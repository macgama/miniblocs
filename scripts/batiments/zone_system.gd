class_name ZoneSystem
extends Node3D
## Zonage dans le mode Terre : le joueur peint des zones (résidentielle,
## commerciale, industrielle) et des bâtiments y poussent tout seuls, alignés
## le long des routes, selon la demande.
##
## - Une zone est un rectangle de cases : {id, k (type), x, z, w, h}.
## - Les bâtiments qui poussent sont des bâtiments ordinaires du catalogue
##   (BuildingSystem), gratuits pour le joueur, avec accès route obligatoire.
## - Le joueur paie le zonage au m² (sauf argent illimité).
## - Retirer une zone n'enlève pas les bâtiments déjà construits.

signal info_changed(text: String)
signal message(text: String)
signal changed
## Le pinceau a changé (set_paint, set_remove, set_inactive) : le panneau le montre.
signal outil_change

enum Mode { NONE, PAINT, REMOVE }

const KINDS := {
	"R": {"name": "Résidentielle", "color": Color(0.35, 0.85, 0.35, 0.33),
		"types": {"maison": 6, "villa": 2, "immeuble": 3, "tour_habitation": 1}},
	"C": {"name": "Commerciale", "color": Color(0.3, 0.6, 1.0, 0.33),
		"types": {"boulangerie": 3, "cafe": 3, "superette": 3, "bureaux": 2, "supermarche": 1}},
	"I": {"name": "Industrielle", "color": Color(1.0, 0.8, 0.2, 0.33),
		"types": {"atelier": 4, "entrepot": 3, "usine": 2}},
}
## Archétypes de la bible qui poussent dans chaque type de zone, avec leur poids.
const STYLE_ARCHS := {
	"R": {"maison": 6, "grande_maison": 2, "rangee": 3, "immeuble": 3, "tour": 1},
	"C": {"boutique": 4, "restaurant": 3, "marche": 1, "bureaux": 2, "grand_magasin": 1, "gratte_ciel": 1},
	"I": {"atelier": 4, "entrepot": 3, "usine": 2, "ferme": 1},
}
## Style des nouvelles zones : "" = modèles classiques MiniBlocs, "mix" = tous
## les styles mélangés, STYLE_BIBLE = bâtiments Blender de la bible (champ
## "zone" de leur fiche), sinon un style de Styles.STYLES.
const STYLE_BIBLE := "bible_blender"
## Chance (0..1) qu'un type pousse à un endroit : (type_id, pos: Vector3, types) -> float (Nuisances).
var extra_chance: Callable
## Si défini, Callable(rect: Rect2i) -> String : raison qui interdit de peindre
## ce zonage (territoire des villages), ou "".
var area_check: Callable
## Optionnel : Callable(vid := -1) -> bool. Faux : les promoteurs attendent avant
## d'ouvrir un nouveau chantier (Fondateurs : plus d'ouvriers libres). vid : le
## village neuf où pousserait le bâtiment, -1 pour le reste de la carte.
var peut_pousser: Callable
var current_style := ""

## Couleur de l'outil Retirer (cadre, carte du panneau).
const COULEUR_RETIRER := Color(1.0, 0.36, 0.3, 0.35)
## Prix du zonage (€ par m²).
const PRICE_M2 := 2
## Côté maximal d'une zone (m).
const MAX_SIDE := 300
## Secondes entre deux tentatives de croissance.
const GROW_INTERVAL := 0.8
## Habitants par logement.
const PEOPLE_PER_HOME := 2.3

@export var world_path: NodePath
@export var camera_path: NodePath
@export var buildings_path: NodePath

var world: TerrainWorld
var camera: Camera3D
var buildings: BuildingSystem

var mode: Mode = Mode.NONE
var kind := "R"
var growth := true
## id -> {"id", "k", "x", "z", "w", "h"}
var zones: Dictionary = {}
var next_id := 1
var rng := RandomNumberGenerator.new()

var _views: Dictionary = {} # id -> MeshInstance3D
var _dirty_views: Dictionary = {}
var _timer := 0.0
var _turn := 0
var _drag := false
var _drag_start := Vector2i.ZERO
var _cursor := Vector2i.ZERO
var _cursor_valid := false
var _right_press := Vector2.ZERO
var _box: MeshInstance3D
var _mats: Dictionary = {}
var _box_mat: StandardMaterial3D
## Opacité du calque des zones peintes.
const CALQUE_ALPHA := 0.42


func _ready() -> void:
	rng.seed = 1234
	if not world_path.is_empty():
		world = get_node_or_null(world_path) as TerrainWorld
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if not buildings_path.is_empty():
		buildings = get_node_or_null(buildings_path) as BuildingSystem
	if buildings != null:
		if buildings.transport != null:
			buildings.transport.network.changed.connect(func() -> void:
				_roads_cache.clear()
				_routes_index.clear())
		buildings.changed.connect(func() -> void:
			_demand_cache.clear()
			# Seules les parties de zone autour du bâtiment changé sont redessinées.
			var r := buildings.last_change_rect
			if r.has_area():
				_mark_area(r)
			else:
				for id in zones:
					_dirty_views[id] = true)
	if world != null:
		# Le sol d'un bloc vient d'être (re)dessiné (tuile d'altitude arrivée,
		# terrassement…) : le calque des zones de ce bloc suit le nouveau relief.
		world.chunk_rebuilt.connect(func(k: Vector2i) -> void:
			if not zones.is_empty():
				var cs := world.chunk_size
				_mark_area(Rect2i(k * cs, Vector2i(cs, cs))))
	var shader: Shader = load("res://scripts/batiments/zone_calque.gdshader")
	for k in KINDS:
		var m := ShaderMaterial.new()
		m.shader = shader
		var c: Color = KINDS[k].color
		m.set_shader_parameter("couleur", Color(c.r, c.g, c.b, CALQUE_ALPHA))
		_mats[k] = m
	_box = MeshInstance3D.new()
	_box.mesh = BoxMesh.new()
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box.visible = false
	add_child(_box)
	# Pinceau : un cadre lumineux qui reste visible même derrière une pente.
	_box_mat = StandardMaterial3D.new()
	_box_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box_mat.no_depth_test = true
	_box_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box_mat.render_priority = 1
	_box.material_override = _box_mat


# --- Outils -------------------------------------------------------------------------

func set_paint(k: String) -> void:
	mode = Mode.PAINT
	kind = k
	_drag = false
	_update_box()
	outil_change.emit()
	info_changed.emit("Zone %s : clic gauche glissé pour peindre un rectangle (%s le m²) · clic droit ou Échap : arrêter" % [String(KINDS[k].name).to_lower(), BuildingSystem.format_money(ReglagesPartie.prix(PRICE_M2))])


func set_remove() -> void:
	mode = Mode.REMOVE
	_drag = false
	_update_box()
	outil_change.emit()
	info_changed.emit("Retirer des zones : clic gauche glissé sur les zones à effacer (les bâtiments restent).")


func set_inactive() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	_drag = false
	_update_box()
	info_changed.emit("")
	outil_change.emit()


func clear() -> void:
	for v in _views.values():
		(v as Node).queue_free()
	_views.clear()
	_dirty_views.clear()
	zones.clear()
	next_id = 1
	changed.emit()


# --- Zones --------------------------------------------------------------------------

static func zone_rect(z: Dictionary) -> Rect2i:
	return Rect2i(int(z.x), int(z.z), int(z.w), int(z.h))


## Peint une zone sur le rectangle (cases incluses). Renvoie son id ou -1.
func add_zone(k: String, rect: Rect2i) -> int:
	if not KINDS.has(k) or rect.size.x < 1 or rect.size.y < 1:
		return -1
	if rect.size.x > MAX_SIDE or rect.size.y > MAX_SIDE:
		message.emit("Zone trop grande : %d m de côté au maximum." % MAX_SIDE)
		return -1
	if area_check.is_valid():
		var why := String(area_check.call(rect))
		if why != "":
			message.emit(why)
			return -1
	# Les zones existantes recouvertes sont retirées de ce rectangle.
	remove_area(rect, false)
	var cost := ReglagesPartie.prix(rect.size.x * rect.size.y * PRICE_M2)
	if buildings != null and not buildings.unlimited_money:
		# Payé par la caisse de la ville du lieu (Pays).
		var caisse_prev := Pays.au_rect(rect)
		if cost > buildings.money:
			Pays.retour(caisse_prev)
			message.emit("Pas assez d'argent pour ce zonage : %s." % BuildingSystem.format_money(cost))
			return -1
		buildings.money -= cost
		Pays.retour(caisse_prev)
	var id := next_id
	next_id += 1
	zones[id] = {"id": id, "k": k, "x": rect.position.x, "z": rect.position.y, "w": rect.size.x, "h": rect.size.y, "s": current_style}
	_dirty_views[id] = true
	message.emit("Zone %s de %d × %d m (%s)." % [String(KINDS[k].name).to_lower(), rect.size.x, rect.size.y, BuildingSystem.format_money(cost)])
	changed.emit()
	return id


## Retire les zones sur un rectangle. Une zone coupée en partie est redécoupée.
func remove_area(rect: Rect2i, notify := true) -> int:
	var touched := 0
	for id in zones.keys():
		var z: Dictionary = zones[id]
		var zr := zone_rect(z)
		if not zr.intersects(rect):
			continue
		touched += 1
		_drop_view(id)
		zones.erase(id)
		# Reste de la zone autour du rectangle retiré (jusqu'à 4 morceaux).
		var cut := zr.intersection(rect)
		var parts: Array[Rect2i] = [
			Rect2i(zr.position.x, zr.position.y, zr.size.x, cut.position.y - zr.position.y),
			Rect2i(zr.position.x, cut.end.y, zr.size.x, zr.end.y - cut.end.y),
			Rect2i(zr.position.x, cut.position.y, cut.position.x - zr.position.x, cut.size.y),
			Rect2i(cut.end.x, cut.position.y, zr.end.x - cut.end.x, cut.size.y),
		]
		for p in parts:
			if p.size.x > 0 and p.size.y > 0:
				var nid := next_id
				next_id += 1
				zones[nid] = {"id": nid, "k": z.k, "x": p.position.x, "z": p.position.y, "w": p.size.x, "h": p.size.y, "s": String(z.get("s", ""))}
				_dirty_views[nid] = true
	if notify and touched > 0:
		message.emit("Zonage retiré.")
	if touched > 0:
		changed.emit()
	return touched


func zone_at(c: Vector2i) -> int:
	for id in zones:
		if zone_rect(zones[id]).has_point(c):
			return id
	return -1


# --- Demande et croissance ------------------------------------------------------------

## Demande pour chaque type de zone (positive : des bâtiments peuvent pousser).
func demand() -> Dictionary:
	if _demand_cache.is_empty():
		_demand_cache = _compute_demand()
	return _demand_cache.duplicate()


## Demande recalculée seulement quand les bâtiments changent.
var _demand_cache := {}
## Routes qui desservent chaque zone : id -> {rect, roads} (vidé quand le réseau change).
var _roads_cache := {}
## Index des routes par case de ROUTES_CASE m : Vector2i -> {eid: rang dans network.edges}.
var _routes_index := {}
const ROUTES_CASE := 64.0


## Routes qui ont un point dans rect, dans l'ordre de network.edges.
func _routes_dans(net: TransportNetwork, rect: Rect2i) -> Array:
	if _routes_index.is_empty():
		_routes_index[Vector2i(2147483647, 0)] = {}  # index fait, même sans route
		var rang := 0
		for eid in net.edges:
			var e: Dictionary = net.edges[eid]
			rang += 1
			if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
				continue
			for p in (e.pts as PackedVector3Array):
				var k := Vector2i(floori(p.x / ROUTES_CASE), floori(p.z / ROUTES_CASE))
				if not _routes_index.has(k):
					_routes_index[k] = {}
				_routes_index[k][eid] = rang
	var vus := {}
	var k0 := Vector2i(floori(rect.position.x / ROUTES_CASE), floori(rect.position.y / ROUTES_CASE))
	var k1 := Vector2i(floori(rect.end.x / ROUTES_CASE), floori(rect.end.y / ROUTES_CASE))
	for x in range(k0.x, k1.x + 1):
		for z in range(k0.y, k1.y + 1):
			var c: Dictionary = _routes_index.get(Vector2i(x, z), {})
			for eid in c:
				if vus.has(eid) or not net.edges.has(eid):
					continue
				for p in (net.edges[eid].pts as PackedVector3Array):
					if rect.has_point(Vector2i(floori(p.x), floori(p.z))):
						vus[eid] = int(c[eid])
						break
	var out := vus.keys()
	out.sort_custom(func(a: int, b: int) -> bool: return int(vus[a]) < int(vus[b]))
	return out


func _compute_demand() -> Dictionary:
	var homes := 0
	var jobs_c := 0
	var jobs_i := 0
	var jobs_other := 0
	var jobs_b := 0
	if buildings != null:
		for b in buildings.buildings.values():
			var t := BuildingCatalog.get_type(b.t)
			# Capacités du niveau d'agrandissement (Ameliorations).
			homes += Ameliorations.cap(b, "logements")
			var emp := Ameliorations.cap(b, "emplois")
			match t.cat:
				"commerce":
					jobs_c += emp
					if est_bureau(String(b.t)):
						jobs_b += emp
				"industrie":
					jobs_i += emp
				_:
					jobs_other += emp
	var people := homes * PEOPLE_PER_HOME
	var workers := people * 0.5
	var jobs := jobs_c + jobs_i + jobs_other
	# Commerces et industries embauchent selon la population.
	return {
		# Il vient toujours quelques habitants, et davantage s'il y a du travail.
		# 1,3 actif par emploi : environ 8 % de chômage quand la ville est à l'équilibre
		# (avec 1,8, une ville de 1 000 habitants comptait un quart de chômeurs).
		"R": 50.0 + jobs * 1.3 - workers,
		"C": people * 0.2 - jobs_c,
		"I": people * 0.25 - jobs_i,
		# Bureaux (jauge B, piste CityRT 10) : une part des emplois de commerce ; ils
		# poussent dans les zones commerciales (la demande C les compte déjà).
		"B": people * PART_BUREAUX - jobs_b,
	}


## Part des habitants qui travaillent dans des bureaux quand la ville est équilibrée.
const PART_BUREAUX := 0.06


## Bâtiment de bureaux (modèle « bureaux », gratte-ciel, ou style qui en joue le rôle).
static func est_bureau(type_id: String) -> bool:
	var base := BuildingCatalog.base_of(type_id)
	if base in ["bureaux", "gratte_ciel"]:
		return true
	return String(BuildingCatalog.get_type(type_id).get("arch", "")) in ["bureaux", "gratte_ciel"]


func _process(delta: float) -> void:
	_rebuild_dirty_views(VIEW_BUDGET_MS)
	if not growth or zones.is_empty() or buildings == null:
		return
	# Les zones se remplissent au rythme du temps (rien en pause).
	_timer += EchelleTemps.dt(delta)
	if _timer < GROW_INTERVAL:
		return
	_timer = 0.0
	grow_step()


## Une tentative de croissance dans la zone suivante. Renvoie l'id du bâtiment ou -1.
func grow_step() -> int:
	if zones.is_empty() or buildings == null or buildings.transport == null:
		return -1
	var d := demand()
	var neuf := _pousser_villages_neufs(d)
	if neuf >= 0:
		return neuf
	if peut_pousser.is_valid() and not bool(peut_pousser.call()):
		return -1
	var ids := zones.keys()
	# Le type de zone le plus demandé d'abord (logements, commerces ou industries),
	# chacun à son tour parmi ses zones : les emplois suivent les habitants.
	var kinds := d.keys().filter(func(k: String) -> bool: return float(d[k]) > 0.0)
	kinds.sort_custom(func(a: String, b: String) -> bool: return _besoin_relatif(d, a) > _besoin_relatif(d, b))
	for k in kinds:
		for n in ids.size():
			_turn = (_turn + 1) % ids.size()
			var z: Dictionary = zones[ids[_turn]]
			if String(z.k) != k:
				continue
			var bid := _grow_in(z, float(d[k]))
			if bid >= 0:
				return bid
	return -1


## Villages neufs (Communes.est_jeune) : à chaque pas, un essai dans les zones de
## l'un d'eux, chacun à son tour, avant le reste de la carte. Sans ça, leurs deux
## ou trois zones attendent derrière les dizaines de zones des grandes villes, et
## un village fondé à côté d'une ville comptait 8 à 185 habitants après 40 jours.
## Les logements y poussent même si la demande de la carte est comblée (des
## familles viennent toujours s'installer dans un village neuf), en maisons et
## petits immeubles ; commerces et activités suivent la demande.
func _pousser_villages_neufs(d: Dictionary) -> int:
	var groupes := _zones_villages_neufs()
	if groupes.is_empty():
		return -1
	var vids := groupes.keys()
	vids.sort()
	_tour_neufs = (_tour_neufs + 1) % vids.size()
	var vid := int(vids[_tour_neufs])
	if peut_pousser.is_valid() and not bool(peut_pousser.call(vid)):
		return -1
	var ids: Array = groupes[vid]
	for k in ["R", "C", "I"]:
		if k != "R" and float(d.get(k, 0.0)) <= 0.0:
			continue
		var de_k := ids.filter(func(id: int) -> bool: return String(zones[id].k) == k)
		if de_k.is_empty():
			continue
		var bid := _grow_in(zones[de_k[rng.randi() % de_k.size()]], INF if k == "R" else float(d[k]), LOGEMENTS_VILLAGE_NEUF)
		if bid >= 0:
			return bid
	return -1


## Un village neuf se bâtit de maisons et de petits immeubles, pas de tours.
const LOGEMENTS_VILLAGE_NEUF := 20
var _tour_neufs := 0
## Village de chaque zone (centre), recalculé quand les zones changent.
var _village_zone := {}
var _village_zone_cle := ""


## Zones des villages neufs : vid -> [ids de zone].
func _zones_villages_neufs() -> Dictionary:
	var cm := Communes.instance
	if cm == null or cm.villages.size() < 2:
		return {}
	var cle := "%d:%d" % [next_id, zones.size()]
	if cle != _village_zone_cle:
		_village_zone_cle = cle
		_village_zone.clear()
		for id in zones:
			var c := zone_rect(zones[id]).get_center()
			_village_zone[id] = cm.village_au_point(float(c.x), float(c.y))
	var out := {}
	for id in _village_zone:
		var vid := int(_village_zone[id])
		if vid >= 0 and zones.has(id) and cm.est_jeune(vid):
			if not out.has(vid):
				out[vid] = []
			(out[vid] as Array).append(int(id))
	return out


## Demande d'un type de zone rapportée à sa taille habituelle (un logement vaut
## ~2,3 habitants, un emploi un actif) pour comparer R, C et I.
static func _besoin_relatif(d: Dictionary, k: String) -> float:
	return float(d[k]) / (PEOPLE_PER_HOME * 0.5 if k == "R" else 1.0)


## Cherche une place le long d'une route de la zone pour un bâtiment de son type.
## need : demande du type de zone ; un gros employeur attend qu'elle suffise.
## max_logements : plafond de logements par bâtiment (village neuf : pas de tour), 0 sans plafond.
## types_force : types imposés avec leur poids (promoteurs immobiliers), sinon ceux de la zone.
func _grow_in(z: Dictionary, need := INF, max_logements := 0, types_force: Dictionary = {}) -> int:
	var rect := zone_rect(z)
	var net := buildings.transport.network
	var cached: Dictionary = _roads_cache.get(int(z.id), {})
	var roads: Array = []
	if not cached.is_empty() and cached.rect == rect:
		roads = cached.roads
	else:
		roads = _routes_dans(net, rect.grow(14))
		_roads_cache[int(z.id)] = {"rect": rect, "roads": roads}
	if roads.is_empty():
		return -1
	var types := types_force if not types_force.is_empty() else types_for(String(z.k), String(z.get("s", "")))
	if max_logements > 0:
		var petits := {}
		for id in types:
			if int(BuildingCatalog.get_type(id).get("logements", 0)) <= max_logements:
				petits[id] = types[id]
		if not petits.is_empty():
			types = petits
	for attempt in 14:
		var type_id := _pick(types)
		var t := BuildingCatalog.get_type(type_id)
		if z.k != "R" and float(t.get("emplois", 0)) > need * 1.5 + 10.0:
			continue
		var eid: int = roads[rng.randi() % roads.size()]
		var e: Dictionary = net.edges[eid]
		var s := rng.randf() * float(e.len)
		var p := net.point_at(eid, s)
		var tan := net.tangent_at(eid, s)
		var nrm := Vector3(-tan.z, 0.0, tan.x).normalized()
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var hw := float(e.get("width", 7.0)) / 2.0
		var c3 := p + nrm * side * (hw + 2.0 + float(t.d) / 2.0)
		# Façade vers la route : rotation la plus proche de la direction −nrm·side.
		var facing := -nrm * side
		var r := 0
		var best := -2.0
		for k in 4:
			var dot := BuildingSystem.front_dir(k).dot(facing)
			if dot > best:
				best = dot
				r = k
		var center := Vector2i(floori(c3.x), floori(c3.z))
		var brect := BuildingSystem.rect_for(type_id, center, r)
		if not rect.encloses(brect):
			continue
		# Valeur du quartier : les bâtiments chers poussent là où le terrain est cher.
		if extra_chance.is_valid() and rng.randf() > float(extra_chance.call(type_id, c3, types)):
			continue
		var bid := buildings.place(type_id, center, r, int(z.id))
		if bid >= 0:
			return bid
	return -1


## Types qui poussent dans une zone de type k avec le style donné (poids),
## limités à ceux déjà inventés à l'époque de la partie (Epoques).
static func types_for(k: String, style: String) -> Dictionary:
	var out := _types_for(k, style)
	if not Epoques.actif():
		return out
	var dispo := {}
	for id in out:
		if Epoques.batiment_disponible(id):
			dispo[id] = out[id]
	# Avant les modèles modernes (1950), la ville pousse dans les styles de
	# l'époque et de la région : colombages et pierre en 1800, haussmannien et
	# briques industrielles vers 1860, art déco vers 1925…
	if Epoques.annee() < 1950 or dispo.is_empty():
		dispo.merge(types_d_epoque(k), false)
	return dispo if not dispo.is_empty() else out


## Types de la bible des styles déjà inventés, de la région de la partie
## (sinon de toutes les régions) ; les styles récents poussent plus souvent.
static func types_d_epoque(k: String) -> Dictionary:
	var out := {}
	if not STYLE_ARCHS.has(k):
		return out
	var y := Epoques.annee()
	var region := Prenoms.region_for_place(GameStart.lat, GameStart.lon)
	for pass_i in 2:
		for sid in Styles.STYLES:
			var s: Dictionary = Styles.STYLES[sid]
			if pass_i == 0 and String(s.region) != region:
				continue
			if String(s.era) == "antique":
				continue
			for arch in STYLE_ARCHS[k]:
				var id := "%s__%s" % [sid, arch]
				if not BuildingCatalog.all_types().has(id) or not Epoques.batiment_disponible(id):
					continue
				var ay := Epoques.annee_batiment(id)
				var w := int(STYLE_ARCHS[k][arch])
				if ay > 0 and y - ay < 80:
					w *= 3
				out[id] = w
		if not out.is_empty():
			break
	# Bâtiments du XIXe siècle faits pour l'époque (longère, canuts, tulou…).
	if y < 1950:
		var siecle := EpoquesBatiments.pour_zone(k, region, y)
		for id in siecle:
			out[id] = int(siecle[id]) * (3 if y < 1914 else 1)
	return out


static func _types_for(k: String, style: String) -> Dictionary:
	if style == STYLE_BIBLE:
		var bible := {}
		var entrees := BibleGlb.entries()
		for id in entrees:
			if String(entrees[id].get("zone", "")) == k:
				# Les petites maisons poussent plus souvent que les grandes tours.
				var lg := int(entrees[id].get("logements", 0))
				bible[id] = int(entrees[id].get("poids", 4 if lg <= 2 else (2 if lg <= 40 else 1)))
		return bible if not bible.is_empty() else KINDS[k].types
	if style == "" or not STYLE_ARCHS.has(k):
		return KINDS[k].types
	var out := {}
	var archs: Dictionary = STYLE_ARCHS[k]
	var styles: Array = Styles.STYLES.keys() if style == "mix" else [style]
	for sid in styles:
		if not Styles.STYLES.has(sid):
			continue
		for arch in archs:
			var id := "%s__%s" % [sid, arch]
			if BuildingCatalog.all_types().has(id):
				out[id] = int(archs[arch])
	# Un style sans modèle pour ce type de zone : on garde les modèles classiques.
	return out if not out.is_empty() else KINDS[k].types


func _pick(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var x := rng.randi() % total
	for k in weights:
		x -= int(weights[k])
		if x < 0:
			return k
	return weights.keys()[0]


# --- Affichage ----------------------------------------------------------------------

func _drop_view(id: int) -> void:
	if _views.has(id):
		(_views[id] as Node).queue_free()
		_views.erase(id)
	_dirty_views.erase(id)


## Côté des morceaux de calque (m) : un bâtiment qui pousse ne redessine que ceux qu'il touche.
const VIEW_SUB := 32


## Temps maximum par image pour redessiner les calques de zones (ms).
const VIEW_BUDGET_MS := 4.0


## Redessine les morceaux de calque en attente, dans la limite du budget
## (INF : tout, par ex. dans les tests).
func _rebuild_dirty_views(budget_ms: float) -> void:
	var start := Time.get_ticks_usec()
	for id in _dirty_views.keys():
		var v: Variant = _dirty_views[id]
		if not v is Dictionary:
			# Toute la zone : on repart de zéro, morceau par morceau.
			if not zones.has(id):
				_dirty_views.erase(id)
				continue
			var holder: Node3D = _views.get(id)
			if holder != null:
				for ch in holder.get_children():
					holder.remove_child(ch)
					ch.queue_free()
			var subs := {}
			var rect := zone_rect(zones[id])
			for sx in range(floori(float(rect.position.x) / VIEW_SUB), floori(float(rect.end.x - 1) / VIEW_SUB) + 1):
				for sz in range(floori(float(rect.position.y) / VIEW_SUB), floori(float(rect.end.y - 1) / VIEW_SUB) + 1):
					subs[Vector2i(sx, sz)] = true
			_dirty_views[id] = subs
			v = subs
		var d: Dictionary = v
		for sk in d.keys():
			_rebuild_sub(id, sk)
			d.erase(sk)
			if (Time.get_ticks_usec() - start) / 1000.0 > budget_ms:
				return
		_dirty_views.erase(id)


## Marque à redessiner les morceaux de calque qui touchent rect, dans toutes les zones.
func _mark_area(rect: Rect2i) -> void:
	for id in zones:
		var r := zone_rect(zones[id]).intersection(rect.grow(1))
		if not r.has_area():
			continue
		var v: Variant = _dirty_views.get(id, {})
		if not v is Dictionary:
			continue
		var subs: Dictionary = v
		for sx in range(floori(float(r.position.x) / VIEW_SUB), floori(float(r.end.x - 1) / VIEW_SUB) + 1):
			for sz in range(floori(float(r.position.y) / VIEW_SUB), floori(float(r.end.y - 1) / VIEW_SUB) + 1):
				subs[Vector2i(sx, sz)] = true
		_dirty_views[id] = subs


## Calque coloré posé sur chaque case libre de la zone, en morceaux. Il épouse
## le relief : le dessus de chaque case et, sur une pente, le flanc des cases
## plus hautes que leur voisine (les marches du terrain). Le shader l'avance un
## peu vers la caméra pour qu'il ne disparaisse jamais dans le sol.
func _rebuild_sub(id: int, sk: Vector2i) -> void:
	if not zones.has(id) or world == null:
		return
	var z: Dictionary = zones[id]
	var rect := zone_rect(z).intersection(Rect2i(sk * VIEW_SUB, Vector2i(VIEW_SUB, VIEW_SUB)))
	var holder: Node3D = _views.get(id)
	if holder == null:
		holder = Node3D.new()
		holder.name = "Zone_%d" % id
		add_child(holder)
		_views[id] = holder
	var sub_name := "S_%d_%d" % [sk.x, sk.y]
	var mi := holder.get_node_or_null(sub_name) as MeshInstance3D
	if not rect.has_area():
		if mi != null:
			mi.queue_free()
		return
	var verts := calque_relief(rect)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = sub_name
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	mi.material_override = _mats[z.k]
	if verts.is_empty():
		mi.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = mesh


## Hauteur du calque au-dessus du sol (m) ; le shader l'avance en plus vers la caméra.
const CALQUE_Y := 0.04


## Triangles du calque d'un rectangle de cases : le dessus de chaque case libre
## (cases voisines de même hauteur réunies en bandes) et les flancs où une case
## domine sa voisine, pour que la couleur suive les marches du relief.
func calque_relief(rect: Rect2i) -> PackedVector3Array:
	var verts := PackedVector3Array()
	if world == null or not rect.has_area():
		return verts
	# Une case de marge tout autour : les flancs au bord du rectangle.
	var big := rect.grow(1)
	var hs := world.cell_heights(big)
	var bw := big.size.x
	var rw := rect.size.x
	var libre := PackedByteArray()
	libre.resize(rw * rect.size.y)
	for jj in rect.size.y:
		for ii in rw:
			var h := hs[(ii + 1) + (jj + 1) * bw]
			if not is_nan(h) and not _covered(rect.position + Vector2i(ii, jj)):
				libre[ii + jj * rw] = 1
	for jj in rect.size.y:
		var j := rect.position.y + jj
		var ii := 0
		while ii < rw:
			if libre[ii + jj * rw] == 0:
				ii += 1
				continue
			var h := hs[(ii + 1) + (jj + 1) * bw]
			# Cases voisines de même hauteur réunies en une bande.
			var e := ii
			while e + 1 < rw and libre[e + 1 + jj * rw] == 1 and hs[(e + 2) + (jj + 1) * bw] == h:
				e += 1
			var y := maxf(h, 0.0) + CALQUE_Y
			var x0 := float(rect.position.x + ii)
			var x1 := float(rect.position.x + e + 1)
			verts.append_array([Vector3(x0, y, j), Vector3(x1, y, j), Vector3(x1, y, j + 1),
				Vector3(x0, y, j), Vector3(x1, y, j + 1), Vector3(x0, y, j + 1)])
			ii = e + 1
	# Flancs : une case plus haute que sa voisine colore sa face jusqu'en bas.
	for jj in rect.size.y:
		for ii in rw:
			if libre[ii + jj * rw] == 0:
				continue
			var h := maxf(hs[(ii + 1) + (jj + 1) * bw], 0.0)
			var x := float(rect.position.x + ii)
			var zz := float(rect.position.y + jj)
			for d in 4:
				var o: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][d]
				var hn := hs[(ii + 1 + o.x) + (jj + 1 + o.y) * bw]
				if is_nan(hn):
					continue
				hn = maxf(hn, 0.0)
				if hn >= h:
					continue
				var top := h + CALQUE_Y
				var bas := hn
				match d:
					0:
						verts.append_array([Vector3(x + 1, top, zz), Vector3(x + 1, top, zz + 1), Vector3(x + 1, bas, zz + 1),
							Vector3(x + 1, top, zz), Vector3(x + 1, bas, zz + 1), Vector3(x + 1, bas, zz)])
					1:
						verts.append_array([Vector3(x, top, zz), Vector3(x, top, zz + 1), Vector3(x, bas, zz + 1),
							Vector3(x, top, zz), Vector3(x, bas, zz + 1), Vector3(x, bas, zz)])
					2:
						verts.append_array([Vector3(x, top, zz + 1), Vector3(x + 1, top, zz + 1), Vector3(x + 1, bas, zz + 1),
							Vector3(x, top, zz + 1), Vector3(x + 1, bas, zz + 1), Vector3(x, bas, zz + 1)])
					3:
						verts.append_array([Vector3(x, top, zz), Vector3(x + 1, top, zz), Vector3(x + 1, bas, zz),
							Vector3(x, top, zz), Vector3(x + 1, bas, zz), Vector3(x, bas, zz)])
	return verts


## Case cachée sous un bâtiment ou une voie : pas de calque dessus.
func _covered(c: Vector2i) -> bool:
	if buildings == null:
		return false
	return buildings.occupancy.has(c) or (buildings.transport != null and buildings.transport.is_cell_occupied(c))


func _update_box() -> void:
	if mode == Mode.NONE or not _cursor_valid:
		_box.visible = false
		return
	var a := _drag_start if _drag else _cursor
	var lo := Vector2i(mini(a.x, _cursor.x), mini(a.y, _cursor.y))
	var hi := Vector2i(maxi(a.x, _cursor.x), maxi(a.y, _cursor.y))
	var size := hi - lo + Vector2i.ONE
	# Le cadre englobe le relief du rectangle (pente comprise) : quelques
	# points relevés suffisent, même pour une grande zone.
	var hmin := INF
	var hmax := -INF
	for fx in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for fz in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var h := world.cell_height(lo + Vector2i(roundi((size.x - 1) * fx), roundi((size.y - 1) * fz)))
			if not is_nan(h):
				hmin = minf(hmin, maxf(h, 0.0))
				hmax = maxf(hmax, maxf(h, 0.0))
	if hmin == INF:
		hmin = 0.0
		hmax = 0.0
	_box.visible = true
	(_box.mesh as BoxMesh).size = Vector3(size.x, hmax - hmin + 0.8, size.y)
	_box.position = Vector3(lo.x + size.x / 2.0, (hmin + hmax) / 2.0 + 0.2, lo.y + size.y / 2.0)
	var col: Color = KINDS[kind].color if mode == Mode.PAINT else COULEUR_RETIRER
	var too_big := size.x > MAX_SIDE or size.y > MAX_SIDE
	if too_big:
		col = COULEUR_RETIRER
	_box_mat.albedo_color = Color(col.r, col.g, col.b, 0.28)
	if _drag and mode == Mode.PAINT:
		info_changed.emit("Zone %s : %d × %d m · %s%s" % [String(KINDS[kind].name).to_lower(), size.x, size.y,
			BuildingSystem.format_money(ReglagesPartie.prix(size.x * size.y * PRICE_M2)), "  ·  trop grande" if too_big else ""])


# --- Souris -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.NONE or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		_update_cursor((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0:
				set_inactive()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_update_cursor(mb.position)
		if mb.pressed and _cursor_valid:
			_drag = true
			_drag_start = _cursor
		elif not mb.pressed and _drag:
			_drag = false
			var lo := Vector2i(mini(_drag_start.x, _cursor.x), mini(_drag_start.y, _cursor.y))
			var hi := Vector2i(maxi(_drag_start.x, _cursor.x), maxi(_drag_start.y, _cursor.y))
			var rect := Rect2i(lo, hi - lo + Vector2i.ONE)
			if mode == Mode.PAINT:
				add_zone(kind, rect)
			else:
				remove_area(rect)
		_update_box()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			if _drag:
				_drag = false
				_update_box()
			else:
				set_inactive()
			get_viewport().set_input_as_handled()


func _update_cursor(screen: Vector2) -> void:
	var hit: Variant = world.pick_cell(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_cursor_valid = hit != null
	if _cursor_valid:
		_cursor = hit
	_update_box()


# --- Sauvegarde ---------------------------------------------------------------------

func summary() -> String:
	var d := demand()
	var area := surfaces()
	return "Demande  ·  R %s  ·  C %s  ·  I %s\nZones : R %d m²  ·  C %d m²  ·  I %d m²" % [
		_bar(d.R), _bar(d.C), _bar(d.I), area.R, area.C, area.I]


## Surface zonée (m²) de chaque type.
func surfaces() -> Dictionary:
	var area := {"R": 0, "C": 0, "I": 0}
	for z in zones.values():
		area[z.k] += int(z.w) * int(z.h)
	return area


static func _bar(v: float) -> String:
	if v > 50.0:
		return "forte"
	if v > 0.0:
		return "faible"
	return "nulle"


## Remplissage d'une jauge de demande (0..1) : 0 = nulle, ≈ 0,4 au seuil
## « forte » (50), pleine vers 150.
static func jauge_demande(v: float) -> float:
	if v <= 0.0:
		return 0.0
	return clampf(0.08 + v / 150.0, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"version": 1, "next_id": next_id, "growth": growth, "zones": zones.values()}


func from_dict(data: Dictionary) -> void:
	clear()
	next_id = int(data.get("next_id", 1))
	growth = bool(data.get("growth", true))
	for z in data.get("zones", []):
		var id := int(z.id)
		if not KINDS.has(String(z.k)):
			continue
		zones[id] = {"id": id, "k": String(z.k), "x": int(z.x), "z": int(z.z), "w": int(z.w), "h": int(z.h), "s": String(z.get("s", ""))}
		_dirty_views[id] = true
		next_id = maxi(next_id, id + 1)
	changed.emit()
