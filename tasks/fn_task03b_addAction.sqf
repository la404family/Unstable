#include "..\macros.hpp"

/*
    LL_fnc_task03b_addAction

    Description:
      Ajoute l'action de désamorçage (hold 10s) sur chaque caisse-bombe de la tâche 03b.
      Lance également le chrono HUD (coin supérieur droit, non intrusif).

      Appelée via remoteExec [..., 0] depuis LL_fnc_task03b (serveur)
      dès que les bombes sont créées et que LL_Task03b_BombCrates est publié.

    Locality:
      CLIENT — hasInterface uniquement
*/

if (!hasInterface) exitWith {};

// Anti-double déclenchement (TASK_RULES §5)
if (missionNamespace getVariable ["LL_Task03b_ActionAdded", false]) exitWith {};
missionNamespace setVariable ["LL_Task03b_ActionAdded", true];

// Attendre que les caisses soient disponibles (publiées par le serveur)
waitUntil {
    sleep 1;
    count (missionNamespace getVariable ["LL_Task03b_BombCrates", []]) >= 2
};

private _crates = missionNamespace getVariable ["LL_Task03b_BombCrates", []];

// ══════════════════════════════════════════════════════════════════════
// HOLD ACTION DE DÉSAMORÇAGE — une par caisse-bombe
// TASK_RULES §5 : couleur jaune, distance courte, anti-double déclenchement
// ══════════════════════════════════════════════════════════════════════
{
    private _crate    = _x;
    private _bombIdx  = _forEachIndex;
    private _condStr  = format [
        "alive _this && _this distance _target < 4 && !(missionNamespace getVariable ['LL_Task03b_Bomb%1_Defused', false])",
        _bombIdx
    ];

    [
        _crate,
        format ["<t color='#FFFF00'>%1</t>", localize "STR_LL_Task_03b_Action_Defuse"],
        "\a3\ui_f\data\IGUI\Cfg\HoldActions\holdAction_hack_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\HoldActions\holdAction_hack_ca.paa",
        _condStr,   // condition d'affichage
        _condStr,   // condition de progression
        {},         // onStart (vide)
        {},         // onProgress (vide)
        {           // onComplete — désamorçage confirmé
            params ["_target", "_caller", "_actionId", "_arguments"];
            _arguments params ["_bombIndex"];

            // Anti-double (au cas où deux joueurs désamorcent simultanément)
            private _defuseVar = format ["LL_Task03b_Bomb%1_Defused", _bombIndex];
            if (missionNamespace getVariable [_defuseVar, false]) exitWith {};

            // Publier la confirmation sur tout le réseau → détectée par le serveur (fn_task03b.sqf)
            missionNamespace setVariable [_defuseVar, true, true];

            [_target, _actionId] call BIS_fnc_holdActionRemove;

            if (DEBUG_MODE) then {
                diag_log format ["[LL][task03b_addAction] Bombe %1 désamorcée par %2.", _bombIndex, name _caller];
            };
        },
        {},         // onInterrupt (vide)
        [_bombIdx], // arguments passés à onComplete
        10,         // durée du hold (secondes) — TASK_RULES §5
        10,         // priorité
        false,      // blockSprint
        false       // showOn3D (icône flottante désactivée)
    ] call BIS_fnc_holdActionAdd;

} forEach _crates;

// ══════════════════════════════════════════════════════════════════════
// CHRONO HUD — coin supérieur droit, non-intrusif
// Utilise ctrlCreate sur le display IGUI (findDisplay 12)
// IDC unique 1750302 pour pouvoir retrouver le contrôle ensuite
// ══════════════════════════════════════════════════════════════════════
[] spawn {
    sleep 1; // Laisser le temps au display de s'initialiser

    disableSerialization;
    private _disp = findDisplay 12;
    if (isNull _disp) exitWith {
        if (DEBUG_MODE) then { diag_log "[LL][task03b_addAction] Display IGUI (12) introuvable — chrono annulé."; };
    };

    // Créer le contrôle texte dans la couche IGUI
    private _ctrl = _disp ctrlCreate ["RscText", 1750302];
    _ctrl ctrlSetPosition   [0.80, 0.01, 0.195, 0.040];
    _ctrl ctrlSetFont        "PuristaBold";
    _ctrl ctrlSetFontHeight  0.038;
    _ctrl ctrlSetTextColor   [1.0, 0.9, 0.1, 1.0]; // jaune par défaut
    _ctrl ctrlCommit 0;

    // Boucle de mise à jour toutes les secondes
    while { missionNamespace getVariable ["LL_Task03b_Running", false] } do {
        private _endTime   = missionNamespace getVariable ["LL_Task03b_TimerEnd", time];
        private _remaining = (_endTime - time) max 0;
        private _mins      = floor (_remaining / 60);
        private _secs      = floor (_remaining mod 60);
        private _secsStr   = if (_secs < 10) then { format ["0%1", _secs] } else { str _secs };

        private _timerCtrl = findDisplay 12 displayCtrl 1750302;
        if (!isNull _timerCtrl) then {
            // Rouge pulsant quand il reste moins de 5 minutes
            private _color = if (_remaining <= 300) then { [1.0, 0.15, 0.15, 1.0] } else { [1.0, 0.9, 0.1, 1.0] };
            _timerCtrl ctrlSetTextColor _color;
            _timerCtrl ctrlSetText (format [localize "STR_LL_Task_03b_Timer_Label", _mins, _secsStr]);
            _timerCtrl ctrlCommit 0;
        };

        sleep 1;
    };

    // Nettoyage du contrôle quand la tâche se termine
    private _timerCtrl = findDisplay 12 displayCtrl 1750302;
    if (!isNull _timerCtrl) then { ctrlDelete _timerCtrl; };
};
