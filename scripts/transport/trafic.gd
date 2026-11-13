class_name Trafic
extends Node
## Modèle de trafic : embouteillages, stationnement et affluence des lignes,
## calculés d'après les vrais trajets des habitants (domicile → travail / école).
##
## Le calcul tourne par petits morceaux à chaque image (budget de temps) :
## 1. « relevé » : le mode de chaque habitant (Population.commute, qui tient
##    compte des bouchons, des places et de l'affluence du cycle précédent) ;
## 2. « affectation » : chaque voiture de l'heure de pointe suit le chemin le
##    plus rapide, d'après les temps du cycle précédent (Dijkstra par origine) ;
## 3. « bilan » : flux lissés (méthode des moyennes successives), saturation de
##    chaque tronçon (formule BPR), occupation des places par quartier,
##    remplissage des lignes, recettes, chiffres du panneau.
##
## Les voitures visibles ralentissent selon la saturation et l'heure
## (Traffic.speed_factors), les bus aussi sauf sur une voie réservée.

signal changed
signal message(text: String)

## Capacité d'une voie, en véhicules par heure et par sens, selon la classe
## (les carrefours rapprochés des rues en ville divisent le débit).
const CAP_PER_LANE := {"rue": 500.0, "avenue": 800.0, "giratoire": 1200.0, "departementale": 1100.0,
	"voie_express": 1800.0, "autoroute": 1900.0, "bretelle": 1500.0}
## Classes sans accès direct aux bâtiments.
const NO_ACCESS := ["autoroute", "voie_express", "bretelle"]
## Formule BPR : t = t0 × (1 + ALPHA × (flux / capacité)^BETA).
const BPR_ALPHA := 0.15
const BPR_BETA := 4.0
const MAX_RATIO := 3.0
## Part des voitures des navetteurs qui roulent pendant l'heure de pointe.
const PEAK_SHARE := 0.5
## Délai moyen d'un carrefour (s).
const JUNCTION_S := 3.0
## Distance maximale entre un bâtiment et sa route (m).
const ACCESS_MAX := 400.0
## Quartiers de stationnement (m).
const CELL := 200.0
## Places le long des trottoirs par mètre de rue (deux côtés, entrées déduites).
const CURB_PER_M := {"rue": 0.22, "avenue": 0.18}
## Places privées des entreprises par emploi.
const PRIVATE_PER_JOB := 0.3
## Valeur du temps : minutes par euro (15 €/h).
const MIN_PER_EURO := 4.0
## Carburant et usure de la voiture (€/km).
const CAR_EUR_KM := 0.15
## Ticket par défaut d'une nouvelle ligne (€ le trajet, gratuit pour les moins de 18 ans).
const DEFAULT_FARE := 1.5
## Coût d'exploitation d'un véhicule de ligne par mois (€), selon le type de ligne.
const RUN_COST := {"bus": 3000.0, "tram": 5000.0, "metro": 8000.0, "train": 9000.0, "bateau": 3000.0, "avion": 15000.0, "camion": 0.0}
## Places par défaut d'un véhicule de ligne sans « places » au catalogue.
const DEFAULT_PLACES := {"bus": 80, "tram": 200, "metro": 600, "train": 400, "bateau": 150, "avion": 150}
## Budget de calcul par image (µs).
const BUDGET_US := 2500
## Pause entre deux cycles complets (s).
const CYCLE_PAUSE := 3.0

var transport: TransportSystem
var population: Population

## Flux de pointe lissé par sens : clé (eid × 2 + sens) -> véhicules/h.
var flow: Dictionary = {}
## Bus et cars par heure de pointe sur chaque tronçon (les deux sens).
var bus_flow: Dictionary = {}
## Temps de parcours en voiture à la pointe : Vector2i(nœud départ, nœud arrivée) -> s.
var od_time: Dictionary = {}
## Le même trajet à vide (sans bouchon), pour le retard.
var od_free: Dictionary = {}
## Stationnement par quartier : Vector2i -> {free, paid, fare, demand, occ, search, walk, cost}.
var park_cells: Dictionary = {}
## Places privées utilisées par bâtiment (bid -> [places, voitures]).
var park_private: Dictionary = {}
## Remplissage des lignes : lid -> {riders, cap, load, headway, extra}.
var line_load: Dictionary = {}
## Tarifs : lid -> € par trajet ; sid (parking) -> € par jour.
var fares: Dictionary = {}
var parking_fares: Dictionary = {}
## Voies réservées aux bus (et taxis) : eid -> true.
var bus_lanes: Dictionary = {}
## Routes fermées par ce système (cortège, travaux…) : eid -> raison.
var closures: Dictionary = {}
## Chiffres du dernier cycle.
var stats: Dictionary = {}
## Recettes et dépenses : {"mois": {poste: €}, "precedent": {...}, "jours": n}.
var ledger := {"mois": {}, "precedent": {}, "jours": 0}
## Facteur visible sur les voitures (désactivable pour comparer).
var visible_jams := true

var _phase := "repos"
var _pause := 0.5
var _ids: Array = []
var _i := 0
var _acc: Dictionary = {}
var _origins: Array = []
var _new_flow: Dictionary = {}
var _new_time: Dictionary = {}
var _new_free: Dictionary = {}
var _access: Dictionary = {}
var _grid: Dictionary = {}
var _grid_dirty := true
var _edge_cost: Dictionary = {}
var _line_edges: Dictionary = {}
var _last_day := -1
var _cycles := 0


func setup(t: TransportSystem, p: Population) -> void:
	transport = t
	population = p
	transport.network.changed.connect(_on_network_changed)
	if transport.stations != null:
		transport.stations.lines_changed.connect(func() -> void: _line_edges.clear())
		if transport.stations.planner != null:
			transport.stations.planner.edge_factor = bus_factor
			transport.stations.planner.extra_wait = {}
	if transport.traffic != null:
		transport.traffic.model = self
		transport.traffic.speed_factors.append(_visible_factor)
	add_to_group("budget_entretien")
	add_to_group("avis_sources")


func _on_network_changed() -> void:
	_grid_dirty = true
	_access.clear()
	_line_edges.clear()
	# Les tronçons coupés ou fusionnés changent d'id : on oublie les clés disparues.
	var net := transport.network
	for k in flow.keys():
		if not net.edges.has(int(k) >> 1):
			flow.erase(k)
	for e in bus_lanes.keys():
		if not net.edges.has(int(e)):
			bus_lanes.erase(e)
	for e in closures.keys():
		if not net.edges.has(int(e)):
			closures.erase(e)


func clear() -> void:
	flow.clear()
	bus_flow.clear()
	od_time.clear()
	od_free.clear()
	park_cells.clear()
	park_private.clear()
	line_load.clear()
	fares.clear()
	parking_fares.clear()
	bus_lanes.clear()
	closures.clear()
	stats.clear()
	ledger = {"mois": {}, "precedent": {}, "jours": 0}
	_access.clear()
	_grid_dirty = true
	_phase = "repos"
	_pause = 0.5


# --- Boucle ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if transport == null or population == null:
		return
	_daily()
	if _phase == "repos":
		_pause -= delta
		if _pause > 0.0:
			return
		_start_cycle()
	var t0 := Time.get_ticks_usec()
	while _phase != "repos" and Time.get_ticks_usec() - t0 < BUDGET_US:
		_work()


## Fait un cycle complet tout de suite (tests, chargement).
func run_cycle() -> void:
	if _phase == "repos":
		_start_cycle()
	var guard := 0
	while _phase != "repos" and guard < 10000000:
		guard += 1
		_work()


func _start_cycle() -> void:
	_ids = population.persons.keys()
	_i = 0
	_acc = {"modes": {"voiture": 0, "commun": 0, "velo": 0, "pied": 0}, "min": 0.0, "n": 0, "delay": 0.0, "n_car": 0,
		"od": {}, "riders": {}, "arrive": {}, "search": 0.0}
	_phase = "releve"


func _work() -> void:
	match _phase:
		"releve":
			_collect_some(60)
		"affectation":
			_assign_one()
		"bilan":
			_finish()


# --- 1. Relevé des trajets ----------------------------------------------------------

func _collect_some(n: int) -> void:
	var stop := mini(_i + n, _ids.size())
	while _i < stop:
		var pid: int = _ids[_i]
		_i += 1
		if not population.persons.has(pid):
			continue
		var p: Dictionary = population.persons[pid]
		var dest := _dest_of(p)
		var home := population.home_of(p)
		if dest < 0 or home < 0:
			continue
		var c := population.commute(p, home, dest)
		var mode := String(c.mode)
		_acc.n = int(_acc.n) + 1
		_acc.min = float(_acc.min) + float(c.min)
		if mode.begins_with("en voiture"):
			_acc.modes.voiture += 1
			_acc.n_car = int(_acc.n_car) + 1
			_acc.delay = float(_acc.delay) + float(c.get("delay", 0.0))
			_acc.search = float(_acc.search) + float(c.get("park", 0.0))
			var k := Vector2i(home, dest)
			_acc.od[k] = int(_acc.od.get(k, 0)) + 1
			_acc.arrive[dest] = int(_acc.arrive.get(dest, 0)) + 1
		elif c.has("trip"):
			_acc.modes.commun += 1
			for leg in c.trip.get("legs", []):
				if String(leg.type) == "ligne":
					_acc.riders[int(leg.line)] = int(_acc.riders.get(int(leg.line), 0)) + 1
		elif mode.begins_with("à vélo"):
			_acc.modes.velo += 1
		else:
			_acc.modes.pied += 1
	if _i >= _ids.size():
		_prepare_assign()


func _dest_of(p: Dictionary) -> int:
	var st := population.stage(p)
	if st == "eleve":
		return int(p.sch)
	if st == "actif":
		return int(p.job)
	return -1


func _prepare_assign() -> void:
	# Regroupe les voitures par nœud de départ.
	var by_origin := {}
	for k in _acc.od:
		var a := access_of(k.x)
		var b := access_of(k.y)
		if a.is_empty() or b.is_empty() or int(a.node) == int(b.node):
			continue
		var o := int(a.node)
		if not by_origin.has(o):
			by_origin[o] = {}
		by_origin[o][int(b.node)] = float(by_origin[o].get(int(b.node), 0.0)) + float(_acc.od[k]) * PEAK_SHARE
	_origins = []
	for o in by_origin:
		_origins.append([o, by_origin[o]])
	_new_flow = {}
	_new_time = {}
	_new_free = {}
	_edge_cost = {}
	_phase = "affectation" if not _origins.is_empty() else "bilan"


# --- 2. Affectation sur le réseau ---------------------------------------------------

## Coût (s) pour parcourir eid dans un sens, avec les bouchons du cycle précédent.
func _cost(eid: int, fwd: bool, free := false) -> float:
	var key := eid * 2 + (0 if fwd else 1)
	if not free and _edge_cost.has(key):
		return _edge_cost[key]
	var e: Dictionary = transport.network.edges[eid]
	var t0 := float(e.len) / maxf(1.0, TransportTypes.speed_of(e.t))
	if free:
		return t0
	var c := t0 * bpr(ratio_key(key))
	_edge_cost[key] = c
	return c


static func bpr(x: float) -> float:
	return 1.0 + BPR_ALPHA * pow(clampf(x, 0.0, MAX_RATIO), BPR_BETA)


func _assign_one() -> void:
	if _origins.is_empty():
		_phase = "bilan"
		return
	var item: Array = _origins.pop_back()
	var o: int = item[0]
	var dests: Dictionary = item[1]
	var res := _dijkstra(o, dests, false)
	var prev: Dictionary = res.prev
	var dist: Dictionary = res.dist
	for d in dests:
		if not dist.has(d):
			continue
		_new_time[Vector2i(o, d)] = float(dist[d])
		var q: float = dests[d]
		var free_t := 0.0
		var n: int = d
		var guard := 0
		while n != o and prev.has(n) and guard < 100000:
			guard += 1
			var pk: Vector2i = prev[n] # (eid, nœud précédent)
			var e: Dictionary = transport.network.edges[pk.x]
			var fwd := int(e.a) == pk.y
			var key := pk.x * 2 + (0 if fwd else 1)
			_new_flow[key] = float(_new_flow.get(key, 0.0)) + q
			free_t += _cost(pk.x, fwd, true) + (JUNCTION_S if transport.network.degree(pk.y) >= 3 else 0.0)
			n = pk.y
		_new_free[Vector2i(o, d)] = free_t


## Plus courts temps depuis o (s) ; s'arrête quand toutes les destinations sont atteintes.
func _dijkstra(o: int, dests: Dictionary, free: bool) -> Dictionary:
	var net := transport.network
	var dist := {o: 0.0}
	var prev := {}
	var done := {}
	var heap_k: Array[int] = [o]
	var heap_v: PackedFloat64Array = PackedFloat64Array([0.0])
	var left := dests.size()
	while not heap_k.is_empty():
		var cur: int = heap_k[0]
		var cur_t: float = heap_v[0]
		_heap_pop(heap_k, heap_v)
		if done.has(cur):
			continue
		done[cur] = true
		if dests.has(cur):
			left -= 1
			if left <= 0:
				break
		var extra := JUNCTION_S if net.degree(cur) >= 3 else 0.0
		for eid in net.adjacency.get(cur, []):
			if net.closed_edges.has(eid):
				continue
			var e: Dictionary = net.edges[eid]
			if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
				continue
			var fwd := int(e.a) == cur
			if not fwd and TransportTypes.is_oneway(e.t):
				continue
			var nxt := int(e.b) if fwd else int(e.a)
			if done.has(nxt):
				continue
			var t := cur_t + _cost(eid, fwd, free) + extra
			if t < float(dist.get(nxt, INF)):
				dist[nxt] = t
				prev[nxt] = Vector2i(eid, cur)
				_heap_push(heap_k, heap_v, nxt, t)
	return {"dist": dist, "prev": prev}


static func _heap_push(k: Array[int], v: PackedFloat64Array, key: int, val: float) -> void:
	k.append(key)
	v.append(val)
	var i := k.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if v[p] <= v[i]:
			break
		var tk := k[p]
		k[p] = k[i]
		k[i] = tk
		var tv := v[p]
		v[p] = v[i]
		v[i] = tv
		i = p


static func _heap_pop(k: Array[int], v: PackedFloat64Array) -> void:
	var last := k.size() - 1
	k[0] = k[last]
	v[0] = v[last]
	k.remove_at(last)
	v.remove_at(last)
	var n := k.size()
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and v[l] < v[m]:
			m = l
		if r < n and v[r] < v[m]:
			m = r
		if m == i:
			break
		var tk := k[m]
		k[m] = k[i]
		k[i] = tk
		var tv := v[m]
		v[m] = v[i]
		v[i] = tv
		i = m


# --- 3. Bilan ------------------------------------------------------------------------

func _finish() -> void:
	_cycles += 1
	# Moyennes successives : la moitié du nouveau, la moitié de l'ancien
	# (les habitants changent de route et de mode petit à petit).
	var w := 1.0 if _cycles <= 1 else 0.5
	var keys := {}
	for k in flow:
		keys[k] = true
	for k in _new_flow:
		keys[k] = true
	for k in keys:
		var v := lerpf(float(flow.get(k, 0.0)), float(_new_flow.get(k, 0.0)), w)
		if v < 0.05:
			flow.erase(k)
		else:
			flow[k] = v
	for k in _new_time:
		od_time[k] = lerpf(float(od_time.get(k, _new_time[k])), float(_new_time[k]), w)
	for k in _new_free:
		od_free[k] = _new_free[k]
	_compute_bus_flow()
	_compute_parking(w)
	_compute_lines()
	_compute_stats()
	population._transit_cache.clear()
	_phase = "repos"
	_pause = CYCLE_PAUSE
	changed.emit()


## Saturation (flux / capacité) d'un sens de tronçon, à l'heure de pointe.
func ratio_key(key: int) -> float:
	var eid := key >> 1
	if not transport.network.edges.has(eid):
		return 0.0
	var q := float(flow.get(key, 0.0)) + float(bus_flow.get(eid, 0.0)) * 1.0
	if q <= 0.0:
		return 0.0
	return q / capacity(eid)


## Saturation d'un tronçon à la pointe (le sens le plus chargé).
func ratio(eid: int) -> float:
	return maxf(ratio_key(eid * 2), ratio_key(eid * 2 + 1))


## Véhicules par heure et par sens qu'un tronçon laisse passer.
func capacity(eid: int) -> float:
	var e: Dictionary = transport.network.edges[eid]
	var c := TransportTypes.get_type(e.t)
	var s := TransportTypes.normalize(e.t, e.w if e.has("w") else {})
	var lanes := int(s.get("lanes", 1))
	if c.get("oneway", false) and not c.get("single", false):
		lanes *= 2
	if bus_lanes.has(eid) and lanes > 1:
		lanes -= 1
	return maxf(100.0, lanes * float(CAP_PER_LANE.get(String(e.t), 600.0)))


## Activité selon l'heure (1 à la pointe du matin).
static func hour_profile(h: float) -> float:
	var am := exp(-pow((h - 8.0) / 1.0, 2.0))
	var pm := 0.9 * exp(-pow((h - 17.5) / 1.3, 2.0))
	var mid := 0.35 * exp(-pow((h - 12.5) / 2.2, 2.0))
	var night := 0.04 if (h < 5.5 or h > 22.5) else 0.12
	return clampf(maxf(maxf(am, pm), mid) + night, 0.0, 1.0)


func _hour() -> float:
	return float(population.now().h) if population != null else 8.0


## Saturation d'un tronçon maintenant (pointe × heure).
func ratio_now(eid: int) -> float:
	return ratio(eid) * hour_profile(_hour())


# --- Bus ------------------------------------------------------------------------------

## Tronçons routiers parcourus par une ligne (aller).
func _route_edges(lid: int) -> Array[int]:
	if _line_edges.has(lid):
		return _line_edges[lid]
	var out: Array[int] = []
	var st := transport.stations
	var l: Dictionary = st.lines[lid]
	var stops: Array = l.stops
	for i in stops.size() - 1:
		if not st.stations.has(int(stops[i])) or not st.stations.has(int(stops[i + 1])):
			continue
		var r := transport.network.find_route(int(st.stations[int(stops[i])].node), int(st.stations[int(stops[i + 1])].node))
		for eid in r:
			if TransportTypes.mode_of(transport.network.edges[eid].t) == TransportTypes.Mode.ROAD:
				out.append(eid)
	_line_edges[lid] = out
	return out


func _compute_bus_flow() -> void:
	bus_flow.clear()
	var st := transport.stations
	if st == null or st.planner == null:
		return
	for lid in st.lines:
		var l: Dictionary = st.lines[lid]
		if String(l.kind) != "bus" and String(l.kind) != "camion":
			continue
		var info := st.planner._line_info(lid)
		if info.is_empty():
			continue
		var per_h := 3600.0 / maxf(60.0, float(info.wait) * 2.0)
		for eid in _route_edges(lid):
			bus_flow[eid] = float(bus_flow.get(eid, 0.0)) + per_h


## Facteur de temps d'un bus sur un tronçon à la pointe (pour le planificateur).
func bus_factor(eid: int) -> float:
	if bus_lanes.has(eid):
		return 1.0
	return minf(bpr(ratio(eid)), 4.0)


## Vitesse des véhicules visibles : ralentis selon la saturation de l'heure.
func _visible_factor(eid: int, v: Dictionary) -> float:
	if not visible_jams or v.has("urgence"):
		return 1.0
	if v.has("line") and bus_lanes.has(eid):
		return 1.0
	var e: Dictionary = transport.network.edges.get(eid, {})
	if e.is_empty():
		return 1.0
	var fwd := int(e.a) == int(v.get("node", e.a))
	var x := ratio_key(eid * 2 + (0 if fwd else 1)) * hour_profile(_hour())
	if x < 0.5:
		return 1.0
	return clampf(1.0 / bpr(x), 0.15, 1.0)


# --- Accès des bâtiments au réseau -------------------------------------------------

## Route la plus proche d'un bâtiment : {node, walk (m)} ou {} si aucune.
func access_of(bid: int) -> Dictionary:
	if _access.has(bid):
		return _access[bid]
	if not population.known.has(bid):
		return {}
	var p: Vector3 = population.known[bid].pos
	var res := _nearest_road(p)
	_access[bid] = res
	return res


func _build_grid() -> void:
	_grid.clear()
	var net := transport.network
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD or NO_ACCESS.has(String(e.t)):
			continue
		var pts: PackedVector3Array = e.pts
		var d: PackedFloat32Array = e.d
		var step := maxi(1, pts.size() / maxi(1, int(float(e.len) / 20.0)))
		var i := 0
		while i < pts.size():
			var c := Vector2i(floori(pts[i].x / 50.0), floori(pts[i].z / 50.0))
			if not _grid.has(c):
				_grid[c] = []
			(_grid[c] as Array).append([eid, pts[i], float(d[i]) if i < d.size() else 0.0])
			i += step
	_grid_dirty = false


func _nearest_road(p: Vector3) -> Dictionary:
	if _grid_dirty:
		_build_grid()
	var c := Vector2i(floori(p.x / 50.0), floori(p.z / 50.0))
	var best := []
	var best_d := ACCESS_MAX
	var r := ceili(ACCESS_MAX / 50.0)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for it in _grid.get(c + Vector2i(dx, dz), []):
				var q: Vector3 = it[1]
				var dd := Vector2(q.x - p.x, q.z - p.z).length()
				if dd < best_d:
					best_d = dd
					best = it
	if best.is_empty():
		return {}
	var e: Dictionary = transport.network.edges[int(best[0])]
	var along := float(best[2])
	var node := int(e.a) if along <= float(e.len) * 0.5 else int(e.b)
	var drive := minf(along, float(e.len) - along)
	return {"node": node, "walk": best_d, "drive": drive, "pos": best[1]}


func has_roads() -> bool:
	if _grid_dirty:
		_build_grid()
	return not _grid.is_empty()


# --- Trajet en voiture (pour Population.commute) -----------------------------------

## Trajet en voiture entre deux bâtiments : {} si le réseau est vide (estimation
## par défaut), {ok: false} sans route, sinon {ok, min, delay, park, walk, cost}.
func car_trip(from_bid: int, to_bid: int, dist_m: float) -> Dictionary:
	if transport == null or not has_roads():
		return {}
	var a := access_of(from_bid)
	var b := access_of(to_bid)
	if a.is_empty() or b.is_empty():
		return {"ok": false, "why": "pas de route"}
	var key := Vector2i(int(a.node), int(b.node))
	var drive_s := 0.0
	var free_s := 0.0
	if a.node == b.node:
		drive_s = dist_m / 8.0
		free_s = drive_s
	elif od_time.has(key):
		drive_s = od_time[key]
		free_s = float(od_free.get(key, drive_s))
	else:
		# Pas encore calculé : estimation à 35 km/h, retard moyen de la ville.
		free_s = dist_m / 9.7
		drive_s = free_s * float(stats.get("jam_factor", 1.0))
	drive_s += (float(a.drive) + float(b.drive)) / 8.0
	var walk_s := (float(a.walk) + float(b.walk)) / 1.3
	var park := parking_for(to_bid)
	var mins := (drive_s + walk_s) / 60.0 + float(park.search) + float(park.walk) + 1.0
	var cost := dist_m / 1000.0 * CAR_EUR_KM + float(park.cost) * 0.5
	return {"ok": true, "min": maxi(2, roundi(mins)), "delay": maxf(0.0, (drive_s - free_s) / 60.0),
		"park": float(park.search) + float(park.walk), "cost": cost}


## Stationnement à l'arrivée : {search (min), walk (min), cost (€/jour), occ}.
func parking_for(bid: int) -> Dictionary:
	var priv: Array = park_private.get(bid, [])
	if not priv.is_empty() and int(priv[1]) <= int(priv[0]):
		return {"search": 0.3, "walk": 0.5, "cost": 0.0, "occ": 0.0, "private": true}
	if not population.known.has(bid):
		return {"search": 1.0, "walk": 1.0, "cost": 0.0, "occ": 0.0}
	var c := _park_cell(bid)
	if not park_cells.has(c):
		return {"search": 1.0, "walk": 1.0, "cost": 0.0, "occ": 0.0}
	var pc: Dictionary = park_cells[c]
	return {"search": float(pc.search), "walk": float(pc.walk), "cost": float(pc.cost), "occ": float(pc.occ)}


## Quartier où se garent ceux qui vont au bâtiment bid (là où il touche la route).
func _park_cell(bid: int) -> Vector2i:
	var a := access_of(bid)
	if a.has("pos"):
		return cell_of(a.pos)
	return cell_of(population.known[bid].pos)


static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


# --- Stationnement ------------------------------------------------------------------

func _compute_parking(w: float) -> void:
	var net := transport.network
	var cells := {}
	# Places le long des trottoirs.
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		var per_m := float(CURB_PER_M.get(String(e.t), 0.0))
		if per_m <= 0.0:
			continue
		# Réparties le long de la rue, quartier par quartier.
		var pts: PackedVector3Array = e.pts
		var n_pts := pts.size()
		for i in n_pts:
			_cell(cells, cell_of(pts[i])).free += float(e.len) * per_m / n_pts
	# Parkings construits (gratuits ou payants).
	if transport.traffic != null:
		for node in transport.traffic.parkings:
			var pk: Dictionary = transport.traffic.parkings[node]
			var sid := int(pk.get("station", -1))
			var n := (pk.spots as Array).size()
			var c := cell_of(net.node_pos(int(node)))
			var fare := float(parking_fares.get(sid, 0.0))
			var cc := _cell(cells, c)
			if fare > 0.0:
				cc.fare = (float(cc.fare) * float(cc.paid) + fare * n) / maxf(1.0, float(cc.paid) + n)
				cc.paid += n
			else:
				cc.free += n
	# Arrivées : d'abord les places privées de l'entreprise, puis le quartier.
	park_private.clear()
	for bid in _acc.arrive:
		if not population.known.has(bid):
			continue
		var cars := int(_acc.arrive[bid])
		var own := floori(int(population.known[bid].get("emp", 0)) * PRIVATE_PER_JOB)
		park_private[bid] = [own, cars]
		var over := maxi(0, cars - own)
		if over > 0:
			_cell(cells, _park_cell(bid)).demand += over
	var paid_used := 0.0
	var revenue := 0.0
	for c in cells:
		var pc: Dictionary = cells[c]
		var supply := float(pc.free) + float(pc.paid)
		var dem := float(pc.demand)
		var occ := dem / supply if supply > 0.0 else (9.0 if dem > 0.0 else 0.0)
		var search := 0.5 + 6.0 * pow(clampf((occ - 0.75) / 0.25, 0.0, 1.0), 2.0)
		var walk := 1.0
		if occ > 1.0:
			search += 10.0 * (1.0 - 1.0 / occ)
			walk += 5.0 * (1.0 - 1.0 / occ)
		var paying := clampf(dem - float(pc.free), 0.0, float(pc.paid))
		var cost := float(pc.fare) * paying / dem if dem > 0.0 else 0.0
		paid_used += paying
		revenue += paying * float(pc.fare)
		var old: Dictionary = park_cells.get(c, {})
		pc.occ = occ
		pc.search = lerpf(float(old.get("search", search)), search, w)
		pc.walk = lerpf(float(old.get("walk", walk)), walk, w)
		pc.cost = cost
	park_cells = cells
	stats.parking_paid_used = paid_used
	stats.parking_revenue_day = revenue


func _cell(cells: Dictionary, c: Vector2i) -> Dictionary:
	if not cells.has(c):
		cells[c] = {"free": 0.0, "paid": 0.0, "fare": 0.0, "demand": 0.0, "occ": 0.0, "search": 0.5, "walk": 1.0, "cost": 0.0}
	return cells[c]


## Occupation d'un parking construit (0..1+), d'après son quartier.
func parking_occupancy(node: int) -> float:
	var c := cell_of(transport.network.node_pos(node))
	return float(park_cells.get(c, {}).get("occ", 0.0))


# --- Lignes ---------------------------------------------------------------------------

## Places d'un véhicule de ligne (avec ses remorques ou voitures).
static func places_of(model: String, kind: String) -> int:
	var t := VehicleCatalog.get_type(model)
	var n := int(t.get("places", 0))
	for w in t.get("consist", []):
		n += int(VehicleCatalog.get_type(String(w)).get("places", 0))
	if n <= 4:
		n = int(DEFAULT_PLACES.get(kind, 80))
	return n


func fare_of(lid: int) -> float:
	return float(fares.get(lid, DEFAULT_FARE))


func _compute_lines() -> void:
	var st := transport.stations
	line_load.clear()
	if st == null or st.planner == null:
		return
	var waits := {}
	var riders_total := 0
	var fare_day := 0.0
	for lid in st.lines:
		var l: Dictionary = st.lines[lid]
		if String(l.kind) == "camion":
			continue
		var info := st.planner._line_info(lid)
		if info.is_empty():
			continue
		var headway := float(info.wait) * 2.0
		var places := places_of(String(l.model), String(l.kind))
		var cap := float(places) * 3600.0 / maxf(30.0, headway)
		var riders := int(_acc.riders.get(lid, 0))
		var peak := riders * PEAK_SHARE
		var load := peak / cap if cap > 0.0 else 0.0
		# Plein : on laisse passer un ou plusieurs véhicules.
		var extra := headway * clampf(load - 1.0, 0.0, 3.0)
		if extra > 1.0:
			waits[lid] = extra
		line_load[lid] = {"riders": riders, "peak": peak, "cap": cap, "load": load, "headway": headway, "extra": extra, "places": places}
		riders_total += riders
		fare_day += riders * 2.0 * fare_of(lid) * 0.85 # moins de 18 ans gratuits (environ 15 %)
	var old: Dictionary = st.planner.extra_wait
	var moved := old.size() != waits.size()
	for k in waits:
		if absf(float(old.get(k, 0.0)) - float(waits[k])) > 30.0:
			moved = true
	st.planner.extra_wait = waits
	# Les bus prennent les bouchons : les temps des lignes sont recalculés.
	st.planner.invalidate()
	if moved:
		population._transit_cache.clear()
	stats.riders = riders_total
	stats.fare_day = fare_day


# --- Chiffres ---------------------------------------------------------------------------

func _compute_stats() -> void:
	var n := maxi(1, int(_acc.n))
	var n_car := maxi(1, int(_acc.n_car))
	stats.trips = int(_acc.n)
	stats.modes = (_acc.modes as Dictionary).duplicate()
	stats.avg_min = float(_acc.min) / n
	stats.avg_delay = float(_acc.delay) / n_car
	stats.avg_search = float(_acc.search) / n_car
	var jam_t := 0.0
	var free_t := 0.0
	for k in od_time:
		jam_t += float(od_time[k])
		free_t += float(od_free.get(k, od_time[k]))
	stats.jam_factor = jam_t / free_t if free_t > 0.0 else 1.0
	# Pires tronçons.
	var worst: Array = []
	for eid in transport.network.edges:
		var r := ratio(eid)
		if r >= 0.6:
			worst.append([r, eid])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	stats.worst = worst.slice(0, 10)
	var jammed := 0
	for it in worst:
		if float(it[0]) >= 1.0:
			jammed += 1
	stats.jammed = jammed
	var full := 0
	for c in park_cells:
		if float(park_cells[c].occ) > 1.0:
			full += 1
	stats.parking_full = full
	var curb := 0.0
	for c in park_cells:
		curb += float(park_cells[c].free) + float(park_cells[c].paid)
	stats.parking_places = curb


## Recettes du jour, une fois par jour de jeu (jours ouvrés : 5 sur 7).
func _daily() -> void:
	var n := population.now()
	var day := int(n.day)
	if _last_day < 0:
		_last_day = day
		return
	if day == _last_day:
		return
	_last_day = day
	if int(n.wd) == 0 or int(n.wd) == 6:
		return
	var tickets := float(stats.get("fare_day", 0.0))
	var parking := float(stats.get("parking_revenue_day", 0.0))
	_book("Tickets de transport", tickets)
	_book("Stationnement", parking)
	ledger.jours = int(ledger.jours) + 1
	if int(ledger.jours) >= 22:
		ledger.precedent = ledger.mois
		ledger.mois = {}
		ledger.jours = 0


func _book(poste: String, amount: float) -> void:
	if amount <= 0.0:
		return
	ledger.mois[poste] = float(ledger.mois.get(poste, 0.0)) + amount
	var b: Node = get_tree().get_first_node_in_group("budget_communal") if is_inside_tree() else null
	if b != null and b.has_method("recette"):
		b.call("recette", poste, amount)


## Coût mensuel d'exploitation des lignes (groupe « budget_entretien »).
func budget_entretien() -> Dictionary:
	var st := transport.stations if transport != null else null
	if st == null:
		return {}
	var total := 0.0
	for lid in st.lines:
		var l: Dictionary = st.lines[lid]
		total += float(RUN_COST.get(String(l.kind), 0.0)) * int(l.count)
	return {"Exploitation des lignes": total} if total > 0.0 else {}


## Recettes mensuelles estimées (tickets, stationnement).
func budget_recettes() -> Dictionary:
	return {"Tickets de transport": float(stats.get("fare_day", 0.0)) * 22.0,
		"Stationnement": float(stats.get("parking_revenue_day", 0.0)) * 22.0}


# --- Avis des habitants -----------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "trafic", "theme": "transports", "f": avis_de}]


## Effet des transports sur un habitant : [delta, raisons].
func avis_de(p: Dictionary) -> Array:
	var dest := _dest_of(p)
	var home := population.home_of(p)
	if dest < 0 or home < 0:
		return [0.0, []]
	var c := population.commute(p, home, dest)
	var d := 0.0
	var why := []
	if String(c.mode).begins_with("en voiture"):
		if float(c.get("delay", 0.0)) >= 8.0:
			d -= 6.0
			why.append("− bouchons tous les jours (%d min perdues)" % roundi(float(c.delay)))
		if float(c.get("park", 0.0)) >= 8.0:
			d -= 4.0
			why.append("− pas de place pour se garer")
	elif c.has("trip"):
		var crowded := false
		for leg in c.trip.get("legs", []):
			if String(leg.type) == "ligne" and float(line_load.get(int(leg.line), {}).get("load", 0.0)) > 1.0:
				crowded = true
		if crowded:
			d -= 5.0
			why.append("− %s bondé aux heures de pointe" % String(c.mode).trim_prefix("en "))
		elif int(c.min) <= 25:
			d += 3.0
			why.append("+ transports en commun pratiques")
	return [d, why]


# --- Fermetures (cortèges, travaux) -----------------------------------------------------

func fermer(eid: int, raison: String) -> void:
	if not transport.network.edges.has(eid):
		return
	closures[eid] = raison
	transport.network.closed_edges[eid] = raison
	_after_closure()


func rouvrir(eid: int) -> void:
	closures.erase(eid)
	transport.network.closed_edges.erase(eid)
	_after_closure()


func _after_closure() -> void:
	od_time.clear()
	_line_edges.clear()
	if transport.stations != null and transport.stations.planner != null:
		transport.stations.planner.invalidate()
	population._transit_cache.clear()


func set_bus_lane(eid: int, on: bool) -> void:
	if on:
		bus_lanes[eid] = true
	else:
		bus_lanes.erase(eid)
	_edge_cost.clear()
	if transport.stations != null and transport.stations.planner != null:
		transport.stations.planner.invalidate()
	population._transit_cache.clear()
	changed.emit()


# --- Flux pour les autres systèmes (pollution, bruit, usure) -----------------------------

## Véhicules par heure sur un tronçon (deux sens), à l'heure actuelle.
func flux(eid: int) -> float:
	return (edge_flow(eid)) * hour_profile(_hour())


## Véhicules par heure de pointe sur un tronçon (deux sens, bus compris).
func edge_flow(eid: int) -> float:
	return float(flow.get(eid * 2, 0.0)) + float(flow.get(eid * 2 + 1, 0.0)) + float(bus_flow.get(eid, 0.0))


func flux_all() -> Dictionary:
	var out := {}
	var h := hour_profile(_hour())
	for k in flow:
		out[int(k) >> 1] = float(out.get(int(k) >> 1, 0.0)) + float(flow[k]) * h
	for eid in bus_flow:
		out[eid] = float(out.get(eid, 0.0)) + float(bus_flow[eid]) * h
	return out


## Poids lourds par heure : bus des lignes et environ 5 % de camions.
func flux_lourds(eid: int) -> float:
	var q := float(flow.get(eid * 2, 0.0)) + float(flow.get(eid * 2 + 1, 0.0))
	return (q * 0.05 + float(bus_flow.get(eid, 0.0))) * hour_profile(_hour())


# --- Sauvegarde -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var f := {}
	for k in fares:
		f[str(k)] = fares[k]
	var pf := {}
	for k in parking_fares:
		pf[str(k)] = parking_fares[k]
	var cl := {}
	for k in closures:
		cl[str(k)] = closures[k]
	return {"v": 1, "tarifs": f, "parkings": pf, "voies_bus": bus_lanes.keys(), "fermetures": cl,
		"comptes": ledger, "bouchons_visibles": visible_jams}


func from_dict(d: Dictionary) -> void:
	clear()
	for k in d.get("tarifs", {}):
		fares[int(k)] = float(d.tarifs[k])
	for k in d.get("parkings", {}):
		parking_fares[int(k)] = float(d.parkings[k])
	for e in d.get("voies_bus", []):
		if transport.network.edges.has(int(e)):
			bus_lanes[int(e)] = true
	for k in d.get("fermetures", {}):
		if transport.network.edges.has(int(k)):
			closures[int(k)] = String(d.fermetures[k])
			transport.network.closed_edges[int(k)] = String(d.fermetures[k])
	var l: Dictionary = d.get("comptes", {})
	ledger = {"mois": l.get("mois", {}), "precedent": l.get("precedent", {}), "jours": int(l.get("jours", 0))}
	visible_jams = bool(d.get("bouchons_visibles", true))
