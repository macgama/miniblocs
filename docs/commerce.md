# Commerce entre villes et pays

Menu **Économie → Commerce** (touche **Maj + S**). Code : `scripts/commerce/`
(`commerce_mondial.gd` = `CommerceMondial`, `marche_types.gd` = `MarcheTypes`,
`commerce_panel.gd` = `CommercePanel`). Test : `tests/commerce_mondial_test.gd`.

## Le marché mondial

- Chaque marchandise a un **cours** qui bouge chaque jour autour de son prix de
  référence (`Ressources.MARCHANDISES`). Les marchandises d'une même **famille**
  bougent ensemble : énergie (la plus agitée), métaux, produits agricoles,
  alimentation, matériaux de construction, chimie et papier, produits manufacturés.
- Le cours reste entre ×0,35 et ×3,5 et revient doucement vers le prix de référence.
- **Exportations et importations** : au cours du jour (`Ressources.prix_export`,
  `Ressources.prix_import`).
- **Sur la carte** (entre entreprises, en rayon pour les habitants et les
  touristes) : le prix suit le cours **à moitié** (`Ressources.prix_interieur`).
- Onglet Marché : cours, variation sur 30 jours et petite courbe ; un clic montre
  la courbe sur 120 jours, les prix export, import et sur la carte, l'effet de la crise.
- Réglage Admin (F10, Événements) : marché **calme, normal ou agité**.

## Les crises économiques

| Crise | Effet au plus fort | Durée |
|---|---|---|
| Choc pétrolier | pétrole ×2,2, carburant ×1,8, gaz ×1,7, plastiques, chimie | 45-100 j |
| Krach boursier | produits manufacturés ×0,7, métaux, matériaux ; export moins payé ; 30 % de camions en moins aux frontières | 60-150 j |
| Sécheresse mondiale | produits agricoles ×1,6, alimentation ×1,25 | 40-90 j |
| Pénurie de puces | électronique ×1,9, voitures ×1,45 | 60-120 j |
| Boom de la construction | matériaux ×1,5, métaux ×1,25 | 50-110 j |
| Inflation galopante | tout ×1,25 | 90-180 j |
| Guerre commerciale | importations ×1,3, export ×0,9, frontières ×0,75 | 60-120 j |
| Récolte record | produits agricoles ×0,65 | 40-80 j |
| Ruée vers les métaux | cuivre, aluminium, bauxite, or ×1,5 à ×1,8 | 50-100 j |

- Une crise monte (15 % de sa durée), dure, puis redescend (20 %). Annonce et fin
  dans le fil d'actualité, avec une touche d'humour.
- Après une crise, 60 jours de répit ; ensuite une chance sur 150 par jour
  (× la fréquence des catastrophes du panneau Admin). Pas de crise les 45 premiers jours.
- Onglet Crises : effets du jour, conseil, crises passées.
- Réglage Admin : crises économiques oui ou non.

## Les villes partenaires (accords avec l'étranger)

- Six **vraies villes voisines** du lieu de la partie (index GeoNames des villes du
  monde, `Villes.voisines`) : quatre grandes villes jusqu'à 250 km et deux petites
  villes proches. Autour de Bâle : Mulhouse, Zurich, Fribourg-en-Brisgau,
  Stuttgart, Rheinfelden, Laufen.
- Selon leur taille, elles achètent et vendent des familles différentes (une grande
  ville achète de l'alimentation et vend des produits manufacturés, un bourg vend
  des produits agricoles…).
- Elles font des **offres** : t par jour d'une marchandise, à prix fixe, pendant 30,
  60, 90 ou 180 jours, valables 10 jours. Les offres d'achat portent souvent sur ce
  que tes entreprises produisent.
- **Accord d'exportation** (« … t'achète ») : prix supérieur au cours (8 à 20 %).
  Les camions des entreprises de la ville portent la marchandise à la frontière
  **avant tout le reste** (même si un commerce de la ville en voudrait). Il faut
  produire, des chauffeurs-livreurs et une porte d'export (route qui sort de la
  carte, dépôt, gare, port). Après 2 jours de grâce, ce qui manque chaque jour
  coûte **10 %** de sa valeur à la caisse de la ville, et la relation baisse.
- **Accord d'importation** (« … te vend ») : prix inférieur au cours, **fixe** (à
  l'abri des crises), et passage garanti même quand la frontière est pleine.
- **Relation** (0 à 100) : elle monte quand on honore ses accords, baisse quand on
  manque ou qu'on rompt (−15). Meilleure relation = meilleurs prix et plus d'offres ;
  sous 20, la ville ne propose plus rien. **Mission commerciale** : 25 000 € (× coût
  des constructions), relation +8 et deux offres tout de suite, une par semaine.
- **Rompre** un accord : 10 % de ce qui restait à échanger.

## Entre tes villes et tes pays

- **Accord entre deux villes** de la carte : la ville qui vend, celle qui achète,
  la marchandise, t par jour, prix (par défaut le prix du jour sur la carte), durée.
  La ville qui achète se fournit d'abord chez celle qui vend, au prix convenu ;
  ce qui manque est payé (10 %) par la ville qui vend à celle qui achète.
- **Libre-échange** entre deux de tes pays : plus de douane entre eux
  (`Pays.douane_entre`).
- Onglet Bilan : exportations, importations et douane du mois, commerce de chaque
  ville avec les autres et avec ses accords, commerce de chaque pays.

## Carte entre amis

- Le marché, les crises et les offres viennent de la graine de la partie : tous les
  jeux voient les mêmes cours.
- Les décisions (signer, proposer, accepter, refuser, rompre, mission commerciale,
  libre-échange) sont des **appels** (`Multijoueur.APPELS["commerce"]`) : le serveur
  vérifie que le joueur est maire de la ville (ou admin pour le libre-échange entre
  pays), les fait, puis tous les rejouent.
- Un accord avec la ville d'un autre joueur est une **proposition** : son maire
  l'accepte ou la refuse dans l'onglet Entre villes (10 jours pour répondre).

## Pour le code

- `Production.marche` : le système Commerce. Crochets dans la logistique :
  `accord_export` / `reserver` (camions de l'accord dans `_push_surplus`, champ
  `accord` de la mission), `vente_export`, `achat_import`, `import_garanti`,
  `vendeur_pour` (dans `_best_source`), `vente_entre`.
- `Ressources.cours_facteurs`, `facteur_export`, `facteur_import`,
  `facteur_capacite` (× de `Production.export_capacity`), remis à 1 par
  `Ressources.marche_neutre()`.
- Section de sauvegarde `commerce_mondial`. Réglages : `ReglagesPartie.crises_economiques`,
  `ReglagesPartie.volatilite_marche`.

## Suite possible

- Époques (à partir de 1800) : prix de référence et marchandises selon l'année.
- Accords avec les villes des autres joueurs sur la carte mondiale.
- Plan de relance du pays pendant une crise (subventions aux entreprises).
