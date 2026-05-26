# TASK_ANIM.md — Animations immersives dans les tâches

Ce document est la référence pour tout usage d'animations sur des PNJ ou des joueurs dans cette mission.
Il complète TASK_RULES.md et s'adresse à un agent IA ou développeur qui code une scène de tâche.

---

## Règle d'or

> **Utilise `playMove` quand tu veux une transition propre.**
>
> `switchMove` applique une animation instantanément (sans blend) — l'unité saute visuellement.  
> `playMove` déclenche une transition progressive depuis la pose actuelle — mouvement fluide.
>
> Réserve `switchMove` uniquement pour les animations **en boucle** (loopées), après que `disableAI "ANIM"` est actif.  
> Utilise `playMove` pour toute animation **one-shot** ou **cinématique** qui doit s'enchaîner proprement.

---

## 1. Les trois commandes fondamentales

| Commande | Comportement | Utilisation |
|---|---|---|
| `playMove "animName"` | Transition fluide depuis la pose courante, one-shot, attend que l'animation soit finie | Scènes narratives, interactions, soins, arrestations |
| `switchMove "animName"` | Changement immédiat (snap), prévu pour les boucles | Attente loopée (`AnimDone` + re-call), captif, civil en veille |
| `playMoveNow "animName"` | Coupe l'animation en cours instantanément et joue la nouvelle | Interruption forcée (ex. le joueur part avant la fin) |

### Lire la durée d'une animation

Arma 3 ne fournit pas de commande native pour récupérer la durée.  
Méthode : `waitUntil { animationState _unit != "animName" }` ou `sleep N` calibré manuellement.

```sqf
// Méthode waitUntil — propre mais bloquante dans le spawn courant
_unit playMove "Acts_ExecutionVictim_Unbow";
waitUntil { sleep 0.2; animationState _unit != "Acts_ExecutionVictim_Unbow" || !alive _unit };
```

---

## 2. Prérequis indispensables avant d'animer un PNJ

Sans ces prérequis le moteur reprend le contrôle de l'animation et la coupe.

```sqf
// 1. Verrouiller l'IA sur l'animation
_unit disableAI "ANIM";

// 2. Forcer la posture de base compatible avec l'animation choisie
_unit setUnitPos "UP";     // debout — compatible animations Act_* et AinvPsit*
_unit setUnitPos "MIDDLE"; // accroupi — compatible animations AinvPknl*
_unit setUnitPos "DOWN";   // couché — compatible animations Unconscious / AinvPpne*

// 3. Désactiver le déplacement pendant la scène
_unit disableAI "MOVE";

// 4. Appliquer l'animation
_unit playMove "animName"; // ou switchMove pour une boucle
```

> **Note MP :** `disableAI` et `setUnitPos` s'exécutent sur la machine propriétaire de l'unité.  
> Si l'unité est locale au serveur, appelle ces commandes depuis le serveur.  
> Si elle est locale à un client, utilise `remoteExec`.

---

## 3. Pattern animation loopée (PNJ en attente)

Utilisé pour : civil en conversation, otage agenouillé, sentinelle qui attend.

```sqf
// ── Prérequis
_unit disableAI "ANIM";
_unit disableAI "MOVE";
_unit setUnitPos "UP";

// ── Lancer la boucle via EventHandler + switchMove
_unit switchMove "Acts_CivilTalking_1";
_unit addEventHandler ["AnimDone", {
    params ["_unit"];
    // Relancer SEULEMENT si le PNJ est encore en phase d'attente
    if (alive _unit && (_unit getVariable ["LL_Task_Status", "WAIT"]) == "WAIT") then {
        _unit switchMove "Acts_CivilTalking_1";
    };
}];
```

**Arrêter la boucle proprement :**
```sqf
_unit setVariable ["LL_Task_Status", "ACTION", true]; // stoppe l'EventHandler
_unit removeAllEventHandlers "AnimDone";
_unit playMove "Acts_CivilTalking_1";                 // laisser finir la pose en cours
sleep 1;
_unit enableAI "ANIM";                                // rendre le contrôle au moteur
```

---

## 4. Répertoire des animations par rôle

### 4.1 Civil / Informateur en attente

| Animation | Description | `setUnitPos` requis |
|---|---|---|
| `Acts_CivilTalking_1` | Parle debout, gestes des mains | `UP` |
| `Acts_CivilTalking_2` | Variante gestuelle | `UP` |
| `Acts_CivilTalking_3` | Nerveux, regarde autour | `UP` |
| `Acts_SittingJumpingSaluting_out` | Saute et salue (unique) | `UP` |
| `Acts_WalkingChecking` | Marche en regardant à droite et gauche | `UP` |

**Pattern recommandé pour civil en attente d'interaction :**
```sqf
_unit disableAI "ANIM";
_unit setUnitPos "UP";
_unit switchMove "Acts_CivilTalking_1";
```

---

### 4.2 Otage / Captif

| Animation | Description | `setUnitPos` requis |
|---|---|---|
| `Acts_ExecutionVictim_Loop` | Agenouillé, mains derrière la tête (**boucle**) | `MIDDLE` |
| `Acts_ExecutionVictim_Unbow` | Se relève lentement (one-shot, ~8 s) | `MIDDLE` |
| `Acts_SurrenderingWalk_1` | Marche mains levées | `UP` |
| `Acts_SurrenderingStand_1` | Debout, mains levées | `UP` |
| `Acts_PercMstpSnonWnonDnon_sleep` | Allongé inconscient | `DOWN` |

**Pattern otage agenouillé (task02b) :**
```sqf
_hostage disableAI "ANIM";
_hostage disableAI "MOVE";
_hostage setUnitPos "MIDDLE";
_hostage switchMove "Acts_ExecutionVictim_Loop";
_hostage addEventHandler ["AnimDone", {
    params ["_unit"];
    if (alive _unit && (_unit getVariable ["LL_Task02b_Status", "WAIT"]) == "WAIT") then {
        _unit switchMove "Acts_ExecutionVictim_Loop";
    };
}];
```

**Pattern libération (transition fluide) :**
```sqf
// Sur TOUTES les machines pour synchronisation visuelle
[_hostage, "Acts_ExecutionVictim_Unbow"] remoteExec ["switchMove", 0];
// Attendre la fin (~8 s) avant de rendre le contrôle
sleep 8;
_hostage enableAI "ANIM";
_hostage enableAI "MOVE";
```

---

### 4.3 Captif / Prisonnier sous garde

| Animation | Description | `setUnitPos` requis |
|---|---|---|
| `Acts_SurrenderingStand_1` | Debout, capitulation | `UP` |
| `Acts_CivilTalking_3` | Nerveux, stressé | `UP` |
| `Acts_LoungingWounded_1` | Blessé, s'appuie | `UP` |

**Pattern captif debout :**
```sqf
_prisoner disableAI "ANIM";
_prisoner setUnitPos "UP";
_prisoner switchMove "Acts_SurrenderingStand_1";
_prisoner addEventHandler ["AnimDone", {
    params ["_unit"];
    if (alive _unit && (_unit getVariable ["LL_Task_Status", "WAIT"]) == "WAIT") then {
        _unit switchMove "Acts_SurrenderingStand_1";
    };
}];
```

---

### 4.4 Médecin / Soins sur une unité

| Animation | Description | `setUnitPos` requis |
|---|---|---|
| `AinvPknlMstpSlayWrflDnon_medic` | Agenouillé, soigne au sol | `MIDDLE` |
| `AinvPknlMstpSlayWrflDnon_medicOther` | Agenouillé, soigne quelqu'un d'autre | `MIDDLE` |
| `AinvPercMstpSlayWrflDnon_medic` | Debout, soigne debout | `UP` |
| `AinvPpneMstpSnonWnonDnon_medic` | Allongé, auto-soin | `DOWN` |

> Ces animations sont couplées à l'action `HealSoldierSelf` (action moteur native).  
> Préférer `_unit action ["HealSoldierSelf", _unit]` plutôt que de forcer l'animation manuellement — le moteur les enchaîne correctement avec le son.

---

### 4.5 Fouille / Interaction avec un objet au sol

| Animation | Description | `setUnitPos` requis |
|---|---|---|
| `AinvPknlMstpSlayWrflDnon_medic` | Fouille accroupi (même anim que soin) | `MIDDLE` |
| `AinvPercMstpSlayWrflDnon_checkGun` | Examine une arme debout | `UP` |
| `Acts_CivilTalking_1` + `doWatch` | PNJ examine un objet (regarder vers l'objet) | `UP` |

**Pattern fouille d'une caisse (fn_addResupplyAction) :**
```sqf
_unit setUnitPos "UP";
_unit doWatch _crate;
sleep 0.5;
// Action moteur native — synchronise l'anim ET le son de rechargement
[_unit, "ReloadMagazine"] remoteExecCall ["playActionNow", owner _unit];
sleep 4.0;
_unit doWatch objNull;
```

---

### 4.6 Soldat blessé / Inconscient

| Animation | Description | `setUnitPos` requis |
|---|---|---|
| `Acts_PercMstpSnonWnonDnon_sleep` | Allongé, inconscient | `DOWN` |
| `Acts_LoungingWounded_1` | Debout, appuyé contre un mur | `UP` |
| `Acts_SittingWounded_1` | Assis au sol, blessé | `MIDDLE` |
| `AinvPpneMstpSnonWnonDnon_medic` | Allongé, en attente de soin | `DOWN` |

---

### 4.7 Gestes du joueur / Leader

| Commande | Description |
|---|---|
| `_player playActionNow "gestureAdvance"` | Geste "avancer" de la main |
| `_player playActionNow "gestureHalt"` | Geste "stopper" |
| `_player playActionNow "gestureFreeze"` | Geste "freeze" |
| `_player playActionNow "gestureCome"` | Geste "venez" |

> `playActionNow` est pour les **gestes courts** du joueur ou d'une IA.  
> Ces gestes s'exécutent côté propriétaire de l'unité — utiliser `remoteExecCall ["playActionNow", owner _unit]` pour une IA.

---

### 4.8 Animations assises (briefing, camp, attente)

| Animation | Description | `setUnitPos` requis |
|---|---|---|
| `Acts_SittingJumpingSaluting_in` | S'asseoir | `MIDDLE` |
| `Acts_UnconsciousStandUp_part1` | Se relever lentement du sol | `DOWN` |
| `Acts_ExecutionVictim_Unbow` | Se relever après agenouillé | `MIDDLE` |

---

## 5. Synchronisation MP — règles critiques

### Animations sur un PNJ serveur
Toutes les commandes d'animation (`playMove`, `switchMove`, `disableAI "ANIM"`) sur un PNJ local au serveur s'exécutent **sur le serveur**. Les clients les voient automatiquement.

```sqf
// Serveur uniquement — PNJ spawné par le serveur
_hostage switchMove "Acts_ExecutionVictim_Loop"; // OK depuis le serveur
```

### Animations visibles sur TOUS les clients (scène cinématique)
Pour une animation déclenchée par une addAction côté client et qui doit être vue par tous :

```sqf
// Depuis le client (addAction callback) :
[_target, "Acts_ExecutionVictim_Unbow"] remoteExec ["switchMove", 0]; // 0 = tous les clients + serveur
```

### `playMove` vs `switchMove` en MP
| | `playMove` | `switchMove` |
|---|---|---|
| Propagé automatiquement | Oui (si unité locale au serveur) | Oui |
| Transition visible côté client | Fluide | Snap instantané |
| Recommandé pour scènes | **Oui** | Non (sauf boucles) |

---

## 6. Récupérer le contrôle après une animation

Toujours restituer le contrôle à l'IA après une scène :

```sqf
_unit enableAI "ANIM";
_unit enableAI "MOVE";
_unit setUnitPos "AUTO"; // Laisser l'IA gérer sa posture
_unit setBehaviour "AWARE";
```

Si l'unité doit reprendre son rôle de combat :
```sqf
_unit enableAI "ANIM";
_unit enableAI "MOVE";
_unit enableAI "AUTOTARGET";
_unit enableAI "TARGET";
_unit setUnitPos "AUTO";
_unit setBehaviour "COMBAT";
_unit setCombatMode "RED";
```

---

## 7. Anti-patterns à éviter

| Anti-pattern | Problème | Solution |
|---|---|---|
| `switchMove` pour une animation one-shot | Snap visuel brutal | Utiliser `playMove` |
| `playMove` dans une boucle `AnimDone` | L'animation ne boucle pas — elle attend une transition inexistante | Utiliser `switchMove` pour les boucles |
| Forcer une animation sans `disableAI "ANIM"` | Le moteur reprend le contrôle et coupe l'animation | Toujours `disableAI "ANIM"` avant |
| `switchMove` depuis un client sur un PNJ serveur | L'animation ne se propage pas correctement | Exécuter depuis le serveur, ou `remoteExec` si nécessaire |
| Appeler `playMove` dans un `while` sans `waitUntil` | Les animations se chevauchent | Toujours attendre la fin avant d'en lancer une autre |
| Oublier `enableAI "ANIM"` après la scène | Le PNJ reste bloqué dans sa pose indéfiniment | Restituer le contrôle après chaque scène |

---

## 8. Récapitulatif — choisir la bonne commande

```
PNJ en attente d'interaction (boucle)
    → disableAI "ANIM" + switchMove + EventHandler "AnimDone"

Scène narrative (one-shot, transition fluide)
    → disableAI "ANIM" + playMove + waitUntil animationState ou sleep

Geste rapide d'un joueur/IA
    → playActionNow (remoteExecCall sur owner)

Interruption d'une animation en cours
    → playMoveNow

Animation visible sur tous les clients
    → remoteExec ["switchMove", 0] ou remoteExec ["playMove", 0]

Fin de scène — rendre le contrôle
    → enableAI "ANIM" + enableAI "MOVE" + setUnitPos "AUTO"
```
