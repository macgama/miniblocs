# Catalogue daté de MiniBlocs

Tout ce qui se construit ou se pose dans le jeu, avec son année d'apparition et ses évolutions.

| Fichier | Contenu |
|---|---|
| [catalogue.md](catalogue.md) | Le catalogue complet, famille par famille, lisible sur GitHub |
| [catalogue.html](catalogue.html) | La même chose en page web autonome : recherche, filtre par famille, curseur « Partie en 1800 … 2040 » |
| [catalogue.json](catalogue.json) | Les données brutes, pour d'autres outils (site, page Steam) |
| [dates-ajoutees.md](dates-ajoutees.md) | Les années données le 16 novembre 2026 aux objets qui n'en avaient pas |

En jeu : **F7** (ou menu Infos → Catalogue). Le curseur « Partie en » part de l'année de la partie et
montre ce qui existe à n'importe quelle année.

## Familles

Bâtiments (catalogue B, bible des styles, bible Blender, époques), véhicules, voies, stations et ports,
lignes électriques et conduites, agriculture (machines de chaque époque, cultures, élevages), grands-huit
et attractions sur l'eau (types et figures), aménagements de l'Atelier (bassins, rails, gradins, terrains),
portes et fenêtres, toits, matériaux, décors (G), meubles, objets de spectacle.

Ne sont pas dans le catalogue : les créations du joueur (Mes créations, modèles de l'Atelier, de toutes les
époques), les objets de musée (des pièces anciennes exposées, sans date d'invention) et les animaux.

## Évolutions

- **Agrandissement** : un bâtiment qui accueille du monde ou produit passe au niveau 2 (+50 % de capacité,
  60 % de son prix) puis au niveau 3 (le double, 80 %) ; il se rénove pour 15 %.
- **Variantes** : nombre de façades différentes d'un même modèle.
- **Même rôle selon l'époque** : la lignée des bâtiments qui tiennent le même rôle (Remise des pompes 1800 →
  Caserne en briques 1880 → Caserne de pompiers 1950).
- **Véhicules et machines agricoles** : le modèle de chaque époque (ambulance à chevaux → années 30 → années 70…),
  ou celui qui roule à la place avant l'invention.
- **Décors posés tout seuls** : leur équivalent d'époque (réverbère à gaz au lieu du lampadaire, barque au lieu
  du hors-bord, meule au lieu des bottes rondes).

## Régénérer

Le catalogue se calcule à partir des données du jeu (`scripts/catalogue/catalogue_jeu.gd`) : après un ajout
de bâtiment, de véhicule ou de décor, relancer

```
godot --headless --path . --script res://tools/catalogue/export_catalogue.gd
```

Les années des objets qui n'en avaient pas sont dans `scripts/epoques/epoques_objets.gd` (EpoquesObjets).
Un nouveau bâtiment sans `annee`, hors des tables, est signalé par `tests/catalogue_test.gd` (« aucune année devinée »).
