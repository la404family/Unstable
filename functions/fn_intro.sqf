#include "..\macros.hpp"

/*
    Author: La Légion
    Description:
      Cinématique d'introduction — Opération Royal Alliance.
      Se déclenche au lancement de la mission, AVANT fn_task00 (Embarquement).

      CORRECTION DOUBLE-EXECUTION : Cette fonction est spawné depuis initServer.sqf
      ET initPlayerLocal.sqf. Sur une machine solo/hébergée, les deux fichiers init
      tournent sur la même machine. Un verrou par section (MISSION_intro_sv /
      MISSION_intro_cl) garantit que chaque bloc ne s'exécute qu'UNE SEULE fois.

      Séquence cinématique (~65s) :
        Plan 1 (~15s) — Survol de Porto, cibles : M_Dans_Bat_XXX (bâtiments mission)
        Plan 2 (~6s)  — Carte contextuelle : lieu + année (fondu noir + texte)
        Plan 3 (~15s) — Intérieur CH-47F Chinook en vol (cargo arrière → cockpit)
        Plan 4 (~14s) — Orbite extérieure autour du Chinook en vol
        Plan 5 (~10s) — Vue plongeante sur l'héliport choisi pendant l'atterrissage
        Fin            — Restauration joueur, MISSION_intro_finished = true

      Musique : "00intro" → music/intro.ogg (CfgMusic dans description.ext)

      VARIABLES ÉDITEUR REQUISES :
        vehicule_team     — véhicule de départ RACS (repositionné près de l'héliport choisi)
        Heliport_000...   — héliports invisibles (au moins 1 requis pour la LZ)

      VARIABLES ÉDITEUR OPTIONNELLES :
        M_Dans_Bat_000... — game logic dans bâtiments (cibles caméra Plan 1)

    Locality:
      Dual — section isServer + section hasInterface, chacune protégée par un verrou.
*/

// ==================================================================================================
// PARTIE CLIENT — Cinématique caméra et effets visuels
// ==================================================================================================
if (hasInterface) then {
    if (missionNamespace getVariable ["MISSION_intro_cl", false]) exitWith {};
    missionNamespace setVariable ["MISSION_intro_cl", true];

    [] spawn {
        waitUntil { time > 0.1 };

        // ==========================================================================================
        // SECTION 1 : ÉCRAN NOIR IMMÉDIAT (avant sleep de synchronisation)
        // ==========================================================================================
        // Masquage immédiat pour éviter tout flash visuel/sonore au chargement.
        disableSerialization;

        cutText ["", "BLACK FADED", 999];
        0 fadeSound 0;
        showCinemaBorder true;
        disableUserInput true;

        waitUntil { !isNull player };
        player allowDamage false;

        // Failsafe : restauration forcée après 100s si le script plante
        [] spawn {
            sleep 100;
            disableUserInput false;
            disableUserInput true;
            disableUserInput false;
            player allowDamage true;
            showCinemaBorder false;
        };

        // Synchronisation — le serveur positionne les unités sous l'écran noir
        sleep 10;

        // ==========================================================================================
        // SECTION 2 : POST-PROCESSING
        // ==========================================================================================
        private _ppColor = ppEffectCreate ["ColorCorrections", 1500];
        _ppColor ppEffectEnable true;
        _ppColor ppEffectAdjust [
            1,
            0.95,
            0.05,
            [0.15, 0.15, 0.2, 0.0],
            [0.85, 0.85, 0.9, 0.6],
            [0.1, 0.1, 0.15, 0]
        ];
        _ppColor ppEffectCommit 0;

        private _ppGrain = ppEffectCreate ["FilmGrain", 2005];
        _ppGrain ppEffectEnable true;
        _ppGrain ppEffectAdjust [0.08, 0.9, 1, 0.08, 1, false];
        _ppGrain ppEffectCommit 0;

        // ==========================================================================================
        // SECTION 3 : COLLECTE DES CIBLES CAMÉRA
        // ==========================================================================================

        // Attendre la position LZ publiée par le serveur
        waitUntil { !isNil "MISSION_intro_lz" };
        private _lzPos = MISSION_intro_lz;

        // Collecte des bâtiments mission : M_Dans_Bat_000 → M_Dans_Bat_XXX
        // CORRECTIF : scan complet 0–99 sans exitWith — un gap ne bloque plus la collecte
        private _buildingTargets = [];
        for "_i" from 0 to 99 do {
            private _s = str _i;
            while { count _s < 3 } do { _s = "0" + _s };
            private _varName = format ["M_Dans_Bat_%1", _s];
            private _obj = missionNamespace getVariable [_varName, objNull];
            if (!isNull _obj) then { _buildingTargets pushBack _obj; };
        };
        if (count _buildingTargets == 0) then { _buildingTargets = [vehicule_team]; };

        // ==========================================================================================
        // SECTION 4 : MUSIQUE
        // ==========================================================================================
        0 fadeMusic 1;
        playMusic "Music_Intro";
        3 fadeSound 1;

        // ##########################################################################################
        // PLAN 1 : SURVOL DE PORTO — bâtiments mission aléatoires (15s)
        // CORRECTIF : selectRandom + angle polaire aléatoire — offset fixe (+180/-180) donnait
        //             toujours la même direction de survol quel que soit le bâtiment cible.
        // ##########################################################################################
        private _tgt1 = selectRandom _buildingTargets;
        private _pool2 = _buildingTargets - [_tgt1];
        private _tgt2 = if (count _pool2 > 0) then { selectRandom _pool2 } else { _tgt1 };

        private _pos1 = getPos _tgt1;
        private _pos2 = getPos _tgt2;

        // Angles et distances aléatoires — clé de la diversité visuelle
        private _ang1 = random 360;
        private _ang2 = random 360;
        private _dist1 = 140 + (random 90);
        private _dist2 = 100 + (random 80);
        private _h1 = 110 + (random 60);
        private _h2 = 90  + (random 60);

        private _camStartX = (_pos1 select 0) + _dist1 * sin _ang1;
        private _camStartY = (_pos1 select 1) + _dist1 * cos _ang1;
        private _camStartZ = (_pos1 select 2) + _h1;

        private _cam = "camera" camCreate [_camStartX, _camStartY, _camStartZ];
        _cam cameraEffect ["INTERNAL", "BACK"];

        _cam camSetPos [_camStartX, _camStartY, _camStartZ];
        _cam camSetTarget _tgt1;
        _cam camSetFov 0.50 + (random 0.15);
        _cam camCommit 0;
        waitUntil { camCommitted _cam };

        cutText ["", "BLACK IN", 2.5];

        // Glisse vers le second bâtiment sur la durée totale du plan
        _cam camSetPos [
            (_pos2 select 0) + _dist2 * sin _ang2,
            (_pos2 select 1) + _dist2 * cos _ang2,
            (_pos2 select 2) + _h2
        ];
        _cam camSetTarget _tgt2;
        _cam camCommit 15;

        sleep 3;  // 3s de vue pure

        // Carte 1 : Auteur (4s)
        titleText [
            format [
                "<t size='2.2' color='#e0e0e0' font='PuristaBold' shadow='2' align='center'>%1</t><br/>" +
                "<t size='1.0' color='#909090' font='PuristaLight' align='center' letterSpacing='0.15'>%2</t>",
                toUpper (localize "STR_LL_Intro_Author"),
                localize "STR_LL_Intro_Presents"
            ],
            "PLAIN", 1, true, true
        ];
        sleep 4;
        titleText ["", "PLAIN", 0.5];
        sleep 0.5;

        // Carte 2 : Titre (4s)
        titleText [
            format [
                "<t size='2.6' color='#ffffff' font='PuristaBold' shadow='2' align='center'>%1</t>",
                localize "STR_LL_Intro_Title"
            ],
            "PLAIN", 1, true, true
        ];
        sleep 4;
        titleText ["", "PLAIN", 0.5];

        // ##########################################################################################
        // PLAN 2 : CARTE DE CONTEXTE — lieu (en dur) + heure dynamique (~7s sur fond noir)
        // Typewriter : caractère par caractère, bip par lettre, texte blanc
        // ##########################################################################################
        cutText ["", "BLACK FADED", 1];
        sleep 1.5;

        // Heure de mission (définie par fn_randomWeather via setDate)
        private _p2h = date select 3;
        private _p2m = date select 4;
        private _p2time = format ["%1:%2",
            if (_p2h < 10) then {"0" + str _p2h} else {str _p2h},
            if (_p2m < 10) then {"0" + str _p2m} else {str _p2m}
        ];

        private _p2chars1 = toArray (localize "STR_LL_Intro_Location");
        private _p2chars2 = toArray (" - " + _p2time);
        private _p2built  = "";

        // ====================== TYPEWRITER CENTRÉ SANS CLIGNOTEMENT ======================

        _p2built = "";

        // Première partie
        {
            _p2built = _p2built + toString [_x];

            [
                format ["<t size='1.3' color='#ffffff' font='PuristaLight' align='center' shadow='2'>%1</t>", _p2built],
                -1,              // Position X (-1 = Centré horizontalement)
                0.35,            // Position Y
                5,               // Durée d'affichage (écrasée par chaque nouvel appel)
                0,               // Pas de Fade-In (effet machine à écrire net)
                0,               // Pas d'effet de glissement (Delta-Y)
                793              // Layer fixe pour éviter le clignotement / superposition
            ] spawn BIS_fnc_dynamicText;

            // Bip discret vanilla uniquement sur les caractères visibles (pas les espaces)
            if (_x != 32) then {
                playSound "readoutClick";
            };
            sleep 0.08;
        } forEach _p2chars1;


        // Deuxième partie (" - HH:MM" plus lent)
        {
            _p2built = _p2built + toString [_x];

            [
                format ["<t size='1.3' color='#ffffff' font='PuristaLight' align='center' shadow='2'>%1</t>", _p2built],
                -1,              // Position X
                0.35,            // Position Y
                5,               // Durée d'affichage
                0,               // Pas de Fade-In
                0,               // Pas de glissement
                793              // Même Layer fixe
            ] spawn BIS_fnc_dynamicText;

            if (_x != 32) then {
                playSound "readoutClick";
            };
            sleep 0.12;
        } forEach _p2chars2;


        // Fin de l'effet
        sleep 2.5;
        ["", -1, 0.35, 1, 0.5, 0, 793] spawn BIS_fnc_dynamicText;

        // ##########################################################################################
        // PLAN 3 : INTÉRIEUR DU CH-47F CHINOOK (15s)
        // ##########################################################################################
        waitUntil { !isNil "MISSION_intro_heli" && { !isNull MISSION_intro_heli } };
        private _camHeli = MISSION_intro_heli;

        if (isNull _camHeli) exitWith {
            _cam cameraEffect ["TERMINATE", "BACK"]; camDestroy _cam;
            ppEffectDestroy _ppColor; ppEffectDestroy _ppGrain;
            showCinemaBorder false; player allowDamage true;
            disableUserInput false; disableUserInput true; disableUserInput false;
            cutText ["", "BLACK IN", 2];
            missionNamespace setVariable ["MISSION_intro_finished", true, true];
        };

        // PP cargo — ambiance confinée, sombre
        _ppColor ppEffectAdjust [0.9, 0.85, 0.1, [0.3, 0.3, 0.35, 0.15], [0.65, 0.65, 0.75, 0.5], [0.15, 0.15, 0.25, 0.1]];
        _ppColor ppEffectCommit 1.5;
        _ppGrain ppEffectAdjust [0.18, 1.3, 1.2, 0.18, 1.2, false];
        _ppGrain ppEffectCommit 1.5;

        detach _cam;
        cutText ["", "BLACK FADED", 0.8];
        sleep 0.8;
        cutText ["", "BLACK IN", 1.2];

        // Caméra fond de cargo — CH-47F : Y=-1(fond), Z=-1.1 (hauteur siège parfait)
        _cam attachTo [_camHeli, [0, 1, -1.1]]; 
        _cam setVectorDirAndUp [[0, 1, 0], [0, 0, 1]];
        _cam camSetFov 0.80;
        _cam camCommit 0;

        sleep 15;  

        // ##########################################################################################
        // PLAN 4 : ORBITE EXTÉRIEURE AUTOUR DU CHINOOK (14s)
        // ##########################################################################################
        detach _cam;
        cutText ["", "BLACK FADED", 0.5];
        sleep 0.5;
        cutText ["", "BLACK IN", 1];

        // PP extérieur — ciel, plus lumineux
        _ppColor ppEffectAdjust [1, 1.0, -0.05, [0.15, 0.15, 0.2, 0.0], [0.85, 0.85, 0.9, 0.65], [0.1, 0.1, 0.15, 0]];
        _ppColor ppEffectCommit 1;
        _ppGrain ppEffectAdjust [0.04, 0.7, 0.8, 0.04, 0.8, false];
        _ppGrain ppEffectCommit 1;

        private _orbStartTime = time;
        private _orbDuration  = 14;

        while { time < _orbStartTime + _orbDuration } do {
            private _progress   = (time - _orbStartTime) / _orbDuration;
            private _angle      = -90 + (_progress * 150);   // -90° → +60°
            private _distance   = 35 - (_progress * 13);     // 35m → 22m
            private _heliPos    = getPosATL _camHeli;
            private _finalAngle = (getDir _camHeli) + _angle;

            _cam camSetPos [
                (_heliPos select 0) + (sin _finalAngle * _distance),
                (_heliPos select 1) + (cos _finalAngle * _distance),
                (_heliPos select 2) + 10
            ];
            _cam camSetTarget _camHeli;
            _cam camSetFov (0.80 - (_progress * 0.15));  // Zoom progressif
            _cam camCommit 0.4;
            sleep 0.1;
        };

        // ##########################################################################################
        // PLAN 5 : VUE PLONGEANTE SUR L'HÉLIPORT CHOISI (jusqu'au posé)
        // ##########################################################################################
        detach _cam;
        cutText ["", "BLACK FADED", 0.5];
        sleep 0.5;

        _cam camSetPos [
            (_lzPos select 0) + 30,
            (_lzPos select 1) - 80,
            (_lzPos select 2) + 40
        ];
        _cam camSetTarget _lzPos;
        _cam camSetFov 0.50;
        _cam camCommit 0;
        waitUntil { camCommitted _cam };

        cutText ["", "BLACK IN", 1];

        private _plan5Start = time;
        while { !isTouchingGround _camHeli && { (getPosATL _camHeli select 2) > 1 } } do {
            private _prog = ((time - _plan5Start) / 12) min 1;
            _cam camSetPos [
                (_lzPos select 0) + 30 + (sin (time * 0.8) * 8),
                (_lzPos select 1) - 80 + (cos (time * 0.8) * 8),
                (_lzPos select 2) + 40 - (_prog * 28)
            ];
            _cam camSetFov (0.50 + (_prog * 0.12));
            _cam camCommit 0.4;
            sleep 0.2;
        };

        // Écran NOIR INSTANTANÉ dès que l'hélico pose les roues — avant que le serveur
        // appelle moveOut et fasse apparaître les unités au sol.
        cutText ["", "BLACK FADED", 0];

        waitUntil { vehicle player == player };
        sleep 1;

        // ##########################################################################################
        // FIN : NETTOYAGE ET RESTAURATION
        // ##########################################################################################
        sleep 1;

        _cam cameraEffect ["TERMINATE", "BACK"];
        camDestroy _cam;
        ppEffectDestroy _ppColor;
        ppEffectDestroy _ppGrain;

        player switchCamera "INTERNAL";
        showCinemaBorder false;
        player allowDamage true;

        disableUserInput false;
        disableUserInput true;
        disableUserInput false;

        cutText ["", "BLACK IN", 3];

        [
            format [
                "<t size='1.7' color='#ffffff' font='PuristaBold' align='center'>%1</t><br/>" +
                "<t size='1.0' color='#bbbbbb' font='PuristaLight' align='center'>%2</t>",
                localize "STR_LL_Intro_MissionStart",
                localize "STR_LL_Intro_MissionStartSubtitle"
            ],
            -1, -1, 5, 1, 0, 793
        ] spawn BIS_fnc_dynamicText;

        missionNamespace setVariable ["MISSION_intro_finished", true, true];
    };
};

// ==================================================================================================
// PARTIE SERVEUR — Sélection héliport aléatoire, création Chinook, vol et atterrissage
// ==================================================================================================
if (isServer) then {
    if (missionNamespace getVariable ["MISSION_intro_sv", false]) exitWith {};
    missionNamespace setVariable ["MISSION_intro_sv", true];

    [] spawn {
        sleep 10;

        // ==========================================================================================
        // SÉLECTION ALÉATOIRE DE L'HÉLIPORT DE DESTINATION
        // ==========================================================================================
        private _heliports = [];
        for "_i" from 0 to 99 do {
            private _s = str _i;
            while { count _s < 3 } do { _s = "0" + _s };
            private _varName = format ["Heliport_%1", _s];
            if (isNil _varName) exitWith {};
            private _hp = missionNamespace getVariable [_varName, objNull];
            if (!isNull _hp) then { _heliports pushBack _hp; };
        };

        if (count _heliports == 0) then {
            _heliports = [vehicule_team];
            diag_log "[LL][intro] AVERTISSEMENT: Aucun Heliport_XXX trouvé — fallback vehicule_team.";
        };

        private _chosenHeliport = _heliports call BIS_fnc_selectRandom;
        private _destPos        = getPos _chosenHeliport;

        // Publier la LZ aux clients (utilisée pour le Plan 5 caméra)
        MISSION_intro_lz = _destPos;
        publicVariable "MISSION_intro_lz";

        // Repositionner vehicule_team : 15m devant l'héliport, même orientation
        vehicule_team setPos (_chosenHeliport getPos [15, getDir _chosenHeliport]);
        vehicule_team setDir (getDir _chosenHeliport);

        if (DEBUG_MODE) then {
            diag_log format ["[LL][intro] Héliport choisi: %1 pos: %2", _chosenHeliport, _destPos];
        };

        // ==========================================================================================
        // CRÉATION DU CH-47F CHINOOK RACS
        // ==========================================================================================
        // Départ 1300m de la LZ, direction aléatoire, altitude 200m
        private _startDir = random 360;
        private _startPos = _chosenHeliport getPos [1300, _startDir];
        _startPos set [2, 200];

        private _heli = createVehicle ["CUP_I_CH47F_RACS", _startPos, [], 0, "FLY"];
        _heli setPos _startPos;
        _heli setDir (_startPos getDir _destPos);
        _heli flyInHeight 150;
        _heli allowDamage false;

        MISSION_intro_heli = _heli;
        publicVariable "MISSION_intro_heli";

        if (DEBUG_MODE) then { diag_log "[LL][intro] CUP_I_CH47F_RACS créé et synchronisé."; };

        // ==========================================================================================
        // ÉQUIPAGE
        // ==========================================================================================
        createVehicleCrew _heli;
        private _crew = crew _heli;
        { _x allowDamage false; } forEach _crew;
        (group driver _heli) setBehaviour "CARELESS";
        (group driver _heli) setCombatMode "BLUE";

        // ==========================================================================================
        // EMBARQUEMENT DES JOUEURS ET DE LEURS I.A.
        // ==========================================================================================
        private _players = playableUnits;
        if (count _players == 0 && hasInterface) then { _players = [player]; };

        private _allUnitsToBoard = [];
        private _processedGroups = [];

        {
            private _grp = group _x;
            if !(_grp in _processedGroups) then {
                _processedGroups pushBack _grp;
                {
                    if (alive _x && !(_x in _allUnitsToBoard)) then { _allUnitsToBoard pushBack _x; };
                } forEach (units _grp);
            };
        } forEach _players;

        {
            if (alive _x && !(_x in _allUnitsToBoard)) then { _allUnitsToBoard pushBack _x; };
        } forEach _players;

        {
            _x moveInCargo _heli;
            if (vehicle _x == _x) then { _x moveInAny _heli; };
            _x assignAsCargo _heli;
        } forEach _allUnitsToBoard;

        sleep 1;

        // ==========================================================================================
        // PHASES DE VOL (synchronisées avec timeline caméra client)
        // ==========================================================================================
        // Plan 1 (15s) + Plan 2 (6s) = 21s en approche rapide
        _heli doMove _destPos;
        _heli flyInHeight 150;
        _heli limitSpeed 200;

        sleep 21;

        // Ouverture rampe — début Plan 3 (vue intérieure)
        [_heli, ["Ramp_Source", 1]] remoteExec ["animateSource", 0, true];
        _heli animateSource ["Ramp_Source", 1];
        sleep 5;   // Animation d'ouverture

        sleep 10;  // Plan 3 restant (15s total - 5s = 10s)

        // Ralentissement — Plan 4 (orbite 14s)
        _heli limitSpeed 110;
        sleep 14;

        // Atterrissage — Plan 5
        waitUntil { (_heli distance2D _chosenHeliport) < 200 };
        _heli land "GET OUT";
        waitUntil { (getPosATL _heli select 2) < 2 };
        sleep 1;

        // ==========================================================================================
        // DÉBARQUEMENT
        // ==========================================================================================
        private _unitsToDisembark   = [];
        private _processedGroupsDis = [];

        {
            private _grp = group _x;
            if !(_grp in _processedGroupsDis) then {
                _processedGroupsDis pushBack _grp;
                {
                    if (alive _x && vehicle _x == _heli && !(_x in _unitsToDisembark)) then {
                        _unitsToDisembark pushBack _x;
                    };
                } forEach (units _grp);
            };
        } forEach _players;

        private _unitIndex = 0;
        {
            moveOut _x;
            unassignVehicle _x;
            private _dir         = getDir _heli;
            private _dist        = 6 + (_unitIndex mod 3);
            private _angleOffset = 60 + (_unitIndex * 14);
            private _pos         = _heli getPos [_dist, _dir + _angleOffset];
            _pos set [2, 0];
            _x setPos _pos;
            _x setDir _dir;
            _unitIndex = _unitIndex + 1;
        } forEach _unitsToDisembark;

        _heli setVehicleLock "LOCKED";
        _heli lock true;
        sleep 2;

        // Fermer la rampe
        [_heli, ["Ramp_Source", 0]] remoteExec ["animateSource", 0, true];
        _heli animateSource ["Ramp_Source", 0];

        // ==========================================================================================
        // DÉPART DE L'HÉLICOPTÈRE
        // ==========================================================================================
        _heli land "NONE";
        _heli doMove (_destPos getPos [3000, _startDir]);
        _heli flyInHeight 200;
        _heli limitSpeed 300;

        sleep 70;
        { deleteVehicle _x } forEach _crew;
        deleteVehicle _heli;

        if (DEBUG_MODE) then { diag_log "[LL][intro] Hélicoptère supprimé."; };
    };
};
