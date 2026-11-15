# Export Windows

Le jeu exporté tient en deux fichiers, `MiniBlocs.exe` et `MiniBlocs.pck`, posés dans `Documents\MiniBlocs`. Double-clic sur `MiniBlocs.exe` : pas besoin de Godot. Les sauvegardes restent dans `%APPDATA%\Godot\app_userdata\MiniBlocs`, un réexport ne les touche pas.

## Refaire l'export à la main

```
powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\MiniBlocs\source\tools\export\exporter_windows.ps1"
```

(La première fois, lance-le depuis ton dossier du dépôt : `tools\export\exporter_windows.ps1`.)

Le script :

1. tient à jour une copie du dépôt réservée à l'export (`%LOCALAPPDATA%\MiniBlocs\source`) sur `origin/main` ; ton dossier de travail n'est jamais modifié ;
2. écrit `build_info.json` : version `0.1.<nombre de commits>`, commit, date et heure ;
3. importe les ressources puis exporte avec le preset **Windows Desktop** de `export_presets.cfg` ;
4. remplace `MiniBlocs.exe`, `MiniBlocs.pck` et `build_info.json` dans `Documents\MiniBlocs` (ferme le jeu avant).

Options : `-SiChangement` (n'exporte que si `main` a bougé), `-Branche <nom>` (tester une branche), `-Destination <dossier>`, `-Godot <chemin du Godot_..._console.exe>` (ou la variable `MINIBLOCS_GODOT`). Journal : `%LOCALAPPDATA%\MiniBlocs\export.log`.

## Modèles d'export

Avec les modèles d'export officiels installés (`%APPDATA%\Godot\export_templates\4.7.2.stable`, via Godot → Éditeur → Gérer les modèles d'export), le script fait un vrai export release. Sans eux, il exporte seulement le `.pck` et copie le moteur Godot à côté sous le nom `MiniBlocs.exe` : Godot charge tout seul le `.pck` qui porte le même nom que l'exécutable, le jeu se lance pareil, l'exécutable est juste plus gros.

## Réexport automatique quand main change

```
powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\MiniBlocs\source\tools\export\installer_tache.ps1"
```

crée la tâche planifiée Windows **MiniBlocs - export** : toutes les 30 minutes et à l'ouverture de session, elle lance l'export avec `-SiChangement`. `-Retirer` la supprime.

## Version sur l'écran titre

`scripts/menu/version_build.gd` lit `res://build_info.json` (inclus dans l'export par le preset) et le menu principal affiche en bas à gauche, par exemple « Version 0.1.450 (a9cae94) · build du 15.11.2026 à 12:40 · Godot 4.7.2 ». Lancé depuis l'éditeur, il affiche « dev ». Test : `godot --headless --path . --script res://tests/version_build_test.gd`.
