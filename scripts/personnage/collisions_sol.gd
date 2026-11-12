class_name CollisionsSol
extends Node3D
## Collisions physiques autour du personnage, créées à la demande :
## - relief : un HeightMapShape3D par bloc de 32 × 32 m (altitude de chaque case,
##   modifications du joueur et terrassements des voies compris) ;
## - arbres : un tronc (cylindre) par arbre du bloc ;
## - voies : la chaussée de chaque tronçon (routes, rail, chemins, ponts avec
##   parapets) ;
## - tunnels : le relief est percé au-dessus du tracé, un tube (sol, murs, voûte)
##   le remplace et un couvercle garde le dessus de la colline praticable ;
## - véhicules proches : une boîte qui suit chaque voiture, train, vélo, bateau…
## Tout autre objet qui a sa propre collision (bâtiments, blocs…) arrête aussi le
## personnage : rien à faire ici.

const BLOC := 32
## Rayon autour du point suivi dans lequel le relief a des collisions (m).
@export var rayon := 80.0
## Nombre maximal de blocs construits par image (pour ne pas saccader).
@export var blocs_par_image := 3
## Rayon dans lequel les véhicules ont une collision (m).
@export var rayon_vehicules := 40.0

## Hauteur libre des tunnels (m) : un peu sous le haut du portail affiché.
const HAUTEUR_TUNNEL := 6.0
const HAUTEUR_TUNNEL_CHEMIN := 3.0
## Valeur de « trou » d'un HeightMapShape3D.
const TROU := 3.4028234663852886e38

var world: TerrainWorld
var network: TransportNetwork
var traffic: Traffic
## Point autour duquel on crée les collisions (le personnage).
var suivi: Node3D

var blocs: Dictionary = {} # Vector2i -> StaticBody3D
var _sales: Dictionary = {} # blocs à refaire
var _voies: Dictionary = {} # id de tronçon -> StaticBody3D
var _voies_parent: Node3D
## Cases percées au-dessus d'un tunnel : Vector2i -> altitude de la voûte (m).
var trous: Dictionary = {}
var _vehicules: Array[AnimatableBody3D] = []
var _materiau_tunnel: StandardMaterial3D


func setup(w: TerrainWorld, net: TransportNetwork, cible: Node3D, trafic: Traffic = null) -> void:
	world = w
	network = net
	traffic = trafic
	suivi = cible
	_materiau_tunnel = StandardMaterial3D.new()
	_materiau_tunnel.vertex_color_use_as_albedo = true
	_materiau_tunnel.vertex_color_is_srgb = true
	_materiau_tunnel.roughness = 0.95
	_materiau_tunnel.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	if world == null or suivi == null:
		return
	mettre_a_jour(suivi.global_position, blocs_par_image)
	suivre_vehicules(suivi.global_position)


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
	# Les blocs manquants d'abord (sans eux on tomberait), puis ceux à refaire ; les plus proches en premier.
	voulus.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ma := blocs.has(a)
		var mb := blocs.has(b)
		if ma != mb:
			return mb
		return _distance(a, p) < _distance(b, p))
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
	var couvercle := PackedVector3Array()
	for j in n:
		for i in n:
			var c := Vector2i(x0 + i, z0 + j)
			var h := world.cell_height(c)
			if is_nan(h):
				return false
			data[i + j * n] = TROU if trous.has(c) else h
			# Couvercle au-dessus des tunnels : la colline reste praticable par-dessus.
			var voute := _voute_pres(c)
			if not is_nan(voute) and h > voute + 0.3:
				_quad(couvercle, Vector3(c.x, h, c.y), Vector3(c.x + 1, h, c.y),
					Vector3(c.x + 1, h, c.y + 1), Vector3(c.x, h, c.y + 1))
	var forme := HeightMapShape3D.new()
	forme.map_width = n
	forme.map_depth = n
	forme.map_data = data
	var corps: StaticBody3D = blocs.get(k)
	if corps == null:
		corps = StaticBody3D.new()
		corps.name = "Relief_%d_%d" % [k.x, k.y]
		add_child(corps)
		blocs[k] = corps
	for child in corps.get_children():
		corps.remove_child(child)
		child.queue_free()
	# La forme est centrée : les sommets vont des centres de cases x0 + 0,5 à x0 + 32,5.
	var centre := Vector3(x0 + 0.5 + BLOC * 0.5, 0.0, z0 + 0.5 + BLOC * 0.5)
	corps.position = centre
	var cs := CollisionShape3D.new()
	cs.shape = forme
	corps.add_child(cs)
	if couvercle.size() > 0:
		var fc := ConcavePolygonShape3D.new()
		fc.backface_collision = true
		fc.set_faces(couvercle)
		var cc := CollisionShape3D.new()
		cc.shape = fc
		cc.position = -centre
		corps.add_child(cc)
	_ajouter_arbres(corps, Rect2(x0 + 0.5, z0 + 0.5, BLOC, BLOC))
	_sales.erase(k)
	return true


## Altitude de la voûte d'un tunnel sous cette case ou une voisine (NAN si aucun).
func _voute_pres(c: Vector2i) -> float:
	if trous.is_empty():
		return NAN
	var v := NAN
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var q := c + Vector2i(dx, dz)
			if trous.has(q):
				v = float(trous[q]) if is_nan(v) else minf(v, float(trous[q]))
	return v


## Un tronc par arbre affiché dans le rectangle (on passe à travers les buissons).
func _ajouter_arbres(corps: StaticBody3D, zone: Rect2) -> void:
	var cs := world.chunk_size
	var a := Vector2i(floori(zone.position.x / cs), floori(zone.position.y / cs))
	var b := Vector2i(floori(zone.end.x / cs), floori(zone.end.y / cs))
	for kx in range(a.x, b.x + 1):
		for kz in range(a.y, b.y + 1):
			var mi: Node3D = world.chunks.get(Vector2i(kx, kz))
			if mi == null:
				continue
			if not mi.has_meta("arbres"):
				continue
			var arbres: Array = mi.get_meta("arbres")
			for t: Transform3D in arbres:
				var p := mi.position + t.origin
				if not zone.has_point(Vector2(p.x, p.z)):
					continue
				var echelle := t.basis.get_scale().x
				var tronc := CylinderShape3D.new()
				tronc.radius = 0.35 * echelle
				tronc.height = 2.6 * echelle
				var col := CollisionShape3D.new()
				col.shape = tronc
				# Les arbres (Plantes.gd) ont leur origine au pied du tronc.
				col.position = p - corps.position + Vector3(0.0, tronc.height * 0.5, 0.0)
				corps.add_child(col)


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
		var faces := faces_voie(e.t, float(e.get("width", 0.0)), e.pts, e.st)
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
		var tube := faces_tunnel(e.t, float(e.get("width", 0.0)), e.pts, e.st)
		if tube.size() > 0:
			var ft := ConcavePolygonShape3D.new()
			ft.backface_collision = true
			ft.set_faces(tube)
			var ct := CollisionShape3D.new()
			ct.shape = ft
			corps.add_child(ct)
			corps.add_child(_maillage_tunnel(e.t, tube))
		_voies_parent.add_child(corps)
		_voies[id] = corps
	_calculer_trous()


## Perce le relief au-dessus de chaque tunnel et refait les blocs concernés.
func _calculer_trous() -> void:
	var avant := trous
	trous = {}
	for id in network.edges:
		var e: Dictionary = network.edges[id]
		var pts: PackedVector3Array = e.pts
		var st: PackedByteArray = e.st
		var hw := _largeur(e.t, float(e.get("width", 0.0))) * 0.5 + 0.7
		var haut := _hauteur_tunnel(e.t)
		for i in pts.size() - 1:
			if st[i] != TransportTypes.Struct.TUNNEL and st[i + 1] != TransportTypes.Struct.TUNNEL:
				continue
			var a := pts[i]
			var b := pts[i + 1]
			var pas := maxi(1, ceili(a.distance_to(b) / 0.5))
			for m in pas + 1:
				var q := a.lerp(b, float(m) / pas)
				for cz in range(floori(q.z - hw), floori(q.z + hw) + 1):
					for cx in range(floori(q.x - hw), floori(q.x + hw) + 1):
						if Vector2(cx + 0.5 - q.x, cz + 0.5 - q.z).length() > hw:
							continue
						var c := Vector2i(cx, cz)
						var v := q.y + haut
						trous[c] = minf(v, float(trous.get(c, v)))
	if trous == avant:
		return
	for k in blocs:
		_sales[k] = true


static func _largeur(type_id: String, width: float) -> float:
	return width if width > 0.0 else TransportTypes.width_of(type_id, {})


static func _hauteur_tunnel(type_id: String) -> float:
	return HAUTEUR_TUNNEL_CHEMIN if TransportTypes.mode_of(type_id) == TransportTypes.Mode.PATH else HAUTEUR_TUNNEL


## Tube d'un tunnel : sol, deux murs et voûte, sur les tronçons en tunnel.
static func faces_tunnel(type_id: String, width: float, pts: PackedVector3Array, st: PackedByteArray) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var mode := TransportTypes.mode_of(type_id)
	if mode < 0 or mode == TransportTypes.Mode.WATER:
		return faces
	var hw := _largeur(type_id, width) * 0.5 + 0.4
	var haut := Vector3(0.0, _hauteur_tunnel(type_id), 0.0)
	var sol := Vector3(0.0, 0.08, 0.0)
	var right := TransportView._rights(pts)
	for i in pts.size() - 1:
		if st[i] != TransportTypes.Struct.TUNNEL and st[i + 1] != TransportTypes.Struct.TUNNEL:
			continue
		var al := pts[i] - right[i] * hw + sol
		var ar := pts[i] + right[i] * hw + sol
		var bl := pts[i + 1] - right[i + 1] * hw + sol
		var br := pts[i + 1] + right[i + 1] * hw + sol
		_quad(faces, al, bl, br, ar) # sol
		_quad(faces, al, bl, bl + haut, al + haut) # mur gauche
		_quad(faces, ar, br, br + haut, ar + haut) # mur droit
		_quad(faces, al + haut, bl + haut, br + haut, ar + haut) # voûte
	return faces


## Affichage de l'intérieur du tunnel (les faces du tube : sol, murs, voûte).
func _maillage_tunnel(type_id: String, faces: PackedVector3Array) -> MeshInstance3D:
	var sol := TransportView.ASPHALT if TransportTypes.mode_of(type_id) == TransportTypes.Mode.ROAD else TransportView.BALLAST
	if TransportTypes.mode_of(type_id) == TransportTypes.Mode.PATH:
		sol = Color("d9c49a")
	var cols := PackedColorArray()
	var normals := PackedVector3Array()
	cols.resize(faces.size())
	normals.resize(faces.size())
	for f in faces.size() / 6:
		var role := f % 4 # 0 sol, 1-2 murs, 3 voûte
		var col := sol if role == 0 else (TransportView.CONCRETE.darkened(0.25) if role < 3 else TransportView.CONCRETE.darkened(0.45))
		var nrm := (faces[f * 6 + 1] - faces[f * 6]).cross(faces[f * 6 + 2] - faces[f * 6]).normalized()
		for v in 6:
			cols[f * 6 + v] = col
			normals[f * 6 + v] = nrm
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Tunnel"
	mi.mesh = mesh
	mi.material_override = _materiau_tunnel
	return mi


# --- Véhicules ----------------------------------------------------------------------

## Une boîte de collision suit chaque véhicule (et wagon) proche du point p.
func suivre_vehicules(p: Vector3) -> void:
	var proches: Array[MeshInstance3D] = []
	if traffic != null and traffic.enabled:
		for v in traffic.vehicles:
			var morceaux: Array = [v.get("body")]
			morceaux.append_array(v.get("wagons", []))
			for m in morceaux:
				var mi := m as MeshInstance3D
				if mi == null or not is_instance_valid(mi) or not mi.visible or mi.mesh == null:
					continue
				if mi.global_position.distance_to(p) < rayon_vehicules:
					proches.append(mi)
	while _vehicules.size() < proches.size():
		var corps := AnimatableBody3D.new()
		corps.sync_to_physics = false
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		corps.add_child(cs)
		add_child(corps)
		_vehicules.append(corps)
	for n in _vehicules.size():
		var corps := _vehicules[n]
		var cs := corps.get_child(0) as CollisionShape3D
		if n >= proches.size():
			cs.disabled = true
			continue
		var mi := proches[n]
		var aabb := mi.mesh.get_aabb()
		(cs.shape as BoxShape3D).size = aabb.size
		cs.disabled = false
		cs.position = aabb.get_center()
		corps.global_transform = mi.global_transform


## Un véhicule qui roule sur le personnage l'écarte sur le côté (il ne le traverse pas).
func ecarter(perso: Personnage) -> void:
	var centre := perso.global_position + Vector3(0.0, Personnage.TAILLE * 0.5, 0.0)
	for corps in _vehicules:
		var cs := corps.get_child(0) as CollisionShape3D
		if cs.disabled:
			continue
		var demi := (cs.shape as BoxShape3D).size * 0.5
		var local := corps.global_transform.affine_inverse() * centre - cs.position
		var marge := Personnage.RAYON
		if absf(local.x) >= demi.x + marge or absf(local.z) >= demi.z + marge or absf(local.y) >= demi.y + Personnage.TAILLE * 0.5:
			continue
		if local.y > demi.y:
			continue # debout sur le véhicule
		var cote := 1.0 if local.x >= 0.0 else -1.0
		var pousse := demi.x + marge - absf(local.x) + 0.02
		var dir := corps.global_transform.basis.x.normalized() * cote
		dir.y = 0.0
		perso.global_position += dir.normalized() * pousse


func nb_vehicules_actifs() -> int:
	var c := 0
	for corps in _vehicules:
		if not (corps.get_child(0) as CollisionShape3D).disabled:
			c += 1
	return c


## Triangles de la surface d'une voie (et des parapets des ponts).
## width : largeur totale (m) ; 0 = largeur par défaut du type.
static func faces_voie(type_id: String, width: float, pts: PackedVector3Array, st: PackedByteArray) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var ty := TransportTypes.get_type(type_id)
	if ty.is_empty() or int(ty.mode) == TransportTypes.Mode.WATER:
		return faces
	if width <= 0.0:
		width = TransportTypes.width_of(type_id, {})
	var hw := width * 0.5
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
