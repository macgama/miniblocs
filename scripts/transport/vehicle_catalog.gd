class_name VehicleCatalog
extends RefCounted
## Catalogue des véhicules : voitures, utilitaires, bus, deux-roues, attelages,
## tramways, trains, wagons, bateaux et aéronefs, des débuts à aujourd'hui (et
## un peu de futur), de plusieurs régions du monde.
##
## Même principe que BuildingCatalog : chaque type a une catégorie, des chiffres
## réels (longueur, largeur, hauteur, vitesse, places) et un modèle low-poly
## fabriqué en code. On le filtre par époque et par région.
##
## Champs d'un type :
##   name, cat, mode (TransportTypes.Mode), era, region, year, L, W, H (m),
##   kmh, places, desc, shape (forme du modèle) et ses réglages,
##   col / col2 (couleurs), paints (teintes au hasard, voitures),
##   consist (trains, trams : liste des voitures attelées derrière),
##   rail : "tram", "train" ou "lgv" (voie où il roule),
##   path : vrai si le véhicule roule sur les chemins (vélos, trottinettes).

const ROAD := TransportTypes.Mode.ROAD
const RAIL := TransportTypes.Mode.RAIL
const PATH := TransportTypes.Mode.PATH
const WATER := TransportTypes.Mode.WATER
const AIR := TransportTypes.Mode.AIR

const CATEGORIES := [
	{"id": "voiture", "name": "Voitures", "color": Color("e76f51")},
	{"id": "utilitaire", "name": "Utilitaires et camions", "color": Color("f4a261")},
	{"id": "bus", "name": "Bus et cars", "color": Color("e9c46a")},
	{"id": "deux_roues", "name": "Deux et trois roues", "color": Color("90be6d")},
	{"id": "attelage", "name": "Attelages", "color": Color("b08968")},
	{"id": "tram", "name": "Tramways", "color": Color("2a9d8f")},
	{"id": "train", "name": "Trains", "color": Color("577590")},
	{"id": "wagon", "name": "Voitures et wagons", "color": Color("8d99ae")},
	{"id": "bateau", "name": "Bateaux", "color": Color("4ea8de")},
	{"id": "avion", "name": "Aéronefs", "color": Color("9d4edd")},
]

## Époques et régions : celles de la « bible » des styles (Styles), communes à
## tous les catalogues. L'époque d'un véhicule suit son année de mise en service.
const ERAS := Styles.ERAS
const REGIONS := Styles.REGIONS

const PAINTS := [Color("d64933"), Color("f2c14e"), Color("2e86ab"), Color("f4f4f4"), Color("3c3c3c"),
	Color("6aa84f"), Color("8e7dbe"), Color("e07a5f"), Color("1d3557"), Color("a8dadc"), Color("b5838d")]
const OLD_PAINTS := [Color("1b1b1b"), Color("3d2b1f"), Color("2f3e46"), Color("6b2737"), Color("31572c"), Color("e9e2c8")]
const BRIGHT := [Color("e63946"), Color("f1c40f"), Color("2ecc71"), Color("3498db"), Color("9b59b6"), Color("e67e22"), Color("1abc9c")]
const CONTAINERS := [Color("c0392b"), Color("2471a3"), Color("229954"), Color("d68910"), Color("7d3c98"), Color("717d7e")]
const DARK := Color("2c2f33")
const WOOD := Color("8b5a2b")
const CANVAS := Color("efe6d0")

const TYPES := {
	# --- Voitures ----------------------------------------------------------------
	"tacot": {"name": "Voiture sans chevaux", "cat": "voiture", "mode": ROAD, "era": "classique", "region": "europe", "year": 1900,
		"L": 3.0, "W": 1.5, "H": 1.6, "kmh": 30, "places": 2, "shape": "ancienne", "open": true, "paints": OLD_PAINTS,
		"desc": "Les premières automobiles, encore proches de la calèche."},
	"torpedo": {"name": "Torpédo décapotable", "cat": "voiture", "mode": ROAD, "era": "classique", "region": "europe", "year": 1925,
		"L": 4.0, "W": 1.65, "H": 1.6, "kmh": 75, "places": 4, "shape": "ancienne", "open": true, "paints": OLD_PAINTS,
		"desc": "Longue voiture ouverte des années folles."},
	"berline_30": {"name": "Berline des années 30", "cat": "voiture", "mode": ROAD, "era": "classique", "region": "ameriques", "year": 1934,
		"L": 4.6, "W": 1.8, "H": 1.75, "kmh": 100, "places": 5, "shape": "ancienne", "paints": OLD_PAINTS,
		"desc": "Haute caisse, ailes séparées et marchepieds."},
	"populaire_ronde": {"name": "Petite voiture populaire ronde", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1950,
		"L": 4.0, "W": 1.55, "H": 1.5, "kmh": 100, "places": 4, "shape": "voiture", "bh": 0.45, "hood": 0.2, "trunk": 0.18, "sf": 0.6, "sb": 0.9, "top": 0.75,
		"desc": "La voiture du peuple de l'après-guerre."},
	"mini_60": {"name": "Mini citadine des années 60", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1960,
		"L": 3.05, "W": 1.4, "H": 1.35, "kmh": 115, "places": 4, "shape": "voiture", "r": 0.26, "bh": 0.45, "hood": 0.2, "trunk": 0.08, "sf": 0.3, "sb": 0.15, "top": 0.86,
		"desc": "Toute petite, quatre places quand même."},
	"populaire_est": {"name": "Voiture populaire d'Europe de l'Est", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1965,
		"L": 3.55, "W": 1.5, "H": 1.45, "kmh": 100, "places": 4, "shape": "voiture", "bh": 0.5, "hood": 0.24, "trunk": 0.2, "sf": 0.35, "sb": 0.3, "top": 0.84,
		"paints": [Color("a8dadc"), Color("f1faee"), Color("e9c46a"), Color("8ab17d")], "desc": "Carrosserie simple et moteur deux temps."},
	"americaine_50": {"name": "Grosse américaine à ailerons", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "ameriques", "year": 1959,
		"L": 5.6, "W": 2.0, "H": 1.4, "kmh": 170, "places": 6, "shape": "voiture", "bh": 0.5, "hood": 0.32, "trunk": 0.28, "sf": 0.4, "sb": 0.4, "top": 0.85, "fins": true,
		"paints": [Color("e5989b"), Color("a8dadc"), Color("f1faee"), Color("e63946"), Color("ffd166")], "desc": "Chromes, ailerons et banquettes."},
	"coupe_60": {"name": "Coupé sport des années 60", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1963,
		"L": 4.4, "W": 1.7, "H": 1.22, "kmh": 230, "places": 2, "shape": "voiture", "bh": 0.42, "hood": 0.36, "trunk": 0.2, "sf": 0.45, "sb": 0.6, "top": 0.78,
		"paints": [Color("c1121f"), Color("1d3557"), Color("e9c46a"), Color("2a9d8f")], "desc": "Long capot et ligne fuyante."},
	"break_70": {"name": "Break familial des années 70", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1975,
		"L": 4.5, "W": 1.7, "H": 1.45, "kmh": 160, "places": 5, "shape": "voiture", "bh": 0.5, "hood": 0.22, "trunk": 0.02, "sf": 0.4, "sb": 0.05, "top": 0.88,
		"paints": [Color("a3b18a"), Color("dda15e"), Color("bc6c25"), Color("f1faee")], "desc": "Grand coffre pour les vacances."},
	"limousine": {"name": "Limousine", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "monde", "year": 1970,
		"L": 6.4, "W": 1.95, "H": 1.45, "kmh": 180, "places": 7, "shape": "voiture", "bh": 0.5, "hood": 0.2, "trunk": 0.14, "sf": 0.35, "sb": 0.3, "top": 0.88,
		"paints": [Color("111111"), Color("f4f4f4")], "desc": "Cabine allongée et vitres teintées."},
	"taxi_ny": {"name": "Taxi jaune de New York", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "ameriques", "year": 1975,
		"L": 5.2, "W": 1.95, "H": 1.5, "kmh": 160, "places": 5, "shape": "voiture", "bh": 0.55, "hood": 0.25, "trunk": 0.22, "sf": 0.3, "sb": 0.3, "top": 0.88, "sign": true,
		"col": Color("f6c90e"), "desc": "Le taxi des avenues de Manhattan."},
	"taxi_londres": {"name": "Taxi noir londonien", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1960,
		"L": 4.6, "W": 1.75, "H": 1.75, "kmh": 110, "places": 5, "shape": "voiture", "bh": 0.6, "hood": 0.22, "trunk": 0.12, "sf": 0.25, "sb": 0.3, "top": 0.86, "sign": true,
		"col": Color("161616"), "desc": "Haut de toit pour monter avec un chapeau."},
	"kei": {"name": "Mini-voiture japonaise (kei car)", "cat": "voiture", "mode": ROAD, "era": "contemporain", "region": "asie_est", "year": 2005,
		"L": 3.4, "W": 1.48, "H": 1.7, "kmh": 130, "places": 4, "shape": "voiture", "r": 0.27, "bh": 0.55, "hood": 0.12, "trunk": 0.02, "sf": 0.35, "sb": 0.05, "top": 0.92,
		"desc": "Cube sur roues, champion des rues étroites."},
	"citadine": {"name": "Citadine", "cat": "voiture", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2010,
		"L": 3.9, "W": 1.72, "H": 1.48, "kmh": 170, "places": 5, "shape": "voiture", "bh": 0.55, "hood": 0.2, "trunk": 0.05, "sf": 0.6, "sb": 0.25, "top": 0.82,
		"desc": "La voiture la plus courante en ville."},
	"berline": {"name": "Berline", "cat": "voiture", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2015,
		"L": 4.7, "W": 1.82, "H": 1.46, "kmh": 210, "places": 5, "shape": "voiture", "bh": 0.55, "hood": 0.24, "trunk": 0.18, "sf": 0.6, "sb": 0.5, "top": 0.82,
		"desc": "Quatre portes et un coffre."},
	"suv": {"name": "SUV", "cat": "voiture", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2018,
		"L": 4.6, "W": 1.9, "H": 1.7, "kmh": 200, "places": 5, "shape": "voiture", "r": 0.37, "bh": 0.65, "hood": 0.2, "trunk": 0.04, "sf": 0.5, "sb": 0.2, "top": 0.86,
		"desc": "Haut sur pattes, look de baroudeur."},
	"brousse": {"name": "4×4 de brousse", "cat": "voiture", "mode": ROAD, "era": "moderne", "region": "afrique", "year": 1985,
		"L": 4.4, "W": 1.8, "H": 2.0, "kmh": 130, "places": 7, "shape": "voiture", "r": 0.4, "bh": 0.7, "hood": 0.22, "trunk": 0.02, "sf": 0.15, "sb": 0.05, "top": 0.94,
		"rack": true, "spare": true, "paints": [Color("e9e2c8"), Color("a3b18a"), Color("dda15e"), Color("f1faee")], "desc": "Galerie de toit, roue de secours, pistes de safari."},
	"pickup": {"name": "Pick-up", "cat": "voiture", "mode": ROAD, "era": "contemporain", "region": "ameriques", "year": 2015,
		"L": 5.6, "W": 2.0, "H": 1.9, "kmh": 180, "places": 5, "shape": "voiture", "r": 0.4, "bh": 0.75, "hood": 0.2, "trunk": 0.36, "sf": 0.45, "sb": 0.05, "top": 0.9, "bed": true,
		"desc": "Cabine et benne ouverte."},
	"monospace": {"name": "Monospace", "cat": "voiture", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2005,
		"L": 4.8, "W": 1.9, "H": 1.75, "kmh": 190, "places": 7, "shape": "voiture", "bh": 0.6, "hood": 0.12, "trunk": 0.02, "sf": 0.9, "sb": 0.1, "top": 0.86,
		"desc": "Sept places pour les grandes familles."},
	"electrique": {"name": "Voiture électrique compacte", "cat": "voiture", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2022,
		"L": 4.2, "W": 1.85, "H": 1.55, "kmh": 160, "places": 5, "shape": "voiture", "bh": 0.6, "hood": 0.16, "trunk": 0.08, "sf": 0.9, "sb": 0.5, "top": 0.8,
		"paints": [Color("f4f4f4"), Color("4ea8de"), Color("3c3c3c"), Color("90be6d")], "desc": "Silencieuse, rechargée à la prise."},
	"supercar": {"name": "Supercar", "cat": "voiture", "mode": ROAD, "era": "contemporain", "region": "europe", "year": 2020,
		"L": 4.6, "W": 2.0, "H": 1.15, "kmh": 330, "places": 2, "shape": "voiture", "r": 0.34, "bh": 0.4, "hood": 0.3, "trunk": 0.24, "sf": 0.7, "sb": 0.8, "top": 0.66,
		"paints": [Color("e63946"), Color("f1c40f"), Color("ff7f11"), Color("2ecc71")], "desc": "Moteur central et ailes basses."},
	"capsule": {"name": "Capsule autonome", "cat": "voiture", "mode": ROAD, "era": "futuriste", "region": "monde", "year": 2040,
		"L": 3.6, "W": 1.8, "H": 1.7, "kmh": 120, "places": 4, "shape": "voiture", "r": 0.3, "bh": 0.5, "hood": 0.02, "trunk": 0.02, "sf": 1.0, "sb": 1.0, "top": 0.75,
		"paints": [Color("f4f4f4"), Color("d9ed92"), Color("caf0f8")], "desc": "Sans volant : elle se conduit seule."},

	# --- Utilitaires ---------------------------------------------------------------
	"camionnette_30": {"name": "Camionnette des années 30", "cat": "utilitaire", "mode": ROAD, "era": "classique", "region": "europe", "year": 1932,
		"L": 4.8, "W": 1.8, "H": 2.4, "kmh": 70, "places": 2, "shape": "camion", "cab": "capot", "cargo": "caisse", "r": 0.4,
		"col": Color("31572c"), "col2": Color("e9e2c8"), "desc": "Livraisons du laitier et du boulanger."},
	"fourgon": {"name": "Fourgon de livraison", "cat": "utilitaire", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2015,
		"L": 5.4, "W": 2.0, "H": 2.5, "kmh": 150, "places": 3, "shape": "voiture", "r": 0.36, "bh": 0.8, "hood": 0.12, "trunk": 0.0, "sf": 0.6, "sb": 0.0, "top": 0.96, "panel": true,
		"paints": [Color("f4f4f4"), Color("e9ecef"), Color("ffd166")], "desc": "Le livreur des colis du quotidien."},
	"benne": {"name": "Camion benne", "cat": "utilitaire", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2010,
		"L": 7.5, "W": 2.5, "H": 3.0, "kmh": 90, "places": 2, "shape": "camion", "cab": "avant", "cargo": "benne",
		"col": Color("f4a261"), "col2": Color("6c757d"), "desc": "Chantiers et carrières."},
	"semi": {"name": "Semi-remorque européen", "cat": "utilitaire", "mode": ROAD, "era": "contemporain", "region": "europe", "year": 2015,
		"L": 16.5, "W": 2.55, "H": 4.0, "kmh": 90, "places": 2, "shape": "camion", "cab": "avant", "cargo": "caisse",
		"col": Color("1d3557"), "col2": Color("f1faee"), "desc": "40 tonnes sur les autoroutes."},
	"camion_us": {"name": "Camion américain à long capot", "cat": "utilitaire", "mode": ROAD, "era": "moderne", "region": "ameriques", "year": 1985,
		"L": 21.0, "W": 2.6, "H": 4.1, "kmh": 105, "places": 2, "shape": "camion", "cab": "capot", "cargo": "caisse", "stacks": true,
		"col": Color("c1121f"), "col2": Color("dee2e6"), "desc": "Cheminées chromées et cabine couchette."},
	"citerne": {"name": "Camion-citerne", "cat": "utilitaire", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2010,
		"L": 12.0, "W": 2.5, "H": 3.4, "kmh": 90, "places": 2, "shape": "camion", "cab": "avant", "cargo": "citerne",
		"col": Color("f4f4f4"), "col2": Color("ced4da"), "desc": "Carburant, lait ou eau."},
	"grumier": {"name": "Grumier", "cat": "utilitaire", "mode": ROAD, "era": "moderne", "region": "afrique", "year": 1980,
		"L": 14.0, "W": 2.5, "H": 3.3, "kmh": 70, "places": 2, "shape": "camion", "cab": "capot", "cargo": "grumes",
		"col": Color("e9c46a"), "col2": WOOD, "desc": "Transport des troncs depuis la forêt."},
	"porte_conteneur": {"name": "Camion porte-conteneur", "cat": "utilitaire", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2010,
		"L": 16.5, "W": 2.55, "H": 4.0, "kmh": 90, "places": 2, "shape": "camion", "cab": "avant", "cargo": "conteneur",
		"col": Color("2a9d8f"), "col2": Color("c0392b"), "desc": "Du port à l'entrepôt."},
	"pompiers": {"name": "Camion de pompiers", "cat": "utilitaire", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2012,
		"L": 9.0, "W": 2.5, "H": 3.3, "kmh": 110, "places": 6, "shape": "camion", "cab": "avant", "cargo": "pompiers",
		"col": Color("d00000"), "col2": Color("d00000"), "desc": "Grande échelle et gyrophares."},
	"ambulance": {"name": "Ambulance", "cat": "utilitaire", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2015,
		"L": 6.0, "W": 2.1, "H": 2.8, "kmh": 140, "places": 4, "shape": "camion", "cab": "capot", "cargo": "ambulance", "r": 0.38,
		"col": Color("f4f4f4"), "col2": Color("f4f4f4"), "desc": "Cellule sanitaire et bandes rouges."},
	"camion_decore": {"name": "Camion décoré d'Asie du Sud", "cat": "utilitaire", "mode": ROAD, "era": "moderne", "region": "asie_sud", "year": 1980,
		"L": 9.0, "W": 2.4, "H": 3.6, "kmh": 70, "places": 2, "shape": "camion", "cab": "capot", "cargo": "decore",
		"col": Color("f1c40f"), "col2": Color("e63946"), "desc": "Peint de motifs et de couleurs vives."},
	"tracteur": {"name": "Tracteur agricole", "cat": "utilitaire", "mode": ROAD, "era": "moderne", "region": "monde", "year": 1965,
		"L": 3.6, "W": 1.9, "H": 2.6, "kmh": 30, "places": 1, "shape": "tracteur",
		"col": Color("c1121f"), "col2": Color("f4f4f4"), "desc": "Grandes roues arrière pour les champs."},

	# --- Bus et cars -----------------------------------------------------------------
	"autobus_30": {"name": "Autobus à plateforme", "cat": "bus", "mode": ROAD, "era": "classique", "region": "europe", "year": 1935,
		"L": 9.5, "W": 2.4, "H": 3.0, "kmh": 60, "places": 50, "shape": "bus", "front": "capot", "platform": true,
		"col": Color("2d6a4f"), "col2": Color("e9e2c8"), "desc": "On saute à l'arrière sur la plateforme ouverte."},
	"imperiale": {"name": "Bus à impériale londonien", "cat": "bus", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1960,
		"L": 8.4, "W": 2.4, "H": 4.4, "kmh": 65, "places": 64, "shape": "bus", "double": true, "platform": true,
		"col": Color("c1121f"), "col2": Color("f1faee"), "desc": "Deux étages et plateforme arrière."},
	"bus_scolaire": {"name": "Bus scolaire jaune", "cat": "bus", "mode": ROAD, "era": "moderne", "region": "ameriques", "year": 1980,
		"L": 11.0, "W": 2.4, "H": 3.1, "kmh": 90, "places": 72, "shape": "bus", "front": "capot",
		"col": Color("f6b80e"), "col2": DARK, "desc": "Capot avant et bandes noires."},
	"bus_urbain": {"name": "Bus urbain", "cat": "bus", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2015,
		"L": 12.0, "W": 2.55, "H": 3.1, "kmh": 70, "places": 100, "shape": "bus",
		"col": Color("f4f4f4"), "col2": Color("2a9d8f"), "desc": "Plancher bas, trois portes."},
	"bus_articule": {"name": "Bus articulé", "cat": "bus", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2015,
		"L": 9.0, "W": 2.55, "H": 3.1, "kmh": 70, "places": 150, "shape": "bus", "consist": ["bus_articule_arriere"],
		"col": Color("f4f4f4"), "col2": Color("e76f51"), "desc": "Deux caisses reliées par un soufflet."},
	"bus_articule_arriere": {"name": "Remorque de bus articulé", "cat": "wagon", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2015,
		"L": 9.0, "W": 2.55, "H": 3.1, "kmh": 70, "places": 60, "shape": "bus", "front": "soufflet",
		"col": Color("f4f4f4"), "col2": Color("e76f51"), "desc": "Partie arrière d'un bus articulé.", "hidden": true},
	"autocar": {"name": "Autocar de tourisme", "cat": "bus", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2012,
		"L": 13.0, "W": 2.55, "H": 3.7, "kmh": 100, "places": 55, "shape": "bus", "coach": true,
		"col": Color("f4f4f4"), "col2": Color("457b9d"), "desc": "Grandes vitres et soutes à bagages."},
	"trolleybus": {"name": "Trolleybus", "cat": "bus", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1975,
		"L": 12.0, "W": 2.5, "H": 3.2, "kmh": 60, "places": 90, "shape": "bus", "trolley": true,
		"col": Color("e9c46a"), "col2": Color("bc4749"), "desc": "Électrique, deux perches sur les fils."},
	"matatu": {"name": "Matatu (minibus décoré)", "cat": "bus", "mode": ROAD, "era": "contemporain", "region": "afrique", "year": 2010,
		"L": 6.0, "W": 2.0, "H": 2.6, "kmh": 110, "places": 14, "shape": "bus", "deco": true,
		"col": Color("2b2d42"), "col2": Color("f72585"), "desc": "Le taxi collectif de Nairobi, musique à fond."},
	"bus_poulet": {"name": "Bus coloré d'Amérique centrale", "cat": "bus", "mode": ROAD, "era": "moderne", "region": "ameriques", "year": 1985,
		"L": 11.0, "W": 2.4, "H": 3.2, "kmh": 80, "places": 70, "shape": "bus", "front": "capot", "deco": true, "rack": true,
		"col": Color("0077b6"), "col2": Color("f1c40f"), "desc": "Ancien bus scolaire repeint, bagages sur le toit."},
	"jeepney": {"name": "Jeepney philippin", "cat": "bus", "mode": ROAD, "era": "moderne", "region": "asie_sud", "year": 1975,
		"L": 6.5, "W": 1.9, "H": 2.3, "kmh": 70, "places": 18, "shape": "bus", "front": "capot", "deco": true, "open_sides": true,
		"col": Color("dee2e6"), "col2": Color("e63946"), "desc": "Descendant des jeeps militaires, chromé et peint."},
	"bus_etage_moderne": {"name": "Bus à étage moderne", "cat": "bus", "mode": ROAD, "era": "contemporain", "region": "asie_est", "year": 2015,
		"L": 12.0, "W": 2.55, "H": 4.4, "kmh": 70, "places": 130, "shape": "bus", "double": true,
		"col": Color("f4f4f4"), "col2": Color("e9c46a"), "desc": "Deux étages vitrés, comme à Hong Kong."},
	"navette_autonome": {"name": "Navette autonome", "cat": "bus", "mode": ROAD, "era": "futuriste", "region": "monde", "year": 2035,
		"L": 5.0, "W": 2.1, "H": 2.7, "kmh": 40, "places": 15, "shape": "bus", "pod": true,
		"col": Color("f4f4f4"), "col2": Color("4cc9f0"), "desc": "Petite navette électrique sans chauffeur."},

	# --- Deux et trois roues -------------------------------------------------------------
	"grand_bi": {"name": "Grand-bi", "cat": "deux_roues", "mode": PATH, "path": true, "era": "classique", "region": "europe", "year": 1875,
		"L": 1.6, "W": 0.5, "H": 2.2, "kmh": 20, "places": 1, "shape": "velo", "kind": "grand_bi", "col": DARK, "desc": "Une roue géante à l'avant."},
	"velo": {"name": "Vélo de ville", "cat": "deux_roues", "mode": PATH, "path": true, "era": "moderne", "region": "monde", "year": 1960,
		"L": 1.8, "W": 0.55, "H": 1.7, "kmh": 18, "places": 1, "shape": "velo", "paints": BRIGHT, "desc": "Le plus répandu des véhicules."},
	"velo_cargo": {"name": "Vélo cargo", "cat": "deux_roues", "mode": PATH, "path": true, "era": "contemporain", "region": "europe", "year": 2015,
		"L": 2.6, "W": 0.8, "H": 1.7, "kmh": 18, "places": 3, "shape": "velo", "kind": "cargo", "paints": BRIGHT, "desc": "Une caisse à l'avant pour les enfants ou les courses."},
	"trottinette": {"name": "Trottinette électrique", "cat": "deux_roues", "mode": PATH, "path": true, "era": "contemporain", "region": "monde", "year": 2019,
		"L": 1.1, "W": 0.45, "H": 1.8, "kmh": 22, "places": 1, "shape": "velo", "kind": "trottinette", "paints": BRIGHT, "desc": "Debout, sans effort."},
	"cyclo_pousse": {"name": "Cyclo-pousse", "cat": "deux_roues", "mode": PATH, "path": true, "era": "moderne", "region": "asie_sud", "year": 1960,
		"L": 2.6, "W": 1.1, "H": 1.9, "kmh": 12, "places": 2, "shape": "velo", "kind": "cyclo", "col": Color("e76f51"), "desc": "Le passager devant, le cycliste derrière."},
	"pousse_pousse": {"name": "Pousse-pousse", "cat": "deux_roues", "mode": PATH, "path": true, "era": "classique", "region": "asie_est", "year": 1900,
		"L": 3.0, "W": 1.1, "H": 1.9, "kmh": 8, "places": 1, "shape": "velo", "kind": "pousse", "col": Color("6b2737"), "desc": "Tiré à pied par un coureur."},
	"scooter": {"name": "Scooter des années 60", "cat": "deux_roues", "mode": ROAD, "era": "moderne", "region": "europe", "year": 1960,
		"L": 1.8, "W": 0.7, "H": 1.6, "kmh": 80, "places": 2, "shape": "moto", "kind": "scooter",
		"paints": [Color("a8dadc"), Color("e9c46a"), Color("f4f4f4"), Color("e5989b")], "desc": "Rond, chic et pratique."},
	"moto": {"name": "Moto", "cat": "deux_roues", "mode": ROAD, "era": "contemporain", "region": "monde", "year": 2015,
		"L": 2.1, "W": 0.8, "H": 1.6, "kmh": 180, "places": 2, "shape": "moto", "paints": BRIGHT, "desc": "Rapide et agile."},
	"side_car": {"name": "Moto side-car", "cat": "deux_roues", "mode": ROAD, "era": "classique", "region": "europe", "year": 1935,
		"L": 2.3, "W": 1.6, "H": 1.6, "kmh": 90, "places": 2, "shape": "moto", "kind": "side", "col": Color("4a5d23"), "desc": "Un passager dans la nacelle."},
	"moto_taxi": {"name": "Moto-taxi", "cat": "deux_roues", "mode": ROAD, "era": "contemporain", "region": "afrique", "year": 2015,
		"L": 2.0, "W": 0.8, "H": 1.6, "kmh": 90, "places": 2, "shape": "moto", "kind": "taxi", "paints": BRIGHT, "desc": "Le taxi le plus rapide des villes africaines."},
	"tuktuk": {"name": "Tuk-tuk", "cat": "deux_roues", "mode": ROAD, "era": "contemporain", "region": "asie_sud", "year": 2000,
		"L": 2.7, "W": 1.4, "H": 1.9, "kmh": 50, "places": 3, "shape": "tuktuk",
		"col": Color("2a9d8f"), "col2": Color("f1c40f"), "desc": "Trois roues, un toit, pas de portes."},

	# --- Attelages -------------------------------------------------------------------------
	"charrette": {"name": "Charrette", "cat": "attelage", "mode": ROAD, "era": "classique", "region": "monde", "year": 1800,
		"L": 3.2, "W": 1.6, "H": 1.6, "kmh": 6, "places": 2, "shape": "attelage", "kind": "charrette", "horses": 1, "desc": "Foin, récoltes et marchandises."},
	"caleche": {"name": "Calèche", "cat": "attelage", "mode": ROAD, "era": "classique", "region": "europe", "year": 1850,
		"L": 3.6, "W": 1.6, "H": 2.0, "kmh": 15, "places": 4, "shape": "attelage", "kind": "caleche", "horses": 2, "col": DARK, "desc": "Promenade élégante, capote repliée."},
	"diligence": {"name": "Diligence", "cat": "attelage", "mode": ROAD, "era": "classique", "region": "ameriques", "year": 1860,
		"L": 4.0, "W": 1.8, "H": 2.6, "kmh": 12, "places": 9, "shape": "attelage", "kind": "diligence", "horses": 4, "col": Color("8c2f39"), "desc": "Le courrier et les voyageurs du Far West."},
	"chariot_bache": {"name": "Chariot bâché", "cat": "attelage", "mode": ROAD, "era": "classique", "region": "ameriques", "year": 1850,
		"L": 4.2, "W": 1.6, "H": 2.8, "kmh": 5, "places": 4, "shape": "attelage", "kind": "bache", "horses": 2, "desc": "La maison roulante des pionniers."},
	"omnibus_chevaux": {"name": "Omnibus à chevaux", "cat": "attelage", "mode": ROAD, "era": "classique", "region": "europe", "year": 1880,
		"L": 5.0, "W": 2.0, "H": 3.2, "kmh": 10, "places": 30, "shape": "attelage", "kind": "omnibus", "horses": 2, "col": Color("2d6a4f"), "desc": "L'ancêtre du bus, avec impériale."},

	# --- Tramways ----------------------------------------------------------------------------
	"tram_1900": {"name": "Tramway électrique 1900", "cat": "tram", "mode": RAIL, "rail": "tram", "era": "classique", "region": "europe", "year": 1900,
		"L": 9.0, "W": 2.1, "H": 3.2, "kmh": 30, "places": 40, "shape": "tram", "style": "ancien", "col": Color("e9c46a"), "col2": Color("6b2737"),
		"desc": "Perche sur le fil et plateformes ouvertes."},
	"tram_cable": {"name": "Tramway à câble de San Francisco", "cat": "tram", "mode": RAIL, "rail": "tram", "era": "classique", "region": "ameriques", "year": 1890,
		"L": 8.5, "W": 2.4, "H": 3.2, "kmh": 15, "places": 60, "shape": "tram", "style": "cable", "col": Color("8c2f39"), "col2": Color("e9e2c8"),
		"desc": "Tiré par un câble sous la rue, voyageurs sur les marchepieds."},
	"tram_50": {"name": "Tramway des années 50", "cat": "tram", "mode": RAIL, "rail": "tram", "era": "moderne", "region": "ameriques", "year": 1950,
		"L": 14.0, "W": 2.6, "H": 3.2, "kmh": 70, "places": 100, "shape": "tram", "style": "rond", "col": Color("2d6a4f"), "col2": Color("f1faee"),
		"desc": "Bouts arrondis et grandes vitres."},
	"tram_etage": {"name": "Tramway à étage", "cat": "tram", "mode": RAIL, "rail": "tram", "era": "moderne", "region": "asie_est", "year": 1960,
		"L": 12.0, "W": 2.0, "H": 4.6, "kmh": 40, "places": 115, "shape": "tram", "style": "etage", "col": Color("2d6a4f"), "col2": Color("f1faee"),
		"desc": "Étroit et haut, comme à Hong Kong."},
	"tram_moderne": {"name": "Tramway moderne", "cat": "tram", "mode": RAIL, "rail": "tram", "era": "contemporain", "region": "europe", "year": 2010,
		"L": 11.0, "W": 2.65, "H": 3.4, "kmh": 70, "places": 90, "shape": "tram", "style": "moderne", "consist": ["tram_module", "tram_module"],
		"col": Color("f4f4f4"), "col2": Color("2a9d8f"), "desc": "Plancher bas, trois modules articulés."},
	"tram_module": {"name": "Module de tramway", "cat": "wagon", "mode": RAIL, "rail": "tram", "era": "contemporain", "region": "europe", "year": 2010,
		"L": 11.0, "W": 2.65, "H": 3.4, "kmh": 70, "places": 80, "shape": "tram", "style": "module", "col": Color("f4f4f4"), "col2": Color("2a9d8f"),
		"desc": "Caisse intermédiaire d'un tramway articulé.", "hidden": true},

	# --- Trains ---------------------------------------------------------------------------
	"vapeur_1830": {"name": "Locomotive à vapeur des débuts", "cat": "train", "mode": RAIL, "rail": "train", "era": "classique", "region": "europe", "year": 1830,
		"L": 6.5, "W": 2.4, "H": 4.2, "kmh": 45, "places": 0, "shape": "vapeur", "style": "debuts", "consist": ["tender", "voiture_diligence", "voiture_diligence"],
		"col": Color("f1c40f"), "col2": Color("2b2d42"), "desc": "Haute cheminée et grandes roues, la révolution du rail."},
	"vapeur_far_west": {"name": "Locomotive américaine à chasse-buffles", "cat": "train", "mode": RAIL, "rail": "train", "era": "classique", "region": "ameriques", "year": 1870,
		"L": 10.0, "W": 2.8, "H": 4.5, "kmh": 70, "places": 0, "shape": "vapeur", "style": "americaine", "consist": ["tender", "voiture_bois", "voiture_bois", "voiture_bois"],
		"col": Color("1b4332"), "col2": Color("c1121f"), "desc": "Cheminée en entonnoir et grosse lanterne."},
	"vapeur_pacific": {"name": "Locomotive à vapeur Pacific", "cat": "train", "mode": RAIL, "rail": "train", "era": "classique", "region": "europe", "year": 1930,
		"L": 14.0, "W": 3.0, "H": 4.3, "kmh": 130, "places": 0, "shape": "vapeur", "style": "pacific", "consist": ["tender", "voiture_1930", "voiture_1930", "voiture_1930", "voiture_1930"],
		"col": Color("1b1b1b"), "col2": Color("c1121f"), "desc": "Longue chaudière et écrans pare-fumée."},
	"train_luxe": {"name": "Train de luxe des années 20", "cat": "train", "mode": RAIL, "rail": "train", "era": "classique", "region": "europe", "year": 1925,
		"L": 14.0, "W": 3.0, "H": 4.3, "kmh": 120, "places": 0, "shape": "vapeur", "style": "pacific", "consist": ["tender", "voiture_luxe", "voiture_luxe", "voiture_luxe", "voiture_luxe"],
		"col": Color("14213d"), "col2": Color("d4a373"), "desc": "Voitures-lits bleu nuit et filets dorés."},
	"diesel_fret": {"name": "Locomotive diesel de fret", "cat": "train", "mode": RAIL, "rail": "train", "era": "moderne", "region": "ameriques", "year": 1970,
		"L": 20.0, "W": 3.1, "H": 4.6, "kmh": 110, "places": 0, "shape": "diesel", "style": "capot", "consist": ["wagon_couvert", "wagon_citerne", "wagon_conteneurs", "wagon_tremie", "wagon_conteneurs", "wagon_grumes"],
		"col": Color("f77f00"), "col2": DARK, "desc": "Longs convois de marchandises."},
	"vapeur_marchandises": {"name": "Train de marchandises à vapeur", "cat": "train", "mode": RAIL, "rail": "train", "era": "classique", "region": "europe", "year": 1905,
		"L": 12.0, "W": 2.9, "H": 4.2, "kmh": 60, "places": 0, "shape": "vapeur", "style": "pacific", "consist": ["tender", "wagon_couvert", "wagon_tremie", "wagon_grumes", "wagon_couvert", "wagon_tremie"],
		"col": Color("2b2d42"), "col2": Color("6b705c"), "desc": "Lourd et lent, il tire charbon, bois et céréales."},
	"electrique_fret": {"name": "Locomotive électrique de fret", "cat": "train", "mode": RAIL, "rail": "train", "era": "contemporain", "region": "europe", "year": 2005,
		"L": 19.0, "W": 3.0, "H": 4.3, "kmh": 140, "places": 0, "shape": "electrique", "consist": ["wagon_conteneurs", "wagon_conteneurs", "wagon_conteneurs", "wagon_citerne", "wagon_citerne", "wagon_conteneurs"],
		"col": Color("2d6a4f"), "col2": Color("f1faee"), "desc": "Conteneurs et citernes entre ports et plateformes logistiques."},
	"diesel_desert": {"name": "Train de voyageurs du désert", "cat": "train", "mode": RAIL, "rail": "train", "era": "moderne", "region": "afrique", "year": 1975,
		"L": 17.0, "W": 3.0, "H": 4.2, "kmh": 100, "places": 0, "shape": "diesel", "style": "cabine", "consist": ["voiture_corail", "voiture_corail", "wagon_couvert"],
		"col": Color("dda15e"), "col2": Color("6b2737"), "desc": "Locomotive diesel à cabines, couleur sable."},
	"electrique_60": {"name": "Locomotive électrique", "cat": "train", "mode": RAIL, "rail": "train", "era": "moderne", "region": "europe", "year": 1965,
		"L": 16.0, "W": 3.0, "H": 4.3, "kmh": 160, "places": 0, "shape": "electrique", "consist": ["voiture_corail", "voiture_corail", "voiture_corail", "voiture_corail"],
		"col": Color("3d5a80"), "col2": Color("e0fbfc"), "desc": "Deux pantographes, la traction des grandes lignes."},
	"autorail": {"name": "Autorail régional", "cat": "train", "mode": RAIL, "rail": "train", "era": "moderne", "region": "europe", "year": 1960,
		"L": 22.0, "W": 2.9, "H": 3.9, "kmh": 120, "places": 80, "shape": "automotrice", "style": "autorail",
		"col": Color("c1121f"), "col2": Color("f1c40f"), "desc": "Un seul véhicule diesel pour les petites lignes."},
	"regional": {"name": "Train régional électrique", "cat": "train", "mode": RAIL, "rail": "train", "era": "contemporain", "region": "europe", "year": 2010,
		"L": 18.0, "W": 2.95, "H": 4.2, "kmh": 160, "places": 220, "shape": "automotrice", "style": "nez", "consist": ["regional_voiture", "regional_voiture", "regional_queue"],
		"col": Color("f4f4f4"), "col2": Color("0096c7"), "desc": "Rame à plancher bas, portes larges."},
	"metro": {"name": "Métro", "cat": "train", "mode": RAIL, "rail": "train", "era": "contemporain", "region": "monde", "year": 2005,
		"L": 15.0, "W": 2.6, "H": 3.6, "kmh": 80, "places": 140, "shape": "automotrice", "style": "metro", "consist": ["metro_voiture", "metro_voiture", "metro_voiture"],
		"col": Color("dee2e6"), "col2": Color("e63946"), "desc": "Rames courtes à quatre portes par côté."},
	"tgv": {"name": "Train à grande vitesse", "cat": "train", "mode": RAIL, "rail": "lgv", "era": "contemporain", "region": "europe", "year": 1990,
		"L": 22.0, "W": 2.9, "H": 4.1, "kmh": 320, "places": 0, "shape": "grande_vitesse", "nose": 5.0, "consist": ["tgv_voiture", "tgv_voiture", "tgv_voiture", "tgv_voiture"],
		"col": Color("f4f4f4"), "col2": Color("3d5a80"), "desc": "Motrice au nez profilé, 320 km/h."},
	"shinkansen": {"name": "Train à grande vitesse japonais", "cat": "train", "mode": RAIL, "rail": "lgv", "era": "contemporain", "region": "asie_est", "year": 2007,
		"L": 27.0, "W": 3.38, "H": 3.6, "kmh": 300, "places": 60, "shape": "grande_vitesse", "nose": 10.0, "consist": ["shinkansen_voiture", "shinkansen_voiture", "shinkansen_voiture"],
		"col": Color("f8f9fa"), "col2": Color("1d4ed8"), "desc": "Nez très long contre le bruit dans les tunnels."},
	"maglev": {"name": "Train à sustentation magnétique", "cat": "train", "mode": RAIL, "rail": "lgv", "era": "futuriste", "region": "asie_est", "year": 2030,
		"L": 28.0, "W": 2.9, "H": 3.5, "kmh": 500, "places": 70, "shape": "grande_vitesse", "nose": 12.0, "maglev": true, "consist": ["maglev_voiture", "maglev_voiture"],
		"col": Color("e9ecef"), "col2": Color("7b2cbf"), "desc": "Flotte sur la voie, 500 km/h."},

	# --- Voitures et wagons ------------------------------------------------------------------
	"tender": {"name": "Tender", "cat": "wagon", "mode": RAIL, "era": "classique", "region": "monde", "year": 1850, "L": 7.0, "W": 2.8, "H": 3.2, "kmh": 120, "places": 0,
		"shape": "fret", "kind": "tender", "col": Color("1b1b1b"), "desc": "Charbon et eau de la locomotive."},
	"voiture_diligence": {"name": "Voiture-diligence", "cat": "wagon", "mode": RAIL, "era": "classique", "region": "europe", "year": 1830, "L": 6.0, "W": 2.3, "H": 3.0, "kmh": 45, "places": 18,
		"shape": "voyageurs", "style": "debuts", "col": Color("6b2737"), "col2": Color("f1c40f"), "desc": "Trois caisses de diligence posées sur un châssis."},
	"voiture_bois": {"name": "Voiture en bois à lanterneau", "cat": "wagon", "mode": RAIL, "era": "classique", "region": "ameriques", "year": 1870, "L": 15.0, "W": 2.9, "H": 3.9, "kmh": 70, "places": 50,
		"shape": "voyageurs", "style": "lanterneau", "col": Color("8b4513"), "col2": Color("e9c46a"), "desc": "Toit surélevé pour l'aération."},
	"voiture_1930": {"name": "Voiture de voyageurs des années 30", "cat": "wagon", "mode": RAIL, "era": "classique", "region": "europe", "year": 1930, "L": 22.0, "W": 2.9, "H": 4.0, "kmh": 140, "places": 70,
		"shape": "voyageurs", "style": "fenetres", "col": Color("2d6a4f"), "col2": Color("d8f3dc"), "desc": "Compartiments et fenêtres à guillotine."},
	"voiture_luxe": {"name": "Voiture-lits de luxe", "cat": "wagon", "mode": RAIL, "era": "classique", "region": "europe", "year": 1925, "L": 23.0, "W": 2.9, "H": 4.0, "kmh": 140, "places": 20,
		"shape": "voyageurs", "style": "fenetres", "col": Color("14213d"), "col2": Color("d4a373"), "desc": "Boiseries et cabines privées."},
	"voiture_corail": {"name": "Voiture de grandes lignes", "cat": "wagon", "mode": RAIL, "era": "moderne", "region": "europe", "year": 1975, "L": 26.0, "W": 2.9, "H": 4.0, "kmh": 160, "places": 80,
		"shape": "voyageurs", "style": "bandeau", "col": Color("e9ecef"), "col2": Color("e76f51"), "desc": "Climatisée, grandes baies."},
	"regional_voiture": {"name": "Voiture de train régional", "cat": "wagon", "mode": RAIL, "era": "contemporain", "region": "europe", "year": 2010, "L": 18.0, "W": 2.95, "H": 4.2, "kmh": 160, "places": 220,
		"shape": "automotrice", "style": "milieu", "col": Color("f4f4f4"), "col2": Color("0096c7"), "desc": "Caisse intermédiaire.", "hidden": true},
	"regional_queue": {"name": "Voiture de queue de train régional", "cat": "wagon", "mode": RAIL, "era": "contemporain", "region": "europe", "year": 2010, "L": 18.0, "W": 2.95, "H": 4.2, "kmh": 160, "places": 200,
		"shape": "automotrice", "style": "queue", "col": Color("f4f4f4"), "col2": Color("0096c7"), "desc": "Cabine arrière.", "hidden": true},
	"metro_voiture": {"name": "Voiture de métro", "cat": "wagon", "mode": RAIL, "era": "contemporain", "region": "monde", "year": 2005, "L": 15.0, "W": 2.6, "H": 3.6, "kmh": 80, "places": 140,
		"shape": "automotrice", "style": "metro_milieu", "col": Color("dee2e6"), "col2": Color("e63946"), "desc": "Caisse de métro.", "hidden": true},
	"tgv_voiture": {"name": "Voiture de train à grande vitesse", "cat": "wagon", "mode": RAIL, "era": "contemporain", "region": "europe", "year": 1990, "L": 18.7, "W": 2.9, "H": 4.0, "kmh": 320, "places": 56,
		"shape": "voyageurs", "style": "gv", "col": Color("f4f4f4"), "col2": Color("3d5a80"), "desc": "Voiture articulée à deux niveaux.", "hidden": true},
	"shinkansen_voiture": {"name": "Voiture de train à grande vitesse japonais", "cat": "wagon", "mode": RAIL, "era": "contemporain", "region": "asie_est", "year": 2007, "L": 25.0, "W": 3.38, "H": 3.6, "kmh": 300, "places": 100,
		"shape": "voyageurs", "style": "gv", "col": Color("f8f9fa"), "col2": Color("1d4ed8"), "desc": "Voiture intermédiaire.", "hidden": true},
	"maglev_voiture": {"name": "Voiture de train magnétique", "cat": "wagon", "mode": RAIL, "era": "futuriste", "region": "asie_est", "year": 2030, "L": 25.0, "W": 2.9, "H": 3.5, "kmh": 500, "places": 100,
		"shape": "voyageurs", "style": "maglev", "col": Color("e9ecef"), "col2": Color("7b2cbf"), "desc": "Voiture intermédiaire.", "hidden": true},
	"wagon_couvert": {"name": "Wagon couvert", "cat": "wagon", "mode": RAIL, "era": "moderne", "region": "monde", "year": 1950, "L": 14.0, "W": 2.9, "H": 4.0, "kmh": 100, "places": 0,
		"shape": "fret", "kind": "couvert", "col": Color("9c4a1a"), "desc": "Marchandises à l'abri, portes coulissantes."},
	"wagon_citerne": {"name": "Wagon-citerne", "cat": "wagon", "mode": RAIL, "era": "moderne", "region": "monde", "year": 1960, "L": 14.0, "W": 2.9, "H": 3.8, "kmh": 100, "places": 0,
		"shape": "fret", "kind": "citerne", "col": Color("212529"), "desc": "Pétrole, produits chimiques."},
	"wagon_conteneurs": {"name": "Wagon porte-conteneurs", "cat": "wagon", "mode": RAIL, "era": "contemporain", "region": "monde", "year": 1990, "L": 18.0, "W": 2.9, "H": 3.9, "kmh": 120, "places": 0,
		"shape": "fret", "kind": "conteneurs", "col": Color("495057"), "desc": "Deux conteneurs de 20 pieds."},
	"wagon_tremie": {"name": "Wagon-trémie", "cat": "wagon", "mode": RAIL, "era": "moderne", "region": "monde", "year": 1960, "L": 13.0, "W": 2.9, "H": 3.8, "kmh": 100, "places": 0,
		"shape": "fret", "kind": "tremie", "col": Color("6c757d"), "desc": "Céréales, minerai, charbon."},
	"wagon_grumes": {"name": "Wagon à grumes", "cat": "wagon", "mode": RAIL, "era": "classique", "region": "monde", "year": 1920, "L": 13.0, "W": 2.9, "H": 3.3, "kmh": 80, "places": 0,
		"shape": "fret", "kind": "grumes", "col": Color("495057"), "desc": "Plateau chargé de troncs."},

	# --- Bateaux ------------------------------------------------------------------------------
	"pirogue": {"name": "Pirogue", "cat": "bateau", "mode": WATER, "era": "antique", "region": "afrique", "year": -5000, "L": 8.0, "W": 1.0, "H": 0.6, "kmh": 8, "places": 6,
		"shape": "bateau", "kind": "pirogue", "col": Color("7f4f24"), "desc": "Creusée dans un seul tronc."},
	"pirogue_balancier": {"name": "Pirogue à balancier", "cat": "bateau", "mode": WATER, "era": "antique", "region": "asie_sud", "year": -1000, "L": 9.0, "W": 3.0, "H": 4.5, "kmh": 15, "places": 6,
		"shape": "bateau", "kind": "balancier", "col": Color("7f4f24"), "col2": Color("efe6d0"), "desc": "Le balancier qui a permis de peupler le Pacifique."},
	"barque": {"name": "Barque à rames", "cat": "bateau", "mode": WATER, "era": "classique", "region": "monde", "year": 1800, "L": 4.0, "W": 1.4, "H": 0.7, "kmh": 6, "places": 3,
		"shape": "bateau", "kind": "barque", "col": Color("588157"), "desc": "Promenade sur le lac."},
	"gondole": {"name": "Gondole", "cat": "bateau", "mode": WATER, "era": "traditionnel", "region": "europe", "year": 1700, "L": 11.0, "W": 1.4, "H": 1.6, "kmh": 6, "places": 6,
		"shape": "bateau", "kind": "gondole", "col": Color("111111"), "desc": "Le gondolier rame debout à l'arrière."},
	"drakkar": {"name": "Drakkar", "cat": "bateau", "mode": WATER, "era": "traditionnel", "region": "europe", "year": 900, "L": 23.0, "W": 5.0, "H": 12.0, "kmh": 20, "places": 60,
		"shape": "bateau", "kind": "drakkar", "col": Color("6f4518"), "col2": Color("c1121f"), "desc": "Voile carrée, boucliers et tête de dragon."},
	"jonque": {"name": "Jonque", "cat": "bateau", "mode": WATER, "era": "traditionnel", "region": "asie_est", "year": 1400, "L": 25.0, "W": 7.0, "H": 18.0, "kmh": 15, "places": 40,
		"shape": "bateau", "kind": "jonque", "col": Color("7f5539"), "col2": Color("bc4749"), "desc": "Voiles à lattes et poupe haute."},
	"sampan": {"name": "Sampan", "cat": "bateau", "mode": WATER, "era": "traditionnel", "region": "asie_est", "year": 1600, "L": 6.0, "W": 1.8, "H": 1.6, "kmh": 6, "places": 4,
		"shape": "bateau", "kind": "sampan", "col": Color("9c6644"), "col2": Color("d4a373"), "desc": "Petit bateau à toit de bambou."},
	"felouque": {"name": "Felouque", "cat": "bateau", "mode": WATER, "era": "antique", "region": "afrique", "year": -2000, "L": 9.0, "W": 2.6, "H": 10.0, "kmh": 10, "places": 10,
		"shape": "bateau", "kind": "latine", "col": Color("f1faee"), "col2": Color("f8f9fa"), "desc": "Voile latine sur le Nil."},
	"boutre": {"name": "Boutre arabe", "cat": "bateau", "mode": WATER, "era": "traditionnel", "region": "moyen_orient", "year": 1000, "L": 18.0, "W": 5.0, "H": 16.0, "kmh": 15, "places": 25,
		"shape": "bateau", "kind": "latine", "col": Color("9c6644"), "col2": Color("efe6d0"), "desc": "Commerce des épices dans l'océan Indien."},
	"caravelle": {"name": "Caravelle", "cat": "bateau", "mode": WATER, "era": "traditionnel", "region": "europe", "year": 1490, "L": 22.0, "W": 6.0, "H": 20.0, "kmh": 15, "places": 30,
		"shape": "bateau", "kind": "caravelle", "col": Color("6f4518"), "col2": Color("efe6d0"), "desc": "Le navire des grandes découvertes."},
	"bateau_aubes": {"name": "Bateau à aubes", "cat": "bateau", "mode": WATER, "era": "classique", "region": "ameriques", "year": 1850, "L": 40.0, "W": 10.0, "H": 14.0, "kmh": 15, "places": 300,
		"shape": "bateau", "kind": "aubes", "col": Color("f8f9fa"), "col2": Color("c1121f"), "desc": "Grande roue à l'arrière, sur le Mississippi."},
	"peniche": {"name": "Péniche", "cat": "bateau", "mode": WATER, "era": "moderne", "region": "europe", "year": 1950, "L": 38.5, "W": 5.05, "H": 4.0, "kmh": 12, "places": 2,
		"shape": "bateau", "kind": "peniche", "col": Color("1d3557"), "col2": Color("e9c46a"), "desc": "Gabarit Freycinet des canaux français."},
	"bateau_bus": {"name": "Bateau-bus", "cat": "bateau", "mode": WATER, "era": "moderne", "region": "europe", "year": 1960, "L": 24.0, "W": 4.5, "H": 3.6, "kmh": 20, "places": 200,
		"shape": "bateau", "kind": "bus", "col": Color("f4f4f4"), "col2": Color("2a9d8f"), "desc": "Transport en commun sur l'eau."},
	"remorqueur": {"name": "Remorqueur", "cat": "bateau", "mode": WATER, "era": "moderne", "region": "monde", "year": 1970, "L": 28.0, "W": 9.0, "H": 10.0, "kmh": 22, "places": 6,
		"shape": "bateau", "kind": "remorqueur", "col": Color("c1121f"), "col2": Color("f4f4f4"), "desc": "Petit mais très puissant."},
	"hors_bord": {"name": "Hors-bord", "cat": "bateau", "mode": WATER, "era": "contemporain", "region": "monde", "year": 2000, "L": 6.0, "W": 2.3, "H": 1.6, "kmh": 70, "places": 6,
		"shape": "bateau", "kind": "hors_bord", "col": Color("f4f4f4"), "col2": Color("e63946"), "desc": "Vitesse et ski nautique."},
	"voilier": {"name": "Voilier de plaisance", "cat": "bateau", "mode": WATER, "era": "contemporain", "region": "monde", "year": 1990, "L": 11.0, "W": 3.6, "H": 15.0, "kmh": 14, "places": 8,
		"shape": "bateau", "kind": "voilier", "col": Color("f4f4f4"), "col2": Color("f8f9fa"), "desc": "Grand-voile et foc."},
	"ferry": {"name": "Ferry", "cat": "bateau", "mode": WATER, "era": "contemporain", "region": "monde", "year": 2000, "L": 120.0, "W": 22.0, "H": 30.0, "kmh": 40, "places": 1500,
		"shape": "bateau", "kind": "ferry", "col": Color("f4f4f4"), "col2": Color("0077b6"), "desc": "Voitures en cale, passagers sur les ponts."},
	"porte_conteneurs": {"name": "Porte-conteneurs", "cat": "bateau", "mode": WATER, "era": "contemporain", "region": "monde", "year": 2010, "L": 200.0, "W": 32.0, "H": 40.0, "kmh": 45, "places": 25,
		"shape": "bateau", "kind": "cargo", "col": Color("1d3557"), "col2": Color("c1121f"), "desc": "Des milliers de conteneurs à travers les océans."},
	"paquebot_1912": {"name": "Paquebot transatlantique", "cat": "bateau", "mode": WATER, "era": "classique", "region": "europe", "year": 1912, "L": 260.0, "W": 28.0, "H": 50.0, "kmh": 40, "places": 3000,
		"shape": "bateau", "kind": "paquebot", "col": Color("111111"), "col2": Color("e9c46a"), "desc": "Quatre cheminées pour traverser l'Atlantique."},
	"croisiere": {"name": "Navire de croisière", "cat": "bateau", "mode": WATER, "era": "contemporain", "region": "monde", "year": 2015, "L": 300.0, "W": 38.0, "H": 65.0, "kmh": 40, "places": 5000,
		"shape": "bateau", "kind": "croisiere", "col": Color("f8f9fa"), "col2": Color("0096c7"), "desc": "Une ville flottante."},

	# --- Aéronefs ----------------------------------------------------------------------------
	"montgolfiere": {"name": "Montgolfière", "cat": "avion", "mode": AIR, "era": "traditionnel", "region": "europe", "year": 1783, "L": 16.0, "W": 16.0, "H": 22.0, "kmh": 20, "places": 4,
		"shape": "aeronef", "kind": "ballon", "col": Color("e63946"), "col2": Color("f1c40f"), "desc": "Le premier vol humain, porté par l'air chaud."},
	"dirigeable": {"name": "Dirigeable", "cat": "avion", "mode": AIR, "era": "classique", "region": "europe", "year": 1930, "L": 120.0, "W": 26.0, "H": 30.0, "kmh": 120, "places": 50,
		"shape": "aeronef", "kind": "dirigeable", "col": Color("ced4da"), "col2": Color("495057"), "desc": "Un géant gonflé qui traversait l'Atlantique."},
	"biplan": {"name": "Biplan", "cat": "avion", "mode": AIR, "era": "classique", "region": "europe", "year": 1920, "L": 7.5, "W": 10.0, "H": 3.0, "kmh": 180, "places": 2,
		"shape": "aeronef", "kind": "biplan", "col": Color("e9c46a"), "col2": Color("c1121f"), "desc": "Deux ailes en toile et un pilote en plein air."},
	"hydravion": {"name": "Hydravion", "cat": "avion", "mode": AIR, "era": "classique", "region": "monde", "year": 1935, "L": 11.0, "W": 15.0, "H": 4.0, "kmh": 250, "places": 8,
		"shape": "aeronef", "kind": "hydravion", "col": Color("f4f4f4"), "col2": Color("e63946"), "desc": "Se pose sur l'eau grâce à ses flotteurs."},
	"avion_helice": {"name": "Avion de ligne à hélices", "cat": "avion", "mode": AIR, "era": "classique", "region": "ameriques", "year": 1940, "L": 19.7, "W": 29.0, "H": 5.2, "kmh": 330, "places": 30,
		"shape": "aeronef", "kind": "helices", "col": Color("ced4da"), "col2": Color("1d3557"), "desc": "Le bimoteur qui a lancé l'aviation commerciale."},
	"regional_turboprop": {"name": "Avion régional à turbopropulseurs", "cat": "avion", "mode": AIR, "era": "contemporain", "region": "europe", "year": 1995, "L": 27.0, "W": 27.0, "H": 7.6, "kmh": 510, "places": 70,
		"shape": "aeronef", "kind": "turboprop", "col": Color("f4f4f4"), "col2": Color("2a9d8f"), "desc": "Aile haute, hélices, petites distances."},
	"court_courrier": {"name": "Avion de ligne court-courrier", "cat": "avion", "mode": AIR, "era": "contemporain", "region": "monde", "year": 2000, "L": 37.6, "W": 35.8, "H": 11.8, "kmh": 840, "places": 180,
		"shape": "aeronef", "kind": "jet", "col": Color("f4f4f4"), "col2": Color("e63946"), "desc": "Le biréacteur le plus courant au monde."},
	"gros_porteur": {"name": "Gros-porteur quadriréacteur", "cat": "avion", "mode": AIR, "era": "moderne", "region": "ameriques", "year": 1970, "L": 70.0, "W": 64.0, "H": 19.0, "kmh": 910, "places": 400,
		"shape": "aeronef", "kind": "gros", "col": Color("f4f4f4"), "col2": Color("1d3557"), "desc": "Pont supérieur et quatre réacteurs."},
	"supersonique": {"name": "Avion de ligne supersonique", "cat": "avion", "mode": AIR, "era": "moderne", "region": "europe", "year": 1976, "L": 61.7, "W": 25.6, "H": 12.2, "kmh": 2170, "places": 100,
		"shape": "aeronef", "kind": "delta", "col": Color("f8f9fa"), "col2": Color("1d3557"), "desc": "Aile delta et nez basculant, Paris-New York en 3 h 30."},
	"jet_prive": {"name": "Jet d'affaires", "cat": "avion", "mode": AIR, "era": "contemporain", "region": "monde", "year": 2005, "L": 16.0, "W": 16.0, "H": 4.8, "kmh": 850, "places": 8,
		"shape": "aeronef", "kind": "affaires", "col": Color("f8f9fa"), "col2": Color("adb5bd"), "desc": "Réacteurs à l'arrière et empennage en T."},
	"helicoptere": {"name": "Hélicoptère", "cat": "avion", "mode": AIR, "era": "contemporain", "region": "monde", "year": 1990, "L": 12.0, "W": 2.5, "H": 3.5, "kmh": 260, "places": 6,
		"shape": "aeronef", "kind": "helico", "col": Color("e63946"), "col2": Color("f4f4f4"), "desc": "Décolle à la verticale, se pose partout."},
	"taxi_volant": {"name": "Taxi volant électrique", "cat": "avion", "mode": AIR, "era": "futuriste", "region": "monde", "year": 2035, "L": 6.0, "W": 7.0, "H": 2.2, "kmh": 150, "places": 2,
		"shape": "aeronef", "kind": "multirotor", "col": Color("f8f9fa"), "col2": Color("4cc9f0"), "desc": "Huit rotors au-dessus des embouteillages."},
}


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, {})


static func category(cat: String) -> Dictionary:
	for c in CATEGORIES:
		if c.id == cat:
			return c
	return {}


static func era_name(id: String) -> String:
	return Styles.era_name(id)


static func region_name(id: String) -> String:
	return Styles.region_name(id)


## Vrai si le modèle transporte des marchandises (camions, charrettes, trains
## de fret, cargos, péniches…).
static func is_freight(id: String) -> bool:
	var t := get_type(id)
	match String(t.get("cat", "")):
		"utilitaire":
			return String(t.get("cargo", "caisse")) in ["caisse", "benne", "citerne", "grumes", "conteneur"]
		"attelage":
			return String(t.get("kind", "")) == "charrette"
		"train":
			for w in t.get("consist", []):
				var wt := get_type(w)
				if String(wt.get("shape", "")) == "fret" and String(wt.get("kind", "")) != "tender":
					return true
			return false
		"bateau":
			return String(t.get("kind", "")) in ["cargo", "peniche"] or id in ["boutre", "jonque", "drakkar"]
	return false


## Charge utile approximative (tonnes) d'un véhicule de fret.
static func capacity_t(id: String) -> float:
	var t := get_type(id)
	var l := float(t.get("L", 5.0))
	match String(t.get("cat", "")):
		"utilitaire":
			return snappedf(maxf(1.0, (l - 3.0) * 1.6), 0.5)
		"attelage":
			return 0.5
		"train":
			var n := 0
			for w in t.get("consist", []):
				if String(get_type(w).get("shape", "")) == "fret" and String(get_type(w).get("kind", "")) != "tender":
					n += 1
			return n * 50.0
		"bateau":
			if String(t.get("kind", "")) == "peniche":
				return 1000.0
			return snappedf(l * l * 2.5, 10.0)
	return 0.0


static func ids_in(cat: String, include_hidden := false) -> Array[String]:
	var out: Array[String] = []
	for id in TYPES:
		if TYPES[id].cat == cat and (include_hidden or not TYPES[id].get("hidden", false)):
			out.append(id)
	return out


## Types qui peuvent rouler sur une voie de la classe donnée (TransportTypes),
## filtrés par époque et région ("" = toutes). Les voitures et wagons attelés
## (hidden) sont exclus : ils viennent avec leur tête de train.
static func for_track(class_id: String, era := "", region := "") -> Array[String]:
	var mode := TransportTypes.mode_of(class_id)
	var cls := TransportTypes.resolve(class_id)
	var out: Array[String] = []
	for id in TYPES:
		var t: Dictionary = TYPES[id]
		if t.get("hidden", false) or t.cat == "wagon":
			continue
		if not matches(id, era, region):
			continue
		if int(t.mode) != mode:
			continue
		if mode == RAIL:
			var r: String = t.get("rail", "train")
			if cls == "tram" and r != "tram":
				continue
			if cls == "lgv" and r == "tram":
				continue
			if cls != "tram" and cls != "lgv" and r != "train":
				continue
		elif mode == PATH and cls == "trottoir" and t.cat == "deux_roues" and String(t.get("kind", "")) != "trottinette":
			continue
		elif mode == WATER and cls == "canal" and float(t.L) > 45.0:
			continue
		elif mode == WATER and cls == "chenal" and float(t.L) < 20.0:
			continue
		out.append(id)
	return out


## Vrai si le type correspond au filtre d'époque et de région ("" = tout).
## Un type "monde" convient à toutes les régions.
static func matches(id: String, era := "", region := "") -> bool:
	var t := get_type(id)
	if t.is_empty():
		return false
	if era != "" and t.era != era:
		return false
	if region != "" and region != "monde" and t.region != region and t.region != "monde":
		return false
	return true


static func describe(id: String) -> String:
	var t := get_type(id)
	if t.is_empty():
		return ""
	var bits: Array[String] = ["%s (%s, %s)" % [t.name, era_name(t.era).to_lower(), region_name(t.region)]]
	bits.append("%s m de long, %d km/h" % [TransportTypes._num(float(t.L)), int(t.kmh)])
	if int(t.get("places", 0)) > 0:
		bits.append("%d places" % int(t.places))
	return " · ".join(bits) + "\n" + String(t.get("desc", ""))


## Couleur principale d'un modèle (paint : teinte au hasard parmi paints).
static func paint_of(id: String, paint: int) -> Color:
	var t := get_type(id)
	var paints: Array = t.get("paints", [])
	if not paints.is_empty() and paint >= 0:
		return paints[paint % paints.size()]
	if t.has("col"):
		return t.col
	if not paints.is_empty():
		return paints[0]
	return PAINTS[0]


static func paint_count(id: String) -> int:
	return maxi(1, (get_type(id).get("paints", []) as Array).size())


## Fabrique le modèle low-poly (avant vers −Z, sol ou flottaison en y = 0).
static func build_mesh(id: String, paint := -1, material: Material = null) -> ArrayMesh:
	var k := VehicleMesh.new()
	var t := get_type(id)
	if t.is_empty():
		k.box(0, 0, 0, 1.6, 1.4, 4.0, PAINTS[0])
		return k.to_mesh(material)
	var col := paint_of(id, paint)
	var col2: Color = t.get("col2", col.darkened(0.3))
	match String(t.shape):
		"voiture": _car(k, t, col)
		"ancienne": _old_car(k, t, col)
		"camion": _truck(k, t, col, col2)
		"tracteur": _tractor(k, t, col, col2)
		"bus": _bus(k, t, col, col2)
		"velo": _bike(k, t, col)
		"moto": _moto(k, t, col)
		"tuktuk": _tuktuk(k, t, col, col2)
		"attelage": _cart(k, t, col)
		"tram": _tram(k, t, col, col2)
		"vapeur": _steam(k, t, col, col2)
		"diesel": _diesel(k, t, col, col2)
		"electrique": _electric(k, t, col, col2)
		"automotrice": _emu(k, t, col, col2)
		"grande_vitesse": _high_speed(k, t, col, col2)
		"voyageurs": _coach(k, t, col, col2)
		"fret": _freight(k, t, col)
		"bateau": _boat(k, t, col, col2)
		"aeronef": _aircraft(k, t, col, col2)
		_: k.box(0, 0, 0, float(t.W), float(t.H), float(t.L), col)
	return k.to_mesh(material)


# --- Route -----------------------------------------------------------------------------

static func _lights(k: VehicleMesh, L: float, W: float, y: float) -> void:
	for s in [-1.0, 1.0]:
		k.box(s * W * 0.33, y, -L / 2.0 - 0.01, W * 0.18, 0.12, 0.06, VehicleMesh.LIGHT)
		k.box(s * W * 0.36, y, L / 2.0 + 0.01, W * 0.14, 0.12, 0.06, VehicleMesh.REAR)


static func _car(k: VehicleMesh, t: Dictionary, col: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var r := float(t.get("r", 0.31))
	var y0 := r * 0.55
	var bh := float(t.get("bh", 0.55))
	var yb := y0 + bh
	k.taper(0, y0, yb, -L / 2, L / 2, W * 0.97, W, 0.12, 0.08, col)
	var cz0 := -L / 2 + L * float(t.get("hood", 0.22))
	var cz1 := L / 2 - L * float(t.get("trunk", 0.15))
	var sf := float(t.get("sf", 0.5))
	var sb := float(t.get("sb", 0.4))
	var top := float(t.get("top", 0.82))
	if t.get("panel", false):
		# Fourgon : caisse tôlée, vitres seulement à l'avant.
		k.taper(0, yb, H, cz0 + 1.6, cz1, W, W * top, 0.0, sb, col)
		k.taper(0, yb, H, cz0, cz0 + 1.6, W * 0.96, W * top, sf, 0.0, VehicleMesh.GLASS)
		k.taper(0, H - 0.02, H + 0.04, cz0 + sf, cz0 + 1.6, W * top, W * top, 0.0, 0.0, col)
	else:
		var belt := yb + (H - yb) * 0.2
		var wb := lerpf(W * 0.94, W * top, 0.2)
		k.taper(0, yb, belt, cz0, cz1, W * 0.94, wb, sf * 0.2, sb * 0.2, col)
		k.taper(0, belt, H, cz0 + sf * 0.2, cz1 - sb * 0.2, wb, W * top, sf * 0.8, sb * 0.8, VehicleMesh.GLASS)
		k.taper(0, H - 0.02, H + 0.05, cz0 + sf, cz1 - sb, W * top, W * top * 0.97, 0.03, 0.03, col)
	_lights(k, L, W, y0 + bh * 0.55)
	var wz := L / 2 - L * 0.17
	k.axle(W / 2 - 0.14, -wz, r)
	k.axle(W / 2 - 0.14, wz, r)
	if t.get("fins", false):
		for s in [-1.0, 1.0]:
			k.taper(s * (W / 2 - 0.1), yb, yb + 0.28, L / 2 - 1.3, L / 2, 0.08, 0.05, 1.0, 0.0, col.lightened(0.1))
		k.box(0, y0 + 0.1, -L / 2 - 0.05, W * 0.95, 0.14, 0.1, Color("d9d9d9"))
		k.box(0, y0 + 0.1, L / 2 + 0.05, W * 0.95, 0.14, 0.1, Color("d9d9d9"))
	if t.get("sign", false):
		k.box(0, H + 0.05, (cz0 + cz1) / 2, 0.6, 0.22, 0.25, Color("ffe066"))
	if t.get("rack", false):
		k.box(0, H + 0.05, (cz0 + cz1) / 2, W * top * 0.95, 0.06, (cz1 - cz0) * 0.8, DARK)
		k.box(0.2, H + 0.11, (cz0 + cz1) / 2, 0.8, 0.35, 1.0, Color("a98467"))
	if t.get("spare", false):
		k.z_cyl(0, yb + 0.15, L / 2, L / 2 + 0.22, r, r, 8, VehicleMesh.TIRE)
	if t.get("bed", false):
		var bz := (cz1 + L / 2) / 2
		var bl := L / 2 - cz1
		for s in [-1.0, 1.0]:
			k.box(s * (W / 2 - 0.05), yb, bz, 0.1, 0.4, bl, col)
		k.box(0, yb, L / 2 - 0.05, W, 0.4, 0.1, col)
		k.box(0, yb - 0.02, bz, W - 0.2, 0.04, bl, DARK)


static func _old_car(k: VehicleMesh, t: Dictionary, col: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var r := 0.36
	var open: bool = t.get("open", false)
	k.box(0, 0.42, 0, W * 0.7, 0.22, L * 0.96, DARK)
	# Capot et calandre.
	k.box(0, 0.62, -L / 2 + L * 0.17, W * 0.56, 0.55, L * 0.3, col)
	k.box(0, 0.6, -L / 2 + 0.02, W * 0.56, 0.62, 0.08, Color("c9ccd1"))
	for s in [-1.0, 1.0]:
		k.cylinder(s * W * 0.32, 0.95, -L / 2 + 0.1, 0.12, 0.12, 0.2, 6, Color("e9e2c8"))
	# Caisse.
	var cz := L * 0.12
	var cl := L * 0.56
	if open:
		k.box(0, 0.62, cz, W * 0.86, 0.55, cl, col)
		k.box(0, 0.9, cz + cl * 0.15, W * 0.8, 0.35, cl * 0.25, Color("6b4a33"))
		k.box(0, 1.17, -L / 2 + L * 0.33, W * 0.75, 0.45, 0.04, VehicleMesh.GLASS)
		k.person(-W * 0.2, 0.9, cz - cl * 0.2, Color("3d405b"))
		if L > 3.5:
			k.person(W * 0.2, 0.9, cz + cl * 0.25, Color("81b29a"))
	else:
		k.box(0, 0.62, cz, W * 0.86, H - 0.95, cl, col)
		k.box(0, 0.62 + (H - 0.95) * 0.45, cz, W * 0.88, (H - 0.95) * 0.45, cl * 0.82, VehicleMesh.GLASS)
		k.box(0, H - 0.33, cz, W * 0.9, 0.12, cl * 1.02, Color("1b1b1b"))
	# Ailes, marchepieds et roues fines.
	var wz := L / 2 - 0.62
	for s in [-1.0, 1.0]:
		for z in [-wz, wz]:
			k.taper(s * (W / 2 - 0.13), 0.66, 0.8, z - r - 0.15, z + r + 0.15, 0.3, 0.26, 0.15, 0.15, DARK)
		k.box(s * (W / 2 - 0.13), 0.42, 0, 0.3, 0.05, wz * 2 - r * 2, DARK)
	k.axle(W / 2 - 0.13, -wz, r, 0.12)
	k.axle(W / 2 - 0.13, wz, r, 0.12)


static func _truck(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var r := float(t.get("r", 0.5))
	var hood: bool = t.get("cab", "avant") == "capot"
	var cab_h := minf(H, 2.4 + r * 1.6) if hood else minf(H, 3.0 + (r - 0.5))
	var hood_len := clampf(L * 0.12, 0.9, 2.2) if hood else 0.0
	var cab_len := 2.2 if L > 6 else 1.6
	k.box(0, r * 0.9, 0, W * 0.8, 0.3, L * 0.98, DARK)
	var z0 := -L / 2
	if hood:
		k.taper(0, r * 1.1, r * 1.1 + 1.0, z0, z0 + hood_len, W * 0.7, W * 0.66, 0.1, 0.0, col)
		k.box(0, r * 1.1, z0 - 0.02, W * 0.55, 0.85, 0.06, Color("c9ccd1"))
	var cz0 := z0 + hood_len
	k.box(0, r * 1.1, cz0 + cab_len / 2, W, cab_h - r * 1.1, cab_len, col)
	k.box(0, cab_h - 1.0, cz0 - 0.01, W * 0.86, 0.75, 0.08, VehicleMesh.GLASS)
	k.box(0, cab_h - 1.0, cz0 + 0.6, W + 0.04, 0.65, 0.9, VehicleMesh.GLASS)
	_lights(k, L, W, r * 1.3)
	if t.get("stacks", false):
		for s in [-1.0, 1.0]:
			k.cylinder(s * (W / 2 - 0.1), r * 1.5, cz0 + cab_len + 0.2, 0.09, 0.09, cab_h + 0.6 - r * 1.5, 6, Color("d9d9d9"))
	var bz0 := cz0 + cab_len + 0.3
	var bl := L / 2 - bz0
	var bz := bz0 + bl / 2
	var by := r * 2.0 + 0.1
	match String(t.get("cargo", "caisse")):
		"caisse":
			k.box(0, by, bz, W, H - by, bl, col2)
			k.box(0, H - 0.05, bz, W * 1.01, 0.06, bl, col2.darkened(0.08))
		"citerne":
			var tr := (H - by) / 2.0
			k.z_cyl(0, by + tr, bz0, L / 2, tr, tr, 12, col2)
			k.box(0, by + tr * 2, bz, 0.5, 0.1, bl * 0.9, Color("adb5bd"))
		"benne":
			k.box(0, by, bz, W, 0.12, bl, col2)
			for s in [-1.0, 1.0]:
				k.box(s * (W / 2 - 0.06), by, bz, 0.12, 1.2, bl, col2)
			k.box(0, by, bz0 + 0.06, W, 1.4, 0.12, col2)
			k.box(0, by, L / 2 - 0.06, W, 1.2, 0.12, col2)
			k.taper(0, by + 0.1, by + 1.0, bz0 + 0.2, L / 2 - 0.2, W - 0.3, W * 0.5, 0.6, 0.6, Color("a1887f"))
		"grumes":
			k.box(0, by, bz, W, 0.15, bl, DARK)
			for i in 5:
				var lx := (float(i % 3) - 1.0) * 0.7
				var ly := by + 0.5 + (0.75 if i >= 3 else 0.0)
				var ox := 0.35 if i >= 3 else 0.0
				k.z_cyl(lx + ox if i >= 3 else lx, ly, bz0, L / 2 + 0.6, 0.38, 0.34, 8, col2)
			for s in [-1.0, 1.0]:
				k.box(s * (W / 2 - 0.05), by, bz0 + 0.5, 0.1, 1.8, 0.12, DARK)
				k.box(s * (W / 2 - 0.05), by, L / 2 - 0.5, 0.1, 1.8, 0.12, DARK)
		"conteneur":
			k.box(0, by, bz, W, 0.15, bl, DARK)
			k.box(0, by + 0.15, bz, W * 0.98, 2.6, minf(bl, 12.2), col2)
			for i in 10:
				k.box(0, by + 0.15, bz - bl * 0.45 + bl * 0.1 * i, W * 1.0, 2.6, 0.08, col2.darkened(0.12))
		"pompiers":
			k.box(0, by, bz, W, H - by - 0.4, bl, col)
			for i in 4:
				k.box(0, by + 0.5, bz - bl * 0.38 + bl * 0.25 * i, W + 0.04, 1.0, bl * 0.18, Color("adb5bd"))
			for s in [-1.0, 1.0]:
				k.box(s * 0.4, H - 0.4, bz, 0.08, 0.12, bl + 2.5, Color("dee2e6"))
			for i in 12:
				k.box(0, H - 0.38, bz - bl / 2 - 1.0 + (bl + 2.0) * i / 11.0, 0.8, 0.06, 0.05, Color("dee2e6"))
			k.box(0, cab_h, cz0 + 0.5, W * 0.6, 0.15, 0.25, Color("4361ee"))
		"ambulance":
			k.box(0, by - 0.4, bz, W, H - by + 0.4, bl, col2)
			k.box(0, by + 0.6, bz, W + 0.03, 0.25, bl, Color("d00000"))
			k.box(0, H, cz0 + 0.6, W * 0.6, 0.15, 0.25, Color("4361ee"))
		"decore":
			k.box(0, by, bz, W, 1.6, bl, col2)
			for i in 6:
				k.box(0, by + 0.2 + i * 0.22, bz, W + 0.03 + i * 0.002, 0.12, bl * (0.98 - i * 0.02), BRIGHT[i % BRIGHT.size()])
			k.box(0, by + 1.6, bz, W * 0.9, 1.0, bl * 0.9, Color("a98467"))
			k.taper(0, cab_h, cab_h + 0.9, cz0 - 0.4, cz0 + cab_len, W * 0.95, W * 0.6, 0.0, 0.6, BRIGHT[2])
		_:
			k.box(0, by, bz, W, 0.15, bl, col2)
	var fz := cz0 + (0.9 if hood else 1.1)
	if hood:
		fz = z0 + hood_len * 0.5
	k.axle(W / 2 - 0.12, fz, r, 0.35)
	k.axle(W / 2 - 0.12, L / 2 - 1.4, r, 0.4)
	if L > 7.0:
		k.axle(W / 2 - 0.12, L / 2 - 2.5, r, 0.4)
	if L > 13.0:
		k.axle(W / 2 - 0.12, L / 2 - 3.6, r, 0.4)
		k.axle(W / 2 - 0.12, bz0 + 0.4, r, 0.4)


static func _tractor(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	k.box(0, 0.6, -0.4, 0.8, 0.9, L * 0.65, col)
	k.box(0, 0.7, -L / 2 + 0.05, 0.75, 0.75, 0.1, Color("c9ccd1"))
	k.cylinder(0.2, 1.5, -L / 2 + 0.6, 0.06, 0.06, 0.9, 6, DARK)
	k.box(0, 1.0, L * 0.22, 1.1, 0.25, 1.0, DARK)
	k.person(0, 1.25, L * 0.22, Color("457b9d"))
	k.box(0, 2.4, L * 0.22, 1.3, 0.08, 1.3, col2)
	for s in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.6, 1.1, L * 0.22 - 0.6), Vector3(s * 0.6, 2.4, L * 0.22 - 0.6), 0.06, DARK)
		k.rod(Vector3(s * 0.6, 1.1, L * 0.22 + 0.6), Vector3(s * 0.6, 2.4, L * 0.22 + 0.6), 0.06, DARK)
	k.axle(W / 2 - 0.25, L / 2 - 0.85, 0.8, 0.45, VehicleMesh.TIRE)
	k.axle(W / 2 - 0.45, -L / 2 + 0.6, 0.45, 0.25, VehicleMesh.TIRE)
	for s in [-1.0, 1.0]:
		k.wheel(s * (W / 2 - 0.25), L / 2 - 0.85, 0.42, 0.5, col2)
		k.wheel(s * (W / 2 - 0.45), -L / 2 + 0.6, 0.25, 0.3, col2)


static func _bus(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var r := 0.5
	var front: String = t.get("front", "plat")
	var hood_len := 1.6 if front == "capot" else 0.0
	var z0 := -L / 2 + hood_len
	var bl := L / 2 - z0
	var bz := z0 + bl / 2
	var y0 := 0.35
	if t.get("pod", false):
		k.taper(0, y0, H, -L / 2, L / 2, W, W * 0.9, 0.4, 0.4, col)
		k.taper(0, 1.0, H - 0.25, -L / 2 - 0.01, L / 2 + 0.01, W + 0.02, W * 0.92, 0.42, 0.42, VehicleMesh.GLASS)
		k.box(0, 0.6, 0, W + 0.03, 0.2, L * 0.9, col2)
		k.axle(W / 2 - 0.1, -L / 2 + 1.0, 0.4, 0.3)
		k.axle(W / 2 - 0.1, L / 2 - 1.0, 0.4, 0.3)
		return
	if hood_len > 0:
		k.taper(0, y0 + 0.3, y0 + 1.3, -L / 2, z0, W * 0.72, W * 0.68, 0.15, 0.0, col)
		k.box(0, y0 + 0.3, -L / 2 - 0.02, W * 0.55, 0.9, 0.06, Color("c9ccd1"))
	if t.get("coach", false):
		k.taper(0, y0, H, z0, L / 2, W, W, 0.5, 0.1, col)
	else:
		k.box(0, y0, bz, W, H - y0, bl, col)
	var open_sides: bool = t.get("open_sides", false)
	var win_y := 1.25 if not t.get("coach", false) else 1.5
	var double: bool = t.get("double", false)
	if double:
		k.box(0, 1.1, bz + 0.2, W + 0.04, 0.85, bl - 1.0, VehicleMesh.GLASS)
		k.box(0, H * 0.5 + 0.55, bz, W + 0.04, 0.9, bl - 0.6, VehicleMesh.GLASS)
		k.box(0, H * 0.5 + 0.55, z0 - 0.01, W * 0.9, 0.9, 0.08, VehicleMesh.GLASS)
		k.box(0, 0.75, bz, W + 0.03, 0.18, bl, col2)
		k.box(0, H * 0.5 + 0.2, bz, W + 0.03, 0.18, bl, col2)
	else:
		var wh := (H - win_y) * 0.62
		k.box(0, win_y, bz + 0.3, W + (0.04 if not open_sides else 0.06), wh, bl - 1.2, VehicleMesh.GLASS if not open_sides else Color("1b1b1b"))
		k.box(0, 0.75, bz, W + 0.03, 0.22, bl, col2)
	if front != "soufflet":
		k.box(0, 0.95, z0 - 0.01, W * 0.9, (H - 0.95) * 0.62, 0.08, VehicleMesh.GLASS)
		k.box(0, H - 0.4, z0 - 0.02, W * 0.6, 0.28, 0.06, Color("ffb703"))
		_lights(k, L, W, 0.7)
	else:
		k.box(0, y0 + 0.1, -L / 2 - 0.6, W * 0.9, H - y0 - 0.3, 1.2, Color("343a40"))
	k.box(0, H, bz, W * 0.92, 0.1, bl * 0.96, col.lightened(0.12))
	if t.get("deco", false):
		for i in 5:
			k.box(0, 0.45 + i * 0.09, bz, W + 0.035, 0.07, bl * (1.0 - i * 0.04), BRIGHT[(i * 2) % BRIGHT.size()])
		k.box(0, H - 0.25, bz, W + 0.035, 0.2, bl, col2)
	if t.get("rack", false):
		k.box(0, H + 0.1, bz, W * 0.9, 0.08, bl * 0.8, DARK)
		for i in 4:
			k.box(-0.3 + 0.3 * (i % 2), H + 0.18, bz - bl * 0.3 + bl * 0.2 * i, 0.9, 0.5, 1.0, [Color("a98467"), Color("e63946"), Color("ffd166"), Color("2a9d8f")][i])
	if t.get("trolley", false):
		for s in [-1.0, 1.0]:
			k.rod(Vector3(s * 0.35, H + 0.1, L / 2 - 3.0), Vector3(s * 0.35, H + 1.5, L / 2 + 2.5), 0.07, DARK)
	if t.get("platform", false):
		k.box(0, y0, L / 2 - 0.8, W - 0.2, H - y0 - 0.2, 1.4, Color("1b1b1b"))
		k.box(W / 2 - 0.2, y0, L / 2 - 0.8, 0.08, H - y0, 0.08, Color("dee2e6"))
	var fz := (-L / 2 + hood_len * 0.6) if hood_len > 0 else (-L / 2 + 2.4)
	if front == "soufflet":
		fz = -L / 2 + 2.0
	k.axle(W / 2 - 0.1, fz, r, 0.3)
	k.axle(W / 2 - 0.1, L / 2 - 2.6 if L > 8 else L / 2 - 1.4, r, 0.32)


static func _bike(k: VehicleMesh, t: Dictionary, col: Color) -> void:
	var kind: String = t.get("kind", "velo")
	var steel := Color("343a40")
	match kind:
		"grand_bi":
			k.x_cyl(0, 0.75, -0.25, 0.75, 0.05, 12, steel)
			k.x_cyl(0, 0.22, 0.75, 0.22, 0.04, 8, steel)
			k.rod(Vector3(0, 1.5, -0.25), Vector3(0, 0.45, 0.75), 0.06, steel)
			k.person(0, 1.5, -0.05, Color("6b2737"))
		"trottinette":
			k.x_cyl(0, 0.1, -0.45, 0.1, 0.05, 8, VehicleMesh.TIRE)
			k.x_cyl(0, 0.1, 0.45, 0.1, 0.05, 8, VehicleMesh.TIRE)
			k.box(0, 0.12, 0.05, 0.16, 0.05, 0.85, col)
			k.rod(Vector3(0, 0.1, -0.45), Vector3(0, 1.05, -0.4), 0.05, col)
			k.box(0, 1.05, -0.4, 0.5, 0.04, 0.04, steel)
			k.person(0, 0.15, 0.1, Color("457b9d"), false)
		"pousse":
			k.axle(0.5, 0.2, 0.65, 0.06, WOOD)
			k.box(0, 0.65, 0.25, 0.9, 0.12, 0.8, col)
			k.box(0, 0.75, 0.55, 0.9, 0.7, 0.12, col)
			k.taper(0, 1.55, 1.75, -0.05, 0.75, 0.95, 0.85, 0.0, 0.2, Color("1b1b1b"))
			k.person(0, 0.77, 0.25, Color("e9c46a"))
			for s in [-1.0, 1.0]:
				k.rod(Vector3(s * 0.35, 0.7, 0.0), Vector3(s * 0.35, 0.9, -1.4), 0.05, WOOD)
			k.person(0, 0.0, -1.2, Color("f1faee"), false)
		"cyclo":
			k.axle(0.45, -0.75, 0.3, 0.05, steel)
			k.box(0, 0.45, -0.75, 0.85, 0.15, 0.7, col)
			k.box(0, 0.6, -0.45, 0.85, 0.5, 0.1, col)
			k.taper(0, 1.4, 1.55, -1.1, -0.35, 0.9, 0.8, 0.1, 0.1, Color("1b1b1b"))
			k.person(0, 0.6, -0.75, Color("e9c46a"))
			k.x_cyl(0, 0.34, 0.85, 0.34, 0.05, 10, steel)
			k.rod(Vector3(0, 0.45, -0.4), Vector3(0, 0.95, 0.4), 0.06, col)
			k.rod(Vector3(0, 0.95, 0.4), Vector3(0, 0.34, 0.85), 0.05, col)
			k.person(0, 0.95, 0.4, Color("2a9d8f"))
		_:
			var L := float(t.L)
			var wz := L / 2 - 0.36
			k.x_cyl(0, 0.34, -wz, 0.34, 0.05, 10, steel)
			k.x_cyl(0, 0.34, wz, 0.34, 0.05, 10, steel)
			k.rod(Vector3(0, 0.34, wz), Vector3(0, 0.95, 0.1), 0.05, col)
			k.rod(Vector3(0, 0.95, 0.1), Vector3(0, 0.9, -wz + 0.15), 0.05, col)
			k.rod(Vector3(0, 0.9, -wz + 0.15), Vector3(0, 0.34, -wz), 0.05, col)
			k.rod(Vector3(0, 0.34, 0.0), Vector3(0, 0.95, 0.1), 0.05, col)
			k.box(0, 1.1, -wz + 0.15, 0.55, 0.04, 0.05, steel)
			if kind == "cargo":
				k.box(0, 0.45, -wz + 0.25, 0.75, 0.45, 0.8, WOOD)
			k.person(0, 0.95, 0.05, BRIGHT[int(absf(col.h * 10.0)) % BRIGHT.size()])


static func _moto(k: VehicleMesh, t: Dictionary, col: Color) -> void:
	var kind: String = t.get("kind", "moto")
	var L := float(t.L)
	var wz := L / 2 - 0.34
	var r := 0.32 if kind != "scooter" else 0.24
	k.x_cyl(0, r, -wz, r, 0.12, 10, VehicleMesh.TIRE)
	k.x_cyl(0, r, wz, r, 0.14, 10, VehicleMesh.TIRE)
	if kind == "scooter":
		k.taper(0, 0.25, 0.85, -0.1, wz + 0.2, 0.5, 0.45, 0.0, 0.3, col)
		k.taper(0, 0.25, 1.1, -wz, -wz + 0.35, 0.45, 0.4, 0.15, 0.0, col)
		k.box(0, 0.25, -0.25, 0.4, 0.08, 0.5, Color("adb5bd"))
	else:
		k.taper(0, 0.4, 0.75, -0.4, 0.4, 0.3, 0.35, 0.0, 0.0, Color("495057"))
		k.taper(0, 0.75, 1.0, -0.5, 0.0, 0.35, 0.3, 0.05, 0.1, col)
		k.box(0, 0.8, 0.3, 0.3, 0.12, 0.6, Color("1b1b1b"))
		k.rod(Vector3(0, r, -wz), Vector3(0, 1.05, -0.5), 0.07, Color("adb5bd"))
	k.box(0, 1.08, -0.45, 0.65, 0.04, 0.05, Color("343a40"))
	k.box(0, 0.75, -wz - 0.05, 0.14, 0.1, 0.06, VehicleMesh.LIGHT)
	k.person(0, 0.85, 0.15, Color("1d3557"))
	k.ellipsoid(Vector3(0, 1.6, 0.15), 0.16, 0.16, 0.16, 3, 6, col.darkened(0.2))
	if kind == "taxi":
		k.person(0, 0.9, 0.55, Color("e9c46a"))
		k.box(0, 0.6, 0.6, 0.3, 0.1, 0.3, DARK)
	if kind == "side":
		k.taper(0.85, 0.3, 0.85, -0.6, 0.6, 0.6, 0.65, 0.35, 0.1, col)
		k.wheel(1.15, 0.2, 0.28, 0.1)
		k.person(0.85, 0.6, 0.15, Color("6b4a33"))
		k.rod(Vector3(0, 0.45, 0.2), Vector3(0.6, 0.45, 0.2), 0.06, DARK)


static func _tuktuk(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	k.x_cyl(0, 0.25, -L / 2 + 0.3, 0.25, 0.12, 8, VehicleMesh.TIRE)
	k.axle(W / 2 - 0.12, L / 2 - 0.5, 0.25, 0.14)
	k.taper(0, 0.3, 0.95, -L / 2 + 0.05, -L / 2 + 0.75, 0.5, 0.9, 0.0, 0.0, col)
	k.box(0, 0.3, 0.25, W - 0.1, 0.3, L * 0.65, col)
	k.box(0, 0.6, L / 2 - 0.55, W - 0.2, 0.45, 0.6, Color("6b4a33"))
	k.box(0, 0.95, -L / 2 + 0.7, W * 0.7, 0.6, 0.05, VehicleMesh.GLASS)
	k.person(0, 0.6, -0.2, Color("f1faee"))
	k.person(-0.3, 0.95, L / 2 - 0.55, Color("e63946"))
	k.taper(0, 1.75, 1.95, -L / 2 + 0.6, L / 2, W, W * 0.92, 0.0, 0.0, col2)
	for s in [-1.0, 1.0]:
		k.rod(Vector3(s * (W / 2 - 0.08), 0.6, L / 2 - 0.1), Vector3(s * (W / 2 - 0.08), 1.75, L / 2 - 0.1), 0.05, DARK)
		k.rod(Vector3(s * 0.4, 0.95, -L / 2 + 0.7), Vector3(s * (W / 2 - 0.08), 1.75, -L / 2 + 0.7), 0.05, DARK)


static func _cart(k: VehicleMesh, t: Dictionary, col: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var kind: String = t.get("kind", "charrette")
	var horses := int(t.get("horses", 1))
	var r := 0.7
	match kind:
		"charrette":
			k.box(0, 0.8, 0, W, 0.12, L * 0.7, WOOD)
			for s in [-1.0, 1.0]:
				k.box(s * (W / 2 - 0.05), 0.92, 0, 0.08, 0.45, L * 0.7, WOOD.lightened(0.1))
			k.taper(0, 0.92, 1.5, -L * 0.25, L * 0.3, W * 0.9, W * 0.5, 0.3, 0.3, Color("e9c46a"))
			k.axle(W / 2 + 0.05, 0.1, r, 0.08, WOOD.darkened(0.3))
			k.person(0, 0.95, -L * 0.3, Color("6b4a33"))
		"caleche":
			k.box(0, 0.85, 0, W * 0.9, 0.55, L * 0.6, col)
			k.box(0, 1.4, L * 0.15, W * 0.85, 0.15, L * 0.25, Color("6b2737"))
			k.taper(0, 1.4, 1.8, L * 0.2, L * 0.35, W * 0.9, W * 0.85, 0.0, 0.1, Color("1b1b1b"))
			k.person(0, 1.15, -L * 0.3, Color("1b1b1b"))
			k.person(-0.3, 1.2, L * 0.15, Color("e5989b"))
			k.axle(W / 2, -L * 0.25, 0.5, 0.06, Color("c1121f"))
			k.axle(W / 2, L * 0.25, r, 0.06, Color("c1121f"))
		"diligence":
			k.box(0, 1.1, 0.2, W * 0.9, H - 1.5, L * 0.6, col)
			k.box(0, 1.6, 0.2, W * 0.92, 0.55, L * 0.35, VehicleMesh.GLASS)
			k.box(0, H - 0.4, 0.2, W * 0.95, 0.1, L * 0.62, Color("e9c46a"))
			k.box(0, H - 0.3, 0.3, W * 0.8, 0.35, L * 0.4, Color("a98467"))
			k.box(0, 1.6, -L * 0.3, W * 0.9, 0.12, 0.6, WOOD)
			k.person(-0.25, 1.7, -L * 0.3, Color("6b4a33"))
			k.person(0.25, 1.7, -L * 0.3, Color("3d405b"))
			k.axle(W / 2, -L * 0.25, 0.55, 0.08, Color("e9c46a"))
			k.axle(W / 2, L * 0.28, 0.8, 0.08, Color("e9c46a"))
		"bache":
			k.box(0, 0.9, 0.2, W, 0.6, L * 0.75, WOOD)
			k.z_cyl(0, 1.5, -L * 0.18, L * 0.58, W * 0.55, W * 0.55, 10, CANVAS, 1.1)
			k.person(0, 1.5, -L * 0.3, Color("6b4a33"))
			k.axle(W / 2 + 0.05, -L * 0.2, 0.55, 0.08, WOOD.darkened(0.3))
			k.axle(W / 2 + 0.05, L * 0.45, 0.75, 0.08, WOOD.darkened(0.3))
		"omnibus":
			k.box(0, 0.8, 0.2, W, 1.8, L * 0.75, col)
			k.box(0, 1.5, 0.2, W + 0.03, 0.6, L * 0.65, VehicleMesh.GLASS)
			k.box(0, 2.6, 0.2, W, 0.08, L * 0.75, Color("e9c46a"))
			for i in 4:
				k.person(-0.35 + 0.7 * (i % 2), 2.68, -0.6 + 0.9 * (i / 2), [Color("1b1b1b"), Color("6b2737"), Color("3d405b"), Color("e9c46a")][i])
			k.person(0, 1.8, -L * 0.36, Color("1b1b1b"))
			k.axle(W / 2, -L * 0.2, 0.5, 0.08, Color("e9c46a"))
			k.axle(W / 2, L * 0.45, 0.75, 0.08, Color("e9c46a"))
	# Attelage : brancards et chevaux devant.
	var front := -L / 2
	for s in [-1.0, 1.0]:
		k.rod(Vector3(s * 0.45, 0.85, front + 0.4), Vector3(s * 0.45, 1.0, front - 1.8), 0.06, WOOD)
	var rows := maxi(1, horses / 2) if horses > 1 else 1
	for i in rows:
		var hz := front - 1.3 - i * 2.2
		if horses == 1:
			k.horse(0, hz)
		else:
			k.horse(-0.4, hz)
			k.horse(0.4, hz, Color("4a2f1b"))


# --- Rail ------------------------------------------------------------------------------

static func _tram(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var style: String = t.get("style", "moderne")
	k.bogie(-L / 2 + 2.2, 1.435, 0.33)
	k.bogie(L / 2 - 2.2, 1.435, 0.33)
	match style:
		"ancien", "cable":
			var y0 := 0.75
			k.box(0, y0, 0, W, 0.15, L, WOOD.darkened(0.2))
			var body := L * (0.62 if style == "ancien" else 0.5)
			k.box(0, y0, 0, W, H - y0 - 0.5, body, col2)
			k.box(0, y0 + 0.9, 0, W + 0.04, 1.0, body * 0.9, VehicleMesh.GLASS)
			k.box(0, y0, 0, W + 0.02, 0.8, body, col)
			k.box(0, H - 0.5, 0, W + 0.2, 0.15, L, col2.darkened(0.1))
			k.box(0, H - 0.35, 0, W * 0.7, 0.2, body, col2.darkened(0.2))
			for s in [-1.0, 1.0]:
				for e in [-1.0, 1.0]:
					k.box(s * (W / 2 - 0.05), y0, e * (L / 2 - 0.1), 0.06, H - y0 - 0.5, 0.06, Color("c9ccd1"))
			if style == "ancien":
				k.rod(Vector3(0, H - 0.2, L * 0.2), Vector3(0, H + 2.3, -L * 0.25), 0.06, DARK)
				k.person(0, y0 + 0.15, -L / 2 + 0.6, Color("1d3557"), false)
			else:
				for i in 4:
					k.person(W / 2 + 0.15, y0 - 0.3, -L * 0.3 + i * L * 0.2, BRIGHT[i], false)
				k.box(0, y0 + 0.1, L * 0.38, W * 0.6, 0.4, 1.2, WOOD)
		"rond":
			k.box(0, 0.8, 0, W, H - 0.8, L - 3.0, col)
			k.z_cyl(0, 0.8 + (H - 0.8) / 2, -L / 2, -L / 2 + 1.5, W * 0.38, W / 2, 8, col, 1.15)
			k.z_cyl(0, 0.8 + (H - 0.8) / 2, L / 2 - 1.5, L / 2, W / 2, W * 0.38, 8, col, 1.15)
			k.box(0, 1.7, 0, W + 0.04, 0.95, L - 3.4, VehicleMesh.GLASS)
			k.box(0, 0.8, 0, W + 0.03, 0.6, L - 3.0, col2)
			k.rod(Vector3(0, H, L * 0.25), Vector3(0, H + 2.0, -L * 0.15), 0.06, DARK)
		"etage":
			k.box(0, 0.6, 0, W, H - 0.6, L, col)
			k.box(0, 1.4, 0, W + 0.04, 0.9, L - 1.0, VehicleMesh.GLASS)
			k.box(0, 2.9, 0, W + 0.04, 0.9, L - 1.0, VehicleMesh.GLASS)
			k.box(0, 2.45, 0, W + 0.03, 0.25, L, col2)
			k.box(0, H, 0, W * 0.9, 0.1, L, col.lightened(0.1))
			k.rod(Vector3(0, H, L * 0.2), Vector3(0, H + 1.5, -L * 0.2), 0.06, DARK)
		_:
			var y0 := 0.3
			var nose_len := 1.2 if style != "module" else 0.0
			var bz0 := -L / 2 + nose_len
			k.box(0, y0, (bz0 + L / 2) / 2, W, H - y0, L / 2 - bz0, col)
			if nose_len > 0:
				k.nose(0, y0, -L / 2, bz0, W, H - y0, W * 0.85, H - y0 - 0.6, 0.2, col)
				k.nose(0, 1.2, -L / 2 - 0.02, bz0 - 0.1, W * 0.86, H - 1.5, W * 0.72, H - 1.9, 0.15, VehicleMesh.GLASS)
				_lights(k, L, W * 0.9, 0.8)
				k.pantograph(H, -L * 0.1)
			k.box(0, 1.05, (bz0 + L / 2) / 2, W + 0.04, H - 1.6, L / 2 - bz0 - 0.4, VehicleMesh.GLASS)
			k.box(0, y0, (bz0 + L / 2) / 2, W + 0.03, 0.55, L / 2 - bz0, col2)
			for i in 2:
				k.box(0, y0 + 0.1, -L * 0.2 + i * L * 0.45, W + 0.05, H - y0 - 0.9, 1.3, col2.darkened(0.2))
			k.box(0, H, 0, W * 0.6, 0.35, L * 0.4, Color("adb5bd"))


static func _steam(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var style: String = t.get("style", "pacific")
	var cab_len := 2.0 if style != "debuts" else 1.2
	var br := 0.75 if style != "debuts" else 0.55
	var by := 1.9 if style != "debuts" else 1.6
	if style == "pacific":
		br = 0.9
		by = 2.4
	k.box(0, 0.75, 0, W * 0.55, 0.35, L * 0.98, DARK)
	k.box(0, 0.65, -L / 2 + 0.1, W, 0.45, 0.2, col2)
	var bz1 := L / 2 - cab_len
	k.z_cyl(0, by, -L / 2 + 0.6, bz1, br, br, 12, col)
	k.z_cyl(0, by, -L / 2 + 0.3, -L / 2 + 1.3, br * 1.03, br * 1.03, 12, DARK)
	var ctop := H
	if style == "americaine":
		k.cylinder(0, by + br * 0.8, -L / 2 + 0.9, 0.22, 0.65, ctop - (by + br * 0.8), 8, DARK)
		k.nose(0, 0.08, -L / 2 - 1.3, -L / 2 + 0.05, W * 0.85, 0.75, 0.15, 0.1, 0.05, col2)
		k.box(0, by + br * 0.9, -L / 2 + 0.45, 0.5, 0.55, 0.5, Color("e9c46a"))
	else:
		k.cylinder(0, by + br * 0.8, -L / 2 + 0.9, 0.24, 0.3 if style == "debuts" else 0.26, ctop - (by + br * 0.8), 8, DARK)
		k.box(0, by + br * 0.75, -L / 2 + 0.5, 0.3, 0.3, 0.2, VehicleMesh.LIGHT)
	k.cylinder(0, by + br * 0.8, (-L / 2 + bz1) / 2 + 0.6, 0.35, 0.3, 0.45, 8, Color("d4a373"))
	if style == "pacific":
		for s in [-1.0, 1.0]:
			k.box(s * (br + 0.15), by - br * 0.6, -L / 2 + 1.2, 0.06, br * 2.0, 1.6, DARK)
	k.box(0, 1.0, L / 2 - cab_len / 2, W * 0.95, H - 1.4 - 1.0, cab_len, col)
	k.box(0, H - 1.4 - 0.9, L / 2 - cab_len / 2, W * 0.97, 0.7, cab_len * 0.5, VehicleMesh.GLASS)
	k.box(0, H - 1.45, L / 2 - cab_len / 2, W, 0.1, cab_len + 0.3, DARK)
	# Roues motrices.
	var n := 1 if style == "debuts" else (2 if style == "americaine" else 3)
	var rd := 0.9 if style != "pacific" else 1.0
	if style == "debuts":
		rd = 1.1
	var zs := bz1 - rd - 0.2
	for i in n:
		var z := zs - i * (rd * 2 + 0.15)
		k.axle(0.85, z, rd, 0.14, col2 if style != "pacific" else Color("c1121f"))
	k.axle(0.75, -L / 2 + 0.9, 0.45, 0.12, DARK)
	if style == "pacific":
		k.axle(0.75, -L / 2 + 1.9, 0.45, 0.12, DARK)
		k.axle(0.75, L / 2 - 0.6, 0.55, 0.12, DARK)
	for s in [-1.0, 1.0]:
		k.box(s * 0.95, rd, zs - (n - 1) * (rd + 0.07), 0.06, 0.12, maxf(0.5, (n - 1) * (rd * 2 + 0.15) + 0.4), Color("adb5bd"))


static func _diesel(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	k.bogie(-L / 2 + 3.0)
	k.bogie(L / 2 - 3.0)
	k.box(0, 1.0, 0, W, 0.4, L, DARK)
	if t.get("style", "capot") == "capot":
		var cab_z := -L / 2 + 3.2
		k.box(0, 1.4, -L / 2 + 1.0, W * 0.65, 1.4, 2.0, col)
		k.box(0, 1.4, cab_z, W, H - 1.4, 2.4, col)
		k.box(0, H - 1.2, cab_z - 1.21, W * 0.8, 0.7, 0.06, VehicleMesh.GLASS)
		k.box(0, H - 1.2, cab_z, W + 0.04, 0.6, 1.4, VehicleMesh.GLASS)
		k.box(0, 1.4, (cab_z + 1.2 + L / 2) / 2, W * 0.7, H - 1.6, L / 2 - cab_z - 1.4, col)
		k.box(0, 1.6, 0, W + 0.02, 0.35, L, col2)
		k.box(0, 1.4, -L / 2 + 0.02, 0.5, 0.25, 0.05, VehicleMesh.LIGHT)
		for i in 3:
			k.box(0, H - 0.2, L * 0.1 + i * 2.0, 0.9, 0.2, 0.9, Color("495057"))
	else:
		k.box(0, 1.4, 0, W, H - 1.4, L - 1.2, col)
		for e in [-1.0, 1.0]:
			k.nose(0, 1.4, e * (L / 2), e * (L / 2 - 0.6), W, H - 1.4, W * 0.9, H - 1.8, 0.0, col)
		k.box(0, H - 1.3, -L / 2 + 0.3, W * 0.8, 0.75, 0.6, VehicleMesh.GLASS)
		k.box(0, H - 1.3, L / 2 - 0.3, W * 0.8, 0.75, 0.6, VehicleMesh.GLASS)
		k.box(0, 1.6, 0, W + 0.03, 0.5, L - 1.2, col2)
		_lights(k, L, W, 1.8)


static func _electric(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	k.bogie(-L / 2 + 3.0)
	k.bogie(L / 2 - 3.0)
	k.box(0, 1.0, 0, W, 0.4, L, DARK)
	k.box(0, 1.4, 0, W, H - 1.4 - 0.4, L - 1.4, col)
	for e in [-1.0, 1.0]:
		k.nose(0, 1.4, e * (L / 2), e * (L / 2 - 0.7), W, H - 1.8, W * 0.85, H - 2.4, 0.1, col)
	k.box(0, H - 1.6, -L / 2 + 0.35, W * 0.8, 0.8, 0.7, VehicleMesh.GLASS)
	k.box(0, H - 1.6, L / 2 - 0.35, W * 0.8, 0.8, 0.7, VehicleMesh.GLASS)
	k.box(0, 1.7, 0, W + 0.03, 0.3, L - 1.4, col2)
	k.box(0, 2.6, 0, W + 0.02, 0.5, L * 0.5, Color("adb5bd"))
	k.box(0, H - 0.4, 0, W * 0.7, 0.2, L * 0.6, Color("6c757d"))
	k.pantograph(H - 0.2, -L * 0.28)
	k.pantograph(H - 0.2, L * 0.28)
	_lights(k, L, W, 1.9)


static func _emu(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var style: String = t.get("style", "nez")
	var y0 := 1.0 if not style.begins_with("metro") else 0.8
	k.bogie(-L / 2 + 2.6)
	k.bogie(L / 2 - 2.6)
	var cab_front := style in ["nez", "autorail", "metro"]
	var cab_back := style in ["queue", "autorail"]
	var nf := 2.0 if style == "nez" else 0.0
	var nb := 2.0 if style == "queue" else 0.0
	var z0 := -L / 2 + nf
	var z1 := L / 2 - nb
	k.box(0, y0, (z0 + z1) / 2, W, H - y0, z1 - z0, col)
	if nf > 0:
		k.nose(0, y0, -L / 2, z0, W, H - y0, W * 0.8, H - y0 - 1.0, 0.3, col)
		k.nose(0, y0 + 1.3, -L / 2 - 0.01, z0 - 0.3, W * 0.85, H - y0 - 1.6, W * 0.65, H - y0 - 2.2, 0.0, VehicleMesh.GLASS)
	if nb > 0:
		k.nose(0, y0, L / 2, z1, W, H - y0, W * 0.8, H - y0 - 1.0, 0.3, col)
		k.nose(0, y0 + 1.3, L / 2 + 0.01, z1 + 0.3, W * 0.85, H - y0 - 1.6, W * 0.65, H - y0 - 2.2, 0.0, VehicleMesh.GLASS)
	if style in ["autorail", "metro"]:
		k.box(0, H - 1.6, -L / 2 - 0.01, W * 0.8, 0.9, 0.06, VehicleMesh.GLASS)
	if cab_back and nb == 0:
		k.box(0, H - 1.6, L / 2 + 0.01, W * 0.8, 0.9, 0.06, VehicleMesh.GLASS)
	k.box(0, y0 + 0.9, (z0 + z1) / 2, W + 0.04, 1.0, (z1 - z0) - 1.0, VehicleMesh.GLASS)
	k.box(0, y0 + 0.2, (z0 + z1) / 2, W + 0.03, 0.4, z1 - z0, col2)
	var doors := 4 if style.begins_with("metro") else 2
	for i in doors:
		var dz := z0 + (z1 - z0) * (i + 0.5) / doors
		k.box(0, y0 + 0.05, dz, W + 0.05, H - y0 - 0.7, 1.3, col2.darkened(0.15))
	if style == "autorail":
		k.box(0, H, 0, W * 0.5, 0.3, L * 0.3, DARK)
	elif not style.begins_with("metro") and style != "milieu":
		k.pantograph(H, 0)
	if cab_front:
		_lights(k, L, W, y0 + 0.6)


static func _high_speed(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var nose_len := float(t.get("nose", 5.0))
	var maglev: bool = t.get("maglev", false)
	var y0 := 0.9 if not maglev else 0.5
	if maglev:
		k.box(0, 0.1, 0, W * 0.7, 0.5, L * 0.95, Color("495057"))
	else:
		k.bogie(-L / 2 + nose_len + 1.0)
		k.bogie(L / 2 - 2.0)
	var z0 := -L / 2 + nose_len
	k.box(0, y0, (z0 + L / 2) / 2, W, H - y0, L / 2 - z0, col)
	k.nose(0, y0, -L / 2, z0, W, H - y0, 0.9, 0.35, 0.25, col)
	k.nose(0, y0 + (H - y0) * 0.45, -L / 2 + nose_len * 0.45, z0 - nose_len * 0.05, W * 0.45, (H - y0) * 0.45, W * 0.3, 0.2, 0.0, VehicleMesh.GLASS)
	k.box(0, y0 + 0.2, (z0 + L / 2) / 2, W + 0.03, 0.45, L / 2 - z0, col2)
	k.nose(0, y0 + 0.2, -L / 2 + 0.2, z0, W + 0.03, 0.45, 0.6, 0.1, 0.2, col2)
	if t.get("places", 0) > 0:
		k.box(0, y0 + 1.1, (z0 + L / 2) / 2 + 0.5, W + 0.04, 0.7, L / 2 - z0 - 1.5, VehicleMesh.GLASS)
	if not maglev:
		k.pantograph(H, L / 2 - 4.0)


static func _coach(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var style: String = t.get("style", "bandeau")
	var y0 := 1.0
	match style:
		"debuts":
			k.box(0, 0.75, 0, W * 0.9, 0.2, L, DARK)
			k.axle(0.75, -L / 2 + 1.2, 0.5, 0.12, DARK)
			k.axle(0.75, L / 2 - 1.2, 0.5, 0.12, DARK)
			for i in 3:
				var z := -L / 3 + i * L / 3
				k.box(0, 0.95, z, W, 1.4, L / 3 - 0.2, col)
				k.box(0, 1.55, z, W + 0.03, 0.55, L / 3 - 0.8, VehicleMesh.GLASS)
				k.box(0, 0.95, z, W + 0.02, 0.15, L / 3 - 0.2, col2)
			k.box(0, 2.35, 0, W * 1.02, 0.12, L, Color("1b1b1b"))
			k.box(0, 2.47, 0, W * 0.8, 0.4, L * 0.8, Color("a98467"))
			return
		"maglev":
			y0 = 0.5
			k.box(0, 0.1, 0, W * 0.7, 0.5, L, Color("495057"))
		_:
			k.bogie(-L / 2 + 2.5)
			k.bogie(L / 2 - 2.5)
	k.box(0, y0, 0, W, H - y0 - 0.3, L - 0.3, col)
	match style:
		"lanterneau":
			k.box(0, H - 0.3, 0, W + 0.15, 0.1, L, Color("3d2b1f"))
			k.box(0, H - 0.2, 0, W * 0.5, 0.35, L * 0.9, col.darkened(0.15))
			k.box(0, H - 0.18, 0, W * 0.52, 0.2, L * 0.85, VehicleMesh.GLASS)
			k.windows_col(-W / 2 - 0.01, 0, L - 2.0, y0 + 0.9, 10, 0.6, 0.9, VehicleMesh.GLASS)
			k.windows_col(W / 2 + 0.01, 0, L - 2.0, y0 + 0.9, 10, 0.6, 0.9, VehicleMesh.GLASS)
			k.box(0, y0, -L / 2, W * 0.9, H - y0 - 0.3, 0.6, col2)
		"fenetres":
			k.taper(0, H - 0.3, H, -L / 2 + 0.15, L / 2 - 0.15, W, W * 0.7, 0.0, 0.0, Color("495057"))
			k.windows_col(-W / 2 - 0.01, 0, L - 2.0, y0 + 1.0, 10, 1.1, 0.9, VehicleMesh.GLASS)
			k.windows_col(W / 2 + 0.01, 0, L - 2.0, y0 + 1.0, 10, 1.1, 0.9, VehicleMesh.GLASS)
			k.box(0, y0 + 2.05, 0, W + 0.03, 0.12, L - 0.3, col2)
			k.box(0, y0 + 0.75, 0, W + 0.03, 0.08, L - 0.3, col2)
		_:
			k.taper(0, H - 0.3, H, -L / 2 + 0.15, L / 2 - 0.15, W, W * 0.8, 0.0, 0.0, col.darkened(0.08))
			k.box(0, y0 + 0.95, 0, W + 0.04, 0.85, L - 2.4, VehicleMesh.GLASS)
			k.box(0, y0 + 0.3, 0, W + 0.03, 0.4, L - 0.3, col2)
			if style == "gv":
				k.box(0, y0 + 2.0, 0, W + 0.04, 0.4, L - 2.4, VehicleMesh.GLASS)


static func _freight(k: VehicleMesh, t: Dictionary, col: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var kind: String = t.get("kind", "couvert")
	k.bogie(-L / 2 + 2.0)
	k.bogie(L / 2 - 2.0)
	k.box(0, 0.9, 0, W * 0.95, 0.3, L, DARK)
	var y0 := 1.2
	match kind:
		"tender":
			k.box(0, y0, 0, W, H - y0 - 0.4, L, col)
			k.taper(0, H - 0.4, H, -L / 2 + 0.3, 0.5, W - 0.3, W * 0.6, 0.6, 0.6, Color("111111"))
			k.cylinder(0, H - 0.4, L / 2 - 1.2, 0.35, 0.35, 0.3, 8, Color("495057"))
		"couvert":
			k.box(0, y0, 0, W, H - y0 - 0.3, L, col)
			k.gable(0, H - 0.3, 0, W + 0.1, L + 0.1, 0.3, col.darkened(0.2), false)
			k.box(0, y0 + 0.1, 0, W + 0.04, H - y0 - 0.6, 2.4, col.lightened(0.1))
		"citerne":
			var r := (H - y0) / 2.0
			k.z_cyl(0, y0 + r, -L / 2 + 0.4, L / 2 - 0.4, r, r, 12, col)
			k.cylinder(0, y0 + r * 2 - 0.1, 0, 0.45, 0.4, 0.4, 8, col.lightened(0.1))
		"conteneurs":
			for i in 2:
				k.box(0, y0, -L / 4 + i * L / 2, W * 0.96, 2.6, 6.0, CONTAINERS[(i * 3 + int(L)) % CONTAINERS.size()])
				for j in 6:
					k.box(0, y0, -L / 4 + i * L / 2 - 2.5 + j * 1.0, W * 0.98, 2.6, 0.06, Color(0, 0, 0, 1).lerp(CONTAINERS[(i * 3 + int(L)) % CONTAINERS.size()], 0.7))
		"tremie":
			k.taper(0, y0 - 0.2, H, -L / 2 + 1.2, L / 2 - 1.2, W * 0.6, W, -1.0, -1.0, col)
			k.box(0, H - 0.05, 0, W * 0.6, 0.1, L - 2.0, col.darkened(0.2))
		"grumes":
			for i in 5:
				var x := (float(i % 3) - 1.0) * 0.8 + (0.4 if i >= 3 else 0.0)
				k.z_cyl(x, y0 + 0.45 + (0.8 if i >= 3 else 0.0), -L / 2 + 0.3, L / 2 - 0.3, 0.42, 0.4, 8, WOOD)
			for z in [-L / 2 + 0.6, 0.0, L / 2 - 0.6]:
				for s in [-1.0, 1.0]:
					k.box(s * (W / 2 - 0.08), y0, z, 0.12, 2.0, 0.15, DARK)


# --- Eau -------------------------------------------------------------------------------

## Coque : ligne de flottaison en y = 0, franc-bord fb, tirant d'eau dr, étrave pointue devant.
static func _hull(k: VehicleMesh, L: float, W: float, fb: float, dr: float, bow: float, col: Color,
		deck := Color(0, 0, 0, 0), rise := 0.0, stern_rise := 0.0) -> void:
	var z0 := -L / 2 + bow
	var z1 := L / 2
	var b := [Vector3(-W * 0.32, -dr, z0), Vector3(W * 0.32, -dr, z0), Vector3(W * 0.3, -dr, z1 - L * 0.04), Vector3(-W * 0.3, -dr, z1 - L * 0.04)]
	var t := [Vector3(-W / 2, fb, z0), Vector3(W / 2, fb, z0), Vector3(W * 0.45, fb + stern_rise, z1), Vector3(-W * 0.45, fb + stern_rise, z1)]
	k.hull(b, t, col)
	var bb := [Vector3(-0.02, -dr * 0.5, -L / 2 + bow * 0.15), Vector3(0.02, -dr * 0.5, -L / 2 + bow * 0.15), Vector3(W * 0.32, -dr, z0), Vector3(-W * 0.32, -dr, z0)]
	var bt := [Vector3(-0.02, fb + rise, -L / 2), Vector3(0.02, fb + rise, -L / 2), Vector3(W / 2, fb, z0), Vector3(-W / 2, fb, z0)]
	k.hull(bb, bt, col)
	if deck.a > 0.0:
		k.box(0, fb - 0.02, (z0 + z1) / 2 + 0.1, W * 0.86, 0.05, (z1 - z0) * 0.94, deck)
	k.box(0, -0.02, 0, W * 0.66, 0.06, L * 0.8, col.darkened(0.35))


static func _boat(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	var deck := Color("c8a27a")
	match String(t.get("kind", "barque")):
		"pirogue":
			_hull(k, L, W, 0.35, 0.25, L * 0.3, col, Color(0, 0, 0, 0), 0.15, 0.1)
			for i in 3:
				k.person(0, 0.05, -L * 0.25 + i * L * 0.25, BRIGHT[i])
		"balancier":
			_hull(k, L, 0.8, 0.4, 0.3, L * 0.3, col, Color(0, 0, 0, 0), 0.3, 0.2)
			k.z_cyl(-W + 0.6, 0.05, -L * 0.25, L * 0.25, 0.15, 0.15, 6, col)
			for z in [-L * 0.15, L * 0.15]:
				k.rod(Vector3(0, 0.4, z), Vector3(-W + 0.6, 0.15, z), 0.08, WOOD)
			k.cylinder(0, 0.4, -0.5, 0.06, 0.05, H - 0.4, 5, WOOD)
			k.sail_tri(0, Vector3(0, 0.8, -L * 0.35), Vector3(0, H, -0.5), Vector3(0, 1.0, L * 0.2), col2)
		"barque":
			_hull(k, L, W, 0.4, 0.25, 1.0, col, deck, 0.1)
			k.person(0, 0.1, 0.2, Color("e9c46a"))
			for s in [-1.0, 1.0]:
				k.rod(Vector3(s * 0.3, 0.6, 0.2), Vector3(s * 1.8, -0.05, 0.5), 0.05, WOOD)
		"gondole":
			_hull(k, L, W, 0.4, 0.25, 3.0, col, Color(0, 0, 0, 0), 1.0, 0.8)
			k.box(0, 0.4, 0.5, 1.0, 0.4, 1.4, Color("6b2737"))
			k.box(0, 1.35, -L / 2 + 0.2, 0.1, 0.4, 0.6, Color("c9ccd1"))
			k.person(0, 1.2, L / 2 - 1.0, Color("f1faee"), false)
			k.box(0, 1.25, L / 2 - 1.0, 0.44, 0.2, 0.3, Color("c1121f"))
			k.rod(Vector3(0.3, 2.0, L / 2 - 1.0), Vector3(0.6, -0.3, L / 2 + 0.5), 0.05, WOOD)
		"drakkar":
			_hull(k, L, W, 1.0, 0.6, 4.0, col, deck, 2.5, 2.0)
			k.ellipsoid(Vector3(0, 3.7, -L / 2 + 0.1), 0.3, 0.4, 0.6, 3, 6, col2.darkened(0.2))
			for s in [-1.0, 1.0]:
				for i in 9:
					k.cylinder(s * (W / 2 - 0.05), 0.5, -L * 0.3 + i * L * 0.075, 0.38, 0.38, 0.05, 8, BRIGHT[(i + int(s)) % BRIGHT.size()])
			k.cylinder(0, 1.0, 0, 0.14, 0.12, H - 1.0, 6, WOOD)
			k.box(0, H - 0.4, 0, 8.0, 0.15, 0.2, WOOD)
			k.box(0, 3.0, 0.15, 8.0, H - 3.4, 0.08, col2)
			for i in 3:
				k.box(0, 3.0, 0.2, 8.0 - i * 0.1, 0.5, 0.09, Color("f1faee") if i % 2 == 0 else col2)
		"jonque":
			_hull(k, L, W, 2.0, 1.2, 5.0, col, deck, 1.5, 4.0)
			k.box(0, 2.0, L / 2 - 3.5, W * 0.8, 2.5, 6.0, col.darkened(0.1))
			for m in [[-L * 0.25, H * 0.65], [0.0, H], [L * 0.3, H * 0.6]]:
				var mz: float = m[0]
				var mh: float = m[1]
				k.cylinder(0, 2.0, mz, 0.2, 0.15, mh - 2.0, 6, WOOD)
				k.box(0, 3.0, mz + 0.4, 0.08, mh - 3.5, (mh - 3.0) * 0.55, col2)
				for i in 5:
					k.box(0, 3.0 + i * (mh - 3.5) / 4.0, mz + 0.4, 0.12, 0.08, (mh - 3.0) * 0.56, WOOD.darkened(0.2))
		"sampan":
			_hull(k, L, W, 0.5, 0.3, 1.5, col, deck, 0.3, 0.3)
			k.z_cyl(0, 0.5, -0.8, 1.2, W * 0.45, W * 0.45, 8, col2, 0.9)
			k.person(0, 0.5, L / 2 - 0.5, Color("2b2d42"), false)
		"latine":
			_hull(k, L, W, 0.9, 0.6, L * 0.25, col, deck, 0.6, 0.5)
			k.cylinder(0, 0.9, -L * 0.15, 0.12, 0.08, H * 0.6, 6, WOOD)
			k.rod(Vector3(0, 1.5, -L * 0.48), Vector3(0, H, L * 0.3), 0.1, WOOD)
			k.sail_tri(0, Vector3(0, 1.5, -L * 0.46), Vector3(0, H * 0.98, L * 0.28), Vector3(0, 1.4, L * 0.25), col2)
		"caravelle":
			_hull(k, L, W, 2.5, 1.5, 5.0, col, deck, 1.5, 3.0)
			k.box(0, 2.5, L / 2 - 3.0, W * 0.85, 2.5, 6.0, col.darkened(0.1))
			k.box(0, 2.5, -L / 2 + 5.5, W * 0.6, 1.2, 3.0, col.darkened(0.1))
			for m in [[-L * 0.2, H * 0.8, true], [L * 0.05, H, true], [L * 0.32, H * 0.65, false]]:
				var mz: float = m[0]
				var mh: float = m[1]
				k.cylinder(0, 2.5, mz, 0.25, 0.18, mh - 2.5, 6, WOOD)
				if m[2]:
					k.sail_square(mz, mh * 0.45, mh * 0.85, W * 1.1, col2, 0.6)
					k.box(0, mh * 0.48, mz + 0.65, 1.6, 1.6, 0.05, Color("c1121f"))
				else:
					k.sail_tri(0, Vector3(0, 4.0, mz - 2.0), Vector3(0, mh, mz), Vector3(0, 3.5, mz + 4.0), col2)
		"aubes":
			_hull(k, L, W, 1.2, 0.8, 6.0, col, deck, 0.4)
			k.box(0, 1.2, 0, W * 0.95, 2.6, L * 0.75, col)
			k.box(0, 1.9, 0, W + 0.03, 1.0, L * 0.7, VehicleMesh.GLASS)
			k.box(0, 3.8, 0, W * 1.05, 0.2, L * 0.78, col2)
			k.box(0, 4.0, -L * 0.05, W * 0.7, 2.2, L * 0.45, col)
			k.box(0, 6.2, -L * 0.15, 3.0, 2.0, 3.0, col)
			for s in [-1.0, 1.0]:
				k.cylinder(s * 1.4, 6.2, -L * 0.28, 0.5, 0.55, H - 6.2, 8, Color("111111"))
			k.x_cyl(0, 2.0, L / 2 + 1.5, 3.0, W * 0.7, 10, col2)
			k.x_cyl(0, 2.0, L / 2 + 1.5, 2.4, W * 0.72, 10, Color("6b2737"))
		"peniche":
			_hull(k, L, W, 1.2, 1.4, 3.0, col, Color(0, 0, 0, 0), 0.4)
			k.box(0, 1.2, -L * 0.05, W * 0.9, 0.7, L * 0.7, col2.darkened(0.2))
			k.box(0, 1.2, L / 2 - 3.5, W * 0.8, 2.3, 4.5, Color("f1faee"))
			k.box(0, 2.3, L / 2 - 3.5, W * 0.82, 0.7, 3.8, VehicleMesh.GLASS)
			k.box(0, 3.5, L / 2 - 3.5, W * 0.85, 0.12, 4.7, col)
			for i in 4:
				k.box(-1.2 + i * 0.8, 3.62, L / 2 - 3.5, 0.5, 0.3, 0.5, BRIGHT[i])
		"bus":
			_hull(k, L, W, 0.8, 0.6, 3.0, col, deck, 0.3)
			k.box(0, 0.8, 0.5, W * 0.9, 2.0, L * 0.72, col)
			k.box(0, 1.4, 0.5, W * 0.92, 1.1, L * 0.68, VehicleMesh.GLASS)
			k.box(0, 2.8, 0.5, W * 0.95, 0.15, L * 0.76, col2)
			k.box(0, 0.8, 0.5, W * 0.92, 0.4, L * 0.72, col2)
		"remorqueur":
			_hull(k, L, W, 2.0, 2.0, 6.0, Color("1b1b1b"), Color("6c757d"), 0.8)
			k.box(0, 1.8, 0, W + 0.4, 0.5, L * 0.9, Color("343a40"))
			k.box(0, 2.0, -L * 0.12, W * 0.7, 2.6, L * 0.35, col2)
			k.box(0, 4.6, -L * 0.18, W * 0.6, 1.8, L * 0.2, col2)
			k.box(0, 5.4, -L * 0.18, W * 0.62, 0.8, L * 0.21, VehicleMesh.GLASS)
			k.cylinder(0, 4.6, L * 0.08, 0.8, 0.8, 3.4, 8, col)
			k.cylinder(0, 6.4, -L * 0.18, 0.08, 0.06, H - 6.4, 4, DARK)
		"hors_bord":
			_hull(k, L, W, 0.6, 0.3, 2.0, col, Color(0, 0, 0, 0), 0.2)
			k.box(0, 0.6, -0.3, W * 0.85, 0.3, 1.0, col2)
			k.taper(0, 0.9, 1.4, -0.9, -0.5, W * 0.8, W * 0.7, 0.3, 0.0, VehicleMesh.GLASS)
			k.box(0, 0.5, L / 2 + 0.2, 0.5, 0.9, 0.4, Color("1b1b1b"))
			k.person(-0.3, 0.6, 0.2, Color("e63946"))
		"voilier":
			_hull(k, L, W, 1.2, 1.8, 3.5, col, deck, 0.3)
			k.box(0, 1.2, 0.8, W * 0.55, 0.6, L * 0.35, col)
			k.box(0, 1.5, 0.8, W * 0.57, 0.25, L * 0.3, VehicleMesh.GLASS)
			k.cylinder(0, 1.2, -L * 0.1, 0.1, 0.08, H - 1.2, 6, Color("adb5bd"))
			k.sail_tri(0, Vector3(0, 1.8, -L * 0.1 + 0.05), Vector3(0, H * 0.97, -L * 0.1 + 0.05), Vector3(0, 1.9, L * 0.35), col2)
			k.sail_tri(0, Vector3(0, 1.4, -L / 2 + 0.3), Vector3(0, H * 0.85, -L * 0.1 - 0.05), Vector3(0, 1.6, -L * 0.12), col2.darkened(0.05))
			k.box(0, -1.8, 0.3, 0.2, 1.4, 1.2, DARK)
		"ferry":
			_hull(k, L, W, 7.0, 5.0, 18.0, col, Color("6c757d"), 1.0)
			k.box(0, 0.0, 0, W + 0.1, 3.0, L * 0.9, col2)
			k.box(0, 7.0, 4.0, W * 0.9, 12.0, L * 0.65, col)
			k.window_bands(0, 4.0, W * 0.9, L * 0.65, 7.0, 4, 3.0, VehicleMesh.GLASS)
			k.box(0, 19.0, -L * 0.2, W * 0.85, 3.0, 12.0, col)
			k.box(0, 20.0, -L * 0.2, W * 0.87, 1.4, 11.0, VehicleMesh.GLASS)
			k.taper(0, 19.0, H, L * 0.15, L * 0.25, 4.0, 3.0, 2.0, 0.0, col2)
		"cargo":
			_hull(k, L, W, 12.0, 12.0, 25.0, col, Color("7f1d1d"), 2.0)
			k.box(0, -2.0, 0, W + 0.1, 3.0, L * 0.9, Color("c1121f"))
			k.box(0, 12.0, L / 2 - 16.0, W * 0.9, 18.0, 14.0, Color("f8f9fa"))
			k.box(0, 27.0, L / 2 - 16.0, W * 1.05, 2.5, 8.0, VehicleMesh.GLASS)
			k.box(0, 30.0, L / 2 - 10.0, 5.0, 8.0, 5.0, Color("343a40"))
			var rows := 9
			for i in rows:
				var bz := -L / 2 + 30.0 + i * (L - 52.0) / rows
				for j in 3:
					var h := 2.6 * (3 + (i * 7 + j * 3) % 4)
					k.box((j - 1) * W * 0.3, 12.0, bz, W * 0.29, h, (L - 56.0) / rows, CONTAINERS[(i * 3 + j) % CONTAINERS.size()])
		"paquebot":
			_hull(k, L, W, 18.0, 10.0, 30.0, col, Color("c8a27a"), 3.0)
			k.box(0, -1.0, 0, W + 0.1, 3.0, L * 0.9, Color("7f1d1d"))
			k.box(0, 14.0, 0, W + 0.05, 4.0, L * 0.85, Color("f8f9fa"))
			k.box(0, 18.0, 10.0, W * 0.85, 9.0, L * 0.6, Color("f8f9fa"))
			k.window_bands(0, 10.0, W * 0.85, L * 0.6, 18.0, 3, 3.0, Color("1b1b1b"))
			for i in 4:
				var fz := -L * 0.22 + i * L * 0.16
				k.cylinder(0, 27.0, fz, 3.2, 3.0, 18.0, 10, col2)
				k.cylinder(0, 42.0, fz, 3.05, 3.05, 3.0, 10, Color("111111"))
			for z in [-L * 0.4, L * 0.4]:
				k.cylinder(0, 18.0, z, 0.4, 0.3, H - 18.0, 4, WOOD)
		"croisiere":
			_hull(k, L, W, 14.0, 9.0, 35.0, col, Color("6c757d"), 2.0)
			k.box(0, -1.0, 0, W + 0.1, 2.0, L * 0.9, col2)
			k.box(0, 14.0, 10.0, W * 0.98, 30.0, L * 0.72, col)
			k.window_bands(0, 10.0, W * 0.98, L * 0.72, 14.0, 10, 3.0, VehicleMesh.GLASS)
			k.box(0, 44.0, 0, W * 0.8, 6.0, L * 0.4, col)
			k.box(0, 44.5, -L * 0.25, W * 0.9, 4.0, 14.0, VehicleMesh.GLASS)
			k.taper(0, 44.0, H, L * 0.25, L * 0.33, 8.0, 6.0, 5.0, 0.0, col2)
			k.box(0, 44.1, L * 0.1, 12.0, 0.4, 20.0, Color("4fb3d9"))
		_:
			_hull(k, L, W, 0.8, 0.5, L * 0.2, col, deck)


# --- Air -------------------------------------------------------------------------------

static func _fuselage(k: VehicleMesh, L: float, R: float, fy: float, nose: float, tail: float, col: Color,
		tail_lift := 0.3) -> void:
	k.z_cyl(0, fy, -L / 2, -L / 2 + nose, R * 0.12, R, 10, col)
	k.z_cyl(0, fy, -L / 2 + nose, L / 2 - tail, R, R, 10, col)
	k.z_cyl(0, fy + R * tail_lift, L / 2 - tail, L / 2, R * 0.92, R * 0.2, 10, col)
	k.box(0, fy + R * 0.25, -L / 2 + nose + 0.1, R * 1.4, R * 0.35, nose * 0.25, VehicleMesh.GLASS)


static func _gear(k: VehicleMesh, z: float, x: float, h: float, r: float) -> void:
	for s in ([0.0] if x == 0.0 else [-1.0, 1.0]):
		k.box(s * x, r, z, 0.15, h - r, 0.15, DARK)
		k.wheel(s * x, z, r, 0.25)


static func _prop(k: VehicleMesh, x: float, y: float, z: float, d: float) -> void:
	k.box(x, y - 0.06, z, d, 0.12, 0.05, Color("343a40"))
	k.box(x, y - d / 2, z, 0.12, d, 0.05, Color("343a40"))
	k.z_cyl(x, y, z - 0.25, z + 0.05, 0.02, 0.2, 6, Color("adb5bd"))


static func _aircraft(k: VehicleMesh, t: Dictionary, col: Color, col2: Color) -> void:
	var L := float(t.L)
	var W := float(t.W)
	var H := float(t.H)
	match String(t.get("kind", "jet")):
		"ballon":
			var R := W / 2
			k.ellipsoid(Vector3(0, H - R * 1.15, 0), R, R * 1.15, R, 6, 12, col)
			for i in 6:
				var a := TAU * i / 6.0
				k.rod(Vector3(cos(a) * R * 0.98, H - R * 1.1, sin(a) * R * 0.98), Vector3(cos(a) * R * 0.45, H - R * 2.0, sin(a) * R * 0.45), R * 0.12, col2)
			k.box(0, 0, 0, 1.4, 1.1, 1.4, WOOD)
			for i in 4:
				var a2 := TAU * i / 4.0 + PI / 4
				k.rod(Vector3(cos(a2) * 0.65, 1.1, sin(a2) * 0.65), Vector3(cos(a2) * R * 0.4, H - R * 2.05, sin(a2) * R * 0.4), 0.05, Color("6b4a33"))
			k.person(0, 1.1, 0, Color("1d3557"))
		"dirigeable":
			var R := W / 2
			k.ellipsoid(Vector3(0, H - R, 0), R, R, L / 2, 6, 12, col)
			k.box(0, H - R * 2 - 2.5, -L * 0.2, 4.0, 3.0, 20.0, col2)
			k.box(0, H - R * 2 - 2.0, -L * 0.2, 4.1, 1.2, 18.0, VehicleMesh.GLASS)
			k.fin(H - R * 0.4, L / 2 - 10.0, R * 0.9, 18.0, 8.0, 4.0, 0.6, col2)
			k.fin(H - R * 1.6 - R * 0.9, L / 2 - 10.0, R * 0.9, 8.0, 18.0, -4.0, 0.6, col2)
			k.wings(H - R, L / 2 - 10.0, R * 0.6, R * 0.8, 18.0, 8.0, 4.0, 0.6, col2)
		"biplan":
			var fy := 1.6
			_fuselage(k, L, 0.55, fy, 1.2, 2.5, col, 0.2)
			k.wings(fy - 0.5, -L * 0.15, 0.4, W / 2 - 0.4, 1.6, 1.4, 0.0, 0.12, col2)
			k.wings(fy + 1.2, -L * 0.18, 0.0, W / 2, 1.6, 1.4, 0.0, 0.12, col2)
			for s in [-1.0, 1.0]:
				k.rod(Vector3(s * W * 0.35, fy - 0.4, -L * 0.15), Vector3(s * W * 0.35, fy + 1.2, -L * 0.18), 0.07, WOOD)
			k.wings(fy + 0.1, L / 2 - 0.6, 0.2, 1.4, 1.0, 0.7, 0.2, 0.08, col2)
			k.fin(fy + 0.2, L / 2 - 0.5, 1.1, 1.0, 0.6, 0.3, 0.08, col2)
			k.person(0, fy + 0.1, L * 0.05, Color("6b4a33"))
			_prop(k, 0, fy, -L / 2 - 0.05, 2.4)
			_gear(k, -L * 0.2, 0.8, 1.05, 0.35)
		"hydravion":
			var fy := 2.4
			_fuselage(k, L, 0.85, fy, 2.0, 4.0, col, 0.3)
			k.wings(fy + 0.7, -L * 0.1, 0.0, W / 2, 2.0, 1.4, 0.2, 0.25, col2)
			for s in [-1.0, 1.0]:
				k.z_cyl(s * 1.4, 0.3, -L * 0.35, L * 0.25, 0.4, 0.3, 8, col)
				k.rod(Vector3(s * 1.4, 0.6, -L * 0.15), Vector3(s * 0.6, fy - 0.5, -L * 0.15), 0.1, DARK)
				k.rod(Vector3(s * 1.4, 0.6, -L * 0.15), Vector3(s * 3.0, fy + 0.7, -L * 0.1), 0.08, DARK)
				k.z_cyl(s * 2.6, fy + 0.6, -L * 0.25, -L * 0.05, 0.35, 0.4, 8, col2)
				_prop(k, s * 2.6, fy + 0.6, -L * 0.25 - 0.05, 2.2)
			k.wings(fy + 0.3, L / 2 - 1.0, 0.2, 2.0, 1.4, 0.8, 0.3, 0.1, col)
			k.fin(fy + 0.5, L / 2 - 1.0, 1.8, 1.6, 0.8, 0.5, 0.1, col2)
		"helices", "turboprop":
			var R := 1.25 if t.kind == "helices" else 1.4
			var fy := R + (1.4 if t.kind == "helices" else 1.0)
			_fuselage(k, L, R, fy, 3.0, L * 0.3, col, 0.35)
			var wy := fy - R * 0.6 if t.kind == "helices" else fy + R * 0.85
			k.wings(wy, -L * 0.1, R * 0.9, W / 2 - R, 3.6, 1.4, 0.8, 0.35, col, 0.6 if t.kind == "helices" else -0.2)
			for s in [-1.0, 1.0]:
				var ex: float = s * (R + W * 0.12)
				k.z_cyl(ex, wy - 0.1, -L * 0.1 - 2.6, -L * 0.1 + 1.5, 0.35, 0.55, 8, col2)
				_prop(k, ex, wy - 0.1, -L * 0.1 - 2.7, 3.2)
			k.box(0, fy, 0, R * 2.02, 0.35, L * 0.55, VehicleMesh.GLASS)
			k.box(0, fy - 0.5, 0, R * 2.03, 0.15, L * 0.6, col2)
			if t.kind == "turboprop":
				k.fin(fy + R * 0.6, L / 2 - 2.0, 4.0, 4.0, 2.2, 1.5, 0.3, col2)
				k.wings(fy + R * 0.6 + 4.0, L / 2 - 1.0, 0.15, 4.5, 2.2, 1.2, 0.6, 0.15, col)
				_gear(k, -L * 0.05, R * 0.8, fy - R + 0.2, 0.45)
			else:
				k.fin(fy + R * 0.3, L / 2 - 1.5, 3.2, 3.5, 1.5, 1.0, 0.25, col2)
				k.wings(fy + R * 0.25, L / 2 - 1.3, R * 0.3, 4.0, 2.4, 1.2, 0.6, 0.15, col)
				_gear(k, -L * 0.12, R + W * 0.12, wy, 0.6)
				_gear(k, L / 2 - 1.5, 0.0, fy - R * 0.4, 0.25)
			if t.kind == "turboprop":
				_gear(k, -L / 2 + 2.5, 0.0, fy - R + 0.2, 0.35)
		"jet", "gros":
			var big: bool = t.kind == "gros"
			var R := 3.2 if big else 2.0
			var fy := R + (2.4 if big else 1.7)
			_fuselage(k, L, R, fy, R * 2.5, L * 0.25, col, 0.4)
			if big:
				k.z_cyl(0, fy + R * 0.7, -L / 2 + R * 2.2, -L / 2 + L * 0.35, R * 0.15, R * 0.6, 10, col, 0.8)
			k.box(0, fy + R * 0.3, 0, R * 2.02, 0.4, L * 0.7, VehicleMesh.GLASS)
			k.box(0, fy - R * 0.25, 0, R * 2.03, 0.35, L * 0.8, col2)
			var wy := fy - R * 0.55
			var wz := -L * 0.02
			k.wings(wy, wz, R * 0.8, W / 2 - R * 0.8, L * 0.2, L * 0.05, L * 0.16, 0.5, col, 1.6)
			var engines := [0.33] if not big else [0.25, 0.45]
			for s in [-1.0, 1.0]:
				for f in engines:
					var ex: float = s * (R + (W / 2 - R) * float(f))
					var ez := wz + L * 0.16 * float(f) - L * 0.04
					k.z_cyl(ex, wy - 1.0, ez - 2.5, ez + 1.5, R * 0.42, R * 0.36, 10, col2)
					k.box(ex, wy - 0.7, ez, 0.3, 0.8, 2.0, col)
			k.fin(fy + R * 0.7, L / 2 - L * 0.08, L * 0.18, L * 0.12, L * 0.05, L * 0.07, 0.5, col2)
			k.wings(fy + R * 0.3, L / 2 - L * 0.07, R * 0.4, W * 0.16, L * 0.09, L * 0.03, L * 0.06, 0.3, col, 0.5)
			_gear(k, -L / 2 + R * 3.0, 0.0, fy - R, 0.5)
			_gear(k, wz + L * 0.06, R * 0.7, fy - R * 0.6, 0.65)
		"delta":
			var R := 1.5
			var fy := R + 3.5
			k.z_cyl(0, fy - 0.3, -L / 2, -L / 2 + 8.0, 0.05, R * 0.9, 10, col)
			k.z_cyl(0, fy, -L / 2 + 8.0, L / 2 - 6.0, R, R, 10, col)
			k.z_cyl(0, fy, L / 2 - 6.0, L / 2, R, R * 0.3, 10, col)
			k.box(0, fy + R * 0.2, 0, R * 2.02, 0.3, L * 0.55, VehicleMesh.GLASS)
			k.wings(fy - R * 0.6, L * 0.12, R * 0.9, W / 2 - R * 0.9, L * 0.55, 2.5, L * 0.2, 0.7, col, 0.0)
			for s in [-1.0, 1.0]:
				k.box(s * 3.6, fy - R * 0.6 - 1.4, L * 0.25, 2.8, 1.4, 11.0, col2)
			k.fin(fy + R * 0.6, L / 2 - 6.0, 9.0, 12.0, 3.0, 6.0, 0.4, col)
			_gear(k, -L / 2 + 14.0, 0.0, fy - R, 0.5)
			_gear(k, L * 0.15, 2.5, fy - R, 0.6)
		"affaires":
			var R := 1.0
			var fy := R + 1.2
			_fuselage(k, L, R, fy, 2.8, L * 0.3, col, 0.4)
			k.box(0, fy + R * 0.3, -0.5, R * 2.02, 0.35, L * 0.35, VehicleMesh.GLASS)
			k.box(0, fy - R * 0.2, 0, R * 2.03, 0.2, L * 0.75, col2)
			k.wings(fy - R * 0.6, -L * 0.02, R * 0.8, W / 2 - R * 0.8, 3.2, 1.0, 2.0, 0.3, col, 0.6)
			for s in [-1.0, 1.0]:
				k.z_cyl(s * (R + 0.55), fy + R * 0.2, L * 0.2, L * 0.38, 0.45, 0.4, 8, col2)
			k.fin(fy + R * 0.6, L / 2 - 1.8, 2.8, 2.8, 1.5, 1.6, 0.25, col)
			k.wings(fy + R * 0.6 + 2.8, L / 2 - 0.4, 0.1, 2.6, 1.5, 0.8, 0.8, 0.15, col)
			_gear(k, -L / 2 + 2.5, 0.0, fy - R, 0.3)
			_gear(k, 0.6, R * 1.2, fy - R * 0.6, 0.35)
		"helico":
			var fy := 1.5
			k.ellipsoid(Vector3(0, fy, -L * 0.18), 1.2, 1.1, 2.2, 4, 8, col)
			k.ellipsoid(Vector3(0, fy + 0.2, -L * 0.18 - 1.0), 1.0, 0.8, 1.2, 3, 8, VehicleMesh.GLASS)
			k.z_cyl(0, fy + 0.3, -L * 0.1, L / 2 - 0.5, 0.45, 0.15, 6, col)
			k.fin(fy + 0.2, L / 2 - 0.6, 1.4, 1.0, 0.6, 0.3, 0.1, col2)
			k.cylinder(0, fy + 1.0, -L * 0.18, 0.2, 0.15, 0.6, 6, DARK)
			k.box(0, fy + 1.6, -L * 0.18, 10.5, 0.06, 0.35, DARK)
			k.box(0, fy + 1.62, -L * 0.18, 0.35, 0.06, 10.5, DARK)
			k.box(0.25, fy + 0.3, L / 2 - 0.5, 0.05, 1.6, 0.2, DARK)
			for s in [-1.0, 1.0]:
				k.box(s * 1.0, 0.0, -L * 0.18, 0.1, 0.1, 3.2, DARK)
				k.rod(Vector3(s * 1.0, 0.05, -L * 0.18 - 0.8), Vector3(s * 0.6, fy - 0.8, -L * 0.18 - 0.6), 0.08, DARK)
				k.rod(Vector3(s * 1.0, 0.05, -L * 0.18 + 0.8), Vector3(s * 0.6, fy - 0.8, -L * 0.18 + 0.6), 0.08, DARK)
		"multirotor":
			var fy := 1.0
			k.ellipsoid(Vector3(0, fy, 0), 0.9, 0.8, 1.8, 4, 8, col)
			k.ellipsoid(Vector3(0, fy + 0.25, -0.5), 0.8, 0.55, 1.2, 3, 8, VehicleMesh.GLASS)
			for i in 8:
				var a := TAU * (i + 0.5) / 8.0
				var p := Vector3(cos(a) * 3.0, fy + 0.7, sin(a) * 2.4)
				k.rod(Vector3(0, fy + 0.6, 0), p, 0.12, col2)
				k.cylinder(p.x, p.y, p.z, 0.75, 0.75, 0.04, 10, Color(0.2, 0.2, 0.25))
			for s in [-1.0, 1.0]:
				k.box(s * 0.7, 0.0, 0, 0.1, 0.1, 2.2, DARK)
				k.rod(Vector3(s * 0.7, 0.05, 0), Vector3(s * 0.5, fy - 0.5, 0), 0.08, DARK)
