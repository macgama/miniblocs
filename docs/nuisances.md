# Pollution, bruit et valeur des terrains

Code : `scripts/environnement/nuisances.gd` (nœud « Nuisances », `Nuisances.instance`),
cartes de couleur : `scripts/interface/calques.gd`, `calque_couleur.gd`, `cartes_panel.gd` (touche **N**).
Test : `tests/nuisances_test.gd`. Section de sauvegarde : `nuisances`.

## Ce que le joueur voit

- **Touche M (panneau Cartes)** : une carte de couleur à la fois, posée sur le terrain autour de la caméra.
  - Groupe *Nuisances* : **Air**, **Eau**, **Bruit le jour**, **Bruit la nuit** (rien là où c’est propre ou calme, du jaune pâle au violet quand ça empire).
  - Groupe *Immobilier* : **Valeur du terrain** (prix du m², du rouge bon marché au bleu très cher) et **Loyers** (un aplat par logement).
  - Les autres systèmes (trafic, services publics, réseaux, avis des habitants…) ajoutent leurs propres cartes dans le même panneau.
  - En bas : air moyen aux logements, foyers au bruit la nuit, prix moyen du terrain, loyer moyen, foyers au loyer trop cher.
- **Survol d'une case** : « Air 12 % · Eau 3 % · Bruit 54 dB (nuit 41 dB) · Terrain 3 100 €/m² ».
- **Admin (F10) → Pollution et bruit** : pollution désactivée, faible, normale (par défaut) ou forte ; et « La pollution rend malade » (oui par défaut).

## Sources

| Source | Air | Eau | Bruit | Nuit | Odeur |
|---|---|---|---|---|---|
| Centrale au charbon, haut fourneau, aciérie, raffinerie | très fort | moyen à fort | fort | oui | – à fort |
| Chimie, cimenterie, briqueterie, verrerie, incinérateur, papeterie | fort | jusqu'à fort | moyen | souvent | parfois |
| Usines, mines, carrières, puits | moyen | moyen | fort (carrières) | – | – |
| Agroalimentaire (sucrerie, abattoir, laiterie, brasserie) | faible | fort | moyen | – | fort |
| Élevages (porcherie, poulailler, étable…) et fermes | faible | moyen (engrais) | faible | – | fort |
| Entrepôts, terminaux, dépôts de bus | faible | – | moyen | oui | – |
| Stades, discothèques, salles de concert, cafés, fêtes foraines | – | – | moyen à fort | bars et boîtes | – |
| Autoroute, voie express, départementale, avenue, rue | selon le trafic | – | selon le trafic | oui | – |
| Train, LGV, tram, métro | – | – | moyen à fort | oui | – |
| Aéroport, aérodrome, héliport | moyen | – | très fort, jusqu'à 2,5 km | oui | – |
| Chantiers en cours | – | – | moyen | – | – |

Les tunnels n'émettent rien. Le trafic routier vient de `Traffic.flux_all()` (véhicules par heure,
`flux_lourds` pour les poids lourds) quand le module de trafic le fournit ; sinon le bruit suit la
classe de la voie et la taille de la ville. Centrales nucléaires, solaires et barrages ne polluent pas l'air.

**Ce qui protège** : forêts, parcs, jardins et espaces publics filtrent l'air (jusqu'à −35 %) et étouffent le bruit (jusqu'à −25 %).

**Autres systèmes** :
- groupe `pollution_sources` avec `pollution_sources() -> Array` de `{"pos": Vector3, "rayon": m, "air", "eau", "bruit", "odeur", "salete": 0..1, "nom", "nuit": bool, "bid": int}` (relu à chaque calcul ; avec `bid`, le bâtiment n'est plus compté par la table des émissions) ;
- ou `Nuisances.instance.ajouter_source(id, type, pos, force, rayon)` / `retirer_source(id)`, avec type `"air"`, `"eau"`, `"bruit"`, `"odeur"` ou `"salete"`.

## Calcul

Grille de cases de 20 m, rangées par tuiles de 640 m, seulement là où la ville existe (région de 40 km).
Chaque source ajoute `force × (1 − d/rayon)²` aux cases proches ; la somme sature : `1 − e^(−somme)`.
Recalcul quand un bâtiment, une voie, une ligne, le terrain ou les réglages changent (au plus toutes les
2 s), et toutes les 30 s pour suivre le trafic et les autres systèmes.

## Valeur des terrains et loyers

Coefficient de valeur (1,0 = moyen, de 0,4 à 3) :

- **plus** : commerces, services et loisirs proches, parcs et forêts, bord de l'eau, arrêts et gares,
  emplois accessibles, voisins prestigieux (villas, monuments, palais, lieux de culte), couverture des
  services publics (`ServicesPublics.couverture` quand ce module existe) ;
- **moins** : air pollué, eau polluée, bruit le jour et surtout la nuit, odeurs et saleté.

Prix du terrain = 2 800 €/m² × coefficient. Chaque bâtiment garde sa propre valeur, qui rejoint celle de
son quartier de 8 % par jour de jeu : un quartier « prend » ou « perd » de la valeur en quelques semaines.

- **Loyer** d'un logement = loyer de base (maison 1 050 €, appartement 720 €, ou loyer du logement
  aménagé) × valeur du bâtiment. `Nuisances.instance.loyer(bid)`.
- **Taxe foncière** = taxe de base × valeur du bâtiment (`coef_foncier(bid)`), dans `Population.city_budget()`.
- **Déménagements** : un foyer dont le loyer dépasse 45 % des revenus pendant 20 jours part dans le logement
  libre le moins cher qu'il peut payer ; un foyer très gêné par le bruit ou la pollution part parfois vers un
  logement calme. Au plus 5 déménagements par jour.
- **Arrivées** : les logements agréables se remplissent jusqu'à 1,4 fois plus vite, les logements gênants
  jusqu'à 6 fois plus lentement (ils restent vides et s'abîment).
- **Zonage** : là où le terrain est cher, les bâtiments chers (par logement ou emploi) poussent plus souvent,
  là où il est bon marché, les bâtiments modestes.
- **Usure** : un quartier dévalué s'use jusqu'à 1,6 fois plus vite, un quartier cher plus lentement.

## Habitants

- **Santé** : pollution de l'air + moitié de celle de l'eau au logement (`CycleVie.pollution_at`) : risque
  de maladie (asthme surtout), espérance de vie. Réglage Admin pour couper cet effet.
- **Satisfaction** : air pollué (jusqu'à −14), odeurs, eau polluée, bruit (surtout la nuit, jusqu'à −14),
  loyer trop cher (jusqu'à −12) ; verdure (+5), bord de l'eau (+3), loyer abordable (+3). Ces facteurs passent
  par le groupe `avis_sources` (`avis_facteurs()`) pour le module d'avis des habitants, et en attendant par
  `Population.extra_satisfaction` (enchaîné avec celui de la production).

## Pour les autres modules

| Fonction | Rend |
|---|---|
| `air(pos)`, `eau(pos)`, `bruit(pos, nuit := 0)` | 0..1 (`nuit = -1` : selon l'heure) |
| `Nuisances.decibels(v)` | dB approchés (35 à 80) |
| `valeur(pos)`, `prix_m2(pos)` | coefficient, €/m² |
| `coef_foncier(bid)`, `tendance(bid)` | valeur du bâtiment, > 0 si le quartier monte |
| `loyer(bid)`, `taux_effort(hid)` | € par mois, part des revenus |
| `gene(bid)`, `sante(bid)` | 0..1 |
| `Calques.ajouter(id, nom, groupe, afficher, legende)` | une carte de plus dans le panneau N |
| `CalqueCouleur` | carte de couleur prête à l'emploi (`valeur(x, z)` ou `rects()`) |

Le registre `Calques` est une classe statique : depuis un script qui ne doit pas dépendre de ce fichier,
`if ResourceLoader.exists("res://scripts/interface/calques.gd"): load("res://scripts/interface/calques.gd").ajouter(…)`.
