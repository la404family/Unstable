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

// Attendre le début de la mission et l'initialisation des joueurs
waitUntil { time > 0 };

// Délai de sécurité pour s'assurer du chargement des joueurs depuis le lobby
sleep 2;

private _players = allPlayers - entities "HeadlessClient_F";

if (count _players == 0) exitWith {
    // Si aucun joueur n'est connecté au démarrage (cas anormal en MP)
    diag_log "[LL][assignLeader] Erreur: Aucun joueur détecté au démarrage pour attribuer le rôle de leader.";
    [localize "STR_LL_Msg_AssignLeader_Error"] remoteExec ["systemChat", 0];
};

private _defaultLeader = missionNamespace getVariable ["player_00", objNull];
private _leaderSlotTaken = isPlayer _defaultLeader;

if (!_leaderSlotTaken && {count _players < 7}) then {
    private _newLeader = selectRandom _players;
    
    // Regrouper tous les joueurs sous le nouveau leader
    _players joinSilent _newLeader;
    (group _newLeader) selectLeader _newLeader;
    
    if (DEBUG_MODE) then {
        diag_log format ["[LL][assignLeader] Le leader par défaut (player_00) est absent. %1 a été désigné leader.", name _newLeader];
    };
} else {
    // Si player_00 est présent, on s'assure qu'il est bien le leader du groupe
    if (_leaderSlotTaken) then {
        private _grp = group _defaultLeader;
        if (leader _grp != _defaultLeader) then {
            _grp selectLeader _defaultLeader;
            if (DEBUG_MODE) then {
                diag_log "[LL][assignLeader] Restauration de player_00 en tant que leader du groupe.";
            };
        };
    } else {
        if (DEBUG_MODE) then {
            diag_log "[LL][assignLeader] Le slot leader est déjà pris ou tous les slots sont occupés.";
        };
    };
};

// Boucle de surveillance continue pour empêcher qu'une IA ne devienne leader (déconnexion, mort, etc.)
while {true} do {
    sleep 5;
    
    private _activePlayers = allPlayers - entities "HeadlessClient_F";
    private _livingPlayers = _activePlayers select { alive _x };
    
    if (count _livingPlayers > 0) then {
        // Identifier tous les groupes contenant au moins un joueur vivant
        private _playerGroups = [];
        {
            private _grp = group _x;
            if (!isNull _grp && !(_grp in _playerGroups)) then {
                _playerGroups pushBack _grp;
            };
        } forEach _livingPlayers;
        
        // S'assurer pour chaque groupe que le leader est un joueur et non une IA
        {
            private _grp = _x;
            private _currentLeader = leader _grp;
            if (!isPlayer _currentLeader) then {
                // Trouver les joueurs humains vivants dans ce groupe spécifique
                private _grpPlayers = units _grp select { isPlayer _x && alive _x };
                if (count _grpPlayers > 0) then {
                    private _newLeader = selectRandom _grpPlayers;
                    _grp selectLeader _newLeader;
                    if (DEBUG_MODE) then {
                        diag_log format ["[LL][assignLeader] Une IA était leader. Réassignation automatique du leader à %1.", name _newLeader];
                    };
                };
            };
        } forEach _playerGroups;
    };
};
