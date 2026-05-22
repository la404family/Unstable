#include "..\macros.hpp"

/*
    Author: La Légion
    Description:
      Ajoute l'action d'interaction "Parler au chef de milice" sur le client local.
      Appelée via remoteExec depuis le serveur (fn_task01) sur toutes les machines
      ayant une interface (hasInterface). Le callback de l'action déclenche le
      scénario sur le serveur en ré-appelant LL_fnc_task01 en mode "scenario".

    Parameter(s):
      0: <OBJECT> Le chef de milice
      1: <ARRAY>  Les gardes
      2: <STRING> ID du marqueur de tâche

    Returns:
      None

    Locality:
      Client only (hasInterface)
*/

if (!hasInterface) exitWith {};

params [
    ["_chief",    objNull, [objNull]],
    ["_guards",   [],      [[]]],
    ["_markerID", "",      [""]]
];

if (isNull _chief) exitWith {};

// Ajout de l'action d'interaction localisée
_chief addAction [
    format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_01_Action"],
    {
        params ["_target", "_caller", "_id", "_args"];
        _args params ["_guards", "_markerID"];

        // Anti-double déclenchement
        if (missionNamespace getVariable ["LL_Task01_Triggered", false]) exitWith {};
        missionNamespace setVariable ["LL_Task01_Triggered", true, true];

        _target removeAction _id;

        // Choix aléatoire d'un scénario (1, 2 ou 3) et exécution sécurisée sur le serveur
        private _scen = 1 + floor (random 3);
        ["scenario", [_scen, _target, _guards, _markerID]] remoteExec ["LL_fnc_task01", 2];
    },
    [_guards, _markerID], // Arguments passés au callback
    10,                   // Priorité
    true,                 // showWindow
    true,                 // hideOnUse
    "",                   // Raccourci
    "alive _target && _this distance _target < 4", // Condition de visibilité
    4                     // Distance d'interaction
];
