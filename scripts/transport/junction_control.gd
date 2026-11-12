class_name JunctionControl
extends Node3D
## Régime des carrefours routiers (3 branches ou plus) : feux tricolores,
## stop, cédez-le-passage ou priorité à droite. Le régime est choisi
## automatiquement d'après les classes de voies qui se croisent ; le joueur
## peut l'imposer avec l'outil « Carrefour ».
##
## Les feux fonctionnent par phases : deux branches dans le prolongement l'une
## de l'autre partagent la même phase. Chaque phase a son vert, son orange,
## puis un court rouge intégral avant la suivante.

signal changed

const MODES: Array[String] = ["auto", "feux", "stop", "cedez", "droite"]
const MODE_NAMES := {
	"auto": "Automatique", "feux": "Feux tricolores", "stop": "Stop sur les voies secondaires",
	"cedez": "Cédez-le-passage sur les voies secondaires", "droite": "Priorité à droite",
	"giratoire": "Giratoire (cédez-le-passage à l'entrée)",
}
const GREEN := 14.0
const AMBER := 3.0
const ALL_RED := 2.0
## Passage piéton : largeur de la bande (m), devant la ligne d'arrêt.
const CROSS_W := 3.0
const RED := 0
const ORANGE := 1
const VERT := 2

var network: TransportNetwork
## Régimes imposés par le joueur : id de nœud -> mode (sauf « auto »).
var overrides: Dictionary = {}
var time := 0.0
## id de nœud -> {kind, auto, phase: {eid: int}, phases, major: {eid: true}, right: {eid: eid}, off}
var _info: Dictionary = {}
var _trims: Dictionary = {}
var _visuals: Dictionary = {} # id de nœud -> Node3D
var _heads: Array = [] # [{nid, eid, lamps: [rouge, orange, vert], state}]
var _mats: Dictionary = {}
## Passages piétons occupés : Vector2i(nœud, tronçon) -> nombre de piétons qui traversent.
var crossing: Dictionary = {}


func _init() -> void:
	name = "Carrefours"
	for k in ["pole", "head", "off", "red", "amber", "green", "white", "sign_red", "sign_white"]:
		var m := StandardMaterial3D.new()
		m.roughness = 0.7
		_mats[k] = m
	_mats.pole.albedo_color = Color("6b7076")
	_mats.head.albedo_color = Color("22252a")
	_mats.off.albedo_color = Color("35383d")
	_mats.white.albedo_color = Color("f2f0e6")
	_mats.sign_red.albedo_color = Color("c8202a")
	_mats.sign_white.albedo_color = Color("f4f4f4")
	for pair in [["red", Color("ff2a1f")], ["amber", Color("ffb21f")], ["green", Color("2cff6a")]]:
		var m: StandardMaterial3D = _mats[pair[0]]
		m.albedo_color = pair[1]
		m.emission_enabled = true
		m.emission = pair[1]
		m.emission_energy_multiplier = 2.5


func setup(net: TransportNetwork) -> void:
	network = net
	network.changed.connect(rebuild)
	rebuild()


func clear() -> void:
	overrides.clear()
	rebuild()


## Recalcule le régime de tous les carrefours (après une modification du réseau).
func rebuild() -> void:
	if network == null:
		return
	_trims = TransportView.compute_trims(network)
	for nid in overrides.keys():
		if not network.nodes.has(nid):
			overrides.erase(nid)
	_info.clear()
	for nid in network.nodes:
		if network.node_mode(nid) == TransportTypes.Mode.ROAD and network.degree(nid) >= 3:
			_info[nid] = _analyse(nid)
	_rebuild_visuals()


func is_controlled(nid: int) -> bool:
	return _info.has(nid)


## Régime effectif : "feux", "stop", "cedez", "droite" ou "" (pas un carrefour).
func kind(nid: int) -> String:
	return String(_info[nid].kind) if _info.has(nid) else ""


## Régime choisi par le joueur ("auto" s'il n'en a pas imposé).
func mode_of(nid: int) -> String:
	return String(overrides.get(nid, "auto"))


func controlled_nodes() -> Array:
	return _info.keys()


## Distance entre le centre du carrefour et la ligne d'arrêt de la branche eid.
func trim(eid: int, nid: int) -> float:
	var v: Vector2 = _trims.get(eid, Vector2.ZERO)
	var e: Dictionary = network.edges[eid]
	return v.x if e.a == nid else v.y


## Passage piéton sur la branche eid du carrefour nid : routes à trottoirs
## seulement, et si le tronçon est assez long.
func has_crosswalk(nid: int, eid: int) -> bool:
	if not _info.has(nid) or not network.edges.has(eid):
		return false
	var e: Dictionary = network.edges[eid]
	if String(TransportTypes.get_type(e.t).get("side_kind", "")) != "trottoir":
		return false
	var other := network.other_end(eid, nid)
	return float(e.len) - trim(eid, nid) - trim(eid, other) > CROSS_W * 2.0 + 6.0


## Distance entre le centre du carrefour et la ligne d'arrêt (derrière le passage piéton).
func stop_dist(eid: int, nid: int) -> float:
	return trim(eid, nid) + (CROSS_W + 0.6 if has_crosswalk(nid, eid) else 0.6)


## Un piéton traverse-t-il la branche eid du carrefour nid ?
func crosswalk_busy(nid: int, eid: int) -> bool:
	return int(crossing.get(Vector2i(nid, eid), 0)) > 0


func is_major(nid: int, eid: int) -> bool:
	return _info.has(nid) and (_info[nid].major as Dictionary).has(eid)


## Branche située à droite d'un véhicule qui arrive par eid (-1 s'il n'y en a pas).
func right_of(nid: int, eid: int) -> int:
	return int((_info[nid].right as Dictionary).get(eid, -1)) if _info.has(nid) else -1


## Couleur du feu pour la branche eid : RED, ORANGE ou VERT.
func light(nid: int, eid: int) -> int:
	if not _info.has(nid):
		return VERT
	var info: Dictionary = _info[nid]
	var slot := GREEN + AMBER + ALL_RED
	var t := fmod(time + float(info.off), slot * int(info.phases))
	var cur := floori(t / slot)
	if int((info.phase as Dictionary).get(eid, -1)) != cur:
		return RED
	var local := t - cur * slot
	if local < GREEN:
		return VERT
	return ORANGE if local < GREEN + AMBER else RED


## Passe au régime suivant (auto → feux → stop → cédez → priorité à droite).
func cycle(nid: int) -> String:
	if not _info.has(nid) or kind(nid) == "giratoire":
		return ""
	var i := MODES.find(mode_of(nid))
	set_mode(nid, MODES[(i + 1) % MODES.size()])
	return mode_of(nid)


func set_mode(nid: int, mode: String) -> void:
	if not _info.has(nid) or not MODES.has(mode) or kind(nid) == "giratoire":
		return
	if mode == "auto":
		overrides.erase(nid)
	else:
		overrides[nid] = mode
	_info[nid] = _analyse(nid)
	_rebuild_visuals()
	changed.emit()


func describe(nid: int) -> String:
	if not _info.has(nid):
		return ""
	var k := kind(nid)
	var txt := "Carrefour à %d branches : %s" % [network.degree(nid), String(MODE_NAMES[k]).to_lower()]
	if k == "giratoire":
		return "Entrée de giratoire : cédez-le-passage aux véhicules de l'anneau"
	if mode_of(nid) == "auto":
		txt += " (choix automatique)"
	return txt


func tick(delta: float) -> void:
	time += delta
	for h in _heads:
		var s := light(h.nid, h.eid)
		if s == int(h.state):
			continue
		h.state = s
		var lamps: Array = h.lamps
		(lamps[0] as MeshInstance3D).material_override = _mats.red if s == RED else _mats.off
		(lamps[1] as MeshInstance3D).material_override = _mats.amber if s == ORANGE else _mats.off
		(lamps[2] as MeshInstance3D).material_override = _mats.green if s == VERT else _mats.off


# --- Analyse d'un carrefour --------------------------------------------------------

func _analyse(nid: int) -> Dictionary:
	var adj: Array = network.adjacency.get(nid, [])
	var dirs := {}
	var kmh := {}
	for eid in adj:
		dirs[eid] = network.leave_dir(eid, nid)
		kmh[eid] = float(TransportTypes.get_type(network.edges[eid].t).get("kmh", 30.0))
	# Phases : chaque branche avec celle qui lui fait le plus face.
	var phase := {}
	var n_phases := 0
	for eid in adj:
		if phase.has(eid):
			continue
		phase[eid] = n_phases
		var best := -1
		var best_dot := -0.7
		for o in adj:
			if phase.has(o):
				continue
			var d: float = (dirs[eid] as Vector3).dot(dirs[o])
			if d < best_dot:
				best_dot = d
				best = o
		if best >= 0:
			phase[best] = n_phases
		n_phases += 1
	# Voies principales : les deux plus rapides, de préférence alignées.
	var order: Array = adj.duplicate()
	order.sort_custom(func(x: int, y: int) -> bool: return float(kmh[x]) > float(kmh[y]))
	var major := {order[0]: true}
	var second := -1
	for o in order.slice(1):
		if float(kmh[o]) < float(kmh[order[1]]):
			break
		if second < 0 or (dirs[order[0]] as Vector3).dot(dirs[o]) < (dirs[order[0]] as Vector3).dot(dirs[second]):
			second = o
	major[second] = true
	# Branche de droite pour chaque arrivée.
	var right := {}
	for eid in adj:
		var fwd: Vector3 = -(dirs[eid] as Vector3)
		var r := Vector3(-fwd.z, 0, fwd.x)
		var best := -1
		var best_dot := 0.3
		for o in adj:
			if o == eid:
				continue
			var d := r.dot(dirs[o])
			if d > best_dot:
				best_dot = d
				best = o
		right[eid] = best
	var speeds: Array = []
	for eid in order:
		speeds.append(kmh[eid])
	var auto := _auto_kind(speeds)
	var mode: String = overrides.get(nid, "auto")
	# Entrée de giratoire : l'anneau est prioritaire.
	var ring := {}
	for eid in adj:
		if TransportTypes.is_oneway(network.edges[eid].t):
			ring[eid] = true
	if not ring.is_empty():
		overrides.erase(nid)
		mode = "auto"
		auto = "giratoire"
		major = ring
	return {"kind": auto if mode == "auto" else mode, "auto": auto, "phase": phase, "phases": maxi(n_phases, 1),
		"major": major, "right": right, "off": fmod(float(nid) * 7.3, (GREEN + AMBER + ALL_RED) * maxi(n_phases, 1))}


## Régime par défaut, d'après les vitesses (km/h, de la plus forte à la plus faible).
static func _auto_kind(sp: Array) -> String:
	var top: float = sp[0]
	var low: float = sp[sp.size() - 1]
	if is_equal_approx(top, low):
		return "droite" if top <= 30.0 else "feux"
	if float(sp[1]) > float(sp[2]):
		if sp.size() >= 4 and low >= 50.0:
			return "feux"
		return "stop" if top >= 80.0 and low <= 50.0 else "cedez"
	return "feux" if float(sp[1]) >= 50.0 else "cedez"


# --- Signalisation ----------------------------------------------------------------------

func _rebuild_visuals() -> void:
	for nid in _visuals:
		(_visuals[nid] as Node).queue_free()
	_visuals.clear()
	_heads.clear()
	for nid in _info:
		var root := Node3D.new()
		root.name = "Carrefour_%d" % nid
		add_child(root)
		_visuals[nid] = root
		var k := kind(nid)
		for eid in network.adjacency.get(nid, []):
			if has_crosswalk(nid, eid):
				_crosswalk(root, nid, eid)
		if k == "droite":
			continue
		for eid in network.adjacency.get(nid, []):
			if k != "feux" and is_major(nid, eid):
				continue
			_approach_signs(root, nid, eid, k)


## Bandes blanches du passage piéton, sur toute la chaussée.
func _crosswalk(root: Node3D, nid: int, eid: int) -> void:
	var e: Dictionary = network.edges[eid]
	var d := trim(eid, nid) + CROSS_W * 0.5
	var base := network.point_at(eid, d if e.a == nid else float(e.len) - d)
	var out := network.leave_dir(eid, nid)
	var right := Vector3(-out.z, 0, out.x)
	var road := network.half_width(eid) - float(TransportTypes.get_type(e.t).get("side", 1.5))
	var n := maxi(2, floori(road * 2.0 / 1.0))
	var mm := MultiMeshInstance3D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.03, CROSS_W - 0.4)
	mesh.mesh = bm
	mesh.instance_count = n
	var basis := Basis.looking_at(out, Vector3.UP)
	for i in n:
		var lat := -road + (float(i) + 0.5) * road * 2.0 / float(n)
		mesh.set_instance_transform(i, Transform3D(basis, base + right * lat + Vector3(0, 0.1, 0)))
	mm.multimesh = mesh
	mm.material_override = _mats.white
	root.add_child(mm)


func _approach_signs(root: Node3D, nid: int, eid: int, k: String) -> void:
	var e: Dictionary = network.edges[eid]
	var tr := stop_dist(eid, nid) - 0.6
	var s := tr if e.a == nid else float(e.len) - tr
	var base := network.point_at(eid, s)
	var out := network.leave_dir(eid, nid) # vers l'extérieur du carrefour
	var fwd := -out # sens de l'arrivée
	var right := Vector3(-fwd.z, 0, fwd.x)
	var hw := network.half_width(eid)
	var lanes_w := hw
	var offsets := TransportTypes.lane_offsets(e.t, e.w)
	if not offsets.is_empty():
		var spec := TransportTypes.normalize(e.t, e.w)
		lanes_w = offsets[offsets.size() - 1] + float(spec.get("lane_w", 3.0)) * 0.5
	var basis := Basis.looking_at(fwd, Vector3.UP)
	# Ligne d'arrêt peinte sur les voies d'arrivée.
	var line := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(lanes_w, 0.03, 0.5 if k == "stop" or k == "feux" else 0.3)
	line.mesh = bm
	line.material_override = _mats.white
	line.basis = basis
	line.position = base + right * (lanes_w * 0.5) + Vector3(0, 0.1, 0) - fwd * 0.3
	root.add_child(line)
	var foot := base + right * (hw + 0.5) - fwd * 0.6
	if k == "feux":
		_pole(root, foot, 3.9)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.5, 1.35, 0.32)
		head.mesh = hm
		head.material_override = _mats.head
		head.basis = basis
		head.position = foot + Vector3(0, 3.3, 0)
		root.add_child(head)
		var lamps: Array = []
		for i in 3:
			var lamp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.17
			sm.height = 0.34
			sm.radial_segments = 8
			sm.rings = 4
			lamp.mesh = sm
			lamp.material_override = _mats.off
			lamp.position = foot + Vector3(0, 3.72 - i * 0.41, 0) - fwd * 0.17
			root.add_child(lamp)
			lamps.append(lamp)
		_heads.append({"nid": nid, "eid": eid, "lamps": lamps, "state": -1})
	else:
		_pole(root, foot, 2.3)
		var sign := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.height = 0.05
		if k == "stop":
			cm.top_radius = 0.42
			cm.bottom_radius = 0.42
			cm.radial_segments = 8
		else:
			cm.top_radius = 0.5
			cm.bottom_radius = 0.5
			cm.radial_segments = 3
		sign.mesh = cm
		sign.material_override = _mats.sign_red
		# Disque debout, face à l'arrivée ; le triangle « cédez » pointe vers le bas.
		var b := basis * Basis(Vector3.RIGHT, PI / 2.0)
		if k != "stop":
			b = b * Basis(Vector3.UP, PI / 2.0)
		else:
			b = b * Basis(Vector3.UP, PI / 8.0)
		sign.basis = b
		sign.position = foot + Vector3(0, 2.2, 0) - fwd * 0.04
		root.add_child(sign)
		if k != "stop":
			var inner := MeshInstance3D.new()
			var im := CylinderMesh.new()
			im.height = 0.06
			im.top_radius = 0.3
			im.bottom_radius = 0.3
			im.radial_segments = 3
			inner.mesh = im
			inner.material_override = _mats.sign_white
			inner.basis = b
			inner.position = sign.position - fwd * 0.01
			root.add_child(inner)


func _pole(root: Node3D, foot: Vector3, h: float) -> void:
	var pole := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, h, 0.12)
	pole.mesh = pm
	pole.material_override = _mats.pole
	pole.position = foot + Vector3(0, h * 0.5, 0)
	root.add_child(pole)


# --- Sauvegarde ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var m := {}
	for nid in overrides:
		m[str(nid)] = overrides[nid]
	return {"modes": m}


func from_dict(data: Dictionary) -> void:
	overrides.clear()
	var m: Dictionary = data.get("modes", {})
	for k in m:
		if MODES.has(String(m[k])):
			overrides[int(k)] = String(m[k])
	rebuild()
