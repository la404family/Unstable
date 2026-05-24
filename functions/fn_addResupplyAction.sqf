#include "..\macros.hpp"

/*
 * LL_fnc_addResupplyAction
 *
 * Description:
 *   Ajoute un addAction sur une caisse de munitions livrée par hélicoptère (LIVRAISON).
 *   Le leader du joueur local peut ordonner aux IA de son groupe de venir se
 *   réapprovisionner en munitions 2 par 2 avec une animation immersive.
 *
 *   Séquence :
 *     1. Les IA viennent devant la caisse par paires (2 positions décalées)
 *     2. Animation accroupie de fouille (AinvPknlMstpSlayWrflDnon_medic)
 *     3. Rechargement réel des magazines depuis la caisse
 *     4. Éloignement pour laisser place à la paire suivante
 *     5. Regroupement final avec le leader (doFollow)
 *
 *   Le joueur leader se sert manuellement via l'inventaire standard.
 *
 * Paramètres:
 *   _this select 0 : OBJECT — la caisse de munitions (B_supplyCrate_F)
 *
 * Locality:
 *   Exécuté sur chaque client (remoteExec depuis le serveur).
 *   L'addAction est local au client, condition de visibilité gérée par le jeu.
 */

if (!hasInterface) exitWith {};

params [["_crate", objNull, [objNull]]];

if (isNull _crate) exitWith {};

// Variable pour empêcher l'utilisation multiple simultanée
_crate setVariable ["LL_Resupply_InProgress", false, true];

// ─── ADDACTION SUR LA CAISSE ─────────────────────────────────────────────────

_crate addAction [
    format ["<t color='#FFD700'>%1</t>", localize "STR_LL_Action_Resupply"],
    {
        params ["_target", "_caller", "_actionId"];

        // Vérification : pas déjà en cours
        if (_target getVariable ["LL_Resupply_InProgress", false]) exitWith {};
        _target setVariable ["LL_Resupply_InProgress", true, true];

        // Récupérer les IA du groupe (pas le joueur, pas les morts, à pied)
        private _squadAI = (units group _caller) select {
            !isPlayer _x && alive _x && vehicle _x == _x
        };

        if (count _squadAI == 0) exitWith {
            systemChat localize "STR_LL_Msg_Resupply_NoAI";
            _target setVariable ["LL_Resupply_InProgress", false, true];
        };

        // Le leader fait un geste de la main pour ordonner le mouvement
        _caller playActionNow "gestureAdvance";
        systemChat localize "STR_LL_Msg_Resupply_Start";

        // Retirer l'action pour éviter la réutilisation pendant l'opération
        _target removeAction _actionId;

        // ─── Séquence immersive en spawn ────────────────────────────────────
        [_target, _squadAI, _caller] spawn {
            params ["_crate", "_squadAI", "_leader"];

            private _cratePos = getPos _crate;
            private _crateDir = getDir _crate;

            // Positions de service devant la caisse, côté leader (±20° pour éviter le clipping)
            // Les 2 unités s'agenouillent face à la caisse, du même côté que le chef — tactiquement
            // elles gardent la caisse entre elles et la direction ennemie.
            // Fonction locale de rechargement de l'inventaire depuis la caisse
            private _fnc_resupply = {
                params ["_unit", "_crate"];
                if (!alive _unit || isNull _crate) exitWith {};

                // Recharger les magazines de l'arme principale
                private _pw = primaryWeapon _unit;
                if (_pw != "") then {
                    private _pwMags = getArray (configFile >> "CfgWeapons" >> _pw >> "magazines");
                    if (count _pwMags > 0) then {
                        private _magClass = _pwMags # 0;
                        private _currentCount = { _x == _magClass } count (magazines _unit);
                        private _needed = (8 - _currentCount) max 0;
                        for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                    };
                };

                // Recharger les magazines de l'arme de poing
                private _hw = handgunWeapon _unit;
                if (_hw != "") then {
                    private _hwMags = getArray (configFile >> "CfgWeapons" >> _hw >> "magazines");
                    if (count _hwMags > 0) then {
                        private _magClass = _hwMags # 0;
                        private _currentCount = { _x == _magClass } count (magazines _unit);
                        private _needed = (4 - _currentCount) max 0;
                        for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                    };
                };

                // Recharger les lanceurs (secondaire)
                private _sw = secondaryWeapon _unit;
                if (_sw != "") then {
                    private _swMags = getArray (configFile >> "CfgWeapons" >> _sw >> "magazines");
                    if (count _swMags > 0) then {
                        private _magClass = _swMags # 0;
                        private _currentCount = { _x == _magClass } count (magazines _unit);
                        private _needed = (3 - _currentCount) max 0;
                        for "_m" from 1 to _needed do { _unit addMagazine _magClass; };
                    };
                };

                // Grenades et fumigènes
                private _grenadeCount = { toLower _x find "grenade" != -1 } count (magazines _unit);
                if (_grenadeCount < 3) then {
                    for "_g" from 1 to (3 - _grenadeCount) do { _unit addMagazine "CUP_HandGrenade_M67"; };
                };
                private _smokeCount = { _x == "SmokeShell" } count (magazines _unit);
                if (_smokeCount < 2) then {
                    for "_s" from 1 to (2 - _smokeCount) do { _unit addMagazine "SmokeShell"; };
                };

                // Soins
                private _fak = { _x == "FirstAidKit" } count (items _unit);
                if (_fak < 3) then {
                    for "_f" from 1 to (3 - _fak) do { _unit addItem "FirstAidKit"; };
                };
            };

            // ─── Séquence 1 par 1 — Actions Moteur Natives ─────────────────────
            {
                private _unit = _x;
                if (alive _unit) then {
                    // L'unité va chercher une position très proche de la caisse (safe: 0.1m pour test)
                    private _dirToUnit = _cratePos getDir (getPos _unit);
                    private _approachPos = _crate getPos [0.1, _dirToUnit];

                    _unit setSpeedMode "NORMAL";
                    _unit setUnitPos "UP";
                    _unit doMove _approachPos;

                    // Attente de l'arrivée
                    private _timeout = time + 12;
                    waitUntil {
                        sleep 0.5;
                        !alive _unit || (_unit distance2D _approachPos < 0.2) || time > _timeout
                    };

                    if (alive _unit) then {
                        // Orienter l'IA explicitement vers le centre de la caisse
                        _unit doWatch _crate;
                        sleep 0.5;

                        // Remplir l'inventaire avant l'animation pour que ça serve pendant le mouvement
                        [_unit, _crate] call _fnc_resupply;

                        // Jouer l'action native moteur "ReloadMagazine".
                        // C'est l'animation et le son EXACTS et fluides associés à l'arme.
                        // remoteExecCall pour forcer l'exécution locale sur la machine de l'intelligence artificielle
                        [_unit, "ReloadMagazine"] remoteExecCall ["playActionNow", owner _unit];

                        // Attendre que l'animation de rechargement se passe
                        sleep 4.0;

                        // Restituer le contrôle à l'IA
                        _unit doWatch objNull;
                        _unit doFollow _leader;
                        
                        // Laisse l'IA dégager légèrement avant que la suivante n'arrive
                        sleep 1.0;
                    };
                };
            } forEach _squadAI;

            systemChat localize "STR_LL_Msg_Resupply_Done";

            // Réactiver l'action si la caisse existe toujours (permettre un 2e resupply)
            if (!isNull _crate && { alive _crate }) then {
                _crate setVariable ["LL_Resupply_InProgress", false, true];
                [_crate] call LL_fnc_addResupplyAction;
            };
        };
    },
    [],
    6.0,       // Priorité (au-dessus des actions)
    true,      // showWindow
    true,      // hideOnUse
    "",
    // Condition : joueur = leader, a des IA dans le groupe, pas de resupply en cours
    "leader group player == player && { !isPlayer _x } count (units group player) > 0 && !(_target getVariable ['LL_Resupply_InProgress', false])"
];
