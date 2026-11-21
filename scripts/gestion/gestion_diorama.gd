class_name GestionDiorama
extends Node3D
## Maquette 3D du mode gestion, vue en isométrique : le rez-de-chaussée du
## bâtiment coupé comme une maison de poupée (murs du fond hauts, murs de
## devant rasés), ses pièces meublées selon leur niveau, le personnel à son
## poste et les clients qui vont et viennent.
##
## Tout est construit en code (LpKit, figurines des métiers) à partir de
## GestionTypes : un nouveau genre de bâtiment n'a besoin que de ses pièces et
## de ses décors (fonctions _decor_<nom>). Les pièces pas encore construites
## sont des emplacements de chantier, avec leur prix.
##
## Coordonnées : mètres, x vers la droite, z vers la rue (la caméra regarde
## depuis l'angle x+ z+). Les décors donnent les « places » où les clients
## s'installent : {pos, rot, assis, avant (point de passage)}.

signal client_clique(index: int)

const H_FOND := 2.8
const H_INTERIEUR := 1.3
const H_DEVANT := 0.45
const EP := 0.18
const PORTE := 1.5
const VITESSE := 1.5

var genre := ""
var niveaux: Dictionary = {}
var etoiles := 3
## Places des clients par pièce : pid → [{pos, rot, assis, avant}].
var places: Dictionary = {}
## Places prises : "pid:i" → true.
var _prises: Dictionary = {}
## Employés visibles : [Figurine].
var employes: Array = []
## Clients : [{fig, chemin, etat, piece, place, attente, bulle}].
var clients: Array = []
## Postes vacants affichés : pid → Label3D.
var vacants: Dictionary = {}
var _statique: Node3D
var _gens: Node3D
var _etiquettes: Node3D
var _surbrillance: MeshInstance3D
var _materiaux := {}
var _t := 0.0
var _n_client := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 4242
	_materiaux = {"base": LpKit.vertex_material(0.85), "eau": _materiau_eau(), "verre": _materiau_verre()}
	_statique = Node3D.new()
	_statique.name = "Decor"
	add_child(_statique)
	_gens = Node3D.new()
	_gens.name = "Gens"
	add_child(_gens)
	_etiquettes = Node3D.new()
	_etiquettes.name = "Etiquettes"
	add_child(_etiquettes)


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


# --- Construction ------------------------------------------------------------------------------

## Reconstruit le décor (après une amélioration). Les clients restent.
func construire(g: String, niv: Dictionary, nb_etoiles := 3) -> void:
	genre = g
	niveaux = niv.duplicate()
	etoiles = nb_etoiles
	for c in _statique.get_children():
		c.queue_free()
	for c in _etiquettes.get_children():
		c.queue_free()
	vacants.clear()
	places.clear()
	var k := LpKit.new(7)
	k.jitter = 0.025
	var gd := GestionTypes.genre(g)
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	_sol(k, plan)
	for pid in GestionTypes.ordre(g):
		var p := GestionTypes.piece(g, String(pid))
		var n := int(niveaux.get(pid, 0))
		var r: Array = p.rect
		var dehors := GestionTypes.est_dehors(g, String(pid))
		if n <= 0:
			_chantier(k, r, dehors)
			_etiquette_chantier(String(pid), p)
			continue
		if not dehors:
			k.box(Vector3(r[0] + r[2] * 0.5, 0.03, r[1] + r[3] * 0.5), Vector3(r[2], 0.06, r[3]), Color(String(p.get("sol", "cccccc"))), 0.0, false)
		var f := "_decor_" + String(p.get("decor", ""))
		var pl: Array = []
		if has_method(f):
			pl = call(f, k, r, n)
		places[String(pid)] = pl
	_murs(k, gd)
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


func _sol(k: LpKit, plan: Vector2) -> void:
	# Pelouse, trottoir et rue devant.
	k.box(Vector3(plan.x * 0.5 + 6, -0.06, plan.y * 0.5 + 4), Vector3(plan.x + 44, 0.1, plan.y + 40), Color("5f9e4c"), 0.0, false)
	k.box(Vector3(plan.x * 0.5 + 6, -0.02, plan.y + 13.5), Vector3(plan.x + 44, 0.06, 2.2), Color("cfcac0"), 0.0, false)
	k.box(Vector3(plan.x * 0.5 + 6, -0.03, plan.y + 17.5), Vector3(plan.x + 44, 0.06, 6.0), Color("55595f"), 0.0, false)
	for i in 12:
		k.box(Vector3(-10 + i * 5.0, 0.01, plan.y + 17.5), Vector3(2.2, 0.02, 0.18), Color("f2f2ee"), 0.0, false)
	# Allée devant la porte.
	var porte: Vector2 = GestionTypes.genre(genre).get("porte", Vector2(plan.x * 0.5, plan.y))
	k.box(Vector3(porte.x, 0.0, plan.y + 6.4), Vector3(2.2, 0.05, 12.8), Color("d8cfbe"), 0.0, false)
	# Quelques arbres et haies autour.
	for t in [Vector3(-4, 0, 2), Vector3(-4, 0, 10), Vector3(-4, 0, 18), Vector3(34, 0, 1.5), Vector3(44, 0, 3), Vector3(44, 0, 22), Vector3(-5, 0, 26)]:
		k.tube(t, t + Vector3(0, 1.4, 0), 0.16, 0.12, 6, Color("7a5536"))
		k.blob(t + Vector3(0, 2.4, 0), Vector3(1.3, 1.3, 1.3), Color("3f7d3a"), Color("6fae55"), 0.15, 1)
	for i in 6:
		k.box(Vector3(31.0, 0.45, 0.6 + i * 1.0), Vector3(0.8, 0.9, 0.9), Color("4f8f45"), 0.08)


## Emplacement vide : gravier, piquets et ruban.
func _chantier(k: LpKit, r: Array, dehors: bool) -> void:
	var c := Vector3(r[0] + r[2] * 0.5, 0.0, r[1] + r[3] * 0.5)
	k.box(c + Vector3(0, 0.02, 0), Vector3(r[2] - 0.2, 0.04, r[3] - 0.2), Color("bfb5a3") if not dehors else Color("a9b98f"), 0.0, false)
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
	l.position = centre(pid) + Vector3(0, 1.4, 0)
	l.name = "Chantier_" + pid
	_etiquettes.add_child(l)


## Murs de toutes les pièces construites, avec les portes (GestionTypes "porte").
func _murs(k: LpKit, gd: Dictionary) -> void:
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	var couleur := Color(String(gd.get("murs", "e9dcc6")))
	var portes: Array = [gd.get("porte", Vector2(plan.x * 0.5, plan.y))]
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
			# Hauteur : fond du bâtiment haut, devant rasé, entre les pièces à mi-hauteur.
			var h := H_INTERIEUR
			if (a.x == b.x and a.x <= 0.01) or (a.y == b.y and a.y <= 0.01):
				h = H_FOND
			elif (a.x == b.x and a.x >= plan.x - 0.01) or (a.y == b.y and a.y >= plan.y - 0.01):
				h = H_DEVANT
			_mur(k, a, b, h, couleur, portes)


func _mur(k: LpKit, a: Vector2, b: Vector2, h: float, col: Color, portes: Array) -> void:
	var horiz := absf(b.x - a.x) > 0.01
	var t0 := a.x if horiz else a.y
	var t1 := b.x if horiz else b.y
	var fixe := a.y if horiz else a.x
	# Trous des portes sur ce mur.
	var trous: Array = []
	for pt in portes:
		var q: Vector2 = pt
		var sur := absf((q.y if horiz else q.x) - fixe) < 0.05
		var t := q.x if horiz else q.y
		if sur and t > t0 and t < t1:
			trous.append([t - PORTE * 0.5, t + PORTE * 0.5])
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
		if h >= H_FOND:
			# Plinthe et frise : les murs du fond ne sont pas des aplats.
			k.box(pos + Vector3(0, -h * 0.5 + 0.08, 0), Vector3(sz.x + 0.01, 0.16, sz.z + 0.01), col.darkened(0.35), 0.0, false)


# --- Mobilier ----------------------------------------------------------------------------------

func _plante(k: LpKit, p: Vector3, taille := 1.0) -> void:
	k.box(p + Vector3(0, 0.22 * taille, 0), Vector3(0.45, 0.44, 0.45) * taille, Color("c0703f"))
	k.blob(p + Vector3(0, 0.85 * taille, 0), Vector3(0.45, 0.55, 0.45) * taille, Color("2f6b35"), Color("6fbf5a"), 0.2, 1)


func _chaise(k: LpKit, p: Vector3, rot: float, col: Color) -> void:
	var dos := Vector3(sin(rot), 0, cos(rot)) * -0.2
	k.box(p + Vector3(0, 0.42, 0), Vector3(0.45, 0.08, 0.45), col)
	k.box(p + dos + Vector3(0, 0.7, 0), Vector3(0.45 if absf(cos(rot)) > 0.5 else 0.08, 0.55, 0.08 if absf(cos(rot)) > 0.5 else 0.45), col.darkened(0.15))
	for dx in [-0.18, 0.18]:
		for dz in [-0.18, 0.18]:
			k.box(p + Vector3(dx, 0.2, dz), Vector3(0.05, 0.4, 0.05), Color("5b4636"), 0.0, false)


func _fauteuil(k: LpKit, p: Vector3, rot: float, col: Color) -> void:
	var dos := Vector3(sin(rot), 0, cos(rot)) * -0.3
	var large := absf(cos(rot)) > 0.5
	k.box(p + Vector3(0, 0.25, 0), Vector3(0.8, 0.4, 0.8), col)
	k.box(p + dos + Vector3(0, 0.6, 0), Vector3(0.8 if large else 0.2, 0.6, 0.2 if large else 0.8), col.darkened(0.12))


## Place assise ou debout pour un client.
func _place(pos: Vector3, rot: float, assis: bool, avant := Vector3.INF) -> Dictionary:
	return {"pos": pos, "rot": rot, "assis": assis, "avant": avant}


func _decor_reception(k: LpKit, r: Array, n: int) -> Array:
	var cx := float(r[0]) + float(r[2]) * 0.5
	# Comptoir : bois, puis marbre et dorures aux niveaux élevés.
	var bois := Color("8a5a3b") if n < 3 else Color("e8e2d6")
	k.box(Vector3(cx, 0.55, 16.9), Vector3(4.6, 1.1, 0.7), bois)
	k.box(Vector3(cx, 1.12, 16.9), Vector3(4.8, 0.06, 0.8), Color("3d2b20") if n < 3 else Color("d4af37"))
	k.box(Vector3(cx + 1.6, 1.25, 16.9), Vector3(0.4, 0.2, 0.3), Color("2b2d42"))
	k.box(Vector3(cx - 1.4, 1.2, 16.9), Vector3(0.18, 0.1, 0.18), Color("e9c46a"))
	# Casier à clés au mur du fond du hall.
	k.box(Vector3(cx, 1.0, 14.2), Vector3(3.0, 1.3, 0.2), Color("6b4a32"))
	for i in 10:
		k.box(Vector3(cx - 1.2 + (i % 5) * 0.6, 0.65 + (i / 5) * 0.55, 14.32), Vector3(0.4, 0.35, 0.05), Color("e9c46a").darkened(0.2))
	# Tapis devant le comptoir et file d'attente (poteaux et cordon).
	k.box(Vector3(cx, 0.07, 19.3), Vector3(2.0, 0.02, 4.6), Color("b23a48") if n >= 2 else Color("9c8f7a"), 0.0, false)
	for i in 4:
		k.box(Vector3(cx + 1.25, 0.45, 17.9 + i * 1.2), Vector3(0.08, 0.9, 0.08), Color("d4af37"))
		k.box(Vector3(cx - 1.25, 0.45, 17.9 + i * 1.2), Vector3(0.08, 0.9, 0.08), Color("d4af37"))
	if n >= 2:
		for x in [float(r[0]) + 1.4, float(r[0]) + float(r[2]) - 1.4]:
			k.box(Vector3(x, 0.3, 20.0), Vector3(1.0, 0.5, 2.4), Color("2a9d8f") if n < 4 else Color("1d3557"))
			k.box(Vector3(x, 0.2, 18.2), Vector3(0.7, 0.4, 0.7), Color("8a5a3b"))
	if n >= 3:
		_plante(k, Vector3(float(r[0]) + 0.6, 0, 14.6))
		_plante(k, Vector3(float(r[0]) + float(r[2]) - 0.6, 0, 14.6))
		_plante(k, Vector3(float(r[0]) + 0.6, 0, 21.4), 0.8)
	if n >= 4:
		# Chariot à bagages doré.
		k.box(Vector3(float(r[0]) + float(r[2]) - 1.6, 0.4, 16.0), Vector3(1.0, 0.08, 0.6), Color("d4af37"))
		k.box(Vector3(float(r[0]) + float(r[2]) - 1.6, 0.7, 16.0), Vector3(0.6, 0.5, 0.4), Color("6d4c41"))
	if n >= 5:
		# Lustre (posé haut, vu de dessus) et colonnes.
		k.lathe(Vector3(cx, 2.4, 19.0), [Vector2(0.0, 0.0), Vector2(0.6, 0.15), Vector2(0.5, 0.4), Vector2(0.0, 0.5)], 8, Color("f6e7a1"))
	# Places : la file d'attente devant le comptoir (gérée à part) et les canapés.
	var out: Array = []
	if n >= 2:
		out.append(_place(Vector3(float(r[0]) + 1.4, 0.0, 19.4), PI * 0.5, true))
		out.append(_place(Vector3(float(r[0]) + float(r[2]) - 1.4, 0.0, 20.6), -PI * 0.5, true))
	return out


func _decor_chambres(k: LpKit, r: Array, n: int) -> Array:
	var out: Array = []
	var ouvertes: int = [0, 3, 4, 5, 5, 5][clampi(n, 0, 5)]
	var draps: Color = [Color("f1faee"), Color("e9f5db"), Color("a8dadc"), Color("ffd6a5"), Color("cdb4db"), Color("f6e7a1")][clampi(n, 0, 5)]
	var couvre: Color = [Color("457b9d"), Color("457b9d"), Color("2a9d8f"), Color("e76f51"), Color("6d597a"), Color("b5838d")][clampi(n, 0, 5)]
	var x0 := float(r[0])
	var rows := 5
	var hz := float(r[3]) / rows
	# Couloir le long des chambres.
	k.box(Vector3(x0 + 9.2, 0.07, float(r[1]) + float(r[3]) * 0.5), Vector3(1.6, 0.02, float(r[3]) - 0.4), Color("9b2226") if n >= 3 else Color("b08968"), 0.0, false)
	for i in rows:
		var z0 := float(r[1]) + i * hz
		var cz := z0 + hz * 0.5
		# Cloisons entre chambres et côté couloir (avec la porte).
		if i > 0:
			k.box(Vector3(x0 + 4.2, H_INTERIEUR * 0.5, z0), Vector3(8.4, H_INTERIEUR, EP), Color("e9dcc6"), 0.0, false)
		k.box(Vector3(x0 + 8.4, H_INTERIEUR * 0.5, z0 + 0.9), Vector3(EP, H_INTERIEUR, 1.8), Color("e9dcc6"), 0.0, false)
		k.box(Vector3(x0 + 8.4, H_INTERIEUR * 0.5, z0 + hz - 0.6), Vector3(EP, H_INTERIEUR, 1.2), Color("e9dcc6"), 0.0, false)
		if i >= ouvertes:
			# Chambre en travaux : bâche et pots de peinture.
			k.box(Vector3(x0 + 4.2, 0.08, cz), Vector3(8.0, 0.04, hz - 0.3), Color("7d7466"), 0.0, false)
			k.box(Vector3(x0 + 3.0, 0.2, cz), Vector3(0.4, 0.4, 0.4), Color("e9c46a"))
			k.box(Vector3(x0 + 5.6, 0.5, cz - 0.6), Vector3(1.6, 1.0, 0.1), Color("adb5bd"))
			continue
		k.box(Vector3(x0 + 4.2, 0.075, cz), Vector3(8.2, 0.03, hz - 0.2), Color("deb887") if n < 4 else Color("caa472"), 0.0, false)
		# Lit double contre le mur de gauche.
		k.box(Vector3(x0 + 1.3, 0.25, cz), Vector3(2.1, 0.5, 1.7), Color("6d4c41"))
		k.box(Vector3(x0 + 1.4, 0.55, cz), Vector3(1.9, 0.12, 1.6), draps)
		k.box(Vector3(x0 + 1.8, 0.6, cz), Vector3(1.1, 0.06, 1.66), couvre)
		k.box(Vector3(x0 + 0.5, 0.68, cz - 0.4), Vector3(0.35, 0.14, 0.6), Color("ffffff"))
		k.box(Vector3(x0 + 0.5, 0.68, cz + 0.4), Vector3(0.35, 0.14, 0.6), Color("ffffff"))
		k.box(Vector3(x0 + 0.12, 0.8, cz), Vector3(0.12, 0.9, 1.9), Color("8a5a3b"))
		# Tables de nuit et lampes.
		for dz in [-1.2, 1.2]:
			k.box(Vector3(x0 + 0.45, 0.25, cz + dz), Vector3(0.45, 0.5, 0.45), Color("8a5a3b"))
			k.box(Vector3(x0 + 0.45, 0.62, cz + dz), Vector3(0.18, 0.25, 0.18), Color("ffe8a3"))
		# Salle de bains au fond (plus belle aux niveaux élevés).
		k.box(Vector3(x0 + 6.9, 0.08, cz - 0.6), Vector3(2.6, 0.04, hz - 1.6), Color("bfe3ea"), 0.0, false)
		k.box(Vector3(x0 + 7.6, 0.45, cz - 0.9), Vector3(0.6, 0.5, 0.5), Color("f8f9fa"))
		if n >= 4:
			k.box(Vector3(x0 + 6.4, 0.3, cz - 0.9), Vector3(1.6, 0.6, 0.8), Color("ffffff"))
			k.box(Vector3(x0 + 6.4, 0.55, cz - 0.9), Vector3(1.3, 0.05, 0.55), Color("7ec8e3"))
		# Fauteuil, bureau, télé selon le niveau.
		if n >= 2:
			_fauteuil(k, Vector3(x0 + 4.4, 0, cz + 1.2), PI, couvre)
		if n >= 3:
			k.box(Vector3(x0 + 4.4, 0.4, z0 + 0.35), Vector3(1.4, 0.8, 0.4), Color("5c4033"))
			k.box(Vector3(x0 + 4.4, 1.0, z0 + 0.3), Vector3(1.0, 0.55, 0.06), Color("1b1b1e"))
		if n >= 5:
			_plante(k, Vector3(x0 + 3.2, 0, z0 + 0.5), 0.7)
		out.append(_place(Vector3(x0 + 3.0, 0.0, cz + 0.3), -PI * 0.5, false, Vector3(x0 + 9.2, 0, cz)))
	return out


func _decor_lingerie(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	for i in mini(1 + n, 5):
		var p := Vector3(x0 + 0.7 + i * 1.0, 0.45, z0 + 0.6)
		k.box(p, Vector3(0.85, 0.9, 0.8), Color("f8f9fa"))
		k.box(p + Vector3(0, 0.05, 0.41), Vector3(0.5, 0.5, 0.02), Color("4a4e69"))
	# Étagères de linge coloré.
	k.box(Vector3(x0 + 5.5, 0.9, z0 + 3.0), Vector3(0.5, 1.8, 3.4), Color("8a5a3b"))
	for j in 3:
		for i in 4:
			k.box(Vector3(x0 + 5.45, 0.5 + j * 0.55, z0 + 1.7 + i * 0.85), Vector3(0.4, 0.22, 0.6), [Color("ffffff"), Color("a8dadc"), Color("ffd6a5")][(i + j) % 3])
	# Chariot de ménage.
	k.box(Vector3(x0 + 2.0, 0.5, z0 + 4.4), Vector3(1.0, 0.8, 0.6), Color("457b9d"))
	k.box(Vector3(x0 + 2.0, 0.95, z0 + 4.4), Vector3(0.8, 0.1, 0.5), Color("ffffff"))
	return []


func _decor_bureau(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 2.0, 0.38, z0 + 1.6), Vector3(2.2, 0.08, 1.0), Color("5c4033") if n < 3 else Color("3d2b20"))
	k.box(Vector3(x0 + 2.0, 0.19, z0 + 1.6), Vector3(2.0, 0.38, 0.9), Color("6b4a32"))
	k.box(Vector3(x0 + 2.0, 0.65, z0 + 1.4), Vector3(0.7, 0.45, 0.05), Color("1b1b1e"))
	k.box(Vector3(x0 + 0.4, 0.9, z0 + 3.4), Vector3(0.5, 1.8, 2.0), Color("8a5a3b"))
	# Tableau des réservations au mur du fond.
	k.box(Vector3(x0 + 2.0, 1.8, z0 + 0.15), Vector3(2.6, 1.0, 0.06), Color("f8f9fa"))
	for i in mini(2 + n, 7):
		k.box(Vector3(x0 + 1.0 + i * 0.32, 1.8 + (i % 2) * 0.2, z0 + 0.19), Vector3(0.24, 0.18, 0.02), [Color("e76f51"), Color("2a9d8f"), Color("e9c46a")][i % 3])
	if n >= 2:
		_plante(k, Vector3(x0 + 3.4, 0, z0 + 5.2), 0.8)
	return []


func _decor_bar(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var cuir: Color = [Color("8a5a3b"), Color("8a5a3b"), Color("6d2e46"), Color("1d3557"), Color("264653"), Color("7b2d26")][clampi(n, 0, 5)]
	# Comptoir et bouteilles.
	k.box(Vector3(x0 + 3.5, 0.55, z0 + 2.0), Vector3(5.0, 1.1, 0.7), Color("3d2b20"))
	k.box(Vector3(x0 + 3.5, 1.12, z0 + 2.0), Vector3(5.2, 0.06, 0.8), Color("d4af37") if n >= 4 else Color("6b4a32"))
	k.box(Vector3(x0 + 3.5, 1.4, z0 + 0.2), Vector3(5.0, 1.6, 0.25), Color("5c4033"))
	for i in 14:
		k.box(Vector3(x0 + 1.3 + i * 0.32, 1.45 + (i % 3) * 0.42, z0 + 0.34), Vector3(0.1, 0.32, 0.1),
			[Color("2a9d8f"), Color("e9c46a"), Color("e76f51"), Color("8ecae6")][i % 4], 0.0, false)
	# Tabourets devant le comptoir.
	for i in 4:
		var p := Vector3(x0 + 1.8 + i * 1.1, 0, z0 + 2.75)
		k.box(p + Vector3(0, 0.38, 0), Vector3(0.4, 0.08, 0.4), cuir)
		k.box(p + Vector3(0, 0.18, 0), Vector3(0.08, 0.36, 0.08), Color("adb5bd"), 0.0, false)
		out.append(_place(p, PI, true))
	# Petites tables et fauteuils (plus nombreux avec le niveau).
	var tables := [Vector3(x0 + 2.2, 0, z0 + 5.6), Vector3(x0 + 8.0, 0, z0 + 3.6), Vector3(x0 + 8.0, 0, z0 + 6.4), Vector3(x0 + 6.2, 0, z0 + 6.6)]
	for i in mini(1 + n, tables.size()):
		var t: Vector3 = tables[i]
		k.lathe(t, [Vector2(0.0, 0.0), Vector2(0.15, 0.02), Vector2(0.08, 0.5), Vector2(0.45, 0.52), Vector2(0.45, 0.58), Vector2(0.0, 0.58)], 10, Color("3d2b20"))
		_fauteuil(k, t + Vector3(-0.85, 0, 0), PI * 0.5, cuir)
		_fauteuil(k, t + Vector3(0.85, 0, 0), -PI * 0.5, cuir)
		out.append(_place(t + Vector3(-0.85, 0, 0), PI * 0.5, true))
		out.append(_place(t + Vector3(0.85, 0, 0), -PI * 0.5, true))
	if n >= 3:
		# Piano à queue.
		k.box(Vector3(x0 + 8.4, 0.75, z0 + 1.2), Vector3(1.4, 0.3, 1.6), Color("111111"))
		k.box(Vector3(x0 + 8.4, 0.35, z0 + 1.2), Vector3(0.2, 0.7, 0.2), Color("111111"), 0.0, false)
		k.box(Vector3(x0 + 8.4, 0.92, z0 + 2.05), Vector3(1.3, 0.04, 0.2), Color("f8f9fa"))
	if n >= 5:
		_plante(k, Vector3(x0 + 0.6, 0, z0 + 7.4))
	return out


func _decor_restaurant(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Cuisine ouverte le long du mur de droite.
	k.box(Vector3(x0 + 8.8, 0.07, z0 + 5.0), Vector3(2.4, 0.02, 10.0), Color("d9d9d9"), 0.0, false)
	for i in 3:
		var p := Vector3(x0 + 9.4, 0.45, z0 + 1.4 + i * 1.6)
		k.box(p, Vector3(0.8, 0.9, 1.4), Color("adb5bd"))
		k.box(p + Vector3(0, 0.47, 0), Vector3(0.7, 0.04, 1.2), Color("343a40"))
	k.box(Vector3(x0 + 9.4, 0.45, z0 + 7.0), Vector3(0.8, 0.9, 1.6), Color("f8f9fa"))
	k.box(Vector3(x0 + 7.7, 0.5, z0 + 3.0), Vector3(0.6, 1.0, 4.0), Color("6b4a32"))
	k.box(Vector3(x0 + 7.7, 1.02, z0 + 3.0), Vector3(0.7, 0.05, 4.1), Color("e9ecef"))
	var nappe: Color = [Color("ffffff"), Color("ffffff"), Color("f1faee"), Color("e63946"), Color("ffffff"), Color("f6e7a1")][clampi(n, 0, 5)]
	var tables := [Vector3(x0 + 2.2, 0, z0 + 2.4), Vector3(x0 + 5.2, 0, z0 + 2.4), Vector3(x0 + 2.2, 0, z0 + 5.2),
		Vector3(x0 + 5.2, 0, z0 + 5.2), Vector3(x0 + 2.2, 0, z0 + 8.0), Vector3(x0 + 5.2, 0, z0 + 8.0)]
	var nb: int = [0, 2, 3, 4, 6, 6][clampi(n, 0, 5)]
	for i in nb:
		var t: Vector3 = tables[i]
		k.box(t + Vector3(0, 0.74, 0), Vector3(1.1, 0.06, 1.1), nappe)
		k.box(t + Vector3(0, 0.37, 0), Vector3(0.12, 0.74, 0.12), Color("3d2b20"), 0.0, false)
		k.box(t + Vector3(0, 0.82, 0), Vector3(0.12, 0.12, 0.12), Color("e9c46a") if n >= 3 else Color("ffffff"))
		_chaise(k, t + Vector3(-0.8, 0, 0), PI * 0.5, Color("8a5a3b"))
		_chaise(k, t + Vector3(0.8, 0, 0), -PI * 0.5, Color("8a5a3b"))
		out.append(_place(t + Vector3(-0.8, 0, 0), PI * 0.5, true))
		out.append(_place(t + Vector3(0.8, 0, 0), -PI * 0.5, true))
	if n >= 3:
		_plante(k, Vector3(x0 + 0.6, 0, z0 + 0.6))
	if n >= 4:
		# Buffet du petit-déjeuner.
		k.box(Vector3(x0 + 3.7, 0.45, z0 + 0.5), Vector3(3.0, 0.9, 0.7), Color("f8f9fa"))
		for i in 5:
			k.box(Vector3(x0 + 2.5 + i * 0.6, 0.98, z0 + 0.5), Vector3(0.4, 0.12, 0.4), [Color("e9c46a"), Color("e76f51"), Color("90be6d")][i % 3])
	return out


func _decor_spa(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Tables de massage.
	for i in mini(1 + n / 2, 3):
		var p := Vector3(x0 + 2.0 + i * 2.6, 0, z0 + 2.2)
		k.box(p + Vector3(0, 0.6, 0), Vector3(0.8, 0.12, 2.0), Color("f8f9fa"))
		k.box(p + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 1.4), Color("c9ada7"))
		_plante(k, p + Vector3(1.1, 0, -0.9), 0.5)
		out.append(_place(p + Vector3(0, 0.0, 0.0), PI, true))
	# Hammam (cabine vitrée).
	if n >= 2:
		k.box(Vector3(x0 + 8.2, 1.0, z0 + 9.0), Vector3(2.6, 2.0, 2.6), Color("e9ecef"))
		k.layer = "verre"
		k.box(Vector3(x0 + 6.88, 1.0, z0 + 9.0), Vector3(0.05, 1.9, 2.4), Color(0.75, 0.9, 0.95, 0.45), 0.0, false)
		k.layer = "base"
	# Bassin chaud.
	if n >= 3:
		k.box(Vector3(x0 + 3.2, 0.25, z0 + 8.2), Vector3(3.6, 0.5, 3.0), Color("e9ecef"))
		k.layer = "eau"
		k.box(Vector3(x0 + 3.2, 0.48, z0 + 8.2), Vector3(3.2, 0.06, 2.6), Color(0.4, 0.75, 0.85, 0.8), 0.0, false)
		k.layer = "base"
		out.append(_place(Vector3(x0 + 3.2, 0.0, z0 + 8.2), PI * 0.25, false))
	# Banc et tisanes.
	k.box(Vector3(x0 + 5.0, 0.25, z0 + 11.2), Vector3(3.0, 0.5, 0.5), Color("b08968"))
	out.append(_place(Vector3(x0 + 4.2, 0, z0 + 11.2), PI, true))
	out.append(_place(Vector3(x0 + 5.8, 0, z0 + 11.2), PI, true))
	if n >= 4:
		_plante(k, Vector3(x0 + 0.6, 0, z0 + 11.2))
		_plante(k, Vector3(x0 + 0.6, 0, z0 + 6.0))
	return out


func _decor_piscine(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var dims: Vector2 = [Vector2(3, 5), Vector2(4, 6), Vector2(5, 8), Vector2(6, 9), Vector2(6.5, 10.5), Vector2(6.5, 10.5)][clampi(n, 0, 5)]
	var c := Vector3(x0 + float(r[2]) * 0.62, 0, z0 + float(r[3]) * 0.5)
	# Plage carrelée, margelle et eau.
	k.box(Vector3(x0 + float(r[2]) * 0.5, 0.03, z0 + float(r[3]) * 0.5), Vector3(r[2], 0.06, r[3]), Color("efe6d2"), 0.0, false)
	k.box(c + Vector3(0, 0.08, 0), Vector3(dims.x + 0.6, 0.12, dims.y + 0.6), Color("f8f9fa"))
	k.box(c + Vector3(0, 0.1, 0), Vector3(dims.x, 0.1, dims.y), Color("3a86c8"), 0.0, false)
	k.layer = "eau"
	k.box(c + Vector3(0, 0.16, 0), Vector3(dims.x, 0.04, dims.y), Color(0.35, 0.78, 0.95, 0.75), 0.0, false)
	k.layer = "base"
	# Transats et parasols.
	var nb: int = [0, 2, 4, 5, 7, 8][clampi(n, 0, 5)]
	for i in nb:
		var p := Vector3(x0 + 1.0, 0, z0 + 1.0 + i * 1.5)
		k.box(p + Vector3(0, 0.25, 0), Vector3(1.6, 0.12, 0.6), Color("f8f9fa"))
		k.box(p + Vector3(-0.65, 0.42, 0), Vector3(0.35, 0.35, 0.58), Color("e9c46a") if i % 2 == 0 else Color("2a9d8f"))
		out.append(_place(p, PI * 0.5, true))
		if n >= 2 and i % 2 == 1:
			k.box(p + Vector3(0.9, 1.0, 0.7), Vector3(0.05, 2.0, 0.05), Color("8a5a3b"), 0.0, false)
			k.lathe(p + Vector3(0.9, 1.9, 0.7), [Vector2(0.0, 0.0), Vector2(1.1, 0.0), Vector2(0.0, 0.35)], 8, Color("e63946") if i % 4 == 1 else Color("f8f9fa"))
	# Nageurs.
	for i in mini(n, 3):
		out.append(_place(c + Vector3(-dims.x * 0.25 + i * dims.x * 0.25, -0.9, -dims.y * 0.2 + i * dims.y * 0.2), PI * 0.5 * i, false))
	if n >= 3:
		# Chaise du maître-nageur.
		k.box(Vector3(x0 + 1.2, 0.8, z0 + float(r[3]) - 1.0), Vector3(0.6, 0.1, 0.6), Color("f8f9fa"))
		k.box(Vector3(x0 + 1.2, 0.4, z0 + float(r[3]) - 1.0), Vector3(0.08, 0.8, 0.08), Color("adb5bd"), 0.0, false)
	if n >= 5:
		# Toboggan.
		var a := c + Vector3(dims.x * 0.5 + 0.8, 2.2, -dims.y * 0.4)
		k.box(a + Vector3(0.3, -1.1, 0), Vector3(0.12, 2.2, 0.12), Color("adb5bd"), 0.0, false)
		k.beam(a, c + Vector3(dims.x * 0.3, 0.25, -dims.y * 0.15), 0.9, 0.2, Color("ffb703"))
	return out


func _decor_parking(k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + float(r[2]) * 0.5, 0.02, z0 + float(r[3]) * 0.5), Vector3(r[2], 0.04, r[3]), Color("6b6f75"), 0.0, false)
	var porte: Vector2 = GestionTypes.genre(genre).get("porte", Vector2(15, 22))
	k.box(Vector3(porte.x, 0.04, z0 + float(r[3]) * 0.5), Vector3(2.2, 0.04, r[3]), Color("d8cfbe"), 0.0, false)
	var slots: Array = []
	for i in 12:
		var x := x0 + 1.4 + i * 2.5
		if absf(x - porte.x) < 2.0:
			continue
		slots.append(Vector3(x, 0, z0 + 2.2))
		slots.append(Vector3(x, 0, z0 + 5.8))
	for s in slots:
		var p: Vector3 = s
		k.box(p + Vector3(1.25, 0.04, 0), Vector3(0.08, 0.02, 3.2), Color("f2f2ee"), 0.0, false)
	var cols := [Color("e63946"), Color("457b9d"), Color("f4a261"), Color("2a9d8f"), Color("f8f9fa"), Color("1b1b1e"), Color("e9c46a")]
	var nb := mini(n * 4, slots.size())
	for i in nb:
		var p: Vector3 = slots[(i * 5) % slots.size()]
		var col: Color = cols[i % cols.size()]
		k.box(p + Vector3(0, 0.45, 0), Vector3(1.7, 0.6, 3.6), col)
		k.box(p + Vector3(0, 0.95, 0.2), Vector3(1.5, 0.45, 1.9), col.lightened(0.1))
		k.layer = "verre"
		k.box(p + Vector3(0, 0.95, 0.2), Vector3(1.52, 0.35, 1.7), Color(0.6, 0.75, 0.85, 0.7), 0.0, false)
		k.layer = "base"
	if n >= 3:
		# Guérite du voiturier.
		k.box(Vector3(porte.x + 2.4, 0.9, z0 + 0.9), Vector3(1.2, 1.8, 1.2), Color("1d3557"))
		k.box(Vector3(porte.x + 2.4, 1.85, z0 + 0.9), Vector3(1.5, 0.1, 1.5), Color("d4af37"))
	return []


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
			var g := _geste(String(e.met), String(pid))
			f.regler(g)
			if f.assise:
				f.regler("conseiller")
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
			return "cafe" if piece == "bar" else "servir"
		"cadre":
			return "reunion"
		"maitre_nageur":
			return "soigner" if piece == "spa" else "moudre"
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

## Point d'entrée de la rue et porte d'entrée.
func _rue() -> Vector3:
	var gd := GestionTypes.genre(genre)
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	var porte: Vector2 = gd.get("porte", Vector2(plan.x * 0.5, plan.y))
	return Vector3(porte.x + rng.randf_range(-0.4, 0.4), 0, plan.y + 15.0)


func _porte() -> Vector3:
	var gd := GestionTypes.genre(genre)
	var plan: Vector2 = gd.get("plan", Vector2(30, 22))
	var porte: Vector2 = gd.get("porte", Vector2(plan.x * 0.5, plan.y))
	return Vector3(porte.x, 0, porte.y)


## Place n de la file devant le comptoir (0 = au guichet).
func place_file(n: int) -> Vector3:
	var porte := _porte()
	return Vector3(porte.x, 0, 18.0 + n * 0.95)


## Chemin du hall jusqu'à la porte d'une pièce (portes « via »).
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
	return out


func ajouter_client() -> Dictionary:
	_n_client += 1
	var f := Figurine.creer(9000 + _n_client * 7, "")
	f.regler("client")
	f.position = _rue()
	_gens.add_child(f)
	var c := {"fig": f, "chemin": [_porte() + Vector3(0, 0, 1.2), _porte() + Vector3(0, 0, -0.8)], "etat": "arrive",
		"piece": "", "place": -1, "attente": 0.0, "bulle": null, "demande": {}, "id": _n_client}
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
	var chemin: Array = [place_file(0) + Vector3(0, 0, 1.0)]
	chemin.append_array(_portes_vers(pid))
	if place.avant != Vector3.INF:
		chemin.append(place.avant)
	chemin.append(Vector3(place.pos.x, 0, place.pos.z))
	c.chemin = chemin
	c.etat = "va"
	c.piece = pid
	c.place = i
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
	f.regler("client")
	var chemin: Array = []
	if String(c.piece) != "":
		var portes := _portes_vers(String(c.piece))
		portes.reverse()
		var p := GestionTypes.piece(genre, String(c.piece))
		if not p.is_empty():
			var pl: Array = places.get(String(c.piece), [])
			for d in pl:
				if d.avant != Vector3.INF and Vector3(d.pos.x, 0, d.pos.z).distance_to(f.position) < 0.5:
					chemin.append(d.avant)
		chemin.append_array(portes)
	chemin.append(place_file(0) + Vector3(0, 0, 1.6))
	chemin.append(_porte() + Vector3(0, 0, -0.8))
	chemin.append(_porte() + Vector3(0, 0, 1.2))
	chemin.append(_rue())
	c.chemin = chemin
	c.etat = "part"
	c.piece = ""
	poser_bulle(c, null)


func poser_bulle(c: Dictionary, l: Label3D) -> void:
	if c.bulle != null and is_instance_valid(c.bulle):
		(c.bulle as Node).queue_free()
	c.bulle = l
	if l != null:
		(c.fig as Node3D).add_child(l)
		l.position = Vector3(0, 2.35, 0)


## Avance les clients (dt déjà mis à la vitesse du jeu). Renvoie les événements :
## [{type: "arrive_guichet"|"installe"|"fini"|"sorti", client}].
func avancer(dt: float) -> Array:
	_t += dt
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
			return []
		"va":
			c.etat = "installe"
			var place: Dictionary = (places.get(String(c.piece), []) as Array)[int(c.place)] if int(c.place) >= 0 and int(c.place) < (places.get(String(c.piece), []) as Array).size() else {}
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
