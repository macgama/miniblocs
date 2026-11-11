# Jouer sur la Terre entière en cases de 1 m²

## Le problème des chiffres

| | Valeur |
| --- | --- |
| Surface de la Terre | ≈ 510 000 milliards de m² (510 × 10¹²) |
| Dont terres émergées | ≈ 149 000 milliards de m² |
| Stocker 1 octet par case | ≈ 510 To : impossible à livrer dans un jeu |
| Une région de 10 km × 10 km | 100 millions de cases |

On ne peut donc pas « dessiner » toute la Terre à l'avance. À la place, le jeu **fabrique les cases à la demande** à partir de vraies données d'altitude, uniquement autour de la caméra, et ne mémorise que ce que le joueur change.

## Décisions de game design (11/11/2026)

- **Terre vierge** : seulement le vrai relief et les mers. Pas de routes ni de villes réelles.
- **Le joueur choisit où il commence**, sur un globe 3D, puis joue dans une région de 40 × 40 km autour de ce point.
- **Trois types de cartes** :
  - **Bac à sable** : seul, hors ligne, on fait ce qu'on veut.
  - **Entre amis** : un joueur crée la carte et invite ses amis. Elle reste accessible à tous ses membres même si le créateur n'est pas en ligne.
  - **Carte mondiale** : une seule Terre partagée par tous les joueurs.
- Comme le relief se recalcule à l'identique chez tout le monde, une carte partagée se résume aux cases modifiées et aux constructions : peu de données à stocker et à échanger. Les deux modes en ligne ont besoin d'un service toujours allumé (voir ci-dessous).

## Héberger les cartes en ligne

| Étape | Solution | Coût |
| --- | --- | --- |
| Entre amis (début) | Base de données en ligne avec synchro temps réel (Supabase ou Nakama). Chaque carte = ses cases modifiées. La simulation tourne chez les joueurs connectés ; à la reconnexion, le jeu calcule ce qui s'est passé pendant l'absence. | Gratuit jusqu'à quelques centaines de joueurs (offres gratuites) |
| Carte mondiale | Serveur de jeu Godot sans affichage qui charge les régions où il y a des joueurs, découpage en régions de 10 × 10 km, règles anti-vandalisme | Petit serveur loué (≈ 5 à 20 €/mois au début), à faire grandir avec le nombre de joueurs |

## Comment c'est fait (version actuelle)

1. **Données réelles gratuites** : tuiles d'altitude « Terrarium » (Mapzen Terrain Tiles, hébergées par AWS Open Data). Pas de clé, pas de compte, pas de serveur à payer. Couverture mondiale, terres et fonds marins.
2. **Résolution** : au zoom 15, un pixel ≈ 4,8 m × cos(latitude) (≈ 3,1 m à Paris). Les sources d'origine sont plus grossières à beaucoup d'endroits (SRTM ≈ 30 m). Le jeu **interpole** pour obtenir une hauteur par case de 1 m : le relief est vrai à grande échelle, lissé au mètre près.
3. **Cache** : chaque tuile (~80 Ko, environ 780 m × 780 m à Paris) est gardée dans `user://terrain_cache/`. Un lieu déjà visité se recharge hors ligne.
4. **Région locale** : on choisit un point (latitude, longitude). Il devient la case (0, 0) d'une grille plate où 1 unité Godot = 1 m = 1 case. La région de jeu fait 40 × 40 km (± 20 km, `GameStart.REGION_SIZE`). Sur cette distance, la déformation due à la courbure de la Terre reste de l'ordre de 0,3 % (invisible : tout le jeu utilise la même grille). Les rivières sont chargées par zones de 10 × 10 km autour de la caméra (voir plus bas). Au-delà de ~100 km, il faudrait une « origine flottante » (recentrer le monde) à cause de la précision des nombres à virgule.
5. **Blocs de 64 × 64 cases** générés autour de la caméra (rayon 160 à 460 m selon le zoom), libérés quand on s'éloigne. Les cases identiques voisines sont fusionnées pour garder peu de triangles.
6. **Hauteurs arrondies à 0,5 m** : donne des plateaux plats constructibles et des marches nettes, façon blocs.
7. **Modifications du joueur** : dictionnaire creux `case -> hauteur`. Seules les cases modifiées sont sauvegardées (`user://terre_save.json`).

### Pourquoi pas une seule grille pour toute la planète ?

Une grille de carrés parfaits ne peut pas recouvrir une sphère sans se déformer (pensez à une carte du monde où le Groenland paraît énorme). Le jeu travaille donc par **régions** : partout sur Terre on peut ouvrir une région, et à l'intérieur les cases font vraiment 1 m × 1 m. C'est ce que font la plupart des jeux sur carte réelle.

## Biomes (forêt, champs, eau douce, glacier, désert…)

Source : **ESA WorldCover 2021** (10 m, licence CC BY 4.0, attribution affichée en jeu), hébergée gratuitement sur AWS Open Data.

- **Globe** : `assets/biomes_monde.png` (4096 × 2048, ≈ 10 km par pixel, 400 Ko) est fabriquée une fois par `tools/build_biome_map.py` à partir des aperçus des 2 651 fichiers WorldCover. Le shader du globe combine biome + altitude (mers, sommets enneigés, ombrage du relief).
- **Terrain** : `scripts/terre/land_cover.gd` lit directement les fichiers GeoTIFF de WorldCover sur AWS, sans les télécharger en entier : seulement l'en-tête puis les blocs de ~10 km autour du lieu (50 à 150 Ko chacun), gardés dans `user://landcover_cache/`. Chaque case de 1 m reçoit le biome du pixel de 10 m qui la contient.
- Correspondance : forêt, broussailles, prairie (le bâti réel devient de la prairie : terre vierge), champs, sol nu (désert en plaine, roche en montagne), glacier, lac ou rivière (eau sous 0 m = mer), marais, mangrove, toundra. Arbres et buissons low-poly plantés selon le biome, toujours au même endroit pour un même lieu.
- Les rivières de moins de ~10 m de large ne sont pas dans WorldCover : elles viennent d'OpenStreetMap ou du calcul sur le relief (voir plus bas).

## Rivières, ruisseaux et lacs

Code : `scripts/terre/water_map.gd` (où est l'eau) et `scripts/terre/water.gdshader` (son aspect).

| Source | Quand | Ce qu'elle donne |
| --- | --- | --- |
| **OpenStreetMap** (API Overpass) | Si le jeu peut joindre `overpass-api.de` (gardé ensuite dans `user://water_cache/`) | Les vrais cours d'eau avec leur nom et leur largeur, jusqu'aux fossés de 1 m, et les étangs. Licence ODbL : attribution affichée en jeu. |
| **Calcul sur le relief** | Toujours, hors ligne | Le jeu fait « couler la pluie » sur l'altitude réelle (tuiles zoom 12, ≈ 25 m par pixel, sur ± 9 km). Chaque point se vide vers son voisin le plus bas, même dans les cuvettes (algorithme « priority-flood »), puis on additionne la surface drainée. Un ruisseau naît là où plus de 0,6 km² s'écoule et s'élargit vers l'aval (≈ 1 m à la source, 8 m pour 100 km², 40 m au plus). Calcul en arrière-plan, < 1 s. |
| **ESA WorldCover** | Toujours | Les lacs et les grandes rivières (plus de ~10 m de large). |

- **Cases d'eau** : le lit est creusé d'une marche (ruisseau < 3 m, lac) ou de deux (rivière). La surface de l'eau est 15 cm sous le haut des berges. Pas d'arbres dans l'eau. Une case modifiée par le joueur (remblai) n'est plus de l'eau.
- **Eau animée** : un même shader pour la mer, les lacs et les rivières. Vagues procédurales, reflets plus forts en regardant de biais, eau plus claire et transparente dans les petits ruisseaux, écume qui bouge le long des berges et dans les cascades (quand le lit descend d'une marche).
- **Ponts** : `RoutePlanner.plan(…, water)` reçoit `TerrainWorld.water_surface_at`. Au-dessus de l'eau, la voie passe toujours sur un pont, au moins 1,5 m au-dessus de la surface, avec des rampes ; le terrassement ne bouche jamais une rivière. Les voies d'eau (canaux) peuvent naviguer sur les rivières.
- Dans le jeu, survoler une case affiche « Rivière », « Ruisseau » ou « Étang », et son nom quand il vient d'OpenStreetMap.

Limite : le réseau du conteneur cloud où le jeu est développé bloque Overpass ; la lecture d'OpenStreetMap est testée avec une réponse enregistrée, et le calcul sur le relief prend le relais. Sur un PC normal, OpenStreetMap répond.

## Mer et côtes

Code : `scripts/terre/terrain_world.gd` (`_compute_surf_mesh`, plages dans `_compute_chunk` et `cell_kind_at`) et `scripts/terre/water.gdshader` (`wave_height`, `surf_only`).

- **Houle** : le grand plan de mer est subdivisé (96 × 96) et ses sommets montent et descendent (somme de sinus, ± 7 cm).
- **Ressac** : dans chaque bloc, on calcule pour chaque case de mer sa distance à la terre (cases sèches seulement, pas les lacs). Les cases à 4 m ou moins reçoivent une bande d'écume (child « Ressac ») ; le shader y fait rouler des bandes vers la plage, plus une écume fixe tout au bord.
- **Plages** : une case de terre devient « Plage » si elle est entre 0 et 2,5 m, peu pentue, et touche la mer (ou est à 1 m au plus), et si son biome est naturel (prairie, buissons, champs, sol nu, mangrove, zone humide). Villes, forêts et rochers restent tels quels.
- **Marées** : pas faites. Le niveau de la mer (0 m) sert partout (eau, ponts, plages) ; une marée demanderait de rendre ce niveau variable dans le temps.

## Limites connues

- La mer est dessinée comme un plan d'eau à 0 m : les polders des Pays-Bas restent inondés à l'écran (leur biome, lui, est correct).
- Les bâtiments, la tour Eiffel ou les arbres ne sont pas dans ces données (c'est le sol nu, parfois bruité en ville).
- Le jeu télécharge les tuiles depuis Internet la première fois. Pour une version Steam, il faudra soit embarquer des régions pré-téléchargées, soit garder ce téléchargement avec un écran de chargement.

## Prochaines étapes possibles

| Étape | Données | Licence |
| --- | --- | --- |
| Mode « Ensemble » | Synchroniser les cases modifiées entre joueurs (GodotSteam) | — |
| Relief vraiment au mètre en France | IGN RGE ALTI 1 m | Licence Ouverte Etalab 2.0 |
| Relief au mètre en Suisse | swisstopo swissALTI3D (0,5 m) | Libre, attribution |
| Recherche de n'importe quel lieu par son nom | Nominatim / Photon, ou une liste de villes embarquée (GeoNames) | Nominatim : usage limité ; GeoNames : CC BY |
| Relier le mode Terre au city builder | Routes et zonage posés sur le relief | — |
| Très grandes distances | « Origine flottante » : recentrer le monde quand la caméra s'éloigne | — |
