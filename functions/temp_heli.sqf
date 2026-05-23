/*
 * fn_requestHelicopter.sqf
 * Locality: Server Only (exécutez via remoteExecCall ["TAG_fnc_requestHelicopter", 2])
 * Description: Hélicoptère CAS (Appui Aérien). L'hélicoptère apparaît, cible la zone, 
 *              engage les ennemis, et se retire au bout du temps imparti.
 */

if (!isServer) exitWith {};

params [
    ["_targetPos", [0,0,0], [[]]],
    ["_caller", objNull, [objNull]]
];

// Vérifier si un soutien est déjà en cours
if (missionNamespace getVariable ["TAG_AirSupport_Active", false]) exitWith {
    private _snd = selectRandom ["negatif01", "negatif02", "negatif03", "negatif04"];
    [_snd] remoteExec ["playSound", _caller];
    (localize "STR_TAG_Msg_CAS_Denied") remoteExec ["systemChat", _caller];
};

// Verrouiller le soutien
missionNamespace setVariable ["TAG_AirSupport_Active", true, true];

// Nettoyage de la position
if (count _targetPos < 2) then { _targetPos = getPos _caller; };
if (count _targetPos < 3) then { _targetPos set [2, 0]; };
_targetPos = _targetPos apply { if (isNil "_x") then {0} else {_x} };

// Variables de configuration
private _spawnDist = 2000;
private _helicoClass = "B_AMF_Heli_Transport_01_F";  
private _flyHeight = 150;
private _loiterHeight = 60; // Hauteur pour attaque optimale
private _loiterRadius = 250;  
private _loiterDuration = 120;  
private _dir = random 360;

// Audios d'acceptation (joués pour tous les joueurs)
[] spawn {
    private _snd = selectRandom ["soutien01", "soutien02", "soutien03", "soutien04"];
    _snd remoteExec ["playSound", 0];
};

(localize "STR_TAG_Msg_CAS_Approved") remoteExec ["systemChat", _caller];

// Position de spawn
private _spawnPos = _targetPos vectorAdd [(_spawnDist * (sin _dir)), (_spawnDist * (cos _dir)), _flyHeight];
if (count _spawnPos < 3) then { _spawnPos set [2, _flyHeight]; };

private _heli = objNull;
private _spawnAttempts = 0;
while {isNull _heli && _spawnAttempts < 5} do {
    _spawnAttempts = _spawnAttempts + 1;
    _heli = createVehicle [_helicoClass, _spawnPos, [], 0, "FLY"];
    if (!isNull _heli) then {
        _heli setPos _spawnPos;
        _heli setDir (_dir + 180);
        _heli flyInHeight _flyHeight;
        _heli allowDamage false;
    } else {
        sleep 1;
    };
};

if (isNull _heli) exitWith {
    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
    (localize "STR_TAG_Msg_CAS_Error") remoteExec ["systemChat", _caller];
};

// =========================================================================
// GESTION DE L'ÉQUIPAGE (OPTIMISÉ POUR LE TIR)
// =========================================================================
private _pilotGroup = createGroup [WEST, true];
private _gunnerGroup = createGroup [WEST, true];
private _crew = [];

private _pilot = _pilotGroup createUnit ["B_Helipilot_F", _spawnPos, [], 0, "NONE"];
_pilot moveInDriver _heli;
_crew pushBack _pilot;

private _copilot = _pilotGroup createUnit ["B_Helipilot_F", _spawnPos, [], 0, "NONE"];
_copilot moveInTurret [_heli, [0]];
_crew pushBack _copilot;

private _turrets = allTurrets _heli;
private _gunnerTurrets = _turrets select { _x isNotEqualTo [0] };  

{
    private _gunner = _gunnerGroup createUnit ["B_Soldier_F", _spawnPos, [], 0, "NONE"];
    _gunner moveInTurret [_heli, _x];
    _gunner setSkill 1; // Précision maximale
    _crew pushBack _gunner;
} forEach _gunnerTurrets;

{
    _x allowDamage false; 
    // ATTENTION: interdiction d'utiliser disableAI "FSM" sur les IA qui doivent tirer
} forEach _crew;

// ---- Configuration du vol (Pilotes) ----
_pilotGroup setBehaviour "CARELESS"; // Le pilote suit strictement les waypoints sans chercher à esquiver
_pilotGroup setCombatMode "BLUE";    // Le groupe de pilotage ne tire pas
_pilotGroup setSpeedMode "FULL";

{
    _x disableAI "TARGET"; 
    _x disableAI "AUTOTARGET"; 
    _x disableAI "AUTOCOMBAT";       // Empêcher l'interruption des waypoints pour le combat
} forEach (units _pilotGroup);

// ---- Configuration de l'attaque (Artilleurs) ----
_gunnerGroup setBehaviour "COMBAT"; // Les artilleurs cherchent les cibles
_gunnerGroup setCombatMode "RED";   // Comportement de tir "Feu à Volonté"


// =========================================================================
// THREAD DE VOL ET COMBAT
// =========================================================================
[_heli, _targetPos, _pilotGroup, _gunnerGroup, _crew, _spawnPos, _loiterHeight, _loiterRadius, _loiterDuration, _caller] spawn {
    params ["_heli", "_targetPos", "_pilotGroup", "_gunnerGroup", "_crew", "_homeBase", "_loiterHeight", "_loiterRadius", "_loiterDuration", "_caller"];
    
    // Trouver un point plat autour
    private _dropPos = +_targetPos;
    if (count _dropPos >= 2) then {
        private _flatCheck = _dropPos isFlatEmpty [5, -1, 0.4, 5, 0, false, objNull];
        if (_flatCheck isEqualTo []) then {
             private _safePos = [_dropPos, 0, 100, 5, 0, 0.4, 0, [], _dropPos] call BIS_fnc_findSafePos;
             if (_safePos isEqualType [] && {count _safePos >= 2}) then {
                _dropPos = _safePos;
                if (count _dropPos < 3) then { _dropPos set [2, 0]; };
             };
        };
    };
    
    // Marqueur visuel sur carte global/local
    private _markerName = format ["cas_mrk_%1", floor(random 10000)];
    private _marker = createMarker [_markerName, _dropPos];
    _marker setMarkerType "mil_warning";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerText "CAS";
    
    [_marker, _loiterDuration] spawn {
        params ["_m", "_d"];
        sleep (_d + 60);  
        deleteMarker _m;
    };
    
    // === 1. WAYPOINT D'APPROCHE ===
    private _wp1 = _pilotGroup addWaypoint [_dropPos, 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointBehaviour "CARELESS";
    _wp1 setWaypointSpeed "FULL";
    _heli doMove _dropPos;
    
    // Attendre l'arrivée sur zone
    private _approachTimeout = 0;
    waitUntil {
        sleep 1;
        _approachTimeout = _approachTimeout + 1;
        ((_heli distance2D _dropPos) < 400) || _approachTimeout > 180 || !alive _heli
    };
    
    if (!alive _heli) exitWith { missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; };
    
    deleteWaypoint [_pilotGroup, 0];
    
    // === 2. ORBITE D'ATTAQUE ===
    _heli flyInHeight _loiterHeight;
    _heli flyInHeightASL [_loiterHeight, _loiterHeight, _loiterHeight];
    
    private _wp2 = _pilotGroup addWaypoint [_dropPos, 0];
    _wp2 setWaypointType "LOITER";
    _wp2 setWaypointLoiterType "CIRCLE";
    _wp2 setWaypointLoiterRadius _loiterRadius;  
    _wp2 setWaypointBehaviour "CARELESS";  
    _wp2 setWaypointSpeed "LIMITED";  
    _heli doMove _dropPos;
    
    private _endTime = time + _loiterDuration;
    
    // === RADAR ET ENGAGEMENT DYNAMIQUE ===
    while {time < _endTime && alive _heli} do {
        // Obtenir toutes les cibles potentielles dans une large zone
        private _nearEnemies = _heli nearEntities [["Man", "Car", "Tank"], 800];
        
        {
            if (side _x == east || side _x == independent) then {
                // Révéler les ennemis au groupe TIREUR pour accéléner l'acquisition
                _gunnerGroup reveal [_x, 4];  
                _pilotGroup reveal [_x, 4]; 
            };
        } forEach _nearEnemies;
        
        // Assurer que les munitions de l'hélico ne tombent pas à sec
        _heli setVehicleAmmo 1;

        sleep 5;
    }; 
    
    if (!alive _heli) exitWith { missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; };
    
    // === 3. RTB (RETOUR BASE) ===
    while {(count (waypoints _pilotGroup)) > 0} do {
        deleteWaypoint [_pilotGroup, 0];
    };
    
    _heli flyInHeight 150;
    _heli flyInHeightASL [150, 150, 150];
    
    private _wpHome = _pilotGroup addWaypoint [[0,0,0], 0];
    _wpHome setWaypointType "MOVE";
    _wpHome setWaypointBehaviour "CARELESS";
    _wpHome setWaypointSpeed "FULL";
    _heli doMove [0,0,0];
    
    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
    (localize "STR_TAG_Msg_CAS_RTB") remoteExec ["systemChat", _caller];
    
    // === 4. NETTOYAGE LORSQU'IL EST LOIN ===
    waitUntil {
        sleep 5;
        private _players = allPlayers select { alive _x };
        private _tooClose = _players findIf { (_x distance2D _heli) < 2000 } > -1;
        (!_tooClose) || !alive _heli
    };
    
    { deleteVehicle _x } forEach _crew;
    deleteVehicle _heli;
    deleteGroup _pilotGroup;
    deleteGroup _gunnerGroup;
};