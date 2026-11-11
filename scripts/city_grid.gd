extends Node3D
## Grille de la ville : stocke le contenu de chaque case (route, zone),
## gère la pose à la souris et fait pousser des bâtiments low-poly
## sur les zones reliées à une route.

signal stats_changed(stats: Dictionary)
signal hovered_cell_changed(cell: Vector2i, valid: bool)

enum Cell { EMPTY, ROAD, RESIDENTIAL, COMMERCIAL, INDUSTRIAL }
enum Tool { ROAD, RESIDENTIAL, COMMERCIAL, INDUSTRIAL, BULLDOZE }

const SAVE_PATH := "user://miniblocs_save.json"
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Distance maximale (en cases) entre une zone et une route pour qu'un bâtiment pousse.
const ROAD_REACH := 2

@export var grid_size: int = 64
@export var camera_path: NodePath
@export var tree_density: float = 0.07
@export var growth_interval: float = 0.35
@export var growth_per_tick: int = 3

var current_tool: Tool = Tool.ROAD

## Vector2i -> Cell
var cells: Dictionary = {}
## Vector2i -> Node3D (visuel de route ou plaque de zone)
var cell_nodes: Dictionary = {}
## Vector2i -> Node3D (bâtiment construit sur une zone)
var buildings: Dictionary = {}
## Vector2i -> Node3D (arbres décoratifs)
var trees: Dictionary = {}

var _camera: Camera3D
var _materials: Dictionary = {}
var _drag_start: Vector2i
var _dragging := false
var _hover := Vector2i(-1, -1)
var _preview: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()
var _growth_timer: Timer

const ZONE_COLORS := {
	Cell.RESIDENTIAL: Color("5fae5a"),
	Cell.COMMERCIAL: Color("4f8fcf"),
	Cell.INDUSTRIAL: Color("cfa640"),
}
const TOOL_COLORS := {
	Tool.ROAD: Color(0.25, 0.25, 0.28, 0.6),
	Tool.RESIDENTIAL: Color(0.3, 0.85, 0.35, 0.45),
	Tool.COMMERCIAL: Color(0.3, 0.6, 1.0, 0.45),
	Tool.INDUSTRIAL: Color(1.0, 0.8, 0.2, 0.45),
	Tool.BULLDOZE: Color(1.0, 0.25, 0.2, 0.45),
}


func _ready() -> void:
	_rng.randomize()
	_camera = get_node(camera_path) as Camera3D
	_build_ground()
	_build_preview()
	_scatter_trees()
	_growth_timer = Timer.new()
	_growth_timer.wait_time = growth_interval
	_growth_timer.autostart = true
	_growth_timer.timeout.connect(_grow_buildings)
	add_child(_growth_timer)
	_emit_stats()


# --- Entrées souris -------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_hover(mb.position)
		if mb.pressed and _in_grid(_hover):
			_dragging = true
			_drag_start = _hover
			_update_preview()
		elif not mb.pressed and _dragging:
			_dragging = false
			_apply_tool(_selection_cells())
			_update_preview()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE and _dragging:
			_dragging = false
			_update_preview()


func _update_hover(screen_pos: Vector2) -> void:
	var cell := _screen_to_cell(screen_pos)
	if cell == _hover:
		return
	_hover = cell
	hovered_cell_changed.emit(cell, _in_grid(cell))
	_update_preview()


func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit == null:
		return Vector2i(-1, -1)
	var p := hit as Vector3
	return Vector2i(floori(p.x), floori(p.z))


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid_size and c.y < grid_size


## Cases concernées par le glisser en cours :
## route = tracé en L, zones et bulldozer = rectangle.
func _selection_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _dragging:
		if _in_grid(_hover):
			result.append(_hover)
		return result
	var a := _drag_start
	var b := Vector2i(clampi(_hover.x, 0, grid_size - 1), clampi(_hover.y, 0, grid_size - 1))
	if current_tool == Tool.ROAD:
		var sx := signi(b.x - a.x)
		var sy := signi(b.y - a.y)
		var x := a.x
		while true:
			result.append(Vector2i(x, a.y))
			if x == b.x:
				break
			x += sx
		var y := a.y
		while y != b.y:
			y += sy
			result.append(Vector2i(b.x, y))
	else:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				result.append(Vector2i(x, y))
	return result


# --- Application des outils ----------------------------------------------

func set_tool(t: Tool) -> void:
	current_tool = t
	_update_preview()


func _apply_tool(selection: Array) -> void:
	var touched: Dictionary = {}
	for c in selection:
		if not _in_grid(c):
			continue
		match current_tool:
			Tool.ROAD:
				_set_cell(c, Cell.ROAD)
			Tool.RESIDENTIAL:
				if get_cell(c) != Cell.ROAD:
					_set_cell(c, Cell.RESIDENTIAL)
			Tool.COMMERCIAL:
				if get_cell(c) != Cell.ROAD:
					_set_cell(c, Cell.COMMERCIAL)
			Tool.INDUSTRIAL:
				if get_cell(c) != Cell.ROAD:
					_set_cell(c, Cell.INDUSTRIAL)
			Tool.BULLDOZE:
				_set_cell(c, Cell.EMPTY)
				_remove_tree(c)
		touched[c] = true
	_refresh_roads_around(touched.keys())
	_emit_stats()


func get_cell(c: Vector2i) -> Cell:
	return cells.get(c, Cell.EMPTY)


func _set_cell(c: Vector2i, type: Cell) -> void:
	var old := get_cell(c)
	if old == type:
		return
	_remove_building(c)
	if cell_nodes.has(c):
		cell_nodes[c].queue_free()
		cell_nodes.erase(c)
	if type == Cell.EMPTY:
		cells.erase(c)
		return
	cells[c] = type
	_remove_tree(c)
	if type != Cell.ROAD:
		var plate := _make_zone_plate(type)
		plate.position = _cell_center(c)
		add_child(plate)
		cell_nodes[c] = plate


func _refresh_roads_around(changed: Array) -> void:
	var to_refresh: Dictionary = {}
	for c in changed:
		to_refresh[c] = true
		for d in DIRS:
			to_refresh[c + d] = true
	for c in to_refresh.keys():
		if get_cell(c) != Cell.ROAD:
			continue
		if cell_nodes.has(c):
			cell_nodes[c].queue_free()
		var road := _make_road(c)
		road.position = _cell_center(c)
		add_child(road)
		cell_nodes[c] = road


func _cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


# --- Croissance des bâtiments --------------------------------------------

func _grow_buildings() -> void:
	var candidates: Array[Vector2i] = []
	for c in cells.keys():
		var t: Cell = cells[c]
		if t == Cell.ROAD or buildings.has(c):
			continue
		if _near_road(c):
			candidates.append(c)
	if candidates.is_empty():
		return
	for i in mini(growth_per_tick, candidates.size()):
		var idx := _rng.randi_range(0, candidates.size() - 1)
		var c: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		_spawn_building(c, cells[c])
	_emit_stats()


func _near_road(c: Vector2i) -> bool:
	for dx in range(-ROAD_REACH, ROAD_REACH + 1):
		for dy in range(-ROAD_REACH, ROAD_REACH + 1):
			if absi(dx) + absi(dy) <= ROAD_REACH and get_cell(c + Vector2i(dx, dy)) == Cell.ROAD:
				return true
	return false


func _spawn_building(c: Vector2i, type: Cell) -> void:
	var b: Node3D
	match type:
		Cell.RESIDENTIAL:
			b = LowPoly.make_house(_rng, _mat_func())
		Cell.COMMERCIAL:
			b = LowPoly.make_shop(_rng, _mat_func())
		_:
			b = LowPoly.make_factory(_rng, _mat_func())
	b.position = _cell_center(c)
	b.rotation.y = _facing_road(c)
	add_child(b)
	buildings[c] = b
	# Petite animation d'apparition.
	b.scale = Vector3(1.0, 0.01, 1.0)
	var tween := create_tween()
	tween.tween_property(b, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Oriente la façade (axe -Z local) vers la route la plus proche.
func _facing_road(c: Vector2i) -> float:
	for r in range(1, ROAD_REACH + 1):
		for d in DIRS:
			if get_cell(c + d * r) == Cell.ROAD:
				return atan2(-d.x, -d.y)
	return 0.0


func _remove_building(c: Vector2i) -> void:
	if buildings.has(c):
		buildings[c].queue_free()
		buildings.erase(c)


# --- Visuels --------------------------------------------------------------

func _mat(color: Color, transparent := false) -> StandardMaterial3D:
	var key := color.to_html() + ("_t" if transparent else "")
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = m
	return m


func _mat_func() -> Callable:
	return func(col: Color) -> StandardMaterial3D: return _mat(col)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid_size, grid_size)
	ground.mesh = plane
	ground.position = Vector3(grid_size / 2.0, 0.0, grid_size / 2.0)
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = preload("res://scripts/ground_grid.gdshader")
	ground.material_override = shader_mat
	add_child(ground)

	# Bordure de terre autour de la carte pour l'effet « maquette ».
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(grid_size + 0.6, 1.5, grid_size + 0.6)
	base.mesh = box
	base.position = Vector3(grid_size / 2.0, -0.76, grid_size / 2.0)
	base.material_override = _mat(Color("8a6a4a"))
	add_child(base)


func _build_preview() -> void:
	_preview = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.96, 0.08, 0.96)
	mm.mesh = box
	_preview.multimesh = mm
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)
	_update_preview()


func _update_preview() -> void:
	if _preview == null:
		return
	var sel := _selection_cells()
	var mm := _preview.multimesh
	mm.instance_count = sel.size()
	for i in sel.size():
		mm.set_instance_transform(i, Transform3D(Basis(), _cell_center(sel[i]) + Vector3(0, 0.12, 0)))
	_preview.material_override = _mat(TOOL_COLORS[current_tool], true)


func _make_zone_plate(type: Cell) -> Node3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.94, 0.04, 0.94)
	mi.mesh = box
	mi.position.y = 0.02
	mi.material_override = _mat(ZONE_COLORS[type])
	var holder := Node3D.new()
	holder.add_child(mi)
	return holder


func _make_road(c: Vector2i) -> Node3D:
	var root := Node3D.new()
	var asphalt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.06, 1.0)
	asphalt.mesh = box
	asphalt.position.y = 0.03
	asphalt.material_override = _mat(Color("4a4d55"))
	root.add_child(asphalt)

	# Marquage central : un trait vers chaque route voisine.
	var connections := 0
	for d in DIRS:
		if get_cell(c + d) != Cell.ROAD:
			continue
		connections += 1
		var line := MeshInstance3D.new()
		var lbox := BoxMesh.new()
		lbox.size = Vector3(0.06 if d.x == 0 else 0.42, 0.01, 0.42 if d.x == 0 else 0.06)
		line.mesh = lbox
		line.position = Vector3(d.x * 0.29, 0.065, d.y * 0.29)
		line.material_override = _mat(Color("f1e7c8"))
		root.add_child(line)
	if connections != 2 or _is_corner(c):
		# Carrefour, virage ou bout de route : petit rond central.
		var dot := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.09
		cyl.height = 0.01
		cyl.radial_segments = 8
		dot.mesh = cyl
		dot.position.y = 0.065
		dot.material_override = _mat(Color("f1e7c8"))
		root.add_child(dot)
	return root


func _is_corner(c: Vector2i) -> bool:
	var h := get_cell(c + Vector2i(1, 0)) == Cell.ROAD or get_cell(c + Vector2i(-1, 0)) == Cell.ROAD
	var v := get_cell(c + Vector2i(0, 1)) == Cell.ROAD or get_cell(c + Vector2i(0, -1)) == Cell.ROAD
	return h and v


func _scatter_trees() -> void:
	for x in grid_size:
		for y in grid_size:
			if _rng.randf() < tree_density:
				var c := Vector2i(x, y)
				var t := LowPoly.make_tree(_rng, _mat_func())
				t.position = _cell_center(c) + Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))
				add_child(t)
				trees[c] = t


func _remove_tree(c: Vector2i) -> void:
	if trees.has(c):
		trees[c].queue_free()
		trees.erase(c)


# --- Statistiques ---------------------------------------------------------

func _emit_stats() -> void:
	var s := {"roads": 0, "res": 0, "com": 0, "ind": 0, "buildings": buildings.size()}
	for t in cells.values():
		match t:
			Cell.ROAD: s.roads += 1
			Cell.RESIDENTIAL: s.res += 1
			Cell.COMMERCIAL: s.com += 1
			Cell.INDUSTRIAL: s.ind += 1
	var pop := 0
	var jobs := 0
	for c in buildings.keys():
		match cells.get(c, Cell.EMPTY):
			Cell.RESIDENTIAL: pop += 4
			Cell.COMMERCIAL: jobs += 3
			Cell.INDUSTRIAL: jobs += 6
	s.population = pop
	s.jobs = jobs
	stats_changed.emit(s)


# --- Sauvegarde -----------------------------------------------------------

func save_city() -> bool:
	var data := {"version": 1, "grid_size": grid_size, "cells": [], "built": []}
	for c in cells.keys():
		data.cells.append([c.x, c.y, cells[c]])
	for c in buildings.keys():
		data.built.append([c.x, c.y])
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


func load_city() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	clear_city()
	var changed: Array = []
	for entry in parsed.get("cells", []):
		var c := Vector2i(int(entry[0]), int(entry[1]))
		_set_cell(c, int(entry[2]) as Cell)
		changed.append(c)
	_refresh_roads_around(changed)
	for entry in parsed.get("built", []):
		var c := Vector2i(int(entry[0]), int(entry[1]))
		if cells.has(c) and cells[c] != Cell.ROAD:
			_spawn_building(c, cells[c])
	_emit_stats()
	return true


func clear_city() -> void:
	for c in cells.keys():
		_set_cell(c, Cell.EMPTY)
	_emit_stats()
