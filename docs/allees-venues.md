# Allées et venues des habitants

Près de la caméra, on voit les habitants sortir de chez eux le matin, entrer au
travail, à l'école, au magasin, à la salle de sport ou au loisir du jour, puis
rentrer le soir, en suivant leur emploi du temps (`Population.day_plan`).

Code : `scripts/habitants/passants.gd` (Passants) et `scripts/habitants/portes.gd`
(Portes). Test : `tests/allees_venues_test.gd`. Captures :
`tests/allees_venues_vitrine.gd`.

## Ce qu'on voit

- **Sortie** : la porte du bâtiment s'ouvre (vantail qui pivote vers l'intérieur
  devant une embrasure sombre), l'habitant sort et marche :
  - à pied : jusqu'au trottoir, puis il suit la rue ;
  - en voiture : jusqu'à sa voiture garée au bord de la rue, côté bâtiment ; il
    monte, la voiture démarre ;
  - à vélo : jusqu'à son vélo, puis il roule ;
  - en bus, tram ou train : jusqu'à l'arrêt (TransitPlanner), il attend debout,
    puis monte (il disparaît pendant le trajet en ligne) et réapparaît à l'arrêt
    d'arrivée.
- **Arrivée** : la voiture se gare devant le bâtiment, il descend, marche jusqu'à
  la porte qui s'ouvre devant lui, et entre. Sa voiture reste garée tant qu'il est
  là (au plus 120 voitures garées) ; c'est elle qui repart avec lui.
- **Courses, sport, loisirs** : dans l'emploi du temps, ces moments s'enchaînent
  sans trajet écrit. Passants ajoute, pour l'affichage seulement, un trajet au
  début du moment (durée de `Population.commute`, au plus la moitié du moment).
  La simulation, elle, ne change pas.

## Temps

- Les scènes de porte (sortie, arrivée, portes) suivent `EchelleTemps` : la pause
  arrête tout, 100 min/s va deux fois plus vite.
- Le trajet lui-même suit l'horloge, comme avant. Aux vitesses rapides, l'horloge
  finit parfois le trajet avant la fin de la scène de sortie : le passant rattrape
  alors son retard en 0,8 s au plus (`RATTRAPAGE`), sans téléportation.
- Plus d'une heure de jeu de retard (saut dans le temps) : pas de scène d'arrivée.

## Performances

| Réglage | Valeur | Rôle |
|---|---|---|
| `MAX_AGENTS` | 300 | passants en même temps |
| `LOD_PROCHE` | 110 m | personnages détaillés, portes et scènes en deçà |
| `MAX_PROCHES` | 90 | personnages détaillés (au-delà : simples blocs) |
| `MAX_SCENES` | 40 | sorties et arrivées en même temps |
| `Portes.MAX` | 48 | portes ouvertes en même temps |
| `MAX_GAREES` | 120 | voitures garées gardées |

Les bâtiments les plus proches de la caméra passent en premier (trois anneaux),
pour que les plafonds gardent ce qu'on voit le mieux. Les portes n'existent que le
temps d'un passage. Banc : `tests/perf_ville.gd`.

## Limites

- La porte est posée au milieu de la façade qui regarde la rue, pas forcément là où
  le modèle dessine la sienne.
- Bâtiments tournés en biais (clé `"a"`) et bâtiments en murs fins : pas de
  vantail, l'habitant passe simplement le seuil.
- Les véhicules de secours qui sortent des casernes et des hôpitaux sont gérés par
  les urgences (`scripts/urgences`), pas ici.
