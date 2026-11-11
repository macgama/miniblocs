# Jouer sur la Terre entière en cases de 1 m²

## Le problème des chiffres

| | Valeur |
| --- | --- |
| Surface de la Terre | ≈ 510 000 milliards de m² (510 × 10¹²) |
| Dont terres émergées | ≈ 149 000 milliards de m² |
| Stocker 1 octet par case | ≈ 510 To : impossible à livrer dans un jeu |
| Une région de 10 km × 10 km | 100 millions de cases |

On ne peut donc pas « dessiner » toute la Terre à l'avance. À la place, le jeu **fabrique les cases à la demande** à partir de vraies données d'altitude, uniquement autour de la caméra, et ne mémorise que ce que le joueur change.

## Comment c'est fait (version actuelle)

1. **Données réelles gratuites** : tuiles d'altitude « Terrarium » (Mapzen Terrain Tiles, hébergées par AWS Open Data). Pas de clé, pas de compte, pas de serveur à payer. Couverture mondiale, terres et fonds marins.
2. **Résolution** : au zoom 15, un pixel ≈ 4,8 m × cos(latitude) (≈ 3,1 m à Paris). Les sources d'origine sont plus grossières à beaucoup d'endroits (SRTM ≈ 30 m). Le jeu **interpole** pour obtenir une hauteur par case de 1 m : le relief est vrai à grande échelle, lissé au mètre près.
3. **Cache** : chaque tuile (~80 Ko, environ 780 m × 780 m à Paris) est gardée dans `user://terrain_cache/`. Un lieu déjà visité se recharge hors ligne.
4. **Région locale** : on choisit un point (latitude, longitude). Il devient la case (0, 0) d'une grille plate où 1 unité Godot = 1 m = 1 case. La caméra peut aller à ± 12 km. Sur cette distance, l'erreur due à la courbure de la Terre reste de l'ordre de 0,2 %.
5. **Blocs de 64 × 64 cases** générés autour de la caméra (rayon 160 à 460 m selon le zoom), libérés quand on s'éloigne. Les cases identiques voisines sont fusionnées pour garder peu de triangles.
6. **Hauteurs arrondies à 0,5 m** : donne des plateaux plats constructibles et des marches nettes, façon blocs.
7. **Modifications du joueur** : dictionnaire creux `case -> hauteur`. Seules les cases modifiées sont sauvegardées (`user://terre_save.json`).

### Pourquoi pas une seule grille pour toute la planète ?

Une grille de carrés parfaits ne peut pas recouvrir une sphère sans se déformer (pensez à une carte du monde où le Groenland paraît énorme). Le jeu travaille donc par **régions** : partout sur Terre on peut ouvrir une région, et à l'intérieur les cases font vraiment 1 m × 1 m. C'est ce que font la plupart des jeux sur carte réelle.

## Limites connues

- La mer est « tout ce qui est sous 0 m » : les polders des Pays-Bas sont inondés, et les lacs en altitude ne sont pas encore de l'eau.
- Les bâtiments, la tour Eiffel ou les arbres ne sont pas dans ces données (c'est le sol nu, parfois bruité en ville).
- Le jeu télécharge les tuiles depuis Internet la première fois. Pour une version Steam, il faudra soit embarquer des régions pré-téléchargées, soit garder ce téléchargement avec un écran de chargement.

## Prochaines étapes possibles

| Étape | Données | Licence |
| --- | --- | --- |
| Vraies routes, bâtiments, rivières, lacs, forêts | OpenStreetMap (via Overpass ou des extraits Geofabrik) | ODbL : attribution et partage des données modifiées |
| Relief vraiment au mètre en France | IGN RGE ALTI 1 m | Licence Ouverte Etalab 2.0 |
| Relief au mètre en Suisse | swisstopo swissALTI3D (0,5 m) | Libre, attribution |
| Recherche d'un lieu par son nom | Nominatim (OpenStreetMap) | Usage limité, attribution |
| Relier le mode Terre au city builder | Routes et zonage posés sur le relief réel | — |
| Très grandes distances | « Origine flottante » : recentrer le monde quand la caméra s'éloigne | — |
