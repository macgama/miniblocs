class_name BibleGlb
extends RefCounted
## Bâtiments de la bible modélisés dans Blender (assets/modeles/bible/).
##
## Chaque famille (publics, résidences, industrie, fermes…) a une fiche JSON
## écrite par tools/blender/bible/generer.py : une entrée de catalogue par
## bâtiment (nom, catégorie, emprise, prix, emplois, métiers, logements…), le
## chemin du .glb et sa palette. BuildingCatalog fusionne ces entrées avec les
## autres bâtiments ; build_mesh() « cuit » le .glb en un ArrayMesh à couleurs
## par sommet, comme les modèles faits en code : même matériau partagé (fenêtres
## allumées la nuit, intérieurs, usure, chantiers), variantes de couleur, et
## façade tournée vers −Z.
##
## Pour un export du jeu : ajouter *.json au filtre « fichiers non-ressources ».

const DOSSIER := "res://assets/modeles/bible/"
## Côté de la palette (8 × 8 cases).
const CASES := 8

static var _entries: Dictionary = {}
static var _charge := false
## id -> {"v": PackedVector3Array, "n": PackedVector3Array, "i": PackedInt32Array,
##        "c": PackedInt32Array (case de palette par sommet)} ; {} si le .glb manque.
static var _geo: Dictionary = {}


## Entrées de catalogue de toutes les familles (id -> fiche).
static func entries() -> Dictionary:
	if _charge:
		return _entries
	_charge = true
	var d := DirAccess.open(DOSSIER)
	if d == null:
		return _entries
	var fichiers := Array(d.get_files())
	fichiers.sort()
	for f: String in fichiers:
		if not f.ends_with(".json") or f.ends_with(".palette.json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + f))
		if not data is Dictionary:
			push_warning("Bible : fiche illisible " + f)
			continue
		for e: Dictionary in (data as Dictionary).get("batiments", []):
			var t := e.duplicate(true)
			t["w"] = int(e.get("w", 10))
			t["d"] = int(e.get("d", 10))
			t["cost"] = int(e.get("cost", 0))
			for k in ["emplois", "logements", "visiteurs", "variantes"]:
				t[k] = int(e.get(k, 0))
			var acces: Array[String] = []
			for a in e.get("access", ["route"]):
				acces.append(String(a))
			t["access"] = acces
			t["style"] = ""
			t["famille"] = String((data as Dictionary).get("famille", ""))
			_entries[String(e.id)] = t
	return _entries


## Le .glb de ce type est-il disponible (importé par Godot) ?
static func disponible(id: String) -> bool:
	return not _geometrie(id).is_empty()


## Géométrie du .glb, lue une fois : sommets tournés d'un demi-tour (façade
## vers −Z), normales, indices et case de palette de chaque sommet.
static func _geometrie(id: String) -> Dictionary:
	if _geo.has(id):
		return _geo[id]
	var out := {}
	_geo[id] = out
	var t: Dictionary = entries().get(id, {})
	var chemin := String(t.get("glb", ""))
	if chemin == "" or not ResourceLoader.exists(chemin):
		return out
	var scene := load(chemin) as PackedScene
	if scene == null:
		return out
	var racine := scene.instantiate()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cases := PackedInt32Array()
	var indices := PackedInt32Array()
	var demi_tour := Basis(Vector3.UP, PI)
	for n in racine.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := mi.transform
		var p := mi.get_parent()
		while p != null and p != racine:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		if racine is Node3D:
			xf = (racine as Node3D).transform * xf
		xf = Transform3D(demi_tour, Vector3.ZERO) * xf
		var m := mi.mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var base := verts.size()
			for i in v.size():
				verts.append(xf * v[i])
				normals.append((xf.basis * (nn[i] if i < nn.size() else Vector3.UP)).normalized())
				var c := 0
				if i < uv.size():
					var cx := clampi(int(uv[i].x * CASES), 0, CASES - 1)
					var cy := clampi(int(uv[i].y * CASES), 0, CASES - 1)
					c = cy * CASES + cx
				cases.append(c)
			if idx.is_empty():
				for i in v.size():
					indices.append(base + i)
			else:
				for i in idx:
					indices.append(base + i)
	racine.free()
	if verts.is_empty():
		return out
	out["v"] = verts
	out["n"] = normals
	out["c"] = cases
	out["i"] = indices
	return out


## Couleurs de la palette (index -> Color) pour une variante (0 = d'origine).
static func couleurs(id: String, variant := 0) -> Array[Color]:
	var t: Dictionary = entries().get(id, {})
	var out: Array[Color] = []
	var noms: Array[String] = []
	for e in t.get("palette", []):
		noms.append(String(e[0]))
		out.append(Color(String(e[1])))
	if variant <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [id, variant])
	var teinte_murs := rng.randf()
	var toit := Color(CouleursModele.TUILES_TEINTES[rng.randi() % CouleursModele.TUILES_TEINTES.size()])
	var accent := rng.randf()
	for i in noms.size():
		var nom := noms[i]
		var o := out[i]
		if nom.begins_with("enduit") or nom == "ocre" or nom == "pignon":
			out[i] = Color.from_hsv(teinte_murs, rng.randf_range(0.08, 0.3), clampf(o.v, 0.78, 0.95))
		elif nom.begins_with("bardage"):
			out[i] = Color.from_hsv(teinte_murs, rng.randf_range(0.2, 0.45), clampf(o.v, 0.45, 0.75))
		elif nom == "tuile":
			out[i] = toit
		elif nom == "tuile_ombre":
			out[i] = toit.darkened(0.3)
		elif nom == "tuile_faitage":
			out[i] = toit.darkened(0.12)
		elif nom in ["volet", "porte", "bois_rouge"]:
			out[i] = Color.from_hsv(accent, rng.randf_range(0.3, 0.55), clampf(o.v, 0.3, 0.7))
		elif nom in ["bois_clair", "bois", "brique", "brique_claire"]:
			out[i] = Color.from_hsv(fposmod(o.h + rng.randf_range(-0.03, 0.03), 1.0), o.s * rng.randf_range(0.8, 1.15),
				clampf(o.v * rng.randf_range(0.88, 1.1), 0.0, 1.0))
	return out


## Maillage du bâtiment, prêt pour le matériau des bâtiments (NightWindows).
## details : teinte par face et ombre au pied des murs (comme BlocMesh).
static func build_mesh(id: String, material: Material = null, details := true, variant := 0) -> ArrayMesh:
	var g := _geometrie(id)
	var t: Dictionary = entries().get(id, {})
	if g.is_empty():
		return _secours(t, material)
	var pal := couleurs(id, variant)
	var verts: PackedVector3Array = g.v
	var normals: PackedVector3Array = g.n
	var cases: PackedInt32Array = g.c
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i in verts.size():
		var c: Color = pal[cases[i]] if cases[i] < pal.size() else Color.MAGENTA
		if details:
			if absf(normals[i].y) < 0.5:
				c = BlocMesh._ao(c, verts[i].y)
			c = BlocMesh._scale(c, 0.96 + BlocMesh._hash(normals[i] * 3.1 + Vector3(0, cases[i], 0)) * 0.06)
		cols[i] = c
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = g.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(0, material)
	return mesh


## Bloc simple quand le .glb n'est pas (encore) importé.
static func _secours(t: Dictionary, material: Material) -> ArrayMesh:
	var k := BlocMesh.new()
	var w := float(t.get("w", 6))
	var d := float(t.get("d", 6))
	k.box(0, 0, 0, maxf(w - 2.0, 1.0), maxf(float(t.get("h", 6.0)), 2.0), maxf(d - 2.0, 1.0), BuildingCatalog.WALL)
	return k.to_mesh(material)
