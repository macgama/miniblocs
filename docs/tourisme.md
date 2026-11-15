# Tourisme

Des touristes viennent dormir en ville, visitent les parcs de loisirs, les zoos,
les musées, les salles de spectacle et le patrimoine, et dépensent dans les
hébergements, les restaurants, les commerces et les boutiques de souvenirs.

Menu : barre du bas → **Loisirs ▴ → Tourisme**, ou **Maj+D**.
Bâtiments : **Construire (B) → Hôtels et tourisme**, ou l'onglet Bâtir du menu.

## Bâtiments (`scripts/tourisme/tourisme_types.gd`)

| Bâtiment | Étoiles | Lits | Nuit / personne | Particularités |
|---|---|---|---|---|
| Aire de camping-cars | 1 | 60 | 7 € | municipale |
| Camping municipal | 2 | 210 | 12 € | municipal, avril–octobre |
| Camping-club avec piscine | 4 | 525 | 24 € | piscine, restaurant, animation, avril–octobre |
| Gîte rural | 3 | 6 | 38 € | cuisine (courses en ville) |
| Chambres d'hôtes | 3 | 10 | 52 € | table d'hôtes |
| Auberge de jeunesse | 1 | 120 | 26 € | dortoirs |
| Hôtel du Commerce | 2 | 48 | 45 € | |
| Hôtel-restaurant | 3 | 120 | 70 € | restaurant |
| Grand hôtel et spa | 4 | 240 | 125 € | restaurant, piscine sur le toit, spa |
| Palace | 5 | 320 | 290 € | restaurant, piscine, spa |
| Résidence de tourisme | 3 | 200 | 36 € | appartements avec cuisine, piscine |
| Village vacances | 3 | 560 | 62 € | pension complète, piscine, animation, avril–octobre |
| Office de tourisme | | | | +10 % de touristes (deux au plus), séjours plus longs |
| Boutique de souvenirs | | | | les touristes y dépensent ~9 € par jour |
| Parking d'autocars | | | | voyages organisés (50 personnes par car), 20 € par car pour la ville |

Les hôtels de la bible (motel, hôtel de chaîne, auberge de montagne, ryokan,
palace Belle Époque, tour hôtelière) sont aussi des hébergements (`AUTRES`).
Tout bâtiment de rôle « hotel » est reconnu (2 étoiles par défaut).

Nouveaux métiers : réceptionniste, valet·femme de chambre, animateur·rice de
vacances, conseiller·ère en séjour.

## Nature : plages, lacs, forêts, sommets (tourisme v2)

La nature des environs attire aussi les touristes. Rien à poser : le jeu la trouve
tout seul dans le **vrai terrain** autour de chaque village (`scripts/tourisme/sites_naturels.gd`,
`SitesNaturels`) : relief réel (les tuiles d'altitude de l'horizon, ~38 m) et biomes
ESA WorldCover, sur une grille de 200 m dans un rayon de 6 km. Le relevé est refait
tous les 30 jours de jeu, quand un village est fondé, et tant que les données ne sont
pas toutes téléchargées. Il prend ~50 à 150 ms.

| Site | Comment il est trouvé | Saison |
|---|---|---|
| Plage | terre basse (moins de 14 m) au bord de la mer | très forte l'été (×1,9 en août, ×0,1 l'hiver) |
| Côte et falaises | terre haute au bord de la mer | toute l'année, plus l'été |
| Lac | eau douce (WorldCover 80) | l'été |
| Rivière | eau longue et étroite (moins de 500 m de large) | l'été |
| Forêt | forêt de 120 ha au moins | toute l'année, l'automne surtout |
| Sommet | point le plus haut à 1 km à la ronde, qui domine de 220 m au moins | l'été |
| Glacier | glace permanente (WorldCover 70) | toute l'année |
| Zone humide | marais, mangrove de 24 ha au moins | printemps |

La mer, c'est l'eau à 0 m qui touche le bord du relevé et fait plus de 600 ha (ou tout
ce qui est sous −1 m) : un étang côtier reste un lac. Au plus 3 sites par genre et 14
par village ; leurs noms (« Plage des Mouettes », « Mont Chauve »…) sont stables.

L'attrait d'un site naturel (ses points) = taille × saison × météo (la pluie vide les
plages) × aménagements × sentiers × accès, moins la pollution de l'eau (carte N) :

- **Accès** : une route à moins de 800 m, sinon ×0,35 (« Dommage qu'aucune route n'y mène »).
- **Sentiers** : chaque km de voie « chemin » (outil Chemin) à moins de 700 m du site :
  +15 % (5 km au plus) et +0,3 ★ dès 1 km.
- **Aménagements** (Construire → Hôtels et tourisme, ou Maj+D → Bâtir → Nature), pour le
  site du bon genre le plus proche :

| Bâtiment | Sites | Effet |
|---|---|---|
| Poste de secours (plage surveillée) | plage, lac | ×1,7, +0,5 ★, de juin à septembre (3 maîtres-nageurs) |
| Base nautique | plage, lac, rivière, côte | ×1,6, +0,4 ★, la ville touche 3 € par visiteur (avril–octobre) |
| Belvédère (point de vue) | sommet, côte, lac, glacier, forêt | ×1,35, +0,4 ★ |
| Parking de randonnée | forêt, sommet, lac, rivière, glacier, zone humide, côte | ×1,3, rend le site accessible (jusqu'à 2,5 km) |
| Maison de la nature | forêt, zone humide, lac, rivière | ×1,5, +0,5 ★ |
| Refuge de montagne | | hébergement de 40 lits (24 €, juin–septembre) |

Les touristes en parlent (« Un canard a volé mon sandwich, sans aucun remords »), la
variété compte (la nature est un genre de visite de plus : +12 %), le menu Tourisme →
Attractions liste la nature des environs (taille, accès, sentiers, aménagements,
visiteurs attendus ; clic : y aller) et les conseils proposent l'aménagement qui manque.

**À voir** : des baigneurs allongés sous leurs parasols sur le sable des plages, des
promeneurs sur les rives des lacs, en forêt et sur les sommets (selon les visites du
jour, de 9 h à 20 h, près de la caméra).

### Autocars sur les routes

Les voyages organisés (parking d'autocars) roulent vraiment : chaque matin (8 h à 12 h),
des autocars de tourisme partent de l'**entrée de la ville** (le bout de route le plus loin
du parking), déposent leur groupe au parking, l'emmènent voir un des sites les plus
attirants (plage, lac, musée…) puis repartent. Six au plus en même temps.

## Simulation (`scripts/tourisme/tourisme.gd`, nœud `Tourisme`, `Tourisme.instance`)

Une fois par jour de jeu :

1. **Sites** : chaque parc de loisirs, zoo, musée, salle de spectacle, monument
   ou lieu de culte de la bible donne des points d'attrait selon sa taille et sa
   note, ainsi que chaque site naturel. +12 % par genre de visite en plus (parc, zoo,
   musée, nature…).
2. **Départs** du matin : l'avis des partants fait bouger la **réputation**
   (0 à 5 étoiles, 3 au départ).
3. **Arrivées** : attrait × 14 × saison (×1,7 en août, ×0,45 en janvier) × jour
   (vendredi ×1,5) × réputation × accès (routes 0,75 ; gare +0,2 ; aéroport
   +0,35 ; port +0,1 ; autocars +0,08) × office de tourisme × publicité. Ils
   choisissent un hébergement selon la note, le rapport qualité-prix, la
   distance aux sites et la saison (camping l'été) ; sans lit libre, un sur
   trois abandonne puis les autres essaient ailleurs ; le reste est **refusé**.
4. **Séjour** : de 1 à 9 nuits (plus long en camping, résidence, village
   vacances, l'été, avec un office de tourisme et des visites variées).
5. **Journée** de chaque client : nuitée (prix réglable), **taxe de séjour**
   (0,50 € à 4 € selon les étoiles) pour la ville, 1,4 repas dehors (moins avec
   un restaurant à l'hôtel) dans les cafés et restaurants, des courses dans les
   commerces (plus avec une cuisine), des souvenirs, 1,3 visite vers les sites
   proches (moins sous la pluie).
6. **Comptes** : un hébergement privé paie ses salaires et ses charges (22 % de
   la nuitée) et verse l'impôt sur les bénéfices à la ville ; le camping
   municipal et l'aire de camping-cars encaissent et paient pour la ville.

Les visites des clients s'ajoutent aux touristes à la journée de chaque système
par `Tourisme.visites(kind, key)` : `Musee.attendus`, `ParcLoisirs.attendus`,
`ZooSysteme.attendus`, `Spectacles.demande` et `demande_cinema`.

Repas et courses passent par l'économie : `Production.repas_touristes(pos, n)`
(cafés et restaurants, en plus de leurs clients habituels, avec leurs stocks) et
`Production.achats_touristes(pos, panier)` (commerces les plus proches ; la
demande des touristes compte pour les livraisons).

Avis des habitants (thème Commerces) : « Les touristes font marcher les
commerces » ; plus de touristes que 60 % des habitants agace.

Statistiques (Maj+I) : « Touristes en ville » et « Nuitées de la veille ».

Section de sauvegarde : `tourisme`.

## Menu (`tourisme_panel.gd`)

En bref, Hébergements (prix, fermer/rouvrir, comptes, personnel), Attractions
(sites et visites attendues), Publicité (salon 15 k€, régionale 45 k€, nationale
220 k€, internationale 900 k€), Bâtir, Avis des touristes.

## Tests

- `tests/tourisme_test.gd` (headless).
- `tests/tourisme_nature_test.gd` (headless) : sites trouvés dans une grille (plage,
  falaises, lac, rivière, forêt, sommet), puis dans une scène (lac, forêt), saisons,
  accès, sentiers, aménagements, locations, promeneurs, autocars, panneau.
- Captures sur le vrai terrain (réseau nécessaire) : `tests/tourisme_nature_vitrine.gd -- --vue plage|autocars|panneau [--lieu lat,lon]`
  (Biarritz par défaut).
- Captures : `tests/tourisme_vitrine.gd -- --vue batiments|rue|plein_air|panneau|hebergements`
  (avec affichage, par exemple `xvfb-run godot --rendering-driver opengl3 …`).
