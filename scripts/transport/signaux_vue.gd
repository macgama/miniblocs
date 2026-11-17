class_name SignauxVue
extends Node3D
## Signaux le long des voies ferrées, dessinés selon l'époque (Signalisation) :
##
## - disque (1830-1871) : poteau en bois et disque rouge tournant ; face à la
##   voie = arrêt, de profil = voie libre ;
## - sémaphore (1872-1934) : mât à bras rouge ; bras horizontal = arrêt, bras
##   incliné = voie libre ;
## - BAL (dès 1935) : mât, cible noire et feu rouge ou vert ;
## - TVM (LGV dès 1981) : repère bleu à triangle jaune, sans feu (la
##   signalisation est en cabine).
##
## Les signaux sont refaits quand le réseau ou l'époque change, et leurs états
## mis à jour quatre fois par seconde.

const PERIODE := 0.25
const RECALCUL := 3.0
## Au-delà, les signaux ne sont pas dessinés (m de la caméra).
const LOIN := 2500.0

var network: TransportNetwork
var signaux: Signalisation
var _items: Array = [] # {node, head, style, k, from, ouvert}
var _sales := true
var _t := 0.0
var _t_style := 0.0
var _style_vu := ""
var _mats: Dictionary = {}
var _meshes: Dictionary = {}


func setup(net: TransportNetwork, sg: Signalisation) -> void:
	network = net
	signaux = sg
	network.changed.connect(func() -> void: _sales = true)


func _process(delta: float) -> void:
	if network == null or signaux == null:
		return
	_t_style -= delta
	if _t_style <= 0.0:
		_t_style = RECALCUL
		var st := String(signaux.epoque().id) + ":%d" % signaux.blocs({"len": 6000.0})
		if st != _style_vu:
			_style_vu = st
			_sales = true
	if _sales:
		_sales = false
		rebuild()
	_t -= delta
	if _t > 0.0:
		return
	_t = PERIODE
	maj_etats()


## Nombre de signaux dessinés.
func count() -> int:
	return _items.size()


func rebuild() -> void:
	for it in _items:
		(it.node as Node).queue_free()
	_items.clear()
	if not signaux.actif:
		return
	for sd in signaux.liste():
		var eid := int(sd.eid)
		if not network.edges.has(eid):
			continue
		var e: Dictionary = network.edges[eid]
		var s := clampf(float(sd.s), 0.0, float(e.len))
		var p := network.point_at(eid, s)
		var t := network.tangent_at(eid, s) * float(sd.dir)
		var fwd := Vector3(t.x, 0, t.z)
		if fwd.length_squared() < 1e-6:
			continue
		fwd = fwd.normalized()
		var right := Vector3(-fwd.z, 0, fwd.x)
		var spacing := float(TransportTypes.get_type(e.t).get("spacing", 4.0))
		var lat := (spacing * 0.5 if int(sd.voies) == 2 else 0.0) + 2.6
		var n := Node3D.new()
		n.position = p + right * lat
		# +Z local vers le train qui arrive.
		n.basis = Basis.looking_at(fwd, Vector3.UP)
		add_child(n)
		var head := _build(n, String(sd.style))
		_items.append({"node": n, "head": head, "style": String(sd.style), "k": String(sd.k), "from": int(sd.from), "ouvert": null})
	maj_etats()


func maj_etats() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cp := cam.global_position if cam != null else Vector3.INF
	for it in _items:
		var n: Node3D = it.node
		if cp != Vector3.INF:
			n.visible = n.position.distance_to(cp) < LOIN
			if not n.visible:
				continue
		var o := signaux.ouvert(String(it.k), int(it.from))
		if it.ouvert != null and bool(it.ouvert) == o:
			continue
		it.ouvert = o
		_set_state(it, o)


## État d'un signal dessiné (tests) : true vert, false rouge, null inconnu.
func etat(i: int) -> Variant:
	return _items[i].ouvert if i < _items.size() else null


# --- Modèles ---------------------------------------------------------------------------------

func _mat(key: String, c: Color, glow := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.7
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var key := "b:%s" % size
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var key := "c:%s:%s" % [r, h]
	if not _meshes.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = h
		cm.radial_segments = 8
		cm.rings = 1
		_meshes[key] = cm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Construit le signal ; renvoie la partie qui change avec l'état.
func _build(n: Node3D, style: String) -> Node3D:
	var gris := _mat("gris", Color("5c6166"))
	var noir := _mat("noir", Color("1d1f22"))
	match style:
		"disque":
			_cyl(n, 0.09, 3.2, Vector3(0, 1.6, 0), _mat("bois", Color("6b4a2b")))
			var pivot := Node3D.new()
			pivot.position = Vector3(0, 3.0, 0.12)
			n.add_child(pivot)
			var disc := _cyl(pivot, 0.5, 0.05, Vector3.ZERO, _mat("rouge_mat", Color("c1272d")))
			disc.rotation = Vector3(PI * 0.5, 0, 0)
			_cyl(pivot, 0.12, 0.06, Vector3(0, 0, 0.01), _mat("blanc", Color("f2f2f2"))).rotation = Vector3(PI * 0.5, 0, 0)
			return pivot
		"semaphore":
			_cyl(n, 0.08, 6.0, Vector3(0, 3.0, 0), gris)
			_box(n, Vector3(0.5, 0.15, 0.5), Vector3(0, 0.08, 0), gris)
			var pivot := Node3D.new()
			pivot.position = Vector3(0, 5.4, 0.12)
			n.add_child(pivot)
			_box(pivot, Vector3(1.5, 0.28, 0.05), Vector3(-0.75, 0, 0), _mat("rouge_mat", Color("c1272d")))
			_box(pivot, Vector3(0.12, 0.3, 0.06), Vector3(-1.2, 0, 0.005), _mat("blanc", Color("f2f2f2")))
			return pivot
		"tvm":
			_cyl(n, 0.05, 1.6, Vector3(0, 0.8, 0), gris)
			_box(n, Vector3(0.55, 0.55, 0.04), Vector3(0, 1.75, 0.03), _mat("bleu", Color("1f4e9c")))
			_box(n, Vector3(0.28, 0.24, 0.05), Vector3(0, 1.72, 0.04), _mat("jaune", Color("f2c14e")))
			return null
	# BAL : mât, cible noire, feu.
	_cyl(n, 0.08, 4.2, Vector3(0, 2.1, 0), gris)
	_box(n, Vector3(0.5, 0.15, 0.5), Vector3(0, 0.08, 0), gris)
	_box(n, Vector3(0.55, 1.1, 0.18), Vector3(0, 4.4, 0.05), noir)
	_box(n, Vector3(0.62, 0.05, 0.3), Vector3(0, 4.97, 0.08), noir)
	var lamp := _box(n, Vector3(0.24, 0.24, 0.06), Vector3(0, 4.6, 0.16), _mat("rouge", Color("ff2a2a"), 0.9))
	return lamp


func _set_state(it: Dictionary, ouvert: bool) -> void:
	var h: Node3D = it.head
	if h == null:
		return
	match String(it.style):
		"disque":
			# De profil quand la voie est libre.
			h.rotation = Vector3(0, PI * 0.5 if ouvert else 0.0, 0)
		"semaphore":
			h.rotation = Vector3(0, 0, -0.8 if ouvert else 0.0)
		_:
			(h as MeshInstance3D).material_override = _mat("vert", Color("29e06a"), 0.9) if ouvert else _mat("rouge", Color("ff2a2a"), 0.9)
