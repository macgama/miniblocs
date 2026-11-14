class_name Spectacles
extends Node3D
## Spectacles : cinémas, salles de concert, théâtres et studios de cinéma.
##
## - Salles (SpectaclesTypes, rôle « salle ») : chaque soir de spectacle, le
##   public vient selon la notoriété de l'artiste, le goût des habitants pour
##   le genre (selon leur âge), le jour, la saison, le prix du billet, la note
##   de la salle et ce qui se joue ailleurs ce soir-là. Les stars attirent aussi
##   la région. Recettes : billets et bar ; charges : cachet, technique,
##   droits d'auteur (9 %), salaires. En plein air : fermé l'hiver, annulé
##   sous la pluie. Programmation à la main (menu Spectacles → Programmer) ou
##   automatique (par défaut).
## - Cinémas : quatre séances par jour, les films à l'affiche (sorties chaque
##   mercredi, plus les films de tes studios). La moitié du billet va au
##   distributeur… ou à tes studios si c'est ton film.
## - Studios : on produit des films (genre, budget, réalisateur, tête
##   d'affiche). Préparation, tournage (un plateau par film), post-production,
##   puis 8 semaines en salle dans tout le pays et les droits télé. La qualité
##   dépend du talent, des décors, des effets spéciaux, du montage, et d'un
##   peu de chance. Festival de la Bobine d'or chaque 20 mai.
## L'argent passe par la caisse de la ville du bâtiment (BudgetCommunal).

signal changed
signal message(text: String)

static var instance: Spectacles

const STEP := 3600.0
const RAYON_STUDIO := 300.0
const SALAIRE_MOYEN := 2150.0
const DROITS := 0.09
const BAR := {"concert": 3.5, "theatre": 2.5, "cinema": 0.0}
const CONFISERIE := 2.8
const PART_DISTRIBUTEUR := 0.5
const PRIX_ENTREE_PAYS := 2.6
const SEMAINES_SALLE := 8
const HORIZON := 10
## Perte attendue qu'un directeur de salle accepte pour ne pas fermer un soir.
const PERTE_ACCEPTEE := 3000.0
## Séances de cinéma : heure → part du public de la journée.
const SEANCES := {14: 0.15, 17: 0.2, 20: 0.4, 22: 0.25}
const SEANCES_ART := {14: 0.2, 18: 0.35, 20: 0.45}
const SEANCES_PLEIN_AIR := {22: 1.0}
const NOMS := {"cinema": ["Le Rex", "Ciné Lumière", "L'Odyssée", "Le Palace", "Le Grand Écran", "Cinéma des Arcades"],
	"concert": ["La Sirène", "Le Hangar", "L'Écho", "La Rotonde", "Le Volume", "L'Onde"],
	"theatre": ["Théâtre du Rond-Point", "Le Grand Théâtre", "Théâtre des Tilleuls", "La Comédie", "Théâtre de la Ville", "L'Atelier"],
	"studio": ["Studios des Collines", "Studios Lumière Nord", "Studios du Lac", "Studios de la Plaine"]}

const PENSEES := {
	"complet": "« Complet ! J'ai eu la dernière place, au fond, derrière un pilier. »",
	"star": "« J'ai vu %s en vrai ! Je ne m'en remets pas. »",
	"super": "« Quelle soirée ! On en parle encore à la sortie. »",
	"bof": "« Bof. Le spectacle était moins bien que l'affiche. »",
	"cher": "« %d € la place… J'espère que l'entracte est inclus. »",
	"bon_prix": "« À ce prix-là, on reviendra le mois prochain. »",
	"acoustique": "« Le son de cette salle, c'est autre chose. »",
	"mauvais_son": "« On n'entendait rien du fond, l'acoustique est à revoir. »",
	"inconfort": "« Deux heures sur ces sièges, mon dos s'en souvient. »",
	"confort": "« Des fauteuils moelleux, on s'y endormirait (je me suis endormi). »",
	"annule": "« Annulé pour cause de pluie. On a mangé les sandwichs dans la voiture. »",
	"bouchons": "« Une heure pour se garer. La prochaine fois, je prends le tram. »",
	"film_local": "« Le film a été tourné chez nous, j'ai reconnu la boulangerie ! »",
	"popcorn": "« Le seau de pop-corn géant, c'est l'essentiel du film. »",
	"vide": "« On était douze dans la salle. Ambiance intime. »",
	"enfants": "« Les enfants ont adoré, ils ont crié tout le long. »",
	"festival": "« Trois jours de festival, de la boue jusqu'aux genoux, le bonheur. »",
	"pas_de_salle": "« Il n'y a rien à faire le soir dans cette ville. »",
	"noel": "« Casse-Noisette en décembre, c'est la tradition. »",
}

var buildings: BuildingSystem
var population: Population
var ambiance: DayNight
var transport: TransportSystem

## bid → état de la salle.
var salles: Dictionary = {}
## bid → état du studio.
var studios: Dictionary = {}
## Films (à l'affiche ou produits par tes studios) : id → film.
var films: Dictionary = {}
var next_film := 1
var clock := -1.0
var last_unix := -1.0
var last_day := -1
var rng := RandomNumberGenerator.new()
var visuels: SpectaclesVisuels
## Habitants allés au spectacle : pid → jour.
var sorties: Dictionary = {}
## Parts d'âge des habitants [enfants, jeunes, adultes, seniors] (mises à jour chaque jour).
var ages := [0.15, 0.25, 0.4, 0.2]
## Pour les tests : ignorer le personnel (fermé faute d'employés).
var ignore_staff := false
## Pour les tests et les bancs : nombre d'habitants imposé (−1 = la vraie population).
var habitants_force := -1
var _dirty := true
var _warned: Dictionary = {}


func _init() -> void:
	rng.seed = 7_070_707
	add_to_group("avis_sources")


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	visuels = SpectaclesVisuels.new()
	visuels.name = "Public"
	visuels.setup(self)
	add_child(visuels)


func setup(b: BuildingSystem, p: Population, a: DayNight, t: TransportSystem = null) -> void:
	buildings = b
	population = p
	ambiance = a
	transport = t
	if buildings != null:
		buildings.changed.connect(func() -> void: _dirty = true)


func clear() -> void:
	salles.clear()
	studios.clear()
	films.clear()
	sorties.clear()
	next_film = 1
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	_dirty = true
	changed.emit()


# --- Quels lieux ? ----------------------------------------------------------------------------

static func _empty_stats() -> Dictionary:
	return {"spectateurs": 0, "representations": 0, "complets": 0, "annulations": 0, "billets": 0.0, "bar": 0.0, "depenses": 0.0, "refus": 0}


func _new_salle(bid: int, spec: Dictionary) -> Dictionary:
	var noms: Array = NOMS[String(spec.famille)]
	return {"nom": String(noms[absi(hash(bid)) % noms.size()]), "prix": float(spec.get("prix", 15.0)), "auto": true, "agenda": [],
		"jour": _empty_stats(), "hier": _empty_stats(), "total": _empty_stats(), "pensees": {}, "dernieres": [],
		"reputation": 3.0, "historique": [], "vus": {}, "affiche_forcee": -1, "argent": 0.0, "ouvert": true}


func _new_studio(bid: int) -> Dictionary:
	var noms: Array = NOMS.studio
	return {"nom": String(noms[absi(hash(bid)) % noms.size()]), "reputation": 20.0, "prix": [], "argent": 0.0}


func _sync() -> void:
	_dirty = false
	if buildings == null:
		return
	var seen_s := {}
	var seen_st := {}
	for bid in buildings.buildings:
		var spec := SpectaclesTypes.spec_of(String(buildings.buildings[bid].t))
		match String(spec.get("role", "")):
			"salle":
				seen_s[int(bid)] = spec
			"studio":
				seen_st[int(bid)] = true
	for bid in seen_s:
		if not salles.has(bid):
			salles[bid] = _new_salle(int(bid), seen_s[bid])
	for bid in salles.keys():
		if not seen_s.has(bid):
			salles.erase(bid)
	for bid in seen_st:
		if not studios.has(bid):
			studios[bid] = _new_studio(int(bid))
	for bid in studios.keys():
		if not seen_st.has(bid):
			studios.erase(bid)
	_assurer_films()


## Toujours quelques films à l'affiche (au début d'une partie, après un long arrêt).
func _assurer_films() -> void:
	if films_affiche_monde().size() < 6:
		_semer_films()


func list_salles(famille := "") -> Array:
	if _dirty:
		_sync()
	var out: Array = []
	for bid in salles:
		if famille == "" or famille_of(int(bid)) == famille:
			out.append(int(bid))
	out.sort()
	return out


func list_studios() -> Array:
	if _dirty:
		_sync()
	var out: Array = studios.keys()
	out.sort()
	return out


func type_of(bid: int) -> String:
	if buildings == null or not buildings.buildings.has(bid):
		return ""
	return String(buildings.buildings[bid].t)


func spec(bid: int) -> Dictionary:
	return SpectaclesTypes.spec_of(type_of(bid))


func famille_of(bid: int) -> String:
	return String(spec(bid).get("famille", ""))


func places(bid: int) -> int:
	var s := spec(bid)
	var p := int(s.get("places", 0))
	# Un modèle de l'atelier garde le rapport de surface de sa fonction.
	var t := BuildingCatalog.get_type(type_of(bid))
	var ref := BuildingCatalog.get_type(BuildingCatalog.base_of(type_of(bid)))
	if t.has("modele") and not ref.is_empty():
		var r := clampf(float(t.w) * float(t.d) / maxf(1.0, float(ref.w) * float(ref.d)), 0.25, 4.0)
		p = int(round(p * r))
	return p


func nom(bid: int) -> String:
	if salles.has(bid):
		return String(salles[bid].nom)
	if studios.has(bid):
		return String(studios[bid].nom)
	return ""


func renommer(bid: int, n: String) -> void:
	n = n.strip_edges()
	if n == "":
		return
	if salles.has(bid):
		salles[bid].nom = n
	elif studios.has(bid):
		studios[bid].nom = n
	changed.emit()


func set_prix(bid: int, prix: float) -> void:
	if salles.has(bid):
		salles[bid].prix = clampf(prix, 0.0, 250.0)
		changed.emit()


func set_auto(bid: int, on: bool) -> void:
	if salles.has(bid):
		salles[bid].auto = on
		if on:
			_auto_programmer(bid, _today())
		changed.emit()


func centre(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)


func porte(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.door_point(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0))) + Vector3(0, float(b.get("h", 0.0)), 0)


func en_chantier(bid: int) -> bool:
	return buildings != null and buildings.buildings.has(bid) and buildings.en_chantier(bid)


func sans_personnel(bid: int) -> bool:
	if ignore_staff or population == null or population.effectif == null:
		return false
	return population.effectif.ferme(bid)


## Note de la salle (0–5 étoiles) : confort, acoustique et réputation.
func note(bid: int) -> float:
	var s := spec(bid)
	var base := 1.2 + float(s.get("confort", 0.5)) * 1.6 + float(s.get("acoustique", 0.5)) * 1.2
	var rep := float(salles[bid].reputation) if salles.has(bid) else 3.0
	return clampf(base + (rep - 3.0) * 0.5, 0.5, 5.0)


# --- Temps ------------------------------------------------------------------------------------

func _now(t: float) -> Dictionary:
	var off := ambiance.utc_offset() if ambiance != null else 0.0
	var local := t + off * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	return {"h": fposmod(local, 86400.0) / 3600.0, "wd": int(dt.weekday), "month": int(dt.month), "day": int(floorf(local / 86400.0)),
		"mday": int(dt.day), "year": int(dt.year)}


## Date d'un jour (numéro de jour local depuis 1970).
func date_of(day: int) -> Dictionary:
	var dt := Time.get_datetime_dict_from_unix_time(day * 86400 + 43200)
	return {"wd": int(dt.weekday), "month": int(dt.month), "mday": int(dt.day), "day": day, "year": int(dt.year)}


func _today() -> int:
	if last_day >= 0:
		return last_day
	var t := ambiance.unix_time if ambiance != null else clock
	return int(_now(maxf(t, 0.0)).day)


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
	if _dirty:
		_sync()
	var end_t := (ambiance.unix_time if ambiance != null else clock + dt)
	if clock < 0.0 or absf(end_t - dt - clock) > 86400.0 * 3.0:
		clock = end_t - dt
	if last_day < 0:
		last_day = int(_now(clock).day)
		_nouveau_jour_programmes()
	var n := 0
	while clock + STEP <= end_t + 0.001 and n < 96:
		clock += STEP
		n += 1
		step(STEP)
	if clock < end_t - 86400.0:
		clock = end_t


func step(_dt: float) -> void:
	if _dirty:
		_sync()
	var now := _now(clock)
	if int(now.day) > last_day:
		last_day = int(now.day)
		new_day(now)
	var h := int(floorf(float(now.h)))
	for bid in salles:
		var b := int(bid)
		if famille_of(b) == "cinema":
			_seance(b, now, h)
		else:
			_soiree(b, now, h)
	changed.emit()


func _pluie() -> float:
	if ambiance == null or ambiance.weather == null:
		return 0.0
	return clampf(float(ambiance.weather.precip), 0.0, 1.0)


## Saison du plein air (mai–septembre ; cinéma en plein air juin–septembre).
func saison_ouverte(bid: int, month: int) -> bool:
	var s := spec(bid)
	if not bool(s.get("plein_air", false)):
		return true
	if famille_of(bid) == "cinema" and not bool(s.get("abrite", false)):
		return month >= 6 and month <= 9
	return month >= 5 and month <= 9


## Heures de représentation d'un genre ce jour-là dans cette salle ([] = relâche).
func creneaux(bid: int, date: Dictionary, genre: String) -> Array:
	var s := spec(bid)
	var wd := int(date.wd)
	if not saison_ouverte(bid, int(date.month)):
		return []
	if bool(s.get("festival", false)):
		return [20] if wd in [5, 6] else []
	match famille_of(bid):
		"concert":
			if float(s.get("prix", 1.0)) <= 0.0:
				# Kiosque : concerts gratuits le dimanche après-midi.
				return [16] if wd == 0 else []
			return [20] if wd in [3, 4, 5, 6] else []
		"theatre":
			if genre in ["cirque", "marionnettes"]:
				if wd == 3:
					return [15]
				if wd == 6:
					return [15, 20] if genre == "cirque" else [15]
				if wd == 0:
					return [15]
				return [20] if genre == "cirque" and wd == 5 else []
			if wd == 1:
				return []
			return [16] if wd == 0 else [20]
	return []


# --- Programmation des salles -----------------------------------------------------------------

## Une tournée peut-elle jouer ici ? "" ou la raison.
func compatible(bid: int, sp: String) -> String:
	if not SpectaclesProgrammes.TOURNEES.has(sp):
		return "spectacle inconnu"
	var e: Array = SpectaclesProgrammes.TOURNEES[sp]
	var s := spec(bid)
	if not (s.get("genres", []) as Array).has(String(e[1])):
		return "pas de %s dans cette salle" % SpectaclesProgrammes.genre_name(String(e[1])).to_lower()
	if int(e[4]) > places(bid):
		return "%s ne joue pas dans une salle de moins de %d places" % [String(e[0]), int(e[4])]
	return ""


func agenda(bid: int) -> Array:
	return salles[bid].agenda if salles.has(bid) else []


func _occupe(bid: int, day: int, h: int) -> bool:
	for ev in agenda(bid):
		if int(ev.d) == day and (h < 0 or int(ev.h) == h):
			return true
	return false


## L'artiste joue-t-il déjà ailleurs ce jour-là ?
func _en_tournee_ailleurs(sp: String, day: int, sauf: int) -> bool:
	for bid in salles:
		if int(bid) == sauf:
			continue
		for ev in salles[bid].agenda:
			if int(ev.d) == day and String(ev.sp) == sp:
				return true
	return false


## Programme n dates d'une tournée à partir du jour `depuis` (premiers créneaux
## libres). Rend le nombre de dates posées, ou −1 si impossible.
func programmer(bid: int, sp: String, n := 1, depuis := -1) -> int:
	if not salles.has(bid) or compatible(bid, sp) != "":
		return -1
	var genre := String(SpectaclesProgrammes.TOURNEES[sp][1])
	var day := depuis if depuis >= 0 else _today() + 1
	var poses := 0
	var essais := 0
	while poses < n and essais < 60:
		var date := date_of(day)
		var hs := creneaux(bid, date, genre)
		if not hs.is_empty() and not _occupe(bid, day, -1) and not _en_tournee_ailleurs(sp, day, bid):
			for h in hs:
				(salles[bid].agenda as Array).append({"d": day, "h": int(h), "sp": sp, "auto": false})
			poses += 1
		day += 1
		essais += 1
	_trier(bid)
	changed.emit()
	return poses


func annuler(bid: int, index: int) -> void:
	if not salles.has(bid):
		return
	var ag: Array = salles[bid].agenda
	if index >= 0 and index < ag.size():
		var ev: Dictionary = ag[index]
		# Annuler moins de 7 jours avant : la moitié du cachet est due.
		if int(ev.d) - _today() < 7:
			_payer(bid, "Spectacles : dédits", float(SpectaclesProgrammes.TOURNEES[String(ev.sp)][3]) * 0.5)
		ag.remove_at(index)
		changed.emit()


func _trier(bid: int) -> void:
	(salles[bid].agenda as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.d) * 100 + int(a.h) < int(b.d) * 100 + int(b.h))


## Remplit les soirées libres des HORIZON prochains jours avec ce qui rapporte
## le plus (en variant les plaisirs).
func _auto_programmer(bid: int, today: int) -> void:
	if not salles.has(bid) or not bool(salles[bid].auto) or famille_of(bid) == "cinema":
		return
	var st: Dictionary = salles[bid]
	var recents := {}
	for hh in st.historique:
		recents[String(hh.sp)] = int(recents.get(String(hh.sp), 0)) + 1
	for ev in st.agenda:
		recents[String(ev.sp)] = int(recents.get(String(ev.sp), 0)) + 1
	var day := today + 1
	while day <= today + HORIZON:
		if _occupe(bid, day, -1):
			day += 1
			continue
		var date := date_of(day)
		var best := ""
		# Une petite perte est acceptée : une salle vide coûte aussi (salaires).
		var best_score := -PERTE_ACCEPTEE
		for sp in SpectaclesProgrammes.TOURNEES:
			if compatible(bid, String(sp)) != "":
				continue
			var hs := creneaux(bid, date, String(SpectaclesProgrammes.TOURNEES[sp][1]))
			if hs.is_empty() or _en_tournee_ailleurs(String(sp), day, bid):
				continue
			var est := estimation(bid, String(sp), date)
			var k := int(recents.get(sp, 0))
			var score := float(est.benefice)
			score = score * pow(0.55, k) if score > 0.0 else score - 800.0 * k
			if score > best_score:
				best_score = score
				best = String(sp)
		if best != "":
			# Les pièces se jouent plusieurs soirs de suite ; un concert, un soir.
			var genre := String(SpectaclesProgrammes.TOURNEES[best][1])
			var serie := 1
			if SpectaclesProgrammes.GENRES[genre].famille == "theatre" and not genre in ["humour"]:
				serie = 3
			var poses := programmer(bid, best, serie, day)
			for ev in st.agenda:
				if String(ev.sp) == best:
					ev.auto = true
			recents[best] = int(recents.get(best, 0)) + maxi(poses, 1)
		day += 1


func _nouveau_jour_programmes() -> void:
	var today := _today()
	_assurer_films()
	for bid in salles:
		var st: Dictionary = salles[bid]
		var ag: Array = st.agenda
		for i in range(ag.size() - 1, -1, -1):
			if int(ag[i].d) < today:
				ag.remove_at(i)
		_auto_programmer(int(bid), today)


# --- Public -----------------------------------------------------------------------------------

## Goût de la ville pour un genre (selon l'âge des habitants), autour de 1.
func gout(genre: String) -> float:
	if not SpectaclesProgrammes.GENRES.has(genre):
		return 1.0
	var g: Array = SpectaclesProgrammes.GENRES[genre].gout
	var s := 0.0
	for i in 4:
		s += float(ages[i]) * float(g[i])
	return s


func _majs_ages() -> void:
	if population == null or population.persons.is_empty():
		return
	var c := [0.0, 0.0, 0.0, 0.0]
	var n := 0
	for pid in population.persons:
		var a := population.age_of(population.persons[pid])
		c[0 if a < 12.0 else (1 if a < 30.0 else (2 if a < 60.0 else 3))] += 1.0
		n += 1
		if n >= 3000:
			break
	for i in 4:
		ages[i] = c[i] / float(n)


func habitants() -> int:
	if habitants_force >= 0:
		return habitants_force
	return population.persons.size() if population != null else 0


## Public attendu pour une tournée un jour donné (avant la limite de places).
func demande(bid: int, sp: String, date: Dictionary) -> float:
	var e: Array = SpectaclesProgrammes.TOURNEES[sp]
	var s := spec(bid)
	var genre := String(e[1])
	var n := float(e[2])
	var pop := float(habitants())
	var g := gout(genre)
	var local := pop * 0.022 * pow(n / 50.0, 1.4) * g
	var region := pow(n / 100.0, 3.0) * 25000.0 * clampf((pop + 2000.0) / 30000.0, 0.08, 1.5) * g
	if bool(s.get("regional", false)):
		region *= 1.5
	var f := 1.0
	match int(date.wd):
		5: f = 1.3
		6: f = 1.5
		0: f = 1.05
		3: f = 0.9 if not genre in ["marionnettes", "cirque"] else 1.3
		_: f = 0.8
	var month := int(date.month)
	if bool(s.get("plein_air", false)):
		f *= 1.3 if month in [6, 7, 8] else 0.9
	elif month in [7, 8]:
		f *= 0.75
	if bool(s.get("festival", false)):
		f *= 1.6
	if sp == "casse_noisette" and month == 12:
		f *= 1.6
	var st: Dictionary = salles.get(bid, {})
	var prix := float(st.get("prix", s.get("prix", 15.0)))
	var ref := SpectaclesProgrammes.prix_ref(sp)
	var px := 1.6 if prix <= 0.0 else clampf(1.6 - 0.6 * prix / ref, 0.15, 1.5)
	var nf := 0.6 + note(bid) / 5.0 * 0.6 if salles.has(bid) else 1.0
	var pot := local + region
	var deja := float((st.get("vus", {}) as Dictionary).get(sp, 0.0))
	var fv := clampf(1.0 - deja / (pot * 5.0 + 1.0), 0.25, 1.0)
	# Les autres salles de la même famille qui jouent ce soir-là.
	var autres := 0
	for b2 in salles:
		if int(b2) != bid and famille_of(int(b2)) == famille_of(bid) and _occupe(int(b2), int(date.day), -1):
			autres += 1
	return pot * f * px * nf * fv / (1.0 + 0.25 * autres)


## Estimation d'une date : {public, recettes, cachet, benefice}.
func estimation(bid: int, sp: String, date: Dictionary) -> Dictionary:
	var e: Array = SpectaclesProgrammes.TOURNEES[sp]
	var p := minf(demande(bid, sp, date), float(places(bid)))
	var prix := float(salles[bid].prix) if salles.has(bid) else 15.0
	var fam := famille_of(bid)
	var billets := p * prix
	var rec := billets + p * float(BAR.get(fam, 0.0)) * 0.6
	var cout := float(e[3]) + _technique(bid) + billets * DROITS
	return {"public": roundi(p), "recettes": rec, "cachet": float(e[3]), "benefice": rec - cout}


func _technique(bid: int) -> float:
	return 600.0 + float(places(bid)) * 0.8


func _arrondi(x: float) -> int:
	var b := int(floorf(x))
	return b + (1 if rng.randf() < x - b else 0)


func _ouverte(bid: int) -> bool:
	if not salles.has(bid) or not bool(salles[bid].ouvert) or en_chantier(bid):
		return false
	if sans_personnel(bid):
		_warn("pers%d" % bid, "%s : fermé faute de personnel. Il faut des habitants pour y travailler." % nom(bid), 86400.0 * 3.0)
		return false
	return true


## Représentation de l'heure h, s'il y en a une.
func _soiree(bid: int, now: Dictionary, h: int) -> void:
	var st: Dictionary = salles[bid]
	var ev: Dictionary = {}
	for e in st.agenda:
		if int(e.d) == int(now.day) and int(e.h) == h:
			ev = e
			break
	if ev.is_empty():
		return
	(st.agenda as Array).erase(ev)
	jouer(bid, String(ev.sp), now)


## Joue une représentation maintenant : public, recettes, charges, avis.
func jouer(bid: int, sp: String, now: Dictionary) -> Dictionary:
	var st: Dictionary = salles[bid]
	var s := spec(bid)
	var e: Array = SpectaclesProgrammes.TOURNEES[sp]
	var res := {"sp": sp, "d": int(now.day), "public": 0, "recette": 0.0, "annule": false}
	if not _ouverte(bid):
		res.annule = true
		return res
	if bool(s.get("plein_air", false)) and not bool(s.get("abrite", false)) and _pluie() > 0.35:
		st.jour.annulations = int(st.jour.annulations) + 1
		_payer(bid, "Spectacles : dédits", float(e[3]) * 0.5)
		_penser(bid, "annule")
		message.emit("%s : « %s » annulé à cause de la pluie (la moitié du cachet est due)." % [nom(bid), String(e[0])])
		res.annule = true
		return res
	var dem := demande(bid, sp, now) * rng.randf_range(0.85, 1.15)
	var cap := float(places(bid))
	var n := mini(_arrondi(dem), int(cap))
	var complet := dem >= cap
	if complet:
		st.jour.complets = int(st.jour.complets) + 1
		st.jour.refus = int(st.jour.refus) + roundi(dem - cap)
	var prix := float(st.prix)
	var fam := famille_of(bid)
	var billets := float(n) * prix
	var bar := float(n) * float(BAR.get(fam, 0.0)) * 0.6
	if fam == "concert":
		bar += float(n) * 2.0 * float(e[2]) / 100.0
	if billets > 0.0:
		_encaisser(bid, "billets", billets)
	if bar > 0.0:
		_encaisser(bid, "bar", bar)
	_payer(bid, "Spectacles : cachets", float(e[3]))
	_payer(bid, "Spectacles : technique", _technique(bid))
	if billets > 0.0:
		_payer(bid, "Spectacles : droits d'auteur", billets * DROITS)
	st.jour.spectateurs = int(st.jour.spectateurs) + n
	st.jour.representations = int(st.jour.representations) + 1
	var vus: Dictionary = st.vus
	vus[sp] = float(vus.get(sp, 0.0)) + n
	_sorties(n)
	# Ce qu'en pense le public : la réputation de la salle suit.
	var ref := SpectaclesProgrammes.prix_ref(sp)
	var sat := 2.2 + float(e[2]) / 100.0 * 1.6 + (float(s.get("acoustique", 0.5)) - 0.5) * 1.4 + (float(s.get("confort", 0.5)) - 0.5) \
		- maxf(0.0, prix / ref - 1.0) * 1.5 + (0.2 if complet else 0.0) + rng.randf_range(-0.4, 0.4)
	sat = clampf(sat, 0.5, 5.0)
	st.reputation = lerpf(float(st.reputation), sat, 0.1)
	var w := maxi(1, n / 50)
	if complet:
		_penser(bid, "complet", [], w)
	if float(e[2]) >= 70.0:
		_penser(bid, "star", [String(e[0])], w)
	if sat >= 3.8:
		_penser(bid, "super", [], w)
	elif sat < 2.4:
		_penser(bid, "bof", [], w)
	if prix > ref * 1.3:
		_penser(bid, "cher", [roundi(prix)], w)
	elif prix > 0.0 and prix < ref * 0.7:
		_penser(bid, "bon_prix", [], w)
	if float(s.get("acoustique", 0.5)) >= 0.9:
		_penser(bid, "acoustique", [], w)
	elif float(s.get("acoustique", 0.5)) < 0.5:
		_penser(bid, "mauvais_son", [], w)
	if float(s.get("confort", 0.5)) < 0.45:
		_penser(bid, "inconfort", [], w)
	if n < 20:
		_penser(bid, "vide")
	if String(e[1]) in ["marionnettes", "cirque"]:
		_penser(bid, "enfants", [], w)
	if bool(s.get("festival", false)):
		_penser(bid, "festival", [], w)
	if sp == "casse_noisette" and int(now.month) == 12:
		_penser(bid, "noel", [], w)
	if n > 3000:
		_penser(bid, "bouchons", [], w)
	var recette := billets + bar
	res.public = n
	res.recette = recette
	res.cout = float(e[3]) + _technique(bid) + billets * DROITS
	var hist: Array = st.historique
	hist.push_front({"sp": sp, "d": int(now.day), "public": n, "places": int(cap), "recette": roundi(recette), "cout": roundi(float(res.cout)), "sat": snappedf(sat, 0.1)})
	if hist.size() > 12:
		hist.resize(12)
	if complet and float(e[2]) >= 60.0:
		message.emit("%s : complet pour %s ! %d spectateurs." % [nom(bid), String(e[0]), n])
	return res


# --- Cinémas ----------------------------------------------------------------------------------

func seances(bid: int) -> Dictionary:
	var s := spec(bid)
	if bool(s.get("plein_air", false)):
		return SEANCES_PLEIN_AIR
	if bool(s.get("art_essai", false)):
		return SEANCES_ART
	return SEANCES


## Attrait d'un film aujourd'hui (0 quand il quitte l'affiche).
func attrait(f: Dictionary, day: int) -> float:
	if String(f.get("phase", "salle")) != "salle":
		return 0.0
	var sem := floorf(float(day - int(f.sortie)) / 7.0)
	if sem < 0.0 or sem >= 10.0:
		return 0.0
	return float(f.pop) * pow(0.74, sem) * (0.5 + float(f.q) / 100.0)


func films_affiche_monde(day := -1) -> Array:
	if day < 0:
		day = _today()
	var out: Array = []
	for id in films:
		if attrait(films[id], day) > 0.0:
			out.append(int(id))
	return out


## Films à l'affiche d'un cinéma (autant que d'écrans), du plus attirant au moins.
func affiche(bid: int, day := -1) -> Array:
	if day < 0:
		day = _today()
	var s := spec(bid)
	var art := bool(s.get("art_essai", false))
	var scored: Array = []
	for id in films_affiche_monde(day):
		var f: Dictionary = films[id]
		var a := attrait(f, day) * (pow(float(f.q) / 60.0, 2.0) if art else 1.0)
		if bool(f.get("joueur", false)):
			a *= 1.5
		if salles.has(bid) and int(salles[bid].affiche_forcee) == int(id):
			a += 1000.0
		scored.append([a, int(id)])
	scored.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var out: Array = []
	for i in mini(int(s.get("salles", 1)), scored.size()):
		out.append(int(scored[i][1]))
	return out


func forcer_affiche(bid: int, film_id: int) -> void:
	if salles.has(bid):
		salles[bid].affiche_forcee = film_id if int(salles[bid].affiche_forcee) != film_id else -1
		changed.emit()


## Public d'un cinéma sur la journée.
func demande_cinema(bid: int, date: Dictionary) -> float:
	var s := spec(bid)
	var day := int(date.day)
	var draw := 0.0
	for id in affiche(bid, day):
		draw += attrait(films[id], day) * gout(String(films[id].genre))
	draw = minf(draw, 1.2 + 0.25 * float(int(s.get("salles", 1))))
	var pop := float(habitants())
	var f := 1.0
	match int(date.wd):
		3: f = 1.15
		5: f = 1.25
		6: f = 1.6
		0: f = 1.4
		_: f = 0.75
	var month := int(date.month)
	if bool(s.get("plein_air", false)):
		f *= 1.3 if month in [7, 8] else 1.0
	elif month in [7, 8]:
		f *= 0.85
	elif month in [11, 12, 1, 2]:
		f *= 1.15
	var st: Dictionary = salles.get(bid, {})
	var prix := float(st.get("prix", s.get("prix", 9.5)))
	var px := clampf(1.7 - prix / 13.0, 0.2, 1.5)
	var autres := 0
	for b2 in salles:
		if int(b2) != bid and famille_of(int(b2)) == "cinema":
			autres += 1
	var region := 0.0
	if bool(s.get("regional", false)):
		region = 18000.0 * 0.0045
	return (pop * 0.0045 + region) * draw * f * px * (0.6 + note(bid) / 5.0 * 0.6) / (1.0 + 0.4 * autres)


func _seance(bid: int, now: Dictionary, h: int) -> void:
	var sc := seances(bid)
	if not sc.has(h) or not saison_ouverte(bid, int(now.month)) or not _ouverte(bid):
		return
	var st: Dictionary = salles[bid]
	var s := spec(bid)
	if bool(s.get("plein_air", false)) and not bool(s.get("abrite", false)) and _pluie() > 0.35:
		st.jour.annulations = int(st.jour.annulations) + 1
		_penser(bid, "annule")
		return
	var day := int(now.day)
	var aff := affiche(bid, day)
	if aff.is_empty():
		return
	var dem := demande_cinema(bid, now) * float(sc[h]) * rng.randf_range(0.85, 1.15)
	var cap := float(places(bid))
	var n := mini(_arrondi(dem), int(cap))
	if dem > cap:
		st.jour.complets = int(st.jour.complets) + 1
		st.jour.refus = int(st.jour.refus) + roundi(dem - cap)
		_penser(bid, "complet")
	if n <= 0:
		return
	st.jour.spectateurs = int(st.jour.spectateurs) + n
	st.jour.representations = int(st.jour.representations) + 1
	_sorties(n)
	var prix := float(st.prix)
	var billets := float(n) * prix
	_encaisser(bid, "billets", billets)
	_encaisser(bid, "bar", float(n) * CONFISERIE * 0.45)
	# Les spectateurs se répartissent entre les films selon leur attrait.
	var tot := 0.0
	for id in aff:
		tot += attrait(films[id], day)
	for id in aff:
		var f: Dictionary = films[id]
		var part := attrait(f, day) / maxf(tot, 0.0001)
		var ent := float(n) * part
		f.entrees_ville = int(f.get("entrees_ville", 0)) + roundi(ent)
		var dist := ent * prix * PART_DISTRIBUTEUR
		if bool(f.get("joueur", false)) and studios.has(int(f.get("studio", -1))):
			_encaisser(int(f.studio), "films_salles", dist)
			if rng.randf() < 0.3:
				_penser(bid, "film_local")
		else:
			_payer(bid, "Spectacles : distributeurs", dist)
	var w := maxi(1, n / 50)
	if float(s.get("confort", 0.5)) >= 0.8:
		_penser(bid, "confort", [], w)
	if rng.randf() < 0.2:
		_penser(bid, "popcorn")
	var ff: Dictionary = films[aff[0]]
	var sat := 1.8 + float(ff.q) / 100.0 * 2.0 + (float(s.get("confort", 0.5)) - 0.5) * 1.5 - maxf(0.0, prix / 11.0 - 1.0) * 1.5
	st.reputation = lerpf(float(st.reputation), clampf(sat, 0.5, 5.0), 0.03)


## Les films du moment : trois sorties chaque mercredi.
func _nouvelles_sorties(day: int, n := 3) -> void:
	var genres := SpectaclesProgrammes.genres_films()
	for i in n:
		var g := String(genres[rng.randi() % genres.size()])
		var q := clampf(rng.randfn(58.0, 14.0), 15.0, 95.0)
		var blockbuster := rng.randf() < 0.18
		var pop := rng.randf_range(0.4, 1.0) * (2.4 if blockbuster else 1.0)
		_ajouter_film({"titre": SpectaclesProgrammes.titre_au_hasard(g, rng), "genre": g, "q": roundi(q), "pop": snappedf(pop, 0.01),
			"sortie": day, "joueur": false, "phase": "salle"})


func _semer_films() -> void:
	var today := _today()
	for w in 5:
		_nouvelles_sorties(today - w * 7 - 1, 2)


func _ajouter_film(f: Dictionary) -> int:
	var id := next_film
	next_film += 1
	f.id = id
	films[id] = f
	return id


func _menage_films(day: int) -> void:
	for id in films.keys():
		var f: Dictionary = films[id]
		if not bool(f.get("joueur", false)) and day - int(f.sortie) > 80:
			films.erase(id)


# --- Studios : produire un film -------------------------------------------------------------

## Annexes à moins de RAYON_STUDIO mètres d'un studio : {plateau: n, decors: {}, vfx, postprod, atelier}.
func annexes(studio: int) -> Dictionary:
	var out := {"plateau": 0, "decors": {}, "vfx": false, "postprod": false, "atelier": false}
	if buildings == null or not buildings.buildings.has(studio):
		return out
	var c := centre(studio)
	for bid in buildings.buildings:
		var sp := SpectaclesTypes.spec_of(String(buildings.buildings[bid].t))
		if String(sp.get("role", "")) != "annexe" or en_chantier(int(bid)):
			continue
		if Vector2(c.x, c.z).distance_to(Vector2(centre(int(bid)).x, centre(int(bid)).z)) > RAYON_STUDIO:
			continue
		match String(sp.annexe):
			"plateau": out.plateau = int(out.plateau) + 1
			"decor": (out.decors as Dictionary)[String(sp.decor)] = true
			"vfx": out.vfx = true
			"postprod": out.postprod = true
			"atelier": out.atelier = true
	return out


func plateaux(studio: int) -> int:
	return int(spec(studio).get("plateaux", 2)) + int(annexes(studio).plateau)


func films_du_studio(studio: int, phases: Array = []) -> Array:
	var out: Array = []
	for id in films:
		var f: Dictionary = films[id]
		if bool(f.get("joueur", false)) and int(f.get("studio", -1)) == studio and (phases.is_empty() or phases.has(String(f.phase))):
			out.append(int(id))
	out.sort()
	return out


func plateaux_libres(studio: int) -> int:
	return plateaux(studio) - films_du_studio(studio, ["prep", "tournage"]).size()


## Décor qui sert ce genre (s'il y en a un).
static func decor_pour(genre: String) -> String:
	for d in SpectaclesProgrammes.DECOR_GENRES:
		if (SpectaclesProgrammes.DECOR_GENRES[d] as Array).has(genre):
			return String(d)
	return ""


## Devis d'un film : {budget, cachets, total, jours, post, conseils}.
func devis(studio: int, genre: String, budget: String, real: String, star: String) -> Dictionary:
	var b: Array = SpectaclesProgrammes.BUDGETS.get(budget, SpectaclesProgrammes.BUDGETS.petit)
	var an := annexes(studio)
	var montant := float(b[1])
	var conseils: Array = []
	if bool(an.atelier):
		montant *= 0.88
	var dec := decor_pour(genre)
	var a_decor := dec != "" and (an.decors as Dictionary).has(dec)
	if dec != "" and not a_decor:
		montant *= 1.15
		conseils.append("Sans décor de %s, on tourne en extérieur : 15 %% plus cher et moins bien." % _decor_nom(dec))
	if genre in ["sf", "animation"] and not bool(an.vfx):
		conseils.append("Sans studio d'effets spéciaux, la science-fiction et l'animation perdent beaucoup.")
	if not bool(an.postprod):
		conseils.append("Une salle de post-production raccourcit le montage et améliore le film.")
	var cachets := float(SpectaclesProgrammes.REALISATEURS[real][2]) + float(SpectaclesProgrammes.STARS[star][2])
	var jours := int(b[2])
	if a_decor:
		jours = maxi(3, roundi(jours * 0.85))
	var post := int(b[3])
	if bool(an.postprod):
		post = maxi(2, roundi(post * 0.6))
	return {"budget": roundf(montant), "cachets": cachets, "total": roundf(montant + cachets), "jours": jours, "post": post, "conseils": conseils}


func _decor_nom(d: String) -> String:
	match d:
		"western": return "western"
		"ville": return "rue de grande ville"
		"chateau": return "château"
		"espace": return "base spatiale"
		"mer": return "bassin"
	return d


## Lance un film. Rend "" ou la raison du refus.
func lancer_film(studio: int, genre: String, budget: String, real: String, star: String, titre := "") -> String:
	if not studios.has(studio):
		return "pas de studio"
	if en_chantier(studio):
		return "les studios sont encore en chantier"
	if not SpectaclesProgrammes.GENRES.has(genre) or String(SpectaclesProgrammes.GENRES[genre].famille) != "film":
		return "genre inconnu"
	if not SpectaclesProgrammes.BUDGETS.has(budget) or not SpectaclesProgrammes.REALISATEURS.has(real) or not SpectaclesProgrammes.STARS.has(star):
		return "équipe incomplète"
	if plateaux_libres(studio) <= 0:
		return "tous les plateaux sont pris (pose un plateau de tournage à côté des studios)"
	var dv := devis(studio, genre, budget, real, star)
	var avance := float(dv.cachets) + float(dv.budget) * 0.2
	if buildings != null and not buildings.unlimited_money and buildings.money < avance:
		return "il faut %s en caisse pour démarrer (cachets et préparation)" % BuildingSystem.format_money(int(avance))
	if titre.strip_edges() == "":
		titre = SpectaclesProgrammes.titre_au_hasard(genre, rng)
	_payer(studio, "Spectacles : cachets", float(dv.cachets))
	_payer(studio, "Spectacles : production de films", float(dv.budget) * 0.2)
	var id := _ajouter_film({"titre": titre.strip_edges(), "genre": genre, "q": 0, "pop": 0.0, "sortie": -1, "joueur": true, "studio": studio,
		"budget_id": budget, "real": real, "star": star, "phase": "prep", "reste": 3, "jours": int(dv.jours), "post": int(dv.post),
		"budget": float(dv.budget), "cout": float(dv.cachets) + float(dv.budget) * 0.2, "recettes": 0.0, "entrees": 0, "entrees_ville": 0,
		"presse": 0, "public": 0, "prix": "", "debut": _today()})
	message.emit("%s : « %s » entre en préparation (%s, %s)." % [nom(studio), titre, SpectaclesProgrammes.genre_name(genre).to_lower(),
		String(SpectaclesProgrammes.BUDGETS[budget][0]).to_lower()])
	changed.emit()
	return ""


## Avancement d'un film (0–1) dans sa phase, et le texte de la phase.
func avancement(id: int) -> Array:
	if not films.has(id):
		return [0.0, ""]
	var f: Dictionary = films[id]
	match String(f.phase):
		"prep": return [1.0 - float(f.reste) / 3.0, "Préparation (repérages, casting)"]
		"tournage": return [1.0 - float(f.reste) / maxf(1.0, float(f.jours)), "Tournage"]
		"post": return [1.0 - float(f.reste) / maxf(1.0, float(f.post)), "Montage et mixage"]
		"salle":
			var sem := float(_today() - int(f.sortie)) / 7.0
			return [clampf(sem / SEMAINES_SALLE, 0.0, 1.0), "En salle, semaine %d" % (int(sem) + 1)]
	return [1.0, "Sorti"]


func _jour_studios() -> void:
	var today := _today()
	for id in films.keys():
		var f: Dictionary = films[id]
		if not bool(f.get("joueur", false)):
			continue
		var studio := int(f.get("studio", -1))
		if not studios.has(studio) and String(f.phase) in ["prep", "tournage", "post"]:
			continue
		match String(f.phase):
			"prep", "tournage", "post":
				if en_chantier(studio) or sans_personnel(studio):
					_warn("st%d" % studio, "%s : le tournage est arrêté (personnel manquant)." % nom(studio), 86400.0 * 3.0)
					continue
				if String(f.phase) == "tournage":
					var jour := float(f.budget) * 0.7 / maxf(1.0, float(f.jours))
					_payer(studio, "Spectacles : production de films", jour)
					f.cout = float(f.cout) + jour
				elif String(f.phase) == "post":
					var jp := float(f.budget) * 0.1 / maxf(1.0, float(f.post))
					_payer(studio, "Spectacles : production de films", jp)
					f.cout = float(f.cout) + jp
				f.reste = int(f.reste) - 1
				if int(f.reste) <= 0:
					_phase_suivante(int(id))
			"salle":
				var sem := int(floorf(float(today - int(f.sortie)) / 7.0))
				if sem >= SEMAINES_SALLE:
					_fin_exploitation(int(id))
				else:
					var tot := float(f.entrees_total)
					var parts := 0.0
					for w in SEMAINES_SALLE:
						parts += pow(0.7, w)
					var ent := tot * pow(0.7, sem) / parts / 7.0
					f.entrees = int(f.entrees) + roundi(ent)
					var r := ent * PRIX_ENTREE_PAYS * (1.0 + float(SpectaclesProgrammes.BUDGETS[String(f.budget_id)][6]))
					f.recettes = float(f.recettes) + r
					if studios.has(studio):
						_encaisser(studio, "films", r)


func _phase_suivante(id: int) -> void:
	var f: Dictionary = films[id]
	match String(f.phase):
		"prep":
			f.phase = "tournage"
			f.reste = int(f.jours)
			message.emit("%s : premier clap pour « %s » ! %d jours de tournage." % [nom(int(f.studio)), String(f.titre), int(f.jours)])
		"tournage":
			f.phase = "post"
			f.reste = int(f.post)
			message.emit("%s : « %s », c'est dans la boîte. Place au montage." % [nom(int(f.studio)), String(f.titre)])
		"post":
			_sortie(id)


## Qualité finale, critiques et sortie en salle.
func _sortie(id: int) -> void:
	var f: Dictionary = films[id]
	var studio := int(f.studio)
	var genre := String(f.genre)
	var real: Array = SpectaclesProgrammes.REALISATEURS[String(f.real)]
	var star: Array = SpectaclesProgrammes.STARS[String(f.star)]
	var b: Array = SpectaclesProgrammes.BUDGETS[String(f.budget_id)]
	var an := annexes(studio)
	var q := 22.0 + float(real[1]) * 0.38 + float(star[1]) * 0.12 + float(b[4])
	if (real[3] as Array).has(genre):
		q += 8.0
	if (star[3] as Array).has(genre):
		q += 6.0
	var dec := decor_pour(genre)
	if dec != "":
		q += 7.0 if (an.decors as Dictionary).has(dec) else -5.0
	if SpectaclesProgrammes.VFX_GENRES.has(genre):
		if bool(an.vfx):
			q += 8.0
		elif genre in ["sf", "animation"]:
			q -= 10.0
	if bool(an.postprod):
		q += 5.0
	if studios.has(studio):
		q += float(studios[studio].reputation) * 0.05
	q += rng.randf_range(-12.0, 12.0)
	q = clampf(q, 5.0, 98.0)
	var presse := clampf(q + (float(real[1]) - 60.0) * 0.15 + (5.0 if genre in ["documentaire", "drame_film", "historique"] else 0.0)
		- (6.0 if String(f.budget_id) == "super" and genre == "action" else 0.0) + rng.randf_range(-8.0, 8.0), 1.0, 99.0)
	var publ := clampf(q + float(star[1]) * 0.15 + float(b[4]) * 0.5 + (4.0 if genre in ["action", "animation", "comedie_film", "aventure"] else 0.0)
		+ rng.randf_range(-8.0, 8.0), 1.0, 99.0)
	f.q = roundi(q)
	f.presse = roundi(presse)
	f.public = roundi(publ)
	var rep := float(studios[studio].reputation) if studios.has(studio) else 20.0
	f.entrees_total = roundi(float(b[5]) * pow(publ / 60.0, 2.2) * (1.0 + float(star[1]) / 150.0) * (0.8 + rep / 250.0))
	f.pop = snappedf(clampf(0.3 + publ / 45.0 * (0.6 + 0.2 * SpectaclesProgrammes.BUDGET_ORDER.find(String(f.budget_id))), 0.2, 4.0), 0.01)
	f.sortie = _today()
	f.phase = "salle"
	if studios.has(studio):
		studios[studio].reputation = lerpf(float(studios[studio].reputation), (presse + publ) / 2.0, 0.3)
	message.emit("« %s » sort en salle ! Presse %s, public %s. %s entrées attendues." % [String(f.titre), SpectaclesPanel.etoiles(presse / 20.0),
		SpectaclesPanel.etoiles(publ / 20.0), _nombre(int(f.entrees_total))])


func _fin_exploitation(id: int) -> void:
	var f: Dictionary = films[id]
	f.phase = "fini"
	var tv := float(f.budget) * clampf(0.15 + float(f.q) / 200.0, 0.15, 0.6)
	if String(f.budget_id) == "court":
		tv = 5000.0 + float(f.q) * 200.0
	f.recettes = float(f.recettes) + tv
	f.tv = tv
	if studios.has(int(f.studio)):
		_encaisser(int(f.studio), "droits_tv", tv)
	var bilan := float(f.recettes) - float(f.cout)
	message.emit("« %s » quitte l'affiche : %s entrées, droits télé %s. Bilan : %s." % [String(f.titre), _nombre(int(f.entrees)),
		BuildingSystem.format_money(int(tv)), ("+" if bilan >= 0.0 else "") + BuildingSystem.format_money(int(bilan))])


## Festival de la Bobine d'or (20 mai) : le meilleur film de l'année gagne.
func _festival(today: int) -> void:
	var best := -1
	var best_p := 0.0
	for id in films:
		var f: Dictionary = films[id]
		if not bool(f.get("joueur", false)) or int(f.sortie) < 0 or today - int(f.sortie) > 365 or String(f.get("prix", "")) != "":
			continue
		if float(f.presse) > best_p:
			best_p = float(f.presse)
			best = int(id)
	if best < 0 or best_p < 70.0:
		return
	if rng.randf() > clampf((best_p - 60.0) / 35.0, 0.1, 0.95):
		message.emit("Festival de la Bobine d'or : « %s » était en compétition, mais repart sans prix. L'an prochain !" % String(films[best].titre))
		return
	var f: Dictionary = films[best]
	var court := String(f.budget_id) == "court"
	f.prix = "Bobine d'or du court métrage" if court else "Bobine d'or"
	var dot := 15000.0 if court else 50000.0
	if studios.has(int(f.studio)):
		var st: Dictionary = studios[int(f.studio)]
		st.reputation = minf(100.0, float(st.reputation) + 15.0)
		(st.prix as Array).append("%s (%d) : « %s »" % [String(f.prix), int(date_of(today).year), String(f.titre)])
		_encaisser(int(f.studio), "prix", dot)
	if String(f.phase) == "salle":
		f.entrees_total = roundi(float(f.entrees_total) * 1.3)
	message.emit("Festival de la Bobine d'or : « %s » remporte la %s ! Toute la ville est fière." % [String(f.titre), String(f.prix)])


static func _nombre(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# --- Jour -------------------------------------------------------------------------------------

func new_day(now: Dictionary = {}) -> void:
	_majs_ages()
	for bid in salles:
		var st: Dictionary = salles[bid]
		_charges(int(bid))
		for f in st.jour:
			if st.jour[f] is int:
				st.total[f] = int(st.total.get(f, 0)) + int(st.jour[f])
			else:
				st.total[f] = float(st.total.get(f, 0.0)) + float(st.jour[f])
		st.hier = st.jour
		st.jour = _empty_stats()
		var vus: Dictionary = st.vus
		for k in vus.keys():
			vus[k] = float(vus[k]) * 0.97
			if float(vus[k]) < 5.0:
				vus.erase(k)
		var pens: Dictionary = st.pensees
		for p in pens.keys():
			pens[p] = int(int(pens[p]) * 0.7)
			if int(pens[p]) <= 0:
				pens.erase(p)
	for bid in studios:
		_charges(int(bid))
	var day := int(now.get("day", _today()))
	if int(now.get("wd", -1)) == 3:
		_nouvelles_sorties(day)
	_menage_films(day)
	_jour_studios()
	if int(now.get("month", 0)) == 5 and int(now.get("mday", 0)) == 20:
		_festival(day)
	_nouveau_jour_programmes()
	for pid in sorties.keys():
		if last_day - int(sorties[pid]) > 30:
			sorties.erase(pid)


func _charges(bid: int) -> void:
	if en_chantier(bid):
		return
	var emplois := int(BuildingCatalog.get_type(type_of(bid)).get("emplois", 0))
	if emplois > 0:
		_payer(bid, "Spectacles : salaires", float(emplois) * SALAIRE_MOYEN / 30.44)


func _sorties(n: int) -> void:
	if population == null or n <= 0 or population.persons.is_empty():
		return
	var ids := population.persons.keys()
	for i in mini(n, 12):
		sorties[int(ids[rng.randi() % ids.size()])] = last_day


func _penser(bid: int, cle: String, args: Array = [], poids := 1) -> void:
	if not salles.has(bid):
		return
	var st: Dictionary = salles[bid]
	var pens: Dictionary = st.pensees
	pens[cle] = int(pens.get(cle, 0)) + poids
	var txt := String(PENSEES.get(cle, cle))
	if not args.is_empty():
		txt = txt % args
	var d: Array = st.dernieres
	if d.is_empty() or String(d[0]) != txt:
		d.push_front(txt)
		if d.size() > 8:
			d.resize(8)


func _warn(k: String, text: String, every := 3600.0 * 12.0) -> void:
	if clock - float(_warned.get(k, -INF)) < every:
		return
	_warned[k] = clock
	message.emit(text)


# --- Argent -----------------------------------------------------------------------------------

const POSTES := {"billets": "Spectacles : billets", "bar": "Spectacles : bar et confiserie", "films": "Spectacles : films (recettes)",
	"films_salles": "Spectacles : films (salles de la ville)", "droits_tv": "Spectacles : droits télé et plateformes", "prix": "Spectacles : prix de festival"}


func _encaisser(bid: int, quoi: String, montant: float) -> void:
	if salles.has(bid) and (salles[bid].jour as Dictionary).has(quoi):
		salles[bid].jour[quoi] = float(salles[bid].jour[quoi]) + montant
	_flux(bid, String(POSTES.get(quoi, "Spectacles")), montant)


func _payer(bid: int, poste: String, montant: float) -> void:
	if salles.has(bid):
		salles[bid].jour.depenses = float(salles[bid].jour.depenses) + montant
	_flux(bid, poste, -montant)


func _flux(bid: int, poste: String, montant: float) -> void:
	if buildings == null or buildings.unlimited_money or absf(montant) < 0.01:
		return
	var prev := Pays.au_batiment(bid)
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		if montant > 0.0:
			bc.recette(poste, montant)
		else:
			bc.depense(poste, -montant)
	else:
		var st: Dictionary = salles.get(bid, studios.get(bid, {}))
		if not st.is_empty():
			st.argent = float(st.argent) + montant
			var whole := int(st.argent)
			if whole != 0:
				buildings.money += whole
				st.argent = float(st.argent) - whole
	Pays.retour(prev)


static func recettes(st: Dictionary) -> float:
	return float(st.billets) + float(st.bar)


# --- Avis des habitants, résumé ----------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "spectacles", "theme": "loisirs", "f": satisfaction_of}]


func satisfaction_of(p: Dictionary) -> Array:
	if salles.is_empty() or population == null:
		return [0.0, []]
	var pid := int(p.get("id", -1))
	var out := 0.0
	var why: Array = []
	if pid >= 0 and sorties.has(pid) and last_day - int(sorties[pid]) <= 30:
		out = 2.0
		why.append("+ Une belle soirée au spectacle")
	else:
		for b in salles:
			if note(int(b)) >= 3.0:
				out = 1.0
				why.append("+ De belles salles de spectacle en ville")
				break
	for id in films:
		var f: Dictionary = films[id]
		if bool(f.get("joueur", false)) and String(f.phase) == "salle":
			out += 0.5
			why.append("+ Un film tourné chez nous à l'affiche")
			break
	return [out, why]


func summary() -> String:
	if salles.is_empty():
		return ""
	var v := 0
	for b in salles:
		v += int(salles[b].hier.spectateurs)
	return "Spectacles : %d spectateurs hier" % v


## Agenda de la ville : les prochaines dates de toutes les salles, dans l'ordre.
func agenda_ville(jours := 7) -> Array:
	var today := _today()
	var out: Array = []
	for bid in salles:
		for ev in salles[bid].agenda:
			if int(ev.d) >= today and int(ev.d) <= today + jours:
				out.append({"bid": int(bid), "d": int(ev.d), "h": int(ev.h), "sp": String(ev.sp)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.d) * 100 + int(a.h) < int(b.d) * 100 + int(b.h))
	return out


## Public attendu ou présent à cet instant autour d'une salle (pour les petits personnages).
func foule(bid: int, now: Dictionary) -> int:
	if not salles.has(bid):
		return 0
	var h := float(now.h)
	var day := int(now.day)
	if famille_of(bid) == "cinema":
		for sh in seances(bid):
			if h >= float(sh) - 0.4 and h < float(sh) + 0.1:
				return roundi(minf(float(places(bid)) * 0.3, demande_cinema(bid, now) * float(seances(bid)[sh])))
		return 0
	for ev in salles[bid].agenda:
		if int(ev.d) == day and h >= float(ev.h) - 0.75 and h < float(ev.h) + 0.5:
			return roundi(minf(float(places(bid)), demande(bid, String(ev.sp), now)))
	# Sortie : jusqu'à 2 h 30 après le début.
	var hist: Array = salles[bid].historique
	if not hist.is_empty() and int(hist[0].d) == day:
		for hh in [20, 16, 15]:
			if h >= float(hh) + 2.0 and h < float(hh) + 2.6:
				return int(hist[0].public)
	return 0


## Équipe de tournage visible : un studio qui tourne en journée.
func tournage_en_cours(studio: int) -> bool:
	return not films_du_studio(studio, ["tournage"]).is_empty()


# --- Sauvegarde -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var s := {}
	for bid in salles:
		var st: Dictionary = salles[bid]
		s[str(bid)] = {"nom": st.nom, "prix": st.prix, "auto": st.auto, "agenda": st.agenda, "total": st.total, "hier": st.hier,
			"pensees": st.pensees, "dernieres": st.dernieres, "reputation": st.reputation, "historique": st.historique, "vus": st.vus,
			"affiche_forcee": st.affiche_forcee, "ouvert": st.ouvert}
	var stu := {}
	for bid in studios:
		stu[str(bid)] = {"nom": studios[bid].nom, "reputation": studios[bid].reputation, "prix": studios[bid].prix}
	var fl := {}
	for id in films:
		fl[str(id)] = films[id]
	var so := {}
	for pid in sorties:
		so[str(pid)] = sorties[pid]
	return {"salles": s, "studios": stu, "films": fl, "next_film": next_film, "last_day": last_day, "sorties": so}


func from_dict(d: Dictionary) -> void:
	clear()
	_dirty = true
	var s: Dictionary = d.get("salles", {})
	for k in s:
		var src: Dictionary = s[k]
		var st := {"nom": "", "prix": 15.0, "auto": true, "agenda": [], "jour": _empty_stats(), "hier": _empty_stats(), "total": _empty_stats(),
			"pensees": {}, "dernieres": [], "reputation": 3.0, "historique": [], "vus": {}, "affiche_forcee": -1, "argent": 0.0, "ouvert": true}
		for f in src:
			st[f] = src[f]
		# JSON : les entiers reviennent en flottants.
		for part in ["total", "hier"]:
			var s0 := _empty_stats()
			var got: Dictionary = st[part]
			for f2 in s0:
				s0[f2] = int(got.get(f2, 0)) if s0[f2] is int else float(got.get(f2, 0.0))
			st[part] = s0
		for ev in st.agenda:
			ev.d = int(ev.d)
			ev.h = int(ev.h)
		for hh in st.historique:
			hh.d = int(hh.d)
			hh.public = int(hh.public)
		st.affiche_forcee = int(st.affiche_forcee)
		salles[int(k)] = st
	var stu: Dictionary = d.get("studios", {})
	for k in stu:
		var st2 := {"nom": "", "reputation": 20.0, "prix": [], "argent": 0.0}
		for f in stu[k]:
			st2[f] = stu[k][f]
		studios[int(k)] = st2
	var fl: Dictionary = d.get("films", {})
	for k in fl:
		var f: Dictionary = fl[k]
		for ik in ["id", "q", "sortie", "studio", "reste", "jours", "post", "entrees", "entrees_ville", "entrees_total", "presse", "public", "debut"]:
			if f.has(ik):
				f[ik] = int(f[ik])
		films[int(k)] = f
	next_film = maxi(int(d.get("next_film", 1)), 1)
	for id in films:
		next_film = maxi(next_film, int(id) + 1)
	last_day = int(d.get("last_day", -1))
	var so: Dictionary = d.get("sorties", {})
	for pid in so:
		sorties[int(pid)] = int(so[pid])
	changed.emit()
