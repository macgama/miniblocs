# Scénarios et défis

Code : `scripts/scenarios/` — `scenarios.gd` (`Scenarios`, le catalogue et le score), `scenario_partie.gd` (`ScenarioPartie`, nœud « Scenario » sous la scène Terre), `scenario_carte.gd` (carte à l'écran), `scenario_bilan.gd` (écran de fin), `scenarios_panel.gd` (fenêtre du menu principal), `classement.gd` (`Classement`). Test : `tests/scenarios_test.gd`. Captures : `tests/scenarios_vitrine.gd`.

## Jouer

Menu principal → **Scénarios et défis**. À gauche la liste (difficulté ●●○, meilleure médaille obtenue), à droite l'histoire, le lieu, la durée, les objectifs, les bonus, les règles, les seuils des médailles et le **classement** des 10 meilleurs scores. **Jouer ce scénario** lance une partie neuve au bon endroit de la Terre, avec les bons réglages.

En jeu, une **carte en haut à gauche** montre le jour (« Jour 12 sur 120 · encore 108 jours »), chaque objectif avec son progrès (✓ rempli, ○ à faire), les bonus et les règles. Boutons : **Histoire** (le texte d'ouverture) et **Abandonner** (deux clics). La carte se replie et disparaît en mode Créer.

- Le scénario est **gagné** dès que **tous les objectifs sont remplis en même temps** ; il est **perdu** à la date limite.
- L'**écran de fin** donne le détail du score, la médaille, la place au classement (on peut y changer son nom), puis : **Continuer à jouer** (la ville reste, sans les règles du scénario), **Rejouer**, **Menu principal**.
- La partie se sauvegarde comme une autre (section `scenario`) : on peut la reprendre plus tard, le scénario continue.

## Les scénarios

| Scénario | Lieu | Difficulté | Durée | Ce qu'il faut faire |
|---|---|---|---|---|
| Reconstruire après l'inondation | Sommières (Gard), au bord du Vidourle | Moyen | 120 j, départ le 15 septembre | 400 habitants, 2 bassins de rétention, pompiers, satisfaction 55. Crue rouge 6 jours après la fondation, aide de l'État (5 M€) au jour 12, nouvelle crue au jour 60. |
| Une ville sans voiture | Houten (Pays-Bas) | Difficile | 150 j | 600 habitants, 3 km de trottoirs / pistes / voies vertes, une ligne de tram ou de train, une école, satisfaction 60. Seules les rues de desserte sont permises, 600 m en tout (la rue en T offerte compte) ; pas d'accès route obligatoire. |
| Le grand hiver | Kiruna (Laponie) | Moyen | 120 j, départ le 20 octobre | 300 habitants, centre technique (déneigement), école, satisfaction 55. Premiers flocons au jour 20, 40 mineurs arrivent au jour 50. |
| Les caisses sont vides | Saint-Claude (Jura) | Difficile | 150 j | 3 M€ au départ, aucun emprunt possible. 500 habitants, aucune dette, 5 M€ dans la caisse. Vieille facture de 400 000 € au jour 40. |
| Course au bourg | Échallens (Vaud) | Facile | 90 j | Devenir un Bourg le plus vite possible (chaque jour d'avance rapporte). |
| Trois villes, un pays | Sélestat (Alsace) | Moyen | 200 j | Fonder 3 villes, 1 000 habitants en tout, toutes reliées. |

Les jours des événements marqués « après la fondation » comptent à partir de la première Maison de commune.

## Score et médailles

| | Points |
|---|---|
| Chaque objectif rempli | 1 000 |
| Chaque bonus rempli (à la fin) | 500 |
| Scénario réussi | 2 000 |
| Chaque jour d'avance sur la date limite (si réussi) | 25 |
| Chaque habitant | 1 |
| Chaque point de satisfaction | 20 |
| Dette | −1 par tranche de 10 000 € |
| Difficulté | total ×1 (facile), ×1,25 (moyen), ×1,5 (difficile) |

Médailles : **bronze** en réussissant, **argent** et **or** au-dessus des seuils de chaque scénario.

**Pas de classement** pour un abandon, une défaite, ou si des **réglages de l'Admin** (F10) ont changé en cours de scénario (argent illimité, coût des constructions, construction instantanée, rythme des chantiers, catastrophes, impôts, salaires, accès route…). Le scénario continue quand même ; la carte le signale.

## Classement

`Classement` garde les 10 meilleurs scores de chaque scénario dans `user://scenarios_classement.json` (nom, score, médaille, jours, habitants, date). Le nom vient du pseudo d'« Entre amis », sinon du nom de la session.

Prévu pour le **classement en ligne** : brancher `Classement.envoi_en_ligne` (appelé à chaque nouveau score) et `Classement.lecture_en_ligne` (lu par la fenêtre du menu). Sur Steam, un classement par scénario nommé `Classement.nom_steam(id)` (`scenario_crue`…), tri décroissant.

## Ajouter un scénario

Une entrée de plus dans `Scenarios.LISTE` (voir le commentaire en tête de `scenarios.gd`) : lieu, réglages (`preset` + n'importe quel champ de `ReglagesPartie`), contraintes (`routes`, `routes_max_m`, `interdits`, `sans_emprunt`), événements (`crue`, `subvention`, `facture`, `vague`, `message`), objectifs et bonus (`habitants`, `satisfaction`, `batiment`, `lignes`, `caisse`, `sans_dette`, `palier`, `voies`, `villes`, `relies`, `chomage_max`), médailles. Le test vérifie que les bâtiments, voies et réglages cités existent.

Branchements dans le reste du jeu : `ReglagesPartie.raison_blocage` (bâtiments interdits), `TransportSystem.evaluate` (voies), `BudgetCommunal.refus_emprunt` (emprunts), `terre_main._setup_scenario` et `ouvrir_bilan_scenario`.
