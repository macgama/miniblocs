extends SceneTree
## Vitrine du lot de décors du 2026-11-23 : un jardin public composé avec les
## nouveaux décors (arbres d'ornement, labyrinthe, étang, pont, parterres…),
## une rue en fête et deux immeubles à toit plat habillés (château d'eau,
## climatisation, burger géant, enseigne néon).
## Usage :
##   godot --path . --rendering-driver opengl3 --script res://tests/decors_scene_parc.gd -- --screenshot parc.png [--yaw 35] [--distance 70]

const SABLE := Color("e0cf9e")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "parc.png"
	var yaw := 35.0
	var dist := 88.0
	var pitch := 42.0
	for i in args.size():
		var v := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--screenshot": shot = v
			"--yaw": yaw = v.to_float()
			"--distance": dist = v.to_float()
			"--pitch": pitch = v.to_float()
	root.size = Vector2i(1600, 900)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("bcd8ea")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("dfe6ee")
	env.environment.ambient_light_energy = 0.3
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -140, 0)
	sun.light_energy = 0.8
	sun.light_color = Color("fff2dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	scene.add_child(sun)

	_boite(scene, Vector3(0, -0.2, 4), Vector3(64, 0.2, 64), Color("5e8f3c"))  # pelouse
	_boite(scene, Vector3(0, 0.0, 0), Vector3(3.2, 0.06, 44), SABLE)  # allées en croix
	_boite(scene, Vector3(0, 0.0, 0), Vector3(44, 0.06, 3.2), SABLE)
	_boite(scene, Vector3(0, 0.0, 26), Vector3(64, 0.08, 6), Color("8e8a86"))  # rue
	_boite(scene, Vector3(0, 0.0, 23), Vector3(64, 0.1, 1.2), Color("c9c1ae"))  # trottoir
	_boite(scene, Vector3(-12, 0, 36), Vector3(14, 10, 10), Color("e8d9c0"))  # immeubles à toit plat
	_boite(scene, Vector3(9, 0, 35), Vector3(12, 6.5, 8), Color("d99a7a"))

	var p := [
		# Jardin
		["fontaine", 0, 0, 0], ["labyrinthe_haies", -12, -12, 0], ["etang_rochers", 11, -11, 0],
		["pont_japonais", 11, -6.2, 0], ["cerisier_fleurs", 6, -16, 0], ["cerisier_fleurs", 16, -15, 40],
		["erable_rouge", 16, -6, 0], ["tsukubai", 7, -7, 0], ["parterre_rond", -7, 7, 0],
		["parterre_francais", -15, 12, 0], ["gloriette", 13, 11, 0], ["banc_arbre", 6, 16, 0],
		["pergola_vigne", 17, 18, 0], ["nappe_pique_nique", 7, 5, 20], ["arche_roses", 0, 20.5, 0],
		["bac_a_sable_hexa", -7, 17, 0], ["jacaranda", -19, 1, 0], ["bouleau_blanc", -18, -3, 0],
		["bouleau_blanc", -20, 5, 0], ["arbre_automne", 19, 3, 0], ["magnolia", -4, -20, 0],
		["saule_pleureur", 19, -12, 0], ["bain_oiseaux", -4, 11, 0], ["cadran_solaire", -11, 3, 0],
		["nichoir", 9, 20, 0], ["rocaille", 4, -4, 0], ["vasque_fleurie", -2.4, 2.4, 0], ["vasque_fleurie", 2.4, -2.4, 0],
		["bassin_nenuphars", -14, 20, 0], ["serre_jardin", -19, 17, 90],
		# Topiaires et éclairage le long des allées
		["topiaire_cone", -2.4, -8, 0], ["topiaire_cone", 2.4, -8, 0], ["topiaire_boule", -2.4, -14, 0],
		["topiaire_boule", 2.4, -14, 0], ["topiaire_spirale", -2.4, 8, 0], ["topiaire_spirale", 2.4, 8, 0],
		["lampadaire_parc", 2.2, 13, 0], ["lampadaire_parc", -2.2, -18, 0], ["lampadaire_parc", 13, 2.2, 0],
		["lampadaire_parc", -13, -2.2, 0], ["borne_jardin", 2, 4, 0], ["borne_jardin", -2, -4, 0],
		["cypres", 22, -20, 0], ["cypres", 22, -16, 0], ["cypres", 22, -12, 0],
		# Rue en fête
		["guirlande_ampoules", -18, 23.4, 0], ["fanions", 2, 23.4, 0], ["chariot_hot_dog", -8, 22, 180],
		["chariot_popcorn", -4, 22, 180], ["chariot_ballons", 5, 22, 0], ["stand_tir", 22, 22, 180],
		["charrette_fleurs", 13, 22, 180], ["stand_limonade", -24, 22, 180], ["arche_ballons", 0, 23.2, 0],
		# Toits et façades
		["chateau_eau_toit", -15, 37, 0], ["climatiseurs_toit", -9, 35, 0], ["parabole", -7, 39, 180],
		["burger_geant", 9, 35, 30], ["climatiseur", 13, 37, 0], ["enseigne_neon", 3.0, 31.5, 0],
		["distributeur_boissons", 4.6, 30.5, 180], ["comptoir_tabourets", 9, 30.3, 0], ["lanternes_rouges", 9, 29.8, 0],
		["plantes_pots", -6, 30.6, 0], ["arbre_pot", -18, 30.6, 0], ["arbre_pot", -15, 30.6, 0],
	]
	var toits := {"chateau_eau_toit": 10.0, "climatiseurs_toit": 10.0, "parabole": 10.0, "burger_geant": 6.5, "climatiseur": 6.5}
	var n := 0
	for e: Array in p:
		var id := String(e[0])
		var m := Decors.mesh(id)
		if m == null:
			push_error("décor inconnu : " + id)
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = Decors.materiau()
		mi.position = Vector3(float(e[1]), float(toits.get(id, 0.03)), float(e[2]))
		mi.rotation_degrees.y = float(e[3])
		scene.add_child(mi)
		n += 1

	var cam := Camera3D.new()
	cam.fov = 40.0
	var cible := Vector3(0, 2, 6)
	var a := deg_to_rad(yaw)
	var b := deg_to_rad(pitch)
	cam.position = cible + Vector3(sin(a) * cos(b), sin(b), -cos(a) * cos(b)) * dist
	scene.add_child(cam)
	cam.look_at(cible)
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shot)
	print("Vitrine : %d décors → %s" % [n, shot])
	quit(0)


func _boite(parent: Node3D, bas: Vector3, taille: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	bm.material = mat
	mi.mesh = bm
	mi.position = bas + Vector3(0, taille.y / 2.0, 0)
	parent.add_child(mi)
