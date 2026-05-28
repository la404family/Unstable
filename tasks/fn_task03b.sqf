#include "..\macros.hpp"

/*
    LL_fnc_task03b

    Description:
      Tâche 03b — "Opération Bouclier — Désamorcer les bombes du MJ"

      Après la libération de l'informateur (task02b), les renseignements révèlent
      que le Mouvement pour la Justice a planté 2 bombes artisanales dans Porto pour
      déclencher un attentat de masse. Des cellules MJ de 8 à 12 gardes protègent
      chaque site. Des civils apparemment innocents sont en réalité des sympathisants
      armés qui se révèlent quand les joueurs s'approchent à moins de 15 mètres.

      Victoire : désamorcer les 2 bombes avant l'expiration du compte à rebours (25 à 45 min, aléatoire).
      Échec    : les bombes explosent. Les survivants MJ attaquent. Tenir jusqu'à
                 l'extraction (fin de mission initiée par le joueur — TASK_RULES §7).

    Locality:
      Serveur uniquement (isServer)
*/

if (!isServer) exitWith {};

[] spawn {

    waitUntil {
        sleep 2;
        (count (allPlayers select { side _x == independent && alive _x })) > 0
    };

    if (DEBUG_MODE) then {
        diag_log "[LL][task03b] Démarrage de la tâche 03b — Opération Bouclier.";
    };

    // ══════════════════════════════════════════════════════════════════════
    // A. SÉLECTION DES POSITIONS — M_Dans_Bat_XXX (priorité absolue)
    //    Fallback héliports si < 2 positions disponibles dans les bâtiments
    //    Filtre : >150m des joueurs, >200m entre sites, >150m de LL_g_usedTaskPos
    // ══════════════════════════════════════════════════════════════════════
    private _playerPositions = (allPlayers select { alive _x }) apply { getPos _x };
    private _usedTaskPos     = if (!isNil "LL_g_usedTaskPos") then { LL_g_usedTaskPos } else { [] };

    // Collecter tous les M_Dans_Bat_XXX
    private _rawLogics = [];
    {
        if (_x select [0, 11] == "M_Dans_Bat_") then {
            private _obj = missionNamespace getVariable [_x, objNull];
            if (!isNull _obj) then { _rawLogics pushBack _obj; };
        };
    } forEach (allVariables missionNamespace);
    _rawLogics = _rawLogics call BIS_fnc_arrayShuffle;

    private _selectedPositions = [];
    private _usedLogics = [];

    // Passe 1 : >150m joueurs, >200m entre sites, >150m des positions déjà utilisées
    {
        private _obj       = _x;
        private _candidate = getPos _obj;
        if (count _selectedPositions < 2 && { !(_obj in _usedLogics) }) then {
            private _valid = true;
            { if (_x distance2D _candidate < 150) exitWith { _valid = false; }; } forEach _playerPositions;
            if (_valid) then {
                { if (_x distance2D _candidate < 200) exitWith { _valid = false; }; } forEach _selectedPositions;
            };
            if (_valid) then {
                { if (_x distance2D _candidate < 150) exitWith { _valid = false; }; } forEach _usedTaskPos;
            };
            if (_valid) then {
                _selectedPositions pushBack _candidate;
                _usedLogics pushBack _obj;
            };
        };
    } forEach _rawLogics;

    // Passe 2 : contraintes assouplies (>100m joueurs, >100m entre sites)
    if (count _selectedPositions < 2) then {
        {
            private _obj       = _x;
            private _candidate = getPos _obj;
            if (count _selectedPositions < 2 && { !(_obj in _usedLogics) }) then {
                private _valid = true;
                { if (_x distance2D _candidate < 100) exitWith { _valid = false; }; } forEach _playerPositions;
                if (_valid) then {
                    { if (_x distance2D _candidate < 100) exitWith { _valid = false; }; } forEach _selectedPositions;
                };
                if (_valid) then {
                    _selectedPositions pushBack _candidate;
                    _usedLogics pushBack _obj;
                };
            };
        } forEach _rawLogics;
    };

    // Fallback héliports si toujours insuffisant
    if (count _selectedPositions < 2) then {
        private _allHeliports = [];
        {
            if (_x select [0, 9] == "Heliport_") then {
                private _hp = missionNamespace getVariable [_x, objNull];
                if (!isNull _hp) then { _allHeliports pushBack _hp; };
            };
        } forEach (allVariables missionNamespace);
        _allHeliports = _allHeliports call BIS_fnc_arrayShuffle;
        {
            if (count _selectedPositions < 2) then {
                _selectedPositions pushBack (getPos _x);
            };
        } forEach _allHeliports;
    };

    // Sécurité absolue : fallback de dernier recours
    while { count _selectedPositions < 2 } do {
        private _refPlayer = (allPlayers select { alive _x }) select 0;
        _selectedPositions pushBack (getPos _refPlayer getPos [300 + random 200, random 360]);
    };

    if (DEBUG_MODE) then {
        diag_log format ["[LL][task03b] %1 position(s) retenue(s) : %2", count _selectedPositions, _selectedPositions];
    };

    // ══════════════════════════════════════════════════════════════════════
    // B. INITIALISATION DES VARIABLES GLOBALES
    // ══════════════════════════════════════════════════════════════════════
    missionNamespace setVariable ["LL_Task03b_DefusedCount",  0,          true];
    missionNamespace setVariable ["LL_Task03b_Bomb0_Defused", false,      true];
    missionNamespace setVariable ["LL_Task03b_Bomb1_Defused", false,      true];
    missionNamespace setVariable ["LL_Task03b_Running",       true,       true];
    private _timerDuration = 1500 + floor (random 1201); // 25 à 45 minutes (aléatoire)
    missionNamespace setVariable ["LL_Task03b_TimerEnd",      time + _timerDuration, true];
    missionNamespace setVariable ["LL_Task03b_BombCrates",    [],         true]; // rempli ci-dessous

    // ══════════════════════════════════════════════════════════════════════
    // C. CRÉATION DE LA TÂCHE BIS (TASK_RULES §7)
    // ══════════════════════════════════════════════════════════════════════
    [
        independent,
        ["task_03b_bombes"],
        [
            localize "STR_LL_Task_03b_Desc",
            localize "STR_LL_Task_03b_Title",
            localize "STR_LL_Task_03b_Marker"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "bomb"
    ] call BIS_fnc_taskCreate;

    // ══════════════════════════════════════════════════════════════════════
    // D. SPAWN DES SITES DE BOMBES (TASK_RULES §3 : secondaires avant principal)
    // ══════════════════════════════════════════════════════════════════════
    private _bombCrates     = [];  // références des caisses pour le désamorçage
    private _bombCharges    = [];  // charges rattachées aux caisses
    private _markersList    = [];  // marqueurs de carte par site
    private _allGuardGroups = [];  // tous les groupes de gardes pour la dissolution
    private _allTraitors    = [];  // civils traîtres (non armés au départ)
    private _traitorGroup   = createGroup [east, true]; // groupe pour les traîtres activés

    {
        private _siteIndex = _forEachIndex;
        private _pos       = _x;

        // ── 1. Gardes MJ — 2 patrouilles (8 à 12 gardes par site) ─────────
        //    Spawner AVANT la bombe (TASK_RULES §3 : secondaires en premier)
        private _numGuards  = 8 + floor (random 5);  // 8, 9, 10, 11 ou 12
        private _half       = floor (_numGuards / 2);
        private _guardsGrp1 = createGroup [east, true];
        private _guardsGrp2 = createGroup [east, true];
        _allGuardGroups pushBack _guardsGrp1;
        _allGuardGroups pushBack _guardsGrp2;

        for "_i" from 1 to _half do {
            sleep 0.7;
            private _gPos = _pos getPos [5 + random 20, random 360];
            private _g    = _guardsGrp1 createUnit ["O_G_Soldier_F", _gPos, [], 0, "NONE"];
            _g setPos [_gPos select 0, _gPos select 1, getTerrainHeightASL _gPos];
            _g allowDamage false;
            [_g] spawn { sleep 3; (_this select 0) allowDamage true; };
            _g setVariable ["LL_forceTemplate", true, true];
            if (!isNil "LL_fnc_applyCivilianTemplate") then { [_g] call LL_fnc_applyCivilianTemplate; };
            _g setBehaviour "AWARE";
            _g setCombatMode "RED";
        };

        for "_i" from 1 to (_numGuards - _half) do {
            sleep 0.7;
            private _gPos = _pos getPos [5 + random 20, random 360];
            private _g    = _guardsGrp2 createUnit ["O_G_Soldier_F", _gPos, [], 0, "NONE"];
            _g setPos [_gPos select 0, _gPos select 1, getTerrainHeightASL _gPos];
            _g allowDamage false;
            [_g] spawn { sleep 3; (_this select 0) allowDamage true; };
            _g setVariable ["LL_forceTemplate", true, true];
            if (!isNil "LL_fnc_applyCivilianTemplate") then { [_g] call LL_fnc_applyCivilianTemplate; };
            _g setBehaviour "AWARE";
            _g setCombatMode "RED";
        };

        // Patrouilles autour du site (TASK_RULES §11)
        [_guardsGrp1, _pos] spawn {
            params ["_grp", "_center"];
            while { ({ alive _x } count units _grp) > 0 } do {
                if (behaviour (leader _grp) != "COMBAT") then {
                    private _pPos = _center getPos [4 + random 21, random 360];
                    _grp move _pPos;
                };
                sleep (18 + random 12);
            };
        };
        [_guardsGrp2, _pos] spawn {
            params ["_grp", "_center"];
            while { ({ alive _x } count units _grp) > 0 } do {
                if (behaviour (leader _grp) != "COMBAT") then {
                    private _pPos = _center getPos [4 + random 21, random 360];
                    _grp move _pPos;
                };
                sleep (18 + random 12);
            };
        };

        // ── 2. Civils traîtres (2 à 4 par site) — armés au contact des joueurs ──
        // Groupe civilian temporaire — deleteWhenEmpty:true, auto-supprimé quand les
        // traîtres rejoignent _traitorGroup via joinSilent
        private _traitorCivGrp = createGroup [civilian, true];
        private _numTraitors = 2 + floor (random 3); // 2, 3 ou 4
        for "_t" from 1 to _numTraitors do {
            sleep 0.5;
            private _tPos   = _pos getPos [15 + random 35, random 360];
            private _traitor = _traitorCivGrp createUnit ["C_Man_1", _tPos, [], 0, "NONE"];
            _traitor setPos [_tPos select 0, _tPos select 1, getTerrainHeightASL _tPos];
            _traitor allowDamage false;
            [_traitor] spawn { sleep 3; (_this select 0) allowDamage true; };
            _traitor setVariable ["LL_forceTemplate",  true,  true];
            _traitor setVariable ["isTraitor",         true,  true];
            _traitor setVariable ["traitorArmed",      false, true];
            if (!isNil "LL_fnc_applyCivilianTemplate") then { [_traitor] call LL_fnc_applyCivilianTemplate; };
            // Ennemi caché — immobile, debout, pas d'animation forcée (les gardes ne discutent pas)
            _traitor disableAI "MOVE";
            _traitor setUnitPos "UP";
            _allTraitors pushBack _traitor;
        };

        // ── 3. Bombe — valise piégée + charge + lumières rouges (PRINCIPAL en dernier) ──
        // Land_Suitcase_F : objet statique non-container → aucun inventaire accessible
        private _crate  = createVehicle ["Land_Suitcase_F", _pos, [], 0, "CAN_COLLIDE"];
        _crate setDir (random 360);
        private _charge = createVehicle ["DemoCharge_F", _pos vectorAdd [0, 0, 0.3], [], 0, "CAN_COLLIDE"];
        _charge attachTo [_crate, [0, 0, 0.15]];
        _charge setVectorUp [0, 0, 1];

        // Lumières rouges visibles jour et nuit
        {
            private _redLight = "#lightpoint" createVehicle _pos;
            _redLight setLightBrightness 0.8;
            _redLight setLightColor      [1, 0, 0];
            _redLight setLightAmbient    [1, 0, 0];
            _redLight setLightDayLight   true;
            _redLight lightAttachObject  [_crate, [_x select 0, _x select 1, 0.5]];
        } forEach [[1.2, 1.2], [-1.2, -1.2]];

        _bombCrates  pushBack _crate;
        _bombCharges pushBack _charge;

        // ── 4. Marqueur de carte ────────────────────────────────────────────
        private _mkrName = format ["LL_mkr_t03b_bomb_%1", _siteIndex];
        createMarker [_mkrName, _pos];
        _mkrName setMarkerType  "mil_warning";
        _mkrName setMarkerColor "ColorRed";
        _mkrName setMarkerText  (localize "STR_LL_Task_03b_Marker");
        _markersList pushBack _mkrName;

        // ── 5. Son de bip — bombe active ────────────────────────────────────
        [_crate, format ["LL_Task03b_Bomb%1_Defused", _siteIndex]] spawn {
            params ["_obj", "_defuseVar"];
            while { alive _obj && { !(missionNamespace getVariable [_defuseVar, false]) } } do {
                if (alive _obj) then {
                    playSound3D ["A3\Sounds_F\sfx\Beep_Target.wss", _obj, false, getPosASL _obj, 2.0, 1.0, 80];
                };
                sleep 2;
            };
        };

    } forEach _selectedPositions;

    // Publier les références des bombes pour l'addAction client
    missionNamespace setVariable ["LL_Task03b_BombCrates", _bombCrates, true];

    // ── Déclencher l'interface client (addAction + chrono HUD) ─────────────
    [] remoteExec ["LL_fnc_task03b_addAction", 0];

    // ── Narration de début ──────────────────────────────────────────────────
    sleep 2;
    ["STR_LL_Speaker_Narrator", "STR_LL_Task_03b_Narrative_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

    if (DEBUG_MODE) then {
        diag_log format ["[LL][task03b] 2 sites armés. %1 gardes + traîtres déployés. Chrono 15 min.", count _allTraitors + (count _allGuardGroups * 5)];
    };

    // ══════════════════════════════════════════════════════════════════════
    // E. BOUCLE PRINCIPALE DE SURVEILLANCE (tick 3 secondes)
    // ══════════════════════════════════════════════════════════════════════
    private _taskSuccess          = false;
    private _taskFailed           = false;
    private _bomb0Notified        = false;
    private _bomb1Notified        = false;

    waitUntil {
        sleep 3;

        // ── Traîtres : s'armer si joueur < 15 mètres ──────────────────────
        private _livePlayers = allPlayers select { alive _x };
        {
            private _civ = _x;
            if (alive _civ
                && { _civ getVariable ["isTraitor",    false] }
                && { !(_civ getVariable ["traitorArmed", false]) }
            ) then {
                private _nearDist   = 999999;
                private _nearPlayer = objNull;
                {
                    if (alive _x) then {
                        private _d = _civ distance _x;
                        if (_d < _nearDist) then { _nearDist = _d; _nearPlayer = _x; };
                    };
                } forEach _livePlayers;

                if (_nearDist < 15 && { !isNull _nearPlayer }) then {
                    _civ setVariable ["traitorArmed", true, true];
                    _civ enableAI "MOVE";
                    _civ enableAI "ANIM";
                    [_civ] joinSilent _traitorGroup;
                    _civ enableAI "TARGET";
                    _civ enableAI "AUTOTARGET";
                    _civ enableAI "WEAPONAIM";
                    _civ enableAI "SUPPRESSION";
                    _civ setBehaviour  "COMBAT";
                    _civ setCombatMode "RED";
                    _civ addMagazine "16Rnd_9x21_Mag";
                    _civ addMagazine "16Rnd_9x21_Mag";
                    _civ addWeapon   "hgun_P07_F";
                    _civ selectWeapon "hgun_P07_F";
                    _civ setSkill 0.5;
                    _civ doTarget _nearPlayer;
                    _civ doFire   _nearPlayer;
                    _civ doMove   (getPos _nearPlayer);
                    (localize "STR_LL_Task_03b_Traitor_Warning") remoteExec ["systemChat", 0];
                    if (DEBUG_MODE) then { diag_log "[LL][task03b] Traître armé — attaque en cours."; };
                };
            };
        } forEach _allTraitors;

        // ── Suivi désamorçage bombe 0 ──────────────────────────────────────
        if (missionNamespace getVariable ["LL_Task03b_Bomb0_Defused", false] && { !_bomb0Notified }) then {
            _bomb0Notified = true;
            // Effet fumée ninja : fumée → 1.5s → lumières éteintes + valise supprimée
            [(_bombCrates select 0), (_bombCharges select 0)] spawn {
                params ["_crate", "_charge"];
                if (!isNull _crate) then {
                    "SmokeShellWhite" createVehicle (getPos _crate);
                };
                sleep 1.5;
                if (!isNull _charge) then { deleteVehicle _charge; };
                if (!isNull _crate)  then { deleteVehicle _crate; };
            };
            if (count _markersList > 0 && { _markersList select 0 != "" }) then {
                deleteMarker (_markersList select 0);
                _markersList set [0, ""];
            };
            (localize "STR_LL_Task_03b_Bomb_Defused_1") remoteExec ["systemChat", 0];
            if (DEBUG_MODE) then { diag_log "[LL][task03b] Bombe 0 désamorcée."; };
        };

        // ── Suivi désamorçage bombe 1 ──────────────────────────────────────
        if (missionNamespace getVariable ["LL_Task03b_Bomb1_Defused", false] && { !_bomb1Notified }) then {
            _bomb1Notified = true;
            // Effet fumée ninja : fumée → 1.5s → lumières éteintes + valise supprimée
            [(_bombCrates select 1), (_bombCharges select 1)] spawn {
                params ["_crate", "_charge"];
                if (!isNull _crate) then {
                    "SmokeShellWhite" createVehicle (getPos _crate);
                };
                sleep 1.5;
                if (!isNull _charge) then { deleteVehicle _charge; };
                if (!isNull _crate)  then { deleteVehicle _crate; };
            };
            if (count _markersList > 1 && { _markersList select 1 != "" }) then {
                deleteMarker (_markersList select 1);
                _markersList set [1, ""];
            };
            (localize "STR_LL_Task_03b_Bomb_Defused_2") remoteExec ["systemChat", 0];
            if (DEBUG_MODE) then { diag_log "[LL][task03b] Bombe 1 désamorcée."; };
        };

        // ── Condition de victoire ──────────────────────────────────────────
        if (missionNamespace getVariable ["LL_Task03b_Bomb0_Defused", false]
            && { missionNamespace getVariable ["LL_Task03b_Bomb1_Defused", false] }
        ) then {
            _taskSuccess = true;
        };

        // ── Condition d'échec : compte à rebours expiré ────────────────────
        if (((missionNamespace getVariable ["LL_Task03b_TimerEnd", time + 1]) - time) <= 0
            && { !_taskSuccess }
        ) then {
            _taskFailed = true;
        };

        _taskSuccess || _taskFailed
    };

    // ══════════════════════════════════════════════════════════════════════
    // F. ARRÊTER LE CHRONO HUD (signal aux clients via variable globale)
    // ══════════════════════════════════════════════════════════════════════
    missionNamespace setVariable ["LL_Task03b_Running", false, true];
    sleep 2;

    // ══════════════════════════════════════════════════════════════════════
    // G. SUCCÈS — 2 bombes désamorcées
    // ══════════════════════════════════════════════════════════════════════
    if (_taskSuccess) then {
        { if (!isNull _x && { alive _x }) then { deleteVehicle _x; }; } forEach _bombCrates;
        { if (!isNull _x && { alive _x }) then { deleteVehicle _x; }; } forEach _bombCharges;
        { if (_x != "") then { deleteMarker _x; }; } forEach _markersList;

        ["task_03b_bombes", "SUCCEEDED", true] call BIS_fnc_taskSetState;
        sleep 2;
        ["STR_LL_Speaker_Narrator", "STR_LL_Task_03b_Narrative_All_Defused"] remoteExec ["LL_fnc_showSubtitle", 0];

        // Dissolution propre des gardes survivants (TASK_RULES §14)
        private _dissolveTargets = _allGuardGroups + [_traitorGroup];
        {
            private _grp   = _x;
            private _alive = (units _grp) select { alive _x };
            if (count _alive == 0) then { continue; };

            { _x enableAI "MOVE"; _x setBehaviour "SAFE"; _x setSpeedMode "FULL"; } forEach _alive;
            { _x setVariable ["LL_Task03b_Escaping", true, true]; } forEach _alive;

            private _dissolveGrp = createGroup [east, true];
            _alive joinSilent _dissolveGrp;

            [_alive, _dissolveGrp] spawn {
                params ["_units", "_grp"];
                private _alive = _units select { alive _x };
                if (count _alive == 0) exitWith {};
                private _running = true;
                while { _running && { ({ alive _x } count _alive) > 0 } } do {
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
                    _wp setWaypointType "MOVE"; _wp setWaypointSpeed "FULL"; _wp setWaypointBehaviour "SAFE";
                    waitUntil {
                        sleep 1;
                        ({ alive _x } count _alive) == 0 || (leader _grp distance2D _dissolvePos <= 5)
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
        } forEach _dissolveTargets;

        if (DEBUG_MODE) then { diag_log "[LL][task03b] SUCCÈS — dissolution des unités ennemies."; };
    };

    // ══════════════════════════════════════════════════════════════════════
    // H. ÉCHEC — timer expiré, bombes explosent
    // ══════════════════════════════════════════════════════════════════════
    if (_taskFailed) then {

        // Faire exploser les bombes non encore désamorcées
        {
            private _idx       = _forEachIndex;
            private _defuseVar = format ["LL_Task03b_Bomb%1_Defused", _idx];
            private _crate     = _x;
            if (!isNull _crate && { alive _crate } && { !(missionNamespace getVariable [_defuseVar, false]) }) then {
                "Bo_GBU12_LGB" createVehicle (getPos _crate);
                deleteVehicle _crate;
            };
        } forEach _bombCrates;
        { if (!isNull _x && { alive _x }) then { deleteVehicle _x; }; } forEach _bombCharges;
        { if (_x != "") then { deleteMarker _x; }; } forEach _markersList;

        ["task_03b_bombes", "FAILED", true] call BIS_fnc_taskSetState;
        sleep 2;
        ["STR_LL_Speaker_Narrator", "STR_LL_Task_03b_Narrative_Explosion"] remoteExec ["LL_fnc_showSubtitle", 0];
        sleep 5;

        // Sous-tâche : tenir la position jusqu'à l'extraction (TASK_RULES §7)
        [
            independent,
            ["task_03b_surv"],
            [
                localize "STR_LL_Task_03b_Surv_Desc",
                localize "STR_LL_Task_03b_Surv_Title",
                localize "STR_LL_Task_03b_Surv_Marker"
            ],
            objNull,
            "AUTOASSIGNED",
            5,
            true,
            "survive"
        ] call BIS_fnc_taskCreate;

        // Activer tous les survivants MJ en mode assaut direct sur les joueurs
        private _allEnemy = _allGuardGroups + [_traitorGroup];
        {
            private _grp  = _x;
            private _alive = (units _grp) select { alive _x };
            if (count _alive > 0) then {
                // Trouver le joueur le plus proche du chef de groupe
                private _nearestPlayer = objNull;
                private _minDist       = 99999;
                {
                    if (alive _x) then {
                        private _d = (leader _grp) distance _x;
                        if (_d < _minDist) then { _minDist = _d; _nearestPlayer = _x; };
                    };
                } forEach allPlayers;

                {
                    _x enableAI "MOVE";
                    _x enableAI "TARGET";
                    _x enableAI "AUTOTARGET";
                    _x setBehaviour  "COMBAT";
                    _x setCombatMode "RED";
                    _x setSpeedMode  "FULL";
                } forEach _alive;

                if (!isNull _nearestPlayer) then { _grp move (getPos _nearestPlayer); };
            };
        } forEach _allEnemy;

        if (DEBUG_MODE) then { diag_log "[LL][task03b] ÉCHEC — bombes explosées, assaut MJ en cours."; };
    };

};
