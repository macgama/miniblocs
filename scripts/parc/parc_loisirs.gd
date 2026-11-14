class_name ParcLoisirs
extends Node3D
## Parc de loisirs : visiteurs, files d'attente, billets, stands, satisfaction,
## propreté, pannes et entretien, note du parc en étoiles.
##
## - Une « Entrée du parc » (ParcTypes) fonde un parc. Attractions, stands,
##   toilettes, aires de repos et ateliers posés à moins de RAYON mètres de
##   l'entrée en font partie (au plus proche s'il y a plusieurs entrées).
## - Visiteurs : des habitants de la ville (selon leur nombre) et des touristes
##   (selon l'attrait des attractions, la note et l'accès par la route), plus
##   nombreux le week-end, le mercredi, l'été, et moins sous la pluie. Chaque
##   visiteur simulé peut en représenter plusieurs (champ "w") quand la foule
##   est grande : MAX_AGENTS visiteurs suivis au plus par parc.
## - Chaque visiteur a son humeur, sa faim, sa soif, sa fatigue, une envie de
##   toilettes, un budget, un goût pour les sensations (pref) et ce qu'il
##   supporte (tol). Il marche entre les attractions, fait la queue, monte,
##   mange, boit, se repose, et repart (fermeture, fatigue, mauvaise humeur,
##   porte-monnaie vide ou simplement l'heure de rentrer).
## - Attractions : places par tour, durée du tour, fiabilité qui baisse à
##   chaque tour, pannes (plus fréquentes quand la fiabilité est basse). Les
##   techniciens de l'atelier révisent et réparent ; sans eux, un dépanneur
##   extérieur vient au bout de DEPANNEUR_H heures, pour DEPANNEUR_PRIX €.
## - Personnel : les emplois sont pris par les habitants (Population). Ce qui
##   manque est complété par des saisonniers venus d'ailleurs (jusqu'à la
##   moitié des postes, payés SAISON_X fois plus) ; les attractions tournent
##   plus lentement avec moins de monde.
## - Argent : billets d'entrée, tours payants, stands → caisse de la ville où
##   est l'entrée (BudgetCommunal.recette, poste « Parc de loisirs ») ;
##   salaires et entretien → dépenses. Taxe de séjour par touriste.
## - Liens, par groupes de nœuds : "avis_sources" (thème loisirs : le parc
##   près de chez soi, la sortie au parc), "pollution_sources" (bruit).

signal changed
signal message(text: String)

static var instance: ParcLoisirs

const RAYON := 250.0
## Pas de simulation (secondes de jeu).
const STEP := 60.0
const MAX_AGENTS := 260
const MARCHE := 1.1
const PRIX_ENTREE := 25.0
const PRIX_TOUR := 0.0
## Touristes par jour et par point d'attrait (bonne saison, bonne note).
const TOURISTES_ATTRAIT := 30.0
## Part des habitants qui vont au parc un jour donné (bonne saison).
const HABITANTS_JOUR := 0.006
const TAXE_SEJOUR := 1.5
const SAISON_PART := 0.5
const SAISON_X := 1.3
const DEPANNEUR_H := 4.0
const DEPANNEUR_PRIX := 2500.0
## Entretien des attractions : part du prix de construction par mois.
const ENTRETIEN_MOIS := 0.008
const MOIS_SAISON := {1: 0.3, 2: 0.35, 3: 0.55, 4: 0.85, 5: 0.95, 6: 1.0, 7: 1.6, 8: 1.6, 9: 0.8, 10: 0.85, 11: 0.35, 12: 0.55}
## Répartition des arrivées sur la journée (part par heure d'ouverture).
const ARRIVEES := {10: 0.22, 11: 0.2, 12: 0.14, 13: 0.14, 14: 0.12, 15: 0.08, 16: 0.05, 17: 0.03, 18: 0.01, 19: 0.0, 20: 0.0, 21: 0.0}
const NOMS := ["Parc des Merveilles", "Le Grand Frisson", "Planète Manège", "Fantasialand des Familles", "Parc du Vertige",
	"Les Folies du Dimanche", "Royaume des Montagnes Russes", "Parc Barbe-à-Papa"]

## Ce que disent les visiteurs : clé → texte (une pointe d'humour, ton réaliste).
const PENSEES := {
	"super": "Excellente journée ! Les enfants dorment déjà dans la voiture.",
	"frisson": "%s : j'ai crié tout le long. Je recommence.",
	"nausee": "%s m'a retourné l'estomac. Plus jamais. Enfin, pas avant midi.",
	"trop_doux": "%s, c'est pour les petits. On veut des sensations !",
	"file": "%d minutes de queue pour %s. J'ai eu le temps de lire tout le règlement.",
	"panne": "%s est en panne. On a une très belle vue… sur le mécanicien.",
	"faim": "Rien à manger ici. Je vais finir par croquer un cheval de bois.",
	"soif": "Il fait soif et pas une buvette à l'horizon.",
	"toilettes": "Les toilettes ? Quelles toilettes ?",
	"sale": "Il y a plus de papiers gras que de visiteurs.",
	"propre": "Ce parc est d'une propreté presque suspecte.",
	"cher": "%d € l'entrée ? Pour ce prix-là, je veux que le carrousel aille plus vite.",
	"bon_prix": "Pour le prix, c'est une très bonne affaire.",
	"frites": "Les frites sont excellentes. Le prix des frites, moins.",
	"fatigue": "Mes pieds ont demandé à rentrer à la maison.",
	"fauche": "Plus un sou en poche. Les souvenirs attendront.",
	"ennui": "On a fait le tour en une heure. Il manque des attractions.",
	"souvenir": "J'ai acheté une casquette du parc. Je ne la porterai jamais.",
	"pluie": "Le parc sous la pluie, c'est romantique. Les files sont courtes, au moins.",
}

var buildings: BuildingSystem
var population: Population
var transport: TransportSystem
var ambiance: DayNight

## Entrée (bid) → parc.
var parcs: Dictionary = {}
## Bâtiment (bid) → état de l'objet du parc.
var items: Dictionary = {}
## Identifiant → visiteur suivi.
var agents: Dictionary = {}
var next_agent := 1
var clock := -1.0
var last_unix := -1.0
var last_day := -1
## Habitants allés au parc : pid → jour.
var sorties: Dictionary = {}
## Tests : personnel complet, sans tenir compte des habitants.
var ignore_staff := false
var rng := RandomNumberGenerator.new()
var _dirty := true
var _n := 0
var _warned: Dictionary = {}


func _init() -> void:
	rng.seed = 7_250_101
	add_to_group("avis_sources")
	add_to_group("pollution_sources")


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


var visuels: ParcVisuels


func _ready() -> void:
	visuels = ParcVisuels.new()
	visuels.name = "Visuels"
	visuels.setup(self)
	add_child(visuels)


func setup(b: BuildingSystem, p: Population, t: TransportSystem, a: DayNight) -> void:
	buildings = b
	population = p
	transport = t
	ambiance = a
	if buildings != null:
		buildings.changed.connect(func() -> void: _dirty = true)


func clear() -> void:
	parcs.clear()
	items.clear()
	agents.clear()
	sorties.clear()
	next_agent = 1
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	_dirty = true
	changed.emit()


static func actif() -> bool:
	return true


# --- Bâtiments ----------------------------------------------------------------------------------

static func _empty_stats() -> Dictionary:
	return {"visiteurs": 0, "touristes": 0, "habitants": 0, "billets": 0.0, "tours_argent": 0.0, "stands": 0.0, "tours": 0,
		"pannes": 0, "sortis": 0, "humeur": 0.0, "depenses": 0.0, "refus": 0}


func _new_parc(bid: int) -> Dictionary:
	return {"nom": NOMS[(bid * 7 + parcs.size()) % NOMS.size()], "prix": PRIX_ENTREE, "prix_tour": PRIX_TOUR, "note": 2.5,
		"salete": 0.0, "jour": _empty_stats(), "hier": _empty_stats(), "total": _empty_stats(), "pensees": {}, "dernieres": [],
		"reste": 0.0, "w": 1, "items": [], "ouvert": false, "attente": 0.0, "argent": 0.0, "dep": 0.0, "saison": 0, "techs": 0.0,
		"agents_propre": 0.0}


func _sync() -> void:
	_dirty = false
	if buildings == null:
		return
	# Entrées : un parc chacune.
	for bid in parcs.keys():
		if not buildings.buildings.has(bid) or ParcTypes.role_of(_type_of(int(bid))) != "entree":
			_fermer_parc(int(bid))
	for bid in items.keys():
		if not buildings.buildings.has(bid) or ParcTypes.role_of(_type_of(int(bid))) != String(items[bid].role):
			_retirer(int(bid))
	for bid in buildings.buildings:
		var role := ParcTypes.role_of(String(buildings.buildings[bid].t))
		if role == "entree" and not parcs.has(bid):
			parcs[bid] = _new_parc(int(bid))
		if role != "" and not items.has(bid):
			items[bid] = {"role": role, "parc": -1, "fiab": 100.0, "panne": false, "repar": 0.0, "dep": false, "file": [], "bord": [],
				"fin": 0.0, "tours": 0, "argent": 0.0, "serv": 0.0, "attente": 0.0}
	# Rattachement de chaque objet au parc le plus proche.
	for p in parcs.values():
		(p.items as Array).clear()
	for bid in items:
		var it: Dictionary = items[bid]
		if it.role == "entree":
			it.parc = int(bid)
		else:
			var pos := _center(int(bid))
			var best := -1
			var best_d := RAYON
			for e in parcs:
				var d := Vector2(pos.x, pos.z).distance_to(Vector2(_center(int(e)).x, _center(int(e)).z))
				if d <= best_d:
					best_d = d
					best = int(e)
			if best != int(it.parc) and int(it.parc) >= 0:
				_vider(int(bid))
			it.parc = best
		if int(it.parc) >= 0:
			(parcs[int(it.parc)].items as Array).append(int(bid))
	changed.emit()


func _retirer(bid: int) -> void:
	_vider(bid)
	items.erase(bid)


## Fait sortir de la file et du manège ceux qui y étaient.
func _vider(bid: int) -> void:
	if not items.has(bid):
		return
	var it: Dictionary = items[bid]
	for aid in (it.file as Array) + (it.bord as Array):
		if agents.has(aid):
			_choisir(agents[aid])
	(it.file as Array).clear()
	(it.bord as Array).clear()


func _fermer_parc(bid: int) -> void:
	for aid in agents.keys():
		if int(agents[aid].parc) == bid:
			agents.erase(aid)
	parcs.erase(bid)


func _type_of(bid: int) -> String:
	return String(buildings.buildings[bid].t) if buildings != null and buildings.buildings.has(bid) else ""


func _center(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)


## Point devant l'objet, où l'on fait la queue.
func porte(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	var p := BuildingSystem.door_point(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0)))
	return Vector3(p.x, float(b.get("h", 0.0)), p.z)


## Direction de la façade (vers l'extérieur) d'un objet.
func facade(bid: int) -> Vector3:
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.front_dir(int(b.r)).rotated(Vector3.UP, float(b.get("a", 0.0)))


## Porte intérieure de l'entrée (côté parc, à l'opposé de la route).
func portail(e: int) -> Vector3:
	var b: Dictionary = buildings.buildings[e]
	var d := float(BuildingCatalog.get_type(String(b.t)).get("d", 14))
	return _center(e) - facade(e) * (d / 2.0 + 3.0)


## Place centrale du parc : milieu des objets (ou devant l'entrée).
func centre(e: int) -> Vector3:
	var p: Dictionary = parcs[e]
	var acc := portail(e)
	var n := 1
	for bid in p.items:
		if int(bid) != e:
			acc += _center(int(bid))
			n += 1
	return acc / float(n)


func en_chantier(bid: int) -> bool:
	return buildings != null and buildings.en_chantier(bid)


func items_of(e: int, role: String) -> Array:
	var out: Array = []
	if not parcs.has(e):
		return out
	for bid in parcs[e].items:
		if items.has(bid) and String(items[bid].role) == role and not en_chantier(int(bid)):
			out.append(int(bid))
	return out


func hors_parc() -> Array:
	var out: Array = []
	for bid in items:
		if int(items[bid].parc) < 0:
			out.append(int(bid))
	return out


func nom_de(bid: int) -> String:
	return String(BuildingCatalog.get_type(_type_of(bid)).get("name", "—"))


# --- Temps ------------------------------------------------------------------------------------------

func _now(t: float) -> Dictionary:
	var off := ambiance.utc_offset() if ambiance != null else 0.0
	var local := t + off * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	return {"h": fposmod(local, 86400.0) / 3600.0, "wd": int(dt.weekday), "month": int(dt.month), "day": int(floorf(local / 86400.0))}


## Heures d'ouverture [ouverture, fermeture] selon le mois.
static func horaires(month: int) -> Vector2:
	if month in [7, 8]:
		return Vector2(10.0, 22.0)
	if month in [11, 12, 1, 2, 3]:
		return Vector2(11.0, 18.0)
	return Vector2(10.0, 19.0)


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


## Fait avancer le parc de dt secondes de jeu (pas de STEP).
func advance(dt: float) -> void:
	if _dirty:
		_sync()
	var end_t := (ambiance.unix_time if ambiance != null else clock + dt)
	if clock < 0.0 or absf(end_t - dt - clock) > 86400.0 * 3.0:
		clock = end_t - dt
	if last_day < 0:
		last_day = int(_now(clock).day)
	var n := 0
	while clock + STEP <= end_t + 0.001 and n < 600:
		clock += STEP
		n += 1
		step(STEP)
	if clock < end_t - 86400.0:
		clock = end_t


func step(dt: float) -> void:
	if _dirty:
		_sync()
	_n += 1
	var now := _now(clock)
	if int(now.day) > last_day:
		last_day = int(now.day)
		new_day()
	if parcs.is_empty():
		return
	for e in parcs:
		_step_parc(int(e), now, dt)
	if _n % 5 == 0:
		changed.emit()


# --- Un parc ---------------------------------------------------------------------------------------

func est_ouvert(e: int, now: Dictionary) -> bool:
	if not actif() or en_chantier(e) or attractions_ok(e).is_empty():
		return false
	var hr := horaires(int(now.month))
	return float(now.h) >= hr.x and float(now.h) < hr.y


## Attractions du parc qui peuvent tourner (posées, finies).
func attractions_ok(e: int) -> Array:
	return items_of(e, "attraction")


func attrait(e: int) -> float:
	var a := 0.0
	for bid in attractions_ok(e):
		a += float(ParcTypes.spec_of(_type_of(bid)).get("attrait", 1.0))
	return a


## Ce que vaut l'entrée aux yeux des visiteurs (€).
func valeur(e: int) -> float:
	return 8.0 + 3.2 * pow(attrait(e), 0.75)


func _pluie() -> float:
	if ambiance == null or ambiance.weather == null:
		return 0.0
	return clampf(float(ambiance.weather.precip), 0.0, 1.0)


## Visiteurs attendus aujourd'hui : [touristes, habitants].
func attendus(e: int, now: Dictionary) -> Array:
	var p: Dictionary = parcs[e]
	var a := attrait(e)
	if a <= 0.0:
		return [0.0, 0.0]
	var note_f := 0.35 + 0.65 * clampf(float(p.note) / 5.0, 0.0, 1.0)
	var saison := float(MOIS_SAISON.get(int(now.month), 1.0))
	var wd := int(now.wd)
	var jour := 1.6 if wd == 6 else (1.5 if wd == 0 else (1.1 if wd == 3 else 0.75))
	var meteo := 1.0 - 0.55 * _pluie()
	var prix := clampf(valeur(e) / maxf(float(p.prix), 1.0), 0.2, 1.25)
	var acces := 1.0 if _relie(e) else 0.15
	var f := note_f * saison * jour * meteo * prix
	var touristes := TOURISTES_ATTRAIT * a * f * acces
	var hab := 0.0
	if population != null:
		hab = float(population.persons.size()) * HABITANTS_JOUR * f * clampf(a / 10.0, 0.3, 1.5)
	return [touristes, hab]


## L'entrée est-elle reliée à une route ?
func _relie(e: int) -> bool:
	if buildings == null or not buildings.buildings.has(e):
		return false
	if transport == null:
		return true
	var door := porte(e)
	for eid in transport.edges_near(door, 40.0):
		if TransportTypes.mode_of(transport.network.edges[eid].t) == TransportTypes.Mode.ROAD:
			return true
	return false


func _step_parc(e: int, now: Dictionary, dt: float) -> void:
	var p: Dictionary = parcs[e]
	var was := bool(p.ouvert)
	p.ouvert = est_ouvert(e, now)
	if was and not p.ouvert:
		_fermeture(e)
	# Propreté : les agents ramassent, le vent emporte un peu.
	var propre := float(p.agents_propre)
	p.salete = maxf(0.0, float(p.salete) - propre * 60.0 * dt / 3600.0 - float(p.salete) * 0.04 * dt / 3600.0)
	_entretien(e, dt)
	if p.ouvert:
		_arrivees(e, now, dt)
	for bid in p.items:
		if not items.has(bid) or en_chantier(int(bid)):
			continue
		match String(items[bid].role):
			"attraction": _tourner(int(bid), e, dt)
			"stand", "toilettes": _servir(int(bid), e, dt)
	_visiteurs(e, now, dt)
	# Note du parc : glisse doucement vers la note du moment (ouvert seulement).
	if p.ouvert and _n % 10 == 0:
		p.note = lerpf(float(p.note), note_cible(e), 0.05)


## Personnel d'un objet : [part des postes tenus (0 à 1), saisonniers].
func personnel(bid: int) -> Array:
	var emplois := int(BuildingCatalog.get_type(_type_of(bid)).get("emplois", 0))
	if emplois <= 0:
		return [1.0, 0]
	if ignore_staff or population == null:
		return [1.0, 0]
	var n := (population.by_job.get(bid, []) as Array).size()
	var f := clampf(float(n) / emplois, 0.0, 1.0)
	var s := 0
	if f < SAISON_PART:
		s = ceili((SAISON_PART - f) * emplois)
	return [clampf(f + float(s) / emplois, 0.0, 1.0), s]


## Techniciens et agents de propreté des ateliers du parc.
func _equipes(e: int) -> Array:
	var techs := 0.0
	var proprete := 0.0
	for bid in parcs[e].items:
		if not items.has(bid) or en_chantier(int(bid)) or String(items[bid].role) != "atelier":
			continue
		for m in Metiers.jobs_for(_type_of(int(bid))):
			var f := float(personnel(int(bid))[0])
			if String(m[0]) == "technicien_attraction":
				techs += float(m[1]) * f
			elif String(m[0]) == "agent_proprete":
				proprete += float(m[1]) * f
	return [techs, proprete]


# --- Arrivées et départs -------------------------------------------------------------------------------

func _arrivees(e: int, now: Dictionary, dt: float) -> void:
	var p: Dictionary = parcs[e]
	var att := attendus(e, now)
	var total := float(att[0]) + float(att[1])
	if total <= 0.0:
		return
	var h := int(now.h)
	var part := float(ARRIVEES.get(h, 0.0))
	if part <= 0.0:
		return
	# Poids d'un visiteur suivi selon la foule attendue.
	p.w = maxi(1, ceili(total * 0.5 / MAX_AGENTS))
	p.reste = float(p.reste) + total * part * dt / 3600.0
	var w := int(p.w)
	var tour_part := float(att[0]) / total
	while float(p.reste) >= float(w) and _agents_du(e) < MAX_AGENTS:
		p.reste = float(p.reste) - w
		_nouveau(e, w, rng.randf() < tour_part)


func _agents_du(e: int) -> int:
	var c := 0
	for a in agents.values():
		if int(a.parc) == e:
			c += 1
	return c


func _nouveau(e: int, w: int, touriste: bool) -> void:
	var p: Dictionary = parcs[e]
	var pid := -1
	if not touriste and population != null and not population.persons.is_empty():
		var keys := population.persons.keys()
		pid = int(keys[rng.randi() % keys.size()])
	var a := {"id": next_agent, "parc": e, "w": w, "src": "tour" if touriste else "hab", "pid": pid, "etat": "marche", "cible": -1,
		"path": PackedVector3Array(), "t0": clock, "t1": clock, "argent": rng.randf_range(25.0, 90.0) + (20.0 if touriste else 0.0),
		"humeur": rng.randf_range(62.0, 80.0), "faim": rng.randf_range(10.0, 45.0), "soif": rng.randf_range(10.0, 40.0),
		"fatigue": rng.randf_range(0.0, 15.0), "vessie": rng.randf_range(0.0, 30.0),
		"pref": rng.randf_range(1.0, 9.0), "tol": rng.randf_range(2.0, 9.5), "fin": clock + rng.randf_range(3.0, 7.0) * 3600.0,
		"vus": {}, "tours": 0, "depense": 0.0, "col": rng.randi() % 64, "pos": portail(e)}
	next_agent += 1
	# Le billet d'entrée : trop cher, on hésite (ou on fait demi-tour).
	var prix := float(p.prix)
	var val := valeur(e)
	if prix > val * 1.6 and rng.randf() < 0.5:
		p.jour.refus = int(p.jour.refus) + w
		_penser(e, "cher", [roundi(prix)])
		return
	if prix > val:
		a.humeur = float(a.humeur) - (prix / val - 1.0) * 25.0
		if rng.randf() < 0.3:
			_penser(e, "cher", [roundi(prix)])
	elif prix < val * 0.6 and rng.randf() < 0.1:
		_penser(e, "bon_prix")
	_encaisser(e, "billets", prix * w)
	a.depense = prix
	p.jour.visiteurs = int(p.jour.visiteurs) + w
	if touriste:
		p.jour.touristes = int(p.jour.touristes) + w
		_encaisser(e, "sejour", TAXE_SEJOUR * w)
	else:
		p.jour.habitants = int(p.jour.habitants) + w
		if pid >= 0:
			sorties[pid] = last_day
	if _pluie() > 0.4 and rng.randf() < 0.05:
		_penser(e, "pluie")
	agents[int(a.id)] = a
	_choisir(a)


## Tout le monde dehors à la fermeture.
func _fermeture(e: int) -> void:
	for aid in agents.keys():
		var a: Dictionary = agents[aid]
		if int(a.parc) == e and String(a.etat) != "sortie":
			_partir(a)
	for bid in parcs[e].items:
		if items.has(bid):
			(items[bid].file as Array).clear()
			(items[bid].bord as Array).clear()
			items[bid].fin = 0.0


func _partir(a: Dictionary) -> void:
	var e := int(a.parc)
	_quitter_file(a)
	# Souvenir en sortant, si la journée était bonne.
	var shops := items_of(e, "stand").filter(func(b: int) -> bool: return String(ParcTypes.spec_of(_type_of(b)).vend) == "souvenir")
	if not shops.is_empty() and float(a.humeur) > 70.0 and rng.randf() < 0.35:
		var prix := float(ParcTypes.spec_of(_type_of(int(shops[0]))).prix)
		if float(a.argent) >= prix:
			a.argent = float(a.argent) - prix
			a.depense = float(a.depense) + prix
			_encaisser(e, "stands", prix * int(a.w))
			items[int(shops[0])].argent = float(items[int(shops[0])].argent) + prix * int(a.w)
			if rng.randf() < 0.15:
				_penser(e, "souvenir")
	_aller(a, -1, portail(e))
	a.etat = "sortie"


func _sortir(a: Dictionary) -> void:
	var e := int(a.parc)
	if parcs.has(e):
		var p: Dictionary = parcs[e]
		p.jour.sortis = int(p.jour.sortis) + int(a.w)
		p.jour.humeur = float(p.jour.humeur) + float(a.humeur) * int(a.w)
		if float(a.humeur) >= 80.0 and rng.randf() < 0.2:
			_penser(e, "super")
	agents.erase(int(a.id))


# --- Déplacements et choix ------------------------------------------------------------------------------------

## Le visiteur part vers un objet (ou la sortie si bid = −1), par la place centrale.
func _aller(a: Dictionary, bid: int, dest: Vector3) -> void:
	var e := int(a.parc)
	var from: Vector3 = a.pos
	var path := PackedVector3Array([from])
	var hub := centre(e) if parcs.has(e) else from
	# Petit écart pour que la foule ne marche pas en file indienne.
	var ang := rng.randf() * TAU
	var jit := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(3.5, 7.0)
	if from.distance_to(hub) > 6.0 and dest.distance_to(hub) > 6.0:
		path.append(hub + jit)
	path.append(dest + jit * 0.15)
	var long := 0.0
	for i in path.size() - 1:
		long += path[i].distance_to(path[i + 1])
	a.path = path
	a.t0 = clock
	a.t1 = clock + long / MARCHE
	a.cible = bid
	a.etat = "marche"
	a.fatigue = float(a.fatigue) + long * 0.004


## Position du visiteur à l'instant t (le long de son chemin).
func position_of(a: Dictionary, t: float) -> Vector3:
	var path: PackedVector3Array = a.path
	if String(a.etat) != "marche" and String(a.etat) != "sortie":
		return a.pos
	if path.size() < 2:
		return a.pos
	var f := clampf((t - float(a.t0)) / maxf(float(a.t1) - float(a.t0), 0.001), 0.0, 1.0)
	var long := 0.0
	for i in path.size() - 1:
		long += path[i].distance_to(path[i + 1])
	var s := f * long
	for i in path.size() - 1:
		var l := path[i].distance_to(path[i + 1])
		if s <= l:
			return path[i].lerp(path[i + 1], s / maxf(l, 0.001))
		s -= l
	return path[path.size() - 1]


## Attente estimée (minutes) à une attraction.
func attente(bid: int) -> float:
	var it: Dictionary = items[bid]
	var spec := ParcTypes.spec_of(_type_of(bid))
	var n := 0
	for aid in it.file:
		if agents.has(aid):
			n += int(agents[aid].w)
	var per := maxf(float(spec.get("cap", 10)), 1.0)
	var lent := 0.5 + 0.5 * float(personnel(bid)[0])
	return ceilf(float(n) / per) * float(spec.get("cycle", 3.0)) / lent


## Que faire maintenant ? (visiteur libre)
func _choisir(a: Dictionary) -> void:
	var e := int(a.parc)
	if not parcs.has(e):
		agents.erase(int(a.id))
		return
	_quitter_file(a)
	a.pos = position_of(a, clock) if String(a.etat) == "marche" else a.pos
	if not bool(parcs[e].ouvert) or clock >= float(a.fin) or float(a.humeur) < 22.0 or float(a.fatigue) >= 95.0:
		if float(a.fatigue) >= 95.0 and rng.randf() < 0.3:
			_penser(e, "fatigue")
		_partir(a)
		return
	# Besoins d'abord.
	if float(a.vessie) > 70.0:
		var t := _proche(a, items_of(e, "toilettes"))
		if t >= 0:
			_aller(a, t, _file_pos(t, 0))
			return
		if rng.randf() < 0.2:
			_penser(e, "toilettes")
	if float(a.faim) > 65.0 or float(a.soif) > 65.0:
		var vend := "manger" if float(a.faim) >= float(a.soif) else "boire"
		var st := _proche(a, _stands(e, vend))
		if st >= 0 and float(a.argent) >= float(ParcTypes.spec_of(_type_of(st)).prix):
			_aller(a, st, _file_pos(st, 0))
			return
		if st < 0 and rng.randf() < 0.15:
			_penser(e, "faim" if vend == "manger" else "soif")
	if float(a.fatigue) > 70.0:
		var r := _proche(a, items_of(e, "repos"))
		if r >= 0:
			_aller(a, r, _center(r) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)))
			return
	# Une attraction.
	var best := -1
	var best_s := -INF
	var file_min := 0.0
	for bid in attractions_ok(e):
		var it: Dictionary = items[bid]
		if bool(it.panne):
			continue
		var spec := ParcTypes.spec_of(_type_of(bid))
		var exc := float(spec.exc)
		var w_min := attente(bid)
		var s := 10.0 - absf(exc - float(a.pref)) * 1.2 - w_min / 6.0 - float(int((a.vus as Dictionary).get(bid, 0))) * 4.0
		if float(spec.int) > float(a.tol) + 3.0:
			s -= 8.0
		if float(a.argent) < float(parcs[e].prix_tour):
			s -= 50.0
		s += rng.randf_range(-2.0, 2.0)
		if s > best_s:
			best_s = s
			best = int(bid)
			file_min = w_min
	if best < 0 or best_s < -12.0:
		if rng.randf() < 0.25:
			_penser(e, "ennui")
		a.fin = minf(float(a.fin), clock + 1800.0)
		var r := _proche(a, items_of(e, "repos"))
		if r >= 0:
			_aller(a, r, _center(r))
		else:
			_partir(a)
		return
	# File trop longue pour sa patience : on râle, mais on y va quand même parfois.
	if file_min > 45.0 and rng.randf() < 0.15:
		_penser(e, "file", [roundi(file_min), nom_de(best)])
	_aller(a, best, _file_pos(best, (items[best].file as Array).size()))


func _stands(e: int, vend: String) -> Array:
	return items_of(e, "stand").filter(func(b: int) -> bool: return String(ParcTypes.spec_of(_type_of(b)).vend) == vend)


func _proche(a: Dictionary, list: Array) -> int:
	var best := -1
	var best_d := INF
	var pos: Vector3 = a.pos
	for bid in list:
		var d := pos.distance_to(_center(int(bid))) + (items[bid].file as Array).size() * 3.0
		if d < best_d:
			best_d = d
			best = int(bid)
	return best


## Place dans la file : en zigzag devant l'objet.
func _file_pos(bid: int, rang: int) -> Vector3:
	var f := facade(bid)
	var side := f.cross(Vector3.UP)
	var rangee := rang / 10
	var col := rang % 10
	if rangee % 2 == 1:
		col = 9 - col
	return porte(bid) + f * (1.0 + rangee * 1.3) + side * ((col - 4.5) * 0.75)


func _quitter_file(a: Dictionary) -> void:
	var c := int(a.cible)
	if c >= 0 and items.has(c):
		(items[c].file as Array).erase(int(a.id))
		(items[c].bord as Array).erase(int(a.id))


# --- Visiteurs, pas à pas ------------------------------------------------------------------------------------

func _visiteurs(e: int, now: Dictionary, dt: float) -> void:
	var p: Dictionary = parcs[e]
	var hrs := dt / 3600.0
	var sale := proprete(e) < 45.0
	for aid in agents.keys():
		if not agents.has(aid):
			continue
		var a: Dictionary = agents[aid]
		if int(a.parc) != e:
			continue
		a.faim = minf(100.0, float(a.faim) + 11.0 * hrs)
		a.soif = minf(100.0, float(a.soif) + (16.0 + 10.0 * float(int(now.month) in [6, 7, 8])) * hrs)
		a.vessie = minf(100.0, float(a.vessie) + 14.0 * hrs)
		var etat := String(a.etat)
		if etat != "repos":
			a.fatigue = minf(100.0, float(a.fatigue) + 6.0 * hrs)
		if float(a.faim) > 90.0 or float(a.soif) > 92.0:
			a.humeur = float(a.humeur) - 4.0 * hrs
		if float(a.vessie) > 95.0:
			a.humeur = float(a.humeur) - 8.0 * hrs
		if sale:
			a.humeur = float(a.humeur) - (45.0 - proprete(e)) / 8.0 * hrs
			if rng.randf() < 0.002:
				_penser(e, "sale")
		elif proprete(e) > 92.0 and rng.randf() < 0.0004:
			_penser(e, "propre")
		match etat:
			"marche":
				if clock >= float(a.t1):
					a.pos = (a.path as PackedVector3Array)[(a.path as PackedVector3Array).size() - 1]
					_arrive(a)
			"sortie":
				if clock >= float(a.t1):
					_sortir(a)
			"file":
				var c := int(a.cible)
				if not items.has(c) or bool(items[c].panne):
					if items.has(c) and bool(items[c].panne):
						a.humeur = float(a.humeur) - 4.0
					_choisir(a)
				else:
					a.humeur = float(a.humeur) - 1.5 * hrs * maxf(0.0, attente(c) / 20.0 - 0.5)
			"repos":
				a.fatigue = maxf(0.0, float(a.fatigue) - 45.0 * hrs)
				if float(a.fatigue) < 20.0:
					_choisir(a)
	# Attente moyenne (minutes) aux attractions ouvertes.
	var tot := 0.0
	var n := 0
	for bid in attractions_ok(e):
		if not bool(items[bid].panne):
			tot += attente(int(bid))
			n += 1
	p.attente = tot / n if n > 0 else 0.0


func _arrive(a: Dictionary) -> void:
	var c := int(a.cible)
	if c < 0 or not items.has(c):
		_choisir(a)
		return
	match String(items[c].role):
		"attraction", "stand", "toilettes":
			if bool(items[c].panne):
				_choisir(a)
				return
			(items[c].file as Array).append(int(a.id))
			a.etat = "file"
			a.pos = _file_pos(c, (items[c].file as Array).size() - 1)
		"repos":
			a.etat = "repos"
		_:
			_choisir(a)


# --- Attractions ---------------------------------------------------------------------------------------------

func _tourner(bid: int, e: int, dt: float) -> void:
	var it: Dictionary = items[bid]
	if bool(it.panne):
		return
	var spec := ParcTypes.spec_of(_type_of(bid))
	# Fin d'un tour : les passagers descendent.
	if float(it.fin) > 0.0 and clock >= float(it.fin):
		_fin_tour(bid, e, spec)
	if float(it.fin) > 0.0 or (it.file as Array).is_empty() or not bool(parcs[e].ouvert):
		return
	var staff: Array = personnel(bid)
	if float(staff[0]) <= 0.0:
		return
	# Embarquement : jusqu'à cap places.
	var cap := int(spec.get("cap", 10))
	var pris := 0
	var prix_tour := float(parcs[e].prix_tour)
	while not (it.file as Array).is_empty() and pris < cap:
		var aid := int((it.file as Array)[0])
		if not agents.has(aid):
			(it.file as Array).pop_front()
			continue
		var a: Dictionary = agents[aid]
		if pris > 0 and pris + int(a.w) > cap:
			break
		(it.file as Array).pop_front()
		if prix_tour > 0.0:
			if float(a.argent) < prix_tour:
				_penser(e, "fauche")
				_choisir(a)
				continue
			a.argent = float(a.argent) - prix_tour
			a.depense = float(a.depense) + prix_tour
			_encaisser(e, "tours", prix_tour * int(a.w))
			it.argent = float(it.argent) + prix_tour * int(a.w)
		(it.bord as Array).append(aid)
		a.etat = "bord"
		pris += int(a.w)
	if pris > 0:
		var lent := 0.5 + 0.5 * float(staff[0])
		it.fin = clock + float(spec.get("cycle", 3.0)) * 60.0 / lent


func _fin_tour(bid: int, e: int, spec: Dictionary) -> void:
	var it: Dictionary = items[bid]
	var p: Dictionary = parcs[e]
	var nom := nom_de(bid)
	var n := 0
	for aid in it.bord:
		if not agents.has(aid):
			continue
		var a: Dictionary = agents[aid]
		n += int(a.w)
		var exc := float(spec.exc)
		# Le deuxième tour plaît moins que le premier, le troisième encore moins.
		var deja := int((a.vus as Dictionary).get(bid, 0))
		var plaisir := (5.0 - absf(exc - float(a.pref)) * 1.2 + exc * 0.35) * pow(0.6, deja)
		a.humeur = clampf(float(a.humeur) + plaisir, 0.0, 100.0)
		if float(spec.int) > float(a.tol) + 1.0:
			a.humeur = float(a.humeur) - (float(spec.int) - float(a.tol)) * 3.0
			a.faim = maxf(0.0, float(a.faim) - 10.0)
			if rng.randf() < 0.12:
				_penser(e, "nausee", [nom])
		elif exc >= 6.0 and plaisir > 6.0 and rng.randf() < 0.06:
			_penser(e, "frisson", [nom])
		elif exc <= 2.5 and float(a.pref) > 6.5 and rng.randf() < 0.06:
			_penser(e, "trop_doux", [nom])
		a.tours = int(a.tours) + 1
		(a.vus as Dictionary)[bid] = int((a.vus as Dictionary).get(bid, 0)) + 1
		a.fatigue = float(a.fatigue) + float(spec.int) * 0.6
		a.etat = "libre"
		a.cible = -1
		_choisir(a)
	(it.bord as Array).clear()
	it.fin = 0.0
	it.tours = int(it.tours) + n
	p.jour.tours = int(p.jour.tours) + n
	# Usure et pannes.
	it.fiab = maxf(0.0, float(it.fiab) - float(spec.get("usure", 0.08)) * (1.0 + rng.randf()))
	var risque := 0.0008 + 0.06 * pow((100.0 - float(it.fiab)) / 100.0, 2.0)
	if rng.randf() < risque:
		_panne(bid, e)


func _panne(bid: int, e: int) -> void:
	var it: Dictionary = items[bid]
	it.panne = true
	it.repar = 0.0
	it.dep = false
	parcs[e].jour.pannes = int(parcs[e].jour.pannes) + 1
	for aid in (it.file as Array).duplicate() + (it.bord as Array).duplicate():
		if agents.has(aid):
			var a: Dictionary = agents[aid]
			a.humeur = float(a.humeur) - 5.0
			a.cible = -1
			a.etat = "libre"
			_choisir(a)
	(it.file as Array).clear()
	(it.bord as Array).clear()
	it.fin = 0.0
	_penser(e, "panne", [nom_de(bid)])
	_warn("panne%d" % bid, "Panne sur l'attraction %s (%s) : les passagers redescendent à pied, un peu vexés." % [nom_de(bid), String(parcs[e].nom)], 3600.0)


## Révisions et réparations (techniciens), propreté (agents) ; dépanneur extérieur sinon.
func _entretien(e: int, dt: float) -> void:
	var p: Dictionary = parcs[e]
	var eq := _equipes(e)
	var techs := float(eq[0])
	p.techs = techs
	p.agents_propre = float(eq[1])
	var hrs := dt / 3600.0
	var dispo := techs
	for bid in attractions_ok(e):
		var it: Dictionary = items[bid]
		if not bool(it.panne):
			continue
		if float(it.repar) <= 0.0:
			if dispo >= 1.0:
				it.repar = clock + rng.randf_range(0.75, 2.0) * 3600.0
				it.dep = false
			else:
				it.repar = clock + DEPANNEUR_H * 3600.0
				it.dep = true
		if dispo >= 1.0 and not bool(it.dep):
			dispo -= 1.0
		if clock >= float(it.repar):
			it.panne = false
			it.fiab = maxf(float(it.fiab), 70.0)
			if bool(it.dep):
				_payer(e, "Parc : dépanneur extérieur", DEPANNEUR_PRIX)
			it.repar = 0.0
	# Révisions, parc fermé (la nuit et le matin) : l'équipe remonte la fiabilité des plus usées.
	if dispo > 0.0 and not bool(p.ouvert):
		var list := attractions_ok(e).filter(func(b: int) -> bool: return not bool(items[b].panne))
		list.sort_custom(func(x: int, y: int) -> bool: return float(items[x].fiab) < float(items[y].fiab))
		var pts := dispo * 7.0 * hrs
		for bid in list:
			if pts <= 0.0:
				break
			var it: Dictionary = items[bid]
			var gain := minf(pts, 100.0 - float(it.fiab))
			it.fiab = float(it.fiab) + gain
			pts -= gain


# --- Stands et toilettes -------------------------------------------------------------------------------------

func _servir(bid: int, e: int, dt: float) -> void:
	var it: Dictionary = items[bid]
	var spec := ParcTypes.spec_of(_type_of(bid))
	if (it.file as Array).is_empty() or not bool(parcs[e].ouvert):
		return
	var staff := float(personnel(bid)[0])
	var rate := float(spec.get("service", 60.0)) * (0.5 + 0.5 * staff)
	it.serv = float(it.serv) + rate * dt / 3600.0
	var sale_f := 1.0
	for r in items_of(e, "repos"):
		sale_f *= 0.85
	sale_f = maxf(sale_f, 0.45)
	while not (it.file as Array).is_empty() and float(it.serv) >= 1.0:
		var aid := int((it.file as Array).pop_front())
		if not agents.has(aid):
			continue
		var a: Dictionary = agents[aid]
		it.serv = float(it.serv) - 1.0
		if String(it.role) == "toilettes":
			a.vessie = 0.0
		else:
			var vend := String(spec.vend)
			var prix := float(spec.prix)
			if float(a.argent) >= prix:
				a.argent = float(a.argent) - prix
				a.depense = float(a.depense) + prix
				_encaisser(e, "stands", prix * int(a.w))
				it.argent = float(it.argent) + prix * int(a.w)
				if vend == "manger":
					a.faim = maxf(0.0, float(a.faim) - 65.0)
					a.soif = float(a.soif) + 8.0
					a.humeur = float(a.humeur) + 3.0
					parcs[e].salete = float(parcs[e].salete) + 0.35 * int(a.w) * sale_f
					if _type_of(bid) == "friterie_parc" and rng.randf() < 0.04:
						_penser(e, "frites")
				elif vend == "boire":
					a.soif = maxf(0.0, float(a.soif) - 70.0)
					a.vessie = float(a.vessie) + 15.0
					parcs[e].salete = float(parcs[e].salete) + 0.2 * int(a.w) * sale_f
				else:
					a.humeur = float(a.humeur) + 4.0
			else:
				if rng.randf() < 0.2:
					_penser(e, "fauche")
		a.etat = "libre"
		a.cible = -1
		_choisir(a)
	it.serv = minf(float(it.serv), 3.0)


# --- Note, propreté, pensées ---------------------------------------------------------------------------

## Propreté du parc : 100 = impeccable.
func proprete(e: int) -> float:
	var p: Dictionary = parcs[e]
	var taille := maxf(1.0, float((p.items as Array).size()) * 0.5)
	return 100.0 / (1.0 + float(p.salete) / (60.0 * taille))


## Humeur moyenne des visiteurs présents (ou de ceux sortis aujourd'hui).
func humeur_moyenne(e: int) -> float:
	var tot := 0.0
	var n := 0
	for a in agents.values():
		if int(a.parc) == e:
			tot += float(a.humeur) * int(a.w)
			n += int(a.w)
	var j: Dictionary = parcs[e].jour
	tot += float(j.humeur)
	n += int(j.sortis)
	return tot / n if n > 0 else 70.0


## Note du moment, de 0 à 5 étoiles, et son détail.
func detail_note(e: int) -> Dictionary:
	var p: Dictionary = parcs[e]
	var att := attractions_ok(e)
	var sortes := {}
	var fiab := 0.0
	for bid in att:
		sortes[String(ParcTypes.spec_of(_type_of(bid)).get("anim", _type_of(bid)))] = true
		fiab += float(items[bid].fiab) * (0.3 if bool(items[bid].panne) else 1.0)
	var variete := clampf(float(sortes.size()) / 8.0, 0.0, 1.0)
	var services := 0.0
	if not _stands(e, "manger").is_empty():
		services += 0.35
	if not _stands(e, "boire").is_empty():
		services += 0.3
	if not items_of(e, "toilettes").is_empty():
		services += 0.35
	var d := {
		"variete": variete,
		"humeur": clampf((humeur_moyenne(e) - 20.0) / 70.0, 0.0, 1.0),
		"proprete": proprete(e) / 100.0,
		"attente": 1.0 - clampf((float(p.attente) - 10.0) / 50.0, 0.0, 1.0),
		"prix": clampf(valeur(e) / maxf(float(p.prix) + float(p.prix_tour) * 4.0, 1.0), 0.0, 1.0),
		"fiabilite": fiab / maxf(att.size(), 1) / 100.0,
		"services": services,
	}
	var poids := {"variete": 0.24, "humeur": 0.24, "proprete": 0.14, "attente": 0.1, "prix": 0.1, "fiabilite": 0.06, "services": 0.12}
	var note := 0.0
	for k in poids:
		note += float(d[k]) * float(poids[k])
	d["note"] = clampf(note * 5.0, 0.0, 5.0)
	return d


func note_cible(e: int) -> float:
	return float(detail_note(e).note)


static func etoiles(note: float) -> String:
	var n := clampi(roundi(note * 2.0), 0, 10)
	var s := ""
	for i in 5:
		s += "★" if n >= (i + 1) * 2 else ("⯪" if n == i * 2 + 1 else "☆")
	return s


func _penser(e: int, cle: String, args: Array = []) -> void:
	if not parcs.has(e):
		return
	var p: Dictionary = parcs[e]
	var pens: Dictionary = p.pensees
	pens[cle] = int(pens.get(cle, 0)) + 1
	var txt := String(PENSEES.get(cle, cle))
	if not args.is_empty():
		txt = txt % args
	var d: Array = p.dernieres
	d.push_front(txt)
	if d.size() > 8:
		d.resize(8)


# --- Argent ----------------------------------------------------------------------------------------

const POSTES := {"billets": "Parc de loisirs : billets", "tours": "Parc de loisirs : tours payants", "stands": "Parc de loisirs : stands",
	"sejour": "Taxe de séjour"}


func _encaisser(e: int, quoi: String, montant: float) -> void:
	var p: Dictionary = parcs[e]
	match quoi:
		"billets": p.jour.billets = float(p.jour.billets) + montant
		"tours": p.jour.tours_argent = float(p.jour.tours_argent) + montant
		"stands": p.jour.stands = float(p.jour.stands) + montant
	var poste := String(POSTES.get(quoi, "Parc de loisirs"))
	_flux(e, poste, montant)


func _payer(e: int, poste: String, montant: float) -> void:
	if parcs.has(e):
		parcs[e].jour.depenses = float(parcs[e].jour.depenses) + montant
	_flux(e, poste, -montant)


## Verse (ou prélève) dans la caisse de la ville où est l'entrée du parc.
func _flux(e: int, poste: String, montant: float) -> void:
	if buildings == null or buildings.unlimited_money or absf(montant) < 0.01:
		return
	var prev := Pays.au_batiment(e)
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		if montant > 0.0:
			bc.recette(poste, montant)
		else:
			bc.depense(poste, -montant)
	else:
		var p: Dictionary = parcs.get(e, {})
		if not p.is_empty():
			p.argent = float(p.argent) + montant
			var whole := int(p.argent)
			if whole != 0:
				buildings.money += whole
				p.argent = float(p.argent) - whole
	Pays.retour(prev)


## Salaires et entretien du jour.
func _charges(e: int) -> void:
	var p: Dictionary = parcs[e]
	var salaires := 0.0
	var saison := 0
	var entretien := 0.0
	for bid in p.items:
		if not items.has(bid) or en_chantier(int(bid)):
			continue
		var t := _type_of(int(bid))
		entretien += float(BuildingCatalog.cost(t)) * ENTRETIEN_MOIS / 30.44
		var emplois := int(BuildingCatalog.get_type(t).get("emplois", 0))
		if emplois <= 0:
			continue
		var st := personnel(int(bid))
		var moyen := 0.0
		for m in Metiers.jobs_for(t):
			moyen += float(Metiers.job(String(m[0])).salaire) * float(m[1])
		moyen /= maxf(1.0, float(emplois))
		var tenus := float(st[0]) * emplois - float(st[1])
		salaires += (maxf(tenus, 0.0) * moyen + float(st[1]) * moyen * SAISON_X) / 30.44
		saison += int(st[1])
	p.saison = saison
	if salaires > 0.0:
		_payer(e, "Parc de loisirs : salaires", salaires)
	if entretien > 0.0:
		_payer(e, "Parc de loisirs : entretien", entretien)


func new_day() -> void:
	for e in parcs:
		var p: Dictionary = parcs[e]
		_charges(int(e))
		for k in p.jour:
			if p.jour[k] is int:
				p.total[k] = int(p.total.get(k, 0)) + int(p.jour[k])
			else:
				p.total[k] = float(p.total.get(k, 0.0)) + float(p.jour[k])
		p.hier = p.jour
		p.jour = _empty_stats()
		# Les pensées s'effacent peu à peu.
		var pens: Dictionary = p.pensees
		for k in pens.keys():
			pens[k] = int(int(pens[k]) * 0.6)
			if int(pens[k]) <= 0:
				pens.erase(k)
		for bid in p.items:
			if items.has(bid):
				items[bid].tours = 0
				items[bid].argent = 0.0
	# Les sorties de plus de 30 jours sont oubliées.
	for pid in sorties.keys():
		if last_day - int(sorties[pid]) > 30:
			sorties.erase(pid)


func _warn(key: String, text: String, every := 3600.0 * 6.0) -> void:
	if clock - float(_warned.get(key, -INF)) < every:
		return
	_warned[key] = clock
	message.emit(text)


# --- Réglages du joueur ------------------------------------------------------------------------------

func set_prix(e: int, entree: float, tour := -1.0) -> void:
	if not parcs.has(e):
		return
	parcs[e].prix = clampf(entree, 0.0, 120.0)
	if tour >= 0.0:
		parcs[e].prix_tour = clampf(tour, 0.0, 15.0)
	changed.emit()


func renommer(e: int, nom: String) -> void:
	if parcs.has(e) and nom.strip_edges() != "":
		parcs[e].nom = nom.strip_edges().left(40)
		changed.emit()


# --- Liens avec les autres systèmes ----------------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "parc_loisirs", "theme": "loisirs", "f": satisfaction_of}]


## Effet du parc sur un habitant : [delta, raisons].
func satisfaction_of(p: Dictionary) -> Array:
	if parcs.is_empty() or population == null:
		return [0.0, []]
	var pid := int(p.get("id", -1))
	if pid >= 0 and sorties.has(pid) and last_day - int(sorties[pid]) <= 30:
		return [3.0, ["+ Une belle journée au parc de loisirs"]]
	var home := population.home_of(p)
	if home < 0:
		return [0.0, []]
	var hp := population.building_pos(home)
	for e in parcs:
		if float(parcs[e].note) >= 3.0 and Vector2(hp.x, hp.z).distance_to(Vector2(_center(int(e)).x, _center(int(e)).z)) < 2500.0:
			return [1.5, ["+ Un parc de loisirs pas loin, les enfants sont ravis"]]
	return [0.0, []]


func pollution_sources() -> Array:
	var out: Array = []
	for e in parcs:
		var n := attractions_ok(int(e)).size()
		if n == 0:
			continue
		out.append({"pos": centre(int(e)), "rayon": 250.0 + 15.0 * n, "bruit": clampf(0.2 + 0.05 * n, 0.2, 0.6),
			"nom": String(parcs[e].nom), "bid": int(e)})
	return out


func summary() -> String:
	if parcs.is_empty():
		return ""
	var v := 0
	for e in parcs:
		v += int(parcs[e].hier.visiteurs)
	return "Parc : %d visiteurs hier" % v


## Visiteurs en ce moment dans un parc (personnes, pas visiteurs suivis).
func presents(e: int) -> int:
	var n := 0
	for a in agents.values():
		if int(a.parc) == e:
			n += int(a.w)
	return n


## Conseils au joueur, en phrases simples.
func conseils(e: int) -> Array[String]:
	var out: Array[String] = []
	if not parcs.has(e):
		return out
	var p: Dictionary = parcs[e]
	if attractions_ok(e).is_empty():
		out.append("Aucune attraction : pose-en à moins de 250 m de l'entrée (Construire → Parc de loisirs).")
	if not _relie(e):
		out.append("L'entrée n'est pas reliée à une route : presque aucun touriste ne trouve le parc.")
	if _stands(e, "manger").is_empty():
		out.append("Pas de friterie ni de glacier : les visiteurs affamés partent plus tôt.")
	if _stands(e, "boire").is_empty():
		out.append("Pas de buvette : il fait soif, surtout l'été.")
	if items_of(e, "toilettes").is_empty():
		out.append("Pas de toilettes : c'est la première chose que les visiteurs remarquent.")
	if items_of(e, "atelier").is_empty():
		out.append("Pas d'atelier d'entretien : personne ne ramasse les papiers ni ne révise les manèges, et le dépanneur extérieur est lent et cher.")
	if proprete(e) < 50.0:
		out.append("Le parc est sale : un atelier de plus (agents de propreté) et des aires de repos avec poubelles.")
	if float(p.attente) > 30.0:
		out.append("Les files sont longues (%d min en moyenne) : ajoute des attractions." % roundi(float(p.attente)))
	if float(p.prix) > valeur(e) * 1.2:
		out.append("L'entrée est chère pour ce que propose le parc (il vaut environ %d €)." % roundi(valeur(e)))
	if int(p.saison) > 0:
		out.append("%d saisonniers venus d'ailleurs complètent le personnel (ils coûtent 30 %% de plus) : la ville manque d'habitants pour ces emplois." % int(p.saison))
	var hp := hors_parc()
	if not hp.is_empty():
		out.append("%d objet(s) du parc sont trop loin d'une entrée (plus de 250 m) et ne servent à rien." % hp.size())
	if out.is_empty():
		out.append("Tout va bien. Les visiteurs crient sur les manèges, c'est bon signe.")
	return out


# --- Sauvegarde -------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ps := {}
	for e in parcs:
		var p: Dictionary = parcs[e]
		ps[str(e)] = {"nom": p.nom, "prix": p.prix, "prix_tour": p.prix_tour, "note": snappedf(float(p.note), 0.01),
			"salete": snappedf(float(p.salete), 0.1), "hier": p.hier, "total": p.total, "pensees": p.pensees}
	var its := {}
	for bid in items:
		var it: Dictionary = items[bid]
		if String(it.role) == "attraction":
			its[str(bid)] = {"fiab": snappedf(float(it.fiab), 0.1), "panne": bool(it.panne)}
	var so := {}
	for pid in sorties:
		so[str(pid)] = int(sorties[pid])
	return {"v": 1, "parcs": ps, "items": its, "sorties": so}


func from_dict(d: Dictionary) -> void:
	clear()
	_sync()
	var ps: Dictionary = d.get("parcs", {})
	for k in ps:
		var e := int(k)
		if not parcs.has(e):
			continue
		var s: Dictionary = ps[k]
		var p: Dictionary = parcs[e]
		p.nom = String(s.get("nom", p.nom))
		p.prix = float(s.get("prix", PRIX_ENTREE))
		p.prix_tour = float(s.get("prix_tour", PRIX_TOUR))
		p.note = float(s.get("note", 2.5))
		p.salete = float(s.get("salete", 0.0))
		var h: Dictionary = _empty_stats()
		h.merge(s.get("hier", {}), true)
		p.hier = h
		var tot: Dictionary = _empty_stats()
		tot.merge(s.get("total", {}), true)
		p.total = tot
		p.pensees = (s.get("pensees", {}) as Dictionary).duplicate()
	var its: Dictionary = d.get("items", {})
	for k in its:
		var bid := int(k)
		if items.has(bid):
			items[bid].fiab = float(its[k].get("fiab", 100.0))
			items[bid].panne = bool(its[k].get("panne", false))
	var so: Dictionary = d.get("sorties", {})
	for k in so:
		sorties[int(k)] = int(so[k])
	changed.emit()
