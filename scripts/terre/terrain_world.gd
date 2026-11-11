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
## Rivières et ruisseaux (OpenStreetMap ou calculés depuis le relief).
var water: WaterMap
## Optionnel : Callable(c: Vector2i) -> bool. Vrai = pas d'arbre sur cette case
## (ex. une route posée sur un terrain plat).
var tree_blocker: Callable
var _tree_mesh: Mesh
var _bush_mesh: Mesh
var _dirty: Dictionary = {}
var _material: ShaderMaterial
var _water: MeshInstance3D
var _water_material: ShaderMaterial
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

	_water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (max_view_radius * 2.0 + 256.0)
	_water.mesh = plane
	var water_shader := preload("res://scripts/terre/water.gdshader")
	var wm := ShaderMaterial.new()
	wm.shader = water_shader
	wm.set_shader_parameter("foam_amount", 0.0)
	wm.set_shader_parameter("fixed_depth", 1.0)
	wm.set_shader_parameter("wave_scale", 0.6)
	_water.material_override = wm
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
	if water:
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


## Hauteur affichée d'une case (arrondie, avec les modifications du joueur).
func cell_height(c: Vector2i) -> float:
	if modifications.has(c):
		return modifications[c]
	var h := raw_height(c.x + 0.5, c.y + 0.5)
	if is_nan(h):
		return NAN
	var q := _quantize(h)
	return q - _water_depth(q, cell_biome(c), water.width_at(c.x + 0.5, c.y + 0.5))


## Hauteur d'une case sans le creusement des rivières.
func _bank_height(c: Vector2i) -> float:
	if modifications.has(c):
		return modifications[c]
	var h := raw_height(c.x + 0.5, c.y + 0.5)
	return NAN if is_nan(h) else _quantize(h)


## Profondeur du lit creusé sous la hauteur arrondie q (0 = pas d'eau douce).
## width : largeur du cours d'eau (WaterMap.width_at), bio : code WorldCover.
func _water_depth(q: float, bio: int, width: float) -> float:
	if q < 0.0:
		return 0.0 # la mer est gérée à part
	if width >= WaterMap.POND_WIDTH or bio == 80:
		return height_step
	if width > 0.0:
		return height_step * (1.0 if width < 3.0 else 2.0)
	return 0.0


## Hauteur de la surface de l'eau douce (rivière, ruisseau, lac) sur la case
## qui contient (x, z), ou NAN s'il n'y en a pas. La mer n'est pas comptée.
func water_surface_at(x: float, z: float) -> float:
	var c := Vector2i(floori(x), floori(z))
	if modifications.has(c):
		return NAN
	var h := raw_height(c.x + 0.5, c.y + 0.5)
	if is_nan(h):
		return NAN
	var q := _quantize(h)
	if _water_depth(q, cell_biome(c), water.width_at(c.x + 0.5, c.y + 0.5)) == 0.0:
		return NAN
	return q - WATER_SURFACE_DROP


## Nom du cours d'eau ou du lac sur une case (OpenStreetMap), ou "".
func water_name_at(c: Vector2i) -> String:
	return water.name_at(c.x + 0.5, c.y + 0.5)


func _on_water_changed() -> void:
	for k in chunks:
		_dirty[k] = true


## Biome d'une case à partir de son altitude, de sa pente et du code WorldCover
## (0 = inconnu : on devine avec l'altitude seule).
static func cell_kind(h: float, slope: float, code := 0) -> String:
	if h < 0.0 and (code == 0 or code == 80):
		return "Mer"
	if code == 80:
		return "Lac / rivière"
	if code == 70:
		return "Glacier"
	if slope >= 1.0:
		return "Roche"
	match code:
		10:
			return "Forêt"
		20:
			return "Broussailles"
		30, 50:
			return "Prairie"
		40:
			return "Champs"
		60:
			return "Roche" if h > 1500.0 else "Désert"
		90:
			return "Marais"
		95:
			return "Mangrove"
		100:
			return "Toundra"
	if h < 1.5:
		return "Plage"
	if h > 2600.0:
		return "Neige"
	if h > 1900.0:
		return "Alpage"
	return "Prairie"


## Code WorldCover sous le centre d'une case (0 si inconnu).
func cell_biome(c: Vector2i) -> int:
	var ll := local_to_lat_lon(c.x + 0.5, c.y + 0.5)
	return land.class_at(ll.x, ll.y)


## Nom du biome d'une case, prêt à afficher.
func cell_kind_at(c: Vector2i) -> String:
	var h := cell_height(c)
	if is_nan(h):
		return ""
	var bio := cell_biome(c)
	if not modifications.has(c) and bio != 80:
		var wk := _stream_kind(water.width_at(c.x + 0.5, c.y + 0.5), h)
		if wk != "":
			return wk
	return cell_kind(h, cell_slope(c), bio)


## Type de case pour un cours d'eau de largeur w (m), "" s'il n'y en a pas.
static func _stream_kind(w: float, h: float) -> String:
	if w <= 0.0 or h < -WATER_SURFACE_DROP - 2.0:
		return ""
	if w >= WaterMap.POND_WIDTH:
		return "Étang"
	return "Rivière" if w >= 3.0 else "Ruisseau"


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
	# Occupation du sol aux quatre coins du bloc (un bloc WorldCover fait ~10 km).
	for corner in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		var ll := local_to_lat_lon(corner.x, corner.y)
		if not land.is_ready_at(ll.x, ll.y):
			land.request_at(ll.x, ll.y)
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

	# Occupation du sol de chaque case.
	var bio := PackedByteArray()
	bio.resize(w * w)
	var lons := PackedFloat64Array()
	lons.resize(w)
	for i in w:
		lons[i] = Geo.local_to_lon(origin_lat, origin_lon, x0 + i - 1 + 0.5)
	for j in w:
		var lat := Geo.local_to_lat(origin_lat, z0 + j - 1 + 0.5)
		for i in w:
			bio[i + j * w] = land.class_at(lat, lons[i])
	# Rivières et ruisseaux de la WaterMap (largeur en m, 0 = pas d'eau).
	var wid := PackedFloat32Array()
	wid.resize(w * w)
	if water.any_in_rect(x0 - 1.0, z0 - 1.0, x0 + cs + 1.0, z0 + cs + 1.0):
		for j in w:
			for i in w:
				wid[i + j * w] = water.width_at(x0 + i - 1 + 0.5, z0 + j - 1 + 0.5)
	# L'eau douce est creusée pour dessiner les berges ; on retient sa surface.
	# wet : 0 = terre, 1 = eau douce, 2 = mer.
	var wet := PackedByteArray()
	wet.resize(w * w)
	var surf := PackedFloat32Array()
	surf.resize(w * w)
	# Hauteurs avant creusement : les berges gardent leur biome (pas de « roche »).
	var h_bank := h.duplicate()
	for n in w * w:
		if bio[n] == 80:
			wid[n] = 0.0 # dans un lac WorldCover, pas de ruisseau dessiné par-dessus
		if h[n] < 0.0:
			wet[n] = 2
			continue
		var c := Vector2i(x0 + n % w - 1, z0 + n / w - 1)
		if modifications.has(c):
			continue
		var d := _water_depth(h[n], bio[n], wid[n])
		if d > 0.0:
			wet[n] = 1
			surf[n] = h[n] - WATER_SURFACE_DROP
			h[n] -= d

	var colors := PackedColorArray()
	colors.resize(w * w)
	var kinds: Array[String] = []
	kinds.resize(w * w)
	for j in range(1, w - 1):
		for i in range(1, w - 1):
			var hc := h[i + j * w]
			var hb := h_bank[i + j * w]
			var s := maxf(maxf(absf(h_bank[i + 1 + j * w] - hb), absf(h_bank[i - 1 + j * w] - hb)),
					maxf(absf(h_bank[i + (j + 1) * w] - hb), absf(h_bank[i + (j - 1) * w] - hb)))
			var kind := cell_kind(hc, s, bio[i + j * w])
			if wet[i + j * w] == 1:
				var sk := _stream_kind(wid[i + j * w], hc)
				if sk != "":
					kind = sk
			kinds[i + j * w] = kind
			colors[i + j * w] = _color_for(kind, hc)

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
	_plant_vegetation(mi, k, h, kinds)
	_build_water_mesh(mi, wet, surf, wid)
	_dirty.erase(k)


## Surface d'eau douce du bloc : un carré par case d'eau, à la hauteur de sa
## surface, avec des cascades entre deux cases d'eau de hauteurs différentes.
## Couleur de sommet (donnée pour le shader) : r = bord (écume), g = profondeur.
func _build_water_mesh(mi: MeshInstance3D, wet: PackedByteArray, surf: PackedFloat32Array,
		wid: PackedFloat32Array) -> void:
	var cs := chunk_size
	var w := cs + 2
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in range(1, cs + 1):
		for i in range(1, cs + 1):
			var n := i + j * w
			if wet[n] != 1:
				continue
			var y := surf[n]
			var depth := 1.0 if wid[n] == 0.0 or wid[n] >= WaterMap.POND_WIDTH else clampf(wid[n] / 15.0, 0.15, 1.0)
			var base := verts.size()
			# Coins (a, b) en coordonnées de grille : bord si une case autour est sèche.
			for corner: Vector2i in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i, j), Vector2i(i - 1, j)]:
				var shore := 0.0
				for ddx in 2:
					for ddz in 2:
						if wet[corner.x + ddx + (corner.y + ddz) * w] == 0:
							shore = 1.0
				verts.append(Vector3(corner.x, y, corner.y))
				normals.append(Vector3.UP)
				cols.append(Color(shore, depth, 0.0, 1.0))
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
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
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var wmi := MeshInstance3D.new()
	wmi.name = "Eau"
	wmi.mesh = mesh
	wmi.material_override = _water_material
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(wmi)


static func _quad(verts: PackedVector3Array, normals: PackedVector3Array, cols: PackedColorArray,
		idx: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	var base := verts.size()
	verts.append_array([a, b, c, d])
	normals.append_array([n, n, n, n])
	cols.append_array([col, col, col, col])
	idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


static func _color_for(kind: String, h: float) -> Color:
	var c: Color
	match kind:
		"Mer":
			c = Color("c9b27c").darkened(clampf(-h / 40.0, 0.0, 0.6))
		"Lac / rivière", "Rivière", "Ruisseau", "Étang":
			# Lit vu à travers l'eau.
			c = Color("5f7a6a")
		"Plage", "Désert":
			c = Color("e6d59c")
		"Roche":
			c = Color("8e8a82")
		"Neige", "Glacier":
			c = Color("eef3f8")
		"Alpage":
			c = Color("98a56a")
		"Forêt":
			c = Color("4c8c3c")
		"Mangrove":
			c = Color("3b7354")
		"Broussailles":
			c = Color("8d9a58")
		"Champs":
			c = Color("d2c06a")
		"Marais":
			c = Color("6c9a7c")
		"Toundra":
			c = Color("a9a88a")
		_:
			# Prairie : plus claire en montant, par paliers de 2 m, pour lire le relief.
			var t := clampf(floorf(h / 2.0) * 2.0 / 400.0, 0.0, 1.0)
			c = Color("5d9e47").lerp(Color("a8b864"), t)
	# Le shader travaille en couleurs linéaires.
	return c.srgb_to_linear()


# --- Végétation --------------------------------------------------------------

const TREE_DENSITY := {"Forêt": 0.10, "Mangrove": 0.08, "Broussailles": 0.025, "Prairie": 0.004, "Marais": 0.01}
const BUSH_DENSITY := {"Broussailles": 0.05, "Toundra": 0.02, "Forêt": 0.03, "Alpage": 0.01}


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


## Plante des arbres et des buissons low-poly selon le biome, de façon
## déterministe (le même lieu donne toujours la même forêt).
func _plant_vegetation(mi: MeshInstance3D, k: Vector2i, h: PackedFloat32Array, kinds: Array[String]) -> void:
	for child in mi.get_children():
		mi.remove_child(child)
		child.queue_free()
	var cs := chunk_size
	var w := cs + 2
	var trees: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	var bushes: Array[Transform3D] = []
	var bush_cols: Array[Color] = []
	for j in range(1, cs + 1):
		for i in range(1, cs + 1):
			var kind := kinds[i + j * w]
			var td: float = TREE_DENSITY.get(kind, 0.0)
			var bd: float = BUSH_DENSITY.get(kind, 0.0)
			if td == 0.0 and bd == 0.0:
				continue
			var c := Vector2i(k.x * cs + i - 1, k.y * cs + j - 1)
			if modifications.has(c) or (tree_blocker.is_valid() and tree_blocker.call(c)):
				continue
			var r := absi(hash(c))
			var u := float(r & 0xffff) / 65535.0
			if u >= td + bd:
				continue
			var jx := float((r >> 16) & 0xff) / 255.0 * 0.6 + 0.2
			var jz := float((r >> 24) & 0x7f) / 127.0 * 0.6 + 0.2
			var s := 0.7 + float((r >> 8) & 0xff) / 255.0 * 0.6
			var shade := 0.85 + float((r >> 4) & 0x3f) / 63.0 * 0.3
			var basis := Basis(Vector3.UP, float(r & 0xff)).scaled(Vector3(s, s, s))
			if u < td:
				trees.append(Transform3D(basis, Vector3(i - 1 + jx, h[i + j * w] + 1.8 * s, j - 1 + jz)))
				var green := Color("2a6a2a") if kind != "Prairie" else Color("367a30")
				tree_cols.append(green * shade)
			else:
				bushes.append(Transform3D(basis, Vector3(i - 1 + jx, h[i + j * w] + 0.3 * s, j - 1 + jz)))
				bush_cols.append(Color("587a33") * shade)
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
