class_name Styles
extends RefCounted
## « Bible » des styles du monde : régions et époques.
##
## Ce registre est partagé par tous les catalogues (bâtiments, et plus tard
## véhicules, mobilier, végétation…). Chaque entrée d'un catalogue peut porter
## "region" et "era" pour être filtrée dans les panneaux et suivie par le zonage.

const REGIONS := [
	{"id": "europe", "name": "Europe"},
	{"id": "mediterranee", "name": "Méditerranée"},
	{"id": "moyen_orient", "name": "Moyen-Orient et Maghreb"},
	{"id": "afrique", "name": "Afrique"},
	{"id": "asie_est", "name": "Asie de l'Est"},
	{"id": "asie_sud", "name": "Asie du Sud et du Sud-Est"},
	{"id": "ameriques", "name": "Amériques"},
	{"id": "monde", "name": "Monde"},
]

const ERAS := [
	{"id": "antique", "name": "Antiquité"},
	{"id": "traditionnel", "name": "Traditionnel"},
	{"id": "classique", "name": "XIXe – 1945"},
	{"id": "moderne", "name": "Moderne"},
	{"id": "contemporain", "name": "Contemporain"},
	{"id": "futuriste", "name": "Futuriste"},
]

## Types de bâtiments génériques (archétypes) et leur catégorie.
const ARCHETYPES := {
	"maison": {"name": "Maison", "cat": "logement"},
	"grande_maison": {"name": "Grande maison", "cat": "logement"},
	"rangee": {"name": "Maisons de ville", "cat": "logement"},
	"immeuble": {"name": "Immeuble", "cat": "logement"},
	"tour": {"name": "Tour d'habitation", "cat": "logement"},
	"boutique": {"name": "Boutique", "cat": "commerce"},
	"marche": {"name": "Marché couvert", "cat": "commerce"},
	"grand_magasin": {"name": "Grand magasin", "cat": "commerce"},
	"bureaux": {"name": "Bureaux", "cat": "commerce"},
	"gratte_ciel": {"name": "Gratte-ciel", "cat": "commerce"},
	"atelier": {"name": "Atelier", "cat": "industrie"},
	"usine": {"name": "Usine", "cat": "industrie"},
	"entrepot": {"name": "Entrepôt", "cat": "industrie"},
	"ferme": {"name": "Ferme", "cat": "industrie"},
	"culte": {"name": "Lieu de culte", "cat": "services"},
	"palais": {"name": "Palais", "cat": "services"},
	"ecole": {"name": "École", "cat": "services"},
	"hopital": {"name": "Hôpital", "cat": "services"},
	"gare": {"name": "Gare", "cat": "services"},
	"restaurant": {"name": "Restaurant", "cat": "loisirs"},
	"theatre": {"name": "Théâtre", "cat": "loisirs"},
	"jardin": {"name": "Jardin", "cat": "loisirs"},
}

## Les styles. roof : gable (deux pans), hip (quatre pans), flat (terrasse),
## mansard, curved (pagode, bords relevés), thatch (chaume), shed (tôle).
## walls / roofs : couleurs possibles. names : noms propres au style.
const STYLES := {
	# --- Europe ----------------------------------------------------------------
	"colombages": {"name": "Colombages", "region": "europe", "era": "traditionnel",
		"walls": ["f3ead8", "efe0c4", "f6f1e7"], "roofs": ["a8452f", "8c4a3a", "7a3b2a"], "trim": "4a3222",
		"roof": "gable", "pitch": 0.9, "floor_h": 2.8, "timber": true, "culte": "eglise", "palais": "chateau_fort",
		"archs": ["maison", "grande_maison", "rangee", "boutique", "marche", "atelier", "ferme", "culte", "palais", "restaurant"],
		"names": {"maison": "Maison à colombages", "grande_maison": "Manoir", "rangee": "Rue à colombages", "marche": "Halle médiévale",
			"culte": "Église de village", "palais": "Château fort", "restaurant": "Auberge", "ferme": "Corps de ferme"}},
	"gothique": {"name": "Pierre médiévale", "region": "europe", "era": "traditionnel",
		"walls": ["c9c1ae", "b8b09c", "d4ccb8"], "roofs": ["4f5560", "5b6270"], "trim": "8a8272",
		"roof": "gable", "pitch": 1.1, "floor_h": 3.2, "culte": "cathedrale", "palais": "chateau_fort",
		"archs": ["maison", "grande_maison", "culte", "palais", "ferme", "atelier"],
		"names": {"maison": "Maison de pierre", "grande_maison": "Abbaye", "culte": "Cathédrale gothique", "palais": "Donjon",
			"ferme": "Moulin et grange", "atelier": "Forge"}},
	"haussmann": {"name": "Haussmannien", "region": "europe", "era": "classique",
		"walls": ["e8dcc2", "efe4cc", "e2d4b6"], "roofs": ["5d6670", "4f5863"], "trim": "2b2b2b",
		"roof": "mansard", "floor_h": 3.4, "balcony": true, "culte": "eglise_classique", "palais": "hotel_de_ville",
		"archs": ["immeuble", "rangee", "boutique", "grand_magasin", "bureaux", "palais", "culte", "theatre", "gare", "restaurant", "ecole", "hopital"],
		"names": {"immeuble": "Immeuble haussmannien", "rangee": "Hôtels particuliers", "grand_magasin": "Grand magasin 1900",
			"palais": "Hôtel de ville", "theatre": "Opéra", "gare": "Gare monumentale", "restaurant": "Brasserie", "culte": "Église néoclassique"}},
	"briques_ind": {"name": "Briques industrielles", "region": "europe", "era": "classique",
		"walls": ["a64b35", "9a4431", "b5583d"], "roofs": ["4f5560", "3f444c"], "trim": "e8e0d0",
		"roof": "gable", "pitch": 0.6, "floor_h": 3.2, "culte": "eglise", "palais": "hotel_de_ville",
		"archs": ["rangee", "immeuble", "usine", "entrepot", "atelier", "gare", "ecole", "marche"],
		"names": {"rangee": "Corons", "immeuble": "Immeuble ouvrier", "usine": "Filature", "entrepot": "Docks", "marche": "Halle en fonte"}},
	"scandinave": {"name": "Bois nordique", "region": "europe", "era": "traditionnel",
		"walls": ["9b2c2c", "b03a2e", "e9c46a", "f1ece2"], "roofs": ["2f3640", "3d4a3e"], "trim": "f6f1e7",
		"roof": "gable", "pitch": 1.0, "floor_h": 2.7, "culte": "stavkirke", "palais": "hotel_de_ville",
		"archs": ["maison", "grande_maison", "rangee", "boutique", "ferme", "culte", "atelier"],
		"names": {"maison": "Maison en bois", "rangee": "Maisons du port", "culte": "Église en bois debout", "ferme": "Grange rouge"}},
	"isba": {"name": "Bois slave", "region": "europe", "era": "traditionnel",
		"walls": ["8a6a48", "7a5a3a"], "roofs": ["5a4a3a", "6b7f5a"], "trim": "e8e0c8",
		"roof": "gable", "pitch": 1.0, "floor_h": 2.8, "culte": "eglise_bulbes", "palais": "kremlin",
		"archs": ["maison", "grande_maison", "ferme", "culte", "palais"],
		"names": {"maison": "Isba", "grande_maison": "Datcha", "culte": "Église à bulbes", "palais": "Kremlin"}},
	# --- Méditerranée -------------------------------------------------------------
	"grec_antique": {"name": "Gréco-romain", "region": "mediterranee", "era": "antique",
		"walls": ["efe6d2", "e6dcc6"], "roofs": ["b5523b", "a8452f"], "trim": "f6f1e7",
		"roof": "gable", "pitch": 0.35, "floor_h": 3.5, "culte": "temple_grec", "palais": "forum",
		"archs": ["maison", "grande_maison", "boutique", "marche", "culte", "palais", "theatre"],
		"names": {"maison": "Insula", "grande_maison": "Domus", "boutique": "Taberna", "marche": "Agora",
			"culte": "Temple à colonnes", "palais": "Basilique romaine", "theatre": "Amphithéâtre"}},
	"mediterraneen": {"name": "Village méditerranéen", "region": "mediterranee", "era": "traditionnel",
		"walls": ["f7f4ee", "f2e3c6", "eed9b0"], "roofs": ["c46a3b", "b5523b"], "trim": "2a6fdb",
		"roof": "hip", "pitch": 0.35, "floor_h": 2.8, "culte": "chapelle_bleue", "palais": "palazzo",
		"archs": ["maison", "grande_maison", "rangee", "boutique", "marche", "culte", "palais", "restaurant", "ferme"],
		"names": {"maison": "Maison blanchie", "grande_maison": "Villa toscane", "culte": "Chapelle au dôme bleu",
			"palais": "Palazzo", "restaurant": "Taverne", "ferme": "Mas"}},
	# --- Moyen-Orient et Maghreb ---------------------------------------------------
	"maghreb": {"name": "Médina", "region": "moyen_orient", "era": "traditionnel",
		"walls": ["e3b98a", "d9a46c", "f2e3c6"], "roofs": ["2a9d8f"], "trim": "1f6f5f",
		"roof": "flat", "floor_h": 3.0, "court": true, "culte": "mosquee_minaret", "palais": "kasbah",
		"archs": ["maison", "grande_maison", "boutique", "marche", "culte", "palais", "restaurant", "atelier"],
		"names": {"maison": "Maison de médina", "grande_maison": "Riad", "boutique": "Échoppe", "marche": "Souk",
			"culte": "Mosquée et minaret", "palais": "Kasbah", "restaurant": "Salon de thé", "atelier": "Tannerie"}},
	"persan": {"name": "Persan", "region": "moyen_orient", "era": "traditionnel",
		"walls": ["d8c3a0", "cdb48c"], "roofs": ["2f7fb8", "3a9fc0"], "trim": "1f5f8f",
		"roof": "flat", "floor_h": 3.2, "culte": "mosquee_dome", "palais": "palais_dome",
		"archs": ["maison", "grande_maison", "marche", "culte", "palais", "jardin"],
		"names": {"maison": "Maison à tour du vent", "grande_maison": "Caravansérail", "marche": "Bazar à coupoles",
			"culte": "Mosquée à coupole", "palais": "Palais aux coupoles", "jardin": "Jardin persan"}},
	"golfe": {"name": "Golfe contemporain", "region": "moyen_orient", "era": "contemporain",
		"walls": ["f2ead8", "e6dcc6"], "roofs": ["d8d0bc"], "trim": "6d97b8",
		"roof": "flat", "floor_h": 3.6, "glass": "5c8fb5", "culte": "mosquee_dome", "palais": "palais_dome",
		"archs": ["grande_maison", "immeuble", "tour", "gratte_ciel", "grand_magasin", "bureaux", "culte", "hopital"],
		"names": {"grande_maison": "Villa du Golfe", "gratte_ciel": "Tour flèche", "grand_magasin": "Mall géant"}},
	# --- Afrique ----------------------------------------------------------------------
	"sahel": {"name": "Architecture de terre", "region": "afrique", "era": "traditionnel",
		"walls": ["b07a4a", "c08a58", "a86e40"], "roofs": ["c9a46a"], "trim": "6b4a2b",
		"roof": "flat", "floor_h": 3.0, "spikes": true, "culte": "mosquee_terre", "palais": "palais_terre",
		"archs": ["maison", "grande_maison", "marche", "culte", "palais", "ferme"],
		"names": {"maison": "Case ronde", "grande_maison": "Concession", "marche": "Grand marché",
			"culte": "Grande mosquée de terre", "palais": "Palais du chef", "ferme": "Greniers"}},
	"afrique_sud": {"name": "Rondavels", "region": "afrique", "era": "traditionnel",
		"walls": ["e6d2a8", "d8b886", "f2e3c6"], "roofs": ["b39a5e", "a58c50"], "trim": "8c3b2b",
		"roof": "thatch", "floor_h": 2.6, "paint": true, "culte": "eglise", "palais": "kraal",
		"archs": ["maison", "grande_maison", "ferme", "marche", "palais"],
		"names": {"maison": "Rondavel", "grande_maison": "Maison peinte", "ferme": "Kraal", "palais": "Enclos royal"}},
	"afrique_moderne": {"name": "Ville africaine", "region": "afrique", "era": "moderne",
		"walls": ["f2c14e", "76b041", "4ea8de", "e76f51", "f1ece2"], "roofs": ["9aa3ad", "8a8f96"], "trim": "2b2b2b",
		"roof": "shed", "floor_h": 3.0, "culte": "eglise_moderne", "palais": "hotel_de_ville",
		"archs": ["maison", "rangee", "immeuble", "boutique", "marche", "bureaux", "ecole", "hopital", "restaurant", "atelier"],
		"names": {"maison": "Maison en parpaings", "boutique": "Boutique peinte", "marche": "Marché aux toits de tôle", "restaurant": "Maquis"}},
	# --- Asie de l'Est ------------------------------------------------------------------
	"chinois": {"name": "Chine impériale", "region": "asie_est", "era": "traditionnel",
		"walls": ["b8322a", "c0392b", "e6d6b8"], "roofs": ["3f4a52", "2f6b4a", "d9a520"], "trim": "1f1f1f",
		"roof": "curved", "floor_h": 3.2, "court": true, "culte": "pagode", "palais": "cite_interdite",
		"archs": ["maison", "grande_maison", "boutique", "marche", "culte", "palais", "restaurant", "jardin"],
		"names": {"maison": "Maison à cour", "grande_maison": "Siheyuan", "culte": "Pagode", "palais": "Pavillon impérial",
			"restaurant": "Maison de thé", "jardin": "Jardin de lettré"}},
	"japonais": {"name": "Japon traditionnel", "region": "asie_est", "era": "traditionnel",
		"walls": ["f4f0e6", "e8e0cc", "8a5a36"], "roofs": ["3a3f45", "2f3338"], "trim": "5a3a22",
		"roof": "curved", "floor_h": 2.9, "culte": "sanctuaire", "palais": "chateau_japonais",
		"archs": ["maison", "grande_maison", "rangee", "boutique", "culte", "palais", "restaurant", "ferme", "jardin"],
		"names": {"maison": "Minka", "grande_maison": "Ryokan", "rangee": "Machiya", "culte": "Sanctuaire et torii",
			"palais": "Château japonais", "restaurant": "Izakaya", "ferme": "Ferme gasshō", "jardin": "Jardin zen"}},
	"asie_dense": {"name": "Mégapole asiatique", "region": "asie_est", "era": "contemporain",
		"walls": ["dfe6ee", "c9d3dc", "eceff2"], "roofs": ["9aa3ad"], "trim": "e63946",
		"roof": "flat", "floor_h": 3.2, "glass": "3c5a78", "neon": true, "culte": "pagode", "palais": "hotel_de_ville",
		"archs": ["rangee", "immeuble", "tour", "gratte_ciel", "boutique", "grand_magasin", "bureaux", "restaurant", "hopital", "usine"],
		"names": {"rangee": "Immeubles-boutiques", "boutique": "Konbini", "gratte_ciel": "Tour de verre", "restaurant": "Restaurant de nouilles"}},
	# --- Asie du Sud et du Sud-Est -----------------------------------------------------
	"indien": {"name": "Rajasthan", "region": "asie_sud", "era": "traditionnel",
		"walls": ["e2a76f", "d98c5f", "f0c48a"], "roofs": ["e2a76f"], "trim": "f6f1e7",
		"roof": "flat", "floor_h": 3.2, "chhatri": true, "culte": "temple_shikhara", "palais": "palais_moghol",
		"archs": ["maison", "grande_maison", "boutique", "marche", "culte", "palais", "jardin"],
		"names": {"maison": "Maison de bazar", "grande_maison": "Haveli", "culte": "Temple hindou", "palais": "Palais moghol",
			"marche": "Bazar", "jardin": "Jardin moghol"}},
	"asie_se": {"name": "Asie du Sud-Est", "region": "asie_sud", "era": "traditionnel",
		"walls": ["9c6b45", "b08a5a", "8a5a36"], "roofs": ["b5523b", "c46a3b", "8a6a3a"], "trim": "d9a520",
		"roof": "curved", "floor_h": 2.8, "stilts": true, "culte": "wat", "palais": "palais_siamois",
		"archs": ["maison", "grande_maison", "marche", "culte", "palais", "ferme", "restaurant"],
		"names": {"maison": "Maison sur pilotis", "grande_maison": "Longue maison", "marche": "Marché flottant",
			"culte": "Temple (wat) et stupa", "palais": "Palais royal", "ferme": "Grenier à riz"}},
	# --- Amériques ----------------------------------------------------------------------
	"pueblo": {"name": "Adobe", "region": "ameriques", "era": "traditionnel",
		"walls": ["c98d5a", "d49e6a", "b97c4a"], "roofs": ["c98d5a"], "trim": "6b4a2b",
		"roof": "flat", "floor_h": 2.8, "vigas": true, "culte": "mission", "palais": "pueblo",
		"archs": ["maison", "grande_maison", "marche", "culte", "palais", "ferme"],
		"names": {"maison": "Maison en adobe", "grande_maison": "Hacienda", "culte": "Mission espagnole", "palais": "Pueblo en terrasses"}},
	"precolombien": {"name": "Précolombien", "region": "ameriques", "era": "antique",
		"walls": ["b9ae96", "a89c82"], "roofs": ["8a7d64"], "trim": "6b5d44",
		"roof": "flat", "floor_h": 3.0, "culte": "pyramide", "palais": "palais_maya",
		"archs": ["maison", "grande_maison", "culte", "palais", "marche"],
		"names": {"maison": "Maison de pierre", "grande_maison": "Maison de notable", "culte": "Pyramide à degrés", "palais": "Palais maya", "marche": "Marché de Tlatelolco"}},
	"colonial": {"name": "Colonial américain", "region": "ameriques", "era": "classique",
		"walls": ["f6f4ee", "e9dcc6", "c9d6df", "e8c9a8"], "roofs": ["4f5560", "5b4636"], "trim": "f6f4ee",
		"roof": "gable", "pitch": 0.8, "floor_h": 3.0, "porch": true, "culte": "eglise_blanche", "palais": "capitole",
		"archs": ["maison", "grande_maison", "rangee", "boutique", "ferme", "culte", "palais", "ecole", "gare", "restaurant"],
		"names": {"maison": "Maison à bardeaux", "grande_maison": "Maison de planteur", "rangee": "Brownstones",
			"boutique": "Saloon de Main Street", "ferme": "Grange et silo", "culte": "Église blanche", "palais": "Capitole", "restaurant": "Diner"}},
	"latino": {"name": "Amérique latine", "region": "ameriques", "era": "classique",
		"walls": ["f2c14e", "e76f51", "4ea8de", "f4a3b4", "76b041"], "roofs": ["c46a3b", "b5523b"], "trim": "f6f4ee",
		"roof": "flat", "floor_h": 3.4, "court": true, "culte": "cathedrale_baroque", "palais": "palacio",
		"archs": ["maison", "rangee", "grande_maison", "boutique", "marche", "culte", "palais", "restaurant"],
		"names": {"maison": "Casa colorée", "rangee": "Rue coloniale", "grande_maison": "Maison à patio",
			"culte": "Cathédrale baroque", "palais": "Palacio", "restaurant": "Cantina"}},
	"art_deco": {"name": "Art déco", "region": "ameriques", "era": "classique",
		"walls": ["e6dcc6", "d9cdb4", "c9bfa8"], "roofs": ["b9b0a0"], "trim": "c9a227",
		"roof": "flat", "floor_h": 3.6, "glass": "3c4a58", "setback": true, "culte": "eglise_classique", "palais": "capitole",
		"archs": ["immeuble", "tour", "gratte_ciel", "grand_magasin", "bureaux", "theatre", "gare", "hopital"],
		"names": {"gratte_ciel": "Gratte-ciel à gradins", "theatre": "Cinéma Art déco", "gare": "Terminal"}},
	"banlieue_us": {"name": "Banlieue américaine", "region": "ameriques", "era": "moderne",
		"walls": ["e9e2d4", "c9d6df", "e7d3b4", "d6e2cf"], "roofs": ["5b5f66", "6e5a48"], "trim": "f6f4ee",
		"roof": "gable", "pitch": 0.45, "floor_h": 3.0, "garage": true, "culte": "eglise_moderne", "palais": "hotel_de_ville",
		"archs": ["maison", "grande_maison", "boutique", "grand_magasin", "restaurant", "ecole", "entrepot"],
		"names": {"maison": "Pavillon", "grande_maison": "Maison de banlieue", "boutique": "Strip mall", "grand_magasin": "Hypermarché", "restaurant": "Fast-food"}},
	# --- Monde --------------------------------------------------------------------------
	"international": {"name": "Style international", "region": "monde", "era": "moderne",
		"walls": ["e8e6e0", "d8d6cf", "f2f0ea"], "roofs": ["b9b6ae"], "trim": "3c4a58",
		"roof": "flat", "floor_h": 3.0, "glass": "3c5a78", "culte": "eglise_moderne", "palais": "hotel_de_ville",
		"archs": ["maison", "rangee", "immeuble", "tour", "bureaux", "grand_magasin", "usine", "entrepot", "ecole", "hopital", "gare", "theatre"],
		"names": {"maison": "Maison cube", "immeuble": "Barre de logements", "tour": "Tour de logements", "theatre": "Maison de la culture"}},
	"verre": {"name": "Verre et acier", "region": "monde", "era": "contemporain",
		"walls": ["8fb8d8", "a7c7de", "7fa6c4"], "roofs": ["cfd8df"], "trim": "e7eef3",
		"roof": "flat", "floor_h": 3.5, "glass": "6d97b8", "green_roof": true, "culte": "eglise_moderne", "palais": "hotel_de_ville",
		"archs": ["maison", "immeuble", "tour", "gratte_ciel", "bureaux", "grand_magasin", "ecole", "hopital", "theatre", "gare"],
		"names": {"maison": "Maison passive", "immeuble": "Écoquartier", "theatre": "Musée", "gare": "Gare TGV"}},
	"futuriste": {"name": "Futuriste", "region": "monde", "era": "futuriste",
		"walls": ["f2f6f8", "e0e8ee"], "roofs": ["cfe8f2"], "trim": "4fd1e0",
		"roof": "dome", "floor_h": 3.8, "glass": "4fb3d9", "culte": "eglise_moderne", "palais": "hotel_de_ville",
		"archs": ["maison", "immeuble", "tour", "gratte_ciel", "bureaux", "grand_magasin", "usine", "hopital", "theatre"],
		"names": {"maison": "Habitat bulle", "immeuble": "Arcologie", "tour": "Tour vivante", "gratte_ciel": "Tour orbitale",
			"usine": "Fabrique automatisée", "theatre": "Dôme des spectacles"}},
}


static func region_name(id: String) -> String:
	for r in REGIONS:
		if r.id == id:
			return r.name
	return id


static func era_name(id: String) -> String:
	for e in ERAS:
		if e.id == id:
			return e.name
	return id


## Vrai si une entrée de catalogue passe les filtres ("" = tout).
static func matches(entry: Dictionary, region: String, era: String) -> bool:
	if region != "" and String(entry.get("region", "")) != region:
		return false
	if era != "" and String(entry.get("era", "")) != era:
		return false
	return true
