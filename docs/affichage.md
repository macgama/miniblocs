# Fermer et réafficher les cartes d'information

Demande de Gaël (2026-11-20) : l'écran de jeu est chargé de cartes ; il faut pouvoir
toutes les fermer et les réafficher, sauf la barre du haut et la barre du bas.

## Pour le joueur

- **Croix ronde** dans le coin haut-droit de chaque carte : la ferme.
- **Œil** dans la barre du haut (entre Aide et Son) : menu **Affichage** en vignettes,
  une par carte (allumée = visible), plus « Tout afficher » et « Tout masquer ».
  Une pastille rouge sur l'œil compte les cartes fermées.
- **Ctrl + H** : tout masquer ; encore une fois, tout revient comme avant.
- Le choix est gardé pour les parties suivantes (`user://interface.cfg`, section `affichage`).

Cartes fermables : objectifs et tutoriel, scénario, habitant suivi, questions du
personnage, fil des habitants, « À faire », infos de la case, jauges de la ville.
Si les questions du personnage sont fermées et qu'une question arrive (le temps
s'arrête), un message le rappelle.

## Pour le code

- `scripts/interface/affichage_panneaux.gd` (`AffichagePanneaux`, calque 7, menu sur
  un calque 45 au-dessus des bulles du tutoriel). `terre_main._setup_affichage()` y
  inscrit chaque carte : `ajouter(id, nom, icône, aide, carte: Callable, restaurer: Callable)`.
- Une carte fermée est recachée à chaque image (`process_priority = 1000`), même si
  son propre code la remontre ; `restaurer` recalcule sa vraie visibilité quand on la rouvre.
- Toute nouvelle carte flottante doit être ajoutée là (et dans `PileGauche` si elle est à gauche).
- `PileGauche` pose la carte la plus basse au bas de l'écran même si la carte de la
  case est fermée ; `TerreHud.gauche_libre` recentre la barre du bas quand la case et
  « À faire » sont fermées.
- Test : `tests/affichage_test.gd` ; captures : `tests/affichage_vitrine.gd`.
