extends Node3D
## Vitrine des décors : quatre petits mondes (place de village, ferme et
## prés, port, aire de jeux et montagne) puis le catalogue complet.
## Ouvre scenes/vitrine_decors.tscn et appuie sur F6.
## Touches 1 à 5 : place du village, ferme, port, jeux et montagne, catalogue.
## N : nuit (les lanternes s'allument). Molette : zoom. Clic gauche glissé : tourner.
## Espace : arrêter / relancer la rotation.
## Capture : godot --path . res://scenes/vitrine_decors.tscn -- --screenshot decors.png [--vue 2] [--nuit]

var _cam: Camera3D
var _yaw := 30.0
var _pitch := 30.0
var _dist := 60.0
var _centre := Vector3.ZERO
var _tourne := true
var _groupes := {} # id -> Array[Transform3D]
var _rng := RandomNumberGenerator.new()
var _animaux: Array = [] # [id, indice, position, maison, cible, angle, pause]
var _mmi := {}
var _soleil: DirectionalLight3D
var _env: Environment
var _nuit := false
var _texte: Label
var _vues: Array = []

const ZONES := {
	"place": Vector3(0, 0, 0), "ferme": Vector3(90, 0, 0), "port": Vector3(0, 0, 90),
	"jeux": Vector3(90, 0, 90), "catalogue": Vector3(-160, 0, -40),
}


func _ready() -> void:
	_rng.seed = 11
	_decor()
	_place_village(ZONES.place)
	_ferme(ZONES.ferme)
	_port(ZONES.port)
	_jeux_montagne(ZONES.jeux)
	_catalogue(ZONES.catalogue)
	_construit()
	_cam = Camera3D.new()
	_cam.fov = 45
	_cam.far = 3000
	add_child(_cam)
	_texte = Label.new()
	_texte.position = Vector2(16, 12)
	_texte.add_theme_font_size_override("font_size", 22)
	_texte.add_theme_color_override("font_outline_color", Color.BLACK)
	_texte.add_theme_constant_override("outline_size", 6)
	add_child(_texte)
	_vues = [
		["Place du village", ZONES.place, 48.0, 30.0, 32.0],
		["Ferme, champs et prés", ZONES.ferme + Vector3(0, 0, 4), 75.0, 40.0, 35.0],
		["Port et plage", ZONES.port + Vector3(0, 0, 8), 70.0, 210.0, 28.0],
		["Jeux, sport et montagne", ZONES.jeux, 62.0, 35.0, 32.0],
		["Catalogue : %d décors" % Decors.tous().size(), Vector3(-160 + 50, 0, -40 - 40), 150.0, 0.0, 55.0],
	]
	var args := OS.get_cmdline_user_args()
	_nuit = args.has("--nuit")
	_applique_nuit()
	var iv := args.find("--vue")
	_vue(int(args[iv + 1]) if iv >= 0 and iv + 1 < args.size() else 1)
	var i := args.find("--screenshot")
	if i >= 0 and i + 1 < args.size():
		_capture(args[i + 1])


func _decor() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("6f9fd8")
	ciel.sky_horizon_color = Color("cfdbe6")
	_env.sky = Sky.new()
	_env.sky.sky_material = ciel
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.ssao_enabled = true
	_env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_soleil = DirectionalLight3D.new()
	_soleil.rotation_degrees = Vector3(-50, -40, 0)
	_soleil.light_energy = 1.3
	_soleil.shadow_enabled = true
	_soleil.directional_shadow_max_distance = 300.0
	add_child(_soleil)
	_sol(Vector3(-20, 0, -20), Vector2(600, 600), Color("6a9a4a"), -0.02)


func _sol(c: Vector3, taille: Vector2, couleur: Color, y := 0.0) -> void:
	var m := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = taille
	m.mesh = plan
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	mat.roughness = 1.0
	m.material_override = mat
	m.position = c + Vector3(0, y, 0)
	add_child(m)


func _pose(id: String, p: Vector3, ang := 0.0, sc := 1.0) -> void:
	if not _groupes.has(id):
		_groupes[id] = []
	if Decors.est_anime(id):
		_animaux.append([id, (_groupes[id] as Array).size(), Vector2(p.x, p.z), Vector2(p.x, p.z), Vector2(p.x, p.z), ang, _rng.randf() * 6.0])
	(_groupes[id] as Array).append(Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * sc), p))


func _ligne(id: String, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var n := maxi(1, roundi(d.length() / Decors.ligne(id)))
	var ang := atan2(-d.z, d.x)
	for i in n:
		_pose(id, a + d * ((i + 0.5) / n), ang)


func _place_village(o: Vector3) -> void:
	_sol(o, Vector2(40, 40), Color("b3aa98"), 0.0)
	_pose("fontaine", o)
	for a in 4:
		var ang := a * PI / 2.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		_pose("banc_vert", o + dir * 6.0, ang + PI)
		_pose("reverbere", o + dir * 9.0 + dir.cross(Vector3.UP) * 3.0)
		_pose("jardiniere", o + dir * 13.0, ang)
	_pose("statue", o + Vector3(-14, 0, -14), PI / 4.0)
	_pose("colonne_affichage", o + Vector3(14, 0, -14))
	_pose("cabine_telephone", o + Vector3(16, 0, -10), -PI / 2.0)
	_pose("boite_aux_lettres", o + Vector3(16, 0, -6.5), -PI / 2.0)
	_pose("abribus", o + Vector3(-17, 0, 6), PI / 2.0)
	_pose("panneau_publicite", o + Vector3(-17, 0, -4), PI / 2.0)
	for i in 3:
		_pose("terrasse_cafe", o + Vector3(8 + i * 3.2, 0, 13), 0.3 * i)
	for i in 3:
		_pose(["etal_fruits", "tente_marche", "etal_fruits"][i], o + Vector3(-12 + i * 4.5, 0, 14), PI)
	_pose("caisses", o + Vector3(-15, 0, 16.5))
	_pose("charrette", o + Vector3(-2, 0, 17), 1.3)
	_pose("poubelles_tri", o + Vector3(15, 0, 4), -PI / 2.0)
	_pose("arceaux_velo", o + Vector3(15, 0, 0), -PI / 2.0)
	_pose("borne_incendie", o + Vector3(10, 0, -16))
	_pose("horloge", o + Vector3(4, 0, -16))
	_pose("potelets", o + Vector3(-4, 0, -18.5))
	_pose("poubelle", o + Vector3(-8, 0, -6), PI / 4.0)
	_pose("monument_morts", o + Vector3(-13, 0, -13 + 30), 0.0)
	_pose("chien", o + Vector3(3, 0, 8), 1.0)
	for x in range(-18, 20, 6):
		_pose("lampadaire", Vector3(o.x + x, 0, o.z - 20.5), 0.0)
	_ligne("haie", o + Vector3(-20, 0, 20.5), o + Vector3(20, 0, 20.5))


func _ferme(o: Vector3) -> void:
	_sol(o + Vector3(-12, 0, -10), Vector2(36, 24), Color("c9b56a"), 0.0)
	for i in 6:
		for j in 3:
			_pose("botte_ronde" if (i + j) % 4 else "botte_enrubannee", o + Vector3(-26 + i * 5.5, 0, -18 + j * 6.0), PI / 2.0 + _rng.randf_range(-0.2, 0.2))
	_pose("tracteur", o + Vector3(-6, 0, -4), 0.6)
	_pose("remorque_foin", o + Vector3(-9, 0, 1), 0.6)
	_pose("pile_bottes", o + Vector3(2, 0, -18), 0.0)
	_pose("meule", o + Vector3(8, 0, -14))
	_pose("epouvantail", o + Vector3(-20, 0, -5))
	_pose("moissonneuse", o + Vector3(-22, 0, 10), 2.0)
	# Pré clôturé et son troupeau
	var p := o + Vector3(18, 0, 6)
	var c := 14.0
	_ligne("cloture_ranch", p + Vector3(-c, 0, -c), p + Vector3(c, 0, -c))
	_ligne("cloture_ranch", p + Vector3(-c, 0, c), p + Vector3(c, 0, c))
	_ligne("cloture_ranch", p + Vector3(-c, 0, -c), p + Vector3(-c, 0, c))
	_ligne("cloture_ranch", p + Vector3(c, 0, -c), p + Vector3(c, 0, c))
	for i in 9:
		_pose(["vache_pie_noire", "vache_broute", "vache_rousse", "veau", "vache_blanche"][i % 5],
			p + Vector3(_rng.randf_range(-11, 11), 0, _rng.randf_range(-11, 11)), _rng.randf() * TAU)
	_pose("abreuvoir", p + Vector3(8, 0, -10), 0.2)
	_pose("ratelier", p + Vector3(-8, 0, -10), 0.0)
	# Moutons, chevaux, basse-cour
	for i in 8:
		_pose(["brebis", "mouton_broute", "agneau"][i % 3], o + Vector3(_rng.randf_range(-30, -12), 0, _rng.randf_range(16, 30)), _rng.randf() * TAU)
	for i in 4:
		_pose(["cheval", "cheval_blanc", "poney", "ane"][i], o + Vector3(_rng.randf_range(0, 14), 0, _rng.randf_range(24, 32)), _rng.randf() * TAU)
	_pose("poulailler", o + Vector3(-6, 0, 14), 0.4)
	for i in 6:
		_pose(["poule_blanche", "poule_rousse"][i % 2], o + Vector3(_rng.randf_range(-10, -2), 0, _rng.randf_range(16, 20)), _rng.randf() * TAU)
	_pose("cochon", o + Vector3(-2, 0, 18), 1.0)
	_pose("chevre", o + Vector3(-12, 0, 12), 2.0)
	_pose("puits", o + Vector3(2, 0, 12))
	_pose("tas_bois", o + Vector3(6, 0, 12), 0.5)
	_pose("brouette", o + Vector3(4, 0, 15), 2.5)
	_pose("ruches", o + Vector3(-28, 0, 4), 0.3)
	_pose("silo_grain", o + Vector3(26, 0, -16))
	_pose("bidons_lait", o + Vector3(18, 0, -16), 0.0)
	_pose("portail_ferme", p + Vector3(0, 0, -c - 0.2))
	_pose("serre_tunnel", o + Vector3(36, 0, 14), 0.0)
	for i in 4:
		_pose("pommier", o + Vector3(-34 + i * 6, 0, -32))
	for i in 5:
		for r in 2:
			_pose(["citrouilles", "choux", "tomates"][r if i % 2 else 2 - r], o + Vector3(32 + i * 1.2, 0, -8 + r * 1.5))
	for x in range(-40, 44, 40):
		_pose("poteau_electrique", o + Vector3(x, 0, 40), 0.0)


func _port(o: Vector3) -> void:
	# Mer au sud (+Z), plage, quai.
	_sol(o + Vector3(0, 0, 32), Vector2(140, 60), Color("3f7fa8"), 0.05)
	_sol(o + Vector3(18, 0, -4), Vector2(50, 12), Color("e0cf9e"), 0.01)
	_sol(o + Vector3(-22, 0, -2), Vector2(30, 8), Color("9a958a"), 0.02)
	_pose("ponton", o + Vector3(-28, -0.55, 2), 0.0)
	_pose("ponton", o + Vector3(-14, -0.55, 2), 0.0)
	_pose("bateau_peche", o + Vector3(-22, 0.05, 9), 0.0)
	_pose("barque", o + Vector3(-9, 0.05, 6), 0.2)
	_pose("voilier", o + Vector3(-4, 0.05, 30), 1.2)
	_pose("voilier_ancre", o + Vector3(10, 0.05, 24), 2.4)
	_pose("bateau_moteur", o + Vector3(-34, 0.05, 18), 0.6)
	_pose("kayak", o + Vector3(14, 0.05, 6), 1.4)
	_pose("pedalo", o + Vector3(24, 0.05, 6), 0.4)
	_pose("bouee", o + Vector3(0, 0.05, 18))
	_pose("balise_verte", o + Vector3(-36, 0.05, 30))
	_pose("balise_rouge", o + Vector3(-24, 0.05, 30))
	_pose("phare", o + Vector3(-42, 0, 2))
	_pose("casiers", o + Vector3(-24, 0, -3))
	for x in [-31.0, -17.0]:
		_pose("bitte", o + Vector3(x, 0, 1))
	for i in 5:
		var p := o + Vector3(6 + i * 7, 0, -5 + (i % 2) * 2)
		_pose("parasol_plage", p, _rng.randf() * TAU)
		_pose("transat", p + Vector3(1.2, 0, 0.3), 3.0)
		_pose("transat", p + Vector3(-1.2, 0, 0.3), 3.3)
	_pose("cabine_plage", o + Vector3(8, 0, -9), PI)
	_pose("cabine_plage", o + Vector3(11, 0, -9), PI)
	_pose("maitre_nageur", o + Vector3(28, 0, -2), PI)
	_pose("stand_glaces", o + Vector3(20, 0, -9), PI)
	for i in 3:
		_pose("canard", o + Vector3(36 + i * 1.2, 0.05, 12 + i), 1.0)
	_pose("rochers_cote", o + Vector3(42, 0, 2))


func _jeux_montagne(o: Vector3) -> void:
	_sol(o + Vector3(-10, 0, 0), Vector2(30, 26), Color("7fb05a"), 0.0)
	_pose("balancoire", o + Vector3(-18, 0, -6))
	_pose("toboggan", o + Vector3(-10, 0, -6), 0.3)
	_pose("tourniquet", o + Vector3(-18, 0, 3))
	_pose("jeu_ressort", o + Vector3(-13, 0, 3), 0.6)
	_pose("bac_a_sable", o + Vector3(-6, 0, 4))
	_pose("cabane_jeux", o + Vector3(-2, 0, -6), 0.4)
	_pose("table_pique_nique", o + Vector3(-20, 0, 10), 0.2)
	_pose("banc_bois", o + Vector3(-12, 0, 11), PI)
	_pose("ping_pong", o + Vector3(-4, 0, 11))
	_ligne("grillage", o + Vector3(-25, 0, -13), o + Vector3(5, 0, -13))
	_pose("cage_foot", o + Vector3(14, 0, -10))
	_pose("cage_foot", o + Vector3(14, 0, 14), PI)
	_pose("panier_basket", o + Vector3(24, 0, 2), -PI / 2.0)
	_sol(o + Vector3(14, 0, 2), Vector2(18, 28), Color("5b9a4a"), 0.01)
	# Montagne : rochers, menhir, troupeau d'alpage, forêt morte
	var m := o + Vector3(10, 0, 40)
	_sol(m, Vector2(70, 30), Color("8e8a6e"), 0.0)
	_pose("falaise_bloc", m + Vector3(-20, 0, 8), 0.4)
	_pose("bloc_granit", m + Vector3(-10, 0, 6), 1.0)
	_pose("eboulis", m + Vector3(-14, 0, 0))
	_pose("menhir", m + Vector3(4, 0, 4))
	_pose("dolmen", m + Vector3(14, 0, 6), 0.3)
	_pose("cairn", m + Vector3(-2, 0, -4))
	_pose("rocher_moussu", m + Vector3(22, 0, -4))
	_pose("rocher_plat", m + Vector3(-26, 0, -6))
	_pose("rocher_rouge", m + Vector3(28, 0, 8))
	_pose("galets", m + Vector3(8, 0, -6))
	_pose("souche", m + Vector3(0, 0, 10))
	_pose("tronc_mort", m + Vector3(-4, 0, 12), 0.7)
	_pose("grumes", m + Vector3(30, 0, -8), 1.4)
	for i in 3:
		_pose(["lama", "renne", "dromadaire"][i], m + Vector3(-8 + i * 8, 0, 12), 0.5 * i)
	_pose("yack", m + Vector3(20, 0, 12), 2.0)
	_pose("zebu", m + Vector3(-20, 0, -10), 1.0)
	_pose("pylone", m + Vector3(30, 0, 18))


func _catalogue(o: Vector3) -> void:
	var tous := Decors.tous()
	var colonnes := 16
	_sol(o + Vector3(50, 0, -38), Vector2(130, 100), Color("c8c4b8"), 0.0)
	for i in tous.size():
		var e: Dictionary = tous[i]
		var p := o + Vector3((i % colonnes) * 7.0, 0, -(i / colonnes) * 8.0)
		var sc := minf(1.0, 5.5 / maxf(0.5, maxf(Decors.hauteur(e.id), Decors.emprise(e.id))))
		_groupes_fixe(e.id, Transform3D(Basis(Vector3.UP, 0.5).scaled(Vector3.ONE * sc), p + (Vector3(0, 0.6, 0) if Decors.sur_eau(e.id) else Vector3.ZERO)))
		var l := Label3D.new()
		l.text = String(e.nom)
		l.font_size = 48
		l.pixel_size = 0.012
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color("1d2430")
		l.outline_size = 0
		l.position = p + Vector3(0, -0.3, 2.6)
		l.width = 600
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(l)


func _groupes_fixe(id: String, t: Transform3D) -> void:
	if not _groupes.has(id):
		_groupes[id] = []
	(_groupes[id] as Array).append(t)


func _construit() -> void:
	for id: String in _groupes:
		var m := Decors.mesh(id)
		if m == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		var l: Array = _groupes[id]
		mm.instance_count = l.size()
		for i in l.size():
			mm.set_instance_transform(i, l[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Decors.materiau()
		add_child(mmi)
		_mmi[id] = mmi


func _applique_nuit() -> void:
	Decors.set_nuit(1.0 if _nuit else 0.0)
	_soleil.light_energy = 0.08 if _nuit else 1.3
	_soleil.light_color = Color("8fa4d8") if _nuit else Color.WHITE
	_env.background_energy_multiplier = 0.08 if _nuit else 1.0
	_env.ambient_light_energy = 0.25 if _nuit else 1.0


func _vue(n: int) -> void:
	n = clampi(n, 1, _vues.size())
	var v: Array = _vues[n - 1]
	_texte.text = "%s  —  1-5 : vues, N : nuit, Espace : rotation" % v[0]
	_centre = v[1]
	_dist = v[2]
	_yaw = v[3]
	_pitch = v[4]
	_tourne = n != 5
	_place_camera()


func _place_camera() -> void:
	var dir := Vector3(
		sin(deg_to_rad(_yaw)) * cos(deg_to_rad(_pitch)),
		sin(deg_to_rad(_pitch)),
		cos(deg_to_rad(_yaw)) * cos(deg_to_rad(_pitch)))
	_cam.position = _centre + dir * _dist
	_cam.look_at(_centre)


func _process(delta: float) -> void:
	if _tourne:
		_yaw += delta * 5.0
		_place_camera()
	# Les animaux broutent et se promènent.
	for a: Array in _animaux:
		if a[6] > 0.0:
			a[6] -= delta
			continue
		var pos: Vector2 = a[2]
		var cible: Vector2 = a[4]
		if pos.distance_to(cible) < 0.2:
			a[4] = (a[3] as Vector2) + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
			a[6] = _rng.randf_range(3.0, 10.0)
			continue
		var d := (cible - pos).normalized()
		a[5] = lerp_angle(a[5], atan2(d.x, d.y), minf(1.0, delta * 2.5))
		pos += Vector2(sin(a[5]), cos(a[5])) * 0.4 * delta
		a[2] = pos
		var mmi: MultiMeshInstance3D = _mmi.get(a[0])
		if mmi:
			var t: Transform3D = mmi.multimesh.get_instance_transform(a[1])
			mmi.multimesh.set_instance_transform(a[1], Transform3D(Basis(Vector3.UP, a[5]).scaled(Vector3.ONE * t.basis.get_scale().x), Vector3(pos.x, t.origin.y, pos.y)))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(4.0, _dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(500.0, _dist * 1.1)
		_place_camera()
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.3
		_pitch = clampf(_pitch + mm.relative.y * 0.3, 3.0, 85.0)
		_place_camera()
	elif e is InputEventKey and e.pressed:
		var k := (e as InputEventKey).keycode
		if k == KEY_SPACE:
			_tourne = not _tourne
		elif k == KEY_N:
			_nuit = not _nuit
			_applique_nuit()
		elif k >= KEY_1 and k <= KEY_5:
			_vue(k - KEY_0)


func _capture(chemin: String) -> void:
	_tourne = false
	for _i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(chemin)
	print("CAPTURE OK ", chemin)
	get_tree().quit()
