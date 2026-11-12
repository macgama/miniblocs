class_name HorizonTerrain
extends Node3D
## Horizon : le relief lointain, simplifié, au-delà des blocs de 1 m.
##
## Les blocs de 64 × 64 cases ne vont qu'à quelques centaines de mètres. Pour
## voir loin avec une caméra rasante, on pose autour d'eux des « plaques » de
## 1 km de côté, au relief réel mais grossier : une altitude tous les 16 m près
## du centre, 32 m plus loin, puis 64 m vers l'horizon. Leurs altitudes viennent
## de tuiles Terrarium à petit zoom (≈ 38 m par pixel, une tuile couvre ~6 km),
## donc très peu de téléchargements. Les couleurs suivent les mêmes biomes que
## le terrain détaillé (WorldCover).
##
## Là où un bloc détaillé est affiché, la plaque est effacée (masque : un texel
## par bloc de 64 m). Tant qu'un bloc détaillé n'est pas prêt, la plaque sert
## de terrain provisoire. Au loin, le relief se fond dans la couleur de l'horizon
## et suit la courbure de la Terre.

## Côté d'une plaque (m).
const PATCH := 1024.0
## Mailles par côté selon l'éloignement (16 m, 32 m, 64 m).
const LEVELS: Array[int] = [64, 32, 16]
## Distances (m) où l'on passe au niveau de détail suivant.
const LEVEL_DIST: Array[float] = [1800.0, 4500.0]
## Couleur de l'eau vue de loin (mer, lacs).
const WATER_FAR := Color(0.36, 0.56, 0.68)

## Distance d'affichage du relief lointain (m).
@export var radius := 10000.0
## Zoom des tuiles d'altitude lointaines (12 : ~38 m par pixel à l'équateur).
@export var zoom := 12
## Temps maximum par image pour lancer et poser des plaques (ms).
@export var budget_ms := 3.0
@export var threaded := true

var world: TerrainWorld
## Tuiles d'altitude à petit zoom (cache disque partagé avec le reste du jeu).
var tiles: ElevationTiles
## Vector2i -> {mi: MeshInstance3D, res: int}
var patches: Dictionary = {}
## Plaques en cours de calcul : Vector2i -> {job, task}
var _jobs: Dictionary = {}
var _max_jobs := clampi(OS.get_processor_count() - 1, 1, 4)
var _generation := 0
var _material: ShaderMaterial
var _mask_img: Image
var _mask_tex: ImageTexture
var _mask_size := 0
var _mask_key := ""
var _mask_dirty := true


func _ready() -> void:
	tiles = ElevationTiles.new()
	tiles.name = "TuilesHorizon"
	tiles.zoom = zoom
	add_child(tiles)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://scripts/terre/horizon.gdshader")
	_material.render_priority = -1
	_mask_size = ceili((radius + PATCH) * 2.0 / world.chunk_size) + 4
	_mask_img = Image.create(_mask_size, _mask_size, false, Image.FORMAT_R8)
	_mask_tex = ImageTexture.create_from_image(_mask_img)
	_material.set_shader_parameter("near_mask", _mask_tex)
	_material.set_shader_parameter("mask_size", float(_mask_size))
	_material.set_shader_parameter("mask_cell", float(world.chunk_size))
	_material.set_shader_parameter("radius", radius)
	world.origin_changed.connect(func(_la: float, _lo: float) -> void: clear())
	world.chunk_rebuilt.connect(func(_k: Vector2i) -> void: _mask_dirty = true)


## Hors ligne (tests) : le relief lointain ne s'affiche que si ses propres tuiles
## sont fabriquées sur place, jamais en allant sur le réseau.
func is_active() -> bool:
	if not visible:
		return false
	return tiles.offline_generator.is_valid() or not world.tiles.offline_generator.is_valid()


func clear() -> void:
	for p in patches.values():
		(p.mi as Node).queue_free()
	patches.clear()
	_generation += 1
	_mask_dirty = true


func _exit_tree() -> void:
	for k in _jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_jobs[k].task)
	_jobs.clear()


## Niveau de détail voulu pour une plaque (nombre de mailles par côté).
static func level_for(dist: float) -> int:
	for i in LEVEL_DIST.size():
		if dist < LEVEL_DIST[i]:
			return LEVELS[i]
	return LEVELS[LEVELS.size() - 1]


## Distance (m) entre le centre et le point le plus proche de la plaque.
static func patch_distance(k: Vector2i, center: Vector3) -> float:
	var x0 := k.x * PATCH
	var z0 := k.y * PATCH
	var dx := maxf(maxf(x0 - center.x, center.x - (x0 + PATCH)), 0.0)
	var dz := maxf(maxf(z0 - center.z, center.z - (z0 + PATCH)), 0.0)
	return sqrt(dx * dx + dz * dz)


func _process(_delta: float) -> void:
	if not is_active():
		for p in patches.values():
			(p.mi as MeshInstance3D).visible = false
		return
	var center := world._focus.global_position if world._focus else Vector3.ZERO
	_update_mask(center)
	_material.set_shader_parameter("focus", center)
	var env := get_world_3d().environment if get_world_3d() else null
	if env:
		_material.set_shader_parameter("horizon_color", env.fog_light_color)

	_collect_jobs()
	var r := ceili(radius / PATCH)
	var cc := Vector2i(floori(center.x / PATCH), floori(center.z / PATCH))
	var wanted: Array = []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := cc + Vector2i(dx, dz)
			var d := patch_distance(k, center)
			if d > radius:
				continue
			var res := level_for(d)
			var p: Dictionary = patches.get(k, {})
			if (p.is_empty() or p.res != res) and not _jobs.has(k):
				wanted.append([d, k, res])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var start := Time.get_ticks_usec()
	for w in wanted:
		if threaded and _jobs.size() >= _max_jobs:
			break
		var k: Vector2i = w[1]
		if not _ensure_data(k):
			continue
		var job := _prepare(k, w[2])
		if threaded:
			_jobs[k] = {"job": job, "task": WorkerThreadPool.add_task(compute.bind(job))}
		else:
			compute(job)
			_apply(job)
		if (Time.get_ticks_usec() - start) / 1000.0 > budget_ms:
			break

	for k in patches.keys():
		if patch_distance(k, center) > radius + PATCH * 0.5:
			(patches[k].mi as Node).queue_free()
			patches.erase(k)


func _collect_jobs() -> void:
	for k in _jobs.keys():
		var e: Dictionary = _jobs[k]
		if not WorkerThreadPool.is_task_completed(e.task):
			continue
		WorkerThreadPool.wait_for_task_completion(e.task)
		_jobs.erase(k)
		if e.job.gen == _generation:
			_apply(e.job)


## Attend la fin des calculs en cours (tests).
func finish_jobs() -> void:
	for k in _jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_jobs[k].task)
		if _jobs[k].job.gen == _generation:
			_apply(_jobs[k].job)
	_jobs.clear()


# --- Masque des blocs détaillés ------------------------------------------

## Un texel par bloc de 64 m : 1 = bloc détaillé affiché (on efface la plaque).
func _update_mask(center: Vector3) -> void:
	var cs := world.chunk_size
	var half := _mask_size / 2
	var origin := Vector2i(floori(center.x / cs) - half, floori(center.z / cs) - half)
	var key := "%d|%d|%d" % [origin.x, origin.y, world.chunks.size()]
	if key == _mask_key and not _mask_dirty:
		return
	_mask_key = key
	_mask_dirty = false
	_mask_img.fill(Color(0, 0, 0))
	for k: Vector2i in world.chunks:
		var t := k - origin
		if t.x >= 0 and t.y >= 0 and t.x < _mask_size and t.y < _mask_size:
			_mask_img.set_pixel(t.x, t.y, Color(1, 0, 0))
	_mask_tex.update(_mask_img)
	_material.set_shader_parameter("mask_origin", Vector2(origin.x * cs, origin.y * cs))


# --- Fabrication des plaques ----------------------------------------------

func _px(x: float) -> float:
	return Geo.lon_to_pixel_x(Geo.local_to_lon(world.origin_lat, world.origin_lon, x), zoom)


func _py(z: float) -> float:
	return Geo.lat_to_pixel_y(Geo.local_to_lat(world.origin_lat, z), zoom)


## Altitude réelle approchée (m) au point local (x, z), NAN si pas encore chargée.
func height_at(x: float, z: float) -> float:
	return tiles.height_at(_px(x), _py(z))


## Vrai si les altitudes et l'occupation du sol de la plaque sont là ; sinon les demande.
func _ensure_data(k: Vector2i) -> bool:
	var x0 := k.x * PATCH - 80.0
	var x1 := (k.x + 1) * PATCH + 80.0
	var z0 := k.y * PATCH - 80.0
	var z1 := (k.y + 1) * PATCH + 80.0
	var t0 := ElevationTiles.tile_of_pixel(_px(x0) - 1.0, _py(z0) - 1.0)
	var t1 := ElevationTiles.tile_of_pixel(_px(x1) + 1.0, _py(z1) + 1.0)
	var ready := true
	for tx in range(t0.x, t1.x + 1):
		for ty in range(t0.y, t1.y + 1):
			var t := Vector2i(tx, ty)
			if not tiles.has_tile(t):
				tiles.request_tile(t)
				ready = ready and tiles.has_tile(t)
	for corner in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		var ll := world.local_to_lat_lon(corner.x, corner.y)
		if not world.land.is_ready_at(ll.x, ll.y):
			world.land.request_at(ll.x, ll.y)
			ready = false
	return ready


## Fil principal : recopie les données utiles (altitudes, biomes) de la plaque.
## La grille a une maille de marge de chaque côté pour calculer les pentes.
func _prepare(k: Vector2i, res: int) -> Dictionary:
	var step := PATCH / res
	var n := res + 3
	var pxs := PackedFloat64Array()
	var lons := PackedFloat64Array()
	pxs.resize(n)
	lons.resize(n)
	for i in n:
		var x := k.x * PATCH + (i - 1) * step
		pxs[i] = _px(x)
		lons[i] = Geo.local_to_lon(world.origin_lat, world.origin_lon, x)
	var pys := PackedFloat64Array()
	var lats := PackedFloat64Array()
	pys.resize(n)
	lats.resize(n)
	for j in n:
		var z := k.y * PATCH + (j - 1) * step
		pys[j] = _py(z)
		lats[j] = Geo.local_to_lat(world.origin_lat, z)
	return {"k": k, "res": res, "gen": _generation, "step": step,
		"pxs": pxs, "pys": pys, "win": tiles.grab_window(pxs, pys),
		"bio": world.land.sample_grid(lats, lons)}


## Calcul pur du maillage (peut tourner sur un autre fil : ne lit que job).
static func compute(job: Dictionary) -> void:
	var res: int = job.res
	var step: float = job.step
	var n := res + 3
	var h := ElevationTiles.interpolate_window(job.win, job.pxs, job.pys)
	var bio: PackedByteArray = job.bio
	var v := res + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var normals := PackedVector3Array()
	verts.resize(v * v)
	cols.resize(v * v)
	normals.resize(v * v)
	for j in v:
		for i in v:
			var g := (i + 1) + (j + 1) * n
			var hc := h[g]
			var code := bio[g]
			var dx := h[g + 1] - h[g - 1]
			var dz := h[g + n] - h[g - n]
			var slope := maxf(absf(dx), absf(dz)) * 0.5 / step
			var y := hc
			var col: Color
			var kind := TerrainWorld.cell_kind_id(hc, slope, code)
			if hc < 0.0:
				kind = TerrainWorld.Kind.MER
			if kind == TerrainWorld.Kind.MER or kind == TerrainWorld.Kind.LAC:
				# Alpha 0 : surface d'eau (lisse et brillante dans le shader).
				col = WATER_FAR.srgb_to_linear()
				col.a = 0.0
				if kind == TerrainWorld.Kind.MER:
					y = TerrainWorld.WATER_LEVEL - 0.4
					dx = 0.0
					dz = 0.0
			else:
				col = TerrainWorld._color_for_id(kind, hc)
			var o := i + j * v
			verts[o] = Vector3(i * step, y, j * step)
			cols[o] = col
			normals[o] = Vector3(-dx / (2.0 * step), 1.0, -dz / (2.0 * step)).normalized()
	var idx := PackedInt32Array()
	idx.resize(res * res * 6)
	var m := 0
	for j in res:
		for i in res:
			var a := i + j * v
			var b := a + 1
			var c := a + 1 + v
			var d := a + v
			idx[m] = a; idx[m + 1] = b; idx[m + 2] = c
			idx[m + 3] = a; idx[m + 4] = c; idx[m + 5] = d
			m += 6
	# Jupe : un rebord qui descend sous la plaque, pour boucher les fentes
	# entre deux niveaux de détail ou au bord des blocs détaillés.
	var skirt := step * 1.5 + 15.0
	var ring: Array[int] = []
	for i in v:
		ring.append(i)
	for j in range(1, v):
		ring.append(res + j * v)
	for i in range(res - 1, -1, -1):
		ring.append(i + res * v)
	for j in range(res - 1, 0, -1):
		ring.append(j * v)
	var base := verts.size()
	for r in ring:
		verts.append(verts[r] - Vector3(0.0, skirt, 0.0))
		cols.append(cols[r].darkened(0.15))
		normals.append(normals[r])
	for q in ring.size():
		var a0: int = ring[q]
		var a1: int = ring[(q + 1) % ring.size()]
		var b0 := base + q
		var b1 := base + (q + 1) % ring.size()
		idx.append_array(PackedInt32Array([a0, a1, b1, a0, b1, b0]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	job.arrays = arrays


func _apply(job: Dictionary) -> void:
	var k: Vector2i = job.k
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, job.arrays)
	var p: Dictionary = patches.get(k, {})
	var mi: MeshInstance3D
	if p.is_empty():
		mi = MeshInstance3D.new()
		mi.name = "Plaque_%d_%d" % [k.x, k.y]
		mi.position = Vector3(k.x * PATCH, 0.0, k.y * PATCH)
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# La courbure de la Terre abaisse les sommets dans le shader.
		mi.extra_cull_margin = 40.0
		add_child(mi)
	else:
		mi = p.mi
	mi.visible = true
	mi.mesh = mesh
	patches[k] = {"mi": mi, "res": job.res}
