class_name AgriDonnees
extends RefCounted
## Données de l'agriculture : cultures, travaux des champs, machines agricoles
## et animaux d'élevage. Ordres de grandeur réels (France, années 2020),
## arrondis pour rester lisibles. Ajouter une culture, une machine ou une
## espèce ici suffit : le reste du jeu les lit dans ces tables.

## Mois de semis donnés pour l'hémisphère nord (1 = janvier) ; l'hémisphère
## sud est décalé de six mois. Climats : indices de Plantes.Climat (0 boréal,
## 1 tempéré, 2 méditerranéen, 3 subtropical, 4 tropical). En climat tropical,
## les cultures « toute_annee » se sèment n'importe quel mois.
## - rdt : rendement moyen (t/ha) de la marchandise "good" ;
## - paille : paille pressable après la récolte (t/ha) ;
## - cycle : jours entre le semis et la maturité (prairie : entre deux coupes) ;
## - semis_m / recolte_m : machines du semis et de la récolte ;
## - semences, engrais : € par ha et kg d'azote par ha ;
## - couche : texture du sol quand la culture pousse (Sols.COUCHES) ;
## - plante : espèce de Plantes ("" : rien) ; densite : plantes par m².
const CULTURES := {
	"ble": {"name": "Blé tendre", "good": "cereales", "rdt": 7.2, "paille": 3.5, "cycle": 270, "semis": [10, 11],
		"climats": [0, 1, 2, 3], "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 110, "engrais": 170,
		"couche": "ble", "plante": "ble", "densite": 1.0, "couleur": Color("d9b44a")},
	"orge": {"name": "Orge", "good": "cereales", "rdt": 6.5, "paille": 3.0, "cycle": 250, "semis": [10],
		"climats": [0, 1, 2, 3], "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 100, "engrais": 140,
		"couche": "ble", "plante": "ble", "densite": 1.0, "couleur": Color("e3c77a")},
	"mais": {"name": "Maïs grain", "good": "cereales", "rdt": 9.5, "paille": 0.0, "cycle": 160, "semis": [4, 5],
		"climats": [1, 2, 3, 4], "toute_annee": true, "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 210,
		"engrais": 160, "couche": "mais", "plante": "mais", "densite": 0.5, "couleur": Color("c9a640")},
	"colza": {"name": "Colza", "good": "oleagineux", "rdt": 3.3, "paille": 0.0, "cycle": 320, "semis": [8, 9],
		"climats": [0, 1, 2], "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 90, "engrais": 160,
		"couche": "colza", "plante": "colza", "densite": 0.7, "couleur": Color("f1d230")},
	"tournesol": {"name": "Tournesol", "good": "oleagineux", "rdt": 2.3, "paille": 0.0, "cycle": 140, "semis": [4, 5],
		"climats": [1, 2, 3], "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 140, "engrais": 60,
		"couche": "tournesol", "plante": "tournesol", "densite": 0.6, "couleur": Color("e9b824")},
	"soja": {"name": "Soja", "good": "oleagineux", "rdt": 2.8, "paille": 0.0, "cycle": 140, "semis": [5],
		"climats": [1, 3, 4], "toute_annee": true, "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 180,
		"engrais": 0, "couche": "legumes", "plante": "legumes", "densite": 0.5, "couleur": Color("9caa48")},
	"betterave": {"name": "Betterave sucrière", "good": "betteraves", "rdt": 85.0, "paille": 0.0, "cycle": 190,
		"semis": [3, 4], "climats": [0, 1, 2], "semis_m": "semoir", "recolte_m": "arracheuse", "semences": 250,
		"engrais": 110, "couche": "legumes", "plante": "legumes", "densite": 0.5, "couleur": Color("4f8a3a")},
	"pomme_de_terre": {"name": "Pomme de terre", "good": "fruits_legumes", "rdt": 42.0, "paille": 0.0, "cycle": 130,
		"semis": [3, 4, 5], "climats": [0, 1, 2, 3], "semis_m": "planteuse", "recolte_m": "arracheuse", "semences": 1800,
		"engrais": 180, "couche": "legumes", "plante": "legumes", "densite": 0.5, "couleur": Color("5c8f3c")},
	"legumes": {"name": "Légumes de plein champ", "good": "fruits_legumes", "rdt": 28.0, "paille": 0.0, "cycle": 100,
		"semis": [3, 4, 5, 6], "climats": [0, 1, 2, 3, 4], "toute_annee": true, "semis_m": "planteuse",
		"recolte_m": "remorque", "semences": 2500, "engrais": 150, "couche": "legumes", "plante": "legumes",
		"densite": 0.5, "couleur": Color("4c9a3c")},
	"riz": {"name": "Riz", "good": "cereales", "rdt": 6.5, "paille": 2.0, "cycle": 150, "semis": [4, 5],
		"climats": [2, 3, 4], "toute_annee": true, "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 160,
		"engrais": 140, "couche": "riz", "plante": "riz", "densite": 0.8, "couleur": Color("a7b04a")},
	"lin": {"name": "Lin textile", "good": "fibres", "rdt": 1.2, "paille": 0.0, "cycle": 110, "semis": [3, 4],
		"climats": [0, 1], "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 230, "engrais": 40,
		"couche": "ble", "plante": "ble", "densite": 0.8, "couleur": Color("8fb3d9")},
	"coton": {"name": "Coton", "good": "fibres", "rdt": 0.9, "paille": 0.0, "cycle": 170, "semis": [4, 5],
		"climats": [3, 4], "toute_annee": true, "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 150,
		"engrais": 120, "couche": "legumes", "plante": "legumes", "densite": 0.5, "couleur": Color("f1efe6")},
	# Lot 5 : cultures arrivées après 1970.
	"triticale": {"name": "Triticale (blé × seigle)", "good": "cereales", "rdt": 6.0, "paille": 4.0, "cycle": 260, "semis": [10],
		"climats": [0, 1, 2], "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 120, "engrais": 110,
		"couche": "ble", "plante": "ble", "densite": 1.0, "couleur": Color("c9a95a")},
	"quinoa": {"name": "Quinoa", "good": "cereales", "rdt": 1.8, "paille": 0.0, "cycle": 150, "semis": [4],
		"climats": [0, 1, 2], "semis_m": "semoir", "recolte_m": "moissonneuse", "semences": 12, "engrais": 60,
		"couche": "colza", "plante": "colza", "densite": 0.6, "couleur": Color("b5654a")},
	"miscanthus": {"name": "Miscanthus (herbe à éléphant, chauffage)", "good": "bois", "rdt": 14.0, "paille": 0.0, "cycle": 300,
		"semis": [4], "perenne": true, "climats": [0, 1, 2], "semis_m": "planteuse", "recolte_m": "moissonneuse", "semences": 400, "engrais": 0,
		"couche": "mais", "plante": "mais", "densite": 1.2, "couleur": Color("a8b36a")},
	"fraises_hors_sol": {"name": "Fraises hors-sol (sous serre)", "good": "fruits_legumes", "rdt": 45.0, "paille": 0.0,
		"cycle": 120, "semis": [3], "climats": [0, 1, 2, 3], "toute_annee": true, "semis_m": "planteuse",
		"recolte_m": "cueillette", "semences": 900, "engrais": 140, "couche": "legumes", "plante": "legumes", "densite": 0.5,
		"couleur": Color("d64545")},
	"prairie": {"name": "Prairie de fauche (foin)", "good": "foin", "rdt": 3.5, "paille": 0.0, "cycle": 60,
		"semis": [3, 4, 9], "climats": [0, 1, 2, 3, 4], "permanente": true, "semis_m": "semoir", "recolte_m": "faucheuse",
		"semences": 120, "engrais": 60, "couche": "pre_fauche", "plante": "herbe", "densite": 0.08,
		"couleur": Color("7fae4a")},
	"paturage": {"name": "Pâture (bêtes au pré)", "good": "", "rdt": 0.0, "paille": 0.0, "cycle": 45,
		"semis": [3, 4, 9], "climats": [0, 1, 2, 3, 4], "permanente": true, "paturage": true, "semis_m": "semoir",
		"recolte_m": "", "semences": 100, "engrais": 0, "couche": "herbe", "plante": "herbe", "densite": 0.05,
		"couleur": Color("6aa84f")},
	# --- Cultures pérennes et cultures de rente (vigne, vergers, plantations) ---
	# "perenne" : plantée une fois, récoltée chaque année ; après la récolte,
	# elle se repose jusqu'au mois de reprise ("semis" = mois où elle repart).
	"vigne": {"name": "Vigne", "good": "raisin", "rdt": 9.0, "paille": 0.0, "cycle": 190, "semis": [3, 4], "perenne": true,
		"climats": [1, 2, 3], "semis_m": "planteuse", "recolte_m": "vendangeuse", "semences": 15000, "engrais": 40,
		"couche": "vigne", "plante": "vigne", "densite": 0.4, "couleur": Color("6d2e46")},
	"verger": {"name": "Verger (pommes, poires)", "good": "fruits_legumes", "rdt": 35.0, "paille": 0.0, "cycle": 190,
		"semis": [3, 4], "perenne": true, "climats": [0, 1, 2], "semis_m": "planteuse", "recolte_m": "cueillette",
		"semences": 9000, "engrais": 60, "couche": "herbe", "plante": "buisson_fleuri", "densite": 0.03, "couleur": Color("c1121f")},
	"agrumes": {"name": "Agrumes (oranges, citrons)", "good": "fruits_legumes", "rdt": 30.0, "paille": 0.0, "cycle": 260,
		"semis": [2, 3], "perenne": true, "climats": [2, 3, 4], "semis_m": "planteuse", "recolte_m": "cueillette",
		"semences": 9000, "engrais": 120, "couche": "herbe", "plante": "buisson", "densite": 0.03, "couleur": Color("f77f00")},
	"olivier": {"name": "Oliviers", "good": "oleagineux", "rdt": 3.0, "paille": 0.0, "cycle": 230, "semis": [3],
		"perenne": true, "climats": [2, 3], "semis_m": "planteuse", "recolte_m": "cueillette", "semences": 6000, "engrais": 50,
		"couche": "herbe", "plante": "olivier", "densite": 0.01, "couleur": Color("6b705c")},
	"cafe": {"name": "Caféiers", "good": "cafe", "rdt": 1.0, "paille": 0.0, "cycle": 240, "semis": [9, 10], "perenne": true,
		"toute_annee": true, "climats": [3, 4], "semis_m": "planteuse", "recolte_m": "cueillette", "semences": 5000,
		"engrais": 120, "couche": "legumes", "plante": "buisson", "densite": 0.25, "couleur": Color("9b2226")},
	"cacao": {"name": "Cacaoyers", "good": "cacao", "rdt": 0.6, "paille": 0.0, "cycle": 180, "semis": [4, 5], "perenne": true,
		"toute_annee": true, "climats": [4], "semis_m": "planteuse", "recolte_m": "cueillette", "semences": 4000,
		"engrais": 60, "couche": "legumes", "plante": "tropical", "densite": 0.02, "couleur": Color("bb9457")},
	"canne": {"name": "Canne à sucre", "good": "canne", "rdt": 70.0, "paille": 0.0, "cycle": 330, "semis": [2, 3], "perenne": true,
		"toute_annee": true, "climats": [3, 4], "semis_m": "planteuse", "recolte_m": "coupe_canne", "semences": 2500,
		"engrais": 150, "couche": "mais", "plante": "roseaux", "densite": 0.5, "couleur": Color("a7c957")},
	"the": {"name": "Théiers", "good": "the", "rdt": 2.0, "paille": 0.0, "cycle": 100, "semis": [3, 4], "perenne": true,
		"toute_annee": true, "climats": [2, 3, 4], "semis_m": "planteuse", "recolte_m": "cueillette", "semences": 7000,
		"engrais": 200, "couche": "legumes", "plante": "buisson", "densite": 0.5, "couleur": Color("386641")},
	"houblon": {"name": "Houblon", "good": "houblon", "rdt": 2.0, "paille": 0.0, "cycle": 150, "semis": [4], "perenne": true,
		"climats": [0, 1], "semis_m": "planteuse", "recolte_m": "cueillette", "semences": 12000, "engrais": 150,
		"couche": "vigne", "plante": "vigne", "densite": 0.4, "couleur": Color("90a955")},
	"tabac": {"name": "Tabac", "good": "tabac", "rdt": 2.5, "paille": 0.0, "cycle": 120, "semis": [4, 5],
		"climats": [1, 2, 3, 4], "toute_annee": true, "semis_m": "planteuse", "recolte_m": "cueillette", "semences": 900,
		"engrais": 120, "couche": "legumes", "plante": "legumes", "densite": 0.4, "couleur": Color("a98467")},
}
## Ordre d'affichage.
const ORDRE_CULTURES := ["ble", "orge", "mais", "colza", "tournesol", "soja", "betterave", "pomme_de_terre",
	"legumes", "riz", "lin", "coton", "prairie", "paturage", "vigne", "verger", "agrumes", "olivier", "houblon", "tabac",
	"cafe", "cacao", "the", "canne", "triticale", "quinoa", "miscanthus", "fraises_hors_sol"]

## Travaux des champs : machine (outil) et tracteur nécessaires. "outil"
## peut dépendre de la culture (semis_m, recolte_m). pluie : impossible sous
## la pluie. ordre : priorité quand il y a plus de travaux que de bras.
const TACHES := {
	"labour": {"name": "Labour", "outil": "charrue", "ordre": 5, "pluie": false},
	"semis": {"name": "Semis", "outil": "semis_m", "ordre": 1, "pluie": true},
	"engrais": {"name": "Épandage d'engrais", "outil": "epandeur", "ordre": 3, "pluie": false},
	"traitement": {"name": "Traitement des cultures", "outil": "pulverisateur", "ordre": 4, "pluie": true},
	"recolte": {"name": "Récolte", "outil": "recolte_m", "ordre": 0, "pluie": true},
	"pressage": {"name": "Pressage des bottes", "outil": "presse", "ordre": 2, "pluie": true},
}

## Machines agricoles. prix : achat neuf (€) ; loc : location à la journée
## à la coopérative (CUMA) ; ha_h : hectares travaillés par heure ; litres :
## gazole par heure ; automoteur : roule seule (sinon tirée par un tracteur) ;
## modele : décor affiché (assets/modeles/decors) ; taches : ce qu'elle fait.
const MACHINES := {
	"tracteur": {"name": "Tracteur", "prix": 110_000, "loc": 220, "ha_h": 0.0, "litres": 14.0, "automoteur": true,
		"modele": "tracteur"},
	"charrue": {"name": "Charrue", "prix": 22_000, "loc": 70, "ha_h": 1.4, "modele": "charrue"},
	"semoir": {"name": "Semoir", "prix": 38_000, "loc": 110, "ha_h": 3.0, "modele": "semoir"},
	"planteuse": {"name": "Planteuse", "prix": 45_000, "loc": 140, "ha_h": 1.2, "modele": "planteuse"},
	"epandeur": {"name": "Épandeur d'engrais", "prix": 18_000, "loc": 60, "ha_h": 8.0, "modele": "epandeur"},
	"pulverisateur": {"name": "Pulvérisateur", "prix": 32_000, "loc": 100, "ha_h": 12.0, "modele": "pulverisateur"},
	"moissonneuse": {"name": "Moissonneuse-batteuse", "prix": 320_000, "loc": 900, "ha_h": 2.8, "litres": 28.0,
		"automoteur": true, "modele": "moissonneuse"},
	"arracheuse": {"name": "Arracheuse (betteraves, pommes de terre)", "prix": 380_000, "loc": 1000, "ha_h": 0.9,
		"litres": 30.0, "automoteur": true, "modele": "arracheuse"},
	"faucheuse": {"name": "Faucheuse", "prix": 14_000, "loc": 55, "ha_h": 3.0, "modele": "faucheuse"},
	"presse": {"name": "Presse à balles rondes", "prix": 40_000, "loc": 130, "ha_h": 4.0, "modele": "presse_balles"},
	"remorque": {"name": "Remorque (récolte à la main)", "prix": 15_000, "loc": 45, "ha_h": 0.25, "modele": "remorque_foin"},
	# Récoltes des cultures pérennes. manuel : le travail se fait à plusieurs
	# mains (jusqu'à MAINS ouvriers sur le même champ), sans tracteur.
	"cueillette": {"name": "Cueilleurs et plateforme de récolte", "prix": 25_000, "loc": 90, "ha_h": 0.08, "litres": 2.0,
		"automoteur": true, "manuel": true, "modele": "remorque_foin"},
	"vendangeuse": {"name": "Machine à vendanger", "prix": 180_000, "loc": 600, "ha_h": 0.5, "litres": 20.0,
		"automoteur": true, "modele": "vendangeuse"},
	"coupe_canne": {"name": "Récolteuse de canne", "prix": 300_000, "loc": 900, "ha_h": 0.8, "litres": 30.0,
		"automoteur": true, "modele": "moissonneuse"},
}
const ORDRE_MACHINES := ["tracteur", "charrue", "semoir", "planteuse", "epandeur", "pulverisateur", "faucheuse",
	"presse", "remorque", "moissonneuse", "arracheuse", "cueillette", "vendangeuse", "coupe_canne"]
## Ouvriers au plus sur un même champ pour un travail à la main.
const MAINS := 8
## Prix du gazole agricole (€/L) et densité (t/L).
const GAZOLE := 1.25
const GAZOLE_T := 0.00084
## Usure par heure de travail (0 → 1) : une machine neuve fait environ 2 500 h
## avant d'être usée. Au-delà de PANNE, elle peut tomber en panne.
const USURE_H := 0.0004
const PANNE := 0.7
## Réparation : part du prix neuf × usure, et une journée d'immobilisation.
const REPARATION := 0.08

## Animaux. ugb : unité gros bétail (pour la place au pré : 1 UGB ≈ 0,6 ha de
## pâture au printemps et en été) ; mange : t par tête et par jour ; donne :
## t par tête et par jour ; prix : achat d'une bête ; par_eleveur : bêtes
## qu'un éleveur peut soigner ; modeles : décors affichés.
const ESPECES := {
	"vache": {"name": "Vaches laitières", "un": "vache", "ugb": 1.0, "prix": 1600,
		"mange": {"foin": 0.013, "cereales": 0.004}, "donne": {"lait": 0.022, "fumier": 0.045},
		"par_eleveur": 60, "modeles": ["vache_pie_noire", "vache_broute", "vache_pie_noire", "veau"]},
	"bovin": {"name": "Bovins à viande", "un": "bovin", "ugb": 0.8, "prix": 1200,
		"mange": {"foin": 0.010, "cereales": 0.002}, "donne": {"betail": 0.0009, "fumier": 0.035},
		"par_eleveur": 80, "modeles": ["vache_rousse", "vache_broute_rousse", "vache_blanche", "veau"]},
	"porc": {"name": "Porcs", "un": "porc", "ugb": 0.0, "prix": 160,
		"mange": {"cereales": 0.0026}, "donne": {"betail": 0.0006, "fumier": 0.004},
		"par_eleveur": 500, "modeles": ["cochon"]},
	"poule": {"name": "Poules pondeuses", "un": "poule", "ugb": 0.0, "prix": 7,
		"mange": {"cereales": 0.00012}, "donne": {"oeufs": 0.00005, "fumier": 0.0001},
		"par_eleveur": 8000, "modeles": ["poule_blanche", "poule_rousse"]},
	"mouton": {"name": "Moutons", "un": "mouton", "ugb": 0.15, "prix": 220,
		"mange": {"foin": 0.0018}, "donne": {"laine": 0.000012, "betail": 0.00012, "fumier": 0.004},
		"par_eleveur": 300, "modeles": ["brebis", "mouton_broute", "agneau"]},
	"chevre": {"name": "Chèvres", "un": "chèvre", "ugb": 0.15, "prix": 250,
		"mange": {"foin": 0.002, "cereales": 0.0005}, "donne": {"lait": 0.0025, "fumier": 0.004},
		"par_eleveur": 250, "modeles": ["chevre"]},
	"cheval": {"name": "Chevaux", "un": "cheval", "ugb": 1.0, "prix": 3000,
		"mange": {"foin": 0.010, "cereales": 0.002}, "donne": {"fumier": 0.04},
		"par_eleveur": 15, "modeles": ["cheval", "cheval_noir", "cheval_blanc", "poney"]},
	"canard": {"name": "Canards", "un": "canard", "ugb": 0.0, "prix": 12,
		"mange": {"cereales": 0.00018}, "donne": {"betail": 0.00004, "oeufs": 0.00001, "fumier": 0.0001},
		"par_eleveur": 4000, "modeles": ["canard"]},
	"dinde": {"name": "Dindes", "un": "dinde", "ugb": 0.0, "prix": 25,
		"mange": {"cereales": 0.0003}, "donne": {"betail": 0.00008, "fumier": 0.0002},
		"par_eleveur": 3000, "modeles": ["poule_rousse"]},
	"lapin": {"name": "Lapins (clapiers)", "un": "lapin", "ugb": 0.0, "prix": 15,
		"mange": {"foin": 0.00008, "cereales": 0.00008}, "donne": {"betail": 0.00003, "fumier": 0.00005},
		"par_eleveur": 1500, "modeles": ["abri_paille"]},
	"abeille": {"name": "Ruches (abeilles)", "un": "ruche", "ugb": 0.0, "prix": 150,
		"mange": {"sucre": 0.00003}, "donne": {"miel": 0.00006},
		"par_eleveur": 300, "modeles": ["ruches"]},
	"pisciculture": {"name": "Bassins de truites", "un": "bassin", "ugb": 0.0, "prix": 8000,
		"mange": {"cereales": 0.035}, "donne": {"poisson": 0.027},
		"par_eleveur": 8, "modeles": ["ponton_court"]},
	"aquaponie": {"name": "Aquaponie (poissons et salades)", "un": "bassin", "ugb": 0.0, "prix": 15000,
		"mange": {"cereales": 0.02}, "donne": {"poisson": 0.015, "fruits_legumes": 0.03},
		"par_eleveur": 6, "modeles": ["serre_tunnel"]},
	"insectes": {"name": "Élevage d'insectes (protéines)", "un": "bac", "ugb": 0.0, "prix": 400,
		"mange": {"cereales": 0.0004}, "donne": {"betail": 0.00015, "fumier": 0.0002},
		"par_eleveur": 400, "modeles": ["bac_insectes"]},
	"buffle": {"name": "Buffles d'eau", "un": "buffle", "ugb": 1.0, "prix": 1800,
		"mange": {"foin": 0.012}, "donne": {"lait": 0.008, "betail": 0.0007, "fumier": 0.04},
		"par_eleveur": 50, "modeles": ["zebu", "yack"]},
	"lama": {"name": "Lamas et alpagas", "un": "lama", "ugb": 0.3, "prix": 600,
		"mange": {"foin": 0.003}, "donne": {"laine": 0.00001, "betail": 0.0001, "fumier": 0.006},
		"par_eleveur": 200, "modeles": ["lama"]},
	"renne": {"name": "Rennes", "un": "renne", "ugb": 0.3, "prix": 500,
		"mange": {"foin": 0.003}, "donne": {"betail": 0.00015, "fumier": 0.005},
		"par_eleveur": 400, "modeles": ["renne"]},
}
const ORDRE_ESPECES := ["vache", "bovin", "porc", "poule", "mouton", "chevre", "cheval", "canard", "dinde", "lapin",
	"abeille", "pisciculture", "buffle", "lama", "renne", "aquaponie", "insectes"]
## Litière : paille par UGB et par jour en bâtiment (t).
const LITIERE := 0.004

## Bâtiments de ferme : bêtes qu'ils accueillent (place maximale) et métiers
## qui travaillent aux champs. Toutes les fermes peuvent avoir des champs.
const FERMES := {
	# Fermes de la catégorie Production.
	"ferme_cereales": {"betes": {}},
	"ferme_maraichere": {"betes": {"poule": 200}},
	"ferme_betteraves": {"betes": {}},
	"ferme_fibres": {"betes": {"mouton": 60}},
	"elevage": {"betes": {"bovin": 150, "mouton": 400, "chevre": 200, "cheval": 10}},
	"ferme_laitiere": {"betes": {"vache": 120, "chevre": 200}},
	# Fermes de la bible Blender (styles du monde).
	"ferme_cour_carree": {"betes": {"vache": 60, "bovin": 60, "porc": 200, "poule": 500, "cheval": 6}},
	"ferme_jurassienne": {"betes": {"vache": 50, "chevre": 50}},
	"ferme_bavaroise": {"betes": {"vache": 40, "poule": 100, "cheval": 4}},
	"cortijo": {"betes": {"mouton": 300, "chevre": 200, "porc": 150, "cheval": 6}},
	"hacienda": {"betes": {"bovin": 300, "cheval": 30, "poule": 300}},
	"grange_americaine": {"betes": {"bovin": 100, "porc": 200, "poule": 300}},
	"etable_moderne": {"betes": {"vache": 120}},
	"bergerie": {"betes": {"mouton": 600, "chevre": 400}},
	"poulailler": {"betes": {"poule": 20000}},
	"porcherie": {"betes": {"porc": 1500}},
	"haras": {"betes": {"cheval": 40}},
	"ferme_alpage": {"betes": {"vache": 40, "chevre": 60, "mouton": 100}},
	"serres_tunnels": {"betes": {}},
	"serre_verre": {"betes": {}},
	"hangar_agricole": {"betes": {}},
	"rizerie_bali": {"betes": {}},
	# Nouvelles fermes de la catégorie Production.
	"vignoble": {"betes": {}},
	"verger": {"betes": {"abeille": 40}},
	"oliveraie": {"betes": {"mouton": 80}},
	"plantation_tropicale": {"betes": {}},
	"houblonniere": {"betes": {}},
	"basse_cour": {"betes": {"canard": 3000, "dinde": 2000, "lapin": 1500, "poule": 2000}},
	"rucher": {"betes": {"abeille": 300}},
	"pisciculture": {"betes": {"pisciculture": 12}},
	"ranch_buffles": {"betes": {"buffle": 150}},
	"elevage_andin": {"betes": {"lama": 400, "mouton": 200}},
	"elevage_rennes": {"betes": {"renne": 800}},
}
## Métiers qui ne font pas les travaux des champs (ils livrent).
const PAS_AUX_CHAMPS := ["chauffeur"]

## Rayon (m) autour de la ferme où l'on peut avoir des champs.
const RAYON_CHAMPS := 2500.0
## Plus petit et plus grand champ (cases de 1 m²).
const CHAMP_MIN := 400
const CHAMP_MAX := 1_000_000

## Gain de rendement de chaque travail fait à temps (sinon perte).
const SANS_ENGRAIS := 0.70
const SANS_TRAITEMENT := 0.85
## Même culture deux ans de suite : rendement en moins (sauf prairies).
const MONOCULTURE := 0.85
## Après une légumineuse, une prairie ou du colza : blé meilleur.
const BONNE_ROTATION := 1.08
## Une culture mûre se perd peu à peu si on ne la récolte pas (part par jour
## après GRACE jours).
const GRACE := 20.0
const PERTE_JOUR := 0.01


static func culture(id: String) -> Dictionary:
	return CULTURES.get(id, {})


static func culture_name(id: String) -> String:
	return String(CULTURES.get(id, {}).get("name", id))


## Machine d'un rôle, dans sa version de l'année en cours (AgriEpoques) : la
## faux avant la moissonneuse, les chevaux avant le tracteur.
static func machine(id: String) -> Dictionary:
	var m: Dictionary = MACHINES.get(id, {})
	if m.is_empty() or not Epoques.actif():
		return m
	var v := AgriEpoques.version(id)
	if v.size() <= 1:
		return m
	var out := m.duplicate()
	for k in v:
		if k != "annee":
			out[k] = v[k]
	return out


## Facteur de rendement des champs à l'époque de la partie : vers 1800, le blé
## donnait environ 1 t/ha (sept fois moins qu'aujourd'hui) ; la sélection des
## semences, les engrais et la mécanisation l'ont fait monter surtout après 1950.
const RENDEMENTS_EPOQUE := [[1800, 0.16], [1900, 0.2], [1950, 0.27], [1970, 0.55], [1990, 0.85], [2005, 1.0]]
## Même chose pour les bêtes (lait par vache, œufs par poule, viande par bête).
const ELEVAGE_EPOQUE := [[1800, 0.3], [1900, 0.36], [1950, 0.45], [1980, 0.8], [2000, 1.0]]


static func _courbe(table: Array, an: int) -> float:
	if an <= int(table[0][0]):
		return float(table[0][1])
	for i in range(1, table.size()):
		if an <= int(table[i][0]):
			var a: Array = table[i - 1]
			var b: Array = table[i]
			return lerpf(float(a[1]), float(b[1]), float(an - int(a[0])) / float(int(b[0]) - int(a[0])))
	return float(table[-1][1])


static func facteur_epoque() -> float:
	return _courbe(RENDEMENTS_EPOQUE, Epoques.annee()) if Epoques.actif() else 1.0


static func facteur_elevage() -> float:
	return _courbe(ELEVAGE_EPOQUE, Epoques.annee()) if Epoques.actif() else 1.0


## La machine se conduit-elle à la main (à plusieurs) ?
static func manuel(id: String) -> bool:
	return bool(machine(id).get("manuel", false))


static func machine_name(id: String) -> String:
	return String(machine(id).get("name", id))


static func espece(id: String) -> Dictionary:
	return ESPECES.get(id, {})


## Le type de bâtiment est-il une ferme (champs possibles) ?
static func est_ferme(type_id: String) -> bool:
	return FERMES.has(BuildingCatalog.base_of(type_id))


## Places pour une espèce dans un type de ferme (0 : pas d'accueil).
static func places(type_id: String, esp: String) -> int:
	return int(FERMES.get(BuildingCatalog.base_of(type_id), {}).get("betes", {}).get(esp, 0))


## Mois de l'hémisphère nord correspondant (hémisphère sud : six mois de décalage).
static func mois_nord(mois: int, lat: float) -> int:
	return mois if lat >= 0.0 else (mois + 5) % 12 + 1


## La culture pousse-t-elle sous ce climat ?
static func convient(id: String, climat: int) -> bool:
	return (CULTURES.get(id, {}).get("climats", []) as Array).has(climat)


## Peut-on semer ce mois-ci (mois local, 1 à 12) ?
static func saison_semis(id: String, mois: int, lat: float, climat: int) -> bool:
	var c := culture(id)
	if c.is_empty():
		return false
	if climat == Plantes.Climat.TROPICAL and bool(c.get("toute_annee", false)):
		return true
	return (c.semis as Array).has(mois_nord(mois, lat))


## Mois de semis lisibles (« oct.-nov. »), dans l'hémisphère du lieu.
static func mois_semis_texte(id: String, lat: float, climat: int) -> String:
	var c := culture(id)
	if c.is_empty():
		return ""
	if climat == Plantes.Climat.TROPICAL and bool(c.get("toute_annee", false)):
		return "toute l'année"
	const M := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
	var out: Array[String] = []
	for m in c.semis:
		var local := int(m) if lat >= 0.0 else (int(m) + 5) % 12 + 1
		out.append(M[local - 1])
	return ", ".join(out)


## Saison où l'herbe pousse et où les bêtes vont au pré (mois local).
static func saison_herbe(mois: int, lat: float, climat: int) -> bool:
	if climat >= Plantes.Climat.SUBTROPICAL:
		return true
	var m := mois_nord(mois, lat)
	if climat == Plantes.Climat.BOREAL:
		return m >= 5 and m <= 9
	return m >= 4 and m <= 10


## Outil qu'il faut pour une tâche sur une culture ("" : rien à faire).
static func outil(tache: String, cult: String) -> String:
	var t: Dictionary = TACHES.get(tache, {})
	var o := String(t.get("outil", ""))
	if o == "semis_m" or o == "recolte_m":
		o = String(culture(cult).get(o, ""))
	# Pas encore inventé (pulvérisateur avant 1885) : la tâche ne se fait pas.
	if o != "" and Epoques.actif() and not AgriEpoques.machine_existe(o):
		return ""
	return o


## Machines nécessaires à une tâche : l'outil, plus un tracteur s'il est tiré.
static func machines_pour(tache: String, cult: String) -> Array[String]:
	var out: Array[String] = []
	var o := outil(tache, cult)
	if o == "":
		return out
	out.append(o)
	if not bool(machine(o).get("automoteur", false)):
		out.append("tracteur")
	return out


## Fourrage (t par heure) mangé par les bêtes de trait d'une tâche.
static func fourrage_h(tache: String, cult: String) -> float:
	var t := 0.0
	for m in machines_pour(tache, cult):
		t += float(machine(m).get("foin_h", 0.0))
	return t


## Vitesse de travail (ha/h) d'une tâche.
static func vitesse(tache: String, cult: String) -> float:
	var o := outil(tache, cult)
	return float(machine(o).get("ha_h", 1.0))


## Gazole par heure (L) des machines d'une tâche.
static func litres(tache: String, cult: String) -> float:
	var l := 0.0
	for m in machines_pour(tache, cult):
		l += float(machine(m).get("litres", 0.0))
	return l
