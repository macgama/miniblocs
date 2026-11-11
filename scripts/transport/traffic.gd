class_name Traffic
extends Node3D
## Véhicules qui circulent sur les réseaux : voitures sur les routes, trains sur
## les rails, piétons et cyclistes sur les chemins, bateaux sur les voies d'eau.
##
## Étape 1 : chaque véhicule choisit une destination au hasard dans son réseau
## et y va par le plus court chemin (A*), en roulant à droite. Pas encore de
## collisions ni de lignes : ce sera l'étape suivante.

## Nombre de véhicules par mètre de réseau, et maximum.
const DENSITY := {
	TransportTypes.Mode.ROAD: [1.0 / 45.0, 160],
	TransportTypes.Mode.RAIL: [1.0 / 350.0, 16],
	TransportTypes.Mode.PATH: [1.0 / 18.0, 120],
	TransportTypes.Mode.WATER: [1.0 / 220.0, 20],
}
const CAR_COLORS: Array[Color] = [Color("d64933"), Color("f2c14e"), Color("2e86ab"), Color("f4f4f4"),
	Color("3c3c3c"), Color("6aa84f"), Color("8e7dbe"), Color("e07a5f")]
const WAGON_GAP := 15

var network: TransportNetwork
var enabled := true
var vehicles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

var _material: StandardMaterial3D
var _meshes: Dictionary = {}
var _spawn_timer := 0.0


func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.6
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rng.seed = 7


func setup(net: TransportNetwork) -> void:
	network = net


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		clear()


func clear() -> void:
	for v in vehicles:
		_free_vehicle(v)
	vehicles.clear()


func count_mode(mode: int) -> int:
	var c := 0
	for v in vehicles:
		if int(v.mode) == mode:
			c += 1
	return c


func _process(delta: float) -> void:
	if network == null or not enabled:
		return
	# Apparitions progressives jusqu'à la densité voulue.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.25
		for mode in DENSITY:
			var want := mini(int(DENSITY[mode][1]), floori(network.total_length(mode) * float(DENSITY[mode][0])))
			if mode == TransportTypes.Mode.RAIL or mode == TransportTypes.Mode.WATER:
				want = maxi(want, 1 if network.total_length(mode) > 60.0 else 0)
			var have := count_mode(mode)
			if have < want:
				spawn(mode)
			elif have > want:
				for i in vehicles.size():
					if int(vehicles[i].mode) == mode:
						_free_vehicle(vehicles[i])
						vehicles.remove_at(i)
						break
	step(delta)


## Fait avancer tous les véhicules de delta secondes.
func step(delta: float) -> void:
	var i := 0
	while i < vehicles.size():
		if _advance(vehicles[i], delta):
			i += 1
		else:
			_free_vehicle(vehicles[i])
			vehicles.remove_at(i)


## Crée un véhicule du mode donné sur un nœud au hasard. Renvoie vrai si réussi.
func spawn(mode: int) -> bool:
	var starts := network.nodes_of_mode(mode)
	if starts.size() < 2:
		return false
	var v := {}
	var found := false
	for _try in 6:
		var start: int = starts[rng.randi() % starts.size()]
		v = {"mode": mode, "node": start, "route": [] as Array[int], "leg": 0, "s": rng.randf() * 4.0,
			"trail": PackedVector3Array(), "wagons": [], "speed": 0.0, "lane": 0.0, "lane_idx": 0, "factor": 1.0, "own_speed": 0.0}
		if _new_route(v):
			found = true
			break
	if not found:
		return false
	_make_body(v)
	vehicles.append(v)
	_place(v)
	return true


func _new_route(v: Dictionary) -> bool:
	var start: int = v.node
	if not network.nodes.has(start):
		return false
	var comp := network.component(start)
	if comp.size() < 2:
		return false
	comp.erase(start)
	for _try in 4:
		var dest: int = comp[rng.randi() % comp.size()]
		var r := network.find_route(start, dest)
		if not r.is_empty():
			v.route = r
			v.leg = 0
			return true
	return false


## Avance un véhicule ; renvoie faux s'il doit disparaître.
func _advance(v: Dictionary, delta: float) -> bool:
	var route: Array[int] = v.route
	if v.leg >= route.size():
		return false
	var eid: int = route[v.leg]
	if not network.edges.has(eid):
		return false
	var e0: Dictionary = network.edges[eid]
	var spd: float = v.own_speed if float(v.own_speed) > 0.0 else TransportTypes.speed_of(e0.t) * float(v.factor)
	v.s = float(v.s) + spd * delta
	var guard := 0
	while float(v.s) >= float(network.edges[eid].len) and guard < 16:
		guard += 1
		v.s = float(v.s) - float(network.edges[eid].len)
		v.node = network.other_end(eid, v.node)
		v.leg = int(v.leg) + 1
		if v.leg >= route.size():
			if not _new_route(v):
				return false
			route = v.route
		eid = route[v.leg]
		if not network.edges.has(eid):
			return false
		var e: Dictionary = network.edges[eid]
		if e.a != v.node and e.b != v.node:
			return false
	_place(v)
	return true


func _place(v: Dictionary) -> void:
	var eid: int = v.route[v.leg]
	var e: Dictionary = network.edges[eid]
	var forward: bool = e.a == v.node
	var s: float = v.s if forward else float(e.len) - float(v.s)
	var p := network.point_at(eid, s)
	var t := network.tangent_at(eid, s)
	if not forward:
		t = -t
	var flat := Vector3(t.x, 0, t.z)
	if flat.length_squared() < 1e-6:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var right := Vector3(-flat.z, 0, flat.x)
	var surface := 0.08 if int(v.mode) != TransportTypes.Mode.RAIL else 0.47
	if int(v.mode) == TransportTypes.Mode.WATER:
		surface = 0.0
	var offsets := TransportTypes.lane_offsets(e.t, e.w)
	var lane: float = offsets[mini(int(v.lane_idx), offsets.size() - 1)] if not offsets.is_empty() else 0.0
	if int(v.mode) == TransportTypes.Mode.PATH:
		lane *= float(v.lane)
	var pos := p + right * lane + Vector3(0, surface, 0)
	var body: Node3D = v.body
	body.position = pos
	body.basis = Basis.looking_at(t, Vector3.UP)
	if not (v.wagons as Array).is_empty():
		var trail: PackedVector3Array = v.trail
		if trail.is_empty() or trail[trail.size() - 1].distance_to(pos) >= 1.0:
			trail.append(pos)
			if trail.size() > WAGON_GAP * 4:
				trail.remove_at(0)
			v.trail = trail
		for k in (v.wagons as Array).size():
			var w: Node3D = v.wagons[k]
			var idx := trail.size() - 1 - WAGON_GAP * (k + 1)
			w.visible = idx >= 0
			if idx >= 0:
				w.position = trail[idx]
				var ahead := trail[mini(idx + 2, trail.size() - 1)] - trail[idx]
				if ahead.length_squared() > 1e-4:
					w.basis = Basis.looking_at(ahead.normalized(), Vector3.UP)


# --- Modèles low-poly -----------------------------------------------------------

func _make_body(v: Dictionary) -> void:
	var mode: int = v.mode
	v.factor = rng.randf_range(0.85, 1.05)
	v.lane_idx = rng.randi() % 4
	v.lane = rng.randf_range(0.3, 1.4)
	var first_edge: Dictionary = network.edges[(v.route as Array[int])[0]]
	var cls: String = first_edge.t
	var key := ""
	var wagon := ""
	var wagons := 0
	match mode:
		TransportTypes.Mode.ROAD:
			key = "car_%d" % (rng.randi() % CAR_COLORS.size())
		TransportTypes.Mode.RAIL:
			match cls:
				"tram":
					key = "tram"
					wagon = "tram"
					wagons = 1
				"lgv":
					key = "tgv"
					wagon = "tgv_car"
					wagons = 3
				_:
					key = "loco"
					wagon = "wagon"
					wagons = 2
		TransportTypes.Mode.PATH:
			if cls != "trottoir" and rng.randf() < 0.45:
				key = "bike_%d" % (rng.randi() % 4)
				v.own_speed = rng.randf_range(4.0, 6.0)
			else:
				key = "walker_%d" % (rng.randi() % 5)
				v.own_speed = rng.randf_range(1.1, 1.6)
		TransportTypes.Mode.WATER:
			key = "boat"
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(key)
	mi.material_override = _material
	add_child(mi)
	v.body = mi
	for k in wagons:
		var w := MeshInstance3D.new()
		w.mesh = _mesh(wagon)
		w.material_override = _material
		w.visible = false
		add_child(w)
		(v.wagons as Array).append(w)


func _free_vehicle(v: Dictionary) -> void:
	if v.has("body"):
		(v.body as Node).queue_free()
	for w in v.get("wagons", []):
		(w as Node).queue_free()


func _mesh(key: String) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var k := TransportView.MeshKit.new()
	var R := Vector3.RIGHT
	if key.begins_with("car_"):
		var col := CAR_COLORS[int(key.substr(4))]
		k.oriented_box(Vector3(0, 0.55, 0), R, Vector3(1.8, 0.8, 4.2), col)
		k.oriented_box(Vector3(0, 1.2, 0.2), R, Vector3(1.6, 0.6, 2.2), col.lightened(0.15))
		k.oriented_box(Vector3(0, 1.2, -0.95), R, Vector3(1.5, 0.5, 0.1), Color("23313f"))
	elif key == "loco":
		k.oriented_box(Vector3(0, 0.6, 0), R, Vector3(2.8, 0.6, 14.0), Color("2c2f33"))
		k.oriented_box(Vector3(0, 2.2, 0), R, Vector3(2.9, 2.6, 13.6), Color("c0392b"))
		k.oriented_box(Vector3(0, 2.7, -6.85), R, Vector3(2.4, 1.0, 0.1), Color("23313f"))
		k.oriented_box(Vector3(0, 3.6, 0), R, Vector3(2.6, 0.2, 12.0), Color("e5e5e5"))
	elif key == "tram" :
		k.oriented_box(Vector3(0, 0.5, 0), R, Vector3(2.4, 0.5, 13.0), Color("2c2f33"))
		k.oriented_box(Vector3(0, 1.9, 0), R, Vector3(2.45, 2.4, 13.0), Color("e8e8e8"))
		k.oriented_box(Vector3(0, 2.2, 0), R, Vector3(2.5, 1.0, 11.5), Color("2a9d8f"))
	elif key == "tgv":
		k.oriented_box(Vector3(0, 0.6, 0), R, Vector3(2.8, 0.6, 14.0), Color("2c2f33"))
		k.oriented_box(Vector3(0, 2.1, 0.8), R, Vector3(2.9, 2.6, 12.4), Color("f4f4f4"))
		k.oriented_box(Vector3(0, 1.6, -6.2), R, Vector3(2.7, 1.6, 2.0), Color("f4f4f4"))
		k.oriented_box(Vector3(0, 2.4, 0.8), R, Vector3(2.95, 0.5, 12.4), Color("3d5a80"))
	elif key == "tgv_car":
		k.oriented_box(Vector3(0, 0.6, 0), R, Vector3(2.8, 0.6, 13.6), Color("2c2f33"))
		k.oriented_box(Vector3(0, 2.1, 0), R, Vector3(2.9, 2.6, 13.2), Color("f4f4f4"))
		k.oriented_box(Vector3(0, 2.4, 0), R, Vector3(2.95, 0.5, 12.0), Color("3d5a80"))
	elif key == "wagon":
		k.oriented_box(Vector3(0, 0.6, 0), R, Vector3(2.8, 0.6, 13.6), Color("2c2f33"))
		k.oriented_box(Vector3(0, 2.2, 0), R, Vector3(2.9, 2.6, 13.2), Color("eae6da"))
		k.oriented_box(Vector3(0, 2.6, 0), R, Vector3(2.95, 0.7, 11.0), Color("3d5a80"))
	elif key.begins_with("walker_"):
		var cols := [Color("e63946"), Color("457b9d"), Color("f4a261"), Color("2a9d8f"), Color("6d597a")]
		k.oriented_box(Vector3(0, 0.45, 0), R, Vector3(0.35, 0.9, 0.25), Color("2b2d42"))
		k.oriented_box(Vector3(0, 1.2, 0), R, Vector3(0.45, 0.6, 0.3), cols[int(key.substr(7))])
		k.oriented_box(Vector3(0, 1.65, 0), R, Vector3(0.25, 0.25, 0.25), Color("f1c27d"))
	elif key.begins_with("bike_"):
		var cols2 := [Color("f94144"), Color("277da1"), Color("90be6d"), Color("f9c74f")]
		k.oriented_box(Vector3(0, 0.45, 0), R, Vector3(0.1, 0.7, 1.7), Color("222222"))
		k.oriented_box(Vector3(0, 1.15, 0.1), R, Vector3(0.4, 0.6, 0.35), cols2[int(key.substr(5))])
		k.oriented_box(Vector3(0, 1.55, 0.0), R, Vector3(0.25, 0.25, 0.25), Color("f1c27d"))
	elif key == "boat":
		k.oriented_box(Vector3(0, 0.3, 0), R, Vector3(3.2, 1.2, 9.0), Color("f4f4f4"))
		k.oriented_box(Vector3(0, 0.95, 0), R, Vector3(3.3, 0.15, 9.1), Color("1d3557"))
		k.oriented_box(Vector3(0, 1.6, 1.2), R, Vector3(2.2, 1.3, 3.0), Color("e9c46a"))
	var m := k.commit()
	_meshes[key] = m
	return m
