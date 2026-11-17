# Catalogue étoffé : toutes les régions à toutes les époques

Demande de Gaël (17 novembre 2026) : beaucoup plus d'objets dans tous les thèmes et toutes les époques, de
1800 à aujourd'hui, styles du monde entier. Le travail se fait par lots, chacun dans sa PR.

## Où étaient les trous

Avant ce travail, le catalogue (Maj+F1) comptait 2 100 objets, mais :

- hors d'Europe, presque aucun bâtiment après 1850 (Asie du Sud : 0 entre 1850 et aujourd'hui ; Afrique : 1 entre
  1850 et 1950 ; Océanie : 0 entre 1900 et 1990) ;
- les véhicules étaient presque tous européens ou « monde » (Afrique 4, Asie du Sud 4, Moyen-Orient 1) ;
- presque aucun meuble ni décor après 1990, aucune attraction entre 1900 et 1950, 12 toits, 27 ouvertures.

## Lot 1 : bâtiments et véhicules du monde entier

**50 nouveaux styles dans la bible des styles** (`scripts/catalogue/styles.gd`, années dans `Epoques.STYLE_ANNEES`).
Chaque style décline 5 à 11 archétypes (maison, immeuble, boutique, école, gare, lieu de culte, palais…) avec ses noms
à lui : environ 470 bâtiments de plus. Ils poussent aussi dans le zonage des parties historiques de leur région.

| Région | Styles ajoutés (année) |
|---|---|
| Europe | Géorgien et Regency (toujours), Villas balnéaires (1860), Art nouveau (1893), Bauhaus (1925), Reconstruction (1945), Nordique contemporain (2000) |
| Méditerranée | Italie du XIXe (1850), Modernisme catalan (1888), Rationalisme (1928), Méditerranée moderne (1955), Riviera contemporaine (1995) |
| Moyen-Orient et Maghreb | Maison levantine (1840), Néo-mauresque (1890), Moderne d'Orient (1935), Golfe des années pétrole (1968) |
| Afrique | Cap hollandais et Voûtes nubiennes (toujours), Colonial tropical (1870), Néo-soudanais (1907), Modernisme d'Asmara (1935), Modernisme tropical (1957), Afrique contemporaine (2000) |
| Asie de l'Est | Shanghai des concessions (1860), Japon Meiji-Taishō (1872), Art déco de Shanghai (1925), Chine populaire (1952), Japon moderne (1958), Asie de l'Est contemporaine (1998) |
| Asie du Sud et du Sud-Est | Inde du Sud et Birmanie-Siam (toujours), Compartiments sino-malais (1840), Indo-sarrasin (1870), Art déco de Bombay (1930), Modernisme indien (1951), Asie tropicale contemporaine (1995) |
| Amériques | Créole des Antilles (toujours), Néo-hispanique (1890), Bungalow américain (1905), Streamline et Googie (1933), Modernisme brésilien (1940), Amérique latine contemporaine (2000) |
| Océanie | Mélanésien (toujours), Fédération australienne (1890), Bungalow océanien (1915), Art déco du Pacifique (1931), Australie d'après-guerre (1950), Pacifique contemporain (1995) |
| Monde | High-tech (1977), Postmoderne (1978), Courbes paramétriques (2005), Bois et végétal (2010) |

Deux nouveaux lieux de culte modelés : le **temple à gopuram** d'Inde du Sud et la **pagode dorée** birmane (stupa).

**79 nouveaux véhicules** (`scripts/transport/vehicle_catalog.gd`) : voitures (première voiture de série 1908, taxi
jaune indien, taxi vert de Mexico, limousine d'État chinoise, taxi-brousse, ute australien, robotaxi…), camions (camion de
brousse peint, mini-camion japonais, train routier australien…), bus (car rapide de Dakar, mammy wagon, bus d'État
indien, car de l'outback…), deux et trois roues (bicyclette chinoise, auto-rickshaw, vélo en libre-service…), attelages
du XIXe hors d'Europe (tonga, chariot à bœufs du Cap, araba, calèche du Caire…), tramways (Hong Kong 1912, Calcutta 1902,
Melbourne 1923…), trains (vapeur indienne, locomotive articulée d'Afrique, train des Andes, grande vitesse chinoise…),
bateaux (vapeur à roue arrière, pirogue motorisée, bateau à longue queue, bateau-dragon, waka…) et avions (avion de brousse,
quadrimoteur des années 50, jet régional).

Planches de vérification : `tests/catalogue_planche.gd` (voir l'en-tête du script), captures dans
`captures/catalogue-etoffe/` des fichiers du projet.

## Lots suivants

- Lot 2 : meubles et décors modernes (après 1990) et d'époque.
- Lot 3 : matériaux, toits, portes et fenêtres, attractions de 1900-1950, voies et stations.
