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
## Un bloc d'affichage vient d'être (re)construit : son relief a pu changer.
signal chunk_rebuilt(k: Vector2i)

enum Tool { INSPECT, FLATTEN, RAISE, LOWER,
	## Outils de paysage (pinceau rond de rayon brush_radius).
	HILL, SMOOTH, DIG_WATER, FILL_WATER, BIOME, PLANT, CLEAR_TREES }
## Outils qui peignent avec un pinceau rond en glissant (les autres : rectangle).
const BRUSH_TOOLS := [Tool.HILL, Tool.SMOOTH, Tool.DIG_WATER, Tool.FILL_WATER, Tool.BIOME, Tool.PLANT, Tool.CLEAR_TREES]
## Biomes que le joueur peut peindre.
const PAINTABLE_KINDS := [4, 6, 7, 5, 8, 12, 3, 13, 9, 11] # forêt, prairie, champs, broussailles, désert, plage, roche, neige, marais, toundra

## Fichier de save_world() / load_world() (ancien format, gardé pour les tests).
## Les parties du joueur passent par SaveGame (user://parties/).
const SAVE_PATH := "user://test_terre_save.json"
const WATER_LEVEL := -0.1
## La surface des rivières et des lacs est un peu sous le haut des berges.
const WATER_SURFACE_DROP := 0.15

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
## Textures du sol (herbe, roche, sable, champs…), voir Sols.gd.
@export var textures_sol := true
@export var camera_path: NodePath
@export var focus_path: NodePath

var origin_lat := 48.8584
var origin_lon := 2.2945
var current_tool: Tool = Tool.INSPECT
## Vector2i -> float : hauteur imposée par le joueur.
var modifications: Dictionary = {}
## Vector2i -> float : surface de l'eau d'un lac ou d'un canal creusé par le joueur.
var water_cells: Dictionary = {}
## Vector2i -> float (indice Kind) : biome peint par le joueur.
var biome_paint: Dictionary = {}
## Vector2i -> float : 1 = arbre planté, 0 = arbres arrachés.
var tree_paint: Dictionary = {}
## Rayon du pinceau des outils de paysage (cases).
var brush_radius := 3
## Biome posé par l'outil BIOME (indice Kind).
var paint_kind := 4
## Hauteur ajoutée au centre d'un coup de pinceau « colline » (m).
var hill_height := 1.5
var _stroke_level := NAN
var _last_brush := Vector2i(1 << 30, 0)
## Vector2i (indice de bloc) -> MeshInstance3D
var chunks: Dictionary = {}

var tiles: ElevationTiles
## Occupation du sol réelle (forêt, champs, eau douce, glacier…).
var land: LandCover
## Rivières et ruisseaux (OpenStreetMap ou calculés depuis le relief).
var water: WaterMap
## Relief lointain simplifié, au-delà des blocs détaillés (voir HorizonTerrain).
var horizon: HorizonTerrain
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
var _water_material: ShaderMaterial
var _surf_material: ShaderMaterial
## Plus haute mer possible au lieu de la partie (m), voir Maree.
var _tide_max := 0.0
var _selection: MeshInstance3D
var _camera: Camera3D
var _focus: Node3D
var _hover := Vector2i.ZERO
var _hover_valid := false
var _drag_start := Vector2i.ZERO
var _dragging := false
var _view_radius := 200.0
## Rayon d'affichage imposé (m), par ex. en vue au sol. 0 = selon la distance de la caméra.
var view_radius_override := 0.0
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
	water = WaterMap.new()
	water.name = "WaterMap"
	add_child(water)
	water.water_changed.connect(_on_water_changed)
	_build_vegetation_meshes()
	if not camera_path.is_empty():
		_camera = get_node(camera_path) as Camera3D
	if not focus_path.is_empty():
		_focus = get_node(focus_path) as Node3D

	_material = ShaderMaterial.new()
	_material.shader = preload("res://scripts/terre/terrain.gdshader")
	_material.set_shader_parameter("sols", Sols.texture())
	_material.set_shader_parameter("avec_textures", textures_sol)
	_material.set_shader_parameter("premiere_couleur", Sols.PREMIERE_COULEUR)

	_water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (max_view_radius * 2.0 + 256.0)
	# Assez de sommets pour la houle (un tous les ~12 m).
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	_water.mesh = plane
	var water_shader := preload("res://scripts/terre/water.gdshader")
	var wm := ShaderMaterial.new()
	wm.shader = water_shader
	wm.set_shader_parameter("foam_amount", 0.0)
	wm.set_shader_parameter("fixed_depth", 1.0)
	wm.set_shader_parameter("wave_scale", 0.6)
	wm.set_shader_parameter("wave_height", 0.12)
	_water.material_override = wm
	_surf_material = ShaderMaterial.new()
	_surf_material.shader = water_shader
	_surf_material.set_shader_parameter("surf_only", true)
	_surf_material.render_priority = 1
	_water_material = ShaderMaterial.new()
	_water_material.shader = water_shader
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

	horizon = HorizonTerrain.new()
	horizon.name = "Horizon"
	horizon.world = self
	add_child(horizon)

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
	water_cells.clear()
	biome_paint.clear()
	tree_paint.clear()
	_dragging = false
	var z := ElevationTiles.ZOOM
	_px0 = Geo.lon_to_pixel_x(lon, z)
	_px_per_m = Geo.lon_to_pixel_x(Geo.local_to_lon(lat, lon, 1000.0), z) - _px0
	_px_per_m /= 1000.0
	_tide_max = Maree.max_level(lat, lon)
	Maree.high_water = _tide_max
	if water:
		# Relief synthétique (tests) : pas de vraies rivières par-dessus.
		water.offline = tiles.offline_generator.is_valid()
		water.set_origin(lat, lon)
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


## Hauteur affichée d'une case (arrondie, avec les modifications du joueur et
## le lit creusé des rivières).
func cell_height(c: Vector2i) -> float:
	if modifications.has(c):
		return modifications[c]
	var h := raw_height(c.x + 0.5, c.y + 0.5)
	if is_nan(h):
		return NAN
	var q := _quantize(h)
	return q - water_depth(q, cell_biome(c), water.width_at(c.x + 0.5, c.y + 0.5), height_step)


## Hauteur d'une case sans le creusement des rivières.
func _bank_height(c: Vector2i) -> float:
	if water_cells.has(c):
		return float(water_cells[c]) + WATER_SURFACE_DROP
	if modifications.has(c):
		return modifications[c]
	var h := raw_height(c.x + 0.5, c.y + 0.5)
	return NAN if is_nan(h) else _quantize(h)


## Profondeur du lit creusé sous la hauteur arrondie q (0 = pas d'eau douce).
## width : largeur du cours d'eau (WaterMap.width_at), bio : code WorldCover.
static func water_depth(q: float, bio: int, width: float, step: float) -> float:
	if q < 0.0:
		return 0.0 # la mer est gérée à part
	if width >= WaterMap.POND_WIDTH or bio == 80:
		return step
	if width > 0.0:
		return step * (1.0 if width < 3.0 else 2.0)
	return 0.0


## Hauteur actuelle de la surface de la mer (marée comprise).
func sea_level() -> float:
	return WATER_LEVEL + Maree.level


## Fait monter ou descendre la mer selon l'heure du jeu (unix, UTC).
func update_tide(unix: float) -> void:
	var l := Maree.level_at(unix, origin_lat, origin_lon)
	if is_equal_approx(l, Maree.level) and _water.position.y == WATER_LEVEL + l:
		return
	Maree.level = l
	_water.position.y = WATER_LEVEL + l
	_surf_material.set_shader_parameter("tide", l)


## Hauteur de la surface de l'eau douce (rivière, ruisseau, lac) sur la case
## qui contient (x, z), ou NAN s'il n'y en a pas. La mer n'est pas comptée.
func water_surface_at(x: float, z: float) -> float:
	var c := Vector2i(floori(x), floori(z))
	if water_cells.has(c):
		return water_cells[c]
	if modifications.has(c):
		return NAN
	var h := raw_height(c.x + 0.5, c.y + 0.5)
	if is_nan(h):
		return NAN
	var q := _quantize(h)
	if water_depth(q, cell_biome(c), water.width_at(c.x + 0.5, c.y + 0.5), height_step) == 0.0:
		return NAN
	return q - WATER_SURFACE_DROP


## Nom du cours d'eau ou du lac sur une case (OpenStreetMap), ou "".
func water_name_at(c: Vector2i) -> String:
	return water.name_at(c.x + 0.5, c.y + 0.5)


func _on_water_changed() -> void:
	for k in chunks:
		_dirty[k] = true


## Types de case (biomes affichés). L'ordre sert d'indice dans les tables ci-dessous.
enum Kind { MER, LAC, GLACIER, ROCHE, FORET, BROUSSAILLES, PRAIRIE, CHAMPS, DESERT,
	MARAIS, MANGROVE, TOUNDRA, PLAGE, NEIGE, ALPAGE, RIVIERE, RUISSEAU, ETANG, CANAL }
const KIND_NAMES: Array[String] = ["Mer", "Lac / rivière", "Glacier", "Roche", "Forêt", "Broussailles",
	"Prairie", "Champs", "Désert", "Marais", "Mangrove", "Toundra", "Plage", "Neige", "Alpage",
	"Rivière", "Ruisseau", "Étang", "Lac / canal"]
## La végétation de chaque biome est décrite dans Plantes.gd.
## Plages : altitude maximale (m) et biomes qui deviennent du sable au bord de la mer
## (broussailles, prairie, champs, désert, toundra, plage).
const BEACH_MAX := 2.5
const BEACH_KINDS := (1 << 5) | (1 << 6) | (1 << 7) | (1 << 8) | (1 << 11) | (1 << 12)


## Hauteurs affichées (comme cell_height) de toutes les cases d'un rectangle,
## rangées (x - rect.x) + (z - rect.y) * rect.size.x. Bien plus rapide case par case.
func cell_heights(rect: Rect2i) -> PackedFloat32Array:
	var pxs := PackedFloat64Array()
	pxs.resize(rect.size.x)
	for i in rect.size.x:
		pxs[i] = _pixel_x(rect.position.x + i + 0.5)
	var pys := PackedFloat64Array()
	pys.resize(rect.size.y)
	for j in rect.size.y:
		pys[j] = _pixel_y(rect.position.y + j + 0.5)
	var h := tiles.sample_grid(pxs, pys)
	for n in h.size():
		h[n] = _quantize(h[n])
	_carve_rect(rect, h)
	if not modifications.is_empty():
		var w := rect.size.x
		if modifications.size() < h.size():
			for c: Vector2i in modifications:
				if rect.has_point(c):
					h[(c.x - rect.position.x) + (c.y - rect.position.y) * w] = modifications[c]
		else:
			for j in rect.size.y:
				for i in w:
					var c := rect.position + Vector2i(i, j)
					if modifications.has(c):
						h[i + j * w] = modifications[c]
	return h


## Creuse le lit des rivières et des lacs dans une grille de hauteurs arrondies.
func _carve_rect(rect: Rect2i, h: PackedFloat32Array) -> void:
	var lats := PackedFloat64Array()
	lats.resize(rect.size.y)
	for j in rect.size.y:
		lats[j] = Geo.local_to_lat(origin_lat, rect.position.y + j + 0.5)
	var lons := PackedFloat64Array()
	lons.resize(rect.size.x)
	for i in rect.size.x:
		lons[i] = Geo.local_to_lon(origin_lat, origin_lon, rect.position.x + i + 0.5)
	var bio := land.sample_grid(lats, lons)
	var any := water.any_in_rect(rect.position.x, rect.position.y, rect.end.x, rect.end.y)
	var w := rect.size.x
	for n in h.size():
		var width := 0.0
		if any:
			width = water.width_at(rect.position.x + n % w + 0.5, rect.position.y + n / w + 0.5)
		h[n] -= water_depth(h[n], bio[n], width, height_step)


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
	if water_cells.has(c):
		return KIND_NAMES[Kind.CANAL]
	if biome_paint.has(c):
		return KIND_NAMES[int(biome_paint[c])]
	var bio := cell_biome(c)
	if h >= 0.0 and h <= BEACH_MAX and not water_cells.has(c) and (BEACH_KINDS >> cell_kind_id(h, 0.0, bio)) & 1 == 1:
		var near_sea := h <= 1.0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			near_sea = near_sea or cell_height(c + d) < 0.0
		if near_sea and cell_slope(c) < 2.0:
			return KIND_NAMES[Kind.PLAGE]
	if not modifications.has(c) and bio != 80:
		var wk := stream_kind_id(water.width_at(c.x + 0.5, c.y + 0.5), h)
		if wk >= 0:
			return KIND_NAMES[wk]
	if is_estran(h, bio, _tide_max):
		return "Estran (découvert à marée basse)"
	return cell_kind(h, cell_slope(c), bio)


## Estran : sol sous le niveau moyen de la mer que la marée basse découvre.
## Seulement pour un sol naturel (eau, sol nu, zone humide, mangrove) : un
## polder cultivé reste un champ.
static func is_estran(h: float, code: int, tide_max: float) -> bool:
	return h < 0.0 and h >= -tide_max and code in [0, 60, 80, 90, 95]


## Type de case pour un cours d'eau de largeur w (m), -1 s'il n'y en a pas.
static func stream_kind_id(w: float, h: float) -> int:
	if w <= 0.0 or h < -2.0:
		return -1
	if w >= WaterMap.POND_WIDTH:
		return Kind.ETANG
	return Kind.RIVIERE if w >= 3.0 else Kind.RUISSEAU


## Pente autour d'une case (écart de hauteur maximal avec ses voisines), sans
## compter le creusement des rivières.
func cell_slope(c: Vector2i) -> float:
	var h := _bank_height(c)
	var s := 0.0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := _bank_height(c + d)
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
	if view_radius_override > 0.0:
		_view_radius = view_radius_override
	var cs := float(chunk_size)
	_water.position.x = snappedf(center.x, cs)
	_water.position.z = snappedf(center.z, cs)
	water.update_focus(center.x, center.z)

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
	# Rivières et ruisseaux de la WaterMap (largeur en m, 0 = pas d'eau).
	var wid := PackedFloat32Array()
	wid.resize(w * w)
	if water.any_in_rect(x0 - 1.0, z0 - 1.0, x0 + cs + 1.0, z0 + cs + 1.0):
		for j in w:
			for i in w:
				wid[i + j * w] = water.width_at(x0 + i - 1 + 0.5, z0 + j - 1 + 0.5)
	var rect := Rect2i(x0 - 1, z0 - 1, w, w)
	return {"k": k, "gen": _generation, "cs": cs, "step": height_step, "tide_max": _tide_max,
		"pxs": pxs, "pys": pys, "win": tiles.grab_window(pxs, pys),
		"bio": land.sample_grid(lats, lons), "wid": wid, "mod_idx": mod_idx, "mod_h": mod_h,
		"pwater": _collect_cells(water_cells, rect), "paint": _collect_cells(biome_paint, rect),
		"trees": _collect_cells(tree_paint, rect),
		"climat": Plantes.climat(origin_lat, origin_lon), "amer": Plantes.ameriques(origin_lon)}


## Cases d'un dictionnaire creux tombant dans rect : [indices locaux, valeurs].
static func _collect_cells(dict: Dictionary, rect: Rect2i) -> Array:
	var idx := PackedInt32Array()
	var val := PackedFloat32Array()
	var w := rect.size.x
	if dict.size() < rect.size.x * rect.size.y:
		for c: Vector2i in dict:
			if rect.has_point(c):
				idx.append((c.x - rect.position.x) + (c.y - rect.position.y) * w)
				val.append(dict[c])
	else:
		for j in rect.size.y:
			for i in w:
				var c := rect.position + Vector2i(i, j)
				if dict.has(c):
					idx.append(i + j * w)
					val.append(dict[c])
	return [idx, val]


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
	var wid: PackedFloat32Array = job.wid
	# L'eau douce est creusée pour dessiner les berges ; on retient sa surface.
	# wet : 0 = terre, 1 = eau douce, 2 = mer.
	var wet := PackedByteArray()
	wet.resize(w * w)
	var surf := PackedFloat32Array()
	surf.resize(w * w)
	# Hauteurs avant creusement : les berges gardent leur biome (pas de « roche »).
	var h_bank := h.duplicate()
	# Même règle que water_depth, écrite en ligne : cette boucle passe sur chaque case.
	var any_wet := false
	for n in w * w:
		var b := bio[n]
		if b == 80:
			wid[n] = 0.0 # dans un lac WorldCover, pas de ruisseau dessiné par-dessus
		var hn := h[n]
		if hn < 0.0:
			wet[n] = 2
			continue
		var wn := wid[n]
		if (wn == 0.0 and b != 80) or modified[n] != 0:
			continue
		var d := step if (b == 80 or wn >= WaterMap.POND_WIDTH) else step * (1.0 if wn < 3.0 else 2.0)
		wet[n] = 1
		surf[n] = hn - WATER_SURFACE_DROP
		h[n] = hn - d
		any_wet = true
	# Lacs et canaux creusés par le joueur (le lit est déjà dans les modifications).
	var pw_idx: PackedInt32Array = job.pwater[0]
	var pw_val: PackedFloat32Array = job.pwater[1]
	var player_water := PackedByteArray()
	player_water.resize(w * w)
	for m in pw_idx.size():
		var n := pw_idx[m]
		wet[n] = 1
		surf[n] = pw_val[m]
		wid[n] = 0.0
		h_bank[n] = pw_val[m] + WATER_SURFACE_DROP
		player_water[n] = 1
	any_wet = any_wet or pw_idx.size() > 0
	var has_marks := (job.paint[0] as PackedInt32Array).size() > 0 or (job.trees[0] as PackedInt32Array).size() > 0
	var paint := PackedByteArray()
	paint.resize(w * w)
	paint.fill(255)
	for m in (job.paint[0] as PackedInt32Array).size():
		paint[job.paint[0][m]] = int(job.paint[1][m])
	var tree_mark := PackedByteArray() # 0 = rien, 1 = arrachés, 2 = plantés
	tree_mark.resize(w * w)
	for m in (job.trees[0] as PackedInt32Array).size():
		tree_mark[job.trees[0][m]] = 2 if job.trees[1][m] > 0.5 else 1

	var colors := PackedColorArray()
	colors.resize(w * w)
	var kinds := PackedByteArray()
	kinds.resize(w * w)
	# Texture du sol (Sols.gd) : couche + 32 si les rangs du champ sont tournés.
	var couches := PackedByteArray()
	couches.resize(w * w)
	var k0: Vector2i = job.k * cs - Vector2i.ONE
	var climat: int = job.climat
	for j in range(1, w - 1):
		for i in range(1, w - 1):
			var n := i + j * w
			var hc := h[n]
			var hb := h_bank[n]
			var s := maxf(maxf(absf(h_bank[n + 1] - hb), absf(h_bank[n - 1] - hb)),
					maxf(absf(h_bank[n + w] - hb), absf(h_bank[n - w] - hb)))
			var code := bio[n]
			var kind: int = _KIND_BY_CODE[code]
			if kind < 0 or hc < 0.0 or s >= 1.0 or hc < 1.5 or hc > 1500.0:
				kind = cell_kind_id(hc, s, code)
			if any_wet and wet[n] == 1 and wid[n] > 0.0:
				var sk := stream_kind_id(wid[n], hc)
				if sk >= 0:
					kind = sk
			# Plages : terre basse au bord de la mer (ou à moins de 1 m d'altitude).
			if wet[n] == 0 and hc >= 0.0 and hc <= BEACH_MAX and s < 2.0:
				var near_sea := wet[n - 1] == 2 or wet[n + 1] == 2 or wet[n - w] == 2 or wet[n + w] == 2 \
					or wet[n - w - 1] == 2 or wet[n - w + 1] == 2 or wet[n + w - 1] == 2 or wet[n + w + 1] == 2
				if (near_sea or hc <= 1.0) and (BEACH_KINDS >> cell_kind_id(hc, 0.0, code)) & 1 == 1:
					kind = Kind.PLAGE
			if any_wet and player_water[n] == 1:
				kind = Kind.CANAL
			elif has_marks and paint[n] != 255 and wet[n] != 1:
				kind = paint[n]
			kinds[n] = kind
			var couche: int = Sols.DESSUS[kind]
			if couche < 0:
				var c := k0 + Vector2i(i, j)
				couche = Sols.CULTURES[Sols.culture(c, climat)][1] + (32 if Sols.rangs_tournes(c) else 0)
			couches[n] = couche
			if kind == Kind.PRAIRIE:
				colors[n] = _prairie_colors[clampi(floori(hc / 2.0), 0, 200)]
			else:
				colors[n] = _color_for_id(kind, hc)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var uvs := PackedVector2Array()

	# Dessus des cases : les cases voisines identiques d'une même ligne sont fusionnées.
	for j in range(1, cs + 1):
		var i := 1
		while i <= cs:
			var hv := h[i + j * w]
			var col := colors[i + j * w]
			var cou := couches[i + j * w]
			var e := i
			while e + 1 <= cs and h[e + 1 + j * w] == hv and colors[e + 1 + j * w] == col and couches[e + 1 + j * w] == cou:
				e += 1
			_quad(verts, normals, cols, idx,
				Vector3(i - 1, hv, j - 1), Vector3(e, hv, j - 1),
				Vector3(e, hv, j), Vector3(i - 1, hv, j), Vector3.UP, col)
			_uv4(uvs, cou & 31, cou >> 5)
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
			_uv4(uvs, Sols.FLANC[kinds[i + j * w] if a > b else kinds[i + 1 + j * w]], 0)

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
			_uv4(uvs, Sols.FLANC[kinds[i + j * w] if a > b else kinds[i + (j + 1) * w]], 0)
			i = e + 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	job.arrays = arrays
	job.h = h
	job.water_arrays = _compute_water_mesh(cs, wet, surf, wid) if any_wet else []
	job.surf_arrays = _compute_surf_mesh(cs, h, wet, job.tide_max)
	# Une case peinte (biome ou arbres) garde sa végétation même terrassée.
	if has_marks:
		for n in w * w:
			if paint[n] != 255 or tree_mark[n] != 0:
				modified[n] = 0
	job.tree_mark = tree_mark
	_compute_vegetation(job, h, kinds, modified)


## Ressac : une nappe d'écume posée sur la mer le long du rivage, qui suit la
## marée. Elle couvre l'estran (cases que la mer couvre et découvre) et une
## bande de 4 m devant les côtes hautes. Pour chaque sommet, UV.x = hauteur du
## sol (le shader n'affiche que là où la mer le recouvre, et mousse là où l'eau
## est peu profonde) et UV.y = proximité d'une côte haute (1 au contact).
const SURF_WIDTH := 4


static func _compute_surf_mesh(cs: int, h: PackedFloat32Array, wet: PackedByteArray, tide_max: float) -> Array:
	var w := cs + 2
	# Distance (en cases, plafonnée) à la terre que la mer n'atteint jamais.
	var dist := PackedByteArray()
	dist.resize(w * w)
	var any_land := false
	var any_sea := false
	for n in w * w:
		# Seule la terre ferme arrête la mer (pas les lacs ni les rivières).
		var wn := wet[n]
		var high := wn == 0 and h[n] > tide_max
		dist[n] = 0 if high else 255
		any_land = any_land or wn == 0
		any_sea = any_sea or wn == 2
	# Pas de rivage dans le bloc : rien à calculer (cas de presque tous les blocs).
	if not any_land or not any_sea:
		return []
	for _pass in SURF_WIDTH:
		for j in w:
			for i in w:
				var n := i + j * w
				if dist[n] == 0:
					continue
				var best: int = dist[n]
				for dj in range(-1, 2):
					for di in range(-1, 2):
						var ii := i + di
						var jj := j + dj
						if ii >= 0 and jj >= 0 and ii < w and jj < w:
							best = mini(best, dist[ii + jj * w] + 1)
				dist[n] = best
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var y := WATER_LEVEL + 0.02
	var shallow := -tide_max - 1.0
	for j in range(1, cs + 1):
		for i in range(1, cs + 1):
			var n := i + j * w
			var wn := wet[n]
			if wn == 1 or dist[n] == 0:
				continue
			var hn := h[n]
			if wn == 2:
				if hn < shallow and dist[n] > SURF_WIDTH:
					continue
			elif hn > tide_max:
				continue
			var base := verts.size()
			for corner: Vector2i in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i, j), Vector2i(i - 1, j)]:
				var d := 255
				var hs := 0.0
				for ddx in 2:
					for ddz in 2:
						var m := corner.x + ddx + (corner.y + ddz) * w
						d = mini(d, dist[m])
						hs += h[m]
				verts.push_back(Vector3(corner.x, y, corner.y))
				normals.push_back(Vector3.UP)
				uvs.push_back(Vector2(hs * 0.25, clampf(1.0 - float(d) / SURF_WIDTH, 0.0, 1.0)))
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	if verts.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


## Surface d'eau douce du bloc : un carré par case d'eau, à la hauteur de sa
## surface, avec des cascades entre deux cases d'eau de hauteurs différentes.
## Couleur de sommet (donnée pour le shader) : r = bord (écume), g = profondeur.
## Renvoie les tableaux du maillage, ou [] s'il n'y a pas d'eau douce.
static func _compute_water_mesh(cs: int, wet: PackedByteArray, surf: PackedFloat32Array,
		wid: PackedFloat32Array) -> Array:
	var w := cs + 2
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	# Coin (a, b) de la grille : bord si une des quatre cases qui le touchent est sèche.
	var cw := cs + 1
	var shore_at := PackedByteArray()
	shore_at.resize(cw * cw)
	for b in cw:
		for a in cw:
			var n0 := a + b * w
			if wet[n0] == 0 or wet[n0 + 1] == 0 or wet[n0 + w] == 0 or wet[n0 + w + 1] == 0:
				shore_at[a + b * cw] = 1
	for j in range(1, cs + 1):
		for i in range(1, cs + 1):
			var n := i + j * w
			if wet[n] != 1:
				continue
			var y := surf[n]
			var depth := 1.0 if wid[n] == 0.0 or wid[n] >= WaterMap.POND_WIDTH else clampf(wid[n] / 15.0, 0.15, 1.0)
			var base := verts.size()
			var c0 := (i - 1) + (j - 1) * cw
			verts.push_back(Vector3(i - 1, y, j - 1))
			verts.push_back(Vector3(i, y, j - 1))
			verts.push_back(Vector3(i, y, j))
			verts.push_back(Vector3(i - 1, y, j))
			for q in 4:
				normals.push_back(Vector3.UP)
			cols.push_back(Color(shore_at[c0], depth, 0.0, 1.0))
			cols.push_back(Color(shore_at[c0 + 1], depth, 0.0, 1.0))
			cols.push_back(Color(shore_at[c0 + 1 + cw], depth, 0.0, 1.0))
			cols.push_back(Color(shore_at[c0 + cw], depth, 0.0, 1.0))
			idx.push_back(base)
			idx.push_back(base + 1)
			idx.push_back(base + 2)
			idx.push_back(base)
			idx.push_back(base + 2)
			idx.push_back(base + 3)
			# Cascades vers l'Est et le Sud.
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var m: int = i + d.x + (j + d.y) * w
				if wet[m] != 1 or surf[m] == y:
					continue
				var hi := maxf(y, surf[m])
				var lo := minf(y, surf[m])
				var fall := Color(1.0, depth, 0.0, 1.0)
				if d.x == 1:
					_quad(verts, normals, cols, idx, Vector3(i, hi, j - 1), Vector3(i, hi, j),
						Vector3(i, lo, j), Vector3(i, lo, j - 1), Vector3.RIGHT, fall)
				else:
					_quad(verts, normals, cols, idx, Vector3(i - 1, hi, j), Vector3(i, hi, j),
						Vector3(i, lo, j), Vector3(i - 1, lo, j), Vector3.BACK, fall)
	if verts.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


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
	var wa: Array = job.water_arrays
	if not wa.is_empty():
		var wmesh := ArrayMesh.new()
		wmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wa)
		var wmi := MeshInstance3D.new()
		wmi.name = "Eau"
		wmi.mesh = wmesh
		wmi.material_override = _water_material
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(wmi)
	var sa: Array = job.surf_arrays
	if not sa.is_empty():
		var smesh := ArrayMesh.new()
		smesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sa)
		var smi := MeshInstance3D.new()
		smi.name = "Ressac"
		smi.mesh = smesh
		smi.material_override = _surf_material
		smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(smi)
	chunk_rebuilt.emit(k)


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


## UV des 4 sommets d'une face du terrain : (couche de texture, rangs tournés).
static func _uv4(uvs: PackedVector2Array, couche: int, tourne: int) -> void:
	var uv := Vector2(couche, tourne)
	uvs.push_back(uv)
	uvs.push_back(uv)
	uvs.push_back(uv)
	uvs.push_back(uv)


## Couleurs de base (linéaires) par type de case ; la prairie et la mer varient avec l'altitude.
static var _base_colors: PackedColorArray = _make_base_colors()


static func _make_base_colors() -> PackedColorArray:
	# Lac, rivière, ruisseau, étang : le lit, vu à travers l'eau animée.
	var hexes := ["c9b27c", "5f7a6a", "eef3f8", "8e8a82", "4c8c3c", "8d9a58", "5d9e47", "d2c06a",
		"e6d59c", "6c9a7c", "3b7354", "a9a88a", "e6d59c", "eef3f8", "98a56a", "5f7a6a", "5f7a6a", "5f7a6a", "5f7a6a"]
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



## Maillages de secours (cône, boule) si les .glb des plantes ne sont pas importés.
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


## Choisit les plantes de chaque case (Plantes.gd : biome, climat, altitude ;
## Sols.gd : culture de la parcelle pour les champs), de façon déterministe
## (le même lieu donne toujours la même forêt). Calcul pur, sans lire la scène.
static func _compute_vegetation(job: Dictionary, h: PackedFloat32Array, kinds: PackedByteArray, modified: PackedByteArray) -> void:
	var k: Vector2i = job.k
	var cs: int = job.cs
	var w := cs + 2
	var climat: int = job.climat
	var amer: bool = job.amer
	var cells: Array[Vector2i] = []
	var xforms: Array[Transform3D] = []
	var teintes := PackedColorArray()
	var especes := PackedInt32Array()
	var tree_mark: PackedByteArray = job.tree_mark
	for j in range(1, cs + 1):
		for i in range(1, cs + 1):
			var n := i + j * w
			var kind := kinds[n]
			var mark: int = tree_mark[n]
			if mark == 1 or modified[n] != 0:
				continue
			var c := Vector2i(k.x * cs + i - 1, k.y * cs + j - 1)
			var r := absi(hash(c))
			var u := float(r & 0xffff) / 65535.0
			var v := float(absi(hash(c * 7 + Vector2i(3, 1))) & 0xffff) / 65535.0
			var e := -1
			var culture := false
			if mark == 2 and kind != Kind.CANAL and u < Plantes.DENSITE_PLANTES:
				e = Plantes.arbre_plante(climat, h[n], v)
			elif kind == Kind.CHAMPS:
				var cu: Array = Sols.CULTURES[Sols.culture(c, climat)]
				if cu[2] != "" and u < cu[3]:
					e = Plantes.id(cu[2])
					culture = true
			else:
				e = Plantes.choisir(kind, climat, h[n], amer, u, v)
			if e < 0:
				continue
			var cat := Plantes.categorie(e)
			var pos: Vector3
			var basis: Basis
			if culture:
				# Cultures : alignées en rangs, dans le sens de la parcelle.
				var tourne := Sols.rangs_tournes(c)
				var vigne := Plantes.nom(e) == "vigne"
				if vigne and posmod(c.x if tourne else c.y, 2) != 0:
					continue
				var jx := 0.5 + (v - 0.5) * 0.1
				var jz := 0.5 + (u - 0.5) * 0.1
				if vigne:
					jx = 0.0 if tourne else 0.5
					jz = 0.5 if tourne else 0.0
				pos = Vector3(i - 1 + jx, h[n], j - 1 + jz)
				var sc := 0.9 + v * 0.2
				basis = Basis(Vector3.UP, PI / 2.0 if tourne else 0.0).scaled(Vector3(sc, sc, sc))
			else:
				var jx := float((r >> 16) & 0xff) / 255.0 * 0.6 + 0.2
				var jz := float((r >> 24) & 0x7f) / 127.0 * 0.6 + 0.2
				var sc := (0.7 + v * 0.6) if cat == Plantes.Cat.ARBRE else (0.8 + v * 0.4)
				basis = Basis(Vector3.UP, float(r & 0xff)).scaled(Vector3(sc, sc, sc))
				pos = Vector3(i - 1 + jx, h[n], j - 1 + jz)
			# Teinte : un peu plus clair ou foncé, un peu plus jaune ou bleu.
			var shade := 0.88 + float((r >> 4) & 0x3f) / 63.0 * 0.24
			var dh := 0.0 if cat == Plantes.Cat.ROCHER else (float((r >> 10) & 0x3f) / 63.0 - 0.5) * 0.12
			cells.append(c)
			xforms.append(Transform3D(basis, pos))
			teintes.append(Color(shade * (1.0 + dh), shade, shade * (1.0 - dh)))
			especes.append(e)
	job.veg = {"cells": cells, "xforms": xforms, "cols": teintes, "especes": especes}


## Fil principal : retire la végétation sous les voies (tree_blocker) et la pose,
## un MultiMesh par espèce (plus sa version lointaine pour les arbres).
func _plant_vegetation(mi: MeshInstance3D, job: Dictionary) -> void:
	for child in mi.get_children():
		mi.remove_child(child)
		child.queue_free()
	var veg: Dictionary = job.veg
	var cells: Array[Vector2i] = veg.cells
	var xforms: Array[Transform3D] = veg.xforms
	var cols: PackedColorArray = veg.cols
	var especes: PackedInt32Array = veg.especes
	var groupes := {} # espèce -> [Array[Transform3D], PackedColorArray]
	var arbres: Array[Transform3D] = []
	var check := tree_blocker.is_valid()
	for n in cells.size():
		if check and tree_blocker.call(cells[n]):
			continue
		var e := especes[n]
		if not groupes.has(e):
			var liste: Array[Transform3D] = []
			groupes[e] = [liste, PackedColorArray()]
		(groupes[e][0] as Array).append(xforms[n])
		groupes[e][1].append(cols[n])
		if Plantes.categorie(e) == Plantes.Cat.ARBRE:
			arbres.append(xforms[n])
	for e: int in groupes:
		var cat := Plantes.categorie(e)
		var liste: Array[Transform3D] = groupes[e][0]
		var teintes: PackedColorArray = groupes[e][1]
		var m := Plantes.mesh(e)
		if m == null:
			# Secours : l'ancien cône ou la boule, en vert.
			var secours := _tree_mesh if cat == Plantes.Cat.ARBRE else _bush_mesh
			var verts := PackedColorArray()
			for t in teintes:
				verts.append(Color("2a6a2a") * t.r)
			var inst0 := _pose_multimesh(mi, secours, liste, verts, 0.0, null)
			inst0.set_meta("categorie", cat)
			continue
		var proche := _pose_multimesh(mi, m, liste, teintes, Plantes.vent(e), Plantes.materiau())
		proche.name = Plantes.nom(e)
		proche.set_meta("categorie", cat)
		proche.visibility_range_end = Plantes.DISTANCE[cat]
		proche.visibility_range_end_margin = 8.0
		if cat == Plantes.Cat.HERBE or cat == Plantes.Cat.CULTURE:
			proche.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if Plantes.a_version_loin(e):
			var ml := Plantes.mesh(e, true)
			if ml:
				var loin := _pose_multimesh(mi, ml, liste, teintes, 0.0, Plantes.materiau())
				loin.name = Plantes.nom(e) + "_loin"
				loin.set_meta("categorie", cat)
				loin.set_meta("loin", true)
				loin.visibility_range_begin = Plantes.DISTANCE[cat]
				loin.visibility_range_begin_margin = 8.0
	# Gardé pour les collisions des troncs (vue au sol).
	mi.set_meta("arbres", arbres)


## Un MultiMeshInstance3D enfant de parent. Avec un matériau de plantes, la
## teinte et le vent passent par INSTANCE_CUSTOM ; sinon par la couleur.
static func _pose_multimesh(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D], cols: PackedColorArray,
		vent: float, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = mat == null
	mm.use_custom_data = mat != null
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for n in xforms.size():
		mm.set_instance_transform(n, xforms[n])
		if mat:
			var c := cols[n]
			mm.set_instance_custom_data(n, Color(c.r, c.g, c.b, vent))
		else:
			mm.set_instance_color(n, cols[n])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat:
		inst.material_override = mat
	parent.add_child(inst)
	return inst


# --- Souris et outils ------------------------------------------------------

## Change la caméra et le point suivis pour charger le relief (vue de dessus ou personnage).
func set_view(camera: Camera3D, focus: Node3D) -> void:
	_camera = camera
	_focus = focus


func set_tool(t: Tool) -> void:
	current_tool = t
	_dragging = false
	_update_selection()


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		if _dragging and is_brush_tool() and _hover_valid and _hover != _last_brush:
			apply_brush(_hover)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_hover(mb.position)
		if is_brush_tool():
			if mb.pressed and _hover_valid:
				_dragging = true
				_stroke_level = NAN
				apply_brush(_hover)
			elif not mb.pressed:
				_dragging = false
				_last_brush = Vector2i(1 << 30, 0)
			_update_selection()
			return
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
		var top := maxf(h, sea_level())
		if p.y <= top:
			return Vector3(p.x, top, p.z)
		t += clampf((p.y - top) * 0.5, 0.15, 25.0)
	return null


func is_brush_tool() -> bool:
	return current_tool in BRUSH_TOOLS


func _selection_rect() -> Rect2i:
	if is_brush_tool():
		return Rect2i(_hover - Vector2i(brush_radius, brush_radius), Vector2i.ONE * (brush_radius * 2 + 1))
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
	var ref := _drag_start if _dragging and not is_brush_tool() else _hover
	var h := cell_height(ref)
	if is_nan(h):
		_selection.visible = false
		return
	_selection.visible = true
	var top := maxf(h, sea_level())
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
			water_cells.erase(c)
			count += 1
			_mark_dirty_around(c)
	terrain_edited.emit(count)
	_update_selection()
	return count


## Cases du pinceau rond centré sur center.
func brush_cells(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := brush_radius
	var lim := (r + 0.5) * (r + 0.5)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz <= lim:
				out.append(center + Vector2i(dx, dz))
	return out


## Un coup de pinceau de l'outil de paysage courant. Renvoie le nombre de cases changées.
func apply_brush(center: Vector2i) -> int:
	_last_brush = center
	var cells := brush_cells(center)
	var count := 0
	var r := float(brush_radius) + 0.5
	match current_tool:
		Tool.HILL:
			for c in cells:
				var h := cell_height(c)
				if is_nan(h):
					continue
				var d := Vector2(c - center).length() / r
				var add := snappedf(hill_height * (1.0 - d * d), height_step)
				if add <= 0.0:
					continue
				water_cells.erase(c)
				modifications[c] = h + add
				count += 1
		Tool.SMOOTH:
			var new_h := {}
			for c in cells:
				var sum := 0.0
				var n := 0
				for dz in range(-2, 3):
					for dx in range(-2, 3):
						var v := cell_height(c + Vector2i(dx, dz))
						if not is_nan(v):
							sum += v
							n += 1
				if n > 0 and not water_cells.has(c):
					new_h[c] = _quantize(sum / n)
			for c in new_h:
				if new_h[c] != cell_height(c):
					modifications[c] = new_h[c]
					count += 1
		Tool.DIG_WATER:
			# Le niveau de l'eau est celui du premier coup de pinceau : un canal
			# qui monte est creusé plus profond, comme un vrai canal.
			if is_nan(_stroke_level):
				_stroke_level = _bank_height(center)
				if is_nan(_stroke_level):
					return 0
			for c in cells:
				if water_cells.has(c):
					continue
				var bank := _bank_height(c)
				if is_nan(bank) or bank < 0.0:
					continue
				var level := minf(bank, _stroke_level)
				water_cells[c] = level - WATER_SURFACE_DROP
				modifications[c] = level - 1.0
				count += 1
		Tool.FILL_WATER:
			for c in cells:
				if water_cells.has(c):
					modifications[c] = float(water_cells[c]) + WATER_SURFACE_DROP
					water_cells.erase(c)
					count += 1
		Tool.BIOME:
			for c in cells:
				if float(biome_paint.get(c, -1.0)) != float(paint_kind):
					biome_paint[c] = float(paint_kind)
					count += 1
		Tool.PLANT, Tool.CLEAR_TREES:
			var v := 1.0 if current_tool == Tool.PLANT else 0.0
			for c in cells:
				if float(tree_paint.get(c, -1.0)) != v:
					tree_paint[c] = v
					count += 1
	if count > 0:
		for c in cells:
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

## Section « terrain » de la sauvegarde : lieu et cases modifiées, par blocs.
func to_dict() -> Dictionary:
	var d := {"version": 2, "lat": origin_lat, "lon": origin_lon, "modifs": SaveGame.encode_cells(modifications)}
	# Paysage du joueur (absent des anciennes parties : sections facultatives).
	if not water_cells.is_empty():
		d["eau"] = SaveGame.encode_cells(water_cells)
	if not biome_paint.is_empty():
		d["biomes"] = SaveGame.encode_cells(biome_paint)
	if not tree_paint.is_empty():
		d["arbres"] = SaveGame.encode_cells(tree_paint)
	return d


## Recharge le lieu et les cases modifiées (vide aussi les autres systèmes via origin_changed).
func from_dict(data: Dictionary) -> void:
	if int(data.get("version", 1)) < 2:
		data = SaveGame.migrate_section("terrain", 1, data)
	set_origin(float(data.get("lat", origin_lat)), float(data.get("lon", origin_lon)))
	modifications = SaveGame.decode_cells(data.get("modifs", {}))
	water_cells = SaveGame.decode_cells(data.get("eau", {}))
	biome_paint = SaveGame.decode_cells(data.get("biomes", {}))
	tree_paint = SaveGame.decode_cells(data.get("arbres", {}))


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
