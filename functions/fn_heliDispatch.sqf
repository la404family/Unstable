#include "..\macros.hpp"
/*
 * LL_fnc_heliDispatch — Dispatcher centralisé des demandes hélicoptère
 * Locality: Serveur uniquement
 *
 * Paramètres :
 *   0: String  — Type: "CAS"|"LIVRAISON"|"VEHICULE"|"DEBARQUEMENT"|"EMBARQUEMENT"
 *   1: Array   — Position cible [x, y, z]
 *   2: Object  — Unité demandeuse
 *   3: Number  — Priorité: 1 (joueur) | 2 (mission/tâche)
 *
 * Matrice de décision :
 *   IDLE                                               → Accepté
 *   État interruptible + prio requête > prio courante  → Interruption + file
 *   Tous les autres cas                                → Refusé
 *
 * États interruptibles : APPROACHING, CAS, DELIVERING, RTB, RTB_WITH_CARGO
 * États non-interruptibles : SPAWNING, DEPLOYING, EXTRACTING
 */
if (!isServer) exitWith {};

params [
    ["_type",     "CAS",   [""]],
    ["_pos",      [0,0,0], [[]]],
    ["_caller",   objNull, [objNull]],
    ["_priority", 1,       [0]]
];

// ── Gardes statiques ──────────────────────────────────────────────────────────

if (_type == "CAS" && { time < (missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) }) exitWith {
    private _rem = ceil ((missionNamespace getVariable ["TAG_CAS_Cooldown_Until", 0]) - time);
    (format [localize "STR_TAG_Msg_CAS_Cooldown", _rem]) remoteExec ["systemChat", _caller];
    diag_log format ["[LL][DISPATCH] CAS refusé — cooldown %1s.", _rem];
};

if (_type == "VEHICULE" && { missionNamespace getVariable ["TAG_VehicleSupport_Delivered", false] }) exitWith {
    (localize "STR_TAG_Msg_Vehicle_Denied_Once") remoteExec ["systemChat", _caller];
    diag_log "[LL][DISPATCH] VEHICULE refusé — déjà livré (usage unique).";
};

// ── Lecture état courant ───────────────────────────────────────────────────────

private _state   = missionNamespace getVariable ["LL_HELI_state",    "IDLE"];
private _curPrio = missionNamespace getVariable ["LL_HELI_priority", 0];
private _curType = missionNamespace getVariable ["LL_HELI_type",     ""];

// ── Décision ─────────────────────────────────────────────────────────────────

private _interruptibleStates = ["APPROACHING", "CAS", "DELIVERING", "RTB", "RTB_WITH_CARGO"];

switch (true) do {

    // ── CAS 1 : Aucune mission active → accepter immédiatement ───────────────
    case (_state == "IDLE"): {
        private _approveMsg = switch (_type) do {
            case "VEHICULE": { "STR_TAG_Msg_Vehicle_Approved" };
            case "CAS":      { "STR_TAG_Msg_CAS_Approved"     };
            default          { "STR_TAG_Msg_Ammo_Approved"    };
        };
        (localize _approveMsg) remoteExec ["systemChat", _caller];

        // Usage unique VEHICULE : verrouiller dès l'acceptation pour éviter
        // les requêtes en rafale pendant le délai de spawn
        if (_type == "VEHICULE") then {
            missionNamespace setVariable ["TAG_VehicleSupport_Delivered", true, true];
        };

        missionNamespace setVariable ["LL_HELI_pending", [_type, _pos, _caller, _priority], false];
        diag_log format ["[LL][DISPATCH] Accepté: type=%1 prio=%2", _type, _priority];
    };

    // ── CAS 2 : Priorité supérieure + état interruptible → interruption ───────
    case (_priority > _curPrio && { _state in _interruptibleStates }): {
        // Signal lu par les boucles internes de fn_heliManager (local serveur)
        missionNamespace setVariable ["LL_HELI_abort",   true,                              false];
        missionNamespace setVariable ["LL_HELI_pending", [_type, _pos, _caller, _priority], false];
        (localize "STR_LL_Heli_Msg_Route") remoteExec ["systemChat", _caller];
        diag_log format ["[LL][DISPATCH] Interruption: %1→%2 prio(%3>%4) état=%5",
            _curType, _type, _priority, _curPrio, _state];
    };

    // ── CAS 3 : Refus (priorité insuffisante ou état non-interruptible) ───────
    default {
        private _denyMsg = switch (_type) do {
            case "VEHICULE": { "STR_TAG_Msg_Vehicle_Denied" };
            case "CAS":      { "STR_TAG_Msg_CAS_Denied"     };
            default          { "STR_TAG_Msg_Ammo_Denied"    };
        };
        (localize _denyMsg) remoteExec ["systemChat", _caller];
        diag_log format ["[LL][DISPATCH] Refusé: état=%1 prio requis>%2 courant=%3",
            _state, _curPrio, _priority];
    };
};
