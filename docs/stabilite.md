# Stabilité sur de longues parties

Passe de stabilité avant l'accès anticipé (novembre 2026) : rapport de plantage
local, sauvegardes automatiques tournantes, banc de 10 heures de jeu sans pause.

## Rapport de plantage (`scripts/stabilite/journal_plantage.gd`, autoload `Plantages`)

Rien n'est envoyé en ligne : tout reste dans `user://plantages/`
(sous Windows `%APPDATA%\Godot\app_userdata\MiniBlocs\plantages` depuis l'éditeur,
`%APPDATA%\MiniBlocs\plantages` pour le jeu exporté).

- Pendant le jeu, `session_en_cours.json` est réécrit toutes les 15 s : version,
  système, carte graphique, écran, mémoire, images/s, et pour une partie
  (`terre_main.etat_pour_rapport`) le nom, la date de jeu, la vitesse, les
  habitants, bâtiments, véhicules, la caméra, la durée de la dernière sauvegarde
  automatique. Les 40 dernières erreurs (avec la pile d'appels GDScript) et les 30
  derniers messages y sont aussi (un `Logger` ajouté par `OS.add_logger`).
- Fermeture normale : le fichier est effacé. S'il est encore là au lancement
  suivant, le jeu s'est arrêté brutalement (plantage du moteur, manque de
  mémoire, jeu tué) : `plantage-AAAAMMJJ-HHMMSS.txt` est écrit avec cet état et
  les 150 dernières lignes du journal du moteur de la session (`user://logs/`,
  journal sur fichier activé, 10 gardés). Les 10 derniers rapports sont gardés.
- Une sentinelle (fil à part) note un gel : plus aucune image depuis 30 s.
- Le menu principal affiche « MiniBlocs s'est fermé brutalement » avec le chemin
  du rapport, « Reprendre la sauvegarde automatique » et « Ouvrir le dossier des
  rapports ».
- Désactivé en headless (tests, serveur) sauf avec `-- --plantages`.

## Sauvegardes automatiques tournantes

`SaveGame.autosave_slots()` : `sauvegarde-auto`, `sauvegarde-auto-2`,
`sauvegarde-auto-3`. `prochain_autosave()` prend une place libre ou la plus
ancienne (`modifie_ms`), `derniere_autosave()` la plus récente qui se relit. Une
fiche abîmée est ignorée sans erreur et devient le prochain emplacement réécrit.

## Banc de longue partie (`tests/longue_partie.gd`)

```
godot --headless --path . --fixed-fps 30 --script res://tests/longue_partie.gd -- --heures 10 --rapport banc.csv --listes listes.csv
```

Ville près de Bâle (600 habitants puis pilote automatique), temps à 1 jour/min,
sauvegardes automatiques toutes les 5 min, caméra qui se promène (relief chargé
et déchargé), sauvegarde + rechargement toutes les 2 heures. Toutes les 10
minutes de jeu : images (moyenne, réel, p95, pire), mémoire, objets, nœuds,
nœuds orphelins, habitants, bâtiments, véhicules, erreurs, et la taille de chaque
liste/dictionnaire des systèmes (fichier `--listes`). Verdict : nœuds orphelins
stables, mémoire par élément de la ville sans pente, images qui ne ralentissent
pas plus que la ville ne grandit, aucune liste qui grossit sans fin, aucune
erreur. Avec `--fixed-fps 30`, une heure de jeu prend environ une heure.

Test rapide (≈ 2 min, dans `tests/tous.sh`) : `tests/stabilite_test.gd`
(rotation, rapport, marque de session, 3 rechargements sans fuite).

## Trouvé et corrigé

- Onglet Télécom du panneau Réseaux : son contenu n'était dans aucun arbre tant
  qu'on ne l'ouvrait pas et n'était jamais libéré : 47 nœuds perdus à chaque
  partie chargée (`ReseauxPanel._exit_tree`).
- Hors ligne, les téléchargements de tuiles d'altitude et d'occupation du sol
  réutilisaient une requête HTTP pas encore terminée (« HTTPRequest is
  processing a request », des dizaines d'erreurs au lancement) : la requête est
  rendue libre après le signal.
- Fiche de partie abîmée : plus d'erreur JSON, la partie est simplement illisible.

## Ville qui se vidait d'un coup (corrigé, choix de Gaël : départs progressifs)

Un réseau partage un seul taux de service entre tous ses logements : quand la
demande dépassait deux fois la production, toute la ville passait sous 50 % le
même jour et, 7 jours plus tard, 2 700 habitants sur 2 700 partaient, puis la
ville se remplissait de nouveau. Maintenant 12 % des foyers touchés partent
chaque jour (les moins satisfaits d'abord) et personne n'emménage sur un réseau
saturé. Dans le banc, les installations du joueur sont posées sans chantier (le
banc n'a pas d'entreprise du bâtiment) près de chaque morceau de réseau qui manque.

## Reste à surveiller

- Pilote automatique : ~150 à 370 ms d'un coup le jour de sa « semaine »
  (budget, quartiers, construction), à étaler sur plusieurs images.
- Relevé de la nature (tourisme) : ~150 ms par village tous les 30 jours.
- Rendu GPU jamais mesuré dans le conteneur : à vérifier sur un vrai PC.
