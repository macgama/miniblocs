extends SceneTree
## Vitrine du mode photo et du time-lapse : un village qui pousse en quelques
## jours (une vraie image par jour), l'écran du time-lapse, le mode photo et
## ses filtres, l'export vidéo avec la date incrustée.
## Usage (avec affichage) :
##   godot --path . --script res://tests/photo_vitrine.gd -- --sortie dossier --vue timelapse|photo|filtres|export


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 2.0) * 3600.0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var sortie := "user://vitrine_photo"
	var vue := "timelapse"
	for i in args.size():
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	DirAccess.make_dir_recursive_absolute(sortie)
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.2, 6.9)
	await _frames(90)
	bs.unlimited_money = true
	amb.set_speed(0)
	amb.unix_time = _at("2026-05-04", 12.0)
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
	amb._apply()
	var tl: TimeLapse = scene.timelapse
	tl.set_process(false)
	var rig: Node3D = scene.rig
	rig.position = Vector3(0, 40, 0)
	if scene.tutoriel != null:
		scene.tutoriel.clear()
	# Le village : Maison de commune, puis une rue et des maisons jour après jour.
	var mairie := bs.place("maison_commune", Vector2i(0, -14), 0) if not BuildingCatalog.get_type("maison_commune").is_empty() else -1
	scene.communes.actif = true
	var vid: int = scene.communes.fonder_au_point("Valbelle", Vector2(0, 0), mairie)
	var c: Dictionary = tl.camera(int(tl.cameras[0].id)) if not tl.cameras.is_empty() else {}
	if c.is_empty():
		tl.camera_village(vid)
		c = tl.cameras[0]
	var y := world.cell_height(Vector2i(0, 0))
	await _frames(30)
	await tl.filmer(c)
	var etapes := [
		func() -> void: transport.build_segment("rue", Vector3(-90, y, 0), Vector3(90, y, 0)),
		func() -> void:
			for i in 6:
				var cc := Vector2i(-80 + i * 14, 10)
				bs.place("maison", cc, bs.best_rotation("maison", cc)),
		func() -> void:
			for i in 6:
				var cc := Vector2i(8 + i * 14, 10)
				bs.place("maison", cc, bs.best_rotation("maison", cc)),
		func() -> void:
			transport.build_segment("rue", Vector3(0, y, 0), Vector3(0, y, 120)),
		func() -> void:
			for i in 6:
				var cc := Vector2i(-80 + i * 14, -12)
				bs.place("maison", cc, bs.best_rotation("maison", cc)),
		func() -> void:
			for i in 5:
				var cc := Vector2i(12, 24 + i * 16)
				bs.place("maison", cc, bs.best_rotation("maison", cc))
				cc = Vector2i(-12, 24 + i * 16)
				bs.place("maison", cc, bs.best_rotation("maison", cc)),
	]
	for e in etapes:
		e.call()
		amb.shift_days(3)
		amb.set_local_hour(12.0)
		await _frames(40)
		await tl.filmer(c)
	print("images : ", (c.images as Array).size())
	match vue:
		"timelapse":
			var p: TimeLapsePanel = scene.timelapse_panel
			p.set_open(true)
			await _frames(10)
			await _shot(sortie.path_join("timelapse-ecran.png"))
			p.image = 0
			p._montrer()
			await _frames(5)
			await _shot(sortie.path_join("timelapse-fondation.png"))
		"export":
			var p: TimeLapsePanel = scene.timelapse_panel
			p.set_open(true)
			p.ips = 2
			var err: String = await p._avi_incruste(c, ProjectSettings.globalize_path(sortie.path_join("timelapse.avi")))
			print("export : ", "ok" if err == "" else err)
		"photo", "filtres":
			var mp: ModePhoto = scene.mode_photo
			rig.position = Vector3(0, 40, 20)
			rig.set("_distance", 70.0)
			rig.set("_target_distance", 70.0)
			rig.rotation_degrees.y = 30.0
			rig.set_pitch(28.0, true)
			await _frames(30)
			mp.entrer()
			mp.set_heure(18.6)
			await _frames(10)
			if vue == "photo":
				mp.format = "vertical"
				mp.grille = true
				mp._guides.queue_redraw()
				mp.filtre = 10
				mp.vignette = 0.35
				mp._appliquer_filtre()
				await _frames(5)
				await _shot(sortie.path_join("photo-ecran.png"))
				mp.definition = 1080
				var img: Image = await mp.rendre(ModePhoto.taille_sortie(9.0 / 16.0, 1080))
				img.save_png(sortie.path_join("photo-verticale.png"))
			else:
				mp._panel.visible = false
				mp._guides.visible = false
				for f in [[2, "sepia"], [9, "maquette"], [1, "noir-blanc"], [3, "vintage"]]:
					mp.filtre = f[0]
					mp.vignette = 0.3
					mp.grain = 0.25 if f[0] == 2 else 0.0
					mp._appliquer_filtre()
					await _frames(5)
					await _shot(sortie.path_join("filtre-%s.png" % f[1]))
	quit(0)
