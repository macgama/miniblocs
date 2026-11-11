extends SceneTree
## Banc d'essai des performances sur une région de 10 × 10 km (sans réseau).
## Usage : godot --headless --path . --script res://tests/perf_bench.gd [-- --big] [--reseau]
## --reseau : vraies données autour d'Annecy (téléchargées puis gardées en cache).
## Mesure : chargement initial du terrain, survol rapide de la région,
## grande ville (routes en grille, zonage), sauvegarde et chargement.
## Affiche des temps en millisecondes et « PERF BENCH OK ».

var _frame_ms: Array[float] = []
var _last_usec := 0


func _initialize() -> void:
	_run.call_deferred()


## Collines et vallées douces (de 0 à ~120 m), une mer au Sud-Ouest.
func _hilly_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := float(t.x * 256 + x)
			var gy := float(t.y * 256 + y)
			a[y * 256 + x] = 60.0 + sin(gx * 0.004) * 35.0 + cos(gy * 0.0031) * 30.0 + sin((gx + gy) * 0.02) * 4.0
	return a


func _biome(lat: float, lon: float) -> int:
	var v := absi(hash(Vector2i(int(lat * 400.0), int(lon * 400.0)))) % 10
	if v < 4:
		return 10 # forêt
	if v < 7:
		return 30
	if v < 9:
		return 40
	return 80


func _stats(label: String, a: Array[float]) -> String:
	if a.is_empty():
		return label + " : aucune image"
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	return "%s : %d images, moyenne %.2f ms, médiane %.2f ms, 95e centile %.2f ms, pire %.2f ms" % [
		label, s.size(), sum / s.size(), s[s.size() / 2], s[int(s.size() * 0.95)], s[-1]]


func _frame() -> void:
	await process_frame
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frame_ms.append((now - _last_usec) / 1000.0)
	_last_usec = now


func _run() -> void:
	var big := OS.get_cmdline_user_args().has("--big")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var zs: ZoneSystem = scene.get_node("Zones")
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	var real := OS.get_cmdline_user_args().has("--reseau")
	if real:
		# Vraies données (Annecy) : on attend d'abord les téléchargements.
		world.set_origin(45.9, 6.13)
		while world.tiles.pending_count() > 0 or world.land.pending_count() > 0 or world.chunks.size() < 20:
			await process_frame
		world.set_process(false)
		for k in world.chunks.keys():
			world.chunks[k].queue_free()
		world.chunks.clear()
		await process_frame
		world.set_process(true)
	else:
		world.tiles.offline_generator = _hilly_tile
		world.land.offline_generator = _biome
	var t0 := Time.get_ticks_usec()
	if not real:
		world.set_origin(45.9, 6.13)
	rig._distance = 200.0
	rig._target_distance = 200.0

	# 1. Chargement initial : jusqu'à ce que plus aucun bloc ne manque.
	var frames := 0
	while frames < 2000:
		await _frame()
		frames += 1
		if frames > 5 and world.missing_chunk_count() == 0:
			break
	print("Chargement initial : %d blocs en %.0f ms (%d images)" % [world.chunks.size(), (Time.get_ticks_usec() - t0) / 1000.0, frames])
	print(_stats("  images pendant le chargement", _frame_ms))

	# 2. Survol : 4 km en ligne droite à ~140 m/s.
	_frame_ms.clear()
	_last_usec = 0
	for i in 600:
		rig.position.x = -2000.0 + i * (4000.0 / 600.0)
		rig.position.z = 300.0 * sin(i * 0.01)
		await _frame()
	print(_stats("Survol de 4 km", _frame_ms))

	# 3. Grande ville : grille de routes, zones, croissance.
	rig.position = Vector3.ZERO
	for i in 120:
		await _frame()
	bs.unlimited_money = true
	zs.growth = false
	var n_roads := 12 if big else 6
	var span := 150.0 * n_roads / 2.0
	t0 = Time.get_ticks_usec()
	var built := 0
	for k in n_roads + 1:
		var v := -span + k * 150.0
		for seg in [[Vector3(v, 0, -span), Vector3(v, 0, span)], [Vector3(-span, 0, v), Vector3(span, 0, v)]]:
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			a.y = world.cell_height(Vector2i(int(a.x), int(a.z)))
			b.y = world.cell_height(Vector2i(int(b.x), int(b.z)))
			var r := transport.build_segment("route", a, b)
			if r.ok:
				built += 1
	print("Routes : %d tronçons posés en %.0f ms (%d nœuds, %d tronçons)" % [built, (Time.get_ticks_usec() - t0) / 1000.0,
		transport.network.nodes.size(), transport.network.edges.size()])
	for k in n_roads:
		for l in n_roads:
			var kinds := ["R", "R", "C", "I"]
			zs.add_zone(kinds[(k + l) % 4], Rect2i(int(-span + k * 150 + 6), int(-span + l * 150 + 6), 138, 138))
	t0 = Time.get_ticks_usec()
	var steps := 1500 if big else 600
	var grown := 0
	for i in steps:
		if zs.grow_step() >= 0:
			grown += 1
	print("Zonage : %d tentatives, %d bâtiments poussés en %.0f ms (%.2f ms par tentative)" % [steps, grown,
		(Time.get_ticks_usec() - t0) / 1000.0, (Time.get_ticks_usec() - t0) / 1000.0 / steps])
	print(bs.summary())

	_frame_ms.clear()
	_last_usec = 0
	for i in 300:
		rig.position.x = -span + i * (2.0 * span / 300.0)
		await _frame()
	print(_stats("Survol de la ville (circulation active)", _frame_ms))

	# 4. Sauvegarde et chargement.
	t0 = Time.get_ticks_usec()
	var main = scene
	main.save_game()
	var save_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var loaded: bool = main.load_game()
	print("Sauvegarde %.0f ms, chargement %.0f ms (%s)" % [save_ms, (Time.get_ticks_usec() - t0) / 1000.0, "ok" if loaded else "ÉCHEC"])
	print(bs.summary())
	print("PERF BENCH OK")
	quit(0)
