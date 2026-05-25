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
private _task1State    = ["task_01_recon"] call BIS_fnc_taskState;
private _task1Scenario = missionNamespace getVariable ["LL_g_task01_scenario", 0];

if (DEBUG_MODE) then {
    diag_log format ["[LL] taskManager: Tâche 01 terminée. État : %1 | Scénario : %2.", _task1State, _task1Scenario];
};

// ── Suite de la mission : lancement de task04a / task04b / task04c ────────────
// La fin de mission n'est JAMAIS déclenchée ici (TASK_RULES §7).
// L'extraction hélicoptère reste le seul déclencheur de BIS_fnc_endMission.
// TODO : décommenter quand les fonctions task04x seront créées.
 switch (_task1Scenario) do {
     case 1: { [] call LL_fnc_task02a; }; // Coopération         → Intel reçu
    case 2: { [] call LL_fnc_task02b; }; // Trahison            → Renseignements perdus
     case 3: {
         if (_task1State == "SUCCEEDED") then {
             [] call LL_fnc_task02c;      // Mutinerie (chef vivant) → Exfiltration chef
         } else {
            [] call LL_fnc_task02b;      // Mutinerie (chef mort)   → Renseignements perdus (= Trahison)
         };
     };
 };
