# BUGFIX — Système de basculement IA en Multijoueur

**Mission :** Unstable.porto  
**Scope :** Analyse et plan de correction du système `fn_switchToAI` pour la compatibilité MP + réintégration depuis le spectateur.

---

## Contexte

En solo, le système fonctionne parfaitement :  
`Killed` EH → `fn_switchToAI` → `fn_transferLocality` → `selectPlayer` sur une IA.

En multijoueur, trois problèmes distincts sont identifiés, plus un comportement non implémenté (spectateur sans IA).

---

## BUG-01 — CRITIQUE : `fn_transferLocality` transfère tout le groupe en MP

### Fichier concerné
`functions/fn_transferLocality.sqf`

### Description
La fonction reçoit une unité IA cible et un `clientOwner`. Lorsque l'unité appartient à un groupe (ce qui est toujours le cas ici), elle exécute :

```sqf
_grp setGroupOwner _clientOwner;
```

En solo, cela est inoffensif : le client = le serveur, la localité ne change pas réellement.

**En MP avec N joueurs dans le même groupe**, c'est un bug destructeur :

| Scénario | Effet réel de `setGroupOwner` |
|---|---|
| Joueur A meurt (machine 3) | Toutes les IA + tout le groupe migrent vers la machine 3 |
| Joueur B meurt ensuite (machine 4) | `setGroupOwner` redéplace tout vers la machine 4 |
| Joueur A (sur AI1, machine 3) | L'IA qu'il contrôle n'est plus locale → désynchronisation, perte de contrôle |
| Joueur B vivant commande les IA | Les IA sont sur machine 3 → les ordres de B transitent mal |

### Impact
- Race condition entre plusieurs morts simultanées ou successives.  
- Le dernier `setGroupOwner` gagne, rendant les switchs précédents instables.  
- Les IA d'un joueur qui a déjà switché peuvent ne plus être locales sur sa machine.

### Solution
Remplacer `setGroupOwner` par `setOwner` sur **l'unité individuelle uniquement** :

```sqf
// AVANT (problématique en MP)
_grp setGroupOwner _clientOwner;

// APRÈS (MP-safe)
_unit setOwner _clientOwner;
```

`selectPlayer` requiert seulement que l'unité cible soit locale sur la machine du client appelant.  
Les autres IA restent locales au serveur. Chaque joueur mort transfère uniquement SON IA cible.

> **Attention :** Si le joueur mort était le seul propriétaire du groupe (solo), conserver `setGroupOwner` comme fallback.  
> Condition : `if (isMultiplayer) then { _unit setOwner _clientOwner } else { _grp setGroupOwner _clientOwner }`.

---

## BUG-02 — MOYEN : Race condition dans `fn_checkGameOver` en MP

### Fichier concerné
`functions/fn_checkGameOver.sqf`

### Description
La fonction attend 5 secondes puis vérifie si tous les joueurs sont morts :

```sqf
sleep 5;
private _alivePlayers = _allPlayers select { alive _x };
if (count _allPlayers > 0 && { count _alivePlayers == 0 }) then { ... endMission };
```

En MP avec N joueurs :

- `fn_checkGameOver` est appelé par **chaque client** quand il entre en spectateur.
- Si deux joueurs morts entrent en spectateur à 1 s d'intervalle, deux instances de `fn_checkGameOver` tournent en parallèle.
- La vérification `alive _x` sur le serveur porte sur les **unités joueurs originales** (mortes), pas sur les IA qu'ils contrôlent maintenant via `selectPlayer`.
- Après `selectPlayer _targetAI` : `isPlayer _targetAI == true` et `alive _targetAI == true`.  
  Mais il peut exister un délai réseau avant que le serveur voie l'état `isPlayer` mis à jour.

### Impact
Risque de fin de mission prématurée si le serveur évalue `allPlayers` dans la fenêtre entre `Killed` et la résolution complète de `selectPlayer`.

### Solution
Dans `fn_checkGameOver`, filtrer les joueurs en croisant deux critères :

```sqf
// Considérer un joueur comme "mort" seulement s'il n'a aucune unité vivante sous contrôle
// ET qu'il n'est pas en train de basculer vers une IA (vérifier la variable de flag)
private _alivePlayers = _allPlayers select {
    alive _x || { _x getVariable ["LL_Switching_To_AI", false] }
};
```

Cela suppose de poser un flag `LL_Switching_To_AI = true` au début de `fn_switchToAI`  
et de le retirer à la fin (succès ou échec).

---

## BUG-03 — FONCTIONNALITÉ MANQUANTE : Pas de réintégration depuis le spectateur

### Fichiers concernés
`functions/fn_switchToAI.sqf` (branche "aucune IA disponible")

### Description
Lorsque `fn_switchToAI` ne trouve aucune IA vivante, le joueur entre en spectateur :

```sqf
["Initialize", [player, [], true]] call BIS_fnc_EGSpectator;
[] remoteExec ["LL_fnc_checkGameOver", 2];
```

Il n'existe aucun mécanisme pour surveiller l'arrivée de nouvelles IA dans le groupe  
(p. ex. : renforts livrés par hélicoptère via `LL_fnc_requestHelicopter`).

### Impact
Un joueur en spectateur reste bloqué en spectateur même si des IA rejoignent le groupe  
(renforts DEBARQUEMENT = nouvelles unités RACS ajoutées au groupe du leader).

### Solution — Boucle de surveillance dans la branche spectateur

Remplacer le bloc "aucune IA" par :

```sqf
} else {
    // Aucune IA disponible : entrer en spectateur
    private _originalGroup = group _deadUnit;

    setPlayerRespawnTime 999999;
    ["Initialize", [player, [], true]] call BIS_fnc_EGSpectator;
    [] remoteExec ["LL_fnc_checkGameOver", 2];

    // Boucle de surveillance : attend qu'une IA rejoigne le groupe
    [] spawn {
        private _grp = _originalGroup; // capturer le groupe dans la closure

        waitUntil {
            sleep 5;
            private _availableAI = (units _grp) select { alive _x && !isPlayer _x };
            count _availableAI > 0
        };

        // Sortir du spectateur
        ["Terminate"] call BIS_fnc_EGSpectator;

        // Re-tenter le basculement vers la nouvelle IA disponible
        [_deadUnit] spawn LL_fnc_switchToAI;
    };
};
```

> **Note :** `_originalGroup` doit être capturé **avant** le `spawn` pour rester accessible  
> dans la closure via la variable privée du bloc parent.

---

## BUG-04 — DESIGN : Boutons de renforts inaccessibles en mode spectateur

### Fichiers concernés
`functions/fn_addHelicopterActions.sqf`, `functions/fn_addDroneAction.sqf`

### Description
Les `addAction` (hélicoptère, drone) sont attachées à l'unité joueur (son corps).  
En mode spectateur `BIS_fnc_EGSpectator`, le joueur est dans une caméra libre :  
**le menu d'actions scroll n'est pas accessible** sur le corps mort.

Le BUG-03 suppose pourtant qu'un spectateur peut appeler des renforts pour réintégrer le jeu.

### Solution recommandée — Ajouter les actions via `BIS_fnc_EGSpectator` callbacks

`BIS_fnc_EGSpectator` expose une interface scriptable. Une option simple est d'ouvrir  
une action carte (`createDialog` ou `addMissionEventHandler "Map"`) pour les joueurs spectateurs.

**Alternative légère** : garder les actions sur l'unité morte mais retirer la condition  
`alive _target` lorsque le joueur est en mode spectateur confirmé :

```sqf
// Condition modifiée pour autoriser le mort-spectateur à appeler des renforts
"leader (group _target) isEqualTo _target || (_target getVariable ['LL_Spectating', false])"
```

Poser `_deadUnit setVariable ["LL_Spectating", true]` lors de l'entrée en spectateur  
(dans `fn_switchToAI`, branche aucune IA).

> Cette approche permet de réutiliser tout le système `addAction` existant sans le refactoriser.  
> Le menu scroll devient accessible sur le corps mort via interaction directe (se placer dessus).  
> En spectateur libre, une interaction via la carte reste la solution la plus ergonomique.

---

## Compatibilité — Système de blessure / réanimation

### Analyse

| Système | Comportement du `Killed` EH | Compatibilité `fn_switchToAI` |
|---|---|---|
| **Vanilla (sans revive)** | Déclenché à `damage == 1.0` (mort définitive) | ✅ Aucun conflit |
| **BIS Revive** (`respawnTemplates[] = {"Revive"}`) | `Killed` déclenché **pendant** l'état inconscient | ⚠️ Conflit possible |
| **ACE3 Medical** | ACE gère ses propres états; `Killed` EH vanilla = mort ACE confirmée | ✅ Aucun conflit si ACE3 actif |

### État actuel (`description.ext`)
```sqf
respawnTemplates[] = {"Tickets"}; // Pas de "Revive"
respawn             = 3;
respawnButton       = 0;
```

**Le système BIS Revive n'est pas activé.** Le `Killed` EH ne se déclenche qu'à la mort définitive.  
Si ACE3 est utilisé (probable vu la mention "système de blessure"), ACE intercepte les états  
inconscients **avant** que le `Killed` EH vanilla ne se déclenche → aucun conflit.

### Précaution si BIS Revive est ajouté ultérieurement
Ajouter une garde dans `fn_switchToAI` :

```sqf
// Ne pas switcher si le joueur est en état de réanimation BIS (incapacité temporaire)
if (_deadUnit getVariable ["BIS_revive_incapacitated", false]) exitWith {
    diag_log "[LL] switchToAI: Joueur incapacité (BIS Revive) — basculement annulé.";
};
```

---

## Récapitulatif des actions à mener

| # | Priorité | Fichier | Action |
|---|---|---|---|
| BUG-01 | 🔴 CRITIQUE | `fn_transferLocality.sqf` | Remplacer `setGroupOwner` par `setOwner` individuel en MP |
| BUG-02 | 🟡 MOYEN | `fn_checkGameOver.sqf` | Ajouter le flag `LL_Switching_To_AI` pour éviter les faux positifs |
| BUG-02 | 🟡 MOYEN | `fn_switchToAI.sqf` | Poser/retirer le flag `LL_Switching_To_AI` au début/fin |
| BUG-03 | 🟠 IMPORTANT | `fn_switchToAI.sqf` | Ajouter la boucle de surveillance dans la branche spectateur |
| BUG-04 | 🔵 DESIGN | `fn_switchToAI.sqf` + actions | Flag `LL_Spectating` + retirer `alive _target` pour les spectateurs |

---

*Document d'analyse — à implémenter après validation des solutions proposées.*
