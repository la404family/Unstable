#include "..\macros.hpp"

/*
    LL_fnc_task03a_addAction

    Description:
      Ajoute l'action radio "Demander l'extraction" disponible pour les joueurs
      après que les véhicules ennemis de la tâche 03a ont été neutralisés.
      Un seul joueur suffit à déclencher l'extraction pour tout le groupe.

    Locality:
      Client uniquement (hasInterface)
      Appelé via remoteExec depuis fn_task03a.sqf (serveur)
*/

if (!hasInterface) exitWith {};

player addAction [
    format ["<t color='#00FF00'>%1</t>", localize "STR_LL_Task_03a_Extraction_Request"],
    {
        params ["_target", "_caller", "_id"];

        // Anti-double déclenchement
        if (missionNamespace getVariable ["LL_Task03a_ExtractionCalled", false]) exitWith {};
        _caller removeAction _id;

        // Diffusion globale (serveur + tous les clients)
        missionNamespace setVariable ["LL_Task03a_ExtractionCalled", true, true];

        // Confirmation locale à tous les joueurs via systemChat
        [localize "STR_LL_Task_03a_Extraction_Called"] remoteExec ["systemChat", 0];
    },
    [],     // Paramètres
    8,      // Priorité
    true,   // Actif au démarrage
    true,   // Disponible en véhicule
    "",     // Condition de shortcut
    "!(missionNamespace getVariable ['LL_Task03a_ExtractionCalled', false])"  // Condition d'affichage
];
