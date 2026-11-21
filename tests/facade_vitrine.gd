extends SceneTree
## Vitrine « Modifier la façade » : une rue de maisons classiques (d'origine,
## murs repeints, chalet alpin, colombages, pavillon, maison cube), la fiche avec
## ses deux tuiles et le panneau avec son devis.
## Usage (avec affichage) :
##   godot --path . --script res://tests/facade_vitrine.gd -- --screenshot a.png --vue rue|fiche|panneau


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "facade.png"
	var vue := "rue"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	Langue.activer("fr")
	root.size = Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BanqueModeles.persist = false
	GameStart.chosen = true
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.services_fondation = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.2, 6.1)
	for i in 60:
		await process_frame
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2027-06-20T00:00:00")
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	scene.communes.nom_en_attente = "Valfleuri"
	bs.require_access = false
	bs.place("maison_commune", Vector2i(-40, -60), 0)
	for i in 4:
		await process_frame
	bs.unlimited_money = false
	bs.money = 3_000_000
	bs.require_access = false
	var rig = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	scene.get_node("Transport").build_segment("route", Vector3(-50, y, 2), Vector3(50, y, 2))
	var looks := [{}, Personnalisation.completer("maison", {"mur": "3d6fa8", "volets": "f2f2f2"}), {"style": "alpin"},
		{"style": "colombages", "etages": 3}, {"style": "banlieue_us", "mur": "e9c46a"}, {"style": "international"}]
	var ids := []
	for i in looks.size():
		var c := Vector2i(-33 + i * 13, -6)
		for dz in [0, -2, -4, -6, -8]:
			if bs.check_place("maison", c + Vector2i(0, dz), 2).ok:
				c += Vector2i(0, dz)
				break
		var bid := bs.place("maison", c, 2)
		print("maison ", i, " : ", bid, " ", bs.check_place("maison", c, 2).get("reason", ""))
		ids.append(bid)
		if bid >= 0 and not (looks[i] as Dictionary).is_empty():
			bs.set_perso(bid, looks[i])
	amb.unix_time += 86400.0 * 60 + 14.0 * 3600.0
	for i in 30:
		await process_frame
	for b in ids:
		if int(b) >= 0:
			bs.buildings[b]["chantier"] = false
	scene.population._sync_buildings()
	rig.position = Vector3(-2, 40.0, -6)
	rig._distance = 54.0
	rig._target_distance = 54.0
	rig.rotation_degrees.y = 0.0
	if "pitch_degrees" in rig:
		rig.pitch_degrees = 32.0
	Langue.activer("fr")
	if scene.get("tutoriel") != null:
		scene.tutoriel.arreter()
	for b in scene.find_children("*", "BullesAide", true, false):
		(b as BullesAide).fermer()
	match vue:
		"avant", "apres":
			var c3 := Vector2i(-62, -6)
			for dz in [0, -2, -4, -6, -8]:
				if bs.check_place("maison@10x14x3", c3 + Vector2i(0, dz), 2).ok:
					c3 += Vector2i(0, dz)
					break
			BatimentsVie.chantiers = false
			var m3 := bs.place("maison@10x14x3", c3, 2)
			amb.unix_time += 86400.0 * 120
			for i in 30:
				await process_frame
			rig.position = Vector3(c3.x + 5, 40.0, c3.y + 2)
			rig._distance = 30.0
			rig._target_distance = 30.0
			rig.rotation_degrees.y = 20.0
			if vue == "apres":
				var r := Conversion.open_interior(scene.mobilier, m3)
				print("ouverture : ", r)
				scene.mobilier.pe.flush()
				scene.mobilier.flush()
		"fiche":
			rig.position = Vector3(-26, 40.0, -6)
			rig._distance = 30.0
			rig._target_distance = 30.0
			var hp: HabitantsPanel = scene.habitants_panel
			hp.set_open(true)
			hp.show_view("batiment", int(ids[0]))
		"panneau":
			rig.position = Vector3(-20, 40.0, -6)
			rig._distance = 34.0
			rig._target_distance = 34.0
			var pp: PersoPanel = scene.perso_panel
			pp.edit(int(ids[0]))
			pp._apply({"style": "alpin"})
	for i in 90:
		await process_frame
	if amb.weather != null:
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit(0)
