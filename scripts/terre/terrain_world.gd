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
## Calcule les blocs sur les autres cœurs du processeur (fluidité en se déplaçant).
@export var threaded := true
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
## Occupation du sol réelle (forêt, champs, eau douce, glacier…).
var land: LandCover
## Optionnel : Callable(c: Vector2i) -> bool. Vrai = pas d'arbre sur cette case
## (ex. une route posée sur un terrain plat).
var tree_blocker: Callable
var _tree_mesh: Mesh
var _bush_mesh: Mesh
var _dirty: Dictionary = {}
## Blocs en cours de calcul sur un autre fil : Vector2i -> {job, task}.
var _jobs: Dictionary = {}
var _max_jobs := clampi(OS.get_processor_count() - 1, 1, 6)
## Change à chaque nouvelle région : les calculs lancés avant sont ignorés.
var _generation := 0
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
	land = LandCover.new()
	land.name = "LandCover"
	add_child(land)
	_build_vegetation_meshes()
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
	_generation += 1
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


## Types de case (biomes affichés). L'ordre sert d'indice dans les tables ci-dessous.
enum Kind { MER, LAC, GLACIER, ROCHE, FORET, BROUSSAILLES, PRAIRIE, CHAMPS, DESERT,
	MARAIS, MANGROVE, TOUNDRA, PLAGE, NEIGE, ALPAGE }
const KIND_NAMES: Array[String] = ["Mer", "Lac / rivière", "Glacier", "Roche", "Forêt", "Broussailles",
	"Prairie", "Champs", "Désert", "Marais", "Mangrove", "Toundra", "Plage", "Neige", "Alpage"]
## Probabilité d'un arbre / d'un buisson sur une case, par type.
const TREE_BY_KIND: Array[float] = [0, 0, 0, 0, 0.10, 0.025, 0.004, 0, 0, 0.01, 0.08, 0, 0, 0, 0]
const BUSH_BY_KIND: Array[float] = [0, 0, 0, 0, 0.03, 0.05, 0, 0, 0, 0, 0, 0.02, 0, 0, 0.01]


## Biome d'une case à partir de son altitude, de sa pente et du code WorldCover
## (0 = inconnu : on devine avec l'altitude seule).
static func cell_kind(h: float, slope: float, code := 0) -> String:
	return KIND_NAMES[cell_kind_id(h, slope, code)]


## Raccourci du cas courant (terre ferme, pente douce, altitude moyenne) : code WorldCover -> type.
static var _KIND_BY_CODE: PackedInt32Array = _make_kind_by_code()


static func _make_kind_by_code() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(256)
	out.fill(-1)
	for code in [10, 20, 30, 40, 50, 60, 90, 95, 100]:
		out[code] = cell_kind_id(100.0, 0.0, code)
	return out


static func cell_kind_id(h: float, slope: float, code := 0) -> int:
	if h < 0.0 and (code == 0 or code == 80):
		return Kind.MER
	if code == 80:
		return Kind.LAC
	if code == 70:
		return Kind.GLACIER
	if slope >= 1.0:
		return Kind.ROCHE
	match code:
		10:
			return Kind.FORET
		20:
			return Kind.BROUSSAILLES
		30, 50:
			return Kind.PRAIRIE
		40:
			return Kind.CHAMPS
		60:
			return Kind.ROCHE if h > 1500.0 else Kind.DESERT
		90:
			return Kind.MARAIS
		95:
			return Kind.MANGROVE
		100:
			return Kind.TOUNDRA
	if h < 1.5:
		return Kind.PLAGE
	if h > 2600.0:
		return Kind.NEIGE
	if h > 1900.0:
		return Kind.ALPAGE
	return Kind.PRAIRIE


## Code WorldCover sous le centre d'une case (0 si inconnu).
func cell_biome(c: Vector2i) -> int:
	var ll := local_to_lat_lon(c.x + 0.5, c.y + 0.5)
	return land.class_at(ll.x, ll.y)


## Nom du biome d'une case, prêt à afficher.
func cell_kind_at(c: Vector2i) -> String:
	var h := cell_height(c)
	if is_nan(h):
		return ""
	return cell_kind(h, cell_slope(c), cell_biome(c))


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
				if (not chunks.has(k) or _dirty.has(k)) and not _jobs.has(k):
					wanted.append(k)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chunk_distance(a, center) < _chunk_distance(b, center))

	_collect_jobs()
	var start := Time.get_ticks_usec()
	for k in wanted:
		if threaded and _jobs.size() >= _max_jobs:
			break
		if _jobs.has(k):
			continue
		if _ensure_tiles(k):
			_dirty.erase(k)
			var job := _prepare_chunk(k)
			if threaded:
				_jobs[k] = {"job": job, "task": WorkerThreadPool.add_task(_compute_chunk.bind(job))}
			else:
				_compute_chunk(job)
				_apply_chunk(job)
			if (Time.get_ticks_usec() - start) / 1000.0 > build_budget_ms:
				break

	# Libère les blocs trop loin.
	for k in chunks.keys():
		if _chunk_distance(k, center) > _view_radius + cs * 1.5:
			(chunks[k] as Node).queue_free()
			chunks.erase(k)


## Récupère les blocs calculés par les fils et les pose (dans la limite du budget).
func _collect_jobs() -> void:
	var start := Time.get_ticks_usec()
	for k in _jobs.keys():
		var entry: Dictionary = _jobs[k]
		if not WorkerThreadPool.is_task_completed(entry.task):
			continue
		WorkerThreadPool.wait_for_task_completion(entry.task)
		_jobs.erase(k)
		var job: Dictionary = entry.job
		# Région changée entre-temps : résultat périmé.
		if job.gen == _generation:
			_apply_chunk(job)
		if (Time.get_ticks_usec() - start) / 1000.0 > build_budget_ms:
			break


## Attend la fin de tous les calculs en cours (avant de quitter la scène, ou dans les tests).
func finish_jobs() -> void:
	for k in _jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_jobs[k].task)
		var job: Dictionary = _jobs[k].job
		if job.gen == _generation:
			_apply_chunk(job)
	_jobs.clear()


func _exit_tree() -> void:
	for k in _jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_jobs[k].task)
	_jobs.clear()


## Nombre de blocs visibles pas encore construits (ou à reconstruire).
func missing_chunk_count() -> int:
	var center := _focus.global_position if _focus else Vector3.ZERO
	var cs := float(chunk_size)
	var cc := Vector2i(floori(center.x / cs), floori(center.z / cs))
	var r := ceili(_view_radius / cs)
	var n := 0
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := cc + Vector2i(dx, dz)
			if _chunk_distance(k, center) <= _view_radius and (not chunks.has(k) or _dirty.has(k) or _jobs.has(k)):
				n += 1
	return n


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
	# Occupation du sol aux quatre coins du bloc (un bloc WorldCover fait ~10 km).
	for corner in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		var ll := local_to_lat_lon(corner.x, corner.y)
		if not land.is_ready_at(ll.x, ll.y):
			land.request_at(ll.x, ll.y)
			ready = false
	return ready


## Construit (ou reconstruit) le maillage d'un bloc de chunk_size × chunk_size cases,
## tout de suite (sans passer par les fils de calcul).
func _build_chunk(k: Vector2i) -> void:
	var job := _prepare_chunk(k)
	_compute_chunk(job)
	_apply_chunk(job)


## Fil principal : rassemble ce qu'il faut lire dans les tuiles et les modifications.
func _prepare_chunk(k: Vector2i) -> Dictionary:
	var cs := chunk_size
	var x0 := k.x * cs
	var z0 := k.y * cs
	var w := cs + 2 # une case de marge de chaque côté
	# Grille [-1 .. cs] × [-1 .. cs], indice (i + 1) + (j + 1) * w.
	var pxs := PackedFloat64Array()
	pxs.resize(w)
	var lons := PackedFloat64Array()
	lons.resize(w)
	for i in w:
		pxs[i] = _pixel_x(x0 + i - 1 + 0.5)
		lons[i] = Geo.local_to_lon(origin_lat, origin_lon, x0 + i - 1 + 0.5)
	var pys := PackedFloat64Array()
	pys.resize(w)
	var lats := PackedFloat64Array()
	lats.resize(w)
	for j in w:
		lats[j] = Geo.local_to_lat(origin_lat, z0 + j - 1 + 0.5)
		pys[j] = Geo.lat_to_pixel_y(lats[j], ElevationTiles.ZOOM)
	# Cases modifiées du bloc : indice -> hauteur.
	var mod_idx := PackedInt32Array()
	var mod_h := PackedFloat32Array()
	if not modifications.is_empty():
		var rect := Rect2i(x0 - 1, z0 - 1, w, w)
		if modifications.size() < w * w:
			for c: Vector2i in modifications:
				if rect.has_point(c):
					mod_idx.append((c.x - x0 + 1) + (c.y - z0 + 1) * w)
					mod_h.append(modifications[c])
		else:
			for j in w:
				for i in w:
					var c := Vector2i(x0 + i - 1, z0 + j - 1)
					if modifications.has(c):
						mod_idx.append(i + j * w)
						mod_h.append(modifications[c])
	return {"k": k, "gen": _generation, "cs": cs, "step": height_step,
		"pxs": pxs, "pys": pys, "win": tiles.grab_window(pxs, pys),
		"bio": land.sample_grid(lats, lons), "mod_idx": mod_idx, "mod_h": mod_h}


## Calcul pur du maillage et des positions d'arbres (peut tourner sur un autre fil :
## ne lit que job).
static func _compute_chunk(job: Dictionary) -> void:
	var cs: int = job.cs
	var w := cs + 2
	var step: float = job.step
	var h := ElevationTiles.interpolate_window(job.win, job.pxs, job.pys)
	for n in w * w:
		var v := h[n]
		h[n] = minf(snappedf(v, step), -step) if v < 0.0 else snappedf(v, step)
	var modified := PackedByteArray()
	modified.resize(w * w)
	var mod_idx: PackedInt32Array = job.mod_idx
	var mod_h: PackedFloat32Array = job.mod_h
	for m in mod_idx.size():
		h[mod_idx[m]] = mod_h[m]
		modified[mod_idx[m]] = 1
	var bio: PackedByteArray = job.bio
	# L'eau douce est creusée d'une marche pour dessiner les berges.
	for n in w * w:
		if bio[n] == 80 and h[n] >= 0.0 and modified[n] == 0:
			h[n] -= step

	var colors := PackedColorArray()
	colors.resize(w * w)
	var kinds := PackedByteArray()
	kinds.resize(w * w)
	for j in range(1, w - 1):
		for i in range(1, w - 1):
			var n := i + j * w
			var hc := h[n]
			var s := maxf(maxf(absf(h[n + 1] - hc), absf(h[n - 1] - hc)),
					maxf(absf(h[n + w] - hc), absf(h[n - w] - hc)))
			var code := bio[n]
			var kind: int = _KIND_BY_CODE[code]
			if kind < 0 or hc < 0.0 or s >= 1.0 or hc < 1.5 or hc > 1500.0:
				kind = cell_kind_id(hc, s, code)
			kinds[n] = kind
			if kind == Kind.PRAIRIE:
				colors[n] = _prairie_colors[clampi(floori(hc / 2.0), 0, 200)]
			else:
				colors[n] = _color_for_id(kind, hc)

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
	job.arrays = arrays
	job.h = h
	_compute_vegetation(job, h, kinds, modified)


## Fil principal : crée ou remplace le maillage du bloc.
func _apply_chunk(job: Dictionary) -> void:
	var k: Vector2i = job.k
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, job.arrays)
	var mi: MeshInstance3D = chunks.get(k)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Bloc_%d_%d" % [k.x, k.y]
		mi.position = Vector3(k.x * chunk_size, 0.0, k.y * chunk_size)
		mi.material_override = _material
		add_child(mi)
		chunks[k] = mi
	mi.mesh = mesh
	_plant_vegetation(mi, job)


static func _quad(verts: PackedVector3Array, normals: PackedVector3Array, cols: PackedColorArray,
		idx: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	var base := verts.size()
	verts.push_back(a)
	verts.push_back(b)
	verts.push_back(c)
	verts.push_back(d)
	for _v in 4:
		normals.push_back(n)
		cols.push_back(col)
	idx.push_back(base)
	idx.push_back(base + 1)
	idx.push_back(base + 2)
	idx.push_back(base)
	idx.push_back(base + 2)
	idx.push_back(base + 3)


## Couleurs de base (linéaires) par type de case ; la prairie et la mer varient avec l'altitude.
static var _base_colors: PackedColorArray = _make_base_colors()


static func _make_base_colors() -> PackedColorArray:
	var hexes := ["c9b27c", "4f8fc4", "eef3f8", "8e8a82", "4c8c3c", "8d9a58", "5d9e47", "d2c06a",
		"e6d59c", "6c9a7c", "3b7354", "a9a88a", "e6d59c", "eef3f8", "98a56a"]
	var out := PackedColorArray()
	for x in hexes:
		out.append(Color(x).srgb_to_linear())
	return out


static func _color_for(kind: String, h: float) -> Color:
	var id := KIND_NAMES.find(kind)
	return _color_for_id(id if id >= 0 else Kind.PRAIRIE, h)


## Prairie : plus claire en montant, par paliers de 2 m (0 à 400 m), pour lire le relief.
static var _prairie_colors: PackedColorArray = _make_ramp(Color("5d9e47"), Color("a8b864"), 200, false)
## Fond marin : plus sombre en profondeur, par paliers de 0,5 m (0 à 24 m).
static var _sea_colors: PackedColorArray = _make_ramp(Color("c9b27c"), Color(), 48, true)


static func _make_ramp(from: Color, to: Color, n: int, darken: bool) -> PackedColorArray:
	var out := PackedColorArray()
	for i in n + 1:
		var c := from.darkened(i * 0.5 / 40.0) if darken else from.lerp(to, float(i) / n)
		out.append(c.srgb_to_linear())
	return out


static func _color_for_id(kind: int, h: float) -> Color:
	if kind == Kind.PRAIRIE:
		return _prairie_colors[clampi(floori(h / 2.0), 0, 200)]
	if kind == Kind.MER:
		return _sea_colors[clampi(roundi(-h / 0.5), 0, 48)]
	return _base_colors[kind]


# --- Végétation --------------------------------------------------------------



func _build_vegetation_meshes() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.1
	cone.height = 3.6
	cone.radial_segments = 6
	cone.rings = 1
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.roughness = 1.0
	cone.material = tm
	_tree_mesh = cone
	var bush := SphereMesh.new()
	bush.radius = 0.55
	bush.height = 0.8
	bush.radial_segments = 6
	bush.rings = 3
	bush.material = tm
	_bush_mesh = bush


## Choisit les arbres et buissons low-poly selon le biome, de façon déterministe
## (le même lieu donne toujours la même forêt). Calcul pur, sans lire la scène.
static func _compute_vegetation(job: Dictionary, h: PackedFloat32Array, kinds: PackedByteArray, modified: PackedByteArray) -> void:
	var k: Vector2i = job.k
	var cs: int = job.cs
	var w := cs + 2
	var cells: Array[Vector2i] = []
	var xforms: Array[Transform3D] = []
	var cols: Array[Color] = []
	var is_tree := PackedByteArray()
	var tree_green := Color("2a6a2a")
	var meadow_green := Color("367a30")
	var bush_green := Color("587a33")
	for j in range(1, cs + 1):
		for i in range(1, cs + 1):
			var n := i + j * w
			var kind := kinds[n]
			var td: float = TREE_BY_KIND[kind]
			var bd: float = BUSH_BY_KIND[kind]
			if (td == 0.0 and bd == 0.0) or modified[n] != 0:
				continue
			var c := Vector2i(k.x * cs + i - 1, k.y * cs + j - 1)
			var r := absi(hash(c))
			var u := float(r & 0xffff) / 65535.0
			if u >= td + bd:
				continue
			var jx := float((r >> 16) & 0xff) / 255.0 * 0.6 + 0.2
			var jz := float((r >> 24) & 0x7f) / 127.0 * 0.6 + 0.2
			var sc := 0.7 + float((r >> 8) & 0xff) / 255.0 * 0.6
			var shade := 0.85 + float((r >> 4) & 0x3f) / 63.0 * 0.3
			var basis := Basis(Vector3.UP, float(r & 0xff)).scaled(Vector3(sc, sc, sc))
			cells.append(c)
			if u < td:
				xforms.append(Transform3D(basis, Vector3(i - 1 + jx, h[n] + 1.8 * sc, j - 1 + jz)))
				cols.append((tree_green if kind != Kind.PRAIRIE else meadow_green) * shade)
				is_tree.append(1)
			else:
				xforms.append(Transform3D(basis, Vector3(i - 1 + jx, h[n] + 0.3 * sc, j - 1 + jz)))
				cols.append(bush_green * shade)
				is_tree.append(0)
	job.veg = {"cells": cells, "xforms": xforms, "cols": cols, "tree": is_tree}


## Fil principal : retire la végétation sous les voies (tree_blocker) et la pose.
func _plant_vegetation(mi: MeshInstance3D, job: Dictionary) -> void:
	for child in mi.get_children():
		child.queue_free()
	var veg: Dictionary = job.veg
	var cells: Array[Vector2i] = veg.cells
	var xforms: Array[Transform3D] = veg.xforms
	var cols: Array[Color] = veg.cols
	var is_tree: PackedByteArray = veg.tree
	var trees: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	var bushes: Array[Transform3D] = []
	var bush_cols: Array[Color] = []
	var check := tree_blocker.is_valid()
	for n in cells.size():
		if check and tree_blocker.call(cells[n]):
			continue
		if is_tree[n] == 1:
			trees.append(xforms[n])
			tree_cols.append(cols[n])
		else:
			bushes.append(xforms[n])
			bush_cols.append(cols[n])
	_add_multimesh(mi, _tree_mesh, trees, tree_cols)
	_add_multimesh(mi, _bush_mesh, bushes, bush_cols)


static func _add_multimesh(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D], cols: Array[Color]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for n in xforms.size():
		mm.set_instance_transform(n, xforms[n])
		mm.set_instance_color(n, cols[n])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	parent.add_child(inst)


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
	var p: Variant = pick_point(origin, dir)
	if p == null:
		return null
	return Vector2i(floori((p as Vector3).x), floori((p as Vector3).z))


## Lance un rayon et renvoie le point touché sur le dessus des cases (Vector3) ou null.
func pick_point(origin: Vector3, dir: Vector3) -> Variant:
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
			return Vector3(p.x, top, p.z)
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


## Impose la hauteur de plusieurs cases (terrassement sous une route, par exemple).
## cells : Vector2i -> float. Renvoie le nombre de cases changées.
func set_cells(cells: Dictionary) -> int:
	var count := 0
	for c in cells:
		var h: float = cells[c]
		if cell_height(c) == h:
			continue
		modifications[c] = h
		_mark_dirty_around(c)
		count += 1
	if count > 0:
		terrain_edited.emit(count)
		_update_selection()
	return count


## À appeler quand quelque chose posé sur des cases (ex. des routes) doit
## faire redessiner le terrain et sa végétation.
func mark_cells_dirty(cells: Array) -> void:
	for c in cells:
		_mark_dirty_around(c)


func _mark_dirty_around(c: Vector2i) -> void:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var n: Vector2i = c + Vector2i(dx, dz)
			var k := Vector2i(floori(float(n.x) / chunk_size), floori(float(n.y) / chunk_size))
			if chunks.has(k):
				_dirty[k] = true


# --- Sauvegarde --------------------------------------------------------------

## Données lues par le dernier load_world() (pour les autres systèmes : transports…).
var loaded_data: Dictionary = {}


## extra : données d'autres systèmes à ranger dans la même sauvegarde (ex. {"transport": …}).
func save_world(extra: Dictionary = {}) -> bool:
	var mods := []
	for c in modifications:
		mods.append([c.x, c.y, modifications[c]])
	var data := {"version": 1, "lat": origin_lat, "lon": origin_lon, "modifications": mods}
	data.merge(extra)
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
	loaded_data = data
	set_origin(float(data.lat), float(data.lon))
	for m in data.get("modifications", []):
		modifications[Vector2i(int(m[0]), int(m[1]))] = float(m[2])
	return true
