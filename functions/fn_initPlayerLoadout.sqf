/*
 * LL_fnc_initPlayerLoadout
 *
 * Description:
 * Gère l'apparence des unités et réapprovisionne instantanément en munitions.
 * Version Expert : Sauvegarde dynamique des chargeurs engagés avant nettoyage.
 *
 * Locality:
 * Serveur uniquement
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

// Fonction de traitement d'une unité
private _fnc_applyVisuals = {
    params ["_unit", "_varName", "_u", "_v", "_b", "_h", "_c"];
    if (isNull _unit) exitWith {};

    // 1. SAUVEGARDE CRITIQUE : Trouver le type de chargeur de l'arme AVANT de tout effacer
    private _pWeapon = primaryWeapon _unit;
    private _sWeapon = secondaryWeapon _unit;
    private _hWeapon = handgunWeapon _unit;
    
    private _pMag = "";
    private _hMag = "";
    
    if (_pWeapon != "") then {
        private _currentPMags = primaryWeaponMagazine _unit;
        if (count _currentPMags > 0) then { _pMag = _currentPMags select 0; } else {
            private _compat = [_pWeapon] call BIS_fnc_compatibleMagazines;
            if (count _compat > 0) then { _pMag = _compat select 0; };
        };
    };
    if (_hWeapon != "") then {
        private _currentHMags = handgunMagazine _unit;
        if (count _currentHMags > 0) then { _hMag = _currentHMags select 0; };
    };

    // Parachute absolu pour votre M249 moddée si elle est vide au départ
    if (_pMag == "" && {toLower _pWeapon find "m249" != -1 || toLower _pWeapon find "lmg" != -1}) then {
        _pMag = "CUP_200Rnd_TE4_Red_Tracer_556x45_M249";
    };

    private _assigned = assignedItems _unit;
    private _cleanItems = items _unit select { !(_x in (magazines _unit)) };
    
    // 2. NETTOYAGE COMPLET
    removeUniform _unit;
    removeVest _unit;
    removeBackpack _unit;
    removeHeadgear _unit;
    removeGoggles _unit;
    removeAllItems _unit;

    // 3. REMPLACEMENT DES CONTENEURS
    _unit forceAddUniform _u;
    _unit addVest _v;
    _unit addBackpack _b;
    _unit addHeadgear _h;
    _unit addGoggles _c;

    // 4. DISTRIBUTION SÉCURISÉE (On force l'ajout dans l'inventaire)
    if (_pMag != "") then {
        for "_i" from 1 to 7 do { _unit addMagazine _pMag; }; // 7 dans les poches
        _unit addWeaponItem [_pWeapon, _pMag, true];        // 1 directement dans le canon de l'arme
    };
    
    if (_hMag != "") then {
        for "_i" from 1 to 2 do { _unit addMagazine _hMag; };
        _unit addWeaponItem [_hWeapon, _hMag, true];
    };

    if (_sWeapon != "") then {
        private _sMags = [_sWeapon] call BIS_fnc_compatibleMagazines;
        if (count _sMags > 0) then { _unit addMagazines [_sMags select 0, 2]; };
    };
    
    // 5. RESTAURATION
    { _unit linkItem _x; } forEach _assigned;
    { _unit addItem _x; } forEach _cleanItems;

    // Forcer l'unité à lever son arme chargée
    _unit selectWeapon _pWeapon;

    [_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
    _unit linkItem "NVGogglesB_blk_F";
    if (binocular _unit == "") then { _unit addWeapon "CUP_LRTV"; };

    _unit setVariable ["LL_LoadoutSet", true, true];
};

// --- BOUCLE DE SCAN ÉLARGIE (Groupe complet du joueur) ---
private _endTime = time + 300;
while { time < _endTime } do {
    
    // On cible toutes les unités vivantes de votre propre groupe 
    private _toProcess = units (group player) select {
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
        
        [_unit, _varName, _u, _v, _b, _h, _c] spawn _fnc_applyVisuals;
        
    } forEach _toProcess;

    sleep 2;
};