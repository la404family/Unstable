/*
 * LL_fnc_doorSecurity
 *
 * Description:
 *   Boucle serveur : ouvre les portes des bâtiments proches de toute unité
 *   I.A. non-BLUFOR (OPFOR, Indépendant, Civil) et les maintient ouvertes.
 *   Les noms d'animations de chaque bâtiment sont mis en cache sur
 *   l'objet pour éviter les appels répétés à animationNames.
 *
 * Arguments:
 *   Aucun
 *
 * Return Value:
 *   Aucun — boucle infinie, à lancer via spawn
 *
 * Locality:
 *   Server uniquement
 *
 * Public:
 *   Non
 *
 * Example:
 *   [] spawn LL_fnc_doorSecurity;
 */

if (!isServer) exitWith {};

private _OPEN_DIST   = 5;   // mètres — seuil de détection pour ouverture
private _CHECK_FREQ  = 0.5; // secondes entre deux passes

while { true } do {
    sleep _CHECK_FREQ;

    // Unités I.A. non-BLUFOR vivantes (OPFOR, Indépendant, Civil)
    private _aiUnits = allUnits select {
        alive _x &&
        !isPlayer _x &&
        side _x != west
    };

    if (_aiUnits isEqualTo []) then { continue };

    // Collecte des bâtiments uniques proches de toute I.A. (déduplication via pushBackUnique)
    private _nearBuildings = [];
    {
        {
            _nearBuildings pushBackUnique _x;
        } forEach (nearestObjects [getPos _x, ["Building", "House"], _OPEN_DIST + 3]);
    } forEach _aiUnits;

    // Traitement bâtiment par bâtiment
    {
        private _bldg = _x;

        // Récupérer (ou scanner et mettre en cache) les animations de portes
        private _doorAnims = _bldg getVariable "LL_doorAnims";

        if (isNil "_doorAnims") then {
            // Premier passage : découverte via animationNames (Arma 3 2.04+)
            // Filtre insensible à la casse sur le mot "door"
            _doorAnims = (animationNames _bldg) select { (toLower _x) find "door" >= 0 };
            _bldg setVariable ["LL_doorAnims", _doorAnims];
        };

        // Pas de porte détectée → ignorer définitivement ce bâtiment
        if (_doorAnims isEqualTo []) then { continue };

        // --- Logique ouverture ---
        private _hasAI = (_aiUnits findIf { _x distance _bldg < _OPEN_DIST }) != -1;

        if (_hasAI) then {
            // I.A. présente → ouvrir toutes les portes (instantané)
            {
                if (_bldg animationPhase _x < 0.9) then {
                    _bldg animate [_x, 1, true];
                };
            } forEach _doorAnims;
        };

    } forEach _nearBuildings;
};
