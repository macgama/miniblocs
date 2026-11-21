class_name ScenarioPartie
extends Node
## Scénario en cours dans la scène Terre (Scenarios.LISTE) :
##   - au départ : date de l'année imposée (hiver, saison des crues…) ;
##   - contraintes tant que le scénario dure : voies routières limitées,
##     bâtiments interdits, pas d'emprunt (refus_voie, refus_batiment,
##     refus_emprunt, appelés par les transports, les bâtiments et le budget) ;
##   - événements à date fixe : crue, subvention, facture, arrivée d'habitants,
##     messages (jour compté depuis le départ, ou depuis la fondation de la
##     première ville) ;
##   - objectifs suivis chaque seconde : gagné quand tous sont remplis en même
##     temps, perdu à la date limite. Le score (Scenarios.calculer_score) entre
##     au Classement si c'est une victoire sans triche (réglages de l'Admin
##     changés en cours de route).
## Après la fin, la partie continue comme une partie normale, sans contrainte.
## Section de sauvegarde « scenario ».

signal changed
signal message(text: String)
signal termine(resultat: Dictionary)

static var instance: ScenarioPartie

## Réglages surveillés : les changer dans l'Admin pendant le scénario = pas de classement.
const REGLAGES_SURVEILLES := ["argent_illimite", "cout_construction", "construction_instantanee",
	"rythme_chantiers", "depart_rapide", "catastrophes", "frequence_catastrophes", "impots", "salaires", "acces_route",
	"fondation", "territoire", "main_oeuvre", "reseaux_obligatoires", "neige_routes"]

var main: Node
var id := ""
var actif := false
var fini := false
var jour0 := -1
var jour_fondation := -1
## Index des événements déjà passés.
var evenements_faits := {}
## Index des objectifs remplis au moins une fois : index -> jour (pour la carte).
var deja := {}
var triche := false
var reglages_depart := {}
var resultat := {}
var _tick := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(m: Node) -> void:
	main = m


func donnees() -> Dictionary:
	return Scenarios.donnees(id)


func en_cours() -> bool:
	return actif and not fini


func clear() -> void:
	id = ""
	actif = false
	fini = false
	jour0 = -1
	jour_fondation = -1
	evenements_faits.clear()
	deja.clear()
	triche = false
	reglages_depart.clear()
	resultat.clear()
	changed.emit()


# --- Départ ----------------------------------------------------------------------------

## Démarre un scénario dans une partie neuve.
func demarrer(sid: String) -> void:
	if not Scenarios.existe(sid):
		return
	clear()
	id = sid
	actif = true
	var s := donnees()
	_imposer_date(String(s.get("date", "")))
	jour0 = _jour_absolu()
	reglages_depart = _reglages_vus()
	message.emit("Scénario « %s » : %s" % [String(s.nom), String(s.accroche)])
	changed.emit()


## Date de départ « MM-JJ » : on avance jusqu'à ce jour de l'année (même heure).
func _imposer_date(mmjj: String) -> void:
	var amb: DayNight = _sys("ambiance")
	if mmjj.length() != 5 or amb == null:
		return
	var off := amb.utc_offset() * 3600.0
	var now_local := amb.unix_time + off
	var d := Time.get_datetime_dict_from_unix_time(int(now_local))
	var cible := {"year": int(d.year), "month": int(mmjj.substr(0, 2)), "day": int(mmjj.substr(3, 2)),
		"hour": int(d.hour), "minute": int(d.minute), "second": 0}
	var t := float(Time.get_unix_time_from_datetime_dict(cible))
	if t < now_local - 86400.0:
		cible.year = int(d.year) + 1
		t = float(Time.get_unix_time_from_datetime_dict(cible))
	var jours := roundi((t - now_local) / 86400.0)
	if jours == 0:
		return
	amb.shift_days(jours)
	# Les chantiers et la vie des bâtiments repartent de la nouvelle date (pas de rattrapage).
	for n in ["vie_batiments", "chantiers"]:
		var o = _sys(n)
		if o != null and "_t_prev" in o:
			o._t_prev = amb.unix_time


func _sys(nom: String) -> Variant:
	if main == null or not (nom in main):
		return null
	return main.get(nom)


func _jour_absolu() -> int:
	var pop: Population = _sys("population")
	return int(pop.now().day) if pop != null else 0


## Jour du scénario (0 au départ).
func jour() -> int:
	return maxi(_jour_absolu() - jour0, 0) if jour0 >= 0 else 0


func jours_max() -> int:
	return int(donnees().get("jours", 100))


func jours_restants() -> int:
	return maxi(jours_max() - jour(), 0)


# --- Suivi -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not en_cours():
		return
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	suivre()


## Un pas de suivi : fondation, événements, triche, objectifs, fin.
func suivre() -> void:
	if not en_cours():
		return
	var cm: Communes = _sys("communes")
	if jour_fondation < 0 and cm != null and not cm.villages.is_empty():
		jour_fondation = jour()
		changed.emit()
	_evenements()
	if not triche and _reglages_vus() != reglages_depart:
		triche = true
		message.emit("Réglages de la partie changés : le scénario continue, mais ce score n'ira pas au classement.")
		changed.emit()
	var tous := true
	var objs: Array = donnees().get("objectifs", [])
	for i in objs.size():
		if rempli(objs[i]):
			if not deja.has(i):
				deja[i] = jour()
				message.emit("Objectif rempli : %s." % String(objs[i].texte))
				changed.emit()
		else:
			tous = false
	if tous and not objs.is_empty():
		terminer(true)
	elif jour() >= jours_max():
		terminer(false)


func _reglages_vus() -> Dictionary:
	var r := ReglagesPartie.actuel
	var out := {}
	for k in REGLAGES_SURVEILLES:
		out[k] = r.get(k)
	var bs: BuildingSystem = _sys("buildings")
	if bs != null:
		out["argent_illimite"] = bs.unlimited_money
	return out


func _evenements() -> void:
	var evs: Array = donnees().get("evenements", [])
	for i in evs.size():
		if evenements_faits.has(i):
			continue
		var e: Dictionary = evs[i]
		var j := int(e.get("jour", 0))
		if bool(e.get("apres_fondation", false)):
			if jour_fondation < 0:
				continue
			j += jour_fondation
		if jour() < j:
			continue
		evenements_faits[i] = jour()
		appliquer_evenement(e)
		changed.emit()


func appliquer_evenement(e: Dictionary) -> void:
	var t := String(e.get("texte", ""))
	var p: Pays = _sys("pays")
	var vid := ville()
	match String(e.get("type", "message")):
		"crue":
			var sa: Saisons = _sys("saisons")
			if sa != null:
				sa.declencher_crue(int(e.get("niveau", 2)))
		"subvention", "facture":
			# Dans la caisse de la ville suivie (une facture la fait baisser).
			var m := int(e.get("montant", 0)) * (1 if String(e.type) == "subvention" else -1)
			if p != null and vid >= 0 and not p.illimite():
				p._poser(vid, p.solde(vid) + m)
				p._noter(vid, "Subvention" if m > 0 else "Facture", m)
				p.changed.emit()
		"vague":
			_vague(int(e.get("niveau", 20)))
	if t != "":
		message.emit(t)


## Arrivée d'habitants : des foyers s'installent dans les logements libres.
func _vague(n: int) -> void:
	var pop: Population = _sys("population")
	if pop == null:
		return
	var venus := 0
	for bid in pop.known:
		if venus >= n:
			break
		if Fondateurs.est_campement(bid):
			continue
		while pop.free_homes(bid) > 0 and venus < n:
			var hid := pop.spawn_household(bid)
			if hid < 0:
				break
			venus += (pop.households[hid].m as Array).size()


# --- Objectifs -------------------------------------------------------------------------

func _obj() -> Objectifs:
	return _sys("objectifs")


## La ville suivie : la plus peuplée (-1 : pas encore de ville).
func ville() -> int:
	var o := _obj()
	return o._meilleure_ville() if o != null else -1


## Valeur actuelle d'un objectif.
func mesure(obj: Dictionary) -> float:
	var o := _obj()
	if o == null:
		return 0.0
	var vid := ville()
	match String(obj.get("type", "")):
		"habitants":
			return float(o.habitants_total())
		"satisfaction":
			return float(o.satisfaction(vid)) if vid >= 0 and o._hab(vid) > 0 else 0.0
		"batiment":
			return float(o._compter_partout(String(obj.get("ref", ""))))
		"lignes":
			return float(o.lignes())
		"caisse":
			var p: Pays = _sys("pays")
			return float(p.solde(vid)) if p != null and vid >= 0 else 0.0
		"sans_dette":
			return dette()
		"palier":
			var best := 0
			for v in o.communes.villages:
				best = maxi(best, o.palier_de(int(v)))
			return float(best)
		"voies":
			return voies_m(String(obj.get("ref", "")))
		"villes":
			return float(o.communes.villages.size())
		"relies":
			return 1.0 if toutes_reliees() else 0.0
		"chomage_max":
			return o.chomage(vid) if vid >= 0 else 100.0
	return 0.0


func rempli(obj: Dictionary) -> bool:
	var v := mesure(obj)
	var c := float(obj.get("cible", 0))
	match String(obj.get("type", "")):
		"sans_dette":
			return v <= c + 0.5
		"chomage_max":
			var o := _obj()
			return v <= c and ville() >= 0 and o != null and o._hab(ville()) > 0
	return v >= c


## Texte du progrès : « 230 / 400 », « 1,2 / 3 km »…
func progres(obj: Dictionary) -> String:
	var v := mesure(obj)
	var c := float(obj.get("cible", 0))
	match String(obj.get("type", "")):
		"sans_dette":
			return "aucune" if v < 0.5 else BuildingSystem.format_money(int(v))
		"caisse":
			return "%s / %s" % [BuildingSystem.format_short(int(v)), BuildingSystem.format_short(int(c))]
		"voies":
			return "%s / %s km" % [_km(v), _km(c)]
		"palier":
			return String(Objectifs.PALIERS[clampi(int(v), 0, Objectifs.PALIERS.size() - 1)].nom)
		"relies":
			return "oui" if v > 0.5 else "pas encore"
		"chomage_max":
			return "%d %%" % roundi(v)
	return "%d / %d" % [int(v), int(c)]


static func _km(m: float) -> String:
	return ("%.1f" % (m / 1000.0)).replace(".", ",")


func dette() -> float:
	var b := BudgetCommunal.instance
	var o := _obj()
	if b == null or o == null:
		return 0.0
	if o.communes.villages.is_empty():
		return b.dette()
	var d := 0.0
	for v in o.communes.villages:
		d += b.dette_de(int(v))
	return d


func voies_m(ref: String) -> float:
	var ts: TransportSystem = _sys("transport")
	if ts == null:
		return 0.0
	var mode: int = {"route": TransportTypes.Mode.ROAD, "rail": TransportTypes.Mode.RAIL,
		"chemin": TransportTypes.Mode.PATH, "eau": TransportTypes.Mode.WATER}.get(ref, -1)
	var m := 0.0
	for e in ts.network.edges.values():
		if TransportTypes.mode_of(String(e.t)) == mode:
			m += float(e.len)
	return m


func toutes_reliees() -> bool:
	var o := _obj()
	if o == null or o.communes.villages.size() < 2:
		return false
	var vs: Array = o.communes.villages.keys()
	for i in range(1, vs.size()):
		if not o.relies(int(vs[0]), int(vs[i])):
			return false
	return true


# --- Contraintes -----------------------------------------------------------------------

func _contraintes() -> Dictionary:
	return donnees().get("contraintes", {}) if en_cours() else {}


## Raison du refus d'un bâtiment, ou "".
static func refus_batiment(type_id: String) -> String:
	if instance == null:
		return ""
	var c := instance._contraintes()
	if (c.get("interdits", []) as Array).has(BuildingCatalog.base_of(type_id)):
		return "Interdit dans ce scénario."
	return ""


## Raison du refus d'une voie (classe, longueur en m), ou "".
static func refus_voie(type_id: String, longueur: float) -> String:
	if instance == null:
		return ""
	var c := instance._contraintes()
	if not c.has("routes") or TransportTypes.mode_of(type_id) != TransportTypes.Mode.ROAD:
		return ""
	var permises: Array = c.routes
	if not permises.has(TransportTypes.resolve(type_id)):
		if permises.is_empty():
			return "Pas de route dans ce scénario : chemins, pistes cyclables, tram et train seulement."
		return "Dans ce scénario, seules ces voies sont permises : %s." % ", ".join(permises.map(
			func(k: String) -> String: return String(TransportTypes.get_type(k).get("name", k)).to_lower()))
	var maxi_m := float(c.get("routes_max_m", -1.0))
	if maxi_m >= 0.0:
		var deja_m := instance.voies_m("route")
		if deja_m + longueur > maxi_m + 1.0:
			return "Plus que %d m de rues permis dans ce scénario (%d m déjà posés sur %d)." % [
				maxi(roundi(maxi_m - deja_m), 0), roundi(deja_m), roundi(maxi_m)]
	return ""


static func refus_emprunt() -> String:
	if instance == null:
		return ""
	if bool(instance._contraintes().get("sans_emprunt", false)):
		return "La banque ne prête plus à la commune dans ce scénario."
	return ""


# --- Fin -------------------------------------------------------------------------------

## Fin du scénario (victoire ou date limite). abandon : pas de score.
func terminer(victoire: bool, abandon := false) -> void:
	if not en_cours():
		return
	fini = true
	var s := donnees()
	var objs: Array = s.get("objectifs", [])
	var n := 0
	for o in objs:
		if rempli(o):
			n += 1
	var nb := 0
	for o in s.get("bonus", []):
		if rempli(o):
			nb += 1
	var vid := ville()
	var ob := _obj()
	var r := {"objectifs": n, "total": objs.size(), "bonus": nb, "jours_restants": jours_restants(),
		"habitants": ob.habitants_total() if ob != null else 0,
		"satisfaction": ob.satisfaction(vid) if ob != null and vid >= 0 and ob._hab(vid) > 0 else 0,
		"dette": dette(), "victoire": victoire and not abandon}
	var sc := Scenarios.calculer_score(id, r)
	r["score"] = int(sc.total)
	r["lignes"] = sc.lignes
	r["medaille"] = Scenarios.medaille(id, int(sc.total), bool(r.victoire))
	r["jours"] = jour()
	r["abandon"] = abandon
	r["triche"] = triche
	r["id"] = id
	r["rang"] = 0
	if bool(r.victoire) and not triche:
		r.rang = Classement.ajouter(id, {"score": r.score, "medaille": r.medaille, "jours": r.jours,
			"habitants": r.habitants, "nom": Classement.nom_joueur()})
	resultat = r
	if abandon:
		message.emit("Scénario abandonné. La ville reste à toi : continue comme tu veux.")
	changed.emit()
	termine.emit(r)


# --- Sauvegarde ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if id == "":
		return {}
	return {"version": 1, "id": id, "actif": actif, "fini": fini, "jour0": jour0, "jour_fondation": jour_fondation,
		"evenements": evenements_faits.keys(), "deja": _cles_str(deja), "triche": triche,
		"reglages_depart": reglages_depart.duplicate(true), "resultat": resultat.duplicate(true)}


static func _cles_str(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty() or not Scenarios.existe(String(d.get("id", ""))):
		return
	id = String(d.id)
	actif = bool(d.get("actif", false))
	fini = bool(d.get("fini", false))
	jour0 = int(d.get("jour0", -1))
	jour_fondation = int(d.get("jour_fondation", -1))
	for i in d.get("evenements", []):
		evenements_faits[int(i)] = true
	var dj: Dictionary = d.get("deja", {})
	for k in dj:
		deja[int(k)] = int(dj[k])
	triche = bool(d.get("triche", false))
	reglages_depart = d.get("reglages_depart", {})
	# Les nombres relus du JSON sont des flottants : on compare avec les réglages lus maintenant.
	if not reglages_depart.is_empty():
		var vus := _reglages_vus()
		for k in vus:
			if reglages_depart.has(k) and typeof(vus[k]) == TYPE_INT:
				reglages_depart[k] = int(reglages_depart[k])
			elif reglages_depart.has(k) and typeof(vus[k]) == TYPE_FLOAT:
				reglages_depart[k] = float(reglages_depart[k])
	resultat = d.get("resultat", {})
	changed.emit()
