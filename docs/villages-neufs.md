# Villages neufs

La partie test à plusieurs villes ([partie-pays.md](partie-pays.md)) a montré qu'un
village fondé à côté d'une ville grandissait très lentement : 8 à 185 habitants en
40 jours, même sous pilote automatique. Ce qui le freinait :

- **les zones** : à chaque essai de croissance, le jeu prend les zones de la carte une
  par une. Les deux ou trois zones d'un village passaient après les dizaines de zones
  des grandes villes, et la demande de logements était comptée pour toute la carte ;
- **les ouvriers** (partie lancée du globe) : ils vont aux chantiers dans l'ordre où
  ceux-ci ont commencé. La première ville en avait toujours en cours, et la Maison de
  commune du nouveau village attendait des ouvriers pendant des semaines ;
- **le pilote automatique** zonait 40 × 30 m à la fois et s'arrêtait dès que 3 logements
  étaient en chantier. Il bâtissait aussi l'école, la police et le dépôt de collecte dès
  le premier habitant (erreur de calcul), ce qui vidait la caisse du village.

## Ce qui change

Un **village neuf**, c'est un village de moins de 150 foyers (≈ 350 habitants) dans une
partie qui en compte plusieurs (`Communes.est_jeune`, `Communes.JEUNE_FOYERS`). Une
partie avec un seul village ne change pas.

- **Ses zones poussent d'abord** (`ZoneSystem._pousser_villages_neufs`) : à chaque essai
  de croissance, un village neuf, chacun à son tour, tente de faire pousser un bâtiment
  dans ses zones avant le reste de la carte. Les logements y poussent même quand la
  demande de la carte est comblée (des familles viennent toujours s'installer dans un
  village neuf), en **maisons et petits immeubles** (20 logements au plus, pas de tour).
  Commerces et activités suivent la demande comme avant.
- **Des pionniers** (`Fondateurs.envoyer_pionniers`) : quand le joueur fonde un village
  après le premier, une équipe de pionniers arrive pour bâtir ses logements :
  30 % des fondateurs réglés en F10 (30 par défaut, 10 au moins), pendant 60 jours ou
  jusqu'à 150 foyers. Ils ne travaillent que pour ce village, aux logements d'abord. Ce ne
  sont pas des habitants : ni loyer, ni vivres, ni salaire. Le panneau **Maj+H** les
  montre avec les jours qui leur restent.
- **Chaque village a un chantier qui avance** (`Fondateurs.repartir`) : à plusieurs
  villages, le premier chantier de chaque village reçoit son équipe avant les autres.
  La Maison de commune d'un nouveau village démarre tout de suite.
- **Les promoteurs** d'un village neuf peuvent ouvrir un chantier même quand tous les
  ouvriers de la carte sont pris, tant que ses pionniers ont des bras libres, ou qu'il a
  moins de deux chantiers en cours (`Fondateurs.accepte_chantier_prive(vid)`).
- **Pilote automatique** dans un village neuf : il zone dès qu'il manque 10 logements
  d'avance ou que ses zones ne font plus rien pousser, par bandes de 120 × 30 m le long
  des rues (40 × 30 m sinon), jusqu'à 4 zones + 1 par 25 habitants. Il bâtit une
  entreprise du bâtiment dès 10 habitants (quand les chantiers ont besoin d'ouvriers). Les services « par tranche » (école, police,
  dépôt de collecte) attendent leur seuil d'habitants.

## Mesures

Banc `tests/village_neuf.gd` : partie lancée du globe en mode Normal (relief plat),
Valpartie fondée avec ses fondateurs, ses rues, ses réseaux et ses zones. Au jour 10,
deux villages neufs à 2,6 km, reliés par une route : **Neuville** en pilote automatique,
**Clairbois** aménagé comme le ferait un joueur (une rue de 600 m, deux zones
résidentielles de 280 × 60 m, une entreprise du bâtiment).

| Après 40 jours | Avant | Après (une dizaine d'essais) |
|---|---|---|
| Clairbois (aménagé) | 0 habitant (aucun chantier ne démarrait) | 140 à 340 habitants, 100 habitants vers le 25e jour |
| Neuville (pilote auto) | 36 habitants | 25 à 155 habitants (souvent 75 à 120) |
| Valpartie, la première ville, au jour 50 | 398 habitants | 350 à 490 habitants |
| Caisse de Neuville (1 M€ au départ) | 990 000 € | 400 000 à 500 000 € (entreprise du bâtiment, zones) |

La première ville ne ralentit pas : les pionniers s'ajoutent à ses ouvriers au lieu de
les lui prendre. Les chiffres varient beaucoup d'un essai à l'autre : ce qui pousse est
tiré au hasard, et un petit immeuble (13 logements, 14 ouvriers) loge cinq fois plus de
monde par ouvrier qu'une maison (1 logement, 10 ouvriers). Le pilote automatique, qui
zone une bande par jour, reste derrière un joueur qui peint de grandes zones dès le
départ. Le banc échoue si Clairbois a moins de 15 habitants à 20 jours ou 100 à
40 jours, ou si Neuville en a moins de 40 à 40 jours.

Partie à plusieurs pays (`tests/partie_pays.gd --jours 15 --echelle 0.25`, sans règle
d'ouvriers) : après 15 jours, les quatre villages neufs comptent 156 habitants en tout
(53, 48, 11 et 44), contre 34 avant (3, 14, 6 et 11) ; les grandes villes grandissent
comme avant (4 560 habitants contre 4 480).

## Lancer le banc

```bash
godot --headless --path . --script res://tests/village_neuf.gd -- --apres 10 --jours 40 [--diag] [--rapport villages.csv]
```

- `--apres` : jours de la première ville avant la fondation des villages neufs.
- `--jours` : jours suivis après la fondation.
- `--diag` : tous les 5 jours, les chantiers des villages neufs avec leur équipe.

Environ 10 minutes sur une machine sans carte graphique.
