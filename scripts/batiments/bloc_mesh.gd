class_name BlocMesh
extends RefCounted
## Petit atelier de formes low-poly (boîtes, toits, cylindres) rassemblées dans
## un seul maillage à couleurs par sommet : un bâtiment = un seul objet à
## dessiner, quel que soit son nombre de pièces.
##
## Repère local d'un bâtiment : 1 unité = 1 m, le sol est à y = 0, le bâtiment
## est centré sur (0, 0) et sa façade principale (porte) regarde vers −Z.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


## Quadrilatère a-b-c-d (dans l'ordre du tour) avec sa normale extérieure.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	var base := verts.size()
	verts.append_array([a, b, c, d])
	normals.append_array([n, n, n, n])
	colors.append_array([col, col, col, col])
	# Godot dessine les faces dont les sommets tournent dans le sens horaire
	# vu de l'extérieur : on remet l'ordre dans le bon sens si besoin.
	if (b - a).cross(c - a).dot(n) > 0.0:
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	else:
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var base := verts.size()
	verts.append_array([a, b, c])
	normals.append_array([n, n, n])
	colors.append_array([col, col, col])
	if (b - a).cross(c - a).dot(n) > 0.0:
		indices.append_array([base, base + 2, base + 1])
	else:
		indices.append_array([base, base + 1, base + 2])


## Boîte : centre au sol (cx, y0, cz), dimensions (sx, sy, sz). bottom : dessiner le dessous.
func box(cx: float, y0: float, cz: float, sx: float, sy: float, sz: float, col: Color, bottom := false) -> void:
	var x0 := cx - sx / 2.0
	var x1 := cx + sx / 2.0
	var z0 := cz - sz / 2.0
	var z1 := cz + sz / 2.0
	var y1 := y0 + sy
	quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, col)
	var side := col.darkened(0.06)
	quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD, side)
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK, side)
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT, side)
	quad(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT, side)
	if bottom:
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, side)


## Plaque fine posée au sol (pelouse, parking, lignes…).
func plate(cx: float, cz: float, sx: float, sz: float, col: Color, y0 := 0.0, thick := 0.08) -> void:
	box(cx, y0, cz, sx, thick, sz, col)


## Toit à deux pentes posé en y0, faîtage parallèle à X (along_x) ou à Z.
func gable(cx: float, y0: float, cz: float, sx: float, sz: float, h: float, col: Color, along_x := true) -> void:
	var x0 := cx - sx / 2.0
	var x1 := cx + sx / 2.0
	var z0 := cz - sz / 2.0
	var z1 := cz + sz / 2.0
	var y1 := y0 + h
	var gable_col := col.lightened(0.08)
	if along_x:
		var n1 := Vector3(0, sz / 2.0, -h).normalized()
		var n2 := Vector3(0, sz / 2.0, h).normalized()
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, cz), Vector3(x0, y1, cz), n1, col)
		quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, cz), Vector3(x0, y1, cz), n2, col.darkened(0.08))
		tri(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, cz), Vector3.LEFT, gable_col)
		tri(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, cz), Vector3.RIGHT, gable_col)
	else:
		var n1 := Vector3(-h, sx / 2.0, 0).normalized()
		var n2 := Vector3(h, sx / 2.0, 0).normalized()
		quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(cx, y1, z1), Vector3(cx, y1, z0), n1, col)
		quad(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(cx, y1, z1), Vector3(cx, y1, z0), n2, col.darkened(0.08))
		tri(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(cx, y1, z0), Vector3.FORWARD, gable_col)
		tri(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(cx, y1, z1), Vector3.BACK, gable_col)


## Toit à quatre pans : faîtage le long du plus grand côté.
func hip(cx: float, y0: float, cz: float, sx: float, sz: float, h: float, col: Color) -> void:
	if absf(sx - sz) < 0.01:
		pyramid(cx, y0, cz, sx, sz, h, col)
		return
	var y1 := y0 + h
	var x0 := cx - sx / 2.0
	var x1 := cx + sx / 2.0
	var z0 := cz - sz / 2.0
	var z1 := cz + sz / 2.0
	if sx > sz:
		var r := (sx - sz) / 2.0
		var a := Vector3(cx - r, y1, cz)
		var b := Vector3(cx + r, y1, cz)
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), b, a, Vector3(0, sz / 2.0, -h).normalized(), col)
		quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), b, a, Vector3(0, sz / 2.0, h).normalized(), col.darkened(0.1))
		tri(Vector3(x0, y0, z0), Vector3(x0, y0, z1), a, Vector3(-h, sz / 2.0, 0).normalized(), col.darkened(0.05))
		tri(Vector3(x1, y0, z0), Vector3(x1, y0, z1), b, Vector3(h, sz / 2.0, 0).normalized(), col.darkened(0.05))
	else:
		var r := (sz - sx) / 2.0
		var a := Vector3(cx, y1, cz - r)
		var b := Vector3(cx, y1, cz + r)
		quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), b, a, Vector3(-h, sx / 2.0, 0).normalized(), col.darkened(0.05))
		quad(Vector3(x1, y0, z0), Vector3(x1, y0, z1), b, a, Vector3(h, sx / 2.0, 0).normalized(), col.darkened(0.1))
		tri(Vector3(x0, y0, z0), Vector3(x1, y0, z0), a, Vector3(0, sx / 2.0, -h).normalized(), col)
		tri(Vector3(x0, y0, z1), Vector3(x1, y0, z1), b, Vector3(0, sx / 2.0, h).normalized(), col.darkened(0.1))


## Solide de révolution : profil de points (rayon, hauteur) du bas vers le haut.
## Sert aux dômes, bulbes, stupas, cônes de chaume, réservoirs…
func lathe(cx: float, y0: float, cz: float, profile: Array, sides: int, col: Color) -> void:
	for j in profile.size() - 1:
		var p0: Vector2 = profile[j]
		var p1: Vector2 = profile[j + 1]
		var shade := col.darkened(0.03 * (profile.size() - 2 - j) / maxf(profile.size() - 2, 1.0))
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var am := (a0 + a1) / 2.0
			var dr := p0.x - p1.x
			var dy := p1.y - p0.y
			var n := Vector3(cos(am) * dy, dr, sin(am) * dy).normalized()
			var q00 := Vector3(cx + cos(a0) * p0.x, y0 + p0.y, cz + sin(a0) * p0.x)
			var q01 := Vector3(cx + cos(a1) * p0.x, y0 + p0.y, cz + sin(a1) * p0.x)
			var q10 := Vector3(cx + cos(a0) * p1.x, y0 + p1.y, cz + sin(a0) * p1.x)
			var q11 := Vector3(cx + cos(a1) * p1.x, y0 + p1.y, cz + sin(a1) * p1.x)
			if p1.x <= 0.001:
				tri(q00, q01, q10, n, shade)
			elif p0.x <= 0.001:
				tri(q00, q11, q10, n, shade)
			else:
				quad(q00, q01, q11, q10, n, shade)


## Dôme (demi-sphère aplatie ou non) posé en y0.
func dome(cx: float, y0: float, cz: float, r: float, h: float, col: Color, sides := 12) -> void:
	var prof := []
	for i in 6:
		var a := PI / 2.0 * i / 5.0
		prof.append(Vector2(cos(a) * r, sin(a) * h))
	lathe(cx, y0, cz, prof, sides, col)


## Bulbe à l'orientale (églises russes, palais moghols).
func onion(cx: float, y0: float, cz: float, r: float, h: float, col: Color, sides := 10) -> void:
	lathe(cx, y0, cz, [Vector2(r * 0.7, 0), Vector2(r, h * 0.25), Vector2(r * 0.95, h * 0.45),
		Vector2(r * 0.6, h * 0.65), Vector2(r * 0.2, h * 0.85), Vector2(0, h)], sides, col)


## Toit en pyramide (clocher, kiosque…).
func pyramid(cx: float, y0: float, cz: float, sx: float, sz: float, h: float, col: Color) -> void:
	var top := Vector3(cx, y0 + h, cz)
	var a := Vector3(cx - sx / 2.0, y0, cz - sz / 2.0)
	var b := Vector3(cx + sx / 2.0, y0, cz - sz / 2.0)
	var c := Vector3(cx + sx / 2.0, y0, cz + sz / 2.0)
	var d := Vector3(cx - sx / 2.0, y0, cz + sz / 2.0)
	tri(a, b, top, Vector3(0, sz / 2.0, -h).normalized(), col)
	tri(b, c, top, Vector3(h, sx / 2.0, 0).normalized(), col.darkened(0.05))
	tri(c, d, top, Vector3(0, sz / 2.0, h).normalized(), col.darkened(0.1))
	tri(d, a, top, Vector3(-h, sx / 2.0, 0).normalized(), col.darkened(0.05))


## Cylindre (ou cône si r1 = 0) à facettes, base centrée en (cx, y0, cz).
func cylinder(cx: float, y0: float, cz: float, r0: float, r1: float, h: float, sides: int, col: Color) -> void:
	var y1 := y0 + h
	var side := col.darkened(0.05)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var am := (a0 + a1) / 2.0
		var n := Vector3(cos(am), (r0 - r1) / maxf(h, 0.01), sin(am)).normalized()
		var p0 := Vector3(cx + cos(a0) * r0, y0, cz + sin(a0) * r0)
		var p1 := Vector3(cx + cos(a1) * r0, y0, cz + sin(a1) * r0)
		var q0 := Vector3(cx + cos(a0) * r1, y1, cz + sin(a0) * r1)
		var q1 := Vector3(cx + cos(a1) * r1, y1, cz + sin(a1) * r1)
		if r1 <= 0.001:
			tri(p0, p1, q0, n, side)
		else:
			quad(p0, p1, q1, q0, n, side)
			tri(Vector3(cx, y1, cz), q0, q1, Vector3.UP, col)


## Arbre low-poly (tronc + cône) : pour les parcs et jardins.
func tree(cx: float, cz: float, s: float, col := Color("4c8c3f")) -> void:
	cylinder(cx, 0.0, cz, 0.18 * s, 0.14 * s, 1.2 * s, 5, Color("7a5230"))
	cylinder(cx, 1.0 * s, cz, 1.2 * s, 0.0, 3.4 * s, 6, col)


## Bandeaux de fenêtres sur les quatre façades d'un volume (un par étage).
func window_bands(cx: float, cz: float, sx: float, sz: float, y0: float, floors: int, floor_h: float, col: Color) -> void:
	for i in floors:
		var y := y0 + i * floor_h + floor_h * 0.35
		box(cx, y, cz, sx + 0.12, floor_h * 0.4, sz + 0.12, col)


## Rangée de fenêtres individuelles sur une façade orientée −Z (front) ou +Z.
func windows_row(cx: float, z: float, width: float, y: float, count: int, w: float, h: float, col: Color) -> void:
	if count <= 0:
		return
	var step := width / count
	for i in count:
		var x := cx - width / 2.0 + step * (i + 0.5)
		box(x, y, z, w, h, 0.12, col)


## Rangée de fenêtres sur une façade orientée ±X.
func windows_col(x: float, cz: float, depth: float, y: float, count: int, w: float, h: float, col: Color) -> void:
	if count <= 0:
		return
	var step := depth / count
	for i in count:
		var z := cz - depth / 2.0 + step * (i + 0.5)
		box(x, y, z, 0.12, h, w, col)


## Ramène le modèle dans son emprise w × d (centrée) s'il en dépasse : les
## auvents, escaliers ou annexes trop larges sont resserrés, la hauteur ne change pas.
func fit_xz(w: float, d: float) -> void:
	if verts.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in verts:
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
	var size := hi - lo
	if lo.x >= -w / 2.0 - 0.01 and hi.x <= w / 2.0 + 0.01 and lo.y >= -d / 2.0 - 0.01 and hi.y <= d / 2.0 + 0.01:
		return
	var center := (lo + hi) / 2.0
	var sx := minf(1.0, w / maxf(size.x, 0.01))
	var sz := minf(1.0, d / maxf(size.y, 0.01))
	# On ne recentre que si le modèle dépasse encore après le resserrage.
	var off := Vector2.ZERO
	if size.x * sx > w - 0.01 or hi.x > w / 2.0 or lo.x < -w / 2.0:
		off.x = center.x
	if size.y * sz > d - 0.01 or hi.y > d / 2.0 or lo.y < -d / 2.0:
		off.y = center.y
	for i in verts.size():
		var v := verts[i]
		verts[i] = Vector3((v.x - off.x) * sx, v.y, (v.z - off.y) * sz)
		var n := normals[i]
		normals[i] = Vector3(n.x / sx, n.y, n.z / sz).normalized()


func to_mesh(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	return mesh
