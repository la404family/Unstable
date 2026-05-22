// ============================================================================
// initPlayerLocal.sqf — Initialisation client (exécuté sur chaque client avec interface)
// ============================================================================

// Lancement de l'initialisation de l'identité joueur (JIP-safe).
// Attend la diffusion des données de l'identité par le serveur et l'applique
// localement sur le personnage pour forcer le nom, le visage et la voix.
[] call LL_fnc_initPlayer;
