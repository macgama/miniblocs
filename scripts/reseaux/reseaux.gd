class_name Reseaux
extends Node3D
## Réseaux de la ville : électricité, eau potable, égouts, gaz et chauffage (touche O).
##
## - Production : centrales (charbon, gaz et bois livrés par camion, nucléaire,
##   barrage, éoliennes, solaire, réseau national), captages et forages,
##   châteaux d'eau (réserve), stations d'épuration, lagunage, rejets directs.
## - Distribution : chaque route porte la desserte locale (basse tension, petites
##   conduites, égouts de rue) ; le joueur pose les gros tronçons (lignes HT et
##   MT sur pylônes, conduites, collecteurs), chacun avec son chantier.
## - Consommation : chaque bâtiment demande du courant (selon l'heure et la
##   saison), de l'eau, et rejette des eaux usées.
## - Coupures : fenêtres noires, usines au ralenti, habitants mécontents ou
##   malades, pompiers sans bouches d'incendie, foyers qui partent au bout de
##   7 jours sans courant ou sans eau.
## - Chauffage : réseau de gaz ou de chaleur (poste de gaz, chaufferie bois,
##   géothermie) ; la demande suit la température. Sans lui, on se chauffe à
##   l'électricité (pointe d'hiver), et sans les deux, on a froid.
## - Usure, pannes, orages, canicule, sécheresse, restrictions d'eau : voir ReseauxIncidents.
## - Factures : chaque foyer et chaque entreprise paie son courant et son eau à
##   la ville ; la ville paie l'entretien, le combustible et le courant importé.
##
## Branchements pour les autres systèmes (sans dépendance d'ordre) :
## groupes "rendement_sources" (rendement), "avis_sources" (avis_facteurs),
## "sante_sources" (risque_sante), "eau_incendie" (eau_incendie),
## "budget_entretien" (budget_entretien) ; sources électriques d'autres
## systèmes : nœuds du groupe "electricite_sources" (electricite_sources()).

signal changed
signal message(text: String)
signal info_changed(text: String)

static var instance: Reseaux

const RES := ["elec", "eau", "egout", "gaz"]
## Clé de chaque réseau dans `etat`.
const CLE := {"elec": "e", "eau": "o", "egout": "g", "gaz": "c"}
## Jours sans courant ou sans eau avant qu'un foyer quitte son logement.
const JOURS_DEPART := 7.0
## Prix payés par les habitants et les entreprises (multipliés par le réglage Admin).
const PRIX_KWH := 0.20
const PRIX_M3_EAU := 2.1
const PRIX_M3_ASSAINISSEMENT := 2.0
## Courant acheté au réseau national (payé par la ville).
const PRIX_KWH_IMPORT := 0.25
## Gaz et chaleur : prix payé par les habitants, prix d'achat du gaz par la ville (€ par kWh).
const PRIX_KWH_GAZ := 0.10
const PRIX_KWH_GAZ_IMPORT := 0.05
## Part de la chaleur manquante produite à l'électricité (radiateurs et pompes à chaleur).
const CHAUFFAGE_ELEC := 0.8
## Entretien annuel des bâtiments des réseaux (part de leur prix).
const ENTRETIEN_BATIMENTS := 0.03
## Distance de contamination d'un captage par un rejet en amont (m).
const PORTEE_POLLUTION := 2000.0

var world: TerrainWorld
var buildings: BuildingSystem
var transport: TransportSystem
var population: Population
var production: Production
var ambiance: DayNight

var elec := ReseauBase.new("elec")
var eau := ReseauBase.new("eau")
var egout := ReseauBase.new("egout")
var gaz := ReseauBase.new("gaz")
## Usure, pannes et crises.
var incidents := ReseauxIncidents.new(self)
## Température du moment (°C), besoin de chauffage (0-1,3) ; temperature_forcee pour les essais.
var temperature := 15.0
var besoin := 0.0
var temperature_forcee := NAN
## bid -> {"e": taux électricité, "o": taux eau, "g": taux égouts, "q": qualité de l'eau,
##   "c": taux gaz/chaleur, "ch": logement chauffé (gaz, sinon électricité)}
var etat: Dictionary = {}
## bid -> {"e": jours sans courant, "o": jours sans eau}
var manque: Dictionary = {}
## bid (château d'eau) -> m³ en réserve
var stocks: Dictionary = {}
## bid (captage, forage) -> qualité 0-1 de l'eau prélevée
var qualite: Dictionary = {}
## bid source -> {"cap": capacité du moment, "max": capacité nominale, "why": raison d'une baisse}
var sources_info: Dictionary = {}
## Composante d'égouts -> m³/j rejetés sans traitement
var rejets: Dictionary = {}
## Comptes : {"mois": {poste: €}, "precedent": {}, "jours": int}
var compta := {"mois": {}, "precedent": {}, "jours": 0}
## Vent du moment (0-1) et ensoleillement (0-1), pour le panneau.
var vent := 0.5
var soleil := 0.0

var vue: ReseauxVue
var panneau: Node

var _topo_sale := true
var _sync_sale := true
var _acc := 0.0
var _last_unix := -1.0
var _jour := -1
var _heures_jour := 0.0
var _money_frac := 0.0
var _routes_cache: Array = []
var _routes_ok := false
var _nuisances_ids: Array = []

# --- Outil de pose ---------------------------------------------------------------
enum Outil { AUCUN, TRACER, GOMME }
var outil: Outil = Outil.AUCUN
var type_troncon := "ligne_ht"
var _trace: PackedVector3Array = PackedVector3Array()
var _curseur := Vector3.INF
var _press := Vector2.ZERO


func _init() -> void:
	elec.rayon_raccord = 30.0
	eau.rayon_raccord = 30.0
	egout.rayon_raccord = 30.0
	gaz.rayon_raccord = 30.0


func tous() -> Array:
	return [elec, eau, egout, gaz]


func _enter_tree() -> void:
	instance = self
	for g in ["rendement_sources", "avis_sources", "sante_sources", "eau_incendie", "budget_entretien"]:
		add_to_group(g)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(w: TerrainWorld, b: BuildingSystem, t: TransportSystem, p: Population, prod: Production, a: DayNight) -> void:
	world = w
	buildings = b
	transport = t
	population = p
	production = prod
	ambiance = a
	if buildings != null:
		buildings.changed.connect(func() -> void:
			_sync_sale = true
			_topo_sale = true)
		var prev: Callable = buildings.extra_check
		buildings.extra_check = func(id: String, rect: Rect2i) -> Dictionary:
			var mine := check_site(id, rect)
			if not mine.is_empty():
				return mine
			return prev.call(id, rect) if prev.is_valid() else {}
	if transport != null:
		transport.network_changed.connect(func(_x = null) -> void:
			_routes_ok = false
			_topo_sale = true)
	if population != null:
		# Sans le système d'avis, on ajoute nos raisons à la satisfaction.
		var prev_sat: Callable = population.extra_satisfaction
		population.extra_satisfaction = func(person: Dictionary) -> Array:
			var out: Array = prev_sat.call(person) if prev_sat.is_valid() else [0.0, []]
			if out.size() < 2:
				out = [0.0, []]
			if _avis_present():
				return out
			var mine := satisfaction_of(person)
			return [float(out[0]) + float(mine[0]), (out[1] as Array) + (mine[1] as Array)]
	vue = ReseauxVue.new()
	vue.name = "Vue"
	vue.reseaux = self
	add_child(vue)
	_inscrire_calques()


func clear() -> void:
	for r in tous():
		(r as ReseauBase).clear()
	incidents.clear()
	etat.clear()
	manque.clear()
	stocks.clear()
	qualite.clear()
	sources_info.clear()
	rejets.clear()
	compta = {"mois": {}, "precedent": {}, "jours": 0}
	_trace = PackedVector3Array()
	_topo_sale = true
	_sync_sale = true
	_routes_ok = false
	_last_unix = -1.0
	_jour = -1
	_retirer_nuisances()
	if vue:
		vue.tout_refaire()
	changed.emit()


func reseau(res: String) -> ReseauBase:
	match res:
		"elec":
			return elec
		"eau":
			return eau
		"gaz":
			return gaz
	return egout


# --- Règles de pose ----------------------------------------------------------------

## Règle de pose des bâtiments des réseaux : eau à proximité, bord de carte.
func check_site(id: String, rect: Rect2i) -> Dictionary:
	var r := ReseauxTypes.info(id)
	if r.is_empty():
		return {}
	var txt := "%s : %s %s" % [ReseauxTypes.RES_NAMES[r.res], _fmt(float(r.cap)), ReseauxTypes.UNITES[r.res]] if float(r.get("cap", 0.0)) > 0.0 else ""
	if r.has("stock"):
		txt = ("Batteries : %d MWh, %d MW" % [int(r.stock), int(r.get("puissance", 0.0))]) if String(r.res) == "elec" else "Réserve : %d m³" % int(r.stock)
	if r.has("pres_eau"):
		var d := distance_eau(rect, float(r.pres_eau) + 20.0)
		if d > float(r.pres_eau):
			return {"reason": "Il faut une rivière ou un lac à moins de %d m." % int(r.pres_eau)}
	if String(r.get("source", "")) == "nappe":
		var f := facteur_nappe(rect)
		txt += " · nappe : %d %%" % roundi(f * 100.0)
	if ReseauxTypes.TYPES.get(id, {}).has("prod"):
		var g: Array[String] = []
		var prod: Dictionary = ReseauxTypes.TYPES[id].prod
		for k in prod.in:
			g.append("%s de %s" % [Ressources.format_t(float(prod.in[k])), Ressources.good_name(k).to_lower()])
		txt += " · brûle " + ", ".join(g) + " par jour (livré par camion)"
	return {"info": txt}


## Distance (m) entre l'emprise et la rivière ou le lac le plus proche (INF si aucun à portée).
func distance_eau(rect: Rect2i, portee: float) -> float:
	if world == null:
		return INF
	var best := INF
	var step := 4
	var g := rect.grow(int(portee))
	for x in range(g.position.x, g.end.x, step):
		for z in range(g.position.y, g.end.y, step):
			var c := Vector2i(x, z)
			if not _est_eau(c):
				continue
			var dx := maxi(maxi(rect.position.x - x, x - (rect.end.x - 1)), 0)
			var dz := maxi(maxi(rect.position.y - z, z - (rect.end.y - 1)), 0)
			best = minf(best, Vector2(dx, dz).length())
	return best


func _est_eau(c: Vector2i) -> bool:
	if world.water_cells.has(c):
		return true
	var h := world.cell_height(c)
	if is_nan(h):
		return false
	if h < world.sea_level():
		return true
	if world.cell_biome(c) == 80:
		return true
	return world.water != null and world.water.width_at(c.x + 0.5, c.y + 0.5) > 3.0


## Nappe souterraine sous un forage (0,3 dans le désert, 1 ailleurs).
func facteur_nappe(rect: Rect2i) -> float:
	if world == null:
		return 1.0
	var bio := world.cell_biome(rect.position + rect.size / 2)
	match bio:
		60:
			return 0.3
		70:
			return 0.5
	return 1.0


# --- Tronçons posés par le joueur -------------------------------------------------------

## Pose un tronçon (tracé déjà calé sur le relief). Renvoie son id, ou -1.
func poser(type_id: String, pts: PackedVector3Array, payer := true) -> int:
	var tr := ReseauxTypes.troncon(type_id)
	if tr.is_empty() or pts.size() < 2:
		return -1
	var l := ReseauBase.longueur(pts)
	var prix := ReseauxTypes.prix_troncon(type_id, l)
	if payer and buildings != null and not buildings.unlimited_money:
		if buildings.money < prix:
			message.emit("Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(prix))
			return -1
		buildings.money -= prix
	var r := reseau(String(tr.res))
	var id := r.poser_troncon(pts, type_id, true)
	r.troncons[id]["cost"] = prix
	_lancer_chantier(String(tr.res), id)
	_topo_sale = true
	if vue:
		vue.refaire_troncon(String(tr.res), id)
	if payer:
		message.emit("%s : %d m pour %s." % [tr.name, roundi(l), BuildingSystem.format_money(prix)])
	changed.emit()
	return id


func retirer(res: String, id: int) -> void:
	var r := reseau(res)
	if not r.troncons.has(id):
		return
	var e: Dictionary = r.troncons[id]
	var back := roundi(float(e.get("cost", 0)) * 0.3)
	if buildings != null and not buildings.unlimited_money:
		buildings.money += back
	var sc := _chantiers()
	if sc != null:
		sc.annuler(_cle(res, id))
	r.retirer_troncon(id)
	_topo_sale = true
	if vue:
		vue.refaire_troncon(res, id)
	message.emit("%s retiré (%s rendus)." % [ReseauxTypes.troncon(String(e.t)).get("name", "Tronçon"), BuildingSystem.format_money(back)])
	changed.emit()


## Tronçon le plus proche d'un point (à moins de r mètres) : {res, id} ou {}.
func troncon_pres(p: Vector3, r: float) -> Dictionary:
	var best := {}
	var bd := r
	for res in RES:
		var rs := reseau(res)
		for id in rs.troncons:
			var pts: PackedVector3Array = rs.troncons[id].pts
			for i in range(pts.size() - 1):
				var d := ReseauBase.dist_seg(p, pts[i], pts[i + 1])
				if d < bd:
					bd = d
					best = {"res": res, "id": id}
	return best


# --- Chantiers (fil « chantiers visibles », branché s'il est là) ----------------------------

const HEURES_PAR_M := {"ligne_ht": 0.4, "ligne_mt": 0.15, "conduite_eau": 0.3, "collecteur": 0.5, "conduite_gaz": 0.25}


## Étapes des chantiers de lignes aériennes et de canalisations enterrées.
const ETAPES_AERIEN := [
	[0.15, "piquetage", "Piquetage du tracé"],
	[0.5, "fondations", "Fondations des pylônes"],
	[0.8, "levage", "Levage des pylônes"],
	[1.0, "cables", "Déroulage et tension des câbles"],
]
const ETAPES_ENTERRE := [
	[0.15, "piquetage", "Piquetage du tracé"],
	[0.55, "tranchee", "Tranchée"],
	[0.85, "pose", "Pose des tuyaux"],
	[1.0, "remblai", "Remblai et essais de pression"],
]


func _chantiers() -> SuiviChantiers:
	if SuiviChantiers.instance != null and is_instance_valid(SuiviChantiers.instance) and SuiviChantiers.instance.is_inside_tree():
		return SuiviChantiers.instance
	return null


static func _cle(res: String, id: int) -> String:
	return "reseau:%s:%d" % [res, id]


func _lancer_chantier(res: String, id: int) -> void:
	var sc := _chantiers()
	var r := reseau(res)
	if sc == null or not r.troncons.has(id) or Chantiers.instantanes():
		r.terminer_troncon(id)
		r.troncons.get(id, {}).erase("av")
		return
	var e: Dictionary = r.troncons[id]
	e.ok = false
	var heures := ReseauBase.longueur(e.pts) * float(HEURES_PAR_M.get(String(e.t), 0.3))
	var av := float(e.get("av", 0.0))
	sc.commencer(_cle(res, id), heures,
		func(a: float, _etape = null) -> void:
			if r.troncons.has(id):
				r.troncons[id]["av"] = a
				if vue:
					vue.avancement(res, id, a),
		func() -> void:
			if r.troncons.has(id):
				r.terminer_troncon(id)
				r.troncons[id].erase("av")
				_topo_sale = true
				if vue:
					vue.refaire_troncon(res, id)
				changed.emit(),
		av, 0, ETAPES_AERIEN if res == "elec" else ETAPES_ENTERRE)


## Le chantier d'un tronçon : {av, etape} ou {} s'il est en service.
func chantier_de(res: String, id: int) -> Dictionary:
	var sc := _chantiers()
	var k := _cle(res, id)
	if sc == null or not sc.en_cours(k):
		return {}
	return {"av": sc.avancement(k), "etape": sc.etape(k)}


static func _classe(n: String) -> Variant:
	for c in ProjectSettings.get_global_class_list():
		if String(c["class"]) == n:
			return load(String(c.path))
	return null


# --- Bâtiments : sources et consommateurs -------------------------------------------------

## Demande moyenne d'un type de bâtiment : {"elec": MW, "eau": m³/j, "egout": m³/j}.
static func demande_type(type_id: String) -> Dictionary:
	var t := BuildingCatalog.get_type(type_id)
	var r := ReseauxTypes.info(type_id)
	if t.is_empty() or not r.is_empty() or bool(t.get("espace", false)):
		return {"elec": float(r.get("elec", 0.0)), "eau": 0.0, "egout": 0.0, "gaz": 0.0}
	var cat := String(t.get("cat", ""))
	var log := float(t.get("logements", 0))
	var emp := float(t.get("emplois", 0))
	var vis := float(t.get("visiteurs", 0))
	var kw_emp := 0.5
	var eau_emp := 0.05
	var chaleur_emp := 0.8
	match cat:
		"industrie", "production":
			kw_emp = 3.0
			eau_emp = 0.5
			chaleur_emp = 2.0
		"commerce":
			kw_emp = 0.9
		"services":
			kw_emp = 0.7
			eau_emp = 0.08
		"sport", "loisirs":
			kw_emp = 1.5
			eau_emp = 0.2
	var kw := log * 0.6 + emp * kw_emp + vis * 0.02
	var m3 := log * 0.33 + emp * eau_emp + vis * 0.01
	if kw <= 0.0 and m3 <= 0.0:
		return {"elec": 0.0, "eau": 0.0, "egout": 0.0, "gaz": 0.0}
	kw = maxf(kw, 0.3)
	m3 = maxf(m3, 0.02)
	# Chauffage par grand froid (kW) : 4 par logement, selon les emplois ailleurs.
	var chaleur := log * 4.0 + emp * chaleur_emp + vis * 0.01
	return {"elec": kw / 1000.0, "eau": m3, "egout": m3 * 0.9, "gaz": maxf(chaleur, 0.2) / 1000.0}


## Besoin de chauffage selon la température extérieure (1 vers 0 °C, eau chaude comprise).
static func besoin_chauffage(t: float) -> float:
	return clampf((18.0 - t) / 22.0, 0.0, 1.2) + 0.08


## Courbe de la journée et de l'année pour l'électricité (1 = moyenne).
func courbe_elec(h: float, mois: int) -> float:
	var f := 0.72 + 0.38 * exp(-pow(h - 19.5, 2.0) / 5.0) + 0.22 * exp(-pow(h - 8.0, 2.0) / 3.0) + 0.12 * exp(-pow(h - 13.0, 2.0) / 4.0)
	var hiver := mois in [12, 1, 2]
	if ambiance != null and ambiance.lat < 0.0:
		hiver = mois in [6, 7, 8]
	if hiver:
		f *= 1.08
	return f


func _sync() -> void:
	_sync_sale = false
	if buildings == null:
		return
	var vus := {}
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		vus[bid] = true
		var rect := buildings._rect_of(b)
		var pos := BuildingSystem.rect_center(rect)
		var marge := maxf(rect.size.x, rect.size.y) * 0.5
		var info := ReseauxTypes.info(String(b.t))
		if not info.is_empty():
			var r := reseau(String(info.res))
			if not r.sources.has(bid):
				r.ajouter_source(bid, pos, 0.0, marge)
				if info.has("stock") and not stocks.has(bid):
					stocks[bid] = float(info.stock) * 0.5
		var dem := demande_type(String(b.t))
		for res in RES:
			if float(dem[res]) > 0.0:
				var rr := reseau(res)
				if not rr.consos.has(bid):
					rr.ajouter_conso(bid, pos, float(dem[res]), marge)
	for r in tous():
		var rs := r as ReseauBase
		for bid in rs.sources.keys():
			if not vus.has(bid):
				rs.retirer_source(bid)
		for bid in rs.consos.keys():
			if not vus.has(bid):
				rs.retirer_conso(bid)
	for bid in etat.keys():
		if not vus.has(bid):
			etat.erase(bid)
			manque.erase(bid)
	for bid in stocks.keys():
		if not vus.has(bid):
			stocks.erase(bid)
	_sync_externes()
	_topo_sale = true


## Sources d'électricité d'autres systèmes (incinérateur…) : groupe "electricite_sources".
var _externes: Dictionary = {}


func _sync_externes() -> void:
	if buildings == null or not is_inside_tree():
		return
	var vus := {}
	for n in get_tree().get_nodes_in_group("electricite_sources"):
		if n == self or not n.has_method("electricite_sources"):
			continue
		for s in n.call("electricite_sources"):
			var bid := int(s.bid)
			if not buildings.buildings.has(bid):
				continue
			vus[bid] = float(s.get("mw", 0.0))
	for bid in _externes.keys():
		if not vus.has(bid):
			elec.retirer_source(bid)
			_externes.erase(bid)
			_topo_sale = true
	for bid in vus:
		if not elec.sources.has(bid):
			var b: Dictionary = buildings.buildings[bid]
			var rect := buildings._rect_of(b)
			elec.ajouter_source(bid, BuildingSystem.rect_center(rect), float(vus[bid]), maxf(rect.size.x, rect.size.y) * 0.5)
			_topo_sale = true
		_externes[bid] = float(vus[bid])


func _routes() -> Array:
	if _routes_ok:
		return _routes_cache
	_routes_ok = true
	_routes_cache = []
	if transport == null or transport.network == null:
		return _routes_cache
	for eid in transport.network.edges:
		var e: Dictionary = transport.network.edges[eid]
		if TransportTypes.mode_of(String(e.t)) == TransportTypes.Mode.ROAD:
			_routes_cache.append(e.pts)
	return _routes_cache


func recalculer_topologie() -> void:
	_topo_sale = false
	var routes := _routes()
	for r in tous():
		(r as ReseauBase).recalculer(routes)
	if vue:
		vue.calques_sales = true


# --- Simulation ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.5:
		return
	var heures := 0.0
	if ambiance != null:
		var u := ambiance.unix_time
		if _last_unix < 0.0 or u < _last_unix:
			_last_unix = u
		heures = clampf((u - _last_unix) / 3600.0, 0.0, 24.0)
		_last_unix = u
	_acc = 0.0
	simuler(heures)


## Avance de `heures` heures de jeu : capacités, partage, effets, factures.
func simuler(heures: float) -> void:
	if _sync_sale:
		_sync()
	else:
		_sync_externes()
	if _topo_sale:
		recalculer_topologie()
	var now := _maintenant()
	temperature = _temperature()
	besoin = besoin_chauffage(temperature)
	incidents.maj(heures, temperature)
	if _topo_sale:
		recalculer_topologie()
	_maj_gaz()
	_maj_capacites(now)
	elec.rebilan()
	_maj_batteries(heures)
	_maj_eau(now, heures)
	egout.rebilan()
	_maj_rejets()
	_maj_etats()
	_heures_jour += heures
	while _heures_jour >= 24.0:
		_heures_jour -= 24.0
		_nouveau_jour()
	if heures > 0.0:
		_facturer(heures / 24.0)
	changed.emit()


func _temperature() -> float:
	if not is_nan(temperature_forcee):
		return temperature_forcee
	if ambiance != null and ambiance.weather != null:
		return ambiance.weather.temperature
	return 15.0


func _maintenant() -> Dictionary:
	if ambiance == null:
		return {"h": 12.0, "mois": 6}
	var dt := ambiance.local_datetime()
	return {"h": ambiance.local_hour(), "mois": int(dt.get("month", 6))}


func _staff(bid: int) -> float:
	if population == null or buildings == null or not buildings.buildings.has(bid):
		return 1.0
	var jobs := int(BuildingCatalog.get_type(String(buildings.buildings[bid].t)).get("emplois", 0))
	if jobs <= 0:
		return 1.0
	return clampf(float((population.by_job.get(bid, []) as Array).size()) / jobs, 0.0, 1.0)


func _maj_capacites(now: Dictionary) -> void:
	var h := float(now.h)
	var t := ambiance.unix_time if ambiance != null else 0.0
	# Vent : bruit lent + rafales d'orage. Soleil : hauteur et nuages.
	var cover := 0.2
	var storm := 0.0
	if ambiance != null and ambiance.weather != null:
		cover = ambiance.weather.cover
		storm = ambiance.weather.storm
	vent = clampf(0.45 + 0.35 * sin(t / 37000.0) * cos(t / 91000.0 + 1.3) + 0.4 * storm, 0.0, 1.0)
	var elev := ambiance.real_sun_elev if ambiance != null else 45.0
	soleil = clampf(sin(deg_to_rad(maxf(elev, 0.0))) * (1.0 - 0.75 * cover), 0.0, 1.0)
	var courbe := courbe_elec(h, int(now.mois)) * ReseauxIncidents.facteur_clim(temperature)
	var libre := not ReglagesPartie.actuel.reseaux_obligatoires
	for bid in elec.consos:
		var d := float(demande_type(_type(bid)).elec) * courbe
		# Chaleur que le réseau de gaz ne fournit pas : radiateurs et pompes à chaleur.
		if not libre and gaz.consos.has(bid):
			d += float(gaz.consos[bid].d) * (1.0 - gaz.taux_servi(bid)) * CHAUFFAGE_ELEC
		elec.set_demande(bid, d)
	for bid in elec.sources:
		var info := ReseauxTypes.info(_type(bid))
		var nom := float(info.get("cap", 0.0))
		var cap := nom
		var why := ""
		match String(info.get("source", "")):
			"combustible":
				var eff := 1.0
				if production != null and production.sites.has(bid):
					eff = float(production.sites[bid].get("eff", 0.0))
					if eff < 0.999:
						why = String(production.sites[bid].get("status", ""))
				cap = nom * eff
			"soleil":
				cap = nom * soleil
				why = "nuit" if soleil <= 0.001 else ("nuages" if cover > 0.5 else "")
			"vent":
				# Courbe de puissance : rien sous 15 %, plein régime au-dessus de 75 %.
				cap = nom * clampf((vent - 0.15) / 0.6, 0.0, 1.0)
				why = "peu de vent" if vent < 0.4 else ""
			"riviere":
				cap = nom * 0.85
			"uranium", "national":
				cap = nom
			"stockage":
				# Les batteries rendent du courant après le bilan (_maj_batteries).
				cap = 0.0
			_:
				if _externes.has(bid):
					# Source d'un autre système (incinérateur…) : sa puissance déclarée.
					nom = float(_externes[bid])
					cap = nom
		var sec := incidents.facteur_secheresse(info)
		if sec < 1.0:
			cap *= sec
			why = "sécheresse"
		var st := _staff(bid)
		if String(info.get("source", "")) != "combustible" and st < 1.0:
			cap *= 0.3 + 0.7 * st
			if st < 0.5:
				why = "manque de personnel"
		if buildings != null and buildings.en_chantier(bid):
			cap = 0.0
			why = "en chantier"
		elec.set_capacite(bid, cap)
		sources_info[bid] = {"cap": cap, "max": nom, "why": why}


## Batteries : le surplus d'électricité les charge, elles couvrent un manque
## (dans la limite de leur puissance et de ce qu'elles ont gardé).
func _maj_batteries(heures: float) -> void:
	var par_comp := {}
	for bid in stocks:
		var info := ReseauxTypes.info(_type(bid))
		if String(info.get("res", "")) != "elec":
			continue
		var c := elec.composante_de(bid)
		if c < 0 or (buildings != null and buildings.en_chantier(bid)):
			continue
		if not par_comp.has(c):
			par_comp[c] = []
		(par_comp[c] as Array).append(bid)
	for c in par_comp:
		var k: Dictionary = elec.composantes.get(c, {})
		if k.is_empty():
			continue
		var list: Array = par_comp[c]
		var tot := 0.0
		var cap_tot := 0.0
		var p_max := 0.0
		for bid in list:
			var info := ReseauxTypes.info(_type(bid))
			tot += float(stocks[bid])
			cap_tot += float(info.get("stock", 0.0))
			p_max += float(info.get("puissance", 0.0))
		var bal := float(k.prod) - float(k.dem)
		var rendu := 0.0
		if bal > 0.0:
			tot = minf(cap_tot, tot + minf(bal, p_max) * heures * 0.9)
		elif bal < 0.0 and tot > 0.0:
			rendu = minf(-bal, p_max)
			if heures > 0.0:
				rendu = minf(rendu, tot / heures)
			tot = maxf(0.0, tot - rendu * heures)
		for bid in list:
			var cmax := float(ReseauxTypes.info(_type(bid)).get("stock", 0.0))
			stocks[bid] = tot * (cmax / cap_tot) if cap_tot > 0.0 else 0.0
			sources_info[bid] = {"cap": rendu * cmax / cap_tot if cap_tot > 0.0 else 0.0, "max": float(ReseauxTypes.info(_type(bid)).get("puissance", 0.0)),
				"why": "chargées à %d %%" % roundi(tot / cap_tot * 100.0) if cap_tot > 0.0 else ""}
		if rendu > 0.0:
			k.prod = float(k.prod) + rendu
			k.taux = 1.0 if float(k.dem) <= 0.0 else clampf(float(k.prod) / float(k.dem), 0.0, 1.0)


## Gaz et chaleur : la demande suit le froid, les sources leur combustible.
func _maj_gaz() -> void:
	for bid in gaz.consos:
		gaz.set_demande(bid, float(demande_type(_type(bid)).gaz) * besoin)
	for bid in gaz.sources:
		var info := ReseauxTypes.info(_type(bid))
		var nom := float(info.get("cap", 0.0))
		var cap := nom
		var why := ""
		if String(info.get("source", "")) == "combustible":
			var eff := 1.0
			if production != null and production.sites.has(bid):
				eff = float(production.sites[bid].get("eff", 0.0))
				if eff < 0.999:
					why = String(production.sites[bid].get("status", ""))
			cap = nom * eff
		else:
			var st := _staff(bid)
			if st < 1.0:
				cap *= 0.3 + 0.7 * st
				if st < 0.5:
					why = "manque de personnel"
		if float(info.get("elec", 0.0)) > 0.0:
			var te := _taux_elec_source(bid)
			cap *= te
			if te < 0.99:
				why = "manque d'électricité"
		if buildings != null and buildings.en_chantier(bid):
			cap = 0.0
			why = "en chantier"
		gaz.set_capacite(bid, cap)
		sources_info[bid] = {"cap": cap, "max": nom, "why": why}
	gaz.rebilan()


func _maj_eau(_now: Dictionary, heures: float) -> void:
	for bid in eau.sources:
		var info := ReseauxTypes.info(_type(bid))
		var nom := float(info.get("cap", 0.0))
		var cap := nom
		var why := ""
		if String(info.get("source", "")) == "nappe" and buildings != null and buildings.buildings.has(bid):
			cap *= facteur_nappe(buildings._rect_of(buildings.buildings[bid]))
		var sec := incidents.facteur_secheresse(info)
		if sec < 1.0:
			cap *= sec
			why = "sécheresse"
		if float(info.get("elec", 0.0)) > 0.0:
			var te := _taux_elec_source(bid)
			cap *= te
			if te < 0.99:
				why = "manque d'électricité"
		var st := _staff(bid)
		if st < 1.0:
			cap *= 0.3 + 0.7 * st
		if buildings != null and buildings.en_chantier(bid):
			cap = 0.0
			why = "en chantier"
		eau.set_capacite(bid, cap)
		sources_info[bid] = {"cap": cap, "max": nom, "why": why}
	var fe := incidents.facteur_eau(temperature)
	for bid in eau.consos:
		eau.set_demande(bid, float(demande_type(_type(bid)).eau) * fe)
	for bid in egout.consos:
		egout.set_demande(bid, float(demande_type(_type(bid)).egout) * fe)
	for bid in egout.sources:
		var info := ReseauxTypes.info(_type(bid))
		var nom := float(info.get("cap", 0.0))
		var cap := nom
		var why := ""
		if float(info.get("elec", 0.0)) > 0.0:
			var te := _taux_elec_source(bid)
			cap *= te
			if te < 0.99:
				why = "manque d'électricité"
		if String(info.get("source", "")) != "rejet":
			var st := _staff(bid)
			if st < 1.0:
				cap *= 0.3 + 0.7 * st
		if buildings != null and buildings.en_chantier(bid):
			cap = 0.0
			why = "en chantier"
		egout.set_capacite(bid, cap)
		sources_info[bid] = {"cap": cap, "max": nom, "why": why}
	eau.rebilan()
	# Fuites dans les rues : une part de la production se perd.
	for c in eau.composantes:
		var perte := incidents.perte_eau(c)
		if perte > 0.0:
			var kc: Dictionary = eau.composantes[c]
			kc.prod = float(kc.prod) * (1.0 - perte)
			kc.taux = 1.0 if float(kc.dem) <= 0.0 else clampf(float(kc.prod) / float(kc.dem), 0.0, 1.0)
	# Châteaux d'eau : le surplus remplit la réserve, la réserve couvre un manque.
	var par_comp := {}
	for bid in stocks:
		var c := eau.composante_de(bid)
		if c < 0:
			continue
		if not par_comp.has(c):
			par_comp[c] = []
		(par_comp[c] as Array).append(bid)
	for c in par_comp:
		var k: Dictionary = eau.composantes.get(c, {})
		if k.is_empty():
			continue
		var bal := (float(k.prod) - float(k.dem)) * heures / 24.0
		var list: Array = par_comp[c]
		var tot := 0.0
		var cap_tot := 0.0
		for bid in list:
			tot += float(stocks[bid])
			cap_tot += float(ReseauxTypes.info(_type(bid)).get("stock", 0.0))
		var nouveau := clampf(tot + bal, 0.0, cap_tot)
		var couvert := float(k.dem) <= 0.0 or float(k.prod) >= float(k.dem) or nouveau > 0.0
		for bid in list:
			var cmax := float(ReseauxTypes.info(_type(bid)).get("stock", 0.0))
			stocks[bid] = nouveau * (cmax / cap_tot) if cap_tot > 0.0 else 0.0
		if couvert and float(k.dem) > 0.0 and (float(k.prod) > 0.0 or nouveau > 0.0):
			k.taux = 1.0
			k.prod = maxf(float(k.prod), float(k.dem))
	_maj_qualite()


## Courant reçu par une usine d'eau ou une station (elle est aussi consommatrice).
func _taux_elec_source(bid: int) -> float:
	if not ReglagesPartie.actuel.reseaux_obligatoires:
		return 1.0
	return elec.taux_servi(bid)


## Qualité de l'eau prélevée : rejets d'égouts en amont et bâtiments sans égout.
func _maj_qualite() -> void:
	qualite.clear()
	var points := _points_rejet()
	for bid in eau.sources:
		var info := ReseauxTypes.info(_type(bid))
		if float(info.get("cap", 0.0)) <= 0.0:
			continue
		var p: Vector3 = eau.sources[bid].p
		var nappe := String(info.get("source", "")) == "nappe"
		var py := _hauteur(p)
		var pol := 0.0
		for q in points:
			var d := Vector2(p.x, p.z).distance_to(Vector2(q.p.x, q.p.z))
			var portee := 300.0 if nappe else PORTEE_POLLUTION
			if d > portee:
				continue
			# Une rivière coule vers le bas : un rejet plus haut est en amont.
			var amont := nappe or d < 250.0 or _hauteur(q.p) >= py - 0.5
			if not amont:
				continue
			# Quelques dizaines de m³ d'eaux usées suffisent à contaminer un forage voisin.
			pol += float(q.m3) / (150.0 if not nappe else 100.0) * (1.0 - d / portee)
		qualite[bid] = clampf(1.0 - pol, 0.0, 1.0)


func _hauteur(p: Vector3) -> float:
	if world == null:
		return p.y
	var h := world.cell_height(Vector2i(floori(p.x), floori(p.z)))
	return p.y if is_nan(h) else h


## Rejets sans traitement : [{p, m3}] (sorties d'égout, bâtiments non raccordés regroupés).
func _points_rejet() -> Array:
	var out := []
	for bid in egout.sources:
		if String(ReseauxTypes.info(_type(bid)).get("source", "")) != "rejet":
			continue
		var c := egout.composante_de(bid)
		var v := float(rejets.get(c, 0.0))
		if v > 0.0:
			out.append({"p": egout.sources[bid].p, "m3": v, "bid": bid})
	if not ReglagesPartie.actuel.reseaux_obligatoires:
		return out
	var cases := {}
	for bid in egout.consos:
		if egout.taux_servi(bid) >= 0.5:
			continue
		var p: Vector3 = egout.consos[bid].p
		var k := Vector2i(floori(p.x / 200.0), floori(p.z / 200.0))
		if not cases.has(k):
			cases[k] = {"p": p, "m3": 0.0}
		cases[k].m3 = float(cases[k].m3) + float(egout.consos[bid].d) * 0.5
	for k in cases:
		out.append(cases[k])
	return out


## Volume rejeté sans traitement par composante d'égouts (vers les sorties directes).
func _maj_rejets() -> void:
	rejets.clear()
	for c in egout.composantes:
		var traite := 0.0
		var rejet := false
		for bid in egout.sources:
			if egout.composante_de(bid) != c:
				continue
			if String(ReseauxTypes.info(_type(bid)).get("source", "")) == "rejet":
				rejet = true
			else:
				traite += float(egout.sources[bid].cap)
		var dem := float(egout.composantes[c].dem)
		if rejet:
			rejets[c] = maxf(dem - traite, 0.0)
	_declarer_nuisances()


## Qualité de l'eau du robinet d'un bâtiment (moyenne de ses sources, 1 = potable).
func qualite_de(bid: int) -> float:
	var c := eau.composante_de(bid)
	if c < 0:
		return 1.0
	var num := 0.0
	var den := 0.0
	for s in eau.sources:
		if eau.composante_de(s) != c or not qualite.has(s):
			continue
		var cap := float(eau.sources[s].cap)
		num += cap * float(qualite[s])
		den += cap
	return num / den if den > 0.0 else 1.0


func _maj_etats() -> void:
	var libre := not ReglagesPartie.actuel.reseaux_obligatoires
	var qual_comp := {}
	var vus := {}
	for r in tous():
		for bid in (r as ReseauBase).consos:
			vus[bid] = true
	for bid in vus:
		var e := 1.0
		var o := 1.0
		var g := 1.0
		var q := 1.0
		var c := 1.0
		if not libre:
			if elec.consos.has(bid):
				e = 0.0 if incidents.coupe(bid) else elec.taux_servi(bid)
			if gaz.consos.has(bid):
				c = gaz.taux_servi(bid)
			if eau.consos.has(bid):
				o = eau.taux_servi(bid)
				var ce := eau.composante_de(bid)
				if not qual_comp.has(ce):
					qual_comp[ce] = qualite_de(bid)
				q = float(qual_comp[ce])
			if egout.consos.has(bid):
				g = egout.taux_servi(bid)
		var avant: Dictionary = etat.get(bid, {})
		etat[bid] = {"e": e, "o": o, "g": g, "q": q, "c": c, "ch": clampf(c + (1.0 - c) * e, 0.0, 1.0)}
		var noir := e < 0.5
		if avant.is_empty() or (float(avant.e) < 0.5) != noir:
			_set_noir(bid, noir)


func _set_noir(bid: int, on: bool) -> void:
	if buildings == null:
		return
	var mi := buildings.node_of(bid)
	if mi == null:
		return
	if bool(mi.get_meta("res_panne", false)) == on:
		return
	mi.set_meta("res_panne", on)
	BatimentsVie.refresh_material(mi)


func taux(bid: int, res: String) -> float:
	return float(etat.get(bid, {}).get(CLE.get(res, "e"), 1.0))


## Le logement est-il chauffé (gaz ou chaleur, sinon électricité) ? 1 = oui.
func chauffe(bid: int) -> float:
	return float(etat.get(bid, {}).get("ch", 1.0))


## Raccordé aux égouts et l'eau y est traitée (pour la pollution).
func raccorde_egout(bid: int) -> bool:
	if not egout.est_raccorde(bid):
		return false
	return not rejets.has(egout.composante_de(bid)) and egout.taux_servi(bid) >= 0.5


# --- Effets sur les autres systèmes ------------------------------------------------------

## Rendement d'une entreprise (Production) : sans courant ni eau, l'usine ralentit.
const PLEIN_AIR := ["elevage", "exploitation_forestiere", "port_peche", "marche", "sabliere", "argiliere"]


func rendement(bid: int) -> float:
	if not etat.has(bid):
		return 1.0
	var s: Dictionary = etat[bid]
	var plancher := plancher_sans_courant(_type(bid))
	return lerpf(plancher, 1.0, clampf(float(s.e), 0.0, 1.0)) * lerpf(0.6, 1.0, clampf(float(s.o), 0.0, 1.0))


## Ce qu'une entreprise produit encore sans courant : presque tout aux champs et
## au grand air, un peu dans les commerces (à la main), presque rien à l'usine.
static func plancher_sans_courant(type_id: String) -> float:
	if type_id.begins_with("ferme") or type_id in PLEIN_AIR:
		return 0.8
	var cat := String(BuildingCatalog.get_type(type_id).get("cat", ""))
	if cat in ["industrie", "production"]:
		return 0.1
	return 0.3


## Pression aux bouches d'incendie (1 = normale) : sans eau, les pompiers n'ont que leurs citernes.
func eau_incendie(bid: int) -> float:
	return taux(bid, "eau")


## Risque pour la santé d'un logement (ajouté à la pollution, 0-1).
func risque_sante(bid: int) -> float:
	if not etat.has(bid):
		return 0.0
	var s: Dictionary = etat[bid]
	var r := 0.0
	r += (1.0 - float(s.q)) * 0.6 * float(s.o)
	r += (1.0 - float(s.o)) * 0.2
	r += (1.0 - float(s.g)) * 0.25
	if besoin > 0.3:
		r += (1.0 - float(s.get("ch", 1.0))) * 0.3 * minf(besoin, 1.0)
	return clampf(r, 0.0, 1.0)


func satisfaction_of(p: Dictionary) -> Array:
	if population == null:
		return [0.0, []]
	var home := population.home_of(p)
	if home < 0 or not etat.has(home):
		return [0.0, []]
	var s: Dictionary = etat[home]
	var d := 0.0
	var why := []
	if float(s.e) < 0.5:
		d -= 15.0
		why.append("− pas d'électricité à la maison")
	elif float(s.e) < 0.95:
		d -= 6.0
		why.append("− coupures d'électricité")
	if float(s.o) < 0.5:
		d -= 15.0
		why.append("− pas d'eau au robinet")
	elif float(s.o) < 0.95:
		d -= 6.0
		why.append("− eau coupée par moments")
	if float(s.g) < 0.5:
		d -= 10.0
		why.append("− les égouts débordent")
	if float(s.q) < 0.7 and float(s.o) > 0.0:
		d -= 8.0
		why.append("− l'eau du robinet n'est pas potable")
	if besoin > 0.3:
		var ch := float(s.get("ch", 1.0))
		if ch < 0.5 and float(s.e) < 0.5:
			# Sans courant ni gaz : la plainte « pas d'électricité » compte déjà.
			var i := why.find("− pas d'électricité à la maison")
			if i >= 0:
				why[i] = "− pas d'électricité ni de chauffage : il fait froid"
		elif ch < 0.5:
			d -= 12.0
			why.append("− il fait froid dans le logement")
		elif ch < 0.9:
			d -= 4.0
			why.append("− logement mal chauffé")
	if incidents.restrictions and float(s.o) >= 0.5:
		d -= 3.0
		why.append("− restrictions d'eau (arrosage, piscines)")
	if why.is_empty():
		d += 2.0
		why.append("+ eau et électricité sans coupure")
	return [d, why]


## Facteurs pour le système d'avis (groupe "avis_sources").
func avis_facteurs() -> Array:
	return [{"id": "reseaux", "theme": "reseaux", "f": func(p: Dictionary) -> Array: return satisfaction_of(p)}]


func _avis_present() -> bool:
	if not is_inside_tree():
		return false
	var root := get_tree().root
	return root.get_node_or_null("Avis") != null


## Entretien mensuel (groupe "budget_entretien") : {poste: € par mois}.
func budget_entretien() -> Dictionary:
	var out := {}
	for res in RES:
		var tot := 0.0
		var r := reseau(res)
		for id in r.troncons:
			var e: Dictionary = r.troncons[id]
			tot += ReseauBase.longueur(e.pts) * float(ReseauxTypes.troncon(String(e.t)).get("entretien_m", 0.0)) / 12.0
		for bid in r.sources:
			if buildings != null and buildings.buildings.has(bid):
				tot += float(buildings.buildings[bid].get("cost", BuildingCatalog.cost(_type(bid)))) * ENTRETIEN_BATIMENTS / 12.0
		out[{"elec": "Entretien du réseau électrique", "eau": "Entretien du réseau d'eau", "egout": "Entretien des égouts",
			"gaz": "Entretien du réseau de gaz et de chaleur"}[res]] = roundf(tot)
	return out


func _budget_present() -> bool:
	return get_parent() != null and get_parent().get_node_or_null("Budget") != null


# --- Pollution de l'eau (module Nuisances, s'il est là) ---------------------------------------

func _nuisances() -> Object:
	var cl = _classe("Nuisances")
	if cl == null:
		return null
	var inst = cl.get("instance")
	return inst if inst != null and is_instance_valid(inst) and inst.has_method("ajouter_source") else null


func _declarer_nuisances() -> void:
	var n := _nuisances()
	if n == null:
		return
	_retirer_nuisances()
	var i := 0
	for q in _points_rejet():
		var id := "egout:%d" % i
		i += 1
		var force := clampf(float(q.m3) / 50.0, 0.05, 1.0)
		n.call("ajouter_source", id, "eau", q.p, force, clampf(150.0 + float(q.m3) * 0.5, 150.0, 400.0))
		_nuisances_ids.append(id)


func _retirer_nuisances() -> void:
	var n := _nuisances()
	if n != null:
		for id in _nuisances_ids:
			n.call("retirer_source", id)
	_nuisances_ids.clear()


# --- Jours : coupures longues, factures --------------------------------------------------

func _nouveau_jour() -> void:
	incidents.nouveau_jour()
	# La santé dépend de l'eau : la pollution autour des logements est recalculée.
	if population != null and population.vie != null:
		population.vie.clear_cache()
	if not ReglagesPartie.actuel.reseaux_obligatoires or population == null:
		manque.clear()
		return
	var partis := 0
	for bid in etat:
		var s: Dictionary = etat[bid]
		if not population.by_home.has(bid) or (population.by_home[bid] as Array).is_empty():
			manque.erase(bid)
			continue
		var m: Dictionary = manque.get(bid, {"e": 0.0, "o": 0.0})
		m.e = float(m.e) + 1.0 if float(s.e) < 0.5 else 0.0
		m.o = float(m.o) + 1.0 if float(s.o) < 0.5 else 0.0
		manque[bid] = m
		if float(m.e) >= JOURS_DEPART or float(m.o) >= JOURS_DEPART:
			var quoi := "d'électricité" if float(m.e) >= JOURS_DEPART else "d'eau"
			for hid in (population.by_home[bid] as Array).duplicate():
				population._remove_household(int(hid), "Quitte la ville : plus %s depuis une semaine" % quoi)
				partis += 1
			manque.erase(bid)
	if partis > 0:
		message.emit("%d foyer%s quitte%s la ville : plus d'eau ou d'électricité depuis une semaine." % [partis, "s" if partis > 1 else "", "nt" if partis > 1 else ""])
	compta.jours = int(compta.jours) + 1
	if int(compta.jours) >= 30:
		compta.precedent = compta.mois
		compta.mois = {}
		compta.jours = 0


## Dépense de la ville (réparations…) : par le Budget communal s'il existe.
func depenser(poste: String, v: float) -> void:
	if v <= 0.0:
		return
	_book(poste, -v)
	if buildings == null or buildings.unlimited_money:
		return
	var bc = _classe("BudgetCommunal")
	var inst = bc.get("instance") if bc != null else null
	if inst != null and is_instance_valid(inst) and inst.has_method("depense"):
		inst.call("depense", poste, v)
	else:
		buildings.money -= roundi(v)


## Pour les tempêtes et les crues d'autres systèmes : casse les lignes à moins de
## `rayon` m de `pos` (les conduites aussi pour une crue). Renvoie le nombre de tronçons cassés.
func endommager(pos: Vector3, rayon: float, cause := "tempete") -> int:
	return incidents.endommager(pos, rayon, cause)


func _book(poste: String, v: float) -> void:
	var m: Dictionary = compta.mois
	m[poste] = float(m.get(poste, 0.0)) + v


## Factures et frais de la ville pour une fraction de jour.
func _facturer(jours: float) -> void:
	var mult := ReglagesPartie.actuel.prix_services
	var recette := 0.0
	var recette_gaz := 0.0
	for bid in elec.consos:
		if buildings == null or not buildings.buildings.has(bid):
			continue
		var s: Dictionary = etat.get(bid, {"e": 1.0, "o": 1.0, "g": 1.0})
		var kwh := float(elec.consos[bid].d) * 1000.0 * 24.0 * jours * float(s.e)
		var m3 := float(eau.consos.get(bid, {}).get("d", 0.0)) * jours * float(s.o)
		var eu := float(egout.consos.get(bid, {}).get("d", 0.0)) * jours * float(s.g)
		var kwh_gaz := float(gaz.consos.get(bid, {}).get("d", 0.0)) * 1000.0 * 24.0 * jours * float(s.get("c", 1.0))
		recette_gaz += kwh_gaz * PRIX_KWH_GAZ * mult
		var cout := (kwh * PRIX_KWH + m3 * PRIX_M3_EAU + eu * PRIX_M3_ASSAINISSEMENT + kwh_gaz * PRIX_KWH_GAZ) * mult
		if cout <= 0.0:
			continue
		recette += cout
		if population != null and population.by_home.has(bid) and not (population.by_home[bid] as Array).is_empty():
			var hids: Array = population.by_home[bid]
			for hid in hids:
				if population.households.has(hid):
					population.households[hid].ep = float(population.households[hid].ep) - cout / hids.size()
		elif production != null and production.sites.has(bid):
			production._pay(bid, "Eau et électricité", -cout)
	_book("Factures d'eau et d'électricité", recette - recette_gaz)
	if recette_gaz > 0.0:
		_book("Factures de gaz et de chauffage", recette_gaz)
	var frais := 0.0
	# Courant acheté au réseau national, combustible des grandes centrales sous contrat.
	for bid in elec.sources:
		var info := ReseauxTypes.info(_type(bid))
		var prix := PRIX_KWH_IMPORT if String(info.get("source", "")) == "national" else float(info.get("achat", 0.0))
		if prix <= 0.0:
			continue
		var c := elec.composante_de(bid)
		var k: Dictionary = elec.composantes.get(c, {})
		if k.is_empty() or float(k.prod) <= 0.0:
			continue
		var mw := minf(float(k.dem), float(k.prod)) * float(elec.sources[bid].cap) / float(k.prod)
		var v := mw * 1000.0 * 24.0 * jours * prix
		if v <= 0.0:
			continue
		frais += v
		_book("Courant acheté au réseau national" if String(info.get("source", "")) == "national" else "Combustible des grandes centrales", -v)
	# Gaz acheté au gazoduc.
	for bid in gaz.sources:
		if String(ReseauxTypes.info(_type(bid)).get("source", "")) != "gaz_import":
			continue
		var c := gaz.composante_de(bid)
		var k: Dictionary = gaz.composantes.get(c, {})
		if k.is_empty() or float(k.prod) <= 0.0:
			continue
		var mw := minf(float(k.dem), float(k.prod)) * float(gaz.sources[bid].cap) / float(k.prod)
		var v := mw * 1000.0 * 24.0 * jours * PRIX_KWH_GAZ_IMPORT
		if v > 0.0:
			frais += v
			_book("Gaz acheté au gazoduc", -v)
	# Centrales et chaufferies au combustible : la ville couvre leurs pertes (combustible, salaires).
	if production != null:
		for bid in elec.sources.keys() + gaz.sources.keys():
			if production.sites.has(bid) and float(production.sites[bid].cash) < 0.0:
				var v := -float(production.sites[bid].cash)
				production.sites[bid].cash = 0.0
				frais += v
				_book("Combustible et salaires des centrales", -v)
	if not _budget_present():
		var ent := 0.0
		for k in budget_entretien().values():
			ent += float(k)
		ent *= jours / 30.0
		frais += ent
		_book("Entretien des réseaux", -ent)
	if buildings != null and not buildings.unlimited_money:
		_money_frac += recette - frais
		var whole := int(_money_frac)
		_money_frac -= whole
		buildings.money += whole


# --- Bilans pour le panneau ----------------------------------------------------------------

func bilan(res: String) -> Dictionary:
	var r := reseau(res)
	var b := r.bilan()
	var coupes := 0
	var partiels := 0
	var k: String = CLE[res]
	for bid in r.consos:
		var t := float(etat.get(bid, {}).get(k, 1.0))
		if t < 0.5:
			coupes += 1
		elif t < 0.95:
			partiels += 1
	b["coupes"] = coupes
	b["partiels"] = partiels
	b["batiments"] = r.consos.size()
	var lin := 0.0
	for id in r.troncons:
		lin += ReseauBase.longueur(r.troncons[id].pts)
	b["lineaire"] = lin
	var nom := 0.0
	for bid in r.sources:
		nom += float(sources_info.get(bid, {}).get("max", 0.0))
	b["nominal"] = nom
	if res == "eau" or res == "elec":
		var st := 0.0
		var stm := 0.0
		for bid in stocks:
			if String(ReseauxTypes.info(_type(bid)).get("res", "")) != res:
				continue
			st += float(stocks[bid])
			stm += float(ReseauxTypes.info(_type(bid)).get("stock", 0.0))
		b["stock"] = st
		b["stock_max"] = stm
	if res == "egout":
		var rj := 0.0
		for c in rejets:
			rj += float(rejets[c])
		b["rejets"] = rj
	if res == "gaz":
		var froid := 0
		for bid in etat:
			if besoin > 0.3 and float(etat[bid].get("ch", 1.0)) < 0.5:
				froid += 1
		b["froid"] = froid
		b["temperature"] = temperature
		b["besoin"] = besoin
	b["incidents"] = incidents.de_reseau(res).size()
	return b


func summary() -> String:
	var e := bilan("elec")
	var o := bilan("eau")
	return "Courant %s / %s MW · Eau %s / %s m³/j" % [_fmt(e.production), _fmt(e.demande), _fmt(o.production), _fmt(o.demande)]


static func _fmt(v: float) -> String:
	if v >= 100.0:
		return str(roundi(v))
	if v >= 10.0:
		return String.num(v, 1).replace(".", ",")
	return String.num(v, 2).replace(".", ",")


func _type(bid: int) -> String:
	if buildings == null:
		return ""
	return String(buildings.buildings.get(bid, {}).get("t", ""))


# --- Calques (panneau commun « Cartes », s'il est là) --------------------------------------------

func _inscrire_calques() -> void:
	var cl = _classe("Calques")
	if cl == null or not cl.has_method("ajouter"):
		return
	for res in RES:
		var r: String = res
		cl.call("ajouter", "reseau_" + r, ReseauxTypes.RES_NAMES[r], "Réseaux",
			func(on: bool) -> void:
				if vue:
					vue.set_calque(r, on),
			"Vert : desservi · orange : rationné · rouge : coupé" if r != "gaz" else "Vert : chauffé par le réseau · orange : en partie · rouge : à l'électricité ou au froid")


# --- Outil de pose ----------------------------------------------------------------------

func set_outil(o: Outil, type_id := "") -> void:
	outil = o
	if type_id != "":
		type_troncon = type_id
	_trace = PackedVector3Array()
	if vue:
		vue.fantome(PackedVector3Array(), Color.WHITE)
		if o == Outil.TRACER:
			vue.set_calque(String(ReseauxTypes.troncon(type_troncon).res), true)
	_aide()


func set_inactive() -> void:
	set_outil(Outil.AUCUN)


func _aide() -> void:
	match outil:
		Outil.TRACER:
			var tr := ReseauxTypes.troncon(type_troncon)
			var t := "%s : clic pour chaque point, clic droit ou Échap pour finir. %s / m." % [tr.name, BuildingSystem.format_money(ReglagesPartie.prix(int(tr.prix_m)))]
			if _trace.size() > 0 and _curseur.is_finite():
				var l := _trace[_trace.size() - 1].distance_to(_curseur)
				t += "  Tronçon : %d m, %s." % [roundi(l), BuildingSystem.format_money(ReseauxTypes.prix_troncon(type_troncon, l))]
			info_changed.emit(t)
		Outil.GOMME:
			info_changed.emit("Clic sur une ligne, une conduite ou un égout pour le retirer (30 % rendus).")
		_:
			info_changed.emit("")


## Calage d'un point : extrémité d'un tronçon proche, centre d'un bâtiment des réseaux.
## Onglet d'un autre système dans le panneau Réseaux (O), par exemple Télécom.
func ajouter_onglet(titre: String, control: Control) -> void:
	if panneau != null and panneau.has_method("ajouter_onglet"):
		panneau.ajouter_onglet(titre, control)


func caler(p: Vector3) -> Vector3:
	var res := String(ReseauxTypes.troncon(type_troncon).get("res", "elec"))
	var r := reseau(res)
	var best := p
	var bd := 12.0
	for id in r.troncons:
		var pts: PackedVector3Array = r.troncons[id].pts
		for q in [pts[0], pts[pts.size() - 1]]:
			var d := Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z))
			if d < bd:
				bd = d
				best = q
	for bid in r.sources:
		var q: Vector3 = r.sources[bid].p
		var d := Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z))
		if d < maxf(bd, float(r.sources[bid].get("x", 0.0))):
			bd = d
			best = Vector3(q.x, _hauteur(q), q.z)
	if bd >= 12.0 and r.suit_routes:
		# Sinon, le bord de route le plus proche (la desserte locale).
		var p2 := Vector2(p.x, p.z)
		var bd2 := 8.0
		for pts in _routes():
			for i in range((pts as PackedVector3Array).size() - 1):
				var a2 := Vector2(pts[i].x, pts[i].z)
				var b2 := Vector2(pts[i + 1].x, pts[i + 1].z)
				var q2 := Geometry2D.get_closest_point_to_segment(p2, a2, b2)
				var d := p2.distance_to(q2)
				if d < bd2:
					bd2 = d
					best = Vector3(q2.x, _hauteur(Vector3(q2.x, 0, q2.y)), q2.y)
	return best


## Tracé calé sur le relief entre deux points (un point tous les 10 m).
func trace_sur_relief(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var l := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var n := maxi(1, ceili(l / 10.0))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		p.y = _hauteur(p)
		out.append(p)
	return out


func _pick(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null or world == null:
		return null
	return world.pick_point(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


func _unhandled_input(event: InputEvent) -> void:
	if outil == Outil.AUCUN:
		return
	var mm := event as InputEventMouseMotion
	if mm:
		var hit = _pick(mm.position)
		if hit != null:
			_curseur = caler(hit) if outil == Outil.TRACER else hit
			if outil == Outil.TRACER and _trace.size() > 0 and vue:
				var col: Color = ReseauxTypes.COULEURS[String(ReseauxTypes.troncon(type_troncon).res)]
				vue.fantome(trace_sur_relief(_trace[_trace.size() - 1], _curseur), col)
			_aide()
		return
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_press = mb.position
			elif mb.position.distance_to(_press) < 6.0:
				if outil == Outil.TRACER and _trace.size() > 0:
					_trace = PackedVector3Array()
					if vue:
						vue.fantome(PackedVector3Array(), Color.WHITE)
					_aide()
				else:
					set_outil(Outil.AUCUN)
				get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		var hit = _pick(mb.position)
		if hit == null:
			return
		get_viewport().set_input_as_handled()
		if outil == Outil.GOMME:
			var t := troncon_pres(hit, 8.0)
			if not t.is_empty():
				retirer(String(t.res), int(t.id))
			return
		var p := caler(hit)
		if _trace.size() > 0:
			var a := _trace[_trace.size() - 1]
			if Vector2(a.x, a.z).distance_to(Vector2(p.x, p.z)) < 2.0:
				return
			if poser(type_troncon, trace_sur_relief(a, p)) < 0:
				return
		_trace = PackedVector3Array([p])
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		if _trace.size() > 0:
			_trace = PackedVector3Array()
			if vue:
				vue.fantome(PackedVector3Array(), Color.WHITE)
		else:
			set_outil(Outil.AUCUN)
		get_viewport().set_input_as_handled()


# --- Sauvegarde --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var st := {}
	for bid in stocks:
		st[str(bid)] = snappedf(float(stocks[bid]), 0.1)
	var mq := {}
	for bid in manque:
		mq[str(bid)] = manque[bid]
	return {"version": 1, "elec": elec.to_dict(), "eau": eau.to_dict(), "egout": egout.to_dict(),
		"gaz": gaz.to_dict(), "incidents": incidents.to_dict(),
		"stocks": st, "manque": mq, "compta": compta, "heures": snappedf(_heures_jour, 0.01)}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	elec.from_dict(d.get("elec", {}))
	eau.from_dict(d.get("eau", {}))
	egout.from_dict(d.get("egout", {}))
	gaz.from_dict(d.get("gaz", {}))
	incidents.from_dict(d.get("incidents", {}))
	for k in d.get("stocks", {}):
		stocks[int(k)] = float(d.stocks[k])
	for k in d.get("manque", {}):
		manque[int(k)] = d.manque[k]
	var c: Dictionary = d.get("compta", {})
	if not c.is_empty():
		compta = {"mois": c.get("mois", {}), "precedent": c.get("precedent", {}), "jours": int(c.get("jours", 0))}
	_heures_jour = float(d.get("heures", 0.0))
	# Chantiers en cours : ils reprennent où ils en étaient.
	for res in RES:
		var r := reseau(res)
		for id in r.troncons:
			if not bool(r.troncons[id].ok):
				_lancer_chantier(res, id)
	if vue:
		vue.tout_refaire()
	_sync_sale = true
	_topo_sale = true
	changed.emit()
