extends SceneTree
## Banc d'essai d'une ville habitée : images par seconde, temps de simulation,
## mémoire et nœuds avec 1 000 puis 5 000 habitants, à la vitesse par défaut
## (1 jour de jeu = 1 minute réelle).
##
## Usage :
##   godot --headless --path . --fixed-fps 60 --script res://tests/perf_ville.gd -- [--hab 1000,5000] [--detail]
## Avec rendu (draw calls, objets visibles) : retirer --headless.
##   --hab N[,M…]  tailles de ville (habitants) ; défaut 1000,5000
##   --images N    images mesurées par taille (défaut 600)
##   --detail      coût de chaque script : on coupe son _process un moment
##   --max-ms X    échoue (code 1) si l'image moyenne dépasse X ms (test chiffré)
## Imprime un tableau et « PERF VILLE OK ».

const BLOC := 120 # côté d'un pâté de maisons (m), routes comprises


class Mesure:
	var wall: Array[float] = []
	var process: Array[float] = []
	var physics: Array[float] = []


var _last_usec := 0
var _rapport: Array[String] = []
var _amb: DayNight


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


static func _stats(a: Array[float]) -> Dictionary:
	if a.is_empty():
		return {"moy": 0.0, "med": 0.0, "p95": 0.0, "pire": 0.0}
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	return {"moy": sum / s.size(), "med": s[s.size() / 2], "p95": s[mini(s.size() - 1, int(s.size() * 0.95))], "pire": s[-1]}


func _mesurer(n: int) -> Mesure:
	var m := Mesure.new()
	_last_usec = 0
	for i in n + 1:
		await process_frame
		var now := Time.get_ticks_usec()
		if _last_usec > 0:
			m.wall.append((now - _last_usec) / 1000.0)
			if (now - _last_usec) > 100000 and _amb != null and OS.get_cmdline_user_args().has("--saccades"):
				print("    saccade %.0f ms à %s" % [(now - _last_usec) / 1000.0, Time.get_datetime_string_from_unix_time(int(_amb.unix_time))])
			m.process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			m.physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_last_usec = now
	return m


func _arg(nom: String, defaut: String) -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find(nom)
	if i >= 0 and i + 1 < a.size():
		return a[i + 1]
	return defaut


## Grille de routes de n × n pâtés autour de l'origine.
func _routes(world: TerrainWorld, transport: TransportSystem, n: int) -> void:
	var span := BLOC * n / 2.0
	for k in n + 1:
		var v := -span + k * BLOC
		for seg in [[Vector3(v, 0, -span), Vector3(v, 0, span)], [Vector3(-span, 0, v), Vector3(span, 0, v)]]:
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			a.y = world.cell_height(Vector2i(int(a.x), int(a.z)))
			b.y = world.cell_height(Vector2i(int(b.x), int(b.z)))
			transport.build_segment("route", a, b)


func _logements(pop: Population) -> int:
	var n := 0
	for bid in pop.known:
		n += int(pop.known[bid].log)
	return n


## Agrandit la ville (zonage) jusqu'à pouvoir loger `habitants` personnes,
## puis fait emménager des foyers jusqu'à les atteindre.
func _remplir(scene: Node, habitants: int) -> void:
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var zs: ZoneSystem = scene.get_node("Zones")
	var pop: Population = scene.population
	var n := 2
	while true:
		pop._sync_buildings()
		# ~2,3 personnes par foyer ; on garde 15 % de marge.
		if _logements(pop) * 2.3 >= habitants * 1.15:
			break
		n += 2
		if n > 24:
			break
		zs.clear()
		_routes(world, transport, n)
		var span := BLOC * n / 2.0
		for k in n:
			for l in n:
				var kinds := ["R", "R", "R", "C", "I", "R"]
				zs.add_zone(kinds[(k * 7 + l * 3) % kinds.size()], Rect2i(int(-span + k * BLOC + 6), int(-span + l * BLOC + 6), BLOC - 12, BLOC - 12))
		for i in n * n * 40:
			zs.grow_step()
		pop._sync_buildings()
		print("  grille %d × %d : %d bâtiments, %d logements" % [n, n, scene.get_node("Batiments").buildings.size(), _logements(pop)])
	var homes := []
	for bid in pop.known:
		if int(pop.known[bid].log) > 0:
			homes.append(bid)
	homes.shuffle()
	var guard := 0
	while pop.persons.size() < habitants and guard < 100000:
		guard += 1
		var bid: int = homes[guard % homes.size()]
		pop.spawn_household(bid)
	pop._match_all()


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	var tailles: Array[int] = []
	for s in _arg("--hab", "1000,5000").split(","):
		tailles.append(int(s))
	var images := int(_arg("--images", "600"))
	var detail := OS.get_cmdline_user_args().has("--detail")
	var max_ms := float(_arg("--max-ms", "0"))
	var echec := false
	print("Banc d'essai ville habitée — Godot %s, %s, %d cœurs" % [Engine.get_version_info().string,
		DisplayServer.get_name(), OS.get_processor_count()])
	for habitants in tailles:
		var t0 := Time.get_ticks_usec()
		var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC)
		var scene: Node = load("res://scenes/terre.tscn").instantiate()
		var world: TerrainWorld = scene.get_node("Terrain")
		var bs: BuildingSystem = scene.get_node("Batiments")
		var zs: ZoneSystem = scene.get_node("Zones")
		var amb: DayNight = scene.get_node("Ambiance")
		var rig: Node3D = scene.get_node("CameraRig")
		root.add_child(scene)
		world.tiles.offline_generator = _flat_tile
		world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
		world.set_origin(48.8584, 2.2945)
		for i in 60:
			await process_frame
		if scene.get("evenements") != null:
			scene.evenements.forcer_auto = 0
			scene.evenements.forcer_catastrophes = 0
		bs.unlimited_money = true
		zs.growth = false
		var pop: Population = scene.population
		pop.arrivals = false
		amb.set_speed(0)
		_remplir(scene, habitants)
		var t_ville := (Time.get_ticks_usec() - t0) / 1000.0
		print("%d habitants voulus : %d habitants, %d foyers, %d bâtiments (ville prête en %.0f ms)" % [habitants,
			pop.persons.size(), pop.households.size(), bs.buildings.size(), t_ville])
		# Un mardi de mars à 7 h 30 : départs au travail.
		amb.unix_time = Time.get_unix_time_from_datetime_string("2026-03-10T06:30:00")
		amb.set_speed(DayNight.DEFAULT_SPEED)
		rig.position = Vector3.ZERO
		rig._distance = 350.0
		rig._target_distance = 350.0
		# Mise en route (bâtiments affichés, caches, premiers trajets).
		var t1 := Time.get_ticks_usec()
		for i in 120:
			await process_frame
		var t_chauffe := (Time.get_ticks_usec() - t1) / 1000.0
		var prof: Script = load("res://scripts/prof_banc.gd") if ResourceLoader.exists("res://scripts/prof_banc.gd") else null
		if prof != null:
			prof.reset()
		_amb = amb
		var m := await _mesurer(images)
		if prof != null:
			prof.rapport(images)
		var w := _stats(m.wall)
		var p := _stats(m.process)
		var ph := _stats(m.physics)
		var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var ligne := "%5d hab | image moy %6.2f ms (%5.1f i/s) méd %6.2f p95 %6.2f pire %7.2f | process moy %6.2f p95 %6.2f | physique %5.2f | mémoire %5.0f Mo (+%4.0f) | nœuds %6d | objets %7d | dessin %5d appels, %6d objets | chauffe %5.0f ms" % [
			pop.persons.size(), w.moy, 1000.0 / maxf(w.moy, 0.001), w.med, w.p95, w.pire, p.moy, p.p95, ph.moy, mem,
			(Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			t_chauffe]
		print(ligne)
		_rapport.append(ligne)
		if max_ms > 0.0 and w.moy > max_ms:
			push_error("ÉCHEC : image moyenne %.2f ms > %.2f ms avec %d habitants" % [w.moy, max_ms, pop.persons.size()])
			echec = true
		if detail:
			await _detail(scene, maxi(images / 3, 120), w.moy)
		scene.queue_free()
		for i in 5:
			await process_frame
	print("")
	for l in _rapport:
		print(l)
	if echec:
		quit(1)
		return
	print("PERF VILLE OK")
	quit(0)


## Coût de chaque script : on coupe le _process de tous ses nœuds le temps
## d'une mesure et on compare à la référence.
func _detail(scene: Node, n: int, _ref: float) -> void:
	var groupes := {}
	var pile: Array[Node] = [root]
	while not pile.is_empty():
		var nd: Node = pile.pop_back()
		for c in nd.get_children():
			pile.append(c)
		if not (nd.is_processing() or nd.is_physics_processing()):
			continue
		var sc: Script = nd.get_script()
		var cle: String = sc.resource_path.get_file() if sc != null and sc.resource_path != "" else nd.get_class()
		if not groupes.has(cle):
			groupes[cle] = []
		groupes[cle].append(nd)
	var r0 := _stats((await _mesurer(n)).wall)
	var res := []
	for cle in groupes:
		var nds: Array = groupes[cle]
		var etats := []
		for nd in nds:
			etats.append([nd.is_processing(), nd.is_physics_processing()])
			nd.set_process(false)
			nd.set_physics_process(false)
		var sans := _stats((await _mesurer(n)).wall)
		for i in nds.size():
			if is_instance_valid(nds[i]):
				nds[i].set_process(etats[i][0])
				nds[i].set_physics_process(etats[i][1])
		res.append([r0.moy - sans.moy, cle, nds.size(), r0.p95 - sans.p95, r0.pire - sans.pire])
		r0 = _stats((await _mesurer(n)).wall)
	res.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	print("  Coût par script (image moyenne %.2f ms) : gain moyen, gain p95, gain pire" % r0.moy)
	for r in res.slice(0, 25):
		print("    %7.2f ms  %7.2f  %8.2f  %s (%d nœuds)" % [r[0], r[3], r[4], r[1], r[2]])
