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

## Véhicules (étape 1)

`scripts/transport/traffic.gd` : voitures, trains (locomotive + 2 voitures), piétons, cyclistes et bateaux. Chacun choisit une destination au hasard dans son réseau et y va par le plus court chemin (A*), en roulant à droite. Le nombre de véhicules suit la longueur du réseau (1 voiture tous les 45 m de route, etc.). Pas encore de collisions, de feux, ni de lignes.

## Feuille de route proposée

| Étape | Contenu |
| --- | --- |
| **1. Fait** | Graphe commun, route / rail / chemin / voie d'eau sur le vrai relief, ponts, tunnels, terrassement, carrefours, véhicules d'ambiance, sauvegarde. |
| **2. Fait** | Classes réglementaires (largeurs, rayons, pentes), courbes, plateaux de carrefour, refus des chevauchements, talus. |
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
