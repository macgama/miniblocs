# Visiter les villes des autres

Menu **Visites et cartes postales** : **F12** partout, le bouton « Visites » du menu Ville, ou
**menu principal → Visiter une ville**. On se promène dans la ville d'un ami ou d'un inconnu sans
pouvoir y toucher, puis on lui laisse une **carte postale**. Tout marche sans serveur payant :
un fichier à s'envoyer, le Steam Workshop à la sortie, ou la carte entre amis déjà en place.

## Faire visiter sa ville

F12 → **Ma ville et mon courrier** :

- **Mot d'accueil** : la phrase que les visiteurs lisent en arrivant (dans le bandeau et dans F12).
- **Livre d'or** : coché, les cartes que tu as reçues partent avec ta ville et les visiteurs
  suivants les voient (épinglées et dans F12). Décoché, elles restent chez toi.
- **Fichier .mbloc de ma ville** : la partie est sauvegardée, puis elle part entière (bâtiments,
  habitants, voies, réseaux, parcs, clubs…) dans un fichier `ville-<nom>.mbloc` du dossier
  d'échange. Envoie-le comme tu veux (courriel, Discord, clé USB).
- **Publier sur le Workshop** : la même chose pour les inconnus, une fois le jeu sur Steam
  (avant, la ville part dans l'atelier local avec son fichier .mbloc).

Le dossier d'échange est celui du partage des créations : `user://partage`
(sous Windows : `%APPDATA%\Godot\app_userdata\MiniBlocs\partage`).

## Visiter

F12 → **Visiter une ville** (ou menu principal → Visiter une ville) :

1. Dépose le fichier .mbloc reçu dans ton dossier d'échange, puis **Recevoir**. Les villes du
   Workshop auxquelles tu es abonné arrivent toutes seules.
2. **Visiter** : la ville s'ouvre derrière l'écran de chargement. Si tu étais dans ta partie, elle
   est sauvegardée d'abord et « Terminer la visite » t'y ramène.

En visite :

- tu te promènes : caméra, **vue au sol V** (3e et 1re personne), à bord des véhicules (E),
  vue sous terre (Page bas), mode photo (F8) ;
- tu regardes : habitants, statistiques, cartes, gazette, saisons, trafic, niveaux de vie,
  loisirs, club, tourisme ;
- tu ne construis rien et ne règles rien : outils, Construire, budget, pays, Admin, mode Créer
  et sauvegarde sont fermés (« En visite, on regarde sans toucher ») ;
- la ville vit à sa vitesse normale, mais **rien n'est gardé** : la copie (partie cachée
  `user://parties/visite`, absente de « Charger une partie ») est jetée à la fin. La ville du
  maire ne peut pas changer, et aucun succès de ville ne se débloque.

## Cartes postales

En visite, **F12** (ou « Carte postale » dans le bandeau) : quelques mots (500 signes), un timbre
(Montagne, Lac, Clocher, Tramway, Soleil, Stade) et, si tu veux, la photo de la vue (prise sans
l'interface au moment où tu ouvres F12). La carte est épinglée là où tu regardes (une petite carte
postale flotte au-dessus du sol, avec ton nom).

- **Hors ligne** : « Poster la carte » écrit `carte-postale-<ville>-<toi>-….mbloc` dans ton
  dossier d'échange. Envoie-le au maire. Dès qu'il le dépose dans **son** dossier d'échange, la
  carte entre toute seule dans le courrier de la bonne partie (même identifiant de partie) : au
  lancement, toutes les 15 secondes, ou avec « Relever le courrier ». Le fichier quitte alors le
  dossier. Une carte pour une autre partie y reste.
- **En ligne** (carte entre amis) : la carte part par le serveur, qui la signe avec ton vrai pseudo,
  la garde dans la sauvegarde de la carte et l'envoie à tous les joueurs.

Chez le maire, F12 → Ma ville et mon courrier : les cartes (nouvelles en ambre), **Aller voir**
(la caméra se place comme celle du visiteur), **Lue**, **Retirer**. Une annonce
« Carte postale de … » paraît à l'arrivée. Les cartes épinglées se masquent avec la case
« Montrer les cartes dans la ville ».

## Visiter une carte entre amis

Menu principal → **Entre amis** → **Visiter (sans construire)** : on entre sur la carte en
visiteur, avec le code d'invitation. Le visiteur n'est pas membre et n'a pas de caisse ; le serveur
refuse ses actions (poser, démolir, tracer, zones, réglages…) et ne fait passer que la discussion,
la resynchronisation et les cartes postales. L'admin peut cocher **Visiteurs sans code** (F3) :
alors un inconnu qui a l'adresse du serveur peut se promener sans code.

## Succès

- *Bons baisers de…* : laisser une carte postale dans la ville d'un autre joueur.
- *Le facteur est passé* : recevoir 10 cartes postales de visiteurs.

## Pour les développeurs

- `scripts/visite/visite_ville.gd` (`VisiteVille`) : paquet de genre « ville » (les fichiers de la
  sauvegarde, tels quels, en base64 dans `contenu.json` ; sections réécrites à la demande, par
  exemple le courrier sans les cartes), bibliothèque `user://visites`, visite (partie cachée
  `visite`, retour à sa partie), verrous (`categorie_verrouillee`, `outil_verrouille`,
  `touche_verrouillee`), cartes postales (`carte`, `paquet_carte`, `poster`).
- `scripts/visite/courrier.gd` (`Courrier`, nœud « Courrier » de la scène Terre) : cartes reçues,
  relevé du dossier d'échange, cartes épinglées (Sprite3D + Label3D), section de sauvegarde « courrier ».
- `scripts/visite/visites_panel.gd` (`VisitesPanel`) : le menu F12 (et celui du menu principal).
- `PaquetPartage.GENRES` gagne « ville » et « carte » ; `Partage.recevoir_echange` les laisse aux
  visites et au courrier ; `Partage.installer` range une ville du Workshop dans les visites.
- Carte entre amis : `bonjour` porte `visiteur` ; `CarteAmis.accepter_visiteur`,
  `visites_ouvertes` (sauvegardé) ; message `carte_postale` (client → serveur → tous) ; op admin
  `visites`.
- Tests : `tests/visites_test.gd` (partage, visite, verrous, carte postale, courrier, visiteurs en
  ligne) ; vitrine `tests/visites_vitrine.gd` (captures).

## Limites

- Une ville très grande peut dépasser la taille maximale d'un fichier de paquet (24 Mo) : le
  fichier n'est alors pas créé.
- Pas d'annuaire en ligne des villes hors Steam : avant la sortie, on s'envoie les fichiers.
- Sur la carte mondiale (à venir), les visites passeront par le même mode visiteur.
