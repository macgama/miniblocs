# Immobilier vivant

Panneau **Immobilier** : touche **F11**, ou menu **Ville → Immobilier**. Les quartiers
changent de visage tout seuls : prix qui montent et qui baissent, promoteurs privés,
gentrification, bidonvilles, logements sociaux.

Code : `scripts/immobilier/` (`immobilier.gd`, `immobilier_types.gd`,
`immobilier_panel.gd`). Test : `tests/immobilier_test.gd`. Section de sauvegarde
`immobilier`. Réglages Admin (F10 → Immobilier) : « Marché vivant » et « Bidonvilles ».

## Marché

- Chaque ville a un **indice des prix** (1,0 = normal, de 0,7 à 1,8). Il suit la
  tension du marché : peu de logements vides (moins de 5 %) et des emplois libres qui
  attirent du monde le font monter, beaucoup de logements vides et du chômage le font
  baisser. Il bouge de 3 % de l'écart chaque jour.
- **Loyer** d'un logement = loyer de base × valeur du terrain (pollution, bruit, parcs,
  services : voir `docs/nuisances.md`) × indice de la ville.
- **Krach** : rare, seulement au-dessus de 1,35 ; les prix perdent 22 % d'un coup.
- **Prix de vente** estimé : terrain + construction (moins l'usure) × indice.
- Un relevé par mois garde l'historique (courbe dans l'onglet Marché).

## Règles du maire (onglet Marché)

| Règle | Choix | Effet |
|---|---|---|
| Encadrement des loyers | Aucun, Souple (×1,6), Moyen (×1,3), Strict (×1,1) | le loyer ne dépasse plus le loyer de base × ce plafond |
| Logements sociaux imposés | 0, 20, 25, 30 % | part des programmes neufs des promoteurs en loyer social |
| Permis de construire | Libre, Sur demande, Gelé | sur demande : le maire accorde ou refuse chaque projet |

Plus les règles sont strictes, plus les promoteurs renoncent (« ce n'est plus rentable »).
Dans une ville dont le joueur n'est plus maire, le conseil élu accorde la plupart des permis.

## Promoteurs

Chaque semaine, deux des quatre sociétés cherchent une affaire :

| Société | Ce qu'elle fait |
|---|---|
| Immo Prestige | résidence de standing (24 logements, loyers ×1,3) dans une zone résidentielle chère (terrain ×1,2) |
| Les Bâtisseurs Réunis | maisons dans une zone résidentielle au prix moyen |
| Béton & Fils | rase une maison du zonage sur un terrain très cher (×1,3) pour un immeuble ; ses habitants sont relogés ailleurs s'ils trouvent |
| Pierre & Rendement | rachète un immeuble dans un quartier qui monte et le rénove haut de gamme (loyers ×1,3) : la gentrification |

Il faut une demande de logements (zonage) et de l'argent dans leur caisse (elle remonte
chaque mois avec leurs loyers). Ils bâtissent à leurs frais, sur un vrai chantier ; la
ville touche **5 % de taxe d'aménagement**. Avant 1960, la « résidence de standing » est
l'immeuble le plus cossu de l'époque.

## Gentrification

La ville est découpée en secteurs de 200 m. Chaque mois, chacun note son prix moyen
et sa part de foyers modestes (Précaire et Modeste, voir `docs/niveaux-de-vie.md`).

- **S'embourgeoise** : prix +12 % ou plus sur six mois, et pas plus de modestes. Les
  foyers modestes ont peur d'être chassés (avis −4), puis partent quand le loyer dépasse
  45 % de leurs revenus. Les foyers aisés sont contents (+2).
- **Se paupérise** : prix −12 % ou plus. Les habitants s'inquiètent (−3).

Carte : **N → Immobilier → Quartiers qui changent** (bleu : s'embourgeoise, rouge : se
paupérise, rouge vif : bidonvilles). Le nom d'un secteur est celui du quartier peint
(Maj+Y) quand il y en a un, sinon sa direction depuis le centre de la ville.

## Bidonvilles

Ils apparaissent (si l'Admin les laisse) quand :

1. une famille ne trouve aucun logement à moins de 35 % de ses revenus, un mois après
   que son loyer est devenu trop cher (expulsée pour impayés) ;
2. des emplois attendent au moins 20 personnes de plus que les chômeurs, et moins de
   1,5 % des logements sont libres : des travailleurs arrivent et bâtissent des baraques.

Les baraques (16 × 16 m, 4 foyers, jusqu'à 14 par bidonville) poussent en bordure de
ville, à 180 m ou plus du centre. Pas de loyer ni de taxe foncière, mais pas d'eau ni
d'égouts : odeurs, eau polluée et saleté autour (les terrains voisins perdent de la
valeur), habitants bloqués au niveau **Précaire** et mécontents (−12). Personne n'y
emménage par choix (arrivées très lentes), et les familles qui trouvent mieux partent.

Le maire peut :

- **Viabiliser** (25 000 € par baraque) : eau, courant, latrines. Plus de pollution ;
  les familles peuvent devenir Modestes ; mécontentement réduit (−5).
- **Reloger** (3 000 € d'aide par famille) : chaque famille part dans un logement libre
  qu'elle peut payer, social d'abord. Les baraques vides sont démontées.
- **Raser** : les familles sont expulsées et quittent la ville ; les habitants s'en
  souviennent deux mois (avis −6).

Une baraque vide depuis 20 jours est démontée ; un bidonville vide disparaît.

## Logements sociaux (B → Logement)

| Bâtiment | Année | Logements | Prix |
|---|---|---|---|
| Cité ouvrière | 1853 | 8 | 1,3 M€ |
| Immeuble HBM | 1894 | 30 | 4,5 M€ |
| Barre HLM | 1955 | 120 | 12 M€ |
| Résidence sociale | 1985 | 36 | 6,5 M€ |
| Résidence de standing (privé) | 1960 | 24 | 9 M€ |

Loyer social : 55 % du loyer de base, quelle que soit la valeur du quartier. Pas de taxe
foncière. La ville touche les loyers de ses logements sociaux et paie l'entretien (35 %
des loyers + 15 € par logement et par mois), visible dans le budget (M).

## Pour les autres systèmes

- `Immobilier.mult_loyer(bid, coef)` : multiplicateur après la valeur du terrain
  (`Nuisances.loyer`, `Population.household_budget`).
- `Immobilier.coef_taxe(bid)` : 0 pour les baraques et les logements sociaux
  (`Population.city_budget`).
- `Immobilier.precaire(bid)`, `Immobilier.viabilise(bid)` : `NiveauxVie.plafond_logement`,
  déménagements de `Nuisances` et de `Population` (on ne choisit pas une baraque).
- `ZoneSystem._grow_in(z, need, max_logements, types_force)` : les promoteurs imposent
  leurs types.
- Groupes `avis_sources` et `budget_ville` ; brèves du journal (F4) pour les grands
  changements.

## Tester dans Godot

1. Ouvrir le projet dans Godot (4.7 conseillé), lancer une partie, fonder un village.
2. **F11** ouvre le panneau. Peindre une zone résidentielle, laisser la ville se remplir :
   quand il n'y a plus de logement libre, l'indice des prix monte (onglet Marché).
3. Onglet Promoteurs : avec le permis « Sur demande », les demandes arrivent ici
   (Accorder / Refuser).
4. Pour voir un bidonville vite : une usine (beaucoup d'emplois) dans une ville dont tous
   les logements sont pleins. Puis onglet Bidonvilles : Viabiliser, Reloger (après avoir
   posé un immeuble HBM depuis B → Logement), Raser.
5. Test automatique : `godot --headless --path . --script res://tests/immobilier_test.gd`.
