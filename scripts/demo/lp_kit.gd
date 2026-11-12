class_name LpKit
extends RefCounted
## Kit de modelage low-poly « poussé », entièrement en code (aucun asset externe).
##
## Les quatre techniques qui font la différence avec des boîtes unies :
## 1. Faces plates (une normale par triangle) : le relief se lit par facettes.
## 2. Une teinte légèrement différente par face (`jitter`) : planches, pierres,
##    bottes de chaume ne sont jamais deux fois pareilles.
## 3. Des formes irrégulières : coins de pierre décalés, bords de chaume ondulés,
##    sphères bosselées pour les feuillages.
## 4. Une ombre « peinte » dans les couleurs (bas des feuillages, pied des murs
##    plus sombres) : on simule l'occlusion ambiante sans coût au rendu.
##
## Tout ce qui est construit va dans quelques « couches » (une par matériau :
## base, verre, lumière...). `commit()` rend un seul ArrayMesh : un objet entier
## ne coûte qu'un appel de dessin par matériau, ce qui permet d'en mettre des
## milliers sur une carte.

var rng := RandomNumberGenerator.new()
## Couche courante (nom du matériau qui recevra les faces suivantes).
var layer := "base"
## Transformation appliquée aux points ajoutés (pour poser une pièce tournée).
var xf := Transform3D.IDENTITY
## Variation de teinte par face (0 = uni).
var jitter := 0.06

var _layers := {}


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


# --- Couleurs -----------------------------------------------------------------

## Une variante de la couleur : teinte, saturation et luminosité un peu décalées.
func vary(c: Color, amount := -1.0) -> Color:
	var a := jitter if amount < 0.0 else amount
	var h := fposmod(c.h + rng.randf_range(-a, a) * 0.06, 1.0)
	var s := clampf(c.s * (1.0 + rng.randf_range(-a, a) * 1.2), 0.0, 1.0)
	var v := clampf(c.v * (1.0 + rng.randf_range(-a, a) * 1.6), 0.0, 1.0)
	return Color.from_hsv(h, s, v, c.a)


# --- Primitives -----------------------------------------------------------------

func _arr(name: String) -> Dictionary:
	if not _layers.has(name):
		# Tableaux ordinaires (passés par référence), convertis à la fin.
		_layers[name] = {"v": [], "n": [], "c": []}
	return _layers[name]


## Triangle à couleurs par sommet. Les points sont donnés dans un ordre
## quelconque : `outward` est une direction (repère local) vers l'extérieur
## de la face, qui sert à orienter le triangle.
func tri3(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, outward := Vector3.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if outward != Vector3.ZERO and n.dot(outward) < 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
		n = -n
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var wn := (xf.basis * n).normalized()
	var d := _arr(layer)
	# Godot dessine les faces avant dans le sens horaire.
	d.v.append(wa)
	d.v.append(wc)
	d.v.append(wb)
	for i in 3:
		d.n.append(wn)
	d.c.append(ca)
	d.c.append(cc)
	d.c.append(cb)


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, outward := Vector3.ZERO) -> void:
	tri3(a, b, c, col, col, col, outward)


## Quadrilatère (a, b, c, d dans l'ordre du contour), une seule teinte.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward := Vector3.ZERO) -> void:
	if outward == Vector3.ZERO:
		outward = (b - a).cross(c - a)
	tri(a, b, c, col, outward)
	tri(a, c, d, col, outward)


## Boîte alignée. `rough` décale chaque coin au hasard (proportion de la taille) :
## 0.15 donne une pierre taillée à la main. `shade_bottom` assombrit la face du bas.
func box(center: Vector3, size: Vector3, col: Color, rough := 0.0, vary_faces := true) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		var q := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		if rough > 0.0:
			q += Vector3(rng.randf_range(-1, 1) * size.x, rng.randf_range(-1, 1) * size.y, rng.randf_range(-1, 1) * size.z) * rough * 0.5
		p.append(center + q)
	var base := vary(col) if vary_faces else col
	var faces := [
		[1, 3, 7, 5, Vector3.RIGHT], [0, 4, 6, 2, Vector3.LEFT],
		[2, 6, 7, 3, Vector3.UP], [0, 1, 5, 4, Vector3.DOWN],
		[4, 5, 7, 6, Vector3.BACK], [0, 2, 3, 1, Vector3.FORWARD],
	]
	for f in faces:
		var c := base
		if vary_faces:
			c = vary(base, jitter * 0.5)
		if f[4] == Vector3.DOWN:
			c = c.darkened(0.3)
		quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], c, f[4])


## Poutre de section rectangulaire entre deux points (colombages, poteaux, rayons).
func beam(a: Vector3, b: Vector3, w: float, h: float, col: Color, up_hint := Vector3.UP) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.001:
		return
	var z := axis / length
	var up := up_hint
	if absf(z.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	var saved := xf
	xf = saved * Transform3D(Basis(x, y, z), (a + b) * 0.5)
	box(Vector3.ZERO, Vector3(w, h, length), col)
	xf = saved


## Tube (cylindre conique) entre deux points : branches, cordes, manches.
func tube(a: Vector3, b: Vector3, r0: float, r1: float, segs: int, col: Color, caps := true, cap_col := Color(0, 0, 0, 0)) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.001:
		return
	var z := axis / length
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	var base := vary(col)
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for i in segs:
		var ang := TAU * i / segs
		var dir := x * cos(ang) + y * sin(ang)
		ring0.append(a + dir * r0)
		ring1.append(b + dir * r1)
	for i in segs:
		var j := (i + 1) % segs
		var mid := ((ring0[i] + ring0[j]) * 0.5) - a
		quad(ring0[i], ring0[j], ring1[j], ring1[i], vary(base, jitter * 0.6), mid - z * mid.dot(z))
	if caps:
		for i in range(1, segs - 1):
			var c0 := base.darkened(0.15) if cap_col.a == 0.0 else cap_col
			var c1 := base.lightened(0.05) if cap_col.a == 0.0 else cap_col
			tri(ring0[0], ring0[i], ring0[i + 1], c0, -z)
			tri(ring1[0], ring1[i], ring1[i + 1], c1, z)


## Objet de révolution autour de l'axe Y : `profile` est une liste de
## Vector2(rayon, hauteur) de bas en haut. `col_fn` (facultatif) reçoit
## (colonne, rangée) et rend la couleur de la face : douelles de tonneau, etc.
func lathe(center: Vector3, profile: Array, segs: int, col: Color, cap_bottom := true, cap_top := true, col_fn := Callable(), phase := 0.0) -> void:
	var rings: Array = []
	for pr in profile:
		var ring: Array[Vector3] = []
		for i in segs:
			var ang := TAU * i / segs + phase
			ring.append(center + Vector3(cos(ang) * pr.x, pr.y, sin(ang) * pr.x))
		rings.append(ring)
	for r in profile.size() - 1:
		for i in segs:
			var j := (i + 1) % segs
			var c: Color = col_fn.call(i, r) if col_fn.is_valid() else vary(col)
			var a: Vector3 = rings[r][i]
			var out := Vector3(a.x - center.x, 0.0, a.z - center.z)
			quad(rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i], c, out)
	if cap_bottom and profile[0].x > 0.0:
		var top0: Array = rings[0]
		for i in range(1, segs - 1):
			tri(top0[0], top0[i], top0[i + 1], col.darkened(0.3), Vector3.DOWN)
	var last: int = profile.size() - 1
	if cap_top and profile[last].x > 0.0:
		var top: Array = rings[last]
		var cc := vary(col).lightened(0.04)
		for i in range(1, segs - 1):
			tri(top[0], top[i], top[i + 1], cc, Vector3.UP)


## Sphère bosselée (icosaèdre subdivisé, sommets déplacés) : feuillages,
## buissons, rochers, choux. Dégradé du bas (sombre) vers le haut (clair).
func blob(center: Vector3, radius: Vector3, col_bottom: Color, col_top: Color, bump := 0.18, subdiv := 1) -> void:
	var verts: Array[Vector3] = []
	var faces: Array = []
	var t := (1.0 + sqrt(5.0)) / 2.0
	for v in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append((v as Vector3).normalized())
	faces = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for s in subdiv:
		var mids := {}
		var nf: Array = []
		for f in faces:
			var m: Array[int] = []
			for k in 3:
				var i0: int = f[k]
				var i1: int = f[(k + 1) % 3]
				var key := Vector2i(mini(i0, i1), maxi(i0, i1))
				if not mids.has(key):
					mids[key] = verts.size()
					verts.append(((verts[i0] + verts[i1]) * 0.5).normalized())
				m.append(mids[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var pts: Array[Vector3] = []
	for v in verts:
		pts.append(center + v * radius * (1.0 + rng.randf_range(-bump, bump)))
	for f in faces:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var c: Vector3 = pts[f[2]]
		var mid := (a + b + c) / 3.0
		var k := clampf(((mid.y - center.y) / maxf(radius.y, 0.001)) * 0.5 + 0.5, 0.0, 1.0)
		tri(a, b, c, vary(col_bottom.lerp(col_top, k)), mid - center)


## Pierre de taille irrégulière (boîte aux coins décalés).
func stone(center: Vector3, size: Vector3, col: Color) -> void:
	box(center, size, vary(col, jitter * 2.5), 0.16)


# --- Assemblage -----------------------------------------------------------------

func triangle_count() -> int:
	var n := 0
	for k in _layers:
		n += int(_layers[k].v.size() / 3.0)
	return n


## Rend le maillage final : une surface par couche, avec le matériau donné.
func commit(materials: Dictionary, mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	for k in _layers:
		var d: Dictionary = _layers[k]
		if d.v.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(d.v)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(d.n)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(d.c)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m: Material = materials.get(k, materials.get("base"))
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	_layers.clear()
	return mesh


## Matériau standard à couleurs par sommet (le seul dont la plupart des objets ont besoin).
static func vertex_material(roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	m.metallic_specular = 0.3
	return m
