#include "..\macros.hpp"

/*
 * LL_fnc_addResupplyAction
 *
 * Description:
 *   Ajoute un addAction sur une caisse de munitions livrée par hélicoptère (LIVRAISON).
 *   Le leader du joueur local peut ordonner aux IA de son groupe de venir se
 *   réapprovisionner en munitions 2 par 2 avec une animation immersive.
 *
 *   Séquence :
 *     1. Les IA viennent devant la caisse par paires (2 positions décalées)
 *     2. Animation accroupie de fouille (AinvPknlMstpSlayWrflDnon_medic)
 *     3. Rechargement réel des magazines depuis la caisse
 *     4. Éloignement pour laisser place à la paire suivante
 *     5. Regroupement final avec le leader (doFollow)
 *
 *   Le joueur leader se sert manuellement via l'inventaire standard.
 *
 * Paramètres:
 *   _this select 0 : OBJECT — la caisse de munitions (B_supplyCrate_F)
 *
 * Locality:
 *   Exécuté sur chaque client (remoteExec depuis le serveur).
 *   L'addAction est local au client, condition de visibilité gérée par le jeu.
 */

if (!hasInterface) exitWith {};

params [["_crate", objNull, [objNull]]];

if (isNull _crate) exitWith {};

// Variable pour empêcher l'utilisation multiple simultanée
_crate setVariable ["LL_Resupply_InProgress", false, true];

// ─── ADDACTION SUR LA CAISSE ─────────────────────────────────────────────────

_crate addAction [
    format ["<t color='#FFD700'>%1</t>", localize "STR_LL_Action_Resupply"],
    {
        params ["_target", "_caller", "_actionId"];

        // Vérification : pas déjà en cours
        if (_target getVariable ["LL_Resupply_InProgress", false]) exitWith {};
        _target setVariable ["LL_Resupply_InProgress", true, true];

        // Récupérer les IA du groupe (pas le joueur, pas les morts, à pied)
        private _squadAI = (units group _caller) select {
            !isPlayer _x && alive _x && vehicle _x == _x
        };

        if (count _squadAI == 0) exitWith {
            systemChat localize "STR_LL_Msg_Resupply_NoAI";
            _target setVariable ["LL_Resupply_InProgress", false, true];
        };

        // Le leader fait un geste de la main pour ordonner le mouvement
        _caller playActionNow "gestureAdvance";
        systemChat localize "STR_LL_Msg_Resupply_Start";

        // Retirer l'action pour éviter la réutilisation pendant l'opération
        _target removeAction _actionId;

        // ─── Séquence immersive en spawn ────────────────────────────────────
        [_target, _squadAI, _caller] spawn {
            params ["_crate", "_squadAI", "_leader"];

            private _cratePos = getPos _crate;
            private _crateDir = getDir _crate;

            // Positions de service devant la caisse, côté leader (±20° pour éviter le clipping)
            // Les 2 unités s'agenouillent face à la caisse, du même côté que le chef — tactiquement
            // elles gardent la caisse entre elles et la direction ennemie.
            private _frontDir = _cratePos getDir (getPos _leader); // axe caisse → leader
            private _posLeft  = _crate getPos [0.2, _frontDir + 20];
            private _posRight = _crate getPos [0.2, _frontDir - 20];

            // Direction d'éloignement (vers le leader après réapprovisionnement)
            private _awayDir  = _frontDir;            // identique à frontDir pour lisibilité
            private _awayDir2 = _frontDir + 180;     // opposée = vers l'ennemi (recul de service)

            // ─── Helpers MP-safe : animation sur la machine locale de l'IA ───────────
            // disableAI / selectWeapon / switchMove sont des commandes LOCALES.
            // Elles doivent être exécutées là où l'unité est locale :
            //   → serveur (machine 2) en dédié, hôte en hosted game.
            // remoteExec ["spawn", owner _u] garantit cela dans les deux cas.
            private _fnc_doUnitAnim = {
                params ["_u", "_anim"];
                if (isNull _u || !alive _u) exitWith {};
                [[_u, _anim], {
                    params ["_u", "_anim"];
                    if (!alive _u) exitWith {};
                    _u disableAI "MOVE";        // immobilise l'IA pendant la séquence
                    _u disableAI "ANIM";        // empêche le FSM de l'IA d'annuler l'anim
                    _u selectWeapon "";         // range l'arme : mains libres pour fouiller
                    _u switchMove _anim;        // démarre l'animation immédiatement
                }] remoteExec ["spawn", owner _u];
            };
            private _fnc_stopUnitAnim = {
                params ["_u"];
                if (isNull _u) exitWith {};
                private _pw = primaryWeapon _u;
                [[_u, _pw], {
                    params ["_u", "_pw"];
                    if (!alive _u) exitWith {};
                    _u enableAI "ANIM";
                    _u enableAI "MOVE";
                    if (_pw != "") then { _u selectWeapon _pw; }; // reprend son arme
                }] remoteExec ["spawn", owner _u];
            };

            // ─── Boucle par paires de 2 ─────────────────────────────────────
            private _totalUnits = count _squadAI;
            private _i = 0;

            while { _i < _totalUnits } do {
                private _unit1 = _squadAI # _i;
                private _unit2 = if (_i + 1 < _totalUnits) then { _squadAI # (_i + 1) } else { objNull };

                // ── Déplacement de la paire vers la caisse ──────────────────
                if (alive _unit1) then {
                    _unit1 doMove _posLeft;
                    _unit1 setSpeedMode "FULL";
                    _unit1 setUnitPos "UP";
                };
                if (!isNull _unit2 && { alive _unit2 }) then {
                    _unit2 doMove _posRight;
                    _unit2 setSpeedMode "FULL";
                    _unit2 setUnitPos "UP";
                };

                // Attente arrivée naturelle (timeout 20s) — seuil 2.5m
                // doMove vers _posLeft/Right (à 2.0m de la caisse) : l'IA s'arrête naturellement
                // à ~2m sans être bloquée par la collision physique de la caisse.
                private _moveTimeout = 0;
                waitUntil {
                    sleep 0.5;
                    _moveTimeout = _moveTimeout + 0.5;
                    private _u1ok = !alive _unit1 || (_unit1 distance2D _cratePos < 0.7);
                    private _u2ok = isNull _unit2 || !alive _unit2 || (_unit2 distance2D _cratePos < 0.7);
                    (_u1ok && _u2ok) || _moveTimeout > 20
                };

                // Positionnement précis contre la caisse (micro-ajustement, unités déjà proches)
                if (alive _unit1) then { _unit1 setPos _posLeft; };
                if (!isNull _unit2 && { alive _unit2 }) then { _unit2 setPos _posRight; };

                // ── Orientation, posture et démarrage de l'animation ────────
                // AinvPknlMstpSnonWrflDnon_medic :
                //   Sn on = arme sur le dos, mains libres → les bras se tendent vers l'avant
                //   Animation bouclante → parfaite pour fouiller une caisse pendant 6 secondes
                //   disableAI "ANIM" empêche le FSM de combat de reprendre le dessus
                //   Exécuté via _fnc_doUnitAnim (remoteExec → machine locale de l'IA)
                if (alive _unit1) then {
                    _unit1 setDir (_unit1 getDir _cratePos);
                    _unit1 setUnitPos "MIDDLE";
                    [_unit1, "AinvPknlMstpSnonWrflDnon_medic"] call _fnc_doUnitAnim;
                };
                if (!isNull _unit2 && { alive _unit2 }) then {
                    _unit2 setDir (_unit2 getDir _cratePos);
                    _unit2 setUnitPos "MIDDLE";
                    [_unit2, "AinvPknlMstpSnonWrflDnon_medic"] call _fnc_doUnitAnim;
                };

                // Laisser l'animation se lancer et la 1ère phase de prise se dérouler
                sleep 3.0;

                // Fonction locale de rechargement depuis la caisse
                private _fnc_resupply = {
                    params ["_unit", "_crate"];
                    if (!alive _unit || isNull _crate) exitWith {};

                    // Recharger les magazines de l'arme principale
                    private _pw = primaryWeapon _unit;
                    if (_pw != "") then {
                        private _pwMags = getArray (configFile >> "CfgWeapons" >> _pw >> "magazines");
                        if (count _pwMags > 0) then {
                            private _magClass = _pwMags # 0;
                            private _currentCount = { _x == _magClass } count (magazines _unit);
                            private _needed = (8 - _currentCount) max 0;
                            for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                        };
                    };

                    // Recharger les magazines de l'arme de poing
                    private _hw = handgunWeapon _unit;
                    if (_hw != "") then {
                        private _hwMags = getArray (configFile >> "CfgWeapons" >> _hw >> "magazines");
                        if (count _hwMags > 0) then {
                            private _magClass = _hwMags # 0;
                            private _currentCount = { _x == _magClass } count (magazines _unit);
                            private _needed = (4 - _currentCount) max 0;
                            for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                        };
                    };

                    // Recharger les lanceurs (secondaire)
                    private _sw = secondaryWeapon _unit;
                    if (_sw != "") then {
                        private _swMags = getArray (configFile >> "CfgWeapons" >> _sw >> "magazines");
                        if (count _swMags > 0) then {
                            private _magClass = _swMags # 0;
                            private _currentCount = { _x == _magClass } count (magazines _unit);
                            private _needed = (3 - _currentCount) max 0;
                            for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                        };
                    };

                    // Grenades et fumigènes
                    private _grenadeCount = { toLower _x find "grenade" != -1 } count (magazines _unit);
                    if (_grenadeCount < 3) then {
                        for "_g" from 1 to (3 - _grenadeCount) do { _unit addMagazine "CUP_HandGrenade_M67"; };
                    };
                    private _smokeCount = { _x == "SmokeShell" } count (magazines _unit);
                    if (_smokeCount < 2) then {
                        for "_s" from 1 to (2 - _smokeCount) do { _unit addMagazine "SmokeShell"; };
                    };

                    // Soins
                    private _fak = { _x == "FirstAidKit" } count (items _unit);
                    if (_fak < 3) then {
                        for "_f" from 1 to (3 - _fak) do { _unit addItem "FirstAidKit"; };
                    };
                };

                if (alive _unit1) then { [_unit1, _crate] call _fnc_resupply; };
                if (!isNull _unit2 && { alive _unit2 }) then { [_unit2, _crate] call _fnc_resupply; };

                // 2e phase d'animation : range les chargeurs dans le sac (2.5s de plus)
                sleep 2.5;

                // ── Fin d'animation : restaurer l'état de l'IA ──────────────
                // enableAI + reprend son arme principale (via remoteExec → machine locale)
                if (alive _unit1) then { [_unit1] call _fnc_stopUnitAnim; };
                if (!isNull _unit2 && { alive _unit2 }) then { [_unit2] call _fnc_stopUnitAnim; };
                sleep 0.3; // court délai pour que l'arme remonte avant de bouger

                // ── Éloignement de la paire ─────────────────────────────────
                // Les unités servies s'éloignent de 8m pour laisser place aux suivantes
                if (alive _unit1) then {
                    private _retreatPos1 = _posLeft getPos [8, _awayDir2 - 20];
                    _unit1 setUnitPos "UP";
                    _unit1 doMove _retreatPos1;
                };
                if (!isNull _unit2 && { alive _unit2 }) then {
                    private _retreatPos2 = _posRight getPos [8, _awayDir2 + 20];
                    _unit2 setUnitPos "UP";
                    _unit2 doMove _retreatPos2;
                };

                // Petite pause entre les paires pour que ça reste fluide
                sleep 3;

                _i = _i + 2;
            };

            // ─── Regroupement final ─────────────────────────────────────────
            sleep 2;
            {
                if (alive _x) then {
                    _x setUnitPos "AUTO";
                    _x setSpeedMode "NORMAL";
                    _x doFollow _leader;
                };
            } forEach _squadAI;

            systemChat localize "STR_LL_Msg_Resupply_Done";

            // Réactiver l'action si la caisse existe toujours (permettre un 2e resupply)
            if (!isNull _crate && { alive _crate }) then {
                _crate setVariable ["LL_Resupply_InProgress", false, true];
                [_crate] call LL_fnc_addResupplyAction;
            };
        };
    },
    [],
    6.0,       // Priorité (au-dessus des autres actions)
    true,      // showWindow
    true,      // hideOnUse
    "",
    // Condition : joueur = leader, a des IA dans le groupe, pas de resupply en cours
    "leader group player == player && { !isPlayer _x } count (units group player) > 0 && !(_target getVariable ['LL_Resupply_InProgress', false])"
];
