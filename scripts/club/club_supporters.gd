class_name ClubSupporters
extends Node3D
## Les supporters en ville : un drapeau aux couleurs du club flotte devant les
## logements où vivent des supporters (un par logement, le club qu'on y aime
## le plus). Quand le club perd beaucoup, une partie des drapeaux disparaît ;
## après une montée ou un titre, il y en a partout.
##
## L'humeur des supporters, les abonnements et la fête de la montée sont dans
## chaque section (ClubSport) ; ici, seulement ce qu'on voit dans les rues.

const MAX_DRAPEAUX := 600
const MAT_H := 5.2

var buildings: BuildingSystem
var population: Population
## Nombre de drapeaux posés (pour les tests et le menu).
var drapeaux := 0
## sport → nombre de drapeaux.
var par_sport: Dictionary = {}
var _signature := ""
var _acc := 0.0
var _mm: Array[MultiMeshInstance3D] = []


func setup(b: BuildingSystem, p: Population) -> void:
	buildings = b
	population = p
	name = "DrapeauxSupporters"


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 2.0:
		return
	_acc = 0.0
	refresh()


func _sections() -> Array:
	var out := []
	for s in ClubSports.ORDRE:
		var c := ClubSport.section(s)
		if c != null and c.fonde() and c.buildings == buildings:
			out.append(c)
	return out


func refresh(force := false) -> void:
	var secs := _sections()
	var sig := ""
	for c in secs:
		sig += "%s:%s:%d:%d:%d|" % [c.sport, ",".join(c.club.couleurs), c.today(), int(c.club.get("division", 0)), int(float(c.club.get("humeur", 0.0)) * 4.0)]
	if population != null:
		sig += str(population.persons.size())
	if not force and sig == _signature:
		return
	_signature = sig
	rebuild(secs)


func _vider() -> void:
	for m in _mm:
		if is_instance_valid(m):
			m.queue_free()
	_mm.clear()
	drapeaux = 0
	par_sport.clear()


func rebuild(secs: Array = []) -> void:
	_vider()
	if secs.is_empty():
		secs = _sections()
	if secs.is_empty() or population == null or buildings == null:
		return
	# Logement → {sport: supporters}.
	var maisons := {}
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		var home := population.home_of(p)
		if home < 0 or not buildings.buildings.has(home):
			continue
		for c in secs:
			if (c as ClubSport).est_supporter(p):
				var m: Dictionary = maisons.get(home, {})
				m[c.sport] = int(m.get(c.sport, 0)) + 1
				maisons[home] = m
	var poses := []
	for home in maisons:
		var m: Dictionary = maisons[home]
		var best := ""
		for s in m:
			if best == "" or int(m[s]) > int(m[best]):
				best = s
		var c := ClubSport.section(best)
		var h := float(c.club.get("humeur", 0.0))
		# Club au fond du trou : on range une partie des drapeaux.
		var garde := 1.0 if h > -0.25 else (0.6 if h > -0.6 else 0.3)
		if float(posmod(hash([int(home), best, "drapeau"]), 100)) / 100.0 >= garde:
			continue
		poses.append([int(home), c])
	poses.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	if poses.size() > MAX_DRAPEAUX:
		poses.resize(MAX_DRAPEAUX)
	if poses.is_empty():
		return
	var mats := [_multi(_mat_mesh(), poses.size(), false), _multi(_toile_mesh(), poses.size(), true), _multi(_toile_mesh(), poses.size(), true)]
	for i in poses.size():
		var bid: int = poses[i][0]
		var c: ClubSport = poses[i][1]
		var b: Dictionary = buildings.buildings[bid]
		var rect := buildings._rect_of(b)
		# Au coin du terrain, côté rue (façade vers −Z avant rotation).
		var coin := Vector3(rect.position.x + 1.0, float(b.get("h", 0.0)), rect.position.y + 1.0)
		var r := int(b.get("r", 0))
		if r == 1:
			coin.x = rect.end.x - 1.0
		elif r == 2:
			coin = Vector3(rect.end.x - 1.0, coin.y, rect.end.y - 1.0)
		elif r == 3:
			coin.z = rect.end.y - 1.0
		var rot := Basis(Vector3.UP, float(posmod(hash([bid, "vent"]), 628)) / 100.0)
		var cols: Array = c.club.couleurs
		(mats[0].multimesh as MultiMesh).set_instance_transform(i, Transform3D(Basis.IDENTITY, coin))
		var haut := Transform3D(rot, coin + rot * Vector3(0.75, MAT_H - 0.45, 0))
		var bas := Transform3D(rot, coin + rot * Vector3(0.75, MAT_H - 0.9, 0))
		(mats[1].multimesh as MultiMesh).set_instance_transform(i, haut)
		(mats[1].multimesh as MultiMesh).set_instance_color(i, Color(String(cols[0])))
		(mats[2].multimesh as MultiMesh).set_instance_transform(i, bas)
		(mats[2].multimesh as MultiMesh).set_instance_color(i, Color(String(cols[1])))
		par_sport[c.sport] = int(par_sport.get(c.sport, 0)) + 1
	drapeaux = poses.size()
	for m in mats:
		add_child(m)
		_mm.append(m)


func _multi(mesh: Mesh, n: int, couleurs: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = couleurs
	mm.mesh = mesh
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_end = 900.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = couleurs
	mat.albedo_color = Color.WHITE if couleurs else Color("9aa0a6")
	mat.roughness = 0.85
	mi.material_override = mat
	return mi


static func _mat_mesh() -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3(0.1, MAT_H, 0.1)
	# BoxMesh est centrée : on décale à l'instance (mât posé au sol).
	var am := ArrayMesh.new()
	var arr := m.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i] += Vector3(0, MAT_H * 0.5, 0)
	arr[Mesh.ARRAY_VERTEX] = v
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func _toile_mesh() -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3(1.5, 0.45, 0.04)
	return m
