class_name Portes
extends Node3D
## Portes qui s'ouvrent quand un habitant entre ou sort d'un bâtiment (Passants).
##
## Une porte n'existe que le temps d'un passage, près de la caméra : un vantail
## pivote sur ses gonds devant une embrasure sombre, reste ouvert tant que
## quelqu'un est à moins de 1,6 m, puis se referme et disparaît. Le mouvement
## suit EchelleTemps (en pause, la porte reste où elle est).

const MAX := 48
const LARGEUR := 0.95
const HAUTEUR := 2.15
## Ouverture complète (radians) et vitesse (fraction par seconde visible).
const ANGLE := 1.75
const VITESSE := 2.6
## Temps (visible) pendant lequel une porte refermée reste avant de disparaître.
const VIE := 1.5

## clé → {racine: Node3D, gond: Node3D, ouv: float, tenir: float, vie: float, pos: Vector3}
var portes: Dictionary = {}
var _bois: Array[StandardMaterial3D] = []
var _noir: StandardMaterial3D
var _vantail: BoxMesh
var _trou: BoxMesh
var _poignee: BoxMesh


func _ready() -> void:
	for c in [Color("6b4a2f"), Color("2f4f3a"), Color("3a4a5c"), Color("e7e2d6"), Color("7a2e2a")]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		_bois.append(m)
	_noir = StandardMaterial3D.new()
	_noir.albedo_color = Color("141414")
	_noir.roughness = 1.0
	_vantail = BoxMesh.new()
	_vantail.size = Vector3(LARGEUR - 0.05, HAUTEUR - 0.05, 0.06)
	_trou = BoxMesh.new()
	_trou.size = Vector3(LARGEUR, HAUTEUR, 0.02)
	_poignee = BoxMesh.new()
	_poignee.size = Vector3(0.12, 0.04, 0.05)


## Ouvre (ou garde ouverte) la porte décrite par cadre (voir Passants._cadre).
## Renvoie false si trop de portes sont déjà ouvertes.
func ouvrir(bid: int, cadre: Dictionary, tenir := 0.8) -> bool:
	if cadre.is_empty() or not bool(cadre.get("porte", false)):
		return false
	var cle := _cle(bid, cadre)
	var p: Dictionary = portes.get(cle, {})
	if p.is_empty():
		if portes.size() >= MAX:
			return false
		p = _creer(bid, cadre)
		portes[cle] = p
	p.tenir = maxf(float(p.tenir), tenir)
	p.vie = VIE
	return true


## Vrai si quelqu'un est assez près de la porte pour qu'elle reste ouverte.
static func proche(cadre: Dictionary, pos: Vector3) -> bool:
	if cadre.is_empty():
		return false
	var f: Vector3 = cadre.face
	return Vector2(pos.x - f.x, pos.z - f.z).length() < 1.6


func avancer(dt: float) -> void:
	if portes.is_empty() or dt <= 0.0:
		return
	var fin := []
	for cle in portes:
		var p: Dictionary = portes[cle]
		p.tenir = float(p.tenir) - dt
		var but := 1.0 if float(p.tenir) > 0.0 else 0.0
		p.ouv = move_toward(float(p.ouv), but, dt * VITESSE)
		# Ouverture amortie : rapide au début, douce en fin de course.
		var o := float(p.ouv)
		(p.gond as Node3D).rotation.y = -ANGLE * (1.0 - (1.0 - o) * (1.0 - o))
		if o <= 0.0 and float(p.tenir) <= 0.0:
			p.vie = float(p.vie) - dt
			if float(p.vie) <= 0.0:
				fin.append(cle)
	for cle in fin:
		(portes[cle].racine as Node).queue_free()
		portes.erase(cle)


func vider() -> void:
	for cle in portes:
		(portes[cle].racine as Node).queue_free()
	portes.clear()


static func _cle(bid: int, cadre: Dictionary) -> String:
	var f: Vector3 = cadre.face
	return "%d:%d:%d" % [bid, roundi(f.x), roundi(f.z)]


func _creer(bid: int, cadre: Dictionary) -> Dictionary:
	var n: Vector3 = cadre.n
	var f: Vector3 = cadre.face
	var racine := Node3D.new()
	racine.name = "Porte"
	add_child(racine)
	racine.position = f
	# Repère de la porte : -Z vers l'extérieur (vers la rue), X le long de la façade.
	racine.basis = Basis.looking_at(n, Vector3.UP)
	var trou := MeshInstance3D.new()
	trou.mesh = _trou
	trou.material_override = _noir
	trou.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trou.position = Vector3(0, HAUTEUR * 0.5, -0.02)
	racine.add_child(trou)
	# Gond sur un côté ; le vantail s'ouvre vers l'intérieur, comme une porte d'entrée.
	var gond := Node3D.new()
	gond.position = Vector3(-LARGEUR * 0.5, 0, -0.06)
	racine.add_child(gond)
	var v := MeshInstance3D.new()
	v.mesh = _vantail
	v.material_override = _bois[absi(bid) % _bois.size()]
	v.position = Vector3(LARGEUR * 0.5, HAUTEUR * 0.5, 0)
	gond.add_child(v)
	var pg := MeshInstance3D.new()
	pg.mesh = _poignee
	pg.material_override = _noir
	pg.position = Vector3(LARGEUR * 0.82, 1.0, -0.05)
	gond.add_child(pg)
	return {"racine": racine, "gond": gond, "ouv": 0.0, "tenir": 0.0, "vie": VIE, "pos": f}
