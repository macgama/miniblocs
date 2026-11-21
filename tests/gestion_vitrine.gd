extends SceneTree
## Captures du mode gestion « tycoon » (écran isométrique d'un hôtel).
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/gestion_vitrine.gd -- --out DOSSIER [--niveau 1|3|5] [--piece spa] [--zoom 30]

var out := "user://captures-gestion"
var niveau := 3
var piece := ""
var zoom := 0.0

const VENDREDI := 1_784_282_400.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		match a[i]:
			"--out": out = a[i + 1]
			"--niveau": niveau = int(a[i + 1])
			"--piece": piece = a[i + 1]
			"--zoom": zoom = float(a[i + 1])
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Langue.activer("fr")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 600.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	Langue.activer("fr")
	var tour: Tourisme = scene.tourisme
	var gest: Gestion = scene.gestion
	var vue: GestionVue = scene.gestion_vue
	var pop: Population = scene.population
	for n in [transport.traffic, tour, pop, scene.production]:
		n.set_process(false)
	bs.unlimited_money = false
	bs.money = 50_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0))
	var sn := bs.road_snap("hotel_3", Vector2i(0, -14))
	var hotel := bs.place("hotel_3", sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	bs.buildings[hotel]["chantier"] = false
	tour.ignore_staff = true
	tour._sync()
	tour.heb[hotel].nom = "Hôtel Bellevue"
	tour.heb[hotel].compte = 180_000.0
	tour.heb[hotel].clients = [[50, 3, 3.5], [40, 2, 3.5]]
	# Personnel : quelques habitants embauchés à leur poste.
	var homes: Array[int] = []
	for i in 6:
		var c := Vector2i(-300 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for b in homes:
		pop.spawn_household(b, "famille")
	var mets := ["receptionniste", "agent_etage", "agent_etage", "cuisinier", "serveur", "serveur", "cadre", "agent_proprete", "maitre_nageur", "maitre_nageur"]
	var k := 0
	pop.by_job[hotel] = []
	for pid in pop.persons:
		if k >= mets.size():
			break
		pop.persons[pid].met = mets[k]
		pop.by_job[hotel].append(int(pid))
		k += 1
	gest.etat(hotel)
	var plan := {1: [], 3: ["chambres", "chambres", "bar", "bar", "piscine", "piscine", "reception", "reception"],
		5: ["chambres", "chambres", "chambres", "chambres", "bar", "bar", "bar", "bar", "bar", "piscine", "piscine", "piscine", "piscine", "piscine",
			"spa", "spa", "spa", "restaurant", "restaurant", "restaurant", "restaurant", "reception", "reception", "reception", "reception", "parking", "parking", "parking"]}
	bs.unlimited_money = true
	for pid in plan.get(niveau, []):
		gest.ameliorer(hotel, String(pid))
	bs.unlimited_money = false
	scene.ouvrir_gestion(hotel)
	if zoom > 0.0:
		vue._zoom = zoom
		vue._placer_camera()
	EchelleTemps.force = 1.0
	for i in 260:
		vue.simuler(0.1)
	vue.choisir(piece)
	for i in 30:
		await process_frame
	vue._t_demande = 0.0
	for i in 40:
		vue.simuler(0.1)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var f := out.path_join("gestion-hotel-niveau%d%s.png" % [niveau, ("-" + piece) if piece != "" else ""])
	img.save_png(f)
	print("capture : ", ProjectSettings.globalize_path(f))
	quit(0)
