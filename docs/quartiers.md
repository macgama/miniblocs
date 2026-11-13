# Quartiers et arrêtés municipaux

Le maire découpe sa ville en **quartiers nommés** et y prend des **arrêtés** : zone 30,
rues piétonnes, tranquillité la nuit, tri obligatoire… Chaque arrêté coûte de l'argent et
change vraiment la vie du quartier : la circulation, le bruit, les déchets, les incendies et
l'avis des habitants. Panneau **Quartiers et arrêtés** : touche **Maj+Y** (menu Ville).

## Tracer un quartier

1. **Nouveau quartier** : il reçoit un nom proposé (Centre, Les Tilleuls, La Gare…) et le pinceau s'active.
2. Clic ou glisser sur la carte : on peint des **îlots de 50 × 50 m** (pinceau de 1 îlot à 9 × 9).
   **Gomme** pour en retirer. Clic droit ou Échap pour arrêter.
3. Ouvre le quartier pour le **renommer**, voir ses habitants, logements, emplois, son bruit le
   jour et la nuit et la satisfaction de ses habitants.

Règles : un quartier reste dans le territoire de **sa ville** (Maj+M) ; un îlot n'appartient qu'à
un quartier. Sans village (bac à sable sans fondation), on peint partout. La carte des quartiers
est aussi un calque du panneau **Cartes** (N).

## Les arrêtés

Coûts pour 1 hectare (× le réglage Admin « coût des constructions »), multipliés par la surface du quartier.

| Arrêté | Mise en place | Par mois | Effets |
|---|---|---|---|
| Zone 30 | 1 500 € | 40 € | voitures à 30 km/h dans les rues et avenues, le transit passe ailleurs, bruit des voies −15 %, + sécurité |
| Rues piétonnes | 8 000 € | 150 € | petites rues au pas (riverains, livraisons, secours), transit ×4, bruit −40 %, air −30 %, commerces plus attirants, terrains plus chers, + loisirs et commerces ; − transports pour ceux qui ont une voiture |
| Interdit aux poids lourds | 500 € | 20 € | 15 % des camions restent (livraisons) : moins de bruit le long des axes, + environnement |
| Tranquillité la nuit (22 h – 6 h) | 300 € | 60 € | bruit la nuit −40 %, + environnement ; les 18-30 ans regrettent les soirées |
| Tri des déchets obligatoire | 600 € | 30 € | +25 points de tri (jusqu'à 92 %), s'il y a un centre de tri |
| Détecteurs de fumée obligatoires | 900 € | 10 € | deux fois moins de départs de feu, + sécurité |
| Éclairage renforcé la nuit | 2 500 € | 70 € | + sécurité (exclut l'extinction) |
| Extinction de l'éclairage (1 h – 5 h) | 200 € | **économie** de 25 € | + environnement, − sécurité (exclut l'éclairage renforcé) |
| Stationnement payant | 1 200 € | 15 € | places le long des rues à 1,50 € la journée : recettes « Stationnement », moins de voitures ; − transports pour les automobilistes |
| Fleurissement et jardins partagés | 2 000 € | 120 € | verdure (air et bruit un peu filtrés), terrains plus chers, + environnement et loisirs |

La mise en place est payée tout de suite par la caisse de la ville du quartier ; le coût par mois
apparaît dans son budget (M) sous « Arrêtés municipaux » (et « Économies d'éclairage »).

## Mairie perdue, conseil élu et pilote automatique

- Avec le réglage « mairie perdue » (F10 → Événements), si ta liste perd les municipales, tu ne peux
  plus tracer, renommer ni supprimer les quartiers de cette ville, ni changer ses arrêtés. Le
  panneau les montre en lecture seule.
- Le **conseil élu** les gère selon son programme, un changement par semaine : il abroge d'abord ce
  que son programme combat, puis prend ce qu'il défend dans le quartier le plus peuplé, en gardant
  200 k€ de réserve.
  - sécurité : zone 30, poids lourds, calme la nuit, détecteurs, éclairage renforcé ; contre l'extinction ;
  - écologie : zone 30, rues piétonnes, poids lourds, tri, extinction, stationnement payant, fleurissement ; contre l'éclairage renforcé ;
  - contribuables : extinction et stationnement payant ; contre les rues piétonnes, le tri, l'éclairage renforcé et le fleurissement ;
  - solidarité : zone 30, calme la nuit, tri, détecteurs, fleurissement ; contre le stationnement payant.
- Le **pilote automatique** (Maj+P, quand tu es maire) ajoute chaque semaine un arrêté utile : détecteurs
  de fumée là où l'on habite, calme la nuit là où c'est bruyant (au-dessus de ~49 dB), tri obligatoire
  s'il y a un centre de tri. Caisse dans le rouge : il abroge l'arrêté le plus cher.

## Pour les autres systèmes

Code : `scripts/quartiers/` — `quartiers.gd` (nœud `Quartiers` sous terre_main, `Quartiers.instance`),
`arretes.gd` (catalogue `Arretes.LISTE`), `quartiers_panel.gd`. Section de sauvegarde « quartiers ».

- `Quartiers.au(x, z, "zone_30")` : un arrêté au point ?
- `quartier_au_point(x, z)`, `quartier_de_voie(eid)`, `a_arrete(qid, aid)`, `en_vigueur(aid)`.
- Crochets déjà branchés : `Trafic._cost` (facteur_cout_voie), `Trafic.flux_lourds` (facteur_lourds),
  places le long des rues (tarif_trottoir), `Traffic.speed_factors` (vitesse), `Nuisances._final_at`
  (moduler), `Dechets.tri_rate` (bonus_tri), `Incendies.roll_day` (facteur_feu), avis (groupe
  `avis_sources`), `GestionAuto.gerer_maire` (gerer_conseil), `PiloteAuto.semaine` (piloter).
- Budget : nouveau groupe **`budget_ville`** : `budget_ville(k) -> {recettes, depenses}` pour la ville k
  (-1 : partie sans pays, 0 : le pays). Contrairement à `budget_entretien`, rien n'est partagé selon la population.

Test : `godot --headless --path . --script res://tests/quartiers_test.gd`
