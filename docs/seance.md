# Séances de 20 minutes et alertes claires

Trois réglages de jouabilité, pour qu'on sache toujours quoi faire et pourquoi.

## 1. Objectif de séance (carte en haut à gauche)

- Une carte « Objectif de la séance » s'affiche sous le tutoriel, au-dessus des
  objectifs : **un but**, sa raison, **le temps restant** (20 minutes réelles),
  **trois médailles** (bronze, argent, or) et la barre vers la prochaine.
- Le but est choisi d'après ce dont la ville gérée a besoin maintenant :
  caisse dans le rouge → « Remettre la caisse à flot » ; chômage → « Créer des
  emplois » ; plus de logement libre → « Loger les nouveaux venus » ; grogne →
  « Rendre le sourire aux habitants » ; service manquant pour le rang suivant →
  « Ouvrir une école » (chantier posé, à moitié construit, ouvert) ; sinon
  « Faire grandir la ville ». Deux séances de suite n'ont pas le même but.
- Récompense visible à chaque palier : prime dans la caisse de la ville
  (25 %, 25 %, 50 % ; 60 000 € + 40 000 € par rang de la ville, × coût des
  constructions), **bannière au centre de l'écran**, son « palier ». L'or donne
  en plus **1 point de progrès** (Maj+F10). La survol d'une médaille dit ce
  qu'elle demande et rapporte.
- Au bout des 20 minutes : bilan (« 2 paliers sur 3 »), puis la séance suivante.
  Or gagné avant : bouton « Encore un objectif ».
- Le temps ne compte pas pendant le tutoriel (c'est lui l'objectif) ni dans un
  menu qui met le jeu en pause. La séance est gardée dans la sauvegarde.
- Code : `scripts/pays/seance.gd` (Seance), `seance_carte.gd`, `seance_banniere.gd`.
  Signal `Seance.palier_atteint(n, seance)` : pour brancher d'autres effets
  (vol de caméra au-dessus de la ville…).

## 2. Trois alertes à la fois, avec « Régler »

- Le fil « À faire » (en bas à gauche) et la Mairie (M) montrent **3 alertes au
  plus**, les plus graves d'abord (à gravité égale, ce qui se règle d'un clic).
- Les autres attendent leur tour : « À faire · 3 sur 7 » et « + 4 moins graves :
  Mairie (M) ».
- Chaque alerte a un bouton **« Régler »** qui ouvre ce qu'il faut : le bon
  panneau, le bâtiment à construire en main, ou le bâtiment non raccordé.

## 3. La cause en un clic

- Bouton **« ? »** (« Pourquoi ? » dans la Mairie) : la cause s'affiche sous
  l'alerte, avec les chiffres du moment, et reste dépliée.
- Exemples : « Pas assez d'ouvriers : 40 au travail pour 95 demandés » (avec
  fondateurs, employés du bâtiment, chantiers sans ouvrier), « Des emplois
  restent vides : ils sont mal desservis… », « Le plus mal noté : transports
  (32/100) » avec les plaintes les plus citées, « Les dépenses dépassent les
  recettes de 12 000 € par mois » avec les plus grosses dépenses.
- Nouvelle alerte **« n chantiers à l'arrêt ou au ralenti »** (sans ouvriers,
  équipe incomplète, plus d'argent) : « Régler » ouvre Fondateurs et chantiers
  (Maj+H).
- Code : `scripts/statistiques/causes.gd` (Causes.de, Causes.alertes_chantiers).

## Tester dans Godot 4.7

1. Ouvrir le projet, lancer une nouvelle partie (sans tutoriel, ou le terminer),
   poser la Maison de commune.
2. En haut à gauche : la carte « Objectif de la séance » avec ⏱ 20 min et les
   trois médailles. Survoler une médaille.
3. Poser beaucoup de maisons d'un coup : le fil « À faire » affiche « chantiers à
   l'arrêt » ; cliquer sur « ? » puis « Régler ».
4. Vitesse Turbo (Maj+T) : les paliers tombent, la bannière apparaît.
5. Test automatique : `godot --headless --path . --script res://tests/seance_test.gd`.
