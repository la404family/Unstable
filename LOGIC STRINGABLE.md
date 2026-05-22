## 🛠️ Méthode d'Intégration Non Destructive

Comme les fichiers XML de traduction sont compilés dynamiquement par le script Python [merge_stringtables.py](file:///c:/Users/kevin/Documents/Arma%203/missions/Unstable.porto/merge_stringtables.py), il ne faut **pas** modifier manuellement `stringtable.xml` sous peine de voir les modifications écrasées lors de la prochaine génération.

La méthode propre consiste à ajouter les définitions dans l'un des fichiers XML sources du dossier `tasks/` (par exemple `global_actions.xml`), puis à régénérer la stringtable globale.

Voici la procédure pas à pas : EXEMPLE ! 

LES ETAPES SONT DES EXEMPLES

### Étape 1 : Ajouter les clés de traduction XML
Ouvrez le fichier [global_actions.xml](file:///c:/Users/kevin/Documents/Arma%203/missions/Unstable.porto/tasks/global_actions.xml) et insérez les clés suivantes dans le `<Container name="Actions">` :

```xml
      <!-- Marqueurs du Support Hélicoptère -->
      <Key ID="STR_TAG_Marker_Heli_Ammo">
        <English>Ammo Delivery Zone</English>
        <French>Zone de Livraison Munitions</French>
      </Key>
      <Key ID="STR_TAG_Marker_Heli_Vehicle">
        <English>Vehicle Delivery Zone</English>
        <French>Zone de Livraison Véhicule</French>
      </Key>
      <Key ID="STR_TAG_Marker_Heli_Debark">
        <English>RACS Landing Zone</English>
        <French>Zone de Débarquement RACS</French>
      </Key>
      <Key ID="STR_TAG_Marker_Heli_Extract">
        <English>Extraction Zone</English>
        <French>Zone d'Extraction</French>
      </Key>
      <Key ID="STR_TAG_Marker_Heli_CAS">
        <English>CAS Support Zone</English>
        <French>Zone d'Appui CAS</French>
      </Key>

      <!-- Erreurs Soins -->
      <Key ID="STR_LL_Msg_Heal_NoKit">
        <English>[LL ERROR] Injured AI do not have a first aid kit (FirstAidKit/Medikit).</English>
        <French>[LL ERREUR] Les IA blessées n'ont pas de kit de soin (FirstAidKit/Medikit).</French>
      </Key>
      <Key ID="STR_LL_Msg_Heal_NoInjured">
        <English>[LL ERROR] No injured AI requires healing.</English>
        <French>[LL ERREUR] Aucune IA blessée n'a besoin de soins.</French>
      </Key>

      <!-- Erreurs RoE -->
      <Key ID="STR_LL_Msg_RoE_Stealth_Error">
        <English>[LL ERROR] Failed to apply stealth: Group not found.</English>
        <French>[LL ERREUR] Impossible d'appliquer l'infiltration : Groupe introuvable.</French>
      </Key>
      <Key ID="STR_LL_Msg_RoE_Vigilance_Error">
        <English>[LL ERROR] Failed to apply vigilance: Group not found.</English>
        <French>[LL ERREUR] Impossible d'appliquer la vigilance : Groupe introuvable.</French>
      </Key>
      <Key ID="STR_LL_Msg_RoE_Assault_Error">
        <English>[LL ERROR] Failed to apply assault: Group not found.</English>
        <French>[LL ERREUR] Impossible d'appliquer l'assaut : Groupe introuvable.</French>
      </Key>
      <Key ID="STR_LL_Msg_RoE_Charge_Error">
        <English>[LL ERROR] Failed to apply charge: Group not found.</English>
        <French>[LL ERREUR] Impossible d'appliquer la charge : Groupe introuvable.</French>
      </Key>

      <!-- Erreurs Leadership -->
      <Key ID="STR_LL_Msg_AssignLeader_Error">
        <English>[LL ERROR] assignLeader: No player detected to assign as leader!</English>
        <French>[LL ERREUR] assignLeader : Aucun joueur détecté pour attribuer le leader !</French>
      </Key>
```

### Étape 2 : Régénérer la table des chaînes globales
Exécutez le script de fusion dans votre terminal depuis le répertoire de la mission :
```powershell
python merge_stringtables.py
```
Cela mettra à jour automatiquement le fichier [stringtable.xml](file:///c:/Users/kevin/Documents/Arma%203/missions/Unstable.porto/stringtable.xml) à la racine de la mission en intégrant proprement les nouvelles clés sans perturber le code existant.

### Étape 3 : Mettre à jour le code SQF
Remplacez les chaînes codées en dur par des appels `localize` ou des clés de chaînes dans vos scripts SQF :

#### Dans `fn_requestHelicopter.sqf` (lignes 251-277)
```diff
     switch (_supportType) do {
         case "LIVRAISON": {
             _markerType = "mil_box";
             _markerColor = "ColorBlue";
-            _markerText = "Zone de Livraison Munitions";
+            _markerText = localize "STR_TAG_Marker_Heli_Ammo";
         };
         case "VEHICULE": {
             _markerType = "mil_box";
             _markerColor = "ColorBlue";
-            _markerText = "Zone de Livraison Véhicule";
+            _markerText = localize "STR_TAG_Marker_Heli_Vehicle";
         };
         case "DEBARQUEMENT": {
             _markerType = "mil_end";
             _markerColor = "ColorGreen";
-            _markerText = "Zone de Débarquement RACS";
+            _markerText = localize "STR_TAG_Marker_Heli_Debark";
         };
         case "EMBARQUEMENT": {
             _markerType = "mil_pickup";
             _markerColor = "ColorYellow";
-            _markerText = "Zone d'Extraction";
+            _markerText = localize "STR_TAG_Marker_Heli_Extract";
         };
         case "CAS": {
             _markerType = "mil_warning";
             _markerColor = "ColorRed";
-            _markerText = "Zone d'Appui CAS";
+            _markerText = localize "STR_TAG_Marker_Heli_CAS";
         };
     };
```

#### Dans `fn_addHealAction.sqf` (lignes 73-77)
```diff
                     if (_injuredWithKits isEqualTo []) then {
-                        systemChat "[LL ERROR] Les IA blessées n'ont pas de kit de soin (FirstAidKit/Medikit).";
+                        systemChat localize "STR_LL_Msg_Heal_NoKit";
                     } else {
-                        systemChat "[LL ERROR] Aucune IA blessée n'a besoin de soins.";
+                        systemChat localize "STR_LL_Msg_Heal_NoInjured";
                     };
```

#### Dans `fn_addRoeActions.sqf` (lignes 33, 54, 74, 94)
```diff
-                    systemChat "[LL ERROR] Impossible d'appliquer l'infiltration : Groupe introuvable.";
+                    systemChat localize "STR_LL_Msg_RoE_Stealth_Error";
...
-                    systemChat "[LL ERROR] Impossible d'appliquer la vigilance : Groupe introuvable.";
+                    systemChat localize "STR_LL_Msg_RoE_Vigilance_Error";
...
-                    systemChat "[LL ERROR] Impossible d'appliquer l'assaut : Groupe introuvable.";
+                    systemChat localize "STR_LL_Msg_RoE_Assault_Error";
...
-                    systemChat "[LL ERROR] Impossible d'appliquer la charge : Groupe introuvable.";
+                    systemChat localize "STR_LL_Msg_RoE_Charge_Error";
```

#### Dans `fn_assignLeader.sqf` (ligne 29)
```diff
 if (isNull _newLeader) exitWith {
-    ["[LL ERROR] assignLeader: Aucun joueur détecté pour attribuer le leader!"] remoteExec ["systemChat", 0];
+    [localize "STR_LL_Msg_AssignLeader_Error"] remoteExec ["systemChat", 0];
     diag_log "[LL][assignLeader] Erreur: Aucun joueur détecté au démarrage pour attribuer le rôle de leader.";
 };
```
