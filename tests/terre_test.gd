extends SceneTree
## Test du mode Terre : conversions géographiques, décodage des tuiles,
## génération des blocs, sélection à la souris, terrassement, sauvegarde.
## Fonctionne sans réseau (tuiles synthétiques).
## Usage : godot --headless --path . --script res://tests/terre_test.gd
## Option : -- --screenshot chemin.png --place lat,lon  (nécessite un affichage)

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


## Tuile synthétique : pente douce vers l'Est, mer à l'Ouest, une falaise au Nord.
func _fake_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := t.x * 256 + x
			var gy := t.y * 256 + y
			var h := float(gx - 4_247_700) * 0.8
			if gy < 2_885_800:
				h += 15.0
			a[y * 256 + x] = h
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	var place := ""
	var dist := 150.0
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--distance" and i + 1 < args.size():
			dist = args[i + 1].to_float()
		if args[i] == "--place" and i + 1 < args.size():
			place = args[i + 1]

	print("Conversions :")
	var px := Geo.lon_to_pixel_x(2.2945, 15)
	var py := Geo.lat_to_pixel_y(48.8584, 15)
	_check(ElevationTiles.tile_of_pixel(px, py) == Vector2i(16592, 11272), "Tour Eiffel -> tuile 15/16592/11272")
	_check(Geo.parse_lat_lon("48.8584, 2.2945") == Vector2(48.8584, 2.2945), "lecture « 48.8584, 2.2945 »")
	_check(Geo.parse_lat_lon("48,8584 2,2945") == Vector2(48.8584, 2.2945), "lecture à la française « 48,8584 2,2945 »")
	_check(Geo.parse_lat_lon("bonjour") == null, "texte invalide refusé")
	var lat1 := Geo.local_to_lat(45.0, 1000.0)
	_check(absf((45.0 - lat1) * 111_319.5 - 1000.0) < 1.0, "1 000 m vers le Sud ≈ 0,009°")

	# Décodage Terrarium : R=128,G=0,B=0 -> 0 m ; R=129,G=44,B=128 -> 300,5 m.
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color8(128, 0, 0))
	img.set_pixel(3, 0, Color8(129, 44, 128))
	var dec := ElevationTiles._decode(img.save_png_to_buffer())
	_check(dec.size() == 65536 and dec[0] == 0.0 and absf(dec[3] - 300.5) < 0.01, "décodage des couleurs Terrarium")

	# Vraie tuile en cache (si présente) : le sol au pied de la tour Eiffel est vers 33 m.
	# Lecture d'un en-tête GeoTIFF minimal (format des fichiers WorldCover).
	var tif := PackedByteArray([0x49, 0x49, 42, 0, 8, 0, 0, 0])
	var entries := [[259, 3, 1, 8], [322, 3, 1, 1024], [323, 3, 1, 1024], [324, 4, 1, 5000], [325, 4, 1, 1234]]
	tif.append_array(PackedByteArray([entries.size(), 0]))
	for e in entries:
		var b := PackedByteArray()
		b.resize(12)
		b.encode_u16(0, e[0]); b.encode_u16(2, e[1]); b.encode_u32(4, e[2]); b.encode_u32(8, e[3])
		tif.append_array(b)
	tif.append_array(PackedByteArray([0, 0, 0, 0]))
	var parsed := LandCover.parse_tiff_header(tif)
	_check(not parsed.is_empty() and parsed.offs[0] == 5000 and parsed.cnts[0] == 1234, "lecture d'un en-tête GeoTIFF")
	_check(LandCover.file_name(46.2, 6.14) == "ESA_WorldCover_10m_2021_v200_N45E006_Map.tif", "fichier WorldCover de Genève")
	_check(LandCover.file_name(-22.9, -43.2) == "ESA_WorldCover_10m_2021_v200_S24W045_Map.tif", "fichier WorldCover de Rio")
	var zbuf := PackedByteArray()
	zbuf.resize(1024 * 1024)
	zbuf.fill(30)
	_check(zbuf.compress(FileAccess.COMPRESSION_DEFLATE).decompress(1024 * 1024, FileAccess.COMPRESSION_DEFLATE) == zbuf, "décompression des blocs")

	var cache := "user://terrain_cache/15_16592_11272.png"
	if FileAccess.file_exists(cache):
		var real := ElevationTiles.new()
		root.add_child(real)
		real.request_tile(Vector2i(16592, 11272))
		var he := real.height_at(px, py)
		_check(he > 25.0 and he < 45.0, "altitude réelle au pied de la tour Eiffel : %.1f m" % he)
		real.queue_free()
	else:
		print("  --  tuile réelle absente du cache : vérification de l'altitude ignorée")

	print("Terrain :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	if place != "":
		var v: Variant = Geo.parse_lat_lon(place)
		print("Lieu : ", v)
		world.set_origin(v.x, v.y)
	else:
		world.tiles.offline_generator = _fake_tile
		# Forêt au Nord de l'origine, champs au Sud, un lac à l'Est.
		world.land.offline_generator = func(lat: float, lon: float) -> int:
			if lon > 2.2945 + 0.0006 and lon < 2.2945 + 0.0009:
				return 80
			return 10 if lat > 48.8584 else 40
		world.set_origin(48.8584, 2.2945)
	for i in 120:
		await process_frame
		if world.tiles.pending_count() == 0 and i > 60:
			break

	if place != "":
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 60_000:
			await process_frame
			if world.tiles.pending_count() == 0 and world.chunks.size() > 40 and world._dirty.is_empty():
				break
		print("Blocs : %d, tuiles : %d, en attente : %d" % [world.chunks.size(), world.tiles.loaded_count(), world.tiles.pending_count()])
		if shot != "":
			var rig = scene.get_node("CameraRig")
			rig._distance = dist
			rig._target_distance = dist
			rig.rotation_degrees.y = 25.0
			for i in 30:
				await process_frame
			var im := root.get_viewport().get_texture().get_image()
			im.save_png(shot)
			print("Capture : ", shot)
		quit(0)
		return

	_check(world.chunks.size() >= 12, "blocs générés autour de la caméra (%d)" % world.chunks.size())
	var mi: MeshInstance3D = world.chunks.values()[0]
	_check(mi.mesh != null and mi.mesh.get_surface_count() == 1, "maillage de bloc construit")

	var h0 := world.cell_height(Vector2i(0, 0))
	var raw := world.raw_height(0.5, 0.5)
	_check(not is_nan(h0) and absf(h0 - raw) <= world.height_step / 2.0 + 0.001, "hauteur de case arrondie au pas (%.2f ~ %.2f)" % [h0, raw])
	var west := world.cell_height(Vector2i(-300, 0))
	_check(west < 0.0, "la mer apparaît à l'Ouest (%.1f m)" % west)
	_check(TerrainWorld.cell_kind(west, 0.0) == "Mer", "type de case « Mer »")

	print("Biomes :")
	_check(world.cell_kind_at(Vector2i(5, -20)) == "Forêt", "forêt au Nord (%s)" % world.cell_kind_at(Vector2i(5, -20)))
	_check(world.cell_kind_at(Vector2i(5, 20)) == "Champs", "champs au Sud (%s)" % world.cell_kind_at(Vector2i(5, 20)))
	_check(world.cell_kind_at(Vector2i(55, 5)) == "Lac / rivière", "lac à l'Est (%s)" % world.cell_kind_at(Vector2i(55, 5)))
	_check(TerrainWorld.cell_kind(500.0, 0.0, 70) == "Glacier", "code 70 -> Glacier")
	_check(TerrainWorld.cell_kind(200.0, 0.0, 60) == "Désert" and TerrainWorld.cell_kind(2500.0, 0.0, 60) == "Roche", "sol nu -> désert en plaine, roche en montagne")
	_check(TerrainWorld.cell_kind(-3.0, 0.0, 40) == "Champs", "polder sous le niveau de la mer reste un champ")
	var north: MeshInstance3D = world.chunks.get(Vector2i(0, -1))
	var trees := 0
	if north:
		for ch in north.get_children():
			if ch is MultiMeshInstance3D:
				trees += (ch as MultiMeshInstance3D).multimesh.instance_count
	_check(trees > 100, "arbres plantés dans la forêt (%d)" % trees)
	var south: MeshInstance3D = world.chunks.get(Vector2i(0, 1))
	_check(south != null and south.get_child_count() == 0, "pas d'arbres dans les champs")
	world.tree_blocker = func(c: Vector2i) -> bool: return true
	world.mark_cells_dirty([Vector2i(10, -10)])
	for i in 120:
		await process_frame
		if world._dirty.is_empty() and world._jobs.is_empty():
			break
	var blocked := 0
	for ch in north.get_children():
		if ch is MultiMeshInstance3D and not ch.is_queued_for_deletion():
			blocked += 1
	_check(blocked == 0, "tree_blocker empêche les arbres")
	world.tree_blocker = Callable()

	var hit: Variant = world.pick_cell(Vector3(0.5, h0 + 80.0, 0.5), Vector3.DOWN)
	_check(hit == Vector2i(0, 0), "rayon vertical -> case 0, 0")
	var hit2: Variant = world.pick_cell(Vector3(10.5, h0 + 80.0, 60.5), Vector3(0, -1, -1).normalized())
	_check(hit2 != null, "rayon oblique touche le terrain (%s)" % [hit2])

	world.set_tool(TerrainWorld.Tool.FLATTEN)
	var n := world.apply_tool(Vector2i(0, 0), Vector2i(9, 9))
	_check(n == 100, "aplanir 10 × 10 cases")
	var flat := true
	for x in 10:
		for z in 10:
			flat = flat and world.cell_height(Vector2i(x, z)) == h0
	_check(flat, "les 100 cases sont à la même hauteur")
	world.set_tool(TerrainWorld.Tool.RAISE)
	world.apply_tool(Vector2i(2, 2), Vector2i(2, 2))
	_check(world.cell_height(Vector2i(2, 2)) == h0 + 1.0, "monter une case de 1 m")
	_check(world._dirty.size() > 0, "blocs touchés marqués à reconstruire")
	for i in 120:
		await process_frame
		if world._dirty.is_empty() and world._jobs.is_empty():
			break
	_check(world._dirty.is_empty(), "blocs reconstruits")

	_check(world.save_world(), "sauvegarde")
	world.set_origin(45.8326, 6.8652)
	_check(world.modifications.is_empty(), "changer de lieu repart d'une région vierge")
	_check(world.load_world(), "chargement")
	_check(is_equal_approx(world.origin_lat, 48.8584) and world.modifications.size() == 100, "lieu et modifications restaurés")
	_check(world.cell_height(Vector2i(2, 2)) == h0 + 1.0, "case modifiée retrouvée")

	print("TERRE TEST OK" if ok else "TERRE TEST ÉCHEC")
	quit(0 if ok else 1)
