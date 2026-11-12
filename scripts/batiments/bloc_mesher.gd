class_name BlocMesher
extends RefCounted
## Maillage texturé de l'éditeur libre : deux surfaces (opaque, verre), chaque
## sommet porte UV (en mètres, la texture se répète tous les mètres), UV2.x
## (couche de texture du matériau) et une couleur (teinte, en linéaire).

var _v := [PackedVector3Array(), PackedVector3Array()]
var _n := [PackedVector3Array(), PackedVector3Array()]
var _uv := [PackedVector2Array(), PackedVector2Array()]
var _uv2 := [PackedVector2Array(), PackedVector2Array()]
var _c := [PackedColorArray(), PackedColorArray()]
var _i := [PackedInt32Array(), PackedInt32Array()]


func is_empty() -> bool:
	return (_v[0] as PackedVector3Array).is_empty() and (_v[1] as PackedVector3Array).is_empty()


## Polygone convexe (3 ou 4 sommets, en mètres) de normale n.
func face(pts: Array, n: Vector3, layer: int, col: Color, glass: bool) -> void:
	var s := 1 if glass else 0
	var v: PackedVector3Array = _v[s]
	var base := v.size()
	# Projection de la texture : horizontale sur les sols, le long du mur sinon.
	var t := Vector3.UP.cross(n)
	var horiz := t.length() < 0.2
	if not horiz:
		t = t.normalized()
	var b := n.cross(t).normalized() if not horiz else Vector3.ZERO
	var lin := col.srgb_to_linear()
	var nn: PackedVector3Array = _n[s]
	var uv: PackedVector2Array = _uv[s]
	var uv2: PackedVector2Array = _uv2[s]
	var cc: PackedColorArray = _c[s]
	for p in pts:
		var pp: Vector3 = p
		v.append(pp)
		nn.append(n)
		if horiz:
			uv.append(Vector2(pp.x, pp.z))
		else:
			uv.append(Vector2(pp.dot(t), -pp.dot(b)))
		uv2.append(Vector2(layer, 0))
		cc.append(lin)
	_v[s] = v
	_n[s] = nn
	_uv[s] = uv
	_uv2[s] = uv2
	_c[s] = cc
	var a: Vector3 = pts[0]
	var bb: Vector3 = pts[1]
	var c: Vector3 = pts[2]
	var cw := (bb - a).cross(c - a).dot(n) > 0.0
	var idx: PackedInt32Array = _i[s]
	for k in range(1, pts.size() - 1):
		if cw:
			idx.append_array([base, base + k + 1, base + k])
		else:
			idx.append_array([base, base + k, base + k + 1])
	_i[s] = idx


func to_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var mats := [BlocMateriaux.solid_material(), BlocMateriaux.glass_material()]
	for s in 2:
		if (_v[s] as PackedVector3Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _v[s]
		arrays[Mesh.ARRAY_NORMAL] = _n[s]
		arrays[Mesh.ARRAY_TEX_UV] = _uv[s]
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2[s]
		arrays[Mesh.ARRAY_COLOR] = _c[s]
		arrays[Mesh.ARRAY_INDEX] = _i[s]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[s])
	return mesh
