# Faire évoluer une route posée

Une route déjà construite change de profil sans être démolie : le tracé, les nœuds et les
carrefours restent les mêmes, donc les bâtiments, leurs accès et les réseaux posés sous la
route (eau, égouts, électricité, fibre) restent raccordés.

## Dans le jeu

- Outil **Route** (touche 5) → bouton **Faire évoluer**, puis clic sur une route (elle
  s'allume en vert au survol). Aussi : **Trafic** (Maj+L) → Choisir une route → **Faire évoluer**.
- Le panneau propose :
  - **Classe** dans la même famille : rue ↔ avenue ↔ départementale, voie express ↔ autoroute ;
  - **Voies par sens** : passer de 1 à 2 voies par sens change la classe toute seule
    (une rue devient une avenue ; une départementale devient une route à 2 × 2 voies,
    avec terre-plein de 2 m) ;
  - **Largeur d'une voie** dans les limites de la classe ;
  - **Bords** : trottoirs (2 m), accotements (1 m) ou sans trottoirs (simple bordure de 30 cm) ;
  - **Terre-plein central** (2 m, ou celui de la classe) ;
  - **Couloirs de bus** : une voie de 3,50 m par sens, à droite, en enrobé rouge, séparée
    par une large ligne continue. Les bus des lignes y roulent sans bouchon et les voitures
    gardent toutes leurs voies (contrairement à la « voie de bus » du panneau Trafic, qui
    prend une voie aux voitures) ;
  - **Tramway au milieu** : plate-forme axiale de 7 m (deux voies, entraxe 3 m). À la fin
    des travaux, une vraie voie de tram est posée dans l'axe, entre les mêmes carrefours :
    on y pose des arrêts de tram et des lignes (touche L).
- Le **devis** se met à jour : nouvelle largeur, détail des postes, total et durée.
  « Lancer les travaux » pose le nouveau profil tout de suite (l'emprise est réservée)
  et ouvre un chantier : cônes et rouleau, payé au fil des travaux, la route reste ouverte
  avec une file sur deux (capacité divisée par deux dans le trafic).
- Refus : un bâtiment dans la nouvelle emprise (on ne démolit rien pour élargir), une autre
  voie trop proche, une classe pas encore inventée à l'époque de la partie (Epoques),
  une route encore en construction ou déjà en travaux, une carte entre amis (pas encore).

## Prix de référence

Avant le réglage Admin « coût des constructions » : chaussée neuve 130 €/m², dépose
30 €/m², trottoirs 90 €/m², accotements 40 €/m², terre-plein 70 €/m², marquage 8 €/m,
tramway 5 000 €/m (plate-forme à deux voies). Plus cher sur les ponts et en tunnel.

## Code

- `scripts/transport/transport_types.gd` : réglages des routes `bords`, `tp`, `bus`, `tram`
  dans `w` (gardés seulement s'ils diffèrent de la classe), `side_of`, `side_kind_of`,
  `bus_of`, `has_tram`, `median_of` (plate-forme du tram comprise), `tp_of`,
  `bus_lane_offset`, `evolutions_of`, `options_of`. La départementale accepte 2 voies par sens.
- `scripts/transport/evolution_voies.gd` (`EvolutionVoies`, nœud « EvolutionVoies ») :
  `devis(eid, classe, w)`, `lancer(eid, classe, w)`, chantier `evolution:<eid>` dans
  `SuiviChantiers`, état dans le tronçon (`evo` : h, av, cout), sauvegardé avec le réseau
  et recopié quand le tronçon est coupé ; `sync_tram()` garde les voies de tram `sr`
  d'accord avec les routes (coupe, démolition, chargement).
- `scripts/transport/evolution_panel.gd` (`EvolutionPanel`) : le panneau.
- `TransportSystem.set_upgrade()` / signal `upgrade_picked` : l'outil.
- Dessin : `TransportView._road_section` (couloirs de bus, plate-forme du tram, bords) ;
  une voie de tram `sr` n'a que ses rails (ni ballast, ni traverses, ni piles).

## Tests

- `godot --headless --path . --script res://tests/evolution_voies_test.gd`
- Captures : `godot --path . --rendering-driver opengl3 --script res://tests/evolution_voies_vitrine.gd -- --dossier captures`
