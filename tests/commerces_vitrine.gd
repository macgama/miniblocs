extends SceneTree
## Vitrine de l'habillage des petits commerces (DevanturesHabillage) : une rue
## d'échoppes de styles du monde (Japon, mégapole asiatique, Paris, Médina,
## Amérique latine, colonial américain, Méditerranée…), vue en diorama de jour
## et de nuit, à hauteur d'homme, et en 1850 / 1925 / 1965 / 2025.
## --sans : mêmes vues sans l'habillage (captures « avant »).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/commerces_vitrine.gd -- --dossier /chemin/captures [--sans]

var dir := "."
var scene: Node
var bs: BuildingSystem
var amb: DayNight
var rig: Node3D
var dev: Devantures
var prod: Production
var y := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(nom: String) -> void:
	for i in 4:
		await process_frame
	dev.refresh()
	for i in 8:
		await process_frame
	var path := dir.path_join(nom)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _heure(iso: String) -> void:
	amb.unix_time = Time.get_unix_time_from_datetime_string(iso)
	amb.set_speed(0)
	for i in 3:
		await process_frame


## Caméra : `pos` point regardé, `yaw` en degrés, recul et inclinaison.
func _camera(pos: Vector3, yaw: float, distance: float, pitch: float) -> void:
	scene.population.follow(-1)
	rig.position = pos
	rig.rotation.y = deg_to_rad(yaw)
	rig._distance = distance
	rig._target_distance = distance
	rig.pitch_degrees = pitch
	rig._target_pitch = pitch
	if rig.has_method("_apply_camera"):
		rig.call("_apply_camera")
	for i in 6:
		await process_frame


func _remplir(bid: int, plein: float) -> void:
	if not prod.sites.has(bid):
		return
	for g in DevanturesTypes.profil(String(bs.buildings[bid].t)).get("vend", []):
		prod.sites[bid].st[g] = prod.cap_of(bid, String(g)) * plein


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var prefixe := ""
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dir = args[i + 1]
		if args[i] == "--sans":
			Devantures.habillage_actif = false
			prefixe = "avant-"
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	ReglagesPartie.actuel.deblocage = "tout"
	BatimentsVie.chantiers = false
	scene = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	bs = scene.get_node("Batiments")
	amb = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	await _heure("2026-04-12T10:30:00")
	bs.unlimited_money = true
	y = world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -160), Vector3(0, y, 160))
	dev = scene.devantures
	prod = scene.production
	rig = scene.rig
	var liste := ["japonais__restaurant", "asie_dense__restaurant", "haussmann__boutique", "boulangerie", "maghreb__boutique",
		"latino__boutique", "colonial__boutique", "mediterraneen__boutique", "bistrot_parisien", "asie_se__restaurant"]
	var ids := {}
	var z := -60
	for id in liste:
		var t := BuildingCatalog.get_type(id)
		if t.is_empty():
			print("type absent : ", id)
			continue
		var bid := bs.place(id, Vector2i(int(t.d) / 2 + 7, z + int(t.w) / 2), 3)
		if bid > 0:
			ids[id] = bid
		z += int(t.w) + 1
	var pop: Population = scene.population
	var maisons := []
	for j in 10:
		var bm := bs.place("maison", Vector2i(-13, 60 + j * 12), 1)
		if bm > 0:
			maisons.append(bm)
	pop._sync_buildings()
	for bm in maisons:
		pop.spawn_household(int(bm))
	var libres := []
	for pid in pop.persons:
		var pp: Dictionary = pop.persons[pid]
		if String(pp.get("role", "")) != "enfant" and int(pp.get("job", -1)) < 0 and pop.age_of(pp) >= 18.0:
			libres.append(pp)
	for k in ids:
		var bid := int(ids[k])
		var requis := Effectif.requis_de(String(bs.buildings[bid].t))
		for n in 2:
			if libres.is_empty():
				break
			var met := String(requis[n % requis.size()]) if not requis.is_empty() else ""
			pop._join_job(libres.pop_back(), bid, met)
	pop.effectif.actualiser(true)
	amb.weather.mode = Meteo.Mode.SOLEIL
	prod._sync()
	for k in ids:
		_remplir(int(ids[k]), 1.0)
	print("Bâtiments posés : ", ids)
	var r := ReglagesPartie.actuel
	r.annee_depart = 2025
	r.histoire_debut = amb.unix_time
	r.histoire_saut = 0
	var vues := [["japonais__restaurant", "1-japon-ramen"], ["haussmann__boutique", "2-paris-boutique"],
		["maghreb__boutique", "3-medina"], ["latino__boutique", "4-amerique-latine"], ["colonial__boutique", "5-amerique-nord"]]
	for vu in vues:
		if not ids.has(vu[0]):
			continue
		var pb := bs.node_of(int(ids[vu[0]])).global_position
		await _camera(Vector3(pb.x - 3.0, y + 2.0, pb.z), -125.0, 24.0, 32.0)
		await _shot(prefixe + String(vu[1]) + "-jour.png")
		for m in dev.montres:
			if int(m.bid) == int(ids[vu[0]]):
				print("  ", vu[0], " · ", m.get("habillage", {}))
	# La rue entière, de jour puis le soir.
	var p0 := bs.node_of(int(ids.values()[2])).global_position
	await _camera(Vector3(p0.x - 4.0, y, p0.z + 4.0), -120.0, 46.0, 34.0)
	await _shot(prefixe + "6-rue-jour.png")
	await _heure("2026-04-12T19:15:00")
	for vu in vues.slice(0, 2):
		if not ids.has(vu[0]):
			continue
		var pb := bs.node_of(int(ids[vu[0]])).global_position
		await _camera(Vector3(pb.x - 3.0, y + 2.0, pb.z), -125.0, 24.0, 32.0)
		await _shot(prefixe + String(vu[1]) + "-nuit.png")
	await _camera(Vector3(p0.x - 4.0, y, p0.z + 4.0), -120.0, 46.0, 34.0)
	await _shot(prefixe + "7-rue-nuit.png")
	# À hauteur d'homme devant l'échoppe japonaise, le soir.
	if ids.has("japonais__restaurant"):
		var pj := bs.node_of(int(ids.japonais__restaurant)).global_position
		var fj := pj.x - float(BuildingCatalog.get_type("japonais__restaurant").d) * 0.5
		await _camera(Vector3(fj - 2.5, y + 1.5, pj.z - 3.0), -100.0, 9.0, 8.0)
		await _shot(prefixe + "8-hauteur-homme-soir.png")
	# Époques.
	await _heure("2026-04-12T11:00:00")
	for an in [1850, 1925, 1965]:
		r.annee_depart = an
		r.histoire_debut = amb.unix_time
		await _camera(Vector3(p0.x - 4.0, y, p0.z + 4.0), -120.0, 46.0, 34.0)
		await _shot(prefixe + "9-epoque-%d.png" % an)
	quit(0)
