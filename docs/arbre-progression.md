# Arbre de progression à points

Choix de Gaël (2026-11-17) : plutôt que des déblocages automatiques, le joueur
gagne des **points de progrès** en jouant et choisit lui-même quoi débloquer.

Panneau : **Maj+F10**, ou menu Infos → « Arbre de progression ».
Réglage : Admin (F10) → Bâtiments → « Tout débloqué (bac à sable) » ou
« Arbre de progression à points ». Le préréglage Difficile utilise l'arbre.

## Gagner des points

| Source | Points |
|---|---|
| Départ | 3 |
| Record de population : 50, 100, 250, 500, 1 000, 2 000, 5 000, 10 000, 25 000, 50 000, 100 000 habitants | +1 chacun |
| Une ville devient Village / Bourg | +2 |
| Ville / Ville moyenne | +3 |
| Grande ville | +4 |
| Métropole | +5 |
| Mission réussie (Maj+J) | +1 |
| Succès des Objectifs | +1 |

Le record de population ne redescend pas : une démolition ne reprend rien.

## Les 9 branches

Logement, Commerce, Industrie, Services publics, Loisirs et sport, Réseaux et
déchets, Tourisme et parcs (tourisme, parc de loisirs, zoo, spectacles),
Transports, Patrimoine.

Chaque branche a un niveau 0 ouvert d'office et 4 niveaux à acheter dans l'ordre :
I = 1 point, II = 2, III = 3, IV = 4.

- Bâtiments : le niveau dépend du prix (0 : ≤ 1,5 M€ ; I : ≤ 5 M€ ; II : ≤ 15 M€ ;
  III : ≤ 40 M€ ; IV : au-delà). Patrimoine : I ≤ 25 M€, II ≤ 60 M€, III ≤ 100 M€, IV au-delà.
- Transports : I avenue, giratoire, tram, train, arrêt de tram, gare ;
  II voie express, bretelle, crémaillère, métro, héliport, aérodrome ;
  III autoroute ; IV LGV, aéroport.
- Toujours ouverts : écoles, Maison de commune, production de base, réseaux
  jusqu'à 50 M€ (il faut du courant et de l'eau dès le hameau).

## Avec les époques

L'époque passe avant l'arbre : un niveau acheté n'ouvre pas ce qui n'est pas
encore inventé (le panneau indique combien de bâtiments arrivent plus tard).

## Code

- `scripts/progression/arbre_progression.gd` (`ArbreProgression`) : données, points, achats, verrous.
- `scripts/progression/arbre_panel.gd` (`ArbrePanel`) : panneau Maj+F10.
- État dans `ReglagesPartie` (`arbre`, `points_bonus`, `journal_points`), sauvegardé avec les réglages.
- Verrous : `ReglagesPartie.raison_blocage` (bâtiments), `raison_voie` (TransportSystem.evaluate), `raison_station` (StationSystem.place).
- Points : `Objectifs.verifier_palier`, `_verifier_missions`, `succes_debloque` ; `ReglagesPartie.note_population`.
- Test : `tests/arbre_test.gd`.
