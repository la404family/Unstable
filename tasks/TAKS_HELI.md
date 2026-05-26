# Intégrer l'Hélicoptère dans une Tâche — Guide de codage

Référence : `functions/fn_heliDispatch.sqf` · `functions/fn_heliManager.sqf`

---

## 1. Principe

L'hélicoptère est géré par une boucle FSM permanente (`LL_fnc_heliManager`) lancée une seule fois par `initServer.sqf`. Une tâche **ne crée jamais l'hélicoptère elle-même** : elle passe une requête au dispatcher et attend le résultat via les variables d'état globales.

```
fn_taskXX.sqf  ──────call──────▶  LL_fnc_heliDispatch
                                        │
                                   écrit LL_HELI_pending
                                        │
                              LL_fnc_heliManager (boucle)
                                   lit + exécute
```

---

## 2. API — Appel au dispatcher

```sqf
// Seule signature valide depuis une tâche
[_type, _pos, _caller, _priority] call LL_fnc_heliDispatch;
```

| Paramètre | Type | Valeur depuis une tâche |
|---|---|---|
| `_type` | String | `"CAS"` · `"LIVRAISON"` · `"VEHICULE"` · `"DEBARQUEMENT"` · `"EMBARQUEMENT"` |
| `_pos` | Array `[x,y,z]` | Position exacte de la mission |
| `_caller` | Object | `objNull` suffit si pas de joueur spécifique, sinon `leader (allPlayers select { alive _x })` |
| `_priority` | Number | **Toujours `2`** depuis une tâche (priorité mission > joueur) |

> **Règle absolue** : une tâche utilise toujours `_priority = 2`.  
> Priorité `1` est réservée aux actions joueur dans `fn_requestHelicopter.sqf`.

---

## 3. Variables d'état à lire

Ces variables sont publiées en broadcast par `fn_heliManager` — accessibles sur le serveur sans délai.

| Variable | Type | Signification |
|---|---|---|
| `LL_HELI_state` | String | État courant : `"IDLE"` `"APPROACHING"` `"CAS"` `"DELIVERING"` `"DEPLOYING"` `"EXTRACTING"` `"RTB"` |
| `LL_HELI_type` | String | Type de mission en cours |
| `LL_HELI_priority` | Number | Priorité de la mission courante (`0` = aucune) |
| `LL_HELI_obj` | Object | Référence au CH-47F actif (`objNull` si IDLE) |
| `TAG_AirSupport_Active` | Bool | `true` si un hélico est actif (compat ancien système) |
| `TAG_CAS_Cooldown_Until` | Number | `time` à partir duquel CAS est à nouveau disponible |

---

## 4. Attendre la fin d'une mission hélicoptère

Le dispatcher est **non-bloquant** : il écrit `LL_HELI_pending` et retourne immédiatement.  
Pour synchroniser la tâche avec la fin de la mission hélico, utiliser un `waitUntil` :

```sqf
// Déclencher
[_type, _pos, _caller, 2] call LL_fnc_heliDispatch;

// Attendre que le gestionnaire démarre la mission
waitUntil { sleep 0.5; (missionNamespace getVariable ["LL_HELI_state", "IDLE"]) != "IDLE" };

// Attendre la fin (retour à IDLE)
waitUntil { sleep 1; (missionNamespace getVariable ["LL_HELI_state", "IDLE"]) == "IDLE" };
```

> **Attention** : Ne jamais bloquer la boucle principale de la tâche sur ce `waitUntil` sans le mettre dans un `spawn {}` séparé.

---

## 5. Exemples complets

### 5.1 — CAS déclenché par une tâche (interruption d'un assaut ennemi)

```sqf
// Dans fn_taskXX.sqf, au moment où le joueur doit recevoir un appui CAS
[] spawn {
    private _casPos = getPos M_CAS_Zone_01;  // Game Logic dans l'éditeur
    private _leader = leader (allPlayers select { alive _x } select 0);

    // Demande CAS priorité mission (2 = peut interrompre un CAS joueur prio 1)
    ["CAS", _casPos, _leader, 2] call LL_fnc_heliDispatch;

    // Attendre début
    waitUntil { sleep 0.5; (missionNamespace getVariable ["LL_HELI_state", "IDLE"]) == "CAS" };

    // Attendre fin du CAS (retour IDLE = RTB terminé)
    waitUntil { sleep 1; (missionNamespace getVariable ["LL_HELI_state", "IDLE"]) == "IDLE" };

    // Enchaîner la suite de la tâche
    ["scenario", []] remoteExec ["LL_fnc_taskXX", 2];
};
```

### 5.2 — DÉBARQUEMENT de renforts comme condition de progression

```sqf
// La tâche attend que les renforts soient déployés avant de valider
[] spawn {
    private _lzPos = getPos Heliport_02;
    private _firstPlayer = allPlayers select { alive _x } select 0;

    ["DEBARQUEMENT", _lzPos, _firstPlayer, 2] call LL_fnc_heliDispatch;

    // Attendre que le gestionnaire passe en phase DEPLOYING
    waitUntil { sleep 0.5; (missionNamespace getVariable ["LL_HELI_state", "IDLE"]) == "DEPLOYING" };

    // Attendre retour à IDLE (fin du débarquement + RTB hélico)
    waitUntil { sleep 1; (missionNamespace getVariable ["LL_HELI_state", "IDLE"]) == "IDLE" };

    // Valider la tâche
    [independent, "task_XX_deploy", "SUCCEEDED", false] call BIS_fnc_taskSetState;
};
```

### 5.3 — EMBARQUEMENT comme condition de victoire finale

```sqf
// Tâche finale : déclencher l'extraction et attendre la fin de mission
[] spawn {
    private _lzPos = getPos Heliport_01;
    private _firstPlayer = allPlayers select { alive _x } select 0;

    (localize "STR_LL_Heli_Msg_Route") remoteExec ["systemChat", 0];

    // Prio 2 garantit l'interruption de toute mission en cours
    ["EMBARQUEMENT", _lzPos, _firstPlayer, 2] call LL_fnc_heliDispatch;

    // La fin de mission est gérée par fn_heliManager (BIS_fnc_endMission)
    // Rien d'autre à faire ici — le manager déclenche MissionSuccess quand
    // tous les joueurs sont à bord
};
```

### 5.4 — Vérifier la disponibilité avant de déclencher

```sqf
// Optionnel : ne déclencher que si l'hélico n'est pas déjà sur une mission prio 2
private _state    = missionNamespace getVariable ["LL_HELI_state",    "IDLE"];
private _curPrio  = missionNamespace getVariable ["LL_HELI_priority", 0];

if (_state == "IDLE" || _curPrio < 2) then {
    ["CAS", _pos, _caller, 2] call LL_fnc_heliDispatch;
} else {
    diag_log "[LL][taskXX] Hélico déjà sur mission prio 2 — CAS annulé.";
};
```

---

## 6. Règles et erreurs fréquentes

| ❌ À ne pas faire | ✅ À faire à la place |
|---|---|
| `["EMBARQUEMENT", _pos, _caller, 1] call LL_fnc_heliDispatch` | Priorité `2` depuis une tâche |
| `[] spawn LL_fnc_heliManager` dans la tâche | Le manager est déjà lancé par `initServer.sqf` |
| Lire `LL_HELI_state` côté client | Lire uniquement côté serveur (`isServer`) |
| `createVehicle ["CUP_I_CH47F_RACS", ...]` dans la tâche | Utiliser le dispatcher — jamais créer l'hélico manuellement |
| `waitUntil` bloquant dans la boucle principale de la tâche | Toujours dans un `[] spawn { ... }` séparé |

---

## 7. Matrice des états interruptibles

Un appel depuis une tâche avec `_priority = 2` peut interrompre les états suivants :

| État interruptible | Comportement lors de l'interruption |
|---|---|
| `APPROACHING` | RTB direct, hélico repart immédiatement |
| `CAS` | Sortie du loiter, RTB, **cooldown CAS NON appliqué** |
| `DELIVERING` | RTB avec cargo si slingload encore attaché, message `STR_LL_Heli_Msg_CargoAborted` |
| `RTB` | RTB déjà en cours, nouvelle mission mise en file |

États **non-interruptibles** (une requête P2 sera refusée si l'hélico est dans ces états) :

| État | Raison |
|---|---|
| `SPAWNING` | Création en cours — trop tôt pour interrompre |
| `DEPLOYING` | Parachutage en cours — les unités sont en l'air |
| `EXTRACTING` | Joueurs en train d'embarquer — interruption impossible |

