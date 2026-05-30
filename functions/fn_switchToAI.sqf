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

// Signaler à toutes les machines que ce joueur est en cours de basculement
// (évite un faux checkGameOver pendant la fenêtre de transfert de localité)
_deadUnit setVariable ["LL_Switching_To_AI", true, true];

// Petit délai pour laisser l'animation de mort se dérouler et le moteur se mettre à jour
sleep 3;

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

    // Déclencher une vérification de fin de partie côté serveur (en multi uniquement)
    if (isMultiplayer) then {
        [] remoteExec ["LL_fnc_checkGameOver", 2];
    };

    // ── MODE SOLO : fin de mission directe ──────────────────────────────────
    // IMPORTANT : on utilise spawn au lieu de exitWith car exitWith dans un
    // contexte spawn ne permet pas les sleep, ce qui empêchait la destruction
    // de la caméra et causait un gel total du jeu (clavier bloqué).
    if (!isMultiplayer) then {
        _deadUnit setVariable ["LL_Spectating", false, true];

        [_deadUnit] spawn {
            params ["_unit"];

            // 1. Caméra vue de haut proche — contempler la scène de mort
            private _cam = "camera" camCreate (getPos _unit vectorAdd [0, 0, 5]);
            _cam camSetTarget _unit;
            _cam cameraEffect ["INTERNAL", "BACK"];
            _cam camCommit 0;
            showCinemaBorder false;

            // 2. Laisser le joueur voir la scène pendant 4 secondes
            sleep 4;

            // 3. DÉTRUIRE la caméra AVANT d'appeler endMission
            //    C'est critique : BIS_fnc_endMission entre en conflit avec
            //    une caméra custom active et gèle le jeu si elle est encore là.
            _cam cameraEffect ["TERMINATE", "BACK"];
            camDestroy _cam;

            // 4. Petit délai pour laisser le moteur nettoyer la caméra
            sleep 0.5;

            // 5. Lancer la fin de mission native (écran FAILED + contrôle clavier)
            //    Le 3ème paramètre (secondes de fondu) est à 3 pour un fondu rapide.
            ["MissionFailed", false, 3] call BIS_fnc_endMission;

            if (DEBUG_MODE) then {
                diag_log "[LL] switchToAI: Mode solo — fin de mission native déclenchée avec caméra.";
            };
        };
    };

    // ── MODE MULTIJOUEUR : spectateur avec caméras valides ──────────────────
    if (isMultiplayer) then {
        // Caméras : [0=libre, 1=première personne, 2=troisième personne]
        // Les deux derniers flags (endMissionButton, spectatorList) passent à false/true
        // pour ne pas bloquer l'affichage de la fin de mission déclenchée par le serveur.
        ["Initialize", [player, [0,1,2], true, true, false, false, false, false, false, true]] call BIS_fnc_EGSpectator;

        if (DEBUG_MODE) then {
            diag_log "[LL] switchToAI: Aucune IA disponible. Spectateur activé. Surveillance du groupe démarrée.";
        };

        // ── Prévention du gel critique (Bug Arma 3) et Transition Immersive ─────
        // BIS_fnc_EGSpectator et BIS_fnc_endMission entrent en conflit.
        // Dès que la fin est annoncée, on coupe le spectateur INSTANTANÉMENT
        // et on active une caméra vue de haut pour contempler la scène.
        [_deadUnit] spawn {
            params ["_unit"];
            waitUntil { missionNamespace getVariable ["MISSION_ended", false] };
            
            // 1. Couper le spectateur immédiatement (évite tout conflit UI)
            ["Terminate"] call BIS_fnc_EGSpectator;
            
            // 2. Lancer la caméra immersive vue de haut
            private _cam = "camera" camCreate (getPos _unit vectorAdd [0, 0, 5]);
            _cam camSetTarget _unit;
            _cam cameraEffect ["INTERNAL", "BACK"];
            _cam camCommit 0;
            showCinemaBorder false;

            // 3. Le serveur attend 2s puis lance un fondu de 5s (total 7s).
            // On attend 6.8s pour que l'écran soit complètement noir.
            sleep 6.8;
            
            // 4. On détruit la caméra juste pour que le débriefing s'affiche proprement
            _cam cameraEffect ["TERMINATE", "BACK"];
            camDestroy _cam;
        };

        // ── Double vérification (Sécurité 30s) ──────────────────────────────────
        // Si la mission ne s'est toujours pas terminée après 30 secondes (bug réseau ou serveur),
        // et qu'il n'y a plus aucun joueur en vie, on force la fin et on rétablit le HUD.
        [] spawn {
            sleep 30;
            private _alivePlayers = allPlayers select { alive _x || _x getVariable ["LL_Switching_To_AI", false] };
            // Si aucun joueur en vie et que la mission n'a pas déclenché d'écran de fin
            if (count _alivePlayers == 0) then {
                if (DEBUG_MODE) then {
                    diag_log "[LL] switchToAI: TIMEOUT CRITIQUE 30s ATTEINT — Aucun joueur en vie, forçage de la fin !";
                };
                
                // Forcer la fermeture du spectateur au cas où
                ["Terminate"] call BIS_fnc_EGSpectator;
                
                // Lancer la fin de mission locale sans aucun délai
                ["MissionFailed", false, 0] call BIS_fnc_endMission;
            };
        };

        // ── Surveiller l'arrivée de nouvelles IA ────────────────────────────────
        // Permet au joueur en spectateur de reprendre le contrôle automatiquement
        // si de nouveaux renforts arrivent (ex : hélicoptère DEBARQUEMENT).
        // Timeout de 300 s pour éviter une loop orpheline si la mission se termine.
        private _watchGroup = _group;
        private _watchDead  = _deadUnit;
        [_watchGroup, _watchDead] spawn {
            params ["_grp", "_dead"];

            private _watchEnd = time + 300;
            waitUntil {
                sleep 5;
                private _availableAI = (units _grp) select { alive _x && !isPlayer _x };
                (count _availableAI > 0) || (time > _watchEnd)
                    || (missionNamespace getVariable ["MISSION_ended", false])
            };

            // Sortie par timeout ou fin de mission → ne rien faire
            if (time > _watchEnd || missionNamespace getVariable ["MISSION_ended", false]) exitWith {};

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
};
