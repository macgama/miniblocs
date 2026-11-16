# Agrandir et rénover les bâtiments

Code : `scripts/batiments/ameliorations.gd` (classe `Ameliorations`, nœud « Ameliorations » créé par `terre_main`). Test : `tests/ameliorations_test.gd`.

## Dans le jeu

Ouvre la fiche d'un bâtiment (outil 1, clic sur le bâtiment, ou H puis un nom de bâtiment). Une section **Agrandissement** montre :

- le niveau (1 à 3) et la capacité actuelle (logements, élèves, emplois, visiteurs, MW, m³/j) ;
- l'état du bâtiment (neuf, bon, usé, très usé) ;
- le bouton **Agrandir** : prix, durée et capacité du niveau suivant dans l'infobulle ;
- le bouton **Rénover** quand le bâtiment est usé.

| Niveau | Capacité | Prix de l'agrandissement | Durée du chantier |
|---|---|---|---|
| 1 | ×1 | — | — |
| 2 | ×1,5 (école 300 → 450 places) | 60 % du prix du bâtiment | 45 % du chantier neuf |
| 3 | ×2 (école 600 places) | 80 % du prix du bâtiment | 60 % du chantier neuf |
| Rénovation | — | 15 % du prix | 15 % du chantier neuf |

L'agrandissement est un vrai chantier : échafaudages jusqu'aux futurs étages, grue pour les bâtiments de plus de 12 m, panneau de travaux (avancement, date de fin). Il suit les horaires des ouvriers et le rythme des chantiers (réglage Admin), et se paie au fil des travaux par la caisse de la ville. Si la caisse est vide, les travaux s'arrêtent et reprennent quand elle peut payer. Le bâtiment reste ouvert pendant les travaux, avec sa capacité d'avant.

Ce qui suit le niveau : logements et emplois (Population), places d'école, lits d'hôpital, lits d'hôtel (Tourisme), visiteurs et production des commerces et des usines (Production), puissance ou débit d'une installation des réseaux et sa consommation (Réseaux), demande du zonage, totaux des quartiers et de la ville.

## Visuel

- Bâtiments faits en code dont la forme se règle (maisons, immeubles, écoles, bureaux, tours…) : ils sont reconstruits avec plus d'étages (environ 30 % d'étages en plus par niveau, au moins un), toit compris.
- Les autres (modèles Blender, usines, halles, fermes…) : `Ameliorations.inserer_etages` recopie un étage courant sous le toit. Les murs s'étirent, les fenêtres et les bandeaux sont recopiés et le toit monte. Les bâtiments bas (moins de 7,5 m) sont rehaussés de 2 m par niveau.

## Rénovation

Après des travaux (rénovation ou agrandissement), `b.renov` prend la date de fin. L'usure (`BatimentsVie`) se calcule alors depuis cette date au lieu de la date de construction.

## Densification du zonage

Toutes les 2 secondes, quelques bâtiments sont examinés tour à tour. Un bâtiment poussé par le zonage s'agrandit d'un niveau, aux frais de ses propriétaires (rien pour la ville), si toutes ces conditions sont remplies :

- au moins 45 jours de jeu depuis sa construction ou ses derniers travaux ;
- la ville demande ce type de zone (demande R, C ou I positive) ;
- il est plein : tous ses logements occupés, au moins 90 % de ses emplois pourvus ;
- le terrain prend de la valeur : coefficient foncier (Nuisances) d'au moins 1,05 pour le niveau 2 et 1,3 pour le niveau 3.

`Ameliorations.raison_densif(bid)` donne la raison d'un refus. Le réglage `densification` est gardé dans la section de sauvegarde « ameliorations ».

## Données

Ces données sont gardées dans le bâtiment (section « batiments » de la sauvegarde v2) :

- `niv` : niveau (absent = 1) ;
- `renov` : date de fin des derniers travaux (secondes Unix du jeu) ;
- `amel` : travaux en cours, `{op: "niv"|"renov", cible, av, hr, du, cout, prive, ne, caisse?}`.

## Carte entre amis

Le client envoie `{"t": "ameliorer", "bid", "op": "niv"|"renov"}`. Le serveur vérifie la demande et lance les travaux, payés par la caisse du joueur s'il est hors de ses villes. Il renvoie ensuite le bâtiment (événement « ~ »), et le client recopie `niv`, `renov` et `amel` avec `Ameliorations.depuis_reseau`. Seul le serveur fait avancer les travaux et la densification.
