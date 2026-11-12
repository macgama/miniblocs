class_name Stades
extends RefCounted
## Les stades modélisés dans Blender (assets/modeles/batiments/stade_*.glb)
## entrent dans le catalogue (catégorie Sport), et les matchs s'y jouent.
##
## Chaque modèle est inspiré d'un stade réel (voir docs/modeles-blender.md),
## mais les clubs du jeu sont inventés (Matchs.club_de_ville).
## Repère du catalogue : origine au centre de l'emprise, façade vers −Z. Le
## modèle Blender a sa façade vers +Z : on le tourne d'un demi-tour et on le
## recentre ; le centre de la pelouse est gardé dans "pelouse".

const DOSSIER := "res://assets/modeles/batiments/"

## id -> [places, nom, inspiration, boîte du modèle (x, z, largeur, hauteur, profondeur),
##        demi-longueur et demi-largeur du bol, profondeur et hauteur des tribunes, couleurs des sièges]
const MODELES := {
	"stade_bale": [38512, "Grand stade à deux niveaux", "le Parc Saint-Jacques de Bâle",
		[-136.03, -86.03, 236.53, 60.0, 168.53], 59, 41, 40, 27, ["c8102e", "1d3c8f"]],
	"stade_berne": [31783, "Stade au toit solaire", "le Wankdorf de Berne",
		[-96.5, -124.03, 193.0, 30.0, 202.53], 59, 41, 36, 24, ["f2c200", "1b1b1b"]],
	"stade_geneve": [30084, "Stade à angles arrondis", "le stade de Genève à Lancy",
		[-93.5, -75.5, 187.0, 29.8, 151.0], 58, 40, 34, 24, ["7a1f2b", "8c8f94"]],
	"stade_letzigrund": [26104, "Stade avec piste d'athlétisme", "le Letzigrund de Zurich",
		[-115.0, -74.0, 230.0, 25.3, 148.0], 88, 47, 26, 13, ["7d1e1e", "26272b"]],
	"stade_saint_gall": [19568, "Stade fermé et centre commercial", "le Kybunpark de Saint-Gall",
		[-95.0, -80.0, 190.0, 30.8, 160.0], 58, 40, 30, 18, ["c8202f", "f2f2f2"]],
	"stade_lucerne": [17000, "Stade au pied des tours", "la Swissporarena de Lucerne",
		[-87.2, -69.2, 220.23, 88.0, 138.4], 58, 40, 28, 17, ["1f5fa8", "1f5fa8"]],
	"stade_sion": [14850, "Stade de montagne", "le stade de Tourbillon à Sion",
		[-73.1, -56.6, 146.2, 17.8, 119.2], 58, 40, 18, 11, ["e30613", "f2f2f2"]],
	"stade_tuiliere": [12544, "Stade à façade de verre", "le stade de la Tuilière à Lausanne",
		[-78.0, -59.5, 156.0, 20.0, 128.5], 58, 40, 22, 14, ["1d3c8f", "f2f2f2"]],
	"stade_thoune": [10398, "Stade et socle commercial", "la Stockhorn Arena de Thoune",
		[-80.0, -62.0, 160.0, 17.3, 199.5], 57, 39, 22, 12, ["c41e3a", "f2f2f2"]],
	"stade_lugano": [8793, "Stade compact", "l'AIL Arena de Lugano",
		[-78.0, -60.0, 156.0, 16.8, 120.0], 57, 39, 20, 11, ["1b1b1b", "f2f2f2"]],
	"stade_vaduz": [6441, "Petit stade à tribunes séparées", "le Rheinpark de Vaduz",
		[-68.1, -51.6, 136.2, 13.3, 107.2], 56, 38, 14, 9, ["d0021b", "1d3c8f"]],
}


## Types du catalogue (ajoutés par BuildingCatalog.all_types).
static func entries() -> Dictionary:
	var out := {}
	for id in MODELES:
		var m: Array = MODELES[id]
		var box: Array = m[3]
		var places := int(m[0])
		var cx := float(box[0]) + float(box[2]) * 0.5
		var cz := float(box[1]) + float(box[4]) * 0.5
		out[id] = {"name": "%s (%s places)" % [m[1], _milliers(places)], "cat": "sport",
			"w": ceili(float(box[2])) + 2, "d": ceili(float(box[4])) + 2, "access": BuildingCatalog.ROAD,
			"visiteurs": places, "emplois": maxi(20, places / 400), "cost": 40_000_000 + places * 2_500,
			"desc": "Stade de football de %s places, inspiré de %s." % [_milliers(places), m[2]],
			"glb": DOSSIER + id + ".glb", "stade": places, "region": "monde", "era": "contemporain", "style": "",
			# Après le demi-tour : centre de la pelouse dans le repère du bâtiment.
			"pelouse": Vector2(cx, cz), "bol": Vector2(float(m[4]), float(m[5])),
			"tribune": Vector2(float(m[6]), float(m[7])), "sieges": m[8], "haut": float(box[3])}
	return out


static func _milliers(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## Le type est-il un stade (modèle Blender ou terrain de foot) ?
static func est_stade(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	return t.has("stade") or type_id == "foot"


## Places d'un stade (terrain de foot : sa tribune).
static func places(type_id: String) -> int:
	var t := BuildingCatalog.get_type(type_id)
	return int(t.get("stade", 500 if type_id == "foot" else 0))


static var _meshes := {}


## Maillage du modèle Blender, recentré et tourné (façade vers −Z). Matériaux du .glb gardés.
static func build_mesh(t: Dictionary) -> ArrayMesh:
	var path := String(t.glb)
	if _meshes.has(path):
		return _meshes[path]
	var out := ArrayMesh.new()
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if scene == null:
		# Modèle absent (pas encore importé) : un bloc gris à la taille du stade.
		var k := BlocMesh.new()
		k.box(0, 0, 0, float(t.w) - 4.0, 12.0, float(t.d) - 4.0, Color("9aa0a6"))
		k.plate(0, 0, 105.0, 68.0, Color("4f9a3c"), 0.0, 0.1)
		out = k.to_mesh(NightWindows.building_material())
		_meshes[path] = out
		return out
	var root := scene.instantiate()
	var pel: Vector2 = t.pelouse
	# v' = R(v − c) avec R = demi-tour : x → −x, z → −z.
	var xf := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -Vector3(pel.x, 0.0, pel.y))
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := mi.transform
		var p := mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				local = (p as Node3D).transform * local
			p = p.get_parent()
		var full := xf * local
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] = full * v[i]
			arr[Mesh.ARRAY_VERTEX] = v
			if arr[Mesh.ARRAY_NORMAL] != null:
				var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for i in n.size():
					n[i] = (full.basis * n[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = n
			arr[Mesh.ARRAY_TANGENT] = null
			out.add_surface_from_arrays(mi.mesh.surface_get_primitive_type(s), arr)
			var mat := mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	root.free()
	_meshes[path] = out
	return out


## Centre de la pelouse d'un bâtiment posé (repère du monde) et axe de la longueur.
static func pelouse_monde(bs: BuildingSystem, bid: int) -> Dictionary:
	var b: Dictionary = bs.buildings[bid]
	var t := BuildingCatalog.get_type(String(b.t))
	var rect := bs._rect_of(b)
	var center := BuildingSystem.rect_center(rect) + Vector3(0, float(b.h), 0)
	var rot := -int(b.r) * PI / 2.0 + float(b.get("a", 0.0))
	var basis := Basis(Vector3.UP, rot)
	var pel := Vector2.ZERO
	if t.has("pelouse"):
		pel = t.pelouse
	elif String(b.t) == "foot":
		# Terrain de foot du catalogue : la longueur suit la profondeur.
		basis = basis * Basis(Vector3.UP, PI / 2.0)
	var length := 52.5
	var width := 34.0
	return {"centre": center + Basis(Vector3.UP, rot) * Vector3(pel.x, 0.05, pel.y), "basis": basis, "L": length, "W": width,
		"bol": t.get("bol", Vector2(58, 40)), "tribune": t.get("tribune", Vector2(8, 4)), "sieges": t.get("sieges", ["c8102e", "f2f2f2"])}
