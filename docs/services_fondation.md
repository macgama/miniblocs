# Départ au 1er janvier et services prêts au premier village

## Trois dates de départ

Une nouvelle partie commence le **1er janvier 1800, 1900 ou 2000** (assistant de
création, étape « Réglages », vignettes illustrées par une diligence, un tramway
de 1900 et un monospace). Une ancienne valeur (1850, « aujourd'hui »…) revient à
2000. L'horloge démarre le 1er janvier à 10 h, heure du lieu ; l'histoire avance
ensuite au rythme choisi (×1 à ×25). L'Admin (F10) peut toujours sauter à une
autre année en cours de partie. Les anciennes sauvegardes gardent leur époque.

Code : `GlobeMenu.EPOQUES`, `GlobeMenu.indice_epoque`, `DayNight.demarrer_au_nouvel_an`
(appelé par `terre_main._ready` pour une nouvelle partie historique).

## Services de base prêts

Le tout premier village de la carte (en solo, ou le premier joueur d'une carte
partagée) reçoit à sa fondation, sans chantier et sans rien payer, les
bâtiments de son époque :

| Réseau | 1800 | 1900 | 2000 |
|---|---|---|---|
| Courant | attend 1925 | attend 1925 (poste national posé alors) | raccordement au réseau national |
| Eau potable | attend 1900 | forage et station de pompage | forage et station de pompage |
| Égouts | attend 1900 | rejet d'égout (sans traitement, comme en 1900) | station d'épuration compacte |
| Déchets | attend 1884 | dépôt des bennes + décharge | dépôt des bennes + décharge |

- Une rue de service (100 à 200 m) prolonge la rue en T offerte, depuis son bout
  le plus loin de la mairie ; les bâtiments la bordent : ils sont un peu à l'écart
  du centre et raccordés au même réseau de rues.
- Ce sont les bons du **kit de l'État** qui servent (ils ne sont pas donnés deux
  fois) ; le reste du prix est offert.
- Un réseau que les habitants n'attendent pas encore (`Epoques.ATTENDU`) est posé
  tout seul l'année venue, sauf si la ville en a déjà un.
- Avant 1925, les pompes d'eau marchent à la vapeur ou par gravité : elles
  n'ont pas besoin du courant (`Reseaux._taux_elec_source`).
- Réglage : F10 → Construction → « Services de base prêts au premier village »,
  et la case de l'assistant (Ville et habitants). Activé par défaut.

Code : `scripts/communes/services_fondation.gd` (nœud `ServicesFondation` de
terre_main, section de sauvegarde `services_fondation`), test
`tests/services_fondation_test.gd -- 1800|1900|2000|off`.
