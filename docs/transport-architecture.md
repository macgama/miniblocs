# Transports et déplacements

Objectif : que le joueur puisse construire **tout ce qui sert à se déplacer** (route, rail, chemins piétons et vélos, voies d'eau, air) sur le vrai relief du mode Terre, puis le faire vivre avec des véhicules, des lignes et, plus tard, une économie.

## Principe : un seul réseau pour tous les modes

Tous les modes partagent le même **graphe** (`scripts/transport/transport_network.gd`) :

| Élément | Contenu |
| --- | --- |
| **Nœud** | Position 3D + mode (route, rail…). Carrefour, extrémité, et plus tard gare, arrêt, port, aéroport. |
| **Tronçon** | Relie deux nœuds du même mode. Garde son tracé échantillonné tous les ~2 m : position 3D et structure de chaque point (sol, pont, tunnel, eau). |
| **Classe de voie** | `scripts/transport/transport_types.gd` : gabarit réglementaire (voies, largeur de voie, trottoirs, accotements, BAU, terre-plein, entraxe), pente maximale, rayon minimal, vitesse, seuils pont / tunnel. Chaque tronçon garde sa classe et ses réglages (`w`). |

Le graphe se sauvegarde en JSON avec les cases du terrain (`user://terre_save.json`, clé `transport`). Comme pour le terrain, seul ce que le joueur a construit est stocké : c'est ce qu'il faudra synchroniser en multijoueur.

## Normes appliquées (choix de Gaël : France)

| Classe | Gabarit | Vitesse | Rayon mini | Pente maxi | Référence |
| --- | --- | --- | --- | --- | --- |
| Rue de desserte | 2 × 1 voie de 2,75 à 3,25 m, trottoirs 1,50 m | 30 km/h | 15 m | 12 % | CEREMA (voirie urbaine, accessibilité 1,40 m mini) |
| Avenue urbaine | 2 × 1 à 3 voies de 3,00 à 3,50 m, terre-plein 2 m dès 2 voies, trottoirs 2,00 m | 50 km/h | 40 m | 8 % | CEREMA |
| Route départementale | 2 × 1 voie de 3,00 à 3,50 m, accotements 1,75 m | 80 km/h | 240 m | 7 % | Guide ARP (Sétra) |
| Voie express | 2 × 2 ou 3 voies de 3,50 m, BAU 2,50 m, TPC 2,60 m | 110 km/h | 400 m | 6 % | ICTAVRU |
| Autoroute | 2 × 2 à 4 voies de 3,50 m, BAU 3,00 m, TPC 3,00 m | 130 km/h | 665 m | 5 % | ICTAAL (catégorie L1) |
| Tramway | 1 ou 2 voies, entraxe 3,00 m | 50 km/h | 25 m | 7 % | STRMTG / CEREMA |
| Ligne classique | 1 ou 2 voies, entraxe 4,20 m | 120 km/h | 600 m | 25 ‰ | SNCF Réseau |
| Ligne à grande vitesse | 2 voies, entraxe 4,50 m | 300 km/h | 4 000 m | 35 ‰ | SNCF Réseau |
| Chemin piéton | 1,40 à 4,00 m | — | 2 m | 12 % | Accessibilité (1,40 m mini) |
| Piste cyclable bidirectionnelle | 2,50 à 3,00 m | — | 10 m | 6 % | CEREMA |
| Voie verte | 3,00 à 5,00 m | — | 10 m | 6 % | CEREMA |

Les valeurs sont des repères de conception simplifiés pour le jeu. Elles sont toutes dans le tableau `CLASSES`, ce qui permettra d'ajouter d'autres pays.

## Pose sur le relief

`scripts/transport/route_planner.gd`, pour chaque tronçon tracé :

1. Échantillonne le sol réel tous les 2 m entre les deux points.
2. Lisse le profil (rayon 4 m pour un chemin, 14 m pour une route, 40 m pour le rail).
3. Applique la **pente maximale** de la classe. Si la différence d'altitude entre les deux bouts est impossible à tenir, le tracé est refusé avec la raison.
4. Vérifie le **rayon de courbure** (tracé courbe = courbe de Bézier rééchantillonnée tous les 2 m).
4. Choisit la structure de chaque point :
   - **au sol** si l'écart avec le terrain est faible : le jeu fait un **remblai ou un déblai** (les cases sous la voie prennent la hauteur de la chaussée) bordé de **talus** à 1 pour 1,5 jusqu'au terrain naturel ;
   - **pont** si la voie passe à plus de 4 m au-dessus du sol, ou au-dessus de la mer (tablier à 3 m minimum) ;
   - **tunnel** si elle passe à plus de 6 m sous le sol.
5. Les voies navigables restent sur la mer, au niveau 0 m.

## Carrefours et raccords

- Cliquer près d'un nœud existant du même mode s'y raccroche.
- Cliquer au milieu d'une voie la coupe et crée un **carrefour en T**.
- Une nouvelle voie qui en croise une autre **du même mode et à la même hauteur** (moins de 1,5 m d'écart) crée un **carrefour** automatiquement. Avec 4,5 m ou plus d'écart (pont, tunnel), elles se croisent sans se relier ; entre les deux, le tracé est refusé. Route et rail (ou chemin) se croisent par un passage à niveau.
- **Pas de superposition** : chaque voie est rognée à l'approche d'un carrefour, d'une longueur qui dépend des largeurs et de l'angle entre les voies, et un plateau (enveloppe convexe des bords) relie les chaussées. Une voie qui en recouvre une autre ailleurs qu'à un raccord ou un croisement est refusée.

## Catalogue de véhicules

`scripts/transport/vehicle_catalog.gd` (VehicleCatalog), même principe que BuildingCatalog : `CATEGORIES`, `TYPES` (name, cat, mode, era, region, year, L, W, H, kmh, places, desc, shape et ses réglages, consist pour les voitures attelées), `build_mesh(id, paint)`. Les époques et régions sont celles de `Styles` (la bible). `for_track(classe, era, region)` donne les modèles qui peuvent rouler sur une classe de voie. Les formes sont dans `vehicle_mesh.gd` (VehicleMesh, qui étend BlocMesh).

## Stations et lignes

`scripts/transport/station_system.gd` (StationSystem, enfant de TransportSystem). Une station du réseau est un **nœud du graphe** (la voie est coupée à cet endroit) ; une station aérienne est posée seule (centre, direction de la piste). Les emprises sont des rectangles dans le repère de la station (`occupies(case)`), le terrain sous une piste est aplani. Une ligne = `{kind, stops, model, count, color}` ; ses véhicules sont dans Traffic (`add_line_vehicle`, `add_air_vehicle`) : navette d'une station à l'autre (A*), arrêt de 12 s. Les avions suivent `flight_path()` : roulage, décollage, croisière à 260 m, approche dans l'axe, atterrissage. Sauvegarde dans la clé `transport.stations`.

Choix simples pour l'instant (questions 1 et 2 toujours ouvertes) : pas de voyageurs simulés, pas d'horaires, navette aller-retour.

## Véhicules (étape 1)

`scripts/transport/traffic.gd` : voitures, trains (locomotive + 2 voitures), piétons, cyclistes et bateaux. Chacun choisit une destination au hasard dans son réseau et y va par le plus court chemin (A*), en roulant à droite. Le nombre de véhicules suit la longueur du réseau (1 voiture tous les 45 m de route, etc.). Pas encore de collisions, de feux, ni de lignes.

## Feuille de route proposée

| Étape | Contenu |
| --- | --- |
| **1. Fait** | Graphe commun, route / rail / chemin / voie d'eau sur le vrai relief, ponts, tunnels, terrassement, carrefours, véhicules d'ambiance, sauvegarde. |
| **2. Fait** | Classes réglementaires (largeurs, rayons, pentes), courbes, plateaux de carrefour, refus des chevauchements, talus. |
| **Catalogue. Fait** | 133 véhicules de toutes époques et régions, branchés sur la circulation avec filtre époque / région. |
| **3 et 4. Fait (version simple)** | Stations : arrêts de bus et de tram, gares, ports, héliports, aérodromes, aéroports. Lignes : stations dans l'ordre, véhicule du catalogue, nombre de véhicules, navette avec arrêts ; avions qui décollent et atterrissent. |
| 2 bis | Ponts et tunnels forcés à la main (échangeurs, sauts-de-mouton), bretelles, ronds-points, aiguillages dessinés. |
| 3 | **Stations** : arrêts de bus, gares, ports, héliports et **aéroports** (pistes, couloirs aériens entre aéroports, avions). |
| 4 | **Lignes** : le joueur relie des stations, choisit les véhicules et la fréquence. |
| 5 | **Simulation** : trajets des habitants (domicile → travail → commerces), embouteillages, files, feux, priorité. |
| 6 | **Économie** : coûts de construction (plus chers pour les ponts et tunnels), entretien, billets. |
| 7 | **Multijoueur** : synchroniser les tronçons construits comme les cases modifiées. |

## Questions ouvertes (pour Gaël)

1. Simulation : véhicules d'ambiance ou vrais trajets des habitants ?
2. Lignes : gestion détaillée (à la Transport Fever) ou simple (deux gares = une navette) ?
3. Argent : coûts dès maintenant ou bac à sable gratuit ?
4. Tracé : angles libres et courbes, ou routes alignées sur les cases ?

## Carrefours et conduite

`JunctionControl` (scripts/transport/junction_control.gd) donne à chaque nœud routier de degré 3 ou plus un régime (`feux`, `stop`, `cedez`, `droite`), choisi daprès
## Giratoires

`TransportSystem.make_roundabout(nid)` coupe chaque branche à un rayon r du carrefour, supprime le centre et relie les nouveaux nœuds par des arcs de classe `giratoire` (à sens unique de `a` vers `b`, sens inverse des aiguilles d'une montre vu du dessus). `find_route` ne prend un tronçon à sens unique que dans son sens, et `lane_offsets` répartit les voies d'un sens unique sur toute la chaussée. Les nœuds d'entrée prennent le régime `giratoire` : l'anneau est prioritaire et les branches cèdent le passage. Les îlots centraux sont gardés dans `roundabouts` (sauvegardés sous la clé `giratoires`).

## Parkings

Un parking est une station de type `parking` (nœud du réseau routier, emprise à droite de la route). `StationSystem._sync_parkings()` donne à `Traffic.parkings` la position de chaque place (`Transform3D`) et leur occupation. Un véhicule ambiant (voiture, utilitaire, deux-roues) a 35 % de chances, à chaque nouvelle destination, de viser une place libre : la place est réservée, il roule jusqu'au nœud du parking, se gare (`parked`, hors des files) puis repart quand la voie est libre.

## Fret

Une ligne a un drapeau `fret` (toujours vrai pour les lignes de camions entre dépôts, au choix pour les trains et les bateaux). `StationSystem.models_for(kind, stops, fret)` ne garde alors que les modèles pour lesquels `VehicleCatalog.is_freight()` est vrai ; les lignes de voyageurs, elles, n'en proposent plus. À chaque arrivée en station, `Traffic` émet `line_arrived(line_id, model)` et la ligne ajoute `VehicleCatalog.capacity_t(model)` à ses `tonnes` (sauvegardées).

## Métro

La classe `metro` (mode rail) a une clé `underground` (14 m) : `RoutePlanner` vise alors `sol - 14 m` au lieu du sol, tous les points deviennent du tunnel et aucun terrassement n'est fait. `TransportView` dessine le tracé en pointillés bleus sur le sol. La station `station_metro` (genre `metro`) a ses quais à la profondeur de la voie et une bouche d'entrée posée à la hauteur du sol.

## Itinéraires

`StationSystem.planner` (`TransitPlanner`) : `plan(a, b)` fait un Dijkstra sur les stations. Un arc est soit un trajet sur une ligne de voyageurs entre deux de ses arrêts (attente moyenne = demi-intervalle, temps de chaque saut = longueur réelle des tronçons / min(vitesse du modèle, vitesse de la voie) × 1,15 + arrêt de 12 s), soit une correspondance à pied (≤ 250 m, + 120 s de pénalité au changement). Marche : 1,3 m/s avec un détour de 30 %. Le résultat (`legs` : étapes `marche` ou `ligne`) est comparé à la marche seule. Le cache par ligne est vidé à chaque changement de lignes ou du réseau. `board(trip, n)` ajoute `n` voyageurs aux lignes empruntées (`passengers`, sauvegardé) ; `describe(trip)` donne un résumé lisible.

## Crémaillère et viaducs

Classe `cremaillere` (rail, 25 km/h, pente maxi 25 %, rayon mini 60 m, clé `rack`) : `TransportView._rail_section` y ajoute le rail denté. Les véhicules ont `"rail": "cremaillere"` ; `VehicleCatalog.for_track` et `StationSystem.models_for` (gare dont la voie est une crémaillère) séparent ces trains des autres.

`TransportView._viaducts` remplace les piles génériques pour le rail : chaque suite de points `BRIDGE` est découpée en travées égales (en pierre : 0,8 × la hauteur entre 8 m et `VIADUCT_SPAN` 18 m ; LGV : 2 × la hauteur entre 25 m et `VIADUCT_SPAN_LGV` 40 m), avec une pile à fruit à chaque appui intérieur et, en pierre, des tympans pleins sous le tablier au-dessus d'un intrados en demi-cercle.

## Piétons des trottoirs et passages piétons

`Traffic.spawn_walker()` crée un piéton (`sidewalk` = ±1, côté du trottoir par rapport au sens de marche) sur un tronçon dont la classe a `side_kind: "trottoir"`. Leur nombre suit `SIDEWALK_DENSITY`, à part des véhicules d'ambiance (`count_mode` ne les compte pas). Au bout d'un tronçon, `_sidewalk_next` choisit un autre trottoir.

`JunctionControl.has_crosswalk(nid, eid)` est vrai pour une branche à trottoirs d'un carrefour géré si le tronçon est assez long. La bande (`CROSS_W` = 3 m) est peinte juste après le plateau, et `stop_dist(eid, nid)` recule la ligne d'arrêt derrière elle (utilisée par `Traffic._drive`).

Un piéton qui arrive au milieu du passage traverse avec la probabilité `CROSS_CHANCE` :
- attente (`cross` = 1) jusqu'à ce que `_may_cross` l'autorise : rouge pour sa branche aux feux, aucune réservation du carrefour sur cette branche, aucun véhicule tout près ;
- traversée (`cross` = 2) ;
- puis il continue sur le trottoir d'en face.

Pendant la traversée, `JunctionControl.crossing[Vector2i(nœud, tronçon)]` est compté, et `Traffic._may_enter` refuse l'entrée par cette branche comme la sortie vers elle.

`VehicleCatalog.bike_on_road(id, cls)` ajoute les vélos (mode chemin) au catalogue des rues et avenues (`BIKE_ROADS`) ; dans le trafic, ils prennent la voie de droite (`lane_idx` 3, ramené au nombre de voies), décalés de 30 % de sa largeur vers le bord.

## Raccords des tronçons

- **Nœud de degré 2 « lisse »** (`TransportView.is_smooth_joint`) : les deux tronçons sont du même mode et forment un angle de `SMOOTH_JOINT` (150°) ou plus entre leurs directions sortantes. Le nœud n'a alors ni rognage ni plateau. `joint_rights(net, eid)` donne pour chaque bout le vecteur « droite » de la bissectrice, divisé par le cosinus du demi-angle pour garder la largeur. `build_mesh` l'impose au premier ou au dernier point, et les deux maillages partagent exactement leurs bords.
- **Autres nœuds** : `junction_mesh` trie les branches par angle. Entre deux branches voisines, il trace une courbe de Bézier quadratique pour la bordure et une pour le bord extérieur. Le point de contrôle est l'intersection des deux bords prolongés, ou leur milieu. Entre ces courbes, il pose une bande de trottoir avec sa bordure si l'une des branches a des trottoirs. La chaussée est un éventail du centre jusqu'aux bordures.
- **Sol sous les plateaux** : `TransportView.junction_cells` donne les cases sous le contour extérieur (marge de 0,6 m), avec la hauteur de la chaussée interpolée dans l'éventail. `TransportSystem._refresh_junction_cells` les réserve (`_occupied`, donc pas d'arbres ni de talus d'une autre voie) et y pose le terrain, sauf sur un pont ou dans l'eau. Les triangles de la chaussée ont une normale verticale. `crosswalk_clear` donne la longueur sans marquage au bout d'un tronçon qui porte un passage piéton ; `JunctionControl.has_crosswalk` s'en sert aussi.
