/*
 * LL_fnc_applyLocalLoadout
 *
 * Description:
 *   Applique l'inventaire complet (uniform, munitions, items liés, insignia) sur
 *   le client propriétaire d'un joueur. Toutes les commandes utilisées ici ont un
 *   effet LOCAL depuis Arma 3 v2.02 et ne peuvent pas être exécutées depuis le serveur
 *   pour des unités distantes.
 *
 *   Appelée exclusivement via remoteExec depuis LL_fnc_initPlayerLoadout (serveur)
 *   pour les unités joueurs (non-locales au serveur).
 *
 * Params:
 *   0: OBJECT — unité cible (doit être locale sur ce client)
 *   1: STRING — classname uniform
 *   2: STRING — classname arme primaire
 *   3: STRING — classname chargeur primaire
 *   4: STRING — classname pistolet
 *   5: STRING — classname chargeur pistolet
 *   6: STRING — classname arme secondaire (lance-roquettes)
 *   7: ARRAY  — items assignés à restaurer (GPS, Map, Compass...)
 *
 * Locality: CLIENT — exécuté sur le client propriétaire de l'unité (via remoteExec)
 */

params [
    ["_unit",    objNull, [objNull]],
    ["_u",       "",      [""]],
    ["_pWeapon", "",      [""]],
    ["_pMag",    "",      [""]],
    ["_hWeapon", "",      [""]],
    ["_hMag",    "",      [""]],
    ["_sWeapon", "",      [""]],
    ["_assigned", [],     [[]]]
];

if (isNull _unit || !alive _unit) exitWith {
    diag_log "[LL][applyLocalLoadout] Unité nulle ou morte, annulé.";
};
if (!local _unit) exitWith {
    diag_log format ["[LL][applyLocalLoadout] ERREUR : unité %1 non-locale (machine %2). remoteExec mal ciblé.", _unit, clientOwner];
};

// 1. NETTOYAGE des items (LOCAL pour joueurs depuis v2.02)
removeAllItems _unit;

// 2. UNIFORM (LOCAL pour joueurs depuis v2.02)
if (_u != "") then { _unit forceAddUniform _u; };

// 3. ARME PRIMAIRE : 5 chargeurs en poche + 1 engagé dans l'arme
if (_pMag != "" && _pWeapon != "") then {
    for "_i" from 1 to 5 do { _unit addMagazine _pMag; };
    _unit addWeaponItem [_pWeapon, _pMag, true];
};

// 4. PISTOLET : 3 chargeurs + 1 engagé
if (_hMag != "" && _hWeapon != "") then {
    for "_i" from 1 to 3 do { _unit addMagazine _hMag; };
    _unit addWeaponItem [_hWeapon, _hMag, true];
};

// 5. LANCE-ROQUETTES : 2 roquettes
if (_sWeapon != "") then {
    private _sMags = [_sWeapon] call BIS_fnc_compatibleMagazines;
    if (count _sMags > 0) then { _unit addMagazines [_sMags select 0, 2]; };
};

// 6. FUMIGÈNES BLANCS (toutes les unités passant par ici sont des joueurs)
for "_i" from 1 to 3 do { _unit addMagazine "SmokeShellWhite"; };

// 7. GRENADES M67 (cette fonction n'est appelée que pour les joueurs humains)
for "_i" from 1 to 2 do { _unit addMagazine "HandGrenade"; };

// 8. ITEMS LIÉS : NVG en priorité, puis restauration des assigned items (GPS, Map, Compass...)
// LOCAL depuis v2.02
_unit linkItem "NVGogglesB_blk_F";
{
    if (!(_x in ["NVGogglesB_blk_F", ""])) then { _unit linkItem _x; };
} forEach _assigned;

// 9. SÉLECTION de l'arme principale
if (_pWeapon != "") then { _unit selectWeapon _pWeapon; };

// 10. INSIGNIA (effet local)
[_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;

// 11. FLAG global — empêche tout double-traitement par la boucle serveur
_unit setVariable ["LL_LoadoutSet", true, true];
