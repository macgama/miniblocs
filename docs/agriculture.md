# Agriculture et nourriture

Les fermes produisent la nourriture que les habitants mangent chaque jour.
Le système s'inspire des jeux de gestion agricole (champs, saisons, machines,
bêtes) sans en copier aucun.

## Ouvrir le panneau

**Maj+F** (ou le bouton **Agriculture** de la barre du bas) ouvre le panneau,
avec cinq onglets :

| Onglet | Contenu |
|---|---|
| Fermes | la ferme choisie : surface, bras, machines, bêtes, journal des travaux. Bouton **Préparer la ferme** : trace 4 champs autour et choisit les cultures adaptées |
| Champs | liste des champs : culture, état (friche, labouré, pousse, mûr, chaume), avancement, rendement attendu. **Tracer** un champ (glisser un rectangle, Échap pour finir), **Supprimer**, changer de culture |
| Bêtes | vaches, bovins à viande, porcs, poules, moutons, chèvres, chevaux : achat, vente, places libres, ce qu'elles mangent et donnent |
| Machines | tracteur, charrue, semoir, planteuse, épandeur, pulvérisateur, moissonneuse, arracheuse, faucheuse, presse, remorque : achat, vente, révision, usure |
| Repas | ce que la ville mange, ce qui manque, les foyers qui ont faim |

## Une ferme, c'est quoi ?

Toutes les fermes du catalogue (Construire → Production : céréales, légumes,
betteraves, lin, lait, élevage) et les fermes de la bible (étable moderne,
bergerie, porcherie, poulailler, haras, ferme à cour carrée…) sont gérées par
l'agriculture. Les champs se tracent librement dans un rayon de 2,5 km autour
de la ferme, entre 400 m² et 100 ha, hors routes, bâtiments et eau. Les arbres
ne poussent pas dans les champs.

## Les saisons et les travaux

- 14 cultures : blé, orge, maïs, colza, tournesol, soja, betterave, pomme de
  terre, légumes, riz, lin, coton, prairie de fauche, pâture.
- Chaque culture se sème aux vrais mois de l'année (décalés de 6 mois dans
  l'hémisphère sud) et seulement dans les climats qui lui conviennent. En climat
  tropical, certaines se sèment toute l'année.
- Cycle d'un champ : labour → semis → engrais → traitement → récolte →
  pressage de la paille → chaume → nouveau labour.
- Les ouvriers de la ferme font les travaux pendant leurs heures de travail,
  avec des machines visibles qui avancent en bandes dans le champ. Pas de
  semis, de traitement ni de récolte sous la pluie.
- Sans machine achetée, la ferme loue celle qu'il faut à la journée. Les
  machines consomment du gazole, s'usent et peuvent tomber en panne ; une
  révision les remet à neuf. Une concession agricole dans la ville fait 10 %
  de remise.

## Le rendement

Il dépend de la fertilité du sol (carte des ressources), de l'engrais (le
fumier des bêtes d'abord, sinon de l'engrais chimique ou acheté), du
traitement, de la rotation (deux fois la même culture : −15 % ; une bonne
rotation : +8 %), de la météo (grêle) et du retard de récolte (1 % de perte
par jour après 20 jours).

## Les bêtes

Elles mangent l'herbe des pâtures, puis du foin, de la paille et des céréales
de la ferme ou livrés par camion. Elles donnent du lait, de la viande, des
œufs, de la laine et du fumier. Il faut des éleveurs (palefreniers pour les
chevaux). Sans nourriture, elles maigrissent puis meurent. Les fermes avec
beaucoup de bêtes ou d'azote polluent l'eau et sentent (groupe
`pollution_sources`).

## Les repas des habitants

Chaque jour, les foyers font leurs courses dans les commerces (supérette,
supermarché, marché…). La chaîne : champs → silo coopérative, moulin,
laiterie, sucrerie, huilerie, usine agroalimentaire → commerces → foyers.

Quand un foyer n'a pas de quoi manger :
- sa santé et sa satisfaction baissent ;
- après 10 jours, il peut déménager ;
- en mode « mortelle » (Admin, F10 : « Faim quand les magasins sont vides »),
  les habitants peuvent mourir de malnutrition après 21 jours.
  Le réglage « aucune » coupe la faim.

Un foyer sans aucun commerce alimentaire à portée fait ses courses hors de la
carte : pas de faim, mais il est moins satisfait.

## Nouveaux bâtiments

Concession agricole, silo coopérative (entrepôt de grains), huilerie
(oléagineux → huile), filature (laine → fibres). Nouvelles marchandises :
oléagineux, foin, paille, fumier, laine, œufs, huile.

## Pour les développeurs

| Fichier | Rôle |
|---|---|
| `scripts/agriculture/agri_donnees.gd` | tables : cultures, travaux, machines, espèces, fermes |
| `scripts/agriculture/agriculture.gd` | simulation (champs, travaux heure par heure, bêtes, sauvegarde) |
| `scripts/agriculture/repas.gd` | repas et faim des foyers |
| `scripts/agriculture/agri_visuels.gd` + `champ.gdshader` | sol des champs, plantes, bottes, machines, bêtes |
| `scripts/agriculture/agri_panel.gd` | panneau Maj+F |

Ajouter une culture, une machine ou une espèce dans `agri_donnees.gd` suffit.
La production délègue les fermes via `Production.agri` (outputs, needs, cap,
status). Sauvegarde : section `agriculture`. Tests :
`tests/agriculture_test.gd` ; captures : `tests/agriculture_vitrine.gd`.
