class_name Epidemies
extends RefCounted
## Épidémies : une maladie contagieuse passe d'un habitant à l'autre.
##
## - Au hasard (réglage Admin), surtout la grippe en hiver, ou à la main
##   (panneau Infos). Quelques premiers malades, puis la maladie se transmet
##   chaque jour dans le foyer, au travail et à l'école.
## - Chaque maladie a ses années (époques) : la variole jusqu'en 1977, le
##   choléra de 1817 à 1923… Les grandes épidémies de l'histoire (choléra de
##   1832, grippe espagnole de 1918, Covid-19 en 2020) arrivent l'année venue
##   (SantePublique, panneau F7).
## - Mode "eau" (choléra, typhoïde) : la maladie passe surtout par l'eau souillée
##   (puits près des fosses, réseau mal traité) ; les égouts et l'eau potable
##   l'arrêtent. Mode "air" et "contact" : par les proches.
## - Un malade reste chez lui (il ne va ni au travail ni à l'école : moins de
##   travailleurs). Les cas graves appellent une ambulance (incident « malades »)
##   et sont soignés à l'hôpital s'il y en a un.
## - Quelques-uns en meurent, surtout les plus âgés et sans hôpital proche
##   (leur CV et leur famille le gardent, voir CycleVie).
## - Guéri : immunisé pour cette épidémie. Elle s'arrête quand plus personne
##   n'est malade.
## - Vaccins, mesures sanitaires (quarantaine, écoles fermées, masques…) et
##   hygiène : SantePublique (s'il existe) module la contagion et la gravité.

## annees : [première, dernière] année où la maladie circule ; historique :
## elle n'arrive que par le calendrier des grandes épidémies (SantePublique) ;
## eau : contagion par l'eau souillée (par jour, habitant très exposé) ;
## traitement : [année, facteur de létalité] (réhydratation, antibiotiques…) ;
## jeunes : les jeunes adultes en meurent plus (grippe de 1918).
const MALADIES := {
	"grippe": {"nom": "grippe", "art": "la grippe", "de": "de la grippe", "contagion": 0.035, "jours": [4, 8], "grave": 0.04, "letal": 0.06, "hiver": true, "mode": "air"},
	"gastro": {"nom": "gastro-entérite", "art": "la gastro-entérite", "de": "de la gastro-entérite", "contagion": 0.05, "jours": [2, 4], "grave": 0.01, "letal": 0.005, "hiver": true, "mode": "contact"},
	"virus": {"nom": "virus respiratoire", "art": "le virus respiratoire", "de": "du virus respiratoire", "contagion": 0.03, "jours": [6, 14], "grave": 0.08, "letal": 0.12, "hiver": false, "mode": "air", "annees": [1950, 9999]},
	"rougeole": {"nom": "rougeole", "art": "la rougeole", "de": "de la rougeole", "contagion": 0.07, "jours": [7, 12], "grave": 0.03, "letal": 0.01, "hiver": false, "enfants": true, "mode": "air"},
	"cholera": {"nom": "choléra", "art": "le choléra", "de": "du choléra", "contagion": 0.006, "eau": 0.05, "jours": [2, 5], "grave": 0.35, "letal": 0.45, "hiver": false,
		"mode": "eau", "annees": [1817, 1923], "historique": true, "traitement": [1945, 0.15]},
	"typhoide": {"nom": "typhoïde", "art": "la typhoïde", "de": "de la typhoïde", "contagion": 0.008, "eau": 0.025, "jours": [10, 20], "grave": 0.2, "letal": 0.15, "hiver": false,
		"mode": "eau", "annees": [1800, 1960], "traitement": [1948, 0.2]},
	"variole": {"nom": "variole", "art": "la variole", "de": "de la variole", "contagion": 0.06, "jours": [12, 20], "grave": 0.3, "letal": 0.3, "hiver": true,
		"mode": "air", "annees": [1800, 1977]},
	"diphterie": {"nom": "diphtérie", "art": "la diphtérie", "de": "de la diphtérie", "contagion": 0.05, "jours": [5, 10], "grave": 0.2, "letal": 0.2, "hiver": true,
		"enfants": true, "mode": "contact", "annees": [1800, 1990], "traitement": [1894, 0.4]},
	"polio": {"nom": "poliomyélite", "art": "la polio", "de": "de la polio", "contagion": 0.03, "jours": [7, 14], "grave": 0.05, "letal": 0.1, "hiver": false,
		"enfants": true, "mode": "contact", "annees": [1900, 1990]},
	"grippe_espagnole": {"nom": "grippe espagnole", "art": "la grippe espagnole", "de": "de la grippe espagnole", "contagion": 0.06, "jours": [4, 9], "grave": 0.15, "letal": 0.25, "hiver": false,
		"mode": "air", "annees": [1918, 1920], "historique": true, "jeunes": true},
	"grippe_asiatique": {"nom": "grippe asiatique", "art": "la grippe asiatique", "de": "de la grippe asiatique", "contagion": 0.045, "jours": [4, 8], "grave": 0.06, "letal": 0.1, "hiver": false,
		"mode": "air", "annees": [1957, 1958], "historique": true},
	"grippe_hk": {"nom": "grippe de Hong Kong", "art": "la grippe de Hong Kong", "de": "de la grippe de Hong Kong", "contagion": 0.045, "jours": [4, 8], "grave": 0.06, "letal": 0.1, "hiver": true,
		"mode": "air", "annees": [1968, 1970], "historique": true},
	"covid": {"nom": "Covid-19", "art": "le Covid-19", "de": "du Covid-19", "contagion": 0.045, "jours": [6, 14], "grave": 0.07, "letal": 0.15, "hiver": false,
		"mode": "air", "annees": [2020, 2023], "historique": true},
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
		var an := annee()
		var sp := _sante()
		for k in MALADIES:
			if not winter and bool(MALADIES[k].hiver):
				continue
			if not circule(k, an) or bool(MALADIES[k].get("historique", false)):
				continue
			# Ville presque toute vaccinée : la maladie ne prend pas.
			if sp != null and sp.immunite_collective(k):
				continue
			keys.append(k)
		if keys.is_empty():
			return
		start(keys[ev.rng.randi() % keys.size()], true)


## Année du calendrier (époques), sinon l'année de l'horloge.
static func annee() -> int:
	return Epoques.annee()


## La maladie circule-t-elle cette année-là ?
static func circule(k: String, an: int) -> bool:
	if not MALADIES.has(k):
		return false
	var a: Array = MALADIES[k].get("annees", [0, 99999])
	return an >= int(a[0]) and an <= int(a[1])


## Maladies possibles cette année (panneau, bouton « Épidémie maintenant »).
static func du_moment(an: int) -> Array:
	var out := []
	for k in MALADIES:
		if circule(k, an):
			out.append(k)
	return out


func _sante() -> Object:
	var sp = SantePublique.instance
	if sp != null and is_instance_valid(sp) and sp.ev == ev:
		return sp
	return null


## Démarre une épidémie (maladie "" : au hasard). Renvoie l'id de l'événement.
func start(maladie: String, auto: bool) -> int:
	if active >= 0 and ev.events.has(active):
		return active
	if ev.population == null or ev.population.persons.is_empty():
		ev.buildings.message.emit("Pas d'habitants : pas d'épidémie possible.")
		return -1
	if maladie == "" or not MALADIES.has(maladie):
		var keys := []
		for k in du_moment(annee()):
			if not bool(MALADIES[k].get("historique", false)):
				keys.append(k)
		if keys.is_empty():
			keys = ["grippe", "gastro", "rougeole"]
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
	var essais := 0
	while malades.size() < n and essais < n * 6:
		essais += 1
		var pid: int = pids[ev.rng.randi() % pids.size()]
		_infect(pid, e)
		if not first_pos.is_finite() and malades.has(pid):
			first_pos = _home_pos(pid)
	if malades.is_empty():
		# Tout le monde est protégé : l'épidémie tourne court.
		ev.news("%s arrive aux portes de la ville… et rebrousse chemin : presque tout le monde est vacciné." % (String(m.art).left(1).to_upper() + String(m.art).substr(1)), Vector3.INF, "epidemie", id)
		active = id
		ev.finir(id)
		return id
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
	var sp := _sante()
	if sp != null and sp.protege(pid, String(e.data.maladie), p):
		return
	var grave_p := float(m.grave) * (3.0 if age >= 70.0 else (1.6 if age >= 55.0 else (1.5 if age < 3.0 else 1.0)))
	if bool(m.get("jeunes", false)) and age >= 18.0 and age < 40.0:
		grave_p *= 2.5
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
	var sp := _sante()
	var mk := String(e.data.maladie)
	var fk := {"foyer": 1.0, "travail": 1.0, "ecole": 1.0}
	if sp != null:
		for ctx in fk:
			fk[ctx] = sp.facteur_contagion(mk, ctx)
	for pid in malades.keys():
		if not pop.persons.has(pid):
			malades.erase(pid)
			continue
		var p: Dictionary = pop.persons[pid]
		for cc in _contacts_ctx(p):
			var c: int = cc[0]
			if malades.has(c) or immunises.has(c) or not pop.persons.has(c):
				continue
			var k := float(m.contagion) * float(fk[cc[1]])
			if bool(m.get("enfants", false)) and pop.age_of(pop.persons[c]) > 16.0:
				k *= 0.15
			if ev.rng.randf() < k:
				newly.append(c)
	# Maladies de l'eau : puits souillés et réseau mal traité.
	if sp != null and float(m.get("eau", 0.0)) > 0.0:
		for c in sp.contamines_eau(malades, mk, ev.rng):
			if not malades.has(c) and not immunises.has(c):
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
			if bool(m.get("jeunes", false)) and age >= 18.0 and age < 40.0:
				q *= 3.0
			var sans_hop := _hospital_for(pid) < 0
			if sp != null:
				q *= sp.facteur_letalite(mk, bool(s.hop), sans_hop)
				if sans_hop and sp.lazaret():
					sans_hop = false
			q *= 0.35 if bool(s.hop) else (2.0 if sans_hop else 1.0)
			if ev.rng.randf() < clampf(q, 0.0, 0.9):
				e.data.deces = int(e.data.deces) + 1
				if sp != null:
					sp.noter_deces(mk, p)
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
	var out := []
	for cc in _contacts_ctx(p):
		out.append(cc[0])
	return out


## Contacts du jour avec leur lieu : [[pid, "foyer" | "travail" | "ecole"], …].
func _contacts_ctx(p: Dictionary) -> Array:
	var pop := ev.population
	var out := []
	var hid := int(p.get("f", -1))
	if pop.households.has(hid):
		for m in pop.households[hid].m:
			if int(m) != int(p.id):
				out.append([int(m), "foyer"])
	for key in ["job", "sch"]:
		var bid := int(p.get(key, -1))
		if bid < 0:
			continue
		var list: Array = (pop.by_job if key == "job" else pop.by_school).get(bid, [])
		for i in mini(CONTACTS_TRAVAIL, list.size()):
			out.append([int(list[ev.rng.randi() % list.size()]), "travail" if key == "job" else "ecole"])
	return out


func on_end(e: Dictionary) -> void:
	var m: Dictionary = MALADIES.get(String(e.data.maladie), MALADIES.grippe)
	if int(e.data.total) > 0:
		ev.news("Fin de l'épidémie de %s : %d malades, %d cas graves, %d décès." % [m.nom, int(e.data.total), int(e.data.graves), int(e.data.deces)],
			Vector3.INF, "epidemie", int(e.id))
	var sp := _sante()
	if sp != null:
		sp.noter_fin(e)
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
