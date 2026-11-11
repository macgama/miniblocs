class_name TransportSystem
extends Node3D
## Chef d'orchestre des transports dans le mode Terre : outils de pose et de
## démolition, aperçu du tracé, terrassement sous les voies, véhicules.
##
## Pose : clic gauche pour commencer, clic gauche pour chaque point suivant (le
## tracé continue depuis le dernier point). Échap ou clic droit : arrêter.
## Maj maintenue : angles par pas de 15°.

signal info_changed(text: String)
signal message(text: String)
signal network_changed

enum Tool { NONE, BUILD, DEMOLISH }

@export var world_path: NodePath
@export var camera_path: NodePath

var network := TransportNetwork.new()
var view: TransportView
var traffic: Traffic
var world: TerrainWorld
var camera: Camera3D

var tool: Tool = Tool.NONE
var type_id := "route"

var _start := {} # accroche du point de départ (vide si aucun tracé en cours)
var _cursor := Vector3.ZERO
var _cursor_valid := false
var _plan := {}
var _preview: MeshInstance3D
var _preview_ok_mat: StandardMaterial3D
var _preview_bad_mat: StandardMaterial3D
var _marker: MeshInstance3D
var _highlight_edge := -1
var _right_press := Vector2.ZERO
## Cases recouvertes par une voie au sol (pas d'arbres dessus).
var _occupied: Dictionary = {}
## Si défini, Callable(case: Vector2i) -> bool : vrai si la case est interdite
## aux voies (un bâtiment s'y trouve).
var blocker: Callable


func _ready() -> void:
	if not world_path.is_empty():
		world = get_node(world_path) as TerrainWorld
	if not camera_path.is_empty():
		camera = get_node(camera_path) as Camera3D
	view = TransportView.new()
	view.name = "Reseau"
	add_child(view)
	view.setup(network, ground_height)
	traffic = Traffic.new()
	traffic.name = "Vehicules"
	add_child(traffic)
	traffic.setup(network)
	network.changed.connect(_on_network_changed)
	if world != null:
		world.tree_blocker = func(c: Vector2i) -> bool: return _occupied.has(c)

	_preview = MeshInstance3D.new()
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)
	_preview_ok_mat = _tint(Color(0.35, 0.95, 0.45, 0.6))
	_preview_bad_mat = _tint(Color(1.0, 0.3, 0.25, 0.6))

	_marker = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.3
	cyl.radial_segments = 16
	_marker.mesh = cyl
	_marker.material_override = _tint(Color(1, 0.9, 0.3, 0.8))
	_marker.visible = false
	add_child(_marker)


static func _tint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func clear() -> void:
	traffic.clear()
	network.clear()
	cancel()


func _on_network_changed() -> void:
	var now := {}
	for id in network.edges:
		var e: Dictionary = network.edges[id]
		var step := world.height_step if world != null else 0.5
		for c in RoutePlanner.earthworks(e.t, e.pts, e.st, step):
			now[c] = true
	if world != null:
		var changed_cells := []
		for c in now:
			if not _occupied.has(c):
				changed_cells.append(c)
		for c in _occupied:
			if not now.has(c):
				changed_cells.append(c)
		_occupied = now
		if not changed_cells.is_empty():
			world.mark_cells_dirty(changed_cells)
	else:
		_occupied = now
	network_changed.emit()


## Vrai si le tracé passe sur une case interdite (au sol ou en pont, pas en tunnel).
func is_blocked(id: String, pts: PackedVector3Array, st: PackedByteArray) -> bool:
	if not blocker.is_valid():
		return false
	var step := world.height_step if world != null else 0.5
	for c in RoutePlanner.earthworks(id, pts, st, step):
		if blocker.call(c):
			return true
	for i in pts.size():
		if st[i] == TransportTypes.Struct.BRIDGE and blocker.call(Vector2i(floori(pts[i].x), floori(pts[i].z))):
			return true
	return false


func is_cell_occupied(c: Vector2i) -> bool:
	return _occupied.has(c)


# --- Outils -------------------------------------------------------------------------

func set_build(id: String) -> void:
	tool = Tool.BUILD
	type_id = id
	cancel()
	var ty := TransportTypes.get_type(id)
	info_changed.emit("%s : clic pour commencer, clic pour chaque point suivant · Échap ou clic droit pour arrêter · Maj : angles de 15°" % ty.name)


func set_demolish() -> void:
	tool = Tool.DEMOLISH
	cancel()
	info_changed.emit("Démolir : clic sur un tronçon pour le supprimer (le terrain reste terrassé).")


func set_inactive() -> void:
	tool = Tool.NONE
	cancel()
	info_changed.emit("")


func cancel() -> void:
	_start = {}
	_plan = {}
	if _preview:
		_preview.mesh = null
	_set_highlight(-1)
	_update_marker()


## Hauteur du sol pour la pose : case modifiée, sinon relief réel lissé.
func ground_height(x: float, z: float) -> float:
	if world == null:
		return NAN
	var c := Vector2i(floori(x), floori(z))
	if world.modifications.has(c):
		return float(world.modifications[c])
	return world.raw_height(x, z)


func snap_radius(id: String) -> float:
	return maxf(3.0, float(TransportTypes.get_type(id).get("width", 4.0)) * 0.6)


# --- Souris -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if tool == Tool.NONE or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		_update_cursor((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0 and not _start.is_empty():
				cancel()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		_update_cursor(mb.position)
		if not _cursor_valid:
			return
		if tool == Tool.DEMOLISH:
			if _highlight_edge >= 0:
				demolish(_highlight_edge)
			return
		_click_build()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE and not _start.is_empty():
			cancel()
			get_viewport().set_input_as_handled()


func _click_build() -> void:
	var mode := TransportTypes.mode_of(type_id)
	if _start.is_empty():
		var snap := network.find_snap(_cursor, mode, snap_radius(type_id))
		_start = snap if not snap.is_empty() else {"node": -1, "edge": -1, "pos": _cursor}
		_update_preview()
		return
	var res := build_segment(type_id, _start.pos, _cursor_target())
	if not res.ok:
		message.emit(res.reason)
		return
	message.emit(_describe(res, true))
	# On continue le tracé depuis le point posé.
	var end_node: int = res.end_node
	_start = {"node": end_node, "edge": -1, "pos": network.node_pos(end_node)}
	_update_preview()


## Position visée, avec accroche et angles de 15° si Maj est enfoncée.
func _cursor_target() -> Vector3:
	var p := _cursor
	if not _start.is_empty() and Input.is_key_pressed(KEY_SHIFT):
		var s: Vector3 = _start.pos
		var d := Vector2(p.x - s.x, p.z - s.z)
		var ang := snappedf(d.angle(), deg_to_rad(15.0))
		var v := Vector2.from_angle(ang) * d.length()
		p = Vector3(s.x + v.x, p.y, s.z + v.y)
	var snap := network.find_snap(p, TransportTypes.mode_of(type_id), snap_radius(type_id))
	if not snap.is_empty():
		return snap.pos
	return p


func _update_cursor(screen: Vector2) -> void:
	var hit: Variant = world.pick_point(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_cursor_valid = hit != null
	if _cursor_valid:
		_cursor = hit
	if tool == Tool.DEMOLISH:
		var best := -1
		var best_d := 6.0
		if _cursor_valid:
			for id in network.edges:
				var h := network.nearest_on_edge(id, _cursor)
				if h.dist < best_d:
					best_d = h.dist
					best = id
		_set_highlight(best)
		if best >= 0:
			var e: Dictionary = network.edges[best]
			info_changed.emit("Démolir : %s de %d m · clic pour supprimer" % [TransportTypes.get_type(e.t).name, roundi(e.len)])
	else:
		_update_preview()
	_update_marker()


func _update_marker() -> void:
	if _marker == null:
		return
	_marker.visible = tool == Tool.BUILD and _cursor_valid
	if _marker.visible:
		var p := _cursor_target()
		_marker.position = p + Vector3(0, 0.25, 0)
		var r := float(TransportTypes.get_type(type_id).get("width", 4.0)) * 0.5
		_marker.scale = Vector3(r, 1, r)


func _update_preview() -> void:
	if _start.is_empty() or not _cursor_valid:
		_preview.mesh = null
		return
	var a: Vector3 = _start.pos
	var b := _cursor_target()
	var a_fixed := a if int(_start.node) >= 0 or int(_start.get("edge", -1)) >= 0 else Vector3(a.x, NAN, a.z)
	var b_snap := network.find_snap(b, TransportTypes.mode_of(type_id), snap_radius(type_id))
	var b_fixed := b if not b_snap.is_empty() else Vector3(b.x, NAN, b.z)
	_plan = RoutePlanner.plan(type_id, a_fixed, b_fixed, ground_height)
	if _plan.pts.size() >= 2:
		_preview.mesh = TransportView.build_mesh(type_id, _plan.pts, _plan.st, ground_height)
		_preview.position = Vector3(0, 0.05, 0)
		if _plan.ok and is_blocked(type_id, _plan.pts, _plan.st):
			_plan.ok = false
			_plan.reason = "Un bâtiment se trouve sur le tracé."
		_preview.material_override = _preview_ok_mat if _plan.ok else _preview_bad_mat
	else:
		_preview.mesh = null
	info_changed.emit(_describe(_plan, false))


func _describe(p: Dictionary, built: bool) -> String:
	var ty := TransportTypes.get_type(String(p.get("type", type_id)))
	if not p.ok:
		return "%s : %s" % [ty.name, p.reason]
	var s := "%s%s : %d m · pente maxi %s %%" % [ty.name, " posée" if built else "", roundi(p.length),
		("%.1f" % (float(p.max_grade) * 100.0)).replace(".", ",")]
	if float(p.bridge_len) > 0.0:
		s += " · pont %d m" % roundi(p.bridge_len)
	if float(p.tunnel_len) > 0.0:
		s += " · tunnel %d m" % roundi(p.tunnel_len)
	if built and int(p.get("junctions", 0)) > 0:
		s += " · %d carrefour%s" % [p.junctions, "s" if int(p.junctions) > 1 else ""]
	return s


func _set_highlight(id: int) -> void:
	if id == _highlight_edge and (id < 0 or _preview.mesh != null):
		return
	_highlight_edge = id
	if id < 0:
		if tool == Tool.DEMOLISH:
			_preview.mesh = null
		return
	var e: Dictionary = network.edges[id]
	_preview.mesh = TransportView.build_mesh(e.t, e.pts, e.st, ground_height)
	_preview.position = Vector3(0, 0.08, 0)
	_preview.material_override = _preview_bad_mat


# --- Pose et démolition ------------------------------------------------------------------

## Pose un tronçon de type id entre a et b (accroches automatiques sur le réseau
## existant, carrefours aux croisements, terrassement). Renvoie le plan avec
## en plus start_node, end_node, edges (créés) et junctions.
func build_segment(id: String, a: Vector3, b: Vector3) -> Dictionary:
	var mode := TransportTypes.mode_of(id)
	var r := snap_radius(id)
	var sa := network.find_snap(a, mode, r)
	var sb := network.find_snap(b, mode, r)
	var a_pos := Vector3(a.x, NAN, a.z) if sa.is_empty() else (sa.pos as Vector3)
	var b_pos := Vector3(b.x, NAN, b.z) if sb.is_empty() else (sb.pos as Vector3)
	if not sa.is_empty() and not sb.is_empty() and int(sa.node) >= 0 and sa.node == sb.node:
		return {"ok": false, "reason": "Le départ et l'arrivée sont au même endroit."}
	var plan := RoutePlanner.plan(id, a_pos, b_pos, ground_height)
	if not plan.ok:
		return plan
	if is_blocked(id, plan.pts, plan.st):
		return {"ok": false, "reason": "Un bâtiment se trouve sur le tracé."}
	var pts: PackedVector3Array = plan.pts
	var st: PackedByteArray = plan.st
	var n := pts.size()

	# Croisements avec les voies existantes du même mode, repérés avant de modifier le réseau.
	var crossings := _find_crossings(mode, pts, st)

	var na := _resolve(sa, pts[0], mode)
	sb = network.find_snap(b_pos if sb.is_empty() else (sb.pos as Vector3), mode, 0.6) if not sb.is_empty() else {}
	var nb := _resolve(sb, pts[n - 1], mode)
	if na == nb:
		return {"ok": false, "reason": "Le départ et l'arrivée sont au même endroit."}

	var d := PackedFloat32Array()
	d.resize(n)
	for i in range(1, n):
		d[i] = d[i - 1] + pts[i].distance_to(pts[i - 1])
	var stops: Array = [[0.0, na]]
	for c in crossings:
		var snap := network.find_snap(c.pos, mode, 0.6)
		if snap.is_empty():
			continue
		var node := _resolve(snap, c.pos, mode)
		var dup := false
		for st_ in stops:
			dup = dup or int(st_[1]) == node
		if dup or node == nb:
			continue
		stops.append([lerpf(d[c.i], d[c.i + 1], c.u), node])
	stops.append([d[n - 1], nb])

	var made: Array[int] = []
	for k in stops.size() - 1:
		var s0: float = stops[k][0]
		var s1: float = stops[k + 1][0]
		var n0: int = stops[k][1]
		var n1: int = stops[k + 1][1]
		if n0 == n1 or s1 - s0 < 0.5:
			continue
		var part := TransportNetwork.slice_polyline(pts, st, d, s0, s1)
		var pp: PackedVector3Array = part[0]
		# Raccord en hauteur exact sur les nœuds (carrefours).
		var d0 := network.node_pos(n0).y - pp[0].y
		var d1 := network.node_pos(n1).y - pp[pp.size() - 1].y
		for i in pp.size():
			var u := float(i) / float(pp.size() - 1)
			pp[i].y += lerpf(d0, d1, u)
		made.append(network.add_edge(n0, n1, id, pp, part[1]))

	# Remblais et déblais sous la voie.
	if world != null:
		world.set_cells(RoutePlanner.earthworks(id, pts, st, world.height_step))
	network.changed.emit()
	plan.start_node = na
	plan.end_node = nb
	plan.edges = made
	plan.junctions = stops.size() - 2
	return plan


## Nœud correspondant à une accroche (en coupant un tronçon si besoin), ou nouveau nœud.
func _resolve(snap: Dictionary, p: Vector3, mode: int) -> int:
	if snap.is_empty():
		return network.add_node(p, mode)
	if int(snap.node) >= 0:
		return snap.node
	return network.split_edge(snap.edge, snap.s, 2.5)


## Points où le nouveau tracé coupe une voie existante du même mode, à la même hauteur
## (sinon l'une passe au-dessus de l'autre, sans carrefour).
func _find_crossings(mode: int, pts: PackedVector3Array, st: PackedByteArray) -> Array:
	var out := []
	var n := pts.size()
	var a := Vector2(pts[0].x, pts[0].z)
	var b := Vector2(pts[n - 1].x, pts[n - 1].z)
	var total := a.distance_to(b)
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	for eid in network.edges:
		var e: Dictionary = network.edges[eid]
		if TransportTypes.mode_of(e.t) != mode:
			continue
		var ep: PackedVector3Array = e.pts
		var est: PackedByteArray = e.st
		for j in ep.size() - 1:
			var p := Vector2(ep[j].x, ep[j].z)
			var q := Vector2(ep[j + 1].x, ep[j + 1].z)
			if maxf(p.x, q.x) < lo.x or minf(p.x, q.x) > hi.x or maxf(p.y, q.y) < lo.y or minf(p.y, q.y) > hi.y:
				continue
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, p, q)
			if hit == null:
				continue
			var x: Vector2 = hit
			var along := a.distance_to(x)
			if along < 3.0 or along > total - 3.0:
				continue
			var f := along / total * float(n - 1)
			var i := mini(floori(f), n - 2)
			var u := f - float(i)
			var ph := lerpf(pts[i].y, pts[i + 1].y, u)
			var v := p.distance_to(x) / maxf(p.distance_to(q), 1e-6)
			var eh := lerpf(ep[j].y, ep[j + 1].y, v)
			if absf(ph - eh) > 1.5:
				continue
			if st[i] == TransportTypes.Struct.TUNNEL or est[j] == TransportTypes.Struct.TUNNEL:
				continue
			out.append({"i": i, "u": u, "along": along, "pos": Vector3(x.x, eh, x.y)})
	out.sort_custom(func(l: Dictionary, r: Dictionary) -> bool: return l.along < r.along)
	return out


func demolish(id: int) -> void:
	if not network.edges.has(id):
		return
	var e: Dictionary = network.edges[id]
	var name_: String = TransportTypes.get_type(e.t).name
	network.remove_edge(id)
	network.changed.emit()
	_highlight_edge = -1
	_preview.mesh = null
	message.emit("%s supprimée." % name_)


# --- Statistiques et sauvegarde -----------------------------------------------------------

func summary() -> String:
	var parts := []
	for mode in [TransportTypes.Mode.ROAD, TransportTypes.Mode.RAIL, TransportTypes.Mode.PATH, TransportTypes.Mode.WATER]:
		var l := network.total_length(mode)
		if l > 0.0:
			parts.append("%s %s" % [TransportTypes.MODE_NAMES[mode], _km(l)])
	if parts.is_empty():
		return "Réseau : aucun"
	return "Réseau : %s   ·   Véhicules : %d" % [", ".join(parts), traffic.vehicles.size()]


static func _km(m: float) -> String:
	return "%d m" % roundi(m) if m < 1000.0 else ("%.2f km" % (m / 1000.0)).replace(".", ",")


func to_dict() -> Dictionary:
	return network.to_dict()


func from_dict(data: Dictionary) -> void:
	traffic.clear()
	cancel()
	network.from_dict(data)
