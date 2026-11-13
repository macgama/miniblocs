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
	# Étapes de vie : jeunes pousses et arbres morts, par famille d'arbres.
	["pousse_feuillu", Cat.ARBRE, false], ["pousse_conifere", Cat.ARBRE, false], ["pousse_palmier", Cat.ARBRE, false],
	["mort_feuillu", Cat.ARBRE, false], ["mort_conifere", Cat.ARBRE, false], ["mort_palmier", Cat.ARBRE, false],
]
const PALETTE_ROLES := "res://assets/modeles/plantes/palette_roles.png"

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
## Probabilité totale qu'il pousse quelque chose, par kind * 8 + climat (tri rapide).
static var _totaux := PackedFloat32Array()
static var _pret := false
## Les blocs de terrain se calculent sur plusieurs threads : un seul prépare les
## tables, les autres attendent (sans verrou, un thread lisait une table à moitié
## remplie et le jeu plantait de temps en temps).
static var _verrou := Mutex.new()


static func _prepare() -> void:
	if _pret:
		return
	_verrou.lock()
	if not _pret:
		_remplir()
	_verrou.unlock()


static func _remplir() -> void:
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
	_totaux.resize(32 * 8)
	for cle: int in _tables:
		var tot := 0.0
		for couche in _tables[cle]:
			tot += couche[0]
		_totaux[cle] = tot
	var tot_d := 0.0
	for couche in _desert_amerique:
		tot_d += couche[0]
	var tot_a := 0.0
	for couche in _desert_ailleurs:
		tot_a += couche[0]
	for c in 8:
		_totaux[TerrainWorld.Kind.DESERT * 8 + c] = maxf(tot_d, tot_a)
	_pret = true


## Probabilité qu'il pousse quelque chose sur une case de ce biome (0 = rien).
static func densite(kind: int, c: int) -> float:
	_prepare()
	return _totaux[kind * 8 + c]


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


# --- Étapes de vie -------------------------------------------------------------------
# Quatre étapes : jeune pousse, jeune arbre, adulte, arbre mort. Au vrai rythme :
# [âge adulte (ans), durée de vie (ans), famille 0 feuillu / 1 conifère / 2 palmier].
# Un arbre mort reste debout MORT_ANS ans, puis une pousse repart au même endroit.
const VIE := {
	"chene": [80.0, 300.0, 0], "hetre": [80.0, 250.0, 0], "bouleau": [30.0, 90.0, 0],
	"peuplier": [25.0, 80.0, 0], "sapin": [60.0, 300.0, 1], "epicea": [60.0, 250.0, 1],
	"meleze": [50.0, 300.0, 1], "pin": [50.0, 200.0, 1], "pin_parasol": [60.0, 200.0, 1],
	"olivier": [40.0, 500.0, 0], "palmier": [15.0, 80.0, 2], "acacia": [20.0, 100.0, 0],
	"baobab": [100.0, 1000.0, 0], "tropical": [50.0, 300.0, 0], "paletuvier": [20.0, 100.0, 0],
	"saule": [20.0, 70.0, 0],
}
const MORT_ANS := 12.0
## Part de l'âge adulte passée en jeune pousse.
const POUSSE := 0.08
enum Etape { POUSSE, JEUNE, ADULTE, MORT }
const ETAPE_NOMS: Array[String] = ["jeune pousse", "jeune arbre", "adulte", "arbre mort"]
const _POUSSES := ["pousse_feuillu", "pousse_conifere", "pousse_palmier"]
const _MORTS := ["mort_feuillu", "mort_conifere", "mort_palmier"]


## Cette espèce passe-t-elle par les 4 étapes de vie ?
static func vivace(espece: int) -> bool:
	return VIE.has(nom(espece))


## Durée d'un cycle complet (de la pousse à la pousse suivante), en années.
static func cycle(espece: int) -> float:
	var v: Array = VIE[nom(espece)]
	return v[1] + MORT_ANS


## Étape d'un arbre de cet âge (années depuis la pousse, dans le cycle) :
## [modèle à afficher (numéro d'espèce), échelle, étape].
static func etape(espece: int, age: float) -> Array:
	var v: Array = VIE[nom(espece)]
	var adulte: float = v[0]
	var vie: float = v[1]
	var fam: int = v[2]
	if age < adulte * POUSSE:
		return [id(_POUSSES[fam]), 0.5 + 0.5 * age / (adulte * POUSSE), Etape.POUSSE]
	if age < adulte:
		return [espece, lerpf(0.12, 1.0, pow(age / adulte, 0.85)), Etape.JEUNE]
	if age < vie:
		return [espece, 1.0 + 0.15 * (age - adulte) / (vie - adulte), Etape.ADULTE]
	return [id(_MORTS[fam]), 1.0, Etape.MORT]


# --- Saisons -------------------------------------------------------------------------

## Réglages des saisons pour un jour de l'année (0 = 1er janvier), à une latitude
## et un climat donnés. Hémisphère sud : six mois de décalage.
## feuilles : part des feuillages caducs présents (0 l'hiver) ; automne : feuilles
## rousses ; printemps : vert tendre ; herbe_seche : herbe jaunie (hiver, ou été
## méditerranéen) ; fleurs : floraison.
static func saison(jour: float, lat: float, c: int) -> Dictionary:
	var j := fposmod(jour + (182.6 if lat < 0.0 else 0.0), 365.25)
	if c == Climat.TROPICAL:
		return {"feuilles": 1.0, "automne": 0.0, "printemps": 0.0, "herbe_seche": 0.15, "fleurs": 1.0}
	# Décalages (jours) : le printemps vient plus tôt au Sud, l'automne plus tard.
	var dp := 0.0
	var da := 0.0
	if c == Climat.BOREAL:
		dp = 18.0
		da = -22.0
	elif c == Climat.MEDITERRANEEN or c == Climat.SUBTROPICAL:
		dp = -18.0
		da = 12.0
	var feuilles := smoothstep(95.0 + dp, 130.0 + dp, j) * (1.0 - smoothstep(292.0 + da, 326.0 + da, j))
	var automne := smoothstep(255.0 + da, 292.0 + da, j)
	var printemps := smoothstep(95.0 + dp, 118.0 + dp, j) * (1.0 - smoothstep(140.0 + dp, 170.0 + dp, j))
	var hiver := 1.0 - smoothstep(55.0 + dp, 105.0 + dp, j) + smoothstep(305.0 + da, 345.0 + da, j)
	var herbe := clampf(hiver, 0.0, 1.0) * 0.7
	if c == Climat.MEDITERRANEEN or c == Climat.SUBTROPICAL:
		herbe = maxf(herbe * 0.4, smoothstep(170.0, 200.0, j) * (1.0 - smoothstep(245.0, 280.0, j)))
	var fleurs := smoothstep(100.0 + dp, 120.0 + dp, j) * (1.0 - smoothstep(205.0 + da * 0.5, 235.0 + da * 0.5, j))
	return {"feuilles": feuilles, "automne": automne, "printemps": printemps, "herbe_seche": herbe, "fleurs": fleurs}


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
	if ResourceLoader.exists(PALETTE_ROLES):
		m.set_shader_parameter("roles", load(PALETTE_ROLES))
	_materiaux["plantes"] = m
	applique_saison(saison(172.0, 48.0, Climat.TEMPERE), 0.0, Sols.etat_cultures(172.0, 48.0))
	return m


## Règle le matériau des plantes : saison (voir saison()), neige au sol (0 à 1)
## et état des cultures (Sols.etat_cultures).
static func applique_saison(s: Dictionary, neige: float, cultures: Dictionary) -> void:
	var m := materiau()
	for cle in s:
		m.set_shader_parameter(cle, s[cle])
	m.set_shader_parameter("neige", neige)
	m.set_shader_parameter("taille_culture", cultures.taille)
	m.set_shader_parameter("maturite_culture", cultures.maturite)


## Coefficient du vent pour une espèce : balancement (m) en haut de la plante,
## divisé par sa hauteur au carré (le shader fait coef × hauteur²).
static func vent(espece: int) -> float:
	var h := maxf(hauteur(espece), 0.2)
	return VENT[categorie(espece)] / (h * h)
