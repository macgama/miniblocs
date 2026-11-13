class_name ParcVisuels
extends Node3D
## Ce qui se voit du parc de loisirs : manèges qui tournent (ParcTypes.build_anim),
## clôture autour du parc, allées depuis l'entrée, visiteurs qui marchent et
## font la queue (petits personnages en MultiMesh, un par visiteur suivi, et
## jusqu'à trois quand il en représente plusieurs).

const LARGEUR_ALLEE := 3.6
const MARGE := 5.0
const ANIM_DIST := 1100.0
const PEAUX := [Color("f6dccb"), Color("e5b48f"), Color("c98f67"), Color("a06743"), Color("75472d"), Color("4d2e1e")]

var parc: ParcLoisirs
var _anims: Dictionary = {}  # bid -> Node3D
var _marche: Dictionary = {}  # bid -> 0..1 (lissé)
var _decor: Dictionary = {}  # entrée -> MeshInstance3D (clôture + allées)
var _sig: Dictionary = {}  # entrée -> signature des objets
var _corps: MultiMeshInstance3D
var _tetes: MultiMeshInstance3D
var _t := 0.0
var _rebuild_t := 0.0


func setup(p: ParcLoisirs) -> void:
	parc = p


func _ready() -> void:
	_corps = _multi("Visiteurs", _corps_mesh(), true)
	_tetes = _multi("Tetes", _tete_mesh(), true)


static func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.8
	return m


func _multi(nom: String, mesh: Mesh, colors: bool) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mmi.multimesh = mm
	mmi.visibility_range_end = 900.0
	add_child(mmi)
	return mmi


static func _corps_mesh() -> Mesh:
	var k := BlocMesh.new()
	k.box(-0.11, 0, 0, 0.16, 0.8, 0.2, Color("3b3f4a"))
	k.box(0.11, 0, 0, 0.16, 0.8, 0.2, Color("3b3f4a"))
	k.box(0, 0.8, 0, 0.46, 0.62, 0.26, Color.WHITE)
	k.box(-0.29, 0.86, 0, 0.12, 0.54, 0.14, Color.WHITE)
	k.box(0.29, 0.86, 0, 0.12, 0.54, 0.14, Color.WHITE)
	return k.to_mesh(_mat())


static func _tete_mesh() -> Mesh:
	var k := BlocMesh.new()
	k.box(0, 1.44, 0, 0.26, 0.28, 0.26, Color.WHITE)
	return k.to_mesh(_mat())


func _process(delta: float) -> void:
	if parc == null or parc.buildings == null:
		return
	_t += delta
	_rebuild_t -= delta
	if _rebuild_t <= 0.0:
		_rebuild_t = 1.0
		_sync_anims()
		_sync_decor()
	_animer(delta)
	_visiteurs()


# --- Manèges ------------------------------------------------------------------------------------------

func _sync_anims() -> void:
	var bs := parc.buildings
	for bid in _anims.keys():
		var n: Node3D = _anims[bid]
		var host := bs.node_of(int(bid)) if bs.buildings.has(bid) else null
		if not parc.items.has(bid) or host == null or not is_instance_valid(n) or n.get_parent() != host or bs.en_chantier(int(bid)):
			if is_instance_valid(n):
				n.queue_free()
			_anims.erase(bid)
	for bid in parc.items:
		if _anims.has(bid) or bs.en_chantier(int(bid)):
			continue
		var host := bs.node_of(int(bid))
		if host == null:
			continue
		var n := ParcTypes.build_anim(parc._type_of(int(bid)))
		if n == null:
			_anims[bid] = Node3D.new()
			host.add_child(_anims[bid])
			continue
		host.add_child(n)
		_anims[bid] = n
		ParcTypes.animate(n, parc._type_of(int(bid)), 0.0, 0.0, 0.0, float(bid) * 1.7)


func _animer(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for bid in _anims:
		var n: Node3D = _anims[bid]
		if not is_instance_valid(n) or n.get_child_count() == 0 or not parc.items.has(bid):
			continue
		var it: Dictionary = parc.items[bid]
		var e := int(it.parc)
		var ouvert := e >= 0 and parc.parcs.has(e) and bool(parc.parcs[e].ouvert)
		var cible := 0.0
		if ouvert and not bool(it.panne):
			if String(it.role) == "attraction":
				cible = 1.0 if (float(it.fin) > 0.0 or not (it.file as Array).is_empty()) else 0.0
			else:
				cible = 1.0
		var m := move_toward(float(_marche.get(bid, 0.0)), cible, delta * 0.5)
		_marche[bid] = m
		if cam != null and cam.global_position.distance_to(n.global_position) > ANIM_DIST:
			continue
		ParcTypes.animate(n, parc._type_of(int(bid)), _t, delta, m, float(bid) * 1.7)


# --- Clôture et allées -------------------------------------------------------------------------------------

func _sync_decor() -> void:
	for e in _decor.keys():
		if not parc.parcs.has(e):
			(_decor[e] as Node).queue_free()
			_decor.erase(e)
			_sig.erase(e)
	for e in parc.parcs:
		var sig := _signature(int(e))
		if _sig.get(e, "") == sig:
			continue
		_sig[e] = sig
		if _decor.has(e):
			(_decor[e] as Node).queue_free()
		var mi := MeshInstance3D.new()
		mi.name = "Parc_%d" % int(e)
		mi.mesh = build_decor(int(e))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 1400.0
		add_child(mi)
		_decor[e] = mi


func _signature(e: int) -> String:
	var parts: Array = []
	for bid in parc.parcs[e].items:
		var b: Dictionary = parc.buildings.buildings.get(bid, {})
		parts.append("%d:%d:%d:%d:%s" % [int(bid), int(b.get("x", 0)), int(b.get("z", 0)), int(b.get("r", 0)), str(parc.en_chantier(int(bid)))])
	parts.sort()
	return ",".join(parts)


func _sol(x: float, z: float, def: float) -> float:
	var w := parc.buildings.world
	if w == null:
		return def
	var h := w.raw_height(x, z)
	return def if is_nan(h) else h


## Clôture (enveloppe des objets du parc, écartée de MARGE) et allées.
func build_decor(e: int) -> ArrayMesh:
	var k := BlocMesh.new()
	var bs := parc.buildings
	var h0 := parc._center(e).y
	var pts := PackedVector2Array()
	var rects: Array = []
	for bid in parc.parcs[e].items:
		if not bs.buildings.has(bid):
			continue
		var r: Rect2i = bs._rect_of(bs.buildings[bid])
		rects.append([int(bid), Rect2(r.position, r.size)])
		for c in [r.position, Vector2i(r.end.x, r.position.y), r.end, Vector2i(r.position.x, r.end.y)]:
			pts.append(Vector2(c))
	if pts.size() >= 3:
		var hull := Geometry2D.convex_hull(pts)
		var off := Geometry2D.offset_polygon(hull, MARGE, Geometry2D.JOIN_ROUND)
		if not off.is_empty():
			var poly: PackedVector2Array = off[0]
			_pelouse(poly)
			var er: Rect2 = Rect2(bs._rect_of(bs.buildings[e])).grow(MARGE + 1.0)
			for i in poly.size():
				var a := poly[i]
				var b := poly[(i + 1) % poly.size()]
				var n := maxi(1, int(a.distance_to(b) / 2.5))
				for j in n:
					var p0 := a.lerp(b, float(j) / n)
					var p1 := a.lerp(b, float(j + 1) / n)
					var mid := (p0 + p1) / 2.0
					if er.has_point(mid) or _dans_batiment(mid, e):
						continue
					var y0 := _sol(p0.x, p0.y, h0)
					var y1 := _sol(p1.x, p1.y, h0)
					k.box(p0.x, y0, p0.y, 0.12, 1.5, 0.12, Color("2d6a4f"))
					ParcTypes.beam(k, Vector3(p0.x, y0 + 1.4, p0.y), Vector3(p1.x, y1 + 1.4, p1.y), 0.07, Color("2d6a4f"))
					ParcTypes.beam(k, Vector3(p0.x, y0 + 0.75, p0.y), Vector3(p1.x, y1 + 0.75, p1.y), 0.05, Color("40916c"))
					ParcTypes.beam(k, Vector3(p0.x, y0 + 0.15, p0.y), Vector3(p1.x, y1 + 0.15, p1.y), 0.05, Color("40916c"))
	# Allées : du portail à la place centrale, puis vers chaque objet.
	var hub := parc.centre(e)
	_allee(k, parc.portail(e), hub, h0)
	_place(k, hub, h0)
	for bid in parc.parcs[e].items:
		if int(bid) == e or not bs.buildings.has(bid):
			continue
		var door := parc.porte(int(bid))
		var to := door + parc.facade(int(bid)) * 2.0
		_allee(k, hub, to, h0)
		_allee(k, to, door, h0, 2.4)
	return k.to_mesh(NightWindows.building_material())


## L'enceinte du parc devient une pelouse (plus de champs ni de vignes entre les manèges).
func _pelouse(poly: PackedVector2Array) -> void:
	var w := parc.buildings.world
	if w == null or not ("biome_paint" in w) or not ("tree_paint" in w):
		return
	var r := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		r = r.expand(q)
	var n := 0
	for x in range(floori(r.position.x), ceili(r.end.x)):
		for z in range(floori(r.position.y), ceili(r.end.y)):
			var c := Vector2i(x, z)
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, z + 0.5), poly):
				continue
			# Pas d'arbres sauvages entre les manèges (arrachés comme avec l'outil Paysage).
			if not w.tree_paint.has(c):
				w.tree_paint[c] = 0.0
				n += 1
			if w.biome_paint.has(c):
				continue
			var k := w.cell_biome(c)
			if k in [TerrainWorld.Kind.MER, TerrainWorld.Kind.LAC, TerrainWorld.Kind.RIVIERE, TerrainWorld.Kind.RUISSEAU,
				TerrainWorld.Kind.ETANG, TerrainWorld.Kind.CANAL, TerrainWorld.Kind.PRAIRIE]:
				continue
			w.biome_paint[c] = float(TerrainWorld.Kind.PRAIRIE)
			n += 1
	if n > 0:
		for x in range(floori(r.position.x), ceili(r.end.x) + 16, 16):
			for z in range(floori(r.position.y), ceili(r.end.y) + 16, 16):
				w._mark_dirty_around(Vector2i(x, z))


func _dans_batiment(p: Vector2, e: int) -> bool:
	var bs := parc.buildings
	var c := Vector2i(floori(p.x), floori(p.y))
	if not bs.occupancy.has(c):
		return false
	return not (parc.parcs[e].items as Array).has(int(bs.occupancy[c]))


const PAVE := Color("d9c9a8")


func _allee(k: BlocMesh, a: Vector3, b: Vector3, h0: float, larg := LARGEUR_ALLEE) -> void:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var long := d.length()
	if long < 0.5:
		return
	var side := Vector2(-d.y, d.x).normalized() * (larg / 2.0)
	var n := maxi(1, int(long / 3.0))
	for i in n:
		var p0 := Vector2(a.x, a.z).lerp(Vector2(b.x, b.z), float(i) / n)
		var p1 := Vector2(a.x, a.z).lerp(Vector2(b.x, b.z), float(i + 1) / n)
		var y0 := maxf(_sol(p0.x, p0.y, h0), _sol(p0.x + side.x, p0.y + side.y, h0)) + 0.07
		var y1 := maxf(_sol(p1.x, p1.y, h0), _sol(p1.x + side.x, p1.y + side.y, h0)) + 0.07
		k.quad(Vector3(p0.x - side.x, y0, p0.y - side.y), Vector3(p0.x + side.x, y0, p0.y + side.y),
			Vector3(p1.x + side.x, y1, p1.y + side.y), Vector3(p1.x - side.x, y1, p1.y - side.y), Vector3.UP, PAVE if i % 2 == 0 else PAVE.darkened(0.04))


func _place(k: BlocMesh, c: Vector3, h0: float) -> void:
	var y := _sol(c.x, c.z, h0) + 0.08
	var n := 16
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		k.tri(Vector3(c.x, y, c.z), Vector3(c.x + cos(a0) * 9.0, y, c.z + sin(a0) * 9.0), Vector3(c.x + cos(a1) * 9.0, y, c.z + sin(a1) * 9.0),
			Vector3.UP, PAVE if i % 2 == 0 else Color("e9c46a").lerp(PAVE, 0.5))
	# Fontaine au milieu.
	k.cylinder(c.x, y, c.z, 2.4, 2.4, 0.6, 12, Color("adb5bd"))
	k.cylinder(c.x, y + 0.6, c.z, 2.1, 2.1, 0.02, 12, Color("4cc9f0"))
	k.cylinder(c.x, y, c.z, 0.35, 0.25, 1.8, 8, Color("adb5bd"))


# --- Visiteurs ----------------------------------------------------------------------------------------------

func _visiteurs() -> void:
	var corps := _corps.multimesh
	var tetes := _tetes.multimesh
	var now := parc.ambiance.unix_time if parc.ambiance != null else parc.clock
	var list: Array = []
	for a in parc.agents.values():
		var etat := String(a.etat)
		if etat == "bord":
			continue
		var n := mini(int(a.w), 3)
		for i in n:
			list.append([a, i])
	var total := list.size()
	if corps.instance_count != total:
		corps.instance_count = total
		tetes.instance_count = total
	for j in total:
		var a: Dictionary = list[j][0]
		var i: int = list[j][1]
		var pos := parc.position_of(a, now)
		var dir := Vector3.FORWARD
		var etat := String(a.etat)
		if etat == "marche" or etat == "sortie":
			var p2 := parc.position_of(a, now + 2.0)
			if p2.distance_to(pos) > 0.01:
				dir = (p2 - pos).normalized()
			pos.y += absf(sin(_t * 7.0 + float(a.id))) * 0.06
		elif etat == "file" and parc.items.has(int(a.cible)):
			dir = -parc.facade(int(a.cible))
		var side := dir.cross(Vector3.UP)
		pos += side * (float(i) * 0.7) - dir * (float(i) * 0.35)
		var basis := Basis(Vector3.UP, atan2(-dir.x, -dir.z))
		var col := int(a.col)
		var s := 0.62 if (col + i) % 5 == 0 else 1.0
		var tr := Transform3D(basis.scaled(Vector3(s, s, s)), pos)
		corps.set_instance_transform(j, tr)
		corps.set_instance_color(j, Color(String(Silhouettes.HAUTS[(col + i * 7) % Silhouettes.HAUTS.size()])))
		tetes.set_instance_transform(j, tr)
		tetes.set_instance_color(j, PEAUX[(col / 3 + i) % PEAUX.size()])
