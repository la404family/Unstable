#include "..\macros.hpp"

/*
 * LL_fnc_addHealAction
 *
 * Description:
 *   Ajoute une action au joueur local (s'il est leader) pour ordonner aux membres
 *   I.A. blessés de son groupe de se soigner de manière autonome.
 *   L'action se réapplique automatiquement après un respawn ou un changement d'unité.
 *   Aucun systemChat n'est affiché en cas de succès de l'action.
 *
 * Locality:
 *   Client uniquement (hasInterface)
 */

if (!hasInterface) exitWith {};

[] spawn {
    private _fnc_addHealAction = {
        params ["_unit"];
        
        if (_unit getVariable ["LL_Action_Heal_Added", false]) exitWith {};
        _unit setVariable ["LL_Action_Heal_Added", true];

        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Action_Heal"],  
            {
                params ["_target", "_caller", "_actionId", "_arguments"];
                
                // Récupération des IA blessées dans le groupe
                private _aiUnits = (units group _caller) select { !isPlayer _x && alive _x && damage _x > 0.1 };
                private _validHealers = [];
                private _noKitCount = 0;

                {
                    if ("FirstAidKit" in items _x || "Medikit" in items _x) then {
                        _validHealers pushBack _x;
                    } else {
                        _noKitCount = _noKitCount + 1;
                    };
                } forEach _aiUnits;

                if (count _validHealers > 0) then {
                    // Succès : pas de systemChat conformément aux instructions utilisateur
                    [_validHealers] spawn {
                        params ["_healers"];
                        {
                            private _unit = _x;
                            private _delayBase = _forEachIndex;
                            
                            [_unit, _delayBase] spawn {
                                params ["_unit", "_delayBase"];
                                
                                // On attend que l'IA ne soit plus en statut COMBAT ou n'ait plus d'ennemi proche
                                waitUntil { 
                                    sleep 2; 
                                    !alive _unit || 
                                    (behaviour _unit != "COMBAT" && isNull (_unit findNearestEnemy _unit))
                                };
                                
                                if (alive _unit && damage _unit > 0.1) then {
                                    // Décalage pour éviter les animations simultanées
                                    sleep (_delayBase * (1.5 + random 1.0));
                                    if (alive _unit) then {
                                        _unit action ["HealSoldierSelf", _unit];
                                    };
                                };
                            };
                        } forEach _healers;
                    };
                } else {
                    // Erreurs / Anomalies : affichage de systemChat uniquement pour ces cas
                    if (_noKitCount > 0) then {
                        systemChat "[LL ERROR] Les IA blessées n'ont pas de kit de soin (FirstAidKit/Medikit).";
                    } else {
                        systemChat "[LL ERROR] Aucune IA blessée n'a besoin de soins.";
                    };
                };
            },
            [],
            5.3, 
            false, 
            true, 
            "", 
            // Condition : le joueur doit être le leader et avoir des IA dans son groupe
            "leader group _target == _target && { { !isPlayer _x } count (units group _target) > 0 }"
        ];
    };

    // Boucle de maintien de l'action (en cas de switch d'IA ou de respawn)
    private _lastPlayer = objNull;
    while {true} do {
        waitUntil { sleep 1; player != _lastPlayer };  
        
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addHealAction;
        };
    };
};
