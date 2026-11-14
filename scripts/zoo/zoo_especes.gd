class_name ZooEspeces
extends RefCounted
## Zoo : espèces (besoins, prix, attrait), sols des habitats et barrières.
##
## Chiffres : ordres de grandeur des zoos européens (surfaces recommandées,
## régimes, durées de vie), arrondis pour le jeu.
##
## Champs d'une espèce :
## - "decors" : modèles (Decors, catégories zoo, animaux) : adulte, puis variantes
##   (femelle, petit) ; "taille" : place prise dans un abri (1 petit à 8 énorme) ;
## - "sols" : part idéale de chaque sol dans l'habitat (somme 1) ;
## - "m2" : surface par animal ; "groupe" : [min, max] d'animaux de l'espèce ;
## - "eau" : part d'eau (bassin) souhaitée ; "nage" : passe les douves à la nage ;
## - "niveau" : solidité de barrière exigée (1 à 5), "h" : hauteur (m) ;
##   "grimpe" : passe un grillage non couvert ; "abri" : a besoin d'un abri ;
## - "climat" : [min, max] °C supportés sans abri ;
## - "regime" (voir REGIMES), "kg" : nourriture par jour et par animal ;
## - "prix" (€ à l'achat), "attrait" (ce qui fait venir les visiteurs) ;
## - "vie", "maturite" (ans), "gestation" (jours), "portee" ; "uicn" : statut ;
## - "proie" : peut être mangée par un carnivore du même enclos ;
##   "fauve" : carnivore dangereux (chasse les proies, panique en ville).

const SOLS := {
	"herbe": {"nom": "Herbe", "kind": 6, "couleur": Color("7fb24a")},
	"foret": {"nom": "Sous-bois", "kind": 4, "couleur": Color("3f7232")},
	"broussailles": {"nom": "Savane sèche", "kind": 5, "couleur": Color("b8a85a")},
	"sable": {"nom": "Sable", "kind": 8, "couleur": Color("e0cf9e")},
	"roche": {"nom": "Rocher", "kind": 3, "couleur": Color("8e8a82")},
	"neige": {"nom": "Neige et glace", "kind": 13, "couleur": Color("eaf6fc")},
	"marais": {"nom": "Boue et marais", "kind": 9, "couleur": Color("6a5a3a")},
	"eau": {"nom": "Eau (bassin)", "kind": -1, "couleur": Color("4a90b8")},
}
const SOLS_ORDRE := ["herbe", "foret", "broussailles", "sable", "roche", "neige", "marais", "eau"]

## Kind du terrain (TerrainWorld.Kind) → sol du zoo.
const KIND_SOL := {0: "eau", 1: "eau", 2: "neige", 3: "roche", 4: "foret", 5: "broussailles", 6: "herbe", 7: "herbe",
	8: "sable", 9: "marais", 10: "marais", 11: "neige", 12: "sable", 13: "neige", 14: "herbe", 15: "eau", 16: "eau",
	17: "eau", 18: "eau"}

const REGIMES := {
	"herbivore": {"nom": "Foin, granulés, légumes", "prix_kg": 0.6},
	"feuilles": {"nom": "Branchages et feuillage", "prix_kg": 1.2},
	"bambou": {"nom": "Bambou frais", "prix_kg": 2.5},
	"carnivore": {"nom": "Viande", "prix_kg": 6.0},
	"poisson": {"nom": "Poisson", "prix_kg": 4.5},
	"omnivore": {"nom": "Fruits, légumes, viande", "prix_kg": 3.0},
	"fruits": {"nom": "Fruits et légumes", "prix_kg": 2.2},
	"insectes": {"nom": "Insectes et vers", "prix_kg": 12.0},
}

## Statuts de conservation (liste rouge) : bonus d'attrait et de prestige.
const UICN := {
	"LC": {"nom": "Préoccupation mineure", "bonus": 0.0},
	"NT": {"nom": "Quasi menacé", "bonus": 0.1},
	"VU": {"nom": "Vulnérable", "bonus": 0.2},
	"EN": {"nom": "En danger", "bonus": 0.35},
	"CR": {"nom": "En danger critique", "bonus": 0.5},
}

const CONTINENTS := {
	"afrique": "Afrique", "asie": "Asie", "europe": "Europe", "amerique": "Amériques", "oceanie": "Océanie",
	"polaire": "Régions polaires", "ferme": "Mini-ferme",
}

const ESPECES := {
	"lion": {"nom": "Lion d'Afrique", "decors": ["lion", "lionne"], "taille": 3, "cont": "afrique",
		"sols": {"herbe": 0.45, "broussailles": 0.35, "sable": 0.15, "eau": 0.05}, "m2": 250, "groupe": [2, 8], "eau": 0.04,
		"niveau": 4, "h": 3.0, "abri": true, "climat": [0, 42], "regime": "carnivore", "kg": 7.0, "prix": 18000,
		"attrait": 9.0, "vie": 16, "maturite": 3, "gestation": 110, "portee": 3, "uicn": "VU", "fauve": true,
		"desc": "Dort vingt heures par jour. Les quatre autres, il regarde les visiteurs comme on regarde une vitrine de boucherie."},
	"tigre": {"nom": "Tigre du Bengale", "decors": ["tigre"], "taille": 3, "cont": "asie",
		"sols": {"foret": 0.45, "herbe": 0.3, "eau": 0.15, "roche": 0.1}, "m2": 400, "groupe": [1, 3], "eau": 0.12, "nage": true,
		"niveau": 5, "h": 3.0, "grimpe": true, "abri": true, "climat": [-10, 40], "regime": "carnivore", "kg": 8.0,
		"prix": 30000, "attrait": 10.0, "vie": 18, "maturite": 4, "gestation": 105, "portee": 3, "uicn": "EN", "fauve": true,
		"desc": "Solitaire, nageur, grimpeur. Une douve ne l'arrête pas : il trouve ça rafraîchissant."},
	"elephant": {"nom": "Éléphant d'Afrique", "decors": ["elephant", "elephant", "elephanteau"], "taille": 8, "cont": "afrique",
		"sols": {"herbe": 0.4, "sable": 0.25, "marais": 0.15, "eau": 0.2}, "m2": 900, "groupe": [3, 10], "eau": 0.15,
		"niveau": 5, "h": 2.5, "abri": true, "climat": [5, 42], "regime": "herbivore", "kg": 120.0, "prix": 90000,
		"attrait": 12.0, "vie": 60, "maturite": 12, "gestation": 660, "portee": 1, "uicn": "EN",
		"desc": "Mange 120 kg par jour et en rend presque autant. Prévoir des soigneurs, et des brouettes."},
	"girafe": {"nom": "Girafe", "decors": ["girafe"], "taille": 6, "cont": "afrique",
		"sols": {"herbe": 0.5, "broussailles": 0.35, "sable": 0.15}, "m2": 500, "groupe": [3, 12], "eau": 0.0,
		"niveau": 3, "h": 2.0, "abri": true, "climat": [8, 42], "regime": "feuilles", "kg": 35.0, "prix": 40000,
		"attrait": 9.0, "vie": 25, "maturite": 4, "gestation": 450, "portee": 1, "uicn": "VU", "proie": true,
		"desc": "Cinq mètres de haut, et toujours la dernière à voir arriver la pluie."},
	"zebre": {"nom": "Zèbre des plaines", "decors": ["zebre"], "taille": 4, "cont": "afrique",
		"sols": {"herbe": 0.6, "broussailles": 0.3, "sable": 0.1}, "m2": 200, "groupe": [4, 15], "eau": 0.02,
		"niveau": 2, "h": 1.8, "abri": true, "climat": [0, 42], "regime": "herbivore", "kg": 9.0, "prix": 6000,
		"attrait": 5.0, "vie": 25, "maturite": 3, "gestation": 370, "portee": 1, "uicn": "NT", "proie": true,
		"desc": "Noir sur blanc ou blanc sur noir ? Les soigneurs ne sont toujours pas d'accord."},
	"rhinoceros": {"nom": "Rhinocéros blanc", "decors": ["rhinoceros"], "taille": 6, "cont": "afrique",
		"sols": {"herbe": 0.5, "marais": 0.3, "sable": 0.1, "eau": 0.1}, "m2": 600, "groupe": [1, 6], "eau": 0.08,
		"niveau": 5, "h": 1.8, "abri": true, "climat": [5, 42], "regime": "herbivore", "kg": 50.0, "prix": 70000,
		"attrait": 10.0, "vie": 40, "maturite": 6, "gestation": 480, "portee": 1, "uicn": "NT",
		"desc": "Deux tonnes et demie de myopie. Il charge d'abord et vérifie ensuite."},
	"hippopotame": {"nom": "Hippopotame", "decors": ["hippopotame"], "taille": 6, "cont": "afrique",
		"sols": {"eau": 0.5, "marais": 0.3, "herbe": 0.2}, "m2": 400, "groupe": [2, 8], "eau": 0.5, "nage": true,
		"niveau": 5, "h": 1.5, "abri": true, "climat": [10, 42], "regime": "herbivore", "kg": 40.0, "prix": 45000,
		"attrait": 8.0, "vie": 40, "maturite": 5, "gestation": 240, "portee": 1, "uicn": "VU",
		"desc": "Passe la journée dans l'eau et la nuit dans l'herbe. Bâille beaucoup, et ce n'est pas de l'ennui."},
	"autruche": {"nom": "Autruche", "decors": ["autruche"], "taille": 2, "cont": "afrique",
		"sols": {"sable": 0.5, "broussailles": 0.3, "herbe": 0.2}, "m2": 150, "groupe": [2, 10], "eau": 0.0,
		"niveau": 2, "h": 2.0, "abri": true, "climat": [-5, 45], "regime": "herbivore", "kg": 3.0, "prix": 3000,
		"attrait": 4.0, "vie": 40, "maturite": 3, "gestation": 42, "portee": 4, "uicn": "LC", "proie": true,
		"desc": "Ne met pas la tête dans le sable. Elle met les pieds dans le sable, à 70 km/h."},
	"suricate": {"nom": "Suricate", "decors": ["suricate"], "taille": 1, "cont": "afrique",
		"sols": {"sable": 0.7, "roche": 0.2, "broussailles": 0.1}, "m2": 8, "groupe": [5, 30], "eau": 0.0,
		"niveau": 4, "h": 1.2, "abri": true, "climat": [5, 42], "regime": "insectes", "kg": 0.05, "prix": 400,
		"attrait": 6.0, "vie": 12, "maturite": 1, "gestation": 70, "portee": 4, "uicn": "LC", "proie": true,
		"desc": "Il y en a toujours un debout pour surveiller. Les visiteurs croient que c'est pour eux."},
	"panda": {"nom": "Panda géant", "decors": ["panda"], "taille": 4, "cont": "asie",
		"sols": {"foret": 0.6, "herbe": 0.25, "roche": 0.15}, "m2": 400, "groupe": [1, 2], "eau": 0.02,
		"niveau": 4, "h": 2.5, "grimpe": true, "abri": true, "climat": [-10, 28], "regime": "bambou", "kg": 15.0,
		"prix": 120000, "attrait": 14.0, "vie": 25, "maturite": 6, "gestation": 140, "portee": 1, "uicn": "VU",
		"desc": "Prêté par la Chine, contre un loyer qui ferait pâlir un appartement parisien."},
	"panda_roux": {"nom": "Panda roux", "decors": ["panda_roux"], "taille": 1, "cont": "asie",
		"sols": {"foret": 0.75, "herbe": 0.25}, "m2": 60, "groupe": [1, 3], "eau": 0.0,
		"niveau": 3, "h": 2.5, "grimpe": true, "abri": true, "climat": [-15, 25], "regime": "bambou", "kg": 1.5,
		"prix": 9000, "attrait": 7.0, "vie": 14, "maturite": 2, "gestation": 130, "portee": 2, "uicn": "EN",
		"desc": "Plus petit, plus roux, et plus panda que l'autre, puisqu'on l'a nommé en premier."},
	"ours_brun": {"nom": "Ours brun", "decors": ["ours_brun"], "taille": 4, "cont": "europe",
		"sols": {"foret": 0.5, "herbe": 0.2, "roche": 0.15, "eau": 0.15}, "m2": 500, "groupe": [1, 4], "eau": 0.12, "nage": true,
		"niveau": 5, "h": 3.0, "grimpe": true, "abri": true, "climat": [-30, 30], "regime": "omnivore", "kg": 10.0,
		"prix": 12000, "attrait": 8.0, "vie": 30, "maturite": 5, "gestation": 220, "portee": 2, "uicn": "LC", "fauve": true,
		"desc": "Dort tout l'hiver. Au printemps, il a très faim et pas beaucoup de patience."},
	"ours_polaire": {"nom": "Ours polaire", "decors": ["ours_polaire"], "taille": 5, "cont": "polaire",
		"sols": {"neige": 0.45, "roche": 0.2, "eau": 0.35}, "m2": 700, "groupe": [1, 3], "eau": 0.35, "nage": true,
		"niveau": 5, "h": 3.0, "abri": true, "climat": [-40, 18], "regime": "poisson", "kg": 12.0, "prix": 60000,
		"attrait": 11.0, "vie": 25, "maturite": 5, "gestation": 240, "portee": 2, "uicn": "VU", "fauve": true,
		"desc": "Pelage blanc, peau noire, humeur variable selon la météo. Un été chaud l'agace."},
	"gorille": {"nom": "Gorille des plaines", "decors": ["gorille"], "taille": 4, "cont": "afrique",
		"sols": {"foret": 0.6, "herbe": 0.3, "roche": 0.1}, "m2": 250, "groupe": [3, 10], "eau": 0.0,
		"niveau": 5, "h": 3.0, "grimpe": true, "abri": true, "climat": [12, 35], "regime": "fruits", "kg": 18.0,
		"prix": 50000, "attrait": 11.0, "vie": 40, "maturite": 10, "gestation": 255, "portee": 1, "uicn": "CR",
		"desc": "Le dos argenté du groupe observe les visiteurs, puis leur tourne le dos. Critique muette."},
	"chimpanze": {"nom": "Chimpanzé", "decors": ["chimpanze"], "taille": 2, "cont": "afrique",
		"sols": {"foret": 0.6, "herbe": 0.3, "roche": 0.1}, "m2": 120, "groupe": [4, 20], "eau": 0.0,
		"niveau": 5, "h": 3.0, "grimpe": true, "abri": true, "climat": [12, 35], "regime": "omnivore", "kg": 4.0,
		"prix": 15000, "attrait": 9.0, "vie": 45, "maturite": 10, "gestation": 230, "portee": 1, "uicn": "EN",
		"desc": "Utilise des outils, ouvre les cadenas et rit des soigneurs. Barrière haute et couverte conseillée."},
	"orang_outan": {"nom": "Orang-outan", "decors": ["orang_outan"], "taille": 3, "cont": "asie",
		"sols": {"foret": 0.8, "herbe": 0.2}, "m2": 200, "groupe": [1, 5], "eau": 0.0,
		"niveau": 5, "h": 3.0, "grimpe": true, "abri": true, "climat": [15, 35], "regime": "fruits", "kg": 6.0,
		"prix": 40000, "attrait": 9.0, "vie": 45, "maturite": 12, "gestation": 250, "portee": 1, "uicn": "CR",
		"desc": "« Homme de la forêt » en malais. Il a besoin d'arbres, de cordes et d'un peu de solitude."},
	"lemurien": {"nom": "Lémurien catta", "decors": ["lemurien"], "taille": 1, "cont": "afrique",
		"sols": {"foret": 0.5, "roche": 0.3, "herbe": 0.2}, "m2": 25, "groupe": [4, 20], "eau": 0.0,
		"niveau": 3, "h": 3.0, "grimpe": true, "abri": true, "climat": [8, 38], "regime": "fruits", "kg": 0.3,
		"prix": 2500, "attrait": 6.0, "vie": 20, "maturite": 2, "gestation": 135, "portee": 1, "uicn": "EN",
		"desc": "Prend le soleil bras écartés, comme au yoga. Les visiteurs l'imitent, avec moins de grâce."},
	"manchot": {"nom": "Manchot de Humboldt", "decors": ["manchot"], "taille": 1, "cont": "amerique",
		"sols": {"eau": 0.5, "roche": 0.35, "sable": 0.15}, "m2": 6, "groupe": [8, 60], "eau": 0.5, "nage": true,
		"niveau": 2, "h": 1.2, "abri": true, "climat": [-5, 25], "regime": "poisson", "kg": 0.5, "prix": 800,
		"attrait": 7.0, "vie": 20, "maturite": 3, "gestation": 40, "portee": 2, "uicn": "VU", "proie": true,
		"desc": "Marche en smoking, nage en fusée. Le repas de 15 h attire plus de monde que le reste du zoo."},
	"otarie": {"nom": "Otarie de Californie", "decors": ["otarie"], "taille": 3, "cont": "amerique",
		"sols": {"eau": 0.6, "roche": 0.3, "sable": 0.1}, "m2": 100, "groupe": [3, 15], "eau": 0.6, "nage": true,
		"niveau": 3, "h": 1.5, "abri": true, "climat": [-5, 30], "regime": "poisson", "kg": 8.0, "prix": 15000,
		"attrait": 8.0, "vie": 25, "maturite": 5, "gestation": 340, "portee": 1, "uicn": "LC",
		"desc": "Aboie, applaudit et éclabousse le premier rang. Le premier rang revient quand même."},
	"loup": {"nom": "Loup gris", "decors": ["loup"], "taille": 2, "cont": "europe",
		"sols": {"foret": 0.55, "herbe": 0.3, "roche": 0.15}, "m2": 300, "groupe": [3, 10], "eau": 0.02,
		"niveau": 4, "h": 3.0, "abri": true, "climat": [-35, 32], "regime": "carnivore", "kg": 3.0, "prix": 4000,
		"attrait": 7.0, "vie": 14, "maturite": 2, "gestation": 63, "portee": 5, "uicn": "LC", "fauve": true,
		"desc": "Hurle à la lune et à la sirène des pompiers. La meute a un chef, et ce n'est pas le soigneur."},
	"bison": {"nom": "Bison d'Europe", "decors": ["bison"], "taille": 6, "cont": "europe",
		"sols": {"herbe": 0.55, "foret": 0.35, "marais": 0.1}, "m2": 800, "groupe": [3, 15], "eau": 0.02,
		"niveau": 4, "h": 2.0, "abri": false, "climat": [-35, 32], "regime": "herbivore", "kg": 30.0, "prix": 8000,
		"attrait": 6.0, "vie": 25, "maturite": 3, "gestation": 265, "portee": 1, "uicn": "NT", "proie": true,
		"desc": "Sauvé de justesse il y a cent ans : il en reste plus de dix mille, et il n'en a pas l'air ému."},
	"renne": {"nom": "Renne", "decors": ["renne"], "taille": 3, "cont": "polaire",
		"sols": {"neige": 0.4, "herbe": 0.3, "foret": 0.3}, "m2": 200, "groupe": [4, 15], "eau": 0.0,
		"niveau": 2, "h": 2.0, "abri": false, "climat": [-45, 22], "regime": "herbivore", "kg": 6.0, "prix": 3000,
		"attrait": 4.0, "vie": 15, "maturite": 2, "gestation": 225, "portee": 1, "uicn": "VU", "proie": true,
		"desc": "Très demandé en décembre. Le reste de l'année, il broute en attendant."},
	"kangourou": {"nom": "Kangourou roux", "decors": ["kangourou"], "taille": 2, "cont": "oceanie",
		"sols": {"herbe": 0.4, "broussailles": 0.4, "sable": 0.2}, "m2": 120, "groupe": [3, 15], "eau": 0.0,
		"niveau": 3, "h": 2.2, "abri": true, "climat": [-2, 42], "regime": "herbivore", "kg": 3.0, "prix": 3500,
		"attrait": 6.0, "vie": 20, "maturite": 2, "gestation": 33, "portee": 1, "uicn": "LC", "proie": true,
		"desc": "Saute deux mètres de haut. La barrière de 1,20 m, c'était une mauvaise idée."},
	"koala": {"nom": "Koala", "decors": ["koala"], "taille": 1, "cont": "oceanie",
		"sols": {"foret": 0.9, "herbe": 0.1}, "m2": 40, "groupe": [1, 4], "eau": 0.0,
		"niveau": 2, "h": 2.0, "grimpe": true, "abri": true, "climat": [5, 38], "regime": "feuilles", "kg": 0.5,
		"prix": 25000, "attrait": 9.0, "vie": 15, "maturite": 3, "gestation": 35, "portee": 1, "uicn": "VU",
		"desc": "Dort 20 heures par jour et ne mange que de l'eucalyptus, livré par avion. Coûteux, mais adoré."},
	"flamant": {"nom": "Flamant rose", "decors": ["flamant"], "taille": 1, "cont": "afrique",
		"sols": {"eau": 0.55, "marais": 0.3, "sable": 0.15}, "m2": 10, "groupe": [10, 60], "eau": 0.5,
		"niveau": 2, "h": 1.2, "abri": true, "climat": [-5, 42], "regime": "insectes", "kg": 0.25, "prix": 1500,
		"attrait": 6.0, "vie": 40, "maturite": 4, "gestation": 30, "portee": 1, "uicn": "LC", "proie": true,
		"desc": "Rose grâce aux crevettes. Sans elles, il pâlit, et les visiteurs demandent si c'est un héron."},
	"crocodile": {"nom": "Crocodile du Nil", "decors": ["crocodile"], "taille": 4, "cont": "afrique",
		"sols": {"eau": 0.55, "sable": 0.3, "marais": 0.15}, "m2": 120, "groupe": [1, 6], "eau": 0.55, "nage": true,
		"niveau": 5, "h": 1.5, "abri": true, "climat": [20, 45], "regime": "carnivore", "kg": 1.5, "prix": 12000,
		"attrait": 8.0, "vie": 70, "maturite": 12, "gestation": 90, "portee": 6, "uicn": "LC", "fauve": true,
		"desc": "Mange une fois par semaine et ne bouge pas le reste du temps. Les visiteurs restent pour voir. En vain."},
	"tortue_geante": {"nom": "Tortue géante", "decors": ["tortue_geante"], "taille": 3, "cont": "amerique",
		"sols": {"herbe": 0.4, "sable": 0.3, "marais": 0.2, "eau": 0.1}, "m2": 60, "groupe": [1, 8], "eau": 0.05,
		"niveau": 2, "h": 0.8, "abri": true, "climat": [15, 40], "regime": "herbivore", "kg": 3.0, "prix": 20000,
		"attrait": 6.0, "vie": 150, "maturite": 25, "gestation": 120, "portee": 8, "uicn": "VU",
		"desc": "A connu trois directeurs du zoo et en enterrera sans doute deux autres."},
	"tapir": {"nom": "Tapir de Malaisie", "decors": ["tapir"], "taille": 4, "cont": "asie",
		"sols": {"foret": 0.45, "marais": 0.25, "eau": 0.3}, "m2": 300, "groupe": [1, 3], "eau": 0.25, "nage": true,
		"niveau": 3, "h": 1.5, "abri": true, "climat": [12, 38], "regime": "fruits", "kg": 12.0, "prix": 15000,
		"attrait": 6.0, "vie": 30, "maturite": 4, "gestation": 395, "portee": 1, "uicn": "EN", "proie": true,
		"desc": "Mi-cochon, mi-éléphant, mi-panda par la couleur. Les enfants le dessinent avec trois moitiés."},
	"dromadaire": {"nom": "Dromadaire", "decors": ["dromadaire"], "taille": 5, "cont": "afrique",
		"sols": {"sable": 0.7, "broussailles": 0.3}, "m2": 300, "groupe": [2, 10], "eau": 0.0,
		"niveau": 2, "h": 1.8, "abri": true, "climat": [-10, 48], "regime": "herbivore", "kg": 12.0, "prix": 5000,
		"attrait": 4.0, "vie": 40, "maturite": 4, "gestation": 390, "portee": 1, "uicn": "LC", "proie": true,
		"desc": "Une bosse : dromadaire. Deux bosses : chameau. Aucune : il est sorti de l'enclos."},
	"lama": {"nom": "Lama", "decors": ["lama"], "taille": 2, "cont": "amerique",
		"sols": {"herbe": 0.5, "roche": 0.3, "broussailles": 0.2}, "m2": 100, "groupe": [3, 12], "eau": 0.0,
		"niveau": 1, "h": 1.5, "abri": false, "climat": [-20, 32], "regime": "herbivore", "kg": 4.0, "prix": 1500,
		"attrait": 3.0, "vie": 20, "maturite": 2, "gestation": 345, "portee": 1, "uicn": "LC", "proie": true,
		"desc": "Crache rarement, et toujours sur le visiteur qui a dit « il ne crache jamais »."},
	"yack": {"nom": "Yack", "decors": ["yack"], "taille": 5, "cont": "asie",
		"sols": {"herbe": 0.5, "roche": 0.3, "neige": 0.2}, "m2": 300, "groupe": [2, 10], "eau": 0.0,
		"niveau": 2, "h": 1.6, "abri": false, "climat": [-40, 22], "regime": "herbivore", "kg": 12.0, "prix": 3500,
		"attrait": 3.0, "vie": 22, "maturite": 3, "gestation": 260, "portee": 1, "uicn": "VU", "proie": true,
		"desc": "Vient de l'Himalaya. Notre été lui semble une erreur de réglage."},
	"chevre": {"nom": "Chèvre naine", "decors": ["chevre"], "taille": 1, "cont": "ferme",
		"sols": {"herbe": 0.6, "roche": 0.3, "sable": 0.1}, "m2": 20, "groupe": [3, 20], "eau": 0.0,
		"niveau": 1, "h": 1.2, "abri": true, "climat": [-15, 38], "regime": "herbivore", "kg": 1.5, "prix": 200,
		"attrait": 3.0, "vie": 14, "maturite": 1, "gestation": 150, "portee": 2, "uicn": "LC", "proie": true,
		"desc": "Mange le foin, les cartes du zoo et les lacets des enfants. Les enfants adorent."},
	"brebis": {"nom": "Brebis d'Ouessant", "decors": ["brebis", "mouton_broute", "agneau"], "taille": 1, "cont": "ferme",
		"sols": {"herbe": 0.9, "roche": 0.1}, "m2": 30, "groupe": [3, 20], "eau": 0.0,
		"niveau": 1, "h": 1.0, "abri": true, "climat": [-20, 35], "regime": "herbivore", "kg": 2.0, "prix": 250,
		"attrait": 2.0, "vie": 12, "maturite": 1, "gestation": 150, "portee": 1, "uicn": "LC", "proie": true,
		"desc": "La plus petite race de France. Tondue chaque printemps, elle boude une semaine."},
	"ane": {"nom": "Âne du Cotentin", "decors": ["ane"], "taille": 3, "cont": "ferme",
		"sols": {"herbe": 0.8, "sable": 0.2}, "m2": 150, "groupe": [2, 8], "eau": 0.0,
		"niveau": 1, "h": 1.4, "abri": true, "climat": [-20, 38], "regime": "herbivore", "kg": 6.0, "prix": 900,
		"attrait": 2.0, "vie": 30, "maturite": 3, "gestation": 365, "portee": 1, "uicn": "LC", "proie": true,
		"desc": "Têtu ? Prudent. Il refuse ce qu'il trouve dangereux, et il trouve beaucoup de choses dangereuses."},
}
const ORDRE := ["lion", "tigre", "elephant", "girafe", "zebre", "rhinoceros", "hippopotame", "autruche", "suricate",
	"gorille", "chimpanze", "orang_outan", "lemurien", "panda", "panda_roux", "tapir", "ours_brun", "loup", "bison",
	"ours_polaire", "renne", "manchot", "otarie", "kangourou", "koala", "flamant", "crocodile", "tortue_geante",
	"dromadaire", "lama", "yack", "chevre", "brebis", "ane"]

## Barrières des enclos : "niveau" (solidité 1 à 5), "h" hauteur (m), prix au
## mètre, "vue" (0 = on ne voit rien à travers, 1 = vue parfaite), "couvert"
## (filet de toit : retient les grimpeurs), "douve" (ne retient pas les nageurs).
const BARRIERES := {
	"barriere_bois": {"nom": "Barrière en bois (1,2 m)", "niveau": 1, "h": 1.2, "prix_m": 60.0, "vue": 0.95,
		"desc": "Pour la mini-ferme. Un lama la regarde avec indulgence."},
	"electrique": {"nom": "Clôture électrique (1,5 m)", "niveau": 1, "h": 1.5, "prix_m": 40.0, "vue": 0.9,
		"desc": "Bon marché, presque invisible. Les herbivores la respectent après le premier essai."},
	"grillage": {"nom": "Grillage (2 m)", "niveau": 2, "h": 2.0, "prix_m": 90.0, "vue": 0.75,
		"desc": "Le classique. Suffisant pour les zèbres et les autruches."},
	"palissade": {"nom": "Palissade en rondins (2,5 m)", "niveau": 3, "h": 2.5, "prix_m": 140.0, "vue": 0.15,
		"desc": "Solide et jolie, mais on ne voit presque rien à travers : prévoir des fenêtres (vitres)."},
	"grillage_fort": {"nom": "Grillage renforcé (4 m)", "niveau": 4, "h": 4.0, "prix_m": 190.0, "vue": 0.65,
		"desc": "Poteaux d'acier et grillage épais, retour en haut. Pour les loups et les lions."},
	"voliere": {"nom": "Volière couverte (6 m)", "niveau": 4, "h": 6.0, "prix_m": 260.0, "vue": 0.7, "couvert": true,
		"desc": "Grillage et filet de toit : rien ne grimpe ni ne s'envole. Coûteuse sur un grand enclos."},
	"vitre": {"nom": "Paroi vitrée (3 m)", "niveau": 5, "h": 3.0, "prix_m": 520.0, "vue": 1.0,
		"desc": "Verre feuilleté de 4 cm. Les enfants y collent le nez, les tigres aussi."},
	"mur": {"nom": "Mur en béton (4 m)", "niveau": 5, "h": 4.0, "prix_m": 320.0, "vue": 0.0,
		"desc": "Rien ne passe, pas même le regard des visiteurs. À combiner avec des vitres."},
	"douve": {"nom": "Douve et muret (fossé)", "niveau": 5, "h": 1.0, "prix_m": 420.0, "vue": 1.0, "douve": true,
		"desc": "Un fossé invisible depuis les allées : la vue est parfaite. Mais tout ce qui nage passe."},
}
const BARRIERES_ORDRE := ["barriere_bois", "electrique", "grillage", "palissade", "grillage_fort", "voliere", "vitre", "mur", "douve"]


static func espece(id: String) -> Dictionary:
	return ESPECES.get(id, {})


static func nom(id: String) -> String:
	return String(espece(id).get("nom", id))


## Nom avec une minuscule au début seulement (« lion d'Afrique »).
static func nom_bas(id: String) -> String:
	return minuscule(nom(id))


static func minuscule(t: String) -> String:
	return t.left(1).to_lower() + t.substr(1) if t != "" else t


static func barriere(id: String) -> Dictionary:
	return BARRIERES.get(id, BARRIERES.grillage)


## La barrière retient-elle l'espèce ? [ok, raison si non].
static func barriere_ok(esp_id: String, bar_id: String) -> Array:
	var e := espece(esp_id)
	var b := barriere(bar_id)
	if e.is_empty():
		return [true, ""]
	if int(b.niveau) < int(e.niveau):
		return [false, "barrière trop faible (niveau %d, il faut %d)" % [int(b.niveau), int(e.niveau)]]
	if bool(b.get("douve", false)):
		if bool(e.get("nage", false)):
			return [false, "il traverse la douve à la nage"]
		return [true, ""]
	if float(b.h) + 0.01 < float(e.h):
		return [false, "barrière trop basse (%.1f m, il faut %.1f m)" % [float(b.h), float(e.h)]]
	if bool(e.get("grimpe", false)) and not bool(b.get("couvert", false)) and bar_id in ["grillage", "grillage_fort", "barriere_bois", "electrique"]:
		return [false, "il grimpe au grillage (vitre, mur ou volière couverte)"]
	return [true, ""]


## Modèle à poser pour un animal (variante selon le sexe et l'âge).
static func modele(esp_id: String, femelle: bool, petit: bool) -> String:
	var d: Array = espece(esp_id).get("decors", [])
	if d.is_empty():
		return ""
	if petit and d.size() >= 3:
		return String(d[2])
	if femelle and d.size() >= 2:
		return String(d[1])
	return String(d[0])


## Échelle d'affichage d'un petit (les espèces sans modèle de petit sont réduites).
static func echelle(esp_id: String, age_ans: float) -> float:
	var e := espece(esp_id)
	var m := maxf(float(e.get("maturite", 1)), 0.5)
	var d: Array = e.get("decors", [])
	if d.size() >= 3 and age_ans < m:
		return 1.0
	return clampf(0.55 + 0.45 * age_ans / m, 0.55, 1.0)


static func uicn_bonus(esp_id: String) -> float:
	return float(UICN.get(String(espece(esp_id).get("uicn", "LC")), UICN.LC).bonus)
