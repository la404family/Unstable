#include "..\macros.hpp"

/*
 * LL_fnc_addRallyAction
 *
 * Description:
 *   Ajoute une action permanente au joueur pour forcer le regroupement des IA
 *   coincées ou dispersées. Chaque IA reçoit un thread indépendant qui gère le
 *   déplacement vers une position en formation derrière le leader, avec détection
 *   et déblocage automatique si l'unité n'avance plus.
 *
 *   Séquence par unité :
 *     1. Reset des états bloquants (doStop, enableAI PATH/MOVE)
 *     2. Calcul d'une position en arc semi-circulaire derrière le leader
 *     3. BIS_fnc_findSafePos pour garantir un sol praticable
 *     4. doMove vers la cible + surveillance (déplacement < SEUIL → déblocage)
 *     5. En cas de blocage : point intermédiaire vers le leader, puis déviation aléatoire
 *     6. À l'arrivée (ou timeout) : doFollow + setFormDir
 *
 * Paramètres:
 *   Aucun — appelé via [] spawn LL_fnc_addRallyAction depuis initPlayerLocal.sqf
 *
 * Locality:
 *   Client uniquement (hasInterface). Action ajoutée sur le joueur local.
 *   MP-safe : ne concerne que la machine du leader. doMove fonctionne car l'IA
 *   est locale au host dans les parties hébergées.
 */

if (!hasInterface) exitWith {};

// ─── CONSTANTES (substituées à la compilation) ──────────────────────────────
#define RALLY_RAYON_FORMATION  4.0   // distance leader → unité en formation (m)
#define RALLY_ECART_RANG       1.8   // décalage supplémentaire pour les rangs alternés
#define RALLY_DIST_ARRIVE      5.0   // seuil "arrivée" : distance leader (m)
#define RALLY_TIMEOUT          45    // timeout global par unité (secondes)
#define RALLY_DELAI_BLOC       2.0   // cycle de surveillance du blocage (secondes)
#define RALLY_SEUIL_MVT        0.6   // déplacement minimal par cycle (m) avant détection
#define RALLY_TENTATIVES_MAX   3     // tentatives de déblocage avant abandon
#define RALLY_RAYON_DEBLOCAGE  10    // rayon de recherche de position intermédiaire (m)

[] spawn {

    // ── Définition de la fonction d'ajout d'action ───────────────────────────
    private _fnc_addRallyAction = {
        params ["_unit"];

        // Eviter les doublons si l'action a déjà été ajoutée sur cette unité
        if (_unit getVariable ["LL_Action_Rally_Added", false]) exitWith {};
        _unit setVariable ["LL_Action_Rally_Added", true];

        _unit addAction [
            // Libellé affiché dans le menu scroll (vert clair + icône regroupement)
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Action_Rally"],

            // ── Code exécuté au déclenchement de l'action ──────────────────
            {
                params ["_target", "_caller", "_actionId"];

                // Récupérer toutes les IA vivantes, à pied, dans le groupe du leader
                private _squadAI = (units group _caller) select {
                    !isPlayer _x && alive _x && vehicle _x == _x
                };

                if (count _squadAI == 0) exitWith {
                    systemChat localize "STR_LL_Msg_Rally_NoAI";
                };

                systemChat localize "STR_LL_Msg_Rally_Start";

                // ── Thread principal de regroupement ───────────────────────
                [_caller, _squadAI] spawn {
                    params ["_leader", "_units"];

                    private _nbUnits   = count _units;
                    private _dirLeader = getDir _leader;
                    private _posLeader = getPosATL _leader;

                    // ── Calcul de position en arc de 140° derrière le leader ─
                    // Rangs alternés (pair = rang 1, impair = rang 2)
                    private _fnc_calcFormPos = {
                        params ["_idx", "_total", "_ldPos", "_ldDir"];
                        private _spread = 140;
                        private _step   = if (_total > 1) then { _spread / (_total - 1) } else { 0 };
                        private _angle  = (_ldDir + 180 - (_spread / 2) + (_idx * _step)) mod 360;
                        private _rang   = if (_idx mod 2 == 0) then {
                            RALLY_RAYON_FORMATION
                        } else {
                            RALLY_RAYON_FORMATION + RALLY_ECART_RANG
                        };
                        [
                            (_ldPos select 0) + _rang * sin _angle,
                            (_ldPos select 1) + _rang * cos _angle,
                            0
                        ]
                    };

                    // ── Reset des états bloquants avant d'envoyer les ordres ─
                    {
                        _x enableAI "PATH";
                        _x enableAI "MOVE";
                        _x setUnitPos "AUTO";
                    } forEach _units;

                    // ── Lancer un thread indépendant par unité ───────────────
                    {
                        private _unit = _x;
                        private _idx  = _forEachIndex;

                        // Position théorique en formation
                        private _posCible = [_idx, _nbUnits, _posLeader, _dirLeader] call _fnc_calcFormPos;

                        // Position praticable au sol autour de la cible
                        private _posSafe = [_posCible, 0, 2.5, 4, 0, 0.5, 0] call BIS_fnc_findSafePos;
                        if (_posSafe isEqualTo [] || _posSafe isEqualTo [0,0,0]) then {
                            _posSafe = getPosATL _leader; // fallback : aller sur le leader
                        };

                        // Thread par unité avec gestion du déblocage
                        [_unit, _posSafe, _leader] spawn {
                            params ["_unit", "_posCible", "_leader"];

                            _unit doMove _posCible;

                            private _tDebut      = time;
                            private _dernierePos = getPosATL _unit;
                            private _cyclesBloq  = 0;
                            private _tentatives  = 0;

                            // ── Boucle de surveillance ───────────────────────
                            waitUntil {
                                sleep RALLY_DELAI_BLOC;

                                // Conditions de sortie anticipée
                                if (!alive _unit || !alive _leader)              exitWith { true };
                                if (_unit distance _leader < RALLY_DIST_ARRIVE)  exitWith { true };
                                if (time - _tDebut > RALLY_TIMEOUT)              exitWith { true };

                                private _posActu = getPosATL _unit;
                                private _mvt     = _posActu distance _dernierePos;

                                if (_mvt < RALLY_SEUIL_MVT) then {
                                    // ── Possible blocage ────────────────────
                                    _cyclesBloq = _cyclesBloq + 1;

                                    if (_cyclesBloq >= 2 && _tentatives < RALLY_TENTATIVES_MAX) then {
                                        _tentatives = _tentatives + 1;
                                        _cyclesBloq = 0;

                                        // Point intermédiaire vers le leader
                                        private _dirVersLeader = _posActu getDir (getPosATL _leader);
                                        private _posInter = [
                                            (_posActu select 0) + RALLY_RAYON_DEBLOCAGE * sin _dirVersLeader,
                                            (_posActu select 1) + RALLY_RAYON_DEBLOCAGE * cos _dirVersLeader,
                                            0
                                        ];
                                        private _safeInter = [
                                            _posInter, 1, RALLY_RAYON_DEBLOCAGE, 4, 0, 0.5, 0
                                        ] call BIS_fnc_findSafePos;

                                        if (!(_safeInter isEqualTo []) && !(_safeInter isEqualTo [0,0,0])) then {
                                            // Aller au point intermédiaire puis reprendre vers la cible
                                            _unit doMove _safeInter;
                                            sleep 3;
                                            if (alive _unit) then { _unit doMove _posCible; };
                                        } else {
                                            // Déviation aléatoire si aucune position propre trouvée
                                            private _angle = random 360;
                                            private _rayon = 5 + random 8;
                                            _unit doMove [
                                                (_posActu select 0) + _rayon * sin _angle,
                                                (_posActu select 1) + _rayon * cos _angle,
                                                0
                                            ];
                                            sleep 2;
                                            if (alive _unit) then { _unit doMove _posCible; };
                                        };
                                    };
                                } else {
                                    // L'unité avance normalement : reset des compteurs
                                    _cyclesBloq  = 0;
                                    _dernierePos = _posActu;
                                };

                                false // continuer la boucle
                            };

                            // ── Arrivée ou timeout : remettre en formation ───
                            if (alive _unit && alive _leader) then {
                                _unit doFollow _leader;
                                _unit setFormDir (getDir _leader);
                            };
                        };

                    } forEach _units;

                    // ── Attendre la fin du regroupement (toutes arrivées ou timeout) ─
                    private _tGlobal = time;
                    waitUntil {
                        sleep 1;
                        (time - _tGlobal > RALLY_TIMEOUT + 5) ||
                        { (_units select { alive _x && _x distance _leader > RALLY_DIST_ARRIVE }) isEqualTo [] }
                    };

                    if (alive _leader) then {
                        systemChat localize "STR_LL_Msg_Rally_Done";
                    };
                };
            },
            [],   // arguments supplémentaires
            5.3,  // priorité : groupe ESCOUADE
            false, // show window
            true,  // hide on use
            "",    // shortcut
            // ── Condition de visibilité : leader du groupe avec au moins une IA ──
            "leader group _target == _target && { !isPlayer _x } count (units group _target) > 0"
        ];
    };

    // ── Boucle de maintien : re-applique l'action après respawn ou switch d'unité ─
    private _lastPlayer = objNull;
    while { true } do {
        waitUntil { sleep 1; player != _lastPlayer };
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addRallyAction;
        };
    };
};
