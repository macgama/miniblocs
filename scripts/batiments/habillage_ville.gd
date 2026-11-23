class_name HabillageVille
extends RefCounted
## Habillage des bâtiments de la ville (logements, bureaux, tours, services
## publics, industrie) : toits-terrasses équipés, acrotères, balcons et
## garde-corps, marquises d'entrée, marches, enseignes, façades vitrées à
## trame, abords (jardinières, bancs, lampadaires, vélos, arbres ronds).
##
## Les petits commerces ont leur propre habillage (Devantures) : ce fichier
## ne les touche pas.
##
## Tout passe par BlocMesh : un bâtiment reste un seul maillage. Les petits
## détails ne sont dessinés que de près (k._fine()) : la version vue de loin
## garde les volumes, l'acrotère et les grandes lignes de façade.
## Repère local : sol en y = 0, façade (porte) vers −Z.

const GRAVIER := Color("a9a59c")
const METAL := Color("c3c8ce")
const METAL_SOMBRE := Color("5b6068")
const NOIR := Color("2e3136")
## Garde-corps vitré : bleuté clair, pas une vitre (ne s'allume pas la nuit).
const VERRE_GC := Color("bfe0ea")
const BOIS_TERRASSE := Color("b48a5e")
const BETON := Color("cfcac0")
const PELOUSE := Color("7fb35a")
const FEUILLAGES := [Color("5f9e4a"), Color("6fae52"), Color("4f8c45"), Color("7cb85a"), Color("88b04b")]
const FLEURS := [Color("e5484d"), Color("f28ab2"), Color("fbf3e4"), Color("f5a524"), Color("b45fd6"), Color("ffd23f")]
const PARASOLS := [Color("e76f51"), Color("2a9d8f"), Color("f4a261"), Color("e9c46a"), Color("4ea8de"), Color("f15bb5")]


## Générateur stable pour un bâtiment et sa variante.
static func rng_pour(k: BlocMesh, cle: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%d" % [cle, k.variant])
	return r


# --- Toits ------------------------------------------------------------------------------

## Toit-terrasse : dalle gravillonnée, acrotère avec couvertine, puis (de près)
## équipements répartis sans se chevaucher. opts :
##   "mode" : "technique" (clims, gaines, édicule), "jardin" (terrasse plantée,
##            parasols), "solaire", "mixte" ; "acrotere" : hauteur (m) ;
##   "edicule" : false pour s'en passer ; "antenne" : true ; "reservoir" : true ;
##   "helico" : true (laisse le centre libre) ; "pas_centre" : rayon libre au centre.
static func toit_terrasse(k: BlocMesh, cx: float, y: float, cz: float, sx: float, sz: float, mur: Color,
		rng: RandomNumberGenerator, opts: Dictionary = {}) -> void:
	var h := float(opts.get("acrotere", 0.7))
	var couv := mur.lightened(0.25)
	k.box(cx, y, cz, sx - 0.1, 0.18, sz - 0.1, GRAVIER)
	var e := 0.3
	k.box(cx, y, cz - sz / 2.0 + e / 2.0, sx, h, e, mur)
	k.box(cx, y, cz + sz / 2.0 - e / 2.0, sx, h, e, mur)
	k.box(cx - sx / 2.0 + e / 2.0, y, cz, e, h, sz - 2.0 * e, mur)
	k.box(cx + sx / 2.0 - e / 2.0, y, cz, e, h, sz - 2.0 * e, mur)
	if not k._fine():
		return
	# Couvertine : un liseré clair qui dessine le haut du bâtiment.
	k.box(cx, y + h, cz - sz / 2.0 + e / 2.0, sx + 0.12, 0.08, e + 0.12, couv)
	k.box(cx, y + h, cz + sz / 2.0 - e / 2.0, sx + 0.12, 0.08, e + 0.12, couv)
	k.box(cx - sx / 2.0 + e / 2.0, y + h, cz, e + 0.12, 0.08, sz - 2.0 * e, couv)
	k.box(cx + sx / 2.0 - e / 2.0, y + h, cz, e + 0.12, 0.08, sz - 2.0 * e, couv)
	equiper_toit(k, cx, y + 0.18, cz, sx, sz, mur, rng, opts)


## Équipements d'un toit-terrasse déjà dessiné (dalle et acrotère) : édicule,
## réservoir, antenne, puis selon opts.mode climatiseurs, jardin ou solaire.
static func equiper_toit(k: BlocMesh, cx: float, y1: float, cz: float, sx: float, sz: float, mur: Color,
		rng: RandomNumberGenerator, opts: Dictionary = {}) -> void:
	if not k._fine():
		return
	var couv := mur.lightened(0.25)
	var mode := String(opts.get("mode", "technique"))
	# Cases libres de ~3,5 m sur la terrasse, mélangées.
	var pas := 3.6
	var nx := maxi(1, int((sx - 1.6) / pas))
	var nz := maxi(1, int((sz - 1.6) / pas))
	var cases: Array[Vector2] = []
	var libre := float(opts.get("pas_centre", 0.0))
	for i in nx:
		for j in nz:
			var p := Vector2(cx - (nx - 1) * pas / 2.0 + i * pas, cz - (nz - 1) * pas / 2.0 + j * pas)
			if libre > 0.0 and p.distance_to(Vector2(cx, cz)) < libre:
				continue
			cases.append(p)
	_melanger(cases, rng)
	# Édicule d'accès (cage d'escalier) dans un coin.
	if bool(opts.get("edicule", true)) and sx >= 8.0 and sz >= 8.0:
		var ex := cx + sx / 2.0 - 2.6
		var ez := cz + sz / 2.0 - 2.2
		k.box(ex, y1, ez, 3.4, 2.6, 2.6, mur.darkened(0.04))
		k.box(ex, y1 + 2.6, ez, 3.7, 0.18, 2.9, couv)
		k.box(ex - 0.6, y1, ez - 1.33, 0.95, 2.1, 0.08, METAL_SOMBRE)
		_retirer_proches(cases, Vector2(ex, ez), 3.2)
	if bool(opts.get("reservoir", false)) and not cases.is_empty():
		var c: Vector2 = cases.pop_back()
		for ox in [-0.8, 0.8]:
			for oz in [-0.8, 0.8]:
				k.box(c.x + ox, y1, c.y + oz, 0.16, 1.9, 0.16, Color("5a4632"))
		k.cylinder(c.x, y1 + 1.9, c.y, 1.4, 1.4, 2.4, 10, Color("8a6440"))
		k.lathe(c.x, y1 + 4.3, c.y, [Vector2(1.5, 0), Vector2(0, 0.9)], 10, Color("4f4a44"))
	if bool(opts.get("antenne", false)) and not cases.is_empty():
		var c: Vector2 = cases.pop_back()
		k.box(c.x, y1, c.y, 0.1, 4.5, 0.1, METAL)
		k.box(c.x, y1 + 3.2, c.y, 1.4, 0.05, 0.05, METAL)
		k.box(c.x, y1 + 3.8, c.y, 0.9, 0.05, 0.05, METAL)
		k.cylinder(c.x + 0.5, y1 + 2.2, c.y, 0.35, 0.05, 0.15, 8, Color("eeeeee"))
	match mode:
		"jardin":
			_terrasse_jardin(k, cx, y1, cz, sx, sz, rng, cases)
		"solaire":
			_rangs_solaires(k, cx, y1, cz, sx * 0.75, sz * 0.6, rng)
			for i in range(cases.size() - 1, -1, -1):
				if absf(cases[i].x - cx) < sx * 0.4 + 0.8 and absf(cases[i].y - cz) < sz * 0.3 + 0.8:
					cases.remove_at(i)
			_equipements(k, y1, rng, cases, 2)
		"mixte":
			var n := cases.size()
			_equipements(k, y1, rng, cases, maxi(2, n / 3))
			_jardinieres_toit(k, y1, rng, cases, maxi(1, n / 4))
		_:
			_equipements(k, y1, rng, cases, clampi(int(sx * sz / 45.0), 2, 9))


## Climatiseurs, gaines et extracteurs sur les cases libres.
static func _equipements(k: BlocMesh, y: float, rng: RandomNumberGenerator, cases: Array[Vector2], n: int) -> void:
	for i in mini(n, cases.size()):
		var c: Vector2 = cases.pop_back()
		match rng.randi() % 4:
			0, 1:
				# Groupe de climatisation : caisson et ventilateur.
				k.box(c.x, y, c.y, 1.6, 0.95, 1.1, Color("d9dcdf"))
				k.box(c.x, y + 0.95, c.y, 1.66, 0.06, 1.16, Color("b5b9be"))
				k.cylinder(c.x - 0.35, y + 1.01, c.y, 0.38, 0.38, 0.03, 8, NOIR)
				k.cylinder(c.x + 0.42, y + 1.01, c.y, 0.3, 0.3, 0.03, 8, NOIR)
			2:
				# Extracteurs en champignon.
				for o in [-0.6, 0.6]:
					k.cylinder(c.x + o, y, c.y, 0.22, 0.22, 0.8, 6, METAL)
					k.cylinder(c.x + o, y + 0.8, c.y, 0.38, 0.1, 0.22, 6, METAL.darkened(0.1))
			_:
				# Gaine de ventilation coudée.
				k.box(c.x, y, c.y, 0.7, 1.2, 0.7, METAL)
				k.box(c.x + 0.9, y + 0.85, c.y, 2.4, 0.55, 0.55, METAL.darkened(0.05))


## Rangs de panneaux solaires inclinés vers le sud (−Z).
static func _rangs_solaires(k: BlocMesh, cx: float, y: float, cz: float, sx: float, sz: float, rng: RandomNumberGenerator) -> void:
	var rows := clampi(int(sz / 2.6), 1, 5)
	var cols := clampi(int(sx / 2.0), 1, 8)
	var col := Color("23396b")
	for r in rows:
		var z := cz - sz / 2.0 + (r + 0.5) * sz / rows
		var x0 := cx - sx / 2.0
		var x1 := cx + sx / 2.0
		k.panel(Vector3(x0, y + 0.3, z - 0.7), Vector3(x1, y + 0.3, z - 0.7), Vector3(x1, y + 1.0, z + 0.5),
			Vector3(x0, y + 1.0, z + 0.5), Vector3(0, 1, -0.6), col)
		k.panel(Vector3(x0, y + 0.28, z - 0.7), Vector3(x1, y + 0.28, z - 0.7), Vector3(x1, y + 0.98, z + 0.5),
			Vector3(x0, y + 0.98, z + 0.5), Vector3(0, -1, 0.6), METAL_SOMBRE)
		for c in cols + 1:
			var x := x0 + c * sx / cols
			k.box(x, y + 0.3, z - 0.1, 0.04, 0.68, 1.25, Color("dfe6ee"))
			k.box(x, y, z + 0.4, 0.08, 0.95, 0.08, METAL)


## Terrasse plantée : platelage, bacs à arbustes, parasols, tables, pergola.
static func _terrasse_jardin(k: BlocMesh, cx: float, y: float, cz: float, sx: float, sz: float,
		rng: RandomNumberGenerator, cases: Array[Vector2]) -> void:
	k.plate(cx, cz, sx - 1.2, sz - 1.2, BOIS_TERRASSE, y, 0.06)
	# Pelouse sur une moitié.
	k.plate(cx + sx * 0.18, cz + sz * 0.1, sx * 0.4, sz * 0.5, PELOUSE, y + 0.06, 0.05)
	var n := cases.size()
	for i in n:
		var c: Vector2 = cases.pop_back()
		match i % 3:
			0:
				parasol(k, c.x, y + 0.06, c.y, PARASOLS[rng.randi() % PARASOLS.size()])
			1:
				jardiniere(k, c.x, y + 0.06, c.y, 1.8, 0.8, rng)
			_:
				arbre_rond(k, c.x, y + 0.06, c.y, 0.55, FEUILLAGES[rng.randi() % FEUILLAGES.size()])
				k.box(c.x, y + 0.06, c.y, 1.1, 0.45, 1.1, BETON)


static func _jardinieres_toit(k: BlocMesh, y: float, rng: RandomNumberGenerator, cases: Array[Vector2], n: int) -> void:
	for i in mini(n, cases.size()):
		var c: Vector2 = cases.pop_back()
		jardiniere(k, c.x, y, c.y, 2.0, 0.8, rng)


static func _melanger(a: Array[Vector2], rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t := a[i]
		a[i] = a[j]
		a[j] = t


static func _retirer_proches(a: Array[Vector2], p: Vector2, r: float) -> void:
	for i in range(a.size() - 1, -1, -1):
		if a[i].distance_to(p) < r:
			a.remove_at(i)


# --- Façades ----------------------------------------------------------------------------

## Façade à trame (bureaux, tours) : bandeaux vitrés par étage, nez de dalle
## en saillie et montants verticaux sur toute la hauteur. Peu de triangles.
## sides : façades habillées (0 = −Z, 1 = +X, 2 = +Z, 3 = −X).
static func trame(k: BlocMesh, cx: float, cz: float, sx: float, sz: float, y0: float, floors: int, fh: float,
		vitre: Color, cadre: Color, pas := 1.8, part_vitre := 0.62, sides := [0, 1, 2, 3]) -> void:
	var h := floors * fh
	for i in floors:
		var yb := y0 + i * fh + fh * (1.0 - part_vitre) * 0.55
		k.box(cx, yb, cz, sx + 0.08, fh * part_vitre, sz + 0.08, vitre)
	if not k._fine():
		return
	for i in floors + 1:
		var ys := y0 + i * fh - 0.12
		if ys >= 0.0:
			k.box(cx, ys, cz, sx + 0.3, 0.24, sz + 0.3, cadre)
	for side in sides:
		var long := sx if side % 2 == 0 else sz
		var n := maxi(2, int(long / pas))
		for j in range(1, n):
			var t := -long / 2.0 + j * long / n
			match side:
				0: k.box(cx + t, y0, cz - sz / 2.0 - 0.08, 0.16, h, 0.2, cadre)
				2: k.box(cx + t, y0, cz + sz / 2.0 + 0.08, 0.16, h, 0.2, cadre)
				1: k.box(cx + sx / 2.0 + 0.08, y0, cz + t, 0.2, h, 0.16, cadre)
				3: k.box(cx - sx / 2.0 - 0.08, y0, cz + t, 0.2, h, 0.16, cadre)


## Fenêtres individuelles sur les quatre façades (encadrements et appuis
## automatiques de près, voir BlocMesh.box). Rien sous y_min (rez-de-chaussée).
static func fenetres(k: BlocMesh, cx: float, cz: float, sx: float, sz: float, y0: float, floors: int, fh: float,
		n_face: int, n_cote: int, vitre: Color, fw := 1.2, fhh := 1.5, sauf_rdc := false) -> void:
	for i in floors:
		if sauf_rdc and i == 0:
			continue
		var y := y0 + i * fh + fh * 0.3
		k.windows_row(cx, cz - sz / 2.0, sx * 0.88, y, n_face, fw, fhh, vitre)
		k.windows_row(cx, cz + sz / 2.0, sx * 0.88, y, n_face, fw, fhh, vitre)
		if n_cote > 0:
			k.windows_col(cx - sx / 2.0, cz, sz * 0.85, y, n_cote, fw, fhh, vitre)
			k.windows_col(cx + sx / 2.0, cz, sz * 0.85, y, n_cote, fw, fhh, vitre)


## Balcons en saillie sur une façade ±Z (side = −1 : façade avant, 1 : arrière).
## motif : "tous", "alterne" (en quinconce), "colonnes" (une colonne sur deux).
## garde : "verre", "barreaux", "plein".
static func balcons(k: BlocMesh, cx: float, z_face: float, width: float, y0: float, floors: int, fh: float, side: float,
		dalle: Color, rail: Color, rng: RandomNumberGenerator, motif := "alterne", garde := "verre", larg := 3.0, prof := 1.3,
		premier := 1) -> void:
	var cols := maxi(1, int(width / (larg + 0.9)))
	for i in range(premier, floors):
		for c in cols:
			if motif == "alterne" and (c + i) % 2 == 1:
				continue
			if motif == "colonnes" and c % 2 == 1:
				continue
			var x := cx - width / 2.0 + (c + 0.5) * width / cols
			var y := y0 + i * fh
			balcon(k, x, y, z_face, larg, prof, side, dalle, rail, garde, rng)


## Un balcon : dalle, garde-corps, et parfois une plante ou une chaise.
static func balcon(k: BlocMesh, x: float, y: float, z_face: float, larg: float, prof: float, side: float,
		dalle: Color, rail: Color, garde: String, rng: RandomNumberGenerator) -> void:
	var zc := z_face + side * prof / 2.0
	var zo := z_face + side * (prof - 0.05)
	k.box(x, y - 0.18, zc, larg, 0.18, prof, dalle)
	if not k._fine():
		return
	match garde:
		"plein":
			k.box(x, y, zo, larg, 1.0, 0.1, dalle)
			k.box(x - larg / 2.0 + 0.05, y, zc, 0.1, 1.0, prof - 0.1, dalle)
			k.box(x + larg / 2.0 - 0.05, y, zc, 0.1, 1.0, prof - 0.1, dalle)
		"barreaux":
			StyleKit.garde_corps(k, x, y, zo, larg, rail)
			k.box(x - larg / 2.0 + 0.03, y + 0.85, zc, 0.07, 0.07, prof - 0.1, rail)
			k.box(x + larg / 2.0 - 0.03, y + 0.85, zc, 0.07, 0.07, prof - 0.1, rail)
		_:
			k.box(x, y + 0.05, zo, larg - 0.1, 0.9, 0.05, VERRE_GC)
			k.box(x, y + 0.95, zo, larg, 0.07, 0.1, rail)
			k.box(x - larg / 2.0 + 0.04, y + 0.05, zc, 0.04, 0.9, prof - 0.1, VERRE_GC)
			k.box(x + larg / 2.0 - 0.04, y + 0.05, zc, 0.04, 0.9, prof - 0.1, VERRE_GC)
	var r := rng.randf()
	if r < 0.45:
		# Pot de fleurs.
		var px := x + (larg / 2.0 - 0.45) * (1.0 if rng.randf() < 0.5 else -1.0)
		k.box(px, y, zo - side * 0.3, 0.45, 0.4, 0.45, Color("c0623a"))
		k.dome(px, y + 0.4, zo - side * 0.3, 0.36, 0.42, FEUILLAGES[rng.randi() % FEUILLAGES.size()], 6)
		if rng.randf() < 0.6:
			k.box(px, y + 0.75, zo - side * 0.3, 0.2, 0.12, 0.2, FLEURS[rng.randi() % FLEURS.size()])
	elif r < 0.6:
		# Petite table et chaise.
		k.cylinder(x, y, zc, 0.3, 0.3, 0.7, 6, Color("f2efe6"))
		k.box(x + 0.6, y, zc, 0.4, 0.45, 0.4, Color("2a9d8f"))


## Loggias : creux d'un étage sur une façade ±Z (simple bande sombre en retrait).
static func loggias(k: BlocMesh, cx: float, z_face: float, width: float, y0: float, floors: int, fh: float, side: float,
		col: Color, pas := 4.5) -> void:
	var n := maxi(1, int(width / pas))
	for i in range(1, floors):
		for c in n:
			if (c + i) % 2 == 0:
				continue
			var x := cx - width / 2.0 + (c + 0.5) * width / n
			k.box(x, y0 + i * fh + 0.1, z_face + side * 0.02, pas * 0.7, fh - 0.4, 0.06, col)


# --- Entrées, enseignes -----------------------------------------------------------------

## Marquise d'entrée (dalle fine en porte-à-faux, liseré coloré) sur une façade −Z.
static func marquise(k: BlocMesh, cx: float, y: float, z_face: float, larg: float, prof: float, col: Color, poteaux := false) -> void:
	k.box(cx, y, z_face - prof / 2.0, larg, 0.22, prof, col)
	if not k._fine():
		return
	k.box(cx, y - 0.04, z_face - prof / 2.0, larg - 0.2, 0.05, prof - 0.2, Color("f4f1ea"))
	if poteaux:
		for x in [cx - larg / 2.0 + 0.25, cx + larg / 2.0 - 0.25]:
			k.box(x, 0, z_face - prof + 0.25, 0.18, y, 0.18, METAL_SOMBRE)


## Marches et palier devant une porte (façade −Z).
static func marches(k: BlocMesh, cx: float, z_face: float, larg: float, n := 3, col := Color("bdb7ad")) -> void:
	if not k._fine():
		return
	for i in n:
		var d := 0.4 * (n - i)
		k.box(cx, i * 0.15, z_face - d / 2.0, larg + 0.3 * (n - i), 0.15, d, col.lightened(i * 0.03))


## Porte vitrée à deux battants avec encadrement (façade −Z).
static func porte_vitree(k: BlocMesh, cx: float, z_face: float, larg := 2.4, h := 2.6, cadre := METAL_SOMBRE) -> void:
	k.box(cx, 0, z_face - 0.04, larg, h, 0.1, Color("1d2d3c"))
	if not k._fine():
		return
	k.box(cx, h, z_face - 0.06, larg + 0.3, 0.15, 0.14, cadre)
	for x in [cx - larg / 2.0, cx, cx + larg / 2.0]:
		k.box(x, 0, z_face - 0.06, 0.1, h, 0.14, cadre)


## Enseigne en applique sur une façade −Z : fond, liseré et lettres claires.
static func enseigne(k: BlocMesh, cx: float, y: float, z_face: float, larg: float, h: float, fond: Color,
		lettres: Color, rng: RandomNumberGenerator) -> void:
	k.box(cx, y, z_face - 0.08, larg, h, 0.12, fond)
	if not k._fine():
		return
	k.box(cx, y - 0.06, z_face - 0.06, larg + 0.16, 0.06, 0.16, fond.darkened(0.3))
	var n := maxi(2, int(larg / (h * 0.75)))
	var lw := (larg - h * 0.6) / n
	for i in n:
		if rng.randf() < 0.88:
			k.box(cx - larg / 2.0 + h * 0.3 + (i + 0.5) * lw, y + h * 0.22, z_face - 0.16, lw * 0.62, h * 0.56, 0.04, lettres)


## Enseigne posée sur le toit (cadre métallique et panneau), façade −Z.
static func enseigne_toit(k: BlocMesh, cx: float, y: float, z: float, larg: float, h: float, fond: Color,
		lettres: Color, rng: RandomNumberGenerator) -> void:
	if not k._fine():
		k.box(cx, y + 0.8, z, larg, h, 0.2, fond)
		return
	for x in [cx - larg * 0.35, cx + larg * 0.35]:
		k.box(x, y, z + 0.3, 0.12, 0.8 + h, 0.12, METAL_SOMBRE)
		k.box(x, y, z + 0.9, 0.1, 0.9, 0.1, METAL_SOMBRE)
	enseigne(k, cx, y + 0.8, z, larg, h, fond, lettres, rng)


## Logo rond (croix, étoile…) : disque coloré et motif clair, sur façade −Z.
static func pastille(k: BlocMesh, cx: float, y: float, z_face: float, r: float, fond: Color, motif: Color, forme := "croix") -> void:
	k.box(cx, y - r, z_face - 0.06, r * 2.0, r * 2.0, 0.1, fond)
	if not k._fine():
		return
	match forme:
		"croix":
			k.box(cx, y - r * 0.7, z_face - 0.13, r * 0.45, r * 1.4, 0.04, motif)
			k.box(cx, y - r * 0.22, z_face - 0.13, r * 1.4, r * 0.45, 0.04, motif)
		"etoile":
			k.box(cx, y - r * 0.6, z_face - 0.13, r * 0.35, r * 1.2, 0.04, motif)
			k.box(cx, y - r * 0.17, z_face - 0.13, r * 1.2, r * 0.35, 0.04, motif)
			k.box(cx, y - r * 0.6, z_face - 0.14, r * 0.8, r * 0.3, 0.04, motif)
		_:
			k.box(cx, y - r * 0.5, z_face - 0.13, r, r, 0.04, motif)


## Horloge sur façade −Z : cadran, aiguilles et cerclage doré.
static func horloge(k: BlocMesh, cx: float, y: float, z_face: float, r: float) -> void:
	k.box(cx, y - r - 0.08, z_face - 0.05, r * 2.0 + 0.16, r * 2.0 + 0.16, 0.08, Color("d4af37"))
	k.box(cx, y - r, z_face - 0.1, r * 2.0, r * 2.0, 0.06, Color("fbf8f0"))
	if not k._fine():
		return
	k.box(cx, y - 0.04, z_face - 0.15, 0.08, r * 0.8, 0.03, NOIR)
	k.box(cx + r * 0.27, y - 0.04, z_face - 0.15, r * 0.55, 0.08, 0.03, NOIR)


# --- Abords -----------------------------------------------------------------------------

## Arbre au houppier rond (plus doux que le cône) : tronc et deux boules.
static func arbre_rond(k: BlocMesh, x: float, y: float, z: float, s: float, col: Color) -> void:
	k.cylinder(x, y, z, 0.16 * s, 0.12 * s, 1.8 * s, 5, Color("7a5230"))
	var prof := [Vector2(0.0, 0.0), Vector2(1.1, 0.5), Vector2(1.3, 1.3), Vector2(1.0, 2.1), Vector2(0.0, 2.6)]
	var p1 := []
	for v: Vector2 in prof:
		p1.append(v * s)
	k.lathe(x, y + 1.4 * s, z, p1, 7, col)
	if k._fine():
		var p2 := []
		for v: Vector2 in prof:
			p2.append(v * s * 0.6)
		k.lathe(x + 0.6 * s, y + 3.0 * s, z - 0.3 * s, p2, 6, col.lightened(0.1))


## Jardinière en béton plantée d'arbustes et de fleurs.
static func jardiniere(k: BlocMesh, x: float, y: float, z: float, sx: float, sz: float, rng: RandomNumberGenerator) -> void:
	k.box(x, y, z, sx, 0.5, sz, BETON)
	if not k._fine():
		return
	k.box(x, y + 0.5, z, sx - 0.2, 0.05, sz - 0.2, Color("6b4f3a"))
	var n := maxi(1, int(maxf(sx, sz) / 0.8))
	for i in n:
		var t := -0.5 + (i + 0.5) / n
		var px := x + (t * sx if sx >= sz else 0.0)
		var pz := z + (t * sz if sz > sx else 0.0)
		k.dome(px, y + 0.5, pz, 0.38, 0.45, FEUILLAGES[rng.randi() % FEUILLAGES.size()], 6)
		if rng.randf() < 0.65:
			k.box(px + 0.1, y + 0.85, pz - 0.1, 0.18, 0.12, 0.18, FLEURS[rng.randi() % FLEURS.size()])


## Parasol de terrasse avec petite table.
static func parasol(k: BlocMesh, x: float, y: float, z: float, col: Color) -> void:
	k.box(x, y, z, 0.07, 2.3, 0.07, Color("f2efe6"))
	k.cylinder(x, y + 2.0, z, 1.3, 0.0, 0.55, 8, col)
	if k._fine():
		k.cylinder(x, y, z, 0.45, 0.45, 0.72, 8, Color("f2efe6"))
		for o in [Vector2(0.8, 0), Vector2(-0.8, 0)]:
			k.box(x + o.x, y, z + o.y, 0.4, 0.45, 0.4, NOIR.lightened(0.2))


## Lampadaire urbain.
static func lampadaire(k: BlocMesh, x: float, z: float, h := 4.2) -> void:
	if not k._fine():
		return
	k.cylinder(x, 0, z, 0.09, 0.07, h, 5, Color("3d4248"))
	k.box(x + 0.35, h - 0.05, z, 0.8, 0.08, 0.12, Color("3d4248"))
	k.box(x + 0.65, h - 0.2, z, 0.35, 0.15, 0.25, Color("fff2c4"))


## Banc (le long de x si along_x).
static func banc(k: BlocMesh, x: float, z: float, along_x := true) -> void:
	if not k._fine():
		return
	var lx := 1.6 if along_x else 0.5
	var lz := 0.5 if along_x else 1.6
	k.box(x, 0.4, z, lx, 0.08, lz, Color("a26b3c"))
	k.box(x + (0.0 if along_x else 0.22), 0.48, z + (0.22 if along_x else 0.0), lx if along_x else 0.06, 0.4, lz if not along_x else 0.06, Color("a26b3c"))
	for o in [-0.65, 0.65]:
		k.box(x + (o if along_x else 0.0), 0, z + (0.0 if along_x else o), 0.08 if along_x else 0.4, 0.4, 0.4 if along_x else 0.08, NOIR)


## Arceaux à vélos et quelques vélos colorés (roues sombres, cadre coloré).
static func velos(k: BlocMesh, x: float, z: float, n: int, rng: RandomNumberGenerator) -> void:
	if not k._fine():
		return
	for i in n:
		var px := x + i * 0.8
		k.box(px, 0, z, 0.06, 0.8, 0.7, METAL)
		if rng.randf() < 0.7:
			var c: Color = PARASOLS[rng.randi() % PARASOLS.size()]
			for o in [-0.5, 0.5]:
				k.box(px + 0.25, 0.0, z + o, 0.05, 0.66, 0.66, NOIR)
			k.box(px + 0.25, 0.45, z, 0.07, 0.08, 1.0, c)
			k.box(px + 0.25, 0.3, z - 0.1, 0.07, 0.45, 0.08, c)


## Haie taillée.
static func haie(k: BlocMesh, x: float, z: float, sx: float, sz: float, h := 1.1, col := Color("4f8c45")) -> void:
	k.box(x, 0, z, sx, h, sz, col)
	if k._fine():
		k.box(x, h, z, sx - 0.15, 0.12, sz - 0.15, col.lightened(0.08))


## Massif de fleurs posé au sol.
static func massif(k: BlocMesh, x: float, z: float, sx: float, sz: float, rng: RandomNumberGenerator) -> void:
	k.plate(x, z, sx, sz, Color("6b4f3a"), 0.0, 0.12)
	if not k._fine():
		return
	var n := maxi(2, int(sx * sz / 0.7))
	for i in mini(n, 14):
		var px := x + rng.randf_range(-sx / 2.0 + 0.2, sx / 2.0 - 0.2)
		var pz := z + rng.randf_range(-sz / 2.0 + 0.2, sz / 2.0 - 0.2)
		if i % 2 == 0:
			k.dome(px, 0.12, pz, 0.3, 0.35, FEUILLAGES[rng.randi() % FEUILLAGES.size()], 5)
		else:
			k.box(px, 0.12, pz, 0.22, 0.3, 0.22, FLEURS[rng.randi() % FLEURS.size()])


## Mât et drapeau.
static func drapeau(k: BlocMesh, x: float, z: float, h: float, col: Color, col2 := Color.WHITE) -> void:
	k.box(x, 0, z, 0.14, h, 0.14, Color("d9d9d9"))
	if not k._fine():
		return
	k.box(x + 0.75, h - 1.0, z, 1.4, 0.45, 0.04, col)
	k.box(x + 0.75, h - 1.45, z, 1.4, 0.45, 0.04, col2)


## Places de parking peintes (lignes perpendiculaires à la façade).
static func parking(k: BlocMesh, cx: float, cz: float, sx: float, sz: float, n: int, rng: RandomNumberGenerator, voitures := true) -> void:
	k.plate(cx, cz, sx, sz, Color("5d6066"), 0.0, 0.06)
	if not k._fine():
		return
	var pas := sx / n
	for i in n + 1:
		k.plate(cx - sx / 2.0 + i * pas, cz, 0.12, sz * 0.8, Color("f2f2f2"), 0.06, 0.02)
	if voitures:
		for i in n:
			if rng.randf() < 0.55:
				var c: Color = [Color("d64545"), Color("e8e8e8"), Color("2f5d9f"), Color("3a3d42"), Color("f2c14e"), Color("4b9b6e")][rng.randi() % 6]
				var x := cx - sx / 2.0 + (i + 0.5) * pas
				k.box(x, 0.2, cz, 1.7, 0.7, 4.0, c)
				k.box(x, 0.9, cz + 0.2, 1.5, 0.55, 2.1, Color("41505f"))


# --- Bâtiments de la bible (StyleBuilder) -----------------------------------------------

## Archétypes habillés ici (les petits commerces ont Devantures).
const ARCHS_BIBLE := ["immeuble", "tour", "gratte_ciel", "bureaux", "hopital", "ecole", "grand_magasin",
	"usine", "entrepot", "atelier", "gare", "theatre"]


## Habillage d'un bâtiment générique de la bible, appelé par StyleBuilder de près :
## équipements du toit-terrasse, entrée (marquise, porte vitrée, marches),
## montants des façades vitrées, enseignes et abords plantés. Les styles
## traditionnels et antiques gardent leurs propres ornements (StyleKit).
static func habiller_bible(k: BlocMesh, s: Dictionary, p: Dictionary, arch: String, w: float, d: float, bw: float, bd: float,
		cz: float, y0: float, top: float, tw: float, td: float, roof: String, floors: int, fh: float) -> void:
	if not k._fine() or arch not in ARCHS_BIBLE:
		return
	var era := String(s.era)
	if era in ["antique", "traditionnel"]:
		return
	var rng := rng_pour(k, "%s|%s" % [String(p.get("style_id", "")), arch])
	var mur: Color = p.wall
	var accent: Color = p.get("enseigne", Color("2a6fdb"))
	var moderne := era in ["moderne", "contemporain", "futuriste"]
	var glassy := moderne and era != "moderne" and arch in ["tour", "gratte_ciel", "bureaux", "grand_magasin"]
	var fz := cz - bd / 2.0
	# Toit-terrasse : l'acrotère est déjà là (StyleBuilder._roof).
	if roof == "flat" and not bool(s.get("green_roof", false)):
		var mode := "technique"
		match arch:
			"immeuble": mode = ["mixte", "jardin", "solaire", "technique"][k.variant % 4]
			"ecole": mode = "solaire"
			"hopital", "bureaux": mode = "technique" if k.variant % 2 == 0 else "mixte"
			"tour": mode = "technique" if k.variant % 2 == 0 else "jardin"
		equiper_toit(k, 0, top + 0.25, cz, tw - 0.6, td - 0.6, mur if not glassy else Color(p.trim), rng,
			{"mode": mode, "antenne": arch in ["tour", "gratte_ciel"], "edicule": tw >= 9.0 and td >= 9.0})
	# Façades vitrées : montants verticaux sur toute la hauteur.
	if glassy:
		var h := top - y0
		var ntiers := 1
		if s.get("setback", false) and floors >= 12:
			ntiers = 3
		elif arch == "gratte_ciel":
			ntiers = 2
		if ntiers == 1:
			montants(k, 0, cz, tw, td, y0, h, Color(p.trim), 2.0)
	elif era in ["moderne", "contemporain"] and arch in ["tour", "bureaux", "hopital", "immeuble", "ecole"] \
			and absf(tw - bw) < 0.01 and not bool(s.get("balcony", false)):
		# Trame verticale en relief sur les bandeaux de fenêtres.
		montants(k, 0, cz, bw, bd, y0, top - y0, mur.lightened(0.18), 3.0)
	# Entrée.
	if moderne or arch in ["hopital", "ecole", "bureaux", "gare"]:
		if arch not in ["usine", "entrepot", "atelier", "gare", "theatre"]:
			var larg := clampf(bw * 0.35, 3.0, 9.0)
			porte_vitree(k, 0, fz - 0.08, minf(larg * 0.45, 3.2), 2.6)
			marquise(k, 0, y0 + 3.0, fz - 0.1, larg, 1.0 if d - bd < 2.6 else 1.6, accent, false)
			marches(k, 0, fz - 0.1, minf(larg * 0.6, 3.0), 2)
		if arch in ["bureaux", "gratte_ciel", "grand_magasin"] and roof == "flat":
			enseigne_toit(k, -tw * 0.15, top + 0.25, cz - td / 2.0 + 0.8, minf(tw * 0.5, 10.0), 1.2, accent, Color("fbf8f0"), rng)
		if arch == "ecole":
			enseigne(k, 0, y0 + 3.6, fz, minf(bw * 0.3, 8.0), 0.9, accent, Color("fbf8f0"), rng)
		if arch in ["usine", "entrepot", "atelier"]:
			enseigne(k, bw * 0.2, minf(top - 1.6, y0 + 5.0), fz, minf(bw * 0.4, 10.0), 1.0, accent, Color("2e3136"), rng)
	# Abords dans la marge devant la façade (1 m) et aux angles.
	var marge := (d - bd) / 2.0 - cz
	if marge >= 0.8 and arch not in ["usine", "entrepot", "atelier"]:
		var jz := fz - minf(marge, 1.2) / 2.0 - 0.05
		for sgn in [-1.0, 1.0]:
			jardiniere(k, sgn * minf(bw * 0.32, 7.0), y0 * 0.0, jz, minf(bw * 0.18, 3.0), 0.7, rng)
		lampadaire(k, -bw / 2.0 + 0.4, fz - 0.5, 3.8)
		if arch in ["immeuble", "ecole", "bureaux"]:
			velos(k, bw * 0.4 - 1.2, fz - 0.6, 3, rng)
	if arch in ["hopital", "ecole", "bureaux", "tour", "gratte_ciel", "theatre", "gare"] and w - bw >= 1.6:
		for c in [Vector2(-w / 2.0 + 1.0, d / 2.0 - 1.0), Vector2(w / 2.0 - 1.0, d / 2.0 - 1.0)]:
			arbre_rond(k, c.x, 0.0, c.y, 0.55, FEUILLAGES[rng.randi() % FEUILLAGES.size()])


## Montants verticaux d'une façade vitrée, sur les quatre côtés.
static func montants(k: BlocMesh, cx: float, cz: float, sx: float, sz: float, y0: float, h: float, col: Color, pas := 2.0) -> void:
	for side in 4:
		var long := sx if side % 2 == 0 else sz
		var n := maxi(2, int(long / pas))
		for j in range(1, n):
			var t := -long / 2.0 + j * long / n
			match side:
				0: k.box(cx + t, y0, cz - sz / 2.0 - 0.06, 0.12, h, 0.14, col)
				2: k.box(cx + t, y0, cz + sz / 2.0 + 0.06, 0.12, h, 0.14, col)
				1: k.box(cx + sx / 2.0 + 0.06, y0, cz + t, 0.14, h, 0.12, col)
				3: k.box(cx - sx / 2.0 - 0.06, y0, cz + t, 0.14, h, 0.12, col)
