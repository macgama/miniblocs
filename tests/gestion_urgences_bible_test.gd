extends SceneTree
## Test : les bâtiments de secours de la bible (centre de secours, gendarmerie,
## hôtel de police, hôpital régional, clinique) envoient leurs véhicules
## comme la caserne, le commissariat et l'hôpital de base, et se gèrent avec
## leur tycoon (caserne, commissariat, hôpital) : tuile sur la fiche, budget
## payé par la ville, véhicules en plus dans la vraie flotte.
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/gestion_urgences_bible_test.gd

const CAS := {
	"caserne_pompiers": ["pompiers", "caserne"],
	"gendarmerie": ["police", "commissariat"],
	"commissariat": ["police", "commissariat"],
	"hopital_regional": ["hopital", "hopital"],
	"clinique": ["hopital", "hopital"],
}

var ok := true


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


func _run() -> void:
	print("Types :")
	for t in CAS:
		_check(Urgences.service_type(t) == CAS[t][0], "%s : secours %s" % [t, CAS[t][0]])
		_check(GestionTypes.genre_de(t) == CAS[t][1], "%s : tycoon %s" % [t, CAS[t][1]])
	for t in ["pompiers", "police", "hopital"]:
		_check(Urgences.service_type(t) == t, "%s inchangé" % t)
	_check(GestionTypes.titre_de("gendarmerie") == "Gérer la gendarmerie" and GestionTypes.titre_de("pompiers") == "Gérer la caserne", "titres : gendarmerie à part, caserne inchangée")
	_check(Urgences.service_type("ecole") == "" and Urgences.service_type("haussmann__restaurant") == "", "l'école et le restaurant ne sont pas des secours")
	await _ville()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _poser(bs: BuildingSystem, type_id: String, x: int, z: int) -> int:
	var sn := bs.road_snap(type_id, Vector2i(x, z - 40))
	var bid := bs.place(type_id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0))) if sn.has("center") else -1
	if bid <= 0:
		for r in 4:
			bid = bs.place(type_id, Vector2i(x, z - BuildingCatalog.footprint(type_id, r).y / 2 - 6), r)
			if bid > 0:
				break
	return bid


func _ville() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var gest: Gestion = scene.gestion
	var pop: Population = scene.population
	var urg: Urgences = scene.urgences
	for nd in [transport.traffic, scene.tourisme, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, scene.production]:
		nd.set_process(false)
	urg.set_process(false)
	urg.random_calls = false
	bs.unlimited_money = false
	bs.money = 600_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	ReglagesPartie.actuel.territoire = false
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-600, y, 0), Vector3(600, y, 0)).ok, "route")
	var x := -500
	for t in CAS:
		var bid := _poser(bs, String(t), x, 0)
		_check(bid > 0, "%s posé" % t)
		x += 120 + int(BuildingCatalog.footprint(String(t), 0).x)
		if bid <= 0:
			continue
		bs.buildings[bid]["chantier"] = false
		pop._sync_buildings()
		urg._sync_stations()
		_check(urg.stations.has(bid) and String(urg.stations[bid].t) == CAS[t][0] and (urg.stations[bid].units as Array).size() == 3, "%s : envoie ses 3 véhicules" % t)
		var hp: HabitantsPanel = scene.habitants_panel
		hp.set_open(true)
		hp.show_view("batiment", bid)
		await process_frame
		var tg: Button = hp._body.find_child("TuileGestion", true, false)
		_check(tg != null and tg.text.begins_with(GestionTypes.titre_de(String(t))), "%s : tuile « %s »" % [t, GestionTypes.titre_de(String(t))])
		hp.set_open(false)
		_check(not gest.etats.has(bid), "%s : jamais ouvert, pas d'état" % t)
		gest.etat(bid)
		gest.set_auto(bid, false)
		_check(gest.valide(bid) and gest.source(bid) == "ville", "%s : service public payé par la ville" % t)
		var argent0 := bs.money
		gest.nouveau_jour({"day": gest.jour + 1, "month": 6})
		_check(bs.money < argent0 and gest.compte(bid) > 0.0, "%s : budget versé (%s)" % [t, BuildingSystem.format_money(int(gest.compte(bid)))])
		var u0 := (urg.stations[bid].units as Array).size()
		for pid in GestionTypes.ordre(String(CAS[t][1])):
			gest.etat(bid).caisse = 5_000_000.0
			gest.ameliorer(bid, String(pid))
		urg._sync_stations()
		_check((urg.stations[bid].units as Array).size() > u0, "%s : véhicules en plus avec la gestion (%d → %d)" % [t, u0, (urg.stations[bid].units as Array).size()])
