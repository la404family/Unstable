#include "..\macros.hpp"

/*
 * LL_fnc_checkGameOver
 *
 * Description:
 *   Vérifie si tous les joueurs connectés sont morts simultanément.
 *   Si oui, déclenche la fin de mission (défaite).
 *   Ajoute un délai de sécurité pour laisser le temps aux basculements IA de se terminer.
 *
 * Locality:
 *   Serveur uniquement — appelé via remoteExec [..., 2]
 */

if (!isServer) exitWith {};

[] spawn {
    // Attendre que les scripts switchToAI des clients aient fini leur travail (sleep 3 + selectPlayer)
    // Cela évite de terminer la mission alors qu'un joueur est en train de prendre le contrôle d'une IA.
    sleep 5;

    // Exclure les Headless Clients de la liste des joueurs
    private _allPlayers = allPlayers - entities "HeadlessClient_F";

    // Compter les joueurs encore actifs :
    // un joueur est "actif" s'il est vivant OU si son basculement vers une IA est encore en cours
    private _alivePlayers = _allPlayers select {
        alive _x || { _x getVariable ["LL_Switching_To_AI", false] }
    };

    if (count _allPlayers > 0 && { count _alivePlayers == 0 }) then {
        if (DEBUG_MODE) then {
            diag_log "[LL] checkGameOver: Tous les joueurs sont morts. Fin de mission déclenchée.";
        };

        // Fin de mission (défaite)
        ["MissionFailed", false, 5] remoteExec ["BIS_fnc_endMission", 0];
    };
};