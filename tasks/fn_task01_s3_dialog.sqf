#include "..\macros.hpp"

/*
    Author: La Légion
    Description:
      Dialogue final avec le chef de milice (Scénario 3) pour valider task01
      et passer à task02c en donnant les coordonnées exactes du financier.

    Locality: Server
*/

params [
    ["_chief", objNull, [objNull]],
    ["_caller", objNull, [objNull]]
];

if (!isServer) exitWith {};
if (isNull _chief) exitWith {};

// Le chef se tourne vers le joueur
private _dir = _chief getDir _caller;
_chief setDir _dir;

// Animation fluide pour parler
[_chief, "Acts_CivilTalking_1"] remoteExec ["switchMove", 0];
[_chief, true] remoteExec ["setRandomLip", 0]; // Fait bouger les lèvres pour simuler la parole

// --- SIMULATION DE LA VRAIE VOIX NATIVE ---
private _grp = group _chief;
private _dummy = _grp createUnit ["I_G_Soldier_F", getPos _chief, [], 0, "NONE"];
_dummy hideObjectGlobal true;
_dummy allowDamage false;
_dummy disableAI "ALL";
_grp selectLeader _chief;

// Force l'audio natif
_dummy commandMove (_chief getPos [1500, random 360]);

["STR_LL_Speaker_Chief", "Merci de m'avoir sauvé ! Mes gardes m'ont trahi pour l'argent du cartel..."] remoteExec ["LL_fnc_showSubtitle", 0];
sleep 5;

// Deuxième ordre audio natif
_dummy commandMove (_chief getPos [2000, random 360]);

["STR_LL_Speaker_Chief", "L'intermédiaire qui les a payés se cache. Je vais vous donner ses coordonnées exactes, trouvez-le et capturez-le !"] remoteExec ["LL_fnc_showSubtitle", 0];
sleep 5;

deleteVehicle _dummy; // Nettoyage du faux soldat

// Remise à zéro de l'animation en douceur et arrêt des lèvres
[_chief, ""] remoteExec ["switchMove", 0];
[_chief, false] remoteExec ["setRandomLip", 0];

// Le chef annonce son départ
["STR_LL_Speaker_Chief", "Je dois me mettre à l'abri. Que Dieu soit avec vous !"] remoteExec ["LL_fnc_showSubtitle", 0];
sleep 3;

_chief enableAI "MOVE";
_chief enableAI "ANIM";
_chief setBehaviour "SAFE";
_chief setSpeedMode "FULL";
_chief setVariable ["LL_Task01_Escaping", true, true];

private _escapeGrp = createGroup [independent, true];
[_chief] joinSilent _escapeGrp;

[_chief, _escapeGrp] spawn {
    params ["_c", "_grp"];
    
    // Recherche d'un Game Logic M_Dans_Bat_XXX
    private _rawLogics = [];
    {
        if (_x select [0, 11] == "M_Dans_Bat_") then {
            private _val = missionNamespace getVariable [_x, objNull];
            if (!isNull _val) then { _rawLogics pushBack _val; };
        };
    } forEach (allVariables missionNamespace);

    private _farLogics = _rawLogics select { _x distance2D _c >= 200 };
    private _escapePos = if (count _farLogics > 0) then { getPos (selectRandom _farLogics) } else { getPos _c getPos [300, random 360] };

    while { count waypoints _grp > 0 } do { deleteWaypoint [_grp, 0]; };
    private _wp = _grp addWaypoint [_escapePos, 5];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "SAFE";

    waitUntil {
        sleep 1;
        !alive _c
        || (_c distance2D _escapePos <= 10)
    };

    if (alive _c) then {
        // Attente que les joueurs s'éloignent si besoin (immersion)
        waitUntil {
            sleep 2;
            !alive _c || {
                private _allFar = true;
                { if (_x distance2D _c <= 100) exitWith { _allFar = false; }; } forEach (allPlayers select { alive _x });
                _allFar
            }
        };
        if (alive _c) then { deleteVehicle _c; };
    };
    if (!isNull _grp) then { deleteGroup _grp; };
};

// Succès final de la tâche (Ceci débloque task02c via fn_taskManager)
["task_01_recon", "SUCCEEDED", true] call BIS_fnc_taskSetState;

if (DEBUG_MODE) then {
    diag_log "[LL] task01_s3_dialog: Fin du dialogue, task01 validée, transition vers task02c.";
};
