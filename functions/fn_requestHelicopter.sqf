#include "..\macros.hpp"
/*
 * LL_fnc_requestHelicopter — v3 HELIFIX
 * Locality : Serveur uniquement
 *
 * Types de support :
 *   "CAS"          — appui aérien rapproché (comportement prouvé HELIFIX)
 *   "LIVRAISON"    — slingload caisse munitions dynamique
 *   "VEHICULE"     — slingload véhicule (usage unique)
 *   "DEBARQUEMENT" — atterrissage + escouade de renfort RACS
 *   "EMBARQUEMENT" — atterrissage + extraction joueurs → victoire
 *
 * Équipage : createVehicleCrew (RACS natif, independent)
 * Comportement CAS préservé : CARELESS + RED + disableAI FSM pilotes + radar reveal
 */

if (!isServer) exitWith {};

params [
    ["_supportType",  "CAS",   [""]],
    ["_targetPos",    [0,0,0], [[]]],
    ["_caller",       objNull, [objNull]],
    ["_actionTarget", objNull, [objNull]],
    ["_actionId",     -1,      [0]]
];

// ─── 0. GARDES ────────────────────────────────────────────────────────────────

// Cooldown CAS (5 minutes après RTB)
if (_supportType == "CAS" && { time < (missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) }) exitWith {
    private _remaining = ceil ((missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) - time);
    (format [localize "STR_TAG_Msg_CAS_Cooldown", _remaining]) remoteExec ["systemChat", _caller];
    diag_log format ["[LL][HELI] CAS refusé — cooldown %1s.", _remaining];
};

// VEHICULE usage unique
if (_supportType == "VEHICULE" && { missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false] }) exitWith {
    (localize "STR_TAG_Msg_Vehicle_Denied_Once") remoteExec ["systemChat", _caller];
};

// Soutien déjà actif
if (missionNamespace getVariable ["TAG_AirSupport_Active", false]) exitWith {
    private _msg = switch (_supportType) do {
        case "VEHICULE": { "STR_TAG_Msg_Vehicle_Denied" };
        case "CAS":      { "STR_TAG_Msg_CAS_Denied"     };
        default          { "STR_TAG_Msg_Ammo_Denied"    };
    };
    (localize _msg) remoteExec ["systemChat", _caller];
    diag_log format ["[LL][HELI] Refusé — TAG_AirSupport_Active actif. Type=%1", _supportType];
};

// ─── 1. VERROU + ACCUSÉ ───────────────────────────────────────────────────────

missionNamespace setVariable ["TAG_AirSupport_Active", true, true];

if (_supportType == "VEHICULE") then {
    missionNamespace setVariable ["TAG_VehicleSupport_Delivered", true, true];
    if (!isNull _actionTarget && { _actionId != -1 }) then {
        [_actionTarget, _actionId] remoteExec ["removeAction", 0, true];
    };
};

private _approveMsg = switch (_supportType) do {
    case "VEHICULE": { "STR_TAG_Msg_Vehicle_Approved" };
    case "CAS":      { "STR_TAG_Msg_CAS_Approved"     };
    default          { "STR_TAG_Msg_Ammo_Approved"    };
};
(localize _approveMsg) remoteExec ["systemChat", _caller];

// ─── 2. POSITION CIBLE ────────────────────────────────────────────────────────

if (count _targetPos < 2) then { _targetPos = getPosATL _caller; };
if (count _targetPos < 3) then { _targetPos set [2, 0]; };
_targetPos = _targetPos apply { if (isNil "_x") then {0} else {_x} };

private _targetPosFinal = +_targetPos;

// Héliport le plus proche pour les missions non-CAS
if (_supportType in ["LIVRAISON", "VEHICULE", "DEBARQUEMENT", "EMBARQUEMENT"]) then {
    private _heliports = (allMissionObjects "Any") select {
        vehicleVarName _x regexMatch "(?i)heliport_\d+"
    };
    diag_log format ["[LL][HELI] Héliports : %1", count _heliports];
    if (count _heliports > 0) then {
        private _refPos  = getPosATL _caller;
        private _nearest = _heliports # 0;
        private _minDist = _nearest distance2D _refPos;
        { private _d = _x distance2D _refPos; if (_d < _minDist) then { _minDist = _d; _nearest = _x; }; } forEach _heliports;
        _targetPosFinal  = getPosATL _nearest;
        diag_log format ["[LL][HELI] Héliport sélectionné à %1m", round _minDist];
    } else {
        _targetPosFinal  = getPosATL _caller;
        diag_log "[LL][HELI][WARN] Aucun héliport — fallback position joueur.";
    };
};

// CAS : centré sur le joueur
if (_supportType == "CAS") then { _targetPosFinal = getPosATL _caller; };

// ─── 3. SPAWN — COIN LE PLUS ÉLOIGNÉ DE PORTO ────────────────────────────────

private _flyHeight      = 150;
private _hoverHeight    = 15;
private _loiterHeight   = 60;
private _loiterRadius   = 250;
private _loiterDuration = 180;  // 3 minutes

private _corners = [
    [200,  200,  _flyHeight],
    [200,  4920, _flyHeight],
    [4920, 4920, _flyHeight],
    [4920, 200,  _flyHeight]
];
private _spawnPos = _corners # 0;
private _maxDist  = 0;
{ private _d = _x distance2D _targetPosFinal; if (_d > _maxDist) then { _maxDist = _d; _spawnPos = _x; }; } forEach _corners;
private _homeBase = +_spawnPos;

// ─── 4. CRÉATION HÉLICOPTÈRE ──────────────────────────────────────────────────

private _heliClass = "CUP_I_CH47F_RACS";
private _heli      = objNull;
private _attempts  = 0;

while { isNull _heli && { _attempts < 5 } } do {
    _attempts = _attempts + 1;
    _heli = createVehicle [_heliClass, _spawnPos, [], 0, "FLY"];
    if (!isNull _heli) then {
        _heli setPos      _spawnPos;
        _heli setDir      (_spawnPos getDir _targetPosFinal);
        _heli flyInHeight _flyHeight;
        _heli allowDamage false;
    } else { sleep 1; };
};

if (isNull _heli) exitWith {
    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
    private _errMsg = if (_supportType == "VEHICULE") then { "STR_TAG_Msg_Vehicle_Error" } else { "STR_TAG_Msg_Ammo_Error" };
    (localize _errMsg) remoteExec ["systemChat", _caller];
    diag_log "[LL][HELI][ERROR] Création CUP_I_CH47F_RACS échouée après 5 tentatives.";
};

missionNamespace setVariable ["LL_missionHelicopter", _heli, true];
diag_log format ["[LL][HELI] Hélicoptère créé. Type=%1 Pos=%2", _supportType, _spawnPos];

// ─── 5. ÉQUIPAGE RACS (INDEPENDENT) ──────────────────────────────────────────
// createVehicleCrew garantit l'équipage RACS natif sans hardcoder les classnames.
// COMPORTEMENT PROUVÉ — NE PAS MODIFIER.

createVehicleCrew _heli;
sleep 0.3;
_heli setVehicleAmmo 1;

private _crew    = crew _heli;
private _group   = group (_crew # 0);
private _pilot   = driver _heli;
private _copilot = _heli turretUnit [0];
private _gunners = _crew select { _x != _pilot && { _x != _copilot } };

diag_log format ["[LL][HELI] Équipage : %1 | pilote=%2 | copilote=%3 | artilleurs=%4",
    count _crew, _pilot, _copilot, count _gunners];

// Groupe : CARELESS = pilote suit ses WP sans dévier ; RED = artilleurs tirent à vue
_group setBehaviour  "CARELESS";
_group setCombatMode "RED";
_group setSpeedMode  "FULL";

// Pilotes : FSM désactivé → ignorent les stimuli de combat, garde le cap
{ _x disableAI "FSM"; _x allowDamage false; } forEach [_pilot, _copilot];

// Artilleurs : skill max + invincibles
// IMPORTANT : private _g = _x évite la collision _x dans le forEach imbriqué (bug setSkill corrigé)
{
    private _g = _x;
    _g allowDamage  false;
    _g allowFleeing 0;
    _g setSkill 1;
    { _g setSkill [_x, 1.0]; } forEach ["aimingAccuracy","aimingShake","aimingSpeed","spotDistance","spotTime","courage","commanding"];
} forEach _gunners;

// ─── 6. THREAD DE VOL ET MISSION ─────────────────────────────────────────────

[_heli, _targetPosFinal, _group, _crew, _gunners, _homeBase,
 _supportType, _caller, _flyHeight, _hoverHeight,
 _loiterHeight, _loiterRadius, _loiterDuration] spawn {

    params [
        "_heli", "_dropPos", "_group", "_crew", "_gunners", "_homeBase",
        "_supportType", "_caller", "_flyHeight", "_hoverHeight",
        "_loiterHeight", "_loiterRadius", "_loiterDuration"
    ];

    private _isSlingload      = _supportType in ["LIVRAISON", "VEHICULE"];
    private _cargo            = objNull;
    private _originalMass     = 0;
    private _victoryTriggered = false;
    private _side             = side _group;

    // Marqueur carte
    private _markerName = format ["heli_%1_%2", _supportType, floor(random 100000)];
    private _markerData = switch (_supportType) do {
        case "LIVRAISON":    { ["mil_box",    "ColorBlue",   localize "STR_TAG_Marker_Heli_Ammo"]    };
        case "VEHICULE":     { ["mil_box",    "ColorBlue",   localize "STR_TAG_Marker_Heli_Vehicle"] };
        case "DEBARQUEMENT": { ["mil_end",    "ColorGreen",  localize "STR_TAG_Marker_Heli_Debark"]  };
        case "EMBARQUEMENT": { ["mil_pickup", "ColorYellow", localize "STR_TAG_Marker_Heli_Extract"] };
        case "CAS":          { ["mil_warning","ColorRed",    localize "STR_TAG_Marker_Heli_CAS"]     };
        default              { ["mil_dot",    "ColorBlack",  ""]                                     };
    };
    private _mrk = createMarker [_markerName, _dropPos];
    _mrk setMarkerType  (_markerData # 0);
    _mrk setMarkerColor (_markerData # 1);
    _mrk setMarkerText  (_markerData # 2);

    // ─── PHASE 1 : APPROCHE ───────────────────────────────────────────────────

    private _wp1 = _group addWaypoint [_dropPos, 0];
    _wp1 setWaypointType       "MOVE";
    _wp1 setWaypointBehaviour  "CARELESS";
    _wp1 setWaypointCombatMode "RED";
    _wp1 setWaypointSpeed      "FULL";
    _heli doMove _dropPos;

    private _approachTimer = 0;
    waitUntil {
        sleep 1; _approachTimer = _approachTimer + 1;
        (_heli distance2D _dropPos < 200) || _approachTimer > 180 || !alive _heli
    };

    if (!alive _heli) exitWith {
        deleteMarker _markerName;
        missionNamespace setVariable ["TAG_AirSupport_Active",  false,   true];
        missionNamespace setVariable ["LL_missionHelicopter",   objNull, true];
    };

    deleteWaypoint [_group, 0];

    // ─── PHASE 2 : EXÉCUTION SELON TYPE ──────────────────────────────────────

    // ═══ A. SLINGLOAD (LIVRAISON / VEHICULE) ═════════════════════════════════
    if (_isSlingload) then {
        if (_supportType == "VEHICULE") then { _hoverHeight = 10; };

        private _cargoClass = "B_supplyCrate_F";
        if (_supportType == "VEHICULE") then {
            _cargoClass = if (!isNil "vehicule_team" && { !isNull vehicule_team }) then {
                typeOf vehicule_team
            } else { "CUP_B_nM1025_SOV_M2_USMC_DES" };
        };

        _cargo = createVehicle [_cargoClass, [0,0,0], [], 0, "NONE"];
        _cargo setPos (_heli modelToWorld [0,0,-15]);
        _cargo allowDamage false;
        _originalMass = getMass _cargo;
        _cargo setMass (if (_supportType == "LIVRAISON") then {500} else {800});
        _heli setSlingLoad _cargo;

        // Remplissage dynamique caisse munitions
        if (_supportType == "LIVRAISON") then {
            clearWeaponCargoGlobal   _cargo;
            clearMagazineCargoGlobal _cargo;
            clearItemCargoGlobal     _cargo;
            clearBackpackCargoGlobal _cargo;

            private _allWeapons = []; private _allMags = []; private _allItems = []; private _allPacks = [];
            {
                { if (_x != "") then {
                    _allWeapons pushBackUnique _x;
                    private _mags = getArray (configFile >> "CfgWeapons" >> _x >> "magazines");
                    if (count _mags > 0) then { _allMags pushBackUnique (_mags # 0); };
                    if (count _mags > 1) then { _allMags pushBackUnique (_mags # 1); };
                }; } forEach [primaryWeapon _x, secondaryWeapon _x, handgunWeapon _x];
                { _allMags  pushBackUnique _x; } forEach (magazines _x);
                { if (_x in ["ItemGPS","ItemDetector","ToolKit","MineDetector","B_UavTerminal"]) then {
                    _allItems pushBackUnique _x;
                }; } forEach (items _x + assignedItems _x);
                if (backpack _x != "") then { _allPacks pushBackUnique (backpack _x); };
            } forEach (allUnits select { alive _x && { side (group _x) == _side } });

            { _cargo addWeaponCargoGlobal [_x, 2]; } forEach _allWeapons;
            {
                private _qty = if ((toLower _x find "grenade") != -1 || (toLower _x find "shell") != -1 || (toLower _x find "smoke") != -1) then {10} else {15};
                _cargo addMagazineCargoGlobal [_x, _qty];
            } forEach _allMags;
            { _cargo addBackpackCargoGlobal [_x, 2]; } forEach _allPacks;
            { _cargo addItemCargoGlobal     [_x, 2]; } forEach _allItems;
            _cargo addItemCargoGlobal     ["FirstAidKit",     20];
            _cargo addMagazineCargoGlobal ["SmokeShell",      10];
            _cargo addMagazineCargoGlobal ["SmokeShellGreen", 10];
        };

        // Descente slingload
        _heli flyInHeight    _hoverHeight;
        _heli flyInHeightASL [_hoverHeight, _hoverHeight, _hoverHeight];

        private _wp2 = _group addWaypoint [_dropPos, 0];
        _wp2 setWaypointType      "MOVE";
        _wp2 setWaypointBehaviour "CARELESS";
        _wp2 setWaypointCombatMode "RED";
        _wp2 setWaypointSpeed     "FULL";
        _heli doMove _dropPos;

        // Approche précise sur point de largage
        private _posTimer = 0;
        waitUntil {
            sleep 0.25; _posTimer = _posTimer + 0.25;
            private _d = _heli distance2D _dropPos;
            if (_d < 25) then {
                private _hp = getPosVisual _heli;
                private _px = ((_dropPos # 0) - (_hp # 0)) * 0.4;
                private _py = ((_dropPos # 1) - (_hp # 1)) * 0.4;
                _heli setVelocity [((_px min 5) max -5), ((_py min 5) max -5), velocity _heli # 2];
            };
            (_d < 2) || _posTimer > 50 || !alive _heli
        };

        if (!alive _heli) exitWith {
            if (!isNull _cargo) then { deleteVehicle _cargo; };
            deleteMarker _markerName;
            missionNamespace setVariable ["TAG_AirSupport_Active",  false,   true];
            missionNamespace setVariable ["LL_missionHelicopter",   objNull, true];
        };

        _heli setVelocity [0,0,0];
        _heli flyInHeight _hoverHeight;

        // Descente progressive du colis
        private _dropTimer = 0;
        private _minCargoH = if (_supportType == "LIVRAISON") then {5} else {4};
        waitUntil {
            sleep 0.25; _dropTimer = _dropTimer + 0.25;
            private _newH = (_hoverHeight - _dropTimer) max _minCargoH;
            _heli flyInHeight    _newH;
            _heli flyInHeightASL [_newH, _newH, _newH];
            private _hp = getPosVisual _heli;
            private _px = ((_dropPos # 0) - (_hp # 0)) * 0.4;
            private _py = ((_dropPos # 1) - (_hp # 1)) * 0.4;
            _heli setVelocity [((_px min 4) max -4), ((_py min 4) max -4), velocity _heli # 2];
            (getPosATL _cargo # 2 < 3) || _dropTimer > 40 || !alive _heli || !alive _cargo
        };

        if (!alive _heli || !alive _cargo) exitWith {
            if (!isNull _cargo && { alive _cargo }) then { deleteVehicle _cargo; };
            deleteMarker _markerName;
            missionNamespace setVariable ["TAG_AirSupport_Active",  false,   true];
            missionNamespace setVariable ["LL_missionHelicopter",   objNull, true];
        };

        sleep 1;
        { ropeDestroy _x; } forEach (ropes _heli);
        _heli setSlingLoad objNull;
        sleep 1;
        _cargo setVelocity [0,0,0];
        _cargo setVectorUp [0,0,1];
        _cargo setMass     _originalMass;
        _cargo allowDamage true;

        if (_supportType == "LIVRAISON") then {
            (localize "STR_TAG_Msg_Ammo_Dropped") remoteExec ["systemChat", _caller];
            [_cargo] spawn {
                params ["_crate"];
                if (isNull _crate) exitWith {};
                private _smokeG = createVehicle ["SmokeShellGreen", getPos _crate, [], 0, "CAN_COLLIDE"];
                private _dead = false;
                for "_i" from 1 to 59 do { sleep 10; if (!alive _crate) exitWith { _dead = true; }; };
                if (_dead) exitWith { if (!isNull _smokeG) then { deleteVehicle _smokeG; }; };
                if (alive _crate) then {
                    private _smks = [];
                    for "_d" from 0 to 360 step 45 do { _smks pushBack (createVehicle ["SmokeShell", (_crate getPos [2, _d]), [], 0, "CAN_COLLIDE"]); };
                    sleep 10;
                    if (alive _crate)     then { deleteVehicle _crate; };
                    if (!isNull _smokeG)  then { deleteVehicle _smokeG; };
                    sleep 120;
                    { if (!isNull _x) then { deleteVehicle _x; }; } forEach _smks;
                };
            };
        } else {
            (localize "STR_TAG_Msg_Vehicle_Dropped") remoteExec ["systemChat", _caller];
            missionNamespace setVariable ["vehicule_team", _cargo, true];
        };
    };

    // ═══ B. CAS ══════════════════════════════════════════════════════════════
    // COMPORTEMENT PROUVÉ — NE PAS MODIFIER
    if (_supportType == "CAS") then {
        _heli flyInHeight    _loiterHeight;
        _heli flyInHeightASL [_loiterHeight, _loiterHeight, _loiterHeight];

        private _wpCAS = _group addWaypoint [_dropPos, 0];
        _wpCAS setWaypointType         "LOITER";
        _wpCAS setWaypointLoiterType   "CIRCLE";
        _wpCAS setWaypointLoiterRadius _loiterRadius;
        _wpCAS setWaypointBehaviour    "CARELESS";
        _wpCAS setWaypointCombatMode   "RED";
        _wpCAS setWaypointSpeed        "LIMITED";
        _heli doMove _dropPos;

        // Attente entrée en zone loiter
        waitUntil { sleep 1; !alive _heli || (_heli distance2D _dropPos < (_loiterRadius + 150)); };

        // Boucle radar : révèle les OPFOR (east) toutes les 5s — force l'engagement
        private _endTime    = time + _loiterDuration;
        private _lastReveal = 0;
        while { time < _endTime && { alive _heli } } do {
            sleep 1;
            if (time - _lastReveal >= 5) then {
                _lastReveal = time;
                {
                    if (side _x == east) then { _group reveal [_x, 4]; };
                } forEach (_heli nearEntities [["Man", "Car", "Tank"], 800]);
            };
        };

        while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    };

    // ═══ C. DÉBARQUEMENT / EMBARQUEMENT ══════════════════════════════════════
    if (_supportType in ["DEBARQUEMENT", "EMBARQUEMENT"]) then {
        _heli flyInHeight 0;
        _heli land (if (_supportType == "DEBARQUEMENT") then {"GET OUT"} else {"GET IN"});

        private _landTimer = 0;
        waitUntil {
            sleep 1; _landTimer = _landTimer + 1;
            !alive _heli || isTouchingGround _heli ||
            (velocity _heli # 2 == 0 && { getPosVisual _heli # 2 < 2 }) || _landTimer > 60
        };

        if (!alive _heli) exitWith {
            deleteMarker _markerName;
            missionNamespace setVariable ["TAG_AirSupport_Active",  false,   true];
            missionNamespace setVariable ["LL_missionHelicopter",   objNull, true];
        };

        // ── DÉBARQUEMENT — spawn escouade RACS ────────────────────────────────
        if (_supportType == "DEBARQUEMENT") then {
            private _infGroup  = createGroup [_side, true];
            private _unitTypes = ["CUP_I_RACS_Soldier_SL","CUP_I_RACS_Soldier_Medic",
                                  "CUP_I_RACS_Soldier_MG","CUP_I_RACS_Soldier_LAT","CUP_I_RACS_Soldier"];
            private _reinforcements = [];

            private _vests   = ["CUP_V_JPC_medical_coy","CUP_V_JPC_tl_coy","CUP_V_JPC_weapons_coy",
                                "CUP_V_JPC_communicationsbelt_coy","CUP_V_JPC_Fastbelt_coy",
                                "CUP_V_JPC_lightbelt_coy","CUP_V_JPC_medicalbelt_coy",
                                "CUP_V_JPC_tlbelt_coy","CUP_V_JPC_weaponsbelt_coy"];
            private _helmets = ["CUP_H_OpsCore_Tan_SF","CUP_H_OpsCore_Tan","CUP_H_OpsCore_Tan_NohS",
                                "CUP_H_OpsCore_Grey_SF","CUP_H_OpsCore_Grey","CUP_H_OpsCore_Grey_NohS"];
            private _backpacks = ["CUP_B_AssaultPack_Coyote","B_assaultPack_cbr","B_Kitbag_cbr"];
            private _uniforms  = ["CUP_U_B_USMC_MCCUU_des_gloves","CUP_U_B_USMC_MCCUU_des_roll_2",
                                  "CUP_U_B_USMC_MCCUU_des_roll_2_gloves","CUP_U_B_USMC_MCCUU_des_roll_pads",
                                  "CUP_U_B_USMC_MCCUU_des_pads","CUP_U_B_USMC_MCCUU_des_pads_gloves",
                                  "CUP_U_B_USMC_MCCUU_des_roll","CUP_U_B_USMC_MCCUU_des_roll_gloves",
                                  "CUP_U_B_USMC_MCCUU_des"];
            private _cagoules  = ["CUP_G_Tan_Scarf_GPS","CUP_G_TK_RoundGlasses_blk","CUP_G_Oakleys_Drk",
                                  "CUP_G_Scarf_Face_Tan","G_Aviator","CUP_G_ESS_KHK_Facewrap_Tan","G_Bandana_khk"];

            private _fnAddMags = {
                params ["_u","_w","_n"];
                if (_w == "") exitWith {};
                private _mags = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
                if (count _mags > 0) then { for "_i" from 1 to _n do { _u addItem (_mags # 0); }; };
            };

            {
                private _unitType = _x;
                private _unit     = _infGroup createUnit [_unitType, _dropPos, [], 0, "NONE"];

                private _vestPool = switch (true) do {
                    case (_unitType == "CUP_I_RACS_Soldier_Medic"): { private _p = _vests select { _x find "medical" != -1 }; if (count _p > 0) then {_p} else {_vests} };
                    case (_unitType == "CUP_I_RACS_Soldier_SL"):    { private _p = _vests select { _x find "_tl" != -1 }; if (count _p > 0) then {_p} else {_vests} };
                    default { _vests };
                };
                removeUniform _unit; removeVest _unit; removeBackpack _unit; removeHeadgear _unit; removeGoggles _unit;
                _unit forceAddUniform (selectRandom _uniforms);
                [_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
                _unit addVest     (selectRandom _vestPool);
                _unit addBackpack (selectRandom _backpacks);
                _unit addHeadgear (selectRandom _helmets);
                _unit addGoggles  (selectRandom _cagoules);
                _unit linkItem "NVGogglesB_blk_F";
                if (binocular _unit != "") then { _unit removeWeapon (binocular _unit); };
                _unit addWeapon "CUP_LRTV";
                [_unit, primaryWeapon   _unit, 5] call _fnAddMags;
                [_unit, handgunWeapon   _unit, 3] call _fnAddMags;
                [_unit, secondaryWeapon _unit, 2] call _fnAddMags;
                for "_i" from 1 to 3 do { _unit addItem "FirstAidKit"; };
                for "_i" from 1 to 3 do { _unit addItem "CUP_HandGrenade_M67"; };
                for "_i" from 1 to 3 do { _unit addItem "SmokeShell"; };
                if (_unitType == "CUP_I_RACS_Soldier_Medic") then { _unit addItemToBackpack "Medikit"; };

                // Identité depuis pool global LL_g_allNamesTyped
                private _allNamesTyped = missionNamespace getVariable ["LL_g_allNamesTyped", []];
                if (count _allNamesTyped == 0) then {
                    _allNamesTyped = [
                        [["Mehdi Benali","Mehdi","Benali"],"Arab"],
                        [["Mustafa Demir","Mustafa","Demir"],"Turkish"],
                        [["Moussa Diallo","Moussa","Diallo"],"African"],
                        [["Budi Santoso","Budi","Santoso"],"Indonesian"]
                    ];
                };
                private _usedNames = missionNamespace getVariable ["LL_g_usedPlayerNames", []];
                private _available = _allNamesTyped select { !((_x # 0 # 0) in _usedNames) };
                if (count _available == 0) then { _usedNames = []; _available = _allNamesTyped; };
                private _entry     = selectRandom _available;
                private _nameData  = _entry # 0;
                private _faceType  = _entry # 1;
                _usedNames pushBackUnique (_nameData # 0);
                missionNamespace setVariable ["LL_g_usedPlayerNames", _usedNames, true];

                private _faces = switch (_faceType) do {
                    case "Turkish"; case "Arab": {
                        ["PersianHead_A3_01","PersianHead_A3_02","PersianHead_A3_03",
                         "GreekHead_A3_01","GreekHead_A3_02","GreekHead_A3_03",
                         "GreekHead_A3_04","GreekHead_A3_05","GreekHead_A3_06"]
                    };
                    case "African":    { ["AfricanHead_01","AfricanHead_02","AfricanHead_03"] };
                    case "Indonesian": { ["AsianHead_A3_01","AsianHead_A3_02","TanoanHead_A3_01","TanoanHead_A3_02"] };
                    default            { ["WhiteHead_01","WhiteHead_02","WhiteHead_03","WhiteHead_04","WhiteHead_05","WhiteHead_06"] };
                };
                private _face    = selectRandom _faces;
                private _speaker = selectRandom ["Male01ENG","Male02ENG","Male03ENG","Male01GRE","Male02GRE","Male03GRE"];
                private _pitch   = 0.85 + random 0.15;
                [_unit, _nameData, _face, _speaker, _pitch, ""] remoteExec ["LL_fnc_applyIdentity", 0, _unit];
                _unit setVariable ["LL_s_identity",  [_nameData, _faceType, _face, _speaker, _pitch, ""], true];
                _unit setVariable ["LL_IdentitySet", true, true];
                _unit setUnitRank (switch (_unitType) do {
                    case "CUP_I_RACS_Soldier_SL":    { "SERGEANT" };
                    case "CUP_I_RACS_Soldier_Medic": { "CORPORAL" };
                    default                          { "PRIVATE"  };
                });
                _unit moveInCargo _heli;
                _reinforcements pushBack _unit;
            } forEach _unitTypes;

            sleep 1;
            { unassignVehicle _x; moveOut _x; sleep 0.5; } forEach _reinforcements;

            private _unloadTimer = 0;
            waitUntil {
                sleep 1; _unloadTimer = _unloadTimer + 1;
                !alive _heli || ({ _x in _heli } count _reinforcements == 0) || _unloadTimer > 30
            };

            private _playerGroup = if (!isNull _caller) then { group _caller } else { grpNull };
            if (!isNull _playerGroup) then {
                _reinforcements joinSilent _playerGroup;
                (localize "STR_LL_Heli_Msg_Squad_Joined") remoteExec ["systemChat", 0];
            } else {
                [_infGroup, _dropPos, 150] call BIS_fnc_taskPatrol;
                (localize "STR_LL_Heli_Msg_Patrol_Started") remoteExec ["systemChat", 0];
            };
        };

        // ── EMBARQUEMENT — extraction joueurs ──────────────────────────────────
        if (_supportType == "EMBARQUEMENT") then {
            (localize "STR_LL_Heli_Msg_Landed_Extract") remoteExec ["systemChat", 0];

            private _timeout = time + 600;
            private _shouldLeave = false;
            waitUntil {
                sleep 2;
                private _allHumans = allPlayers select { alive _x };
                private _inHeli    = crew _heli select { _x in _allHumans };
                if (count _inHeli > 0) then {
                    if (count _inHeli >= count _allHumans) then { _shouldLeave = true; };
                } else {
                    if (time > _timeout) then { _shouldLeave = true; };
                };
                !alive _heli || _shouldLeave
            };

            (localize "STR_LL_Heli_Msg_Departing") remoteExec ["systemChat", 0];

            if (alive _heli) then {
                private _playersInHeli = crew _heli select { isPlayer _x && { alive _x } };
                if (count _playersInHeli > 0) then {
                    _victoryTriggered = true;
                    deleteMarker _markerName;
                    _heli flyInHeight _flyHeight;
                    private _wpVic = _group addWaypoint [_homeBase, 0];
                    _wpVic setWaypointType      "MOVE";
                    _wpVic setWaypointBehaviour "CARELESS";
                    _wpVic setWaypointCombatMode "RED";
                    _wpVic setWaypointSpeed     "FULL";
                    _heli doMove _homeBase;
                    { _x hideObjectGlobal true; } forEach (crew _heli select { !(_x in _crew) });
                    _heli lock 2;
                    sleep 25;
                    if (alive _heli) then { ["MissionSuccess", true, true] remoteExec ["BIS_fnc_endMission", 0]; };
                };
            };
        };
    };

    // ─── PHASE 3 : RETOUR BASE ET NETTOYAGE ──────────────────────────────────

    if (!_victoryTriggered) then {
        deleteMarker _markerName;
        if (_supportType == "CAS") then {
            (localize "STR_TAG_Msg_CAS_RTB") remoteExec ["systemChat", _caller];
        };

        sleep 2;
        while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };

        _heli flyInHeight _flyHeight;
        private _wpRTB = _group addWaypoint [_homeBase, 0];
        _wpRTB setWaypointType      "MOVE";
        _wpRTB setWaypointBehaviour "CARELESS";
        _wpRTB setWaypointCombatMode "RED";
        _wpRTB setWaypointSpeed     "FULL";
        _group setCurrentWaypoint _wpRTB;
        _heli doMove _homeBase;

        // Libère le verrou immédiatement — le joueur peut faire une nouvelle demande
        missionNamespace setVariable ["TAG_AirSupport_Active", false, true];

        private _rtbStart = time;
        waitUntil {
            sleep 5;
            (_heli distance2D _homeBase < 200) || !alive _heli || (time - _rtbStart > 180)
        };

        if (alive _heli) then {
            if ({ isPlayer _x } count crew _heli > 0) then {
                ["MissionSuccess", true, true] remoteExec ["BIS_fnc_endMission", 0];
            } else {
                { deleteVehicle _x; } forEach _crew;
                deleteVehicle _heli;
                deleteGroup   _group;
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
    };

    missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
    diag_log format ["[LL][HELI] Mission %1 terminée.", _supportType];
};
