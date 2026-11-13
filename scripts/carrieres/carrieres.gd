class_name Carrieres
extends Node
## Carrières, gravières, argilières et mines : la roche sort vraiment du sol.
##
## - Chaque carrière, sablière, argilière et mine à ciel ouvert a un PÉRIMÈTRE
##   D'EXTRACTION (posé tout seul à côté des installations, ou dessiné par le
##   joueur). Chaque tonne extraite creuse la fosse en gradins (Fosse) : le
##   relief descend pour de bon, par passes visibles.
## - La réserve du site est le volume de roche du périmètre, jusqu'à la
##   profondeur maximale, multiplié par la richesse du gisement. Fosse pleine :
##   gisement épuisé (si l'épuisement est activé dans le panneau Admin).
## - Les stériles (découverte, roche trop pauvre) montent en VERSE à côté ;
##   ceux d'une mine souterraine forment un terril.
## - SONDAGES : la carte des ressources et l'aide de pose donnent une
##   estimation ; un sondage payant (une foreuse travaille deux jours) donne la
##   richesse exacte.
## - Fin de vie : plan d'eau, remblai et prairie, ou fosse laissée telle quelle.
## - Sur le site : pelle hydraulique et tombereaux aux heures de travail, tir
##   de mine à midi (poussière, bruit), visibles près de la caméra.

signal changed
signal message(text: String)
signal info_changed(text: String)
## Le relief a changé (au plus toutes les 5 s) : les décors posés dessus se recalent.
signal relief_change

## Paramètres des fosses par type de bâtiment.
## taille : côté du périmètre posé tout seul (m) ; gradin (m) ; risberme
## (largeur des marches, m) ; prof : profondeur maximale sous le bord (m) ;
## densite (t/m³) ; sterile : m³ de stériles par m³ de gisement ; verse : côté
## de la verse (m) ; sol : sol du fond (TerrainWorld.KIND_NAMES) ; tirs : tir
## de mine chaque jour de travail ; engin : taille des engins (1 ou 2).
const FOSSES := {
	"carriere": {"taille": 110, "gradin": 6.0, "risberme": 4, "prof": 42.0, "densite": 2.6, "sterile": 0.15,
		"verse": 60, "sol": 3, "tirs": true, "engin": 1.0},
	"sabliere": {"taille": 90, "gradin": 4.0, "risberme": 3, "prof": 8.0, "densite": 1.7, "sterile": 0.2,
		"verse": 34, "sol": 12, "tirs": false, "engin": 1.0},
	"argiliere": {"taille": 70, "gradin": 3.0, "risberme": 3, "prof": 9.0, "densite": 1.9, "sterile": 0.25,
		"verse": 30, "sol": 8, "tirs": false, "engin": 1.0},
	"mine_ciel_ouvert": {"taille": 200, "gradin": 10.0, "risberme": 6, "prof": 80.0, "densite": 2.8, "sterile": 2.0,
		"verse": 120, "sol": 3, "tirs": true, "engin": 2.0},
}
## Mines souterraines : seuls leurs stériles se voient (terril).
## sterile : tonnes de stériles par tonne extraite.
const TERRILS := {
	"mine": {"verse": 64, "densite": 2.4, "sterile": 0.4},
}
## Types de bâtiments dont la pose dépend d'un gisement du sous-sol (sondage utile).
const SONDABLES := ["carriere", "sabliere", "argiliere", "mine_ciel_ouvert", "mine", "mine_sel", "puits"]

## Une roche abattue foisonne (prend plus de place en tas).
const FOISONNEMENT := 1.3
const VERSE_GRADIN := 3.0
const VERSE_RISBERME := 3
const VERSE_HAUT := 24.0
const TERRIL_GRADIN := 2.0
const TERRIL_HAUT := 40.0
## Écart (m) entre les installations et le périmètre posé tout seul.
const ECART := 3
## Périmètre dessiné : côtés permis (m) et distance maximale des installations.
const COTE_MIN := 20
const COTE_MAX := 400
const DIST_MAX := 400.0
## Bornage, défrichement et dossier d'autorisation (€/m²).
const PRIX_M2 := 2.0
const SONDAGE_PRIX := 15000
const SONDAGE_JOURS := 2.0
## Un sondage renseigne les sites posés à moins de cette distance (m).
const SONDAGE_RAYON := 250.0
const LAC_PRIX := 60000
const REMBLAI_M3 := 3.0
## Heures de travail sur le site (jours ouvrés), heure du tir de mine.
const DEBUT := 7.0
const FIN := 17.0
const HEURE_TIR := 12.0
## Les engins ne sont dessinés qu'à cette distance de la caméra (m).
const VUE := 1800.0
const FLUSH := 0.4

const NOMS_FIN := {"lac": "plan d'eau", "remblai": "remblai et prairie", "laisser": "fosse laissée telle quelle"}

var world: TerrainWorld
var buildings: BuildingSystem
var production: Production
var transport: TransportSystem
var ambiance: DayNight
var focus: Node3D

## bid -> {t, fosse: Fosse, verse: Fosse, fin, ok, tir (jour du dernier tir), essais}
var sites: Dictionary = {}
## Sondages : {x, z, debut, fin, res: {ressource: richesse}} (res vide : en cours).
var sondages: Array = []
## Outil en cours : "" / "perimetre" / "sondage", et le site concerné.
var outil := ""
var outil_site := -1

var _dirty := true
var _pending: Dictionary = {}
var _paint: Dictionary = {}
var _flush_t := 0.0
var _relief_t := 0.0
var _relief_sale := false
var _visuels: Dictionary = {}
var _foreuses: Dictionary = {}
var _apercu: MeshInstance3D
var _drag := false
var _a := Vector2i.ZERO
var _b := Vector2i.ZERO
var _t := 0.0
var _prev_check: Callable


func setup(w: TerrainWorld, b: BuildingSystem, p: Production, t: TransportSystem, a: DayNight, f: Node3D = null) -> void:
	world = w
	buildings = b
	production = p
	transport = t
	ambiance = a
	focus = f
	add_to_group("pollution_sources")
	_prev_check = buildings.extra_check
	buildings.extra_check = check_place
	buildings.changed.connect(func() -> void: _dirty = true)
	production.extraction_gate = gate
	production.extrait.connect(_on_extrait)


func clear() -> void:
	for bid in _visuels.keys():
		_drop_visuel(bid)
	for k in _foreuses.keys():
		(_foreuses[k] as Node).queue_free()
	_foreuses.clear()
	sites.clear()
	sondages.clear()
	_pending.clear()
	_paint.clear()
	set_inactive()
	_dirty = true
	changed.emit()


static func is_fosse(type_id: String) -> bool:
	return FOSSES.has(type_id)


func _type_of(bid: int) -> String:
	return String(buildings.buildings.get(bid, {}).get("t", ""))


# --- Règle de pose ----------------------------------------------------------------------

## Enveloppe la règle de pose de Production : pas de bâtiment sur une fosse ;
## sans sondage, la richesse d'un gisement n'est qu'une estimation.
func check_place(id: String, rect: Rect2i) -> Dictionary:
	for bid in sites:
		var r: Dictionary = sites[bid]
		for k in ["fosse", "verse"]:
			var f: Fosse = r.get(k)
			if f != null and f.rect.intersects(rect):
				return {"reason": "Une fosse ou une verse d'extraction occupe l'emplacement."}
	var res: Dictionary = _prev_check.call(id, rect) if _prev_check.is_valid() else {}
	if not id in SONDABLES or String(res.get("reason", "")) != "" or String(res.get("info", "")) == "":
		return res
	var info := String(res.info)
	if FOSSES.has(id):
		var p: Dictionary = FOSSES[id]
		info += " · fosse de %d × %d m creusée à côté" % [p.taille, p.taille]
	if not sonde_pres(rect):
		info = _estimation(info, rect)
	else:
		info += " · sondé"
	res.info = info
	return res


## Un sondage terminé près de rect ?
func sonde_pres(rect: Rect2i) -> bool:
	var c := Vector2(rect.get_center())
	for s in sondages:
		if not (s.res as Dictionary).is_empty() and Vector2(float(s.x), float(s.z)).distance_to(c) <= SONDAGE_RAYON:
			return true
	return false


## Remplace « richesse 52 % » par une fourchette, et retire les tonnages.
func _estimation(info: String, rect: Rect2i) -> String:
	var re := RegEx.new()
	re.compile("richesse (\\d+) %")
	var m := re.search(info)
	if m == null:
		return info
	var v := int(m.get_string(1))
	var h := absf(sin(float(rect.position.x) * 12.9898 + float(rect.position.y) * 78.233) * 43758.5453)
	var a := 0.15 + 0.2 * fmod(h, 1.0)
	var b := 0.15 + 0.2 * fmod(h * 7.0, 1.0)
	var lo := maxi(5, roundi(v * (1.0 - a) / 5.0) * 5)
	var hi := maxi(lo + 5, roundi(v * (1.0 + b) / 5.0) * 5)
	var out := info.substr(0, m.get_start()) + "richesse estimée %d à %d %%" % [lo, hi]
	var rest := info.substr(m.get_end())
	var parts := rest.split(" · ")
	var keep: Array[String] = []
	for i in parts.size():
		var p := String(parts[i])
		if p.begins_with("environ") or p.begins_with("réserve"):
			continue
		keep.append(p)
	return out + " · ".join(keep) + " (sondage conseillé : P → Mines)"


# --- Lien avec la production ---------------------------------------------------------------

## Raison qui empêche d'extraire (vide : la production peut tourner).
func gate(bid: int) -> String:
	if not sites.has(bid):
		return ""
	var r: Dictionary = sites[bid]
	if String(r.get("fin", "")) != "":
		return "Site fermé : %s" % NOMS_FIN.get(String(r.fin), String(r.fin))
	if not FOSSES.has(String(r.t)):
		return ""
	if r.get("fosse") == null:
		if int(r.get("essais", 0)) >= 3:
			return "Pas de place libre pour la fosse : dessine le périmètre d'extraction (P → Mines)"
		return "Préparation du périmètre d'extraction…"
	if not bool(r.get("ok", false)):
		return "Relevé du gisement dans le périmètre…"
	var s: Dictionary = production.sites.get(bid, {})
	if s.is_empty():
		return ""
	var need := float(ProductionTypes.prod_of(String(r.t)).get("min", 0.1))
	if float(s.rich) < need:
		return "Périmètre trop pauvre (%d %%, il faut %d %%) : dessine-le ailleurs (P → Mines)" % [roundi(float(s.rich) * 100.0), roundi(need * 100.0)]
	return ""


## Facteur de richesse utilisé pour convertir tonnes et volumes.
static func _rf(rich: float) -> float:
	return clampf(rich, 0.3, 1.0)


## Réserve en tonnes d'une fosse, à la richesse rich.
static func reserve_de(type_id: String, f: Fosse, rich: float) -> float:
	var p: Dictionary = FOSSES[type_id]
	return f.restant() / (1.0 + float(p.sterile)) * float(p.densite) * _rf(rich)


## Volume creusé (m³) pour t tonnes de marchandise.
static func volume_pour(type_id: String, t: float, rich: float) -> float:
	var p: Dictionary = FOSSES[type_id]
	return t / float(p.densite) / _rf(rich) * (1.0 + float(p.sterile))


func _on_extrait(bid: int, _res: String, t: float) -> void:
	if not sites.has(bid) or t <= 0.0:
		return
	var r: Dictionary = sites[bid]
	var type_id := String(r.t)
	var s: Dictionary = production.sites.get(bid, {})
	var rich := float(s.get("rich", 0.5))
	var verse: Fosse = r.get("verse")
	if FOSSES.has(type_id):
		var f: Fosse = r.get("fosse")
		if f == null:
			return
		var p: Dictionary = FOSSES[type_id]
		var v := volume_pour(type_id, t, rich)
		if f.pleine():
			return
		var ch := f.avancer(v)
		for c in ch:
			_pending[c] = ch[c]
			_paint[c] = int(p.sol)
		if verse != null and not verse.pleine():
			var ch2 := verse.avancer(v * float(p.sterile) / (1.0 + float(p.sterile)) * FOISONNEMENT)
			for c in ch2:
				_pending[c] = ch2[c]
				_paint[c] = 5
	elif TERRILS.has(type_id) and verse != null and not verse.pleine():
		var q: Dictionary = TERRILS[type_id]
		var ch3 := verse.avancer(t * float(q.sterile) / float(q.densite) * FOISONNEMENT)
		for c in ch3:
			_pending[c] = ch3[c]
			_paint[c] = 3


## Applique au relief les passes en attente (par lots, sans message de terrain).
func flush() -> void:
	if _pending.is_empty():
		return
	for c in _paint:
		world.biome_paint[c] = float(_paint[c])
	for c in _pending:
		world.modifications[c] = float(_pending[c])
		world.water_cells.erase(c)
	world.mark_cells_dirty(_pending.keys())
	_relief_sale = true
	_pending.clear()
	_paint.clear()
	changed.emit()


# --- Sites et périmètres -------------------------------------------------------------------

func _sync() -> void:
	_dirty = false
	for bid in sites.keys():
		if not buildings.buildings.has(bid) or _type_of(bid) != String(sites[bid].t):
			# Démoli : le trou reste, mais plus personne ne l'exploite.
			_drop_visuel(bid)
			sites.erase(bid)
	for bid in buildings.buildings:
		var t := _type_of(bid)
		if not (FOSSES.has(t) or TERRILS.has(t)):
			continue
		if not sites.has(bid):
			sites[bid] = {"t": t, "fosse": null, "verse": null, "fin": "", "ok": false, "tir": -1, "essais": 0}
		var r: Dictionary = sites[bid]
		if FOSSES.has(t) and r.fosse == null and int(r.essais) < 3:
			_auto(bid)
		elif TERRILS.has(t) and r.verse == null and int(r.essais) < 3:
			_auto_terril(bid)


func _brect(bid: int) -> Rect2i:
	return buildings._rect_of(buildings.buildings[bid])


## Rectangle de côté (sx, sz) collé au côté `side` (0 nord, 1 est, 2 sud, 3 ouest) de r.
static func _beside(r: Rect2i, side: int, sx: int, sz: int, gap := ECART) -> Rect2i:
	var c := r.get_center()
	match side:
		0:
			return Rect2i(c.x - sx / 2, r.position.y - gap - sz, sx, sz)
		1:
			return Rect2i(r.end.x + gap, c.y - sz / 2, sx, sz)
		2:
			return Rect2i(c.x - sx / 2, r.end.y + gap, sx, sz)
		_:
			return Rect2i(r.position.x - gap - sx, c.y - sz / 2, sx, sz)


## Le rectangle est-il libre (relief chargé, ni bâtiment, ni voie, ni eau, ni autre fosse) ?
## Renvoie "" ou la raison.
func libre(rect: Rect2i, except := -1) -> String:
	for bid in sites:
		for k in ["fosse", "verse"]:
			var f: Fosse = sites[bid].get(k)
			if f != null and f.rect.intersects(rect) and not (bid == except and k == "fosse"):
				return "Une autre fosse ou verse est là."
	for bid in buildings.buildings:
		if _brect(bid).intersects(rect):
			return "Un bâtiment est sur le périmètre."
	var step := 2
	for z in range(rect.position.y, rect.end.y, step):
		for x in range(rect.position.x, rect.end.x, step):
			var c := Vector2i(x, z)
			if transport != null and transport.is_cell_occupied(c):
				return "Une voie traverse le périmètre."
			if x % 4 == 0 and z % 4 == 0:
				var h := world.cell_height(c)
				if is_nan(h):
					return "Relief encore en chargement."
				if h < 0.0 or world.water_cells.has(c):
					return "De l'eau est dans le périmètre."
				if x % 12 == 0 and z % 12 == 0 and world.cell_biome(c) == 80:
					return "Un lac ou une rivière est dans le périmètre."
	return ""


func _heights(rect: Rect2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(rect.size.x * rect.size.y)
	for j in rect.size.y:
		for i in rect.size.x:
			out[i + j * rect.size.x] = world.cell_height(rect.position + Vector2i(i, j))
	return out


## Fosse sur rect pour le site bid ; le front part du côté des installations.
func _make_fosse(bid: int, rect: Rect2i) -> Fosse:
	var p: Dictionary = FOSSES[String(sites[bid].t)]
	var f := Fosse.new()
	f.gradin = float(p.gradin)
	f.risberme = int(p.risberme)
	f.profondeur = float(p.prof)
	var bc := Vector2(_brect(bid).get_center())
	var rc := Vector2(rect.get_center())
	var d := bc - rc
	if absf(d.x) > absf(d.y):
		f.depart = 1 if d.x > 0.0 else 3
	else:
		f.depart = 2 if d.y > 0.0 else 0
	f.preparer(rect, _heights(rect), -1)
	return f


func _make_verse(rect: Rect2i, terril := false) -> Fosse:
	var v := Fosse.new()
	v.gradin = TERRIL_GRADIN if terril else VERSE_GRADIN
	v.risberme = 1 if terril else VERSE_RISBERME
	v.profondeur = TERRIL_HAUT if terril else VERSE_HAUT
	v.preparer(rect, _heights(rect), 1)
	return v


## Pose le périmètre tout seul : le côté libre le plus riche, puis la verse sur un autre côté.
func _auto(bid: int) -> void:
	var r: Dictionary = sites[bid]
	var p: Dictionary = FOSSES[String(r.t)]
	var br := _brect(bid)
	var prod := ProductionTypes.prod_of(String(r.t))
	var best := {}
	var loading := false
	for scale in [1.0, 0.7, 0.5]:
		var size := int(int(p.taille) * scale)
		for side in 4:
			var rect := _beside(br, side, size, size)
			var why := libre(rect)
			if why == "Relief encore en chargement.":
				loading = true
				continue
			if why != "":
				continue
			var m := production.carte.best_of((prod.res as Dictionary).keys(), rect)
			if float(m.rich) < 0.0:
				loading = true
				continue
			if best.is_empty() or float(m.rich) > float(best.rich) + 0.02:
				best = {"rect": rect, "rich": float(m.rich), "side": side}
		if not best.is_empty():
			break
	if best.is_empty():
		if not loading:
			r.essais = int(r.essais) + 1
		return
	r.fosse = _make_fosse(bid, best.rect)
	r.ok = false
	r.verse = _place_verse(br, (r.fosse as Fosse).rect, int(p.verse), int(best.side))
	changed.emit()


## Verse à côté des installations (pas du côté de la fosse), sinon à côté de la fosse.
func _place_verse(br: Rect2i, pit: Rect2i, vs: int, pit_side: int) -> Fosse:
	var tries := []
	for side in [1, 3, 2, 0]:
		var sd: int = (pit_side + side) % 4 if pit_side >= 0 else side
		if sd != pit_side:
			tries.append(_beside(br, sd, vs, vs, ECART + 2))
	for side in 4:
		tries.append(_beside(pit, side, vs, vs, ECART + 2))
	for scale in [1.0, 0.7]:
		for vr: Rect2i in tries:
			var rr := vr
			if scale < 1.0:
				var n := int(vs * scale)
				rr = Rect2i(vr.get_center() - Vector2i(n / 2, n / 2), Vector2i(n, n))
			if not rr.intersects(pit) and libre(rr) == "":
				return _make_verse(rr)
	return null


func _auto_terril(bid: int) -> void:
	var r: Dictionary = sites[bid]
	var q: Dictionary = TERRILS[String(r.t)]
	var br := _brect(bid)
	var loading := false
	for side in [0, 1, 2, 3]:
		var vr := _beside(br, side, int(q.verse), int(q.verse))
		var why := libre(vr)
		if why == "Relief encore en chargement.":
			loading = true
		elif why == "":
			r.verse = _make_verse(vr, true)
			changed.emit()
			return
	if not loading:
		r.essais = int(r.essais) + 1


## Richesse et réserve du site d'après son périmètre (une fois Production prête).
func _relever(bid: int) -> void:
	var r: Dictionary = sites[bid]
	var s: Dictionary = production.sites.get(bid, {})
	var f: Fosse = r.get("fosse")
	if s.is_empty() or f == null or float(s.rich) < 0.0:
		return
	var prod := ProductionTypes.prod_of(String(r.t))
	var m := production.carte.best_of((prod.res as Dictionary).keys(), f.rect)
	if float(m.rich) < 0.0:
		return
	if String(m.res) != "":
		s.res = String(m.res)
		s.rich = float(m.rich)
	s.reserve = reserve_de(String(r.t), f, float(s.rich))
	r.ok = true
	changed.emit()


## Nouveau périmètre dessiné par le joueur pour le site bid. Renvoie "" ou la raison.
func set_perimetre(bid: int, rect: Rect2i, pay := true) -> String:
	if not sites.has(bid) or not FOSSES.has(String(sites[bid].t)):
		return "Ce site n'a pas de fosse."
	if rect.size.x < COTE_MIN or rect.size.y < COTE_MIN:
		return "Périmètre trop petit (au moins %d × %d m)." % [COTE_MIN, COTE_MIN]
	if rect.size.x > COTE_MAX or rect.size.y > COTE_MAX:
		return "Périmètre trop grand (au plus %d × %d m)." % [COTE_MAX, COTE_MAX]
	var br := _brect(bid)
	var gap := Vector2(maxf(0.0, maxf(br.position.x - rect.end.x, rect.position.x - br.end.x)),
		maxf(0.0, maxf(br.position.y - rect.end.y, rect.position.y - br.end.y)))
	if gap.length() > DIST_MAX:
		return "Trop loin des installations (au plus %d m)." % int(DIST_MAX)
	var why := libre(rect, bid)
	if why != "":
		return why
	var cost := ReglagesPartie.prix(roundi(rect.size.x * rect.size.y * PRIX_M2))
	if pay and not buildings.unlimited_money:
		if buildings.money < cost:
			return "Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(cost)
		buildings.money -= cost
	var r: Dictionary = sites[bid]
	r.fosse = _make_fosse(bid, rect)
	r.fin = ""
	r.ok = false
	r.essais = 0
	if r.verse == null:
		r.verse = _place_verse(br, rect, int(FOSSES[String(r.t)].verse), -1)
	message.emit("Nouveau périmètre d'extraction de %d × %d m (%s)." % [rect.size.x, rect.size.y, BuildingSystem.format_money(cost)])
	changed.emit()
	return ""


# --- Fin de vie ----------------------------------------------------------------------------

## Réaménage la fosse du site : "lac", "remblai" ou "laisser". Renvoie "" ou la raison.
func reamenager(bid: int, kind: String) -> String:
	if not sites.has(bid):
		return "Site inconnu."
	var r: Dictionary = sites[bid]
	var f: Fosse = r.get("fosse")
	if f == null:
		return "Ce site n'a pas de fosse."
	flush()
	var cost := 0
	match kind:
		"lac":
			cost = LAC_PRIX
		"remblai":
			cost = roundi(f.vol * REMBLAI_M3)
		"laisser":
			cost = 0
		_:
			return "Réaménagement inconnu."
	cost = ReglagesPartie.prix(cost)
	if not buildings.unlimited_money and buildings.money < cost:
		return "Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(cost)
	if not buildings.unlimited_money:
		buildings.money -= cost
	var cells := f.cases_modifiees()
	match kind:
		"lac":
			# Le plan d'eau monte jusqu'à 1 m sous le point le plus bas du bord.
			var bord := INF
			var w := f.rect.size.x
			for i in f.h0.size():
				var x := i % w
				var z := i / w
				if (x == 0 or z == 0 or x == w - 1 or z == f.rect.size.y - 1) and not is_nan(f.h0[i]):
					bord = minf(bord, f.h0[i])
			var lvl := bord - 1.0
			for c in cells:
				if float(cells[c]) < lvl - 0.4:
					world.water_cells[c] = lvl - TerrainWorld.WATER_SURFACE_DROP
					world.biome_paint.erase(c)
		"remblai":
			var w2 := f.rect.size.x
			for c in cells:
				var p: Vector2i = c - f.rect.position
				world.modifications[c] = f.h0[p.x + p.y * w2]
				world.biome_paint[c] = 6.0
				f.cur[p.x + p.y * w2] = f.h0[p.x + p.y * w2]
	world.mark_cells_dirty(cells.keys())
	r.fin = kind
	_drop_visuel(bid)
	message.emit("%s : %s (%s)." % [BuildingCatalog.get_type(String(r.t)).get("name", r.t), NOMS_FIN[kind], BuildingSystem.format_money(cost)])
	changed.emit()
	return ""


# --- Sondages ------------------------------------------------------------------------------

## Lance un sondage sur la case c. Renvoie "" ou la raison.
func sonder(c: Vector2i) -> String:
	var h := world.cell_height(c)
	if is_nan(h):
		return "Relief encore en chargement."
	if h < 0.0 or world.water_cells.has(c):
		return "On ne sonde pas dans l'eau."
	var cost := ReglagesPartie.prix(SONDAGE_PRIX)
	if not buildings.unlimited_money:
		if buildings.money < cost:
			return "Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(cost)
		buildings.money -= cost
	var now := ambiance.unix_time if ambiance != null else 0.0
	sondages.append({"x": c.x, "z": c.y, "debut": now, "fin": now + SONDAGE_JOURS * 86400.0, "res": {}})
	message.emit("Sondage lancé (%s) : résultats dans %d jours." % [BuildingSystem.format_money(cost), int(SONDAGE_JOURS)])
	changed.emit()
	return ""


## Ressources du sol et du sous-sol mesurées par un sondage en c.
func mesurer(c: Vector2i) -> Dictionary:
	var out := {}
	var rect := Rect2i(c - Vector2i(15, 15), Vector2i(30, 30))
	for res in ["pierre", "calcaire", "granite", "sable", "argile"] + Ressources.SOUS_SOL:
		var m := production.carte.mean_in(res, rect)
		if m < 0.0:
			return {}
		out[res] = snappedf(m, 0.01)
	return out


func _sondages_tick() -> void:
	var now := ambiance.unix_time if ambiance != null else 0.0
	for s in sondages:
		if not (s.res as Dictionary).is_empty() or now < float(s.fin):
			continue
		var m := mesurer(Vector2i(int(s.x), int(s.z)))
		if m.is_empty():
			continue
		s.res = m
		message.emit("Sondage terminé : " + resume_sondage(s))
		changed.emit()


## « calcaire 62 %, granite 20 %, fer 8 % » (les trois plus riches).
static func resume_sondage(s: Dictionary) -> String:
	var res: Dictionary = s.res
	if res.is_empty():
		return "en cours"
	var keys := res.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(res[a]) > float(res[b]))
	var parts: Array[String] = []
	for k in keys.slice(0, 3):
		if float(res[k]) <= 0.01:
			continue
		parts.append("%s %d %%" % [String(Ressources.naturelle(k).name).to_lower(), roundi(float(res[k]) * 100.0)])
	return ", ".join(parts) if not parts.is_empty() else "rien d'exploitable"


# --- Informations (panneau) ------------------------------------------------------------------

## Fiche d'un site pour le panneau Mines.
func info(bid: int) -> Dictionary:
	if not sites.has(bid) or not buildings.buildings.has(bid):
		return {}
	var r: Dictionary = sites[bid]
	var t := String(r.t)
	var s: Dictionary = production.sites.get(bid, {})
	var out := {"bid": bid, "t": t, "name": BuildingCatalog.get_type(t).get("name", t), "fin": String(r.fin),
		"status": String(s.get("status", "")), "pos": _pos(bid), "fosse": FOSSES.has(t)}
	if String(s.get("res", "")) != "":
		out["res"] = Ressources.naturelle(String(s.res)).name
		out["rich"] = float(s.rich)
	if float(s.get("reserve", -1.0)) >= 0.0:
		out["reserve"] = float(s.reserve)
	var per_day := 0.0
	var prod := ProductionTypes.prod_of(t)
	if String(s.get("res", "")) != "" and (prod.get("res", {}) as Dictionary).has(String(s.res)):
		per_day = float(prod.res[String(s.res)]) * float(s.rich) * float(s.get("eff", 0.0))
	out["par_jour"] = per_day
	var f: Fosse = r.get("fosse")
	if f != null:
		out["rect"] = f.rect
		out["prof"] = f.profondeur_actuelle()
		out["prof_max"] = f.profondeur
		out["gradin"] = f.gradin_actuel()
		out["gradins"] = f.nb_gradins()
		out["part"] = clampf(f.vol / maxf(f.capacite(), 1.0), 0.0, 1.0)
		out["pleine"] = f.pleine()
	var v: Fosse = r.get("verse")
	if v != null:
		out["verse_h"] = v.profondeur_actuelle()
		out["verse_part"] = clampf(v.vol / maxf(v.capacite(), 1.0), 0.0, 1.0)
	return out


func _pos(bid: int) -> Vector3:
	var b: Dictionary = buildings.buildings[bid]
	var c := Vector2(_brect(bid).get_center())
	return Vector3(c.x, float(b.get("h", 0.0)), c.y)


## Sources de nuisances (bruit, poussière) pour la pollution et la valeur foncière :
## [{pos: Vector3, bruit: dB à 10 m, rayon: m, poussiere: 0-1, actif: bool, tir: bool}].
func nuisances() -> Array:
	var out := []
	for bid in sites:
		var r: Dictionary = sites[bid]
		if String(r.fin) != "" or not buildings.buildings.has(bid):
			continue
		var t := String(r.t)
		var s: Dictionary = production.sites.get(bid, {})
		var act := float(s.get("eff", 0.0)) > 0.0
		var f: Fosse = r.get("fosse")
		var pos := _pos(bid)
		if f != null:
			var c := Vector2(f.rect.get_center())
			pos = Vector3(c.x, pos.y, c.y)
		var tirs := bool(FOSSES.get(t, {}).get("tirs", false))
		out.append({"bid": bid, "pos": pos, "bruit": 85.0 if tirs else 75.0, "rayon": 600.0 if tirs else 300.0,
			"poussiere": 0.7 if tirs else 0.4, "actif": act, "tir": tirs})
	return out


## Contrat commun de la pollution (groupe « pollution_sources ») : bruit et
## poussière de 0 à 1, eau (fines rejetées), nuit : le site travaille la nuit.
func pollution_sources() -> Array:
	var out := []
	for n in nuisances():
		var t := String(sites[n.bid].t)
		var k := 1.0 if bool(n.actif) else 0.15
		out.append({"bid": n.bid, "pos": n.pos, "rayon": float(n.rayon), "bruit": clampf((float(n.bruit) - 35.0) / 45.0, 0.0, 1.0) * k,
			"air": float(n.poussiere) * k, "eau": (0.5 if t in ["sabliere", "mine_ciel_ouvert"] else 0.25) * k, "nuit": false,
			"nom": String(BuildingCatalog.get_type(t).get("name", t))})
	return out


# --- Outils (périmètre, sondage) ----------------------------------------------------------------

func start_tool(mode: String, bid := -1) -> void:
	outil = mode
	outil_site = bid
	_drag = false
	if mode == "perimetre":
		info_changed.emit("Périmètre d'extraction : glisse pour dessiner un rectangle (%d à %d m de côté, %s le m²). Clic droit : annuler." % [
			COTE_MIN, COTE_MAX, BuildingSystem.format_money(int(PRIX_M2))])
	elif mode == "sondage":
		info_changed.emit("Sondage : clique où forer (%s, résultats en %d jours). Clic droit : annuler." % [
			BuildingSystem.format_money(ReglagesPartie.prix(SONDAGE_PRIX)), int(SONDAGE_JOURS)])
	_update_apercu()


func set_inactive() -> void:
	outil = ""
	outil_site = -1
	_drag = false
	if _apercu:
		_apercu.visible = false


func _cell_at(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	return world.pick_cell(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


func _unhandled_input(event: InputEvent) -> void:
	if outil == "":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			set_inactive()
			info_changed.emit("")
			get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit: Variant = _cell_at(mb.position)
		get_viewport().set_input_as_handled()
		if hit == null:
			return
		if outil == "sondage":
			if mb.pressed:
				var why := sonder(hit)
				if why != "":
					message.emit(why)
			return
		if mb.pressed:
			_drag = true
			_a = hit
			_b = hit
		elif _drag:
			_drag = false
			_b = hit
			var why2 := set_perimetre(outil_site, _rect_ab())
			if why2 != "":
				message.emit(why2)
			else:
				set_inactive()
				info_changed.emit("")
		_update_apercu()
	elif event is InputEventMouseMotion and _drag:
		var hit2: Variant = _cell_at((event as InputEventMouseMotion).position)
		if hit2 != null:
			_b = hit2
			_update_apercu()
			var r := _rect_ab()
			info_changed.emit("Périmètre : %d × %d m · %s" % [r.size.x, r.size.y,
				BuildingSystem.format_money(ReglagesPartie.prix(roundi(r.size.x * r.size.y * PRIX_M2)))])


func _rect_ab() -> Rect2i:
	var p := Vector2i(mini(_a.x, _b.x), mini(_a.y, _b.y))
	return Rect2i(p, Vector2i(absi(_a.x - _b.x) + 1, absi(_a.y - _b.y) + 1))


func _update_apercu() -> void:
	if _apercu == null:
		_apercu = MeshInstance3D.new()
		_apercu.name = "ApercuPerimetre"
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.75, 0.2, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_apercu.material_override = m
		_apercu.mesh = BoxMesh.new()
		add_child(_apercu)
	_apercu.visible = outil == "perimetre" and _drag
	if not _apercu.visible:
		return
	var r := _rect_ab()
	var hs: Array[float] = []
	for c in [r.position, r.end - Vector2i.ONE, Vector2i(r.position.x, r.end.y - 1), Vector2i(r.end.x - 1, r.position.y), r.get_center()]:
		var h := world.cell_height(c)
		if not is_nan(h):
			hs.append(h)
	var lo: float = hs.min() if not hs.is_empty() else 0.0
	var hi: float = hs.max() if not hs.is_empty() else 0.0
	(_apercu.mesh as BoxMesh).size = Vector3(r.size.x, hi - lo + 6.0, r.size.y)
	_apercu.position = Vector3(r.position.x + r.size.x * 0.5, (lo + hi) * 0.5, r.position.y + r.size.y * 0.5)


# --- Vie du site : engins, tirs ----------------------------------------------------------------

func _process(delta: float) -> void:
	if _dirty and world != null:
		_sync()
	for bid in sites:
		var r: Dictionary = sites[bid]
		if r.get("fosse") != null and not bool(r.get("ok", false)):
			_relever(bid)
	_flush_t += delta
	if _flush_t >= FLUSH:
		_flush_t = 0.0
		flush()
		_sondages_tick()
	_relief_t += delta
	if _relief_sale and _relief_t >= 5.0:
		_relief_t = 0.0
		_relief_sale = false
		relief_change.emit()
	_t += delta
	_anime(delta)


func _focus_pos() -> Vector3:
	if focus != null:
		return focus.global_position
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else Vector3.ZERO


## Le site travaille-t-il en ce moment (jour ouvré, heures de travail, personnel) ?
func au_travail(bid: int) -> bool:
	var s: Dictionary = production.sites.get(bid, {})
	if float(s.get("eff", 0.0)) <= 0.0 or String(sites[bid].get("fin", "")) != "":
		return false
	if ambiance == null:
		return true
	var lt := production.local_time(ambiance.unix_time)
	return int(lt.wd) >= 1 and int(lt.wd) <= 5 and float(lt.h) >= DEBUT and float(lt.h) < FIN


func _anime(_delta: float) -> void:
	var fp := _focus_pos()
	var lt := production.local_time(ambiance.unix_time) if ambiance != null else {"h": 12.0, "day": 0}
	for bid in sites:
		var r: Dictionary = sites[bid]
		var f: Fosse = r.get("fosse")
		if f == null or not buildings.buildings.has(bid):
			continue
		var c := Vector2(f.rect.get_center())
		var near := Vector2(fp.x, fp.z).distance_to(c) < VUE + f.rect.size.length() * 0.5
		var work := near and au_travail(bid)
		if not work:
			_drop_visuel(bid)
		else:
			_show_visuel(bid, r, f)
		# Tir de mine : une fois par jour de travail, à midi.
		var p: Dictionary = FOSSES.get(String(r.t), {})
		if bool(p.get("tirs", false)) and au_travail(bid) and float(lt.h) >= HEURE_TIR and int(r.get("tir", -1)) != int(lt.day):
			r.tir = int(lt.day)
			_tir(bid, f, near)
	_anime_foreuses(fp)


func _front_pos(f: Fosse) -> Vector3:
	var c := f.front
	if c.x < 0:
		c = f.rect.get_center()
	var h := f.hauteur(c)
	if is_nan(h):
		h = world.cell_height(c)
	return Vector3(c.x + 0.5, h, c.y + 0.5)


func _show_visuel(bid: int, r: Dictionary, f: Fosse) -> void:
	var p: Dictionary = FOSSES[String(r.t)]
	var s := float(p.engin)
	if not _visuels.has(bid):
		var root := Node3D.new()
		root.name = "Engins%d" % bid
		root.add_child(EnginsCarriere.pelle(s))
		var n := 2 if s > 1.5 else 1
		for i in n:
			var tb := EnginsCarriere.tombereau(s)
			tb.name = "Tombereau%d" % i
			root.add_child(tb)
		add_child(root)
		_visuels[bid] = root
	var root2: Node3D = _visuels[bid]
	var fr := _front_pos(f)
	# La pelle se tient sur le gradin, en retrait du front, côté fosse.
	var inside := Vector2(f.rect.get_center()) - Vector2(fr.x, fr.z)
	var off := inside.normalized() * 5.0 * s if inside.length() > 1.0 else Vector2.ZERO
	var pc := Vector2i(floori(fr.x + off.x), floori(fr.z + off.y))
	var ph := f.hauteur(pc)
	if is_nan(ph):
		ph = fr.y
	var pelle: Node3D = root2.get_node("Pelle")
	pelle.position = Vector3(pc.x + 0.5, ph, pc.y + 0.5)
	_face(pelle, Vector3(fr.x, ph, fr.z))
	var tour: Node3D = pelle.get_node("Tourelle")
	var cycle := fmod(_t / 9.0, 1.0)
	tour.rotation.y = sin(cycle * TAU) * 1.4
	(tour.get_node("Bras") as Node3D).rotation.x = -0.25 + 0.35 * sin(cycle * TAU * 2.0)
	# Tombereaux : de la pelle aux installations et retour.
	var dest := _pos(bid)
	var a := pelle.position + Vector3(4.0 * s, 0, 0)
	var n2 := root2.get_child_count() - 1
	for i in n2:
		var tb2: Node3D = root2.get_node("Tombereau%d" % i)
		var u := fmod(_t / (36.0 * s) + float(i) / n2, 1.0)
		var pos: Vector3
		var vide := u >= 0.5
		var tilt := 0.0
		if u < 0.1:
			pos = a
		elif u < 0.45:
			pos = a.lerp(dest, (u - 0.1) / 0.35)
		elif u < 0.55:
			pos = dest
			tilt = sin((u - 0.45) / 0.1 * PI) * 0.9
		else:
			pos = dest.lerp(a, (u - 0.55) / 0.45)
		var g := world.cell_height(Vector2i(floori(pos.x), floori(pos.z)))
		pos.y = g if not is_nan(g) else pos.y
		var target := dest if u < 0.5 else a
		tb2.position = pos
		_face(tb2, Vector3(target.x, pos.y, target.z))
		var benne: Node3D = tb2.get_node("Benne")
		benne.rotation.x = tilt
		(benne.get_node("Charge") as Node3D).visible = not vide or tilt > 0.2


## Tourne un engin (repère : il regarde vers −Z) vers p, sur le plan horizontal.
static func _face(n: Node3D, p: Vector3) -> void:
	var d := Vector2(p.x - n.position.x, p.z - n.position.z)
	if d.length() > 0.3:
		n.rotation = Vector3(0, atan2(-d.x, -d.y), 0)


func _drop_visuel(bid: int) -> void:
	if _visuels.has(bid):
		(_visuels[bid] as Node).queue_free()
		_visuels.erase(bid)


func _tir(bid: int, f: Fosse, near: bool) -> void:
	if not near:
		return
	var fr := _front_pos(f)
	var dust := EnginsCarriere.poussiere(10.0 * float(FOSSES[String(sites[bid].t)].engin))
	add_child(dust)
	dust.position = fr + Vector3(0, 2, 0)
	dust.emitting = true
	get_tree().create_timer(dust.lifetime + 1.0).timeout.connect(dust.queue_free)
	message.emit("Tir de mine à %s : poussière et bruit pendant quelques secondes." % String(BuildingCatalog.get_type(String(sites[bid].t)).get("name", "")).to_lower())


func _anime_foreuses(fp: Vector3) -> void:
	var live := {}
	for i in sondages.size():
		var s: Dictionary = sondages[i]
		if not (s.res as Dictionary).is_empty():
			continue
		var p := Vector3(float(s.x) + 0.5, 0, float(s.z) + 0.5)
		if Vector2(p.x, p.z).distance_to(Vector2(fp.x, fp.z)) > VUE:
			continue
		var key := "%d,%d" % [int(s.x), int(s.z)]
		live[key] = true
		if not _foreuses.has(key):
			var fo := EnginsCarriere.foreuse()
			add_child(fo)
			_foreuses[key] = fo
		var node: Node3D = _foreuses[key]
		var h := world.cell_height(Vector2i(int(s.x), int(s.z)))
		node.position = Vector3(p.x, h if not is_nan(h) else 0.0, p.z)
		(node.get_node("Tige") as Node3D).rotation.y = _t * 6.0
	for key in _foreuses.keys():
		if not live.has(key):
			(_foreuses[key] as Node).queue_free()
			_foreuses.erase(key)


# --- Sauvegarde ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	flush()
	var out := {}
	for bid in sites:
		var r: Dictionary = sites[bid]
		var f: Fosse = r.get("fosse")
		var v: Fosse = r.get("verse")
		out[str(bid)] = {"t": r.t, "fin": r.fin, "tir": r.get("tir", -1), "essais": r.get("essais", 0),
			"fosse": f.to_dict() if f != null else {}, "verse": v.to_dict() if v != null else {}}
	return {"version": 1, "sites": out, "sondages": sondages.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	clear()
	var src: Dictionary = d.get("sites", {})
	for k in src:
		var e: Dictionary = src[k]
		var f: Fosse = Fosse.from_dict(e.fosse) if not (e.get("fosse", {}) as Dictionary).is_empty() else null
		var v: Fosse = Fosse.from_dict(e.verse) if not (e.get("verse", {}) as Dictionary).is_empty() else null
		# Réserve et richesse sont déjà dans la section production : rien à relever.
		sites[int(k)] = {"t": String(e.get("t", "")), "fosse": f, "verse": v, "fin": String(e.get("fin", "")),
			"ok": true, "tir": int(e.get("tir", -1)), "essais": int(e.get("essais", 0))}
	for s in d.get("sondages", []):
		var sd: Dictionary = s
		sondages.append({"x": int(sd.get("x", 0)), "z": int(sd.get("z", 0)), "debut": float(sd.get("debut", 0.0)),
			"fin": float(sd.get("fin", 0.0)), "res": sd.get("res", {})})
	_dirty = true
	changed.emit()
