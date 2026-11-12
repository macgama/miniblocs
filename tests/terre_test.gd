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

	print("Zones de rivières :")
	_check(WaterMap.zone_of(0, 0) == Vector2i.ZERO and WaterMap.zone_of(5200, -4900) == Vector2i(1, 0) and WaterMap.zone_of(-15100, 0) == Vector2i(-2, 0), "zones de 10 × 10 km")
	_check(WaterMap.zone_rect(Vector2i(1, -1)) == Rect2(5000, -15000, 10000, 10000), "rectangle d'une zone")
	_check(GameStart.REGION_SIZE >= 40000.0, "région de jeu de 40 × 40 km")
	print("Rivières :")
	# Vallée en V qui descend vers le Sud : l'eau doit suivre le fond (x = 30).
	var vw := 61
	var vh := 80
	var velev := PackedFloat32Array()
	velev.resize(vw * vh)
	for y in vh:
		for x in vw:
			velev[x + y * vw] = 10.0 + absf(x - 30) * 2.0 + float(vh - y) * 0.5
	var streams := WaterMap.compute_streams(velev, vw, vh, 30.0)
	var all_pts := PackedVector2Array()
	var reaches_end := false
	var widths_grow := true
	var prev_w := 0.0
	for l in streams.lines:
		var pl: PackedVector2Array = l[0]
		all_pts.append_array(pl)
		reaches_end = reaches_end or pl[pl.size() - 1].y >= vh - 2
		widths_grow = widths_grow and float(l[1]) >= prev_w
		prev_w = float(l[1])
	var on_floor := all_pts.size() > 10
	for q in all_pts:
		on_floor = on_floor and (absf(q.x - 30.0) <= 1.0 or q.y >= vh - 2)
	_check(on_floor, "le ruisseau calculé suit le fond de la vallée (%d points)" % all_pts.size())
	_check(reaches_end, "il coule vers l'aval (le Sud)")
	_check(widths_grow and prev_w > float(streams.lines[0][1]), "il s'élargit vers l'aval (%.1f -> %.1f m)" % [float(streams.lines[0][1]), prev_w])
	var smooth := WaterMap._chaikin(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)]), 2)
	_check(smooth.size() > 3 and smooth[0] == Vector2(0, 0) and smooth[smooth.size() - 1] == Vector2(10, 10), "lissage des tracés")
	# Réponse OpenStreetMap (Overpass, « out geom ») : une rivière et un étang.
	var wm := WaterMap.new()
	wm.offline = true
	wm.set_origin(48.8584, 2.2945)
	var fixture := {"elements": [
		{"type": "way", "tags": {"waterway": "river", "name": "Seine", "width": "30"},
			"geometry": [{"lat": 48.8584, "lon": 2.2900}, {"lat": 48.8584, "lon": 2.2990}]},
		{"type": "way", "tags": {"waterway": "stream"},
			"geometry": [{"lat": 48.8570, "lon": 2.2945}, {"lat": 48.8560, "lon": 2.2945}]},
		{"type": "way", "tags": {"natural": "water", "name": "Étang test"},
			"geometry": [{"lat": 48.8600, "lon": 2.2940}, {"lat": 48.8600, "lon": 2.2950},
				{"lat": 48.8605, "lon": 2.2950}, {"lat": 48.8605, "lon": 2.2940}, {"lat": 48.8600, "lon": 2.2940}]}]}
	_check(wm._apply_osm_text(JSON.stringify(fixture), wm._generation), "lecture d'une réponse OpenStreetMap")
	_check(wm.source == WaterMap.Source.OSM, "source = OpenStreetMap")
	_check(wm.width_at(0.0, 10.0) == 30.0 and wm.width_at(0.0, 20.0) == 0.0, "largeur de la Seine (30 m de large)")
	_check(wm.name_at(0.0, 0.0) == "Seine", "nom de la rivière")
	var stream_z := -Geo.EARTH_RADIUS * deg_to_rad(48.8565 - 48.8584)
	_check(wm.width_at(0.3, stream_z) == 2.0 and wm.width_at(2.0, stream_z) == 0.0, "ruisseau étroit (2 m)")
	var pond_z := -Geo.EARTH_RADIUS * deg_to_rad(48.86025 - 48.8584)
	_check(wm.width_at(0.0, pond_z) == WaterMap.POND_WIDTH and wm.name_at(0.0, pond_z) == "Étang test", "étang")
	wm.free()
	print('FREED')

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
		world.water.offline = true
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
		while Time.get_ticks_msec() - t0 < 120_000:
			await process_frame
			if world.tiles.pending_count() == 0 and world.chunks.size() > 40 and world._dirty.is_empty() and world.water.is_ready():
				break
		print("Blocs : %d, tuiles : %d, en attente : %d" % [world.chunks.size(), world.tiles.loaded_count(), world.tiles.pending_count()])
		print(world.water.status, " (", Time.get_ticks_msec() - t0, " ms)")
		if shot != "":
			var rig = scene.get_node("CameraRig")
			if "--water" in args:
				# Vise le cours d'eau (d'au moins 3 m) le plus proche du centre.
				var best := INF
				var spot := Vector2.ZERO
				for si in world.water.seg_a.size():
					var mid: Vector2 = (world.water.seg_a[si] + world.water.seg_b[si]) * 0.5
					if world.water.seg_w[si] >= 3.0 and mid.length() < best:
						best = mid.length()
						spot = mid
				print("Cours d'eau visé : ", spot)
				rig.position = Vector3(spot.x, rig.position.y, spot.y)
				var t1 := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t1 < 60_000:
					await process_frame
					if world.tiles.pending_count() == 0 and world._dirty.is_empty() and Time.get_ticks_msec() - t1 > 3000:
						break
				if "--bridge" in args:
					# Une départementale qui traverse le cours d'eau.
					var tr: TransportSystem = scene.get_node("Transport")
					var built := tr.build_path("departementale", {}, PackedVector2Array([spot + Vector2(-50, 30), spot + Vector2(50, -30)]))
					print("Route : ", built.get("ok"), " ", built.get("reason", ""))
					for i in 60:
						await process_frame
			var tide_i := args.find("--tide")
			if tide_i >= 0:
				# Marée « high » ou « low » en plein jour, temps ensoleillé.
				var want_high: bool = args[tide_i + 1] == "high"
				var amb: DayNight = scene.ambiance
				amb.weather.mode = Meteo.Mode.SOLEIL
				var best_t := amb.unix_time
				var best_l := -INF if want_high else INF
				for i in 6 * 24 * 3:
					var tt := amb.unix_time + i * 600.0
					var hour := fposmod((tt / 3600.0) + amb.utc_offset(), 24.0)
					if hour < 10.0 or hour > 16.0:
						continue
					var l := Maree.level_at(tt, world.origin_lat, world.origin_lon)
					if (want_high and l > best_l) or (not want_high and l < best_l):
						best_l = l
						best_t = tt
				amb.unix_time = best_t
				print("Marée : %.1f m" % best_l)
				for i in 60:
					await process_frame
			if "--far" in args:
				# Va à 14 km à l'Est : relief, biomes et rivières doivent suivre.
				rig.position.x = 14000.0
				var t2 := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t2 < 90_000:
					await process_frame
					if world.missing_chunk_count() == 0 and world.water.is_ready_at(14000.0, 0.0) and Time.get_ticks_msec() - t2 > 3000:
						break
				print("Loin : blocs manquants %d, rivières prêtes %s, %s (%d ms)" % [world.missing_chunk_count(), world.water.is_ready_at(14000.0, 0.0), world.water.status, Time.get_ticks_msec() - t2])
			if "--paysage" in args:
				# Démonstration des pinceaux : un lac, un canal, une colline boisée, un désert.
				var c0 := Vector2i(floori(rig.position.x), floori(rig.position.z))
				world.brush_radius = 7
				world.set_tool(TerrainWorld.Tool.DIG_WATER)
				world._stroke_level = NAN
				for dx in range(-6, 7, 3):
					world.apply_brush(c0 + Vector2i(dx, 0))
				world.brush_radius = 1
				for dz in range(5, 40, 2):
					world.apply_brush(c0 + Vector2i(dz / 3, dz))
				world.brush_radius = 8
				world.set_tool(TerrainWorld.Tool.HILL)
				for i in 3:
					world.apply_brush(c0 + Vector2i(-28, -20))
				world.set_tool(TerrainWorld.Tool.SMOOTH)
				world.apply_brush(c0 + Vector2i(-28, -20))
				world.set_tool(TerrainWorld.Tool.PLANT)
				world.apply_brush(c0 + Vector2i(-28, -20))
				world.set_tool(TerrainWorld.Tool.BIOME)
				world.paint_kind = TerrainWorld.Kind.DESERT
				world.brush_radius = 6
				for dx in range(20, 40, 4):
					world.apply_brush(c0 + Vector2i(dx, -15))
				world.set_tool(TerrainWorld.Tool.INSPECT)
				scene.hud.select_tool_silently(TerreHud.LANDSCAPE_TOOL)
				scene._on_tool_selected(TerreHud.LANDSCAPE_TOOL)
				for i in 120:
					await process_frame
					if world._dirty.is_empty() and world._jobs.is_empty():
						break
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

	print("Côtes :")
	var coast_x := 999
	for x in range(-400, 50):
		if world.cell_height(Vector2i(x, 20)) >= 0.0:
			coast_x = x
			break
	_check(coast_x < 50, "rivage trouvé à l'Ouest (x = %d)" % coast_x)
	_check(world.cell_kind_at(Vector2i(coast_x, 20)) == "Plage", "plage au bord de la mer (%s)" % world.cell_kind_at(Vector2i(coast_x, 20)))
	var ck := Vector2i(floori(coast_x / 64.0), 0)
	if world._ensure_tiles(ck):
		world._build_chunk(ck)
	var coast_chunk: MeshInstance3D = world.chunks.get(ck)
	if coast_chunk:
		var surf_node := coast_chunk.get_node_or_null("Ressac") as MeshInstance3D
		_check(surf_node != null and surf_node.material_override.get_shader_parameter("surf_only") == true, "écume du ressac le long du rivage")
		if surf_node:
			# La nappe d'écume couvre aussi l'estran : du sol sous le niveau moyen
			# et du sol au-dessus (que la marée haute recouvre).
			var uvs: PackedVector2Array = (surf_node.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			var lo := INF
			var hi := -INF
			for uv in uvs:
				lo = minf(lo, uv.x)
				hi = maxf(hi, uv.x)
			_check(lo < 0.0 and hi > 0.0, "le ressac couvre l'estran (sol de %.1f à %.1f m)" % [lo, hi])
	else:
		print("  --  bloc du rivage pas chargé : ressac non vérifié")

	print("Marées :")
	_check(Maree.amplitude(43.3, 5.37) < 0.3, "presque pas de marée à Marseille")
	_check(Maree.amplitude(48.65, -2.0) > 2.0, "grandes marées à Saint-Malo")
	_check(Maree.amplitude(42.0, 50.0) == 0.0, "pas de marée dans la mer Caspienne")
	# Deux pleines mers par jour lunaire (24 h 50) à Saint-Malo, le 12/11/2026.
	var t0 := 1794441600.0
	var highs := 0
	var prev := Maree.level_at(t0 - 600.0, 48.65, -2.0)
	var cur := Maree.level_at(t0, 48.65, -2.0)
	var top := -INF
	var bottom := INF
	for i in range(1, 150):
		var nxt := Maree.level_at(t0 + i * 600.0, 48.65, -2.0)
		if cur > prev and cur >= nxt:
			highs += 1
		top = maxf(top, cur)
		bottom = minf(bottom, cur)
		prev = cur
		cur = nxt
	_check(highs == 2, "deux pleines mers en 24 h 50 (%d)" % highs)
	_check(top > 1.5 and bottom < -1.5, "la mer monte et descend (%.1f à %.1f m)" % [bottom, top])
	# Vives-eaux (pleine lune) plus fortes que mortes-eaux (quartier).
	var springs := 0.0
	var neaps := 0.0
	for d in 30:
		var f := Maree.spring_factor(t0 + d * 86400.0)
		springs = maxf(springs, f)
		neaps = maxf(neaps, 2.0 - f)
	_check(springs > 1.2 and 2.0 - neaps < 0.8, "vives-eaux et mortes-eaux dans le mois")
	world.update_tide(t0)
	var l0 := Maree.level
	var sea_y := world._water.position.y
	var t_low := t0
	for i in 80:
		if Maree.level_at(t0 + i * 600.0, world.origin_lat, world.origin_lon) < l0 - 1.0:
			t_low = t0 + i * 600.0
			break
	world.update_tide(t_low)
	_check(absf(world._water.position.y - (TerrainWorld.WATER_LEVEL + Maree.level)) < 0.001 and world._water.position.y < sea_y, "le plan de la mer suit la marée")
	_check(world.sea_level() < l0 - 0.9 and (world._surf_material.get_shader_parameter("tide") as float) == Maree.level, "marée basse : la mer et l'écume descendent (%.1f m)" % world.sea_level())
	_check(Maree.high_water == Maree.max_level(world.origin_lat, world.origin_lon) and Maree.high_water > 1.0, "plus haute mer connue pour les ponts (%.1f m)" % Maree.high_water)
	_check(TerrainWorld.is_estran(-1.0, 80, 2.3) and not TerrainWorld.is_estran(-4.0, 80, 2.3) and not TerrainWorld.is_estran(-1.0, 40, 2.3), "estran : découvert à marée basse, pas les polders cultivés")
	world.update_tide(t0)
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
	var south_trees := 0
	var south_crops := 0
	if south:
		for ch in south.get_children():
			if ch is MultiMeshInstance3D and not ch.has_meta("loin"):
				var cat: int = ch.get_meta("categorie", -1)
				if cat == Plantes.Cat.ARBRE or cat == Plantes.Cat.ARBUSTE:
					south_trees += 1
				elif cat == Plantes.Cat.CULTURE:
					south_crops += (ch as MultiMeshInstance3D).multimesh.instance_count
	_check(south != null and south_trees == 0, "pas d'arbres dans les champs")
	_check(south_crops > 100, "cultures dans les champs (%d)" % south_crops)
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

	print("Eau douce :")
	# Une rivière de 4 m (x ≈ 20) et un ruisseau de 1 m en diagonale (x ≈ 30 à 36).
	world.water.add_line(PackedVector2Array([Vector2(20, -120), Vector2(20, 120)]), 4.0, "Rivière test")
	world.water.add_line(PackedVector2Array([Vector2(30, -60), Vector2(36, 60)]), 1.0)
	world.water.add_polygon(PackedVector2Array([Vector2(-20, 30), Vector2(-10, 30), Vector2(-10, 40), Vector2(-20, 40)]))
	world.water.water_changed.emit()
	_check(world._dirty.size() >= world.chunks.size(), "les blocs sont redessinés quand l'eau arrive")
	for i in 300:
		await process_frame
		if world._dirty.is_empty() and world._jobs.is_empty():
			break
	var rc := Vector2i(20, 10)
	var q := world._quantize(world.raw_height(20.5, 10.5))
	_check(world.cell_kind_at(rc) == "Rivière", "case de rivière (%s)" % world.cell_kind_at(rc))
	_check(world.water_name_at(rc) == "Rivière test", "nom du cours d'eau sur la case")
	_check(world.cell_height(rc) == q - 2.0 * world.height_step, "lit de rivière creusé de 1 m (%.1f / %.1f)" % [world.cell_height(rc), q])
	_check(absf(world.water_surface_at(20.5, 10.5) - (q - TerrainWorld.WATER_SURFACE_DROP)) < 0.001, "surface de l'eau juste sous la berge")
	_check(is_nan(world.water_surface_at(25.5, 10.5)), "pas d'eau sur la berge")
	_check(world.cell_kind_at(Vector2i(33, 0)) == "Ruisseau", "ruisseau de 1 m (%s)" % world.cell_kind_at(Vector2i(33, 0)))
	var qs := world._quantize(world.raw_height(33.5, 0.5))
	_check(world.cell_height(Vector2i(33, 0)) == qs - world.height_step, "ruisseau creusé d'une marche")
	_check(world.cell_kind_at(Vector2i(-15, 35)) == "Étang", "étang (%s)" % world.cell_kind_at(Vector2i(-15, 35)))
	var lake_s := world.water_surface_at(55.5, 5.5)
	_check(not is_nan(lake_s), "le lac WorldCover a une surface d'eau")
	_check(is_nan(world.water_surface_at(-300.5, 0.5)), "la mer n'est pas de l'eau douce")
	var c00: MeshInstance3D = world.chunks.get(Vector2i(0, 0))
	var eau: MeshInstance3D = c00.get_node_or_null("Eau") if c00 else null
	_check(eau != null and eau.mesh != null and eau.material_override is ShaderMaterial, "surface d'eau animée dans le bloc")
	var shore_v := 0
	var open_v := 0
	if eau:
		var cols: PackedColorArray = eau.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for col in cols:
			if col.r > 0.5:
				shore_v += 1
			else:
				open_v += 1
	_check(shore_v > 0 and open_v > 0, "écume sur les berges, eau libre au milieu (%d / %d)" % [shore_v, open_v])
	var trees_in_river := 0
	for ch in c00.get_children():
		if ch is MultiMeshInstance3D:
			var mm: MultiMesh = (ch as MultiMeshInstance3D).multimesh
			for t in mm.instance_count:
				var o := mm.get_instance_transform(t).origin
				if o.x >= 18.0 and o.x < 22.0:
					trees_in_river += 1
	_check(trees_in_river == 0, "pas d'arbres dans la rivière")
	# Une route qui traverse la rivière passe sur un pont.
	# (sol plat à 5 m, rivière de x = 19 à 21 et ruisseau en x = 34)
	var ground := func(_x: float, _z: float) -> float: return 5.0
	var river := func(x: float, _z: float) -> float:
		return 4.85 if (x >= 19.0 and x < 21.0) or (x >= 34.0 and x < 35.0) else NAN
	var cross := RoutePlanner.plan("rue", PackedVector2Array([Vector2(0, 10), Vector2(28, 10)]), NAN, NAN, ground, river)
	var bridge_ok := false
	var dry_ok := true
	for i in cross.pts.size():
		var px_: float = cross.pts[i].x
		if px_ >= 19.0 and px_ <= 21.0:
			bridge_ok = cross.st[i] == TransportTypes.Struct.BRIDGE and cross.pts[i].y >= 4.85 + 1.0
		if px_ < 10.0 and cross.st[i] == TransportTypes.Struct.BRIDGE:
			dry_ok = false
	_check(cross.ok and bridge_ok, "pont au-dessus de la rivière (%s)" % cross.reason)
	_check(dry_ok, "pas de pont loin de la rivière")
	var cross2 := RoutePlanner.plan("rue", PackedVector2Array([Vector2(26, 0), Vector2(42, 0)]), NAN, NAN, ground, river)
	var small_bridge := false
	for i in cross2.pts.size():
		if cross2.st[i] == TransportTypes.Struct.BRIDGE:
			small_bridge = true
	_check(small_bridge, "petit pont même sur un ruisseau de 1 m")
	var no_water := RoutePlanner.plan("rue", PackedVector2Array([Vector2(0, 10), Vector2(28, 10)]), NAN, NAN, ground)
	_check(no_water.ok, "plan() marche toujours sans le paramètre eau")

	print("Paysage :")
	world.brush_radius = 3
	world.set_tool(TerrainWorld.Tool.HILL)
	var hc0 := world.cell_height(Vector2i(120, -40))
	_check(world.apply_brush(Vector2i(120, -40)) > 20, "colline : le pinceau rond change ~37 cases")
	_check(world.cell_height(Vector2i(120, -40)) == hc0 + 1.5, "colline : +1,5 m au centre")
	_check(world.cell_height(Vector2i(124, -40)) == world._quantize(world.raw_height(124.5, -39.5)), "colline : rien hors du pinceau")
	world.apply_brush(Vector2i(120, -40))
	var peak := world.cell_height(Vector2i(120, -40))
	world.set_tool(TerrainWorld.Tool.SMOOTH)
	world.apply_brush(Vector2i(120, -40))
	_check(world.cell_height(Vector2i(120, -40)) < peak, "lisser abaisse le sommet")
	world.set_tool(TerrainWorld.Tool.DIG_WATER)
	world._stroke_level = NAN
	var bank := world.cell_height(Vector2i(120, -80))
	world.apply_brush(Vector2i(120, -80))
	world.apply_brush(Vector2i(126, -80)) # même coup de pinceau, vers l'amont (Est)
	var s1 := world.water_surface_at(120.5, -79.5)
	_check(absf(s1 - (bank - TerrainWorld.WATER_SURFACE_DROP)) < 0.01, "lac creusé : eau juste sous la berge")
	_check(world.cell_height(Vector2i(120, -80)) == bank - 1.0, "lac creusé : lit 1 m plus bas")
	_check(world.water_surface_at(128.5, -79.5) == s1, "canal : l'eau garde son niveau en montant")
	_check(world.cell_kind_at(Vector2i(120, -80)) == "Lac / canal", "type de case « Lac / canal »")
	var over := RoutePlanner.plan("rue", PackedVector2Array([Vector2(123, -100), Vector2(123, -60)]), NAN, NAN,
		func(x: float, z: float) -> float: return world.cell_height(Vector2i(floori(x), floori(z))), world.water_surface_at)
	var on_bridge := false
	for i in over.pts.size():
		if absf(over.pts[i].z + 79.5) < 1.0 and over.st[i] == TransportTypes.Struct.BRIDGE:
			on_bridge = true
	_check(on_bridge, "une rue enjambe le canal creusé")
	world.set_tool(TerrainWorld.Tool.FILL_WATER)
	world.apply_brush(Vector2i(126, -80))
	_check(is_nan(world.water_surface_at(126.5, -79.5)) and world.cell_height(Vector2i(126, -80)) == s1 + TerrainWorld.WATER_SURFACE_DROP, "combler l'eau")
	world.set_tool(TerrainWorld.Tool.BIOME)
	world.paint_kind = TerrainWorld.Kind.DESERT
	world.apply_brush(Vector2i(100, 30))
	_check(world.cell_kind_at(Vector2i(100, 30)) == "Désert", "peindre un désert (%s)" % world.cell_kind_at(Vector2i(100, 30)))
	# (le rendu sans écran ne relit pas les positions des arbres : on compte par bloc)
	# Arbres et arbustes seulement (pas les cultures ni les herbes, pas les versions lointaines).
	var count_trees := func(kk: Vector2i) -> int:
		var ch: MeshInstance3D = world.chunks.get(kk)
		var total := 0
		if ch:
			for g in ch.get_children():
				if g is MultiMeshInstance3D and not g.is_queued_for_deletion() and not g.has_meta("loin"):
					var cat: int = g.get_meta("categorie", -1)
					if cat == Plantes.Cat.ARBRE or cat == Plantes.Cat.ARBUSTE:
						total += (g as MultiMeshInstance3D).multimesh.instance_count
		return total
	var fields_before: int = count_trees.call(Vector2i(1, 0))
	var forest_before: int = count_trees.call(Vector2i(1, -1))
	world.brush_radius = 6
	world.set_tool(TerrainWorld.Tool.PLANT)
	world.apply_brush(Vector2i(100, 45))
	world.set_tool(TerrainWorld.Tool.CLEAR_TREES)
	world.apply_brush(Vector2i(100, -30))
	for i in 300:
		await process_frame
		if world._dirty.is_empty() and world._jobs.is_empty():
			break
	var fields_after: int = count_trees.call(Vector2i(1, 0))
	var forest_after: int = count_trees.call(Vector2i(1, -1))
	_check(fields_before == 0 and fields_after >= 15, "arbres plantés dans les champs (%d -> %d)" % [fields_before, fields_after])
	_check(forest_before - forest_after >= 8, "arbres arrachés dans la forêt (%d -> %d)" % [forest_before, forest_after])
	var saved := world.to_dict()
	var n_water := world.water_cells.size()
	world.from_dict(saved)
	_check(world.water_cells.size() == n_water and world.biome_paint.size() > 0 and world.tree_paint.size() > 0, "paysage sauvegardé et rechargé")
	_check(world.cell_kind_at(Vector2i(100, 30)) == "Désert" and not is_nan(world.water_surface_at(120.5, -79.5)), "biome et lac retrouvés après chargement")
	for i in 300:
		await process_frame
		if world._dirty.is_empty() and world._jobs.is_empty() and world.chunks.size() > 10:
			break
	world.set_tool(TerrainWorld.Tool.INSPECT)
	world.set_origin(48.8584, 2.2945) # région vierge pour la suite
	for i in 300:
		await process_frame
		if world._dirty.is_empty() and world._jobs.is_empty() and world.chunks.size() > 10:
			break

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
