class_name CollisionsSol
extends Node3D
## Collisions physiques autour du personnage, créées à la demande :
## - relief : un HeightMapShape3D par bloc de 32 × 32 m (altitude de chaque case,
##   modifications du joueur et terrassements des voies compris) ;
## - voies : la chaussée de chaque tronçon (routes, rail, chemins, ponts avec
##   parapets). Les tunnels ne sont pas encore praticables à pied.
## Tout autre objet qui a sa propre collision (bâtiments…) arrête aussi le
## personnage : rien à faire ici.

const BLOC := 32
## Rayon autour du point suivi dans lequel le relief a des collisions (m).
@export var rayon := 80.0
## Nombre maximal de blocs construits par image (pour ne pas saccader).
@export var blocs_par_image := 3

var world: TerrainWorld
var network: TransportNetwork
## Point autour duquel on crée les collisions (le personnage).
var suivi: Node3D

var blocs: Dictionary = {} # Vector2i -> StaticBody3D
var _sales: Dictionary = {} # blocs à refaire
var _voies: Dictionary = {} # id de tronçon -> StaticBody3D
var _voies_parent: Node3D


func setup(w: TerrainWorld, net: TransportNetwork, cible: Node3D) -> void:
	world = w
	network = net
	suivi = cible
	_voies_parent = Node3D.new()
	_voies_parent.name = "Voies"
	add_child(_voies_parent)
	world.chunk_rebuilt.connect(_on_chunk_rebuilt)
	world.origin_changed.connect(func(_la: float, _lo: float) -> void: vider())
	if network:
		network.changed.connect(_reconstruire_voies)
		_reconstruire_voies()


func vider() -> void:
	for k in blocs:
		(blocs[k] as Node).queue_free()
	blocs.clear()
	_sales.clear()


## Vrai si le relief sous ce point a déjà sa collision.
func pret_a(p: Vector3) -> bool:
	return blocs.has(_bloc_de(p.x, p.z))


func _bloc_de(x: float, z: float) -> Vector2i:
	# Un bloc couvre les centres de cases de x0 + 0,5 à x0 + 32,5.
	return Vector2i(floori((x - 0.5) / BLOC), floori((z - 0.5) / BLOC))


func _physics_process(_delta: float) -> void:
	if world == null or suivi == null or not is_processing():
		return
	mettre_a_jour(suivi.global_position, blocs_par_image)


## Crée les blocs manquants autour de p (au plus `budget`), libère ceux trop loin.
func mettre_a_jour(p: Vector3, budget: int) -> void:
	var c := _bloc_de(p.x, p.z)
	var r := ceili(rayon / BLOC)
	var voulus: Array[Vector2i] = []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := c + Vector2i(dx, dz)
			if _distance(k, p) <= rayon and (not blocs.has(k) or _sales.has(k)):
				voulus.append(k)
	voulus.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _distance(a, p) < _distance(b, p))
	var faits := 0
	for k in voulus:
		if faits >= budget:
			break
		if _construire(k):
			faits += 1
	for k in blocs.keys():
		if _distance(k, p) > rayon + BLOC * 1.5:
			(blocs[k] as Node).queue_free()
			blocs.erase(k)
			_sales.erase(k)


func _distance(k: Vector2i, p: Vector3) -> float:
	var mid := Vector2((k.x + 0.5) * BLOC + 0.5, (k.y + 0.5) * BLOC + 0.5)
	return maxf(0.0, mid.distance_to(Vector2(p.x, p.z)) - BLOC * 0.7)


## Construit la collision d'un bloc ; faux si le relief n'est pas encore chargé.
func _construire(k: Vector2i) -> bool:
	var n := BLOC + 1
	var data := PackedFloat32Array()
	data.resize(n * n)
	var x0 := k.x * BLOC
	var z0 := k.y * BLOC
	for j in n:
		for i in n:
			var h := world.cell_height(Vector2i(x0 + i, z0 + j))
			if is_nan(h):
				return false
			data[i + j * n] = h
	var forme := HeightMapShape3D.new()
	forme.map_width = n
	forme.map_depth = n
	forme.map_data = data
	var corps: StaticBody3D = blocs.get(k)
	if corps == null:
		corps = StaticBody3D.new()
		corps.name = "Relief_%d_%d" % [k.x, k.y]
		var cs := CollisionShape3D.new()
		corps.add_child(cs)
		add_child(corps)
		blocs[k] = corps
	# La forme est centrée : les sommets vont des centres de cases x0 + 0,5 à x0 + 32,5.
	corps.position = Vector3(x0 + 0.5 + BLOC * 0.5, 0.0, z0 + 0.5 + BLOC * 0.5)
	(corps.get_child(0) as CollisionShape3D).shape = forme
	_sales.erase(k)
	return true


func _on_chunk_rebuilt(k: Vector2i) -> void:
	# Le bloc d'affichage (64 m) a changé : on refait les blocs de collision qui le touchent.
	var cs := world.chunk_size
	var a := _bloc_de(k.x * cs - 1.0, k.y * cs - 1.0)
	var b := _bloc_de((k.x + 1) * cs + 1.0, (k.y + 1) * cs + 1.0)
	for bx in range(a.x, b.x + 1):
		for bz in range(a.y, b.y + 1):
			var q := Vector2i(bx, bz)
			if blocs.has(q):
				_sales[q] = true


# --- Voies ------------------------------------------------------------------------

func _reconstruire_voies() -> void:
	for id in _voies.keys():
		# Tronçon disparu, ou remplacé (chargement d'une sauvegarde) : on le refait.
		if not network.edges.has(id) or not is_same((_voies[id] as Node).get_meta("e"), network.edges[id]):
			(_voies[id] as Node).queue_free()
			_voies.erase(id)
	for id in network.edges:
		if _voies.has(id):
			continue
		var e: Dictionary = network.edges[id]
		var faces := faces_voie(e.t, e.pts, e.st)
		var corps := StaticBody3D.new()
		corps.name = "Voie_%d" % id
		corps.set_meta("e", e)
		if faces.size() > 0:
			var forme := ConcavePolygonShape3D.new()
			forme.backface_collision = true
			forme.set_faces(faces)
			var cs := CollisionShape3D.new()
			cs.shape = forme
			corps.add_child(cs)
		_voies_parent.add_child(corps)
		_voies[id] = corps


## Triangles de la surface d'une voie (et des parapets des ponts).
static func faces_voie(type_id: String, pts: PackedVector3Array, st: PackedByteArray) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var ty := TransportTypes.get_type(type_id)
	if ty.is_empty() or int(ty.mode) == TransportTypes.Mode.WATER:
		return faces
	var hw := float(ty.width) * 0.5
	var dessus := 0.12 if int(ty.mode) == TransportTypes.Mode.RAIL else 0.08
	var right := TransportView._rights(pts)
	var S := TransportTypes.Struct
	for i in pts.size() - 1:
		if st[i] == S.TUNNEL or st[i + 1] == S.TUNNEL:
			continue
		var up := Vector3(0.0, dessus, 0.0)
		var a := pts[i] + up
		var b := pts[i + 1] + up
		_quad(faces, a - right[i] * hw, b - right[i + 1] * hw, b + right[i + 1] * hw, a + right[i] * hw)
		if st[i] == S.BRIDGE or st[i + 1] == S.BRIDGE:
			# Parapets de 0,9 m : on ne tombe pas du pont.
			var h := Vector3(0.0, 0.9, 0.0)
			for s in [-1.0, 1.0]:
				var pa: Vector3 = a + right[i] * hw * s
				var pb: Vector3 = b + right[i + 1] * hw * s
				_quad(faces, pa, pb, pb + h, pa + h)
	return faces


static func _quad(f: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	f.append_array([a, b, c, a, c, d])
