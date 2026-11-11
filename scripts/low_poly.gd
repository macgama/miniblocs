class_name LowPoly
extends RefCounted
## Fabrique de modèles low-poly générés en code (aucun asset externe requis).
## Chaque fonction reçoit un générateur aléatoire et une fonction `mat(color)`
## qui renvoie un matériau partagé, pour garder peu de matériaux différents.

const HOUSE_WALLS: Array[Color] = [Color("f4e9d8"), Color("f2d0a9"), Color("e8e3f0"), Color("fbe7a1"), Color("d9ecf2")]
const HOUSE_ROOFS: Array[Color] = [Color("c8553d"), Color("8c4a3a"), Color("5b6c8f"), Color("6e8b3d")]
const SHOP_WALLS: Array[Color] = [Color("8ec5e6"), Color("b5d3e7"), Color("a0b8d8"), Color("d6e4f0")]
const FACTORY_WALLS: Array[Color] = [Color("c9b38a"), Color("b8a27a"), Color("a8a8a0")]


static func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = material
	return mi


static func make_house(rng: RandomNumberGenerator, mat: Callable) -> Node3D:
	var root := Node3D.new()
	var w := rng.randf_range(0.55, 0.72)
	var d := rng.randf_range(0.5, 0.65)
	var h := rng.randf_range(0.35, 0.5) * (2.0 if rng.randf() < 0.2 else 1.0)
	var wall: Color = HOUSE_WALLS[rng.randi() % HOUSE_WALLS.size()]
	var roof_col: Color = HOUSE_ROOFS[rng.randi() % HOUSE_ROOFS.size()]
	root.add_child(_box(Vector3(w, h, d), Vector3(0, h / 2.0, 0), mat.call(wall)))

	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(w + 0.08, 0.28, d + 0.08)
	roof.mesh = prism
	roof.position.y = h + 0.14
	roof.material_override = mat.call(roof_col)
	root.add_child(roof)

	# Porte sur la façade (côté -Z, tourné vers la route).
	root.add_child(_box(Vector3(0.12, 0.2, 0.02), Vector3(0, 0.1, -d / 2.0 - 0.01), mat.call(Color("6b4a33"))))
	return root


static func make_shop(rng: RandomNumberGenerator, mat: Callable) -> Node3D:
	var root := Node3D.new()
	var floors := rng.randi_range(1, 4)
	var w := rng.randf_range(0.7, 0.85)
	var d := rng.randf_range(0.65, 0.8)
	var h := 0.35 * floors + 0.15
	var wall: Color = SHOP_WALLS[rng.randi() % SHOP_WALLS.size()]
	root.add_child(_box(Vector3(w, h, d), Vector3(0, h / 2.0, 0), mat.call(wall)))
	# Vitrine sombre au rez-de-chaussée + auvent coloré.
	root.add_child(_box(Vector3(w * 0.8, 0.18, 0.02), Vector3(0, 0.14, -d / 2.0 - 0.01), mat.call(Color("2f3e4f"))))
	var awnings: Array[Color] = [Color("e4572e"), Color("f2c14e"), Color("76b041"), Color("ffffff")]
	root.add_child(_box(Vector3(w * 0.9, 0.04, 0.14), Vector3(0, 0.27, -d / 2.0 - 0.06), mat.call(awnings[rng.randi() % awnings.size()])))
	# Bandeaux de fenêtres aux étages.
	for i in range(1, floors):
		root.add_child(_box(Vector3(w + 0.01, 0.1, d + 0.01), Vector3(0, 0.15 + 0.35 * i + 0.12, 0), mat.call(Color("3c5a78"))))
	# Toit plat avec une petite installation technique.
	root.add_child(_box(Vector3(0.18, 0.1, 0.18), Vector3(rng.randf_range(-0.2, 0.2), h + 0.05, rng.randf_range(-0.15, 0.15)), mat.call(Color("9aa0a6"))))
	return root


static func make_factory(rng: RandomNumberGenerator, mat: Callable) -> Node3D:
	var root := Node3D.new()
	var w := rng.randf_range(0.8, 0.92)
	var d := rng.randf_range(0.7, 0.88)
	var h := rng.randf_range(0.35, 0.5)
	var wall: Color = FACTORY_WALLS[rng.randi() % FACTORY_WALLS.size()]
	root.add_child(_box(Vector3(w, h, d), Vector3(0, h / 2.0, 0), mat.call(wall)))
	# Toit en dents de scie.
	for i in 3:
		var tooth := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.left_to_right = 0.0
		prism.size = Vector3(w / 3.0, 0.14, d)
		tooth.mesh = prism
		tooth.position = Vector3(-w / 3.0 + i * w / 3.0, h + 0.07, 0)
		tooth.material_override = mat.call(Color("7d7f85"))
		root.add_child(tooth)
	# Cheminée.
	var chimney := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.08
	cyl.height = 0.6
	cyl.radial_segments = 6
	chimney.mesh = cyl
	chimney.position = Vector3(w / 2.0 - 0.12, h + 0.3, d / 2.0 - 0.12)
	chimney.material_override = mat.call(Color("b0413e"))
	root.add_child(chimney)
	# Porte de quai.
	root.add_child(_box(Vector3(0.3, 0.25, 0.02), Vector3(0, 0.125, -d / 2.0 - 0.01), mat.call(Color("55585e"))))
	return root


static func make_tree(rng: RandomNumberGenerator, mat: Callable) -> Node3D:
	var root := Node3D.new()
	var s := rng.randf_range(0.7, 1.15)
	var trunk := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.04
	tcyl.bottom_radius = 0.05
	tcyl.height = 0.25
	tcyl.radial_segments = 5
	trunk.mesh = tcyl
	trunk.position.y = 0.125
	trunk.material_override = mat.call(Color("7a5230"))
	root.add_child(trunk)

	var leaves: Array[Color] = [Color("3f7d3a"), Color("4c8c3f"), Color("5a9a48")]
	var cone := MeshInstance3D.new()
	var ccyl := CylinderMesh.new()
	ccyl.top_radius = 0.0
	ccyl.bottom_radius = 0.24
	ccyl.height = 0.6
	ccyl.radial_segments = 6
	ccyl.rings = 1
	cone.mesh = ccyl
	cone.position.y = 0.5
	cone.material_override = mat.call(leaves[rng.randi() % leaves.size()])
	root.add_child(cone)
	root.scale = Vector3.ONE * s
	root.rotation.y = rng.randf() * TAU
	return root
