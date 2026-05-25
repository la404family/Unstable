# TASK_TREE.md — Arbre de mission

Ce fichier est la référence de l'enchaînement des tâches.  
Toujours le mettre à jour avant de coder une nouvelle tâche.

---

## Arbre complet

```mermaid
flowchart TD
    START([Mission Start]) --> T00

    T00["task00 — Embarquement\nfn_task00.sqf\nÉtat final : SUCCEEDED uniquement"]
    T00 --> T01

    T01["task01 — Rendez-vous de reconnaissance\nfn_task01.sqf\nScénario tiré aléatoirement 1/2/3"]

    T01 -->|"Scénario 1\nCoopération\n→ SUCCEEDED"| T02A
    T01 -->|"Scénario 2\nTrahison\n→ SUCCEEDED après élimination"| T02B
    T01 -->|"Scénario 3 — chef survit\nMutinerie\n→ SUCCEEDED"| T02C
    T01 -->|"Scénario 3 — chef mort\nMutinerie\n→ FAILED\nRenseignements perdus"| T02B

    T02A["task02a — Neutraliser les chefs / Récupérer les documents\nfn_task02a.sqf"]
    T02B["task02b — Le Fil Rouge — Libération de l'informateur\nfn_task02b.sqf"]
    T02C["task02c — L'Intermédiaire — Capturer le financier\nfn_task02c.sqf"]

    T02A --> EXFIL
    T02B --> EXFIL
    T02C --> EXFIL

    EXFIL(["Fin de mission\nExtraction hélicoptère\ninitiée par le joueur\nBIS_fnc_endMission"])
```

---

## Détail par tâche

| ID | Fichier | Déclencheur | Issues | Tâche suivante |
|---|---|---|---|---|
| `task00` | `fn_task00.sqf` | `fn_taskManager.sqf` au lancement | `SUCCEEDED` uniquement | `task01` |
| `task01` | `fn_task01.sqf` | Après `task00 SUCCEEDED` | `SUCCEEDED` (S1, S2, S3-chef-vivant) / `FAILED` (S3-chef-mort) | S1→`task02a` / S2→`task02b` / S3-vivant→`task02c` / S3-mort→`task02b` |
| `task02a` | `fn_task02a.sqf` | `LL_g_task01_scenario == 1` (Coopération) | `SUCCEEDED` (documents récupérés) | Extraction |
| `task02b` | `fn_task02b.sqf` | Trahison **ou** Mutinerie chef mort | `SUCCEEDED` (informateur libéré) / `FAILED` (tué) | Extraction |
| `task02c` | `fn_task02c.sqf` | `LL_g_task01_scenario == 3` + chef vivant (Mutinerie réussie) | `SUCCEEDED` (intermédiaire capturé) / `FAILED` (tué) | Extraction |

---

## Variable de branchement

`LL_g_task01_scenario` (missionNamespace, public) — définie dans `fn_task01.sqf` lors du déclenchement du scénario.

| Valeur | Scénario |
|---|---|
| `1` | Coopération |
| `2` | Trahison |
| `3` | Mutinerie |

---

## Règle de fin de mission

**Aucune tâche ne déclenche `BIS_fnc_endMission`.**  
La fin de mission est exclusivement initiée par le joueur via l'action `[Hélicoptère] Demander Extraction` (TASK_RULES §7).

---

## Changelog

| Date | Modification |
|---|---|
| 2026-05-25 | Création — task00 + task01 documentées, placeholders task04a/b/c |
