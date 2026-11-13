class_name Evenements
extends Node
## Événements de la ville : fêtes de quartier, marchés, matchs au stade,
## incendies, tempêtes et épidémies (panneau Infos, touche I).
##
## Le nœud vit sous la racine (/root/Evenements) pendant une partie, et
## Evenements.instance y donne accès. Il tient aussi la liste unique des
## incidents que les services d'urgence (pompiers, ambulances, police) traitent :
##
##   var ev := get_node_or_null("/root/Evenements")
##   ev.incident_declare.connect(func(inc): …)      # un véhicule part
##   ev.prendre_en_charge(inc.id, "pompiers")       # il est sur place
##   ev.resoudre(inc.id)                             # le travail est fini
##
## Incident : {id, type ("incendie", "malades", "arbre", "inondation",
## "accident"…), position (Vector3 du monde), batiment (id ou −1), gravite 1 à 3
## (= nombre de véhicules), besoin (Array : "pompiers", "ambulance", "police"),
## etat ("declare", "pris", "resolu"), services (Array), debut (unix), texte}.
## Sans intervention, un incendie grandit et s'étend, une épidémie progresse.
##
## Tant que personne n'écoute incident_declare (services d'urgence pas encore
## branchés), les secours sont simulés : la caserne, l'hôpital ou le
## commissariat le plus proche arrive après le trajet, puis règle l'incident.
##
## Le temps des événements est celui de l'horloge (DayNight.unix_time), mais
## les incendies ne vont jamais plus vite que 10 min de jeu par seconde.

signal incident_declare(incident: Dictionary)
signal incident_aggrave(id: int, gravite: int)
signal incident_resolu(id: int)
## Une nouvelle pour le fil d'actualité : {t, texte, pos, genre, ev}.
signal actualite(n: Dictionary)
signal changed

static var instance: Evenements

const TYPES := {
	"marche": {"nom": "Marché", "icone": "marche", "couleur": Color("f4a259")},
	"fete": {"nom": "Fête de quartier", "icone": "fete", "couleur": Color("ff8fb1")},
	"match": {"nom": "Match", "icone": "sport", "couleur": Color("9d4edd")},
	"incendie": {"nom": "Incendie", "icone": "feu", "couleur": Color("ef476f")},
	"tempete": {"nom": "Tempête", "icone": "tempete", "couleur": Color("6ea8fe")},
	"epidemie": {"nom": "Épidémie", "icone": "epidemie", "couleur": Color("06d6a0")},
	# Vie politique (scripts/avis) : nouvelles seulement.
	"politique": {"nom": "Vie politique", "icone": "urne", "couleur": Color("ffd166")},
	"manifestation": {"nom": "Manifestation", "icone": "pancarte", "couleur": Color("f77f00")},
}
## Vitesse maximale des incendies (secondes de jeu par seconde réelle).
const FEU_MAX_VITESSE := 600.0
## Part du prix d'un bâtiment payée pour une réparation complète.
const REPARATION := 0.6
const JOURNAL_MAX := 200
## Vitesse des secours simulés (m/s) et délai de départ (s de jeu).
const SECOURS_VITESSE := 13.9
const SECOURS_DEPART := 240.0

var buildings: BuildingSystem
var population: Population
var transport: TransportSystem
var ambiance: DayNight
var world: TerrainWorld
var rig: Node3D

## id -> événement {id, type, nom, debut, fin, pos (Vector3), bid, etat ("prevu", "en_cours", "fini"), data, auto}
var events: Dictionary = {}
var next_event := 1
var incidents: Dictionary = {}
var next_incident := 1
## Nouvelles, la plus récente d'abord.
var journal: Array = []
## Bâtiments abîmés : bid -> {d (0 à 1), cause, bache (tempête)}.
var degats: Dictionary = {}
## Bâtiments détruits : "x,z" -> {b (fiche du bâtiment), cause, t}.
var ruines: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Événements automatiques (fêtes, marchés, matchs) et catastrophes au hasard
## (sinon, réglages de la partie : ReglagesPartie.actuel).
var forcer_auto := -1
var forcer_catastrophes := -1

var fetes: FetesMarches
var matchs: Matchs
var incendies: Incendies
var tempetes: Tempetes
var epidemies: Epidemies
var visuels: Node3D

var _last_unix := NAN
var _last_day := -1
var _last_hour := -1
var _ruin_cells: Dictionary = {}
var _ruin_nodes: Dictionary = {}
var _hover := Vector2i.ZERO
var _hover_ok := false
## Outil de pose : "" ou un type ("marche", "fete", "incendie"…), et ce qu'on fait au clic.
var outil := ""
signal outil_change(t: String)


func _init() -> void:
	name = "Evenements"
	rng.randomize()


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(bs: BuildingSystem, pop: Population, tr: TransportSystem, amb: DayNight, w: TerrainWorld, r: Node3D) -> void:
	buildings = bs
	population = pop
	transport = tr
	ambiance = amb
	world = w
	rig = r
	visuels = Node3D.new()
	visuels.name = "Visuels"
	add_child(visuels)
	fetes = FetesMarches.new(self)
	matchs = Matchs.new(self)
	incendies = Incendies.new(self)
	tempetes = Tempetes.new(self)
	epidemies = Epidemies.new(self)
	if population != null:
		population.plan_hooks.append(_plan_hook)
	if buildings != null:
		var prev: Callable = buildings.extra_blocker
		buildings.extra_blocker = func(c: Vector2i) -> bool:
			return _ruin_cells.has(c) or (prev.is_valid() and prev.call(c))
		buildings.removed.connect(func(bid: int) -> void:
			degats.erase(bid)
			incendies.oublie(bid))
		buildings.added.connect(func(bid: int) -> void:
			if degats.has(bid):
				_apply_look(bid))
	if world != null:
		world.hovered_cell_changed.connect(func(c: Vector2i, ok: bool) -> void:
			_hover = c
			_hover_ok = ok)


func clear() -> void:
	for id in events.keys():
		_end_visuals(events[id])
	events.clear()
	incidents.clear()
	journal.clear()
	degats.clear()
	for k in _ruin_nodes:
		(_ruin_nodes[k] as Node).queue_free()
	_ruin_nodes.clear()
	ruines.clear()
	_ruin_cells.clear()
	next_event = 1
	next_incident = 1
	_last_unix = NAN
	_last_day = -1
	if matchs != null:
		matchs.clear()
	if tempetes != null:
		tempetes.clear()
	changed.emit()


# --- Temps ---------------------------------------------------------------------------

func now() -> float:
	return ambiance.unix_time if ambiance != null else 0.0


func local_now() -> Dictionary:
	if population != null:
		return population.now()
	return {"h": 10.0, "wd": 2, "month": 3, "day": 0, "mday": 10}


## Unix (UTC) d'une heure locale du jour de jeu `day` (Population.now().day).
func unix_at(day: int, hour: float) -> float:
	var off := ambiance.utc_offset() * 3600.0 if ambiance != null else 0.0
	return day * 86400.0 + hour * 3600.0 - off


func auto_on() -> bool:
	return forcer_auto == 1 if forcer_auto >= 0 else ReglagesPartie.actuel.evenements_auto


func catastrophes_on() -> bool:
	return forcer_catastrophes == 1 if forcer_catastrophes >= 0 else ReglagesPartie.actuel.catastrophes


func frequence() -> float:
	return ReglagesPartie.actuel.frequence_catastrophes


func _process(delta: float) -> void:
	if ambiance == null:
		return
	var t := now()
	if is_nan(_last_unix) or t < _last_unix - 1.0:
		_last_unix = t
	var dt := clampf(t - _last_unix, 0.0, 6.0 * 3600.0)
	_last_unix = t
	var n := local_now()
	var d := int(n.day)
	if _last_day < 0 or d < _last_day:
		_last_day = d
		_new_day(n)
	elif d > _last_day:
		_last_day = d
		_new_day(n)
	var hr := int(float(n.h))
	if hr != _last_hour:
		_last_hour = hr
		_new_hour(n)
	# Les incendies vont au plus à 10 min de jeu par seconde.
	var dt_feu := minf(dt, delta * FEU_MAX_VITESSE) if delta > 0.0 else dt
	_update_events(t)
	incendies.step(dt_feu)
	tempetes.step(dt, t)
	epidemies.step(dt)
	matchs.step(t, delta)
	fetes.step(t, delta)
	_secours_simules(t)


func _new_day(n: Dictionary) -> void:
	if auto_on():
		fetes.plan_day(n)
		matchs.plan_day(n)
	epidemies.new_day(n)
	if catastrophes_on():
		incendies.roll_day(n)
		tempetes.roll_day(n)
		epidemies.roll_day(n)


func _new_hour(_n: Dictionary) -> void:
	pass


## Les événements prévus commencent, ceux qui sont finis s'arrêtent.
func _update_events(t: float) -> void:
	for id in events.keys():
		var e: Dictionary = events[id]
		match String(e.etat):
			"prevu":
				if t >= float(e.debut):
					e.etat = "en_cours"
					_start(e)
			"en_cours":
				if float(e.fin) > 0.0 and t >= float(e.fin):
					finir(id)
			"fini":
				# On garde les événements finis un jour (panneau), puis on oublie.
				if t > float(e.fin) + 86400.0:
					events.erase(id)


func _start(e: Dictionary) -> void:
	_forget_plans()
	match String(e.type):
		"marche", "fete":
			fetes.on_start(e)
		"match":
			matchs.on_start(e)
		"tempete":
			tempetes.on_start(e)
	changed.emit()


## Termine un événement (fin prévue, feu éteint, épidémie passée…).
func finir(id: int) -> void:
	if not events.has(id):
		return
	var e: Dictionary = events[id]
	if String(e.etat) == "fini":
		return
	var was_running := String(e.etat) == "en_cours"
	e.etat = "fini"
	if float(e.fin) <= 0.0 or float(e.fin) > now():
		e.fin = now()
	if was_running:
		match String(e.type):
			"marche", "fete":
				fetes.on_end(e)
			"match":
				matchs.on_end(e)
			"tempete":
				tempetes.on_end(e)
			"epidemie":
				epidemies.on_end(e)
	_end_visuals(e)
	_forget_plans()
	changed.emit()


func _end_visuals(e: Dictionary) -> void:
	var node = e.get("node", null)
	if node != null and is_instance_valid(node):
		(node as Node).queue_free()
	e.erase("node")


## Ajoute un événement. debut/fin en unix ; fin = 0 : il finit quand son module le décide.
func ajouter(type: String, nom: String, debut: float, fin: float, pos: Vector3, bid := -1, data: Dictionary = {}, auto := true) -> int:
	var id := next_event
	next_event += 1
	events[id] = {"id": id, "type": type, "nom": nom, "debut": debut, "fin": fin, "pos": pos, "bid": bid,
		"etat": "prevu", "data": data, "auto": auto}
	changed.emit()
	return id


func en_cours(type := "") -> Array:
	var out := []
	for id in events:
		var e: Dictionary = events[id]
		if String(e.etat) == "en_cours" and (type == "" or String(e.type) == type):
			out.append(e)
	return out


func prevus(type := "") -> Array:
	var out := []
	for id in events:
		var e: Dictionary = events[id]
		if String(e.etat) == "prevu" and (type == "" or String(e.type) == type):
			out.append(e)
	return out


# --- Incidents (services d'urgence) ---------------------------------------------------

## Déclare un incident ; renvoie son id. Les services d'urgence y passent aussi
## leurs propres appels (accidents…), pour qu'il n'y ait qu'une liste.
func declarer(incident: Dictionary) -> int:
	var id := next_incident
	next_incident += 1
	var inc := incident.duplicate(true)
	inc.id = id
	inc.type = String(inc.get("type", "accident"))
	var p = inc.get("position", Vector3.ZERO)
	inc.position = p if p is Vector3 else Vector3.ZERO
	inc.batiment = int(inc.get("batiment", -1))
	inc.gravite = clampi(int(inc.get("gravite", 1)), 1, 3)
	var besoin = inc.get("besoin", [])
	if besoin is String:
		besoin = [besoin]
	inc.besoin = (besoin as Array).duplicate()
	inc.etat = "declare"
	inc.services = []
	inc.debut = now()
	if not inc.has("texte"):
		inc.texte = _incident_text(inc)
	incidents[id] = inc
	incident_declare.emit(inc)
	changed.emit()
	return id


func prendre_en_charge(id: int, service: String) -> void:
	if not incidents.has(id):
		return
	var inc: Dictionary = incidents[id]
	if String(inc.etat) == "resolu":
		return
	if not (inc.services as Array).has(service):
		(inc.services as Array).append(service)
	inc.etat = "pris"
	changed.emit()


## Fin de l'intervention (appelé par les services d'urgence après le travail sur place).
func resoudre(id: int) -> void:
	if not incidents.has(id):
		return
	var inc: Dictionary = incidents[id]
	if String(inc.etat) == "resolu":
		return
	inc.etat = "resolu"
	inc.fin = now()
	match String(inc.get("role", "")):
		"feu":
			incendies.on_resolu(inc)
		"arbre", "inondation":
			tempetes.on_resolu(inc)
		"malade":
			epidemies.on_resolu(inc)
	incident_resolu.emit(id)
	changed.emit()


func aggraver(id: int, gravite: int) -> void:
	if not incidents.has(id):
		return
	var inc: Dictionary = incidents[id]
	var g := clampi(gravite, 1, 3)
	if g == int(inc.gravite) or String(inc.etat) == "resolu":
		return
	inc.gravite = g
	incident_aggrave.emit(id, g)
	changed.emit()


func incident(id: int) -> Dictionary:
	return incidents.get(id, {})


## Incidents encore ouverts (déclarés ou pris en charge).
func incidents_ouverts() -> Array:
	var out := []
	for id in incidents:
		if String(incidents[id].etat) != "resolu":
			out.append(incidents[id])
	return out


## Les services d'urgence du jeu écoutent-ils les incidents ?
func secours_branches() -> bool:
	return not incident_declare.get_connections().is_empty()


func _incident_text(inc: Dictionary) -> String:
	match String(inc.type):
		"incendie": return "Incendie"
		"malades": return "Malade à transporter"
		"arbre": return "Arbre tombé sur la route"
		"inondation": return "Inondation"
	return "Accident"


## Bâtiment de service le plus proche (types du catalogue dont l'archétype ou le type correspond).
func service_proche(service: String, pos: Vector3) -> int:
	var keys := {"pompiers": ["pompiers", "caserne"], "ambulance": ["hopital", "clinique"], "police": ["police", "commissariat", "gendarmerie"]}
	var want: Array = keys.get(service, [service])
	var best := -1
	var bd := INF
	if buildings == null:
		return -1
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if b.get("chantier", false):
			continue
		var ok := false
		for k in Metiers.keys_of(String(b.t)):
			if want.has(k):
				ok = true
				break
		if not ok:
			continue
		var p := building_pos(bid)
		var d := p.distance_to(pos)
		if d < bd:
			bd = d
			best = bid
	return best


## Secours simulés tant que les services d'urgence ne sont pas branchés.
func _secours_simules(t: float) -> void:
	if secours_branches():
		return
	for id in incidents.keys():
		var inc: Dictionary = incidents[id]
		if String(inc.etat) == "resolu":
			continue
		if not inc.has("sim"):
			var arrive := INF
			var who := ""
			for s in inc.besoin:
				var st := service_proche(String(s), inc.position)
				if st >= 0:
					var d := building_pos(st).distance_to(inc.position) * 1.3
					var a := float(inc.debut) + SECOURS_DEPART + d / SECOURS_VITESSE
					if a < arrive:
						arrive = a
						who = String(s)
			inc.sim = {"arrive": arrive, "service": who, "fin": INF}
		var sim: Dictionary = inc.sim
		if is_inf(float(sim.arrive)):
			continue
		if String(inc.etat) == "declare" and t >= float(sim.arrive):
			prendre_en_charge(id, String(sim.service))
			sim.fin = t + _duree_intervention(inc)
		elif String(inc.etat) == "pris" and t >= float(sim.fin):
			resoudre(id)


func _duree_intervention(inc: Dictionary) -> float:
	match String(inc.type):
		"incendie": return 900.0 * int(inc.gravite)
		"arbre": return 1800.0
		"inondation": return 3600.0 * int(inc.gravite)
		"malades": return 600.0
	return 900.0


# --- Nouvelles ---------------------------------------------------------------------

func news(texte: String, pos := Vector3.INF, genre := "", ev := -1) -> void:
	var n := {"t": now(), "texte": texte, "pos": pos, "genre": genre, "ev": ev}
	journal.push_front(n)
	if journal.size() > JOURNAL_MAX:
		journal.resize(JOURNAL_MAX)
	actualite.emit(n)


## Heure locale lisible d'un instant unix (« sam. 14 h 05 »).
func heure_texte(unix: float) -> String:
	var off := ambiance.utc_offset() * 3600.0 if ambiance != null else 0.0
	var d := Time.get_datetime_dict_from_unix_time(int(unix + off))
	var jours := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
	return "%s %d/%d %d h %02d" % [jours[int(d.weekday)], int(d.day), int(d.month), int(d.hour), int(d.minute)]


## « 18 h 05 ».
func heure_courte(unix: float) -> String:
	var off := ambiance.utc_offset() * 3600.0 if ambiance != null else 0.0
	var d := Time.get_datetime_dict_from_unix_time(int(unix + off))
	return "%d h %02d" % [int(d.hour), int(d.minute)]


# --- Bâtiments -----------------------------------------------------------------------

func building_pos(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)


func building_name(bid: int) -> String:
	if population != null and population.known.has(bid):
		return population.building_name(bid)
	if buildings != null and buildings.buildings.has(bid):
		return String(BuildingCatalog.get_type(String(buildings.buildings[bid].t)).get("name", "Bâtiment"))
	return "Bâtiment"


## Hauteur du sol (y) en un point, 0 si inconnue.
func ground(x: float, z: float) -> float:
	if world == null:
		return 0.0
	var h := world.cell_height(Vector2i(floori(x), floori(z)))
	return 0.0 if is_nan(h) else h


## Dégâts d'un bâtiment (0 à 1). À 1, il est détruit (ruine à reconstruire).
func set_degats(bid: int, d: float, cause: String, bache := false) -> void:
	if buildings == null or not buildings.buildings.has(bid):
		return
	var old: Dictionary = degats.get(bid, {"d": 0.0, "cause": cause, "bache": false})
	var nd := clampf(maxf(d, 0.0), 0.0, 1.0)
	if nd >= 1.0:
		detruire(bid, cause)
		return
	if nd <= 0.001 and not bache:
		degats.erase(bid)
	else:
		degats[bid] = {"d": nd, "cause": cause if nd > float(old.d) else String(old.cause), "bache": bache or bool(old.bache)}
	_apply_look(bid)
	changed.emit()


func _apply_look(bid: int) -> void:
	var mi := buildings.node_of(bid)
	if mi == null:
		return
	var e: Dictionary = degats.get(bid, {})
	var cause := String(e.get("cause", ""))
	var d := float(e.get("d", 0.0))
	# Suie : seulement après un incendie ; bâche : toit abîmé par une tempête.
	mi.set_meta("ev_degats", ceili(d * 4.0) if cause == "incendie" and d > 0.0 else 0)
	mi.set_meta("ev_bache", 2 if bool(e.get("bache", false)) and d > 0.12 else (1 if bool(e.get("bache", false)) else 0))
	BatimentsVie.refresh_material(mi)


func set_panne(bid: int, on: bool) -> void:
	var mi := buildings.node_of(bid) if buildings != null else null
	if mi == null:
		return
	if bool(mi.get_meta("ev_panne", false)) == on:
		return
	mi.set_meta("ev_panne", on)
	BatimentsVie.refresh_material(mi)


func cout_reparation(bid: int) -> int:
	if not degats.has(bid) or not buildings.buildings.has(bid):
		return 0
	var b: Dictionary = buildings.buildings[bid]
	var c := int(b.get("cost", BuildingCatalog.cost(String(b.t))))
	return ReglagesPartie.prix(maxi(500, roundi(float(c) * REPARATION * maxf(float(degats[bid].d), 0.05))))


func _payer(cout: int, quoi: String) -> bool:
	if buildings.unlimited_money:
		return true
	if buildings.money < cout:
		buildings.message.emit("Pas assez d'argent pour %s (%s)." % [quoi, BuildingSystem.format_money(cout)])
		return false
	buildings.money -= cout
	return true


func reparer(bid: int) -> bool:
	if not degats.has(bid):
		return false
	var c := cout_reparation(bid)
	if not _payer(c, "réparer"):
		return false
	degats.erase(bid)
	_apply_look(bid)
	news("%s réparé (%s)." % [building_name(bid), BuildingSystem.format_money(c)], building_pos(bid), "reparation")
	changed.emit()
	return true


func reparer_tout() -> int:
	var n := 0
	for bid in degats.keys():
		if reparer(bid):
			n += 1
		else:
			break
	return n


## Le bâtiment est détruit : ses habitants partent, une ruine reste à reconstruire.
func detruire(bid: int, cause: String) -> void:
	if buildings == null or not buildings.buildings.has(bid):
		return
	var b: Dictionary = (buildings.buildings[bid] as Dictionary).duplicate(true)
	var name := building_name(bid)
	var rect := buildings._rect_of(b)
	var cells := buildings._cells_of(b)
	degats.erase(bid)
	incendies.oublie(bid)
	buildings.remove_quietly(bid)
	var key := "%d,%d" % [int(b.x), int(b.z)]
	b.erase("chantier")
	ruines[key] = {"b": b, "cause": cause, "t": now()}
	_spawn_ruin(key)
	for c in cells:
		_ruin_cells[c] = key
	news("%s détruit par %s : ruine à reconstruire." % [name, _cause_texte(cause)], BuildingSystem.rect_center(rect) + Vector3(0, float(b.h), 0), "ruine")
	changed.emit()


func _cause_texte(cause: String) -> String:
	match cause:
		"incendie": return "l'incendie"
		"tempete": return "la tempête"
		"inondation": return "l'inondation"
	return cause


func _spawn_ruin(key: String) -> void:
	var r: Dictionary = ruines[key]
	var b: Dictionary = r.b
	var rect := Rect2i(Vector2i(int(b.x), int(b.z)), BuildingCatalog.footprint(String(b.t), int(b.r)))
	var mi := EvVisuels.ruine(rect.size, String(r.cause), hash(key))
	mi.position = BuildingSystem.rect_center(rect) + Vector3(0, float(b.h), 0)
	mi.name = "Ruine_" + key.replace(",", "_")
	visuels.add_child(mi)
	_ruin_nodes[key] = mi


func cout_reconstruction(key: String) -> int:
	if not ruines.has(key):
		return 0
	var b: Dictionary = ruines[key].b
	return ReglagesPartie.prix(int(b.get("cost", BuildingCatalog.cost(String(b.t)))))


## Reconstruit une ruine (même bâtiment, même place) : un chantier commence.
func reconstruire(key: String) -> bool:
	if not ruines.has(key):
		return false
	var c := cout_reconstruction(key)
	if not _payer(c, "reconstruire"):
		return false
	var b: Dictionary = (ruines[key].b as Dictionary).duplicate(true)
	_retirer_ruine(key)
	# Nouveau chantier : sans date, BatimentsVie le fait reconstruire.
	b.erase("ne")
	b.erase("fin")
	b.id = buildings.next_id
	buildings.next_id += 1
	buildings.restore(b)
	news("Reconstruction de %s (%s)." % [String(BuildingCatalog.get_type(String(b.t)).get("name", "bâtiment")), BuildingSystem.format_money(c)],
		BuildingSystem.rect_center(buildings._rect_of(b)), "reparation")
	changed.emit()
	return true


## Déblaie une ruine sans reconstruire (le terrain redevient libre).
func deblayer(key: String) -> void:
	if not ruines.has(key):
		return
	_retirer_ruine(key)
	changed.emit()


func _retirer_ruine(key: String) -> void:
	for c in _ruin_cells.keys():
		if String(_ruin_cells[c]) == key:
			_ruin_cells.erase(c)
	if _ruin_nodes.has(key):
		(_ruin_nodes[key] as Node).queue_free()
		_ruin_nodes.erase(key)
	ruines.erase(key)


func ruine_at(c: Vector2i) -> String:
	return String(_ruin_cells.get(c, ""))


# --- Habitants : la journée change pendant un événement --------------------------------

## Accroché à Population.day_plan : malades à la maison ou à l'hôpital, visiteurs
## du marché, de la fête ou du match.
func _plan_hook(p: Dictionary, n: Dictionary, plan: Array) -> Array:
	var sick := epidemies.plan_for(p, n)
	if not sick.is_empty():
		return sick
	var day := int(n.day)
	for id in events:
		var e: Dictionary = events[id]
		if String(e.etat) == "fini" or not String(e.type) in ["marche", "fete", "match"]:
			continue
		var visit: Dictionary
		match String(e.type):
			"match":
				visit = matchs.visit_for(p, e, day)
			_:
				visit = fetes.visit_for(p, e, day)
		if visit.is_empty():
			continue
		# Seulement si l'habitant est libre à cette heure-là.
		var t0 := float(visit.t)
		var free := false
		for seg in plan:
			if t0 >= float(seg[0]) and t0 < float(seg[1]):
				free = String(seg[2]) in ["maison", "loisir", "sport", "courses", "promenade"]
				break
		if free:
			return population._apply_order(p, plan, visit)
	return plan


## Une route a été coupée ou rouverte : les passants recalculent leurs itinéraires
## (les véhicules prennent les nouveaux à leur prochain trajet).
func reroute() -> void:
	if population != null and population.passants != null:
		population.passants._routes.clear()


## Les emplois du temps en cache des passants sont refaits.
func _forget_plans() -> void:
	if population != null and population.passants != null:
		population.passants._plans.clear()


## Bâtiment connu des habitants le plus proche d'un point (pour s'y rendre).
func nearest_known(pos: Vector3, max_d := 400.0) -> int:
	if population == null:
		return -1
	var best := -1
	var bd := max_d
	for bid in population.known:
		var d := Vector2(pos.x, pos.z).distance_to(Vector2(population.known[bid].pos.x, population.known[bid].pos.z))
		if d < bd:
			bd = d
			best = bid
	return best


# --- Outil de pose (panneau Infos) ------------------------------------------------------

func set_outil(t: String) -> void:
	outil = t
	outil_change.emit(t)


func _unhandled_input(event: InputEvent) -> void:
	if outil == "":
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			set_outil("")
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and _hover_ok:
			var t := outil
			if poser(t, _hover):
				set_outil("")
			get_viewport().set_input_as_handled()
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE:
		set_outil("")
		get_viewport().set_input_as_handled()


## Organise ou déclenche un événement à la case c (clic du joueur).
func poser(t: String, c: Vector2i) -> bool:
	var pos := Vector3(c.x + 0.5, ground(c.x + 0.5, c.y + 0.5), c.y + 0.5)
	match t:
		"marche", "fete":
			return fetes.organiser(t, pos) >= 0
		"incendie":
			var bid := buildings.building_at(c)
			if bid < 0:
				buildings.message.emit("Clique sur un bâtiment pour y mettre le feu.")
				return false
			return incendies.start_fire(bid, "manuel") >= 0
	return false


## Déclenche tout de suite une catastrophe (bac à sable, panneau Infos).
func declencher(t: String) -> int:
	match t:
		"tempete":
			return tempetes.start(now(), 4.0, false)
		"epidemie":
			return epidemies.start("", false)
		"incendie":
			return incendies.start_random()
	return -1


# --- Sauvegarde --------------------------------------------------------------------------

static func v3(v: Vector3) -> Array:
	if not v.is_finite():
		return []
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


static func to_v3(a) -> Vector3:
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.INF


func to_dict() -> Dictionary:
	var evs := []
	for id in events:
		var e: Dictionary = events[id]
		if String(e.etat) == "fini":
			continue
		evs.append({"id": e.id, "type": e.type, "nom": e.nom, "debut": e.debut, "fin": e.fin, "pos": v3(e.pos),
			"bid": e.bid, "etat": e.etat, "auto": e.auto, "data": _data_out(e)})
	var incs := []
	for id in incidents:
		var inc: Dictionary = incidents[id]
		if String(inc.etat) == "resolu":
			continue
		var o := inc.duplicate(true)
		o.position = v3(inc.position)
		o.erase("sim")
		incs.append(o)
	var jr := []
	for n in journal.slice(0, 80):
		jr.append({"t": n.t, "texte": n.texte, "pos": v3(n.pos), "genre": n.genre, "ev": n.ev})
	var dg := {}
	for bid in degats:
		dg[str(bid)] = degats[bid]
	return {"version": 1, "next_event": next_event, "next_incident": next_incident, "events": evs,
		"incidents": incs, "journal": jr, "degats": dg, "ruines": ruines.duplicate(true),
		"matchs": matchs.to_dict(), "epidemies": epidemies.to_dict()}


func _data_out(e: Dictionary) -> Dictionary:
	var d: Dictionary = (e.data as Dictionary).duplicate(true)
	for k in d.keys():
		if d[k] is Vector3:
			d[k] = {"v3": v3(d[k])}
	return d


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	next_event = int(d.get("next_event", 1))
	next_incident = int(d.get("next_incident", 1))
	matchs.from_dict(d.get("matchs", {}))
	epidemies.from_dict(d.get("epidemies", {}))
	for k in (d.get("ruines", {}) as Dictionary):
		var r: Dictionary = d.ruines[k]
		var b: Dictionary = r.get("b", {})
		if BuildingCatalog.get_type(String(b.get("t", ""))).is_empty():
			continue
		for key in ["id", "x", "z", "r", "zone", "cost", "v"]:
			if b.has(key):
				b[key] = int(b[key])
		for key in ["a", "h", "ne", "fin"]:
			if b.has(key):
				b[key] = float(b[key])
		ruines[String(k)] = {"b": b, "cause": String(r.get("cause", "incendie")), "t": float(r.get("t", 0.0))}
		_spawn_ruin(String(k))
		for c in BuildingSystem.cells_for(String(b.t), Vector2i(int(b.x), int(b.z)) + BuildingCatalog.footprint(String(b.t), int(b.r)) / 2, int(b.r), float(b.get("a", 0.0))):
			_ruin_cells[c] = String(k)
	for k in (d.get("degats", {}) as Dictionary):
		var bid := int(k)
		var e: Dictionary = d.degats[k]
		if buildings.buildings.has(bid):
			degats[bid] = {"d": float(e.get("d", 0.0)), "cause": String(e.get("cause", "")), "bache": bool(e.get("bache", false))}
			_apply_look(bid)
	for n in d.get("journal", []):
		journal.append({"t": float(n.t), "texte": String(n.texte), "pos": to_v3(n.get("pos", [])), "genre": String(n.get("genre", "")), "ev": int(n.get("ev", -1))})
	for o in d.get("incidents", []):
		var inc: Dictionary = (o as Dictionary).duplicate(true)
		inc.id = int(inc.id)
		inc.position = to_v3(inc.get("position", []))
		if not inc.position.is_finite():
			inc.position = Vector3.ZERO
		inc.gravite = int(inc.get("gravite", 1))
		inc.batiment = int(inc.get("batiment", -1))
		for key in ["ev", "pid"]:
			if inc.has(key):
				inc[key] = int(inc[key])
		incidents[inc.id] = inc
	for o in d.get("events", []):
		var e := {"id": int(o.id), "type": String(o.type), "nom": String(o.nom), "debut": float(o.debut), "fin": float(o.fin),
			"pos": to_v3(o.get("pos", [])), "bid": int(o.get("bid", -1)), "etat": "prevu", "auto": bool(o.get("auto", true)), "data": {}}
		if not (e.pos as Vector3).is_finite():
			e.pos = Vector3.ZERO
		var data: Dictionary = o.get("data", {})
		for k in data:
			var v = data[k]
			if v is Dictionary and (v as Dictionary).has("v3"):
				v = to_v3(v.v3)
			data[k] = v
		e.data = data
		events[e.id] = e
		match String(e.type):
			"incendie":
				incendies.restore(e)
			"epidemie":
				epidemies.restore(e)
		# Déjà commencé : il reprend (visuels refaits).
		if String(o.get("etat", "prevu")) == "en_cours":
			e.etat = "en_cours"
			_start(e)
	_last_unix = now()
	_last_day = int(local_now().day)
	# Les incidents rechargés sont annoncés à nouveau aux services d'urgence.
	for id in incidents:
		incident_declare.emit(incidents[id])
	changed.emit()
