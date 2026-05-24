#include "..\macros.hpp"

/*
 * LL_fnc_assignLeader
 *
 * Description:
 *   Assigne un leader parmi les joueurs humains si le slot du leader par défaut (player_00)
 *   n'est pas occupé par un joueur humain.
 *   De plus, s'assure en continu qu'une IA ne devienne jamais leader du groupe des joueurs,
 *   y compris en cours de mission (ex: mort ou déconnexion du leader).
 *
 * Locality:
 *   Serveur uniquement
 */

if (!isServer) exitWith {};

// Attendre le début de la mission
waitUntil { time > 0 };
sleep 2;

// Boucle de surveillance continue
while {true} do {
    sleep 5;
    
    private _activePlayers = allPlayers - entities "HeadlessClient_F";
    private _livingPlayers = _activePlayers select { alive _x };
    
    if (count _livingPlayers > 0) then {
        // On s'assure que tous les joueurs vivants sont dans le même groupe que le leader par défaut
        private _mainGrp = group (missionNamespace getVariable ["player_00", objNull]);
        if (!isNull _mainGrp) then {
            {
                if (group _x != _mainGrp) then {
                    [_x] joinSilent _mainGrp;
                };
            } forEach _livingPlayers;

            // Si le leader du groupe principal n'est pas un joueur, on en désigne un
            if (!isPlayer (leader _mainGrp)) then {
                private _newLeader = _livingPlayers select 0;
                _mainGrp selectLeader _newLeader;
            };
        };
    };
};
