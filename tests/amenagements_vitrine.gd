extends SceneTree
## Vitrine des aménagements de l'atelier : stade, centre aquatique, gare,
## terrains de sport, zoo, et le panneau avec ses vignettes.
## Usage (avec affichage) :
##   godot --path . --script res://tests/amenagements_vitrine.gd -- --screenshot a.png --vue stade|piscines|gare|terrains|zoo|panneau [--onglet am_bassins]


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


var pe: PlanEditor


func _am(id: String, kind: String, x: int, z: int, w := -1, d := -1, r := 0, e := 0) -> void:
	var s := Amenagements.default_size(kind, r)
	if w > 0:
		s = Vector2i(w, d)
	if not pe.add_amenagement(id, Rect2i(x, z, s.x, s.y), e, kind, r):
		push_warning("non posé : %s" % kind)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "amenagements.png"
	var vue := "stade"
	var onglet := "am_bassins"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
		if args[i] == "--onglet" and i + 1 < args.size():
			onglet = args[i + 1]
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BanqueModeles.persist = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	bs.unlimited_money = true
	bs.require_access = false
	pe = scene.get_node("Plans")
	var rig = scene.get_node("CameraRig")
	var look := Vector3.ZERO
	var dist := 80.0
	var yaw := 0.0
	var pitch := 35.0
	var y0 := pe.ground_level(Vector2i.ZERO)
	var id := pe.new_plan(y0)
	match vue:
		"stade":
			_am(id, "athletisme", -47, -89)
			_am(id, "tribune_couverte", 47, -60, 16, 120, 3)
			_am(id, "gradins_beton", -63, -60, 16, 120, 1)
			_am(id, "gradins_gazon", -47, 89, 94, 10, 0)
			look = Vector3(0, y0 + 2, 0)
			dist = 210.0
			yaw = 35.0
			pitch = 38.0
		"piscines":
			pe.add_floors(id, Rect2i(-20, -16, 44, 34), 0, BlocFormes.encode(BlocMateriaux.index_of("Dalles de grès")))
			_am(id, "bassin_nage", -18, -14, 13, 25)
			_am(id, "plongeon", -2, -14, 12, 14)
			_am(id, "pataugeoire", 12, -14, 8, 8)
			_am(id, "spa", 12, -3, 3, 3)
			_am(id, "spa", 16, -3, 3, 3)
			_am(id, "piscine", -2, 3, 10, 5)
			_am(id, "gradins_beton", -18, 12, 13, 5, 0)
			_am(id, "bassin_ornement", 12, 6, 8, 8)
			look = Vector3(2, y0 + 1, 0)
			dist = 60.0
			yaw = 25.0
			pitch = 42.0
		"gare":
			_am(id, "voie_normale", -10, -50, 9, 100)
			_am(id, "quai_couvert", -1, -40, 6, 80)
			_am(id, "voie_lgv", 5, -50, 10, 100)
			_am(id, "quai", 15, -40, 4, 80)
			_am(id, "voie_tram", 19, -50, 6, 100)
			_am(id, "voie_metrique", -16, -50, 3, 100)
			_am(id, "voie_etroite", -20, -30, 2, 60)
			_am(id, "butoir", -20, 28, 2, 2, 0)
			look = Vector3(-14, y0 + 1, 26)
			dist = 30.0
			yaw = 30.0
			pitch = 32.0
		"terrains":
			_am(id, "tennis_terre", -40, -20)
			_am(id, "tennis", -21, -20)
			_am(id, "basket", -2, -20)
			_am(id, "volley", 18, -20)
			_am(id, "beach_volley", 34, -20)
			_am(id, "foot5", -40, 18)
			_am(id, "handball", -25, 18)
			_am(id, "patinoire", 0, 18, 32, 62, 0)
			_am(id, "petanque", 34, 18, 4, 15)
			_am(id, "petanque", 39, 18, 4, 15)
			_am(id, "golf_green", 34, 36)
			look = Vector3(0, y0, 18)
			dist = 120.0
			yaw = 20.0
			pitch = 48.0
		"zoo":
			_am(id, "bassin_animaux", -10, -8, 14, 16)
			_am(id, "aquarium", 8, -8, 3, 10)
			_am(id, "bassin_ornement", 8, 5, 6, 4)
			_am(id, "gradins_pierre", -10, 9, 14, 5, 0)
			look = Vector3(0, y0, 0)
			dist = 45.0
			yaw = 15.0
			pitch = 35.0
		"panneau":
			_am(id, "bassin_nage", -6, -12, 13, 25)
			_am(id, "gradins_beton", -6, 13, 13, 4, 0)
			var bp: BuildingPanel = scene.get_node("PanneauConstruction")
			scene.set_create_mode(true)
			bp.set_open(true)
			bp._block_mode = "plans"
			bp._plan_tab = onglet
			bp.show_category("blocs")
			await process_frame
			var sc: ScrollContainer = bp._list.get_parent()
			await process_frame
			for c in bp._list.get_children():
				if c is HFlowContainer and c.get_child_count() > 0 and (c.get_child(0) as Button).toggle_mode and c.get_child(0).has_meta("tab"):
					sc.scroll_vertical = int((c as Control).position.y) - 8
			look = Vector3(0, y0, 0)
			dist = 50.0
			yaw = 20.0
			pitch = 40.0
	pe.flush()
	rig.position = look
	rig._distance = dist
	rig._target_distance = dist
	rig.rotation_degrees.y = yaw
	if "pitch_degrees" in rig:
		rig.pitch_degrees = pitch
	for i in 120:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit(0)
