# Page Steam : mode d'emploi

- [page-steam-fr.md](page-steam-fr.md) : fiche, descriptions courte et longue, fonctionnalités,
  accroches, tags, configuration requise, accès anticipé, mentions légales.
- [page-steam-en.md](page-steam-en.md), [page-steam-de.md](page-steam-de.md),
  [page-steam-it.md](page-steam-it.md), [page-steam-es.md](page-steam-es.md) : la même chose
  en anglais, allemand, italien et espagnol.

Rien n'est publié : tout se colle à la main dans Steamworks une fois le compte Steam Direct
ouvert (100 $ par jeu, remboursés après 1 000 $ de ventes).

## Où coller quoi dans Steamworks

| Steamworks | Source |
|---|---|
| Store Page → Description → « À propos de ce jeu » | bloc « Description longue » |
| Store Page → Description courte | bloc « Description courte » (300 caractères au plus) |
| Store Page → Configuration système | bloc « Configuration requise » (Windows) |
| Store Page → Accès anticipé | section « Accès anticipé », seulement si le jeu sort ainsi |
| Basic info → Mentions légales | bloc « Mentions légales » |
| Tags (Gérer les tags) | les 20 tags, dans l'ordre |
| Content Survey → Contenu généré par IA | voir plus bas |

Pour chaque langue, Steamworks a un sélecteur de langue en haut de la page : coller le
français dans « French », l'anglais dans « English », l'allemand dans « German »,
l'italien dans « Italian », l'espagnol dans « Spanish - Spain ».

## Images et vidéo

Captures et vidéo : fichiers du projet, `captures/demo/` (faits par `tests/demo_vitrine.gd`,
voir [../demo.md](../demo.md)). Capsules et logos : dans ce dépôt, `marque/steam/`, faits par
`tools/marque/capsules.py` avec le logo final (voir [../../marque/README.md](../../marque/README.md)).

| Élément Steam | Taille | Fichier | État |
|---|---|---|---|
| Capsule d'en-tête | 920 × 430 | marque/steam/capsule-entete-920x430.png | prête |
| Petite capsule | 462 × 174 | marque/steam/capsule-petite-462x174.png | prête |
| Capsule principale | 1232 × 706 | marque/steam/capsule-principale-1232x706.png | prête |
| Capsule verticale | 748 × 896 | marque/steam/capsule-verticale-748x896.png | prête |
| Capsule bibliothèque | 600 × 900 | marque/steam/capsule-bibliotheque-600x900.png | prête |
| Annonces Steam (couverture, en-tête) | 800 × 450, 1920 × 622 | marque/steam/annonce-couverture-800x450.png, annonce-entete-1920x622.png | prêtes |
| Fond de page | 1438 × 810 | marque/steam/fond-page-1438x810.png | prête (facultatif) |
| Héros de bibliothèque | 3840 × 1240 | marque/steam/heros-bibliotheque-3840x1240.png | prêt (sans texte, comme Steam le demande) |
| Logo de bibliothèque | 1280 × 720, fond transparent | marque/steam/logo-bibliotheque-1280x720.png | prêt |
| Captures (5 au moins) | 1920 × 1080 | captures/demo/01 à 08 | prêtes |
| Bande-annonce | 1080p | captures/demo/miniblocs-bande-annonce-v2.mp4 (39 s, nouveau logo) | prête |

Ordre conseillé des captures : 01 village vu du ciel, 03 centre du village, 05 vue au sol,
06 soir au village, 07 foot et quartiers, 02 campagne à l'horizon, 04 démo pendant un
marché, 08 bilan. La première est celle qu'on voit au survol dans les listes.

Logo de bibliothèque : dans Steamworks, le placer en bas à gauche du héros. Steam refuse les capsules avec des notes,
des récompenses ou des mentions comme « Nouveau » ou « En promo ».

## Le jour où Steam donne l'App ID (liste de souhaits)

Une fois les 100 $ payés, Steamworks donne un numéro à MiniBlocs (l'App ID, par exemple
`1234560`). Il se reporte à quatre endroits pour que tous les boutons mènent à la liste de
souhaits :

| Où | Quoi changer |
|---|---|
| `scripts/edition/edition_demo.gd` | `const APP_ID := 0` → le numéro (bouton « Ajouter à ma liste de souhaits » de la démo et de son écran de fin) |
| Godot, Projet → Paramètres du projet | ajouter le réglage `steam/initialization/app_id` = le numéro (Workshop, succès) |
| `tools/site/construire.py` | `CONFIG["steam_miniblocs"]` = `https://store.steampowered.com/app/<numéro>/MiniBlocs/`, puis reconstruire et téléverser le site |
| Réseaux (bios YouTube, Discord, TikTok) | le même lien |

Ensuite, dans l'ordre :

1. Remplir la page (textes de ce dossier, capsules de `marque/steam/`, captures, bande-annonce).
2. Cliquer « Prête pour vérification » : Valve vérifie en quelques jours ouvrés.
3. Publier la page **Prochainement** : les joueurs peuvent l'ajouter à leur liste de souhaits.
4. Le même jour, publier l'annonce ci-dessous sur Steam (Événements et annonces), le site et
   les réseaux.
5. Créer la page développeur ManiGames (Steamworks → Homepage du développeur) avec le logo
   choisi, puis la lier à MiniBlocs.

### Annonce « La page est en ligne »

> **FR** : MiniBlocs a sa page Steam ! Choisis n'importe quel lieu sur Terre et n'importe
> quelle année depuis 1800, et bâtis ta ville au mètre près. Le jeu sort en accès anticipé
> en 2027. Ajoute-le à ta liste de souhaits : c'est le meilleur moyen de soutenir un jeu
> fait par une seule personne, et tu seras prévenu le jour de la sortie.
>
> **EN**: MiniBlocs now has a Steam page! Pick any spot on Earth and any year from 1800,
> and build your town one square metre at a time. The game launches in Early Access in
> 2027. Add it to your wishlist: it's the best way to support a game made by one person,
> and you'll be notified on launch day.

Images de l'annonce (Steam les demande) : couverture 800 × 450 et en-tête 1920 × 622,
`marque/steam/annonce-couverture-800x450.png` et `annonce-entete-1920x622.png`.

## Contenu généré par IA (questionnaire obligatoire)

Depuis 2024, Steam demande de déclarer le contenu fait avec une IA. Le code, les modèles,
les sons et les textes de MiniBlocs ont été écrits avec l'aide de Claude, puis choisis et
testés par Gaël. Rien n'est généré par une IA pendant la partie. Proposition de texte :

> FR : Le code, les modèles 3D, les sons, la musique et les textes ont été réalisés avec
> l'aide d'outils d'IA, puis revus et testés par le développeur. Aucun contenu n'est généré
> par une IA pendant la partie.
>
> EN: Code, 3D models, sounds, music and text were made with the help of AI tools, then
> reviewed and tested by the developer. No content is generated by AI while playing.

## Classification et questionnaire de contenu

Rien de violent ni de sexuel. Le jeu montre la mort de vieillesse (pompes funèbres,
cimetières) et des incendies : à décrire honnêtement si Steam le demande ; cela ne place
pas le jeu en contenu pour adultes.

## Calendrier conseillé (sortie en 2027)

1. Ouvrir la page « Prochainement » dès que possible : les listes de souhaits s'accumulent
   pendant des mois, c'est le chiffre qui compte le plus pour la visibilité à la sortie.
2. Publier la démo guidée (30 min) sur Steam quelques semaines avant un **Steam Next Fest**
   (il y en a habituellement trois par an, en février, juin et octobre ; vérifier les dates
   et la date limite d'inscription dans Steamworks).
3. Sortie quelques mois après ce Next Fest.

## À décider par Gaël

- ~~Nom du développeur~~ : **ManiGames** (choisi le 15 novembre 2026).
- **Accès anticipé** en 2027 (choisi le 15 novembre 2026) : la section « Accès anticipé » des fiches est à coller.
- Prix : **19,99 € / 19,99 $** pour l'accès anticipé, puis 24,99 € en version complète (validé par Gaël le 15 novembre 2026).
- Pages anglaise, allemande, italienne et espagnole : le jeu est traduit dans ces quatre langues (Options → Jeu → Langue). Les publier quand **toute** l'application est traduite (menus, panneaux, aide F1, tutoriel, démo, nouvelles, noms des bâtiments). Contrôle à faire avant : `python3 tools/langue/extraire.py --manquants en` (puis `de`, `it`, `es`) ne doit plus lister que des noms propres et du code (voir [../langues.md](../langues.md)), puis parcourir chaque écran dans la langue pour repérer les textes restés en français.

## Prix conseillé

Repères (prix de lancement en accès anticipé, de mémoire, à revérifier sur Steam) : Timberborn
et Against the Storm autour de 20 €, Farthest Frontier et Foundation entre 25 et 30 €,
Manor Lords 40 € (gros succès attendu), Cities: Skylines autour de 28 € en version complète.
Les petits jeux de construction « cosy » (Islanders, Townscaper) sont à 5 €.

MiniBlocs a énormément de contenu, mais c'est un premier jeu, par une seule personne, en
low-poly et en accès anticipé : les joueurs sont plus exigeants au-dessus de 20 €.

- **19,99 € (19,99 $)** au lancement de l'accès anticipé, avec une remise de lancement de 10 à 15 %.
- **24,99 €** à la sortie de la version complète (ce que promet la FAQ « le prix augmentera légèrement »).
- Laisser Steam proposer les prix régionaux (CHF, £, etc.) à partir du prix en dollars.
- La démo reste gratuite.

## Succès Steam

62 succès prêts : `succes-steam.csv` (nom de l'API `MB_…`, noms et descriptions FR / EN,
caché) et `succes-icones/` (256 × 256, couleur et grisée) à recopier dans Steamworks
(Statistiques et succès). Le jeu les reporte tout seul avec GodotSteam. Détails :
[../succes-manette.md](../succes-manette.md).
