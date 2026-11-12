# Personnages arrondis

Les habitants ne sont plus faits de boîtes : ce sont des personnages low-poly
arrondis, modelés dans Blender par code, du bébé à la personne âgée, de toutes
corpulences, couleurs de peau, origines et tenues.

## Ce qu'il y a

- **28 corps** (`assets/modeles/personnages/corps/`) : bébé (0-2 ans), petit
  (3-6), enfant (7-11), ado, adulte, senior (68 ans et plus, un peu voûté) ;
  femmes et hommes à partir de l'adolescence ; minces, moyens, ronds, forts
  (ventre, hanches, épaules, bras et cuisses changent).
- **16 coiffures** (`cheveux/`) : rasée, courte, raie, boucles, afro, mi-longue,
  longue, queue de cheval, chignon, tresses, locks, calvitie, bébé, foulard,
  turban, casquette.
- **4 vêtements longs** (`habits/`) : jupe, robe, jupe longue, robe longue
  (boubou, thobe, abaya, kurta…). Sinon : pantalon ou short.
- Environ 1 200 triangles par corps, 40 à 230 par coiffure.

La taille suit l'âge réel (une fillette de 4 ans fait environ 1,05 m, un ado de
15 ans 1,62 à 1,70 m), avec ± 3,5 % d'un adulte à l'autre.

## Couleurs

Les faces pointent une petite texture de **rôles** (`palette_roles.png`) ; le
shader `scripts/habitants/silhouette.gdshader` remplace chaque rôle par la
couleur de la personne : peau, cheveux, haut, bas, chaussures, accessoire
(foulard, turban, casquette), manches longues ou bras nus, jambes couvertes ou
mollets nus.

- 12 teintes de peau, de la plus claire à la plus foncée. Chaque région du monde
  (celle des prénoms) a sa teinte la plus fréquente, mais toutes les couleurs
  existent partout (environ 15 % des foyers au hasard).
- Un foyer partage sa teinte de base et sa couleur de cheveux (les enfants
  ressemblent à leurs parents), avec un peu de variation.
- Les cheveux grisonnent à partir de la quarantaine, blanchissent après 70 ans ;
  la calvitie vient avec l'âge chez les hommes.
- L'apparence est **stable** : elle se calcule à partir du numéro de
  l'habitant, de son foyer, de son âge et de sa région. Rien à sauvegarder.

## Dans le jeu

- **Passants** (habitants en trajet à pied) : leur vraie apparence, ils marchent
  (jambes, bras).
- **Habitants dans les pièces** : debout, assis, couchés, à leur taille.
- **Piétons d'ambiance** (trafic) : personnages variés au hasard.
- **Vue au sol** : le personnage du joueur ; quand on prend la place d'un
  habitant, on prend aussi son apparence.

## Pour le code

```gdscript
var n := Silhouettes.pour_habitant(pop, pid)          # apparence de l'habitant
var n2 := Silhouettes.creer(Silhouettes.apparence(pid, age, "F", "afrique", foyer))
Silhouettes.habiller(n, {"haut": Color.WHITE, "bas": "1d3557", "manches": true})  # tenue de métier
Silhouettes.poser(n, "assis")        # "debout", "assis", "couche"
Silhouettes.marcher(n, phase, 1.0)   # balancement de marche
var os := Silhouettes.os(n)          # articulations
os.avant_bras_d.rotation.x = -1.2    # négatif = vers l'avant ; rotation.z écarte
```

Squelette (nœuds séparés, origine exactement à l'articulation, regard vers +Z,
pieds en y = 0) :

```
bassin ─ jambe_g/d ─ tibia_g/d
       ├ habit (jupes et robes)
       └ torse ─ tete ─ cheveux
               └ bras_g/d ─ avant_bras_g/d ─ main_g/d (vide : outil tenu)
```

Si les `.glb` ne sont pas importés, `Silhouettes.creer()` construit le même
squelette en blocs, et les anciens modèles restent utilisés.

## Refaire les modèles dans Blender

```
blender --background --factory-startup --python tools/blender/personnages_lowpoly.py -- \
    --dossier assets/modeles/personnages
```

(ou `python tools/blender/personnages_lowpoly.py -- …` avec `pip install bpy`).
`--apercu chemin.png` fait une image d'une rangée de personnages.

## Tester

- Ouvrir `scenes/vitrine_personnages.tscn` et lancer la scène (F6) : une foule
  qui se promène, la rangée des âges, des tenues de métier, un banc. R : nouvelle
  foule ; 1-4 : vues ; Espace : marche/arrêt ; glisser à la souris : tourner.
- Test automatique : `godot --headless --path . --script res://tests/silhouettes_test.gd`.
- Captures : `godot --path . --script res://tests/silhouettes_vitrine.gd -- --prefixe captures/personnages`.
