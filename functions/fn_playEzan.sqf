/*
 * LL_fnc_playEzan
 *
 * Description:
 *   Fonction double rôle :
 *   - Serveur (aucun argument) : lance la boucle qui déclenche l'appel à la
 *     prière depuis chaque minaret toutes les 30 minutes, uniquement pour les
 *     joueurs à portée.
 *   - Client (1 argument)     : joue le son "ezan" en 3D depuis l'objet
 *     haut-parleur passé en paramètre.
 *
 * Arguments:
 *   0: <OBJECT> (Optionnel) Objet haut-parleur (minaret). Si fourni, joue le
 *      son localement sur la machine appelante. Default: objNull
 *
 * Return Value:
 *   <NIL>
 *
 * Locality:
 *   Serveur  — boucle de déclenchement
 *   Client   — lecture audio 3D (via remoteExec depuis le serveur)
 *
 * Public:
 *   Non
 *
 * Example:
 *   // Démarrage côté serveur (fn_initServer.sqf) :
 *   [] spawn LL_fnc_playEzan;
 */

params [["_minaretObj", objNull, [objNull]]];

// ── Mode client : lecture locale du son 3D ────────────────────────────────────
if (!isNull _minaretObj) exitWith {
    _minaretObj say3D ["ezan", 2500, 1];
};

// ── Mode serveur : boucle de l'appel à la prière ──────────────────────────────
if (!isServer) exitWith {};

private _soundRange = 2500;

// Construction dynamique de la liste des minarets définis dans la mission
// (ezan_00 … ezan_20 — les variables nulles sont ignorées)
private _minaretsVars = [];
for "_i" from 0 to 20 do {
    private _suffix  = if (_i < 10) then {format ["0%1", _i]} else {str _i};
    private _varName = format ["ezan_%1", _suffix];
    if (!isNull (missionNamespace getVariable [_varName, objNull])) then {
        _minaretsVars pushBack _varName;
    };
};

if (_minaretsVars isEqualTo []) exitWith {
    ["LL_fnc_playEzan: aucun objet minaret trouvé (ezan_00 … ezan_20)"] call BIS_fnc_error;
};

// Délai aléatoire initial avant le premier appel (5 à 15 minutes)
sleep (300 + random 600);

while {true} do {
    {
        private _varName = _x;
        private _minaret = missionNamespace getVariable [_varName, objNull];

        if (!isNull _minaret) then {
            private _nearbyPlayers = allPlayers select {
                (_x distance _minaret) < _soundRange
            };
            if (count _nearbyPlayers > 0) then {
                [_minaret] remoteExec ["LL_fnc_playEzan", _nearbyPlayers];
            };
        };

        sleep 0.05;
    } forEach _minaretsVars;

    // Prochain appel à la prière dans 30 minutes
    sleep 1800;
};
