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

## L'agriculture au fil des époques

Dans une partie qui commence dans le passé (année de départ, voir
`docs/epoques-1800.md`), chaque machine change de forme avec les années
(`scripts/agriculture/agri_epoques.gd`). Une machine du jeu est un **rôle** :
« moissonneuse » veut dire « ce qui récolte les céréales ».

| Rôle | 1800 | puis | puis | aujourd'hui |
|---|---|---|---|---|
| Tracteur | paire de chevaux de trait (mangent du foin) | 1920 tracteur à pétrole | 1950 tracteur diesel | 1990 tracteur moderne |
| Moisson | faux, faucille et fléau (à la main) | 1850 moissonneuse attelée et batteuse à vapeur | 1900 moissonneuse-lieuse, 1940 moissonneuse-batteuse tractée | 1960 automotrice |
| Labour | charrue à versoir attelée | 1880 brabant double | 1950 charrue portée | 1980 |
| Semis | à la volée, à la main | 1850 semoir en ligne attelé | 1950 semoir mécanique | 1985 |
| Traitement | aucun (rendement −15 %) | 1885 pulvérisateur à dos (bouillie bordelaise) | 1950 pulvérisateur porté | 1990 |
| Fenaison | faux, fourche et meules | 1850 faucheuse à cheval, 1880 presse fixe | 1945 ramasseuse-presse | 1975 balles rondes |
| Vendanges, cueillette, canne | à la main | | | 1960-1975 machines |

- Le travail **à la main** se fait à plusieurs : jusqu'à 8 employés de la ferme
  sur le même champ. Les chevaux ne brûlent pas de gazole mais mangent du foin
  (pris dans le stock de la ferme, sinon acheté).
- **Rendements d'époque** : vers 1800, le blé donne environ 1 t/ha (16 %
  d'aujourd'hui), 1,3 t/ha en 1900, 1,8 t/ha en 1950 ; la sélection et les
  engrais font le reste après 1950. Les bêtes donnent aussi moins (30 % du
  lait d'une vache actuelle en 1800).
- **Engrais minéraux** à partir de 1910 (Haber-Bosch) ; avant, seul le fumier
  nourrit les champs. L'usine d'engrais (1913) livre les fermes par camion.
- **Cultures datées** : betterave sucrière en 1812, tournesol en 1830, soja en
  1920. **Élevage** : pisciculture à partir de 1850.
- **Marchandises datées** : pas de plastique avant 1950, d'électronique avant
  1960, de carburant ni de voitures avant 1900, d'aluminium avant 1890… Les
  habitants n'en achètent pas, et une usine qui en utilise fait sans.

## Nouvelles cultures et nouveaux élevages

- **Cultures pérennes** (plantées une fois, récoltées chaque année, puis au
  repos jusqu'à la reprise) : vigne (raisin), verger (pommes, poires), agrumes,
  oliviers, houblon, caféiers, cacaoyers, théiers, canne à sucre ; et le tabac
  (annuel). Chacune a son climat.
- **Élevages** : canards, dindes, lapins, ruches (miel), bassins de truites,
  buffles d'eau, lamas et alpagas, rennes.
- **Fermes** (catégorie Production) : domaine viticole, verger, oliveraie,
  plantation tropicale, houblonnière, basse-cour, rucher, pisciculture, ranch
  de buffles, élevage andin, élevage de rennes.
- **Industries** : four à chaux, tuilerie, cave vinicole, distillerie,
  sucrerie de canne et rhumerie, chocolaterie, torréfaction, fromagerie
  d'alpage, conserverie, tannerie, manufacture de tabac, manufacture
  horlogère, chantier naval, usine d'engrais, usine de recyclage des
  matériaux, usine de batteries.

## Pour les développeurs

| Fichier | Rôle |
|---|---|
| `scripts/agriculture/agri_donnees.gd` | tables : cultures, travaux, machines, espèces, fermes |
| `scripts/agriculture/agri_epoques.gd` | versions d'époque des machines, années des cultures et des élevages |
| `scripts/agriculture/agriculture.gd` | simulation (champs, travaux heure par heure, bêtes, sauvegarde) |
| `scripts/agriculture/repas.gd` | repas et faim des foyers |
| `scripts/agriculture/agri_visuels.gd` + `champ.gdshader` | sol des champs, plantes, bottes, machines, bêtes |
| `scripts/agriculture/agri_panel.gd` | panneau Maj+F |

Ajouter une culture, une machine ou une espèce dans `agri_donnees.gd` suffit.
La production délègue les fermes via `Production.agri` (outputs, needs, cap,
status). Sauvegarde : section `agriculture`. Tests :
`tests/agriculture_test.gd`, `tests/agri_epoques_test.gd` ; captures :
`tests/agriculture_vitrine.gd`.
