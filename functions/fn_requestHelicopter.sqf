#include "..\macros.hpp"

/*
 * LL_fnc_requestHelicopter  — v2 (réécriture PLANHELI)
 *
 * Description:
 *   Fonction unique côté serveur de gestion du support hélicoptère (CUP_I_CH47F_RACS).
 *   Garantit qu'un seul hélicoptère de support est actif (verrou TAG_AirSupport_Active).
 *   La livraison de véhicule ne peut être demandée qu'une seule fois.
 *   L'hélicoptère apparaît au coin de Porto le plus éloigné de la cible, exécute sa
 *   mission, puis retourne à son point de spawn et se despawn proprement.
 *
 * Types de support :
 *   "LIVRAISON"    — slingload caisse munitions dynamique
 *   "VEHICULE"     — slingload véhicule de remplacement (livraison unique)
 *   "DEBARQUEMENT" — atterrissage + débarquement escouade de renfort
 *   "EMBARQUEMENT" — atterrissage + extraction joueurs (déclenche fin de mission)
 *   "CAS"          — appui aérien rapproché : loiter 3min + tir sur ennemis
 *
 * Arguments:
 *   0: <STRING>  Type de support
 *   1: <ARRAY>   Position cible [X, Y, Z]
 *   2: <OBJECT>  Le joueur ayant effectué la demande
 *   3: <OBJECT>  L'objet cible de l'AddAction (pour suppression)
 *   4: <NUMBER>  L'ID de l'AddAction (pour suppression)
 *
 * Locality: Serveur uniquement
 *
 * FIXES v2 (PLANHELI) :
 *   [FIX-1] disableAI "FSM" SUPPRIMÉ des pilotes — cassait le FSM de groupe entier et
 *           empêchait les ordres de tir de remonter aux artilleurs.
 *   [FIX-2] forceWeaponFire corrigé — appelé sur le VÉHICULE (_heli), muzzle = nom arme.
 *   [FIX-3] fireAtTarget corrigé — syntaxe array fixée (#0 au lieu de param[0,objNull]).
 *   [FIX-4] selectWeaponTurret remplace selectWeapon pour les tourelles de véhicule.
 *   [OPT-1] Recherche héliports O(n) via allMissionObjects + regexMatch (anti boucle ×1100).
 *   [OPT-2] Pool identités DEBARQUEMENT depuis LL_g_allNamesTyped (global existant).
 *   [OPT-3] Sub-thread combat : intervalle 3s, logique de tir clarifiée et corrigée.
 */

if (!isServer) exitWith {};

params [
    ["_supportType",  "LIVRAISON", [""]],
    ["_targetPos",    [0,0,0],     [[]]],
    ["_caller",       objNull,     [objNull]],
    ["_actionTarget", objNull,     [objNull]],
    ["_actionId",     -1,          [0]]
];

// ─────────────────────────────────────────────────────────────────────────────
// 0. GUARD CLAUSES
// ─────────────────────────────────────────────────────────────────────────────

// Cooldown CAS : 5 minutes après le départ du dernier CAS
if (_supportType == "CAS" && { time < (missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) }) exitWith {
    private _remaining = ceil ((missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) - time);
    (format [localize "STR_TAG_Msg_CAS_Cooldown", _remaining]) remoteExec ["systemChat", _caller];
    diag_log format ["[LL] requestHelicopter: CAS refusé — cooldown %1s restants.", _remaining];
};

// Livraison véhicule unique : déjà livrée
if (_supportType == "VEHICULE" && { missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false] }) exitWith {
    (localize "STR_TAG_Msg_Vehicle_Denied_Once") remoteExec ["systemChat", _caller];
    diag_log "[LL] requestHelicopter: VEHICULE refusé — déjà livré.";
};

// Soutien aérien déjà en cours
if (missionNamespace getVariable ["TAG_AirSupport_Active", false]) exitWith {
    private _msg = switch (_supportType) do {
        case "VEHICULE": { "STR_TAG_Msg_Vehicle_Denied" };
        case "CAS":      { "STR_TAG_Msg_CAS_Denied"     };
        default          { "STR_TAG_Msg_Ammo_Denied"    };
    };
    (localize _msg) remoteExec ["systemChat", _caller];
    diag_log "[LL] requestHelicopter: Refusé — TAG_AirSupport_Active déjà actif.";
};

// ─────────────────────────────────────────────────────────────────────────────
// 1. VERROU + ACCUSÉ DE RÉCEPTION
// ─────────────────────────────────────────────────────────────────────────────

missionNamespace setVariable ["TAG_AirSupport_Active", true, true];

// Livraison véhicule : verrouillage définitif + suppression de l'AddAction associée
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

// ─────────────────────────────────────────────────────────────────────────────
// 2. POSITION CIBLE FINALE — HÉLIPORT LE PLUS PROCHE OU POSITION JOUEUR
// ─────────────────────────────────────────────────────────────────────────────

// Fallback sur position joueur si targetPos invalide
if (count _targetPos < 2) then { _targetPos = getPosATL _caller; };
if (count _targetPos < 3) then { _targetPos set [2, 0]; };

private _targetPosFinal = +_targetPos;

// [OPT-1] Recherche O(n) via allMissionObjects + regexMatch
// Remplace la boucle inefficace de 1100 itérations (for 0 to 999 + for 0 to 99)
private _heliports = (allMissionObjects "Any") select {
    vehicleVarName _x regexMatch "(?i)heliport_\d+"
};
diag_log format ["[LL][HELI] Héliports détectés : %1", count _heliports];

if (_supportType in ["LIVRAISON", "VEHICULE", "DEBARQUEMENT", "EMBARQUEMENT"]) then {
    if (count _heliports > 0) then {
        private _refPos   = getPosATL _caller;
        private _nearest  = _heliports # 0;
        private _minDist  = _nearest distance2D _refPos;
        {
            private _d = _x distance2D _refPos;
            if (_d < _minDist) then { _minDist = _d; _nearest = _x; };
        } forEach _heliports;
        _targetPosFinal = getPosATL _nearest;
        diag_log format ["[LL][HELI] Héliport sélectionné : %1 à %2m (pos: %3)", vehicleVarName _nearest, round _minDist, _targetPosFinal];
    } else {
        _targetPosFinal = getPosATL _caller;
        diag_log "[LL][WARNING][HELI] Aucun héliport trouvé — fallback position joueur.";
    };
};

if (_supportType == "CAS") then {
    _targetPosFinal = getPosATL _caller;
    diag_log format ["[LL][HELI] CAS — orbite centrée sur le joueur : %1", _targetPosFinal];
};

// ─────────────────────────────────────────────────────────────────────────────
// 3. SÉLECTION DU COIN DE SPAWN — LE PLUS ÉLOIGNÉ DE LA CIBLE
// Porto : 5120m × 5120m. Coins à 200m du bord = au-dessus de l'eau.
// ─────────────────────────────────────────────────────────────────────────────

private _flyHeight      = 150;
private _hoverHeight    = 15;   // slingload: 15m (LIVRAISON) ou 10m (VEHICULE)
private _loiterHeight   = 60;   // CAS
private _loiterRadius   = 250;  // CAS
private _loiterDuration = 120;  // CAS — durée de loiter avant window combat

private _corners = [
    [200,  200,  _flyHeight],   // Sud-Ouest
    [200,  4920, _flyHeight],   // Nord-Ouest
    [4920, 4920, _flyHeight],   // Nord-Est
    [4920, 200,  _flyHeight]    // Sud-Est
];

private _spawnPos = _corners # 0;
private _maxDist  = 0;
{
    private _d = _x distance2D _targetPosFinal;
    if (_d > _maxDist) then { _maxDist = _d; _spawnPos = _x; };
} forEach _corners;

private _homeBase = +_spawnPos;

// ─────────────────────────────────────────────────────────────────────────────
// 4. CRÉATION DU VÉHICULE
// ─────────────────────────────────────────────────────────────────────────────

private _heliClass    = "CUP_I_CH47F_RACS";
private _pilotClass   = "CUP_I_RACS_Pilot";
private _soldierClass = "CUP_I_RACS_Soldier";

private _side = if (!isNull _caller) then { side (group _caller) } else { independent };
if (_side == west) then {
    _pilotClass   = "B_Helipilot_F";
    _soldierClass = "B_Soldier_F";
};

private _heli     = objNull;
private _attempts = 0;
while { isNull _heli && { _attempts < 5 } } do {
    _attempts = _attempts + 1;
    _heli = createVehicle [_heliClass, _spawnPos, [], 0, "FLY"];
    if (!isNull _heli) then {
        _heli setPos    _spawnPos;
        _heli setDir    (_spawnPos getDir _targetPosFinal);
        _heli flyInHeight _flyHeight;
        _heli allowDamage false;
    } else {
        sleep 1;
    };
};

if (isNull _heli) exitWith {
    missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
    private _errMsg = if (_supportType == "VEHICULE") then { "STR_TAG_Msg_Vehicle_Error" } else { "STR_TAG_Msg_Ammo_Error" };
    (localize _errMsg) remoteExec ["systemChat", _caller];
    diag_log "[LL][ERROR][HELI] Création du véhicule échouée.";
};

missionNamespace setVariable ["LL_missionHelicopter", _heli, true];

// ─────────────────────────────────────────────────────────────────────────────
// 5. CRÉATION DE L'ÉQUIPAGE — GROUPE UNIQUE
// ─────────────────────────────────────────────────────────────────────────────

private _group = createGroup [_side, true];
private _crew  = [];

// 1. Pilote (Index 0)
private _pilot = _group createUnit [_pilotClass, [0,0,0], [], 0, "NONE"];
_pilot moveInAny _heli;
_crew pushBack _pilot;

// 2. Copilote (Index 1)
private _copilot = _group createUnit [_pilotClass, [0,0,0], [], 0, "NONE"];
_copilot moveInAny _heli;
_crew pushBack _copilot;

// 3. Les 4 passagers test demandés
for "_i" from 1 to 4 do {
    private _crewMember = _group createUnit [_soldierClass, [0,0,0], [], 0, "NONE"];
    _crewMember moveInAny _heli;
    _crew pushBack _crewMember;
};

// Attribution des IA (Les pilotes conduisent, les autres tirent)
{
    private _u = _x;
    
    _u enableAI "FSM";
    _u enableAI "MOVE";
    _u allowFleeing  0;
    _u allowDamage   false;
    
    // Pilote/copilot
    if (_forEachIndex < 2) then {
        _u disableAI "TARGET";
        _u disableAI "AUTOTARGET";
        _u disableAI "AUTOCOMBAT";
        _u disableAI "SUPPRESSION";
    } else {
        // Tireurs
        _u setSkill 1;
        { _u setSkill [_x, 1.0]; } forEach ["aimingAccuracy","aimingShake","aimingSpeed","spotDistance","spotTime","courage","commanding"];
        _u enableAI "TARGET";
        _u enableAI "AUTOTARGET";
        _u enableAI "AUTOCOMBAT";
        _u enableAI "SUPPRESSION";
    };
} forEach _crew;

sleep 0.3;
_heli setVehicleAmmo 1;

// Configuration des comportements de groupes
_group setBehaviour "COMBAT";
_group setCombatMode "RED";
_group setSpeedMode "FULL";

_heli setCombatMode "RED"; 

// Destination courante stockée sur l'heli pour le sub-thread combat
_heli setVariable ["TAG_Heli_CurrentDestination", _targetPosFinal, true];

// ─────────────────────────────────────────────────────────────────────────────
// 6. THREAD DE VOL PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
[_heli, _targetPosFinal, _group, _crew, _homeBase,
 _supportType, _caller, _flyHeight, _hoverHeight, _side,
 _pilotClass, _soldierClass, _loiterHeight, _loiterRadius, _loiterDuration] spawn {

    params [
        "_heli", "_dropPos", "_group", "_crew", "_homeBase",
        "_supportType", "_caller", "_flyHeight", "_hoverHeight", "_side",
        "_pilotClass", "_soldierClass", "_loiterHeight", "_loiterRadius", "_loiterDuration"
    ];

    private _isSlingload      = _supportType in ["LIVRAISON", "VEHICULE"];
    private _cargo            = objNull;
    private _originalMass     = 0;
    private _victoryTriggered = false;

    // ── SUB-THREAD COMBAT ─────────────────────────────────────────────────────
    // Intervalle 3s — maintient le cap et force le tir des artilleurs.
    [_heli, _group] spawn {
        params ["_heli", "_group"];

        private _reloadTick = 0;

        while { alive _heli && { missionNamespace getVariable ["TAG_AirSupport_Active", false] } } do {
            sleep 3;
            if (!alive _heli) exitWith {};

            _reloadTick = _reloadTick + 1;

            // Détection
            private _enemies = allUnits select {
                alive _x && { side _x == east } && { _x distance2D _heli < 800 }
            };

            if (count _enemies > 0) then {
                { _group reveal [_x, 4]; } forEach _enemies;

                private _target   = _enemies # 0;
                private _bestDist = _target distance _heli;
                {
                    private _d = _x distance _heli;
                    if (_d < _bestDist) then { _bestDist = _d; _target = _x; };
                } forEach _enemies;

                {
                    // Boucle de tir EXCLUSIVEMENT sur les passagers/gunners (pas les 2 pilotes à l'avant)
                    private _gunner = _x;
                    
                    // Récupère nativement l'arme de l'endroit où le jeu l'a assis
                    private _turretPath = _heli unitTurret _gunner;
                    private _turretWeapon = (_heli weaponsTurret _turretPath) param [0, ""];

                    _gunner doTarget _target;
                    _gunner doWatch  _target;
                    
                    // Ordres natifs ultra-agressifs
                    _group reveal [_target, 4];
                    _gunner doFire _target;
                    _gunner suppressFor 3; // Force l'IA à tirer même si la cible n'est pas "parfaite"

                    // Force mécanique absolue si l'IA s'endort
                    if (_turretWeapon != "") then {
                        _heli selectWeaponTurret [_turretWeapon, _turretPath];
                        _gunner forceWeaponFire [_turretWeapon, _turretWeapon]; 
                    };
                } forEach ((units _group) select { _x != (driver _heli) && { _heli unitTurret _x isNotEqualTo [0] } });
            };
        };
    };

    // ── HAUTEUR STATIONNAIRE — ajustement par type de mission ─────────────────
    if (_supportType == "VEHICULE") then { _hoverHeight = 10; };

    // ── MARQUEUR DE SOUTIEN SUR LA CARTE ──────────────────────────────────────
    private _markerName = format ["heli_support_%1_%2", _supportType, floor (random 100000)];
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

    // ── PRÉPARATION DU SLINGLOAD ───────────────────────────────────────────────
    if (_isSlingload) then {
        private _cargoClass = "B_supplyCrate_F";
        if (_supportType == "VEHICULE") then {
            _cargoClass = if (!isNil "vehicule_team" && { !isNull vehicule_team }) then {
                typeOf vehicule_team
            } else {
                "CUP_B_nM1025_SOV_M2_USMC_DES"
            };
        };

        _cargo = createVehicle [_cargoClass, [0,0,0], [], 0, "NONE"];
        _cargo setPos (_heli modelToWorld [0, 0, -15]);
        _cargo allowDamage false;
        _originalMass = getMass _cargo;

        // Masse stabilisatrice pour un slingload réaliste
        private _stabMass = if (_supportType == "LIVRAISON") then { 500 } else { 800 };
        _cargo setMass _stabMass;
        _heli setSlingLoad _cargo;

        // Remplissage dynamique de la caisse munitions depuis l'inventaire des alliés
        if (_supportType == "LIVRAISON") then {
            clearWeaponCargoGlobal   _cargo;
            clearMagazineCargoGlobal _cargo;
            clearItemCargoGlobal     _cargo;
            clearBackpackCargoGlobal _cargo;

            private _allWeapons   = [];
            private _allMagazines = [];
            private _allItems     = [];
            private _allBackpacks = [];

            private _alliedUnits = allUnits select { alive _x && { side (group _x) == _side } };
            {
                // Armes + chargeurs compatibles depuis la config
                {
                    if (_x != "") then {
                        _allWeapons pushBackUnique _x;
                        private _mags = getArray (configFile >> "CfgWeapons" >> _x >> "magazines");
                        if (count _mags > 0) then { _allMagazines pushBackUnique (_mags # 0); };
                        if (count _mags > 1) then { _allMagazines pushBackUnique (_mags # 1); };
                    };
                } forEach [primaryWeapon _x, secondaryWeapon _x, handgunWeapon _x];

                { _allMagazines pushBackUnique _x; } forEach (magazines _x);

                {
                    if (_x in ["ItemGPS","ItemDetector","ToolKit","MineDetector","B_UavTerminal"]) then {
                        _allItems pushBackUnique _x;
                    };
                } forEach (items _x + assignedItems _x);

                if (backpack _x != "") then { _allBackpacks pushBackUnique (backpack _x); };
            } forEach _alliedUnits;

            { _cargo addWeaponCargoGlobal   [_x, 2]; } forEach _allWeapons;
            {
                private _qty = if (
                    (toLower _x find "grenade") != -1 ||
                    (toLower _x find "shell")   != -1 ||
                    (toLower _x find "smoke")   != -1
                ) then { 10 } else { 15 };
                _cargo addMagazineCargoGlobal [_x, _qty];
            } forEach _allMagazines;
            { _cargo addBackpackCargoGlobal [_x, 2]; } forEach _allBackpacks;
            { _cargo addItemCargoGlobal     [_x, 2]; } forEach _allItems;

            // Soin et fumigènes standards toujours présents
            _cargo addItemCargoGlobal     ["FirstAidKit",      20];
            _cargo addMagazineCargoGlobal ["SmokeShell",       10];
            _cargo addMagazineCargoGlobal ["SmokeShellGreen",  10];
        };
    };

    // ─────────────────────────────────────────────────────────────────────────
    // PHASE 1 — APPROCHE VERS LA CIBLE
    // ─────────────────────────────────────────────────────────────────────────
    private _wp1 = _group addWaypoint [_dropPos, 0];
    _wp1 setWaypointType       "MOVE";
    _wp1 setWaypointBehaviour  "AWARE";
    _wp1 setWaypointCombatMode "RED";
    _wp1 setWaypointSpeed      "FULL";
    _heli doMove _dropPos;

    private _approachTimer = 0;
    waitUntil {
        sleep 1;
        _approachTimer = _approachTimer + 1;
        (_heli distance2D _dropPos < 200) || _approachTimer > 180 || !alive _heli
    };

    // Sortie anticipée si heli détruit en approche
    if (!alive _heli) exitWith {
        deleteMarker _markerName;
        missionNamespace setVariable ["TAG_AirSupport_Active",   false,   true];
        missionNamespace setVariable ["LL_missionHelicopter",    objNull, true];
    };

    deleteWaypoint [_group, 0];

    // Désactiver la destination de transit pendant les manœuvres précises
    _heli setVariable ["TAG_Heli_CurrentDestination", [], true];

    // ─────────────────────────────────────────────────────────────────────────
    // PHASE 2 — EXÉCUTION DE LA MISSION
    // ─────────────────────────────────────────────────────────────────────────

    // ── CAS A : LIVRAISON MUNITIONS ou VÉHICULE (slingload) ──────────────────
    if (_isSlingload) then {
        _heli flyInHeight    _hoverHeight;
        _heli flyInHeightASL [_hoverHeight, _hoverHeight, _hoverHeight];

        // Approche finale précise sur le point de largage
        private _wp2 = _group addWaypoint [_dropPos, 0];
        _wp2 setWaypointType       "MOVE";
        _wp2 setWaypointBehaviour  "AWARE";
        _wp2 setWaypointCombatMode "RED";
        _wp2 setWaypointSpeed      "FULL";
        _heli doMove _dropPos;

        private _posTimer = 0;
        waitUntil {
            sleep 0.25;
            _posTimer = _posTimer + 0.25;

            // Correction physique ultra-précise sous les 25 mètres
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
            missionNamespace setVariable ["TAG_AirSupport_Active",   false,   true];
            missionNamespace setVariable ["LL_missionHelicopter",    objNull, true];
        };

        _heli setVelocity [0, 0, 0];
        _heli flyInHeight _hoverHeight;

        // Descente progressive du colis avec correction de trajectoire continue
        private _dropTimer  = 0;
        private _minCargoH  = if (_supportType == "LIVRAISON") then { 5 } else { 4 };

        waitUntil {
            sleep 0.25;
            _dropTimer = _dropTimer + 0.25;

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
            missionNamespace setVariable ["TAG_AirSupport_Active",   false,   true];
            missionNamespace setVariable ["LL_missionHelicopter",    objNull, true];
        };

        sleep 1;

        // Détachement du câble de slingload
        { ropeDestroy _x; } forEach (ropes _heli);
        _heli setSlingLoad objNull;

        sleep 1;
        _cargo setVelocity [0, 0, 0];
        _cargo setVectorUp [0, 0, 1];
        _cargo setMass     _originalMass;
        _cargo allowDamage true;

        if (_supportType == "LIVRAISON") then {
            (localize "STR_TAG_Msg_Ammo_Dropped") remoteExec ["systemChat", _caller];

            // Signalisation fumigène + nettoyage différé (10 minutes)
            [_cargo] spawn {
                params ["_crate"];
                if (isNull _crate) exitWith {};

                private _smokeGreen = createVehicle ["SmokeShellGreen", getPos _crate, [], 0, "CAN_COLLIDE"];
                private _destroyed  = false;

                for "_i" from 1 to 59 do {     // 59 × 10s = 590s
                    sleep 10;
                    if (!alive _crate) exitWith { _destroyed = true; };
                };

                if (_destroyed) exitWith {
                    if (!isNull _smokeGreen) then { deleteVehicle _smokeGreen; };
                };

                if (alive _crate) then {
                    private _smokes = [];
                    for "_dir" from 0 to 360 step 45 do {
                        _smokes pushBack (createVehicle ["SmokeShell", (_crate getPos [2, _dir]), [], 0, "CAN_COLLIDE"]);
                    };
                    sleep 10;
                    if (alive _crate)       then { deleteVehicle _crate; };
                    if (!isNull _smokeGreen) then { deleteVehicle _smokeGreen; };
                    sleep 120;
                    { if (!isNull _x) then { deleteVehicle _x; }; } forEach _smokes;
                };
            };

        } else {
            (localize "STR_TAG_Msg_Vehicle_Dropped") remoteExec ["systemChat", _caller];
            missionNamespace setVariable ["vehicule_team", _cargo, true];
        };
    };

    // ── CAS B : APPUI AÉRIEN RAPPROCHÉ (CAS) ──────────────────────────────────
    if (_supportType == "CAS") then {
        _heli flyInHeight    _loiterHeight;
        _heli flyInHeightASL [_loiterHeight, _loiterHeight, _loiterHeight];

        private _wpCAS = _group addWaypoint [_dropPos, 0];
        _wpCAS setWaypointType         "LOITER";
        _wpCAS setWaypointLoiterType   "CIRCLE";
        _wpCAS setWaypointLoiterRadius _loiterRadius;
        _wpCAS setWaypointBehaviour    "AWARE";
        _wpCAS setWaypointCombatMode   "RED";
        _wpCAS setWaypointSpeed        "LIMITED";
        _heli doMove _dropPos;

        // Attendre l'entrée en zone de loiter
        waitUntil {
            sleep 1;
            !alive _heli || (_heli distance2D _dropPos < (_loiterRadius + 150))
        };

        // Fenêtre de combat : 3 minutes avec révélation continue des cibles
        if (alive _heli) then {
            private _endTime    = time + 180;
            private _lastReveal = 0;
            while { time < _endTime && { alive _heli } } do {
                sleep 1;
                if (time - _lastReveal > 5) then {
                    _lastReveal = time;
                    {
                        _group reveal [_x, 4];
                    } forEach (allUnits select { alive _x && { side _x == east } && { _x distance2D _dropPos < 500 } });
                };
            };
        };

        while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };
    };

    // ── CAS C : DÉBARQUEMENT / EMBARQUEMENT ───────────────────────────────────
    if (_supportType in ["DEBARQUEMENT", "EMBARQUEMENT"]) then {
        _heli flyInHeight 0;
        _heli land (if (_supportType == "DEBARQUEMENT") then { "GET OUT" } else { "GET IN" });

        private _landTimer = 0;
        waitUntil {
            sleep 1;
            _landTimer = _landTimer + 1;
            !alive _heli ||
            isTouchingGround _heli ||
            (velocity _heli # 2 == 0 && { getPosVisual _heli # 2 < 2 }) ||
            _landTimer > 60
        };

        if (!alive _heli) exitWith {
            deleteMarker _markerName;
            missionNamespace setVariable ["TAG_AirSupport_Active",   false,   true];
            missionNamespace setVariable ["LL_missionHelicopter",    objNull, true];
        };

        // ── DÉBARQUEMENT — spawn et équipement de l'escouade de renfort ──────
        if (_supportType == "DEBARQUEMENT") then {
            private _infGroup  = createGroup [_side, true];
            private _unitTypes = [
                "CUP_I_RACS_Soldier_SL",
                "CUP_I_RACS_Soldier_Medic",
                "CUP_I_RACS_Soldier_MG",
                "CUP_I_RACS_Soldier_LAT",
                "CUP_I_RACS_Soldier"
            ];
            private _reinforcements = [];

            // Pools d'équipements — identiques à fn_initPlayerLoadout.sqf
            private _vests = [
                "CUP_V_JPC_medical_coy","CUP_V_JPC_tl_coy","CUP_V_JPC_weapons_coy",
                "CUP_V_JPC_communicationsbelt_coy","CUP_V_JPC_Fastbelt_coy",
                "CUP_V_JPC_lightbelt_coy","CUP_V_JPC_medicalbelt_coy",
                "CUP_V_JPC_tlbelt_coy","CUP_V_JPC_weaponsbelt_coy"
            ];
            private _helmets = [
                "CUP_H_OpsCore_Tan_SF","CUP_H_OpsCore_Tan","CUP_H_OpsCore_Tan_NohS",
                "CUP_H_OpsCore_Grey_SF","CUP_H_OpsCore_Grey","CUP_H_OpsCore_Grey_NohS"
            ];
            private _backpacks = ["CUP_B_AssaultPack_Coyote","B_assaultPack_cbr","B_Kitbag_cbr"];
            private _uniforms  = [
                "CUP_U_B_USMC_MCCUU_des_gloves","CUP_U_B_USMC_MCCUU_des_roll_2",
                "CUP_U_B_USMC_MCCUU_des_roll_2_gloves","CUP_U_B_USMC_MCCUU_des_roll_pads",
                "CUP_U_B_USMC_MCCUU_des_roll_2_pads_gloves","CUP_U_B_USMC_MCCUU_des_pads",
                "CUP_U_B_USMC_MCCUU_des_pads_gloves","CUP_U_B_USMC_MCCUU_des_roll",
                "CUP_U_B_USMC_MCCUU_des_roll_gloves","CUP_U_B_USMC_MCCUU_des_roll_pads",
                "CUP_U_B_USMC_MCCUU_des_roll_pads_gloves","CUP_U_B_USMC_MCCUU_des"
            ];
            private _cagoules = [
                "CUP_G_Tan_Scarf_Shades_GPSCombo_Beard","CUP_G_Tan_Scarf_Shades_GPS_Beard",
                "CUP_G_Tan_Scarf_GPS","CUP_G_TK_RoundGlasses_blk","CUP_G_Oakleys_Drk",
                "CUP_G_Scarf_Face_Tan","G_Aviator","CUP_G_ESS_KHK_Scarf_Tan_GPS_Beard",
                "CUP_G_ESS_KHK_Facewrap_Tan","G_Bandana_khk"
            ];

            // Aide locale : ajoute les chargeurs compatibles d'une arme
            private _fnAddMags = {
                params ["_u","_w","_n"];
                if (_w == "") exitWith {};
                private _mags = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
                if (count _mags > 0) then {
                    for "_i" from 1 to _n do { _u addItem (_mags # 0); };
                };
            };

            {
                private _unitType = _x;
                private _unit     = _infGroup createUnit [_unitType, _dropPos, [], 0, "NONE"];

                // Sélection du gilet selon le rôle
                private _vestPool = switch (true) do {
                    case (_unitType == "CUP_I_RACS_Soldier_Medic"): {
                        private _p = _vests select { _x find "medical" != -1 };
                        if (count _p > 0) then { _p } else { _vests }
                    };
                    case (_unitType == "CUP_I_RACS_Soldier_SL"): {
                        private _p = _vests select { _x find "_tl" != -1 };
                        if (count _p > 0) then { _p } else { _vests }
                    };
                    default { _vests };
                };

                removeUniform  _unit;
                removeVest     _unit;
                removeBackpack _unit;
                removeHeadgear _unit;
                removeGoggles  _unit;

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

                // [OPT-2] Identité depuis le pool global LL_g_allNamesTyped (déjà construit par fn_initPlayerIdentity)
                private _allNamesTyped = missionNamespace getVariable ["LL_g_allNamesTyped", []];
                // Fallback minimal si le global n'est pas encore initialisé
                if (count _allNamesTyped == 0) then {
                    _allNamesTyped = [
                        [["Mehdi Benali",   "Mehdi",   "Benali"],  "Arab"],
                        [["Mustafa Demir",  "Mustafa", "Demir"],   "Turkish"],
                        [["Moussa Diallo",  "Moussa",  "Diallo"],  "African"],
                        [["Budi Santoso",   "Budi",    "Santoso"], "Indonesian"]
                    ];
                };

                private _usedNames = missionNamespace getVariable ["LL_g_usedPlayerNames", []];
                private _available = _allNamesTyped select { !((_x # 0 # 0) in _usedNames) };
                if (count _available == 0) then { _usedNames = []; _available = _allNamesTyped; };

                private _entry    = selectRandom _available;
                private _nameData = _entry # 0;
                private _faceType = _entry # 1;
                _usedNames pushBackUnique (_nameData # 0);
                missionNamespace setVariable ["LL_g_usedPlayerNames", _usedNames, true];

                private _faces = switch (_faceType) do {
                    case "Turkish";
                    case "Arab":       { ["PersianHead_A3_01","PersianHead_A3_02","PersianHead_A3_03",
                                         "GreekHead_A3_01","GreekHead_A3_02","GreekHead_A3_03",
                                         "GreekHead_A3_04","GreekHead_A3_05","GreekHead_A3_06"] };
                    case "African":    { ["AfricanHead_01","AfricanHead_02","AfricanHead_03"] };
                    case "Indonesian": { ["AsianHead_A3_01","AsianHead_A3_02","AsianHead_A3_03",
                                         "TanoanHead_A3_01","TanoanHead_A3_02","TanoanHead_A3_03",
                                         "TanoanHead_A3_04","TanoanHead_A3_05"] };
                    default            { ["WhiteHead_01","WhiteHead_02","WhiteHead_03","WhiteHead_04",
                                         "WhiteHead_05","WhiteHead_06","WhiteHead_07","WhiteHead_08",
                                         "WhiteHead_09","WhiteHead_10","WhiteHead_11","WhiteHead_12",
                                         "WhiteHead_13","WhiteHead_14","WhiteHead_15","WhiteHead_16"] };
                };

                private _face    = selectRandom _faces;
                private _speaker = selectRandom [
                    "Male01ENG","Male02ENG","Male03ENG","Male04ENG","Male05ENG",
                    "Male01ENGB","Male02ENGB","Male03ENGB","Male04ENGB","Male05ENGB",
                    "Male01GRE","Male02GRE","Male03GRE","Male04GRE","Male05GRE"
                ];
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

            // Débarquement des renforts
            { unassignVehicle _x; moveOut _x; sleep 0.5; } forEach _reinforcements;

            private _unloadTimer = 0;
            waitUntil {
                sleep 1;
                _unloadTimer = _unloadTimer + 1;
                !alive _heli ||
                ({ _x in _heli } count _reinforcements == 0) ||
                _unloadTimer > 30
            };

            // Rejoindre le groupe du joueur ou patrouille autonome
            private _playerGroup = if (!isNull _caller) then { group _caller } else { grpNull };
            if (!isNull _playerGroup) then {
                _reinforcements joinSilent _playerGroup;
                (localize "STR_LL_Heli_Msg_Squad_Joined") remoteExec ["systemChat", 0];
            } else {
                [_infGroup, _dropPos, 150] call BIS_fnc_taskPatrol;
                (localize "STR_LL_Heli_Msg_Patrol_Started") remoteExec ["systemChat", 0];
            };
        };

        // ── EMBARQUEMENT — attente des joueurs puis déclenchement victoire ────
        if (_supportType == "EMBARQUEMENT") then {
            (localize "STR_LL_Heli_Msg_Landed_Extract") remoteExec ["systemChat", 0];

            private _timeout     = time + 600;  // 10 minutes d'attente maximum
            private _shouldLeave = false;

            waitUntil {
                sleep 2;
                private _allHumans  = allPlayers select { alive _x };
                private _inHeli     = crew _heli select { _x in _allHumans };

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

                    // Décollage vers la base
                    _heli setVariable ["TAG_Heli_CurrentDestination", _homeBase, true];
                    _heli flyInHeight _flyHeight;
                    private _wpVic = _group addWaypoint [_homeBase, 0];
                    _wpVic setWaypointType       "MOVE";
                    _wpVic setWaypointBehaviour  "AWARE";
                    _wpVic setWaypointCombatMode "RED";
                    _wpVic setWaypointSpeed      "FULL";
                    _heli doMove _homeBase;

                    // Masquer les unités embarquées (non membres de l'équipage heli)
                    { _x hideObjectGlobal true; } forEach (crew _heli select { !(_x in _crew) });
                    _heli lock 2;

                    sleep 25;
                    if (alive _heli) then {
                        ["MissionSuccess", true, true] remoteExec ["BIS_fnc_endMission", 0];
                    };
                };
            };
        };
    };

    // ─────────────────────────────────────────────────────────────────────────
    // PHASE 3 — RETOUR BASE ET DESPAWN
    // ─────────────────────────────────────────────────────────────────────────
    if (!_victoryTriggered) then {
        deleteMarker _markerName;

        if (_supportType == "CAS") then {
            (localize "STR_TAG_Msg_CAS_RTB") remoteExec ["systemChat", _caller];
        };

        sleep 2;

        // Nettoyer tous les waypoints restants
        while { count (waypoints _group) > 0 } do { deleteWaypoint [_group, 0]; };

        _heli setVariable ["TAG_Heli_CurrentDestination", _homeBase, true];
        _heli flyInHeight _flyHeight;

        private _wpRTB = _group addWaypoint [_homeBase, 0];
        _wpRTB setWaypointType       "MOVE";
        _wpRTB setWaypointBehaviour  "AWARE";
        _wpRTB setWaypointCombatMode "RED";
        _wpRTB setWaypointSpeed      "FULL";
        _group setCurrentWaypoint _wpRTB;
        _heli doMove _homeBase;

        // Libération immédiate du verrou — le joueur peut redemander une mission
        missionNamespace setVariable ["TAG_AirSupport_Active", false, true];

        private _rtbStart = time;
        waitUntil {
            sleep 5;
            (_heli distance2D _homeBase < 200) || !alive _heli || (time - _rtbStart > 180)
        };

        if (alive _heli) then {
            // Fallback : joueurs à bord au retour = victoire (cas exceptionnel)
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
};
