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
            ["_chief",    objNull, [objNull]],
            ["_guards",   [],      [[]]],
            ["_markerID", "",      [""]]
        ];

        if (isNull _chief) exitWith {};

        // Choix aléatoire du scénario côté serveur (CORRECTIF #6 — MP-safe)
        private _scenario = 1 + floor (random 3);

        // Enregistrer le scénario globalement pour fn_taskManager (branchement task02a/b/c)
        missionNamespace setVariable ["LL_g_task01_scenario", _scenario, true];

        // S'assurer que le camp OPFOR (East) et les Indépendants se considèrent hostiles
        east setFriend [independent, 0];
        independent setFriend [east, 0];

        _chief setVariable ["LL_Task01_Status", "ACTION", true];
        _chief enableAI "ANIM";
        _chief enableAI "MOVE";

        // Supprimer le marqueur Eden
        deleteMarker _markerID;

        switch (_scenario) do {
            // ── Scénario 1 : Coopération ──────────────────────────────────────
            case 1: {
                if (DEBUG_MODE) then { diag_log "[LL] task01: Scénario 1 — Coopération."; };

                // Dégaîner avec animation native — tension immédiate
                _chief action ["SwitchWeapon", _chief, _chief, 0];
                sleep 0.2;

                // Chef armé mais coopératif — parle arme à la main, ne menace pas
                ["STR_LL_Speaker_Chief", "STR_LL_Task_01_S1_Chief"] remoteExec ["LL_fnc_showSubtitle", 0];
                sleep 5;

                ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S1_Success"] remoteExec ["LL_fnc_showSubtitle", 0];
                
                // Succès immédiat
                ["task_01_recon", "SUCCEEDED", true] call BIS_fnc_taskSetState;

                // Il range son arme avant de partir — tension retombée, il n'est plus menaçant
                _chief action ["SwitchWeapon", _chief, _chief, -1];
                sleep 0.5;

                // Le groupe se dirige vers un M_Dans_Bat_XXX à minimum 200m
                // et disparaît dès qu'il arrive à 3m (immersif : entrent dans le bâtiment)
                private _escapeGrp = createGroup [independent, true];
                ([_chief] + _guards) joinSilent _escapeGrp;

                {
                    _x enableAI "MOVE";
                    _x enableAI "ANIM";
                    _x setBehaviour "SAFE";
                    _x setSpeedMode "FULL";
                    _x setVariable ["LL_Task01_Escaping", true, true];
                } forEach ([_chief] + _guards);

                // Dissolution hors de vue (TASK_RULES §14)
                // Le groupe marche vers un point >150m des joueurs, vérifie à l'arrivée,
                // et recommence si un joueur s'est rapproché entre-temps.
                [[_chief] + _guards, _escapeGrp] spawn {
                    params ["_units", "_grp"];
                    private _alive = _units select { alive _x };
                    if (count _alive == 0) exitWith {};

                    private _running = true;
                    while { _running && ({ alive _x } count _alive) > 0 } do {

                        // Chercher un point de dissolution valide (>150m de tous les joueurs)
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

                        // Waypoint vers le point de dissolution
                        while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
                        private _wp = _grp addWaypoint [_dissolvePos, 5];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointSpeed "FULL";
                        _wp setWaypointBehaviour "SAFE";

                        // Attendre l'arrivée à 5m du point
                        waitUntil {
                            sleep 1;
                            ({ alive _x } count _alive) == 0
                            || (leader _grp distance2D _dissolvePos <= 5)
                        };

                        if (({ alive _x } count _alive) == 0) exitWith { _running = false; };

                        // Re-vérifier que les joueurs sont toujours à >150m
                        private _allFar = true;
                        { if (_x distance2D _dissolvePos <= 150) exitWith { _allFar = false; }; }
                            forEach (allPlayers select { alive _x });

                        if (_allFar) then {
                            { if (!isNull _x && alive _x) then { deleteVehicle _x; }; } forEach _alive;
                            if (!isNull _grp) then { deleteGroup _grp; };
                            _running = false;
                        };
                        // Sinon : nouvelle itération avec un nouveau point
                    };
                };
            };

            // ── Scénario 2 : Trahison ─────────────────────────────────────────
            case 2: {
                if (DEBUG_MODE) then { diag_log "[LL] task01: Scénario 2 — Trahison."; };

                // La milice attaque directement sans sommation

                ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S2_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

                // Tout le monde devient hostile (OPFOR) et rejoint le même groupe
                private _hostiles = [_chief] + _guards;
                private _opforGrp = createGroup [east, true];
                _hostiles joinSilent _opforGrp;

                {
                    _x enableAI "ANIM";      // Activer simultanément avec COMBAT — pas de flash holster
                    _x enableAI "MOVE";      // Assure que le déplacement est actif (peut être reseté par joinSilent)
                    _x enableAI "WEAPONAIM"; // Ré-activer la visée IA pour le combat
                    _x setBehaviour "COMBAT";
                    _x setCombatMode "RED";
                    
                    // Réinitialisation globale de l'état d'animation pour sortir proprement d'Acts_CivilTalking_1
                    [_x, ""] remoteExec ["switchMove", 0];
                    
                    // Forcer l'I.A. à sortir son arme principale et à la pointer (évite qu'ils se baladent désarmés)
                    _x selectWeapon (primaryWeapon _x);
                    _x action ["SwitchWeapon", _x, _x, 0];
                } forEach _hostiles;

                // Chaque traître : debout, cible alliée aléatoire toutes les 10s (simulation de recherche)
                {
                    [_x] spawn {
                        params ["_unit"];
                        _unit setUnitPos "UP";  // Force la position debout
                        _unit allowFleeing 0;   // Empêche la fuite
                        sleep 1; // Laisser l'IA s'initialiser en pose combat avant les premiers ordres
                        while { alive _unit } do {
                            private _targets = allPlayers select { side _x == independent && alive _x };
                            if (count _targets > 0) then {
                                private _target = selectRandom _targets;
                                _unit doMove (getPos _target);
                                (group _unit) reveal [_target, 4.0];
                                _unit doTarget _target;  // Orienter vers la cible avant l'ordre de tir
                                _unit doFire _target;
                            };
                            sleep 10;
                        };
                    };
                } forEach _hostiles;

                // Attendre l'élimination de tous les traîtres
                waitUntil {
                    sleep 2;
                    ({ alive _x } count _hostiles) == 0
                };

                ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S2_Success"] remoteExec ["LL_fnc_showSubtitle", 0];
                ["task_01_recon", "SUCCEEDED", true] call BIS_fnc_taskSetState;

                // Nettoyage du groupe OPFOR vide (CORRECTIF #3.2)
                if (!isNull _opforGrp && {count units _opforGrp == 0}) then {
                    deleteGroup _opforGrp;
                };
            };

            // ── Scénario 3 : Mutinerie (CORRECTIF #1 — timing accéléré) ──────
            case 3: {
                if (DEBUG_MODE) then { diag_log "[LL] task01: Scénario 3 — Mutinerie."; };

                // Dégaîner avec animation native — tension immédiate
                _chief action ["SwitchWeapon", _chief, _chief, 0];
                sleep 0.2;

                // Chef avertit — durée réduite à 3s (phrase courte)
                ["STR_LL_Speaker_Chief", "STR_LL_Task_01_S3_Chief"] remoteExec ["LL_fnc_showSubtitle", 0];
                sleep 3; // CORRECTIF #1 : réduit de 5 → 3s

                // Gardes mutins — réponse immédiate, le combat démarre PENDANT l'affichage
                ["STR_LL_Speaker_Guards", "STR_LL_Task_01_S3_Guards"] remoteExec ["LL_fnc_showSubtitle", 0];

                // CHANGEMENT DE CAMP IMMÉDIAT — plus d'attente (CORRECTIF #1)
                private _opforGrp = createGroup [east, true];
                _guards joinSilent _opforGrp;

                {
                    _x enableAI "ANIM";      // CORRECTIF #5 : manquant — obligatoire (TASK_ANIM §6)
                    _x enableAI "MOVE";
                    _x enableAI "WEAPONAIM";
                    _x setBehaviour "COMBAT";
                    _x setCombatMode "RED";
                    _x doFire _chief;
                } forEach _guards;

                // Le chef réagit immédiatement
                private _allyGrp = createGroup [independent, true];
                [_chief] joinSilent _allyGrp;
                _chief enableAI "ANIM";
                _chief enableAI "MOVE";
                _chief enableAI "WEAPONAIM"; // Ré-activer l'acquisition de visée de combat
                _chief setBehaviour "COMBAT";
                _chief setCombatMode "RED";
                _chief setUnitPos "UP";
                _chief allowFleeing 0;
                
                // Réinitialiser proprement l'animation du chef et forcer la mise en garde de combat
                [_chief, ""] remoteExec ["switchMove", 0];
                _chief selectWeapon (primaryWeapon _chief);
                _chief action ["SwitchWeapon", _chief, _chief, 0];

                // Narrateur en parallèle — les tirs ont déjà commencé (CORRECTIF #1)
                sleep 1;
                ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S3_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

                // Boucle du chef : cible un mutin aléatoire vivant toutes les 10s
                // Condition d'arrêt via LL_Task01_ChiefCombatDone (CORRECTIF #3.1)
                [_chief, _guards] spawn {
                    params ["_unit", "_mutins"];
                    while {
                        alive _unit
                        && ({ alive _x } count _mutins) > 0
                        && !(_unit getVariable ["LL_Task01_ChiefCombatDone", false])
                    } do {
                        private _aliveMutins = _mutins select { alive _x };
                        if (count _aliveMutins > 0) then {
                            private _target = selectRandom _aliveMutins;
                            _unit doMove (getPos _target);
                            (group _unit) reveal [_target, 4.0];
                            _unit doTarget _target;
                            _unit doFire _target;
                        };
                        sleep 10;
                    };
                };

                // Chaque mutin : debout, cible aléatoire (joueurs + chef) toutes les 10s
                {
                    [_x, _chief] spawn {
                        params ["_unit", "_chef"];
                        _unit setUnitPos "UP";
                        _unit allowFleeing 0;
                        sleep 1; // Laisser l'IA s'initialiser en pose combat
                        while { alive _unit } do {
                            private _targets = allPlayers select { side _x == independent && alive _x };
                            if (alive _chef) then { _targets pushBack _chef; };
                            if (count _targets > 0) then {
                                private _target = selectRandom _targets;
                                _unit doMove (getPos _target);
                                (group _unit) reveal [_target, 4.0];
                                _unit doTarget _target;
                                _unit doFire _target;
                            };
                            sleep 10;
                        };
                    };
                } forEach _guards;

                // Attendre l'issue du combat
                waitUntil {
                    sleep 2;
                    !alive _chief || ({ alive _x } count _guards) == 0
                };

                if (alive _chief) then {
                    // Succès : le chef a survécu
                    ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S3_Success"] remoteExec ["LL_fnc_showSubtitle", 0];
                    ["task_01_recon", "SUCCEEDED", true] call BIS_fnc_taskSetState;

                    // CORRECTIF #3.1 : Préparer le chef pour task02c
                    _chief setVariable ["LL_Task01_ChiefCombatDone", true, true];
                    _chief setBehaviour "SAFE";
                    _chief setCombatMode "BLUE";
                    _chief setUnitPos "UP";
                    _chief disableAI "MOVE";
                } else {
                    // Échec : le chef a été tué
                    ["STR_LL_Speaker_Narrator", "STR_LL_Task_01_Narrative_S3_Failed"] remoteExec ["LL_fnc_showSubtitle", 0];
                    ["task_01_recon", "FAILED", true] call BIS_fnc_taskSetState;
                };

                // Nettoyage du groupe OPFOR vide
                if (!isNull _opforGrp && {count units _opforGrp == 0}) then {
                    deleteGroup _opforGrp;
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
    private _rawLogics = [];
    {
        if (_x select [0, 11] == "M_Dans_Bat_") then {
            private _val = missionNamespace getVariable [_x, objNull];
            if (!isNull _val) then {
                _rawLogics pushBack _val;
            };
        };
    } forEach (allVariables missionNamespace);

    // Filtrer les logiques : JAMAIS à moins de 100 mètres d'un joueur en vie
    private _players = allPlayers select { alive _x };
    private _logics = [];
    {
        private _logic = _x;
        private _tooClose = false;
        {
            if (_x distance2D _logic < 100) exitWith { _tooClose = true; };
        } forEach _players;
        if (!_tooClose) then {
            _logics pushBack _logic;
        };
    } forEach _rawLogics;

    private _meetingPos = [0, 0, 0];
    private _selectedLogic = objNull;

    if (count _logics > 0) then {
        // Sélectionne une logique aléatoirement si plusieurs existent (JAMAIS à moins de 250 mètres d'un joueur si possible)
        private _logicsFar = [];
        {
            private _logic = _x;
            private _tooClose = false;
            {
                if (_x distance2D _logic < 250) exitWith { _tooClose = true; };
            } forEach _players;
            if (!_tooClose) then {
                _logicsFar pushBack _logic;
            };
        } forEach _logics;
        
        if (count _logicsFar > 0) then {
            _selectedLogic = selectRandom _logicsFar;
        } else {
            _selectedLogic = selectRandom _logics;
        };

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
        // Fallback si aucune logique n'est valide ou trouvée : recherche progressive de bâtiment (de 250 à 1000m)
        private _aliveIndep = allPlayers select { side _x == independent && alive _x };
        private _leaderUnit = leader (group (_aliveIndep select 0));
        private _leaderPos  = getPos _leaderUnit;
        private _candidates = [];

        // Recherche progressive de 250m à 1000m
        for "_radius" from 250 to 1000 step 150 do {
            if (count _candidates == 0) then {
                private _band = nearestTerrainObjects [
                    _leaderPos,
                    ["House", "Building", "HouseBase", "Church", "Ruin"],
                    _radius,
                    false
                ] select {
                    (_x distance2D _leaderPos >= 250)
                    && { (_x buildingPos 0) distance [0,0,0] > 1 }
                };
                if (count _band > 0) then {
                    _candidates = _band;
                };
            };
        };

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

    // ── Spawn des gardes (secondaires avant principal — TASK_RULES §3) ─────────────────
    private _guards    = [];
    private _numGuards = 2 + floor (random 3); // 2 à 4 gardes

    for "_i" from 0 to (_numGuards - 1) do {
        sleep 0.7; // Délai obligatoire entre chaque spawn secondaire (TASK_RULES §3)
        private _gPos  = _meetingPos getPos [6 + random 14, random 360];
        private _gGrp  = createGroup [independent, true];
        private _guard = _gGrp createUnit ["I_G_Soldier_F", [0,0,0], [], 0, "NONE"];

        _guard setPosASL [
            _gPos select 0,
            _gPos select 1,
            (getTerrainHeightASL _gPos) + 0.5
        ];
        _guard allowDamage false;
        [_guard] spawn {
            sleep 3;
            private _u = _this select 0;
            _u allowDamage true;
            // Arme au repos — le garde patrouille détendu sans arme brandisée (TASK_ANIM)
            _u action ["SwitchWeapon", _u, _u, -1];
        };

        // Appliquer le template civil/militia
        _guard setVariable ["LL_forceTemplate", true, true];
        if (!isNil "LL_fnc_applyCivilianTemplate") then {
            [_guard] call LL_fnc_applyCivilianTemplate;
        };

        _guard setBehaviour "CARELESS";  // Patrouille détendue — TASK_ANIM
        _guard setCombatMode "BLUE";
        _guard disableAI "WEAPONAIM";      // Pas d'arme brandisée — TASK_ANIM

        // Patrouille locale autour du lieu de rencontre (rayon 4–18 m, CARELESS — TASK_ANIM)
        [_guard, _meetingPos] spawn {
            params ["_unit", "_center"];
            _unit setSpeedMode "LIMITED";
            while { alive _unit && behaviour _unit != "COMBAT" && !(_unit getVariable ["LL_Task01_Escaping", false]) } do {
                _unit setBehaviour "CARELESS"; // Maintenir l'état détendu à chaque itération
                private _dst = _center getPos [4 + random 14, random 360];
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

    // ── Spawn du chef de milice (principal en dernier — TASK_RULES §3) ────────────
    private _chiefGrp = createGroup [independent, true];
    private _chief    = _chiefGrp createUnit ["I_G_officer_F", [0,0,0], [], 0, "NONE"];

    // Positionnement précis en ASL
    _chief setPosASL _meetingPos;
    
    // Protection temporaire contre les collisions au spawn
    _chief allowDamage false;
    [_chief] spawn {
        sleep 3;
        private _u = _this select 0;
        _u allowDamage true;
        _u action ["SwitchWeapon", _u, _u, -1]; // Ranger l'arme avant de geler l'animation
        sleep 0.5;                               // Laisser l'état de rangement s'appliquer au moteur
        _u disableAI "ANIM";                     // Geler en pose désarmée — évite la pose de combat au spawn
    };

    // Appliquer le template civil/militia
    _chief setVariable ["LL_forceTemplate", true, true];
    if (!isNil "LL_fnc_applyCivilianTemplate") then {
        [_chief] call LL_fnc_applyCivilianTemplate;
    };

    // Comportement d'attente initial — chef statique et silencieux (TASK_ANIM)
    // Pas d'animation de dialogue forcée : le chef attend debout, immobile.
    // disableAI "ANIM" est différé dans le spawn ci-dessus — appliqué APRÈS le rangement de l'arme.
    _chief disableAI "MOVE";
    _chief disableAI "WEAPONAIM"; // Ne vise jamais les joueurs pendant le rendez-vous — arme baissée
    _chief setUnitPos "UP";
    _chief setBehaviour "SAFE";
    _chief setCombatMode "BLUE";
    _chief setVariable ["LL_Task01_Status", "WAIT", true];
    _chief setVariable ["LL_Task01_Chief", true, true]; // Marqueur pour identification par task02c (CORRECTIF #4)

    // Le Chef de milice doit se tourner toutes les 2 secondes vers la position du joueur du serveur le plus proche
    [_chief] spawn {
        params ["_unit"];
        while { alive _unit && { (_unit getVariable ["LL_Task01_Status", "WAIT"]) == "WAIT" } } do {
            private _players = allPlayers select { alive _x };
            if (count _players > 0) then {
                private _nearest = objNull;
                private _minDist = 999999;
                {
                    private _d = _unit distance2D _x;
                    if (_d < _minDist) then {
                        _minDist = _d;
                        _nearest = _x;
                    };
                } forEach _players;

                if (!isNull _nearest) then {
                    private _dir = _unit getDir _nearest;
                    _unit setDir _dir;
                    _unit setFormDir _dir;
                };
            };
            sleep 2;
        };
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

            // Les gardes rejoignent OPFOR et traquent les joueurs
            private _opforGrp = createGroup [east, true];
            _guards joinSilent _opforGrp;
            {
                _x setBehaviour "COMBAT";
                _x setCombatMode "RED";
            } forEach _guards;

            [_opforGrp] spawn {
                params ["_grp"];
                while { !isNull _grp && { ({ alive _x } count units _grp) > 0 } } do {
                    private _players = allPlayers select { side _x == independent && alive _x };
                    if (count _players > 0) then {
                        private _leader = leader _grp;
                        private _nearestPlayer = objNull;
                        private _minDist = 999999;
                        {
                            private _d = _leader distance2D _x;
                            if (_d < _minDist) then {
                                _minDist = _d;
                                _nearestPlayer = _x;
                            };
                        } forEach _players;

                        if (!isNull _nearestPlayer) then {
                            _grp move (getPos _nearestPlayer);
                            _grp reveal [_nearestPlayer, 4.0];
                        };
                    };
                    sleep 15;
                };
            };

            true
        };

        (["task_01_recon"] call BIS_fnc_taskState) in ["SUCCEEDED", "FAILED", "CANCELED"]
    };

    if (DEBUG_MODE) then {
        diag_log format ["[LL] task01: Terminé avec l'état : %1.", ["task_01_recon"] call BIS_fnc_taskState];
    };

    // ── Nettoyage différé après éloignement ────────────────────────────────────
    waitUntil {
        sleep 15;
        private _alivePlayers = allPlayers select { alive _x && side _x == independent };
        if (count _alivePlayers == 0) exitWith { true };
        
        // Tous les joueurs doivent être à plus de 1500m de la position de rencontre (TASK01.md spec)
        private _farFromMeeting = (_alivePlayers findIf { _x distance2D _meetingPos <= 1500 }) == -1;
        
        // Et à plus de 1500m de toutes les unités vivantes de la tâche (sauf celles en fuite)
        private _aliveUnits = ([_chief] + _guards) select { alive _x && !(_x getVariable ["LL_Task01_Escaping", false]) };
        private _farFromUnits = true;
        {
            private _unit = _x;
            if ((_alivePlayers findIf { _x distance2D _unit <= 1500 }) != -1) then {
                _farFromUnits = false;
            };
        } forEach _aliveUnits;

        _farFromMeeting && _farFromUnits
    };

    {
        if (alive _x && !(_x getVariable ["LL_Task01_Escaping", false])) then {
            deleteVehicle _x;
        };
    } forEach ([_chief] + _guards);

    if (DEBUG_MODE) then { diag_log "[LL] task01: Nettoyage des unités de la tâche terminé."; };
};
