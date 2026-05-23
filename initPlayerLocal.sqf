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

// Ajout de l'action pour forcer le regroupement des IA coincées
[] spawn LL_fnc_addRallyAction;

// Les actions de demande de support hélicoptère (Chinook RACS)
[] spawn LL_fnc_addHelicopterActions;

// L'action de demande de surveillance drone (MQ-9)
[] spawn LL_fnc_addDroneAction;

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
