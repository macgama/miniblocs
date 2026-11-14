# Parc de loisirs (première version)

Le deuxième univers de MiniBlocs : un parc d'attractions qui vit avec la ville.
Inspiré des grands jeux de parc (attractions, files, visiteurs avec leurs
besoins, note), sans en copier ni les noms ni les modèles.

## Construire un parc

1. **Construire → Parc de loisirs → Entrée du parc**, au bord d'une route :
   portique, guichets et tourniquets. L'entrée fonde le parc.
2. Derrière elle, à **moins de 250 m**, on pose sans route :
   - 9 **attractions** animées : carrousel à chevaux, tasses tournantes, autos
     tamponneuses, train fantôme, grande roue (34 m), chaises volantes, bateau
     pirate, tour de chute libre (50 m), montagnes russes familiales ;
   - des **stands** : friterie, glacier, buvette, boutique de souvenirs ;
   - des **toilettes**, des **aires de repos** (bancs, parasols, poubelles) ;
   - un **atelier d'entretien** (techniciens et agents de propreté).
3. Le jeu dessine tout seul la **clôture** autour du parc, les **allées** depuis
   l'entrée et une place centrale avec sa fontaine. Un objet posé trop loin
   d'une entrée est « hors du parc » et ne sert à rien (le panneau le signale).

## Les visiteurs

- **Touristes** : selon l'attrait des attractions, la note du parc, le prix et
  l'accès par la route (presque personne si l'entrée n'est pas reliée).
- **Habitants** : une petite part de la population chaque jour. Ceux qui y sont
  allés sont plus contents pendant un mois (panneau Avis, thème Loisirs), et
  ceux qui vivent à moins de 2,5 km d'un parc noté 3 étoiles ou plus aussi.
- Plus de monde le samedi, le dimanche, le mercredi et en juillet-août ; moins
  l'hiver et sous la pluie. Horaires : 10 h–19 h (juillet-août jusqu'à 22 h,
  novembre à mars 11 h–18 h).
- Chaque visiteur a une **humeur**, une **faim**, une **soif**, une **fatigue**,
  une envie de **toilettes**, un **budget**, un goût pour les sensations et ce
  que son estomac supporte. Il choisit ses attractions (selon ses goûts, la file
  et ce qu'il a déjà fait), fait la queue, mange, boit, se repose et repart.
- Quand la foule est grande, chaque petit personnage en représente plusieurs
  (le panneau l'indique).
- Ce qu'ils disent apparaît dans l'onglet **Visiteurs** (« Les frites sont
  excellentes. Le prix des frites, moins. »).

## Gérer

- **Prix** : entrée (25 € par défaut) et, si l'on veut, un prix par tour de
  manège. Le panneau dit combien le parc « vaut » aux yeux des visiteurs ; trop
  cher, ils râlent ou font demi-tour.
- **Usure et pannes** : chaque tour use l'attraction ; plus elle est usée, plus
  elle tombe en panne. Les techniciens de l'atelier révisent le parc fermé et
  réparent dans la journée (1 à 2 h). Sans atelier, un dépanneur extérieur
  vient au bout de 4 h, pour 2 500 €.
- **Propreté** : chaque frite laisse un papier. Les agents de propreté de
  l'atelier ramassent ; les aires de repos (poubelles) en réduisent la quantité.
- **Personnel** : les emplois (opérateurs, vendeurs, agents d'accueil,
  techniciens, agents de propreté) sont pris par les habitants. Ce qui manque
  est complété par des saisonniers venus d'ailleurs, jusqu'à la moitié des
  postes, 30 % plus chers. Moins de personnel, manèges plus lents.
- **Argent** : billets, tours et stands entrent dans la caisse de la ville où
  est l'entrée (panneau Budget, postes « Parc de loisirs »), plus une taxe de
  séjour de 1,50 € par touriste. Salaires et entretien sortent chaque jour.
- **Note** (0 à 5 étoiles) : variété des attractions, humeur des visiteurs,
  propreté, files, prix, fiabilité et services (manger, boire, toilettes). Elle
  fait venir les touristes.
- Le parc fait du **bruit** pour les voisins (carte Bruit, panneau Cartes).

## Commandes

- **Maj + G** : panneau du parc (ou menu Économie de la barre du bas).
- Onglets : **Parc** (note, prix, recettes, détail de la note, conseils),
  **Attractions** (état, file, fiabilité, personnel, clic pour y aller),
  **Visiteurs** (besoins moyens, ce qu'ils disent).

## Pour les développeurs

- `scripts/parc/parc_types.gd` (`ParcTypes`) : catalogue (champ `"parc"`),
  modèles fixes, parties mobiles (`build_anim`, `animate`), tracé des montagnes
  russes.
- `scripts/parc/parc_loisirs.gd` (`ParcLoisirs`, nœud « ParcLoisirs ») :
  simulation par pas de 60 s de jeu, section de sauvegarde `"parc"`.
- `scripts/parc/parc_visuels.gd` : manèges animés (enfants du nœud du
  bâtiment), clôture et allées, visiteurs en MultiMesh.
- `scripts/parc/parc_panel.gd` : panneau Maj+G.
- Métiers ajoutés dans `Metiers.METIERS` : `operateur_attraction`,
  `agent_accueil_parc`, `technicien_attraction`, `agent_proprete`, `vendeur_parc`.
- Test : `godot --headless --path . --script res://tests/parc_test.gd`
- Captures : `godot --path . --script res://tests/parc_vitrine.gd -- --dossier captures/parc`

## Pistes pour la suite

- Allées posées à la main et file d'attente dessinée par le joueur.
- Éditeur de montagnes russes (tracé libre, sensations, nausée).
- Voitures et autocars de touristes sur les routes, parking du parc.
- Personnel géré à la main (embauche, formation), inspections et prix annuels.
- Le zoo, en réutilisant les visiteurs, les allées et la note.
