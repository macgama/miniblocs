class_name TransportView
extends Node3D
## Affichage low-poly des réseaux : chaussées, voies ferrées, chemins, bouées,
## ponts (tablier, parapets, piles) et entrées de tunnels. Tout est généré en
## code à partir du tracé des tronçons, sans asset externe.

const ASPHALT := Color("34373d")
const MARKING := Color("f2f0e6")
const CONCRETE := Color("b9b4aa")
const BALLAST := Color("8a7f72")
const SLEEPER := Color("5b4636")
const STEEL := Color("c6cbd1")
const PATH_COL := Color("d9c49a")
const DARK := Color("1d1f22")

## Callable(x, z) -> hauteur du sol (pour les piles de pont).
var ground: Callable
var network: TransportNetwork

var _material: StandardMaterial3D
var _edge_meshes: Dictionary = {} # id de tronçon -> MeshInstance3D
var _node_meshes: Dictionary = {} # id de nœud -> MeshInstance3D


func _init() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.9
	# Faces visibles des deux côtés : pas besoin de soigner le sens des triangles.
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func setup(net: TransportNetwork, ground_fn: Callable) -> void:
	network = net
	ground = ground_fn
	network.changed.connect(rebuild)
	rebuild()


## Reconstruit uniquement ce qui a changé (tronçons ajoutés / supprimés).
func rebuild() -> void:
	for id in _edge_meshes.keys():
		if not network.edges.has(id):
			(_edge_meshes[id] as Node).queue_free()
			_edge_meshes.erase(id)
	for id in network.edges:
		if not _edge_meshes.has(id):
			var e: Dictionary = network.edges[id]
			var mi := MeshInstance3D.new()
			mi.name = "Troncon_%d" % id
			mi.mesh = build_mesh(e.t, e.pts, e.st, ground)
			mi.material_override = _material
			add_child(mi)
			_edge_meshes[id] = mi
	# Les carrefours dépendent des voisins : on les refait tous (peu nombreux).
	for id in _node_meshes.keys():
		(_node_meshes[id] as Node).queue_free()
	_node_meshes.clear()
	for id in network.nodes:
		var m := _node_mesh(id)
		if m != null:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.material_override = _material
			mi.position = network.node_pos(id)
			add_child(mi)
			_node_meshes[id] = mi


func edge_mesh_count() -> int:
	return _edge_meshes.size()


func _node_mesh(id: int) -> ArrayMesh:
	var mode := network.node_mode(id)
	if mode != TransportTypes.Mode.ROAD and mode != TransportTypes.Mode.PATH:
		return null
	if network.degree(id) == 0:
		return null
	var width := 0.0
	for eid in network.adjacency[id]:
		var e: Dictionary = network.edges[eid]
		if e.st[0 if e.a == id else (e.st as PackedByteArray).size() - 1] == TransportTypes.Struct.TUNNEL:
			return null
		width = maxf(width, float(TransportTypes.get_type(e.t).width))
	var k := MeshKit.new()
	var col := ASPHALT if mode == TransportTypes.Mode.ROAD else PATH_COL
	k.disc(Vector3(0, 0.09, 0), width * 0.5, 12, col)
	return k.commit()


## Maillage d'un tracé (utilisé pour les tronçons et pour l'aperçu de pose).
static func build_mesh(type_id: String, pts: PackedVector3Array, st: PackedByteArray, ground_fn: Callable) -> ArrayMesh:
	var ty := TransportTypes.get_type(type_id)
	var k := MeshKit.new()
	if ty.is_empty() or pts.size() < 2:
		return k.commit()
	var mode := int(ty.mode)
	var w: float = ty.width
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

	for i in n - 1:
		var sa := st[i]
		var sb := st[i + 1]
		if sa == S.TUNNEL or sb == S.TUNNEL:
			continue
		var bridge := sa == S.BRIDGE or sb == S.BRIDGE
		var a := pts[i]
		var b := pts[i + 1]
		var ra := right[i]
		var rb := right[i + 1]
		var skirt := 1.1 if bridge else 0.7
		match mode:
			TransportTypes.Mode.ROAD:
				k.strip(a, b, ra, rb, -hw, hw, 0.08, ASPHALT, skirt, CONCRETE if bridge else ASPHALT.darkened(0.2))
				if i % 2 == 0:
					k.strip(a, b, ra, rb, -0.08, 0.08, 0.1, MARKING, 0.0, MARKING)
				k.strip(a, b, ra, rb, -hw + 0.25, -hw + 0.4, 0.1, MARKING, 0.0, MARKING)
				k.strip(a, b, ra, rb, hw - 0.4, hw - 0.25, 0.1, MARKING, 0.0, MARKING)
			TransportTypes.Mode.RAIL:
				k.strip(a, b, ra, rb, -hw, hw, 0.12, CONCRETE if bridge else BALLAST, skirt, BALLAST.darkened(0.2))
				var rm := (ra + rb).normalized()
				for c in [a.lerp(b, 0.25), a.lerp(b, 0.75)]:
					k.oriented_box(c + Vector3(0, 0.2, 0), rm, Vector3(2.6, 0.12, 0.28), SLEEPER)
				for off in [-0.72, 0.72]:
					k.strip(a, b, ra, rb, off - 0.05, off + 0.05, 0.36, STEEL, 0.1, STEEL.darkened(0.3))
			TransportTypes.Mode.PATH:
				k.strip(a, b, ra, rb, -hw, hw, 0.08, CONCRETE if bridge else PATH_COL, skirt, PATH_COL.darkened(0.25))
		if bridge:
			# Parapets.
			k.strip(a, b, ra, rb, -hw - 0.25, -hw, 0.9, CONCRETE, 0.85, CONCRETE)
			k.strip(a, b, ra, rb, hw, hw + 0.25, 0.9, CONCRETE, 0.85, CONCRETE)

	# Piles de pont tous les ~16 m, et entrées de tunnel.
	var acc2 := 0.0
	var next_pier := 8.0
	for i in n:
		if i > 0:
			acc2 += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		if st[i] == S.BRIDGE and acc2 >= next_pier:
			next_pier = acc2 + 16.0
			var top := pts[i].y - 1.0
			var gh: float = NAN
			if ground_fn.is_valid():
				gh = ground_fn.call(pts[i].x, pts[i].z)
			if is_nan(gh):
				gh = top - 12.0
			gh = minf(gh, top) - 2.0
			var h := top - gh
			if h > 0.3:
				var pw := minf(w * 0.6, 4.0)
				k.oriented_box(Vector3(pts[i].x, gh + h * 0.5, pts[i].z), right[i], Vector3(pw, h, 1.2), CONCRETE.darkened(0.08))
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

	func disc(c: Vector3, radius: float, segments: int, col: Color) -> void:
		var base := verts.size()
		verts.append(c)
		normals.append(Vector3.UP)
		colors.append(col)
		for s in segments:
			var ang := TAU * float(s) / float(segments)
			verts.append(c + Vector3(cos(ang), 0, sin(ang)) * radius)
			normals.append(Vector3.UP)
			colors.append(col)
		for s in segments:
			var i1 := base + 1 + s
			var i2 := base + 1 + (s + 1) % segments
			idx.append_array([base, i1, i2])

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
