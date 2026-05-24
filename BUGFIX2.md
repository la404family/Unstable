# BUGFIX2 — Rapport d'analyse et Solutions

Ce document traite des problèmes persistants de respawn et de la configuration des IA en multijoueur pour la mission "Operation Royal Alliance".

## Problème 1 : Respawn intempestif au marqueur (Une seule vie)

**Symptôme :** Malgré le système de basculement vers l'IA, si aucune IA n'est disponible, le joueur réapparaît après 10 secondes au marqueur `respawn_west`.
**Cause :** Le paramètre `respawn = 3` dans `description.ext` force Arma 3 à faire réapparaître le joueur si rien n'interrompt le cycle.
**Solution :** 
1. Empêcher techniquement le respawn individuel si aucune IA n'est disponible.
2. Basculer le joueur en mode spectateur pour qu'il puisse suivre ses coéquipiers.
3. Améliorer la détection de fin de partie.

### Modification de `functions/fn_switchToAI.sqf`
Il faut ajouter l'arrêt du respawn et le démarrage du spectateur dans la branche `else`.

```sqf
} else {
    // Empêcher le respawn natif Arma 3 (le mettre à un temps infini)
    setPlayerRespawnTime 999999;
    
    // Activer le mode spectateur (Standard Arma 3)
    ["Initialize", [player, [], true]] call BIS_fnc_EGSpectator;

    // Déclencher la vérification de fin de partie côté serveur
    [] remoteExec ["LL_fnc_checkGameOver", 2];

    if (DEBUG_MODE) then {
        diag_log "[LL] switchToAI: Aucune IA disponible. Respawn bloqué, Spectateur activé.";
    };
};
```

### Amélioration de `functions/fn_checkGameOver.sqf`
Pour éviter que la mission ne se termine alors qu'un autre joueur est en train de basculer sur une IA, il faut ajouter un délai de sécurité avant la vérification finale.

```sqf
if (!isServer) exitWith {};

[] spawn {
    // Attendre que les scripts switchToAI des clients aient fini leur travail (sleep 3 + selectPlayer)
    sleep 5;

    private _allPlayers = allPlayers - entities "HeadlessClient_F";
    private _alivePlayers = _allPlayers select { alive _x };

    if (count _allPlayers > 0 && { count _alivePlayers == 0 }) then {
        if (DEBUG_MODE) then {
            diag_log "[LL] checkGameOver: Tous les joueurs sont morts. Fin de mission.";
        };
        ["MissionFailed", false, 5] remoteExec ["BIS_fnc_endMission", 0];
    };
};
```

---

## Problème 2 : Impossibilité d'ajouter des IA en Multiplayer

**Symptôme :** Les slots de joueurs vides ne peuvent pas être occupés par des IA dans le lobby.
**Cause :** `disabledAI = 1;` dans `description.ext`.
**Solution :** Passer `disabledAI` à `0`. Cela permet aux IA d'occuper les slots non pris par des humains, offrant ainsi une "réserve" de vies pour le système de basculement.

### Modification de `description.ext`
```sqf
// AVANT
disabledAI = 1;

// APRÈS
disabledAI = 0;
```

---

## Synthèse des Actions à implémenter

| Fichier | Action | Impact |
|---|---|---|
| `description.ext` | Modifier `disabledAI = 0` | Autorise les IA dans les slots vides au démarrage. |
| `description.ext` | `respawnDelay = 999999` et `respawnTemplates[] = {"Tickets"}` | Bloque définitivement le respawn natif Arma 3. |
| `initServer.sqf` | `[west, 0] call BIS_fnc_respawnTickets` | Met les tickets de respawn à zéro dès le départ. |
| `initServer.sqf` | Regroupement des joueurs | Force tous les joueurs et IA dans le même groupe pour partager le pool de vies. |
| `functions/fn_switchToAI.sqf` | Ajouter `setPlayerRespawnTime` et `BIS_fnc_EGSpectator` | Bloque le respawn à la base et permet de spectater. |
| `functions/fn_checkGameOver.sqf` | Ajouter un `sleep 5` avant le check | Évite les fins de mission prématurées par désynchronisation. |

---

## Note sur le mode Spectateur
L'utilisation de `BIS_fnc_EGSpectator` est le standard recommandé. Si le joueur doit pouvoir revenir en jeu (par exemple si une nouvelle IA est spawnée par un script de renfort), il faudra prévoir une fonction pour quitter le mode spectateur, mais dans le cadre d'une "vie unique", le mode spectateur jusqu'à la fin de la mission est le comportement attendu.
