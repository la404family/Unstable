#include "..\macros.hpp"

/*
    LL_fnc_task02c_addAction

    Description:
      Gère deux addActions pour la tâche 02c :
        - "chief"   : "Interroger le chef de milice" — déclenche le dialogue
                      de renseignement sur le serveur.
        - "capture" : "Maîtriser l'intermédiaire" — capture l'intermédiaire
                      financier côté client, puis notifie le serveur.

    Params:
      0: STRING  — mode ("chief" ou "capture")
      1: OBJECT  — la cible concernée (chef ou intermédiaire)

    Locality:
      CLIENT — exécutée sur tous les clients via remoteExec [..., 0]
*/

if (!hasInterface) exitWith {};

params [
    ["_mode", "chief", [""]],
    ["_unit", objNull, [objNull]]
];

if (isNull _unit) exitWith {};

switch (_mode) do {



    // ── Mode "capture" : addAction "Maîtriser l'intermédiaire" ───────────────
    case "capture": {

        // Anti-double instanciation (TASK_RULES §5)
        if (missionNamespace getVariable ["LL_Task02c_CaptureAdded", false]) exitWith {};
        missionNamespace setVariable ["LL_Task02c_CaptureAdded", true];

        _unit addAction [
            format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_02c_Capture"], // Jaune — TASK_RULES §5
            {
                params ["_target", "_caller", "_id", "_args"];

                // Anti-double déclenchement (TASK_RULES §5)
                if (missionNamespace getVariable ["LL_Task02c_Captured", false]) exitWith {};
                _target removeAction _id;

                // Déléguer l'animation et le changement d'état au serveur
                // (le serveur a la locality de l'unité — switchMove fiable)
                ["capture_anim", [_target]] remoteExec ["LL_fnc_task02c", 2];
            },
            [],
            10,   // Priorité
            true, // showWindow
            true, // hideOnUse
            "",   // Raccourci
            "alive _target && (_this distance _target) < 4 && !(missionNamespace getVariable ['LL_Task02c_Captured', false])",
            4     // Distance d'interaction (TASK_RULES §5)
        ];
    };
};
