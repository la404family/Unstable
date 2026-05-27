#include "..\macros.hpp"

/*
    LL_fnc_task02b

    Description:
      Tâche 02b — "Le Fil Rouge"
      Un informateur du RACS à Porto a été kidnappé par la milice.
      Trois zones de recherche sont définies, une seule le cache.
      Les joueurs doivent le retrouver, éliminer ses gardiens et le libérer.

      SUCCEEDED : Informateur libéré (animation de libération terminée).
      FAILED    : Informateur tué avant d'être libéré.

    Points de spawn :
      Utilise les Game Logic M_Dans_Bat_XXX déjà présents dans l'éditeur (minimum 3).

    Locality:
      Serveur uniquement (isServer)
*/

if (!isServer) exitWith {};

[] spawn {

    // Attendre qu'au moins un joueur indépendant soit actif
    waitUntil {
        sleep 2;
        (count (allPlayers select { side _x == independent && alive _x })) > 0
    };

    // ══════════════════════════════════════════════════════════════════════
    // POINTS DE SPAWN — Game Logic M_Dans_Bat_XXX (éditeur Eden existants)
    // ══════════════════════════════════════════════════════════════════════
    private _rawSpawns = [];
    {
        if (_x select [0, 11] == "M_Dans_Bat_") then {
            private _val = missionNamespace getVariable [_x, objNull];
            if (!isNull _val) then { _rawSpawns pushBack _val; };
        };
    } forEach (allVariables missionNamespace);

    _rawSpawns = _rawSpawns call BIS_fnc_arrayShuffle;

    // Filtrer les points trop proches du lieu de rencontre de task01 (immersion — min 200m)
    private _task01MeetingPos = if (!isNil "LL_g_usedTaskPos" && { count LL_g_usedTaskPos > 0 }) then {
        LL_g_usedTaskPos select 0
    } else {
        [0, 0, 0]
    };
    private _farSpawns02b = _rawSpawns select { _x distance2D _task01MeetingPos >= 200 };
    if (count _farSpawns02b >= 3) then { _rawSpawns = _farSpawns02b; };

    // Sélectionner 3 points espacés d'au moins 150m entre eux (immersion)
    private _selectedSpawns = [];
    {
        private _candidate = _x;
        if (count _selectedSpawns < 3) then {
            private _tooClose = false;
            {
                if (_candidate distance2D _x < 150) exitWith { _tooClose = true; };
            } forEach _selectedSpawns;
            if (!_tooClose) then { _selectedSpawns pushBack _candidate; };
        };
    } forEach _rawSpawns;

    if (count _selectedSpawns < 3) exitWith {
        diag_log "[LL][task02b] ERREUR : pas assez de points M_Dans_Bat_XXX (minimum 3 requis).";
    };

    // ══════════════════════════════════════════════════════════════════════
    // ZONE DE L'INFORMATEUR — tirée aléatoirement parmi les 3
    // ══════════════════════════════════════════════════════════════════════
    private _hostageZoneIndex = floor random 3;

    if (DEBUG_MODE) then {
        diag_log format ["[LL][task02b] Zone de l'informateur : %1", _hostageZoneIndex];
    };

    // ══════════════════════════════════════════════════════════════════════
    // SPAWN DES GARDES — 3 zones, 5 à 7 gardes chacune
    // TASK_RULES §3 : sleep 0.7 entre chaque spawn secondaire
    // ══════════════════════════════════════════════════════════════════════
    private _allGroups = [];

    for "_i" from 0 to 2 do {

        private _logic    = _selectedSpawns select _i;
        private _spawnPos = getPosASL _logic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2]; // Z + 0.2 — TASK_RULES §3

        private _grp       = createGroup [east, true];
        private _numGuards = 5 + floor random 3; // 5 à 7 gardes

        for "_g" from 0 to (_numGuards - 1) do {
            sleep 0.7;

            private _gPos  = _spawnPos getPos [4 + random 12, random 360];
            private _guard = _grp createUnit ["O_G_Soldier_F", [0,0,0], [], 0, "NONE"];

            _guard setPosASL [
                _gPos select 0,
                _gPos select 1,
                (getTerrainHeightASL _gPos) + 0.5
            ];
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };

            _guard setVariable ["LL_forceTemplate", true, true];
            if (!isNil "LL_fnc_applyCivilianTemplate") then {
                [_guard] call LL_fnc_applyCivilianTemplate;
            };
            _guard allowFleeing 0;
        };

        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";
        _allGroups pushBack _grp;

        // Boucle de patrouille locale (TASK_RULES §11 — ennemi, 4–25m, non-SAFE)
        [units _grp, _spawnPos] spawn {
            params ["_members", "_center"];
            while { ({ alive _x } count _members) > 0 } do {
                {
                    if (alive _x
                        && !(_x getVariable ["LL_Task02b_Dissolving", false])
                        && behaviour _x != "COMBAT"
                    ) then {
                        _x doMove (_center getPos [4 + random 21, random 360]);
                    };
                } forEach _members;
                sleep (12 + random 18);
            };
        };

        // Marqueur orange de zone de recherche
        private _mkrName = format ["LL_mkr_t02b_zone_%1", _i];
        createMarker [_mkrName, getPos _logic];
        _mkrName setMarkerType "hd_unknown";
        _mkrName setMarkerColor "ColorOrange";
        _mkrName setMarkerText localize "STR_LL_Task_02b_ZoneMarker";
    };

    // ══════════════════════════════════════════════════════════════════════
    // SPAWN DE L'INFORMATEUR — unité principale en dernier (TASK_RULES §3)
    // ══════════════════════════════════════════════════════════════════════
    sleep 0.7;

    private _hostageLogic = _selectedSpawns select _hostageZoneIndex;
    private _hostagePos   = getPosASL _hostageLogic;
    _hostagePos set [2, (_hostagePos select 2) + 0.2];

    // Léger décalage pour ne pas spawn exactement sur le logic
    private _spawnOffsetPos = [
        (_hostagePos select 0) + (2 - random 4),
        (_hostagePos select 1) + (2 - random 4),
        (_hostagePos select 2)
    ];

    private _hostageGrp = createGroup [civilian, true];
    private _hostage    = _hostageGrp createUnit ["C_Man_1_1_F", [0,0,0], [], 0, "NONE"];

    // CORRECTIF : Empêcher le chargement automatique de l'équipement joueur
    _hostage setVariable ["LL_LoadoutSet", true, true];

    _hostage setPosASL _spawnOffsetPos;
    _hostage allowDamage false;
    [_hostage] spawn { sleep 3; (_this select 0) allowDamage true; };

    // Configuration otage
    _hostage setCaptive true;
    removeAllWeapons _hostage;
    removeBackpack _hostage;

    _hostage disableAI "ANIM";
    _hostage disableAI "MOVE";
    _hostage disableAI "AUTOTARGET";
    _hostage disableAI "TARGET";

    _hostage setUnitPos "MIDDLE";
    _hostage allowFleeing 0;
    _hostage setVariable ["LL_Task02b_Status", "WAIT", true];

    // Animation de captif en boucle (TASK_RULES §4)
    _hostage switchMove "Acts_ExecutionVictim_Loop";
    _hostage addEventHandler ["AnimDone", {
        params ["_unit"];
        if (alive _unit && (_unit getVariable ["LL_Task02b_Status", "WAIT"]) == "WAIT") then {
            _unit switchMove "Acts_ExecutionVictim_Loop";
        };
    }];

    // Rotation vers le joueur le plus proche toutes les 2s (TASK_RULES §4)
    [_hostage] spawn {
        params ["_h"];
        while { alive _h && (_h getVariable ["LL_Task02b_Status", "WAIT"]) == "WAIT" } do {
            private _nearest    = objNull;
            private _minDist    = 99999;
            {
                if (alive _x) then {
                    private _d = _h distance _x;
                    if (_d < _minDist) then { _minDist = _d; _nearest = _x; };
                };
            } forEach allPlayers;
            if (!isNull _nearest) then {
                _h setDir     (_h getDir _nearest);
                _h setFormDir (_h getDir _nearest); // Empêche l'IA de formation de re-pivoter
                _h setPosATL  (getPosATL _h);       // Ancre la position — empêche la dérive de l'animation
            };
            sleep 2;
        };
    };

    // ══════════════════════════════════════════════════════════════════════
    // CRÉATION DE LA TÂCHE BIS (TASK_RULES §7)
    // ══════════════════════════════════════════════════════════════════════
    missionNamespace setVariable ["LL_Task02b_Freed", false, true];

    [
        independent,
        ["task_02b_informateur"],
        [
            localize "STR_LL_Task_02b_Desc",
            localize "STR_LL_Task_02b_Title",
            localize "STR_LL_Task_02b_Marker"
        ],
        objNull,  // Pas de marqueur 3D/carte initial — 3 zones de recherche, découverte progressive (carte seule)
        "AUTOASSIGNED",
        5,
        true,
        "protect"
    ] call BIS_fnc_taskCreate;

    ["STR_LL_Speaker_Narrator", "STR_LL_Task_02b_Narrative_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

    // Déployer l'addAction de libération sur tous les clients (TASK_RULES §5)
    [_hostage] remoteExec ["LL_fnc_task02b_addAction", 0];

    // ══════════════════════════════════════════════════════════════════════
    // DÉTECTION DE PROXIMITÉ — révèle la position de l'informateur à 50m
    // ══════════════════════════════════════════════════════════════════════
    [_hostage] spawn {
        params ["_h"];
        waitUntil {
            sleep 2;
            !alive _h
            || missionNamespace getVariable ["LL_Task02b_Freed", false]
            || ({ _x distance2D _h <= 50 } count (allPlayers select { alive _x })) > 0
        };
        if (!alive _h) exitWith {};
        if (missionNamespace getVariable ["LL_Task02b_Freed", false]) exitWith {};

        // Marqueur blanc sur l'informateur + mise à jour destination de tâche
        createMarker ["LL_mkr_t02b_hostage", getPos _h];
        "LL_mkr_t02b_hostage" setMarkerType "mil_objective";
        "LL_mkr_t02b_hostage" setMarkerColor "ColorWhite";
        "LL_mkr_t02b_hostage" setMarkerText localize "STR_LL_Task_02b_MarkerHostage";
        // Pas de BIS_fnc_taskSetDestination — interdit par TASK_RULES §7 (marqueur 3D, tâche créée avec [0,0,0])

        if (DEBUG_MODE) then {
            diag_log "[LL][task02b] Informateur localisé par les joueurs.";
        };
    };

    // ══════════════════════════════════════════════════════════════════════
    // SURVEILLANCE ÉCHEC — mort de l'informateur avant libération
    // ══════════════════════════════════════════════════════════════════════
    [_hostage, _allGroups] spawn {
        params ["_h", "_groups"];
        waitUntil { sleep 1; !alive _h || missionNamespace getVariable ["LL_Task02b_Freed", false] };
        if (missionNamespace getVariable ["LL_Task02b_Freed", false]) exitWith {}; // Libéré → pas d'échec
        if (alive _h) exitWith {};                                                 // Sécurité

        // Informateur mort sans être libéré → FAILED
        if (DEBUG_MODE) then { diag_log "[LL][task02b] Informateur tué — tâche FAILED."; };

        deleteMarker "LL_mkr_t02b_hostage";
        for "_i" from 0 to 2 do { deleteMarker format ["LL_mkr_t02b_zone_%1", _i]; };

        ["task_02b_informateur", "FAILED", true] call BIS_fnc_taskSetState;
        ["STR_LL_Speaker_Narrator", "STR_LL_Task_02b_Narrative_Failed"] remoteExec ["LL_fnc_showSubtitle", 0];

        // Dissolution des gardes survivants même en cas d'échec (TASK_RULES §14)
        {
            private _grp   = _x;
            private _alive = (units _grp) select { alive _x };
            if (count _alive > 0) then {
                { _x setVariable ["LL_Task02b_Dissolving", true, true]; } forEach _alive;
                [_alive, _grp] spawn {
                    params ["_units", "_grp"];
                    private _alive = _units select { alive _x };
                    if (count _alive == 0) exitWith {};
                    private _running = true;
                    while { _running && ({ alive _x } count _alive) > 0 } do {
                        private _refPos      = getPos (leader _grp);
                        private _dissolvePos = [];
                        private _attempts    = 0;
                        while { count _dissolvePos == 0 && _attempts < 30 } do {
                            _attempts = _attempts + 1;
                            private _candidate = _refPos getPos [200 + random 300, random 360];
                            private _valid = true;
                            { if (_x distance2D _candidate <= 150) exitWith { _valid = false; }; }
                                forEach (allPlayers select { alive _x });
                            if (_valid) then { _dissolvePos = _candidate; };
                        };
                        if (count _dissolvePos == 0) then { _dissolvePos = _refPos getPos [400, random 360]; };
                        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                        private _wp = _grp addWaypoint [_dissolvePos, 5];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "FULL";
                        _wp setWaypointBehaviour "SAFE";
                        waitUntil { sleep 1; ({ alive _x } count _alive) == 0 || (leader _grp distance2D _dissolvePos <= 5) };
                        if (({ alive _x } count _alive) == 0) exitWith { _running = false; };
                        private _allFar = true;
                        { if (_x distance2D _dissolvePos <= 150) exitWith { _allFar = false; }; }
                            forEach (allPlayers select { alive _x });
                        if (_allFar) then {
                            { if (!isNull _x && alive _x) then { deleteVehicle _x; }; } forEach _alive;
                            if (!isNull _grp) then { deleteGroup _grp; };
                            _running = false;
                        };
                    };
                };
            };
        } forEach _groups;
    };

    // ══════════════════════════════════════════════════════════════════════
    // ATTENTE DE LA LIBÉRATION (ou mort de l'informateur)
    // ══════════════════════════════════════════════════════════════════════
    waitUntil {
        sleep 1;
        missionNamespace getVariable ["LL_Task02b_Freed", false]
        || !alive _hostage
    };

    // Informateur tué → la surveillance échec gère le reste
    if (!alive _hostage) exitWith {};

    // ══════════════════════════════════════════════════════════════════════
    // SÉQUENCE DE LIBÉRATION
    // ══════════════════════════════════════════════════════════════════════
    _hostage setVariable ["LL_Task02b_Status", "ACTION", true];

    // CORRECTIF #7 : l'addAction se masque via sa condition (LL_Task02b_Freed = true)
    // Ne plus utiliser removeAllActions (trop large, conflit potentiel avec d'autres mods)

    // Animation de libération — transition propre (TASK_ANIM §4.2)
    _hostage removeAllEventHandlers "AnimDone";
    // CORRECTIF : L'animation playMove a déjà été lancée par le client ayant cliqué sur l'action pour une réaction instantanée.
    // Le serveur se contente d'attendre la fin de l'animation pour synchroniser la suite de la libération.
    sleep 8; // Durée de l'animation de relèvement (~8s)
    _hostage enableAI "ANIM";

    // Réactiver le mouvement, l'informateur se relève
    _hostage enableAI "MOVE";
    _hostage setUnitPos "UP";
    _hostage setBehaviour "CARELESS";
    _hostage setSpeedMode "LIMITED";
    _hostage setCaptive false;

    // Identifier le leader du groupe joueur et rejoindre son groupe
    private _alivePlayers = allPlayers select { alive _x };
    private _playerLeader = if (count _alivePlayers > 0) then {
        leader (group (_alivePlayers select 0))
    } else { objNull };

    if (!isNull _playerLeader) then {
        [_hostage] joinSilent (group _playerLeader);
        _hostage doFollow _playerLeader;
    };

    // CORRECTIF #11 : Supprimer le groupe civil vide de l'otage
    if (!isNull _hostageGrp && {count units _hostageGrp == 0}) then {
        deleteGroup _hostageGrp;
    };

    // Boucle de suivi actif du leader (mise à jour toutes les 5s)
    [_hostage] spawn {
        params ["_h"];
        while {
            alive _h
            && !(_h getVariable ["LL_Task02b_InHeli", false])
        } do {
            private _players = allPlayers select { alive _x };
            if (count _players > 0) then {
                private _ldr = leader (group (_players select 0));
                if (!isNull _ldr && { _ldr != _h }) then { _h doFollow _ldr; };
            };
            sleep 5;
        };
    };

    sleep 3;

    // Dialogues de libération
    ["STR_LL_Speaker_Informateur", "STR_LL_Task_02b_Informateur_Freed"] remoteExec ["LL_fnc_showSubtitle", 0];
    sleep 6;
    ["STR_LL_Speaker_Narrator", "STR_LL_Task_02b_Narrative_Success"] remoteExec ["LL_fnc_showSubtitle", 0];
    sleep 3;

    // ══════════════════════════════════════════════════════════════════════
    // DEMANDE D'EXTRACTION DE L'INFORMATEUR (TAKS_HELI)
    // ══════════════════════════════════════════════════════════════════════
    private _players = allPlayers select { alive _x };
    private _caller = if (count _players > 0) then { _players select 0 } else { objNull };
    if (!isNull _caller) then {
        // Enregistrer l'otage globalement pour le gestionnaire d'hélicoptère
        missionNamespace setVariable ["LL_Task02b_Hostage", _hostage, true];
        missionNamespace setVariable ["LL_Task02b_Freed_Done", false, true];

        if (DEBUG_MODE) then {
            diag_log "[LL][task02b] Envoi d'une requête d'hélicoptère 'EMBARQUEMENT' pour l'informateur.";
        };
        // Appel centralisé au dispatcher (hélicoptère CUP_I_CH47F_RACS)
        ["EMBARQUEMENT", getPos _hostage, _caller, 2] call LL_fnc_heliDispatch;
    };

    // ══════════════════════════════════════════════════════════════════════
    // SURVEILLANCE EMBARQUEMENT — l'informateur rejoint l'hélico de mission
    // dès qu'il s'en approche
    // ══════════════════════════════════════════════════════════════════════
    [_hostage] spawn {
        params ["_h"];

        // Attendre que l'hélico de mission soit actif
        private _heli = objNull;
        waitUntil {
            sleep 2;
            if (!alive _h) exitWith { true };
            _heli = missionNamespace getVariable ["LL_HELI_obj", objNull];
            !isNull _heli && { alive _heli }
        };
        if (!alive _h || isNull _heli) exitWith {};

        // Attendre que l'hélico soit proche (100m) ou au sol
        waitUntil {
            sleep 1;
            if (!alive _h || !alive _heli) exitWith { true };
            (_h distance2D _heli < 100) || isTouchingGround _heli
        };
        if (!alive _h || !alive _heli) exitWith {};

        if (DEBUG_MODE) then {
            diag_log "[LL][task02b] L'informateur est proche de l'hélicoptère. Séparation du groupe.";
        };

        // --- SORTIE DE VÉHICULE ---
        if (vehicle _h != _h) then {
            if (DEBUG_MODE) then { diag_log "[LL][task02b] L'informateur sort de son véhicule."; };
            _h action ["GetOut", vehicle _h];
            unassignVehicle _h;
            moveOut _h;
            sleep 1;
        };

        // --- SÉPARATION DU GROUPE DES JOUEURS ---
        _h setVariable ["LL_Task02b_InHeli", true, true]; // Arrête le doFollow
        _h setUnitPos "UP";
        _h setBehaviour "CARELESS";

        // Rejoindre le groupe de l'hélicoptère pour améliorer le GetIn
        private _heliGrp = group (driver _heli);
        if (!isNull _heliGrp) then {
            [_h] joinSilent _heliGrp;
        } else {
            [_h] joinSilent grpNull;
        };

        _h setCaptive false;
        _h assignAsCargo _heli;
        [_h] orderGetIn true;

        // Aide active au pathfinding d'embarquement
        private _lastGetInActionTime = 0;
        waitUntil {
            sleep 1.5;
            if (!alive _h || !alive _heli) exitWith { true };

            // Anti-blocage si l'informateur remonte dans un mauvais véhicule
            if (vehicle _h != _h && vehicle _h != _heli) then {
                _h action ["GetOut", vehicle _h];
                unassignVehicle _h;
                moveOut _h;
                sleep 0.5;
            };

            private _dist = _h distance2D _heli;
            if (_dist < 40) then {
                _h setUnitPos "UP";
                _h setBehaviour "CARELESS";

                if (assignedVehicle _h != _heli) then {
                    _h assignAsCargo _heli;
                };
                [_h] orderGetIn true;

                if (_dist < 10) then {
                    if (time - _lastGetInActionTime > 4) then {
                        if (unitReady _h) then {
                            _h action ["GetInCargo", _heli];
                            _lastGetInActionTime = time;
                        };
                    };
                };
            };
            vehicle _h == _heli
        };
    };

    // ══════════════════════════════════════════════════════════════════════
    // ATTENTE DE L'EMBARQUEMENT (ou mort de l'informateur)
    // ══════════════════════════════════════════════════════════════════════
    waitUntil {
        sleep 3;
        private _heliRef = missionNamespace getVariable ["LL_HELI_obj", objNull];
        !alive _hostage
        || (!isNull _heliRef && { vehicle _hostage == _heliRef })
    };

    // ══════════════════════════════════════════════════════════════════════
    // COMPLÉTION DE LA TÂCHE
    // ══════════════════════════════════════════════════════════════════════
    if (!alive _hostage) then {
        if (DEBUG_MODE) then { diag_log "[LL][task02b] Informateur tué avant embarquement — tâche FAILED."; };
        ["task_02b_informateur", "FAILED", true] call BIS_fnc_taskSetState;
    } else {
        ["task_02b_informateur", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        if (DEBUG_MODE) then { diag_log "[LL][task02b] Informateur embarqué — tâche SUCCEEDED."; };
        // Marquer comme terminé pour libérer la surveillance de l'hélicoptère
        missionNamespace setVariable ["LL_Task02b_Freed_Done", true, true];
    };

    // Nettoyage des marqueurs
    deleteMarker "LL_mkr_t02b_hostage";
    deleteMarker "LL_mkr_t02b_extraction";
    for "_i" from 0 to 2 do { deleteMarker format ["LL_mkr_t02b_zone_%1", _i]; };

    // ══════════════════════════════════════════════════════════════════════
    // DISSOLUTION DES GARDES SURVIVANTS (TASK_RULES §14)
    // ══════════════════════════════════════════════════════════════════════
    {
        private _grp   = _x;
        private _alive = (units _grp) select { alive _x };

        if (count _alive > 0) then {
            {
                _x enableAI "MOVE";
                _x setBehaviour "SAFE";
                _x setSpeedMode "FULL";
                _x allowFleeing 1;
                _x setVariable ["LL_Task02b_Dissolving", true, true];
            } forEach _alive;

            [_alive, _grp] spawn {
                params ["_units", "_grp"];
                private _alive = _units select { alive _x };
                if (count _alive == 0) exitWith {};
                private _running = true;
                while { _running && ({ alive _x } count _alive) > 0 } do {
                    private _refPos      = getPos (leader _grp);
                    private _dissolvePos = [];
                    private _attempts    = 0;
                    while { count _dissolvePos == 0 && _attempts < 30 } do {
                        _attempts = _attempts + 1;
                        private _candidate = _refPos getPos [200 + random 300, random 360];
                        private _valid = true;
                        { if (_x distance2D _candidate <= 150) exitWith { _valid = false; }; }
                            forEach (allPlayers select { alive _x });
                        if (_valid) then { _dissolvePos = _candidate; };
                    };
                    if (count _dissolvePos == 0) then { _dissolvePos = _refPos getPos [400, random 360]; };
                    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                    private _wp = _grp addWaypoint [_dissolvePos, 5];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "FULL";
                    _wp setWaypointBehaviour "SAFE";
                    waitUntil { sleep 1; ({ alive _x } count _alive) == 0 || (leader _grp distance2D _dissolvePos <= 5) };
                    if (({ alive _x } count _alive) == 0) exitWith { _running = false; };
                    private _allFar = true;
                    { if (_x distance2D _dissolvePos <= 150) exitWith { _allFar = false; }; }
                        forEach (allPlayers select { alive _x });
                    if (_allFar) then {
                        { if (!isNull _x && alive _x) then { deleteVehicle _x; }; } forEach _alive;
                        if (!isNull _grp) then { deleteGroup _grp; };
                        _running = false;
                    };
                };
            };
        };

    } forEach _allGroups;
};
