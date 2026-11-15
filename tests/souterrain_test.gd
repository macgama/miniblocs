extends SceneTree
## Test de la vue sous terre (scripts/souterrain/vue_souterraine.gd) :
## une rue avec des maisons et des immeubles, un collecteur d'égout, une ligne de
## métro et sa station, un bunker de l'Atelier à −10 ; on descend niveau par
## niveau avec Page bas et on vérifie ce qui se voit.
## Usage : godot --headless --path . --script res://tests/souterrain_test.gd
## Captures (avec affichage) : ajouter -- --dossier /chemin/captures

var ok := true
var dossier := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _place(bs: BuildingSystem, id: String, x: int, side := -1, road_z := 0) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, road_z + side * (d / 2 + 6))
	return bs.place(id, c, bs.best_rotation(id, c))


func _key(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	root.push_input(k)
	var r := InputEventKey.new()
	r.keycode = code
	r.pressed = false
	root.push_input(r)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(nom: String) -> void:
	if dossier == "":
		return
	await _frames(12)
	var path := dossier.path_join(nom)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dossier = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel.construction_instantanee = true

	print("Règles :")
	_check(VueSouterraine.sous_sols_de("maison") == 1 and not VueSouterraine.est_parking("maison"), "une maison a une cave")
	_check(VueSouterraine.sous_sols_de("immeuble") == 1 and VueSouterraine.est_parking("immeuble"), "un immeuble a un niveau de parking")
	_check(VueSouterraine.sous_sols_de("tour_habitation") == 2, "une tour a deux niveaux de parking")
	_check(VueSouterraine.sous_sols_de("supermarche") == 2, "un supermarché a deux niveaux de parking")
	_check(VueSouterraine.sous_sols_de("usine") == 0, "pas de sous-sol sous une usine")
	_check(VueSouterraine.sous_sols_de("maison", {"sous_sols": 4}) == 4, "un bâtiment peut porter ses propres sous-sols")
	_check(VueSouterraine.visible_au(1, 0.8) and not VueSouterraine.visible_au(2, 2.6), "les réseaux de rue se voient au −1, plus au −2")
	_check(VueSouterraine.visible_au(5, 15.0) and not VueSouterraine.visible_au(6, 15.0), "le métro à 14 m se voit jusqu'au −5")
	_check(VueSouterraine.niveau_nom(2) == "Sous-sol −2  (3 à 6 m)", "nom du niveau : " + VueSouterraine.niveau_nom(2))
	_check(PlanEditor.MIN_LEVEL == -20, "l'Atelier descend à −20 (bunkers)")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	await _frames(150)
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T15:00:00")
	bs.unlimited_money = true
	var res: Reseaux = scene.reseaux
	var vs: VueSouterraine = scene.souterrain
	var cam: Camera3D = scene.get_node("CameraRig/Camera3D")
	var rig: Node3D = scene.get_node("CameraRig")
	_check(vs != null, "la vue sous terre est dans la scène")
	var y := world.cell_height(Vector2i(0, 0))

	print("Ville :")
	transport.build_segment("route", Vector3(-160, y, 0), Vector3(160, y, 0))
	transport.build_segment("route", Vector3(0, y, 0), Vector3(0, y, 140))
	var maisons := []
	for i in 5:
		maisons.append(_place(bs, "maison", -140 + i * 24, 1))
	var imm := _place(bs, "immeuble", 40, 1)
	_place(bs, "supermarche", 100, -1)
	bs.require_access = false
	var isole := bs.place("maison", Vector2i(-120, 120), 0)
	bs.require_access = true
	_place(bs, "forage_eau", -100, -1)
	_place(bs, "station_epuration_locale", 40, -1)
	_place(bs, "poste_national", -40, -1)
	var col := res.poser("collecteur", res.trace_sur_relief(Vector3(-160, y, -40), Vector3(160, y, -40)), false)
	var m := transport.build_segment("metro", Vector3(-150, y, 70), Vector3(150, y, 70))
	var st: Dictionary = transport.stations.place("station_metro", Vector3(60, y, 70))
	_check(m.ok and st.ok, "métro et station posés (%s / %s)" % [m.get("reason", "ok"), st.get("reason", "ok")])
	await _frames(30)
	res.recalculer_topologie()
	_check(col >= 0 and res.eau.est_raccorde(maisons[0]) and not res.eau.est_raccorde(isole), "maisons de la rue raccordées, maison isolée non")

	# Bunker de l'Atelier : 10 niveaux sous le sol.
	var pe: PlanEditor = scene.plans
	var pid := pe.new_plan(pe.ground_level(Vector2i(-65, 39)))
	_check(pe.add_room(pid, Rect2i(-70, 34, 10, 10), -10, 10), "bunker de 10 × 10 m sur 10 niveaux (−1 à −10)")
	_check(pe.levels_of(pid).has(-10), "le bunker descend à −10")
	await _frames(10)

	rig.global_position = Vector3(-10, y, 30)
	rig.rotation_degrees.y = -25.0
	rig.set("_target_distance", 210.0)
	rig.set_pitch(48.0, true)
	await _shot("souterrain-0-surface.png")

	print("Descente :")
	var cull := cam.cull_mask
	_key(KEY_PAGEDOWN)
	await _frames(3)
	_check(vs.actif and vs.niveau == 1, "Page bas sans bâtiment à étages : Sous-sol −1")
	_check(cam.cull_mask == VueSouterraine.COUCHE, "la surface s'efface (couche de la vue seule)")
	_check(int(vs.compte.rues) >= 2, "réseaux sous les deux rues (%d)" % int(vs.compte.rues))
	_check(int(vs.compte.troncons) >= 1, "collecteur d'égout visible")
	_check(int(vs.compte.branchements) >= 5, "branchements des bâtiments (%d)" % int(vs.compte.branchements))
	_check(int(vs.compte.tunnels) >= 1 and int(vs.compte.stations) == 1, "métro et sa station")
	_check(int(vs.compte.sous_sols) >= 7, "caves et parkings (%d)" % int(vs.compte.sous_sols))
	_check(int(vs.compte.plans) == 1, "le bunker de l'Atelier se voit")
	await _shot("souterrain-1-reseaux.png")
	_key(KEY_PAGEDOWN)
	await _frames(3)
	_check(vs.niveau == 2 and int(vs.compte.rues) == 0, "au −2, plus de tuyaux de rue")
	_check(int(vs.compte.troncons) >= 1, "le collecteur (4 m) se voit encore au −2")
	_check(int(vs.compte.sous_sols) == 1, "seul le supermarché a un 2e sous-sol (%d)" % int(vs.compte.sous_sols))
	await _shot("souterrain-2-parkings.png")
	vs.set_niveau(5)
	await _frames(3)
	_check(int(vs.compte.tunnels) >= 1 and int(vs.compte.troncons) == 0, "au −5 : le métro, plus le collecteur")
	await _shot("souterrain-5-metro.png")
	vs.set_niveau(6)
	await _frames(3)
	_check(int(vs.compte.tunnels) == 0 and int(vs.compte.plans) == 1, "au −6 : seul le bunker reste")
	await _shot("souterrain-6-bunker.png")
	for i in 30:
		_key(KEY_PAGEDOWN)
	await _frames(3)
	_check(vs.niveau == VueSouterraine.NIVEAU_MAX, "on ne descend pas sous −20")
	_key(KEY_PAGEUP)
	await _frames(2)
	_check(vs.niveau == VueSouterraine.NIVEAU_MAX - 1, "Page haut remonte d'un niveau")
	_key(KEY_HOME)
	await _frames(2)
	_check(not vs.actif and cam.cull_mask == cull, "Origine : retour à la surface")
	_check(scene.pause_menu == null, "pas de menu pause ouvert")
	vs.set_niveau(1)
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(not vs.actif and scene.pause_menu == null, "Échap remonte sans ouvrir le menu pause")
	vs.set_niveau(3)
	_key(KEY_PAGEUP)
	_key(KEY_PAGEUP)
	_key(KEY_PAGEUP)
	await _frames(2)
	_check(not vs.actif, "Page haut depuis le −1 : retour à la surface")
	_check(pe.levels_of(pid).size() == 10, "sous-sols de l'Atelier intacts")
	var marques := 0
	for e in pe._nodes[pid]:
		var nd: Node = pe._nodes[pid][e]
		for c in nd.find_children("*", "VisualInstance3D", true, false):
			if (c as VisualInstance3D).layers & VueSouterraine.COUCHE:
				marques += 1
	_check(marques == 0, "les étages de l'Atelier retrouvent leur couche en sortant")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
