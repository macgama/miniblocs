class_name Epidemies
extends RefCounted
## Épidémies : une maladie contagieuse passe d'un habitant à l'autre.
##
## - Au hasard (réglage Admin), surtout la grippe en hiver, ou à la main
##   (panneau Infos). Quelques premiers malades, puis la maladie se transmet
##   chaque jour dans le foyer, au travail et à l'école.
## - Un malade reste chez lui (il ne va ni au travail ni à l'école : moins de
##   travailleurs). Les cas graves appellent une ambulance (incident « malades »)
##   et sont soignés à l'hôpital s'il y en a un.
## - Quelques-uns en meurent, surtout les plus âgés et sans hôpital proche
##   (leur CV et leur famille le gardent, voir CycleVie).
## - Guéri : immunisé pour cette épidémie. Elle s'arrête quand plus personne
##   n'est malade.

const MALADIES := {
	"grippe": {"nom": "grippe", "art": "la grippe", "de": "de la grippe", "contagion": 0.035, "jours": [4, 8], "grave": 0.04, "letal": 0.06, "hiver": true},
	"gastro": {"nom": "gastro-entérite", "art": "la gastro-entérite", "de": "de la gastro-entérite", "contagion": 0.05, "jours": [2, 4], "grave": 0.01, "letal": 0.005, "hiver": true},
	"virus": {"nom": "virus respiratoire", "art": "le virus respiratoire", "de": "du virus respiratoire", "contagion": 0.03, "jours": [6, 14], "grave": 0.08, "letal": 0.12, "hiver": false},
	"rougeole": {"nom": "rougeole", "art": "la rougeole", "de": "de la rougeole", "contagion": 0.07, "jours": [7, 12], "grave": 0.03, "letal": 0.01, "hiver": false, "enfants": true},
}
const RISQUE_JOUR := 1.0 / 120.0
const CONTACTS_TRAVAIL := 4

var ev: Evenements
## Épidémie en cours : id de l'événement (une à la fois), −1 sinon.
var active := -1
## pid -> {fin (jour), grave (bool), hop (bool), inc}
var malades: Dictionary = {}
var immunises: Dictionary = {}
var _hospital_cache := {}


func _init(e: Evenements) -> void:
	ev = e


func roll_day(n: Dictionary) -> void:
	if active >= 0 or ev.population == null or ev.population.persons.size() < 40:
		return
	var p := RISQUE_JOUR * ev.frequence()
	var winter := int(n.month) in [11, 12, 1, 2, 3]
	if winter:
		p *= 2.5
	if ev.rng.randf() < p:
		var keys := []
		for k in MALADIES:
			if not winter and bool(MALADIES[k].hiver):
				continue
			keys.append(k)
		start(keys[ev.rng.randi() % keys.size()] if not keys.is_empty() else "virus", true)


## Démarre une épidémie (maladie "" : au hasard). Renvoie l'id de l'événement.
func start(maladie: String, auto: bool) -> int:
	if active >= 0 and ev.events.has(active):
		return active
	if ev.population == null or ev.population.persons.is_empty():
		ev.buildings.message.emit("Pas d'habitants : pas d'épidémie possible.")
		return -1
	if maladie == "" or not MALADIES.has(maladie):
		var keys := MALADIES.keys()
		maladie = keys[ev.rng.randi() % keys.size()]
	var m: Dictionary = MALADIES[maladie]
	malades.clear()
	immunises.clear()
	_hospital_cache.clear()
	var id := ev.ajouter("epidemie", "Épidémie de %s" % m.nom, ev.now(), 0.0, Vector3.INF, -1,
		{"maladie": maladie, "total": 0, "deces": 0, "graves": 0, "jour0": int(ev.local_now().day)}, auto)
	var e: Dictionary = ev.events[id]
	e.etat = "en_cours"
	active = id
	var pids := ev.population.persons.keys()
	var n := clampi(pids.size() / 120, 2, 8)
	var first_pos := Vector3.INF
	for i in n:
		var pid: int = pids[ev.rng.randi() % pids.size()]
		_infect(pid, e)
		if not first_pos.is_finite():
			first_pos = _home_pos(pid)
	e.pos = first_pos if first_pos.is_finite() else Vector3.ZERO
	ev.news("Épidémie de %s : %d premiers malades. Ils restent chez eux." % [m.nom, malades.size()], e.pos, "epidemie", id)
	ev._forget_plans()
	return id


func _home_pos(pid: int) -> Vector3:
	var p: Dictionary = ev.population.persons.get(pid, {})
	if p.is_empty():
		return Vector3.INF
	var home := ev.population.home_of(p)
	return ev.population.building_pos(home) if ev.population.known.has(home) else Vector3.INF


func _infect(pid: int, e: Dictionary) -> void:
	if malades.has(pid) or immunises.has(pid) or not ev.population.persons.has(pid):
		return
	var m: Dictionary = MALADIES[String(e.data.maladie)]
	var p: Dictionary = ev.population.persons[pid]
	var age := ev.population.age_of(p)
	var j: Array = m.jours
	var day := int(ev.local_now().day)
	var grave_p := float(m.grave) * (3.0 if age >= 70.0 else (1.6 if age >= 55.0 else (1.5 if age < 3.0 else 1.0)))
	var grave := ev.rng.randf() < grave_p
	malades[pid] = {"fin": day + ev.rng.randi_range(int(j[0]), int(j[1])) + (3 if grave else 0), "grave": grave, "hop": false, "inc": -1}
	e.data.total = int(e.data.total) + 1
	if ev.population.vie != null:
		ev.population.vie.log_event(p, "maladie", "Tombe malade : %s" % m.nom)
	if grave:
		e.data.graves = int(e.data.graves) + 1
		var pos := _home_pos(pid)
		if pos.is_finite():
			malades[pid].inc = ev.declarer({"type": "malades", "position": pos, "batiment": ev.population.home_of(p),
				"gravite": 1, "besoin": ["ambulance"], "role": "malade", "ev": int(e.id), "pid": pid,
				"texte": "Malade grave à transporter (%s)" % m.nom})


## L'ambulance a emmené le malade : il est soigné à l'hôpital.
func on_resolu(inc: Dictionary) -> void:
	var pid := int(inc.get("pid", -1))
	if malades.has(pid):
		malades[pid].hop = _hospital_for(pid) >= 0
		ev._forget_plans()


func _hospital_for(pid: int) -> int:
	if _hospital_cache.has(pid):
		return _hospital_cache[pid]
	var pos := _home_pos(pid)
	var bid := ev.service_proche("ambulance", pos) if pos.is_finite() else -1
	if bid >= 0 and not ev.population.known.has(bid):
		bid = -1
	_hospital_cache[pid] = bid
	return bid


## Chaque jour : contagion, guérisons, décès.
func new_day(n: Dictionary) -> void:
	if active < 0 or not ev.events.has(active):
		return
	var e: Dictionary = ev.events[active]
	var m: Dictionary = MALADIES[String(e.data.maladie)]
	var pop := ev.population
	var day := int(n.day)
	var newly := []
	for pid in malades.keys():
		if not pop.persons.has(pid):
			malades.erase(pid)
			continue
		var p: Dictionary = pop.persons[pid]
		for c in _contacts(p):
			if malades.has(c) or immunises.has(c):
				continue
			var k := float(m.contagion)
			if bool(m.get("enfants", false)) and pop.age_of(pop.persons[c]) > 16.0:
				k *= 0.15
			if ev.rng.randf() < k:
				newly.append(c)
	for c in newly:
		_infect(c, e)
	# Fin de la maladie : guérison ou décès pour les cas graves.
	for pid in malades.keys():
		var s: Dictionary = malades[pid]
		if day < int(s.fin):
			continue
		var p: Dictionary = pop.persons.get(pid, {})
		malades.erase(pid)
		if p.is_empty():
			continue
		if bool(s.grave):
			var age := pop.age_of(p)
			var q := float(m.letal) * (4.0 if age >= 80.0 else (2.0 if age >= 65.0 else 0.5))
			q *= 0.35 if bool(s.hop) else (2.0 if _hospital_for(pid) < 0 else 1.0)
			if ev.rng.randf() < clampf(q, 0.0, 0.9):
				e.data.deces = int(e.data.deces) + 1
				var name := "%s %s" % [String(p.get("p", "")), String(p.get("n", ""))]
				var pos := _home_pos(pid)
				if pop.vie != null:
					pop.vie.die(pid, String(m.de))
				ev.news("Décès de %s, emporté·e par %s." % [name.strip_edges(), m.art], pos, "epidemie", int(e.id))
				continue
		immunises[pid] = true
		if pop.vie != null:
			pop.vie.log_event(p, "guerison", "Guérit %s" % m.de)
		var inc := int(s.inc)
		if inc >= 0 and not ev.incident(inc).is_empty() and String(ev.incident(inc).etat) != "resolu":
			ev.resoudre(inc)
	ev._forget_plans()
	if not newly.is_empty() and (day - int(e.data.jour0)) % 3 == 0:
		ev.news("Épidémie de %s : %d malades en ce moment, %d en tout." % [m.nom, malades.size(), int(e.data.total)], e.pos, "epidemie", int(e.id))
	if malades.is_empty():
		ev.finir(active)


func _contacts(p: Dictionary) -> Array:
	var pop := ev.population
	var out := []
	var hid := int(p.get("f", -1))
	if pop.households.has(hid):
		for m in pop.households[hid].m:
			if int(m) != int(p.id):
				out.append(int(m))
	for key in ["job", "sch"]:
		var bid := int(p.get(key, -1))
		if bid < 0:
			continue
		var list: Array = (pop.by_job if key == "job" else pop.by_school).get(bid, [])
		for i in mini(CONTACTS_TRAVAIL, list.size()):
			out.append(int(list[ev.rng.randi() % list.size()]))
	return out


func on_end(e: Dictionary) -> void:
	var m: Dictionary = MALADIES.get(String(e.data.maladie), MALADIES.grippe)
	ev.news("Fin de l'épidémie de %s : %d malades, %d cas graves, %d décès." % [m.nom, int(e.data.total), int(e.data.graves), int(e.data.deces)],
		Vector3.INF, "epidemie", int(e.id))
	if active == int(e.id):
		active = -1
	malades.clear()
	immunises.clear()


func step(_dt: float) -> void:
	pass


## La journée d'un malade : à la maison, ou à l'hôpital pour un cas grave pris en charge.
func plan_for(p: Dictionary, _n: Dictionary) -> Array:
	var pid := int(p.id)
	if not malades.has(pid):
		return []
	var home := ev.population.home_of(p)
	var s: Dictionary = malades[pid]
	if bool(s.hop):
		var h := _hospital_for(pid)
		if h >= 0:
			return [[0.0, 24.0, "soins", h, "Hospitalisé·e (%s)" % ev.population.building_name(h)]]
	var m: Dictionary = MALADIES.get(String(ev.events.get(active, {}).get("data", {}).get("maladie", "grippe")), MALADIES.grippe)
	return [[0.0, 24.0, "maison", home, "Malade (%s), reste à la maison" % m.nom]]


func malades_count() -> int:
	return malades.size()


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ml := {}
	for pid in malades:
		ml[str(pid)] = malades[pid]
	return {"active": active, "malades": ml, "immunises": immunises.keys()}


func from_dict(d: Dictionary) -> void:
	active = int(d.get("active", -1))
	malades.clear()
	immunises.clear()
	_hospital_cache.clear()
	for k in (d.get("malades", {}) as Dictionary):
		var s: Dictionary = d.malades[k]
		malades[int(k)] = {"fin": int(s.get("fin", 0)), "grave": bool(s.get("grave", false)), "hop": bool(s.get("hop", false)), "inc": int(s.get("inc", -1))}
	for pid in d.get("immunises", []):
		immunises[int(pid)] = true


func restore(e: Dictionary) -> void:
	for k in ["total", "deces", "graves", "jour0"]:
		e.data[k] = int(e.data.get(k, 0))
	active = int(e.id)
