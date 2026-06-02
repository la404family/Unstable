#include "..\macros.hpp"

/*
 * LL_fnc_task04
 *
 * Description:
 *   Attend 5 minutes (300s) puis lance automatiquement la demande d'extraction.
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
    // Attendre 5 minutes (300 secondes)
    sleep 300;
    
    // Pour éviter de spammer le serveur si plusieurs joueurs sont connectés, 
    // seul le leader de l'escouade envoie la requête d'extraction.
    if (player isEqualTo leader group player) then {
        ["EMBARQUEMENT", getPos player, player, player, -1] remoteExec ["LL_fnc_requestHelicopter", 2];
    };
};
