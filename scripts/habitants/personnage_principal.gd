class_name PersonnagePrincipal
extends RefCounted
## Le personnage principal du joueur : il naît dans une famille de la ville,
## le joueur le suit toute sa vie et décide de ses grands choix (rencontre,
## mariage, enfants, études, offres d'emploi, retraite). À sa mort, le joueur
## continue avec un enfant ou un proche, ou fait naître un nouveau personnage.
##
## - L'habitant porte `p.joueur` = identifiant du joueur (SaveGame.player_id()).
##   Les autres joueurs ne peuvent pas lui donner d'ordres (Ordres.protected).
## - Les questions attendent la réponse du joueur (`questions`) ; le temps se
##   met en pause pendant qu'une question est affichée (`pause_on_question`).
## - Le hasard ne décide plus pour lui : pas de rencontre, mariage, enfant,
##   séparation ni changement de travail automatiques (CycleVie._player_choice).

var pop: Population
## Le joueur veut un personnage principal dans cette partie.
var enabled := true
var pause_on_question := true
## [{id, pid, kind, text, options: [[label, action, arg]]}]
var questions: Array = []
var _next_q := 1
var _speed_before := -1


func _init(p: Population) -> void:
	pop = p


func clear() -> void:
	questions.clear()
	_speed_before = -1


## Le personnage principal du joueur de cette machine, vivant (-1 sinon).
func mine() -> int:
	var me := pop.player_id()
	for pid in pop.persons:
		if String(pop.persons[pid].get("joueur", "")) == me:
			return pid
	return -1


func is_mine(p: Dictionary) -> bool:
	return String(p.get("joueur", "")) == pop.player_id()


## Fait naître le personnage dans une famille (couple sous le même toit, mère de 18 à 45 ans).
func try_birth() -> int:
	if not enabled or mine() >= 0 or _has_question("heritier"):
		return -1
	var best := -1
	var best_score := -INF
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		var mom := Ordres.mother_for(pop, p)
		if mom != pid:
			continue
		# Une famille déjà installée, avec un logement agréable et peu d'enfants.
		var h: Dictionary = pop.households[int(p.f)]
		var score := -float((h.m as Array).size()) + pop.rng.randf()
		if score > best_score:
			best_score = score
			best = pid
	if best < 0:
		return -1
	var baby := pop.vie._birth(best, true)
	if baby < 0:
		return -1
	var b: Dictionary = pop.persons[baby]
	b.joueur = pop.player_id()
	pop.vie.log_event(b, "naissance", "Devient ton personnage principal", -1)
	pop.follow(baby)
	pop.message.emit("★ Ton personnage est né : %s, chez %s. Tu décideras de ses grands choix." % [
		CycleVie.full_name(b), pop.building_name(pop.home_of(b))])
	return baby


# --- Questions ----------------------------------------------------------------------

func _has_question(kind: String) -> bool:
	for q in questions:
		if String(q.kind) == kind:
			return true
	return false


func ask(pid: int, kind: String, text: String, options: Array) -> void:
	if _has_question(kind) or questions.size() >= 4:
		return
	questions.append({"id": _next_q, "pid": pid, "kind": kind, "text": text, "options": options})
	_next_q += 1
	if pause_on_question and pop.ambiance != null and pop.ambiance.speed_index > 0:
		_speed_before = pop.ambiance.speed_index
		pop.ambiance.set_speed(0)
	pop.questions_changed.emit()


## Réponse du joueur : option n° i de la question qid.
func answer(qid: int, i: int) -> void:
	var q: Dictionary = {}
	for x in questions:
		if int(x.id) == qid:
			q = x
	if q.is_empty():
		return
	questions.erase(q)
	var opt: Array = q.options[clampi(i, 0, (q.options as Array).size() - 1)]
	_apply(q, String(opt[1]), opt[2] if opt.size() > 2 else null)
	if questions.is_empty() and _speed_before > 0 and pop.ambiance != null and pop.ambiance.speed_index == 0:
		pop.ambiance.set_speed(_speed_before)
		_speed_before = -1
	pop.questions_changed.emit()


func _apply(q: Dictionary, action: String, arg: Variant) -> void:
	var pid := int(q.pid)
	var vie := pop.vie
	if action == "non":
		return
	if action == "heritier":
		var h := int(arg)
		if pop.persons.has(h):
			pop.persons[h].joueur = pop.player_id()
			vie.log_event(pop.persons[h], "heritage", "Devient ton personnage principal", -1)
			pop.follow(h)
		return
	if action == "nouveau":
		try_birth()
		return
	if not pop.persons.has(pid):
		return
	var p: Dictionary = pop.persons[pid]
	match action:
		"couple":
			if pop.persons.has(int(arg)) and int(p.cj) < 0 and int(pop.persons[int(arg)].cj) < 0:
				vie._couple(p, pop.persons[int(arg)], String(q.get("where", "")))
		"mariage", "pacs":
			if pop.persons.has(int(p.cj)):
				vie._union(p, pop.persons[int(p.cj)], action)
		"enfant":
			var mom := Ordres.mother_for(pop, p)
			if mom >= 0:
				vie._birth(mom, true)
		"etudes":
			var sup := String(arg)
			var dur: float = {"bts": 2.0, "licence": 3.0, "master": 5.0}.get(sup, 3.0)
			p.etd = sup
			p.etu = pop.life_clock + dur * 365.25
			vie.log_event(p, "etudes", "Choisit des études (%s, %d ans) à l'université, hors de la ville" % [CycleVie.DIPLOMES[sup], int(dur)])
		"emploi":
			if pop.known.has(int(arg)) and pop.free_jobs(int(arg)) > 0:
				pop._join_job(p, int(arg))
		"retraite":
			p.retr = true
			pop._match_all()


## Chaque année de vie : les questions de l'année pour le personnage principal.
func yearly(years: float) -> void:
	var pid := mine()
	if pid < 0:
		try_birth()
		return
	var p: Dictionary = pop.persons[pid]
	var a := pop.age_of(p)
	var name := String(p.p)
	var rng := pop.rng
	# Rencontre.
	if a >= 18.0 and int(p.cj) < 0 and rng.randf() < 0.35 * years:
		var singles := []
		for oid in pop.persons:
			var o: Dictionary = pop.persons[oid]
			if int(o.cj) < 0 and pop.age_of(o) >= 18.0:
				singles.append(oid)
		var pick := pop.vie._best_partner(p, singles, {})
		if not pick.is_empty():
			var o: Dictionary = pop.persons[int(pick.id)]
			questions_add_where(pid, "rencontre", "%s rencontre %s (%d ans, %s) %s. Se mettre en couple ?" % [name,
				CycleVie.full_name(o), pop.age_years(o), pop.stage_label(o).to_lower(), pick.where],
				[["Oui, se mettre en couple", "couple", int(pick.id)], ["Non, pas maintenant", "non"]], String(pick.where))
	# Mariage ou PACS.
	if int(p.cj) >= 0 and pop.persons.has(int(p.cj)) and String(p.un) == "couple" and rng.randf() < 0.15 * years:
		var c: Dictionary = pop.persons[int(p.cj)]
		ask(pid, "union", "%s et %s sont ensemble depuis un moment. Officialiser ?" % [name, CycleVie.full_name(c)],
			[["Se marier", "mariage"], ["Se pacser", "pacs"], ["Rester en couple", "non"]])
	# Enfant.
	if Ordres.mother_for(pop, p) >= 0 and rng.randf() < 0.2 * years:
		ask(pid, "enfant", "%s et son couple pensent à avoir un enfant. Agrandir la famille ?" % name,
			[["Oui, avoir un enfant", "enfant"], ["Pas maintenant", "non"]])
	# Offre d'emploi.
	if a >= 18.0 and pop.stage(p) in ["actif", "chomeur"] and rng.randf() < 0.25 * years:
		var jobs := Ordres._free_jobs(pop, int(p.job))
		if not jobs.is_empty():
			var bid: int = jobs[rng.randi() % jobs.size()]
			var met := Metiers.job(Metiers.pick_job(rng, String(pop.known[bid].t)))
			ask(pid, "emploi", "Offre d'emploi pour %s : %s à %s (%s net par mois). %s" % [name, String(met.name).to_lower(),
				pop.building_name(bid), HabitantsPanel.money(float(met.salaire) * ReglagesPartie.actuel.salaires),
				"Changer de travail ?" if int(p.job) >= 0 else "Accepter ?"],
				[["Accepter", "emploi", bid], ["Refuser", "non"]])
	# Retraite anticipée.
	if a >= 60.0 and pop.stage(p) == "actif" and rng.randf() < 0.5 * years:
		ask(pid, "retraite", "%s a %d ans. Prendre sa retraite maintenant ?" % [name, floori(a)],
			[["Oui, la retraite", "retraite"], ["Continuer à travailler", "non"]])


func questions_add_where(pid: int, kind: String, text: String, options: Array, where: String) -> void:
	ask(pid, kind, text, options)
	if not questions.is_empty() and String(questions[-1].kind) == kind:
		questions[-1].where = where


## Après le bac : le joueur choisit les études.
func ask_studies(p: Dictionary) -> void:
	ask(int(p.id), "etudes", "%s a son bac ! Quelles études ?" % p.p,
		[["BTS (2 ans)", "etudes", "bts"], ["Licence (3 ans)", "etudes", "licence"], ["Master (5 ans)", "etudes", "master"],
		["Travailler tout de suite", "non"]])


## À la mort du personnage : continuer avec un proche ou un nouveau-né.
func on_death(dead: Dictionary) -> void:
	var opts := []
	var vie := pop.vie
	var ids := vie.children_of(int(dead.id))
	if int(dead.get("cj", -1)) >= 0:
		ids.append(int(dead.cj))
	for k in ids:
		if pop.persons.has(k) and String(pop.persons[k].get("joueur", "")) == "" and opts.size() < 3:
			var q: Dictionary = pop.persons[k]
			opts.append(["Continuer avec %s (%s, %d ans)" % [CycleVie.full_name(q), vie.relation(dead, q), pop.age_years(q)], "heritier", k])
	opts.append(["Faire naître un nouveau personnage", "nouveau"])
	ask(-1, "heritier", "%s est mort%s à %d ans. Avec qui continuer ?" % [CycleVie.full_name(dead), CycleVie.g(dead, "", "e"),
		floori(vie.age_of(dead))], opts)


# --- Sauvegarde ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"actif": enabled, "pause": pause_on_question, "questions": questions, "next": _next_q}


func from_dict(d: Dictionary) -> void:
	enabled = bool(d.get("actif", true))
	pause_on_question = bool(d.get("pause", true))
	questions.clear()
	for q in d.get("questions", []):
		if q is Dictionary:
			var opts := []
			for o in q.get("options", []):
				var o2: Array = (o as Array).duplicate()
				if o2.size() > 2 and o2[2] is float and float(o2[2]) == floorf(float(o2[2])):
					o2[2] = int(o2[2])
				opts.append(o2)
			questions.append({"id": int(q.get("id", 0)), "pid": int(q.get("pid", -1)), "kind": String(q.get("kind", "")),
				"text": String(q.get("text", "")), "options": opts, "where": String(q.get("where", ""))})
	_next_q = int(d.get("next", questions.size() + 1))
	_speed_before = -1
