#include "..\macros.hpp"

/*
    LL_fnc_task03a

    Description:
      Tâche 03a — "Neutraliser les véhicules armés"
      Crée 3 véhicules armés de type "CUP_O_UAZ_AGS30_CHDKZ" sur des héliports invisibles (Heliport_XXX)
      situés à au moins 500m des joueurs.
      Le groupe équipage (conducteur + tireur) fait avancer le véhicule de 50m vers le joueur le plus proche,
      puis le carburant est retiré pour l'arrêter. Le pilote débarque pour monter la garde tandis que le tireur
      reste à l'arme (AGS-30).
      Deux patrouilles de deux gardes (O_G_Soldier_F formatés FL/Cartel) sécurisent et patrouillent autour de chaque véhicule.
      
      Victoire: Les 3 véhicules armés sont détruits ou vidés de leurs menaces.

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

    if (DEBUG_MODE) then {
        diag_log "[LL][task03a] Démarrage de la tâche 03a...";
    };

    // ══════════════════════════════════════════════════════════════════════
    // RECHERCHE DES POSITIONS DE SPAWN — HÉLIPORTS INVISIBLES (priorité absolue)
    // Les Heliport_XXX sont pré-placés dans des zones accessibles en véhicule.
    // Passe 1 : >500m joueurs, >300m entre spawns  (espacement maximal)
    // Passe 2 : >300m joueurs, >150m entre spawns  (contraintes assouplies)
    // Passe 3 : dernier recours — tout héliport non encore utilisé
    // ══════════════════════════════════════════════════════════════════════
    private _playerPositions   = (allPlayers select { alive _x }) apply { getPos _x };
    private _selectedPositions = [];
    private _usedHeliports     = [];

    // Collecter tous les Heliport_XXX définis dans l'éditeur Eden
    private _allHeliports = [];
    {
        if (_x select [0, 9] == "Heliport_") then {
            private _hp = missionNamespace getVariable [_x, objNull];
            if (!isNull _hp) then { _allHeliports pushBack _hp; };
        };
    } forEach (allVariables missionNamespace);
    _allHeliports = _allHeliports call BIS_fnc_arrayShuffle;

    if (DEBUG_MODE) then {
        diag_log format ["[LL][task03a] %1 héliport(s) disponible(s) pour le spawn des véhicules.", count _allHeliports];
    };

    // ── Passe 1 : >500m joueurs, >300m entre spawns ──────────────────────
    {
        private _hp        = _x;
        private _candidate = getPos _hp;
        if (count _selectedPositions < 3 && { !(_hp in _usedHeliports) }) then {
            private _valid = true;
            { if (_x distance2D _candidate < 500) exitWith { _valid = false; }; } forEach _playerPositions;
            if (_valid) then {
                { if (_x distance2D _candidate < 300) exitWith { _valid = false; }; } forEach _selectedPositions;
            };
            if (_valid) then {
                _selectedPositions pushBack _candidate;
                _usedHeliports     pushBack _hp;
            };
        };
    } forEach _allHeliports;

    // ── Passe 2 : >300m joueurs, >150m entre spawns (contraintes assouplies) ──
    if (count _selectedPositions < 3) then {
        if (DEBUG_MODE) then {
            diag_log format ["[LL][task03a] Passe 2 : %1 position(s) après passe 1.", count _selectedPositions];
        };
        {
            private _hp        = _x;
            private _candidate = getPos _hp;
            if (count _selectedPositions < 3 && { !(_hp in _usedHeliports) }) then {
                private _valid = true;
                { if (_x distance2D _candidate < 300) exitWith { _valid = false; }; } forEach _playerPositions;
                if (_valid) then {
                    { if (_x distance2D _candidate < 150) exitWith { _valid = false; }; } forEach _selectedPositions;
                };
                if (_valid) then {
                    _selectedPositions pushBack _candidate;
                    _usedHeliports     pushBack _hp;
                };
            };
        } forEach _allHeliports;
    };

    // ── Passe 3 : dernier recours — tout héliport non encore utilisé ─────
    if (count _selectedPositions < 3) then {
        if (DEBUG_MODE) then {
            diag_log format ["[LL][task03a] Passe 3 (dernier recours) : %1 position(s) après passe 2.", count _selectedPositions];
        };
        {
            private _hp = _x;
            if (count _selectedPositions < 3 && { !(_hp in _usedHeliports) }) then {
                _selectedPositions pushBack (getPos _hp);
                _usedHeliports     pushBack _hp;
            };
        } forEach _allHeliports;
    };

    if (DEBUG_MODE) then {
        diag_log format ["[LL][task03a] %1 position(s) retenue(s) sur héliports : %2", count _usedHeliports, _selectedPositions];
    };

    // ══════════════════════════════════════════════════════════════════════
    // CRÉATION DE LA TÂCHE BIS (TASK_RULES §7)
    // ══════════════════════════════════════════════════════════════════════
    [
        independent,
        ["task_03a_assaut"],
        [
            localize "STR_LL_Task_03a_Desc",
            localize "STR_LL_Task_03a_Title",
            localize "STR_LL_Task_03a_Marker"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "destroy"
    ] call BIS_fnc_taskCreate;

    ["STR_LL_Speaker_Narrator", "STR_LL_Task_03a_Narrative_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

    // Tableaux de suivi pour la destruction/clean final
    private _vehiclesList = [];
    private _allGroups = [];
    private _markersList = [];

    // Spawner les 3 groupes et véhicules (TASK_RULES §3 : secondaires avant principal)
    {
        private _spawnIndex = _forEachIndex;
        private _pos = _x;

        // 1. Spawner le véhicule armé
        private _veh = createVehicle ["CUP_O_UAZ_AGS30_CHDKZ", _pos, [], 0, "NONE"];
        _veh setDir (random 360);
        _veh allowDamage false;
        
        // Anti-collision initiale pour le véhicule
        [_veh] spawn { sleep 3; (_this select 0) allowDamage true; };
        _vehiclesList pushBack _veh;

        // 2. Créer l'équipage du véhicule (Conducteur + Tireur)
        private _crewGrp = createGroup [east, true];
        _allGroups pushBack _crewGrp;

        private _driver = _crewGrp createUnit ["O_G_Soldier_F", _pos, [], 0, "NONE"];
        _driver allowDamage false;
        [_driver] spawn { sleep 3; (_this select 0) allowDamage true; };
        _driver moveInDriver _veh;

        private _gunner = _crewGrp createUnit ["O_G_Soldier_F", _pos, [], 0, "NONE"];
        _gunner allowDamage false;
        [_gunner] spawn { sleep 3; (_this select 0) allowDamage true; };
        _gunner moveInGunner _veh;

        // Application du modèle civil
        _driver setVariable ["LL_forceTemplate", true, true];
        _gunner setVariable ["LL_forceTemplate", true, true];
        if (!isNil "LL_fnc_applyCivilianTemplate") then {
            [_driver] call LL_fnc_applyCivilianTemplate;
            [_gunner] call LL_fnc_applyCivilianTemplate;
        };

        _driver setBehaviour "AWARE";
        _driver setCombatMode "RED";
        _gunner setBehaviour "AWARE";
        _gunner setCombatMode "RED";

        // 3. Spawner les gardes de protection (Deux équipes de deux)
        private _guardsGroup1 = createGroup [east, true];
        private _guardsGroup2 = createGroup [east, true];
        _allGroups pushBack _guardsGroup1;
        _allGroups pushBack _guardsGroup2;

        // Équipe 1
        for "_i" from 1 to 2 do {
            sleep 0.5;
            private _gPos = _pos getPos [6 + random 8, random 360];
            private _guard = _guardsGroup1 createUnit ["O_G_Soldier_F", _gPos, [], 0, "NONE"];
            _guard setPos [ _gPos select 0, _gPos select 1, (getTerrainHeightASL _gPos) ];
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };
            
            _guard setVariable ["LL_forceTemplate", true, true];
            if (!isNil "LL_fnc_applyCivilianTemplate") then { [_guard] call LL_fnc_applyCivilianTemplate; };
            _guard setBehaviour "AWARE";
            _guard setCombatMode "RED";
        };

        // Équipe 2
        for "_i" from 1 to 2 do {
            sleep 0.5;
            private _gPos = _pos getPos [6 + random 8, random 360];
            private _guard = _guardsGroup2 createUnit ["O_G_Soldier_F", _gPos, [], 0, "NONE"];
            _guard setPos [ _gPos select 0, _gPos select 1, (getTerrainHeightASL _gPos) ];
            _guard allowDamage false;
            [_guard] spawn { sleep 3; (_this select 0) allowDamage true; };

            _guard setVariable ["LL_forceTemplate", true, true];
            if (!isNil "LL_fnc_applyCivilianTemplate") then { [_guard] call LL_fnc_applyCivilianTemplate; };
            _guard setBehaviour "AWARE";
            _guard setCombatMode "RED";
        };

        // 4. Lancer le comportement de patrouille autour du véhicule
        [_guardsGroup1, _veh] spawn {
            params ["_grp", "_v"];
            while { alive _v && { ({ alive _x } count units _grp) > 0 } } do {
                if (behaviour (leader _grp) != "COMBAT") then {
                    private _pPos = (getPos _v) getPos [8 + random 15, random 360];
                    _grp move _pPos;
                };
                sleep (20 + random 15);
            };
        };

        [_guardsGroup2, _veh] spawn {
            params ["_grp", "_v"];
            while { alive _v && { ({ alive _x } count units _grp) > 0 } } do {
                if (behaviour (leader _grp) != "COMBAT") then {
                    private _pPos = (getPos _v) getPos [8 + random 15, random 360];
                    _grp move _pPos;
                };
                sleep (20 + random 15);
            };
        };

        // 5. Piloter 50m vers le joueur le plus proche puis désactiver le véhicule
        [_veh, _crewGrp, _driver, _gunner, _pos] spawn {
            params ["_veh", "_crewGrp", "_driver", "_gunner", "_spawnPos"];
            
            _veh setFuel 1;
            _veh engineOn true;

            private _nearestPlayer = objNull;
            private _players = allPlayers select { alive _x };
            if (count _players > 0) then {
                _nearestPlayer = [_players, _spawnPos] call BIS_fnc_nearestPosition;
            };

            if (!isNull _nearestPlayer) then {
                private _dirToPlayer = _spawnPos getDir _nearestPlayer;
                _veh setDir _dirToPlayer;
                
                private _targetPos = _spawnPos getPos [50, _dirToPlayer];
                _veh limitSpeed 15;
                _crewGrp move _targetPos;

                private _timeout = time + 35;
                waitUntil {
                    sleep 1;
                    !alive _veh
                    || !alive _driver
                    || (_veh distance2D _targetPos) < 8
                    || (_veh distance2D _spawnPos) >= 45
                    || time > _timeout
                };
            };

            // Stopper définitivement le véhicule (panne de carburant simulée)
            _veh setFuel 0;
            _veh setVelocity [0,0,0];
            doStop _veh;

            // Faire débarquer le pilote pour monter la garde
            if (alive _driver && { vehicle _driver == _veh }) then {
                unassignVehicle _driver;
                _driver action ["getOut", _veh];
                _driver setUnitPos "UP";
                _driver setBehaviour "COMBAT";
            };

            // Le tireur reste dans le véhicule et engage les menaces
            if (alive _gunner) then {
                _gunner setBehaviour "COMBAT";
                _gunner setCombatMode "RED";
            };
        };

        // 6. Créer le marqueur de carte
        private _markerName = format ["LL_mkr_t03a_veh_%1", _spawnIndex];
        createMarker [_markerName, _pos];
        _markerName setMarkerType "mil_warning";
        _markerName setMarkerColor "ColorRed";
        _markerName setMarkerText (localize "STR_LL_Task_03a_Marker");
        _markersList pushBack _markerName;

        // Gestionnaire de mise à jour/déplacement du marqueur basé sur la position finale du véhicule
        [_veh, _markerName] spawn {
            params ["_v", "_mkr"];
            // Attendre qu'il s'arrête de rouler pour actualiser précisément son icône
            sleep 40;
            if (alive _v) then {
                _mkr setMarkerPos (getPos _v);
            };
        };

    } forEach _selectedPositions;

    // ══════════════════════════════════════════════════════════════════════
    // SURVEILLANCE DE L'OBJECTIF — Attendre que les 3 véhicules soient gérés
    // ══════════════════════════════════════════════════════════════════════
    waitUntil {
        sleep 4;
        
        // Un véhicule est dit neutralisé s'il est détruit, OU s'il n'y a plus aucun combattant vivant à bord
        private _neutralizedCount = {
            private _veh = _x;
            !alive _veh || { { alive _x } count (crew _veh) == 0 }
        } count _vehiclesList;

        // Mettre à jour les marqueurs en direct (supprimer ceux des véhicules déjà détruits/vides)
        {
            private _veh = _vehiclesList select _forEachIndex;
            private _mkr = _x;
            if (_mkr != "" && { !alive _veh || { { alive _x } count (crew _veh) == 0 } }) then {
                deleteMarker _mkr;
                _markersList set [_forEachIndex, ""];
            };
        } forEach _markersList;

        _neutralizedCount == 3
    };

    // ══════════════════════════════════════════════════════════════════════
    // COMPLÉTION DE LA TÂCHE
    // ══════════════════════════════════════════════════════════════════════
    
    // Nettoyer tous les marqueurs restants au cas où
    { if (_x != "") then { deleteMarker _x; }; } forEach _markersList;

    ["task_03a_assaut", "SUCCEEDED", true] call BIS_fnc_taskSetState;
    ["STR_LL_Speaker_Narrator", "STR_LL_Task_03a_Narrative_Success"] remoteExec ["LL_fnc_showSubtitle", 0];

    if (DEBUG_MODE) then {
        diag_log "[LL][task03a] Tous les véhicules armés ennemis ont été neutralisés. Tâche accomplie !";
    };

    // ══════════════════════════════════════════════════════════════════════
    // SOUS-TÂCHE : RESTER EN VIE
    // Les survivants ennemis attaquent les joueurs.
    // Les joueurs déclenchent eux-mêmes la fin via l'action d'extraction.
    // ══════════════════════════════════════════════════════════════════════

    // Création de la sous-tâche
    [
        independent,
        ["task_03a_surv"],
        [
            localize "STR_LL_Task_03a_Surv_Desc",
            localize "STR_LL_Task_03a_Surv_Title",
            localize "STR_LL_Task_03a_Surv_Marker"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "survive"
    ] call BIS_fnc_taskCreate;

    // Activation des survivants ennemis en mode assaut (poursuite des joueurs)
    {
        private _grp  = _x;
        private _alive = (units _grp) select { alive _x };

        if (count _alive > 0) then {
            {
                _x enableAI "MOVE";
                _x enableAI "TARGET";
                _x enableAI "AUTOTARGET";
                _x setBehaviour "COMBAT";
                _x setCombatMode "RED";
                _x setSpeedMode "FULL";
                _x allowFleeing 0;
            } forEach _alive;

            // Boucle de poursuite : se dirige vers le joueur vivant le plus proche
            [_grp] spawn {
                params ["_grp"];
                while {
                    ({ alive _x } count (units _grp)) > 0
                    && !(missionNamespace getVariable ["LL_Task03a_ExtractionCalled", false])
                } do {
                    private _alivePlayers = allPlayers select { alive _x };
                    if (count _alivePlayers > 0) then {
                        private _leaderPos    = getPos (leader _grp);
                        private _nearestPlayer = _alivePlayers select 0;
                        private _nearestDist   = _leaderPos distance2D (_alivePlayers select 0);
                        {
                            private _d = _leaderPos distance2D _x;
                            if (_d < _nearestDist) then {
                                _nearestDist   = _d;
                                _nearestPlayer = _x;
                            };
                        } forEach _alivePlayers;
                        // Se déplacer vers le joueur s'il est hors de portée de combat directe
                        if (_nearestDist > 80) then {
                            _grp move getPos _nearestPlayer;
                        };
                    };
                    sleep 10;
                };
            };
        };

    } forEach _allGroups;

    // Ajouter l'action "Demander l'extraction" sur tous les clients avec interface
    [] remoteExec ["LL_fnc_task03a_addAction", 0];

    if (DEBUG_MODE) then {
        diag_log "[LL][task03a] Survivants activs en mode assaut — en attente de la demande d'extraction joueur.";
    };

    // Attendre que n'importe quel joueur demande l'extraction
    waitUntil {
        sleep 3;
        missionNamespace getVariable ["LL_Task03a_ExtractionCalled", false]
    };

    // ── Sous-tâche réussie — extraction confirmée ──────────────────────
    ["task_03a_surv", "SUCCEEDED", true] call BIS_fnc_taskSetState;
    ["STR_LL_Speaker_Narrator", "STR_LL_Task_03a_Narrative_Surv_Success"] remoteExec ["LL_fnc_showSubtitle", 0];

    if (DEBUG_MODE) then {
        diag_log "[LL][task03a] Extraction demandée par les joueurs — nettoyage des survivants ennemis.";
    };

    // Nettoyage immédiat des survivants ennemis (l'extraction arrive, ils sont éliminés)
    {
        private _grp   = _x;
        private _alive = (units _grp) select { alive _x };
        { if (!isNull _x && alive _x) then { deleteVehicle _x; }; } forEach _alive;
        if (!isNull _grp && { count units _grp == 0 }) then { deleteGroup _grp; };
    } forEach _allGroups;
};