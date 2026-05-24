// ============================================================================
// initServer.sqf — Initialisation serveur (exécuté uniquement sur le serveur)
// ============================================================================

diag_log "[LL][initServer] Démarrage de l'initialisation serveur...";

// --- 0. Configuration du Respawn (Tickets à 0 pour vie unique) ---
[independent, 0] call BIS_fnc_respawnTickets;
[west, 0] call BIS_fnc_respawnTickets;

// Charge les templates d'apparence civile depuis l'éditeur et nettoie la carte
[] call LL_fnc_initCivilians;

// Boucle principale de spawn et de dépop des civils autour des joueurs
[] spawn LL_fnc_spawnCivilianPresence;


// --- 2. Groupement et Initialisation des joueurs/IA ---
// On force tout le monde dans le même groupe AVANT d'appliquer les identités et loadouts.
[] spawn {
    waitUntil { time > 0 };
    private _leaderUnit = missionNamespace getVariable ["player_00", objNull];
    if (!isNull _leaderUnit) then {
        private _grp = group _leaderUnit;
        {
            private _unit = missionNamespace getVariable [format ["player_0%1", _x], objNull];
            if (!isNull _unit && _unit != _leaderUnit) then {
                [_unit] joinSilent _grp;
            };
        } forEach [1,2,3,4,5,6];
    };

    // Attendre un court instant pour que le regroupement soit effectif
    sleep 1;

    // Assigne les grades et l'apparence Légion aux slots player_00 ... player_06
    [] call LL_fnc_initPlayerIdentity;

    // Assigne les sacs (CUP Tactical Pack CCE) et l'armement initial
    [] call LL_fnc_initPlayerLoadout;
};

// Assigne un leader parmi les joueurs humains et surveille qu'une IA ne le devienne jamais
[] spawn LL_fnc_assignLeader;


// --- 3. Ambiance & Mécaniques de jeu ---
// Boucle de lecture de l'appel à la prière depuis les haut-parleurs (ezan_XX)
[] spawn LL_fnc_playEzan;

// Boucle de contrôle des portes de bâtiments proches des IA non-BLUFOR
[] spawn LL_fnc_doorSecurity;

// --- 4. Démarrage du gestionnaire de tâches (Task Manager) ---
[] spawn LL_fnc_taskManager;

diag_log "[LL][initServer] Initialisation serveur terminée.";
