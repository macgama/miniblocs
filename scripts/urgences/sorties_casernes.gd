class_name SortiesCasernes
extends Node3D
## Départs et retours visibles des véhicules de secours : la porte du garage
## de la caserne (de l'hôpital, du commissariat) se lève, le véhicule sort
## gyrophares allumés jusqu'à la route, puis prend la route ; au retour, il
## quitte la route, rentre au garage et la porte se referme.
##
## Le véhicule de la circulation (Traffic) attend pendant la sortie (clé
## « hold ») et il est caché ; une copie le remplace entre le garage et la
## route. Le temps est celui de la simulation (Urgences.step).

## Durée d'une sortie ou d'une rentrée (s de simulation) et ouverture de la porte.
const DUREE := 4.0
const PORTE := 1.0
const COULEUR_PORTE := {"pompiers": Color("c62828"), "police": Color("8d99ae"), "hopital": Color("e9ecef")}

var urg: Urgences
## Animations en cours : [{ghost, de, a, t, dur, v (véhicule de Traffic), bid, retour}].
var anims: Array = []
## Portes de garage : bid -> {node, panneau, h, ouvert (0 à 1), demandes}.
var portes: Dictionary = {}

var _blink := 0.0
static var _meshes: Dictionary = {}
static var _feux: Dictionary = {}


func _init() -> void:
	name = "SortiesCasernes"


## Le véhicule v vient de partir de la caserne bid : il sort du garage.
func sortie(bid: int, v: Dictionary) -> void:
	var g := _geometrie(bid)
	if g.is_empty() or v.is_empty():
		return
	var road: Vector3 = urg.transport.traffic.vehicle_position(v)
	v.hold = 1e9
	if v.has("body"):
		(v.body as Node3D).visible = false
	var ghost := _fantome(String(v.model))
	add_child(ghost)
	anims.append({"ghost": ghost, "pts": [g.dedans, g.porte, road], "t": -PORTE, "dur": DUREE, "v": v, "bid": bid, "retour": false})
	_porte(bid).demandes += 1


## Le véhicule rentre (il est déjà retiré de la circulation, à pos sur la route).
func rentree(bid: int, model: String, pos: Vector3) -> void:
	var g := _geometrie(bid)
	if g.is_empty():
		return
	var ghost := _fantome(model)
	add_child(ghost)
	anims.append({"ghost": ghost, "pts": [pos, g.porte, g.dedans], "t": -PORTE, "dur": DUREE, "v": {}, "bid": bid, "retour": true})
	_porte(bid).demandes += 1


func vider() -> void:
	for a in anims:
		_finir(a)
	anims.clear()
	for bid in portes:
		(portes[bid].node as Node).queue_free()
	portes.clear()


## Avance les animations de delta secondes de simulation.
func step(delta: float) -> void:
	_blink += delta
	var reste: Array = []
	for a in anims:
		a.t = float(a.t) + delta
		var ghost: Node3D = a.ghost
		var k := clampf(float(a.t) / float(a.dur), 0.0, 1.0)
		var pts: Array = a.pts
		# Deux segments : garage → porte, porte → route (ou l'inverse).
		var p: Vector3
		var dir: Vector3
		var k2 := smoothstep(0.0, 1.0, k)
		if k2 < 0.5:
			p = (pts[0] as Vector3).lerp(pts[1], k2 * 2.0)
			dir = (pts[1] as Vector3) - (pts[0] as Vector3)
		else:
			p = (pts[1] as Vector3).lerp(pts[2], (k2 - 0.5) * 2.0)
			dir = (pts[2] as Vector3) - (pts[1] as Vector3)
		dir.y = 0.0
		ghost.position = p + Vector3(0, 0.08, 0)
		if dir.length_squared() > 1e-4:
			ghost.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
		var on := fmod(_blink * 3.0, 2.0) < 1.0
		for i in ghost.get_child_count():
			var c := ghost.get_child(i)
			if c.has_meta("feu"):
				(c as Node3D).visible = (i % 2 == 0) == on
		if float(a.t) >= float(a.dur):
			_finir(a)
		else:
			reste.append(a)
	anims = reste
	# Portes : ouvertes tant qu'un véhicule passe, puis elles se referment.
	for bid in portes:
		var po: Dictionary = portes[bid]
		var cible := 1.0 if int(po.demandes) > 0 else 0.0
		po.ouvert = move_toward(float(po.ouvert), cible, delta / PORTE)
		var pan: Node3D = po.panneau
		pan.position.y = float(po.h) * 0.5 + float(po.ouvert) * float(po.h) * 0.92
		pan.scale.y = 1.0 - 0.85 * float(po.ouvert)


func _finir(a: Dictionary) -> void:
	if is_instance_valid(a.ghost):
		(a.ghost as Node).queue_free()
	var v: Dictionary = a.v
	if not v.is_empty():
		v.hold = 0.0
		if v.has("body") and is_instance_valid(v.body):
			(v.body as Node3D).visible = true
	if portes.has(int(a.bid)):
		portes[int(a.bid)].demandes = maxi(0, int(portes[int(a.bid)].demandes) - 1)


## Points du garage : {dedans, porte, normale, largeur, sol} ou {} si la caserne a disparu.
func _geometrie(bid: int) -> Dictionary:
	if urg == null or urg.buildings == null or not urg.buildings.buildings.has(bid) or not urg.stations.has(bid):
		return {}
	var b: Dictionary = urg.buildings.buildings[bid]
	var t := String(b.t)
	var rect := urg.buildings._rect_of(b)
	var n := BuildingSystem.front_dir(int(b.r)).rotated(Vector3.UP, float(b.get("a", 0.0)))
	var door: Vector3 = urg.stations[bid].get("door", BuildingSystem.door_point(t, rect, int(b.r), float(b.get("a", 0.0))))
	var h := float(b.get("h", 0.0))
	var facade := Vector3(door.x, h, door.z) - n * 0.5
	return {"dedans": facade - n * 6.0, "porte": facade + n * 1.5, "facade": facade, "n": n, "sol": h}


func _porte(bid: int) -> Dictionary:
	if portes.has(bid):
		return portes[bid]
	var g := _geometrie(bid)
	var node := Node3D.new()
	node.name = "Garage%d" % bid
	add_child(node)
	var n: Vector3 = g.n
	node.position = (g.facade as Vector3) + n * 0.06
	node.basis = Basis.looking_at(-n, Vector3.UP)
	var st := String(urg.stations[bid].t)
	var w := 4.2 if st == "pompiers" else 3.2
	var h := 4.0 if st == "pompiers" else 2.8
	var k := EvVisuels._kit()
	# Ouverture sombre et encadrement.
	k.box(0, 0.0, 0.0, w, h, 0.04, Color("1b1b1f"))
	k.box(-w * 0.5 - 0.15, 0.0, 0.03, 0.3, h + 0.3, 0.12, Color("d9d4c7"))
	k.box(w * 0.5 + 0.15, 0.0, 0.03, 0.3, h + 0.3, 0.12, Color("d9d4c7"))
	k.box(0, h, 0.03, w + 0.6, 0.3, 0.12, Color("d9d4c7"))
	node.add_child(EvVisuels._mesh_instance(k))
	# Panneau de la porte sectionnelle, qui se lève.
	var pk := EvVisuels._kit()
	var col: Color = COULEUR_PORTE.get(st, Color("adb5bd"))
	for i in 5:
		pk.box(0, -h * 0.5 + i * h / 5.0, 0.0, w, h / 5.0 - 0.05, 0.06, col if i % 2 == 0 else col.darkened(0.12))
	var pan := EvVisuels._mesh_instance(pk)
	pan.position = Vector3(0, h * 0.5, 0.06)
	node.add_child(pan)
	portes[bid] = {"node": node, "panneau": pan, "h": h, "ouvert": 0.0, "demandes": 0}
	return portes[bid]


## Copie d'un véhicule de secours, avec ses gyrophares qui clignotent.
func _fantome(model: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	if not _meshes.has(model):
		_meshes[model] = VehicleCatalog.build_mesh(model, 0, EvVisuels.material())
	mi.mesh = _meshes[model]
	root.add_child(mi)
	var t := VehicleCatalog.get_type(model)
	var box := BoxMesh.new()
	box.size = Vector3(0.38, 0.16, 0.26)
	for p in VehicleCatalog.beacons(t):
		var bp: Vector3 = p
		var c := VehicleCatalog.beacon_color(t, bp.x)
		if not _feux.has(c):
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 3.0
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_feux[c] = m
		var f := MeshInstance3D.new()
		f.mesh = box
		f.material_override = _feux[c]
		f.position = bp + Vector3(0, 0.02, 0)
		f.set_meta("feu", true)
		root.add_child(f)
	return root
