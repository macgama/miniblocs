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

## Tenues selon la situation (époque, saison, métier, région)

`scripts/habitants/tenues.gd` (`Tenues`) habille chacun selon le moment :

- **Époque** (année de la partie) : au XIXe siècle (avant 1870) redingotes et
  vestes ouvertes sur un plastron, hauts-de-forme, feutres et casquettes ;
  robes et jupes longues, coiffes, capotes et tabliers pour les femmes. Vers
  1900 : canotiers l'été, melons, casquettes de titi, chapeaux cloche ; puis
  costumes, robes et carreaux des Trente Glorieuses ; tenues d'aujourd'hui
  ensuite. Couleurs sourdes autrefois, plus vives ensuite.
- **Saison et météo** (température et pluie du jour) : sous 10 °C manteaux,
  bonnets et écharpes, plus de short ; au-dessus de 21 °C bras nus, shorts,
  casquettes et chapeaux de soleil ; sous la pluie, une partie des passants
  sortent le parapluie (tenu au-dessus de la tête, même en marchant).
- **Âge** : cartable (autrefois) ou sac à dos des écoliers, canne de
  certaines personnes âgées, sac à main.
- **Région** : tissus wax d'Afrique de l'Ouest, chapeaux coniques d'Asie, en
  plus des foulards, turbans et robes longues déjà présents.
- **Métiers** : un uniforme par époque pour pompiers (casque de laiton → casque
  F1 et bandes réfléchissantes ; casque américain aux Amériques), policiers
  (bicorne du gendarme, képi, casquette), médecins (redingote puis blouse et
  stéthoscope), infirmières (robe longue, tablier et coiffe → tunique),
  ouvriers (chemise et casquette → bleu de travail → gilet haute visibilité et
  casque), mineurs, agriculteurs, boulangers, cuisiniers, bouchers, serveurs,
  cadres, chauffeurs, agents de gare, éboueurs, bûcherons, pêcheurs,
  jardiniers, artisans, enseignants, pompes funèbres… Les autres métiers
  gardent les couleurs de `Figurine.TENUES`.

Pour rester léger, rayures, carreaux, wax, bandes réfléchissantes, gilets,
tabliers et vestes ouvertes sont **peints par le shader** (`motif`,
`motif_couleur`), sans géométrie. Seuls le chapeau et un ou deux petits objets
ajoutent un maillage (partagé entre tous, moins de 400 triangles, sans ombre).
Les figurines sans habitant (secours, ouvriers des chantiers et des réseaux)
sont désormais elles aussi des personnages arrondis, plus des blocs.

```gdscript
var look := Silhouettes.apparence(pid, age, "F", "europe", foyer)       # contexte du moment
var look2 := Silhouettes.apparence(pid, age, "F", "europe", foyer, {})  # sans adaptation
Tenues.metier(look, "pompier", "F", Tenues.contexte())                  # uniforme de l'époque
var fig := Figurine.look_de(pid, "medecin", false, pop)                 # look complet d'un employé
Tenues.force = {"annee": 1850, "temp": -3.0, "pluie": 0.6}             # imposer (vitrine, tests)
```

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
  foule ; 1-4 : vues ; E : époque (1850, 1905, 1960, aujourd'hui) ; T : temps
  (doux, hiver, été, pluie) ; Espace : marche/arrêt ; glisser à la souris : tourner.
- Test automatique : `godot --headless --path . --script res://tests/silhouettes_test.gd`
  et `res://tests/tenues_test.gd`.
- Captures des tenues : `godot --path . --script res://tests/tenues_vitrine.gd --
  --prefixe captures/tenues/1850 --annee 1850 --temp -2 --pluie 0.5`.
- Captures : `godot --path . --script res://tests/silhouettes_vitrine.gd -- --prefixe captures/personnages`.
