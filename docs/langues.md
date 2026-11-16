# Langues : français, anglais, allemand, italien, espagnol

Le jeu est écrit en français. Il est traduit en anglais, allemand, italien et espagnol
(même ton : réaliste, avec une touche d'humour).

## Changer de langue

Menu principal (ou menu pause) → **Options → Jeu → Langue** : *Français*, *English*, *Deutsch*, *Italiano* ou *Español*.
Le changement est immédiat, sans relancer : menus, panneaux, info-bulles, messages,
conseiller, fiches des bâtiments… Le choix est gardé dans `user://options.cfg`.
Au tout premier lancement, le jeu prend la langue du système (anglais si elle n'est pas
connue). Les sauvegardes ne dépendent pas de la langue.

En allemand, italien et espagnol, la virgule décimale reste et les milliers prennent un
point (« 1 234,5 € » → « 1.234,5 € ») ; les dates suivent la langue (« 10. Juni 2026 »,
« 10 giu. 2026 », « 10 jun. 2026 »), le journal aussi (« Dienstag, 10. Juni 2026 »…).
Les touches sont données en WASD et Q / E, comme en anglais (mêmes positions sur les
claviers QWERTZ, QWERTY italien et espagnol).

En anglais, les nombres passent à l'anglaise (« 1 234,5 € » → « 1,234.5 € »), les dates
aussi (« 10 juin 2026 » → « 10 Jun 2026 »). Les touches sont données en QWERTY
(**WASD** et **Q / E** au lieu de ZQSD et A / E) : le jeu lit la position des touches, pas
la lettre, donc les mêmes touches marchent sur les deux claviers.

Restent en français, volontairement : les noms propres (villages, quartiers, clubs,
artistes, cinémas, zoos, prénoms et noms des habitants, animaux du zoo). Les villes du
monde qui ont un nom usuel dans la langue le prennent (Genève → Genf, Ginevra, Ginebra).

## Comment ça marche

- `assets/langues/en.json`, `de.json`, `it.json`, `es.json` : `{"textes": {"texte français": "texte traduit"}}`,
  environ 11 000 textes chacun. Le texte français est la clé (comme gettext).
- `scripts/langue/traduction_auto.gd` (`TraductionAuto`, une `Translation` de Godot) :
  - texte exact ;
  - **modèles** : une clé avec `%d`, `%s`, `%.1f` devient un motif. « Caisse : 1 250 € »
    trouve « Caisse : %s » → « Funds: %s ». Les `%s` trouvés sont traduits à leur tour.
    La traduction peut réordonner les champs avec `%1$s`, `%2$d`… (et laisser tomber
    les `%s` de pluriel français) ;
  - sinon le texte est coupé par lignes puis aux séparateurs (` · `, ` — `, ` : `, `, `…),
    en regroupant les morceaux qui forment ensemble une clé connue ; capitales, puces,
    flèches ▴ et ponctuation sont gardées ;
  - un cache garde les textes déjà traduits.
- `scripts/langue/langue.gd` (`Langue`) : `Langue.activer("en")` charge la traduction une
  fois et change la langue de Godot ; tous les `Label`, `Button`, info-bulles, onglets,
  `OptionButton`, `Label3D` se traduisent tout seuls (traduction automatique de Godot).
  `Langue.t(texte)` traduit un texte dessiné à la main. En français, aucune traduction
  n'est branchée : rien ne change et rien ne coûte.
- `OptionsJeu.langue` (`scripts/menu/options_jeu.gd`) : la langue choisie.

## Ajouter des textes (ou une langue)

Les nouveaux textes du jeu s'affichent en français tant qu'ils ne sont pas traduits.

```
python3 tools/langue/extraire.py --manquants en   # ou de, it, es
```

écrit `tools/langue/manquants_en.txt` (ou `manquants_de.txt`…) (« fichier | texte ») : les textes qui ne sont pas
encore dans le JSON de la langue. On les traduit et on les ajoute au JSON. Une partie de la liste
est normale : noms propres, noms de nœuds, code des icônes SVG.

Pour une nouvelle langue : `assets/langues/<code>.json` au même format, puis une ligne
dans `Langue.LANGUES` (`scripts/langue/langue.gd`).

## Test

`godot --headless --path . --script res://tests/langue_test.gd` : les 4 fichiers bien formés
(mêmes champs `%d` / `%s` qu'en français), textes exacts, modèles, lignes,
séparateurs, nombres, dates, touches, `Label` et `Button` traduits en anglais, allemand,
italien et espagnol (nombres « 1.234,5 », dates), cinq langues dans Options, retour au
français.
Il affiche `TEST OK`.
