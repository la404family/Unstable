#include "..\macros.hpp"

/*
    Author: La Légion
    Description:
      Tâche 01 — Rendez-vous de reconnaissance.
      Le groupe doit localiser et rejoindre un chef de milice local réfugié
      dans un bâtiment désigné par l'un des objets Game Logic "M_Dans_Bat_XXX".

      Trois scénarios possibles lors de l'interaction (décidés aléatoirement) :
        1. Coopération — Le chef donne les infos. → Tâche réussie.
        2. Trahison    — Le chef et ses gardes deviennent hostiles (OPFOR). → Tâche réussie après élimination.
        3. Mutinerie   — Les gardes deviennent hostiles (OPFOR) et attaquent le chef (allié) et les joueurs.
                         → Tâche réussie si le chef survit.
                         → Tâche échouée si le chef meurt.

    Parameter(s):
      0: STRING - Mode d'appel ("init" pour le lancement initial ou "scenario" pour le callback d'interaction)
      1: ARRAY  - Arguments spécifiques au mode

    Returns:
      None

    Locality:
      Server only (isServer)
*/

params [
    ["_mode", "init", [""]],
    ["_args", [], [[]]]
];

if (!isServer) exitWith {};

// ══════════════════════════════════════════════════════════════════════════════
// SCÉNARIO CALLBACK (Exécuté côté serveur après l'interaction du joueur)
// ══════════════════════════════════════════════════════════════════════════════
if (_mode == "scenario") exitWith {
    _args spawn {
        params [
            ["_scenario", 1,      [0]],
            ["_chief",    objNull, [objNull]],
            ["_guards",   [],      [[]]],
            ["_markerID", "",      [""]]
        ];

        if (isNull _chief) exitWith {};

        // S'assurer que le camp OPFOR (East) et les Indépendants se considèrent hostiles
        east setFriend [independent, 0];
        independent setFriend [east, 0];

        _chief setVariable ["LL_Task01_Status", "ACTION", true];
        _chief enableAI "ANIM";
        _chief enableAI "MOVE";
        _chief switchMove "";

        // Supprimer le marqueur Eden
        deleteMarker _markerID;

        switch (_scenario) do {
            // ── Scénario 1 : Coopération ──────────────────────────────────────
            case 1: {
                if (DEBUG_MODE) then { diag_log "[LL] task01: Scénario 1 — Coopération."; };

                // Dialogue bilingue via sous-titres
                ["STR_LL_Speaker_Chief", "STR_LL_Task_01_S1_Chief"] remoteExec ["LL_fnc_showSubtitle", 0];
                sleep 5;

                ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S1_Success"] remoteExec ["LL_fnc_showSubtitle", 0];
                
                // Les gardes restent amicaux et arrêtent leurs patrouilles
                { _x disableAI "MOVE"; } forEach _guards;

                ["task_01_recon", "SUCCEEDED", true] call BIS_fnc_taskSetState;
            };

            // ── Scénario 2 : Trahison ─────────────────────────────────────────
            case 2: {
                if (DEBUG_MODE) then { diag_log "[LL] task01: Scénario 2 — Trahison."; };

                ["STR_LL_Speaker_Chief", "STR_LL_Task_01_S2_Chief"] remoteExec ["LL_fnc_showSubtitle", 0];
                sleep 5;

                ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S2_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

                // Tout le monde devient hostile (OPFOR)
                private _hostiles = [_chief] + _guards;
                {
                    private _grp = createGroup [east, true];
                    [_x] joinSilent _grp;
                    _x setBehaviour "COMBAT";
                    _x setCombatMode "RED";
                } forEach _hostiles;

                // Engager les joueurs à proximité
                private _targets = allPlayers select { side _x == independent && alive _x };
                if (count _targets > 0) then {
                    { _x doFire (selectRandom _targets); } forEach _hostiles;
                };

                // Attendre l'élimination de tous les traîtres
                waitUntil {
                    sleep 2;
                    ({ alive _x } count _hostiles) == 0
                };

                ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S2_Success"] remoteExec ["LL_fnc_showSubtitle", 0];
                ["task_01_recon", "SUCCEEDED", true] call BIS_fnc_taskSetState;
            };

            // ── Scénario 3 : Mutinerie ────────────────────────────────────────
            case 3: {
                if (DEBUG_MODE) then { diag_log "[LL] task01: Scénario 3 — Mutinerie."; };

                ["STR_LL_Speaker_Chief", "STR_LL_Task_01_S3_Chief"] remoteExec ["LL_fnc_showSubtitle", 0];
                sleep 5;

                ["STR_LL_Speaker_Guards", "STR_LL_Task_01_S3_Guards"] remoteExec ["LL_fnc_showSubtitle", 0];
                sleep 5;

                ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S3_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

                // Les gardes deviennent mutins (OPFOR) et attaquent le chef et les joueurs
                {
                    private _grp = createGroup [east, true];
                    [_x] joinSilent _grp;
                    _x setBehaviour "COMBAT";
                    _x setCombatMode "RED";
                    _x doFire _chief;
                } forEach _guards;

                // Le chef rejoint le camp des joueurs (Independent) et se défend
                private _allyGrp = createGroup [independent, true];
                [_chief] joinSilent _allyGrp;
                _chief setBehaviour "COMBAT";
                _chief setCombatMode "RED";

                // Attendre l'issue du combat
                waitUntil {
                    sleep 2;
                    !alive _chief || ({ alive _x } count _guards) == 0
                };

                if (alive _chief) then {
                    // Succès : le chef a survécu
                    ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S3_Success"] remoteExec ["LL_fnc_showSubtitle", 0];
                    ["task_01_recon", "SUCCEEDED", true] call BIS_fnc_taskSetState;
                } else {
                    // Échec : le chef a été tué
                    ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S3_Failed"] remoteExec ["LL_fnc_showSubtitle", 0];
                    ["task_01_recon", "FAILED", true] call BIS_fnc_taskSetState;
                };
            };
        };
    };
};

// ══════════════════════════════════════════════════════════════════════════════
// INITIALISATION DE LA TÂCHE (Lancement initial depuis fn_taskManager)
// ══════════════════════════════════════════════════════════════════════════════
[] spawn {
    // Attendre qu'au moins un joueur indépendant soit actif
    waitUntil {
        sleep 2;
        (count (allPlayers select { side _x == independent && alive _x })) > 0
    };

    // ── Détection dynamique des logiques "M_Dans_Bat_XXX" ─────────────────────────
    private _logics = [];
    {
        if (_x select [0, 11] == "M_Dans_Bat_") then {
            private _val = missionNamespace getVariable [_x, objNull];
            if (!isNull _val) then {
                _logics pushBack _val;
            };
        };
    } forEach (allVariables missionNamespace);

    private _meetingPos = [0, 0, 0];
    private _selectedLogic = objNull;

    if (count _logics > 0) then {
        _selectedLogic = selectRandom _logics;
        private _logicPos = getPosASL _selectedLogic;
        
        // Z + 0.2m pour éviter le clipping dans le sol/bâtiment
        _meetingPos = [
            _logicPos select 0,
            _logicPos select 1,
            (_logicPos select 2) + 0.2
        ];
        if (DEBUG_MODE) then {
            diag_log format ["[LL] task01: Logique de rencontre sélectionnée : %1 à %2.", vehicleVarName _selectedLogic, _meetingPos];
        };
    } else {
        // Fallback si aucune logique n'est définie : recherche de bâtiment
        private _aliveIndep = allPlayers select { side _x == independent && alive _x };
        private _leaderUnit = leader (group (_aliveIndep select 0));
        private _leaderPos  = getPos _leaderUnit;
        private _candidates = [];

        {
            if (count _candidates == 0) then {
                private _tryMin = _x + floor (random 601);
                private _tryMax = _tryMin + 400;
                private _band = nearestTerrainObjects [
                    _leaderPos,
                    ["House", "Building", "HouseBase", "Church", "Ruin"],
                    _tryMax,
                    false
                ] select {
                    (_x distance2D _leaderPos >= _tryMin)
                    && { (_x buildingPos 0) distance [0,0,0] > 1 }
                };
                if (count _band > 0) then {
                    _candidates = _band;
                };
            };
        } forEach [300, 200, 250, 200, 150];

        if (count _candidates > 0) then {
            private _building = selectRandom _candidates;
            private _bPos = _building buildingPos 0;
            _meetingPos = [
                _bPos select 0,
                _bPos select 1,
                (_bPos select 2) + 0.2
            ];
            if (DEBUG_MODE) then {
                diag_log format ["[LL] task01: Fallback sur le bâtiment %1 à %2.", typeOf _building, _meetingPos];
            };
        } else {
            // Ultime fallback statique au cas où
            _meetingPos = [2300, 2300, 0.2];
            if (DEBUG_MODE) then {
                diag_log "[LL] task01: Alerte — Aucun bâtiment trouvé, position statique utilisée.";
            };
        };
    };

    // Publier la position globale pour d'éventuelles futures tâches
    LL_g_usedTaskPos = [_meetingPos];
    publicVariable "LL_g_usedTaskPos";

    // ── Notification QG ──────────────────────────────────────────────────────────
    ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_Meeting"] remoteExec ["LL_fnc_showSubtitle", 0];

    // ── Spawn du chef de milice ──────────────────────────────────────────────────
    private _chiefGrp = createGroup [independent, true];
    private _chief    = _chiefGrp createUnit ["I_G_officer_F", [0,0,0], [], 0, "NONE"];

    // Positionnement précis en ASL
    _chief setPosASL _meetingPos;
    
    // Protection temporaire contre les collisions au spawn
    _chief allowDamage false;
    [_chief] spawn { sleep 3; (_this select 0) allowDamage true; };

    // Appliquer le template civil/militia
    _chief setVariable ["LL_forceTemplate", true, true];
    if (!isNil "LL_fnc_applyCivilianTemplate") then {
        [_chief] call LL_fnc_applyCivilianTemplate;
    };

    // Comportement d'attente initial
    _chief disableAI "MOVE";
    _chief disableAI "ANIM";
    _chief setUnitPos "UP";
    _chief switchMove "Acts_CivilTalking_1";
    _chief setBehaviour "SAFE";
    _chief setCombatMode "BLUE";
    _chief setVariable ["LL_Task01_Status", "WAIT", true];

    _chief addEventHandler ["AnimDone", {
        params ["_unit"];
        if (alive _unit && (_unit getVariable ["LL_Task01_Status", "WAIT"] == "WAIT")) then {
            _unit switchMove "Acts_CivilTalking_1";
        };
    }];

    // ── Spawn des gardes ────────────────────────────────────────────────────────
    private _guards    = [];
    private _numGuards = 2 + floor (random 3); // 2 à 4 gardes

    for "_i" from 0 to (_numGuards - 1) do {
        private _gPos  = _meetingPos getPos [6 + random 14, random 360];
        private _gGrp  = createGroup [independent, true];
        private _guard = _gGrp createUnit ["I_G_Soldier_F", [0,0,0], [], 0, "NONE"];

        _guard setPosASL [
            _gPos select 0,
            _gPos select 1,
            (getTerrainHeightASL _gPos) + 0.5
        ];
        _guard allowDamage false;
        [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };

        // Appliquer le template civil/militia
        _guard setVariable ["LL_forceTemplate", true, true];
        if (!isNil "LL_fnc_applyCivilianTemplate") then {
            [_guard] call LL_fnc_applyCivilianTemplate;
        };

        _guard setBehaviour "SAFE";
        _guard setCombatMode "BLUE";

        // Patrouille locale autour du lieu de rencontre
        [_guard, _meetingPos] spawn {
            params ["_unit", "_center"];
            _unit setSpeedMode "LIMITED";
            while { alive _unit && behaviour _unit != "COMBAT" } do {
                private _dst = _center getPos [4 + random 18, random 360];
                _unit doMove _dst;
                waitUntil {
                    sleep 1;
                    !alive _unit
                    || _unit distance2D _dst < 2
                    || unitReady _unit
                    || behaviour _unit == "COMBAT"
                };
                sleep (12 + random 20);
            };
        };

        _guards pushBack _guard;
    };

    // ── Marqueur de tâche carte ───────────────────────────────────────────────
    private _markerID = "LL_task01_rdv";
    deleteMarker _markerID;
    createMarker [_markerID, _meetingPos];
    _markerID setMarkerType "mil_warning";
    _markerID setMarkerColor "ColorOrange";
    _markerID setMarkerText (localize "STR_LL_Task_01_Marker");

    // ── Création de la tâche Framework Arma ──────────────────────────────────────
    [
        independent,
        ["task_01_recon"],
        [
            localize "STR_LL_Task_01_Desc",
            localize "STR_LL_Task_01_Title",
            localize "STR_LL_Task_01_Marker"
        ],
        _meetingPos,
        "AUTOASSIGNED",
        5,
        true,
        "meet"
    ] call BIS_fnc_taskCreate;

    if (DEBUG_MODE) then {
        diag_log "[LL] task01: Tâche créée et assignée aux indépendants.";
    };

    missionNamespace setVariable ["LL_Task01_Triggered", false, true];

    // Envoyer l'action d'interaction à tous les clients (JIP compatible via identifiant unique)
    [_chief, _guards, _markerID] remoteExec ["LL_fnc_task01_addAction", 0, str _chief];

    // ── Surveillance de mort anticipée avant interaction ───────────────────────
    waitUntil {
        sleep 5;

        if (!alive _chief && !(missionNamespace getVariable ["LL_Task01_Triggered", false])) exitWith {
            if (DEBUG_MODE) then {
                diag_log "[LL] task01: Chef éliminé avant contact. Tâche échouée.";
            };
            ["task_01_recon", "FAILED", true] call BIS_fnc_taskSetState;
            deleteMarker _markerID;
            true
        };

        (["task_01_recon"] call BIS_fnc_taskState) in ["SUCCEEDED", "FAILED", "CANCELED"]
    };

    if (DEBUG_MODE) then {
        diag_log format ["[LL] task01: Terminé avec l'état : %1.", ["task_01_recon"] call BIS_fnc_taskState];
    };

    // ── Nettoyage différé après éloignement ────────────────────────────────────
    waitUntil {
        sleep 10;
        private _alive = allPlayers select { alive _x && side _x == independent };
        if (count _alive == 0) exitWith { true };
        (_alive select 0) distance2D _meetingPos > 1500
    };

    { if (alive _x) then { deleteVehicle _x; }; } forEach ([_chief] + _guards);

    if (DEBUG_MODE) then { diag_log "[LL] task01: Nettoyage des unités de la tâche terminé."; };
};
