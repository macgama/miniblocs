class_name Ordres
extends RefCounted
## Ordres que le joueur donne aux habitants (façon Sims).
##
## - Ordres de la journée ("jour") : l'habitant quitte son programme, va où on
##   lui dit, y reste un moment, puis rentre et reprend sa journée. L'ordre
##   est rangé dans `p.ord` = {k, b, d (jour), t (heure), dur, txt} et appliqué
##   par Population.day_plan.
## - Choix de vie ("vie") : effet immédiat (emploi, déménagement, mariage,
##   enfant, séparation, retraite), noté dans le CV.
## - Tout le monde peut commander tout le monde, sauf le personnage principal
##   d'un autre joueur.
## Pour ajouter un ordre : une entrée dans LISTE, un cas dans check() et give().

const LISTE := [
	{"id": "aller", "name": "Aller à… (clic sur un bâtiment)", "type": "jour"},
	{"id": "rentrer", "name": "Rentrer à la maison", "type": "jour"},
	{"id": "travail", "name": "Aller au travail ou à l'école", "type": "jour"},
	{"id": "loisir", "name": "Faire un loisir ou du sport…", "type": "jour"},
	{"id": "courses", "name": "Faire les courses", "type": "jour"},
	{"id": "visite", "name": "Rendre visite à…", "type": "jour"},
	{"id": "dormir", "name": "Aller dormir", "type": "jour"},
	{"id": "emploi", "name": "Chercher un emploi", "type": "vie"},
	{"id": "demission", "name": "Démissionner", "type": "vie"},
	{"id": "demenager", "name": "Déménager (logement libre)", "type": "vie"},
	{"id": "rencontre", "name": "Chercher l'âme sœur", "type": "vie"},
	{"id": "mariage", "name": "Demander en mariage", "type": "vie"},
	{"id": "enfant", "name": "Avoir un enfant", "type": "vie"},
	{"id": "separation", "name": "Se séparer", "type": "vie"},
	{"id": "retraite", "name": "Prendre sa retraite", "type": "vie"},
]
## Durée (heures) passée sur place.
const DUREE := {"aller": 2.0, "loisir": 2.0, "courses": 1.0, "visite": 2.0, "travail": 4.0}


static func entry(id: String) -> Dictionary:
	for e in LISTE:
		if e.id == id:
			return e
	return {}


## Personnage principal d'un autre joueur : on ne le commande pas.
static func protected(pop: Population, p: Dictionary) -> bool:
	var owner := String(p.get("joueur", ""))
	return owner != "" and owner != pop.player_id()


## "" si l'ordre est possible, sinon la raison.
static func check(pop: Population, p: Dictionary, id: String) -> String:
	if protected(pop, p):
		return "C'est le personnage principal d'un autre joueur."
	var a := pop.age_of(p)
	var st := pop.stage(p)
	var h: Dictionary = pop.households.get(int(p.f), {})
	if entry(id).get("type", "") == "jour" and a < 3.0:
		return "Un bébé ne se déplace pas seul."
	match id:
		"travail":
			if int(p.job) < 0 and int(p.sch) < 0:
				return "Pas de travail ni d'école."
		"loisir":
			if hobby_venues(pop, p).is_empty():
				return "Aucun lieu en ville pour ses loisirs."
		"courses":
			if pop._nearest_cat(p, "commerce") < 0:
				return "Aucun commerce en ville."
		"visite":
			if visit_targets(pop, p).is_empty():
				return "Personne à qui rendre visite."
		"emploi":
			if a < 16.0 or st == "retraite":
				return "Trop jeune ou à la retraite."
			if _free_jobs(pop, int(p.job)).is_empty():
				return "Aucun emploi libre en ville."
		"demission":
			if int(p.job) < 0:
				return "N'a pas d'emploi."
		"demenager":
			if a < 18.0 or String(p.r) != "adulte":
				return "Seul un adulte du foyer peut faire déménager la famille."
			if _free_home(pop, int(h.get("b", -1))) < 0:
				return "Aucun logement libre."
		"rencontre":
			if a < 18.0:
				return "Trop jeune."
			if int(p.cj) >= 0:
				return "Déjà en couple."
		"mariage":
			if int(p.cj) < 0 or not pop.persons.has(int(p.cj)):
				return "Il faut d'abord être en couple."
			if String(p.un) == "mariage":
				return "Déjà marié%s." % CycleVie.g(p, "", "e")
		"enfant":
			if mother_for(pop, p) < 0:
				return "Il faut un couple sous le même toit, avec une femme de 18 à 45 ans."
		"separation":
			if int(p.cj) < 0 or not pop.persons.has(int(p.cj)):
				return "N'est pas en couple."
		"retraite":
			if st == "retraite":
				return "Déjà à la retraite."
			if a < 60.0:
				return "Possible à partir de 60 ans."
	return ""


## Donne un ordre. arg : bâtiment (aller), loisir (loisir), habitant (visite).
## Renvoie {ok, text}.
static func give(pop: Population, p: Dictionary, id: String, arg: Variant = null) -> Dictionary:
	var why := check(pop, p, id)
	if why != "":
		return {"ok": false, "text": why}
	var name := CycleVie.full_name(p)
	var home := pop.home_of(p)
	var n := pop.now()
	var vie := pop.vie
	match id:
		"aller":
			var bid := int(arg) if arg != null else -1
			if not pop.known.has(bid):
				return {"ok": false, "text": "Choisis un bâtiment de la ville."}
			return _day(pop, p, id, bid, "Sur ton ordre : à %s" % pop.building_name(bid), "loisir")
		"rentrer":
			return _day(pop, p, id, home, "Rentré%s sur ton ordre" % CycleVie.g(p, "", "e"), "maison")
		"dormir":
			return _day(pop, p, id, home, "Dort (sur ton ordre)", "dort")
		"travail":
			var dest := int(p.job) if int(p.job) >= 0 else int(p.sch)
			return _day(pop, p, id, dest, "Au travail (sur ton ordre)" if int(p.job) >= 0 else "À l'école (sur ton ordre)",
				"travail" if int(p.job) >= 0 else "ecole")
		"loisir":
			var venues := hobby_venues(pop, p)
			var hb := String(arg) if arg != null and venues.has(String(arg)) else String(venues.keys()[0])
			return _day(pop, p, id, int(venues[hb]), "%s (sur ton ordre, %s)" % [Metiers.LOISIRS[hb].name,
				pop.building_name(int(venues[hb]))], "loisir")
		"courses":
			var shop := pop._nearest_cat(p, "commerce")
			return _day(pop, p, id, shop, "Fait les courses (sur ton ordre)", "courses")
		"visite":
			var targets := visit_targets(pop, p)
			var who := int(arg) if arg != null and targets.has(int(arg)) else int(targets.keys()[0])
			var q: Dictionary = pop.persons[who]
			return _day(pop, p, id, pop.home_of(q), "En visite chez %s (%s)" % [CycleVie.full_name(q), targets[who]], "loisir")
		"emploi":
			var jobs := _free_jobs(pop, int(p.job))
			var best := pop._nearest(home, jobs)
			if best < 0:
				best = jobs[0]
			pop._join_job(p, best)
			return {"ok": true, "text": "%s devient %s à %s." % [name, String(Metiers.job(String(p.met)).name).to_lower(),
				pop.building_name(best)]}
		"demission":
			var where := pop.building_name(int(p.job))
			pop._leave_job(p, "Démissionne (%s)" % where)
			return {"ok": true, "text": "%s démissionne de %s." % [name, where]}
		"demenager":
			var h: Dictionary = pop.households[int(p.f)]
			var bid := int(arg) if arg != null and pop.free_homes(int(arg)) > 0 else _free_home(pop, int(h.b))
			pop.move_household(int(p.f), bid)
			return {"ok": true, "text": "Le foyer de %s déménage à %s." % [name, pop.building_name(bid)]}
		"rencontre":
			var singles := []
			for pid in pop.persons:
				var q: Dictionary = pop.persons[pid]
				if int(q.cj) < 0 and pop.age_of(q) >= 18.0 and pid != int(p.id):
					singles.append(pid)
			if not vie.find_partner(p, singles):
				return {"ok": false, "text": "%s ne trouve personne pour l'instant (célibataires de son âge en ville ?)." % name}
			return {"ok": true, "text": "%s rencontre %s." % [name, CycleVie.full_name(pop.persons[int(p.cj)])]}
		"mariage":
			var q: Dictionary = pop.persons[int(p.cj)]
			if int(q.f) != int(p.f):
				vie._move_in_together(p, q)
			vie._union(p, q, "mariage")
			return {"ok": true, "text": "%s et %s se marient !" % [name, CycleVie.full_name(q)]}
		"enfant":
			var mom := mother_for(pop, p)
			var baby := vie._birth(mom, true)
			if baby < 0:
				return {"ok": false, "text": "Pas maintenant : déjà deux petits de moins de 6 ans, ou foyer complet."}
			return {"ok": true, "text": "Naissance de %s !" % CycleVie.full_name(pop.persons[baby])}
		"separation":
			var q: Dictionary = pop.persons[int(p.cj)]
			vie._separate(p, q)
			return {"ok": true, "text": "%s et %s se séparent." % [name, CycleVie.full_name(q)]}
		"retraite":
			p.retr = true
			pop._match_all()
			return {"ok": true, "text": "%s prend sa retraite." % name}
	return {"ok": false, "text": "Ordre inconnu."}


static func _day(pop: Population, p: Dictionary, id: String, bid: int, text: String, kind: String) -> Dictionary:
	if bid < 0 or not pop.known.has(bid):
		return {"ok": false, "text": "Lieu introuvable."}
	var n := pop.now()
	p.ord = {"k": id, "b": bid, "d": int(n.day), "t": float(n.h), "dur": float(DUREE.get(id, 2.0)), "txt": text, "kind": kind}
	pop.plan_changed(int(p.id))
	return {"ok": true, "text": "%s : %s." % [CycleVie.full_name(p), text[0].to_lower() + text.substr(1)]}


## Loisirs possibles en ville : {loisir: bâtiment}.
static func hobby_venues(pop: Population, p: Dictionary) -> Dictionary:
	var out := {}
	for hb in Metiers.LOISIRS:
		if (Metiers.LOISIRS[hb].lieux as Array).is_empty():
			continue
		var v := pop.venue_for(p, hb)
		if v >= 0:
			out[hb] = v
	# Ses loisirs d'abord.
	var mine := {}
	for hb in p.hob:
		if out.has(hb):
			mine[hb] = out[hb]
	for hb in out:
		if not mine.has(hb):
			mine[hb] = out[hb]
	return mine


## Proches chez qui aller : {pid: lien}.
static func visit_targets(pop: Population, p: Dictionary) -> Dictionary:
	var out := {}
	var vie := pop.vie
	var ids := []
	ids.append_array(vie.parents_of(p))
	ids.append_array(vie.children_of(int(p.id)))
	ids.append_array(vie.siblings_of(p))
	for par in vie.parents_of(p):
		ids.append_array(vie.parents_of(vie.person(par)))
	if int(p.cj) >= 0:
		ids.append(int(p.cj))
	for pid in ids:
		if pop.persons.has(pid) and int(pop.persons[pid].f) != int(p.f) and not out.has(pid):
			out[pid] = vie.relation(p, pop.persons[pid])
	# Collègues.
	if int(p.job) >= 0:
		for pid in pop.by_job.get(int(p.job), []):
			if pid != int(p.id) and not out.has(pid) and int(pop.persons[pid].f) != int(p.f) and out.size() < 12:
				out[pid] = CycleVie.g(pop.persons[pid], "collègue", "collègue")
	return out


## La future mère pour « Avoir un enfant » (elle-même ou sa conjointe), ou -1.
static func mother_for(pop: Population, p: Dictionary) -> int:
	if int(p.cj) < 0 or not pop.persons.has(int(p.cj)):
		return -1
	var q: Dictionary = pop.persons[int(p.cj)]
	if int(q.f) != int(p.f):
		return -1
	for m in [p, q]:
		var a := pop.age_of(m)
		if String(m.s) == "F" and a >= 18.0 and a < 46.0:
			return int(m.id)
	return -1


static func _free_jobs(pop: Population, current: int) -> Array:
	var out := []
	for bid in pop.known:
		if bid != current and pop.free_jobs(bid) > 0:
			out.append(bid)
	return out


static func _free_home(pop: Population, current: int) -> int:
	var best := -1
	for bid in pop.known:
		if bid != current and pop.free_homes(bid) > 0:
			if best < 0 or bid < best:
				best = bid
	return best
