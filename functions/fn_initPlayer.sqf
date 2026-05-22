// ============================================================
// fn_initPlayer.sqf — Initialisation côté client
// Exécuté sur chaque machine avec interface (hasInterface)
// via init.sqf. JIP-compatible.
// ============================================================
if (!hasInterface) exitWith {};

// --- Briefing & Narrative Background ---
// Diary records are displayed in reverse chronological order of creation in the UI.
// Creating bottom sections first ensures the main OPORD remains at the top.
player createDiaryRecord ["diary", [localize "STR_LL_Diary_Lore_Title", localize "STR_LL_Diary_Lore_Text"]];
player createDiaryRecord ["diary", [localize "STR_LL_Diary_Factions_Title", localize "STR_LL_Diary_Factions_Text"]];
player createDiaryRecord ["diary", [localize "STR_LL_Diary_Context_Title", localize "STR_LL_Diary_Context_Text"]];
player createDiaryRecord ["diary", [localize "STR_LL_Briefing_Title", localize "STR_LL_Briefing_Text"]];


// Application asynchrone de l'identité RACS (Multinational) :
// Le serveur assigne les identités via fn_initPlayerIdentity et
// diffuse la variable LL_s_identity globalement (setVariable true).
// On attend sa disponibilité puis on rappelle applyIdentity localement
// pour forcer setFace / setSpeaker / setPitch / setName sur cette machine,
// quelle que soit la fenêtre de connexion (JIP ou démarrage simultané).

[] spawn {
    private _playerUnit = vehicle player;
    private _timeout    = 0;

    // Attendre que le serveur ait diffusé l'identité (ou timeout 30 s)
    waitUntil {
        sleep 0.5;
        _timeout = _timeout + 0.5;
        (!isNil { _playerUnit getVariable "LL_s_identity" }) || { _timeout >= 30 }
    };

    private _identity = _playerUnit getVariable ["LL_s_identity", []];
    if (count _identity >= 5) then {
        _identity params ["_nameData", "_faceType", "_face", "_speaker", "_pitch", ["_beard", "", [""]]];
        [_playerUnit, _nameData, _face, _speaker, _pitch, _beard] call LL_fnc_applyIdentity;

        // Test : forcer un rafraîchissement de la barre de squad en masquant/remontrant le HUD.
        // Si les noms personnalisés apparaissent après ça, le problème est un cache HUD côté client.
        showHUD false;
        sleep 0.5;
        showHUD true;
    };
};
