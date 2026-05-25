#include "..\macros.hpp"

/*
 * LL_fnc_transferLocality
 *
 * Description:
 *   Transfère la propriété (localité) d'une unité IA individuelle vers le client spécifié.
 *   Utilise setOwner sur l'unité cible uniquement (MP-safe, évite les race conditions).
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

// Transférer uniquement l'unité cible (MP-safe).
// setOwner sur l'unité individuelle évite la race condition provoquée par setGroupOwner
// lorsque plusieurs joueurs meurent simultanément : chaque joueur ne vole plus la localité
// des IA déjà transférées aux autres joueurs ayant switché avant lui.
_unit setOwner _clientOwner;

if (DEBUG_MODE) then {
    diag_log format ["[LL] transferLocality: Unité %1 transférée au client %2.", _unit, _clientOwner];
};
