#include "..\macros.hpp"

/*
 * LL_fnc_requestHelicopter
 *
 * Description:
 *   Fonction unique côté serveur de gestion du support hélicoptère (Chinook CUP_B_MH47E_USA).
 *   Garantit qu'un seul hélicoptère de support est actif sur la carte (verrou TAG_AirSupport_Active).
 *   La livraison de véhicule ("VEHICULE") ne peut être demandée qu'une seule fois dans la partie.
 *   L'hélicoptère apparaît à l'un des coins de la carte de Porto (le plus éloigné de la cible pour éviter les bugs)
 *   puis effectue la tâche désignée ("LIVRAISON", "VEHICULE", "DEBARQUEMENT", "EMBARQUEMENT") avant de retourner à son point de spawn.
 *
 * Arguments:
 *   0: <STRING>  Type de support ("LIVRAISON", "VEHICULE", "DEBARQUEMENT", "EMBARQUEMENT")
 *   1: <ARRAY>   Position cible [X, Y, Z]
 *   2: <OBJECT>  Le joueur ayant effectué la demande
 *
 * Locality:
 *   Serveur uniquement
 */

if (!isServer) exitWith {};

params [
    ["_supportType", "LIVRAISON", [""]],
    ["_targetPos", [0,0,0], [[]]],
    ["_caller", objNull, [objNull]],
    ["_actionTarget", objNull, [objNull]],
    ["_actionId", -1, [0]]
];

// 0. Vérification du cooldown pour le CAS (5 minutes / 300 secondes après le départ du dernier CAS)
if (_supportType == "CAS" && {time < (missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0])}) exitWith {
    private _cooldown = missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0];
    private _remaining = ceil (_cooldown - time);
    private _snd = selectRandom ["negatif01", "negatif02", "negatif03", "negatif04"];
    [_snd] remoteExec ["playSound", _caller];
    
    private _msg = format [localize "STR_TAG_Msg_CAS_Cooldown", _remaining];
    _msg remoteExec ["systemChat", _caller];
    diag_log format ["[LL] requestHelicopter: Soutien CAS refusé. Cooldown actif (%1s restants).", _remaining];
};

// 1. Vérification spécifique pour la livraison unique du véhicule
if (_supportType == "VEHICULE" && {missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false]}) exitWith {
    private _snd = selectRandom ["negatif01", "negatif02", "negatif03", "negatif04"];
    [_snd] remoteExec ["playSound", _caller];
    (localize "STR_TAG_Msg_Vehicle_Denied_Once") remoteExec ["systemChat", _caller];
    diag_log "[LL] requestHelicopter: Soutien véhicule refusé. Le véhicule de remplacement a déjà été livré.";
};

// 2. Vérifier si un soutien aérien est déjà en cours (Verrou unique et partagé)
if (missionNamespace getVariable ["TAG_AirSupport_Active", false]) exitWith {
    private _snd = selectRandom ["negatif01", "negatif02", "negatif03", "negatif04"];
    [_snd] remoteExec ["playSound", _caller];
    
    private _msg = "STR_TAG_Msg_Ammo_Denied";
    if (_supportType == "VEHICULE") then { _msg = "STR_TAG_Msg_Vehicle_Denied"; };
    if (_supportType == "CAS") then { _msg = "STR_TAG_Msg_CAS_Denied"; };
    
    (localize _msg) remoteExec ["systemChat", _caller];
    diag_log "[LL] requestHelicopter: Soutien refusé. TAG_AirSupport_Active est déjà actif.";
};

// Verrouiller immédiatement l'espace aérien
missionNamespace setVariable ["TAG_AirSupport_Active", true, true];

// Si c'est le véhicule, on verrouille définitivement la possibilité d'en demander un autre et on supprime l'action AddAction associée
if (_supportType == "VEHICULE") then {
    missionNamespace setVariable ["TAG_VehicleSupport_Delivered", true, true];
    if (!isNull _actionTarget && _actionId != -1) then {
        [_actionTarget, _actionId] remoteExec ["removeAction", 0, true];
    };
};

// Fallback pour les coordonnées de la cible
if (count _targetPos < 2) then { _targetPos = getPos _caller; };
if (count _targetPos < 3) then { _targetPos set [2, 0]; };

private _flyHeight = 150;
private _hoverHeight = 15; // 15m pour slingload munitions, 10m pour véhicule (sera ajusté en thread de vol)
private _loiterHeight = 60; // Pour le CAS
private _loiterRadius = 250; // Pour le CAS
private _loiterDuration = 120; // Pour le CAS

// Audios d'acceptation de la demande
[_supportType] spawn {
    params ["_type"];
    private _sndList = ["livraison01", "livraison02", "livraison03", "livraison04", "livraison05", "livraison06", "livraison07", "livraison08", "livraison09"];
    if (_type == "CAS") then {
        _sndList = ["soutien01", "soutien02", "soutien03", "soutien04"];
    };
    private _snd = selectRandom _sndList;
    _snd remoteExec ["playSound", 0];
};

private _approveMsg = "STR_TAG_Msg_Ammo_Approved";
if (_supportType == "VEHICULE") then { _approveMsg = "STR_TAG_Msg_Vehicle_Approved"; };
if (_supportType == "CAS") then { _approveMsg = "STR_TAG_Msg_CAS_Approved"; };
(localize _approveMsg) remoteExec ["systemChat", _caller];

// --- 1. DÉTERMINATION DE LA POSITION DE DESTINATION (HÉLIPORTS OU ROUTE INTELLIGENTE) ---
private _targetPosFinal = +_targetPos;

// --- CAS A : CALCUL INTELLIGENT DE ROUTE POUR LE VÉHICULE ---
if (_supportType == "VEHICULE") then {
    private _vehClass = if (!isNil "vehicule_team" && {!isNull vehicule_team}) then { typeOf vehicule_team } else { "CUP_B_nM1025_SOV_M2_USMC_DES" };
    private _activePlayers = allPlayers select { alive _x };
    if (count _activePlayers == 0) then { _activePlayers = [_caller]; };

    private _centerPos = [0, 0, 0];
    { _centerPos = _centerPos vectorAdd getPos _x; } forEach _activePlayers;
    _centerPos = _centerPos vectorMultiply (1 / (count _activePlayers));
    if (count _centerPos < 3) then { _centerPos set [2, 0]; };

    private _dropPos       = +_centerPos;
    private _foundGoodRoad = false;

    // Fonction locale : teste une liste de routes et retourne la première position propre
    private _fnc_testRoads = {
        params ["_roadList", "_strict"];
        private _checkRadius = if (_strict) then { 12 } else { 8 };
        private _badTypes = ["TREE", "SMALL TREE", "BUSH", "ROCK", "ROCKS", "HIDE",
                             "BUILDING", "HOUSE", "WALL", "FENCE"];
        {
            if (_foundGoodRoad) exitWith {};
            private _road    = _x;
            private _roadPos = getPos _road;
            if (!isOnRoad _roadPos) then { continue };

            for "_offset" from -15 to 15 step 5 do {
                if (_foundGoodRoad) exitWith {};

                private _roadDir = getDir _road;
                private _testPos = [
                    (_roadPos select 0) + _offset * sin(_roadDir),
                    (_roadPos select 1) + _offset * cos(_roadDir),
                    0
                ];

                if (surfaceIsWater _testPos) then { continue };
                if (!isOnRoad _testPos)      then { continue };

                private _nearBad = nearestTerrainObjects [_testPos, _badTypes, _checkRadius, false, true];
                if (count _nearBad > 0) then { continue };

                private _emptyPos = _testPos findEmptyPosition [0, _checkRadius, _vehClass];
                if (count _emptyPos > 0 && { _emptyPos distance2D _testPos <= _checkRadius }) then {
                    _dropPos = _emptyPos;
                    _dropPos set [2, 0];
                    _foundGoodRoad = true;
                };
            };
        } forEach _roadList;
    };

    // Passe 1 : routes larges et proches (rayon 800 m — critères stricts)
    private _allRoads = _centerPos nearRoads 800;
    _allRoads = [_allRoads, [], {
        private _info = getRoadInfo _x;
        (_info select 1) + (10000 / ((_x distance2D _centerPos) max 1))
    }, "DESCEND"] call BIS_fnc_sortBy;
    [_allRoads, true] call _fnc_testRoads;

    // Passe 2 : rayon élargi à 2000 m — critères légèrement souples
    if (!_foundGoodRoad) then {
        _allRoads = _centerPos nearRoads 2000;
        _allRoads = [_allRoads, [], { _x distance2D _centerPos }, "ASCEND"] call BIS_fnc_sortBy;
        [_allRoads, false] call _fnc_testRoads;
    };

    // Repli ultime : position plate dégagée sans route
    if (!_foundGoodRoad) then {
        private _safePos = [_centerPos, 0, 300, 10, 0, 0.35, 0, [], _centerPos] call BIS_fnc_findSafePos;
        if (_safePos isEqualType [] && { count _safePos >= 2 } && { _safePos distance2D _centerPos < 1200 }) then {
            _dropPos = _safePos;
        };
        _dropPos set [2, 0];
    };

    _targetPosFinal = _dropPos;
    diag_log format ["[LL] requestHelicopter: Position de largage véhicule calculée : %1 (sur route: %2)", _targetPosFinal, _foundGoodRoad];
};

// --- CAS B : HÉLIPORTS INVISIBLES POUR DÉBARQUEMENT ET EMBARQUEMENT ---
if (_supportType == "DEBARQUEMENT" || _supportType == "EMBARQUEMENT") then {
    private _heliports = [];
    private _i = 0;
    while {true} do {
        private _numStr = "";
        if (_i < 10) then {
            _numStr = "00" + str _i;
        } else {
            if (_i < 100) then {
                _numStr = "0" + str _i;
            } else {
                _numStr = str _i;
            };
        };
        private _varName = "Heliport_" + _numStr;
        private _heliportObj = missionNamespace getVariable [_varName, objNull];
        if (isNull _heliportObj) exitWith {};
        _heliports pushBack _heliportObj;
        _i = _i + 1;
    };

    // Trouver l'héliport le plus proche de la cible demandée
    private _nearestHeliport = objNull;
    private _minDist = 999999;
    {
        private _dist = _x distance2D _targetPos;
        if (_dist < _minDist) then {
            _minDist = _dist;
            _nearestHeliport = _x;
        };
    } forEach _heliports;

    // Si on trouve un héliport à moins de 250m, on utilise sa position exacte
    if (!isNull _nearestHeliport && { _nearestHeliport distance2D _targetPos < 250 }) then {
        _targetPosFinal = getPosATL _nearestHeliport;
        diag_log format ["[LL] requestHelicopter: Héliport invisible détecté à proximité. Utilisation de %1 (pos: %2)", vehicleVarName _nearestHeliport, _targetPosFinal];
    };
};

// --- CAS C : POSITION PLATE POUR LE CAS ---
if (_supportType == "CAS") then {
    private _dropPos = +_targetPos;
    private _flatCheck = _dropPos isFlatEmpty [5, -1, 0.4, 5, 0, false, objNull];
    if (_flatCheck isEqualTo []) then {
         private _safePos = [_dropPos, 0, 100, 5, 0, 0.4, 0, [], _dropPos] call BIS_fnc_findSafePos;
         if (_safePos isEqualType [] && {count _safePos >= 2}) then {
            _dropPos = _safePos;
            if (count _dropPos < 3) then { _dropPos set [2, 0]; };
         };
    };
    _targetPosFinal = _dropPos;
    diag_log format ["[LL] requestHelicopter: Position orbitale CAS calculée : %1", _targetPosFinal];
};

// --- 2. DÉTERMINATION DU COIN DE SPAWN LE PLUS ÉLOIGNÉ ---
// Porto fait 5120m x 5120m. Les coins à 200m du bord sont sur l'eau et très stables.
private _corners = [
    [200, 200, _flyHeight],     // Sud-Ouest
    [200, 4920, _flyHeight],    // Nord-Ouest
    [4920, 4920, _flyHeight],   // Nord-Est
    [4920, 200, _flyHeight]     // Sud-Est
];

private _spawnPos = _corners select 0;
private _maxDist = 0;
{
    private _dist = _x distance2D _targetPosFinal;
    if (_dist > _maxDist) then {
        _maxDist = _dist;
        _spawnPos = _x;
    };
} forEach _corners;

private _homeBase = +_spawnPos;
private _helicoClass = "CUP_B_MH47E_USA";

// --- 3. CRÉATION DE L'HÉLICOPTÈRE ET DE L'ÉQUIPAGE ---
private _heli = objNull;
private _spawnAttempts = 0;
while {isNull _heli && _spawnAttempts < 5} do {
    _spawnAttempts = _spawnAttempts + 1;
    _heli = createVehicle [_helicoClass, _spawnPos, [], 0, "FLY"];
    if (!isNull _heli) then {
        _heli setPos _spawnPos;
        _heli setDir (_spawnPos getDir _targetPosFinal);
        _heli flyInHeight _flyHeight;
        _heli allowDamage false; // Invincible pour la sécurité du vol IA
    } else {
        sleep 1;
    };
};

if (isNull _heli) exitWith {
    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
    
    private _errorMsg = if (_supportType == "VEHICULE") then { "STR_TAG_Msg_Vehicle_Error" } else { "STR_TAG_Msg_Ammo_Error" };
    (localize _errorMsg) remoteExec ["systemChat", _caller];
    diag_log "[LL][ERROR] requestHelicopter: Échec de la création de l'hélicoptère.";
};

// Assigner les pilotes et artilleurs de l'équipage dans le bon camp (allié aux joueurs - indépendant RACS)
private _side = if (!isNull _caller) then { side (group _caller) } else { independent };
private _group = createGroup [_side, true];
private _crew = [];

private _pilotClass = "CUP_I_RACS_Pilot";
private _soldierClass = "CUP_I_RACS_Soldier";
if (_side == west) then {
    _pilotClass = "B_Helipilot_F";
    _soldierClass = "B_Soldier_F";
};

// Pilote
private _pilot = _group createUnit [_pilotClass, [0,0,0], [], 0, "NONE"];
_pilot moveInDriver _heli;
_crew pushBack _pilot;

// Copilote (sur la tourelle [0])
private _copilot = _group createUnit [_pilotClass, [0,0,0], [], 0, "NONE"];
_copilot moveInTurret [_heli, [0]];
_crew pushBack _copilot;

// Artilleurs des autres tourelles
private _turrets = allTurrets _heli;
private _gunnerTurrets = _turrets select { _x isNotEqualTo [0] };
{
    private _gunner = _group createUnit [_soldierClass, [0,0,0], [], 0, "NONE"];
    _gunner moveInTurret [_heli, _x];
    _crew pushBack _gunner;
} forEach _gunnerTurrets;

_group setBehaviour "CARELESS";
_group setCombatMode "RED";
_group setSpeedMode "FULL";

{
    _x disableAI "FSM";
    _x allowDamage false; // Invincibles également
} forEach _crew;

// Enregistrer l'hélicoptère globalement
missionNamespace setVariable ["LL_missionHelicopter", _heli, true];

// --- 4. EXÉCUTION DU THREAD DE VOL ET COMPORTEMENT ---
[_heli, _targetPosFinal, _group, _crew, _homeBase, _supportType, _caller, _flyHeight, _hoverHeight, _side, _pilotClass, _soldierClass, _loiterHeight, _loiterRadius, _loiterDuration] spawn {
    params ["_heli", "_dropPos", "_group", "_crew", "_homeBase", "_supportType", "_caller", "_flyHeight", "_hoverHeight", "_side", "_pilotClass", "_soldierClass", "_loiterHeight", "_loiterRadius", "_loiterDuration"];
    
    private _isSlingload = (_supportType == "LIVRAISON" || _supportType == "VEHICULE");
    private _cargo = objNull;
    private _originalMass = 0;
    
    // Si livraison de véhicule, la hauteur stationnaire finale est de 10m au lieu de 15m
    if (_supportType == "VEHICULE") then { _hoverHeight = 10; };

    // --- PREPARATION DU SLINGLOAD ---
    if (_isSlingload) then {
        private _cargoClass = "B_supplyCrate_F";
        if (_supportType == "VEHICULE") then {
            _cargoClass = if (!isNil "vehicule_team" && {!isNull vehicule_team}) then { typeOf vehicule_team } else { "CUP_B_nM1025_SOV_M2_USMC_DES" };
            // Supprimer l'ancienne instance ou son épave
            if (!isNil "vehicule_team" && {!isNull vehicule_team}) then {
                deleteVehicle vehicule_team;
            };
        };
        _cargo = createVehicle [_cargoClass, [0,0,0], [], 0, "NONE"];
        _cargo setPos (_heli modelToWorld [0, 0, -15]);
        _cargo allowDamage false;
        _originalMass = getMass _cargo;
        
        // Poids stabilisateur (500 pour la caisse, 800 pour le véhicule)
        private _stabilizerMass = if (_supportType == "LIVRAISON") then { 500 } else { 800 };
        _cargo setMass _stabilizerMass;
        _heli setSlingLoad _cargo;

        // Remplissage dynamique à partir de l'équipement des joueurs (seulement pour les munitions)
        if (_supportType == "LIVRAISON") then {
            clearWeaponCargoGlobal _cargo;
            clearMagazineCargoGlobal _cargo;
            clearItemCargoGlobal _cargo;
            clearBackpackCargoGlobal _cargo;

            private _allWeapons = [];
            private _allMagazines = [];
            private _allItems = [];
            private _allBackpacks = [];
            
            private _legionUnits = [];
            for "_i" from 0 to 6 do {
                private _unit = missionNamespace getVariable [format ["player_%1", _i], objNull];
                if (!isNull _unit) then { _legionUnits pushBack _unit; };
            };

            {
                if (!isNull _x && {side _x == independent || side _x == west}) then {
                    private _pw = _x getVariable ["TAG_Initial_Primary", primaryWeapon _x];
                    private _sw = _x getVariable ["TAG_Initial_Secondary", secondaryWeapon _x];
                    private _hw = _x getVariable ["TAG_Initial_Handgun", handgunWeapon _x];
                    
                    if (_pw != "") then { _allWeapons pushBackUnique _pw; };
                    if (_sw != "") then { _allWeapons pushBackUnique _sw; };
                    if (_hw != "") then { _allWeapons pushBackUnique _hw; };
                    
                    private _mags = _x getVariable ["TAG_Initial_Mags", magazines _x];
                    { _allMagazines pushBackUnique _x; } forEach _mags;
                    
                    private _itm = _x getVariable ["TAG_Initial_Items", items _x + assignedItems _x];
                    { _allItems pushBackUnique _x; } forEach _itm;
                    
                    private _bp = _x getVariable ["TAG_Initial_Backpack", backpack _x];
                    if (_bp != "") then { _allBackpacks pushBackUnique _bp; };
                };
            } forEach _legionUnits;

            { _cargo addWeaponCargoGlobal [_x, 2]; } forEach _allWeapons;
            { _cargo addMagazineCargoGlobal [_x, 20]; } forEach _allMagazines;
            { _cargo addItemCargoGlobal [_x, 5]; } forEach _allItems;
            { _cargo addBackpackCargoGlobal [_x, 2]; } forEach _allBackpacks;

            _cargo addMagazineCargoGlobal ["SmokeShell", 10];
            _cargo addMagazineCargoGlobal ["SmokeShellGreen", 10];
            _cargo addItemCargoGlobal ["FirstAidKit", 20];
        };
    };

    // Marqueur temporaire sur la zone de livraison (Munitions ou Véhicule)
    private _marker = objNull;
    if (_isSlingload) then {
        private _markerName = format ["delivery_mrk_%1_%2", _supportType, floor(random 10000)];
        _marker = createMarker [_markerName, _dropPos];
        _marker setMarkerType "mil_pickup";
        _marker setMarkerColor "ColorBlue";
        
        private _txt = if (_supportType == "LIVRAISON") then { "Drop Logistique" } else { localize "STR_TAG_Msg_Vehicle_Marker" };
        _marker setMarkerText _txt;
        
        [_marker] spawn {
            params ["_m"];
            sleep 120;
            deleteMarker _m;
        };
    };

    // --- PHASE 1 : VOL VERS LA CIBLE ---
    private _wp1 = _group addWaypoint [_dropPos, 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointBehaviour "CARELESS";
    _wp1 setWaypointSpeed "FULL";
    _heli doMove _dropPos;
    
    private _approachTimeout = 0;
    waitUntil {
        sleep 1;
        _approachTimeout = _approachTimeout + 1;
        ((_heli distance2D _dropPos) < 200) || _approachTimeout > 180 || !alive _heli
    };
    
    if (!alive _heli) exitWith { 
        missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; 
        missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
    };
    
    deleteWaypoint [_group, 0];

    // --- PHASE 2 : EXÉCUTION DES TÂCHES SPÉCIFIQUES ---
    
    // --- CAS A : LARGAGE MUNITIONS OU VÉHICULE ---
    if (_isSlingload) then {
        // Approche finale et vol stationnaire
        _heli flyInHeight _hoverHeight;
        _heli flyInHeightASL [_hoverHeight, _hoverHeight, _hoverHeight];
        
        private _wp2 = _group addWaypoint [_dropPos, 0];
        _wp2 setWaypointType "MOVE";
        _wp2 setWaypointBehaviour "CARELESS";
        _wp2 setWaypointSpeed "FULL";
        _heli doMove _dropPos;
        
        private _positionTimeout = 0;
        waitUntil {
            sleep 0.5;
            _positionTimeout = _positionTimeout + 0.5;
            ((_heli distance2D _dropPos) < 5) || _positionTimeout > 30 || !alive _heli
        };
        
        if (!alive _heli) exitWith { 
            missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; 
            missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
        };
        
        doStop _heli;
        _heli flyInHeight _hoverHeight;
        
        // Descente progressive du colis
        private _dropTimeout = 0;
        private _cargoGrounded = false;
        private _minCargoHeight = if (_supportType == "LIVRAISON") then { 5 } else { 4 };
        
        waitUntil {
            sleep 0.5;
            _dropTimeout = _dropTimeout + 0.5;
            private _newHeight = _hoverHeight - _dropTimeout;
            if (_newHeight < _minCargoHeight) then { _newHeight = _minCargoHeight; };
            
            _heli flyInHeight _newHeight;
            _heli flyInHeightASL [_newHeight, _newHeight, _newHeight];
            
            _cargoGrounded = (getPosATL _cargo select 2) < 3;
            if ((getPosATL _heli select 2) < 4) then {
                _cargoGrounded = true;
            };
            _cargoGrounded || _dropTimeout > 30 || !alive _heli || !alive _cargo
        };
        
        if (!alive _heli || !alive _cargo) exitWith { 
            missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; 
            missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
        };
        
        private _dropTime = time;
        sleep 1;
        
        // Détachement du câble
        private _allRopes = ropes _heli;
        { ropeDestroy _x; } forEach _allRopes;
        _heli setSlingLoad objNull;
        
        sleep 1;
        _cargo setVelocity [0, 0, 0];
        _cargo setVectorUp [0, 0, 1];
        _cargo setMass _originalMass; // Restaurer la masse d'origine
        _cargo allowDamage true;
        
        if (_supportType == "LIVRAISON") then {
            (localize "STR_TAG_Msg_Ammo_Dropped") remoteExec ["systemChat", _caller];
            
            // Signalisation fumigène et nettoyage
            [_cargo] spawn {
                params ["_crate"];
                private _smoke = createVehicle ["SmokeShellGreen", getPos _crate, [], 0, "CAN_COLLIDE"];
                
                sleep 590; // Supprimer au bout de 10 min
                if (alive _crate) then {
                    for "_i" from 0 to 360 step 45 do {
                        private _smokePos = _crate getPos [2, _i];
                        createVehicle ["SmokeShell", _smokePos, [], 0, "CAN_COLLIDE"];
                    };
                    sleep 10;
                    if (alive _crate) then { deleteVehicle _crate; };
                };
            };
        } else {
            (localize "STR_TAG_Msg_Vehicle_Dropped") remoteExec ["systemChat", _caller];
            missionNamespace setVariable ["vehicule_team", _cargo, true];
        };
    };

    // --- CAS SPÉCIFIQUE : APPUI AÉRIEN (CAS) ---
    if (_supportType == "CAS") then {
        _heli flyInHeight _loiterHeight;
        _heli flyInHeightASL [_loiterHeight, _loiterHeight, _loiterHeight];

        private _wpCAS = _group addWaypoint [_dropPos, 0];
        _wpCAS setWaypointType "LOITER";
        _wpCAS setWaypointLoiterType "CIRCLE";
        _wpCAS setWaypointLoiterRadius _loiterRadius;
        _wpCAS setWaypointBehaviour "CARELESS";
        _wpCAS setWaypointCombatMode "RED";
        _wpCAS setWaypointSpeed "LIMITED";
        
        _heli doMove _dropPos;

        private _endTime = time + _loiterDuration;
        while {time < _endTime && alive _heli} do {
            // Révéler uniquement les OPFOR (east) à l'hélicoptère
            private _targets = allUnits select { alive _x && {side _x == east} && {_x distance2D _dropPos < 500} };
            {
                _group reveal [_x, 4];
            } forEach _targets;
            sleep 5;
        };

        deleteWaypoint [_group, 0];
    };

    // --- CAS B & C : DEBARQUEMENT ET EMBARQUEMENT ---
    if (_supportType == "DEBARQUEMENT" || _supportType == "EMBARQUEMENT") then {
        _heli flyInHeight 0;
        _heli land (if (_supportType == "DEBARQUEMENT") then { "GET OUT" } else { "GET IN" });
        
        private _landTimeout = 0;
        waitUntil {
            sleep 1;
            _landTimeout = _landTimeout + 1;
            !alive _heli || 
            {isTouchingGround _heli} || 
            {(velocity _heli select 2 == 0 && (getPosVisual _heli select 2) < 2)} ||
            _landTimeout > 60
        };
        
        if (!alive _heli) exitWith { 
            missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; 
            missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
        };
        
        // Débarquement d'unités alliées
        if (_supportType == "DEBARQUEMENT") then {
            private _infGroup = createGroup [_side, true];
            private _unitTypes = [
                "CUP_I_RACS_Soldier_SL", 
                "CUP_I_RACS_Soldier_Medic", 
                "CUP_I_RACS_Soldier_MG", 
                "CUP_I_RACS_Soldier_LAT", 
                "CUP_I_RACS_Soldier"
            ];
            private _reinforcements = [];
            {
                private _unit = _infGroup createUnit [_x, _dropPos, [], 0, "NONE"];
                _unit moveInCargo _heli;
                _reinforcements pushBack _unit;
            } forEach _unitTypes;
            
            sleep 1;
            
            // Évacuation
            {
                unassignVehicle _x;
                moveOut _x;
                sleep 0.5;
            } forEach _reinforcements;
            
            private _unloadTimeout = 0;
            waitUntil {
                sleep 1;
                _unloadTimeout = _unloadTimeout + 1;
                !alive _heli || { { _x in _heli } count _reinforcements == 0 } || _unloadTimeout > 30
            };
            
            // Rejoindre le groupe du leader joueur
            private _playerGroup = if (!isNull _caller) then { group _caller } else { grpNull };
            if (!isNull _playerGroup) then {
                _reinforcements joinSilent _playerGroup;
                (localize "STR_LL_Heli_Msg_Squad_Joined") remoteExec ["systemChat", 0];
            } else {
                [_infGroup, _dropPos, 150] call BIS_fnc_taskPatrol;
                (localize "STR_LL_Heli_Msg_Patrol_Started") remoteExec ["systemChat", 0];
            };
        };
        
        // Embarquement (Extraction / Otage)
        if (_supportType == "EMBARQUEMENT") then {
            (localize "STR_LL_Heli_Msg_Landed_Extract") remoteExec ["systemChat", 0];
            
            private _startTime = time;
            private _timeout = _startTime + 600; // 10 minutes d'attente (600 secondes)
            private _shouldLeave = false;
            
            waitUntil {
                sleep 2;
                
                // Récupérer tous les joueurs humains vivants sur le serveur
                private _allHumanPlayers = allPlayers select { alive _x };
                // Filtrer les joueurs humains vivants actuellement dans l'hélicoptère
                private _playersInHeli = crew _heli select { _x in _allHumanPlayers };
                
                private _numTotalPlayers = count _allHumanPlayers;
                private _numPlayersInHeli = count _playersInHeli;
                
                if (_numPlayersInHeli > 0) then {
                    // S'il y a des joueurs à bord, on attend qu'ils soient tous à bord
                    if (_numPlayersInHeli >= _numTotalPlayers) then {
                        _shouldLeave = true;
                    };
                } else {
                    // S'il n'y a aucun joueur à bord, l'hélicoptère repart après 10 minutes
                    if (time > _timeout) then {
                        _shouldLeave = true;
                    };
                };
                
                !alive _heli || _shouldLeave
            };
            
            (localize "STR_LL_Heli_Msg_Departing") remoteExec ["systemChat", 0];
        };
    };

    // --- PHASE 3 : RETOUR ET DESPAWN ---
    if (_supportType == "CAS") then {
        (localize "STR_TAG_Msg_CAS_RTB") remoteExec ["systemChat", _caller];
    };
    sleep 2;
    _heli flyInHeight _flyHeight;
    
    private _wpHome = _group addWaypoint [_homeBase, 0];
    _wpHome setWaypointType "MOVE";
    _wpHome setWaypointBehaviour "CARELESS";
    _wpHome setWaypointSpeed "FULL";
    _heli doMove _homeBase;
    
    // Libération immédiate du verrou pour que le joueur puisse demander une autre action
    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
    
    private _returnTime = time;
    waitUntil {
        sleep 5;
        (_heli distance2D _homeBase < 200) || !alive _heli || (time - _returnTime > 180)
    };
    
    if (alive _heli) then {
        // Extraction finale : si des joueurs sont à bord au retour, c'est un succès de mission
        private _hasPlayers = {isPlayer _x} count crew _heli > 0;
        if (_hasPlayers) then {
            ["MissionSuccess", true, true] remoteExec ["BIS_fnc_endMission", 0];
        } else {
            { deleteVehicle _x } forEach _crew;
            deleteVehicle _heli;
            deleteGroup _group;
            if (_supportType == "CAS") then {
                missionNamespace setVariable ["TAG_CAS_Cooldown_Until", time + 300, true];
            };
        };
    } else {
        deleteGroup _group;
        if (_supportType == "CAS") then {
            missionNamespace setVariable ["TAG_CAS_Cooldown_Until", time + 300, true];
        };
    };
    
    missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
};
