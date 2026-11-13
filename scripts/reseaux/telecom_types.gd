class_name TelecomTypes
extends RefCounted
## Bâtiments du réseau internet et téléphone (catégorie « Services publics »
## du panneau Construire) : antennes relais 2G, 4G, 5G, centraux téléphoniques
## et nœuds de la fibre.
##
## Même format que BuildingCatalog, plus un champ "telecom" :
## - antenne : "em" = émetteurs [{gen, portee (m), cap (abonnés), debit (Mb/s)}].
##   Les portées sont des ordres de grandeur réels : un pylône 2G (900 MHz)
##   porte à 5-10 km à la campagne, la 4G à 2-3 km, la 5G (3,5 GHz) à 500 m
##   en ville. La capacité est partagée : trop d'abonnés, le débit baisse.
## - central : point de départ du cuivre (téléphone fixe et ADSL, desservi le
##   long des routes) et de la fibre ("lignes" = lignes fibre qu'il alimente).
## - noeud_fibre : armoire qui alimente seulement la fibre (lignes).

const RP := ["route", "chemin"]
const ROAD := ["route"]

const GENS := {
	"2g": {"name": "2G (GSM)", "color": Color("e9c46a"), "rang": 1},
	"4g": {"name": "4G", "color": Color("4ea8de"), "rang": 2},
	"5g": {"name": "5G", "color": Color("b5179e"), "rang": 3},
}

const TYPES := {
	"pylone_2g": {"name": "Pylône 2G (GSM)", "w": 8, "d": 8, "access": RP, "cost": 180_000, "era": "moderne",
		"telecom": {"kind": "antenne", "h": 40.0, "em": [{"gen": "2g", "portee": 7000.0, "cap": 400.0, "debit": 0.2}]},
		"desc": "Grand pylône en treillis de 40 m. Téléphone mobile et SMS jusqu'à 7 km : idéal pour couvrir la campagne."},
	"pylone_4g": {"name": "Pylône 4G", "w": 8, "d": 8, "access": RP, "cost": 260_000, "era": "contemporain",
		"telecom": {"kind": "antenne", "h": 32.0, "em": [{"gen": "4g", "portee": 2500.0, "cap": 1500.0, "debit": 40.0},
			{"gen": "2g", "portee": 5000.0, "cap": 300.0, "debit": 0.2}]},
		"desc": "Pylône de 32 m. Internet mobile (40 Mb/s) jusqu'à 2,5 km, et la 2G plus loin."},
	"pylone_5g": {"name": "Pylône 4G + 5G", "w": 8, "d": 8, "access": RP, "cost": 420_000, "era": "contemporain",
		"telecom": {"kind": "antenne", "h": 32.0, "em": [{"gen": "5g", "portee": 900.0, "cap": 3000.0, "debit": 300.0},
			{"gen": "4g", "portee": 2500.0, "cap": 1500.0, "debit": 40.0}]},
		"desc": "Pylône équipé en 5G (300 Mb/s jusqu'à 900 m) et en 4G (2,5 km)."},
	"antenne_5g": {"name": "Petite antenne 5G", "w": 3, "d": 3, "access": RP, "cost": 90_000, "era": "contemporain",
		"telecom": {"kind": "antenne", "h": 12.0, "em": [{"gen": "5g", "portee": 450.0, "cap": 1500.0, "debit": 500.0}]},
		"desc": "Mât urbain de 12 m au bord d'une rue. Très haut débit sur 450 m, pour les quartiers denses."},
	"central_telephonique": {"name": "Central téléphonique", "w": 20, "d": 14, "access": ROAD, "cost": 900_000, "emplois": 6, "era": "moderne",
		"telecom": {"kind": "central", "lignes": 5000.0, "cuivre": 8000.0},
		"desc": "Téléphone fixe et ADSL par le cuivre, le long des routes (jusqu'à 5 km), et départ de la fibre (5 000 lignes)."},
	"noeud_fibre": {"name": "Nœud de raccordement optique", "w": 6, "d": 4, "access": RP, "cost": 220_000, "era": "contemporain",
		"telecom": {"kind": "noeud_fibre", "lignes": 2000.0},
		"desc": "Armoire de la fibre : alimente 2 000 lignes sur les câbles qui la touchent."},
}
const ORDER := ["pylone_2g", "pylone_4g", "pylone_5g", "antenne_5g", "central_telephonique", "noeud_fibre"]


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate(true)
		t["cat"] = "services"
		t["region"] = "monde"
		t["style"] = ""
		out[id] = t
	return out


static func spec_of(type_id: String) -> Dictionary:
	return BuildingCatalog.get_type(type_id).get("telecom", {})


# --- Modèles low-poly --------------------------------------------------------------------

const ACIER := Color("a9b0b8")
const ACIER_F := Color("6c757d")
const BLANC := Color("eef0f2")
const ROUGE := Color("c8553d")
const BETON := Color("b9b6ae")
const GRAVIER := Color("c2b8a3")
const GRILLAGE := Color("8d99ae")
const VERT_ARMOIRE := Color("52796f")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"pylone_2g", "pylone_4g", "pylone_5g":
			var h := float(t.telecom.h)
			k.plate(0, 0, w, d, GRAVIER)
			_fence(k, w - 0.4, d - 0.4)
			_lattice(k, h, 2.6, 0.7)
			# Bandes rouges et blanches en haut (balisage aérien).
			k.box(0, h - 4.0, 0, 1.0, 1.0, 1.0, ROUGE)
			k.box(0, h - 2.0, 0, 0.9, 1.0, 0.9, BLANC)
			var plates := 3
			for i in plates:
				var a := TAU * i / plates
				var px := cos(a) * 0.9
				var pz := sin(a) * 0.9
				k.box(px, h - 3.2, pz, 0.45, 2.4, 0.18, BLANC)
				if id == "pylone_5g":
					k.box(px * 0.9, h - 7.0, pz * 0.9, 0.5, 0.9, 0.5, Color("dee2e6"))
			if id == "pylone_2g":
				k.cylinder(0.9, h - 10.0, 0.0, 0.5, 0.5, 0.15, 10, Color("dee2e6"))
			k.cylinder(0, h, 0, 0.05, 0.05, 2.0, 4, ACIER_F)
			k.box(0, h + 2.0, 0, 0.25, 0.25, 0.25, Color("ff3b30"))
			# Abri technique au pied.
			k.box(2.2, 0, 2.2, 2.4, 2.6, 2.0, BETON)
			k.box(2.2, 2.6, 2.2, 2.6, 0.15, 2.2, ACIER_F)
		"antenne_5g":
			var h5 := float(t.telecom.h)
			k.plate(0, 0, w, d, BETON)
			k.cylinder(0, 0, 0, 0.35, 0.22, h5, 8, Color("ced4da"))
			for i in 3:
				var a5 := TAU * i / 3.0
				k.box(cos(a5) * 0.35, h5 - 2.2, sin(a5) * 0.35, 0.35, 1.6, 0.12, BLANC)
			k.box(0.9, 0, 0.9, 0.8, 1.4, 0.5, VERT_ARMOIRE)
		"central_telephonique":
			k.plate(0, 0, w, d, Color("9a9da1"))
			k.box(0, 0, 0, w - 4.0, 7.0, d - 4.0, Color("d8cfc0"))
			k.box(0, 7.0, 0, w - 3.6, 0.4, d - 3.6, Color("8d8d8d"))
			k.window_bands(0, 0, w - 4.0, d - 4.0, 1.4, 2, 3.2, Color("33495e"))
			k.box(0, 0, -(d - 4.0) / 2.0 - 0.05, 2.2, 2.4, 0.12, Color("6b4a33"))
			# Petite antenne et climatiseurs sur le toit.
			k.cylinder(-4.0, 7.4, 1.0, 0.12, 0.08, 6.0, 5, ACIER)
			for i in 3:
				k.box(2.0 + i * 1.8, 7.4, 1.5, 1.2, 0.8, 1.2, BLANC)
		"noeud_fibre":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 0, w - 1.6, 2.2, d - 1.6, VERT_ARMOIRE)
			k.box(0, 2.2, 0, w - 1.4, 0.12, d - 1.4, Color("354f52"))
			k.box(0, 0.9, -(d - 1.6) / 2.0 - 0.03, 1.6, 0.4, 0.05, Color("f2c14e"))
	k.fit_xz(w, d)


## Pylône en treillis : quatre montants qui se resserrent et des entretoises.
static func _lattice(k: BlocMesh, h: float, base: float, top: float) -> void:
	var steps := int(h / 4.0)
	for i in steps:
		var y0 := h * i / steps
		var y1 := h * (i + 1) / steps
		var s0 := lerpf(base, top, float(i) / steps)
		var s1 := lerpf(base, top, float(i + 1) / steps)
		var sm := (s0 + s1) * 0.5
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			k.box(c.x * sm * 0.5, y0, c.y * sm * 0.5, 0.16, y1 - y0, 0.16, ACIER)
		k.box(0, y1 - 0.1, -s1 * 0.5, s1, 0.1, 0.08, ACIER_F)
		k.box(0, y1 - 0.1, s1 * 0.5, s1, 0.1, 0.08, ACIER_F)
		k.box(-s1 * 0.5, y1 - 0.1, 0, 0.08, 0.1, s1, ACIER_F)
		k.box(s1 * 0.5, y1 - 0.1, 0, 0.08, 0.1, s1, ACIER_F)


static func _fence(k: BlocMesh, w: float, d: float) -> void:
	k.box(0, 0, -d / 2.0, w, 1.8, 0.05, GRILLAGE)
	k.box(0, 0, d / 2.0, w, 1.8, 0.05, GRILLAGE)
	k.box(-w / 2.0, 0, 0, 0.05, 1.8, d, GRILLAGE)
	k.box(w / 2.0, 0, 0, 0.05, 1.8, d, GRILLAGE)
