class_name Traffic
extends Node3D
## Véhicules qui circulent sur les réseaux : voitures sur les routes, trains sur
## les rails, piétons et cyclistes sur les chemins, bateaux sur les voies d'eau.
##
## Chaque véhicule choisit une destination au hasard dans son réseau et y va par
## le plus court chemin (A*), en roulant à droite. Sur les routes et les rails,
## il garde ses distances avec celui qui le précède (file d'attente), freine et
## accélère, et respecte le régime des carrefours (feux, stop, cédez-le-passage,
## priorité à droite) géré par JunctionControl.
##
## Les modèles viennent du catalogue (VehicleCatalog) : chaque véhicule est tiré
## parmi ceux qui peuvent rouler sur la voie, filtrés par époque et région.

## Nombre de véhicules par mètre de réseau, et maximum.
const DENSITY := {
	TransportTypes.Mode.ROAD: [1.0 / 45.0, 160],
	TransportTypes.Mode.RAIL: [1.0 / 350.0, 16],
	TransportTypes.Mode.PATH: [1.0 / 18.0, 120],
	TransportTypes.Mode.WATER: [1.0 / 220.0, 20],
}
const CAR_COLORS: Array[Color] = [Color("d64933"), Color("f2c14e"), Color("2e86ab"), Color("f4f4f4"),
	Color("3c3c3c"), Color("6aa84f"), Color("8e7dbe"), Color("e07a5f")]
## Part de chaque catégorie dans la circulation routière.
const CAT_WEIGHT := {"voiture": 10.0, "utilitaire": 2.0, "bus": 1.0, "deux_roues": 1.5, "attelage": 0.5}
## Part des piétons sur les chemins (le reste : vélos, trottinettes…).
const WALKERS := 0.55
## Arrêt en station des véhicules de ligne (s).
const DWELL := 12.0
const DWELL_AIR := 25.0
## Conduite : accélération et freinage (m/s²), distance entre deux véhicules (m).
const ACCEL := 2.5
const BRAKE := 4.5
const MIN_GAP := 2.0
## Un véhicule bloqué plus longtemps (s) disparaît (ou passe outre, pour les lignes).
const STUCK := 75.0
const STUCK_LINE := 20.0
## Distance (m) en deçà de laquelle un véhicule prioritaire qui arrive fait attendre.
const YIELD_DIST := 32.0

## Émis quand la circulation est réactivée : les lignes remettent leurs véhicules.
signal restarted

var network: TransportNetwork
var enabled := true
var vehicles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

var _material: StandardMaterial3D
var _meshes: Dictionary = {}
var _spawn_timer := 0.0
## Filtres du catalogue ("" = tout) : époque et région (ids de Styles).
var era_filter := ""
var region_filter := ""
var _pool_cache: Dictionary = {}
## Régime des carrefours (fourni par TransportSystem ; null = libre).
var junctions: JunctionControl
## Véhicules routiers et ferroviaires par file (tronçon, sens, voie).
var _index: Dictionary = {}
var _lanes: Dictionary = {}
var _uid := 0
## Occupation des carrefours : id de nœud -> {uid: Vector2i(tronçon d'arrivée, de sortie)}.
var _busy: Dictionary = {}


func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.6
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rng.seed = 7


func setup(net: TransportNetwork) -> void:
	network = net
	network.changed.connect(func() -> void:
		_lanes.clear()
		_busy.clear())


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		clear()
	else:
		restarted.emit()


## Retire les véhicules ; ambient_only : garde ceux des lignes.
func clear(ambient_only := false) -> void:
	var keep: Array[Dictionary] = []
	for v in vehicles:
		if ambient_only and v.has("line"):
			keep.append(v)
		else:
			_free_vehicle(v)
	vehicles = keep


## Retire les véhicules d'une ligne (-1 : de toutes les lignes).
func remove_line_vehicles(line_id: int) -> void:
	var keep: Array[Dictionary] = []
	for v in vehicles:
		if v.has("line") and (line_id < 0 or int(v.line) == line_id):
			_free_vehicle(v)
		else:
			keep.append(v)
	vehicles = keep


## Véhicule de ligne sur le réseau : fait la navette entre les nœuds stops,
## en partant du k-ième. delay : attente avant le premier départ (négatif = à quai).
func add_line_vehicle(line_id: int, model: String, stops: Array[int], k: int, delay := 0.0) -> bool:
	if stops.size() < 2 or not network.nodes.has(stops[k]):
		return false
	var mode := network.node_mode(stops[k])
	var v := {"mode": mode, "node": stops[k], "route": [] as Array[int], "leg": 0, "s": 0.0,
		"trail": PackedVector3Array(), "wagons": [], "speed": 0.0, "lane": 0.6, "lane_idx": 0, "factor": 1.0, "own_speed": 0.0,
		"max_speed": INF, "model": model, "gaps": [], "line": line_id, "stops": stops, "stop_i": k, "step": 1,
		"dwell": absf(delay) + 1.0}
	if k == stops.size() - 1:
		v.step = -1
	if not _next_stop(v):
		return false
	_make_body(v)
	vehicles.append(v)
	_place(v)
	return true


## Aéronef de ligne : path_fn(line_id, de, vers) donne le trajet en 3D.
func add_air_vehicle(line_id: int, model: String, n_stops: int, k: int, path_fn: Callable, delay := 0.0) -> bool:
	if n_stops < 2:
		return false
	var v := {"mode": TransportTypes.Mode.AIR, "model": model, "line": line_id, "n_stops": n_stops, "stop_i": k,
		"step": 1 if k < n_stops - 1 else -1, "dwell": absf(delay) + 1.0, "path_fn": path_fn, "s": 0.0, "wagons": [], "gaps": []}
	if not _next_flight(v):
		return false
	var mi := MeshInstance3D.new()
	mi.material_override = _material
	mi.mesh = _model_mesh(model, line_id)
	add_child(mi)
	v.body = mi
	v.max_speed = minf(float(VehicleCatalog.get_type(model).get("kmh", 300)) / 3.6, 110.0)
	vehicles.append(v)
	_place_air(v)
	return true


func _next_flight(v: Dictionary) -> bool:
	var n: int = v.n_stops
	var ni: int = int(v.stop_i) + int(v.step)
	if ni < 0 or ni >= n:
		v.step = -int(v.step)
		ni = int(v.stop_i) + int(v.step)
	var path: PackedVector3Array = (v.path_fn as Callable).call(int(v.line), int(v.stop_i), ni)
	if path.size() < 2:
		return false
	var d := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		d.append(d[i - 1] + path[i].distance_to(path[i - 1]))
	v.path = path
	v.pd = d
	v.target_i = ni
	v.s = 0.0
	return true


func _advance_air(v: Dictionary, delta: float) -> bool:
	if float(v.dwell) > 0.0:
		v.dwell = float(v.dwell) - delta
		_place_air(v)
		return true
	var path: PackedVector3Array = v.path
	var d: PackedFloat32Array = v.pd
	var i := clampi(d.bsearch(float(v.s)), 1, path.size() - 1)
	var ground := minf(path[0].y, path[path.size() - 1].y)
	var alt := path[i].y - ground
	var vmax: float = v.max_speed
	var spd := lerpf(minf(25.0, vmax), vmax, clampf(alt / 60.0, 0.0, 1.0))
	v.s = float(v.s) + spd * delta
	if float(v.s) >= d[d.size() - 1]:
		v.stop_i = v.target_i
		v.dwell = DWELL_AIR
		if not _next_flight(v):
			return false
	_place_air(v)
	return true


func _place_air(v: Dictionary) -> void:
	var path: PackedVector3Array = v.path
	var d: PackedFloat32Array = v.pd
	var s := clampf(float(v.s), 0.0, d[d.size() - 1])
	var i := clampi(d.bsearch(s), 1, path.size() - 1)
	var seg := maxf(d[i] - d[i - 1], 1e-4)
	var p := path[i - 1].lerp(path[i], clampf((s - d[i - 1]) / seg, 0.0, 1.0))
	var t := path[i] - path[i - 1]
	var flat := Vector3(t.x, 0, t.z)
	var body: Node3D = v.body
	body.position = p
	if flat.length_squared() > 1e-4:
		# Pas de piqué pour un trajet vertical : l'appareil garde son cap.
		var look := t if absf(t.y) < flat.length() * 2.0 else flat
		body.basis = Basis.looking_at(look.normalized(), Vector3.UP)


func _next_stop(v: Dictionary) -> bool:
	var stops: Array[int] = v.stops
	var n := stops.size()
	for _try in n + 1:
		var ni: int = int(v.stop_i) + int(v.step)
		if ni < 0 or ni >= n:
			v.step = -int(v.step)
			ni = int(v.stop_i) + int(v.step)
		v.stop_i = ni
		var target: int = stops[ni]
		if target == int(v.node):
			continue
		var r := network.find_route(v.node, target)
		if not r.is_empty():
			v.route = r
			v.leg = 0
			v.s = 0.0
			return true
	return false


## Change l'époque et la région des véhicules ; la circulation est renouvelée.
func set_filters(era: String, region: String) -> void:
	era_filter = era
	region_filter = region
	_pool_cache.clear()
	clear(true)


## Modèles possibles sur une classe de voie, avec le filtre courant (ou sans
## filtre si rien ne correspond, pour ne jamais laisser une voie vide).
func pool_for(cls: String) -> Array[String]:
	if _pool_cache.has(cls):
		return _pool_cache[cls]
	var ids := VehicleCatalog.for_track(cls, era_filter, region_filter)
	if ids.is_empty():
		ids = VehicleCatalog.for_track(cls, era_filter, "")
	if ids.is_empty():
		ids = VehicleCatalog.for_track(cls)
	_pool_cache[cls] = ids
	return ids


## Tire un modèle au hasard ; sur route, les voitures dominent.
func pick_model(cls: String) -> String:
	var ids := pool_for(cls)
	if ids.is_empty():
		return ""
	if TransportTypes.mode_of(cls) != TransportTypes.Mode.ROAD:
		return ids[rng.randi() % ids.size()]
	var per_cat: Dictionary = {}
	for id in ids:
		var c: String = VehicleCatalog.get_type(id).cat
		per_cat[c] = int(per_cat.get(c, 0)) + 1
	var total := 0.0
	for c in per_cat:
		total += float(CAT_WEIGHT.get(c, 1.0))
	var x := rng.randf() * total
	var cat := ""
	for c in per_cat:
		x -= float(CAT_WEIGHT.get(c, 1.0))
		cat = c
		if x <= 0.0:
			break
	var in_cat: Array[String] = []
	for id in ids:
		if VehicleCatalog.get_type(id).cat == cat:
			in_cat.append(id)
	return in_cat[rng.randi() % in_cat.size()]


## Véhicules d'ambiance d'un mode (sans ceux des lignes).
func count_mode(mode: int) -> int:
	var c := 0
	for v in vehicles:
		if int(v.mode) == mode and not v.has("line"):
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
					if int(vehicles[i].mode) == mode and not vehicles[i].has("line"):
						_free_vehicle(vehicles[i])
						vehicles.remove_at(i)
						break
	step(delta)


## Fait avancer tous les véhicules de delta secondes.
func step(delta: float) -> void:
	if junctions != null:
		junctions.tick(delta)
	_build_index()
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
			"trail": PackedVector3Array(), "wagons": [], "speed": 0.0, "lane": 0.0, "lane_idx": 0, "factor": 1.0, "own_speed": 0.0,
			"max_speed": INF, "model": "", "gaps": []}
		if _new_route(v) and _spawn_free(v):
			found = true
			break
	if not found:
		return false
	_make_body(v)
	vehicles.append(v)
	_place(v)
	return true


## Pas d'apparition sur un véhicule déjà présent au même endroit.
func _spawn_free(v: Dictionary) -> bool:
	var mode := int(v.mode)
	if mode != TransportTypes.Mode.ROAD and mode != TransportTypes.Mode.RAIL:
		return true
	var eid: int = (v.route as Array[int])[0]
	if junctions != null and junctions.is_controlled(int(v.node)):
		return false
	for o in vehicles:
		if int(o.mode) != mode or int(o.leg) >= (o.route as Array).size():
			continue
		if int(o.route[o.leg]) == eid and int(o.node) == int(v.node) and absf(float(o.s) - float(v.s)) < 16.0:
			return false
		# Ni au milieu d'un véhicule qui arrive au même nœud.
		if int(o.node) != int(v.node) and network.other_end(int(o.route[o.leg]), int(o.node)) == int(v.node) \
				and network.edges.has(int(o.route[o.leg])) and float(network.edges[int(o.route[o.leg])].len) - float(o.s) < 25.0:
			return false
	return true


## Ajoute à l'itinéraire d'un véhicule ambiant le trajet vers une nouvelle destination.
func _extend_route(v: Dictionary) -> void:
	var route: Array[int] = v.route
	var leg := int(v.leg)
	var end := network.other_end(route[leg], v.node)
	var comp := network.component(end)
	if comp.size() < 2:
		return
	comp.erase(end)
	for _try in 3:
		var r := network.find_route(end, comp[rng.randi() % comp.size()])
		# Demi-tour seulement au bout d'une impasse.
		if r.is_empty() or (r[0] == route[leg] and network.degree(end) > 1):
			continue
		var nr: Array[int] = route.slice(leg)
		nr.append_array(r)
		v.route = nr
		v.leg = 0
		return


func _new_route(v: Dictionary) -> bool:
	if v.has("line"):
		return _next_stop(v)
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
	if int(v.mode) == TransportTypes.Mode.AIR:
		return _advance_air(v, delta)
	if float(v.get("dwell", 0.0)) > 0.0:
		v.dwell = float(v.dwell) - delta
		_place(v)
		return true
	var route: Array[int] = v.route
	if v.leg >= route.size():
		return false
	var eid: int = route[v.leg]
	if not network.edges.has(eid):
		return false
	var e0: Dictionary = network.edges[eid]
	var spd: float = v.own_speed if float(v.own_speed) > 0.0 else minf(TransportTypes.speed_of(e0.t), float(v.max_speed)) * float(v.factor)
	var mode := int(v.mode)
	if mode == TransportTypes.Mode.ROAD or mode == TransportTypes.Mode.RAIL:
		if not _drive(v, eid, e0, spd, delta):
			return false
	else:
		v.s = float(v.s) + spd * delta
	var guard := 0
	while float(v.s) >= float(network.edges[eid].len) and guard < 16:
		guard += 1
		v.s = float(v.s) - float(network.edges[eid].len)
		v.node = network.other_end(eid, v.node)
		v.leg = int(v.leg) + 1
		v.granted = -1
		if v.leg >= route.size():
			if v.has("line"):
				# Arrivée en station : arrêt, puis départ vers la suivante.
				if not _next_stop(v):
					return false
				v.dwell = DWELL
				_place(v)
				return true
			if not _new_route(v):
				return false
			route = v.route
		eid = route[v.leg]
		if not network.edges.has(eid):
			return false
		var e: Dictionary = network.edges[eid]
		if e.a != v.node and e.b != v.node:
			return false
	_release_if_clear(v)
	_place(v)
	return true


# --- Conduite : files, freinage et carrefours ---------------------------------------

func _lane_count(eid: int) -> int:
	if not _lanes.has(eid):
		var e: Dictionary = network.edges[eid]
		_lanes[eid] = maxi(1, TransportTypes.lane_offsets(e.t, e.w).size())
	return _lanes[eid]


func _key(eid: int, forward: bool, lane_idx: int) -> int:
	return (eid * 2 + (0 if forward else 1)) * 4 + mini(lane_idx, _lane_count(eid) - 1)


func _build_index() -> void:
	_index.clear()
	for v in vehicles:
		var mode := int(v.mode)
		if mode != TransportTypes.Mode.ROAD and mode != TransportTypes.Mode.RAIL:
			continue
		var route: Array[int] = v.route
		if int(v.leg) >= route.size():
			continue
		var eid: int = route[v.leg]
		if not network.edges.has(eid):
			continue
		var k := _key(eid, network.edges[eid].a == v.node, int(v.lane_idx))
		if not _index.has(k):
			_index[k] = []
		(_index[k] as Array).append(v)


## Véhicule le plus proche devant la position s dans une file : [véhicule, s] ou [].
func _leader(k: int, s: float, me: Dictionary) -> Array:
	var best: Dictionary = {}
	var best_s := INF
	for o in _index.get(k, []):
		if is_same(o, me):
			continue
		var os := float(o.s)
		if os < s or (os == s and int(o.uid) > int(me.uid)):
			continue
		if os < best_s:
			best_s = os
			best = o
	return [] if best.is_empty() else [best, best_s]


## Place libre devant v (m) : jusqu'à l'arrière du véhicule qui le précède,
## sur son tronçon ou sur le suivant.
func _room(v: Dictionary, eid: int, e: Dictionary, s: float) -> float:
	var forward: bool = e.a == v.node
	var front := s + float(v.get("half", 2.0))
	var lead := _leader(_key(eid, forward, int(v.lane_idx)), s, v)
	if not lead.is_empty():
		return float(lead[1]) - float(lead[0].get("rear", 2.0)) - front - MIN_GAP
	var route: Array[int] = v.route
	if int(v.leg) + 1 >= route.size():
		# Véhicule ambiant sans suite connue : il attend au nœud qu'on lui en trouve une.
		return INF if v.has("line") else float(e.len) - s - 0.01
	var nxt: int = route[int(v.leg) + 1]
	if not network.edges.has(nxt):
		return INF
	var n2 := network.other_end(eid, v.node)
	var lead2 := _leader(_key(nxt, network.edges[nxt].a == n2, int(v.lane_idx)), -1.0, v)
	if lead2.is_empty():
		return INF
	return float(e.len) + float(lead2[1]) - float(lead2[0].get("rear", 2.0)) - front - MIN_GAP


## Avance un véhicule routier ou ferroviaire : file d'attente, carrefours,
## freinage. Renvoie faux s'il est resté bloqué trop longtemps.
func _drive(v: Dictionary, eid: int, e: Dictionary, cruise: float, delta: float) -> bool:
	var s := float(v.s)
	var stuck := float(v.get("stuck", 0.0))
	var ghost: bool = v.has("line") and stuck > STUCK_LINE
	var route: Array[int] = v.route
	# Destination suivante choisie à l'avance : le véhicule voit qui est devant
	# lui à la sortie du nœud et respecte le carrefour.
	if not v.has("line") and int(v.leg) + 1 >= route.size() and float(e.len) - s < 40.0:
		_extend_route(v)
		route = v.route
	var limit := INF if ghost else _room(v, eid, e, s)
	var nid := network.other_end(eid, v.node)
	if int(v.mode) == TransportTypes.Mode.ROAD and junctions != null and junctions.is_controlled(nid) \
			and int(v.leg) + 1 < route.size() and int(v.get("granted", -1)) != nid and not ghost:
		var stop_s := float(e.len) - junctions.trim(eid, nid) - 0.6 - float(v.get("half", 2.0))
		var dist := stop_s - s
		var at_line := dist <= maxf(1.0, float(v.speed) * 1.2)
		if at_line and _may_enter(v, nid, eid, route[int(v.leg) + 1], maxf(dist, 0.0)):
			v.granted = nid
			_release(v)
			if not _busy.has(nid):
				_busy[nid] = {}
			_busy[nid][int(v.uid)] = Vector2i(eid, route[int(v.leg) + 1])
			v.res = nid
		else:
			limit = minf(limit, maxf(dist, 0.0))
	var target := cruise
	if limit < INF:
		target = minf(cruise, sqrt(2.0 * BRAKE * maxf(limit, 0.0)))
	var speed := float(v.speed)
	speed = target if speed > target else minf(target, speed + ACCEL * delta)
	var adv := speed * delta
	if limit < INF:
		adv = clampf(adv, 0.0, maxf(limit, 0.0))
	v.speed = speed
	v.s = s + adv
	if adv < 0.05 * delta:
		v.wait = float(v.get("wait", 0.0)) + delta
		v.stuck = stuck + delta
		if not v.has("line") and float(v.stuck) > STUCK:
			return false
	else:
		v.wait = 0.0
		v.stuck = 0.0 if adv > 0.5 * delta else stuck
	return true


## Le véhicule v, arrêté (ou presque) à la ligne de la branche eid, peut-il
## s'engager dans le carrefour nid pour sortir par exit_eid ?
func _may_enter(v: Dictionary, nid: int, eid: int, exit_eid: int, dist: float) -> bool:
	# Place à la sortie, sinon on bloquerait le carrefour.
	if network.edges.has(exit_eid):
		var ex: Dictionary = network.edges[exit_eid]
		var lead := _leader(_key(exit_eid, ex.a == nid, int(v.lane_idx)), -1.0, v)
		if not lead.is_empty() and float(lead[1]) - float(lead[0].get("rear", 2.0)) < float(v.get("half", 2.0)) * 2.0 + MIN_GAP + junctions.trim(exit_eid, nid) * 0.5:
			return false
	# Un autre véhicule s'engage déjà vers la même sortie.
	for uid in _busy.get(nid, {}):
		var b: Vector2i = _busy[nid][uid]
		if b.x != eid and b.y == exit_eid:
			return false
	var waited := float(v.get("wait", 0.0))
	match junctions.kind(nid):
		"feux":
			var c := junctions.light(nid, eid)
			if c == JunctionControl.VERT:
				return true
			# À l'orange, on passe seulement si on ne peut plus s'arrêter.
			return c == JunctionControl.ORANGE and float(v.speed) > 4.0 and dist < float(v.speed) * 0.8
		"stop", "cedez":
			if junctions.is_major(nid, eid):
				return true
			if junctions.kind(nid) == "stop" and (waited < 1.2 or dist > 1.2):
				return false
			if _crossing_from_other(nid, eid):
				return false
			for o in network.adjacency.get(nid, []):
				if o != eid and junctions.is_major(nid, o) and _approaching(nid, o, YIELD_DIST):
					return false
			return true
		"droite":
			if _crossing_from_other(nid, eid):
				return false
			# Au bout de quelques secondes, on finit par passer (tout le monde
			# attendrait sinon celui de droite).
			var r := junctions.right_of(nid, eid)
			if r >= 0 and waited < 4.0 and _approaching(nid, r, YIELD_DIST * 0.8):
				return false
			return true
	return true


## Un véhicule venu d'une autre branche est-il en train de traverser ?
func _crossing_from_other(nid: int, eid: int) -> bool:
	for uid in _busy.get(nid, {}):
		if (_busy[nid][uid] as Vector2i).x != eid:
			return true
	return false


## Un véhicule arrive-t-il au carrefour nid par la branche eid, à moins de d m ?
func _approaching(nid: int, eid: int, d: float) -> bool:
	var e: Dictionary = network.edges[eid]
	var toward_b: bool = e.b == nid # sens a -> b
	for lane in _lane_count(eid):
		for o in _index.get(_key(eid, toward_b, lane), []):
			if float(e.len) - float(o.s) < d:
				return true
	return false


## Libère le carrefour quand le véhicule en est sorti.
func _release_if_clear(v: Dictionary) -> void:
	var res := int(v.get("res", -1))
	if res < 0:
		return
	var route: Array[int] = v.route
	if int(v.leg) >= route.size() or not network.edges.has(route[v.leg]) or junctions == null:
		_release(v)
		return
	var eid: int = route[v.leg]
	var gone: bool
	if int(v.node) == res:
		# Sorti du carrefour quand l'arrière a franchi le bord du plateau.
		gone = float(v.s) > junctions.trim(eid, res) + float(v.get("rear", 2.0))
	else:
		# Encore en approche ? Sinon (itinéraire changé), on libère.
		gone = network.other_end(eid, v.node) != res
	if gone:
		_release(v)


func _release(v: Dictionary) -> void:
	var res := int(v.get("res", -1))
	if res >= 0 and _busy.has(res):
		(_busy[res] as Dictionary).erase(int(v.get("uid", 0)))
	v.res = -1


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
		var gaps: Array = v.gaps
		var trail: PackedVector3Array = v.trail
		if trail.is_empty() or trail[trail.size() - 1].distance_to(pos) >= 1.0:
			trail.append(pos)
			if trail.size() > int(gaps[gaps.size() - 1]) + 8:
				trail.remove_at(0)
			v.trail = trail
		for k in (v.wagons as Array).size():
			var w: Node3D = v.wagons[k]
			var idx := trail.size() - 1 - int(gaps[k])
			w.visible = idx >= 0
			if idx >= 0:
				w.position = trail[idx]
				var ahead := trail[mini(idx + 2, trail.size() - 1)] - trail[idx]
				if ahead.length_squared() > 1e-4:
					w.basis = Basis.looking_at(ahead.normalized(), Vector3.UP)


# --- Modèles low-poly -----------------------------------------------------------

func _make_body(v: Dictionary) -> void:
	var mode: int = v.mode
	_uid += 1
	v.uid = _uid
	v.half = 0.5
	v.rear = 0.5
	v.factor = rng.randf_range(0.85, 1.05)
	v.lane_idx = rng.randi() % 4
	v.lane = rng.randf_range(0.3, 1.4)
	var first_edge: Dictionary = network.edges[(v.route as Array[int])[0]]
	var cls: String = first_edge.t
	var model := ""
	if v.has("line"):
		model = v.model
		v.factor = 1.0
		v.lane_idx = 0
	elif mode == TransportTypes.Mode.PATH and (cls == "trottoir" or rng.randf() < WALKERS):
		model = ""
	else:
		model = pick_model(cls)
		# Pas de navire plus large que le chenal.
		for _try in 6:
			if model == "" or float(VehicleCatalog.get_type(model).W) <= float(first_edge.get("width", 99.0)) * 0.6:
				break
			model = pick_model(cls)
	v.model = model
	var mi := MeshInstance3D.new()
	mi.material_override = _material
	add_child(mi)
	v.body = mi
	if model == "":
		var key := "walker_%d" % (rng.randi() % 5) if mode == TransportTypes.Mode.PATH else "boat"
		mi.mesh = _mesh(key)
		v.own_speed = rng.randf_range(1.1, 1.6) if mode == TransportTypes.Mode.PATH else 0.0
		return
	var t := VehicleCatalog.get_type(model)
	var paint := rng.randi() % VehicleCatalog.paint_count(model)
	mi.mesh = _model_mesh(model, paint)
	v.max_speed = float(t.kmh) / 3.6
	v.half = float(t.L) / 2.0
	v.rear = v.half
	v.speed = 0.0 if v.has("line") else v.max_speed * 0.5
	if mode == TransportTypes.Mode.PATH:
		v.own_speed = v.max_speed * rng.randf_range(0.6, 0.9)
	# Voitures attelées : écart (en mètres de trace) entre chaque caisse et la tête.
	var gap := float(t.L) / 2.0
	for wid in t.get("consist", []):
		var wt := VehicleCatalog.get_type(wid)
		gap += float(wt.L) / 2.0 + 0.8
		(v.gaps as Array).append(roundi(gap))
		gap += float(wt.L) / 2.0
		v.rear = gap
		var w := MeshInstance3D.new()
		w.mesh = _model_mesh(wid, paint)
		w.material_override = _material
		w.visible = false
		add_child(w)
		(v.wagons as Array).append(w)


func _model_mesh(id: String, paint: int) -> ArrayMesh:
	var key := "%s:%d" % [id, paint]
	if not _meshes.has(key):
		_meshes[key] = VehicleCatalog.build_mesh(id, paint)
	return _meshes[key]


func _free_vehicle(v: Dictionary) -> void:
	_release(v)
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
