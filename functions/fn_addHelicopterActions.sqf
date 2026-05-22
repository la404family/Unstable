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
                openMap true;
                (localize "STR_LL_Heli_Msg_MapClick") systemChat;
                
                missionNamespace setVariable ["TAG_Heli_Request_Pending", ["LIVRAISON", _target, _actionId]];
                
                onMapSingleClick {
                    params ["_control", "_pos", "_shift", "_alt"];
                    private _pending = missionNamespace getVariable ["TAG_Heli_Request_Pending", []];
                    if (count _pending > 0) then {
                        _pending params ["_type", "_targetObj", "_actId"];
                        [_type, _pos, player, _targetObj, _actId] remoteExec ["LL_fnc_requestHelicopter", 2];
                    };
                    missionNamespace setVariable ["TAG_Heli_Request_Pending", nil];
                    onMapSingleClick "";
                    openMap false;
                    true
                };
            },
            nil, 5.5, false, true, "", "alive _target"
        ];

        // 2. Demander Livraison Véhicule (Usage Unique)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_TAG_Heli_Action_Vehicle"],
            {
                params ["_target", "_caller", "_actionId"];
                // Vérifier d'abord localement si le véhicule a déjà été livré
                if (missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false]) exitWith {
                    private _snd = selectRandom ["negatif01", "negatif02", "negatif03", "negatif04"];
                    playSound _snd;
                    (localize "STR_TAG_Msg_Vehicle_Denied_Once") systemChat;
                };
                
                openMap true;
                (localize "STR_LL_Heli_Msg_MapClick") systemChat;
                
                missionNamespace setVariable ["TAG_Heli_Request_Pending", ["VEHICULE", _target, _actionId]];
                
                onMapSingleClick {
                    params ["_control", "_pos", "_shift", "_alt"];
                    private _pending = missionNamespace getVariable ["TAG_Heli_Request_Pending", []];
                    if (count _pending > 0) then {
                        _pending params ["_type", "_targetObj", "_actId"];
                        [_type, _pos, player, _targetObj, _actId] remoteExec ["LL_fnc_requestHelicopter", 2];
                    };
                    missionNamespace setVariable ["TAG_Heli_Request_Pending", nil];
                    onMapSingleClick "";
                    openMap false;
                    true
                };
            },
            nil, 5.4, false, true, "", "alive _target"
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
                    private _snd = selectRandom ["negatif01", "negatif02", "negatif03", "negatif04"];
                    playSound _snd;
                    (format [localize "STR_TAG_Msg_CAS_Cooldown", _remaining]) systemChat;
                };
                
                openMap true;
                (localize "STR_LL_Heli_Msg_MapClick") systemChat;
                
                missionNamespace setVariable ["TAG_Heli_Request_Pending", ["CAS", _target, _actionId]];
                
                onMapSingleClick {
                    params ["_control", "_pos", "_shift", "_alt"];
                    private _pending = missionNamespace getVariable ["TAG_Heli_Request_Pending", []];
                    if (count _pending > 0) then {
                        _pending params ["_type", "_targetObj", "_actId"];
                        [_type, _pos, player, _targetObj, _actId] remoteExec ["LL_fnc_requestHelicopter", 2];
                    };
                    missionNamespace setVariable ["TAG_Heli_Request_Pending", nil];
                    onMapSingleClick "";
                    openMap false;
                    true
                };
            },
            nil, 5.3, false, true, "", "alive _target"
        ];

        // 4. Demander Renforts (Débarquement)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Heli_Action_Reinforcements"],
            {
                params ["_target", "_caller", "_actionId"];
                openMap true;
                (localize "STR_LL_Heli_Msg_MapClick") systemChat;
                
                missionNamespace setVariable ["TAG_Heli_Request_Pending", ["DEBARQUEMENT", _target, _actionId]];
                
                onMapSingleClick {
                    params ["_control", "_pos", "_shift", "_alt"];
                    private _pending = missionNamespace getVariable ["TAG_Heli_Request_Pending", []];
                    if (count _pending > 0) then {
                        _pending params ["_type", "_targetObj", "_actId"];
                        [_type, _pos, player, _targetObj, _actId] remoteExec ["LL_fnc_requestHelicopter", 2];
                    };
                    missionNamespace setVariable ["TAG_Heli_Request_Pending", nil];
                    onMapSingleClick "";
                    openMap false;
                    true
                };
            },
            nil, 5.2, false, true, "", "alive _target"
        ];

        // 5. Demander Extraction (Embarquement)
        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Heli_Action_Extraction"],
            {
                params ["_target", "_caller", "_actionId"];
                openMap true;
                (localize "STR_LL_Heli_Msg_MapClick") systemChat;
                
                missionNamespace setVariable ["TAG_Heli_Request_Pending", ["EMBARQUEMENT", _target, _actionId]];
                
                onMapSingleClick {
                    params ["_control", "_pos", "_shift", "_alt"];
                    private _pending = missionNamespace getVariable ["TAG_Heli_Request_Pending", []];
                    if (count _pending > 0) then {
                        _pending params ["_type", "_targetObj", "_actId"];
                        [_type, _pos, player, _targetObj, _actId] remoteExec ["LL_fnc_requestHelicopter", 2];
                    };
                    missionNamespace setVariable ["TAG_Heli_Request_Pending", nil];
                    onMapSingleClick "";
                    openMap false;
                    true
                };
            },
            nil, 5.1, false, true, "", "alive _target"
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
