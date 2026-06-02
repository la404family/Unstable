// ============================================================================
// initPlayerLocal.sqf — Initialisation client (exécuté sur chaque client avec interface)
// ============================================================================
#include "macros.hpp"

// --- Cinématique d'introduction (partie client) ---
// Doit être le premier appel pour bloquer les contrôles joueur dès le départ.
[] spawn LL_fnc_intro;

// Lancement de l'initialisation de l'identité joueur (JIP-safe).
// Attend la diffusion des données de l'identité par le serveur et l'applique
// localement sur le personnage pour forcer le nom, le visage et la voix.
[] call LL_fnc_initPlayer;

// ── Application continue des noms RACS (setName LOCAL + counter-sync réseau) ──
// Cause racine confirmée : Arma 3 re-synchronise les noms de profil Steam
// depuis chaque client propriétaire vers toutes les machines, à intervalles
// irréguliers (réseau interne). Un setName ponctuel est écrasé 2-5 s plus tard.
//
// Solution : boucle continue sur ce client (sleep 2 s) qui ré-applique setName
// pour TOUS les membres du groupe — players distants ET player local.
// Arma ne peut pas "gagner la course" si on ré-applique avant la prochaine sync.
//
// Note : setFace / setSpeaker / setPitch ne sont PAS soumis à la même sync réseau
// → appliqués une seule fois dès réception de LL_s_identity.
[] spawn {
    // Attente que le serveur ait assigné et diffusé l'identité pour notre unité
    waitUntil {
        sleep 1;
        count (player getVariable ["LL_s_identity", []]) >= 5
    };

    // Application unique du visage, voix et pitch (pas de re-sync Arma pour ces attributs)
    private _ownId = player getVariable ["LL_s_identity", []];
    _ownId params ["_ownName", "_ownFaceType", "_ownFace", "_ownSpeaker", "_ownPitch", ["_ownBeard", "", [""]]];
    if (_ownFace    != "") then { player setFace    _ownFace    };
    if (_ownSpeaker != "") then { player setSpeaker _ownSpeaker };
    if (_ownPitch    > 0)  then { player setPitch   _ownPitch   };

    // Boucle continue : ré-applique setName pour tous les membres du groupe
    // (player local + players distants dont le nom serait re-sync par le moteur)
    while { alive player } do {
        {
            private _id = _x getVariable ["LL_s_identity", []];
            if (count _id >= 1) then {
                private _nd = _id select 0;
                if (count _nd >= 3) then {
                    _x setName [_nd select 0, _nd select 1, _nd select 2];
                };
            };
        } forEach units group player;
        sleep 2;
    };
};

// Ajout de l'action permettant d'ordonner aux IA du groupe de se soigner
[] spawn LL_fnc_addHealAction;

// Ajout des actions pour définir les règles d'engagement (RoE) de l'escouade
[] spawn LL_fnc_addRoeActions;

// Ajout de l'action pour ordonner la fouille des bâtiments aux IA
[] spawn LL_fnc_addSearchAction;

// Ajout de l'action pour forcer le regroupement des IA coincées
[] spawn LL_fnc_addRallyAction;

// Les actions de demande de support hélicoptère (Chinook RACS)
[] spawn LL_fnc_addHelicopterActions;

// L'action de demande de surveillance drone (MQ-9)
[] spawn LL_fnc_addDroneAction;

// ── Garantie items obligatoires (côté client — contourne les délais de propagation réseau)
// Le serveur applique vest/backpack en effets globaux AVANT d'envoyer addMagazine (effet local).
// En partie hébergée ou dédiée, la vest peut ne pas être encore enregistrée côté client
// au moment où fn_applyLocalLoadout tente d'y insérer les magazines.
// Ce bloc attend que LL_LoadoutSet soit confirmé, puis injecte directement les items
// sur le client propriétaire de l'unité — garanti local, aucune dépendance réseau.
[] spawn {
    waitUntil { sleep 1; player getVariable ["LL_LoadoutSet", false] };
    sleep 0.5; // laisser fn_applyLocalLoadout terminer son écriture

    // Fumigènes blancs — 2 par joueur
    private _smokes = magazines player select { _x == "SmokeShellWhite" };
    private _missing = 2 - count _smokes;
    if (_missing > 0) then {
        for "_i" from 1 to _missing do { player addMagazine "SmokeShellWhite"; };
    };

    // Grenades M67 — 2 par joueur
    private _m67 = magazines player select { _x == "HandGrenade" };
    private _missingM67 = 2 - count _m67;
    if (_missingM67 > 0) then {
        for "_i" from 1 to _missingM67 do { player addMagazine "HandGrenade"; };
    };

    // Lance-roquettes M72A6 — uniquement si désigné par le serveur
    if (player getVariable ["LL_GiveLauncher", false]) then {
        if (secondaryWeapon player != "CUP_launch_M72A6_Special") then {
            player addWeapon "CUP_launch_M72A6_Special";
        };
        // Ajouter les roquettes compatibles si manquantes
        private _sMags = ["CUP_launch_M72A6_Special"] call BIS_fnc_compatibleMagazines;
        if (count _sMags > 0) then {
            private _sMag = _sMags select 0;
            private _existing = magazines player select { _x == _sMag };
            private _missingMags = 2 - count _existing;
            if (_missingMags > 0) then {
                for "_i" from 1 to _missingMags do { player addMagazine _sMag; };
            };
        };
    };

    if (DEBUG_MODE) then {
        diag_log format ["[LL][initPlayerLocal] Items garantis appliqués — fumigènes: %1, M67: %2, launcher: %3",
            count (magazines player select { _x == "SmokeShellWhite" }),
            count (magazines player select { _x == "HandGrenade" }),
            player getVariable ["LL_GiveLauncher", false]
        ];
    };
};
// --- Système de basculement vers une IA du groupe en cas de mort ---
player addEventHandler ["Killed", {
    params ["_unit", "_killer", "_instigator", "_useEffects"];
    
    // Si l'unité décédée était le leader, réassigner immédiatement
    if (leader (group _unit) == _unit) then {
        [group _unit, _unit] remoteExec ["LL_fnc_manageLeadership", 2];
    };
    
    [_unit] spawn LL_fnc_switchToAI;
}];

player addEventHandler ["Respawn", {
    params ["_newUnit", "_oldUnit"];
    
    // Réattacher l'Event Handler Killed sur le nouveau corps après respawn normal
    _newUnit addEventHandler ["Killed", {
        params ["_unit", "_killer", "_instigator", "_useEffects"];
        
        if (leader (group _unit) == _unit) then {
            [group _unit, _unit] remoteExec ["LL_fnc_manageLeadership", 2];
        };
        
        [_unit] spawn LL_fnc_switchToAI;
    }];
}];

// ══════════════════════════════════════════════════════════════════════════════
// WATCHDOG SOLO — Boucle de surveillance indépendante (filet de sécurité)
// Ne dépend PAS de la chaîne de Killed EH. Vérifie en continu si TOUTES
// les unités jouables sont mortes. Si oui → fin de mission forcée.
// En multijoueur ce rôle est rempli par fn_checkGameOver côté serveur.
// ══════════════════════════════════════════════════════════════════════════════
if (!isMultiplayer) then {
    [] spawn {
        // Attendre que la mission soit bien démarrée
        sleep 15;

        while { true } do {
            sleep 3;

            // Sortie si la mission est déjà terminée
            if (missionNamespace getVariable ["MISSION_ended", false]) exitWith {};

            // Vérifier toutes les unités jouables (pas seulement le groupe actuel)
            private _anyAlive = false;
            {
                if (alive _x) exitWith { _anyAlive = true; };
            } forEach playableUnits;

            // Fallback: vérifier aussi le joueur actuel
            if (!_anyAlive && alive player) then { _anyAlive = true; };

            // Un basculement IA est peut-être en cours, ne pas interrompre
            if (!_anyAlive) then {
                private _switching = false;
                {
                    if (_x getVariable ["LL_Switching_To_AI", false]) exitWith { _switching = true; };
                } forEach (allPlayers + allDeadMen);
                if (_switching) then { _anyAlive = true; };
            };

            if (!_anyAlive) then {
                diag_log "[LL] WATCHDOG SOLO: Aucune unité jouable en vie. Fin de mission forcée.";
                missionNamespace setVariable ["MISSION_ended", true];
                sleep 2;
                endMission "MissionFailed";
            };
        };
    };
};
