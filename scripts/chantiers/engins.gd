class_name EnginsChantier
extends RefCounted
## Engins de chantier low-poly faits en code : pelleteuse, camion-toupie,
## camionnette d'artisan, finisseur et rouleau compacteur, plus les petits
## accessoires (piquets, tas de terre, palettes).
##
## Chaque engin regarde vers +Z et repose sur y = 0. Les parties qui bougent
## (bras de la pelleteuse, toupie) sont des nœuds nommés « Bras » et
## « Toupie » : animer() les fait travailler.

const JAUNE := Color("e8b923")
const GRIS := Color("8a8f96")
const NOIR := Color("2b2b2b")
const VITRE := Color("6d97b8")
const BLANC := Color("eceae4")
const ORANGE := Color("f77f00")

static var _cache := {}


static func _mi(k: BlocMesh, nom: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = k.to_mesh(NightWindows.chantier_material())
	return mi


## On peut monter à bord en vue au sol (voir ABord) ; l'avant regarde vers +Z.
static func _montable(root: Node3D, nom: String, siege: Vector3) -> void:
	root.add_to_group(ABord.GROUPE)
	root.set_meta("nom_bord", nom)
	root.set_meta("infos_bord", "Sur un chantier")
	root.set_meta("avant_plus_z", true)
	root.set_meta("siege_bord", siege)


static func _roues(k: BlocMesh, long: float, large: float, r: float, n := 2) -> void:
	for i in n:
		var z := lerpf(-long / 2.0, long / 2.0, float(i) / maxf(n - 1, 1))
		for s in [-1.0, 1.0]:
			k.box(s * large / 2.0, 0.0, z, 0.35, r * 2.0, r * 2.0, NOIR)


## Pelleteuse sur chenilles : châssis, tourelle, cabine ; le bras est un nœud à part.
static func pelleteuse() -> Node3D:
	var root := Node3D.new()
	root.name = "Pelleteuse"
	_montable(root, "Pelleteuse", Vector3(-0.6, 2.75, 0.4))
	var k := BlocMesh.new()
	for s in [-1.0, 1.0]:
		k.box(s * 1.05, 0.0, 0, 0.6, 0.8, 3.6, NOIR)
	k.box(0, 0.8, 0, 1.6, 0.3, 2.0, GRIS)
	k.box(0, 1.1, -0.3, 2.4, 0.9, 2.6, JAUNE)
	k.box(-0.6, 2.0, 0.4, 0.9, 1.1, 1.0, JAUNE)
	k.box(-0.6, 2.2, 0.92, 0.75, 0.75, 0.05, VITRE)
	k.box(0, 1.2, -1.75, 2.2, 0.8, 0.3, GRIS.darkened(0.2))
	root.add_child(_mi(k, "Corps"))
	var bras := Node3D.new()
	bras.name = "Bras"
	bras.position = Vector3(0.45, 1.6, 0.9)
	var kb := BlocMesh.new()
	kb.box(0, -0.25, 1.4, 0.35, 0.45, 2.8, JAUNE)
	kb.box(0, -1.6, 2.75, 0.3, 1.6, 0.3, JAUNE)
	kb.box(0, -2.1, 3.05, 0.8, 0.55, 0.6, GRIS.darkened(0.3))
	bras.add_child(_mi(kb, "Godet"))
	root.add_child(bras)
	return root


## Camion-toupie (bétonnière) : la toupie tourne.
static func toupie() -> Node3D:
	var root := Node3D.new()
	root.name = "Toupie"
	_montable(root, "Camion-toupie", Vector3(-0.45, 2.3, 2.6))
	var k := BlocMesh.new()
	k.box(0, 0.5, 0, 2.3, 0.4, 7.0, GRIS.darkened(0.2))
	k.box(0, 0.9, 2.6, 2.4, 1.9, 1.8, BLANC)
	k.box(0, 1.9, 3.52, 2.1, 0.75, 0.05, VITRE)
	k.box(0, 0.9, -2.9, 1.2, 1.0, 0.6, GRIS)
	_roues(k, 5.4, 2.4, 0.5, 3)
	root.add_child(_mi(k, "Corps"))
	var t := Node3D.new()
	t.name = "Tambour"
	t.position = Vector3(0, 2.4, -0.6)
	t.rotation.x = -0.25
	var kt := BlocMesh.new()
	kt.box(0, -1.0, 0, 2.0, 2.0, 3.6, ORANGE)
	kt.box(0, -0.7, 0, 2.2, 1.4, 3.0, ORANGE.darkened(0.15))
	kt.box(0, -0.3, 1.9, 0.9, 0.6, 0.4, GRIS)
	t.add_child(_mi(kt, "Cuve"))
	root.add_child(t)
	return root


## Camionnette d'artisan (finitions).
static func camionnette() -> Node3D:
	var k := BlocMesh.new()
	k.box(0, 0.35, 0, 2.0, 2.0, 4.8, BLANC)
	k.box(0, 1.4, 2.42, 1.8, 0.7, 0.05, VITRE)
	k.box(0, 1.0, -0.5, 2.02, 0.35, 2.6, ORANGE)
	_roues(k, 3.2, 2.0, 0.35, 2)
	var root := Node3D.new()
	root.name = "Camionnette"
	_montable(root, "Camionnette d'artisan", Vector3(-0.45, 1.6, 1.4))
	root.add_child(_mi(k, "Corps"))
	return root


## Finisseur : pose l'enrobé chaud (trémie à l'avant, table derrière).
static func finisseur(largeur := 3.0) -> Node3D:
	var k := BlocMesh.new()
	k.box(0, 0.0, 0, 2.6, 0.8, 4.0, NOIR)
	k.box(0, 0.8, 0.3, 2.8, 1.0, 3.0, JAUNE)
	k.box(0, 1.8, -0.6, 1.4, 1.3, 1.2, JAUNE)
	k.box(0, 3.1, -0.6, 2.2, 0.08, 1.8, GRIS)
	k.box(0, 0.4, 2.3, 3.0, 0.9, 1.0, GRIS.darkened(0.3))
	k.box(0, 0.05, -2.3, maxf(largeur, 2.6), 0.35, 0.6, JAUNE.darkened(0.2))
	var root := Node3D.new()
	root.name = "Finisseur"
	_montable(root, "Finisseur", Vector3(0.0, 2.7, -0.6))
	root.add_child(_mi(k, "Corps"))
	return root


## Rouleau compacteur.
static func rouleau() -> Node3D:
	var k := BlocMesh.new()
	k.box(0, 0.0, 1.4, 1.9, 1.3, 1.3, GRIS)
	k.box(0, 0.0, -1.4, 1.9, 1.3, 1.3, GRIS)
	k.box(0, 0.9, 0, 1.6, 0.9, 2.2, JAUNE)
	k.box(0, 1.8, -0.2, 1.3, 1.1, 1.2, JAUNE)
	k.box(0, 2.9, -0.2, 1.6, 0.08, 1.5, GRIS)
	var root := Node3D.new()
	root.name = "Rouleau"
	_montable(root, "Rouleau compacteur", Vector3(0.0, 2.6, -0.2))
	root.add_child(_mi(k, "Corps"))
	return root


## Camion-benne (terre, grave).
static func benne() -> Node3D:
	var k := BlocMesh.new()
	k.box(0, 0.5, 0, 2.3, 0.4, 6.6, GRIS.darkened(0.2))
	k.box(0, 0.9, 2.4, 2.4, 1.9, 1.7, ORANGE)
	k.box(0, 1.9, 3.27, 2.1, 0.75, 0.05, VITRE)
	k.box(0, 0.9, -1.0, 2.4, 1.4, 4.2, GRIS)
	k.box(0, 2.25, -1.0, 2.0, 0.35, 3.8, Color("7a5a3a"))
	_roues(k, 5.0, 2.4, 0.5, 3)
	var root := Node3D.new()
	root.name = "Benne"
	_montable(root, "Camion-benne", Vector3(-0.45, 2.3, 2.4))
	root.add_child(_mi(k, "Corps"))
	return root


## Fait bouger les parties mobiles d'un engin (t en secondes réelles).
static func animer(engin: Node3D, t: float, actif: bool) -> void:
	if engin == null or not actif:
		return
	var bras := engin.get_node_or_null("Bras") as Node3D
	if bras != null:
		bras.rotation.x = sin(t * 0.9) * 0.35 - 0.1
	var tam := engin.get_node_or_null("Tambour") as Node3D
	if tam != null:
		tam.rotation.z += 0.05


## Tas de terre (terrassement) : quelques blocs en pyramide.
static func tas(k: BlocMesh, x: float, z: float, r: float, col := Color("7a5a3a")) -> void:
	var y := 0.0
	var s := r
	while s > 0.4:
		k.box(x, y, z, s * 2.0, 0.45, s * 1.7, col)
		y += 0.45
		s *= 0.68
		col = col.lightened(0.04)


## Palette de parpaings ou de tuiles.
static func palette(k: BlocMesh, x: float, z: float, col := Color("b9b4aa")) -> void:
	k.box(x, 0.0, z, 1.2, 0.15, 1.0, Color("a07a4a"))
	k.box(x, 0.15, z, 1.1, 0.8, 0.9, col)
