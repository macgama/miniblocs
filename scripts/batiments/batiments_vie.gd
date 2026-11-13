class_name BatimentsVie
extends Node
## Vie des bâtiments posés :
## - Chantier : un bâtiment neuf monte étage par étage derrière ses
##   échafaudages (grue pour les grands), dans une palissade, puis le toit, puis
##   on démonte tout. Personne ne s'y installe avant la fin (Population).
## - Usure : les façades se délavent, la mousse gagne les toits ; un bâtiment
##   vide depuis longtemps se couvre de lierre, ses fenêtres restent éteintes
##   ou sont condamnées (uniformes d'instance de batiment.gdshader).
## - Maisons habitées : clôture, boîte aux lettres, potager, linge (Abords) et
##   fumée aux cheminées.
##
## Données gardées dans chaque bâtiment (et dans la sauvegarde) : "ne" (date
## de construction, secondes Unix du jeu), "fin" (fin du chantier).

## Chantiers visibles (false : les bâtiments apparaissent d'un coup).
static var chantiers := true
## Usure, abords et fumée.
static var vie := true

const AN := 365.0 * 86400.0
## Durée d'un chantier (heures de jeu) : base + par étage de 3 m.
const CHANTIER_BASE_H := 1.0
const CHANTIER_ETAGE_H := 0.75
## Au-delà, les détails de vie (abords, fumée) ne sont pas dessinés.
const VUE_ABORDS := 260.0
const VUE_FUMEE := 380.0

var buildings: BuildingSystem
var ambiance: DayNight
var population: Population

## bid -> {"mi": nœud, "echaf": nœud, "grue": nœud, "fleche": nœud, "palissade": nœud, "H": hauteur}
var _chantiers := {}
## bid -> {"abords": nœud, "fumee": [nœuds], "usure": float, "abandon": float, "vide": float}
var _etat := {}
var _acc_chantier := 0.0
var _acc_vie := 0.0
var _clock := 0.0

static var _bounds_cache := {}
static var _fumee_mesh: ArrayMesh
static var _fumee_mat: ShaderMaterial


func setup(b: BuildingSystem, a: DayNight, p: Population) -> void:
	buildings = b
	ambiance = a
	population = p
	buildings.added.connect(_on_added)
	buildings.removed.connect(_on_removed)
	for bid in buildings.buildings:
		_on_added(bid)


func now() -> float:
	return ambiance.unix_time if ambiance != null else _clock


## Années de « vie » écoulées pour une durée de jeu (suit la vitesse de la vie des habitants).
func _years(seconds: float) -> float:
	var k := population.life_speed() if population != null else 1.0
	return seconds * k / AN


func _on_added(bid: int) -> void:
	var b: Dictionary = buildings.buildings[bid]
	var t := now()
	var mi := buildings.node_of(bid)
	if mi == null:
		return
	if not b.has("ne") or float(b.ne) <= 0.0:
		var fresh := not b.has("ne")
		b["ne"] = t
		b["fin"] = t + duree_chantier(String(b.t)) if fresh and chantiers and _chantier_possible(b) else t
	_etat[bid] = {"abords": null, "fumee": [], "usure": -1, "abandon": -1, "vide": -1.0,
		"base": posmod(hash(Vector2i(int(b.x), int(b.z))), 1000) / 1000.0 * 0.22}
	if float(b.get("fin", 0.0)) > t:
		_start_chantier(bid)
	else:
		b.erase("chantier")


func _on_removed(bid: int) -> void:
	_chantiers.erase(bid)
	_etat.erase(bid)


func _chantier_possible(b: Dictionary) -> bool:
	var t := BuildingCatalog.get_type(String(b.t))
	return not t.has("blocks") and not t.has("stade")


## Durée du chantier d'un type (secondes de jeu).
static func duree_chantier(id: String) -> float:
	var h := BuildingCatalog.approx_height(id)
	return (CHANTIER_BASE_H + ceilf(h / 3.0) * CHANTIER_ETAGE_H) * 3600.0


func _process(delta: float) -> void:
	_clock += delta
	if buildings == null:
		return
	_acc_chantier += delta
	_acc_vie += delta
	if _acc_chantier >= 0.2:
		_acc_chantier = 0.0
		_update_chantiers()
	if _acc_vie >= 1.5:
		_acc_vie = 0.0
		_update_vie()


# --- Chantiers ---------------------------------------------------------------------------

## Volume construit d'un maillage (sans les abords plats) : AABB des sommets au-dessus de 0,6 m.
static func body_bounds(mesh: ArrayMesh) -> AABB:
	var key := mesh.get_rid()
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	if mesh.get_surface_count() > 0:
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y > 0.6:
				lo = lo.min(v)
				hi = hi.max(v)
	var box := AABB(Vector3.ZERO, Vector3(1, 1, 1))
	if lo.x < INF:
		lo.y = 0.0
		box = AABB(lo, hi - lo)
	_bounds_cache[key] = box
	return box


func _start_chantier(bid: int) -> void:
	var b: Dictionary = buildings.buildings[bid]
	var mi := buildings.node_of(bid)
	b["chantier"] = true
	var bb := body_bounds(mi.mesh as ArrayMesh)
	# Matériaux propres au chantier : bâtiment (et sa version lointaine) d'un côté,
	# échafaudages de l'autre (ils dépassent un peu la partie construite).
	var mat := NightWindows.chantier_copy()
	var mat_echaf := NightWindows.chantier_copy()
	mi.material_override = mat
	var far := mi.get_node_or_null("Loin") as MeshInstance3D
	if far != null:
		far.material_override = mat
	var echaf := MeshInstance3D.new()
	echaf.name = "Echafaudage"
	echaf.mesh = _scaffold_mesh(bb)
	echaf.material_override = mat_echaf
	echaf.visibility_range_end = 1400.0
	mi.add_child(echaf)
	var t := BuildingCatalog.get_type(String(b.t))
	var pal := MeshInstance3D.new()
	pal.name = "Palissade"
	pal.mesh = _palissade_mesh(float(t.get("w", 8)), float(t.get("d", 8)))
	pal.material_override = NightWindows.chantier_material()
	pal.visibility_range_end = 900.0
	mi.add_child(pal)
	var c := {"mi": mi, "echaf": echaf, "palissade": pal, "grue": null, "fleche": null, "H": bb.end.y,
		"mat": mat, "mat_echaf": mat_echaf}
	if bb.end.y > 12.0:
		var g := _grue(bb)
		mi.add_child(g)
		c.grue = g
		c.fleche = g.get_node("Fleche")
	_chantiers[bid] = c
	_set_clip(bid, 3.0)


func _set_clip(bid: int, h: float) -> void:
	var c: Dictionary = _chantiers[bid]
	(c.mat as ShaderMaterial).set_shader_parameter("chantier_h", h)
	(c.mat_echaf as ShaderMaterial).set_shader_parameter("chantier_h", h + 1.3 if h < 9000.0 else h)


## Avancement du chantier (0 à 1), 1 si terminé ou inconnu.
func progress(bid: int) -> float:
	if not buildings.buildings.has(bid):
		return 1.0
	var b: Dictionary = buildings.buildings[bid]
	var ne := float(b.get("ne", 0.0))
	var fin := float(b.get("fin", 0.0))
	if fin <= ne:
		return 1.0
	return clampf((now() - ne) / (fin - ne), 0.0, 1.0)


func _update_chantiers() -> void:
	var done := []
	for bid in _chantiers:
		var c: Dictionary = _chantiers[bid]
		if not is_instance_valid(c.mi):
			done.append(bid)
			continue
		var p := progress(bid)
		if p >= 1.0:
			done.append(bid)
			continue
		var H: float = c.H
		# Étage par étage jusqu'à 85 %, puis le toit ; les échafaudages restent jusqu'au bout.
		var h := 10000.0
		if p < 0.85:
			h = (floorf(p / 0.85 * ceilf(H / 3.0)) + 1.0) * 3.0
		_set_clip(bid, h)
		if c.fleche != null:
			(c.fleche as Node3D).rotation.y = sin(_clock * 0.15 + float(bid)) * 1.3
	for bid in done:
		_finish_chantier(bid)


func _finish_chantier(bid: int) -> void:
	var c: Dictionary = _chantiers.get(bid, {})
	_chantiers.erase(bid)
	if c.is_empty() or not is_instance_valid(c.mi):
		return
	var mi: MeshInstance3D = c.mi
	mi.material_override = null
	var far := mi.get_node_or_null("Loin") as MeshInstance3D
	if far != null:
		far.material_override = null
	# L'usure sera réappliquée au prochain passage.
	if _etat.has(bid):
		_etat[bid].usure = -1.0
	for key in ["echaf", "palissade", "grue"]:
		if c[key] != null:
			(c[key] as Node).queue_free()
	if buildings.buildings.has(bid):
		buildings.buildings[bid].erase("chantier")
	# Les habitants peuvent s'installer.
	buildings.changed.emit()


## Termine tout de suite les chantiers en cours (tests, captures).
func finish_all() -> void:
	for bid in _chantiers.keys():
		buildings.buildings[bid]["fin"] = buildings.buildings[bid].get("ne", 0.0)
		_finish_chantier(bid)


static func _scaffold_mesh(bb: AABB) -> ArrayMesh:
	var k := BlocMesh.new()
	var x0 := bb.position.x - 0.8
	var x1 := bb.end.x + 0.8
	var z0 := bb.position.z - 0.8
	var z1 := bb.end.z + 0.8
	var H := bb.end.y + 1.0
	var pole := Color("b3b8bf")
	var plank := Color("a07a4a")
	var net := Color("2f7f6f")
	var levels := maxi(1, int(H / 2.0))
	var edges := [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x1, z0), Vector2(x1, z1)], [Vector2(x1, z1), Vector2(x0, z1)], [Vector2(x0, z1), Vector2(x0, z0)]]
	var ei := 0
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var length := a.distance_to(b)
		var n := maxi(1, int(length / 2.6))
		var along_x := absf(b.x - a.x) > 0.01
		var inward := Vector2(0, 0.45) if (along_x and a.y < (z0 + z1) / 2.0) else (Vector2(0, -0.45) if along_x else (Vector2(0.45, 0) if a.x < (x0 + x1) / 2.0 else Vector2(-0.45, 0)))
		for i in n:
			var p := a.lerp(b, float(i) / n)
			k.box(p.x, 0, p.y, 0.09, H, 0.09, pole)
			k.box(p.x + inward.x * 1.6, 0, p.y + inward.y * 1.6, 0.09, H, 0.09, pole)
		var mid := (a + b) / 2.0
		for l in levels:
			var y := (l + 1) * 2.0
			# Plancher et lisse.
			var c := mid + inward
			k.box(c.x, y - 0.06, c.y, (length if along_x else 0.75), 0.06, (0.75 if along_x else length), plank)
			k.box(mid.x, y + 0.9, mid.y, (length if along_x else 0.06), 0.06, (0.06 if along_x else length), pole)
			k.box(mid.x, y + 0.45, mid.y, (length if along_x else 0.05), 0.05, (0.05 if along_x else length), pole)
			# Filets sur quelques travées.
			for i in n:
				if BlocMesh._hash(Vector3(i, l, ei) * 3.1) < 0.16:
					var p0 := a.lerp(b, float(i) / n)
					var p1 := a.lerp(b, float(i + 1) / n)
					var pm := (p0 + p1) / 2.0 - inward * 0.1
					k.box(pm.x, y - 2.0, pm.y, (p0.distance_to(p1) if along_x else 0.03), 2.0, (0.03 if along_x else p0.distance_to(p1)), net)
		ei += 1
	return k.to_mesh()


static func _palissade_mesh(w: float, d: float) -> ArrayMesh:
	var k := BlocMesh.new()
	var col := Color("d6d9dc")
	var x0 := -w / 2.0 + 0.1
	var x1 := w / 2.0 - 0.1
	var z0 := -d / 2.0 + 0.1
	var z1 := d / 2.0 - 0.1
	for e in [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x1, z0), Vector2(x1, z1)], [Vector2(x1, z1), Vector2(x0, z1)], [Vector2(x0, z1), Vector2(x0, z0)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n := maxi(1, int(a.distance_to(b) / 3.5))
		for i in n:
			if i == n / 2 and a.y == z0 and b.y == z0:
				continue # entrée du chantier
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			var pm := (p0 + p1) / 2.0
			var along_x := absf(b.x - a.x) > 0.01
			var length := p0.distance_to(p1) - 0.1
			k.box(pm.x, 0.1, pm.y, (length if along_x else 0.04), 1.9, (0.04 if along_x else length), col)
			k.box(p0.x, 0, p0.y, 0.25, 0.15, 0.6 if along_x else 0.25, Color("8a8f96"))
			if i % 2 == 0:
				k.box(pm.x, 1.2, pm.y, (length * 0.5 if along_x else 0.05), 0.35, (0.05 if along_x else length * 0.5), Color("e8b923"))
	return k.to_mesh()


static func _grue(bb: AABB) -> Node3D:
	var root := Node3D.new()
	root.name = "Grue"
	var H := bb.end.y + 8.0
	var x := bb.end.x + 2.2
	var z := bb.end.z + 2.2
	root.position = Vector3(x, 0, z)
	var yellow := Color("e8b923")
	var k := BlocMesh.new()
	k.box(0, 0, 0, 3.0, 0.8, 3.0, Color("8a8f96"))
	for ox in [-0.8, 0.8]:
		for oz in [-0.8, 0.8]:
			k.box(ox, 0.8, oz, 0.16, H - 0.8, 0.16, yellow)
	var y := 0.8
	while y < H:
		k.box(0, y, -0.8, 1.6, 0.1, 0.1, yellow)
		k.box(0, y, 0.8, 1.6, 0.1, 0.1, yellow)
		k.box(-0.8, y, 0, 0.1, 0.1, 1.6, yellow)
		k.box(0.8, y, 0, 0.1, 0.1, 1.6, yellow)
		y += 2.0
	var mast := MeshInstance3D.new()
	mast.mesh = k.to_mesh(NightWindows.chantier_material())
	root.add_child(mast)
	var jib := Node3D.new()
	jib.name = "Fleche"
	jib.position = Vector3(0, H, 0)
	var kj := BlocMesh.new()
	var reach := clampf(maxf(bb.size.x, bb.size.z) + 6.0, 18.0, 45.0)
	kj.box(0, 0, 0, 2.0, 2.2, 2.0, yellow)
	kj.box(0.9, 0.5, -1.05, 0.2, 1.0, 0.8, Color("6d97b8").darkened(0.4))
	kj.box(0, 2.2, 0, 0.3, 4.0, 0.3, yellow)
	kj.box(-reach / 2.0, 0.9, 0, reach, 0.9, 0.9, yellow)
	kj.box(5.0, 0.9, 0, 10.0, 0.9, 1.2, yellow)
	kj.box(8.5, 0.0, 0, 2.6, 1.8, 1.6, Color("8a8f96"))
	var hook := -reach * 0.6
	kj.box(hook, 0.3, 0, 1.0, 0.6, 1.0, Color("55585e"))
	kj.box(hook, -H * 0.55, 0, 0.04, H * 0.55 + 0.3, 0.04, Color("2b2b2b"))
	kj.box(hook, -H * 0.55 - 0.5, 0, 0.5, 0.5, 0.3, Color("b5432f"))
	kj.box(hook, -H * 0.55 - 1.6, 0, 1.6, 1.1, 1.2, Color("a64b35"))
	var jm := MeshInstance3D.new()
	jm.mesh = kj.to_mesh(NightWindows.chantier_material())
	jib.add_child(jm)
	root.add_child(jib)
	return root


# --- Usure, abords et fumée ------------------------------------------------------------

func _occupe(bid: int) -> bool:
	if population == null:
		return true
	return not (population.by_home.get(bid, []) as Array).is_empty() or not (population.by_job.get(bid, []) as Array).is_empty()


func _habite(bid: int) -> bool:
	return population != null and not (population.by_home.get(bid, []) as Array).is_empty()


func _update_vie() -> void:
	if not vie:
		return
	var t := now()
	for bid in _etat:
		if _chantiers.has(bid) or not buildings.buildings.has(bid):
			continue
		var b: Dictionary = buildings.buildings[bid]
		var e: Dictionary = _etat[bid]
		var mi := buildings.node_of(bid)
		if mi == null:
			continue
		var tt := BuildingCatalog.get_type(String(b.t))
		var accueille := int(tt.get("logements", 0)) + int(tt.get("emplois", 0)) > 0
		var occupe := _occupe(bid)
		# Depuis quand le bâtiment est-il vide ?
		if not accueille or occupe:
			e.vide = -1.0
		elif e.vide < 0.0:
			e.vide = maxf(t, float(b.get("fin", t)))
		var age := _years(maxf(t - float(b.get("ne", t)), 0.0))
		var usure: float = e.base + age / (60.0 if occupe or not accueille else 18.0)
		var abandon := 0.0
		if e.vide >= 0.0:
			abandon = clampf((_years(t - float(e.vide)) - 0.5) / 2.0, 0.0, 1.0)
		usure = clampf(usure, 0.0, 1.0)
		# Paliers : quelques matériaux partagés suffisent (et le renderer
		# Compatibilité n'a pas de réglage par objet).
		var qu := roundi(usure * 5.0)
		var qa := roundi(abandon * 4.0)
		if qu != int(e.usure) or qa != int(e.abandon):
			e.usure = qu
			e.abandon = qa
			apply_wear(mi, qu, qa)
		var habite := _habite(bid)
		_set_abords(bid, mi, e, habite)
		_set_fumee(bid, mi, e, habite)


## Matériau d'usure d'un bâtiment (et de sa version lointaine). Les dégâts
## laissés par les événements (métadonnées « ev_degats », « ev_bache »,
## « ev_panne » posées par Evenements) s'y ajoutent.
static func apply_wear(mi: MeshInstance3D, usure_q: int, abandon_q: int) -> void:
	mi.set_meta("usure_q", usure_q)
	mi.set_meta("abandon_q", abandon_q)
	refresh_material(mi)


## Recalcule le matériau d'un bâtiment (usure + dégâts des événements).
## Les modèles Blender (.glb) gardent leurs propres matériaux.
static func refresh_material(mi: MeshInstance3D) -> void:
	if mi == null or mi.has_meta("glb"):
		return
	var u := int(mi.get_meta("usure_q", 0))
	var a := int(mi.get_meta("abandon_q", 0))
	var dq := int(mi.get_meta("ev_degats", 0))
	var bq := int(mi.get_meta("ev_bache", 0))
	var pn := bool(mi.get_meta("ev_panne", false)) or bool(mi.get_meta("res_panne", false))
	var m: Material = null
	if u > 0 or a > 0 or dq > 0 or bq > 0 or pn:
		m = NightWindows.variant_material(u, a, dq, bq, pn)
	mi.material_override = m
	var far := mi.get_node_or_null("Loin") as MeshInstance3D
	if far != null:
		far.material_override = m


func _set_abords(bid: int, mi: MeshInstance3D, e: Dictionary, on: bool) -> void:
	var b: Dictionary = buildings.buildings[bid]
	if on and e.abords == null:
		var m := Abords.mesh_for(String(b.t), NightWindows.building_material())
		if m == null:
			return
		var n := MeshInstance3D.new()
		n.name = "Abords"
		n.mesh = m
		n.visibility_range_end = VUE_ABORDS
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(n)
		e.abords = n
	elif not on and e.abords != null:
		(e.abords as Node).queue_free()
		e.abords = null


func _set_fumee(bid: int, mi: MeshInstance3D, e: Dictionary, on: bool) -> void:
	var list: Array = e.fumee
	if on and list.is_empty():
		var ancres: Dictionary = mi.mesh.get_meta("ancres", {}) if mi.mesh.has_meta("ancres") else {}
		for p: Vector3 in ancres.get("fumee", []):
			var n := MeshInstance3D.new()
			n.name = "Fumee"
			n.mesh = fumee_mesh()
			n.position = p
			n.visibility_range_end = VUE_FUMEE
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 9, 8))
			mi.add_child(n)
			list.append(n)
	elif not on and not list.is_empty():
		for n in list:
			(n as Node).queue_free()
		list.clear()


## Bouffées de fumée : petits octaèdres, UV.x = rang de la bouffée.
static func fumee_mesh() -> ArrayMesh:
	if _fumee_mesh != null:
		return _fumee_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	var pts := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var faces := [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	for i in n:
		var r := 0.5 + 0.2 * sin(i * 2.3)
		var rot := Basis(Vector3.UP, i * 0.9)
		for f in faces:
			var a: Vector3 = rot * pts[f[0]] * r
			var b: Vector3 = rot * pts[f[1]] * r
			var c: Vector3 = rot * pts[f[2]] * r
			var nn := (b - a).cross(c - a).normalized()
			if nn.dot(a + b + c) < 0.0:
				nn = -nn
				var tmp := b
				b = c
				c = tmp
			for v in [a, c, b]:
				st.set_normal(nn)
				st.set_uv(Vector2(float(i) / n, 0))
				st.add_vertex(v)
	_fumee_mesh = st.commit()
	if _fumee_mat == null:
		_fumee_mat = ShaderMaterial.new()
		_fumee_mat.shader = load("res://scripts/batiments/fumee.gdshader")
	_fumee_mesh.surface_set_material(0, _fumee_mat)
	return _fumee_mesh
