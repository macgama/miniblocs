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

enum Tool { NONE, BUILD, DEMOLISH, JUNCTION }

## Hauteur entre deux voies qui se croisent : en dessous, carrefour (ou passage
## à niveau) ; au-dessus de CLEARANCE, l'une passe sous l'autre.
const JUNCTION_DY := 1.5
const CLEARANCE := 4.5
## Passage aux croisements : automatique (carrefour, ou pont pour couper une
## autoroute), toujours dessus (pont) ou toujours dessous (tunnel).
const LEVELS: Array[String] = ["auto", "dessus", "dessous"]
const LEVEL_NAMES := {"auto": "Croisements : automatique", "dessus": "Croisements : passer dessus (pont)",
	"dessous": "Croisements : passer dessous (tunnel)"}

@export var world_path: NodePath
@export var camera_path: NodePath

var network := TransportNetwork.new()
var view: TransportView
var traffic: Traffic
var stations: StationSystem
var junctions: JunctionControl
## Îlots centraux des giratoires : [{"c": Vector3, "r": float}].
var roundabouts: Array = []
var _islands: Node3D
var world: TerrainWorld
var camera: Camera3D

var tool: Tool = Tool.NONE
var type_id := "departementale"
var spec: Dictionary = TransportTypes.default_spec("departementale")
var curve_mode := false
## Passage imposé aux croisements (voir LEVELS).
var level := "auto"
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
## Cases couvertes par les voies : Vector2i -> nombre de tronçons qui la couvrent.
var _occupied: Dictionary = {}
## Emprise de chaque tronçon : id -> {e: tronçon, cells: Array[Vector2i]}.
var _edge_fp: Dictionary = {}
## Emprise des plateaux de carrefour : id de nœud -> {key, cells}.
var _node_fp: Dictionary = {}
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
	junctions = JunctionControl.new()
	add_child(junctions)
	junctions.setup(network)
	traffic.junctions = junctions
	_islands = Node3D.new()
	_islands.name = "Giratoires"
	add_child(_islands)
	network.changed.connect(_on_network_changed)
	stations = StationSystem.new()
	stations.name = "Stations"
	add_child(stations)
	stations.setup(self)
	if world != null:
		world.tree_blocker = func(c: Vector2i) -> bool: return _occupied.has(c) or stations.occupies(c)

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
	junctions.overrides.clear()
	roundabouts.clear()
	stations.clear()
	traffic.clear()
	network.clear()
	cancel()


func _on_network_changed() -> void:
	_refresh_islands()
	_hash_dirty = true
	# Mise à jour incrémentale : seuls les tronçons ajoutés, supprimés ou
	# remplacés recalculent leur emprise (le réseau peut faire des dizaines de km).
	var changed_cells := []
	for id in _edge_fp.keys():
		var old: Dictionary = _edge_fp[id]
		if network.edges.has(id) and is_same(old.e, network.edges[id]):
			continue
		for c in old.cells:
			var n: int = _occupied.get(c, 0) - 1
			if n <= 0:
				_occupied.erase(c)
				changed_cells.append(c)
			else:
				_occupied[c] = n
		_edge_fp.erase(id)
	for id in network.edges:
		if _edge_fp.has(id):
			continue
		var e: Dictionary = network.edges[id]
		var cells: Array = RoutePlanner.footprint(float(e.width), e.pts, e.st).keys()
		for c in cells:
			var n: int = _occupied.get(c, 0)
			if n == 0:
				changed_cells.append(c)
			_occupied[c] = n + 1
		_edge_fp[id] = {"e": e, "cells": cells}
	_refresh_junction_cells(changed_cells)
	if world != null and not changed_cells.is_empty():
		world.mark_cells_dirty(changed_cells)
	network_changed.emit()


## Plateaux de carrefour : cases réservées (pas d'arbres, pas de talus d'une
## autre voie) et terrain mis au niveau de la chaussée, pour que le sol ne
## perce pas les trottoirs arrondis des angles.
func _refresh_junction_cells(changed_cells: Array) -> void:
	var trims := TransportView.compute_trims(network)
	var keys := {}
	for nid in network.nodes:
		if network.degree(nid) < 2:
			continue
		var key := [network.node_pos(nid)]
		for eid in network.adjacency.get(nid, []):
			key.append(network.edges[eid])
			key.append(trims.get(eid, Vector2.ZERO))
		keys[nid] = key
	for nid in _node_fp.keys():
		if keys.has(nid) and TransportView._same_key(_node_fp[nid].key, keys[nid]):
			continue
		for c in _node_fp[nid].cells:
			var n: int = _occupied.get(c, 0) - 1
			if n <= 0:
				_occupied.erase(c)
				changed_cells.append(c)
			else:
				_occupied[c] = n
		_node_fp.erase(nid)
	var works := {}
	for nid in keys:
		if _node_fp.has(nid):
			continue
		var cells := TransportView.junction_cells(network, nid, trims)
		for c in cells:
			var n: int = _occupied.get(c, 0)
			if n == 0:
				changed_cells.append(c)
			_occupied[c] = n + 1
			if world != null and is_nan(water_surface(c.x + 0.5, c.y + 0.5)):
				works[c] = floorf((float(cells[c]) + 0.001) / world.height_step) * world.height_step
		_node_fp[nid] = {"key": keys[nid], "cells": cells.keys()}
	if world != null and not works.is_empty():
		world.set_cells(works)


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
	return _occupied.has(c) or (stations != null and stations.occupies(c))


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


func set_level(l: String) -> void:
	if not LEVELS.has(l):
		return
	level = l
	_update_preview()
	_emit_help()


func cycle_level() -> String:
	set_level(LEVELS[(LEVELS.find(level) + 1) % LEVELS.size()])
	return level


func _emit_help() -> void:
	if tool != Tool.BUILD:
		return
	var ty := TransportTypes.get_type(type_id)
	var how := "clic de départ, clic de direction, clic d'arrivée" if curve_mode else "clic pour commencer, clic pour chaque point"
	info_changed.emit("%s (%s) : %s · C : %s · N : %s · Échap / clic droit : arrêter · Maj : angles de 15°\n%s" % [
		ty.name, "courbe" if curve_mode else "droite", how, "passer en ligne droite" if curve_mode else "passer en courbe",
		String(LEVEL_NAMES[level]).to_lower(), TransportTypes.describe(type_id, spec)])


func set_demolish() -> void:
	tool = Tool.DEMOLISH
	cancel()
	info_changed.emit("Démolir : clic sur un tronçon pour le supprimer (le terrain reste terrassé).")


## Outil « Carrefour », trois actions : changer le régime d'un carrefour
## (automatique, feux, stop, cédez-le-passage, priorité à droite), le
## transformer en giratoire, ou construire un échangeur sur une autoroute.
const JUNCTION_ACTIONS: Array[String] = ["regime", "giratoire", "echangeur"]
const JUNCTION_HELP := {
	"regime": "Carrefour : clic sur un carrefour pour changer son régime (automatique → feux → stop → cédez-le-passage → priorité à droite) · Maj + clic : giratoire.",
	"giratoire": "Giratoire : clic sur un carrefour d'au moins trois routes pour le transformer en rond-point.",
	"echangeur": "Échangeur : clic là où une route passe au-dessus (ou au-dessous) d'une autoroute ; quatre bretelles la relient à la route.",
}
var junction_action := "regime"


func set_junction_tool(action := "") -> void:
	tool = Tool.JUNCTION
	if JUNCTION_ACTIONS.has(action):
		junction_action = action
	cancel()
	info_changed.emit(String(JUNCTION_HELP[junction_action]))


# --- Échangeurs -----------------------------------------------------------------------------

## Distance entre le pont de l'échangeur et le départ des bretelles, le long de
## l'autoroute, et le long de la route (m).
const RAMP_ALONG := 200.0
const RAMP_ROAD := 80.0


## Croisement dénivelé entre une autoroute (ou voie express) et une route, près
## de p : {main, road, x (Vector2), dy} ou {}.
func separated_crossing_near(p: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	var near := edges_near(p, radius + 40.0)
	for ma in near:
		var ea: Dictionary = network.edges[ma]
		if not TransportTypes.takes_ramps(ea.t):
			continue
		for rd in near:
			var er: Dictionary = network.edges[rd]
			if rd == ma or TransportTypes.mode_of(er.t) != TransportTypes.Mode.ROAD:
				continue
			if TransportTypes.is_separated(er.t) or TransportTypes.is_ramp(er.t) or TransportTypes.is_ring(er.t):
				continue
			var pa: PackedVector3Array = ea.pts
			var pr: PackedVector3Array = er.pts
			for i in pa.size() - 1:
				var a0 := Vector2(pa[i].x, pa[i].z)
				var a1 := Vector2(pa[i + 1].x, pa[i + 1].z)
				if a0.distance_to(Vector2(p.x, p.z)) > radius + 40.0:
					continue
				for j in pr.size() - 1:
					var hit: Variant = Geometry2D.segment_intersects_segment(a0, a1, Vector2(pr[j].x, pr[j].z), Vector2(pr[j + 1].x, pr[j + 1].z))
					if hit == null:
						continue
					var x: Vector2 = hit
					var d := x.distance_to(Vector2(p.x, p.z))
					if d >= best_d:
						continue
					var ha := lerpf(pa[i].y, pa[i + 1].y, a0.distance_to(x) / maxf(a0.distance_to(a1), 1e-6))
					var nr := network.nearest_on_edge(rd, Vector3(x.x, 0, x.y))
					var hr: float = (nr.pos as Vector3).y
					var tun: bool = network.struct_at(rd, float(nr.s)) == TransportTypes.Struct.TUNNEL \
						or network.struct_at(ma, float(pa_s(ea, i, a0, x))) == TransportTypes.Struct.TUNNEL
					if absf(hr - ha) < CLEARANCE - 0.5 and not tun:
						continue
					best_d = d
					best = {"main": ma, "road": rd, "x": x, "dy": hr - ha}
	return best


## Distance le long du tronçon e du point x, situé sur son segment i.
static func pa_s(e: Dictionary, i: int, a0: Vector2, x: Vector2) -> float:
	var d: PackedFloat32Array = e.d
	return float(d[i]) + a0.distance_to(x)


## Échangeur en losange là où une route passe au-dessus ou au-dessous d'une
## autoroute : deux sorties et deux entrées (bretelles à sens unique) qui
## rejoignent la route de part et d'autre. Renvoie {ok, reason, ramps}.
func make_interchange(p: Vector3) -> Dictionary:
	var xc := separated_crossing_near(p, 60.0)
	if xc.is_empty():
		return {"ok": false, "reason": "Pas d'échangeur possible ici : il faut une route qui passe au-dessus ou au-dessous d'une autoroute (ou d'une voie express). Pose la route en travers de l'autoroute, elle passe dessus toute seule."}
	var ma: int = xc.main
	var rd: int = xc.road
	var x: Vector2 = xc.x
	var ha := network.nearest_on_edge(ma, Vector3(x.x, 0, x.y))
	var hr := network.nearest_on_edge(rd, Vector3(x.x, 0, x.y))
	var ea: Dictionary = network.edges[ma]
	var er: Dictionary = network.edges[rd]
	var sa: float = ha.s
	var sr: float = hr.s
	if sa < RAMP_ALONG + 20.0 or float(ea.len) - sa < RAMP_ALONG + 20.0:
		return {"ok": false, "reason": "Autoroute trop courte : il faut au moins %d m de chaque côté du pont pour les bretelles." % roundi(RAMP_ALONG + 20.0)}
	if sr < RAMP_ROAD + 10.0 or float(er.len) - sr < RAMP_ROAD + 10.0:
		return {"ok": false, "reason": "Route trop courte : il faut au moins %d m de chaque côté de l'autoroute." % roundi(RAMP_ROAD + 10.0)}
	var t3 := network.tangent_at(ma, sa)
	var d := Vector2(t3.x, t3.z).normalized()
	var right := Vector2(-d.y, d.x)
	var r3 := network.tangent_at(rd, sr)
	var rdir := Vector2(r3.x, r3.z).normalized()
	if absf(rdir.dot(d)) > cos(deg_to_rad(40.0)):
		return {"ok": false, "reason": "La route croise l'autoroute trop en biais pour un échangeur (au moins 40°)."}
	# Côté droit de l'autoroute dans le sens +d : la route y part vers sr + sgn·RAMP_ROAD.
	var sgn := 1.0 if rdir.dot(right) > 0.0 else -1.0
	var a0 := _xz(network.point_at(ma, sa - RAMP_ALONG))
	var a1 := _xz(network.point_at(ma, sa + RAMP_ALONG))
	var d0 := _xz(network.tangent_at(ma, sa - RAMP_ALONG)).normalized()
	var d1 := _xz(network.tangent_at(ma, sa + RAMP_ALONG)).normalized()
	var p_right := _xz(network.point_at(rd, sr + sgn * RAMP_ROAD))
	var p_left := _xz(network.point_at(rd, sr - sgn * RAMP_ROAD))
	var k := RAMP_ALONG * 0.6
	# Sortie et entrée de chaque sens (on roule à droite).
	var paths := [
		RoutePlanner.bezier(a0, a0 + d0 * k, p_right), # sortie, sens +d
		RoutePlanner.bezier(p_right, a1 - d1 * k, a1), # entrée, sens +d
		RoutePlanner.bezier(a1, a1 - d1 * k, p_left), # sortie, sens -d
		RoutePlanner.bezier(p_left, a0 + d0 * k, a0), # entrée, sens -d
	]
	# On vérifie tout avant de construire.
	var keep_level := level
	level = "auto"
	for path in paths:
		var pl := evaluate("bretelle", {}, path)
		if not pl.ok:
			level = keep_level
			return {"ok": false, "reason": "Échangeur impossible : " + String(pl.reason)}
	var ramps: Array[int] = []
	for path in paths:
		var res := build_path("bretelle", {}, path)
		if not res.ok:
			level = keep_level
			return {"ok": false, "reason": "Échangeur incomplet : " + String(res.reason), "ramps": ramps}
		ramps.append_array(res.edges)
	level = keep_level
	return {"ok": true, "ramps": ramps}


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Transforme un carrefour en giratoire : chaque branche est coupée sur un
## cercle autour du carrefour, et des arcs à sens unique (sens inverse des
## aiguilles d'une montre, vu du dessus) relient les branches. Renvoie {ok, reason}.
func make_roundabout(nid: int) -> Dictionary:
	if not network.nodes.has(nid) or network.node_mode(nid) != TransportTypes.Mode.ROAD:
		return {"ok": false, "reason": "Il faut un carrefour routier."}
	var adj: Array = (network.adjacency[nid] as Array).duplicate()
	if adj.size() < 3:
		return {"ok": false, "reason": "Il faut au moins trois routes qui se rejoignent."}
	var hw := 0.0
	for eid in adj:
		var e: Dictionary = network.edges[eid]
		if TransportTypes.is_ring(e.t):
			return {"ok": false, "reason": "C'est déjà un giratoire."}
		if TransportTypes.is_ramp(e.t) or TransportTypes.is_separated(e.t):
			return {"ok": false, "reason": "Pas de giratoire sur une autoroute ou une bretelle."}
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
			return {"ok": false, "reason": "Seulement entre des routes."}
		hw = maxf(hw, network.half_width(eid))
	var ring_hw := TransportTypes.width_of("giratoire", {}) * 0.5
	var r := clampf(hw * 2.2 + ring_hw + 4.0, 14.0, 34.0)
	for eid in adj:
		if float(network.edges[eid].len) < r + 12.0:
			return {"ok": false, "reason": "Branche trop courte pour un giratoire de %d m de rayon." % roundi(r)}
	var c := network.node_pos(nid)
	var ends: Array[int] = []
	for eid in adj:
		var e: Dictionary = network.edges[eid]
		var p := network.split_edge(eid, r if e.a == nid else float(e.len) - r, 0.0)
		ends.append(p)
		for piece in (network.adjacency.get(nid, []) as Array).duplicate():
			if network.other_end(piece, nid) == p:
				network.remove_edge(piece)
				break
	var ang := func(n: int) -> float:
		var q := network.node_pos(n) - c
		return atan2(-q.z, q.x)
	ends.sort_custom(func(x: int, y: int) -> bool: return ang.call(x) < ang.call(y))
	for i in ends.size():
		var a := ends[i]
		var b := ends[(i + 1) % ends.size()]
		var pa := network.node_pos(a)
		var pb := network.node_pos(b)
		var a0: float = ang.call(a)
		var a1: float = ang.call(b)
		if a1 <= a0:
			a1 += TAU
		var ra := Vector2(pa.x - c.x, pa.z - c.z).length()
		var rb := Vector2(pb.x - c.x, pb.z - c.z).length()
		var n := maxi(4, ceili((a1 - a0) * r / TransportTypes.STEP))
		var pts := PackedVector3Array()
		var st := PackedByteArray()
		for k in n + 1:
			var u := float(k) / n
			var th := lerpf(a0, a1, u)
			var rr := lerpf(ra, rb, u)
			pts.append(Vector3(c.x + cos(th) * rr, lerpf(pa.y, pb.y, u), c.z - sin(th) * rr))
			st.append(TransportTypes.Struct.GROUND)
		network.add_edge(a, b, "giratoire", pts, st)
	roundabouts.append({"c": c, "r": r - ring_hw})
	network.changed.emit()
	return {"ok": true, "radius": r, "nodes": ends}


## Îlots centraux : on garde ceux dont l'anneau existe encore.
func _refresh_islands() -> void:
	if _islands == null:
		return
	var keep: Array = []
	for g in roundabouts:
		var c: Vector3 = g.c
		var alive := false
		for eid in network.edges:
			var e: Dictionary = network.edges[eid]
			if TransportTypes.is_ring(e.t) and network.nearest_on_edge(eid, c).dist < float(g.r) + 6.0:
				alive = true
				break
		if alive:
			keep.append(g)
	roundabouts = keep
	for ch in _islands.get_children():
		ch.queue_free()
	for g in roundabouts:
		var island := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(g.r)
		cm.bottom_radius = float(g.r) + 0.3
		cm.height = 0.6
		cm.radial_segments = 32
		cm.rings = 1
		island.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("6f8f4e")
		m.roughness = 0.9
		island.material_override = m
		island.position = (g.c as Vector3) + Vector3(0, 0.05, 0)
		_islands.add_child(island)
		var kerb := MeshInstance3D.new()
		var km := CylinderMesh.new()
		km.top_radius = float(g.r) + 0.35
		km.bottom_radius = float(g.r) + 0.35
		km.height = 0.4
		km.radial_segments = 32
		kerb.mesh = km
		var mk := StandardMaterial3D.new()
		mk.albedo_color = Color("c9c5bd")
		kerb.material_override = mk
		kerb.position = (g.c as Vector3) + Vector3(0, -0.02, 0)
		_islands.add_child(kerb)
		# Un arbre au milieu.
		var tree := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0
		tm.bottom_radius = minf(2.2, float(g.r) * 0.4)
		tm.height = 5.0
		tm.radial_segments = 6
		tree.mesh = tm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color("3f7d3a")
		tree.material_override = mt
		tree.position = (g.c as Vector3) + Vector3(0, 2.8, 0)
		_islands.add_child(tree)


## Carrefour routier le plus proche du point p (-1 si aucun à moins de sa largeur).
func junction_at(p: Vector3) -> int:
	var best := -1
	var best_d := INF
	for nid in junctions.controlled_nodes():
		var q := network.node_pos(nid)
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < maxf(network.node_half_width(nid) * 1.6, 8.0) and d < best_d:
			best_d = d
			best = nid
	return best


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


## Surface d'une rivière ou d'un lac (NAN s'il n'y en a pas) : les voies l'enjambent.
func water_surface(x: float, z: float) -> float:
	if world == null:
		return NAN
	return world.water_surface_at(x, z)


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
		if tool == Tool.JUNCTION:
			if junction_action == "echangeur":
				var xres := make_interchange(_cursor)
				message.emit("Échangeur construit : 2 sorties et 2 entrées." if xres.ok else String(xres.reason))
				return
			var nid := junction_at(_cursor)
			if nid >= 0 and (mb.shift_pressed or junction_action == "giratoire"):
				var res := make_roundabout(nid)
				message.emit("Giratoire de %d m de rayon construit." % roundi(res.radius) if res.ok else String(res.reason))
				return
			if nid < 0:
				if not separated_crossing_near(_cursor, 40.0).is_empty():
					message.emit("Ici, la route passe au-dessus de l'autoroute : choisis « Échangeur » pour la relier par des bretelles.")
				else:
					message.emit("Pas de carrefour ici (il faut au moins trois routes qui se rejoignent).")
			else:
				junctions.cycle(nid)
				info_changed.emit(junctions.describe(nid) + " · clic : régime suivant")
				message.emit(String(JunctionControl.MODE_NAMES[junctions.mode_of(nid)]) + (" : " + String(JunctionControl.MODE_NAMES[junctions.kind(nid)]).to_lower() if junctions.mode_of(nid) == "auto" else "") + ".")
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
		elif key.keycode == KEY_N and tool == Tool.BUILD:
			cycle_level()
			message.emit(String(LEVEL_NAMES[level]) + ".")
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
	elif tool == Tool.JUNCTION:
		var nid := junction_at(_cursor) if _cursor_valid else -1
		if junction_action == "echangeur":
			pass
		elif nid >= 0:
			info_changed.emit(junctions.describe(nid) + (" · clic : giratoire" if junction_action == "giratoire" else " · clic : régime suivant · Maj + clic : giratoire"))
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
	if int(p.get("passes", 0)) > 0:
		s += " · passe %s de %d voie%s" % ["au-dessus ou dessous" if level == "auto" else ("au-dessus" if level == "dessus" else "dessous"),
			p.passes, "s" if int(p.passes) > 1 else ""]
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
	var plan := RoutePlanner.plan(id, path, h0, h1, ground_height, water_surface)
	plan.snap_a = sa
	plan.snap_b = sb
	plan.crossings = []
	if not sa.is_empty() and not sb.is_empty() and int(sa.node) >= 0 and sa.node == sb.node:
		plan.ok = false
		plan.reason = "Le départ et l'arrivée sont au même endroit."
		return plan
	if not plan.ok:
		return plan
	if not TransportTypes.is_ramp(id) and not TransportTypes.is_separated(id):
		for snap in [sa, sb]:
			if not (snap as Dictionary).is_empty() and _snap_takes_ramps(snap):
				plan.ok = false
				plan.reason = "On ne se raccorde pas directement à une autoroute : pose une bretelle (classe « Bretelle ») ou un échangeur (outil J)."
				return plan
	if is_blocked(id, plan.pts, plan.st):
		plan.ok = false
		plan.reason = "Un bâtiment se trouve sur le tracé."
		return plan
	var pts: PackedVector3Array = plan.pts
	var st: PackedByteArray = plan.st
	var crossings := _find_crossings(mode, pts, st)
	var w := TransportTypes.width_of(id, s)
	# Passages dessus / dessous : on recalcule le profil avec des hauteurs imposées.
	var forced := _forced_crossings(id, crossings, sa, sb)
	plan.passes = forced.size()
	if not forced.is_empty():
		var bounds := []
		var need := 0.0
		for f in forced:
			var c: Dictionary = f[0]
			var half: float = (w * 0.5 + float(c.hw)) / maxf(sin(float(c.angle)), 0.3) + 2.0
			var eh: float = (c.pos as Vector3).y
			if f[1] == "dessus":
				bounds.append({"s0": float(c.along) - half, "s1": float(c.along) + half, "lo": eh + CLEARANCE + 0.4,
					"st": TransportTypes.Struct.BRIDGE})
			else:
				bounds.append({"s0": float(c.along) - half, "s1": float(c.along) + half, "hi": eh - CLEARANCE - 0.8,
					"st": TransportTypes.Struct.TUNNEL})
			need = maxf(need, CLEARANCE + 0.8 + absf(float(c.dy)))
		var fplan := RoutePlanner.plan(id, path, h0, h1, ground_height, water_surface, bounds)
		fplan.snap_a = sa
		fplan.snap_b = sb
		fplan.crossings = []
		fplan.passes = forced.size()
		if not fplan.ok:
			return fplan
		var grade := float(TransportTypes.get_type(id).max_grade)
		if float(fplan.max_grade) > grade * 1.05 + 0.002:
			fplan.ok = false
			fplan.reason = "Pas assez de longueur pour passer %s : il faut environ %d m de rampe de chaque côté (pente maxi %s %%)." % [
				"dessus" if forced[0][1] == "dessus" else "dessous", ceili(need / grade), TransportTypes._num(grade * 100.0)]
			return fplan
		plan = fplan
		pts = plan.pts
		st = plan.st
		if is_blocked(id, pts, st):
			plan.ok = false
			plan.reason = "Un bâtiment se trouve sur le tracé."
			return plan
		crossings = _find_crossings(mode, pts, st)
	plan.crossings = crossings
	for c in crossings:
		if not c.same_mode and not c.compatible and absf(c.dy) < CLEARANCE:
			plan.ok = false
			plan.reason = "Croisement impossible avec %s ici." % String(TransportTypes.get_type(c.type).name).to_lower()
			return plan
		if absf(c.dy) >= JUNCTION_DY and absf(c.dy) < CLEARANCE:
			plan.ok = false
			plan.reason = "Croisement à %s m de hauteur : trop haut pour un carrefour, trop bas pour passer dessus (%s m minimum). Touche N : forcer un pont ou un tunnel." % [
				TransportTypes._num(snappedf(absf(c.dy), 0.1)), TransportTypes._num(CLEARANCE)]
			return plan
	var clash := _find_overlap(mode, w, pts, st, sa, sb, crossings, id)
	if not clash.is_empty():
		plan.ok = false
		plan.reason = "Chevauche %s. Raccorde-toi dessus (clic sur la voie) ou croise-la franchement." % String(clash.name).to_lower()
		plan.clash = clash.pos
	return plan


## Croisements à franchir par un pont ou un tunnel : [[croisement, "dessus" ou
## "dessous"], …]. Mode automatique : seulement les autoroutes et voies express
## (jamais de carrefour à niveau dessus). Les raccords aux extrémités comptent pas.
func _forced_crossings(id: String, crossings: Array, sa: Dictionary, sb: Dictionary) -> Array:
	var out := []
	for c in crossings:
		if absf(float(c.dy)) >= CLEARANCE:
			continue
		var cp: Vector3 = c.pos
		var near_end := false
		for snap in [sa, sb]:
			var sd: Dictionary = snap
			if not sd.is_empty() and Vector2(cp.x - sd.pos.x, cp.z - sd.pos.z).length() < 4.0:
				near_end = true
		if near_end:
			continue
		var how := level
		if how == "auto":
			if not (TransportTypes.is_separated(id) or TransportTypes.is_separated(String(c.type))):
				continue
			how = "dessous" if float(c.dy) < -1.0 else "dessus"
		out.append([c, how])
	return out


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


## Tronçons qui passent à moins de radius (environ) du point p, sans doublon.
func edges_near(p: Vector3, radius: float) -> Array[int]:
	var out: Array[int] = []
	var seen := {}
	for item in _query(Vector2(p.x - radius, p.z - radius), Vector2(p.x + radius, p.z + radius)):
		var eid: int = item[0]
		if not seen.has(eid):
			seen[eid] = true
			out.append(eid)
	return out


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
		sa: Dictionary, sb: Dictionary, crossings: Array, type_id := "") -> Dictionary:
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
		# Une bretelle longe l'autoroute sur une centaine de mètres avant de s'en écarter.
		var ramp := TransportTypes.is_ramp(type_id) and _snap_takes_ramps(sd)
		allowed.append([Vector2(p.x, p.z), 260.0 if ramp else (hw + other) * 2.5 + 2.0, ramp])
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
		var ramp_zone := false
		for zone in allowed:
			if q.distance_to(zone[0]) < float(zone[1]):
				if zone.size() > 2 and zone[2]:
					ramp_zone = true
				else:
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
			if ramp_zone and (TransportTypes.takes_ramps(e.t) or TransportTypes.is_ramp(e.t)):
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


## L'accroche est-elle sur une autoroute ou une voie express (ou un de ses nœuds) ?
func _snap_takes_ramps(sd: Dictionary) -> bool:
	if int(sd.get("node", -1)) >= 0:
		for eid in network.adjacency.get(int(sd.node), []):
			if TransportTypes.takes_ramps(network.edges[eid].t):
				return true
		return false
	return int(sd.get("edge", -1)) >= 0 and TransportTypes.takes_ramps(network.edges[int(sd.edge)].t)


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
		# Les talus ne bouchent pas les rivières.
		for c in works.keys():
			if not is_nan(water_surface(c.x + 0.5, c.y + 0.5)):
				works.erase(c)

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
	var d := network.to_dict()
	d["stations"] = stations.to_dict()
	d["carrefours"] = junctions.to_dict()
	var g := []
	for r in roundabouts:
		var c: Vector3 = r.c
		g.append([snappedf(c.x, 0.01), snappedf(c.y, 0.01), snappedf(c.z, 0.01), snappedf(float(r.r), 0.01)])
	d["giratoires"] = g
	return d


func from_dict(data: Dictionary) -> void:
	stations.clear()
	traffic.clear()
	cancel()
	roundabouts.clear()
	for g in data.get("giratoires", []):
		roundabouts.append({"c": Vector3(float(g[0]), float(g[1]), float(g[2])), "r": float(g[3])})
	network.from_dict(data)
	junctions.from_dict(data.get("carrefours", {}))
	stations.from_dict(data.get("stations", {}))
