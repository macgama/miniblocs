class_name BuildingCatalog
extends RefCounted
## Catalogue des bâtiments prédéfinis, rangés par catégorie.
##
## Chaque type a une emprise réelle en cases de 1 m (w le long de la façade,
## d en profondeur), les voies qui peuvent le desservir, et quelques chiffres
## (logements, emplois, visiteurs) qui serviront aux futures mécaniques.
## Les modèles low-poly sont fabriqués en code (aucun fichier 3D à fournir).

const CATEGORIES := [
	{"id": "logement", "name": "Logement", "color": Color("e9c46a")},
	{"id": "commerce", "name": "Commerce", "color": Color("4ea8de")},
	{"id": "industrie", "name": "Industrie", "color": Color("b08968")},
	{"id": "production", "name": "Production et ressources", "color": Color("d4a373")},
	{"id": "services", "name": "Services publics", "color": Color("e76f51")},
	{"id": "loisirs", "name": "Loisirs", "color": Color("80b918")},
	{"id": "sport", "name": "Sport", "color": Color("9d4edd")},
	{"id": "espaces", "name": "Espaces publics", "color": Color("52b788")},
]

const ROAD := ["route"]
const ROAD_OR_PATH := ["route", "chemin"]

const BASE_TYPES := {
	# --- Logement -----------------------------------------------------------------
	"maison": {"name": "Maison", "cat": "logement", "w": 10, "d": 12, "access": ROAD,
		"logements": 1, "desc": "Maison individuelle avec jardin."},
	"villa": {"name": "Villa", "cat": "logement", "w": 16, "d": 16, "access": ROAD,
		"logements": 1, "desc": "Grande maison, garage et piscine."},
	"immeuble": {"name": "Petit immeuble", "cat": "logement", "w": 18, "d": 14, "access": ROAD,
		"logements": 12, "desc": "Quatre étages, douze appartements."},
	"tour_habitation": {"name": "Tour d'habitation", "cat": "logement", "w": 22, "d": 22, "access": ROAD,
		"logements": 60, "desc": "Douze étages au-dessus d'un socle."},
	# --- Commerce -----------------------------------------------------------------
	"boulangerie": {"name": "Boulangerie", "cat": "commerce", "w": 8, "d": 12, "access": ROAD_OR_PATH,
		"emplois": 4, "visiteurs": 150, "desc": "Petit commerce avec logement à l'étage."},
	"superette": {"name": "Supérette", "cat": "commerce", "w": 16, "d": 16, "access": ROAD,
		"emplois": 8, "visiteurs": 400, "desc": "Commerce de quartier."},
	"supermarche": {"name": "Supermarché", "cat": "commerce", "w": 44, "d": 46, "access": ROAD,
		"emplois": 60, "visiteurs": 2500, "desc": "Grande surface et son parking."},
	"bureaux": {"name": "Immeuble de bureaux", "cat": "commerce", "w": 22, "d": 18, "access": ROAD,
		"emplois": 250, "desc": "Six étages vitrés."},
	# --- Industrie ----------------------------------------------------------------
	"atelier": {"name": "Atelier", "cat": "industrie", "w": 16, "d": 20, "access": ROAD,
		"emplois": 10, "desc": "Petite fabrication, porte de quai."},
	"entrepot": {"name": "Entrepôt", "cat": "industrie", "w": 32, "d": 42, "access": ROAD,
		"emplois": 30, "desc": "Stockage et quais de chargement."},
	"usine": {"name": "Usine", "cat": "industrie", "w": 44, "d": 34, "access": ROAD,
		"emplois": 120, "desc": "Toit en dents de scie et cheminée."},
	"ferme": {"name": "Ferme", "cat": "industrie", "w": 30, "d": 26, "access": ROAD_OR_PATH,
		"emplois": 4, "logements": 1, "desc": "Corps de ferme, grange et silo."},
	# --- Services publics -----------------------------------------------------------
	"mairie": {"name": "Mairie", "cat": "services", "w": 26, "d": 18, "access": ROAD,
		"emplois": 30, "desc": "Hôtel de ville et son horloge."},
	"ecole": {"name": "École", "cat": "services", "w": 38, "d": 30, "access": ROAD_OR_PATH,
		"emplois": 25, "visiteurs": 300, "desc": "Bâtiment en L et cour de récréation."},
	"pompiers": {"name": "Caserne de pompiers", "cat": "services", "w": 22, "d": 18, "access": ROAD,
		"emplois": 20, "desc": "Trois portes de garage et une tour."},
	"police": {"name": "Commissariat", "cat": "services", "w": 18, "d": 16, "access": ROAD,
		"emplois": 20, "desc": "Poste de police."},
	"hopital": {"name": "Hôpital", "cat": "services", "w": 44, "d": 34, "access": ROAD,
		"emplois": 400, "visiteurs": 800, "desc": "Bâtiment principal et héliport."},
	"chateau_eau": {"name": "Château d'eau", "cat": "services", "w": 12, "d": 12, "access": ROAD_OR_PATH,
		"desc": "Réservoir sur pilier, 25 m de haut."},
	# --- Loisirs --------------------------------------------------------------------
	"parc": {"name": "Parc", "cat": "loisirs", "w": 30, "d": 30, "access": ROAD_OR_PATH,
		"visiteurs": 300, "desc": "Pelouse, allées, arbres et fontaine."},
	"aire_jeux": {"name": "Aire de jeux", "cat": "loisirs", "w": 14, "d": 14, "access": ROAD_OR_PATH,
		"visiteurs": 60, "desc": "Toboggan, balançoire, bac à sable."},
	"cafe": {"name": "Café-restaurant", "cat": "loisirs", "w": 12, "d": 14, "access": ROAD_OR_PATH,
		"emplois": 6, "visiteurs": 120, "desc": "Salle et terrasse avec parasols."},
	"cinema": {"name": "Cinéma", "cat": "loisirs", "w": 26, "d": 32, "access": ROAD,
		"emplois": 15, "visiteurs": 600, "desc": "Quatre salles et une enseigne."},
	# --- Sport ----------------------------------------------------------------------
	"foot": {"name": "Terrain de football", "cat": "sport", "w": 76, "d": 115, "access": ROAD_OR_PATH,
		"visiteurs": 500, "desc": "Terrain de 105 × 68 m et une tribune."},
	"tennis": {"name": "Court de tennis", "cat": "sport", "w": 20, "d": 38, "access": ROAD_OR_PATH,
		"visiteurs": 20, "desc": "Court en terre battue, grillage."},
	"basket": {"name": "Terrain de basket", "cat": "sport", "w": 18, "d": 30, "access": ROAD_OR_PATH,
		"visiteurs": 30, "desc": "Terrain extérieur de 28 × 15 m."},
	"gymnase": {"name": "Gymnase", "cat": "sport", "w": 34, "d": 28, "access": ROAD,
		"emplois": 4, "visiteurs": 200, "desc": "Salle de sport couverte."},
	"piscine": {"name": "Piscine", "cat": "sport", "w": 34, "d": 24, "access": ROAD,
		"emplois": 8, "visiteurs": 300, "desc": "Bassin extérieur de 25 m et vestiaires."},
}

## Prix de construction (€), sans le terrassement.
const COSTS := {
	"maison": 280_000, "villa": 650_000, "immeuble": 2_400_000, "tour_habitation": 14_000_000,
	"boulangerie": 350_000, "superette": 900_000, "supermarche": 6_500_000, "bureaux": 9_000_000,
	"atelier": 600_000, "entrepot": 2_200_000, "usine": 7_500_000, "ferme": 900_000,
	"mairie": 4_000_000, "ecole": 6_000_000, "pompiers": 2_500_000, "police": 1_800_000,
	"hopital": 25_000_000, "chateau_eau": 1_200_000,
	"parc": 300_000, "aire_jeux": 80_000, "cafe": 450_000, "cinema": 5_000_000,
	"foot": 1_500_000, "tennis": 120_000, "basket": 90_000, "gymnase": 3_500_000, "piscine": 2_800_000,
}

const WALL := Color("f1e6d2")
const WALL_WARM := Color("f2d0a9")
const ROOF_TILE := Color("c8553d")
const ROOF_DARK := Color("5b5f66")
const GLASS := Color("33495e")
const DOOR := Color("6b4a33")
const GRASS := Color("6aa84f")
const ASPHALT := Color("55585e")
const LINE := Color("f2f2f2")
const CONCRETE := Color("b9b6ae")


static var _all: Dictionary = {}


## Tous les types : les modèles faits main, puis la bible générée par styles
## (région × époque × archétype, voir Styles et StyleBuilder).
static func all_types() -> Dictionary:
	if _all.is_empty():
		for id in BASE_TYPES:
			var t: Dictionary = BASE_TYPES[id].duplicate()
			t["region"] = "monde"
			t["era"] = "moderne"
			t["style"] = ""
			_all[id] = t
		_all.merge(EspacesPublics.entries())
		_all.merge(ProductionTypes.entries())
		_all.merge(CommercesTypes.entries())
		_all.merge(Stades.entries())
		_all.merge(StyleBuilder.generate())
		_all.merge(BibleGlb.entries())
		for id in Creations.items:
			_all[id] = Creations.catalog_entry(id)
		Creations.ensure_loaded()
	return _all


static func get_type(id: String) -> Dictionary:
	return all_types().get(id, {})


static func cost(id: String) -> int:
	if COSTS.has(id):
		return int(COSTS[id])
	return int(get_type(id).get("cost", 0))


## Identifiants d'une catégorie, filtrés par région et par époque ("" = toutes).
static func ids_in(cat: String, region := "", era := "") -> Array[String]:
	var out: Array[String] = []
	var types := all_types()
	for id in types:
		var t: Dictionary = types[id]
		if t.cat == cat and Styles.matches(t, region, era):
			out.append(id)
	return out


## Identifiants d'un style donné dans une catégorie.
static func ids_of_style(cat: String, style: String) -> Array[String]:
	var out: Array[String] = []
	var types := all_types()
	for id in types:
		var t: Dictionary = types[id]
		if t.cat == cat and String(t.get("style", "")) == style:
			out.append(id)
	return out


static func category(cat: String) -> Dictionary:
	for c in CATEGORIES:
		if c.id == cat:
			return c
	return {}


## Emprise en cases selon la rotation (0 à 3, quarts de tour).
static func footprint(id: String, rot: int) -> Vector2i:
	var t := get_type(id)
	var w := int(t.get("w", 1))
	var d := int(t.get("d", 1))
	return Vector2i(d, w) if rot % 2 == 1 else Vector2i(w, d)


## Fabrique le modèle low-poly d'un type (repère local : sol en y = 0, façade vers −Z).
## `details` : finitions low-poly (toits en rangs, teintes par face…) ; sans
## elles, c'est la version légère utilisée au loin.
## variant : variante du modèle (bâtiments de la bible seulement, 0 = modèle de base).
## Variantes par type de la bible (couleurs, fenêtres, pente du toit, détails).
const VARIANTES := 4


static func build_mesh(id: String, material: Material = null, details := true, variant := 0, perso: Dictionary = {}) -> ArrayMesh:
	var k := BlocMesh.new()
	k.details = details
	k.variant = variant
	k.perso = perso
	var t := get_type(id)
	var w := float(t.get("w", 4))
	var d := float(t.get("d", 4))
	if t.get("espace", false):
		EspacesPublics.build(k, id, t)
		k.fit_xz(w, d)
		return k.to_mesh(material)
	if t.has("blocks"):
		return Creations.build_mesh(t)
	if t.has("glb") and t.has("stade"):
		return Stades.build_mesh(t)
	if t.has("glb"):
		return BibleGlb.build_mesh(id, material, details, variant, perso)
	if t.has("boutique_eco"):
		CommercesTypes.build(k, id, t)
		k.fit_xz(w, d)
		return k.to_mesh(material)
	if t.has("prod"):
		ProductionTypes.build(k, id, t)
		k.fit_xz(w, d)
		return k.to_mesh(material)
	if t.has("arch"):
		StyleBuilder.build(k, t)
		k.fit_xz(w, d)
		return k.to_mesh(material)
	match id:
		"maison":
			k.plate(0, 0, w, d, GRASS)
			k.box(0, 0, -1.0, 8.0, 5.6, 8.0, WALL)
			k.gable(0, 5.6, -1.0, 8.8, 8.8, 3.2, ROOF_TILE)
			k.box(0, 0, -5.0, 1.1, 2.2, 0.2, DOOR)
			k.windows_row(0, -5.0, 7.0, 3.3, 3, 1.1, 1.2, GLASS)
			k.windows_row(-2.5, -5.0, 2.0, 0.9, 1, 1.1, 1.2, GLASS)
			k.windows_row(2.5, -5.0, 2.0, 0.9, 1, 1.1, 1.2, GLASS)
			k.box(3.0, 5.6, 1.0, 0.7, 2.6, 0.7, Color("8c4a3a"))
			k.tree(-3.2, 4.4, 0.8)
			k.box(0, 0, 5.9, w, 0.9, 0.2, Color("9c6b45"))
		"villa":
			k.plate(0, 0, w, d, GRASS)
			k.box(-1.5, 0, -2.0, 11.0, 6.0, 9.0, WALL_WARM)
			k.box(-1.5, 6.0, -2.0, 11.6, 0.4, 9.6, Color("e9e2d4"))
			k.box(5.5, 0, -4.0, 4.4, 3.0, 6.0, Color("e7dccb"))
			k.box(5.5, 0, -7.05, 3.2, 2.4, 0.1, Color("9aa0a6"))
			k.windows_row(-1.5, -6.5, 10.0, 3.4, 4, 1.6, 1.6, GLASS)
			k.windows_row(-1.5, -6.5, 10.0, 0.6, 2, 2.4, 2.0, GLASS)
			k.plate(-1.0, 5.0, 8.0, 4.0, CONCRETE, 0.0, 0.12)
			k.plate(-1.0, 5.0, 7.0, 3.0, Color("4fb3d9"), 0.0, 0.16)
			k.tree(6.0, 5.5, 1.0)
			k.tree(-6.5, 6.0, 0.8)
		"immeuble":
			k.box(0, 0, 0, 16.0, 13.0, 12.0, Color("e8e3d9"))
			k.window_bands(0, 0, 16.0, 12.0, 0.0, 4, 3.2, GLASS)
			k.box(0, 13.0, 0, 16.4, 0.5, 12.4, Color("d0c8b8"))
			k.box(0, 0, -6.1, 2.4, 2.6, 0.3, DOOR)
			k.box(4.0, 13.5, 2.0, 3.0, 1.6, 2.5, CONCRETE)
		"tour_habitation":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(0, 0, 0, 20.0, 4.5, 20.0, Color("c9c2b6"))
			k.box(0, 0, -10.05, 6.0, 3.0, 0.2, GLASS)
			k.box(0, 4.5, 0, 16.0, 36.0, 16.0, Color("ece7de"))
			k.window_bands(0, 0, 16.0, 16.0, 4.5, 12, 3.0, GLASS)
			k.box(0, 40.5, 0, 16.4, 0.6, 16.4, Color("bdb5a6"))
			k.box(2.0, 41.1, 2.0, 4.0, 2.5, 4.0, CONCRETE)
		"boulangerie":
			k.box(0, 0, 1.0, 8.0, 7.0, 10.0, Color("f4e3c1"))
			k.gable(0, 7.0, 1.0, 8.6, 10.6, 2.6, Color("8c4a3a"), false)
			k.box(0, 0.4, -4.05, 6.0, 2.4, 0.2, GLASS)
			k.box(0, 3.0, -4.6, 7.4, 0.25, 1.4, Color("e4572e"))
			k.windows_row(0, -4.0, 6.0, 4.4, 2, 1.2, 1.4, GLASS)
			k.box(0, 3.4, -4.15, 4.0, 0.7, 0.2, Color("fff3b0"))
		"superette":
			k.plate(0, 0, w, d, ASPHALT)
			k.box(0, 0, 2.0, 15.0, 5.0, 11.0, Color("b5d3e7"))
			k.box(0, 0.3, -3.55, 11.0, 3.0, 0.2, GLASS)
			k.box(0, 3.6, -3.7, 15.4, 1.0, 0.5, Color("76b041"))
			k.box(0, 5.0, 2.0, 15.4, 0.4, 11.4, Color("9aa0a6"))
			for i in 4:
				k.plate(-6.0 + i * 4.0, -5.5, 0.15, 4.0, LINE, 0.08, 0.04)
		"supermarche":
			k.plate(0, 0, w, d, ASPHALT)
			k.box(0, 0, 8.0, 40.0, 8.0, 28.0, Color("e9edf1"))
			k.box(0, 8.0, 8.0, 40.4, 0.6, 28.4, Color("9aa0a6"))
			k.box(0, 0.3, -6.05, 14.0, 4.0, 0.2, GLASS)
			k.box(0, 4.6, -6.4, 18.0, 0.6, 3.0, Color("e63946"))
			k.box(0, 8.6, -5.8, 12.0, 2.2, 0.4, Color("e63946"))
			for row in 2:
				for i in 12:
					k.plate(-19.0 + i * 3.4, -14.0 + row * 7.5, 0.15, 4.8, LINE, 0.08, 0.04)
			for i in 4:
				k.tree(-18.0 + i * 12.0, -21.0, 0.8)
		"bureaux":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(0, 0, 1.0, 20.0, 22.0, 15.0, Color("8fb8d8"))
			for i in 6:
				k.box(0, 3.6 * i + 3.2, 1.0, 20.2, 0.5, 15.2, Color("e7eef3"))
			k.box(0, 22.0, 1.0, 20.4, 0.6, 15.4, Color("cfd8df"))
			k.box(0, 0, -6.6, 5.0, 3.0, 0.2, Color("1d2d3c"))
			k.box(-5.0, 22.6, 3.0, 4.0, 2.0, 4.0, CONCRETE)
		"atelier":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(0, 0, 2.0, 14.0, 6.0, 15.0, Color("c9b38a"))
			k.gable(0, 6.0, 2.0, 14.6, 15.6, 2.0, ROOF_DARK, false)
			k.box(-2.0, 0, -5.55, 5.0, 4.4, 0.2, Color("7d7f85"))
			k.box(4.0, 0, -5.55, 1.1, 2.2, 0.2, DOOR)
			k.windows_row(0, -5.5, 12.0, 4.6, 4, 1.6, 0.8, GLASS)
		"entrepot":
			k.plate(0, 0, w, d, ASPHALT)
			k.box(0, 0, 4.0, 30.0, 10.0, 32.0, Color("b8a27a"))
			k.gable(0, 10.0, 4.0, 30.6, 32.6, 2.2, Color("8a8d93"), false)
			for i in 4:
				k.box(-10.5 + i * 7.0, 0, -12.05, 4.5, 4.5, 0.2, Color("6c7077"))
			k.box(0, 0, -12.6, 30.0, 1.2, 1.0, CONCRETE)
			for i in 6:
				k.plate(-12.5 + i * 5.0, -17.0, 0.15, 6.0, LINE, 0.08, 0.04)
		"usine":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(-3.0, 0, 2.0, 36.0, 9.0, 28.0, Color("c2ab84"))
			for i in 6:
				var sx := -3.0 - 18.0 + 3.0 + i * 6.0
				k.gable(sx, 9.0, 2.0, 6.0, 28.4, 3.0, Color("7d7f85"), false)
			k.windows_row(-3.0, -12.0, 34.0, 5.0, 8, 2.6, 1.6, GLASS)
			k.box(-3.0, 0, -12.05, 6.0, 5.0, 0.2, Color("55585e"))
			k.cylinder(18.5, 0, 12.0, 1.6, 1.2, 30.0, 8, Color("b0413e"))
			k.cylinder(18.5, 26.0, 12.0, 1.3, 1.3, 1.5, 8, Color("eeeeee"))
			k.cylinder(18.5, 0, -6.0, 2.6, 2.6, 12.0, 10, Color("d9d9d9"))
			k.cylinder(18.5, 12.0, -6.0, 2.6, 0.0, 1.5, 10, Color("a5a5a5"))
		"ferme":
			k.plate(0, 0, w, d, Color("a8915e"))
			k.box(-7.0, 0, -4.0, 12.0, 6.0, 8.0, Color("efe2c8"))
			k.gable(-7.0, 6.0, -4.0, 12.8, 8.8, 3.6, ROOF_TILE)
			k.box(-7.0, 0, -8.05, 1.1, 2.2, 0.2, DOOR)
			k.windows_row(-7.0, -8.0, 10.0, 3.0, 3, 1.0, 1.2, GLASS)
			k.box(6.0, 0, 3.0, 14.0, 7.0, 16.0, Color("9b2c2c"))
			k.gable(6.0, 7.0, 3.0, 14.8, 16.8, 4.5, Color("4a4e55"), false)
			k.box(6.0, 0, -5.05, 5.0, 5.0, 0.2, Color("f2f2f2"))
			k.cylinder(-10.0, 0, 8.0, 2.4, 2.4, 13.0, 10, Color("c9ccd1"))
			k.cylinder(-10.0, 13.0, 8.0, 2.5, 0.0, 2.6, 10, Color("8a8d93"))
		"mairie":
			k.plate(0, 0, w, d, Color("d8d2c4"))
			k.box(0, 0, 1.0, 24.0, 10.0, 14.0, Color("efe6d4"))
			k.gable(0, 10.0, 1.0, 24.8, 14.8, 4.0, Color("4f5d75"))
			k.windows_row(0, -6.0, 22.0, 1.4, 8, 1.4, 2.4, GLASS)
			k.windows_row(0, -6.0, 22.0, 5.8, 8, 1.4, 2.4, GLASS)
			k.box(0, 0, -6.4, 4.0, 4.0, 1.0, Color("e2d6bf"))
			k.box(0, 0, -6.95, 2.0, 3.2, 0.2, DOOR)
			k.box(0, 10.0, -4.0, 4.0, 8.0, 4.0, Color("efe6d4"))
			k.cylinder(0, 15.0, -6.1, 1.2, 1.2, 0.1, 12, Color("fdfdfd"))
			k.pyramid(0, 18.0, -4.0, 4.6, 4.6, 4.0, Color("4f5d75"))
			k.box(0, 0, -7.5, 0.2, 9.0, 0.2, Color("d9d9d9"))
			k.box(0.8, 7.5, -7.5, 1.4, 1.0, 0.05, Color("2a6fdb"))
		"ecole":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(-4.0, 0, -8.0, 30.0, 8.0, 12.0, Color("f6d7a7"))
			k.box(-4.0, 8.0, -8.0, 30.4, 0.5, 12.4, Color("c96f4a"))
			k.box(14.0, 0, 3.0, 10.0, 8.0, 24.0, Color("f6d7a7"))
			k.box(14.0, 8.0, 3.0, 10.4, 0.5, 24.4, Color("c96f4a"))
			k.window_bands(-4.0, -8.0, 30.0, 12.0, 0.0, 2, 4.0, GLASS)
			k.window_bands(14.0, 3.0, 10.0, 24.0, 0.0, 2, 4.0, GLASS)
			k.box(-4.0, 0, -14.1, 3.0, 2.6, 0.3, Color("2a6fdb"))
			k.plate(-5.0, 7.0, 22.0, 14.0, Color("c96f4a"), 0.0, 0.1)
			k.tree(-13.0, 11.0, 1.0)
			k.tree(2.0, 11.0, 0.9)
		"pompiers":
			k.plate(0, 0, w, d, ASPHALT)
			k.box(-2.0, 0, 1.5, 18.0, 7.0, 14.0, Color("e9e2d4"))
			k.box(-2.0, 7.0, 1.5, 18.4, 0.5, 14.4, Color("b23a2e"))
			for i in 3:
				k.box(-7.5 + i * 5.5, 0, -5.55, 4.2, 4.6, 0.2, Color("c0392b"))
			k.box(8.5, 0, 4.0, 3.5, 16.0, 3.5, Color("c0392b"))
			k.box(8.5, 16.0, 4.0, 4.0, 0.5, 4.0, Color("8e2a20"))
		"police":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(0, 0, 1.0, 16.0, 7.5, 12.0, Color("dfe6ee"))
			k.box(0, 7.5, 1.0, 16.4, 0.5, 12.4, Color("1f3b73"))
			k.window_bands(0, 1.0, 16.0, 12.0, 0.0, 2, 3.7, GLASS)
			k.box(0, 0, -5.1, 2.6, 2.8, 0.3, Color("1f3b73"))
			k.box(0, 5.5, -5.15, 5.0, 1.0, 0.2, Color("2a6fdb"))
		"hopital":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(0, 0, 4.0, 40.0, 7.0, 24.0, Color("eef2f5"))
			k.window_bands(0, 4.0, 40.0, 24.0, 0.0, 2, 3.5, Color("6d97b8"))
			k.box(0, 7.0, 6.0, 24.0, 18.0, 16.0, Color("f7f9fb"))
			k.window_bands(0, 6.0, 24.0, 16.0, 7.0, 5, 3.6, Color("6d97b8"))
			k.box(0, 25.0, 6.0, 24.4, 0.5, 16.4, CONCRETE)
			k.cylinder(0, 25.5, 6.0, 6.0, 6.0, 0.15, 12, Color("4a4e55"))
			k.box(0, 25.7, 6.0, 1.0, 0.05, 6.0, LINE)
			k.box(0, 25.7, 6.0, 4.0, 0.05, 1.0, LINE)
			k.box(0, 0, -8.6, 10.0, 4.0, 3.0, Color("d6e4f0"))
			k.box(0, 4.5, -10.15, 3.0, 3.0, 0.2, Color("e63946"))
			k.box(0, 5.5, -10.25, 1.0, 1.0, 0.2, LINE)
		"chateau_eau":
			k.plate(0, 0, w, d, Color("8c8f86"))
			k.cylinder(0, 0, 0, 1.6, 1.4, 18.0, 8, CONCRETE)
			k.cylinder(0, 17.0, 0, 2.0, 5.0, 3.0, 12, Color("cfd3d6"))
			k.cylinder(0, 20.0, 0, 5.0, 5.0, 4.0, 12, Color("dfe3e6"))
			k.cylinder(0, 24.0, 0, 5.2, 0.6, 1.4, 12, Color("9aa3a8"))
		"parc":
			k.plate(0, 0, w, d, Color("7cbf5a"))
			k.plate(0, 0, 2.6, d, Color("e3d3a8"), 0.06, 0.06)
			k.plate(0, 0, w, 2.6, Color("e3d3a8"), 0.06, 0.06)
			k.cylinder(0, 0.06, 0, 3.2, 3.2, 0.6, 12, Color("cfc7b5"))
			k.cylinder(0, 0.1, 0, 2.7, 2.7, 0.6, 12, Color("4fb3d9"))
			k.cylinder(0, 0.6, 0, 0.3, 0.2, 1.8, 6, Color("cfc7b5"))
			var spots := [Vector2(-9, -9), Vector2(-11, -4), Vector2(-6, -12), Vector2(9, -10), Vector2(11, -5),
				Vector2(-10, 9), Vector2(-5, 11), Vector2(8, 8), Vector2(12, 11), Vector2(5, 12), Vector2(-12, 12)]
			for i in spots.size():
				k.tree(spots[i].x, spots[i].y, 0.9 + 0.08 * (i % 4), Color("3f7d3a") if i % 2 == 0 else Color("5a9a48"))
			for b in [Vector2(-4, -2.2), Vector2(4, 2.2)]:
				k.box(b.x, 0, b.y, 1.8, 0.5, 0.5, Color("9c6b45"))
		"aire_jeux":
			k.plate(0, 0, w, d, Color("d8c39a"))
			k.plate(-3.0, 3.0, 5.0, 5.0, Color("f0dfa8"), 0.0, 0.15)
			k.box(3.5, 0, -2.5, 0.25, 2.6, 0.25, Color("e63946"))
			k.box(6.0, 0, -2.5, 0.25, 2.6, 0.25, Color("e63946"))
			k.box(4.75, 2.5, -2.5, 2.8, 0.2, 0.2, Color("e63946"))
			k.box(4.75, 0.6, -2.5, 0.8, 0.08, 0.4, Color("2a6fdb"))
			k.box(-3.5, 0, -3.5, 2.0, 2.0, 2.0, Color("f2c14e"))
			k.box(-3.5, 2.0, -3.5, 2.2, 0.15, 2.2, Color("2a9d8f"))
			k.box(-1.0, 0, -3.5, 3.2, 0.12, 1.0, Color("2a6fdb"))
			k.tree(5.0, 5.0, 0.8)
		"cafe":
			k.box(0, 0, 2.0, 12.0, 4.5, 10.0, Color("f4e9d8"))
			k.box(0, 4.5, 2.0, 12.4, 0.4, 10.4, Color("6b4a33"))
			k.box(0, 0.4, -3.05, 8.0, 2.8, 0.2, GLASS)
			k.box(0, 3.2, -3.6, 11.0, 0.2, 1.2, Color("2a9d8f"))
			k.plate(0, -5.0, 12.0, 4.0, Color("c9a27e"), 0.0, 0.1)
			for x in [-4.0, 0.0, 4.0]:
				k.cylinder(x, 0.1, -5.0, 0.05, 0.05, 2.2, 4, Color("eeeeee"))
				k.cylinder(x, 2.2, -5.0, 1.4, 0.0, 0.5, 8, Color("e4572e"))
				k.cylinder(x, 0.1, -5.0, 0.5, 0.5, 0.75, 6, Color("8c6b4a"))
		"cinema":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(0, 0, 3.0, 24.0, 12.0, 26.0, Color("3d3a4b"))
			k.box(0, 12.0, 3.0, 24.4, 0.5, 26.4, Color("2b2836"))
			k.box(0, 0, -10.05, 12.0, 3.5, 0.2, GLASS)
			k.box(0, 3.8, -10.6, 14.0, 0.3, 1.2, Color("f2c14e"))
			k.box(0, 6.0, -10.2, 16.0, 4.0, 0.4, Color("e63946"))
			k.box(0, 7.2, -10.45, 12.0, 1.6, 0.1, Color("fff3b0"))
		"foot":
			k.plate(0, 4.0, w, d - 8.0, Color("4f9a3a"))
			for i in 7:
				k.plate(0, 4.0 - 45.0 + i * 15.0, 68.0, 7.5, Color("5aa845"), 0.0, 0.1)
			var fz := 4.0
			k.plate(0, fz - 52.5, 68.0, 0.12, LINE, 0.0, 0.14)
			k.plate(0, fz + 52.5, 68.0, 0.12, LINE, 0.0, 0.14)
			k.plate(-34.0, fz, 0.12, 105.0, LINE, 0.0, 0.14)
			k.plate(34.0, fz, 0.12, 105.0, LINE, 0.0, 0.14)
			k.plate(0, fz, 68.0, 0.12, LINE, 0.0, 0.14)
			k.cylinder(0, 0.0, fz, 9.15, 9.15, 0.13, 20, LINE)
			k.cylinder(0, 0.0, fz, 9.0, 9.0, 0.135, 20, Color("4f9a3a"))
			for side in [-1.0, 1.0]:
				var gz: float = fz + side * 52.5
				k.plate(0, gz - side * 8.25, 40.3, 0.12, LINE, 0.0, 0.14)
				k.plate(-20.15, gz - side * 8.25 + side * 0.0, 0.12, 16.5, LINE, 0.0, 0.14)
				k.plate(20.15, gz - side * 8.25, 0.12, 16.5, LINE, 0.0, 0.14)
				k.box(-3.66, 0, gz + side * 0.6, 0.15, 2.44, 0.15, LINE)
				k.box(3.66, 0, gz + side * 0.6, 0.15, 2.44, 0.15, LINE)
				k.box(0, 2.3, gz + side * 0.6, 7.5, 0.15, 0.15, LINE)
			# Tribune le long de la touche Est, accès et parking côté façade (−Z).
			for step in 5:
				k.box(36.0, 0, fz, 3.6 - step * 0.7, 0.8 + step * 0.7, 50.0, Color("9aa3ad").lightened(step * 0.04))
			k.box(36.6, 4.2, fz, 2.6, 0.2, 52.0, Color("1f3b73"))
			k.plate(0, -53.5, w, 8.0, ASPHALT)
		"tennis":
			k.plate(0, 0, w, d, Color("4f9a3a"))
			k.plate(0, 0, 16.0, 34.0, Color("c46a3b"), 0.0, 0.1)
			k.plate(0, -11.885, 10.97, 0.08, LINE, 0.0, 0.12)
			k.plate(0, 11.885, 10.97, 0.08, LINE, 0.0, 0.12)
			k.plate(-5.485, 0, 0.08, 23.77, LINE, 0.0, 0.12)
			k.plate(5.485, 0, 0.08, 23.77, LINE, 0.0, 0.12)
			k.plate(-4.115, 0, 0.08, 23.77, LINE, 0.0, 0.12)
			k.plate(4.115, 0, 0.08, 23.77, LINE, 0.0, 0.12)
			k.plate(0, -6.4, 8.23, 0.08, LINE, 0.0, 0.12)
			k.plate(0, 6.4, 8.23, 0.08, LINE, 0.0, 0.12)
			k.plate(0, 0, 0.08, 12.8, LINE, 0.0, 0.12)
			k.box(0, 0, 0, 12.8, 0.95, 0.06, Color("eeeeee"))
			for p in [Vector2(-8, -17), Vector2(8, -17), Vector2(-8, 17), Vector2(8, 17)]:
				k.box(p.x, 0, p.y, 0.15, 3.5, 0.15, Color("3a5a40"))
			k.box(0, 3.0, -17.0, 16.0, 0.5, 0.06, Color("3a5a40"))
			k.box(0, 3.0, 17.0, 16.0, 0.5, 0.06, Color("3a5a40"))
		"basket":
			k.plate(0, 0, w, d, CONCRETE)
			k.plate(0, 0, 15.0, 28.0, Color("2e6f9e"), 0.0, 0.1)
			k.plate(0, 0, 15.0, 0.08, LINE, 0.0, 0.12)
			k.cylinder(0, 0.0, 0, 1.8, 1.8, 0.12, 14, LINE)
			k.cylinder(0, 0.0, 0, 1.7, 1.7, 0.125, 14, Color("2e6f9e"))
			for side in [-1.0, 1.0]:
				k.plate(0, side * 11.1, 4.9, 5.8, Color("c46a3b"), 0.0, 0.12)
				k.box(0, 0, side * 14.6, 0.2, 3.05, 0.2, Color("888888"))
				k.box(0, 2.9, side * 14.0, 1.8, 1.05, 0.08, LINE)
		"gymnase":
			k.plate(0, 0, w, d, CONCRETE)
			k.box(0, 0, 2.0, 32.0, 9.0, 24.0, Color("d8dee6"))
			k.gable(0, 9.0, 2.0, 32.6, 24.6, 2.0, Color("3e7cb1"))
			k.box(0, 6.0, 2.0, 32.2, 1.6, 24.2, GLASS)
			k.box(0, 0, -10.05, 4.0, 3.0, 0.2, Color("1d2d3c"))
			k.box(-10.0, 0, -11.0, 8.0, 3.5, 2.0, Color("c0c7cf"))
		"piscine":
			k.plate(0, 0, w, d, Color("e6e1d6"))
			k.plate(-4.0, 3.0, 25.0, 12.5, Color("2b9fd9"), 0.0, 0.12)
			for i in 5:
				k.plate(-4.0, 3.0 - 5.0 + i * 2.5, 25.0, 0.1, LINE, 0.0, 0.14)
			k.box(0, 0, -9.0, 28.0, 4.0, 5.0, Color("f4e9d8"))
			k.box(0, 4.0, -9.0, 28.4, 0.3, 5.4, Color("2a9d8f"))
			k.box(0, 0, -11.55, 2.4, 2.6, 0.2, GLASS)
			k.box(12.5, 0, 3.0, 0.2, 4.0, 1.4, Color("cccccc"))
			k.box(13.4, 4.0, 3.0, 2.0, 0.12, 0.6, Color("2a6fdb"))
			k.tree(-15.0, 10.0, 0.8)
			k.tree(14.0, 10.0, 0.8)
		_:
			k.box(0, 0, 0, w * 0.8, 4.0, d * 0.8, WALL)
	k.fit_xz(w, d)
	return k.to_mesh(material)


## Hauteur indicative du modèle (pour cadrer la caméra, les étiquettes…).
## Nombre de variantes d'un type (1 = toujours le même modèle).
static func variants_of(id: String) -> int:
	var t := get_type(id)
	if t.has("glb"):
		return maxi(int(t.get("variantes", 1)), 1)
	return VARIANTES if t.has("arch") else 1


static func approx_height(id: String) -> float:
	var m := build_mesh(id)
	if m.get_surface_count() == 0:
		return 0.0
	return m.get_aabb().end.y
