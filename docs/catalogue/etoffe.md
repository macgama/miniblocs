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

## Lot 2 : meubles et décors de chaque époque (2026-11-17)

**38 nouveaux types de meubles** (`scripts/interieurs/meubles.gd`, modèles dans `meubles_modeles_plus.gd`), déclinés
dans chaque style de mobilier de leur époque : **351 modèles de plus, 2 778 en tout**.

| Époque | Meubles ajoutés (année) |
|---|---|
| Avant 1900 | Rouet, métier à tisser, secrétaire à abattant, méridienne, poêle en faïence (toujours), glacière en bois (1850), lessiveuse (1850), machine à coudre (1851), lampe à pétrole (1860), téléphone mural (1880), phonographe (1895) |
| 1900-1950 | Lit escamotable (1916), fauteuil club (1920), poste de TSF (1922), juke-box (1940), flipper (1947) |
| 1950-1990 | Baby-foot, téléviseur à tube, lave-linge (1950), fauteuil coque (1958), sèche-linge (1960), lampe à lave (1963), chaîne hi-fi, vélo d'appartement (1970), micro-ondes (1975), borne d'arcade (1978), ordinateur personnel (1981), minitel (1982) |
| Après 1990 | Canapé d'angle, tapis de course, cave à vin (1990), home cinéma (1995), îlot à induction (2000), robot aspirateur (2002), écran plat, poêle à granulés (2005), bureau assis-debout, imprimante 3D (2012), enceinte connectée (2014), fauteuil de joueur (2015) |
| Demain | Robot domestique (2035), hologramme (2040) |

**51 nouveaux décors** (touche G), modelés dans Blender (`tools/blender/decors/epoques.py`) :

| Époque | Décors ajoutés (année) |
|---|---|
| XIXe siècle | Bec de gaz (1830), lavoir couvert (1830), vespasienne (1834), kiosque à musique (1850), poteau télégraphique (1850), kiosque à journaux (1857), orgue de Barbarie, cireur de chaussures (1880), chariot à bagages de gare (1880), avertisseur d'incendie (1890) |
| 1900-1950 | Entrée de métro Art nouveau (1900), mur de réclame (1900), yatai japonais (1900), pompe à essence à globe (1920), borne routière (1920), cabine d'appel de police (1929), sirène d'alerte (1938) |
| 1980-2000 | Sanisette (1981), module de skatepark (1990), caméras de surveillance (1995), abribus vitré (2000), conteneurs enterrés (2000), jardin partagé (2000) |
| Après 2000 | Radar (2003), panneaux solaires (2005), agrès de fitness (2005), vélos en libre-service (2007), borne de recharge (2010), poubelle solaire (2010), boîte à livres (2010), hôtel à insectes (2010), lampadaire solaire (2012), totem d'information (2012), ombrière de recharge, consigne à colis, atelier vélo, composteur, banc connecté (2015), trottinettes (2018), mât 5G (2019) |
| Demain | Borne de livraison par drones (2030) |
| Du monde (de tout temps) | Torii, lanternes de papier, chadouf, drapeaux de prière, mur mani, totem, tandoor, four à pain, pompe à bras, chasse-roue |

Dans une partie qui commence tôt, les décors posés tout seuls prennent leur équivalent d'époque (`DECORS_ANCIENS`) :
la sanisette devient vespasienne, l'abribus vitré redevient abribus, la borne de recharge une pompe à essence, etc.

La planche sait aussi montrer les décors et les meubles : `--decors bec_gaz,torii` ou `--meubles victorien/phonographe`.

## Lots suivants

- Lot 3 : matériaux, toits, portes et fenêtres, attractions de 1900-1950, voies et stations.
