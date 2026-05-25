#include "..\macros.hpp"

/*
    LL_fnc_task02a_addAction

    Description:
      Ajoute l'addAction de ramassage des documents top secret sur le corps du chef
      détenteur. Appelée via remoteExec depuis le serveur (LL_fnc_task02a) après
      la mort du détenteur.

    Params:
      0: OBJECT — corps du chef détenteur
      1: OBJECT — objet document (Land_Document_01_F) à supprimer après ramassage

    Locality:
      CLIENT — exécutée sur tous les clients via remoteExec [..., 0]
*/

if (!hasInterface) exitWith {};

params [
    ["_body",   objNull, [objNull]],
    ["_docObj", objNull, [objNull]]
];

if (isNull _body) exitWith {};

// Anti-double-déclenchement : empêcher l'ajout de l'action plusieurs fois (TASK_RULES §5)
if (missionNamespace getVariable ["LL_Task02a_ActionAdded", false]) exitWith {};
missionNamespace setVariable ["LL_Task02a_ActionAdded", true];

_body addAction [
    format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_02a_Pickup"], // Jaune — TASK_RULES §5
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        _arguments params ["_doc"];

        // Anti-double-pickup : ignorer si déjà ramassé (TASK_RULES §5)
        if (missionNamespace getVariable ["LL_Task02a_DocPickedUp", false]) exitWith {};

        // Supprimer l'action immédiatement
        _target removeAction _actionId;

        // Notifier tout le réseau — le serveur détecte via waitUntil
        missionNamespace setVariable ["LL_Task02a_DocPickedUp", true, true];

        // Supprimer l'objet document du sol
        if (!isNull _doc) then { deleteVehicle _doc; };

        if (DEBUG_MODE) then {
            diag_log "[LL][task02a_addAction] Documents top secret récupérés.";
        };
    },
    [_docObj],  // Arguments transmis au callback
    10,         // Priorité
    true,       // showWindow
    true,       // hideOnUse
    "",         // Shortcut
    "(_this distance _target) < 4", // Distance d'interaction — TASK_RULES §5
    4
];
