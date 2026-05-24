#include "..\macros.hpp"

/*
 * LL_fnc_checkGameOver
 *
 * Description:
 *   Vérifie si tous les joueurs connectés sont morts simultanément.
 *   Si oui, déclenche la fin de mission (défaite) avant l'expiration
 *   du respawnDelay Arma 3 (10 s).
 *   Ne doit pas être appelé si une IA vivante reste disponible pour le basculement.
 *
 * Locality:
 *   Serveur uniquement — appelé via remoteExec [..., 2]
 */

if (!isServer) exitWith {};

// Exclure les Headless Clients de la liste des joueurs
private _allPlayers = allPlayers - entities "HeadlessClient_F";

// Compter les joueurs encore en vie
private _alivePlayers = _allPlayers select { alive _x };

if (count _allPlayers > 0 && { count _alivePlayers == 0 }) then {
    if (DEBUG_MODE) then {
        diag_log "[LL] checkGameOver: Tous les joueurs sont morts. Fin de mission déclenchée.";
    };

    // Court délai dramatique (3 s) avant l'écran de défaite,
    // bien inférieur au respawnDelay (10 s) pour éviter tout respawn.
    [] spawn {
        sleep 3;
        ["LOSER", false, 0] call BIS_fnc_endMission;
    };
};