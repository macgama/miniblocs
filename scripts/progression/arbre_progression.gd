class_name ArbreProgression
extends RefCounted
## Arbre de progression à points (choix de Gaël, 2026-11-17) : à la place des
## déblocages automatiques par paliers de population, le joueur gagne des points
## de progrès en jouant (records de population, rang des villes, missions,
## succès) et les dépense dans 9 branches de 4 niveaux. Chaque niveau ouvre les
## bâtiments (ou les voies et stations) de sa branche jusqu'à une taille donnée.
##
## L'état vit dans ReglagesPartie (sauvegardé avec la partie) : `arbre`
## (branche -> niveau acheté), `points_bonus` (points gagnés hors population) et
## `journal_points`. Les points de population se déduisent du record d'habitants.
## L'époque passe avant l'arbre : un niveau acheté n'ouvre pas ce qui n'est pas
## encore inventé (Epoques.raison_batiment, raison_voie, raison_station).

const POINTS_DEPART := 3
## +1 point à chaque record de population franchi.
const SEUILS_POPULATION := [50, 100, 250, 500, 1000, 2000, 5000, 10000, 25000, 50000, 100000]
## Points quand une ville monte de rang (Objectifs.PALIERS, par nom).
const POINTS_RANG := {"Village": 2, "Bourg": 2, "Ville": 3, "Ville moyenne": 3, "Grande ville": 4, "Métropole": 5}
const POINTS_MISSION := 1
const POINTS_SUCCES := 1
## Prix des niveaux I à IV (le niveau 0 est ouvert d'office).
const COUTS := [0, 1, 2, 3, 4]
const NIVEAU_MAX := 4
const CHIFFRES := ["0", "I", "II", "III", "IV"]
## Taille des bâtiments par niveau : prix maximal (comme les anciens paliers).
const PRIX_NIVEAUX := [1_500_000, 5_000_000, 15_000_000, 40_000_000]
## Grands monuments (tous chers) : niveaux I à IV par prix, aucun au niveau 0.
const PRIX_PATRIMOINE := [0, 25_000_000, 60_000_000, 100_000_000]

const BRANCHES := [
	{"id": "logement", "nom": "Logement", "icon": "logement", "cats": ["logement"],
		"desc": "Maisons, immeubles, tours et grands ensembles."},
	{"id": "commerce", "nom": "Commerce", "icon": "commerce", "cats": ["commerce"],
		"desc": "Boutiques, bureaux, supermarchés et centres commerciaux."},
	{"id": "industrie", "nom": "Industrie", "icon": "industrie", "cats": ["industrie", "production"],
		"desc": "Ateliers, usines et grandes industries (la production de base reste ouverte)."},
	{"id": "services", "nom": "Services publics", "icon": "services", "cats": ["services", "funeraire"],
		"desc": "Mairie, police, pompiers, santé, enseignement supérieur, cimetières."},
	{"id": "loisirs", "nom": "Loisirs et sport", "icon": "sport", "cats": ["loisirs", "sport", "espaces"],
		"desc": "Parcs, places, cafés, cinémas, terrains, piscines et stades."},
	{"id": "reseaux", "nom": "Réseaux et déchets", "icon": "reseaux", "cats": ["reseaux", "dechets"],
		"desc": "Grandes centrales, usines d'eau, tri et incinération (les petits réseaux restent ouverts)."},
	{"id": "tourisme", "nom": "Tourisme et parcs", "icon": "parc", "cats": ["tourisme", "parc", "zoo", "spectacles"],
		"desc": "Campings, hôtels, parc de loisirs, zoo, salles de spectacle."},
	{"id": "transports", "nom": "Transports", "icon": "route", "cats": [],
		"desc": "Avenues et tram, rail, métro, voies express, autoroutes, LGV et aéroport."},
	{"id": "patrimoine", "nom": "Patrimoine", "icon": "patrimoine", "cats": ["patrimoine"],
		"desc": "Grands monuments et chefs-d'œuvre d'architecture."},
]

## Voies (TransportTypes.CLASSES) et stations (StationSystem.TYPES) par niveau
## de la branche Transports. Absent = niveau 0 (rue, départementale, chemins…).
const VOIES := {"avenue": 1, "giratoire": 1, "tram": 1, "train": 1,
	"voie_express": 2, "bretelle": 2, "cremaillere": 2, "metro": 2,
	"autoroute": 3, "lgv": 4}
const STATIONS := {"arret_tram": 1, "gare": 1, "station_metro": 2, "heliport": 2, "aerodrome": 2, "aeroport": 4}

## Bâtiments toujours ouverts : il en faut tôt pour qu'une ville vive.
const TOUJOURS := ["ecole", "maison_commune"]

static var _branche_cat := {}
static var _cache_niveau := {}

## Carte entre amis (choix de Gaël, 2026-11-18) : un arbre par joueur, comme la
## caisse (ReglagesPartie.arbres_joueurs). Le serveur fait foi : il compte les
## points et fait les achats ; chaque joueur regarde son propre arbre. Pendant
## l'action d'un joueur, le serveur met `joueur_serveur` à son identifiant ; ce
## qu'aucun joueur ne fait (pousse des zones, pilote…) n'est pas verrouillé.
static var joueur_serveur := ""
## Serveur : maire d'une ville (vid -> pid) et membres de la carte (pour les
## succès du pays, partagés par tous).
static var maire_de: Callable
static var membres: Callable


static func multi() -> bool:
	return Multijoueur.role != Multijoueur.Role.SOLO


static func joueur() -> String:
	if Multijoueur.role == Multijoueur.Role.CLIENT and Multijoueur.client != null:
		return Multijoueur.client.pid
	return joueur_serveur


static func _j(r: ReglagesPartie) -> Dictionary:
	var pid := joueur()
	if not r.arbres_joueurs.has(pid):
		r.arbres_joueurs[pid] = {"arbre": {}, "bonus": 0, "journal": [], "record": 0}
	return r.arbres_joueurs[pid]


static func _par_joueur() -> bool:
	return multi() and joueur() != ""


static func arbre_de(r: ReglagesPartie) -> Dictionary:
	return _j(r).arbre if _par_joueur() else r.arbre


static func bonus_de(r: ReglagesPartie) -> int:
	return int(_j(r).bonus) if _par_joueur() else r.points_bonus


static func record_de(r: ReglagesPartie) -> int:
	return int(_j(r).record) if _par_joueur() else r.record_habitants


static func journal_de(r: ReglagesPartie) -> Array:
	return _j(r).journal if _par_joueur() else r.journal_points


## Exécute f avec l'arbre d'un autre joueur, puis revient au joueur courant.
static func pour(pid: String, f: Callable) -> Variant:
	var avant := joueur_serveur
	joueur_serveur = pid
	var res: Variant = f.call()
	joueur_serveur = avant
	return res


# --- Données ----------------------------------------------------------------------------

static func branche(id: String) -> Dictionary:
	for b in BRANCHES:
		if String(b.id) == id:
			return b
	return {}


static func nom_niveau(branche_id: String, niveau: int) -> String:
	return "%s %s" % [String(branche(branche_id).get("nom", branche_id)), CHIFFRES[clampi(niveau, 0, NIVEAU_MAX)]]


## Branche d'une catégorie de bâtiment ("" = hors arbre, toujours ouvert).
static func branche_de_cat(cat: String) -> String:
	if _branche_cat.is_empty():
		for b in BRANCHES:
			for c in b.cats:
				_branche_cat[String(c)] = String(b.id)
	return String(_branche_cat.get(cat, ""))


static func branche_batiment(id: String) -> String:
	return branche_de_cat(String(BuildingCatalog.get_type(id).get("cat", "")))


## Niveau de la branche qu'il faut pour ce bâtiment (0 = ouvert d'office).
static func niveau_batiment(id: String) -> int:
	if _cache_niveau.has(id):
		return int(_cache_niveau[id])
	var n := _calcule_niveau(id)
	_cache_niveau[id] = n
	return n


static func _calcule_niveau(id: String) -> int:
	var t := BuildingCatalog.get_type(id)
	var cat := String(t.get("cat", ""))
	if branche_de_cat(cat) == "":
		return 0
	# La production de base fait vivre une ville qui démarre.
	if cat == "production":
		return 0
	# Il faut du courant et de l'eau dès le hameau (sauf les très grosses centrales).
	if cat == "reseaux" and BuildingCatalog.cost(id) <= 50_000_000:
		return 0
	if TOUJOURS.has(id) or TOUJOURS.has(BuildingCatalog.base_of(id)):
		return 0
	for k in Metiers.keys_of(id):
		if TOUJOURS.has(k):
			return 0
	var c := BuildingCatalog.cost(id)
	var paliers: Array = PRIX_PATRIMOINE if cat == "patrimoine" else PRIX_NIVEAUX
	for i in paliers.size():
		if c <= int(paliers[i]):
			return i
	return NIVEAU_MAX


static func vider_cache() -> void:
	_cache_niveau.clear()
	_cache_contenu.clear()


# --- Points -----------------------------------------------------------------------------

static func points_population(record: int) -> int:
	var n := 0
	for s in SEUILS_POPULATION:
		if record >= int(s):
			n += 1
	return n


static func prochain_seuil(record: int) -> int:
	for s in SEUILS_POPULATION:
		if record < int(s):
			return int(s)
	return -1


static func points_gagnes(r: ReglagesPartie) -> int:
	return POINTS_DEPART + points_population(record_de(r)) + bonus_de(r)


static func points_depenses(r: ReglagesPartie) -> int:
	var n := 0
	var a := arbre_de(r)
	for b in a:
		for i in range(1, mini(int(a[b]), NIVEAU_MAX) + 1):
			n += int(COUTS[i])
	return n


static func points_disponibles(r: ReglagesPartie) -> int:
	return points_gagnes(r) - points_depenses(r)


## Ajoute des points de progrès (rang, mission, succès, admin) et les note au journal.
static func gagner(r: ReglagesPartie, n: int, raison: String) -> void:
	if r == null or n == 0:
		return
	if _par_joueur():
		_j(r).bonus = int(_j(r).bonus) + n
	else:
		r.points_bonus += n
	noter(r, n, raison)


static func noter(r: ReglagesPartie, n: int, raison: String) -> void:
	var j := journal_de(r)
	j.append({"n": n, "raison": raison})
	while j.size() > 12:
		j.pop_front()


## Carte entre amis : record de population d'un joueur (ses villes). Renvoie les points gagnés.
static func note_population_joueur(r: ReglagesPartie, pid: String, n: int) -> int:
	return int(pour(pid, func() -> int:
		var e := _j(r)
		if n <= int(e.record):
			return 0
		var avant := points_population(int(e.record))
		e.record = n
		var gain := points_population(n) - avant
		if gain > 0:
			noter(r, gain, "%d habitants" % SEUILS_POPULATION[points_population(n) - 1])
		return gain))


## Points pour une ville (vid -1 : tout le pays). En solo, le joueur ; sur une
## carte entre amis (serveur), le maire de la ville, ou chaque membre pour le pays.
static func _gagner_ville(vid: int, n: int, raison: String) -> void:
	# Carte entre amis : seul le serveur compte les points.
	if n <= 0 or Multijoueur.role == Multijoueur.Role.CLIENT:
		return
	var r := ReglagesPartie.actuel
	if not multi():
		gagner(r, n, raison)
		return
	var pids: Array = []
	if vid >= 0 and maire_de.is_valid():
		var m := String(maire_de.call(vid))
		if m != "":
			pids.append(m)
	elif membres.is_valid():
		pids = membres.call()
	for pid in pids:
		pour(String(pid), func() -> void: gagner(r, n, raison))


## Raccourcis pour la partie en cours, appelés par Objectifs (rangs, missions, succès).
static func rang_atteint(nom_rang: String, ville: String, vid := -1) -> void:
	_gagner_ville(vid, int(POINTS_RANG.get(nom_rang, 0)), "%s devient %s" % [ville, nom_rang])


static func mission_reussie(texte: String, vid := -1) -> void:
	_gagner_ville(vid, POINTS_MISSION, "Mission : " + texte)


static func succes_gagne(nom: String) -> void:
	_gagner_ville(-1, POINTS_SUCCES, "Succès « %s »" % nom)


# --- Niveaux ----------------------------------------------------------------------------

static func niveau(r: ReglagesPartie, branche_id: String) -> int:
	return clampi(int(arbre_de(r).get(branche_id, 0)), 0, NIVEAU_MAX)


## Raison pour laquelle on ne peut pas acheter le niveau suivant, ou "".
static func refus_achat(r: ReglagesPartie, branche_id: String) -> String:
	if branche(branche_id).is_empty():
		return "Branche inconnue."
	var n := niveau(r, branche_id) + 1
	if n > NIVEAU_MAX:
		return "Branche complète."
	if points_disponibles(r) < int(COUTS[n]):
		return "Il faut %d point%s (tu en as %d)." % [int(COUTS[n]), "s" if int(COUTS[n]) > 1 else "", points_disponibles(r)]
	return ""


## Achète le niveau suivant d'une branche. Renvoie "" si c'est fait, sinon la raison.
static func acheter(r: ReglagesPartie, branche_id: String) -> String:
	var refus := refus_achat(r, branche_id)
	if refus != "":
		return refus
	arbre_de(r)[branche_id] = niveau(r, branche_id) + 1
	return ""


static func est_ouvert(r: ReglagesPartie, branche_id: String, niveau_requis: int) -> bool:
	if r.deblocage != "arbre" or niveau_requis <= 0 or branche_id == "":
		return true
	# Carte entre amis : ce qu'aucun joueur ne fait (zones, pilote…) n'est pas verrouillé.
	if multi() and joueur() == "":
		return true
	return niveau(r, branche_id) >= niveau_requis


static func batiment_ouvert(r: ReglagesPartie, id: String) -> bool:
	return est_ouvert(r, branche_batiment(id), niveau_batiment(id))


static func _texte_requis(r: ReglagesPartie, branche_id: String, n: int) -> String:
	return "À débloquer dans l'arbre de progression : %s (Maj+F10)." % nom_niveau(branche_id, n)


static func raison_batiment(r: ReglagesPartie, id: String) -> String:
	if batiment_ouvert(r, id):
		return ""
	return _texte_requis(r, branche_batiment(id), niveau_batiment(id))


## Court texte pour une carte du catalogue : « Arbre · Logement II ».
static func etiquette(id: String) -> String:
	return "Arbre · " + nom_niveau(branche_batiment(id), niveau_batiment(id))


static func raison_voie(r: ReglagesPartie, cls: String) -> String:
	var n := int(VOIES.get(TransportTypes.resolve(cls), 0))
	if est_ouvert(r, "transports", n):
		return ""
	var t := _texte_requis(r, "transports", n)
	return "%s : %s" % [String(TransportTypes.get_type(cls).get("name", cls)), t[0].to_lower() + t.substr(1)]


static func raison_station(r: ReglagesPartie, type_id: String) -> String:
	var n := int(STATIONS.get(type_id, 0))
	if est_ouvert(r, "transports", n):
		return ""
	return _texte_requis(r, "transports", n)


# --- Contenu d'un niveau (panneau) ------------------------------------------------------

static var _cache_contenu := {}


## Ce que ce niveau ouvre exactement : {ids, noms, pas_inventes}.
static func contenu(branche_id: String, n: int, r: ReglagesPartie = null) -> Dictionary:
	var cle := "%s:%d" % [branche_id, n]
	if not _cache_contenu.has(cle):
		_cache_contenu[cle] = _calcule_contenu(branche_id, n)
	var c: Dictionary = _cache_contenu[cle]
	var futurs := 0
	if r != null and Epoques.actif(r):
		for id in c.ids:
			if Epoques.raison_batiment(String(id), r) != "":
				futurs += 1
	return {"ids": c.ids, "noms": c.noms, "pas_inventes": futurs}


static func _calcule_contenu(branche_id: String, n: int) -> Dictionary:
	var ids: Array[String] = []
	var noms: Array[String] = []
	if branche_id == "transports":
		for v in VOIES:
			if int(VOIES[v]) == n:
				noms.append(String(TransportTypes.get_type(v).get("name", v)))
		for s in STATIONS:
			if int(STATIONS[s]) == n:
				noms.append(String(StationSystem.TYPES[s].name) if StationSystem.TYPES.has(s) else String(s))
		return {"ids": ids, "noms": noms}
	var types := BuildingCatalog.all_types()
	for id in types:
		var t: Dictionary = types[id]
		if t.get("cache", false) or Creations.items.has(id):
			continue
		if branche_de_cat(String(t.get("cat", ""))) != branche_id or niveau_batiment(id) != n:
			continue
		ids.append(String(id))
		noms.append(String(t.get("name", id)))
	return {"ids": ids, "noms": noms}
