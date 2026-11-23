extends SceneTree
## Planche « avant / après » des bâtiments de la ville : chaque bâtiment est
## photographié seul, de trois quarts face (façade −Z), puis les vignettes sont
## assemblées en une seule image. Sert à juger le niveau de détail et le charme.
## Usage (avec affichage) :
##   godot --path . --script res://tests/batiments_detail_vitrine.gd -- --screenshot p.png --ids immeuble,mairie
##   --variantes : les 4 variantes de chaque id. --loin : version lointaine (sans finitions).
##   --colonnes N, --tuile 480 (côté d'une vignette en pixels), --yaw 35, --pitch 32.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "batiments_detail.png"
	var ids: Array = []
	var variantes := false
	var loin := false
	var cols := 0
	var tuile := 480
	var yaw := 35.0
	var pitch := 32.0
	for i in args.size():
		var v := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--screenshot": shot = v
			"--ids": ids.append_array(v.split(","))
			"--variantes": variantes = true
			"--loin": loin = true
			"--colonnes": cols = v.to_int()
			"--tuile": tuile = v.to_int()
			"--yaw": yaw = v.to_float()
			"--pitch": pitch = v.to_float()
	var jobs: Array = []
	for id in ids:
		var n := BuildingCatalog.variants_of(String(id)) if variantes else 1
		for vi in n:
			jobs.append([String(id), vi])
	if cols <= 0:
		cols = mini(jobs.size(), 4)
	var rows := ceili(float(jobs.size()) / cols)
	root.size = Vector2i(tuile, tuile)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("bfe0ea")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dfe6f0")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 150, 0)
	sun.light_energy = 1.05
	sun.light_color = Color("fff3e0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	scene.add_child(sun)
	var mat := NightWindows.building_material()
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("9cb987")
	ground.material_override = gm
	ground.position.y = -0.03
	scene.add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 2000.0
	scene.add_child(cam)
	cam.current = true
	var planche := Image.create(cols * tuile, rows * tuile, false, Image.FORMAT_RGBA8)
	planche.fill(Color("bfe0ea"))
	var mi := MeshInstance3D.new()
	scene.add_child(mi)
	var lab := Label3D.new()
	for j in jobs.size():
		var id: String = jobs[j][0]
		var vi: int = jobs[j][1]
		if BuildingCatalog.get_type(id).is_empty():
			push_error("bâtiment inconnu : " + id)
			continue
		var mesh := BuildingCatalog.build_mesh(id, mat, not loin, vi)
		mi.mesh = mesh
		var bb := mesh.get_aabb()
		var c := bb.get_center()
		var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), -cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
		var r := bb.size.length() * 0.5
		cam.size = r * 1.75
		cam.position = c + dir * (r * 4.0 + 50.0)
		cam.look_at(c)
		for f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		planche.blit_rect(img, Rect2i(0, 0, tuile, tuile), Vector2i((j % cols) * tuile, int(j / cols) * tuile))
		print("  %s #%d : %d triangles" % [id, vi, _tris(mesh)])
	planche.save_png(shot)
	print("Planche : %d vignettes → %s" % [jobs.size(), shot])
	quit()


func _tris(m: ArrayMesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		n += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n
