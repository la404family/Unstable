/*
 * LL_fnc_manageSkills
 *
 * Description:
 *   Boucle infinie ajustant les capacités (skills) des I.A. en fonction de
 *   leur faction.  Tourne sur toutes les machines (Serveur, Clients,
 *   Headless Clients) mais ne modifie que les I.A. locales à cette machine.
 *
 *   Les compétences ne sont appliquées qu'une seule fois par unité
 *   (variable LL_skillsApplied) pour éviter de ré-randomiser la précision
 *   à chaque passage de la boucle.
 *
 *   Factions gérées :
 *     — OPFOR / Indépendants : soldats de faible niveau, fuites interdites
 *     — BLUFOR standard       : soldats réguliers
 *     — BLUFOR spécialistes   : player_02, player_03 — précision de sniper
 *
 * Arguments:
 *   Aucun — boucle infinie, à lancer via spawn
 *
 * Return Value:
 *   Aucun
 *
 * Locality:
 *   Toutes les machines (serveur, clients, Headless Clients)
 *   — traite uniquement les I.A. locales (local _x)
 *
 * Public:
 *   Non
 *
 * Example:
 *   [] spawn LL_fnc_manageSkills;
 */

#include "..\macros.hpp"

if (DEBUG_MODE) then {
    diag_log "[LL] Démarrage du gestionnaire de compétences (skills) des I.A.";
};

while { true } do {
    {
        private _unit = _x;

        // Filtres : vivant, local, I.A. uniquement
        if (!alive _unit)    then { continue };
        if (!local _unit)    then { continue };
        if (isPlayer _unit)  then { continue };

        // Appliquer une seule fois par unité
        if (_unit getVariable ["LL_skillsApplied", false]) then { continue };

        private _side = side _unit;

        // ----------------------------------------------------------------
        // OPFOR (East) — soldats de faible niveau
        // ----------------------------------------------------------------
        if (_side == east) then {
            _unit setSkill ["aimingAccuracy", 0.10 + random 0.15];
            _unit setSkill ["aimingShake",    0.10 + random 0.20];
            _unit setSkill ["aimingSpeed",    0.10 + random 0.30];
            _unit setSkill ["spotDistance",   0.10 + random 0.50];
            _unit setSkill ["spotTime",       0.10 + random 0.40];
            _unit setSkill ["courage",        1];
            _unit setSkill ["reloadSpeed",    0.60];
            _unit setSkill ["commanding",     0.40];
            _unit setSkill ["general",        0.50];
            _unit allowFleeing 0;

            _unit setVariable ["LL_skillsApplied", true];

            if (DEBUG_MODE) then {
                diag_log format ["[LL][manageSkills] OPFOR : %1 (%2)", _unit, typeOf _unit];
            };

            continue;
        };

        // ----------------------------------------------------------------
        // BLUFOR (West) & INDÉPENDANT (Resistance) — soldats de très bons niveaux
        // ----------------------------------------------------------------
        if (_side == west || _side == independent || _side == resistance) then {
            // Détection automatique des rôles
            private _roleDesc = toLower (roleDescription _unit);
            private _classLower = toLower (typeOf _unit);
            private _wepLower = toLower (primaryWeapon _unit);

            // 1. Détection du rôle de sniper / tireur d'élite (Sniper / Marksman)
            private _isSniper = (_roleDesc find "sniper" >= 0) || (_roleDesc find "marksman" >= 0) || (_roleDesc find "précision" >= 0) || (_roleDesc find "precision" >= 0) || (_roleDesc find "élite" >= 0) || (_roleDesc find "elite" >= 0) ||
                                (_classLower find "sniper" >= 0) || (_classLower find "marksman" >= 0) || (_classLower find "ghillie" >= 0) || (_classLower find "sharpshooter" >= 0) || (_classLower find "spotter" >= 0) ||
                                (_wepLower find "srifle_" == 0) || (_wepLower find "dmr_" >= 0) || (_wepLower find "sniper" >= 0) || (_wepLower find "m24" >= 0) || (_wepLower find "m40" >= 0) || (_wepLower find "svd" >= 0);

            // 2. Détection du rôle de mitrailleur (Autorifleman / Machine Gunner)
            private _isMitrailleur = false;
            if (!_isSniper) then {
                _isMitrailleur = (_roleDesc find "autorifleman" >= 0) || (_roleDesc find "machinegunner" >= 0) || (_roleDesc find "mitrailleur" >= 0) || (_roleDesc find "mg" >= 0) || (_roleDesc find "lmg" >= 0) ||
                                  (_classLower find "heavygunner" >= 0) || (_classLower find "machinegunner" >= 0) || (_classLower find "autorifleman" >= 0) || (_classLower find "soldier_ar" >= 0) || (_classLower find "_ar" >= 0) || (_classLower find "_mg" >= 0) || (_classLower find "support" >= 0) ||
                                  (_wepLower find "lmg_" >= 0) || (_wepLower find "minimi" >= 0) || (_wepLower find "m249" >= 0) || (_wepLower find "m240" >= 0) || (_wepLower find "pkp" >= 0) || (_wepLower find "pkm" >= 0) || (_wepLower find "mg3" >= 0) || (_wepLower find "rpk" >= 0);
            };

            // 3. Détection du rôle de médecin (Medic)
            private _isMedic = false;
            if (!_isSniper && !_isMitrailleur) then {
                _isMedic = (_unit getUnitTrait "medical") ||
                           (_roleDesc find "medic" >= 0) || (_roleDesc find "medecin" >= 0) || (_roleDesc find "soigneur" >= 0) || (_roleDesc find "secouriste" >= 0) || (_roleDesc find "corpsman" >= 0) ||
                           (_classLower find "medic" >= 0) || (_classLower find "corpsman" >= 0);
            };

            // 4. Détection du rôle de chef de groupe / d'équipe (Leader / Officer)
            private _isLeader = false;
            if (!_isSniper && !_isMitrailleur && !_isMedic) then {
                _isLeader = (_roleDesc find "leader" >= 0) || (_roleDesc find "chef" >= 0) || (_roleDesc find "officier" >= 0) || (_roleDesc find "officer" >= 0) || (_roleDesc find "commandant" >= 0) || (_roleDesc find "commander" >= 0) ||
                            (_classLower find "officer" >= 0) || (_classLower find "squadleader" >= 0) || (_classLower find "teamleader" >= 0) || (_classLower find "_sl" >= 0) || (_classLower find "_tl" >= 0);
            };

            // --- Attribution des compétences selon le rôle ---
            if (_isSniper) then {
                // Sniper / Marksman : létalité maximale (mortel)
                _unit setSkill ["aimingAccuracy", 0.85 + random 0.15]; // 0.85 à 1.00 (mortel !)
                _unit setSkill ["aimingShake",    0.85 + random 0.15]; // 0.85 à 1.00
                _unit setSkill ["aimingSpeed",    0.75 + random 0.15];
                _unit setSkill ["spotDistance",   0.95 + random 0.05];
                _unit setSkill ["spotTime",       0.95 + random 0.05];
                _unit setSkill ["courage",        1.0];
                _unit setSkill ["reloadSpeed",    0.85];
                _unit setSkill ["commanding",     0.70];
                _unit setSkill ["general",        0.95];

                if (DEBUG_MODE) then {
                    diag_log format ["[LL][manageSkills] Tireur d'élite (West/Indep) : %1 (%2)", _unit, typeOf _unit];
                };
            } else {
                if (_isLeader) then {
                    // Chef de groupe : meneur d'hommes de bon niveau
                    _unit setSkill ["aimingAccuracy", 0.55 + random 0.15]; // 0.55 à 0.70
                    _unit setSkill ["aimingShake",    0.60 + random 0.15];
                    _unit setSkill ["aimingSpeed",    0.60 + random 0.15];
                    _unit setSkill ["spotDistance",   0.80 + random 0.10];
                    _unit setSkill ["spotTime",       0.80 + random 0.10];
                    _unit setSkill ["courage",        1.0];
                    _unit setSkill ["reloadSpeed",    0.80];
                    _unit setSkill ["commanding",     0.90 + random 0.10]; // 0.90 à 1.00 (commandant)
                    _unit setSkill ["general",        0.85];

                    if (DEBUG_MODE) then {
                        diag_log format ["[LL][manageSkills] Chef de groupe (West/Indep) : %1 (%2)", _unit, typeOf _unit];
                    };
                } else {
                    if (_isMitrailleur) then {
                        // Mitrailleur : dispersion de tir équilibrée, rechargement rapide
                        _unit setSkill ["aimingAccuracy", 0.45 + random 0.15]; // 0.45 à 0.60
                        _unit setSkill ["aimingShake",    0.50 + random 0.15];
                        _unit setSkill ["aimingSpeed",    0.55 + random 0.15];
                        _unit setSkill ["spotDistance",   0.75 + random 0.15];
                        _unit setSkill ["spotTime",       0.70 + random 0.15];
                        _unit setSkill ["courage",        1.0];
                        _unit setSkill ["reloadSpeed",    0.85]; // rapide pour LMG
                        _unit setSkill ["commanding",     0.60];
                        _unit setSkill ["general",        0.75];

                        if (DEBUG_MODE) then {
                            diag_log format ["[LL][manageSkills] Mitrailleur (West/Indep) : %1 (%2)", _unit, typeOf _unit];
                        };
                    } else {
                        if (_isMedic) then {
                            // Médecin : courage maximal et bon niveau général
                            _unit setSkill ["aimingAccuracy", 0.50 + random 0.15]; // 0.50 à 0.65
                            _unit setSkill ["aimingShake",    0.60 + random 0.15];
                            _unit setSkill ["aimingSpeed",    0.60 + random 0.15];
                            _unit setSkill ["spotDistance",   0.70 + random 0.15];
                            _unit setSkill ["spotTime",       0.70 + random 0.15];
                            _unit setSkill ["courage",        1.0]; // courage max pour soigner
                            _unit setSkill ["reloadSpeed",    0.80];
                            _unit setSkill ["commanding",     0.65];
                            _unit setSkill ["general",        0.80];

                            if (DEBUG_MODE) then {
                                diag_log format ["[LL][manageSkills] Médecin (West/Indep) : %1 (%2)", _unit, typeOf _unit];
                            };
                        } else {
                            // Soldat standard (Rifleman, etc.) : très bon niveau général
                            _unit setSkill ["aimingAccuracy", 0.55 + random 0.15]; // 0.55 à 0.70
                            _unit setSkill ["aimingShake",    0.60 + random 0.15];
                            _unit setSkill ["aimingSpeed",    0.60 + random 0.15];
                            _unit setSkill ["spotDistance",   0.75 + random 0.15];
                            _unit setSkill ["spotTime",       0.75 + random 0.15];
                            _unit setSkill ["courage",        1.0];
                            _unit setSkill ["reloadSpeed",    0.80];
                            _unit setSkill ["commanding",     0.60];
                            _unit setSkill ["general",        0.75];

                            if (DEBUG_MODE) then {
                                diag_log format ["[LL][manageSkills] Soldat régulier (West/Indep) : %1 (%2)", _unit, typeOf _unit];
                            };
                        };
                    };
                };
            };

            _unit allowFleeing 0;
            _unit setVariable ["LL_skillsApplied", true];

            continue;
        };

        // Civils (civilian) et autres factions — pas de modification de skills
    } forEach allUnits;

    sleep 60;
};
