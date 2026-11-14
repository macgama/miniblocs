# Performances des grandes villes

## Le banc d'essai

```bash
godot --headless --path . --fixed-fps 60 --script res://tests/perf_ville.gd -- --hab 1000,5000
```

Il bâtit une ville sur un terrain plat (grille de routes, zonage, puis des foyers
jusqu'au nombre d'habitants voulu), la met un mardi à 6 h 30 à la vitesse par
défaut (1 jour de jeu par minute), puis mesure 600 images : temps moyen, médian,
95e centile et pire image, mémoire, nœuds. Il sauvegarde et recharge ensuite la
ville et donne les deux temps.

Options :

- `--hab 1000,5000` : tailles de ville (habitants) ;
- `--images N` : nombre d'images mesurées ;
- `--saccades` : affiche l'heure de jeu de chaque image de plus de 100 ms ;
- `--max-ms X` : échoue (code 1) si l'image moyenne dépasse X ms, pour s'en servir comme test chiffré ;
- `--detail` : coût approximatif de chaque script (on coupe son `_process` le temps d'une mesure) ;
- sans `--headless` : avec le rendu, il donne aussi les appels de dessin et les objets dessinés.

En `--headless`, rien n'est dessiné : les chiffres sont ceux de la simulation et
des scripts (le processeur), pas de la carte graphique.

## Résultats

Mesures du 14 novembre 2026 (conteneur Linux à 4 cœurs, `--headless`, 1 200 images,
1 jour de jeu par minute). « Avant » = `main` au commit c672522.

| Ville | | Image moyenne | Médiane | 95e centile | Pire image |
|---|---|---|---|---|---|
| 1 000 hab. | avant | 13,8 ms (73 i/s) | 5,9 ms | 24,5 ms | 775 ms |
| 1 000 hab. | après | 5,6 ms (178 i/s) | 4,0 ms | 14,2 ms | 42 ms |
| 5 000 hab. | avant | 54,5 ms (18 i/s) | 9,4 ms | 68,7 ms | 1 656 ms |
| 5 000 hab. | après | 11,9 ms (84 i/s) | 8,1 ms | 34,5 ms | 153 ms |

Mémoire inchangée (310 Mo à 1 000 hab., 410 Mo à 5 000). Sauvegarde : 0,15 → 0,12 s
(1 000 hab.) et 0,55 → 0,42 s (5 000 hab.) ; chargement : environ 2,1 s et 5,5 s, inchangé.

Avant, la ville se figeait près d'une seconde à chaque heure de jeu (toutes les
2,5 s réelles) ; il reste à 5 000 habitants de petites saccades de 60 à 150 ms
au quart d'heure de jeu (livraisons, déchets, réseaux).

## Ce qui a été changé

Aucune règle du jeu n'a changé : les calculs donnent les mêmes résultats, ils
sont faits plus vite, ailleurs (sur un autre cœur) ou étalés sur quelques images.

- **Nuisances** (pollution, bruit, valeur des terrains) : le calcul complet prenait
  0,7 s à 1 000 habitants (chaque emploi « éclabousse » 1,5 km autour de lui) et
  bloquait l'image. Il est fait maintenant sur un autre cœur du processeur
  (WorkerThreadPool) ; les nouvelles couches remplacent les anciennes d'un coup
  quand il est fini. La boucle de calcul est aussi 1,7 fois plus rapide, avec
  exactement les mêmes sommes (vérifié case par case). `recalculer()` reste
  immédiat quand on l'appelle directement (tests, chargement), et en pause.
  Une tuile dont le relief n'est pas encore chargé n'est relue qu'à l'arrivée de
  nouvelles tuiles d'altitude.
- **Passants** : quand beaucoup d'habitants partent en même temps (8 h, 17 h), ils
  apparaissent sur plusieurs images (3 ms au plus par image) au lieu d'un coup.
  Chaque image ne regarde plus que ceux qui sont en trajet ; les autres sont
  revus à la minute où leur moment de la journée se termine.
- **Livraisons** (Production) : pendant une tournée, la liste des fournisseurs de
  chaque marchandise, les besoins des sites et les chauffeurs ne sont calculés
  qu'une fois (les stocks, eux, sont relus à chaque commande). Même chose pour le
  pas horaire de production.
- **Barre du haut** : la satisfaction moyenne (200 habitants) était recalculée
  d'un bloc chaque seconde ; elle l'est par petits morceaux (`Population.stats_par_morceaux`).
- **Habitant suivi** : son repère ne recalcule plus sa journée deux fois par image.
- **Réseaux** : les besoins en eau et en courant de chaque type de bâtiment ne sont
  calculés qu'une fois par pas.
- **Déchets** : la taille des bacs se calcule sans recompter les occupants trois fois.

## Profiler soi-même

La méthode qui a servi : copier le dépôt, renommer chaque `func _process` en
`__w_process` et ajouter une fonction `_process` qui chronomètre l'appel, puis
lancer le banc dans la copie. Couper les scripts un par un (`--detail`) est plus
bruité, car les gros calculs reviennent par vagues (chaque quart d'heure, chaque
heure de jeu).

## Pistes pour la suite

- Livraisons : ~1 000 commandes examinées par quart d'heure à 5 000 habitants,
  même quand aucun chauffeur n'est libre (40 ms).
- Réseaux : le pas de simulation (toutes les 0,5 s) coûte encore ~30 ms à 5 000 habitants.
- Chargement d'une partie de 5 000 habitants : 5,5 s.
- Construction de la ville du banc : le zonage de 1 000 bâtiments prend ~75 s.
- Rendu (carte graphique) : à mesurer sur un vrai PC, sans `--headless`.
