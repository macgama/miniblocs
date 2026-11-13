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


## Couleurs que le joueur peut changer (panneau Personnaliser) : clé de
## Personnalisation -> noms de la palette du modèle, par ordre de priorité. Les
## noms qui finissent par « * » sont des préfixes. Pour les murs, si aucun nom
## du premier groupe n'existe, on prend le second (pierre, béton, bois).
const GROUPES := {
	"mur": [["enduit*", "brique*", "bardage*", "ocre", "pignon", "terre", "adobe"], ["pierre_claire", "pierre", "beton_clair", "bois", "bois_clair"]],
	"toit_c": [["tuile", "tuile_faitage", "tuile_ombre", "ardoise", "zinc", "tole*", "chaume"]],
	"boiseries": [["cadre", "blanc", "sous_toit"]],
	"volets": [["volet", "bois_rouge", "vert", "bleu", "rouge"]],
	"porte": [["porte"], ["bois_sombre"]],
	"vitres": [["vitre", "verre_*"]],
}

static var _groupes: Dictionary = {}


static func _nom_dans(nom: String, liste: Array) -> bool:
	for m: String in liste:
		if m.ends_with("*") and nom.begins_with(m.trim_suffix("*")):
			return true
		if nom == m:
			return true
	return false


## Clé de personnalisation -> indices de la palette qu'elle recolore ({} si aucune).
static func groupes(id: String) -> Dictionary:
	if _groupes.has(id):
		return _groupes[id]
	var noms: Array[String] = []
	for e in (entries().get(id, {}) as Dictionary).get("palette", []):
		noms.append(String(e[0]))
	var out := {}
	var pris := {}
	for cle: String in GROUPES:
		for liste: Array in GROUPES[cle]:
			var idx: Array[int] = []
			for i in noms.size():
				if not pris.has(i) and _nom_dans(noms[i], liste):
					idx.append(i)
			if not idx.is_empty():
				for i in idx:
					pris[i] = true
				out[cle] = idx
				break
	_groupes[id] = out
	return out


## Couleur de référence d'une clé (la première couleur de son groupe).
static func couleur_cle(id: String, variant: int, cle: String) -> Color:
	var g: Dictionary = groupes(id)
	if not g.has(cle):
		return Color.WHITE
	var pal := couleurs(id, variant)
	return pal[int((g[cle] as Array)[0])]


## Couleurs de la palette (index -> Color) pour une variante (0 = d'origine),
## puis les couleurs choisies par le joueur (perso, voir Personnalisation) : chaque
## couleur du groupe prend la teinte choisie en gardant son écart de clarté avec
## la première (tuiles d'ombre, briques sombres…).
static func couleurs(id: String, variant := 0, perso: Dictionary = {}) -> Array[Color]:
	var out := _couleurs_variante(id, variant)
	if perso.is_empty():
		return out
	var g := groupes(id)
	for cle: String in g:
		if not perso.has(cle):
			continue
		var voulue := Color(String(perso[cle]))
		var idx: Array = g[cle]
		var ref := out[int(idx[0])]
		for i in idx:
			var o := out[int(i)]
			var ecart := o.v - ref.v
			out[int(i)] = Color.from_hsv(voulue.h, voulue.s, clampf(voulue.v + ecart, 0.0, 1.0))
	return out


static func _couleurs_variante(id: String, variant := 0) -> Array[Color]:
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
static func build_mesh(id: String, material: Material = null, details := true, variant := 0, perso: Dictionary = {}) -> ArrayMesh:
	var g := _geometrie(id)
	var t: Dictionary = entries().get(id, {})
	if g.is_empty():
		return _secours(t, material)
	var pal := couleurs(id, variant, perso)
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


static var _volumes: Dictionary = {}


## Volume principal du bâtiment, lu dans sa géométrie (pour « Ouvrir
## l'intérieur ») : {w, d, cx, cz, etages, toit ("deux_pans" ou "plat")}, dans
## le repère du bâtiment posé (façade vers −Z). Les murs sont les faces
## verticales qui passent à 2 m du sol : clôtures, haies basses et bancs n'y
## arrivent pas. {} si le modèle manque.
static func volume(id: String) -> Dictionary:
	if _volumes.has(id):
		return _volumes[id]
	var out := {}
	_volumes[id] = out
	var g := _geometrie(id)
	if g.is_empty():
		return out
	var verts: PackedVector3Array = g.v
	var idx: PackedInt32Array = g.i
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in range(0, idx.size() - 2, 3):
		var a := verts[idx[k]]
		var b := verts[idx[k + 1]]
		var c := verts[idx[k + 2]]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-8 or absf(n.normalized().y) > 0.3:
			continue
		if minf(a.y, minf(b.y, c.y)) > 1.0 or maxf(a.y, maxf(b.y, c.y)) < 2.4:
			continue
		# Une face assez large (pas un poteau ni un lampadaire).
		var lx := maxf(a.x, maxf(b.x, c.x)) - minf(a.x, minf(b.x, c.x))
		var lz := maxf(a.z, maxf(b.z, c.z)) - minf(a.z, minf(b.z, c.z))
		if maxf(lx, lz) < 0.6:
			continue
		for p in [a, b, c]:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var t: Dictionary = entries().get(id, {})
	if lo.x == INF or hi.x - lo.x < 3.0 or hi.y - lo.y < 3.0:
		return out
	# Trop petit devant l'emprise : murs mal lus (pilotis, cours ouvertes).
	if (hi.x - lo.x) * (hi.y - lo.y) < 0.25 * float(t.get("w", 1)) * float(t.get("d", 1)):
		return out
	# Hauteur sous le toit : bas des pans en pente, sinon haut des murs.
	var mur_haut := 0.0
	var avant_toit := INF
	var pentes := 0.0
	for k in range(0, idx.size() - 2, 3):
		var a := verts[idx[k]]
		var b := verts[idx[k + 1]]
		var c := verts[idx[k + 2]]
		var m := (a + b + c) / 3.0
		if m.x < lo.x - 0.8 or m.x > hi.x + 0.8 or m.z < lo.y - 0.8 or m.z > hi.y + 0.8:
			continue
		var cr := (b - a).cross(c - a)
		if cr.length_squared() < 1e-8:
			continue
		var n := cr.normalized()
		var bas := minf(a.y, minf(b.y, c.y))
		if absf(n.y) < 0.3 and bas < 1.0:
			mur_haut = maxf(mur_haut, maxf(a.y, maxf(b.y, c.y)))
		elif n.y > 0.3 and n.y < 0.985 and bas > 2.0:
			pentes += cr.length() * 0.5
			avant_toit = minf(avant_toit, bas)
	var pente := pentes >= 0.15 * (hi.x - lo.x) * (hi.y - lo.y)
	var haut := avant_toit if pente else mur_haut
	out["w"] = hi.x - lo.x
	out["d"] = hi.y - lo.y
	out["cx"] = (lo.x + hi.x) / 2.0
	out["cz"] = (lo.y + hi.y) / 2.0
	var etages := floori((haut + 0.6) / 3.0)
	# Grand comble sous un toit en pente : un étage de plus (combles aménagés).
	if pente and float(t.get("h", 0.0)) - haut >= 4.5:
		etages += 1
	if not pente:
		# Toits plats (tours) : la hauteur du modèle compte aussi.
		etages = maxi(etages, floori(float(t.get("h", 3.0)) * 0.85 / 3.0))
	out["etages"] = clampi(etages, 1, 60)
	out["toit"] = "deux_pans" if pente else "plat"
	return out
