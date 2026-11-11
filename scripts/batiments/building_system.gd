class_name BuildingSystem
extends Node3D
## Pose de bâtiments prédéfinis dans le mode Terre.
##
## - Aperçu fantôme sous la souris (vert : possible, rouge : impossible + raison).
## - R : tourner d'un quart de tour. Sans rotation manuelle, la façade se
##   tourne toute seule vers la route la plus proche.
## - Terrassement automatique : l'emprise est aplanie à la hauteur moyenne,
##   avec un talus de deux cases autour.
## - Règles du bac à sable : accès à une voie obligatoire (option), coût du
##   bâtiment et du terrassement payé par la caisse (option « argent illimité »).
## - Données sérialisables : un bâtiment = {id, t, x, z, r, h}.

signal info_changed(text: String)
signal message(text: String)
signal changed

enum Mode { NONE, PLACE, DEMOLISH }

## Écart de hauteur maximal sous l'emprise avant de refuser le terrassement (m).
const MAX_RELIEF := 12.0
## Distance maximale entre la porte et une voie pour être desservi (m).
const ACCESS_MAX := 10.0
## Largeur du talus autour de l'emprise (cases).
const APRON := 2
## Coût du terrassement par case et par mètre de hauteur déplacée (€).
const EARTH_COST := 15.0
## Part du prix rendue à la démolition.
const REFUND := 0.5
const START_MONEY := 20_000_000

@export var world_path: NodePath
@export var camera_path: NodePath
@export var transport_path: NodePath

var world: TerrainWorld
var camera: Camera3D
var transport: TransportSystem

var mode: Mode = Mode.NONE
var type_id := "maison"
var rot := 0
var manual_rot := false
## Règles du bac à sable.
var require_access := true
var unlimited_money := false
var money: int = START_MONEY

## id -> {"id", "t", "x", "z", "r", "h"} (x, z : coin de l'emprise)
var buildings: Dictionary = {}
## Vector2i -> id du bâtiment qui occupe la case
var occupancy: Dictionary = {}
var next_id := 1

var _nodes: Dictionary = {} # id -> MeshInstance3D
var _meshes: Dictionary = {} # type -> ArrayMesh
var _material: StandardMaterial3D
var _ghost: MeshInstance3D
var _plate: MeshInstance3D
var _link: MeshInstance3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _hover_mat: StandardMaterial3D
var _cursor := Vector2i.ZERO
var _cursor_valid := false
var _check := {}
var _hover_building := -1
var _right_press := Vector2.ZERO


func _ready() -> void:
	if not world_path.is_empty():
		world = get_node_or_null(world_path) as TerrainWorld
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if not transport_path.is_empty():
		transport = get_node_or_null(transport_path) as TransportSystem
	changed.connect(func() -> void: _summary_dirty = true)
	if transport != null:
		transport.network_changed.connect(func() -> void: _summary_dirty = true)
		# Une voie ne peut pas traverser un bâtiment.
		transport.blocker = func(c: Vector2i) -> bool: return occupancy.has(c)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.95
	_ok_mat = _tint(Color(0.35, 0.95, 0.45, 0.55))
	_bad_mat = _tint(Color(1.0, 0.3, 0.25, 0.55))
	_hover_mat = _tint(Color(1.0, 0.25, 0.2, 0.45))

	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	_plate = MeshInstance3D.new()
	_plate.mesh = BoxMesh.new()
	_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plate.visible = false
	add_child(_plate)
	_link = MeshInstance3D.new()
	_link.mesh = BoxMesh.new()
	_link.material_override = _tint(Color(1, 0.85, 0.2, 0.85))
	_link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_link.visible = false
	add_child(_link)


static func _tint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func mesh_for(id: String) -> ArrayMesh:
	if not _meshes.has(id):
		_meshes[id] = BuildingCatalog.build_mesh(id, _material)
	return _meshes[id]


# --- Outils -------------------------------------------------------------------------

func set_place(id: String) -> void:
	mode = Mode.PLACE
	type_id = id
	manual_rot = false
	_ghost.mesh = mesh_for(id)
	_refresh()
	var t := BuildingCatalog.get_type(id)
	info_changed.emit("%s (%d × %d m) : clic pour poser · R : tourner · clic droit ou Échap : arrêter" % [t.name, t.w, t.d])


func set_demolish() -> void:
	mode = Mode.DEMOLISH
	_refresh()
	info_changed.emit("Démolir un bâtiment : clic dessus (%d %% du prix rendu, le terrain reste aplani)." % roundi(REFUND * 100))


func set_inactive() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	_refresh()
	info_changed.emit("")


func rotate_quarter() -> void:
	rot = (rot + 1) % 4
	manual_rot = true
	_refresh()


func clear() -> void:
	for n in _nodes.values():
		(n as Node).queue_free()
	_nodes.clear()
	buildings.clear()
	occupancy.clear()
	next_id = 1
	money = START_MONEY
	_hover_building = -1
	changed.emit()


# --- Géométrie ----------------------------------------------------------------------

## Rectangle de cases occupé par un type posé autour de la case centrale.
static func rect_for(id: String, center: Vector2i, r: int) -> Rect2i:
	var fp := BuildingCatalog.footprint(id, r)
	return Rect2i(center - fp / 2, fp)


## Direction de la façade (porte) pour une rotation : 0 = −Z, puis quarts de tour.
static func front_dir(r: int) -> Vector3:
	return Basis(Vector3.UP, -r * PI / 2.0) * Vector3.FORWARD


static func rect_center(rect: Rect2i) -> Vector3:
	return Vector3(rect.position.x + rect.size.x / 2.0, 0.0, rect.position.y + rect.size.y / 2.0)


## Point juste devant la porte.
static func door_point(id: String, rect: Rect2i, r: int) -> Vector3:
	var t := BuildingCatalog.get_type(id)
	return rect_center(rect) + front_dir(r) * (float(t.d) / 2.0 + 0.5)


# --- Vérification ---------------------------------------------------------------------

## Accès : voie desservante la plus proche de la porte. {} si aucune.
func find_access(id: String, rect: Rect2i, r: int) -> Dictionary:
	if transport == null:
		return {}
	var door := door_point(id, rect, r)
	var best := {}
	for type in BuildingCatalog.get_type(id).get("access", []):
		# "route" ou "chemin" : toute classe de voie de ce mode (rue, avenue…).
		var mode := TransportTypes.mode_of(type)
		for eid in transport.network.edges:
			var e: Dictionary = transport.network.edges[eid]
			if TransportTypes.mode_of(e.t) != mode:
				continue
			var reach := ACCESS_MAX + float(e.get("width", 4.0)) / 2.0
			var hit := transport.network.nearest_on_edge(eid, door)
			if hit.dist <= reach and (best.is_empty() or hit.dist < best.dist):
				best = {"dist": hit.dist, "pos": hit.pos, "type": type, "door": door}
	return best


## Analyse complète d'une pose : {ok, reason, rect, h, cost, access, earth}.
## grown : bâtiment poussé dans une zone (accès toujours exigé, rien à payer).
func check_place(id: String, center: Vector2i, r: int, grown := false) -> Dictionary:
	var t := BuildingCatalog.get_type(id)
	var rect := rect_for(id, center, r)
	var res := {"ok": false, "reason": "", "rect": rect, "h": 0.0, "cost": 0, "access": {}, "earth": 0.0}
	if t.is_empty() or world == null:
		res.reason = "Type de bâtiment inconnu."
		return res
	var lo := INF
	var hi := -INF
	var sum := 0.0
	var n := 0
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			var c := Vector2i(x, z)
			if occupancy.has(c):
				res.reason = "Il y a déjà un bâtiment ici."
				return res
			if transport != null and transport.is_cell_occupied(c):
				res.reason = "Une voie passe sur l'emplacement."
				return res
			var h := world.cell_height(c)
			if is_nan(h):
				res.reason = "Relief encore en chargement."
				return res
			if h < 0.0:
				res.reason = "On ne construit pas dans la mer."
				return res
			lo = minf(lo, h)
			hi = maxf(hi, h)
			sum += h
			n += 1
			# Le biome (10 m de résolution) est lu une case sur trois.
			if x % 3 == 0 and z % 3 == 0 and world.cell_biome(c) == 80:
				res.reason = "On ne construit pas sur un lac ou une rivière."
				return res
	if hi - lo > MAX_RELIEF:
		res.reason = "Terrain trop pentu : %.0f m de dénivelé (maximum %.0f m)." % [hi - lo, MAX_RELIEF]
		return res
	var target := snappedf(sum / n, world.height_step)
	res.h = target
	var earth := 0.0
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			earth += absf(world.cell_height(Vector2i(x, z)) - target)
	res.earth = earth
	res.cost = BuildingCatalog.cost(id) + roundi(earth * EARTH_COST)
	res.access = find_access(id, rect, r)
	if grown:
		res.cost = 0
	if (require_access or grown) and res.access.is_empty():
		var names: Array[String] = []
		for a in t.get("access", []):
			names.append(String(TransportTypes.get_type(a).get("name", a)).to_lower())
		res.reason = "Il faut une %s à moins de %d m de la porte." % [" ou un ".join(names), int(ACCESS_MAX)]
		return res
	if not grown and not unlimited_money and res.cost > money:
		res.reason = "Pas assez d'argent : %s nécessaires." % format_money(res.cost)
		return res
	res.ok = true
	return res


## Rotation automatique : celle dont la porte est la plus proche d'une voie.
func best_rotation(id: String, center: Vector2i) -> int:
	var best_r := rot
	var best_d := INF
	for r in 4:
		var a := find_access(id, rect_for(id, center, r), r)
		if not a.is_empty() and a.dist < best_d - 0.01:
			best_d = a.dist
			best_r = r
	return best_r


# --- Pose et démolition -----------------------------------------------------------------

## Pose un bâtiment centré sur une case. Renvoie son id, ou -1 (raison dans message).
## zone > 0 : le bâtiment pousse dans cette zone (gratuit, sans message).
func place(id: String, center: Vector2i, r: int, zone := 0) -> int:
	var res := check_place(id, center, r, zone > 0)
	if not res.ok:
		if zone == 0:
			message.emit(res.reason)
		return -1
	_terrace(res.rect, res.h)
	if not unlimited_money:
		money -= int(res.cost)
	var bid := next_id
	next_id += 1
	var rect: Rect2i = res.rect
	_add({"id": bid, "t": id, "x": rect.position.x, "z": rect.position.y, "r": r, "h": res.h, "cost": res.cost, "zone": zone})
	if zone == 0:
		message.emit("%s construit pour %s." % [BuildingCatalog.get_type(id).name, format_money(res.cost)])
	changed.emit()
	return bid


func demolish(bid: int) -> void:
	if not buildings.has(bid):
		return
	var b: Dictionary = buildings[bid]
	var rect := _rect_of(b)
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			occupancy.erase(Vector2i(x, z))
	if _nodes.has(bid):
		(_nodes[bid] as Node).queue_free()
		_nodes.erase(bid)
	buildings.erase(bid)
	var back := roundi(float(b.get("cost", 0)) * REFUND)
	if not unlimited_money:
		money += back
	if _hover_building == bid:
		_hover_building = -1
	message.emit("%s démoli (%s rendus)." % [BuildingCatalog.get_type(b.t).get("name", b.t), format_money(back)])
	changed.emit()


func building_at(c: Vector2i) -> int:
	return int(occupancy.get(c, -1))


func _rect_of(b: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(b.x), int(b.z)), BuildingCatalog.footprint(b.t, int(b.r)))


func _add(b: Dictionary) -> void:
	var bid := int(b.id)
	buildings[bid] = b
	var rect := _rect_of(b)
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			occupancy[Vector2i(x, z)] = bid
	var mi := MeshInstance3D.new()
	mi.name = "Batiment_%d" % bid
	mi.mesh = mesh_for(b.t)
	mi.position = rect_center(rect) + Vector3(0, float(b.h), 0)
	mi.rotation.y = -int(b.r) * PI / 2.0
	mi.visibility_range_end = 1400.0
	add_child(mi)
	_nodes[bid] = mi


## Aplanit l'emprise et adoucit un talus autour (sans toucher aux voies ni aux autres bâtiments).
func _terrace(rect: Rect2i, target: float) -> void:
	var cells := {}
	for x in range(rect.position.x - APRON, rect.end.x + APRON):
		for z in range(rect.position.y - APRON, rect.end.y + APRON):
			var c := Vector2i(x, z)
			var inside := rect.has_point(c)
			if inside:
				cells[c] = target
				continue
			if occupancy.has(c) or (transport != null and transport.is_cell_occupied(c)):
				continue
			var h := world.cell_height(c)
			if is_nan(h):
				continue
			var ring := maxi(maxi(rect.position.x - x, x - rect.end.x + 1), maxi(rect.position.y - z, z - rect.end.y + 1))
			var u := float(ring) / float(APRON + 1)
			cells[c] = snappedf(lerpf(target, h, u), world.height_step)
	# Les cases de l'emprise sont toujours enregistrées : pas d'arbres dessous.
	for c in cells:
		world.modifications[c] = cells[c]
	world.mark_cells_dirty(cells.keys())


# --- Souris et clavier ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.NONE or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		_update_cursor((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				set_inactive()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		_update_cursor(mb.position)
		if not _cursor_valid:
			return
		get_viewport().set_input_as_handled()
		if mode == Mode.DEMOLISH:
			if _hover_building >= 0:
				demolish(_hover_building)
				_refresh()
			return
		if place(type_id, _cursor, rot) >= 0:
			_refresh()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			set_inactive()
			get_viewport().set_input_as_handled()
		elif key.physical_keycode == KEY_R and mode == Mode.PLACE:
			rotate_quarter()
			get_viewport().set_input_as_handled()


func _update_cursor(screen: Vector2) -> void:
	var hit: Variant = world.pick_cell(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	var valid := hit != null
	var c: Vector2i = hit if valid else _cursor
	if c == _cursor and valid == _cursor_valid:
		return
	_cursor = c
	_cursor_valid = valid
	_refresh()


## Met à jour l'aperçu, la surbrillance et le texte d'aide.
func _refresh() -> void:
	_ghost.visible = false
	_plate.visible = false
	_link.visible = false
	_set_hover(-1)
	if mode == Mode.DEMOLISH and _cursor_valid:
		_set_hover(building_at(_cursor))
		if _hover_building >= 0:
			var b: Dictionary = buildings[_hover_building]
			info_changed.emit("Démolir %s : clic (%s rendus)" % [BuildingCatalog.get_type(b.t).name, format_money(roundi(float(b.get("cost", 0)) * REFUND))])
		return
	if mode != Mode.PLACE or not _cursor_valid:
		return
	if not manual_rot:
		rot = best_rotation(type_id, _cursor)
	_check = check_place(type_id, _cursor, rot)
	var rect: Rect2i = _check.rect
	var h: float = _check.h
	if h == 0.0:
		h = maxf(world.cell_height(_cursor), 0.0) if not is_nan(world.cell_height(_cursor)) else 0.0
	var center := rect_center(rect)
	_ghost.visible = true
	_ghost.position = center + Vector3(0, h + 0.05, 0)
	_ghost.rotation.y = -rot * PI / 2.0
	_ghost.material_override = _ok_mat if _check.ok else _bad_mat
	_plate.visible = true
	(_plate.mesh as BoxMesh).size = Vector3(rect.size.x + 0.1, 0.4, rect.size.y + 0.1)
	_plate.position = center + Vector3(0, h + 0.05, 0)
	_plate.material_override = _ok_mat if _check.ok else _bad_mat
	var acc: Dictionary = _check.access
	if not acc.is_empty():
		var a: Vector3 = acc.door
		a.y = h + 0.3
		var b: Vector3 = acc.pos
		b.y += 0.3
		var len := Vector2(a.x - b.x, a.z - b.z).length()
		if len > 0.2:
			_link.visible = true
			(_link.mesh as BoxMesh).size = Vector3(0.5, 0.2, len)
			_link.position = (a + b) / 2.0
			_link.look_at(b, Vector3.UP)
	var t := BuildingCatalog.get_type(type_id)
	var txt := "%s (%d × %d m) · %s" % [t.name, t.w, t.d, format_money(int(_check.cost))]
	if _check.earth > 0.0:
		txt += " dont terrassement %s" % format_money(roundi(_check.earth * EARTH_COST))
	txt += " · " + ("desservi par une %s" % String(TransportTypes.get_type(acc.type).name).to_lower() if not acc.is_empty() else "aucune voie à proximité")
	if not _check.ok:
		txt += "\n✗ " + String(_check.reason)
	txt += "\nClic : poser · R : tourner%s · clic droit ou Échap : arrêter" % ("" if manual_rot else " (orientation auto vers la route)")
	info_changed.emit(txt)


func _set_hover(bid: int) -> void:
	if bid == _hover_building:
		return
	if _hover_building >= 0 and _nodes.has(_hover_building):
		(_nodes[_hover_building] as MeshInstance3D).material_overlay = null
	_hover_building = bid
	if bid >= 0 and _nodes.has(bid):
		(_nodes[bid] as MeshInstance3D).material_overlay = _hover_mat


# --- Chiffres ------------------------------------------------------------------------

static func format_money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + " €"


## Prix court pour les listes : « 280 k€ », « 1,5 M€ ».
static func format_short(v: int) -> String:
	if v >= 1_000_000:
		var m := float(v) / 1_000_000.0
		return ("%d M€" % roundi(m)) if m >= 10.0 or is_equal_approx(m, roundf(m)) else ("%.1f M€" % m).replace(".", ",")
	if v >= 1000:
		return "%d k€" % roundi(v / 1000.0)
	return "%d €" % v


## Totaux : logements, emplois, visiteurs, nombre par catégorie.
func totals() -> Dictionary:
	var out := {"logements": 0, "emplois": 0, "visiteurs": 0, "count": buildings.size(), "non_desservis": 0}
	for b in buildings.values():
		var t := BuildingCatalog.get_type(b.t)
		for k in ["logements", "emplois", "visiteurs"]:
			out[k] += int(t.get(k, 0))
		if find_access(b.t, _rect_of(b), int(b.r)).is_empty():
			out.non_desservis += 1
	return out


var _summary := ""
var _summary_dirty := true


func summary() -> String:
	if not _summary_dirty:
		return _summary
	_summary_dirty = false
	var t := totals()
	var s := "Bâtiments : %d   ·   Logements : %d   ·   Emplois : %d" % [t.count, t.logements, t.emplois]
	if t.non_desservis > 0:
		s += "   ·   %d sans accès" % t.non_desservis
	_summary = s
	return s


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var list := []
	for b in buildings.values():
		list.append({"id": b.id, "t": b.t, "x": b.x, "z": b.z, "r": b.r, "h": b.h, "cost": b.get("cost", 0), "zone": b.get("zone", 0)})
	return {"version": 1, "next_id": next_id, "money": money, "require_access": require_access,
		"unlimited_money": unlimited_money, "buildings": list}


func from_dict(data: Dictionary) -> void:
	clear()
	next_id = int(data.get("next_id", 1))
	money = int(data.get("money", START_MONEY))
	require_access = bool(data.get("require_access", true))
	unlimited_money = bool(data.get("unlimited_money", false))
	for b in data.get("buildings", []):
		if BuildingCatalog.get_type(String(b.t)).is_empty():
			continue
		_add({"id": int(b.id), "t": String(b.t), "x": int(b.x), "z": int(b.z), "r": int(b.r),
			"h": float(b.h), "cost": int(b.get("cost", 0)), "zone": int(b.get("zone", 0))})
		next_id = maxi(next_id, int(b.id) + 1)
	changed.emit()
