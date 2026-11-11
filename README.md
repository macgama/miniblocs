# MiniBlocs

Prototype de city builder en vue de dessus, style low-poly, mode bac à sable. Fait avec **Godot 4.3** (GDScript), sans aucun asset externe : tous les modèles (maisons, commerces, usines, arbres, routes) sont générés en code.

![Aperçu](docs/apercu.png)

## Lancer le jeu

1. Installe [Godot 4.3 ou plus](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvre Godot, clique sur **Importer** et choisis le fichier `project.godot` de ce dossier.
3. Appuie sur **F5** (ou le bouton ▶) pour lancer.

## Commandes

| Action | Touches |
| --- | --- |
| Déplacer la caméra | ZQSD (WASD en QWERTY) ou flèches, ou clic droit maintenu + glisser |
| Zoomer | Molette |
| Tourner la caméra | A / E (Q / E en QWERTY), ou clic molette maintenu + glisser |
| Construire | Clic gauche maintenu + glisser |
| Choisir un outil | 1 Route · 2 Résidentiel · 3 Commercial · 4 Industriel · 5 Bulldozer |
| Annuler le tracé en cours | Échap |
| Sauvegarder / charger | F5 / F9 (ou les boutons en bas) |

## Comment ça marche

- **Routes** : se tracent en L entre le point de départ et la souris. Le marquage s'adapte aux routes voisines (lignes droites, virages, carrefours).
- **Zones** : se peignent en rectangle. Une zone ne recouvre jamais une route.
- **Croissance** : les bâtiments poussent tout seuls sur les cases zonées situées à 2 cases maximum d'une route, orientés vers celle-ci.
- **Statistiques** : habitants (4 par maison) et emplois (3 par commerce, 6 par usine), affichés en haut à gauche.
- **Sauvegarde** : un fichier JSON dans le dossier utilisateur de Godot (`user://miniblocs_save.json`).

## Organisation du code

| Fichier | Rôle |
| --- | --- |
| `scenes/main.tscn` | Scène principale : lumière, ciel, caméra, ville, interface |
| `scripts/main.gd` | Relie l'interface à la ville |
| `scripts/camera_rig.gd` | Caméra de gestion (déplacement, zoom, rotation) |
| `scripts/city_grid.gd` | Grille, outils de pose, croissance, sauvegarde |
| `scripts/low_poly.gd` | Fabrique des modèles low-poly |
| `scripts/ground_grid.gdshader` | Sol herbeux quadrillé |
| `scripts/hud.gd` | Barre d'outils, statistiques, aide |
| `tests/smoke_test.gd` | Test automatique de bout en bout |

## Test automatique

```bash
godot --headless --path . --script res://tests/smoke_test.gd
```

Le test pose des routes et des zones, attend la croissance, puis vérifie la sauvegarde, le chargement et le bulldozer. Il affiche `SMOKE TEST OK` si tout va bien.

## Pistes pour la suite

- Remplacer les modèles générés par des packs CC0 (Kenney City Kit, Quaternius) en gardant la même logique.
- Besoins entre zones (les habitants ont besoin d'emplois et de commerces), argent et budget.
- Services : électricité, eau, parcs.
- Petites voitures sur les routes.
