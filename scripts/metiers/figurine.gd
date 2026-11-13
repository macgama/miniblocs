class_name Figurine
extends Node3D
## Habitant articulé low-poly qui fait les gestes de son métier.
##
## Même allure que les silhouettes des intérieurs (Occupants), mais en
## morceaux : bassin, cuisses, tibias, buste, tête, bras et avant-bras. Chaque
## image, animer() place les articulations selon le geste (pétrir, écrire au
## tableau, ausculter, piocher…). La figurine regarde vers +Z ; ses pieds sont
## en 0 (debout) ou son bassin à la hauteur d'une assise (assis).
##
## Tenue selon le métier (blouse blanche, toque, gilet orange, uniforme…),
## outil dans la main droite.

const SKINS := ["f1c8a6", "e0a984", "c68a5e", "9a6440", "6b4428"]
const SHIRTS := ["3a86c8", "e76f51", "2a9d8f", "e9c46a", "8d5a97", "6b8f3a", "d64545", "4a4e69"]
const HAIRS := ["2b1d16", "5a3a22", "a87b4f", "1a1a1a", "c9b28a"]

## Tenues : [haut, bas, chapeau] ; "" = couleur de l'habitant. Clé = métier
## (ou clé "tenue" d'un métier de Metiers.METIERS, qui désigne une de ces tenues).
const TENUES := {
	"boulanger": ["f4f1ea", "d9d4c7", "toque"], "cuisinier": ["f7f7f2", "2f2f33", "toque"],
	"boucher": ["f4f1ea", "3a3f4a", "tablier_rouge"], "serveur": ["202024", "202024", "tablier"],
	"medecin": ["f5f7f8", "3d5a80", "blouse"], "infirmier": ["8ecae6", "8ecae6", ""], "aide_soignant": ["b7e4c7", "b7e4c7", ""],
	"pompier": ["1f2a44", "1f2a44", "casque_pompier"], "policier": ["1d3557", "1d3557", "casquette"],
	"ouvrier": ["f77f00", "3a4a6b", "casque"], "carrier": ["f77f00", "3a4a6b", "casque"], "mineur": ["5c5c5c", "3a3a3a", "casque_lampe"],
	"conducteur_engins": ["f9c74f", "3a4a6b", "casque"], "siderurgiste": ["8d99ae", "4a4e69", "casque"], "operateur": ["4895ef", "2b2d42", "casque"],
	"foreur": ["e63946", "2b2d42", "casque"], "agriculteur": ["5a7d3a", "3b5ba5", "chapeau"], "eleveur": ["2d6a4f", "3b5ba5", "casquette"],
	"bucheron": ["c1121f", "3a4a2b", "casque"], "pecheur": ["ffb703", "ffb703", "bonnet"], "magasinier": ["90be6d", "3a3f4a", ""],
	"chauffeur": ["577590", "3a3f4a", "casquette"], "caissier": ["e63946", "2f2f33", ""], "agent_gare": ["264653", "264653", "casquette"],
	"coach": ["ef476f", "1d3557", ""], "cadre": ["2b2d42", "2b2d42", ""], "meunier": ["e9e4d8", "8a7a5a", "bonnet"],
	"menuisier": ["9c6644", "3a3f4a", ""],
	"porteur_funeraire": ["1b1b1e", "1b1b1e", ""], "conseiller_funeraire": ["2b2d42", "2b2d42", ""],
	"fossoyeur": ["4a5a3a", "3a3f4a", "casquette"], "gardien_cimetiere": ["3d5a80", "2b2d42", "casquette"], "jardinier": ["2d6a4f", "3a3f4a", "chapeau"], "artisan": ["7f5539", "3a3f4a", "tablier"],
}

var pid := 0
var assise := false
var geste := ""
var anim := "taper"
## Décalage d'horloge propre à chacun (tous ne pétrissent pas au même rythme).
var phase := 0.0
## Mouvement de va-et-vient (servir, porter…) : amplitude en mètres le long de Z.
var va_et_vient := 0.0
## Hauteur du bassin quand la figurine est assise (0 : le parent la pose sur l'assise).
var hauteur_assise := 0.0

var _corps: Node3D
var _bassin: Node3D
var _buste: Node3D
var _tete: Node3D
var _bras: Array[Node3D] = []
var _coudes: Array[Node3D] = []
var _cuisses: Array[Node3D] = []
var _genoux: Array[Node3D] = []
var _main: Node3D
var _outil: MeshInstance3D
var _outil_nom := "?"

static var _cache: Dictionary = {}
## Hauteur du bassin debout (modèle arrondi : celle du modèle).
var _hanche := 0.88
## Personnage arrondi de Blender (Silhouettes) ; null : figurine en blocs.
var silhouette: Node3D


static func materiau() -> Material:
	return MeublesModeles.materials().base


## Crée la figurine d'un habitant (tenue de son métier). Avec pop et les
## modèles Blender importés, c'est son personnage arrondi (Silhouettes), à
## sa taille et avec son apparence ; sinon une figurine en blocs.
static func creer(person_id: int, met: String, enfant := false, pop: Population = null) -> Figurine:
	var f := Figurine.new()
	f.pid = person_id
	f.phase = float(absi(hash(person_id)) % 1000) / 137.0
	if pop != null and pop.persons.has(person_id) and Silhouettes.disponible():
		f._construire_silhouette(pop, met)
	else:
		f._construire(met, enfant)
	return f


func _construire_silhouette(pop: Population, met: String) -> void:
	_corps = Node3D.new()
	add_child(_corps)
	var n := Silhouettes.pour_habitant(pop, pid)
	_corps.add_child(n)
	silhouette = n
	var rig := Silhouettes.os(n)
	_hanche = float(n.get_meta("hanche", 0.88))
	_bassin = rig.bassin
	_buste = rig.torse
	_tete = rig.tete
	# Index 0 : bras du côté −X, index 1 : côté +X (celui qui tient l'outil).
	var cotes := ["g", "d"]
	if (rig.bras_g as Node3D).position.x > (rig.bras_d as Node3D).position.x:
		cotes = ["d", "g"]
	for c in cotes:
		_bras.append(rig["bras_" + c])
		_coudes.append(rig["avant_bras_" + c])
		_cuisses.append(rig["jambe_" + c])
		_genoux.append(rig["tibia_" + c])
	_main = rig.get("main_" + cotes[1])
	if _main == null:
		_main = Node3D.new()
		_main.position = Vector3(0, -0.28, 0)
		_coudes[1].add_child(_main)
	var t := tenue_de(met)
	var tenue := {}
	if String(t[0]) != "":
		tenue["haut"] = Color(String(t[0]))
		tenue["manches"] = 1.0
	if String(t[1]) != "":
		tenue["bas"] = Color(String(t[1]))
		tenue["jambes"] = 1.0
	if not tenue.is_empty():
		Silhouettes.habiller(n, tenue)
	# Couvre-chef du métier (toque, casque, casquette…), posé sur la tête.
	var chapeau := String(t[2])
	if chapeau in ["toque", "casque", "casque_lampe", "casque_pompier", "casquette", "chapeau", "bonnet"]:
		var key := "chapeau_" + chapeau
		if not _cache.has(key):
			var k := LpKit.new(1)
			k.jitter = 0.02
			_chapeau(k, chapeau)
			_cache[key] = k.commit({"base": materiau()})
		var hat := MeshInstance3D.new()
		hat.mesh = _cache[key]
		hat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hat.position = Vector3(0, _haut_de_tete(_tete) - CHAPEAU_Y, 0)
		_tete.add_child(hat)
	_outil = MeshInstance3D.new()
	_outil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_main.add_child(_outil)


## Hauteur, au-dessus de l'origine de la tête, où commence un couvre-chef
## dans les modèles de _chapeau() (le haut du crâne y est à 0,25 m).
const CHAPEAU_Y := 0.25


## Haut du crâne (cheveux compris) dans le repère de la tête.
static func _haut_de_tete(tete: Node3D) -> float:
	var top := 0.25
	var found := false
	var pile: Array = [[tete, Transform3D.IDENTITY]]
	while not pile.is_empty():
		var e: Array = pile.pop_back()
		var n: Node = e[0]
		var xf: Transform3D = e[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var bb := xf * (n as MeshInstance3D).mesh.get_aabb()
			top = bb.end.y if not found else maxf(top, bb.end.y)
			found = true
		for c in n.get_children():
			if c is Node3D:
				pile.append([c, xf * (c as Node3D).transform])
	return top


static func tenue_de(met: String) -> Array:
	var m: Dictionary = Metiers.METIERS.get(met, {})
	if m.has("tenue") and TENUES.has(String(m.tenue)):
		return TENUES[String(m.tenue)]
	return TENUES.get(met, ["", "", ""])


func _construire(met: String, enfant: bool) -> void:
	var skin := Color(String(SKINS[(pid / SHIRTS.size()) % SKINS.size()]))
	var hair := Color(String(HAIRS[(pid / 3) % HAIRS.size()]))
	var shirt := Color(String(SHIRTS[pid % SHIRTS.size()]))
	var pants := Color("3b3f4a").lerp(shirt, 0.15)
	var t := tenue_de(met)
	if String(t[0]) != "":
		shirt = Color(String(t[0]))
	if String(t[1]) != "":
		pants = Color(String(t[1]))
	var c := {"skin": skin, "hair": hair, "shirt": shirt, "pants": pants, "chapeau": String(t[2]),
		"bandes": String(t[0]) in ["f77f00", "f9c74f", "e63946"]}
	_corps = Node3D.new()
	add_child(_corps)
	if enfant:
		_corps.scale = Vector3.ONE * 0.72
	_bassin = Node3D.new()
	_bassin.position = Vector3(0, 0.88, 0)
	_corps.add_child(_bassin)
	_piece(_bassin, "bassin", c)
	for sx in [-0.1, 0.1]:
		var cuisse := Node3D.new()
		cuisse.position = Vector3(sx, -0.04, 0)
		_bassin.add_child(cuisse)
		_piece(cuisse, "cuisse", c)
		var genou := Node3D.new()
		genou.position = Vector3(0, -0.42, 0)
		cuisse.add_child(genou)
		_piece(genou, "tibia", c)
		_cuisses.append(cuisse)
		_genoux.append(genou)
	_buste = Node3D.new()
	_buste.position = Vector3(0, 0.04, 0)
	_bassin.add_child(_buste)
	_piece(_buste, "buste", c)
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.6, 0)
	_buste.add_child(_tete)
	_piece(_tete, "tete", c)
	for sx in [-0.25, 0.25]:
		var bras := Node3D.new()
		bras.position = Vector3(sx, 0.52, 0)
		_buste.add_child(bras)
		_piece(bras, "bras", c)
		var coude := Node3D.new()
		coude.position = Vector3(0, -0.28, 0)
		bras.add_child(coude)
		_piece(coude, "avant_bras", c)
		_bras.append(bras)
		_coudes.append(coude)
	_main = Node3D.new()
	_main.position = Vector3(0, -0.28, 0)
	_coudes[1].add_child(_main)
	_outil = MeshInstance3D.new()
	_outil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_main.add_child(_outil)


## Une pièce du corps (maillage mis en cache par forme et couleurs).
func _piece(parent: Node3D, nom: String, c: Dictionary) -> void:
	var col: Color = c.shirt
	if nom in ["bassin", "cuisse", "tibia"]:
		col = c.pants
	var key := "%s_%s" % [nom, col.to_html(false)]
	if nom == "tete":
		key = "tete_%s_%s_%s_%d" % [(c.skin as Color).to_html(false), (c.hair as Color).to_html(false), c.chapeau, pid % 7]
	elif nom == "buste":
		key += "_%s_%s" % [c.chapeau, str(c.bandes)]
	elif nom == "avant_bras":
		key += "_" + (c.skin as Color).to_html(false)
	if not _cache.has(key):
		var k := LpKit.new(pid if nom == "tete" else 1)
		k.jitter = 0.03
		_dessiner(k, nom, c)
		_cache[key] = k.commit({"base": materiau()})
	var mi := MeshInstance3D.new()
	mi.mesh = _cache[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _dessiner(k: LpKit, nom: String, c: Dictionary) -> void:
	var skin: Color = c.skin
	var shirt: Color = c.shirt
	var pants: Color = c.pants
	var chapeau := String(c.chapeau)
	if nom == "bassin":
		k.box(Vector3(0, -0.02, 0), Vector3(0.36, 0.16, 0.22), pants)
	elif nom == "cuisse":
		k.box(Vector3(0, -0.21, 0), Vector3(0.14, 0.44, 0.15), pants)
	elif nom == "tibia":
		k.box(Vector3(0, -0.2, 0), Vector3(0.12, 0.4, 0.13), pants)
		k.box(Vector3(0, -0.41, 0.04), Vector3(0.13, 0.06, 0.22), Color("2a2a2a"))
	elif nom == "bras":
		k.box(Vector3(0, -0.14, 0), Vector3(0.1, 0.3, 0.11), shirt.darkened(0.08))
	elif nom == "avant_bras":
		k.box(Vector3(0, -0.12, 0), Vector3(0.09, 0.24, 0.1), shirt.darkened(0.12))
		k.box(Vector3(0, -0.27, 0), Vector3(0.08, 0.08, 0.08), skin)
	elif nom == "buste":
		k.box(Vector3(0, 0.28, 0), Vector3(0.4, 0.56, 0.23), shirt)
		if chapeau == "tablier" or chapeau == "tablier_rouge":
			k.box(Vector3(0, 0.12, 0.125), Vector3(0.34, 0.5, 0.02), Color("f2efe6") if chapeau == "tablier" else Color("b23a48"))
		elif chapeau == "blouse":
			k.box(Vector3(0, 0.12, 0), Vector3(0.43, 0.42, 0.26), shirt.darkened(0.03))
			k.box(Vector3(0, 0.42, 0.12), Vector3(0.12, 0.12, 0.02), Color("3d5a80"))
		if bool(c.bandes):
			k.box(Vector3(0, 0.2, 0.118), Vector3(0.41, 0.05, 0.01), Color("e8e8e8"))
			k.box(Vector3(0, 0.36, 0.118), Vector3(0.41, 0.05, 0.01), Color("e8e8e8"))
	elif nom == "tete":
		var hair: Color = c.hair
		k.box(Vector3(0, -0.04, 0), Vector3(0.1, 0.08, 0.1), skin)
		k.blob(Vector3(0, 0.12, 0), Vector3(0.12, 0.13, 0.12), skin.darkened(0.05), skin, 0.04, 0)
		k.blob(Vector3(0, 0.17, -0.03), Vector3(0.13, 0.1, 0.13), hair, hair.lightened(0.1), 0.06, 0)
		k.box(Vector3(0, 0.12, 0.11), Vector3(0.03, 0.04, 0.03), skin.darkened(0.1))
		_chapeau(k, chapeau)


func _chapeau(k: LpKit, c: String) -> void:
	match c:
		"toque":
			k.box(Vector3(0, 0.3, -0.01), Vector3(0.24, 0.16, 0.24), Color("fbfbf8"))
		"casque", "casque_lampe":
			k.blob(Vector3(0, 0.24, -0.01), Vector3(0.15, 0.08, 0.16), Color("f9c74f"), Color("ffd166"), 0.02, 0)
			if c == "casque_lampe":
				k.box(Vector3(0, 0.25, 0.15), Vector3(0.06, 0.05, 0.03), Color("fff3b0"))
		"casque_pompier":
			k.blob(Vector3(0, 0.24, -0.01), Vector3(0.15, 0.09, 0.16), Color("e8e8e8"), Color("ffffff"), 0.02, 0)
			k.box(Vector3(0, 0.27, 0.0), Vector3(0.03, 0.06, 0.3), Color("d62828"))
		"casquette":
			k.box(Vector3(0, 0.25, -0.01), Vector3(0.25, 0.07, 0.25), Color("1d3557"))
			k.box(Vector3(0, 0.22, 0.14), Vector3(0.2, 0.02, 0.1), Color("14213d"))
		"chapeau":
			k.box(Vector3(0, 0.22, 0), Vector3(0.36, 0.02, 0.36), Color("d4a373"))
			k.box(Vector3(0, 0.28, 0), Vector3(0.2, 0.1, 0.2), Color("d4a373"))
		"bonnet":
			k.blob(Vector3(0, 0.24, -0.02), Vector3(0.14, 0.1, 0.14), Color("c1121f"), Color("e63946"), 0.03, 0)


## Choisit le geste (animation, outil, assis ou debout).
func regler(nom_geste: String, force_assis := false) -> void:
	geste = nom_geste
	var g := Gestes.info(nom_geste)
	anim = String(g.a)
	assise = force_assis or bool(g.get("s", false)) or Accessoires.poste_assis(String(g.p))
	va_et_vient = 0.8 if anim in ["servir", "porter", "pousser", "balayer"] and not assise else 0.0
	var o := String(g.o)
	if o != _outil_nom:
		_outil_nom = o
		_outil.mesh = Accessoires.outil(o) if o != "" else null


## Pose de base puis geste, à l'instant t (secondes).
func animer(t: float) -> void:
	var u := t + phase
	var s := sin(u * 3.0)
	var c := cos(u * 3.0)
	# Bras : [épaule (x : − = vers l'avant), écart (z), coude (− = plié vers l'avant)].
	var bg := Vector3(0, 0.05, -0.1)
	var bd := Vector3(0, -0.05, -0.1)
	var buste := 0.0
	var buste_yaw := 0.0
	var tete := 0.0
	var tete_yaw := 0.0
	var haut := 0.0
	var marche := 0.0
	match anim:
		"petrir":
			buste = 0.35 + 0.08 * s
			bg = Vector3(-0.9 - 0.25 * s, 0.1, -0.6)
			bd = Vector3(-0.9 + 0.25 * s, -0.1, -0.6)
			tete = 0.3
		"faconner":
			buste = 0.3
			bg = Vector3(-0.8, 0.15 + 0.12 * s, -0.9)
			bd = Vector3(-0.8, -0.15 - 0.12 * s, -0.9)
			tete = 0.4
		"enfourner":
			var p := 0.5 + 0.5 * sin(u * 1.4)
			buste = 0.1 + 0.1 * p
			bg = Vector3(-1.1 - 0.3 * p, 0.1, -0.3)
			bd = Vector3(-1.2 - 0.3 * p, -0.1, -0.2)
			marche = 0.25 * p
		"remuer":
			buste = 0.15
			bg = Vector3(-0.7, 0.1, -0.9)
			bd = Vector3(-0.9 + 0.15 * s, -0.15 + 0.15 * c, -0.8)
			tete = 0.35
		"trancher":
			buste = 0.25
			bg = Vector3(-0.8, 0.1, -0.7)
			bd = Vector3(-1.3 + 0.45 * maxf(s, -0.2), -0.05, -0.5)
			tete = 0.4
		"servir":
			bg = Vector3(-0.4, 0.05, -1.2)
			bd = Vector3(0.1 * s, -0.05, -0.15)
		"scanner":
			buste = 0.1
			buste_yaw = 0.25 * s
			bg = Vector3(-0.7, 0.1, -0.8)
			bd = Vector3(-0.8, -0.3 - 0.25 * s, -0.7)
			tete = 0.3
		"parler":
			bg = Vector3(-0.4 - 0.3 * maxf(s, 0.0), 0.15, -1.0)
			bd = Vector3(-0.6 - 0.3 * maxf(-s, 0.0), -0.2, -0.9)
			buste_yaw = 0.3 * sin(u * 0.7)
			tete_yaw = 0.4 * sin(u * 0.7)
		"ranger":
			var h := 0.5 + 0.5 * sin(u * 1.5)
			bg = Vector3(-1.2 - 1.2 * h, 0.1, -0.3)
			bd = Vector3(-1.2 - 1.2 * h, -0.1, -0.3)
			tete = -0.3 * h
		"tendre":
			bd = Vector3(-1.2 - 0.2 * s, -0.05, -0.1)
			bg = Vector3(-0.2, 0.05, -0.3)
			buste = 0.1
		"porter":
			bg = Vector3(-0.9, 0.2, -0.7)
			bd = Vector3(-0.9, -0.2, -0.7)
		"ecrire_tableau":
			bd = Vector3(-2.3 + 0.15 * c, -0.2 - 0.3 * s, -0.3)
			bg = Vector3(-0.1, 0.1, -0.2)
			tete = -0.15
		"ecrire_assis":
			buste = 0.3
			bg = Vector3(-0.7, 0.2, -0.9)
			bd = Vector3(-0.75, -0.15 + 0.06 * sin(u * 9.0), -0.95)
			tete = 0.45
		"pencher":
			buste = 0.7 + 0.08 * s
			bg = Vector3(-0.9, 0.15, -0.3)
			bd = Vector3(-1.0 - 0.15 * s, -0.15, -0.4)
			tete = 0.2
		"soigner":
			buste = 0.55
			bg = Vector3(-1.0 + 0.1 * s, 0.2, -0.6)
			bd = Vector3(-1.0 - 0.1 * s, -0.2, -0.6)
			tete = 0.3
		"lever_bras":
			bd = Vector3(-2.4 + 0.1 * s, -0.1, -0.4)
			bg = Vector3(-0.6, 0.1, -0.6)
			tete = -0.35
		"pousser":
			buste = 0.15
			bg = Vector3(-1.1, 0.1, -0.4)
			bd = Vector3(-1.1, -0.1, -0.4)
		"taper":
			buste = 0.1
			bg = Vector3(-0.75 + 0.05 * sin(u * 12.0), 0.15, -0.95)
			bd = Vector3(-0.75 + 0.05 * sin(u * 11.0 + 1.0), -0.15, -0.95)
			tete = 0.2
		"telephoner":
			bd = Vector3(-0.6, -0.35, -2.4)
			bg = Vector3(-0.5 - 0.2 * maxf(s, 0.0), 0.15, -0.9)
			tete_yaw = 0.3 * sin(u * 0.5)
		"balayer":
			buste = 0.2
			bg = Vector3(-0.6 + 0.3 * s, 0.15, -0.3)
			bd = Vector3(-0.4 + 0.3 * s, -0.15, -0.3)
		"marteler":
			buste = 0.25
			bg = Vector3(-0.8, 0.1, -0.7)
			var f := pow(0.5 + 0.5 * sin(u * 4.0), 3.0)
			bd = Vector3(-0.6 - 1.4 * f, -0.05, -0.6 - 0.6 * f)
			tete = 0.35
		"raboter":
			buste = 0.35 + 0.12 * s
			bg = Vector3(-1.0 - 0.3 * s, 0.1, -0.3)
			bd = Vector3(-1.0 - 0.3 * s, -0.1, -0.3)
			marche = 0.12 * s
		"machine":
			bg = Vector3(-1.0, 0.1, -0.4 - 0.3 * maxf(s, 0.0))
			bd = Vector3(-1.0 - 0.2 * maxf(-s, 0.0), -0.1, -0.5)
			tete_yaw = 0.3 * sin(u * 0.6)
			tete = 0.15
		"recueil":
			# Mains jointes devant soi, tête baissée.
			buste = 0.06
			bg = Vector3(-0.3, 0.0, -1.0)
			bd = Vector3(-0.3, 0.0, -1.0)
			tete = 0.35 + 0.03 * sin(u * 0.5)
		"surveiller":
			bg = Vector3(0.25, 0.1, -1.2)
			bd = Vector3(0.25, -0.1, -1.2)
			tete_yaw = 0.6 * sin(u * 0.4)
		"souder":
			buste = 0.4
			bg = Vector3(-0.9, 0.15, -0.6)
			bd = Vector3(-0.9 + 0.05 * sin(u * 8.0), -0.1, -0.7)
			tete = 0.5
		"becher":
			var f2 := 0.5 + 0.5 * sin(u * 2.2)
			buste = 0.3 + 0.4 * f2
			bg = Vector3(-0.5 - 0.6 * f2, 0.1, -0.5)
			bd = Vector3(-0.9 - 0.5 * f2, -0.1, -0.3)
		"cueillir":
			buste = 0.8 + 0.1 * s
			bg = Vector3(-1.0, 0.2, -0.2)
			bd = Vector3(-1.1 - 0.2 * s, -0.2, -0.2)
		"jeter":
			bg = Vector3(-0.8, 0.1, -0.6)
			bd = Vector3(-0.5 - 0.9 * maxf(s, 0.0), -0.2, -0.3)
			buste_yaw = 0.3 * s
		"accroupi":
			haut = -0.42
			buste = 0.35
			bg = Vector3(-1.0, 0.15, -0.5)
			bd = Vector3(-1.0 + 0.15 * sin(u * 6.0), -0.15, -0.5)
		"scier":
			buste = 0.3
			bg = Vector3(-1.0 - 0.2 * s, 0.15, -0.5)
			bd = Vector3(-1.0 - 0.2 * s, -0.15, -0.5)
			marche = 0.08 * s
		"piocher":
			var f3 := pow(0.5 + 0.5 * sin(u * 2.4), 2.0)
			buste = 0.15 + 0.5 * (1.0 - f3)
			bg = Vector3(-0.8 - 1.8 * f3, 0.05, -0.4)
			bd = Vector3(-0.8 - 1.8 * f3, -0.05, -0.4)
		"tirer":
			buste = 0.3 - 0.25 * s
			bg = Vector3(-1.2 + 0.4 * s, 0.15, -0.3)
			bd = Vector3(-1.2 + 0.4 * s, -0.15, -0.3)
		"trier":
			buste = 0.5
			bg = Vector3(-1.0, 0.25 + 0.2 * s, -0.4)
			bd = Vector3(-1.0, -0.25 + 0.2 * s, -0.4)
		"conduire":
			bg = Vector3(-1.0, 0.15, -0.5 + 0.15 * s)
			bd = Vector3(-1.0, -0.15, -0.5 - 0.15 * s)
			tete_yaw = 0.2 * sin(u * 0.5)
		"lance":
			buste = 0.1
			bg = Vector3(-1.2, 0.2, -0.5)
			bd = Vector3(-1.1, -0.05, -0.6)
			buste_yaw = 0.4 * sin(u * 0.8)
		"sauter":
			var j := absf(sin(u * 3.2))
			haut = 0.12 * j
			bg = Vector3(-0.3 - 2.4 * j, 0.6 * j, 0.0)
			bd = Vector3(-0.3 - 2.4 * j, -0.6 * j, 0.0)
		"client":
			tete_yaw = 0.7 * sin(u * 0.35)
			tete = 0.1 + 0.15 * maxf(sin(u * 0.5), 0.0)
			bd = Vector3(-0.5 * maxf(sin(u * 0.5 + 2.0), 0.0), -0.05, -0.6)
		"declamer":
			bg = Vector3(-1.6 - 0.4 * s, 0.4, -0.2)
			bd = Vector3(-1.2 + 0.3 * s, -0.5, -0.3)
			buste = -0.1
			tete = -0.2
			buste_yaw = 0.25 * sin(u * 0.6)
	_bras[0].rotation = Vector3(bg.x, 0, -bg.y)
	_bras[1].rotation = Vector3(bd.x, 0, -bd.y)
	_coudes[0].rotation = Vector3(bg.z, 0, 0)
	_coudes[1].rotation = Vector3(bd.z, 0, 0)
	_buste.rotation = Vector3(buste, buste_yaw, 0)
	_tete.rotation = Vector3(tete, tete_yaw, 0)
	# Jambes : assis, accroupi, en marche ou debout.
	var pas := 0.0
	var dz := 0.0
	var yaw := 0.0
	if va_et_vient > 0.0:
		var w := fposmod(u * 0.3, 2.0)
		dz = va_et_vient * (smoothstep(0.0, 1.0, w) if w < 1.0 else 1.0 - smoothstep(1.0, 2.0, w))
		var moving := absf(fposmod(w, 1.0) - 0.5) < 0.42
		pas = 0.45 * sin(u * 7.0) if moving else 0.0
		yaw = 0.0 if w < 1.0 else PI
	if assise:
		if silhouette != null:
			_bassin.position = Vector3(0, hauteur_assise + _hanche * 0.09, 0)
		else:
			_bassin.position = Vector3(0, hauteur_assise, 0)
			_buste.position = Vector3(0, 0.02, -0.05)
		for i in 2:
			_cuisses[i].rotation = Vector3(-PI * 0.5, 0, 0)
			_genoux[i].rotation = Vector3(PI * 0.5, 0, 0)
	elif anim == "accroupi":
		_bassin.position = Vector3(0, _hanche + haut, 0)
		for i in 2:
			_cuisses[i].rotation = Vector3(-1.4, 0, 0)
			_genoux[i].rotation = Vector3(2.2, 0, 0)
	else:
		_bassin.position = Vector3(0, _hanche + haut, marche)
		_cuisses[0].rotation = Vector3(-pas - marche * 0.6, 0, 0)
		_cuisses[1].rotation = Vector3(pas - marche * 0.6, 0, 0)
		_genoux[0].rotation = Vector3(maxf(pas, 0.0) * 0.8, 0, 0)
		_genoux[1].rotation = Vector3(maxf(-pas, 0.0) * 0.8, 0, 0)
	if silhouette != null:
		var hab: Node3D = Silhouettes.os(silhouette).get("habit")
		if hab != null:
			hab.rotation.x = -PI * 0.42 if assise else 0.0
	_corps.position = Vector3(0, 0, dz)
	_corps.rotation = Vector3(0, yaw, 0)
