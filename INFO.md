# Informations sur les variables présentes dans l'éditeur

## Variables présentes dans l'éditeur:

### LOGIC DE JEU : 

- M_Dans_Bat_000 à M_Dans_Bat_XXX sont game logic placé dans des batiments les M_Dans_Bat_XXX déterminent des lieux précis de missions ( respecter absolument le x,y,z + 0.2)
- Heliport_000 à Heliport_XXX sont des heliport invisibles. pour l'hélicoptère allié
- player_00 à player_XX sont les unités jouables (Royal Army Corps of Sahrani - independant)
- template_01 ... template_XX sont des personnages dans l'éditeur qui servent de gabarit de personnage pour des missions ou des civils...
- ezan_00 à ezan_XX sont des Loudspeaker dans le jeu qui produise l'appel a la prière.
- template_01 à template_16 sont des femmes
- template_16 à template_XX (le reste) sont des hommes...
- Des femmes sont présentes dans l'éditeur grace à un mod les noms des variables pour les femmes sont :
- Max_Tak_woman1 à  Max_Tak_woman6
- Max_Taky_woman1 à  Max_Taky_woman5
- Max_Tak2_woman1 à  Max_Tak2_woman5
- les barbes sont déterminées par la variable CUP_Beard_Brown ou CUP_Beard_Black
- Les chapeaux sont déterminés par : CPU_H_TKI_Lungee_Open_01 à CPU_H_TKI_Lungee_Open_06 ou CPU_H_TKI_Pakol_1_01 à CPU_H_TKI_Pakol_1_05 ou - CPU_H_TKI_SkullCap_01 à CPU_H_TKI_SkullCap_06
- Les chapeaux et les barbes sont réservés aux hommes.
- heliport_00 à heliport_XX sont des heliports invisible
- La variable du drone est : CUP_B_USMC_DYN_MQ9
- vehicule_team est le véhicule des joueurs en début de mission. (nom de variable du véhicule : CUP_B_nM1025_SOV_M2_USMC_DES)
- l'hélicoptère allié est un CH-47F (CUP_I_CH47F_RACS)

---

## Chat et interraction avec le joueur BILINGUE STR stringtable.xml : 

- Toutes les interractions texte en jeu se font avec le systemChat. REGLES A SUIVRE : 
    - `SUPPORT` — Messages liés au soutien hélicoptère ou drone (demande, refus, approbation, livraison, erreur, RTB, cooldown).
    - `QG` ou `HQ`  pour messages narratifs du QG et ordre de mission (taches)
    - `Chef de milice` ou `Militia Leader` pour les chef de milice
    - `Gardes de la milice` ou `Militia Guards`  pour les gardes sous les ordres des chef de milice


