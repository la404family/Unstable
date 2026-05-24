# BUGFIX — Rapport d'analyse : Respawn intempestif en 2 joueurs sans IA

**Symptôme rapporté :**
En multijoueur à 2 joueurs sans IA, lorsque les deux joueurs meurent (ou qu'un joueur déclenche la mort forcée via le menu pause), un nouveau joueur apparaît au marqueur `respawn_west` au lieu de terminer la partie.

---

## Schéma d'exécution attendu vs observé

| Scénario | Comportement attendu | Comportement observé |
|---|---|---|
| 2 joueurs, avec IA — un joueur meurt | Basculement vers une IA du groupe | ✅ Correct |
| 2 joueurs, sans IA — un joueur meurt | Mort permanente, attendre l'autre | ❌ Respawn au marqueur après 10 s |
| 2 joueurs, sans IA — les deux morts | Fin de partie (défaite) | ❌ Les deux respawn au marqueur |
| Un joueur appuie sur le bouton Respawn (mort forcée) | Fin de partie si dernier joueur | ❌ Respawn immédiat au marqueur |

---

## Analyse des fichiers — Bugs identifiés

---

### BUG #1 — [CRITIQUE] `description.ext` : `respawn = 3` universel sans garde-fou de fin de partie

**Fichier :** `description.ext`
**Lignes concernées :**
```sqf
respawn        = 3;   // Respawn sur marqueur — TOUJOURS actif
respawnDelay   = 10;  // 10 secondes de délai
respawnButton  = 1;   // Bouton de mort forcée activé
```

**Explication :**
Arma 3 gère le respawn de manière **native et inconditionnelle**. Dès que `respawn = 3` est défini, le moteur de jeu programme **automatiquement** la réapparition d'un joueur mort après `respawnDelay` secondes, **indépendamment** de tout script SQF.

Le système `fn_switchToAI` est conçu pour interrompre ce cycle en prenant le contrôle d'une IA **avant** que le respawn ne se produise. Mais si aucune IA n'est disponible (scénario 2 joueurs sans IA), `fn_switchToAI` ne fait rien — et Arma 3 respawn le joueur quand même.

**Il n'existe aucun mécanisme dans la mission qui surveille si tous les joueurs sont simultanément morts et déclenche une fin de partie.**

---

### BUG #2 — [CRITIQUE] `fn_switchToAI.sqf` : branche `else` silencieuse, aucune détection de fin de partie

**Fichier :** `functions/fn_switchToAI.sqf`
**Lignes concernées :**
```sqf
} else {
    if (DEBUG_MODE) then {
        diag_log "[LL] switchToAI: Aucune IA vivante disponible dans le groupe pour le basculement.";
    };
};
```

**Explication :**
Quand `_livingAI` est vide (aucune IA à prendre en contrôle), la fonction se termine **silencieusement**. Elle log un message en mode debug, puis rend la main. À ce stade, Arma 3 a déjà démarré son compteur de 10 secondes (`respawnDelay`) pour respawn le joueur.

La branche `else` devrait être le **point de déclenchement d'une vérification de fin de partie** côté serveur. Elle ne l'est pas. C'est la cause directe du symptôme rapporté.

---

### BUG #3 — [MAJEUR] `description.ext` : `respawnButton = 1` contourne entièrement `fn_switchToAI`

**Fichier :** `description.ext`
**Ligne concernée :** `respawnButton = 1;`

**Explication :**
Le bouton « Respawn » dans le menu Échap (mort forcée) **déclenche directement le système de respawn natif d'Arma 3**, sans passer par le cycle `Killed` → `fn_switchToAI`. Résultat :

- Le joueur mort appuie sur le bouton → réapparition immédiate au marqueur `respawn_west`
- Aucune vérification du nombre de joueurs vivants
- Aucune chance pour `fn_switchToAI` d'intercepter l'action

Ce bouton est **incompatible** avec le système de basculement IA : soit le joueur bascule vers une IA (automatiquement via le `Killed` EH, le bouton est inutile), soit il doit mourir définitivement et le bouton ne devrait pas être disponible.

---

### BUG #4 — [MAJEUR] `fn_switchToAI.sqf` : duplication possible du `Killed` EH après basculement + respawn natif

**Fichier :** `functions/fn_switchToAI.sqf` (lignes du bloc `if (local _targetAI)`)
**Fichier connexe :** `initPlayerLocal.sqf` (bloc `Respawn` EH)

**Explication — chaîne d'événements problématique :**

1. **Joueur A** meurt → `Killed` EH → `fn_switchToAI` → bascule vers `_targetAI` (IA du groupe)
2. `fn_switchToAI` attache un **nouveau `Killed` EH** à `player` (= `_targetAI` après `selectPlayer`)
3. Pendant ce temps, le moteur Arma 3 voit le **corps original du Joueur A** comme un joueur mort avec `respawn = 3` → il programme un respawn
4. Après 10 s, le **corps original du Joueur A** est respawné → le `Respawn` EH dans `initPlayerLocal.sqf` se déclenche sur `_newUnit` → attache **un deuxième `Killed` EH** au nouveau corps

Résultat : deux corps distincts (`_targetAI` et le nouveau respawn du Joueur A) ont chacun un `Killed` EH actif, et chacun appellera `fn_switchToAI` et `fn_manageLeadership` lors de leur prochaine mort. Les appels en double à `fn_manageLeadership` via `remoteExec` sur le serveur peuvent produire des comportements incohérents (double réassignation de leader, double transfert de groupe).

```sqf
// Dans fn_switchToAI.sqf — EH ajouté à l'IA basculée
player addEventHandler ["Killed", { ... }];

// Dans initPlayerLocal.sqf — EH ajouté au corps respawné (10 s plus tard)
_newUnit addEventHandler ["Killed", { ... }];
```

---

### BUG #5 — [MINEUR] `fn_manageLeadership.sqf` : aucune détection de fin de partie quand toutes les unités sont mortes

**Fichier :** `functions/fn_manageLeadership.sqf`
**Lignes concernées :**
```sqf
} else {
    if (count _livingUnits > 0) then {
        private _newLeader = _livingUnits select 0;
        _group selectLeader _newLeader;
        ...
    };
    // ← Aucune action si count _livingUnits == 0
};
```

**Explication :**
Quand `_livingUnits` est vide (plus aucune unité vivante dans le groupe), la fonction se termine silencieusement. C'est un défaut secondaire, car `fn_manageLeadership` n'est appelé **que lorsque c'est le leader qui meurt** (condition dans le `Killed` EH). Si le dernier joueur vivant n'est pas le leader, `fn_manageLeadership` n'est pas invoqué du tout, et cette branche n'est jamais atteinte. Ce bug ne peut pas seul déclencher la fin de partie.

---

### BUG #6 — [MINEUR] `initPlayerLocal.sqf` : cycle mort→respawn→mort perpétué sans fin

**Fichier :** `initPlayerLocal.sqf`
**Bloc concerné :** le `Respawn` EH

**Explication :**
Le `Respawn` EH re-attache systématiquement un `Killed` EH sur le nouveau corps à chaque respawn. C'est le comportement **voulu** pour que le système de basculement IA fonctionne aussi après une réapparition.

En revanche, si la fin de partie n'est jamais déclenchée (voir Bug #1), ce mécanisme garantit que le cycle `mort → respawn → mort → respawn` se répète **indéfiniment** en 2 joueurs sans IA. Ce n'est pas un bug en soi mais un amplificateur du Bug #1.

---

## Synthèse des causes racines

```
description.ext
  └── respawn = 3             ← Moteur Arma 3 respawn TOUJOURS (Bug #1)
  └── respawnButton = 1       ← Mort forcée contourne fn_switchToAI (Bug #3)

fn_switchToAI.sqf
  └── else { /* rien */ }     ← Aucun déclencheur de fin de partie (Bug #2)
  └── player addEH "Killed"   ← Potentielle duplication d'EH (Bug #4)

fn_manageLeadership.sqf
  └── count == 0 → rien       ← Opportunité manquée (Bug #5)

initPlayerLocal.sqf
  └── Respawn EH              ← Perpétue le cycle (Bug #6, amplifie Bug #1)
```

---

## Corrections proposées

> **Contraintes respectées :**
> - Ne pas modifier la logique native Arma 3
> - Ne pas casser le système de résurrection (basculement vers IA)
> - Cibler la cause racine, pas les symptômes

---

### CORRECTION #1 — `fn_switchToAI.sqf` — Déclencher la vérification de fin de partie quand aucune IA n'est disponible

**Remplacer la branche `else` silencieuse :**

```sqf
} else {
    // Aucune IA disponible pour le basculement.
    // Déclencher immédiatement une vérification de fin de partie côté serveur.
    // Le délai de 10 s (respawnDelay) laisse une fenêtre pour que endMission
    // s'exécute avant tout respawn Arma 3.
    [] remoteExec ["LL_fnc_checkGameOver", 2];

    if (DEBUG_MODE) then {
        diag_log "[LL] switchToAI: Aucune IA disponible. Vérification de fin de partie déclenchée.";
    };
};
```

---

### CORRECTION #2 — Créer `functions/fn_checkGameOver.sqf` (nouvelle fonction serveur)

```sqf
#include "..\macros.hpp"

/*
 * LL_fnc_checkGameOver
 *
 * Description:
 *   Vérifie si tous les joueurs connectés sont morts simultanément.
 *   Si oui, déclenche la fin de mission (défaite) avant l'expiration
 *   du respawnDelay Arma 3 (10 s).
 *   Ne doit pas être appelé si une IA vivante reste disponible pour le basculement.
 *
 * Locality:
 *   Serveur uniquement — appelé via remoteExec [..., 2]
 */

if (!isServer) exitWith {};

// Exclure les Headless Clients de la liste des joueurs
private _allPlayers = allPlayers - entities "HeadlessClient_F";

// Compter les joueurs encore en vie
private _alivePlayers = _allPlayers select { alive _x };

if (count _allPlayers > 0 && { count _alivePlayers == 0 }) then {
    if (DEBUG_MODE) then {
        diag_log "[LL] checkGameOver: Tous les joueurs sont morts. Fin de mission déclenchée.";
    };

    // Court délai dramatique (3 s) avant l'écran de défaite,
    // bien inférieur au respawnDelay (10 s) pour éviter tout respawn.
    [] spawn {
        sleep 3;
        ["LOSER", false, 0] call BIS_fnc_endMission;
    };
};
```

**Déclarer la fonction dans `description.ext` :**
```sqf
class MissionFunctions {
    file = "functions";
    // ... fonctions existantes ...
    class checkGameOver         {};   // ← Ajouter cette ligne
};
```

---

### CORRECTION #3 — `description.ext` — Désactiver le bouton de mort forcée

```sqf
// AVANT
respawnButton = 1;

// APRÈS
respawnButton = 0;
```

**Justification :** Le bouton de mort forcée contourne le `Killed` EH et donc toute vérification de fin de partie. Il n'apporte aucune valeur dans ce système (le basculement IA est automatique). Sa suppression élimine le Bug #3 sans impact sur le gameplay.

---

### CORRECTION #4 (optionnelle) — `fn_switchToAI.sqf` — Éviter la duplication du `Killed` EH

Après `selectPlayer _targetAI`, utiliser `removeAllEventHandlers` sur le corps original pour lui retirer son `Respawn` EH avant qu'Arma 3 ne le respawn et ne crée un EH en double :

```sqf
if (local _targetAI) then {
    selectPlayer _targetAI;

    // Retirer le Respawn EH du corps original (_deadUnit) pour éviter
    // qu'Arma 3 ne respawn l'ancienne unité et ne duplique le Killed EH.
    _deadUnit removeAllEventHandlers "Respawn";

    // ... reste de la logique existante ...
};
```

---

## Ordre d'implémentation recommandé

| Priorité | Correction | Impact |
|---|---|---|
| 1 | Créer `fn_checkGameOver.sqf` | Élimine la cause racine du respawn |
| 2 | Modifier `fn_switchToAI.sqf` (branche `else`) | Connecte la mort sans IA à la fin de partie |
| 3 | Déclarer `checkGameOver` dans `description.ext` | Nécessaire pour que la fonction soit reconnue |
| 4 | `respawnButton = 0` dans `description.ext` | Bloque le contournement par mort forcée |
| 5 | `removeAllEventHandlers "Respawn"` dans `fn_switchToAI.sqf` | Nettoyage préventif des EH en double |

---

## Fichiers à modifier / créer

| Fichier | Action | Bug(s) corrigé(s) |
|---|---|---|
| `functions/fn_checkGameOver.sqf` | **Créer** | #1, #2 |
| `functions/fn_switchToAI.sqf` | **Modifier** (branche `else` + `removeAllEventHandlers`) | #2, #4 |
| `description.ext` | **Modifier** (`respawnButton`, déclaration `checkGameOver`) | #1, #3 |
