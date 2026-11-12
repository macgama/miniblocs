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
## Une création a été enregistrée (ou refusée) : résultat de Creations.capture.
signal captured(result: Dictionary)

enum Tool { NONE, BLOCK, RECT, WALL, ERASE, CAPTURE }

## Côté d'un bloc (m). 0,5 donnerait des blocs plus fins.
const SIZE := 1.0
## Pas vertical (m) : celui du relief.
const UNIT_Y := 0.5
## Hauteur d'un bloc en pas verticaux.
const HU := int(SIZE / UNIT_Y)
const CHUNK := 16
const MAX_FILL := 4096
const REFUND := 0.5

## Matériaux : voir BlocMateriaux (textures dessinées par le jeu).
const MATERIALS := BlocMateriaux.LIST

@export var world_path: NodePath
@export var camera_path: NodePath
@export var buildings_path: NodePath

var world: TerrainWorld
var camera: Camera3D
var buildings: BuildingSystem

var tool: Tool = Tool.NONE
var material := 0
var wall_height := 3
## Nom donné à la prochaine création enregistrée (outil Enregistrer).
var capture_name := ""
## Forme posée (BlocFormes.S), teinte (BlocMateriaux.TINTS) et quart de tour
## ajouté à l'orientation automatique (touche R).
var shape := 0
var tint := 0
var rot_offset := 0

## Vector3i(x, y2, z) -> matériau
var blocks: Dictionary = {}
## Vector2i(x, z) -> nombre de blocs dans la colonne
var columns: Dictionary = {}

var _chunks: Dictionary = {} # Vector2i -> MeshInstance3D
var _dirty: Dictionary = {}
var _ghost: MeshInstance3D
var _ghost_ok: StandardMaterial3D
var _ghost_bad: StandardMaterial3D
var _undo: Array = []
var _target := {}
var _drag := false
var _drag_start := {}
var _right_press := Vector2.ZERO
var _bounds := AABB()
var _shape_ghost: MeshInstance3D
var _ghost_key := ""
## Vue en coupe (murs et étages) : blocs masqués au-dessus de clip_y dans clip_rect.
var clip_rect := Rect2i()
var clip_y := INF


func _ready() -> void:
	if not world_path.is_empty():
		world = get_node_or_null(world_path) as TerrainWorld
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if not buildings_path.is_empty():
		buildings = get_node_or_null(buildings_path) as BuildingSystem
	if buildings != null:
		buildings.extra_blocker = func(c: Vector2i) -> bool: return columns.has(c)
	_ghost_ok = BuildingSystem._tint(Color(1, 1, 1, 0.35))
	_ghost_bad = BuildingSystem._tint(Color(1, 0.3, 0.25, 0.45))
	_shape_ghost = MeshInstance3D.new()
	_shape_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shape_ghost.visible = false
	add_child(_shape_ghost)
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
	_ghost_key = ""
	_update_ghost()
	if tool != Tool.NONE:
		_emit_help()


func set_shape(sh: int) -> void:
	shape = sh
	_ghost_key = ""
	_update_ghost()
	if tool != Tool.NONE:
		_emit_help()


func set_tint(t: int) -> void:
	tint = clampi(t, 0, BlocMateriaux.TINTS.size() - 1)
	_ghost_key = ""
	_update_ghost()


func _emit_help() -> void:
	var mat: Dictionary = MATERIALS[material]
	var t := ""
	match tool:
		Tool.BLOCK:
			t = BlocFormes.shape_name(shape)
		Tool.RECT:
			t = "Rectangle : clic glissé pour une dalle"
		Tool.WALL:
			t = "Mur de %d bloc%s : clic glissé le long du mur" % [wall_height, "s" if wall_height > 1 else ""]
		Tool.ERASE:
			t = "Gomme : clic sur un bloc, ou glissé pour effacer un étage"
		Tool.CAPTURE:
			info_changed.emit("Enregistrer une création : clic glissé autour de ta construction (toutes les hauteurs sont prises) · Échap : arrêter")
			return
	var price := ReglagesPartie.prix(BlocFormes.price(BlocFormes.encode(material, shape)))
	info_changed.emit("%s · %s (%s) · clic : poser · R : tourner · clic droit : retirer · Ctrl+Z : annuler · Échap : arrêter" % [t, mat.name, BuildingSystem.format_money(price)])


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


## Masque les blocs au-dessus de y (m) dans le rectangle de cases r (vue en coupe).
func set_clip(r: Rect2i, y: float) -> void:
	if r == clip_rect and (y == clip_y or (is_inf(y) and is_inf(clip_y))):
		return
	for rr in [clip_rect, r]:
		var rect: Rect2i = rr
		if rect.size == Vector2i.ZERO:
			continue
		for cx in range(floori(float(rect.position.x) / CHUNK), floori(float(rect.end.x) / CHUNK) + 1):
			for cz in range(floori(float(rect.position.y) / CHUNK), floori(float(rect.end.y) / CHUNK) + 1):
				_dirty[Vector2i(cx, cz)] = true
	clip_rect = r
	clip_y = y


func _clipped(k: Vector3i) -> bool:
	return clip_rect.size != Vector2i.ZERO and k.y * UNIT_Y >= clip_y - 0.01 and clip_rect.has_point(Vector2i(k.x, k.z))


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


func _price(code: int) -> int:
	return ReglagesPartie.prix(BlocFormes.price(code))


## Code du bloc à poser en k avec la forme, la teinte et l'orientation courantes.
func current_code(target := {}) -> int:
	var sh := shape
	if sh == BlocFormes.S.SLAB and target.get("upper", false):
		sh = BlocFormes.S.SLAB_TOP
	var r := (_auto_rot() + rot_offset) % 4
	return BlocFormes.encode(material, sh, r, tint)


func _auto_rot() -> int:
	if camera == null:
		return 0
	return BlocFormes.rot_facing(-camera.global_transform.basis.z)


## Cases occupées par un bloc posé en k (une porte prend deux cases).
static func expand(k: Vector3i, code: int) -> Dictionary:
	var out := {k: code}
	if BlocFormes.cells(BlocFormes.shape_of(code)) == 2:
		var top := BlocFormes.encode(BlocFormes.mat_of(code), BlocFormes.shape_of(code), BlocFormes.rot_of(code),
			BlocFormes.tint_of(code), BlocFormes.is_open(code), true)
		out[k + Vector3i(0, HU, 0)] = top
	return out


## L'autre moitié d'une porte (ou null).
func partner(k: Vector3i) -> Variant:
	if not blocks.has(k):
		return null
	var code: int = blocks[k]
	if BlocFormes.cells(BlocFormes.shape_of(code)) != 2:
		return null
	var o := k - Vector3i(0, HU, 0) if BlocFormes.is_top(code) else k + Vector3i(0, HU, 0)
	return o if blocks.has(o) else null


func _can_pay(amount: int) -> bool:
	return buildings == null or buildings.unlimited_money or buildings.money >= amount


func _pay(amount: int) -> void:
	if buildings != null and not buildings.unlimited_money:
		buildings.money -= amount


## Pose plusieurs blocs d'un coup (une seule étape d'annulation). Renvoie le nombre posé.
## m : code du bloc (BlocFormes.encode) ; un simple indice de matériau donne un bloc plein.
func place_blocks(keys: Array, m: int) -> int:
	var ok_keys: Array = []
	var codes := {}
	var taken := {}
	var reason := ""
	for k0 in keys:
		var parts := expand(k0, m)
		var all_ok := true
		for k in parts:
			if taken.has(k):
				all_ok = false
				break
			var r := check_block(k)
			if r != "":
				all_ok = false
				if reason == "":
					reason = r
				break
			# Pas deux blocs qui se chevauchent dans la même opération.
			for d in range(-(HU - 1), HU):
				if taken.has(Vector3i(k.x, k.y + d, k.z)):
					all_ok = false
		if all_ok:
			for k in parts:
				ok_keys.append(k)
				codes[k] = parts[k]
				taken[k] = true
	if ok_keys.is_empty():
		if reason != "":
			message.emit(reason)
		return 0
	var cost := 0
	for k in ok_keys:
		cost += _price(codes[k])
	if not _can_pay(cost):
		message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(cost))
		return 0
	_pay(cost)
	for k in ok_keys:
		_put_block(k, codes[k])
	_undo.append({"added": ok_keys, "removed": {}})
	_after_edit(ok_keys)
	return ok_keys.size()


## Retire des blocs (une seule étape d'annulation). Renvoie le nombre retiré.
func remove_blocks(keys: Array) -> int:
	var removed := {}
	var back := 0
	var all_keys: Array = []
	for k in keys:
		all_keys.append(k)
		var o: Variant = partner(k)
		if o != null:
			all_keys.append(o)
	for k in all_keys:
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
	for c in blocks.values():
		var m := BlocFormes.mat_of(c)
		out[m] = int(out.get(m, 0)) + 1
	return out


## Ouvre ou ferme la porte (ou la porte de garage entière) en k. Renvoie vrai si fait.
func toggle_open(k: Vector3i) -> bool:
	if not blocks.has(k):
		return false
	var code: int = blocks[k]
	var sh := BlocFormes.shape_of(code)
	if not BlocFormes.openable(sh):
		return false
	var open := not BlocFormes.is_open(code)
	var todo: Array = [k]
	var seen := {k: true}
	var keys: Array = []
	while not todo.is_empty() and keys.size() < 256:
		var c: Vector3i = todo.pop_back()
		keys.append(c)
		var o: Variant = partner(c)
		var nb: Array = [] if o == null else [o]
		if sh == BlocFormes.S.GARAGE:
			nb.append_array([c + Vector3i(1, 0, 0), c - Vector3i(1, 0, 0), c + Vector3i(0, 0, 1), c - Vector3i(0, 0, 1),
				c + Vector3i(0, HU, 0), c - Vector3i(0, HU, 0)])
		for n in nb:
			if not seen.has(n) and blocks.has(n) and BlocFormes.shape_of(blocks[n]) == sh:
				seen[n] = true
				todo.append(n)
	for c in keys:
		blocks[c] = BlocFormes.with_open(blocks[c], open)
		_mark(Vector2i(c.x, c.z))
	changed.emit()
	return true


## Ouvre la porte visée (vue au sol), à moins de max_dist mètres.
func interact_ray(origin: Vector3, dir: Vector3, max_dist := 4.0) -> bool:
	var hit := raycast_block(origin, dir.normalized())
	if hit.is_empty() or float(hit.dist) > max_dist:
		# On tolère un peu plus loin pour une porte de garage ou un clic imprécis.
		return false
	var k: Vector3i = hit.key
	if toggle_open(k):
		message.emit("%s %s." % [BlocFormes.shape_name(BlocFormes.shape_of(blocks[k])),
			"ouverte" if BlocFormes.is_open(blocks[k]) else "fermée"])
		return true
	return false


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
		var hp: Vector3 = origin + dir * float(b.dist)
		var frac := (hp.y - k.y * UNIT_Y) / (HU * UNIT_Y)
		return {"place": k + n, "hit": k, "upper": n.y == 0 and frac > 0.5}
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
		Tool.RECT, Tool.ERASE, Tool.CAPTURE:
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
			if tool == Tool.CAPTURE:
				_drag = true
				_drag_start = _target.duplicate()
				_drag_start.place = _cap_key(_target)
			elif tool == Tool.BLOCK:
				place_blocks([_target.place], current_code(_target))
				_update_target(mb.position)
			elif tool == Tool.ERASE and _target.get("hit") == null:
				return
			else:
				_drag = true
				_drag_start = _target.duplicate()
		elif _drag:
			_drag = false
			if tool == Tool.CAPTURE:
				var ca: Vector3i = _drag_start.place
				var cb: Vector3i = _cap_key(_target) if not _target.is_empty() else ca
				capture(Rect2i(Vector2i(mini(ca.x, cb.x), mini(ca.z, cb.z)), Vector2i(absi(cb.x - ca.x) + 1, absi(cb.z - ca.z) + 1)))
			elif tool == Tool.ERASE:
				var a: Vector3i = _drag_start.hit
				var b: Vector3i = _target.get("hit") if _target.get("hit") != null else a
				remove_blocks(drag_keys(a, Vector3i(b.x, a.y, b.z), Tool.ERASE))
			elif not _target.is_empty():
				var a2: Vector3i = _drag_start.place
				var b2: Vector3i = _target.place
				place_blocks(drag_keys(a2, Vector3i(b2.x, a2.y, b2.z), tool), current_code(_drag_start))
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
		elif key.physical_keycode == KEY_R and not key.ctrl_pressed:
			rot_offset = (rot_offset + 1) % 4
			_ghost_key = ""
			_update_ghost()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_Z and key.ctrl_pressed:
			if undo():
				message.emit("Annulé.")
			get_viewport().set_input_as_handled()


## Case visée par l'outil Enregistrer : le bloc touché lui-même, sinon le sol.
func _cap_key(t: Dictionary) -> Vector3i:
	return t.hit if t.get("hit") != null else t.place


## Enregistre les blocs du rectangle comme création du catalogue.
func capture(rect: Rect2i) -> Dictionary:
	var res := Creations.capture(self, rect, capture_name)
	if res.ok:
		message.emit("Création « %s » enregistrée : %d blocs, %d × %d m. Retrouve-la dans l'onglet Mes créations." % [
			Creations.items[res.id].name, res.blocks, res.w, res.d])
	else:
		message.emit(res.reason)
	captured.emit(res)
	return res


func _update_target(screen: Vector2) -> void:
	_target = target_from_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_update_ghost()


func _update_ghost() -> void:
	_shape_ghost.visible = false
	if tool == Tool.NONE or _target.is_empty():
		_ghost.visible = false
		return
	if tool == Tool.BLOCK and not _drag:
		var code := current_code(_target)
		var k: Vector3i = _target.place
		var ok := true
		for part in expand(k, code):
			ok = ok and check_block(part) == ""
		if ok:
			var gk := str(code)
			if gk != _ghost_key:
				_ghost_key = gk
				var gm := BlocMesher.new()
				BlocFormes.emit(gm, code, Vector3.ZERO, func(_o: Vector3i) -> int: return -1)
				if BlocFormes.cells(BlocFormes.shape_of(code)) == 2:
					BlocFormes.emit(gm, expand(k, code)[k + Vector3i(0, HU, 0)], Vector3(0, HU * UNIT_Y, 0), func(_o: Vector3i) -> int: return -1)
				_shape_ghost.mesh = gm.to_mesh()
				_shape_ghost.material_override = BlocMateriaux.ghost_material()
			_shape_ghost.position = Vector3(k.x * SIZE, k.y * UNIT_Y, k.z * SIZE)
			_shape_ghost.visible = true
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
	elif tool == Tool.CAPTURE:
		var ca: Vector3i = _drag_start.place if _drag else _cap_key(_target)
		var cb: Vector3i = _cap_key(_target)
		keys = drag_keys(ca, Vector3i(cb.x, ca.y, cb.z), Tool.CAPTURE)
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
	elif tool == Tool.CAPTURE:
		_ghost_ok.albedo_color = Color(0.3, 0.7, 1.0, 0.35)
		_ghost.material_override = _ghost_ok
		# Toute la hauteur des colonnes sélectionnées.
		var top := hi.y
		for k in blocks:
			if k.x >= lo.x and k.x < hi.x and k.z >= lo.z and k.z < hi.z:
				top = maxf(top, k.y * UNIT_Y + HU * UNIT_Y)
		(_ghost.mesh as BoxMesh).size.y = top - lo.y + 0.04
		_ghost.position.y = (lo.y + top) / 2.0
		if _drag:
			info_changed.emit("Sélection %d × %d m · relâche pour enregistrer" % [roundi(hi.x - lo.x), roundi(hi.z - lo.z)])
		return
	elif ok:
		var c: Color = BlocMateriaux.color(material) * BlocMateriaux.tint_color(tint)
		_ghost_ok.albedo_color = Color(c.r, c.g, c.b, 0.55)
		_ghost.material_override = _ghost_ok
	else:
		_ghost.material_override = _ghost_bad
	if _drag and tool != Tool.ERASE:
		info_changed.emit("%d blocs · %s" % [keys.size(), BuildingSystem.format_money(keys.size() * _price(current_code(_drag_start)))])


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


func _build_chunk(ck: Vector2i, keys: Array) -> void:
	var mi: MeshInstance3D = _chunks.get(ck)
	if keys.is_empty():
		if mi:
			mi.queue_free()
			_chunks.erase(ck)
		return
	var mesher := BlocMesher.new()
	for k in keys:
		var kk: Vector3i = k
		if _clipped(kk):
			continue
		BlocFormes.emit(mesher, blocks[kk], Vector3(kk.x * SIZE, kk.y * UNIT_Y, kk.z * SIZE),
			func(o: Vector3i) -> int: return int(blocks.get(kk + o, -1)))
	var mesh := mesher.to_mesh()
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Blocs_%d_%d" % [ck.x, ck.y]
		add_child(mi)
		_chunks[ck] = mi
	mi.mesh = mesh
	# Collision des blocs pleins (le verre aussi : on ne passe pas à travers).
	for c in mi.get_children():
		c.queue_free()
	if mesh.get_surface_count() > 0:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		mi.add_child(body)


# --- Sauvegarde ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var flat := []
	for k in blocks:
		flat.append_array([k.x, k.y, k.z, blocks[k]])
	return {"version": 2, "size": SIZE, "blocks": flat}


func from_dict(data: Dictionary) -> void:
	clear()
	var flat: Array = data.get("blocks", [])
	var i := 0
	while i + 3 < flat.size():
		var m := int(flat[i + 3])
		if m >= 0 and BlocFormes.mat_of(m) < MATERIALS.size() and BlocFormes.INFO.has(BlocFormes.shape_of(m)):
			_put_block(Vector3i(int(flat[i]), int(flat[i + 1]), int(flat[i + 2])), m)
		i += 4
	changed.emit()
