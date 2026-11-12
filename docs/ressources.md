# Ressources naturelles et production

Étape 1, livrée le 2026-11-12. Le code est dans `scripts/economie/`, le test dans `tests/production_test.gd`.

## Ce que fait l'étape 1

- **Carte des ressources** : panneau Production (touche **P**), onglet Ressources. Un clic sur une ressource la dessine sur le relief autour de la caméra, sur environ 1,4 km de côté. Plus la couleur est franche, plus la ressource est riche. Survoler une case affiche ses ressources les plus riches dans la fiche du terrain.
- **14 ressources naturelles** : bois, terres cultivables, pâturages, poisson, pierre, sable, argile, fer, charbon, cuivre, or, bauxite, pétrole et gaz.
- **20 bâtiments de production** dans Construire → Production (catégorie nouvelle) :
  - extraction : exploitation forestière, ferme céréalière, élevage, port de pêche, carrière, sablière, carrière d'argile, mine (elle prend le meilleur minerai sous elle), puits de pétrole ou de gaz ;
  - transformation : scierie, moulin, boulangerie industrielle, abattoir, briqueterie, cimenterie, aciérie, fonderie de cuivre, raffinerie, menuiserie, usine de biens.
- **Règle de pose** : un site d'extraction est refusé là où sa ressource est trop pauvre. L'aide de pose affiche la richesse, les tonnes par jour prévues et la réserve.
- **Emplois** : la production suit la part des emplois pourvus. Il faut des habitants (logements) près des sites. 12 nouveaux métiers : bûcheron, carrier, mineur, foreur, marin pêcheur, sidérurgiste…
- **Stock commun, façon Anno** : tous les bâtiments desservis par une voie partagent le stock de la ville, 2 000 t par marchandise. Chaque entrepôt ajoute 20 000 t.
- **Chaînes** : bois → planches → meubles ; céréales → farine → pain ; bétail → viande ; minerai de fer + charbon → acier ; minerai de cuivre → cuivre ; acier + planches + cuivre → biens ; pétrole → carburant ; argile → briques ; pierre → ciment.
- **Ventes** : chaque jour, les habitants achètent pain, viande, poisson, meubles, biens et carburant (un plein par voiture), s'il y a au moins un commerce en ville.
- **Export** : le surplus part à 80 % du prix de gros, par les dépôts de marchandises, gares et ports (150 t par jour chacun), par les voies qui sortent de la carte, plus les tonnes que transportent tes lignes de fret. La ville garde d'abord 3 jours de besoins.
- **Caisse** : elle encaisse les ventes et l'export, et paie les salaires des employés de la production (charges comprises).
- **Épuisement** : les mines et les puits ont une réserve qui baisse. Le bois et le poisson s'appauvrissent si on les exploite fort, puis repoussent. Les sols, la pierre, le sable et l'argile ne s'épuisent pas.
- **Sauvegarde** : section `production` (stocks, sites, réserves, comptes).

## D'où viennent les ressources (lieu réel)

| Ressource | Source dans l'étape 1 | Licence |
|---|---|---|
| Bois, cultures, pâturages | ESA WorldCover 2021, déjà lu par le jeu | CC BY 4.0 (attribution affichée) |
| Pente, altitude, bathymétrie | tuiles Terrarium (AWS Open Data) | libre, attribution |
| Rivières, lacs, mer | WaterMap du jeu (relief, OSM si disponible) | ODbL pour OSM |
| Sable, argile, pierre | calculés : bords de rivière, plages, plaines basses, roche nue, pente | — |
| Fer, charbon, cuivre, or, bauxite, pétrole, gaz | `GisementsMonde.PROVINCES` : 106 grandes régions réelles (centre, rayon, richesse), plus de petits gisements locaux possibles partout | faits géographiques, aucune base recopiée |

Dans une province, les gisements sont des taches de quelques kilomètres, tirées d'un bruit calculé sur les vraies coordonnées. Tout le monde a donc les mêmes gisements au même endroit, en solo comme en carte mondiale.

## Données gratuites pour aller plus loin

Toutes ces données permettent l'usage commercial, donc la vente sur Steam :

- **USGS MRDS** (Mineral Resources Data System), environ 300 000 sites miniers dans le monde : domaine public.
- **USGS World Petroleum Assessment** (provinces pétrolières) : domaine public.
- **Global Energy Monitor** : Global Coal Mine Tracker et Global Oil and Gas Extraction Tracker, CC BY 4.0.
- **GLiM**, carte lithologique mondiale (calcaire, granite, sédiments) : CC BY.
- **SoilGrids 250 m** (ISRIC), carbone, argile et pH des sols : CC BY 4.0.
- **MapSPAM**, rendement de 42 cultures par maille de 10 km : CC BY 4.0.
- **WorldClim**, pluie et température : CC BY 4.0.
- **Global Wind Atlas** et **Global Solar Atlas** : CC BY 4.0.
- **NASA MODIS**, chlorophylle des océans (productivité de la pêche) : domaine public.
- **GEBCO**, bathymétrie mondiale : libre.

À éviter, car leur licence est non commerciale : FAO GAEZ v4, Global Fishing Watch, Sea Around Us.

Méthode prévue : comme pour `tools/build_biome_map.py`, un script `tools/` précalcule une grille mondiale compacte (par exemple 0,05°) pour chaque ressource, livrée avec le jeu. Le jeu y lit la probabilité d'un gisement, puis place les taches comme aujourd'hui.

## Choix de Gaël (2026-11-12)

1. Transport : stock commun à courte distance, et lignes de fret à longue distance. L'étape 1 fait le stock commun ; l'étape 2 fera circuler les tonnes sur les lignes de fret.
2. Épuisement : oui pour les mines, le pétrole et le gaz. Le bois et le poisson repoussent si on n'exploite pas trop : à plein régime, la ressource baisse et se stabilise vers 60 % ; laissée tranquille, elle revient à 100 % en quelques mois de jeu.
3. Clients : les habitants et l'export. L'export passe par les dépôts, gares et ports, et par les voies qui sortent de la carte : 200 t par jour pour une route, 800 t pour un rail, 1 200 t pour une voie d'eau qui arrive à moins de 300 m du bord.

## Étapes suivantes proposées

- Étape 2 : les marchandises voyagent vraiment. Chaque site a son stock, les camions, trains et bateaux de fret chargent et livrent, et la distance coûte.
- Les bâtiments consomment des matériaux à la construction (briques, ciment, planches, acier).
- Champs visibles autour des fermes, forêt qui recule sous l'exploitation et repousse.
- Énergie : centrales à charbon, au gaz, hydrauliques, éoliennes et solaires (Global Wind Atlas, Global Solar Atlas).
- Grilles mondiales précalculées à partir de USGS MRDS et Global Energy Monitor.

![Sites de production](apercu-production-sites.png)

![Carte du bois et panneau Production](apercu-production-carte-bois.png)
