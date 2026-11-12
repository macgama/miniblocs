class_name Population
extends Node3D
## Les habitants de la ville : chacun a un âge, un foyer, un logement, un
## travail ou une école, des loisirs, un emploi du temps et un budget.
##
## - Les logements (champ "logements" des bâtiments) accueillent des foyers
##   qui emménagent peu à peu. Les emplois et les places d'école sont
##   attribués au plus proche.
## - Étapes de la vie : bébé (0-2 ans), élève (3-17 ans, maternelle → lycée),
##   adulte (18-63 ans : emploi ou recherche d'emploi), retraité (64 ans et plus).
## - L'activité du moment (dormir, trajet, école, travail, loisir, courses)
##   est calculée à partir de l'heure locale du cycle jour/nuit : un élève
##   inscrit dans une école y est bien pendant les heures de classe.
## - Économie (débuts) : salaires et dépenses des foyers, recettes et
##   dépenses de la ville payées chaque jour de jeu dans la caisse.
## Données sérialisables (section "habitants" de la sauvegarde).

signal changed
signal message(text: String)
signal building_selected(bid: int)
## L'habitant suivi a changé (CycleVie.followed).
signal follow_changed
## Clic sur un habitant visible dans la rue.
signal person_clicked(pid: int)
## Questions du personnage principal (PersonnagePrincipal.questions).
signal questions_changed

const LIFE_SPEEDS := [1.0, 12.0, 365.0]
const LIFE_SPEED_NAMES := ["Réaliste (1 an = 1 an)", "Normale (1 an = 1 mois)", "Très rapide (1 an = 1 jour)"]
## Par défaut : 1 an de vie = 1 mois de jeu (choix de Gaël) : une vie de 80 ans dure
## environ 13 h de jeu à 100 min/s, et une année de partie (2 h) fait vieillir de 12 ans.
const DEFAULT_LIFE_SPEED := 1
const RETIREMENT_AGE := 64
const ADULT_AGE := 18
const SCHOOL_AGE := 3
## Places par école quand le catalogue ne donne pas de « visiteurs ».
const DEFAULT_SCHOOL_SEATS := 250
## Foyers qui emménagent par heure de jeu, en part des logements libres.
const ARRIVAL_RATE := 0.6
## Distance à pied, à vélo (m).
const WALK_MAX := 1200.0
const BIKE_MAX := 4000.0

# --- Économie (euros par mois) ---
const TAXE_FONCIERE := 95.0 # par foyer
const CFE := 60.0 # par emploi occupé (entreprises privées)
const DOTATION := 15.0 # dotation de l'État par habitant
const CHARGES := 1.45 # salaire net → coût employeur
const ENTRETIEN := 0.0008 # part du prix des bâtiments publics par mois
const PENSION := 1450.0
const ALLOCATION := 1050.0 # chômage
const BOURSE := 500.0 # étudiant (bourse, petits boulots)
const LOYER_MAISON := 1050.0
const LOYER_APPART := 720.0
const COURSES := 260.0 # par personne
const VOITURE := 160.0
const DAYS_PER_MONTH := 30.44

@export var world_path: NodePath
@export var buildings_path: NodePath
@export var transport_path: NodePath
@export var ambiance_path: NodePath

var world: TerrainWorld
var buildings: BuildingSystem
var transport: TransportSystem
var ambiance: DayNight

## id -> {id, f (foyer), p (prénom), n (nom), s ("F"/"H"), nj (jour de vie de naissance),
##        r ("adulte"/"enfant"), job (bâtiment ou -1), met (métier), sch (école ou -1), hob [loisirs]}
var persons: Dictionary = {}
## id -> {id, b (logement), reg (région des noms), ep (épargne €), car (voitures), m [habitants]}
var households: Dictionary = {}
var next_pid := 1
var next_hid := 1
## Horloge de la vie, en jours (avance avec le temps du jeu × life_speed).
var life_clock := 0.0
var life_speed_index := DEFAULT_LIFE_SPEED
var arrivals := true
## Dernier instant de jeu vu (secondes Unix) et numéro du dernier jour traité.
var last_unix := -1.0
var last_day := -1
## Comptes de la ville : mois en cours et mois précédent ({catégorie: euros}).
var ledger := {"mois": {}, "precedent": {}, "jours": 0}
var rng := RandomNumberGenerator.new()

# Index (recalculés) : bâtiment -> foyers, employés, élèves.
var by_home: Dictionary = {}
var by_job: Dictionary = {}
var by_school: Dictionary = {}
## Bâtiments connus : bid -> {t, cat, log, emp, seats, pos, public}
var known: Dictionary = {}

## Bâtiments en plus de ceux du catalogue (intérieurs en murs fins) :
## fonction qui rend { bid : fiche } (mêmes champs que _info_of, plus name,
## conf, attr, valeur, loyer, tf). Voir Mobilier.population_info().
var extra_buildings: Callable
## Bâtiment en plus sous une case (fiche au clic) : fonction (Vector2i) -> bid ou -1.
var extra_pick: Callable
## Satisfaction venue d'ailleurs (commerces de l'économie locale) : f(p) -> [delta, raisons].
var extra_satisfaction: Callable

var _arrival_acc: Dictionary = {}
var _money_frac := 0.0
var _step_acc := 0.0
var _last_step_ms := 0
var _venue_cache: Dictionary = {}
var _transit_cache: Dictionary = {}
var _selected := -1
var _marker: MeshInstance3D
var _marker_label: Label3D
var _press := Vector2.ZERO
var _arrival_news := Vector2i.ZERO
var _news_timer := 0.0
var _now := {}
## Cycle de vie : CV, familles, santé, défunts, habitant suivi.
var vie: CycleVie
## Fonctions (p, n, plan) -> plan qui changent la journée d'un habitant (événements).
var plan_hooks: Array[Callable] = []
## Caméra de la partie (pour suivre un habitant) et suivi caméra actif.
var rig: Node3D
var follow_camera := true
var _follow_marker: MeshInstance3D
var _follow_label: Label3D
var _follow_timer := 0.0
var _follow_target := Vector3.ZERO
var _follow_set := Vector3.INF
## Habitants visibles près de la caméra.
var passants: Passants
## Ordre « Aller à… » en attente d'un clic sur un bâtiment (habitant, ou -1).
var order_pick := -1
## Habitant incarné en vue au sol (-1 : aucun).
var _incarne := -1
var _player_id := ""
## Personnage principal du joueur (né en ville, ses choix).
var principal: PersonnagePrincipal
## Personnel des bâtiments : fermés faute d'employés, sous-effectif (scripts/metiers).
var effectif: Effectif
## Clic sur un employé visible (vue métiers) : Callable(écran, caméra) -> pid ou -1.
var extra_person_pick: Callable
## Vue au sol (pour incarner un habitant).
var vue_sol: VueSol


func _init() -> void:
	vie = CycleVie.new(self)
	principal = PersonnagePrincipal.new(self)
	effectif = Effectif.new(self)


func _ready() -> void:
	rng.randomize()
	if not world_path.is_empty():
		world = get_node_or_null(world_path) as TerrainWorld
	if not buildings_path.is_empty():
		buildings = get_node_or_null(buildings_path) as BuildingSystem
	if not transport_path.is_empty():
		transport = get_node_or_null(transport_path) as TransportSystem
	if not ambiance_path.is_empty():
		ambiance = get_node_or_null(ambiance_path) as DayNight
	if buildings != null:
		buildings.changed.connect(func() -> void: _sync_buildings.call_deferred())
	_marker = MeshInstance3D.new()
	_marker.mesh = BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.75, 1.0, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker.material_override = m
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)
	_marker_label = Label3D.new()
	_marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker_label.no_depth_test = true
	_marker_label.fixed_size = true
	_marker_label.pixel_size = 0.0007
	_marker_label.font_size = 30
	_marker_label.outline_size = 8
	_marker_label.visible = false
	add_child(_marker_label)
	_follow_marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 1.6
	cone.bottom_radius = 0.0
	cone.height = 3.2
	cone.radial_segments = 4
	_follow_marker.mesh = cone
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("ffd166")
	fm.emission_enabled = true
	fm.emission = Color("ffb703")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_follow_marker.material_override = fm
	_follow_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_follow_marker.visible = false
	add_child(_follow_marker)
	_follow_label = Label3D.new()
	_follow_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_follow_label.no_depth_test = true
	_follow_label.fixed_size = true
	_follow_label.pixel_size = 0.0007
	_follow_label.font_size = 28
	_follow_label.outline_size = 8
	_follow_label.modulate = Color("ffe08a")
	_follow_label.visible = false
	add_child(_follow_label)
	passants = Passants.new()
	passants.name = "Passants"
	add_child(passants)
	passants.setup(self)


func clear() -> void:
	persons.clear()
	households.clear()
	by_home.clear()
	by_job.clear()
	by_school.clear()
	known.clear()
	_arrival_acc.clear()
	_venue_cache.clear()
	next_pid = 1
	next_hid = 1
	life_clock = 0.0
	last_unix = -1.0
	last_day = -1
	ledger = {"mois": {}, "precedent": {}, "jours": 0}
	vie.clear()
	if passants != null:
		passants.clear()
	order_pick = -1
	_incarne = -1
	principal.clear()
	select_building(-1)
	follow_changed.emit()
	changed.emit()


# --- Temps ------------------------------------------------------------------------

func life_speed() -> float:
	return LIFE_SPEEDS[life_speed_index]


## Âge en années (décimales).
func age_of(p: Dictionary) -> float:
	return (life_clock - float(p.nj)) / 365.25


func age_years(p: Dictionary) -> int:
	return int(floorf(age_of(p)))


## Heure locale, jour de la semaine (0 = dimanche), mois, numéro du jour.
func now() -> Dictionary:
	if ambiance == null:
		return {"h": 10.0, "wd": 2, "month": 3, "day": 0, "mday": 10}
	var dt := ambiance.local_datetime()
	var local := ambiance.unix_time + ambiance.utc_offset() * 3600.0
	return {"h": ambiance.local_hour(), "wd": int(dt.weekday), "month": int(dt.month), "mday": int(dt.day),
		"day": int(floorf(local / 86400.0))}


func _process(delta: float) -> void:
	_news_timer -= delta
	if _news_timer <= 0.0 and _arrival_news.x > 0:
		message.emit("%d foyer%s emménage%s (%d habitant%s)." % [_arrival_news.x, "s" if _arrival_news.x > 1 else "",
			"nt" if _arrival_news.x > 1 else "", _arrival_news.y, "s" if _arrival_news.y > 1 else ""])
		_arrival_news = Vector2i.ZERO
		_news_timer = 4.0
	if ambiance == null:
		return
	var t := ambiance.unix_time
	if last_unix < 0.0:
		last_unix = t
		last_day = int(now().day)
		return
	var dt := clampf(t - last_unix, 0.0, 86400.0 * 3.0)
	last_unix = t
	if dt > 0.0:
		advance(dt, true)
	_now = {}


## Fait avancer la simulation de dt secondes de jeu.
## realtime : appelé par le jeu (les attributions sont limitées à ~3 par seconde réelle).
func advance(dt: float, realtime := false) -> void:
	life_clock += dt / 86400.0 * life_speed()
	_step_acc += dt
	# Arrivées et attributions toutes les 5 minutes de jeu.
	var now_ms := Time.get_ticks_msec()
	if _step_acc >= 300.0 and (not realtime or now_ms - _last_step_ms >= 350):
		_last_step_ms = now_ms
		var hours := _step_acc / 3600.0
		_step_acc = 0.0
		if arrivals:
			_immigrate(hours)
		_match_all()
		if principal.enabled and principal.mine() < 0 and not households.is_empty():
			principal.try_birth()
	var d := int(now().day)
	# Horloge remise en arrière (date changée, partie chargée) : on repart de là.
	if last_day < 0 or d < last_day:
		last_day = d
	var n := 0
	while last_day < d and n < 3:
		last_day += 1
		n += 1
		_new_day()
	if last_day < d:
		last_day = d


# --- Bâtiments ------------------------------------------------------------------

func _info_of(b: Dictionary) -> Dictionary:
	var t := BuildingCatalog.get_type(String(b.t))
	var keys := Metiers.keys_of(String(b.t))
	var is_school := keys.has("ecole")
	var seats := 0
	if is_school:
		seats = int(t.get("visiteurs", DEFAULT_SCHOOL_SEATS))
		if seats <= 0:
			seats = DEFAULT_SCHOOL_SEATS
	var rect := Rect2i(int(b.x), int(b.z), 1, 1)
	if buildings != null:
		rect = buildings._rect_of(b)
	var serves := []
	for hb in Metiers.LOISIRS:
		if Metiers.venue_matches(hb, String(b.t)):
			serves.append(hb)
	return {"t": String(b.t), "cat": String(t.get("cat", "")), "serves": serves, "log": int(t.get("logements", 0)),
		"emp": int(t.get("emplois", 0)), "seats": seats, "pos": BuildingSystem.rect_center(rect) + Vector3(0, float(b.get("h", 0.0)), 0),
		"rect": rect, "public": String(t.get("cat", "")) == "services", "cost": int(b.get("cost", BuildingCatalog.cost(String(b.t)))),
		"house": t.get("arch", t.get("role", String(b.t))) in ["maison", "villa", "grande_maison", "ferme"],
		"region": String(t.get("region", "monde"))}


## Met la liste des bâtiments à jour : nouveaux bâtiments, bâtiments démolis.
func _sync_buildings() -> void:
	if buildings == null:
		return
	var extra := _extras()
	var gone := []
	for bid in known:
		if known[bid].has("plan"):
			if not extra.has(bid):
				gone.append(bid)
		elif not buildings.buildings.has(bid) or String(buildings.buildings[bid].t) != String(known[bid].t):
			gone.append(bid)
	for bid in gone:
		_remove_building(bid)
	var added := false
	for bid in buildings.buildings:
		# Un bâtiment en chantier n'accueille encore personne.
		if not known.has(bid) and not buildings.en_chantier(bid):
			known[bid] = _info_of(buildings.buildings[bid])
			added = true
	# Bâtiments en murs fins : leur fiche suit leurs meubles (lits, postes, pupitres…).
	for bid in extra:
		var info: Dictionary = extra[bid]
		if not known.has(bid):
			known[bid] = info
			added = true
		else:
			var old: Dictionary = known[bid]
			if int(old.log) != int(info.log) or int(old.emp) != int(info.emp) or int(old.seats) != int(info.seats) \
					or String(old.t) != String(info.t) or old.serves != info.serves or int(old.get("attr", 0)) != int(info.attr):
				added = true
			known[bid] = info
	if added or not gone.is_empty():
		_venue_cache.clear()
		_transit_cache.clear()
		vie.clear_cache()
		_match_all()
		changed.emit()
	if _selected >= 0 and not known.has(_selected):
		select_building(-1)


func _remove_building(bid: int) -> void:
	known.erase(bid)
	_arrival_acc.erase(bid)
	var n_left := 0
	for hid in by_home.get(bid, []).duplicate():
		n_left += (households[hid].m as Array).size()
		_remove_household(hid, "Quitte la ville : logement démoli")
	by_home.erase(bid)
	for pid in by_job.get(bid, []):
		if persons.has(pid):
			vie.log_event(persons[pid], "fin_emploi", "Perd son emploi : %s est démoli" % building_name(bid), bid)
			persons[pid].job = -1
			persons[pid].met = ""
	by_job.erase(bid)
	for pid in by_school.get(bid, []):
		if persons.has(pid):
			persons[pid].sch = -1
	by_school.erase(bid)
	if n_left > 0:
		message.emit("%d habitant%s quitte%s la ville (logement démoli)." % [n_left, "s" if n_left > 1 else "", "nt" if n_left > 1 else ""])


func free_homes(bid: int) -> int:
	if not known.has(bid):
		return 0
	return int(known[bid].log) - (by_home.get(bid, []) as Array).size()


func free_jobs(bid: int) -> int:
	if not known.has(bid):
		return 0
	return int(known[bid].emp) - (by_job.get(bid, []) as Array).size()


func free_seats(bid: int) -> int:
	if not known.has(bid):
		return 0
	return int(known[bid].seats) - (by_school.get(bid, []) as Array).size()


func _extras() -> Dictionary:
	if extra_buildings.is_valid():
		return extra_buildings.call()
	return {}


func building_name(bid: int) -> String:
	if not known.has(bid):
		return "—"
	if known[bid].has("name"):
		return String(known[bid].name)
	return String(BuildingCatalog.get_type(String(known[bid].t)).get("name", known[bid].t))


func building_pos(bid: int) -> Vector3:
	return known[bid].pos if known.has(bid) else Vector3.ZERO


# --- Foyers -------------------------------------------------------------------------

func _start_region() -> String:
	return Prenoms.region_for_place(GameStart.lat, GameStart.lon)


## Crée un foyer dans un logement. kind : "seul", "couple", "famille", "mono", "seniors" ("" = au hasard).
func spawn_household(bid: int, kind := "") -> int:
	if free_homes(bid) <= 0:
		return -1
	var info: Dictionary = known[bid]
	var region: String = info.region
	if region == "monde" or not Prenoms.POOLS.has(region):
		region = _start_region()
	if rng.randf() < 0.15:
		region = Prenoms.POOLS.keys()[rng.randi() % Prenoms.POOLS.size()]
	if kind == "":
		var r := rng.randf()
		var fam := 0.62 if info.house else 0.38
		if r < fam:
			kind = "famille"
		elif r < fam + 0.08:
			kind = "mono"
		elif r < fam + 0.08 + 0.12:
			kind = "couple"
		elif r < fam + 0.08 + 0.12 + 0.08:
			kind = "seniors"
		else:
			kind = "seul"
	var hid := next_hid
	next_hid += 1
	var h := {"id": hid, "b": bid, "reg": region, "ep": float(rng.randi_range(2, 30) * 1000), "car": 0, "m": []}
	households[hid] = h
	if not by_home.has(bid):
		by_home[bid] = []
	(by_home[bid] as Array).append(hid)
	var surname := Prenoms.family_name(rng, region)
	match kind:
		"seul":
			var a := rng.randf_range(19.0, 85.0)
			_add_person(hid, "F" if rng.randf() < 0.5 else "H", a, "adulte", surname)
		"couple", "seniors":
			var a := rng.randf_range(22.0, 45.0) if kind == "couple" else rng.randf_range(64.0, 86.0)
			_add_person(hid, "F", a + rng.randf_range(-3.0, 3.0), "adulte", surname)
			_add_person(hid, "H", a + rng.randf_range(-3.0, 4.0), "adulte", surname)
		"famille", "mono":
			var n_kids := 1 + rng.randi() % 3
			var oldest := rng.randf_range(0.2, 17.5)
			var mother := oldest + rng.randf_range(22.0, 36.0)
			if kind == "mono":
				_add_person(hid, "F" if rng.randf() < 0.82 else "H", mother, "adulte", surname)
			else:
				_add_person(hid, "F", mother, "adulte", surname)
				_add_person(hid, "H", mother + rng.randf_range(-2.0, 5.0), "adulte", surname)
			var age := oldest
			for i in n_kids:
				_add_person(hid, "F" if rng.randf() < 0.49 else "H", age, "enfant", surname)
				age -= rng.randf_range(1.2, 4.5)
				if age < 0.1:
					break
	var n_adults := 0
	for pid in h.m:
		if persons[pid].r == "adulte":
			n_adults += 1
	h.car = mini(n_adults, 2) if rng.randf() < 0.82 else 0
	if info.house == false and h.car > 1 and rng.randf() < 0.5:
		h.car = 1
	vie.on_arrival(hid, kind)
	return hid


func _add_person(hid: int, sex: String, age: float, role: String, surname: String) -> int:
	var h: Dictionary = households[hid]
	var pid := next_pid
	next_pid += 1
	var p := {"id": pid, "f": hid, "p": Prenoms.first_name(rng, String(h.reg), sex), "n": surname, "s": sex,
		"nj": life_clock - age * 365.25, "r": role, "job": -1, "met": "", "sch": -1, "hob": []}
	p.hob = Metiers.pick_hobbies(rng, age)
	CycleVie.ensure(p)
	persons[pid] = p
	(h.m as Array).append(pid)
	return pid


## archive : raison du départ gardée dans la fiche des habitants ("" : pas de fiche).
func _remove_household(hid: int, archive := "Quitte la ville") -> void:
	if not households.has(hid):
		return
	var h: Dictionary = households[hid]
	for pid in (h.m as Array).duplicate():
		_remove_person(pid, false, archive)
	var list: Array = by_home.get(int(h.b), [])
	list.erase(hid)
	households.erase(hid)


func _remove_person(pid: int, check_household := true, archive := "") -> void:
	if not persons.has(pid):
		return
	var p: Dictionary = persons[pid]
	if archive != "":
		vie.archive_person(p, "depart", archive)
	if vie.followed == pid:
		vie.followed = -1
		follow_changed.emit()
	_leave_job(p)
	_leave_school(p)
	persons.erase(pid)
	if households.has(int(p.f)):
		var h: Dictionary = households[int(p.f)]
		(h.m as Array).erase(pid)
		if check_household:
			var adults := 0
			for m in h.m:
				if persons[m].r == "adulte" or age_of(persons[m]) >= ADULT_AGE:
					adults += 1
			if adults == 0:
				_remove_household(int(p.f), "Quitte la ville avec sa famille")


## reason : étape notée dans le CV ("" : rien).
func _leave_job(p: Dictionary, reason := "") -> void:
	if int(p.job) >= 0:
		(by_job.get(int(p.job), []) as Array).erase(int(p.id))
		if reason != "":
			vie.log_event(p, "fin_emploi", reason, int(p.job))
	p.job = -1
	p.met = ""


func _leave_school(p: Dictionary) -> void:
	if int(p.sch) >= 0:
		(by_school.get(int(p.sch), []) as Array).erase(int(p.id))
	p.sch = -1


func home_of(p: Dictionary) -> int:
	return int(households[int(p.f)].b) if households.has(int(p.f)) else -1


# --- Étapes de la vie ---------------------------------------------------------------

## "bebe", "eleve", "actif", "chomeur", "retraite"
func stage(p: Dictionary) -> String:
	var a := age_of(p)
	if a < SCHOOL_AGE:
		return "bebe"
	if a < ADULT_AGE:
		return "eleve"
	if a >= RETIREMENT_AGE or bool(p.get("retr", false)):
		return "retraite"
	if float(p.get("etu", -1.0)) > life_clock:
		return "etudiant"
	return "actif" if int(p.job) >= 0 else "chomeur"


const STAGE_NAMES := {"bebe": "Bébé", "eleve": "Élève", "etudiant": "Étudiant·e", "actif": "Actif·ve", "chomeur": "Sans emploi",
	"retraite": "Retraité·e"}


func stage_label(p: Dictionary) -> String:
	var st := stage(p)
	if st == "eleve":
		var lvl := Metiers.school_level(age_years(p))
		return "Élève (%s)" % lvl if int(p.sch) >= 0 else "Enfant sans école"
	if st == "actif":
		return Metiers.job(String(p.met)).name
	if st == "etudiant":
		return "Étudiant%s (%s)" % [CycleVie.g(p, "", "e"), CycleVie.DIPLOMES.get(String(p.get("etd", "")), "université")]
	return STAGE_NAMES[st]


## Arrivées : les logements libres se remplissent peu à peu.
func _immigrate(hours: float) -> void:
	for bid in known:
		var free := free_homes(bid)
		if free <= 0:
			continue
		var acc := float(_arrival_acc.get(bid, 0.0))
		# Un premier foyer s'installe vite dans un logement vide.
		if (by_home.get(bid, []) as Array).is_empty():
			acc = maxf(acc, 1.0)
		acc += maxf(1.0, free * ARRIVAL_RATE) * hours
		var n := mini(int(acc), free)
		acc -= n
		_arrival_acc[bid] = acc
		for i in n:
			var hid := spawn_household(bid)
			if hid >= 0:
				_arrival_news.x += 1
				_arrival_news.y += (households[hid].m as Array).size()


## Attribue les écoles et les emplois au plus proche (et met les retraites à jour).
func _match_all() -> void:
	var schools := []
	var jobs := []
	for bid in known:
		if free_seats(bid) > 0:
			schools.append(bid)
		if free_jobs(bid) > 0:
			jobs.append(bid)
	for pid in persons:
		var p: Dictionary = persons[pid]
		var st := stage(p)
		if st == "eleve":
			if int(p.sch) < 0 and not schools.is_empty():
				var best := _nearest(home_of(p), schools)
				if best >= 0:
					_join_school(p, best)
					if free_seats(best) <= 0:
						schools.erase(best)
			if int(p.sch) >= 0:
				var lvl := Metiers.school_level(age_years(p))
				if String(p.get("niv", "")) != lvl:
					p.niv = lvl
					const ENTRE := {"maternelle": "Entre à l'école maternelle", "élémentaire": "Entre à l'école élémentaire",
						"collège": "Entre au collège", "lycée": "Entre au lycée"}
					vie.log_event(p, "ecole", "%s (%s)" % [ENTRE.get(lvl, "Entre à l'école"), building_name(int(p.sch))], int(p.sch))
		elif int(p.sch) >= 0:
			_leave_school(p)
		if st == "retraite" and not bool(p.get("ret", false)):
			p.ret = true
			vie.log_event(p, "retraite", "Prend sa retraite%s" % (" (%s)" % String(Metiers.job(String(p.met)).name).to_lower()
				if int(p.job) >= 0 else ""), int(p.job))
		if st == "retraite" and int(p.job) >= 0:
			_leave_job(p)
		elif st == "chomeur" and not jobs.is_empty():
			# D'abord les bâtiments fermés faute du métier indispensable (Effectif) :
			# l'école cherche un enseignant, l'hôpital un médecin…
			var met := ""
			var best := -1
			if effectif != null:
				var urgents := []
				for b in jobs:
					if effectif.ferme(b):
						urgents.append(b)
				if not urgents.is_empty():
					best = _nearest(home_of(p), urgents)
					var req := Effectif.requis_de(String(known[best].t)) if best >= 0 else []
					if not req.is_empty():
						met = String(req[0])
			if best < 0:
				best = _nearest(home_of(p), jobs)
			if best >= 0:
				_join_job(p, best, met)
				if effectif != null:
					effectif.oublier(best)
				if free_jobs(best) <= 0:
					jobs.erase(best)
		elif (st == "bebe" or st == "eleve") and int(p.job) >= 0:
			_leave_job(p)
	_apres_embauches()


## Les embauches ont pu ouvrir ou fermer des bâtiments : les trajets vers les
## commerces et loisirs, et l'accès aux soins, sont à recalculer.
func _apres_embauches(force := false) -> void:
	if effectif != null and effectif.actualiser(force):
		_venue_cache.clear()
		vie.clear_cache()
		if passants != null:
			passants._plans.clear()


func _nearest(from_bid: int, list: Array) -> int:
	if not known.has(from_bid):
		return -1
	var o: Vector3 = known[from_bid].pos
	var best := -1
	var best_d := INF
	for bid in list:
		var d := o.distance_squared_to(known[bid].pos)
		# Un lieu attrayant (meubles, vitrines) attire de plus loin.
		var attr := float(known[bid].get("attr", 0))
		if attr > 0.0:
			d /= pow(1.0 + attr / 50.0, 2.0)
		if d < best_d:
			best_d = d
			best = bid
	return best


func _join_school(p: Dictionary, bid: int) -> void:
	_leave_school(p)
	p.sch = bid
	if not by_school.has(bid):
		by_school[bid] = []
	(by_school[bid] as Array).append(int(p.id))


func _join_job(p: Dictionary, bid: int, metier := "") -> void:
	var had := int(p.job) >= 0
	_leave_job(p)
	p.job = bid
	if metier == "":
		# Les diplômes ouvrent les métiers les mieux payés (deux tirages, on garde le meilleur).
		metier = Metiers.pick_job(rng, String(known[bid].t))
		var dip := String(p.get("dip", ""))
		var other := Metiers.pick_job(rng, String(known[bid].t))
		var better := int(Metiers.job(other).salaire) > int(Metiers.job(metier).salaire)
		if (dip in ["licence", "master"] and better) or (dip in ["", "brevet"] and not better):
			metier = other
	p.met = metier
	if not by_job.has(bid):
		by_job[bid] = []
	(by_job[bid] as Array).append(int(p.id))
	var j := Metiers.job(String(p.met))
	vie.log_event(p, "emploi", "%s %s à %s (%s net par mois)" % ["Change de travail : devient" if had else "Devient",
		String(j.name).to_lower(), building_name(bid), HabitantsPanel.money(float(j.salaire) * ReglagesPartie.actuel.salaires)], bid)


## Chaque nouveau jour : économie, naissances, décès, départs de chez les parents.
func _new_day() -> void:
	_pay_day()
	_board_commuters()
	var years := life_speed() / 365.25 # années de vie écoulées en un jour de jeu
	vie.daily(years)
	vie.flush_digest()
	changed.emit()


## Un jeune adulte quitte ses parents s'il trouve un logement libre.
func _move_out(pid: int) -> void:
	var homes := []
	for bid in known:
		if free_homes(bid) > 0:
			homes.append(bid)
	if homes.is_empty():
		return
	var p: Dictionary = persons[pid]
	var old: Dictionary = households[int(p.f)]
	var bid: int = homes[rng.randi() % homes.size()]
	var hid := next_hid
	next_hid += 1
	households[hid] = {"id": hid, "b": bid, "reg": old.reg, "ep": 3000.0, "car": 1 if rng.randf() < 0.6 else 0, "m": [pid]}
	if not by_home.has(bid):
		by_home[bid] = []
	(by_home[bid] as Array).append(hid)
	(old.m as Array).erase(pid)
	p.f = hid
	p.r = "adulte"
	vie.log_event(p, "demenage", "Quitte ses parents et s'installe à %s" % building_name(bid), bid)
	if int(households[hid].car) > 0:
		if not bool(p.get("perm", false)):
			p.perm = true
			vie.log_event(p, "permis", "Obtient le permis de conduire")
		vie.log_event(p, "voiture", "Achète sa première voiture")


# --- Économie -------------------------------------------------------------------

func _book(cat: String, amount: float) -> void:
	var m: Dictionary = ledger.mois
	m[cat] = float(m.get(cat, 0.0)) + amount


## Revenus mensuels d'un habitant (salaire, pension, allocation).
func income_of(p: Dictionary) -> float:
	match stage(p):
		"actif":
			return float(Metiers.job(String(p.met)).salaire) * ReglagesPartie.actuel.salaires
		"retraite":
			return PENSION
		"chomeur":
			return ALLOCATION
		"etudiant":
			return BOURSE
	return 0.0


## Budget mensuel d'un foyer : {revenus, loyer, courses, voitures, solde}.
func household_budget(hid: int) -> Dictionary:
	var h: Dictionary = households[hid]
	var inc := 0.0
	for pid in h.m:
		inc += income_of(persons[pid])
	var house: bool = known.has(int(h.b)) and bool(known[int(h.b)].house)
	var rent := LOYER_MAISON if house else LOYER_APPART
	# Logement aménagé : le loyer suit sa valeur.
	if known.has(int(h.b)) and float(known[int(h.b)].get("loyer", 0.0)) > 0.0:
		rent = float(known[int(h.b)].loyer)
	var food := COURSES * (h.m as Array).size()
	var cars := VOITURE * int(h.car)
	return {"revenus": inc, "loyer": rent, "courses": food, "voitures": cars, "solde": inc - rent - food - cars}


## Budget mensuel de la ville, estimé sur la population actuelle.
func city_budget() -> Dictionary:
	var rec := {"Taxe foncière": 0.0, "Impôts des entreprises": 0.0, "Dotation de l'État": 0.0}
	var dep := {"Salaires des agents de la ville": 0.0, "Entretien des bâtiments publics": 0.0}
	var reg := ReglagesPartie.actuel
	for hid in households:
		var hb := int(households[hid].b)
		rec["Taxe foncière"] += TAXE_FONCIERE * reg.impots * (float(known[hb].get("tf", 1.0)) if known.has(hb) else 1.0)
	rec["Dotation de l'État"] = DOTATION * persons.size()
	for bid in by_job:
		if not known.has(bid):
			continue
		var info: Dictionary = known[bid]
		for pid in by_job[bid]:
			var j := Metiers.job(String(persons[pid].met))
			if bool(j.get("etat", false)):
				continue
			if info.public or bool(j.get("public", false)):
				dep["Salaires des agents de la ville"] += float(Metiers.job(String(persons[pid].met)).salaire) * reg.salaires * CHARGES
			else:
				rec["Impôts des entreprises"] += CFE * reg.impots
	for bid in known:
		if known[bid].public:
			dep["Entretien des bâtiments publics"] += float(known[bid].cost) * ENTRETIEN
	var r := 0.0
	var d := 0.0
	for k in rec:
		r += rec[k]
	for k in dep:
		d += dep[k]
	return {"recettes": rec, "depenses": dep, "total_recettes": r, "total_depenses": d, "solde": r - d}


## Paie une journée : budgets des foyers et caisse de la ville.
func _pay_day() -> void:
	var b := city_budget()
	var day := 1.0 / DAYS_PER_MONTH
	for k in b.recettes:
		_book(k, b.recettes[k] * day)
	for k in b.depenses:
		_book(k, -b.depenses[k] * day)
	if buildings != null and not buildings.unlimited_money:
		_money_frac += float(b.solde) * day
		var whole := int(_money_frac)
		_money_frac -= whole
		buildings.money += whole
	var gone := []
	for hid in households:
		var h: Dictionary = households[hid]
		h.ep = float(h.ep) + float(household_budget(hid).solde) * day
		# Trop de dettes : le foyer quitte la ville.
		if float(h.ep) < -8000.0:
			gone.append(hid)
	for hid in gone:
		var h: Dictionary = households[hid]
		var who: Dictionary = persons[h.m[0]] if not (h.m as Array).is_empty() else {}
		if not who.is_empty():
			message.emit("Le foyer %s, endetté, quitte la ville." % String(who.n))
		_remove_household(hid, "Quitte la ville : le foyer est trop endetté")
	ledger.jours = int(ledger.jours) + 1
	if int(ledger.jours) >= 30:
		ledger.precedent = ledger.mois
		ledger.mois = {}
		ledger.jours = 0


# --- Emploi du temps -------------------------------------------------------------

## Trajet entre deux bâtiments : {mode, min (minutes), m (mètres)}.
func commute(p: Dictionary, from_bid: int, to_bid: int) -> Dictionary:
	if not known.has(from_bid) or not known.has(to_bid):
		return {"mode": "à pied", "min": 0, "m": 0.0}
	var a: Vector3 = known[from_bid].pos
	var b: Vector3 = known[to_bid].pos
	var d := Vector2(a.x - b.x, a.z - b.z).length() * 1.3
	var age := age_of(p)
	var h: Dictionary = households.get(int(p.f), {})
	if d <= WALK_MAX or age < 10.0:
		return {"mode": "à pied", "min": maxi(2, roundi(d / 80.0)), "m": d}
	var tc := _transit_between(a, b)
	var cars := int(h.get("car", 0)) > 0 and age >= ADULT_AGE
	var bike := d <= BIKE_MAX and age < 75.0 and (int(p.id) % 3 == 0 or not cars)
	var bike_min := maxi(3, roundi(d / 250.0))
	var car_min := maxi(3, roundi(d / 500.0) + 3)
	# Les amoureux de la voiture la prennent ; les autres choisissent le plus rapide.
	if cars and int(p.id) % 2 == 1:
		return {"mode": "en voiture", "min": car_min, "m": d}
	if not tc.is_empty() and (not bike or int(tc.min) <= bike_min):
		return {"mode": tc.mode, "min": tc.min, "m": d, "detail": tc.detail, "trip": tc.trip}
	if bike:
		return {"mode": "à vélo", "min": bike_min, "m": d}
	if cars:
		return {"mode": "en voiture", "min": car_min, "m": d}
	return {"mode": "à pied (long trajet)", "min": roundi(d / 80.0), "m": d}


## Trajet en transports publics plus rapide que la marche (planificateur des
## lignes : marche, lignes, correspondances), ou {} : {mode, min, detail, trip}.
func _transit_between(a: Vector3, b: Vector3) -> Dictionary:
	if transport == null or transport.stations == null or transport.stations.lines.is_empty():
		return {}
	var st := transport.stations
	if not st.lines_changed.is_connected(_on_lines_changed):
		st.lines_changed.connect(_on_lines_changed)
	var key := [a, b]
	if _transit_cache.has(key):
		return _transit_cache[key]
	var res := {}
	if st.planner != null:
		var trip: Dictionary = st.planner.plan(a, b)
		var first_line := ""
		var n_lines := 0
		for leg in trip.get("legs", []):
			if String(leg.type) == "ligne":
				n_lines += 1
				if first_line == "":
					first_line = "en %s (%s)" % [String(leg.kind), String(leg.name)]
		if bool(trip.get("ok", false)) and n_lines > 0:
			res = {"mode": first_line + (" + %d correspondance%s" % [n_lines - 1, "s" if n_lines > 2 else ""] if n_lines > 1 else ""),
				"min": maxi(1, roundi(float(trip.total_s) / 60.0)), "detail": st.planner.describe(trip), "trip": trip}
	_transit_cache[key] = res
	return res


func _on_lines_changed() -> void:
	_transit_cache.clear()


## Compte chaque jour les voyageurs des lignes : un aller et un retour par trajet.
func _board_commuters() -> void:
	if transport == null or transport.stations == null or transport.stations.planner == null or transport.stations.lines.is_empty():
		return
	var n := now()
	var counts := {}
	var trips := {}
	for pid in persons:
		var p: Dictionary = persons[pid]
		var dest := int(p.sch) if stage(p) == "eleve" else int(p.job)
		if dest < 0 or (stage(p) == "actif" and not _works_today(p, n)):
			continue
		var c := commute(p, home_of(p), dest)
		if c.has("trip"):
			var k := Vector2i(home_of(p), dest)
			counts[k] = int(counts.get(k, 0)) + 2
			trips[k] = c.trip
	for k in counts:
		transport.stations.planner.board(trips[k], counts[k])


## Lieu d'un loisir le plus proche du logement, ou -1 (à la maison).
func venue_for(p: Dictionary, hobby: String) -> int:
	return _cached_nearest(home_of(p), hobby)


func _nearest_cat(p: Dictionary, cat: String) -> int:
	return _cached_nearest(home_of(p), "cat:" + cat)


## Fermé faute de personnel (voir Effectif) ?
func _ferme(bid: int) -> bool:
	return effectif != null and effectif.ferme(bid)


## Bâtiment le plus proche d'un logement pour un loisir (ou "cat:<catégorie>"), mis en cache.
func _cached_nearest(home: int, what: String) -> int:
	var per_home: Dictionary = _venue_cache.get(home, {})
	if per_home.has(what):
		return per_home[what]
	var list := []
	if what == "cat:commerce":
		for bid in known:
			if (known[bid].serves as Array).has("shopping") and not _ferme(bid):
				list.append(bid)
	else:
		for bid in known:
			if (known[bid].serves as Array).has(what) and not _ferme(bid):
				list.append(bid)
	var best := _nearest(home, list) if not list.is_empty() else -1
	per_home[what] = best
	_venue_cache[home] = per_home
	return best


func _works_today(p: Dictionary, n: Dictionary) -> bool:
	var j := Metiers.job(String(p.met))
	var wd: int = n.wd
	match String(j.j):
		"semaine":
			return wd >= 1 and wd <= 5
		"lunsam":
			return wd >= 1 and wd <= 6
		"marsam":
			return wd >= 2 and wd <= 6
		"tous":
			return true
		"garde":
			return (int(n.day) + int(p.id)) % 2 == 0
		"ecole":
			return wd >= 1 and wd <= 5 and not _school_holidays(n)
	return wd >= 1 and wd <= 5


func _school_holidays(n: Dictionary) -> bool:
	return int(n.month) == 7 or int(n.month) == 8


## En congés : trois semaines en août pour la moitié des actifs.
func _on_leave(p: Dictionary, n: Dictionary) -> bool:
	return int(n.month) == 8 and int(n.mday) <= 21 and int(p.id) % 2 == 0 and Metiers.job(String(p.met)).j != "garde"


## Programme de la journée : liste de [début, fin, genre, bâtiment, texte] (heures locales).
## Un ordre du joueur (p.ord) remplace une partie de la journée.
func day_plan(p: Dictionary, n: Dictionary = {}) -> Array:
	if n.is_empty():
		n = now()
	var plan := _base_plan(p, n)
	# Événements de la ville (malades, marché, fête, match) : voir Evenements.
	for hook in plan_hooks:
		plan = hook.call(p, n, plan)
	if p.has("ord"):
		var o: Dictionary = p.ord
		if int(o.d) == int(n.day):
			plan = _apply_order(p, plan, o)
		elif int(o.d) < int(n.day):
			p.erase("ord")
	return plan


## Journée modifiée par un ordre : programme normal jusqu'à l'heure de l'ordre,
## trajet, temps sur place, retour à la maison, soirée.
func _apply_order(p: Dictionary, plan: Array, o: Dictionary) -> Array:
	var home := home_of(p)
	var t0 := float(o.t)
	var target := int(o.b)
	var kind := String(o.get("kind", "loisir"))
	var where := home
	var sleep := 22.5
	for seg in plan:
		if t0 >= float(seg[0]) and t0 < float(seg[1]):
			where = int(seg[3])
		if String(seg[2]) == "dort" and float(seg[0]) > 12.0:
			sleep = float(seg[0])
	if not known.has(where):
		where = home
	var out := []
	for seg in plan:
		if float(seg[0]) >= t0:
			break
		var s2: Array = (seg as Array).duplicate()
		s2[1] = minf(float(s2[1]), t0)
		out.append(s2)
	var t := t0
	if where != target and known.has(target):
		var c := commute(p, where, target)
		var arr := minf(t + maxf(float(c.min), 1.0) / 60.0, 24.0)
		out.append([t, arr, "trajet", target, "En route %s (sur ton ordre)" % c.mode])
		t = arr
	var end := minf(t + float(o.get("dur", 2.0)), 24.0)
	if kind == "dort":
		end = 24.0
	elif kind == "maison":
		end = maxf(sleep, t)
	if end > t:
		out.append([t, end, kind, target, String(o.txt)])
	t = end
	if t < 24.0 and target != home and known.has(home):
		var c2 := commute(p, target, home)
		var back := minf(t + maxf(float(c2.min), 1.0) / 60.0, 24.0)
		out.append([t, back, "trajet", home, "Rentre %s" % c2.mode])
		t = back
	if t < 24.0:
		if t < sleep:
			out.append([t, sleep, "maison", home, "À la maison"])
		out.append([maxf(t, sleep), 24.0, "dort", home, "Dort"])
	return out


func _base_plan(p: Dictionary, n: Dictionary) -> Array:
	var home := home_of(p)
	var st := stage(p)
	var plan := []
	var wake := 7.0
	var sleep := 22.5
	var dest := -1
	var start := 0.0
	var end := 0.0
	var where := ""
	var kind := ""
	match st:
		"bebe":
			wake = 7.0
			sleep = 20.0
			var all_work := true
			var any_adult := false
			for m in households[int(p.f)].m:
				var q: Dictionary = persons[m]
				if q.r == "adulte":
					any_adult = true
					if stage(q) != "actif" or not _works_today(q, n):
						all_work = false
			if any_adult and all_work and n.wd >= 1 and n.wd <= 5:
				return [[0.0, wake, "dort", home, "Dort"], [wake, 8.5, "maison", home, "À la maison"],
					[8.5, 17.5, "garde", home, "Chez l'assistante maternelle"], [17.5, sleep, "maison", home, "À la maison avec ses parents"],
					[sleep, 24.0, "dort", home, "Dort"]]
		"eleve":
			sleep = 21.0 if age_of(p) < 11.0 else 22.5
			if int(p.sch) >= 0 and n.wd >= 1 and n.wd <= 5 and not _school_holidays(n) and _ferme(int(p.sch)):
				plan.append([0.0, 7.5, "dort", home, "Dort"])
				plan.append([7.5, 16.5, "maison", home, "À la maison : école fermée (%s)" % String(effectif.etat(int(p.sch)).raison)])
				plan.append([16.5, sleep, "maison", home, "À la maison"])
				plan.append([sleep, 24.0, "dort", home, "Dort"])
				return plan
			if int(p.sch) >= 0 and n.wd >= 1 and n.wd <= 5 and not _school_holidays(n):
				dest = int(p.sch)
				start = 8.5
				end = 12.0 if n.wd == 3 else 16.5
				kind = "ecole"
				where = "À l'école (%s)" % Metiers.school_class(age_years(p))
		"actif":
			wake = 6.5
			sleep = 23.0
			if _works_today(p, n) and not _on_leave(p, n):
				var j := Metiers.job(String(p.met))
				dest = int(p.job)
				start = float(j.h[0])
				end = float(j.h[1])
				kind = "travail"
				where = "Au travail (%s)" % String(j.name).to_lower()
				wake = minf(wake, start - 1.0)
		"retraite":
			wake = 7.5
			sleep = 22.0
		"chomeur":
			wake = 7.5
			sleep = 23.0
	wake = maxf(wake, 3.0)
	plan.append([0.0, wake, "dort", home, "Dort"])
	var t := wake
	var vacation := (st == "eleve" and _school_holidays(n)) or (st == "actif" and _on_leave(p, n))
	if dest >= 0:
		var c := commute(p, home, dest)
		var go := maxf(t, start - float(c.min) / 60.0)
		if go > t:
			plan.append([t, go, "maison", home, "À la maison"])
		plan.append([go, start, "trajet", dest, "En route %s" % c.mode])
		plan.append([start, end, kind, dest, where])
		var back := end + float(c.min) / 60.0
		plan.append([end, back, "trajet", home, "Rentre %s" % c.mode])
		t = back
	elif st == "etudiant" and n.wd >= 1 and n.wd <= 5 and not _school_holidays(n):
		plan.append([t, 8.5, "maison", home, "À la maison"])
		plan.append([8.5, 17.5, "etudes", -1, "En cours à l'université (hors de la ville)"])
		t = 17.5
	elif st == "chomeur" and n.wd >= 1 and n.wd <= 5:
		plan.append([t, 12.0, "maison", home, "Cherche un emploi"])
		t = 12.0
	elif vacation:
		plan.append([t, 10.0, "maison", home, "En vacances"])
		t = 10.0
	# Courses : un adulte du foyer, certains jours.
	if (st == "retraite" or st == "chomeur" or (st == "actif" and t < 19.0)) and (int(n.day) + int(p.id)) % 3 == 0:
		var shop := _nearest_cat(p, "commerce")
		if shop >= 0 and t < 19.5:
			var s := maxf(t, 10.0 if st != "actif" else t)
			if s > t:
				plan.append([t, s, "maison", home, "À la maison"])
			plan.append([s, s + 1.0, "courses", shop, "Fait les courses"])
			t = s + 1.0
	# Loisir : un jour sur deux, plus souvent le week-end et en vacances.
	var hobbies: Array = p.hob
	var free_day: bool = n.wd == 0 or n.wd == 6 or n.wd == 3 or vacation
	if not hobbies.is_empty() and ((int(n.day) + int(p.id)) % 2 == 0 or free_day) and st != "bebe":
		var hb: String = hobbies[(int(n.day) + int(p.id)) % hobbies.size()]
		var v := venue_for(p, hb)
		var s := maxf(t, 14.0 if free_day else 17.0)
		var e := minf(s + 2.0, sleep - 1.0)
		if e > s + 0.25:
			if s > t:
				plan.append([t, s, "maison", home, "À la maison"])
			if v >= 0:
				plan.append([s, e, "loisir", v, "%s (%s)" % [Metiers.LOISIRS[hb].name, building_name(v)]])
			else:
				plan.append([s, e, "maison", home, "%s à la maison" % Metiers.LOISIRS[hb].name])
			t = e
	if t < sleep:
		plan.append([t, sleep, "maison", home, "À la maison"])
	plan.append([maxf(t, sleep), 24.0, "dort", home, "Dort"])
	return plan


## Activité en ce moment : {kind, bid, text}.
func activity(p: Dictionary) -> Dictionary:
	if int(p.id) == _incarne:
		return {"kind": "incarne", "bid": -1, "text": "Dirigé%s par toi (vue au sol)" % CycleVie.g(p, "", "e")}
	if _now.is_empty():
		_now = now()
	var h: float = _now.h
	for seg in day_plan(p, _now):
		if h >= float(seg[0]) and h < float(seg[1]):
			return {"kind": seg[2], "bid": seg[3], "text": seg[4]}
	return {"kind": "dort", "bid": home_of(p), "text": "Dort"}


## Habitants présents en ce moment dans un bâtiment.
func present_in(bid: int) -> Array:
	var out := []
	var candidates := []
	if not known.has(bid):
		return out
	var info: Dictionary = known[bid]
	for hid in by_home.get(bid, []):
		candidates.append_array(households[hid].m)
	candidates.append_array(by_job.get(bid, []))
	candidates.append_array(by_school.get(bid, []))
	# Visiteurs possibles : ceux dont c'est le lieu de loisir ou le commerce le plus proche.
	var serves: Array = info.serves
	var shop: bool = serves.has("shopping")
	if shop or not serves.is_empty():
		var seen := {}
		for c in candidates:
			seen[c] = true
		for hid in households:
			var home := int(households[hid].b)
			var shop_here := shop and _cached_nearest(home, "cat:commerce") == bid
			for pid in households[hid].m:
				if seen.has(pid):
					continue
				var hit := shop_here
				if not hit:
					for hb in persons[pid].hob:
						if serves.has(hb) and _cached_nearest(home, hb) == bid:
							hit = true
							break
				if hit:
					candidates.append(pid)
	for pid in candidates:
		var a := activity(persons[pid])
		if int(a.bid) == bid and a.kind != "trajet":
			out.append(pid)
	return out


## Satisfaction (0-100) et ce qui la fait varier.
func satisfaction(p: Dictionary) -> Dictionary:
	var s := 60.0
	var why := []
	match stage(p):
		"actif":
			s += 15.0
			why.append("+ a un emploi")
		"chomeur":
			s -= 20.0
			why.append("− cherche un emploi")
		"eleve":
			if int(p.sch) >= 0:
				s += 15.0
				why.append("+ va à l'école")
			else:
				s -= 20.0
				why.append("− pas de place à l'école")
		"retraite":
			s += 10.0
		"etudiant":
			s += 10.0
			why.append("+ fait des études")
	var found := 0
	for hb in p.hob:
		if Metiers.LOISIRS[hb].lieux.is_empty() or venue_for(p, hb) >= 0:
			found += 1
	if not (p.hob as Array).is_empty():
		var part := float(found) / (p.hob as Array).size()
		s += 15.0 * part - 5.0
		why.append("%s loisirs : %d sur %d possibles en ville" % ["+" if part >= 0.5 else "−", found, (p.hob as Array).size()])
	# Personnel des bâtiments du quotidien (école, commerce, hôpital).
	if int(p.sch) >= 0 and _ferme(int(p.sch)):
		s -= 15.0
		why.append("− école fermée faute d'enseignant")
	var shop := _nearest_cat(p, "commerce")
	if shop >= 0 and effectif != null and effectif.manque(shop):
		s -= 5.0
		why.append("− longues files au commerce (manque de personnel)")
	elif shop < 0 and not known.is_empty():
		for bid in known:
			if (known[bid].serves as Array).has("shopping"):
				s -= 8.0
				why.append("− les commerces sont fermés faute de personnel")
				break
	var dest := int(p.job) if int(p.job) >= 0 else int(p.sch)
	if dest >= 0:
		var c := commute(p, home_of(p), dest)
		if int(c.min) > 40:
			s -= 10.0
			why.append("− long trajet (%d min)" % int(c.min))
	if households.has(int(p.f)) and float(households[int(p.f)].ep) < 0.0:
		s -= 15.0
		why.append("− foyer endetté")
	# Confort du logement aménagé (meubles, cuisine, salle de bains…).
	var home := home_of(p)
	if known.has(home) and known[home].has("conf"):
		var c := int(known[home].conf)
		var bonus := clampf((c - 50.0) / 4.0, -12.0, 12.0)
		s += bonus
		why.append("%s logement %s (confort %d)" % ["+" if bonus >= 0.0 else "−", "confortable" if c >= 50 else "peu confortable", c])
	if extra_satisfaction.is_valid():
		var ex: Array = extra_satisfaction.call(p)
		if ex.size() >= 2:
			s += float(ex[0])
			why.append_array(ex[1])
	return {"value": clampi(roundi(s), 0, 100), "why": why}


# --- Circulation -------------------------------------------------------------------

## Agents à l'écran par personne qui se déplace (les autres sont « hors champ »).
const STREET_SHARE := 1.0
## Demi-fenêtre autour de l'heure pendant laquelle un trajet compte (h).
const WINDOW := 0.33
## Trains et bateaux d'ambiance : un par tant d'emplois occupés.
const JOBS_PER_TRAIN := 300
const JOBS_PER_BOAT := 400
var _demand := {}
var _demand_ms := -100000
var _demand_n := -1


## Combien de voitures, de cyclistes et de piétons sont dehors en ce moment,
## d'après l'emploi du temps des habitants (échantillon de 300 personnes).
## Sans habitant, personne dans les rues. Pour Traffic.demand.
func traffic_demand() -> Dictionary:
	var ms := Time.get_ticks_msec()
	if ms - _demand_ms < 1500 and persons.size() == _demand_n:
		return _demand
	_demand_ms = ms
	_demand_n = persons.size()
	var cars := 0.0
	var bikes := 0.0
	var walk := 0.0
	var jobs := 0
	for bid in by_job:
		jobs += (by_job[bid] as Array).size()
	if not persons.is_empty():
		_now = now()
		var ids := persons.keys()
		var n := mini(ids.size(), 300)
		var step := float(ids.size()) / n
		for k in n:
			var p: Dictionary = persons[ids[int(k * step)]]
			var h: Dictionary = households.get(int(p.f), {})
			var has_car := int(h.get("car", 0)) > 0 and age_of(p) >= ADULT_AGE
			var hour: float = _now.h
			# Dehors si un trajet tombe à moins de 20 min (on flâne, on attend,
			# on se gare), ou pendant les courses et les loisirs.
			for seg in day_plan(p, _now):
				var kind := String(seg[2])
				if kind == "trajet" and float(seg[1]) > hour - WINDOW and float(seg[0]) < hour + WINDOW:
					var dest := int(p.sch) if int(p.sch) >= 0 else int(p.job)
					var mode := String(commute(p, home_of(p), dest).mode)
					if mode.begins_with("en voiture"):
						cars += 1.0
					elif mode.begins_with("à vélo"):
						bikes += 1.0
					else:
						walk += 1.0
					break
				if (kind == "courses" or kind == "loisir") and hour >= float(seg[0]) and hour < float(seg[1]):
					if has_car and int(p.id) % 2 == 1:
						cars += 0.25
					else:
						walk += 0.4
					break
		var scale := float(ids.size()) / n * STREET_SHARE
		cars *= scale
		bikes *= scale
		walk *= scale
	# Livraisons et artisans : un utilitaire pour 40 emplois occupés en journée.
	var hour := float(now().h)
	if hour >= 7.0 and hour < 19.0:
		cars += jobs / 40.0
	# Les habitants dessinés près de la caméra remplacent une partie des figurants.
	if passants != null:
		cars = maxf(0.0, cars - passants.count_mode("voiture"))
		walk = maxf(0.0, walk - passants.count_mode("pied"))
	var road := roundi(cars + bikes * 0.5)
	_demand = {TransportTypes.Mode.ROAD: road, TransportTypes.Mode.PATH: roundi(walk * 0.5 + bikes * 0.5),
		TransportTypes.Mode.RAIL: jobs / JOBS_PER_TRAIN, TransportTypes.Mode.WATER: jobs / JOBS_PER_BOAT,
		"walkers": roundi(walk)}
	return _demand


# --- Chiffres ---------------------------------------------------------------------

func stats() -> Dictionary:
	var out := {"habitants": persons.size(), "foyers": households.size(), "bebe": 0, "eleve": 0, "etudiant": 0, "actif": 0,
		"chomeur": 0, "retraite": 0, "sans_ecole": 0, "logements": 0, "emplois": 0, "places": 0, "satisfaction": 0}
	var sat := 0
	for pid in persons:
		var p: Dictionary = persons[pid]
		var st := stage(p)
		out[st] += 1
		if st == "eleve" and int(p.sch) < 0:
			out.sans_ecole += 1
	# Satisfaction moyenne sur un échantillon (le calcul complet est coûteux).
	var n := 0
	for pid in persons:
		sat += int(satisfaction(persons[pid]).value)
		n += 1
		if n >= 200:
			break
	out.satisfaction = roundi(float(sat) / n) if n > 0 else 0
	for bid in known:
		out.logements += int(known[bid].log)
		out.emplois += int(known[bid].emp)
		out.places += int(known[bid].seats)
	return out


func summary() -> String:
	var adults := 0
	var jobless := 0
	for pid in persons:
		var p: Dictionary = persons[pid]
		var a := age_of(p)
		if a >= ADULT_AGE and a < RETIREMENT_AGE:
			adults += 1
			if int(p.job) < 0:
				jobless += 1
	return "Habitants : %d   ·   Foyers : %d   ·   Chômage : %s   ·   H : habitants" % [persons.size(), households.size(),
		"—" if adults == 0 else "%d %%" % roundi(100.0 * jobless / adults)]


# --- Sélection d'un bâtiment (clic) -------------------------------------------------

func select_building(bid: int) -> void:
	_selected = bid if known.has(bid) else -1
	_marker.visible = _selected >= 0
	_marker_label.visible = _selected >= 0
	if _selected >= 0:
		var info: Dictionary = known[_selected]
		var r: Rect2i = info.rect
		var hgt := BuildingCatalog.approx_height(String(info.t)) + 1.0
		(_marker.mesh as BoxMesh).size = Vector3(r.size.x + 1.0, hgt, r.size.y + 1.0)
		_marker.position = info.pos + Vector3(0, hgt / 2.0 - 0.2, 0)
		_marker_label.position = info.pos + Vector3(0, hgt + 4.0, 0)
		_update_label()
	building_selected.emit(_selected)


func selected() -> int:
	return _selected


func _update_label() -> void:
	if _selected < 0:
		return
	var inside := present_in(_selected).size()
	_marker_label.text = "%s\n%d personne%s ici" % [building_name(_selected), inside, "s" if inside > 1 else ""]


var _label_timer := 0.0


func _physics_process(delta: float) -> void:
	_label_timer -= delta
	if _label_timer <= 0.0 and _selected >= 0:
		_label_timer = 1.0
		_update_label()
	_update_follow(delta)


# --- Ordres, déménagements, joueur -------------------------------------------------

func player_id() -> String:
	if _player_id == "":
		_player_id = SaveGame.player_id()
	return _player_id


## Le programme d'un habitant a changé (ordre, déménagement) : on le recalcule.
func plan_changed(pid: int) -> void:
	_now = {}
	if passants != null:
		passants.forget(pid)
	changed.emit()


func incarnated() -> int:
	return _incarne


## Prendre la place d'un habitant en vue au sol (3e personne). Retour en vue de
## dessus (V) : il reprend sa journée.
func incarnate(pid: int) -> bool:
	if vue_sol == null or not persons.has(pid) or rig == null:
		return false
	if Ordres.protected(self, persons[pid]):
		message.emit("C'est le personnage principal d'un autre joueur.")
		return false
	var pos := vie.position_of(pid)
	# Il sort sur le trottoir le plus proche.
	if transport != null:
		var snap := transport.network.find_snap(pos, TransportTypes.Mode.ROAD, 80.0)
		if not snap.is_empty():
			var sp: Vector3 = snap.pos
			var away := Vector3(pos.x - sp.x, 0.0, pos.z - sp.z)
			var hw := transport.network.half_width(int(snap.edge)) if int(snap.edge) >= 0 else 4.0
			pos = sp + (away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT) * (hw + 1.2)
	follow_camera = false
	rig.global_position = Vector3(pos.x, rig.global_position.y, pos.z)
	_incarne = pid
	if not vue_sol.vue_changee.is_connected(_on_vue):
		vue_sol.vue_changee.connect(_on_vue)
	if vue_sol.personnage != null:
		vue_sol.personnage.prendre_apparence(Silhouettes.apparence_habitant(self, pid))
	vue_sol.set_vue(VueSol.Vue.TROISIEME)
	var p: Dictionary = persons[pid]
	message.emit("Tu es %s. ZQSD pour marcher, V pour revenir à la vue de dessus." % CycleVie.full_name(p))
	plan_changed(pid)
	return true


func _on_vue(v: int) -> void:
	if v == VueSol.Vue.DESSUS and _incarne >= 0:
		var pid := _incarne
		_incarne = -1
		if vue_sol != null and vue_sol.personnage != null:
			vue_sol.personnage.prendre_apparence({})
		if persons.has(pid):
			message.emit("%s reprend sa journée." % CycleVie.full_name(persons[pid]))
		plan_changed(pid)


## Tout le foyer déménage dans un logement libre.
func move_household(hid: int, bid: int) -> void:
	var h: Dictionary = households[hid]
	var old := int(h.b)
	(by_home.get(old, []) as Array).erase(hid)
	h.b = bid
	if not by_home.has(bid):
		by_home[bid] = []
	(by_home[bid] as Array).append(hid)
	_venue_cache.clear()
	for m in h.m:
		vie.log_event(persons[m], "demenage", "Déménage avec son foyer à %s" % building_name(bid), bid)
		plan_changed(m)
	changed.emit()


## Ordre donné depuis l'interface (message dans le jeu).
func give_order(pid: int, id: String, arg: Variant = null) -> Dictionary:
	if not persons.has(pid):
		return {"ok": false, "text": "Habitant introuvable."}
	var r := Ordres.give(self, persons[pid], id, arg)
	message.emit(String(r.text))
	return r


# --- Habitant suivi (façon Sims) ----------------------------------------------------

func follow(pid: int) -> void:
	vie.follow(pid)
	follow_camera = vie.followed >= 0
	_follow_set = Vector3.INF
	_follow_timer = 0.0


func followed() -> int:
	return vie.followed


## Repère au-dessus de l'habitant suivi ; la caméra l'accompagne (sauf si le joueur la déplace).
func _update_follow(delta: float) -> void:
	var pid := vie.followed
	var on := pid >= 0 and persons.has(pid)
	_follow_marker.visible = on
	_follow_label.visible = on
	if not on:
		return
	_follow_timer -= delta
	if _follow_timer <= 0.0:
		_follow_timer = 0.25
		_now = {}
		_follow_target = vie.position_of(pid)
		var p: Dictionary = persons[pid]
		var a := activity(p)
		_follow_label.text = "★ %s %s, %d ans\n%s" % [p.p, p.n, age_years(p), a.text]
	var top := _follow_target + Vector3(0, 14.0, 0)
	if known.has(int(activity(persons[pid]).bid)):
		top.y = _follow_target.y + BuildingCatalog.approx_height(String(known[int(activity(persons[pid]).bid)].t)) + 4.0
	_follow_marker.position = _follow_marker.position.lerp(top, minf(1.0, delta * 6.0)) if _follow_marker.position != Vector3.ZERO else top
	_follow_marker.rotate_y(delta * 1.5)
	# Le repère grossit quand la caméra s'éloigne, pour rester visible.
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var k := 1.0
	if cam != null:
		k = clampf(cam.global_position.distance_to(_follow_marker.position) / 60.0, 1.0, 12.0)
	var b := _follow_marker.basis.orthonormalized()
	_follow_marker.basis = b.scaled(Vector3.ONE * k)
	_follow_label.position = _follow_marker.position + Vector3(0, 3.5 * k, 0)
	if rig == null or not follow_camera:
		return
	# Le joueur a déplacé la caméra : on le laisse faire.
	if _follow_set != Vector3.INF and Vector2(rig.position.x - _follow_set.x, rig.position.z - _follow_set.z).length() > 0.5:
		follow_camera = false
		_follow_set = Vector3.INF
		message.emit("Caméra libre. Clique sur la caméra de la fiche (ou F) pour suivre à nouveau.")
		follow_changed.emit()
		return
	var f := minf(1.0, delta * 3.0)
	rig.position.x = lerpf(rig.position.x, _follow_target.x, f)
	rig.position.z = lerpf(rig.position.z, _follow_target.z, f)
	_follow_set = rig.position


## Un outil est-il actif ? Dans ce cas le clic ne sert pas à choisir un bâtiment.
func _tools_busy() -> bool:
	if world != null and world.current_tool != TerrainWorld.Tool.INSPECT:
		return true
	if buildings != null and buildings.mode != BuildingSystem.Mode.NONE:
		return true
	if transport != null and (transport.tool != TransportSystem.Tool.NONE or transport.stations.tool != StationSystem.Tool.NONE):
		return true
	var zones := get_node_or_null("../Zones") as ZoneSystem
	if zones != null and zones.mode != ZoneSystem.Mode.NONE:
		return true
	var blocks := get_node_or_null("../Blocs") as BlockEditor
	if blocks != null and blocks.tool != BlockEditor.Tool.NONE:
		return true
	var plans := get_node_or_null("../Plans") as PlanEditor
	if plans != null and plans.tool != PlanEditor.Tool.NONE:
		return true
	var mob := get_node_or_null("../Mobilier") as Mobilier
	if mob != null and mob.tool != Mobilier.Tool.NONE:
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and key.physical_keycode == KEY_ESCAPE and order_pick >= 0:
		order_pick = -1
		message.emit("Ordre annulé.")
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or world == null or buildings == null:
		return
	if mb.pressed:
		_press = mb.position
		return
	if mb.position.distance_to(_press) > 6.0 or _tools_busy():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if order_pick < 0 and passants != null:
		var who := passants.pick(mb.position, cam)
		if who < 0 and extra_person_pick.is_valid():
			who = int(extra_person_pick.call(mb.position, cam))
		if who >= 0:
			person_clicked.emit(who)
			get_viewport().set_input_as_handled()
			return
	var hit: Variant = world.pick_cell(cam.project_ray_origin(mb.position), cam.project_ray_normal(mb.position))
	if hit == null:
		return
	var bid := buildings.building_at(hit)
	if bid < 0 and extra_pick.is_valid():
		bid = int(extra_pick.call(hit))
	if order_pick >= 0:
		if bid >= 0:
			if not known.has(bid):
				_sync_buildings()
			var who := order_pick
			order_pick = -1
			give_order(who, "aller", bid)
			get_viewport().set_input_as_handled()
		return
	if bid >= 0:
		if not known.has(bid):
			_sync_buildings()
		select_building(bid)
		get_viewport().set_input_as_handled()


# --- Sauvegarde ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var hs := []
	for hid in households:
		var h: Dictionary = households[hid]
		hs.append([hid, h.b, h.reg, snappedf(float(h.ep), 0.01), h.car])
	var ps := []
	for pid in persons:
		var p: Dictionary = persons[pid]
		ps.append([pid, p.f, p.p, p.n, p.s, snappedf(float(p.nj), 0.001), p.r, p.job, p.met, p.sch, ",".join(p.hob),
			CycleVie.pack(p)])
	return {"version": 2, "vie": vie.to_dict(), "principal": principal.to_dict(), "next_pid": next_pid, "next_hid": next_hid, "life_clock": life_clock,
		"life_speed": life_speed_index, "arrivals": arrivals, "last_day": last_day, "ledger": ledger,
		"money_frac": _money_frac, "foyers": hs, "habitants": ps}


func from_dict(d: Dictionary) -> void:
	persons.clear()
	households.clear()
	by_home.clear()
	by_job.clear()
	by_school.clear()
	known.clear()
	_venue_cache.clear()
	_arrival_acc.clear()
	next_pid = int(d.get("next_pid", 1))
	next_hid = int(d.get("next_hid", 1))
	life_clock = float(d.get("life_clock", 0.0))
	life_speed_index = clampi(int(d.get("life_speed", 0)), 0, LIFE_SPEEDS.size() - 1)
	arrivals = bool(d.get("arrivals", true))
	last_day = int(d.get("last_day", -1))
	last_unix = -1.0
	_money_frac = float(d.get("money_frac", 0.0))
	var l: Dictionary = d.get("ledger", {})
	ledger = {"mois": l.get("mois", {}), "precedent": l.get("precedent", {}), "jours": int(l.get("jours", 0))}
	if buildings != null:
		for bid in buildings.buildings:
			known[int(bid)] = _info_of(buildings.buildings[bid])
		var extra := _extras()
		for bid in extra:
			known[int(bid)] = extra[bid]
	for e in d.get("foyers", []):
		var bid := int(e[1])
		if not known.has(bid):
			continue
		var hid := int(e[0])
		households[hid] = {"id": hid, "b": bid, "reg": String(e[2]), "ep": float(e[3]), "car": int(e[4]), "m": []}
		if not by_home.has(bid):
			by_home[bid] = []
		(by_home[bid] as Array).append(hid)
	for e in d.get("habitants", []):
		var hid := int(e[1])
		if not households.has(hid):
			continue
		var pid := int(e[0])
		var hob := []
		for k in String(e[10]).split(",", false):
			if Metiers.LOISIRS.has(k):
				hob.append(k)
		var p := {"id": pid, "f": hid, "p": String(e[2]), "n": String(e[3]), "s": String(e[4]), "nj": float(e[5]),
			"r": String(e[6]), "job": -1, "met": "", "sch": -1, "hob": hob}
		if (e as Array).size() > 11 and e[11] is Dictionary:
			CycleVie.unpack(p, e[11])
		CycleVie.ensure(p)
		persons[pid] = p
		(households[hid].m as Array).append(pid)
		var job := int(e[7])
		if known.has(job):
			p.job = job
			p.met = String(e[8]) if Metiers.METIERS.has(String(e[8])) else Metiers.pick_job(rng, String(known[job].t))
			if not by_job.has(job):
				by_job[job] = []
			(by_job[job] as Array).append(pid)
		var sch := int(e[9])
		if known.has(sch) and int(known[sch].seats) > 0:
			_join_school(p, sch)
	# Foyers vides (données abîmées) : retirés.
	for hid in households.keys():
		if (households[hid].m as Array).is_empty():
			_remove_household(hid, "")
	vie.from_dict(d.get("vie", {}))
	principal.from_dict(d.get("principal", {}))
	# Ancienne sauvegarde (sans familles) : couples et parents devinés dans chaque foyer.
	if int(d.get("version", 1)) < 2:
		for hid in households:
			vie.link_household(hid)
		for pid in persons:
			var p: Dictionary = persons[pid]
			if (p.cv as Array).is_empty():
				vie.log_event(p, "naissance", "Naît loin d'ici", -1, float(p.nj))
	select_building(-1)
	_apres_embauches(true)
	follow_changed.emit()
	changed.emit()
