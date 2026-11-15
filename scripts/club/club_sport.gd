class_name ClubSport
extends Node
## Club de sport : le joueur en est le président. Un nœud par sport (section) :
## football, basket, handball, hockey, rugby, tennis (voir ClubSports). Chaque
## section a son équipe, son championnat et sa caisse ; ClubSport.instance est
## la section football, ClubSport.sections toutes les sections.
##
## v2 : centre de formation (jeunes du coin, espoirs promus en pro),
## abonnements, habitants supporters (humeur, drapeaux : ClubSupporters).
##
## - Fondation : un stade de la ville (modèle Blender ou terrain de foot du
##   catalogue), un nom, des couleurs. La ville verse une subvention de départ.
##   Le club démarre en Régionale avec des joueurs du coin (des habitants fans
##   de foot, bénévoles) et quelques joueurs indemnisés.
## - Championnat : 12 clubs par division, aller-retour (22 journées) du mois
##   d'août à fin mai, trêve de Noël. Les deux premiers montent, les deux
##   derniers descendent. Quatre divisions : Régionale → Nationale →
##   Deuxième Ligue → Première Ligue.
## - Matchs : la force de l'équipe vient du onze aligné (formation, notes,
##   forme, fatigue) et de la tactique. Les matchs à domicile se voient au
##   stade (Evenements / Matchs : joueurs aux couleurs du club, foule, score).
## - Argent : le club a sa propre caisse. Recettes : billets (prix choisi),
##   buvette, boutique, sponsors, droits télé, primes de classement, ventes de
##   joueurs. Dépenses : salaires, staff, transferts, location du stade (versée
##   à la ville du stade). La ville peut subventionner le club.
## - Effectif : âge, poste, note, potentiel, forme, fatigue, blessures,
##   contrats ; progression selon l'entraînement ; marché des transferts
##   renouvelé chaque lundi.

signal changed
signal message(text: String)
## Fin d'un match du club : {sport, club, adv, dom, pour, contre, issue, buteurs, affluence, texte} (le journal l'écoute).
signal resultat(r: Dictionary)

static var instance: ClubSport
## sport → section (ClubSport).
static var sections: Dictionary = {}

const STEP := 3600.0
const SUBVENTION_DEPART := 150_000.0
const MAX_JOUEURS := 30
const MIN_JOUEURS := 16
const BUVETTE := 3.5
const BOUTIQUE := 1.2
const LOYER_PART := 0.12
const LOYER_MIN := 300.0
const DUREE_MATCH := 2.0 # h, du coup d'envoi au résultat

## Le sport de cette section (à fixer avant add_child).
var sport := "football"
var buildings: BuildingSystem
var population: Population
var ambiance: DayNight

## Vide tant que le club n'est pas fondé.
var club: Dictionary = {}
## id → joueur du club.
var joueurs: Dictionary = {}
## id → jeune du centre de formation (même fiche qu'un joueur, "espoir": true).
var espoirs: Dictionary = {}
## Joueurs proposés sur le marché des transferts.
var marche: Array = []
## Championnat de la saison : {saison, division, clubs: {nom: fiche}, journees: [...], fini}.
var ligue: Dictionary = {}
## Dernières nouvelles du club (les plus récentes d'abord).
var journal: Array = []
## Ce que disent les supporters : clé → nombre.
var pensees: Dictionary = {}
var next_id := 1
var clock := -1.0
var last_unix := -1.0
var last_day := -1
var rng := RandomNumberGenerator.new()
## Pour les tests : nombre d'habitants fans imposé (−1 = la vraie population).
var fans_force := -1
var _supporters_cache := -1


func _init() -> void:
	rng.seed = 4_242_424


func _enter_tree() -> void:
	if sport == "football":
		instance = self
	sections[sport] = self
	add_to_group("avis_sources")


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if sections.get(sport, null) == self:
		sections.erase(sport)


## La section d'un sport (null si absente).
static func section(s: String) -> ClubSport:
	var c = sections.get(s, null)
	if c == null or not is_instance_valid(c):
		return null
	return c


## Le bâtiment sert-il de stade à un club du joueur (tous sports) ?
static func lieu_pris(bid: int, sauf := "") -> String:
	for s in sections:
		var c := section(s)
		if c != null and s != sauf and c.fonde() and int(c.club.get("stade", -1)) == bid:
			return String(s)
	return ""


func sp() -> Dictionary:
	return ClubSports.sport(sport)


func _div(i: int) -> Dictionary:
	return ClubSports.division(sport, i)


func _adverses() -> Array:
	return ClubSports.adverses(sport)


func max_joueurs() -> int:
	return int(sp().max)


func min_joueurs() -> int:
	return int(sp().min)


func setup(b: BuildingSystem, p: Population, a: DayNight) -> void:
	buildings = b
	population = p
	ambiance = a
	if buildings != null:
		buildings.removed.connect(func(bid: int) -> void:
			if fonde() and int(club.stade) == bid:
				club.stade = -1
				_news("Le stade du club a été démoli ! Le club cherche un nouveau terrain (menu Club → Club).")
				changed.emit())


func clear() -> void:
	club = {}
	joueurs.clear()
	marche.clear()
	ligue = {}
	journal.clear()
	pensees.clear()
	espoirs.clear()
	next_id = 1
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	changed.emit()


func fonde() -> bool:
	return not club.is_empty()


# --- Temps ------------------------------------------------------------------------------------

func _now(t: float) -> Dictionary:
	var off := ambiance.utc_offset() if ambiance != null else 0.0
	var local := t + off * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	return {"h": fposmod(local, 86400.0) / 3600.0, "wd": int(dt.weekday), "month": int(dt.month), "day": int(floorf(local / 86400.0)),
		"mday": int(dt.day), "year": int(dt.year)}


func date_of(day: int) -> Dictionary:
	var dt := Time.get_datetime_dict_from_unix_time(day * 86400 + 43200)
	return {"wd": int(dt.weekday), "month": int(dt.month), "mday": int(dt.day), "day": day, "year": int(dt.year)}


static func day_of(year: int, month: int, mday: int) -> int:
	var u := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": mday, "hour": 12, "minute": 0, "second": 0})
	return int(floorf(float(u) / 86400.0))


func today() -> int:
	if last_day >= 0:
		return last_day
	var t := ambiance.unix_time if ambiance != null else clock
	return int(_now(maxf(t, 0.0)).day)


## Saison « 2026-2027 » d'un jour (elle commence en juillet).
static func saison_de(year: int, month: int) -> String:
	var y := year if month >= 7 else year - 1
	return "%d-%d" % [y, y + 1]


func _process(_delta: float) -> void:
	if ambiance == null:
		return
	var t := ambiance.unix_time
	if last_unix < 0.0:
		last_unix = t
		return
	var dt := clampf(t - last_unix, 0.0, 86400.0 * 2.0)
	last_unix = t
	if dt > 0.0:
		advance(dt)


func advance(dt: float) -> void:
	var end_t := (ambiance.unix_time if ambiance != null else clock + dt)
	if clock < 0.0 or absf(end_t - dt - clock) > 86400.0 * 3.0:
		clock = end_t - dt
		# Retour en arrière dans le temps (partie rechargée, date changée) : on repart de là.
		if last_day >= 0 and int(_now(clock).day) < last_day:
			last_day = -1
	if last_day < 0:
		last_day = int(_now(clock).day)
	var n := 0
	while clock + STEP <= end_t + 0.001 and n < 96:
		clock += STEP
		n += 1
		step()
	if clock < end_t - 86400.0:
		clock = end_t


func step() -> void:
	var now := _now(clock)
	if int(now.day) > last_day:
		last_day = int(now.day)
		new_day(now)
	if not fonde():
		return
	var j := journee_du_jour(int(now.day))
	if not j.is_empty() and not bool(j.joue) and float(now.h) >= float(j.h) + duree_match():
		jouer_journee(j)


## Heures entre le coup d'envoi et le résultat.
func duree_match() -> float:
	if sport == "football":
		return DUREE_MATCH
	return ClubSports.duree(sport) / 3600.0 + 0.2


func new_day(now: Dictionary) -> void:
	if not fonde():
		return
	var s := saison_de(int(now.year), int(now.month))
	if String(ligue.get("saison", "")) != s:
		nouvelle_saison(int(now.day))
	club.humeur = float(club.get("humeur", 0.0)) * 0.97
	_supporters_cache = -1
	var tr: Array = ClubDonnees.ENTRAINEMENTS[String(club.entrainement)]
	for id in joueurs:
		var p: Dictionary = joueurs[id]
		p.fatigue = maxf(float(p.fatigue) - float(tr[1]), 0.0)
		if int(p.blesse) > 0:
			p.blesse = int(p.blesse) - 1
			if int(p.blesse) == 0:
				_news("%s est rétabli et reprend l'entraînement." % nom_joueur(p))
		# La forme bouge un peu chaque jour, elle revient vers la moyenne.
		p.forme = clampf(float(p.forme) + rng.randf_range(-0.03, 0.03) + (0.6 - float(p.forme)) * 0.03, 0.2, 1.0)
	if int(now.wd) == 1:
		_semaine()
	if int(now.mday) == 1:
		_mois(now)
	var j := journee_du_jour(int(now.day))
	if not j.is_empty() and not bool(j.get("prepare", false)):
		_preparer(j)
	changed.emit()


# --- Fondation --------------------------------------------------------------------------------

func _lieu() -> String:
	var n := GameStart.place_name.strip_edges()
	if n == "":
		return "MiniBlocs"
	return n.split(",")[0].strip_edges()


func nom_propose() -> String:
	return ClubSports.nom_propose(sport, _lieu())


## Subvention de départ de la ville (moins pour les petits sports).
func subvention_depart() -> float:
	if sport == "football":
		return SUBVENTION_DEPART
	return roundf(SUBVENTION_DEPART * clampf(float(sp().eco) * 1.5, 0.2, 1.0) / 1000.0) * 1000.0


## Stades de la ville où le club peut jouer : [{bid, nom, places}].
func stades_possibles() -> Array:
	var out := []
	if buildings == null:
		return out
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if b.get("chantier", false) or not ClubSports.accueille(sport, String(b.t)):
			continue
		out.append({"bid": int(bid), "nom": String(BuildingCatalog.get_type(String(b.t)).get("name", b.t)), "places": ClubSports.places_lieu(String(b.t))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.places) > int(b.places))
	return out


## Fonde le club. Renvoie "" ou la raison du refus.
func fonder(nom: String, couleurs: int, stade: int) -> String:
	if fonde():
		return "Le club existe déjà."
	nom = nom.strip_edges()
	if nom == "":
		return "Donne un nom au club."
	var ok := false
	for s in stades_possibles():
		ok = ok or int(s.bid) == stade
	if not ok:
		return "Il faut %s dans la ville (chantier terminé)." % String(sp().lieu)
	var now := _now(_temps())
	last_day = int(now.day)
	club = {"nom": nom, "couleurs": ClubDonnees.COULEURS[posmod(couleurs, ClubDonnees.COULEURS.size())].duplicate(),
		"stade": stade, "fonde": int(now.day), "caisse": 0.0, "division": 0, "reputation": 10.0, "supporters": 120.0,
		"prix": _div(0).prix, "formation": String(sp().formation), "tactique": "equilibree", "entrainement": "normal",
		"sport": sport, "academie": 0, "humeur": 0.0, "abo": 0, "abo_prix": 0.0,
		"sponsor": ClubDonnees.SPONSORS[posmod(hash(nom), ClubDonnees.SPONSORS.size())],
		"finances": {}, "finances_prec": {}, "historique": [], "palmares": [], "serie": [], "auto_prix": false}
	_effectif_depart()
	_renouveler_marche()
	nouvelle_saison(int(now.day))
	_verser_ville("Subvention de départ au club de sport", -subvention_depart())
	_flux("Subvention de départ de la ville", subvention_depart())
	_news("Le club %s est fondé%s ! Il jouera en %s au %s." % [nom, "" if sport == "football" else " (%s)" % String(sp().nom).to_lower(), _div(0).nom, nom_stade()])
	changed.emit()
	return ""


func _temps() -> float:
	if ambiance != null:
		return ambiance.unix_time
	return maxf(clock, 0.0)


func nom_stade() -> String:
	if not fonde() or buildings == null or not buildings.buildings.has(int(club.stade)):
		return "stade (aucun)"
	return String(BuildingCatalog.get_type(String(buildings.buildings[int(club.stade)].t)).get("name", "stade")).split(" (")[0].to_lower()


func places() -> int:
	if not fonde() or buildings == null or not buildings.buildings.has(int(club.stade)):
		return 0
	return ClubSports.places_lieu(String(buildings.buildings[int(club.stade)].t))


func changer_stade(bid: int) -> String:
	for s in stades_possibles():
		if int(s.bid) == bid:
			club.stade = bid
			_news("Le club joue désormais au %s (%s places)." % [nom_stade(), Stades._milliers(places())])
			changed.emit()
			return ""
	return "Ce stade n'est pas disponible."


func renommer(n: String) -> void:
	n = n.strip_edges()
	if n == "" or not fonde() or n == String(club.nom):
		return
	var old := String(club.nom)
	club.nom = n
	if ligue.has("clubs") and (ligue.clubs as Dictionary).has(old):
		var c: Dictionary = ligue.clubs[old]
		ligue.clubs.erase(old)
		c.nom = n
		ligue.clubs[n] = c
		for j in ligue.journees:
			for m in j.matchs:
				for i in 2:
					if String(m[i]) == old:
						m[i] = n
	changed.emit()


func set_couleurs(i: int) -> void:
	if fonde():
		club.couleurs = ClubDonnees.COULEURS[posmod(i, ClubDonnees.COULEURS.size())].duplicate()
		if ligue.has("clubs") and (ligue.clubs as Dictionary).has(String(club.nom)):
			ligue.clubs[String(club.nom)].couleurs = club.couleurs
		changed.emit()


# --- Joueurs ----------------------------------------------------------------------------------

func _region() -> String:
	return Prenoms.region_for_place(GameStart.lat, GameStart.lon)


func _nouveau_joueur(poste: String, niveau: float, age: float, spread := 6.0) -> Dictionary:
	var reg := _region()
	if rng.randf() < 0.3:
		reg = ["europe", "mediterranee", "afrique", "ameriques", "moyen_orient"][rng.randi() % 5]
	var note := clampf(niveau + rng.randfn(0.0, spread * 0.6), 30.0, 94.0)
	var pot := note
	if age < 24.0:
		pot = clampf(note + rng.randf_range(2.0, 16.0) * (24.0 - age) / 6.0, note, 96.0)
	else:
		pot = note + rng.randf_range(0.0, 3.0)
	var id := next_id
	next_id += 1
	return {"id": id, "prenom": Prenoms.first_name(rng, reg, "H"), "nom": Prenoms.family_name(rng, reg), "poste": poste,
		"ne": today() - int(age * 365.25), "note": note, "pot": pot, "forme": rng.randf_range(0.5, 0.8), "fatigue": 0.0,
		"blesse": 0, "salaire": ClubSports.salaire(sport, note), "contrat": 0, "buts": 0, "matchs": 0, "buts_saison": 0,
		"matchs_saison": 0, "pid": -1, "repos": false, "benevole": false}


func age(p: Dictionary) -> float:
	return float(today() - int(p.ne)) / 365.25


static func nom_joueur(p: Dictionary) -> String:
	return "%s %s" % [String(p.prenom), String(p.nom)]


func _annee_saison() -> int:
	var d := date_of(today())
	return int(d.year) if int(d.month) >= 7 else int(d.year) - 1


func _effectif_depart() -> void:
	var niveau := float(_div(0).niveau)
	var postes: Array = sp().effectif
	var locaux := _habitants_sportifs()
	var fin := _annee_saison() + 1
	for i in postes.size():
		var poste: String = postes[i]
		var p: Dictionary
		if i % 2 == 1 and not locaux.is_empty():
			# Un habitant du coin, bénévole : un peu moins fort, mais il ne coûte rien.
			var h: Dictionary = locaux.pop_back()
			p = _nouveau_joueur(poste, niveau - 4.0, float(h.age))
			p.prenom = String(h.p.p)
			p.nom = String(h.p.n)
			p.pid = int(h.p.id)
			p.benevole = true
			p.salaire = 0.0
		else:
			p = _nouveau_joueur(poste, niveau, rng.randf_range(18.0, 33.0))
		p.contrat = fin + rng.randi_range(0, 2)
		joueurs[int(p.id)] = p


## Habitants de 17 à 34 ans qui pratiquent le sport du club (pour l'équipe amateur).
func _habitants_sportifs(age_min := 17.0, age_max := 34.0) -> Array:
	var out := []
	if population == null:
		return out
	var pris := {}
	for c in [joueurs, espoirs]:
		for id in c:
			if int(c[id].get("pid", -1)) >= 0:
				pris[int(c[id].pid)] = true
	var hob := ClubSports.hobby(sport)
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		if String(p.get("s", "")) != "H" or not (p.get("hob", []) as Array).has(hob) or pris.has(int(pid)):
			continue
		var a := population.age_of(p)
		if a >= age_min and a <= age_max:
			out.append({"p": p, "age": a})
	out.shuffle()
	return out


func liste_joueurs(poste := "") -> Array:
	var out := []
	for id in joueurs:
		if poste == "" or String(joueurs[id].poste) == poste:
			out.append(joueurs[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia := (sp().ordre as Array).find(String(a.poste))
		var ib := (sp().ordre as Array).find(String(b.poste))
		if ia != ib:
			return ia < ib
		return float(a.note) > float(b.note))
	return out


## Note effective du jour (forme, fatigue).
static func note_eff(p: Dictionary) -> float:
	return float(p.note) * (0.88 + 0.12 * float(p.forme)) * (1.0 - 0.22 * float(p.fatigue))


func disponible(p: Dictionary) -> bool:
	return int(p.blesse) <= 0 and not bool(p.repos)


## Le onze aligné : [{id, poste (joué), hors_poste}], gardien d'abord.
func onze() -> Array:
	var besoin := ClubSports.besoins(sport, String(club.get("formation", sp().formation)))
	var ordre: Array = sp().ordre
	var libres := []
	for id in joueurs:
		if disponible(joueurs[id]):
			libres.append(joueurs[id])
	libres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return note_eff(a) > note_eff(b))
	var out := []
	var pris := {}
	for poste in ordre:
		var n := int(besoin[poste])
		for p in libres:
			if n <= 0:
				break
			if String(p.poste) == poste and not pris.has(int(p.id)):
				out.append({"id": int(p.id), "poste": poste, "hors_poste": false})
				pris[int(p.id)] = true
				n -= 1
		besoin[poste] = n
	# Postes vides : les meilleurs restants, hors de leur poste.
	for poste in ordre:
		var n := int(besoin[poste])
		for p in libres:
			if n <= 0:
				break
			if not pris.has(int(p.id)):
				out.append({"id": int(p.id), "poste": poste, "hors_poste": true})
				pris[int(p.id)] = true
				n -= 1
	return out


func titulaires() -> Dictionary:
	var out := {}
	for o in onze():
		out[int(o.id)] = true
	return out


## Force de l'équipe (même échelle que les notes), et le détail par ligne.
func force_equipe() -> Dictionary:
	var xi := onze()
	var lignes := {}
	for k in sp().ordre:
		lignes[k] = []
	for o in xi:
		var p: Dictionary = joueurs[int(o.id)]
		var v := note_eff(p) * (0.75 if bool(o.hors_poste) else 1.0)
		(lignes[String(o.poste)] as Array).append(v)
	var moy := {}
	var total := 0.0
	var poids: Dictionary = sp().poids
	for k in lignes:
		var a: Array = lignes[k]
		var s := 0.0
		for v in a:
			s += float(v)
		moy[k] = s / a.size() if not a.is_empty() else 25.0
		total += float(moy[k]) * float(poids.get(k, 0.0))
	# Il manque des titulaires : grosse pénalité.
	var need := ClubSports.titulaires(sport, String(club.get("formation", sp().formation)))
	total *= clampf(float(xi.size()) / float(maxi(need, 1)), 0.3, 1.0)
	var out := {"force": total, "n": xi.size()}
	out.merge(moy)
	return out


func set_formation(f: String) -> void:
	if (sp().formations as Dictionary).has(f):
		club.formation = f
		changed.emit()


func set_tactique(t: String) -> void:
	if ClubDonnees.TACTIQUES.has(t):
		club.tactique = t
		changed.emit()


func set_entrainement(t: String) -> void:
	if ClubDonnees.ENTRAINEMENTS.has(t):
		club.entrainement = t
		changed.emit()


func set_repos(id: int, on: bool) -> void:
	if joueurs.has(id):
		joueurs[id].repos = on
		changed.emit()


func set_prix(prix: float) -> void:
	if fonde():
		club.prix = clampf(roundf(prix), 0.0, 250.0)
		changed.emit()


# --- Transferts -------------------------------------------------------------------------------

func _renouveler_marche() -> void:
	marche.clear()
	var niv := float(_div(int(club.get("division", 0))).niveau)
	var postes: Array = sp().marche
	for i in postes.size():
		var a := rng.randf_range(17.5, 34.0)
		var p := _nouveau_joueur(postes[i], niv + rng.randf_range(-6.0, 9.0), a, 4.0)
		var libre := rng.randf() < 0.3 or a > 31.0
		p.libre = libre
		p.prix = 0.0 if libre else roundf(ClubSports.valeur(sport, float(p.note), a, float(p.pot)) * rng.randf_range(0.9, 1.3) / 1000.0) * 1000.0
		p.salaire = roundf(ClubSports.salaire(sport, float(p.note)) * rng.randf_range(1.0, 1.2) / 10.0) * 10.0
		p.club_origine = "" if libre else String(_adverses()[rng.randi() % _adverses().size()])
		marche.append(p)


## Le joueur accepte-t-il de venir ? "" ou la raison.
func peut_acheter(p: Dictionary) -> String:
	if not fonde():
		return "Fonde d'abord le club."
	if joueurs.size() >= max_joueurs():
		return "Effectif complet (%d joueurs)." % max_joueurs()
	var niv := float(_div(int(club.division)).niveau)
	if float(p.note) > niv + 12.0 + float(club.reputation) * 0.08:
		return "Il trouve le club trop modeste pour lui."
	if float(club.caisse) < float(p.prix) + float(p.salaire) * 2.0:
		return "Pas assez d'argent dans la caisse du club."
	return ""


func acheter(id: int) -> String:
	for i in marche.size():
		var p: Dictionary = marche[i]
		if int(p.id) != id:
			continue
		var why := peut_acheter(p)
		if why != "":
			return why
		marche.remove_at(i)
		if float(p.prix) > 0.0:
			_flux("Transferts (achats)", -float(p.prix))
		var prime := float(p.salaire) * 2.0
		_flux("Primes à la signature", -prime)
		p.contrat = _annee_saison() + 1 + rng.randi_range(1, 3)
		for k in ["libre", "prix", "club_origine"]:
			p.erase(k)
		joueurs[int(p.id)] = p
		_news("%s signe au club (%s, %d ans, note %d)." % [nom_joueur(p), String(sp().postes[p.poste]).to_lower(), int(age(p)), int(p.note)])
		changed.emit()
		return ""
	return "Ce joueur n'est plus sur le marché."


func valeur_de(p: Dictionary) -> float:
	return ClubSports.valeur(sport, float(p.note), age(p), float(p.pot))


func vendre(id: int) -> String:
	if not joueurs.has(id):
		return "Joueur inconnu."
	var p: Dictionary = joueurs[id]
	if bool(p.benevole) and valeur_de(p) < 5000.0:
		return liberer(id)
	var prix := roundf(valeur_de(p) * rng.randf_range(0.8, 1.05) / 1000.0) * 1000.0
	var acheteur: String = _adverses()[rng.randi() % _adverses().size()]
	joueurs.erase(id)
	_flux("Transferts (ventes)", prix)
	_news("%s part au %s pour %s." % [nom_joueur(p), acheteur, BuildingSystem.format_money(int(prix))])
	changed.emit()
	return ""


func liberer(id: int) -> String:
	if not joueurs.has(id):
		return "Joueur inconnu."
	var p: Dictionary = joueurs[id]
	var indem := float(p.salaire) * 3.0
	joueurs.erase(id)
	if indem > 0.0:
		_flux("Indemnités de départ", -indem)
	_news("%s quitte le club%s." % [nom_joueur(p), "" if indem <= 0.0 else " (indemnité de %s)" % BuildingSystem.format_money(int(indem))])
	changed.emit()
	return ""


## Prolonger : +2 saisons, salaire revu à sa note du moment (+10 %).
func prolonger(id: int) -> String:
	if not joueurs.has(id):
		return "Joueur inconnu."
	var p: Dictionary = joueurs[id]
	if age(p) >= 35.0:
		return "À %d ans, il préfère finir sa carrière." % int(age(p))
	p.contrat = maxi(int(p.contrat), _annee_saison() + 1) + 2
	if not bool(p.benevole):
		p.salaire = maxf(float(p.salaire), roundf(ClubSports.salaire(sport, float(p.note)) * 1.1 / 10.0) * 10.0)
	changed.emit()
	return ""


func masse_salariale() -> float:
	var s := 0.0
	for id in joueurs:
		s += float(joueurs[id].salaire)
	return s


func staff() -> float:
	if sport == "football":
		return 1500.0 + masse_salariale() * 0.15 + float(club.get("division", 0)) * 8000.0
	return 600.0 + masse_salariale() * 0.15 + float(club.get("division", 0)) * 8000.0 * float(sp().eco)


func _semaine() -> void:
	_renouveler_marche()
	var tr: Array = ClubDonnees.ENTRAINEMENTS[String(club.entrainement)]
	for id in joueurs:
		var p: Dictionary = joueurs[id]
		var a := age(p)
		var g := 0.0
		if a < 21.0:
			g = 0.35
		elif a < 24.0:
			g = 0.22
		elif a < 28.0:
			g = 0.08
		elif a > 31.0:
			g = -0.06 * (a - 30.0)
		if g > 0.0:
			g *= float(tr[0]) * clampf((float(p.pot) - float(p.note)) / 6.0, 0.0, 1.0)
		p.note = clampf(float(p.note) + g, 25.0, 96.0)
		# Blessures à l'entraînement.
		if int(p.blesse) <= 0 and rng.randf() < 0.006 * float(tr[2]):
			p.blesse = rng.randi_range(3, 14)
			_news("%s se blesse à l'entraînement (%d jours)." % [nom_joueur(p), int(p.blesse)])
	_semaine_espoirs(float(tr[0]))
	_completer_effectif()


## Trop peu de joueurs : les meilleurs espoirs passent pro, sinon des jeunes
## du coin complètent.
func _completer_effectif() -> void:
	while joueurs.size() < min_joueurs():
		var best := -1
		for id in espoirs:
			if best < 0 or float(espoirs[id].note) > float(espoirs[best].note):
				best = int(id)
		if best >= 0:
			promouvoir(best)
			continue
		var postes: Array = sp().jeunes
		var p := _nouveau_joueur(postes[joueurs.size() % postes.size()], float(_div(int(club.division)).niveau) - 8.0, rng.randf_range(17.0, 19.5))
		p.contrat = _annee_saison() + 2
		joueurs[int(p.id)] = p
		_news("Un jeune du centre de formation, %s, rejoint l'équipe." % nom_joueur(p))


# --- Centre de formation ----------------------------------------------------------------------

func academie() -> Dictionary:
	return ClubSports.ACADEMIE[clampi(int(club.get("academie", 0)), 0, ClubSports.ACADEMIE.size() - 1)]


## Coût mensuel d'un niveau (selon le sport).
func cout_academie(niveau: int) -> float:
	var a: Dictionary = ClubSports.ACADEMIE[clampi(niveau, 0, ClubSports.ACADEMIE.size() - 1)]
	return roundf(float(a.cout) * clampf(float(sp().eco), 0.25, 1.0) / 100.0) * 100.0


## Un centre de formation est-il bâti (et terminé) dans la ville ?
func centre_bati() -> bool:
	if buildings == null:
		return false
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if not b.get("chantier", false) and BuildingCatalog.base_of(String(b.t)) == "centre_formation":
			return true
	return false


func set_academie(niveau: int) -> String:
	if not fonde():
		return "Fonde d'abord le club."
	niveau = clampi(niveau, 0, ClubSports.ACADEMIE.size() - 1)
	var a: Dictionary = ClubSports.ACADEMIE[niveau]
	if bool(a.bati) and not centre_bati():
		return "Il faut d'abord bâtir un centre de formation dans la ville (Construire → Sport)."
	var avant := int(club.get("academie", 0))
	club.academie = niveau
	if niveau > avant:
		_news("%s : %s ouvert (%s par mois)." % [String(club.nom), String(a.nom).to_lower(), BuildingSystem.format_money(int(cout_academie(niveau)))])
		if espoirs.is_empty():
			_recruter_espoirs()
	elif niveau < avant:
		_news("%s réduit son centre de formation : %s." % [String(club.nom), String(a.nom).to_lower()])
	changed.emit()
	return ""


## Nouvelle promotion de jeunes (début de saison) : d'abord les enfants de la
## ville qui pratiquent le sport, puis des jeunes repérés ailleurs.
func _recruter_espoirs() -> void:
	var a := academie()
	var n := int(a.n)
	if n <= 0:
		return
	var niveau := float(_div(int(club.division)).niveau)
	var locaux := _habitants_sportifs(14.0, 17.5)
	var postes: Array = sp().jeunes
	var noms := []
	for i in n:
		if espoirs.size() >= 12:
			break
		var poste: String = postes[(espoirs.size() + i) % postes.size()]
		var p: Dictionary
		if not locaux.is_empty() and (i < n - 1 or rng.randf() < 0.5):
			var h: Dictionary = locaux.pop_back()
			p = _nouveau_joueur(poste, niveau - 20.0, float(h.age), 4.0)
			p.prenom = String(h.p.p)
			p.nom = String(h.p.n)
			p.pid = int(h.p.id)
			p.pot = clampf(float(p.note) + 14.0 + float(a.pot) + rng.randf_range(0.0, 12.0), float(p.note), 94.0)
		else:
			p = _nouveau_joueur(poste, niveau - 18.0, rng.randf_range(15.0, 17.0), 4.0)
			p.pot = clampf(float(p.note) + 14.0 + float(a.pot) + rng.randf_range(0.0, 14.0), float(p.note), 96.0)
		p.espoir = true
		p.salaire = 0.0
		p.contrat = 0
		espoirs[int(p.id)] = p
		noms.append("%s%s" % [nom_joueur(p), " (de la ville)" if int(p.pid) >= 0 else ""])
	if not noms.is_empty():
		_news("Centre de formation de %s : %d jeunes arrivent (%s)." % [String(club.nom), noms.size(), ", ".join(noms)])


func _semaine_espoirs(entrainement: float) -> void:
	var bonus := 1.0 + float(club.get("academie", 0)) * 0.2 + (0.2 if centre_bati() else 0.0)
	for id in espoirs:
		var p: Dictionary = espoirs[id]
		var g := 0.42 * entrainement * bonus * clampf((float(p.pot) - float(p.note)) / 8.0, 0.0, 1.0)
		p.note = clampf(float(p.note) + g, 20.0, 96.0)
		p.forme = clampf(float(p.forme) + rng.randf_range(-0.04, 0.05), 0.3, 1.0)


func liste_espoirs() -> Array:
	var out: Array = espoirs.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.pot) > float(b.pot))
	return out


## Le jeune signe son premier contrat pro (trois saisons, petit salaire).
func promouvoir(id: int) -> String:
	if not espoirs.has(id):
		return "Ce jeune n'est plus au centre."
	if joueurs.size() >= max_joueurs():
		return "Effectif complet (%d joueurs)." % max_joueurs()
	var p: Dictionary = espoirs[id]
	espoirs.erase(id)
	p.erase("espoir")
	p.forme_club = true
	p.contrat = _annee_saison() + 3
	p.salaire = roundf(ClubSports.salaire(sport, float(p.note)) * 0.6 / 10.0) * 10.0
	joueurs[id] = p
	_news("%s, formé au club, signe son premier contrat pro (%d ans, note %d, potentiel %d)." % [nom_joueur(p), int(age(p)), int(p.note), int(p.pot)])
	if int(p.pid) >= 0:
		_penser("habitant_pro", [String(p.prenom)], 3)
		club.humeur = clampf(float(club.get("humeur", 0.0)) + 0.15, -1.0, 1.0)
	changed.emit()
	return ""


func liberer_espoir(id: int) -> String:
	if not espoirs.has(id):
		return "Ce jeune n'est plus au centre."
	var p: Dictionary = espoirs[id]
	espoirs.erase(id)
	_news("%s quitte le centre de formation." % nom_joueur(p))
	changed.emit()
	return ""


## Fin de saison : les espoirs de 19 ans et plus doivent passer pro ou partir.
func _fin_saison_espoirs() -> void:
	for id in espoirs.keys():
		var p: Dictionary = espoirs[id]
		if age(p) >= 19.0:
			if float(p.note) >= float(_div(int(club.division)).niveau) - 6.0 and joueurs.size() < max_joueurs():
				promouvoir(int(id))
			else:
				espoirs.erase(id)
				_news("%s (%d ans) quitte le centre de formation sans contrat pro." % [nom_joueur(p), int(age(p))])


func _mois(now: Dictionary) -> void:
	_flux("Salaires des joueurs", -masse_salariale())
	_flux("Staff et frais du club", -staff())
	if int(club.get("academie", 0)) > 0:
		_flux("Centre de formation", -cout_academie(int(club.academie)))
	var m := int(now.month)
	# Sponsors et droits télé : versés d'août à mai (dix mensualités).
	if m >= 8 or m <= 5:
		var div := _div(int(club.division))
		var rep := 0.6 + float(club.reputation) / 100.0 * 0.8
		_flux("Sponsors (%s)" % String(club.sponsor), float(div.sponsors) * rep / 10.0)
		if float(div.tv) > 0.0:
			_flux("Droits télé", float(div.tv) / 10.0)
		_flux("Boutique et produits dérivés", float(club.supporters) * 0.4)
	if float(club.caisse) < 0.0:
		_news("Attention : la caisse du club est dans le rouge (%s). Vends des joueurs ou demande une subvention à la ville." % BuildingSystem.format_money(int(club.caisse)))


# --- Championnat ------------------------------------------------------------------------------

## Clubs adverses inventés d'une division.
func _adversaires(div: int, garder: Array) -> Dictionary:
	var out := {}
	var niv := float(_div(div).niveau)
	var pool := _adverses().duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = hash([String(club.nom), div, String(ligue.get("saison", ""))])
	for g in garder:
		pool.erase(g)
	var noms := garder.duplicate()
	while noms.size() < int(sp().nb_clubs) - 1 and not pool.is_empty():
		var k := r.randi() % pool.size()
		noms.append(pool[k])
		pool.remove_at(k)
	for i in noms.size():
		var n: String = noms[i]
		out[n] = _fiche(n, ClubDonnees.COULEURS[posmod(hash(n), ClubDonnees.COULEURS.size())], niv + r.randf_range(-6.0, 6.0), false)
	return out


static func _fiche(nom: String, couleurs: Array, force: float, moi: bool) -> Dictionary:
	return {"nom": nom, "couleurs": couleurs, "force": force, "moi": moi, "pts": 0, "j": 0, "g": 0, "n": 0, "p": 0, "bp": 0, "bc": 0}


func nouvelle_saison(day: int) -> void:
	var d := date_of(day)
	var s := saison_de(int(d.year), int(d.month))
	if not ligue.is_empty() and String(ligue.saison) != s:
		_fin_saison()
	var div := int(club.division)
	var garder := []
	if ligue.has("clubs") and int(ligue.get("division", -1)) == div:
		for n in ligue.clubs:
			if not bool(ligue.clubs[n].moi):
				garder.append(n)
	elif ligue.has("clubs"):
		# Montée ou descente : on retrouve quelques clubs de l'ancienne division.
		var k := 0
		for c in ligue.get("restent", []):
			if k < 2:
				garder.append(c)
				k += 1
	ligue = {"saison": s, "division": div, "clubs": {}, "journees": [], "fini": false}
	var clubs := _adversaires(div, garder.slice(0, int(sp().nb_clubs) - 1))
	clubs[String(club.nom)] = _fiche(String(club.nom), club.couleurs, 0.0, true)
	ligue.clubs = clubs
	for id in joueurs:
		joueurs[id].buts_saison = 0
		joueurs[id].matchs_saison = 0
	club.finances_prec = club.get("finances", {})
	club.finances = {}
	club.serie = []
	_calendrier(day)
	club.abo = 0
	if int(club.get("fonde", day)) != day:
		_abonnements()
	_recruter_espoirs()
	var nj := (ligue.journees as Array).size()
	if nj > 0:
		_news("Saison %s : %s en %s, %d journées. Premier match le %s." % [s, String(club.nom), _div(div).nom, nj, date_texte(int(ligue.journees[0].d))])
	else:
		_news("Le championnat %s a déjà commencé : le club s'entraîne et jouera dès la saison prochaine." % s)
	changed.emit()


## Dates de la saison : samedis (puis mercredis si on arrive en cours de route)
## de mi-août à fin mai, sans la trêve de Noël.
func _calendrier(day: int) -> void:
	var d := date_of(day)
	var y := int(d.year) if int(d.month) >= 7 else int(d.year) - 1
	var S := sp()
	var db: Array = S.debut
	var fn: Array = S.fin
	var debut := maxi(day + 2, _jour_saison(y, db))
	var fin := _jour_saison(y, fn)
	var treve := [-1, -2]
	if not (S.treve as Array).is_empty():
		treve = [_jour_saison(y, S.treve[0]), _jour_saison(y, S.treve[1])]
	var samedis := []
	var mercredis := []
	for k in range(debut, fin + 1):
		if k >= int(treve[0]) and k <= int(treve[1]):
			continue
		var wd := int(date_of(k).wd)
		if wd == int(S.jour):
			samedis.append(k)
		elif wd == int(S.jour2):
			mercredis.append(k)
	var noms := (ligue.clubs as Dictionary).keys()
	noms.sort()
	var r := RandomNumberGenerator.new()
	r.seed = hash([String(ligue.saison), String(club.nom)])
	for i in range(noms.size() - 1, 0, -1):
		var k2 := r.randi() % (i + 1)
		var tmp = noms[i]
		noms[i] = noms[k2]
		noms[k2] = tmp
	var ar := bool(S.aller_retour)
	var rounds := ClubDonnees.round_robin(noms, ar)
	var dates := samedis.duplicate()
	if dates.size() < rounds.size():
		dates.append_array(mercredis)
		dates.sort()
	if dates.size() < rounds.size() and ar:
		rounds = ClubDonnees.round_robin(noms, false)
	if dates.size() < rounds.size():
		ligue.journees = []
		return
	var heure := float(_div(int(ligue.division)).heure)
	var js := []
	for i in rounds.size():
		var idx := int(roundf(float(i) * float(dates.size() - 1) / float(maxi(rounds.size() - 1, 1))))
		if rounds.size() == 1:
			idx = 0
		var dd := int(dates[idx])
		var h := heure if int(date_of(dd).wd) == int(S.jour) else (14.0 if sport == "tennis" else 20.0)
		js.append({"n": i + 1, "d": dd, "h": h, "matchs": rounds[i], "scores": [], "joue": false, "prepare": false, "mon": {}})
	ligue.journees = js


## Jour d'une date [mois, jour] de la saison qui commence en juillet de l'année y.
static func _jour_saison(y: int, md: Array) -> int:
	return day_of(y if int(md[0]) >= 7 else y + 1, int(md[0]), int(md[1]))


# --- Abonnements -------------------------------------------------------------------------------

func nb_domicile() -> int:
	var n := 0
	for j in ligue.get("journees", []):
		var m := mon_match(j)
		if not m.is_empty() and String(m[0]) == String(club.nom):
			n += 1
	return n


## Prix conseillé de l'abonnement : 70 % des billets de la saison.
func abo_prix_ref() -> float:
	return roundf(float(_div(int(club.get("division", 0))).prix) * maxi(nb_domicile(), 1) * 0.7)


## Abonnés attendus à ce prix (supporters fidèles et habitants fans).
func abonnes_attendus(prix: float) -> int:
	var cap := places()
	if cap <= 0 or nb_domicile() <= 0:
		return 0
	var ref := maxf(abo_prix_ref(), 1.0)
	var pf := clampf(pow(ref / maxf(prix, 1.0), 1.5), 0.05, 2.0)
	var base := float(club.get("supporters", 0.0)) * 0.35 + float(_fans_locaux()) * 0.25
	return mini(int(cap * 0.6), int(base * pf))


## Vente des abonnements (début de saison) : payés d'avance, places assurées.
func _abonnements() -> void:
	if nb_domicile() <= 0:
		return
	if float(club.get("abo_prix", 0.0)) <= 0.0:
		club.abo_prix = abo_prix_ref()
	club.abo = abonnes_attendus(float(club.abo_prix))
	if int(club.abo) > 0:
		_flux("Abonnements", float(club.abo) * float(club.abo_prix))
		_news("%s : %s abonnés pour la saison (%s l'abonnement)." % [String(club.nom), Stades._milliers(int(club.abo)), BuildingSystem.format_money(int(club.abo_prix))])
		_penser("abonne", [], 2)
		if float(club.abo_prix) > abo_prix_ref() * 1.4:
			_penser("abo_cher", [int(club.abo_prix)], 2)


func set_abo_prix(v: float) -> void:
	if fonde():
		club.abo_prix = clampf(roundf(v), 0.0, 20_000.0)
		changed.emit()


func journee_du_jour(day: int) -> Dictionary:
	for j in ligue.get("journees", []):
		if int(j.d) == day:
			return j
	return {}


func prochaine_journee() -> Dictionary:
	for j in ligue.get("journees", []):
		if not bool(j.joue):
			return j
	return {}


## Mon match d'une journée : [domicile, extérieur] ou [].
func mon_match(j: Dictionary) -> Array:
	for m in j.matchs:
		if String(m[0]) == String(club.nom) or String(m[1]) == String(club.nom):
			return m
	return []


func _force_de(nom: String) -> float:
	if nom == String(club.nom):
		return float(force_equipe().force)
	return float(ligue.clubs[nom].force) if ligue.clubs.has(nom) else 50.0


## Tire un match : {buts: [{min, side, buteur, pts}], score: [d, e]} et, selon
## le sport, prol (prolongation), suffixe (« a.p. », « t.a.b. »), bonus [d, e]
## (rugby), essais [d, e].
func simuler(dom: String, ext: String, r: RandomNumberGenerator) -> Dictionary:
	match String(sp().modele):
		"basket":
			return _sim_points(dom, ext, r, true)
		"handball":
			return _sim_points(dom, ext, r, false)
		"hockey":
			return _sim_hockey(dom, ext, r)
		"rugby":
			return _sim_rugby(dom, ext, r)
		"tennis":
			return _sim_tennis(dom, ext, r)
	var fd := _force_de(dom)
	var fe := _force_de(ext)
	var ld := 1.35 * exp((fd - fe) / 10.0) * 1.1
	var le := 1.35 * exp((fe - fd) / 10.0) * 0.9
	var t: Array = ClubDonnees.TACTIQUES[String(club.tactique)]
	if dom == String(club.nom):
		ld *= float(t[0])
		le *= float(t[1])
	elif ext == String(club.nom):
		le *= float(t[0])
		ld *= float(t[1])
	ld = clampf(ld, 0.15, 4.5)
	le = clampf(le, 0.15, 4.5)
	var buts := []
	var sc := [ClubDonnees.poisson(r, ld), ClubDonnees.poisson(r, le)]
	for side in 2:
		var nom := dom if side == 0 else ext
		for i in int(sc[side]):
			buts.append({"min": r.randi_range(1, 90), "side": side, "buteur": _buteur(r) if nom == String(club.nom) else ""})
	buts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.min) < int(b.min))
	return {"buts": buts, "score": sc}


## Multiplicateurs de la tactique du club : [marqués par dom, marqués par ext].
func _tact(dom: String, ext: String, force := 1.0) -> Array:
	var t: Array = ClubDonnees.TACTIQUES[String(club.tactique)]
	var a := 1.0 + (float(t[0]) - 1.0) * force
	var b := 1.0 + (float(t[1]) - 1.0) * force
	if dom == String(club.nom):
		return [a, b]
	if ext == String(club.nom):
		return [b, a]
	return [1.0, 1.0]


## Basket (paniers à 1, 2 ou 3 points, prolongation en cas d'égalité) ou
## handball (buts, le nul existe).
func _sim_points(dom: String, ext: String, r: RandomNumberGenerator, basket: bool) -> Dictionary:
	var fd := _force_de(dom)
	var fe := _force_de(ext)
	var tm := _tact(dom, ext, 0.5)
	var moy := float(sp().moy)
	var k := 1.1 if basket else 0.42
	var home := 3.0 if basket else 1.2
	var sd := 9.0 if basket else 3.5
	var plancher := 35 if basket else 12
	var sc := [maxi(int(roundf((moy + (fd - fe) * k + home) * float(tm[0]) + r.randfn(0.0, sd))), plancher),
		maxi(int(roundf((moy + (fe - fd) * k) * float(tm[1]) + r.randfn(0.0, sd))), plancher)]
	var res := {"score": sc, "buts": []}
	var fin := float(int((sp().per as Array)[0]) * int((sp().per as Array)[1]))
	var prol := [0, 0]
	if basket and int(sc[0]) == int(sc[1]):
		# Prolongation (5 minutes) : on rejoue jusqu'à ce qu'il y ait un vainqueur.
		var pd := 1.0 / (1.0 + exp(-(fd + home - fe) / 8.0))
		prol = [r.randi_range(6, 14), r.randi_range(6, 14)]
		if prol[0] == prol[1]:
			if r.randf() < pd:
				prol[0] += r.randi_range(1, 4)
			else:
				prol[1] += r.randi_range(1, 4)
		res.prol = true
		res.suffixe = "a.p."
	var xi := onze()
	for side in 2:
		var nom := dom if side == 0 else ext
		var moi := nom == String(club.nom)
		for part in 2:
			var reste := int(sc[side]) if part == 0 else int(prol[side])
			while reste > 0:
				var pts := 1
				if basket:
					var u := r.randf()
					pts = 3 if u < 0.3 else (2 if u < 0.85 else 1)
					pts = mini(pts, reste)
				reste -= pts
				var mn := r.randf_range(0.3, fin - 0.05) if part == 0 else fin
				res.buts.append({"min": mn, "side": side, "pts": pts, "buteur": _buteur(r, xi) if moi else ""})
	res.score = [int(sc[0]) + int(prol[0]), int(sc[1]) + int(prol[1])]
	res.buts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.min) < float(b.min))
	return res


## Hockey : buts (environ trois par équipe), prolongation puis tirs au but.
func _sim_hockey(dom: String, ext: String, r: RandomNumberGenerator) -> Dictionary:
	var fd := _force_de(dom)
	var fe := _force_de(ext)
	var tm := _tact(dom, ext)
	var moy := float(sp().moy)
	var ld := clampf(moy * exp((fd - fe) / 10.0) * 1.08 * float(tm[0]), 0.4, 8.0)
	var le := clampf(moy * exp((fe - fd) / 10.0) * 0.93 * float(tm[1]), 0.4, 8.0)
	var sc := [ClubDonnees.poisson(r, ld), ClubDonnees.poisson(r, le)]
	var res := {"score": sc, "buts": []}
	var xi := onze()
	for side in 2:
		var moi := (dom if side == 0 else ext) == String(club.nom)
		for i in int(sc[side]):
			res.buts.append({"min": r.randf_range(0.5, 59.8), "side": side, "pts": 1, "buteur": _buteur(r, xi) if moi else ""})
	if int(sc[0]) == int(sc[1]):
		var pd := 1.0 / (1.0 + exp(-(fd + 1.5 - fe) / 8.0))
		var gagnant := 0 if r.randf() < pd else 1
		var tab := r.randf() < 0.45
		var moi2 := (dom if gagnant == 0 else ext) == String(club.nom)
		res.buts.append({"min": 60.0, "side": gagnant, "pts": 1, "buteur": "" if tab or not moi2 else _buteur(r, xi)})
		sc[gagnant] = int(sc[gagnant]) + 1
		res.prol = true
		res.suffixe = "t.a.b." if tab else "a.p."
	res.buts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.min) < float(b.min))
	return res


## Rugby : essais (5 points, transformés à 2), pénalités (3), bonus offensif
## (trois essais de plus que l'adversaire) et défensif (défaite de 5 points ou moins).
func _sim_rugby(dom: String, ext: String, r: RandomNumberGenerator) -> Dictionary:
	var fd := _force_de(dom)
	var fe := _force_de(ext)
	var tm := _tact(dom, ext)
	var moy := float(sp().moy)
	var essais := [ClubDonnees.poisson(r, clampf(moy * exp((fd - fe) / 9.0) * 1.12 * float(tm[0]), 0.2, 9.0)),
		ClubDonnees.poisson(r, clampf(moy * exp((fe - fd) / 9.0) * 0.9 * float(tm[1]), 0.2, 9.0))]
	var pens := [ClubDonnees.poisson(r, clampf(2.2 * exp((fd - fe) / 18.0), 0.4, 6.0)),
		ClubDonnees.poisson(r, clampf(2.0 * exp((fe - fd) / 18.0), 0.4, 6.0))]
	var res := {"buts": [], "essais": essais}
	var sc := [0, 0]
	var xi := onze()
	for side in 2:
		var moi := (dom if side == 0 else ext) == String(club.nom)
		for i in int(essais[side]):
			var mn := r.randf_range(0.5, 79.0)
			res.buts.append({"min": mn, "side": side, "pts": 5, "buteur": _buteur(r, xi) if moi else ""})
			sc[side] += 5
			if r.randf() < 0.72:
				res.buts.append({"min": mn + 0.6, "side": side, "pts": 2, "buteur": ""})
				sc[side] += 2
		for i in int(pens[side]):
			res.buts.append({"min": r.randf_range(0.5, 79.8), "side": side, "pts": 3, "buteur": ""})
			sc[side] += 3
	res.score = sc
	var bonus := [0, 0]
	for side in 2:
		var o := 1 - side
		if int(sc[side]) > int(sc[o]) and int(essais[side]) >= int(essais[o]) + 3:
			bonus[side] = 1
		elif int(sc[side]) < int(sc[o]) and int(sc[o]) - int(sc[side]) <= 5:
			bonus[side] = 1
	res.bonus = bonus
	res.buts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.min) < float(b.min))
	return res


## Forces des quatre joueurs alignés (les meilleurs d'abord).
func _quatre(nom: String) -> Array:
	if nom == String(club.nom):
		var out := []
		for o in onze():
			out.append([note_eff(joueurs[int(o.id)]), str(int(o.id))])
		out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		while out.size() < 4:
			out.append([25.0, ""])
		return out.slice(0, 4)
	var f := _force_de(nom)
	return [[f + 4.0, ""], [f + 1.5, ""], [f - 1.5, ""], [f - 4.0, ""]]


## Tennis par équipes : quatre simples (du n° 4 au n° 1) puis deux doubles ;
## chaque partie gagnée vaut un point (score sur 6, le nul existe).
func _sim_tennis(dom: String, ext: String, r: RandomNumberGenerator) -> Dictionary:
	var a := _quatre(dom)
	var b := _quatre(ext)
	var parties := [[3, 3], [2, 2], [1, 1], [0, 0]]
	var res := {"buts": [], "score": [0, 0]}
	var sc := [0, 0]
	for i in 6:
		var fa := 0.0
		var fb := 0.0
		var qui_a := ""
		var qui_b := ""
		if i < 4:
			fa = float(a[parties[i][0]][0])
			fb = float(b[parties[i][1]][0])
			qui_a = String(a[parties[i][0]][1])
			qui_b = String(b[parties[i][1]][1])
		else:
			var x := 0 if i == 4 else 2
			fa = (float(a[x][0]) + float(a[x + 1][0])) * 0.5
			fb = (float(b[x][0]) + float(b[x + 1][0])) * 0.5
			qui_a = String(a[x][1])
			qui_b = String(b[x][1])
		var p := 1.0 / (1.0 + exp(-(fa + 1.0 - fb) / 5.0))
		var side := 0 if r.randf() < p else 1
		sc[side] += 1
		res.buts.append({"min": float(i + 1), "side": side, "pts": 1, "buteur": qui_a if side == 0 else qui_b})
	res.score = sc
	return res


func _buteur(r: RandomNumberGenerator, xi: Array = []) -> String:
	if xi.is_empty():
		xi = onze()
	if xi.is_empty():
		return ""
	var poids: Dictionary = sp().marqueur
	var tot := 0.0
	for o in xi:
		tot += float(poids.get(String(o.poste), 1.0)) * float(joueurs[int(o.id)].note)
	if tot <= 0.0:
		return ""
	var u := r.randf() * tot
	for o in xi:
		u -= float(poids.get(String(o.poste), 1.0)) * float(joueurs[int(o.id)].note)
		if u <= 0.0:
			return str(int(o.id))
	return str(int(xi[-1].id))


## Le jour du match : on tire le résultat et, à domicile, on prépare la fête au stade.
func _preparer(j: Dictionary) -> void:
	j.prepare = true
	var m := mon_match(j)
	if m.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([String(ligue.saison), int(j.n), String(club.nom), rng.randi()])
	var res := simuler(String(m[0]), String(m[1]), r)
	j.mon = res
	j.xi = []
	for o in onze():
		j.xi.append(int(o.id))
	var dom := String(m[0]) == String(club.nom)
	if dom:
		j.affluence = affluence(String(m[1]))
		_evenement_stade(j, m, res)


## Spectateurs attendus contre un adversaire.
func affluence(adversaire: String) -> int:
	var cap := places()
	if cap <= 0:
		return 0
	var locaux := float(_fans_locaux())
	var serie: Array = club.get("serie", [])
	var forme := 0.0
	for x in serie.slice(maxi(serie.size() - 5, 0)):
		forme += 0.06 if String(x) == "V" else (-0.05 if String(x) == "D" else 0.0)
	var attrait := 1.0 + forme
	var cl := classement()
	if not cl.is_empty() and cl.size() >= 3:
		for i in 3:
			if String(cl[i].nom) == adversaire:
				attrait += 0.2
	var div := _div(int(club.division))
	var prix := maxf(float(club.prix), 0.5)
	var pf := clampf(pow(float(div.prix) / prix, 1.3), 0.12, 1.9)
	var ext := float(club.supporters) * (1.0 + int(club.division) * 0.5)
	# Les abonnés viennent quoi qu'il arrive (ils ont payé leur place).
	return mini(cap, maxi(int((locaux + ext) * attrait * pf), int(club.get("abo", 0))))


func _fans_locaux() -> int:
	if fans_force >= 0:
		return fans_force
	if population == null:
		return 0
	var n := 0.0
	var hob := ClubSports.hobby(sport)
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		if (p.get("hob", []) as Array).has(hob):
			n += 0.55
		elif population.age_of(p) >= 6.0:
			n += 0.04 + float(club.reputation) * 0.001
	return int(n)


func _evenement_stade(j: Dictionary, m: Array, res: Dictionary) -> void:
	var ev := Evenements.instance
	if ev == null or not is_instance_valid(ev) or ev.buildings != buildings or buildings == null:
		return
	var bid := int(club.stade)
	if not buildings.buildings.has(bid):
		return
	var kick := ev.unix_at(int(j.d), float(j.h))
	var ext: Dictionary = ligue.clubs.get(String(m[1]), {})
	var data := {"home": String(m[0]), "away": String(m[1]), "buts": res.buts.duplicate(true), "affluence": int(j.affluence), "fans": 0,
		"ligue": true, "score": [0, 0], "annonces": 0, "club": true, "cdom": club.couleurs, "cext": ext.get("couleurs", ["f2f2f2", "1b1b1b"]),
		"sport": sport, "suffixe": String(res.get("suffixe", ""))}
	var pos := Stades.pelouse_monde(buildings, bid).centre as Vector3
	var titre := "%s, %de journée : %s – %s" % [_div(int(club.division)).nom, int(j.n), String(m[0]), String(m[1])]
	if sport != "football":
		titre = "%s, %s" % [String(sp().court), titre]
	var duree := Matchs.DUREE if sport == "football" else ClubSports.duree(sport) + 300.0
	j.ev = ev.ajouter("match", titre, kick - Matchs.AVANT, kick + duree, pos, bid, data)


## Tous les matchs de la journée : résultats, classement, recettes.
func jouer_journee(j: Dictionary) -> void:
	if bool(j.joue):
		return
	if not bool(j.get("prepare", false)):
		_preparer(j)
	j.joue = true
	var r := RandomNumberGenerator.new()
	r.seed = hash([String(ligue.saison), int(j.n), "autres"])
	var scores := []
	for m in j.matchs:
		var res: Dictionary
		if String(m[0]) == String(club.nom) or String(m[1]) == String(club.nom):
			res = j.mon
		else:
			res = simuler(String(m[0]), String(m[1]), r)
		var sc: Array = res.score
		scores.append([int(sc[0]), int(sc[1])])
		var prol := bool(res.get("prol", false))
		var bonus: Array = res.get("bonus", [0, 0])
		_compter(String(m[0]), int(sc[0]), int(sc[1]), prol, int(bonus[0]))
		_compter(String(m[1]), int(sc[1]), int(sc[0]), prol, int(bonus[1]))
		# Les clubs adverses changent un peu selon leurs résultats.
		for i in 2:
			var nom := String(m[i])
			if ligue.clubs.has(nom) and not bool(ligue.clubs[nom].moi):
				var diff := int(sc[i]) - int(sc[1 - i])
				ligue.clubs[nom].force = float(ligue.clubs[nom].force) + signf(diff) * 0.25
	j.scores = scores
	var m := mon_match(j)
	if not m.is_empty():
		_apres_mon_match(j, m)
	_verifier_fin()
	changed.emit()


## Points au classement selon le sport : victoire, nul, défaite, après
## prolongation (hockey, basket), bonus (rugby).
func _compter(nom: String, pour: int, contre: int, prol := false, bonus := 0) -> void:
	if not ligue.clubs.has(nom):
		return
	var P: Dictionary = sp().points
	var c: Dictionary = ligue.clubs[nom]
	c.j = int(c.j) + 1
	c.bp = int(c.bp) + pour
	c.bc = int(c.bc) + contre
	if pour > contre:
		c.g = int(c.g) + 1
		c.pts = int(c.pts) + int(P.get("VP", P.V) if prol else P.V)
	elif pour == contre:
		c.n = int(c.n) + 1
		c.pts = int(c.pts) + int(P.get("N", 1))
	else:
		c.p = int(c.p) + 1
		c.pts = int(c.pts) + int(P.get("DP", P.D) if prol else P.D)
	c.pts = int(c.pts) + bonus


func _apres_mon_match(j: Dictionary, m: Array) -> void:
	var res: Dictionary = j.mon
	var dom := String(m[0]) == String(club.nom)
	var sc: Array = res.score
	var pour := int(sc[0]) if dom else int(sc[1])
	var contre := int(sc[1]) if dom else int(sc[0])
	var issue := "V" if pour > contre else ("N" if pour == contre else "D")
	(club.serie as Array).append(issue)
	# Joueurs : matchs, buts, fatigue, forme, blessures.
	var tr: Array = ClubDonnees.ENTRAINEMENTS[String(club.entrainement)]
	for id in j.get("xi", []):
		if not joueurs.has(int(id)):
			continue
		var p: Dictionary = joueurs[int(id)]
		p.matchs = int(p.matchs) + 1
		p.matchs_saison = int(p.matchs_saison) + 1
		p.fatigue = minf(float(p.fatigue) + 0.3 * ClubSports.fatigue_f(sport, String(club.formation)), 1.0)
		p.forme = clampf(float(p.forme) + (0.07 if issue == "V" else (-0.05 if issue == "D" else 0.0)) + rng.randf_range(-0.05, 0.05), 0.2, 1.0)
		if rng.randf() < 0.018 * float(tr[2]):
			p.blesse = rng.randi_range(5, 45)
			_news("%s se blesse pendant le match (absent %d jours)." % [nom_joueur(p), int(p.blesse)])
	var noms_buteurs := []
	var par_joueur := {}
	for b in res.buts:
		var bid := String(b.buteur)
		if bid != "" and joueurs.has(int(bid)):
			var p: Dictionary = joueurs[int(bid)]
			var pts := int(b.get("pts", 1)) if String(sp().modele) in ["basket", "handball"] else 1
			p.buts = int(p.buts) + pts
			p.buts_saison = int(p.buts_saison) + pts
			par_joueur[int(bid)] = int(par_joueur.get(int(bid), 0)) + pts
			noms_buteurs.append(String(p.nom))
	# Humeur des supporters de la ville.
	club.humeur = clampf(float(club.get("humeur", 0.0)) + (0.22 if issue == "V" else (-0.18 if issue == "D" else 0.02)), -1.0, 1.0)
	# Réputation et supporters.
	var delta_rep := 0.8 if issue == "V" else (-0.5 if issue == "D" else 0.1)
	club.reputation = clampf(float(club.reputation) + delta_rep, 0.0, 100.0)
	club.supporters = maxf(float(club.supporters) * (1.02 if issue == "V" else (0.985 if issue == "D" else 1.0)) + (6.0 if issue == "V" else 0.0), 30.0)
	var adv := String(m[1]) if dom else String(m[0])
	var txt := "%s %d – %d %s" % [String(m[0]), int(sc[0]), int(sc[1]), String(m[1])]
	if String(res.get("suffixe", "")) != "":
		txt += " (%s)" % String(res.suffixe)
	if String(sp().modele) in ["basket", "handball"] and not par_joueur.is_empty():
		var top := -1
		for id in par_joueur:
			if top < 0 or int(par_joueur[id]) > int(par_joueur[top]):
				top = int(id)
		txt += " (meilleur marqueur : %s, %d %s)" % [nom_joueur(joueurs[top]), int(par_joueur[top]), String(sp().unite[1])]
	elif not noms_buteurs.is_empty():
		txt += " (%s : %s)" % [String(sp().unite[1]) if sport != "tennis" else "victoires", ", ".join(noms_buteurs)]
	resultat.emit({"sport": sport, "club": String(club.nom), "adv": adv, "dom": dom, "pour": pour, "contre": contre,
		"issue": issue, "buteurs": noms_buteurs.duplicate(), "affluence": int(j.get("affluence", 0)) if dom else 0, "texte": txt})
	if dom:
		var aff := int(j.get("affluence", 0))
		var payants := maxi(aff - int(club.get("abo", 0)), 0)
		var billets := payants * float(club.prix)
		var buvette := aff * BUVETTE
		var boutique := aff * BOUTIQUE
		_flux("Billetterie", billets)
		_flux("Buvette", buvette)
		_flux("Boutique (jours de match)", boutique)
		var loyer := maxf(billets * LOYER_PART, LOYER_MIN)
		_flux("Location du stade (à la ville)", -loyer)
		_verser_ville("Club de sport : location du stade", loyer)
		j.recettes = billets + buvette + boutique
		_penser("victoire" if issue == "V" else ("defaite" if issue == "D" else "nul"), [], 3)
		var ref := float(_div(int(club.division)).prix)
		if float(club.prix) > ref * 1.5:
			_penser("cher", [int(club.prix)], 2)
		elif float(club.prix) <= ref * 0.8:
			_penser("bon_prix", [], 1)
		if aff >= places() and places() > 0:
			_penser("complet", [], 2)
		_news("%s, %s spectateurs, %s de recettes." % [txt, Stades._milliers(aff), BuildingSystem.format_money(int(j.recettes))])
	else:
		_news("À l'extérieur contre %s : %s." % [adv, txt])
	for id in j.get("xi", []):
		if joueurs.has(int(id)) and int(joueurs[int(id)].pid) >= 0:
			_penser("habitant", [nom_joueur(joueurs[int(id)])], 1)
			break


func classement() -> Array:
	var out: Array = (ligue.get("clubs", {}) as Dictionary).values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.pts) != int(b.pts):
			return int(a.pts) > int(b.pts)
		var da := int(a.bp) - int(a.bc)
		var db := int(b.bp) - int(b.bc)
		if da != db:
			return da > db
		if int(a.bp) != int(b.bp):
			return int(a.bp) > int(b.bp)
		return String(a.nom) < String(b.nom))
	return out


func rang() -> int:
	var cl := classement()
	for i in cl.size():
		if bool(cl[i].moi):
			return i + 1
	return 0


func _verifier_fin() -> void:
	if bool(ligue.get("fini", false)):
		return
	for j in ligue.journees:
		if not bool(j.joue):
			return
	ligue.fini = true
	var cl := classement()
	var div := int(ligue.division)
	var d := _div(div)
	var rg := rang()
	var n := cl.size()
	var prime := float(d.titre) * pow(0.82, rg - 1)
	_flux("Prime de classement", prime)
	var issue := "maintien"
	if rg <= int(d.monte) and div < ClubSports.nb_divisions(sport) - 1:
		issue = "montee"
	elif rg > n - int(d.descend) and div > 0:
		issue = "descente"
	if rg == 1:
		(club.palmares as Array).append("Champion de %s %s" % [d.nom, String(ligue.saison)])
	(club.historique as Array).append({"saison": String(ligue.saison), "division": div, "rang": rg, "pts": int(cl[rg - 1].pts), "issue": issue})
	club.issue = issue
	# Clubs qu'on retrouvera la saison prochaine.
	var restent := []
	for c in cl:
		if not bool(c.moi):
			restent.append(String(c.nom))
	ligue.restent = restent.slice(0, 3) if issue == "montee" else restent.slice(restent.size() - 3)
	var champion := String(cl[0].nom)
	var txt := "Fin de saison %s : %s champion de %s. %s termine %de" % [String(ligue.saison), champion, d.nom, String(club.nom), rg]
	match issue:
		"montee":
			txt += " et monte en %s !" % _div(div + 1).nom
			club.reputation = minf(float(club.reputation) + 8.0, 100.0)
			club.supporters = float(club.supporters) * 1.4
			club.humeur = 1.0
			_penser("montee", [], 5)
		"descente":
			txt += " et descend en %s." % _div(div - 1).nom
			club.reputation = maxf(float(club.reputation) - 6.0, 0.0)
			club.humeur = -1.0
			_penser("descente", [], 5)
		_:
			txt += "."
	_news(txt)
	if rg == 1 or issue == "montee":
		club.humeur = 1.0
		_fete_supporters("titre" if rg == 1 else "montee")


## Fête des supporters en ville, le lendemain d'un titre ou d'une montée.
func _fete_supporters(raison: String) -> void:
	var ev := Evenements.instance
	if ev == null or not is_instance_valid(ev) or ev.buildings != buildings or buildings == null:
		return
	var bid := int(club.get("stade", -1))
	if not buildings.buildings.has(bid):
		return
	var day := today() + 1
	var nom_f := "Fête des supporters : %s %s" % [String(club.nom), "champion !" if raison == "titre" else "monte !"]
	var id := ev.ajouter("fete", nom_f, ev.unix_at(day, 16.0), ev.unix_at(day, 22.0), ev.building_pos(bid), bid,
		{"club": String(club.nom), "couleurs": club.couleurs, "sport": sport})
	club.fete = id
	_penser("fete", [], 4)
	_news("Demain à 16 h, les supporters fêtent %s autour du %s." % ["le titre" if raison == "titre" else "la montée", nom_stade()])


## Bilan de la saison passée (appelé au début de la suivante) : montée,
## descente, fins de contrat, retraites.
func _fin_saison() -> void:
	var issue := String(club.get("issue", "maintien"))
	if issue == "montee":
		club.division = mini(int(club.division) + 1, ClubSports.nb_divisions(sport) - 1)
	elif issue == "descente":
		club.division = maxi(int(club.division) - 1, 0)
	club.erase("issue")
	club.prix = maxf(float(club.prix), float(_div(int(club.division)).prix) * 0.6)
	club.abo_prix = 0.0
	_fin_saison_espoirs()
	var fin := _annee_saison()
	for id in joueurs.keys():
		var p: Dictionary = joueurs[id]
		if age(p) >= 36.0 or (age(p) >= 33.0 and rng.randf() < 0.3):
			joueurs.erase(id)
			_news("%s prend sa retraite à %d ans (%d matchs, %d buts au club)." % [nom_joueur(p), int(age(p)), int(p.matchs), int(p.buts)])
		elif int(p.contrat) <= fin:
			if bool(p.benevole) and rng.randf() < 0.85:
				# Les bénévoles du coin rempilent presque tous.
				p.contrat = fin + 1
				continue
			joueurs.erase(id)
			_news("Fin de contrat : %s quitte le club." % nom_joueur(p))
	_completer_effectif()


# --- Argent -----------------------------------------------------------------------------------

func _flux(poste: String, montant: float) -> void:
	if not fonde() or absf(montant) < 0.01:
		return
	club.caisse = float(club.caisse) + montant
	var f: Dictionary = club.finances
	f[poste] = float(f.get(poste, 0.0)) + montant


## Argent entre la ville du stade et le club (montant > 0 : la ville reçoit).
func _verser_ville(poste: String, montant: float) -> void:
	if buildings == null or buildings.unlimited_money or absf(montant) < 0.01:
		return
	var prev := Pays.au_batiment(int(club.get("stade", -1))) if fonde() and int(club.get("stade", -1)) >= 0 else -1
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		if montant > 0.0:
			bc.recette(poste, montant)
		else:
			bc.depense(poste, -montant)
	else:
		buildings.money += int(montant)
	Pays.retour(prev)


func caisse_ville() -> int:
	if buildings == null:
		return 0
	var prev := Pays.au_batiment(int(club.stade)) if fonde() and int(club.stade) >= 0 else -1
	var m := buildings.money
	Pays.retour(prev)
	return m


## La ville subventionne le club.
func subventionner(montant: float) -> String:
	if not fonde():
		return "Fonde d'abord le club."
	if montant <= 0.0:
		return ""
	if buildings != null and not buildings.unlimited_money and caisse_ville() < montant:
		return "La ville n'a pas assez d'argent."
	_verser_ville("Subvention au club de sport", -montant)
	_flux("Subventions de la ville", montant)
	_news("La ville verse %s de subvention au club." % BuildingSystem.format_money(int(montant)))
	changed.emit()
	return ""


func bilan(prec := false) -> Dictionary:
	var f: Dictionary = club.get("finances_prec" if prec else "finances", {})
	var rec := 0.0
	var dep := 0.0
	for k in f:
		if float(f[k]) >= 0.0:
			rec += float(f[k])
		else:
			dep -= float(f[k])
	return {"postes": f, "recettes": rec, "depenses": dep, "solde": rec - dep}


# --- Supporters en ville ---------------------------------------------------------------------

## L'habitant soutient-il le club ? Les pratiquants du sport surtout, et
## d'autant plus de monde que le club est connu.
func est_supporter(p: Dictionary) -> bool:
	if not fonde():
		return false
	var h := float(posmod(hash([int(p.get("id", -1)), sport]), 1000)) / 1000.0
	var rep := float(club.get("reputation", 10.0))
	var part := 0.0
	if (p.get("hob", []) as Array).has(ClubSports.hobby(sport)):
		part = 0.45 + rep * 0.004
	else:
		part = 0.02 + rep * 0.0015 + int(club.get("division", 0)) * 0.01
	return h < part


## Habitants supporters (recompté chaque jour).
func supporters_habitants() -> int:
	if _supporters_cache >= 0:
		return _supporters_cache
	var n := 0
	if population != null and fonde():
		for pid in population.persons:
			var p: Dictionary = population.persons[pid]
			if population.age_of(p) >= 5.0 and est_supporter(p):
				n += 1
	_supporters_cache = n
	return n


func avis_facteurs() -> Array:
	return [{"id": "club_%s" % sport, "theme": "loisirs", "f": satisfaction_of}]


## Moral des supporters selon les résultats du club : [delta, raisons].
func satisfaction_of(p: Dictionary) -> Array:
	if not fonde():
		return [0.0, []]
	var h := float(club.get("humeur", 0.0))
	if absf(h) < 0.25 or not est_supporter(p):
		return [0.0, []]
	if h > 0.0:
		return [h * 5.0, ["+ %s gagne, les supporters sont aux anges" % String(club.nom)]]
	return [h * 4.0, ["− %s perd, les supporters font grise mine" % String(club.nom)]]


func humeur_texte() -> String:
	var h := float(club.get("humeur", 0.0))
	if h > 0.6:
		return "euphorique"
	if h > 0.25:
		return "content"
	if h < -0.6:
		return "abattu"
	if h < -0.25:
		return "déçu"
	return "partagé"


# --- Nouvelles --------------------------------------------------------------------------------

func _news(t: String) -> void:
	journal.push_front({"d": today(), "t": t})
	if journal.size() > 40:
		journal.resize(40)
	var ev := Evenements.instance
	if ev != null and is_instance_valid(ev) and ev.is_inside_tree() and ev.buildings == buildings and buildings != null:
		var pos := Vector3.INF
		if fonde() and buildings.buildings.has(int(club.stade)):
			pos = ev.building_pos(int(club.stade))
		ev.news(t, pos, "match")
	else:
		message.emit(t)


func _penser(cle: String, args: Array = [], poids := 1) -> void:
	var txt := String(ClubDonnees.PENSEES.get(cle, ClubSports.PENSEES.get(cle, "")))
	if txt == "":
		return
	if not args.is_empty():
		txt = txt % args
	pensees[txt] = int(pensees.get(txt, 0)) + poids
	if pensees.size() > 24:
		var worst := ""
		for k in pensees:
			if worst == "" or int(pensees[k]) < int(pensees[worst]):
				worst = k
		pensees.erase(worst)


const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
const JOURS := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]


func date_texte(day: int) -> String:
	var d := date_of(day)
	return "%s %d %s" % [JOURS[int(d.wd)], int(d.mday), MOIS[int(d.month) - 1]]


func summary() -> String:
	if not fonde():
		return "Pas encore de club"
	return "%s : %de de %s, caisse %s" % [String(club.nom), rang(), _div(int(club.division)).nom, BuildingSystem.format_money(int(club.caisse))]


# --- Sauvegarde -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if not fonde():
		return {}
	var js := {}
	for id in joueurs:
		js[str(id)] = joueurs[id]
	var lg := ligue.duplicate(true)
	for j in lg.get("journees", []):
		j.erase("ev")
	var es := {}
	for id in espoirs:
		es[str(id)] = espoirs[id]
	return {"club": club.duplicate(true), "joueurs": js, "marche": marche.duplicate(true), "ligue": lg, "journal": journal.duplicate(true),
		"pensees": pensees.duplicate(), "next_id": next_id, "last_day": last_day, "sport": sport, "espoirs": es}


const INT_JOUEUR := ["id", "ne", "blesse", "contrat", "buts", "matchs", "buts_saison", "matchs_saison", "pid"]
const INT_FICHE := ["pts", "j", "g", "n", "p", "bp", "bc"]


static func _ints(d: Dictionary, keys: Array) -> void:
	for k in keys:
		if d.has(k):
			d[k] = int(d[k])


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty() or not d.has("club"):
		return
	club = (d.club as Dictionary).duplicate(true)
	_ints(club, ["stade", "fonde", "division", "academie", "abo", "fete"])
	club.sport = sport
	if not club.has("formation") or not (sp().formations as Dictionary).has(String(club.formation)):
		club.formation = String(sp().formation)
	for k in ["finances", "finances_prec"]:
		if not club.has(k):
			club[k] = {}
	for k in ["historique", "palmares", "serie"]:
		if not club.has(k):
			club[k] = []
	for h in club.historique:
		_ints(h, ["division", "rang", "pts"])
	for k in d.get("joueurs", {}):
		var p: Dictionary = (d.joueurs[k] as Dictionary).duplicate(true)
		_ints(p, INT_JOUEUR)
		joueurs[int(k)] = p
	for k in d.get("espoirs", {}):
		var p: Dictionary = (d.espoirs[k] as Dictionary).duplicate(true)
		_ints(p, INT_JOUEUR)
		espoirs[int(k)] = p
	for p in d.get("marche", []):
		var q: Dictionary = (p as Dictionary).duplicate(true)
		_ints(q, INT_JOUEUR)
		marche.append(q)
	ligue = (d.get("ligue", {}) as Dictionary).duplicate(true)
	if ligue.has("division"):
		ligue.division = int(ligue.division)
	for n in ligue.get("clubs", {}):
		_ints(ligue.clubs[n], INT_FICHE)
	for j in ligue.get("journees", []):
		_ints(j, ["n", "d", "affluence"])
		j.h = float(j.h)
		var sc := []
		for s in j.get("scores", []):
			sc.append([int(s[0]), int(s[1])])
		j.scores = sc
		var xi := []
		for x in j.get("xi", []):
			xi.append(int(x))
		j.xi = xi
		var mon: Dictionary = j.get("mon", {})
		if mon.has("score"):
			mon.score = [int(mon.score[0]), int(mon.score[1])]
			mon.score = [int(mon.score[0]), int(mon.score[1])]
			for b in mon.buts:
				_ints(b, ["side", "pts"] if sport != "football" else ["min", "side"])
			if mon.has("bonus"):
				mon.bonus = [int(mon.bonus[0]), int(mon.bonus[1])]
	journal = (d.get("journal", []) as Array).duplicate(true)
	for e in journal:
		e.d = int(e.d)
	for k in d.get("pensees", {}):
		pensees[k] = int(d.pensees[k])
	next_id = maxi(int(d.get("next_id", 1)), 1)
	for c in [joueurs, espoirs]:
		for id in c:
			next_id = maxi(next_id, int(id) + 1)
	last_day = int(d.get("last_day", -1))
	changed.emit()
