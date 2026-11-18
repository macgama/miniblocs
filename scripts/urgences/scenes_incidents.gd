class_name ScenesIncidents
extends Node3D
## Ce qu'on voit sur les lieux de chaque incident (low-poly, fait en code) :
##
## - Accident de la route : deux voitures accidentées (tôle froissée, feux de
##   détresse qui clignotent, un peu de fumée), éclats de verre, morceaux de
##   pare-chocs, flaque d'huile, triangle de signalisation, le conducteur
##   choqué au bord de la route et un blessé allongé. Sur la neige : une
##   voiture dans le fossé.
## - Feu de poubelle : un conteneur qui brûle sur le trottoir.
## - Malaise, chute, malade : la personne allongée devant chez elle, un voisin
##   penché sur elle.
## - Cambriolage : porte forcée et éclats de vitre devant la maison.
## - Incendie, arbre tombé, crue, manifestation : le décor vient déjà des
##   événements (flammes, arbre, eau, cortège) ; ici seulement les secours.
##
## Quand un véhicule de secours est sur place, son équipage en descend et
## travaille : pompiers à la lance (jet d'eau vers le feu, tuyau jusqu'au
## camion) ou à la tronçonneuse, ambulanciers penchés sur le blessé avec un
## brancard, policiers qui posent un cordon (rubalise, cônes) et règlent la
## circulation. L'ambulance repartie, le blessé n'est plus là ; l'incident
## terminé, tout disparaît.

const VUE := 650.0
const PAS := 0.25
const HUILE := Color("1d1d22")
const VERRE := Color("cfe6f2")
const ORANGE := Color("ff9f1c")

var urg: Urgences
## id -> {root, kind, anchor, dir (le long de la route), droite, sol, blink: [], blesse, voisin, cordon, equipes: {uid: {...}}}
var scenes: Dictionary = {}

var _acc := 0.0
var _temps := 0.0
var _rng := RandomNumberGenerator.new()

static var _mat_glow: StandardMaterial3D
static var _mat_eau: StandardMaterial3D
static var _epaves: Dictionary = {}


func _init() -> void:
	name = "ScenesIncidents"
	_rng.randomize()


# --- Ouverture et fermeture ----------------------------------------------------------------

## Décor des lieux d'un incident (appelé à l'ouverture par Urgences).
func ouvrir(inc: Dictionary) -> void:
	var id := int(inc.id)
	if scenes.has(id):
		return
	var sc := {"kind": String(inc.type), "blink": [], "equipes": {}, "blesse": null, "voisin": null, "cordon": null,
		"root": Node3D.new()}
	var root: Node3D = sc.root
	root.name = "Incident%d" % id
	add_child(root)
	scenes[id] = sc
	_rng.seed = hash([id, inc.pos])
	_placer(sc, inc)
	root.position = sc.anchor
	root.basis = Basis.looking_at(sc.dir, Vector3.UP)
	match String(inc.type):
		"accident":
			if String(inc.meta.get("role", "")) == "neige":
				_fosse(sc, inc)
			else:
				_accident(sc, inc)
		"feu_poubelle":
			_poubelle(sc)
		"malaise", "chute", "malades":
			_malaise(sc, inc)
		"cambriolage":
			_cambriolage(sc)
	inc.scene_pos = sc.anchor
	if sc.has("batiment"):
		inc.icone_pos = (sc.batiment as Vector3) + Vector3(0, float(sc.get("hauteur", 8.0)) + 1.0, 0)


func fermer(id: int) -> void:
	if not scenes.has(id):
		return
	var sc: Dictionary = scenes[id]
	(sc.root as Node).queue_free()
	scenes.erase(id)


func vider() -> void:
	for id in scenes.keys():
		fermer(int(id))


## Point des lieux : sur la route (accident, poubelle) ou devant la porte.
func _placer(sc: Dictionary, inc: Dictionary) -> void:
	var road: Dictionary = inc.road
	var pos: Vector3 = inc.pos
	sc.dir = Vector3.FORWARD
	sc.anchor = pos
	sc.sol = pos.y
	var net: TransportNetwork = urg.transport.network if urg != null and urg.transport != null else null
	var eid := int(road.get("edge", -1))
	var on_road := net != null and net.edges.has(eid)
	var len := float(net.edges[eid].len) if on_road else 0.0
	var s := float(road.get("s", 0.0))
	if on_road:
		var t := net.tangent_at(eid, s)
		t.y = 0.0
		if t.length_squared() > 1e-6:
			sc.dir = t.normalized()
	var droite := Vector3(-sc.dir.z, 0, sc.dir.x)
	sc.droite = droite
	var bid := _bid(inc)
	match String(inc.type):
		"accident", "feu_poubelle":
			if on_road:
				# Un peu plus loin que l'arrêt des secours : le premier véhicule
				# se gare derrière (gyrophares pour protéger les lieux).
				var avance := 14.0
				var s2 := clampf(s + avance, minf(2.0, len * 0.5), maxf(len - 2.0, len * 0.5))
				var p := net.point_at(eid, s2)
				var hw := net.half_width(eid)
				var side := TransportTypes.side_of(String(net.edges[eid].t), net.edges[eid].w)
				var off := hw - side - 1.6 if String(inc.type) == "accident" else hw - side * 0.5
				if String(inc.meta.get("role", "")) == "neige":
					off = hw + 1.2
				sc.anchor = p + droite * maxf(off, 1.0) + Vector3(0, 0.05, 0)
				sc.sol = p.y
		_:
			if bid >= 0 and urg.buildings != null and urg.buildings.buildings.has(bid):
				var b: Dictionary = urg.buildings.buildings[bid]
				var rect := urg.buildings._rect_of(b)
				var door := BuildingSystem.door_point(String(b.t), rect, int(b.r), float(b.get("a", 0.0)))
				var h := float(b.get("h", 0.0))
				var centre := BuildingSystem.rect_center(rect)
				var dehors := Vector3(door.x - centre.x, 0, door.z - centre.z)
				if dehors.length_squared() < 1e-4:
					dehors = Vector3.BACK
				dehors = dehors.normalized()
				sc.anchor = Vector3(door.x, h, door.z) + dehors * 1.6
				sc.sol = h
				sc.dir = dehors
				sc.droite = Vector3(-dehors.z, 0, dehors.x)
				sc.batiment = Vector3(centre.x, h, centre.z)
				sc.hauteur = BuildingCatalog.approx_height(String(b.t))
			elif not road.is_empty():
				sc.anchor = road.pos
				sc.sol = (road.pos as Vector3).y
	if String(inc.type) == "incendie" and not sc.has("batiment"):
		sc.batiment = pos
		sc.hauteur = 8.0


func _bid(inc: Dictionary) -> int:
	var meta: Dictionary = inc.meta
	return int(meta.get("bid", meta.get("batiment", -1)))


# --- Décors -----------------------------------------------------------------------------

func _accident(sc: Dictionary, inc: Dictionary) -> void:
	var root: Node3D = sc.root
	var a := _modele_voiture()
	var b := _modele_voiture()
	# Voiture A : l'avant enfoncé, en travers ; voiture B : touchée sur le côté.
	_poser_epave(sc, a, "avant", Vector3(-0.2, 0, -3.2), 0.45)
	_poser_epave(sc, b, "cote", Vector3(0.4, 0, 1.6), -1.25)
	var k := EvVisuels._kit()
	# Flaque d'huile et de liquide de refroidissement.
	k.box(-0.3, 0.0, -4.9, 1.8, 0.02, 1.3, HUILE)
	k.box(0.6, 0.0, -5.6, 0.9, 0.02, 0.7, HUILE)
	# Éclats de verre et morceaux de pare-chocs.
	for i in 22:
		var x := _rng.randf_range(-2.2, 2.4)
		var z := _rng.randf_range(-6.5, 3.0)
		var c := VERRE if i % 3 != 0 else (Color("2b2d42") if i % 2 == 0 else Color("8d99ae"))
		var sz := _rng.randf_range(0.08, 0.22) if c == VERRE else _rng.randf_range(0.2, 0.55)
		k.box(x, 0.0, z, sz, 0.03, sz * _rng.randf_range(0.4, 1.0), c)
	k.box(1.6, 0.0, -1.0, 1.3, 0.1, 0.25, Color("2b2d42"))
	k.box(-1.9, 0.0, 0.4, 0.5, 0.1, 0.45, Color("6c757d"))
	# Triangle de signalisation, posé en amont (on arrive par +Z).
	_triangle(k, 0.3, 24.0)
	root.add_child(EvVisuels._mesh_instance(k))
	# Le conducteur choqué au bord, au téléphone.
	var conducteur := _figure(-1, "", "telephone_debout")
	conducteur.position = Vector3(2.6, 0, -0.4)
	conducteur.rotation.y = -2.0
	root.add_child(conducteur)
	sc.voisin = conducteur
	# Un blessé allongé près de la voiture A.
	_blesse(sc, Vector3(-2.3, 0, -3.0), 1.4)


func _fosse(sc: Dictionary, _inc: Dictionary) -> void:
	var m := _modele_voiture()
	var ep := _poser_epave(sc, m, "avant", Vector3(0, -0.35, 0), 0.5)
	ep.rotation.x = -0.22
	ep.rotation.z = 0.32
	var k := EvVisuels._kit()
	_triangle(k, -1.0, 20.0)
	# Traces dans la neige jusqu'au fossé.
	for i in 6:
		k.box(-1.5 - i * 0.35, 0.0, 3.0 + i * 2.2, 0.35, 0.02, 2.0, Color("9aa5ad"))
	(sc.root as Node3D).add_child(EvVisuels._mesh_instance(k))
	var conducteur := _figure(-1, "", "telephone_debout")
	conducteur.position = Vector3(-2.6, 0.35, 1.5)
	conducteur.rotation.y = 2.4
	(sc.root as Node3D).add_child(conducteur)
	sc.voisin = conducteur


func _poubelle(sc: Dictionary) -> void:
	var k := EvVisuels._kit()
	# Conteneur roulant noirci, couvercle ouvert.
	k.box(0, 0.12, 0, 1.1, 1.0, 0.9, Color("2f3a2f"))
	k.box(0, 1.12, -0.45, 1.15, 0.06, 0.9, Color("1f241f"))
	k.box(-0.4, 0.0, 0.3, 0.2, 0.2, 0.2, Color("111111"))
	k.box(0.4, 0.0, 0.3, 0.2, 0.2, 0.2, Color("111111"))
	k.box(0.1, 0.0, 0.9, 1.6, 0.02, 1.2, Color("2a2622"))
	(sc.root as Node3D).add_child(EvVisuels._mesh_instance(k))
	var feu := EvVisuels.feu(Vector3(1.0, 1.2, 0.8))
	feu.name = "FeuPoubelle"
	feu.scale = Vector3.ONE * 0.35
	feu.position = Vector3(0, 0.6, 0)
	EvVisuels.regle_feu(feu, 0.8)
	(sc.root as Node3D).add_child(feu)
	sc.feu = feu


func _malaise(sc: Dictionary, inc: Dictionary) -> void:
	_blesse(sc, Vector3(0.6, 0, 0.4), 0.3, int(inc.meta.get("pid", -1)))
	var voisin := _figure(-1, "", "ausculter")
	voisin.position = Vector3(-0.5, 0, 0.6)
	voisin.rotation.y = PI * 0.5
	(sc.root as Node3D).add_child(voisin)
	sc.voisin = voisin


func _cambriolage(sc: Dictionary) -> void:
	var k := EvVisuels._kit()
	# Porte forcée (ouverte de travers) et vitre brisée.
	k.box(-1.0, 0.0, -1.55, 0.08, 2.1, 0.95, Color("6b4f3a"))
	for i in 14:
		k.box(_rng.randf_range(-1.6, 1.6), 0.0, _rng.randf_range(-1.4, 0.6), 0.12, 0.03, 0.08, VERRE)
	# Traces de pas boueuses qui s'éloignent.
	for i in 5:
		k.box(0.4 + (i % 2) * 0.25, 0.0, i * 0.8, 0.12, 0.015, 0.26, Color("3b2f25"))
	var mi := EvVisuels._mesh_instance(k)
	mi.rotation.y = 0.3
	(sc.root as Node3D).add_child(mi)


## Triangle de signalisation rouge et blanc, à (x, z) dans le repère des lieux.
static func _triangle(k: BlocMesh, x: float, z: float) -> void:
	var r := Color("d62839")
	k.box(x, 0.0, z, 0.06, 0.06, 0.5, Color("333333"))
	k.box(x - 0.2, 0.0, z, 0.06, 0.62, 0.06, r)
	k.box(x + 0.2, 0.0, z, 0.06, 0.62, 0.06, r)
	k.box(x, 0.0, z, 0.5, 0.06, 0.06, r)
	k.box(x, 0.58, z, 0.12, 0.08, 0.06, r)


func _blesse(sc: Dictionary, p: Vector3, yaw: float, pid := -1) -> void:
	var n: Node3D
	var pop := urg.population if urg != null else null
	if Silhouettes.disponible() and pop != null and pid >= 0 and pop.persons.has(pid):
		n = Silhouettes.pour_habitant(pop, pid)
		Silhouettes.poser(n, "couche")
	elif Silhouettes.disponible():
		n = Silhouettes.creer(Silhouettes.apparence(_rng.randi_range(1, 99999), _rng.randf_range(20.0, 80.0), "M" if _rng.randf() < 0.5 else "F"))
		Silhouettes.poser(n, "couche")
	else:
		n = Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = EvVisuels.random_person(_rng)
		mi.rotation.x = -PI * 0.5
		mi.position = Vector3(0, 0.12, 0)
		n.add_child(mi)
	n.name = "Blesse"
	n.position = p
	n.rotation.y = yaw
	(sc.root as Node3D).add_child(n)
	sc.blesse = n


# --- Voitures accidentées -----------------------------------------------------------------

func _modele_voiture() -> String:
	var tr: Traffic = urg.transport.traffic if urg != null and urg.transport != null else null
	for _i in 12:
		var m := tr.pick_model("route") if tr != null else ""
		if m == "":
			continue
		var t := VehicleCatalog.get_type(m)
		if String(t.get("shape", "")) in ["voiture", "ancienne"] and not t.has("urgence"):
			return m
	return "berline"


func _poser_epave(sc: Dictionary, model: String, choc: String, p: Vector3, yaw: float) -> Node3D:
	var paint := _rng.randi() % maxi(1, VehicleCatalog.paint_count(model))
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = epave(model, paint, choc)
	n.add_child(mi)
	(sc.root as Node3D).add_child(n)
	# Feux de détresse aux quatre coins.
	var t := VehicleCatalog.get_type(model)
	var L := float(t.get("L", 4.2))
	var W := float(t.get("W", 1.8))
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.12, 0.08)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var f := MeshInstance3D.new()
		f.mesh = box
		f.material_override = _glow()
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = Vector3(c.x * W * 0.4, 0.62, c.y * (L * 0.5 + 0.03))
		n.add_child(f)
		(sc.blink as Array).append(f)
	# Un filet de fumée sous le capot froissé.
	if choc == "avant":
		var fum := _fumee_capot()
		fum.position = Vector3(0, 0.9, -L * 0.42)
		n.add_child(fum)
	return n


## Maillage d'une voiture accidentée : la tôle enfoncée à l'avant ou sur le côté,
## assombrie là où elle a frotté.
static func epave(model: String, paint: int, choc: String) -> ArrayMesh:
	var key := "%s:%d:%s" % [model, paint, choc]
	if _epaves.has(key):
		return _epaves[key]
	var src := VehicleCatalog.build_mesh(model, paint, EvVisuels.material())
	var aabb := src.get_aabb()
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols = arr[Mesh.ARRAY_COLOR]
		for i in v.size():
			var p := v[i]
			var k := 0.0
			if choc == "avant":
				# Les 90 premiers cm de l'avant : écrasés, capot relevé au milieu.
				var d := p.z - aabb.position.z
				k = clampf(1.0 - d / 0.95, 0.0, 1.0)
				p.z += k * 0.5
				p.y += k * (0.12 - absf(p.x) * 0.12) - k * 0.08 * float(p.y < 0.4)
				p.x *= 1.0 - 0.08 * k
			elif choc == "cote":
				var d2 := (aabb.position.x + aabb.size.x) - p.x
				var mid := 1.0 - clampf(absf(p.z - aabb.get_center().z) / 1.5, 0.0, 1.0)
				k = clampf(1.0 - d2 / 0.4, 0.0, 1.0) * mid
				p.x -= k * 0.32
				p.y -= k * 0.04
			v[i] = p
			if k > 0.0 and cols is PackedColorArray and i < (cols as PackedColorArray).size():
				var c: Color = cols[i]
				cols[i] = c.darkened(0.35 * k)
		arr[Mesh.ARRAY_VERTEX] = v
		if cols is PackedColorArray:
			arr[Mesh.ARRAY_COLOR] = cols
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, src.surface_get_material(si))
	_epaves[key] = out
	return out


static func _glow() -> StandardMaterial3D:
	if _mat_glow == null:
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.albedo_color = ORANGE
		_mat_glow.emission_enabled = true
		_mat_glow.emission = ORANGE
		_mat_glow.emission_energy_multiplier = 2.5
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _mat_glow


func _fumee_capot() -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.name = "Fumee"
	g.amount = 14
	g.lifetime = 3.0
	g.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0.3, 0.4, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.85, 0.85, 0.55))
	ramp.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = EvVisuels._particle_material(Color(1, 1, 1), false)
	g.draw_pass_1 = q
	return g


# --- Équipages ------------------------------------------------------------------------------

## Tenue par rôle (et modèle) d'un véhicule de secours.
static func tenue(role: String, base: String) -> String:
	match role:
		"pompiers": return "pompier"
		"police": return "policier"
		"ambulance": return "pompier" if base == "vsav" else "infirmier"
	return ""


## Une figurine (métier, geste). geste "telephone_debout" : debout au téléphone.
func _figure(pid: int, met: String, geste: String) -> Figurine:
	var f := Figurine.creer(pid if pid >= 0 else _rng.randi_range(1, 9999), met)
	f.regler("conseiller" if geste == "telephone_debout" else geste)
	f.set_meta("geste", geste)
	return f


## Qui fait quoi pour un véhicule sur place : [[geste, position locale, regard local], …].
func _postes(sc: Dictionary, role: String, rang: int) -> Array:
	var kind := String(sc.kind)
	var cote := -1.0 if rang % 2 == 0 else 1.0
	match role:
		"pompiers":
			if kind in ["incendie", "feu_poubelle"]:
				return [["lance", Vector3(cote * (1.5 + rang), 0, 5.5 + rang), Vector3.ZERO], ["lance", Vector3(-cote * 2.5, 0, 7.0 + rang), Vector3.ZERO]]
			if kind == "arbre":
				return [["tronconner", Vector3(0.6, 0, 1.4), Vector3.ZERO], ["surveiller", Vector3(-2.0, 0, 4.0), Vector3(0, 0, 12)]]
			if kind == "accident":
				return [["ausculter", Vector3(1.0, 0, -2.6), Vector3(-0.2, 0, -3.2)], ["surveiller", Vector3(-1.4, 0, 1.5), Vector3.ZERO]]
			return [["surveiller", Vector3(cote * 2.0, 0, 3.0), Vector3.ZERO], ["surveiller", Vector3(-cote * 3.0, 0, 4.0), Vector3.ZERO]]
		"ambulance":
			var b: Vector3 = (sc.blesse as Node3D).position if sc.blesse != null and is_instance_valid(sc.blesse) else Vector3(0, 0, 1.5)
			return [["soigner", b + Vector3(-0.9, 0, 0.0), b], ["ausculter", b + Vector3(0.9, 0, 0.4), b]]
		"police":
			if kind == "manifestation":
				return [["surveiller", Vector3(cote * 3.0, 0, 6.0 + rang * 2.0), Vector3(0, 0, -20)], ["surveiller", Vector3(-cote * 1.5, 0, 6.0 + rang * 2.0), Vector3(0, 0, -20)]]
			# Un agent garde le cordon, l'autre règle la circulation en amont.
			return [["surveiller", Vector3(2.0, 0, 3.8 + rang), Vector3.ZERO], ["perfuser", Vector3(-1.2, 0, 16.0 + rang * 3.0), Vector3(0, 0, 40)]]
	return []


## Met les équipages en accord avec les véhicules sur place (appelé 4 fois par seconde).
func _sync(id: int, sc: Dictionary, inc: Dictionary) -> void:
	var la := {}
	var rangs := {}
	for u in inc.units:
		var uid := int(u.get("uid", 0))
		var phase := String(u.get("phase", ""))
		if phase != "sur_place" or uid == 0:
			continue
		la[uid] = true
		var role := String(u.role)
		rangs[role] = int(rangs.get(role, -1)) + 1
		if not (sc.equipes as Dictionary).has(uid):
			_descendre(sc, inc, u, int(rangs[role]))
	for uid in (sc.equipes as Dictionary).keys():
		if not la.has(uid):
			_remonter(sc, int(uid))
	# Ambulance repartie avec le blessé (ou le service fait) : il n'est plus là.
	if bool(inc.done.get("ambulance", false)) and sc.blesse != null:
		if is_instance_valid(sc.blesse):
			(sc.blesse as Node).queue_free()
		sc.blesse = null
		if sc.has("brancard") and is_instance_valid(sc.brancard):
			(sc.brancard as Node).queue_free()
	# Pompiers sur place : le feu de poubelle baisse.
	if sc.has("feu") and is_instance_valid(sc.feu) and inc.arrived.has("pompiers"):
		var flammes := (sc.feu as Node3D).get_node_or_null("Flammes") as GPUParticles3D
		if flammes != null:
			flammes.amount_ratio = maxf(0.05, flammes.amount_ratio - 0.03)
		var fumee := (sc.feu as Node3D).get_node_or_null("Fumee") as GPUParticles3D
		if fumee != null:
			fumee.amount_ratio = maxf(0.15, fumee.amount_ratio - 0.03)
		if bool(inc.done.get("pompiers", false)):
			EvVisuels.fumee_seule(sc.feu)


func _local(sc: Dictionary, p: Vector3) -> Vector3:
	return (sc.root as Node3D).transform.affine_inverse() * p


func _descendre(sc: Dictionary, inc: Dictionary, u: Dictionary, rang: int) -> void:
	var role := String(u.role)
	var postes := _postes(sc, role, rang)
	var depart := Vector3(0, 0, 8)
	if urg != null and urg.transport != null and not (u.v as Dictionary).is_empty():
		depart = _local(sc, urg.transport.traffic.vehicle_position(u.v))
		depart.y = 0.0
	var eq := {"figs": [], "extras": []}
	var root: Node3D = sc.root
	for i in postes.size():
		var poste: Array = postes[i]
		var f := _figure(-1, tenue(role, String(u.base)), String(poste[0]))
		f.regler("surveiller")
		f.position = depart + Vector3(0.8 * (i * 2 - 1), 0, 0)
		root.add_child(f)
		f.set_meta("but", poste[1])
		f.set_meta("regard", poste[2])
		f.set_meta("arrive", false)
		(eq.figs as Array).append(f)
		if String(poste[0]) == "lance":
			_lance(sc, eq, f, poste[1], depart)
	if role == "ambulance" and sc.blesse != null and is_instance_valid(sc.blesse) and not sc.has("brancard"):
		var br := _brancard()
		br.position = (sc.blesse as Node3D).position + Vector3(0, 0, 1.3)
		br.rotation.y = (sc.blesse as Node3D).rotation.y
		root.add_child(br)
		sc.brancard = br
	if role == "police" and sc.cordon == null and String(sc.kind) != "manifestation":
		sc.cordon = _cordon(String(sc.kind))
		root.add_child(sc.cordon)
	# Le voisin ou le conducteur s'écarte quand les secours prennent le relais.
	if sc.voisin != null and is_instance_valid(sc.voisin) and role != "police":
		(sc.voisin as Node3D).position += Vector3(2.0, 0, 1.0)
		(sc.voisin as Figurine).regler("conseiller")
	sc.equipes[int(u.uid)] = eq


func _remonter(sc: Dictionary, uid: int) -> void:
	var eq: Dictionary = sc.equipes[uid]
	for f in eq.figs:
		if is_instance_valid(f):
			(f as Node).queue_free()
	for x in eq.extras:
		if is_instance_valid(x):
			(x as Node).queue_free()
	sc.equipes.erase(uid)


## Lance à incendie : tuyau au sol jusqu'au camion, jet d'eau vers le feu.
func _lance(sc: Dictionary, eq: Dictionary, f: Figurine, poste: Vector3, camion: Vector3) -> void:
	var root: Node3D = sc.root
	var a := Vector3(camion.x, 0, camion.z)
	var b := Vector3(poste.x, 0, poste.z)
	var d := b - a
	if d.length() > 0.5:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 0.06, d.length())
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("e9d8a6")
		mi.material_override = m
		mi.position = (a + b) * 0.5 + Vector3(0, 0.03, 0)
		mi.basis = Basis.looking_at(d.normalized(), Vector3.UP)
		root.add_child(mi)
		(eq.extras as Array).append(mi)
	# Cible : le bâtiment en feu (ou la poubelle, au centre des lieux).
	var cible := Vector3.ZERO + Vector3(0, 0.8, 0)
	if sc.has("batiment"):
		cible = _local(sc, sc.batiment as Vector3) + Vector3(0, float(sc.get("hauteur", 8.0)) * 0.55, 0)
	var jet := _jet()
	var bec := poste + Vector3(0, 1.25, 0)
	var vers := cible - bec
	jet.position = bec
	var horiz := Vector3(vers.x, 0, vers.z)
	var dist := maxf(horiz.length(), 1.0)
	var pm := jet.process_material as ParticleProcessMaterial
	# Vitesse et angle pour retomber sur la cible (portée d'une lance : ~ 25 m).
	var v := clampf(sqrt(dist * 9.8) * 1.05, 6.0, 22.0)
	pm.direction = (horiz.normalized() + Vector3(0, clampf((vers.y + 0.5 * 9.8 * pow(dist / v, 2)) / dist, -0.3, 1.2), 0)).normalized()
	pm.initial_velocity_min = v * 0.95
	pm.initial_velocity_max = v * 1.05
	jet.lifetime = clampf(dist / v * 1.3, 0.6, 3.0)
	jet.set_meta("fig", f)
	root.add_child(jet)
	(eq.extras as Array).append(jet)
	f.set_meta("regard", cible)


func _jet() -> GPUParticles3D:
	if _mat_eau == null:
		_mat_eau = EvVisuels._particle_material(Color(0.8, 0.92, 1.0, 0.85), false)
	var g := GPUParticles3D.new()
	g.name = "Jet"
	g.amount = 90
	g.lifetime = 1.5
	g.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 40, 80))
	g.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.spread = 3.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.25
	pm.scale_max = 0.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.2))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	q.material = _mat_eau
	g.draw_pass_1 = q
	return g


static func _brancard() -> MeshInstance3D:
	var k := EvVisuels._kit()
	for x in [-0.25, 0.25]:
		for z in [-0.85, 0.85]:
			k.box(x, 0.0, z, 0.05, 0.62, 0.05, Color("9aa0a6"))
	k.box(0, 0.62, 0, 0.6, 0.06, 1.95, Color("9aa0a6"))
	k.box(0, 0.68, 0, 0.56, 0.1, 1.85, Color("f8f9fa"))
	k.box(0, 0.78, -0.75, 0.4, 0.08, 0.3, Color("f8f9fa"))
	k.box(0, 0.73, 0.1, 0.56, 0.05, 1.0, Color("e76f51"))
	return EvVisuels._mesh_instance(k)


## Cordon de police : poteaux, rubalise rouge et blanche, cônes.
static func _cordon(kind: String) -> MeshInstance3D:
	var k := EvVisuels._kit()
	var w := 4.2 if kind == "accident" else 3.2
	var z0 := -8.0 if kind == "accident" else -2.6
	var z1 := 4.5 if kind == "accident" else 2.4
	var pts := [Vector2(-w, z0), Vector2(w, z0), Vector2(w, z1), Vector2(-w, z1)]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 4]
		k.box(a.x, 0.0, a.y, 0.08, 1.0, 0.08, Color("dddddd"))
		var n := int(ceil(a.distance_to(b) / 0.6))
		for j in n:
			var p := a.lerp(b, (j + 0.5) / n)
			var horiz := absf(b.x - a.x) > absf(b.y - a.y)
			var seg := a.distance_to(b) / n
			var col := Color("d62839") if j % 2 == 0 else Color("f8f9fa")
			if horiz:
				k.box(p.x, 0.92, p.y, seg, 0.07, 0.03, col)
			else:
				k.box(p.x, 0.92, p.y, 0.03, 0.07, seg, col)
	for z in [z1 + 2.0, z1 + 4.0, z1 + 6.0]:
		k.cylinder(-1.0, 0.0, z, 0.24, 0.04, 0.7, 6, ORANGE)
		k.box(-1.0, 0.0, z, 0.5, 0.04, 0.5, Color("222222"))
	return EvVisuels._mesh_instance(k)


# --- Animation ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if urg == null:
		return
	_temps += delta
	_acc += delta
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if _acc >= PAS:
		_acc = 0.0
		for id in scenes.keys():
			if urg.incidents.has(id):
				_sync(int(id), scenes[id], urg.incidents[id])
	var clign := fmod(_temps, 0.9) < 0.45
	for id in scenes:
		var sc: Dictionary = scenes[id]
		var root: Node3D = sc.root
		var proche := cam == null or cam.global_position.distance_to(root.global_position) < VUE
		root.visible = proche
		if not proche:
			continue
		for f in sc.blink:
			(f as Node3D).visible = clign
		for f in [sc.voisin, sc.blesse]:
			if f is Figurine and is_instance_valid(f):
				(f as Figurine).animer(_temps)
		for uid in sc.equipes:
			var eq: Dictionary = sc.equipes[uid]
			for f in eq.figs:
				if is_instance_valid(f):
					_marcher(f as Figurine, delta)
			for x in eq.extras:
				if x is GPUParticles3D and is_instance_valid(x):
					var fig: Figurine = x.get_meta("fig")
					(x as GPUParticles3D).emitting = is_instance_valid(fig) and bool(fig.get_meta("arrive", false))


## L'équipier marche jusqu'à son poste, puis se tourne et fait son geste.
func _marcher(f: Figurine, delta: float) -> void:
	var but: Vector3 = f.get_meta("but")
	var d := but - f.position
	d.y = 0.0
	if not bool(f.get_meta("arrive", false)):
		var pas := 2.2 * delta
		if d.length() <= pas:
			f.position = Vector3(but.x, f.position.y, but.z)
			f.set_meta("arrive", true)
			f.regler(String(f.get_meta("geste")))
			var r: Vector3 = f.get_meta("regard")
			var vers := r - f.position
			vers.y = 0.0
			if vers.length_squared() > 1e-4:
				f.rotation.y = atan2(vers.x, vers.z)
		else:
			f.position += d.normalized() * pas
			f.rotation.y = atan2(d.x, d.z)
	f.animer(_temps)
