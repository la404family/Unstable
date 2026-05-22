/*
    Author: La Légion
    Description:
    Displays a localized subtitle at the bottom center of the player's screen and prints it in systemChat.
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

// Output to systemChat (Commented out to remove chat spam during tasks)
// systemChat format ["%1: %2", _localizedSpeaker, _localizedText];

// Show dynamic text at the bottom center (x=0, y=0.85)
private _displayText = format [
    "<t align='center' size='0.85' color='#FFFFFF' shadow='2' font='RobotoCondensed'><t color='#FFD700'>%1:</t><br/>%2</t>",
    _localizedSpeaker,
    _localizedText
];

// BIS_fnc_dynamicText parameters: [text, x, y, duration, fadeIn, deltaY, layer]
[_displayText, -1, 0.85, 6, 0.5, 0, 70100] spawn BIS_fnc_dynamicText;
