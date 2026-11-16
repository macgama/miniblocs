class_name Climat
extends Node
## Climat et pollution à long terme (panneau Maj+F7, menu Infos).
##
## - Bilan carbone : chaque heure de jeu, le CO₂ des villes est compté par secteur
##   (électricité selon le vrai mix des centrales, chauffage, voitures et camions
##   d'après le trafic, industries, élevages et champs, décharges) moins ce que
##   les forêts et les parcs absorbent. Totaux du jour, de chaque année d'histoire,
##   et depuis le début de la partie.
## - Réchauffement : l'écart de température mondial suit l'histoire réelle
##   (de −0,3 °C en 1815 à +1,45 °C en 2026), puis un scénario du GIEC (sobre,
##   médian, fossile). Par défaut, le monde suit l'exemple des villes du joueur :
##   leurs émissions par habitant poussent la courbe. Il décale la météo du jeu
##   (Meteo.ecart_climat : canicules plus fréquentes, sécheresses, grosses pluies),
##   rend les catastrophes plus fréquentes et fait monter la mer (submersions
##   des bâtiments trop bas pendant les tempêtes). Îlot de chaleur des grandes
##   villes peu arborées en plus.
## - Sols pollués : grille de cases de 40 m qui garde la mémoire des pollutions
##   (usines, mines, décharges, pesticides) pendant des années. Ils rendent un
##   peu malades les habitants (Nuisances.sante), font baisser les récoltes
##   (Agriculture.rendement) et la valeur des terrains (« saleté » dans Nuisances).
## - Transition énergétique : le mix électrique, l'intensité du réseau national
##   (selon l'époque et le pays) et les mesures du plan climat, datées (filtres
##   en 1910, isolation en 1974, pot catalytique en 1993, ZFE en 2015…), qui
##   agissent aussi sur la pollution de l'air et de l'eau (Nuisances).
## Section de sauvegarde "climat".

signal changed
signal message(text: String)

static var instance: Climat

const JOURS_GARDES := 60
const ANNEES_GARDEES := 400
## Hauteur d'eau d'une tempête au bord de la mer (m), en plus de la marée.
const SURCOTE := 1.0

var world: TerrainWorld
var buildings: BuildingSystem
var transport: TransportSystem
var population: Population
var ambiance: DayNight
var reseaux: Reseaux
var agriculture: Agriculture
var evenements: Evenements

# --- État ----------------------------------------------------------------------------------

## Écart de température mondial (°C, par rapport à 1850-1900).
var ecart_monde := NAN
## Niveau de la mer (cm au-dessus de 1900).
var mer_cm := NAN
## Année d'histoire (avec sa fraction) du dernier calcul.
var annee_f := NAN
## Émissions par habitant et par an (t CO₂), lissées sur quelques années.
var intensite := NAN
## Scénario suivi après 2026 (0 sobre, 1 médian, 2 fossile).
var scenario_s := 1.0
## Îlot de chaleur urbain (°C) et décalage total de la météo (°C).
var ilot := 0.0
var ecart_local := 0.0
## Secteur → t CO₂ depuis minuit ; filière → MWh.
var aujourdhui: Dictionary = {}
var mix_aujourdhui: Dictionary = {}
## Derniers jours : [{"j", "t": {secteur: t}, "mix": {filière: MWh}}].
var jours: Array = []
## Années d'histoire : "1900" → {"t": {secteur: t}, "mix": {}, "jours": n, "pop": n, "ecart": °C, "mer": cm}.
var annees: Dictionary = {}
## t CO₂ nettes depuis le début de la partie.
var cumul := 0.0
## Mesures adoptées : id → année d'adoption.
var mesures: Dictionary = {}
## Grandes dates déjà annoncées, seuils de réchauffement franchis.
var annonces: Dictionary = {}
## Sols : case (SOL_CELL m) → pollution 0..1.
var sols: Dictionary = {}
var forets_ha := 0.0
var parcs_ha := 0.0
## Bâtiments trop bas face à la mer qui monte.
var menaces: Array = []
var submersions := 0
## Heure du dernier calcul (tests) et forçages.
var clock := NAN

var _last_unix := NAN
var _acc_h := 0.0
var _jour := -1
var _jours_releve := 0
var _derniere_submersion := -1e12
var _longueurs: Dictionary = {}
var _types: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _money_frac := 0.0


func _init() -> void:
	name = "Climat"
	_rng.randomize()


func _enter_tree() -> void:
	instance = self
	add_to_group("avis_sources")
	add_to_group("budget_entretien")
	add_to_group("budget_recettes")
	add_to_group("pollution_sources")


func _exit_tree() -> void:
	if instance == self:
		instance = null
		Meteo.ecart_climat = 0.0


func setup(w: TerrainWorld, b: BuildingSystem, t: TransportSystem, p: Population, a: DayNight, r: Reseaux, agri: Agriculture, ev: Evenements) -> void:
	world = w
	buildings = b
	transport = t
	population = p
	ambiance = a
	reseaux = r
	agriculture = agri
	evenements = ev


func clear() -> void:
	ecart_monde = NAN
	mer_cm = NAN
	annee_f = NAN
	intensite = NAN
	scenario_s = 1.0
	ilot = 0.0
	ecart_local = 0.0
	aujourdhui = {}
	mix_aujourdhui = {}
	jours.clear()
	annees.clear()
	cumul = 0.0
	mesures.clear()
	annonces.clear()
	sols.clear()
	forets_ha = 0.0
	parcs_ha = 0.0
	menaces.clear()
	submersions = 0
	_last_unix = NAN
	_acc_h = 0.0
	_jour = -1
	_jours_releve = 0
	Meteo.ecart_climat = 0.0


static func reglage() -> int:
	return clampi(ReglagesPartie.actuel.climat, 0, ClimatTypes.REGLAGES.size() - 1)


func now() -> float:
	if not is_nan(clock):
		return clock
	return ambiance.unix_time if ambiance != null else 0.0


## Année d'histoire en cours, avec sa fraction.
static func annee_en_cours() -> float:
	var r := ReglagesPartie.actuel
	var y := Epoques.annee(r)
	var u := Epoques._unix()
	if Epoques.actif(r):
		if is_nan(u) or r.histoire_debut == 0.0:
			return float(y)
		var ecoule := maxf(0.0, u - r.histoire_debut) / Epoques.SECONDES_AN * r.rythme_histoire
		return float(r.annee_depart + r.histoire_saut) + ecoule
	if is_nan(u):
		return float(y)
	var debut := Time.get_unix_time_from_datetime_dict({"year": y, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	return float(y) + clampf((u - debut) / Epoques.SECONDES_AN, 0.0, 0.999)


# --- Boucle ----------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if ambiance == null:
		return
	var t := now()
	if is_nan(_last_unix) or t < _last_unix - 1.0:
		_last_unix = t
		_jour = floori(t / 86400.0)
		if is_nan(ecart_monde):
			_initialiser(annee_en_cours())
		return
	var dt := clampf(t - _last_unix, 0.0, 12.0 * 3600.0)
	_last_unix = t
	advance(dt, t)


## Fait avancer le climat de dt secondes de jeu (t : instant atteint).
func advance(dt: float, t: float) -> void:
	_acc_h += dt
	var n := 0
	while _acc_h >= 3600.0 and n < 12:
		_acc_h -= 3600.0
		n += 1
		heure()
		var j := floori((t - _acc_h) / 86400.0)
		if _jour < 0:
			_jour = j
		if j != _jour:
			_jour = j
			nouveau_jour()
	if n >= 12:
		_acc_h = 0.0


## Une journée complète d'un coup (tests, avance rapide).
func simuler_jour() -> void:
	for i in 24:
		heure()
	nouveau_jour()


# --- Bilan carbone ----------------------------------------------------------------------------

## Une heure de jeu : CO₂ de chaque secteur.
func heure() -> void:
	var y := annee_en_cours()
	if is_nan(ecart_monde):
		_initialiser(y)
	var e := emissions_heure(y)
	for k in e.t:
		aujourdhui[k] = float(aujourdhui.get(k, 0.0)) + float(e.t[k])
	for f in e.mix:
		mix_aujourdhui[f] = float(mix_aujourdhui.get(f, 0.0)) + float(e.mix[f])


## {"t": {secteur: t CO₂}, "mix": {filière: MWh}} pour une heure.
func emissions_heure(y: float) -> Dictionary:
	var t := {}
	var mix := {}
	_electricite(y, t, mix)
	_chauffage(y, t)
	_transport(y, t)
	_batiments(y, t)
	t["absorption"] = -absorption_an() / 365.0 / 24.0
	return {"t": t, "mix": mix}


func _electricite(y: float, t: Dictionary, mix: Dictionary) -> void:
	if reseaux == null:
		return
	var el := reseaux.elec
	var co2 := 0.0
	for bid in el.sources:
		var f := ClimatTypes.filiere(reseaux._type(bid))
		if f == "":
			continue
		var cap := float(el.sources[bid].cap)
		var k: Dictionary = el.composantes.get(el.composante_de(bid), {})
		if cap <= 0.0 or k.is_empty() or float(k.prod) <= 0.0:
			continue
		var mwh := cap * clampf(float(k.dem) / float(k.prod), 0.0, 1.0)
		mix[f] = float(mix.get(f, 0.0)) + mwh
		co2 += mwh * ClimatTypes.intensite_filiere(f, y, GameStart.pays, scenario_s)
	# Réseaux non obligatoires : le courant que la ville ne produit pas vient du pays.
	if not ReglagesPartie.actuel.reseaux_obligatoires and y >= 1882.0:
		var manque := 0.0
		for bid in el.consos:
			manque += float(el.consos[bid].d) * (1.0 - el.taux_servi(bid))
		if manque > 0.0:
			mix["national"] = float(mix.get("national", 0.0)) + manque
			co2 += manque * ClimatTypes.intensite_nationale(y, GameStart.pays, scenario_s)
	if a("toits_solaires"):
		co2 *= 0.85
	t["electricite"] = co2


func _chauffage(y: float, t: Dictionary) -> void:
	if population == null:
		return
	var temp := reseaux.temperature if reseaux != null else 12.0
	var besoin := Reseaux.besoin_chauffage(temp)
	var chaleur := float(population.households.size()) * ClimatTypes.CHAUFFAGE_FOYER * besoin
	if a("isolation"):
		chaleur *= 0.75
	var gaz := 0.0
	if reseaux != null:
		for bid in reseaux.gaz.consos:
			gaz += float(reseaux.gaz.consos[bid].d) * reseaux.gaz.taux_servi(bid)
	gaz = minf(gaz, chaleur)
	t["chauffage"] = gaz * ClimatTypes.GAZ_CO2 + (chaleur - gaz) * ClimatTypes.courbe(ClimatTypes.CHAUFFAGE, y)


func _transport(y: float, t: Dictionary) -> void:
	if transport == null:
		return
	var kg := ClimatTypes.courbe(ClimatTypes.VOITURE, y)
	var co2 := 0.0
	var tr = transport.traffic
	if kg > 0.0 and tr != null and tr.has_method("flux_all"):
		var flux: Dictionary = tr.flux_all()
		var lourds := tr.has_method("flux_lourds")
		for eid in flux:
			var f := float(flux[eid])
			if f <= 0.0:
				continue
			var lv := float(tr.flux_lourds(eid)) if lourds else 0.0
			co2 += ((f - lv) + lv * ClimatTypes.LOURD) * _longueur_km(int(eid)) * kg / 1000.0
	if a("transports_doux"):
		co2 *= 0.85
	if a("zfe"):
		co2 *= 0.85
	if transport.stations != null:
		for sid in transport.stations.stations:
			var ty := String(transport.stations.stations[sid].type)
			if ClimatTypes.STATIONS.has(ty) and (ty == "port" or y >= 1919.0):
				co2 += float(ClimatTypes.STATIONS[ty]) / 24.0
	t["transport"] = co2


func _longueur_km(eid: int) -> float:
	var net := transport.network
	if not net.edges.has(eid):
		return 0.0
	var pts: PackedVector3Array = net.edges[eid].pts
	var c: Array = _longueurs.get(eid, [])
	if c.size() == 2 and int(c[0]) == pts.size():
		return float(c[1])
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	_longueurs[eid] = [pts.size(), l / 1000.0]
	return l / 1000.0


## Ce que chaque type de bâtiment émet (gardé en cache).
func _info_type(tid: String) -> Dictionary:
	if _types.has(tid):
		return _types[tid]
	var ty := BuildingCatalog.get_type(tid)
	var id := tid.to_lower()
	var info := {"ind": ClimatTypes.intensite_industrie(tid), "elev": ClimatTypes.est_elevage(tid),
		"decharge": id.contains("decharge"), "emplois": maxi(1, int(ty.get("emplois", 10))),
		"famille": ClimatTypes.famille(tid),
		"parc": String(ty.get("cat", "")) == "espaces" or id.contains("parc") or id.contains("jardin") or id.contains("square")}
	_types[tid] = info
	return info


func _batiments(_y: float, t: Dictionary) -> void:
	if buildings == null:
		return
	var ind := 0.0
	var agri := 0.0
	var dech := 0.0
	for bid in buildings.buildings:
		if buildings.en_chantier(bid):
			continue
		var info := _info_type(String(buildings.buildings[bid].t))
		if float(info.ind) > 0.0:
			var emp := int(info.emplois)
			var st := 1.0
			if population != null:
				st = clampf(float((population.by_job.get(bid, []) as Array).size()) / emp, 0.0, 1.0)
			ind += float(info.ind) * emp * st / 24.0
		elif bool(info.elev):
			agri += ClimatTypes.ELEVAGE_CO2 / 24.0
		if bool(info.decharge):
			dech += ClimatTypes.DECHARGE_CO2 / 24.0
	if a("taxe_carbone"):
		ind *= 0.85
	if a("captage_co2"):
		ind *= 0.4
	if agriculture != null:
		for id in agriculture.champs:
			var ch: Dictionary = agriculture.champs[id]
			if bool(ch.get("eng", false)) and String(ch.get("etat", "friche")) != "friche":
				agri += Agriculture.surface(ch) * ClimatTypes.CHAMP_CO2 / 24.0 * (0.7 if a("normes_agricoles") else 1.0)
	t["industrie"] = ind
	t["agriculture"] = agri
	t["dechets"] = dech


## t CO₂ absorbées par an par les forêts et les parcs.
func absorption_an() -> float:
	var v := forets_ha * ClimatTypes.FORET_T_HA + parcs_ha * ClimatTypes.PARC_T_HA
	if a("vegetaliser"):
		v += float(population.persons.size()) * 0.02 if population != null else 0.0
	return v


static func total(t: Dictionary) -> float:
	var s := 0.0
	for k in t:
		s += float(t[k])
	return s


# --- Un jour -----------------------------------------------------------------------------------

func nouveau_jour() -> void:
	var y := annee_en_cours()
	if is_nan(ecart_monde):
		_initialiser(y)
	_jours_releve += 1
	if _jours_releve == 1 or _jours_releve % 30 == 0:
		_releve_vert()
		_releve_menaces()
	# Bilan du jour.
	var tot := total(aujourdhui)
	jours.append({"j": _jour, "t": aujourdhui.duplicate(), "mix": mix_aujourdhui.duplicate()})
	if jours.size() > JOURS_GARDES:
		jours.pop_front()
	var cle := str(floori(y))
	var an: Dictionary = annees.get(cle, {"t": {}, "mix": {}, "jours": 0})
	for k in aujourdhui:
		an.t[k] = float(an.t.get(k, 0.0)) + float(aujourdhui[k])
	for f in mix_aujourdhui:
		an.mix[f] = float(an.mix.get(f, 0.0)) + float(mix_aujourdhui[f])
	an.jours = int(an.jours) + 1
	an.pop = population.persons.size() if population != null else 0
	annees[cle] = an
	_tailler_annees()
	cumul += tot
	aujourdhui = {}
	mix_aujourdhui = {}
	# Émissions par habitant, lissées.
	var pop := population.persons.size() if population != null else 0
	var ref := ClimatTypes.courbe(ClimatTypes.INTENSITE_EPOQUE, y)
	var mesure_j := tot * 365.0 / maxf(float(pop), 1.0) if pop > 0 else ref
	var poids := clampf(float(pop) / 500.0, 0.0, 1.0)
	var vise := lerpf(ref, maxf(mesure_j, 0.0), poids)
	if is_nan(intensite):
		intensite = vise
	else:
		var dy := maxf(y - annee_f, 1.0 / 365.0) if not is_nan(annee_f) else 1.0 / 365.0
		intensite = lerpf(intensite, vise, clampf(dy / 3.0 + 0.01, 0.0, 1.0))
	scenario_s = ClimatTypes.scenario_de(intensite)
	avancer_climat(y)
	an.ecart = snappedf(ecart_monde, 0.001)
	an.mer = snappedf(mer_cm, 0.1)
	_maj_meteo()
	_sols_jour(y)
	_annonces(y)
	_submersion()
	changed.emit()


func _tailler_annees() -> void:
	if annees.size() <= ANNEES_GARDEES:
		return
	var cles := annees.keys()
	cles.sort_custom(func(p, q) -> bool: return int(p) < int(q))
	for i in cles.size() - ANNEES_GARDEES:
		annees.erase(cles[i])


func _initialiser(y: float) -> void:
	annee_f = y
	if y <= ClimatTypes.ANNEE_PRESENT:
		ecart_monde = ClimatTypes.histoire(y)
		mer_cm = ClimatTypes.mer_histoire(y)
	else:
		ecart_monde = ClimatTypes.scenario(y, 1.0)
		mer_cm = ClimatTypes.mer_histoire(ClimatTypes.ANNEE_PRESENT)
		var yy := float(ClimatTypes.ANNEE_PRESENT)
		while yy < y:
			mer_cm += ClimatTypes.montee_mer(ClimatTypes.scenario(yy, 1.0))
			yy += 1.0
	# Une partie qui commence au début de l'histoire a déjà franchi les dates passées.
	for h in ClimatTypes.HISTOIRE_CLIMAT:
		if float(h[0]) <= y:
			annonces["h%d" % int(h[0])] = true
	for s in [1.0, 1.5, 2.0, 3.0]:
		if ecart_monde >= s:
			annonces["s%s" % str(s)] = true
	_maj_meteo()


## Écart mondial visé pour une année.
func cible(y: float) -> float:
	match reglage():
		0:
			return ecart_monde
		1:
			return ClimatTypes.histoire(y) if y <= ClimatTypes.ANNEE_PRESENT else ClimatTypes.scenario(y, 1.0)
	if y <= ClimatTypes.ANNEE_PRESENT:
		var ref := ClimatTypes.courbe(ClimatTypes.INTENSITE_EPOQUE, y)
		var f := 1.0 if is_nan(intensite) else clampf(sqrt(maxf(intensite, 0.0) / maxf(ref, 0.1)), 0.6, 1.5)
		return ClimatTypes.histoire(y) * f if ClimatTypes.histoire(y) > 0.0 else ClimatTypes.histoire(y)
	return ClimatTypes.scenario(y, scenario_s)


## Fait avancer la température et la mer jusqu'à l'année y (avec sa fraction).
func avancer_climat(y: float) -> void:
	if is_nan(annee_f) or is_nan(ecart_monde):
		_initialiser(y)
		return
	var dy := y - annee_f
	if dy < -0.5:
		# L'admin est revenu en arrière dans l'histoire : on repart de là.
		_initialiser(y)
		return
	if dy <= 0.0:
		return
	var pas := clampi(ceili(dy), 1, 300)
	var h := minf(dy, 300.0) / pas
	var y0 := annee_f
	for i in pas:
		var yi := y0 + h * (i + 1)
		ecart_monde += (cible(yi) - ecart_monde) * (1.0 - exp(-h / ClimatTypes.INERTIE))
		mer_cm += ClimatTypes.montee_mer(ecart_monde) * h
	annee_f = y
	_maj_meteo()


## Décale la météo : réchauffement des terres + îlot de chaleur.
func _maj_meteo() -> void:
	var mode := reglage()
	var pop := float(population.persons.size()) if population != null else 0.0
	var dens := pow(clampf(pop / 40000.0, 0.0, 1.0), 0.7)
	var bati := float(buildings.buildings.size()) * 0.08 if buildings != null else 1.0
	var vert := (parcs_ha + forets_ha * 0.15) / maxf(bati, 1.0)
	ilot = 2.5 * dens * (1.0 - clampf(vert * 2.0, 0.0, 0.6))
	if a("vegetaliser"):
		ilot *= 0.5
	if mode == 0:
		ecart_local = 0.0
	else:
		ecart_local = (ecart_monde - ClimatTypes.ECART_REFERENCE) * ClimatTypes.FACTEUR_TERRES * (2.0 if mode == 3 else 1.0) + ilot
	Meteo.ecart_climat = ecart_local


## Plus de canicules, de sécheresses, de crues et de feux quand il fait plus chaud.
static func facteur_extremes() -> float:
	if instance == null:
		return 1.0
	return 1.0 + 0.15 * maxf(instance.ecart_local - instance.ilot, 0.0)


## Hausse de la mer par rapport aux côtes d'aujourd'hui (m).
func hausse_mer_m() -> float:
	if is_nan(mer_cm):
		return 0.0
	return (mer_cm - ClimatTypes.mer_histoire(ClimatTypes.ANNEE_PRESENT)) / 100.0


# --- Forêts, parcs, mer ------------------------------------------------------------------------

func _releve_vert() -> void:
	parcs_ha = 0.0
	if buildings == null:
		return
	var bmin := Vector2(INF, INF)
	var bmax := Vector2(-INF, -INF)
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var r := buildings._rect_of(b)
		bmin = bmin.min(Vector2(r.position))
		bmax = bmax.max(Vector2(r.end))
		if bool(_info_type(String(b.t)).parc):
			parcs_ha += float(r.size.x * r.size.y) / 10000.0
	forets_ha = 0.0
	if world == null or bmin.x == INF:
		return
	bmin -= Vector2(1000, 1000)
	bmax += Vector2(1000, 1000)
	var pas := maxf(200.0, maxf(bmax.x - bmin.x, bmax.y - bmin.y) / 60.0)
	var x := bmin.x
	while x <= bmax.x:
		var z := bmin.y
		while z <= bmax.y:
			if world.cell_biome(Vector2i(floori(x), floori(z))) == 10:
				forets_ha += pas * pas / 10000.0
			z += pas
		x += pas


func _releve_menaces() -> void:
	menaces.clear()
	if world == null or buildings == null:
		return
	var seuil := TerrainWorld.WATER_LEVEL + hausse_mer_m() + SURCOTE + Maree.max_level(world.origin_lat, world.origin_lon)
	for bid in buildings.buildings:
		var c := BuildingSystem.rect_center(buildings._rect_of(buildings.buildings[bid]))
		var h := world.raw_height(c.x, c.z)
		if not is_nan(h) and h > TerrainWorld.WATER_LEVEL and h < seuil:
			menaces.append(bid)


func _submersion() -> void:
	if menaces.is_empty() or evenements == null or not evenements.catastrophes_on() or reglage() == 0:
		return
	var w: Meteo = ambiance.weather if ambiance != null else null
	if w == null or w.storm < 0.6 or now() - _derniere_submersion < 20.0 * 86400.0:
		return
	var p := 0.15 * evenements.frequence() * (1.0 + 3.0 * maxf(hausse_mer_m(), 0.0))
	if _rng.randf() >= p:
		return
	submerger()


## Une tempête pousse la mer sur les bâtiments trop bas (renvoie leur nombre).
func submerger() -> int:
	_derniere_submersion = now()
	var n := 0
	var centre := Vector3.INF
	for bid in menaces:
		if n >= 40:
			break
		if evenements == null or not buildings.buildings.has(bid):
			continue
		var d := float(evenements.degats.get(bid, {}).get("d", 0.0))
		evenements.set_degats(bid, minf(0.9, d + _rng.randf_range(0.2, 0.45)), "inondation")
		if centre == Vector3.INF:
			centre = evenements.building_pos(bid)
		n += 1
	if n > 0:
		submersions += 1
		_news("Submersion marine : la tempête pousse la mer dans les rues basses, %d bâtiment%s les pieds dans l'eau. La mer est %s plus haute qu'en 1900." % [n, "s" if n > 1 else "", _cm(mer_cm)],
			"submersion", centre)
	return n


# --- Sols pollués -----------------------------------------------------------------------------

static func cle_sol(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / ClimatTypes.SOL_CELL), floori(z / ClimatTypes.SOL_CELL))


## Pollution du sol au point (0..1).
func sol_at(x: float, z: float) -> float:
	return float(sols.get(cle_sol(x, z), 0.0))


## Pollution moyenne du sol sur un rectangle de cases (1 m).
func sol_rect(r: Rect2i) -> float:
	if sols.is_empty():
		return 0.0
	var s := 0.0
	var n := 0
	for i in 3:
		for j in 3:
			s += sol_at(r.position.x + r.size.x * (i + 0.5) / 3.0, r.position.y + r.size.y * (j + 0.5) / 3.0)
			n += 1
	return s / n


## Récoltes d'un champ : un sol pollué donne moins (et les normes coûtent 5 %).
func facteur_champ(ch: Dictionary) -> float:
	var f := 1.0
	if ch.has("r"):
		f -= 0.5 * sol_rect(ch.r)
	if a("normes_agricoles"):
		f *= 0.95
	return clampf(f, 0.3, 1.0)


## Part de la santé d'un habitant que lui coûte le sol de son jardin (0..0,25).
func risque_sol(p: Vector3) -> float:
	if not ReglagesPartie.actuel.sols_pollues:
		return 0.0
	return 0.25 * sol_at(p.x, p.z)


func _depot(p: Vector3, force: float, r: float) -> void:
	if force <= 0.0:
		return
	var cs := ClimatTypes.SOL_CELL
	var c0 := cle_sol(p.x, p.z)
	var n := ceili(r / cs)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var k := c0 + Vector2i(i, j)
			var d := Vector2((k.x + 0.5) * cs - p.x, (k.y + 0.5) * cs - p.z).length()
			if d > r:
				continue
			var s := float(sols.get(k, 0.0))
			sols[k] = s + force * (1.0 - d / r) * (1.0 - s)


func _sols_jour(y: float) -> void:
	var actif := ReglagesPartie.actuel.sols_pollues
	var k := float(Nuisances.NIVEAUX[clampi(ReglagesPartie.actuel.pollution, 0, Nuisances.NIVEAUX.size() - 1)])
	if actif and k > 0.0 and buildings != null:
		for bid in buildings.buildings:
			if buildings.en_chantier(bid):
				continue
			var b: Dictionary = buildings.buildings[bid]
			var e := Nuisances.emission_of(String(b.t))
			if e.is_empty():
				continue
			var force := 0.6 * float(e.eau) + 0.4 * float(e.air)
			if force < 0.25:
				continue
			match String(_info_type(String(b.t)).famille):
				"industrie":
					if a("epuration_industrielle"):
						force *= 0.5
				"ferme":
					if a("normes_agricoles"):
						force *= 0.4
			_depot(BuildingSystem.rect_center(buildings._rect_of(b)), ClimatTypes.SOL_DEPOT * force * k, clampf(float(e.rayon) * 0.3, 60.0, 360.0))
		if is_inside_tree():
			for node in get_tree().get_nodes_in_group("pollution_sources"):
				if node == self or not node.has_method("pollution_sources"):
					continue
				for s in node.pollution_sources():
					if s is Dictionary and s.has("pos") and float(s.get("eau", 0.0)) >= 0.3:
						_depot(s.pos, ClimatTypes.SOL_DEPOT * float(s.eau) * 0.6 * k, clampf(float(s.get("rayon", 200.0)) * 0.3, 60.0, 300.0))
		# Pesticides et engrais chimiques des champs, après 1945.
		if agriculture != null and y >= 1945.0:
			var dep := ClimatTypes.SOL_CHAMPS * k * (0.4 if a("normes_agricoles") else 1.0)
			for id in agriculture.champs:
				var ch: Dictionary = agriculture.champs[id]
				if not bool(ch.get("tr", false)) or String(ch.get("etat", "friche")) == "friche":
					continue
				var r: Rect2i = ch.r
				var cs := ClimatTypes.SOL_CELL
				var x := float(r.position.x)
				while x < r.end.x:
					var z := float(r.position.y)
					while z < r.end.y:
						var kk := cle_sol(x, z)
						var s := float(sols.get(kk, 0.0))
						sols[kk] = s + dep * (1.0 - s)
						z += cs
					x += cs
	# Le sol guérit lentement (beaucoup plus vite avec la dépollution).
	var gueri := a("depollution")
	for kk in sols.keys():
		var s := float(sols[kk])
		s -= s * ClimatTypes.SOL_OUBLI * (10.0 if gueri else 1.0)
		if gueri:
			s -= 0.0015
		if s < 0.002 or not actif:
			sols.erase(kk)
		else:
			sols[kk] = s


## Hectares de sols pollués (au-dessus du seuil).
func sols_pollues_ha() -> float:
	var n := 0
	for k in sols:
		if float(sols[k]) >= ClimatTypes.SOL_SEUIL:
			n += 1
	return n * ClimatTypes.SOL_CELL * ClimatTypes.SOL_CELL / 10000.0


## Les points les plus pollués, regroupés par carrés de 200 m : [{pos, v}].
func points_noirs(n := 6) -> Array:
	var blocs := {}
	for k in sols:
		var v := float(sols[k])
		if v < ClimatTypes.SOL_SEUIL:
			continue
		var bk := Vector2i(floori(k.x / 5.0), floori(k.y / 5.0))
		if v > float(blocs.get(bk, [0.0])[0]):
			blocs[bk] = [v, k]
	var out := []
	for bk in blocs:
		var k: Vector2i = blocs[bk][1]
		out.append({"pos": Vector3((k.x + 0.5) * ClimatTypes.SOL_CELL, 0.0, (k.y + 0.5) * ClimatTypes.SOL_CELL), "v": float(blocs[bk][0])})
	out.sort_custom(func(p, q) -> bool: return float(p.v) > float(q.v))
	return out.slice(0, n)


## Nuisances : un sol très pollué fait baisser la valeur des terrains (« saleté »).
func pollution_sources() -> Array:
	var out := []
	for p in points_noirs(40):
		out.append({"pos": p.pos, "rayon": 160.0, "salete": clampf(float(p.v) * 0.6, 0.0, 0.6), "nom": "sol pollué"})
	return out


# --- Mesures ------------------------------------------------------------------------------------

## La mesure est-elle en vigueur ?
func a(id: String) -> bool:
	return mesures.has(id)


func adopter(id: String) -> bool:
	if not ClimatTypes.MESURES.has(id) or a(id):
		return false
	var y := Epoques.annee()
	if not ClimatTypes.mesure_disponible(id, y):
		return false
	mesures[id] = y
	_apres_mesure()
	message.emit("Plan climat : « %s » adoptée." % ClimatTypes.MESURES[id].nom)
	return true


func abandonner(id: String) -> bool:
	if not a(id):
		return false
	mesures.erase(id)
	_apres_mesure()
	message.emit("Plan climat : « %s » abandonnée." % ClimatTypes.MESURES[id].nom)
	return true


func _apres_mesure() -> void:
	if Nuisances.instance != null:
		Nuisances.instance._dirty = true
	_maj_meteo()
	changed.emit()


## Nuisances : multiplicateurs (air, eau) des émissions d'un bâtiment selon les mesures.
func facteurs_nuisances(tid: String) -> Vector2:
	var fa := 1.0
	var fe := 1.0
	match String(_info_type(tid).famille):
		"industrie":
			if a("filtres_usines"):
				fa *= 0.55
			if a("desulfuration"):
				fa *= 0.6
			if a("epuration_industrielle"):
				fe *= 0.4
		"ferme":
			if a("normes_agricoles"):
				fe *= 0.5
	if ClimatTypes.filiere_centrale(tid.to_lower()) and a("desulfuration"):
		fa *= 0.6
	return Vector2(fa, fe)


## Nuisances : multiplicateur de la pollution de l'air du trafic.
func facteur_air_trafic() -> float:
	var f := 1.0
	if a("pot_catalytique"):
		f *= 0.6
	if a("zfe"):
		f *= 0.7
	if a("transports_doux"):
		f *= 0.85
	return f


## Nombre de sites industriels et de centrales (pour le coût des mesures).
func sites() -> int:
	var n := 0
	if buildings == null:
		return 0
	for bid in buildings.buildings:
		var tid := String(buildings.buildings[bid].t)
		if String(_info_type(tid).famille) == "industrie" or (ClimatTypes.filiere_centrale(tid.to_lower()) and ClimatTypes.filiere(tid) in ["charbon", "gaz", "biomasse"]):
			n += 1
	return n


## Coût mensuel d'une mesure (€).
func cout_mesure(id: String) -> float:
	var m: Dictionary = ClimatTypes.MESURES.get(id, {})
	var c := float(m.get("cout", 0.0))
	c += float(m.get("par_site", 0.0)) * sites()
	if population != null:
		c += float(m.get("par_foyer", 0.0)) * population.households.size()
		c += float(m.get("par_hab", 0.0)) * population.persons.size()
	c += float(m.get("par_ha", 0.0)) * sols_pollues_ha()
	return roundf(c)


func budget_entretien() -> Dictionary:
	var out := {}
	for id in mesures:
		var c := cout_mesure(String(id))
		if c > 0.0:
			out["Plan climat : " + String(ClimatTypes.MESURES[id].nom).to_lower()] = c
	return out


func budget_recettes() -> Dictionary:
	if not a("taxe_carbone"):
		return {}
	var t := 0.0
	var n := 0
	for j in jours.slice(maxi(0, jours.size() - 7)):
		t += float(j.t.get("industrie", 0.0))
		n += 1
	if n == 0:
		return {}
	return {"Taxe carbone": roundf(t / n * BudgetCommunal.DAYS_PER_MONTH * float(ClimatTypes.MESURES.taxe_carbone.recette_t))}


func avis_facteurs() -> Array:
	return [{"id": "climat_plan", "theme": "environnement", "f": _avis_plan, "ville": true},
		{"id": "climat_zfe", "theme": "transports", "f": _avis_zfe, "ville": true},
		{"id": "climat_chaleur", "theme": "environnement", "f": _avis_chaleur, "ville": true}]


func _avis_plan() -> Array:
	if mesures.size() >= 4:
		return [1.5, ["+ La ville agit pour le climat et l'air qu'on respire"]]
	return [0.0, []]


func _avis_zfe() -> Array:
	if a("zfe"):
		return [-1.0, ["− La zone à faibles émissions interdit ma vieille voiture"]]
	return [0.0, []]


func _avis_chaleur() -> Array:
	if reglage() != 0 and ecart_local >= 1.5:
		return [-2.0, ["− Les étés sont devenus étouffants, le climat se dérègle"]]
	if reglage() != 0 and ilot >= 1.0:
		return [-1.0, ["− En ville, il fait bien plus chaud qu'à la campagne"]]
	return [0.0, []]


# --- Nouvelles ----------------------------------------------------------------------------------

func _news(texte: String, genre := "climat", pos := Vector3.INF) -> void:
	if evenements != null:
		evenements.news(texte, pos, genre)
	message.emit(texte)


func _annonces(y: float) -> void:
	for h in ClimatTypes.HISTOIRE_CLIMAT:
		var cle := "h%d" % int(h[0])
		if float(h[0]) <= y and not annonces.has(cle):
			annonces[cle] = true
			_news("Climat, %d : %s" % [int(h[0]), String(h[1])])
	if reglage() == 0:
		return
	var seuils := {1.0: "La planète a gagné 1 °C depuis l'époque des diligences.",
		1.5: "Le réchauffement dépasse 1,5 °C : la limite que visait l'accord de Paris est franchie.",
		2.0: "+2 °C : canicules, sécheresses et tempêtes deviennent la norme. Les glaciers fondent à vue d'œil.",
		3.0: "+3 °C : les étés de 2003 deviennent des étés frais. Les assureurs ne couvrent plus les côtes."}
	for s in seuils:
		var cle := "s%s" % str(s)
		if ecart_monde >= float(s) and not annonces.has(cle):
			annonces[cle] = true
			_news(String(seuils[s]))


static func _cm(v: float) -> String:
	return "%d cm" % roundi(v) if absf(v) < 100.0 else "%s m" % String.num(v / 100.0, 2).replace(".", ",")


# --- Résumés ------------------------------------------------------------------------------------

## Moyenne des derniers jours : {"t": {secteur}, "mix": {filière}}.
func moyenne(n := 7) -> Dictionary:
	var t := {}
	var mix := {}
	var part := jours.slice(maxi(0, jours.size() - n))
	for j in part:
		for k in j.t:
			t[k] = float(t.get(k, 0.0)) + float(j.t[k]) / part.size()
		for f in j.mix:
			mix[f] = float(mix.get(f, 0.0)) + float(j.mix[f]) / part.size()
	return {"t": t, "mix": mix}


## t CO₂ par habitant et par an d'après les derniers jours.
func par_habitant() -> float:
	var pop := population.persons.size() if population != null else 0
	if pop <= 0 or jours.is_empty():
		return 0.0
	return total(moyenne().t) * 365.0 / pop


## Part bas carbone de l'électricité des derniers jours (0..1).
func part_bas_carbone() -> float:
	var mix: Dictionary = moyenne().mix
	var tot := 0.0
	var bas := 0.0
	for f in mix:
		tot += float(mix[f])
		if f in ClimatTypes.BAS_CARBONE:
			bas += float(mix[f])
	return bas / tot if tot > 0.0 else 0.0


## Intensité de l'électricité (g CO₂ par kWh) des derniers jours.
func intensite_elec() -> float:
	var m := moyenne()
	var mwh := 0.0
	for f in m.mix:
		mwh += float(m.mix[f])
	return float(m.t.get("electricite", 0.0)) / mwh * 1000.0 if mwh > 0.0 else 0.0


func resume() -> String:
	return "%+.1f °C · %s t CO₂/j · %s ha de sols pollués" % [ecart_monde if not is_nan(ecart_monde) else 0.0,
		String.num(total(moyenne().t), 0), String.num(sols_pollues_ha(), 1)]


# --- Sauvegarde ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var sl := PackedInt32Array()
	for k in sols:
		sl.append(k.x)
		sl.append(k.y)
		sl.append(roundi(float(sols[k]) * 10000.0))
	return {"version": 1, "ecart": ecart_monde if not is_nan(ecart_monde) else null, "mer": mer_cm if not is_nan(mer_cm) else null,
		"annee": annee_f if not is_nan(annee_f) else null, "intensite": intensite if not is_nan(intensite) else null,
		"scenario": scenario_s, "aujourdhui": aujourdhui, "mix": mix_aujourdhui, "jours": jours, "annees": annees,
		"cumul": cumul, "mesures": mesures, "annonces": annonces, "sols": Array(sl), "forets": forets_ha, "parcs": parcs_ha,
		"submersions": submersions, "releve": _jours_releve}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	var nb := func(k: String) -> float: return float(d[k]) if d.get(k) != null else NAN
	ecart_monde = nb.call("ecart")
	mer_cm = nb.call("mer")
	annee_f = nb.call("annee")
	intensite = nb.call("intensite")
	scenario_s = float(d.get("scenario", 1.0))
	aujourdhui = d.get("aujourdhui", {}).duplicate()
	mix_aujourdhui = d.get("mix", {}).duplicate()
	jours = d.get("jours", []).duplicate(true)
	for j in jours:
		j.j = int(j.get("j", 0))
	annees = d.get("annees", {}).duplicate(true)
	cumul = float(d.get("cumul", 0.0))
	for id in d.get("mesures", {}):
		if ClimatTypes.MESURES.has(String(id)):
			mesures[String(id)] = int(d.mesures[id])
	annonces = d.get("annonces", {}).duplicate()
	var sl: Array = d.get("sols", [])
	for i in range(0, sl.size() - 2, 3):
		sols[Vector2i(int(sl[i]), int(sl[i + 1]))] = float(sl[i + 2]) / 10000.0
	forets_ha = float(d.get("forets", 0.0))
	parcs_ha = float(d.get("parcs", 0.0))
	submersions = int(d.get("submersions", 0))
	_jours_releve = int(d.get("releve", 0))
	if not is_nan(ecart_monde):
		_maj_meteo()
	changed.emit()
