// ============================================================================
// initServer.sqf — Initialisation serveur (exécuté uniquement sur le serveur)
// ============================================================================

diag_log "[LL][initServer] Démarrage de l'initialisation serveur...";

// --- 1. Initialisation et contrôle de la présence civile ---
// Charge les templates d'apparence civile depuis l'éditeur et nettoie la carte
[] call LL_fnc_initCivilians;

// Boucle principale de spawn et de dépop des civils autour des joueurs
[] spawn LL_fnc_spawnCivilianPresence;


// --- 2. Initialisation de l'identité et du loadout des joueurs ---
// Assigne les grades et l'apparence Légion aux slots player_00 ... player_06
[] call LL_fnc_initPlayerIdentity;

// Configure les sacs (CUP Tactical Pack CCE) et l'armement initial
[] call LL_fnc_initPlayerLoadout;

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
