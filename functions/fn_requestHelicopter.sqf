#include "..\macros.hpp"
/*
 * LL_fnc_requestHelicopter
 * Locality : Serveur uniquement
 *
 * Appelé depuis fn_addHelicopterActions via :
 *   ["CAS", getPos player, player, _target, _actionId] remoteExec ["LL_fnc_requestHelicopter", 2]
 *
 * Paramètres :
 *   0 : STRING  — Type de support : "CAS" | "LIVRAISON" | "VEHICULE" | "DEBARQUEMENT" | "EMBARQUEMENT"
 *   1 : ARRAY   — Position cible [X, Y, Z]
 *   2 : OBJECT  — Joueur demandeur
 *   3 : OBJECT  — Objet cible de l'AddAction (pour suppression éventuelle)
 *   4 : NUMBER  — ID de l'AddAction
 *
 * Véhicule : CUP_I_CH47F_RACS (Faction : independent — Royal Army Corps of Sahrani)
 * Équipage : createVehicleCrew — garantit l'équipage RACS natif sans hardcoder les classnames
 */

if (!isServer) exitWith {};

params [
    ["_supportType",  "CAS",   [""]],
    ["_targetPos",    [0,0,0], [[]]],
    ["_caller",       objNull, [objNull]],
    ["_actionTarget", objNull, [objNull]],
    ["_actionId",     -1,      [0]]
];

// ─── GARDE : soutien déjà actif ───────────────────────────────────────────────
if (missionNamespace getVariable ["TAG_AirSupport_Active", false]) exitWith {
    (localize "STR_TAG_Msg_CAS_Denied") remoteExec ["systemChat", _caller];
};

// Seul le CAS est implémenté dans cette version
if (_supportType != "CAS") exitWith {
    diag_log format ["[LL][HELI] Type '%1' non géré dans cette version.", _supportType];
};

// ─── VERROU ───────────────────────────────────────────────────────────────────
missionNamespace setVariable ["TAG_AirSupport_Active", true, true];

// ─── SANITIZE POSITION ────────────────────────────────────────────────────────
if (count _targetPos < 2) then { _targetPos = getPos _caller; };
if (count _targetPos < 3) then { _targetPos set [2, 0]; };
_targetPos = _targetPos apply { if (isNil "_x") then {0} else {_x} };

// ─── VARIABLES ────────────────────────────────────────────────────────────────
private _spawnDist      = 2000;
private _helicoClass    = "CUP_I_CH47F_RACS";
private _flyHeight      = 150;
private _loiterHeight   = 60;
private _loiterRadius   = 250;
private _loiterDuration = 120;
private _dir            = random 360;

(localize "STR_TAG_Msg_CAS_Approved") remoteExec ["systemChat", _caller];

// ─── POSITION DE SPAWN (hors champ, aléatoire) ────────────────────────────────
private _spawnPos = _targetPos vectorAdd [
    (_spawnDist * (sin _dir)),
    (_spawnDist * (cos _dir)),
    _flyHeight
];
if (count _spawnPos < 3) then { _spawnPos set [2, _flyHeight]; };

// ─── CRÉATION DE L'HÉLICOPTÈRE ────────────────────────────────────────────────
private _heli = objNull;
private _spawnAttempts = 0;
while {isNull _heli && _spawnAttempts < 5} do {
    _spawnAttempts = _spawnAttempts + 1;
    _heli = createVehicle [_helicoClass, _spawnPos, [], 0, "FLY"];
    if (!isNull _heli) then {
        _heli setPos      _spawnPos;
        _heli setDir      (_dir + 180);
        _heli flyInHeight _flyHeight;
        _heli allowDamage false;
    } else {
        sleep 1;
    };
};

if (isNull _heli) exitWith {
    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
    (localize "STR_TAG_Msg_CAS_Error") remoteExec ["systemChat", _caller];
    diag_log "[LL][HELI][ERROR] Impossible de créer CUP_I_CH47F_RACS après 5 tentatives.";
};

diag_log format ["[LL][HELI] Hélicoptère créé : %1 à %2", _heli, _spawnPos];

// ─── ÉQUIPAGE RACS (INDEPENDENT) ──────────────────────────────────────────────
// createVehicleCrew crée l'équipage natif du CH47F RACS (independent) sans hardcoder de classnames.
createVehicleCrew _heli;
sleep 0.3;
_heli setVehicleAmmo 1;

private _crew    = crew _heli;
private _group   = group (_crew select { true } # 0);
private _pilot   = driver _heli;
private _copilot = _heli turretUnit [0];
private _gunners = _crew select { _x != _pilot && { _x != _copilot } };

diag_log format ["[LL][HELI] Équipage : %1 membres | Pilote=%2 | Copilote=%3 | Artilleurs=%4",
    count _crew, _pilot, _copilot, count _gunners];

// Comportement du groupe : CARELESS pour que le pilote suive ses waypoints sans dévier
_group setBehaviour  "CARELESS";
_group setCombatMode "RED";      // Feu à volonté pour les artilleurs
_group setSpeedMode  "FULL";

// Pilotes : FSM désactivé → ils ignorent les stimuli de combat et gardent le cap
{ 
    _x disableAI "FSM";
    _x allowDamage false;
} forEach [_pilot, _copilot];

// Artilleurs : invincibles + compétences de tir maximales
// NOTE : setSkill [string, number] — _x dans le forEach interne = nom de compétence (string)
{
    private _g = _x;    // variable locale pour éviter la collision avec le _x du forEach interne
    _g allowDamage  false;
    _g allowFleeing 0;
    _g setSkill 1;
    { _g setSkill [_x, 1.0]; } forEach [
        "aimingAccuracy", "aimingShake", "aimingSpeed",
        "spotDistance",   "spotTime",   "courage",   "commanding"
    ];
} forEach _gunners;

// ─── THREAD PRINCIPAL DE VOL ET D'ATTAQUE ─────────────────────────────────────
[_heli, _targetPos, _group, _crew, _spawnPos, _loiterHeight, _loiterRadius, _loiterDuration, _caller] spawn {
    params [
        "_heli", "_targetPos", "_group", "_crew",
        "_homeBase", "_loiterHeight", "_loiterRadius", "_loiterDuration", "_caller"
    ];

    private _dropPos = +_targetPos;

    // Marqueur CAS visible sur la carte de tous les joueurs
    private _markerName = format ["cas_mrk_%1", floor(random 10000)];
    private _marker = createMarker [_markerName, _dropPos];
    _marker setMarkerType  "mil_warning";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerText  "CAS";

    // Auto-suppression du marqueur après fin de mission + délai
    [_marker, _loiterDuration] spawn {
        params ["_m", "_d"];
        sleep (_d + 60);
        deleteMarker _m;
    };

    // ─── PHASE 1 : APPROCHE ────────────────────────────────────────────────────
    private _wp1 = _group addWaypoint [_dropPos, 0];
    _wp1 setWaypointType      "MOVE";
    _wp1 setWaypointBehaviour "CARELESS";
    _wp1 setWaypointSpeed     "FULL";
    _heli doMove _dropPos;

    private _approachTimeout = 0;
    waitUntil {
        sleep 1;
        _approachTimeout = _approachTimeout + 1;
        ((_heli distance2D _dropPos) < 300) || _approachTimeout > 180 || !alive _heli
    };

    if (!alive _heli) exitWith {
        missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
        deleteMarker _markerName;
    };

    deleteWaypoint [_group, 0];

    // ─── PHASE 2 : ORBITE D'ATTAQUE ────────────────────────────────────────────
    _heli flyInHeight    _loiterHeight;
    _heli flyInHeightASL [_loiterHeight, _loiterHeight, _loiterHeight];

    private _wp2 = _group addWaypoint [_dropPos, 0];
    _wp2 setWaypointType         "LOITER";
    _wp2 setWaypointLoiterType   "CIRCLE";
    _wp2 setWaypointLoiterRadius _loiterRadius;
    _wp2 setWaypointBehaviour    "CARELESS";
    _wp2 setWaypointCombatMode   "RED";
    _wp2 setWaypointSpeed        "LIMITED";
    _heli doMove _dropPos;

    private _endTime = time + _loiterDuration;

    // Boucle radar : révèle les unités OPFOR (east) à l'équipage toutes les 5s
    // → force l'acquisition de cible même avec disableAI "FSM" sur les pilotes
    while {time < _endTime && alive _heli} do {
        private _nearEnemies = _heli nearEntities [["Man", "Car", "Tank"], 600];
        {
            // Cibler uniquement les OPFOR (east), PAS les indépendants alliés (RACS)
            if (side _x == east) then {
                _group reveal [_x, 4];
            };
        } forEach _nearEnemies;
        sleep 5;
    };

    if (!alive _heli) exitWith {
        missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
        deleteMarker _markerName;
    };

    // ─── PHASE 3 : RETOUR BASE (RTB) ───────────────────────────────────────────
    while {(count (waypoints _group)) > 0} do {
        deleteWaypoint [_group, 0];
    };

    _heli flyInHeight    150;
    _heli flyInHeightASL [150, 150, 150];

    private _wpHome = _group addWaypoint [[0,0,0], 0];
    _wpHome setWaypointType      "MOVE";
    _wpHome setWaypointBehaviour "CARELESS";
    _wpHome setWaypointSpeed     "FULL";
    _heli doMove [0,0,0];

    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
    (localize "STR_TAG_Msg_CAS_RTB") remoteExec ["systemChat", _caller];

    // ─── PHASE 4 : NETTOYAGE HORS CHAMP ────────────────────────────────────────
    // Attendre que l'hélico soit hors de portée visuelle de tous les joueurs
    waitUntil {
        sleep 5;
        private _players  = allPlayers select { alive _x };
        private _tooClose = _players findIf { (_x distance2D _heli) < 2000 } > -1;
        (!_tooClose) || !alive _heli
    };

    { deleteVehicle _x } forEach _crew;
    deleteVehicle _heli;
    deleteGroup   _group;

    diag_log "[LL][HELI] Mission CAS terminée. Hélicoptère nettoyé.";
};
