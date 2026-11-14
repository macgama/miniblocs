# Modèles de l'atelier : de vrais bâtiments du jeu

Un bâtiment construit dans l'Atelier (murs et étages, blocs, intérieur) peut
devenir un bâtiment du catalogue, qui se pose et se gère comme les autres.

## Pas à pas

1. **Construire** dans l'Atelier (mode Créer, Tab) : Murs et étages (2), Blocs (3), Intérieur (4).
2. **Enregistrer** : clic sur le bâtiment, « Aménager » (ou viser le bâtiment dans l'onglet Intérieur),
   puis « Nom du modèle » et **Enregistrer dans la banque**.
3. **Fonction** : Banque (6) → bouton **Fonction** sur la carte du modèle. On choisit une catégorie,
   on cherche (« centrale », « stade », « piscine »…) et on clique. Par défaut, la fonction suit l'usage
   choisi dans l'onglet Intérieur (logement → Maison, école → École, boutique → Supérette…).
4. **Poser** : depuis la Banque (« Poser »), ou en partie depuis le catalogue **B → Mes modèles**
   (le modèle est aussi rangé dans la catégorie de sa fonction). Prix, **R** pour tourner, accès à une
   route, terrassement et chantier comme pour les autres bâtiments.

Les créations en blocs (Mes créations) ont le même bouton **Fonction** ; « Aucune fonction » les
remet en simple décor.

## Comment ça marche

- `scripts/atelier/modeles_jeu.gd` (ModelesJeu) : chaque modèle en murs fins de la banque entre au
  catalogue sous l'id `mdl_<id du modèle>`. L'entrée recopie toutes les données de jeu de sa fonction
  (emplois, logements, `reseau`, `prod`, `parc`, `stade`…), sauf ce qui décrit le modèle 3D, et ajoute
  `base` (l'id de la fonction) et `modele` (l'id du modèle).
- `BuildingCatalog.base_of(id)` rend l'id de la fonction ; les quelques systèmes qui reconnaissent un
  bâtiment par son id (stade de foot, château d'eau, entrepôt, fermes, parc, funéraire, déchets,
  objectifs) passent par elle. `Metiers.keys_of` ajoute `base` à ses clés.
- Capacités : emplois, logements, visiteurs et `reseau.cap` sont multipliés par le rapport des surfaces
  (modèle / référence), borné de 0,25 à 4.
- Prix : murs, planchers, escaliers, blocs et meubles × 1,3 (main-d'œuvre), et pas moins que le prix
  de la référence × le même rapport.
- Maillage : les murs, planchers et escaliers sont cuits par un éditeur de murs hors de la scène
  (`PlanEditor.emit_storey`), les blocs du toit par `BlocFormes.emit`, puis centrés (façade vers −Z).
  Les modèles enregistrés avant cette version n'avaient pas la bonne hauteur des blocs : leur toit est
  reposé sur le haut des murs. Les nouveaux gardent `dy2` (hauteur des blocs en demi-mètres).
- Sauvegarde : la section `modeles_jeu` copie les modèles utilisés par la partie ; une partie chargée
  sur un autre ordinateur les retrouve. Un modèle retiré de la banque reste connu (caché) pour les
  bâtiments déjà posés.
- Test : `tests/modeles_jeu_test.gd` ; vitrine : `tests/modeles_jeu_vitrine.gd -- --vue rue|banque`.

## Limites

- Un modèle posé comme bâtiment n'est pas visitable (le maillage est cuit, sans meubles). « Poser
  meublé » (Banque) pose les vrais murs et meubles, sans rotation ni chantier.
- Pas de pièces mobiles : un grand-huit fait maison ne bouge pas.
- Le zonage ne fait pas encore pousser les modèles.
