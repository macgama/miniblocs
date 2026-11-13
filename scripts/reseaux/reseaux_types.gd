class_name ReseauxTypes
extends RefCounted
## Bâtiments des réseaux (catégorie « Réseaux » du panneau Construire) :
## centrales électriques, captages d'eau potable, châteaux d'eau, stations
## d'épuration. Même format que BuildingCatalog, plus un champ "reseau" :
## - "res" : "elec", "eau" ou "egout" (le réseau qu'il alimente) ;
## - "cap" : capacité (MW pour l'électricité, m³ par jour pour l'eau et les égouts) ;
## - "stock" : réserve (m³) d'un château d'eau (ceux des Services publics, voir CHATEAU) ;
## - "source" : d'où vient l'énergie : "combustible" (charbon, gaz, bois livrés
##   par camion), "soleil", "vent", "riviere", "uranium", "national", "rejet" ;
## - "pres_eau" : distance maximale (m) à une rivière ou un lac (captage, barrage) ;
## - "elec" : courant consommé à plein régime (MW) : pompes, aérateurs…
## Les chiffres sont des ordres de grandeur réels, à l'échelle d'une petite
## ville (une centrale au charbon de 20 MW brûle environ 190 t par jour).

const CATEGORY := "reseaux"
const ROAD := ["route"]
const RP := ["route", "chemin"]

const TYPES := {
	# --- Électricité ---------------------------------------------------------------------
	"centrale_charbon_locale": {"name": "Petite centrale au charbon", "w": 60, "d": 48, "access": ROAD, "emplois": 40, "cost": 25_000_000,
		"reseau": {"res": "elec", "cap": 20.0, "source": "combustible"},
		"prod": {"kind": "transformation", "in": {"charbon": 190.0}, "out": {}},
		"desc": "20 MW. Chaudière, cheminée et tas de charbon livré par camion (190 t par jour). Fumées polluantes."},
	"centrale_gaz": {"name": "Centrale au gaz (cycle combiné)", "w": 44, "d": 36, "access": ROAD, "emplois": 25, "cost": 40_000_000,
		"reseau": {"res": "elec", "cap": 60.0, "source": "combustible"},
		"prod": {"kind": "transformation", "in": {"gaz": 260.0}, "out": {}},
		"desc": "60 MW. Turbines à gaz et à vapeur. Le gaz arrive par camion-citerne (260 t par jour)."},
	"centrale_biomasse": {"name": "Centrale biomasse", "w": 36, "d": 30, "access": ROAD, "emplois": 20, "cost": 12_000_000,
		"reseau": {"res": "elec", "cap": 8.0, "source": "combustible"},
		"prod": {"kind": "transformation", "in": {"bois": 210.0}, "out": {}},
		"desc": "8 MW. Brûle du bois des forêts voisines (210 t par jour)."},
	"poste_national": {"name": "Raccordement au réseau national", "w": 40, "d": 30, "access": ROAD, "emplois": 3, "cost": 8_000_000,
		"reseau": {"res": "elec", "cap": 50.0, "source": "national"},
		"desc": "Poste électrique qui achète jusqu'à 50 MW au réseau voisin, cher (0,25 € le kWh). À moins de 300 m du bord de la carte."},
	# --- Eau potable ---------------------------------------------------------------------
	"captage_eau": {"name": "Captage et usine d'eau potable", "w": 34, "d": 26, "access": ROAD, "emplois": 8, "cost": 8_000_000,
		"reseau": {"res": "eau", "cap": 6000.0, "source": "riviere", "pres_eau": 80.0, "elec": 0.12},
		"desc": "6 000 m³ par jour (environ 18 000 habitants). Pompe dans une rivière ou un lac (80 m au plus), filtre et désinfecte. Prends l'eau en amont des rejets d'égouts !"},
	"forage_eau": {"name": "Forage et station de pompage", "w": 14, "d": 12, "access": RP, "emplois": 1, "cost": 1_500_000,
		"reseau": {"res": "eau", "cap": 1500.0, "source": "nappe", "elec": 0.04},
		"desc": "1 500 m³ par jour pompés dans la nappe, presque partout (moins dans le désert)."},
	# --- Égouts et épuration ---------------------------------------------------------------
	"station_epuration_locale": {"name": "Station d'épuration compacte", "w": 50, "d": 36, "access": ROAD, "emplois": 6, "cost": 10_000_000,
		"reseau": {"res": "egout", "cap": 3000.0, "source": "traitement", "elec": 0.15},
		"desc": "Traite 3 000 m³ d'eaux usées par jour (environ 10 000 habitants) avant de les rendre à la rivière."},
	"lagunage": {"name": "Lagunage", "w": 70, "d": 50, "access": RP, "emplois": 1, "cost": 1_800_000,
		"reseau": {"res": "egout", "cap": 400.0, "source": "traitement"},
		"desc": "Bassins où les eaux usées s'épurent toutes seules (400 m³ par jour, sans électricité). Pour un village."},
	"exutoire_egout": {"name": "Rejet d'égout sans traitement", "w": 8, "d": 8, "access": [], "emplois": 0, "cost": 60_000,
		"reseau": {"res": "egout", "cap": 1_000_000.0, "source": "rejet"},
		"desc": "Sortie d'égout dans la nature : pas cher, mais il pollue la rivière et rend malades ceux qui boivent en aval."},
}

const ORDER := ["centrale_charbon_locale", "centrale_gaz", "centrale_biomasse", "poste_national", "captage_eau", "forage_eau",
	"station_epuration_locale", "lagunage", "exutoire_egout"]

## Bâtiments de la bible Blender qui deviennent des bâtiments des réseaux
## (ils passent dans la catégorie Réseaux et ne poussent plus dans les zones).
## "achat" : combustible acheté sous contrat, payé par la ville (€ par kWh produit).
const BIBLE := {
	"centrale_charbon": {"res": "elec", "cap": 600.0, "source": "contrat", "achat": 0.05},
	"centrale_nucleaire": {"res": "elec", "cap": 2600.0, "source": "contrat", "achat": 0.012, "pres_eau": 300.0},
	"barrage_usine": {"res": "elec", "cap": 40.0, "source": "riviere", "pres_eau": 60.0},
	"eolienne": {"res": "elec", "cap": 3.0, "source": "vent"},
	"centrale_solaire": {"res": "elec", "cap": 2.0, "source": "soleil"},
	"station_epuration": {"res": "egout", "cap": 20000.0, "source": "traitement", "elec": 0.8},
	"chateau_eau_champignon": {"res": "eau", "cap": 0.0, "stock": 2500.0},
}
const BIBLE_DESC := {
	"centrale_charbon": "600 MW. Charbon acheté par contrat et livré par train (0,05 € par kWh, payé par la ville).",
	"centrale_nucleaire": "2 600 MW. Combustible sous contrat (0,012 € par kWh). Il faut de l'eau à moins de 300 m.",
	"barrage_usine": "40 MW au fil de l'eau : rivière à moins de 60 m.",
	"eolienne": "3 MW quand le vent souffle fort, rien par temps calme.",
	"centrale_solaire": "2 MW en plein soleil, moins sous les nuages, rien la nuit.",
	"station_epuration": "Traite 20 000 m³ d'eaux usées par jour (environ 70 000 habitants).",
	"chateau_eau_champignon": "Réserve de 2 500 m³ en hauteur.",
}


## Rend fonctionnels les modèles de la bible (appelé par BuildingCatalog.all_types).
static func adopter(all: Dictionary) -> void:
	for id in BIBLE:
		if not all.has(id):
			continue
		var t: Dictionary = all[id]
		t["reseau"] = BIBLE[id]
		t["cat"] = CATEGORY
		t.erase("zone")
		t["desc"] = "%s %s" % [BIBLE_DESC.get(id, ""), String(t.get("desc", ""))]

## Tronçons que le joueur pose (prix par mètre, entretien par mètre et par an).
const TRONCONS := {
	"ligne_ht": {"name": "Ligne haute tension", "res": "elec", "prix_m": 400, "entretien_m": 6.0, "pas": 300.0, "haut": 28.0,
		"desc": "Pylônes de 28 m tous les 300 m : relie une centrale lointaine à la ville."},
	"ligne_mt": {"name": "Ligne moyenne tension", "res": "elec", "prix_m": 120, "entretien_m": 2.0, "pas": 60.0, "haut": 10.0,
		"desc": "Poteaux de 10 m tous les 60 m : dessert un hameau ou une ferme hors des routes."},
	"conduite_eau": {"name": "Conduite d'eau potable", "res": "eau", "prix_m": 250, "entretien_m": 3.0,
		"desc": "Canalisation enterrée (visible avec le calque Eau) : relie un captage éloigné au réseau des routes."},
	"collecteur": {"name": "Collecteur d'égout", "res": "egout", "prix_m": 450, "entretien_m": 4.0,
		"desc": "Grand égout enterré : emmène les eaux usées jusqu'à la station d'épuration."},
}

const RES_NAMES := {"elec": "Électricité", "eau": "Eau potable", "egout": "Égouts"}
const UNITES := {"elec": "MW", "eau": "m³/j", "egout": "m³/j"}
const COULEURS := {"elec": Color("ffd166"), "eau": Color("4cc9f0"), "egout": Color("a47148")}


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		out[id] = t
	return out


## Château d'eau : ceux du catalogue (Services publics) et de la bible servent de réserve.
const CHATEAU := {"res": "eau", "cap": 0.0, "stock": 1500.0}


static func info(type_id: String) -> Dictionary:
	var t := BuildingCatalog.get_type(type_id)
	if t.has("reseau"):
		return t.reseau
	if type_id == "chateau_eau" or String(t.get("role", "")) == "chateau_eau" or String(t.get("arch", "")) == "chateau_eau":
		return CHATEAU
	return {}


static func troncon(id: String) -> Dictionary:
	return TRONCONS.get(id, {})


static func troncons_de(res: String) -> Array[String]:
	var out: Array[String] = []
	for id in TRONCONS:
		if String(TRONCONS[id].res) == res:
			out.append(id)
	return out


## Prix d'un tronçon (avec le multiplicateur de la partie).
static func prix_troncon(id: String, longueur: float) -> int:
	return ReglagesPartie.prix(roundi(float(troncon(id).get("prix_m", 0)) * longueur))


# --- Modèles low-poly --------------------------------------------------------------------

const BETON := Color("b9b6ae")
const BETON_C := Color("d8d4cc")
const TOLE := Color("8d99ae")
const BRIQUE := Color("a4543a")
const ACIER := Color("5c677d")
const BLANC := Color("eef0ee")
const HERBE := Color("6aa84f")
const GRAVIER := Color("c2b8a3")
const EAU := Color("3f88c5")
const EAU_SALE := Color("6b7f4a")
const PANNEAU := Color("1f3b5a")
const CHARBON := Color("2b2d30")
const BOIS := Color("8c5a3c")
const VITRE := Color("33495e")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"centrale_charbon_locale":
			k.plate(0, 0, w, d, GRAVIER)
			k.box(-8, 0, -4, 26, 22, 20, BRIQUE)
			k.gable(-8, 22, -4, 26.6, 20.6, 4.0, TOLE)
			k.windows_row(-8, -14.0, 22.0, 8.0, 6, 1.6, 3.0, VITRE)
			k.box(12, 0, -6, 12, 14, 14, BETON)
			k.cylinder(18, 0, 12, 2.6, 1.8, 70.0, 10, BETON_C)
			k.cylinder(18, 66, 12, 1.9, 1.9, 4.0, 10, Color("a33b2f"))
			for i in 3:
				k.box(-16 + i * 9, 0, 16, 8, 3.0 + i * 0.6, 8, CHARBON)
			k.box(4, 8, 6, 2, 2, 18, ACIER)
		"centrale_gaz":
			k.plate(0, 0, w, d, GRAVIER)
			k.box(-6, 0, -2, 24, 14, 16, BLANC)
			k.box(-6, 14, -2, 24.4, 0.6, 16.4, TOLE)
			k.windows_row(-6, -10.0, 20.0, 6.0, 5, 2.0, 2.2, VITRE)
			for x in [10.0, 15.0]:
				k.cylinder(x, 0, 6, 1.6, 1.4, 34.0, 8, BETON_C)
			k.box(12, 0, -8, 10, 10, 8, ACIER)
			for i in 3:
				k.cylinder(-14 + i * 7, 0, 12, 2.6, 2.6, 4.0, 10, BLANC)
		"centrale_biomasse":
			k.plate(0, 0, w, d, GRAVIER)
			k.box(-4, 0, -2, 18, 16, 14, BOIS)
			k.gable(-4, 16, -2, 18.6, 14.6, 3.0, TOLE)
			k.cylinder(9, 0, 6, 1.4, 1.0, 36.0, 8, BETON_C)
			for i in 4:
				for j in 2:
					k.box(-12 + i * 3, j * 0.9, 11, 2.6, 0.9, 6.0, Color("a0704a"))
		"poste_national":
			k.plate(0, 0, w, d, GRAVIER)
			for i in 3:
				k.box(-10 + i * 10, 0, 2, 4, 4, 6, ACIER)
				k.cylinder(-10 + i * 10, 4, 2, 0.4, 0.3, 4.0, 6, BLANC)
			for x in [-16.0, 16.0]:
				k.box(x, 0, 8, 0.6, 14, 0.6, ACIER)
				k.box(x, 13, 8, 0.4, 0.4, 12, ACIER)
			k.box(0, 0, -10, 10, 4, 6, BETON_C)
			k.gable(0, 4, -10, 10.4, 6.4, 1.4, ACIER)
		"captage_eau":
			k.plate(0, 0, w, d, HERBE)
			k.box(-6, 0, -4, 18, 7, 12, BETON_C)
			k.gable(-6, 7, -4, 18.6, 12.6, 2.6, TOLE)
			k.windows_row(-6, -10.0, 14.0, 3.0, 4, 1.6, 1.6, VITRE)
			for i in 3:
				k.box(8 + (i % 2) * 7, 0, -6 + (i / 2) * 10, 6, 1.2, 8, EAU)
			k.cylinder(10, 0, 8, 3.2, 3.2, 6.0, 12, BLANC)
		"forage_eau":
			k.plate(0, 0, w, d, GRAVIER)
			k.box(0, 0, 0, 6, 3.2, 5, BETON_C)
			k.gable(0, 3.2, 0, 6.4, 5.4, 1.2, TOLE)
			k.box(0, 0, -4, 0.9, 2.2, 0.2, Color("4a4e69"))
			k.cylinder(4.5, 0, 3.5, 0.6, 0.6, 1.4, 8, ACIER)
		"station_epuration_locale":
			k.plate(0, 0, w, d, HERBE)
			for c in [[-12.0, 6.0], [4.0, 6.0]]:
				k.cylinder(c[0], 0, c[1], 7.0, 7.0, 2.2, 16, BETON_C)
				k.cylinder(c[0], 2.1, c[1], 6.4, 6.4, 0.2, 16, EAU_SALE)
			k.box(16, 0, 6, 10, 2.0, 14, BETON_C)
			k.box(16, 1.9, 6, 9, 0.2, 13, EAU)
			k.box(-6, 0, -12, 16, 5, 8, BETON_C)
			k.gable(-6, 5, -12, 16.4, 8.4, 1.6, TOLE)
		"lagunage":
			k.plate(0, 0, w, d, HERBE)
			for i in 3:
				k.box(-w * 0.33 + i * w * 0.33, 0.05, 2, w * 0.3, 0.2, d * 0.7, EAU_SALE if i == 0 else EAU)
			k.box(-w * 0.4, 0, -d * 0.45, 4, 2.2, 3, BETON_C)
			for x in [-30.0, 0.0, 30.0]:
				k.tree(x, -d * 0.45, 1.0)
		"exutoire_egout":
			k.plate(0, 0, w, d, GRAVIER)
			k.box(0, 0, 0, 3.0, 1.6, 2.0, BETON)
			k.cylinder(0, 0.2, -1.2, 0.7, 0.7, 0.3, 10, CHARBON)
			k.box(0, 0.02, -3, 2.0, 0.06, 3.0, EAU_SALE)
		_:
			k.box(0, 0, 0, w * 0.6, 5, d * 0.6, BETON)
