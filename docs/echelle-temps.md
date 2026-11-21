# Tout bouge à la vitesse du temps

Demande de Gaël (16 novembre 2026) : véhicules, personnages, travaux, etc. doivent
aller à la vitesse du temps choisie par le joueur (T = pause, Maj + T = vitesse).

## Deux familles de systèmes

1. **Ce qui compte en heures de jeu** (chantiers et leur rythme ×3 de l'Admin,
   production, emplois du temps des habitants, passants visibles, machines
   agricoles, budget, déchets, zoo, parc, tourisme, saisons, climat…) lit déjà
   `DayNight.unix_time`. Ces systèmes suivent l'horloge exactement et s'arrêtent
   en pause.
2. **Les mouvements visibles** (véhicules d'ambiance, bus, trains et camions des
   lignes, secours, gestes des ouvriers et engins de chantier, métiers en coupe,
   bêtes du zoo, des fermes et des décors, manèges, visiteurs des musées, touristes,
   figurants des spectacles, des matchs, des fêtes et des obsèques, occupants des
   intérieurs, engins des carrières) avançaient en secondes réelles. Ils passent
   maintenant par `EchelleTemps` (`scripts/ambiance/echelle_temps.gd`).

À 1 jour/min, une seconde réelle vaut 24 minutes de jeu : une voiture qui roulerait
« vraiment » à cette allure traverserait la ville en un éclair. Le facteur des
mouvements est donc lisible plutôt qu'exact, réglé pour que la vitesse par défaut
ne change pas :

| Vitesse du temps | Pause | Réel | 1 min/s | 10 min/s | 1 jour/min (défaut) | 100 min/s | Turbo (4 h/s) |
|---|---|---|---|---|---|---|---|
| Mouvements | arrêt | ×0,25 | ×0,5 | ×0,75 | ×1 | ×2 | ×3 |

**Turbo** (ajouté le 2026-11-20) : 1 jour de jeu en 6 s, 10 fois la vitesse par
défaut, pour faire grandir vite la première ville. Pour tenir la cadence, les
livraisons (Production) y sont lancées une fois par heure de jeu au lieu de tous
les quarts d'heure, et le relevé quotidien des statistiques reprend le sondage
du jour d'Avis au lieu d'en refaire un. Mesures (tests/perf_ville.gd
`--vitesse 6`, sans GPU) : 1 000 habitants ≈ 70 images/s, 5 000 ≈ 28 images/s,
avec un à-coup de 0,3 à 0,5 s par jour de jeu (relevés quotidiens, aussi
présents à 1 jour/min, mais une fois par minute).

Départ rapide (Admin F10, `ReglagesPartie.depart_rapide`) : voir
`Chantiers.bonus_depart` (chantiers ×3 jusqu'à 200 habitants, effacé à 400).

Le tableau est dans `EchelleTemps.FACTEURS` (un nombre par vitesse de
`DayNight.SPEEDS`).

La croissance des zones (une construction tous les 0,8 s) suit aussi ce facteur :
rien ne pousse en pause.

## Vue au sol et à bord

Le personnage du joueur marche toujours en temps réel (c'est le joueur qui le
déplace, il doit rester maniable, même en pause). Pour que la rue reste
cohérente avec lui, en vue au sol (1re / 3e personne, à bord), les mouvements
visibles passent à ×1 tant que le temps n'est pas en pause
(`EchelleTemps.vue_sol_temps_reel`). En pause, tout est figé autour de lui.
Il n'y a pas encore de conduite manuelle : à bord, le véhicule est conduit par le
jeu et suit donc la même règle.

## Restent en temps réel (exprès)

- Caméras, mode photo, menus, messages, fondus de la musique et des sons.
- Vent dans les arbres, vagues et nuages (effets du ciel et des shaders).
- Calculs en tâche de fond (trafic, nuisances, réseaux) : seul leur résultat
  compte, pas leur cadence.

## Pour un nouveau système

Dans un `_process`, tout ce qui se voit bouger utilise
`var dt := EchelleTemps.dt(delta)` ; tout ce qui compte des heures de jeu lit
`DayNight.unix_time`.

Test : `tests/echelle_temps_test.gd`.
