class_name TourismeVisuels
extends Node3D
## Touristes devant les hébergements : de petits personnages (MultiMesh, comme
## au parc de loisirs) qui arrivent valise à la main, flânent devant l'entrée,
## prennent des photos. Leur nombre suit les clients (Tourisme.clients), au plus
## MAX_PAR_HEB par hébergement, seulement près de la caméra.

const MAX_PAR_HEB := 24
const DISTANCE := 700.0
const VITESSE := 1.1
const PEAUX := [Color("f6dccb"), Color("e5b48f"), Color("c98f67"), Color("a06743"), Color("75472d"), Color("4d2e1e")]
## Tenues de vacances : chemises à fleurs, rouge, jaune, bleu ciel, blanc.
const HABITS := [Color("e76f51"), Color("f4a261"), Color("e9c46a"), Color("2a9d8f"), Color("8ecae6"), Color("ffffff"), Color("d62828"), Color("90be6d")]
const VALISES := [Color("1d3557"), Color("e63946"), Color("343a40"), Color("ffb703"), Color("6a4c93")]

var tourisme: Tourisme
## bid → liste de touristes {p (Vector3), cible (Vector3), wait, cap, peau, habit, valise (Color ou null)}.
var agents: Dictionary = {}
var _corps: MultiMeshInstance3D
var _tetes: MultiMeshInstance3D
var _valises: MultiMeshInstance3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(t: Tourisme) -> void:
	tourisme = t
	_rng.seed = 31_415


func _ready() -> void:
	_corps = _multi("Corps", ParcVisuels._corps_mesh())
	_tetes = _multi("Tetes", ParcVisuels._tete_mesh())
	var k := BlocMesh.new()
	k.box(0.32, 0.05, 0.0, 0.18, 0.55, 0.38, Color.WHITE)
	k.box(0.32, 0.6, 0.0, 0.04, 0.12, 0.12, Color("212529"))
	_valises = _multi("Valises", k.to_mesh(ParcVisuels._mat()))


func _multi(nom: String, mesh: Mesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mmi.multimesh = mm
	mmi.visibility_range_end = DISTANCE
	add_child(mmi)
	return mmi


func _process(delta: float) -> void:
	if tourisme == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_peupler()
	_bouger(delta)
	_dessiner()


func _camera_pos() -> Vector3:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	return cam.global_position if cam != null else Vector3.ZERO


## Combien de touristes dessiner devant chaque hébergement.
func voulus(bid: int) -> int:
	var h := 0.0
	if tourisme.ambiance != null:
		var now := tourisme._now(tourisme.ambiance.unix_time)
		h = float(now.h)
	# La nuit, tout le monde dort (ou presque).
	var jour := 1.0 if h >= 8.0 and h < 22.0 else 0.15
	return mini(MAX_PAR_HEB, roundi(float(tourisme.clients(bid)) / 5.0 * jour))


func _peupler() -> void:
	var cam := _camera_pos()
	for bid in agents.keys():
		if not tourisme.heb.has(bid):
			agents.erase(bid)
	for bid in tourisme.heb:
		var door := tourisme.porte(int(bid))
		var loin := Vector2(door.x, door.z).distance_to(Vector2(cam.x, cam.z)) > DISTANCE
		var voulu := 0 if loin else voulus(int(bid))
		var list: Array = agents.get(bid, [])
		agents[bid] = list
		while list.size() > voulu:
			list.pop_back()
		while list.size() < voulu:
			var p := _point(int(bid), door)
			list.append({"p": p, "cible": p, "wait": _rng.randf_range(0.0, 4.0), "cap": _rng.randf() * TAU,
				"peau": PEAUX[_rng.randi() % PEAUX.size()], "habit": HABITS[_rng.randi() % HABITS.size()],
				"valise": VALISES[_rng.randi() % VALISES.size()] if _rng.randf() < 0.45 else null})


func _bouger(delta: float) -> void:
	for bid in agents:
		var door := tourisme.porte(int(bid))
		for a in agents[bid]:
			if float(a.wait) > 0.0:
				a.wait = float(a.wait) - delta
				continue
			var p: Vector3 = a.p
			var c: Vector3 = a.cible
			var d := Vector2(c.x - p.x, c.z - p.z)
			if d.length() < 0.2:
				# Nouvelle envie : regarder la façade, faire une photo, revenir à la porte.
				a.cible = _point(int(bid), door)
				a.wait = _rng.randf_range(1.0, 6.0)
				continue
			var step := minf(d.length(), VITESSE * delta)
			var dir := d.normalized()
			a.p = Vector3(p.x + dir.x * step, door.y, p.z + dir.y * step)
			a.cap = atan2(dir.x, dir.y)


## Un point devant la façade, côté bâtiment (pas sur la route).
func _point(bid: int, door: Vector3) -> Vector3:
	var c := tourisme.pos_of(bid)
	var vers := Vector3(c.x - door.x, 0, c.z - door.z)
	if vers.length() < 0.1:
		vers = Vector3(0, 0, 1)
	vers = vers.normalized()
	var cote := Vector3(-vers.z, 0, vers.x)
	return door + vers * _rng.randf_range(0.8, 3.0) + cote * _rng.randf_range(-8.0, 8.0)


func _dessiner() -> void:
	var n := 0
	var nv := 0
	for bid in agents:
		for a in agents[bid]:
			n += 1
			if a.valise != null:
				nv += 1
	var mc := _corps.multimesh
	var mt := _tetes.multimesh
	var mv := _valises.multimesh
	if mc.instance_count != n:
		mc.instance_count = n
		mt.instance_count = n
	if mv.instance_count != nv:
		mv.instance_count = nv
	var i := 0
	var j := 0
	for bid in agents:
		for a in agents[bid]:
			var xf := Transform3D(Basis(Vector3.UP, float(a.cap)).scaled(Vector3.ONE * 0.95), a.p)
			mc.set_instance_transform(i, xf)
			mc.set_instance_color(i, a.habit)
			mt.set_instance_transform(i, xf)
			mt.set_instance_color(i, a.peau)
			if a.valise != null:
				mv.set_instance_transform(j, xf)
				mv.set_instance_color(j, a.valise)
				j += 1
			i += 1


func count() -> int:
	var n := 0
	for bid in agents:
		n += (agents[bid] as Array).size()
	return n
