#include "..\macros.hpp"

/*
    Author: La Légion
    Description:
      Tâche 00 — Embarquement.
      Crée la première tâche de la mission : le leader et tous les joueurs
      doivent monter dans le véhicule allié (vehicule_team) pour débuter
      les opérations. La tâche passe à SUCCEEDED dès que tous les joueurs
      vivants sont à bord.
      Affiche un message de QG localisé sous forme de sous-titres à la création.

    Parameter(s):
      None

    Returns:
      None

    Locality:
      Server only (isServer)
*/

if (!isServer) exitWith {};

// ── Notification de début QG ──────────────────────────────────────────────────
// Envoie le message radio de QG aux joueurs sous forme de sous-titres
["STR_LL_Speaker_Narrator", "STR_LL_Task_00_Narrative_Start"] remoteExec ["LL_fnc_showSubtitle", 0];

// ── Création de la tâche ──────────────────────────────────────────────────────
[
    independent,
    ["task_00_embark"],
    [
        localize "STR_LL_Task_00_Desc",
        localize "STR_LL_Task_00_Title",
        localize "STR_LL_Task_00_Marker"
    ],
    getPosATL vehicule_team,
    "AUTOASSIGNED",
    5,
    true,
    "move"
] call BIS_fnc_taskCreate;

if (DEBUG_MODE) then {
    diag_log "[LL] task00: Tâche d'embarquement créée pour le camp indépendant.";
};

// ── Surveillance de complétion ──────────────────────────────────────────────
[] spawn {
    private _initialVehicle = missionNamespace getVariable ["vehicule_team", objNull];

    // Attendre que tous les joueurs vivants soient à bord du véhicule d'origine ou du véhicule de remplacement
    waitUntil {
        sleep 2;

        // Collecter les joueurs vivants indépendants
        private _alivePlayers = allPlayers select { alive _x && (side _x == independent) };

        // Si personne de vivant, éviter un faux positif — attendre
        if (count _alivePlayers == 0) exitWith { false };

        // Vrai si chaque joueur vivant est bien passager ou conducteur d'un des véhicules autorisés
        private _notBoarded = _alivePlayers select { 
            private _veh = vehicle _x;
            _veh != _initialVehicle && _veh != (missionNamespace getVariable ["vehicule_team", objNull])
        };

        (count _notBoarded == 0)
    };

    // Tous à bord — succès
    ["task_00_embark", "SUCCEEDED", true] call BIS_fnc_taskSetState;

    if (DEBUG_MODE) then {
        diag_log "[LL] task00: Tous les joueurs sont embarqués — tâche réussie.";
    };
};
