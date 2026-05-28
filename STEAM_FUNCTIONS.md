# Unstable — Porto | Guide du Joueur

**Mission coopérative 1–7 joueurs — RACS Corps Expéditionnaire Multinational**
**Île de Porto, Sahrani · 2025–2026 · Pas de DLC requis · Mods : CUP**

---

## Sommaire
1. [Menu d'actions (scroll)](#menu-dactions)
2. [Soutien Hélicoptère — CH-47F Chinook](#soutien-hélicoptère)
3. [Soutien Drone — MQ-9 Reaper](#soutien-drone)
4. [Mort et continuité de jeu](#mort-et-continuité)
5. [Structure de la mission](#structure-de-la-mission)
6. [Équipement et identités](#équipement-et-identités)
7. [Civils et menaces cachées](#civils-et-menaces-cachées)

---

## Menu d'actions

Toutes les actions sont accessibles via le **menu scroll** d'Arma 3 (molette ou `F2` selon vos touches).
Les actions de commandement et de soutien ne s'affichent que lorsqu'elles sont disponibles.

> **Actions blanches** = Support / Soutien
> **Actions jaunes** = Interactions de tâche (examiner, libérer, désamorcer…)
> **Certaines actions sont réservées au chef de groupe.**

---

### `[ESCOUADE]` — Commandement *(chef de groupe uniquement)*

Ces actions apparaissent uniquement si vous êtes le **leader du groupe** et que votre escouade contient des unités IA actives.

---

#### Règles d'engagement (RoE)

Modifient instantanément le comportement de **toutes vos unités IA**. Seule la RoE qui n'est pas déjà active s'affiche.

| Action | Mode IA | Usage conseillé |
|---|---|---|
| **`[ESCOUADE] RoE : Infiltration`** | Silence total — marche accroupie, ne tire jamais en premier | Approche discrète, reconnaissance urbaine |
| **`[ESCOUADE] RoE : Vigilance`** | Déplacement normal, prêt au combat, tir si menacée | Mode par défaut entre deux phases de contact |
| **`[ESCOUADE] RoE : Assaut`** | Combat actif, tir libre, recherche d'abri | Engagement offensif sur un objectif confirmé |
| **`[ESCOUADE] RoE : Charge`** | Sprint vers l'objectif, ignore la prudence | Exploitation d'une brèche, sprint final |

---

#### `[ESCOUADE] Ordonner soins à l'escouade`

Ordonne aux unités IA **blessées** de se soigner de manière autonome.

- Les soins ne démarrent **qu'une fois le contact ennemi rompu** (comportement non-COMBAT).
- Chaque IA doit avoir un **FirstAidKit** ou **Medikit** dans son inventaire.
- Si une IA n'a pas de kit → message d'avertissement dans le chat.
- Si personne n'est blessé → message d'information.
- Les IA se soignent avec un décalage de 1 à 2 secondes entre elles pour éviter les animations simultanées.

---

#### `[ESCOUADE] Forcer le regroupement`

Ordonne à toutes les IA vivantes de rejoindre votre position immédiatement.

- Chaque IA rejoint une **position en arc semi-circulaire derrière vous** (rang 1 / rang 2 alternés).
- Si une IA est bloquée (pathfinding), le système tente jusqu'à **3 débloquages automatiques** : point intermédiaire, puis déviation aléatoire.
- Les IA font un `doFollow` une fois arrivées à 5m de votre position.
- Timeout de sécurité : **45 secondes** par unité avant abandon.

---

#### `[ESCOUADE] Fouiller les bâtiments`

Ordonne aux IA de **sécuriser et inspecter les bâtiments** dans un rayon de **50 mètres**.

- L'action n'est visible que si des bâtiments accessibles sont effectivement à portée (détection toutes les 2s).
- Les IA se répartissent sur les positions intérieures disponibles.
- Elles regagnent automatiquement la formation après **3 minutes**.

---

## Soutien Hélicoptère

**Un seul CH-47F RACS** est disponible par mission. Toutes les demandes passent par un **dispatcher centralisé**. Si l'hélicoptère est déjà en mission, la demande est soit refusée soit mise en file selon la priorité.

**États interruptibles** *(une demande à haute priorité peut l'annuler)* : Approche, CAS, Livraison en cours, RTB.
**États non-interruptibles** : Spawn, Déploiement de renforts, Extraction en cours.

> **Toutes les actions hélicoptère sont réservées au chef de groupe.**

---

### `[Hélicoptère] Demander Livraison Munitions`

L'hélicoptère livre une **caisse de munitions** à votre position actuelle.

Une fois la caisse posée, une action dorée apparaît sur elle :

> **`[Ravitaillement] Ordonner réapprovisionnement`** *(sur la caisse — leader uniquement)*

**Séquence de ravitaillement :**
1. Le leader fait un geste d'avance (`gestureAdvance`).
2. Les IA viennent se placer devant la caisse **par paires**.
3. Animation accroupie de fouille (`medic`).
4. Rechargement réel : jusqu'à **8 chargeurs** pour l'arme principale, **4** pour l'arme de poing.
5. Les IA s'éloignent pour laisser place à la paire suivante, puis font un `doFollow` sur le leader.

> Le joueur leader se ravitaille **manuellement** via l'inventaire standard (`I` ou `G`).

---

### `[Hélicoptère] Demander Livraison Véhicule`

L'hélicoptère livre un **véhicule de remplacement** par sling-load.

> ⚠ **Usage unique par mission.** L'action disparaît définitivement après la livraison.

---

### `[Hélicoptère] Demander Appui Aérien (CAS)`

L'hélicoptère effectue une **passe de frappe rapprochée** sur la zone.

> **Cooldown : 5 minutes** après chaque frappe. Le temps restant est affiché dans le chat si vous tentez une demande pendant le cooldown.

---

### `[Hélicoptère] Demander Renforts (Débarquement)`

L'hélicoptère dépose une **escouade de renforts RACS** sur zone. Les renforts effectuent une patrouille de sécurisation.

---

### `[Hélicoptère] Demander Extraction (Embarquement)`

L'hélicoptère atterrit pour **récupérer votre équipe**. Embarquez à bord — il décolle dès que la condition d'extraction est remplie.

> Dans certaines tâches, **l'hélicoptère d'extraction est réservé à un PNJ spécifique** (informateur). Les joueurs qui tentent de monter sont immédiatement éjectés.

---

## Soutien Drone

### `[Drone] Demander surveillance MQ-9`

Déploie un **drone de surveillance MQ-9 Reaper** (CUP) qui effectue un loiter circulaire sur zone.

| Paramètre | Valeur |
|---|---|
| Durée de mission | **15 minutes** |
| Altitude de surveillance | 180 m |
| Rayon de loiter | 450 m autour du centre de l'équipe |
| Rayon de détection | 1 000 m |
| Marqueurs ennemis | Points rouges sur carte (sans texte) |
| Marqueurs alliés | Points bleus sur carte (sans texte) |

- Un seul drone peut être actif à la fois. Une nouvelle demande est refusée si un drone est déjà sur zone.
- Réservé au **chef de groupe** (ou joueur en mode spectateur).
- Le drone ignore les fantassins ennemis et ne cible que les **véhicules ennemis** pour l'armement.
- Les unités ennemies au sol **ne réagissent pas** au drone.

---

## Mort et continuité

### Prise de contrôle d'une IA

Lorsque votre personnage est tué, vous **basculez automatiquement** sur le contrôle d'une IA vivante de votre groupe (choisie aléatoirement).

**Séquence :**
1. L'animation de mort se termine (3 secondes de délai).
2. La localité de l'IA est transférée à votre machine (timeout de sécurité : 5s).
3. Vous prenez le contrôle. Tous vos Event Handlers (Killed, Respawn…) se transfèrent sur le nouveau corps.
4. Si vous étiez le chef, le commandement est **automatiquement réassigné** au prochain joueur humain vivant.

### Mode spectateur

Si **aucune IA n'est disponible** (toutes mortes ou déjà contrôlées), vous basculez en **mode spectateur Arma 3 standard** (EGSpectator). Vous pouvez observer la situation en attendant l'issue.

### Réassignation du chef de groupe

Si le **chef de groupe est tué**, le commandement passe immédiatement au **premier joueur humain vivant** dans la liste du groupe. En l'absence de joueur vivant, une IA assure temporairement le commandement.

### Fin de mission (défaite)

Si **tous les joueurs humains sont morts simultanément** (aucune IA disponible pour le bascule), la mission se termine en **défaite** après un court délai de sécurité (5 secondes). Ce délai permet aux basculements IA en cours de se finaliser avant que le verdict ne tombe.

---

## Structure de la mission

La mission se déroule en **tâches enchaînées dynamiquement**. L'arbre varie selon l'issue de la tâche 01.

```
Tâche 00 — Embarquement
    └─→ Tâche 01 — Rendez-vous de reconnaissance
            ├─ Scénario 1 : Coopération
            │       └─→ Tâche 02a — Neutraliser les chefs / Cache de documents
            │               └─→ Tâche 03a — Neutraliser les véhicules armés (UAZ AGS-30 ×3)
            │                       └─→ EXTRACTION (fin de mission joueur)
            │
            ├─ Scénario 2 : Trahison
            │       └─→ Tâche 02b — Libérer l'informateur du RACS
            │               └─→ Tâche 03b — Désamorcer les bombes du MJ (×2, chrono 15 min)
            │                       └─→ EXTRACTION (fin de mission joueur)
            │
            └─ Scénario 3 : Mutinerie
                    ├─ Chef survivant
                    │       └─→ Tâche 02c — Capturer l'intermédiaire financier
                    │               └─→ Tâche 03a — (voir ci-dessus)
                    │
                    └─ Chef mort
                            └─→ Tâche 02b → Tâche 03b (voir ci-dessus)
```

> **La fin de mission n'est jamais automatique.** C'est toujours le joueur qui déclenche l'extraction via `[Hélicoptère] Demander Extraction`. Une tâche peut être réussie ou échouée sans que la mission se termine.

---

### Détail des tâches

#### Tâche 00 — Embarquement
Rejoindre le point de regroupement et finaliser la mise en place avant le déploiement.

#### Tâche 01 — Rendez-vous de reconnaissance
Rencontrer un contact local. Le scénario (Coopération / Trahison / Mutinerie) est tiré aléatoirement à chaque partie, assurant la **rejouabilité**.

#### Tâche 02a — Neutraliser les chefs / Récupérer les documents
Localiser et éliminer les chefs de milice dans leurs repaires. Sécuriser des renseignements stratégiques.

#### Tâche 02b — Libérer l'informateur
Un informateur du RACS est retenu prisonnier, encadré par des gardes. Localisez-le dans l'une des trois zones de recherche, éliminez les gardes et libérez-le via l'action jaune **`[Libérer]`** (3m, appui court).

L'hélicoptère d'extraction viendra chercher l'informateur — il est **réservé exclusivement au PNJ**. Tout joueur qui tente de monter est éjecté.

#### Tâche 02c — Capturer l'intermédiaire financier
Neutraliser et extraire un financier du réseau MJ, protégé par un dispositif de sécurité renforcé.

#### Tâche 03a — Neutraliser les véhicules armés
Trois UAZ équipés de lance-grenades AGS-30, positionnés sur des points stratégiques de l'île, escortés par des patrouilles de gardes. Utilisez le **drone MQ-9** pour les localiser avant l'engagement.

#### Tâche 03b — Opération Bouclier : Désamorcer les bombes
**Mission à haut risque.** Le MJ a planté **2 engins explosifs** dans Porto. Compte à rebours de **25 à 45 minutes** affiché en temps réel (coin supérieur droit de l'écran).

**Mécaniques :**
- **Désamorçage** : approchez la caisse-bombe à moins de **3 mètres**, maintenez l'action jaune **`[Désamorcer l'explosif]`** pendant **10 secondes**.
- **Gardes MJ** : 8 à 12 combattants par site, organisés en deux patrouilles.
- **Civils traîtres** : 2 à 4 sympathisants MJ par site. Ils paraissent inoffensifs mais s'arment automatiquement si un joueur s'approche à **moins de 15 mètres**. Un avertissement QG s'affiche dès leur activation.
- **Si le chrono expire** : les bombes explosent, la tâche échoue. Les gardes MJ survivants passent en mode assaut et convergent sur votre position. Une sous-tâche de survie est créée — tenez jusqu'à l'extraction.

---

## Équipement et identités

Chaque joueur reçoit au démarrage une **identité aléatoire unique** : nom, visage, voix. L'équipement est également distribué aléatoirement — uniforme, gilet, casque, sac, accessoires faciaux. Aucun soldat ne sera identique d'une partie à l'autre.

Le véhicule de départ de l'équipe (**CUP_B_nM1025_SOV_M2_USMC_DES**) est disponible en début de mission. En cas de perte, une livraison véhicule de remplacement peut être demandée via l'hélicoptère (**usage unique**).

---

## Civils et menaces cachées

Porto est peuplée de **civils procéduraux** : pêcheurs, commerçants, passants. Ils se déplacent, s'assoient, réagissent à l'environnement et aux tirs. Leur présence est essentielle à l'immersion — évitez les pertes civiles.

**Dans la tâche 03b**, une fraction de la population civile est infiltrée par le MJ. Ces traîtres **ne peuvent pas être identifiés à l'avance** — leur armement se déclenche uniquement à la proximité physique des joueurs. La prudence s'impose en milieu urbain.

---

*Corps Expéditionnaire Multinational — RACS. Porto ne nous attend pas.*

