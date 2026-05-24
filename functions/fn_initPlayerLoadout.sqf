/*
 * LL_fnc_initPlayerLoadout
 *
 * Description:
 *   Gère l'inventaire des unités jouables (BLUFOR).
 *   Distribue de manière aléatoire et diversifiée le loadout (uniforme, gilet, sac, casque, lunettes).
 *   S'assure que les munitions et l'équipement de base (FirstAidKit, grenades) sont bien présents.
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

// Fonction utilitaire de mélange
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

// Fonction pour ajouter des munitions
private _fnc_addMags = {
    params ["_unit", "_weapon", "_count"];
    if (_weapon == "") exitWith {};
    private _mag = (getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines")) select 0;
    for "_i" from 1 to _count do { _unit addItem _mag; };
};

// Fonction de traitement d'une unité
private _fnc_processUnit = {
    params ["_unit", "_varName"];
    
    // Attendre que l'unité ait ses armes de l'éditeur (timeout 5s)
    private _t = time + 5;
    waitUntil { primaryWeapon _unit != "" || time > _t };

    // Sélection de l'équipement
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

    // Application
    removeUniform _unit; removeVest _unit; removeBackpack _unit; removeHeadgear _unit; removeGoggles _unit;
    
    _unit forceAddUniform _u;
    _unit addVest _v;
    _unit addBackpack _b;
    _unit addHeadgear _h;
    _unit addGoggles _c;
    
    _unit linkItem "NVGogglesB_blk_F";
    _unit addWeapon "CUP_LRTV";

    // Un petit sleep pour laisser Arma enregistrer les conteneurs avant d'ajouter les items
    sleep 0.2;

    // Munitions
    [_unit, primaryWeapon _unit, 6] call _fnc_addMags;
    [_unit, handgunWeapon _unit, 3] call _fnc_addMags;
    
    // Équipement de base
    for "_i" from 1 to 3 do { _unit addItemToVest "FirstAidKit"; };
    for "_i" from 1 to 2 do { _unit addItemToVest "CUP_HandGrenade_M67"; };
    for "_i" from 1 to 2 do { _unit addItemToVest "SmokeShell"; };

    if (_varName == "player_04") then { _unit addItemToBackpack "Medikit"; };

    _unit setVariable ["LL_LoadoutSet", true, true];
};

// Boucle de scan
private _endTime = time + 300;
while { time < _endTime } do {
    private _toProcess = allUnits select {
        (side _x == independent || side _x == resistance) && 
        alive _x && 
        !(_x getVariable ["LL_LoadoutSet", false]) &&
        { (str _x) find "player_" == 0 }
    };

    if (_toProcess isEqualTo []) then {
        sleep 2;
    } else {
        {
            [_x, str _x] spawn _fnc_processUnit;
        } forEach _toProcess;
    };
};
