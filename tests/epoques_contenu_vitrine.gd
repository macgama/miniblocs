extends SceneTree
## Vitrine du contenu d'époque 1800-1900 : planches de captures des bâtiments du
## XIXe siècle et des véhicules d'époque, posés sur une pelouse sous un soleil
## de fin de matinée. Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/epoques_contenu_vitrine.gd -- --dossier /chemin/captures
## Options : --groupe batiments|vehicules|tout, --ids id1,id2 (une seule planche).

var _mat: StandardMaterial3D


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _decor() -> Node3D:
	var n := Node3D.new()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("bcd8ec")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dfe8f0")
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	n.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	n.add_child(sun)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	sol.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("6f9a52")
	sol.material_override = sm
	sol.position.y = -0.02
	n.add_child(sol)
	return n


## Pose des modèles en grille, chacun avec son nom, et prend la photo.
func _planche(ids: Array, meshes: Callable, path: String, pas: float, cols: int, hauteur_cam: float) -> void:
	var scene := _decor()
	root.add_child(scene)
	cols = mini(cols, ids.size())
	var rows := ceili(float(ids.size()) / cols)
	for i in ids.size():
		var id: String = ids[i]
		var mi := MeshInstance3D.new()
		mi.mesh = meshes.call(id)
		mi.material_override = _mat
		var c := i % cols
		var r := i / cols
		mi.position = Vector3((c - (cols - 1) / 2.0) * pas, 0, (r - (rows - 1) / 2.0) * pas)
		mi.rotation_degrees.y = 180.0 + 25.0
		scene.add_child(mi)
		var lb := Label3D.new()
		lb.text = id
		lb.font_size = 96
		lb.pixel_size = pas * 0.0006
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = mi.position + Vector3(0, 0.2, pas * 0.42)
		lb.modulate = Color("1b1b1b")
		lb.outline_size = 18
		lb.outline_modulate = Color(1, 1, 1, 0.9)
		scene.add_child(lb)
	var cam := Camera3D.new()
	cam.fov = 32.0
	var etendue := maxf(cols, rows + 0.6) * pas
	cam.position = Vector3(0, etendue * hauteur_cam, etendue * 0.95)
	scene.add_child(cam)
	cam.look_at(Vector3(0, 0, pas * 0.1))
	cam.current = true
	await _shot(path)
	scene.queue_free()
	await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	var groupe := "tout"
	var ids_choisis := []
	for i in args.size() - 1:
		match args[i]:
			"--dossier": dir = args[i + 1]
			"--groupe": groupe = args[i + 1]
			"--ids": ids_choisis = Array(args[i + 1].split(","))
	root.size = Vector2i(1600, 900)
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.roughness = 0.9
	var bat := func(id: String) -> Mesh: return BuildingCatalog.build_mesh(id)
	var veh := func(id: String) -> Mesh: return VehicleCatalog.build_mesh(id)
	if not ids_choisis.is_empty():
		var est_veh := VehicleCatalog.TYPES.has(String(ids_choisis[0]))
		await _planche(ids_choisis, veh if est_veh else bat, dir.path_join("planche.png"), 14.0 if est_veh else 50.0, 4, 0.8)
		quit(0)
		return
	if groupe in ["batiments", "tout"]:
		var o: Array = EpoquesBatiments.ORDER
		var paquets := [o.slice(0, 12), o.slice(12, 24), o.slice(24)]
		for p in paquets.size():
			await _planche(paquets[p], bat, dir.path_join("batiments-1800-%d.png" % (p + 1)), 40.0, 4, 0.7)
	if groupe in ["vehicules", "tout"]:
		var familles := {"route": [], "rail": [], "eau": []}
		for vid in VehicleCatalog.TYPES:
			var vt: Dictionary = VehicleCatalog.TYPES[vid]
			if not bool(vt.get("siecle", false)):
				continue
			match int(vt.mode):
				VehicleCatalog.RAIL: familles.rail.append(vid)
				VehicleCatalog.WATER, VehicleCatalog.AIR: familles.eau.append(vid)
				_: familles.route.append(vid)
		await _planche(familles.route, veh, dir.path_join("vehicules-1800-route.png"), 7.0, 4, 0.7)
		await _planche(familles.rail, veh, dir.path_join("vehicules-1800-rail.png"), 14.0, 4, 0.7)
		await _planche(familles.eau, veh, dir.path_join("vehicules-1800-eau.png"), 75.0, 4, 0.6)
	quit(0)
