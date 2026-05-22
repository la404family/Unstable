/*
 * LL_fnc_applyCivilianTemplate
 *
 * Description:
 *   (Serveur uniquement) Applique à une unité non-BLUFOR un template civil
 *   tiré aléatoirement dans MISSION_CivilianTemplates :
 *     - tenue complète via setUnitLoadout
 *     - armes + sac aléatoires pour OPFOR / Indépendants
 *     - désarmement pour les civils
 *     - barbe + couvre-chef CUP pour les hommes
 *     - identité (nom, visage, voix, pitch) diffusée à tous les clients via
 *       LL_fnc_applyIdentity (remoteExec JIP-safe, voix perse).
 *
 * Arguments:
 *   0: <OBJECT>  Unité cible
 *
 * Return Value:
 *   <BOOL> true si un template a été appliqué, false sinon
 *
 * Locality:
 *   Server uniquement — setUnitLoadout / addHeadgear / addGoggles sont locaux
 *
 * Public:
 *   Non
 *
 * Example:
 *   [_unit] call LL_fnc_applyCivilianTemplate;
 */

#include "..\macros.hpp"

params [
    ["_agent", objNull, [objNull]],
    ["_template", [], [[]]]
];

// --- Gardes de sortie anticipée ---
if (isNull _agent)                                          exitWith { false };
if (!alive _agent)                                          exitWith { false };
if (isPlayer _agent)                                        exitWith { false };
if ((side _agent == independent || side _agent == resistance) && !(_agent getVariable ["LL_forceTemplate", false])) exitWith { false };
if (!local _agent)                                          exitWith { false };
if (_agent getVariable ["MISSION_TemplateApplied", false])  exitWith { false };
if (count MISSION_CivilianTemplates == 0) exitWith {
    if (DEBUG_MODE) then {
        diag_log format ["[LL][applyCivilianTemplate] Aucun template disponible pour %1.", _agent];
    };
    false
};

// Marquage immédiat pour éviter la double application (local + broadcasted)
_agent setVariable ["MISSION_TemplateApplied", true, true];

// --- Sélection aléatoire d'un template ---
// Format : [classe, chargement, estFemme, visage, pitch]
if (_template isEqualTo []) then {
    // Filtrage par genre pour s'assurer que le squelette/modèle 3D de l'unité correspond à la tenue
    private _isFemaleUnit = "woman" in (toLower typeOf _agent);
    private _compatibleTemplates = MISSION_CivilianTemplates select { (_x select 2) == _isFemaleUnit };
    
    if (count _compatibleTemplates > 0) then {
        _template = selectRandom _compatibleTemplates;
    } else {
        _template = selectRandom MISSION_CivilianTemplates;
    };
};
_template params ["_class", "_loadout", "_isFemale", "_face", "_pitch"];

// --- Tenue complète depuis le template (remplace tout le chargement) ---
_agent setUnitLoadout _loadout;

// --- Armement selon la faction ---
private _agentSide = side _agent;

if (_agentSide == east || _agentSide == west || _agent getVariable ["LL_forceTemplate", false]) then {

    // Bandits OPFOR / Indépendants : sac aléatoire + arme primaire + secondaire
    removeBackpack _agent;
    _agent addBackpack (selectRandom MISSION_BanditBackpacks);

    private _bLoadout = selectRandom MISSION_BanditLoadouts;
    _bLoadout params [
        "_priWep", "_priMag", "_priMagCount",
        "_secWep", "_secMag", "_secMagCount",
        "_smoke",  "_smokeCount",
        "_FAK",    "_FAKCount"
    ];

    _agent addWeapon _priWep;
    for "_i" from 1 to _priMagCount  do { _agent addMagazine _priMag  };
    _agent addWeapon _secWep;
    for "_i" from 1 to _secMagCount  do { _agent addMagazine _secMag  };
    for "_i" from 1 to _smokeCount   do { _agent addMagazine _smoke   };
    for "_i" from 1 to _FAKCount     do { _agent addItem     _FAK     };
} else {
    // Civil : s'assurer qu'il ne porte aucune arme
    removeAllWeapons _agent;
};

// --- Accessoires masculins : barbe (slot lunettes) + couvre-chef CUP ---
if (!_isFemale) then {
    removeGoggles  _agent;
    _agent addGoggles  (selectRandom MISSION_CivilianBeards);
    removeHeadgear _agent;
    _agent addHeadgear (selectRandom MISSION_CivilianHats);
};

// --- Identité diffusée à tous les clients (JIP-safe) ---
// Le 3e paramètre de remoteExec est l'unité elle-même : broadcast annulé à sa mort
private _namesDB  = if (_isFemale) then { MISSION_CivilianNames_Female } else { MISSION_CivilianNames_Male };
private _nameData = selectRandom _namesDB;
private _speaker  = selectRandom ["Male01PER", "Male02PER", "Male03PER"];

[_agent, _nameData, _face, _speaker, _pitch] remoteExec ["LL_fnc_applyIdentity", 0, _agent];

if (DEBUG_MODE) then {
    diag_log format [
        "[LL][applyCivilianTemplate] %1 → tenue appliquée | genre : %2 | nom : %3 | pitch : %4",
        _agent,
        if (_isFemale) then {"F"} else {"M"},
        _nameData select 0,
        _pitch
    ];
};

true
