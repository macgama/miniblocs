class_name FeuxArtifice
extends Node3D
## Feux d'artifice au-dessus d'un lieu (fête de la ville, inauguration, palier).
##
## Des fusées montent depuis le sol (traînée d'étincelles), éclatent en
## bouquet de couleur (pivoine, saule qui retombe, anneau) avec une lueur qui
## éclaire la place, puis s'éteignent. Le bouquet final tire plusieurs fusées
## d'un coup. Chaque éclatement joue « feu_artifice » à sa position.
##
##   var f := FeuxArtifice.new()
##   f.duree = 20.0           # secondes réelles de spectacle (0 : jusqu'à arreter())
##   parent.add_child(f)       # à la position du pas de tir
##
## Les mouvements suivent la vitesse du temps (EchelleTemps : rien ne bouge en
## pause). Le nœud se libère tout seul après le bouquet final.

signal fini

const COULEURS := [Color("ff4d6d"), Color("ffd166"), Color("06d6a0"), Color("4cc9f0"), Color("c77dff"),
	Color("f8f9fa"), Color("ff9f1c"), Color("80ffdb")]
const FORMES := ["pivoine", "saule", "anneau"]
## Hauteur d'éclatement (m) : 60 à 110 m, comme un vrai feu municipal.
const HAUTEUR := Vector2(60.0, 110.0)
const VITESSE_MONTEE := 55.0

## Durée du spectacle en secondes réelles (0 : jusqu'à arreter()).
var duree := 20.0
## Fusées par seconde pendant le spectacle.
var cadence := 1.3
## Rayon du pas de tir (m) autour du centre.
var rayon := 25.0
## Son des éclatements (désactivé dans les tests).
var avec_son := true
var rng := RandomNumberGenerator.new()
## Fusées en vol : {node, v (Vector3), apex (y), couleur, forme}.
var fusees: Array = []
var eclatements := 0

var _t := 0.0
var _prochaine := 0.0
var _final := false
var _arrete := false
var _fin_t := -1.0

static var _mat_cache := {}


func _ready() -> void:
	name = "FeuxArtifice"
	if rng.seed == 0:
		rng.randomize()


## Arrête le spectacle par le bouquet final.
func arreter() -> void:
	if not _final:
		_bouquet_final()


func _process(delta: float) -> void:
	var dt := EchelleTemps.dt(delta)
	if dt <= 0.0:
		return
	_t += dt
	if not _final:
		_prochaine -= dt
		if _prochaine <= 0.0:
			lancer_fusee()
			_prochaine = rng.randf_range(0.5, 1.5) / maxf(cadence, 0.1)
		if duree > 0.0 and _t >= duree:
			_bouquet_final()
	for f in fusees.duplicate():
		var n: Node3D = f.node
		if not is_instance_valid(n):
			fusees.erase(f)
			continue
		f.v.y -= 9.0 * dt
		n.position += (f.v as Vector3) * dt
		if n.position.y >= float(f.apex) or float(f.v.y) < 6.0:
			_eclater(f)
	if _final and fusees.is_empty() and _fin_t < 0.0:
		_fin_t = _t + 3.5
	if _fin_t >= 0.0 and _t >= _fin_t and not _arrete:
		_arrete = true
		fini.emit()
		queue_free()


## Une fusée part d'un point du pas de tir.
func lancer_fusee(forme := "") -> void:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * rayon
	var depart := Vector3(cos(a) * r, 0.5, sin(a) * r)
	var col: Color = COULEURS[rng.randi() % COULEURS.size()]
	var n := Node3D.new()
	n.name = "Fusee"
	n.position = depart
	add_child(n)
	n.add_child(_trainee(col))
	var apex := rng.randf_range(HAUTEUR.x, HAUTEUR.y)
	var v := Vector3(rng.randf_range(-3.0, 3.0), VITESSE_MONTEE + rng.randf_range(-6.0, 8.0), rng.randf_range(-3.0, 3.0))
	fusees.append({"node": n, "v": v, "apex": apex, "couleur": col,
		"forme": forme if forme != "" else String(FORMES[rng.randi() % FORMES.size()])})


func _bouquet_final() -> void:
	_final = true
	for i in 9:
		lancer_fusee("pivoine" if i % 3 else "saule")


func _eclater(f: Dictionary) -> void:
	fusees.erase(f)
	var n: Node3D = f.node
	var pos := n.position
	n.queue_free()
	eclatements += 1
	var b := bouquet(f.couleur, String(f.forme), rng.randi())
	b.position = pos
	add_child(b)
	if avec_son and is_inside_tree():
		Son.jouer_a("feu_artifice", to_global(pos), -2.0, 1500.0)


## Traînée d'étincelles derrière une fusée qui monte.
static func _trainee(col: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Trainee"
	p.amount = 40
	p.lifetime = 0.7
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -120, -30), Vector3(60, 240, 60))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 12.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.6
	pm.color_ramp = _rampe(col.lightened(0.5), 0.9)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	q.material = _mat()
	p.draw_pass_1 = q
	return p


## Un éclatement (un seul tir de particules + lueur qui s'éteint), se libère seul.
static func bouquet(col: Color, forme: String, seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Bouquet"
	var p := GPUParticles3D.new()
	p.name = "Etoiles"
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 160 if forme != "anneau" else 110
	p.lifetime = 2.6 if forme != "saule" else 4.0
	p.randomness = 0.3
	p.seed = absi(seed)
	p.use_fixed_seed = true
	p.visibility_aabb = AABB(Vector3(-70, -90, -70), Vector3(140, 150, 140))
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.direction = Vector3.UP
	match forme:
		"saule":
			pm.initial_velocity_min = 14.0
			pm.initial_velocity_max = 20.0
			pm.gravity = Vector3(0, -6.0, 0)
			pm.damping_min = 3.0
			pm.damping_max = 5.0
		"anneau":
			pm.spread = 90.0
			pm.direction = Vector3(1, 0, 0)
			pm.flatness = 1.0
			pm.initial_velocity_min = 24.0
			pm.initial_velocity_max = 26.0
			pm.gravity = Vector3(0, -2.0, 0)
			pm.damping_min = 6.0
			pm.damping_max = 8.0
		_:
			pm.initial_velocity_min = 22.0
			pm.initial_velocity_max = 30.0
			pm.gravity = Vector3(0, -3.0, 0)
			pm.damping_min = 9.0
			pm.damping_max = 12.0
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	pm.color_ramp = _rampe(col, 1.0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.material = _mat()
	p.draw_pass_1 = q
	p.emitting = true
	root.add_child(p)
	var l := OmniLight3D.new()
	l.name = "Lueur"
	l.light_color = col
	l.omni_range = 140.0
	l.light_energy = 5.0
	root.add_child(l)
	var tw := root.create_tween() if root.is_inside_tree() else null
	if tw == null:
		root.tree_entered.connect(func() -> void:
			var t2 := root.create_tween()
			t2.tween_property(l, "light_energy", 0.0, 1.2)
			t2.tween_interval(p.lifetime + 0.5)
			t2.tween_callback(root.queue_free), CONNECT_ONE_SHOT)
	return root


static func _rampe(col: Color, alpha: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	g.colors = PackedColorArray([Color(col.lightened(0.6), alpha), Color(col.lightened(0.1), alpha), Color(col, alpha * 0.8),
		Color(col.darkened(0.4), 0.0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _mat() -> StandardMaterial3D:
	if not _mat_cache.has("m"):
		_mat_cache.m = EvVisuels._particle_material(Color.WHITE, true)
	return _mat_cache.m
