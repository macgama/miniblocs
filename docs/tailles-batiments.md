# Choisir la taille d'un bâtiment

Quand on pose un bâtiment du catalogue (B, ou un menu Loisirs, Club, Tourisme…),
sa taille se choisit **au geste**, directement sur la carte :

1. **Tracer l'emprise** : bouton gauche enfoncé, glisser au sol. Le bâtiment
   suit le rectangle tracé, case par case (1 case = 1 m), à partir de la case
   de départ. Il reste dans les bornes du type (une maison ne dépasse pas
   16 m de large). La porte se tourne d'office vers la voie la plus proche ;
   R la tourne à la main.
2. **Monter les niveaux** : relâcher le bouton, puis monter la souris (un
   niveau tous les 26 pixels) ou tourner la molette. Le toit ne compte pas.
3. **Poser** : un clic. Clic droit ou Échap : annuler le geste (l'outil reste).

Pendant le geste, une étiquette au-dessus du fantôme donne la taille, les
niveaux et le prix (ou « payé par un promoteur » pour un bâtiment privé). Un
simple clic sans glisser pose à la taille en cours, comme avant.

La carte **Taille** en bas de l'écran rappelle le geste et résume la taille
choisie. Son bouton **Menu** la déplie (gardé pour la session) en secours, en
deux étapes :

1. **Emprise au sol** : quatre vignettes dessinées en plan à la même échelle
   (Petite, Normale, Grande, Très grande), puis la largeur et la profondeur au
   mètre près avec − et +. Le trait jaune du dessin est la façade (côté rue).
2. **Hauteur** : silhouettes de 1 à N niveaux, à la même échelle, avec un
   bonhomme pour se repérer, puis − et +.

Le fantôme change tout de suite. La ligne du bas donne logements ou emplois,
prix (payé par la ville ou par un promoteur), durée du chantier.

## Ce qui suit la taille

La surface de plancher (largeur × profondeur × niveaux) comparée au modèle du
catalogue donne un rapport ; tout suit ce rapport :

- logements, emplois, visiteurs, lits, places (au moins 1 s'il y en avait) ;
- puissance d'une centrale, débit d'une station (réseaux) ;
- prix : 20 % fixes (fondations, raccordements, études), 80 % au mètre carré,
  +1,5 % par niveau au-delà de 8 (ascenseurs, structure) ;
- durée du chantier et matériaux : Chantiers les calcule sur la surface de
  plancher et la hauteur du modèle, et l'époque garde ses matériaux ;
- consommation d'eau, d'électricité, déchets : via les emplois et logements ;
- l'agrandissement (3 niveaux, PR #172) et « Modifier la façade » (PR #249)
  partent de la taille choisie.

## Bornes réalistes

- Emprise : de 60 % à 160 % de celle du catalogue sur chaque côté.
- Niveaux, selon la forme : maison 1 à 4, villa 1 à 3, petit immeuble 2 à 12,
  tour 8 à 45, bureaux 2 à 30, école 1 à 4, hôpital 2 à 14, commerces 1 à 4,
  usines et entrepôts 1 à 3…
- Selon l'époque de la partie : 6 niveaux au plus avant 1860, 8 avant 1890,
  16 avant 1920, 30 avant 1950, 50 avant 1975.
- Pas de taille à choisir : terrains de foot, tennis et basket (mesures
  officielles), monuments et patrimoine, modèles de l'Atelier et créations,
  mobilier urbain (bancs, lampadaires, arbres). Parcs, places, enclos et
  ouvrages de réseau : emprise seulement.

## Comment c'est rangé

- `scripts/batiments/tailles_batiments.gd` (TaillesBatiments) : un bâtiment à
  une autre taille a son propre id, `<type>@<largeur>x<profondeur>x<niveaux>`
  (ex. `maison@8x10x1`). `BuildingCatalog.get_type()` fabrique son entrée à la
  demande (champ `base` pour `BuildingCatalog.base_of()`, `taille_de`, `etages`).
  L'id voyage tel quel dans la sauvegarde et en carte entre amis : chaque
  machine refait la même entrée, rien à ajouter au format.
- Modèle : les bâtiments dont la forme se règle (styles du monde, modèles
  classiques) sont redessinés à la bonne taille avec leurs étages ; les autres
  sont étirés au sol et reçoivent ou perdent des étages (étage recopié ou
  retiré au-dessus du rez-de-chaussée).
- Geste : `BuildingSystem` (geste "trace" puis "hauteur", `_trace_vers`,
  `_hauteur_souris`, `poser_geste`, `annuler_geste`, `PX_NIVEAU`). La pose
  passe par le même chemin que le clic (multijoueur, mode plan, historique).
- `scripts/batiments/taille_panel.gd` (TaillePanel) : la carte, qui suit
  l'outil de pose ; `scripts/batiments/dessin_taille.gd` : les dessins.
- Test : `tests/tailles_test.gd`.

## Tester dans Godot 4.7

1. Ouvrir le projet, lancer la scène principale (F5), commencer une partie.
2. B → Logement → Maison.
3. Bouton gauche enfoncé, glisser au sol sur une douzaine de cases, relâcher,
   monter la souris (ou molette) : les niveaux changent, l'étiquette aussi.
   Clic pour poser ; clic droit pour annuler.
4. Bouton « Menu » de la carte Taille : vignettes et − / + en secours.
5. Cliquer la maison posée : la fiche affiche « Taille choisie ».
6. Sauvegarder, recharger : la maison garde sa taille.

Test automatique :
`godot --path . --script res://tests/tailles_test.gd` (doit finir par « TEST OK »).
