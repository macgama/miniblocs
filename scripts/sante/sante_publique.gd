class_name SantePublique
extends Node
## Santé publique (panneau F7, menu Infos) : hygiène des logements, vaccins,
## mesures sanitaires et grandes épidémies de l'histoire.
##
## - Hygiène d'un logement : eau du robinet (réseau d'eau et sa qualité) ou du
##   puits, égouts (raccordé et traité) ou fosse d'aisance. Avant 1950 (époques),
##   un logement insalubre raccourcit la vie (CycleVie, Population.extra_health).
## - Maladies de l'eau (choléra, typhoïde) : un malade sans égout souille les
##   puits de son quartier (cases de 150 m) ; sur le réseau, l'eau mal traitée
##   (Reseaux.qualite_de) les répand plus loin. Égouts, eau potable, chlore et
##   eau bouillie les arrêtent.
## - Vaccins datés (variole en 1800, diphtérie 1923, polio 1955, rougeole 1963,
##   Covid-19 2021…) : campagnes du maire (doses payées par la ville, plus
##   rapides avec des hôpitaux et des médecins) et obligation vaccinale. Une
##   part des habitants refuse (selon l'époque). Au-delà de 90 % de vaccinés, la
##   maladie ne prend plus (immunité collective).
## - Mesures sanitaires datées : quarantaine, écoles fermées, lazaret, campagne
##   d'hygiène (1847), eau bouillie (1854), chloration (1902), masques et
##   confinement (1918). Elles coûtent chaque jour et fâchent parfois les
##   habitants (contrat Avis). Les mesures temporaires sont levées une semaine
##   après la fin de l'épidémie.
## - Calendrier des grandes épidémies (partie à une époque historique, réglage
##   catastrophes de l'Admin) : choléra de 1832, 1849, 1854…, variole de 1870,
##   grippe espagnole de 1918, grippes de 1957 et 1968, Covid-19 en 2020. Une
##   rumeur arrive d'abord dans la gazette, puis l'épidémie.
## - Lits d'hôpital : un hôpital débordé laisse mourir plus de cas graves ; les
##   traitements arrivent avec l'histoire (sérum 1894, antibiotiques 1945…).
##
## Le moteur des épidémies reste Epidemies (scripts/evenements) : il demande ici
## protege(), facteur_contagion(), contamines_eau() et facteur_letalite().

signal changed
signal message(text: String)

static var instance: SantePublique

## Taille des quartiers de puits (m).
const CASE_PUITS := 150.0
## Couverture vaccinale qui arrête une maladie (immunité collective).
const SEUIL_COLLECTIF := 0.9
## Jours sans épidémie avant de lever les mesures temporaires.
const LEVEE_JOURS := 7
## Probabilité par jour qu'une grande épidémie arrive, l'année venue.
const ARRIVEE_JOUR := 1.0 / 25.0

var ev: Evenements
var population: Population
var buildings: BuildingSystem

## Vaccins : clé -> {pid: année de la dose}.
var vaccins: Dictionary = {}
## Campagnes en cours : clé -> {debut (jour), doses, cout}.
var campagnes: Dictionary = {}
## Obligation vaccinale : clé -> true.
var obligatoires: Dictionary = {}
## Mesures en vigueur : clé -> jour de début.
var mesures: Dictionary = {}
## Épidémies passées : [{nom, maladie, annee, total, graves, deces, jours}], la plus récente d'abord.
var historique: Array = []
## Grandes épidémies : "1832" -> "rumeur" | "fait" | "passe".
var pandemies: Dictionary = {}
## Repères de la médecine déjà annoncés : "1847" -> true.
var reperes: Dictionary = {}
## Décès par maladie depuis le début de la partie.
var deces: Dictionary = {}
## Grandes épidémies de l'histoire au calendrier (réglage du panneau).
var historiques := true
## Tests : -1 = réglage Admin (catastrophes), 0 / 1 = forcé.
var forcer_historiques := -1
var depenses_mois := 0.0

var _last_day := -1
var _sans_epidemie := 0
var _hyg_cache: Dictionary = {}
var _letal_cache: Dictionary = {}
var _bilan_cache: Dictionary = {}
var _bilan_ms := -100000
var _hesitant_cache: Dictionary = {}


func _init() -> void:
	name = "SantePublique"


func _enter_tree() -> void:
	instance = self
	add_to_group("avis_sources")
	add_to_group("budget_entretien")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(e: Evenements, pop: Population, bs: BuildingSystem) -> void:
	ev = e
	population = pop
	buildings = bs
	if population != null:
		var avant_h: Callable = population.extra_health
		population.extra_health = func(p: Dictionary) -> Array:
			var f := 1.0
			var why := []
			if avant_h.is_valid():
				var ex: Array = avant_h.call(p)
				if ex.size() >= 2:
					f *= float(ex[0])
					why.append_array(ex[1])
			var mine := _sante_logement(p)
			if float(mine[0]) != 1.0:
				f *= float(mine[0])
				why.append_array(mine[1])
			return [f, why]
		var avant_s: Callable = population.extra_satisfaction
		population.extra_satisfaction = func(p: Dictionary) -> Array:
			var d := 0.0
			var why := []
			if avant_s.is_valid():
				var ex: Array = avant_s.call(p)
				if ex.size() >= 2:
					d += float(ex[0])
					why.append_array(ex[1])
			if not _avis_present():
				var r := _avis_mesures()
				if float(r[0]) != 0.0:
					d += float(r[0])
					why.append_array(r[1])
			return [d, why]


func clear() -> void:
	vaccins.clear()
	campagnes.clear()
	obligatoires.clear()
	mesures.clear()
	historique.clear()
	pandemies.clear()
	reperes.clear()
	deces.clear()
	historiques = true
	depenses_mois = 0.0
	_last_day = -1
	_sans_epidemie = 0
	_caches()
	changed.emit()


func _caches() -> void:
	_hyg_cache.clear()
	_letal_cache.clear()
	_hesitant_cache.clear()
	_bilan_ms = -100000


func _avis_present() -> bool:
	return Avis.instance != null and is_instance_valid(Avis.instance)


# --- Temps ------------------------------------------------------------------------------

static func annee() -> int:
	return Epoques.annee()


func jour() -> int:
	return int(population.now().day) if population != null else 0


func _process(_delta: float) -> void:
	if population == null or population.ambiance == null:
		return
	var d := jour()
	if _last_day < 0 or d < _last_day:
		_last_day = d
		_premier_jour()
		return
	if d > _last_day:
		_last_day = d
		nouveau_jour()


## Au chargement : les repères déjà passés ne sont pas annoncés.
func _premier_jour() -> void:
	var an := annee()
	for r in SanteDonnees.REPERES:
		if int(r.annee) <= an:
			reperes[str(r.annee)] = true


## Un jour de jeu : vaccins, mesures, calendrier des épidémies.
func nouveau_jour() -> void:
	_caches()
	var an := annee()
	_vacciner(an)
	_mesures_du_jour()
	_calendrier(an)
	_reperes(an)
	changed.emit()


# --- Hygiène des logements ----------------------------------------------------------------

func _reseaux() -> Reseaux:
	var r := Reseaux.instance
	if r != null and is_instance_valid(r) and r.population == population:
		return r
	return null


## Hygiène d'un logement : {eau (0-1, 1 = potable), egout (0-1), total, reseau (bool), txt}.
func hygiene(bid: int) -> Dictionary:
	if _hyg_cache.has(bid):
		return _hyg_cache[bid]
	var r := _reseaux()
	var eau := 0.55
	var egout := 0.2
	var reseau := false
	if r != null:
		if r.egout.est_raccorde(bid):
			egout = 1.0 if r.raccorde_egout(bid) else 0.6
		if r.eau.est_raccorde(bid) and r.taux(bid, "eau") >= 0.5:
			reseau = true
			eau = r.qualite_de(bid)
			if mesures.has("chloration"):
				eau = maxf(eau, 0.98)
	if not reseau and egout >= 0.6:
		eau = 0.7
	var txt := ""
	if reseau:
		txt = "eau du réseau (%d %% potable)" % roundi(eau * 100.0)
	else:
		txt = "eau du puits"
	txt += ", " + ("égouts" if egout >= 1.0 else ("égout sans station d'épuration" if egout >= 0.6 else "fosse d'aisance"))
	var h := {"eau": eau, "egout": egout, "total": 0.5 * eau + 0.5 * egout, "reseau": reseau, "txt": txt}
	_hyg_cache[bid] = h
	return h


## Avant 1950 (époques) : un logement insalubre raccourcit la vie.
func _sante_logement(p: Dictionary) -> Array:
	if not Epoques.actif() or annee() >= 1950:
		return [1.0, []]
	var home := population.home_of(p)
	if home < 0:
		return [1.0, []]
	var r := _reseaux()
	# Le réseau compte déjà son eau et ses égouts (Reseaux.risque_sante) quand il les attend.
	if r != null and r.etat.has(home):
		return [1.0, []]
	var h := hygiene(home)
	var bad := 1.0 - float(h.total)
	if bad < 0.1:
		return [0.9, ["+ logement sain (eau potable et égouts)"]]
	return [1.0 + 0.35 * bad, ["− %s" % String(h.txt)]]


# --- Contagion (appelé par Epidemies) ------------------------------------------------------

func _mode(maladie: String) -> String:
	return String(Epidemies.MALADIES.get(maladie, {}).get("mode", "air"))


## Contagion d'un malade vers un contact selon le lieu ("foyer", "travail", "ecole").
func facteur_contagion(maladie: String, ctx: String) -> float:
	var f := 1.0
	var mode := _mode(maladie)
	if mesures.has("hygiene"):
		f *= 0.8
	if ctx == "ecole" and (mesures.has("ecoles") or mesures.has("confinement")):
		return 0.0
	if ctx != "foyer" and mesures.has("quarantaine"):
		f /= 3.0
	if ctx == "travail" and mesures.has("confinement"):
		f /= 4.0
	if mode == "air" and ctx != "foyer" and mesures.has("masques"):
		f *= 0.6
	return f


## Ce vaccinés est-il protégé contre la maladie ?
func protege(pid: int, maladie: String, _p: Dictionary = {}) -> bool:
	var an := annee()
	for v in SanteDonnees.vaccins_de(maladie):
		var d: Dictionary = vaccins.get(v, {})
		if not d.has(pid):
			continue
		if bool(SanteDonnees.VACCINS[v].get("annuel", false)) and int(d[pid]) != an:
			continue
		if ev.rng.randf() < float(SanteDonnees.VACCINS[v].efficacite):
			return true
	return false


## Assez de vaccinés pour que la maladie ne prenne pas.
func immunite_collective(maladie: String) -> bool:
	for v in SanteDonnees.vaccins_de(maladie):
		if couverture(v) >= SEUIL_COLLECTIF:
			return true
	return false


## Nouveaux malades par l'eau souillée (choléra, typhoïde).
func contamines_eau(malades: Dictionary, maladie: String, rng: RandomNumberGenerator) -> Array:
	var m: Dictionary = Epidemies.MALADIES.get(maladie, {})
	var k := float(m.get("eau", 0.0))
	if k <= 0.0 or population == null:
		return []
	if mesures.has("eau_bouillie"):
		k /= 2.5
	if mesures.has("hygiene"):
		k *= 0.7
	# Puits souillés par les malades sans égout, et égouts qui finissent à la rivière.
	var puits := {}
	var vers_riviere := 0.0
	for pid in malades:
		var p: Dictionary = population.persons.get(pid, {})
		if p.is_empty():
			continue
		var home := population.home_of(p)
		if home < 0 or not population.known.has(home):
			continue
		var h := hygiene(home)
		var eg := float(h.egout)
		if eg >= 1.0:
			continue
		if eg >= 0.6:
			vers_riviere += 1.0
			continue
		var c := _case(population.building_pos(home))
		puits[c] = float(puits.get(c, 0.0)) + 1.0
	if puits.is_empty() and vers_riviere <= 0.0:
		return []
	var reseau_souille := clampf(vers_riviere * 0.1 + float(puits.size()) * 0.03, 0.0, 1.0)
	var out := []
	for hid in population.households:
		var hh: Dictionary = population.households[hid]
		var home := int(hh.b)
		if not population.known.has(home):
			continue
		var h := hygiene(home)
		var expo := 0.0
		if bool(h.reseau):
			expo = reseau_souille * (1.0 - float(h.eau)) * 4.0
		else:
			var c := _case(population.building_pos(home))
			var s := float(puits.get(c, 0.0))
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if dx != 0 or dz != 0:
						s += 0.4 * float(puits.get(c + Vector2i(dx, dz), 0.0))
			# Égout et puits ne se mélangent pas : le puits reste plus propre.
			expo = clampf(s * 0.35, 0.0, 1.0) * (0.4 if float(h.egout) >= 0.6 else 1.0)
		if expo <= 0.0:
			continue
		var q := clampf(k * expo, 0.0, 0.5)
		for pid in hh.m:
			if not malades.has(int(pid)) and rng.randf() < q:
				out.append(int(pid))
	return out


func _case(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CASE_PUITS), floori(pos.z / CASE_PUITS))


## Gravité : traitements de l'époque et hôpitaux débordés.
func facteur_letalite(maladie: String, hop: bool, _sans_hop: bool) -> float:
	var f := 1.0
	var m: Dictionary = Epidemies.MALADIES.get(maladie, {})
	var tr: Array = m.get("traitement", [])
	if tr.size() >= 2 and annee() >= int(tr[0]):
		f *= float(tr[1])
	if hop and hopitaux_debordes():
		f *= 1.8
	return f


func lazaret() -> bool:
	return mesures.has("lazaret")


## Lits d'hôpital de la ville (ServicesPublics, sinon 3 lits par emploi soignant).
func lits() -> int:
	if _letal_cache.has("lits"):
		return int(_letal_cache.lits)
	var n := 0
	var sp := ServicesPublics.instance
	if sp != null and is_instance_valid(sp) and sp.population == population:
		for l in (sp.bilan("hopital").get("lieux", []) as Array):
			n += sp.capacite(int(l.bid), "hopital")
	if mesures.has("lazaret"):
		n += maxi(10, population.persons.size() / 100) if population != null else 10
	_letal_cache["lits"] = n
	return n


## Cas graves hospitalisés en ce moment.
func hospitalises() -> int:
	var n := 0
	if ev == null or ev.epidemies == null:
		return 0
	for pid in ev.epidemies.malades:
		if bool(ev.epidemies.malades[pid].get("hop", false)):
			n += 1
	return n


## Les épidémies remplissent les lits laissés libres par les autres malades (40 %).
func hopitaux_debordes() -> bool:
	if not _letal_cache.has("deborde"):
		var l := lits()
		_letal_cache["deborde"] = l > 0 and hospitalises() > maxi(2, roundi(l * 0.4))
	return bool(_letal_cache.deborde)


func noter_deces(maladie: String, _p: Dictionary) -> void:
	deces[maladie] = int(deces.get(maladie, 0)) + 1


func noter_fin(e: Dictionary) -> void:
	var d: Dictionary = e.get("data", {})
	var mk := String(d.get("maladie", ""))
	var rec := {"nom": String(e.get("nom", "")), "maladie": mk, "annee": annee(), "total": int(d.get("total", 0)),
		"graves": int(d.get("graves", 0)), "deces": int(d.get("deces", 0)), "jours": maxi(1, jour() - int(d.get("jour0", jour())))}
	historique.push_front(rec)
	if historique.size() > 40:
		historique.resize(40)
	# Le mot de la fin, pour la gazette.
	if ev != null and int(rec.total) > 0:
		var m: Dictionary = Epidemies.MALADIES.get(mk, {})
		if int(rec.deces) == 0 and int(rec.total) >= 5:
			ev.news("Pas un seul mort pendant l'épidémie de %s. Le maire se félicite, les médecins aussi, chacun pour soi." % String(m.get("nom", mk)), Vector3.INF, "epidemie", int(e.get("id", -1)))
		elif _mode(mk) == "eau" and bilan().get("egouts", 0.0) < 0.5:
			ev.news("Après %s, les médecins le répètent : sans égouts ni eau propre, il reviendra." % String(m.get("art", mk)), Vector3.INF, "epidemie", int(e.get("id", -1)))
	changed.emit()


# --- Vaccins ------------------------------------------------------------------------------

func vaccin_disponible(v: String) -> bool:
	return SanteDonnees.VACCINS.has(v) and annee() >= int(SanteDonnees.VACCINS[v].annee)


func _cible(v: String, p: Dictionary) -> bool:
	if String(SanteDonnees.VACCINS[v].cible) == "enfants":
		var a := population.age_of(p)
		return a >= 0.5 and a < 16.0
	return true


## Couverture d'un vaccin dans sa cible (0-1).
func couverture(v: String) -> float:
	if population == null or not SanteDonnees.VACCINS.has(v):
		return 0.0
	var d: Dictionary = vaccins.get(v, {})
	var annuel := bool(SanteDonnees.VACCINS[v].get("annuel", false))
	var an := annee()
	var n := 0
	var ok := 0
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		if not _cible(v, p):
			continue
		n += 1
		if d.has(pid) and (not annuel or int(d[pid]) == an):
			ok += 1
	return float(ok) / float(n) if n > 0 else 0.0


## Cet habitant refuse-t-il le vaccin ? (le même chaque jour)
func hesitant(pid: int, v: String) -> bool:
	var seuil := SanteDonnees.HESITANTS_OBLIGATION if obligatoires.has(v) else SanteDonnees.hesitants(annee())
	var h := hash([pid, v]) % 1000
	return float(absi(h)) / 1000.0 < seuil


## Doses possibles par jour : plus de soignants, plus de doses.
func doses_par_jour() -> int:
	if population == null:
		return 0
	var lieux := 0
	for bid in population.known:
		var keys := Metiers.keys_of(String(population.known[bid].t))
		if keys.has("hopital") or keys.has("clinique") or keys.has("sante") or keys.has("medecin"):
			lieux += 1
	return maxi(10, roundi(population.persons.size() * 0.03)) * (1 + lieux)


## Ce que coûterait la vaccination de toute la cible (€).
func cout_campagne(v: String) -> int:
	if population == null or not SanteDonnees.VACCINS.has(v):
		return 0
	var n := 0
	for pid in population.persons:
		if _cible(v, population.persons[pid]):
			n += 1
	return roundi(n * float(SanteDonnees.VACCINS[v].dose))


func lancer_campagne(v: String) -> bool:
	if not vaccin_disponible(v) or campagnes.has(v):
		return false
	campagnes[v] = {"debut": jour(), "doses": 0, "cout": 0.0}
	var nom := String(SanteDonnees.VACCINS[v].nom)
	_annonce("Campagne de vaccination contre la %s : les médecins sortent leurs seringues, les enfants leurs cris." % nom.to_lower()
		if v != "covid" else "Campagne de vaccination contre le Covid-19 : rendez-vous en ligne, files d'attente devant le gymnase.")
	changed.emit()
	return true


func arreter_campagne(v: String) -> void:
	campagnes.erase(v)
	changed.emit()


func set_obligatoire(v: String, on: bool) -> void:
	if on and not vaccin_disponible(v):
		return
	if on == obligatoires.has(v):
		return
	if on:
		obligatoires[v] = true
		_annonce("La vaccination contre la %s devient obligatoire. Une ligue antivaccinale se réunit au café, ils sont quatre." % String(SanteDonnees.VACCINS[v].nom).to_lower())
	else:
		obligatoires.erase(v)
		_annonce("La vaccination contre la %s n'est plus obligatoire." % String(SanteDonnees.VACCINS[v].nom).to_lower())
	_hesitant_cache.clear()
	changed.emit()


func _vacciner(an: int) -> void:
	if population == null:
		return
	var budget := doses_par_jour()
	for v in SanteDonnees.VACCINS:
		if not campagnes.has(v) and not obligatoires.has(v):
			continue
		if not vaccin_disponible(v):
			continue
		var d: Dictionary = vaccins.get(v, {})
		vaccins[v] = d
		var annuel := bool(SanteDonnees.VACCINS[v].get("annuel", false))
		var faites := 0
		var restants := 0
		for pid in population.persons:
			var p: Dictionary = population.persons[pid]
			if not _cible(v, p) or (d.has(pid) and (not annuel or int(d[pid]) == an)) or hesitant(int(pid), v):
				continue
			if faites >= budget:
				restants += 1
				continue
			d[pid] = an
			faites += 1
		if faites > 0:
			var cout := faites * float(SanteDonnees.VACCINS[v].dose)
			_payer("Vaccination", cout)
			if campagnes.has(v):
				campagnes[v].doses = int(campagnes[v].doses) + faites
				campagnes[v].cout = float(campagnes[v].cout) + cout
		budget = maxi(0, budget - faites)
		if campagnes.has(v) and restants == 0 and faites < doses_par_jour():
			var c: Dictionary = campagnes[v]
			campagnes.erase(v)
			var refus := 0
			for pid in population.persons:
				if _cible(v, population.persons[pid]) and hesitant(int(pid), v):
					refus += 1
			var t := "Campagne de vaccination contre la %s terminée : %d doses, couverture %d %%." % [
				String(SanteDonnees.VACCINS[v].nom).to_lower(), int(c.doses), roundi(couverture(v) * 100.0)]
			if refus > 0:
				t += " %d habitant%s refuse%s : « Mon cousin connaît quelqu'un qui… »" % [refus, "s" if refus > 1 else "", "nt" if refus > 1 else ""]
			_annonce(t)
		# Les morts et les déménagés quittent les listes.
		for pid in d.keys():
			if not population.persons.has(pid):
				d.erase(pid)


# --- Mesures sanitaires -----------------------------------------------------------------------

func mesure_disponible(k: String) -> bool:
	return SanteDonnees.MESURES.has(k) and annee() >= int(SanteDonnees.MESURES[k].annee)


func set_mesure(k: String, on: bool) -> void:
	if not SanteDonnees.MESURES.has(k) or on == mesures.has(k):
		return
	if on:
		if not mesure_disponible(k):
			return
		mesures[k] = jour()
		_annonce(String(SanteDonnees.MESURES[k].oui))
	else:
		mesures.erase(k)
		if SanteDonnees.LEVEES.has(k):
			_annonce(String(SanteDonnees.LEVEES[k]))
	_caches()
	if ev != null:
		ev._forget_plans()
	changed.emit()


## Coût d'une mesure par jour (€).
func cout_mesure(k: String) -> float:
	var m: Dictionary = SanteDonnees.MESURES.get(k, {})
	if m.is_empty():
		return 0.0
	var hab := population.persons.size() if population != null else 0
	return float(m.fixe) + float(m.hab) * hab


func _mesures_du_jour() -> void:
	var en_cours := ev != null and ev.epidemies != null and ev.epidemies.active >= 0
	_sans_epidemie = 0 if en_cours else _sans_epidemie + 1
	# Une semaine sans épidémie (et une semaine au moins après l'arrêté) : on lève.
	if _sans_epidemie >= LEVEE_JOURS:
		for k in mesures.keys():
			if bool(SanteDonnees.MESURES[k].get("temporaire", false)) and jour() - int(mesures[k]) >= LEVEE_JOURS:
				set_mesure(k, false)
	if BudgetCommunal.instance == null:
		var tot := 0.0
		for k in mesures:
			tot += cout_mesure(k)
		if tot > 0.0:
			_payer("Santé publique", tot)


## Contrat BudgetCommunal : euros par mois.
func budget_entretien() -> Dictionary:
	var out := {}
	var tot := 0.0
	for k in mesures:
		tot += cout_mesure(k)
	if tot > 0.0:
		out["Santé publique (mesures sanitaires)"] = tot * 30.0
	return out


func _payer(poste: String, v: float) -> void:
	depenses_mois += v
	if BudgetCommunal.instance != null and is_instance_valid(BudgetCommunal.instance):
		BudgetCommunal.instance.depense(poste, v)
	elif buildings != null and not buildings.unlimited_money:
		buildings.money -= roundi(v)


# --- Satisfaction (contrat Avis) ------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "sante_mesures", "theme": "sante", "f": _avis_mesures, "ville": true}]


func _avis_mesures(_p = null) -> Array:
	var d := 0.0
	var why := []
	for k in mesures:
		var s := float(SanteDonnees.MESURES[k].satisfaction)
		if s != 0.0:
			d += s
			why.append("− %s" % String(SanteDonnees.MESURES[k].nom).to_lower())
	if ev != null and ev.epidemies != null and ev.epidemies.active >= 0:
		var n := ev.epidemies.malades_count()
		var hab := maxi(1, population.persons.size()) if population != null else 1
		var peur := clampf(2.0 + 60.0 * float(n) / float(hab), 2.0, 8.0)
		d -= peur
		why.append("− peur de l'épidémie (%d malades)" % n)
	return [d, why]


# --- Calendrier des grandes épidémies --------------------------------------------------------

func historiques_actifs() -> bool:
	if forcer_historiques >= 0:
		return forcer_historiques == 1
	return historiques and Epoques.actif() and ev != null and ev.catastrophes_on()


func _calendrier(an: int) -> void:
	if ev == null or not historiques_actifs():
		return
	for pd in SanteDonnees.PANDEMIES:
		var k := str(pd.annee)
		var etat := String(pandemies.get(k, ""))
		if etat in ["fait", "passe"]:
			continue
		var y := int(pd.annee)
		if an < y - 1:
			continue
		# Trop tard (partie commencée après, ou saut dans le temps) : l'histoire est passée.
		if an > y + 1 or (etat == "" and an > y):
			pandemies[k] = "passe"
			continue
		if etat == "":
			pandemies[k] = "rumeur"
			ev.news(String(pd.rumeur), Vector3.INF, "epidemie")
			continue
		if an < y:
			continue
		if ev.epidemies.active >= 0:
			continue
		if an > y or ev.rng.randf() < ARRIVEE_JOUR:
			declencher_pandemie(pd)


func declencher_pandemie(pd: Dictionary) -> int:
	var k := str(pd.annee)
	pandemies[k] = "fait"
	var id := ev.epidemies.start(String(pd.maladie), true)
	if id >= 0 and ev.events.has(id):
		ev.events[id].nom = String(pd.nom)
		ev.changed.emit()
	changed.emit()
	return id


## Prochaine grande épidémie au calendrier (panneau) : {} si aucune.
func prochaine_pandemie() -> Dictionary:
	var an := annee()
	for pd in SanteDonnees.PANDEMIES:
		var k := str(pd.annee)
		if String(pandemies.get(k, "")) in ["fait", "passe"]:
			continue
		if int(pd.annee) >= an - 1:
			return pd
	return {}


func _reperes(an: int) -> void:
	for r in SanteDonnees.REPERES:
		var k := str(r.annee)
		if int(r.annee) <= an and not reperes.has(k):
			reperes[k] = true
			if Epoques.actif():
				_annonce("Médecine : %s" % String(r.texte))


func _annonce(t: String) -> void:
	message.emit(t)
	if ev != null:
		ev.news(t, Vector3.INF, "epidemie")


# --- Bilan (panneau, statistiques) ---------------------------------------------------------------

## {hab, eau_potable (part), egouts (part), puits (part), hygiene (moyenne), lits, hospitalises, malades}
func bilan() -> Dictionary:
	var ms := Time.get_ticks_msec()
	if ms - _bilan_ms < 1500 and not _bilan_cache.is_empty():
		return _bilan_cache
	_bilan_ms = ms
	var hab := 0
	var potable := 0
	var eg := 0
	var puits := 0
	var hyg := 0.0
	if population != null:
		for hid in population.households:
			var hh: Dictionary = population.households[hid]
			var n := (hh.m as Array).size()
			if n == 0 or not population.known.has(int(hh.b)):
				continue
			var h := hygiene(int(hh.b))
			hab += n
			if float(h.eau) >= 0.9:
				potable += n
			if float(h.egout) >= 1.0:
				eg += n
			if not bool(h.reseau):
				puits += n
			hyg += float(h.total) * n
	var den := float(maxi(1, hab))
	_bilan_cache = {"hab": hab, "eau_potable": potable / den, "egouts": eg / den, "puits": puits / den, "hygiene": hyg / den,
		"lits": lits(), "hospitalises": hospitalises(), "malades": ev.epidemies.malades_count() if ev != null and ev.epidemies != null else 0}
	return _bilan_cache


## Conseils du moment pour le panneau (texte court).
func conseils() -> Array:
	var out := []
	var b := bilan()
	if int(b.hab) == 0:
		return out
	if float(b.egouts) < 0.5:
		out.append("Moins de la moitié des habitants ont des égouts : le choléra et la typhoïde se régaleraient. Pose un réseau d'égouts (O) et une station d'épuration.")
	if float(b.eau_potable) < 0.5:
		out.append("La plupart boivent l'eau du puits. Un captage ou une usine d'eau et des conduites (O) changent tout.")
	if int(b.lits) == 0:
		out.append("Aucun lit d'hôpital : les cas graves meurent plus souvent. Un hôpital (Construire → Services), ou un lazaret en urgence.")
	for v in SanteDonnees.VACCINS:
		if vaccin_disponible(v) and couverture(v) < 0.5 and not campagnes.has(v) and not obligatoires.has(v):
			out.append("Vaccin contre la %s disponible et peu de vaccinés (%d %%)." % [String(SanteDonnees.VACCINS[v].nom).to_lower(), roundi(couverture(v) * 100.0)])
			break
	return out


# --- Sauvegarde ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var vac := {}
	for v in vaccins:
		var d := {}
		for pid in vaccins[v]:
			d[str(pid)] = int(vaccins[v][pid])
		vac[v] = d
	return {"vaccins": vac, "campagnes": campagnes.duplicate(true), "obligatoires": obligatoires.keys(), "mesures": mesures.duplicate(),
		"historique": historique.duplicate(true), "pandemies": pandemies.duplicate(), "reperes": reperes.keys(),
		"deces": deces.duplicate(), "historiques": historiques}


func from_dict(d: Dictionary) -> void:
	clear()
	for v in (d.get("vaccins", {}) as Dictionary):
		if not SanteDonnees.VACCINS.has(v):
			continue
		var dd := {}
		for k in (d.vaccins[v] as Dictionary):
			dd[int(k)] = int(d.vaccins[v][k])
		vaccins[v] = dd
	for v in (d.get("campagnes", {}) as Dictionary):
		if SanteDonnees.VACCINS.has(v):
			var c: Dictionary = d.campagnes[v]
			campagnes[v] = {"debut": int(c.get("debut", 0)), "doses": int(c.get("doses", 0)), "cout": float(c.get("cout", 0.0))}
	for v in d.get("obligatoires", []):
		if SanteDonnees.VACCINS.has(String(v)):
			obligatoires[String(v)] = true
	for k in (d.get("mesures", {}) as Dictionary):
		if SanteDonnees.MESURES.has(k):
			mesures[k] = int(d.mesures[k])
	historique = (d.get("historique", []) as Array).duplicate(true)
	for k in (d.get("pandemies", {}) as Dictionary):
		pandemies[String(k)] = String(d.pandemies[k])
	for k in d.get("reperes", []):
		reperes[String(k)] = true
	for k in (d.get("deces", {}) as Dictionary):
		deces[String(k)] = int(d.deces[k])
	historiques = bool(d.get("historiques", true))
	_last_day = -1
	changed.emit()
