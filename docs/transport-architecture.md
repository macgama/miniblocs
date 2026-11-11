# Transports et déplacements

Objectif : que le joueur puisse construire **tout ce qui sert à se déplacer** (route, rail, chemins piétons et vélos, voies d'eau, air) sur le vrai relief du mode Terre, puis le faire vivre avec des véhicules, des lignes et, plus tard, une économie.

## Principe : un seul réseau pour tous les modes

Tous les modes partagent le même **graphe** (`scripts/transport/transport_network.gd`) :

| Élément | Contenu |
| --- | --- |
| **Nœud** | Position 3D + mode (route, rail…). Carrefour, extrémité, et plus tard gare, arrêt, port, aéroport. |
| **Tronçon** | Relie deux nœuds du même mode. Garde son tracé échantillonné tous les ~2 m : position 3D et structure de chaque point (sol, pont, tunnel, eau). |
| **Type de voie** | `scripts/transport/transport_types.gd` : largeur, pente maximale, seuils pont / tunnel, vitesse des véhicules. Ajouter un type (avenue 4 voies, LGV, autoroute…) = ajouter une ligne au catalogue. |

Le graphe se sauvegarde en JSON avec les cases du terrain (`user://terre_save.json`, clé `transport`). Comme pour le terrain, seul ce que le joueur a construit est stocké : c'est ce qu'il faudra synchroniser en multijoueur.

## Pose sur le relief

`scripts/transport/route_planner.gd`, pour chaque tronçon tracé :

1. Échantillonne le sol réel tous les 2 m entre les deux points.
2. Lisse le profil (rayon 4 m pour un chemin, 14 m pour une route, 40 m pour le rail).
3. Applique la **pente maximale** : route 10 %, rail 4 %, chemin 15 %. Si la différence d'altitude entre les deux bouts est impossible à tenir, le tracé est refusé avec la raison.
4. Choisit la structure de chaque point :
   - **au sol** si l'écart avec le terrain est faible : le jeu fait un **remblai ou un déblai** (les cases sous la voie prennent la hauteur de la chaussée, comme l'outil Aplanir) ;
   - **pont** si la voie passe à plus de 4 m au-dessus du sol, ou au-dessus de la mer (tablier à 3 m minimum) ;
   - **tunnel** si elle passe à plus de 6 m sous le sol.
5. Les voies navigables restent sur la mer, au niveau 0 m.

## Carrefours et raccords

- Cliquer près d'un nœud existant du même mode s'y raccroche.
- Cliquer au milieu d'une voie la coupe et crée un **carrefour en T**.
- Une nouvelle voie qui en croise une autre **du même mode et à la même hauteur** crée un **carrefour** automatiquement. Si l'une passe sur un pont ou dans un tunnel, ou si les modes diffèrent (route / rail), elles se croisent sans se relier.

## Véhicules (étape 1)

`scripts/transport/traffic.gd` : voitures, trains (locomotive + 2 voitures), piétons, cyclistes et bateaux. Chacun choisit une destination au hasard dans son réseau et y va par le plus court chemin (A*), en roulant à droite. Le nombre de véhicules suit la longueur du réseau (1 voiture tous les 45 m de route, etc.). Pas encore de collisions, de feux, ni de lignes.

## Feuille de route proposée

| Étape | Contenu |
| --- | --- |
| **1. Fait** | Graphe commun, route / rail / chemin / voie d'eau sur le vrai relief, ponts, tunnels, terrassement, carrefours, véhicules d'ambiance, sauvegarde. |
| 2 | **Courbes** (tracé en arc, rayon mini par type), types supplémentaires (avenue, autoroute, LGV, piste cyclable), ponts et tunnels forcés à la main. |
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
