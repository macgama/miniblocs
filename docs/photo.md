# Mode photo et time-lapse

Code : `scripts/photo/` (`ModePhoto`, `TimeLapse`, `TimeLapsePanel`, `AviMjpeg`,
`filtre_photo.gdshader`). Branché dans `terre_main._setup_photo()`.
Test : `godot --headless --path . --script res://tests/photo_test.gd`.
Vitrine (avec affichage) : `godot --path . --script res://tests/photo_vitrine.gd -- --sortie dossier --vue timelapse|photo|filtres|export`.

## Mode photo (F8, ou menu Infos → Mode photo)

- **Temps figé** (`get_tree().paused`, case à cocher) : voitures, habitants, pluie,
  tout s'arrête. Pas sur une carte entre amis (`ModePhoto.figeable()`).
- **Interface cachée** : tous les `CanvasLayer` du jeu sont masqués puis rendus
  à la sortie. La caméra de gestion et la vue au sol sont arrêtées.
- **Caméra libre** (part de la vue du joueur) : ZQSD / WASD avancer à
  l'horizontale, A / E (Q / E en QWERTY) descendre / monter, clic droit ou
  molette enfoncée glissé pour regarder, molette = zoom (champ de vision), Maj
  vite, Ctrl lent. Elle ne passe jamais sous le relief (`rig.ground_height`).
- **Heure de la lumière** (temps figé seulement) : déplace le Soleil, la Lune et
  le ciel via `DayNight._shift` ; l'horloge du jeu (`unix_time`) ne bouge pas.
  Remis comme avant à la sortie.
- **Réglages** : horizon penché, flou de profondeur (mise au point, force),
  12 filtres (aucun, noir et blanc, sépia années 1800, vintage, chaud, froid,
  vif, délavé, nuit bleue, maquette tilt-shift, carte postale, néon), force du
  filtre, luminosité, contraste, saturation, vignette, grain.
- **Cadrage** : écran, 16:9, vertical 9:16 (TikTok, Reels), carré, 4:5,
  cinéma 2,39:1 (le hors-cadre est assombri), grille des tiers ; définition
  HD, 2K ou 4K (petit côté 1080, 1440 ou 2160 px).
- **Photo** (Espace) : rendue à part dans un `SubViewport` à la taille voulue,
  avec le filtre, sans l'interface ni les guides. PNG dans
  `Images/MiniBlocs/Photos` (sinon `user://photos`).
- H masque le panneau, Échap ou F8 quitte.
- « Filmer ce cadrage en time-lapse » : ajoute une caméra du time-lapse avec
  cette vue (format paysage, vertical ou carré selon le cadrage).

## Time-lapse (Maj+F8, ou bouton du mode photo)

- **Enregistrement** : une caméra fixe se pose toute seule à la fondation de
  chaque village (de biais, à 300 m de la Maison de commune), 4 caméras au plus.
  Chaque caméra prend une image par jour de jeu (réglable : 2, 3, 7 ou 30 jours),
  vers midi (lumière de 11 h en plein jour, sinon entre 14 h et 16 h), rendue
  à part (`SubViewport`), en JPEG 720p (≈ 100 Ko) ou 1080p.
- Les images attendent si le joueur est à plus de 2,5 km de la caméra (le
  relief n'est chargé qu'autour de lui).
- **Fichiers** : `user://timelapse/<id de la partie>/c<caméra>/00000.jpg`. La
  sauvegarde (section `timelapse`) garde l'id, les caméras et l'index des images
  (instant, habitants). En rechargeant une sauvegarde plus ancienne, les images
  suivantes sont réécrites.
- **Ancienne partie** (sans section) : une caméra par village, à partir du
  chargement.
- **Écran** : la partie se met en pause ; lecture (Espace), ← →, Début / Fin,
  4 à 60 images par seconde, date et habitants incrustés, logo MiniBlocs.
  Caméras : choisir, recadrer sur la vue actuelle, suspendre, effacer les images,
  supprimer, en ajouter une (vue actuelle, format paysage / vertical / carré).
  Réglages : enregistrer oui / non, intervalle, qualité.
- **Export** dans `Images/MiniBlocs/Time-lapse` : vidéo AVI Motion JPEG écrite
  à la main (`AviMjpeg`, lisible par VLC, le lecteur Windows et les logiciels de
  montage), la dernière image tenue 2 s ; MP4 H.264 en plus si `ffmpeg` est dans
  le PATH ; ou la suite d'images. Avec incrustations, chaque image est recomposée
  dans un `SubViewport` ; sans, les JPEG sont copiés tels quels.

## Pistes

- Rejouer la croissance en 3D (bâtiments datés), avec une caméra libre.
- Trajectoires de caméra (travellings) pour des vidéos plus vivantes.
- Partage direct (Steam, réseaux sociaux).
