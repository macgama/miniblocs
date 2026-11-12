class_name TransportView
extends Node3D
## Affichage low-poly des réseaux : chaussées avec leurs voies, marquages,
## trottoirs, accotements, terre-pleins ; voies ferrées ; chemins ; bouées ;
## ponts (tablier, parapets, piles) et entrées de tunnels ; plateaux de
## carrefour. Tout est généré en code à partir du tracé des tronçons.
##
## Carrefours : chaque voie est coupée (« rognée ») à l'approche du nœud, et le
## nœud reçoit un plateau qui relie proprement les bords des voies : aucune
## chaussée ne se superpose à une autre.

const ASPHALT := Color("3a3d43")
const ASPHALT_SIDE := Color("4b4f56")
const MARKING := Color("f2f0e6")
const CONCRETE := Color("b9b4aa")
const SIDEWALK := Color("c9c5bd")
const KERB := Color("9e9a92")
const GRASS := Color("6f8f4e")
const BALLAST := Color("8a7f72")
const SLEEPER := Color("5b4636")
const STEEL := Color("c6cbd1")
const DARK := Color("1d1f22")
const METRO_TRACE := Color("3a86ff")
## Largeur d'un passage piéton (m), devant la ligne d'arrêt.
const CROSS_W := 3.0
const STONE := Color("b39b78")
## Longueur des travées des viaducs (m).
const VIADUCT_SPAN := 18.0
const VIADUCT_SPAN_LGV := 40.0

## Callable(x, z) -> hauteur du sol (pour les piles de pont).
var ground: Callable
var network: TransportNetwork

var _material: StandardMaterial3D
var _edge_meshes: Dictionary = {} # id de tronçon -> MeshInstance3D
var _edge_keys: Dictionary = {} # id de tronçon -> rognages utilisés
var _node_meshes: Dictionary = {} # id de nœud -> MeshInstance3D
var _node_keys: Dictionary = {} # id de nœud -> ce qui a servi à dessiner son plateau


func _init() -> void:
	_material = make_material()


static func make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	# Faces visibles des deux côtés : pas besoin de soigner le sens des triangles.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func setup(net: TransportNetwork, ground_fn: Callable) -> void:
	network = net
	ground = ground_fn
	network.changed.connect(rebuild)
	rebuild()


## Reconstruit ce qui a changé (tronçons ajoutés, supprimés ou dont les carrefours ont changé).
func rebuild() -> void:
	var trims := compute_trims(network)
	for id in _edge_meshes.keys():
		if not network.edges.has(id):
			(_edge_meshes[id] as Node).queue_free()
			_edge_meshes.erase(id)
			_edge_keys.erase(id)
	for id in network.edges:
		var tr: Vector2 = trims.get(id, Vector2.ZERO)
		var joints := joint_rights(network, id)
		var e0: Dictionary = network.edges[id]
		var clear := Vector2(crosswalk_clear(network, id, e0.a, trims), crosswalk_clear(network, id, e0.b, trims))
		var key := [tr, joints[0], joints[1], clear]
		if _edge_meshes.has(id) and _edge_keys.get(id) == key:
			continue
		var e: Dictionary = network.edges[id]
		var mi: MeshInstance3D = _edge_meshes.get(id)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.name = "Troncon_%d" % id
			mi.material_override = _material
			add_child(mi)
			_edge_meshes[id] = mi
		mi.mesh = build_mesh(e.t, e.w, e.pts, e.st, ground, tr.x, tr.y, joints[0], joints[1], clear.x, clear.y)
		_edge_keys[id] = key
	# Plateaux de carrefour : seuls ceux dont les tronçons ou les rognages ont changé.
	for id in _node_keys.keys():
		if not network.nodes.has(id):
			if _node_meshes.has(id):
				(_node_meshes[id] as Node).queue_free()
				_node_meshes.erase(id)
			_node_keys.erase(id)
	for id in network.nodes:
		var key := [network.node_pos(id)]
		for eid in network.adjacency.get(id, []):
			key.append(network.edges[eid])
			key.append(trims.get(eid, Vector2.ZERO))
		if _node_keys.has(id) and _same_key(_node_keys[id], key):
			continue
		_node_keys[id] = key
		if _node_meshes.has(id):
			(_node_meshes[id] as Node).queue_free()
			_node_meshes.erase(id)
		var m := _junction_mesh(id, trims)
		if m != null:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.material_override = _material
			add_child(mi)
			_node_meshes[id] = mi


## Compare deux clés de carrefour (les tronçons par identité, le reste par valeur).
static func _same_key(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if typeof(a[i]) == TYPE_DICTIONARY:
			if not is_same(a[i], b[i]):
				return false
		elif a[i] != b[i]:
			return false
	return true


func edge_mesh_count() -> int:
	return _edge_meshes.size()


func junction_count() -> int:
	return _node_meshes.size()


## Deux tronçons de même mode qui se suivent presque en ligne droite : pas de
## plateau, les deux maillages se rejoignent bord à bord (onglet).
const SMOOTH_JOINT := TransportNetwork.SMOOTH_JOINT


static func is_smooth_joint(net: TransportNetwork, nid: int) -> bool:
	var adj: Array = net.adjacency.get(nid, [])
	if adj.size() != 2 or adj[0] == adj[1]:
		return false
	var e0: Dictionary = net.edges[adj[0]]
	var e1: Dictionary = net.edges[adj[1]]
	if TransportTypes.mode_of(e0.t) != TransportTypes.mode_of(e1.t):
		return false
	var d0 := net.leave_dir(adj[0], nid)
	var d1 := net.leave_dir(adj[1], nid)
	return rad_to_deg(acos(clampf(d0.dot(d1), -1.0, 1.0))) >= SMOOTH_JOINT


## Voie qui continue tout droit à travers le nœud (raccord simple ou voie
## principale d'une insertion) : [tronçon, tronçon] ou [].
static func through_pair(net: TransportNetwork, nid: int) -> Array:
	if is_smooth_joint(net, nid):
		return net.adjacency[nid]
	return net.merge_through(nid)


## Longueur de bretelle cachée sous la chaussée principale : jusqu'à ce que
## son bord rejoigne le bord de l'autoroute (la bretelle « sort » de la BAU).
static func ramp_trim(net: TransportNetwork, nid: int, eid: int, main: Array) -> float:
	var e: Dictionary = net.edges[eid]
	var hw_main := maxf(net.half_width(main[0]), net.half_width(main[1]))
	var need := hw_main + net.half_width(eid) - 0.3
	var length: float = e.len
	# Tronçon principal du côté où part la bretelle ; on compare les points à
	# même distance du nœud (la bretelle s'écarte en biais, presque parallèle).
	var dr: Vector3 = net.leave_dir(eid, nid)
	var m: int = main[0] if net.leave_dir(main[0], nid).dot(dr) >= net.leave_dir(main[1], nid).dot(dr) else main[1]
	var em: Dictionary = net.edges[m]
	var mlen: float = em.len
	var s := 0.0
	while s < length * 0.8:
		var p: Vector3 = net.point_at(eid, s if e.a == nid else length - s)
		var sm := minf(s, mlen)
		var q: Vector3 = net.point_at(m, sm if em.a == nid else mlen - sm)
		var t: Vector3 = net.tangent_at(m, sm if em.a == nid else mlen - sm)
		var t2 := Vector2(t.x, t.z).normalized()
		if absf((p.x - q.x) * t2.y - (p.z - q.z) * t2.x) >= need:
			return s
		s += 1.0
	return length * 0.8


## Vecteur « droite » imposé au début et à la fin d'un tronçon quand il continue
## un autre tronçon (bissectrice, allongée pour garder la largeur) ; ZERO sinon.
static func joint_rights(net: TransportNetwork, eid: int) -> Array:
	var e: Dictionary = net.edges[eid]
	var out := [Vector3.ZERO, Vector3.ZERO]
	for end in 2:
		var nid: int = e.a if end == 0 else e.b
		var pair := through_pair(net, nid)
		if not pair.has(eid):
			continue
		var other: int = pair[0] if pair[1] == eid else pair[1]
		var d1 := net.leave_dir(eid, nid)
		var d2 := net.leave_dir(other, nid)
		var travel := d1 if end == 0 else -d1
		var t := (d1 - d2) if end == 0 else (d2 - d1)
		t.y = 0.0
		if t.length_squared() < 1e-8:
			continue
		t = t.normalized()
		var r := Vector3(-t.z, 0.0, t.x)
		var own := Vector3(-travel.z, 0.0, travel.x)
		var c := r.dot(own)
		if c < 0.2:
			continue
		out[end] = (r / c).snapped(Vector3.ONE * 0.0001)
	return out


## Passage piéton au bout nid du tronçon eid (carrefour d'au moins 3 routes,
## rue ou avenue assez longue) : longueur à laisser sans marquage, sinon 0.
static func crosswalk_clear(net: TransportNetwork, eid: int, nid: int, trims: Dictionary) -> float:
	var e: Dictionary = net.edges[eid]
	if net.degree(nid) < 3 or net.node_mode(nid) != TransportTypes.Mode.ROAD:
		return 0.0
	if String(TransportTypes.get_type(e.t).get("side_kind", "")) != "trottoir":
		return 0.0
	var tr: Vector2 = trims.get(eid, Vector2.ZERO)
	if float(e.len) - tr.x - tr.y <= CROSS_W * 2.0 + 6.0:
		return 0.0
	return CROSS_W + 0.6


## Longueur à retirer au début (x) et à la fin (y) de chaque tronçon pour
## laisser la place au plateau du carrefour.
static func compute_trims(net: TransportNetwork) -> Dictionary:
	var out := {}
	for nid in net.nodes:
		var mode := net.node_mode(nid)
		if mode != TransportTypes.Mode.ROAD and mode != TransportTypes.Mode.PATH:
			continue
		var adj: Array = net.adjacency.get(nid, [])
		if adj.size() < 2 or is_smooth_joint(net, nid):
			continue
		var main: Array = net.merge_through(nid)
		if not main.is_empty():
			for eid in adj:
				if main.has(eid):
					continue
				var er: Dictionary = net.edges[eid]
				var tr := ramp_trim(net, nid, eid, main)
				var vr: Vector2 = out.get(eid, Vector2.ZERO)
				if er.a == nid:
					vr.x = tr
				if er.b == nid:
					vr.y = tr
				out[eid] = vr
			continue
		var trim := junction_trim(net, nid)
		for eid in adj:
			var e: Dictionary = net.edges[eid]
			var t := minf(trim, float(e.len) * 0.45)
			var v: Vector2 = out.get(eid, Vector2.ZERO)
			if e.a == nid:
				v.x = t
			if e.b == nid:
				v.y = t
			out[eid] = v
	return out


## Rognage nécessaire autour d'un nœud : assez pour que deux voies voisines ne
## se chevauchent pas, compte tenu de l'angle qu'elles font.
static func junction_trim(net: TransportNetwork, nid: int) -> float:
	var adj: Array = net.adjacency.get(nid, [])
	var trim := 0.5
	for i in adj.size():
		for j in range(i + 1, adj.size()):
			var di := net.leave_dir(adj[i], nid)
			var dj := net.leave_dir(adj[j], nid)
			var ang := acos(clampf(di.dot(dj), -1.0, 1.0))
			var hw := maxf(net.half_width(adj[i]), net.half_width(adj[j]))
			if ang > deg_to_rad(170.0):
				trim = maxf(trim, 0.5)
				continue
			trim = maxf(trim, hw / tan(maxf(ang, deg_to_rad(12.0)) * 0.5) + 0.8)
	return minf(trim, 45.0)


func _junction_mesh(nid: int, trims: Dictionary) -> ArrayMesh:
	return junction_mesh(network, nid, trims)


## Plateau de carrefour : chaussée jusqu'aux bordures, et trottoirs qui
## tournent à chaque angle entre deux branches voisines (courbe de raccord).
static func junction_mesh(net: TransportNetwork, nid: int, trims: Dictionary) -> ArrayMesh:
	var arms := _junction_arms(net, nid, trims)
	if arms.is_empty():
		return null
	var col := ASPHALT
	if net.node_mode(nid) == TransportTypes.Mode.PATH:
		col = TransportTypes.get_type(net.edges[net.adjacency[nid][0]].t).get("color", SIDEWALK)
	var center := net.node_pos(nid)
	var c3 := Vector3(center.x, center.y + 0.085, center.z)
	var kit := MeshKit.new()
	var kerb_ring := PackedVector3Array()
	var n := arms.size()
	for i in n:
		var A: Dictionary = arms[i]
		var B: Dictionary = arms[(i + 1) % n]
		# Côté +r de la branche A et côté -r de la branche B.
		var ka: Vector3 = A.p + A.r * float(A.kerb)
		var kb: Vector3 = B.p - B.r * float(B.kerb)
		var oa: Vector3 = A.p + A.r * float(A.hw)
		var ob: Vector3 = B.p - B.r * float(B.hw)
		var kc := _corner(ka, A.d, kb, B.d)
		var oc := _corner(oa, A.d, ob, B.d)
		kerb_ring.append(A.p - A.r * float(A.kerb))
		var steps := 8
		var prev_k := ka
		var prev_o := oa
		for q in range(0, steps + 1):
			var t := float(q) / float(steps)
			var k := _bez(ka, kc, kb, t)
			var o := _bez(oa, oc, ob, t)
			kerb_ring.append(k)
			if q > 0:
				var walk := float(A.hw) > float(A.kerb) + 0.01 or float(B.hw) > float(B.kerb) + 0.01
				if walk:
					var up := Vector3(0, 0.22, 0)
					kit.quad(prev_k + up, k + up, o + up, prev_o + up, SIDEWALK)
					# Bordure du trottoir, côté chaussée.
					kit.quad(prev_k + Vector3(0, 0.085, 0), k + Vector3(0, 0.085, 0), k + up, prev_k + up, KERB)
				# Bord extérieur (cache le vide entre le plateau et le sol).
				var top := Vector3(0, 0.22 if walk else 0.085, 0)
				kit.quad(prev_o + top, o + top, o + Vector3(0, -0.6, 0), prev_o + Vector3(0, -0.6, 0), KERB if walk else col.darkened(0.2))
			prev_k = k
			prev_o = o
	# Chaussée : éventail depuis le centre jusqu'aux bordures.
	for i in kerb_ring.size():
		var a := kerb_ring[i]
		var b := kerb_ring[(i + 1) % kerb_ring.size()]
		kit.tri(c3, a + Vector3(0, 0.085, 0), b + Vector3(0, 0.085, 0), col, true)
	return kit.commit()


## Bouts des branches d'un plateau de carrefour, triés par angle :
## {p, d (direction sortante), r, hw, kerb (demi-largeur de chaussée)}. [] si pas de plateau.
static func _junction_arms(net: TransportNetwork, nid: int, trims: Dictionary) -> Array:
	var mode := net.node_mode(nid)
	if mode != TransportTypes.Mode.ROAD and mode != TransportTypes.Mode.PATH:
		return []
	var adj: Array = net.adjacency.get(nid, [])
	if adj.size() < 2 or is_smooth_joint(net, nid) or net.is_merge(nid):
		return []
	var arms: Array = []
	for eid in adj:
		var e: Dictionary = net.edges[eid]
		var tr: Vector2 = trims.get(eid, Vector2.ZERO)
		var s: float = tr.x if e.a == nid else float(e.len) - tr.y
		var stc := net.struct_at(eid, s)
		if stc == TransportTypes.Struct.TUNNEL:
			return []
		var ty := TransportTypes.get_type(e.t)
		# Direction au bout rogné (pas au nœud) : sur une courbe, les bords du
		# plateau tombent ainsi exactement sur ceux du tronçon.
		var dir: Vector3 = net.out_dir_at(eid, nid, s)
		var hw := net.half_width(eid)
		var walk := float(ty.get("side", 0.0)) if String(ty.get("side_kind", "")) == "trottoir" else 0.0
		arms.append({"p": net.point_at(eid, s), "d": dir, "r": Vector3(-dir.z, 0, dir.x), "hw": hw, "kerb": hw - walk,
			"ang": atan2(dir.z, dir.x), "bridge": stc == TransportTypes.Struct.BRIDGE})
	arms.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.ang) < float(y.ang))
	return arms


## Contour extérieur du plateau (bords des branches et arrondis des angles).
static func junction_outline(net: TransportNetwork, nid: int, trims: Dictionary) -> PackedVector3Array:
	var arms := _junction_arms(net, nid, trims)
	var out := PackedVector3Array()
	var n := arms.size()
	for i in n:
		var A: Dictionary = arms[i]
		var B: Dictionary = arms[(i + 1) % n]
		var oa: Vector3 = A.p + A.r * float(A.hw)
		var ob: Vector3 = B.p - B.r * float(B.hw)
		var oc := _corner(oa, A.d, ob, B.d)
		out.append(A.p - A.r * float(A.hw))
		for q in 9:
			out.append(_bez(oa, oc, ob, float(q) / 8.0))
	return out


## Cases sous un plateau de carrefour au sol : cellule -> hauteur de la
## chaussée (marge de 0,6 m comme sous les tronçons). {} sur un pont.
static func junction_cells(net: TransportNetwork, nid: int, trims: Dictionary) -> Dictionary:
	var arms := _junction_arms(net, nid, trims)
	for A in arms:
		if A.bridge:
			return {}
	var ring := junction_outline(net, nid, trims)
	if ring.size() < 3:
		return {}
	var center := net.node_pos(nid)
	var poly := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in ring:
		var q := Vector2(p.x, p.z)
		# Marge : on pousse le contour de 0,6 m vers l'extérieur.
		var away := q - Vector2(center.x, center.z)
		if away.length_squared() > 1e-6:
			q += away.normalized() * 0.6
		poly.append(q)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var out := {}
	for x in range(floori(lo.x), floori(hi.x) + 1):
		for z in range(floori(lo.y), floori(hi.y) + 1):
			var q := Vector2(x + 0.5, z + 0.5)
			if not Geometry2D.is_point_in_polygon(q, poly):
				continue
			out[Vector2i(x, z)] = _fan_height(center, ring, q)
	return out


## Hauteur du plateau en q : interpolation dans l'éventail centre / contour.
static func _fan_height(center: Vector3, ring: PackedVector3Array, q: Vector2) -> float:
	var c := Vector2(center.x, center.z)
	var best := center.y
	var best_d := INF
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var bary := _bary(q, c, a2, b2)
		if bary.x >= -0.01 and bary.y >= -0.01 and bary.z >= -0.01:
			return bary.x * center.y + bary.y * a.y + bary.z * b.y
		var d := q.distance_squared_to((a2 + b2) * 0.5)
		if d < best_d:
			best_d = d
			best = (a.y + b.y) * 0.5
	return best


static func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-9:
		return Vector3(-1, -1, -1)
	var v := (v2.x * v1.y - v1.x * v2.y) / den
	var w := (v0.x * v2.y - v2.x * v0.y) / den
	return Vector3(1.0 - v - w, v, w)


## Point de contrôle de l'angle : intersection des deux bords prolongés vers
## le centre, sinon le milieu (branches alignées ou angle rentrant).
static func _corner(pa: Vector3, da: Vector3, pb: Vector3, db: Vector3) -> Vector3:
	var mid := (pa + pb) * 0.5
	var den := da.x * db.z - da.z * db.x
	if absf(den) < 0.05:
		return mid
	var w := pb - pa
	# pa - t·da = pb - u·db  →  t·(-da) + u·db = w
	var t := (w.x * db.z - w.z * db.x) / -den
	var u := (-da.x * w.z + da.z * w.x) / -den
	if t < 0.0 or u < 0.0 or t > 60.0 or u > 60.0:
		return mid
	var c := pa - da * t
	c.y = mid.y
	return c


static func _bez(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u) + c * (2.0 * u * t) + b * (t * t)


## Maillage d'un tracé (tronçons et aperçu de pose). trim_a / trim_b : longueur
## retirée au début et à la fin (place laissée aux carrefours).
static func build_mesh(type_id: String, spec: Dictionary, pts: PackedVector3Array, st: PackedByteArray,
		ground_fn: Callable, trim_a: float = 0.0, trim_b: float = 0.0,
		right_a := Vector3.ZERO, right_b := Vector3.ZERO, clear_a := 0.0, clear_b := 0.0) -> ArrayMesh:
	var ty := TransportTypes.get_type(type_id)
	var k := MeshKit.new()
	if ty.is_empty() or pts.size() < 2:
		return k.commit()
	spec = TransportTypes.normalize(type_id, spec)
	if trim_a > 0.0 or trim_b > 0.0:
		var d := PackedFloat32Array()
		d.resize(pts.size())
		for i in range(1, pts.size()):
			d[i] = d[i - 1] + pts[i].distance_to(pts[i - 1])
		var total := d[d.size() - 1]
		if total - trim_a - trim_b < 0.3:
			return k.commit()
		var part := TransportNetwork.slice_polyline(pts, st, d, trim_a, total - trim_b)
		pts = part[0]
		st = part[1]
	var mode := int(ty.mode)
	var w := TransportTypes.width_of(type_id, spec)
	var hw := w * 0.5
	var n := pts.size()
	var right := _rights(pts)
	if right_a != Vector3.ZERO and trim_a <= 0.0:
		right[0] = right_a
	if right_b != Vector3.ZERO and trim_b <= 0.0:
		right[n - 1] = right_b
	var S := TransportTypes.Struct

	if mode == TransportTypes.Mode.WATER:
		var acc := 0.0
		var next_buoy := 0.0
		for i in n:
			if i > 0:
				acc += pts[i].distance_to(pts[i - 1])
			if acc >= next_buoy:
				next_buoy += 30.0
				k.box(pts[i] + right[i] * hw + Vector3(0, 0.4, 0), Vector3(0.8, 1.2, 0.8), Color("3fae5a"))
				k.box(pts[i] - right[i] * hw + Vector3(0, 0.4, 0), Vector3(0.8, 1.2, 0.8), Color("d6453d"))
		return k.commit()

	var acc_len := 0.0
	var total_len := 0.0
	for i in n - 1:
		total_len += pts[i].distance_to(pts[i + 1])
	for i in n - 1:
		var seg_len := pts[i].distance_to(pts[i + 1])
		var sa := st[i]
		var sb := st[i + 1]
		var dash_on := fmod(acc_len, 6.0) < 3.0
		# Pas de marquage sur les passages piétons (clear_a / clear_b depuis les bouts).
		var marks := acc_len + seg_len * 0.5 >= clear_a and total_len - acc_len - seg_len * 0.5 >= clear_b
		acc_len += seg_len
		if sa == S.TUNNEL or sb == S.TUNNEL:
			# Tracé du métro, en pointillés sur le sol, pour le voir de dessus.
			if ty.has("underground") and ground_fn.is_valid() and dash_on:
				var ga: float = ground_fn.call(pts[i].x, pts[i].z)
				var gb: float = ground_fn.call(pts[i + 1].x, pts[i + 1].z)
				if not is_nan(ga) and not is_nan(gb):
					var a0 := Vector3(pts[i].x, maxf(ga, 0.0) + 0.16, pts[i].z)
					var b0 := Vector3(pts[i + 1].x, maxf(gb, 0.0) + 0.16, pts[i + 1].z)
					k.strip(a0, b0, right[i], right[i + 1], -0.6, 0.6, 0.0, METRO_TRACE, 0.0, METRO_TRACE)
			continue
		var bridge := sa == S.BRIDGE or sb == S.BRIDGE
		var a := pts[i]
		var b := pts[i + 1]
		var ra := right[i]
		var rb := right[i + 1]
		var skirt := 1.2 if bridge else 0.8
		match mode:
			TransportTypes.Mode.ROAD:
				_road_section(k, type_id, spec, a, b, ra, rb, bridge, skirt, dash_on, marks)
			TransportTypes.Mode.RAIL:
				_rail_section(k, type_id, spec, a, b, ra, rb, bridge, skirt, hw)
			TransportTypes.Mode.PATH:
				var pc: Color = ty.get("color", SIDEWALK)
				k.strip(a, b, ra, rb, -hw, hw, 0.08, CONCRETE if bridge else pc, skirt, pc.darkened(0.25))
				if type_id == "piste_cyclable" and dash_on:
					k.strip(a, b, ra, rb, -0.06, 0.06, 0.1, MARKING, 0.0, MARKING)
		if bridge:
			# Parapets.
			k.strip(a, b, ra, rb, -hw - 0.3, -hw, 1.0, CONCRETE, 0.95, CONCRETE)
			k.strip(a, b, ra, rb, hw, hw + 0.3, 1.0, CONCRETE, 0.95, CONCRETE)

	# Viaducs ferroviaires (piles régulières et arches de pierre), sinon piles
	# de pont tous les ~20 m ; puis entrées de tunnel.
	var viaduct := mode == TransportTypes.Mode.RAIL and not ty.has("underground")
	if viaduct:
		_viaducts(k, type_id, pts, st, right, w, ground_fn)
	var acc2 := 0.0
	var next_pier := 10.0
	for i in n:
		if i > 0:
			acc2 += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		if st[i] == S.BRIDGE and acc2 >= next_pier and not viaduct:
			next_pier = acc2 + 20.0
			var top := pts[i].y - 1.2
			var gh: float = NAN
			if ground_fn.is_valid():
				gh = ground_fn.call(pts[i].x, pts[i].z)
			if is_nan(gh):
				gh = top - 12.0
			gh = minf(gh, top) - 2.0
			var h := top - gh
			if h > 0.3:
				var pw := minf(w * 0.6, 6.0)
				k.oriented_box(Vector3(pts[i].x, gh + h * 0.5, pts[i].z), right[i], Vector3(pw, h, 1.4), CONCRETE.darkened(0.08))
		if i < n - 1 and (st[i] == S.TUNNEL) != (st[i + 1] == S.TUNNEL):
			var at := i if st[i] != S.TUNNEL else i + 1
			var p := pts[at]
			var fwd := (pts[i + 1] - pts[i]).normalized()
			if st[i] != S.TUNNEL:
				fwd = -fwd
			var r := right[at]
			var ph := 6.5 if mode != TransportTypes.Mode.PATH else 3.5
			for side in [-1.0, 1.0]:
				k.oriented_box(p + r * side * (hw + 0.6) + Vector3(0, ph * 0.5, 0), r, Vector3(1.2, ph, 1.2), CONCRETE)
			k.oriented_box(p + Vector3(0, ph + 0.5, 0), r, Vector3(w + 2.4, 1.0, 1.2), CONCRETE)
			# Ouverture sombre, tournée vers l'extérieur du tunnel.
			k.oriented_box(p - fwd * 0.7 + Vector3(0, ph * 0.5, 0), r, Vector3(w + 0.1, ph, 0.2), DARK)
	return k.commit()


## Viaducs du rail : chaque passage en pont est découpé en travées égales.
## Lignes classiques, tram et crémaillère : piles et arches en pierre
## (travées de 8 à 18 m selon la hauteur) ; LGV : travées jusqu'à 40 m sur
## piles de béton.
static func _viaducts(k: MeshKit, type_id: String, pts: PackedVector3Array, st: PackedByteArray,
		right: PackedVector3Array, w: float, ground_fn: Callable) -> void:
	var S := TransportTypes.Struct
	var n := pts.size()
	var acc := PackedFloat32Array()
	acc.resize(n)
	for i in range(1, n):
		acc[i] = acc[i - 1] + Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
	var stone := type_id != "lgv"
	var span := VIADUCT_SPAN if stone else VIADUCT_SPAN_LGV
	var col := STONE if stone else CONCRETE.darkened(0.08)
	var i := 0
	while i < n:
		if st[i] != S.BRIDGE:
			i += 1
			continue
		var j := i
		while j + 1 < n and st[j + 1] == S.BRIDGE:
			j += 1
		var d0 := acc[maxi(0, i - 1)]
		var d1 := acc[mini(n - 1, j + 1)]
		var L := d1 - d0
		# Travées à la mesure de la hauteur : arches basses sur un petit vallon,
		# grandes arches sur une vallée profonde.
		var hmax := 0.0
		for q in range(i, j + 1):
			hmax = maxf(hmax, pts[q].y - 1.2 - _ground(ground_fn, pts[q], pts[q].y) - 2.0)
		var sp := clampf(hmax * 0.8, 8.0, span) if stone else clampf(hmax * 2.0, 25.0, span)
		var m := maxi(1, roundi(L / sp))
		var piers: Array[float] = [d0]
		for q in range(1, m):
			piers.append(d0 + L * float(q) / float(m))
		piers.append(d1)
		var thick := 2.2 if stone else 2.6
		# Piles (pas aux culées, à chaque bout).
		for q in range(1, piers.size() - 1):
			var at := _sample(pts, acc, piers[q])
			var top: float = (at[0] as Vector3).y - 1.2
			var gh := _ground(ground_fn, at[0], top)
			var h := top - gh
			if h <= 0.3:
				continue
			var c: Vector3 = at[0]
			var r: Vector3 = right[int(at[1])]
			# Fruit : la pile s'élargit vers le bas.
			var base_t := thick + h * 0.03
			k.oriented_box(Vector3(c.x, gh + h * 0.25, c.z), r, Vector3(w + 0.8 + h * 0.02, h * 0.5, base_t), col.darkened(0.06))
			k.oriented_box(Vector3(c.x, gh + h * 0.75, c.z), r, Vector3(w + 0.6, h * 0.5, thick), col)
		if stone:
			# Arches : tympans pleins entre l'intrados (demi-cercle) et le tablier.
			for q in piers.size() - 1:
				var a0 := piers[q] + (thick * 0.5 if q > 0 else 0.0)
				var a1 := piers[q + 1] - (thick * 0.5 if q < piers.size() - 2 else 0.0)
				var ls := a1 - a0
				if ls < 3.0:
					continue
				var rad := ls * 0.5
				var slices := maxi(6, roundi(ls / 1.5))
				for z in slices:
					var x := (float(z) + 0.5) / float(slices) * ls
					var at2 := _sample(pts, acc, a0 + x)
					var c2: Vector3 = at2[0]
					var top2 := c2.y - 1.2
					var u := x - rad
					var crown := top2 - 0.9
					var y_arch := crown - (rad - sqrt(maxf(0.0, rad * rad - u * u)))
					var gh2 := _ground(ground_fn, c2, top2)
					y_arch = maxf(y_arch, gh2)
					var hh := top2 - y_arch
					if hh > 0.05:
						k.oriented_box(Vector3(c2.x, y_arch + hh * 0.5, c2.z), right[int(at2[1])], Vector3(w + 0.4, hh, ls / float(slices) + 0.05), col.lightened(0.04))
		i = j + 1


## Point du tracé à la distance (à plat) d depuis le début : [Vector3, index].
static func _sample(pts: PackedVector3Array, acc: PackedFloat32Array, d: float) -> Array:
	for i in range(1, pts.size()):
		if acc[i] >= d:
			var seg := acc[i] - acc[i - 1]
			var t := 0.0 if seg <= 0.0 else (d - acc[i - 1]) / seg
			return [pts[i - 1].lerp(pts[i], clampf(t, 0.0, 1.0)), i - 1]
	return [pts[pts.size() - 1], pts.size() - 1]


## Hauteur du sol sous un point (un peu enterrée), bornée sous le tablier.
static func _ground(ground_fn: Callable, p: Vector3, top: float) -> float:
	var gh: float = NAN
	if ground_fn.is_valid():
		gh = ground_fn.call(p.x, p.z)
	if is_nan(gh):
		gh = top - 12.0
	return minf(gh, top) - 2.0


## Profil en travers d'une route : bords (trottoirs, accotements ou bandes
## d'arrêt d'urgence), voies de circulation, marquages, terre-plein central.
static func _road_section(k: MeshKit, type_id: String, spec: Dictionary, a: Vector3, b: Vector3,
		ra: Vector3, rb: Vector3, bridge: bool, skirt: float, dash_on: bool, marks := true) -> void:
	var ty := TransportTypes.get_type(type_id)
	var lanes: int = spec.lanes
	var lw: float = spec.lane_w
	var med := TransportTypes.median_of(type_id, spec)
	var side: float = ty.side
	var single := bool(ty.get("single", false))
	var carriage := lanes * lw * (0.5 if single else 1.0)
	var inner := med * 0.5
	var outer := inner + carriage
	var hw := outer + side
	var skirt_col := CONCRETE if bridge else ASPHALT.darkened(0.2)
	# Chaussées (les deux sens) et terre-plein.
	k.strip(a, b, ra, rb, -outer, -inner, 0.08, ASPHALT, 0.0, ASPHALT)
	k.strip(a, b, ra, rb, inner, outer, 0.08, ASPHALT, 0.0, ASPHALT)
	if single:
		lanes = 1
	if med > 0.0:
		if ty.center == "barrier":
			k.strip(a, b, ra, rb, -inner, inner, 0.08, ASPHALT_SIDE, 0.0, ASPHALT_SIDE)
			k.strip(a, b, ra, rb, -0.25, 0.25, 0.9, CONCRETE, 0.82, CONCRETE)
		else:
			k.strip(a, b, ra, rb, -inner, inner, 0.22, GRASS, 0.14, KERB)
	# Bords.
	match String(ty.side_kind):
		"trottoir":
			k.strip(a, b, ra, rb, -hw, -outer, 0.22, SIDEWALK, skirt + 0.14, KERB)
			k.strip(a, b, ra, rb, outer, hw, 0.22, SIDEWALK, skirt + 0.14, KERB)
		_:
			k.strip(a, b, ra, rb, -hw, -outer, 0.08, ASPHALT_SIDE, skirt, skirt_col)
			k.strip(a, b, ra, rb, outer, hw, 0.08, ASPHALT_SIDE, skirt, skirt_col)
	if not marks:
		return
	# Lignes de rive (continues) au bord de la chaussée.
	for e in [-outer, outer]:
		var o: float = e
		k.strip(a, b, ra, rb, o - 0.08, o + 0.08, 0.1, MARKING, 0.0, MARKING)
	# Axe : tirets (rue, départementale) ou ligne continue (avenue sans terre-plein).
	if ty.center == "none":
		pass
	elif med <= 0.0:
		if ty.center == "dashed":
			if dash_on:
				k.strip(a, b, ra, rb, -0.07, 0.07, 0.1, MARKING, 0.0, MARKING)
		else:
			k.strip(a, b, ra, rb, -0.07, 0.07, 0.1, MARKING, 0.0, MARKING)
	else:
		for e in [-inner, inner]:
			var o2: float = e
			k.strip(a, b, ra, rb, o2 - 0.07, o2 + 0.07, 0.1, MARKING, 0.0, MARKING)
	# Séparation des voies d'un même sens : tirets.
	if dash_on:
		for i in range(1, lanes):
			var off := inner + lw * i
			for sgn in [-1.0, 1.0]:
				var c: float = off * sgn
				k.strip(a, b, ra, rb, c - 0.07, c + 0.07, 0.1, MARKING, 0.0, MARKING)


## Profil en travers d'une voie ferrée : plate-forme, ballast (ou gazon pour le
## tramway), traverses et rails, pour une ou deux voies.
static func _rail_section(k: MeshKit, type_id: String, spec: Dictionary, a: Vector3, b: Vector3,
		ra: Vector3, rb: Vector3, bridge: bool, skirt: float, hw: float) -> void:
	var ty := TransportTypes.get_type(type_id)
	var tram := type_id == "tram"
	var base := CONCRETE if bridge else (GRASS if tram else BALLAST)
	k.strip(a, b, ra, rb, -hw, hw, 0.12, base, skirt, BALLAST.darkened(0.2))
	var tracks: int = spec.tracks
	var spacing: float = ty.spacing
	var rm := (ra + rb).normalized()
	for t in tracks:
		var off := 0.0 if tracks == 1 else (spacing * 0.5 * (-1.0 if t == 0 else 1.0))
		var ca := a + ra * off
		var cb := b + rb * off
		if not tram:
			k.strip(ca, cb, ra, rb, -1.5, 1.5, 0.2, BALLAST.lightened(0.08), 0.0, BALLAST)
		for c in [ca.lerp(cb, 0.25), ca.lerp(cb, 0.75)]:
			k.oriented_box(c + Vector3(0, 0.26, 0), rm, Vector3(2.6, 0.12, 0.26), SLEEPER)
		var g := TransportTypes.GAUGE * 0.5
		for r in [-g, g]:
			var o: float = r
			k.strip(ca, cb, ra, rb, o - 0.05, o + 0.05, 0.42, STEEL, 0.1, STEEL.darkened(0.3))
		if ty.get("rack", false):
			# Crémaillère : rail denté au milieu de la voie.
			k.strip(ca, cb, ra, rb, -0.09, 0.09, 0.5, STEEL.darkened(0.15), 0.18, STEEL.darkened(0.4))
			var seg := ca.distance_to(cb)
			var teeth := maxi(1, floori(seg / 0.6))
			for q in teeth:
				var c: Vector3 = ca.lerp(cb, (float(q) + 0.5) / float(teeth))
				k.oriented_box(c + Vector3(0, 0.55, 0), rm, Vector3(0.22, 0.1, 0.16), STEEL.darkened(0.35))


## Vecteur « droite » horizontal en chaque point du tracé.
static func _rights(pts: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	out.resize(n)
	for i in n:
		var t := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		t.y = 0.0
		if t.length_squared() < 1e-8:
			t = Vector3.FORWARD
		t = t.normalized()
		out[i] = Vector3(-t.z, 0.0, t.x)
	return out


## Petit fabricant de maillages à couleurs de sommets.
class MeshKit:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()

	## flat_up : normale verticale (éclairage uniforme d'un plateau en pente douce).
	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, flat_up := false) -> void:
		var nrm := (b - a).cross(c - a)
		if nrm.y < 0.0:
			nrm = -nrm
		nrm = nrm.normalized() if nrm.length_squared() > 1e-12 and not flat_up else Vector3.UP
		var base := verts.size()
		verts.append_array([a, b, c])
		normals.append_array([nrm, nrm, nrm])
		colors.append_array([col, col, col])
		idx.append_array([base, base + 1, base + 2])

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
		var nrm := (d - a).cross(b - a)
		if nrm.length_squared() < 1e-10:
			nrm = (a - b).cross(c - b)
		nrm = nrm.normalized()
		var base := verts.size()
		verts.append_array([a, b, c, d])
		normals.append_array([nrm, nrm, nrm, nrm])
		colors.append_array([col, col, col, col])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	## Bande entre a et b, de la position latérale l à r, surélevée de dy,
	## avec des bords qui descendent de « skirt » mètres.
	func strip(a: Vector3, b: Vector3, ra: Vector3, rb: Vector3, l: float, r: float, dy: float,
			col: Color, skirt: float, skirt_col: Color) -> void:
		var up := Vector3(0, dy, 0)
		var al := a + ra * l + up
		var ar := a + ra * r + up
		var bl := b + rb * l + up
		var br := b + rb * r + up
		quad(al, bl, br, ar, col)
		if skirt > 0.0:
			var dn := Vector3(0, -skirt, 0)
			quad(ar, br, br + dn, ar + dn, skirt_col)
			quad(bl, al, al + dn, bl + dn, skirt_col)

	func box(c: Vector3, size: Vector3, col: Color) -> void:
		oriented_box(c, Vector3.RIGHT, size, col)

	## Pavé centré en c ; « right » donne l'axe de size.x (horizontal).
	func oriented_box(c: Vector3, right: Vector3, size: Vector3, col: Color) -> void:
		var x := Vector3(right.x, 0, right.z).normalized() * size.x * 0.5
		var z := Vector3(-right.z, 0, right.x).normalized() * size.z * 0.5
		var y := Vector3(0, size.y * 0.5, 0)
		var p := [c - x - y - z, c + x - y - z, c + x - y + z, c - x - y + z,
			c - x + y - z, c + x + y - z, c + x + y + z, c - x + y + z]
		quad(p[4], p[5], p[6], p[7], col) # dessus
		var side := col.darkened(0.1)
		quad(p[0], p[1], p[5], p[4], side)
		quad(p[1], p[2], p[6], p[5], side)
		quad(p[2], p[3], p[7], p[6], side)
		quad(p[3], p[0], p[4], p[7], side)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if verts.is_empty():
			return mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
