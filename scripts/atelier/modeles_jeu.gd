class_name ModelesJeu
extends RefCounted
## Les modèles de l'atelier deviennent de vrais bâtiments du jeu.
##
## Chaque modèle en murs fins de la banque (et chaque création en blocs) a une
## « fonction » : n'importe quel bâtiment du catalogue (maison, centrale à gaz,
## stade, piscine, grand-huit…). Le modèle entre dans le catalogue sous l'id
## « mdl_<id du modèle> » avec toutes les données de jeu de sa fonction
## (emplois, logements, production, réseau, parc…) et sa propre apparence, sa
## taille et son prix. Il se pose alors comme les autres bâtiments : prix,
## rotation R, accès à une voie, terrassement, chantier.
##
## Le champ « base » de l'entrée garde l'id de la fonction : les systèmes qui
## reconnaissent un bâtiment par son id passent par BuildingCatalog.base_of().
## Les capacités (emplois, logements, visiteurs, puissance) suivent la surface du modèle
## par rapport au bâtiment de référence (de ×0,25 à ×4).

const PREFIX := "mdl_"
const CATEGORY := "mes_modeles"
## Plus grand côté d'un modèle posé comme bâtiment.
const MAX_SIDE := 160
## Capacités proportionnelles à la surface.
const SCALED := ["emplois", "logements", "visiteurs"]
const RATIO_MIN := 0.25
const RATIO_MAX := 4.0
## Clés propres au modèle 3D de la fonction, à ne pas recopier.
const DROP := ["glb", "variantes", "palette", "blocks", "espace", "cache", "id", "zone", "modele", "base", "creation",
	"sans_vitres", "volume", "groupes"]
## Main-d'œuvre ajoutée au prix des matériaux.
const LABOUR := 1.3
const MIN_COST := 20_000

## Modèles venus des parties chargées (absents de la banque de ce joueur).
static var _from_saves: Dictionary = {}
static var _meshes: Dictionary = {}


static func catalog_id(model_id: String) -> String:
	return PREFIX + model_id


static func is_model(type_id: String) -> bool:
	return type_id.begins_with(PREFIX)


## Fonction par défaut d'un modèle en murs fins : celle de son usage.
static func default_fonction(d: Dictionary) -> String:
	var u := String(d.get("usage", "logement"))
	return String(Mobilier.USAGES.get(u, Mobilier.USAGES.logement).t)


static func fonction_of(d: Dictionary) -> String:
	var f := String(d.get("fonction", ""))
	if f != "" and not BuildingCatalog.get_type(f).is_empty() and not is_model(f):
		return f
	return default_fonction(d)


## Fonctions possibles : tous les bâtiments du catalogue (sauf les modèles et
## les créations), rangés par catégorie puis par nom.
static func fonctions() -> Array:
	var out := []
	var types := BuildingCatalog.all_types()
	for c in BuildingCatalog.CATEGORIES:
		var ids := []
		for id in types:
			var t: Dictionary = types[id]
			if String(t.get("cat", "")) != String(c.id) or t.get("cache", false) or t.has("modele") or t.has("creation"):
				continue
			ids.append(id)
		ids.sort_custom(func(a, b) -> bool: return String(types[a].name).naturalnocasecmp_to(String(types[b].name)) < 0)
		out.append({"cat": c.id, "name": c.name, "ids": ids})
	return out


static func fonction_name(f: String) -> String:
	var t := BuildingCatalog.get_type(f)
	if t.is_empty():
		return f
	var c := BuildingCatalog.category(String(t.get("cat", "")))
	return "%s (%s)" % [String(t.name), String(c.get("name", "")).to_lower()] if not c.is_empty() else String(t.name)


# --- Entrées du catalogue ------------------------------------------------------------------

## Données de jeu de la fonction, à la taille du modèle.
static func base_fields(fonction: String, w: int, d: int) -> Dictionary:
	var ref := BuildingCatalog.get_type(fonction)
	var t := ref.duplicate(true)
	for k in DROP:
		t.erase(k)
	var rw := maxf(1.0, float(ref.get("w", w)))
	var rd := maxf(1.0, float(ref.get("d", d)))
	var ratio := clampf(float(w * d) / (rw * rd), RATIO_MIN, RATIO_MAX)
	for k in SCALED:
		if t.has(k) and int(t[k]) > 0:
			t[k] = maxi(1, roundi(float(t[k]) * ratio))
	# Puissance d'une centrale, débit d'une station…
	if t.get("reseau") is Dictionary and float((t.reseau as Dictionary).get("cap", 0.0)) > 0.0:
		t.reseau["cap"] = snappedf(float(t.reseau.cap) * ratio, 0.1)
	# Les bâtiments faits main (maison, piscine…) se reconnaissent à leur id :
	# le rôle le garde pour les systèmes qui lisent arch ou role.
	if not t.has("arch") and not t.has("role"):
		t["role"] = fonction
	t["base"] = fonction
	t["w"] = w
	t["d"] = d
	return t


## Prix : les matériaux et la main-d'œuvre, mais pas moins que le bâtiment de
## référence à la même surface (une centrale reste chère, même petite).
static func price(fonction: String, w: int, d: int, materials: int) -> int:
	var ref := BuildingCatalog.get_type(fonction)
	var rw := maxf(1.0, float(ref.get("w", w)))
	var rd := maxf(1.0, float(ref.get("d", d)))
	var ratio := clampf(float(w * d) / (rw * rd), RATIO_MIN, RATIO_MAX)
	return maxi(materials, int(BuildingCatalog.cost(fonction) * ratio))


## Entrée de catalogue d'un modèle en murs fins de la banque.
static func entry(d: Dictionary) -> Dictionary:
	var g := geometry(d)
	var f := fonction_of(d)
	var t := base_fields(f, int(g.w), int(g.d))
	t["name"] = String(d.get("nom", "Mon modèle"))
	t["cost"] = price(f, int(g.w), int(g.d), int(g.cost))
	t["modele"] = String(d.id)
	t["region"] = "monde"
	t["era"] = "contemporain"
	t["style"] = ""
	t["desc"] = "Mon modèle · %s · %d × %d m" % [fonction_name(f), int(g.w), int(g.d)]
	return t


## Enregistre (ou met à jour) les modèles dans le catalogue.
static func register(all: Dictionary) -> void:
	var seen := {}
	for id in _from_saves:
		seen[id] = _from_saves[id]
	for id in BanqueModeles.ids():
		seen[id] = BanqueModeles.get_model(String(id))
	for id in seen:
		var d: Dictionary = seen[id]
		if String(d.get("genre", "")) != "plan":
			continue
		var cid := catalog_id(String(id))
		var e := entry(d)
		# Un modèle retiré de la banque reste connu (bâtiments déjà posés) mais caché.
		if not BanqueModeles.has_model(String(id)):
			e["cache"] = true
		all[cid] = e


static func refresh() -> void:
	register(BuildingCatalog.all_types())


## Modèle retiré de la banque : ses exemplaires posés restent, il quitte le catalogue.
static func forget(model_id: String, d: Dictionary) -> void:
	if String(d.get("genre", "")) == "plan":
		_from_saves[model_id] = d
	var all := BuildingCatalog.all_types()
	var cid := catalog_id(model_id)
	if all.has(cid):
		all[cid]["cache"] = true


static func ids() -> Array:
	var out := []
	var all := BuildingCatalog.all_types()
	for id in BanqueModeles.ids():
		var cid := catalog_id(String(id))
		if all.has(cid) and not all[cid].get("cache", false):
			out.append(cid)
	return out


# --- Géométrie ----------------------------------------------------------------------------

## Hauteur (m, au-dessus du rez-de-chaussée) d'un bloc enregistré.
static func block_height(d: Dictionary, yrel: int) -> float:
	if d.has("dy2"):
		return yrel * BlockEditor.UNIT_Y - float(d.dy2)
	return yrel * BlockEditor.UNIT_Y


## Emprise (murs, planchers, blocs), décalage des blocs anciens, prix.
static func geometry(d: Dictionary) -> Dictionary:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	var price := 0.0
	var top_wall := 0
	var wa: Array = d.get("walls", [])
	var i := 0
	while i + 8 < wa.size():
		var x := int(wa[i])
		var z := int(wa[i + 2])
		var dir := int(wa[i + 3])
		lo = Vector2i(mini(lo.x, x), mini(lo.y, z))
		hi = Vector2i(maxi(hi.x, x + (1 if dir == 0 else 0)), maxi(hi.y, z + (0 if dir == 0 else 1)))
		top_wall = maxi(top_wall, int(wa[i + 1]) + 1)
		price += PlanEditor.wall_price(int(wa[i + 4]))
		i += 9
	var fa: Array = d.get("floors", [])
	i = 0
	while i + 4 < fa.size():
		lo = Vector2i(mini(lo.x, int(fa[i])), mini(lo.y, int(fa[i + 2])))
		hi = Vector2i(maxi(hi.x, int(fa[i]) + 1), maxi(hi.y, int(fa[i + 2]) + 1))
		price += PlanEditor.floor_price(int(fa[i + 3]))
		i += 5
	price += (d.get("stairs", []) as Array).size() / 5 * PlanEditor.STAIR_PRICE
	var ba: Array = d.get("blocs", [])
	i = 0
	var min_y := INF
	while i + 3 < ba.size():
		lo = Vector2i(mini(lo.x, int(ba[i])), mini(lo.y, int(ba[i + 2])))
		hi = Vector2i(maxi(hi.x, int(ba[i]) + 1), maxi(hi.y, int(ba[i + 2]) + 1))
		min_y = minf(min_y, float(ba[i + 1]))
		price += BlocFormes.price(int(ba[i + 3]))
		i += 4
	if lo.x > hi.x:
		lo = Vector2i.ZERO
		hi = Vector2i(int(d.get("w", 4)), int(d.get("d", 4)))
	# Blocs d'un modèle ancien (hauteur mal repérée) : le toit se pose sur les murs.
	var block_shift := 0.0
	if not d.has("dy2") and min_y < INF:
		block_shift = top_wall * PlanEditor.H - min_y * BlockEditor.UNIT_Y
	var meubles := (d.get("meubles", []) as Array).size() / 6
	price += meubles * 400.0
	var w := clampi(hi.x - lo.x, 1, MAX_SIDE)
	var dd := clampi(hi.y - lo.y, 1, MAX_SIDE)
	return {"lo": lo, "w": w, "d": dd, "shift": block_shift, "cost": maxi(MIN_COST, int(price * LABOUR))}


## Maillage du modèle dans le repère du catalogue (centré, sol en y = 0, façade vers −Z).
static func build_mesh(t: Dictionary) -> ArrayMesh:
	var mid := String(t.modele)
	if _meshes.has(mid):
		return _meshes[mid]
	var d := BanqueModeles.get_model(mid)
	if d.is_empty():
		d = _from_saves.get(mid, {})
	var m := BlocMesher.new()
	if not d.is_empty():
		_emit(d, m)
	var mesh := m.to_mesh()
	_meshes[mid] = mesh
	return mesh


static func _emit(d: Dictionary, m: BlocMesher) -> void:
	var g := geometry(d)
	var lo: Vector2i = g.lo
	# Murs, planchers, escaliers : un éditeur de murs hors de la scène les fabrique.
	var pe := PlanEditor.new()
	var p := {"y0": 0.0, "walls": {}, "floors": {}, "stairs": {}}
	var levels := {}
	var wa: Array = d.get("walls", [])
	var i := 0
	while i + 8 < wa.size():
		var kind := String(wa[i + 6])
		p.walls[Vector4i(int(wa[i]), int(wa[i + 1]), int(wa[i + 2]), int(wa[i + 3]))] = {
			"a": int(wa[i + 4]), "b": int(wa[i + 5]), "o": kind if PlanEditor.OPENINGS.has(kind) else "", "om": int(wa[i + 7]), "op": false}
		levels[int(wa[i + 1])] = true
		i += 9
	var fa: Array = d.get("floors", [])
	i = 0
	while i + 4 < fa.size():
		p.floors[Vector3i(int(fa[i]), int(fa[i + 1]), int(fa[i + 2]))] = {"t": int(fa[i + 3]), "u": int(fa[i + 4])}
		levels[int(fa[i + 1])] = true
		i += 5
	var sa: Array = d.get("stairs", [])
	i = 0
	while i + 4 < sa.size():
		p.stairs[Vector3i(int(sa[i]), int(sa[i + 1]), int(sa[i + 2]))] = {"r": int(sa[i + 3]), "m": int(sa[i + 4])}
		levels[int(sa[i + 1])] = true
		i += 5
	pe.plans["m"] = p
	var ramps := PackedVector3Array()
	for e in levels:
		pe.emit_storey("m", int(e), m, m, ramps)
	pe.free()
	# Toit et ajouts en blocs.
	var occupied := {}
	var ba: Array = d.get("blocs", [])
	i = 0
	while i + 3 < ba.size():
		occupied[Vector3i(int(ba[i]), int(ba[i + 1]), int(ba[i + 2]))] = int(ba[i + 3])
		i += 4
	var shift := float(g.shift)
	for key in occupied:
		var kk: Vector3i = key
		var base := Vector3(kk.x * BlockEditor.SIZE, block_height(d, kk.y) + shift, kk.z * BlockEditor.SIZE)
		BlocFormes.emit(m, occupied[kk], base, func(o: Vector3i) -> int: return int(occupied.get(kk + o, -1)))
	m.translate(Vector3(-lo.x - float(g.w) / 2.0, 0.0, -lo.y - float(g.d) / 2.0))


# --- Sauvegarde de la partie ---------------------------------------------------------------

## Modèles utilisés par les bâtiments posés (copiés dans la sauvegarde).
static func to_dict(bs: BuildingSystem) -> Dictionary:
	var out := {}
	for b in bs.buildings.values():
		var t := String(b.t)
		if not is_model(t):
			continue
		var mid := t.substr(PREFIX.length())
		if out.has(mid):
			continue
		var d := BanqueModeles.get_model(mid)
		if d.is_empty():
			d = _from_saves.get(mid, {})
		if not d.is_empty():
			out[mid] = d
	return {"version": 1, "items": out}


## Avant de recréer les bâtiments d'une partie : ses modèles entrent au catalogue.
static func adopt(data: Dictionary) -> void:
	var src: Dictionary = data.get("items", {})
	for mid in src:
		var d: Dictionary = src[mid]
		if String(d.get("genre", "")) == "plan" and not BanqueModeles.has_model(String(mid)):
			_from_saves[String(mid)] = d
	refresh()
