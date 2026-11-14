extends SceneTree
## Captures du zoo : vue d'ensemble, savane, fauves derrière la douve,
## manchots, singes, panneau (onglets Zoo, Enclos, Animaux), tracé d'un enclos.
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/zoo_vitrine.gd -- --dossier captures/zoo

const SAMEDI := 1_784_358_000.0

var world: TerrainWorld
var zoo: ZooSysteme
var outils: ZooOutils
var y := 40.0


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


func _rect(x0: float, z0: float, x1: float, z1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])


func _peint(outil: ZooOutils.Outil, sol: String, pts: Array, r := 6) -> void:
	outils.outil = outil
	outils.sol = sol
	outils.rayon = r
	for p in pts:
		world._stroke_level = NAN
		outils._peindre(Vector3(float(p[0]), y, float(p[1])), false)
	outils.outil = ZooOutils.Outil.AUCUN


func _remplir(sol: String, x0: int, z0: int, x1: int, z1: int, pas := 8) -> void:
	var pts: Array = []
	for x in range(x0, x1 + 1, pas):
		for z in range(z0, z1 + 1, pas):
			pts.append([x, z])
	_peint(ZooOutils.Outil.SOL, sol, pts, 5)


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
	world = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = SAMEDI + 4.5 * 3600.0
	if amb.weather != null:
		amb.weather.mode = Meteo.Mode.SOLEIL
	bs.unlimited_money = true
	y = world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-300, y, 0), Vector3(300, y, 0))
	zoo = scene.zoo
	outils = scene.zoo_outils
	zoo.set_process(false)
	zoo.ignore_staff = true
	scene.production.set_process(false)
	scene.dechets.set_process(false)
	var c0 := Vector2i(0, -14)
	var e := bs.place("entree_zoo", c0, bs.best_rotation("entree_zoo", c0))
	for spec in [["poste_soigneurs_zoo", -60, -36], ["cuisine_zoo", -80, -36], ["clinique_zoo", 70, -36], ["restaurant_zoo", 34, -38],
		["glacier_zoo", -22, -36], ["toilettes_zoo", 52, -36], ["boutique_zoo", -40, -36], ["belvedere_zoo", 0, -120],
		["kiosque_pedago_zoo", 18, -122], ["atelier_zoo", -100, -38], ["pique_nique_zoo", -20, -122]]:
		if bs.place(String(spec[0]), Vector2i(int(spec[1]), int(spec[2])), 0) < 0:
			push_warning("pose impossible : %s" % spec[0])
	zoo._sync()
	zoo.set_nom(e, "Zoo des Grands Espaces")

	# Savane : herbe, savane sèche, sable, un point d'eau.
	var sav := zoo.ajouter_enclos(PackedVector2Array([Vector2(-110, -60), Vector2(-10, -60), Vector2(-10, -110), Vector2(-40, -112),
		Vector2(-110, -105)]), "grillage")
	zoo.renommer_enclos(sav, "Savane africaine")
	_remplir("broussailles", -104, -100, -16, -66, 10)
	_remplir("sable", -60, -100, -45, -92, 6)
	_peint(ZooOutils.Outil.EAU, "", [[-80, -85], [-74, -88]], 5)
	bs.place("abri_savane_zoo", Vector2i(-28, -98), 0)
	zoo._sync()
	for esp in [["zebre", 6], ["girafe", 3], ["autruche", 3]]:
		for i in int(esp[1]):
			zoo.acheter(String(esp[0]), sav)
	scene.decors.pose("mangeoire_haute", -50.0, -75.0)
	scene.decors.pose("ratelier_foin", -30.0, -80.0)
	scene.decors.pose("tronc_escalade", -90.0, -70.0)

	# Lions derrière une douve (vue parfaite).
	var lions := zoo.ajouter_enclos(_rect(10, -60, 60, -100), "douve")
	zoo.renommer_enclos(lions, "Plaine des lions")
	_remplir("broussailles", 14, -96, 56, -64, 10)
	_remplir("roche", 40, -96, 56, -84, 5)
	bs.place("grotte_zoo", Vector2i(48, -90), 0)
	zoo._sync()
	for i in 4:
		zoo.acheter("lion", lions)
	scene.decors.pose("rocher_chauffant", 28.0, -76.0)
	scene.decors.pose("tronc_escalade", 20.0, -90.0)

	# Manchots : rochers et eau, paroi vitrée.
	var manch := zoo.ajouter_enclos(_rect(70, -60, 100, -85), "vitre")
	zoo.renommer_enclos(manch, "Côte des manchots")
	_remplir("roche", 72, -84, 98, -62, 5)
	_peint(ZooOutils.Outil.EAU, "", [[84, -75], [90, -72], [80, -78]], 5)
	bs.place("abri_polaire_zoo", Vector2i(90, -80), 1)
	zoo._sync()
	for i in 14:
		zoo.acheter("manchot", manch)

	# Grands singes : sous-bois, plateforme, volière couverte.
	var singes := zoo.ajouter_enclos(_rect(70, -95, 110, -135), "voliere")
	zoo.renommer_enclos(singes, "Forêt des grands singes")
	_remplir("foret", 72, -133, 108, -97, 8)
	_peint(ZooOutils.Outil.ARBRES, "", [[80, -110], [100, -125]], 4)
	scene.decors.pose("plateforme_singes", 90.0, -115.0)
	for i in 5:
		zoo.acheter("chimpanze", singes)

	# Éléphants : boue, herbe, grand bassin.
	var elef := zoo.ajouter_enclos(_rect(-110, -125, -40, -175), "mur")
	zoo.renommer_enclos(elef, "Terre des éléphants")
	_remplir("marais", -105, -170, -80, -130, 8)
	_peint(ZooOutils.Outil.EAU, "", [[-60, -150], [-55, -158], [-65, -160]], 6)
	for i in 4:
		zoo.acheter("elephant", elef)
	zoo._tout_relire()

	# Une journée : de 9 h à 13 h 30.
	zoo.clock = SAMEDI
	zoo.last_day = int(zoo._now(zoo.clock).day)
	for i in 5:
		zoo.clock += ZooSysteme.STEP
		zoo.step()
	zoo.zoos[e].presents = 320.0
	# Les animaux se placent un peu.
	for i in 40:
		zoo.visuels._process(0.25)
		await process_frame

	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(-10, y, -95)
	rig._target_distance = 210.0
	rig.set_pitch(40.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("zoo-ensemble.png"), 90)
	rig.position = Vector3(-60, y, -85)
	rig._target_distance = 60.0
	rig.set_pitch(26.0, true)
	rig.rotation_degrees.y = 10.0
	await _shot(dir.path_join("zoo-savane.png"))
	rig.position = Vector3(35, y, -80)
	rig._target_distance = 45.0
	rig.set_pitch(28.0, true)
	rig.rotation_degrees.y = -10.0
	await _shot(dir.path_join("zoo-lions-douve.png"))
	rig.position = Vector3(88, y, -90)
	rig._target_distance = 55.0
	rig.set_pitch(32.0, true)
	rig.rotation_degrees.y = -30.0
	await _shot(dir.path_join("zoo-manchots-singes.png"))
	rig.position = Vector3(-75, y, -150)
	rig._target_distance = 70.0
	rig.set_pitch(34.0, true)
	rig.rotation_degrees.y = 20.0
	await _shot(dir.path_join("zoo-elephants.png"))
	# Panneau.
	var panel: ZooPanel = scene.zoo_panel
	rig.position = Vector3(-10, y, -95)
	rig._target_distance = 210.0
	rig.set_pitch(40.0, true)
	rig.rotation_degrees.y = 0.0
	panel.set_open(true)
	panel.show_view("zoo")
	await _shot(dir.path_join("zoo-panneau.png"))
	panel.enclos_vu = sav
	panel.show_view("enclos")
	await _shot(dir.path_join("zoo-panneau-enclos.png"))
	panel.show_view("animaux")
	await _shot(dir.path_join("zoo-panneau-animaux.png"), 90)
	# Tracé d'un enclos en cours.
	panel.show_view("enclos")
	outils.set_outil(ZooOutils.Outil.ENCLOS)
	outils.barriere = "palissade"
	for p in [Vector3(-130, y, -60), Vector3(-160, y, -60), Vector3(-170, y, -95)]:
		outils._appui = true
		outils._clic(p, false)
	outils._survol = Vector3(-140, y, -110)
	outils._survol_ok = true
	outils._dessine()
	panel.refresh()
	rig.position = Vector3(-140, y, -85)
	rig._target_distance = 90.0
	rig.set_pitch(45.0, true)
	await _shot(dir.path_join("zoo-trace-enclos.png"))
	quit()
