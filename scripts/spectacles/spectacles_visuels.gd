class_name SpectaclesVisuels
extends Node3D
## Le public devant les salles : de petits personnages (MultiMesh, comme au
## parc) qui attendent devant la porte avant le spectacle et repartent après,
## et l'équipe de tournage devant les studios qui tournent (en journée).
## Leur nombre suit Spectacles.foule, au plus MAX_PAR_SALLE par salle.

const MAX_PAR_SALLE := 60
const MAX_TOTAL := 900
const EQUIPE := 14
const PEAUX := [Color("f6dccb"), Color("e5b48f"), Color("c98f67"), Color("a06743"), Color("75472d"), Color("4d2e1e")]
const HABITS := [Color("1d3557"), Color("8e1e24"), Color("2a9d8f"), Color("e9c46a"), Color("6b4a2f"), Color("5e6b73"), Color("f4a261"), Color("3a3d42"), Color("e6e1d3")]

var spect: Spectacles
var _corps: MultiMeshInstance3D
var _tetes: MultiMeshInstance3D
var _t := 0.0
var _anim := 0.0
## Personnages affichés : [position, angle, couleur d'habit, peau, phase].
var _gens: Array = []


func setup(s: Spectacles) -> void:
	spect = s


func _ready() -> void:
	_corps = _multi("Corps", ParcVisuels._corps_mesh())
	_tetes = _multi("Tetes", ParcVisuels._tete_mesh())


func _multi(n: String, mesh: Mesh) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mmi.multimesh = mm
	mmi.visibility_range_end = 700.0
	add_child(mmi)
	return mmi


func _process(delta: float) -> void:
	if spect == null or spect.ambiance == null:
		return
	_t += delta
	_anim += delta
	if _t >= 0.5:
		_t = 0.0
		_placer()
	if _anim >= 0.1:
		_anim = 0.0
		_bouger()


## Qui est dehors en ce moment, et où.
func _placer() -> void:
	_gens.clear()
	var now := spect._now(spect.ambiance.unix_time)
	var rng := RandomNumberGenerator.new()
	for bid in spect.salles:
		if _gens.size() >= MAX_TOTAL:
			break
		var n := mini(MAX_PAR_SALLE, int(ceilf(float(spect.foule(int(bid), now)) / 25.0)))
		if n <= 0:
			continue
		rng.seed = int(bid) * 7919
		_groupe(int(bid), n, rng, 3.0, 10.0)
	var h := float(now.h)
	if h >= 8.0 and h < 18.0:
		for bid in spect.studios:
			if spect.tournage_en_cours(int(bid)):
				rng.seed = int(bid) * 104729
				_groupe(int(bid), EQUIPE, rng, 4.0, 8.0)
	_dessiner()


func _groupe(bid: int, n: int, rng: RandomNumberGenerator, r0: float, r1: float) -> void:
	var b: Dictionary = spect.buildings.buildings.get(bid, {})
	if b.is_empty():
		return
	var p := spect.porte(bid)
	var front := BuildingSystem.front_dir(int(b.r)).rotated(Vector3.UP, float(b.get("a", 0.0)))
	var side := front.cross(Vector3.UP)
	for i in n:
		# Sur le parvis, entre la porte et le trottoir (pas sur la chaussée).
		var along := rng.randf_range(-1.0, 1.0) * (r1 + n * 0.12)
		var out := rng.randf_range(-r0 * 0.5, minf(r0 * 0.6, 2.2))
		var pos := p + side * along + front * out
		var ang := atan2(-front.x, -front.z) + rng.randf_range(-0.8, 0.8)
		_gens.append([pos, ang, HABITS[rng.randi() % HABITS.size()], PEAUX[rng.randi() % PEAUX.size()], rng.randf() * TAU])


func _dessiner() -> void:
	var mc := _corps.multimesh
	var mt := _tetes.multimesh
	var n := _gens.size()
	if mc.instance_count != n:
		mc.instance_count = n
		mt.instance_count = n
	for i in n:
		var g: Array = _gens[i]
		var tr := Transform3D(Basis(Vector3.UP, float(g[1])), g[0])
		mc.set_instance_transform(i, tr)
		mt.set_instance_transform(i, tr)
		mc.set_instance_color(i, g[2])
		mt.set_instance_color(i, g[3])


## Petits balancements : on piétine en attendant.
func _bouger() -> void:
	var mc := _corps.multimesh
	var mt := _tetes.multimesh
	var t := Time.get_ticks_msec() / 1000.0
	for i in mini(_gens.size(), mc.instance_count):
		var g: Array = _gens[i]
		var a := float(g[1]) + sin(t * 0.7 + float(g[4])) * 0.25
		var tr := Transform3D(Basis(Vector3.UP, a), (g[0] as Vector3) + Vector3(0, absf(sin(t * 2.0 + float(g[4]))) * 0.03, 0))
		mc.set_instance_transform(i, tr)
		mt.set_instance_transform(i, tr)


func compte() -> int:
	return _gens.size()
