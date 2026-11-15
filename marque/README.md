# Marque ManiGames et logo de MiniBlocs

Tout est fabriqué par `tools/marque/logos.py` (lettres vectorisées : les SVG s'ouvrent dans
Illustrator, Inkscape ou un navigateur sans installer de police). PNG transparents avec
`python3 tools/marque/logos.py --png`.

## Les 4 pistes de logo du studio

| Piste | Fichiers | Idée |
|---|---|---|
| 1. Cube MG (proposée) | `manigames-piste1-*` | Un bloc de MiniBlocs en 3D isométrique, M sur la face rouge, G sur la face bleue. « Mani » en encre, « Games » en rouge. Marche aussi en icône seule (favicon, photo de profil). |
| 2. Ville en M | `manigames-piste2-*` | Badge sombre : cinq immeubles dont les toits dessinent un M, sur une bande de pré. MANI en gras, GAMES en fin. |
| 3. Point-cube | `manigames-piste3-*` | « manigames » en minuscules rondes, le point du i remplacé par un petit cube. |
| 4. Tampon | `manigames-piste4-*` | Médaillon rond, trois blocs empilés, « MANIGAMES · INDIE GAMES · MADE WITH CARE » autour. |

Le site et les capsules utilisent la piste 1. Changer de piste = refaire les fichiers du
site (`tools/site/construire.py`, fonction `logo_inline` et favicons) avec l'autre logo.

## Couleurs et polices

| | |
|---|---|
| Jaune | `#F2C14E` (foncé `#C9962A`) |
| Rouge | `#E4572E` (foncé `#B03A1A`) |
| Bleu | `#5DA9E9` (foncé `#3478B5`) |
| Vert | `#7FB069` |
| Encre | `#22303C` |
| Crème | `#FFF8EC` |
| Titres, logo du studio | Outfit ExtraBold (800) |
| Texte du site | Nunito |
| Logo MiniBlocs | Fredoka SemiBold (600), lettres jaunes en relief, points des i en cubes |

Polices libres (SIL Open Font License), dans `tools/marque/polices/` avec leur licence.

## Logo du jeu

`miniblocs-logo.svg` / `.png` : sur toutes les capsules Steam, le site et la bande-annonce v2.

## Capsules Steam (`steam/`)

`python3 tools/marque/capsules.py` (fonds : grandes captures 3840 × 2160 de
`tests/demo_vitrine.gd --grand`, sinon les captures de la démo). Voir
[../docs/steam/README.md](../docs/steam/README.md) pour l'endroit où chacune se dépose.

## Bande-annonce v2

`python3 tools/marque/bande_annonce.py` : carton ManiGames, plans de la v1 avec le nouveau
logo en surimpression, carton final « Steam · 2027 ». Sortie dans les fichiers du projet,
`captures/demo/miniblocs-bande-annonce-v2.mp4`.
