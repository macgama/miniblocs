class_name ParcSoireesVisuels
extends Node3D
## Ce qu'on voit des soirées du parc (ParcSoirees) : fusées et bouquets des
## feux d'artifice (couleurs selon l'époque), salves en rythme du feu
## pyromélodique, chars illuminés de la parade, rayons laser, drones qui
## dessinent dans le ciel.
##
## Le spectacle suit l'horloge du jeu (il commence et finit à l'heure de jeu) ;
## les fusées, elles, bougent à la vitesse visible (EchelleTemps) : en pause,
## tout se fige. À la vitesse par défaut, le spectacle se voit quelques
## secondes : ralentir le temps (T, Maj + T) pour en profiter.

## Durée de jeu minimale pendant laquelle on montre un spectacle (s de jeu),
## pour qu'il reste visible à vitesse rapide.
const MONTRE_MIN := 5400.0
const MAX_BOUQUETS := 70
const MAX_LUMIERES := 6

var parc: ParcLoisirs
var rng := RandomNumberGenerator.new()
## Par parc (id d'entrée) : état du spectacle affiché.
var _shows: Dictionary = {}
## Effets en vol : {"node", "age", "vie", "kind", ...}.
var _effets: Array = []
var _mat_points: StandardMaterial3D
var _mesh_point: QuadMesh


func setup(p: ParcLoisirs) -> void:
	parc = p
	rng.seed = 18_031_789


func _ready() -> void:
	_mat_points = StandardMaterial3D.new()
	_mat_points.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_points.vertex_color_use_as_albedo = true
	_mat_points.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_points.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_points.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mesh_point = QuadMesh.new()
	_mesh_point.size = Vector2(1.4, 1.4)
	_mesh_point.material = _mat_points


## Nombre d'effets visibles en ce moment (tests).
func effets() -> int:
	return _effets.size()


func spectacles_affiches() -> Array:
	return _shows.keys()


func _process(delta: float) -> void:
	if parc == null:
		return
	var dt := EchelleTemps.dt(delta)
	_suivre(dt)
	_vieillir(dt)


## Démarre, fait vivre et arrête les spectacles selon l'horloge du parc.
func _suivre(dt: float) -> void:
	var vus := {}
	for e in parc.parcs:
		var p: Dictionary = parc.parcs[e]
		var show: Dictionary = p.get("show", {})
		var last: Dictionary = _shows.get(e, {})
		if show.is_empty() and not last.is_empty():
			show = last.show
		if show.is_empty():
			continue
		var fin := maxf(float(show.t1), float(show.t0) + MONTRE_MIN)
		if parc.clock < float(show.t0) or parc.clock > fin:
			continue
		vus[e] = true
		if last.is_empty() or int(last.show.id) != int(show.id):
			if not last.is_empty() and last.get("noeud") != null and is_instance_valid(last.noeud):
				(last.noeud as Node).queue_free()
			last = {"show": show.duplicate(), "acc": 0.0, "t": 0.0, "noeud": null}
			_shows[e] = last
			_installer(int(e), last)
		_animer(int(e), last, dt)
	for e in _shows.keys():
		if not vus.has(e):
			var n: Node = _shows[e].get("noeud")
			if n != null and is_instance_valid(n):
				n.queue_free()
			_shows.erase(e)


func _installer(e: int, st: Dictionary) -> void:
	var type_id := String(st.show.type)
	var taille := int(st.show.taille)
	var c := parc.centre(e)
	var root := Node3D.new()
	root.name = "Spectacle_%d" % e
	root.position = c
	add_child(root)
	st.noeud = root
	match type_id:
		"drones":
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = _mesh_point
			mm.instance_count = int(ParcSoirees.DRONES[clampi(taille, 0, 2)])
			var mi := MultiMeshInstance3D.new()
			mi.name = "drones"
			mi.multimesh = mm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			for i in mm.instance_count:
				mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, 2.0, 0)))
				mm.set_instance_color(i, Color(1, 1, 1, 0.9))
		"parade_lumineuse":
			for i in 6 + 3 * taille:
				var k := BlocMesh.new()
				var col: Color = ParcTypes.VIFS[i % ParcTypes.VIFS.size()]
				k.box(0, 0, 0, 3.0, 1.2, 5.0, col)
				k.box(0, 1.2, 0, 2.0, 2.0, 2.0, col.lightened(0.3))
				var mi := MeshInstance3D.new()
				mi.name = "char_%d" % i
				mi.mesh = k.to_mesh(_mat_lumineux(col))
				root.add_child(mi)
		"laser":
			for i in 4 + 2 * taille:
				var bm := BoxMesh.new()
				bm.size = Vector3(0.25, 0.25, 260.0)
				var mi := MeshInstance3D.new()
				mi.name = "laser_%d" % i
				mi.mesh = bm
				mi.material_override = _mat_lumineux([Color(0.2, 1.0, 0.3), Color(0.3, 0.6, 1.0), Color(1.0, 0.2, 0.5)][i % 3], 0.75)
				mi.position = Vector3(0, 3.0, 0)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mi)
			var eau := QuadMesh.new()
			eau.size = Vector2(40.0, 18.0)
			var ecran := MeshInstance3D.new()
			ecran.name = "ecran_eau"
			ecran.mesh = eau
			ecran.material_override = _mat_lumineux(Color(0.6, 0.85, 1.0), 0.25)
			ecran.position = Vector3(0, 9.0, 18.0)
			root.add_child(ecran)


func _mat_lumineux(col: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _animer(e: int, st: Dictionary, dt: float) -> void:
	st.t = float(st.t) + dt
	var type_id := String(st.show.type)
	var taille := int(st.show.taille)
	var root: Node3D = st.noeud
	match type_id:
		"feu_artifice", "pyromelodique":
			var cadence: float = [1.5, 3.0, 5.0][clampi(taille, 0, 2)]
			if type_id == "pyromelodique":
				# Salves en rythme : toutes les 1,2 s, plusieurs fusées ensemble.
				st.acc = float(st.acc) + dt
				while float(st.acc) >= 1.2:
					st.acc = float(st.acc) - 1.2
					for i in 2 + taille * 2:
						_fusee(root.global_position, i, 2 + taille * 2)
			else:
				st.acc = float(st.acc) + dt * cadence
				while float(st.acc) >= 1.0:
					st.acc = float(st.acc) - 1.0
					_fusee(root.global_position, rng.randi() % 5, 5)
		"drones":
			_drones(root, float(st.t), taille)
		"parade_lumineuse":
			var n := root.get_child_count()
			for i in n:
				var ch: Node3D = root.get_child(i)
				var a := float(st.t) * 0.12 + TAU * i / n
				ch.position = Vector3(cos(a) * 45.0, 0.3, sin(a) * 45.0)
				ch.rotation.y = -a
		"laser":
			var n := 0
			for ch in root.get_children():
				if not String(ch.name).begins_with("laser_"):
					continue
				var a := float(st.t) * (0.4 + 0.1 * n) + n * 1.1
				(ch as Node3D).rotation = Vector3(-0.35 - 0.25 * sin(float(st.t) * 0.7 + n), a, 0)
				n += 1


## Une fusée : elle monte, puis éclate en bouquet.
func _fusee(origine: Vector3, i: int, n: int) -> void:
	if _effets.size() >= MAX_BOUQUETS:
		return
	var depart := origine + Vector3(rng.randf_range(-25.0, 25.0), 0.0, rng.randf_range(-25.0, 25.0))
	var haut := depart + Vector3((float(i) - n / 2.0) * 6.0 + rng.randf_range(-4.0, 4.0), rng.randf_range(55.0, 105.0), rng.randf_range(-6.0, 6.0))
	var fil := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 2.2)
	fil.mesh = qm
	fil.material_override = _mat_lumineux(Color(1.0, 0.85, 0.5), 0.9)
	(fil.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	fil.position = depart
	fil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fil)
	_effets.append({"node": fil, "age": 0.0, "vie": 1.1, "kind": "fusee", "a": depart, "b": haut})


func _bouquet(pos: Vector3) -> void:
	var pal := ParcSoirees.palette()
	var col: Color = pal[rng.randi() % pal.size()]
	var pt := CPUParticles3D.new()
	pt.position = pos
	pt.amount = rng.randi_range(70, 130)
	pt.lifetime = 2.4
	pt.one_shot = true
	pt.explosiveness = 1.0
	pt.direction = Vector3.UP
	pt.spread = 180.0
	pt.initial_velocity_min = 16.0
	pt.initial_velocity_max = 24.0
	pt.gravity = Vector3(0, -5.0, 0)
	pt.damping_min = 4.0
	pt.damping_max = 6.0
	pt.mesh = _mesh_point
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 1.0))
	g.set_color(1, Color(col.r * 0.6, col.g * 0.3, col.b * 0.2, 0.0))
	pt.color_ramp = g
	pt.speed_scale = EchelleTemps.facteur()
	pt.emitting = true
	pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pt)
	_effets.append({"node": pt, "age": 0.0, "vie": 3.0, "kind": "bouquet"})
	if _lumieres() < MAX_LUMIERES:
		var l := OmniLight3D.new()
		l.position = pos
		l.light_color = col
		l.light_energy = 4.0
		l.omni_range = 160.0
		l.shadow_enabled = false
		add_child(l)
		_effets.append({"node": l, "age": 0.0, "vie": 0.7, "kind": "lumiere"})


func _lumieres() -> int:
	var n := 0
	for f in _effets:
		if String(f.kind) == "lumiere":
			n += 1
	return n


func _vieillir(dt: float) -> void:
	var garde: Array = []
	for f in _effets:
		var nd: Node3D = f.node
		if not is_instance_valid(nd):
			continue
		f.age = float(f.age) + dt
		if nd is CPUParticles3D:
			(nd as CPUParticles3D).speed_scale = EchelleTemps.facteur()
		match String(f.kind):
			"fusee":
				var s := clampf(float(f.age) / float(f.vie), 0.0, 1.0)
				nd.position = (f.a as Vector3).lerp(f.b, 1.0 - pow(1.0 - s, 2.0))
				if s >= 1.0:
					_bouquet(f.b)
			"lumiere":
				(nd as OmniLight3D).light_energy = 4.0 * maxf(0.0, 1.0 - float(f.age) / float(f.vie))
		if float(f.age) >= float(f.vie):
			nd.queue_free()
		else:
			garde.append(f)
	_effets = garde


## Formes dessinées par les drones, l'une après l'autre (6 s visibles chacune).
func _drones(root: Node3D, t: float, taille: int) -> void:
	var mi: MultiMeshInstance3D = root.get_node_or_null("drones")
	if mi == null:
		return
	var mm := mi.multimesh
	var n := mm.instance_count
	var forme := int(t / 6.0) % 4
	var mel := clampf(fposmod(t, 6.0) / 2.0, 0.0, 1.0)
	var base := 60.0 + 8.0 * taille
	for i in n:
		var u := float(i) / n
		var a := _forme(forme, u) * (1.0 + 0.4 * taille)
		var b := _forme((forme + 3) % 4, u) * (1.0 + 0.4 * taille)
		var p := b.lerp(a, smoothstep(0.0, 1.0, mel))
		var y := base + p.y + (2.0 - 2.0 * mel) * sin(t * 2.0 + i)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, y, p.z)))
		var col := Color(1.0, 0.9, 0.8)
		if forme == 3:
			col = Color.from_hsv(fposmod(u + t * 0.05, 1.0), 0.6, 1.0)
		elif forme == 2:
			col = Color(1.0, 0.5, 0.3)
		mm.set_instance_color(i, col)


## Point u (0 à 1) d'une forme : 0 cercle (grande roue), 1 étoile, 2 cœur, 3 spirale.
static func _forme(f: int, u: float) -> Vector3:
	var a := TAU * u
	match f:
		0:
			# Grande roue : cercle et rayons.
			if u < 0.7:
				var b := TAU * u / 0.7
				return Vector3(cos(b) * 30.0, sin(b) * 30.0, 0)
			var r := fposmod(u - 0.7, 0.3) / 0.3
			var k := int((u - 0.7) / 0.0375)
			return Vector3(cos(k * TAU / 8.0) * 30.0 * r, sin(k * TAU / 8.0) * 30.0 * r, 0)
		1:
			var rr := 30.0 if int(u * 10.0) % 2 == 0 else 13.0
			var s := fposmod(u * 10.0, 1.0)
			var a0 := TAU * floorf(u * 10.0) / 10.0
			var a1 := TAU * (floorf(u * 10.0) + 1.0) / 10.0
			var r1 := 13.0 if rr > 20.0 else 30.0
			var p0 := Vector3(sin(a0) * rr, cos(a0) * rr, 0)
			var p1 := Vector3(sin(a1) * r1, cos(a1) * r1, 0)
			return p0.lerp(p1, s)
		2:
			var x := 16.0 * pow(sin(a), 3.0)
			var y := 13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)
			return Vector3(x * 1.8, y * 1.8, 0)
	var rs := 6.0 + 26.0 * u
	return Vector3(cos(a * 4.0) * rs, 10.0 * sin(a * 2.0), sin(a * 4.0) * rs)
