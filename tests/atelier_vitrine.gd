extends SceneTree
## Vitrine de la personnalisation : une rue de Maisons à pignon personnalisées,
## le panneau Personnaliser, une maison ouverte vue en coupe, l'atelier et sa
## banque de modèles.
## Usage (avec affichage) :
##   godot --path . --script res://tests/atelier_vitrine.gd -- --screenshot a.png --vue rue|panneau|coupe|atelier


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "atelier.png"
	var vue := "rue"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BanqueModeles.persist = false
	if vue == "atelier":
		GameStart.atelier = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	if vue != "atelier":
		world.tiles.offline_generator = _flat_tile
		world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
		world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	bs.unlimited_money = true
	bs.require_access = false
	var mob: Mobilier = scene.mobilier
	var rig = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	scene.get_node("Transport").build_segment("route", Vector3(-60, y, 2), Vector3(60, y, 2))
	var looks := [{}, {"mur": "3d6fa8", "toit_c": "c2453a", "volets": "f2f2f2", "toit": "hip", "etages": 3},
		{"mur": "e9c46a", "boiseries": "2a2a2a", "toit": "flat", "etages": 1}, {"mur": "f2ede1", "toit_c": "2f6b4f", "volets": "c2453a", "pente": 1.6},
		{"mur": "e3a0a8", "toit_c": "4a4a4a", "toit": "mansard"}, {}]
	var ids := []
	for i in looks.size():
		var bid := bs.place("hollandais__maison", Vector2i(-36 + i * 12, -10), 2)
		ids.append(bid)
		if not (looks[i] as Dictionary).is_empty():
			bs.set_perso(bid, looks[i])
	# Les chantiers se terminent.
	amb.unix_time += 86400.0 * 60
	for i in 30:
		await process_frame
	var opened := Conversion.open_interior(mob, int(ids[5]))
	mob.pe.flush()
	mob.flush()
	BanqueModeles.save_building(bs, int(ids[1]), "Maison bleue à quatre pans")
	BanqueModeles.save_building(bs, int(ids[2]), "Pignon jaune, toit terrasse")
	BanqueModeles.save_building(bs, int(ids[3]), "Pignon crème, toit vert")
	if opened.ok:
		BanqueModeles.save_plan(mob, String(opened.id), "Pignon meublé")
	match vue:
		"rue", "panneau":
			rig.position = Vector3(-6, 40.0, -10)
			rig._distance = 52.0
			rig._target_distance = 52.0
			rig.rotation_degrees.y = 0.0
			if "pitch_degrees" in rig:
				rig.pitch_degrees = 40.0
			if vue == "panneau":
				rig.position = Vector3(-16, 40.0, -10)
				var pp: PersoPanel = scene.perso_panel
				pp.edit(int(ids[1]))
		"coupe":
			var id := String(opened.get("id", ""))
			var blocks: BlockEditor = scene.get_node("Blocs")
			blocks.visible = false
			for e in mob.pe._nodes.get(id, {}):
				(mob.pe._nodes[id][e] as Node3D).visible = int(e) == 0
			var bb: Rect2i = mob.pe._bbox[id]
			rig.position = Vector3(bb.position.x + bb.size.x / 2.0, 40.0, bb.position.y + bb.size.y / 2.0)
			rig._distance = 18.0
			rig._target_distance = 18.0
			rig.rotation_degrees.y = 20.0
			if "pitch_degrees" in rig:
				rig.pitch_degrees = 64.0
		"atelier":
			rig.position = Vector3(-6, 40.0, -10)
			rig._distance = 60.0
			rig._target_distance = 60.0
			var bp: BuildingPanel = scene.get_node("PanneauConstruction")
			scene.hud.set_create_category("banque")
			scene._on_create_requested("banque")
	for i in 90:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	GameStart.atelier = false
	quit(0)
