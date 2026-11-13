class_name EnginsCarriere
extends RefCounted
## Engins des carrières et des mines, en low-poly : pelle hydraulique (sa
## tourelle tourne, son bras monte et descend), tombereau (sa benne bascule),
## foreuse de sondage et nuage de poussière des tirs de mine.
## Repère : l'engin regarde vers −Z, ses chenilles ou ses roues posées en y = 0.

const JAUNE := Color("f2b632")
const JAUNE_FONCE := Color("c98f1a")
const NOIR := Color("2b2d33")
const ACIER := Color("6c757d")
const VITRE := Color("33495e")
const ROUGE := Color("c1121f")

static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.85
	return _mat


static func _kit() -> BlocMesh:
	var k := BlocMesh.new()
	k.details = false
	return k


static func _mi(k: BlocMesh, nom: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = k.to_mesh(material())
	mi.visibility_range_end = 2500.0
	return mi


## Pelle hydraulique sur chenilles. taille 1 : pelle de carrière (≈ 45 t),
## 2 : pelle de mine (≈ 250 t). Nœuds : « Tourelle » (tourne sur y) et
## « Tourelle/Bras » (pivote sur x).
static func pelle(taille := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Pelle"
	var s := taille
	var k := _kit()
	for sx in [-1.0, 1.0]:
		k.box(sx * 1.35 * s, 0.0, 0.0, 0.8 * s, 1.0 * s, 4.6 * s, NOIR)
	k.box(0, 0.6 * s, 0, 1.9 * s, 0.5 * s, 2.0 * s, ACIER)
	root.add_child(_mi(k, "Chenilles"))
	var tour := Node3D.new()
	tour.name = "Tourelle"
	tour.position.y = 1.1 * s
	root.add_child(tour)
	k = _kit()
	k.box(0.2 * s, 0, 0.6 * s, 2.8 * s, 1.3 * s, 3.4 * s, JAUNE)
	k.box(0.2 * s, 0, 2.1 * s, 2.8 * s, 1.5 * s, 0.9 * s, JAUNE_FONCE)
	k.box(-0.8 * s, 1.3 * s, -0.6 * s, 1.1 * s, 1.3 * s, 1.3 * s, JAUNE)
	k.box(-0.8 * s, 1.55 * s, -1.27 * s, 0.95 * s, 0.8 * s, 0.05 * s, VITRE)
	tour.add_child(_mi(k, "Caisse"))
	var bras := Node3D.new()
	bras.name = "Bras"
	bras.position = Vector3(0.5 * s, 1.0 * s, -0.9 * s)
	tour.add_child(bras)
	k = _kit()
	# Flèche, balancier et godet, vers l'avant (−Z).
	k.box(0, 0, -2.4 * s, 0.6 * s, 0.7 * s, 4.8 * s, JAUNE)
	k.box(0, -2.0 * s, -4.9 * s, 0.5 * s, 3.0 * s, 0.5 * s, JAUNE_FONCE)
	k.box(0, -3.3 * s, -5.4 * s, 1.3 * s, 1.0 * s, 1.1 * s, ACIER)
	bras.add_child(_mi(k, "Fleche"))
	return root


## Tombereau (dumper). taille 1 : tombereau articulé de carrière (≈ 40 t),
## 2 : tombereau rigide de mine (≈ 220 t). Nœud « Benne » (bascule sur x).
static func tombereau(taille := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Tombereau"
	var s := taille
	var k := _kit()
	for sx in [-1.0, 1.0]:
		for z in [-1.6, 1.4]:
			k.box(sx * 1.25 * s, 0, z * s, 0.6 * s, 1.4 * s, 1.4 * s, NOIR)
	k.box(0, 0.7 * s, 0, 1.9 * s, 0.6 * s, 4.6 * s, JAUNE_FONCE)
	k.box(0, 1.3 * s, -1.9 * s, 2.0 * s, 1.1 * s, 1.0 * s, JAUNE)
	k.box(-0.5 * s, 2.4 * s, -1.9 * s, 0.9 * s, 0.9 * s, 0.9 * s, JAUNE)
	k.box(-0.5 * s, 2.55 * s, -2.36 * s, 0.75 * s, 0.6 * s, 0.05 * s, VITRE)
	root.add_child(_mi(k, "Chassis"))
	var benne := Node3D.new()
	benne.name = "Benne"
	benne.position = Vector3(0, 1.4 * s, 2.3 * s)
	root.add_child(benne)
	k = _kit()
	k.box(0, 0, -1.7 * s, 2.5 * s, 0.25 * s, 3.4 * s, JAUNE)
	for sx in [-1.0, 1.0]:
		k.box(sx * 1.2 * s, 0.25 * s, -1.7 * s, 0.12 * s, 1.1 * s, 3.4 * s, JAUNE)
	k.box(0, 0.25 * s, -3.35 * s, 2.5 * s, 1.5 * s, 0.12 * s, JAUNE)
	benne.add_child(_mi(k, "Caisse"))
	var charge := _kit()
	charge.pyramid(0, 0.3 * s, -1.7 * s, 2.2 * s, 3.0 * s, 0.9 * s, Color("a39e93"))
	var cm := _mi(charge, "Charge")
	benne.add_child(cm)
	return root


## Foreuse de sondage sur chenilles, mât levé.
static func foreuse() -> Node3D:
	var root := Node3D.new()
	root.name = "Foreuse"
	var k := _kit()
	for sx in [-1.0, 1.0]:
		k.box(sx * 0.9, 0, 0, 0.5, 0.7, 3.2, NOIR)
	k.box(0, 0.7, 0.4, 2.0, 1.0, 2.4, ROUGE)
	k.box(-0.5, 1.7, 1.0, 0.9, 1.0, 1.0, ROUGE)
	k.box(0, 0.7, -1.2, 0.35, 8.0, 0.35, ACIER)
	k.box(0, 8.7, -1.2, 0.6, 0.4, 0.6, ROUGE)
	k.box(1.6, 0, -0.5, 1.0, 0.8, 1.6, Color("adb5bd"))
	root.add_child(_mi(k, "Corps"))
	var tige := _kit()
	tige.cylinder(0, -0.3, 0, 0.08, 0.08, 3.0, 6, Color("495057"))
	var t := _mi(tige, "Tige")
	t.position = Vector3(0, 0.6, -1.2)
	root.add_child(t)
	return root


## Nuage de poussière d'un tir de mine (ou d'un convoyeur), qui monte puis retombe.
static func poussiere(rayon := 12.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Poussiere"
	p.amount = 90
	p.lifetime = 6.0
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = rayon * 0.4
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = rayon * 0.6
	p.initial_velocity_max = rayon * 1.4
	p.gravity = Vector3(0.4, -1.2, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.scale_amount_min = rayon * 0.25
	p.scale_amount_max = rayon * 0.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 1.3))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.8, 0.72, 0.85))
	grad.set_color(1, Color(0.8, 0.76, 0.7, 0.0))
	p.color_ramp = grad
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mesh.material = m
	p.mesh = mesh
	return p
