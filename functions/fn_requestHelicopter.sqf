#include "..\macros.hpp"

/*
 * LL_fnc_requestHelicopter
 *
 * Description:
 *   Fonction unique côté serveur de gestion du support hélicoptère (Chinook CUP_I_CH47F_RACS).
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
    
    private _msg = format [localize "STR_TAG_Msg_CAS_Cooldown", _remaining];
    _msg remoteExec ["systemChat", _caller];
    diag_log format ["[LL] requestHelicopter: Soutien CAS refusé. Cooldown actif (%1s restants).", _remaining];
};

// 1. Vérification spécifique pour la livraison unique du véhicule
if (_supportType == "VEHICULE" && {missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false]}) exitWith {
    (localize "STR_TAG_Msg_Vehicle_Denied_Once") remoteExec ["systemChat", _caller];
    diag_log "[LL] requestHelicopter: Soutien véhicule refusé. Le véhicule de remplacement a déjà été livré.";
};

// 2. Vérifier si un soutien aérien est déjà en cours (Verrou unique et partagé)
if (missionNamespace getVariable ["TAG_AirSupport_Active", false]) exitWith {
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



private _approveMsg = "STR_TAG_Msg_Ammo_Approved";
if (_supportType == "VEHICULE") then { _approveMsg = "STR_TAG_Msg_Vehicle_Approved"; };
if (_supportType == "CAS") then { _approveMsg = "STR_TAG_Msg_CAS_Approved"; };
(localize _approveMsg) remoteExec ["systemChat", _caller];

// --- 1. DÉTERMINATION DE LA POSITION DE DESTINATION (HÉLIPORTS OU ROUTE INTELLIGENTE) ---
private _targetPosFinal = +_targetPos;

// Collecter tous les héliports invisibles de la mission
private _heliports = [];
for "_i" from 0 to 999 do {
    private _numStr = "";
    if (_i < 10) then { _numStr = "00" + str _i; } else {
        if (_i < 100) then { _numStr = "0" + str _i; } else { _numStr = str _i; };
    };
    {
        private _varName = _x + _numStr;
        private _heliportObj = missionNamespace getVariable [_varName, objNull];
        if (!isNull _heliportObj) then {
            _heliports pushBackUnique _heliportObj;
        };
    } forEach ["Heliport_", "heliport_"];
};
for "_i" from 0 to 99 do {
    private _numStr = if (_i < 10) then { "0" + str _i } else { str _i };
    {
        private _varName = _x + _numStr;
        private _heliportObj = missionNamespace getVariable [_varName, objNull];
        if (!isNull _heliportObj) then {
            _heliports pushBackUnique _heliportObj;
        };
    } forEach ["Heliport_", "heliport_"];
};

// Trouver l'héliport le plus proche du joueur appelant
private _nearestHeliport = objNull;
private _minDist = 999999;
private _referencePos = getPosATL _caller;
{
    private _dist = _x distance2D _referencePos;
    if (_dist < _minDist) then {
        _minDist = _dist;
        _nearestHeliport = _x;
    };
} forEach _heliports;

if (_supportType in ["LIVRAISON", "VEHICULE", "DEBARQUEMENT", "EMBARQUEMENT"]) then {
    if (!isNull _nearestHeliport) then {
        _targetPosFinal = getPosATL _nearestHeliport;
        diag_log format ["[LL] requestHelicopter: Support %1. Héliport le plus proche sélectionné : %2 à %3m (pos: %4)", _supportType, vehicleVarName _nearestHeliport, round _minDist, _targetPosFinal];
    } else {
        // Fallback si aucun héliport n'est défini
        _targetPosFinal = getPosATL _caller;
        diag_log format ["[LL][WARNING] requestHelicopter: Aucun héliport trouvé ! Fallback sur la position du joueur : %1", _targetPosFinal];
    };
};

if (_supportType == "CAS") then {
    // Le CAS orbite autour de la position actuelle du joueur appelant
    _targetPosFinal = getPosATL _caller;
    diag_log format ["[LL] requestHelicopter: Support CAS. Orbite autour du joueur (pos: %1)", _targetPosFinal];
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
private _helicoClass = "CUP_I_CH47F_RACS";

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
        _heli setVehicleAmmo 1; // Remplir toutes les munitions des armes du véhicule
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

// --- DIAGNOSTIC : Logger les tourelles disponibles pour debug RPT ---
private _turrets = allTurrets _heli;
diag_log format ["[LL][HELI] allTurrets retourne %1 tourelles : %2", count _turrets, _turrets];
{
    private _weapons = _heli weaponsTurret _x;
    private _magazines = _heli magazinesTurret _x;
    diag_log format ["[LL][HELI]   Tourelle %1 : armes=%2 | magazines=%3", _x, _weapons, _magazines];
} forEach _turrets;

// Artilleurs des tourelles armées (exclure copilote [0] et les sièges FFV sans arme montée)
private _gunnerTurrets = _turrets select { 
    _x isNotEqualTo [0] && { count (_heli weaponsTurret _x) > 0 } 
};
diag_log format ["[LL][HELI] Tourelles armées filtrées : %1 (total: %2)", _gunnerTurrets, count _gunnerTurrets];

{
    private _turretPath = _x;
    private _gunner = _group createUnit [_soldierClass, [0,0,0], [], 0, "NONE"];
    _gunner moveInTurret [_heli, _turretPath];
    _crew pushBack _gunner;
    
    // Rendre l'artilleur ultra agressif et réactif
    _gunner setSkill 1;
    { _gunner setSkill [_x, 1.0]; } forEach ["aimingAccuracy", "aimingShake", "aimingSpeed", "spotDistance", "spotTime", "courage", "commanding"];
    
    // Activer TOUS les modules IA de combat pour garantir l'engagement
    _gunner enableAI "TARGET";
    _gunner enableAI "AUTOTARGET";
    _gunner enableAI "AUTOCOMBAT";
    _gunner enableAI "SUPPRESSION";
    _gunner enableAI "FSM";
    _gunner enableAI "MOVE";
    
    // Forcer le mode combat individuel sur l'artilleur
    _gunner setCombatMode "RED";
    _gunner setBehaviour "COMBAT";
    
    diag_log format ["[LL][HELI]   Artilleur %1 placé sur tourelle %2", _gunner, _turretPath];
} forEach _gunnerTurrets;

// CRITIQUE : Recharger les munitions du véhicule APRÈS placement de l'équipage dans les tourelles
sleep 0.5;
_heli setVehicleAmmo 1;
diag_log "[LL][HELI] setVehicleAmmo 1 appliqué APRÈS placement équipage.";

// Forcer la sélection de l'arme de tourelle pour chaque artilleur
{
    private _turretPath = _gunnerTurrets select (_forEachIndex);
    private _turretWeapons = _heli weaponsTurret _turretPath;
    if (count _turretWeapons > 0) then {
        _x selectWeapon (_turretWeapons select 0);
        diag_log format ["[LL][HELI]   Artilleur %1 : arme de tourelle sélectionnée = %2", _x, _turretWeapons select 0];
    };
} forEach (_crew select [2, count _crew]);

// Configurer le groupe en mode combat agressif pour que le véhicule autorise le tir des artilleurs
_group setBehaviour "COMBAT";
_group setCombatMode "RED";
_group setSpeedMode "FULL";

// Appliquer également les modes au véhicule lui-même pour forcer l'armement
_heli setCombatMode "RED";

// Désigner le premier artilleur comme leader pour que les ordres de combat du groupe soient transmis, 
// car les pilotes ont leur IA de ciblage désactivée et bloqueraient sinon la transmission
if (count _crew > 2) then {
    private _firstGunner = _crew select 2;
    _group selectLeader _firstGunner;
};

// Neutraliser sélectivement le comportement de combat des pilotes (vol imperturbable)
{
    _x disableAI "TARGET";
    _x disableAI "AUTOTARGET";
    _x disableAI "AUTOCOMBAT";
    _x disableAI "SUPPRESSION";
    _x disableAI "FSM";
    _x setCombatMode "BLUE"; // Never fire (pilotes uniquement)
} forEach [_pilot, _copilot];

// Tout l'équipage est invincible
{
    _x allowDamage false;
} forEach _crew;

// Enregistrer l'hélicoptère globalement
missionNamespace setVariable ["LL_missionHelicopter", _heli, true];

// --- 4. EXÉCUTION DU THREAD DE VOL ET COMPORTEMENT ---
[_heli, _targetPosFinal, _group, _crew, _homeBase, _supportType, _caller, _flyHeight, _hoverHeight, _side, _pilotClass, _soldierClass, _loiterHeight, _loiterRadius, _loiterDuration] spawn {
    params ["_heli", "_dropPos", "_group", "_crew", "_homeBase", "_supportType", "_caller", "_flyHeight", "_hoverHeight", "_side", "_pilotClass", "_soldierClass", "_loiterHeight", "_loiterRadius", "_loiterDuration"];
    
    private _isSlingload = (_supportType == "LIVRAISON" || _supportType == "VEHICULE");
    private _cargo = objNull;
    private _originalMass = 0;
    private _victoryTriggered = false;

    // Initialiser la destination courante pour la boucle de rappel
    _heli setVariable ["TAG_Heli_CurrentDestination", _dropPos, true];

    // Sous-thread de combat : forcer le tir des artilleurs toutes les 2 secondes
    [_heli, _group, _crew] spawn {
        params ["_heli", "_group", "_crew"];
        private _ammoReloadCounter = 0;
        
        while {alive _heli && {missionNamespace getVariable ["TAG_AirSupport_Active", false]}} do {
            sleep 2;
            if (!alive _heli) exitWith {};
            _ammoReloadCounter = _ammoReloadCounter + 1;

            // 1. Maintenir le mode combat du groupe (forcer COMBAT + RED en permanence)
            _group setBehaviour "COMBAT";
            _group setCombatMode "RED";

            // 2. Maintenir la destination de vol (le pilote suit les ordres malgré le combat)
            private _dest = _heli getVariable ["TAG_Heli_CurrentDestination", [0,0,0]];
            if (_dest isNotEqualTo [0,0,0]) then {
                _heli doMove _dest;
                _group setSpeedMode "FULL";
            };

            // 3. Recharger les munitions toutes les 30 secondes (15 itérations × 2s)
            if (_ammoReloadCounter mod 15 == 0) then {
                _heli setVehicleAmmo 1;
            };

            // 4. Identifier les artilleurs vivants (tout sauf pilote index 0 et copilote index 1)
            private _gunners = [];
            { if (alive _x && {_forEachIndex >= 2}) then { _gunners pushBack _x; }; } forEach _crew;

            // 5. Révéler les ennemis proches ET forcer le tir
            private _enemies = allUnits select { alive _x && {side _x == east} && {_x distance2D _heli < 1000} };

            if (count _enemies > 0) then {
                // Révéler toutes les cibles à connaissance maximale
                { _group reveal [_x, 4]; } forEach _enemies;

                // Trouver la cible prioritaire (la plus proche de l'hélicoptère)
                private _bestTarget = objNull;
                private _bestDist = 9999;
                {
                    private _d = _x distance _heli;
                    if (_d < _bestDist) then { _bestDist = _d; _bestTarget = _x; };
                } forEach _enemies;

                // Ordonner le tir à chaque artilleur + forcer physiquement le tir de la tourelle
                if (!isNull _bestTarget) then {
                    {
                        _x doWatch _bestTarget;
                        _x doTarget _bestTarget;
                        _x doFire _bestTarget;
                        
                        // Forcer le tir physique de l'arme de tourelle si l'IA refuse
                        private _cw = currentWeapon _x;
                        if (_cw != "") then {
                            _x forceWeaponFire [_cw, "FullAuto"];
                        };
                    } forEach _gunners;

                    // Aussi commander le tir du véhicule directement sur la cible
                    _heli fireAtTarget [_bestTarget, currentWeapon ((crew _heli) select {_x in _gunners} param [0, objNull])];

                    // Ordre hiérarchique depuis le leader du groupe
                    (leader _group) commandTarget _bestTarget;
                };
            };
        };
    };
    
    // Si livraison de véhicule, la hauteur stationnaire finale est de 10m au lieu de 15m
    if (_supportType == "VEHICULE") then { _hoverHeight = 10; };

    // Création du marqueur de carte unifié pour indiquer la zone de support
    private _markerName = format ["heli_support_mrk_%1_%2", _supportType, floor(random 100000)];
    private _markerType = "mil_dot";
    private _markerColor = "ColorBlack";
    private _markerText = "";

    switch (_supportType) do {
        case "LIVRAISON": {
            _markerType = "mil_box";
            _markerColor = "ColorBlue";
            _markerText = localize "STR_TAG_Marker_Heli_Ammo";
        };
        case "VEHICULE": {
            _markerType = "mil_box";
            _markerColor = "ColorBlue";
            _markerText = localize "STR_TAG_Marker_Heli_Vehicle";
        };
        case "DEBARQUEMENT": {
            _markerType = "mil_end";
            _markerColor = "ColorGreen";
            _markerText = localize "STR_TAG_Marker_Heli_Debark";
        };
        case "EMBARQUEMENT": {
            _markerType = "mil_pickup";
            _markerColor = "ColorYellow";
            _markerText = localize "STR_TAG_Marker_Heli_Extract";
        };
        case "CAS": {
            _markerType = "mil_warning";
            _markerColor = "ColorRed";
            _markerText = localize "STR_TAG_Marker_Heli_CAS";
        };
    };

    private _mrk = createMarker [_markerName, _dropPos];
    _mrk setMarkerType _markerType;
    _mrk setMarkerColor _markerColor;
    _mrk setMarkerText _markerText;

    // --- PREPARATION DU SLINGLOAD ---
    if (_isSlingload) then {
        private _cargoClass = "B_supplyCrate_F";
        if (_supportType == "VEHICULE") then {
            _cargoClass = if (!isNil "vehicule_team" && {!isNull vehicule_team}) then { typeOf vehicule_team } else { "CUP_B_nM1025_SOV_M2_USMC_DES" };
        };
        _cargo = createVehicle [_cargoClass, [0,0,0], [], 0, "NONE"];
        _cargo setPos (_heli modelToWorld [0, 0, -15]);
        _cargo allowDamage false;
        _originalMass = getMass _cargo;
        
        // Poids stabilisateur (500 pour la caisse, 800 pour le véhicule)
        private _stabilizerMass = if (_supportType == "LIVRAISON") then { 500 } else { 800 };
        _cargo setMass _stabilizerMass;
        _heli setSlingLoad _cargo;

        // Remplissage dynamique à partir de l'équipement des unités alliées vivantes présentes (joueurs et IA)
        if (_supportType == "LIVRAISON") then {
            clearWeaponCargoGlobal _cargo;
            clearMagazineCargoGlobal _cargo;
            clearItemCargoGlobal _cargo;
            clearBackpackCargoGlobal _cargo;

            private _allWeapons = [];
            private _allMagazines = [];
            private _allItems = [];
            private _allBackpacks = [];

            // Récupérer toutes les unités alliées vivantes (joueurs et IA) présentes dans la mission
            private _alliedUnits = allUnits select { alive _x && {side (group _x) == _side} };

            {
                private _unit = _x;

                // 1. Analyser les armes équipées pour s'assurer d'avoir des munitions compatibles
                {
                    private _w = _x;
                    if (_w != "") then {
                        _allWeapons pushBackUnique _w;
                        
                        // Récupérer les chargeurs compatibles de la config
                        private _compMags = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
                        if (count _compMags > 0) then {
                            _allMagazines pushBackUnique (_compMags select 0);
                            if (count _compMags > 1) then {
                                _allMagazines pushBackUnique (_compMags select 1);
                            };
                        };
                    };
                } forEach [primaryWeapon _unit, secondaryWeapon _unit, handgunWeapon _unit];

                // 2. Analyser les chargeurs, fumigènes et grenades dans leur inventaire actuel
                {
                    _allMagazines pushBackUnique _x;
                } forEach (magazines _unit);

                // 3. Analyser les objets utiles (GPS, télémètres, outils, etc.)
                {
                    if (_x in ["ItemGPS", "ItemDetector", "ToolKit", "MineDetector", "B_UavTerminal"]) then {
                        _allItems pushBackUnique _x;
                    };
                } forEach (items _unit + assignedItems _unit);

                // 4. Analyser les sacs à dos
                private _bp = backpack _unit;
                if (_bp != "") then {
                    _allBackpacks pushBackUnique _bp;
                };

            } forEach _alliedUnits;

            // 5. Remplissage effectif de la caisse
            {
                _cargo addWeaponCargoGlobal [_x, 2];
            } forEach _allWeapons;

            {
                // Adapter la quantité si c'est une grenade ou un fumigène
                private _qty = 15;
                private _lower = toLower _x;
                if ((_lower find "grenade") != -1 || (_lower find "shell") != -1 || (_lower find "smoke") != -1) then {
                    _qty = 10;
                };
                _cargo addMagazineCargoGlobal [_x, _qty];
            } forEach _allMagazines;

            {
                _cargo addBackpackCargoGlobal [_x, 2];
            } forEach _allBackpacks;

            {
                _cargo addItemCargoGlobal [_x, 2];
            } forEach _allItems;

            // Toujours fournir du soin de base et quelques fumigènes standards
            _cargo addItemCargoGlobal ["FirstAidKit", 20];
            _cargo addMagazineCargoGlobal ["SmokeShell", 10];
            _cargo addMagazineCargoGlobal ["SmokeShellGreen", 10];
        };
    };

    // --- PHASE 1 : VOL VERS LA CIBLE ---
    private _wp1 = _group addWaypoint [_dropPos, 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointBehaviour "COMBAT";
    _wp1 setWaypointCombatMode "RED";
    _wp1 setWaypointSpeed "FULL";
    _heli doMove _dropPos;
    
    private _approachTimeout = 0;
    waitUntil {
        sleep 1;
        _approachTimeout = _approachTimeout + 1;
        ((_heli distance2D _dropPos) < 200) || _approachTimeout > 180 || !alive _heli
    };
    
    if (!alive _heli) exitWith { 
        deleteMarker _markerName;
        missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; 
        missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
    };
    
    deleteWaypoint [_group, 0];

    // Désactiver la destination de transit automatique lors des opérations spécifiques (loiter, atterrissage, stationnaire)
    _heli setVariable ["TAG_Heli_CurrentDestination", [0,0,0], true];

    // --- PHASE 2 : EXÉCUTION DES TÂCHES SPÉCIFIQUES ---
    
    // --- CAS A : LARGAGE MUNITIONS OU VÉHICULE ---
    if (_isSlingload) then {
        // Approche finale et vol stationnaire
        _heli flyInHeight _hoverHeight;
        _heli flyInHeightASL [_hoverHeight, _hoverHeight, _hoverHeight];
        
        private _wp2 = _group addWaypoint [_dropPos, 0];
        _wp2 setWaypointType "MOVE";
        _wp2 setWaypointBehaviour "COMBAT";
        _wp2 setWaypointCombatMode "RED";
        _wp2 setWaypointSpeed "FULL";
        _heli doMove _dropPos;
        
        private _positionTimeout = 0;
        waitUntil {
            sleep 0.25;
            _positionTimeout = _positionTimeout + 0.25;
            
            private _dist2D = _heli distance2D _dropPos;
            
            // Correction physique de la trajectoire pour forcer un stationnaire ultra précis sous les 25 mètres
            if (_dist2D < 25) then {
                private _heliPos = getPosVisual _heli;
                private _pushX = ((_dropPos select 0) - (_heliPos select 0)) * 0.4;
                private _pushY = ((_dropPos select 1) - (_heliPos select 1)) * 0.4;
                _pushX = (_pushX min 5) max -5;
                _pushY = (_pushY min 5) max -5;
                private _vel = velocity _heli;
                _heli setVelocity [_pushX, _pushY, _vel select 2];
            };

            (_dist2D < 2) || _positionTimeout > 50 || !alive _heli
        };
        
        if (!alive _heli) exitWith { 
            deleteMarker _markerName;
            missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; 
            missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
        };
        
        _heli setVelocity [0, 0, 0];
        _heli flyInHeight _hoverHeight;
        
        // Descente progressive du colis
        private _dropTimeout = 0;
        private _cargoGrounded = false;
        private _minCargoHeight = if (_supportType == "LIVRAISON") then { 5 } else { 4 };
        
        waitUntil {
            sleep 0.25;
            _dropTimeout = _dropTimeout + 0.25;
            private _newHeight = _hoverHeight - _dropTimeout;
            if (_newHeight < _minCargoHeight) then { _newHeight = _minCargoHeight; };
            
            _heli flyInHeight _newHeight;
            _heli flyInHeightASL [_newHeight, _newHeight, _newHeight];

            // Rétablir et maintenir l'alignement vertical parfait pendant la descente
            private _heliPos = getPosVisual _heli;
            private _pushX = ((_dropPos select 0) - (_heliPos select 0)) * 0.4;
            private _pushY = ((_dropPos select 1) - (_heliPos select 1)) * 0.4;
            _pushX = (_pushX min 4) max -4;
            _pushY = (_pushY min 4) max -4;
            _heli setVelocity [_pushX, _pushY, velocity _heli select 2];
            
            _cargoGrounded = (getPosATL _cargo select 2) < 3;
            if ((getPosATL _heli select 2) < 4) then {
                _cargoGrounded = true;
            };
            _cargoGrounded || _dropTimeout > 40 || !alive _heli || !alive _cargo
        };
        
        if (!alive _heli || !alive _cargo) exitWith { 
            deleteMarker _markerName;
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
            
            // Signalisation fumigène et nettoyage différé optimisé
            [_cargo] spawn {
                params ["_crate"];
                if (isNull _crate) exitWith {};
                
                private _smokeGreen = createVehicle ["SmokeShellGreen", getPos _crate, [], 0, "CAN_COLLIDE"];
                
                // Attente de 9 minutes et 50 secondes (590s) avec vérification d'existence active
                private _steps = 59; // 59 * 10s = 590s
                private _isDestroyed = false;
                for "_i" from 1 to _steps do {
                    sleep 10;
                    if (!alive _crate) exitWith { _isDestroyed = true; };
                };
                
                if (_isDestroyed) exitWith {
                    // Si la caisse est détruite avant les 10 min, nettoyer le fumigène vert s'il existe toujours
                    if (!isNull _smokeGreen) then { deleteVehicle _smokeGreen; };
                };
                
                if (alive _crate) then {
                    // Créer une fumée blanche épaisse autour de la caisse pour masquer sa disparition
                    private _smokes = [];
                    for "_dir" from 0 to 360 step 45 do {
                        private _smokePos = _crate getPos [2, _dir];
                        private _smk = createVehicle ["SmokeShell", _smokePos, [], 0, "CAN_COLLIDE"];
                        _smokes pushBack _smk;
                    };
                    
                    sleep 10; // Laisser le temps à la fumée de s'épaissir
                    
                    if (alive _crate) then { 
                        deleteVehicle _crate; 
                    };
                    
                    // Nettoyer le fumigène vert initial
                    if (!isNull _smokeGreen) then { deleteVehicle _smokeGreen; };
                    
                    // Nettoyage des fumigènes blancs après 2 minutes
                    sleep 120;
                    { if (!isNull _x) then { deleteVehicle _x; }; } forEach _smokes;
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
        _wpCAS setWaypointBehaviour "COMBAT";
        _wpCAS setWaypointCombatMode "RED";
        _wpCAS setWaypointSpeed "LIMITED";
        
        _heli doMove _dropPos;

        // Attendre que l'hélicoptère atteigne la zone de loiter avant de commencer le timer
        waitUntil {
            sleep 1;
            !alive _heli || {(_heli distance2D _dropPos) < (_loiterRadius + 150)}
        };

        if (alive _heli) then {
            private _endTime = time + 180; // Reste 3 minutes (180 secondes)
            private _lastReveal = 0;

            while {time < _endTime && alive _heli} do {
                sleep 1;
                if (!alive _heli) exitWith {};

                if (time - _lastReveal > 5) then {
                    _lastReveal = time;
                    private _targets = allUnits select { alive _x && {side _x == east} && {_x distance2D _dropPos < 500} };
                    {
                        _group reveal [_x, 4];
                    } forEach _targets;
                };
            };
        };

        // Supprimer proprement tous les waypoints de ce groupe pour éviter les conflits d'IA
        while { count (waypoints _group) > 0 } do {
            deleteWaypoint [_group, 0];
        };
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
            deleteMarker _markerName;
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

            // Pools d'équipements identiques à fn_initPlayerLoadout.sqf
            private _vests = [
                "CUP_V_JPC_medical_coy",
                "CUP_V_JPC_tl_coy",
                "CUP_V_JPC_weapons_coy",
                "CUP_V_JPC_communicationsbelt_coy",
                "CUP_V_JPC_Fastbelt_coy",
                "CUP_V_JPC_lightbelt_coy",
                "CUP_V_JPC_medicalbelt_coy",
                "CUP_V_JPC_tlbelt_coy",
                "CUP_V_JPC_weaponsbelt_coy"
            ];
            private _helmets = [
                "CUP_H_OpsCore_Tan_SF",
                "CUP_H_OpsCore_Tan",
                "CUP_H_OpsCore_Tan_NohS",
                "CUP_H_OpsCore_Grey_SF",
                "CUP_H_OpsCore_Grey",
                "CUP_H_OpsCore_Grey_NohS"
            ];
            private _backpacks = [
                "CUP_B_AssaultPack_Coyote",
                "B_assaultPack_cbr",
                "B_Kitbag_cbr"
            ];
            private _uniforms = [
                "CUP_U_B_USMC_MCCUU_des_gloves",
                "CUP_U_B_USMC_MCCUU_des_roll_2",
                "CUP_U_B_USMC_MCCUU_des_roll_2_gloves",
                "CUP_U_B_USMC_MCCUU_des_roll_pads",
                "CUP_U_B_USMC_MCCUU_des_roll_2_pads_gloves",
                "CUP_U_B_USMC_MCCUU_des_pads",
                "CUP_U_B_USMC_MCCUU_des_pads_gloves",
                "CUP_U_B_USMC_MCCUU_des_roll",
                "CUP_U_B_USMC_MCCUU_des_roll_gloves",
                "CUP_U_B_USMC_MCCUU_des_roll_pads",
                "CUP_U_B_USMC_MCCUU_des_roll_pads_gloves",
                "CUP_U_B_USMC_MCCUU_des"
            ];
            private _cagoules = [
                "CUP_G_Tan_Scarf_Shades_GPSCombo_Beard",
                "CUP_G_Tan_Scarf_Shades_GPS_Beard",
                "CUP_G_Tan_Scarf_GPS",
                "CUP_G_TK_RoundGlasses_blk",
                "CUP_G_Oakleys_Drk",
                "CUP_G_Scarf_Face_Tan",
                "G_Aviator",
                "CUP_G_ESS_KHK_Scarf_Tan_GPS_Beard",
                "CUP_G_ESS_KHK_Facewrap_Tan",
                "G_Bandana_khk"
            ];

            private _fn_addMagsForWeapon = {
                params ["_unit", "_weapon", "_magCount"];
                if (_weapon == "") exitWith {};
                private _compatibleMags = getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines");
                if (count _compatibleMags > 0) then {
                    private _targetMag = _compatibleMags select 0;
                    for "_i" from 1 to _magCount do {
                        _unit addItem _targetMag;
                    };
                };
            };

            {
                private _unitType = _x;
                private _unit = _infGroup createUnit [_unitType, _dropPos, [], 0, "NONE"];

                // --- 1. Attribution du loadout similaire aux joueurs ---
                private _selectedUniform = selectRandom _uniforms;
                private _selectedBackpack = selectRandom _backpacks;
                private _selectedHelmet = selectRandom _helmets;
                private _selectedCagoule = selectRandom _cagoules;
                
                private _selectedVest = "";
                if (_unitType == "CUP_I_RACS_Soldier_Medic") then {
                    private _medVests = _vests select { (_x find "medical") != -1 };
                    _selectedVest = if (count _medVests > 0) then { selectRandom _medVests } else { selectRandom _vests };
                } else {
                    if (_unitType == "CUP_I_RACS_Soldier_SL") then {
                        private _tlVests = _vests select { (_x find "_tl") != -1 };
                        _selectedVest = if (count _tlVests > 0) then { selectRandom _tlVests } else { selectRandom _vests };
                    } else {
                        _selectedVest = selectRandom _vests;
                    };
                };

                removeUniform _unit;
                removeVest _unit;
                removeBackpack _unit;
                removeHeadgear _unit;
                removeGoggles _unit;

                _unit forceAddUniform _selectedUniform;
                [_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
                _unit addVest _selectedVest;
                _unit addBackpack _selectedBackpack;
                _unit addHeadgear _selectedHelmet;
                _unit addGoggles _selectedCagoule;

                _unit linkItem "NVGogglesB_blk_F";
                
                private _currentBinoc = binocular _unit;
                if (_currentBinoc != "") then {
                    _unit removeWeapon _currentBinoc;
                };
                _unit addWeapon "CUP_LRTV";

                // Munitions de manière dynamique en fonction des armes équipées (qui restent d'origine)
                [_unit, primaryWeapon _unit, 5] call _fn_addMagsForWeapon;
                [_unit, handgunWeapon _unit, 3] call _fn_addMagsForWeapon;
                [_unit, secondaryWeapon _unit, 2] call _fn_addMagsForWeapon;

                // Équipements de soin, grenades et fumigènes
                for "_i" from 1 to 3 do { _unit addItem "FirstAidKit"; };
                for "_i" from 1 to 3 do { _unit addItem "CUP_HandGrenade_M67"; };
                for "_i" from 1 to 3 do { _unit addItem "SmokeShell"; };

                if (_unitType == "CUP_I_RACS_Soldier_Medic") then {
                    _unit addItemToBackpack "Medikit";
                };

                // --- 2. Attribution de l'identité et de la voix (cohérentes avec fn_initPlayerIdentity.sqf) ---
                private _allNamesTyped = missionNamespace getVariable ["LL_g_allNamesTyped", []];
                if (_allNamesTyped isEqualTo []) then {
                    private _names_turkish = [
                        ["Mustafa Demir", "Mustafa", "Demir"], ["Ahmet Yılmaz", "Ahmet", "Yılmaz"], ["Mehmet Kaya", "Mehmet", "Kaya"],
                        ["Emre Şahin", "Emre", "Şahin"], ["Can Öztürk", "Can", "Öztürk"], ["Hakan Yıldırım", "Hakan", "Yıldırım"],
                        ["Oğuzhan Çelik", "Oğuzhan", "Çelik"], ["Kaan Arslan", "Kaan", "Arslan"], ["Burak Koç", "Burak", "Koç"],
                        ["Volkan Aydın", "Volkan", "Aydın"], ["Onur Özdemir", "Onur", "Özdemir"]
                    ];
                    private _names_arab = [
                        ["Mehdi Benali", "Mehdi", "Benali"], ["Sofiane Haddad", "Sofiane", "Haddad"], ["Karim Mansouri", "Karim", "Mansouri"],
                        ["Mohamed Trabelsi", "Mohamed", "Trabelsi"], ["Walid Belkacem", "Walid", "Belkacem"], ["Hicham Bouzid", "Hicham", "Bouzid"],
                        ["Adel Gharbi", "Adel", "Gharbi"], ["Nassim Saïdi", "Nassim", "Saïdi"], ["Rachid Ziani", "Rachid", "Ziani"],
                        ["Adam Khayat", "Adam", "Khayat"], ["Rayane Meriah", "Rayane", "Meriah"]
                    ];
                    private _names_african = [
                        ["Moussa Diallo", "Moussa", "Diallo"], ["Mamadou Traoré", "Mamadou", "Traoré"], ["Ibrahim Keita", "Ibrahim", "Keita"],
                        ["Sekou Diop", "Sekou", "Diop"], ["Ousmane Sy", "Ousmane", "Sy"], ["Bakary Sow", "Bakary", "Sow"],
                        ["Ismaël Koné", "Ismaël", "Koné"], ["Kofi Mensah", "Kofi", "Mensah"], ["Amadi Achebe", "Amadi", "Achebe"],
                        ["Jengo Okeke", "Jengo", "Okeke"], ["Kwame Nkrumah", "Kwame", "Nkrumah"]
                    ];
                    private _names_indonesian = [
                        ["Budi Santoso", "Budi", "Santoso"], ["Joko Widodo", "Joko", "Widodo"], ["Agus Harjono", "Agus", "Harjono"],
                        ["Slamet Rahardjo", "Slamet", "Rahardjo"], ["Wawan Setiawan", "Wawan", "Setiawan"], ["Hendra Wijaya", "Hendra", "Wijaya"],
                        ["Eko Prasetyo", "Eko", "Prasetyo"], ["Aditya Nugroho", "Aditya", "Nugroho"], ["Rian Hidayat", "Rian", "Hidayat"],
                        ["Aris Budiman", "Aris", "Budiman"], ["Dedi Kusnadi", "Dedi", "Kusnadi"]
                    ];
                    { _allNamesTyped pushBack [_x, "Turkish"]; } forEach _names_turkish;
                    { _allNamesTyped pushBack [_x, "Arab"]; } forEach _names_arab;
                    { _allNamesTyped pushBack [_x, "African"]; } forEach _names_african;
                    { _allNamesTyped pushBack [_x, "Indonesian"]; } forEach _names_indonesian;
                };
                private _usedNames = missionNamespace getVariable ["LL_g_usedPlayerNames", []];
                private _availableNames = _allNamesTyped select { !((_x select 0 select 0) in _usedNames) };
                if (_availableNames isEqualTo []) then { _usedNames = []; _availableNames = _allNamesTyped; };
                private _nameEntry = selectRandom _availableNames;
                private _nameData = _nameEntry select 0;
                private _faceType = _nameEntry select 1;
                _usedNames pushBackUnique (_nameData select 0);
                missionNamespace setVariable ["LL_g_usedPlayerNames", _usedNames, true];

                // Visage cohérent avec l'origine du nom
                private _faces = switch (_faceType) do {
                    case "Turkish";
                    case "Arab":      { ["PersianHead_A3_01","PersianHead_A3_02","PersianHead_A3_03",
                                       "GreekHead_A3_01","GreekHead_A3_02","GreekHead_A3_03",
                                       "GreekHead_A3_04","GreekHead_A3_05","GreekHead_A3_06"] };
                    case "African":   { ["AfricanHead_01","AfricanHead_02","AfricanHead_03"] };
                    case "Indonesian": { ["AsianHead_A3_01","AsianHead_A3_02","AsianHead_A3_03",
                                        "TanoanHead_A3_01","TanoanHead_A3_02","TanoanHead_A3_03",
                                        "TanoanHead_A3_04","TanoanHead_A3_05"] };
                    default         { ["WhiteHead_01","WhiteHead_02","WhiteHead_03","WhiteHead_04",
                                       "WhiteHead_05","WhiteHead_06","WhiteHead_07","WhiteHead_08",
                                       "WhiteHead_09","WhiteHead_10","WhiteHead_11","WhiteHead_12",
                                       "WhiteHead_13","WhiteHead_14","WhiteHead_15","WhiteHead_16",
                                       "WhiteHead_17","WhiteHead_18","WhiteHead_19","WhiteHead_20",
                                       "WhiteHead_21"] };
                };
                private _face = selectRandom _faces;

                // Voix de joueur aléatoire (Américain, Britannique, Altis) avec pitch
                private _speakers = [
                    "Male01ENG", "Male02ENG", "Male03ENG", "Male04ENG", "Male05ENG",
                    "Male01ENGB", "Male02ENGB", "Male03ENGB", "Male04ENGB", "Male05ENGB",
                    "Male01GRE", "Male02GRE", "Male03GRE", "Male04GRE", "Male05GRE"
                ];
                private _speaker = selectRandom _speakers;
                private _pitch = 0.85 + random 0.15;

                // Application JIP-safe via remoteExec
                private _beard = "";
                [_unit, _nameData, _face, _speaker, _pitch, _beard] remoteExec ["LL_fnc_applyIdentity", 0, _unit];

                // Stockage global + drapeau sur l'unité
                _unit setVariable ["LL_s_identity", [_nameData, _faceType, _face, _speaker, _pitch, _beard], true];
                _unit setVariable ["LL_IdentitySet", true, true];

                // Assigner également un grade cohérent
                if (_unitType == "CUP_I_RACS_Soldier_SL") then { _unit setUnitRank "SERGEANT"; } else {
                    if (_unitType == "CUP_I_RACS_Soldier_Medic") then { _unit setUnitRank "CORPORAL"; } else {
                        _unit setUnitRank "PRIVATE";
                    };
                };

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

            if (alive _heli) then {
                private _allHumanPlayers = allPlayers select { alive _x };
                private _playersInHeli = crew _heli select { _x in _allHumanPlayers };
                if (count _playersInHeli > 0) then {
                    _victoryTriggered = true;
                    deleteMarker _markerName;

                    // Décollage de l'hélicoptère
                    _heli setVariable ["TAG_Heli_CurrentDestination", _homeBase, true];
                    _heli flyInHeight _flyHeight;
                    private _wpHome = _group addWaypoint [_homeBase, 0];
                    _wpHome setWaypointType "MOVE";
                    _wpHome setWaypointBehaviour "COMBAT";
                    _wpHome setWaypointCombatMode "RED";
                    _wpHome setWaypointSpeed "FULL";
                    _heli doMove _homeBase;

                    // Rendre les joueurs et les alliés invisibles
                    private _unitsToHide = (crew _heli) - _crew;
                    {
                        _x hideObjectGlobal true;
                    } forEach _unitsToHide;

                    // Verrouiller l'hélicoptère
                    _heli lock 2;

                    // Attendre 25 secondes
                    sleep 25;

                    // Lancer la fin de mission
                    if (alive _heli) then {
                        ["MissionSuccess", true, true] remoteExec ["BIS_fnc_endMission", 0];
                    };
                };
            };
        };
    };

    if (!_victoryTriggered) then {
        deleteMarker _markerName;
        // --- PHASE 3 : RETOUR ET DESPAWN ---
        if (_supportType == "CAS") then {
            (localize "STR_TAG_Msg_CAS_RTB") remoteExec ["systemChat", _caller];
        };
        sleep 2;
        
        // Supprimer proprement tous les waypoints existants pour éviter les conflits d'IA
        while { count (waypoints _group) > 0 } do {
            deleteWaypoint [_group, 0];
        };

        _heli setVariable ["TAG_Heli_CurrentDestination", _homeBase, true];
        _heli flyInHeight _flyHeight;
        
        private _wpHome = _group addWaypoint [_homeBase, 0];
        _wpHome setWaypointType "MOVE";
        _wpHome setWaypointBehaviour "COMBAT";
        _wpHome setWaypointCombatMode "RED";
        _wpHome setWaypointSpeed "FULL";
        _group setCurrentWaypoint _wpHome;
        _heli doMove _homeBase;
        
        // Libération immédiate du verrou pour que le joueur puisse demander une autre action
        missionNamespace setVariable ["TAG_AirSupport_Active", false, true];
        
        private _returnTime = time;
        waitUntil {
            sleep 5;
            (_heli distance2D _homeBase < 200) || !alive _heli || (time - _returnTime > 180)
        };
        
        if (alive _heli) then {
            // Extraction finale : si des joueurs sont à bord au retour, c'est un succès de mission (fallback au cas où)
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
    };
    
    missionNamespace setVariable ["LL_missionHelicopter", objNull, true];
};
