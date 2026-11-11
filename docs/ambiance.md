# Ambiance : cycle jour/nuit, Soleil et Lune réels, éclairage nocturne

## Ce que fait le jeu

- **Horloge de jeu** : date et heure du lieu choisi sur le globe. Au lancement : aujourd'hui (date de l'ordinateur), 10 h, heure locale.
- **Soleil réel** : sa hauteur et sa direction sont calculées pour la latitude, la longitude, la date et l'heure. On retrouve les vraies durées du jour (à Paris : lever 05:47 et coucher 21:58 le 21 juin, 08:41 et 16:56 le 21 décembre), la nuit polaire et le soleil de minuit en Laponie.
- **Lune réelle** : position et phase (nouvelle lune, croissant, quartier, pleine lune…). Elle éclaire faiblement la nuit, plus fort quand elle est pleine. Son disque est dessiné avec la bonne partie éclairée.
- **Ciel** : dégradé qui suit la hauteur du Soleil (journée, lueur orangée au lever et au coucher, crépuscule bleu, nuit étoilée). Les étoiles tournent autour de l'étoile Polaire au fil de la nuit.
- **Lumière et ombres** : couleur du Soleil (orange au ras de l'horizon, blanc à midi), lumière ambiante et brume assorties au ciel. Ombres en 4 niveaux de détail, dont la portée suit le zoom de la caméra.
- **La nuit** :
  - **Lampadaires** posés tout seuls le long des routes (un tous les 32 m, en quinconce) et des chemins (plus petits, tous les 24 m). Rien dans les tunnels. Ils suivent les routes qu'on construit et qu'on démolit.
  - **Fenêtres allumées** sur tous les bâtiments : plus nombreuses le soir, quelques-unes au milieu de la nuit, un regain au réveil. Toujours les mêmes fenêtres pour un même bâtiment.

## Commandes

| Action | Comment |
| --- | --- |
| Pause / reprise | **T**, ou bouton **Pause** du panneau Horloge (en bas à droite) |
| Vitesse suivante | **Maj + T**, ou boutons **Temps réel**, **1 min/s** (par défaut : une journée en 24 min), **10 min/s**, **1 h/s** |
| Choisir l'heure | Glisser la barre du panneau Horloge |
| Changer de saison | Boutons ◀ ▶ (un mois avant ou après) |

L'heure, la date et la vitesse sont gardées par **Sauver / Charger**.

## Comment c'est fait

| Fichier | Rôle |
| --- | --- |
| `scripts/ambiance/astro.gd` | Calculs astronomiques (Soleil, Lune, phase, lever et coucher, fuseau horaire approximatif) |
| `scripts/ambiance/day_night.gd` | Horloge de jeu, lumières du Soleil et de la Lune, ciel, ambiance, ombres, sauvegarde |
| `scripts/ambiance/ciel.gdshader` | Ciel : dégradé, halo, disque du Soleil, Lune avec sa phase, étoiles |
| `scripts/ambiance/street_lights.gd` | Lampadaires le long des voies |
| `scripts/ambiance/batiment.gdshader`, `night_windows.gd` | Matériau des bâtiments : fenêtres qui s'allument la nuit |
| `scripts/ambiance/clock_hud.gd` | Panneau Horloge |
| `tests/ambiance_test.gd` | Test automatique (et captures jour, coucher, nuit) |

- **Précision** : formules « basse précision » de l'Almanach astronomique, environ 0,01° pour le Soleil et 0,5° pour la Lune.
- **Fuseau horaire** : pas de base de données des fuseaux (trop lourde pour l'instant). L'heure affichée vient de la longitude, avec une correction pour l'Europe (heure de Paris, de Londres, de l'Est) et l'heure d'été européenne. Ailleurs, elle peut avoir une heure d'écart avec l'heure officielle : c'est noté « approx. » à l'écran.
- **Performances** :
  - tous les lampadaires sont dessinés en une seule fois (MultiMesh) ;
  - seuls les 48 plus proches de la caméra projettent une vraie lumière au sol, les autres brillent sans éclairer ;
  - les fenêtres sont calculées par le matériau des bâtiments, sans lumière supplémentaire.
- **Fenêtres** : toute face d'un bâtiment de la couleur `BuildingCatalog.GLASS` (vitres) devient une fenêtre la nuit, ainsi que les vitres de chaque style de la bible (`"glass"` dans `Styles.STYLES`) et quelques façades vitrées, même assombries. Pour un nouveau bâtiment, il suffit d'utiliser `GLASS` pour ses fenêtres.

## Prochaines étapes possibles

- Phares des véhicules et éclairage des gares, ports et aéroports.
- Lumières propres à certains bâtiments (enseignes du cinéma, projecteurs du stade).
- Météo : nuages, pluie, neige selon la saison et le climat réel.
- Vrai fuseau horaire du lieu (base de données des fuseaux).
- Simulation liée à l'heure (trajets domicile-travail, horaires d'ouverture) : à décider avec le game design.
