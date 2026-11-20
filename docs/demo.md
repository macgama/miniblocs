# Démo guidée (environ 30 minutes)

Code : `scripts/tutoriel/demo.gd` (`Demo` : lieu, réglages, lancement),
`scripts/tutoriel/demo_bilan.gd` (`DemoBilan` : bilan de fin), les étapes dans
`Tutoriel.ETAPES_DEMO` (`scripts/tutoriel/tutoriel.gd`).
Édition démo pour Steam (build à part, limites, liste de souhaits) : `docs/demo-next-fest.md`.
Tests : `tests/demo_test.gd` (headless), `tests/demo_vitrine.gd` (captures et vidéo
pour la page Steam).

![La démo guidée pendant un marché](apercu-demo-marche.jpg)

## Lancer la démo

Menu principal → **Démo guidée**. C'est une nouvelle partie, toujours au même
endroit : **Échallens (Vaud)**, un plateau agricole presque plat avec des bois
(`Demo.LIEU`), avec les réglages **Normal** (30 M€, 100 fondateurs, réseaux
obligatoires). Pas de globe à traverser.

La carte en haut à gauche affiche « Démo guidée · étape N / 18 · 12 min ». Le
chrono compte le temps réel joué (pas le temps en pause).

## Le parcours

1. Les 13 premières étapes du **tutoriel** (caméra, Maison de commune, fondateurs,
   route, logements, courant et eau, temps, emplois, marchandises, école,
   poubelles, budget, objectifs), sans l'étape « Tu es maire ! ».
2. Les chapitres de la démo :

| # | Chapitre | Il se valide quand… | Bouton |
|---|---|---|---|
| 14 | Descendre dans la rue | la vue au sol est active (V) | passe en vue au sol |
| 15 | Un coin pour souffler | un espace public, un loisir ou un terrain de sport est posé | Construire → Espaces publics |
| 16 | Une fête au village | un marché ou une fête est organisé (I → Organiser) | ouvre Infos → Organiser |
| 17 | Prendre le bus | une ligne de transport existe (L) | ouvre les lignes |
| 18 | Cent habitants | la ville a 100 habitants (ou le rang de Village) | ouvre Maj+J |
| 19 | Fin de la démo | bouton « Voir mon bilan » | ouvre le bilan |

![Le bilan de fin de démo](apercu-demo-bilan.jpg)

**Bilan** : temps de jeu (et jours passés en ville), rang, habitants, bâtiments,
kilomètres de routes, lignes, caisse, réputation, étapes faites. Deux boutons :
**Continuer à jouer** (la partie continue, sans tutoriel) et **Menu principal**
(la partie est d'abord sauvegardée, on peut la reprendre avec Continuer).

Comme le tutoriel : « Passer » saute un chapitre, la croix arrête la démo, une
partie sauvegardée en pleine démo la reprend au même chapitre avec son chrono
(section `tutoriel` : `parcours`, `temps_demo`, `jour0`, `demo_finie`).

## Rythme

Mesuré avec `tests/partie_test.gd -- --jours 40` (joueur automatique, Normal,
1 jour de jeu = 1 minute) : premières maisons habitées vers le jour 15, 100
habitants logés vers le jour 25, 240 au jour 30. Les 11 étapes du tutoriel et les
chapitres 12 à 15 se font pendant que les chantiers avancent ; la démo tient donc
en 25 à 35 minutes. Le rang de Village demande aussi 50 % de satisfaction, ce qui
peut prendre plus longtemps : c'est pour ça que le dernier chapitre accepte
100 habitants.

## Équilibre (2026-11-20)

La démo n'atteignait le rang de Village qu'une partie sur deux : sans tour
d'habitation tirée au sort dans la zone, le campement se vide maison par maison
(≈ 50 jours au lieu de 21) et la satisfaction tombait à 0 %. Trois causes,
mesurées avec `tests/demo_parcours_test.gd` :

- **Rayons vides** : ni dépôt de marchandises ni chauffeur-livreur, le stock du
  début s'épuise. Étape « Remplir les rayons » (dépôt + entrepôt) ; quand les
  rayons sont vides et qu'il n'y a aucun chauffeur, deux fondateurs sans chantier
  prennent le volant d'un entrepôt (`Fondateurs._livreurs`).
- **Manifestations ignorées** (elles comptent comme ignorées sans réponse) :
  bulle « Une manifestation ! » sur « Négocier » à la première.
- **Bidonvilles et expulsions** pendant que des fondateurs dorment encore sous
  la tente : plus de baraques ni d'expulsions dans un village en fondation
  (`Immobilier._ville_en_fondation`).

Résultat : rang de Village 6 parties sur 6 (5,8 à 14 min de jeu à vitesse max,
satisfaction 50 à 95 %), contre 2 sur 4 avant.

## Captures et vidéo pour la page Steam

`tests/demo_vitrine.gd` bâtit un village au lieu de la démo (vrai relief,
téléchargé), puis prend 8 captures en 1920 × 1080 : vue du ciel, campagne à
l'horizon, centre, démo guidée pendant un marché, vue au sol, soir, foot, bilan.

```
godot --path . --rendering-driver opengl3 --resolution 1920x1080 --script res://tests/demo_vitrine.gd -- --dossier captures/demo
```

Vidéo (environ 40 s, 5 plans) avec le Movie Maker de Godot, puis ffmpeg :

```
godot --path . --rendering-driver opengl3 --resolution 1920x1080 --write-movie film.avi --fixed-fps 30 --script res://tests/demo_vitrine.gd -- --film
ffmpeg -ss <début> -i film.avi -c:v libx264 -crf 18 -pix_fmt yuv420p -c:a aac demo.mp4
```

Le script imprime « FILM DÉBUT image N » : la vidéo utile commence à N / 30 s.

## Changer le lieu ou les chapitres

- Lieu : `Demo.LIEU` (nom, latitude, longitude, code du pays pour le drapeau).
- Chapitres : ajouter une entrée à `Tutoriel.ETAPES_DEMO` (avec `"demo": true`),
  un cas dans `Tutoriel.est_faite()` et, pour son bouton, dans
  `terre_main._on_tuto_action()`.

## Test de bout en bout

`tests/demo_parcours_test.gd` joue la démo comme un joueur : bouton « Démo
guidée » du menu → écran de chargement → partie à Échallens (Normal, 100
fondateurs + 40 ouvriers du kit, vrais chantiers) → chaque étape avec le bouton
de la carte puis le geste demandé, sans jamais « Passer » → le temps tourne à
la vitesse du jeu (accéléré par `Engine.time_scale`, le chrono de la démo compte
donc les minutes du joueur) → bilan → « Menu principal » → « Continuer ».

```
godot --headless --path . --script res://tests/demo_parcours_test.gd [-- --echelle 20 --rapport parcours.csv]
```

Options : `--proxy hôte:port --ca fichier.crt` (vrai relief téléchargé),
`--soigneux` (maire prévoyant : déchets, dépôt de marchandises, négocie avec
les manifestants), `--aleas` (incendies, tempêtes et crues au hasard, coupés
sinon pour que le test reste reproductible). À la fin : ce que disent les
habitants (thèmes, motifs), les réseaux, les bâtiments.

Mesures (novembre 2026, gestes instantanés) : 100 habitants vers le jour 38-45,
soit 10 à 11 minutes de jeu à vitesse maximale ; un vrai joueur, qui lit les
cartes et pose ses routes à la souris, met plutôt 25 à 35 minutes.

Corrigé grâce à ce test :
- un incendie, une tempête ou une crue rasait le campement des fondateurs : les
  140 fondateurs quittaient la ville d'un coup et plus aucun chantier
  n'avançait. Le campement est maintenant replanté sur place ;
- le chapitre « Un coin pour souffler » se validait tout seul dès qu'un café
  poussait dans la zone commerciale ;
- le bilan affichait 16 / 17 étapes même démo finie ;
- les fondateurs sous la tente manifestaient dès le premier jour (seuil de 50
  habitants compté avec eux) ;
- un motif de l'avis était compté autant de fois qu'il apparaissait (« 690
  habitants » sur 138) ;
- un village sans livraisons possibles (ni chauffeur-livreur, ni dépôt, gare,
  port ou route qui sort de la carte) mourait de faim devant une boulangerie
  vide : les foyers font maintenant leurs courses dans une ville voisine
  (« rayons vides : fait ses courses dans une ville voisine », −5) ;
- l'étape du tutoriel « Courant, eau et égouts » demande aussi un traitement
  des égouts (le kit de l'État le paie) : sans lui, tous les logements
  avaient « les égouts débordent ».

Équilibrage choisi par Gaël (2026-11-15) : sous 500 habitants
(`Communes.ATTENTES_REDUITES_MAX`), personne ne se plaint de l'absence
d'hôpital, de police, d'internet ou de réseau mobile (on va à la ville
voisine), et l'outil Route pose une rue de village par défaut (plus une
départementale). Satisfaction à la fin de la démo : de 10-25 % à 42-46 % ; il
reste surtout les poubelles (dépôt de collecte du kit) et les commerces.

### Rang de Village (2026-11-15)

Le test va maintenant jusqu'au **rang de Village** (100 habitants et 50 % de
satisfaction, seuil inchangé) et échoue s'il n'est pas atteint dans les 10
minutes qui suivent les 100 habitants. Ce qui bloquait, et ce qui a changé :
- **Poubelles** : personne ne posait de dépôt de collecte, et même posé il
  n'avait qu'un ou deux éboueurs (il en faut trois par benne) : aucune tournée,
  sacs sur les trottoirs, mauvaises odeurs dans tout le village. Nouvelle étape
  du tutoriel et de la démo, « Ramasser les poubelles » (dépôt de collecte +
  décharge, en grande partie payés par le kit de l'État). Le dépôt compte
  comme fermé tant qu'il n'a pas trois éboueurs (`Effectif.REQUIS_MIN`).
- **Fondateurs sans chantier** : chaque matin, ceux qui n'ont pas de chantier
  vont tenir les bâtiments fermés faute d'un métier indispensable (éboueurs,
  boulanger, enseignant…), autant qu'il en faut pour ouvrir
  (`Fondateurs.depanner`). Ailleurs, un tel bâtiment recrute chez un employeur
  voisin qui garde la moitié de ses postes (`Population._mobilite_requis`).
- **Files d'attente** : un commerce était « en sous-effectif » sous la moitié
  de ses postes, quelle que soit sa clientèle ; dans un village où les emplois
  dépassent les actifs, tous les habitants avaient « longues files au
  commerce ». Le personnel utile suit maintenant la clientèle : un employé pour
  25 habitants dont c'est le commerce le plus proche
  (`Effectif.HAB_PAR_VENDEUR`, `Population.clients_commerce`), les fondateurs
  sous la tente ne comptent pas (ils vivent de leurs vivres). Les fondateurs
  sans chantier vont aussi renforcer un commerce où l'on fait la queue.

Mesures (parcours sans réglage particulier, décharge à l'écart des maisons) :
rang de Village atteint dans 12 parcours sur 12, entre 7 et 13 minutes de jeu
à vitesse maximale (jour 27 à 53), satisfaction 50 à 78 % au moment du rang
(avant : 25-46 %, rang jamais atteint). Il reste surtout les rayons vides (pas
de livraisons sans dépôt de marchandises), le bruit et les manifestations
ignorées.
