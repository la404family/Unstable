#include "..\macros.hpp"

/*
 * LL_fnc_addDroneAction
 *
 * Description:
 *   Ajoute l'action de demande de soutien drone (surveillance MQ-9) au joueur local.
 *   L'action se réapplique automatiquement après un respawn ou un changement d'unité.
 *
 * Locality:
 *   Client uniquement (hasInterface)
 */

if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addDroneAction = {
        params ["_unit"];

        // Empêcher d'ajouter l'action en double
        if (_unit getVariable ["LL_Drone_Action_Added", false]) exitWith {};
        _unit setVariable ["LL_Drone_Action_Added", true];

        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Drone_Action"],
            {
                params ["_target", "_caller", "_actionId"];
                // Vérification locale du verrou avant d'envoyer au serveur
                if (missionNamespace getVariable ["TAG_Drone_Active", false]) exitWith {
                    systemChat (localize "STR_TAG_Msg_Drone_Denied");
                };
                [_caller] remoteExec ["LL_fnc_requestDrone", 2];
            },
            nil, 5.0, false, true, "", "alive _target"
        ];
    };

    // Boucle de maintien en cas de switch d'IA ou respawn
    private _lastPlayer = objNull;
    while { true } do {
        waitUntil { sleep 1; player != _lastPlayer };
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addDroneAction;
        };
    };
};
