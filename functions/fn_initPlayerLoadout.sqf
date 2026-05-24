/*
 * LL_fnc_initPlayerLoadout
 *
 * Description:
 *   Gère l'inventaire des unités jouables (BLUFOR).
 *   Distribue de manière aléatoire et diversifiée le loadout.
 *   Optimisé pour le multijoueur (Host, Clients et IA).
 *
 * Locality:
 *   Serveur uniquement (scanne et applique à toutes les unités)
 */

if (!isServer) exitWith {};

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

private _fn_shuffle = {
    private _arr = +_this;
    private _cnt = count _arr;
    for "_i" from _cnt - 1 to 1 step -1 do {
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

// Fonction de traitement interne
private _fnc_applyLoadout = {
    params ["_unit", "_varName", "_u", "_v", "_b", "_h", "_c"];

    // Nettoyage complet (Global)
    removeAllWeapons _unit;
    removeAllItems _unit;
    removeAllAssignedItems _unit;
    removeUniform _unit;
    removeVest _unit;
    removeBackpack _unit;
    removeHeadgear _unit;
    removeGoggles _unit;

    // Habillage (Global)
    _unit forceAddUniform _u;
    _unit addVest _v;
    _unit addBackpack _b;
    _unit addHeadgear _h;
    _unit addGoggles _c;

    // Attendre que les contenants soient synchronisés (Essentiel pour les clients distants)
    sleep 1.5;

    // Items de base (Global)
    [_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
    _unit linkItem "NVGogglesB_blk_F";
    _unit addWeapon "CUP_LRTV";
    _unit linkItem "ItemMap";
    _unit linkItem "ItemCompass";
    _unit linkItem "ItemWatch";
    _unit linkItem "ItemRadio";

    // Munitions
    private _mag = "CUP_30Rnd_556x45_Stanag";
    if (_varName == "player_05") then { _mag = "CUP_100Rnd_TE4_LRT4_White_Tracer_762x51_Belt_M"; };

    for "_i" from 1 to 6 do { _unit addItemToVest _mag; };
    for "_i" from 1 to 3 do { _unit addItemToUniform "FirstAidKit"; };
    for "_i" from 1 to 2 do { _unit addItemToVest "CUP_HandGrenade_M67"; };
    for "_i" from 1 to 2 do { _unit addItemToVest "SmokeShell"; };
    
    if (_varName == "player_04") then { _unit addItemToBackpack "Medikit"; };

    // Armes (Global)
    if (_varName == "player_05") then {
        _unit addWeapon "CUP_lmg_M60E4";
    } else {
        _unit addWeapon "CUP_arifle_Mk16_STD_FG_black";
        _unit addPrimaryWeaponItem "CUP_acc_ANPEQ_15_Black";
        _unit addPrimaryWeaponItem "CUP_optic_HoloBlack";
    };

    _unit addWeapon "CUP_hgun_Glock17_blk";
    for "_i" from 1 to 2 do { _unit addItemToUniform "CUP_17Rnd_9x19_glock17"; };

    _unit setVariable ["LL_LoadoutSet", true, true];
};

// Boucle de scan pour attraper tout le monde (Start + JIP)
private _endTime = time + 300;
while { time < _endTime } do {
    private _toProcess = allUnits select {
        (side _x == independent || side _x == resistance) && 
        alive _x && 
        !(_x getVariable ["LL_LoadoutSet", false]) &&
        { (str _x) find "player_" == 0 }
    };

    {
        private _unit = _x;
        private _varName = str _unit;

        // Sélection aléatoire
        private _u = _shuffledUniforms select 0; _shuffledUniforms = _shuffledUniforms - [_u];
        if (count _shuffledUniforms == 0) then { _shuffledUniforms = _uniforms call _fn_shuffle; };
        
        private _v = "";
        if (_varName == "player_04") then {
            private _mv = _shuffledVests select { (_x find "medical") != -1 };
            if (count _mv > 0) then { _v = _mv select 0; _shuffledVests = _shuffledVests - [_v]; };
        };
        if (_v == "") then { _v = _shuffledVests select 0; _shuffledVests = _shuffledVests - [_v]; };
        if (count _shuffledVests == 0) then { _shuffledVests = _vests call _fn_shuffle; };

        private _b = _shuffledBackpacks select 0; _shuffledBackpacks = _shuffledBackpacks - [_b];
        if (count _shuffledBackpacks == 0) then { _shuffledBackpacks = _backpacks call _fn_shuffle; };

        private _h = _shuffledHelmets select 0; _shuffledHelmets = _shuffledHelmets - [_h];
        if (count _shuffledHelmets == 0) then { _shuffledHelmets = _helmets call _fn_shuffle; };

        private _c = _shuffledCagoules select 0; _shuffledCagoules = _shuffledCagoules - [_c];
        if (count _shuffledCagoules == 0) then { _shuffledCagoules = _cagoules call _fn_shuffle; };

        // Exécution du traitement
        [_unit, _varName, _u, _v, _b, _h, _c] spawn _fnc_applyLoadout;
        
    } forEach _toProcess;

    sleep 2;
};
