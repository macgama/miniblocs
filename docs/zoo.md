# Zoo (première version)

Le troisième univers de loisirs de MiniBlocs : un parc zoologique qui vit avec
la ville. Il s'inspire des grands jeux de zoo (enclos tracés à la main, habitat
peint, bien-être détaillé par animal, vue des visiteurs), sans en copier ni
les noms ni les modèles. Tous les animaux sont des modèles low-poly faits dans
Blender (`tools/blender/decors/zoo.py`).

**Ouvrir :** barre du bas → **Loisirs ▴ → Zoo**, ou **Maj + Z**.

## Fonder le zoo

1. Onglet **Bâtiments** (ou Construire → Zoo) → **Entrée du zoo**, au bord
   d'une route. L'entrée fonde le zoo ; tout le reste se pose à **moins de
   400 m** d'elle, sans route.
2. Onglet **Visiteurs** : le bouton Chemin ouvre l'outil chemin piéton pour
   relier l'entrée aux enclos. Belvédères et vitres donnent la meilleure vue.

## Les enclos (onglet Enclos)

- **Tracer** : un clic à chaque coin, clic sur le premier point ou **Entrée**
  pour fermer, **glisser** pour un rectangle, **Retour arrière** retire le
  dernier coin. Le prix (au mètre de barrière) s'affiche pendant le tracé.
- **9 barrières**, chacune avec une hauteur, une solidité (niveau 1 à 5), une
  vue et un prix : barrière en bois, clôture électrique, grillage, palissade en
  rondins, grillage renforcé, volière couverte, paroi vitrée, mur en béton,
  douve et muret. Les grimpeurs ont besoin d'une barrière haute ou couverte,
  les nageurs ne sont pas arrêtés par une douve.
- **Barrière** change la barrière d'un enclos ; **Démolir** le retire (les
  animaux restent, mais ils sont libres…).
- La fiche de l'enclos donne la surface, l'état de la barrière, la propreté,
  les abris, les jouets et arbres, et la part de chaque sol.

## L'habitat (onglet Terrain)

Pinceaux de sol (herbe, forêt, savane sèche, sable, roche, neige, marais),
**bassin** (creuser l'eau), **remblai**, **relief** (Maj : lisser), **arbres**
et **arrachage**. Rayon réglable. Les travaux sont payés par la ville.

## Les animaux (onglet Animaux)

- **34 espèces** : Afrique (lion, éléphant, girafe, zèbre, rhinocéros,
  hippopotame, autruche, suricate, gorille, chimpanzé…), Asie (tigre, panda,
  panda roux, orang-outan, tapir…), Europe (ours brun, loup, bison), Amériques,
  Océanie (kangourou, koala), pôles (ours polaire, manchot, otarie, renne) et
  une mini-ferme. Filtre par continent.
- Chaque espèce a sa fiche : prix, statut UICN, taille de groupe, surface par
  animal, barrière minimale, nage, escalade.
- Clic sur l'espèce puis dans l'enclos (**Maj + clic** : un groupe entier).
- **Bien-être** détaillé : espace, sols, eau, abri, groupe, nourriture,
  propreté, enrichissement, température, tranquillité, avec les problèmes en
  clair (« Abri trop petit : 30 places pour 48 »).
- Chaque animal a un nom, un sexe, un âge et une santé ; on peut le vendre,
  l'échanger, le relâcher, le déplacer ou lui donner un contraceptif.

## Génétique

Code : `scripts/zoo/zoo_genetique.gd` (ZooGenetique), généalogie dans
`ZooSysteme.genealogie`.

- **Quatre gènes** par animal, de -1 à +1 (0 = moyenne de l'espèce) :
  **taille** (le modèle est un peu plus grand ou plus petit), **santé**
  (maladies plus ou moins fréquentes), **fertilité** (chances d'avoir des
  petits, taille de la portée), **longévité** (±15 % de vie).
- Un animal acheté au marché est un **fondateur** (lignée inconnue, sans lien
  avec les autres). Un petit hérite de la moyenne de ses deux parents, plus un
  peu de hasard. La généalogie garde les parents même vendus, morts ou relâchés.
- **Parenté** (coefficient de Malécot) : père × fille ou frère × sœur = 25 %,
  demi-frère × demi-sœur = 12,5 %, cousins = 6,25 %. La **consanguinité** d'un
  petit est la parenté de ses parents. Elle baisse la santé, la fertilité et la
  longévité ; dès 12,5 %, une **tare héréditaire** peut apparaître (cœur
  fragile, hanches faibles…).
- **Diversité génétique** d'un groupe (fiche de l'enclos) = 1 − parenté
  moyenne : 2 fondateurs = 75 %, 10 = 95 %. Les animaux venus d'ailleurs la
  font remonter.
- Les **conseils** signalent les couples à risque (« Simba et Nala sont
  proches parents ») ; le bouton **Contra.** met un animal sous contraception.
- Infobulle d'un animal : ses gènes, ses parents, son origine, sa
  consanguinité, sa valeur pour l'élevage.

## Échanges (onglet Échanges)

- **Réseau d'élevage** : douze zoos partenaires (inventés) publient tous les
  quelques jours des offres (un animal d'une autre lignée, moins cher que le
  marché) et des demandes (ils cherchent une espèce, parfois un sexe). Envoyer
  un animal de lignée rare rapporte plus d'argent et du prestige. Les offres
  durent 20 jours. Attention : le réseau peut proposer le petit d'un animal
  que vous lui avez cédé, l'onglet le signale (« Apparenté à vos animaux »).
- **Entre zoos de la carte** : bouton **Échanger** sur un animal, choisir un
  autre zoo et un prix (0 = don). En solo, tous les zoos sont à vous : l'animal
  part tout de suite. Sur une **carte entre amis**, le maire de la ville de
  l'autre zoo accepte (en choisissant l'enclos) ou refuse ; la ville qui reçoit
  paie celle qui donne.
- **Arrivées** : les animaux rapportés par les expéditions (ou un sauvetage)
  attendent un enclos ; on les place ou on les cède au réseau.

## Remise en liberté

- Espèces menacées seulement (statut UICN Vulnérable ou plus), adultes, en
  forme (bien-être et santé ≥ 60), sans tare ni forte consanguinité.
- Coût 2 500 € (transport, colliers émetteurs). **Prestige** tout de suite,
  puis **60 jours de suivi** : s'il s'adapte (chance selon sa santé, ses gènes,
  sa forme, et s'il est né sauvage), prestige et dons en plus. Le suivi est
  dans l'onglet Échanges, et les réussites comptent dans la note
  « Conservation ».

## Branchement pour les expéditions

`ZooSysteme.instance.accueillir(esp, zoo := -1, origine := "expedition", extra := {})`

- `esp` : une espèce de `ZooEspeces.ESPECES` (sinon refusée, renvoie 0) ;
- `zoo` : l'entrée du zoo (-1 : le premier) ;
- `origine` : "expedition", "sauvetage", "sauvage"… (animal sauvage : gènes
  plus variés, aucun lien avec les animaux en captivité) ;
- `extra` : "nom", "f" (femelle), "age" (ans), "genes", "enclos" (placé
  directement), "texte" (message affiché).
- Renvoie l'id de l'arrivée (> 0, à placer dans l'onglet Échanges), ou
  `-id` de l'animal s'il a été placé directement.

## Bâtiments et personnel

| Bâtiment | Rôle |
|---|---|
| Abris (bois, savane, grotte, réfrigéré, serre tropicale, maison des éléphants) | places à l'abri, chaud ou froid |
| Poste des soigneurs | repas à 8 h et 15 h, nettoyage des enclos (1 soigneur pour 20 animaux) |
| Cuisine et réserve | nourriture moins chère (sinon livraison ×1,4) |
| Clinique vétérinaire | soigne les animaux malades |
| Atelier d'entretien | répare les barrières qui s'usent |
| Belvédère, kiosque pédagogique | vue sur les enclos, conservation |
| Restaurant, glaces, buvette, boutique, toilettes, pique-nique | besoins et dépenses des visiteurs |

Cinq métiers nouveaux : soigneur animalier, vétérinaire de zoo, technicien,
agent d'accueil et animateur.

## Ce qui peut mal tourner

- **Évasions** : barrière trop basse, trop faible ou usée. L'animal sort et se
  promène ; un fauve en liberté inquiète les habitants du quartier (avis en baisse).
- **Prédation** : un fauve et ses proies dans le même enclos.
- **Maladies** : enclos sale, faim, stress. Sans clinique, on perd des animaux.
- **Naissances** quand le bien-être est bon (gestation et portée réelles).

## Visiteurs et argent

- Ouvert de 9 h à 19 h d'avril à septembre, de 10 h à 17 h le reste de
  l'année. Plus de monde le week-end et l'été, moins sous la pluie.
- **Note en étoiles** : variété des espèces, bien-être, vue sur les enclos,
  restaurants et toilettes, prix de l'entrée (22 € par défaut), conservation.
- Recettes (billets, restauration et boutiques, dons pour la conservation) et
  dépenses (nourriture, salaires, entretien) passent dans le budget de la
  ville. Le zoo compte dans l'avis des habitants (thème Loisirs) et dégage un
  peu d'odeur.
- Les visiteurs marchent dans les allées et pensent tout haut (« Lion
  d'Afrique, vu de tout près. Magique. »).

## Décors (touche G)

Les 29 animaux et 10 objets d'enclos (tronc d'escalade, plateforme pour
singes, mangeoire haute, râtelier à foin, balle d'enrichissement, rocher
chauffant, piscine pour ours, abri de paille, panneau d'espèce, longue-vue)
sont aussi dans le panneau Décors : catégories **Animaux du zoo** et **Objets
des enclos**. Un objet posé dans un enclos compte comme jouet.

## Tests

```
godot --headless --path . --script res://tests/zoo_test.gd
godot --headless --path . --script res://tests/zoo_genetique_test.gd
xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/zoo_vitrine.gd -- --dossier captures/zoo
```
