# À bord des véhicules

On peut monter dans n'importe quel véhicule du jeu et se laisser conduire : le
véhicule roule tout seul (sa ligne, sa tournée, sa mission ou un trajet au hasard).
La conduite manuelle viendra plus tard.

## Commandes

| Touche | Effet |
|---|---|
| E (vue au sol, près d'un véhicule) | monter à bord (à moins de 3,5 m de la carrosserie) |
| Maj+V (toute vue) | monter dans le véhicule le plus proche du centre de la vue |
| E à bord | descendre à côté du véhicule (refusé en plein vol, ou en mer sans quai à portée) |
| Maj+E à bord | passer dans le véhicule voisin le plus proche (moins de 40 m) |
| V à bord | caméra extérieure ↔ place du conducteur |
| Souris / molette | tourner autour, reculer (au plus près : place du conducteur) |
| Maj+V à bord | revenir à la vue de dessus, centrée sur le véhicule |

Le bandeau en haut à gauche donne le nom du véhicule, sa vitesse et son activité
(ligne et prochain arrêt, urgence, collecte des déchets, livraison, tâche aux champs…).

## Véhicules concernés

- toute la circulation (`Traffic.vehicles`) : voitures, deux-roues, bus, cars, trams,
  trains, métros, bateaux, avions et hélicoptères des lignes, camions de livraison,
  bennes à ordures, corbillards, pompiers, ambulances, police ;
- tout `Node3D` du groupe `ABord.GROUPE` (`"vehicules_montables"`) : machines
  agricoles (`AgriVisuels`), engins de chantier (`EnginsChantier`).

Pour rendre un nouvel engin montable (mines, parc de loisirs…), l'ajouter au groupe
et poser les métas facultatives : `nom_bord` (String), `infos_bord` (String ou
Callable qui rend une String), `siege_bord` (Vector3, place du conducteur dans le
repère du nœud), `avant_plus_z` (vrai si l'avant du modèle regarde vers +Z).

## Règles

- Un véhicule de la circulation avec quelqu'un à bord porte `v.aboard` : il n'est pas
  retiré par la densité, et une voiture bloquée se faufile au lieu de disparaître.
- Quand un véhicule quitte quand même la circulation (fin de tournée, ligne
  supprimée), `Traffic.vehicle_removed` dépose le joueur sur place.
- Un engin remplacé (nouvelle tâche aux champs) : on remonte dans son successeur
  s'il est à moins de 15 m.

Code : `scripts/personnage/a_bord.gd` (recherche, places, bandeau) et
`scripts/personnage/vue_sol.gd` (montée, descente, caméras). Test :
`tests/a_bord_test.gd`.
