class_name AmbiancesSonores
extends Node
## Ambiances sonores de la scène Terre : ce qu'on entend dépend de ce que regarde
## la caméra et de sa hauteur.
##
## Nappes en boucle (bus Ambiance), mélangées en douceur :
## - nature le jour (vent dans les feuilles, oiseaux) ou la nuit (grillons s'il
##   fait plus de 10 °C, chouette) loin des bâtiments ;
## - ville le jour (brouhaha, passants, pigeons) ou la nuit, selon le nombre de
##   bâtiments autour du point regardé ;
## - trafic selon les véhicules proches ; pluie, vent (rafales, orage, altitude), mer ;
## - chantiers : un son 3D sur les chantiers en activité les plus proches.
## Plus la caméra monte, plus les détails s'effacent et plus le vent domine.
## Sons ponctuels : tonnerre après les éclairs, cloches à midi, coq au lever du jour.

const NAPPES := ["nature_jour", "nature_nuit", "ville_jour", "ville_nuit", "trafic", "pluie", "vent", "mer"]
## Volume de chaque nappe à poids 1 (dB) : équilibre du mélange.
const GAIN := {"nature_jour": -2.0, "nature_nuit": -3.0, "ville_jour": -1.0, "ville_nuit": -2.0,
	"trafic": -3.0, "pluie": 0.0, "vent": -2.0, "mer": -1.0}
const RAYON_VILLE := 160.0
const RAYON_TRAFIC := 90.0
const MAX_CHANTIERS := 3
## Cloches et coq : au plus une fois toutes les 4 minutes réelles (temps accéléré).
const REPOS_CLOCHES := 240.0

var rig: Node3D
var ambiance: DayNight
var world: TerrainWorld
var buildings: BuildingSystem
var traffic: Node
var vue_sol: Node
## Fonctions qui renvoient des positions de chantiers bruyants (BatimentsVie, ChantiersVoies).
var sources_chantiers: Array[Callable] = []

## Poids voulus (0..1) et poids actuels (lissés).
var cible := {}
var actuel := {}
var _players := {}
var _chantiers: Array[AudioStreamPlayer3D] = []
var _timer := 0.0
var _flash_prev := 0.0
var _tonnerres: Array = []
var _heure_prev := -1.0
var _repos_cloches := 0.0
var _repos_coq := 0.0
## Valeurs du dernier calcul (pour le test et l'aide au réglage).
var mesure := {}
var _rng := RandomNumberGenerator.new()


func setup(r: Node3D, a: DayNight, w: TerrainWorld, b: BuildingSystem, t: Node, vs: Node) -> void:
	rig = r
	ambiance = a
	world = w
	buildings = b
	traffic = t
	vue_sol = vs


func _ready() -> void:
	_rng.randomize()
	for id in NAPPES:
		var p := AudioStreamPlayer.new()
		p.name = "Nappe_" + id
		p.stream = Son.flux("ambiance/" + id, true)
		p.bus = "Ambiance"
		p.volume_db = -80.0
		add_child(p)
		_players[id] = p
		cible[id] = 0.0
		actuel[id] = 0.0
	var ch := Son.flux("ambiance/chantier", true)
	for i in MAX_CHANTIERS:
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "Chantier%d" % i
		p3.stream = ch
		p3.bus = "Ambiance"
		p3.unit_size = 18.0
		p3.max_distance = 260.0
		p3.volume_db = -2.0
		add_child(p3)
		_chantiers.append(p3)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		calculer()
		_placer_chantiers()
	for id in NAPPES:
		var w := move_toward(float(actuel[id]), float(cible[id]), delta * 0.35)
		actuel[id] = w
		var p: AudioStreamPlayer = _players[id]
		if p.stream == null:
			continue
		if w > 0.003:
			p.volume_db = linear_to_db(w) + float(GAIN[id])
			if not p.playing:
				p.play(_rng.randf() * maxf(p.stream.get_length() - 1.0, 0.0))
		elif p.playing:
			p.stop()
	_ponctuels(delta)


## Centre de ce qu'on écoute : le point regardé (vue de dessus) ou la caméra (vue au sol).
func _ecoute() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if vue_sol != null and int(vue_sol.get("vue")) != 0 and cam != null:
		return cam.global_position
	return rig.global_position if rig != null else Vector3.ZERO


func _hauteur() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or rig == null:
		return 40.0
	return maxf(cam.global_position.y - rig.global_position.y, 1.0)


## Calcule les poids de chaque nappe (deux fois par seconde).
func calculer() -> void:
	var c := _ecoute()
	var h := _hauteur()
	if vue_sol != null and int(vue_sol.get("vue")) != 0:
		h = 2.0
	var pres := clampf(1.0 - (h - 60.0) / 700.0, 0.0, 1.0)
	var tres_pres := clampf(1.0 - (h - 25.0) / 260.0, 0.0, 1.0)
	var altitude := clampf((h - 250.0) / 900.0, 0.0, 1.0)
	var ville := _densite(c)
	var trafic := _trafic(c)
	var mer := _mer(c)
	var nuit := ambiance.night if ambiance != null else 0.0
	var jour := 1.0 - nuit
	var pluie := 0.0
	var orage := 0.0
	var neige := 0.0
	var chaud := 1.0
	if ambiance != null and ambiance.weather != null:
		var m := ambiance.weather
		pluie = m.precip * (1.0 - m.snow)
		neige = m.precip * m.snow
		orage = m.storm
		chaud = clampf((m.temperature - 8.0) / 6.0, 0.0, 1.0)
	var calme := 1.0 - 0.6 * pluie - 0.4 * neige
	var nature := (1.0 - ville) * pres
	cible.nature_jour = nature * jour * calme
	cible.nature_nuit = nature * nuit * calme * (0.35 + 0.65 * chaud)
	cible.ville_jour = ville * pres * jour * (1.0 - 0.3 * pluie)
	cible.ville_nuit = ville * pres * nuit
	cible.trafic = trafic * tres_pres
	cible.pluie = pluie * (0.45 + 0.55 * pres)
	cible.vent = clampf(maxf(maxf(0.18 * (1.0 - ville) * pres, orage * 0.9), maxf(pluie * 0.3 + neige * 0.5, altitude * 0.7)), 0.0, 1.0)
	cible.mer = mer * (0.3 + 0.7 * pres)
	mesure = {"hauteur": h, "ville": ville, "trafic": trafic, "mer": mer, "nuit": nuit, "pluie": pluie, "orage": orage}


## 0 en rase campagne, 1 en ville (bâtiments à moins de RAYON_VILLE).
func _densite(c: Vector3) -> float:
	if buildings == null:
		return 0.0
	var n := 0.0
	var r2 := RAYON_VILLE * RAYON_VILLE
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var dx := float(b.x) - c.x
		var dz := float(b.z) - c.z
		var d2 := dx * dx + dz * dz
		if d2 < r2:
			n += 1.0 - sqrt(d2) / RAYON_VILLE * 0.6
	return clampf(n / 18.0, 0.0, 1.0)


func _trafic(c: Vector3) -> float:
	if traffic == null or not ("vehicles" in traffic):
		return 0.0
	var n := 0.0
	for v in traffic.vehicles:
		var body = v.get("body", null)
		if body == null or not is_instance_valid(body):
			continue
		var d := (body as Node3D).global_position.distance_to(c)
		if d < RAYON_TRAFIC:
			n += 1.0 - d / RAYON_TRAFIC
	return clampf(n / 4.0, 0.0, 1.0)


## Part de mer (ou de grand plan d'eau sous le niveau de la mer) autour du point écouté.
func _mer(c: Vector3) -> float:
	if world == null:
		return 0.0
	var eau := 0
	var vus := 0
	for r in [0.0, 60.0, 140.0]:
		for k in (1 if r == 0.0 else 8):
			var a := TAU * k / 8.0
			var cell := Vector2i(floori(c.x + cos(a) * r), floori(c.z + sin(a) * r))
			var hh := world.cell_height(cell)
			if is_nan(hh):
				continue
			vus += 1
			if hh < -0.5:
				eau += 1
	return 0.0 if vus == 0 else clampf(float(eau) / vus * 2.0, 0.0, 1.0)


## Le son de chantier suit les chantiers en activité les plus proches.
func _placer_chantiers() -> void:
	var c := _ecoute()
	var pts: Array = []
	for f in sources_chantiers:
		if f.is_valid():
			pts.append_array(f.call())
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(c) < b.distance_squared_to(c))
	for i in _chantiers.size():
		var p := _chantiers[i]
		if i < pts.size() and p.stream != null:
			p.global_position = pts[i]
			if not p.playing:
				p.play(_rng.randf() * maxf(p.stream.get_length() - 1.0, 0.0))
		elif p.playing:
			p.stop()


## Tonnerre, cloches de midi, coq du matin.
func _ponctuels(delta: float) -> void:
	_repos_cloches -= delta
	_repos_coq -= delta
	if ambiance == null:
		return
	var m := ambiance.weather
	if m != null:
		# Un éclair : le tonnerre suit, d'autant plus tard que l'orage est loin.
		if m.flash > 0.9 and _flash_prev <= 0.9:
			_tonnerres.append(_rng.randf_range(0.4, 3.5))
		_flash_prev = m.flash
	for i in range(_tonnerres.size() - 1, -1, -1):
		_tonnerres[i] -= delta
		if _tonnerres[i] <= 0.0:
			_tonnerres.remove_at(i)
			Son.jouer("tonnerre_%d" % (1 + _rng.randi() % 2), -3.0 - _rng.randf() * 6.0, 0.08, "Ambiance")
	var hr := ambiance.local_hour()
	if _heure_prev >= 0.0 and ambiance.speed_index > 0:
		var ville := float(mesure.get("ville", 0.0))
		var pres := float(mesure.get("hauteur", 999.0)) < 500.0
		if _passe(_heure_prev, hr, 12.0) and ville > 0.15 and pres and _repos_cloches <= 0.0:
			_repos_cloches = REPOS_CLOCHES
			Son.jouer("cloches", -8.0, 0.0, "Ambiance")
		var lever := 6.5
		if _passe(_heure_prev, hr, lever) and ville < 0.7 and pres and _repos_coq <= 0.0:
			_repos_coq = REPOS_CLOCHES
			Son.jouer("coq", -10.0, 0.05, "Ambiance")
	_heure_prev = hr


static func _passe(avant: float, apres: float, h: float) -> bool:
	if apres >= avant:
		return avant < h and apres >= h
	return avant < h or apres >= h
