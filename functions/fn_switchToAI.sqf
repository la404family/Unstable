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

    // Déclencher une vérification de fin de partie côté serveur
    [] remoteExec ["LL_fnc_checkGameOver", 2];

    // ── MODE SOLO : fin de mission directe ──────────────────────────────────
    // BIS_fnc_EGSpectator avec une liste de caméras vide [] cause un gel complet
    // de l'interface en partie solo (HUD perdu, clavier bloqué, aucune issue).
    // En solo il n'y a qu'un seul joueur : on crée une caméra vue de haut au-dessus
    // du cadavre (clavier accessible, ESC fonctionnel), puis on déclenche la fin de mission.
    if (!isMultiplayer) exitWith {
        _deadUnit setVariable ["LL_Spectating", false, true];

        // Caméra vue de haut — 15 m au-dessus du cadavre
        // Créée AVANT le titleText pour éviter l'écran noir bloquant ("BLACK FADED")
        private _cam = "camera" camCreate (getPos _deadUnit vectorAdd [0, 0, 15]);
        _cam camSetTarget _deadUnit;
        _cam cameraEffect ["INTERNAL", "BACK"];
        _cam camCommit 0;
        showCinemaBars false;

        // Message en bas d'écran — style PLAIN pour ne pas superposer de fond noir
        titleText [localize "STR_LL_Msg_GameOver", "PLAIN DOWN", 2];

        // Laisser le joueur voir la scène et accéder au menu (ESC) pendant 8 s
        sleep 8;

        // Nettoyage caméra avant l'écran de débrief
        _cam cameraEffect ["TERMINATE", "BACK"];
        camDestroy _cam;
        titleText ["", "PLAIN", 0];

        ["MissionFailed", false, 0] call BIS_fnc_endMission;

        if (DEBUG_MODE) then {
            diag_log "[LL] switchToAI: Mode solo — caméra overhead + fin de mission (aucune IA disponible).";
        };
    };

    // ── MODE MULTIJOUEUR : spectateur avec caméras valides ──────────────────
    // Caméras : [0=libre, 1=première personne, 2=troisième personne]
    // Les deux derniers flags (endMissionButton, spectatorList) passent à false/true
    // pour ne pas bloquer l'affichage de la fin de mission déclenchée par le serveur.
    ["Initialize", [player, [0,1,2], true, true, false, false, false, false, false, true]] call BIS_fnc_EGSpectator;

    if (DEBUG_MODE) then {
        diag_log "[LL] switchToAI: Aucune IA disponible. Spectateur activé. Surveillance du groupe démarrée.";
    };

    // ── Timeout de sécurité ─────────────────────────────────────────────────
    // Si checkGameOver ou BIS_fnc_endMission ne déclenchent pas la fin dans les 15 s,
    // on force la sortie de mission pour éviter un blocage permanent.
    [] spawn {
        sleep 15;
        if (!(missionNamespace getVariable ["MISSION_ended", false])) then {
            if (DEBUG_MODE) then {
                diag_log "[LL] switchToAI: Timeout de sécurité atteint — fin de mission forcée.";
            };
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
