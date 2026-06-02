# AUDIOINFO : Références et Audios pour l'Immersion (Porto)

Ce document liste les fichiers audio disponibles nativement dans Arma 3 et dans le mod CUP qui peuvent être intégrés pour renforcer l'immersion de la mission **Operation Royal Alliance**, notamment pour les messages radio, le drone, l'hélicoptère et le désamorçage de bombe.

## 📻 Audios Natifs Arma 3 (Messages Radio & Interface)

Ces sons peuvent être appelés avec `playSound "NomDuSon";` (ou `playSound3D`) et sont parfaits pour habiller les `systemChat`.

### Radio & QG (HQ)
- **`RadioAmbient1` à `RadioAmbient30`** : Bruits de fond de radio militaire, crépitements et voix indiscernables. Idéal à jouer juste avant ou pendant un message texte du QG (`systemChat` ou `sideChat`).
- **`InBaseMoves_Radio1`** : Transmission radio environnementale plus longue.
- **`Beep_Light`** ou **`Beep_Light2`** : Petit bip radio pour simuler l'ouverture d'un canal de communication par le Chef de milice ou le QG.
- **`TaskCreated` / `TaskSucceeded` / `TaskFailed`** : Sons caractéristiques pour l'ajout, la réussite ou l'échec des missions (Tâches 01, 02, 03).

### Drone MQ-9 (Surveillance)
- **`Beep_Target`** : Bip radar/verrouillage court. Parfait lorsque le drone MQ-9 détecte un nouveau groupe ennemi ou met à jour les marqueurs sur la carte.
- **`UAV_loop`** : Bruit continu de moteur de drone lointain. Peut être attaché à un objet ou joué en ambiance si le joueur ouvre le terminal.

### Tâche "Opération Bouclier" (Désamorçage Tâche 03B)
- **`FD_Timer_F`** : Bip de compte à rebours pour la bombe (à jouer en boucle ou avec `playSound` quand le timer passe sous la barre rouge des 5 minutes).
- **`FD_CP_Clear_F`** : Bip de validation clair, parfait pour le succès du désamorçage de la bombe.
- **`FD_CP_Not_Clear_F`** : Bip d'erreur, si l'action de désamorçage est interrompue par un civil traître ou une attaque.

### Alertes & Soutien Hélicoptère
- **`Alarm_Independent`** : Déjà configuré dans votre `description.ext` pour l'extraction.
- **`Alarm_BLUFOR` / `Alarm_OPFOR`** : Variantes d'alerte pour simuler l'approche des renforts ennemis ou alerter les joueurs d'un danger imminent (ex: repérage de l'escouade).

---

## 🚁 Audios CUP (Effets Sonores Avancés)

Le mod CUP apporte ses propres configs sonores. Bien que CUP n'ajoute pas de voix radio généralistes (celles-ci dépendent du doublage), ses banques de sons peuvent grandement aider :

- **Sons d'Hélicoptère (CH-47F RACS)** :
  - Bien que le véhicule joue ses sons automatiquement, vous pouvez extraire les classes sonores du `CfgVehicles` du Chinook CUP pour simuler un largage de soutien (munitions/véhicule) *hors carte* ou accentuer le son du rotor lors d'un "Call CAS" avec `playSound3D`.
- **Ambiance de Combat (CUP Weapons / Battle)** :
  - **`BattlefieldExplosions1_3D` à `BattlefieldExplosions5_3D`** (Natif souvent utilisé avec les mods) : Combiner ces sons avec les impacts explosifs de CUP pour simuler que le RACS se bat ailleurs sur l'île de Porto, augmentant l'immersion sans surcharger le serveur avec des IA réelles.

---

## 🕌 Audios Personnalisés Inclus (Mission)

- **`ezan`** (`music\ezan.ogg`) : Appel à la prière configuré pour les haut-parleurs (`ezan_00` à `ezan_XX`).
- **`LL_typewriter_bip`** et **`LL_extraction_bip`** : Modifiés via `description.ext` à partir des sons vanilla pour un effet UI unique.

---

## 💡 Recommandation d'Intégration SQF (Messages Radio)

Pour rendre les messages (`SUPPORT`, `QG`, `Militia Leader`) de `INFO.md` vivants sans voice acting complet, combinez un son radio court avec le texte :

```sqf
// Exemple pour un ordre du QG
playSound "RadioAmbient2";
sleep 0.5;
systemChat "[QG] : Escouade, ici le QG. Nouvel objectif transmis sur vos terminaux.";
```

```sqf
// Exemple pour le Drone MQ-9 qui détecte des ennemis
playSound "Beep_Target";
systemChat "[SUPPORT] : MQ-9 en position. Cibles marquées sur le réseau tactique.";
```
