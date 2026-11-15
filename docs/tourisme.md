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

## Simulation (`scripts/tourisme/tourisme.gd`, nœud `Tourisme`, `Tourisme.instance`)

Une fois par jour de jeu :

1. **Sites** : chaque parc de loisirs, zoo, musée, salle de spectacle, monument
   ou lieu de culte de la bible donne des points d'attrait selon sa taille et sa
   note. +12 % par genre de visite en plus (parc, zoo, musée…).
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
- Captures : `tests/tourisme_vitrine.gd -- --vue batiments|rue|plein_air|panneau|hebergements`
  (avec affichage, par exemple `xvfb-run godot --rendering-driver opengl3 …`).
