#include "..\macros.hpp"

/*
 * LL_fnc_transferLocality
 *
 * Description:
 *   Transfère la propriété (localité) d'une unité ou de son groupe complet vers le client spécifié.
 *
 * Locality:
 *   Serveur uniquement
 */

params [
    ["_unit", objNull, [objNull]],
    ["_clientOwner", 0, [0]]
];

if (!isServer) exitWith {};
if (isNull _unit || _clientOwner == 0) exitWith {};

private _grp = group _unit;
if (!isNull _grp) then {
    // Si l'unité fait partie d'un groupe, on transfère la propriété du groupe complet
    // pour garantir la localité de tous ses membres IA sur la machine du joueur.
    _grp setGroupOwner _clientOwner;
    
    if (DEBUG_MODE) then {
        diag_log format ["[LL] transferLocality: Propriété du groupe %1 transférée au client %2.", _grp, _clientOwner];
    };
} else {
    // Sinon, on transfère l'unité individuelle
    _unit setOwner _clientOwner;
    
    if (DEBUG_MODE) then {
        diag_log format ["[LL] transferLocality: Propriété de l'unité %1 transférée au client %2.", _unit, _clientOwner];
    };
};
