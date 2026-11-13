# Quoi de neuf (nuit du 11 au 12 novembre 2026)

Tout est dans `main`, et les 9 tests automatiques passent (`sh tests/tous.sh`).

## Nouveautés

**Agriculture et nourriture** (touche **Maj+F**)
- Fermes à la façon des jeux de gestion agricole : champs tracés librement, 14 cultures selon la saison et le climat, labour, semis, engrais, moisson et bottes de paille faits par les ouvriers avec des machines visibles (achetées ou louées, gazole, usure, pannes), 7 espèces de bêtes au pré. Les habitants mangent chaque jour : sans nourriture, santé et satisfaction baissent puis ils déménagent (voir docs/agriculture.md).

**Le monde**
- Décors (touche **G**) : 160 modèles Blender (mobilier urbain, clôtures, marché, jeux, plage, ferme, animaux, bateaux et pontons, rochers). Ils viennent seuls autour de ce que le joueur construit (poteaux et balises le long des routes, bancs en ville, pontons et barques au bord des lacs près des bâtiments ; la Terre reste vierge ailleurs) et se posent à la main, en rangée ou au pinceau (voir docs/decors.md).
- Saisons et âges des plantes : feuillage d'automne et arbres nus l'hiver selon le vrai calendrier du lieu, neige qui tient selon la météo, champs semés, mûrs puis moissonnés, et 4 âges des arbres (jeune pousse, jeune arbre, adulte, arbre mort qui laisse repousser une pousse) au rythme de la vie des habitants (réglage Admin « vitesse de la vie ») (voir docs/plantes-et-sols.md).
- Plantes et textures du sol : 46 plantes low-poly faites dans Blender (arbres, arbustes, fleurs, cultures, rochers) selon le biome et le climat, sols texturés et champs en patchwork (voir docs/plantes-et-sols.md).
- Rivières, ruisseaux et lacs avec de l'eau animée, et des ponts au-dessus (#21). Région jouable de 40 × 40 km, les rivières se chargent autour de la caméra (#26).
- Mer et côtes : houle, ressac et plages de sable (#29).
- Paysage (outil **0**) : collines, lissage, lacs et canaux, peinture de biomes, plantation et arrachage d'arbres au pinceau (#24).
- Ambiance : jour et nuit, vrais Soleil et Lune, lampadaires et fenêtres allumées (#14). Météo selon le climat réel et heure locale du lieu (#18).

**Événements** (touche **I**)
- Marchés du samedi, fêtes de quartier, matchs dans les 11 stades avec des clubs inventés, incendies qui se propagent, tempêtes (arbres tombés, toits, coupures, crues) et épidémies, avec un fil d'actualité cliquable en haut de l'écran (voir docs/evenements.md).

**Transports**
- Carrefours (outil **J**) : feux, stop, cédez-le-passage, priorité à droite (#25). **Maj + clic** les transforme en giratoire (#27).
- Transports publics (touche **L**) : arrêts de bus et de tram, gares, ports, aéroports et lignes (#17). Parkings (#28).
- Fret : camions, trains et bateaux de marchandises (#30). Catalogue de 131 véhicules de toutes époques et régions (#13).

**Bâtiments**
- 15 styles de plus, des espaces publics, et « Mes créations » : ce que tu bâtis dans l'éditeur libre devient un bâtiment réutilisable (#22).

**Avis des habitants et élections** (touche **Y**)
- La satisfaction est notée par thème (emploi, logement, écoles et santé, sécurité, environnement, transports, impôts, réseaux, loisirs, commerces), par quartier avec une carte de couleur, et des habitants disent ce qui ne va pas. Dès 30 habitants tu es maire : municipales tous les 6 ans de vie, campagne avec 3 promesses, listes adverses menées par des habitants, 2e tour si besoin. Les mécontents manifestent devant la mairie : négocier, ignorer (grève à la 2e fois) ou envoyer la police (voir docs/avis.md).

**Les habitants au travail** (touche **K**)
- On voit les métiers : en zoomant, les commerces, écoles, hôpitaux et usines s'ouvrent en coupe. Le boulanger pétrit, l'enseignant écrit au tableau devant ses élèves, le médecin ausculte. Il y a 56 gestes avec outils et postes de travail, et les nouveaux métiers reçoivent des gestes tout seuls. Les métiers d'extérieur se voient dehors. Les bâtiments ont une enseigne Ouvert / Fermé, un rideau de fer et une pancarte « Manque de personnel ». Sans personnel, l'école ferme et les élèves restent à la maison, les clients vont ailleurs et l'hôpital ne soigne plus (voir docs/metiers.md).

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
