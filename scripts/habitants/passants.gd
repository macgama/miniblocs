class_name Passants
extends Node3D
## Les habitants visibles : près de la caméra, chaque habitant en trajet est
## dessiné là où sa journée le place (Population.day_plan). Il sort de chez
## lui, suit les voies (sur le trottoir à pied, sur la chaussée en voiture ou
## à vélo), arrive au travail, à l'école, au sport… au rythme de l'horloge.
##
## - Itinéraires : du bâtiment de départ à la voie la plus proche, puis plus
##   court chemin sur le réseau routier (TransportNetwork.find_route), puis
##   jusqu'au bâtiment d'arrivée. Mis en cache par paire de bâtiments.
## - Seuls les habitants qui vivent, travaillent ou étudient près de la caméra
##   sont examinés (plus l'habitant suivi, toujours).
## - Clic sur un passant : Population.person_clicked.

const MAX_AGENTS := 300
## Temps maximal par image pour faire apparaître de nouveaux passants (µs) : quand
## beaucoup partent en même temps, les suivants apparaissent aux images d'après.
const BUDGET_US := 3000
const SIDEWALK := 1.2
const LANE := 1.7

var pop: Population
## pid → {body: Node3D (Silhouettes à pied, MeshInstance3D sinon), mode: String, path: PackedVector3Array, d: PackedFloat32Array, s0, s1}
var agents: Dictionary = {}
var _routes: Dictionary = {}
var _plans: Dictionary = {}
var _cand: Array = []
var _cand_timer := 0.0
var _net_sig := -1
var _material: StandardMaterial3D
var _meshes: Dictionary = {}
## Affichage actif (désactivé dans certains tests ou si le joueur le coupe).
var enabled := true


func setup(p: Population) -> void:
	pop = p
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.85


func clear() -> void:
	for pid in agents:
		(agents[pid].body as Node).queue_free()
	agents.clear()
	_plans.clear()
	_routes.clear()
	_cand.clear()


## L'emploi du temps d'un habitant a changé (ordre donné, déménagement…).
func forget(pid: int) -> void:
	_plans.erase(pid)


func count_mode(kind: String) -> int:
	var n := 0
	for pid in agents:
		if (agents[pid].body as Node3D).visible and String(agents[pid].mode) == kind:
			n += 1
	return n


func _process(delta: float) -> void:
	if pop == null:
		return
	if not enabled:
		if not agents.is_empty():
			clear()
		return
	_cand_timer -= delta
	if _cand_timer <= 0.0:
		_cand_timer = 0.5
		_collect()
	_update()


func _focus() -> Vector3:
	if pop.rig != null:
		return pop.rig.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


func _radius() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 400.0
	return clampf((cam.global_position - _focus()).length() * 2.5, 150.0, 700.0)


## Habitants qui vivent, travaillent ou étudient près de la caméra.
func _collect() -> void:
	var tr := pop.transport
	if tr != null:
		var sig := tr.network.next_id * 100003 + tr.network.edges.size()
		if sig != _net_sig:
			_net_sig = sig
			_routes.clear()
	var o := _focus()
	var r := _radius()
	var seen := {}
	var out := []
	for bid in pop.known:
		var p: Vector3 = pop.known[bid].pos
		if Vector2(p.x - o.x, p.z - o.z).length() > r:
			continue
		for hid in pop.by_home.get(bid, []):
			for m in pop.households[hid].m:
				if not seen.has(m):
					seen[m] = true
					out.append(m)
		for m in pop.by_job.get(bid, []):
			if not seen.has(m):
				seen[m] = true
				out.append(m)
		for m in pop.by_school.get(bid, []):
			if not seen.has(m):
				seen[m] = true
				out.append(m)
		if out.size() > 2000:
			break
	var f := pop.followed()
	if f >= 0 and not seen.has(f):
		out.append(f)
	_cand = out


func _plan_of(pid: int, n: Dictionary) -> Array:
	var c: Array = _plans.get(pid, [])
	if not c.is_empty() and int(c[0]) == int(n.day):
		return c[1]
	var plan := pop.day_plan(pop.persons[pid], n)
	_plans[pid] = [int(n.day), plan]
	return plan


func _update() -> void:
	var t0 := Time.get_ticks_usec()
	var n := pop.now()
	var h: float = n.h
	var live := {}
	for pid in _cand:
		if live.size() >= MAX_AGENTS:
			break
		if not pop.persons.has(pid) or pop.incarnated() == pid:
			continue
		var over := Time.get_ticks_usec() - t0 > BUDGET_US
		var c: Array = _plans.get(pid, [])
		if over and (c.is_empty() or int(c[0]) != int(n.day)):
			# Plan du jour pas encore calculé : à une prochaine image.
			if agents.has(pid):
				live[pid] = true
			continue
		var plan := _plan_of(pid, n)
		for i in plan.size():
			var seg: Array = plan[i]
			if h < float(seg[0]) or h >= float(seg[1]):
				continue
			if String(seg[2]) == "trajet" and i > 0:
				var from := int(plan[i - 1][3])
				var to := int(seg[3])
				if pop.known.has(from) and pop.known.has(to) and from != to:
					var mode := _mode_of(String(seg[4]))
					var t := clampf((h - float(seg[0])) / maxf(float(seg[1]) - float(seg[0]), 0.0001), 0.0, 1.0)
					var a: Dictionary = agents.get(pid, {})
					var nouveau := a.is_empty() or int(a.from) != from or int(a.to) != to or String(a.mode) != mode
					if nouveau and Time.get_ticks_usec() - t0 > BUDGET_US:
						# Trop de départs à la fois : il apparaîtra à une prochaine image.
						if not a.is_empty():
							live[pid] = true
					else:
						_show(pid, from, to, mode, t)
						live[pid] = true
			break
	for pid in agents.keys():
		if not live.has(pid):
			(agents[pid].body as Node).queue_free()
			agents.erase(pid)


static func _mode_of(text: String) -> String:
	if text.contains("voiture"):
		return "voiture"
	if text.contains("vélo"):
		return "velo"
	return "pied"


func _show(pid: int, from: int, to: int, mode: String, t: float) -> void:
	var a: Dictionary = agents.get(pid, {})
	if a.is_empty() or int(a.from) != from or int(a.to) != to or String(a.mode) != mode:
		if not a.is_empty():
			(a.body as Node).queue_free()
		var mi: Node3D
		if mode == "pied" and Silhouettes.disponible():
			# Personnage arrondi, avec l'apparence de l'habitant.
			mi = Silhouettes.pour_habitant(pop, pid)
		else:
			var m3 := MeshInstance3D.new()
			m3.material_override = _material
			m3.mesh = _mesh_for(pid, mode)
			m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi = m3
		add_child(mi)
		var route := route_between(from, to, mode)
		a = {"body": mi, "mode": mode, "from": from, "to": to, "path": route.path, "d": route.d}
		agents[pid] = a
	var pd: PackedFloat32Array = a.d
	var path: PackedVector3Array = a.path
	if path.size() < 2:
		return
	var total := pd[pd.size() - 1]
	var s := t * total
	var i := 0
	while i < pd.size() - 2 and pd[i + 1] < s:
		i += 1
	var seg_len := maxf(pd[i + 1] - pd[i], 0.0001)
	var pos := path[i].lerp(path[i + 1], clampf((s - pd[i]) / seg_len, 0.0, 1.0))
	var dir := path[i + 1] - path[i]
	dir.y = 0.0
	var body: Node3D = a.body
	body.position = pos
	if body.has_meta("rig"):
		Silhouettes.marcher(body, s * 2.6, 1.0)
	if dir.length_squared() > 0.0001:
		body.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	# Le marcheur suivi est un peu plus grand, pour le repérer.
	body.scale = Vector3.ONE * (1.4 if pid == pop.followed() else 1.0)


func _mesh_for(pid: int, mode: String) -> Mesh:
	var key := "walker_%d" % (pid % 5)
	if mode == "voiture":
		key = "car_%d" % (pid % 6)
	elif mode == "velo":
		key = "bike_%d" % (pid % 4)
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh = null
	if pop.transport != null and pop.transport.traffic != null:
		m = pop.transport.traffic._mesh(key)
	if m == null:
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 1.7, 0.4)
		m = b
	_meshes[key] = m
	return m


# --- Itinéraires --------------------------------------------------------------------

## Chemin entre deux bâtiments : {path: PackedVector3Array, d: distances cumulées}.
func route_between(from: int, to: int, mode := "pied") -> Dictionary:
	var key := "%d>%d>%s" % [from, to, mode]
	if _routes.has(key):
		return _routes[key]
	var a: Vector3 = pop.known[from].pos
	var b: Vector3 = pop.known[to].pos
	var pts := PackedVector3Array()
	var net: TransportNetwork = pop.transport.network if pop.transport != null else null
	var side := SIDEWALK if mode == "pied" else LANE
	var road := PackedVector3Array()
	if net != null:
		var sa := net.find_snap(a, TransportTypes.Mode.ROAD, 80.0)
		var sb := net.find_snap(b, TransportTypes.Mode.ROAD, 80.0)
		if not sa.is_empty() and not sb.is_empty():
			road = _road_path(net, sa, sb, a, b)
			if road.size() >= 2:
				road = _offset(road, side)
	if road.size() >= 2:
		# On sort par la façade qui donne sur la voie, pas du milieu du bâtiment.
		pts.append(_door(from, road[0]))
		pts.append_array(road)
		pts.append(_door(to, road[road.size() - 1]))
	else:
		pts.append(_door(from, b))
		pts.append(_door(to, a))
	var d := PackedFloat32Array()
	d.resize(pts.size())
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		d[i] = acc
	var res := {"path": pts, "d": d}
	_routes[key] = res
	return res


## Point du bord d'un bâtiment le plus proche de p (sa porte, à peu près).
func _door(bid: int, p: Vector3) -> Vector3:
	var info: Dictionary = pop.known[bid]
	var c: Vector3 = info.pos
	if not info.has("rect"):
		return c
	var r: Rect2i = info.rect
	var x := clampf(p.x, float(r.position.x) - 0.6, float(r.end.x) + 0.6)
	var z := clampf(p.z, float(r.position.y) - 0.6, float(r.end.y) + 0.6)
	# Un point dans le rectangle (bâtiment collé à la voie) : on prend le bord le plus proche.
	if Rect2(r).grow(0.5).has_point(Vector2(x, z)):
		var dl := x - r.position.x
		var dr := r.end.x - x
		var dt := z - r.position.y
		var db := r.end.y - z
		var m := minf(minf(dl, dr), minf(dt, db))
		if m == dl:
			x = r.position.x - 0.6
		elif m == dr:
			x = r.end.x + 0.6
		elif m == dt:
			z = r.position.y - 0.6
		else:
			z = r.end.y + 0.6
	return Vector3(x, p.y, z)


## Tracé sur les voies entre deux accroches (nœud ou point d'un tronçon).
func _road_path(net: TransportNetwork, sa: Dictionary, sb: Dictionary, a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var ea := int(sa.edge)
	var eb := int(sb.edge)
	if ea >= 0 and ea == eb:
		return _edge_part(net, ea, float(sa.s), float(sb.s))
	# Nœuds de départ et d'arrivée sur le réseau.
	var na := int(sa.node)
	var nb := int(sb.node)
	var starts := [na] if na >= 0 else [int(net.edges[ea].a), int(net.edges[ea].b)]
	var ends := [nb] if nb >= 0 else [int(net.edges[eb].a), int(net.edges[eb].b)]
	var best: Array[int] = []
	var best_cost := INF
	var best_pair := [-1, -1]
	for s in starts:
		for e in ends:
			var r: Array[int] = []
			if s != e:
				r = net.find_route(s, e)
				if r.is_empty():
					continue
			var cost := 0.0
			for eid in r:
				cost += float(net.edges[eid].len)
			cost += Vector2(net.node_pos(s).x - a.x, net.node_pos(s).z - a.z).length()
			cost += Vector2(net.node_pos(e).x - b.x, net.node_pos(e).z - b.z).length()
			if cost < best_cost:
				best_cost = cost
				best = r
				best_pair = [s, e]
	if best_pair[0] < 0:
		return out
	if na < 0:
		var e: Dictionary = net.edges[ea]
		out.append_array(_edge_part(net, ea, float(sa.s), 0.0 if int(e.a) == best_pair[0] else float(e.len)))
	else:
		out.append(net.node_pos(na))
	var cur: int = best_pair[0]
	for eid in best:
		var e: Dictionary = net.edges[eid]
		var forward := int(e.a) == cur
		var part := _edge_part(net, eid, 0.0 if forward else float(e.len), float(e.len) if forward else 0.0)
		if not out.is_empty() and not part.is_empty():
			part.remove_at(0)
		out.append_array(part)
		cur = int(e.b) if forward else int(e.a)
	if nb < 0:
		var e: Dictionary = net.edges[eb]
		var part := _edge_part(net, eb, 0.0 if int(e.a) == best_pair[1] else float(e.len), float(sb.s))
		if not out.is_empty() and not part.is_empty():
			part.remove_at(0)
		out.append_array(part)
	return out


## Points d'un tronçon entre les abscisses s0 et s1 (dans un sens ou l'autre).
static func _edge_part(net: TransportNetwork, eid: int, s0: float, s1: float) -> PackedVector3Array:
	var e: Dictionary = net.edges[eid]
	var d: PackedFloat32Array = e.d
	var pts: PackedVector3Array = e.pts
	var out := PackedVector3Array()
	out.append(net.point_at(eid, s0))
	if s0 <= s1:
		for i in pts.size():
			if d[i] > s0 and d[i] < s1:
				out.append(pts[i])
	else:
		for i in range(pts.size() - 1, -1, -1):
			if d[i] < s0 and d[i] > s1:
				out.append(pts[i])
	out.append(net.point_at(eid, s1))
	return out


## Décale un tracé sur sa droite (trottoir ou voie de droite).
static func _offset(pts: PackedVector3Array, dist: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(pts.size())
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := b - a
		t.y = 0.0
		if t.length_squared() < 1e-6:
			out[i] = pts[i]
			continue
		t = t.normalized()
		out[i] = pts[i] + Vector3(-t.z, 0.0, t.x) * dist
	return out


# --- Clic ---------------------------------------------------------------------------

## Habitant visible sous le pointeur (à 18 px près), ou -1.
func pick(screen: Vector2, cam: Camera3D) -> int:
	var best := -1
	var best_d := 18.0
	for pid in agents:
		var body: Node3D = agents[pid].body
		if not body.visible:
			continue
		var p := body.global_position + Vector3(0, 1.0, 0)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(screen)
		if d < best_d:
			best_d = d
			best = pid
	return best
