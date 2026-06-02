/*
    Author: La Légion
    Description:
    Prints a localized speaker message in systemChat.
    Can be run globally via remoteExec.

    Parameter(s):
    0: STRING - Speaker name or Localization key (e.g. "STR_LL_Speaker_Chief")
    1: STRING - Subtitle text or Localization key (e.g. "STR_LL_Task_01_S1_Chief")

    Returns:
    Nothing
*/
params [
    ["_speaker", "", [""]],
    ["_text", "", [""]]
];

// Localize speaker and text if keys are provided
private _localizedSpeaker = localize _speaker;
if (_localizedSpeaker == "") then { _localizedSpeaker = _speaker; };

private _localizedText = localize _text;
if (_localizedText == "") then { _localizedText = _text; };

// Ajout de sauts de ligne invisibles à la fin pour "pousser" le texte vers le haut
// Cela évite que les sous-titres ne chevauchent le HUD natif d'Arma (stance/stamina en bas au centre)
private _paddedText = _localizedText + "<br/><br/>";

[_localizedSpeaker, _paddedText] spawn BIS_fnc_showSubtitle;
