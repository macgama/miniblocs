extends SceneTree
## Captures de l'éditeur du parc : grand-huit, bûches, toboggan et piscine,
## décors à thème, allées et files, panneau de tracé et onglets.
## Usage : xvfb-run godot --path . --script res://tests/parc_editeur_vitrine.gd -- --dossier captures/parc-editeur

const SAMEDI := 1_784_358_000.0


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String, frames := 30) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _vue(rig: Node3D, pos: Vector3, dist: float, pitch: float, yaw: float) -> void:
	rig.position = pos
	rig._target_distance = dist
	rig.set_pitch(pitch, true)
	rig.rotation_degrees.y = yaw


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 800.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = SAMEDI + 4 * 3600.0
	if amb.weather != null:
		amb.weather.mode = Meteo.Mode.SOLEIL
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0))
	var parc: ParcLoisirs = scene.parc
	var atr: AttractionsPerso = scene.attractions
	var al: ParcAllees = scene.parc_allees
	parc.set_process(false)
	parc.ignore_staff = true
	scene.production.set_process(false)
	scene.dechets.set_process(false)
	var e := bs.place("entree_parc", Vector2i(0, -14), bs.best_rotation("entree_parc", Vector2i(0, -14)))
	var poses := [["acier", 0, Vector2i(-110, -150), 0], ["mine", 1, Vector2i(80, -230), 2], ["buches", 2, Vector2i(70, -60), 2],
		["riviere", 3, Vector2i(-150, -50), 1], ["toboggan", 4, Vector2i(-30, -60), 1]]
	var bids := {}
	for p in poses:
		atr.nouveau(String(p[0]), AttractionsPerso.modeles()[int(p[1])])
		atr.poser_gare(p[2], int(p[3]))
		if not atr.construire():
			push_warning("pas construit : %s (%s)" % [p[0], atr.conflits()])
			atr.annuler()
		for bid in bs.buildings:
			if AttractionsPerso.is_atr(String(bs.buildings[bid].t)) and not bids.values().has(int(bid)):
				bids[String(p[0])] = int(bid)
	for spec in [["piscine_vagues", 10, -105], ["pataugeoire", -20, -110], ["pizzeria_parc", 20, -40], ["creperie_parc", 32, -36],
		["barbe_a_papa", -16, -36], ["bar_smoothies", -26, -38], ["toilettes_parc", 44, -48], ["stand_ballons", 8, -30],
		["poste_secours", -36, -30], ["bateaux_tamponneurs", 120, -120], ["pedalos", -80, -100]]:
		if bs.place(String(spec[0]), Vector2i(int(spec[1]), int(spec[2])), 0) < 0:
			push_warning("pose impossible : %s" % spec[0])
	parc._sync()
	# Allées et file du grand-huit.
	var portail := parc.portail(e)
	var hub := Vector2(0, -75)
	al.ajoute_allee(Vector2(portail.x, portail.z), hub, "pave", 6.0)
	for b in bids.values():
		var d := parc.porte(int(b))
		al.ajoute_allee(hub, Vector2(d.x, d.z) + Vector2(parc.facade(int(b)).x, parc.facade(int(b)).z) * 8.0, "pave", 4.0)
	if bids.has("acier"):
		var d := parc.porte(int(bids.acier))
		var f := parc.facade(int(bids.acier))
		var s := f.cross(Vector3.UP)
		var p0 := Vector2(d.x, d.z)
		var p1 := p0 + Vector2(f.x, f.z) * 2.0 + Vector2(s.x, s.z) * 9.0
		var p2 := p1 + Vector2(f.x, f.z) * 2.0
		var p3 := p2 - Vector2(s.x, s.z) * 18.0
		var p4 := p3 + Vector2(f.x, f.z) * 2.0
		var p5 := p4 + Vector2(s.x, s.z) * 18.0
		al.ajoute_file(p0, p1)
		al.ajoute_file(p1, p2)
		al.ajoute_file(p2, p3)
		al.ajoute_file(p3, p4)
		al.ajoute_file(p4, p5)
	# Décors à thème.
	var dec: DecorSystem = scene.decors
	var x0 := -60.0
	for id in ["pt_palmier", "pt_tiki", "pt_tete_temple", "pt_bambous", "pt_colonne_ruine", "pt_tonneau", "pt_canon", "pt_mat_pirate",
		"pt_coffre_tresor", "pt_rocher_crane", "pt_fusee", "pt_soucoupe", "pt_robot", "pt_planete", "pt_cristal", "pt_radar",
		"pt_tour_chateau", "pt_champignon", "pt_citrouille_carrosse", "pt_puits", "pt_cactus", "pt_chariot", "pt_totem", "pt_facade_saloon",
		"pt_arbre_mort", "pt_citrouille_lanterne", "pt_grille_manoir", "pt_mascotte", "pt_lampadaire_guirlande", "pt_arche_fleurs"]:
		dec.pose(id, x0, -20.0 - (fposmod(x0, 20.0)), 0.3, 1.0, true)
		x0 += 7.0
	parc.clock = SAMEDI
	parc.last_day = int(parc._now(parc.clock).day)
	for i in 5 * 60:
		parc.clock += ParcLoisirs.STEP
		parc.step(ParcLoisirs.STEP)
	amb.unix_time = parc.clock
	parc.visuels._rebuild_t = 0.0
	var rig: Node3D = scene.get_node("CameraRig")
	_vue(rig, Vector3(-20, y, -120), 300.0, 40.0, 0.0)
	await _shot(dir.path_join("editeur-ensemble.png"), 90)
	if bids.has("acier"):
		var c := parc._center(int(bids.acier))
		_vue(rig, c + Vector3(40, 0, -30), 110.0, 22.0, 30.0)
		await _shot(dir.path_join("editeur-grand-huit.png"), 60)
	if bids.has("buches"):
		_vue(rig, parc._center(int(bids.buches)) + Vector3(-20, 0, -20), 80.0, 24.0, -40.0)
		await _shot(dir.path_join("editeur-buches.png"), 40)
	_vue(rig, Vector3(-10, y, -95), 70.0, 26.0, 160.0)
	await _shot(dir.path_join("editeur-toboggan-piscine.png"), 40)
	_vue(rig, Vector3(40, y, -25), 70.0, 20.0, 180.0)
	await _shot(dir.path_join("editeur-decors-theme.png"), 40)
	if bids.has("acier"):
		_vue(rig, parc.porte(int(bids.acier)), 40.0, 40.0, 20.0)
		await _shot(dir.path_join("editeur-file-attente.png"), 40)
	# Panneau : un tracé en cours.
	var pan: ParcEditeurPanel = scene.parc_editeur_panel
	pan.set_open(true)
	atr.nouveau("acier")
	atr.poser_gare(Vector2i(160, -180), 0)
	for pid in ["droit", "montee", "droit_long", "droit_long", "fin_montee", "descente", "raidir_bas", "adoucir_bas", "fin_descente", "looping", "virage_d_large"]:
		atr.chaine = pid in ["montee", "droit_long", "fin_montee"]
		atr.ajoute(pid)
	atr.chaine = false
	atr.apercu("vrille_d")
	pan.refresh()
	_vue(rig, Vector3(190, y, -190), 120.0, 35.0, 10.0)
	await _shot(dir.path_join("editeur-panneau-trace.png"), 60)
	atr.annuler()
	pan.show_onglet("rail")
	await _shot(dir.path_join("editeur-onglet-grands-huit.png"), 120)
	pan.show_onglet("eau")
	await _shot(dir.path_join("editeur-onglet-aquatiques.png"), 120)
	pan.theme_decor = "theme_espace"
	pan.show_onglet("decors")
	await _shot(dir.path_join("editeur-onglet-decors.png"), 120)
	pan.show_onglet("boutique")
	await _shot(dir.path_join("editeur-onglet-boutiques.png"), 120)
	quit()
