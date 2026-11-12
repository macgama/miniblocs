class_name Occupants
extends Node3D
## Les habitants dans les bâtiments en murs fins, à leurs heures.
##
## Pour chaque bâtiment proche de la caméra, on demande aux habitants
## (Population.present_in) qui s'y trouve en ce moment et pour quoi faire, puis
## chacun prend une place des meubles : il dort dans un lit la nuit, s'assoit
## au séjour ou à table, travaille à son poste, fait classe au tableau, tient
## la caisse, suit le cours à son pupitre, regarde les rayons… Les silhouettes
## sont low-poly, en trois poses (debout, assis, couché).

const RADIUS := 90.0
const MAX_FIGURES := 300
const REFRESH := 1.0

## Places voulues selon l'activité.
const WANTS := {
	"dort": ["lit", "bebe", "assis_sol", "assis"],
	"bebe": ["bebe", "lit", "assis"],
	"maison": ["assis", "assis_sol", "cuisine", "poste"],
	"garde": ["assis", "assis_sol"],
	"ecole": ["pupitre", "assis"],
	"enseigne": ["tableau", "poste"],
	"travail": ["poste", "comptoir", "tableau", "cuisine", "client"],
	"courses": ["client", "assis"],
	"loisir": ["assis", "client", "assis_sol"],
}
const SKINS := ["f1c8a6", "e0a984", "c68a5e", "9a6440", "6b4428"]
const SHIRTS := ["3a86c8", "e76f51", "2a9d8f", "e9c46a", "8d5a97", "6b8f3a", "d64545", "4a4e69"]
const HAIRS := ["2b1d16", "5a3a22", "a87b4f", "1a1a1a", "c9b28a"]

var mob: Mobilier
var population: Population
var camera: Camera3D

var _pool: Array[MeshInstance3D] = []
var _meshes: Dictionary = {}
var _timer := 0.0
## Ce qui est affiché : [{pid, plan, e, pose, pos}] (tests, vitrine).
var shown: Array = []


func setup(m: Mobilier, pop: Population, cam: Camera3D) -> void:
	mob = m
	population = pop
	camera = cam


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		_sync_visibility()
		return
	_timer = REFRESH
	refresh()


## Recalcule qui est où (appelé chaque seconde).
func refresh() -> void:
	shown.clear()
	if mob == null or population == null or mob.pe == null:
		_hide_from(0)
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		cam = camera
	var cam_pos := cam.global_position if cam != null else Vector3.ZERO
	var used := 0
	for id in mob.pe.plans:
		if used >= MAX_FIGURES:
			break
		var bbox: Rect2i = mob.pe._bbox.get(id, Rect2i())
		if bbox.size == Vector2i.ZERO:
			continue
		var center := BuildingSystem.rect_center(bbox)
		if cam != null and Vector2(center.x, center.z).distance_to(Vector2(cam_pos.x, cam_pos.z)) > RADIUS + bbox.size.length() * 0.5:
			continue
		var bid := mob.bid_of(id)
		if not population.known.has(bid):
			continue
		var present := population.present_in(bid)
		if present.is_empty():
			continue
		present.sort()
		var spots := _spots(id)
		var taken := {}
		for pid in present:
			if used >= MAX_FIGURES:
				break
			var p: Dictionary = population.persons[pid]
			var a := population.activity(p)
			var kind := String(a.kind)
			if kind == "ecole" or kind == "travail":
				if int(p.job) == bid and kind == "travail" and Metiers.job(String(p.met)).j == "ecole":
					kind = "enseigne"
			if population.stage(p) == "bebe" and kind != "garde":
				kind = "bebe" if kind == "dort" else "garde"
			var spot := _take_spot(spots, taken, WANTS.get(kind, ["assis"]), int(pid))
			if spot.is_empty():
				spot = _free_cell(id, int(pid), taken)
			if spot.is_empty():
				continue
			var child := population.age_of(p) < 12.0
			_show(used, spot, int(pid), child, id)
			shown.append({"pid": pid, "plan": id, "e": int(spot.e), "pose": String(spot.pose), "pos": spot.pos, "kind": String(spot.kind), "activity": kind})
			used += 1
	_hide_from(used)
	_sync_visibility()


## Places de tous les meubles du bâtiment : [{kind, pos, yaw, e, pose}].
func _spots(id: String) -> Array:
	var out := []
	for key in mob.items.get(id, {}):
		var k: Vector4i = key
		var it: Dictionary = mob.items[id][k]
		var ent := Meubles.get_entry(String(it.m))
		if ent.is_empty() or (ent.places as Array).is_empty():
			continue
		var xf := Mobilier.placement(ent, Vector2i(k.x, k.z), int(it.r), mob.pe.base_y(id, k.y))
		for pl in ent.places:
			var kind := String(pl[0])
			var pos := xf * Vector3(float(pl[1]), float(pl[2]), float(pl[3]))
			var yaw := int(it.r) * PI * 0.5 + float(pl[4])
			var pose := "debout"
			if kind in ["lit", "bebe"]:
				pose = "couche"
			elif kind in ["assis", "pupitre", "poste", "assis_sol"]:
				pose = "assis"
			out.append({"kind": kind, "pos": pos, "yaw": yaw, "e": k.y, "pose": pose})
	return out


static func _take_spot(spots: Array, taken: Dictionary, wants: Array, pid: int) -> Dictionary:
	if spots.is_empty():
		return {}
	var n := spots.size()
	var start := absi(hash(pid)) % n
	for w in wants:
		for i in n:
			var j := (start + i) % n
			if taken.has(j):
				continue
			var s: Dictionary = spots[j]
			if String(s.kind) == String(w):
				taken[j] = true
				return s
	return {}


## Sans place libre : debout sur une case libre du bâtiment.
func _free_cell(id: String, pid: int, taken: Dictionary) -> Dictionary:
	var p: Dictionary = mob.pe.plans[id]
	var cells := []
	for k in p.floors:
		var kf: Vector3i = k
		if mob.item_at(id, kf.y, Vector2i(kf.x, kf.z), 1) == null and not taken.has(kf):
			cells.append(kf)
	if cells.is_empty():
		return {}
	cells.sort()
	var kc: Vector3i = cells[absi(hash(pid * 7919)) % cells.size()]
	if mob.blocked_cells(id, kc.y).has(Vector2i(kc.x, kc.z)):
		kc = cells[0]
	taken[kc] = true
	return {"kind": "debout", "pos": Vector3(kc.x + 0.5, mob.pe.base_y(id, kc.y), kc.z + 0.5), "yaw": float(absi(hash(pid)) % 628) / 100.0, "e": kc.y, "pose": "debout"}


func _show(i: int, spot: Dictionary, pid: int, child: bool, id: String) -> void:
	while _pool.size() <= i:
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_pool.append(mi)
	var mi2 := _pool[i]
	mi2.mesh = figure_mesh(String(spot.pose), pid)
	var s := 0.72 if child else 1.0
	mi2.transform = Transform3D(Basis(Vector3.UP, float(spot.yaw)).scaled(Vector3(s, s, s)), spot.pos)
	mi2.set_meta("plan", id)
	mi2.set_meta("e", int(spot.e))
	mi2.visible = true


func _hide_from(n: int) -> void:
	for i in range(n, _pool.size()):
		_pool[i].visible = false
		_pool[i].set_meta("plan", "")


## Les silhouettes suivent la vue en coupe des étages.
func _sync_visibility() -> void:
	if mob == null or mob.pe == null:
		return
	for mi in _pool:
		var id := String(mi.get_meta("plan", ""))
		if id == "":
			continue
		var ref: Node3D = (mob.pe._nodes.get(id, {}) as Dictionary).get(int(mi.get_meta("e", 0)))
		mi.visible = ref == null or ref.visible


## Silhouette low-poly : debout (pieds en 0), assis (bassin sur l'assise en 0),
## couché (sur le dos, la tête vers −Z). Regarde vers +Z.
func figure_mesh(pose: String, pid: int) -> ArrayMesh:
	var key := "%s_%d_%d_%d" % [pose, pid % SHIRTS.size(), (pid / SHIRTS.size()) % SKINS.size(), (pid / 3) % HAIRS.size()]
	if _meshes.has(key):
		return _meshes[key]
	var kit := LpKit.new(pid)
	kit.jitter = 0.03
	var skin := Color(String(SKINS[(pid / SHIRTS.size()) % SKINS.size()]))
	var shirt := Color(String(SHIRTS[pid % SHIRTS.size()]))
	var pants := Color("3b3f4a").lerp(shirt, 0.15)
	var hair := Color(String(HAIRS[(pid / 3) % HAIRS.size()]))
	match pose:
		"assis":
			for sx in [-0.1, 0.1]:
				kit.box(Vector3(sx, 0.07, 0.2), Vector3(0.13, 0.14, 0.42), pants)
				kit.box(Vector3(sx, -0.2, 0.38), Vector3(0.12, 0.42, 0.13), pants)
				kit.box(Vector3(sx, -0.42, 0.43), Vector3(0.12, 0.06, 0.2), Color("2a2a2a"))
			kit.box(Vector3(0, 0.42, -0.02), Vector3(0.38, 0.52, 0.22), shirt)
			for sx2 in [-0.24, 0.24]:
				kit.beam(Vector3(sx2, 0.62, -0.02), Vector3(sx2 * 0.8, 0.3, 0.22), 0.09, 0.09, shirt.darkened(0.08))
				kit.box(Vector3(sx2 * 0.8, 0.28, 0.25), Vector3(0.08, 0.08, 0.08), skin)
			_head(kit, Vector3(0, 0.85, 0.0), skin, hair)
		"couche":
			kit.box(Vector3(0, 0.08, -0.15), Vector3(0.38, 0.16, 0.6), shirt)
			for sx in [-0.1, 0.1]:
				kit.box(Vector3(sx, 0.07, 0.42), Vector3(0.13, 0.13, 0.75), pants)
			# Couverture.
			kit.box(Vector3(0, 0.17, 0.25), Vector3(0.6, 0.06, 1.1), shirt.lightened(0.35))
			_head(kit, Vector3(0, 0.1, -0.6), skin, hair, true)
		_:
			for sx in [-0.1, 0.1]:
				kit.box(Vector3(sx, 0.42, 0), Vector3(0.13, 0.84, 0.14), pants)
				kit.box(Vector3(sx, 0.03, 0.04), Vector3(0.13, 0.06, 0.22), Color("2a2a2a"))
			kit.box(Vector3(0, 1.12, 0), Vector3(0.4, 0.56, 0.23), shirt)
			for sx2 in [-0.25, 0.25]:
				kit.box(Vector3(sx2, 1.05, 0), Vector3(0.09, 0.52, 0.1), shirt.darkened(0.08))
				kit.box(Vector3(sx2, 0.75, 0), Vector3(0.08, 0.1, 0.08), skin)
			_head(kit, Vector3(0, 1.55, 0), skin, hair)
	var m := kit.commit({"base": MeublesModeles.materials().base})
	_meshes[key] = m
	return m


static func _head(kit: LpKit, at: Vector3, skin: Color, hair: Color, lying := false) -> void:
	kit.box(at + Vector3(0, -0.12 if not lying else 0.0, 0 if not lying else 0.1), Vector3(0.1, 0.08, 0.1), skin)
	kit.blob(at, Vector3(0.12, 0.13, 0.12), skin.darkened(0.05), skin, 0.04, 0)
	if lying:
		kit.blob(at + Vector3(0, -0.02, -0.04), Vector3(0.13, 0.11, 0.11), hair, hair.lightened(0.1), 0.06, 0)
	else:
		kit.blob(at + Vector3(0, 0.05, -0.03), Vector3(0.13, 0.1, 0.13), hair, hair.lightened(0.1), 0.06, 0)
		kit.box(at + Vector3(0, 0.0, 0.11), Vector3(0.03, 0.04, 0.03), skin.darkened(0.1))
