# MiniBlocs — Document de game design (v0.1)

> Jeu de gestion en bac à sable pour Steam. Développeur solo, budget zéro, moteur Godot 4, vue de dessus, style low-poly.
> Statut : brouillon de travail, à faire évoluer avec le prototype.

---

## 1. Le concept en une phrase

**Construis une petite ville en blocs, puis offre-lui un parc qui la fait vivre : plus la ville grandit, plus le parc attire de monde, et plus le parc rapporte, plus la ville peut grandir.**

Ce qui distingue MiniBlocs :
- **Deux échelles qui se nourrissent** : la ville produit des habitants (visiteurs, employés, argent), le parc produit de l'attractivité (tourisme, bonheur, emplois). On ne joue pas deux jeux côte à côte, on joue un seul système.
- **Tout est fait de blocs** sur une grille simple, lisible d'un coup d'œil, avec un rendu low-poly chaleureux. Le joueur comprend sa ville en la regardant.
- **Bac à sable d'abord** : pas de game over, pas de scénario imposé. Les objectifs sont des envies, pas des obligations.

## 2. Public et sensations visées

- Joueurs de city builders et de tycoons qui aiment optimiser **sans stress**.
- Sessions de 20 minutes à plusieurs heures.
- Sensations clés : *« ça tourne tout seul et c'est beau »*, *« j'ai trouvé une meilleure disposition »*, *« ma ville a son caractère »*.

## 3. Boucle de jeu

### Boucle courte (quelques minutes)
1. **Observer** : survoler la ville, lire les indicateurs (demande de zones, bonheur, trafic, file d'attente au parc).
2. **Décider** : où zoner, quoi construire, quel prix fixer.
3. **Construire** : routes, zones, bâtiments de service, attractions.
4. **Voir le résultat** : les bâtiments poussent, les habitants circulent, l'argent rentre ou sort.

### Boucle moyenne (une session)
- Débloquer un nouveau palier de population → nouveaux bâtiments et attractions.
- Résoudre un goulot d'étranglement (embouteillage, manque d'emplois, parc saturé).
- Agrandir le parc ou ouvrir un nouveau quartier.

### Boucle longue (plusieurs sessions)
- Faire évoluer une petite bourgade en ville touristique reconnue.
- Spécialiser des quartiers, embellir, collectionner les attractions.
- Plus tard : ouvrir un club de sport (extension).

## 4. La ville

### 4.1 Grille et construction
- Grille carrée (1 case = 1 bloc). Bâtiments de 1×1 à 4×4.
- Les routes se tracent case par case (glisser-déposer). Tout bâtiment doit toucher une route.
- Terrain plat au départ ; relief et eau en option plus tard (coûteux à développer).

### 4.2 Zonage
Trois zones de base, peintes au pinceau sur la grille. Le jeu fait pousser les bâtiments selon la demande.

| Zone | Ce qu'elle produit | Ce qu'elle demande |
|---|---|---|
| **Résidentielle** (vert) | Habitants, impôts | Emplois, services, calme |
| **Commerciale** (bleu) | Emplois, impôts, attractivité touristique | Clients (habitants + visiteurs) |
| **Industrielle** (jaune) | Beaucoup d'emplois, marchandises | Accès routier, éloignement des maisons |

- **Barre de demande** (style RCI) : trois jauges indiquent quelle zone la ville réclame.
- **Densité** : chaque zone a 3 niveaux (petite, moyenne, haute), qui montent si le quartier est desservi et apprécié.
- **Nuisances** : l'industrie fait baisser la valeur des terrains autour, le parc et les espaces verts la font monter.

### 4.3 Services (version minimale)
Pour rester réaliste en solo, peu de services, mais chacun lisible :
- **Électricité** (centrale + rayon de couverture simplifié, pas de réseau de câbles).
- **Eau** (château d'eau + rayon).
- **Bonheur** : parc de quartier, école, poste de police — chacun en rayon d'effet.

Pas de déchets, santé, pompiers, transports en commun dans la première version. Ce sont des ajouts possibles plus tard.

### 4.4 Habitants
- Simulation **agrégée** (des chiffres par bâtiment), pas d'agents individuels intelligents.
- Quelques petits personnages et voitures circulent **pour l'ambiance** : ils suivent les routes mais ne pilotent pas la simulation. C'est beaucoup plus simple et plus performant.

## 5. Le parc (parc de loisirs, le zoo en variante)

Recommandation : **commencer par le parc de loisirs**. Les attractions sont des objets fixes faciles à modéliser en low-poly, alors qu'un zoo demande des animaux animés et une simulation de bien-être plus lourde. Le zoo peut venir ensuite comme un « type de parc » réutilisant le même système.

### 5.1 Fonctionnement
- Le parc est une **zone spéciale** clôturée, avec une entrée reliée à la route de la ville.
- À l'intérieur, on pose des **allées**, des **attractions**, des **stands** (nourriture, boissons, souvenirs), des **bancs/toilettes/poubelles**, et de la **décoration**.
- Chaque attraction a : capacité, durée, prix, note d'excitation, coût d'entretien.

### 5.2 Visiteurs
- Les visiteurs ont 3 jauges simples : **envie** (fun), **faim/soif**, **fatigue**. Quand elles sont mauvaises, ils partent.
- Ils viennent de deux sources :
  - **habitants de la ville** (proportion selon leur temps libre et leur bonheur),
  - **touristes** (selon la réputation du parc et l'accès routier).

### 5.3 Note du parc
Une note de 0 à 5 étoiles, calculée à partir de la variété des attractions, de la propreté, des files d'attente et des prix. Elle pilote le nombre de touristes.

## 6. Liens ville ↔ parc (le cœur du jeu)

C'est ce qui rend MiniBlocs différent d'un city builder ou d'un tycoon seuls.

| La ville donne au parc | Le parc donne à la ville |
|---|---|
| Des **visiteurs locaux** (plus la ville est grande et heureuse, plus ils viennent) | Du **bonheur** dans les quartiers proches |
| Des **employés** (un parc sans personnel ferme ses attractions) | Des **touristes** qui dépensent dans les commerces |
| De l'**électricité et de l'eau** | Une hausse de la **valeur foncière** autour |
| Un **accès routier** (embouteillage = moins de visiteurs) | Des **emplois** pour les résidents |

Tensions intéressantes pour le joueur :
- Le parc attire des touristes, mais leurs voitures **saturent les routes** : il faut penser l'accès.
- Le parc rend les quartiers voisins désirables, mais ses **nuisances sonores** gênent ceux qui sont collés à lui.
- Construire le parc trop tôt : pas assez de visiteurs ni d'employés. Trop tard : la ville stagne faute de commerce.

## 7. Économie

### 7.1 Une seule monnaie
La caisse de la ville et la caisse du parc sont **une seule trésorerie**. C'est plus simple à comprendre et ça renforce le lien entre les deux.

### 7.2 Entrées
- Impôts résidentiels, commerciaux, industriels (taux réglable par zone).
- Billets d'entrée du parc et/ou prix par attraction.
- Ventes des stands.
- Taxe de séjour sur les touristes (débloquée plus tard).

### 7.3 Sorties
- Coût de construction (routes, services, attractions).
- Entretien mensuel des services et des attractions.
- Salaires du personnel du parc.

### 7.4 Équilibrage de départ (bac à sable)
- Mode **bac à sable** : argent illimité, tout débloqué, pour construire librement.
- Mode **normal** (plus tard) : budget de départ, paliers de déblocage par population.
- Pas de faillite brutale : en cas de dette, les services ralentissent et la croissance s'arrête, mais rien ne s'effondre.

### 7.5 Paliers de déblocage (mode normal)

| Palier | Population | Débloque |
|---|---|---|
| Hameau | 0 | Routes, zones basse densité, électricité, eau |
| Village | 500 | Moyenne densité, école, petit parc (3 attractions) |
| Bourg | 2 000 | Police, commerces touristiques, attractions moyennes |
| Ville | 8 000 | Haute densité, grandes attractions, taxe de séjour |
| Métropole | 25 000 | Attractions vedettes, décorations rares |

## 8. Direction artistique

- **Low-poly** à couleurs franches, une palette limitée (environ 16 couleurs) partagée par tous les modèles : ça unifie le style et accélère la production.
- Une seule **texture-palette** pour tous les modèles (technique de l'atlas de couleurs) : simple dans Blender, très performant dans Godot.
- Caméra : vue de dessus inclinée (environ 45°), rotation par pas de 90°, zoom.
- Cycle jour/nuit simple (éclairage uniquement) : gros effet visuel pour peu de travail.
- Ressources gratuites possibles pour démarrer : packs CC0 de Kenney ou Quaternius, à remplacer progressivement par des modèles maison.

## 9. Architecture technique (Godot 4)

- **Grille** : un tableau 2D de cellules (type, bâtiment, valeur foncière, couverture des services). C'est la source de vérité.
- **Rendu** : `MultiMeshInstance3D` pour les éléments répétés (routes, arbres, petites maisons) afin de tenir des milliers de blocs.
- **Simulation** : un « tick » toutes les X secondes (pas à chaque image), avec vitesse réglable (pause, ×1, ×2, ×4).
- **Chemins** : `AStarGrid2D` sur la grille des routes pour les voitures d'ambiance et l'accessibilité.
- **Sauvegarde** : sérialiser la grille et la trésorerie en JSON ou en ressource Godot dès le premier prototype (ça évite une réécriture douloureuse plus tard).
- **Données** : bâtiments et attractions décrits dans des fichiers `Resource` (`.tres`) pour ajouter du contenu sans toucher au code.

## 10. Feuille de route réaliste en solo

Estimations pour quelqu'un qui travaille sur son temps libre (environ 10 h par semaine). À ajuster dès les premières étapes.

| Étape | Contenu | Durée estimée |
|---|---|---|
| **0. Fondations** | Projet Godot, caméra, grille, poser/supprimer un bloc, sauvegarde | 3–4 semaines |
| **1. Ville minimale** | Routes, 3 zones, croissance automatique, barre de demande, électricité/eau | 6–8 semaines |
| **2. Économie** | Trésorerie, impôts, entretien, interface de base, vitesse du temps | 3–4 semaines |
| **3. Parc minimal** | Zone parc, allées, 5 attractions, 3 stands, visiteurs avec jauges, note du parc | 8–10 semaines |
| **4. Liens ville ↔ parc** | Visiteurs locaux et touristes, emplois, bonheur, valeur foncière, trafic | 4–6 semaines |
| **5. Version jouable (démo)** | Mode bac à sable complet, tutoriel léger, menus, sons, polissage | 6–8 semaines |
| **6. Accès anticipé** | Mode normal avec paliers, plus de contenu, retours joueurs, page Steam | 3–6 mois |
| **Extension** | Zoo comme type de parc, puis club de sport | Après l'accès anticipé |

**Première version jouable (fin étape 5) : environ 8 à 10 mois.**

Conseils pour tenir la distance :
- Créer la **page Steam tôt** (dès l'étape 3) pour accumuler des listes de souhaits. Les frais Steam Direct (environ 100 $) sont la seule dépense quasi obligatoire.
- Participer à un **Steam Next Fest** avec la démo de l'étape 5.
- Partager des GIFs de la ville qui pousse : c'est le meilleur marketing gratuit pour ce genre.
- Couper sans pitié : si une fonctionnalité dépasse de deux fois son estimation, la simplifier ou la repousser.

## 11. Hors périmètre de la première version

- Simulation individuelle des habitants
- Transports en commun, déchets, santé, pompiers
- Relief, rivières, terraformage
- Multijoueur
- Zoo et club de sport (prévus, mais après)
- Catastrophes

## 12. Questions ouvertes

1. **Taille de carte** : petite (64×64) pour un jeu cosy, ou grande (256×256) pour des villes ambitieuses ? Ça change beaucoup les choix techniques.
2. **Parc unique ou plusieurs parcs** dans la même ville ?
3. **Gestion du personnel du parc** : automatique (simple) ou embauche manuelle (plus tycoon) ?
4. **Quel ton** : réaliste et posé, ou décalé avec de l'humour (noms de commerces, réactions des visiteurs) ?
5. **Club de sport** : stade relié à la ville comme le parc, ou vrai jeu de manager avec équipe et matchs ?
6. **Ton expérience** en Godot et en modélisation 3D (Blender) : ça peut faire varier la feuille de route du simple au double.
