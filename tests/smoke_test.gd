extends SceneTree
## Test de fumée : lance la scène principale, construit un petit quartier,
## attend la croissance, vérifie sauvegarde/chargement.
## Usage : godot --path . --script res://tests/smoke_test.gd [-- --screenshot chemin.png]

func _initialize() -> void:
	_run.call_deferred()


func _cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			r.append(Vector2i(x, y))
	return r


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var city = main.get_node("City")
	var ok := true

	city.set_tool(city.Tool.ROAD)
	city._apply_tool(_cells(Vector2i(20, 32), Vector2i(44, 32)))
	city._apply_tool(_cells(Vector2i(32, 22), Vector2i(32, 42)))
	city._apply_tool(_cells(Vector2i(20, 24), Vector2i(20, 40)))
	city.set_tool(city.Tool.RESIDENTIAL)
	city._apply_tool(_cells(Vector2i(21, 33), Vector2i(31, 35)))
	city._apply_tool(_cells(Vector2i(21, 29), Vector2i(31, 31)))
	city.set_tool(city.Tool.COMMERCIAL)
	city._apply_tool(_cells(Vector2i(33, 29), Vector2i(40, 31)))
	city.set_tool(city.Tool.INDUSTRIAL)
	city._apply_tool(_cells(Vector2i(33, 33), Vector2i(42, 35)))
	# Une zone posée sur la route ne doit pas l'écraser.
	city.set_tool(city.Tool.RESIDENTIAL)
	city._apply_tool([Vector2i(32, 32)])
	if city.get_cell(Vector2i(32, 32)) != city.Cell.ROAD:
		push_error("La zone a écrasé la route"); ok = false

	# Tracé de route en L.
	city.set_tool(city.Tool.ROAD)
	city._dragging = true
	city._drag_start = Vector2i(0, 0)
	city._hover = Vector2i(3, 2)
	var l: Array[Vector2i] = city._selection_cells()
	city._dragging = false
	if l.size() != 6 or l[-1] != Vector2i(3, 2):
		push_error("Tracé en L incorrect : %s" % [l]); ok = false

	for i in 120:
		await process_frame
	await create_timer(4.0).timeout
	print("Bâtiments après croissance : ", city.buildings.size())
	if city.buildings.size() < 20:
		push_error("Pas assez de bâtiments"); ok = false

	var args := OS.get_cmdline_user_args()
	var shot := args.find("--screenshot")
	if shot != -1:
		var cam: Node3D = main.get_node("CameraRig")
		cam.position = Vector3(32, 0, 32)
		cam.rotation_degrees.y = 25
		cam._target_distance = 30.0
		await create_timer(1.0).timeout
		await process_frame
		root.get_viewport().get_texture().get_image().save_png(args[shot + 1])
		print("Capture : ", args[shot + 1])

	var before: int = city.cells.size()
	if not city.save_city():
		push_error("Sauvegarde impossible"); ok = false
	city.clear_city()
	if city.cells.size() != 0:
		push_error("Effacement incomplet"); ok = false
	city.load_city()
	if city.cells.size() != before:
		push_error("Chargement : %d cases au lieu de %d" % [city.cells.size(), before]); ok = false

	city.set_tool(city.Tool.BULLDOZE)
	city._apply_tool(_cells(Vector2i(20, 32), Vector2i(44, 32)))
	if city.get_cell(Vector2i(25, 32)) != city.Cell.EMPTY:
		push_error("Bulldozer inefficace"); ok = false

	print("SMOKE TEST ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
