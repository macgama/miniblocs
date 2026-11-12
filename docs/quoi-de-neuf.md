# Quoi de neuf (nuit du 11 au 12 novembre 2026)

Tout est dans `main`, et les 9 tests automatiques passent (`sh tests/tous.sh`).

## Nouveautés

**Le monde**
- Saisons et âges des plantes : feuillage d'automne et arbres nus l'hiver selon le vrai calendrier du lieu, neige qui tient selon la météo, champs semés, mûrs puis moissonnés, et 4 âges des arbres (jeune pousse, jeune arbre, adulte, arbre mort qui laisse repousser une pousse) au vrai rythme (voir docs/plantes-et-sols.md).
- Plantes et textures du sol : 46 plantes low-poly faites dans Blender (arbres, arbustes, fleurs, cultures, rochers) selon le biome et le climat, sols texturés et champs en patchwork (voir docs/plantes-et-sols.md).
- Rivières, ruisseaux et lacs avec de l'eau animée, et des ponts au-dessus (#21). Région jouable de 40 × 40 km, les rivières se chargent autour de la caméra (#26).
- Mer et côtes : houle, ressac et plages de sable (#29).
- Paysage (outil **0**) : collines, lissage, lacs et canaux, peinture de biomes, plantation et arrachage d'arbres au pinceau (#24).
- Ambiance : jour et nuit, vrais Soleil et Lune, lampadaires et fenêtres allumées (#14). Météo selon le climat réel et heure locale du lieu (#18).

**Transports**
- Carrefours (outil **J**) : feux, stop, cédez-le-passage, priorité à droite (#25). **Maj + clic** les transforme en giratoire (#27).
- Transports publics (touche **L**) : arrêts de bus et de tram, gares, ports, aéroports et lignes (#17). Parkings (#28).
- Fret : camions, trains et bateaux de marchandises (#30). Catalogue de 131 véhicules de toutes époques et régions (#13).

**Bâtiments**
- 15 styles de plus, des espaces publics, et « Mes créations » : ce que tu bâtis dans l'éditeur libre devient un bâtiment réutilisable (#22).

**Vue au sol** (touche **V**)
- Collisions avec les arbres et les véhicules, et tunnels praticables à pied (#23).

**Le jeu dans son ensemble**
- Menus : bouton **Continuer** sur le globe, plusieurs parties sauvegardées, sauvegarde auto toutes les 5 minutes (#16, #19).
- Aide complète sur **F1**. Plus aucune touche ne déclenche deux actions : **T** met le temps en pause, **L** ouvre les lignes (#19, #31).
- Performances : chargement de la carte nettement plus rapide, et plus de gel quand la ville pousse (#12, #15, #31).

## Comment tester (Godot 4.3 ou plus)

1. Dans GitHub Desktop, fais **Fetch origin** puis **Pull** sur `main`.
2. Ouvre le projet dans Godot et appuie sur **F5**.
3. Choisis un lieu au bord de l'eau sur le globe (par exemple Annecy), puis **Commencer**.
4. Appuie sur **F1** pour voir toutes les commandes.
5. Trace deux routes qui se croisent (**5**), puis clique le carrefour avec l'outil **J**. Avec **Maj + clic**, il devient un giratoire.
6. Pose une maison (**B**), creuse un lac (**0**), puis passe en vue au sol (**V**).
7. Mets le temps en pause avec **T**, et ouvre les lignes avec **L**.
8. Clique **Sauver**, puis **Globe**, puis **Continuer** : ta partie revient telle quelle.

Si quelque chose ne marche pas, dis-moi ce que tu as fait et ce que tu as vu.
