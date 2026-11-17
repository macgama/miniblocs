extends SceneTree
## Planche de modèles : pose des bâtiments, des véhicules ou des décors en
## grille, au soleil, et prend une capture. Sert à vérifier d'un coup d'œil un
## lot d'objets ajoutés au catalogue.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/catalogue_planche.gd -- --screenshot p.png --styles nubien,birman
##   ... -- --vehicules serie_1908,tonga --colonnes 6
##   ... -- --batiments maison,villa
##   ... -- --decors bec_gaz,torii   ou   --meubles phonographe_x,radio_tsf_y
##   ... -- --toits pagode,verriere   ou   --ouvertures hublot,fenetre_ogive (maquettes de l'Atelier)
##   ... -- --materiaux "Mycélium,Biobéton"   (cubes de 2 m)
## --colonnes N : objets par ligne. --yaw / --pitch : angle de la caméra. --largeur / --hauteur : taille de l'image.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "planche.png"
	var ids: Array = []
	var genre := "batiment"
	var cols := 0
	var yaw := 0.0
	var pitch := 38.0
	var size := Vector2i(1600, 900)
	for i in args.size():
		var v := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--screenshot": shot = v
			"--styles":
				for sid in v.split(","):
					var s: Dictionary = Styles.STYLES.get(sid, {})
					for arch in s.get("archs", []):
						ids.append("%s__%s" % [sid, arch])
			"--batiments": ids.append_array(v.split(","))
			"--vehicules":
				genre = "vehicule"
				ids.append_array(v.split(","))
			"--decors":
				genre = "decor"
				ids.append_array(v.split(","))
			"--meubles":
				genre = "meuble"
				ids.append_array(v.split(","))
			"--toits":
				genre = "toit"
				ids.append_array(v.split(","))
			"--ouvertures":
				genre = "ouverture"
				ids.append_array(v.split(","))
			"--materiaux":
				genre = "materiau"
				ids.append_array(v.split(","))
			"--colonnes": cols = v.to_int()
			"--yaw": yaw = v.to_float()
			"--pitch": pitch = v.to_float()
			"--largeur": size.x = v.to_int()
			"--hauteur": size.y = v.to_int()
	root.size = size
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("cfe3ee")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d8dde6")
	env.environment.ambient_light_energy = 0.4
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	scene.add_child(sun)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# Cases de la grille : taille de la plus grande emprise.
	var cell := 4.0
	for id in ids:
		if genre == "materiau":
			cell = 4.0
		elif genre == "toit":
			cell = maxf(cell, 12.0)
		elif genre == "ouverture":
			cell = maxf(cell, 6.0)
		elif genre == "decor" or genre == "meuble":
			cell = maxf(cell, _taille(genre, id) + 2.0)
		elif genre == "vehicule":
			var t := VehicleCatalog.get_type(id)
			cell = maxf(cell, maxf(float(t.get("L", 4.0)), float(t.get("W", 2.0))) + 2.0)
		else:
			var t := BuildingCatalog.get_type(id)
			cell = maxf(cell, maxf(float(t.get("w", 10)), float(t.get("d", 10))) + 6.0)
	if cols <= 0:
		cols = maxi(1, ceili(sqrt(ids.size() * 1.2)))
	var rows := ceili(float(ids.size()) / cols)
	var maxh := 0.0
	for i in ids.size():
		var id := String(ids[i])
		var mesh: ArrayMesh
		if genre == "materiau":
			var mid := BlocMateriaux.index_of(id)
			if mid < 0:
				push_error("matériau inconnu : " + id)
				continue
			var bm := BlocMesher.new()
			var cells := {}
			for x in 2:
				for y in roundi(BlockEditor.HU):
					for z in 2:
						cells[Vector3i(x, y, z)] = BlocFormes.encode(mid)
			for kk: Vector3i in cells:
				BlocFormes.emit(bm, int(cells[kk]), Vector3(kk.x * BlockEditor.SIZE, kk.y * BlockEditor.UNIT_Y, kk.z * BlockEditor.SIZE),
					func(off: Vector3i) -> int: return int(cells.get(kk + off, -1)))
			mesh = bm.to_mesh()
		elif genre == "toit":
			mesh = VignettesAtelier.roof_mesh(id)
		elif genre == "ouverture":
			mesh = VignettesAtelier.opening_mesh(id)
		elif genre == "decor":
			mesh = Decors.mesh(id) as ArrayMesh
			if mesh == null:
				push_error("décor inconnu : " + id)
				continue
		elif genre == "meuble":
			if not Meubles.has(id):
				push_error("meuble inconnu : " + id)
				continue
			mesh = MeublesModeles.mesh_of(id)
		elif genre == "vehicule":
			if VehicleCatalog.get_type(id).is_empty():
				push_error("véhicule inconnu : " + id)
				continue
			mesh = VehicleCatalog.build_mesh(id, -1, mat)
		else:
			if BuildingCatalog.get_type(id).is_empty():
				push_error("bâtiment inconnu : " + id)
				continue
			mesh = BuildingCatalog.build_mesh(id, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if genre == "decor":
			mi.material_override = Decors.materiau()
		var cx := (i % cols - (cols - 1) / 2.0) * cell
		var cz := (int(i / cols) - (rows - 1) / 2.0) * cell
		mi.position = Vector3(cx, 0, cz)
		if genre == "toit" or genre == "ouverture" or genre == "materiau":
			mi.position -= mesh.get_aabb().get_center() * Vector3(1, 0, 1)
		mi.rotation_degrees.y = 90.0 + 30.0 if genre == "vehicule" else 30.0
		scene.add_child(mi)
		maxh = maxf(maxh, mesh.get_aabb().size.y)
		var lab := Label3D.new()
		lab.text = _nom(genre, id)
		lab.font_size = 64
		lab.pixel_size = cell / 750.0
		lab.modulate = Color("1f2933")
		lab.outline_modulate = Color(1, 1, 1, 0.9)
		lab.outline_size = 18
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.position = Vector3(cx, 0.05, cz + cell * 0.45)
		lab.width = 700.0
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scene.add_child(lab)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(cols * cell + cell, rows * cell + cell)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("8fa37f")
	ground.material_override = gm
	ground.position.y = -0.02
	scene.add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var span := maxf(cols * cell, rows * cell * float(size.x) / size.y)
	var asp := float(size.x) / size.y
	cam.size = maxf(cols * cell / asp, rows * cell * sin(deg_to_rad(pitch)) + maxh * cos(deg_to_rad(pitch))) * 1.08
	var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	cam.position = dir * span * 2.0 + Vector3(0, maxh * 0.25, 0)
	cam.far = span * 6.0
	scene.add_child(cam)
	cam.look_at(Vector3(0, maxh * 0.25, 0))
	cam.current = true
	for f in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(shot)
	print("Planche : %d objets → %s" % [ids.size(), shot])
	quit()


func _taille(genre: String, id: String) -> float:
	if genre == "decor":
		var t: Array = Decors.info(id).get("taille", [2, 2, 2])
		return maxf(float(t[0]), float(t[1]))
	var e := Meubles.get_entry(id)
	return maxf(float(e.get("w", 1)), float(e.get("d", 1)))


func _nom(genre: String, id: String) -> String:
	match genre:
		"toit":
			for r in PlanEditor.ROOFS:
				if r[0] == id:
					return String(r[1])
		"ouverture": return String(PlanEditor.OPENINGS.get(id, {}).get("name", id))
		"materiau": return id
		"vehicule": return String(VehicleCatalog.get_type(id).get("name", id))
		"decor": return Decors.nom(id)
		"meuble": return String(Meubles.get_entry(id).get("n", id))
	return String(BuildingCatalog.get_type(id).get("name", id))
