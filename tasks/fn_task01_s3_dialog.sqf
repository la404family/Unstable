#include "..\macros.hpp"

/*
    Author: La Légion
    Description:
      Dialogue final avec le chef de milice (Scénario 3) pour valider task01
      et passer à task02c en donnant les coordonnées exactes du financier.

    Locality: Server
*/

params [
    ["_chief", objNull, [objNull]],
    ["_caller", objNull, [objNull]]
];

if (!isServer) exitWith {};
if (isNull _chief) exitWith {};

// Le chef se tourne vers le joueur
private _dir = _chief getDir _caller;
_chief setDir _dir;

// Animation fluide pour parler (playMove au lieu de switchMove pour la transition)
[_chief, "Acts_CivilTalking_1"] remoteExec ["playMove", 0];
[_chief, true] remoteExec ["setRandomLip", 0]; // Fait bouger les lèvres pour simuler la parole

// --- SIMULATION DE LA VRAIE VOIX NATIVE (Arma 3 AI Radio Voice) ---
// On crée temporairement une unité invisible dans son groupe pour le forcer à donner un ordre audio natif
private _grp = group _chief;
private _dummy = _grp createUnit ["I_G_Soldier_F", getPos _chief, [], 0, "NONE"];
_dummy hideObjectGlobal true;
_dummy allowDamage false;
_dummy disableAI "ALL";
_grp selectLeader _chief; // CORRECTIF : syntaxe group selectLeader unit

// Il donne l'ordre d'aller aux coordonnées, ce qui force le moteur à générer SA VRAIE VOIX !
_dummy commandMove (_chief getPos [1500, random 360]);

// Restauration exacte des sous-titres demandés (SANS le globalChat)
["STR_LL_Speaker_Chief", "Merci de m'avoir sauvé ! Mes gardes m'ont trahi pour l'argent du cartel..."] remoteExec ["LL_fnc_showSubtitle", 0];
sleep 5;

// Deuxième ordre audio natif pour simuler la suite de la phrase
_dummy commandMove (_chief getPos [2000, random 360]);

["STR_LL_Speaker_Chief", "L'intermédiaire qui les a payés se cache. Je vais vous donner ses coordonnées exactes, trouvez-le et capturez-le !"] remoteExec ["LL_fnc_showSubtitle", 0];
sleep 5;

deleteVehicle _dummy; // Nettoyage du faux soldat

// Remise à zéro de l'animation en douceur et arrêt des lèvres
[_chief, "AmovPercMstpSnonWnonDnon"] remoteExec ["playMove", 0];
[_chief, false] remoteExec ["setRandomLip", 0];

// Succès final de la tâche (Ceci débloque task02c via fn_taskManager)
["task_01_recon", "SUCCEEDED", true] call BIS_fnc_taskSetState;

if (DEBUG_MODE) then {
    diag_log "[LL] task01_s3_dialog: Fin du dialogue, task01 validée, transition vers task02c.";
};
