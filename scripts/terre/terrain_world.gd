class_name TerrainWorld
extends Node3D
## Terrain réel en cases de 1 m × 1 m, généré à la demande autour de la caméra.
##
## La Terre fait environ 510 000 milliards de m² : impossible de tout stocker.
## On ne garde donc que :
##  - les tuiles d'altitude réelles téléchargées (cache disque, ~80 Ko chacune) ;
##  - les cases modifiées par le joueur (dictionnaire creux).
## Tout le reste est recalculé à la volée, par blocs (« chunks ») de 64 × 64 cases
## chargés autour de la caméra et libérés quand elle s'éloigne.

signal origin_changed(lat: float, lon: float)
signal hovered_cell_changed(cell: Vector2i, valid: bool)
signal terrain_edited(count: int)

enum Tool { INSPECT, FLATTEN, RAISE, LOWER }

const SAVE_PATH := "user://terre_save.json"
const WATER_LEVEL := -0.1

@export var chunk_size: int = 64
## Les hauteurs sont arrondies à ce pas : crée des plateaux plats constructibles
## et des marches nettes, façon blocs.
@export var height_step: float = 0.5
@export var min_view_radius: float = 160.0
@export var max_view_radius: float = 460.0
## Temps maximum consacré à fabriquer des blocs à chaque image (ms).
@export var build_budget_ms: float = 6.0
@export var camera_path: NodePath
@export var focus_path: NodePath

var origin_lat := 48.8584
var origin_lon := 2.2945
var current_tool: Tool = Tool.INSPECT
## Vector2i -> float : hauteur imposée par le joueur.
var modifications: Dictionary = {}
## Vector2i (indice de bloc) -> MeshInstance3D
var chunks: Dictionary = {}

var tiles: ElevationTiles
var _dirty: Dictionary = {}
var _material: ShaderMaterial
var _water: MeshInstance3D
var _selection: MeshInstance3D
var _camera: Camera3D
var _focus: Node3D
var _hover := Vector2i.ZERO
var _hover_valid := false
var _drag_start := Vector2i.ZERO
var _dragging := false
var _view_radius := 200.0
# Conversion mètres locaux -> pixels globaux, mise à jour à chaque changement d'origine.
var _px0 := 0.0
var _px_per_m := 0.0


func _ready() -> void:
	tiles = ElevationTiles.new()
	tiles.name = "ElevationTiles"
	add_child(tiles)
	if not camera_path.is_empty():
		_camera = get_node(camera_path) as Camera3D
	if not focus_path.is_empty():
		_focus = get_node(focus_path) as Node3D

	_material = ShaderMaterial.new()
	_material.shader = preload("res://scripts/terre/terrain.gdshader")

	_water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (max_view_radius * 2.0 + 256.0)
	_water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.22, 0.5, 0.78, 0.78)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.15
	wm.metallic_specular = 0.7
	_water.material_override = wm
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.position.y = WATER_LEVEL
	add_child(_water)

	_selection = MeshInstance3D.new()
	_selection.mesh = BoxMesh.new()
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1.0, 0.92, 0.3, 0.4)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.no_depth_test = false
	_selection.material_override = sm
	_selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection.visible = false
	add_child(_selection)

	set_origin(origin_lat, origin_lon)


# --- Origine et coordonnées ---------------------------------------------

## Choisit le point du globe au centre de la région jouable (case 0, 0).
func set_origin(lat: float, lon: float) -> void:
	origin_lat = lat
	origin_lon = lon
	for c in chunks.values():
		(c as Node).queue_free()
	chunks.clear()
	_dirty.clear()
	modifications.clear()
	_dragging = false
	var z := ElevationTiles.ZOOM
	_px0 = Geo.lon_to_pixel_x(lon, z)
	_px_per_m = Geo.lon_to_pixel_x(Geo.local_to_lon(lat, lon, 1000.0), z) - _px0
	_px_per_m /= 1000.0
	origin_changed.emit(lat, lon)


func local_to_lat_lon(x: float, z: float) -> Vector2:
	return Vector2(Geo.local_to_lat(origin_lat, z), Geo.local_to_lon(origin_lat, origin_lon, x))


func _pixel_x(x: float) -> float:
	return _px0 + x * _px_per_m


func _pixel_y(z: float) -> float:
	return Geo.lat_to_pixel_y(Geo.local_to_lat(origin_lat, z), ElevationTiles.ZOOM)


## Altitude réelle (non arrondie) au point local (x, z) en mètres. NAN si pas encore chargée.
func raw_height(x: float, z: float) -> float:
	return tiles.height_at(_pixel_x(x), _pixel_y(z))


func _quantize(h: float) -> float:
	if h < 0.0:
		return minf(snappedf(h, height_step), -height_step)
	return snappedf(h, height_step)


## Hauteur affichée d'une case (arrondie, avec les modifications du joueur).
func cell_height(c: Vector2i) -> float:
	if modifications.has(c):
		return modifications[c]
	var h := raw_height(c.x + 0.5, c.y + 0.5)
	if is_nan(h):
		return NAN
	return _quantize(h)


static func cell_kind(h: float, slope: float) -> String:
	if h < 0.0:
		return "Mer"
	if h < 1.5:
		return "Plage"
	if slope >= 1.0:
		return "Roche"
	if h > 2600.0:
		return "Neige"
	if h > 1900.0:
		return "Alpage"
	return "Herbe"


func cell_slope(c: Vector2i) -> float:
	var h := cell_height(c)
	var s := 0.0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := cell_height(c + d)
		if not is_nan(n):
			s = maxf(s, absf(n - h))
	return s


# --- Chargement des blocs autour de la caméra -----------------------------

func _process(_delta: float) -> void:
	var center := Vector3.ZERO
	if _focus:
		center = _focus.global_position
	if _camera:
		var cam_dist := _camera.global_position.distance_to(center)
		_view_radius = clampf(cam_dist * 2.4, min_view_radius, max_view_radius)
	var cs := float(chunk_size)
	_water.position.x = snappedf(center.x, cs)
	_water.position.z = snappedf(center.z, cs)

	var cc := Vector2i(floori(center.x / cs), floori(center.z / cs))
	var r := ceili(_view_radius / cs)
	var wanted: Array[Vector2i] = []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := cc + Vector2i(dx, dz)
			if _chunk_distance(k, center) <= _view_radius:
				if not chunks.has(k) or _dirty.has(k):
					wanted.append(k)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chunk_distance(a, center) < _chunk_distance(b, center))

	var start := Time.get_ticks_usec()
	for k in wanted:
		if _ensure_tiles(k):
			_build_chunk(k)
			if (Time.get_ticks_usec() - start) / 1000.0 > build_budget_ms:
				break

	# Libère les blocs trop loin.
	for k in chunks.keys():
		if _chunk_distance(k, center) > _view_radius + cs * 1.5:
			(chunks[k] as Node).queue_free()
			chunks.erase(k)


func _chunk_distance(k: Vector2i, center: Vector3) -> float:
	var cs := float(chunk_size)
	var mid := Vector2((k.x + 0.5) * cs, (k.y + 0.5) * cs)
	return maxf(0.0, mid.distance_to(Vector2(center.x, center.z)) - cs * 0.7)


## Vrai si toutes les tuiles nécessaires au bloc sont là ; sinon les demande.
func _ensure_tiles(k: Vector2i) -> bool:
	var x0 := k.x * chunk_size - 2.0
	var x1 := (k.x + 1) * chunk_size + 2.0
	var z0 := k.y * chunk_size - 2.0
	var z1 := (k.y + 1) * chunk_size + 2.0
	var t0 := ElevationTiles.tile_of_pixel(_pixel_x(x0) - 1.0, _pixel_y(z0) - 1.0)
	var t1 := ElevationTiles.tile_of_pixel(_pixel_x(x1) + 1.0, _pixel_y(z1) + 1.0)
	var ready := true
	for tx in range(t0.x, t1.x + 1):
		for ty in range(t0.y, t1.y + 1):
			var t := Vector2i(tx, ty)
			if not tiles.has_tile(t):
				tiles.request_tile(t)
				if not tiles.has_tile(t):
					ready = false
	return ready


## Construit (ou reconstruit) le maillage d'un bloc de chunk_size × chunk_size cases.
func _build_chunk(k: Vector2i) -> void:
	var cs := chunk_size
	var x0 := k.x * cs
	var z0 := k.y * cs
	var w := cs + 2 # une case de marge de chaque côté
	# Hauteurs de la grille [-1 .. cs] × [-1 .. cs], indice (i + 1) + (j + 1) * w.
	var h := PackedFloat32Array()
	h.resize(w * w)
	var pxs := PackedFloat64Array()
	pxs.resize(w)
	for i in w:
		pxs[i] = _pixel_x(x0 + i - 1 + 0.5)
	for j in w:
		var py := _pixel_y(z0 + j - 1 + 0.5)
		for i in w:
			var c := Vector2i(x0 + i - 1, z0 + j - 1)
			if modifications.has(c):
				h[i + j * w] = modifications[c]
			else:
				h[i + j * w] = _quantize(tiles.height_at(pxs[i], py))

	var colors := PackedColorArray()
	colors.resize(w * w)
	for j in range(1, w - 1):
		for i in range(1, w - 1):
			var hc := h[i + j * w]
			var s := maxf(maxf(absf(h[i + 1 + j * w] - hc), absf(h[i - 1 + j * w] - hc)),
					maxf(absf(h[i + (j + 1) * w] - hc), absf(h[i + (j - 1) * w] - hc)))
			colors[i + j * w] = _color_for(hc, s)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	# Dessus des cases : les cases voisines identiques d'une même ligne sont fusionnées.
	for j in range(1, cs + 1):
		var i := 1
		while i <= cs:
			var hv := h[i + j * w]
			var col := colors[i + j * w]
			var e := i
			while e + 1 <= cs and h[e + 1 + j * w] == hv and colors[e + 1 + j * w] == col:
				e += 1
			_quad(verts, normals, cols, idx,
				Vector3(i - 1, hv, j - 1), Vector3(e, hv, j - 1),
				Vector3(e, hv, j), Vector3(i - 1, hv, j), Vector3.UP, col)
			i = e + 1

	# Murs entre une case et sa voisine Est (i+1) : orientés vers la case la plus basse.
	for j in range(1, cs + 1):
		for i in range(1, cs + 1):
			var a := h[i + j * w]
			var b := h[i + 1 + j * w]
			if a == b:
				continue
			var x := float(i)
			var lo := minf(a, b)
			var hi := maxf(a, b)
			var col := (colors[i + j * w] if a > b else colors[i + 1 + j * w]).darkened(0.12)
			var n := Vector3.RIGHT if a > b else Vector3.LEFT
			_quad(verts, normals, cols, idx,
				Vector3(x, hi, j - 1), Vector3(x, hi, j), Vector3(x, lo, j), Vector3(x, lo, j - 1), n, col)

	# Murs entre une case et sa voisine Sud (j+1), fusionnés le long de la ligne.
	for j in range(1, cs + 1):
		var i := 1
		while i <= cs:
			var a := h[i + j * w]
			var b := h[i + (j + 1) * w]
			if a == b:
				i += 1
				continue
			var e := i
			while e + 1 <= cs and h[e + 1 + j * w] == a and h[e + 1 + (j + 1) * w] == b:
				e += 1
			var z := float(j)
			var lo := minf(a, b)
			var hi := maxf(a, b)
			var col := (colors[i + j * w] if a > b else colors[i + (j + 1) * w]).darkened(0.12)
			var n := Vector3.BACK if a > b else Vector3.FORWARD
			_quad(verts, normals, cols, idx,
				Vector3(i - 1, hi, z), Vector3(e, hi, z), Vector3(e, lo, z), Vector3(i - 1, lo, z), n, col)
			i = e + 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi: MeshInstance3D = chunks.get(k)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Bloc_%d_%d" % [k.x, k.y]
		mi.position = Vector3(x0, 0.0, z0)
		mi.material_override = _material
		add_child(mi)
		chunks[k] = mi
	mi.mesh = mesh
	_dirty.erase(k)


static func _quad(verts: PackedVector3Array, normals: PackedVector3Array, cols: PackedColorArray,
		idx: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	var base := verts.size()
	verts.append_array([a, b, c, d])
	normals.append_array([n, n, n, n])
	cols.append_array([col, col, col, col])
	idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


static func _color_for(h: float, slope: float) -> Color:
	var c: Color
	match cell_kind(h, slope):
		"Mer":
			c = Color("c9b27c").darkened(clampf(-h / 40.0, 0.0, 0.6))
		"Plage":
			c = Color("e6d59c")
		"Roche":
			c = Color("8e8a82")
		"Neige":
			c = Color("f1f3f6")
		"Alpage":
			c = Color("98a56a")
		_:
			# Herbe : plus claire en montant, par paliers de 2 m, pour lire le relief.
			var t := clampf(floorf(h / 2.0) * 2.0 / 400.0, 0.0, 1.0)
			c = Color("4f8f3c").lerp(Color("a8b864"), t)
	# Le shader travaille en couleurs linéaires.
	return c.srgb_to_linear()


# --- Souris et outils ------------------------------------------------------

func set_tool(t: Tool) -> void:
	current_tool = t
	_dragging = false
	_update_selection()


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_hover(mb.position)
		if mb.pressed and _hover_valid and current_tool != Tool.INSPECT:
			_dragging = true
			_drag_start = _hover
		elif not mb.pressed and _dragging:
			_dragging = false
			apply_tool(_drag_start, _hover)
		_update_selection()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE and _dragging:
			_dragging = false
			_update_selection()


func _update_hover(screen_pos: Vector2) -> void:
	var hit: Variant = pick_cell(_camera.project_ray_origin(screen_pos), _camera.project_ray_normal(screen_pos))
	var valid := hit != null
	var cell: Vector2i = hit if valid else _hover
	if cell != _hover or valid != _hover_valid:
		_hover = cell
		_hover_valid = valid
		hovered_cell_changed.emit(cell, valid)
		_update_selection()


## Lance un rayon et renvoie la case touchée (Vector2i) ou null.
func pick_cell(origin: Vector3, dir: Vector3) -> Variant:
	var t := 0.0
	var max_t := _view_radius * 3.0 + 400.0
	while t < max_t:
		var p := origin + dir * t
		var c := Vector2i(floori(p.x), floori(p.z))
		var h := cell_height(c)
		if is_nan(h):
			h = -1.0e6
		var top := maxf(h, WATER_LEVEL)
		if p.y <= top:
			return c
		t += clampf((p.y - top) * 0.5, 0.15, 25.0)
	return null


func _selection_rect() -> Rect2i:
	var a := _drag_start if _dragging else _hover
	var b := _hover
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _update_selection() -> void:
	if not _hover_valid:
		_selection.visible = false
		return
	var r := _selection_rect()
	var ref := _drag_start if _dragging else _hover
	var h := cell_height(ref)
	if is_nan(h):
		_selection.visible = false
		return
	_selection.visible = true
	var top := maxf(h, WATER_LEVEL)
	(_selection.mesh as BoxMesh).size = Vector3(r.size.x + 0.04, 0.6, r.size.y + 0.04)
	_selection.position = Vector3(r.position.x + r.size.x / 2.0, top, r.position.y + r.size.y / 2.0)


## Applique l'outil courant sur le rectangle de cases a..b (inclus).
func apply_tool(a: Vector2i, b: Vector2i) -> int:
	if current_tool == Tool.INSPECT:
		return 0
	var ref_h := cell_height(a)
	if is_nan(ref_h):
		return 0
	var count := 0
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for z in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			var c := Vector2i(x, z)
			var h := cell_height(c)
			if is_nan(h):
				continue
			match current_tool:
				Tool.FLATTEN:
					h = ref_h
				Tool.RAISE:
					h += 1.0
				Tool.LOWER:
					h -= 1.0
			modifications[c] = h
			count += 1
			_mark_dirty_around(c)
	terrain_edited.emit(count)
	_update_selection()
	return count


func _mark_dirty_around(c: Vector2i) -> void:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var n: Vector2i = c + Vector2i(dx, dz)
			var k := Vector2i(floori(float(n.x) / chunk_size), floori(float(n.y) / chunk_size))
			if chunks.has(k):
				_dirty[k] = true


# --- Sauvegarde --------------------------------------------------------------

func save_world() -> bool:
	var mods := []
	for c in modifications:
		mods.append([c.x, c.y, modifications[c]])
	var data := {"version": 1, "lat": origin_lat, "lon": origin_lon, "modifications": mods}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


func load_world() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	set_origin(float(data.lat), float(data.lon))
	for m in data.get("modifications", []):
		modifications[Vector2i(int(m[0]), int(m[1]))] = float(m[2])
	return true
