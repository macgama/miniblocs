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

## Callable(x, z) -> hauteur du sol (pour les piles de pont).
var ground: Callable
var network: TransportNetwork

var _material: StandardMaterial3D
var _edge_meshes: Dictionary = {} # id de tronçon -> MeshInstance3D
var _edge_keys: Dictionary = {} # id de tronçon -> rognages utilisés
var _node_meshes: Dictionary = {} # id de nœud -> MeshInstance3D


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
		var key: Vector2 = trims.get(id, Vector2.ZERO)
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
		mi.mesh = build_mesh(e.t, e.w, e.pts, e.st, ground, key.x, key.y)
		_edge_keys[id] = key
	for id in _node_meshes.keys():
		(_node_meshes[id] as Node).queue_free()
	_node_meshes.clear()
	for id in network.nodes:
		var m := _junction_mesh(id, trims)
		if m != null:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.material_override = _material
			add_child(mi)
			_node_meshes[id] = mi


func edge_mesh_count() -> int:
	return _edge_meshes.size()


func junction_count() -> int:
	return _node_meshes.size()


## Longueur à retirer au début (x) et à la fin (y) de chaque tronçon pour
## laisser la place au plateau du carrefour.
static func compute_trims(net: TransportNetwork) -> Dictionary:
	var out := {}
	for nid in net.nodes:
		var mode := net.node_mode(nid)
		if mode != TransportTypes.Mode.ROAD and mode != TransportTypes.Mode.PATH:
			continue
		var adj: Array = net.adjacency.get(nid, [])
		if adj.size() < 2:
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
	var mode := network.node_mode(nid)
	if mode != TransportTypes.Mode.ROAD and mode != TransportTypes.Mode.PATH:
		return null
	var adj: Array = network.adjacency.get(nid, [])
	if adj.size() < 2:
		return null
	var corners := PackedVector2Array()
	var heights := {}
	var col := ASPHALT
	for eid in adj:
		var e: Dictionary = network.edges[eid]
		if mode == TransportTypes.Mode.PATH:
			col = TransportTypes.get_type(e.t).get("color", SIDEWALK)
		var tr: Vector2 = trims.get(eid, Vector2.ZERO)
		var s: float = tr.x if e.a == nid else float(e.len) - tr.y
		var p := network.point_at(eid, s)
		if network.struct_at(eid, s) == TransportTypes.Struct.TUNNEL:
			return null
		var dir := network.leave_dir(eid, nid)
		var right := Vector3(-dir.z, 0, dir.x)
		var hw := network.half_width(eid)
		for side in [-1.0, 1.0]:
			var c: Vector3 = p + right * hw * side
			var k := Vector2(c.x, c.z)
			corners.append(k)
			heights[k] = c.y
	var hull := Geometry2D.convex_hull(corners)
	if hull.size() < 3:
		return null
	var center := network.node_pos(nid)
	var kit := MeshKit.new()
	var c3 := Vector3(center.x, center.y + 0.085, center.z)
	for i in hull.size() - 1:
		var a := hull[i]
		var b := hull[i + 1]
		var ya: float = heights.get(a, center.y)
		var yb: float = heights.get(b, center.y)
		kit.tri(c3, Vector3(a.x, ya + 0.085, a.y), Vector3(b.x, yb + 0.085, b.y), col)
		# Bord du plateau (cache le petit vide entre le plateau et le sol).
		kit.quad(Vector3(a.x, ya + 0.085, a.y), Vector3(b.x, yb + 0.085, b.y),
			Vector3(b.x, yb - 0.6, b.y), Vector3(a.x, ya - 0.6, a.y), col.darkened(0.2))
	return kit.commit()


## Maillage d'un tracé (tronçons et aperçu de pose). trim_a / trim_b : longueur
## retirée au début et à la fin (place laissée aux carrefours).
static func build_mesh(type_id: String, spec: Dictionary, pts: PackedVector3Array, st: PackedByteArray,
		ground_fn: Callable, trim_a: float = 0.0, trim_b: float = 0.0) -> ArrayMesh:
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
	for i in n - 1:
		var seg_len := pts[i].distance_to(pts[i + 1])
		var sa := st[i]
		var sb := st[i + 1]
		var dash_on := fmod(acc_len, 6.0) < 3.0
		acc_len += seg_len
		if sa == S.TUNNEL or sb == S.TUNNEL:
			continue
		var bridge := sa == S.BRIDGE or sb == S.BRIDGE
		var a := pts[i]
		var b := pts[i + 1]
		var ra := right[i]
		var rb := right[i + 1]
		var skirt := 1.2 if bridge else 0.8
		match mode:
			TransportTypes.Mode.ROAD:
				_road_section(k, type_id, spec, a, b, ra, rb, bridge, skirt, dash_on)
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

	# Piles de pont tous les ~20 m, et entrées de tunnel.
	var acc2 := 0.0
	var next_pier := 10.0
	for i in n:
		if i > 0:
			acc2 += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		if st[i] == S.BRIDGE and acc2 >= next_pier:
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


## Profil en travers d'une route : bords (trottoirs, accotements ou bandes
## d'arrêt d'urgence), voies de circulation, marquages, terre-plein central.
static func _road_section(k: MeshKit, type_id: String, spec: Dictionary, a: Vector3, b: Vector3,
		ra: Vector3, rb: Vector3, bridge: bool, skirt: float, dash_on: bool) -> void:
	var ty := TransportTypes.get_type(type_id)
	var lanes: int = spec.lanes
	var lw: float = spec.lane_w
	var med := TransportTypes.median_of(type_id, spec)
	var side: float = ty.side
	var carriage := lanes * lw
	var inner := med * 0.5
	var outer := inner + carriage
	var hw := outer + side
	var skirt_col := CONCRETE if bridge else ASPHALT.darkened(0.2)
	# Chaussées (les deux sens) et terre-plein.
	k.strip(a, b, ra, rb, -outer, -inner, 0.08, ASPHALT, 0.0, ASPHALT)
	k.strip(a, b, ra, rb, inner, outer, 0.08, ASPHALT, 0.0, ASPHALT)
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
	# Lignes de rive (continues) au bord de la chaussée.
	for e in [-outer, outer]:
		var o: float = e
		k.strip(a, b, ra, rb, o - 0.08, o + 0.08, 0.1, MARKING, 0.0, MARKING)
	# Axe : tirets (rue, départementale) ou ligne continue (avenue sans terre-plein).
	if med <= 0.0:
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

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		var nrm := (b - a).cross(c - a)
		if nrm.y < 0.0:
			nrm = -nrm
		nrm = nrm.normalized() if nrm.length_squared() > 1e-12 else Vector3.UP
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
