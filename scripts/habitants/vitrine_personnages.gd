extends Node3D
## Vitrine des personnages (scenes/vitrine_personnages.tscn, F6 dans Godot) :
## une foule variée (âges, corpulences, peaux, coiffures, tenues) qui se
## promène, plus une rangée de métiers en tenue.
##   R : nouvelle foule   ·   1-4 : vue (foule, rangée des âges, gros plan, assis)
##   Espace : marche / arrêt   ·   clic gauche glissé : tourner

const REGIONS := ["europe", "afrique", "asie_est", "asie_sud", "moyen_orient", "ameriques", "oceanie", "mediterranee"]
const TENUES := [
	{"haut": "f4f4f4", "bas": "f4f4f4", "manches": 1.0},  # soignant
	{"haut": "1d3557", "bas": "1d3557", "accessoire": "1d3557"},  # police
	{"haut": "e76f51", "bas": "3b3f4a", "manches": 1.0},  # ouvrier
	{"haut": "2a9d8f", "bas": "2a9d8f"},  # chirurgien
	{"haut": "f4f1e8", "bas": "2b2d42"},  # serveur
	{"haut": "6b8f3a", "bas": "5c4a3a"},  # jardinier
]

var graine := 1
var marche := true
var foule: Array = []  # [{n, dir, vitesse, phase}]
var cam: Camera3D
var vue := 0
var _azimut := 0.6
var _drag := false
var _info: Label


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("a9c9e8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c8d4e0")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	sol.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("8fb36a")
	sol.material_override = sm
	add_child(sol)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	_info = Label.new()
	_info.position = Vector2(12, 8)
	_info.add_theme_color_override("font_color", Color.BLACK)
	add_child(_info)
	genere()


func genere() -> void:
	for f in foule:
		(f.n as Node).queue_free()
	foule.clear()
	var r := RandomNumberGenerator.new()
	r.seed = graine
	# Rangée des âges, au premier plan (z = 4).
	var ages := [0.8, 2.0, 4.5, 8.0, 13.0, 16.0, 25.0, 35.0, 45.0, 55.0, 70.0, 85.0]
	for i in ages.size():
		var s := "F" if i % 2 == 0 else "H"
		var look := Silhouettes.apparence(graine * 1000 + i, ages[i], s, REGIONS[(i + graine) % REGIONS.size()], graine * 100 + i)
		var n := Silhouettes.creer(look, true)
		n.position = Vector3(-6.6 + i * 1.2, 0, 4)
		add_child(n)
		foule.append({"n": n, "dir": Vector3.ZERO, "vitesse": 0.0, "phase": 0.0, "fixe": true})
	# Métiers en tenue (z = 1.5).
	for i in TENUES.size():
		var look2 := Silhouettes.apparence(graine * 2000 + i, 30.0 + i * 5.0, "F" if i % 2 else "H", REGIONS[(i * 3 + graine) % REGIONS.size()], graine * 300 + i)
		var n2 := Silhouettes.creer(look2, true)
		Silhouettes.habiller(n2, TENUES[i])
		n2.position = Vector3(-3.0 + i * 1.2, 0, 1.5)
		add_child(n2)
		foule.append({"n": n2, "dir": Vector3.ZERO, "vitesse": 0.0, "phase": 0.0, "fixe": true})
	# Assis sur un banc (x = 9).
	for i in 4:
		var look3 := Silhouettes.apparence(graine * 3000 + i, r.randf_range(5.0, 80.0), "F" if r.randf() < 0.5 else "H", REGIONS[r.randi() % REGIONS.size()], r.randi())
		var n3 := Silhouettes.creer(look3, true)
		Silhouettes.poser(n3, "assis")
		n3.position = Vector3(8.0 + i * 0.75, 0.45, 2.0)
		add_child(n3)
		foule.append({"n": n3, "dir": Vector3.ZERO, "vitesse": 0.0, "phase": 0.0, "fixe": true})
	var banc := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.4, 0.45, 0.5)
	banc.mesh = bm
	banc.position = Vector3(9.1, 0.225, 1.95)
	add_child(banc)
	foule.append({"n": banc, "dir": Vector3.ZERO, "vitesse": 0.0, "phase": 0.0, "fixe": true})
	# La foule qui se promène.
	for i in 40:
		var age := r.randf_range(1.0, 90.0) if r.randf() < 0.85 else r.randf_range(1.0, 12.0)
		var look4 := Silhouettes.apparence(graine * 5000 + i, age, "F" if r.randf() < 0.5 else "H", REGIONS[r.randi() % REGIONS.size()], graine * 700 + i / 2)
		var n4 := Silhouettes.creer(look4, true)
		var a := r.randf() * TAU
		n4.position = Vector3(r.randf_range(-12, 12), 0, r.randf_range(-14, -1))
		n4.rotation.y = a
		add_child(n4)
		var v := 1.3 * (0.6 if age > 75.0 or age < 5.0 else 1.0)
		foule.append({"n": n4, "dir": Vector3(sin(a), 0, cos(a)), "vitesse": v, "phase": r.randf() * TAU, "fixe": false})
	_place_cam()


func _process(delta: float) -> void:
	for f in foule:
		if f.fixe or not marche:
			continue
		var n: Node3D = f.n
		n.position += (f.dir as Vector3) * float(f.vitesse) * delta
		if absf(n.position.x) > 14.0 or n.position.z > 0.0 or n.position.z < -16.0:
			f.dir = -(f.dir as Vector3)
			n.rotation.y += PI
		f.phase = float(f.phase) + delta * float(f.vitesse) * 4.2
		Silhouettes.marcher(n, f.phase, 1.0)
	_info.text = "Personnages : R nouvelle foule · 1-4 vues · Espace marche · glisser pour tourner"


func _place_cam() -> void:
	var cible := Vector3(0, 0.9, 0)
	var dist := 16.0
	match vue:
		1:
			cible = Vector3(0, 0.8, 4)
			dist = 9.5
		2:
			cible = Vector3(-1.2, 1.3, 4)
			dist = 3.4
		3:
			cible = Vector3(9.1, 0.8, 2)
			dist = 4.5
	var h := dist * (0.35 if vue != 0 else 0.55)
	cam.position = cible + Vector3(sin(_azimut) * dist, h, cos(_azimut) * dist)
	cam.look_at(cible)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		match (ev as InputEventKey).keycode:
			KEY_R:
				graine += 1
				genere()
			KEY_SPACE:
				marche = not marche
			KEY_1, KEY_2, KEY_3, KEY_4:
				vue = (ev as InputEventKey).keycode - KEY_1
				_azimut = 0.6 if vue != 1 else 0.0
				_place_cam()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = (ev as InputEventMouseButton).pressed
	elif ev is InputEventMouseMotion and _drag:
		_azimut -= (ev as InputEventMouseMotion).relative.x * 0.01
		_place_cam()
