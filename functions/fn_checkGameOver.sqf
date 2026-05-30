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
    // Attendre un court instant pour s'assurer que les requêtes réseau de basculement (LL_Switching_To_AI)
    // ont bien été reçues par le serveur. Le délai de 3s de l'animation est maintenant couvert en amont.
    sleep 1;

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

        // Signaler à tous les clients que la mission se termine
        MISSION_ended = true;
        publicVariable "MISSION_ended";

        // DÉLAI CRITIQUE : Laisser 2 secondes aux clients pour désactiver proprement
        // le mode spectateur (BIS_fnc_EGSpectator) et lancer la caméra immersive.
        // Si on n'attend pas, l'écran de débriefing entre en conflit avec le spectateur et gèle le jeu !
        sleep 2;

        // Fin de mission (défaite)
        ["MissionFailed", false, 5] remoteExec ["BIS_fnc_endMission", 0];
    };
};