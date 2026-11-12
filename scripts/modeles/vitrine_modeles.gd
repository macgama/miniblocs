extends Node3D
## Vitrine des bâtiments modélisés dans Blender (assets/modeles/batiments/*.glb).
## Ouvre scenes/vitrine_modeles.tscn et appuie sur F6 : les modèles sont posés
## côte à côte sur une pelouse, la caméra tourne autour.
## Molette : zoom. Clic gauche glissé : tourner. Espace : arrêter / relancer la rotation.
## C : couleurs au hasard (variantes, voir CouleursModele). X : couleurs d'origine.
## Capture en ligne de commande :
##   godot --path . res://scenes/vitrine_modeles.tscn -- --screenshot vitrine_glb.png [--modele stade_tuiliere]
## --modele nom : seulement ce modèle (nom du fichier sans .glb).
## --variante 7 : capture avec des couleurs au hasard (graine 7).

const DOSSIER := "res://assets/modeles/batiments"
const ECART := 4.0

var _cam: Camera3D
var _yaw := 35.0
var _pitch := 28.0
var _dist := 22.0
var _centre := Vector3.ZERO
var _tourne := true
var _poses: Array[Node3D] = []
var _chemins: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_decor()
	var x := 0.0
	var largeurs: Array[float] = []
	var noeuds: Array[Node3D] = []
	var args := OS.get_cmdline_user_args()
	var seul := ""
	var im := args.find("--modele")
	if im >= 0 and im + 1 < args.size():
		seul = args[im + 1]
	var d := DirAccess.open(DOSSIER)
	if d:
		for f in d.get_files():
			if not f.ends_with(".glb") or (seul != "" and f.get_basename() != seul):
				continue
			var sc := load(DOSSIER.path_join(f)) as PackedScene
			if sc == null:
				continue
			var n := sc.instantiate() as Node3D
			add_child(n)
			_poses.append(n)
			_chemins.append(DOSSIER.path_join(f))
			var lar := _largeur(n)
			n.position.x = x + lar / 2.0
			x += lar + ECART
			largeurs.append(lar)
			noeuds.append(n)
	if noeuds.is_empty():
		push_warning("Aucun .glb dans " + DOSSIER)
	_centre = Vector3((x - ECART) / 2.0, 3.0, 0)
	_dist = maxf(22.0, x * 1.25)
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	_place_camera()
	var iv := args.find("--variante")
	if iv >= 0 and iv + 1 < args.size():
		_rng.seed = args[iv + 1].to_int()
		_variantes()
	var i := args.find("--screenshot")
	if i >= 0 and i + 1 < args.size():
		_capture(args[i + 1])


func _decor() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("6f9fd8")
	ciel.sky_horizon_color = Color("cfdbe6")
	env.sky = Sky.new()
	env.sky.sky_material = ciel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-48, -35, 0)
	soleil.light_energy = 1.3
	soleil.shadow_enabled = true
	add_child(soleil)
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(1200, 1200)
	sol.mesh = plan
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6aa84f")
	mat.roughness = 1.0
	sol.material_override = mat
	add_child(sol)


func _largeur(n: Node) -> float:
	var l := 1.0
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		l = maxf(l, mi.mesh.get_aabb().size.x)
	return l


func _place_camera() -> void:
	var dir := Vector3(
		sin(deg_to_rad(_yaw)) * cos(deg_to_rad(_pitch)),
		sin(deg_to_rad(_pitch)),
		cos(deg_to_rad(_yaw)) * cos(deg_to_rad(_pitch)))
	_cam.position = _centre + dir * _dist
	_cam.look_at(_centre)


func _process(delta: float) -> void:
	if _tourne:
		_yaw += delta * 8.0
		_place_camera()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(6.0, _dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(300.0, _dist * 1.1)
		_place_camera()
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.3
		_pitch = clampf(_pitch + mm.relative.y * 0.3, 5.0, 85.0)
		_place_camera()
	elif e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_SPACE:
		_tourne = not _tourne
	elif e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_C:
		_variantes()
	elif e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_X:
		for n in _poses:
			for c in n.find_children("*", "MeshInstance3D", true, false):
				var mi := c as MeshInstance3D
				for s in mi.mesh.get_surface_count():
					mi.set_surface_override_material(s, null)


func _variantes() -> void:
	for k in _poses.size():
		CouleursModele.variante_au_hasard(_poses[k], _chemins[k], _rng)


func _capture(chemin: String) -> void:
	_tourne = false
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(chemin)
	print("CAPTURE OK ", chemin)
	get_tree().quit()
