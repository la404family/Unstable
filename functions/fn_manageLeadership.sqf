#include "..\macros.hpp"

/*
 * LL_fnc_manageLeadership
 *
 * Description:
 *   Gère la réassignation immédiate du leader de groupe lors du décès du leader actuel.
 *   Recherche prioritairement un joueur humain vivant, sinon prend une unité IA vivante.
 *
 * Locality:
 *   Serveur uniquement
 */

params [
    ["_group", grpNull, [grpNull]],
    ["_deadUnit", objNull, [objNull]]
];

if (!isServer) exitWith {};
if (isNull _group) exitWith {};

private _livingUnits = units _group select { alive _x };
private _players = _livingUnits select { isPlayer _x };

if (count _players > 0) then {
    // Choisir le premier joueur vivant disponible
    private _newLeader = _players select 0;
    _group selectLeader _newLeader;
    
    if (DEBUG_MODE) then {
        diag_log format ["[LL] manageLeadership: Leader %1 mort. Réassignation au joueur %2.", name _deadUnit, name _newLeader];
    };
} else {
    if (count _livingUnits > 0) then {
        // Si aucun joueur n'est vivant, assigner temporairement à une IA vivante
        private _newLeader = _livingUnits select 0;
        _group selectLeader _newLeader;
        
        if (DEBUG_MODE) then {
            diag_log format ["[LL] manageLeadership: Leader %1 mort. Aucun joueur vivant. Réassignation temporaire à l'IA %2.", name _deadUnit, name _newLeader];
        };
    };
};
