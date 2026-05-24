# Unstable — Porto | Guide du Joueur

**Mission coopérative multijoueur — RACS Corps Expéditionnaire Multinational**  
Île de Porto, Sahrani. Stabilisez la zone, neutralisez les factions hostiles.

---

## Menu d'actions (touche Scroll)

Toutes les actions sont accessibles via le **menu scroll** d'Arma 3.  
Elles sont organisées par thème : les ordres d'escouade en haut, les soutiens en bas.

---

### Groupe `[ESCOUADE]` — Ordres de commandement *(leader uniquement)*

Ces actions ne sont disponibles **que si vous êtes le chef de groupe** et que votre escouade contient des unités IA actives.

---

#### Règles d'engagement (RoE)

Modifient immédiatement le comportement de toutes vos unités IA.

| Action | Comportement de l'IA |
|---|---|
| **RoE : Infiltration** | Silence total. Marche accroupie, ne tire jamais en premier. Idéal pour s'approcher discrètement. |
| **RoE : Vigilance** | Déplacement normal, prêt au combat. Tire si menacée. Mode par défaut. |
| **RoE : Assaut** | Combat actif, tir libre, recherche d'abris. Engagement offensif. |
| **RoE : Charge** | Sprint permanent vers l'objectif. L'IA ignore la prudence et fonce. |

> Seule la RoE qui n'est **pas déjà active** apparaît dans le menu.

---

#### Soins
> **`[ESCOUADE] Ordonner à l'escouade de se soigner`**

Ordonne aux unités IA blessées de se soigner elles-mêmes, **à condition qu'elles aient un kit de soin** (FirstAidKit ou Medikit) dans leur inventaire.  
Les soins se déclenchent automatiquement une fois le contact ennemi rompu.

- Si une IA n'a pas de kit → message d'erreur dans le chat.
- Si personne n'est blessé → message d'information dans le chat.

---

#### Regroupement
> **`[ESCOUADE] Forcer le regroupement de l'escouade`**

Ordonne à toutes les IA de votre groupe de **rejoindre votre position immédiatement**.  
Utile si votre escouade s'est dispersée au combat ou après un mouvement rapide.

---

#### Fouille de bâtiments
> **`[ESCOUADE] Fouiller les bâtiments`**

Ordonne à vos unités IA de **sécuriser les bâtiments proches** (dans un rayon de 50 m).  
Les IA se répartissent dans les positions intérieures disponibles.

- Nécessite qu'il y ait des bâtiments accessibles à proximité.
- Les IA retournent en formation automatiquement après 3 minutes.

---

### Groupe `[Drone]` — Surveillance aérienne

> **`[Drone] Demander surveillance MQ-9`**

Déploie un **drone MQ-9 Reaper** qui survole la zone pendant **15 minutes**.

- Marque les **ennemis** (points rouges) et les **alliés** (points bleus) sur la carte.
- Rayon de détection : 1 500 m autour du centre de l'équipe.
- Un seul drone peut être actif à la fois. Si un drone est déjà en mission, la demande est refusée.

---

### Groupe `[Hélicoptère]` — Soutien aérien *(CH-47F Chinook)*

Les actions hélicoptère envoient un **CH-47F RACS** sur zone. Un seul hélicoptère peut être actif ou en transit à la fois — les demandes sont refusées si l'espace aérien est occupé.

---

#### Munitions
> **`[Hélicoptère] Demander Livraison Munitions`**

L'hélicoptère livre une **caisse de munitions** à votre position actuelle.  
Une fois la caisse posée au sol, une action apparaît dessus :

> **`[Ravitaillement] Ordonner le réapprovisionnement`** *(sur la caisse)*

Ordonne aux IA de venir se réapprovisionner depuis la caisse, **par paires**, avec une animation de fouille immersive. Le joueur leader se sert **manuellement** via l'inventaire standard.

---

#### Véhicule de remplacement *(usage unique)*
> **`[Hélicoptère] Demander Livraison Véhicule`**

L'hélicoptère livre un **véhicule de remplacement** par sling-load.  
Cette livraison n'est disponible **qu'une seule fois** par mission.

---

#### Appui aérien (CAS)
> **`[Hélicoptère] Demander Appui Aérien (CAS)`**

L'hélicoptère effectue une **frappe d'appui rapproché** sur la zone désignée.  
Après la mission, un **cooldown de 5 minutes** s'applique avant de pouvoir le rappeler.

---

#### Renforts (Débarquement)
> **`[Hélicoptère] Demander Renforts (Débarquement)`**

L'hélicoptère dépose une **escouade de renforts RACS** sur zone.  
Les renforts rejoignent votre groupe ou effectuent une patrouille de sécurisation.

---

#### Extraction (Embarquement)
> **`[Hélicoptère] Demander Extraction (Embarquement)`**

L'hélicoptère atterrit pour récupérer votre équipe.  
Une fois tout le monde à bord, utilisez l'action sur l'hélicoptère pour ordonner le décollage.

---

## Mort et continuité du jeu

### Prise de contrôle d'une IA
Si votre personnage meurt, vous **basculez automatiquement sur une IA vivante** de votre groupe.  
Vous reprenez ainsi le contrôle d'un soldat et pouvez continuer à combattre.

### Réassignation du chef de groupe
Si le **chef de groupe est tué**, le jeu réassigne automatiquement le commandement au **prochain joueur humain vivant** du groupe.  
En l'absence de joueur, une IA assure temporairement le commandement.

---

## Identités et personnages

Chaque joueur reçoit une **identité aléatoire unique** au démarrage de la mission (nom, visage, voix).  
L'équipement (uniforme, gilet, casque, sac) est également distribué aléatoirement — aucun soldat ne sera identique.

---

## Civils

La zone de Porto est peuplée de **civils procéduraux**. Ils se déplacent, s'assoient, et réagissent à l'environnement.  
Évitez les pertes civiles — l'immersion repose sur leur présence.

---

## Structure de la mission

La mission se déroule en **tâches enchaînées** :

| Tâche | Objectif |
|---|---|
| **Tâche 00** — Embarquement | Rejoindre le point de départ |
| **Tâche 01** — Reconnaissance | Atteindre et sécuriser l'objectif |

La mission se termine en **succès** ou en **échec** selon l'issue de la dernière tâche.

---

*Bonne chance, soldat. Porto ne vous attend pas.*
