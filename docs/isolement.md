# Bâtiment isolé au clic

Demande de Gaël (2026-11-21) : quand on clique sur un bâtiment, ne voir que lui pour ne pas surcharger l'écran.

## Ce que voit le joueur

Outil Observer (touche 1), clic sur un bâtiment :

- la caméra glisse vers le bâtiment et le cadre, un peu à gauche du centre (la fiche occupe la droite) ;
- le reste de la ville pâlit : voile gris clair à l'écran, troué autour du bâtiment, et bâtiments voisins transparents (fantômes, sans ombre) ;
- les cartes d'information (objectifs, fil des habitants, À faire, case, jauges, mini-carte) se rangent ; restent la barre du haut, la barre du bas et la fiche du bâtiment (les questions du personnage restent, elles arrêtent le temps) ;
- un clic sur un autre bâtiment passe directement à celui-ci.

Pour sortir, tout revient comme avant (caméra, cartes, bâtiments) :

- **Échap** : ferme la fiche et rétablit tout (sans ouvrir le menu pause) ;
- **✕ de la fiche**, clic sur un terrain libre, ou passage à une autre vue du panneau ;
- **« Toute la ville »** dans la fiche : la ville revient, la fiche reste ; **« Isoler »** y retourne.

Option : Options → Jeu → « Isoler le bâtiment cliqué » (activée par défaut).

## Code

- `scripts/interface/isolement_batiment.gd` (`IsolementBatiment`, posé par `terre_main._setup_isolement()`, accessible par `terre_main.isolement`).
- Rangement temporaire des cartes : `AffichagePanneaux.ranger(on, garder)` ; ne touche pas au choix du joueur (`masques`, user://interface.cfg).
- Caméra : `CameraRig.etat()`, `cadrer(pos, dist, pitch)`, `retablir(etat)`.
- Pas d'isolement à l'Atelier ni en vue au sol (`peut_isoler`).

## Pour la gestion d'un bâtiment (mini-jeu façon tycoon)

Écouter `isolement.entree(bid)` / `isolement.sortie(bid)`, ou appeler `isolement.entrer(bid)` / `isolement.sortir()`.
Le cadrage et la ville pâlie servent de décor d'entrée.

## Test

`godot --headless --path . --script res://tests/isolement_test.gd` (avec affichage et `-- --dossier <chemin>` : captures).
