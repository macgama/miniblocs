extends SceneTree
## Vitrine des intérieurs : bâtiments meublés vus en coupe, habitants dans les
## pièces, vue au sol dans un séjour, salle d'exposition de la bible.
## Usage (avec affichage) :
##   godot --path . --script res://tests/interieurs_vitrine.gd -- --screenshot i.png --vue dessus|proche|nuit|sol|bible|panneau
## --style japonais : style du mobilier des bâtiments meublés.
## --types canape,lit_double,… : types montrés par --vue bible (un style par rangée).


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "interieurs.png"
	var vue := "dessus"
	var style := ""
	var types: PackedStringArray = ["lit_double", "canape", "fauteuil", "table_repas", "armoire", "cuisiniere", "table_basse", "lampadaire", "tapis"]
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
		if args[i] == "--style" and i + 1 < args.size():
			style = args[i + 1]
		if args[i] == "--types" and i + 1 < args.size():
			types = args[i + 1].split(",")
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	bs.unlimited_money = true
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.5)
	var pe: PlanEditor = scene.get_node("Plans")
	var mob: Mobilier = scene.mobilier
	var pop: Population = scene.population
	var rig = scene.get_node("CameraRig")
	var placed := {}
	if vue == "bible":
		_bible(pe, mob, types)
		rig.position = Vector3(10, 40.0, 14)
		rig._distance = 34.0
		rig._target_distance = 34.0
		rig.rotation_degrees.y = 0.0
		if "pitch_degrees" in rig:
			rig.pitch_degrees = 58.0
	else:
		var styles := {"maison": "rustique", "immeuble": "scandinave", "ecole": "contemporain", "boutique": "marocain", "bureaux": "industriel", "cafe": "art_deco"}
		var pos := {"maison": Vector2i(-26, -22), "immeuble": Vector2i(-12, -22), "ecole": Vector2i(4, -24), "boutique": Vector2i(-26, -8), "bureaux": Vector2i(-12, -8), "cafe": Vector2i(4, -8)}
		for k in Gabarits.ORDER:
			var res := Gabarits.build(mob, k, pos[k], 0, style if style != "" else String(styles[k]))
			if res.ok:
				placed[k] = String(res.id)
		pe.flush()
		mob.flush()
		# Une route devant, et le temps passe : les habitants emménagent.
		var y := world.cell_height(Vector2i(0, 0))
		scene.get_node("Transport").build_segment("route", Vector3(-40, y, -27), Vector3(30, y, -27))
		pop._sync_buildings()
		for i in 72:
			pop.advance(300.0)
		# Vue en coupe : seuls les rez-de-chaussée (les toits sont en blocs).
		var blocks: BlockEditor = scene.get_node("Blocs")
		blocks.visible = false
		for id in pe._nodes:
			for e in pe._nodes[id]:
				(pe._nodes[id][e] as Node3D).visible = int(e) == 0
		if vue == "nuit":
			amb.unix_time = _at("2026-03-11", 2.5)
		elif vue == "proche":
			amb.unix_time = _at("2026-03-10", 17.5)
		pop._now = {}
		var occ: Occupants = scene.occupants
		match vue:
			"dessus", "nuit", "panneau", "proche":
				rig.position = Vector3(-8, 40.0, -12)
				rig._distance = 46.0 if vue != "nuit" else 30.0
				rig._target_distance = rig._distance
				rig.rotation_degrees.y = 18.0
				if vue == "nuit":
					rig.position = Vector3(-22, 40.0, -18)
				if vue == "proche":
					rig.position = Vector3(-20, 40.0, -16)
					rig._distance = 20.0
					rig._target_distance = 20.0
				if "pitch_degrees" in rig:
					rig.pitch_degrees = 62.0
				if vue == "panneau":
					var bp: BuildingPanel = scene.get_node("PanneauConstruction")
					bp.set_open(true)
					bp.show_category("interieur")
					mob._focus = String(placed.get("maison", ""))
					mob.plan_selected.emit(mob._focus)
			"sol":
				var id: String = placed.get("maison", "")
				var by := pe.base_y(id, 0)
				var cam := Camera3D.new()
				cam.fov = 72.0
				scene.add_child(cam)
				cam.global_position = Vector3(-25.4, by + 1.6, -15.3)
				cam.look_at(Vector3(-21.0, by + 0.8, -18.4))
				cam.current = true
				occ.camera = cam
		for i in 20:
			await process_frame
		occ.refresh()
	for i in 80:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot, " · ", (scene.occupants as Occupants).shown.size(), " habitants affichés")
	quit(0)


## Salle d'exposition : une rangée par style, les mêmes types côte à côte.
func _bible(pe: PlanEditor, mob: Mobilier, types: PackedStringArray) -> void:
	var picks := ["rustique", "louis_xv", "victorien", "scandinave", "romain", "egyptien", "marocain", "afrique_ouest", "japonais", "chinois",
		"indien", "mexicain", "mid_century", "polynesien", "futuriste"]
	var w := types.size() * 3 + 1
	var d := picks.size() * 3 + 1
	var id := pe.new_plan(pe.ground_level(Vector2i(0, 0)))
	pe.set_material(35)
	pe.add_floors(id, Rect2i(0, 0, w, d), 0)
	for r in picks.size():
		for t in types.size():
			var m := Meubles.pick(types[t], String(picks[r]))
			if m != "":
				mob.place(id, 0, Vector2i(1 + t * 3, 1 + r * 3), 0, m, false, false)
	pe.flush()
	mob.flush()
