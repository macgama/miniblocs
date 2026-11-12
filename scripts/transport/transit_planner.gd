class_name TransitPlanner
extends RefCounted
## Calcul d'itinéraires en transports publics, pour les habitants.
##
## Un trajet = marche jusqu'à une station, une ou plusieurs lignes (avec
## correspondances à pied entre stations proches), puis marche jusqu'à
## l'arrivée. Le planificateur compare avec la marche seule et garde le plus
## rapide. Les durées sont estimées : longueur réelle des voies parcourues,
## vitesse du modèle de la ligne (et de la voie), attente moyenne (demi-intervalle
## entre deux véhicules) et arrêt en station.
##
## Utilisation :
##   var trip := transport.stations.planner.plan(depart, arrivee)
##   trip.ok, trip.total_s, trip.legs : [{type: "marche" | "ligne", ...}]
##   transport.stations.planner.board(trip)   # compte les voyageurs des lignes

## Marche : vitesse (m/s), détour moyen par rapport à la ligne droite.
const WALK_SPEED := 1.3
const WALK_DETOUR := 1.3
## Distance maximale à pied jusqu'à une station, et pour une correspondance (m).
const WALK_TO_STATION := 800.0
const TRANSFER_WALK := 250.0
## Pénalité d'une correspondance (s), en plus de la marche et de l'attente.
const TRANSFER_PENALTY := 120.0

var stations: StationSystem
## id de ligne -> {"hops": Array (temps entre arrêts successifs, s), "wait": s}
var _cache: Dictionary = {}


func _init(s: StationSystem) -> void:
	stations = s
	s.lines_changed.connect(invalidate)
	s.network.changed.connect(invalidate)


func invalidate() -> void:
	_cache.clear()


## Stations à moins de radius mètres de p (à vol d'oiseau), les plus proches
## d'abord. kind : genre de ligne ("bus", "metro"…), "" pour toutes.
func stations_near(p: Vector3, radius := WALK_TO_STATION, kind := "") -> Array[int]:
	var found: Array = []
	for sid in stations.stations:
		var s: Dictionary = stations.stations[sid]
		var k: String = StationSystem.get_type(s.type).kind
		if k == "parking" or k == "camion" or (kind != "" and k != kind):
			continue
		var d := _flat_dist(p, s.pos)
		if d <= radius:
			found.append([d, sid])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[int] = []
	for f in found:
		out.append(int(f[1]))
	return out


## Lignes de voyageurs qui desservent une station (le fret est exclu).
func lines_at(sid: int) -> Array[int]:
	var out: Array[int] = []
	for lid in stations.lines:
		var l: Dictionary = stations.lines[lid]
		if not bool(l.get("fret", false)) and (l.stops as Array).has(sid):
			out.append(lid)
	return out


## Temps de marche estimé entre deux points (s).
static func walk_time(a: Vector3, b: Vector3) -> float:
	return _flat_dist(a, b) * WALK_DETOUR / WALK_SPEED


## Meilleur trajet de a à b. Renvoie {ok, reason, total_s, walk_only_s, legs}.
## Chaque étape : {type: "marche", from: Vector3, to: Vector3, s: float}
## ou {type: "ligne", line: int, name: String, kind: String, from: int, to: int,
## stops: int, wait_s: float, ride_s: float, s: float}.
func plan(a: Vector3, b: Vector3) -> Dictionary:
	var walk_only := walk_time(a, b)
	var res := {"ok": true, "reason": "", "total_s": walk_only, "walk_only_s": walk_only,
		"legs": [{"type": "marche", "from": a, "to": b, "s": walk_only}]}
	var starts := stations_near(a)
	var ends := stations_near(b)
	if starts.is_empty() or ends.is_empty():
		res.reason = "Pas de station à moins de %d m : à pied." % roundi(WALK_TO_STATION)
		return res
	# Dijkstra sur les stations. État : station ; arc : un trajet sur une ligne
	# entre deux de ses arrêts, ou une correspondance à pied.
	var best := {}
	var prev := {}
	var open := {}
	for sid in starts:
		var t := walk_time(a, stations.stations[sid].pos)
		best[sid] = t
		prev[sid] = {"type": "marche_depart"}
		open[sid] = t
	var end_set := {}
	for sid in ends:
		end_set[sid] = true
	var done := {}
	while not open.is_empty():
		var cur := -1
		var cur_t := INF
		for sid in open:
			if float(open[sid]) < cur_t:
				cur_t = open[sid]
				cur = sid
		open.erase(cur)
		done[cur] = true
		if cur_t > res.total_s:
			break
		# Les lignes au départ de cette station.
		for lid in lines_at(cur):
			var info := _line_info(lid)
			if info.is_empty():
				continue
			var stops: Array = stations.lines[lid].stops
			var i0 := stops.find(cur)
			var penalty := float(info.wait) + (TRANSFER_PENALTY if String(prev[cur].type) != "marche_depart" else 0.0)
			for dir in [-1, 1]:
				var ride := 0.0
				var j := i0
				while true:
					var nj: int = j + int(dir)
					if nj < 0 or nj >= stops.size():
						break
					ride += float((info.hops as Array)[mini(j, nj)])
					j = nj
					var nxt: int = stops[j]
					var t: float = cur_t + penalty + ride
					if t < float(best.get(nxt, INF)) and not done.has(nxt):
						best[nxt] = t
						prev[nxt] = {"type": "ligne", "line": lid, "from": cur, "stops": absi(j - i0), "wait_s": float(info.wait), "ride_s": ride, "pen": penalty}
						open[nxt] = t
		# Correspondances à pied vers les stations voisines.
		for o in stations_near(stations.stations[cur].pos, TRANSFER_WALK):
			if o == cur or done.has(o):
				continue
			var t2 := cur_t + walk_time(stations.stations[cur].pos, stations.stations[o].pos)
			if t2 < float(best.get(o, INF)):
				best[o] = t2
				prev[o] = {"type": "marche_station", "from": cur}
				open[o] = t2
	# Meilleure station d'arrivée.
	var best_end := -1
	var best_total: float = res.total_s
	for sid in ends:
		if best.has(sid) and String(prev[sid].type) != "marche_depart":
			var tt: float = float(best[sid]) + walk_time(stations.stations[sid].pos, b)
			if tt < best_total:
				best_total = tt
				best_end = sid
	if best_end < 0:
		res.reason = "À pied, c'est plus rapide."
		return res
	# Reconstitution des étapes.
	var legs: Array = []
	var last_b := walk_time(stations.stations[best_end].pos, b)
	legs.push_front({"type": "marche", "from": stations.stations[best_end].pos, "to": b, "s": last_b})
	var cur2 := best_end
	while String(prev[cur2].type) != "marche_depart":
		var p: Dictionary = prev[cur2]
		if String(p.type) == "ligne":
			var l: Dictionary = stations.lines[int(p.line)]
			legs.push_front({"type": "ligne", "line": int(p.line), "name": String(l.name), "kind": String(l.kind),
				"from": int(p.from), "to": cur2, "stops": int(p.stops), "wait_s": float(p.wait_s), "ride_s": float(p.ride_s),
				"s": float(p.pen) + float(p.ride_s)})
		else:
			legs.push_front({"type": "marche", "from": stations.stations[int(p.from)].pos, "to": stations.stations[cur2].pos,
				"s": walk_time(stations.stations[int(p.from)].pos, stations.stations[cur2].pos)})
		cur2 = int(p.from)
	legs.push_front({"type": "marche", "from": a, "to": stations.stations[cur2].pos, "s": walk_time(a, stations.stations[cur2].pos)})
	res.legs = legs
	res.total_s = best_total
	res.reason = ""
	return res


## Compte les voyageurs d'un trajet sur ses lignes (statistiques des lignes).
func board(trip: Dictionary, people := 1) -> void:
	for leg in trip.get("legs", []):
		if String(leg.type) == "ligne" and stations.lines.has(int(leg.line)):
			var l: Dictionary = stations.lines[int(leg.line)]
			l.passengers = int(l.get("passengers", 0)) + people


## Résumé lisible d'un trajet : « 4 min à pied, Bus 1 (3 arrêts), 2 min à pied — 14 min ».
func describe(trip: Dictionary) -> String:
	var parts: Array[String] = []
	for leg in trip.get("legs", []):
		if String(leg.type) == "marche":
			if float(leg.s) >= 30.0:
				parts.append("%s à pied" % _minutes(float(leg.s)))
		else:
			parts.append("%s de %s à %s (%d arrêt%s)" % [leg.name, stations.stations[int(leg.from)].name,
				stations.stations[int(leg.to)].name, int(leg.stops), "s" if int(leg.stops) > 1 else ""])
	return "%s — %s" % [", ".join(parts), _minutes(float(trip.get("total_s", 0.0)))]


static func _minutes(s: float) -> String:
	if s < 3600.0:
		return "%d min" % maxi(1, roundi(s / 60.0))
	return "%d h %02d" % [floori(s / 3600.0), roundi(fmod(s, 3600.0) / 60.0)]


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Durée de chaque saut entre arrêts successifs d'une ligne, et attente moyenne.
func _line_info(lid: int) -> Dictionary:
	if _cache.has(lid):
		return _cache[lid]
	var l: Dictionary = stations.lines[lid]
	var stops: Array = l.stops
	var vt := VehicleCatalog.get_type(String(l.model))
	var vmax := float(vt.get("kmh", 50.0)) / 3.6
	var hops: Array = []
	var total := 0.0
	for i in stops.size() - 1:
		var sa: Dictionary = stations.stations[int(stops[i])]
		var sb: Dictionary = stations.stations[int(stops[i + 1])]
		var t := 0.0
		if String(l.kind) == "avion":
			t = _flat_dist(sa.pos, sb.pos) / minf(vmax, 110.0) + 60.0
		else:
			var route := stations.network.find_route(int(sa.node), int(sb.node))
			if route.is_empty():
				_cache[lid] = {}
				return {}
			for eid in route:
				var e: Dictionary = stations.network.edges[eid]
				t += float(e.len) / maxf(1.0, minf(vmax, TransportTypes.speed_of(e.t)))
			# Freinage, accélération et arrêt en station.
			t = t * 1.15 + StationSystem.DWELL
		hops.append(t)
		total += t
	# Aller-retour d'un véhicule, réparti entre les véhicules de la ligne.
	var headway := total * 2.0 / maxf(1.0, float(l.count))
	var info := {"hops": hops, "wait": headway * 0.5}
	_cache[lid] = info
	return info
