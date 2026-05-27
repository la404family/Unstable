#include "..\macros.hpp"

/*
    LL_fnc_task02b_addAction

    Description:
      Ajoute l'addAction de libération de l'informateur sur son corps (il est à genoux, captif).
      Appelée via remoteExec depuis le serveur (LL_fnc_task02b) dès le spawn de l'informateur.

    Params:
      0: OBJECT — l'unité informateur

    Locality:
      CLIENT — exécutée sur tous les clients via remoteExec [..., 0]
*/

if (!hasInterface) exitWith {};

params [["_hostage", objNull, [objNull]]];

if (isNull _hostage) exitWith {};

// Anti-double-déclenchement (TASK_RULES §5)
if (missionNamespace getVariable ["LL_Task02b_ActionAdded", false]) exitWith {};
missionNamespace setVariable ["LL_Task02b_ActionAdded", true];

_hostage addAction [
    format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_02b_Free"], // Jaune — TASK_RULES §5
    {
        params ["_target", "_caller", "_actionId", "_arguments"];

        // Anti-double-pickup (TASK_RULES §5)
        if (missionNamespace getVariable ["LL_Task02b_Freed", false]) exitWith {};

        // Supprimer l'action immédiatement sur ce client
        _target removeAction _actionId;

        // Jouer l'animation de libération sur toutes les machines
        [_target, "Acts_ExecutionVictim_Unbow"] remoteExec ["playMove", 0]; // CORRECTIF #2 : playMove pour one-shot (TASK_ANIM §1)

        // Délai animation (~8s) puis notification globale
        [_target] spawn {
            params ["_h"];
            sleep 8;
            missionNamespace setVariable ["LL_Task02b_Freed", true, true];
            if (DEBUG_MODE) then {
                diag_log "[LL][task02b_addAction] Informateur libéré — variable globale définie.";
            };
        };
    },
    [],
    10,    // Priorité
    true,  // showWindow
    true,  // hideOnUse
    "",    // Shortcut
    "alive _target && (_this distance _target) < 3 && !(missionNamespace getVariable ['LL_Task02b_Freed', false])",
    3      // Distance maximale d'interaction (TASK_RULES §5)
];
