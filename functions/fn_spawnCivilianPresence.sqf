/*
 * LL_fnc_spawnCivilianPresence
 *
 * Description:
 *   (Serveur uniquement) Boucle de gestion de la présence civile dynamique.
 *   Spawne des civils dans les bâtiments proches des joueurs et supprime
 *   ceux trop éloignés. Chaque civil reçoit un template via
 *   LL_fnc_applyCivilianTemplate (tenue, identité, voix).
 *
 * Arguments:
 *   Aucun — boucle infinie, à lancer via spawn
 *
 * Return Value:
 *   Aucun
 *
 * Locality:
 *   Server uniquement
 *
 * Public:
 *   Non
 *
 * Example:
 *   [] spawn LL_fnc_spawnCivilianPresence;
 */

#include "..\macros.hpp"

if (!isServer) exitWith {};

// ============================================================
// === PARAMÈTRES
// ============================================================

private _SPAWN_DIST   = 500;   // mètres — rayon de recherche de bâtiments autour d'un joueur
private _MIN_DIST     = 50;    // mètres — distance minimale de spawn par rapport au joueur
private _CLEANUP_DIST = 1200;  // mètres — au-delà, le civil est supprimé
private _MAX_CIVILS   = 55;    // nombre maximum de civils présents simultanément
private _PATROL_DIST  = 200;   // mètres — rayon de patrouille autour du point de spawn
private _SLEEP        = 10;    // secondes entre chaque passe

// Tableau serveur-local des civils spawnés (nettoyé chaque passe)
if (isNil "LL_s_civSpawned") then { LL_s_civSpawned = []; };

// ============================================================
// === BOUCLE PRINCIPALE
// ============================================================

while { true } do {
    sleep _SLEEP;

    // --------------------------------------------------------
    // 1. NETTOYAGE — suppression des civils hors portée
    // --------------------------------------------------------
    {
        private _civ = _x;
        if (isNull _civ || !alive _civ) then {
            LL_s_civSpawned = LL_s_civSpawned - [_civ];
        } else {
            private _tooFar = true;
            {
                if (isPlayer _x && { (_x distance2D _civ) < _CLEANUP_DIST }) exitWith {
                    _tooFar = false;
                };
            } forEach allPlayers;

            if (_tooFar) then {
                private _grp = group _civ;
                deleteVehicle _civ;
                LL_s_civSpawned = LL_s_civSpawned - [_civ];
                if (count (units _grp) == 0) then { deleteGroup _grp; };

                if (DEBUG_MODE) then {
                    diag_log format ["[LL][spawnCivilianPresence] supprimé (trop loin) : %1", _civ];
                };
            };
        };
    } forEach (+ LL_s_civSpawned); // copie pour itérer en sécurité

    // Nettoyage final des références nulles résiduelles
    LL_s_civSpawned = LL_s_civSpawned select { !isNull _x && alive _x };

    // --------------------------------------------------------
    // 2. SPAWN — ajout de civils si sous le quota
    // --------------------------------------------------------
    if (count LL_s_civSpawned < _MAX_CIVILS) then {

        private _players = allPlayers select { alive _x };
        if (count _players == 0) then { continue };

        private _refPlayer = selectRandom _players;
        private _refPos    = getPosATL _refPlayer;

        // Bâtiments dans le rayon de spawn, au-delà de la distance minimale
        private _buildings = nearestObjects [_refPos, ["House", "Building"], _SPAWN_DIST];
        _buildings = _buildings select { (_x distance2D _refPlayer) > _MIN_DIST };

        if (count _buildings == 0) then { continue };

        private _building  = selectRandom _buildings;
        private _bPosList  = _building buildingPos -1;

        if (count _bPosList == 0) then { continue };

        private _bPos = selectRandom _bPosList;
        // Offset Z +0.5 m pour éviter de spawner dans le sol (INFO.md)
        _bPos set [2, (_bPos select 2) + 0.5];

        // Classe depuis MISSION_CivilianTemplates (fallback : civil vanille)
        private _class = "C_man_1";
        private _template = [];
        if (!isNil "MISSION_CivilianTemplates" && { count MISSION_CivilianTemplates > 0 }) then {
            _template = selectRandom MISSION_CivilianTemplates;
            _class = _template select 0;
        };

        // Création du civil
        private _grp = createGroup civilian;
        private _civ = _grp createUnit [_class, _bPos, [], 0, "NONE"];
        _civ setPosASL (AGLToASL _bPos); // force la position sécurisée ASL

        // Application du template complet (tenue, identité, voix)
        [_civ, _template] call LL_fnc_applyCivilianTemplate;

        // Patrouille aléatoire dans le rayon défini
        [_grp, getPosATL _civ, _PATROL_DIST] call BIS_fnc_taskPatrol;

        LL_s_civSpawned pushBack _civ;

        if (DEBUG_MODE) then {
            diag_log format [
                "[LL][spawnCivilianPresence] spawné : %1 | classe : %2 | pos : %3 | total : %4",
                _civ, _class, _bPos, count LL_s_civSpawned
            ];
        };
    };
};
