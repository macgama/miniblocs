class_name BlockEditor
extends Node3D
## Éditeur libre bloc par bloc, façon jeu de construction en cubes.
##
## - Blocs de SIZE mètres (1 m par défaut) posés sur le relief ou contre
##   d'autres blocs. Le relief est en marches de 0,5 m : la hauteur d'un bloc
##   est donc repérée en demi-mètres (y2), ce qui permet de poser au ras du sol
##   partout.
## - Outils : Bloc (un clic = un bloc), Rectangle (dalle ou plancher),
##   Mur (ligne de N blocs de haut), Gomme. Clic droit court : retirer un bloc.
##   Ctrl+Z : annuler.
## - Règles : chaque bloc a un prix (caisse partagée avec les bâtiments),
##   pas de bloc sur une voie, dans un bâtiment ou sous terre.
## - Sauvegarde compacte : [x, y2, z, matériau] par bloc.

signal info_changed(text: String)
signal message(text: String)
signal changed

enum Tool { NONE, BLOCK, RECT, WALL, ERASE }

## Côté d'un bloc (m). 0,5 donnerait des blocs plus fins.
const SIZE := 1.0
## Pas vertical (m) : celui du relief.
const UNIT_Y := 0.5
## Hauteur d'un bloc en pas verticaux.
const HU := int(SIZE / UNIT_Y)
const CHUNK := 16
const MAX_FILL := 4096
const REFUND := 0.5

const MATERIALS := [
	{"name": "Brique", "color": Color("b8573f"), "price": 120},
	{"name": "Pierre", "color": Color("9a9a94"), "price": 150},
	{"name": "Bois", "color": Color("8a5a36"), "price": 80},
	{"name": "Planches", "color": Color("c9a27e"), "price": 70},
	{"name": "Béton", "color": Color("b9b6ae"), "price": 100},
	{"name": "Enduit blanc", "color": Color("f1ece2"), "price": 90},
	{"name": "Enduit jaune", "color": Color("f2d491"), "price": 90},
	{"name": "Tuile", "color": Color("b5523b"), "price": 110},
	{"name": "Ardoise", "color": Color("4f5560"), "price": 130},
	{"name": "Métal", "color": Color("7d8590"), "price": 180},
	{"name": "Verre", "color": Color(0.62, 0.83, 0.92, 0.45), "price": 200, "glass": true},
	{"name": "Herbe", "color": Color("6aa84f"), "price": 20},
	{"name": "Sable", "color": Color("e6d59c"), "price": 20},
	{"name": "Feuillage", "color": Color("3f7d3a"), "price": 30},
]

@export var world_path: NodePath
@export var camera_path: NodePath
@export var buildings_path: NodePath

var world: TerrainWorld
var camera: Camera3D
var buildings: BuildingSystem

var tool: Tool = Tool.NONE
var material := 0
var wall_height := 3

## Vector3i(x, y2, z) -> matériau
var blocks: Dictionary = {}
## Vector2i(x, z) -> nombre de blocs dans la colonne
var columns: Dictionary = {}

var _chunks: Dictionary = {} # Vector2i -> MeshInstance3D
var _dirty: Dictionary = {}
var _opaque_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D
var _ghost: MeshInstance3D
var _ghost_ok: StandardMaterial3D
var _ghost_bad: StandardMaterial3D
var _undo: Array = []
var _target := {}
var _drag := false
var _drag_start := {}
var _right_press := Vector2.ZERO
var _bounds := AABB()


func _ready() -> void:
	if not world_path.is_empty():
		world = get_node_or_null(world_path) as TerrainWorld
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if not buildings_path.is_empty():
		buildings = get_node_or_null(buildings_path) as BuildingSystem
	if buildings != null:
		buildings.extra_blocker = func(c: Vector2i) -> bool: return columns.has(c)
	_opaque_mat = StandardMaterial3D.new()
	_opaque_mat.vertex_color_use_as_albedo = true
	_opaque_mat.vertex_color_is_srgb = true
	_opaque_mat.roughness = 0.9
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.vertex_color_use_as_albedo = true
	_glass_mat.vertex_color_is_srgb = true
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.roughness = 0.1
	_glass_mat.metallic_specular = 0.9
	_ghost_ok = BuildingSystem._tint(Color(1, 1, 1, 0.35))
	_ghost_bad = BuildingSystem._tint(Color(1, 0.3, 0.25, 0.45))
	_ghost = MeshInstance3D.new()
	_ghost.mesh = BoxMesh.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)


# --- Outils -------------------------------------------------------------------------

func set_tool(t: Tool) -> void:
	tool = t
	_drag = false
	_target = {}
	_ghost.visible = false
	if t == Tool.NONE:
		info_changed.emit("")
	else:
		_emit_help()


func set_inactive() -> void:
	if tool != Tool.NONE:
		set_tool(Tool.NONE)


func set_material(m: int) -> void:
	material = clampi(m, 0, MATERIALS.size() - 1)
	_update_ghost()
	if tool != Tool.NONE:
		_emit_help()


func _emit_help() -> void:
	var mat: Dictionary = MATERIALS[material]
	var t := ""
	match tool:
		Tool.BLOCK:
			t = "Bloc"
		Tool.RECT:
			t = "Rectangle : clic glissé pour une dalle"
		Tool.WALL:
			t = "Mur de %d bloc%s : clic glissé le long du mur" % [wall_height, "s" if wall_height > 1 else ""]
		Tool.ERASE:
			t = "Gomme : clic sur un bloc, ou glissé pour effacer un étage"
	info_changed.emit("%s · %s (%d € le bloc) · clic : poser · clic droit : retirer · Ctrl+Z : annuler · Échap : arrêter" % [t, mat.name, mat.price])


func clear() -> void:
	blocks.clear()
	columns.clear()
	_undo.clear()
	for c in _chunks.values():
		(c as Node).queue_free()
	_chunks.clear()
	_dirty.clear()
	_bounds = AABB()
	changed.emit()


# --- Blocs --------------------------------------------------------------------------

## Case du terrain (1 m) qui contient la colonne de blocs (x, z).
static func cell_of(x: int, z: int) -> Vector2i:
	return Vector2i(floori(x * SIZE), floori(z * SIZE))


## Bloc qui recouvre (même en partie) l'intervalle vertical d'un bloc posé en y2.
func overlapping(k: Vector3i) -> Variant:
	for d in range(-(HU - 1), HU):
		var o := Vector3i(k.x, k.y + d, k.z)
		if blocks.has(o):
			return o
	return null


## Raison pour laquelle on ne peut pas poser ce bloc ("" si possible).
func check_block(k: Vector3i) -> String:
	if world == null:
		return "Terrain absent."
	if overlapping(k) != null:
		return "Il y a déjà un bloc ici."
	var cell := cell_of(k.x, k.z)
	var g := world.cell_height(cell)
	if is_nan(g):
		return "Relief encore en chargement."
	if (k.y + HU) * UNIT_Y <= maxf(g, 0.0) + 0.001:
		return "Ce bloc serait sous terre."
	if buildings != null:
		if buildings.occupancy.has(cell):
			return "Un bâtiment occupe cette case."
		if buildings.transport != null and buildings.transport.is_cell_occupied(cell):
			return "Une voie passe ici."
	return ""


func _price(m: int) -> int:
	return int(MATERIALS[m].price)


func _can_pay(amount: int) -> bool:
	return buildings == null or buildings.unlimited_money or buildings.money >= amount


func _pay(amount: int) -> void:
	if buildings != null and not buildings.unlimited_money:
		buildings.money -= amount


## Pose plusieurs blocs d'un coup (une seule étape d'annulation). Renvoie le nombre posé.
func place_blocks(keys: Array, m: int) -> int:
	var ok_keys: Array = []
	var taken := {}
	var reason := ""
	for k in keys:
		if taken.has(k):
			continue
		var r := check_block(k)
		if r == "":
			# Pas deux blocs qui se chevauchent dans la même opération.
			var clash := false
			for d in range(-(HU - 1), HU):
				clash = clash or taken.has(Vector3i(k.x, k.y + d, k.z))
			if not clash:
				ok_keys.append(k)
				taken[k] = true
		elif reason == "":
			reason = r
	if ok_keys.is_empty():
		if reason != "":
			message.emit(reason)
		return 0
	var cost := ok_keys.size() * _price(m)
	if not _can_pay(cost):
		message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(cost))
		return 0
	_pay(cost)
	for k in ok_keys:
		_put_block(k, m)
	_undo.append({"added": ok_keys, "removed": {}})
	_after_edit(ok_keys)
	return ok_keys.size()


## Retire des blocs (une seule étape d'annulation). Renvoie le nombre retiré.
func remove_blocks(keys: Array) -> int:
	var removed := {}
	var back := 0
	for k in keys:
		if blocks.has(k) and not removed.has(k):
			removed[k] = blocks[k]
			back += roundi(_price(blocks[k]) * REFUND)
			_drop_block(k)
	if removed.is_empty():
		return 0
	_pay(-back)
	_undo.append({"added": [], "removed": removed})
	_after_edit(removed.keys())
	return removed.size()


## Annule la dernière opération (sans rendre ni reprendre d'argent au-delà du prix).
func undo() -> bool:
	if _undo.is_empty():
		return false
	var op: Dictionary = _undo.pop_back()
	var touched: Array = []
	var refund := 0
	for k in op.added:
		if blocks.has(k):
			refund += _price(blocks[k])
			_drop_block(k)
			touched.append(k)
	var cost := 0
	for k in op.removed:
		if overlapping(k) == null:
			_put_block(k, op.removed[k])
			cost += roundi(_price(op.removed[k]) * REFUND)
			touched.append(k)
	_pay(cost - refund)
	_after_edit(touched)
	return true


func _put_block(k: Vector3i, m: int) -> void:
	blocks[k] = m
	var c := Vector2i(k.x, k.z)
	columns[cell_of(k.x, k.z)] = int(columns.get(cell_of(k.x, k.z), 0)) + 1
	_mark(c)
	var p := Vector3(k.x * SIZE, k.y * UNIT_Y, k.z * SIZE)
	var box := AABB(p, Vector3(SIZE, HU * UNIT_Y, SIZE))
	_bounds = box if _bounds.size == Vector3.ZERO else _bounds.merge(box)


func _drop_block(k: Vector3i) -> void:
	blocks.erase(k)
	var cell := cell_of(k.x, k.z)
	var n := int(columns.get(cell, 0)) - 1
	if n <= 0:
		columns.erase(cell)
	else:
		columns[cell] = n
	_mark(Vector2i(k.x, k.z))


func _mark(c: Vector2i) -> void:
	# Les voisins aussi : leurs faces cachées peuvent réapparaître.
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		_dirty[Vector2i(floori(float(n.x) / CHUNK), floori(float(n.y) / CHUNK))] = true


func _after_edit(keys: Array) -> void:
	# Pas d'arbres sous les blocs posés au sol.
	if world != null:
		var cells := []
		for k in keys:
			var cell := cell_of(k.x, k.z)
			if columns.has(cell) and not world.modifications.has(cell):
				var g := world.cell_height(cell)
				if not is_nan(g):
					world.modifications[cell] = g
					cells.append(cell)
		if not cells.is_empty():
			world.mark_cells_dirty(cells)
	changed.emit()


func count_by_material() -> Dictionary:
	var out := {}
	for m in blocks.values():
		out[m] = int(out.get(m, 0)) + 1
	return out


func summary() -> String:
	if blocks.is_empty():
		return "Aucun bloc posé."
	return "%d bloc%s posé%s (%s × %s m)" % [blocks.size(), "s" if blocks.size() > 1 else "", "s" if blocks.size() > 1 else "",
		str(SIZE).replace(".", ","), str(SIZE).replace(".", ",")]


# --- Rayon --------------------------------------------------------------------------

## Bloc touché par un rayon : {"key", "normal": Vector3i (en x, pas, z), "dist"} ou {}.
func raycast_block(origin: Vector3, dir: Vector3) -> Dictionary:
	if blocks.is_empty():
		return {}
	var box := _bounds.grow(0.01)
	var t0 := 0.0
	var t1 := 2000.0
	# Fenêtre du rayon dans la boîte englobante des blocs.
	for a in 3:
		var o := origin[a]
		var d := dir[a]
		var lo := box.position[a]
		var hi := box.end[a]
		if absf(d) < 1e-9:
			if o < lo or o > hi:
				return {}
			continue
		var ta := (lo - o) / d
		var tb := (hi - o) / d
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t0 > t1:
		return {}
	var step := minf(SIZE, UNIT_Y) * 0.12
	var t := t0
	var prev := origin + dir * t0
	while t <= t1:
		var p := origin + dir * t
		var k: Variant = _block_at_point(p)
		if k != null:
			return {"key": k, "normal": _hit_normal(k, prev), "dist": t}
		prev = p
		t += step
	return {}


func _block_at_point(p: Vector3) -> Variant:
	var x := floori(p.x / SIZE)
	var z := floori(p.z / SIZE)
	var yy := floori(p.y / UNIT_Y)
	for d in HU:
		var k := Vector3i(x, yy - d, z)
		if blocks.has(k):
			return k
	return null


func _hit_normal(k: Vector3i, prev: Vector3) -> Vector3i:
	var x0 := k.x * SIZE
	var z0 := k.z * SIZE
	var y0 := k.y * UNIT_Y
	if prev.y >= y0 + HU * UNIT_Y - 1e-4:
		return Vector3i(0, HU, 0)
	if prev.y < y0:
		return Vector3i(0, -HU, 0)
	if prev.x < x0:
		return Vector3i(-1, 0, 0)
	if prev.x >= x0 + SIZE:
		return Vector3i(1, 0, 0)
	if prev.z < z0:
		return Vector3i(0, 0, -1)
	return Vector3i(0, 0, 1)


## Cible sous la souris : {"place": Vector3i (case libre), "hit": Vector3i ou null}.
func target_from_ray(origin: Vector3, dir: Vector3) -> Dictionary:
	var b := raycast_block(origin, dir)
	var ground: Variant = world.pick_point(origin, dir) if world != null else null
	var gd := INF if ground == null else origin.distance_to(ground)
	if not b.is_empty() and b.dist <= gd + 0.05:
		var k: Vector3i = b.key
		var n: Vector3i = b.normal
		return {"place": k + n, "hit": k}
	if ground == null:
		return {}
	var gp: Vector3 = ground
	var x := floori(gp.x / SIZE)
	var z := floori(gp.z / SIZE)
	var g := world.cell_height(cell_of(x, z))
	if is_nan(g):
		return {}
	return {"place": Vector3i(x, roundi(maxf(g, 0.0) / UNIT_Y), z), "hit": null}


## Blocs d'une opération glissée entre deux cibles.
func drag_keys(a: Vector3i, b: Vector3i, t: Tool) -> Array:
	var out: Array = []
	match t:
		Tool.RECT, Tool.ERASE:
			for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
					out.append(Vector3i(x, a.y, z))
		Tool.WALL:
			var horizontal := absi(b.x - a.x) >= absi(b.z - a.z)
			var n := absi(b.x - a.x) if horizontal else absi(b.z - a.z)
			var s := signi(b.x - a.x) if horizontal else signi(b.z - a.z)
			for i in n + 1:
				for h in wall_height:
					var k := Vector3i(a.x + i * s, a.y + h * HU, a.z) if horizontal else Vector3i(a.x, a.y + h * HU, a.z + i * s)
					out.append(k)
		_:
			out.append(a)
	if out.size() > MAX_FILL:
		out.resize(MAX_FILL)
	return out


# --- Souris et clavier ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if tool == Tool.NONE or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		_update_target((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				_update_target(mb.position)
				if _target.get("hit") != null:
					remove_blocks([_target.hit])
					_update_target(mb.position)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_target(mb.position)
		get_viewport().set_input_as_handled()
		if mb.pressed:
			if _target.is_empty():
				return
			if tool == Tool.BLOCK:
				place_blocks([_target.place], material)
				_update_target(mb.position)
			elif tool == Tool.ERASE and _target.get("hit") == null:
				return
			else:
				_drag = true
				_drag_start = _target.duplicate()
		elif _drag:
			_drag = false
			if tool == Tool.ERASE:
				var a: Vector3i = _drag_start.hit
				var b: Vector3i = _target.get("hit") if _target.get("hit") != null else a
				remove_blocks(drag_keys(a, Vector3i(b.x, a.y, b.z), Tool.ERASE))
			elif not _target.is_empty():
				var a2: Vector3i = _drag_start.place
				var b2: Vector3i = _target.place
				place_blocks(drag_keys(a2, Vector3i(b2.x, a2.y, b2.z), tool), material)
			_update_target(mb.position)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			if _drag:
				_drag = false
				_update_ghost()
			else:
				set_inactive()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_Z and key.ctrl_pressed:
			if undo():
				message.emit("Annulé.")
			get_viewport().set_input_as_handled()


func _update_target(screen: Vector2) -> void:
	_target = target_from_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_update_ghost()


func _update_ghost() -> void:
	if tool == Tool.NONE or _target.is_empty():
		_ghost.visible = false
		return
	var keys: Array
	var ok := true
	if tool == Tool.ERASE:
		if _target.get("hit") == null:
			_ghost.visible = false
			return
		var a: Vector3i = _drag_start.hit if _drag else _target.hit
		var b: Vector3i = _target.hit
		keys = drag_keys(a, Vector3i(b.x, a.y, b.z), Tool.ERASE) if _drag else [a]
	else:
		var a2: Vector3i = _drag_start.place if _drag else _target.place
		var b2: Vector3i = _target.place
		keys = drag_keys(a2, Vector3i(b2.x, a2.y, b2.z), tool) if _drag or tool == Tool.WALL else [a2]
		if keys.size() == 1:
			ok = check_block(keys[0]) == ""
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for k in keys:
		var p := Vector3(k.x * SIZE, k.y * UNIT_Y, k.z * SIZE)
		lo = lo.min(p)
		hi = hi.max(p + Vector3(SIZE, HU * UNIT_Y, SIZE))
	_ghost.visible = true
	(_ghost.mesh as BoxMesh).size = hi - lo + Vector3(0.04, 0.04, 0.04)
	_ghost.position = (lo + hi) / 2.0
	var mat: Dictionary = MATERIALS[material]
	if tool == Tool.ERASE:
		_ghost.material_override = _ghost_bad
	elif ok:
		var c: Color = mat.color
		_ghost_ok.albedo_color = Color(c.r, c.g, c.b, 0.55)
		_ghost.material_override = _ghost_ok
	else:
		_ghost.material_override = _ghost_bad
	if _drag and tool != Tool.ERASE:
		info_changed.emit("%d blocs · %s" % [keys.size(), BuildingSystem.format_money(keys.size() * int(mat.price))])


# --- Affichage ----------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _dirty.is_empty():
		return
	var by_chunk := {}
	for k in blocks:
		var ck := Vector2i(floori(float(k.x) / CHUNK), floori(float(k.z) / CHUNK))
		if _dirty.has(ck):
			if not by_chunk.has(ck):
				by_chunk[ck] = []
			by_chunk[ck].append(k)
	for ck in _dirty:
		_build_chunk(ck, by_chunk.get(ck, []))
	_dirty.clear()


const _FACES := [
	[Vector3i(1, 0, 0), Vector3.RIGHT],
	[Vector3i(-1, 0, 0), Vector3.LEFT],
	[Vector3i(0, 0, 1), Vector3.BACK],
	[Vector3i(0, 0, -1), Vector3.FORWARD],
]


func _build_chunk(ck: Vector2i, keys: Array) -> void:
	var mi: MeshInstance3D = _chunks.get(ck)
	if keys.is_empty():
		if mi:
			mi.queue_free()
			_chunks.erase(ck)
		return
	var solid := BlocMesh.new()
	var glass := BlocMesh.new()
	var hy := HU * UNIT_Y
	for k in keys:
		var m: int = blocks[k]
		var mat: Dictionary = MATERIALS[m]
		var is_glass := bool(mat.get("glass", false))
		var kit := glass if is_glass else solid
		# Légère variation par bloc pour lire chaque cube.
		var col: Color = (mat.color as Color).darkened(float(absi(hash(k)) % 7) * 0.012)
		var x0: float = k.x * SIZE
		var z0: float = k.z * SIZE
		var y0: float = k.y * UNIT_Y
		var x1: float = x0 + SIZE
		var z1: float = z0 + SIZE
		var y1: float = y0 + hy
		if not _hides(k + Vector3i(0, HU, 0), is_glass):
			kit.quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, col)
		if not _hides(k - Vector3i(0, HU, 0), is_glass):
			kit.quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, col.darkened(0.2))
		for f in _FACES:
			var off: Vector3i = f[0]
			if _hides(k + off, is_glass):
				continue
			var n: Vector3 = f[1]
			var side := col.darkened(0.08 if n.x != 0.0 else 0.03)
			var cx := x1 if off.x > 0 else x0
			var cz := z1 if off.z > 0 else z0
			if off.x != 0:
				kit.quad(Vector3(cx, y0, z0), Vector3(cx, y0, z1), Vector3(cx, y1, z1), Vector3(cx, y1, z0), n, side)
			else:
				kit.quad(Vector3(x0, y0, cz), Vector3(x1, y0, cz), Vector3(x1, y1, cz), Vector3(x0, y1, cz), n, side)
	var mesh := solid.to_mesh(_opaque_mat)
	if not glass.verts.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = glass.verts
		arrays[Mesh.ARRAY_NORMAL] = glass.normals
		arrays[Mesh.ARRAY_COLOR] = glass.colors
		arrays[Mesh.ARRAY_INDEX] = glass.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _glass_mat)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Blocs_%d_%d" % [ck.x, ck.y]
		add_child(mi)
		_chunks[ck] = mi
	mi.mesh = mesh


## Vrai si un voisin exactement aligné cache cette face.
func _hides(n: Vector3i, is_glass: bool) -> bool:
	if not blocks.has(n):
		return false
	var other_glass := bool(MATERIALS[blocks[n]].get("glass", false))
	return other_glass == is_glass


# --- Sauvegarde ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var flat := []
	for k in blocks:
		flat.append_array([k.x, k.y, k.z, blocks[k]])
	return {"version": 1, "size": SIZE, "blocks": flat}


func from_dict(data: Dictionary) -> void:
	clear()
	var flat: Array = data.get("blocks", [])
	var i := 0
	while i + 3 < flat.size():
		var m := int(flat[i + 3])
		if m >= 0 and m < MATERIALS.size():
			_put_block(Vector3i(int(flat[i]), int(flat[i + 1]), int(flat[i + 2])), m)
		i += 4
	changed.emit()
