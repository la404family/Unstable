#include "..\macros.hpp"

/*
 * LL_fnc_requestDrone
 *
 * Description:
 *   Déploie un drone de surveillance MQ-9 (CUP_B_USMC_DYN_MQ9) côté serveur.
 *   Le drone entre sur zone, effectue un loiter circulaire autour du leader du groupe
 *   appelant, marque les unités ennemies (rouge) et alliées (bleu) sur la carte avec
 *   des markers dot sans texte. Il ne cible que les véhicules ennemis.
 *   Les unités ennemies au sol ignorent le drone.
 *   Verrou unique : TAG_Drone_Active empêche deux drones simultanés.
 *
 * Arguments:
 *   0: <OBJECT> Le joueur ayant effectué la demande (_caller)
 *
 * Locality:
 *   Serveur uniquement
 */

if (!isServer) exitWith {};

params [
    ["_caller", objNull, [objNull]]
];

// ── Vérification verrou ───────────────────────────────────────────────────────
if (missionNamespace getVariable ["TAG_Drone_Active", false]) exitWith {
    (localize "STR_TAG_Msg_Drone_Denied") remoteExec ["systemChat", _caller];
    if (DEBUG_MODE) then { diag_log "[LL] requestDrone: Refusé — TAG_Drone_Active déjà actif."; };
};

missionNamespace setVariable ["TAG_Drone_Active", true, true];

(localize "STR_TAG_Msg_Drone_Approved") remoteExec ["systemChat", 0];

if (DEBUG_MODE) then { diag_log "[LL] requestDrone: Demande approuvée, déploiement en cours."; };

// ── Scénario principal (spawn pour permettre sleep/waitUntil) ─────────────────
[_caller] spawn {
    params ["_caller"];

    // ── Constantes ────────────────────────────────────────────────────────────
    private _droneClass     = "CUP_B_USMC_DYN_MQ9";
    private _approachHeight = 300;  // Altitude d'approche et de retrait (m)
    private _loiterHeight   = 180;  // Altitude de surveillance (m)
    private _loiterRadius   = 600;  // Rayon de loiter (m) — voilure fixe, large cercle
    private _missionTime    = 900;  // Durée de mission : 15 minutes
    private _markerPrefix   = "LL_drone_";
    private _markerPool     = 25;   // Nb max de marqueurs par faction
    private _scanRadius     = 1500; // Rayon de détection (m)

    // ── Centre de masse des joueurs actifs ────────────────────────────────────
    private _activePlayers = allPlayers select { alive _x };
    if (count _activePlayers == 0) then { _activePlayers = [_caller]; };
    private _centerPos = [0, 0, 0];
    { _centerPos = _centerPos vectorAdd getPos _x; } forEach _activePlayers;
    _centerPos = _centerPos vectorMultiply (1 / count _activePlayers);
    _centerPos set [2, 0];

    // ── Spawn hors de vue ─────────────────────────────────────────────────────
    private _spawnDir    = random 360;
    private _spawnPos    = _centerPos getPos [3000, _spawnDir];
    _spawnPos set [2, _approachHeight];
    private _approachDir = ((_spawnDir + 180) mod 360);

    // ── Créer le drone ────────────────────────────────────────────────────────
    private _drone = createVehicle [_droneClass, _spawnPos, [], 0, "FLY"];
    if (isNull _drone) exitWith {
        missionNamespace setVariable ["TAG_Drone_Active", false, true];
        (localize "STR_TAG_Msg_Drone_Error") remoteExec ["systemChat", 0];
        if (DEBUG_MODE) then { diag_log "[LL][ERROR] requestDrone: createVehicle échoué — classe introuvable."; };
    };

    _drone setPos _spawnPos;
    _drone setDir _approachDir;
    _drone flyInHeight _approachHeight;
    _drone allowDamage false;

    // Vitesse initiale indispensable pour voilure fixe (évite le décrochage au spawn)
    private _initSpeed = 55; // m/s (~198 km/h)
    _drone setVelocity [
        _initSpeed * (sin _approachDir),
        _initSpeed * (cos _approachDir),
        0
    ];

    // Créer l'équipage natif (pilote IA + opérateur UAV)
    createVehicleCrew _drone;
    sleep 0.2;

    private _droneGroup = group (driver _drone);
    if (isNull _droneGroup) exitWith {
        { deleteVehicle _x } forEach crew _drone;
        deleteVehicle _drone;
        missionNamespace setVariable ["TAG_Drone_Active", false, true];
        (localize "STR_TAG_Msg_Drone_Error") remoteExec ["systemChat", 0];
        if (DEBUG_MODE) then { diag_log "[LL][ERROR] requestDrone: groupe pilote introuvable après createVehicleCrew."; };
    };

    // ── Comportement IA ───────────────────────────────────────────────────────
    // FIRE AT WILL (RED) pour engager les véhicules ennemis
    // Le filtre d'infanterie (boucle ci-dessous) empêche l'engagement au sol
    _droneGroup setCombatMode "RED";
    _droneGroup setBehaviour "COMBAT";
    {
        _x allowDamage false;
        _x disableAI "SUPPRESSION"; // Pas de suppression inutile
    } forEach units _droneGroup;

    // ── Filtre cibles : le drone ne tire que sur les véhicules ───────────────
    // EnemyDetected se déclenche dès qu'une unité ennemie est détectée.
    // Si c'est un fantassin, toutes les unités du groupe l'oublient immédiatement.
    _droneGroup addEventHandler ["EnemyDetected", {
        params ["_grp", "_detected"];
        if (_detected isKindOf "Man") then {
            { _x forgetTarget _detected } forEach units _grp;
        };
    }];

    // ── Boucle : les unités ennemies ignorent le drone ────────────────────────
    [_drone] spawn {
        params ["_drone"];
        while { alive _drone } do {
            sleep 4;
            if (alive _drone) then {
                {
                    if (alive _x) then { _x forgetTarget _drone; };
                } forEach (allUnits select { side _x == east });
            };
        };
    };

    if (DEBUG_MODE) then {
        diag_log format ["[LL] requestDrone: Drone spawné en %1, cap %2, approche vers %3.", _spawnPos, _approachDir, _centerPos];
    };

    // ── Phase 1 : Approche de la zone ─────────────────────────────────────────
    private _wp = _droneGroup addWaypoint [_centerPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointCompletionRadius 400;

    waitUntil {
        sleep 5;
        !alive _drone || (_drone distance2D _centerPos < 600)
    };

    if (!alive _drone) exitWith {
        missionNamespace setVariable ["TAG_Drone_Active", false, true];
        if (DEBUG_MODE) then { diag_log "[LL] requestDrone: Drone détruit en approche."; };
    };

    if (DEBUG_MODE) then { diag_log "[LL] requestDrone: Drone sur zone — passage en loiter."; };

    // ── Phase 2 : Annonce et loiter autour du leader ──────────────────────────
    (localize "STR_TAG_Msg_Drone_Overhead") remoteExec ["systemChat", 0];

    _drone flyInHeight _loiterHeight;

    // Supprimer les waypoints intermédiaires (index > 0)
    private _allWps = waypoints _droneGroup;
    for "_i" from ((count _allWps) - 1) to 1 step -1 do {
        deleteWaypoint (_allWps select _i);
    };

    // Loiter circulaire centré sur le leader du groupe appelant
    private _loiterCenter = getPos (leader (group _caller));
    private _wpLoiter = _droneGroup addWaypoint [_loiterCenter, 0];
    _wpLoiter setWaypointType "LOITER";
    _wpLoiter setWaypointLoiterRadius _loiterRadius;
    _wpLoiter setWaypointLoiterType "CIRCLE";
    _droneGroup setSpeedMode "LIMITED";
    _droneGroup setCurrentWaypoint _wpLoiter;

    // ── Phase 3 : Initialisation des marqueurs ────────────────────────────────
    // Pools de marqueurs dot : east=rouge, independent=bleu (RACS allié)
    // createMarker est global : visible par tous les clients automatiquement
    {
        _x params ["_tag", "_color"];
        for "_i" from 0 to (_markerPool - 1) do {
            private _mn = format ["%1%2_%3", _markerPrefix, _tag, _i];
            createMarker [_mn, [0, 0, 0]];
            _mn setMarkerShape "ICON";
            _mn setMarkerType "mil_dot";
            _mn setMarkerColor _color;
            _mn setMarkerSize [0.4, 0.4];
            _mn setMarkerText "";
            _mn setMarkerAlpha 0;
        };
    } forEach [
        ["opfor", "ColorRed"],
        ["indep", "ColorBlue"]
    ];

    // ── Boucle de marquage (parallèle) ───────────────────────────────────────
    private _missionEnd = time + _missionTime;

    [_drone, _markerPrefix, _markerPool, _missionEnd, _caller, _scanRadius] spawn {
        params ["_drone", "_prefix", "_pool", "_endTime", "_caller", "_scanRadius"];

        while { time < _endTime && alive _drone } do {
            sleep (5 + random 5); // Rafraîchissement toutes les 5–10 secondes

            if (!alive _drone) exitWith {};

            private _leaderPos = getPos (leader (group _caller));

            // Remettre tous les marqueurs à alpha 0 pour éviter les fantômes
            for "_i" from 0 to (_pool - 1) do {
                (format ["%1opfor_%2", _prefix, _i]) setMarkerAlpha 0;
                (format ["%1indep_%2", _prefix, _i]) setMarkerAlpha 0;
            };

            // ── OPFOR (est) — points rouges ───────────────────────────────────
            // Léger bruit de position (simulation capteur imparfait)
            private _opforIdx = 0;
            {
                if (_opforIdx >= _pool) exitWith {};
                private _rawPos = getPos _x;
                private _mp = [
                    (_rawPos select 0) + ((random 50) - 25),
                    (_rawPos select 1) + ((random 50) - 25),
                    0
                ];
                (format ["%1opfor_%2", _prefix, _opforIdx]) setMarkerPos _mp;
                (format ["%1opfor_%2", _prefix, _opforIdx]) setMarkerAlpha 1;
                _opforIdx = _opforIdx + 1;
            } forEach (allUnits select {
                alive _x
                && side _x == east
                && _x distance2D _leaderPos < _scanRadius
            });

            // ── INDEP (RACS alliés) — points bleus ───────────────────────────
            // Position précise pour les alliés (pas de bruit)
            private _indepIdx = 0;
            {
                if (_indepIdx >= _pool) exitWith {};
                private _rawPos = getPos _x;
                (format ["%1indep_%2", _prefix, _indepIdx]) setMarkerPos [_rawPos select 0, _rawPos select 1, 0];
                (format ["%1indep_%2", _prefix, _indepIdx]) setMarkerAlpha 1;
                _indepIdx = _indepIdx + 1;
            } forEach (allUnits select {
                alive _x
                && side _x == independent
                && _x distance2D _leaderPos < _scanRadius
            });
        };

        // ── Nettoyage des marqueurs à la fin ──────────────────────────────────
        for "_i" from 0 to (_pool - 1) do {
            deleteMarker format ["%1opfor_%2", _prefix, _i];
            deleteMarker format ["%1indep_%2", _prefix, _i];
        };
    };

    // ── Phase 4 : Attendre la fin de mission ou la destruction du drone ─────
    // waitUntil interruptible : libère le verrou immédiatement si le drone est détruit
    waitUntil { sleep 5; !alive _drone || time >= _missionEnd };

    (localize "STR_TAG_Msg_Drone_End") remoteExec ["systemChat", 0];

    if (DEBUG_MODE) then { diag_log "[LL] requestDrone: Mission terminée ou drone détruit, retrait en cours."; };

    // Supprimer les waypoints actifs
    while { count (waypoints _droneGroup) > 0 } do {
        deleteWaypoint [_droneGroup, 0];
    };

    // ── Phase 5 : Vol de retrait (ignoré si drone détruit) ───────────────────
    if (alive _drone) then {
        _drone flyInHeight _approachHeight;
        private _exitDir = random 360;
        private _exitPos = (getPos _drone) getPos [5000, _exitDir];
        _exitPos set [2, _approachHeight];
        private _wpExit = _droneGroup addWaypoint [_exitPos, 0];
        _wpExit setWaypointType "MOVE";
        _wpExit setWaypointSpeed "FULL";

        waitUntil {
            sleep 5;
            !alive _drone || (_drone distance2D _exitPos < 1000)
        };
    };

    // ── Nettoyage final ───────────────────────────────────────────────────────
    { deleteVehicle _x } forEach (crew _drone);
    deleteVehicle _drone;
    if (!isNull _droneGroup) then { deleteGroup _droneGroup; };

    missionNamespace setVariable ["TAG_Drone_Active", false, true];

    if (DEBUG_MODE) then { diag_log "[LL] requestDrone: Drone supprimé, verrou TAG_Drone_Active libéré."; };
};
