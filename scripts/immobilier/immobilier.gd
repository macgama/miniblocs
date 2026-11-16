class_name Immobilier
extends Node
## Immobilier vivant (panneau Immobilier, F11) : les quartiers changent de visage
## tout seuls.
##
## - Marché : chaque ville a un indice des prix qui suit la tension du marché
##   (logements vides, emplois qui attirent du monde). Les loyers et les prix de
##   vente suivent la valeur du terrain (Nuisances) × cet indice. Rares krachs
##   quand les prix sont trop hauts. Le maire peut encadrer les loyers.
## - Promoteurs privés : quatre sociétés qui cherchent chaque semaine une bonne
##   affaire : résidence de standing dans un quartier cher, maisons qui
##   remplacent les champs, maisons rasées pour un immeuble, vieux immeubles
##   rachetés et rénovés en haut de gamme. Permis de construire libre, sur
##   demande (le maire accepte ou refuse) ou gelé ; quota de logements sociaux
##   imposé ; taxe d'aménagement payée à la ville.
## - Gentrification : chaque secteur de 200 m garde son histoire (prix, part des
##   foyers modestes). Un secteur qui s'embourgeoise fait peur aux modestes qui
##   y vivent ; un secteur qui se paupérise inquiète ses habitants.
## - Bidonvilles : une famille qui ne trouve plus aucun logement abordable, ou
##   des travailleurs attirés par des emplois sans logement pour eux, bâtissent
##   des baraques en bordure de ville. Pas d'eau, pas d'égouts : odeurs, eau
##   polluée, terrains voisins dévalués, habitants bloqués au niveau Précaire.
##   Le maire peut viabiliser (eau, courant), reloger (s'il y a des logements
##   abordables, sociaux surtout) ou raser (les familles quittent la ville, et
##   la ville s'en souvient).
## - Logements sociaux datés (ImmobilierTypes) : loyer modéré, la ville touche
##   les loyers et paie l'entretien (groupe « budget_ville »).
##
## Crochets pour les autres systèmes (neutres sans ce module) :
##   Immobilier.mult_loyer(bid, coef) : multiplicateur du loyer (Nuisances.loyer,
##     Population.household_budget) ; Immobilier.coef_taxe(bid) (taxe foncière) ;
##   Immobilier.precaire(bid), viabilise(bid) (NiveauxVie, déménagements).

signal changed
signal message(text: String)

static var instance: Immobilier

## Permis de construire des promoteurs.
const PERMIS_NOMS := ["Libre", "Sur demande", "Gelé"]
## Encadrement des loyers : plafond du coefficient (valeur du terrain × indice), 0 = aucun.
const ENCADREMENTS := [0.0, 1.6, 1.3, 1.1]
const ENCADREMENT_NOMS := ["Aucun", "Souple", "Moyen", "Strict"]
## Part de logements sociaux imposée aux programmes neufs des promoteurs.
const QUOTAS := [0.0, 0.2, 0.25, 0.3]
## Taxe d'aménagement payée à la ville (part du prix du programme).
const TAXE_AMENAGEMENT := 0.05
## Loyer d'un logement social (part du loyer de base, sans la valeur du quartier).
const LOYER_SOCIAL := 0.55
## Loyer d'un logement de standing (multiplicateur).
const STANDING := 1.3
## Indice des prix : bornes, vitesse de suivi par jour.
const INDICE_MIN := 0.7
const INDICE_MAX := 1.8
const SUIVI_INDICE := 0.03
## Vacance « normale » d'un marché détendu.
const VACANCE_NORMALE := 0.05
## Secteurs pour la gentrification (m).
const SECTEUR := 200
## Bidonvilles : baraques au plus par bidonville, coûts des actions (€).
const BARAQUES_MAX := 14
const VIAB_BARAQUE := 25_000
const AIDE_RELOGEMENT := 3_000
## Jours sans habitant avant qu'une baraque soit démontée.
const JOURS_BARAQUE_VIDE := 20
## Jours de plus que Nuisances.JOURS_AVANT_DEMENAGER avant d'être à la rue.
const JOURS_A_LA_RUE := 10
const NOMS_BIDONVILLES := ["La Zone", "Les Baraques", "La Folie", "Le Chemin des Tôles", "Les Planches",
	"Le Terrain vague", "La Butte aux Chiffons", "Les Tôles bleues"]

const PROMOTEURS := [
	{"id": "beton", "nom": "Béton & Fils", "genre": "densifier", "devise": "On coule, vous signez."},
	{"id": "prestige", "nom": "Immo Prestige", "genre": "standing", "devise": "Le luxe, c'est l'adresse."},
	{"id": "batisseurs", "nom": "Les Bâtisseurs Réunis", "genre": "familial", "devise": "Une maison pour chacun (ou presque)."},
	{"id": "rendement", "nom": "Pierre & Rendement", "genre": "renover", "devise": "Nous rénovons, vous déménagez."},
]
const GENRES := {
	"standing": "Résidence de standing",
	"densifier": "Maison rasée pour un immeuble",
	"familial": "Lotissement de maisons",
	"renover": "Rachat et rénovation haut de gamme",
}

## Réglages du maire (sauvegardés).
var permis := 1
var encadrement := 0
var quota := 0

var buildings: BuildingSystem
var population: Population
var nuisances: Nuisances
var zones: ZoneSystem
var ameliorations: Ameliorations

## vid -> indice des prix (1,0 = normal).
var indices := {}
## vid -> part des logements vides.
var vacances := {}
## vid -> [[jour, indice, loyer moyen, prix moyen du m², vacance]] (un par mois).
var histo := {}
## id du promoteur -> {caisse, projets, logements}
var promoteurs := {}
## Demandes de permis en attente : [{id, prom, genre, vid, zone, bid, cout, log, soc, jour, lieu}]
var demandes: Array = []
var next_demande := 1
## bid -> {soc: logements sociaux, std: standing, prom: promoteur, vide: jours vide}
var fiches := {}
## Vector2i (secteur) -> {"h": [[jour, coef, part modestes, foyers]], "statut": ""}
var secteurs := {}
## bvid -> {id, nom, vid, c: Vector2, baraques: [bid], viab, ne (jour)}
var bidonvilles := {}
var next_bv := 1
## Ce qui s'est passé (panneau) : [{jour, vid, texte}]
var journal: Array = []
## Simulation coupée (tests).
var actif := true

var rng := RandomNumberGenerator.new()
var _jour := -1
var _role_cache := {}
var _vid_cache := {}
var _cache_version := -1
var _dernier_boude := -1000


func _init() -> void:
	instance = self
	rng.randomize()


func _enter_tree() -> void:
	instance = self
	add_to_group("avis_sources")
	add_to_group("budget_ville")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(b: BuildingSystem, p: Population, n: Nuisances, z: ZoneSystem, am: Ameliorations) -> void:
	instance = self
	buildings = b
	population = p
	nuisances = n
	zones = z
	ameliorations = am
	buildings.removed.connect(_on_removed)
	_init_promoteurs()


func clear() -> void:
	indices.clear()
	vacances.clear()
	histo.clear()
	promoteurs.clear()
	demandes.clear()
	fiches.clear()
	secteurs.clear()
	for bv in bidonvilles.values():
		for bid in bv.baraques:
			_retirer_source(int(bid))
	bidonvilles.clear()
	journal.clear()
	permis = 1
	encadrement = 0
	quota = 0
	_jour = -1
	_init_promoteurs()


func _init_promoteurs() -> void:
	for p in PROMOTEURS:
		if not promoteurs.has(p.id):
			promoteurs[p.id] = {"caisse": 30_000_000.0, "projets": 0, "logements": 0}


static func reglages_actifs() -> bool:
	var r := ReglagesPartie.actuel
	return r == null or r.immobilier_vivant


static func bidonvilles_actifs() -> bool:
	var r := ReglagesPartie.actuel
	return r == null or r.bidonvilles


# --- Crochets (neutres sans le module) -------------------------------------------------------

func _maj_caches() -> void:
	if population == null or _cache_version == population.version:
		return
	_cache_version = population.version
	_role_cache.clear()


## Rôle immobilier d'un bâtiment : "social", "standing", "precaire" ou "".
func role_de(bid: int) -> String:
	if _role_cache.has(bid):
		return String(_role_cache[bid])
	var r := ""
	if buildings != null and buildings.buildings.has(bid):
		r = ImmobilierTypes.role(String(buildings.buildings[bid].t))
	_role_cache[bid] = r
	return r


static func precaire(bid: int) -> bool:
	return instance != null and instance.role_de(bid) == "precaire"


static func viabilise(bid: int) -> bool:
	if instance == null:
		return false
	var bv := instance.bidonville_de(bid)
	return bv >= 0 and bool(instance.bidonvilles[bv].get("viab", false))


## Multiplicateur du loyer d'un logement, appliqué après la valeur du terrain (coef).
static func mult_loyer(bid: int, coef: float) -> float:
	if instance == null:
		return 1.0
	return instance._mult(bid, coef)


func _mult(bid: int, coef: float) -> float:
	var role := role_de(bid)
	if role == "precaire":
		return 0.0
	coef = maxf(coef, 0.05)
	var f: Dictionary = fiches.get(bid, {})
	var m := indice_de(bid)
	if role == "standing" or bool(f.get("std", false)):
		m *= STANDING
	var plafond := float(ENCADREMENTS[clampi(encadrement, 0, ENCADREMENTS.size() - 1)])
	if plafond > 0.0 and coef * m > plafond:
		m = plafond / coef
	var part_soc := 0.0
	if role == "social":
		part_soc = 1.0
	elif int(f.get("soc", 0)) > 0 and population != null and population.known.has(bid):
		part_soc = clampf(float(f.soc) / float(maxi(1, int(population.known[bid].log))), 0.0, 1.0)
	return m * (1.0 - part_soc) + LOYER_SOCIAL / coef * part_soc


## Taxe foncière : ni les baraques ni les logements sociaux ne la paient.
static func coef_taxe(bid: int) -> float:
	if instance == null:
		return 1.0
	var r := instance.role_de(bid)
	return 0.0 if r == "precaire" or r == "social" else 1.0


## Village d'un bâtiment (-1 sans village).
func ville_de(bid: int) -> int:
	if Communes.instance == null or Communes.instance.villages.is_empty():
		return -1
	return Communes.instance.village_de(bid)


func indice_de(bid: int) -> float:
	return float(indices.get(ville_de(bid), indices.get(-1, 1.0)))


func indice_ville(vid: int) -> float:
	return float(indices.get(vid, 1.0))


## Prix de vente estimé d'un bâtiment (€) : terrain + construction usée, × indice.
func prix_vente(bid: int) -> int:
	if buildings == null or not buildings.buildings.has(bid):
		return 0
	var b: Dictionary = buildings.buildings[bid]
	var r := buildings._rect_of(b)
	var coef := nuisances.coef_foncier(bid) if nuisances != null else 1.0
	var terrain := float(r.size.x * r.size.y) * Nuisances.PRIX_M2 * 0.35 * coef
	var bati := float(BuildingCatalog.cost(String(b.t))) * Ameliorations.facteur(b)
	var usure := ameliorations.usure(bid) if ameliorations != null else 0.0
	bati *= 1.0 - 0.5 * usure
	if bool(fiches.get(bid, {}).get("std", false)) or role_de(bid) == "standing":
		bati *= 1.25
	return roundi((terrain + bati) * indice_de(bid))


# --- Chaque jour ------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if population == null or population.ambiance == null or buildings == null:
		return
	var j := floori(population.ambiance.unix_time / 86400.0)
	if _jour < 0:
		_jour = j
		return
	if j > _jour:
		var n := mini(j - _jour, 10)
		_jour = j
		for i in n:
			jour_suivant()


func jour() -> int:
	return _jour if _jour >= 0 else (floori(population.ambiance.unix_time / 86400.0) if population != null and population.ambiance != null else 0)


func jour_suivant() -> void:
	if not actif or buildings == null or buildings.verrou_reseau:
		return
	_maj_caches()
	if _jour < 0:
		_jour = jour()
	maj_marche()
	if bidonvilles_actifs():
		_a_la_rue()
		if _jour % 5 == 0:
			_pression_logement()
	_baraques_vides()
	if reglages_actifs():
		if _jour % 7 == 0:
			promoteurs_semaine()
		_expirer_demandes()
	if _jour % 30 == 0:
		releve_mensuel()
		_conseils_municipaux()
	changed.emit()


# --- Marché -----------------------------------------------------------------------------------

## Comptes par ville : {vid: {log, libres, emplois_libres, chomeurs}}.
func comptes() -> Dictionary:
	var out := {}
	if population == null:
		return out
	for bid in population.known:
		var info: Dictionary = population.known[bid]
		var v := ville_de(bid)
		if not out.has(v):
			out[v] = {"log": 0, "libres": 0, "emplois_libres": 0, "chomeurs": 0, "foyers": 0}
		var c: Dictionary = out[v]
		if int(info.log) > 0 and not bool(info.get("camp", false)) and role_de(bid) != "precaire":
			c.log += int(info.log)
			c.libres += population.free_homes(bid)
		if int(info.emp) > 0:
			c.emplois_libres += population.free_jobs(bid)
	for hid in population.households:
		var h: Dictionary = population.households[hid]
		var v := ville_de(int(h.b))
		if not out.has(v):
			out[v] = {"log": 0, "libres": 0, "emplois_libres": 0, "chomeurs": 0, "foyers": 0}
		out[v].foyers += 1
		for pid in h.m:
			if population.persons.has(pid) and population.stage(population.persons[pid]) == "chomeur":
				out[v].chomeurs += 1
	return out


func maj_marche() -> void:
	var c := comptes()
	for v in c:
		var d: Dictionary = c[v]
		if int(d.log) <= 0:
			continue
		var vac := float(d.libres) / float(d.log)
		vacances[v] = vac
		# Peu de logements vides et du travail pour les nouveaux venus : les prix montent.
		var attrait := clampf(float(int(d.emplois_libres) - int(d.chomeurs)) / maxf(20.0, float(d.log)), -0.5, 0.5)
		var cible := clampf(1.0 + 3.0 * (VACANCE_NORMALE - vac) + 0.4 * attrait, INDICE_MIN, INDICE_MAX)
		var i := float(indices.get(v, 1.0))
		i += (cible - i) * SUIVI_INDICE + rng.randf_range(-0.002, 0.002)
		# Krach : rare, et seulement quand les prix sont très hauts.
		if i > 1.35 and rng.randf() < 0.002 * (i - 1.3) * 10.0:
			i *= 0.78
			_noter(v, "Krach immobilier : les prix chutent de 22 %. Les promoteurs gèlent leurs projets.", true)
		indices[v] = clampf(i, INDICE_MIN, INDICE_MAX)


## Relevé du mois : historique des prix et secteurs (gentrification).
func releve_mensuel() -> void:
	if population == null:
		return
	var par_ville := {}
	for hid in population.households:
		var h: Dictionary = population.households[hid]
		var b := int(h.b)
		if role_de(b) == "precaire":
			continue
		var v := ville_de(b)
		if not par_ville.has(v):
			par_ville[v] = [0, 0.0, 0.0]
		par_ville[v][0] += 1
		par_ville[v][1] += nuisances.loyer(b) if nuisances != null else 0.0
		par_ville[v][2] += (nuisances.coef_foncier(b) if nuisances != null else 1.0) * indice_de(b)
	for v in par_ville:
		var n := int(par_ville[v][0])
		if n <= 0:
			continue
		if not histo.has(v):
			histo[v] = []
		(histo[v] as Array).append([_jour, float(indices.get(v, 1.0)), float(par_ville[v][1]) / n,
			Nuisances.PRIX_M2 * float(par_ville[v][2]) / n, float(vacances.get(v, 0.0))])
		while (histo[v] as Array).size() > 120:
			(histo[v] as Array).pop_front()
	_releve_secteurs()
	_payer_promoteurs()


# --- Secteurs et gentrification -----------------------------------------------------------------

static func secteur_de(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / SECTEUR), floori(p.z / SECTEUR))


func _releve_secteurs() -> void:
	var acc := {}
	for hid in population.households:
		var h: Dictionary = population.households[hid]
		var b := int(h.b)
		if not population.known.has(b):
			continue
		var k := secteur_de(population.known[b].pos)
		if not acc.has(k):
			acc[k] = [0, 0.0, 0]
		acc[k][0] += 1
		acc[k][1] += (nuisances.coef_foncier(b) if nuisances != null else 1.0) * indice_de(b) * (STANDING if bool(fiches.get(b, {}).get("std", false)) else 1.0)
		if NiveauxVie.niveau(h) >= 0 and NiveauxVie.niveau(h) <= 1:
			acc[k][2] += 1
	for k in acc:
		var n := int(acc[k][0])
		if not secteurs.has(k):
			secteurs[k] = {"h": [], "statut": ""}
		var s: Dictionary = secteurs[k]
		(s.h as Array).append([_jour, float(acc[k][1]) / n, float(acc[k][2]) / n, n])
		while (s.h as Array).size() > 13:
			(s.h as Array).pop_front()
		var avant := String(s.statut)
		s.statut = statut_calcule(s.h)
		if s.statut != avant and s.statut != "" and n >= 4:
			var nom := nom_secteur(k)
			if s.statut == "embourgeoisement":
				_noter(_ville_secteur(k), "%s s'embourgeoise : les prix montent, les foyers modestes partent." % nom, true)
			elif s.statut == "pauperisation":
				_noter(_ville_secteur(k), "%s se paupérise : les prix baissent, les immeubles se dégradent." % nom, true)
	for k in secteurs.keys():
		if not acc.has(k):
			secteurs.erase(k)


## Statut d'un secteur d'après son histoire : "embourgeoisement", "pauperisation" ou "".
static func statut_calcule(h: Array) -> String:
	if h.size() < 2:
		return ""
	var old: Array = h[maxi(0, h.size() - 7)]
	var now: Array = h[h.size() - 1]
	var dcoef := float(now[1]) / maxf(0.05, float(old[1])) - 1.0
	var dmod := float(now[2]) - float(old[2])
	if dcoef > 0.12 and dmod <= 0.0:
		return "embourgeoisement"
	if dcoef < -0.12:
		return "pauperisation"
	return ""


func statut_au_point(p: Vector3) -> String:
	return String(secteurs.get(secteur_de(p), {}).get("statut", ""))


## Évolution des prix d'un secteur depuis le plus ancien relevé gardé (0,1 = +10 %).
func evolution_secteur(k: Vector2i) -> float:
	var h: Array = secteurs.get(k, {}).get("h", [])
	if h.size() < 2:
		return 0.0
	var old: Array = h[maxi(0, h.size() - 7)]
	return float(h[h.size() - 1][1]) / maxf(0.05, float(old[1])) - 1.0


func _ville_secteur(k: Vector2i) -> int:
	if Communes.instance == null:
		return -1
	var c := Vector2((k.x + 0.5) * SECTEUR, (k.y + 0.5) * SECTEUR)
	return Communes.instance.village_au_point(c.x, c.y)


## Nom lisible d'un secteur : quartier peint (Maj+Y), sinon sa direction depuis le centre.
func nom_secteur(k: Vector2i) -> String:
	var c := Vector2((k.x + 0.5) * SECTEUR, (k.y + 0.5) * SECTEUR)
	if Quartiers.instance != null:
		var q := Quartiers.instance.quartier_au_point(c.x, c.y)
		if q >= 0 and Quartiers.instance.quartiers.has(q):
			return "Le quartier %s" % String(Quartiers.instance.quartiers[q].nom)
	var vid := _ville_secteur(k)
	var centre := Vector2.ZERO
	var nom := Avis.ville()
	if Communes.instance != null and Communes.instance.villages.has(vid):
		centre = Communes.instance.villages[vid].c
		nom = String(Communes.instance.villages[vid].nom)
	var d := c - centre
	if d.length() < SECTEUR * 1.2:
		return "Le centre de %s" % nom
	var dirs := ["l'est", "le sud-est", "le sud", "le sud-ouest", "l'ouest", "le nord-ouest", "le nord", "le nord-est"]
	var i := posmod(roundi(d.angle() / (TAU / 8.0)), 8)
	return "Le secteur dans %s de %s" % [dirs[i], nom]


# --- Promoteurs -------------------------------------------------------------------------------

## La semaine des promoteurs : chacun son tour cherche une affaire.
func promoteurs_semaine() -> int:
	if zones == null or population == null:
		return 0
	if permis == 2:
		return 0
	var faits := 0
	var ordre := PROMOTEURS.duplicate()
	ordre.shuffle()
	for p in ordre.slice(0, 2):
		var proj := chercher_projet(String(p.id))
		if proj.is_empty():
			continue
		# Encadrement strict, quota élevé : le projet n'est plus rentable.
		var frein: float = float([0.0, 0.15, 0.35, 0.6][clampi(encadrement, 0, 3)]) + float(QUOTAS[clampi(quota, 0, 3)])
		if String(proj.genre) != "renover" and rng.randf() < frein:
			if _jour - _dernier_boude > 30:
				_dernier_boude = _jour
				_noter(int(proj.vid), "%s renonce à un projet : « avec ces règles, ce n'est plus rentable »." % nom_promoteur(String(p.id)))
			continue
		if permis == 0 or not decide(int(proj.vid)):
			# Permis libre, ou ville gérée par le conseil élu : accordé d'office (le plus souvent).
			if permis == 0 or rng.randf() < 0.75:
				if realiser(proj):
					faits += 1
		else:
			proposer(proj)
	return faits


func nom_promoteur(id: String) -> String:
	for p in PROMOTEURS:
		if p.id == id:
			return String(p.nom)
	return id


func genre_promoteur(id: String) -> String:
	for p in PROMOTEURS:
		if p.id == id:
			return String(p.genre)
	return ""


## Cherche une affaire pour ce promoteur : {} si rien.
func chercher_projet(prom: String) -> Dictionary:
	var genre := genre_promoteur(prom)
	var d := zones.demand()
	var caisse := float(promoteurs.get(prom, {}).get("caisse", 0.0))
	match genre:
		"standing", "familial":
			if float(d.get("R", 0.0)) <= 0.0:
				return {}
			var types := _types_genre(genre)
			if types.is_empty():
				return {}
			var best := -1
			var best_v := -INF
			for zid in zones.zones:
				var z: Dictionary = zones.zones[zid]
				if String(z.k) != "R":
					continue
				var r := ZoneSystem.zone_rect(z)
				var c := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
				var v := nuisances.valeur(c) if nuisances != null else 1.0
				var ok := v >= 1.2 if genre == "standing" else (v >= 0.8 and v < 1.25)
				if ok and v + rng.randf() * 0.1 > best_v:
					best_v = v
					best = int(zid)
			if best < 0:
				return {}
			var t0 := String(types.keys()[0])
			var cout := float(BuildingCatalog.cost(t0))
			if caisse < cout:
				return {}
			var r := ZoneSystem.zone_rect(zones.zones[best])
			var pos := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
			var lg := int(BuildingCatalog.get_type(t0).get("logements", 1))
			return {"prom": prom, "genre": genre, "zone": best, "types": types, "bid": -1, "cout": cout,
				"log": lg, "soc": _soc(lg), "vid": _ville_pos(pos), "lieu": nom_secteur(secteur_de(pos))}
		"densifier":
			if float(d.get("R", 0.0)) <= 0.0:
				return {}
			var types := _types_genre("densifier")
			if types.is_empty():
				return {}
			var cand := _candidat(func(bid: int, b: Dictionary, info: Dictionary) -> float:
				if int(b.get("zone", 0)) <= 0 or not zones.zones.has(int(b.zone)) or String(zones.zones[int(b.zone)].k) != "R":
					return -1.0
				if not bool(info.get("house", false)) or int(info.log) > 2 or role_de(bid) != "":
					return -1.0
				var c := nuisances.coef_foncier(bid)
				return c if c >= 1.3 else -1.0)
			if cand < 0:
				return {}
			var t0 := String(types.keys()[0])
			var cout := float(BuildingCatalog.cost(t0))
			if caisse < cout:
				return {}
			var lg := int(BuildingCatalog.get_type(t0).get("logements", 10))
			var pos: Vector3 = population.known[cand].pos
			return {"prom": prom, "genre": genre, "zone": int(buildings.buildings[cand].zone), "types": types, "bid": cand,
				"cout": cout, "log": lg, "soc": _soc(lg), "vid": ville_de(cand), "lieu": nom_secteur(secteur_de(pos))}
		"renover":
			var cand := _candidat(func(bid: int, b: Dictionary, info: Dictionary) -> float:
				if int(info.log) < 2 or role_de(bid) != "" or bool(fiches.get(bid, {}).get("std", false)):
					return -1.0
				if buildings.en_chantier(bid) or b.has("amel") or bool(info.get("camp", false)):
					return -1.0
				var c := nuisances.coef_foncier(bid)
				var t := nuisances.tendance(bid)
				if c >= 1.4 or (c >= 1.15 and t > 0.01) or statut_au_point(info.pos) == "embourgeoisement":
					return c + t * 5.0
				return -1.0)
			if cand < 0:
				return {}
			var cout := float(ameliorations.cout(cand, 0)) * 2.0 + float(prix_vente(cand)) * 0.2 if ameliorations != null else float(prix_vente(cand)) * 0.3
			if caisse < cout:
				return {}
			var pos: Vector3 = population.known[cand].pos
			return {"prom": prom, "genre": genre, "zone": 0, "types": {}, "bid": cand, "cout": cout,
				"log": int(population.known[cand].log), "soc": 0, "vid": ville_de(cand), "lieu": nom_secteur(secteur_de(pos))}
	return {}


## Meilleur bâtiment selon score(bid, b, info) (> 0 retenu), sur un échantillon.
func _candidat(score: Callable) -> int:
	var ids := population.known.keys()
	if ids.is_empty():
		return -1
	var best := -1
	var best_s := 0.0
	var n := mini(ids.size(), 400)
	var start := rng.randi() % ids.size()
	for i in n:
		var bid := int(ids[(start + i) % ids.size()])
		if not buildings.buildings.has(bid):
			continue
		var s := float(score.call(bid, buildings.buildings[bid], population.known[bid]))
		if s > best_s:
			best_s = s
			best = bid
	return best


## Logements sociaux imposés à un programme de lg logements.
func _soc(lg: int) -> int:
	return floori(lg * float(QUOTAS[clampi(quota, 0, QUOTAS.size() - 1)]))


## Types que bâtit un genre de promoteur, déjà inventés à l'époque.
func _types_genre(genre: String) -> Dictionary:
	var base := ZoneSystem.types_for("R", "")
	var out := {}
	match genre:
		"standing":
			if Epoques.batiment_disponible("residence_standing"):
				return {"residence_standing": 1}
			# Avant 1960 : les immeubles les plus chers par logement (immeubles bourgeois).
			var best := ""
			var best_c := 0.0
			for id in base:
				var lg := int(BuildingCatalog.get_type(id).get("logements", 0))
				if lg >= 4:
					var c := float(BuildingCatalog.cost(id)) / lg
					if c > best_c:
						best_c = c
						best = id
			if best != "":
				out[best] = 1
		"familial":
			for id in base:
				if int(BuildingCatalog.get_type(id).get("logements", 0)) in [1, 2]:
					out[id] = int(base[id])
		"densifier":
			for id in base:
				if int(BuildingCatalog.get_type(id).get("logements", 0)) >= 10:
					out[id] = int(base[id])
	return out


func _ville_pos(p: Vector3) -> int:
	if Communes.instance == null or Communes.instance.villages.is_empty():
		return -1
	return Communes.instance.village_au_point(p.x, p.z)


## Le joueur décide-t-il dans cette ville (il en est le maire) ?
static func decide(vid: int) -> bool:
	if vid <= 0 or Pays.instance == null:
		return true
	return Pays.instance.joueur_maire(vid)


func proposer(proj: Dictionary) -> void:
	for dm in demandes:
		if String(dm.prom) == String(proj.prom):
			return
	var dm := proj.duplicate()
	dm["id"] = next_demande
	next_demande += 1
	dm["jour"] = _jour
	demandes.append(dm)
	message.emit("Permis de construire : %s demande à bâtir (%s, %s). Réponds dans le panneau Immobilier (F11)." % [
		nom_promoteur(String(proj.prom)), String(GENRES.get(String(proj.genre), "")).to_lower(), String(proj.lieu)])
	changed.emit()


func accepter(id: int) -> bool:
	for i in demandes.size():
		if int(demandes[i].id) == id:
			var dm: Dictionary = demandes[i]
			demandes.remove_at(i)
			var ok := realiser(dm)
			if not ok:
				message.emit("%s n'a pas trouvé de terrain libre : projet abandonné." % nom_promoteur(String(dm.prom)))
			changed.emit()
			return ok
	return false


func refuser(id: int) -> void:
	for i in demandes.size():
		if int(demandes[i].id) == id:
			var dm: Dictionary = demandes[i]
			demandes.remove_at(i)
			_noter(int(dm.vid), "Permis refusé à %s (%s)." % [nom_promoteur(String(dm.prom)), String(dm.lieu)])
			changed.emit()
			return


func _expirer_demandes() -> void:
	for dm in demandes.duplicate():
		if _jour - int(dm.jour) > 30:
			demandes.erase(dm)
			_noter(int(dm.vid), "%s retire sa demande de permis, faute de réponse." % nom_promoteur(String(dm.prom)))


## Réalise un projet. Vrai si quelque chose a été bâti ou lancé.
func realiser(proj: Dictionary) -> bool:
	var prom := String(proj.prom)
	var genre := String(proj.genre)
	var bid := -1
	match genre:
		"standing", "familial":
			var zid := int(proj.zone)
			if not zones.zones.has(zid):
				return false
			bid = zones._grow_in(zones.zones[zid], INF, 0, proj.types)
		"densifier":
			var old := int(proj.bid)
			if not buildings.buildings.has(old) or not zones.zones.has(int(proj.zone)):
				return false
			var b: Dictionary = (buildings.buildings[old] as Dictionary).duplicate(true)
			var foyers: Array = (population.by_home.get(old, []) as Array).duplicate()
			buildings.remove_quietly(old)
			bid = zones._grow_in(zones.zones[int(proj.zone)], INF, 0, proj.types)
			if bid < 0:
				buildings.restore(b)
				return false
			var partis := 0
			for hid in foyers:
				if not _reloger_foyer(int(hid), old, "Doit partir : %s rase sa maison pour un immeuble" % nom_promoteur(prom)):
					partis += 1
			_noter(int(proj.vid), "%s rase une maison (%s) pour bâtir un immeuble de %d logements%s." % [
				nom_promoteur(prom), String(proj.lieu), int(proj.log), (" ; %d foyer(s) n'ont rien trouvé" % partis) if partis > 0 else ""], true)
		"renover":
			bid = int(proj.bid)
			if not buildings.buildings.has(bid):
				return false
			var f: Dictionary = fiches.get(bid, {})
			f["std"] = true
			f["prom"] = prom
			fiches[bid] = f
			if ameliorations != null and ameliorations.en_cours(bid).is_empty() and not buildings.en_chantier(bid):
				ameliorations._lancer(bid, "renov", 0, ameliorations.cout(bid, 0), true)
			_noter(int(proj.vid), "%s rachète %s (%s) et le rénove en haut de gamme : les loyers vont grimper de 30 %%." % [
				nom_promoteur(prom), population.building_name(bid), String(proj.lieu)], true)
	if bid < 0:
		return false
	if genre != "renover":
		var f: Dictionary = fiches.get(bid, {})
		f["prom"] = prom
		if int(proj.get("soc", 0)) > 0:
			f["soc"] = int(proj.soc)
		fiches[bid] = f
		if genre != "densifier":
			_noter(int(proj.vid), "%s lance %s (%s) : %d logements%s." % [nom_promoteur(prom), String(GENRES.get(genre, "")).to_lower(),
				String(proj.lieu), int(proj.log), (" dont %d sociaux" % int(proj.soc)) if int(proj.get("soc", 0)) > 0 else ""])
	var pr: Dictionary = promoteurs[prom]
	pr.caisse = float(pr.caisse) - float(proj.cout)
	pr.projets = int(pr.projets) + 1
	pr.logements = int(pr.logements) + int(proj.log)
	# Taxe d'aménagement pour la ville.
	_payer(int(proj.vid), -roundi(float(proj.cout) * TAXE_AMENAGEMENT), "Taxe d'aménagement")
	_role_cache.erase(bid)
	changed.emit()
	return true


## Loyers encaissés par les promoteurs (chaque mois) : leur caisse remonte.
func _payer_promoteurs() -> void:
	var gains := {}
	for bid in fiches:
		var prom := String(fiches[bid].get("prom", ""))
		if prom == "" or not promoteurs.has(prom) or not population.by_home.has(bid):
			continue
		var n := (population.by_home[bid] as Array).size()
		gains[prom] = float(gains.get(prom, 0.0)) + n * (nuisances.loyer(bid) if nuisances != null else 700.0) * 0.6
	for prom in promoteurs:
		# Et les ventes ailleurs : une rentrée minimale.
		promoteurs[prom].caisse = float(promoteurs[prom].caisse) + float(gains.get(prom, 0.0)) + 400_000.0


# --- Relogements, expulsions et bidonvilles -----------------------------------------------------

## Cherche un logement abordable à un foyer (social d'abord). Sinon une baraque,
## sinon il quitte la ville. Vrai s'il reste en ville dans un vrai logement.
func _reloger_foyer(hid: int, sauf := -1, raison := "") -> bool:
	if not population.households.has(hid):
		return false
	var target := logement_abordable(hid, sauf)
	if target >= 0:
		population.move_household(hid, target)
		return true
	if bidonvilles_actifs():
		var bq := _place_en_baraque(ville_de(int(population.households[hid].b)))
		if bq >= 0 and population.households.has(hid):
			population.move_household(hid, bq)
			_journal_foyer(hid, "demenage", "S'installe dans une baraque du bidonville, faute de logement abordable", bq)
			return false
	if raison != "":
		_journal_foyer(hid, "demenage", raison, -1)
	population._remove_household(hid, "Quitte la ville : plus de logement abordable")
	return false


func _journal_foyer(hid: int, code: String, texte: String, ref: int) -> void:
	if population.vie == null or not population.households.has(hid):
		return
	for pid in population.households[hid].m:
		if population.persons.has(pid):
			population.vie.log_event(population.persons[pid], code, texte, ref)


func _revenus(hid: int) -> float:
	var inc := 0.0
	for pid in population.households[hid].m:
		if population.persons.has(pid):
			inc += population.income_of(population.persons[pid])
	return inc


## Logement libre au loyer ≤ 35 % des revenus du foyer (social d'abord), ou -1.
func logement_abordable(hid: int, sauf := -1) -> int:
	var inc := _revenus(hid)
	var best := -1
	var best_s := INF
	for bid in population.known:
		if bid == sauf or population.free_homes(bid) <= 0 or role_de(bid) == "precaire":
			continue
		if bool(population.known[bid].get("camp", false)) or not buildings.buildings.has(bid):
			continue
		var l := nuisances.loyer(bid) if nuisances != null else 700.0
		if l > 0.35 * inc:
			continue
		var s := l - (10_000.0 if role_de(bid) == "social" else 0.0)
		if s < best_s:
			best_s = s
			best = bid
	return best


## Foyers qui ne trouvent rien depuis longtemps (loyer trop cher) : à la rue.
func _a_la_rue() -> void:
	if nuisances == null:
		return
	var n := 0
	for hid in nuisances._cher.keys():
		if n >= 3:
			break
		if int(nuisances._cher[hid]) < Nuisances.JOURS_AVANT_DEMENAGER + JOURS_A_LA_RUE:
			continue
		if not population.households.has(hid) or role_de(int(population.households[hid].b)) == "precaire":
			continue
		nuisances._cher[hid] = 0
		n += 1
		var v := ville_de(int(population.households[hid].b))
		if not _reloger_foyer(hid, int(population.households[hid].b), "Expulsé pour loyers impayés"):
			_noter(v, "Une famille expulsée pour loyers impayés n'a trouvé qu'une baraque, ou a quitté la ville.")


## Des emplois attirent des travailleurs, mais aucun logement libre : ils bâtissent des baraques.
func _pression_logement() -> void:
	var c := comptes()
	for v in c:
		var d: Dictionary = c[v]
		if int(d.log) < 30:
			continue
		var manque := int(d.emplois_libres) - int(d.chomeurs)
		if manque < 20 or float(d.libres) / float(d.log) > 0.015:
			continue
		var bq := _place_en_baraque(int(v))
		if bq < 0:
			continue
		for i in 2:
			if population.free_homes(bq) <= 0:
				break
			var hid := population.spawn_household(bq, "seul" if rng.randf() < 0.5 else "famille")
			if hid >= 0:
				population.households[hid].ep = float(rng.randi_range(0, 3) * 100)
				_journal_foyer(hid, "demenage", "Arrive pour travailler ; faute de logement, bâtit une baraque en bord de ville", bq)


## Une baraque avec une place libre dans un bidonville de la ville (créée au besoin).
func _place_en_baraque(vid: int) -> int:
	var bv := -1
	for id in bidonvilles:
		var b: Dictionary = bidonvilles[id]
		if int(b.vid) != vid:
			continue
		for bq in b.baraques:
			if buildings.buildings.has(int(bq)) and population.known.has(int(bq)) and population.free_homes(int(bq)) > 0:
				return int(bq)
		if (b.baraques as Array).size() < BARAQUES_MAX:
			bv = int(id)
	if bv < 0:
		bv = _nouveau_bidonville(vid)
		if bv < 0:
			return -1
	return _ajouter_baraque(bv)


func _centre_ville(vid: int) -> Vector2:
	if Communes.instance != null and Communes.instance.villages.has(vid):
		return Communes.instance.villages[vid].c
	var s := Vector2.ZERO
	var n := 0
	for bid in population.known:
		var p: Vector3 = population.known[bid].pos
		s += Vector2(p.x, p.z)
		n += 1
	return s / n if n > 0 else Vector2.ZERO


func _nouveau_bidonville(vid: int) -> int:
	var c := _centre_ville(vid)
	var a0 := rng.randf() * TAU
	for dist in [180.0, 260.0, 340.0, 440.0, 560.0]:
		for i in 16:
			var a := a0 + float(i) / 16.0 * TAU
			var p := Vector2i(roundi(c.x + cos(a) * dist), roundi(c.y + sin(a) * dist))
			if not buildings.check_place("baraques", p, 0).ok:
				continue
			var id := next_bv
			next_bv += 1
			var noms := NOMS_BIDONVILLES.filter(func(n: String) -> bool:
				for b in bidonvilles.values():
					if String(b.nom) == n:
						return false
				return true)
			var nom := String(noms[rng.randi() % noms.size()]) if not noms.is_empty() else "Bidonville n° %d" % id
			bidonvilles[id] = {"id": id, "nom": nom, "vid": vid, "c": Vector2(p), "baraques": [], "viab": false, "ne": _jour}
			_noter(vid, "Un bidonville apparaît en bordure de ville : « %s ». Des familles sans logement abordable s'y installent." % nom, true)
			return id
	return -1


## Pose une baraque de plus dans ce bidonville. Renvoie son id, ou -1.
func _ajouter_baraque(bv: int) -> int:
	var b: Dictionary = bidonvilles[bv]
	var c: Vector2 = b.c
	var n := (b.baraques as Array).size()
	var places := [Vector2.ZERO] if n == 0 else []
	for ring in [16.0, 32.0, 48.0]:
		for i in 8:
			var a := float(i) / 8.0 * TAU + float(ring) * 0.05
			places.append(Vector2(cos(a), sin(a)) * float(ring))
	for off in places:
		var p := Vector2i(roundi(c.x + off.x), roundi(c.y + off.y))
		if not buildings.check_place("baraques", p, rng.randi() % 4).ok:
			continue
		var unl := buildings.unlimited_money
		buildings.unlimited_money = true
		var bid := buildings.place("baraques", p, rng.randi() % 4, -1)
		buildings.unlimited_money = unl
		if bid < 0:
			continue
		buildings.buildings[bid]["v"] = rng.randi() % 4
		(b.baraques as Array).append(bid)
		_role_cache.erase(bid)
		_source(bid)
		# Seulement ce bâtiment (une synchro complète ferait partir les foyers d'un bâtiment rasé).
		population.known[bid] = population._info_of(buildings.buildings[bid])
		return bid
	return -1


## Pas d'eau ni d'égouts : odeurs et eau polluée autour des baraques (Nuisances).
func _source(bid: int) -> void:
	if nuisances == null or not buildings.buildings.has(bid) or viabilise(bid):
		return
	var p := BuildingSystem.rect_center(buildings._rect_of(buildings.buildings[bid]))
	nuisances.ajouter_source("bidonville:%d" % bid, "odeur", p, 0.55, 120.0)
	nuisances.ajouter_source("bidonville:%d" % bid, "eau", p, 0.5, 120.0)
	nuisances.ajouter_source("bidonville:%d" % bid, "salete", p, 0.6, 90.0)


func _retirer_source(bid: int) -> void:
	if nuisances != null:
		nuisances.retirer_source("bidonville:%d" % bid)


func bidonville_de(bid: int) -> int:
	for id in bidonvilles:
		if (bidonvilles[id].baraques as Array).has(bid):
			return int(id)
	return -1


func habitants_bidonville(bv: int) -> Array:
	var out := []
	for bq in bidonvilles[bv].baraques:
		for hid in population.by_home.get(int(bq), []):
			out.append(int(hid))
	return out


## Baraques vides depuis longtemps : démontées. Bidonville sans baraque : disparu.
func _baraques_vides() -> void:
	for id in bidonvilles.keys():
		var b: Dictionary = bidonvilles[id]
		for bq in (b.baraques as Array).duplicate():
			bq = int(bq)
			if not buildings.buildings.has(bq):
				(b.baraques as Array).erase(bq)
				continue
			var f: Dictionary = fiches.get(bq, {})
			if (population.by_home.get(bq, []) as Array).is_empty():
				f["vide"] = int(f.get("vide", 0)) + 1
			else:
				f["vide"] = 0
			fiches[bq] = f
			if int(f.vide) >= JOURS_BARAQUE_VIDE:
				_demonter(bq)
				(b.baraques as Array).erase(bq)
		if (b.baraques as Array).is_empty() and _jour - int(b.ne) > 2:
			_noter(int(b.vid), "Le bidonville « %s » a disparu : ses habitants ont trouvé mieux." % String(b.nom), true)
			bidonvilles.erase(id)


func _demonter(bq: int) -> void:
	_retirer_source(bq)
	fiches.erase(bq)
	buildings.remove_quietly(bq)


func _on_removed(bid: int) -> void:
	_role_cache.erase(bid)
	var bv := bidonville_de(bid)
	if bv >= 0:
		(bidonvilles[bv].baraques as Array).erase(bid)
		_retirer_source(bid)
	fiches.erase(bid)


func cout_viabiliser(bv: int) -> int:
	return ReglagesPartie.prix(VIAB_BARAQUE * (bidonvilles[bv].baraques as Array).size()) if bidonvilles.has(bv) else 0


func raison_viabiliser(bv: int) -> String:
	if not bidonvilles.has(bv):
		return "Bidonville introuvable."
	if bool(bidonvilles[bv].viab):
		return "Déjà viabilisé."
	if not decide(int(bidonvilles[bv].vid)):
		return "Ce n'est plus toi qui décides dans cette ville."
	if not buildings.unlimited_money and solde_ville(int(bidonvilles[bv].vid)) < cout_viabiliser(bv):
		return "Pas assez d'argent dans la caisse (%s)." % BuildingSystem.format_money(cout_viabiliser(bv))
	return ""


## Eau, électricité et latrines : plus d'odeurs ni d'eau polluée, niveau Modeste possible.
func viabiliser(bv: int, conseil := false) -> String:
	var why := raison_viabiliser(bv) if not conseil else ("" if bidonvilles.has(bv) and not bool(bidonvilles[bv].viab) else "Déjà viabilisé.")
	if why != "":
		return why
	var b: Dictionary = bidonvilles[bv]
	_payer(int(b.vid), cout_viabiliser(bv), "Bidonvilles")
	b.viab = true
	for bq in b.baraques:
		_retirer_source(int(bq))
	_noter(int(b.vid), "« %s » viabilisé : eau courante, électricité et latrines pour %d baraques." % [String(b.nom), (b.baraques as Array).size()], true)
	changed.emit()
	return ""


## Reloge les familles du bidonville dans des logements abordables. Renvoie le nombre relogé.
func reloger(bv: int, conseil := false) -> int:
	if not bidonvilles.has(bv) or not (conseil or decide(int(bidonvilles[bv].vid))):
		return 0
	var b: Dictionary = bidonvilles[bv]
	var n := 0
	var reste := 0
	for hid in habitants_bidonville(bv):
		var target := logement_abordable(hid)
		if target < 0:
			reste += 1
			continue
		population.move_household(hid, target)
		_journal_foyer(hid, "demenage", "Relogé par la mairie : quitte le bidonville pour %s" % population.building_name(target), target)
		_payer(int(b.vid), ReglagesPartie.prix(AIDE_RELOGEMENT), "Bidonvilles")
		n += 1
	for bq in (b.baraques as Array).duplicate():
		if (population.by_home.get(int(bq), []) as Array).is_empty():
			_demonter(int(bq))
			(b.baraques as Array).erase(bq)
	if n > 0:
		_noter(int(b.vid), "%d famille%s du bidonville « %s » relogée%s par la mairie%s." % [n, "s" if n > 1 else "", String(b.nom), "s" if n > 1 else "",
			(" ; %d attendent encore un logement abordable" % reste) if reste > 0 else ""], true)
	elif reste > 0 and not conseil:
		message.emit("Aucun logement abordable libre pour reloger les familles de « %s » : bâtis des logements sociaux (B → Logement)." % String(b.nom))
	if (b.baraques as Array).is_empty():
		bidonvilles.erase(bv)
	changed.emit()
	return n


## Rase le bidonville : les familles quittent la ville, et la ville s'en souvient.
func raser(bv: int) -> int:
	if not bidonvilles.has(bv) or not decide(int(bidonvilles[bv].vid)):
		return 0
	var b: Dictionary = bidonvilles[bv]
	var n := 0
	for hid in habitants_bidonville(bv):
		population._remove_household(hid, "Quitte la ville : expulsé du bidonville")
		n += 1
	for bq in (b.baraques as Array).duplicate():
		_demonter(int(bq))
	if Avis.instance != null:
		Avis.instance.ajouter_effet("logement", -6.0, 60.0, "expulsion du bidonville « %s »" % String(b.nom), int(b.vid) if int(b.vid) > 0 else -2)
	_noter(int(b.vid), "Le bidonville « %s » est rasé : %d famille%s expulsée%s. Les habitants n'ont pas aimé." % [String(b.nom), n, "s" if n > 1 else "", "s" if n > 1 else ""], true)
	bidonvilles.erase(bv)
	population.version += 1
	population.changed.emit()
	changed.emit()
	return n


## Villes que le joueur ne gère pas (conseil élu, pilote) : on reloge, sinon on viabilise.
func _conseils_municipaux() -> void:
	for bv in bidonvilles.keys():
		if not bidonvilles.has(bv) or decide(int(bidonvilles[bv].vid)):
			continue
		var b: Dictionary = bidonvilles[bv]
		if reloger(bv, true) > 0 or not bidonvilles.has(bv) or bool(b.viab):
			continue
		if buildings.unlimited_money or solde_ville(int(b.vid)) > cout_viabiliser(bv) * 3:
			viabiliser(bv, true)


# --- Caisse de la ville ------------------------------------------------------------------------

func solde_ville(vid: int) -> int:
	if buildings == null:
		return 0
	if vid > 0 and Pays.instance != null and Pays.instance.a_des_villes():
		return Pays.instance.solde(vid)
	return buildings.money


## Paie (montant > 0) ou encaisse (montant < 0) pour la ville.
func _payer(vid: int, montant: int, poste: String) -> void:
	if buildings == null or montant == 0 or (buildings.unlimited_money and montant > 0):
		return
	var multi := vid > 0 and Pays.instance != null and Pays.instance.a_des_villes()
	var prev := Pays.a_la_caisse(vid) if multi else -1
	buildings.money -= montant
	Pays.retour(prev)
	if BudgetCommunal.instance != null:
		if multi:
			BudgetCommunal.instance.noter_pour(vid, poste, -montant)
		else:
			BudgetCommunal.noter(poste, -montant)


## Comptes de la ville k pour le budget (groupe "budget_ville") : loyers et
## entretien des logements sociaux bâtis par la ville.
func budget_ville(k: int) -> Dictionary:
	var rec := {}
	var dep := {}
	if population == null:
		return {"recettes": rec, "depenses": dep}
	var loyers := 0.0
	var log := 0
	for bid in population.known:
		if role_de(bid) != "social":
			continue
		var v := ville_de(bid)
		if k >= 0 and v != k and not (k == 0 and v < 0):
			continue
		log += int(population.known[bid].log)
		for hid in population.by_home.get(bid, []):
			loyers += nuisances.loyer(bid) if nuisances != null else 400.0
	if log > 0:
		rec["Loyers des logements sociaux"] = roundf(loyers)
		dep["Entretien des logements sociaux"] = roundf(loyers * 0.35 + 15.0 * log)
	return {"recettes": rec, "depenses": dep}


# --- Avis des habitants ------------------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "immobilier", "theme": "logement", "f": _f_avis}]


func _f_avis(p: Dictionary) -> Array:
	if population == null:
		return [0.0, []]
	var home := population.home_of(p)
	if home < 0:
		return [0.0, []]
	var r := role_de(home)
	if r == "precaire":
		if viabilise(home):
			return [-5.0, ["− vit dans une baraque (bidonville viabilisé)"]]
		return [-12.0, ["− vit dans un bidonville, sans eau ni égouts"]]
	if r == "social" or int(fiches.get(home, {}).get("soc", 0)) > 0:
		return [3.0, ["+ loyer modéré (logement social)"]]
	if not population.known.has(home):
		return [0.0, []]
	var st := statut_au_point(population.known[home].pos)
	var h: Dictionary = population.households.get(int(p.f), {})
	var nv := NiveauxVie.niveau(h) if not h.is_empty() else -1
	if st == "embourgeoisement" and nv >= 0 and nv <= 1:
		return [-4.0, ["− peur d'être chassé : le quartier devient trop cher"]]
	if st == "pauperisation":
		return [-3.0, ["− le quartier se dégrade"]]
	if st == "embourgeoisement" and nv >= 3:
		return [2.0, ["+ le quartier prend de la valeur"]]
	return [0.0, []]


# --- Journal ----------------------------------------------------------------------------------

func _noter(vid: int, t: String, presse := false) -> void:
	journal.append({"jour": _jour, "vid": vid, "texte": t})
	while journal.size() > 40:
		journal.pop_front()
	message.emit(t)
	if presse and Journal.instance != null:
		Journal.instance.noter({"k": "depeche", "genre": "immobilier", "texte": t, "ev": -1, "pos": []})


# --- Résumés pour le panneau ----------------------------------------------------------------------

## Chiffres d'une ville (vid = -2 : toute la carte).
func bilan(vid := -2) -> Dictionary:
	var out := {"foyers": 0, "loyer": 0.0, "effort": 0.0, "cher": 0, "sociaux": 0, "sociaux_occ": 0, "standing": 0,
		"baraques": 0, "precaires": 0, "prix_m2": 0.0, "indice": 0.0, "vacance": 0.0, "log": 0}
	if population == null:
		return out
	var n_eff := 0
	for hid in population.households:
		var h: Dictionary = population.households[hid]
		var b := int(h.b)
		if vid != -2 and ville_de(b) != vid:
			continue
		if role_de(b) == "precaire":
			out.precaires += 1
			continue
		out.foyers += 1
		var l := nuisances.loyer(b) if nuisances != null else 0.0
		out.loyer += l
		var te := nuisances.taux_effort(hid) if nuisances != null else 0.0
		if te < 5.0:
			out.effort += te
			n_eff += 1
		if te > Nuisances.TAUX_EFFORT_MAX:
			out.cher += 1
		out.prix_m2 += Nuisances.PRIX_M2 * (nuisances.coef_foncier(b) if nuisances != null else 1.0) * indice_de(b)
	for bid in population.known:
		if vid != -2 and ville_de(bid) != vid:
			continue
		var r := role_de(bid)
		var lg := int(population.known[bid].log)
		if r == "social":
			out.sociaux += lg
			out.sociaux_occ += (population.by_home.get(bid, []) as Array).size()
		elif int(fiches.get(bid, {}).get("soc", 0)) > 0:
			out.sociaux += int(fiches[bid].soc)
		if r == "standing" or bool(fiches.get(bid, {}).get("std", false)):
			out.standing += lg
		if r == "precaire":
			out.baraques += 1
		elif lg > 0:
			out.log += lg
	if out.foyers > 0:
		out.loyer = float(out.loyer) / out.foyers
		out.prix_m2 = float(out.prix_m2) / out.foyers
	if n_eff > 0:
		out.effort = float(out.effort) / n_eff
	if vid == -2:
		var s := 0.0
		var vs := 0.0
		for v in indices:
			s += float(indices[v])
			vs += float(vacances.get(v, 0.0))
		out.indice = s / indices.size() if not indices.is_empty() else 1.0
		out.vacance = vs / indices.size() if not indices.is_empty() else 0.0
	else:
		out.indice = float(indices.get(vid, 1.0))
		out.vacance = float(vacances.get(vid, 0.0))
	return out


## Secteurs qui changent : [{k, nom, statut, evol, foyers}], les plus forts d'abord.
func secteurs_qui_changent() -> Array:
	var out := []
	for k in secteurs:
		var s: Dictionary = secteurs[k]
		var h: Array = s.h
		if h.is_empty():
			continue
		out.append({"k": k, "nom": nom_secteur(k), "statut": String(s.statut), "evol": evolution_secteur(k),
			"foyers": int(h[h.size() - 1][3]), "modestes": float(h[h.size() - 1][2])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a.evol)) > absf(float(b.evol)))
	return out


# --- Sauvegarde -------------------------------------------------------------------------------

static func _cle(v: Vector2i) -> String:
	return "%d,%d" % [v.x, v.y]


static func _de_cle(s: String) -> Vector2i:
	var p := s.split(",")
	return Vector2i(int(p[0]), int(p[1])) if p.size() == 2 else Vector2i.ZERO


func to_dict() -> Dictionary:
	var ind := {}
	for v in indices:
		ind[str(v)] = indices[v]
	var vac := {}
	for v in vacances:
		vac[str(v)] = vacances[v]
	var hi := {}
	for v in histo:
		hi[str(v)] = histo[v]
	var fi := {}
	for bid in fiches:
		fi[str(bid)] = fiches[bid]
	var se := {}
	for k in secteurs:
		se[_cle(k)] = secteurs[k]
	var bv := {}
	for id in bidonvilles:
		var b: Dictionary = bidonvilles[id].duplicate(true)
		b.c = [float((b.c as Vector2).x), float((b.c as Vector2).y)]
		bv[str(id)] = b
	return {"version": 1, "permis": permis, "encadrement": encadrement, "quota": quota, "indices": ind, "vacances": vac,
		"histo": hi, "promoteurs": promoteurs.duplicate(true), "demandes": demandes.duplicate(true), "next_demande": next_demande,
		"fiches": fi, "secteurs": se, "bidonvilles": bv, "next_bv": next_bv, "journal": journal.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	permis = clampi(int(d.get("permis", 1)), 0, 2)
	encadrement = clampi(int(d.get("encadrement", 0)), 0, ENCADREMENTS.size() - 1)
	quota = clampi(int(d.get("quota", 0)), 0, QUOTAS.size() - 1)
	for v in d.get("indices", {}):
		indices[int(v)] = float(d.indices[v])
	for v in d.get("vacances", {}):
		vacances[int(v)] = float(d.vacances[v])
	for v in d.get("histo", {}):
		histo[int(v)] = (d.histo[v] as Array).duplicate(true)
	var pr: Dictionary = d.get("promoteurs", {})
	for id in pr:
		promoteurs[String(id)] = {"caisse": float(pr[id].get("caisse", 0.0)), "projets": int(pr[id].get("projets", 0)),
			"logements": int(pr[id].get("logements", 0))}
	_init_promoteurs()
	for dm in d.get("demandes", []):
		var e: Dictionary = (dm as Dictionary).duplicate(true)
		for key in ["id", "zone", "bid", "log", "soc", "vid", "jour"]:
			e[key] = int(e.get(key, 0))
		demandes.append(e)
	next_demande = int(d.get("next_demande", 1))
	for bid in d.get("fiches", {}):
		var f: Dictionary = (d.fiches[bid] as Dictionary).duplicate(true)
		if f.has("soc"):
			f.soc = int(f.soc)
		if f.has("vide"):
			f.vide = int(f.vide)
		fiches[int(bid)] = f
	for k in d.get("secteurs", {}):
		secteurs[_de_cle(String(k))] = (d.secteurs[k] as Dictionary).duplicate(true)
	for id in d.get("bidonvilles", {}):
		var b: Dictionary = (d.bidonvilles[id] as Dictionary).duplicate(true)
		var c: Array = b.get("c", [0.0, 0.0])
		b.c = Vector2(float(c[0]), float(c[1]))
		b.id = int(id)
		b.vid = int(b.get("vid", -1))
		b.ne = int(b.get("ne", 0))
		var bq := []
		for x in b.get("baraques", []):
			bq.append(int(x))
		b.baraques = bq
		bidonvilles[int(id)] = b
	next_bv = int(d.get("next_bv", 1))
	journal = (d.get("journal", []) as Array).duplicate(true)
	_role_cache.clear()
	for id in bidonvilles:
		for bq in bidonvilles[id].baraques:
			_source(int(bq))
