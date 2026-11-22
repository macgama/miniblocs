class_name GestionDiorama
extends Node3D
## Maquette 3D du mode gestion, vue en isométrique : le rez-de-chaussée du
## bâtiment coupé comme une maison de poupée (murs du fond hauts avec leurs
## fenêtres, cloisons basses, façade rasée), ses pièces meublées selon leur
## niveau, les objets achetés (GestionModeles), le personnel à son poste, les
## clients qui vont et viennent, la rue et ses voitures.
##
## Tout est construit en code (LpKit, figurines des métiers) à partir de
## GestionTypes : un nouveau genre de bâtiment n'a besoin que de ses pièces,
## de ses objets et de ses décors de base (fonctions _decor_<nom>). Les
## pièces pas encore construites sont des emplacements de chantier.
##
## Coordonnées : mètres, x vers la droite, z vers la rue (la caméra regarde
## depuis l'angle x+ z+). Les décors et les objets donnent les « places » où
## les clients s'installent : {pos, rot, assis, avant (points de passage)}.

signal client_clique(index: int)

const H_FOND := 2.8
const H_INTERIEUR := 0.9
const H_CLOISON := 0.55
const H_DEVANT := 0.45
const EP := 0.18
const PORTE := 1.5
const VITESSE := 1.5
## Chambres : rangées de cellules le long du couloir.
const RANGEES := 6
const CELLULE_L := 10.0

var genre := ""
var niveaux: Dictionary = {}
var etoiles := 3
## Objets achetés : pid → [oid].
var objets: Dictionary = {}
## Pannes en cours : [{piece, texte}].
var pannes: Array = []
var titre := ""
## Places des clients par pièce : pid → [{pos, rot, assis, avant}].
var places: Dictionary = {}
## Places prises : "pid:i" → true.
var _prises: Dictionary = {}
## Employés visibles : [Figurine].
var employes: Array = []
## Clients : [{fig, chemin, etat, piece, place, pl, attente, bulle}].
var clients: Array = []
## Postes vacants affichés : pid → Label3D.
var vacants: Dictionary = {}
## Étiquettes des pannes (dans l'ordre de `pannes`).
var pannes_l: Array = []
var _statique: Node3D
var _gens: Node3D
var _etiquettes: Node3D
var _rue_n: Node3D
var _surbrillance: MeshInstance3D
var _materiaux := {}
var _voitures: Array = []
## Engins de la remise (caserne) : [{n, model, etat ("gare" | "part" | "absent"), feux}].
var engins: Array = []
var _engins_n: Node3D
var _feux_mat: Dictionary = {}
var _alerte_t := 0.0
var _alerte_l: Label3D
var _t := 0.0
var _n_client := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 4242
	_materiaux = {"base": LpKit.vertex_material(0.85), "eau": _materiau_eau(), "verre": _materiau_verre(), "lumiere": _materiau_lumiere()}
	for n in ["Decor", "Gens", "Etiquettes", "Rue", "Engins"]:
		var nd := Node3D.new()
		nd.name = n
		add_child(nd)
	_statique = get_node("Decor")
	_gens = get_node("Gens")
	_etiquettes = get_node("Etiquettes")
	_rue_n = get_node("Rue")
	_engins_n = get_node("Engins")


static func _materiau_eau() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic_specular = 0.8
	return m


static func _materiau_verre() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.2
	return m


static func _materiau_lumiere() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _vider(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# --- Construction ------------------------------------------------------------------------------

## Reconstruit le décor (après une amélioration, un achat, une panne). Les
## clients restent.
func construire(g: String, niv: Dictionary, nb_etoiles := 3, objs: Dictionary = {}, pannes_: Array = [], titre_ := "") -> void:
	genre = g
	niveaux = niv.duplicate()
	etoiles = nb_etoiles
	objets = objs.duplicate(true)
	pannes = pannes_.duplicate(true)
	titre = titre_
	_vider(_statique)
	_vider(_etiquettes)
	vacants.clear()
	places.clear()
	pannes_l.clear()
	var k := LpKit.new(7)
	k.jitter = 0.025
	var gd := GestionTypes.genre(g)
	_sol(k, gd)
	for pid in GestionTypes.ordre(g):
		var p := GestionTypes.piece(g, String(pid))
		var n := int(niveaux.get(pid, 0))
		var r: Array = p.rect
		var dehors := GestionTypes.est_dehors(g, String(pid))
		if n <= 0:
			_chantier(k, r, dehors)
			_etiquette_chantier(String(pid), p)
			continue
		_sol_piece(k, r, p, n)
		var f := "_decor_" + String(p.get("decor", ""))
		var pl: Array = []
		if has_method(f):
			pl = call(f, k, r, n)
		else:
			pl = DecorsRestaurant.dessiner(self, k, String(p.get("decor", "")), r, n)
		pl.append_array(_objets(k, String(pid), r, n))
		places[String(pid)] = pl
	_murs(k, gd)
	_facade(k, gd)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit(_materiaux)
	_statique.add_child(mi)
	_surbrillance = MeshInstance3D.new()
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.no_depth_test = true
	sm.render_priority = 2
	_surbrillance.material_override = sm
	_surbrillance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surbrillance.visible = false
	_statique.add_child(_surbrillance)
	_enseigne(gd)
	_etiquettes_pannes()
	if _voitures.is_empty():
		_creer_voitures(gd)
	# Les clients déjà installés dans une pièce disparue repartent.
	for c in clients:
		if String(c.piece) != "" and not places.has(String(c.piece)):
			_partir(c)


func surligner(pid: String) -> void:
	if _surbrillance == null:
		return
	var p := GestionTypes.piece(genre, pid)
	if p.is_empty():
		_surbrillance.visible = false
		return
	# Cadre jaune autour de la pièce choisie (vu à travers les murs).
	var r: Array = p.rect
	var k := LpKit.new(3)
	k.jitter = 0.0
	var c := Color("ffd166")
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := x0 + float(r[2])
	var z1 := z0 + float(r[3])
	var e := 0.22
	k.box(Vector3((x0 + x1) * 0.5, 0.12, z0), Vector3(x1 - x0 + e, 0.08, e), c, 0.0, false)
	k.box(Vector3((x0 + x1) * 0.5, 0.12, z1), Vector3(x1 - x0 + e, 0.08, e), c, 0.0, false)
	k.box(Vector3(x0, 0.12, (z0 + z1) * 0.5), Vector3(e, 0.08, z1 - z0 + e), c, 0.0, false)
	k.box(Vector3(x1, 0.12, (z0 + z1) * 0.5), Vector3(e, 0.08, z1 - z0 + e), c, 0.0, false)
	_surbrillance.mesh = k.commit({"base": _surbrillance.material_override})
	_surbrillance.visible = true


## Pièce sous un point du sol ("" : aucune).
func piece_en(p: Vector3) -> String:
	for pid in GestionTypes.ordre(genre):
		var r: Array = GestionTypes.piece(genre, String(pid)).rect
		if p.x >= r[0] and p.x <= r[0] + r[2] and p.z >= r[1] and p.z <= r[1] + r[3]:
			return String(pid)
	return ""


func centre(pid: String) -> Vector3:
	var p := GestionTypes.piece(genre, pid)
	if p.is_empty():
		return Vector3.ZERO
	var r: Array = p.rect
	return Vector3(r[0] + r[2] * 0.5, 0.0, r[1] + r[3] * 0.5)


## Rectangle de tout le terrain (bâtiment et pièces du dehors) : [x0, z0, x1, z1].
func emprise() -> Array:
	var x0 := 0.0
	var z0 := 0.0
	var x1 := 0.0
	var z1 := 0.0
	for pid in GestionTypes.ordre(genre):
		var r: Array = GestionTypes.piece(genre, String(pid)).rect
		x0 = minf(x0, r[0])
		z0 = minf(z0, r[1])
		x1 = maxf(x1, float(r[0]) + float(r[2]))
		z1 = maxf(z1, float(r[1]) + float(r[3]))
	return [x0, z0, x1, z1]


func _q(k: LpKit, x0: float, z0: float, x1: float, z1: float, y: float, col: Color) -> void:
	k.quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), col, Vector3.UP)


func _m(k: LpKit, nom: String, x: float, z: float, rot := 0.0, teinte := Color.WHITE) -> void:
	GestionModeles.dessiner(k, nom, Vector3(x, 0, z), rot, teinte)


func _arbre(k: LpKit, t: Vector3, s := 1.0) -> void:
	k.tube(t, t + Vector3(0, 1.4 * s, 0), 0.16 * s, 0.12 * s, 6, Color("7a5536"))
	k.blob(t + Vector3(0, 2.4 * s, 0), Vector3(1.3, 1.3, 1.3) * s, Color("3f7d3a"), Color("6fae55"), 0.15, 1)


func _sol(k: LpKit, gd: Dictionary) -> void:
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	var porte: Vector2 = gd.get("porte", Vector2(plan.x * 0.5, plan.y))
	var e := emprise()
	var xa := float(e[0]) - 10.0
	var xb := float(e[2]) + 10.0
	var rz := plan.y + 12.4
	# Pelouse, parvis devant la façade, trottoirs, rue et son marquage.
	k.box(Vector3((xa + xb) * 0.5, -0.06, (float(e[1]) - 8.0 + rz + 12.0) * 0.5), Vector3(xb - xa, 0.1, rz + 20.0 - float(e[1])), Color("5f9e4c"), 0.0, false)
	for i in int((xb - xa) / 2.0):
		if i % 2 == 0:
			_q(k, xa + i * 2.0, float(e[1]) - 8.0, xa + i * 2.0 + 2.0, plan.y, -0.008, Color("66a652"))
	k.box(Vector3(plan.x * 0.5, 0.0, plan.y + 1.5), Vector3(plan.x + 1.0, 0.05, 3.0), Color("d9d1c1"), 0.0, false)
	for i in int(plan.x):
		_q(k, float(i) + 0.03, plan.y + 0.03, float(i) + 0.97, plan.y + 2.97, 0.028, Color("e2dacb") if i % 2 == 0 else Color("d3cab8"))
	# Allée qui longe la façade de droite jusqu'au jardin et à la piscine.
	k.box(Vector3(plan.x + 1.0, 0.0, plan.y * 0.5 + 1.5), Vector3(2.0, 0.05, plan.y + 3.0), Color("d9d1c1"), 0.0, false)
	k.box(Vector3((xa + xb) * 0.5, -0.01, rz - 0.7), Vector3(xb - xa, 0.08, 1.4), Color("cfcac0"), 0.0, false)
	k.box(Vector3((xa + xb) * 0.5, 0.0, rz), Vector3(xb - xa, 0.1, 0.12), Color("9a958c"), 0.0, false)
	k.box(Vector3((xa + xb) * 0.5, -0.03, rz + 3.0), Vector3(xb - xa, 0.06, 6.0), Color("55595f"), 0.0, false)
	for i in int((xb - xa) / 5.0):
		k.box(Vector3(xa + 2.0 + i * 5.0, 0.01, rz + 3.0), Vector3(2.2, 0.02, 0.16), Color("f2f2ee"), 0.0, false)
	k.box(Vector3((xa + xb) * 0.5, 0.0, rz + 6.0), Vector3(xb - xa, 0.1, 0.12), Color("9a958c"), 0.0, false)
	k.box(Vector3((xa + xb) * 0.5, -0.01, rz + 6.7), Vector3(xb - xa, 0.08, 1.4), Color("cfcac0"), 0.0, false)
	# Passage piéton devant l'entrée.
	for i in 6:
		k.box(Vector3(porte.x, 0.01, rz + 0.6 + i * 0.95), Vector3(2.6, 0.02, 0.5), Color("f2f2ee"), 0.0, false)
	# Allée de la porte à la rue.
	k.box(Vector3(porte.x, 0.03, (plan.y + rz) * 0.5), Vector3(2.2, 0.05, rz - plan.y), Color("d8cfbe"), 0.0, false)
	# Réverbères sur le trottoir, arbres de l'autre côté de la rue.
	for i in int((xb - xa) / 12.0):
		var x := xa + 6.0 + i * 12.0
		_m(k, "lampadaire", x, rz - 1.1)
		_arbre(k, Vector3(x + 6.0, 0, rz + 7.6), 0.9)
	# Arbres et haies autour du terrain.
	for t in [Vector3(-4, 0, 2), Vector3(-4, 0, 10), Vector3(-4, 0, 18), Vector3(-5, 0, 26), Vector3(float(e[2]) + 3.0, 0, 2.0),
			Vector3(float(e[2]) + 3.5, 0, 12.0), Vector3(float(e[2]) + 3.0, 0, 22.0), Vector3(20, 0, -4), Vector3(34, 0, -4.5)]:
		_arbre(k, t)
	for i in int((float(e[2]) - plan.x - 2.0) / 1.0):
		k.box(Vector3(plan.x + 2.5 + i * 1.0, 0.45, -0.6), Vector3(0.9, 0.9, 0.9), Color("4f8f45"), 0.08)
	for i in int(float(e[3]) - plan.y - 0.5):
		k.box(Vector3(float(e[2]) + 0.6, 0.45, plan.y + 0.5 + i * 1.0), Vector3(0.9, 0.9, 0.9), Color("4f8f45"), 0.08)


## Sol d'une pièce, avec son motif (damier, parquet, moquette, carrelage,
## dalles, gazon). Les niveaux élevés ont un sol plus riche.
func _sol_piece(k: LpKit, r: Array, p: Dictionary, n: int) -> void:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := x0 + float(r[2])
	var z1 := z0 + float(r[3])
	var c := Color(String(p.get("sol", "cccccc")))
	if n >= 4:
		c = c.lerp(Color("f5e6c4"), 0.1)
	var y := 0.062
	k.box(Vector3((x0 + x1) * 0.5, 0.03, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.06, z1 - z0), c.darkened(0.15), 0.0, false)
	match String(p.get("motif", "")):
		"damier":
			for i in int(x1 - x0):
				for j in int(z1 - z0):
					var col := c if (i + j) % 2 == 0 else c.darkened(0.22 if n < 3 else 0.5)
					_q(k, x0 + i, z0 + j, x0 + i + 1, z0 + j + 1, y, col)
		"parquet":
			var nb := int((z1 - z0) / 0.5)
			for j in nb:
				var dx := 0.0 if j % 2 == 0 else 1.0
				var x := x0 - dx
				var m := 0
				while x < x1:
					var xa := maxf(x, x0)
					var xb := minf(x + 2.0, x1)
					var col: Color = [c, c.darkened(0.06), c.lightened(0.05)][(j + m) % 3]
					_q(k, xa + 0.01, z0 + j * 0.5 + 0.015, xb - 0.01, z0 + j * 0.5 + 0.485, y, col)
					x += 2.0
					m += 1
		"moquette":
			_q(k, x0 + 0.35, z0 + 0.35, x1 - 0.35, z1 - 0.35, y, c)
			if n >= 3:
				var bord := Color("d4af37") if n >= 4 else c.darkened(0.3)
				_q(k, x0 + 0.5, z0 + 0.5, x1 - 0.5, z0 + 0.6, y + 0.002, bord)
				_q(k, x0 + 0.5, z1 - 0.6, x1 - 0.5, z1 - 0.5, y + 0.002, bord)
				_q(k, x0 + 0.5, z0 + 0.5, x0 + 0.6, z1 - 0.5, y + 0.002, bord)
				_q(k, x1 - 0.6, z0 + 0.5, x1 - 0.5, z1 - 0.5, y + 0.002, bord)
		"carrelage":
			var t := 0.6
			for i in int((x1 - x0) / t):
				for j in int((z1 - z0) / t):
					var col := c if (i * 7 + j * 3) % 5 != 0 else c.lightened(0.08)
					_q(k, x0 + i * t + 0.03, z0 + j * t + 0.03, x0 + (i + 1) * t - 0.03, z0 + (j + 1) * t - 0.03, y, col)
		"dalles":
			for i in int(x1 - x0):
				for j in int(z1 - z0):
					var col := c if (i + 2 * j) % 3 != 0 else c.darkened(0.06)
					_q(k, x0 + i + 0.04, z0 + j + 0.04, x0 + i + 0.96, z0 + j + 0.96, y, col)
		"gazon":
			for i in int(x1 - x0):
				_q(k, x0 + i, z0, x0 + i + 1, z1, y, c if i % 2 == 0 else c.lightened(0.08))
		_:
			_q(k, x0, z0, x1, z1, y, c)


## Emplacement vide : gravier, piquets et ruban.
func _chantier(k: LpKit, r: Array, dehors: bool) -> void:
	var c := Vector3(r[0] + r[2] * 0.5, 0.0, r[1] + r[3] * 0.5)
	k.box(c + Vector3(0, 0.02, 0), Vector3(r[2] - 0.2, 0.04, r[3] - 0.2), Color("bfb5a3") if not dehors else Color("a9b98f"), 0.0, false)
	for i in 6:
		var p := c + Vector3(rng.randf_range(-0.35, 0.35) * r[2], 0.0, rng.randf_range(-0.35, 0.35) * r[3])
		k.stone(p + Vector3(0, 0.08, 0), Vector3(0.35, 0.16, 0.3), Color("9c9282"))
	var n := 0
	var pts := [Vector3(r[0] + 0.3, 0, r[1] + 0.3), Vector3(r[0] + r[2] - 0.3, 0, r[1] + 0.3),
		Vector3(r[0] + r[2] - 0.3, 0, r[1] + r[3] - 0.3), Vector3(r[0] + 0.3, 0, r[1] + r[3] - 0.3)]
	for i in 4:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 4]
		k.box(a + Vector3(0, 0.45, 0), Vector3(0.1, 0.9, 0.1), Color("e76f51"), 0.0, false)
		var l := a.distance_to(b)
		var segs := maxi(1, int(l / 1.2))
		for s in segs:
			if s % 2 == 0:
				var m := a.lerp(b, (float(s) + 0.5) / float(segs))
				var sz := Vector3(l / segs, 0.08, 0.04) if absf(b.x - a.x) > 0.01 else Vector3(0.04, 0.08, l / segs)
				k.box(m + Vector3(0, 0.75, 0), sz, Color("f4a261") if n % 2 == 0 else Color("f1f1f1"), 0.0, false)
				n += 1
	# Panneau « bientôt ».
	k.box(c + Vector3(0, 0.5, 0), Vector3(0.08, 1.0, 0.08), Color("6b4a32"), 0.0, false)
	k.box(c + Vector3(0, 1.05, 0), Vector3(1.2, 0.6, 0.06), Color("f4d35e"))


func _etiquette_chantier(pid: String, p: Dictionary) -> void:
	var l := Label3D.new()
	l.text = "+ %s" % String(p.get("nom", pid))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.pixel_size = 0.014
	l.outline_size = 14
	l.modulate = Color("fff3c4")
	l.outline_modulate = Color(0.15, 0.12, 0.05, 0.9)
	l.no_depth_test = true
	l.position = centre(pid) + Vector3(0, 1.9, 0)
	l.name = "Chantier_" + pid
	_etiquettes.add_child(l)


## Murs de toutes les pièces du dedans, avec les portes (GestionTypes "porte") :
## murs du fond hauts et percés de fenêtres, cloisons basses, façade rasée.
func _murs(k: LpKit, gd: Dictionary) -> void:
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	var couleur := Color(String(gd.get("murs", "e9dcc6")))
	var dehors := Color(String(gd.get("murs_dehors", "c9876a")))
	var portes: Array = [gd.get("porte", Vector2(plan.x * 0.5, plan.y))]
	for pg in gd.get("portes_garage", []):
		portes.append(Vector3(float(pg[0]), float(pg[1]), float(pg[2])))
	for pid in GestionTypes.ordre(genre):
		var p := GestionTypes.piece(genre, String(pid))
		if p.has("porte"):
			portes.append(Vector2(p.porte[0], p.porte[1]))
	var faits := {}
	for pid in (gd.get("pieces", {}) as Dictionary):
		var r: Array = GestionTypes.piece(genre, String(pid)).rect
		var x0 := float(r[0])
		var z0 := float(r[1])
		var x1 := x0 + float(r[2])
		var z1 := z0 + float(r[3])
		for side in [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x0, z0), Vector2(x0, z1)],
				[Vector2(x0, z1), Vector2(x1, z1)], [Vector2(x1, z0), Vector2(x1, z1)]]:
			var a: Vector2 = side[0]
			var b: Vector2 = side[1]
			var cle := "%s|%s" % [a, b]
			if faits.has(cle):
				continue
			faits[cle] = true
			var h := H_INTERIEUR
			var col := couleur
			var fond := (a.x == b.x and a.x <= 0.01) or (a.y == b.y and a.y <= 0.01)
			if fond:
				h = H_FOND
			elif (a.x == b.x and a.x >= plan.x - 0.01) or (a.y == b.y and a.y >= plan.y - 0.01):
				h = H_DEVANT
				col = dehors
			_mur(k, a, b, h, col, portes)
			if fond:
				_fenetres(k, a, b, String(pid))


func _mur(k: LpKit, a: Vector2, b: Vector2, h: float, col: Color, portes: Array) -> void:
	var horiz := absf(b.x - a.x) > 0.01
	var t0 := a.x if horiz else a.y
	var t1 := b.x if horiz else b.y
	var fixe := a.y if horiz else a.x
	# Trous des portes sur ce mur.
	var trous: Array = []
	for pt in portes:
		# Vector2 : porte ordinaire ; Vector3 (x, z, largeur) : porte de garage.
		var q := Vector2(pt.x, pt.y)
		var larg: float = pt.z if pt is Vector3 else PORTE
		var sur := absf((q.y if horiz else q.x) - fixe) < 0.05
		var t := q.x if horiz else q.y
		if sur and t > t0 and t < t1:
			trous.append([t - larg * 0.5, t + larg * 0.5])
	trous.sort_custom(func(u: Array, v: Array) -> bool: return u[0] < v[0])
	var debut := t0
	var morceaux: Array = []
	for tr in trous:
		if tr[0] > debut:
			morceaux.append([debut, tr[0]])
		debut = maxf(debut, tr[1])
	if debut < t1:
		morceaux.append([debut, t1])
	for m in morceaux:
		var l := float(m[1]) - float(m[0])
		if l < 0.05:
			continue
		var mid := (float(m[0]) + float(m[1])) * 0.5
		var pos := Vector3(mid, h * 0.5, fixe) if horiz else Vector3(fixe, h * 0.5, mid)
		var sz := Vector3(l + EP, h, EP) if horiz else Vector3(EP, h, l + EP)
		k.box(pos, sz, col, 0.0, false)
		# Chaperon plus foncé sur le dessus (lisible de haut).
		k.box(pos + Vector3(0, h * 0.5 + 0.02, 0), Vector3(sz.x + 0.02, 0.04, sz.z + 0.02), col.darkened(0.25), 0.0, false)
		# Plinthe : les murs ne sont pas des aplats.
		k.box(pos + Vector3(0, -h * 0.5 + 0.08, 0), Vector3(sz.x + 0.03, 0.16, sz.z + 0.03), col.darkened(0.3), 0.0, false)
		if h >= H_FOND:
			k.box(pos + Vector3(0, h * 0.5 - 0.25, 0), Vector3(sz.x + 0.03, 0.08, sz.z + 0.03), col.darkened(0.12), 0.0, false)
	# Chambranles des portes.
	for tr in trous:
		for t in tr:
			var pp := Vector3(float(t), h * 0.5, fixe) if horiz else Vector3(fixe, h * 0.5, float(t))
			k.box(pp, Vector3(0.1, h + 0.04, EP + 0.06), Color("7a5536") if h > H_DEVANT else col.darkened(0.3), 0.0, false)


## Fenêtres, rideaux et appliques d'un mur du fond, réparties sur la pièce.
func _fenetres(k: LpKit, a: Vector2, b: Vector2, pid: String) -> void:
	var horiz := absf(b.x - a.x) > 0.01
	var t0 := a.x if horiz else a.y
	var t1 := b.x if horiz else b.y
	var n := int(niveaux.get(pid, 0))
	var rideau: Color = [Color("c9ada7"), Color("c9ada7"), Color("a8dadc"), Color("b5838d"), Color("7b2d26"), Color("6d597a")][clampi(n, 0, 5)]
	var pas := 3.2
	if pid == "chambres" and not horiz:
		pas = float(GestionTypes.piece(genre, pid).rect[3]) / RANGEES
	var nb := maxi(1, int((t1 - t0) / pas))
	var marge := ((t1 - t0) - nb * pas) * 0.5
	for i in nb:
		var t := t0 + marge + pas * (i + 0.5)
		if pid == "chambres" and not horiz:
			t = t0 + pas * i + pas * 0.82
		var p := Vector3(t, 0, a.y + EP * 0.5) if horiz else Vector3(a.x + EP * 0.5, 0, t)
		var rot := 0.0 if horiz else PI * 0.5
		var sauve := k.xf
		k.xf = Transform3D(Basis(Vector3.UP, rot), p)
		k.box(Vector3(0, 1.65, 0.02), Vector3(1.4, 1.3, 0.05), Color("f4f1ea"), 0.0, false)
		k.box(Vector3(0, 1.65, 0.05), Vector3(1.22, 1.12, 0.02), Color("9fcde3"), 0.0, false)
		k.box(Vector3(0, 1.65, 0.07), Vector3(0.05, 1.12, 0.02), Color("f4f1ea"), 0.0, false)
		k.box(Vector3(0, 1.65, 0.07), Vector3(1.22, 0.05, 0.02), Color("f4f1ea"), 0.0, false)
		k.box(Vector3(0, 0.98, 0.1), Vector3(1.5, 0.06, 0.18), Color("e3ddd0"), 0.0, false)
		if n >= 2:
			k.box(Vector3(-0.72, 1.6, 0.1), Vector3(0.22, 1.45, 0.06), rideau)
			k.box(Vector3(0.72, 1.6, 0.1), Vector3(0.22, 1.45, 0.06), rideau)
			k.box(Vector3(0, 2.36, 0.1), Vector3(1.8, 0.05, 0.05), Color("8a5a3b"), 0.0, false)
		if n >= 3 and i < nb - 1:
			# Applique entre deux fenêtres.
			k.box(Vector3(pas * 0.5, 2.05, 0.06), Vector3(0.12, 0.2, 0.08), Color("d4af37"), 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(pas * 0.5, 2.2, 0.1), Vector3(0.22, 0.16, 0.14), Color("ffe8a3"), 0.0, false)
			k.layer = "base"
		k.xf = sauve


## Entrée, jardinières, vélos, mâts et drapeaux devant la façade.
func _facade(k: LpKit, gd: Dictionary) -> void:
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	var porte: Vector2 = gd.get("porte", Vector2(plan.x * 0.5, plan.y))
	var nr := int(niveaux.get(String(gd.get("accueil", "reception")), 1))
	# Marches et paillasson.
	k.box(Vector3(porte.x, 0.05, porte.y + 0.45), Vector3(2.4, 0.1, 0.9), Color("bdb5a6"))
	k.box(Vector3(porte.x, 0.08, porte.y - 0.6), Vector3(1.4, 0.02, 0.8), Color("3d3a36"), 0.0, false)
	# Jardinières le long de la façade.
	for x in [2.0, 6.0, 10.0, 22.0, 30.0, 34.0, 40.0]:
		if absf(x - porte.x) < 3.0 or x > plan.x - 1.0 or not libre(Vector2(x, plan.y + 0.55)):
			continue
		k.box(Vector3(x, 0.25, plan.y + 0.55), Vector3(1.6, 0.5, 0.6), Color("8d6e63"))
		for i in 3:
			k.blob(Vector3(x - 0.5 + i * 0.5, 0.62, plan.y + 0.55), Vector3(0.28, 0.25, 0.25), Color("2f6b35"), [Color("e76f51"), Color("f4d35e"), Color("ef476f")][(int(x) + i) % 3], 0.2, 0)
	# Range-vélos et deux vélos.
	var vx := porte.x + 9.0 if libre(Vector2(porte.x + 9.7, plan.y + 2.3), 1.5) else porte.x - 9.0
	if libre(Vector2(vx + 0.7, plan.y + 2.3), 1.2):
		for i in 3:
			k.box(Vector3(vx + i * 0.7, 0.35, plan.y + 2.3), Vector3(0.05, 0.7, 0.5), Color("6c757d"), 0.0, false)
		for i in 2:
			_m(k, "velo", vx + 0.35 + i * 0.7, plan.y + 2.3, PI * 0.5)
	# Banc et poubelle.
	var bx := porte.x - 6.0 if libre(Vector2(porte.x - 6.0, plan.y + 2.4), 1.2) else porte.x + 2.6
	if libre(Vector2(bx, plan.y + 2.4), 0.8):
		_m(k, "banc", bx, plan.y + 2.4, PI)
		k.lathe(Vector3(bx + 1.6, 0, plan.y + 2.5), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.28, 0.8), Vector2(0.0, 0.8)], 8, Color("3a5a40"))
	# Mâts et drapeaux (3 étoiles et plus).
	if etoiles >= 3 and libre(Vector2(porte.x + 4.5, plan.y + 1.4), 1.6):
		var cols := [Color("e63946"), Color("1d3557"), Color("f4d35e")]
		for i in 3:
			var x := porte.x + 3.2 + i * 1.3
			k.tube(Vector3(x, 0, plan.y + 1.4), Vector3(x, 5.0, plan.y + 1.4), 0.05, 0.04, 6, Color("dee2e6"))
			k.box(Vector3(x + 0.5, 4.5, plan.y + 1.4), Vector3(1.0, 0.65, 0.03), cols[i], 0.0, false)
	# Portier : colonnes à l'entrée au niveau 3, marquise dorée au 5.
	if nr >= 3:
		for sx in [-1.5, 1.5]:
			k.lathe(Vector3(porte.x + sx, 0, porte.y + 0.6), [Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.2, 0.2), Vector2(0.17, 2.6), Vector2(0.24, 2.8), Vector2(0.0, 2.8)], 10, Color("efe7da"))
	if nr >= 5:
		k.box(Vector3(porte.x, 2.9, porte.y + 0.7), Vector3(3.6, 0.14, 1.6), Color("d4af37"))


## Ce point du terrain est-il libre (hors des pièces du dehors construites) ?
func libre(p: Vector2, marge := 0.6) -> bool:
	for r in GestionTypes.genre(genre).get("zones_libres", []):
		if p.x > float(r[0]) - marge and p.x < float(r[0]) + float(r[2]) + marge and p.y > float(r[1]) - marge and p.y < float(r[1]) + float(r[3]) + marge:
			return false
	for pid in (GestionTypes.genre(genre).get("dehors", {}) as Dictionary):
		var r: Array = GestionTypes.piece(genre, String(pid)).rect
		if p.x > float(r[0]) - marge and p.x < float(r[0]) + float(r[2]) + marge and p.y > float(r[1]) - marge and p.y < float(r[1]) + float(r[3]) + marge:
			return false
	return true


## Enseigne de l'établissement (nom et étoiles) sur un socle devant l'entrée.
func _enseigne(gd: Dictionary) -> void:
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	var porte: Vector2 = gd.get("porte", Vector2(plan.x * 0.5, plan.y))
	var k := LpKit.new(5)
	var p := Vector3(porte.x - 2.8, 0, plan.y + 1.9)
	k.box(p + Vector3(0, 0.3, 0), Vector3(3.4, 0.6, 0.5), Color("5c4033"))
	k.box(p + Vector3(0, 0.95, 0), Vector3(3.2, 0.75, 0.25), Color("1d3557") if etoiles >= 3 else Color("2a9d8f"))
	k.box(p + Vector3(0, 1.36, 0), Vector3(3.3, 0.06, 0.3), Color("d4af37"), 0.0, false)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit(_materiaux)
	_statique.add_child(mi)
	var l := Label3D.new()
	l.name = "Enseigne"
	var nom := titre if titre != "" else String(gd.get("nom", ""))
	l.text = "%s\n%s" % [nom.to_upper(), "★".repeat(clampi(etoiles, 0, 5))]
	l.font_size = 40
	l.pixel_size = 0.0085
	l.outline_size = 4
	l.modulate = Color("f6e7a1")
	l.outline_modulate = Color(0.05, 0.05, 0.1, 1.0)
	l.position = p + Vector3(0, 0.95, 0.14)
	l.width = 370.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiquettes.add_child(l)


# --- Mobilier de base --------------------------------------------------------------------------

func _chaise(k: LpKit, p: Vector3, rot: float, col: Color) -> void:
	var sauve := k.xf
	k.xf = sauve * Transform3D(Basis(Vector3.UP, rot), p)
	k.box(Vector3(0, 0.44, 0), Vector3(0.44, 0.07, 0.44), col)
	k.box(Vector3(0, 0.72, -0.2), Vector3(0.44, 0.5, 0.06), col.darkened(0.15))
	for dx in [-0.18, 0.18]:
		for dz in [-0.18, 0.18]:
			k.box(Vector3(dx, 0.2, dz), Vector3(0.05, 0.4, 0.05), Color("5b4636"), 0.0, false)
	k.xf = sauve


func _fauteuil(k: LpKit, p: Vector3, rot: float, col: Color) -> void:
	var sauve := k.xf
	k.xf = sauve * Transform3D(Basis(Vector3.UP, rot), p)
	k.box(Vector3(0, 0.22, 0), Vector3(0.8, 0.36, 0.75), col)
	k.box(Vector3(0, 0.6, -0.3), Vector3(0.8, 0.5, 0.18), col.darkened(0.12))
	k.box(Vector3(-0.36, 0.48, 0.02), Vector3(0.12, 0.2, 0.7), col.darkened(0.06))
	k.box(Vector3(0.36, 0.48, 0.02), Vector3(0.12, 0.2, 0.7), col.darkened(0.06))
	k.xf = sauve


func _table_ronde(k: LpKit, p: Vector3, r: float, col: Color, nappe := Color(0, 0, 0, 0)) -> void:
	k.lathe(p, [Vector2(0.0, 0.0), Vector2(0.22, 0.0), Vector2(0.06, 0.05), Vector2(0.05, 0.7), Vector2(r, 0.72), Vector2(r, 0.76), Vector2(0.0, 0.76)], 12, col)
	if nappe.a > 0.0:
		k.lathe(p + Vector3(0, 0.5, 0), [Vector2(0.0, 0.27), Vector2(r + 0.05, 0.27), Vector2(r + 0.08, 0.0), Vector2(r + 0.1, -0.02)], 12, nappe, false, true)


func _lampe(k: LpKit, p: Vector3, h := 0.25) -> void:
	k.box(p + Vector3(0, h * 0.4, 0), Vector3(0.06, h * 0.8, 0.06), Color("8d8d8d"), 0.0, false)
	k.layer = "lumiere"
	k.lathe(p + Vector3(0, h * 0.75, 0), [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.08, 0.16), Vector2(0.0, 0.16)], 8, Color("ffe8a3"))
	k.layer = "base"


func _etagere(k: LpKit, p: Vector3, rot: float, l: float, h: float, col: Color, cols: Array) -> void:
	var sauve := k.xf
	k.xf = sauve * Transform3D(Basis(Vector3.UP, rot), p)
	k.box(Vector3(0, h * 0.5, 0), Vector3(l, h, 0.4), col)
	var rangs := maxi(1, int(h / 0.45))
	for j in rangs:
		var y := 0.25 + j * 0.45
		var x := -l * 0.5 + 0.1
		var i := 0
		while x < l * 0.5 - 0.15:
			var w := 0.1 + float((i * 7 + j * 3) % 4) * 0.04
			k.box(Vector3(x + w * 0.5, y + 0.14, 0.12), Vector3(w * 0.9, 0.28, 0.25), cols[(i + j) % cols.size()], 0.0, false)
			x += w
			i += 1
	k.xf = sauve


## Place assise ou debout pour un client.
func _place(pos: Vector3, rot: float, assis: bool, avant: Array = []) -> Dictionary:
	return {"pos": pos, "rot": rot, "assis": assis, "avant": avant}


func _decor_reception(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Comptoir : bois, puis marbre et dorures aux niveaux élevés.
	var bois := Color("8a5a3b") if n < 3 else Color("efe9df")
	var dessus := Color("3d2b20") if n < 3 else (Color("d4af37") if n >= 4 else Color("b8b1a5"))
	var cc := Vector3(x0 + 2.0, 0, z0 + 2.6)
	k.box(cc + Vector3(0, 0.53, 0), Vector3(3.6, 1.06, 0.7), bois)
	k.box(cc + Vector3(0, 0.5, 0.36), Vector3(3.3, 0.7, 0.02), bois.darkened(0.12), 0.0, false)
	k.box(cc + Vector3(0, 1.09, 0), Vector3(3.8, 0.06, 0.82), dessus)
	k.box(cc + Vector3(0.9, 1.3, -0.12), Vector3(0.5, 0.34, 0.05), Color("26262b"))
	k.layer = "lumiere"
	k.box(cc + Vector3(0.9, 1.3, -0.09), Vector3(0.44, 0.28, 0.01), Color("8ecae6"), 0.0, false)
	k.layer = "base"
	k.box(cc + Vector3(-0.9, 1.3, -0.12), Vector3(0.5, 0.34, 0.05), Color("26262b"))
	k.layer = "lumiere"
	k.box(cc + Vector3(-0.9, 1.3, -0.09), Vector3(0.44, 0.28, 0.01), Color("8ecae6"), 0.0, false)
	k.layer = "base"
	k.lathe(cc + Vector3(0.0, 1.12, 0.2), [Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.07, 0.06), Vector2(0.0, 0.09)], 8, Color("e9c46a"))
	k.box(cc + Vector3(1.55, 1.15, 0.15), Vector3(0.3, 0.06, 0.22), Color("f8f9fa"), 0.0, false)
	if n >= 2:
		# Bouquet sur le comptoir.
		k.lathe(cc + Vector3(-1.55, 1.12, 0.1), [Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.06, 0.25), Vector2(0.0, 0.25)], 8, Color("a8dadc"))
		k.blob(cc + Vector3(-1.55, 1.5, 0.1), Vector3(0.22, 0.18, 0.22), Color("2f6b35"), Color("ef476f"), 0.25, 0)
	# Meuble et casier à clés derrière le comptoir.
	k.box(Vector3(x0 + 2.0, 0.42, z0 + 0.45), Vector3(3.4, 0.84, 0.5), bois.darkened(0.15))
	k.box(Vector3(x0 + 2.0, 0.6, z0 + 0.11), Vector3(2.6, 0.7, 0.1), Color("6b4a32"))
	for i in 12:
		k.box(Vector3(x0 + 0.95 + (i % 6) * 0.42, 0.45 + (i / 6) * 0.3, z0 + 0.18), Vector3(0.3, 0.22, 0.04), Color("e9c46a").darkened(0.25))
	# Poteaux et cordons de la file d'attente.
	if n >= 2:
		for zz in [3.5, 4.7, 5.9]:
			for xx in [1.3, 2.7]:
				k.lathe(Vector3(x0 + xx, 0, z0 + zz), [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.04, 0.05), Vector2(0.04, 0.9), Vector2(0.07, 0.95), Vector2(0.0, 1.0)], 8, Color("d4af37"))
		for xx in [1.3, 2.7]:
			k.box(Vector3(x0 + xx, 0.82, z0 + 4.7), Vector3(0.04, 0.05, 2.4), Color("b5172b"), 0.0, false)
	# Coin salon avec fauteuils (niveau 2), tableaux au mur (3), colonnes (5).
	if n >= 2:
		_fauteuil(k, Vector3(x0 + 4.9, 0, z0 + 7.3), PI * 0.5, Color("1d3557") if n >= 4 else Color("2a9d8f"))
		k.lathe(Vector3(x0 + 5.8, 0, z0 + 7.3), [Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.45), Vector2(0.0, 0.45)], 10, Color("5c4033"))
		out.append(_place(Vector3(x0 + 4.9, 0, z0 + 7.3), PI * 0.5, true))
	if n >= 3:
		k.box(Vector3(x0 + 7.0, 1.6, z0 + 0.1), Vector3(1.2, 0.8, 0.05), Color("d4af37"), 0.0, false)
		k.box(Vector3(x0 + 7.0, 1.6, z0 + 0.13), Vector3(1.05, 0.65, 0.02), Color("6a994e"), 0.0, false)
	if n >= 5:
		for zz in [z0 + 1.0, z0 + 8.0]:
			k.lathe(Vector3(x0 + 6.4, 0, zz), [Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.24, 0.2), Vector2(0.2, 2.4), Vector2(0.3, 2.6), Vector2(0.0, 2.6)], 10, Color("efe7da"))
	out.append(_place(Vector3(x0 + 6.3, 0, z0 + 5.6), PI * 0.5, false))
	out.append(_place(Vector3(x0 + 3.2, 0, z0 + 8.0), 0.0, false))
	return out


func _ouvertes(n: int) -> int:
	return [0, 2, 3, 4, 5, 6][clampi(n, 0, 5)]


## Chambres : une rangée de cellules le long du couloir (lit, chevets,
## salle de bains) ; chaque niveau ouvre une chambre de plus.
func _decor_chambres(k: LpKit, r: Array, n: int) -> Array:
	var out: Array = []
	var ouvertes := _ouvertes(n)
	var luxe := "literie" in (objets.get("chambres", []) as Array)
	var draps: Color = [Color("f1faee"), Color("f1faee"), Color("e9f5db"), Color("fdf0d5"), Color("fdf0d5"), Color("fff8e7")][clampi(n, 0, 5)]
	var couvre: Color = [Color("457b9d"), Color("457b9d"), Color("2a9d8f"), Color("e76f51"), Color("6d597a"), Color("7b2d26")][clampi(n, 0, 5)]
	if luxe:
		draps = Color("fffdf5")
		couvre = Color("b08d57")
	var moquette: Color = [Color("c9a27e"), Color("c9a27e"), Color("b7a28a"), Color("a3b18a"), Color("8e7dbe"), Color("9d6b53")][clampi(n, 0, 5)]
	var x0 := float(r[0])
	var z0 := float(r[1])
	var hz := float(r[3]) / RANGEES
	var cl := Color(String(GestionTypes.genre(genre).get("murs", "efe3cc")))
	# Tapis du couloir.
	k.box(Vector3(x0 + CELLULE_L + 1.0, 0.075, z0 + float(r[3]) * 0.5), Vector3(1.3, 0.02, float(r[3]) - 0.6), Color("9b2226") if n >= 3 else Color("b08968"), 0.0, false)
	if n >= 4:
		k.box(Vector3(x0 + CELLULE_L + 1.0, 0.078, z0 + float(r[3]) * 0.5), Vector3(1.0, 0.02, float(r[3]) - 0.9), Color("ae2012"), 0.0, false)
	for i in RANGEES:
		var cz0 := z0 + i * hz
		var cz := cz0 + hz * 0.5
		var dz := cz0 + hz - 0.75
		# Cloisons entre chambres et côté couloir (avec la porte).
		if i > 0:
			k.box(Vector3(x0 + CELLULE_L * 0.5, H_CLOISON * 0.5, cz0), Vector3(CELLULE_L, H_CLOISON, 0.12), cl, 0.0, false)
			k.box(Vector3(x0 + CELLULE_L * 0.5, H_CLOISON + 0.02, cz0), Vector3(CELLULE_L, 0.04, 0.16), cl.darkened(0.25), 0.0, false)
		var avant_porte := (dz - 0.6) - cz0
		k.box(Vector3(x0 + CELLULE_L, H_CLOISON * 0.5, cz0 + avant_porte * 0.5), Vector3(0.12, H_CLOISON, avant_porte), cl, 0.0, false)
		k.box(Vector3(x0 + CELLULE_L, H_CLOISON * 0.5, (dz + 0.6 + cz0 + hz) * 0.5), Vector3(0.12, H_CLOISON, cz0 + hz - dz - 0.6), cl, 0.0, false)
		# Numéro de la chambre sur le couloir.
		k.box(Vector3(x0 + CELLULE_L + 0.08, 0.45, dz - 0.75), Vector3(0.03, 0.18, 0.22), Color("d4af37"), 0.0, false)
		if i >= ouvertes:
			# Chambre en travaux : bâche, pots de peinture, escabeau.
			k.box(Vector3(x0 + 5.0, 0.08, cz), Vector3(9.6, 0.04, hz - 0.3), Color("7d7466"), 0.0, false)
			k.box(Vector3(x0 + 3.0, 0.2, cz), Vector3(0.4, 0.4, 0.4), Color("e9c46a"))
			k.box(Vector3(x0 + 3.6, 0.18, cz + 0.5), Vector3(0.35, 0.36, 0.35), Color("a8dadc"))
			k.beam(Vector3(x0 + 6.0, 0.05, cz - 0.6), Vector3(x0 + 6.0, 1.6, cz - 0.1), 0.5, 0.06, Color("adb5bd"))
			k.box(Vector3(x0 + 7.6, 0.6, cz + 0.6), Vector3(1.6, 1.2, 0.08), Color("dee2e6"))
			continue
		# Sol de la chambre et de la salle de bains.
		_q(k, x0 + 0.1, cz0 + 0.08, x0 + CELLULE_L - 0.08, cz0 + hz - 0.08, 0.066, moquette)
		_q(k, x0 + 7.0, cz0 + 0.08, x0 + CELLULE_L - 0.08, cz0 + 2.3, 0.068, Color("cfe8ef"))
		for t in 5:
			_q(k, x0 + 7.0 + t * 0.6, cz0 + 0.1, x0 + 7.0 + t * 0.6 + 0.02, cz0 + 2.3, 0.07, Color("a9cdd6"))
		# Cloison basse de la salle de bains.
		k.box(Vector3(x0 + 7.0, H_CLOISON * 0.5, cz0 + 1.15), Vector3(0.1, H_CLOISON, 2.3), cl, 0.0, false)
		k.box(Vector3(x0 + 7.9, H_CLOISON * 0.5, cz0 + 2.3), Vector3(1.8, H_CLOISON, 0.1), cl, 0.0, false)
		# Lavabo, WC, douche (remplacée par la baignoire balnéo si achetée).
		k.box(Vector3(x0 + 7.5, 0.4, cz0 + 0.35), Vector3(0.7, 0.8, 0.45), Color("f8f9fa"))
		k.box(Vector3(x0 + 7.5, 0.82, cz0 + 0.38), Vector3(0.4, 0.05, 0.3), Color("cbd5dc"), 0.0, false)
		k.box(Vector3(x0 + 9.55, 0.2, cz0 + 1.8), Vector3(0.4, 0.4, 0.55), Color("ffffff"))
		k.box(Vector3(x0 + 9.75, 0.45, cz0 + 1.8), Vector3(0.18, 0.5, 0.45), Color("f1f1f1"))
		if not ("baignoire" in (objets.get("chambres", []) as Array) and n >= 3):
			k.box(Vector3(x0 + 9.3, 0.08, cz0 + 0.6), Vector3(1.0, 0.06, 1.0), Color("e9ecef"))
			k.layer = "verre"
			k.box(Vector3(x0 + 8.8, 0.9, cz0 + 0.6), Vector3(0.03, 1.7, 1.0), Color(0.75, 0.9, 0.95, 0.35), 0.0, false)
			k.layer = "base"
		# Lit double contre le mur de gauche, chevets et lampes.
		k.box(Vector3(x0 + 1.2, 0.22, cz), Vector3(2.1, 0.36, 1.7), Color("6d4c41") if not luxe else Color("3d2b20"))
		k.box(Vector3(x0 + 1.25, 0.47, cz), Vector3(2.0, 0.16, 1.62), draps)
		k.box(Vector3(x0 + 1.75, 0.56, cz), Vector3(1.0, 0.05, 1.68), couvre)
		k.box(Vector3(x0 + 0.45, 0.6, cz - 0.4), Vector3(0.35, 0.14, 0.6), Color("ffffff"))
		k.box(Vector3(x0 + 0.45, 0.6, cz + 0.4), Vector3(0.35, 0.14, 0.6), Color("ffffff"))
		k.box(Vector3(x0 + 0.13, 0.65 if not luxe else 0.8, cz), Vector3(0.12, 0.9 if not luxe else 1.3, 1.9), Color("8a5a3b") if not luxe else Color("b08d57"))
		for s in [-1.18, 1.18]:
			k.box(Vector3(x0 + 0.4, 0.25, cz + s), Vector3(0.45, 0.5, 0.42), Color("8a5a3b"))
			_lampe(k, Vector3(x0 + 0.4, 0.5, cz + s))
		if n >= 3:
			# Tapis au pied du lit.
			k.box(Vector3(x0 + 2.9, 0.075, cz), Vector3(1.2, 0.02, 2.0), couvre.lightened(0.3), 0.0, false)
		if n >= 2:
			_fauteuil(k, Vector3(x0 + 3.6, 0, cz0 + 3.35), PI, couvre.darkened(0.1))
			out.append(_place(Vector3(x0 + 3.6, 0, cz0 + 3.35), PI, true, [Vector3(x0 + CELLULE_L + 0.9, 0, dz), Vector3(x0 + CELLULE_L - 0.6, 0, dz)]))
		if n >= 4:
			# Valise posée et porte-bagages.
			k.box(Vector3(x0 + 2.6, 0.22, cz0 + 3.95), Vector3(0.7, 0.3, 0.45), Color("6c757d"))
			k.box(Vector3(x0 + 2.6, 0.5, cz0 + 3.95), Vector3(0.6, 0.3, 0.4), [Color("e63946"), Color("1d3557"), Color("f4a261")][i % 3])
		out.append(_place(Vector3(x0 + 2.35, 0, cz - 0.3), PI * 0.5, true, [Vector3(x0 + CELLULE_L + 0.9, 0, dz), Vector3(x0 + CELLULE_L - 0.6, 0, dz)]))
	return out


func _decor_lingerie(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	for i in mini(n, 3):
		_m(k, "lave_linge", x0 + 0.5, z0 + 1.6 + i * 1.0, PI * 0.5)
	# Table de pliage et piles de serviettes.
	k.box(Vector3(x0 + 3.0, 0.42, z0 + 2.4), Vector3(2.0, 0.84, 0.9), Color("adb5bd"))
	k.box(Vector3(x0 + 3.0, 0.86, z0 + 2.4), Vector3(2.1, 0.05, 1.0), Color("e9ecef"), 0.0, false)
	for i in 4:
		for j in mini(1 + n / 2, 3):
			k.box(Vector3(x0 + 2.3 + i * 0.45, 0.94 + j * 0.1, z0 + 2.3), Vector3(0.38, 0.09, 0.42), [Color("ffffff"), Color("a8dadc"), Color("ffd6a5"), Color("ffffff")][(i + j) % 4], 0.0, false)
	# Étagère de linge le long du mur de droite.
	_etagere(k, Vector3(x0 + 5.75, 0, z0 + 2.4), -PI * 0.5, 1.6, 1.6, Color("8a5a3b"), [Color("ffffff"), Color("a8dadc"), Color("ffd6a5")])
	# Paniers à linge.
	for p in [Vector2(4.4, 6.0), Vector2(5.0, 6.7)]:
		k.lathe(Vector3(x0 + p.x, 0, z0 + p.y), [Vector2(0.0, 0.0), Vector2(0.28, 0.0), Vector2(0.32, 0.5), Vector2(0.0, 0.5)], 8, Color("c9a27e"), true, false)
		k.blob(Vector3(x0 + p.x, 0.5, z0 + p.y), Vector3(0.28, 0.12, 0.28), Color("e9ecef"), Color("ffffff"), 0.3, 0)
	return []


func _decor_bureau(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Bureau (l'ordinateur acheté le remplace) et chaises des visiteurs.
	if not "ordinateur" in (objets.get("direction", []) as Array):
		k.box(Vector3(x0 + 3.0, 0.74, z0 + 2.0), Vector3(1.6, 0.06, 0.8), Color("5c4033"))
		for sx in [-0.7, 0.7]:
			k.box(Vector3(x0 + 3.0 + sx, 0.37, z0 + 2.0), Vector3(0.06, 0.74, 0.7), Color("5c4033"), 0.0, false)
		k.box(Vector3(x0 + 2.6, 0.8, z0 + 2.0), Vector3(0.4, 0.06, 0.3), Color("f8f9fa"), 0.0, false)
	_chaise(k, Vector3(x0 + 2.4, 0, z0 + 1.0), 0.0, Color("6d4c41"))
	_chaise(k, Vector3(x0 + 3.6, 0, z0 + 1.0), 0.0, Color("6d4c41"))
	# Bibliothèque et classeurs.
	_etagere(k, Vector3(x0 + 0.3, 0, z0 + 3.4), PI * 0.5, 2.4, 1.8, Color("6b4a32"), [Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), Color("264653")])
	for i in 2:
		k.box(Vector3(x0 + 5.7, 0.6, z0 + 3.0 + i * 0.6), Vector3(0.5, 1.2, 0.55), Color("8d99ae"))
		for j in 3:
			k.box(Vector3(x0 + 5.44, 0.25 + j * 0.38, z0 + 3.0 + i * 0.6), Vector3(0.02, 0.05, 0.25), Color("2b2d42"), 0.0, false)
	k.box(Vector3(x0 + 3.0, 0.075, z0 + 4.6), Vector3(3.0, 0.02, 2.0), Color("6d597a") if n >= 3 else Color("8d99ae"), 0.0, false)
	if n >= 2:
		_m(k, "plante", x0 + 0.6, z0 + 7.3)
	if n >= 3:
		# Table de réunion.
		_table_ronde(k, Vector3(x0 + 3.4, 0, z0 + 5.8), 0.7, Color("5c4033"))
		for a in [0.0, 2.1, 4.2]:
			_chaise(k, Vector3(x0 + 3.4 + sin(a) * 1.0, 0, z0 + 5.8 + cos(a) * 1.0), a + PI, Color("495057"))
	if n >= 4:
		# Trophées et diplômes.
		for i in 3:
			k.lathe(Vector3(x0 + 0.42, 1.82, z0 + 2.6 + i * 0.4), [Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.03, 0.08), Vector2(0.1, 0.25), Vector2(0.0, 0.25)], 8, Color("d4af37"))
	return []


func _decor_bar(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var cuir: Color = [Color("8a5a3b"), Color("8a5a3b"), Color("6d2e46"), Color("1d3557"), Color("264653"), Color("7b2d26")][clampi(n, 0, 5)]
	# Comptoir le long du mur de gauche, étagère de bouteilles derrière.
	k.box(Vector3(x0 + 1.6, 0.53, z0 + 3.0), Vector3(0.7, 1.06, 4.4), Color("3d2b20"))
	k.box(Vector3(x0 + 1.6, 1.09, z0 + 3.0), Vector3(0.85, 0.06, 4.6), Color("d4af37") if n >= 4 else Color("6b4a32"))
	k.box(Vector3(x0 + 1.96, 0.12, z0 + 3.0), Vector3(0.04, 0.04, 4.2), Color("d4af37"), 0.0, false)
	k.box(Vector3(x0 + 0.3, 0.5, z0 + 3.0), Vector3(0.45, 1.0, 4.8), Color("5c4033"))
	for i in 18:
		var zz := z0 + 1.0 + (i % 9) * 0.45
		var yy := 1.2 if i < 9 else 1.0
		k.lathe(Vector3(x0 + 0.3 + (0.0 if i < 9 else 0.0), yy if i < 9 else 1.0, zz), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.2), Vector2(0.025, 0.3), Vector2(0.0, 0.32)], 6,
			[Color("2a9d8f"), Color("e9c46a"), Color("e76f51"), Color("8ecae6"), Color("6a994e")][i % 5])
	# Pompes à bière et verres sur le comptoir.
	for i in 3:
		k.box(Vector3(x0 + 1.55, 1.3, z0 + 1.5 + i * 0.25), Vector3(0.05, 0.38, 0.05), Color("d4af37"), 0.0, false)
	for i in 4:
		k.lathe(Vector3(x0 + 1.75, 1.12, z0 + 3.6 + i * 0.3), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.06, 0.14), Vector2(0.0, 0.14)], 6, Color("dff3f8"))
	# Tabourets devant le comptoir.
	for i in 4:
		var p := Vector3(x0 + 2.45, 0, z0 + 1.4 + i * 1.05)
		k.lathe(p, [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.04, 0.05), Vector2(0.04, 0.65), Vector2(0.2, 0.68), Vector2(0.2, 0.76), Vector2(0.0, 0.76)], 8, cuir)
		out.append(_place(p, -PI * 0.5, true))
	# Petites tables et fauteuils club (plus nombreux avec le niveau).
	var tables := [Vector3(x0 + 5.0, 0, z0 + 2.8), Vector3(x0 + 4.8, 0, z0 + 6.0), Vector3(x0 + 7.4, 0, z0 + 3.4), Vector3(x0 + 7.2, 0, z0 + 6.8)]
	var nb: int = [0, 2, 3, 4, 4, 4][clampi(n, 0, 5)]
	for i in nb:
		var t: Vector3 = tables[i]
		_table_ronde(k, t, 0.42, Color("3d2b20"))
		k.lathe(t + Vector3(0.1, 0.76, 0.05), [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.06, 0.16), Vector2(0.0, 0.16)], 6, Color("f4a261"))
		_fauteuil(k, t + Vector3(-0.85, 0, 0), PI * 0.5, cuir)
		_fauteuil(k, t + Vector3(0.85, 0, 0), -PI * 0.5, cuir)
		out.append(_place(t + Vector3(-0.85, 0, 0), PI * 0.5, true))
		out.append(_place(t + Vector3(0.85, 0, 0), -PI * 0.5, true))
	if n >= 3:
		# Lampes de table et tapis persan.
		k.box(Vector3(x0 + 6.2, 0.072, z0 + 4.8), Vector3(4.2, 0.02, 5.0), Color("6b2a2a"), 0.0, false)
		k.box(Vector3(x0 + 6.2, 0.074, z0 + 4.8), Vector3(3.6, 0.02, 4.4), Color("9c4a3c"), 0.0, false)
	if n >= 5:
		_m(k, "plante_grande", x0 + 11.4, z0 + 8.4)
	return out


func _decor_restaurant(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Cuisine ouverte dans le coin du fond : fourneaux, hotte, passe.
	_q(k, x0 + 7.4, z0 + 0.1, x0 + 11.9, z0 + 2.9, 0.07, Color("d9d9d9"))
	for i in 4:
		var p := Vector3(x0 + 8.0 + i * 1.0, 0, z0 + 0.45)
		k.box(p + Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.7), Color("adb5bd"))
		k.box(p + Vector3(0, 0.92, 0), Vector3(0.9, 0.04, 0.65), Color("343a40"), 0.0, false)
		if i % 2 == 0:
			k.lathe(p + Vector3(-0.15, 0.94, 0.0), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.2), Vector2(0.0, 0.2)], 8, Color("ced4da"), true, false)
		else:
			k.box(p + Vector3(0.1, 0.97, 0.05), Vector3(0.45, 0.05, 0.3), Color("495057"), 0.0, false)
	k.box(Vector3(x0 + 9.5, 2.2, z0 + 0.5), Vector3(4.0, 0.4, 0.9), Color("ced4da"))
	k.box(Vector3(x0 + 9.6, 0.5, z0 + 2.4), Vector3(4.2, 1.0, 0.6), Color("6b4a32"))
	k.box(Vector3(x0 + 9.6, 1.02, z0 + 2.4), Vector3(4.3, 0.05, 0.7), Color("e9ecef"))
	k.layer = "lumiere"
	k.box(Vector3(x0 + 9.6, 1.55, z0 + 2.4), Vector3(4.0, 0.05, 0.12), Color("ffd8a8"), 0.0, false)
	k.layer = "base"
	for i in 5:
		k.lathe(Vector3(x0 + 8.0 + i * 0.75, 1.05, z0 + 2.4), [Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.18, 0.03), Vector2(0.0, 0.03)], 8, Color("ffffff"))
		k.blob(Vector3(x0 + 8.0 + i * 0.75, 1.1, z0 + 2.4), Vector3(0.09, 0.05, 0.09), Color("bc6c25"), [Color("90be6d"), Color("e76f51"), Color("f4d35e")][i % 3], 0.3, 0)
	var nappe: Color = [Color("ffffff"), Color("ffffff"), Color("f1faee"), Color("e63946"), Color("ffffff"), Color("f6e7a1")][clampi(n, 0, 5)]
	var tables := [Vector3(x0 + 1.8, 0, z0 + 5.6), Vector3(x0 + 4.6, 0, z0 + 5.6), Vector3(x0 + 7.4, 0, z0 + 5.6),
		Vector3(x0 + 1.8, 0, z0 + 8.0), Vector3(x0 + 4.6, 0, z0 + 8.0), Vector3(x0 + 7.4, 0, z0 + 8.0),
		Vector3(x0 + 1.8, 0, z0 + 10.4), Vector3(x0 + 4.6, 0, z0 + 10.4), Vector3(x0 + 7.4, 0, z0 + 10.4)]
	var nb: int = [0, 3, 4, 6, 8, 9][clampi(n, 0, 5)]
	for i in nb:
		var t: Vector3 = tables[i]
		k.box(t + Vector3(0, 0.74, 0), Vector3(1.1, 0.06, 1.1), nappe)
		k.box(t + Vector3(0, 0.6, 0), Vector3(1.14, 0.22, 1.14), nappe.darkened(0.05), 0.0, false)
		k.box(t + Vector3(0, 0.3, 0), Vector3(0.12, 0.6, 0.12), Color("3d2b20"), 0.0, false)
		k.lathe(t + Vector3(0, 0.77, 0), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.03, 0.18), Vector2(0.0, 0.2)], 6, Color("e9c46a") if n >= 3 else Color("ffffff"))
		for s in [-0.3, 0.3]:
			k.lathe(t + Vector3(s, 0.77, 0), [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.16, 0.02), Vector2(0.0, 0.02)], 8, Color("ffffff"))
		_chaise(k, t + Vector3(-0.8, 0, 0), PI * 0.5, Color("8a5a3b"))
		_chaise(k, t + Vector3(0.8, 0, 0), -PI * 0.5, Color("8a5a3b"))
		out.append(_place(t + Vector3(-0.8, 0, 0), PI * 0.5, true))
		out.append(_place(t + Vector3(0.8, 0, 0), -PI * 0.5, true))
	# Pupitre du maître d'hôtel à l'entrée.
	k.box(Vector3(x0 + 1.0, 0.55, z0 + 3.0), Vector3(0.5, 1.1, 0.4), Color("5c4033"))
	if n >= 3:
		_m(k, "plante", x0 + 11.4, z0 + 4.0)
	return out


func _decor_spa(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Tables de massage (une, puis deux, puis trois).
	var tables := [Vector3(x0 + 1.6, 0, z0 + 2.4), Vector3(x0 + 4.6, 0, z0 + 2.4), Vector3(x0 + 7.2, 0, z0 + 2.4)]
	for i in mini(1 + (n - 1) / 2, 3):
		var p: Vector3 = tables[i]
		k.box(p + Vector3(0, 0.62, 0), Vector3(0.8, 0.12, 2.0), Color("f8f9fa"))
		k.box(p + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 1.4), Color("c9ada7"))
		k.box(p + Vector3(0, 0.7, -0.8), Vector3(0.5, 0.06, 0.3), Color("a8dadc"), 0.0, false)
		k.lathe(p + Vector3(1.0, 0, -1.0), [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.2, 0.6), Vector2(0.0, 0.6)], 8, Color("b08968"))
		_lampe(k, p + Vector3(1.0, 0.6, -1.0), 0.2)
		out.append(_place(p + Vector3(-0.1, 0.25, 0), PI, true))
	# Paravents en bambou entre les tables.
	for i in mini((n - 1) / 2, 2):
		k.box(Vector3(x0 + 3.1 + i * 2.8, 0.8, z0 + 2.4), Vector3(0.06, 1.6, 2.2), Color("cdb380"))
	# Chaises longues de détente et galets.
	var nbl: int = [0, 2, 3, 3, 4, 4][clampi(n, 0, 5)]
	for i in nbl:
		var p := Vector3(x0 + 1.4 + i * 1.3, 0, z0 + 12.6)
		k.box(p + Vector3(0, 0.25, 0), Vector3(0.6, 0.12, 1.7), Color("f8f9fa"))
		k.box(p + Vector3(0, 0.45, -0.65), Vector3(0.6, 0.35, 0.4), Color("e9ecef"))
		out.append(_place(p, PI, true))
	for i in 7:
		k.stone(Vector3(x0 + 6.2 + rng.randf_range(-0.8, 0.8), 0.1, z0 + 6.8 + rng.randf_range(-0.8, 0.8)), Vector3(0.3, 0.12, 0.25), Color("cfd8dc"))
	if n >= 3:
		# Bassin chaud.
		k.box(Vector3(x0 + 6.2, 0.22, z0 + 6.8), Vector3(2.6, 0.44, 2.2), Color("e9ecef"))
		k.layer = "eau"
		k.box(Vector3(x0 + 6.2, 0.42, z0 + 6.8), Vector3(2.3, 0.05, 1.9), Color(0.4, 0.75, 0.85, 0.8), 0.0, false)
		k.layer = "base"
		out.append(_place(Vector3(x0 + 6.2, -0.3, z0 + 6.8), PI * 0.25, false))
	if n >= 4:
		_m(k, "plante_grande", x0 + 0.6, z0 + 13.3)
	return out


func _decor_boutique(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Comptoir-caisse, étagères au mur du fond.
	k.box(Vector3(x0 + 2.0, 0.5, z0 + 6.8), Vector3(2.0, 1.0, 0.6), Color("8a5a3b"))
	k.box(Vector3(x0 + 2.0, 1.02, z0 + 6.8), Vector3(2.1, 0.05, 0.7), Color("e9ecef"))
	k.box(Vector3(x0 + 1.5, 1.15, z0 + 6.85), Vector3(0.4, 0.2, 0.3), Color("343a40"))
	_etagere(k, Vector3(x0 + 2.0, 0, z0 + 0.3), 0.0, 3.2, 1.4, Color("b08968"), [Color("ef476f"), Color("ffd166"), Color("06d6a0"), Color("118ab2")])
	if n >= 3:
		k.layer = "lumiere"
		k.box(Vector3(x0 + 2.0, 1.55, z0 + 0.4), Vector3(3.0, 0.05, 0.08), Color("fff3b0"), 0.0, false)
		k.layer = "base"
	return [_place(Vector3(x0 + 2.0, 0, z0 + 1.4), PI, false), _place(Vector3(x0 + 2.0, 0, z0 + 5.9), 0.0, false)]


func _decor_sport(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Tapis de sol noirs, râtelier d'haltères, ballons.
	k.box(Vector3(x0 + 4.0, 0.075, z0 + 5.2), Vector3(7.4, 0.02, 3.0), Color("343a40"), 0.0, false)
	k.box(Vector3(x0 + 0.5, 0.4, z0 + 3.0), Vector3(0.5, 0.8, 2.0), Color("495057"))
	for i in 5:
		k.box(Vector3(x0 + 0.6, 0.85, z0 + 2.2 + i * 0.4), Vector3(0.35, 0.12, 0.12), Color("212529"), 0.0, false)
		k.box(Vector3(x0 + 0.6, 0.55, z0 + 2.2 + i * 0.4), Vector3(0.35, 0.12, 0.12), Color("ef476f"), 0.0, false)
	for i in mini(n + 1, 4):
		k.blob(Vector3(x0 + 6.8 + (i % 2) * 0.5, 0.3, z0 + 9.0 + (i / 2) * 0.5), Vector3(0.3, 0.3, 0.3), [Color("06d6a0"), Color("118ab2"), Color("ffd166")][i % 3], [Color("06d6a0"), Color("118ab2"), Color("ffd166")][i % 3].lightened(0.2), 0.0, 1)
	# Tapis de yoga (des places).
	var nb: int = [0, 2, 3, 3, 4, 4][clampi(n, 0, 5)]
	for i in nb:
		var p := Vector3(x0 + 1.6 + i * 1.5, 0, z0 + 8.6)
		k.box(p + Vector3(0, 0.08, 0), Vector3(0.65, 0.02, 1.8), [Color("9d4edd"), Color("06d6a0"), Color("ff8fab"), Color("4cc9f0")][i % 4], 0.0, false)
		out.append(_place(p, PI, true))
	if n >= 3:
		k.box(Vector3(x0 + 4.0, 2.0, z0 + 0.12), Vector3(3.0, 0.6, 0.05), Color("1d3557"), 0.0, false)
	return out


func _decor_conference(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Rangées de chaises face à l'écran (allée au milieu).
	var rangs: int = [0, 2, 3, 4, 5, 6][clampi(n, 0, 5)]
	for j in rangs:
		var zz := z0 + 3.6 + j * 1.4
		for xx in [1.0, 1.8, 2.6, 5.4, 6.2, 7.0]:
			if xx > 6.5 and zz > z0 + 7.8 and zz < z0 + 10.2:
				continue
			_chaise(k, Vector3(x0 + xx, 0, zz), PI, Color("1d3557") if n >= 3 else Color("6c757d"))
			out.append(_place(Vector3(x0 + xx, 0, zz), PI, true))
	if n >= 2:
		# Table des orateurs avec nappe et bouteilles d'eau.
		k.box(Vector3(x0 + 5.0, 0.72, z0 + 1.8), Vector3(2.4, 0.06, 0.7), Color("f8f9fa"))
		k.box(Vector3(x0 + 5.0, 0.4, z0 + 2.12), Vector3(2.4, 0.64, 0.03), Color("1d3557"), 0.0, false)
		for i in 3:
			k.lathe(Vector3(x0 + 4.3 + i * 0.7, 0.75, z0 + 1.8), [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.04, 0.18), Vector2(0.0, 0.22)], 6, Color("a8dadc"))
	return out


func _decor_piscine(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var dims: Vector2 = [Vector2(3, 5), Vector2(4, 6), Vector2(4.6, 7.5), Vector2(5.4, 8.6), Vector2(6, 9.6), Vector2(6.2, 10)][clampi(n, 0, 5)]
	var c := Vector3(x0 + 7.2, 0, z0 + 8.0)
	# Margelle, bassin (bords et fond bleus), eau, lignes d'eau, échelle.
	k.box(c + Vector3(0, 0.09, 0), Vector3(dims.x + 0.7, 0.1, dims.y + 0.7), Color("f8f9fa"))
	k.box(c + Vector3(0, 0.11, 0), Vector3(dims.x, 0.1, dims.y), Color("2f7fb8"), 0.0, false)
	for i in int(dims.y):
		k.box(c + Vector3(0, 0.162, -dims.y * 0.5 + 0.5 + i), Vector3(dims.x - 0.1, 0.002, 0.04), Color("5fb3e4"), 0.0, false)
	k.layer = "eau"
	k.box(c + Vector3(0, 0.17, 0), Vector3(dims.x, 0.04, dims.y), Color(0.35, 0.78, 0.95, 0.72), 0.0, false)
	k.layer = "base"
	if n >= 3:
		for i in 2:
			k.box(c + Vector3(-dims.x * 0.17 + i * dims.x * 0.34, 0.2, 0), Vector3(0.06, 0.04, dims.y - 0.2), Color("e63946") if i == 0 else Color("f4d35e"), 0.0, false)
	k.tube(c + Vector3(-dims.x * 0.5 + 0.2, 0.1, dims.y * 0.5 - 0.6), c + Vector3(-dims.x * 0.5 + 0.2, 0.8, dims.y * 0.5 - 0.5), 0.03, 0.03, 5, Color("ced4da"))
	k.tube(c + Vector3(-dims.x * 0.5 + 0.2, 0.1, dims.y * 0.5 - 1.1), c + Vector3(-dims.x * 0.5 + 0.2, 0.8, dims.y * 0.5 - 1.0), 0.03, 0.03, 5, Color("ced4da"))
	# Transats.
	var nb: int = [0, 3, 4, 5, 6, 7][clampi(n, 0, 5)]
	for i in nb:
		var p := Vector3(x0 + 1.2, 0, z0 + 1.4 + i * 2.0)
		k.box(p + Vector3(0, 0.25, 0.1), Vector3(0.62, 0.1, 1.6), Color("f8f9fa"))
		k.box(p + Vector3(0, 0.42, -0.6), Vector3(0.62, 0.32, 0.36), Color("e9c46a") if i % 2 == 0 else Color("2a9d8f"))
		k.box(p + Vector3(0.0, 0.27, 0.2), Vector3(0.5, 0.02, 0.9), Color("ef476f") if i % 3 == 0 else Color("4cc9f0"), 0.0, false)
		out.append(_place(p + Vector3(0, 0.0, 0.1), PI, true))
	# Nageurs.
	for i in mini(n, 3):
		out.append(_place(c + Vector3(-dims.x * 0.25 + i * dims.x * 0.25, -0.95, -dims.y * 0.25 + i * dims.y * 0.25), PI * 0.5 * i, false))
	# Chaise haute du maître-nageur.
	if n >= 2:
		k.box(Vector3(x0 + 3.0, 1.2, z0 + 14.6), Vector3(0.6, 0.08, 0.6), Color("f8f9fa"))
		k.box(Vector3(x0 + 3.0, 1.55, z0 + 14.35), Vector3(0.6, 0.6, 0.06), Color("f8f9fa"))
		for sx in [-0.25, 0.25]:
			k.box(Vector3(x0 + 3.0 + sx, 0.6, z0 + 14.6), Vector3(0.06, 1.2, 0.06), Color("adb5bd"), 0.0, false)
	return out


func _decor_jardin(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Allée en pas japonais, arbres fruitiers, clôture basse.
	for i in 10:
		k.box(Vector3(x0 + 0.8 + i * 1.15, 0.08, z0 + 8.4 + sin(i * 0.9) * 0.2), Vector3(0.7, 0.04, 0.55), Color("d6ccc2"), 0.0, false)
	_arbre(k, Vector3(x0 + 11.0, 0, z0 + 1.0), 0.8)
	if n >= 2:
		_arbre(k, Vector3(x0 + 0.9, 0, z0 + 1.0), 0.7)
	for i in 12:
		k.box(Vector3(x0 + 0.5 + i * 1.0, 0.35, z0 + 0.12), Vector3(0.06, 0.7, 0.06), Color("f8f9fa"), 0.0, false)
	k.box(Vector3(x0 + 6.0, 0.55, z0 + 0.12), Vector3(12.0, 0.06, 0.04), Color("f8f9fa"), 0.0, false)
	# Table de pique-nique.
	k.box(Vector3(x0 + 8.2, 0.72, z0 + 6.2), Vector3(1.6, 0.06, 0.8), Color("a47148"))
	for s in [-0.6, 0.6]:
		k.box(Vector3(x0 + 8.2, 0.42, z0 + 6.2 + s), Vector3(1.6, 0.05, 0.3), Color("a47148"))
	k.box(Vector3(x0 + 8.2, 0.36, z0 + 6.2), Vector3(0.08, 0.72, 0.6), Color("7f5539"), 0.0, false)
	out.append(_place(Vector3(x0 + 8.0, 0, z0 + 5.6), 0.0, true))
	out.append(_place(Vector3(x0 + 8.4, 0, z0 + 6.8), PI, true))
	return out


func _decor_parking(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var porte: Vector2 = GestionTypes.genre(genre).get("porte", Vector2(15, 22))
	var achats: Array = objets.get("parking", [])
	k.box(Vector3(porte.x, 0.07, z0 + float(r[3]) * 0.5), Vector3(2.2, 0.04, r[3]), Color("d8cfbe"), 0.0, false)
	var slots: Array = []
	for i in 16:
		var x := x0 + 1.4 + i * 2.5
		if absf(x - porte.x) < 2.2 or x > x0 + float(r[2]) - 1.0:
			continue
		if not (absf(x - 19.2) < 1.6 and "guerite" in achats):
			slots.append(Vector3(x, 0, z0 + 2.1))
		if not (x > 30.5 and x < 35.5 and "navette" in achats):
			slots.append(Vector3(x, 0, z0 + 5.9))
	for s in slots:
		var p: Vector3 = s
		k.box(p + Vector3(1.25, 0.075, 0), Vector3(0.08, 0.02, 3.2), Color("f2f2ee"), 0.0, false)
		k.box(p + Vector3(-1.25, 0.075, 0), Vector3(0.08, 0.02, 3.2), Color("f2f2ee"), 0.0, false)
	# Marquage handicapé sur la première place.
	if not slots.is_empty():
		k.box((slots[0] as Vector3) + Vector3(0, 0.08, 0), Vector3(1.0, 0.01, 1.0), Color("3a86ff"), 0.0, false)
	var cols := [Color("e63946"), Color("457b9d"), Color("f4a261"), Color("2a9d8f"), Color("f8f9fa"), Color("1b1b1e"), Color("e9c46a"), Color("8d99ae")]
	var nb := mini(3 + n * 3, slots.size())
	for i in nb:
		var p: Vector3 = slots[(i * 7) % slots.size()]
		var sauve := k.xf
		k.xf = Transform3D(Basis(Vector3.UP, 0.0 if p.z < z0 + 4.0 else PI), Vector3.ZERO)
		GestionModeles.voiture(k, k.xf.affine_inverse() * p, cols[i % cols.size()])
		k.xf = sauve
	return []


# --- Objets achetés ----------------------------------------------------------------------------

## Dessine les objets achetés d'une pièce et renvoie les places qu'ils offrent.
func _objets(k: LpKit, pid: String, r: Array, n: int) -> Array:
	var out: Array = []
	var hz := float(r[3]) / RANGEES
	for oid in objets.get(pid, []):
		var d := GestionTypes.objet(genre, pid, String(oid))
		if d.is_empty() or int(d.get("niv", 1)) > n:
			continue
		var mod := String(d.get("modele", ""))
		if mod == "":
			continue
		var cell := bool(d.get("cellules", false))
		var origines: Array = []
		if cell:
			for i in _ouvertes(n):
				origines.append(Vector2(r[0], float(r[1]) + i * hz))
		else:
			origines.append(Vector2(r[0], r[1]))
		for o in origines:
			for ps in d.get("poses", []):
				var p := Vector3((o as Vector2).x + float(ps[0]), 0, (o as Vector2).y + float(ps[1]))
				var rot := float(ps[2])
				GestionModeles.dessiner(k, mod, p, rot)
				if cell:
					continue
				for lp in GestionModeles.places(mod):
					var q := p + Basis(Vector3.UP, rot) * Vector3(float(lp[0]), 0, float(lp[1]))
					out.append(_place(q, rot + float(lp[2]), bool(lp[3])))
	return out


# --- Pannes ------------------------------------------------------------------------------------

func _etiquettes_pannes() -> void:
	var vues := {}
	for i in pannes.size():
		var p: Dictionary = pannes[i]
		var pid := String(p.get("piece", ""))
		if not GestionTypes.pieces(genre).has(pid):
			continue
		var decal := float(vues.get(pid, 0)) * 0.7
		vues[pid] = int(vues.get(pid, 0)) + 1
		var l := Label3D.new()
		l.name = "Panne_%d" % i
		l.text = "⚠ %s\n(clic : réparer)" % String(p.get("texte", "Panne"))
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 44
		l.pixel_size = 0.011
		l.outline_size = 12
		l.modulate = Color("ffb703")
		l.outline_modulate = Color(0.25, 0.08, 0.0, 0.95)
		l.no_depth_test = true
		l.position = centre(pid) + Vector3(0, 2.3 + decal, 0)
		l.set_meta("i", i)
		_etiquettes.add_child(l)
		pannes_l.append(l)
		# Fumée grise au-dessus de l'appareil en panne.
		var k := LpKit.new(11 + i)
		for j in 4:
			k.blob(Vector3(rng.randf_range(-0.3, 0.3), 0.8 + j * 0.35, rng.randf_range(-0.3, 0.3)), Vector3(0.25, 0.22, 0.25) * (1.0 + j * 0.2), Color("6c757d"), Color("adb5bd"), 0.25, 0)
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit(_materiaux)
		mi.position = centre(pid) + Vector3(0.8, 0, 0.8)
		mi.name = "Fumee_%d" % i
		_etiquettes.add_child(mi)


## Panne sous un point de l'écran (-1 : aucune).
func panne_sous(cam: Camera3D, ecran: Vector2, rayon := 70.0) -> int:
	var best := -1
	var bd := rayon
	for l in pannes_l:
		if not is_instance_valid(l):
			continue
		var p := (l as Node3D).global_position
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(ecran)
		if d < bd:
			bd = d
			best = int((l as Node).get_meta("i"))
	return best


# --- Rue ---------------------------------------------------------------------------------------

func _creer_voitures(gd: Dictionary) -> void:
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	var e := emprise()
	var rz := plan.y + 12.4
	var cols := [Color("e63946"), Color("f4d35e"), Color("457b9d"), Color("f8f9fa")]
	for i in 4:
		var k := LpKit.new(30 + i)
		GestionModeles.voiture(k, Vector3.ZERO, cols[i], i == 3)
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit(_materiaux)
		var sens := 1.0 if i % 2 == 0 else -1.0
		mi.position = Vector3(float(e[0]) - 10.0 + i * 19.0, 0, rz + (1.5 if sens > 0 else 4.5))
		mi.rotation.y = PI * 0.5 * sens
		_rue_n.add_child(mi)
		_voitures.append({"n": mi, "v": sens * (5.5 + i * 0.7), "x0": float(e[0]) - 12.0, "x1": float(e[2]) + 12.0})


func _rouler(dt: float) -> void:
	for v in _voitures:
		var n: Node3D = v.n
		n.position.x += float(v.v) * dt
		if n.position.x > float(v.x1):
			n.position.x = float(v.x0)
		elif n.position.x < float(v.x0):
			n.position.x = float(v.x1)


# --- Personnel -----------------------------------------------------------------------------------

## Employés à leur poste : [{piece, met, pid}] ; une pièce dont les métiers
## manquent affiche « poste vacant ».
func placer_employes(liste: Array) -> void:
	for f in employes:
		(f as Node).queue_free()
	employes.clear()
	var par_piece := {}
	for e in liste:
		var pc := String(e.piece)
		if not par_piece.has(pc):
			par_piece[pc] = []
		(par_piece[pc] as Array).append(e)
	for pid in GestionTypes.ordre(genre):
		var p := GestionTypes.piece(genre, String(pid))
		if int(niveaux.get(pid, 0)) <= 0:
			continue
		var postes: Array = p.get("postes", [])
		var gens: Array = par_piece.get(String(pid), [])
		if postes.is_empty():
			continue
		if gens.is_empty() and not (p.get("metiers", []) as Array).is_empty():
			_vacant(String(pid), Vector3(postes[0][0], 0, postes[0][1]))
			continue
		for i in mini(gens.size(), postes.size()):
			var e: Dictionary = gens[i]
			var f := Figurine.creer(int(e.get("pid", i + 100 * employes.size())), String(e.met))
			f.position = Vector3(postes[i][0], 0, postes[i][1])
			f.rotation.y = float(postes[i][2])
			f.regler(_geste(String(e.met), String(pid)))
			_gens.add_child(f)
			employes.append(f)


static func _geste(met: String, piece: String) -> String:
	match met:
		"receptionniste":
			return "guichet"
		"agent_etage":
			return "porter"
		"agent_proprete":
			return "ranger"
		"cuisinier":
			return "cuisiner"
		"serveur":
			if piece == "accueil":
				return "guichet"
			return "cafe" if piece in ["bar", "cave"] else "servir"
		"cadre":
			return "reunion"
		"maitre_nageur":
			return "soigner" if piece == "spa" else "conseiller"
		"vendeur":
			return "vendre"
		"caissier":
			return "caisse"
		"coach":
			return "entrainer"
		"magasinier", "chauffeur":
			return "porter"
		"maraicher", "jardinier":
			return "ranger"
		"mecanicien":
			return "marteler"
		"pompier":
			match piece:
				"accueil":
					return "guichet"
				"alerte":
					return "radio"
				"remise", "lavage":
					return "entretien_camion"
				"tour":
					return "lance"
				"sport":
					return "entrainer"
				"cuisine":
					return "cuisiner"
				"formation":
					return "expliquer"
				"bureau":
					return "taper"
				"reserve", "vestiaires":
					return "ranger"
				"dortoir":
					return "telephoner"
			return "radio"
		"policier":
			match piece:
				"accueil":
					return "guichet"
				"commandement":
					return "radio"
				"garage", "fourriere":
					return "entretien_camion"
				"tir":
					return "entrainer"
				"plaintes", "enquete", "bureau":
					return "taper"
				"armurerie", "repos":
					return "ranger"
				"pause":
					return "cafe"
				"cellules", "chenil", "parvis":
					return "surveiller"
			return "surveiller"
	return "conseiller"


func _vacant(pid: String, p: Vector3) -> void:
	var l := Label3D.new()
	l.text = "Poste vacant"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.01
	l.outline_size = 12
	l.modulate = Color("ffb4a2")
	l.outline_modulate = Color(0.2, 0.05, 0.05, 0.9)
	l.no_depth_test = true
	l.position = p + Vector3(0, 1.0, 0)
	_etiquettes.add_child(l)
	vacants[pid] = l


# --- Clients -------------------------------------------------------------------------------------

func _plan() -> Vector2:
	return GestionTypes.genre(genre).get("plan", Vector2(30, 22))


## Point du trottoir où les clients apparaissent et repartent.
func _rue() -> Vector3:
	var porte := _porte()
	var cote := -1.0 if rng.randf() < 0.5 else 1.0
	return Vector3(porte.x + cote * rng.randf_range(6.0, 18.0), 0, _plan().y + 11.7)


func _trottoir() -> Vector3:
	return Vector3(_porte().x, 0, _plan().y + 11.7)


func _porte() -> Vector3:
	var porte: Vector2 = GestionTypes.genre(genre).get("porte", Vector2(_plan().x * 0.5, _plan().y))
	return Vector3(porte.x, 0, porte.y)


func _hall() -> Vector3:
	var h: Vector2 = GestionTypes.genre(genre).get("hall", Vector2(_porte().x, _porte().z - 4.0))
	return Vector3(h.x, 0, h.y)


## Place n de la file devant le comptoir (0 = au guichet) ; la file se
## courbe vers la porte et sort sur le parvis si elle est longue.
func place_file(n: int) -> Vector3:
	var porte := _porte()
	var f: Vector2 = GestionTypes.genre(genre).get("file", Vector2(porte.x, porte.z - 4.0))
	var z := f.y + n * 0.95
	var t := clampf((z - (porte.z - 3.0)) / 2.5, 0.0, 1.0)
	return Vector3(lerpf(f.x, porte.x, t), 0, z)


## Chemin du hall jusqu'à une pièce (portes « via », puis points de passage).
func _portes_vers(pid: String) -> Array:
	var out: Array = []
	var p := GestionTypes.piece(genre, pid)
	if p.is_empty():
		return out
	var via := String(p.get("via", ""))
	if via != "":
		out.append_array(_portes_vers(via))
	if p.has("porte"):
		out.append(Vector3(p.porte[0], 0, p.porte[1]))
	for c in p.get("chemin", []):
		out.append(Vector3(c[0], 0, c[1]))
	return out


func ajouter_client() -> Dictionary:
	_n_client += 1
	var f := Figurine.creer(9000 + _n_client * 7, "")
	f.regler("client")
	f.position = _rue()
	_gens.add_child(f)
	var c := {"fig": f, "chemin": [_trottoir(), _porte() + Vector3(0, 0, 1.2), _porte() + Vector3(0, 0, -0.8)], "etat": "arrive",
		"piece": "", "place": -1, "pl": {}, "attente": 0.0, "bulle": null, "demande": {}, "id": _n_client}
	clients.append(c)
	return c


## Nombre de clients dans la file d'attente de la réception.
func file_attente() -> Array:
	var out: Array = []
	for c in clients:
		if String(c.etat) in ["file", "guichet"]:
			out.append(c)
	return out


## Envoie un client vers une place libre d'une pièce (false : rien de libre).
func installer(c: Dictionary, pid: String, duree: float) -> bool:
	var pl: Array = places.get(pid, [])
	var libres: Array = []
	for i in pl.size():
		if not _prises.has("%s:%d" % [pid, i]):
			libres.append(i)
	if libres.is_empty():
		return false
	var i: int = libres[rng.randi() % libres.size()]
	_prises["%s:%d" % [pid, i]] = true
	var place: Dictionary = pl[i]
	var chemin: Array = [_hall()]
	chemin.append_array(_portes_vers(pid))
	chemin.append_array(place.get("avant", []))
	chemin.append(Vector3(place.pos.x, 0, place.pos.z))
	c.chemin = chemin
	c.etat = "va"
	c.piece = pid
	c.place = i
	c.pl = place
	c.attente = duree
	return true


func _liberer(c: Dictionary) -> void:
	if String(c.piece) != "" and int(c.place) >= 0:
		_prises.erase("%s:%d" % [String(c.piece), int(c.place)])
	c.place = -1


## Le client sort de sa pièce et quitte l'établissement.
func _partir(c: Dictionary) -> void:
	_liberer(c)
	var f: Figurine = c.fig
	f.assise = false
	f.position.y = 0.0
	f.regler("client")
	var chemin: Array = []
	if String(c.piece) != "":
		var avant: Array = (c.get("pl", {}) as Dictionary).get("avant", []).duplicate()
		avant.reverse()
		chemin.append_array(avant)
		var portes := _portes_vers(String(c.piece))
		portes.reverse()
		chemin.append_array(portes)
		chemin.append(_hall())
	chemin.append(_porte() + Vector3(0, 0, -0.8))
	chemin.append(_porte() + Vector3(0, 0, 1.2))
	chemin.append(_trottoir())
	chemin.append(_rue())
	c.chemin = chemin
	c.etat = "part"
	c.piece = ""
	c.pl = {}
	poser_bulle(c, null)


func poser_bulle(c: Dictionary, l: Label3D) -> void:
	if c.bulle != null and is_instance_valid(c.bulle):
		(c.bulle as Node).queue_free()
	c.bulle = l
	if l != null:
		(c.fig as Node3D).add_child(l)
		l.position = Vector3(0, 2.35, 0)


## Avance les clients et les voitures (dt déjà mis à la vitesse du jeu).
## Renvoie les événements : [{type: "entre"|"installe"|"fini"|"sorti", client}].
func avancer(dt: float) -> Array:
	_t += dt
	_rouler(dt)
	_rouler_engins(dt)
	var ev: Array = []
	for f in employes:
		(f as Figurine).animer(_t)
	for c in clients.duplicate():
		var f: Figurine = c.fig
		if not is_instance_valid(f):
			clients.erase(c)
			continue
		if not (c.chemin as Array).is_empty():
			var cible: Vector3 = c.chemin[0]
			var d := Vector3(cible.x - f.position.x, 0, cible.z - f.position.z)
			var pas := VITESSE * dt
			if d.length() <= pas:
				f.position = Vector3(cible.x, f.position.y, cible.z)
				(c.chemin as Array).pop_front()
			else:
				f.position += d.normalized() * pas
				f.rotation.y = atan2(d.x, d.z)
			f.anim = "marcher"
			f.animer(_t)
			if (c.chemin as Array).is_empty():
				ev.append_array(_arrive(c))
			continue
		match String(c.etat):
			"file", "guichet":
				f.rotation.y = PI
			"installe":
				c.attente = float(c.attente) - dt
				if float(c.attente) <= 0.0:
					ev.append({"type": "fini", "client": c})
					_partir(c)
		f.animer(_t)
	return ev


func _arrive(c: Dictionary) -> Array:
	var f: Figurine = c.fig
	match String(c.etat):
		"arrive":
			c.etat = "file"
			f.regler("client")
			return [{"type": "entre", "client": c}]
		"file":
			f.regler("client")
			return []
		"va":
			c.etat = "installe"
			var place: Dictionary = c.get("pl", {})
			if not place.is_empty():
				f.rotation.y = float(place.rot)
				f.position.y = float(place.pos.y)
				if bool(place.assis):
					f.regler("client", true)
					f.hauteur_assise = 0.45
				else:
					f.regler("client")
			return [{"type": "installe", "client": c}]
		"part":
			f.queue_free()
			clients.erase(c)
			return [{"type": "sorti", "client": c}]
	return []


## Met à jour les places de la file (le premier au guichet).
func ranger_file() -> void:
	var file := file_attente()
	for i in file.size():
		var c: Dictionary = file[i]
		var p := place_file(i)
		var f: Figurine = c.fig
		if f.position.distance_to(p) > 0.05 and (c.chemin as Array).is_empty():
			c.chemin = [p]
		c.etat = "guichet" if i == 0 else "file"


## Client le plus proche d'un point de l'écran (pour les clics sur les bulles).
func client_sous(cam: Camera3D, ecran: Vector2, rayon := 34.0) -> Dictionary:
	var best := {}
	var bd := rayon
	for c in clients:
		if c.bulle == null or not is_instance_valid(c.bulle):
			continue
		var p := (c.fig as Node3D).global_position + Vector3(0, 2.35, 0)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(ecran)
		if d < bd:
			bd = d
			best = c
	return best


## Petit texte qui monte et s'efface (argent gagné, pourboire…).
func flotter(p: Vector3, texte: String, col := Color("ffe066")) -> void:
	var l := Label3D.new()
	l.text = texte
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.pixel_size = 0.011
	l.outline_size = 14
	l.modulate = col
	l.outline_modulate = Color(0.1, 0.08, 0.02, 0.9)
	l.no_depth_test = true
	l.position = p + Vector3(0, 2.0, 0)
	_etiquettes.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.6, 1.6)
	tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


# --- Engins de la remise (caserne) -----------------------------------------------------------------

## Place les engins de la caserne dans la remise : [{model, out}]. Un engin qui
## vient de partir sort en marche avant, gyrophares allumés, et s'en va par la
## rue ; un engin rentré réapparaît à sa place. Renvoie le nombre de départs.
func placer_engins(liste: Array, anime := true) -> int:
	var gd := GestionTypes.genre(genre)
	var baies: Array = gd.get("baies", [])
	var departs := 0
	while engins.size() > mini(liste.size(), baies.size()):
		var e: Dictionary = engins.pop_back()
		(e.n as Node).queue_free()
	for i in mini(liste.size(), baies.size()):
		var info: Dictionary = liste[i]
		var model := String(info.get("model", "fpt"))
		if i >= engins.size():
			engins.append({"n": null, "model": "", "etat": "gare", "feux": []})
		var e: Dictionary = engins[i]
		if String(e.model) != model and String(e.etat) != "part":
			if e.n != null:
				(e.n as Node).queue_free()
			_creer_engin(e, model, float(gd.get("engin_long", 5.6)))
		var place := Vector3(float(baies[i][0]), 0, float(baies[i][1]))
		var dehors := bool(info.get("out", false))
		match String(e.etat):
			"gare":
				if dehors:
					if anime:
						e.etat = "part"
						e.phase = 0
						departs += 1
					else:
						e.etat = "absent"
						(e.n as Node3D).visible = false
				else:
					(e.n as Node3D).position = place
					(e.n as Node3D).rotation.y = PI
					(e.n as Node3D).visible = true
			"absent":
				if not dehors:
					e.etat = "gare"
					(e.n as Node3D).position = place
					(e.n as Node3D).rotation.y = PI
					(e.n as Node3D).visible = true
					_feux(e, false)
	return departs


func _creer_engin(e: Dictionary, model: String, longueur: float) -> void:
	var root := Node3D.new()
	root.name = "Engin_" + model
	var t := VehicleCatalog.get_type(model)
	var mi := MeshInstance3D.new()
	mi.mesh = VehicleCatalog.build_mesh(model, 0, EvVisuels.material())
	var sc := minf(1.0, longueur / maxf(1.0, float(t.get("L", 6.0))))
	mi.scale = Vector3.ONE * sc
	root.add_child(mi)
	var feux: Array = []
	var box := BoxMesh.new()
	box.size = Vector3(0.38, 0.16, 0.26) * sc
	for p in VehicleCatalog.beacons(t):
		var bp: Vector3 = p
		var c := VehicleCatalog.beacon_color(t, bp.x)
		if not _feux_mat.has(c):
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 3.0
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_feux_mat[c] = m
		var f := MeshInstance3D.new()
		f.mesh = box
		f.material_override = _feux_mat[c]
		f.position = (bp + Vector3(0, 0.02, 0)) * sc
		f.visible = false
		root.add_child(f)
		feux.append(f)
	_engins_n.add_child(root)
	e.n = root
	e.model = model
	e.feux = feux


func _feux(e: Dictionary, on: bool, t := 0.0) -> void:
	var i := 0
	for f in e.feux:
		(f as Node3D).visible = on and (int(t * 4.0) + i) % 2 == 0
		i += 1


func _rouler_engins(dt: float) -> void:
	if engins.is_empty():
		return
	var plan := _plan()
	var e_ := emprise()
	var rz := plan.y + 12.4 + 1.5
	for e in engins:
		if String(e.etat) != "part" or e.n == null:
			continue
		var n: Node3D = e.n
		_feux(e, true, _t)
		var v := 7.0 * dt
		if int(e.phase) == 0:
			# Sortie en marche avant jusqu'à la rue.
			n.rotation.y = PI
			n.position.z += v
			if n.position.z >= rz:
				n.position.z = rz
				e.phase = 1
		else:
			# Dans la rue, vers la droite.
			n.rotation.y = -PI * 0.5
			n.position.x += v * 1.6
			if n.position.x > float(e_[2]) + 14.0:
				e.etat = "absent"
				n.visible = false
				_feux(e, false)
	if _alerte_t > 0.0:
		_alerte_t -= dt
		if _alerte_l != null:
			_alerte_l.visible = _alerte_t > 0.0 and int(_alerte_t * 3.0) % 2 == 0


## Sonnerie d'alerte : « ALERTE ! » clignote au-dessus de la salle d'alerte.
func alerte(texte := "ALERTE !") -> void:
	if _alerte_l == null or not is_instance_valid(_alerte_l):
		_alerte_l = Label3D.new()
		_alerte_l.name = "Alerte"
		_alerte_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_alerte_l.font_size = 96
		_alerte_l.pixel_size = 0.016
		_alerte_l.outline_size = 22
		_alerte_l.modulate = Color("ff4d4d")
		_alerte_l.outline_modulate = Color(0.25, 0, 0, 1)
		_alerte_l.no_depth_test = true
		_engins_n.add_child(_alerte_l)
	_alerte_l.text = texte
	var c := centre("alerte") if GestionTypes.pieces(genre).has("alerte") else centre(String(GestionTypes.genre(genre).get("accueil", "")))
	_alerte_l.position = c + Vector3(0, 4.2, 0)
	_alerte_t = 4.0
