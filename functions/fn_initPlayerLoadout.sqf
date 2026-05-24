/*
 * LL_fnc_initPlayerLoadout
 *
 * Description:
 *   - Applique un loadout visuel aléatoire aux joueurs
 *   - Donne des munitions standard à TOUTES les unités (Joueurs + IA)
 *
 * Locality: Serveur uniquement
 */

if (!isServer) exitWith {};

// --- Pools d'équipements (uniquement pour les joueurs) ---
private _vests = [ /* ... même liste ... */ 
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

private _uniforms = [ /* ... même liste ... */ 
    "CUP_U_B_USMC_MCCUU_des_gloves", "CUP_U_B_USMC_MCCUU_des_roll_2",
    "CUP_U_B_USMC_MCCUU_des_roll_2_gloves", "CUP_U_B_USMC_MCCUU_des_roll_pads",
    "CUP_U_B_USMC_MCCUU_des_roll_2_pads_gloves", "CUP_U_B_USMC_MCCUU_des_pads",
    "CUP_U_B_USMC_MCCUU_des_pads_gloves", "CUP_U_B_USMC_MCCUU_des_roll",
    "CUP_U_B_USMC_MCCUU_des_roll_gloves", "CUP_U_B_USMC_MCCUU_des_roll_pads",
    "CUP_U_B_USMC_MCCUU_des_roll_pads_gloves", "CUP_U_B_USMC_MCCUU_des"
];

private _cagoules = [ /* ... même liste ... */ 
    "CUP_G_Tan_Scarf_Shades_GPSCombo_Beard", "CUP_G_Tan_Scarf_Shades_GPS_Beard",
    "CUP_G_Tan_Scarf_GPS", "CUP_G_TK_RoundGlasses_blk", "CUP_G_Oakleys_Drk",
    "CUP_G_Scarf_Face_Tan", "G_Aviator", "CUP_G_ESS_KHK_Scarf_Tan_GPS_Beard",
    "CUP_G_ESS_KHK_Facewrap_Tan", "G_Bandana_khk"
];

// Fonction shuffle
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

// Fonction munitions (utilisée par tous)
private _fn_addMagsStandard = {
    params [["_unit", objNull], ["_weapon", ""], ["_count", 0]];

    if (isNull _unit || {_weapon == ""} || {_count <= 0}) exitWith {};

    private _mags = [_weapon] call BIS_fnc_compatibleMagazines;
    if (_mags isEqualTo []) exitWith {};

    private _mag = _mags select 0;

    for "_i" from 1 to _count do {
        if (_unit canAddItemToVest _mag) then {
            _unit addItemToVest _mag;
        } else {
            if (_unit canAddItemToBackpack _mag) then {
                _unit addItemToBackpack _mag;
            } else {
                if (_unit canAddItemToUniform _mag) then {
                    _unit addItemToUniform _mag;
                };
            };
        };
    };
};

// Fonction complète (visuel + munitions) → seulement pour les joueurs
private _fnc_applyFullLoadout = {
    params ["_unit", "_varName", "_u", "_v", "_b", "_h", "_c", "_fn_addMags"];

    if (isNull _unit) exitWith {};

    // Sauvegarde
    private _pWeapon = primaryWeapon _unit;
    private _sWeapon = secondaryWeapon _unit;
    private _hWeapon = handgunWeapon _unit;
    private _assigned = assignedItems _unit;
    private _cleanItems = items _unit select { !(_x in (magazines _unit)) };

    // Reset visuel
    removeUniform _unit;
    removeVest _unit;
    removeBackpack _unit;
    removeHeadgear _unit;
    removeGoggles _unit;
    removeAllItems _unit;

    _unit forceAddUniform _u;
    _unit addVest _v;
    _unit addBackpack _b;
    _unit addHeadgear _h;
    _unit addGoggles _c;

    sleep 1.5;

    // Munitions
    [_unit, _pWeapon, 8] call _fn_addMags;
    [_unit, _hWeapon, 3] call _fn_addMags;
    [_unit, _sWeapon, 2] call _fn_addMags;

    // Restauration
    { _unit linkItem _x; } forEach _assigned;
    { _unit addItem _x; } forEach _cleanItems;

    // Rechargement
    if (count (primaryWeaponMagazine _unit) == 0 && _pWeapon != "") then {
        private _pMags = [_pWeapon] call BIS_fnc_compatibleMagazines;
        if (count _pMags > 0) then { _unit addPrimaryWeaponItem (_pMags select 0); };
    };
    if (count (handgunMagazine _unit) == 0 && _hWeapon != "") then {
        private _hMags = [_hWeapon] call BIS_fnc_compatibleMagazines;
        if (count _hMags > 0) then { _unit addHandgunItem (_hMags select 0); };
    };

    [_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
    _unit linkItem "NVGogglesB_blk_F";
    if (binocular _unit == "") then { _unit addWeapon "CUP_LRTV"; };

    _unit setVariable ["LL_LoadoutSet", true, true];
};

// Fonction légère munitions uniquement (pour IA)
private _fnc_giveAmmoOnly = {
    params ["_unit", "_fn_addMags"];

    if (isNull _unit) exitWith {};

    private _pWeapon = primaryWeapon _unit;
    private _sWeapon = secondaryWeapon _unit;
    private _hWeapon = handgunWeapon _unit;

    removeAllItems _unit; // On vide d'abord pour éviter les doublons

    [_unit, _pWeapon, 8] call _fn_addMags;
    [_unit, _hWeapon, 3] call _fn_addMags;
    [_unit, _sWeapon, 2] call _fn_addMags;

    _unit setVariable ["LL_LoadoutSet", true, true];
};

// Initialisation des pools mélangés
private _shuffledUniforms  = _uniforms call _fn_shuffle;
private _shuffledHelmets   = _helmets call _fn_shuffle;
private _shuffledBackpacks = _backpacks call _fn_shuffle;
private _shuffledCagoules  = _cagoules call _fn_shuffle;
private _shuffledVests     = _vests call _fn_shuffle;

// Boucle principale
private _endTime = time + 300;

while { time < _endTime } do {
    private _toProcess = allUnits select {
        (side _x in [independent, resistance]) &&
        alive _x &&
        !(_x getVariable ["LL_LoadoutSet", false])
    };

    {
        private _unit = _x;
        private _varName = str _unit;
        private _isPlayerUnit = (_varName find "player_" == 0);

        if (_isPlayerUnit) then {
            // === JOUEURS : Full loadout visuel + munitions ===
            private _u = _shuffledUniforms select 0; _shuffledUniforms deleteAt 0;
            if (count _shuffledUniforms == 0) then { _shuffledUniforms = _uniforms call _fn_shuffle; };

            private _v = "";
            if (_varName == "player_04") then {
                private _mv = _shuffledVests select { (_x find "medical") != -1 };
                if (count _mv > 0) then { _v = _mv select 0; _shuffledVests deleteAt (_shuffledVests find _v); };
            } else {
                if (_varName in ["player_00", "player_01"]) then {
                    private _tlv = _shuffledVests select { (_x find "_tl") != -1 };
                    if (count _tlv > 0) then { _v = _tlv select 0; _shuffledVests deleteAt (_shuffledVests find _v); };
                };
            };
            if (_v == "") then {
                _v = _shuffledVests select 0; _shuffledVests deleteAt 0;
            };
            if (count _shuffledVests == 0) then { _shuffledVests = _vests call _fn_shuffle; };

            private _b = _shuffledBackpacks select 0; _shuffledBackpacks deleteAt 0;
            if (count _shuffledBackpacks == 0) then { _shuffledBackpacks = _backpacks call _fn_shuffle; };

            private _h = _shuffledHelmets select 0; _shuffledHelmets deleteAt 0;
            if (count _shuffledHelmets == 0) then { _shuffledHelmets = _helmets call _fn_shuffle; };

            private _c = _shuffledCagoules select 0; _shuffledCagoules deleteAt 0;
            if (count _shuffledCagoules == 0) then { _shuffledCagoules = _cagoules call _fn_shuffle; };

            [_unit, _varName, _u, _v, _b, _h, _c, _fn_addMagsStandard] spawn _fnc_applyFullLoadout;

        } else {
            // === IA : Munitions uniquement ===
            [_unit, _fn_addMagsStandard] spawn _fnc_giveAmmoOnly;
        };

    } forEach _toProcess;

    sleep 2;
};