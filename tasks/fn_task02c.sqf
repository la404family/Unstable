#include "..\macros.hpp"

/*
    LL_fnc_task02c

    Description:
      Tâche 02c — "L'Intermédiaire"
      Déclenchée après task01 Scénario 3 (Mutinerie — chef de milice vivant).

      Le chef de milice, ayant survécu à la mutinerie et rejoint le groupe,
      révèle la position d'un intermédiaire financier indépendant qui coordonne
      les flux d'argent entre les milices et les cartels locaux de Porto.

      L'intermédiaire doit être capturé vivant — sa mort compromet toute
      remontée de la chaîne logistique. Il connaît les noms, les lieux de
      stockage et les prochains transferts.

      SUCCEEDED : Intermédiaire capturé et sous escorte.
      FAILED    : Intermédiaire tué avant capture.

    Points de spawn :
      Utilise les Game Logic M_Dans_Bat_XXX présents dans l'éditeur.

    Locality:
      Serveur uniquement (isServer)
*/

params [
    ["_mode", "init", [""]],
    ["_args", [], [[]]]
];

if (!isServer) exitWith {};

// ══════════════════════════════════════════════════════════════════════════════
// MODE "chief_talk" — déclenché par le client après interaction avec le chef
// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
// MODE "capture_anim" — déclenché par le client après interaction de capture
// Gère l'animation d'arrestation server-side (bonne locality de l'unité)
// ══════════════════════════════════════════════════════════════════════════════
if (_mode == "capture_anim") exitWith {
    _args spawn {
        params [["_h", objNull, [objNull]]];
        if (isNull _h || !alive _h) exitWith {};
        if (missionNamespace getVariable ["LL_Task02c_Captured", false]) exitWith {};

        // Stopper la boucle d'attente (TASK_RULES §4)
        _h setVariable ["LL_Task02c_Status", "ACTION", true];
        _h removeAllEventHandlers "AnimDone";

        // Animation d'arrestation — exécutée sur le serveur (locality correcte)
        // Pas de setUnitPos qui briserait la pose de l'animation
        _h disableAI "MOVE";
        _h disableAI "ANIM";
        _h switchMove "Acts_ExecutionVictim_Loop";
        sleep 0.3;

        // Boucle persistante de l'état d'arrestation via AnimDone EH
        _h addEventHandler ["AnimDone", {
            params ["_unit"];
            // Loop l'animation tant que le statut est "ACTION" (captif en attente de récupération)
            if (alive _unit && (_unit getVariable ["LL_Task02c_Status", ""]) == "ACTION") then {
                _unit switchMove "Acts_ExecutionVictim_Loop";
            };
        }];

        missionNamespace setVariable ["LL_Task02c_Captured", true, true];

        if (DEBUG_MODE) then {
            diag_log "[LL][task02c] capture_anim : animation d'arrestation déclenchée (server-side) — LL_Task02c_Captured = true.";
        };
    };
};

if (_mode == "chief_talk") exitWith {
    _args spawn {
        params [["_chief", objNull, [objNull]]];
        if (isNull _chief || !alive _chief) exitWith {};

        _chief setVariable ["LL_Task02c_Status", "ACTION", true];
        _chief enableAI "ANIM";

        // --- VOIX NATIVE IMMERSIVE (le chef parle en perse nativement) ---
        private _chiefGrp = group _chief;
        private _dummy = _chiefGrp createUnit ["I_G_Soldier_F", getPos _chief, [], 0, "NONE"];
        _dummy hideObjectGlobal true;
        _dummy allowDamage false;
        _dummy disableAI "ALL";
        _chiefGrp selectLeader _chief;

        // Le chef "donne un ordre" au fantôme → voix native !
        _dummy commandMove (_chief getPos [500, random 360]);

        ["STR_LL_Speaker_Chief", "STR_LL_Task_02c_Chief_Intel"] remoteExec ["LL_fnc_showSubtitle", 0];
        sleep 6;

        // Deuxième phrase vocale native
        _dummy commandMove (_chief getPos [800, random 360]);

        ["STR_LL_Speaker_Narrator", "STR_LL_Task_02c_Narrative_Start"] remoteExec ["LL_fnc_showSubtitle", 0];
        sleep 5;

        deleteVehicle _dummy; // Nettoyage du fantôme

        // Signal : le chef a parlé
        missionNamespace setVariable ["LL_Task02c_ChiefTalked", true, true];

        // CORRECTIF : Libérer le chef de sa boucle d'animation
        [_chief, ""] remoteExec ["switchMove", 0];
        _chief enableAI "MOVE";
        _chief enableAI "ANIM";
        _chief setVariable ["LL_Task02c_Status", "DONE", true];

        if (DEBUG_MODE) then {
            diag_log "[LL][task02c] Dialogue chef terminé — LL_Task02c_ChiefTalked = true.";
        };
    };
};

// ══════════════════════════════════════════════════════════════════════════════
// INITIALISATION — lancé depuis fn_taskManager
// ══════════════════════════════════════════════════════════════════════════════
[] spawn {

    // Attendre qu'au moins un joueur indépendant soit actif
    waitUntil {
        sleep 2;
        (count (allPlayers select { side _x == independent && alive _x })) > 0
    };

    // ══════════════════════════════════════════════════════════════════════
    // LOCALISER LE CHEF DE MILICE
    // Survivant de task01 scénario 3 — I_G_officer_F, côté independent, non-joueur
    // ══════════════════════════════════════════════════════════════════════
    // CORRECTIF #4 : Recherche par variable dédiée au lieu de typeOf (plus robuste)
    private _chief = objNull;
    {
        if (!isPlayer _x && (_x getVariable ["LL_Task01_Chief", false]) && alive _x) exitWith {
            _chief = _x;
        };
    } forEach allUnits;

    if (isNull _chief) exitWith {
        diag_log "[LL][task02c] ERREUR : chef de milice introuvable (I_G_officer_F / independent / alive).";
    };

    // ══════════════════════════════════════════════════════════════════════
    // INITIALISER LES VARIABLES GLOBALES
    // ══════════════════════════════════════════════════════════════════════
    missionNamespace setVariable ["LL_Task02c_ChiefTalked",    false, true];
    missionNamespace setVariable ["LL_Task02c_Captured",       false, true];
    missionNamespace setVariable ["LL_Task02c_ActionAdded",    false, true];
    missionNamespace setVariable ["LL_Task02c_ChiefTriggered", false, true];
    missionNamespace setVariable ["LL_Task02c_CaptureAdded",   false, true];

    // ══════════════════════════════════════════════════════════════════════
    // METTRE LE CHEF EN ATTENTE D'INTERACTION (TASK_RULES §4)
    // ══════════════════════════════════════════════════════════════════════
    // CORRECTIF #7.2 : Transition douce depuis le mode COMBAT de task01 S3
    _chief setBehaviour "SAFE";
    sleep 1;
    _chief action ["SwitchWeapon", _chief, _chief, -1]; // Ranger l'arme
    sleep 1;
    _chief disableAI "MOVE";
    _chief disableAI "ANIM";
    _chief setUnitPos "UP";
    _chief switchMove "Acts_CivilTalking_1";
    _chief setVariable ["LL_Task02c_Status", "WAIT", true];

    _chief addEventHandler ["AnimDone", {
        params ["_unit"];
        if (alive _unit && (_unit getVariable ["LL_Task02c_Status", "WAIT"]) == "WAIT") then {
            _unit switchMove "Acts_CivilTalking_1";
        };
    }];

    // Rotation vers le joueur le plus proche (TASK_RULES §4)
    [_chief] spawn {
        params ["_u"];
        while { alive _u && (_u getVariable ["LL_Task02c_Status", "WAIT"]) == "WAIT" } do {
            private _nearest = objNull;
            private _minDist = 99999;
            {
                if (alive _x) then {
                    private _d = _u distance2D _x;
                    if (_d < _minDist) then { _minDist = _d; _nearest = _x; };
                };
            } forEach allPlayers;
            if (!isNull _nearest) then {
                private _dir = _u getDir _nearest;
                _u setDir _dir;
                _u setFormDir _dir; // CORRECTIF #9 : empêche l'IA de re-pivoter
            };
            sleep 2;
        };
    };

    // Déployer l'addAction "Interroger le chef" sur tous les clients
    ["chief", _chief] remoteExec ["LL_fnc_task02c_addAction", 0];

    // ══════════════════════════════════════════════════════════════════════
    // INTERMÉDIAIRE : CRÉATION DU MARQUEUR ET DE LA TÂCHE DE TRANSITION "PARLER"
    // ══════════════════════════════════════════════════════════════════════
    createMarker ["LL_mkr_t02c_chief", getPos _chief];
    "LL_mkr_t02c_chief" setMarkerType "mil_join";
    "LL_mkr_t02c_chief" setMarkerColor "ColorBlue";
    "LL_mkr_t02c_chief" setMarkerText localize "STR_LL_Task_01_Action";

    [
        independent,
        ["task_02c_talk_chief"],
        [
            localize "STR_LL_Task_01_Action",
            localize "STR_LL_Task_01_Action",
            ""
        ],
        _chief, // Associer directement la tâche à l'unité (suit automatiquement l'objet sans spam de notification)
        "AUTOASSIGNED",
        5,
        true,
        "meet"
    ] call BIS_fnc_taskCreate;

    // Mettre à jour uniquement le marqueur carte sur le mouvement du chef (le chef est statique mais peut pivoter)
    [_chief] spawn {
        params ["_c"];
        private _lastPos = [0,0,0];
        while { alive _c && !(missionNamespace getVariable ["LL_Task02c_ChiefTalked", false]) } do {
            private _curPos = getPos _c;
            if (_curPos distance2D _lastPos > 1) then {
                "LL_mkr_t02c_chief" setMarkerPos _curPos;
                _lastPos = _curPos;
            };
            sleep 4;
        };
    };

    if (DEBUG_MODE) then {
        diag_log "[LL][task02c] Chef stoppé en attente — addAction et tâche intermédiaire 'Parler au chef' créées.";
    };

    // ══════════════════════════════════════════════════════════════════════
    // ATTENDRE QUE LE CHEF AIT PARLÉ
    // ══════════════════════════════════════════════════════════════════════
    waitUntil {
        sleep 1;
        (missionNamespace getVariable ["LL_Task02c_ChiefTalked", false]) || !alive _chief
    };

    deleteMarker "LL_mkr_t02c_chief";
    if ("task_02c_talk_chief" call BIS_fnc_taskExists) then {
        if (alive _chief) then {
            ["task_02c_talk_chief", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        } else {
            ["task_02c_talk_chief", "CANCELED", true] call BIS_fnc_taskSetState;
        };
    };

    if (!alive _chief) exitWith {
        if (DEBUG_MODE) then {
            diag_log "[LL][task02c] Avertissement : le chef est mort avant de donner les coordonnées.";
        };
    };

    // ══════════════════════════════════════════════════════════════════════
    // POINT DE SPAWN — Game Logic M_Dans_Bat_XXX
    // Sélectionné à plus de 100m de tous les joueurs (TASK_RULES §8)
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
    private _farSpawns02c = _rawSpawns select { _x distance2D _task01MeetingPos >= 200 };
    if (count _farSpawns02c >= 1) then { _rawSpawns = _farSpawns02c; };

    private _players = allPlayers select { alive _x };
    private _spawnLogic = objNull;
    {
        private _logic = _x;
        private _tooClose = false;
        {
            if (_x distance2D _logic < 100) exitWith { _tooClose = true; };
        } forEach _players;
        if (!_tooClose && isNull _spawnLogic) then {
            _spawnLogic = _logic;
        };
    } forEach _rawSpawns;

    if (isNull _spawnLogic) exitWith {
        diag_log "[LL][task02c] ERREUR : aucun point M_Dans_Bat_XXX disponible (tous à < 100m des joueurs).";
    };

    private _spawnPos = getPosASL _spawnLogic;
    _spawnPos set [2, (_spawnPos select 2) + 0.2]; // Z + 0.2 — TASK_RULES §3

    if (DEBUG_MODE) then {
        diag_log format ["[LL][task02c] Point de spawn intermédiaire : %1", _spawnPos];
    };

    // ══════════════════════════════════════════════════════════════════════
    // SPAWN DES HOMMES DE MAIN
    // Gardes en premier (TASK_RULES §3) — 3 à 5, OPFOR, patrouille 4–25m
    // ══════════════════════════════════════════════════════════════════════
    private _grp       = createGroup [east, true];
    private _numGuards = 3 + floor random 3; // 3 à 5

    for "_i" from 0 to (_numGuards - 1) do {
        sleep 0.7; // Délai entre spawns secondaires — TASK_RULES §3

        private _gPos  = _spawnPos getPos [4 + random 21, random 360];
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
        _guard setBehaviour "AWARE";
        _guard setCombatMode "RED";
    };

    private _allGuards = units _grp;

    // Patrouille locale des gardes (TASK_RULES §11 — ennemi, 4–25m, non-SAFE)
    [_allGuards, _spawnPos] spawn {
        params ["_members", "_center"];
        while { ({ alive _x } count _members) > 0 } do {
            {
                if (alive _x
                    && !(_x getVariable ["LL_Task02c_Dissolving", false])
                    && behaviour _x != "COMBAT"
                ) then {
                    _x doMove (_center getPos [4 + random 21, random 360]);
                };
            } forEach _members;
            sleep (10 + random 15);
        };
    };

    // ══════════════════════════════════════════════════════════════════════
    // SPAWN DE L'INTERMÉDIAIRE — principal en dernier (TASK_RULES §3)
    // Civil non armé — C_Man_1_1_F
    // ══════════════════════════════════════════════════════════════════════
    sleep 0.7;

    private _civGrp = createGroup [civilian, true];
    private _h      = _civGrp createUnit ["C_Man_1_1_F", [0,0,0], [], 0, "NONE"];

    // CORRECTIF : Empêcher le chargement automatique de l'équipement joueur
    _h setVariable ["LL_LoadoutSet", true, true];

    _h setPosASL _spawnPos;
    _h allowDamage false;
    [_h] spawn { sleep 3; (_this select 0) allowDamage true; };

    // Désarmer (pas un combattant)
    removeAllWeapons _h;
    removeAllItems _h;
    removeAllAssignedItems _h;
    clearAllItemsFromBackpack _h;

    // Désactiver le ciblage ennemi — civil passif
    _h disableAI "TARGET";
    _h disableAI "AUTOTARGET";

    // Comportement d'attente (TASK_RULES §4)
    _h disableAI "MOVE";
    _h disableAI "ANIM";
    _h setUnitPos "UP";
    _h switchMove "Acts_CivilTalking_1";
    _h setVariable ["LL_Task02c_Status", "WAIT", true];

    _h addEventHandler ["AnimDone", {
        params ["_unit"];
        if (alive _unit && (_unit getVariable ["LL_Task02c_Status", "WAIT"]) == "WAIT") then {
            _unit switchMove "Acts_CivilTalking_1";
        };
    }];

    // Rotation vers le joueur le plus proche (TASK_RULES §4)
    [_h] spawn {
        params ["_u"];
        while { alive _u && (_u getVariable ["LL_Task02c_Status", "WAIT"]) == "WAIT" } do {
            private _nearest = objNull;
            private _minDist = 99999;
            {
                if (alive _x) then {
                    private _d = _u distance2D _x;
                    if (_d < _minDist) then { _minDist = _d; _nearest = _x; };
                };
            } forEach allPlayers;
            if (!isNull _nearest) then {
                private _dir = _u getDir _nearest;
                _u setDir _dir;
                _u setFormDir _dir; // CORRECTIF #9 : empêche l'IA de re-pivoter
            };
            sleep 2;
        };
    };

    // ══════════════════════════════════════════════════════════════════════
    // MARQUEUR ET CRÉATION DE LA TÂCHE BIS (TASK_RULES §7)
    // ══════════════════════════════════════════════════════════════════════
    createMarker ["LL_mkr_t02c_inter", getPos _h];
    "LL_mkr_t02c_inter" setMarkerType "mil_objective";
    "LL_mkr_t02c_inter" setMarkerColor "ColorYellow";
    "LL_mkr_t02c_inter" setMarkerText localize "STR_LL_Task_02c_Marker";

    [
        independent,
        ["task_02c_intermediaire"],
        [
            localize "STR_LL_Task_02c_Desc",
            localize "STR_LL_Task_02c_Title",
            localize "STR_LL_Task_02c_Marker"
        ],
        getPos _h,
        "AUTOASSIGNED",
        5,
        true,
        "capture"
    ] call BIS_fnc_taskCreate;

    if (DEBUG_MODE) then {
        diag_log "[LL][task02c] Intermédiaire spawné — tâche BIS créée.";
    };

    // Déployer l'addAction "Maîtriser l'intermédiaire" sur tous les clients
    ["capture", _h] remoteExec ["LL_fnc_task02c_addAction", 0];

    // ══════════════════════════════════════════════════════════════════════
    // SURVEILLANCE : mort de l'intermédiaire avant capture → FAILED
    // ══════════════════════════════════════════════════════════════════════
    [_h] spawn {
        params ["_unit"];
        waitUntil { sleep 1; !alive _unit };
        if (!(missionNamespace getVariable ["LL_Task02c_Captured", false])) then {
            ["task_02c_intermediaire", "FAILED", true] call BIS_fnc_taskSetState;
            ["STR_LL_Speaker_Narrator", "STR_LL_Task_02c_Narrative_Failed"] remoteExec ["LL_fnc_showSubtitle", 0];
            deleteMarker "LL_mkr_t02c_inter";
            if (DEBUG_MODE) then {
                diag_log "[LL][task02c] Intermédiaire tué — tâche FAILED.";
            };
        };
    };

    // ══════════════════════════════════════════════════════════════════════
    // ATTENTE DE LA CAPTURE
    // ══════════════════════════════════════════════════════════════════════
    waitUntil {
        sleep 1;
        missionNamespace getVariable ["LL_Task02c_Captured", false]
    };

    if (!alive _h) exitWith {};

    // ══════════════════════════════════════════════════════════════════════
    // POST-CAPTURE : SUCCÈS
    // ══════════════════════════════════════════════════════════════════════
    deleteMarker "LL_mkr_t02c_inter";
    ["task_02c_intermediaire", "SUCCEEDED", true] call BIS_fnc_taskSetState;

    // --- VOIX NATIVE IMMERSIVE (le financier parle en perse — pas d'animation de dialogue) ---
    // Création du soldat fantôme pour forcer la voix native du financier
    private _dummy = _civGrp createUnit ["I_G_Soldier_F", getPos _h, [], 0, "NONE"];
    _dummy hideObjectGlobal true;
    _dummy allowDamage false;
    _dummy disableAI "ALL";
    _civGrp selectLeader _h;

    // Le financier "donne un ordre" au fantôme → voix native !
    _dummy commandMove (getPos _h getPos [500, random 360]);

    ["STR_LL_Speaker_Intermediaire", "STR_LL_Task_02c_Intermediaire_Captured"] remoteExec ["LL_fnc_showSubtitle", 0];
    sleep 5;

    // Deuxième phrase vocale native
    _dummy commandMove (getPos _h getPos [800, random 360]);

    ["STR_LL_Speaker_Intermediaire", "Ne me tuez pas ! L'héliport caché du cartel est juste à côté, prenez cette info mais laissez-moi la vie sauve !"] remoteExec ["LL_fnc_showSubtitle", 0];
    sleep 5;

    deleteVehicle _dummy; // Nettoyage du fantôme

    ["STR_LL_Speaker_Narrator", "STR_LL_Task_02c_Narrative_Success"] remoteExec ["LL_fnc_showSubtitle", 0];
    sleep 5;

    // ── L'intermédiaire reste sur place en état d'arrestation ────────────
    // L'animation Acts_ExecutionVictim_Loop est déjà active et loopée
    // via le AnimDone EH posé par le mode capture_anim
    _h setCaptive true;   // Neutre — ne se fait pas cibler
    _h allowFleeing 0;
    _h disableAI "MOVE"; // Immobile sur place

    // Nettoyage du groupe civil vide
    if (!isNull _civGrp && { count units _civGrp == 0 }) then {
        deleteGroup _civGrp;
    };

    // ── Information joueurs : équipe de récupération dépêchée ─────────────
    sleep 3;
    ["STR_LL_Speaker_Narrator", "STR_LL_Task_02c_Narrative_Extraction_Team"] remoteExec ["LL_fnc_showSubtitle", 0];
    sleep 6;

    // ══════════════════════════════════════════════════════════════════════
    // DISPARITION DE L'INTERMÉDIAIRE
    // Dès que TOUS les joueurs vivants sont à plus de 500m — «récupéré»
    // ══════════════════════════════════════════════════════════════════════
    [_h] spawn {
        params ["_unit"];
        waitUntil {
            sleep 5;
            !alive _unit
            || {
                private _alivePlayers = allPlayers select { alive _x };
                (count _alivePlayers > 0)
                && { ({ _x distance2D _unit <= 500 } count _alivePlayers) == 0 }
            }
        };
        if (alive _unit) then {
            if (DEBUG_MODE) then {
                diag_log "[LL][task02c] Tous joueurs à > 500m — intermédiaire récupéré par l'équipe d'extraction.";
            };
            private _grpPrisoner = group _unit;
            deleteVehicle _unit;
            if (!isNull _grpPrisoner && { count units _grpPrisoner == 0 }) then {
                deleteGroup _grpPrisoner;
            };
        };
    };

    // ══════════════════════════════════════════════════════════════════════
    // LE CHEF DE MILICE QUITTE LE GROUPE (s'il est encore vivant)
    // Il part rejoindre l'équipe d'extraction hélicoptère (dissolution §14)
    // ══════════════════════════════════════════════════════════════════════
    if (alive _chief) then {
        sleep 3;

        ["STR_LL_Speaker_Chief", "STR_LL_Task_02c_Chief_Leaves"] remoteExec ["LL_fnc_showSubtitle", 0];
        sleep 5;

        // CORRECTIF : Libérer de toute animation résiduelle avant sa fuite
        [_chief, ""] remoteExec ["switchMove", 0];
        _chief enableAI "MOVE";
        _chief enableAI "ANIM";
        _chief setBehaviour "SAFE";
        _chief setSpeedMode "FULL";
        _chief setVariable ["LL_Task02c_ChiefLeaving", true, true];

        // Dissolution hors champ (TASK_RULES §14)
        private _chiefGrp = createGroup [independent, true];
        [_chief] joinSilent _chiefGrp;

        [[_chief], _chiefGrp] spawn {
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

    // ══════════════════════════════════════════════════════════════════════
    // DISSOLUTION DES HOMMES DE MAIN SURVIVANTS (TASK_RULES §14)
    // ══════════════════════════════════════════════════════════════════════
    private _aliveGuards = _allGuards select { alive _x };

    if (count _aliveGuards > 0) then {

        {
            _x enableAI "MOVE";
            _x setBehaviour "SAFE";
            _x setSpeedMode "FULL";
            _x allowFleeing 1;
            _x setVariable ["LL_Task02c_Dissolving", true, true];
        } forEach _aliveGuards;

        [_aliveGuards, _grp] spawn {
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
};
