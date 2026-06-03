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

if (!isServer) exitWith {};

// Anti-doublon — une seule instance côté serveur
if (missionNamespace getVariable ["LL_Task04_Started", false]) exitWith {};
missionNamespace setVariable ["LL_Task04_Started", true, true];

[] spawn {
    sleep 5; // Petite pause après la fin de la tâche 03
    
    // Création de la tâche d'extraction
    [
        independent,
        ["task_04_exfil"],
        [
            "Le commandement envoie un hélicoptère pour vous extraire. Maintenez la position et montez à bord dès qu'il atterrit pour terminer la mission.",
            "Extraction",
            "Zone d'atterrissage"
        ],
        objNull,
        "AUTOASSIGNED",
        5,
        true,
        "heli"
    ] call BIS_fnc_taskCreate;

    // Trouver le joueur principal (ou leader) pour l'atterrissage
    private _targetPlayer = objNull;
    {
        if (isPlayer _x && { alive _x }) exitWith { _targetPlayer = _x; };
    } forEach allPlayers;

    if (!isNull _targetPlayer) then {
        // Envoi avec priorité 2 (Mission) : force le retour d'un éventuel hélicoptère actif (ex: CAS) pour lancer l'extraction
        ["EMBARQUEMENT", getPos _targetPlayer, _targetPlayer, 2] call LL_fnc_heliDispatch;
    };
};
