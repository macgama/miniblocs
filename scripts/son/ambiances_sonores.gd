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
## Partie historique avant 1900 : la ville et le trafic changent de son (sabots,
## roues cerclées, forge, crieurs ; attelages au lieu des moteurs) et, dès 1830,
## un sifflet de locomotive à vapeur se fait entendre de temps en temps.
##
## Saisons : corneilles et silence feutré en hiver (au lieu des oiseaux),
## cigales les après-midi chauds d'été, grenouilles les nuits douces.
## Lieux de la ville, en 3D sur place (LIEUX) : cour d'école pendant les heures
## de classe, aire de jeux, manèges, zoo, usines et ateliers, ferme, piscine
## l'été, terrasse de café, quai de gare, port, tribune pendant un match,
## marché et fête de quartier, incendie en cours. Sonnerie de l'école le matin
## et à la sortie (cloche à main avant 1920).
## Vitesse du temps (EchelleTemps) : en pause, tout ce qui bouge se tait ou se
## fige (trafic, chantiers, lieux, sirènes) ; seuls la nature et la météo restent.

const NAPPES := ["nature_jour", "nature_nuit", "ville_jour", "ville_nuit", "trafic", "pluie", "vent", "mer",
	"cigales", "grenouilles"]
## Volume de chaque nappe à poids 1 (dB) : équilibre du mélange.
const GAIN := {"nature_jour": -2.0, "nature_nuit": -3.0, "ville_jour": -1.0, "ville_nuit": -2.0,
	"trafic": -3.0, "pluie": 0.0, "vent": -2.0, "mer": -1.0, "cigales": -4.0, "grenouilles": -3.0}
## Saisons de Saisons.saison (0 hiver, 1 printemps, 2 été, 3 automne ; 10-11 tropiques).
const HIVER := 0
const PRINTEMPS := 1
const ETE := 2
## Lieux de la ville : boucle mono (assets/son/ambiance/<id>.ogg) jouée sur place.
## n : nombre de lieux de ce genre entendus à la fois ; db : volume ; unite : taille
## (m) à laquelle le son est à plein volume ; portee : au-delà, plus rien.
const LIEUX := {
	"cour_recre": {"n": 2, "db": -3.0, "unite": 14.0, "portee": 220.0},
	"manege": {"n": 2, "db": -2.0, "unite": 20.0, "portee": 300.0},
	"zoo": {"n": 1, "db": -2.0, "unite": 20.0, "portee": 260.0},
	"usine": {"n": 2, "db": -4.0, "unite": 16.0, "portee": 240.0},
	"ferme": {"n": 2, "db": -4.0, "unite": 14.0, "portee": 200.0},
	"piscine": {"n": 1, "db": -3.0, "unite": 14.0, "portee": 200.0},
	"terrasse": {"n": 2, "db": -5.0, "unite": 8.0, "portee": 120.0},
	"gare": {"n": 1, "db": -3.0, "unite": 18.0, "portee": 260.0},
	"port": {"n": 1, "db": -2.0, "unite": 20.0, "portee": 300.0},
	"foule_stade": {"n": 1, "db": 0.0, "unite": 40.0, "portee": 600.0},
	"feu": {"n": 2, "db": 0.0, "unite": 14.0, "portee": 260.0},
}
## Rayon de recherche des lieux autour du point écouté (m).
const RAYON_LIEUX := 320.0
## Heures de la sonnerie de l'école (entrée et sortie).
const SONNERIES := [8.25, 16.5]
const RAYON_VILLE := 160.0
const RAYON_TRAFIC := 90.0
const MAX_CHANTIERS := 3
## Cloches et coq : au plus une fois toutes les 4 minutes réelles (temps accéléré).
const REPOS_CLOCHES := 240.0
## Nappes remplacées avant 1900 (partie historique).
const NAPPES_ANCIENNES := {"ville_jour": "ville_jour_ancien", "ville_nuit": "ville_nuit_ancien",
	"trafic": "trafic_attelages"}
const ANNEE_ANCIENNE := 1900
const ANNEE_VAPEUR := 1830

var rig: Node3D
var ambiance: DayNight
var world: TerrainWorld
var buildings: BuildingSystem
var traffic: Node
var vue_sol: Node
## Branchés par la scène Terre après setup (tous facultatifs).
var saisons: Node
var evenements: Node
var stations: Node
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
var _repos_sifflet := 60.0
var _repos_sonnerie := 0.0
## Lecteurs 3D des lieux : id -> Array[AudioStreamPlayer3D].
var _lieux := {}
## Lieux entendus au dernier calcul : id -> nombre (pour le test et l'aide au réglage).
var lieux_actifs := {}
## Saison forcée (tests) : -1 = celle de la partie.
var saison_forcee := -1
var hiver := false
## Le temps est en pause : ce qui bouge s'est tu.
var en_pause := false
## Sons figés par la pause au dernier passage (chantiers, lieux, sirènes).
var figes := 0
## Sons de la ville d'avant 1900 en cours.
var ancien := false
var _epoque_pret := false
## Année forcée (tests) : -1 = celle de la partie.
var annee_forcee := -1
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
	_maj_epoque()
	for id in LIEUX:
		var l: Dictionary = LIEUX[id]
		var arr: Array[AudioStreamPlayer3D] = []
		for i in int(l.n):
			var p3 := AudioStreamPlayer3D.new()
			p3.name = "Lieu_%s_%d" % [id, i]
			p3.stream = Son.flux("ambiance/" + id, true)
			p3.bus = "Ambiance"
			p3.unit_size = float(l.unite)
			p3.max_distance = float(l.portee)
			p3.volume_db = float(l.db)
			add_child(p3)
			arr.append(p3)
		_lieux[id] = arr
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
		_maj_epoque()
		_maj_saison()
		calculer()
		_placer_chantiers()
		_placer_lieux()
		_maj_pause()
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


func _annee() -> int:
	if annee_forcee >= 0:
		return annee_forcee
	return Epoques.annee() if Epoques.actif() else 0


## Change les sons de ville et de trafic quand on passe le cap de 1900.
func _maj_epoque() -> void:
	var a := _annee()
	var v := a > 0 and a < ANNEE_ANCIENNE
	if v == ancien and _epoque_pret:
		return
	ancien = v
	_epoque_pret = true
	for id in NAPPES_ANCIENNES:
		var p: AudioStreamPlayer = _players.get(id)
		if p == null:
			continue
		var fichier: String = NAPPES_ANCIENNES[id] if ancien else id
		var st := Son.flux("ambiance/" + fichier, true)
		if st == null or st == p.stream:
			continue
		var jouait := p.playing
		p.stream = st
		if jouait:
			p.play(_rng.randf() * maxf(st.get_length() - 1.0, 0.0))


func _saison() -> int:
	if saison_forcee >= 0:
		return saison_forcee
	if saisons != null and is_instance_valid(saisons) and "saison" in saisons:
		return int(saisons.get("saison"))
	return -1


## En hiver, la nature de jour devient celle de l'hiver (corneilles, rouge-gorge, vent froid).
func _maj_saison() -> void:
	var v := _saison() == HIVER
	if v == hiver:
		return
	hiver = v
	var p: AudioStreamPlayer = _players.get("nature_jour")
	if p == null:
		return
	var st := Son.flux("ambiance/" + ("nature_hiver" if hiver else "nature_jour"), true)
	if st == null or st == p.stream:
		return
	var jouait := p.playing
	p.stream = st
	if jouait:
		p.play(_rng.randf() * maxf(st.get_length() - 1.0, 0.0))


## Pause du temps : chantiers, lieux et sirènes se figent (et repartent d'où ils étaient).
func _maj_pause() -> void:
	en_pause = EchelleTemps.en_pause()
	var tous: Array = []
	tous.append_array(_chantiers)
	for id in _lieux:
		tous.append_array(_lieux[id])
	if traffic != null and "vehicles" in traffic:
		for v in traffic.vehicles:
			var sp = v.get("siren_player", null)
			if sp != null and is_instance_valid(sp):
				tous.append(sp)
	figes = 0
	for p in tous:
		var p3 := p as AudioStreamPlayer3D
		p3.stream_paused = en_pause
		if en_pause and p3.playing:
			figes += 1


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
	var temp := 15.0
	if ambiance != null and ambiance.weather != null:
		temp = ambiance.weather.temperature
	var sa := _saison()
	cible.nature_jour = nature * jour * calme
	cible.nature_nuit = nature * nuit * calme * (0.35 + 0.65 * chaud) * (0.4 if hiver else 1.0)
	# Cigales : après-midi chauds d'été (ou toute l'année sous les tropiques), dans la verdure.
	var ete := sa == ETE or sa >= 10 or (sa < 0 and temp >= 26.0)
	var hr := ambiance.local_hour() if ambiance != null else 12.0
	var apres_midi := clampf(1.0 - absf(hr - 15.0) / 5.0, 0.0, 1.0)
	cible.cigales = (1.0 - ville * 0.6) * pres * calme * apres_midi * clampf((temp - 22.0) / 6.0, 0.0, 1.0) * (1.0 if ete else 0.0)
	# Grenouilles : nuits douces du printemps et de l'été, plus fort près de l'eau.
	var doux := sa == PRINTEMPS or sa == ETE or sa >= 10 or (sa < 0 and temp >= 14.0)
	cible.grenouilles = nature * nuit * calme * (0.35 + 0.65 * minf(1.0, _mer(c) * 2.0 + 0.3)) \
		* clampf((temp - 9.0) / 6.0, 0.0, 1.0) * (1.0 if doux else 0.0) * 0.8
	cible.ville_jour = ville * pres * jour * (1.0 - 0.3 * pluie)
	cible.ville_nuit = ville * pres * nuit
	en_pause = EchelleTemps.en_pause()
	# En pause, les véhicules sont arrêtés : plus de trafic, la rue se calme.
	cible.trafic = 0.0 if en_pause else trafic * tres_pres
	if en_pause:
		cible.ville_jour = float(cible.ville_jour) * 0.5
		cible.ville_nuit = float(cible.ville_nuit) * 0.6
	cible.pluie = pluie * (0.45 + 0.55 * pres)
	cible.vent = clampf(maxf(maxf(0.18 * (1.0 - ville) * pres, orage * 0.9), maxf(pluie * 0.3 + neige * 0.5, altitude * 0.7)), 0.0, 1.0)
	cible.mer = mer * (0.3 + 0.7 * pres)
	mesure = {"hauteur": h, "ville": ville, "trafic": trafic, "mer": mer, "nuit": nuit, "pluie": pluie, "orage": orage,
		"temperature": temp, "saison": sa}


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
	_repos_sifflet -= delta
	_repos_sonnerie -= delta
	if ancien and _repos_sifflet <= 0.0 and not en_pause:
		_repos_sifflet = _rng.randf_range(90.0, 240.0)
		var a := _annee()
		var pres_v := float(mesure.get("hauteur", 999.0)) < 600.0
		if a >= ANNEE_VAPEUR and pres_v and float(mesure.get("ville", 0.0)) > 0.05:
			Son.jouer("sifflet_vapeur", -14.0 - _rng.randf() * 6.0, 0.05, "Ambiance")
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
		# Sonnerie de l'école (entrée, sortie) : électrique, ou cloche à main avant 1920.
		for s in SONNERIES:
			if _passe(_heure_prev, hr, float(s)) and pres and _repos_sonnerie <= 0.0:
				var ec := _ecole_proche(_ecoute())
				if ec != Vector3.INF:
					_repos_sonnerie = REPOS_CLOCHES * 0.5
					var a := _annee()
					Son.jouer_a("cloche_main" if a > 0 and a < 1920 else "sonnerie_ecole", ec, -4.0, 300.0)
	_heure_prev = hr


static func _passe(avant: float, apres: float, h: float) -> bool:
	if apres >= avant:
		return avant < h and apres >= h
	return avant < h or apres >= h


# --- Lieux de la ville -------------------------------------------------------------------

## Son d'un bâtiment selon l'heure et le temps qu'il fait ("" : silencieux).
## Renvoie [id du lieu, gain 0..1].
static func lieu_de(type_id: String, heure: float, temp: float, pluie: float) -> Array:
	var base := BuildingCatalog.base_of(type_id)
	var cat := String(BuildingCatalog.get_type(type_id).get("cat", ""))
	var sec := pluie < 0.25
	match base:
		"ecole":
			# Heures de classe (la cantine de midi compte aussi : on joue dans la cour).
			if heure >= 8.0 and heure < 16.75:
				var recre := (heure >= 10.0 and heure < 10.5) or (heure >= 12.0 and heure < 13.5) or (heure >= 15.5 and heure < 16.75)
				return ["cour_recre", (1.0 if recre else 0.35) * (1.0 if sec else 0.4)]
			return ["", 0.0]
		"aire_jeux":
			return ["cour_recre", 0.6] if heure >= 9.0 and heure < 19.5 and sec and temp > 4.0 else ["", 0.0]
		"piscine":
			return ["piscine", clampf((temp - 18.0) / 6.0, 0.0, 1.0)] if heure >= 10.0 and heure < 19.5 and sec else ["", 0.0]
		"cafe":
			return ["terrasse", 1.0 if temp >= 14.0 else 0.5] if heure >= 8.0 and heure < 23.5 and sec else ["", 0.0]
		"ferme":
			return ["ferme", 1.0] if heure >= 5.0 and heure < 21.5 else ["", 0.0]
		"campement":
			return ["", 0.0]
	match cat:
		"parc":
			return ["manege", 1.0 if sec else 0.5] if heure >= 10.0 and heure < 23.0 else ["", 0.0]
		"zoo":
			return ["zoo", 1.0] if heure >= 7.5 and heure < 19.5 else ["zoo", 0.2]
		"industrie":
			return ["usine", 1.0] if heure >= 6.0 and heure < 22.0 else ["usine", 0.25]
	return ["", 0.0]


## Cherche les lieux bruyants autour du point écouté et y place les sons.
func _placer_lieux() -> void:
	var c := _ecoute()
	var h := float(mesure.get("hauteur", 40.0))
	var pres := clampf(1.0 - (h - 80.0) / 900.0, 0.0, 1.0)
	var hr := ambiance.local_hour() if ambiance != null else 12.0
	var temp := float(mesure.get("temperature", 15.0))
	var pluie := float(mesure.get("pluie", 0.0))
	# id -> [[distance², position, gain], …]
	var trouves := {}
	var r2 := RAYON_LIEUX * RAYON_LIEUX
	if buildings != null and pres > 0.0:
		for bid in buildings.buildings:
			var b: Dictionary = buildings.buildings[bid]
			var fp := BuildingCatalog.footprint(String(b.t), int(b.get("r", 0)))
			var x := float(b.x) + fp.x * 0.5
			var z := float(b.z) + fp.y * 0.5
			var d2 := (x - c.x) * (x - c.x) + (z - c.z) * (z - c.z)
			if d2 > r2:
				continue
			var l := lieu_de(String(b.t), hr, temp, pluie)
			if String(l[0]) == "" or float(l[1]) <= 0.0 or buildings.en_chantier(int(bid)):
				continue
			_ajouter(trouves, String(l[0]), d2, Vector3(x, _sol(x, z, c.y), z), float(l[1]))
	if stations != null and is_instance_valid(stations) and "stations" in stations:
		for sid in stations.stations:
			var st: Dictionary = stations.stations[sid]
			var t := String(st.get("type", ""))
			if t != "gare" and t != "port":
				continue
			var p: Vector3 = st.get("pos", Vector3.INF)
			if p == Vector3.INF:
				continue
			var d2 := (p.x - c.x) * (p.x - c.x) + (p.z - c.z) * (p.z - c.z)
			if d2 <= r2:
				var g := 1.0 if t == "port" or (hr >= 5.0 and hr < 24.0) else 0.3
				_ajouter(trouves, t, d2, p, g)
	if evenements != null and is_instance_valid(evenements):
		if evenements.has_method("en_cours"):
			for e in evenements.en_cours():
				var p: Vector3 = e.get("pos", Vector3.INF)
				if p == Vector3.INF:
					continue
				var d2 := p.distance_squared_to(c)
				match String(e.type):
					"match":
						var aff := float((e.get("data", {}) as Dictionary).get("affluence", 500))
						_ajouter(trouves, "foule_stade", d2, p, clampf(0.35 + aff / 4000.0, 0.35, 1.0))
					"marche":
						_ajouter(trouves, "terrasse", d2, p, 1.0)
					"fete":
						_ajouter(trouves, "manege", d2, p, 0.7)
		if "incidents" in evenements:
			for id in evenements.incidents:
				var inc: Dictionary = evenements.incidents[id]
				if String(inc.get("type", "")) != "incendie" or String(inc.get("etat", "")) == "resolu":
					continue
				var p: Vector3 = inc.get("position", Vector3.ZERO)
				_ajouter(trouves, "feu", p.distance_squared_to(c), p, clampf(0.5 + 0.25 * int(inc.get("gravite", 1)), 0.5, 1.0))
	lieux_actifs.clear()
	for id in _lieux:
		var liste: Array = trouves.get(id, [])
		liste.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var players: Array = _lieux[id]
		for i in players.size():
			var p3: AudioStreamPlayer3D = players[i]
			if i < liste.size() and p3.stream != null and pres > 0.0:
				p3.global_position = liste[i][1]
				p3.volume_db = float(LIEUX[id].db) + linear_to_db(maxf(float(liste[i][2]) * pres, 0.01))
				if not p3.playing:
					p3.play(_rng.randf() * maxf(p3.stream.get_length() - 1.0, 0.0))
					p3.stream_paused = en_pause
				lieux_actifs[id] = int(lieux_actifs.get(id, 0)) + 1
			elif p3.playing:
				p3.stop()


func _ajouter(trouves: Dictionary, id: String, d2: float, pos: Vector3, gain: float) -> void:
	if not LIEUX.has(id):
		return
	var portee := float(LIEUX[id].portee)
	if d2 > portee * portee:
		return
	if not trouves.has(id):
		trouves[id] = []
	(trouves[id] as Array).append([d2, pos, gain])


func _sol(x: float, z: float, defaut: float) -> float:
	if world == null:
		return defaut
	var hh := world.cell_height(Vector2i(floori(x), floori(z)))
	return defaut if is_nan(hh) else hh + 2.0


## École la plus proche du point écouté (Vector3.INF : aucune à portée).
func _ecole_proche(c: Vector3) -> Vector3:
	if buildings == null:
		return Vector3.INF
	var best := Vector3.INF
	var bd := 260.0 * 260.0
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if BuildingCatalog.base_of(String(b.t)) != "ecole" or buildings.en_chantier(int(bid)):
			continue
		var fp := BuildingCatalog.footprint(String(b.t), int(b.get("r", 0)))
		var x := float(b.x) + fp.x * 0.5
		var z := float(b.z) + fp.y * 0.5
		var d2 := (x - c.x) * (x - c.x) + (z - c.z) * (z - c.z)
		if d2 < bd:
			bd = d2
			best = Vector3(x, _sol(x, z, c.y), z)
	return best


# --- Sirènes ----------------------------------------------------------------------------

## Boucle de sirène (assets/son/ambiance/) d'un véhicule d'urgence selon son modèle
## et l'année de la partie (0 : moderne). Avant 1920 : pompiers et ambulances à
## cheval avec cloche, sergents de ville au sifflet.
static func sirene_de(model: String, annee: int) -> String:
	var m := model.to_lower()
	var police := m.contains("police") or m.contains("gendarm")
	if annee > 0 and annee < 1920:
		return "sifflet_police" if police else "cloche_pompiers"
	if m.ends_with("_us"):
		return "sirene_us"
	if m.contains("japon"):
		return "sirene_japon"
	if police:
		return "sirene_police"
	if m.contains("ambulance") or m.contains("smur") or m.contains("samu"):
		return "sirene_samu"
	return "sirene_pompiers"
