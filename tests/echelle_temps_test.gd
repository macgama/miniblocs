extends SceneTree
## Test « tout bouge à la vitesse du temps » (EchelleTemps) : facteur par vitesse
## (pause = 0), vue au sol à vitesse réelle, véhicules arrêtés en pause et plus
## rapides à 100 min/s, animations des chantiers, des métiers et des manèges
## arrêtées en pause, croissance des zones suspendue.
## Fonctionne sans réseau (relief synthétique).
## Usage : godot --headless --path . --script res://tests/echelle_temps_test.gd

var ok := true
var world: TerrainWorld


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
	a.fill(30.0)
	return a


func _pos(v: Dictionary) -> Vector3:
	return (v.body as Node3D).global_position if v.has("body") else Vector3.ZERO


## Distance parcourue par une voiture en n images de dt secondes réelles,
## avec la vitesse du temps i.
func _distance(tr: TransportSystem, amb: DayNight, i: int, n: int, dt: float) -> float:
	amb.set_speed(i)
	var v: Dictionary = tr.traffic.vehicles[0]
	var d := 0.0
	var p := _pos(v)
	for k in n:
		tr.traffic._spawn_timer = 1000.0
		tr.traffic._process(dt)
		if tr.traffic.vehicles.is_empty():
			break
		v = tr.traffic.vehicles[0]
		var q := _pos(v)
		d += Vector2(q.x - p.x, q.z - p.z).length()
		p = q
	return d


func _run() -> void:
	print("Facteur des mouvements :")
	EchelleTemps.horloge = null
	_check(is_equal_approx(EchelleTemps.facteur(), 1.0), "sans horloge (vitrines) : ×1")
	_check(EchelleTemps.FACTEURS.size() == DayNight.SPEEDS.size(), "un facteur pour chacune des %d vitesses" % DayNight.SPEEDS.size())
	_check(EchelleTemps.facteur_vitesse(0) == 0.0, "pause : ×0")
	_check(is_equal_approx(EchelleTemps.facteur_vitesse(DayNight.DEFAULT_SPEED), 1.0), "vitesse par défaut (1 jour/min) : ×1, comme avant")
	var croissant := true
	for i in range(1, EchelleTemps.FACTEURS.size()):
		croissant = croissant and EchelleTemps.facteur_vitesse(i) > EchelleTemps.facteur_vitesse(i - 1)
	_check(croissant, "plus le temps va vite, plus ça bouge vite (%s)" % str(EchelleTemps.FACTEURS))

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	var tr: TransportSystem = scene.get_node("Transport")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.set_origin(48.8584, 2.2945)
	for i in 30:
		await process_frame
	_check(EchelleTemps.horloge == amb, "l'horloge du jeu est branchée")

	amb.set_speed(0)
	_check(EchelleTemps.facteur() == 0.0 and EchelleTemps.en_pause(), "T (pause) : tout est arrêté")
	amb.set_speed(DayNight.SPEEDS.size() - 1)
	_check(is_equal_approx(EchelleTemps.facteur(), 2.0), "100 min/s : ×2")
	amb.set_speed(1)
	_check(is_equal_approx(EchelleTemps.facteur(), 0.25), "temps réel : ×0,25")
	EchelleTemps.vue_sol = true
	_check(is_equal_approx(EchelleTemps.facteur(), 1.0), "vue au sol : vitesse réelle, comme le personnage")
	amb.set_speed(0)
	_check(EchelleTemps.facteur() == 0.0, "vue au sol en pause : arrêt aussi")
	EchelleTemps.vue_sol = false

	print("Véhicules :")
	var r := tr.build_segment("route", Vector3(-300, 0, 0), Vector3(300, 0, 0))
	_check(r.ok, "une longue route droite")
	tr.traffic.demand = Callable()
	tr.traffic.clear()
	tr.traffic.rng.seed = 7
	_check(tr.traffic.spawn(TransportTypes.Mode.ROAD), "une voiture")
	# Mise en route à la vitesse par défaut (la voiture atteint sa vitesse de croisière).
	_distance(tr, amb, DayNight.DEFAULT_SPEED, 30, 0.05)
	var d0 := _distance(tr, amb, 0, 20, 0.05)
	_check(d0 < 0.001, "en pause, la voiture ne bouge plus (%.3f m)" % d0)
	var d_lent := _distance(tr, amb, 2, 10, 0.05)
	var d_def := _distance(tr, amb, DayNight.DEFAULT_SPEED, 10, 0.05)
	var d_vite := _distance(tr, amb, DayNight.SPEEDS.size() - 1, 10, 0.05)
	_check(d_lent > 0.0 and d_lent < d_def, "1 min/s : plus lente qu'au défaut (%.1f m contre %.1f m)" % [d_lent, d_def])
	_check(d_vite > d_def * 1.3, "100 min/s : plus rapide (%.1f m contre %.1f m)" % [d_vite, d_def])

	print("Chantiers, métiers, manèges, zones :")
	var vie: BatimentsVie = null
	for n in scene.get_children():
		if n is BatimentsVie:
			vie = n
	var metiers: MetiersVivants = null
	for n in scene.find_children("*", "MetiersVivants", true, false):
		metiers = n
	var zones: ZoneSystem = scene.get_node("Zones")
	amb.set_speed(0)
	if vie != null:
		var c0 := vie._clock
		vie._process(1.0)
		_check(is_equal_approx(vie._clock, c0), "en pause, ouvriers et engins des chantiers figés")
		amb.set_speed(DayNight.DEFAULT_SPEED)
		vie._process(1.0)
		_check(is_equal_approx(vie._clock, c0 + 1.0), "au défaut, ils reprennent (×1)")
		amb.set_speed(0)
	else:
		_check(false, "BatimentsVie trouvé dans la scène")
	if metiers != null:
		var t0 := metiers._t
		metiers._process(1.0)
		_check(is_equal_approx(metiers._t, t0), "en pause, les gestes des métiers sont figés")
	var tz := zones._timer
	zones.growth = true
	zones._process(5.0)
	_check(is_equal_approx(zones._timer, tz), "en pause, les zones ne se remplissent pas")
	amb.set_speed(DayNight.SPEEDS.size() - 1)
	var attr := AttractionsPerso.new()
	_check(is_equal_approx(attr._vitesse_jeu(), 2.0), "manèges : suivent la vitesse du temps (×2 à 100 min/s)")
	amb.set_speed(0)
	_check(attr._vitesse_jeu() == 0.0, "manèges arrêtés en pause")
	attr.free()

	EchelleTemps.horloge = null
	print("ÉCHELLE DU TEMPS TEST ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
