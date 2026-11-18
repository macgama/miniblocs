# Panneau Admin : réglages de la partie

![Panneau Admin](apercu-admin.png)

**F10**, ou l'icône réglages de la barre du haut, ou le bouton **Règles** du panneau
Construire. Sur le globe, le bouton **Réglages…** ouvre le même panneau avant de
commencer la partie.

## Réglages

| Réglage | Effet |
|---|---|
| Argent de départ | ce que reçoit chaque joueur en arrivant sur la carte (en solo : la caisse de départ) |
| Argent illimité | plus rien n'est payé |
| Caisse actuelle | en cours de partie, l'admin peut mettre la caisse à un montant |
| Coût des constructions (×0,5 à ×5) | bâtiments, terrassement, zonage, blocs, murs et étages |
| Accès à une voie obligatoire | règle de pose des bâtiments |
| Bâtiments | tout débloqué (bac à sable), ou arbre de progression à points (Maj+F10, voir [arbre-progression.md](arbre-progression.md)) |
| Impôts (×0 à ×3) | taxe foncière et impôts des entreprises touchés par la ville |
| Usure des routes et réseaux | Aucune, Lente, Normale, Rapide (voir [budget.md](budget.md)) |
| Salaires (×0,5 à ×2) | salaires des habitants, des agents de la ville et de la production |
| Vitesse du temps, de la vie | vitesse de l'horloge (comme T / Maj+T, par défaut 1 jour de jeu par minute) et du vieillissement |
| Rythme des chantiers (réaliste ×1 à ×10) | vitesse de tous les chantiers (bâtiments, voies, réseaux) ; ×3 par défaut : premières maisons des fondateurs en 2 à 3 semaines de jeu |
| Événements automatiques | marchés du samedi, fêtes de quartier, matchs au stade |
| Catastrophes (Rares, Normales, Fréquentes) | incendies, tempêtes et épidémies au hasard ; décoché : seulement à la main (panneau Infos) |
| Épuisement des ressources | sans épuisement : mines et puits inépuisables, forêts et poissons ne s'abîment pas |

Préréglages : **Facile**, **Normal** (30 M€, prix ×1), **Difficile**,
**Bac à sable libre**. « Garder par défaut » écrit `user://reglages_defaut.json`,
proposé pour les nouvelles parties.

## Déblocage : l'arbre de progression

Les anciens paliers de population sont remplacés par l'arbre de progression à
points (voir [arbre-progression.md](arbre-progression.md)). Une ancienne partie
réglée « par paliers » passe sur l'arbre au chargement.

## Qui est admin

- **Bac à sable** : le joueur.
- **Entre amis** : le créateur de la carte seulement (`createur` = identifiant du joueur, `SaveGame.player_id()`).
- **Carte mondiale** : le développeur seulement. Pour l'instant : jeu lancé depuis l'éditeur
  Godot ou avec `-- --dev` ; le serveur fera la vraie vérification.

Les autres joueurs ne voient ni l'icône ni le bouton Règles.

## Code

- `scripts/admin/reglages_partie.gd` (`ReglagesPartie`) : valeurs, préréglages, droits,
  arbre (`ArbreProgression`), `ReglagesPartie.prix()`. `ReglagesPartie.actuel` = partie en cours.
- `scripts/admin/admin_panel.gd` (`AdminPanel`) : le panneau.
- Section de sauvegarde `reglages`. Une ancienne sauvegarde sans section garde ses règles
  (accès, argent illimité).
- Test : `tests/admin_test.gd` ; captures : `tests/admin_vitrine.gd`.

Carte entre amis : chaque joueur reçoit l'argent de départ dans sa caisse personnelle,
le serveur vérifie les droits (réglages, vitesse, code d'invitation). Voir
[multijoueur.md](multijoueur.md).
