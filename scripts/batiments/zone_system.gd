class_name ZoneSystem
extends Node3D
## Zonage dans le mode Terre : le joueur peint des zones (résidentielle,
## commerciale, industrielle) et des bâtiments y poussent tout seuls, alignés
## le long des routes, selon la demande.
##
## - Une zone est un rectangle de cases : {id, k (type), x, z, w, h}.
## - Les bâtiments qui poussent sont des bâtiments ordinaires du catalogue
##   (BuildingSystem), gratuits pour le joueur, avec accès route obligatoire.
## - Le joueur paie le zonage au m² (sauf argent illimité).
## - Retirer une zone n'enlève pas les bâtiments déjà construits.

signal info_changed(text: String)
signal message(text: String)
signal changed

enum Mode { NONE, PAINT, REMOVE }

const KINDS := {
	"R": {"name": "Résidentielle", "color": Color(0.35, 0.85, 0.35, 0.33),
		"types": {"maison": 6, "villa": 2, "immeuble": 3, "tour_habitation": 1}},
	"C": {"name": "Commerciale", "color": Color(0.3, 0.6, 1.0, 0.33),
		"types": {"boulangerie": 3, "cafe": 3, "superette": 3, "bureaux": 2, "supermarche": 1}},
	"I": {"name": "Industrielle", "color": Color(1.0, 0.8, 0.2, 0.33),
		"types": {"atelier": 4, "entrepot": 3, "usine": 2}},
}
## Archétypes de la bible qui poussent dans chaque type de zone, avec leur poids.
const STYLE_ARCHS := {
	"R": {"maison": 6, "grande_maison": 2, "rangee": 3, "immeuble": 3, "tour": 1},
	"C": {"boutique": 4, "restaurant": 3, "marche": 1, "bureaux": 2, "grand_magasin": 1, "gratte_ciel": 1},
	"I": {"atelier": 4, "entrepot": 3, "usine": 2, "ferme": 1},
}
## Style des nouvelles zones : "" = modèles classiques MiniBlocs, "mix" = tous
## les styles mélangés, sinon un style de Styles.STYLES.
var current_style := ""

## Prix du zonage (€ par m²).
const PRICE_M2 := 2
## Côté maximal d'une zone (m).
const MAX_SIDE := 300
## Secondes entre deux tentatives de croissance.
const GROW_INTERVAL := 0.8
## Habitants par logement.
const PEOPLE_PER_HOME := 2.3

@export var world_path: NodePath
@export var camera_path: NodePath
@export var buildings_path: NodePath

var world: TerrainWorld
var camera: Camera3D
var buildings: BuildingSystem

var mode: Mode = Mode.NONE
var kind := "R"
var growth := true
## id -> {"id", "k", "x", "z", "w", "h"}
var zones: Dictionary = {}
var next_id := 1
var rng := RandomNumberGenerator.new()

var _views: Dictionary = {} # id -> MeshInstance3D
var _dirty_views: Dictionary = {}
var _timer := 0.0
var _turn := 0
var _drag := false
var _drag_start := Vector2i.ZERO
var _cursor := Vector2i.ZERO
var _cursor_valid := false
var _right_press := Vector2.ZERO
var _box: MeshInstance3D
var _mats: Dictionary = {}


func _ready() -> void:
	rng.seed = 1234
	if not world_path.is_empty():
		world = get_node_or_null(world_path) as TerrainWorld
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if not buildings_path.is_empty():
		buildings = get_node_or_null(buildings_path) as BuildingSystem
	if buildings != null:
		buildings.changed.connect(func() -> void:
			for id in zones:
				_dirty_views[id] = true)
	for k in KINDS:
		var m := StandardMaterial3D.new()
		m.albedo_color = KINDS[k].color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[k] = m
	_box = MeshInstance3D.new()
	_box.mesh = BoxMesh.new()
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box.visible = false
	add_child(_box)


# --- Outils -------------------------------------------------------------------------

func set_paint(k: String) -> void:
	mode = Mode.PAINT
	kind = k
	_drag = false
	_update_box()
	info_changed.emit("Zone %s : clic gauche glissé pour peindre un rectangle (%d € le m²) · clic droit ou Échap : arrêter" % [String(KINDS[k].name).to_lower(), PRICE_M2])


func set_remove() -> void:
	mode = Mode.REMOVE
	_drag = false
	_update_box()
	info_changed.emit("Retirer des zones : clic gauche glissé sur les zones à effacer (les bâtiments restent).")


func set_inactive() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	_drag = false
	_update_box()
	info_changed.emit("")


func clear() -> void:
	for v in _views.values():
		(v as Node).queue_free()
	_views.clear()
	_dirty_views.clear()
	zones.clear()
	next_id = 1
	changed.emit()


# --- Zones --------------------------------------------------------------------------

static func zone_rect(z: Dictionary) -> Rect2i:
	return Rect2i(int(z.x), int(z.z), int(z.w), int(z.h))


## Peint une zone sur le rectangle (cases incluses). Renvoie son id ou -1.
func add_zone(k: String, rect: Rect2i) -> int:
	if not KINDS.has(k) or rect.size.x < 1 or rect.size.y < 1:
		return -1
	if rect.size.x > MAX_SIDE or rect.size.y > MAX_SIDE:
		message.emit("Zone trop grande : %d m de côté au maximum." % MAX_SIDE)
		return -1
	# Les zones existantes recouvertes sont retirées de ce rectangle.
	remove_area(rect, false)
	var cost := rect.size.x * rect.size.y * PRICE_M2
	if buildings != null and not buildings.unlimited_money:
		if cost > buildings.money:
			message.emit("Pas assez d'argent pour ce zonage : %s." % BuildingSystem.format_money(cost))
			return -1
		buildings.money -= cost
	var id := next_id
	next_id += 1
	zones[id] = {"id": id, "k": k, "x": rect.position.x, "z": rect.position.y, "w": rect.size.x, "h": rect.size.y, "s": current_style}
	_dirty_views[id] = true
	message.emit("Zone %s de %d × %d m (%s)." % [String(KINDS[k].name).to_lower(), rect.size.x, rect.size.y, BuildingSystem.format_money(cost)])
	changed.emit()
	return id


## Retire les zones sur un rectangle. Une zone coupée en partie est redécoupée.
func remove_area(rect: Rect2i, notify := true) -> int:
	var touched := 0
	for id in zones.keys():
		var z: Dictionary = zones[id]
		var zr := zone_rect(z)
		if not zr.intersects(rect):
			continue
		touched += 1
		_drop_view(id)
		zones.erase(id)
		# Reste de la zone autour du rectangle retiré (jusqu'à 4 morceaux).
		var cut := zr.intersection(rect)
		var parts: Array[Rect2i] = [
			Rect2i(zr.position.x, zr.position.y, zr.size.x, cut.position.y - zr.position.y),
			Rect2i(zr.position.x, cut.end.y, zr.size.x, zr.end.y - cut.end.y),
			Rect2i(zr.position.x, cut.position.y, cut.position.x - zr.position.x, cut.size.y),
			Rect2i(cut.end.x, cut.position.y, zr.end.x - cut.end.x, cut.size.y),
		]
		for p in parts:
			if p.size.x > 0 and p.size.y > 0:
				var nid := next_id
				next_id += 1
				zones[nid] = {"id": nid, "k": z.k, "x": p.position.x, "z": p.position.y, "w": p.size.x, "h": p.size.y, "s": String(z.get("s", ""))}
				_dirty_views[nid] = true
	if notify and touched > 0:
		message.emit("Zonage retiré.")
	if touched > 0:
		changed.emit()
	return touched


func zone_at(c: Vector2i) -> int:
	for id in zones:
		if zone_rect(zones[id]).has_point(c):
			return id
	return -1


# --- Demande et croissance ------------------------------------------------------------

## Demande pour chaque type de zone (positive : des bâtiments peuvent pousser).
func demand() -> Dictionary:
	var homes := 0
	var jobs_c := 0
	var jobs_i := 0
	var jobs_other := 0
	if buildings != null:
		for b in buildings.buildings.values():
			var t := BuildingCatalog.get_type(b.t)
			homes += int(t.get("logements", 0))
			match t.cat:
				"commerce":
					jobs_c += int(t.get("emplois", 0))
				"industrie":
					jobs_i += int(t.get("emplois", 0))
				_:
					jobs_other += int(t.get("emplois", 0))
	var people := homes * PEOPLE_PER_HOME
	var workers := people * 0.5
	var jobs := jobs_c + jobs_i + jobs_other
	# Commerces et industries embauchent selon la population.
	return {
		# Il vient toujours quelques habitants, et davantage s'il y a du travail.
		"R": 50.0 + jobs * 1.8 - workers,
		"C": people * 0.2 - jobs_c,
		"I": people * 0.25 - jobs_i,
	}


func _process(delta: float) -> void:
	for id in _dirty_views.keys():
		_rebuild_view(id)
	_dirty_views.clear()
	if not growth or zones.is_empty() or buildings == null:
		return
	_timer += delta
	if _timer < GROW_INTERVAL:
		return
	_timer = 0.0
	grow_step()


## Une tentative de croissance dans la zone suivante. Renvoie l'id du bâtiment ou -1.
func grow_step() -> int:
	if zones.is_empty() or buildings == null or buildings.transport == null:
		return -1
	var d := demand()
	var ids := zones.keys()
	for n in ids.size():
		_turn = (_turn + 1) % ids.size()
		var z: Dictionary = zones[ids[_turn]]
		if float(d[z.k]) <= 0.0:
			continue
		var bid := _grow_in(z, float(d[z.k]))
		if bid >= 0:
			return bid
	return -1


## Cherche une place le long d'une route de la zone pour un bâtiment de son type.
## need : demande du type de zone ; un gros employeur attend qu'elle suffise.
func _grow_in(z: Dictionary, need := INF) -> int:
	var rect := zone_rect(z)
	var net := buildings.transport.network
	var roads: Array = []
	var grown := rect.grow(14)
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
			continue
		for p in (e.pts as PackedVector3Array):
			if grown.has_point(Vector2i(floori(p.x), floori(p.z))):
				roads.append(eid)
				break
	if roads.is_empty():
		return -1
	var types := types_for(String(z.k), String(z.get("s", "")))
	for attempt in 14:
		var type_id := _pick(types)
		var t := BuildingCatalog.get_type(type_id)
		if z.k != "R" and float(t.get("emplois", 0)) > need * 1.5 + 10.0:
			continue
		var eid: int = roads[rng.randi() % roads.size()]
		var e: Dictionary = net.edges[eid]
		var s := rng.randf() * float(e.len)
		var p := net.point_at(eid, s)
		var tan := net.tangent_at(eid, s)
		var nrm := Vector3(-tan.z, 0.0, tan.x).normalized()
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var hw := float(e.get("width", 7.0)) / 2.0
		var c3 := p + nrm * side * (hw + 2.0 + float(t.d) / 2.0)
		# Façade vers la route : rotation la plus proche de la direction −nrm·side.
		var facing := -nrm * side
		var r := 0
		var best := -2.0
		for k in 4:
			var dot := BuildingSystem.front_dir(k).dot(facing)
			if dot > best:
				best = dot
				r = k
		var center := Vector2i(floori(c3.x), floori(c3.z))
		var brect := BuildingSystem.rect_for(type_id, center, r)
		if not rect.encloses(brect):
			continue
		var bid := buildings.place(type_id, center, r, int(z.id))
		if bid >= 0:
			return bid
	return -1


## Types qui poussent dans une zone de type k avec le style donné (poids).
static func types_for(k: String, style: String) -> Dictionary:
	if style == "" or not STYLE_ARCHS.has(k):
		return KINDS[k].types
	var out := {}
	var archs: Dictionary = STYLE_ARCHS[k]
	var styles: Array = Styles.STYLES.keys() if style == "mix" else [style]
	for sid in styles:
		if not Styles.STYLES.has(sid):
			continue
		for arch in archs:
			var id := "%s__%s" % [sid, arch]
			if BuildingCatalog.all_types().has(id):
				out[id] = int(archs[arch])
	# Un style sans modèle pour ce type de zone : on garde les modèles classiques.
	return out if not out.is_empty() else KINDS[k].types


func _pick(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var x := rng.randi() % total
	for k in weights:
		x -= int(weights[k])
		if x < 0:
			return k
	return weights.keys()[0]


# --- Affichage ----------------------------------------------------------------------

func _drop_view(id: int) -> void:
	if _views.has(id):
		(_views[id] as Node).queue_free()
		_views.erase(id)
	_dirty_views.erase(id)


## Calque coloré posé sur chaque case libre de la zone (suit le relief).
func _rebuild_view(id: int) -> void:
	if not zones.has(id) or world == null:
		return
	var z: Dictionary = zones[id]
	var rect := zone_rect(z)
	var verts := PackedVector3Array()
	for j in range(rect.position.y, rect.end.y):
		var i := rect.position.x
		while i < rect.end.x:
			var c := Vector2i(i, j)
			var h := world.cell_height(c)
			if is_nan(h) or _covered(c):
				i += 1
				continue
			# Cases voisines de même hauteur réunies en une bande.
			var e := i
			while e + 1 < rect.end.x:
				var n := Vector2i(e + 1, j)
				if world.cell_height(n) != h or _covered(n):
					break
				e += 1
			var y := maxf(h, 0.0) + 0.06
			verts.append_array([Vector3(i, y, j), Vector3(e + 1, y, j), Vector3(e + 1, y, j + 1),
				Vector3(i, y, j), Vector3(e + 1, y, j + 1), Vector3(i, y, j + 1)])
			i = e + 1
	var mi: MeshInstance3D = _views.get(id)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_views[id] = mi
	mi.material_override = _mats[z.k]
	if verts.is_empty():
		mi.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = mesh


## Case cachée sous un bâtiment ou une voie : pas de calque dessus.
func _covered(c: Vector2i) -> bool:
	if buildings == null:
		return false
	return buildings.occupancy.has(c) or (buildings.transport != null and buildings.transport.is_cell_occupied(c))


func _update_box() -> void:
	if mode == Mode.NONE or not _cursor_valid:
		_box.visible = false
		return
	var a := _drag_start if _drag else _cursor
	var lo := Vector2i(mini(a.x, _cursor.x), mini(a.y, _cursor.y))
	var hi := Vector2i(maxi(a.x, _cursor.x), maxi(a.y, _cursor.y))
	var size := hi - lo + Vector2i.ONE
	var h := world.cell_height(a)
	if is_nan(h):
		h = 0.0
	_box.visible = true
	(_box.mesh as BoxMesh).size = Vector3(size.x, 0.8, size.y)
	_box.position = Vector3(lo.x + size.x / 2.0, maxf(h, 0.0), lo.y + size.y / 2.0)
	var col: Color = KINDS[kind].color if mode == Mode.PAINT else Color(1, 0.3, 0.25, 0.35)
	var too_big := size.x > MAX_SIDE or size.y > MAX_SIDE
	if too_big:
		col = Color(1, 0.3, 0.25, 0.35)
	var m := BuildingSystem._tint(Color(col.r, col.g, col.b, 0.45))
	_box.material_override = m
	if _drag and mode == Mode.PAINT:
		info_changed.emit("Zone %s : %d × %d m · %s%s" % [String(KINDS[kind].name).to_lower(), size.x, size.y,
			BuildingSystem.format_money(size.x * size.y * PRICE_M2), "  ·  trop grande" if too_big else ""])


# --- Souris -------------------------------------------------------------------------

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
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_cursor(mb.position)
		if mb.pressed and _cursor_valid:
			_drag = true
			_drag_start = _cursor
		elif not mb.pressed and _drag:
			_drag = false
			var lo := Vector2i(mini(_drag_start.x, _cursor.x), mini(_drag_start.y, _cursor.y))
			var hi := Vector2i(maxi(_drag_start.x, _cursor.x), maxi(_drag_start.y, _cursor.y))
			var rect := Rect2i(lo, hi - lo + Vector2i.ONE)
			if mode == Mode.PAINT:
				add_zone(kind, rect)
			else:
				remove_area(rect)
		_update_box()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			if _drag:
				_drag = false
				_update_box()
			else:
				set_inactive()
			get_viewport().set_input_as_handled()


func _update_cursor(screen: Vector2) -> void:
	var hit: Variant = world.pick_cell(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_cursor_valid = hit != null
	if _cursor_valid:
		_cursor = hit
	_update_box()


# --- Sauvegarde ---------------------------------------------------------------------

func summary() -> String:
	var d := demand()
	var area := {"R": 0, "C": 0, "I": 0}
	for z in zones.values():
		area[z.k] += int(z.w) * int(z.h)
	return "Demande  ·  R %s  ·  C %s  ·  I %s\nZones : R %d m²  ·  C %d m²  ·  I %d m²" % [
		_bar(d.R), _bar(d.C), _bar(d.I), area.R, area.C, area.I]


static func _bar(v: float) -> String:
	if v > 50.0:
		return "forte"
	if v > 0.0:
		return "faible"
	return "nulle"


func to_dict() -> Dictionary:
	return {"version": 1, "next_id": next_id, "growth": growth, "zones": zones.values()}


func from_dict(data: Dictionary) -> void:
	clear()
	next_id = int(data.get("next_id", 1))
	growth = bool(data.get("growth", true))
	for z in data.get("zones", []):
		var id := int(z.id)
		if not KINDS.has(String(z.k)):
			continue
		zones[id] = {"id": id, "k": String(z.k), "x": int(z.x), "z": int(z.z), "w": int(z.w), "h": int(z.h), "s": String(z.get("s", ""))}
		_dirty_views[id] = true
		next_id = maxi(next_id, id + 1)
	changed.emit()
