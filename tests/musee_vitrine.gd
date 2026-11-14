extends SceneTree
## Vitrine des musées : musées prêts à poser vus en coupe avec leurs visiteurs,
## salles de près, bible des objets, panneau du musée.
## Usage (avec affichage) :
##   godot --path . --script res://tests/musee_vitrine.gd -- --screenshot m.png --vue dessus|proche|dinos|bible|panneau
## --famille peinture : famille montrée par --vue bible ("" = toutes).


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 2.0) * 3600.0


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "musee.png"
	var vue := "dessus"
	var famille := ""
	var dist := 40.0
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
		if args[i] == "--famille" and i + 1 < args.size():
			famille = args[i + 1]
		if args[i] == "--dist" and i + 1 < args.size():
			dist = float(args[i + 1])
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BatimentsVie.chantiers = false
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
	amb.unix_time = _at("2026-07-18", 11.0)
	var pe: PlanEditor = scene.get_node("Plans")
	var mob: Mobilier = scene.mobilier
	var musee: Musee = scene.musee
	var rig = scene.get_node("CameraRig")
	if vue == "bible":
		_bible(pe, mob, famille)
		rig.position = Vector3(14, 40.0, 13) if dist >= 40.0 else Vector3(9, 40.0, 6)
		rig._distance = dist
		rig._target_distance = dist
		rig.rotation_degrees.y = 0.0
		if "pitch_degrees" in rig:
			rig.pitch_degrees = 55.0
	else:
		var pos := {"musee_beaux_arts": Vector2i(-30, -20), "museum_nature": Vector2i(-2, -20), "musee_civilisations": Vector2i(-30, 2),
			"musee_sciences": Vector2i(0, 2)}
		if vue.begins_with("themes"):
			pos = {"cite_transports": Vector2i(-36, -24), "musee_cinema_musique": Vector2i(0, -20), "musee_mer": Vector2i(-36, 0),
				"musee_jouets_bd": Vector2i(-8, 2), "musee_prehistoire": Vector2i(16, 2)}
		var placed := {}
		for k in pos:
			var res := Gabarits.build(mob, k, pos[k], 0, "contemporain")
			if res.ok:
				placed[k] = String(res.id)
		pe.flush()
		mob.flush()
		# Une journée d'été : les visiteurs arrivent.
		musee._dirty = true
		musee.clock = amb.unix_time - 3 * 3600.0
		musee.last_day = int(musee._now(musee.clock).day)
		musee.advance(3 * 3600.0)
		musee.visuels._peupler()
		for i in 200:
			musee.visuels._bouger(0.1)
		# Vue en coupe : seuls les rez-de-chaussée.
		var blocks: BlockEditor = scene.get_node("Blocs")
		blocks.visible = false
		for id in pe._nodes:
			for e in pe._nodes[id]:
				(pe._nodes[id][e] as Node3D).visible = int(e) == 0
		for id in mob._nodes:
			for e in mob._nodes[id]:
				(mob._nodes[id][e] as Node3D).visible = int(e) == 0
		match vue:
			"dessus", "panneau":
				rig.position = Vector3(-2, 40.0, -2)
				rig._distance = 62.0
				rig._target_distance = 62.0
				rig.rotation_degrees.y = 12.0
				if "pitch_degrees" in rig:
					rig.pitch_degrees = 64.0
				if vue == "panneau":
					rig.position = Vector3(-14, 40.0, -6)
					rig._distance = 40.0
					rig._target_distance = 40.0
					var panel: MuseePanel = scene.musee_panel
					panel.set_open(true)
					panel.choisi = String(placed.get("musee_beaux_arts", ""))
					panel.show_view("musee")
			"themes":
				rig.position = Vector3(-6, 40.0, -4)
				rig._distance = 66.0
				rig._target_distance = 66.0
				rig.rotation_degrees.y = 12.0
				if "pitch_degrees" in rig:
					rig.pitch_degrees = 64.0
			"themes_transports", "themes_cinema", "themes_jouets", "themes_mer":
				var at := {"themes_transports": Vector3(-24, 40.0, -6), "themes_cinema": Vector3(12, 40.0, -6),
					"themes_jouets": Vector3(5, 40.0, 13), "themes_mer": Vector3(-24, 40.0, 13)}
				rig.position = at[vue]
				rig._distance = 24.0
				rig._target_distance = 24.0
				rig.rotation_degrees.y = 15.0
				if "pitch_degrees" in rig:
					rig.pitch_degrees = 55.0
			"proche":
				rig.position = Vector3(-24, 40.0, -9)
				rig._distance = 22.0
				rig._target_distance = 22.0
				rig.rotation_degrees.y = 20.0
				if "pitch_degrees" in rig:
					rig.pitch_degrees = 55.0
			"dinos":
				rig.position = Vector3(8, 40.0, -9)
				rig._distance = 24.0
				rig._target_distance = 24.0
				rig.rotation_degrees.y = -15.0
				if "pitch_degrees" in rig:
					rig.pitch_degrees = 50.0
	for i in 90:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	var vis := 0
	var mm := (musee.visuels.get_node("Corps") as MultiMeshInstance3D).multimesh
	for i in mm.instance_count:
		if mm.get_instance_transform(i).basis.get_scale().y > 0.01:
			vis += 1
	print("Capture : ", shot, " · ", musee.visuels.count(), " visiteurs, ", vis, " visibles")
	quit(0)


## Salle d'exposition : tous les objets d'une famille (ou tous), en rangées.
func _bible(pe: PlanEditor, mob: Mobilier, famille: String) -> void:
	var ids := []
	for e in MuseeObjets.entries():
		if famille == "" or famille.split(",").has(String(e.p[1])):
			ids.append(String(e.id))
	var cols := 14
	var w := cols * 2 + 2
	var d := 4 + ceili(float(ids.size()) / cols) * 4
	var id := pe.new_plan(pe.ground_level(Vector2i(0, 0)))
	pe.set_material(35)
	pe.add_floors(id, Rect2i(0, 0, w, d), 0)
	var x := 1
	var z := 1
	for m in ids:
		var ent := Meubles.get_entry(String(m))
		var fw := int(ent.w)
		if x + fw > w - 1:
			x = 1
			z += 3 if fw < 3 else 4
		mob.place(id, 0, Vector2i(x, z), 0, String(m), false, false)
		x += fw + 1
	pe.flush()
	mob.flush()
