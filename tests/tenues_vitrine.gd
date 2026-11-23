extends SceneTree
## Captures des tenues des personnages (Tenues) : métiers en uniforme et
## passants, selon l'époque, la saison et la région.
## Usage (avec affichage, rendu Forward+) :
##   godot --path . --script res://tests/tenues_vitrine.gd -- --prefixe captures/tenues/x [--annee 1850]
##        [--temp 16] [--pluie 0] [--region europe] [--vues metiers,civils]
## Écrit <prefixe>-metiers.png et <prefixe>-civils.png.

const METIERS := ["pompier", "policier", "medecin", "infirmier", "ouvrier", "mineur", "agriculteur",
	"boulanger", "cuisinier", "boucher", "serveur", "cadre", "bucheron", "eboueur"]
const REGIONS := ["europe", "afrique", "asie_est", "mediterranee", "ameriques", "moyen_orient", "europe", "asie_sud"]


func _initialize() -> void:
	_run.call_deferred()


func _arg(args: PackedStringArray, nom: String, defaut: String) -> String:
	var i := args.find(nom)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else defaut


func _scene() -> Node3D:
	var s := Node3D.new()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("a9c9e8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c8d4e0")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	s.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 25, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	s.add_child(sun)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	sol.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("9aa58a")
	sol.material_override = sm
	s.add_child(sol)
	return s


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	var pre := _arg(args, "--prefixe", "tenues")
	var region := _arg(args, "--region", "europe")
	# Contexte imposé (si le jeu connaît les tenues : avant ce chantier, non).
	if ResourceLoader.exists("res://scripts/habitants/tenues.gd"):
		var T: Script = load("res://scripts/habitants/tenues.gd")
		T.set("force", {"annee": int(_arg(args, "--annee", "2025")), "temp": float(_arg(args, "--temp", "16")),
			"pluie": float(_arg(args, "--pluie", "0")), "saison": int(_arg(args, "--saison", "1")), "region": region})
	var vues := _arg(args, "--vues", "metiers,civils").split(",")
	for v in vues:
		var s := _scene()
		root.add_child(s)
		var cam := Camera3D.new()
		cam.fov = 32
		s.add_child(cam)
		if v == "metiers":
			for i in METIERS.size():
				var f := Figurine.creer(4100 + i * 13, METIERS[i])
				f.regler("conseiller")
				f.animer(0.0)
				# Deux rangées de sept, la seconde en quinconce.
				var rang := i / 7
				f.position = Vector3(-4.2 + (i % 7) * 1.4 + rang * 0.7, 0, 1.0 - rang * 2.2)
				f.rotation.y = 0.2
				s.add_child(f)
			cam.position = Vector3(0, 2.6, 12.5)
			cam.look_at(Vector3(0, 0.6, 0))
		elif v == "gros":
			# Gros plan : quatre passants.
			for i in 4:
				var look3 := Silhouettes.apparence(7300 + i * 5, [34.0, 29.0, 78.0, 10.0][i], "F" if i % 2 == 1 else "H", region if region != "monde" else REGIONS[i], 500 + i)
				var n3 := Silhouettes.creer(look3, true)
				n3.position = Vector3(-1.5 + i * 1.0, 0, 0)
				n3.rotation.y = -0.35 + i * 0.2
				s.add_child(n3)
				Silhouettes.marcher(n3, 0.5 + i, 0.5)
			cam.position = Vector3(0, 1.7, 5.0)
			cam.look_at(Vector3(0, 1.0, 0))
		else:
			# Une rangée de civils de tous âges, puis une petite foule derrière.
			var ages := [7.0, 12.0, 16.0, 24.0, 31.0, 38.0, 45.0, 52.0, 60.0, 68.0, 76.0, 84.0]
			for i in ages.size():
				var look := Silhouettes.apparence(7000 + i * 7, ages[i], "F" if i % 2 == 0 else "H", REGIONS[i % REGIONS.size()] if region == "monde" else region, 300 + i)
				var n := Silhouettes.creer(look, true)
				n.position = Vector3(-6.0 + i * 1.1, 0, 0)
				n.rotation.y = 0.3
				s.add_child(n)
				Silhouettes.marcher(n, 0.6 + i, 0.6)
			for j in 16:
				var age2 := 18.0 + float((j * 37) % 60)
				var look2 := Silhouettes.apparence(9000 + j * 11, age2, "F" if j % 3 == 0 else "H", REGIONS[j % REGIONS.size()] if region == "monde" else region, 900 + j)
				var n2 := Silhouettes.creer(look2, true)
				n2.position = Vector3(-7.0 + (j % 8) * 2.0 + (j / 8) * 1.0, 0, -2.2 - (j / 8) * 1.8)
				n2.rotation.y = 0.4 * (j % 3) - 0.2
				s.add_child(n2)
				Silhouettes.marcher(n2, j * 1.3, 0.8)
			cam.position = Vector3(0, 2.6, 10.5)
			cam.look_at(Vector3(0, 0.85, -1.0))
		for k in 10:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s-%s.png" % [pre, v])
		print("capture ", pre, "-", v)
		s.queue_free()
		await process_frame
	quit()
