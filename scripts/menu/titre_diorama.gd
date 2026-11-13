class_name TitreDiorama
extends Node3D
## Décor de l'écran titre : une île de terre flottante en low-poly, avec un petit
## village (longères, grange, puits, arbres), une rivière qui tombe en cascade,
## un terrain de foot et une grande roue (le parc de loisirs n'est jamais loin).
## Tout est fabriqué en code avec LpKit et FermeModeles (aucun asset externe).

const DEMI := 36.0
const PAS := 2.0
const SOL_BAS := -3.2
const ROCHE_BAS := -7.0

## Plates-formes aplanies : [centre x, centre z, rayon, hauteur].
const REPLATS := [
	[-6.0, -8.0, 11.0, 0.6],   # longère
	[10.0, -14.0, 8.0, 0.8],   # grange
	[-16.0, 14.0, 13.0, 0.35], # terrain de foot
	[21.0, 21.0, 9.0, 1.2],    # grande roue
	[4.0, 6.0, 6.0, 0.5],      # place et puits
]

var mats := {}
var roue: Node3D
var nacelles: Array[Node3D] = []
var nuages: Array[Node3D] = []
var _t := 0.0
var _noise := FastNoiseLite.new()
var stats := {"triangles": 0}


func _ready() -> void:
	_noise.seed = 11
	_noise.frequency = 0.035
	_materiaux()
	_ile()
	_eau()
	_village()
	_foot()
	_grande_roue()
	_nuages()


func _process(delta: float) -> void:
	_t += delta
	if roue != null:
		roue.rotation.z = -_t * 0.12
		for i in nacelles.size():
			var a := -_t * 0.12 + TAU * i / nacelles.size()
			nacelles[i].position = roue.position + Vector3(cos(a) * 7.0, sin(a) * 7.0, 0.0)
	for i in nuages.size():
		var n := nuages[i]
		n.position.x += delta * (0.6 + 0.15 * i)
		if n.position.x > 110.0:
			n.position.x = -110.0


# --- Relief --------------------------------------------------------------------------

## Lit de la rivière : z en fonction de x.
static func riviere_z(x: float) -> float:
	return 2.0 + 9.0 * sin(x / 13.0) - x * 0.15


func hauteur(x: float, z: float) -> float:
	var h := 0.9 + _noise.get_noise_2d(x, z) * 1.6
	# Une colline au fond à gauche.
	h += 6.5 * exp(-(pow(x + 22.0, 2) + pow(z + 22.0, 2)) / 160.0)
	for r in REPLATS:
		var d := Vector2(x - r[0], z - r[1]).length()
		var w := clampf((d - r[2] * 0.6) / (r[2] * 0.4), 0.0, 1.0)
		w = w * w * (3.0 - 2.0 * w)
		h = lerpf(r[3], h, w)
	# La rivière creuse son lit.
	var dz := absf(z - riviere_z(x))
	if dz < 4.0:
		var t := 1.0 - dz / 4.0
		h = lerpf(h, -1.1, t * t * (3.0 - 2.0 * t))
	return h


func _couleur(x: float, z: float, h: float, k: LpKit) -> Color:
	var t := _noise.get_noise_2d(x * 2.0 + 50.0, z * 2.0) * 0.5 + 0.5
	var c := Color("6a9a3c").lerp(Color("9ab84c"), t)
	if h < -0.5:
		c = Color("8a7a58")
	elif h > 4.5:
		c = c.lerp(Color("587a34"), 0.5)
	return k.vary(c, 0.05)


func _ile() -> void:
	var k := LpKit.new(3)
	k.jitter = 0.04
	var n := int(DEMI * 2.0 / PAS)
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			hs[j * (n + 1) + i] = hauteur(-DEMI + i * PAS, -DEMI + j * PAS)
	for j in n:
		for i in n:
			var x0 := -DEMI + i * PAS
			var z0 := -DEMI + j * PAS
			var p00 := Vector3(x0, hs[j * (n + 1) + i], z0)
			var p10 := Vector3(x0 + PAS, hs[j * (n + 1) + i + 1], z0)
			var p01 := Vector3(x0, hs[(j + 1) * (n + 1) + i], z0 + PAS)
			var p11 := Vector3(x0 + PAS, hs[(j + 1) * (n + 1) + i + 1], z0 + PAS)
			var hm := (p00.y + p11.y) * 0.5
			if (i + j) % 2 == 0:
				k.tri(p00, p10, p11, _couleur(x0 + 1.3, z0 + 0.7, hm, k), Vector3.UP)
				k.tri(p00, p11, p01, _couleur(x0 + 0.7, z0 + 1.3, hm, k), Vector3.UP)
			else:
				k.tri(p00, p10, p01, _couleur(x0 + 0.7, z0 + 0.7, hm, k), Vector3.UP)
				k.tri(p10, p11, p01, _couleur(x0 + 1.3, z0 + 1.3, hm, k), Vector3.UP)
	# Pourtour : points du bord, dans l'ordre, avec leur hauteur.
	var bord: Array[Vector3] = []
	for i in n:
		bord.append(Vector3(-DEMI + i * PAS, hs[i], -DEMI))
	for j in n:
		bord.append(Vector3(DEMI, hs[j * (n + 1) + n], -DEMI + j * PAS))
	for i in n:
		bord.append(Vector3(DEMI - i * PAS, hs[n * (n + 1) + n - i], DEMI))
	for j in n:
		bord.append(Vector3(-DEMI, hs[(n - j) * (n + 1)], DEMI - j * PAS))
	var m := bord.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var terre_y: Array[float] = []
	for i in m:
		terre_y.append(SOL_BAS + rng.randf_range(-0.6, 0.6))
	for i in m:
		var a := bord[i]
		var b := bord[(i + 1) % m]
		var out := Vector3(a.x + b.x, 0, a.z + b.z).normalized()
		var ya := terre_y[i]
		var yb := terre_y[(i + 1) % m]
		# Herbe qui déborde un peu, terre, puis roche.
		k.quad(a, b, Vector3(b.x, b.y - 0.35, b.z), Vector3(a.x, a.y - 0.35, a.z), k.vary(Color("5d8a34"), 0.05), out)
		k.quad(Vector3(a.x, a.y - 0.35, a.z), Vector3(b.x, b.y - 0.35, b.z), Vector3(b.x, yb, b.z), Vector3(a.x, ya, a.z), k.vary(Color("7a5a3a"), 0.08), out)
		k.quad(Vector3(a.x, ya, a.z), Vector3(b.x, yb, b.z), Vector3(b.x, ROCHE_BAS, b.z), Vector3(a.x, ROCHE_BAS, a.z), k.vary(Color("6e6a64"), 0.08), out)
	# Dessous : la roche se resserre en pointe, en deux anneaux bosselés.
	var anneaux := [[ROCHE_BAS, 1.0], [-14.0, 0.62], [-21.0, 0.3]]
	var prev: Array[Vector3] = []
	for i in m:
		prev.append(Vector3(bord[i].x, ROCHE_BAS, bord[i].z))
	for r in range(1, anneaux.size()):
		var cur: Array[Vector3] = []
		for i in m:
			var s: float = anneaux[r][1] * rng.randf_range(0.9, 1.08)
			cur.append(Vector3(bord[i].x * s, float(anneaux[r][0]) + rng.randf_range(-1.5, 1.5), bord[i].z * s))
		for i in m:
			var a := prev[i]
			var b := prev[(i + 1) % m]
			var c := cur[(i + 1) % m]
			var d := cur[i]
			var out := Vector3(a.x + b.x, -2.0, a.z + b.z).normalized()
			var col := Color("5e5a55").lerp(Color("47433f"), float(r) / anneaux.size())
			k.quad(a, b, c, d, k.vary(col, 0.1), out)
		prev = cur
	var pointe := Vector3(rng.randf_range(-3, 3), -30.0, rng.randf_range(-3, 3))
	for i in m:
		k.tri(prev[i], prev[(i + 1) % m], pointe, k.vary(Color("403c38"), 0.1), Vector3(prev[i].x, -1.0, prev[i].z).normalized())
	_poser(k, "Ile")


func _eau() -> void:
	var w := LpKit.new(9)
	w.layer = "eau"
	var y := -0.35
	var x := -DEMI
	while x < DEMI - 0.01:
		var x1 := minf(x + PAS, DEMI)
		var z0 := riviere_z(x)
		var z1 := riviere_z(x1)
		w.quad(Vector3(x, y, z0 - 3.4), Vector3(x1, y, z1 - 3.4), Vector3(x1, y, z1 + 3.4), Vector3(x, y, z0 + 3.4), Color("2f6d7a"), Vector3.UP)
		x = x1
	# Cascades aux deux bouts de la rivière.
	for side in [-1.0, 1.0]:
		var ex: float = DEMI * side + 0.05 * side
		var ez := riviere_z(ex)
		var out := Vector3(side, 0, 0)
		w.quad(Vector3(ex, y, ez - 2.2), Vector3(ex, y, ez + 2.2), Vector3(ex + side * 0.6, -16.0, ez + 1.4), Vector3(ex + side * 0.6, -16.0, ez - 1.4), Color("8fc6d0"), out)
	_poser(w, "Riviere", Transform3D.IDENTITY, false)


# --- Village ----------------------------------------------------------------------------

func _sol(x: float, z: float) -> Vector3:
	return Vector3(x, hauteur(x, z), z)


func _pose(k: LpKit, x: float, z: float, yaw_deg := 0.0, s := 1.0) -> void:
	k.xf = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * s), _sol(x, z))


func _village() -> void:
	var k := LpKit.new(21)
	_pose(k, -6.0, -8.0, 8.0, 0.8)
	FermeModeles.maison(k)
	_pose(k, 10.0, -14.0, -20.0, 0.7)
	FermeModeles.grange(k)
	_pose(k, 4.0, 6.0, 0.0, 1.0)
	FermeModeles.puits(k)
	_pose(k, 6.0, 4.5, 30.0, 1.0)
	FermeModeles.charrette(k)
	_pose(k, -1.0, 2.0, 70.0, 1.0)
	FermeModeles.tas_bois(k)
	for p in [[2.0, -12.0], [14.0, -5.0], [-12.0, -1.0]]:
		_pose(k, p[0], p[1], randf() * 360.0, 1.0)
		FermeModeles.botte_ronde(k)
	k.xf = Transform3D.IDENTITY
	_chemin(k, [Vector2(-6, -3), Vector2(0, 2), Vector2(4, 6), Vector2(8, 10), Vector2(12, 12), Vector2(14, 12)])
	_chemin(k, [Vector2(4, 6), Vector2(-4, 10), Vector2(-8, 13)])
	# Pont de bois sur la rivière.
	var bx := 1.0
	var bz := riviere_z(bx)
	k.xf = Transform3D(Basis(), Vector3(bx, 0.35, bz))
	k.box(Vector3.ZERO, Vector3(2.6, 0.25, 8.0), Color("8a6a46"), 0.03)
	for sx in [-1.2, 1.2]:
		k.beam(Vector3(sx, 0.1, -4.0), Vector3(sx, 0.1, 4.0), 0.12, 0.9, Color("6e5236"))
	k.xf = Transform3D.IDENTITY
	_poser(k, "Village")
	var arbres := LpKit.new(22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var places := 0
	var essais := 0
	while places < 34 and essais < 400:
		essais += 1
		var x := rng.randf_range(-DEMI + 3, DEMI - 3)
		var z := rng.randf_range(-DEMI + 3, DEMI - 3)
		if absf(z - riviere_z(x)) < 5.0:
			continue
		var libre := true
		for r in REPLATS:
			if Vector2(x - r[0], z - r[1]).length() < r[2] + 1.5:
				libre = false
		if not libre:
			continue
		_pose(arbres, x, z, rng.randf() * 360.0, rng.randf_range(0.7, 1.15))
		var colline := Vector2(x + 22.0, z + 22.0).length() < 16.0
		if colline or rng.randf() < 0.25:
			FermeModeles.sapin(arbres, rng.randf_range(1.0, 1.4))
		elif rng.randf() < 0.5:
			FermeModeles.fruitier(arbres)
		else:
			FermeModeles.chene(arbres, rng.randf_range(0.7, 1.0))
		places += 1
	arbres.xf = Transform3D.IDENTITY
	_poser(arbres, "Arbres")


func _chemin(k: LpKit, pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x) * 1.1
		var steps := maxi(int((b - a).length() / 1.0), 1)
		for s in steps:
			var p0 := a.lerp(b, float(s) / steps)
			var p1 := a.lerp(b, float(s + 1) / steps)
			var q := [p0 - nrm, p1 - nrm, p1 + nrm, p0 + nrm]
			var v: Array[Vector3] = []
			for qq: Vector2 in q:
				v.append(Vector3(qq.x, hauteur(qq.x, qq.y) + 0.06, qq.y))
			k.quad(v[0], v[1], v[2], v[3], k.vary(Color("b59a6a"), 0.06), Vector3.UP)


func _foot() -> void:
	var k := LpKit.new(31)
	var cx := -16.0
	var cz := 14.0
	var y := 0.38
	var L := 18.0
	var W := 11.0
	k.jitter = 0.0
	for i in 6:
		var x0 := cx - L * 0.5 + i * L / 6.0
		var col := Color("5c9e3c") if i % 2 == 0 else Color("68ad44")
		k.quad(Vector3(x0, y, cz - W * 0.5), Vector3(x0 + L / 6.0, y, cz - W * 0.5), Vector3(x0 + L / 6.0, y, cz + W * 0.5), Vector3(x0, y, cz + W * 0.5), col, Vector3.UP)
	var blanc := Color("f2f2ea")
	var t := 0.12
	var ly := y + 0.02
	k.box(Vector3(cx, ly, cz - W * 0.5), Vector3(L, 0.03, t), blanc, 0.0, false)
	k.box(Vector3(cx, ly, cz + W * 0.5), Vector3(L, 0.03, t), blanc, 0.0, false)
	k.box(Vector3(cx - L * 0.5, ly, cz), Vector3(t, 0.03, W), blanc, 0.0, false)
	k.box(Vector3(cx + L * 0.5, ly, cz), Vector3(t, 0.03, W), blanc, 0.0, false)
	k.box(Vector3(cx, ly, cz), Vector3(t, 0.03, W), blanc, 0.0, false)
	for i in 16:
		var a0 := TAU * i / 16.0
		var a1 := TAU * (i + 1) / 16.0
		k.beam(Vector3(cx + cos(a0) * 1.6, ly, cz + sin(a0) * 1.6), Vector3(cx + cos(a1) * 1.6, ly, cz + sin(a1) * 1.6), t, 0.03, blanc)
	for side in [-1.0, 1.0]:
		var gx: float = cx + side * L * 0.5
		k.beam(Vector3(gx, y, cz - 1.8), Vector3(gx, y + 1.5, cz - 1.8), 0.1, 0.1, blanc)
		k.beam(Vector3(gx, y, cz + 1.8), Vector3(gx, y + 1.5, cz + 1.8), 0.1, 0.1, blanc)
		k.beam(Vector3(gx, y + 1.5, cz - 1.8), Vector3(gx, y + 1.5, cz + 1.8), 0.1, 0.1, blanc)
	# Une petite tribune en bois.
	for r in 3:
		k.box(Vector3(cx, y + 0.3 + r * 0.4, cz - W * 0.5 - 1.4 - r * 0.6), Vector3(10.0, 0.4, 0.7), k.vary(Color("8a6a46"), 0.05), 0.02)
	_poser(k, "Foot")


func _grande_roue() -> void:
	var cx := 21.0
	var cz := 21.0
	var base := 1.2
	var hub := Vector3(cx, base + 8.5, cz)
	var k := LpKit.new(41)
	var acier := Color("dfe3e6")
	for side in [-1.0, 1.0]:
		var z: float = cz + side * 1.0
		k.beam(Vector3(cx - 4.0, base, z), Vector3(cx, hub.y, z), 0.25, 0.25, acier)
		k.beam(Vector3(cx + 4.0, base, z), Vector3(cx, hub.y, z), 0.25, 0.25, acier)
	k.beam(Vector3(cx, hub.y, cz - 1.2), Vector3(cx, hub.y, cz + 1.2), 0.35, 0.35, Color("8a8f94"))
	k.box(Vector3(cx, base + 0.3, cz + 3.0), Vector3(3.0, 0.6, 2.0), Color("c8463c"), 0.05)
	_poser(k, "Roue pieds")
	var r := LpKit.new(42)
	r.jitter = 0.03
	var seg := 20
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for z in [-0.7, 0.7]:
			var col := Color("f2c14e") if i % 2 == 0 else Color("e2574c")
			r.beam(Vector3(cos(a0) * 7.0, sin(a0) * 7.0, z), Vector3(cos(a1) * 7.0, sin(a1) * 7.0, z), 0.18, 0.18, col)
		if i % 2 == 0:
			r.beam(Vector3.ZERO, Vector3(cos(a0) * 7.0, sin(a0) * 7.0, -0.7), 0.08, 0.08, acier)
			r.beam(Vector3.ZERO, Vector3(cos(a0) * 7.0, sin(a0) * 7.0, 0.7), 0.08, 0.08, acier)
	roue = _poser(r, "Roue")
	roue.position = hub
	var couleurs := [Color("4a90c8"), Color("e2574c"), Color("f2c14e"), Color("6ab04c"), Color("9b6bc8")]
	for i in 10:
		var c := LpKit.new(50 + i)
		var col: Color = couleurs[i % couleurs.size()]
		c.beam(Vector3(0, 0, 0), Vector3(0, -0.6, 0), 0.06, 0.06, acier)
		c.box(Vector3(0, -1.2, 0), Vector3(1.1, 0.9, 1.0), col, 0.04)
		c.box(Vector3(0, -0.68, 0), Vector3(1.3, 0.12, 1.2), col.darkened(0.25), 0.0)
		var n := _poser(c, "Nacelle")
		nacelles.append(n)
	_process(0.0)


func _nuages() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for i in 6:
		var k := LpKit.new(70 + i)
		FermeModeles.nuage(k, rng.randf_range(0.6, 1.0))
		var n := _poser(k, "Nuage", Transform3D(Basis(), Vector3(rng.randf_range(-100, 100), rng.randf_range(8, 20), rng.randf_range(-90, -30))), false)
		n.set_meta("nuage", true)
		nuages.append(n)


# --- Outils ------------------------------------------------------------------------------

func _materiaux() -> void:
	mats["base"] = LpKit.vertex_material(0.9)
	var verre := LpKit.vertex_material(0.12)
	mats["verre"] = verre
	mats["flamme"] = LpKit.vertex_material(0.5)
	var eau := StandardMaterial3D.new()
	eau.vertex_color_use_as_albedo = true
	eau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eau.albedo_color = Color(1, 1, 1, 0.85)
	eau.roughness = 0.05
	eau.metallic_specular = 0.8
	mats["eau"] = eau
	var vent := ShaderMaterial.new()
	vent.shader = load("res://scripts/demo/lp_vent.gdshader")
	mats["vent"] = vent
	mats["ble"] = vent
	var nuage := LpKit.vertex_material(1.0)
	nuage.disable_receive_shadows = true
	mats["nuage"] = nuage


func _poser(k: LpKit, nom: String, xf := Transform3D.IDENTITY, ombre := true) -> MeshInstance3D:
	stats.triangles += k.triangle_count()
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = k.commit(mats)
	mi.transform = xf
	if not ombre:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
