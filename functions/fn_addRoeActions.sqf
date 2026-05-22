#include "..\macros.hpp"

/*
 * LL_fnc_addRoeActions
 *
 * Description:
 *   Ajoute des actions au joueur local (s'il est leader) pour définir les règles d'engagement (RoE)
 *   de ses unités I.A. (Infiltration, Vigilance, Assaut, Charge).
 *   L'action se réapplique automatiquement après un respawn ou un changement d'unité.
 *   Aucun systemChat n'est affiché en cas de succès de l'action.
 *
 * Locality:
 *   Client uniquement (hasInterface)
 */

if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addRoeActions = {
        params ["_unit"];
        
        // Empêcher d'ajouter les actions en double
        if (_unit getVariable ["LL_Action_Roe_Added", false]) exitWith {};
        _unit setVariable ["LL_Action_Roe_Added", true];

        // Action : INFILTRATION (GHOST)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Action_RoE_Stealth"],
            {
                params ["_target", "_caller"];
                private _grp = group _caller;
                if (isNull _grp) exitWith {
                    systemChat "[LL ERROR] Impossible d'appliquer l'infiltration : Groupe introuvable.";
                };
                
                _grp setCombatMode "BLUE";    // Ne tire jamais
                _grp setBehaviour "STEALTH";  // Chuchote, marche accroupi
                _grp setSpeedMode "LIMITED";  // Marche lente
                
                // Réactiver l'autocombat normal si on vient d'un mode ultra agressif
                { if (!isPlayer _x) then { _x enableAI "AUTOCOMBAT"; }; } forEach units _grp;
            },
            nil, 6.4, false, true, "", 
            "leader group _target == _target && combatMode group _target != 'BLUE' && { { !isPlayer _x } count (units group _target) > 0 }"
        ];

        // Action : VIGILANCE (AWARE)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Action_RoE_Vigilance"],
            {
                params ["_target", "_caller"];
                private _grp = group _caller;
                if (isNull _grp) exitWith {
                    systemChat "[LL ERROR] Impossible d'appliquer la vigilance : Groupe introuvable.";
                };
                
                _grp setCombatMode "YELLOW";  // Tire à volonté
                _grp setBehaviour "AWARE";    // Déplacement normal, prêt au combat
                _grp setSpeedMode "NORMAL";   // Vitesse de croisière
                
                { if (!isPlayer _x) then { _x enableAI "AUTOCOMBAT"; }; } forEach units _grp;
            },
            nil, 6.3, false, true, "", 
            "leader group _target == _target && combatMode group _target != 'YELLOW' && { { !isPlayer _x } count (units group _target) > 0 }"
        ];

        // Action : ASSAUT (COMBAT)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Action_RoE_Assault"],
            {
                params ["_target", "_caller"];
                private _grp = group _caller;
                if (isNull _grp) exitWith {
                    systemChat "[LL ERROR] Impossible d'appliquer l'assaut : Groupe introuvable.";
                };
                
                _grp setCombatMode "RED";     // Engagement libre et tir à volonté
                _grp setBehaviour "COMBAT";   // Cherche à couvert, très réactif
                _grp setSpeedMode "NORMAL";
                
                { if (!isPlayer _x) then { _x enableAI "AUTOCOMBAT"; }; } forEach units _grp;
            },
            nil, 6.2, false, true, "", 
            "leader group _target == _target && (combatMode group _target != 'RED' || speedMode group _target != 'NORMAL') && { { !isPlayer _x } count (units group _target) > 0 }"
        ];

        // Action : ULTRA AGRESSIF (CHARGE)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Action_RoE_Charge"],
            {
                params ["_target", "_caller"];
                private _grp = group _caller;
                if (isNull _grp) exitWith {
                    systemChat "[LL ERROR] Impossible d'appliquer la charge : Groupe introuvable.";
                };
                
                _grp setCombatMode "RED";     // Engagement libre
                _grp setBehaviour "COMBAT";
                _grp setSpeedMode "FULL";     // Sprint
                
                // Désactiver "AUTOCOMBAT" oblige l'IA à ignorer la prudence. 
                // Ils ne s'arrêteront plus pour avancer prudemment d'un abri à l'autre, ils sprinteront vers l'objectif.
                { 
                    if (!isPlayer _x) then {
                        _x disableAI "AUTOCOMBAT"; 
                    };
                } forEach units _grp;
            },
            nil, 6.1, false, true, "", 
            "leader group _target == _target && (combatMode group _target != 'RED' || speedMode group _target != 'FULL') && { { !isPlayer _x } count (units group _target) > 0 }"
        ];
    };

    // Boucle de maintien en cas de switch d'IA ou respawn
    private _lastPlayer = objNull;
    while {true} do {
        waitUntil { sleep 1; player != _lastPlayer };  
        
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addRoeActions;
        };
    };
};
