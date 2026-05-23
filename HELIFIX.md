# HELIFIX — Documentation technique de fn_requestHelicopter.sqf

> Référence interne pour comprendre les choix de conception, les pièges SQF évités,  
> et la logique de chaque phase de la mission CAS.

---

## Architecture générale

La fonction est divisée en **5 phases distinctes** + une section de configuration.  
L'exécution principale s'effectue dans un `spawn` pour ne pas bloquer le serveur.

```
┌─────────────────────────────────────────────┐
│ SERVEUR (code synchrone)                    │
│  1. Garde (verrou TAG_AirSupport_Active)    │
│  2. Sanitize position                       │
│  3. Création hélicoptère (CUP_I_CH47F_RACS) │
│  4. Création équipage (createVehicleCrew)   │
│  5. Configuration comportement              │
│  6. spawn → THREAD DE VOL                  │
└─────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ THREAD DE VOL (spawn asynchrone)            │
│  Phase 1 : Approche (WP MOVE)              │
│  Phase 2 : Orbite d'attaque (WP LOITER)    │
│            + Boucle radar (reveal)          │
│  Phase 3 : RTB (WP MOVE [0,0,0])           │
│  Phase 4 : Nettoyage hors champ            │
└─────────────────────────────────────────────┘
```

---

## Section 1 — Paramètres et signature d'appel

**Signature attendue (depuis fn_addHelicopterActions.sqf) :**
```sqf
["CAS", getPos player, player, _target, _actionId] remoteExec ["LL_fnc_requestHelicopter", 2]
```

**params déclarés dans la fonction :**
| Index | Nom            | Type    | Valeur par défaut |
|-------|---------------|---------|-------------------|
| 0     | `_supportType` | STRING  | `"CAS"`           |
| 1     | `_targetPos`   | ARRAY   | `[0,0,0]`         |
| 2     | `_caller`      | OBJECT  | `objNull`         |
| 3     | `_actionTarget`| OBJECT  | `objNull`         |
| 4     | `_actionId`    | NUMBER  | `-1`              |

> ⚠️ **Erreur historique #1** : La refonte avait réduit à 2 paramètres (`_targetPos`, `_caller`).  
> Résultat : `"CAS"` (string) était reçu comme `_targetPos` (array attendu) → **Error Params: Type Tableau, Objet attendu**.

---

## Section 2 — Verrou TAG_AirSupport_Active

Un seul hélicoptère peut être actif en simultané.  
Le verrou est posé **avant** le spawn et libéré soit à la **Phase 3 (RTB)**, soit sur mort.

```sqf
missionNamespace setVariable ["TAG_AirSupport_Active", true, true];  // pose
missionNamespace setVariable ["TAG_AirSupport_Active", false, true]; // libère (RTB / mort)
```

> Le 3ème argument `true` = broadcast global (JIP-compatible).

---

## Section 3 — Création hélicoptère

**Classe utilisée :** `CUP_I_CH47F_RACS` (mod CUP, faction Independent/RACS)

```sqf
_heli = createVehicle [_helicoClass, _spawnPos, [], 0, "FLY"];
```

- Spawné à **2 000 m** de la cible dans une direction aléatoire, altitude **150 m**
- `"FLY"` : créé directement en vol, évite le crash au sol
- 5 tentatives maximum avant `exitWith` avec message d'erreur

> ⚠️ **Erreur historique #2** : La classe `"B_AMF_Heli_Transport_01_F"` (mod AMF non chargé)  
> provoquait **5 échecs consécutifs** → "Impossible de créer l'hélicoptère".

---

## Section 4 — Équipage RACS (Independent)

**Méthode choisie : `createVehicleCrew _heli`**

```sqf
createVehicleCrew _heli;
private _crew    = crew _heli;
private _pilot   = driver _heli;
private _copilot = _heli turretUnit [0];
private _gunners = _crew select { _x != _pilot && { _x != _copilot } };
```

**Pourquoi `createVehicleCrew` plutôt que `createGroup + createUnit` :**
- Crée automatiquement l'équipage **RACS (independent)** natif du CH47F
- Évite de hardcoder des classnames CUP potentiellement incorrects (`CUP_I_RACS_Pilot_F` etc.)
- Le groupe créé est déjà **Independent** — pas besoin de `joinSilent` + `deleteGroup`

---

## Section 5 — Configuration comportement (la partie critique pour le tir)

### Problème central

ArmA 3 gère le **comportement** (`setBehaviour`) au niveau du groupe entier.  
Si le groupe est en `"CARELESS"`, les artilleurs ne cherchent pas de cibles activement.  
Si le groupe est en `"COMBAT"`, le **pilote dévie** de ses waypoints pour esquiver.

### Solution retenue : un seul groupe + `disableAI "FSM"` sur pilotes uniquement

```sqf
_group setBehaviour  "CARELESS";   // pilote suit ses WP sans dévier
_group setCombatMode "RED";        // artilleurs tirent à vue quand cible révélée

// Pilotes : FSM désactivé → ignorent les stimuli de combat
{ _x disableAI "FSM"; _x allowDamage false; } forEach [_pilot, _copilot];

// Artilleurs : FSM actif + compétences max
{ 
    private _g = _x;
    _g setSkill 1;
    { _g setSkill [_x, 1.0]; } forEach ["aimingAccuracy", ...];
} forEach _gunners;
```

> ⚠️ **Erreur historique #3 (bug setSkill)** : Le code original utilisait `_x setSkill [_x, 1.0]`  
> dans un `forEach` imbriqué. Le `_x` interne (nom de compétence, STRING) **écrasait** le `_x` externe  
> (artilleur, OBJECT) → **Error setskill: Type Chaîne, Objet attendu**.  
> **Fix** : `private _g = _x` avant le forEach interne.

---

## Section 6 — Phase 2 : Boucle radar et forçage du tir

```sqf
while {time < _endTime && alive _heli} do {
    private _nearEnemies = _heli nearEntities [["Man", "Car", "Tank"], 600];
    {
        if (side _x == east) then {   // OPFOR uniquement, pas les indépendants alliés
            _group reveal [_x, 4];    // 4 = connaissance totale de la position ennemie
        };
    } forEach _nearEnemies;
    sleep 5;
};
```

**Pourquoi `reveal [_x, 4]` :**
- Niveau 4 = l'IA "sait exactement où est l'ennemi" → engagement immédiat
- Contourne le délai de détection naturel
- Fonctionne même avec `disableAI "FSM"` sur les pilotes

**Pourquoi `side _x == east` et non `== independent` :**
- Le groupe artilleur EST independent (RACS)
- Révéler les independents reviendrait à se cibler soi-même

---

## Section 7 — Waypoint LOITER

```sqf
_wp2 setWaypointType         "LOITER";
_wp2 setWaypointLoiterType   "CIRCLE";
_wp2 setWaypointLoiterRadius 250;
_wp2 setWaypointCombatMode   "RED";   // override local du waypoint
```

Le `setWaypointCombatMode "RED"` sur le waypoint LOITER est un override supplémentaire  
au niveau du waypoint (en plus du `_group setCombatMode "RED"`). Double garantie.

---

## Checklist de debug en jeu (RPT)

Lignes à chercher dans le RPT (`%LOCALAPPDATA%\Arma 3\Arma3_x64_xxxx.rpt`) :

| Ligne RPT                              | Signification                        |
|---------------------------------------|--------------------------------------|
| `[LL][HELI] Hélicoptère créé : xxx`   | ✅ Spawn réussi                      |
| `[LL][HELI] Équipage : 4 membres`     | ✅ Crew créé (pilote+copilote+2 gunners) |
| `[LL][HELI][ERROR] Impossible de créer` | ❌ Classe introuvable / mod absent  |
| `[LL][HELI] Mission CAS terminée`     | ✅ Fin propre                        |

---

## Historique des corrections

| # | Erreur ArmA               | Cause                              | Fix                                   |
|---|---------------------------|------------------------------------|---------------------------------------|
| 1 | `Error setskill: Type Chaîne` | `_x` shadowing dans forEach imbriqué | `private _g = _x` avant le forEach |
| 2 | `Error Params: Type Tableau` | params réduits à 2 au lieu de 5   | Restauration des 5 paramètres         |
| 3 | `Sound soutien01 not found` | Sons non déclarés dans CfgSounds  | Suppression des appels son            |
| 4 | `Impossible de créer l'hélico` | Classe `B_AMF_Heli_Transport_01_F` (mod absent) | Retour à `CUP_I_CH47F_RACS` |
| 5 | Hélico arrive mais n'attaque pas | `createGroup [WEST]` + mauvais comportement | `createVehicleCrew` + `reveal [_x, 4]` |
