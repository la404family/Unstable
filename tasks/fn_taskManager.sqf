#include "..\macros.hpp"

/*
    Author: RACS
    Description:
      Gestionnaire central des tâches de mission.
      Crée, assigne et enchaîne les tâches de la mission.
      Doit être appelé uniquement sur le serveur depuis initServer.sqf.

    Parameter(s):
      None

    Returns:
      None

    Locality:
      Server only (isServer)
*/

if (!isServer) exitWith {};

// Définir le propriétaire des tâches sur la faction indépendante (les joueurs)
private _owner = independent;

if (DEBUG_MODE) then {
    diag_log "[LL] taskManager: Démarrage du gestionnaire de tâches.";
};

// ── Tâche 00 — Embarquement ──────────────────────────────────────────────────
[] call LL_fnc_task00;
waitUntil {
    sleep 5;
    (["task_00_embark"] call BIS_fnc_taskState) in ["SUCCEEDED", "FAILED", "CANCELED"]
};

if (DEBUG_MODE) then {
    diag_log "[LL] taskManager: Tâche 00 terminée, lancement de la tâche 01.";
};

// ── Tâche 01 — Rendez-vous de reconnaissance ──────────────────────────────────
[] call LL_fnc_task01;
waitUntil {
    sleep 5;
    (["task_01_recon"] call BIS_fnc_taskState) in ["SUCCEEDED", "FAILED", "CANCELED"]
};

// ── Fin de la mission ────────────────────────────────────────────────────────
private _task1State = ["task_01_recon"] call BIS_fnc_taskState;

if (DEBUG_MODE) then {
    diag_log format ["[LL] taskManager: Tâche 01 terminée avec l'état : %1. Déclenchement de la fin de mission.", _task1State];
};

if (_task1State == "SUCCEEDED") then {
    sleep 8; // Laisser le temps aux joueurs de lire les derniers sous-titres
    ["MissionSuccess", true, true] remoteExec ["BIS_fnc_endMission", 0];
} else {
    sleep 8; // Laisser le temps aux joueurs de lire les derniers sous-titres
    ["MissionFailed", false, true] remoteExec ["BIS_fnc_endMission", 0];
};
