#include "..\macros.hpp"

/*
 * LL_fnc_addHelicopterActions
 *
 * Description:
 *   Ajoute les actions de demande de soutien hélicoptère (Logistique, Véhicule, CAS, Débarquement, Extraction)
 *   au joueur local en couleur blanche (#FFFFFF) avec sélection sur carte.
 *   L'action se réapplique automatiquement après un respawn ou un changement d'unité.
 *
 * Locality:
 *   Client uniquement (hasInterface)
 */

if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addHelicopterActions = {
        params ["_unit"];
        
        // Empêcher d'ajouter les actions en double
        if (_unit getVariable ["LL_Heli_Actions_Added", false]) exitWith {};
        _unit setVariable ["LL_Heli_Actions_Added", true];

        // 1. Demander Livraison Munitions
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Heli_Action_Supply"],
            {
                params ["_target", "_caller", "_actionId"];
                ["LIVRAISON", getPos player, player, _target, _actionId] remoteExec ["LL_fnc_requestHelicopter", 2];
            },
            nil, 3.3, false, true, "", "(alive _target && leader (group _target) isEqualTo _target) || _target getVariable ['LL_Spectating', false]"
        ];

        // 2. Demander Livraison Véhicule (Usage Unique)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_TAG_Heli_Action_Vehicle"],
            {
                params ["_target", "_caller", "_actionId"];
                // Vérifier d'abord localement si le véhicule a déjà été livré
                if (missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false]) exitWith {
                    systemChat (localize "STR_TAG_Msg_Vehicle_Denied_Once");
                };
                ["VEHICULE", getPos player, player, _target, _actionId] remoteExec ["LL_fnc_requestHelicopter", 2];
            },
            nil, 3.1, false, true, "", "(alive _target && leader (group _target) isEqualTo _target) || _target getVariable ['LL_Spectating', false]"
        ];

        // 3. Demander Appui Aérien CAS (Cooldown de 5 minutes)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_TAG_Heli_Action_CAS"],
            {
                params ["_target", "_caller", "_actionId"];
                // Vérifier d'abord localement le cooldown CAS
                private _cooldown = missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0];
                if (time < _cooldown) exitWith {
                    private _remaining = ceil (_cooldown - time);
                    systemChat (format [localize "STR_TAG_Msg_CAS_Cooldown", _remaining]);
                };
                ["CAS", getPos player, player, _target, _actionId] remoteExec ["LL_fnc_requestHelicopter", 2];
            },
            nil, 2.9, false, true, "", "(alive _target && leader (group _target) isEqualTo _target) || _target getVariable ['LL_Spectating', false]"
        ];

        // 4. Demander Renforts (Débarquement)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Heli_Action_Reinforcements"],
            {
                params ["_target", "_caller", "_actionId"];
                ["DEBARQUEMENT", getPos player, player, _target, _actionId] remoteExec ["LL_fnc_requestHelicopter", 2];
            },
            nil, 2.7, false, true, "", "(alive _target && leader (group _target) isEqualTo _target) || _target getVariable ['LL_Spectating', false]"
        ];


    };

    // Boucle de maintien en cas de switch d'IA ou respawn
    private _lastPlayer = objNull;
    while {true} do {
        waitUntil { sleep 1; player != _lastPlayer };  
        
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addHelicopterActions;
        };
    };
};
