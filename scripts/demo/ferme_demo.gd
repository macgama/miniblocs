extends Node3D
## Démo « ferme low-poly » : jusqu'où on peut pousser le style de MiniBlocs.
## Tout est généré en code (LpKit + FermeModeles), aucun fichier 3D ni texture.
##
## Commandes : 1 à 4 lumière · C point de vue suivant · clic droit glissé tourner ·
## molette zoom · ZQSD / flèches déplacer · H masquer l'aide.

const LUMIERES := ["Fin d'après-midi", "Matin brumeux", "Plein midi", "Soir, lanternes allumées"]
const VUES := [
	# cible, lacet (°), tangage (°), distance
	[Vector3(-3, 0, 5), 32.0, 36.0, 64.0],
	[Vector3(-1, 2.6, 3), 18.0, 5.0, 23.0],
	[Vector3(-4, 3.5, 2), -12.0, 3.5, 46.0],
	[Vector3(3, 5.0, 2), 38.0, 16.0, 12.5],
]
const NOMS_VUES := ["Vue d'ensemble (gestion)", "Dans la cour", "Depuis le champ de blé", "Détail du toit de chaume"]

# Plan de la ferme (mètres, X vers l'est, Z vers le sud).
const MAISON := Vector3(0, 0, 0)
const GRANGE := Vector3(-19, 0, 4)
const PUITS := Vector3(3.5, 0, 11)
const MARE := Vector2(-38, 9)
const MARE_R := 7.0
const CHAMP := Rect2(-50, 27, 86, 46)
const LABOUR := Rect2(40, 27, 40, 46)
const POTAGER := Rect2(10, 7, 8, 7)
const ENCLOS := Rect2(14, -18, 24, 20)

enum Zone { HERBE, COUR, CHEMIN, CHAMP, LABOUR, POTAGER, BERGE, SOL }

var mats := {}
var noise := FastNoiseLite.new()
var noise_fine := FastNoiseLite.new()
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var camera: Camera3D
var cam_attr: CameraAttributesPractical
var lampes: Array[OmniLight3D] = []
var fumee: GPUParticles3D
var hud: Label
var stats := {"triangles": 0, "objets": 0, "herbes": 0, "epis": 0}
var lumiere := 0
var vue := 0

var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 30.0
var _dist := 60.0
var _drag := false


func _ready() -> void:
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	noise_fine.seed = 11
	noise_fine.frequency = 0.15
	_materiaux()
	_terrain()
	_batiments()
	_decor()
	_vegetation()
	_ciel_et_lumiere()
	_camera_et_aide()
	appliquer_lumiere(0)
	appliquer_vue(0)


# --- Relief et zones ------------------------------------------------------------

func route_z(x: float) -> float:
	return 22.0 + sin(x * 0.04) * 1.5


func hauteur(x: float, z: float) -> float:
	var d := Vector2(x + 4.0, z - 6.0).length()
	var plat := smoothstep(30.0, 95.0, d)
	var h := noise.get_noise_2d(x, z) * 7.0 * plat
	h += smoothstep(110.0, 260.0, d) * (noise.get_noise_2d(x * 0.4 + 300.0, z * 0.4) * 0.5 + 0.6) * 30.0
	h += noise_fine.get_noise_2d(x, z) * 0.12
	var dm := Vector2(x, z).distance_to(MARE)
	h -= smoothstep(MARE_R + 1.5, MARE_R - 1.0, dm) * 1.2
	return h


func zone(x: float, z: float) -> int:
	if absf(x - MAISON.x) < 8.2 and absf(z - MAISON.z) < 4.2:
		return Zone.SOL
	if absf(x - GRANGE.x) < 5.5 and absf(z - GRANGE.z) < 7.5:
		return Zone.SOL
	if Vector2(x, z).distance_to(MARE) < MARE_R + 0.8:
		return Zone.BERGE
	if absf(z - route_z(x)) < 1.9:
		return Zone.CHEMIN
	if z > 12.0 and z < 22.0 and absf(x - 1.0 - sin(z * 0.3) * 0.6) < 1.5:
		return Zone.CHEMIN
	if POTAGER.has_point(Vector2(x, z)):
		return Zone.POTAGER
	var e := Vector2((x + 4.0) / 15.0, (z - 9.5) / 6.5)
	if e.length() < 1.0 + noise_fine.get_noise_2d(x, z) * 0.15:
		return Zone.COUR
	if CHAMP.has_point(Vector2(x, z)):
		return Zone.CHAMP
	if LABOUR.has_point(Vector2(x, z)):
		return Zone.LABOUR
	if POTAGER.has_point(Vector2(x, z)):
		return Zone.POTAGER
	return Zone.HERBE


func _couleur_sol(x: float, z: float, k: LpKit) -> Color:
	var zn := zone(x, z)
	match zn:
		Zone.SOL:
			return k.vary(Color("7d6a50"))
		Zone.COUR:
			return k.vary(Color("8f7a5c").lerp(Color("7c8a52"), clampf(noise_fine.get_noise_2d(x * 2.0, z * 2.0) + 0.1, 0.0, 0.6)))
		Zone.CHEMIN:
			var rut := absf(absf(z - route_z(x)) - 0.75) < 0.3
			return k.vary(Color("9b8262").darkened(0.12 if rut else 0.0))
		Zone.CHAMP:
			return k.vary(Color("a48c50"))
		Zone.LABOUR:
			return k.vary(Color("6b4e33") if int(floor(z)) % 2 == 0 else Color("5a4029"), 0.04)
		Zone.POTAGER:
			return k.vary(Color("5b4430"))
		Zone.BERGE:
			return k.vary(Color("5f5a3f"))
	var t := noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5
	var c := Color("5f8a36").lerp(Color("8fa848"), t)
	var d := Vector2(x, z).length()
	if d > 120.0:
		c = c.lerp(Color("4f6e34"), 0.4)
	return k.vary(c, 0.05)


func _terrain() -> void:
	# Deux grilles : fine (1 m) autour de la ferme, large (4 m) jusqu'à l'horizon.
	var k := LpKit.new(3)
	k.jitter = 0.035
	_grille(k, Rect2(-64, -48, 128, 128), 1.0, 0.0, Rect2())
	_poser(k, "Sol proche")
	var k2 := LpKit.new(4)
	k2.jitter = 0.035
	_grille(k2, Rect2(-320, -320, 640, 640), 4.0, -0.06, Rect2(-62, -46, 124, 124))
	_poser(k2, "Sol lointain")
	# La mare : un disque d'eau à peine plus haut que le fond.
	var w := LpKit.new(5)
	w.layer = "eau"
	var c := Vector3(MARE.x, -0.28, MARE.y)
	for i in 24:
		var a0 := TAU * i / 24.0
		var a1 := TAU * (i + 1) / 24.0
		w.tri(c, c + Vector3(cos(a0), 0, sin(a0)) * (MARE_R + 1.0), c + Vector3(cos(a1), 0, sin(a1)) * (MARE_R + 1.0), Color("2e4a48"), Vector3.UP)
	_poser(w, "Mare")


func _grille(k: LpKit, r: Rect2, cell: float, drop: float, hole: Rect2) -> void:
	var nx := int(r.size.x / cell)
	var nz := int(r.size.y / cell)
	var hs := PackedFloat32Array()
	hs.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			var x := r.position.x + i * cell
			var z := r.position.y + j * cell
			hs[j * (nx + 1) + i] = hauteur(x, z)
	for j in nz:
		for i in nx:
			var x0 := r.position.x + i * cell
			var z0 := r.position.y + j * cell
			var inside := hole.has_area() and hole.has_point(Vector2(x0 + cell * 0.5, z0 + cell * 0.5))
			var dy := drop if inside else 0.0
			var p00 := Vector3(x0, hs[j * (nx + 1) + i] + dy, z0)
			var p10 := Vector3(x0 + cell, hs[j * (nx + 1) + i + 1] + dy, z0)
			var p01 := Vector3(x0, hs[(j + 1) * (nx + 1) + i] + dy, z0 + cell)
			var p11 := Vector3(x0 + cell, hs[(j + 1) * (nx + 1) + i + 1] + dy, z0 + cell)
			if (i + j) % 2 == 0:
				k.tri(p00, p10, p11, _couleur_sol(x0 + cell * 0.66, z0 + cell * 0.33, k), Vector3.UP)
				k.tri(p00, p11, p01, _couleur_sol(x0 + cell * 0.33, z0 + cell * 0.66, k), Vector3.UP)
			else:
				k.tri(p00, p10, p01, _couleur_sol(x0 + cell * 0.33, z0 + cell * 0.33, k), Vector3.UP)
				k.tri(p10, p11, p01, _couleur_sol(x0 + cell * 0.66, z0 + cell * 0.66, k), Vector3.UP)


# --- Objets ---------------------------------------------------------------------------

func _materiaux() -> void:
	mats["base"] = LpKit.vertex_material(0.9)
	var verre := LpKit.vertex_material(0.12)
	verre.emission_enabled = true
	verre.emission = Color("ffb35c")
	verre.emission_energy_multiplier = 0.0
	mats["verre"] = verre
	var flamme := LpKit.vertex_material(0.5)
	flamme.emission_enabled = true
	flamme.emission = Color("ffc070")
	flamme.emission_energy_multiplier = 0.0
	mats["flamme"] = flamme
	var eau := StandardMaterial3D.new()
	eau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eau.albedo_color = Color(0.13, 0.24, 0.23, 0.82)
	eau.roughness = 0.03
	eau.metallic_specular = 0.7
	mats["eau"] = eau
	var vent := ShaderMaterial.new()
	vent.shader = load("res://scripts/demo/lp_vent.gdshader")
	mats["vent"] = vent
	var ble := ShaderMaterial.new()
	ble.shader = vent.shader
	ble.set_shader_parameter("force", 0.12)
	ble.set_shader_parameter("backlight_color", Color(0.6, 0.5, 0.2))
	ble.set_shader_parameter("hue_variation", 0.08)
	mats["ble"] = ble
	var nuage := LpKit.vertex_material(1.0)
	nuage.disable_receive_shadows = true
	mats["nuage"] = nuage


func _poser(k: LpKit, nom: String, xf := Transform3D.IDENTITY, ombre := true) -> MeshInstance3D:
	stats.triangles += k.triangle_count()
	stats.objets += 1
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = k.commit(mats)
	mi.transform = xf
	if not ombre:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _sol(p: Vector3) -> Vector3:
	return Vector3(p.x, hauteur(p.x, p.z), p.z)


func _pose(k: LpKit, p: Vector3, yaw_deg := 0.0, s := 1.0) -> void:
	k.xf = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * s), _sol(p))


func _batiments() -> void:
	var k := LpKit.new(21)
	k.xf = Transform3D(Basis(), _sol(MAISON))
	var infos := FermeModeles.maison(k)
	_poser(k, "Maison")
	var g := LpKit.new(22)
	g.xf = Transform3D(Basis(Vector3.UP, deg_to_rad(90)), _sol(GRANGE))
	var ginfos := FermeModeles.grange(g)
	_poser(g, "Grange")
	var base := _sol(MAISON)
	_lampe(base + infos.lanterne + Vector3(0, 0.15, 0.15))
	_lampe(_sol(GRANGE) + Basis(Vector3.UP, deg_to_rad(90)) * ginfos.lanterne + Vector3(0.15, 0.15, 0))
	_fumee(base + infos.cheminee)


func _lampe(p: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color("ffb867")
	l.omni_range = 9.0
	l.omni_attenuation = 1.4
	l.shadow_enabled = true
	l.position = p
	l.light_energy = 0.0
	add_child(l)
	lampes.append(l)


func _fumee(p: Vector3) -> void:
	fumee = GPUParticles3D.new()
	fumee.name = "Fumee"
	fumee.amount = 26
	fumee.lifetime = 9.0
	fumee.preprocess = 9.0
	fumee.position = p
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.35, 0.12, 0.2)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 2.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 0.73, 0.7, 0.55))
	grad.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	fumee.process_material = pm
	var sph := SphereMesh.new()
	sph.radius = 0.4
	sph.height = 0.7
	sph.radial_segments = 7
	sph.rings = 3
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.disable_receive_shadows = true
	sph.material = m
	fumee.draw_pass_1 = sph
	fumee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fumee)


func _decor() -> void:
	var k := LpKit.new(31)
	# Puits, charrette, tonneaux, caisses, bois, bottes.
	_pose(k, PUITS, 10)
	FermeModeles.puits(k)
	_pose(k, Vector3(-8.5, 0, 12.5), 63)
	FermeModeles.charrette(k)
	var tonneaux := [Vector3(5.6, 0, 4.4), Vector3(6.35, 0, 4.5), Vector3(5.95, 0, 5.15), Vector3(-10.8, 0, 7.4)]
	for p in tonneaux:
		_pose(k, p, k.rng.randf() * 90.0)
		FermeModeles.tonneau(k)
	# Un tonneau couché.
	k.xf = Transform3D(Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, 0.4), _sol(Vector3(7.3, 0, 5.4)) + Vector3(0.0, 0.33, 0))
	k.xf = k.xf * Transform3D(Basis(), Vector3(0, -0.42, 0))
	FermeModeles.tonneau(k)
	for p in [Vector3(-11.5, 0, 9.0), Vector3(-11.4, 0, 9.7), Vector3(4.6, 0, 4.6)]:
		_pose(k, p, k.rng.randf_range(-20, 20))
		FermeModeles.caisse(k, 0.6)
	_pose(k, Vector3(-11.45, 0.6, 9.35), 30)
	FermeModeles.caisse(k, 0.5)
	_pose(k, Vector3(9.6, 0, 0.0), 90)
	FermeModeles.tas_bois(k, 4.0, 6)
	_poser(k, "Cour")

	# Enclos : clôture de perches et bottes rondes.
	var e := LpKit.new(32)
	_cloture(e, ENCLOS, 2.6, Vector2(ENCLOS.position.x + 1.0, ENCLOS.position.x + 4.0))
	for p in [Vector3(22, 0, -10), Vector3(23.6, 0, -9.4), Vector3(30, 0, -4), Vector3(27, 0, -14)]:
		_pose(e, p, e.rng.randf() * 180.0)
		FermeModeles.botte_ronde(e)
	for i in 6:
		var bp := _sol(Vector3(-11.2, 0, -3.0 + (i % 3) * 0.55)) + Vector3(0, 0.45 * int(i / 3.0), 0)
		e.xf = Transform3D(Basis(Vector3.UP, deg_to_rad(90 + e.rng.randf_range(-6, 6))), bp)
		FermeModeles.botte_carree(e)
	_poser(e, "Enclos")

	# Potager : planches de terre, choux, salades, rames de haricots, piquets.
	var pg := LpKit.new(33)
	for row in 4:
		var z := POTAGER.position.y + 1.0 + row * 1.6
		_pose(pg, Vector3(POTAGER.get_center().x, 0, z))
		pg.box(Vector3(0, 0.08, 0), Vector3(POTAGER.size.x - 1.2, 0.22, 0.9), Color("4e3a28"), 0.04)
		for i in 9:
			var x := -POTAGER.size.x * 0.5 + 1.0 + i * 0.72
			if row == 3:
				pg.tube(Vector3(x, 0, -0.2), Vector3(x + 0.1, 1.8, 0.0), 0.02, 0.015, 4, FermeModeles.BOIS)
				pg.tube(Vector3(x, 0, 0.2), Vector3(x + 0.1, 1.8, 0.0), 0.02, 0.015, 4, FermeModeles.BOIS)
				pg.blob(Vector3(x + 0.05, 1.0, 0), Vector3(0.22, 0.75, 0.22), Color("2f5a22"), Color("6f9f3c"), 0.35, 1)
			elif row % 2 == 0:
				pg.blob(Vector3(x, 0.3, 0), Vector3(0.28, 0.22, 0.28), Color("3c6b4a"), Color("8fb58a"), 0.25, 1)
			else:
				pg.blob(Vector3(x, 0.26, 0), Vector3(0.2, 0.12, 0.2), Color("5f9a2e"), Color("b6d860"), 0.3, 1)
	_cloture_basse(pg, POTAGER.grow(0.3))
	_pose(pg, Vector3(-30.0, 0, 46.0), 20)
	FermeModeles.epouvantail(pg)
	_poser(pg, "Potager")

	# Basse-cour.
	var b := LpKit.new(34)
	var plumes := [Color("f2ece0"), Color("b8642e"), Color("8a4a24"), Color("f2ece0"), Color("3a3430"), Color("d9a05c")]
	for i in 9:
		var pos := Vector3(-2.0 + b.rng.randf_range(-6, 6), 0, 9.0 + b.rng.randf_range(-3, 3))
		_pose(b, pos, b.rng.randf() * 360.0)
		FermeModeles.poule(b, plumes[i % plumes.size()], i == 0)
	# Pierres et rochers.
	for i in 30:
		var a := b.rng.randf() * TAU
		var d := b.rng.randf_range(22.0, 70.0)
		var pr := Vector3(cos(a) * d - 4.0, 0, sin(a) * d * 0.8)
		if zone(pr.x, pr.z) != Zone.HERBE:
			continue
		_pose(b, pr, 0)
		var s := b.rng.randf_range(0.3, 1.2)
		b.blob(Vector3(0, s * 0.2, 0), Vector3(s, s * 0.6, s * 0.8), Color("7a756c"), Color("aaa498"), 0.3, 0)
	# Pierres autour de la mare et nénuphars.
	for i in 26:
		var a := TAU * i / 26.0 + b.rng.randf() * 0.2
		var pr := Vector3(MARE.x + cos(a) * (MARE_R + 0.6), 0, MARE.y + sin(a) * (MARE_R + 0.6))
		_pose(b, pr, 0)
		var s := b.rng.randf_range(0.25, 0.6)
		b.blob(Vector3(0, 0, 0), Vector3(s, s * 0.6, s), Color("6f6a60"), Color("9d978a"), 0.3, 0)
	for i in 10:
		var pr := Vector3(MARE.x + b.rng.randf_range(-4, 4), 0, MARE.y + b.rng.randf_range(-4, 4))
		b.xf = Transform3D(Basis(Vector3.UP, b.rng.randf() * TAU), Vector3(pr.x, -0.26, pr.z))
		b.lathe(Vector3.ZERO, [Vector2(0.35, 0), Vector2(0.35, 0.015)], 7, Color("4f7a2e"), false, true)
		if i % 3 == 0:
			b.blob(Vector3(0.1, 0.06, 0), Vector3(0.08, 0.05, 0.08), Color("e8d0d8"), Color("ffffff"), 0.2, 0)
	_poser(b, "Animaux et pierres")

	# Nuages.
	var n := LpKit.new(35)
	for i in 14:
		var a := TAU * i / 14.0 + n.rng.randf() * 0.4
		var d := n.rng.randf_range(160.0, 320.0)
		n.xf = Transform3D(Basis(Vector3.UP, n.rng.randf() * TAU), Vector3(cos(a) * d, n.rng.randf_range(70.0, 110.0), sin(a) * d))
		FermeModeles.nuage(n, n.rng.randf_range(0.8, 1.5))
	var nm := _poser(n, "Nuages", Transform3D.IDENTITY, false)
	nm.material_override = mats["nuage"]


func _cloture(k: LpKit, r: Rect2, pas: float, porte: Vector2) -> void:
	var coins := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for c in 4:
		var a: Vector2 = coins[c]
		var b: Vector2 = coins[(c + 1) % 4]
		var n := maxi(1, int(a.distance_to(b) / pas))
		var prev := Vector3.ZERO
		for i in n + 1:
			var t := float(i) / n
			var q := a.lerp(b, t)
			var base := _sol(Vector3(q.x, 0, q.y))
			var top := base + Vector3(k.rng.randf_range(-0.06, 0.06), 1.25 + k.rng.randf_range(-0.08, 0.08), k.rng.randf_range(-0.06, 0.06))
			k.xf = Transform3D.IDENTITY
			k.beam(base - Vector3(0, 0.3, 0), top, 0.13, 0.13, FermeModeles.BOIS_GRIS)
			var gap := c == 2 and q.x > porte.x and q.x < porte.y
			if i > 0 and not gap:
				for hy in [0.5, 1.0]:
					var sag := k.rng.randf_range(0.0, 0.06)
					var pa := prev + Vector3(0, hy - 1.25, 0)
					var pb := top + Vector3(0, hy - 1.25, 0)
					var mid := (pa + pb) * 0.5 - Vector3(0, sag, 0)
					k.tube(pa, mid, 0.05, 0.05, 5, FermeModeles.BOIS_GRIS, false)
					k.tube(mid, pb, 0.05, 0.05, 5, FermeModeles.BOIS_GRIS, false)
			prev = top


func _cloture_basse(k: LpKit, r: Rect2) -> void:
	k.xf = Transform3D.IDENTITY
	var coins := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for c in 4:
		var a: Vector2 = coins[c]
		var b: Vector2 = coins[(c + 1) % 4]
		var n := int(a.distance_to(b) / 0.16)
		for i in n:
			var q := a.lerp(b, (i + 0.5) / n)
			if c == 3 and absf(q.y - r.get_center().y) < 0.6:
				continue
			var base := _sol(Vector3(q.x, 0, q.y))
			k.box(base + Vector3(0, 0.38, 0), Vector3(0.07, 0.8 + k.rng.randf_range(-0.08, 0.08), 0.05), FermeModeles.BOIS_GRIS.lerp(FermeModeles.BOIS, k.rng.randf()), 0.2)
		for hy in [0.25, 0.6]:
			var pa := _sol(Vector3(a.x, 0, a.y)) + Vector3(0, hy, 0)
			var pb := _sol(Vector3(b.x, 0, b.y)) + Vector3(0, hy, 0)
			k.tube(pa, pb, 0.025, 0.025, 4, FermeModeles.BOIS, false)


# --- Végétation ---------------------------------------------------------------------

func _vegetation() -> void:
	# Arbres proches : chênes, verger, haie.
	var k := LpKit.new(41)
	var chenes := [Vector3(-9, 0, -11), Vector3(27, 0, 13), Vector3(-44, 0, -4), Vector3(-29, 0, 15), Vector3(48, 0, 4), Vector3(-58, 0, 30)]
	for p in chenes:
		_pose(k, p, k.rng.randf() * 360.0, k.rng.randf_range(0.9, 1.3))
		FermeModeles.chene(k, 1.0)
	for i in 4:
		for j in 3:
			var p := Vector3(-28 + i * 6.0 + (j % 2) * 3.0, 0, -22 - j * 6.0)
			_pose(k, p, k.rng.randf() * 360.0, k.rng.randf_range(0.85, 1.1))
			FermeModeles.fruitier(k, 1.0)
	# Haie le long du chemin.
	k.xf = Transform3D.IDENTITY
	var x := -60.0
	while x < 36.0:
		if absf(x - 1.0) > 3.0:
			var p := _sol(Vector3(x, 0, route_z(x) + 3.2))
			var hs := k.rng.randf_range(0.8, 1.5)
			k.blob(p + Vector3(0, 0.5 * hs, k.rng.randf_range(-0.3, 0.3)), Vector3(1.5, 1.1 * hs, 1.1) * k.rng.randf_range(0.85, 1.15), Color("2f4f22"), Color("789c40").lerp(Color("a0a848"), k.rng.randf() * 0.4), 0.28, 1)
		x += k.rng.randf_range(1.3, 2.2)
	# Buissons près des murs.
	for p in [Vector3(-7.9, 0, 4.4), Vector3(8.4, 0, 3.9), Vector3(-6.0, 0, -4.4), Vector3(-12.5, 0, 9.8), Vector3(13, 0, 6)]:
		k.xf = Transform3D.IDENTITY
		k.blob(_sol(p) + Vector3(0, 0.5, 0), Vector3(1.0, 0.8, 0.9), Color("2f4f22"), Color("789c40"), 0.25, 1)
	_poser(k, "Arbres proches")

	# Forêt lointaine : feuillus et sapins, en un seul maillage.
	var f := LpKit.new(42)
	var placed := 0
	var tries := 0
	while placed < 320 and tries < 4000:
		tries += 1
		var a := f.rng.randf() * TAU
		var d := f.rng.randf_range(85.0, 300.0)
		var p := Vector3(cos(a) * d - 4.0, 0, sin(a) * d + 6.0)
		if zone(p.x, p.z) != Zone.HERBE or absf(p.x) > 318.0 or absf(p.z) > 318.0:
			continue
		# Bosquets : densité selon un bruit.
		if noise.get_noise_2d(p.x * 2.0 + 50.0, p.z * 2.0) < -0.05:
			continue
		_pose(f, p, f.rng.randf() * 360.0, f.rng.randf_range(0.9, 1.5))
		if f.rng.randf() < 0.35:
			FermeModeles.sapin(f, 1.4)
		else:
			f.tube(Vector3.ZERO, Vector3(0, 3.0, 0), 0.4, 0.25, 5, Color("4e3b2b"))
			f.blob(Vector3(0, 5.0, 0), Vector3(3.2, 2.8, 3.2), Color("2c4a1f"), Color("7f9f42"), 0.2, 1)
			f.blob(Vector3(1.2, 6.4, 0.4), Vector3(2.0, 1.7, 2.0), Color("3a5a24"), Color("8aa848"), 0.2, 0)
		placed += 1
	_poser(f, "Foret")

	_herbes()
	_ble()
	_fleurs_et_roseaux()


## Touffe d'herbe : quelques brins triangulaires, sombres au pied, clairs en pointe.
func _maillage_touffe(k: LpKit, brins: int, bas: Color, haut: Color, hauteur_brin: float, largeur: float) -> ArrayMesh:
	for i in brins:
		var a := TAU * i / brins + k.rng.randf() * 0.8
		var r := k.rng.randf_range(0.0, 0.12)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var lean := Vector3(cos(a), 0, sin(a)) * k.rng.randf_range(0.08, 0.25)
		var h := hauteur_brin * k.rng.randf_range(0.7, 1.15)
		var side := Vector3(-sin(a), 0, cos(a)) * largeur
		var mid := base + lean * 0.4 + Vector3(0, h * 0.5, 0)
		var tip := base + lean + Vector3(0, h, 0)
		var cm := bas.lerp(haut, 0.55)
		k.tri3(base - side, base + side, mid + side * 0.6, bas, bas, cm, lean)
		k.tri3(base - side, mid + side * 0.6, mid - side * 0.6, bas, cm, cm, lean)
		k.tri3(mid - side * 0.6, mid + side * 0.6, tip, cm, cm, haut, lean)
	k.layer = "base"
	return k.commit({"base": mats["vent"]})


func _multi(nom: String, mesh: Mesh, xfs: Array, mat: Material, ombre := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _herbes() -> void:
	var k := LpKit.new(51)
	var courte := _maillage_touffe(k, 6, Color("3c5a22"), Color("9cbf58"), 0.32, 0.035)
	var haute := _maillage_touffe(k, 9, Color("3a5420"), Color("c2c46a"), 0.75, 0.03)
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	var courtes: Array = []
	var hautes: Array = []
	# Par blocs de 16 m (pour que la caméra n'affiche que ce qu'elle voit).
	var blocs := {}
	for i in 60000:
		var x := rng.randf_range(-62.0, 62.0)
		var z := rng.randf_range(-46.0, 78.0)
		var zn := zone(x, z)
		var marge := zn == Zone.CHAMP and (x - CHAMP.position.x < 1.2 or CHAMP.end.x - x < 1.2 or z - CHAMP.position.y < 1.2)
		if zn != Zone.HERBE and zn != Zone.BERGE and not marge:
			continue
		var tall := noise.get_noise_2d(x * 4.0, z * 4.0) > 0.12 or marge or zn == Zone.BERGE
		# Herbe haute au pied des clôtures et des murs.
		if absf(x - ENCLOS.position.x) < 0.7 or absf(z - ENCLOS.end.y) < 0.7 or absf(z - (route_z(x) + 2.4)) < 1.0:
			tall = true
		if not tall and rng.randf() < 0.45:
			continue
		var s := rng.randf_range(0.8, 1.35) * (rng.randf_range(1.0, 1.6) if tall else 1.0)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, hauteur(x, z) - 0.02, z))
		var key := "%s_%d_%d" % ["h" if tall else "c", int(floor(x / 16.0)), int(floor(z / 16.0))]
		if not blocs.has(key):
			blocs[key] = []
		blocs[key].append(t)
		stats.herbes += 1
	for key in blocs:
		_multi("Herbe_" + key, haute if key.begins_with("h") else courte, blocs[key], mats["vent"])


func _ble() -> void:
	var k := LpKit.new(61)
	# Une « gerbe » : 3 tiges, chacune avec un épi en fuseau et une feuille.
	for i in 3:
		var a := TAU * i / 3.0 + k.rng.randf() * 0.5
		var base := Vector3(cos(a), 0, sin(a)) * 0.07
		var h := k.rng.randf_range(0.85, 1.05)
		var top := base + Vector3(cos(a) * 0.04, h, sin(a) * 0.04)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.012
		var c0 := Color("8a7a3c")
		var c1 := Color("d6bb68")
		k.tri3(base - side, base + side, top, c0, c0, c1, Vector3(cos(a), 0, sin(a)))
		# Épi : deux pyramides à 4 faces.
		var e0 := top
		var e1 := top + Vector3(cos(a) * 0.02, 0.14, sin(a) * 0.02)
		var em := (e0 + e1) * 0.5
		var r := 0.028
		var ring: Array[Vector3] = []
		for j in 4:
			var b := TAU * j / 4.0 + a
			ring.append(em + Vector3(cos(b) * r, 0, sin(b) * r))
		var ce := Color("e6c770")
		var cd := Color("b8953e")
		for j in 4:
			var o := (ring[j] + ring[(j + 1) % 4]) * 0.5 - em
			k.tri3(e0, ring[j], ring[(j + 1) % 4], cd, ce, ce, o)
			k.tri3(e1, ring[j], ring[(j + 1) % 4], ce.lightened(0.1), ce, ce, o)
		# Feuille.
		var fl := base + Vector3(0, h * 0.4, 0)
		var dirf := Vector3(cos(a + 1.2), 0, sin(a + 1.2))
		k.tri3(fl - side * 2.0, fl + side * 2.0, fl + dirf * 0.25 + Vector3(0, 0.12, 0), c0, c0, Color("b8a050"), Vector3.UP)
	var mesh := k.commit({"base": mats["ble"]})
	var rng := RandomNumberGenerator.new()
	rng.seed = 62
	var blocs := {}
	var step := 0.42
	var z := CHAMP.position.y + 1.2
	while z < CHAMP.end.y:
		var x := CHAMP.position.x + 1.2
		while x < CHAMP.end.x - 1.2:
			var px := x + rng.randf_range(-0.15, 0.15)
			var pz := z + rng.randf_range(-0.12, 0.12)
			if Vector2(px + 30.0, pz - 46.0).length() > 1.2:
				var s := rng.randf_range(0.9, 1.15)
				var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.1), s)), Vector3(px, hauteur(px, pz) - 0.03, pz))
				var key := "%d_%d" % [int(floor(px / 12.0)), int(floor(pz / 12.0))]
				if not blocs.has(key):
					blocs[key] = []
				blocs[key].append(t)
				stats.epis += 1
			x += step
		z += step * 0.8
	for key in blocs:
		_multi("Ble_" + key, mesh, blocs[key], mats["ble"])


func _fleurs_et_roseaux() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	# Coquelicots, bleuets, marguerites : une petite coupe au bout d'une tige.
	var couleurs := [Color("d8302c"), Color("4a6ad8"), Color("f4f0e6"), Color("f2c53d")]
	for ci in couleurs.size():
		var k := LpKit.new(72 + ci)
		var c: Color = couleurs[ci]
		k.tri3(Vector3(-0.008, 0, 0), Vector3(0.008, 0, 0), Vector3(0, 0.45, 0), Color("3c5a22"), Color("3c5a22"), Color("6f8f3a"), Vector3.BACK)
		k.tri3(Vector3(0, 0, -0.008), Vector3(0, 0, 0.008), Vector3(0, 0.45, 0), Color("3c5a22"), Color("3c5a22"), Color("6f8f3a"), Vector3.RIGHT)
		var top := Vector3(0, 0.45, 0)
		for j in 5:
			var a0 := TAU * j / 5.0
			var a1 := TAU * (j + 1) / 5.0
			k.tri3(top, top + Vector3(cos(a0) * 0.06, 0.03, sin(a0) * 0.06), top + Vector3(cos(a1) * 0.06, 0.03, sin(a1) * 0.06), c.darkened(0.4), c, c, Vector3.UP)
		var mesh := k.commit({"base": mats["vent"]})
		var xfs: Array = []
		for i in 2500:
			var x := rng.randf_range(-60.0, 60.0)
			var z := rng.randf_range(-44.0, 76.0)
			var zn := zone(x, z)
			var ok := zn == Zone.HERBE and noise.get_noise_2d(x * 3.0 + ci * 40.0, z * 3.0) > 0.2
			if ci == 0 and zn == Zone.CHAMP and rng.randf() < 0.35:
				ok = true
			if not ok:
				continue
			var s := rng.randf_range(0.8, 1.3) * (2.2 if zn == Zone.CHAMP else 1.0)
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, hauteur(x, z), z)))
		_multi("Fleurs_%d" % ci, mesh, xfs, mats["vent"])
	# Roseaux et massettes autour de la mare.
	var r := LpKit.new(80)
	for i in 7:
		var a := TAU * i / 7.0
		var b := Vector3(cos(a) * 0.08, 0, sin(a) * 0.08)
		var h := r.rng.randf_range(1.2, 1.9)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.02
		r.tri3(b - side, b + side, b + Vector3(cos(a) * 0.2, h, sin(a) * 0.2), Color("33502a"), Color("33502a"), Color("8aa04a"), Vector3(cos(a), 0, sin(a)))
		if i % 3 == 0:
			var top := b + Vector3(cos(a) * 0.12, h * 0.8, sin(a) * 0.12)
			r.tube(top, top + Vector3(0, 0.22, 0), 0.035, 0.035, 5, Color("5a3a22"))
	var rm := r.commit({"base": mats["vent"]})
	var xfs2: Array = []
	for i in 260:
		var a := rng.randf() * TAU
		var d := MARE_R + rng.randf_range(-1.6, 0.6)
		if sin(a) > 0.6:
			continue
		var x := MARE.x + cos(a) * d
		var z := MARE.y + sin(a) * d
		var s := rng.randf_range(0.8, 1.2)
		xfs2.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, maxf(hauteur(x, z), -0.3), z)))
	_multi("Roseaux", rm, xfs2, mats["vent"], true)


# --- Lumière, ciel, brume --------------------------------------------------------------

func _ciel_et_lumiere() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = false
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.25
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_anisotropy = 0.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Soleil"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.light_angular_distance = 0.8
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)


func _soleil(elevation: float, azimut: float, couleur: Color, energie: float) -> void:
	var el := deg_to_rad(elevation)
	var az := deg_to_rad(azimut)
	var d := Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
	sun.transform = Transform3D(Basis.looking_at(-d, Vector3.UP), Vector3.ZERO)
	sun.light_color = couleur
	sun.light_energy = energie


## 0 fin d'après-midi · 1 matin brumeux · 2 plein midi · 3 soir aux lanternes.
func appliquer_lumiere(i: int) -> void:
	lumiere = clampi(i, 0, LUMIERES.size() - 1)
	var fenetres := 0.0
	var lanternes := 0.0
	match lumiere:
		0:
			_soleil(21.0, -62.0, Color("ffd2a0"), 1.9)
			sky_mat.sky_top_color = Color("5a8fd2")
			sky_mat.sky_horizon_color = Color("f0c99a")
			sky_mat.ground_horizon_color = Color("c9a780")
			sky_mat.ground_bottom_color = Color("3d3a30")
			sky_mat.sky_energy_multiplier = 1.0
			env.ambient_light_energy = 0.6
			env.fog_light_color = Color("e8c9a0")
			env.fog_density = 0.0016
			env.fog_sun_scatter = 0.3
			env.fog_height = -20.0
			env.fog_height_density = 0.0
			env.volumetric_fog_density = 0.0025
			env.volumetric_fog_albedo = Color("ffe6c8")
			env.tonemap_exposure = 1.0
		1:
			# Brume au ras du sol (brouillard en hauteur) et rayons de soleil rasants.
			_soleil(11.0, 70.0, Color("ffe0b0"), 1.6)
			sky_mat.sky_top_color = Color("7d9cc8")
			sky_mat.sky_horizon_color = Color("efe2d0")
			sky_mat.ground_horizon_color = Color("d8d0c4")
			sky_mat.ground_bottom_color = Color("5a5850")
			sky_mat.sky_energy_multiplier = 1.0
			env.ambient_light_energy = 0.75
			env.fog_light_color = Color("e4e2dc")
			env.fog_density = 0.002
			env.fog_sun_scatter = 0.45
			env.fog_height = 3.5
			env.fog_height_density = 0.2
			env.volumetric_fog_density = 0.012
			env.volumetric_fog_albedo = Color("f6f2ea")
			env.tonemap_exposure = 1.05
		2:
			_soleil(62.0, -20.0, Color("fff6ea"), 1.6)
			sky_mat.sky_top_color = Color("3a6fc0")
			sky_mat.sky_horizon_color = Color("b9d2ea")
			sky_mat.ground_horizon_color = Color("a8b8a0")
			sky_mat.ground_bottom_color = Color("3d3a30")
			sky_mat.sky_energy_multiplier = 1.0
			env.ambient_light_energy = 0.55
			env.fog_light_color = Color("c6d6e6")
			env.fog_density = 0.0018
			env.fog_sun_scatter = 0.1
			env.fog_height = -20.0
			env.fog_height_density = 0.0
			env.volumetric_fog_density = 0.002
			env.volumetric_fog_albedo = Color("ffffff")
			env.tonemap_exposure = 0.85
		3:
			# Heure bleue : ciel encore clair, fenêtres et lanternes allumées.
			# La « lune » : une lumière froide et faible qui garde les volumes lisibles.
			_soleil(38.0, 150.0, Color("8fa2ff"), 0.22)
			sky_mat.sky_top_color = Color("23345e")
			sky_mat.sky_horizon_color = Color("c98a78")
			sky_mat.ground_horizon_color = Color("4a4058")
			sky_mat.ground_bottom_color = Color("15151c")
			sky_mat.sky_energy_multiplier = 0.9
			env.ambient_light_energy = 1.3
			env.fog_light_color = Color("5a6488")
			env.fog_density = 0.002
			env.fog_sun_scatter = 0.0
			env.fog_height = 1.0
			env.fog_height_density = 0.05
			env.volumetric_fog_density = 0.006
			env.volumetric_fog_albedo = Color("d0d8ff")
			env.tonemap_exposure = 1.6
			fenetres = 3.0
			lanternes = 1.0
	sun.visible = sun.light_energy > 0.0
	(mats["verre"] as StandardMaterial3D).emission_energy_multiplier = fenetres
	(mats["flamme"] as StandardMaterial3D).emission_energy_multiplier = 6.0 * lanternes
	for l in lampes:
		l.light_energy = 2.2 * lanternes
		l.light_volumetric_fog_energy = 2.0 * lanternes
	_maj_aide()


# --- Caméra et aide ---------------------------------------------------------------------

func _camera_et_aide() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.1
	camera.far = 900.0
	cam_attr = CameraAttributesPractical.new()
	camera.attributes = cam_attr
	add_child(camera)
	camera.current = true
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 17)
	hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	hud.add_theme_constant_override("outline_size", 5)
	cl.add_child(hud)


func appliquer_vue(i: int) -> void:
	vue = posmod(i, VUES.size())
	var v: Array = VUES[vue]
	_target = v[0]
	_yaw = v[1]
	_pitch = v[2]
	_dist = v[3]
	# Flou de profondeur discret pour les vues rapprochées (effet maquette).
	cam_attr.dof_blur_far_enabled = vue != 0
	cam_attr.dof_blur_far_distance = 70.0 if vue != 3 else 25.0
	cam_attr.dof_blur_far_transition = 60.0
	cam_attr.dof_blur_amount = 0.05
	_maj_camera()
	_maj_aide()


func _maj_camera() -> void:
	_pitch = clampf(_pitch, 2.0, 85.0)
	_dist = clampf(_dist, 4.0, 260.0)
	var b := Basis(Vector3.UP, deg_to_rad(_yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-_pitch))
	var pos := _target + b * Vector3(0, 0, _dist)
	pos.y = maxf(pos.y, hauteur(pos.x, pos.z) + 1.2)
	camera.transform = Transform3D(Basis.looking_at(_target - pos, Vector3.UP), pos)


func _maj_aide() -> void:
	if hud == null:
		return
	hud.text = "Démo ferme low-poly · tout est généré en code\nLumière (1-4) : %s · Vue (C) : %s\nClic droit glissé : tourner · molette : zoom · ZQSD : déplacer · H : masquer" % [LUMIERES[lumiere], NOMS_VUES[vue]]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				appliquer_lumiere(0)
			KEY_2, KEY_KP_2:
				appliquer_lumiere(1)
			KEY_3, KEY_KP_3:
				appliquer_lumiere(2)
			KEY_4, KEY_KP_4:
				appliquer_lumiere(3)
			KEY_C:
				appliquer_vue(vue + 1)
			KEY_H:
				hud.visible = not hud.visible
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_drag = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_dist *= 0.9
			_maj_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_dist *= 1.1
			_maj_camera()
	elif event is InputEventMouseMotion and _drag:
		_yaw -= event.relative.x * 0.3
		_pitch += event.relative.y * 0.2
		_maj_camera()


func _process(delta: float) -> void:
	var mv := Vector2.ZERO
	# Touches physiques : ZQSD en AZERTY = WASD en QWERTY.
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv.x += 1
	if mv != Vector2.ZERO:
		var b := Basis(Vector3.UP, deg_to_rad(_yaw))
		_target += b * Vector3(mv.x, 0, mv.y) * delta * maxf(_dist * 0.6, 6.0)
		_target.y = hauteur(_target.x, _target.z) + 1.5
		_maj_camera()
