extends SceneTree
## Vitrine du zonage : zones peintes sur une colline (pente marquée) et panneau
## Zonage ouvert. Sert à vérifier que la couleur des zones épouse le relief.
## Usage (avec affichage) :
##   xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##     --script res://tests/zonage_vitrine.gd -- --screenshot zonage.png [--distance 140] [--yaw 30] [--pitch 35]
## --sans-panneau : sans le panneau Construire. --plat : terrain plat.
## --glisser : un rectangle en cours de peinture (pinceau). --defiler : panneau défilé vers le bas.


func _initialize() -> void:
	_run.call_deferred()


var _plat := false


## Colline : la pente monte vers le nord-est (environ 1 m tous les 2 à 3 m).
func _tuile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := float(t.x * 256 + x)
			var gy := float(t.y * 256 + y)
			a[y * 256 + x] = 40.0 if _plat else 80.0 + sin(gx * 0.035) * 30.0 + cos(gy * 0.03) * 25.0
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "zonage.png"
	var dist := 140.0
	var yaw := 30.0
	var pitch := -1.0
	_plat = args.has("--plat")
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--distance" and i + 1 < args.size():
			dist = args[i + 1].to_float()
		if args[i] == "--yaw" and i + 1 < args.size():
			yaw = args[i + 1].to_float()
		if args[i] == "--pitch" and i + 1 < args.size():
			pitch = args[i + 1].to_float()
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _tuile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	bs.unlimited_money = true
	var zs: ZoneSystem = scene.get_node("Zones")
	zs.growth = false
	var y := world.cell_height(Vector2i(0, -40))
	transport.build_segment("route", Vector3(-70, y, -40), Vector3(70, y, -40))
	zs.add_zone("R", Rect2i(-60, -30, 50, 40))
	zs.add_zone("C", Rect2i(-5, -30, 30, 40))
	zs.add_zone("I", Rect2i(30, -30, 35, 40))
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	amb.set_local_hour(13.0)
	var rig = scene.get_node("CameraRig")
	rig.position = Vector3(0, world.cell_height(Vector2i(0, -10)), -10)
	rig._distance = dist
	rig._target_distance = dist
	rig.rotation_degrees.y = yaw
	if pitch > 0.0 and "pitch_degrees" in rig:
		rig.pitch_degrees = pitch
	var panel = scene.get_node("PanneauConstruction")
	panel.visible = not args.has("--sans-panneau")
	if panel.visible:
		panel.set_open(true)
		panel.show_category("zones")
	for i in 90:
		await process_frame
	# Le pinceau Résidentielle choisi, comme après un clic sur sa carte.
	if panel.visible and panel.has_method("choisir_zone"):
		panel.choisir_zone("R")
	# Un rectangle en cours de peinture sur la pente (pinceau visible).
	if args.has("--glisser"):
		zs.set_paint("R")
		zs._cursor_valid = true
		zs._drag = true
		zs._drag_start = Vector2i(-60, 14)
		zs._cursor = Vector2i(-15, 40)
		zs._update_box()
	if args.has("--defiler"):
		for sc in panel.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 400
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit(0)
