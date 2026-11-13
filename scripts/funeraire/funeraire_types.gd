class_name FuneraireTypes
extends RefCounted
## Bâtiments funéraires (catégorie « Funéraire » du panneau Construire) :
## cimetières de plusieurs styles, columbarium, crématorium et pompes funèbres.
##
## Même format que BuildingCatalog, plus un champ "funeraire" qui dit le rôle du
## bâtiment pour le système Funeraire :
## - "cimetiere" : tombes ("plan" : disposition des carrés, "stele" : style
##   des pierres tombales). Le nombre de places vient du plan (slots()).
## - "columbarium" : cases pour les urnes dans des murs, et un jardin du
##   souvenir où l'on disperse les cendres (places illimitées).
## - "crematorium" : "fours" fours, CREMATIONS_FOUR crémations par four et
##   par jour ; il a aussi son jardin du souvenir.
## - "pompes_funebres" : "corbillards" corbillards, une chambre funéraire de
##   "chambre" places (les défunts y attendent leurs obsèques).
## Chiffres : ordres de grandeur français (une tombe et son passage ≈ 4 m²,
## 600 à 900 crémations par an et par four).

const CATEGORY := "funeraire"
const ROAD := ["route"]
const ROAD_OR_PATH := ["route", "chemin"]
const CREMATIONS_FOUR := 4

## plan : marge (mur et bordure), entree (parvis côté porte), allee (largeur
## des allées), bloc [largeur, profondeur] d'un carré, pas [x, z] d'une tombe.
const TYPES := {
	"cimetiere_village": {"name": "Cimetière de village", "w": 44, "d": 40, "access": ROAD_OR_PATH, "emplois": 1, "cost": 350_000,
		"funeraire": {"role": "cimetiere", "stele": "dalle", "mur": "pierre",
			"plan": {"marge": 2.5, "entree": 4.0, "allee": 2.5, "bloc": [7.5, 10.0], "pas": [1.5, 2.5]}},
		"metiers": [["fossoyeur", 1]],
		"desc": "Mur de pierre, croix de l'allée, ifs et cyprès : %d tombes pour un village."},
	"cimetiere_communal": {"name": "Cimetière communal", "w": 120, "d": 100, "access": ROAD, "emplois": 4, "cost": 1_600_000,
		"funeraire": {"role": "cimetiere", "stele": "dalle", "mur": "enduit", "ossuaire": true,
			"plan": {"marge": 3.0, "entree": 8.0, "allee": 3.5, "bloc": [14.0, 16.8], "pas": [1.4, 2.4]}},
		"metiers": [["fossoyeur", 3], ["gardien_cimetiere", 1]],
		"desc": "Grand mur, allées gravillonnées, ossuaire et jardin du souvenir : %d tombes."},
	"cimetiere_paysager": {"name": "Cimetière paysager", "w": 200, "d": 160, "access": ROAD, "emplois": 8, "cost": 4_500_000,
		"funeraire": {"role": "cimetiere", "stele": "stele", "mur": "haie", "ossuaire": true, "jardin": true,
			"plan": {"marge": 4.0, "entree": 12.0, "allee": 6.0, "bloc": [20.0, 20.0], "pas": [1.6, 2.8]}},
		"metiers": [["fossoyeur", 5], ["jardinier", 2], ["gardien_cimetiere", 1]],
		"desc": "Un parc : pelouses, bosquets, étang et haies basses ; %d tombes et un jardin du souvenir."},
	"cimetiere_militaire": {"name": "Cimetière militaire", "w": 80, "d": 60, "access": ROAD, "emplois": 2, "cost": 900_000,
		"funeraire": {"role": "cimetiere", "stele": "blanche", "mur": "haie",
			"plan": {"marge": 3.0, "entree": 10.0, "allee": 4.0, "bloc": [18.0, 11.0], "pas": [1.2, 2.2]}},
		"metiers": [["jardinier", 1], ["gardien_cimetiere", 1]],
		"desc": "Pelouse rase, rangées de stèles blanches alignées et mât du souvenir : %d tombes."},
	"cimetiere_asie": {"name": "Cimetière d'Asie de l'Est", "w": 60, "d": 50, "access": ROAD_OR_PATH, "emplois": 1, "cost": 700_000,
		"funeraire": {"role": "cimetiere", "stele": "asie", "mur": "pierre", "cremation": 0.95,
			"plan": {"marge": 3.0, "entree": 6.0, "allee": 3.0, "bloc": [11.0, 9.6], "pas": [2.2, 3.2]}},
		"region": "asie_est",
		"metiers": [["fossoyeur", 1]],
		"desc": "Hautes stèles de pierre sombre sur socle, lanternes et bonsaïs : %d tombes familiales."},
	"cimetiere_musulman": {"name": "Cimetière musulman", "w": 50, "d": 40, "access": ROAD_OR_PATH, "emplois": 1, "cost": 400_000,
		"funeraire": {"role": "cimetiere", "stele": "simple", "mur": "enduit_blanc", "cremation": 0.0,
			"plan": {"marge": 2.5, "entree": 5.0, "allee": 3.0, "bloc": [10.0, 13.0], "pas": [1.4, 2.6]}},
		"region": "moyen_orient",
		"metiers": [["fossoyeur", 1]],
		"desc": "Tombes simples en pleine terre, petites stèles tournées vers La Mecque, palmiers : %d tombes."},
	"cimetiere_juif": {"name": "Cimetière juif", "w": 44, "d": 44, "access": ROAD_OR_PATH, "emplois": 1, "cost": 400_000,
		"funeraire": {"role": "cimetiere", "stele": "juive", "mur": "pierre", "cremation": 0.0,
			"plan": {"marge": 2.5, "entree": 5.0, "allee": 2.5, "bloc": [9.0, 12.0], "pas": [1.4, 2.4]}},
		"metiers": [["fossoyeur", 1]],
		"desc": "Stèles de pierre où l'on dépose de petits cailloux, maison de purification : %d tombes."},
	"columbarium": {"name": "Columbarium et jardin du souvenir", "w": 30, "d": 24, "access": ROAD_OR_PATH, "emplois": 0, "cost": 300_000,
		"funeraire": {"role": "columbarium", "jardin": true},
		"desc": "Murs de cases pour les urnes (%d cases) et pelouse où l'on disperse les cendres."},
	"crematorium": {"name": "Crématorium", "w": 44, "d": 32, "access": ROAD, "emplois": 6, "cost": 5_000_000,
		"funeraire": {"role": "crematorium", "fours": 2, "jardin": true},
		"metiers": [["operateur_crematorium", 3], ["conseiller_funeraire", 1], ["agent_public", 2]],
		"desc": "Salle de cérémonie, deux fours (environ 8 crémations par jour) et jardin du souvenir."},
	"pompes_funebres": {"name": "Pompes funèbres", "w": 18, "d": 16, "access": ROAD, "emplois": 7, "cost": 450_000,
		"funeraire": {"role": "pompes_funebres", "corbillards": 2, "chambre": 6},
		"metiers": [["conseiller_funeraire", 2], ["porteur_funeraire", 4], ["thanatopracteur", 1]],
		"desc": "Agence, chambre funéraire (%d places) et deux corbillards. Les porteurs conduisent les cortèges."},
}
const ORDER := ["pompes_funebres", "cimetiere_village", "cimetiere_communal", "cimetiere_paysager", "columbarium", "crematorium",
	"cimetiere_militaire", "cimetiere_asie", "cimetiere_musulman", "cimetiere_juif"]


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate(true)
		t["cat"] = CATEGORY
		t["region"] = String(t.get("region", "monde"))
		t["era"] = "moderne"
		t["style"] = ""
		var n := places(id)
		if String(t.desc).contains("%d"):
			t.desc = String(t.desc) % n
		if n > 0:
			t["places"] = n
		out[id] = t
	return out


static func role_of(type_id: String) -> String:
	return String(spec_of(type_id).get("role", ""))


static func spec_of(type_id: String) -> Dictionary:
	if TYPES.has(type_id):
		return TYPES[type_id].funeraire
	return BuildingCatalog.get_type(type_id).get("funeraire", {})


## Nombre de places (tombes, cases du columbarium, places de la chambre funéraire).
static func places(type_id: String) -> int:
	match role_of(type_id):
		"cimetiere", "columbarium":
			return slots(type_id).size()
		"pompes_funebres":
			return int(spec_of(type_id).get("chambre", 0))
	return 0


# --- Disposition des tombes ------------------------------------------------------------------

static var _slots_cache: Dictionary = {}
static var _blocks_cache: Dictionary = {}


## Carrés d'un cimetière (repère local) : [Rect2(x, z, largeur, profondeur)].
static func blocks(type_id: String) -> Array:
	if _blocks_cache.has(type_id):
		return _blocks_cache[type_id]
	var out: Array = []
	var t: Dictionary = TYPES[type_id] if TYPES.has(type_id) else BuildingCatalog.get_type(type_id)
	var pl: Dictionary = spec_of(type_id).get("plan", {})
	if pl.is_empty():
		_blocks_cache[type_id] = out
		return out
	var w := float(t.w)
	var d := float(t.d)
	var m := float(pl.marge)
	var al := float(pl.allee)
	var bw := float(pl.bloc[0])
	var bd := float(pl.bloc[1])
	var wi := w - 2.0 * m
	var z0 := -d / 2.0 + m + float(pl.entree)
	var di := d / 2.0 - m - z0
	var nx := int(floor((wi + al) / (bw + al)))
	var nz := int(floor((di + al) / (bd + al)))
	var used_x := nx * bw + (nx - 1) * al
	var used_z := nz * bd + (nz - 1) * al
	var x0 := -used_x / 2.0
	var zs := z0 + (di - used_z) / 2.0
	for j in nz:
		for i in nx:
			out.append(Rect2(x0 + i * (bw + al), zs + j * (bd + al), bw, bd))
	_blocks_cache[type_id] = out
	return out


## Places d'un cimetière ou d'un columbarium, dans l'ordre où on les remplit
## (de l'entrée vers le fond) : Transform3D local (la stèle regarde vers −Z,
## vers l'allée de l'entrée ; pour le columbarium, la plaque regarde dehors).
static func slots(type_id: String) -> Array:
	if _slots_cache.has(type_id):
		return _slots_cache[type_id]
	var out: Array = []
	var spec := spec_of(type_id)
	match String(spec.get("role", "")):
		"cimetiere":
			var pl: Dictionary = spec.plan
			var dx := float(pl.pas[0])
			var dz := float(pl.pas[1])
			var yaw := 0.0
			# Les tombes musulmanes sont tournées vers La Mecque (au sud-est depuis l'Europe).
			if String(spec.get("stele", "")) == "simple":
				yaw = deg_to_rad(-20.0)
			var rows: Array = []
			for r in blocks(type_id):
				var rr: Rect2 = r
				var cols := int(floor(rr.size.x / dx))
				var nrows := int(floor(rr.size.y / dz))
				var ox := rr.position.x + (rr.size.x - cols * dx) / 2.0
				for j in nrows:
					for i in cols:
						rows.append([rr.position.y + j * dz, absf(ox + (i + 0.5) * dx), ox + (i + 0.5) * dx, rr.position.y + (j + 0.5) * dz])
			rows.sort_custom(func(a: Array, b: Array) -> bool:
				return a[0] < b[0] - 0.01 or (absf(a[0] - b[0]) <= 0.01 and a[1] < b[1]))
			for e in rows:
				out.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(float(e[2]), 0.0, float(e[3]))))
		"columbarium":
			# Trois murs de cases de 12 m, deux faces, 6 rangées de cases de 50 cm.
			for wz in [-4.0, 1.0, 6.0]:
				for face in [-1.0, 1.0]:
					for lvl in 6:
						for i in 24:
							var x := -6.0 + 0.25 + i * 0.5
							var b := Basis.IDENTITY if face < 0.0 else Basis(Vector3.UP, PI)
							out.append(Transform3D(b, Vector3(x, 0.45 + lvl * 0.5, wz + face * 0.42)))
	_slots_cache[type_id] = out
	return out


# --- Modèles low-poly ----------------------------------------------------------------------------

const HERBE := Color("7fae5a")
const HERBE_R := Color("8fbf68")
const GRAVIER := Color("d8cfbd")
const PIERRE := Color("b7ab95")
const PIERRE_F := Color("8e8473")
const ENDUIT := Color("e6dccb")
const BLANC := Color("f3f1ea")
const ARDOISE := Color("4b5563")
const TUILE := Color("b5654a")
const VITRE := Color("33495e")
const NOIR := Color("26262b")
const BOIS := Color("7a5230")
const CYPRES := Color("2f5d3a")
const IF_C := Color("3c6b40")
const EAU := Color("5b8fb0")
const ROUGE := Color("a4161a")
const GRANITS := [Color("8d8d8f"), Color("3a3a3e"), Color("a07e74"), Color("c2bdb3")]


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	var spec: Dictionary = t.funeraire
	match String(spec.role):
		"cimetiere":
			_cimetiere(k, id, w, d, spec)
		"columbarium":
			_columbarium(k, w, d)
		"crematorium":
			_crematorium(k, w, d)
		"pompes_funebres":
			_pompes_funebres(k, w, d)


static func _cypres(k: BlocMesh, x: float, z: float, h := 7.0) -> void:
	k.cylinder(x, 0.0, z, 0.15, 0.12, 0.8, 5, BOIS)
	k.cylinder(x, 0.6, z, 0.75, 0.0, h, 7, CYPRES)


static func _mur(k: BlocMesh, w: float, d: float, kind: String, porte := 5.0) -> void:
	var col := PIERRE
	var h := 1.8
	var e := 0.5
	match kind:
		"enduit":
			col = ENDUIT
			h = 2.2
		"enduit_blanc":
			col = BLANC
			h = 2.0
		"haie":
			col = Color("4f7d3c")
			h = 1.1
			e = 0.9
	var hw := w / 2.0
	var hd := d / 2.0
	k.box(0, 0, hd - e / 2.0, w, h, e, col)
	k.box(-hw + e / 2.0, 0, 0, e, h, d, col)
	k.box(hw - e / 2.0, 0, 0, e, h, d, col)
	var side := (w - porte) / 2.0
	k.box(-hw + side / 2.0, 0, -hd + e / 2.0, side, h, e, col)
	k.box(hw - side / 2.0, 0, -hd + e / 2.0, side, h, e, col)
	if kind != "haie":
		# Chaperon du mur et piliers du portail.
		var top := col.darkened(0.15)
		k.box(0, h, hd - e / 2.0, w + 0.1, 0.12, e + 0.12, top)
		k.box(-hw + e / 2.0, h, 0, e + 0.12, 0.12, d, top)
		k.box(hw - e / 2.0, h, 0, e + 0.12, 0.12, d, top)
		for s in [-1.0, 1.0]:
			k.box(s * (porte / 2.0 + 0.35), 0, -hd + e / 2.0, 0.8, h + 0.7, 0.8, col.darkened(0.08))
	# Grille du portail, ouverte.
	for s in [-1.0, 1.0]:
		k.box(s * (porte / 2.0 - 0.2), 0, -hd + 1.0, 0.08, 1.9, 1.6, NOIR)


static func _cimetiere(k: BlocMesh, id: String, w: float, d: float, spec: Dictionary) -> void:
	var stele := String(spec.get("stele", "dalle"))
	var pl: Dictionary = spec.plan
	var sol := HERBE_R if stele in ["blanche", "stele"] else GRAVIER
	k.plate(0, 0, w, d, HERBE)
	var m := float(pl.marge)
	# Allées : tout l'intérieur en gravier (ou pelouse), carrés posés dessus.
	k.plate(0, 0, w - 2.0 * m + 0.6, d - 2.0 * m + 0.6, sol, 0.0, 0.1)
	var carre := HERBE if stele in ["blanche", "stele"] else Color("b9ae98")
	if stele == "asie":
		carre = Color("a69f92")
	elif stele == "simple":
		carre = Color("c9b48f")
	for r in blocks(id):
		var rr: Rect2 = r
		k.plate(rr.get_center().x, rr.get_center().y, rr.size.x, rr.size.y, carre, 0.0, 0.14)
	# Allée centrale depuis le portail.
	k.plate(0, -d / 2.0 + m + float(pl.entree) / 2.0, float(pl.allee) + 1.0, float(pl.entree) + 2.0 * m, GRAVIER.lightened(0.05), 0.0, 0.12)
	_mur(k, w, d, String(spec.get("mur", "pierre")), clampf(float(pl.allee) + 1.5, 4.0, 8.0))
	# Arbres aux croisements des allées.
	var bl: Array = blocks(id)
	var al := float(pl.allee)
	var n := 0
	for r in bl:
		var rr: Rect2 = r
		var cx := rr.position.x + rr.size.x + al / 2.0
		var cz := rr.position.y + rr.size.y + al / 2.0
		if cx < w / 2.0 - m and cz < d / 2.0 - m:
			n += 1
			match stele:
				"stele":
					k.tree(cx, cz, 1.3 + 0.3 * float(n % 3), Color("5a8f3c") if n % 2 == 0 else Color("6b9e45"))
				"simple":
					k.cylinder(cx, 0.0, cz, 0.2, 0.15, 5.0, 6, Color("8b6b4a"))
					for a in 6:
						var ang := a * TAU / 6.0
						k.box(cx + cos(ang) * 1.2, 4.6, cz + sin(ang) * 1.2, 2.4, 0.15, 0.7, Color("4f8a3a"))
				"asie":
					_lanterne(k, cx, cz)
				_:
					_cypres(k, cx, cz, 6.0 + float(n % 3))
	# Rangée d'arbres le long du mur du fond.
	if stele != "blanche":
		var i := -w / 2.0 + m + 3.0
		while i < w / 2.0 - m - 2.0:
			if stele == "stele":
				k.tree(i, d / 2.0 - m * 0.6, 1.4)
			elif stele != "simple":
				_cypres(k, i, d / 2.0 - m * 0.55, 5.5)
			i += 9.0
	var z_in := -d / 2.0 + m
	match id:
		"cimetiere_village":
			# Croix de cimetière au bout de l'allée et petit appentis à outils.
			k.box(0, 0, z_in + float(pl.entree) - 1.0, 1.2, 0.6, 1.2, PIERRE_F)
			k.box(0, 0.6, z_in + float(pl.entree) - 1.0, 0.25, 3.2, 0.25, PIERRE_F)
			k.box(0, 2.8, z_in + float(pl.entree) - 1.0, 1.3, 0.25, 0.25, PIERRE_F)
			k.box(w / 2.0 - 4.0, 0, -d / 2.0 + 3.2, 3.0, 2.4, 2.4, PIERRE)
			k.gable(w / 2.0 - 4.0, 2.4, -d / 2.0 + 3.2, 3.4, 2.8, 1.0, TUILE)
		"cimetiere_communal", "cimetiere_paysager":
			# Conciergerie à l'entrée, ossuaire, fontaine et jardin du souvenir.
			var gx := -w / 2.0 + 7.0
			k.box(gx, 0, z_in + 3.0, 7.0, 3.6, 5.0, ENDUIT)
			k.hip(gx, 3.6, z_in + 3.0, 7.6, 5.6, 1.6, ARDOISE)
			k.windows_row(gx, z_in + 0.45, 5.0, 1.4, 2, 1.0, 1.2, VITRE)
			k.box(w / 2.0 - 7.0, 0, z_in + 3.0, 5.0, 2.8, 3.0, PIERRE)
			k.box(w / 2.0 - 7.0, 2.8, z_in + 3.0, 5.4, 0.3, 3.4, PIERRE_F)
			k.cylinder(-6.0, 0.0, z_in + float(pl.entree) - 2.0, 0.5, 0.5, 0.9, 8, PIERRE_F)
			k.cylinder(-6.0, 0.9, z_in + float(pl.entree) - 2.0, 0.1, 0.1, 0.4, 5, Color("6c757d"))
			# Jardin du souvenir : pelouse ronde, galets, stèle des noms.
			var jx := w / 2.0 - 12.0
			var jz := z_in + float(pl.entree) - 3.0
			k.cylinder(jx, 0.0, jz, 3.0, 3.0, 0.16, 12, HERBE_R)
			k.cylinder(jx, 0.16, jz, 1.2, 1.2, 0.06, 10, Color("e9e4d8"))
			k.box(jx, 0, jz + 3.6, 3.0, 1.6, 0.3, PIERRE_F)
			if id == "cimetiere_paysager":
				k.cylinder(-w / 4.0, 0.0, d / 2.0 - m - 12.0, 9.0, 9.0, 0.18, 14, EAU)
				for a in 7:
					var ang := a * TAU / 7.0
					k.tree(-w / 4.0 + cos(ang) * 12.0, d / 2.0 - m - 12.0 + sin(ang) * 10.0, 1.5)
		"cimetiere_militaire":
			# Mât et mémorial au centre du parvis.
			var mz := z_in + float(pl.entree) / 2.0
			k.box(0, 0, mz, 6.0, 0.4, 3.0, BLANC.darkened(0.06))
			k.box(0, 0.4, mz + 0.6, 4.0, 2.6, 0.6, BLANC)
			k.cylinder(5.0, 0.0, mz, 0.08, 0.06, 10.0, 6, Color("d0d0d0"))
			k.box(5.0 + 0.8, 8.8, mz, 1.5, 1.0, 0.04, Color("1d3557"))
		"cimetiere_asie":
			# Portique d'entrée en pierre et bonsaïs.
			var pz := -d / 2.0 + m + 1.0
			for s in [-1.0, 1.0]:
				k.box(s * 2.4, 0, pz, 0.5, 3.6, 0.5, PIERRE_F)
			k.box(0, 3.6, pz, 6.2, 0.4, 0.7, PIERRE_F)
			k.box(0, 3.0, pz, 5.2, 0.3, 0.4, PIERRE_F)
			for s in [-1.0, 1.0]:
				_lanterne(k, s * 4.0, z_in + float(pl.entree) - 1.5)
		"cimetiere_musulman":
			# Petit pavillon à coupole près de l'entrée.
			var px := -w / 2.0 + 6.0
			k.box(px, 0, z_in + 2.5, 4.0, 3.0, 4.0, BLANC)
			k.dome(px, 3.0, z_in + 2.5, 1.9, 1.6, Color("2a9d8f"))
		"cimetiere_juif":
			# Maison de purification (tahara) et lavabo à l'entrée.
			var px := -w / 2.0 + 6.0
			k.box(px, 0, z_in + 2.5, 6.0, 3.2, 4.0, PIERRE)
			k.gable(px, 3.2, z_in + 2.5, 6.4, 4.4, 1.2, ARDOISE)
			k.box(4.0, 0, z_in + 1.5, 1.4, 0.9, 0.5, PIERRE_F)


static func _lanterne(k: BlocMesh, x: float, z: float) -> void:
	k.box(x, 0, z, 0.7, 0.2, 0.7, PIERRE_F)
	k.box(x, 0.2, z, 0.25, 0.9, 0.25, PIERRE_F)
	k.box(x, 1.1, z, 0.55, 0.45, 0.55, Color("efe6cf"))
	k.pyramid(x, 1.55, z, 0.9, 0.9, 0.35, PIERRE_F)


static func _columbarium(k: BlocMesh, w: float, d: float) -> void:
	k.plate(0, 0, w, d, HERBE)
	k.plate(0, -2.0, 16.0, 18.0, GRAVIER, 0.0, 0.1)
	for wz in [-4.0, 1.0, 6.0]:
		k.box(0, 0, wz, 12.4, 3.5, 0.8, Color("d9d4c7"))
		k.box(0, 3.5, wz, 12.8, 0.2, 1.1, PIERRE_F)
	# Jardin du souvenir au fond, à droite : pelouse ronde, galets blancs, stèle.
	k.cylinder(w / 2.0 - 5.0, 0.0, d / 2.0 - 5.0, 3.6, 3.6, 0.16, 12, HERBE_R)
	k.cylinder(w / 2.0 - 5.0, 0.16, d / 2.0 - 5.0, 1.4, 1.4, 0.06, 10, Color("efebe3"))
	k.box(w / 2.0 - 5.0, 0, d / 2.0 - 1.0, 3.0, 1.5, 0.3, PIERRE_F)
	for i in 4:
		_cypres(k, -w / 2.0 + 2.0, -d / 2.0 + 4.0 + i * 5.0, 5.0)
	k.box(0, 0, -d / 2.0 + 0.3, w, 0.9, 0.3, Color("4f7d3c"))


static func _crematorium(k: BlocMesh, w: float, d: float) -> void:
	k.plate(0, 0, w, d, HERBE)
	k.plate(0, -d / 2.0 + 4.0, w - 4.0, 7.0, Color("c8c3b8"), 0.0, 0.1)
	# Salle de cérémonie : grand volume clair, vitrage sur le jardin.
	k.box(-6.0, 0, 0.0, 20.0, 6.5, 14.0, Color("e9e5dc"))
	k.box(-6.0, 6.5, 0.0, 20.6, 0.5, 14.6, Color("8d8d8f"))
	k.box(-6.0, 0.4, -7.05, 10.0, 4.6, 0.1, VITRE)
	k.box(-6.0, 0, -9.0, 8.0, 0.25, 4.0, Color("8d8d8f"))
	for s in [-1.0, 1.0]:
		k.box(-6.0 + s * 3.8, 0.25, -10.6, 0.3, 3.4, 0.3, Color("8d8d8f"))
	k.box(-6.0, 3.65, -9.0, 8.4, 0.25, 4.4, Color("8d8d8f"))
	# Bâtiment technique des fours et cheminée.
	k.box(11.0, 0, 3.0, 14.0, 5.0, 12.0, Color("bdb7ab"))
	k.box(11.0, 5.0, 3.0, 14.4, 0.4, 12.4, Color("6c757d"))
	k.cylinder(14.5, 5.4, 6.0, 0.9, 0.7, 9.0, 10, Color("9a948a"))
	k.box(11.0, 0, -3.05, 4.0, 3.6, 0.1, Color("d6d3cc"))
	# Jardin du souvenir derrière.
	k.cylinder(-6.0, 0.0, d / 2.0 - 4.5, 3.2, 3.2, 0.16, 12, HERBE_R)
	k.cylinder(-6.0, 0.16, d / 2.0 - 4.5, 1.2, 1.2, 0.06, 10, Color("efebe3"))
	for i in 5:
		_cypres(k, -w / 2.0 + 2.5, -6.0 + i * 5.0, 6.0)
		k.tree(w / 2.0 - 2.5, -8.0 + i * 5.0, 1.1)


static func _pompes_funebres(k: BlocMesh, w: float, d: float) -> void:
	k.plate(0, 0, w, d, Color("c8c3b8"))
	# Agence en façade : vitrine sombre, enseigne, étage.
	k.box(-3.0, 0, 0.5, 11.0, 6.4, 13.0, ENDUIT)
	k.hip(-3.0, 6.4, 0.5, 11.6, 13.6, 2.2, ARDOISE)
	k.box(-3.0, 0, -6.05, 8.6, 3.0, 0.1, Color("2b2d42"))
	k.box(-4.0, 0.2, -6.1, 4.2, 2.4, 0.1, VITRE)
	k.box(-0.3, 0, -6.1, 1.2, 2.3, 0.1, Color("4a3b30"))
	k.box(-3.0, 3.1, -6.15, 7.0, 0.7, 0.1, Color("1b1b1e"))
	k.box(-3.0, 3.25, -6.22, 5.2, 0.4, 0.05, Color("d4b483"))
	k.windows_row(-3.0, -6.05, 8.0, 4.4, 3, 1.1, 1.3, VITRE)
	# Garage des corbillards et cour.
	k.box(6.0, 0, 3.0, 6.0, 3.6, 10.0, Color("d6d0c4"))
	k.box(6.0, 3.6, 3.0, 6.3, 0.3, 10.3, Color("6c757d"))
	k.box(6.0, 0, -2.05, 4.4, 3.0, 0.1, Color("e9ecef"))
	# Un corbillard garé devant.
	k.box(6.0, 0.35, -5.4, 1.85, 0.75, 5.6, NOIR)
	k.box(6.0, 1.1, -5.0, 1.75, 0.65, 4.0, NOIR.lightened(0.08))
	k.box(6.0, 1.15, -5.0, 1.78, 0.45, 3.0, VITRE)
	for zz in [-7.3, -3.5]:
		for s in [-1.0, 1.0]:
			k.box(6.0 + s * 0.85, 0, zz, 0.25, 0.65, 0.65, Color("1a1a1a"))
	# Bacs de fleurs et arbustes.
	for i in 3:
		k.box(-7.5 + i * 3.0, 0, -7.4, 1.6, 0.5, 0.6, PIERRE_F)
		k.box(-7.5 + i * 3.0, 0.5, -7.4, 1.4, 0.35, 0.45, [Color("e63946"), Color("f1faee"), Color("ffb703")][i])


# --- Pierres tombales (MultiMesh du système Funeraire) ------------------------------------------

static var _tomb_meshes: Dictionary = {}


## Maillage d'une tombe selon le style (variant : couleur du granit).
static func tomb_mesh(style: String, variant := 0) -> ArrayMesh:
	var key := "%s:%d" % [style, variant]
	if _tomb_meshes.has(key):
		return _tomb_meshes[key]
	var k := BlocMesh.new()
	var g: Color = GRANITS[variant % GRANITS.size()]
	match style:
		"dalle":
			# Tombe à la française : semelle, dalle, stèle au fond.
			k.box(0, 0, 0.0, 1.05, 0.12, 2.15, g.darkened(0.1))
			k.box(0, 0.12, -0.05, 0.95, 0.16, 1.85, g)
			k.box(0, 0.12, 0.88, 0.85, 0.85, 0.14, g)
			k.box(0, 0.97, 0.88, 0.7, 0.1, 0.14, g.lightened(0.08))
			k.box(0, 0.3, 0.6, 0.35, 0.1, 0.25, Color("d4b483"))
		"stele":
			# Stèle sur pelouse : pierre seule et petit massif.
			k.box(0, 0, 0.9, 0.8, 0.9, 0.18, g)
			k.box(0, 0.9, 0.9, 0.6, 0.12, 0.18, g.lightened(0.06))
			k.box(0, 0, 0.55, 0.7, 0.08, 0.35, Color("6b8f3a"))
		"blanche":
			k.box(0, 0, 0.8, 0.45, 0.75, 0.12, BLANC)
			k.box(0, 0.75, 0.8, 0.35, 0.1, 0.12, BLANC.darkened(0.04))
		"asie":
			# Socle, haute stèle sombre, brûle-parfum.
			k.box(0, 0, 0.3, 1.7, 0.35, 1.9, PIERRE_F)
			k.box(0, 0.35, 0.8, 1.2, 0.35, 0.6, g.darkened(0.1))
			k.box(0, 0.7, 0.8, 0.5, 1.5, 0.3, Color("2e2e33") if variant % 2 == 0 else Color("6b6b70"))
			k.box(0, 0.35, -0.1, 0.4, 0.25, 0.3, Color("8d8d8f"))
		"simple":
			# Tertre bordé de pierres, petite stèle à la tête.
			k.box(0, 0, 0.0, 0.8, 0.18, 1.9, Color("a08b68"))
			k.box(0, 0, 0.0, 0.95, 0.08, 2.05, Color("d9d4c7"))
			k.box(0, 0, 0.98, 0.4, 0.65, 0.1, Color("e9e4d8"))
		"juive":
			k.box(0, 0, 0.0, 0.85, 0.1, 1.9, g.darkened(0.15))
			k.box(0, 0, 0.9, 0.75, 1.1, 0.16, g)
			for i in 3:
				k.box(-0.2 + i * 0.18, 1.1, 0.9, 0.08, 0.06, 0.08, Color("bdb7ab"))
		"plaque":
			# Case de columbarium : plaque gravée, filet doré.
			k.box(0, -0.2, -0.01, 0.46, 0.44, 0.03, g.darkened(0.2))
			k.box(0, 0.05, -0.03, 0.28, 0.04, 0.01, Color("d4b483"))
		"fleurs":
			# Bouquets et couronne d'une tombe récente.
			var cols := [Color("e63946"), Color("f1faee"), Color("ffb703"), Color("c77dff"), Color("ff8fab")]
			for i in 6:
				var a := float(i) * 1.7
				k.box(sin(a) * 0.3, 0.28, 0.1 + cos(a) * 0.55, 0.22, 0.18, 0.22, cols[(i + variant) % cols.size()])
			k.cylinder(0, 0.28, -0.6, 0.32, 0.32, 0.1, 10, Color("2d6a4f"))
		"cercueil":
			k.box(0, 0, 0, 0.7, 0.55, 2.0, Color("6f4e37"))
			k.box(0, 0.55, 0, 0.74, 0.08, 2.04, Color("5a3d2b"))
			k.box(0, 0.63, 0.2, 0.5, 0.12, 0.6, Color("e63946"))
		"fosse":
			k.box(0, 0, 0, 1.0, 0.04, 2.2, Color("3b2f25"))
			k.box(0.9, 0, 0, 0.6, 0.45, 2.0, Color("6b5642"))
		_:
			k.box(0, 0, 0.8, 0.7, 0.8, 0.15, g)
	var m := k.to_mesh(LpKit.vertex_material(0.85))
	_tomb_meshes[key] = m
	return m
