// ============================================================================
// initPlayerLocal.sqf — Initialisation client (exécuté sur chaque client avec interface)
// ============================================================================

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
