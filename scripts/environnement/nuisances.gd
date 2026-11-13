class_name Nuisances
extends Node
## Pollution de l'air et de l'eau, bruit (jour et nuit), et valeur des terrains.
##
## Tout est calculé sur une grille de cases de CELL mètres, rangées par tuiles,
## seulement là où la ville existe. Chaque source « éclabousse » les cases
## autour d'elle (plus fort au centre), puis les sommes saturent entre 0 et 1.
##
## Sources :
## - bâtiments (usines, centrales, fermes, mines, stades, bars…) : table EMISSIONS ;
## - voies : routes (bruit et air selon la classe et le trafic), rail, aéroports ;
## - autres systèmes : groupe "pollution_sources" avec pollution_sources() → Array de
##   {"pos": Vector3, "rayon": m, "air", "eau", "bruit", "odeur", "salete": 0..1, "nom"},
##   ou ajouter_source(id, type, pos, force, rayon) / retirer_source(id).
## Ce qui protège : arbres, forêts, parcs (moins de pollution et de bruit).
##
## Effets : la santé des habitants (CycleVie.pollution_at), leur satisfaction
## (facteurs pour l'avis des habitants), la valeur des terrains et donc les loyers,
## la taxe foncière, les déménagements, les arrivées et la pousse du zonage.

signal recalcule

## Instance de la partie en cours (null hors partie).
static var instance: Nuisances

const CELL := 20.0
const TILE := 32
## Couches de la grille (sommes brutes avant saturation).
enum L { AIR, EAU, BRUIT, NUIT, GENE, VERT, COMMO, PRESTIGE, EMPLOIS, VUE_EAU, TRANSIT }
const NL := 11

## Prix moyen d'un terrain constructible (€/m²) pour un coefficient de 1.
const PRIX_M2 := 2800.0
const COEF_MIN := 0.4
const COEF_MAX := 3.0
## Vitesse à laquelle la valeur d'un bâtiment suit celle de son quartier (par jour de jeu).
const SUIVI_JOUR := 0.08
## Part des revenus au-delà de laquelle un loyer est trop cher.
const TAUX_EFFORT_MAX := 0.45
## Jours de loyer trop cher avant de chercher moins cher.
const JOURS_AVANT_DEMENAGER := 20
## Réglage Admin « Pollution » : multiplicateur des émissions.
const NIVEAUX := [0.0, 0.5, 1.0, 1.8]
const NIVEAUX_NOMS := ["Désactivée", "Faible", "Normale", "Forte"]

## Émissions des bâtiments, premier mot trouvé dans l'id du type (ou son archétype).
## [mots, air, eau, bruit, bruit la nuit (0/1), odeur, rayon (m)]
const EMISSIONS := [
	[["barrage", "centrale_solaire", "centrale_nucleaire", "chateau_eau"], 0.0, 0.0, 0.1, 0, 0.0, 200.0],
	[["centrale_charbon"], 1.0, 0.4, 0.5, 1, 0.1, 1500.0],
	[["haut_fourneau", "acierie", "aluminerie", "fonderie"], 0.9, 0.5, 0.7, 1, 0.2, 1100.0],
	[["raffinerie"], 0.9, 0.7, 0.5, 1, 0.6, 1200.0],
	[["usine_chimique", "labo_pharma"], 0.7, 0.8, 0.4, 1, 0.4, 900.0],
	[["cimenterie", "briqueterie", "verrerie", "filature_briques"], 0.7, 0.2, 0.5, 0, 0.0, 900.0],
	[["incinerateur"], 0.6, 0.2, 0.3, 1, 0.3, 900.0],
	[["papeterie", "usine_textile"], 0.45, 0.8, 0.4, 1, 0.4, 800.0],
	[["usine"], 0.45, 0.35, 0.45, 0, 0.05, 600.0],
	[["mine", "carriere", "sabliere", "argiliere", "mine_ciel_ouvert", "mine_sel"], 0.4, 0.5, 0.8, 0, 0.0, 700.0],
	[["puits"], 0.3, 0.4, 0.3, 1, 0.3, 400.0],
	[["sucrerie", "abattoir", "laiterie", "brasserie", "rizerie", "fournil", "moulin", "chai", "cave_cooperative"], 0.2, 0.55, 0.3, 0, 0.5, 450.0],
	[["scierie", "menuiserie"], 0.25, 0.1, 0.55, 0, 0.0, 400.0],
	[["porcherie", "poulailler", "elevage", "etable", "bergerie", "haras", "ferme_laitiere"], 0.1, 0.5, 0.15, 0, 0.7, 450.0],
	[["ferme", "cereales", "maraichere", "betteraves", "fibres", "serre", "cortijo", "hacienda", "grange", "silos", "hangar_agricole", "alpage"], 0.05, 0.35, 0.15, 0, 0.1, 300.0],
	[["station_epuration"], 0.0, 0.0, 0.1, 1, 0.5, 400.0],
	[["terminal_conteneurs", "entrepot", "depot_bus", "transporteur"], 0.2, 0.05, 0.5, 1, 0.0, 450.0],
	[["data_center", "eolienne"], 0.0, 0.0, 0.25, 1, 0.0, 250.0],
	[["atelier"], 0.1, 0.05, 0.3, 0, 0.0, 200.0],
	[["stade"], 0.05, 0.0, 0.7, 0, 0.0, 700.0],
	[["discotheque", "salle_concert", "casino"], 0.0, 0.0, 0.5, 1, 0.0, 300.0],
	[["cafe", "restaurant", "bowling"], 0.0, 0.0, 0.15, 1, 0.05, 90.0],
	[["parc_aquatique", "grande_roue", "carrousel", "manege", "skatepark", "foot"], 0.0, 0.0, 0.35, 0, 0.0, 300.0],
	[["supermarche", "centre_commercial", "station_service", "concession"], 0.1, 0.05, 0.3, 0, 0.0, 250.0],
	[["hopital", "pompiers"], 0.0, 0.0, 0.25, 1, 0.0, 250.0],
	[["ecole", "gymnase"], 0.0, 0.0, 0.2, 0, 0.0, 150.0],
]

## Bruit et air des voies : classe → [bruit, air, rayon (m), part la nuit].
const VOIES := {
	"autoroute": [0.8, 0.5, 450.0, 0.6], "voie_express": [0.7, 0.42, 350.0, 0.5],
	"bretelle": [0.5, 0.3, 200.0, 0.4], "departementale": [0.5, 0.28, 220.0, 0.35],
	"avenue": [0.5, 0.3, 180.0, 0.3], "giratoire": [0.4, 0.25, 140.0, 0.3], "rue": [0.25, 0.12, 90.0, 0.2],
	"train": [0.55, 0.05, 280.0, 0.5], "cremaillere": [0.35, 0.0, 150.0, 0.2], "lgv": [0.75, 0.0, 420.0, 0.5],
	"tram": [0.3, 0.0, 110.0, 0.2], "metro": [0.25, 0.0, 80.0, 0.2],
}
## Aéroports et héliports : [bruit, air, rayon, part la nuit].
const AIR_STATIONS := {"aeroport": [1.0, 0.45, 2500.0, 0.6], "aerodrome": [0.6, 0.15, 1000.0, 0.2], "heliport": [0.55, 0.05, 600.0, 0.2]}

var world: TerrainWorld
var buildings: BuildingSystem
var transport: TransportSystem
var population: Population
var ambiance: DayNight

## Tuile → Array de floats (TILE × TILE × NL), sommes brutes (Array : modifié sur place).
var _tiles: Dictionary = {}
## Tuile → PackedByteArray (TILE × TILE) : 1 eau, 2 forêt (lu une fois).
var _env: Dictionary = {}
## Sources posées par d'autres systèmes : id → {pos, rayon, air, eau, bruit, …}.
var _manuelles: Dictionary = {}
## Valeur actuelle de chaque bâtiment (elle suit son quartier jour après jour).
var coef_bat: Dictionary = {}
## Valeur visée (celle du quartier aujourd'hui).
var _cible: Dictionary = {}
## Jours de loyer trop cher par foyer.
var _cher: Dictionary = {}
## Couches finales déjà calculées par case (vidé à chaque recalcul).
var _cache: Dictionary = {}
var _medianes: Dictionary = {}
var _svc = null
var _svc_state := 0
var _dirty := true
var _timer := 0.0
var _last_ms := -100000
var _jour := -1
## Dernier temps de calcul (ms), pour les tests.
var last_ms := 0
var stats := {"sources": 0, "tuiles": 0}


func _init() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(w: TerrainWorld, b: BuildingSystem, t: TransportSystem, p: Population, a: DayNight) -> void:
	world = w
	buildings = b
	transport = t
	population = p
	ambiance = a
	var mark := func(_x = null) -> void: _dirty = true
	if buildings != null:
		buildings.changed.connect(mark)
	if transport != null:
		transport.network_changed.connect(mark)
		if transport.stations != null:
			transport.stations.lines_changed.connect(mark)
	if world != null:
		world.terrain_edited.connect(func(_n: int) -> void:
			_env.clear()
			_dirty = true)
		world.origin_changed.connect(func(_a: float, _b: float) -> void: clear())
	if population != null:
		population.attrait_logement = attrait
		# Satisfaction : par l'avis des habitants s'il existe, sinon on enchaîne.
		add_to_group("avis_sources")
		if not ResourceLoader.exists("res://scripts/avis/avis.gd"):
			var old: Callable = population.extra_satisfaction
			population.extra_satisfaction = func(p: Dictionary) -> Array:
				var mine := satisfaction_of(p)
				if old.is_valid():
					var ex: Array = old.call(p)
					if ex.size() >= 2:
						var why: Array = (ex[1] as Array).duplicate()
						why.append_array(mine[1])
						return [float(ex[0]) + float(mine[0]), why]
				return mine


func clear() -> void:
	_tiles.clear()
	_env.clear()
	coef_bat.clear()
	_cible.clear()
	_cher.clear()
	_dirty = true


func niveau() -> float:
	return float(NIVEAUX[clampi(ReglagesPartie.actuel.pollution, 0, NIVEAUX.size() - 1)])


# --- Sources posées par les autres systèmes -----------------------------------------

## type : "air", "eau", "bruit", "odeur" ou "salete" ; force 0..1 au centre ; rayon en m.
func ajouter_source(id: String, type: String, pos: Vector3, force: float, rayon: float) -> void:
	var s: Dictionary = _manuelles.get(id, {"pos": pos, "rayon": rayon, "nom": id})
	s.pos = pos
	s.rayon = maxf(rayon, CELL)
	s[type] = clampf(force, 0.0, 1.0)
	_manuelles[id] = s
	_dirty = true


func retirer_source(id: String) -> void:
	if _manuelles.erase(id):
		_dirty = true


# --- Calcul ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_timer -= delta
	var ms := Time.get_ticks_msec()
	# Recalcul quand quelque chose change (au plus toutes les 2 s), sinon toutes les 30 s
	# (trafic, sources des autres systèmes).
	if (_dirty and ms - _last_ms > 2000) or _timer <= 0.0:
		recalculer()
	if ambiance != null and population != null:
		var j := floori(ambiance.unix_time / 86400.0)
		if _jour < 0:
			_jour = j
		elif j > _jour:
			var n := mini(j - _jour, 30)
			_jour = j
			for i in n:
				jour_suivant()


## Recalcule toutes les couches et la valeur visée de chaque bâtiment.
func recalculer() -> void:
	var t0 := Time.get_ticks_msec()
	_dirty = false
	_timer = 30.0
	_last_ms = t0
	_tiles.clear()
	_cache.clear()
	var k := niveau()
	var n := 0
	# Sources des autres systèmes (lues d'abord : un bâtiment qu'ils décrivent eux-mêmes,
	# avec sa clé "bid", n'est pas compté une seconde fois par la table EMISSIONS).
	var autres := []
	var decrits := {}
	for node in get_tree().get_nodes_in_group("pollution_sources") if is_inside_tree() else []:
		if node.has_method("pollution_sources"):
			for s in node.pollution_sources():
				if s is Dictionary and s.has("pos"):
					autres.append(s)
					if s.has("bid"):
						decrits[int(s.bid)] = true
	if buildings != null:
		for bid in buildings.buildings:
			if decrits.has(bid):
				continue
			if buildings.en_chantier(bid):
				# Un chantier fait du bruit le jour.
				var cb: Dictionary = buildings.buildings[bid]
				_splat(L.BRUIT, BuildingSystem.rect_center(buildings._rect_of(cb)), 0.3 * k, 150.0)
				continue
			n += _sources_batiment(bid, k)
	if transport != null:
		n += _sources_voies(k)
	for s in _manuelles.values():
		_source_dict(s, k)
		n += 1
	for s in autres:
		_source_dict(s, k)
		n += 1
	_environnement()
	_cache.clear()
	# Valeur visée de chaque bâtiment.
	_cible.clear()
	if buildings != null:
		for bid in buildings.buildings:
			var c := valeur(_centre(bid))
			_cible[bid] = c
			if not coef_bat.has(bid):
				coef_bat[bid] = c
	for bid in coef_bat.keys():
		if not _cible.has(bid) and (population == null or not population.known.has(bid)):
			coef_bat.erase(bid)
	# Bâtiments en murs fins (plans) : ils sont connus des habitants seulement.
	if population != null:
		for bid in population.known:
			if not _cible.has(bid):
				var c := valeur(population.known[bid].pos)
				_cible[bid] = c
				if not coef_bat.has(bid):
					coef_bat[bid] = c
	stats = {"sources": n, "tuiles": _tiles.size()}
	last_ms = Time.get_ticks_msec() - t0
	recalcule.emit()


func _centre(bid: int) -> Vector3:
	if population != null and population.known.has(bid):
		return population.known[bid].pos
	if buildings != null and buildings.buildings.has(bid):
		return BuildingSystem.rect_center(buildings._rect_of(buildings.buildings[bid]))
	return Vector3.ZERO


## Émissions d'un type de bâtiment : {air, eau, bruit, nuit, odeur, rayon} (vide si aucune).
static func emission_of(type_id: String) -> Dictionary:
	var t := BuildingCatalog.get_type(type_id)
	var arch := String(t.get("arch", t.get("role", "")))
	var id := type_id.to_lower()
	for e in EMISSIONS:
		for kw in e[0]:
			if id.contains(kw) or arch == kw:
				return {"air": e[1], "eau": e[2], "bruit": e[3], "nuit": int(e[4]) == 1, "odeur": e[5], "rayon": e[6]}
	return {}


func _sources_batiment(bid: int, k: float) -> int:
	var b: Dictionary = buildings.buildings[bid]
	var tid := String(b.t)
	var t := BuildingCatalog.get_type(tid)
	var rect := buildings._rect_of(b)
	var c := BuildingSystem.rect_center(rect)
	var cat := String(t.get("cat", ""))
	var arch := String(t.get("arch", t.get("role", tid)))
	var size := sqrt(float(rect.size.x * rect.size.y))
	var n := 0
	var e := emission_of(tid)
	if not e.is_empty() and k > 0.0:
		# Les grands sites portent plus loin.
		var r := float(e.rayon) * clampf(size / 60.0, 0.6, 1.6)
		var f := k * clampf(size / 50.0, 0.5, 1.5)
		if float(e.air) > 0.0:
			_splat(L.AIR, c, float(e.air) * f, r)
		if float(e.eau) > 0.0:
			_splat(L.EAU, c, float(e.eau) * f, r * 0.8)
		if float(e.bruit) > 0.0:
			_splat(L.BRUIT, c, float(e.bruit) * f, r * 0.6)
			if bool(e.nuit):
				_splat(L.NUIT, c, float(e.bruit) * f, r * 0.6)
		if float(e.odeur) > 0.0:
			_splat(L.GENE, c, float(e.odeur) * f, r * 0.7)
		n = 1
	# Ce qui fait la valeur d'un quartier.
	var tid_l := tid.to_lower()
	if cat == "espaces" or arch == "jardin" or tid_l.contains("parc") or tid_l.contains("jardin") or tid_l.contains("square"):
		_splat(L.VERT, c, 1.2 * clampf(size / 30.0, 0.5, 2.5), maxf(150.0, size * 4.0))
		_splat(L.PRESTIGE, c, 0.25, 250.0)
	match cat:
		"commerce":
			_splat(L.COMMO, c, 0.45, 500.0)
		"services":
			_splat(L.COMMO, c, 0.5, 800.0)
		"loisirs", "sport":
			_splat(L.COMMO, c, 0.3, 600.0)
	var p := _prestige(tid, t)
	if p != 0.0:
		_splat(L.PRESTIGE, c, p, 200.0)
	var emp := int(t.get("emplois", 0))
	if emp > 0:
		_splat(L.EMPLOIS, c, clampf(emp / 150.0, 0.05, 2.0), 1500.0)
	return n


## Prestige d'un bâtiment pour ses voisins (−1 à +1).
static func _prestige(tid: String, t: Dictionary) -> float:
	var arch := String(t.get("arch", t.get("role", tid)))
	match arch:
		"villa", "grande_maison", "chateau":
			return 0.6
		"maison", "rangee":
			return 0.15
		"tour":
			return -0.1
		"palais", "culte", "musee", "theatre", "monument", "hotel":
			return 0.5
	if tid.contains("chateau") or tid.contains("palais") or tid.contains("monument"):
		return 0.5
	return 0.0


func _sources_voies(k: float) -> int:
	var net := transport.network
	var flux := {}
	var lourds := {}
	var tr = transport.traffic
	if tr != null and tr.has_method("flux_all"):
		flux = tr.flux_all()
	var activite := 0.35
	if population != null:
		activite = clampf(0.35 + population.persons.size() / 3000.0, 0.35, 1.0)
	var n := 0
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		var cls := String(e.t)
		if not VOIES.has(cls):
			continue
		var spec: Array = VOIES[cls]
		var bruit := float(spec[0])
		var air := float(spec[1])
		var r := float(spec[2])
		var mode := TransportTypes.mode_of(cls)
		if mode == TransportTypes.Mode.ROAD:
			if flux.has(eid):
				# Véhicules par heure → niveau (≈ 10 dB par décade).
				var f := float(flux[eid])
				var lv := 0.0
				if tr.has_method("flux_lourds"):
					lv = float(tr.flux_lourds(eid))
				var eq := f + 6.0 * lv
				var x := clampf(0.12 + 0.2 * log(1.0 + eq) / log(10.0), 0.0, 1.0)
				air = air / maxf(bruit, 0.01) * x
				bruit = x
			else:
				bruit *= activite
				air *= activite
		bruit *= k
		air *= k
		if bruit <= 0.0 and air <= 0.0:
			continue
		var pts: PackedVector3Array = e.pts
		var st: PackedByteArray = e.get("st", PackedByteArray())
		var step := maxi(1, int(CELL / 2.0))
		var i := 0
		# Un échantillon tous les ~20 m (les points sont tous les ~2 m).
		while i < pts.size():
			if i < st.size() and st[i] == TransportTypes.Struct.TUNNEL:
				i += step * 5
				continue
			var p := pts[i]
			var w := CELL / 20.0
			_splat(L.BRUIT, p, bruit * w, r)
			_splat(L.NUIT, p, bruit * float(spec[3]) * w, r)
			if air > 0.0:
				_splat(L.AIR, p, air * w * 0.5, r * 0.8)
			i += step * 5
		n += 1
	if transport.stations != null:
		for sid in transport.stations.stations:
			var s: Dictionary = transport.stations.stations[sid]
			var ty := String(s.type)
			var pos: Vector3 = s.get("pos", Vector3.ZERO)
			if AIR_STATIONS.has(ty) and k > 0.0:
				var a: Array = AIR_STATIONS[ty]
				_splat(L.BRUIT, pos, float(a[0]) * k * 1.5, float(a[2]))
				_splat(L.NUIT, pos, float(a[0]) * float(a[3]) * k * 1.5, float(a[2]))
				_splat(L.AIR, pos, float(a[1]) * k, float(a[2]) * 0.6)
				n += 1
			# Desserte : arrêts et gares font monter la valeur.
			match ty:
				"arret_bus", "arret_tram":
					_splat(L.TRANSIT, pos, 0.6, 400.0)
				"station_metro", "gare":
					_splat(L.TRANSIT, pos, 1.2, 900.0)
				"port", "aeroport":
					_splat(L.TRANSIT, pos, 0.5, 2500.0)
	return n


func _source_dict(s: Dictionary, k: float) -> void:
	var pos: Vector3 = s.pos
	var r := float(s.get("rayon", 200.0))
	for pair in [["air", L.AIR], ["eau", L.EAU], ["bruit", L.BRUIT], ["odeur", L.GENE], ["salete", L.GENE]]:
		var v := float(s.get(pair[0], 0.0))
		if v > 0.0:
			_splat(pair[1], pos, clampf(v, 0.0, 1.0) * k, r)
			if pair[0] == "bruit" and bool(s.get("nuit", false)):
				_splat(L.NUIT, pos, clampf(v, 0.0, 1.0) * k, r)


## Eau (vue, pollution qui suit les cours d'eau) et forêts des tuiles touchées.
func _environnement() -> void:
	if world == null:
		return
	for tk in _tiles.keys():
		var env: PackedByteArray = _env.get(tk, PackedByteArray())
		if env.is_empty():
			env = _lire_env(tk)
			if env.is_empty():
				continue
			_env[tk] = env
		for j in TILE:
			for i in TILE:
				var v := env[i + j * TILE]
				if v == 0:
					continue
				var p := Vector3((tk.x * TILE + i + 0.5) * CELL, 0, (tk.y * TILE + j + 0.5) * CELL)
				if v == 1:
					_splat(L.VUE_EAU, p, 0.12, 160.0, false)
				elif v == 2:
					_splat(L.VERT, p, 0.07, 70.0, false)


func _lire_env(tk: Vector2i) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(TILE * TILE)
	var known := 0
	for j in TILE:
		for i in TILE:
			var x := (tk.x * TILE + i + 0.5) * CELL
			var z := (tk.y * TILE + j + 0.5) * CELL
			var h := world.raw_height(x, z)
			if is_nan(h):
				continue
			known += 1
			var c := Vector2i(floori(x), floori(z))
			var bio := world.cell_biome(c)
			if h < 0.0 or bio == 80 or world.water_cells.has(c) or world.water.width_at(x, z) > 3.0:
				out[i + j * TILE] = 1
			elif bio == 10 or bio == 95:
				out[i + j * TILE] = 2
	# Relief pas encore chargé : on réessaiera.
	return out if known > TILE * TILE / 2 else PackedByteArray()


## Ajoute v × (1 − d/r)² aux cases à moins de r mètres de p.
func _splat(layer: int, p: Vector3, v: float, r: float, create := true) -> void:
	if v == 0.0:
		return
	var cx := p.x / CELL - 0.5
	var cz := p.z / CELL - 0.5
	var rc := r / CELL
	var i0 := floori(cx - rc)
	var i1 := ceili(cx + rc)
	var j0 := floori(cz - rc)
	var j1 := ceili(cz + rc)
	var r2 := rc * rc
	var cur_t := Vector2i(1 << 30, 0)
	var arr: Array = []
	var has := false
	for j in range(j0, j1 + 1):
		var dz := j - cz
		for i in range(i0, i1 + 1):
			var dx := i - cx
			var d2 := dx * dx + dz * dz
			if d2 > r2:
				continue
			var tk := Vector2i(floori(float(i) / TILE), floori(float(j) / TILE))
			if tk != cur_t:
				cur_t = tk
				has = _tiles.has(tk)
				if has:
					arr = _tiles[tk]
				elif create:
					arr = []
					arr.resize(TILE * TILE * NL)
					arr.fill(0.0)
					_tiles[tk] = arr
					has = true
			if not has:
				continue
			var w := 1.0 - sqrt(d2) / rc
			var li := (posmod(i, TILE) + posmod(j, TILE) * TILE) * NL + layer
			arr[li] += v * w * w


# --- Lecture ---------------------------------------------------------------------------

## Sommes brutes d'une case de la grille (NL valeurs, vide si rien).
func _raw(i: int, j: int) -> Array:
	var tk := Vector2i(floori(float(i) / TILE), floori(float(j) / TILE))
	if not _tiles.has(tk):
		return []
	var arr: Array = _tiles[tk]
	var base := (posmod(i, TILE) + posmod(j, TILE) * TILE) * NL
	return arr.slice(base, base + NL)


static func _sat(x: float) -> float:
	return 1.0 - exp(-maxf(x, 0.0))


## Couches finales d'une case : {air, eau, bruit, nuit, gene, vert, …} entre 0 et 1.
func _final(raw: Array) -> Dictionary:
	if raw.is_empty():
		return {"air": 0.0, "eau": 0.0, "bruit": 0.0, "nuit": 0.0, "gene": 0.0, "vert": 0.0, "commo": 0.0,
			"prestige": 0.0, "emplois": 0.0, "vue_eau": 0.0, "transit": 0.0}
	var vert := _sat(raw[L.VERT])
	# Arbres et parcs filtrent l'air et étouffent le bruit.
	var filtre := 1.0 - 0.35 * vert
	return {"air": _sat(raw[L.AIR]) * filtre, "eau": _sat(raw[L.EAU]), "bruit": _sat(raw[L.BRUIT]) * (1.0 - 0.25 * vert),
		"nuit": _sat(raw[L.NUIT]) * (1.0 - 0.25 * vert), "gene": _sat(raw[L.GENE]) * filtre, "vert": vert,
		"commo": _sat(raw[L.COMMO]), "prestige": tanh(raw[L.PRESTIGE]), "emplois": _sat(raw[L.EMPLOIS] * 0.5),
		"vue_eau": _sat(raw[L.VUE_EAU]), "transit": _sat(raw[L.TRANSIT])}


func _final_at(i: int, j: int) -> Dictionary:
	var key := Vector2i(i, j)
	var f = _cache.get(key)
	if f == null:
		f = _final(_raw(i, j))
		# Arrêtés des quartiers (zone 30, calme la nuit, fleurissement…).
		if Quartiers.instance != null:
			f = Quartiers.instance.moduler(f, (i + 0.5) * CELL, (j + 0.5) * CELL)
		if _cache.size() < 200000:
			_cache[key] = f
	return f


## Valeur d'une couche pour les cartes de couleur ("air", "eau", "bruit", "nuit",
## "valeur" en 0..1 où 0,5 = moyen) : la case la plus proche, rapide.
func couche(nom: String, x: float, z: float) -> float:
	var i := floori(x / CELL)
	var j := floori(z / CELL)
	var f := _final_at(i, j)
	if nom == "valeur":
		var c := valeur_de(f, Vector3(x, 0, z))
		# 0,4 → 0 ; 1 → 0,5 ; 3 → 1 (échelle log).
		return clampf(0.5 + 0.5 * log(c) / log(3.0) if c >= 1.0 else 0.5 * (c - COEF_MIN) / (1.0 - COEF_MIN), 0.0, 1.0)
	return float(f.get(nom, 0.0))


## Toutes les couches au point p (interpolées entre les cases voisines).
func au_point(p: Vector3) -> Dictionary:
	var fx := p.x / CELL - 0.5
	var fz := p.z / CELL - 0.5
	var i := floori(fx)
	var j := floori(fz)
	var ax := fx - i
	var az := fz - j
	var out := {}
	var corners := [[i, j, (1.0 - ax) * (1.0 - az)], [i + 1, j, ax * (1.0 - az)], [i, j + 1, (1.0 - ax) * az], [i + 1, j + 1, ax * az]]
	for c in corners:
		var f := _final_at(c[0], c[1])
		for key in f:
			out[key] = float(out.get(key, 0.0)) + float(f[key]) * float(c[2])
	return out


func air(p: Vector3) -> float:
	return float(au_point(p).air)


func eau(p: Vector3) -> float:
	return float(au_point(p).eau)


## Bruit au point p (0..1). nuit : -1 = selon l'heure, 0 = jour, 1 = nuit.
func bruit(p: Vector3, nuit := 0) -> float:
	var f := au_point(p)
	if nuit < 0:
		nuit = 1 if _est_nuit() else 0
	return float(f.nuit) if nuit == 1 else float(f.bruit)


func _est_nuit() -> bool:
	if ambiance == null:
		return false
	var h := fmod(ambiance.unix_time / 3600.0 + 1.0, 24.0)
	return h < 6.0 or h >= 22.0


## Bruit en décibels (Lden approché) : 0 → 35 dB, 1 → 80 dB.
static func decibels(v: float) -> int:
	return roundi(35.0 + 45.0 * clampf(v, 0.0, 1.0))


## Coefficient de valeur d'un terrain au point p (1,0 = moyen, de 0,4 à 3).
func valeur(p: Vector3) -> float:
	return valeur_de(au_point(p), p)


func valeur_de(f: Dictionary, p: Vector3) -> float:
	var v := 1.0
	v += 0.30 * float(f.commo) + 0.25 * float(f.vue_eau) + 0.30 * float(f.vert) + 0.20 * float(f.transit)
	v += 0.25 * float(f.emplois) + 0.35 * float(f.prestige)
	v -= 0.75 * float(f.air) + 0.25 * float(f.eau) + 0.45 * float(f.bruit) + 0.25 * float(f.nuit) + 0.35 * float(f.gene)
	v += 0.25 * _services(p)
	return clampf(v, COEF_MIN, COEF_MAX)


## Couverture des services publics (écoles, hôpitaux, police), si le système existe.
func _services(p: Vector3) -> float:
	if _svc_state == 0:
		_svc_state = -1
		var path := "res://scripts/services/services_publics.gd"
		if ResourceLoader.exists(path):
			_svc = load(path)
			if _svc != null and _svc.has_method("couverture"):
				_svc_state = 1
	if _svc_state != 1:
		return 0.0
	return clampf(float(_svc.couverture(p, "")), 0.0, 1.0)


## Prix du terrain au point p (€/m²).
func prix_m2(p: Vector3) -> float:
	return PRIX_M2 * valeur(p)


# --- Bâtiments et habitants -------------------------------------------------------------

## Coefficient de valeur actuel d'un bâtiment (pour la taxe foncière, autour de 1,0).
func coef_foncier(bid: int) -> float:
	return float(coef_bat.get(bid, _cible.get(bid, 1.0)))


## Tendance d'un bâtiment : valeur visée − valeur actuelle (> 0 : le quartier monte).
func tendance(bid: int) -> float:
	return float(_cible.get(bid, coef_foncier(bid))) - coef_foncier(bid)


## Loyer de base d'un logement (avant la valeur du quartier).
func loyer_base(bid: int) -> float:
	if population == null or not population.known.has(bid):
		return Population.LOYER_APPART
	var info: Dictionary = population.known[bid]
	if float(info.get("loyer", 0.0)) > 0.0:
		return float(info.loyer)
	return Population.LOYER_MAISON if bool(info.get("house", false)) else Population.LOYER_APPART


## Loyer d'un logement (€ par mois) : il suit la valeur du quartier.
func loyer(bid: int) -> float:
	return roundf(loyer_base(bid) * coef_foncier(bid))


## Pollution qui touche la santé de ceux qui vivent là (0..1).
func sante(bid: int) -> float:
	if not ReglagesPartie.actuel.pollution_sante:
		return 0.0
	# Une usine vient d'ouvrir : la santé se lit sur des valeurs à jour.
	if _dirty and Time.get_ticks_msec() - _last_ms > 250:
		recalculer()
	var f := au_point(_centre(bid))
	return clampf(float(f.air) + 0.5 * float(f.eau), 0.0, 1.0)


## Gêne au logement (pollution, odeurs, bruit surtout la nuit), 0..1.
func gene(bid: int) -> float:
	var f := au_point(_centre(bid))
	return clampf(0.45 * float(f.air) + 0.3 * float(f.gene) + 0.25 * float(f.bruit) + 0.4 * float(f.nuit), 0.0, 1.0)


## Attrait d'un logement pour les nouveaux arrivants (multiplie le rythme des arrivées).
func attrait(bid: int) -> float:
	var g := gene(bid)
	var c := coef_foncier(bid)
	# Les quartiers agréables se remplissent plus vite, les quartiers gênants lentement.
	return clampf(1.0 - 1.1 * g + 0.25 * (c - 1.0), 0.15, 1.4)


## Part du loyer dans les revenus d'un foyer.
func taux_effort(hid: int) -> float:
	if population == null or not population.households.has(hid):
		return 0.0
	var h: Dictionary = population.households[hid]
	var inc := 0.0
	for pid in h.m:
		inc += population.income_of(population.persons[pid])
	var l := loyer(int(h.b))
	return l / inc if inc > 0.0 else (9.9 if l > 0.0 else 0.0)


## Satisfaction liée au cadre de vie et au loyer : [delta, raisons].
func satisfaction_of(p: Dictionary) -> Array:
	var out := [0.0, []]
	for fa in _facteurs_liste():
		var r: Array = (fa.f as Callable).call(p)
		out[0] = float(out[0]) + float(r[0])
		(out[1] as Array).append_array(r[1])
	return out


func _facteurs_liste() -> Array:
	return [{"id": "pollution", "theme": "environnement", "f": _f_pollution},
		{"id": "bruit", "theme": "environnement", "f": _f_bruit},
		{"id": "loyer", "theme": "logement", "f": _f_loyer}]


## Facteurs pour l'avis des habitants (groupe "avis_sources").
func avis_facteurs() -> Array:
	return _facteurs_liste()


func _f_pollution(p: Dictionary) -> Array:
	var home := population.home_of(p)
	if home < 0:
		return [0.0, []]
	var f := au_point(_centre(home))
	var d := 0.0
	var why := []
	if float(f.air) > 0.12:
		d -= 14.0 * float(f.air)
		why.append("− air pollué (%d %%)" % roundi(100.0 * float(f.air)))
	if float(f.eau) > 0.25:
		d -= 5.0 * float(f.eau)
		why.append("− eau polluée près de chez soi")
	if float(f.gene) > 0.15:
		d -= 8.0 * float(f.gene)
		why.append("− mauvaises odeurs")
	if float(f.vert) > 0.3:
		d += 5.0 * float(f.vert)
		why.append("+ verdure autour du logement")
	if float(f.vue_eau) > 0.4:
		d += 3.0
		why.append("+ au bord de l'eau")
	return [clampf(d, -15.0, 10.0), why]


func _f_bruit(p: Dictionary) -> Array:
	var home := population.home_of(p)
	if home < 0:
		return [0.0, []]
	var f := au_point(_centre(home))
	var b := 0.4 * float(f.bruit) + 0.8 * float(f.nuit)
	if b < 0.2:
		return [0.0, []]
	var txt := "− bruit (%d dB le jour, %d dB la nuit)" % [decibels(float(f.bruit)), decibels(float(f.nuit))]
	return [clampf(-14.0 * b, -15.0, 0.0), [txt]]


func _f_loyer(p: Dictionary) -> Array:
	var hid := int(p.get("f", -1))
	if population == null or not population.households.has(hid):
		return [0.0, []]
	var te := taux_effort(hid)
	if te > 0.4:
		return [clampf(-25.0 * (te - 0.3), -12.0, 0.0), ["− loyer trop cher (%d %% des revenus)" % mini(roundi(te * 100.0), 999)]]
	if te > 0.0 and te < 0.2:
		return [3.0, ["+ loyer abordable"]]
	return [0.0, []]


# --- Chaque jour : valeur qui suit le quartier, déménagements --------------------------

func jour_suivant() -> void:
	for bid in _cible:
		var c := coef_foncier(bid)
		coef_bat[bid] = c + (float(_cible[bid]) - c) * SUIVI_JOUR
	if population == null:
		return
	var moves := 0
	for hid in population.households.keys():
		if moves >= 5:
			break
		if not population.households.has(hid):
			continue
		var h: Dictionary = population.households[hid]
		var te := taux_effort(hid)
		var n := int(_cher.get(hid, 0))
		n = n + 1 if te > TAUX_EFFORT_MAX else maxi(0, n - 1)
		_cher[hid] = n
		var why := ""
		var target := -1
		if n >= JOURS_AVANT_DEMENAGER:
			target = _logement_moins_cher(hid)
			why = "Déménage dans un logement moins cher (%s par mois)"
		elif gene(int(h.b)) > 0.55 and population.rng.randf() < 0.03:
			target = _logement_calme(hid)
			why = "Déménage loin du bruit et de la pollution (%s par mois)"
		if target >= 0:
			population.move_household(hid, target)
			_cher[hid] = 0
			moves += 1
			for pid in h.m:
				if population.persons.has(pid) and population.vie != null:
					population.vie.log_event(population.persons[pid], "demenage", why % BuildingSystem.format_money(roundi(loyer(target))), target)
	for hid in _cher.keys():
		if not population.households.has(hid):
			_cher.erase(hid)


func _revenus(hid: int) -> float:
	var inc := 0.0
	for pid in population.households[hid].m:
		inc += population.income_of(population.persons[pid])
	return inc


func _logement_moins_cher(hid: int) -> int:
	var inc := _revenus(hid)
	var best := -1
	var best_l := INF
	for bid in population.known:
		if population.free_homes(bid) <= 0:
			continue
		var l := loyer(bid)
		if l <= 0.35 * inc and l < best_l:
			best_l = l
			best = bid
	if best >= 0:
		return best
	# Rien d'abordable : au moins nettement moins cher qu'aujourd'hui.
	var now := loyer(int(population.households[hid].b))
	for bid in population.known:
		if population.free_homes(bid) <= 0:
			continue
		var l := loyer(bid)
		if l < now * 0.7 and l < best_l:
			best_l = l
			best = bid
	return best


func _logement_calme(hid: int) -> int:
	var inc := _revenus(hid)
	var best := -1
	var best_g := 0.25
	for bid in population.known:
		if population.free_homes(bid) <= 0:
			continue
		var g := gene(bid)
		if g < best_g and loyer(bid) <= 0.4 * inc:
			best_g = g
			best = bid
	return best


# --- Zonage et usure -------------------------------------------------------------------

## Chance qu'un bâtiment de ce type pousse à cet endroit (zonage) : les quartiers
## chers attirent les bâtiments chers, les quartiers dévalués les moins chers.
func chance_pousse(type_id: String, pos: Vector3, types: Dictionary) -> float:
	if types.size() < 2:
		return 1.0
	var key := "%d|%s" % [types.size(), str(types.keys()[0])]
	var med := float(_medianes.get(key, -1.0))
	if med < 0.0:
		var costs := []
		for id in types:
			costs.append(_cout_unitaire(id))
		costs.sort()
		med = costs[costs.size() / 2]
		_medianes[key] = med
	var chic := clampf(log(maxf(_cout_unitaire(type_id), 1.0) / maxf(med, 1.0)) / log(4.0), -1.0, 1.0)
	var f := clampf((valeur(pos) - 1.0) * 1.5, -1.0, 1.0)
	return clampf(1.0 + 0.8 * chic * f, 0.15, 1.0)


## Prix d'un type par logement ou emploi (pour comparer les bâtiments chics et modestes).
static func _cout_unitaire(id: String) -> float:
	var t := BuildingCatalog.get_type(id)
	return float(BuildingCatalog.cost(id)) / float(maxi(1, int(t.get("logements", 0)) + int(t.get("emplois", 0))))


## Vitesse d'usure d'un bâtiment : un quartier dévalué s'abîme plus vite.
func usure_rythme(bid: int) -> float:
	var c := coef_foncier(bid)
	return clampf(1.0 + (1.0 - c) * 0.8, 0.6, 1.6)


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var c := {}
	for bid in coef_bat:
		c[str(bid)] = snappedf(float(coef_bat[bid]), 0.001)
	var ch := {}
	for hid in _cher:
		if int(_cher[hid]) > 0:
			ch[str(hid)] = int(_cher[hid])
	return {"version": 1, "valeurs": c, "cher": ch}


func from_dict(d: Dictionary) -> void:
	clear()
	for k in d.get("valeurs", {}):
		coef_bat[int(k)] = clampf(float(d.valeurs[k]), COEF_MIN, COEF_MAX)
	for k in d.get("cher", {}):
		_cher[int(k)] = int(d.cher[k])
	_jour = -1
	_dirty = true
