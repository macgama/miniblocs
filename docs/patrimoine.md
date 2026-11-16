# Patrimoine et grands monuments

Classer les bâtiments historiques de la ville et bâtir de grands monuments sur
plusieurs années, qui font venir les touristes.

Menu : barre du bas → **Loisirs ▴ → Patrimoine**, ou la touche **Fin**.
Monuments : **Construire (B) → Patrimoine et grands monuments**, ou l'onglet
Bâtir du menu.

## Grands monuments (`scripts/patrimoine/monuments_types.gd`)

Des modèles originaux, inspirés des grands styles de chaque époque (aucune copie
d'un monument réel). Chacun a son année d'apparition (verrou d'époque), sa durée
réelle de travaux, son équipe, ses étapes propres et ses matériaux.

| Monument | Dès | Travaux d'époque | Ouvriers | Prix | Attrait |
|---|---|---|---|---|---|
| Grande cathédrale gothique (92 m) | toujours | 40 ans | 140 | 90 M€ | 6 |
| Basilique à coupole | toujours | 25 ans | 110 | 70 M€ | 5 |
| Grande mosquée à coupoles | toujours | 12 ans | 120 | 60 M€ | 5 |
| Pagode à neuf étages | toujours | 8 ans | 60 | 18 M€ | 3 |
| Palais de verre et de fonte | 1851 | 1 an | 220 | 40 M€ | 4 |
| Grand opéra | 1861 | 14 ans | 120 | 75 M€ | 5 |
| Statue colossale du Génie | 1884 | 9 ans | 70 | 22 M€ | 4 |
| Tour de fer de 240 m | 1887 | 2,2 ans | 250 | 55 M€ | 8 |
| Grand barrage hydroélectrique (350 MW) | 1905 | 7 ans | 300 | 180 M€ | 1,6 |
| Gratte-ciel Art déco (378 m) | 1930 | 1,6 an | 400 | 160 M€ | 4 |
| Tour de télévision (267 m) | 1965 | 4 ans | 90 | 38 M€ | 3,5 |
| Arche de la Fraternité | 1985 | 7 ans | 200 | 120 M€ | 4 |
| Tour-flèche de 600 m | 2008 | 6 ans | 500 | 600 M€ | 7 |

- **Durée** : comme tous les chantiers (`Chantiers`), la durée réelle est divisée
  par la vitesse de la vie (×12) et le rythme des chantiers (×3 par défaut, Admin) :
  la cathédrale prend environ 13 mois de jeu, la tour de fer 3 semaines. Les
  monuments échappent au plafond de 4 ans des bâtiments ordinaires
  (`Chantiers.mois_batiment`, `equipe_batiment`).
- **Étapes** : `Chantiers.etapes_batiment(id)` ; une cathédrale passe par le
  terrassement, les fondations et la crypte, le chœur, la nef, les voûtes et
  arcs-boutants, la façade et les tours, la flèche, les vitraux. À l'écran
  (`BatimentsVie._show_etape`, `MonumentsTypes.visuel`), le monument monte d'un
  bout à l'autre derrière ses échafaudages et sa grue ; le panneau de chantier
  montre l'étape du monument.
- **Matériaux** (PR #170) : chaque monument a sa liste en tonnes
  (`MateriauxChantiers.besoins_batiment`), prise dans les stocks de la carte.
- **Barrage** : produit 350 MW (réseau électrique) ; une rivière doit passer à
  moins de 220 m.
- Le prix se paie au fil des travaux ; caisse vide = chantier arrêté.

### Souscription, mécènes, curieux

- **Souscription populaire** (onglet Grands chantiers) : chaque jour, les
  habitants donnent ~8 € chacun (plus si la ville est contente, sondage des
  Avis), jusqu'à 25 % du prix ; les dons diminuent ce que la ville doit payer.
- **Mécènes** : de temps en temps, un mécène offre 1 à 4 % du prix (plus souvent
  pour un chantier prestigieux).
- **Curieux** : le chantier est déjà un site touristique (« Chantier de… »), de
  plus en plus attirant à mesure qu'il monte.
- **Inauguration** : fini, le monument est classé monument historique d'office ;
  la gazette en parle.

## Classement (`scripts/patrimoine/patrimoine.gd`, nœud `Patrimoine`)

**Intérêt patrimonial** d'un bâtiment :

- édifice remarquable (monument, lieu de culte, palais, château, théâtre, phare,
  gare, moulin, halle…) : +1,2 ;
- architecture d'autrefois (style traditionnel : +0,6, classique : +0,4,
  bâtiment du XIXe siècle : +0,5), moitié moins s'il a moins de 30 ans ;
- âge, en années de l'histoire (`Epoques`) : +1 par 50 ans (2 au plus).

| Protection | Intérêt | Dossier | Attrait | Abords | Entretien par an | Part de l'État | Aide à la restauration |
|---|---|---|---|---|---|---|---|
| Inscrit au patrimoine | 1 | 15 k€ | ×1,3 | 100 m, 45 m de haut | 0,12 % de la valeur | 30 % | 25 % |
| Classé monument historique | 2 | 40 k€ | ×1,7 | 200 m, 30 m de haut | 0,25 % de la valeur | 50 % | 40 % |

- **Protection** : pas de démolition (il faut déclasser d'abord), pas
  d'agrandissement ni de densification (`Ameliorations`).
- **Abords** (`BuildingSystem.extra_check`) : pas de bâtiment plus haut que la
  limite, ni d'usine ou d'installation de déchets ; la règle s'affiche à la pose.
  Elle peut être coupée (En bref → Règles des abords).
- **Entretien** : entretenu, le monument s'use trois fois moins vite
  (`BatimentsVie.extra_usure`) ; sans entretien, il s'use plus vite et attire
  moins. La restauration passe par le chantier de rénovation
  (`Ameliorations.renover`), en partie payé par l'État.
- **Journées du patrimoine** : le troisième week-end de septembre, les monuments
  attirent ×1,8.

## Tourisme

`Tourisme._maj_sites` demande à `Patrimoine.points_site(bid)` les points de
chaque site « patrimoine » : grands monuments (prestige, ou un quart en
chantier), monuments, châteaux et lieux de culte de la bible, bâtiments protégés ;
× bonus de protection × état (usure) × Journées du patrimoine. La note des
visiteurs suit la protection et l'état. Le **rayonnement** (En bref) est la somme
de ces points (1 point ≈ 14 touristes par jour).

## Menu (`patrimoine_panel.gd`)

En bref (rayonnement, monuments, argent de l'année, Journées du patrimoine,
règles des abords, conseils), Grands chantiers (étape, avancement, fin prévue,
reste à payer, souscription, mécènes, Voir), Classement (intérêt, âge, état,
attrait ; Inscrire, Classer, Entretien, Restaurer, Déclasser, Voir), Bâtir un
monument (les 13, avec leur durée dans le jeu ; verrouillés avant leur époque).

Édition démo : le menu et la catégorie Construire sont réservés au jeu complet.

Section de sauvegarde : `patrimoine` (protections, années de construction,
souscriptions, règles des abords, comptes de l'année).

## Tests

- `tests/patrimoine_test.gd` (headless) : catalogue, durées, étapes, matériaux,
  chantier, curieux, souscription, inauguration, démolition interdite, abords,
  classement d'une église (frais, âge, agrandissement refusé, entretien, usure),
  tourisme, Journées du patrimoine, sauvegarde, panneau.
- Captures : `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/patrimoine_vitrine.gd -- --vue anciens|modernes|chantier|panneau|chantiers|monument [--id tour_fer] --screenshot p.png`.
