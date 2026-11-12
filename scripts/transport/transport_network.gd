class_name TransportNetwork
extends RefCounted
## Graphe commun à tous les réseaux de transport.
##
## - Nœud : un point (carrefour, extrémité, gare plus tard) avec un mode (route, rail…).
## - Tronçon : relie deux nœuds du même mode. Il garde son tracé échantillonné
##   tous les ~2 m (positions 3D + structure : sol, pont, tunnel, eau), ce qui
##   permettra plus tard les courbes sans changer le format.
##
## Tout est sérialisable en dictionnaire JSON (sauvegarde et futur multijoueur).

signal changed

## id -> {"p": Vector3, "m": int}
var nodes: Dictionary = {}
## id -> {"a": int, "b": int, "t": String, "pts": PackedVector3Array,
##        "st": PackedByteArray, "d": PackedFloat32Array (distances cumulées), "len": float}
var edges: Dictionary = {}
## id de nœud -> Array d'id de tronçons
var adjacency: Dictionary = {}
var next_id := 1


func clear() -> void:
	nodes.clear()
	edges.clear()
	adjacency.clear()
	next_id = 1
	changed.emit()


# --- Construction --------------------------------------------------------------

func add_node(p: Vector3, mode: int) -> int:
	var id := next_id
	next_id += 1
	nodes[id] = {"p": p, "m": mode}
	adjacency[id] = []
	return id


func node_pos(id: int) -> Vector3:
	return nodes[id].p


func node_mode(id: int) -> int:
	return int(nodes[id].m)


func degree(id: int) -> int:
	return (adjacency.get(id, []) as Array).size()


## Ajoute un tronçon. Les extrémités du tracé sont recollées sur les nœuds.
func add_edge(a: int, b: int, type_id: String, pts: PackedVector3Array, st: PackedByteArray, spec: Dictionary = {}) -> int:
	assert(pts.size() >= 2 and pts.size() == st.size())
	pts[0] = node_pos(a)
	pts[pts.size() - 1] = node_pos(b)
	var id := next_id
	next_id += 1
	type_id = TransportTypes.resolve(type_id)
	var e := {"a": a, "b": b, "t": type_id, "pts": pts, "st": st, "w": TransportTypes.normalize(type_id, spec)}
	_measure(e)
	edges[id] = e
	(adjacency[a] as Array).append(id)
	(adjacency[b] as Array).append(id)
	return id


static func _measure(e: Dictionary) -> void:
	var pts: PackedVector3Array = e.pts
	var d := PackedFloat32Array()
	d.resize(pts.size())
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		d[i] = acc
	e.d = d
	e.len = acc
	e.width = TransportTypes.width_of(e.t, e.get("w", {}))


func half_width(edge_id: int) -> float:
	return float(edges[edge_id].width) * 0.5


## Demi-largeur de la plus large voie qui touche le nœud.
func node_half_width(id: int) -> float:
	var hw := 0.0
	for eid in adjacency.get(id, []):
		hw = maxf(hw, half_width(eid))
	return hw


## Supprime un tronçon et les nœuds devenus isolés.
func remove_edge(id: int) -> void:
	if not edges.has(id):
		return
	var e: Dictionary = edges[id]
	edges.erase(id)
	for n in [e.a, e.b]:
		var adj: Array = adjacency.get(n, [])
		adj.erase(id)
		if adj.is_empty():
			nodes.erase(n)
			adjacency.erase(n)


## Coupe un tronçon à la distance s : renvoie le nœud créé (ou l'extrémité
## existante si s est tout près d'un bout).
func split_edge(id: int, s: float, snap := 1.5) -> int:
	var e: Dictionary = edges[id]
	if s <= snap:
		return e.a
	if s >= float(e.len) - snap:
		return e.b
	var p := point_at(id, s)
	var mid := add_node(p, node_mode(e.a))
	var first := slice(e, 0.0, s)
	var second := slice(e, s, e.len)
	var a: int = e.a
	var b: int = e.b
	var t: String = e.t
	var spec: Dictionary = e.w
	var keep_a: Dictionary = nodes[a].duplicate()
	var keep_b: Dictionary = nodes[b].duplicate()
	remove_edge(id)
	# remove_edge efface a ou b s'ils n'avaient que ce tronçon : on les remet.
	if not nodes.has(a):
		nodes[a] = keep_a
		adjacency[a] = []
	if not nodes.has(b):
		nodes[b] = keep_b
		adjacency[b] = []
	add_edge(a, mid, t, first[0], first[1], spec)
	add_edge(mid, b, t, second[0], second[1], spec)
	return mid


## Extrait le morceau [s0, s1] du tracé d'un tronçon : [pts, st].
static func slice(e: Dictionary, s0: float, s1: float) -> Array:
	return slice_polyline(e.pts, e.st, e.d, s0, s1)


static func slice_polyline(pts: PackedVector3Array, st: PackedByteArray, d: PackedFloat32Array, s0: float, s1: float) -> Array:
	var out_p := PackedVector3Array()
	var out_s := PackedByteArray()
	out_p.append(_interp(pts, d, s0))
	out_s.append(st[_index_at(d, s0)])
	for i in pts.size():
		if d[i] > s0 + 0.05 and d[i] < s1 - 0.05:
			out_p.append(pts[i])
			out_s.append(st[i])
	out_p.append(_interp(pts, d, s1))
	out_s.append(st[mini(_index_at(d, s1) + 1, st.size() - 1)] if s1 < d[d.size() - 1] else st[st.size() - 1])
	return [out_p, out_s]


static func _index_at(d: PackedFloat32Array, s: float) -> int:
	var i := d.bsearch(s, true) - 1
	return clampi(i, 0, d.size() - 2)


static func _interp(pts: PackedVector3Array, d: PackedFloat32Array, s: float) -> Vector3:
	var i := _index_at(d, s)
	var span := d[i + 1] - d[i]
	var u := 0.0 if span <= 0.0 else clampf((s - d[i]) / span, 0.0, 1.0)
	return pts[i].lerp(pts[i + 1], u)


# --- Lecture du tracé ------------------------------------------------------------

func point_at(id: int, s: float) -> Vector3:
	var e: Dictionary = edges[id]
	return _interp(e.pts, e.d, clampf(s, 0.0, e.len))


func tangent_at(id: int, s: float) -> Vector3:
	var e: Dictionary = edges[id]
	var i := _index_at(e.d, clampf(s, 0.0, e.len))
	var pts: PackedVector3Array = e.pts
	var t := pts[i + 1] - pts[i]
	return t.normalized() if t.length_squared() > 1e-8 else Vector3.FORWARD


## Direction horizontale vers l'extérieur du nœud node_id, au point s du
## tronçon (sur une courbe, elle diffère de leave_dir, prise au nœud).
func out_dir_at(edge_id: int, node_id: int, s: float) -> Vector3:
	var e: Dictionary = edges[edge_id]
	var from_a: bool = e.a == node_id
	var t := tangent_at(edge_id, s + 0.05 if from_a else s - 0.05)
	if not from_a:
		t = -t
	t.y = 0.0
	return t.normalized() if t.length_squared() > 1e-8 else leave_dir(edge_id, node_id)


func struct_at(id: int, s: float) -> int:
	var e: Dictionary = edges[id]
	var i := _index_at(e.d, clampf(s, 0.0, e.len))
	var st: PackedByteArray = e.st
	var mid: float = (float(e.d[i]) + float(e.d[i + 1])) * 0.5
	return st[i] if s <= mid else st[i + 1]


## Point du tronçon le plus proche de p (dans le plan horizontal).
func nearest_on_edge(id: int, p: Vector3) -> Dictionary:
	var e: Dictionary = edges[id]
	var pts: PackedVector3Array = e.pts
	var d: PackedFloat32Array = e.d
	var best := {"dist": INF, "s": 0.0, "pos": pts[0]}
	var q := Vector2(p.x, p.z)
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var ab := b - a
		var u := 0.0
		if ab.length_squared() > 1e-8:
			u = clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var dist := q.distance_to(a + ab * u)
		if dist < best.dist:
			var s := lerpf(d[i], d[i + 1], u)
			best = {"dist": dist, "s": s, "pos": pts[i].lerp(pts[i + 1], u)}
	return best


## Accroche : nœud proche, sinon point d'une voie proche, du même mode.
## margin : distance au-delà du bord de la voie (on accroche en cliquant sur la chaussée).
## Renvoie {"node": id ou -1, "edge": id ou -1, "s": float, "pos": Vector3} ou {}.
func find_snap(p: Vector3, mode: int, margin: float) -> Dictionary:
	var best_node := -1
	var best_d := INF
	for id in nodes:
		if node_mode(id) != mode:
			continue
		var np := node_pos(id)
		var dd := Vector2(np.x - p.x, np.z - p.z).length()
		if dd <= node_half_width(id) + margin + 1.0 and dd < best_d:
			best_d = dd
			best_node = id
	if best_node >= 0:
		return {"node": best_node, "edge": -1, "s": 0.0, "pos": node_pos(best_node)}
	var best_edge := -1
	var best_hit := {}
	best_d = INF
	for id in edges:
		if TransportTypes.mode_of(edges[id].t) != mode:
			continue
		var hit := nearest_on_edge(id, p)
		if hit.dist <= half_width(id) + margin and hit.dist < best_d:
			best_d = hit.dist
			best_edge = id
			best_hit = hit
	if best_edge >= 0:
		return {"node": -1, "edge": best_edge, "s": best_hit.s, "pos": best_hit.pos}
	return {}


## Angle (degrés) au-delà duquel deux tronçons se suivent « tout droit ».
const SMOOTH_JOINT := 150.0
## Bretelles : angle maximal avec la voie principale (insertion ou sortie).
const MERGE_ANGLE := 40.0


## Insertion ou sortie d'autoroute : deux tronçons d'une classe à bretelles dans
## le prolongement l'un de l'autre, et en plus seulement des bretelles presque
## parallèles. Renvoie les deux tronçons de la voie principale, ou [].
func merge_through(nid: int) -> Array:
	var adj: Array = adjacency.get(nid, [])
	if adj.size() < 3:
		return []
	var main: Array = []
	for eid in adj:
		var t: String = edges[eid].t
		if TransportTypes.is_ramp(t):
			continue
		if not TransportTypes.takes_ramps(t):
			return []
		main.append(eid)
	if main.size() != 2 or main[0] == main[1]:
		return []
	var d0 := leave_dir(main[0], nid)
	var d1 := leave_dir(main[1], nid)
	if rad_to_deg(acos(clampf(d0.dot(d1), -1.0, 1.0))) < SMOOTH_JOINT:
		return []
	var lim := cos(deg_to_rad(MERGE_ANGLE))
	for eid in adj:
		if main.has(eid):
			continue
		var d := leave_dir(eid, nid)
		if maxf(d.dot(d0), d.dot(d1)) < lim:
			return []
	return main


func is_merge(nid: int) -> bool:
	return not merge_through(nid).is_empty()


## Direction (horizontale) par laquelle un tronçon quitte un nœud.
func leave_dir(edge_id: int, node_id: int) -> Vector3:
	var e: Dictionary = edges[edge_id]
	var pts: PackedVector3Array = e.pts
	var n := pts.size()
	var v: Vector3
	if e.a == node_id:
		v = pts[mini(2, n - 1)] - pts[0]
	else:
		v = pts[maxi(n - 3, 0)] - pts[n - 1]
	v.y = 0.0
	return v.normalized() if v.length_squared() > 1e-8 else Vector3.FORWARD


# --- Itinéraires ------------------------------------------------------------------

func other_end(edge_id: int, node_id: int) -> int:
	var e: Dictionary = edges[edge_id]
	return e.b if e.a == node_id else e.a


## Plus court chemin (A*) entre deux nœuds. Renvoie la liste des tronçons à
## parcourir, dans l'ordre, ou [] si les nœuds ne sont pas reliés.
## On cherche sur les couples (nœud, tronçon d'arrivée) pour respecter les
## mouvements interdits : sens uniques, et aux bretelles d'autoroute, pas de
## demi-tour par-dessus le terre-plein.
func find_route(from: int, to: int) -> Array[int]:
	var result: Array[int] = []
	if from == to or not nodes.has(from) or not nodes.has(to):
		return result
	var goal := node_pos(to)
	var start := Vector2i(from, -1)
	var g := {start: 0.0}
	var came := {} # état -> [état précédent, tronçon]
	var open := {start: node_pos(from).distance_to(goal)}
	var closed := {}
	var merges := {}
	var found: Variant = null
	while not open.is_empty():
		var cur: Vector2i = start
		var best := INF
		for k in open:
			if open[k] < best:
				best = open[k]
				cur = k
		if cur.x == to:
			found = cur
			break
		open.erase(cur)
		closed[cur] = true
		for eid in adjacency.get(cur.x, []):
			var nxt := other_end(eid, cur.x)
			if edges[eid].a != cur.x and TransportTypes.is_oneway(edges[eid].t):
				continue
			if cur.y >= 0 and not _turn_ok(cur.x, cur.y, eid, merges):
				continue
			var st := Vector2i(nxt, eid)
			if closed.has(st):
				continue
			var cost: float = g[cur] + float(edges[eid].len)
			if cost < float(g.get(st, INF)):
				g[st] = cost
				came[st] = [cur, eid]
				open[st] = cost + node_pos(nxt).distance_to(goal)
	if found == null:
		return result
	var k: Vector2i = found
	while k != start:
		var c: Array = came[k]
		result.push_front(int(c[1]))
		k = c[0]
	return result


## Mouvement autorisé au nœud nid, en arrivant par in_eid et en repartant par
## out_eid ? Aux insertions d'autoroute, on ne tourne pas de plus de 90°.
func _turn_ok(nid: int, in_eid: int, out_eid: int, cache: Dictionary) -> bool:
	if not cache.has(nid):
		cache[nid] = is_merge(nid)
	if not cache[nid]:
		return true
	if in_eid == out_eid:
		return false
	var arrive := -leave_dir(in_eid, nid)
	return arrive.dot(leave_dir(out_eid, nid)) > 0.0


## Nœuds atteignables depuis start (même composante connexe).
func component(start: int) -> Array[int]:
	var seen := {start: true}
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var n: int = stack.pop_back()
		for eid in adjacency.get(n, []):
			var o := other_end(eid, n)
			if not seen.has(o):
				seen[o] = true
				stack.append(o)
	var out: Array[int] = []
	for k in seen:
		out.append(k)
	return out


func total_length(mode: int) -> float:
	var t := 0.0
	for id in edges:
		if TransportTypes.mode_of(edges[id].t) == mode:
			t += float(edges[id].len)
	return t


func nodes_of_mode(mode: int) -> Array[int]:
	var out: Array[int] = []
	for id in nodes:
		if node_mode(id) == mode and degree(id) > 0:
			out.append(id)
	return out


# --- Sauvegarde ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ns := []
	for id in nodes:
		var p := node_pos(id)
		ns.append([id, snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), node_mode(id)])
	var es := []
	for id in edges:
		var e: Dictionary = edges[id]
		var flat := []
		for p in (e.pts as PackedVector3Array):
			flat.append_array([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
		es.append({"id": id, "a": e.a, "b": e.b, "t": e.t, "w": e.w, "p": flat, "s": Array(e.st as PackedByteArray)})
	return {"version": 1, "next_id": next_id, "nodes": ns, "edges": es}


func from_dict(data: Dictionary) -> void:
	nodes.clear()
	edges.clear()
	adjacency.clear()
	for n in data.get("nodes", []):
		var id := int(n[0])
		nodes[id] = {"p": Vector3(float(n[1]), float(n[2]), float(n[3])), "m": int(n[4])}
		adjacency[id] = []
	for ed in data.get("edges", []):
		var pts := PackedVector3Array()
		var flat: Array = ed.p
		for i in range(0, flat.size() - 2, 3):
			pts.append(Vector3(float(flat[i]), float(flat[i + 1]), float(flat[i + 2])))
		var st := PackedByteArray()
		for v in ed.s:
			st.append(int(v))
		var id := int(ed.id)
		var a := int(ed.a)
		var b := int(ed.b)
		if not nodes.has(a) or not nodes.has(b) or pts.size() < 2 or pts.size() != st.size():
			continue
		var t := TransportTypes.resolve(String(ed.t))
		if TransportTypes.get_type(t).is_empty():
			continue
		var e := {"a": a, "b": b, "t": t, "pts": pts, "st": st, "w": TransportTypes.normalize(t, ed.get("w", {}))}
		_measure(e)
		edges[id] = e
		(adjacency[a] as Array).append(id)
		(adjacency[b] as Array).append(id)
	next_id = int(data.get("next_id", 1))
	for id in nodes:
		next_id = maxi(next_id, int(id) + 1)
	for id in edges:
		next_id = maxi(next_id, int(id) + 1)
	changed.emit()
