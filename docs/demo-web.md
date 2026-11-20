# Démo jouable dans le navigateur (piste CityRT 12)

La même démo que celle du Steam Next Fest (`EditionDemo` : 120 jours, 1 000 habitants,
pas de parc, zoo, multijoueur…), mais lancée dans une page web, sans rien installer.

## Exporter

- Dans Godot 4.7 : **Projet → Exporter… → « Web Demo » → Exporter le projet**, dossier `build/web/`.
  La première fois, Godot propose de télécharger les modèles d'export (Web compris).
- Ou en ligne de commande : `sh tools/export/exporter_web.sh`.

Le préréglage utilise :
- le rendu **Compatibilité** (WebGL 2), réglé dans `project.godot` par
  `rendering/renderer/rendering_method.web` : le PC garde Forward+ ;
- la variante **sans fils d'exécution** (`thread_support=false`) : pas besoin des
  en-têtes COOP/COEP, la page marche chez n'importe quel hébergeur (Infomaniak, itch.io) ;
- la fonctionnalité `demo` : limites de la démo, bouton « Liste de souhaits ».

Taille : ~95 Mo (40 Mo de moteur `.wasm`, 55 Mo de jeu `.pck`). Le serveur doit envoyer
les `.wasm` avec le type `application/wasm` (Infomaniak le fait) ; la compression gzip
ou brotli des `.wasm` et `.pck` divise le téléchargement par 3 à 4.

## Essayer chez soi

```
python3 -m http.server 8000 -d build/web
```
puis ouvrir http://localhost:8000 dans Chrome, Edge ou Firefox (un double-clic sur
`index.html` ne marche pas : les navigateurs bloquent le `.wasm` en `file://`).

## Mettre en ligne sur manigames.online

Copier le contenu de `build/web/` dans un dossier du site, par exemple `demo/`
(gestionnaire FTP d'Infomaniak), et faire un lien vers `https://www.manigames.online/demo/`.
itch.io accepte aussi le dossier zippé (« HTML5 », cocher « SharedArrayBuffer » n'est pas utile).

## Ce qui change dans le navigateur

- Pas de bouton « Quitter » (on ferme l'onglet).
- Sauvegardes dans le stockage du navigateur (IndexedDB) : elles restent sur ce
  navigateur, sur cet ordinateur.
- Pas de rapport de plantage en arrière-plan (pas de fils d'exécution).
- WebGL limite les paramètres par objet : chaque habitant reçoit son propre matériau
  et les champs gardent la teinte commune des plantes.
- Polices de secours embarquées (`assets/polices`) : flèches, ♥, ☆ et chinois
  s'affichent sans police du système.
- Le relief réel est téléchargé comme sur PC (tuiles AWS, autorisées depuis une page web).
