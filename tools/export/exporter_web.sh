#!/bin/sh
# Démo jouable dans le navigateur (piste CityRT 12) : exporte le préréglage
# « Web Demo » dans build/web/ (index.html + .wasm + .pck, ~95 Mo).
# Il faut les modèles d'export Web de Godot 4.7 (Éditeur → Gérer les modèles d'export).
# Essai local : python3 -m http.server 8000 -d build/web  puis http://localhost:8000
set -e
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web Demo" build/web/index.html
ls -la build/web
