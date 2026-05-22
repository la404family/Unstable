/*
 * LL_fnc_initPlayerIdentity
 *
 * Description:
 *   Attribue à chaque unité indépendante (ex: player_00 … player_06) une
 *   identité unique : nom turc, arabe, africain ou indonésien, visage cohérent
 *   avec l'origine et voix anglaise accentuée.
 *   La diffusion vers les clients est assurée par LL_fnc_applyIdentity
 *   (JIP-safe via remoteExec avec flag _unit).
 *
 * Arguments:
 *   <NIL>
 *
 * Return Value:
 *   <NIL>
 *
 * Locality:
 *   Serveur uniquement
 *
 * Public:
 *   Non
 *
 * Example:
 *   [] call LL_fnc_initPlayerIdentity;
 */

if (!isServer) exitWith {};

// ── Re-application des identités à chaque (re)connexion joueur ───────────────
// Enregistré en premier pour ne manquer aucune connexion, même avant le waitUntil.
addMissionEventHandler ["PlayerConnected", {
    params ["_id", "_uid", "_name", "_jip", "_owner", "_idstr"];
    [_owner] spawn {
        params ["_ownerId"];
        // Attendre que les identités soient assignées ET que le joueur soit prêt
        waitUntil { !isNil "LL_g_usedPlayerNames" };
        sleep 3;

        private _allPlayersVars = [];
        for "_i" from 0 to 99 do {
            private _suffix = if (_i < 10) then { format ["0%1", _i] } else { str _i };
            private _varName = format ["player_%1", _suffix];
            private _unit = missionNamespace getVariable [_varName, objNull];
            if (!isNull _unit) then {
                _allPlayersVars pushBack _varName;
            };
        };

        {
            private _unit = missionNamespace getVariable [_x, objNull];
            if (!isNull _unit) then {
                private _identity = _unit getVariable ["LL_s_identity", []];
                if (count _identity >= 5) then {
                    _identity params ["_nameData", "_faceType", "_face", "_speaker", "_pitch", ["_beard", "", [""]]];
                    [_unit, _nameData, _face, _speaker, _pitch, _beard]
                        remoteExec ["LL_fnc_applyIdentity", _ownerId];
                };
            };
        } forEach _allPlayersVars;
    };
}];

// ── Pools de noms classés par origine ────────────────────────────────────────

private _names_turkish = [
    ["Mustafa Demir",    "Mustafa",   "Demir"],
    ["Ahmet Yılmaz",     "Ahmet",     "Yılmaz"],
    ["Mehmet Kaya",      "Mehmet",    "Kaya"],
    ["Emre Şahin",       "Emre",      "Şahin"],
    ["Can Öztürk",       "Can",       "Öztürk"],
    ["Hakan Yıldırım",   "Hakan",     "Yıldırım"],
    ["Oğuzhan Çelik",    "Oğuzhan",   "Çelik"],
    ["Kaan Arslan",      "Kaan",      "Arslan"],
    ["Burak Koç",        "Burak",     "Koç"],
    ["Volkan Aydın",     "Volkan",    "Aydın"],
    ["Onur Özdemir",     "Onur",      "Özdemir"]
];

private _names_arab = [
    ["Mehdi Benali",     "Mehdi",     "Benali"],
    ["Sofiane Haddad",   "Sofiane",   "Haddad"],
    ["Karim Mansouri",   "Karim",     "Mansouri"],
    ["Mohamed Trabelsi", "Mohamed",   "Trabelsi"],
    ["Walid Belkacem",   "Walid",     "Belkacem"],
    ["Hicham Bouzid",    "Hicham",    "Bouzid"],
    ["Adel Gharbi",      "Adel",      "Gharbi"],
    ["Nassim Saïdi",     "Nassim",    "Saïdi"],
    ["Rachid Ziani",     "Rachid",    "Ziani"],
    ["Adam Khayat",      "Adam",      "Khayat"],
    ["Rayane Meriah",    "Rayane",    "Meriah"]
];

private _names_african = [
    ["Moussa Diallo",    "Moussa",    "Diallo"],
    ["Mamadou Traoré",   "Mamadou",   "Traoré"],
    ["Ibrahim Keita",    "Ibrahim",   "Keita"],
    ["Sekou Diop",       "Sekou",     "Diop"],
    ["Ousmane Sy",       "Ousmane",   "Sy"],
    ["Bakary Sow",       "Bakary",    "Sow"],
    ["Ismaël Koné",      "Ismaël",    "Koné"],
    ["Kofi Mensah",      "Kofi",      "Mensah"],
    ["Amadi Achebe",     "Amadi",     "Achebe"],
    ["Jengo Okeke",      "Jengo",     "Okeke"],
    ["Kwame Nkrumah",    "Kwame",     "Nkrumah"]
];

private _names_indonesian = [
    ["Budi Santoso",     "Budi",      "Santoso"],
    ["Joko Widodo",      "Joko",      "Widodo"],
    ["Agus Harjono",     "Agus",      "Harjono"],
    ["Slamet Rahardjo",  "Slamet",    "Rahardjo"],
    ["Wawan Setiawan",   "Wawan",     "Setiawan"],
    ["Hendra Wijaya",    "Hendra",    "Wijaya"],
    ["Eko Prasetyo",     "Eko",       "Prasetyo"],
    ["Aditya Nugroho",   "Aditya",    "Nugroho"],
    ["Rian Hidayat",     "Rian",      "Hidayat"],
    ["Aris Budiman",     "Aris",      "Budiman"],
    ["Dedi Kusnadi",     "Dedi",      "Kusnadi"]
];

// ── Construction du pool typé complet ────────────────────────────────────────

private _allNamesTyped = [];
{ _allNamesTyped pushBack [_x, "Turkish"];    } forEach _names_turkish;
{ _allNamesTyped pushBack [_x, "Arab"];       } forEach _names_arab;
{ _allNamesTyped pushBack [_x, "African"];    } forEach _names_african;
{ _allNamesTyped pushBack [_x, "Indonesian"]; } forEach _names_indonesian;

// Cache des noms déjà attribués et du pool complet (session serveur uniquement)
LL_g_allNamesTyped = _allNamesTyped;
LL_g_usedPlayerNames = [];

// ── Sous-fonction locale : sélection d'une identité unique ───────────────────
// ── Grade par slot jouable ────────────────────────────────────────────────────
private _unitRoles = [];
for "_i" from 0 to 99 do {
    private _suffix = if (_i < 10) then { format ["0%1", _i] } else { str _i };
    private _varName = format ["player_%1", _suffix];
    private _unit = missionNamespace getVariable [_varName, objNull];
    if (!isNull _unit) then {
        private _rank = "PRIVATE";
        if (_varName == "player_00") then { _rank = "CORPORAL"; };
        if (_varName == "player_01") then { _rank = "SERGEANT"; };
        _unitRoles pushBack [_varName, _rank];
    };
};

// ── Traitement d'une unité : sélection d'identité + diffusion ─────────────────
// Pattern proven-working (porté depuis un code TAG_ précédent) :
// pool et rôles passés en params pour éviter les conflits de scope SQF.
private _fnc_processUnit = {
    params ["_unit", "_pool", "_roles"];

    // Sélection d'un nom unique dans le pool
    private _available = _pool select { !((_x select 0 select 0) in LL_g_usedPlayerNames) };
    if (_available isEqualTo []) then { LL_g_usedPlayerNames = []; _available = _pool; };
    private _entry    = selectRandom _available;
    private _nameData = _entry select 0;
    private _faceType = _entry select 1;
    LL_g_usedPlayerNames pushBack (_nameData select 0);

    // Visage cohérent avec l'origine
    private _faces = switch (_faceType) do {
        case "Turkish";
        case "Arab":      { ["PersianHead_A3_01","PersianHead_A3_02","PersianHead_A3_03",
                           "GreekHead_A3_01","GreekHead_A3_02","GreekHead_A3_03",
                           "GreekHead_A3_04","GreekHead_A3_05","GreekHead_A3_06"] };
        case "African":   { ["AfricanHead_01","AfricanHead_02","AfricanHead_03"] };
        case "Indonesian": { ["AsianHead_A3_01","AsianHead_A3_02","AsianHead_A3_03",
                            "TanoanHead_A3_01","TanoanHead_A3_02","TanoanHead_A3_03",
                            "TanoanHead_A3_04","TanoanHead_A3_05"] };
        default         { ["WhiteHead_01","WhiteHead_02","WhiteHead_03","WhiteHead_04",
                           "WhiteHead_05","WhiteHead_06","WhiteHead_07","WhiteHead_08",
                           "WhiteHead_09","WhiteHead_10","WhiteHead_11","WhiteHead_12",
                           "WhiteHead_13","WhiteHead_14","WhiteHead_15","WhiteHead_16",
                           "WhiteHead_17","WhiteHead_18","WhiteHead_19","WhiteHead_20",
                           "WhiteHead_21"] };
    };
    private _face  = selectRandom _faces;

    // Voix de joueur aléatoire entre Américain (1-5), Britannique (1-5) et Anglais d'Altis (1-5) avec variation de pitch (0.85 à 1.00)
    private _speakers = [
        "Male01ENG", "Male02ENG", "Male03ENG", "Male04ENG", "Male05ENG",
        "Male01ENGB", "Male02ENGB", "Male03ENGB", "Male04ENGB", "Male05ENGB",
        "Male01GRE", "Male02GRE", "Male03GRE", "Male04GRE", "Male05GRE"
    ];
    private _speaker = selectRandom _speakers;
    private _pitch = 0.85 + random 0.15;

    // Grade selon le slot (uniquement pour les unités jouables connues)
    {
        if ((missionNamespace getVariable [_x select 0, objNull]) isEqualTo _unit) exitWith {
            _unit setUnitRank (_x select 1);
        };
    } forEach _roles;

    // Barbe désactivée car elle utilise le slot de lunettes (goggles) et efface les cagoules du loadout
    private _beard = "";

    // Diffusion JIP-safe vers tous les clients
    [_unit, _nameData, _face, _speaker, _pitch, _beard]
        remoteExec ["LL_fnc_applyIdentity", 0, _unit];

    // Stockage global + drapeau pour éviter les réapplications inutiles
    _unit setVariable ["LL_s_identity",  [_nameData, _faceType, _face, _speaker, _pitch, _beard], true];
    _unit setVariable ["LL_IdentitySet", true, true];
};

// ── Boucle principale : scan des unités indépendantes ──────────────────────────
// • Première passe immédiate — les unités existantes sont traitées d'un coup.
// • Sortie anticipée immédiate si aucune unité n'est à traiter ou si tout a été traité.
// • Limite de 5 minutes au cas où des unités tardives ou JIP apparaîtraient (avec sleep de 2s).
private _endTime = time + 300;
while { time < _endTime } do {
    private _unprocessed = allUnits select {
        (side _x == independent || side _x == resistance) && 
        alive _x && 
        !(_x getVariable ["LL_IdentitySet", false])
    };

    if (_unprocessed isEqualTo []) exitWith {};

    {
        [_x, _allNamesTyped, _unitRoles] call _fnc_processUnit;
    } forEach _unprocessed;

    // Re-vérification immédiate après traitement de cette passe
    private _remaining = allUnits select {
        (side _x == independent || side _x == resistance) && 
        alive _x && 
        !(_x getVariable ["LL_IdentitySet", false])
    };
    if (_remaining isEqualTo []) exitWith {};

    sleep 2;
};
