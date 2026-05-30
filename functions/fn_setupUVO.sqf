#include "..\macros.hpp"

/*
 * LL_fnc_setupUVO
 *
 * Description:
 *   Configure une unité pour utiliser la langue Française avec le mod Unit Voice-Overs Expanded (UVO).
 *   Cette fonction est totalement non-intrusive : elle se contente d'assigner des variables
 *   qui seront lues par UVO si le mod est actif. Si UVO n'est pas installé, les variables
 *   sont ignorées par le jeu, ce qui garantit qu'aucune erreur ne se produira.
 *
 * Params:
 *   0: OBJECT - L'unité à configurer
 *
 * Locality:
 *   Exécuté partout (les variables sont broadcastées)
 */

params [["_unit", objNull, [objNull]]];

if (isNull _unit) exitWith {};

// En mode "Full FR", on force systématiquement la langue française pour UVO.
private _uvoLang = "French";

// On assigne les variables classiques de contrôle pour UVO Expanded et ses dérivés.
_unit setVariable ["UVO_Voice", _uvoLang, true];
_unit setVariable ["UVO_Language", _uvoLang, true];

// On désactive la détection automatique de UVO pour éviter que le mod n'écrase
// notre choix en se basant sur la faction RACS/Indépendante.
_unit setVariable ["uvo_disable_auto", true, true];

if (DEBUG_MODE) then {
    diag_log format ["[LL] setupUVO: Variables d'intégration UVO (Full FR) appliquées sur %1", name _unit];
};
