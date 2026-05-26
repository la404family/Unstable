#include "..\macros.hpp"

/*
    LL_fnc_task02a

    Description:
      Tâche 02a — "Neutraliser les chefs et récupérer les documents"
      Trois groupes OPFOR (1 chef + 3–5 gardes) patrouillent dans des zones distinctes.
      Un chef tiré au sort détient des documents top secret.
      Les joueurs doivent éliminer les chefs et récupérer les documents.
      Une fois les documents récupérés, les groupes survivants se dissolvent (TASK_RULES §14).

    Points de spawn :
      Utilise les Game Logic M_Dans_Bat_XXX déjà présents dans l'éditeur (minimum 3).
      Position respectée à l'identique (x, y, z + 0.2) — TASK_RULES §3.

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
    private _farSpawns02a = _rawSpawns select { _x distance2D _task01MeetingPos >= 200 };
    if (count _farSpawns02a >= 3) then { _rawSpawns = _farSpawns02a; };

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
        diag_log "[LL][task02a] ERREUR : pas assez de points M_Dans_Bat_XXX (minimum 3 requis dans l'éditeur).";
    };

    // ══════════════════════════════════════════════════════════════════════
    // DÉTENTEUR ALÉATOIRE DES DOCUMENTS (groupe 0, 1 ou 2)
    // ══════════════════════════════════════════════════════════════════════
    private _docHolderIndex = floor random 3;

    if (DEBUG_MODE) then {
        diag_log format ["[LL][task02a] Détenteur des documents : groupe %1", _docHolderIndex];
    };

    // ══════════════════════════════════════════════════════════════════════
    // SPAWN DES 3 GROUPES
    // TASK_RULES §3 : gardes en premier (sleep 0.7 entre chaque), chef en dernier
    // ══════════════════════════════════════════════════════════════════════
    private _allChiefs = [];
    private _allGroups = [];

    for "_i" from 0 to 2 do {

        private _logic    = _selectedSpawns select _i;
        private _spawnPos = getPosASL _logic;
        _spawnPos set [2, (_spawnPos select 2) + 0.2]; // Z + 0.2 — TASK_RULES §3

        private _grp = createGroup [east, true];

        // ── Gardes en premier (TASK_RULES §3) ─────────────────────────────────
        private _numGuards = 3 + floor random 3; // 3 à 5 gardes

        for "_g" from 0 to (_numGuards - 1) do {
            sleep 0.7; // Délai obligatoire entre spawns secondaires — TASK_RULES §3

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

        // ── Chef en dernier (TASK_RULES §3) ───────────────────────────────────
        sleep 0.7;

        private _chief = _grp createUnit ["O_G_officer_F", [0,0,0], [], 0, "NONE"];
        _chief setPosASL _spawnPos;
        _chief allowDamage false;
        [_chief] spawn { sleep 3; (_this select 0) allowDamage true; };

        _chief setVariable ["LL_forceTemplate", true, true];
        if (!isNil "LL_fnc_applyCivilianTemplate") then {
            [_chief] call LL_fnc_applyCivilianTemplate;
        };
        _chief setRank "COLONEL";
        _chief allowFleeing 0;

        // Flag document (seul le détenteur a true)
        _chief setVariable ["LL_Task02a_HasDoc", (_i == _docHolderIndex), true];

        // Comportement initial du groupe (alerte, tir libre)
        _grp setBehaviour "AWARE";
        _grp setCombatMode "RED";

        _allChiefs pushBack _chief;
        _allGroups pushBack _grp;

        // ── Boucle de patrouille (TASK_RULES §11 — ennemi, 4–25m, non-SAFE) ──
        // Capture le snapshot des membres et du centre au moment du spawn
        [units _grp, _spawnPos] spawn {
            params ["_members", "_center"];
            while { ({ alive _x } count _members) > 0 } do {
                {
                    if (alive _x
                        && !(_x getVariable ["LL_Task02a_Dissolving", false])
                        && behaviour _x != "COMBAT"
                    ) then {
                        _x doMove (_center getPos [4 + random 21, random 360]);
                    };
                } forEach _members;
                sleep (12 + random 18);
            };
        };

        // Marqueur carte rouge pour ce groupe
        private _mkrName = format ["LL_mkr_t02a_%1", _i];
        createMarker [_mkrName, getPos _chief];
        _mkrName setMarkerType "mil_destroy";
        _mkrName setMarkerColor "ColorRed";
        _mkrName setMarkerText format [localize "STR_LL_Task_02a_Target", _i + 1];
    };

    // ══════════════════════════════════════════════════════════════════════
    // CRÉATION DE LA TÂCHE BIS (TASK_RULES §7)
    // ══════════════════════════════════════════════════════════════════════
    [
        independent,
        ["task_02a_cache"],
        [
            localize "STR_LL_Task_02a_Desc",
            localize "STR_LL_Task_02a_Title",
            localize "STR_LL_Task_02a_Marker"
        ],
        objNull,  // Pas de marqueur de destination — marqueurs carte seuls (TASK_RULES §7)
        "AUTOASSIGNED",
        5,
        true,
        "kill"
    ] call BIS_fnc_taskCreate;

    ["STR_LL_Speaker_Narrator", "STR_LL_Task_02a_Narrative_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

    // ══════════════════════════════════════════════════════════════════════
    // SURVEILLANCE — chefs sans documents : retirer marqueur à leur mort
    // ══════════════════════════════════════════════════════════════════════
    missionNamespace setVariable ["LL_Task02a_DocPickedUp", false, true];

    private _docHolder = _allChiefs select _docHolderIndex;

    {
        private _chief = _x;
        private _idx   = _foreachIndex;
        if (_chief != _docHolder) then {
            [_chief, _idx] spawn {
                params ["_unit", "_i"];
                waitUntil { sleep 1; !alive _unit };
                deleteMarker format ["LL_mkr_t02a_%1", _i];
                if (DEBUG_MODE) then {
                    diag_log format ["[LL][task02a] Chef %1 éliminé (pas de documents).", _i];
                };
            };
        };
    } forEach _allChiefs;

    // ══════════════════════════════════════════════════════════════════════
    // ATTENTE DE LA MORT DU DÉTENTEUR → APPARITION DES DOCUMENTS
    // ══════════════════════════════════════════════════════════════════════
    waitUntil { sleep 1; !alive _docHolder };

    if (DEBUG_MODE) then {
        diag_log "[LL][task02a] Détenteur éliminé — apparition des documents sur le corps.";
    };

    // Spawn de l'objet document sur le corps
    private _bodyPos = getPosASL _docHolder;
    private _docObj  = createVehicle [
        "Land_Document_01_F",
        [_bodyPos select 0, _bodyPos select 1, (_bodyPos select 2) + 0.1],
        [], 0, "CAN_COLLIDE"
    ];

    // Marqueur blanc sur le document (carte uniquement — pas de marqueur 3D, TASK_RULES §7)
    createMarker ["LL_mkr_t02a_doc", getPos _docHolder];
    "LL_mkr_t02a_doc" setMarkerType "mil_objective";
    "LL_mkr_t02a_doc" setMarkerColor "ColorWhite";
    "LL_mkr_t02a_doc" setMarkerText localize "STR_LL_Task_02a_Doc";

    ["STR_LL_Speaker_Narrator", "STR_LL_Task_02a_Narrative_DocFound"] remoteExec ["LL_fnc_showSubtitle", 0];

    // Déployer l'addAction de ramassage sur tous les clients (TASK_RULES §5)
    [_docHolder, _docObj] remoteExec ["LL_fnc_task02a_addAction", 0];

    // ══════════════════════════════════════════════════════════════════════
    // ATTENTE DU RAMASSAGE DES DOCUMENTS
    // ══════════════════════════════════════════════════════════════════════
    waitUntil {
        sleep 1;
        missionNamespace getVariable ["LL_Task02a_DocPickedUp", false]
    };

    // ── Nettoyage des marqueurs ────────────────────────────────────────────
    deleteMarker "LL_mkr_t02a_doc";
    for "_i" from 0 to 2 do { deleteMarker format ["LL_mkr_t02a_%1", _i]; };
    if (!isNull _docObj) then { deleteVehicle _docObj; };

    // ── Complétion de la tâche ────────────────────────────────────────────
    ["task_02a_cache", "SUCCEEDED", true] call BIS_fnc_taskSetState;
    ["STR_LL_Speaker_Narrator", "STR_LL_Task_02a_Narrative_Success"] remoteExec ["LL_fnc_showSubtitle", 0];

    if (DEBUG_MODE) then {
        diag_log "[LL][task02a] Documents récupérés — tâche SUCCEEDED.";
    };

    // ══════════════════════════════════════════════════════════════════════
    // DISSOLUTION DES GROUPES SURVIVANTS (TASK_RULES §14)
    // S'applique aux 3 groupes : gardes du détenteur encore en vie inclus
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
                _x setVariable ["LL_Task02a_Dissolving", true, true];
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

                    if (count _dissolvePos == 0) then {
                        _dissolvePos = _refPos getPos [400, random 360];
                    };

                    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                    private _wp = _grp addWaypoint [_dissolvePos, 5];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "FULL";
                    _wp setWaypointBehaviour "SAFE";

                    waitUntil {
                        sleep 1;
                        ({ alive _x } count _alive) == 0
                        || (leader _grp distance2D _dissolvePos <= 5)
                    };

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
