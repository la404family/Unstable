/*
 * LL_fnc_initPlayerLoadout
 *
 * Description:
 *   Gère l'apparence et le loadout de toutes les unités du groupe (I.A et joueurs).
 *   Compatible serveur dédié : se base sur player_00, pas sur player.
 *   Munitions : 5 chargeurs primaires, 3 pistolet, 2 lance-roquettes, 3 fum igènes blancs.
 *   Grenades M67 : joueurs humains uniquement.
 *
 * Locality:
 *   Serveur uniquement
 */

if (!isServer) exitWith {};

// --- Définition des pools d'équipements ---
private _vests = [
    "CUP_V_JPC_medical_coy", "CUP_V_JPC_tl_coy", "CUP_V_JPC_weapons_coy",
    "CUP_V_JPC_communicationsbelt_coy", "CUP_V_JPC_Fastbelt_coy", "CUP_V_JPC_lightbelt_coy",
    "CUP_V_JPC_medicalbelt_coy", "CUP_V_JPC_tlbelt_coy", "CUP_V_JPC_weaponsbelt_coy"
];

private _helmets = [
    "CUP_H_OpsCore_Tan_SF", "CUP_H_OpsCore_Tan", "CUP_H_OpsCore_Tan_NohS",
    "CUP_H_OpsCore_Grey_SF", "CUP_H_OpsCore_Grey", "CUP_H_OpsCore_Grey_NohS"
];

private _backpacks = [
    "CUP_B_AssaultPack_Coyote", "B_assaultPack_cbr", "B_Kitbag_cbr"
];

private _uniforms = [
    "CUP_U_B_USMC_MCCUU_des_gloves", "CUP_U_B_USMC_MCCUU_des_roll_2",
    "CUP_U_B_USMC_MCCUU_des_roll_2_gloves", "CUP_U_B_USMC_MCCUU_des_roll_pads",
    "CUP_U_B_USMC_MCCUU_des_roll_2_pads_gloves", "CUP_U_B_USMC_MCCUU_des_pads",
    "CUP_U_B_USMC_MCCUU_des_pads_gloves", "CUP_U_B_USMC_MCCUU_des_roll",
    "CUP_U_B_USMC_MCCUU_des_roll_gloves", "CUP_U_B_USMC_MCCUU_des_roll_pads",
    "CUP_U_B_USMC_MCCUU_des_roll_pads_gloves", "CUP_U_B_USMC_MCCUU_des"
];

private _cagoules = [
    "CUP_G_Tan_Scarf_Shades_GPSCombo_Beard", "CUP_G_Tan_Scarf_Shades_GPS_Beard",
    "CUP_G_Tan_Scarf_GPS", "CUP_G_TK_RoundGlasses_blk", "CUP_G_Oakleys_Drk",
    "CUP_G_Scarf_Face_Tan", "G_Aviator", "CUP_G_ESS_KHK_Scarf_Tan_GPS_Beard",
    "CUP_G_ESS_KHK_Facewrap_Tan", "G_Bandana_khk"
];

// Fonction de mélange
private _fn_shuffle = {
    private _arr = +_this;
    for "_i" from (count _arr) - 1 to 1 step -1 do {
        private _j = floor random (_i + 1);
        private _temp = _arr select _i;
        _arr set [_i, _arr select _j];
        _arr set [_j, _temp];
    };
    _arr
};

private _shuffledUniforms  = _uniforms call _fn_shuffle;
private _shuffledHelmets   = _helmets call _fn_shuffle;
private _shuffledBackpacks = _backpacks call _fn_shuffle;
private _shuffledCagoules  = _cagoules call _fn_shuffle;
private _shuffledVests     = _vests call _fn_shuffle;

// Applique le loadout complet sur une unité.
// I.A (locale serveur) : toutes les commandes en direct (toutes locales ici).
// Joueur (distant) : containers globaux sur le serveur + délégation via LL_fnc_applyLocalLoadout.
private _fnc_applyVisuals = {
    params ["_unit", "_varName", "_u", "_v", "_b", "_h", "_c"];
    if (isNull _unit || !alive _unit) exitWith {};

    // 1. SAUVEGARDE : armes et chargeurs AVANT nettoyage
    private _pWeapon = primaryWeapon _unit;
    private _sWeapon = secondaryWeapon _unit;
    private _hWeapon = handgunWeapon _unit;

    private _pMag = "";
    private _hMag = "";

    if (_pWeapon != "") then {
        private _currentPMags = primaryWeaponMagazine _unit;
        if (count _currentPMags > 0) then {
            _pMag = _currentPMags select 0;
        } else {
            private _compat = [_pWeapon] call BIS_fnc_compatibleMagazines;
            if (count _compat > 0) then { _pMag = _compat select 0; };
        };
    };
    if (_hWeapon != "") then {
        private _currentHMags = handgunMagazine _unit;
        if (count _currentHMags > 0) then { _hMag = _currentHMags select 0; };
    };

    // Fallback M249
    if (_pMag == "" && {toLower _pWeapon find "m249" != -1 || toLower _pWeapon find "lmg" != -1}) then {
        _pMag = "CUP_200Rnd_TE4_Red_Tracer_556x45_M249";
    };

    private _assigned = assignedItems _unit;

    // 2. CONTAINERS — effet GLOBAL (fonctionnent depuis le serveur pour toutes les unités)
    removeUniform _unit;
    removeVest _unit;
    removeBackpack _unit;
    removeHeadgear _unit;
    removeGoggles _unit;
    _unit addVest _v;
    _unit addBackpack _b;
    _unit addHeadgear _h;
    _unit addGoggles _c;

    // Jumelles (addWeapon = effet global)
    if (binocular _unit == "") then { _unit addWeapon "CUP_LRTV"; };

    // 3. INVENTAIRE — séparation stricte selon la localité de l'unité
    if (local _unit) then {
        // === I.A locale au serveur : application directe ===
        // removeAllItems, forceAddUniform, addWeaponItem, linkItem sont tous d'effet
        // local — OK ici car l'unité est bien locale sur cette machine (serveur).
        removeAllItems _unit;
        _unit forceAddUniform _u;

        if (_pMag != "") then {
            for "_i" from 1 to 5 do { _unit addMagazine _pMag; };
            _unit addWeaponItem [_pWeapon, _pMag, true];
        };
        if (_hMag != "") then {
            for "_i" from 1 to 3 do { _unit addMagazine _hMag; };
            _unit addWeaponItem [_hWeapon, _hMag, true];
        };
        if (_sWeapon != "") then {
            private _sMags = [_sWeapon] call BIS_fnc_compatibleMagazines;
            if (count _sMags > 0) then { _unit addMagazines [_sMags select 0, 2]; };
        };
        for "_i" from 1 to 3 do { _unit addMagazine "SmokeShellWhite"; };
        // Pas de M67 pour les I.A
        for "_i" from 1 to 3 do { _unit addItem "FirstAidKit"; };
        { _unit linkItem _x; } forEach _assigned;
        _unit linkItem "NVGogglesB_blk_F";
        _unit selectWeapon _pWeapon;
        [_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
        _unit setVariable ["LL_LoadoutSet", true, true];

    } else {
        // === JOUEUR distant (propriété d'un client) ===
        // removeAllItems, forceAddUniform, addWeaponItem, linkItem, setUnitInsignia
        // sont tous d'effet LOCAL depuis v2.02 : ne fonctionnent pas depuis le serveur
        // sur une unité distante. On délègue TOUT l'inventaire à LL_fnc_applyLocalLoadout
        // qui s'exécutera sur le client propriétaire où l'unité est bien locale.
        [_unit, _u, _pWeapon, _pMag, _hWeapon, _hMag, _sWeapon, _assigned]
            remoteExec ["LL_fnc_applyLocalLoadout", owner _unit];

        // Flag posé immédiatement côté serveur pour éviter le double-traitement
        // dans les itérations suivantes. LL_fnc_applyLocalLoadout le pose aussi côté client.
        _unit setVariable ["LL_LoadoutSet", true, true];
    };
};

// --- BOUCLE DE SCAN ÉLARGIE (Groupe complet, compatible serveur dédié) ---
// On se base sur player_00 (leader fixé) plutôt que sur player
// qui est objNull sur un serveur dédié et empecherait tout traitement.
private _groupLeader = missionNamespace getVariable ["player_00", objNull];
if (isNull _groupLeader) exitWith {
    diag_log "[LL][ERROR] initPlayerLoadout: player_00 introuvable, annulation.";
};

// ============================================================================
// DEUXIÈME PASSE DE VÉRIFICATION (T+90s, en parallèle de la boucle principale)
// Sécurité pour les joueurs qui se connectent après le démarrage ou qui auraient
// été manqués lors de la première passe (groupe pas encore constitué, etc.).
// - S'ils ont déjà LL_LoadoutSet = true : on ne fait rien.
// - S'ils n'ont pas le loadout : on l'applique via _fnc_applyVisuals.
// _fnc_applyVisuals et les pools sont passés comme arguments car les spawns
// s'exécutent dans un scope isolé sans accès aux variables privées du parent.
// ============================================================================
[_groupLeader, _fnc_applyVisuals, _uniforms, _helmets, _backpacks, _vests, _cagoules, _fn_shuffle] spawn {
    params ["_grpLeader", "_applyFn", "_unis", "_helms", "_bpacks", "_vs", "_cags", "_shuffleFn"];

    sleep 90; // Attendre que tous les joueurs soient connectés et groupés

    private _toCheck = (units (group _grpLeader)) select {
        alive _x && !(_x getVariable ["LL_LoadoutSet", false])
    };

    if (count _toCheck == 0) exitWith {
        diag_log "[LL][initPlayerLoadout] 2ème passe T+90s : OK, tous les joueurs ont leur loadout.";
    };

    diag_log format ["[LL][initPlayerLoadout] 2ème passe T+90s : %1 unité(s) sans loadout, traitement...", count _toCheck];

    // Réinitialiser des pools indépendants pour cette passe
    private _su = _unis call _shuffleFn;
    private _sh = _helms call _shuffleFn;
    private _sb = _bpacks call _shuffleFn;
    private _sv = _vs call _shuffleFn;
    private _sc = _cags call _shuffleFn;

    {
        private _unit = _x;
        private _varName = str _unit;

        private _u = _su select 0; _su deleteAt 0;
        if (count _su == 0) then { _su = _unis call _shuffleFn; };

        private _v = _sv select 0; _sv deleteAt 0;
        if (count _sv == 0) then { _sv = _vs call _shuffleFn; };

        private _b = _sb select 0; _sb deleteAt 0;
        if (count _sb == 0) then { _sb = _bpacks call _shuffleFn; };

        private _h = _sh select 0; _sh deleteAt 0;
        if (count _sh == 0) then { _sh = _helms call _shuffleFn; };

        private _c = _sc select 0; _sc deleteAt 0;
        if (count _sc == 0) then { _sc = _cags call _shuffleFn; };

        [_unit, _varName, _u, _v, _b, _h, _c] call _applyFn;
    } forEach _toCheck;

    diag_log "[LL][initPlayerLoadout] 2ème passe T+90s : terminé.";
};

private _endTime = time + 300;
while { time < _endTime } do {
    
    // Toutes les unités vivantes du groupe (I.A et joueurs) non encore traitées
    private _toProcess = units (group _groupLeader) select {
        alive _x &&
        !(_x getVariable ["LL_LoadoutSet", false])
    };

    {
        private _unit = _x;
        private _varName = str _unit;
        
        private _u = _shuffledUniforms select 0; _shuffledUniforms deleteAt 0;
        if (count _shuffledUniforms == 0) then { _shuffledUniforms = _uniforms call _fn_shuffle; };
        
        private _v = "";
        if (_varName == "player_04" || _varName find "Infirmier" != -1 || _unit getUnitTrait "Medic") then {
            private _mv = _shuffledVests select { (_x find "medical") != -1 };
            if (count _mv > 0) then { _v = _mv select 0; _shuffledVests = _shuffledVests - [_v]; };
        } else {
            if (_varName in ["player_00", "player_01"] || _varName find "Chef" != -1 || leader group _unit == _unit) then {
                private _tlv = _shuffledVests select { (_x find "_tl") != -1 };
                if (count _tlv > 0) then { _v = _tlv select 0; _shuffledVests = _shuffledVests - [_v]; };
            };
        };
        if (_v == "") then { _v = _shuffledVests select 0; _shuffledVests deleteAt 0; };
        if (count _shuffledVests == 0) then { _shuffledVests = _vests call _fn_shuffle; };

        private _b = _shuffledBackpacks select 0; _shuffledBackpacks deleteAt 0;
        if (count _shuffledBackpacks == 0) then { _shuffledBackpacks = _backpacks call _fn_shuffle; };

        private _h = _shuffledHelmets select 0; _shuffledHelmets deleteAt 0;
        if (count _shuffledHelmets == 0) then { _shuffledHelmets = _helmets call _fn_shuffle; };

        private _c = _shuffledCagoules select 0; _shuffledCagoules deleteAt 0;
        if (count _shuffledCagoules == 0) then { _shuffledCagoules = _cagoules call _fn_shuffle; };
        
        // call (pas spawn) : _fnc_applyVisuals n'a pas de sleep, inutile de spawner.
        // Traitement séquentiel = pas de race condition sur les tableaux shufflés.
        [_unit, _varName, _u, _v, _b, _h, _c] call _fnc_applyVisuals;

    } forEach _toProcess;

    sleep 2;
};