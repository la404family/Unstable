/*
 * LL_fnc_initPlayerLoadout
 *
 * Description:
 *   Gère l'inventaire des unités jouables (BLUFOR).
 *   Distribue de manière aléatoire et diversifiée le loadout (uniforme, gilet, sac, casque, lunettes)
 *   à partir des listes d'options définies dans INFO.md.
 *   Garantit que chaque joueur reçoive un équipement unique ou distinct.
 *   Assigne les LNV (NVGogglesB_blk_F) et Jumelles (CUP_LRTV).
 *   Ajoute dynamiquement des munitions en fonction des armes équipées (principale, secondaire, de poing).
 *   Ajoute les FirstAidKits, grenades M67, fumigènes blancs et le matériel médical spécifique pour le Medic (player_04).
 *### LOADOUT : 
- Les gilets par balle des joueurs sont : 
        - CUP_V_JPC_medical_coy
        - CUP_V_JPC_tl_coy
        - CUP_V_JPC_weapons_coy
        - CUP_V_JPC_communicationsbelt_coy
        - CUP_V_JPC_Fastbelt_coy
        - CUP_V_JPC_lightbelt_coy
        - CUP_V_JPC_medicalbelt_coy
        - CUP_V_JPC_tlbelt_coy
        - CUP_V_JPC_weaponsbelt_coy
- les casques sont : 
        - CUP_H_OpsCore_Tan_SF
        - CUP_H_OpsCore_Tan
        - CUP_H_OpsCore_Tan_NohS
        - CUP_H_OpsCore_Grey_SF
        - CUP_H_OpsCore_Grey
        - CUP_H_OpsCore_Grey_NohS
- Les sacs sont : 
        - CUP_B_AssaultPack_Coyote
        - B_assaultPack_cbr
        - B_Kitbag_cbr
- Les vetements sont :
        - CUP_U_B_USMC_MCCUU_des_gloves
        - CUP_U_B_USMC_MCCUU_des_roll_2
        - CUP_U_B_USMC_MCCUU_des_roll_2_gloves
        - CUP_U_B_USMC_MCCUU_des_roll_pads
        - CUP_U_B_USMC_MCCUU_des_roll_2_pads_gloves
        - CUP_U_B_USMC_MCCUU_des_pads
        - CUP_U_B_USMC_MCCUU_des_pads_gloves
        - CUP_U_B_USMC_MCCUU_des_roll
        - CUP_U_B_USMC_MCCUU_des_roll_gloves
        - CUP_U_B_USMC_MCCUU_des_roll_pads
        - CUP_U_B_USMC_MCCUU_des_roll_pads_gloves
        - CUP_U_B_USMC_MCCUU_des
Les cagoules sont : 
        - CUP_G_Tan_Scarf_Shades_GPSCombo_Beard
        - CUP_G_Tan_Scarf_Shades_GPS_Beard
        - CUP_G_Tan_Scarf_GPS
        - CUP_G_TK_RoundGlasses_blk
        - CUP_G_Oakleys_Drk
        - CUP_G_Scarf_Face_Tan
        - G_Aviator
        - CUP_G_ESS_KHK_Scarf_Tan_GPS_Beard
        - CUP_G_ESS_KHK_Facewrap_Tan
        - G_Bandana_khk
LNV : NVGooglesB_blk_F
Jummelles : CUP_LRTV
 * Locality:
 *   Server
 */

if (!isServer) exitWith {};

// --- Définition des pools d'équipements issus de INFO.md ---
private _vests = [
    "CUP_V_JPC_medical_coy",
    "CUP_V_JPC_tl_coy",
    "CUP_V_JPC_weapons_coy",
    "CUP_V_JPC_communicationsbelt_coy",
    "CUP_V_JPC_Fastbelt_coy",
    "CUP_V_JPC_lightbelt_coy",
    "CUP_V_JPC_medicalbelt_coy",
    "CUP_V_JPC_tlbelt_coy",
    "CUP_V_JPC_weaponsbelt_coy"
];

private _helmets = [
    "CUP_H_OpsCore_Tan_SF",
    "CUP_H_OpsCore_Tan",
    "CUP_H_OpsCore_Tan_NohS",
    "CUP_H_OpsCore_Grey_SF",
    "CUP_H_OpsCore_Grey",
    "CUP_H_OpsCore_Grey_NohS"
];

private _backpacks = [
    "CUP_B_AssaultPack_Coyote",
    "B_assaultPack_cbr",
    "B_Kitbag_cbr"
];

private _uniforms = [
    "CUP_U_B_USMC_MCCUU_des_gloves",
    "CUP_U_B_USMC_MCCUU_des_roll_2",
    "CUP_U_B_USMC_MCCUU_des_roll_2_gloves",
    "CUP_U_B_USMC_MCCUU_des_roll_pads",
    "CUP_U_B_USMC_MCCUU_des_roll_2_pads_gloves",
    "CUP_U_B_USMC_MCCUU_des_pads",
    "CUP_U_B_USMC_MCCUU_des_pads_gloves",
    "CUP_U_B_USMC_MCCUU_des_roll",
    "CUP_U_B_USMC_MCCUU_des_roll_gloves",
    "CUP_U_B_USMC_MCCUU_des_roll_pads",
    "CUP_U_B_USMC_MCCUU_des_roll_pads_gloves",
    "CUP_U_B_USMC_MCCUU_des"
];

private _cagoules = [
    "CUP_G_Tan_Scarf_Shades_GPSCombo_Beard",
    "CUP_G_Tan_Scarf_Shades_GPS_Beard",
    "CUP_G_Tan_Scarf_GPS",
    "CUP_G_TK_RoundGlasses_blk",
    "CUP_G_Oakleys_Drk",
    "CUP_G_Scarf_Face_Tan",
    "G_Aviator",
    "CUP_G_ESS_KHK_Scarf_Tan_GPS_Beard",
    "CUP_G_ESS_KHK_Facewrap_Tan",
    "G_Bandana_khk"
];

// Fonction utilitaire de mélange de tableau (Fisher-Yates Shuffle)
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

// Mélange initial de tous les pools pour garantir l'aléatoire
private _shuffledUniforms  = _uniforms call _fn_shuffle;
private _shuffledHelmets   = _helmets call _fn_shuffle;
private _shuffledBackpacks = _backpacks call _fn_shuffle;
private _shuffledCagoules  = _cagoules call _fn_shuffle;
private _shuffledVests     = _vests call _fn_shuffle;

// Détection dynamique des joueurs définis dans l'éditeur (player_00 à player_XX)
private _players = [];
for "_i" from 0 to 99 do {
    private _suffix = if (_i < 10) then { format ["0%1", _i] } else { str _i };
    private _varName = format ["player_%1", _suffix];
    private _unit = missionNamespace getVariable [_varName, objNull];
    if (!isNull _unit) then {
        _players pushBack [_varName, _unit];
    };
};

// Fonction utilitaire pour ajouter des munitions compatibles de manière dynamique
private _fn_addMagsForWeapon = {
    params ["_unit", "_weapon", "_magCount", "_slotType"];
    if (_weapon == "") exitWith {};
    
    private _mags = [];
    switch (_slotType) do {
        case 1: { _mags = primaryWeaponMagazine _unit; };
        case 2: { _mags = handgunMagazine _unit; };
        case 3: { _mags = secondaryWeaponMagazine _unit; };
    };
    
    private _targetMag = "";
    if (count _mags > 0) then {
        _targetMag = _mags select 0;
    } else {
        private _compatibleMags = getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines");
        if (count _compatibleMags > 0) then {
            _targetMag = _compatibleMags select 0;
        };
    };
    
    if (_targetMag != "") then {
        for "_i" from 1 to _magCount do {
            _unit addItem _targetMag;
        };
    };
};

{
    _x params ["_varName", "_unit"];

    if (alive _unit) then {
        // --- 1. Sélection intelligente de l'équipement ---
        
        // Tenue (12 options -> unique pour 7 joueurs)
        private _selectedUniform = _shuffledUniforms select 0;
        _shuffledUniforms = _shuffledUniforms - [_selectedUniform];
        
        // Gilet (Gestion intelligente des rôles de Medic/TL)
        private _selectedVest = "";
        if (_varName == "player_04") then {
            // Medic: Prioriser les gilets médicaux
            private _medVests = _shuffledVests select { (_x find "medical") != -1 };
            if (count _medVests > 0) then {
                _selectedVest = _medVests select 0;
                _shuffledVests = _shuffledVests - [_selectedVest];
            };
        } else {
            if (_varName in ["player_00", "player_01"]) then {
                // Team Leader: Prioriser les gilets de commandement/TL
                private _tlVests = _shuffledVests select { (_x find "_tl") != -1 };
                if (count _tlVests > 0) then {
                    _selectedVest = _tlVests select 0;
                    _shuffledVests = _shuffledVests - [_selectedVest];
                };
            };
        };
        // Fallback si pas de rôle spécifique ou si le gilet spécifique n'est plus disponible
        if (_selectedVest == "") then {
            _selectedVest = _shuffledVests select 0;
            _shuffledVests = _shuffledVests - [_selectedVest];
        };

        // Sac (3 options -> cyclique/modulo avec mélange)
        private _selectedBackpack = _shuffledBackpacks select 0;
        _shuffledBackpacks = _shuffledBackpacks - [_selectedBackpack];
        if (count _shuffledBackpacks == 0) then { _shuffledBackpacks = _backpacks call _fn_shuffle; };

        // Casque (6 options -> cyclique/modulo avec mélange)
        private _selectedHelmet = _shuffledHelmets select 0;
        _shuffledHelmets = _shuffledHelmets - [_selectedHelmet];
        if (count _shuffledHelmets == 0) then { _shuffledHelmets = _helmets call _fn_shuffle; };

        // Cagoule/Lunettes (10 options -> unique pour 7 joueurs)
        private _selectedCagoule = _shuffledCagoules select 0;
        _shuffledCagoules = _shuffledCagoules - [_selectedCagoule];

        // --- 2. Application de l'équipement ---
        
        // Retrait des anciens conteneurs
        removeUniform _unit;
        removeVest _unit;
        removeBackpack _unit;
        removeHeadgear _unit;
        removeGoggles _unit;

        // Équipement de la tenue et des accessoires
        _unit forceAddUniform _selectedUniform;
        [_unit, "CSAT_ScimitarRegiment"] call BIS_fnc_setUnitInsignia;
        _unit addVest _selectedVest;
        _unit addBackpack _selectedBackpack;
        _unit addHeadgear _selectedHelmet;
        _unit addGoggles _selectedCagoule;

        // LNV (NVG) réglementaires
        _unit linkItem "NVGogglesB_blk_F";

        // Jumelles réglementaires
        private _currentBinoc = binocular _unit;
        if (_currentBinoc != "") then {
            _unit removeWeapon _currentBinoc;
        };
        _unit addWeapon "CUP_LRTV";

        // --- 3. Ravitaillement de l'inventaire ---

        // Munitions de manière dynamique en fonction des armes équipées
        [_unit, primaryWeapon _unit, 5, 1] call _fn_addMagsForWeapon;
        [_unit, handgunWeapon _unit, 3, 2] call _fn_addMagsForWeapon;
        [_unit, secondaryWeapon _unit, 2, 3] call _fn_addMagsForWeapon;

        // Équipements de soin, grenades M67 et fumigènes blancs
        for "_i" from 1 to 3 do { _unit addItem "FirstAidKit"; };
        for "_i" from 1 to 3 do { _unit addItem "CUP_HandGrenade_M67"; };
        for "_i" from 1 to 3 do { _unit addItem "SmokeShell"; };

        // Équipement spécifique Medic (player_04)
        if (_varName == "player_04") then {
            _unit addItemToBackpack "Medikit";
        };
    };
} forEach _players;

true
