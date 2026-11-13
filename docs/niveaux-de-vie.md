# Niveaux de vie

Code : `scripts/habitants/niveaux_vie.gd` (`NiveauxVie`, nœud « NiveauxVie » sous terre_main, `NiveauxVie.instance`) et `scripts/habitants/niveaux_vie_panel.gd` (panneau **Maj+N**). Section de sauvegarde : `"niveaux_vie"`. Test : `tests/niveaux_vie_test.gd`.

Inspiré des jeux de gestion où les habitants « montent en gamme » quand on couvre leurs besoins, mais adapté à MiniBlocs : le niveau est celui du **foyer**, il dépend de ce que la ville lui offre **et** de ses revenus, et il a des effets sur l'économie réelle du jeu (impôts, achats, logement).

## Les cinq niveaux

| Niveau | Besoins en plus de ceux d'en dessous | Revenu par part | Jours pour monter |
| --- | --- | --- | --- |
| Précaire | — | — | — |
| Modeste | vrai logement (pas la tente), de quoi manger (boulangerie, supérette ou marché approvisionné), eau, électricité, pas de dettes | — | 4 |
| Classe moyenne | école pour les enfants, hôpital à moins de 30 min avec des lits, égouts raccordés, internet (ADSL, fibre ou mobile), vêtements et hygiène | 1 300 € | 7 |
| Aisé | trajets de 35 min au plus, deux tiers des loisirs possibles, quartier calme, police, logement agréable | 1 800 € | 12 |
| Très aisé | électronique et meubles, quartier recherché (terrain ×1,3), beau logement | 2 300 € (ou 1 800 € et 60 000 € d'épargne) | 20 |

Le revenu par part suit l'INSEE : 1 part pour le premier adulte, 0,5 par personne de 14 ans ou plus, 0,3 par enfant. Il est multiplié par le réglage Admin « Salaires ».

**Logement.** Chaque logement a un plafond : Classe moyenne au départ, +1 pour une maison, un confort de 60 ou plus (intérieur aménagé), un terrain à ×1,2, un terrain à ×1,6 (au plus Très aisé). La tente des fondateurs plafonne à Précaire.

## Monter et redescendre

Chaque jour, tous les foyers sont évalués (400 par image, pour ne pas ralentir le jeu) :
- tous les besoins du niveau suivant sont là : la progression avance (4 à 20 jours selon le niveau) ;
- un besoin de son niveau manque : elle recule, et le foyer perd un niveau au bout de 10 jours ;
- sinon elle revient doucement à zéro. Si seuls le logement ou le quartier bloquent, le foyer a 15 % de chances par jour de déménager dans le logement libre le plus proche qui lui permettrait de monter.

Les nouveaux arrivants (et les foyers d'une ancienne partie) commencent au niveau que la ville leur permet, au plus Classe moyenne. Une montée ou une descente s'inscrit au CV des adultes (étape « niveau ») et un message résume la journée.

## Effets

| | Précaire | Modeste | Classe moyenne | Aisé | Très aisé |
| --- | --- | --- | --- | --- | --- |
| Taxe foncière | ×0,6 | ×0,85 | ×1 | ×1,3 | ×1,7 |
| Courses | ×0,8 | ×0,92 | ×1 | ×1,15 | ×1,35 |
| Achats de biens (vêtements, électronique, meubles, boissons, hygiène…) | ×0,5 | ×0,8 | ×1 | ×1,5 | ×2,2 |
| Sorties et loisirs (par adulte et par mois) | 0 € | 30 € | 90 € | 220 € | 450 € |
| Intérêts de l'épargne | — | — | — | 2,5 % par an | 2,5 % par an |

Les achats passent par les commerces de la Production (P) : une ville aisée vend plus, donc demande plus de livraisons. Les foyers sans niveau (module absent) gardent les coefficients 1.

**Avis des habitants** (thème Logement, groupe `avis_sources`) : +3 pour un foyer qui monte, −4 pour un foyer qui s'appauvrit, −8 pendant 15 jours après une descente.

**Objectifs** (Maj+J) : succès « La classe moyenne » (300 habitants et la moitié des foyers en Classe moyenne ou mieux) et « Les beaux quartiers » (25 foyers Très aisés).

## Pour les autres systèmes

- `NiveauxVie.niveau(h)` : 0..4, −1 si le foyer n'est pas encore évalué (données `h.nv`, `h.nvp` dans `Population.households`).
- `NiveauxVie.coef_taxe(h)`, `coef_courses(h)`, `coef_conso(h, marchandise)`, `sorties(h, adultes)`, `placements(h)` : utilisés par `Population.household_budget()`, `Population.city_budget()` et `Production`.
- `NiveauxVie.instance.manques(hid)`, `texte_foyer(hid)`, `bilan(filtre)`, `part_au_moins(n, filtre)`.
- Carte : calque `habitants_niveaux` du panneau Cartes (N).
