// ============================================================================
// initPlayerLocal.sqf — Initialisation client (exécuté sur chaque client avec interface)
// ============================================================================

// Lancement de l'initialisation de l'identité joueur (JIP-safe).
// Attend la diffusion des données de l'identité par le serveur et l'applique
// localement sur le personnage pour forcer le nom, le visage et la voix.
[] call LL_fnc_initPlayer;

// Ajout de l'action permettant d'ordonner aux IA du groupe de se soigner
[] spawn LL_fnc_addHealAction;

// Ajout des actions pour définir les règles d'engagement (RoE) de l'escouade
[] spawn LL_fnc_addRoeActions;

// Ajout de l'action pour ordonner la fouille des bâtiments aux IA
[] spawn LL_fnc_addSearchAction;
