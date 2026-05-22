// ============================================================================
// init.sqf — Initialisation globale (exécuté sur serveur et clients)
// ============================================================================

// Lancement global du gestionnaire de compétences (skills) des IA.
// Cette boucle tourne sur toutes les machines mais ne traite que les IA locales
// à la machine qui exécute la boucle (local _unit).
[] spawn LL_fnc_manageSkills;
