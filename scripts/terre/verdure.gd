class_name Verdure
extends Node3D
## Verdure des jardins : arbres, buissons et massifs de fleurs plantés tout seuls
## autour des maisons, immeubles, commerces, services et lieux de loisirs.
##
## Une ville sans arbres a l'air d'une maquette vide : ici chaque bâtiment reçoit
## quelques plantes de son climat (chênes et hêtres en zone tempérée, oliviers et
## pins parasols autour de la Méditerranée, palmiers sous les tropiques…),
## posées sur les cases libres autour de lui (ni voie, ni bâtiment, ni eau).
## Toujours les mêmes au même endroit (hasard tiré de la case), rien à sauvegarder.
##
## Mêmes modèles et même matériau que la végétation du terrain (Plantes) : les
## saisons, la neige, le vent et les feuilles d'automne s'appliquent tout seuls.
## Coût : quelques MultiMesh (un par espèce), refaits seulement quand un bâtiment
## ou une voie change, et seulement pour les bâtiments nouveaux.

## Verdure des jardins allumée (option du rendu cosy).
static var actif := true

## Densité des arbres : 0 légers, 1 entre-deux, 2 touffus.
static var densite := 1

## Catégories de bâtiments qui ont un jardin.
const CATS_JARDIN := ["logement", "commerce", "services", "loisirs"]
## Plantes par climat (Plantes.Climat) : [arbres, buissons, fleurs].
const PAR_CLIMAT := {
	0: [["bouleau", "epicea", "bouleau"], ["buisson", "saule_nain"], ["marguerites", "gentianes"]],
	1: [["chene", "hetre", "bouleau", "chene"], ["buisson", "buisson_fleuri", "buisson_fleuri"], ["coquelicots", "marguerites", "fleurs_jaunes", "lavande"]],
	2: [["olivier", "pin_parasol", "olivier"], ["buisson_fleuri", "genet", "buisson"], ["lavande", "lavande", "coquelicots", "fleurs_jaunes"]],
	3: [["palmier", "olivier", "chene"], ["buisson_fleuri", "agave", "buisson"], ["fleurs_jaunes", "coquelicots", "lavande"]],
	4: [["palmier", "tropical", "palmier"], ["buisson_fleuri", "fougere", "buisson"], ["fleurs_jaunes", "coquelicots"]],
}
## Arbres au plus près à cette distance (m) les uns des autres.
const ECART_ARBRES := 5.0
## Attente (s) après un changement avant de replanter.
const ATTENTE := 1.2

var buildings: BuildingSystem
var world: TerrainWorld
var climat := 1
## bid -> Array de [case, espèce, Transform3D, teinte].
var _jardins: Dictionary = {}
var _attente := -1.0
var _instances: Array[MultiMeshInstance3D] = []


func setup(bs: BuildingSystem, w: TerrainWorld) -> void:
	buildings = bs
	world = w
	climat = Plantes.climat(w.origin_lat, w.origin_lon)
	bs.changed.connect(_change)
	w.origin_changed.connect(func(a: float, o: float) -> void:
		climat = Plantes.climat(a, o)
		_jardins.clear()
		_change())
	_change()


func _change() -> void:
	_attente = ATTENTE


func _process(delta: float) -> void:
	if _attente < 0.0:
		return
	_attente -= delta
	if _attente <= 0.0:
		_attente = -1.0
		replanter()


## Fait pousser les jardins des nouveaux bâtiments et refait les MultiMesh.
func replanter() -> void:
	if buildings == null or world == null:
		return
	if not (actif and RenduCosy.actif):
		_jardins.clear()
		_poser()
		return
	for bid in _jardins.keys():
		if not buildings.buildings.has(bid):
			_jardins.erase(bid)
	var pris := {}
	for bid in _jardins:
		for p in _jardins[bid]:
			pris[p[0]] = true
	for bid: int in buildings.buildings:
		if _jardins.has(bid):
			continue
		var b: Dictionary = buildings.buildings[bid]
		var t := BuildingCatalog.get_type(String(b.t))
		if not CATS_JARDIN.has(String(t.get("cat", ""))):
			continue
		var plantes := jardin(b, pris)
		# Relief pas encore chargé : on réessaiera au prochain changement.
		if plantes.is_empty() and is_nan(world.cell_height(Vector2i(int(b.x), int(b.z)))):
			continue
		_jardins[bid] = plantes
	_poser()


## Case libre pour une plante : ni bâtiment, ni voie, ni eau, relief chargé.
func libre(c: Vector2i) -> bool:
	if buildings.occupancy.has(c):
		return false
	if world.tree_blocker.is_valid() and world.tree_blocker.call(c):
		return false
	var h := world.cell_height(c)
	if is_nan(h) or is_inf(h):
		return false
	if not is_nan(world.water_surface_at(c.x + 0.5, c.y + 0.5)):
		return false
	return true


## Les plantes d'un bâtiment : arbres dans le jardin (à 2 à 4 m des murs),
## buissons et fleurs au pied des murs (1 à 2 m).
func jardin(b: Dictionary, pris: Dictionary) -> Array:
	var choix: Array = PAR_CLIMAT.get(climat, PAR_CLIMAT[1])
	var rect := buildings._rect_of(b)
	var taille := rect.size.x + rect.size.y
	var n_arbres := clampi(taille / int([14, 10, 8][densite]), 1, int([2, 3, 5][densite]))
	var n_buissons := clampi(taille / 6, 2, 8)
	var n_fleurs := clampi(taille / 5, 2, 10)
	var res: Array = []
	var arbres: Array[Vector2] = []
	# Anneaux de cases autour du bâtiment, rangées dans un ordre tiré au hasard
	# (toujours le même pour la même case).
	for passe in [[2, 4, n_arbres, 0], [1, 2, n_buissons, 1], [1, 1, n_fleurs, 2]]:
		var cand: Array = []
		for d in range(int(passe[0]), int(passe[1]) + 1):
			var r := rect.grow(d)
			for x in range(r.position.x, r.end.x):
				cand.append(Vector2i(x, r.position.y))
				cand.append(Vector2i(x, r.end.y - 1))
			for z in range(r.position.y + 1, r.end.y - 1):
				cand.append(Vector2i(r.position.x, z))
				cand.append(Vector2i(r.end.x - 1, z))
		cand.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return hash(a * 31 + Vector2i(passe[3], 7)) < hash(c * 31 + Vector2i(passe[3], 7)))
		var poses := 0
		for c: Vector2i in cand:
			if poses >= int(passe[2]):
				break
			if pris.has(c) or not libre(c):
				continue
			var p2 := Vector2(c) + Vector2(0.5, 0.5)
			if passe[3] == 0:
				var trop_pres := false
				for a in arbres:
					if a.distance_to(p2) < ECART_ARBRES:
						trop_pres = true
						break
				# Pas devant la façade : loin des voies (on garde la vue sur la maison).
				if not trop_pres and world.tree_blocker.is_valid():
					var loin_voie: int = [3, 2, 1][densite]
					for dc in [Vector2i(loin_voie, 0), Vector2i(-loin_voie, 0), Vector2i(0, loin_voie), Vector2i(0, -loin_voie)]:
						if world.tree_blocker.call(c + dc):
							trop_pres = true
							break
				if trop_pres:
					continue
				arbres.append(p2)
			var r := absi(hash(c * 13 + Vector2i(3, 11)))
			var liste: Array = choix[int(passe[3])]
			var e := Plantes.id(String(liste[r % liste.size()]))
			if e < 0:
				continue
			var sc := 0.0
			match int(passe[3]):
				0: sc = float([0.48, 0.6, 0.72][densite]) + float((r >> 8) & 0xff) / 255.0 * float([0.22, 0.25, 0.3][densite])
				1: sc = 0.8 + float((r >> 8) & 0xff) / 255.0 * 0.5
				_: sc = 1.0 + float((r >> 8) & 0xff) / 255.0 * 0.5
			var jx := float((r >> 16) & 0xff) / 255.0 * 0.5 + 0.25
			var jz := float((r >> 24) & 0x7f) / 127.0 * 0.5 + 0.25
			var pos := Vector3(c.x + jx, world.cell_height(c), c.y + jz)
			var basis := Basis(Vector3.UP, float(r & 0xff)).scaled(Vector3(sc, sc, sc))
			var shade := 0.92 + float((r >> 4) & 0x3f) / 63.0 * 0.2
			res.append([c, e, Transform3D(basis, pos), Color(shade, shade * 1.03, shade * 0.97)])
			pris[c] = true
			poses += 1
	return res


## Nombre de plantes posées (tests).
func compte() -> int:
	var n := 0
	for bid in _jardins:
		n += (_jardins[bid] as Array).size()
	return n


func _poser() -> void:
	for inst in _instances:
		inst.queue_free()
	_instances.clear()
	var groupes := {}
	var bloque := world.tree_blocker.is_valid()
	for bid in _jardins:
		for p in _jardins[bid]:
			# Une voie posée depuis sur la case : la plante est arrachée.
			if bloque and world.tree_blocker.call(p[0]):
				continue
			var e: int = p[1]
			if not groupes.has(e):
				var l: Array[Transform3D] = []
				groupes[e] = [l, []]
			(groupes[e][0] as Array).append(p[2])
			(groupes[e][1] as Array).append(p[3])
	for e: int in groupes:
		var m := Plantes.mesh(e)
		if m == null:
			continue
		var cat := Plantes.categorie(e)
		var liste: Array[Transform3D] = groupes[e][0]
		var teintes := PackedColorArray(groupes[e][1])
		var inst := TerrainWorld._pose_multimesh(self, m, liste, teintes, Plantes.vent(e), Plantes.materiau())
		inst.name = "Jardin_" + Plantes.nom(e)
		inst.visibility_range_end = Plantes.DISTANCE[cat] * 1.4
		inst.visibility_range_end_margin = 8.0
		if cat != Plantes.Cat.ARBRE:
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_instances.append(inst)
		if Plantes.a_version_loin(e):
			var ml := Plantes.mesh(e, true)
			if ml != null:
				var loin := TerrainWorld._pose_multimesh(self, ml, liste, teintes, 0.0, Plantes.materiau())
				loin.name = "Jardin_" + Plantes.nom(e) + "_loin"
				loin.visibility_range_begin = Plantes.DISTANCE[cat] * 1.4
				loin.visibility_range_begin_margin = 8.0
				loin.visibility_range_end = 900.0
				_instances.append(loin)
