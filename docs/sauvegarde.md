# Sauvegarde des parties (format 2)

Code : `scripts/sauvegarde/save_game.gd` (lecture, écriture, conversions) et
`scripts/sauvegarde/parties_panel.gd` (fenêtre « Parties sauvegardées »).
Test : `tests/sauvegarde_test.gd`.

## Où sont les fichiers

Une partie = un dossier dans `user://parties/` :

- Windows : `%APPDATA%\Godot\app_userdata\MiniBlocs\parties\`
- Linux : `~/.local/share/godot/app_userdata/MiniBlocs/parties/`
- macOS : `~/Library/Application Support/Godot/app_userdata/MiniBlocs/parties/`

```
parties/
  annecy-20261112-0215/
    partie.json            fiche lisible (texte)
    terrain.json.zst       cases modifiées, par blocs de 64 × 64 m
    transport.json.zst     réseau : nœuds et tronçons
    batiments.json.zst     bâtiments, caisse, règles du bac à sable
    zones.json.zst         zones R / C / I
    blocs.json.zst         éditeur libre bloc par bloc
    mobilier.json.zst      meubles, fonctions des pièces, usage et style des bâtiments en murs fins
    ambiance.json.zst      heure et vitesse du temps
  sauvegarde-auto/         sauvegarde automatique (toutes les 5 min s'il y a eu des changements)
```

Les sections sont du JSON compressé (Zstandard), clés triées : deux sauvegardes
identiques donnent des fichiers identiques.

## La fiche `partie.json`

| Champ | Rôle |
| --- | --- |
| `format`, `version` | `"miniblocs-partie"`, `2` |
| `partie_id` | identifiant unique de la partie (128 bits), gardé d'une sauvegarde à l'autre |
| `auteur` | identifiant du joueur sur cette machine (`user://joueur.cfg`) |
| `nom`, `lieu` (`lat`, `lon`, `nom`), `mode` | ce qui s'affiche dans la liste |
| `cree`, `modifie`, `sauvegardes` | dates (secondes Unix, UTC) et nombre de sauvegardes |
| `camera` | position de la caméra, pour reprendre au même endroit |
| `resume` | bâtiments, logements, emplois, longueur du réseau, blocs, cases modifiées |
| `sections` | pour chaque section : fichier, version, taille et empreinte SHA-256 |

## Ce qui est stocké : seulement les changements

Le relief réel, les biomes et la végétation se recalculent toujours à partir des
données publiques (tuiles d'altitude, ESA WorldCover) : ils ne sont jamais
sauvegardés. Le terrain ne garde que les cases changées par le joueur (terrassement,
routes, bâtiments), rangées par blocs de 64 × 64 m : `{"bloc": 64, "blocs": {"bx,bz": base64}}`,
chaque bloc étant une suite de 6 octets par case (x et z locaux sur 1 octet, hauteur
en flottant 32 bits). Une ville de 600 bâtiments et 60 000 cases terrassées tient
en quelques centaines de Ko.

## Robustesse

- Écriture dans des fichiers `.tmp`, puis renommage ; la fiche est écrite en dernier.
  Un plantage pendant la sauvegarde laisse l'ancienne partie intacte.
- Au chargement, chaque section est vérifiée (empreinte SHA-256). Une section abîmée
  est ignorée et signalée ; le reste de la partie se charge.
- Chaque section a sa propre version. `SaveGame.migrate_section()` convertit les
  anciennes versions (par ex. terrain v1 : liste `[x, z, h]` → blocs).
- L'ancienne sauvegarde unique (`user://terre_save.json`, format 1) est importée
  automatiquement comme « Ancienne sauvegarde », puis renommée en `.bak`.
- Une partie d'une version plus récente du jeu est refusée proprement.

## Prêt pour le multijoueur (sans serveur pour l'instant)

Le format prépare les modes « entre amis » et « carte mondiale » sans rien coûter aujourd'hui :

1. **Identité** : `partie_id` identifie la carte partagée, `auteur` le joueur. Deux
   joueurs qui ont la même partie peuvent savoir qu'ils parlent de la même carte.
2. **Sections indépendantes** : chaque système (terrain, réseau, bâtiments…) est un
   fichier à part, avec son empreinte. Pour synchroniser, on compare les empreintes
   et on n'échange que les sections différentes.
3. **Terrain par blocs de 64 m** : la même découpe que l'affichage. Un serveur ou un
   pair pourra n'envoyer que les blocs changés, et seulement ceux proches du joueur
   (indispensable pour la carte mondiale).
4. **Étape suivante** (quand le multijoueur arrivera) : un journal d'actions
   (`journal.jsonl` : « route posée de A à B par tel joueur à telle heure ») en plus
   de l'état. L'état sert de point de départ, le journal se rejoue chez les autres
   joueurs. Les identifiants d'objets (tronçons, bâtiments, zones) devront alors être
   préfixés par le joueur qui les crée pour ne jamais entrer en collision.

## Dans le jeu

- **Sauver** (ou **F5**) : sauvegarde dans la partie en cours ; la première fois, une
  nouvelle partie est créée au nom du lieu.
- **Charger** : ouvre la liste des parties (charger, supprimer, sauvegarder sous un
  autre nom). **F9** : recharge tout de suite la partie en cours.
- Sur le globe : **Continuer** reprend la dernière partie, **Parties…** ouvre la liste.
