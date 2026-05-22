/*
 * LL_fnc_applyIdentity
 *
 * Description:
 *   Applique l'identité visuelle et vocale d'une unité : nom, visage, voix, pitch.
 *   setFace / setSpeaker / setPitch / setName sont des commandes locales — elles
 *   doivent être exécutées sur chaque machine pour que l'effet soit visible et
 *   audible. Cette fonction est donc appelée sur toutes les machines via remoteExec.
 *
 * Arguments:
 *   0: <OBJECT>  Unité cible
 *   1: <ARRAY>   Données de nom [nomComplet, prénom, nomFamille]
 *   2: <STRING>  Classe de visage ("" = conserver le visage par défaut du modèle)
 *   3: <STRING>  Classe de speaker / voix (ex. "Male01PER")
 *   4: <NUMBER>  Pitch (1.0 = neutre, >1.0 = plus aigu pour les femmes)
 *
 * Return Value:
 *   <BOOL> true si appliqué, false si l'unité est nulle
 *
 * Locality:
 *   Toutes les machines — appelée via remoteExec [..., 0, _unit]
 *
 * Public:
 *   Non
 *
 * Example:
 *   [_unit, ["Leila Hatami", "Leila", "Hatami"], "", "Male01PER", 1.35]
 *       remoteExec ["LL_fnc_applyIdentity", 0, _unit];
 */

params [
    ["_unit",     objNull, [objNull]],
    ["_nameData", [],      [[]]],
    ["_face",     "",      [""]],
    ["_speaker",  "",      [""]],
    ["_pitch",    1.0,     [0.0]],
    ["_goggles",  "",      [""]]
];

if (isNull _unit) exitWith { false };

if (count _nameData > 0) then {
    if (count _nameData >= 3) then {
        // Syntaxe complète : [nomComplet, prénom, nom]
        // Cela permet au HUD d'escouade (en bas) d'afficher correctement le nom court (nom de famille)
        // au lieu du surnom généré aléatoirement par le moteur (ex: "Delai", "Wiki").
        _unit setName [_nameData select 0, _nameData select 1, _nameData select 2];
    } else {
        // Rétrocompatibilité si seul un string est fourni
        _unit setName (_nameData select 0);
    };
};

if (_face      != "") then { _unit setFace    _face     };
if (_speaker   != "") then { _unit setSpeaker _speaker  };
if (_pitch      > 0)  then { _unit setPitch   _pitch    };
if (_goggles   != "") then {
    removeGoggles _unit;
    _unit addGoggles _goggles;
};

true
