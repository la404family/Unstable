#include "..\macros.hpp"

/*
 * LL_fnc_switchToAI
 *
 * Description:
 *   Permet à un joueur de basculer sur le contrôle d'une IA vivante de son groupe lors de sa mort.
 *   N'affiche aucun systemChat en cas de réussite.
 *
 * Locality:
 *   Client uniquement (hasInterface)
 */

params [
    ["_deadUnit", objNull, [objNull]]
];

if (!hasInterface) exitWith {};

private _group = group _deadUnit;
if (isNull _group) exitWith {};

// Petit délai pour laisser l'animation de mort se dérouler et le moteur se mettre à jour
sleep 3;

// Signaler à toutes les machines que ce joueur est en cours de basculement
// (évite un faux checkGameOver pendant la fenêtre de transfert de localité)
_deadUnit setVariable ["LL_Switching_To_AI", true, true];

// Trouver toutes les IA vivantes du groupe (unités non-joueurs)
private _livingAI = (units _group) select { alive _x && {!isPlayer _x} };

if (count _livingAI > 0) then {
    private _targetAI = selectRandom _livingAI;
    
    // Demander au serveur de transférer la propriété de l'IA (ou du groupe) vers ce client
    [_targetAI, clientOwner] remoteExec ["LL_fnc_transferLocality", 2];
    
    // Attendre que l'IA devienne locale pour nous (avec un timeout de sécurité de 5 secondes)
    private _timeout = time + 5;
    waitUntil { local _targetAI || time > _timeout };

    // Retirer le flag de basculement (succès ou timeout, le résultat est connu ici)
    _deadUnit setVariable ["LL_Switching_To_AI", false, true];

    if (local _targetAI) then {
        // Prendre le contrôle de la nouvelle IA
        selectPlayer _targetAI;
        
        // Retirer le Respawn EH du corps original (_deadUnit) pour éviter
        // qu'Arma 3 ne respawn l'ancienne unité et ne duplique le Killed EH.
        _deadUnit removeAllEventHandlers "Respawn";
        
        // Une IA ne doit jamais être leader s'il y a un joueur.
        // Si le leader actuel n'est pas un joueur (ex: une IA), le joueur prend le commandement.
        if (!isPlayer (leader _group)) then {
            _group selectLeader _targetAI;
        };
        
        // Attacher l'Event Handler "Killed" au nouveau corps pour que le système se répète en cas de mort future
        player addEventHandler ["Killed", {
            params ["_unit", "_killer", "_instigator", "_useEffects"];
            
            if (leader (group _unit) == _unit) then {
                [group _unit, _unit] remoteExec ["LL_fnc_manageLeadership", 2];
            };
            
            [_unit] spawn LL_fnc_switchToAI;
        }];
        
        if (DEBUG_MODE) then {
            diag_log format ["[LL] switchToAI: Joueur a basculé vers %1", name _targetAI];
        };
    } else {
        // En cas de bug réseau/timeout de localité, on affiche un message d'erreur
        systemChat localize "STR_LL_Msg_Switch_Error";
        diag_log format ["[LL][ERROR] switchToAI: Échec du transfert de localité pour %1 (timeout)", _targetAI];
    };
} else {
    // Aucune IA disponible pour le basculement.

    // Retirer le flag de basculement
    _deadUnit setVariable ["LL_Switching_To_AI", false, true];

    // Marquer ce corps comme spectateur actif (rend les addActions visibles même mort)
    _deadUnit setVariable ["LL_Spectating", true, true];

    // Empêcher le respawn natif Arma 3 (le mettre à un temps infini)
    setPlayerRespawnTime 999999;

    // Activer le mode spectateur (Standard Arma 3)
    ["Initialize", [player, [], true]] call BIS_fnc_EGSpectator;

    // Déclencher une vérification de fin de partie côté serveur
    [] remoteExec ["LL_fnc_checkGameOver", 2];

    if (DEBUG_MODE) then {
        diag_log "[LL] switchToAI: Aucune IA disponible. Spectateur activé. Surveillance du groupe démarrée.";
    };

    // Surveiller l'arrivée de nouvelles IA dans le groupe (ex : renforts hélicoptère DEBARQUEMENT).
    // Permet au joueur en spectateur de reprendre le contrôle automatiquement sans intervention manuelle.
    private _watchGroup = _group;
    private _watchDead  = _deadUnit;
    [_watchGroup, _watchDead] spawn {
        params ["_grp", "_dead"];

        waitUntil {
            sleep 5;
            private _availableAI = (units _grp) select { alive _x && !isPlayer _x };
            count _availableAI > 0
        };

        if (DEBUG_MODE) then {
            diag_log "[LL] switchToAI: Nouvelle IA détectée — sortie du spectateur et reprise.";
        };

        // Retirer le flag spectateur
        _dead setVariable ["LL_Spectating", false, true];

        // Sortir du mode spectateur
        ["Terminate"] call BIS_fnc_EGSpectator;

        // Retenter le basculement vers la nouvelle IA disponible
        [_dead] spawn LL_fnc_switchToAI;
    };
};
