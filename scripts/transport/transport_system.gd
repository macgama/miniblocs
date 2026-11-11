class_name TransportSystem
extends Node3D
## Chef d'orchestre des transports dans le mode Terre : outils de pose et de
## démolition, aperçu du tracé, contrôle des chevauchements, carrefours,
## terrassement sous les voies, véhicules.
##
## Pose en ligne droite : clic pour commencer, clic pour chaque point suivant.
## Pose en courbe (touche C) : clic de départ, clic qui donne la direction
## (point de contrôle), clic d'arrivée ; en continuant un tracé, la courbe part
## dans le prolongement de la voie précédente et un seul clic suffit.
## Échap ou clic droit : arrêter. Maj maintenue : angles par pas de 15°.

signal info_changed(text: String)
signal message(text: String)
signal network_changed
signal spec_changed(type_id: String, spec: Dictionary)

enum Tool { NONE, BUILD, DEMOLISH }

## Hauteur entre deux voies qui se croisent : en dessous, carrefour (ou passage
## à niveau) ; au-dessus de CLEARANCE, l'une passe sous l'autre.
const JUNCTION_DY := 1.5
const CLEARANCE := 4.5

@export var world_path: NodePath
@export var camera_path: NodePath

var network := TransportNetwork.new()
var view: TransportView
var traffic: Traffic
var world: TerrainWorld
var camera: Camera3D

var tool: Tool = Tool.NONE
var type_id := "departementale"
var spec: Dictionary = TransportTypes.default_spec("departementale")
var curve_mode := false
## Réglages retenus pour chaque classe (on les retrouve en revenant dessus).
var _specs: Dictionary = {}

var _start := {} # accroche du point de départ (vide si aucun tracé en cours)
var _ctrl: Variant = null # point de contrôle de la courbe (Vector2) ou null
var _cursor := Vector3.ZERO
var _cursor_valid := false
var _plan := {}
var _preview: MeshInstance3D
var _preview_ok_mat: StandardMaterial3D
var _preview_bad_mat: StandardMaterial3D
var _marker: MeshInstance3D
var _ctrl_marker: MeshInstance3D
var _highlight_edge := -1
var _right_press := Vector2.ZERO
## Cases recouvertes par une voie au sol (pas d'arbres dessus, talus protégés).
var _occupied: Dictionary = {}
## Grille de recherche : case de 16 m -> [[tronçon, segment], …]
var _hash: Dictionary = {}
var _hash_dirty := true
var _max_hw := 0.0
const HASH := 16.0
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
	_marker = _make_marker(Color(1, 0.9, 0.3, 0.8))
	_ctrl_marker = _make_marker(Color(0.4, 0.8, 1.0, 0.9))


func _make_marker(c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.3
	cyl.radial_segments = 16
	m.mesh = cyl
	m.material_override = _tint(c)
	m.visible = false
	add_child(m)
	return m


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
	_hash_dirty = true
	var now := {}
	for id in network.edges:
		var e: Dictionary = network.edges[id]
		for c in RoutePlanner.footprint(float(e.width), e.pts, e.st):
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
	for c in RoutePlanner.footprint(TransportTypes.width_of(id, spec), pts, st):
		if blocker.call(c):
			return true
	for i in pts.size():
		if st[i] == TransportTypes.Struct.BRIDGE and blocker.call(Vector2i(floori(pts[i].x), floori(pts[i].z))):
			return true
	return false


func is_cell_occupied(c: Vector2i) -> bool:
	return _occupied.has(c)


# --- Outils et réglages ------------------------------------------------------------------

func set_build(id: String) -> void:
	id = TransportTypes.resolve(id)
	tool = Tool.BUILD
	type_id = id
	spec = TransportTypes.normalize(id, _specs.get(id, {}))
	cancel()
	spec_changed.emit(type_id, spec)
	_emit_help()


## Change la classe ou les réglages (voies, largeur…) de la voie à poser.
func set_spec(id: String, s: Dictionary) -> void:
	id = TransportTypes.resolve(id)
	type_id = id
	spec = TransportTypes.normalize(id, s)
	_specs[id] = spec
	if tool == Tool.BUILD:
		_update_preview()
		_update_marker()
	if _plan.is_empty():
		_emit_help()


func set_curve(on: bool) -> void:
	curve_mode = on
	_ctrl = null
	_update_preview()
	_emit_help()


func _emit_help() -> void:
	if tool != Tool.BUILD:
		return
	var ty := TransportTypes.get_type(type_id)
	var how := "clic de départ, clic de direction, clic d'arrivée" if curve_mode else "clic pour commencer, clic pour chaque point"
	info_changed.emit("%s (%s) : %s · C : %s · Échap / clic droit : arrêter · Maj : angles de 15°\n%s" % [
		ty.name, "courbe" if curve_mode else "droite", how, "passer en ligne droite" if curve_mode else "passer en courbe",
		TransportTypes.describe(type_id, spec)])


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
	_ctrl = null
	_plan = {}
	if _preview:
		_preview.mesh = null
	_set_highlight(-1)
	_update_marker()
	_emit_help()


## Hauteur du sol pour la pose : case modifiée, sinon relief réel lissé.
func ground_height(x: float, z: float) -> float:
	if world == null:
		return NAN
	var c := Vector2i(floori(x), floori(z))
	if world.modifications.has(c):
		return float(world.modifications[c])
	return world.raw_height(x, z)


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
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE and not _start.is_empty():
			cancel()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_C and tool == Tool.BUILD:
			set_curve(not curve_mode)
			spec_changed.emit(type_id, spec)
			get_viewport().set_input_as_handled()


func _click_build() -> void:
	var mode := TransportTypes.mode_of(type_id)
	if _start.is_empty():
		var snap := network.find_snap(_cursor, mode, 1.0)
		_start = snap if not snap.is_empty() else {"node": -1, "edge": -1, "pos": _cursor}
		_start.dir = _continue_dir(snap)
		_update_preview()
		return
	if curve_mode and _ctrl == null and (_start.dir as Vector2) == Vector2.ZERO:
		var t := _cursor_target()
		_ctrl = Vector2(t.x, t.z)
		_update_preview()
		return
	var res := build_path(type_id, spec, _current_path())
	if not res.ok:
		message.emit(res.reason)
		return
	message.emit(_describe(res, true))
	# On continue le tracé depuis le point posé, dans le prolongement.
	var end_node: int = res.end_node
	var pts: PackedVector3Array = res.pts
	var tail := pts[pts.size() - 1] - pts[maxi(pts.size() - 3, 0)]
	_start = {"node": end_node, "edge": -1, "pos": network.node_pos(end_node),
		"dir": Vector2(tail.x, tail.z).normalized()}
	_ctrl = null
	_update_preview()


## Direction de départ quand on prolonge l'extrémité libre d'une voie.
func _continue_dir(snap: Dictionary) -> Vector2:
	if snap.is_empty() or int(snap.node) < 0:
		return Vector2.ZERO
	var adj: Array = network.adjacency.get(snap.node, [])
	if adj.size() != 1:
		return Vector2.ZERO
	var d := -network.leave_dir(adj[0], snap.node)
	return Vector2(d.x, d.z)


## Position visée, avec accroche et angles de 15° si Maj est enfoncée.
func _cursor_target() -> Vector3:
	var p := _cursor
	if not _start.is_empty() and Input.is_key_pressed(KEY_SHIFT):
		var s: Vector3 = _start.pos
		var origin := Vector2(s.x, s.z) if _ctrl == null else (_ctrl as Vector2)
		var d := Vector2(p.x, p.z) - origin
		var ang := snappedf(d.angle(), deg_to_rad(15.0))
		var v := Vector2.from_angle(ang) * d.length()
		p = Vector3(origin.x + v.x, p.y, origin.y + v.y)
	var snap := network.find_snap(p, TransportTypes.mode_of(type_id), 1.0)
	if not snap.is_empty():
		return snap.pos
	return p


## Tracé en plan entre le départ et la souris (droit ou courbe).
func _current_path() -> PackedVector2Array:
	var s: Vector3 = _start.pos
	var e := _cursor_target()
	return make_path(Vector2(s.x, s.z), Vector2(e.x, e.z), _ctrl, _start.get("dir", Vector2.ZERO), curve_mode)


## Tracé en plan : ligne droite, ou courbe de Bézier passant par le point de
## contrôle (ou partant dans la direction donnée).
static func make_path(a: Vector2, b: Vector2, ctrl: Variant, dir: Vector2, curve: bool) -> PackedVector2Array:
	if curve:
		if ctrl != null:
			return RoutePlanner.bezier(a, ctrl, b)
		if dir != Vector2.ZERO:
			return RoutePlanner.bezier(a, a + dir * a.distance_to(b) * 0.5, b)
	return PackedVector2Array([a, b])


func _update_cursor(screen: Vector2) -> void:
	var hit: Variant = world.pick_point(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_cursor_valid = hit != null
	if _cursor_valid:
		_cursor = hit
	if tool == Tool.DEMOLISH:
		var best := -1
		var best_d := INF
		if _cursor_valid:
			for id in network.edges:
				var h := network.nearest_on_edge(id, _cursor)
				if h.dist < network.half_width(id) + 1.5 and h.dist < best_d:
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
		_marker.position = p + Vector3(0, 0.3, 0)
		var r := TransportTypes.width_of(type_id, spec) * 0.5
		_marker.scale = Vector3(r, 1, r)
	_ctrl_marker.visible = tool == Tool.BUILD and _ctrl != null
	if _ctrl_marker.visible:
		var c: Vector2 = _ctrl
		var h := ground_height(c.x, c.y)
		_ctrl_marker.position = Vector3(c.x, (0.0 if is_nan(h) else maxf(h, 0.0)) + 0.4, c.y)


func _update_preview() -> void:
	if _start.is_empty() or not _cursor_valid or tool != Tool.BUILD:
		if _preview and tool != Tool.DEMOLISH:
			_preview.mesh = null
		return
	_plan = evaluate(type_id, spec, _current_path())
	var pts: PackedVector3Array = _plan.get("pts", PackedVector3Array())
	if pts.size() >= 2:
		_preview.mesh = TransportView.build_mesh(type_id, spec, pts, _plan.st, ground_height)
		_preview.position = Vector3(0, 0.05, 0)
		_preview.material_override = _preview_ok_mat if _plan.ok else _preview_bad_mat
	else:
		_preview.mesh = null
	info_changed.emit(_describe(_plan, false) + "\n" + TransportTypes.describe(type_id, spec))


func _describe(p: Dictionary, built: bool) -> String:
	var ty := TransportTypes.get_type(String(p.get("type", type_id)))
	if not p.get("ok", false):
		return "%s : %s" % [ty.name, p.get("reason", "")]
	var s := "%s%s : %d m · pente maxi %s %%" % [ty.name, " posée" if built else "", roundi(p.length),
		TransportTypes._num(float(p.max_grade) * 100.0)]
	if float(p.get("min_radius", INF)) < 1.0e6:
		s += " · rayon %d m" % roundi(p.min_radius)
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
	_preview.mesh = TransportView.build_mesh(e.t, e.w, e.pts, e.st, ground_height)
	_preview.position = Vector3(0, 0.12, 0)
	_preview.material_override = _preview_bad_mat


# --- Évaluation d'un tracé -----------------------------------------------------------------

## Accroches, profil en long et contrôles (chevauchements, croisements) d'un
## tracé, sans rien modifier. Renvoie le plan avec en plus : snap_a, snap_b,
## crossings.
func evaluate(id: String, s: Dictionary, path: PackedVector2Array) -> Dictionary:
	id = TransportTypes.resolve(id)
	var mode := TransportTypes.mode_of(id)
	var a := path[0]
	var b := path[path.size() - 1]
	var sa := network.find_snap(Vector3(a.x, 0, a.y), mode, 1.0)
	var sb := network.find_snap(Vector3(b.x, 0, b.y), mode, 1.0)
	path = path.duplicate()
	if not sa.is_empty():
		path[0] = Vector2(sa.pos.x, sa.pos.z)
	if not sb.is_empty():
		path[path.size() - 1] = Vector2(sb.pos.x, sb.pos.z)
	var h0: float = sa.pos.y if not sa.is_empty() else NAN
	var h1: float = sb.pos.y if not sb.is_empty() else NAN
	var plan := RoutePlanner.plan(id, path, h0, h1, ground_height)
	plan.snap_a = sa
	plan.snap_b = sb
	plan.crossings = []
	if not sa.is_empty() and not sb.is_empty() and int(sa.node) >= 0 and sa.node == sb.node:
		plan.ok = false
		plan.reason = "Le départ et l'arrivée sont au même endroit."
		return plan
	if not plan.ok:
		return plan
	if is_blocked(id, plan.pts, plan.st):
		plan.ok = false
		plan.reason = "Un bâtiment se trouve sur le tracé."
		return plan
	var pts: PackedVector3Array = plan.pts
	var st: PackedByteArray = plan.st
	var crossings := _find_crossings(mode, pts, st)
	plan.crossings = crossings
	var w := TransportTypes.width_of(id, s)
	for c in crossings:
		if not c.same_mode and not c.compatible and absf(c.dy) < CLEARANCE:
			plan.ok = false
			plan.reason = "Croisement impossible avec %s ici." % String(TransportTypes.get_type(c.type).name).to_lower()
			return plan
		if absf(c.dy) >= JUNCTION_DY and absf(c.dy) < CLEARANCE:
			plan.ok = false
			plan.reason = "Croisement à %s m de hauteur : trop haut pour un carrefour, trop bas pour passer dessus (%s m minimum)." % [
				TransportTypes._num(snappedf(absf(c.dy), 0.1)), TransportTypes._num(CLEARANCE)]
			return plan
	var clash := _find_overlap(mode, w, pts, st, sa, sb, crossings)
	if not clash.is_empty():
		plan.ok = false
		plan.reason = "Chevauche %s. Raccorde-toi dessus (clic sur la voie) ou croise-la franchement." % String(clash.name).to_lower()
		plan.clash = clash.pos
	return plan


func _rebuild_hash() -> void:
	if not _hash_dirty:
		return
	_hash.clear()
	_max_hw = 0.0
	for eid in network.edges:
		var e: Dictionary = network.edges[eid]
		_max_hw = maxf(_max_hw, float(e.width) * 0.5)
		var ep: PackedVector3Array = e.pts
		for j in ep.size() - 1:
			var lo := Vector2(minf(ep[j].x, ep[j + 1].x), minf(ep[j].z, ep[j + 1].z))
			var hi := Vector2(maxf(ep[j].x, ep[j + 1].x), maxf(ep[j].z, ep[j + 1].z))
			for cx in range(floori(lo.x / HASH), floori(hi.x / HASH) + 1):
				for cz in range(floori(lo.y / HASH), floori(hi.y / HASH) + 1):
					var k := Vector2i(cx, cz)
					if not _hash.has(k):
						_hash[k] = []
					(_hash[k] as Array).append([eid, j])
	_hash_dirty = false


## Segments existants près d'un rectangle (coins lo / hi), sans doublon.
func _query(lo: Vector2, hi: Vector2) -> Array:
	_rebuild_hash()
	var out := []
	var seen := {}
	for cx in range(floori(lo.x / HASH), floori(hi.x / HASH) + 1):
		for cz in range(floori(lo.y / HASH), floori(hi.y / HASH) + 1):
			for item in _hash.get(Vector2i(cx, cz), []):
				var key := Vector2i(item[0], item[1])
				if not seen.has(key):
					seen[key] = true
					out.append(item)
	return out


## Points où le tracé coupe une voie existante (tous modes).
## Chaque croisement : i, u (position sur le tracé), along, pos, edge, same_mode,
## compatible (passage à niveau possible), dy (écart de hauteur), angle, type.
func _find_crossings(mode: int, pts: PackedVector3Array, st: PackedByteArray) -> Array:
	var out := []
	var n := pts.size()
	var along := 0.0
	for i in n - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var seg := a.distance_to(b)
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		for item in _query(lo, hi):
			var eid: int = item[0]
			var j: int = item[1]
			var e: Dictionary = network.edges[eid]
			var emode := TransportTypes.mode_of(e.t)
			if emode == TransportTypes.Mode.WATER or mode == TransportTypes.Mode.WATER:
				continue
			var ep: PackedVector3Array = e.pts
			var p := Vector2(ep[j].x, ep[j].z)
			var q := Vector2(ep[j + 1].x, ep[j + 1].z)
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, p, q)
			if hit == null:
				continue
			var x: Vector2 = hit
			var u := a.distance_to(x) / maxf(seg, 1e-6)
			var ph := lerpf(pts[i].y, pts[i + 1].y, u)
			var v := p.distance_to(x) / maxf(p.distance_to(q), 1e-6)
			var eh := lerpf(ep[j].y, ep[j + 1].y, v)
			var est: PackedByteArray = e.st
			if st[i] == TransportTypes.Struct.TUNNEL or est[j] == TransportTypes.Struct.TUNNEL:
				continue
			var cross_along := along + seg * u
			var dup := false
			for c in out:
				if int(c.edge) == eid and absf(float(c.along) - cross_along) < 1.5:
					dup = true
			if dup:
				continue
			var d1 := (b - a).normalized()
			var d2 := (q - p).normalized()
			var ang := acos(clampf(absf(d1.dot(d2)), 0.0, 1.0))
			# Passage à niveau : route ou chemin qui coupe une voie ferrée, chemin qui coupe une route.
			var compatible := emode != mode
			out.append({"i": i, "u": u, "along": cross_along, "pos": Vector3(x.x, eh, x.y), "edge": eid,
				"same_mode": emode == mode, "compatible": compatible, "dy": ph - eh, "angle": ang, "type": e.t,
				"hw": float(e.width) * 0.5})
		along += seg
	out.sort_custom(func(l: Dictionary, r: Dictionary) -> bool: return l.along < r.along)
	return out


## Cherche un endroit où la nouvelle voie recouvrirait une voie existante sans
## la croiser ni s'y raccorder. Renvoie {"pos", "name"} ou {}.
func _find_overlap(mode: int, width: float, pts: PackedVector3Array, st: PackedByteArray,
		sa: Dictionary, sb: Dictionary, crossings: Array) -> Dictionary:
	if mode == TransportTypes.Mode.WATER:
		return {}
	_rebuild_hash()
	var hw := width * 0.5
	# Zones où le recouvrement est normal : raccords et croisements.
	var allowed := []
	for snap in [sa, sb]:
		var sd: Dictionary = snap
		if sd.is_empty():
			continue
		var p: Vector3 = sd.pos
		var other := network.node_half_width(sd.node) if int(sd.node) >= 0 else network.half_width(sd.edge)
		allowed.append([Vector2(p.x, p.z), (hw + other) * 2.5 + 2.0])
	for c in crossings:
		var cp: Vector3 = c.pos
		var r: float = (hw + float(c.hw)) / maxf(sin(float(c.angle)), 0.25) + 1.5
		allowed.append([Vector2(cp.x, cp.z), r])
	var reach := hw + _max_hw
	for i in pts.size():
		if st[i] == TransportTypes.Struct.TUNNEL:
			continue
		var q := Vector2(pts[i].x, pts[i].z)
		var ok_zone := false
		for zone in allowed:
			if q.distance_to(zone[0]) < float(zone[1]):
				ok_zone = true
				break
		if ok_zone:
			continue
		for item in _query(q - Vector2.ONE * reach, q + Vector2.ONE * reach):
			var eid: int = item[0]
			var j: int = item[1]
			var e: Dictionary = network.edges[eid]
			if TransportTypes.mode_of(e.t) == TransportTypes.Mode.WATER:
				continue
			var est: PackedByteArray = e.st
			if est[j] == TransportTypes.Struct.TUNNEL:
				continue
			var ep: PackedVector3Array = e.pts
			var a := Vector2(ep[j].x, ep[j].z)
			var ab := Vector2(ep[j + 1].x, ep[j + 1].z) - a
			var u := 0.0
			if ab.length_squared() > 1e-8:
				u = clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var dist := q.distance_to(a + ab * u)
			if dist >= hw + float(e.width) * 0.5 - 0.2:
				continue
			var eh := lerpf(ep[j].y, ep[j + 1].y, u)
			if absf(pts[i].y - eh) >= CLEARANCE:
				continue
			return {"pos": pts[i], "name": TransportTypes.get_type(e.t).name}
	return {}


# --- Pose et démolition ------------------------------------------------------------------

## Pose une voie droite de a à b (raccourci pour les tests et les scripts).
func build_segment(id: String, a: Vector3, b: Vector3, s: Dictionary = {}) -> Dictionary:
	return build_path(id, s, PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z)]))


## Pose une voie le long d'un tracé en plan : accroches, carrefours aux
## croisements, terrassement. Renvoie le plan avec en plus start_node,
## end_node, edges (créés) et junctions.
func build_path(id: String, s: Dictionary, path: PackedVector2Array) -> Dictionary:
	id = TransportTypes.resolve(id)
	if s.is_empty():
		s = _specs.get(id, TransportTypes.default_spec(id))
	s = TransportTypes.normalize(id, s)
	var plan := evaluate(id, s, path)
	if not plan.ok:
		return plan
	var mode := TransportTypes.mode_of(id)
	var pts: PackedVector3Array = plan.pts
	var st: PackedByteArray = plan.st
	var n := pts.size()
	var sa: Dictionary = plan.snap_a
	var sb: Dictionary = plan.snap_b
	var width := TransportTypes.width_of(id, s)
	# Terrassement calculé avant d'ajouter la voie (les autres voies sont protégées).
	var works := {}
	if world != null:
		works = RoutePlanner.earthworks(width, pts, st, world.height_step, ground_height, _occupied)

	var na := _resolve(sa, pts[0], mode)
	if not sb.is_empty():
		sb = network.find_snap(sb.pos, mode, 0.3)
	var nb := _resolve(sb, pts[n - 1], mode)
	if na == nb:
		return {"ok": false, "reason": "Le départ et l'arrivée sont au même endroit."}

	var d := PackedFloat32Array()
	d.resize(n)
	for i in range(1, n):
		d[i] = d[i - 1] + pts[i].distance_to(pts[i - 1])
	var stops: Array = [[0.0, na]]
	for c in plan.crossings:
		if not c.same_mode or absf(float(c.dy)) >= JUNCTION_DY:
			continue
		var snap := network.find_snap(c.pos, mode, 0.0)
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
		made.append(network.add_edge(n0, n1, id, pp, part[1], s))

	if world != null and not works.is_empty():
		world.set_cells(works)
	network.changed.emit()
	plan.start_node = na
	plan.end_node = nb
	plan.edges = made
	plan.junctions = stops.size() - 2
	plan.earthworks = works.size()
	return plan


## Nœud correspondant à une accroche (en coupant un tronçon si besoin), ou nouveau nœud.
func _resolve(snap: Dictionary, p: Vector3, mode: int) -> int:
	if snap.is_empty():
		return network.add_node(p, mode)
	if int(snap.node) >= 0:
		return snap.node
	return network.split_edge(snap.edge, snap.s, maxf(2.5, network.half_width(snap.edge)))


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
