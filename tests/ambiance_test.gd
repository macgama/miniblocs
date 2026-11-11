extends SceneTree
## Test du cycle jour/nuit : position du Soleil et de la Lune, lever et coucher,
## fuseau horaire approximatif, lampadaires, fenêtres allumées, sauvegarde.
## Fonctionne sans réseau (relief synthétique).
## Usage : godot --headless --path . --script res://tests/ambiance_test.gd
## Captures (avec affichage) : -- --screenshot prefixe [--distance 140]
##   donne prefixe-jour.png, prefixe-coucher.png, prefixe-nuit.png

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _utc(y: int, mo: int, d: int, h: int, mi := 0) -> float:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": 0})


func _flat_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			a[y * 256 + x] = 40.0 + sin((t.x * 256 + x) * 0.05) * 1.0
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	var dist := 140.0
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--distance" and i + 1 < args.size():
			dist = args[i + 1].to_float()

	print("Astronomie :")
	# Paris, solstice d'été 2026 à midi solaire (≈ 11:51 UTC) : hauteur ≈ 64,6°.
	var s := Astro.sun_horizontal(_utc(2026, 6, 21, 11, 51), 48.8566, 2.3522)
	_check(absf(s.x - 64.6) < 0.5, "Paris, 21 juin, midi : Soleil à %.1f° (≈ 64,6°)" % s.x)
	_check(absf(s.y - 180.0) < 3.0, "… plein Sud (azimut %.1f°)" % s.y)
	s = Astro.sun_horizontal(_utc(2026, 12, 21, 11, 49), 48.8566, 2.3522)
	_check(absf(s.x - 17.7) < 0.5, "Paris, 21 décembre, midi : Soleil à %.1f° (≈ 17,7°)" % s.x)
	s = Astro.sun_horizontal(_utc(2026, 3, 20, 6, 0), 48.8566, 2.3522)
	_check(s.y > 80.0 and s.y < 100.0, "Matin d'équinoxe : le Soleil se lève à l'Est (%.0f°)" % s.y)
	var dir := Astro.direction(Vector2(0, 90))
	_check(dir.distance_to(Vector3(1, 0, 0)) < 0.001, "Est = +X dans le repère du jeu")
	dir = Astro.direction(Vector2(0, 180))
	_check(dir.distance_to(Vector3(0, 0, 1)) < 0.001, "Sud = +Z dans le repère du jeu")
	# Lever / coucher à Paris (heure légale) : 21 juin ≈ 05:47 / 21:58, 21 déc ≈ 08:41 / 16:56.
	print("Fuseaux horaires :")
	_check(Fuseaux.available(), "Carte des fuseaux chargée")
	var off := Fuseaux.utc_offset(48.8566, 2.3522, _utc(2026, 6, 21, 12))
	_check(off == 2.0, "Paris en été : UTC+2")
	var tz_cases := [
		["Paris en hiver", 48.8566, 2.3522, _utc(2026, 12, 21, 12), 1.0],
		["Paris, 29 mars 2026 à 00:59 UTC (avant le changement)", 48.8566, 2.3522, _utc(2026, 3, 29, 0, 59), 1.0],
		["Paris, 29 mars 2026 à 01:00 UTC (heure d'été)", 48.8566, 2.3522, _utc(2026, 3, 29, 1, 0), 2.0],
		["Paris en juillet 2070 (au-delà de la table)", 48.8566, 2.3522, _utc(2070, 7, 1, 12), 2.0],
		["Londres en hiver", 51.5072, -0.1276, _utc(2026, 12, 21, 12), 0.0],
		["Tokyo", 35.68, 139.69, _utc(2026, 12, 21, 12), 9.0],
		["Pékin", 39.9, 116.4, _utc(2026, 7, 1, 12), 8.0],
		["New York en été", 40.71, -74.0, _utc(2026, 7, 1, 12), -4.0],
		["Phoenix en été (pas d'heure d'été)", 33.45, -112.07, _utc(2026, 7, 1, 12), -7.0],
		["Bombay", 19.07, 72.87, _utc(2026, 7, 1, 12), 5.5],
		["Katmandou", 27.7, 85.32, _utc(2026, 7, 1, 12), 5.75],
		["Sydney en janvier (été austral)", -33.87, 151.21, _utc(2026, 1, 15, 12), 11.0],
		["Rio", -22.95, -43.16, _utc(2026, 1, 15, 12), -3.0],
		["Étretat (côte)", 49.707, 0.2016, _utc(2026, 1, 15, 12), 1.0],
		["Milieu de l'Atlantique (fuseau nautique)", 35.0, -40.0, _utc(2026, 1, 15, 12), -3.0],
	]
	for c in tz_cases:
		var o := Fuseaux.utc_offset(c[1], c[2], c[3])
		_check(absf(o - float(c[4])) < 0.01, "%s : %s" % [c[0], ClockHud.format_offset(o)])
	var rs := Astro.sun_rise_set(_utc(2026, 6, 21, 12), 48.8566, 2.3522, off)
	_check(absf(rs.x - 5.78) < 0.1 and absf(rs.y - 21.97) < 0.1, "Paris, 21 juin : lever %s, coucher %s (≈ 05:47, 21:58)" % [ClockHud.format_hour(rs.x), ClockHud.format_hour(rs.y)])
	rs = Astro.sun_rise_set(_utc(2026, 12, 21, 12), 48.8566, 2.3522, 1.0)
	_check(absf(rs.x - 8.68) < 0.1 and absf(rs.y - 16.93) < 0.1, "Paris, 21 décembre : lever %s, coucher %s (≈ 08:41, 16:56)" % [ClockHud.format_hour(rs.x), ClockHud.format_hour(rs.y)])
	_check(Astro.sun_rise_set(_utc(2026, 12, 21, 12), 69.65, 18.96, 1.0) == Vector2(-1, -1), "Tromsø en décembre : nuit polaire")
	_check(Astro.sun_rise_set(_utc(2026, 6, 21, 12), 69.65, 18.96, 2.0) == Vector2(-2, -2), "Tromsø en juin : soleil de minuit")
	# Lune : pleine le 2026-05-31 08:45 UTC, nouvelle le 2026-06-15 02:54 UTC.
	var full := Astro.moon_illumination(_utc(2026, 5, 31, 8, 45))
	var new := Astro.moon_illumination(_utc(2026, 6, 15, 2, 54))
	_check(full > 0.97, "Pleine lune du 31 mai 2026 : %.0f %% éclairée" % (full * 100.0))
	_check(new < 0.03, "Nouvelle lune du 15 juin 2026 : %.0f %% éclairée" % (new * 100.0))
	_check(ClockHud.moon_phase_name(Astro.moon_age(_utc(2026, 5, 31, 8, 45))) == "pleine lune", "Nom de la phase : pleine lune")
	_check(NightWindows.lit_ratio_at(20.0) > NightWindows.lit_ratio_at(3.0), "Plus de fenêtres allumées à 20 h qu'à 3 h")

	print("Météo :")
	var t_paris_jan := Meteo.air_temperature(48.85, _utc(2026, 1, 15, 14), 14.0, 35.0)
	var t_paris_jul := Meteo.air_temperature(48.85, _utc(2026, 7, 15, 14), 15.0, 35.0)
	_check(t_paris_jan > 0.0 and t_paris_jan < 12.0, "Paris, mi-janvier, après-midi : %.0f °C" % t_paris_jan)
	_check(t_paris_jul > 18.0 and t_paris_jul < 30.0, "Paris, mi-juillet, après-midi : %.0f °C" % t_paris_jul)
	_check(Meteo.air_temperature(-33.9, _utc(2026, 1, 15, 4), 15.0, 0.0) > Meteo.air_temperature(-33.9, _utc(2026, 7, 15, 4), 15.0, 0.0), "Hémisphère sud : janvier plus chaud que juillet")
	_check(Meteo.air_temperature(45.83, _utc(2026, 7, 15, 13), 15.0, 4800.0) < 0.0, "Sommet du mont Blanc en juillet : sous 0 °C")
	_check(Meteo.default_humidity(25.0) < Meteo.default_humidity(48.0), "Tropiques plus secs que l'Europe")
	# Sur un an à Paris : il pleut parfois, pas tout le temps ; plus de pluie en climat humide.
	var rainy := 0
	var rainy_dry := 0
	var cloudy := 0
	for d in 365:
		var u := _utc(2026, 1, 1, 12) + d * 86400.0
		var n := Meteo.natural(u, 48.85, 2.35, 0.55, 12.0, 14.0)
		if float(n[1]) > 0.2:
			rainy += 1
		if float(n[0]) > 0.6:
			cloudy += 1
		if float(Meteo.natural(u, 23.0, 10.0, 0.08, 30.0, 14.0)[1]) > 0.2:
			rainy_dry += 1
	_check(rainy > 15 and rainy < 200, "Paris : %d jours de pluie à 14 h sur 365" % rainy)
	_check(cloudy > 40 and cloudy < 330, "Paris : %d jours très nuageux sur 365" % cloudy)
	_check(rainy_dry < rainy / 3, "Sahara : %d jours de pluie seulement" % rainy_dry)
	_check(Meteo.natural(_utc(2026, 5, 1, 12), 48.85, 2.35, 0.55, 12.0, 14.0) == Meteo.natural(_utc(2026, 5, 1, 12), 48.85, 2.35, 0.55, 12.0, 14.0), "Même temps pour tous au même endroit au même moment")
	_check(Headlights.lamp_points({"L": 4.0, "W": 1.8, "H": 1.5})[0].z < -1.9, "Phares à l'avant du véhicule (−Z)")

	print("Scène :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	var dn: DayNight = scene.get_node("Ambiance")
	_check(dn != null and dn.sun != null and dn.moon != null, "Soleil, Lune et ciel en place")
	for i in 40:
		await process_frame
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	var r1 := transport.build_segment("route", Vector3(-150, y, 0), Vector3(150, y, 0))
	var r2 := transport.build_segment("chemin", Vector3(-100, y, 40), Vector3(100, y, 40))
	_check(r1.ok and r2.ok, "Route et chemin construits")
	var placed := 0
	var x := -130
	for id in ["immeuble", "maison", "bureaux", "superette", "tour_habitation", "cafe", "maison", "ecole"]:
		var r := 2
		var fp := BuildingCatalog.footprint(id, r)
		if bs.place(id, Vector2i(x + fp.x / 2, -6 - fp.y / 2), r) >= 0:
			placed += 1
		x += fp.x + 4
	_check(placed >= 6, "%d bâtiments posés" % placed)
	# Quelques bâtiments de la bible des styles, de l'autre côté de la route.
	var styled: Array[String] = []
	for id in BuildingCatalog.all_types():
		if String(id).ends_with("__gratte_ciel") or String(id) in ["haussmann__immeuble", "japonais__maison", "chinois__boutique"]:
			styled.append(id)
	x = -130
	var placed_styled := 0
	for id in styled.slice(0, 6):
		var fp := BuildingCatalog.footprint(id, 0)
		if x + fp.x > 140:
			break
		if bs.place(id, Vector2i(x + fp.x / 2, 6 + fp.y / 2), 0) >= 0:
			placed_styled += 1
		x += fp.x + 4
	_check(placed_styled >= 2, "%d bâtiments de la bible posés" % placed_styled)
	_check(NightWindows.window_colors().size() >= 8, "%d couleurs de vitres reconnues (catalogue et styles)" % NightWindows.window_colors().size())
	await process_frame
	await process_frame
	var lamps := dn.street.count()
	_check(lamps >= 12 and lamps <= 20, "%d lampadaires le long de 300 m de route et 200 m de chemin" % lamps)
	_check(bs.mesh_for("maison").surface_get_material(0) == NightWindows.building_material(), "Bâtiments : matériau aux fenêtres allumables")

	# Journée, puis nuit.
	dn.set_speed(0)
	dn.unix_time = _utc(2026, 6, 21, 10) # midi à Paris (UTC+2)
	dn._apply()
	_check(dn.night < 0.01 and dn.sun.visible and dn.sun.shadow_enabled, "Midi : plein jour, ombres du Soleil")
	_check(absf(dn.local_hour() - 12.0) < 0.01, "Heure locale affichée : 12:00")
	dn.set_local_hour(23.5)
	_check(dn.night > 0.95 and not dn.sun.visible, "23 h 30 : nuit")
	_check(float(NightWindows.building_material().get_shader_parameter("night")) > 0.95, "La nuit, les fenêtres s'allument")
	for i in 20:
		await process_frame
	var lit := 0
	for c in dn.street.get_children():
		if c is SpotLight3D and c.visible:
			lit += 1
	_check(lit >= 10, "%d lampadaires éclairent le sol près de la caméra" % lit)
	dn.set_local_hour(12.0)
	for i in 20:
		await process_frame
	lit = 0
	for c in dn.street.get_children():
		if c is SpotLight3D and c.visible:
			lit += 1
	_check(lit == 0, "Le jour, les lampadaires sont éteints")

	# Météo forcée.
	dn.weather.mode = Meteo.Mode.PLUIE
	dn.weather.settle(dn.unix_time, dn.local_hour())
	for i in 3:
		await process_frame
	_check(dn.weather.precip > 0.3 and dn.weather.cover > 0.6, "Météo « Pluie » : il pleut (%.0f %%)" % (dn.weather.precip * 100.0))
	_check(dn.env.fog_density > 0.0005, "Pluie : la visibilité baisse")
	dn.weather.mode = Meteo.Mode.SOLEIL
	dn.weather.settle(dn.unix_time, dn.local_hour())
	for i in 3:
		await process_frame
	_check(dn.weather.precip < 0.1, "Retour au soleil")
	dn.weather.mode = Meteo.Mode.AUTO
	# Phares la nuit.
	transport.traffic.set_enabled(true)
	dn.set_local_hour(23.0)
	for i in 120:
		await process_frame
	var cars := 0
	for v in transport.traffic.vehicles:
		if String(v.get("model", "")) != "":
			cars += 1
	_check(cars == 0 or dn.headlights.get_child(0).multimesh.instance_count > 0, "La nuit, %d véhicules ont leurs phares allumés" % cars)
	dn.set_local_hour(12.0)
	for i in 5:
		await process_frame
	if dn.weather.fog < 0.3 and dn.weather.precip < 0.3:
		_check(dn.headlights.get_child(0).multimesh.instance_count == 0, "Le jour, phares éteints")

	# Le temps avance.
	dn.set_speed(4)
	var t0 := dn.unix_time
	for i in 10:
		await process_frame
	_check(dn.unix_time > t0, "Le temps avance à 1 h/s")
	dn.toggle_pause()
	_check(dn.speed_index == 0, "T : pause")

	# Sauvegarde.
	dn.set_local_hour(21.0)
	dn.weather.mode = Meteo.Mode.NEIGE
	var saved := dn.to_dict()
	dn.set_local_hour(8.0)
	dn.from_dict(JSON.parse_string(JSON.stringify(saved)))
	_check(absf(dn.local_hour() - 21.0) < 0.01, "Sauvegarde : l'heure est retrouvée")
	_check(dn.weather.mode == Meteo.Mode.NEIGE, "Sauvegarde : la météo choisie est retrouvée")
	dn.weather.mode = Meteo.Mode.SOLEIL

	if shot != "" and not args.has("--meteo"):
		var rig = scene.get_node("CameraRig")
		rig.position = Vector3(-40, y, -10)
		rig._distance = dist
		rig._target_distance = dist
		rig.rotation_degrees.y = 200.0
		dn.unix_time = _utc(2026, 6, 21, 12)
		for item in [["jour", 15.0], ["coucher", 21.6], ["nuit", 23.4]]:
			dn.set_local_hour(item[1])
			for i in 40:
				await process_frame
			var path := "%s-%s.png" % [shot, item[0]]
			root.get_viewport().get_texture().get_image().save_png(path)
			print("Capture : ", path)
		# Le ciel au ras du sol : Lune, étoiles, lueur du couchant.
		rig.pitch_degrees = 8.0
		rig._distance = 60.0
		rig._target_distance = 60.0
		# Couchant au Nord-Ouest, Lune (premier quartier) au Sud-Ouest.
		for item in [["ciel-coucher", 21.9, 55.0], ["ciel-nuit", 23.9, 135.0]]:
			rig.rotation_degrees.y = item[2]
			dn.set_local_hour(item[1])
			for i in 40:
				await process_frame
			var path := "%s-%s.png" % [shot, item[0]]
			root.get_viewport().get_texture().get_image().save_png(path)
			print("Capture : ", path)

	if shot != "":
		var rig = scene.get_node("CameraRig")
		rig.position = Vector3(-40, y, -10)
		rig.pitch_degrees = 30.0
		rig._distance = 90.0
		rig._target_distance = 90.0
		rig.rotation_degrees.y = 200.0
		for item in [["pluie", Meteo.Mode.PLUIE, 15.0], ["neige", Meteo.Mode.NEIGE, 11.0],
				["brouillard", Meteo.Mode.BROUILLARD, 8.0], ["nuageux", Meteo.Mode.NUAGEUX, 17.0],
				["phares", Meteo.Mode.SOLEIL, 23.2]]:
			dn.weather.mode = item[1]
			dn.set_local_hour(item[2])
			dn.weather.settle(dn.unix_time, dn.local_hour())
			for i in 90:
				await process_frame
			var path := "%s-%s.png" % [shot, item[0]]
			root.get_viewport().get_texture().get_image().save_png(path)
			print("Capture : ", path)

	print("AMBIANCE TEST OK" if ok else "AMBIANCE TEST ÉCHEC")
	quit(0 if ok else 1)
