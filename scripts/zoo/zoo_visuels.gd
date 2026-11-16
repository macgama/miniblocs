class_name ZooVisuels
extends Node3D
## Ce qui se voit du zoo : barrières des enclos (grillage, palissade, vitres,
## murs, douves, volières), animaux qui se promènent dans leur enclos (et
## les évadés dehors), soigneurs, visiteurs le long des enclos.

const ANIM_DIST := 700.0
const MAX_VISITEURS := 240
const PEAUX := [Color("f6dccb"), Color("e5b48f"), Color("c98f67"), Color("a06743"), Color("75472d"), Color("4d2e1e")]
const BOIS := Color("7a5032")
const BOIS_C := Color("a87a4e")
const METAL := Color("5a6066")
const METAL_C := Color("9aa0a6")
const BETON := Color("b5b0a5")
const VERT_SOIGNEUR := Color("3f6a3a")

var zoo: ZooSysteme
## Enclos → [MeshInstance3D opaque, MeshInstance3D transparent].
var _barrieres: Dictionary = {}
var _sig: Dictionary = {}
## Animal → {node, p (Vector2), cible, pause, ang, vit}.
var _betes: Dictionary = {}
var _soigneurs: Array = []
var _corps: MultiMeshInstance3D
var _tetes: MultiMeshInstance3D
var _t := 0.0
var _rebuild_t := 0.0
var rng := RandomNumberGenerator.new()
static var _mat_opaque: StandardMaterial3D
static var _mat_verre: StandardMaterial3D


func setup(z: ZooSysteme) -> void:
	zoo = z


func _ready() -> void:
	rng.seed = 99_031
	_corps = _multi("Visiteurs", ParcVisuels._corps_mesh())
	_tetes = _multi("Tetes", ParcVisuels._tete_mesh())


func _multi(nom: String, mesh: Mesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mmi.multimesh = mm
	mmi.visibility_range_end = 900.0
	add_child(mmi)
	return mmi


static func mat_opaque() -> StandardMaterial3D:
	if _mat_opaque == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.85
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_opaque = m
	return _mat_opaque


## Grillages, filets et vitres : à demi transparents.
static func mat_verre() -> StandardMaterial3D:
	if _mat_verre == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.2
		m.metallic_specular = 0.8
		_mat_verre = m
	return _mat_verre


func _process(delta: float) -> void:
	if zoo == null:
		return
	var vitesse := EchelleTemps.facteur()
	_t += delta * vitesse
	_rebuild_t -= delta
	if _rebuild_t <= 0.0:
		_rebuild_t = 0.5
		_sync_barrieres()
		_sync_betes()
		_sync_soigneurs()
	# Bêtes et soigneurs suivent la vitesse du temps (EchelleTemps), arrêt en pause.
	_animer(delta * vitesse, 1.0)
	_animer_soigneurs(delta * vitesse, 1.0)
	_visiteurs()


# --- Hauteurs -------------------------------------------------------------------------------------

func sol(x: float, z: float) -> float:
	var w := zoo.world
	if w == null:
		return 0.0
	var c := Vector2i(floori(x), floori(z))
	if w.water_cells.has(c):
		return float(w.water_cells[c])
	var h := w.cell_height(c)
	return 0.0 if is_nan(h) else h


# --- Barrières ----------------------------------------------------------------------------------------

func _sync_barrieres() -> void:
	for id in _barrieres.keys():
		if not zoo.enclos.has(id):
			for mi in _barrieres[id]:
				(mi as Node).queue_free()
			_barrieres.erase(id)
			_sig.erase(id)
	for id in zoo.enclos:
		var en: Dictionary = zoo.enclos[id]
		var sig := "%s|%s|%d" % [str(en.pts), String(en.barriere), int(float(en.etat) / 34.0)]
		if _sig.get(id, "") == sig:
			continue
		_sig[id] = sig
		var meshes := construire_barriere(en.pts, String(en.barriere), float(en.etat))
		if not _barrieres.has(id):
			var a := MeshInstance3D.new()
			var b := MeshInstance3D.new()
			a.name = "Barriere%d" % id
			b.name = "Verre%d" % id
			for mi in [a, b]:
				mi.visibility_range_end = 1200.0
				add_child(mi)
			_barrieres[id] = [a, b]
		(_barrieres[id][0] as MeshInstance3D).mesh = meshes[0]
		(_barrieres[id][1] as MeshInstance3D).mesh = meshes[1]
		(_barrieres[id][1] as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Maillages [opaque, transparent] de la barrière d'un enclos.
func construire_barriere(pts: PackedVector2Array, type: String, etat: float) -> Array:
	var k := BlocMesh.new()
	var v := BlocMesh.new()
	var spec := ZooEspeces.barriere(type)
	var h := float(spec.h)
	var use := etat < 40.0
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var l := a.distance_to(b)
		if l < 0.05:
			continue
		var dir := (b - a) / l
		var pas := 3.0 if type != "palissade" else 0.32
		var nb := maxi(1, ceili(l / pas))
		for j in nb:
			var t0 := float(j) / nb
			var t1 := float(j + 1) / nb
			var p0 := a.lerp(b, t0)
			var p1 := a.lerp(b, t1)
			var y0 := sol(p0.x, p0.y)
			var y1 := sol(p1.x, p1.y)
			var q0 := Vector3(p0.x, y0, p0.y)
			var q1 := Vector3(p1.x, y1, p1.y)
			# Une barrière usée penche un peu par endroits.
			var penche := 0.0
			if use and (i * 31 + j * 7) % 5 == 0:
				penche = 0.25
			match type:
				"barriere_bois":
					_poteau(k, q0, 0.14, h, BOIS)
					for hh in [0.45, 1.0]:
						ParcTypes.beam(k, q0 + Vector3(0, hh, 0), q1 + Vector3(0, hh - penche * 0.5, 0), 0.08, BOIS_C)
				"electrique":
					_poteau(k, q0, 0.07, h, BOIS)
					for hh in [0.4, 0.85, 1.35]:
						ParcTypes.beam(k, q0 + Vector3(0, hh, 0), q1 + Vector3(0, hh, 0), 0.015, Color("d8c040"))
				"grillage", "grillage_fort", "voliere":
					var ep := 0.08 if type == "grillage" else 0.14
					_poteau(k, q0, ep, h, METAL)
					ParcTypes.beam(k, q0 + Vector3(0, h, 0), q1 + Vector3(0, h - penche, 0), 0.05, METAL)
					ParcTypes.beam(k, q0 + Vector3(0, 0.05, 0), q1 + Vector3(0, 0.05, 0), 0.05, METAL)
					_toile(v, q0, q1, 0.0, h - penche * 0.5, Color(0.22, 0.24, 0.26, 0.45))
					if type == "grillage_fort":
						# Retour incliné vers l'intérieur.
						var inn := Vector3(-dir.y, 0, dir.x) * 0.6
						_toile(v, q0 + Vector3(0, h, 0), q1 + Vector3(0, h, 0), 0.0, 0.0, Color(0.22, 0.24, 0.26, 0.45), inn + Vector3(0, 0.4, 0))
				"palissade":
					var ph := h + (0.15 if (i + j) % 3 == 0 else 0.0) - penche
					k.cylinder(q0.x, q0.y - 0.2, q0.z, 0.16, 0.14, ph + 0.2, 6, BOIS if j % 2 == 0 else BOIS_C)
				"vitre":
					_poteau(k, q0, 0.12, h, METAL)
					ParcTypes.beam(k, q0 + Vector3(0, h, 0), q1 + Vector3(0, h, 0), 0.1, METAL)
					k.box((q0.x + q1.x) * 0.5, minf(y0, y1) - 0.1, (q0.z + q1.z) * 0.5, 0.3, 0.6, 0.3, BETON)
					_mur_bas(k, q0, q1, 0.5, 0.3, BETON)
					_toile(v, q0 + Vector3(0, 0.5, 0), q1 + Vector3(0, 0.5, 0), 0.0, h - 0.5, Color(0.6, 0.78, 0.86, 0.28))
				"mur":
					_mur_bas(k, q0, q1, h - penche * 0.3, 0.35, BETON.darkened(0.04 * (j % 2)))
				"douve":
					# Muret côté visiteurs, fossé d'eau côté animaux.
					var inn := Vector3(-dir.y, 0, dir.x)
					_mur_bas(k, q0, q1, h, 0.3, Color("c9c1ae"))
					var e0 := q0 + inn * 0.3
					var e1 := q1 + inn * 0.3
					var f0 := q0 + inn * 2.8
					var f1 := q1 + inn * 2.8
					k.panel(e0 + Vector3(0, 0.04, 0), e1 + Vector3(0, 0.04, 0), f1 + Vector3(0, 0.04, 0), f0 + Vector3(0, 0.04, 0),
						Vector3.UP, Color("3e6a7a"))
				_:
					_poteau(k, q0, 0.1, h, METAL)
	if type == "voliere":
		# Filet de toit.
		var tri := Geometry2D.triangulate_polygon(pts)
		var hy := 0.0
		for p in pts:
			hy = maxf(hy, sol(p.x, p.y))
		hy += h
		for i in range(0, tri.size(), 3):
			var a := pts[tri[i]]
			var b := pts[tri[i + 1]]
			var c := pts[tri[i + 2]]
			v.tri(Vector3(a.x, hy, a.y), Vector3(b.x, hy, b.y), Vector3(c.x, hy, c.y), Vector3.UP, Color(0.22, 0.24, 0.26, 0.3))
	var m0: Mesh = k.to_mesh(mat_opaque()) if not k.verts.is_empty() else null
	var m1: Mesh = v.to_mesh(mat_verre()) if not v.verts.is_empty() else null
	return [m0, m1]


func _poteau(k: BlocMesh, q: Vector3, ep: float, h: float, col: Color) -> void:
	k.box(q.x, q.y - 0.3, q.z, ep, h + 0.3, ep, col)


func _mur_bas(k: BlocMesh, q0: Vector3, q1: Vector3, h: float, ep: float, col: Color) -> void:
	var d := q1 - q0
	d.y = 0.0
	if d.length() < 0.01:
		return
	var s := Vector3(-d.z, 0, d.x).normalized() * (ep / 2.0)
	var b0 := q0 + Vector3(0, -0.4, 0)
	var b1 := q1 + Vector3(0, -0.4, 0)
	var t0 := q0 + Vector3(0, h, 0)
	var t1 := q1 + Vector3(0, h, 0)
	k.panel(b0 + s, b1 + s, t1 + s, t0 + s, s, col)
	k.panel(b0 - s, b1 - s, t1 - s, t0 - s, -s, col)
	k.panel(t0 + s, t1 + s, t1 - s, t0 - s, Vector3.UP, col.lightened(0.06))


## Pan vertical (ou incliné par `vers`) entre q0 et q1, de y0 à y0 + h.
func _toile(v: BlocMesh, q0: Vector3, q1: Vector3, y0: float, h: float, col: Color, vers := Vector3.ZERO) -> void:
	var up := Vector3(0, h, 0) if vers == Vector3.ZERO else vers
	var a := q0 + Vector3(0, y0, 0)
	var b := q1 + Vector3(0, y0, 0)
	var d := b - a
	var n := Vector3(-d.z, 0, d.x).normalized()
	v.quad(a, b, b + up, a + up, n, col)


# --- Animaux ----------------------------------------------------------------------------------------

func _sync_betes() -> void:
	for aid in _betes.keys():
		if not zoo.animaux.has(aid):
			(_betes[aid].node as Node).queue_free()
			_betes.erase(aid)
	for aid in zoo.animaux:
		var a: Dictionary = zoo.animaux[aid]
		var age := zoo.age_ans(a)
		var esp := String(a.esp)
		var e := ZooEspeces.espece(esp)
		var petit := age < float(e.get("maturite", 1))
		var did := ZooEspeces.modele(esp, bool(a.f), petit)
		if not _betes.has(aid):
			var mi := MeshInstance3D.new()
			mi.name = "Animal%d" % aid
			mi.material_override = Decors.materiau()
			mi.visibility_range_end = ANIM_DIST
			add_child(mi)
			var p := Vector2(float(a.pos[0]), float(a.pos[1]))
			_betes[aid] = {"node": mi, "p": p, "cible": p, "pause": rng.randf_range(0.0, 6.0), "ang": rng.randf() * TAU,
				"vit": 0.5 + 0.12 * float(e.get("taille", 2)), "did": ""}
		var b: Dictionary = _betes[aid]
		if String(b.did) != did:
			b.did = did
			(b.node as MeshInstance3D).mesh = Decors.mesh(did)
		b.echelle = ZooEspeces.echelle(esp, age)


func _animer(delta: float, vitesse: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	for aid in _betes:
		if not zoo.animaux.has(aid):
			continue
		var a: Dictionary = zoo.animaux[aid]
		var b: Dictionary = _betes[aid]
		var mi: MeshInstance3D = b.node
		var p: Vector2 = b.p
		if cam and Vector2(cp.x, cp.z).distance_to(p) > ANIM_DIST:
			mi.visible = false
			continue
		mi.visible = true
		var id := int(a.enclos)
		var dehors := bool(a.evade)
		if float(b.pause) > 0.0:
			b.pause = float(b.pause) - delta * maxf(vitesse, 0.2)
		else:
			var c: Vector2 = b.cible
			var d := c - p
			var pas := float(b.vit) * delta * maxf(vitesse, 0.3) * (2.2 if dehors else 1.0)
			if d.length() <= pas:
				b.p = c
				b.pause = rng.randf_range(3.0, 18.0) if not dehors else rng.randf_range(0.5, 3.0)
				b.cible = _nouvelle_cible(id, c, dehors)
			else:
				b.p = p + d.normalized() * pas
				b.ang = lerp_angle(float(b.ang), atan2(d.x, d.y), clampf(delta * 4.0, 0.0, 1.0))
		p = b.p
		a.pos = [p.x, p.y]
		var y := sol(p.x, p.y)
		if zoo.world != null and zoo.world.water_cells.has(Vector2i(floori(p.x), floori(p.y))):
			y -= 0.5 if String(a.esp) in ["hippopotame", "crocodile", "ours_polaire", "otarie", "tapir", "manchot"] else 0.0
		var marche := float(b.pause) <= 0.0
		var hop := absf(sin(_t * 6.0 + float(aid))) * 0.04 if marche else 0.0
		var s := float(b.get("echelle", 1.0))
		mi.transform = Transform3D(Basis(Vector3.UP, float(b.ang) + PI).scaled(Vector3(s, s, s)), Vector3(p.x, y + hop, p.y))


func _nouvelle_cible(id: int, depuis: Vector2, dehors: bool) -> Vector2:
	if dehors or not zoo.enclos.has(id):
		var base := zoo._centre_enclos(id) if zoo.enclos.has(id) else depuis
		var a := rng.randf() * TAU
		return base + Vector2(cos(a), sin(a)) * rng.randf_range(20.0, 70.0)
	var pts: PackedVector2Array = zoo.enclos[id].pts
	for i in 12:
		var a := rng.randf() * TAU
		var q := depuis + Vector2(cos(a), sin(a)) * rng.randf_range(3.0, 25.0)
		if Geometry2D.is_point_in_polygon(q, pts) and _loin_du_bord(q, pts, 0.8):
			return q
	return zoo._point_dans(id)


static func _loin_du_bord(q: Vector2, pts: PackedVector2Array, m: float) -> bool:
	for i in pts.size():
		var c := Geometry2D.get_closest_point_to_segment(q, pts[i], pts[(i + 1) % pts.size()])
		if c.distance_to(q) < m:
			return false
	return true


# --- Soigneurs ---------------------------------------------------------------------------------------

func _sync_soigneurs() -> void:
	var voulus := 0
	for e in zoo.zoos:
		voulus += mini(roundi(zoo.soigneurs(int(e))), 12)
	while _soigneurs.size() < voulus:
		var mi := MeshInstance3D.new()
		mi.name = "Soigneur%d" % _soigneurs.size()
		var k := BlocMesh.new()
		k.box(-0.11, 0, 0, 0.16, 0.8, 0.2, Color("4a4a3a"))
		k.box(0.11, 0, 0, 0.16, 0.8, 0.2, Color("4a4a3a"))
		k.box(0, 0.8, 0, 0.46, 0.62, 0.26, VERT_SOIGNEUR)
		k.box(-0.29, 0.86, 0, 0.12, 0.54, 0.14, VERT_SOIGNEUR)
		k.box(0.29, 0.86, 0, 0.12, 0.54, 0.14, VERT_SOIGNEUR)
		k.box(0, 1.44, 0, 0.26, 0.28, 0.26, PEAUX[_soigneurs.size() % PEAUX.size()])
		k.box(0, 1.72, 0, 0.3, 0.08, 0.3, Color("c8b86a"))
		# Brouette.
		k.box(0, 0.35, -0.75, 0.6, 0.35, 0.8, Color("3f7a9a"))
		mi.mesh = k.to_mesh(mat_opaque())
		mi.visibility_range_end = ANIM_DIST
		add_child(mi)
		_soigneurs.append({"node": mi, "p": Vector2.ZERO, "cible": Vector2.ZERO, "pause": 0.0, "ok": false})
	while _soigneurs.size() > voulus:
		(_soigneurs.pop_back().node as Node).queue_free()


func _cible_soigneur() -> Vector2:
	if zoo.enclos.is_empty():
		return Vector2.ZERO
	var ids := zoo.enclos.keys()
	var id := int(ids[rng.randi() % ids.size()])
	var pts: PackedVector2Array = zoo.enclos[id].pts
	var c := ZooSysteme._centroide(pts)
	var i := rng.randi() % pts.size()
	var m := pts[i].lerp(pts[(i + 1) % pts.size()], rng.randf())
	return m + (m - c).normalized() * 2.0


# --- Visiteurs ------------------------------------------------------------------------------------------

## Parcours d'un zoo : portail → devant chaque enclos → portail.
func parcours(e: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not zoo.zoos.has(e) or zoo.buildings == null or not zoo.buildings.buildings.has(e):
		return out
	var por := zoo.portail(e)
	out.append(Vector2(por.x, por.z))
	var encl := zoo.enclos_du_zoo(e)
	var pts: Array = []
	for id in encl:
		var poly: PackedVector2Array = zoo.enclos[id].pts
		var c := ZooSysteme._centroide(poly)
		# Point du bord le plus proche de l'entrée, un peu en dehors.
		var best := poly[0]
		var bd := INF
		for i in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(Vector2(por.x, por.z), poly[i], poly[(i + 1) % poly.size()])
			var d := q.distance_to(Vector2(por.x, por.z))
			if d < bd:
				bd = d
				best = q
		pts.append(best + (best - c).normalized() * 3.5)
	# Tour dans le sens des aiguilles d'une montre autour du centre.
	var centre := Vector2(por.x, por.z)
	for q in pts:
		centre += q
	centre /= float(pts.size() + 1)
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - centre).angle() < (b - centre).angle())
	for q in pts:
		out.append(q)
	out.append(Vector2(por.x, por.z))
	return out


var _parcours_cache: Dictionary = {}
var _parcours_t := 0.0


func _visiteurs() -> void:
	var corps := _corps.multimesh
	var tetes := _tetes.multimesh
	_parcours_t -= 1.0
	if _parcours_t <= 0.0:
		_parcours_t = 120.0
		_parcours_cache.clear()
	var list: Array = []
	for e in zoo.zoos:
		var n := mini(roundi(float(zoo.zoos[e].presents) * 0.5), MAX_VISITEURS)
		if n <= 0:
			continue
		if not _parcours_cache.has(e):
			var pc := parcours(int(e))
			var longs := PackedFloat32Array([0.0])
			for i in range(1, pc.size()):
				longs.append(longs[i - 1] + pc[i - 1].distance_to(pc[i]))
			_parcours_cache[e] = [pc, longs]
		var pc: PackedVector2Array = _parcours_cache[e][0]
		var longs: PackedFloat32Array = _parcours_cache[e][1]
		if pc.size() < 2 or longs[longs.size() - 1] < 1.0:
			continue
		for i in n:
			list.append([pc, longs, i])
	var total := list.size()
	if corps.instance_count != total:
		corps.instance_count = total
		tetes.instance_count = total
	for j in total:
		var pc: PackedVector2Array = list[j][0]
		var longs: PackedFloat32Array = list[j][1]
		var i: int = list[j][2]
		var L := longs[longs.size() - 1]
		# Chacun avance à son rythme, avec des arrêts devant les enclos.
		var s := fposmod(float(i) * 37.7 + _t * (0.9 + float(i % 5) * 0.08), L + 40.0)
		s = minf(s, L)
		var k := 1
		while k < longs.size() - 1 and longs[k] < s:
			k += 1
		var seg := maxf(longs[k] - longs[k - 1], 0.001)
		var f := clampf((s - longs[k - 1]) / seg, 0.0, 1.0)
		var a := pc[k - 1]
		var b := pc[k]
		var p := a.lerp(b, f)
		var dir := (b - a).normalized()
		var cote := Vector2(-dir.y, dir.x) * (float(i % 7) - 3.0) * 0.6
		p += cote
		var y := sol(p.x, p.y) + absf(sin(_t * 7.0 + float(i))) * 0.05
		var basis := Basis(Vector3.UP, atan2(-dir.x, -dir.y))
		var sc := 0.62 if i % 5 == 0 else 1.0
		var tr := Transform3D(basis.scaled(Vector3(sc, sc, sc)), Vector3(p.x, y, p.y))
		corps.set_instance_transform(j, tr)
		corps.set_instance_color(j, Color(String(Silhouettes.HAUTS[(i * 7) % Silhouettes.HAUTS.size()])))
		tetes.set_instance_transform(j, tr)
		tetes.set_instance_color(j, PEAUX[(i / 3) % PEAUX.size()])


func _animer_soigneurs(delta: float, vitesse: float) -> void:
	for s in _soigneurs:
		var mi: MeshInstance3D = s.node
		if not bool(s.ok):
			s.p = _cible_soigneur()
			s.cible = _cible_soigneur()
			s.ok = true
		if float(s.pause) > 0.0:
			s.pause = float(s.pause) - delta * maxf(vitesse, 0.2)
		else:
			var d: Vector2 = s.cible - s.p
			var pas := 1.3 * delta * maxf(vitesse, 0.3)
			if d.length() <= pas:
				s.p = s.cible
				s.pause = rng.randf_range(4.0, 14.0)
				s.cible = _cible_soigneur()
			else:
				s.p = (s.p as Vector2) + d.normalized() * pas
				s.ang = atan2(d.x, d.y)
		var p: Vector2 = s.p
		mi.transform = Transform3D(Basis(Vector3.UP, float(s.get("ang", 0.0)) + PI), Vector3(p.x, sol(p.x, p.y), p.y))
