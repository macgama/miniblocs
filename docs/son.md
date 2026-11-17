# Son et musique

Le jeu a maintenant des **ambiances sonores**, des **sons d'effets et
d'interface** et **7 morceaux de musique**. Tout est fabriqué par le script
`tools/build_sons.py` (synthèse maison, aucun enregistrement extérieur), donc
libre de droits (CC0, voir `assets/son/LICENCE.md`).

## Pour le joueur

- **F2**, ou l'icône haut-parleur de la barre du haut : panneau **Son et
  musique**.
  - Volumes : **Général**, **Musique**, **Ambiance**, **Effets**, **Interface**.
  - **Silences entre les morceaux** (par défaut) : quelques dizaines de secondes
    de calme pour entendre la ville, comme dans les grands city builders.
  - **Couper quand le jeu est en arrière-plan**.
  - **Morceau suivant**, **Silence**, et la liste de lecture : décocher un
    morceau le retire, ▶ l'écoute tout de suite.
- Les réglages sont ceux **du joueur** (fichier `user://son.cfg`) : ils valent
  pour toutes les parties et le globe, et ne vont pas dans la sauvegarde d'une
  partie (une partie entre amis ne doit pas imposer son volume aux autres).

## Ambiances : on entend ce que regarde la caméra

Le centre d'écoute est le point regardé (vue de dessus) ou la caméra (vue au
sol). Huit nappes en boucle se mélangent en douceur (bus « Ambiance ») :

| Nappe | Quand |
| --- | --- |
| Nature de jour | loin des bâtiments : vent dans les feuilles, merles, mésanges, un coucou au loin |
| Nature de nuit | loin des bâtiments, la nuit : grillons (s'il fait plus de 10 °C), chouette, grenouilles |
| Ville de jour | selon le nombre de bâtiments à moins de 160 m : brouhaha, passants, voitures au loin, pigeons, sonnette de vélo, portières |
| Ville de nuit | la ville calme : rumeur lointaine, une voiture, un chien qui aboie |
| Trafic | selon les véhicules à moins de 90 m (voitures, camions, scooter, effet Doppler) |
| Pluie | selon la météo (la neige, elle, étouffe tout) |
| Vent | à la campagne, par gros temps, en orage, et quand la caméra prend de la hauteur |
| Mer | quand il y a de la mer autour du point écouté |

- **Hauteur de la caméra** : en montant, les détails (oiseaux, rue, trafic)
  s'effacent et le vent d'altitude prend le dessus.
- **Chantiers** : un son de chantier (marteaux, scie, perceuse, moteur diesel,
  bip de recul) est posé en 3D sur les 3 chantiers en activité les plus proches
  (bâtiments et voies), seulement quand les ouvriers travaillent.
- **Orages** : chaque éclair est suivi du tonnerre, 0,4 à 3,5 s plus tard.
- **Village** : les cloches sonnent à midi en ville, le coq chante vers 6 h 30
  à la campagne (au plus une fois toutes les 4 minutes réelles, pour ne pas
  sonner chaque minute quand le temps est accéléré).
- Les sirènes des secours passent par le bus « Effets ».

## Sons d'effets et d'interface

| Son | Quand |
| --- | --- |
| `ui_clic` | tous les boutons du jeu (branché tout seul, même sur les nouveaux panneaux ; mettre la méta `sans_clic` sur un bouton pour l'en dispenser) |
| `ui_ouvrir`, `ui_fermer` | un panneau de droite s'ouvre ; panneau Son |
| `ui_notification` | une nouvelle dans le fil d'actualité (au plus toutes les 4 s) |
| `ui_erreur` | bâtiment refusé, démolition impossible |
| `pose_batiment`, `demolition`, `pose_route` | le joueur pose un bâtiment, démolit, trace une voie |
| `chantier_fini` | un chantier se termine près de la caméra |
| `palier` | nouveau palier de population (fanfare de village un peu trop fière d'elle) |
| `election_gagnee`, `election_perdue` | résultat des municipales (la défaite a droit au trombone triste) |
| `alerte` | un incident (incendie, tempête…) |
| `argent` | un emprunt est accordé : l'argent arrive dans la caisse |
| `ui_vitesse` | T et Maj+T (pause, vitesse du temps) |

## Musique

La musique suit l'heure de la ville (humeur donnée par la scène Terre) :
journée, soirée, nuit ; l’écran titre et le globe ont leur thème. L’onglet Son des Options du menu principal règle les mêmes volumes (même fichier son.cfg).

| Morceau | Moment | Instruments |
| --- | --- | --- |
| Une Terre à bâtir | globe | nappe, piano électrique, clarinette, cuivres |
| Premier coup de pioche | journée | piano électrique, glockenspiel, contrebasse, balais |
| Valse du permis de construire | journée | accordéon musette ; le tampon du permis tombe à la fin |
| Conseil municipal (en retard) | journée | basson, tuba, pizzicati, tic-tac de l'horloge et coucou final |
| Nids-de-poule blues | soirée | clarinette, contrebasse qui marche ; un nid-de-poule en plein solo |
| Lampadaires | nuit | piano et nappe |
| Heure creuse | nuit | nappes et glockenspiel |

Fondu de 3 s entre deux morceaux ; le passage du globe à la ville change de
morceau tout de suite.

### Musique de son temps (parties historiques)

| Époque | Années jouées | Morceaux |
| --- | --- | --- |
| XIXe siècle | 1800 à 1919 | Menuet de la place du marché, Quadrille des diligences, L'orgue de barbarie du dimanche, Fanfare pour l'inauguration de la gare, Ragtime du saloon, Complainte du canal, Nocturne à la bougie |
| 1900-1950 | 1895 à 1964 | **Swing du tramway** (jour : clarinette, trompettes bouchées ; le tramway sonne en plein solo), **Bal musette du 14 Juillet** (jour : accordéon, banjo ; un pétard éclate au mauvais moment), **Tango du cadastre** (soir : bandonéon, violon ; chaque phrase finit sur un coup de tampon), **Clair de lune sur le gazomètre** (nuit : piano-bar, clarinette) |
| Moderne | dès 1930, et parties modernes | les 7 morceaux ci-dessus |

Les époques se chevauchent : en 1910 on entend le XIXe et le bal musette, en
1930 le swing et les morceaux modernes. Le panneau F2 indique l'époque de
chaque morceau, qu'on peut toujours lancer à la main.

## Saisons, lieux de la ville, sirènes (novembre 2026)

- **Saisons** (Saisons.saison) : en hiver, la nature de jour devient
  corneilles, rouge-gorge et vent froid ; les après-midi chauds d'été (plus de
  22 °C, au mieux vers 15 h) font chanter les **cigales** ; les nuits douces
  du printemps et de l'été, les **grenouilles** (plus fort près de l'eau).
- **Lieux de la ville**, en 3D sur place (au plus 1 ou 2 de chaque à la fois,
  dans un rayon de 320 m) :

| Lieu | Son | Quand |
| --- | --- | --- |
| École | cour de récré (cris, ballon, corde à sauter) | 8 h à 16 h 45, fort aux récrés et à midi |
| Aire de jeux | enfants | 9 h à 19 h 30, s'il ne pleut pas |
| Parc de loisirs, fête de quartier | orgue de manège, montagnes russes et cris | 10 h à 23 h |
| Zoo | lion, éléphant, singes, perroquets | 7 h 30 à 19 h 30 (calme la nuit) |
| Usine, atelier, entrepôt | presse, moteur, vapeur | 6 h à 22 h (ronron la nuit) |
| Ferme | vaches, poules, moutons, chien | 5 h à 21 h 30 |
| Piscine | plongeons, enfants, sifflet du maître-nageur | 10 h à 19 h 30, s'il fait plus de 18 °C |
| Café, marché | terrasse : conversations, rires, tasses | 8 h à 23 h 30, s'il ne pleut pas |
| Gare | quai : foule, carillon d'annonce, freins, sifflet | 5 h à minuit |
| Port | clapotis, mouettes, cordages, corne de brume | toujours |
| Stade pendant un match | tribune, chants, « ooooh » ; sifflet au coup d'envoi et à la fin, clameur à chaque but | pendant le match |
| Incendie | grondement et crépitements | jusqu'à l'extinction |

- **Sonnerie de l'école** à 8 h 15 et 16 h 30 près d'une école (cloche à
  main avant 1920).
- **Sirènes** selon le véhicule, le pays et l'époque : deux-tons des
  pompiers, deux-tons rapide de la police, trois tons du SAMU, sirène
  américaine qui ondule, « pii-poo » japonais ; avant 1920, cloche des
  pompiers à cheval (et des ambulances) et sifflet des sergents de ville.
- **Succès débloqué** : petite fanfare.
- **Pause (T)** : le trafic se tait, chantiers, lieux et sirènes se figent et
  repartent d'où ils étaient ; nature et météo restent (EchelleTemps).

## Pour le développeur

- `scripts/son/son.gd` (`Son`, nœud `/root/Son` créé à la demande, pas
  d'autoload) : bus, volumes, réglages, `Son.jouer(id)`,
  `Son.jouer_a(id, position)`, `Son.flux("ambiance/pluie", true)`, musique,
  clic des boutons, F2.
- `scripts/son/son_panel.gd` (`SonPanel`) : le panneau.
- `scripts/son/ambiances_sonores.gd` (`AmbiancesSonores`, nœud de la scène
  Terre) : nappes, saisons, chantiers, lieux (`LIEUX`, `lieu_de()` : type de
  bâtiment → son selon l'heure et la météo), sirènes (`sirene_de()`),
  tonnerre, cloches, coq, sonnerie de l'école. Une nouvelle source de chantier
  s'ajoute avec `sons.sources_chantiers.append(callable)` (renvoie des
  `Vector3`). Un nouveau lieu : une fonction dans `tools/sons/lieux.py`
  (boucle mono), une entrée dans `LIEUX`, une règle dans `lieu_de()`.
- Refaire les sons : `python3 tools/build_sons.py` (tout) ou
  `python3 tools/build_sons.py musique lampadaires` (un seul). Il faut numpy,
  scipy et ffmpeg (libvorbis). Les fichiers sont reproductibles (graines fixes).
- Les `.ogg` sont importés par l'éditeur ; sans import (tests en ligne de
  commande), `Son.flux` lit le fichier directement.
- Test : `godot --headless --path . --script res://tests/son_test.gd`.

## Pistes

- Remplacer un morceau ou un son par un enregistrement libre (Freesound,
  Kenney, OpenGameArt) ou fait dans Adobe Audition : même nom de fichier, et
  noter la licence dans `assets/son/LICENCE.md`.
- Trains et avions qui passent (sons 3D sur les véhicules), bateaux.
- Musique qui réagit à la situation (crise, fête, élections).
