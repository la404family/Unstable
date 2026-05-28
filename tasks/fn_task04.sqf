#include "..\macros.hpp"

/*
 * LL_fnc_task04
 *
 * Description:
 *   Affiche un rappel d'extraction en bas de l'écran avec un bip sonore.
 *   Se répète 3 fois toutes les 2 minutes, puis s'arrête.
 *   Appelé depuis fn_task03a et fn_task03b à la fin de leur tâche principale.
 *
 * Locality:
 *   Client uniquement (hasInterface)
 */

if (!hasInterface) exitWith {};

// Anti-doublon — une seule instance par client
if (missionNamespace getVariable ["LL_Task04_Started", false]) exitWith {};
missionNamespace setVariable ["LL_Task04_Started", true];

[] spawn {
    for "_i" from 1 to 3 do {
        playSound "LL_extraction_bip";
        systemChat (localize "STR_LL_Task04_Remind");
        if (_i < 3) then { sleep 120; };
    };
};
