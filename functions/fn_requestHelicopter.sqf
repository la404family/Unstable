#include "..\macros.hpp"
/*
 * LL_fnc_requestHelicopter — Wrapper de compatibilité (point d'entrée actions joueur)
 * Locality : Serveur uniquement
 *
 * Reçoit les demandes des addAction (fn_addHelicopterActions) et délègue à
 * LL_fnc_heliDispatch avec priorité 1 (joueur).
 * Les tâches mission utilisent LL_fnc_heliDispatch directement avec priorité 2.
 *
 * Paramètres :
 *   0: String  — Type de support
 *   1: Array   — Position cible
 *   2: Object  — Unité demandeuse
 *   3: Object  — Cible de l'action (pour removeAction VEHICULE)
 *   4: Number  — ID de l'action (pour removeAction VEHICULE)
 */

if (!isServer) exitWith {};

params [
    ["_supportType",  "CAS",   [""]],
    ["_targetPos",    [0,0,0], [[]]],
    ["_caller",       objNull, [objNull]],
    ["_actionTarget", objNull, [objNull]],
    ["_actionId",     -1,      [0]]
];

// Suppression anticipée de l'action VEHICULE (usage unique) :
// faite ici avant l'appel au dispatcher pour éviter une double requête
// si le joueur reclique pendant le délai de traitement.
if (_supportType == "VEHICULE") then {
    if (!(missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false])
        && { _actionId != -1 } && { !isNull _actionTarget }) then {
        [_actionTarget, _actionId] remoteExec ["removeAction", 0, true];
    };
};

[_supportType, _targetPos, _caller, 1] call LL_fnc_heliDispatch;