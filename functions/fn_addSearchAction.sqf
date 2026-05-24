#include "..\macros.hpp"

/*
 * LL_fnc_addSearchAction
 *
 * Description:
 *   Ajoute une action au joueur local (s'il est leader) pour ordonner à son escouade I.A.
 *   d'investir et fouiller les bâtiments à proximité (jusqu'à 50m).
 *   L'action se réapplique automatiquement après un respawn ou un changement d'unité.
 *   Optimisé pour réduire la consommation CPU en évitant les calculs de positions superflus.
 *   Aucun systemChat n'est affiché en cas de succès de l'action.
 *
 * Locality:
 *   Client uniquement (hasInterface)
 */

if (!hasInterface) exitWith {};

// Initialisation de la variable globale d'état
LL_Search_BuildingsNearby = false;

[] spawn {
    // -------------------------------------------------------------------------
    // BOUCLE DE MISE À JOUR DE L'ÉTAT (toutes les 2 secondes)
    // -------------------------------------------------------------------------
    // Optimisation : On ne fait pas buildingPos -1 (très lourd) sur chaque bâtiment.
    // On teste uniquement s'il possède au moins une position en vérifiant l'index 0.
    [] spawn {
        while {true} do {
            sleep 2;
            private _p = player;
            if (!isNull _p && {alive _p}) then {
                private _nearbyBuildings = nearestObjects [_p, ["House"], 50];
                private _hasValidBuilding = false;
                
                {
                    if (!((_x buildingPos 0) isEqualTo [0,0,0])) exitWith {
                        _hasValidBuilding = true;
                    };
                } forEach _nearbyBuildings;
                
                LL_Search_BuildingsNearby = _hasValidBuilding;
            } else {
                LL_Search_BuildingsNearby = false;
            };
        };
    };

    // -------------------------------------------------------------------------
    // FONCTION INTERNE D'AJOUT D'ACTION
    // -------------------------------------------------------------------------
    private _fnc_addSearchAction = {
        params ["_unit"];
        
        if (_unit getVariable ["LL_Action_Search_Added", false]) exitWith {};
        _unit setVariable ["LL_Action_Search_Added", true];

        _unit addAction [
            format ["<t color='#FFFFFF'>%1</t>", localize "STR_LL_Action_Search"],
            {
                params ["_target", "_caller", "_actionId", "_arguments"];

                private _nearbyBuildings = nearestObjects [_caller, ["House"], 50];
                private _validBuildings = _nearbyBuildings select { !((_x buildingPos 0) isEqualTo [0,0,0]) };

                if (count _validBuildings == 0) exitWith {
                    systemChat localize "STR_LL_Msg_Search_NoBuilding";
                };

                private _allPositions = [];
                { _allPositions append (_x buildingPos -1); } forEach _validBuildings;
                if (count _allPositions == 0) exitWith { 
                    systemChat localize "STR_LL_Msg_Search_NotAccessible"; 
                };

                // Mélanger les positions pour une répartition aléatoire de l'escouade
                _allPositions = _allPositions call BIS_fnc_arrayShuffle;

                private _squadAI = (units group _caller) select { !isPlayer _x && alive _x && vehicle _x == _x };
                if (count _squadAI == 0) exitWith { 
                    systemChat localize "STR_LL_Msg_Search_NoInfantry"; 
                };

                // Le leader fait un geste de la main (gestureAdvance) pour ordonner le mouvement
                _caller playActionNow "gestureAdvance";

                // Déploiement séquentiel asynchrone des IA pour respecter l'écart de 10m
                [_squadAI, _allPositions, _caller] spawn {
                    params ["_squadAI", "_allPositions", "_caller"];
                    
                    private _prevUnit = objNull;
                    
                    {
                        private _unit = _x;
                        if (alive _unit) then {
                            // Attendre que l'unité précédente soit à 10m de celle-ci pour éviter les encombrements
                            if (!isNull _prevUnit && {alive _prevUnit}) then {
                                private _timeout = time + 12; // Sécurité de 12 secondes maximum
                                waitUntil {
                                    sleep 0.25;
                                    private _dist = _unit distance _prevUnit;
                                    (_dist >= 10) || 
                                    { !alive _prevUnit } || 
                                    { speed _prevUnit < 0.2 && _dist > 3 && time > (_timeout - 9) } || 
                                    { time > _timeout }
                                };
                            };

                            // Paramétrage agressif pour investir le bâtiment rapidement
                            _unit disableAI "AUTOCOMBAT";
                            _unit disableAI "SUPPRESSION";
                            _unit setUnitPos "UP";
                            _unit setBehaviour "AWARE";
                            _unit setSpeedMode "FULL";

                            if (count _allPositions > 0) then {
                                private _assignedPos = _allPositions deleteAt 0;
                                _unit doMove _assignedPos;
                                _prevUnit = _unit;
                            } else {
                                // S'il y a plus d'I.A que de pièces, les derniers suivent le joueur (leader)
                                _unit doFollow _caller;
                                _prevUnit = _unit;
                            };
                        };
                    } forEach _squadAI;
                };

                // Rétablissement des paramètres normaux après 3 minutes (180s)
                [_squadAI] spawn {
                    params ["_units"];
                    sleep 180;
                    {
                        if (alive _x) then {
                            _x enableAI "AUTOCOMBAT";
                            _x enableAI "SUPPRESSION";
                            _x setUnitPos "AUTO";
                            _x setSpeedMode "NORMAL";
                            _x setBehaviour "AWARE";
                            
                            // Forcer le retour en formation
                            _x doFollow (leader group _x);
                        };
                    } forEach _units;
                };
            },
            [],
            5.1,
            false,
            true,
            "",
            // Condition optimisée : N'apparaît que s'il y a des IA ET des bâtiments garnis à proximité
            "leader group _target == _target && { { !isPlayer _x } count (units group _target) > 0 } && LL_Search_BuildingsNearby"
        ];
    };

    // -------------------------------------------------------------------------
    // BOUCLE PRINCIPALE - Gestion du switch de joueur / Respawn
    // -------------------------------------------------------------------------
    private _lastPlayer = objNull;
    while {true} do {
        waitUntil { sleep 1; player != _lastPlayer };
        
        _lastPlayer = player;
        if (!isNull _lastPlayer) then {
            [_lastPlayer] call _fnc_addSearchAction;
        };
    };
};
