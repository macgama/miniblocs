class_name Plantes
extends RefCounted
## Les plantes du terrain : arbres, arbustes, herbes, fleurs, cultures et rochers
## low-poly, modélisés dans Blender par tools/blender/plantes_lowpoly.py
## (assets/modeles/plantes/*.glb), et le choix de la végétation de chaque case
## selon son biome (ESA WorldCover), le climat du lieu et l'altitude.
##
## Le choix est un calcul pur (sans scène) : il tourne sur les fils de calcul
## des blocs de terrain. Les maillages et le matériau (vent, palette commune)
## sont chargés sur le fil principal par mesh() et materiau().

enum Cat { ARBRE, ARBUSTE, HERBE, CULTURE, ROCHER }
enum Climat { BOREAL, TEMPERE, MEDITERRANEEN, SUBTROPICAL, TROPICAL }
const CLIMAT_NOMS: Array[String] = ["boréal", "tempéré", "méditerranéen", "subtropical", "tropical"]

const DOSSIER := "res://assets/modeles/plantes/"
const PALETTE := "res://assets/modeles/plantes/palette_plantes.png"

## [nom du .glb, catégorie, version lointaine]. L'indice est le numéro de l'espèce.
const ESPECES := [
	["chene", Cat.ARBRE, true], ["hetre", Cat.ARBRE, true], ["bouleau", Cat.ARBRE, true],
	["peuplier", Cat.ARBRE, true], ["sapin", Cat.ARBRE, true], ["epicea", Cat.ARBRE, true],
	["meleze", Cat.ARBRE, true], ["pin", Cat.ARBRE, true], ["pin_parasol", Cat.ARBRE, true],
	["olivier", Cat.ARBRE, true], ["palmier", Cat.ARBRE, true], ["acacia", Cat.ARBRE, true],
	["baobab", Cat.ARBRE, true], ["tropical", Cat.ARBRE, true], ["paletuvier", Cat.ARBRE, true],
	["saule", Cat.ARBRE, true], ["cactus_saguaro", Cat.ARBRE, false],
	["buisson", Cat.ARBUSTE, false], ["buisson_fleuri", Cat.ARBUSTE, false], ["genet", Cat.ARBUSTE, false],
	["buisson_sec", Cat.ARBUSTE, false], ["saule_nain", Cat.ARBUSTE, false], ["cactus_raquette", Cat.ARBUSTE, false],
	["agave", Cat.ARBUSTE, false], ["fougere", Cat.ARBUSTE, false],
	["herbe", Cat.HERBE, false], ["hautes_herbes", Cat.HERBE, false], ["roseaux", Cat.HERBE, false],
	["oyat", Cat.HERBE, false], ["lichen", Cat.HERBE, false], ["coquelicots", Cat.HERBE, false],
	["marguerites", Cat.HERBE, false], ["fleurs_jaunes", Cat.HERBE, false], ["gentianes", Cat.HERBE, false],
	["lavande", Cat.HERBE, false],
	["ble", Cat.CULTURE, false], ["riz", Cat.CULTURE, false], ["mais", Cat.CULTURE, false],
	["colza", Cat.CULTURE, false], ["tournesol", Cat.CULTURE, false], ["vigne", Cat.CULTURE, false],
	["legumes", Cat.CULTURE, false],
	["rocher", Cat.ROCHER, false], ["gros_rocher", Cat.ROCHER, false], ["cailloux", Cat.ROCHER, false],
	["rocher_desert", Cat.ROCHER, false],
]

## Distance (m) au-delà de laquelle une catégorie disparaît (arbres : passent à
## leur version lointaine). Mesurée depuis le centre du bloc de 64 m.
const DISTANCE := [170.0, 190.0, 95.0, 130.0, 260.0]
## Balancement au vent en haut de la plante (m), par catégorie.
const VENT := [0.25, 0.06, 0.07, 0.08, 0.0]

static var _ids: Dictionary = _fait_ids()


static func _fait_ids() -> Dictionary:
	var d := {}
	for n in ESPECES.size():
		d[ESPECES[n][0]] = n
	return d


static func id(nom: String) -> int:
	return _ids.get(nom, -1)


static func nom(espece: int) -> String:
	return ESPECES[espece][0]


static func categorie(espece: int) -> int:
	return ESPECES[espece][1]


## Climat d'une région, d'après sa latitude (et la Méditerranée).
static func climat(lat: float, lon: float) -> int:
	var a := absf(lat)
	var med := lat > 29.0 and lat < 46.0 and lon > -10.0 and lon < 42.0
	if a >= 58.0:
		return Climat.BOREAL
	if a < 18.0:
		return Climat.TROPICAL
	if med:
		return Climat.MEDITERRANEEN
	if a < 32.0:
		return Climat.SUBTROPICAL
	return Climat.TEMPERE


## Amériques : cactus dans les déserts (ailleurs : broussailles et agaves).
static func ameriques(lon: float) -> bool:
	return lon < -30.0


# --- Ce qui pousse dans chaque biome ---------------------------------------------
# Une « couche » = [probabilité par case, [[espèce, poids], ...]].
# Les probabilités des couches d'un biome s'additionnent.

## Arbres des forêts selon le climat (aussi utilisés par le pinceau « planter »).
const _FORETS := {
	Climat.BOREAL: [["sapin", 4], ["epicea", 4], ["bouleau", 2], ["pin", 2], ["meleze", 1]],
	Climat.TEMPERE: [["chene", 5], ["hetre", 4], ["bouleau", 2], ["sapin", 1], ["pin", 1], ["peuplier", 1]],
	Climat.MEDITERRANEEN: [["pin_parasol", 3], ["chene", 3], ["olivier", 2], ["pin", 2]],
	Climat.SUBTROPICAL: [["tropical", 2], ["chene", 2], ["pin", 2], ["palmier", 1], ["olivier", 1]],
	Climat.TROPICAL: [["tropical", 6], ["palmier", 2], ["paletuvier", 1]],
}
const _MONTAGNE := [["sapin", 5], ["epicea", 4], ["meleze", 2], ["pin", 1]]
## Altitude (m) à partir de laquelle les forêts deviennent des forêts de conifères.
const ALTITUDE_CONIFERES := 1100.0
## Densité des arbres en forêt (un arbre adulte pour ~28 m²).
const DENSITE_FORET := 0.036
## Densité des arbres plantés au pinceau.
const DENSITE_PLANTES := 0.15

static var _tables: Dictionary = {}
static var _pret := false


static func _prepare() -> void:
	if _pret:
		return
	var K := TerrainWorld.Kind
	for c: int in Climat.values():
		var chaud := c >= Climat.SUBTROPICAL
		var med := c == Climat.MEDITERRANEEN
		var foret: Array = _FORETS[c]
		_ajoute(K.FORET, c, [[DENSITE_FORET, foret],
			[0.02, [["buisson", 3], ["buisson_fleuri", 1]] if not chaud else [["buisson", 2], ["fougere", 2]]],
			[0.04, [["fougere", 3], ["herbe", 1]]], [0.003, [["rocher", 1]]]])
		var arbres_maquis: Array = [["olivier", 2], ["pin_parasol", 1]] if med else (
			[["acacia", 4], ["baobab", 1]] if chaud else [["chene", 2], ["pin", 1], ["bouleau", 1]])
		_ajoute(K.BROUSSAILLES, c, [[0.006, arbres_maquis],
			[0.05, [["buisson_sec", 2], ["lavande", 2], ["buisson", 1]] if med else (
				[["buisson_sec", 3], ["buisson", 1]] if chaud else [["genet", 2], ["buisson", 2], ["buisson_fleuri", 1]])],
			[0.06, [["hautes_herbes", 1]]], [0.004, [["rocher", 1], ["cailloux", 2]]]])
		var arbres_pre: Array = [["acacia", 5], ["baobab", 1], ["palmier", 1]] if chaud else (
			[["olivier", 2], ["chene", 1]] if med else [["chene", 3], ["peuplier", 1], ["bouleau", 1]])
		_ajoute(K.PRAIRIE, c, [[0.0025 if not chaud else 0.004, arbres_pre],
			[0.12, [["herbe", 4], ["hautes_herbes", 1]] if not chaud else [["hautes_herbes", 3], ["herbe", 1]]],
			[0.025, [["coquelicots", 2], ["marguerites", 2], ["fleurs_jaunes", 2]] if c != Climat.BOREAL else [["marguerites", 1], ["fleurs_jaunes", 1]]],
			[0.004, [["buisson", 1], ["cailloux", 1]]]])
		_ajoute(K.ALPAGE, c, [[0.002, _MONTAGNE], [0.1, [["herbe", 1]]],
			[0.035, [["gentianes", 3], ["marguerites", 1], ["fleurs_jaunes", 1]]],
			[0.012, [["cailloux", 3], ["rocher", 1]]]])
		_ajoute(K.ROCHE, c, [[0.03, [["cailloux", 1]]], [0.006, [["rocher", 4], ["gros_rocher", 1]]],
			[0.012, [["lichen", 2], ["gentianes", 1]]]])
		_ajoute(K.MARAIS, c, [[0.006, [["saule", 2], ["bouleau", 1]] if not chaud else [["paletuvier", 1], ["palmier", 1]]],
			[0.12, [["roseaux", 1]]], [0.04, [["hautes_herbes", 1]]], [0.01, [["buisson", 1]]]])
		_ajoute(K.MANGROVE, c, [[0.06, [["paletuvier", 1]]], [0.015, [["roseaux", 1]]]])
		_ajoute(K.TOUNDRA, c, [[0.002, [["bouleau", 1]]], [0.04, [["saule_nain", 1]]], [0.06, [["lichen", 1]]],
			[0.04, [["herbe", 1]]], [0.012, [["cailloux", 3], ["rocher", 1]]]])
		_ajoute(K.PLAGE, c, [[0.006 if chaud else 0.0, [["palmier", 1]]],
			[0.03 if not chaud else 0.006, [["oyat", 1]]], [0.003, [["cailloux", 1]]]])
	_pret = true


static func _ajoute(kind: int, c: int, couches: Array) -> void:
	var t := []
	for couche in couches:
		var especes := PackedInt32Array()
		var poids := PackedFloat32Array()
		var total := 0.0
		for e in couche[1]:
			total += float(e[1])
		var acc := 0.0
		for e in couche[1]:
			var i := id(e[0])
			assert(i >= 0, "espèce inconnue " + str(e[0]))
			acc += float(e[1]) / total
			especes.append(i)
			poids.append(acc)
		t.append([float(couche[0]), especes, poids])
	_tables[kind * 8 + c] = t


## Déserts : selon le continent (cactus seulement dans les Amériques).
static var _desert_amerique := [[0.003, _choix([["cactus_saguaro", 1]])],
	[0.006, _choix([["cactus_raquette", 2], ["agave", 1]])], [0.01, _choix([["buisson_sec", 1]])],
	[0.003, _choix([["rocher_desert", 1]])], [0.008, _choix([["cailloux", 1]])]]
static var _desert_ailleurs := [[0.012, _choix([["buisson_sec", 3], ["agave", 1]])],
	[0.004, _choix([["rocher_desert", 1]])], [0.01, _choix([["cailloux", 1]])]]
static var _montagne := _choix(_MONTAGNE)


static func _choix(liste: Array) -> Array:
	var especes := PackedInt32Array()
	var poids := PackedFloat32Array()
	var total := 0.0
	for e in liste:
		total += float(e[1])
	var acc := 0.0
	for e in liste:
		acc += float(e[1]) / total
		especes.append(id(e[0]))
		poids.append(acc)
	return [especes, poids]


static func _pioche(especes: PackedInt32Array, poids: PackedFloat32Array, v: float) -> int:
	for n in poids.size():
		if v < poids[n]:
			return especes[n]
	return especes[especes.size() - 1]


## Espèce qui pousse sur une case, ou -1. u et v : deux nombres de 0 à 1 tirés
## de la position de la case (toujours les mêmes pour un même lieu).
## Les champs ne passent pas par ici (voir Sols.culture).
static func choisir(kind: int, c: int, alt: float, americain: bool, u: float, v: float) -> int:
	_prepare()
	if kind == TerrainWorld.Kind.DESERT:
		var acc := 0.0
		for couche in (_desert_amerique if americain else _desert_ailleurs):
			acc += couche[0]
			if u < acc:
				return _pioche(couche[1][0], couche[1][1], v)
		return -1
	var t: Array = _tables.get(kind * 8 + c, [])
	var acc := 0.0
	for n in t.size():
		var couche: Array = t[n]
		acc += couche[0]
		if u < acc:
			# Forêts de montagne : des conifères (sauf sous les tropiques).
			if n == 0 and alt > ALTITUDE_CONIFERES and c != Climat.TROPICAL \
					and (kind == TerrainWorld.Kind.FORET or kind == TerrainWorld.Kind.PRAIRIE):
				return _pioche(_montagne[0], _montagne[1], v)
			return _pioche(couche[1], couche[2], v)
	return -1


## Arbre planté au pinceau : un arbre des forêts du climat (conifères en montagne).
static func arbre_plante(c: int, alt: float, v: float) -> int:
	_prepare()
	if alt > ALTITUDE_CONIFERES and c != Climat.TROPICAL:
		return _pioche(_montagne[0], _montagne[1], v)
	var t: Array = _tables[TerrainWorld.Kind.FORET * 8 + c]
	return _pioche(t[0][1], t[0][2], v)


# --- Maillages et matériau (fil principal) ------------------------------------------

static var _meshes: Dictionary = {}
static var _materiaux: Dictionary = {}
static var _hauteurs: Dictionary = {}


## Maillage d'une espèce (loin = version de quelques triangles), ou null si le
## .glb n'est pas (encore) importé.
static func mesh(espece: int, loin := false) -> Mesh:
	var cle := espece * 2 + (1 if loin else 0)
	if _meshes.has(cle):
		return _meshes[cle]
	var chemin := DOSSIER + nom(espece) + ("_loin" if loin else "") + ".glb"
	var m: Mesh = null
	if ResourceLoader.exists(chemin):
		var sc := load(chemin) as PackedScene
		if sc:
			var racine := sc.instantiate()
			var mi := _premier_mesh(racine)
			if mi:
				m = mi.mesh
			racine.free()
	_meshes[cle] = m
	if m and not loin:
		_hauteurs[espece] = m.get_aabb().end.y
	return m


static func a_version_loin(espece: int) -> bool:
	return ESPECES[espece][2]


## Hauteur du modèle (m), pour régler le vent.
static func hauteur(espece: int) -> float:
	if not _hauteurs.has(espece):
		mesh(espece)
	return _hauteurs.get(espece, 1.0)


static func _premier_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return n
	for c in n.get_children():
		var r := _premier_mesh(c)
		if r:
			return r
	return null


## Matériau commun (palette + vent). ombre = false pour l'herbe et les cultures.
static func materiau() -> ShaderMaterial:
	if _materiaux.has("plantes"):
		return _materiaux["plantes"]
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/terre/plante.gdshader")
	if ResourceLoader.exists(PALETTE):
		m.set_shader_parameter("palette", load(PALETTE))
	_materiaux["plantes"] = m
	return m


## Coefficient du vent pour une espèce : balancement (m) en haut de la plante,
## divisé par sa hauteur au carré (le shader fait coef × hauteur²).
static func vent(espece: int) -> float:
	var h := maxf(hauteur(espece), 0.2)
	return VENT[categorie(espece)] / (h * h)
