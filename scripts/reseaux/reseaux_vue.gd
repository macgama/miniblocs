class_name ReseauxVue
extends Node3D
## Ce qu'on voit des réseaux :
## - lignes électriques : pylônes (HT) ou poteaux (MT) et câbles, toujours visibles ;
##   pendant le chantier, seuls les pylônes déjà montés apparaissent ;
## - conduites d'eau et égouts : enterrés, montrés en couleur avec le calque ;
## - calque d'un réseau : une pastille au-dessus de chaque bâtiment (vert :
##   desservi, orange : rationné, rouge : coupé) et les sources en grand.

var reseaux: Reseaux
## res -> calque affiché
var calques := {"elec": false, "eau": false, "egout": false}
var calques_sales := true

var _mat: StandardMaterial3D
var _mat_calque: StandardMaterial3D
## "res:id" -> MeshInstance3D
var _troncons := {}
var _pastilles: MultiMeshInstance3D
var _fantome: MeshInstance3D
## Calque : routes et tronçons colorés selon leur réseau (vert, orange, rouge).
var _lignes_calque: MeshInstance3D
var _acc := 0.0


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.85
	_mat_calque = StandardMaterial3D.new()
	_mat_calque.vertex_color_use_as_albedo = true
	_mat_calque.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_calque.no_depth_test = true
	_mat_calque.render_priority = 2
	_pastilles = MultiMeshInstance3D.new()
	_pastilles.name = "Pastilles"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(4, 1.2, 4)
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = pm
	mm.mesh = bm
	_pastilles.multimesh = mm
	_pastilles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pastilles)
	_lignes_calque = MeshInstance3D.new()
	_lignes_calque.name = "LignesCalque"
	_lignes_calque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lignes_calque)
	_fantome = MeshInstance3D.new()
	_fantome.name = "Fantome"
	_fantome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fantome)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 and not calques_sales:
		return
	_acc = 0.0
	calques_sales = false
	_maj_pastilles()


func set_calque(res: String, on: bool) -> void:
	if not calques.has(res) or bool(calques[res]) == on:
		return
	calques[res] = on
	for k in _troncons:
		if String(k).begins_with(res + ":"):
			_refaire(res, int(String(k).split(":")[1]))
	calques_sales = true


func calque_actif() -> String:
	for r in calques:
		if calques[r]:
			return r
	return ""


func tout_refaire() -> void:
	for k in _troncons:
		var n: Node = _troncons[k]
		if is_instance_valid(n):
			n.queue_free()
	_troncons.clear()
	if reseaux == null:
		return
	for res in Reseaux.RES:
		for id in reseaux.reseau(res).troncons:
			_refaire(res, id)
	calques_sales = true


func refaire_troncon(res: String, id: int) -> void:
	_refaire(res, id)
	calques_sales = true


func avancement(res: String, id: int, _a: float) -> void:
	_refaire(res, id)


func _refaire(res: String, id: int) -> void:
	var key := "%s:%d" % [res, id]
	if _troncons.has(key):
		var old: Node = _troncons[key]
		if is_instance_valid(old):
			old.queue_free()
		_troncons.erase(key)
	var r := reseaux.reseau(res)
	if not r.troncons.has(id):
		return
	var e: Dictionary = r.troncons[id]
	var mesh: ArrayMesh = null
	var mat := _mat
	if res == "elec":
		var av := 1.0 if bool(e.ok) else float(e.get("av", 0.0))
		mesh = ligne_aerienne(e.pts, String(e.t), av)
	elif bool(calques[res]) or (reseaux.outil == Reseaux.Outil.TRACER and String(ReseauxTypes.troncon(reseaux.type_troncon).res) == res):
		var col: Color = ReseauxTypes.COULEURS[res]
		if not bool(e.ok):
			col = col.darkened(0.45)
		mesh = ruban(e.pts, 2.2 if String(e.t) == "collecteur" else 1.4, col, 0.4)
		mat = _mat_calque
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.name = "T_" + key.replace(":", "_")
	add_child(mi)
	_troncons[key] = mi


## Aperçu du tronçon en cours de tracé.
func fantome(pts: PackedVector3Array, col: Color) -> void:
	if _fantome == null:
		return
	if pts.size() < 2:
		_fantome.mesh = null
		return
	var c := col
	c.a = 0.8
	_fantome.mesh = ruban(pts, 1.6, c, 0.6)
	_fantome.material_override = _mat_calque


# --- Maillages --------------------------------------------------------------------------

## Bande colorée posée sur le sol le long d'un tracé.
static func ruban(pts: PackedVector3Array, largeur: float, col: Color, haut := 0.3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		var a := pts[i] + Vector3(0, haut, 0)
		var b := pts[i + 1] + Vector3(0, haut, 0)
		var d := b - a
		d.y = 0.0
		if d.length() < 0.01:
			continue
		var s := Vector3(-d.z, 0, d.x).normalized() * largeur * 0.5
		st.set_color(col)
		st.set_normal(Vector3.UP)
		for v in [a - s, a + s, b + s, a - s, b + s, b - s]:
			st.add_vertex(v)
	return st.commit()


## Pylônes ou poteaux tous les `pas` mètres, câbles entre eux. av : part montée (chantier).
static func ligne_aerienne(pts: PackedVector3Array, type_id: String, av := 1.0) -> ArrayMesh:
	var tr := ReseauxTypes.troncon(type_id)
	var pas := float(tr.get("pas", 60.0))
	var haut := float(tr.get("haut", 10.0))
	var ht := type_id == "ligne_ht"
	var total := ReseauBase.longueur(pts)
	var n := maxi(1, ceili(total / pas))
	var poses := []
	for i in n + 1:
		poses.append(_point_a(pts, total * float(i) / n))
	var montes := clampi(int(floor(av * (n + 1) + 0.001)), 0 if av < 1.0 else n + 1, n + 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var metal := Color("8a9099") if ht else Color("9c8f7a")
	var cable := Color("2b2d30")
	var tetes := []
	for i in montes:
		var p: Vector3 = poses[i][0]
		var dir: Vector3 = poses[i][1]
		var cote := Vector3(-dir.z, 0, dir.x).normalized()
		var bas := Basis(cote, Vector3.UP, dir)
		if ht:
			# Pylône en treillis : fût effilé et deux consoles.
			_boite(st, p + Vector3(0, haut * 0.25, 0), Vector3(3.2, haut * 0.5, 3.2), bas, metal)
			_boite(st, p + Vector3(0, haut * 0.72, 0), Vector3(1.6, haut * 0.44, 1.6), bas, metal)
			_boite(st, p + Vector3(0, haut * 0.78, 0), Vector3(12.0, 0.5, 0.8), bas, metal)
			_boite(st, p + Vector3(0, haut * 0.93, 0), Vector3(8.0, 0.5, 0.8), bas, metal)
			tetes.append([p + Vector3(0, haut * 0.76, 0) + cote * 5.6, p + Vector3(0, haut * 0.76, 0) - cote * 5.6, p + Vector3(0, haut * 0.91, 0) + cote * 3.6])
		else:
			_boite(st, p + Vector3(0, haut * 0.5, 0), Vector3(0.35, haut, 0.35), bas, metal)
			_boite(st, p + Vector3(0, haut - 0.4, 0), Vector3(2.2, 0.18, 0.18), bas, metal)
			tetes.append([p + Vector3(0, haut - 0.25, 0) + cote * 0.95, p + Vector3(0, haut - 0.25, 0) - cote * 0.95, p + Vector3(0, haut - 0.25, 0)])
	# Câbles entre deux pylônes montés, avec une flèche au milieu.
	for i in range(maxi(montes - 1, 0)):
		for c in 3:
			var a: Vector3 = tetes[i][c]
			var b: Vector3 = tetes[i + 1][c]
			var fleche := a.distance_to(b) * (0.03 if ht else 0.02)
			var prev := a
			for s in range(1, 5):
				var t := s / 4.0
				var q := a.lerp(b, t) - Vector3(0, fleche * 4.0 * t * (1.0 - t), 0)
				_cable(st, prev, q, 0.12 if ht else 0.07, cable)
				prev = q
	st.generate_normals()
	return st.commit()


static func _point_a(pts: PackedVector3Array, s: float) -> Array:
	var acc := 0.0
	for i in range(pts.size() - 1):
		var l := pts[i].distance_to(pts[i + 1])
		if acc + l >= s - 0.001 or i == pts.size() - 2:
			var t := 0.0 if l < 0.001 else clampf((s - acc) / l, 0.0, 1.0)
			var d := pts[i + 1] - pts[i]
			d.y = 0.0
			if d.length() < 0.001:
				d = Vector3.FORWARD
			return [pts[i].lerp(pts[i + 1], t), d.normalized()]
		acc += l
	return [pts[pts.size() - 1], Vector3.FORWARD]


static func _boite(st: SurfaceTool, c: Vector3, size: Vector3, b: Basis, col: Color) -> void:
	var h := size * 0.5
	var corners := []
	for i in 8:
		var v := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		corners.append(c + b * v)
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	st.set_color(col)
	for f in faces:
		var a: Vector3 = corners[f[0]]
		var bb: Vector3 = corners[f[1]]
		var cc: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		for v in [a, bb, cc, a, cc, d]:
			st.add_vertex(v)


static func _cable(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var z := d.normalized()
	var x := z.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := x.cross(z).normalized()
	_boite(st, (a + b) * 0.5, Vector3(r, r, d.length()), Basis(x, y, z), col)


# --- Pastilles du calque ---------------------------------------------------------------------

func _maj_pastilles() -> void:
	var res := calque_actif()
	var mm := _pastilles.multimesh
	if res == "" or reseaux == null or reseaux.buildings == null:
		mm.instance_count = 0
		_lignes_calque.mesh = null
		return
	var r := reseaux.reseau(res)
	# Taille des pastilles et des bandes selon la distance de la caméra.
	var zoom := 1.0
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var rig := cam.get_parent_node_3d()
		var dist := cam.global_position.distance_to(rig.global_position if rig != null else Vector3.ZERO)
		zoom = clampf(dist / 200.0, 1.0, 4.0)
	_maj_lignes(r, zoom)
	var b := reseaux.buildings
	var list := []
	for bid in r.consos:
		list.append([bid, false])
	for bid in r.sources:
		list.append([bid, true])
	mm.instance_count = list.size()
	var k := {"elec": "e", "eau": "o", "egout": "g"}[res] as String
	for i in list.size():
		var bid := int(list[i][0])
		var src: bool = list[i][1]
		var p := Vector3.ZERO
		var hgt := 8.0
		if b.buildings.has(bid):
			var bd: Dictionary = b.buildings[bid]
			p = BuildingSystem.rect_center(b._rect_of(bd))
			p.y = float(bd.get("h", 0.0))
			hgt = BuildingCatalog.approx_height(String(bd.t)) if not src else 6.0
		var col := Color("ffd166")
		var sc := 1.0
		if src:
			var inf: Dictionary = reseaux.sources_info.get(bid, {})
			var ratio := 1.0 if float(inf.get("max", 0.0)) <= 0.0 else float(inf.get("cap", 0.0)) / float(inf.max)
			col = ReseauxTypes.COULEURS[res].lerp(Color("e63946"), 1.0 - clampf(ratio, 0.0, 1.0))
			sc = 3.0
		else:
			var t := float(reseaux.etat.get(bid, {}).get(k, 1.0))
			col = Color("52b788") if t >= 0.95 else (Color("f4a261") if t >= 0.5 else Color("e63946"))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc * zoom, zoom, sc * zoom)), p + Vector3(0, hgt + 3.0 * zoom, 0)))
		mm.set_instance_color(i, col)


## Routes et tronçons du réseau, colorés par l'état de leur partie du réseau.
func _maj_lignes(r: ReseauBase, zoom: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for i in r.lignes.size():
		var t := r.taux_composante(r.lignes_comp[i])
		var col := Color("52b788") if t >= 0.95 else (Color("f4a261") if t > 0.0 else Color("e63946"))
		col.a = 0.85
		var pts: PackedVector3Array = r.lignes[i]
		var w := 2.5 * zoom
		for j in range(pts.size() - 1):
			var a := pts[j] + Vector3(0, 0.6, 0)
			var b := pts[j + 1] + Vector3(0, 0.6, 0)
			var d := b - a
			d.y = 0.0
			if d.length() < 0.01:
				continue
			var s := Vector3(-d.z, 0, d.x).normalized() * w * 0.5
			st.set_color(col)
			st.set_normal(Vector3.UP)
			for v in [a - s, a + s, b + s, a - s, b + s, b - s]:
				st.add_vertex(v)
			n += 1
	_lignes_calque.mesh = st.commit() if n > 0 else null
	_lignes_calque.material_override = _mat_calque
