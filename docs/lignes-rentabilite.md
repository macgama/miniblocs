# Rentabilité des lignes de transport

Chaque ligne (panneau **Lignes**, touche **L**) a son compte d'exploitation,
dans l'esprit des jeux de transport : ce qu'elle rapporte, ce qu'elle coûte,
et des véhicules qui vieillissent. Le bouton **Bilan ▸** sous une ligne ouvre
son bilan détaillé ; la première ligne du panneau donne le total de toutes
les lignes.

## Ce qu'on voit pour chaque ligne

- **Résumé** (toujours affiché) : résultat estimé par mois, âge moyen des
  véhicules, fiabilité (part du service qui roule, pannes déduites).
- **Bilan détaillé** :
  - voyageurs par jour et remplissage à la pointe, prix du ticket (− / + 0,50 €)
    et recettes des tickets par mois ;
  - pour le fret : tonnes par jour, part qui trouve un client, prix de la tonne
    et recettes du fret ;
  - personnel et énergie (km par jour et par véhicule, longueur de la ligne) ;
  - entretien et réparations (pannes par mois) ;
  - résultat estimé, puis le vrai compte : ce mois-ci, le mois dernier, depuis
    la création (et l'argent mis dans les véhicules) ;
  - la flotte : modèle, âge, durée de vie, prix neuf, valeur de revente ;
  - **Renouveler les usés** et la case **Automatique**.

Le prix de chaque modèle s'affiche dans la liste des véhicules.

## Les règles (choix par défaut, à discuter)

| Sujet | Règle |
|---|---|
| Achat | les véhicules sont payés à la création de la ligne, quand on en ajoute ou qu'on change de modèle. Sans assez d'argent, c'est refusé (message). Argent illimité (Admin) : gratuit. Le réglage Admin « coût des constructions » s'applique aussi aux véhicules |
| Prix | ordres de grandeur réels : bus 25 000 € par mètre (bus urbain 300 k€), tram 80 000 € par mètre de rame, métro 90 000 €/m, train de voyageurs 60 000 €/m × (1 + vitesse/300) (TER ≈ 8 M€, TGV ≈ 25 M€), train de fret 3,5 M€ + 90 000 € par wagon, bateau 1 200 € × longueur² (au moins 150 k€), avion 400 000 € par place, camion 10 000 €/m. Avant 1920 ×0,35, avant 1950 ×0,55, avant 1980 ×0,8, futur ×1,4 |
| Revente | 80 % du prix neuf, puis la valeur baisse jusqu'à 5 % en fin de vie. On revend les plus vieux quand on réduit la flotte, toute la flotte quand on change de modèle ou qu'on supprime la ligne |
| Durée de vie | bus 12 ans, camion 10, tram 30, métro 40, train 35, bateau 30, avion 25 (1 an = 365 jours de jeu, soit 6 h de jeu à la vitesse par défaut) |
| Personnel | par véhicule et par mois, équipes comprises : bus 6 000 €, tram 7 000 €, métro 8 000 €, train 12 000 €, bateau 9 000 €, camion 5 000 €, avion 60 000 € (selon le nombre de places) |
| Énergie | par km : bus 0,50 €, tram 0,90 €, métro 1,50 €, train 3 € (fret ×1,5), bateau 4 €, avion 3 €, camion 0,45 €, selon la taille du véhicule. Km par jour = vitesse commerciale (au plus bus 15 km/h, tram 18, métro 30, train 70, camion 45…) × heures de service (16 à 19 h) |
| Entretien | part du prix neuf par an (bus 5 %, tram 2,5 %, métro 2 %, train 3 %, bateau 4 %, avion 6 %, camion 8 %), × 0,7 neuf, × 1,3 en fin de vie, puis de plus en plus |
| Pannes | rares jusqu'à 60 % de la vie, puis de plus en plus fréquentes ; une panne immobilise le véhicule 2 jours (moins de voyageurs transportés) et coûte 0,3 % de son prix (au moins 500 €). Une alerte prévient quand des véhicules dépassent leur durée de vie |
| Tickets | voyageurs du trafic (aller et retour, jours ouvrés, moins de 18 ans gratuits) × prix du ticket de la ligne. Un ticket plus cher rapporte plus par voyageur mais fait fuir des voyageurs vers la voiture |
| Fret | 2,50 € par tonne + par tonne et par km (camion 0,09 €, train 0,045 €, bateau 0,03 €). Seules les tonnes dont la production a besoin sont payées : part = (export + import de la veille) ÷ (capacité des dépôts, gares, ports, bords de carte et lignes de fret). Sans entreprise qui expédie, les camions roulent à vide |
| Budget | le budget communal (M) verse chaque jour : « Tickets de transport », « Fret des lignes », « Exploitation des lignes », « Entretien des véhicules » ; les achats et les reventes passent tout de suite en « Achat de véhicules » et « Revente de véhicules » |

## Anciennes parties

Les lignes d'une partie sauvegardée avant cette version reprennent des
véhicules neufs, sans les payer.

## Pour les autres systèmes

- `ExploitationLignes.instance`, nœud « ExploitationLignes » de la scène Terre
  (`terre_main.lignes_eco`).
- `bilan(id)`, `bilan_total()`, `journee(id)` ; `prix(model)`, `prix_achat(model)`,
  `valeur(model, genre, âge)`.
- `StationSystem.achat_ok` (garde de paiement) et le signal
  `StationSystem.fleet_changed(id)`.
- Sauvegarde : section `lignes_eco` (âges, comptes, renouvellement automatique).

## Code

`scripts/transport/exploitation_lignes.gd`, bilan dans
`scripts/transport/station_panel.gd`. Test : `tests/lignes_eco_test.gd`.
Captures : `tests/lignes_eco_vitrine.gd`.
