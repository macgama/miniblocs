extends SceneTree
## Test du relief lointain (HorizonTerrain) et de la caméra rasante : niveaux de
## détail, montagne et mer au loin, masque sous les blocs détaillés, bornes de
## l'inclinaison, caméra qui reste au-dessus du sol.
## Fonctionne sans réseau (tuiles synthétiques).
## Usage : godot --headless --path . --script res://tests/horizon_test.gd

var ok := true
var world: TerrainWorld


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


## Relief lointain : une montagne de 600 m à 3 km à l'Est, la mer à plus de 4 km à l'Ouest.
static func far_terrain(x: float, z: float) -> float:
	if x < -4000.0:
		return -30.0
	return 40.0 + 560.0 * exp(-((x - 3000.0) * (x - 3000.0) + z * z) / 250000.0)


## Relief détaillé : plat à 40 m.
func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _far_tile(t: Vector2i) -> PackedFloat32Array:
	var z := world.horizon.zoom
	var px0 := Geo.lon_to_pixel_x(world.origin_lon, z)
	var py0 := Geo.lat_to_pixel_y(world.origin_lat, z)
	var ppm := world._px_per_m / pow(2.0, ElevationTiles.ZOOM - z)
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			a[y * 256 + x] = far_terrain((t.x * 256 + x - px0) / ppm, (t.y * 256 + y - py0) / ppm)
	return a


func _max_y(p: Dictionary) -> float:
	var mesh: ArrayMesh = (p.mi as MeshInstance3D).mesh
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var m := -INF
	for v in verts:
		m = maxf(m, v.y)
	return m


func _run() -> void:
	print("Niveaux de détail :")
	_check(HorizonTerrain.level_for(100.0) == 64 and HorizonTerrain.level_for(3000.0) == 32
		and HorizonTerrain.level_for(8000.0) == 16, "16 m près, 32 m plus loin, 64 m vers l'horizon")
	_check(HorizonTerrain.patch_distance(Vector2i(0, 0), Vector3(500, 0, 500)) == 0.0
		and HorizonTerrain.patch_distance(Vector2i(2, 0), Vector3.ZERO) == 2048.0, "distance à une plaque")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	root.add_child(scene)
	world.water.offline = true
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.horizon.tiles.offline_generator = _far_tile
	world.horizon.radius = 7000.0
	world.set_origin(45.0, 6.0)
	var h := world.horizon
	var t0 := Time.get_ticks_msec()
	var stable := 0
	while Time.get_ticks_msec() - t0 < 90_000:
		await process_frame
		var n := h.patches.size()
		h.finish_jobs()
		stable = stable + 1 if n == h.patches.size() and n > 0 else 0
		if stable > 30 and world.missing_chunk_count() == 0:
			break
	print("Plaques : %d, blocs détaillés : %d (%d ms)" % [h.patches.size(), world.chunks.size(), Time.get_ticks_msec() - t0])

	print("Relief lointain :")
	var expected := 0
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			if HorizonTerrain.patch_distance(Vector2i(dx, dz), Vector3.ZERO) <= h.radius:
				expected += 1
	_check(h.patches.size() == expected, "toutes les plaques jusqu'à 7 km (%d / %d)" % [h.patches.size(), expected])
	_check(h.patches.has(Vector2i(0, 0)) and h.patches[Vector2i(0, 0)].res == 64, "plaque du centre détaillée (maille de 16 m)")
	_check(h.patches.has(Vector2i(6, 0)) and h.patches[Vector2i(6, 0)].res == 16, "plaque à 6 km grossière (maille de 64 m)")
	var mont: Dictionary = h.patches.get(Vector2i(2, -1), {})
	var mont2: Dictionary = h.patches.get(Vector2i(2, 0), {})
	_check(not mont.is_empty() and maxf(_max_y(mont), _max_y(mont2)) > 450.0, "la montagne à 3 km dépasse 450 m (%.0f m)" % maxf(_max_y(mont), _max_y(mont2)))
	var sea: Dictionary = h.patches.get(Vector2i(-6, 0), {})
	_check(not sea.is_empty() and absf(_max_y(sea) - (TerrainWorld.WATER_LEVEL - 0.4)) < 0.01, "la mer au loin est à plat sous le niveau de l'eau")
	_check(absf(h.height_at(3000.0, 0.0) - 600.0) < 25.0, "altitude lointaine lue (%.0f m)" % h.height_at(3000.0, 0.0))

	print("Masque des blocs détaillés :")
	var half := h._mask_size / 2
	_check(h._mask_img.get_pixel(half, half).r > 0.5, "sous le bloc détaillé du centre : plaque effacée")
	_check(h._mask_img.get_pixel(1, 1).r < 0.5, "loin du centre : plaque visible")

	print("Caméra rasante :")
	var rig = scene.get_node("CameraRig")
	rig.set_pitch(2.0, true)
	_check(is_equal_approx(rig.get_target_pitch(), rig.min_pitch), "inclinaison bornée à %d° au plus bas" % rig.min_pitch)
	rig.set_pitch(95.0, true)
	_check(is_equal_approx(rig.get_target_pitch(), rig.max_pitch), "inclinaison bornée à %d° au plus haut" % rig.max_pitch)
	rig.set_pitch(8.0, true)
	rig._target_distance = 8.0
	rig._distance = 8.0
	for i in 30:
		await process_frame
	var cam: Camera3D = rig.get_node("Camera3D")
	_check(cam.global_position.y >= 40.0 + rig.ground_clearance - 0.05, "la caméra reste au-dessus du sol (%.1f m)" % cam.global_position.y)
	_check(cam.far >= h.radius, "la caméra voit jusqu'à l'horizon (%.0f m)" % cam.far)

	scene.queue_free()
	await process_frame
	print("HORIZON TEST OK" if ok else "HORIZON TEST ÉCHEC")
	quit(0 if ok else 1)
