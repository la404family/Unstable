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


// --- 2. Initialisation de l'identité et du loadout des joueurs ---
// Assigne les grades et l'apparence Légion aux slots player_00 ... player_06
[] call LL_fnc_initPlayerIdentity;

// Assigne les sacs (CUP Tactical Pack CCE) et l'armement initial
[] spawn LL_fnc_initPlayerLoadout;

// --- 2.5 Groupement de tous les joueurs ---
// Force tous les slots joueurs et leurs IA dans le même groupe (player_00)
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
};

// Assigne un leader parmi les joueurs humains et surveille qu'une IA ne le devienne jamais
[] spawn LL_fnc_assignLeader;


// --- 3. Ambiance & Mécaniques de jeu ---
// Boucle de lecture de l'appel à la prière depuis les haut-parleurs (ezan_XX)
[] spawn LL_fnc_playEzan;

// Boucle de contrôle des portes de bâtiments proches des IA non-BLUFOR
[] spawn LL_fnc_doorSecurity;

// --- 3.5 Météo et heure de mission aléatoires ---
// Appelé avant l'introduction pour que la cinématique reflète les conditions réelles
[] call LL_fnc_randomWeather;

// --- 4. Lancement de la cinématique d'introduction (partie serveur) ---
// Appelé AVANT le taskManager : l'intro crée l'hélico, embarque les joueurs et
// publie MISSION_intro_finished. Le taskManager attend ce signal pour démarrer.
// Appelé APRÈS initPlayerLoadout pour que les joueurs soient équipés à bord.
[] spawn LL_fnc_intro;

// --- 4.5 Gestionnaire hélicoptère de support ---
// Boucle permanente lancée après la fin de l'intro (évite conflit avec l'hélico cinématique).
[] spawn {
    waitUntil { !isNil "MISSION_intro_finished" };
    [] spawn LL_fnc_heliManager;
};

// --- 5. Démarrage du gestionnaire de tâches (Task Manager) ---
// Bloqué en interne par waitUntil { !isNil "MISSION_intro_finished" }.
[] spawn LL_fnc_taskManager;

diag_log "[LL][initServer] Initialisation serveur terminée.";
