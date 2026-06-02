# PROMPT : 

## CONTEXTE ET RÔLE
Tu es un expert en narration militaire, scénariste pour des simulations tactiques exigeantes et un "Lore Master" dans le fichier : STEAM_STORY.md
Ton but est de rédiger des lignes de dialogue radio, des briefings immersifs, des sous-titres de PNJ et des messages textuels pour une immersion total….

## DIRECTIVES DE STYLE DES TEXTES
1. Format Radio (QG / Narrateur) : Utiliser le vocabulaire de procédure radio ("Ici QG", "Terminé", "Reçu", "Visuel", "En route"). Les phrases doivent être courtes, percutantes, directes.
2. Les phrase RADIO QG commencent toutes par "PC alpha à unité de terrain… "
3. Immersion Tactique : Mentionner des éléments concrets (présence de civils, risques, supports aérien Chinook ou drone MQ-9 Reaper disponibles).
3. Langue : Français militaire correct, sans anachronismes. 

## FORMAT DE LA DEMANDE (Ce que l'utilisateur va te demander)
L'utilisateur va te donner un ID de tâche (ex: TASK 01, TASK 03B) ou une situation (ex: "Mort de l'informateur", "Le drone arrive sur zone"). Tu devras générer :
- [MESSAGE RADIO QG] : Le texte officiel transmis dans le casque des joueurs.
- [DIAL PNJ / SOUTIEN] : Les lignes de dialogue s'il y a un tiers impliqué.
- [DESCRIP_IMMERSIVE] : Un court texte d'ambiance pour le journal (Diary) ou la description de la tâche.

# TEXTE A FAIRE : 

## Fichier : `description.ext`

| Identifiant (Key)             | Texte                                  |
| -------------------------------| ----------------------------------------|
| `STR_LL_End_Failed_Desc`      | L'opération a échoué.                  |
| `STR_LL_End_Failed_Subtitle`  | La situation a échappé au contrôle     |
| `STR_LL_End_Failed_Title`     | Mission Échouée                        |
| `STR_LL_End_Success_Desc`     | L'opération est terminée. Bon travail. |
| `STR_LL_End_Success_Subtitle` | Votre unité a été extraite de Porto    |
| `STR_LL_End_Success_Title`    | Mission Terminée                       |

## Fichier : `functions\fn_addDroneAction.sqf`

| Identifiant (Key)          | Texte                                                                     |
| ----------------------------| ---------------------------------------------------------------------------|
| `STR_LL_Drone_Action`      | [Drone] Demander Surveillance MQ-9                                        |
| `STR_TAG_Msg_Drone_Denied` | 🟢[SUPPORT] Soutien drone refusé. Un drone de surveillance est déjà actif. |

## Fichier : `functions\fn_addHealAction.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Action_Heal` | [ESCOUADE] Ordonner à l'escouade de se soigner |
| `STR_LL_Msg_Heal_NoInjured` | [LL ERREUR] Aucun membre blesse de l'escouade n'a besoin de soins. |
| `STR_LL_Msg_Heal_NoKit` | [LL ERREUR] Les membres blessés de l'escouade n'ont pas de kit de soin (FirstAidKit/Medikit). |

## Fichier : `functions\fn_addHelicopterActions.sqf`

| Identifiant (Key)                   | Texte　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| -------------------------------------| ----------------------------------------------------------------------------------------------|
| `STR_LL_Heli_Action_Extraction`     | [Hélicoptère] Demander Extraction (Embarquement)　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Heli_Action_Reinforcements` | [Hélicoptère] Demander Renforts (Débarquement)　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Heli_Action_Supply`         | [Hélicoptère] Demander Livraison Munitions　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_TAG_Heli_Action_CAS`           | [Hélicoptère] Demander Appui Aérien (CAS)　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Heli_Action_Vehicle`       | [Hélicoptère] Demander Livraison Véhicule　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_CAS_Cooldown`          | 🟢[SUPPORT] Soutien CAS indisponible. Veuillez patienter %1 secondes avant le prochain appel. |
| `STR_TAG_Msg_Vehicle_Denied_Once`   | 🔴[SUPPORT] Soutien refusé. Le véhicule de remplacement a déjà été livré.　　　　　　　　　　|

## Fichier : `functions\fn_addRallyAction.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Action_Rally` | [ESCOUADE] Forcer le regroupement de l'escouade |
| `STR_LL_Msg_Rally_Done` | [ESCOUADE] Regroupement terminé. |
| `STR_LL_Msg_Rally_NoAI` | [ESCOUADE] Aucun membre actif dans votre groupe. |
| `STR_LL_Msg_Rally_Start` | [ESCOUADE] Regroupement ordonné. L'escouade rejoint la formation. |

## Fichier : `functions\fn_addResupplyAction.sqf`

| Identifiant (Key)           | Texte                                                                     |
| -----------------------------| ---------------------------------------------------------------------------|
| `STR_LL_Action_Resupply`    | [Ravitaillement] Ordonner le réapprovisionnement                          |
| `STR_LL_Msg_Resupply_Done`  | [SUPPORT] Réapprovisionnement terminé. Regroupement.                      |
| `STR_LL_Msg_Resupply_NoAI`  | [SUPPORT] Aucun membre d'escouade disponible pour le réapprovisionnement. |
| `STR_LL_Msg_Resupply_Start` | [SUPPORT] L'escouade se réapprovisionne depuis la caisse.                 |

## Fichier : `functions\fn_addRoeActions.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Action_RoE_Assault` | [ESCOUADE] Règles d'engagement : Assaut (Tir libre/Combat) |
| `STR_LL_Action_RoE_Charge` | [ESCOUADE] Règles d'engagement : Charge (Sprint/Assaut permanent) |
| `STR_LL_Action_RoE_Stealth` | [ESCOUADE] Règles d'engagement : Infiltration (Silencieux/Marche) |
| `STR_LL_Action_RoE_Vigilance` | [ESCOUADE] Règles d'engagement : Vigilance (Combat/Prudent) |
| `STR_LL_Msg_RoE_Assault_Error` | [LL ERREUR] Impossible d'appliquer l'assaut : Groupe introuvable. |
| `STR_LL_Msg_RoE_Charge_Error` | [LL ERREUR] Impossible d'appliquer la charge : Groupe introuvable. |
| `STR_LL_Msg_RoE_Stealth_Error` | [LL ERREUR] Impossible d'appliquer l'infiltration : Groupe introuvable. |
| `STR_LL_Msg_RoE_Vigilance_Error` | [LL ERREUR] Impossible d'appliquer la vigilance : Groupe introuvable. |

## Fichier : `functions\fn_addSearchAction.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Action_Search` | [ESCOUADE] Fouiller les bâtiments |
| `STR_LL_Msg_Search_NoBuilding` | [LL ERREUR] Fouille : Aucun bâtiment avec des positions intérieures à proximité. |
| `STR_LL_Msg_Search_NoInfantry` | [LL ERREUR] Fouille : Aucun membre d'escouade actif dans votre groupe pour fouiller. |
| `STR_LL_Msg_Search_NotAccessible` | [LL ERREUR] Fouille : Les positions dans les bâtiments ne sont pas accessibles. |

## Fichier : `functions\fn_heliDispatch.sqf`

| Identifiant (Key)                 | Texte　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| -----------------------------------| -----------------------------------------------------------------------------------------------|
| `STR_LL_Heli_Msg_Route`           | 🟢[SUPPORT] Hélicoptère de support MH-47E en route vers la zone.　　　　　　　　　　　　　　　 |
| `STR_TAG_Msg_Ammo_Approved`       | 🟢[SUPPORT] Demande approuvée. Chinook en route.　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_TAG_Msg_Ammo_Denied`         | 🔴[SUPPORT] Soutien aérien refusé. Espace aérien occupé.　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_CAS_Approved`        | 🟢[SUPPORT] Demande approuvée. Chinook en route pour appui aérien.　　　　　　　　　　　　　　 |
| `STR_TAG_Msg_CAS_Cooldown`        | 🔴[SUPPORT] Soutien CAS indisponible. Veuillez patienter %1 secondes avant le prochain appel. |
| `STR_TAG_Msg_CAS_Denied`          | 🔴[SUPPORT] Soutien aérien refusé. Espace aérien occupé.　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_Vehicle_Approved`    | 🟢[SUPPORT] Demande approuvée. Chinook en route avec le véhicule de remplacement.　　　　　　　|
| `STR_TAG_Msg_Vehicle_Denied`      | 🔴[SUPPORT] Soutien aérien refusé. Espace aérien occupé.　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_Vehicle_Denied_Once` | 🔴[SUPPORT] Soutien refusé. Le véhicule de remplacement a déjà été livré.　　　　　　　　　　 |

## Fichier : `functions\fn_heliManager.sqf`

| Identifiant (Key)                              | Texte　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| ------------------------------------------------| ---------------------------------------------------------------------------------------------------------------|
| `STR_LL_Heli_Msg_Active`                       | 🟢[SUPPORT] Un hélicoptère de support est déjà demandé ou actif. Veuillez patienter.　　　　　　　　　　　　　 |
| `STR_LL_Heli_Msg_CargoAborted`                 | 🔴[SUPPORT] Livraison annulée — redirigé vers mission prioritaire. Caisse de ravitaillement annulée.　　　　　|
| `STR_LL_Heli_Msg_Departing`                    | 🟢[SUPPORT] Décollage. Retour vers le point d'extraction.　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Heli_Msg_Extract_Counter`              | Extraction — %1 / %2 à bord　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Heli_Msg_Extract_Players_Exit_Warning` | ATTENTION : L'hélicoptère ne partira pas tant qu'un joueur est à bord ! Sortez !　　　　　　　　　　　　　　　|
| `STR_LL_Heli_Msg_Extract_Waiting_Hostage`      | Attente embarquement de l'informateur (%1m)...　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Heli_Msg_Killed`                       | 🔴[SUPPORT] L'hélicoptère de support a été abattu !　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Heli_Msg_Landed_Extract`               | 🟢[SUPPORT] Hélicoptère posé. Embarquez les unités puis utilisez l'action sur l'hélico pour le faire décoller. |
| `STR_LL_Heli_Msg_Landed_Reinforce`             | 🟢[SUPPORT] Parachutage des renforts.　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Heli_Msg_Patrol_Started`               | [SUPPORT] Renforts alliés en patrouille de sécurisation.　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Heli_Msg_Squad_Joined`                 | [SUPPORT] Renforts alliés intégrés à votre escouade.　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Marker_Heli_Ammo`                     | Zone de Livraison Munitions　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_TAG_Marker_Heli_CAS`                      | Zone d'Appui CAS　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Marker_Heli_Debark`                   | Zone de Débarquement RACS　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_TAG_Marker_Heli_Extract`                  | Zone d'Extraction　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_TAG_Marker_Heli_Vehicle`                  | Zone de Livraison Véhicule　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_Ammo_Dropped`                     | 🟢[SUPPORT] Colis largué avec succès.　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_Ammo_Error`                       | [SUPPORT] Erreur de soutien aérien. Impossible de créer l'hélicoptère.　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_CAS_Error`                        | [SUPPORT] Erreur de soutien aérien. Impossible de créer l'hélicoptère.　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_CAS_RTB`                          | 🟢[SUPPORT] Mission CAS terminée. Hélicoptère de retour à la base.　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_TAG_Msg_Vehicle_Dropped`                  | 🟢[SUPPORT] Véhicule livré avec succès.　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_Vehicle_Error`                    | [SUPPORT] Erreur de soutien aérien. Impossible de créer l'hélicoptère.　　　　　　　　　　　　　　　　　　　　|

## Fichier : `functions\fn_initPlayer.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Briefing_Text` | <font size='16' color='#FFFF00'>OPÉRATION ROYAL ALLIANCE</font><br/><br/><br><font size='14' color='#00FF00'>1. SITUATION</font><br/><br>L'île-port de Porto est en proie à de vives tensions ethniques, confessionnelles et idéologiques, catalysées par la pauvreté, la corruption locale et les flux migratoires clandestins. Des groupes armés insurgés, notamment le Front de Libération (FL) nationaliste ethnique et le Mouvement pour la Justice (MJ) djihadiste, tentent d'établir une base arrière et de saborder l'autorité de la Couronne de Sahrani. Le Corps Expéditionnaire Multinational du RACS est déployé pour restaurer la sécurité civile et assurer la pacification globale de l'île.<br/><br/><br><font size='14' color='#00FF00'>2. MISSION</font><br/><br>Mener des opérations de sécurisation, patrouiller les zones urbaines et neutraliser les menaces insurgées à travers plusieurs tâches successives afin d'assurer le contrôle territorial et la sécurité civile de Porto. Le rendez-vous avec un chef de milice locale n'est qu'une des tâches initiales visant à obtenir des renseignements clés sur les réseaux ennemis.<br/><br/><br><font size='14' color='#00FF00'>3. SOUTIEN</font><br/><br>Le transport initial est assuré par le véhicule d'escouade. Durant l'opération, vous disposez d'un soutien aérien à la demande, d'un survol permanent par drone (MQ-9), ainsi que de possibilités de livraisons logistiques de munitions et de véhicules de remplacement en cas de besoin. Bonne chance, soldats. |
| `STR_LL_Briefing_Title` | Ordre d'Opération (OPORD) |
| `STR_LL_Diary_Context_Text` | <font size='16' color='#FFFF00'>CONTEXTE GLOBAL</font><br/><br>Après la réunification difficile de Sahrani, le Royaume reste un État fragile. Le Nord nationaliste ethnique a été vaincu, mais ses réseaux clandestins et ses armes subsistent.<br/><br>Le pays est devenu un hub en Atlantique pour les routes migratoires clandestines et les trafics d'armes et de drogue.<br/><br/><br>Le <font color='#00FF00'>RACS</font> a instauré un Corps Expéditionnaire Multinational intégrant des volontaires de pays alliés (Turquie, pays arabes, Afrique, Indonésie).<br/><br/><br><font size='16' color='#FFFF00'>SITUATION TACTIQUE À PORTO</font><br/><br>Porto est une île-port secondaire en proie à de vives tensions ethniques, confessionnelles et idéologiques, catalysées par la pauvreté, la corruption locale et les flux migratoires. |
| `STR_LL_Diary_Context_Title` | Contexte et Situation |
| `STR_LL_Diary_Factions_Text` | <font size='16' color='#FF0000'>FRONT DE LIBÉRATION (FL)</font><br/><br>Idéologie nationaliste ethnique et anti-monarchiste. Recrute parmi les déçus de la couronne. Vise à chasser le RACS de Porto.<br/><br/><br><font size='16' color='#FF0000'>MOUVEMENT POUR LA JUSTICE (MJ)</font><br/><br>Groupe djihadiste lié à un réseau transnational. Vise à faire de Porto un sanctuaire logistique et de contrebande.<br/><br/><br><font size='16' color='#FF0000'>MILICES ET CARTELS DE CONTREBANDE</font><br/><br>Criminels opportunistes voulant maintenir l'anarchie locale pour pérenniser leurs trafics maritimes. |
| `STR_LL_Diary_Factions_Title` | Factions |
| `STR_LL_Diary_Lore_Text` | <font size='16' color='#FFFF00'>LORE DE CAMPAGNE (2025-2026)</font><br/><br>Suite à des attentats sanglants sur le continent (marché de Corazol, poste de Bagango), Porto a été identifiée comme la plaque tournante logistique du MJ et du FL.<br/><br/><br>Le Roi de Sahrani a lancé cette opération de pacification autonome pour prouver que le RACS multinational est capable de stabiliser son territory sans intervention directe de l'OTAN ou des États-Unis. <font color='#FFFF00'>C'est un test décisif pour la crédibilité du Royaume.</font> |
| `STR_LL_Diary_Lore_Title` | Historique Narratif |

## Fichier : `functions\fn_intro.sqf`

| Identifiant (Key)                   | Texte                                                |
| -------------------------------------| ------------------------------------------------------|
| `STR_LL_Intro_Author`               | RACS — Corps Expéditionnaire Multinational           |
| `STR_LL_Intro_Location`             | Île de Porto                                         |
| `STR_LL_Intro_MissionStartSubtitle` | Equipe de soldat d'élite                             |
| `STR_LL_Intro_Presents`             | Une opération de pacification post-conflit à Sahrani |
| `STR_LL_Intro_Title`                | OPÉRATION ROYAL ALLIANCE                             |

## Fichier : `functions\fn_requestDrone.sqf`

| Identifiant (Key)            | Texte　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| ------------------------------| ---------------------------------------------------------------------------------------------------------|
| `STR_TAG_Msg_Drone_Approved` | 🟢[SUPPORT] Demande approuvée. Drone MQ-9 en route vers la zone.　　　　　　　　　　　　　　　　　　　　 |
| `STR_TAG_Msg_Drone_Denied`   | 🔴[SUPPORT] Soutien drone refusé. Un drone de surveillance est déjà actif.　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_Drone_End`      | 🟢[SUPPORT] Mission drone terminée. MQ-9 de retour à la base.　　　　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_Drone_Error`    | 🔴[SUPPORT] Erreur soutien drone. Impossible de déployer le drone.　　　　　　　　　　　　　　　　　　　|
| `STR_TAG_Msg_Drone_Overhead` | 🟢[SUPPORT] MQ-9 sur zone. Surveillance active. Positions ennemies et alliées mises à jour sur la carte. |

## Fichier : `functions\fn_showSubtitle.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Speaker_Chief` | Chef de milice |
| `STR_LL_Task_01_S1_Chief` | Voici les coordonnées et leurs plans de patrouille. |

## Fichier : `functions\fn_switchToAI.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Msg_Switch_Error` | [LL ERREUR] Délai d'attente dépassé pour le transfert de localité. Impossible de basculer sur l'unité. |

## Fichier : `tasks\fn_task00.sqf`

| Identifiant (Key)                | Texte                                                                                                           |
| ----------------------------------| -----------------------------------------------------------------------------------------------------------------|
| `STR_LL_Speaker_Narrator`        | QG                                                                                                              |
| `STR_LL_Task_00_Desc`            | 🟢 Montez à bord du véhicule de patrouille avec votre escouade pour commencer l'opération.                       |
| `STR_LL_Task_00_Marker`          | Point de rassemblement                                                                                          |
| `STR_LL_Task_00_Narrative_Start` | 🟢 Ici QG, répondez. Préparez votre équipement et montez dans le véhicule pour commencer la patrouille. Terminé. |
| `STR_LL_Task_00_Title`           | Embarquement                                                                                                    |

## Fichier : `tasks\fn_task01.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Speaker_Chief` | Chef de milice |
| `STR_LL_Speaker_Guards` | Gardes de la milice |
| `STR_LL_Speaker_Narrator` | QG |
| `STR_LL_Task_01_Desc` | Rendez-vous au lieu de rencontre indiqué dans le bâtiment pour obtenir les renseignements auprès du chef de milice. |
| `STR_LL_Task_01_Marker` | Lieu de rencontre |
| `STR_LL_Task_01_Narrative_Meeting` | Ici QG. Nous avons localisé le chef de milice. Rendez-vous au bâtiment désigné et établissez le contact. Faites preuve de prudence. Terminé. |
| `STR_LL_Task_01_Narrative_S1_Success` | QG à patrouille. Positions insurgées confirmées. Terminé. |
| `STR_LL_Task_01_Narrative_S2_Start` | TRAHISON ! |
| `STR_LL_Task_01_Narrative_S2_Success` | QG à patrouille. Excellent travail sous le feu. Terminé. |
| `STR_LL_Task_01_Narrative_S3_Failed` | QG à patrouille. Le chef de milice a été tué. Les renseignements sont perdus. Terminé. |
| `STR_LL_Task_01_Narrative_S3_Start` | QG à patrouille. Protégez le chef de milice et éliminez les gardes mutins ! Il doit survivre ! |
| `STR_LL_Task_01_Narrative_S3_Success` | QG à patrouille. Mutins éliminés et le chef est sain et sauf. Les renseignements sont sécurisés. Terminé. |
| `STR_LL_Task_01_S1_Chief` | Voici les coordonnées et leurs plans de patrouille. |
| `STR_LL_Task_01_S3_Chief` | Je suis avec vous mais il y a des traîtres ici ! |
| `STR_LL_Task_01_S3_Guards` | Traître ! Tu vends notre cause aux étrangers ! Tu vas mourir avec eux ! |
| `STR_LL_Task_01_Title` | Contacter le chef de milice |

## Fichier : `tasks\fn_task01_addAction.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Task_01_Action` | Parler au chef de milice |

## Fichier : `tasks\fn_task02a.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Speaker_Narrator` | QG |
| `STR_LL_Task_02a_Desc` | Trois groupes de miliciens opèrent dans le secteur. Neutralisez leurs chefs et récupérez les documents de renseignement détenus par l'un d'eux. |
| `STR_LL_Task_02a_Doc` | Documents de renseignement |
| `STR_LL_Task_02a_Marker` | Secteur |
| `STR_LL_Task_02a_Narrative_DocFound` | QG à patrouille. Cible neutralisée. Documents localisés sur le corps. Sécurisez ces renseignements immédiatement. Terminé. |
| `STR_LL_Task_02a_Narrative_Start` | QG à patrouille. Trois cellules de milice sont actives dans votre secteur. Nos renseignements indiquent que l'un de leurs chefs transporte des documents sensibles. Neutralisez les trois commandants et récupérez ces informations. Terminé. |
| `STR_LL_Task_02a_Narrative_Success` | QG à patrouille. Documents sécurisés. Les renseignements sont acheminés vers le commandement. Bien joué. Terminé. |
| `STR_LL_Task_02a_Target` | Chef %1 |
| `STR_LL_Task_02a_Title` | Chasse aux renseignements |

## Fichier : `tasks\fn_task02a_addAction.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Task_02a_Pickup` | Récupérer les documents de renseignement |

## Fichier : `tasks\fn_task02b.sqf`

| Identifiant (Key)                   | Texte                                                                                                                                                                                                                         |
| -------------------------------------| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `STR_LL_Speaker_Informateur`        | Informateur                                                                                                                                                                                                                   |
| `STR_LL_Speaker_Narrator`           | QG                                                                                                                                                                                                                            |
| `STR_LL_Task_02b_Desc`              | Nassim, notre informateur à Porto, a été capturé par la milice. Localisez-le dans l'une des zones de recherche, neutralisez ses gardiens et libérez-le.                                                                       |
| `STR_LL_Task_02b_Informateur_Freed` | Ils… ils allaient m'exécuter... Sortez-moi d'ici.                                                                                                                                                                             |
| `STR_LL_Task_02b_Marker`            | Zone de recherche                                                                                                                                                                                                             |
| `STR_LL_Task_02b_MarkerHostage`     | Informateur                                                                                                                                                                                                                   |
| `STR_LL_Task_02b_Narrative_Failed`  | 🟢 QG à patrouille. L'informateur a été tué. Nous avons perdu une source de renseignement critique. La mission continue — notre réseau est compromis. Terminé.                                                                 |
| `STR_LL_Task_02b_Narrative_Start`   | 🟢 QG à patrouille. Notre informateur a été enlevé par la milice. Il se trouve quelque part dans le secteur — localisez-le, éliminez ses gardiens et exfiltrez-le. Il est crucial pour notre réseau de renseignement. Terminé. |
| `STR_LL_Task_02b_Narrative_Success` | 🟢 QG à patrouille. L'informateur est en sécurité. Les renseignements qu'il transmet sont acheminés vers le commandement. Bien joué. Terminé.                                                                                  |
| `STR_LL_Task_02b_Title`             | Exfiltrer l'informateur                                                                                                                                                                                                       |
| `STR_LL_Task_02b_ZoneMarker`        | Zone de fouille                                                                                                                                                                                                               |

## Fichier : `tasks\fn_task02b_addAction.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Task_02b_Free` | Libérer l'informateur |

## Fichier : `tasks\fn_task02c.sqf`

| Identifiant (Key)                           | Texte                                                                                                                                                                                                                                                                                                                      |
| ---------------------------------------------| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `STR_LL_Speaker_Chief`                      | Chef de milice                                                                                                                                                                                                                                                                                                             |
| `STR_LL_Speaker_Intermediaire`              | Intermédiaire financier                                                                                                                                                                                                                                                                                                    |
| `STR_LL_Speaker_Narrator`                   | QG                                                                                                                                                                                                                                                                                                                         |
| `STR_LL_Task_01_Action`                     | Parler au chef de milice                                                                                                                                                                                                                                                                                                   |
| `STR_LL_Task_02c_Chief_Intel`               | Je sais qui fait passer l'argent ici. Un intermédiaire indépendant — il coordonne les flux de fonds entre les milices et les cartels locaux. Il opère depuis un endroit dans ce secteur. Il ne se bat pas, mais il est protégé. Capturez-le vivant — il connaît les noms, les lieux de stockage, les prochains transferts. |
| `STR_LL_Task_02c_Chief_Leaves`              | Votre équipe d'extraction s'occupe de lui. Je les rejoins moi-même — il vaut mieux que je me fasse discret un moment. Bonne chance.                                                                                                                                                                                        |
| `STR_LL_Task_02c_Desc`                      | Le chef de milice a révélé la position d'un intermédiaire financier qui coordonne les flux de fonds entre les milices et les cartels locaux. Localisez-le, éliminez ses gardes du corps et capturez-le vivant. Sa mort compromettrait toute la chaîne de renseignement.                                                    |
| `STR_LL_Task_02c_Intermediaire_Captured`    | D'accord, d'accord ! Je coopère ! Je sais des choses — des choses importantes. Ne tirez pas !                                                                                                                                                                                                                              |
| `STR_LL_Task_02c_Marker`                    | Intermédiaire financier                                                                                                                                                                                                                                                                                                    |
| `STR_LL_Task_02c_Narrative_Extraction_Team` | 🟢 QG à patrouille. Une équipe de récupération a été envoyée à votre position. Elle prendra en charge le prisonnier discrètement. Éloignez-vous à plus de 500 mètres pour permettre leur intervention sans être repérés. Ne restez PAS à proximité du prisonnier. Terminé.                                                  |
| `STR_LL_Task_02c_Narrative_Failed`          | 🟢 QG à patrouille. L'intermédiaire financier a été tué. La piste financière est perdue. Le réseau logistique est compromis. La mission continue. Terminé.                                                                                                                                                                  |
| `STR_LL_Task_02c_Narrative_Start`           | 🟢 QG à patrouille. Objectif confirmé. Localisez l'intermédiaire financier dans votre secteur, éliminez sa protection et capturez-le vivant. Il est un atout de renseignement critique. Ne le tuez pas. Terminé.                                                                                                            |
| `STR_LL_Task_02c_Narrative_Success`         | 🟢 QG à patrouille. L'intermédiaire financier est sécurisé. Ses renseignements sur les flux financiers milice-cartel sont en cours d'extraction. Bien joué. Terminé.                                                                                                                                                        |
| `STR_LL_Task_02c_Title`                     | Capturer l'intermédiaire                                                                                                                                                                                                                                                                                                   |

## Fichier : `tasks\fn_task02c_addAction.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Task_02c_Capture` | Maîtriser l'intermédiaire |
| `STR_LL_Task_02c_ChiefTalk` | Interroger le chef de milice |

## Fichier : `tasks\fn_task03a.sqf`

| Identifiant (Key)                   | Texte                                                                                                                                                                                                                                                                                                           |
| -------------------------------------| -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `STR_LL_Speaker_Narrator`           | QG                                                                                                                                                                                                                                                                                                              |
| `STR_LL_Task_03a_Desc`              | Nos opérations bruyantes sur l'île ont poussé les rebelles du FL à se rallier au cartel de Porto. Ils déploient 3 véhicules blindés légers UAZ équipés de lances-grenades AGS-30 pour nous traquer. Appelez le drone MQ-9 en soutien pour localiser et éliminer ces menaces extrêmement dangereuses.            |
| `STR_LL_Task_03a_Marker`            | Véhicule armé ennemi                                                                                                                                                                                                                                                                                            |
| `STR_LL_Task_03a_Narrative_Start`   | 🟢 QG à patrouille. Le bruit de nos opérations a déclenché une réaction d'urgence : les extrémistes du FL se sont alliés au cartel ! Ils ont mobilisé trois véhicules d'assaut armés UAZ pour ratisser votre secteur. Faites appel au drone MQ-9 depuis vos options radio pour neutraliser ces menaces. Terminé. |
| `STR_LL_Task_03a_Narrative_Success` | 🟢 QG à patrouille. Tous les véhicules armés détruits. Mais les combattants survivants rompent les rangs et convergent sur votre position. Attendez-vous à un contact. Tenez la position et demandez l'extraction quand vous êtes prêts. Terminé.                                                                |
| `STR_LL_Task_03a_Surv_Desc`         | 🟢 Les combattants ennemis survivants se regroupent et convergent vers votre position. Tenez la position et éliminez les menaces restantes. Lorsque la situation est maîtrisée, demandez l'extraction via vos options radio.                                                                                     |
| `STR_LL_Task_03a_Surv_Marker`       | Tenir la position                                                                                                                                                                                                                                                                                               |
| `STR_LL_Task_03a_Surv_Title`        | Tenir la position                                                                                                                                                                                                                                                                                               |
| `STR_LL_Task_03a_Title`             | Neutraliser les véhicules armés                                                                                                                                                                                                                                                                                 |

## Fichier : `tasks\fn_task03b.sqf`

| Identifiant (Key)                       | Texte　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| -----------------------------------------| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `STR_LL_Speaker_Narrator`               | QG　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Task_03b_Bomb_Defused_1`        | SUPPORT — Engin neutralisé. 1 / 2 bombes désamorcées. Continuez !　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Task_03b_Bomb_Defused_2`        | SUPPORT — Second engin neutralisé. 2 / 2 bombes désamorcées !　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Task_03b_Desc`                  | RENSEIGNEMENT FLASH — Le Mouvement pour la Justice (MJ) a dissimulé 2 dispositifs explosifs improvisés dans Porto. Chaque site est protégé par une cellule MJ lourdement armée. Localisez les deux engins et désamorcez-les avant l'expiration du compte à rebours. Vous avez entre 25 et 45 minutes.　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Task_03b_Marker`                | Site d'attentat MJ　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Task_03b_Narrative_All_Defused` | 🟢 QG à toutes les unités. Les deux engins ont été neutralisés. Travail remarquable. Porto a été épargnée. Regroupez-vous et attendez l'extraction quand vous êtes prêts. Terminé.　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Task_03b_Narrative_Explosion`   | 🔴 QG à toutes les unités. Un ou plusieurs engins ont explosé. De nombreuses victimes civiles signalées. Les combattants MJ survivants convergent sur votre position en représailles. Éliminez toutes les menaces restantes. Tenez la position et demandez l'extraction quand la situation est maîtrisée. Terminé.　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Task_03b_Narrative_Start`       | 🟢 QG à toutes les unités. Renseignement flash de notre informateur : le MJ a planté deux engins explosifs dans la ville. Chaque site est sécurisé par une cellule armée — entre 8 et 12 combattants. Attention : certains civils dans la zone sont des sympathisants du MJ. Ils s'armeront et ouvriront le feu si vous approchez. Trouvez les engins, désamorcez-les. Vous avez entre 25 et 45 minutes — le chrono exact est sur votre HUD. L'échec n'est pas une option — Porto ne peut pas absorber une nouvelle atrocité. Terminé. |
| `STR_LL_Task_03b_Surv_Desc`             | 🔴 Les bombes ont explosé. Les cellules MJ convergent sur votre position. Éliminez les combattants survivants et tenez la position jusqu'à l'extraction hélicoptère.　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Task_03b_Surv_Marker`           | Tenir la position　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `STR_LL_Task_03b_Surv_Title`            | Survivre — Tenir la position　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|
| `STR_LL_Task_03b_Title`                 | Opération Bouclier — Désamorcer les bombes　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|

## Fichier : `tasks\fn_task03b_addAction.sqf`

| Identifiant (Key) | Texte | 
| --- | --- |
| `STR_LL_Task_03b_Action_Defuse` | Désamorcer l'explosif [TENIR] |
| `STR_LL_Task_03b_Timer_Label` | BOMBE : %1:%2 |

## Fichier : `tasks\fn_task04.sqf`

| Identifiant (Key)      | Texte                                                                             |
| ------------------------| -----------------------------------------------------------------------------------|
| `STR_LL_Task04_Remind` | 🟢 [EXTRACTION] Demandez votre extraction hélicoptère via le menu d'actions radio. |

