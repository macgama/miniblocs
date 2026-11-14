class_name ClubSport
extends Node
## Club de sport (football) : le joueur en est le président.
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

static var instance: ClubSport

const STEP := 3600.0
const SUBVENTION_DEPART := 150_000.0
const MAX_JOUEURS := 30
const MIN_JOUEURS := 16
const BUVETTE := 3.5
const BOUTIQUE := 1.2
const LOYER_PART := 0.12
const LOYER_MIN := 300.0
const DUREE_MATCH := 2.0 # h, du coup d'envoi au résultat

var buildings: BuildingSystem
var population: Population
var ambiance: DayNight

## Vide tant que le club n'est pas fondé.
var club: Dictionary = {}
## id → joueur du club.
var joueurs: Dictionary = {}
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


func _init() -> void:
	rng.seed = 4_242_424


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


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
	if not j.is_empty() and not bool(j.joue) and float(now.h) >= float(j.h) + DUREE_MATCH:
		jouer_journee(j)


func new_day(now: Dictionary) -> void:
	if not fonde():
		return
	var s := saison_de(int(now.year), int(now.month))
	if String(ligue.get("saison", "")) != s:
		nouvelle_saison(int(now.day))
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
	return "FC %s" % _lieu()


## Stades de la ville où le club peut jouer : [{bid, nom, places}].
func stades_possibles() -> Array:
	var out := []
	if buildings == null:
		return out
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if b.get("chantier", false) or not Stades.est_stade(String(b.t)):
			continue
		out.append({"bid": int(bid), "nom": String(BuildingCatalog.get_type(String(b.t)).get("name", b.t)), "places": Stades.places(String(b.t))})
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
		return "Il faut un stade ou un terrain de foot terminé, dans la ville."
	var now := _now(_temps())
	last_day = int(now.day)
	club = {"nom": nom, "couleurs": ClubDonnees.COULEURS[posmod(couleurs, ClubDonnees.COULEURS.size())].duplicate(),
		"stade": stade, "fonde": int(now.day), "caisse": 0.0, "division": 0, "reputation": 10.0, "supporters": 120.0,
		"prix": ClubDonnees.division(0).prix, "formation": "4-4-2", "tactique": "equilibree", "entrainement": "normal",
		"sponsor": ClubDonnees.SPONSORS[posmod(hash(nom), ClubDonnees.SPONSORS.size())],
		"finances": {}, "finances_prec": {}, "historique": [], "palmares": [], "serie": [], "auto_prix": false}
	_effectif_depart()
	_renouveler_marche()
	nouvelle_saison(int(now.day))
	_verser_ville("Subvention de départ au club de sport", -SUBVENTION_DEPART)
	_flux("Subvention de départ de la ville", SUBVENTION_DEPART)
	_news("Le club %s est fondé ! Il jouera en %s au %s." % [nom, ClubDonnees.division(0).nom, nom_stade()])
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
	return Stades.places(String(buildings.buildings[int(club.stade)].t))


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
		"blesse": 0, "salaire": ClubDonnees.salaire(note), "contrat": 0, "buts": 0, "matchs": 0, "buts_saison": 0,
		"matchs_saison": 0, "pid": -1, "repos": false, "benevole": false}


func age(p: Dictionary) -> float:
	return float(today() - int(p.ne)) / 365.25


static func nom_joueur(p: Dictionary) -> String:
	return "%s %s" % [String(p.prenom), String(p.nom)]


func _annee_saison() -> int:
	var d := date_of(today())
	return int(d.year) if int(d.month) >= 7 else int(d.year) - 1


func _effectif_depart() -> void:
	var niveau := float(ClubDonnees.division(0).niveau)
	var postes := ["G", "G", "D", "D", "D", "D", "D", "D", "D", "M", "M", "M", "M", "M", "M", "M", "A", "A", "A", "A"]
	var locaux := _habitants_footballeurs()
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


## Habitants de 17 à 34 ans qui aiment le football (pour l'équipe amateur).
func _habitants_footballeurs() -> Array:
	var out := []
	if population == null:
		return out
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		if String(p.get("s", "")) != "H" or not (p.get("hob", []) as Array).has("football"):
			continue
		var a := population.age_of(p)
		if a >= 17.0 and a <= 34.0:
			out.append({"p": p, "age": a})
	out.shuffle()
	return out


func liste_joueurs(poste := "") -> Array:
	var out := []
	for id in joueurs:
		if poste == "" or String(joueurs[id].poste) == poste:
			out.append(joueurs[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia := ClubDonnees.ORDRE_POSTES.find(String(a.poste))
		var ib := ClubDonnees.ORDRE_POSTES.find(String(b.poste))
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
	var f: Dictionary = ClubDonnees.FORMATIONS[String(club.get("formation", "4-4-2"))]
	var besoin := {"G": 1, "D": int(f.D), "M": int(f.M), "A": int(f.A)}
	var libres := []
	for id in joueurs:
		if disponible(joueurs[id]):
			libres.append(joueurs[id])
	libres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return note_eff(a) > note_eff(b))
	var out := []
	var pris := {}
	for poste in ClubDonnees.ORDRE_POSTES:
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
	for poste in ClubDonnees.ORDRE_POSTES:
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
	var lignes := {"G": [], "D": [], "M": [], "A": []}
	for o in xi:
		var p: Dictionary = joueurs[int(o.id)]
		var v := note_eff(p) * (0.75 if bool(o.hors_poste) else 1.0)
		(lignes[String(o.poste)] as Array).append(v)
	var moy := {}
	for k in lignes:
		var a: Array = lignes[k]
		var s := 0.0
		for v in a:
			s += float(v)
		moy[k] = s / a.size() if not a.is_empty() else 25.0
	var total := float(moy.G) * 0.12 + float(moy.D) * 0.3 + float(moy.M) * 0.3 + float(moy.A) * 0.28
	# Moins de onze : grosse pénalité.
	total *= clampf(xi.size() / 11.0, 0.3, 1.0)
	return {"force": total, "G": moy.G, "D": moy.D, "M": moy.M, "A": moy.A, "n": xi.size()}


func set_formation(f: String) -> void:
	if ClubDonnees.FORMATIONS.has(f):
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
	var niv := float(ClubDonnees.division(int(club.get("division", 0))).niveau)
	var postes := ["G", "D", "D", "D", "M", "M", "M", "A", "A", "A", "D", "M", "A", "G"]
	for i in postes.size():
		var a := rng.randf_range(17.5, 34.0)
		var p := _nouveau_joueur(postes[i], niv + rng.randf_range(-6.0, 9.0), a, 4.0)
		var libre := rng.randf() < 0.3 or a > 31.0
		p.libre = libre
		p.prix = 0.0 if libre else roundf(ClubDonnees.valeur(float(p.note), a, float(p.pot)) * rng.randf_range(0.9, 1.3) / 1000.0) * 1000.0
		p.salaire = roundf(ClubDonnees.salaire(float(p.note)) * rng.randf_range(1.0, 1.2) / 10.0) * 10.0
		p.club_origine = "" if libre else String(ClubDonnees.ADVERSES[rng.randi() % ClubDonnees.ADVERSES.size()])
		marche.append(p)


## Le joueur accepte-t-il de venir ? "" ou la raison.
func peut_acheter(p: Dictionary) -> String:
	if not fonde():
		return "Fonde d'abord le club."
	if joueurs.size() >= MAX_JOUEURS:
		return "Effectif complet (%d joueurs)." % MAX_JOUEURS
	var niv := float(ClubDonnees.division(int(club.division)).niveau)
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
		_news("%s signe au club (%s, %d ans, note %d)." % [nom_joueur(p), String(ClubDonnees.POSTES[p.poste]).to_lower(), int(age(p)), int(p.note)])
		changed.emit()
		return ""
	return "Ce joueur n'est plus sur le marché."


func valeur_de(p: Dictionary) -> float:
	return ClubDonnees.valeur(float(p.note), age(p), float(p.pot))


func vendre(id: int) -> String:
	if not joueurs.has(id):
		return "Joueur inconnu."
	var p: Dictionary = joueurs[id]
	if bool(p.benevole) and valeur_de(p) < 5000.0:
		return liberer(id)
	var prix := roundf(valeur_de(p) * rng.randf_range(0.8, 1.05) / 1000.0) * 1000.0
	var acheteur: String = ClubDonnees.ADVERSES[rng.randi() % ClubDonnees.ADVERSES.size()]
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
		p.salaire = maxf(float(p.salaire), roundf(ClubDonnees.salaire(float(p.note)) * 1.1 / 10.0) * 10.0)
	changed.emit()
	return ""


func masse_salariale() -> float:
	var s := 0.0
	for id in joueurs:
		s += float(joueurs[id].salaire)
	return s


func staff() -> float:
	return 1500.0 + masse_salariale() * 0.15 + float(club.get("division", 0)) * 8000.0


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
	_completer_effectif()


## Trop peu de joueurs : des jeunes du centre de formation complètent.
func _completer_effectif() -> void:
	while joueurs.size() < MIN_JOUEURS:
		var postes := ["G", "D", "D", "M", "M", "A"]
		var p := _nouveau_joueur(postes[joueurs.size() % postes.size()], float(ClubDonnees.division(int(club.division)).niveau) - 8.0, rng.randf_range(17.0, 19.5))
		p.contrat = _annee_saison() + 2
		joueurs[int(p.id)] = p
		_news("Un jeune du centre de formation, %s, rejoint l'équipe." % nom_joueur(p))


func _mois(now: Dictionary) -> void:
	_flux("Salaires des joueurs", -masse_salariale())
	_flux("Staff et frais du club", -staff())
	var m := int(now.month)
	# Sponsors et droits télé : versés d'août à mai (dix mensualités).
	if m >= 8 or m <= 5:
		var div := ClubDonnees.division(int(club.division))
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
	var niv := float(ClubDonnees.division(div).niveau)
	var pool := ClubDonnees.ADVERSES.duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = hash([String(club.nom), div, String(ligue.get("saison", ""))])
	for g in garder:
		pool.erase(g)
	var noms := garder.duplicate()
	while noms.size() < ClubDonnees.NB_CLUBS - 1 and not pool.is_empty():
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
	var clubs := _adversaires(div, garder.slice(0, ClubDonnees.NB_CLUBS - 1))
	clubs[String(club.nom)] = _fiche(String(club.nom), club.couleurs, 0.0, true)
	ligue.clubs = clubs
	for id in joueurs:
		joueurs[id].buts_saison = 0
		joueurs[id].matchs_saison = 0
	club.finances_prec = club.get("finances", {})
	club.finances = {}
	club.serie = []
	_calendrier(day)
	var nj := (ligue.journees as Array).size()
	if nj > 0:
		_news("Saison %s : %s en %s, %d journées. Premier match le %s." % [s, String(club.nom), ClubDonnees.division(div).nom, nj, date_texte(int(ligue.journees[0].d))])
	else:
		_news("Le championnat %s a déjà commencé : le club s'entraîne et jouera dès la saison prochaine." % s)
	changed.emit()


## Dates de la saison : samedis (puis mercredis si on arrive en cours de route)
## de mi-août à fin mai, sans la trêve de Noël.
func _calendrier(day: int) -> void:
	var d := date_of(day)
	var y := int(d.year) if int(d.month) >= 7 else int(d.year) - 1
	var debut := maxi(day + 2, day_of(y, 8, 8))
	var fin := day_of(y + 1, 5, 31)
	var treve := [day_of(y, 12, 18), day_of(y + 1, 1, 20)]
	var samedis := []
	var mercredis := []
	for k in range(debut, fin + 1):
		if k >= int(treve[0]) and k <= int(treve[1]):
			continue
		var wd := int(date_of(k).wd)
		if wd == 6:
			samedis.append(k)
		elif wd == 3:
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
	var rounds := ClubDonnees.round_robin(noms, true)
	var dates := samedis.duplicate()
	if dates.size() < rounds.size():
		dates.append_array(mercredis)
		dates.sort()
	if dates.size() < rounds.size():
		rounds = ClubDonnees.round_robin(noms, false)
	if dates.size() < rounds.size():
		ligue.journees = []
		return
	var heure := float(ClubDonnees.division(int(ligue.division)).heure)
	var js := []
	for i in rounds.size():
		var idx := int(roundf(float(i) * float(dates.size() - 1) / float(maxi(rounds.size() - 1, 1))))
		if rounds.size() == 1:
			idx = 0
		var dd := int(dates[idx])
		var h := heure if int(date_of(dd).wd) == 6 else 20.0
		js.append({"n": i + 1, "d": dd, "h": h, "matchs": rounds[i], "scores": [], "joue": false, "prepare": false, "mon": {}})
	ligue.journees = js


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


## Tire un match : {buts: [{min, side, buteur}], score: [d, e]}.
func simuler(dom: String, ext: String, r: RandomNumberGenerator) -> Dictionary:
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


func _buteur(r: RandomNumberGenerator) -> String:
	var xi := onze()
	var poids := {"G": 0.0, "D": 0.5, "M": 1.6, "A": 4.0}
	var tot := 0.0
	for o in xi:
		tot += float(poids[String(o.poste)]) * float(joueurs[int(o.id)].note)
	if tot <= 0.0:
		return ""
	var u := r.randf() * tot
	for o in xi:
		u -= float(poids[String(o.poste)]) * float(joueurs[int(o.id)].note)
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
	var div := ClubDonnees.division(int(club.division))
	var prix := maxf(float(club.prix), 0.5)
	var pf := clampf(pow(float(div.prix) / prix, 1.3), 0.12, 1.9)
	var ext := float(club.supporters) * (1.0 + int(club.division) * 0.5)
	return mini(cap, int((locaux + ext) * attrait * pf))


func _fans_locaux() -> int:
	if fans_force >= 0:
		return fans_force
	if population == null:
		return 0
	var n := 0.0
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		if (p.get("hob", []) as Array).has("football"):
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
		"ligue": true, "score": [0, 0], "annonces": 0, "club": true, "cdom": club.couleurs, "cext": ext.get("couleurs", ["f2f2f2", "1b1b1b"])}
	var pos := Stades.pelouse_monde(buildings, bid).centre as Vector3
	j.ev = ev.ajouter("match", "%s, %de journée : %s – %s" % [ClubDonnees.division(int(club.division)).nom, int(j.n), String(m[0]), String(m[1])],
		kick - Matchs.AVANT, kick + Matchs.DUREE, pos, bid, data)


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
		_compter(String(m[0]), int(sc[0]), int(sc[1]))
		_compter(String(m[1]), int(sc[1]), int(sc[0]))
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


func _compter(nom: String, pour: int, contre: int) -> void:
	if not ligue.clubs.has(nom):
		return
	var c: Dictionary = ligue.clubs[nom]
	c.j = int(c.j) + 1
	c.bp = int(c.bp) + pour
	c.bc = int(c.bc) + contre
	if pour > contre:
		c.g = int(c.g) + 1
		c.pts = int(c.pts) + 3
	elif pour == contre:
		c.n = int(c.n) + 1
		c.pts = int(c.pts) + 1
	else:
		c.p = int(c.p) + 1


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
		p.fatigue = minf(float(p.fatigue) + 0.3, 1.0)
		p.forme = clampf(float(p.forme) + (0.07 if issue == "V" else (-0.05 if issue == "D" else 0.0)) + rng.randf_range(-0.05, 0.05), 0.2, 1.0)
		if rng.randf() < 0.018 * float(tr[2]):
			p.blesse = rng.randi_range(5, 45)
			_news("%s se blesse pendant le match (absent %d jours)." % [nom_joueur(p), int(p.blesse)])
	var noms_buteurs := []
	for b in res.buts:
		var bid := String(b.buteur)
		if bid != "" and joueurs.has(int(bid)):
			var p: Dictionary = joueurs[int(bid)]
			p.buts = int(p.buts) + 1
			p.buts_saison = int(p.buts_saison) + 1
			noms_buteurs.append(String(p.nom))
	# Réputation et supporters.
	var delta_rep := 0.8 if issue == "V" else (-0.5 if issue == "D" else 0.1)
	club.reputation = clampf(float(club.reputation) + delta_rep, 0.0, 100.0)
	club.supporters = maxf(float(club.supporters) * (1.02 if issue == "V" else (0.985 if issue == "D" else 1.0)) + (6.0 if issue == "V" else 0.0), 30.0)
	var adv := String(m[1]) if dom else String(m[0])
	var txt := "%s %d – %d %s" % [String(m[0]), int(sc[0]), int(sc[1]), String(m[1])]
	if not noms_buteurs.is_empty():
		txt += " (buts : %s)" % ", ".join(noms_buteurs)
	if dom:
		var aff := int(j.get("affluence", 0))
		var billets := aff * float(club.prix)
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
		var ref := float(ClubDonnees.division(int(club.division)).prix)
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
	var d := ClubDonnees.division(div)
	var rg := rang()
	var n := cl.size()
	var prime := float(d.titre) * pow(0.82, rg - 1)
	_flux("Prime de classement", prime)
	var issue := "maintien"
	if rg <= int(d.monte) and div < ClubDonnees.DIVISIONS.size() - 1:
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
			txt += " et monte en %s !" % ClubDonnees.division(div + 1).nom
			club.reputation = minf(float(club.reputation) + 8.0, 100.0)
			club.supporters = float(club.supporters) * 1.4
			_penser("montee", [], 5)
		"descente":
			txt += " et descend en %s." % ClubDonnees.division(div - 1).nom
			club.reputation = maxf(float(club.reputation) - 6.0, 0.0)
			_penser("descente", [], 5)
		_:
			txt += "."
	_news(txt)


## Bilan de la saison passée (appelé au début de la suivante) : montée,
## descente, fins de contrat, retraites.
func _fin_saison() -> void:
	var issue := String(club.get("issue", "maintien"))
	if issue == "montee":
		club.division = mini(int(club.division) + 1, ClubDonnees.DIVISIONS.size() - 1)
	elif issue == "descente":
		club.division = maxi(int(club.division) - 1, 0)
	club.erase("issue")
	club.prix = maxf(float(club.prix), float(ClubDonnees.division(int(club.division)).prix) * 0.6)
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
	var txt := String(ClubDonnees.PENSEES.get(cle, ""))
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
	return "%s : %de de %s, caisse %s" % [String(club.nom), rang(), ClubDonnees.division(int(club.division)).nom, BuildingSystem.format_money(int(club.caisse))]


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
	return {"club": club.duplicate(true), "joueurs": js, "marche": marche.duplicate(true), "ligue": lg, "journal": journal.duplicate(true),
		"pensees": pensees.duplicate(), "next_id": next_id, "last_day": last_day}


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
	_ints(club, ["stade", "fonde", "division"])
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
			for b in mon.buts:
				_ints(b, ["min", "side"])
	journal = (d.get("journal", []) as Array).duplicate(true)
	for e in journal:
		e.d = int(e.d)
	for k in d.get("pensees", {}):
		pensees[k] = int(d.pensees[k])
	next_id = maxi(int(d.get("next_id", 1)), 1)
	for id in joueurs:
		next_id = maxi(next_id, int(id) + 1)
	last_day = int(d.get("last_day", -1))
	changed.emit()
