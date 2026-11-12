class_name CycleVie
extends RefCounted
## Cycle de vie des habitants, de la naissance à la mort.
##
## - Chaque habitant a un CV (`p.cv`) : une liste d'étapes
##   [jour de vie, code, texte, référence] (voir CODES). Le texte est écrit au
##   moment de l'étape (le nom du bâtiment reste même s'il est démoli).
## - Liens familiaux : parents (`pa` = [mère, père]), conjoint (`cj`), type
##   d'union (`un` : "couple", "pacs", "mariage"). Familles recomposées : un
##   adulte qui emménage chez son conjoint amène ses enfants mineurs.
## - Chaque jour de jeu (`daily`) : décès, naissances, rencontres, mariages et
##   PACS, séparations, diplômes et études, permis, voiture, maladies et
##   guérisons, loisirs, distinctions sportives, changements de travail.
## - La vie dépend de la ville : hôpital proche, pollution des usines,
##   satisfaction, places à l'école (sans école, pas de brevet ni de bac).
## - Héritage : le foyer garde son épargne et son logement (les enfants majeurs
##   restent dans la maison familiale). Une personne seule lègue son épargne à
##   ses enfants. Des mineurs sans adulte vont chez un parent de la famille.
## - Les défunts et les habitants partis restent consultables (`archive`).
## - Le joueur peut suivre un habitant (`followed`) : repère au-dessus de lui,
##   caméra qui l'accompagne, nouvelles de sa vie.

const ARCHIVE_MAX := 4000
const CV_MAX := 160
const SPORTS := ["football", "tennis", "basket", "natation", "musculation", "skate"]
const MALADIES := {
	"hypertension": {"name": "hypertension", "art": "son hypertension", "gueri": 0.0, "f": 1.25, "w": 4},
	"diabete": {"name": "diabète", "art": "son diabète", "gueri": 0.0, "f": 1.35, "w": 3},
	"coeur": {"name": "maladie du cœur", "art": "sa maladie du cœur", "gueri": 0.08, "f": 1.8, "w": 2},
	"cancer": {"name": "cancer", "art": "son cancer", "gueri": 0.3, "f": 2.4, "w": 2},
	"asthme": {"name": "asthme", "art": "son asthme", "gueri": 0.15, "f": 1.15, "w": 0},
}
const DIPLOMES := {"": "aucun diplôme", "brevet": "brevet", "bac": "baccalauréat", "bts": "BTS", "licence": "licence", "master": "master"}
## Étapes de la vie : couleur dans la frise.
const PHASES := {
	"enfance": Color("f4b6c2"), "ecole": Color("6ea8fe"), "etudes": Color("a78bfa"), "travail": Color("5cc98a"),
	"recherche": Color("f4a259"), "retraite": Color("d9b26f"), "ailleurs": Color("8a8f98"),
}
const PHASE_NAMES := {
	"enfance": "Petite enfance", "ecole": "École", "etudes": "Études", "travail": "Travail",
	"recherche": "Sans emploi", "retraite": "Retraite", "ailleurs": "Vie ailleurs",
}
## Codes des étapes du CV : couleur du point.
const CODES := {
	"naissance": Color("ffffff"), "arrivee": Color("ffffff"), "ecole": Color("6ea8fe"), "diplome": Color("a78bfa"),
	"etudes": Color("a78bfa"), "emploi": Color("5cc98a"), "fin_emploi": Color("f4a259"), "retraite": Color("d9b26f"),
	"demenage": Color("c8ccd2"), "couple": Color("ff8fb1"), "pacs": Color("ff8fb1"), "mariage": Color("ff5c8a"),
	"separation": Color("b5485d"), "enfant": Color("ffd166"), "veuvage": Color("6c6f75"), "deuil": Color("6c6f75"),
	"heritage": Color("e9c46a"), "loisir": Color("4cc9f0"), "sport": Color("ffbe0b"), "permis": Color("90e0ef"),
	"voiture": Color("90e0ef"), "maladie": Color("ef476f"), "guerison": Color("06d6a0"), "deces": Color("000000"),
	"depart": Color("8a8f98"),
}
## Étapes comptées dans les nouvelles du jour.
const DIGEST := {"naissance": ["naissance", "naissances"], "deces": ["décès", "décès"], "couple": ["couple", "couples"],
	"mariage": ["mariage", "mariages"], "pacs": ["PACS", "PACS"], "separation": ["séparation", "séparations"],
	"sport": ["médaille", "médailles"], "diplome": ["diplôme", "diplômes"]}

var pop: Population
## Défunts et habitants partis : pid → fiche (mêmes champs qu'un habitant + fin, mort, cause, lieu).
var archive: Dictionary = {}
## Habitant suivi par le joueur (-1 : personne).
var followed := -1
## Totaux depuis le début de la partie.
var totals := {"naissances": 0, "deces": 0, "age_deces": 0.0, "mariages": 0, "pacs": 0, "couples": 0, "separations": 0, "departs": 0}
var _digest := {}
var _pollution := {}
var _hospital := {}


func _init(p: Population) -> void:
	pop = p


func clear() -> void:
	archive.clear()
	followed = -1
	totals = {"naissances": 0, "deces": 0, "age_deces": 0.0, "mariages": 0, "pacs": 0, "couples": 0, "separations": 0, "departs": 0}
	_digest.clear()
	clear_cache()


func clear_cache() -> void:
	_pollution.clear()
	_hospital.clear()


# --- Petits outils -----------------------------------------------------------------

## Accord : texte masculin ou féminin selon l'habitant.
static func g(p: Dictionary, m: String, f: String) -> String:
	return f if String(p.get("s", "H")) == "F" else m


static func full_name(p: Dictionary) -> String:
	return "%s %s" % [p.p, p.n]


## Champs du cycle de vie (anciennes sauvegardes, nouveaux habitants).
static func ensure(p: Dictionary) -> void:
	if not p.has("pa"):
		p.pa = [-1, -1]
	if not p.has("cj"):
		p.cj = -1
	if not p.has("un"):
		p.un = ""
	if not p.has("cv"):
		p.cv = []
	if not p.has("dip"):
		p.dip = ""
	if not p.has("etu"):
		p.etu = -1.0
	if not p.has("etd"):
		p.etd = ""
	if not p.has("niv"):
		p.niv = ""
	if not p.has("perm"):
		p.perm = false
	if not p.has("mal"):
		p.mal = ""
	if not p.has("sp"):
		p.sp = 0
	if not p.has("gain"):
		p.gain = 0.0
	if not p.has("ret"):
		p.ret = false


## Habitant vivant ou fiche d'archive ({} si inconnu).
func person(pid: int) -> Dictionary:
	if pop.persons.has(pid):
		return pop.persons[pid]
	return archive.get(pid, {})


func is_alive(pid: int) -> bool:
	return pop.persons.has(pid)


## Âge (années) : à la mort pour un défunt.
func age_of(p: Dictionary) -> float:
	if p.has("mort"):
		return (float(p.mort) - float(p.nj)) / 365.25
	return pop.age_of(p)


func log_event(p: Dictionary, code: String, text: String, ref := -1, day := NAN) -> void:
	ensure(p)
	var d := snappedf(pop.life_clock if is_nan(day) else day, 0.01)
	var cv: Array = p.cv
	var e := [d, code, text, ref]
	# Les étapes datées d'avant (passé d'un nouvel arrivant) restent dans l'ordre.
	var i := cv.size()
	while i > 0 and float(cv[i - 1][0]) > d:
		i -= 1
	cv.insert(i, e)
	if cv.size() > CV_MAX:
		# On garde la naissance ; on retire les petites étapes les plus anciennes.
		for k in range(1, cv.size()):
			if String(cv[k][1]) in ["loisir", "demenage", "ecole", "emploi", "fin_emploi"]:
				cv.remove_at(k)
				break
		if cv.size() > CV_MAX:
			cv.remove_at(1)
	if DIGEST.has(code) and is_nan(day):
		_digest[code] = int(_digest.get(code, 0)) + 1
	if int(p.id) == followed and is_nan(day):
		var t := text
		if t.length() > 0:
			t = t[0].to_lower() + t.substr(1)
		pop.message.emit("★ %s (%d ans) : %s." % [full_name(p), floori(age_of(p)), t])


## Nouvelles du jour : « Aujourd'hui en ville : 3 naissances · 2 décès… ».
func flush_digest() -> void:
	if _digest.is_empty():
		return
	var parts := []
	for code in DIGEST:
		var n := int(_digest.get(code, 0))
		if n > 0:
			parts.append("%d %s" % [n, DIGEST[code][0] if n == 1 else DIGEST[code][1]])
	_digest.clear()
	if not parts.is_empty():
		pop.message.emit("Aujourd'hui en ville : " + " · ".join(parts) + ".")


# --- Famille ------------------------------------------------------------------------

func parents_of(p: Dictionary) -> Array:
	var out := []
	for id in p.get("pa", []):
		if int(id) >= 0 and not person(int(id)).is_empty():
			out.append(int(id))
	return out


func children_of(pid: int) -> Array:
	var out := []
	for src in [pop.persons, archive]:
		for id in src:
			var pa: Array = src[id].get("pa", [])
			if pa.has(pid):
				out.append(int(id))
	out.sort_custom(func(a: int, b: int) -> bool: return float(person(a).nj) < float(person(b).nj))
	return out


func siblings_of(p: Dictionary) -> Array:
	var out := []
	var mine := parents_of(p)
	if mine.is_empty():
		return out
	for par in mine:
		for c in children_of(par):
			if c != int(p.id) and not out.has(c):
				out.append(c)
	return out


func _shares_parent(p: Dictionary, q: Dictionary) -> bool:
	for a in parents_of(p):
		if parents_of(q).has(a):
			return true
	return false


## Proches (parents, enfants, frères et sœurs, grands-parents) : pas de couple possible.
func _related(p: Dictionary, q: Dictionary) -> bool:
	var a := int(p.id)
	var b := int(q.id)
	if (p.pa as Array).has(b) or (q.pa as Array).has(a) or _shares_parent(p, q):
		return true
	for par in parents_of(p):
		if (person(par).pa as Array).has(b):
			return true
	for par in parents_of(q):
		if (person(par).pa as Array).has(a):
			return true
	return false


## Lien de q pour p (« sa mère », « son demi-frère », « son beau-père »…).
func relation(p: Dictionary, q: Dictionary) -> String:
	var a := int(p.id)
	var b := int(q.id)
	var f: bool = String(q.s) == "F"
	if int(p.get("cj", -1)) == b:
		match String(p.get("un", "")):
			"mariage":
				return "sa femme" if f else "son mari"
			"pacs":
				return "sa partenaire (PACS)" if f else "son partenaire (PACS)"
		return "sa compagne" if f else "son compagnon"
	if (p.get("pa", []) as Array).has(b):
		return "sa mère" if f else "son père"
	if (q.get("pa", []) as Array).has(a):
		return "sa fille" if f else "son fils"
	var mine := parents_of(p)
	var theirs := parents_of(q)
	if not mine.is_empty() and not theirs.is_empty():
		var shared := 0
		for x in mine:
			if theirs.has(x):
				shared += 1
		if shared >= mine.size() and shared >= theirs.size():
			return "sa sœur" if f else "son frère"
		if shared > 0:
			return "sa demi-sœur" if f else "son demi-frère"
	for par in mine:
		if (person(par).get("pa", []) as Array).has(b):
			return "sa grand-mère" if f else "son grand-père"
	for par in theirs:
		if (person(par).get("pa", []) as Array).has(a):
			return "sa petite-fille" if f else "son petit-fils"
	# Famille recomposée : le conjoint d'un parent, l'enfant du conjoint.
	for par in mine:
		if int(person(par).get("cj", -1)) == b:
			return "sa belle-mère" if f else "son beau-père"
	if int(p.get("cj", -1)) >= 0 and theirs.has(int(p.cj)):
		return "sa belle-fille" if f else "son beau-fils"
	if String(p.r) == "adulte" and String(q.r) == "adulte":
		return "colocataire"
	if String(p.r) == "adulte":
		return "sa belle-fille" if f else "son beau-fils"
	if String(q.r) == "adulte":
		return "sa belle-mère" if f else "son beau-père"
	return "sa quasi-sœur" if f else "son quasi-frère"


## Liens d'un foyer créé à l'arrivée (ou d'une ancienne sauvegarde) : couple et parents.
func link_household(hid: int, kind := "") -> void:
	var h: Dictionary = pop.households[hid]
	var adults := []
	var kids := []
	for m in h.m:
		var q: Dictionary = pop.persons[m]
		ensure(q)
		if String(q.r) == "adulte":
			adults.append(m)
		else:
			kids.append(m)
	if adults.size() >= 2:
		var a: Dictionary = pop.persons[adults[0]]
		var b: Dictionary = pop.persons[adults[1]]
		if int(a.cj) < 0 and int(b.cj) < 0:
			a.cj = int(b.id)
			b.cj = int(a.id)
			var r := pop.rng.randf()
			var un := "mariage" if r < 0.55 else ("pacs" if r < 0.75 else "couple")
			if kind == "seniors":
				un = "mariage"
			a.un = un
			b.un = un
	var mom := -1
	var dad := -1
	for m in adults:
		if String(pop.persons[m].s) == "F" and mom < 0:
			mom = m
		elif dad < 0:
			dad = m
	for k in kids:
		var q: Dictionary = pop.persons[k]
		if (q.pa as Array) == [-1, -1]:
			q.pa = [mom, dad]


## Passé d'un nouvel arrivant : naissance ailleurs, diplômes, permis, union.
func on_arrival(hid: int, kind: String) -> void:
	link_household(hid, kind)
	var h: Dictionary = pop.households[hid]
	var where := pop.building_name(int(h.b))
	for m in h.m:
		var p: Dictionary = pop.persons[m]
		var a := pop.age_of(p)
		var nj := float(p.nj)
		log_event(p, "naissance", g(p, "Naît", "Naît") + " loin d'ici", -1, nj)
		if a >= 15.0 and pop.rng.randf() < 0.88:
			p.dip = "brevet"
			log_event(p, "diplome", "Obtient le brevet", -1, nj + 15.0 * 365.25)
		if a >= 18.0 and p.dip == "brevet" and pop.rng.randf() < 0.8:
			p.dip = "bac"
			log_event(p, "diplome", "Obtient le baccalauréat", -1, nj + 18.0 * 365.25)
			var r := pop.rng.randf()
			var sup := ""
			var dur := 0.0
			if r < 0.15:
				sup = "bts"
				dur = 2.0
			elif r < 0.37:
				sup = "licence"
				dur = 3.0
			elif r < 0.55:
				sup = "master"
				dur = 5.0
			if sup != "" and a >= 18.0 + dur:
				p.dip = sup
				log_event(p, "diplome", "Obtient son %s" % DIPLOMES[sup], -1, nj + (18.0 + dur) * 365.25)
		if a >= 18.5 and pop.rng.randf() < (0.95 if int(h.car) > 0 else 0.6):
			p.perm = true
			log_event(p, "permis", "Obtient le permis de conduire", -1, nj + pop.rng.randf_range(18.0, minf(a, 24.0)) * 365.25)
		if a >= 45.0 and pop.rng.randf() < clampf((a - 45.0) / 80.0, 0.0, 0.4):
			_fall_ill(p, true)
		if a >= Population.RETIREMENT_AGE:
			p.ret = true
			log_event(p, "retraite", "Prend sa retraite", -1, nj + Population.RETIREMENT_AGE * 365.25)
	# Union (date inventée avant l'arrivée).
	for m in h.m:
		var p: Dictionary = pop.persons[m]
		if int(p.cj) >= 0 and int(p.cj) > m and pop.persons.has(int(p.cj)):
			var q: Dictionary = pop.persons[int(p.cj)]
			var youngest := minf(pop.age_of(p), pop.age_of(q))
			var back := pop.rng.randf_range(1.0, maxf(1.0, youngest - 19.0))
			var d := pop.life_clock - back * 365.25
			var verb: String = {"mariage": "Se marie avec %s", "pacs": "Se pacse avec %s", "couple": "Se met en couple avec %s"}[String(p.un)]
			log_event(p, String(p.un), verb % full_name(q), int(q.id), d)
			log_event(q, String(p.un), verb % full_name(p), int(p.id), d)
	for m in h.m:
		var p: Dictionary = pop.persons[m]
		log_event(p, "arrivee", "Arrive en ville et emménage à %s" % where, int(h.b))
		if not (p.hob as Array).is_empty():
			var names := []
			for hb in p.hob:
				names.append(String(Metiers.LOISIRS[hb].name).to_lower())
			log_event(p, "loisir", "Loisirs : " + ", ".join(names))


# --- Santé ------------------------------------------------------------------------

## Pollution (0-1) autour d'un logement : usines et industries à moins de 800 m.
func pollution_at(bid: int) -> float:
	if _pollution.has(bid):
		return _pollution[bid]
	var v := 0.0
	if pop.known.has(bid):
		var o: Vector3 = pop.known[bid].pos
		for other in pop.known:
			var info: Dictionary = pop.known[other]
			if String(info.cat) != "industrie":
				continue
			var d := o.distance_to(info.pos)
			if d < 800.0:
				v += (1.0 - d / 800.0) * clampf(float(info.emp) / 60.0, 0.4, 2.0) * 0.5
	v = clampf(v, 0.0, 1.0)
	_pollution[bid] = v
	return v


## Distance (m) au plus proche hôpital ou centre de santé de la ville (INF : aucun).
func hospital_distance(bid: int) -> float:
	if _hospital.has(bid):
		return _hospital[bid]
	var best := INF
	if pop.known.has(bid):
		var o: Vector3 = pop.known[bid].pos
		for other in pop.known:
			var keys := Metiers.keys_of(String(pop.known[other].t))
			if keys.has("hopital") or keys.has("clinique") or keys.has("sante") or keys.has("medecin"):
				best = minf(best, o.distance_to(pop.known[other].pos))
	_hospital[bid] = best
	return best


## Risque de décès par an selon l'âge seul (France : espérance de vie ≈ 83 ans).
static func base_mortality(a: float) -> float:
	var q := 0.00002 * exp(0.1 * a)
	if a < 1.0:
		q += 0.0035
	elif a < 40.0:
		q += 0.0003
	return q


## Ce qui joue sur la santé : {f (multiplicateur du risque), why}.
func health(p: Dictionary) -> Dictionary:
	var f := 1.0
	var why := []
	var home := pop.home_of(p)
	var hd := hospital_distance(home)
	if hd < 6000.0:
		f *= 0.82
		why.append("+ hôpital à %.1f km" % (hd / 1000.0))
	else:
		f *= 1.15
		why.append("− pas d'hôpital proche")
	var pol := pollution_at(home)
	if pol > 0.05:
		f *= 1.0 + 0.4 * pol
		why.append("− air pollué par les usines (%d %%)" % roundi(pol * 100.0))
	var sat := int(pop.satisfaction(p).value)
	f *= 1.3 - 0.006 * sat
	why.append("%s satisfaction %d / 100" % ["+" if sat >= 50 else "−", sat])
	var mal := String(p.get("mal", ""))
	if mal != "" and MALADIES.has(mal):
		f *= float(MALADIES[mal].f)
		why.append("− %s" % MALADIES[mal].name)
	return {"f": f, "why": why}


## Espérance de vie estimée (années) avec la santé actuelle.
func life_expectancy(p: Dictionary) -> float:
	var f := float(health(p).f)
	var a := pop.age_of(p)
	var alive := 1.0
	var years := a
	var t := a
	while t < 120.0 and alive > 0.001:
		var q := clampf(base_mortality(t) * f, 0.0, 1.0)
		alive *= 1.0 - q
		years += alive
		t += 1.0
	return years


func _fall_ill(p: Dictionary, past := false) -> void:
	var pol := pollution_at(pop.home_of(p))
	var total := 0.0
	var w := {}
	for k in MALADIES:
		var x := float(MALADIES[k].w)
		if k == "asthme":
			x = 6.0 * pol
		w[k] = x
		total += x
	var r := pop.rng.randf() * total
	var pick := "hypertension"
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			pick = k
			break
	p.mal = pick
	var d := NAN
	if past:
		d = pop.life_clock - pop.rng.randf_range(0.5, 6.0) * 365.25
	log_event(p, "maladie", "Tombe malade : %s" % MALADIES[pick].name, -1, d)


# --- Le temps passe ----------------------------------------------------------------

## Un jour de jeu : `years` années de vie passent pour tout le monde.
func daily(years: float) -> void:
	if years <= 0.0:
		return
	var deaths := []
	var births := []
	var leaving := []
	var singles := []
	var unions := []
	var breakups := []
	for pid in pop.persons.keys():
		var p: Dictionary = pop.persons[pid]
		ensure(p)
		var a := pop.age_of(p)
		var a0 := a - years
		# Décès : tirage d'abord avec le risque maximal, la santé n'est calculée que si besoin.
		var qb := base_mortality(a)
		var r := pop.rng.randf()
		if r < 1.0 - pow(1.0 - minf(qb * 4.0, 0.95), years):
			var q := minf(qb * float(health(p).f), 0.95)
			if r < 1.0 - pow(1.0 - q, years):
				deaths.append(pid)
				continue
		p.gain = float(p.gain) + pop.income_of(p) * 12.0 * years
		_school_milestones(p, a0, a)
		# Fin des études supérieures.
		if float(p.etu) > 0.0 and pop.life_clock >= float(p.etu):
			p.etu = -1.0
			if String(p.etd) != "":
				p.dip = p.etd
				log_event(p, "diplome", "Obtient son %s et cherche un emploi" % DIPLOMES[String(p.etd)])
			p.etd = ""
		if a >= 18.0:
			_adult_year(p, a, years)
		if (p.hob as Array).size() > 0 or a >= 3.0:
			_hobbies(p, a, years)
		# Rencontres, unions, séparations, naissances.
		if a >= 20.0 and a < 78.0 and int(p.cj) < 0:
			singles.append(pid)
		if int(p.cj) > pid and pop.persons.has(int(p.cj)):
			var q: Dictionary = pop.persons[int(p.cj)]
			var together: bool = int(q.f) == int(p.f)
			var chosen := _player_choice(p) or _player_choice(q)
			if chosen:
				pass
			elif together and String(p.un) == "couple" and pop.rng.randf() < 0.12 * years:
				unions.append(pid)
			elif pop.rng.randf() < (0.012 if String(p.un) == "mariage" else 0.03) * years:
				breakups.append(pid)
		if String(p.s) == "F" and a >= 20.0 and a < 43.0 and int(p.cj) >= 0 and pop.persons.has(int(p.cj)) \
				and int(pop.persons[int(p.cj)].f) == int(p.f) and not _player_choice(p) \
				and not _player_choice(pop.persons[int(p.cj)]) and pop.rng.randf() < 0.11 * years:
			births.append(pid)
		if String(p.r) == "enfant" and a >= 19.0 and a < 32.0 and float(p.etu) < 0.0 and pop.rng.randf() < 0.3 * years:
			leaving.append(pid)
	for pid in deaths:
		if pop.persons.has(pid):
			die(pid)
	for pid in births:
		if pop.persons.has(pid):
			_birth(pid)
	for pid in unions:
		if pop.persons.has(pid) and pop.persons.has(int(pop.persons[pid].cj)):
			_union(pop.persons[pid], pop.persons[int(pop.persons[pid].cj)])
	for pid in breakups:
		if pop.persons.has(pid) and pop.persons.has(int(pop.persons[pid].cj)):
			_separate(pop.persons[pid], pop.persons[int(pop.persons[pid].cj)])
	_meetings(singles, years)
	for pid in leaving:
		if pop.persons.has(pid) and String(pop.persons[pid].r) == "enfant":
			pop._move_out(pid)
	tidy()
	if pop.principal.enabled:
		pop.principal.yearly(years)


## Foyers vidés par les déménagements : retirés ; foyers sans adulte : le plus âgé devient adulte.
func tidy() -> void:
	for hid in pop.households.keys():
		var h: Dictionary = pop.households[hid]
		if (h.m as Array).is_empty():
			pop._remove_household(hid, "")
		elif _adults_in(hid) == 0:
			var oldest := -1
			for m in h.m:
				if pop.age_of(pop.persons[m]) >= 18.0 and (oldest < 0 or float(pop.persons[m].nj) < float(pop.persons[oldest].nj)):
					oldest = m
			if oldest >= 0:
				pop.persons[oldest].r = "adulte"
			else:
				for m in (h.m as Array).duplicate():
					if pop.persons.has(m):
						_rehome_minor(pop.persons[m], {})
				if pop.households.has(hid) and (pop.households[hid].m as Array).is_empty():
					pop._remove_household(hid, "")


## Personnage principal d'un joueur : ses grands choix (couple, mariage, enfant,
## séparation, changement de travail, études) viennent du joueur, pas du hasard.
static func _player_choice(p: Dictionary) -> bool:
	return String(p.get("joueur", "")) != ""


## École : brevet à 15 ans, bac à 18 ans, puis études supérieures (hors de la ville).
func _school_milestones(p: Dictionary, a0: float, a: float) -> void:
	if a0 < 15.0 and a >= 15.0 and String(p.niv) in ["collège", "lycée"]:
		if pop.rng.randf() < 0.87:
			p.dip = "brevet"
			log_event(p, "diplome", "Obtient le brevet")
	if a0 < 18.0 and a >= 18.0:
		if String(p.niv) == "lycée" and String(p.dip) == "brevet" and pop.rng.randf() < 0.85:
			p.dip = "bac"
			log_event(p, "diplome", "Obtient le baccalauréat")
			if _player_choice(p):
				pop.principal.ask_studies(p)
			elif pop.rng.randf() < 0.6:
				var r := pop.rng.randf()
				var sup := "licence"
				var dur := 3.0
				if r < 0.28:
					sup = "bts"
					dur = 2.0
				elif r > 0.7:
					sup = "master"
					dur = 5.0
				p.etd = sup
				p.etu = pop.life_clock + dur * 365.25
				log_event(p, "etudes", "Commence des études (%s, %d ans) à l'université, hors de la ville" % [DIPLOMES[sup], int(dur)])
		elif String(p.niv) == "":
			log_event(p, "fin_emploi", "Atteint 18 ans sans être allé%s à l'école (pas de place en ville)" % g(p, "", "e"))
		else:
			log_event(p, "fin_emploi", "Quitte l'école sans le bac")


## Une année d'adulte : permis, voiture, maladie, travail.
func _adult_year(p: Dictionary, a: float, years: float) -> void:
	var h: Dictionary = pop.households.get(int(p.f), {})
	if h.is_empty():
		return
	if not bool(p.perm) and a < 70.0 and pop.rng.randf() < (0.7 if int(h.car) > 0 else 0.35) * years:
		p.perm = true
		log_event(p, "permis", "Obtient le permis de conduire")
	if bool(p.perm) and int(h.car) == 0 and String(p.r) == "adulte" and float(h.ep) > 12000.0 and pop.rng.randf() < 0.25 * years:
		h.car = 1
		h.ep = float(h.ep) - 9000.0
		log_event(p, "voiture", "Achète une voiture d'occasion (9 000 €)")
	if String(p.mal) == "":
		var q := 0.0015 * exp(0.045 * maxf(a - 30.0, 0.0)) + 0.01 * pollution_at(pop.home_of(p))
		if pop.rng.randf() < q * years:
			_fall_ill(p)
	elif MALADIES.has(String(p.mal)):
		var cure := float(MALADIES[String(p.mal)].gueri)
		if cure > 0.0:
			if hospital_distance(pop.home_of(p)) < 6000.0:
				cure *= 2.0
			if pop.rng.randf() < cure * years:
				log_event(p, "guerison", "Guérit (%s)" % MALADIES[String(p.mal)].name)
				p.mal = ""
	if pop.stage(p) == "actif":
		var r := pop.rng.randf()
		if r < 0.015 * years:
			pop._leave_job(p, "Perd son emploi (%s)" % pop.building_name(int(p.job)))
		elif r < 0.065 * years and not _player_choice(p):
			var jobs := []
			for bid in pop.known:
				if bid != int(p.job) and pop.free_jobs(bid) > 0:
					jobs.append(bid)
			if not jobs.is_empty():
				pop._join_job(p, jobs[pop.rng.randi() % jobs.size()])


## Loisirs qui changent avec l'âge, distinctions sportives.
func _hobbies(p: Dictionary, a: float, years: float) -> void:
	var hob: Array = p.hob
	for hb in hob.duplicate():
		var lim: Array = Metiers.LOISIRS[hb].age
		if a > float(lim[1]) + 2.0:
			hob.erase(hb)
			log_event(p, "loisir", "Arrête : %s" % String(Metiers.LOISIRS[hb].name).to_lower())
	if hob.size() < 4 and pop.rng.randf() < 0.1 * years:
		var ok := []
		for k in Metiers.LOISIRS:
			var lim: Array = Metiers.LOISIRS[k].age
			if not hob.has(k) and a >= float(lim[0]) and a <= float(lim[1]):
				ok.append(k)
		if not ok.is_empty():
			var k: String = ok[pop.rng.randi() % ok.size()]
			hob.append(k)
			log_event(p, "loisir", "Se met à un nouveau loisir : %s" % String(Metiers.LOISIRS[k].name).to_lower())
	for hb in hob:
		if not SPORTS.has(hb) or pop.rng.randf() >= 0.07 * years:
			continue
		var club := pop.venue_for(p, hb)
		if club < 0:
			continue
		var sport := String(Metiers.LOISIRS[hb].name).to_lower()
		var r := pop.rng.randf()
		var t := "Remporte le tournoi de %s du club (%s)" % [sport, pop.building_name(club)]
		if r < 0.06:
			t = "Sélectionné%s en équipe nationale de %s" % [g(p, "", "e"), sport]
		elif r < 0.25:
			t = "%s de %s" % [g(p, "Champion départemental", "Championne départementale"), sport]
		elif r < 0.55:
			t = "Médaille au championnat régional de %s" % sport
		p.sp = int(p.sp) + 1
		log_event(p, "sport", t, club)


## Rencontres : au travail, à un loisir, dans le quartier, par des amis.
func _meetings(singles: Array, years: float) -> void:
	if singles.size() < 2:
		return
	var taken := {}
	for pid in singles:
		if taken.has(pid) or not pop.persons.has(pid) or pop.rng.randf() >= 0.3 * years:
			continue
		# Le personnage principal d'un joueur choisit lui-même (Ordres « Chercher l'âme sœur »).
		if String(pop.persons[pid].get("joueur", "")) != "":
			continue
		var pick := _best_partner(pop.persons[pid], singles, taken)
		if not pick.is_empty():
			taken[pid] = true
			taken[int(pick.id)] = true
			_couple(pop.persons[pid], pop.persons[int(pick.id)], String(pick.where))


## Ordre « Chercher l'âme sœur » : une rencontre tout de suite, si possible.
func find_partner(p: Dictionary, singles: Array) -> bool:
	var pick := _best_partner(p, singles, {}, true)
	if pick.is_empty():
		return false
	_couple(p, pop.persons[int(pick.id)], String(pick.where))
	return true


## Meilleur partenaire parmi un échantillon de célibataires : {id, where} ou {}.
func _best_partner(p: Dictionary, singles: Array, taken: Dictionary, all := false) -> Dictionary:
	var pid := int(p.id)
	var a := pop.age_of(p)
	var same_sex := pop.rng.randf() < 0.07
	var best := -1
	var best_score := -1.0
	var best_where := ""
	var tries := singles.size() if all else mini(40, singles.size())
	for i in tries:
		var oid: int = singles[i] if all else singles[pop.rng.randi() % singles.size()]
		if oid == pid or taken.has(oid) or not pop.persons.has(oid):
			continue
		var q: Dictionary = pop.persons[oid]
		if String(q.get("joueur", "")) != "" or int(q.cj) >= 0:
			continue
		if (String(q.s) == String(p.s)) != same_sex or absf(pop.age_of(q) - a) > 10.0 or int(q.f) == int(p.f) or _related(p, q):
			continue
		var score := pop.rng.randf()
		var where := "par des amis"
		if int(p.job) >= 0 and int(p.job) == int(q.job):
			score += 2.0
			where = "au travail (%s)" % pop.building_name(int(p.job))
		else:
			for hb in p.hob:
				if (q.hob as Array).has(hb):
					score += 1.5
					where = "en pratiquant le même loisir (%s)" % String(Metiers.LOISIRS[hb].name).to_lower()
					break
			var hp := pop.home_of(p)
			var hq := pop.home_of(q)
			if where == "par des amis" and pop.known.has(hp) and pop.known.has(hq) \
					and (pop.known[hp].pos as Vector3).distance_to(pop.known[hq].pos) < 400.0:
				score += 1.0
				where = "dans le quartier"
		if score > best_score:
			best_score = score
			best = oid
			best_where = where
	if best < 0:
		return {}
	return {"id": best, "where": best_where}


func _couple(p: Dictionary, q: Dictionary, where: String) -> void:
	p.cj = int(q.id)
	q.cj = int(p.id)
	p.un = "couple"
	q.un = "couple"
	totals.couples = int(totals.couples) + 1
	log_event(p, "couple", "Rencontre %s %s et se met en couple" % [full_name(q), where], int(q.id))
	log_event(q, "couple", "Rencontre %s %s et se met en couple" % [full_name(p), where], int(p.id))
	_move_in_together(p, q)


## Emménager ensemble : l'un rejoint le foyer de l'autre (avec ses enfants mineurs),
## ou deux jeunes qui vivent chez leurs parents prennent un logement libre.
func _move_in_together(p: Dictionary, q: Dictionary) -> void:
	var dep_p: bool = String(p.r) == "enfant"
	var dep_q: bool = String(q.r) == "enfant"
	if dep_p and dep_q:
		var bid := _free_home()
		if bid < 0:
			return
		var hid := _new_household(bid, String(pop.households[int(p.f)].reg), 4000.0)
		move_person(p, hid, "Emménage avec %s à %s" % [full_name(q), pop.building_name(bid)])
		move_person(q, hid, "Emménage avec %s à %s" % [full_name(p), pop.building_name(bid)])
		p.r = "adulte"
		q.r = "adulte"
		return
	var mover := p
	var host := q
	if dep_q and not dep_p:
		mover = q
		host = p
	elif not dep_p and not dep_q:
		var np := (pop.households[int(p.f)].m as Array).size()
		var nq := (pop.households[int(q.f)].m as Array).size()
		if np > nq or (np == nq and pop.rng.randf() < 0.5):
			mover = q
			host = p
	var old_hid := int(mover.f)
	var new_hid := int(host.f)
	var old: Dictionary = pop.households[old_hid]
	var dest := pop.building_name(int(pop.households[new_hid].b))
	var family := [mover]
	if String(mover.r) == "adulte":
		for m in old.m:
			var k: Dictionary = pop.persons[m]
			if m != int(mover.id) and String(k.r) == "enfant" and pop.age_of(k) < 18.0 and (k.pa as Array).has(int(mover.id)):
				family.append(k)
	for k in family:
		move_person(k, new_hid, "Emménage avec %s à %s" % [full_name(host), dest] if k == mover else "Suit %s chez %s, à %s" % [
			g(mover, "son père", "sa mère"), full_name(host), dest])
	mover.r = "adulte"
	if not pop.households.has(old_hid):
		return
	var left: Array = old.m
	var moved := float(old.ep) if left.is_empty() else float(old.ep) * 0.5
	old.ep = float(old.ep) - moved
	pop.households[new_hid].ep = float(pop.households[new_hid].ep) + moved
	if left.is_empty():
		pop._remove_household(old_hid, "")
	elif _adults_in(old_hid) == 0:
		_promote_grown_children(old_hid, mover)


func _adults_in(hid: int) -> int:
	var n := 0
	for m in pop.households[hid].m:
		if String(pop.persons[m].r) == "adulte":
			n += 1
	return n


## Les enfants majeurs restés seuls deviennent les adultes du foyer (ils gardent le logement).
func _promote_grown_children(hid: int, from: Dictionary) -> void:
	var h: Dictionary = pop.households[hid]
	var minors := []
	for m in h.m:
		var k: Dictionary = pop.persons[m]
		if pop.age_of(k) >= 18.0:
			k.r = "adulte"
		else:
			minors.append(m)
	if _adults_in(hid) == 0:
		for m in minors:
			if pop.persons.has(m):
				_rehome_minor(pop.persons[m], from)


func move_person(p: Dictionary, to_hid: int, text := "") -> void:
	var old := int(p.f)
	if pop.households.has(old):
		(pop.households[old].m as Array).erase(int(p.id))
	p.f = to_hid
	(pop.households[to_hid].m as Array).append(int(p.id))
	pop._venue_cache.erase(int(p.id))
	if text != "":
		log_event(p, "demenage", text, int(pop.households[to_hid].b))


func _free_home() -> int:
	var homes := []
	for bid in pop.known:
		if pop.free_homes(bid) > 0:
			homes.append(bid)
	if homes.is_empty():
		return -1
	return homes[pop.rng.randi() % homes.size()]


func _new_household(bid: int, region: String, savings: float) -> int:
	var hid := pop.next_hid
	pop.next_hid += 1
	pop.households[hid] = {"id": hid, "b": bid, "reg": region, "ep": savings, "car": 0, "m": []}
	if not pop.by_home.has(bid):
		pop.by_home[bid] = []
	(pop.by_home[bid] as Array).append(hid)
	return hid


func _union(p: Dictionary, q: Dictionary, kind := "") -> void:
	if kind == "":
		kind = "mariage" if pop.rng.randf() < 0.6 else "pacs"
	p.un = kind
	q.un = kind
	if kind == "mariage":
		totals.mariages = int(totals.mariages) + 1
		log_event(p, "mariage", "Se marie avec %s" % full_name(q), int(q.id))
		log_event(q, "mariage", "Se marie avec %s" % full_name(p), int(p.id))
	else:
		totals.pacs = int(totals.pacs) + 1
		log_event(p, "pacs", "Se pacse avec %s" % full_name(q), int(q.id))
		log_event(q, "pacs", "Se pacse avec %s" % full_name(p), int(p.id))


func _separate(p: Dictionary, q: Dictionary) -> void:
	var word := "Divorce de %s" if String(p.un) == "mariage" else "Se sépare de %s"
	totals.separations = int(totals.separations) + 1
	log_event(p, "separation", word % full_name(q), int(q.id))
	log_event(q, "separation", word % full_name(p), int(p.id))
	p.cj = -1
	q.cj = -1
	p.un = ""
	q.un = ""
	if int(p.f) != int(q.f):
		return
	# Celui qui part : au hasard ; les enfants restent dans le logement.
	var mover := p if pop.rng.randf() < 0.5 else q
	var hid := int(mover.f)
	var bid := _free_home()
	if bid < 0:
		pop._remove_person(int(mover.id), false, "Quitte la ville après sa séparation")
		return
	var h: Dictionary = pop.households[hid]
	var share := maxf(float(h.ep), 0.0) * 0.4
	h.ep = float(h.ep) - share
	var nh := _new_household(bid, String(h.reg), share)
	move_person(mover, nh, "S'installe seul%s à %s" % [g(mover, "", "e"), pop.building_name(bid)])
	if int(h.car) > 1:
		h.car = int(h.car) - 1
		pop.households[nh].car = 1


## Naissance chez une mère ; renvoie l'id du bébé ou -1.
## asked : demandé par le joueur (on accepte jusqu'à 3 petits de moins de 6 ans).
func _birth(mom_id: int, asked := false) -> int:
	var mom: Dictionary = pop.persons[mom_id]
	var h: Dictionary = pop.households[int(mom.f)]
	var small := 0
	for m in h.m:
		if pop.age_of(pop.persons[m]) < 6.0:
			small += 1
	if small >= (3 if asked else 2) or (h.m as Array).size() >= (9 if asked else 7):
		return -1
	var dad: Dictionary = pop.persons.get(int(mom.cj), {})
	var surname := String(dad.n) if not dad.is_empty() and pop.rng.randf() < 0.8 else String(mom.n)
	var sex := "F" if pop.rng.randf() < 0.49 else "H"
	var baby_id := pop._add_person(int(h.id), sex, 0.0, "enfant", surname)
	var baby: Dictionary = pop.persons[baby_id]
	baby.pa = [mom_id, int(dad.get("id", -1))]
	totals.naissances = int(totals.naissances) + 1
	var where := pop.building_name(int(h.b))
	if dad.is_empty():
		log_event(baby, "naissance", "Naît à %s, %s de %s" % [where, g(baby, "fils", "fille"), full_name(mom)], int(h.b))
	else:
		log_event(baby, "naissance", "Naît à %s, %s de %s et %s" % [where, g(baby, "fils", "fille"), full_name(mom), full_name(dad)], int(h.b))
	for par in [mom, dad]:
		if not par.is_empty():
			log_event(par, "enfant", "Naissance de %s %s" % [g(baby, "son fils", "sa fille"), baby.p], baby_id)
	return baby_id


## Décès : CV, deuil des proches, héritage, logement transmis.
func die(pid: int, cause := "") -> void:
	var p: Dictionary = pop.persons[pid]
	var a := pop.age_of(p)
	if cause == "":
		cause = _cause(p, a)
	var hid := int(p.f)
	var h: Dictionary = pop.households.get(hid, {})
	var home := int(h.get("b", -1))
	totals.deces = int(totals.deces) + 1
	totals.age_deces = float(totals.age_deces) + a
	log_event(p, "deces", "Meurt %s à %d ans" % [cause, floori(a)], home)
	if int(p.cj) >= 0 and pop.persons.has(int(p.cj)):
		var c: Dictionary = pop.persons[int(p.cj)]
		log_event(c, "veuvage", "Perd %s %s" % [relation(c, p), full_name(p)], pid)
		c.cj = -1
		c.un = ""
	var kids_alive := []
	for k in children_of(pid):
		if pop.persons.has(k):
			kids_alive.append(k)
			log_event(pop.persons[k], "deuil", "Décès de %s %s" % [relation(pop.persons[k], p), full_name(p)], pid)
	var was_followed := followed == pid
	var was_mine := pop.principal.is_mine(p)
	archive_person(p, "deces", cause)
	pop._remove_person(pid, false)
	if not h.is_empty() and pop.households.has(hid):
		_inherit(hid, p, kids_alive)
	if was_mine:
		pop.principal.on_death(p)
		followed = -1
		pop.follow_changed.emit()
	elif was_followed:
		_follow_heir(p, kids_alive)


func _cause(p: Dictionary, a: float) -> String:
	var mal := String(p.get("mal", ""))
	if mal != "" and MALADIES.has(mal) and pop.rng.randf() < 0.7:
		return "des suites de %s" % MALADIES[mal].art
	if a < 1.0:
		return "en bas âge"
	if a < 45.0:
		return "dans un accident" if pop.rng.randf() < 0.6 else "d'une maladie"
	if a >= 80.0 and pop.rng.randf() < 0.6:
		return "de vieillesse"
	return ["d'une crise cardiaque", "d'une maladie", "d'un accident vasculaire", "d'une longue maladie"][pop.rng.randi() % 4]


func _inherit(hid: int, dead: Dictionary, kids_alive: Array) -> void:
	var h: Dictionary = pop.households[hid]
	var ep := float(h.ep)
	var where := pop.building_name(int(h.b))
	if (h.m as Array).is_empty():
		# Personne seule : l'épargne va aux enfants qui vivent en ville.
		if ep > 0.0 and not kids_alive.is_empty():
			var part := ep / kids_alive.size()
			for k in kids_alive:
				var kid: Dictionary = pop.persons[k]
				if pop.households.has(int(kid.f)):
					pop.households[int(kid.f)].ep = float(pop.households[int(kid.f)].ep) + part
				log_event(kid, "heritage", "Hérite de %s de %s" % [HabitantsPanel.money(part), relation(kid, dead)], int(dead.id))
		pop._remove_household(hid, "")
		return
	if _adults_in(hid) > 0:
		for m in h.m:
			var c: Dictionary = pop.persons[m]
			if String(c.r) == "adulte" and int(dead.cj) == m and ep > 1000.0:
				log_event(c, "heritage", "Garde le logement et l'épargne du foyer (%s)" % HabitantsPanel.money(ep), int(dead.id))
		return
	# Plus d'adulte : les enfants majeurs gardent la maison familiale.
	var grown := false
	for m in h.m:
		var k: Dictionary = pop.persons[m]
		if pop.age_of(k) >= 18.0:
			k.r = "adulte"
			grown = true
			log_event(k, "heritage", "Hérite du logement familial (%s)%s" % [where,
				" et de l'épargne (%s)" % HabitantsPanel.money(ep) if ep > 1000.0 else ""], int(h.b))
	if grown:
		_promote_grown_children(hid, dead)
		return
	for m in (h.m as Array).duplicate():
		if pop.persons.has(m):
			_rehome_minor(pop.persons[m], dead)
	if pop.households.has(hid) and (pop.households[hid].m as Array).is_empty():
		pop._remove_household(hid, "")


## Un mineur sans adulte : chez son autre parent, ses grands-parents, un frère ou
## une sœur majeur, sinon dans une famille d'accueil hors de la ville.
func _rehome_minor(k: Dictionary, dead: Dictionary) -> void:
	var options := []
	for par in parents_of(k):
		if pop.persons.has(par):
			options.append(par)
	for par in parents_of(k):
		for gp in parents_of(person(par)):
			if pop.persons.has(gp):
				options.append(gp)
	for s in siblings_of(k):
		if pop.persons.has(s) and pop.age_of(pop.persons[s]) >= 18.0:
			options.append(s)
	var old_hid := int(k.f)
	for o in options:
		var who: Dictionary = pop.persons[o]
		if int(who.f) != old_hid and String(who.r) == "adulte":
			var h: Dictionary = pop.households[old_hid]
			move_person(k, int(who.f), "Part vivre chez %s %s, à %s" % [relation(k, who), full_name(who),
				pop.building_name(int(pop.households[int(who.f)].b))])
			if (h.m as Array).is_empty() and float(h.ep) > 0.0:
				pop.households[int(who.f)].ep = float(pop.households[int(who.f)].ep) + float(h.ep)
				h.ep = 0.0
			return
	pop._remove_person(int(k.id), false, "Part dans une famille d'accueil, hors de la ville")


## Le suivi passe au conjoint ou à l'aîné des enfants (façon Sims).
func _follow_heir(dead: Dictionary, kids_alive: Array) -> void:
	followed = -1
	var heir := -1
	var c := int(dead.get("cj", -1))
	for k in kids_alive:
		if pop.persons.has(k):
			heir = k
			break
	for m in pop.persons:
		if int(pop.persons[m].get("cj", -1)) == -1 and m == c:
			heir = m
	if heir < 0:
		pop.message.emit("★ %s nous a quittés. Plus personne n'est suivi." % full_name(dead))
		pop.follow_changed.emit()
		return
	followed = heir
	pop.message.emit("★ %s nous a quittés. Tu suis maintenant %s (%s)." % [full_name(dead), full_name(pop.persons[heir]),
		relation(dead, pop.persons[heir])])
	pop.follow_changed.emit()


## Garde la fiche d'un défunt ou d'un habitant qui part.
func archive_person(p: Dictionary, kind: String, text: String) -> void:
	ensure(p)
	var f := {}
	for k in ["id", "p", "n", "s", "nj", "pa", "cj", "un", "cv", "dip", "perm", "mal", "sp", "gain", "hob", "r"]:
		f[k] = p.get(k)
	f.fin = kind
	f.mort = pop.life_clock
	f.cause = text
	f.lieu = pop.building_name(pop.home_of(p))
	f.met = Metiers.job(String(p.met)).name if String(p.get("met", "")) != "" else ""
	if kind != "deces":
		totals.departs = int(totals.departs) + 1
		log_event(f, "depart", text, -1)
	archive[int(p.id)] = f
	if followed == int(p.id) and kind != "deces":
		followed = -1
		pop.message.emit("★ %s quitte la ville." % full_name(p))
		pop.follow_changed.emit()
	while archive.size() > ARCHIVE_MAX:
		archive.erase(archive.keys()[0])


# --- Frise -------------------------------------------------------------------------

## Étapes de la vie pour la frise : [[âge début, âge fin, phase], …].
func phases_of(p: Dictionary) -> Array:
	var out := []
	var cur := "enfance"
	var start := 0.0
	var nj := float(p.nj)
	var end_age := age_of(p)
	for e in p.get("cv", []):
		var at := clampf((float(e[0]) - nj) / 365.25, 0.0, end_age)
		var next := ""
		match String(e[1]):
			"naissance":
				if String(e[2]).ends_with("loin d'ici"):
					next = "ailleurs"
			"arrivee":
				next = _phase_now(p, at)
			"ecole":
				next = "ecole"
			"etudes":
				next = "etudes"
			"emploi":
				next = "travail"
			"fin_emploi":
				next = "recherche" if at >= 16.0 else ""
			"diplome":
				if cur == "etudes":
					next = "recherche"
			"retraite":
				next = "retraite"
		if next != "" and next != cur:
			if at > start:
				out.append([start, at, cur])
			cur = next
			start = at
	if end_age > start:
		out.append([start, end_age, cur])
	return out


## Phase d'un habitant à un âge donné (arrivée en ville).
func _phase_now(p: Dictionary, a: float) -> String:
	if a < 3.0:
		return "enfance"
	if a < 18.0:
		return "ecole"
	if a >= Population.RETIREMENT_AGE:
		return "retraite"
	return "travail" if int(p.get("job", -1)) >= 0 else "recherche"


# --- Suivi -------------------------------------------------------------------------

func follow(pid: int) -> void:
	followed = pid if pop.persons.has(pid) else -1
	if followed >= 0:
		pop.message.emit("★ Tu suis %s. Ses grands moments s'afficheront ici." % full_name(pop.persons[pid]))
	pop.follow_changed.emit()


## Position de l'habitant suivi en ce moment (sur un trajet : entre les deux lieux).
func position_of(pid: int) -> Vector3:
	if not pop.persons.has(pid):
		return Vector3.ZERO
	var p: Dictionary = pop.persons[pid]
	var home := pop.home_of(p)
	var n := pop.now()
	var plan := pop.day_plan(p, n)
	var h: float = n.h
	for i in plan.size():
		var seg: Array = plan[i]
		if h >= float(seg[0]) and h < float(seg[1]):
			var to := int(seg[3])
			if String(seg[2]) == "trajet" and i > 0:
				var from := int(plan[i - 1][3])
				if pop.known.has(from) and pop.known.has(to):
					var t := clampf((h - float(seg[0])) / maxf(float(seg[1]) - float(seg[0]), 0.001), 0.0, 1.0)
					return (pop.known[from].pos as Vector3).lerp(pop.known[to].pos, t)
			if pop.known.has(to):
				return pop.known[to].pos
			break
	return pop.known[home].pos if pop.known.has(home) else Vector3.ZERO


# --- Sauvegarde --------------------------------------------------------------------

## Champs du cycle de vie d'un habitant pour la sauvegarde.
static func pack(p: Dictionary) -> Dictionary:
	var d := {"pa": p.get("pa", [-1, -1]), "cj": p.get("cj", -1), "cv": p.get("cv", [])}
	for k in ["un", "dip", "etd", "niv", "mal"]:
		if String(p.get(k, "")) != "":
			d[k] = p[k]
	if float(p.get("etu", -1.0)) > 0.0:
		d.etu = snappedf(float(p.etu), 0.01)
	if bool(p.get("perm", false)):
		d.perm = true
	if bool(p.get("ret", false)):
		d.ret = true
	if bool(p.get("retr", false)):
		d.retr = true
	if String(p.get("joueur", "")) != "":
		d.joueur = p.joueur
	if p.has("ord"):
		d.ord = p.ord
	if int(p.get("sp", 0)) > 0:
		d.sp = int(p.sp)
	if float(p.get("gain", 0.0)) > 0.0:
		d.gain = roundf(float(p.gain))
	return d


static func unpack(p: Dictionary, d: Dictionary) -> void:
	var pa: Array = d.get("pa", [-1, -1])
	p.pa = [int(pa[0]) if pa.size() > 0 else -1, int(pa[1]) if pa.size() > 1 else -1]
	p.cj = int(d.get("cj", -1))
	p.un = String(d.get("un", ""))
	p.dip = String(d.get("dip", ""))
	p.etd = String(d.get("etd", ""))
	p.niv = String(d.get("niv", ""))
	p.mal = String(d.get("mal", ""))
	p.etu = float(d.get("etu", -1.0))
	p.perm = bool(d.get("perm", false))
	p.ret = bool(d.get("ret", false))
	p.retr = bool(d.get("retr", false))
	if String(d.get("joueur", "")) != "":
		p.joueur = String(d.joueur)
	if d.get("ord") is Dictionary:
		var o: Dictionary = d.ord
		p.ord = {"k": String(o.get("k", "")), "b": int(o.get("b", -1)), "d": int(o.get("d", -1)), "t": float(o.get("t", 0.0)),
			"dur": float(o.get("dur", 2.0)), "txt": String(o.get("txt", "")), "kind": String(o.get("kind", "loisir"))}
	p.sp = int(d.get("sp", 0))
	p.gain = float(d.get("gain", 0.0))
	var cv := []
	for e in d.get("cv", []):
		if e is Array and (e as Array).size() >= 4:
			cv.append([float(e[0]), String(e[1]), String(e[2]), int(e[3])])
	p.cv = cv


func to_dict() -> Dictionary:
	var arc := []
	for pid in archive:
		var f: Dictionary = archive[pid]
		var d := pack(f)
		for k in ["id", "p", "n", "s", "fin", "cause", "lieu", "met", "r"]:
			d[k] = f.get(k, "")
		d.nj = snappedf(float(f.nj), 0.01)
		d.mort = snappedf(float(f.mort), 0.01)
		d.hob = ",".join(f.get("hob", []))
		arc.append(d)
	return {"archive": arc, "suivi": followed, "totaux": totals}


func from_dict(d: Dictionary) -> void:
	archive.clear()
	_digest.clear()
	clear_cache()
	for e in d.get("archive", []):
		var f := {}
		unpack(f, e)
		f.id = int(e.get("id", -1))
		for k in ["p", "n", "s", "fin", "cause", "lieu", "met", "r"]:
			f[k] = String(e.get(k, ""))
		f.nj = float(e.get("nj", 0.0))
		f.mort = float(e.get("mort", 0.0))
		f.hob = String(e.get("hob", "")).split(",", false)
		if int(f.id) >= 0:
			archive[int(f.id)] = f
	var t: Dictionary = d.get("totaux", {})
	for k in totals:
		totals[k] = t.get(k, totals[k])
	followed = int(d.get("suivi", -1))
	if not pop.persons.has(followed):
		followed = -1
