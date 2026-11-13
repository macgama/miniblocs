class_name Agriculture
extends Node
## Agriculture façon gestion de ferme : champs tracés par le joueur, cultures
## selon la saison et le climat du lieu, travaux faits par les habitants qui
## travaillent à la ferme avec des machines (achetées ou louées), élevage, et
## récoltes qui partent dans le stock de la ferme (puis en camion, voir
## Production).
##
## - Un CHAMP est un rectangle de cases rattaché à une ferme. Il suit les
##   étapes friche → labouré → semé (pousse) → mûr → récolté (chaume), avec les
##   travaux qui vont avec : labour, semis, engrais, traitement, récolte,
##   pressage de la paille ou du foin.
## - Les travaux sont faits par les employés de la ferme présents (pas les
##   chauffeurs), un engin chacun. Sans la machine, la ferme la loue à la
##   coopérative pour la journée (réglable par ferme).
## - Une ferme qui a des champs ou des bêtes est « gérée » ici : elle ne produit
##   plus toute seule d'après la richesse du sol (voir Production.agri).
## - Les bêtes mangent le foin, les céréales et la paille de la ferme (livrés
##   par camion s'il en manque), broutent au pré à la belle saison et donnent
##   lait, œufs, laine, viande et fumier (engrais des champs).

signal changed
signal message(text: String)
signal info_changed(text: String)

## Pas de la simulation des travaux (heures de jeu).
const PAS_H := 1.0
## Heures de travail aux champs.
const HEURE_DEBUT := 6.0
const HEURE_FIN := 21.0
## Pluie au-delà de laquelle on ne sème, ne traite, ne récolte ni ne presse.
const PLUIE := 0.35
## Biomes où l'on ne peut pas cultiver (noms de TerrainWorld.KIND_NAMES).
const EAUX := ["Mer", "Lac / rivière", "Glacier", "Rivière", "Ruisseau", "Étang", "Lac / canal"]

var world: TerrainWorld
var buildings: BuildingSystem
var population: Population
var production: Production
var ambiance: DayNight
var visuels: Node3D

## Champs : id -> {id, r (Rect2i), f (ferme), cult, etat, sc (culture semée),
## cr (croissance 0-1), eng, tr, pertes, met, tache, fait (ha), paille, foin,
## prec (culture précédente), rdt (dernière récolte, t), azote (kg/ha cette
## année), jr (jour de la récolte), nom}.
var champs: Dictionary = {}
var next_id := 1
## Fermes : bid -> {machines: [{t, us, h, panne}], betes: {esp: n},
## faim: {esp: jours}, loc_auto, loues: {type: jour}, nb (nourries, 0-1),
## travail: [{champ, tache, machines}], journal: [texte]}.
var fermes: Dictionary = {}
## Champ choisi dans le panneau (-1 : aucun) et culture pour les nouveaux champs.
var selection := -1
var culture_choisie := "ble"
var ferme_choisie := -1

## Horloge (unix) et jour local en cours.
var clock := -1.0
var last_day := -1
var _climat := Plantes.Climat.TEMPERE
var _rng := RandomNumberGenerator.new()
var repas: Repas

## Outil de tracé des champs : "" (aucun), "tracer", "effacer".
var outil := ""
var _debut := Vector2i.ZERO
var _glisse := false
var _survol := Vector2i.ZERO
var _survol_ok := false
var _cadre: MeshInstance3D


func _init() -> void:
	_rng.seed = 4242


func setup(w: TerrainWorld, b: BuildingSystem, p: Population, prod: Production, a: DayNight) -> void:
	world = w
	buildings = b
	population = p
	production = prod
	ambiance = a
	production.agri = self
	repas = Repas.new(self)
	production.day_passed.connect(func() -> void: repas.apres_courses())
	if population != null:
		var avant: Callable = population.extra_satisfaction
		population.extra_satisfaction = func(pp: Dictionary) -> Array:
			var r: Array = avant.call(pp) if avant.is_valid() else [0.0, []]
			var f := repas.satisfaction(pp)
			if f.size() >= 2 and float(f[0]) != 0.0:
				r = [float(r[0]) + float(f[0]), (r[1] as Array) + (f[1] as Array)]
			return r
		population.extra_health = repas.sante
	if world != null:
		var bloque: Callable = world.tree_blocker
		world.tree_blocker = func(c: Vector2i) -> bool:
			return champ_at(c) >= 0 or (bloque.is_valid() and bloque.call(c))
		world.origin_changed.connect(func(lat: float, lon: float) -> void: _climat = Plantes.climat(lat, lon))
		_climat = Plantes.climat(world.origin_lat, world.origin_lon)
	buildings.changed.connect(_on_buildings_changed)
	add_to_group("pollution_sources")
	_cadre = MeshInstance3D.new()
	_cadre.name = "CadreChamp"
	_cadre.visible = false
	_cadre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.35)
	mat.no_depth_test = true
	_cadre.material_override = mat
	add_child(_cadre)


func clear() -> void:
	champs.clear()
	fermes.clear()
	next_id = 1
	selection = -1
	clock = -1.0
	last_day = -1
	if repas:
		repas.clear()
	_marque_tout()
	changed.emit()


func climat() -> int:
	return _climat


func lat() -> float:
	return world.origin_lat if world != null else 48.0


# --- Fermes ------------------------------------------------------------------------

func _type_of(bid: int) -> String:
	return String(buildings.buildings.get(bid, {}).get("t", "")) if buildings != null else ""


func est_ferme(bid: int) -> bool:
	return buildings != null and buildings.buildings.has(bid) and AgriDonnees.est_ferme(_type_of(bid))


## Toutes les fermes de la carte (bid), de la plus ancienne à la plus récente.
func liste_fermes() -> Array:
	var out := []
	if buildings == null:
		return out
	for bid in buildings.buildings:
		if AgriDonnees.est_ferme(String(buildings.buildings[bid].t)):
			out.append(int(bid))
	out.sort()
	return out


func ferme(bid: int) -> Dictionary:
	if not fermes.has(bid):
		fermes[bid] = {"machines": [], "betes": {}, "faim": {}, "loc_auto": true, "loues": {}, "nb": 1.0,
			"travail": [], "journal": []}
	return fermes[bid]


func _pos_of(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	var r := buildings._rect_of(b)
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	return Vector3(c.x, 0.0, c.y)


func nom_ferme(bid: int) -> String:
	var t := BuildingCatalog.get_type(_type_of(bid))
	return "%s n° %d" % [String(t.get("name", "Ferme")), bid]


## Une ferme gérée par l'agriculture (elle a des champs ou des bêtes).
func manages(bid: int) -> bool:
	if not fermes.has(bid):
		return false
	var f: Dictionary = fermes[bid]
	if _betes_total(f) > 0:
		return true
	for ch in champs.values():
		if int(ch.f) == bid:
			return true
	return false


func _betes_total(f: Dictionary) -> int:
	var n := 0
	for e in f.betes:
		n += int(f.betes[e])
	return n


func champs_de(bid: int) -> Array:
	var out := []
	for id in champs:
		if int(champs[id].f) == bid:
			out.append(int(id))
	out.sort()
	return out


func surface_ferme(bid: int) -> float:
	var ha := 0.0
	for id in champs_de(bid):
		ha += surface(champs[id])
	return ha


# --- Ce que la ferme fournit et ce dont elle a besoin (pour Production) ------------

## Marchandises produites, par jour en moyenne sur l'année : {marchandise: t}.
func outputs(bid: int) -> Dictionary:
	var out := {}
	for id in champs_de(bid):
		var ch: Dictionary = champs[id]
		var c := AgriDonnees.culture(String(ch.cult))
		var g := String(c.get("good", ""))
		if g != "":
			var par_an := float(c.rdt) * surface(ch) * (2.0 if bool(c.get("permanente", false)) else 1.0)
			out[g] = float(out.get(g, 0.0)) + par_an / 365.0
		if float(c.get("paille", 0.0)) > 0.0:
			out["paille"] = float(out.get("paille", 0.0)) + float(c.paille) * surface(ch) / 365.0
	var f: Dictionary = fermes.get(bid, {})
	for e in f.get("betes", {}):
		var sp := AgriDonnees.espece(e)
		for g in sp.get("donne", {}):
			out[g] = float(out.get(g, 0.0)) + float(sp.donne[g]) * int(f.betes[e])
	# Le stock déjà là (récolte d'un coup) reste à vendre.
	if production != null and production.sites.has(bid):
		for g in production.sites[bid].st:
			if not out.has(g) and float(production.sites[bid].st[g]) > 0.01 and not needs(bid).has(g):
				out[g] = 0.01
	return out


## Fourrage dont les bêtes ont besoin chaque jour : {marchandise: t}.
func needs(bid: int) -> Dictionary:
	var f: Dictionary = fermes.get(bid, {})
	if f.is_empty() or _betes_total(f) <= 0:
		return {}
	# Ce que la ferme fait pousser elle-même remplit son stock : elle ne
	# commande que ce qui manque (Production compare au stock).
	return besoins_betes(bid)


## Stock maximal (t) d'une marchandise à la ferme (silos, hangars, tank à lait).
func cap(bid: int, g: String) -> float:
	var n := needs(bid)
	if n.has(g):
		return maxf(float(n[g]) * 30.0, 5.0)
	var o := outputs(bid)
	if o.has(g):
		return maxf(float(o[g]) * 200.0, 50.0)
	if g in ["chimie", "carburant", "fumier"]:
		return 200.0
	return 0.0


func status_of(bid: int) -> String:
	var f := ferme(bid)
	var parts: Array[String] = []
	for w in f.get("travail", []):
		parts.append("%s (%s)" % [String(AgriDonnees.TACHES[w.tache].name), nom_champ(int(w.champ))])
	var n := _betes_total(f)
	if n > 0:
		var nb := float(f.get("nb", 1.0))
		parts.append("%d bête%s%s" % [n, "s" if n > 1 else "", "" if nb >= 0.99 else " (nourries à %d %%)" % roundi(nb * 100.0)])
	if parts.is_empty():
		var nc := champs_de(bid).size()
		return "%d champ%s · rien à faire aux champs en ce moment" % [nc, "s" if nc > 1 else ""]
	return " · ".join(parts)


# --- Champs ------------------------------------------------------------------------

static func surface(ch: Dictionary) -> float:
	var r: Rect2i = ch.r
	return float(r.size.x * r.size.y) / 10000.0


func nom_champ(id: int) -> String:
	if not champs.has(id):
		return "?"
	var ch: Dictionary = champs[id]
	if String(ch.get("nom", "")) != "":
		return String(ch.nom)
	return "champ %d" % id


## Champ qui contient la case c (-1 : aucun).
func champ_at(c: Vector2i) -> int:
	for id in champs:
		if (champs[id].r as Rect2i).has_point(c):
			return int(id)
	return -1


## Ferme la plus proche d'un point, dans le rayon des champs (-1 : aucune).
func ferme_proche(p: Vector2) -> int:
	var best := -1
	var best_d := AgriDonnees.RAYON_CHAMPS
	for bid in liste_fermes():
		var q := _pos_of(bid)
		var d := Vector2(q.x, q.z).distance_to(p)
		if d < best_d:
			best_d = d
			best = bid
	return best


## Peut-on faire un champ ici ? {ok, raison, ferme}.
func verifie(r: Rect2i, bid := -1) -> Dictionary:
	var n := r.size.x * r.size.y
	if n < AgriDonnees.CHAMP_MIN:
		return {"ok": false, "raison": "Champ trop petit (au moins %d m², soit 20 × 20 m)." % AgriDonnees.CHAMP_MIN}
	if n > AgriDonnees.CHAMP_MAX:
		return {"ok": false, "raison": "Champ trop grand (100 ha au plus)."}
	var centre := Vector2(r.position) + Vector2(r.size) * 0.5
	if bid < 0:
		bid = ferme_choisie if est_ferme(ferme_choisie) else ferme_proche(centre)
	if bid < 0:
		return {"ok": false, "raison": "Aucune ferme à moins de %.1f km : construis d'abord une ferme (catégorie Production)." % (AgriDonnees.RAYON_CHAMPS / 1000.0)}
	var q := _pos_of(bid)
	if Vector2(q.x, q.z).distance_to(centre) > AgriDonnees.RAYON_CHAMPS:
		return {"ok": false, "raison": "Trop loin de %s (%.1f km au plus)." % [nom_ferme(bid), AgriDonnees.RAYON_CHAMPS / 1000.0]}
	for id in champs:
		if (champs[id].r as Rect2i).intersects(r):
			return {"ok": false, "raison": "Ce champ en recouvre un autre (%s)." % nom_champ(int(id))}
	# Bâtiments, voies et eau : on regarde une case sur quatre (assez fin pour un champ).
	var pas := maxi(1, mini(r.size.x, r.size.y) / 40)
	for z in range(r.position.y, r.end.y, pas):
		for x in range(r.position.x, r.end.x, pas):
			var c := Vector2i(x, z)
			if buildings != null and buildings.occupancy.has(c):
				return {"ok": false, "raison": "Il y a un bâtiment sur ce champ."}
			if world != null and world.cell_kind_at(c) in EAUX:
				return {"ok": false, "raison": "Il y a de l'eau ou un glacier sur ce champ."}
	if _sur_voie(r, pas):
		return {"ok": false, "raison": "Une route ou un chemin passe sur ce champ."}
	return {"ok": true, "raison": "", "ferme": bid}


func _sur_voie(r: Rect2i, pas: int) -> bool:
	var tr: Variant = get_parent().get("transport") if get_parent() != null else null
	if tr == null:
		return false
	var occ: Dictionary = tr._occupied
	for z in range(r.position.y, r.end.y, pas):
		for x in range(r.position.x, r.end.x, pas):
			if occ.has(Vector2i(x, z)):
				return true
	return false


## Crée un champ. Rend son id (-1 et un message si c'est impossible).
func ajoute_champ(r: Rect2i, cult := "", bid := -1) -> int:
	var v := verifie(r, bid)
	if not bool(v.ok):
		message.emit(String(v.raison))
		return -1
	if cult == "":
		cult = culture_choisie
	var id := next_id
	next_id += 1
	champs[id] = {"id": id, "r": r, "f": int(v.ferme), "cult": cult, "etat": "friche", "sc": "", "cr": 0.0,
		"eng": false, "tr": false, "pertes": 0.0, "met": 1.0, "fait": 0.0, "tache": "", "paille": 0.0, "foin": 0.0,
		"prec": "", "rdt": 0.0, "azote": 0.0, "jr": -1, "nom": ""}
	ferme(int(v.ferme))
	selection = id
	_marque(r)
	if not AgriDonnees.convient(cult, _climat):
		message.emit("%s pousse mal sous ce climat (%s) : rendement divisé par deux." % [AgriDonnees.culture_name(cult),
			Plantes.CLIMAT_NOMS[_climat]])
	else:
		message.emit("Champ de %s ha créé pour %s (%s)." % [_ha(surface(champs[id])), nom_ferme(int(v.ferme)),
			AgriDonnees.culture_name(cult).to_lower()])
	changed.emit()
	return id


func supprime_champ(id: int) -> void:
	if not champs.has(id):
		return
	var r: Rect2i = champs[id].r
	champs.erase(id)
	for f in fermes.values():
		var t: Array = f.get("travail", [])
		for i in range(t.size() - 1, -1, -1):
			if int(t[i].champ) == id:
				t.remove_at(i)
	if selection == id:
		selection = -1
	_marque(r)
	changed.emit()


## Change la culture prévue. Une culture en place est gardée jusqu'à sa
## récolte, sauf si detruire (le champ repart en friche).
func change_culture(id: int, cult: String, detruire := false) -> void:
	if not champs.has(id) or not AgriDonnees.CULTURES.has(cult):
		return
	var ch: Dictionary = champs[id]
	ch.cult = cult
	if detruire and String(ch.etat) in ["pousse", "mur", "laboure"]:
		ch.etat = "friche"
		ch.sc = ""
		ch.cr = 0.0
		ch.tache = ""
		ch.fait = 0.0
		message.emit("%s : culture détruite, le champ repart en friche." % nom_champ(id).capitalize())
	changed.emit()


func rattache(id: int, bid: int) -> void:
	if champs.has(id) and est_ferme(bid):
		champs[id].f = bid
		champs[id].tache = ""
		champs[id].fait = 0.0
		ferme(bid)
		changed.emit()


## Prépare une ferme : quelques champs autour d'elle (sur les terres
## cultivables libres), et des bêtes pour un élevage. Rend le nombre de champs.
func prepare_ferme(bid: int, n := 4, cote := 160) -> int:
	if not est_ferme(bid):
		return 0
	var t := _type_of(bid)
	var r := buildings._rect_of(buildings.buildings[bid])
	var faits := 0
	var cults := _cultures_pour(t)
	var essais := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	for d: Vector2i in essais:
		if faits >= n:
			break
		for taille: int in [cote, cote * 3 / 4, cote / 2]:
			var c := r.get_center() + d * (taille + 16 + maxi(r.size.x, r.size.y) / 2)
			var rect := Rect2i(c - Vector2i(taille, taille) / 2, Vector2i(taille, taille))
			if bool(verifie(rect, bid).ok):
				var cult: String = cults[faits % cults.size()]
				if not AgriDonnees.convient(cult, _climat):
					cult = "mais" if AgriDonnees.convient("mais", _climat) else "legumes"
				var id := next_id
				next_id += 1
				champs[id] = {"id": id, "r": rect, "f": bid, "cult": cult, "etat": "friche", "sc": "", "cr": 0.0,
					"eng": false, "tr": false, "pertes": 0.0, "met": 1.0, "fait": 0.0, "tache": "", "paille": 0.0,
					"foin": 0.0, "prec": "", "rdt": 0.0, "azote": 0.0, "jr": -1, "nom": ""}
				_marque(rect)
				faits += 1
				break
	var f := ferme(bid)
	for e in AgriDonnees.FERMES[t].betes:
		if _betes_total(f) == 0 or int(f.betes.get(e, 0)) == 0:
			var place := AgriDonnees.places(t, e)
			# Départ : un quart des places, le premier type de bête de la ferme.
			if _betes_total(f) == 0:
				f.betes[e] = maxi(place / 4, 1)
	if faits > 0 or _betes_total(f) > 0:
		changed.emit()
	return faits


func _cultures_pour(t: String) -> Array:
	match t:
		"ferme_cereales":
			return ["ble", "orge", "colza", "mais"]
		"ferme_betteraves":
			return ["betterave", "ble", "pomme_de_terre", "orge"]
		"ferme_maraichere":
			return ["legumes", "pomme_de_terre", "legumes", "tournesol"]
		"ferme_fibres":
			return ["lin" if _climat <= Plantes.Climat.TEMPERE else "coton", "ble", "paturage", "prairie"]
		"elevage", "ferme_laitiere", "bergerie", "haras", "etable_moderne", "ferme_jurassienne", "ferme_bavaroise", \
				"ferme_alpage", "hacienda", "grange_americaine":
			return ["paturage", "prairie", "paturage", "mais"]
		"porcherie", "poulailler", "ferme_cour_carree", "hangar_agricole":
			return ["ble", "mais", "orge", "colza"]
		"cortijo":
			return ["ble", "tournesol", "paturage", "orge"]
		"serres_tunnels", "serre_verre":
			return ["legumes", "pomme_de_terre", "legumes", "legumes"]
		"rizerie_bali":
			return ["riz", "riz", "legumes", "riz"]
	return ["ble"]


# --- Machines ------------------------------------------------------------------------

## Remise sur les machines quand une concession agricole tourne sur la carte.
func remise_concession() -> float:
	if production == null:
		return 0.0
	for bid in production.sites:
		if _type_of(bid) == "concession_agricole" and float(production.sites[bid].get("eff", 0.0)) > 0.0:
			return 0.10
	return 0.0


func prix_machine(t: String) -> int:
	return roundi(float(AgriDonnees.machine(t).get("prix", 0)) * (1.0 - remise_concession()))


## Achète une machine avec la caisse du joueur. Rend vrai si c'est fait.
func achete_machine(bid: int, t: String) -> bool:
	if not est_ferme(bid) or not AgriDonnees.MACHINES.has(t):
		return false
	var prix := prix_machine(t)
	if not buildings.unlimited_money:
		if buildings.money < prix:
			message.emit("Pas assez d'argent pour %s (%s)." % [AgriDonnees.machine_name(t).to_lower(), BuildingSystem.format_money(prix)])
			return false
		buildings.money -= prix
	(ferme(bid).machines as Array).append({"t": t, "us": 0.0, "h": 0.0, "panne": -1})
	_journal(bid, "Achat : %s (%s)" % [AgriDonnees.machine_name(t), BuildingSystem.format_money(prix)])
	message.emit("%s achetée pour %s." % [AgriDonnees.machine_name(t), nom_ferme(bid)])
	changed.emit()
	return true


## Revend une machine (moitié du prix neuf, moins l'usure).
func vend_machine(bid: int, i: int) -> void:
	var ms: Array = ferme(bid).machines
	if i < 0 or i >= ms.size():
		return
	var m: Dictionary = ms[i]
	var v := roundi(float(AgriDonnees.machine(String(m.t)).prix) * 0.5 * (1.0 - float(m.us)))
	if not buildings.unlimited_money:
		buildings.money += v
	ms.remove_at(i)
	_journal(bid, "Vente : %s (%s)" % [AgriDonnees.machine_name(String(m.t)), BuildingSystem.format_money(v)])
	changed.emit()


## Révision d'une machine : l'usure retombe à 10 %, payée par la ferme.
func revise_machine(bid: int, i: int) -> void:
	var ms: Array = ferme(bid).machines
	if i < 0 or i >= ms.size():
		return
	var m: Dictionary = ms[i]
	var cout := float(AgriDonnees.machine(String(m.t)).prix) * AgriDonnees.REPARATION * maxf(float(m.us), 0.1) \
		* (0.5 if remise_concession() > 0.0 else 1.0)
	production.pay(bid, "Réparations des machines", -cout)
	m.us = 0.1
	m.panne = -1
	_journal(bid, "Révision : %s (%s)" % [AgriDonnees.machine_name(String(m.t)), BuildingSystem.format_money(roundi(cout))])
	changed.emit()


func machines_de(bid: int) -> Array:
	return ferme(bid).machines


# --- Bêtes ----------------------------------------------------------------------------

func places_libres(bid: int, esp: String) -> int:
	var f := ferme(bid)
	return maxi(AgriDonnees.places(_type_of(bid), esp) - int(f.betes.get(esp, 0)), 0)


## Achète n bêtes (caisse du joueur). Rend le nombre acheté.
func achete_betes(bid: int, esp: String, n: int) -> int:
	n = mini(n, places_libres(bid, esp))
	if n <= 0:
		message.emit("Plus de place pour des %s ici." % String(AgriDonnees.espece(esp).get("name", esp)).to_lower())
		return 0
	var prix := int(AgriDonnees.espece(esp).prix) * n
	if not buildings.unlimited_money:
		if buildings.money < prix:
			message.emit("Pas assez d'argent (%s)." % BuildingSystem.format_money(prix))
			return 0
		buildings.money -= prix
	var f := ferme(bid)
	f.betes[esp] = int(f.betes.get(esp, 0)) + n
	_journal(bid, "Achat : %d %s (%s)" % [n, String(AgriDonnees.espece(esp).name).to_lower(), BuildingSystem.format_money(prix)])
	changed.emit()
	return n


## Vend n bêtes à l'abattoir (bétail dans le stock de la ferme) ou au marché.
func vend_betes(bid: int, esp: String, n: int) -> int:
	var f := ferme(bid)
	n = mini(n, int(f.betes.get(esp, 0)))
	if n <= 0:
		return 0
	f.betes[esp] = int(f.betes[esp]) - n
	if int(f.betes[esp]) <= 0:
		f.betes.erase(esp)
	var poids := {"vache": 0.6, "bovin": 0.65, "porc": 0.11, "poule": 0.002, "mouton": 0.045, "chevre": 0.04, "cheval": 0.0}
	var t := float(poids.get(esp, 0.0)) * n
	if t > 0.0:
		production.put(bid, "betail", t)
	else:
		var v := float(AgriDonnees.espece(esp).prix) * 0.6 * n
		production.pay(bid, "Vente de bêtes", v)
	_journal(bid, "Vente : %d %s" % [n, String(AgriDonnees.espece(esp).name).to_lower()])
	changed.emit()
	return n


## Hectares de pâture des champs de la ferme où l'herbe a poussé.
func paturage_ha(bid: int) -> float:
	var ha := 0.0
	for id in champs_de(bid):
		var ch: Dictionary = champs[id]
		if bool(AgriDonnees.culture(String(ch.sc if String(ch.sc) != "" else ch.cult)).get("paturage", false)) \
				and String(ch.etat) in ["pousse", "mur"]:
			ha += surface(ch)
	return ha


## Part du fourrage trouvée au pré (0 à 1), selon la saison et la place.
func part_au_pre(bid: int) -> float:
	var f := ferme(bid)
	var ugb := 0.0
	for e in f.betes:
		ugb += float(AgriDonnees.espece(e).ugb) * int(f.betes[e])
	if ugb <= 0.0:
		return 0.0
	var mois := int(local_time(clock).month) if clock > 0.0 else 6
	if not AgriDonnees.saison_herbe(mois, lat(), _climat):
		return 0.0
	return clampf(paturage_ha(bid) / 0.6 / ugb, 0.0, 1.0)


## Ce que mangent les bêtes de la ferme chaque jour : {marchandise: t}.
func besoins_betes(bid: int) -> Dictionary:
	var f := ferme(bid)
	var pre := part_au_pre(bid)
	var out := {}
	var ugb := 0.0
	for e in f.betes:
		var sp := AgriDonnees.espece(e)
		var n := int(f.betes[e])
		ugb += float(sp.ugb) * n
		for g in sp.mange:
			var q := float(sp.mange[g]) * n
			if g == "foin" and float(sp.ugb) > 0.0:
				q *= 1.0 - pre
			out[g] = float(out.get(g, 0.0)) + q
	if ugb > 0.0:
		out["paille"] = float(out.get("paille", 0.0)) + AgriDonnees.LITIERE * ugb * (1.0 - pre)
	for g in out.keys():
		if float(out[g]) <= 0.00001:
			out.erase(g)
	return out


# --- Temps ------------------------------------------------------------------------------

func _utc() -> float:
	return ambiance.utc_offset() if ambiance != null else 0.0


func local_time(unix: float) -> Dictionary:
	var local := unix + _utc() * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	return {"h": fposmod(local, 86400.0) / 3600.0, "month": int(dt.month), "day": int(floorf(local / 86400.0)),
		"yday": _jour_annee(dt)}


static func _jour_annee(dt: Dictionary) -> int:
	const AVANT := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	return AVANT[int(dt.month) - 1] + int(dt.day) - 1


func _process(_delta: float) -> void:
	if ambiance == null:
		return
	var t := ambiance.unix_time
	if clock < 0.0 or absf(t - clock) > 86400.0 * 5.0:
		clock = t
		last_day = int(local_time(t).day)
		return
	if t - clock >= PAS_H * 3600.0:
		advance(t - clock)


## Fait avancer l'agriculture de dt secondes de jeu, heure par heure.
func advance(dt: float) -> void:
	if clock < 0.0:
		clock = ambiance.unix_time - dt if ambiance != null else 0.0
	if last_day < 0:
		last_day = int(local_time(clock).day)
	var n := 0
	while dt >= PAS_H * 3600.0 - 0.01 and n < 24 * 6:
		clock += PAS_H * 3600.0
		dt -= PAS_H * 3600.0
		n += 1
		var lt := local_time(clock)
		if int(lt.day) > last_day:
			last_day = int(lt.day)
			nouveau_jour(lt)
		heure(lt)
	if n > 0:
		changed.emit()


## Pluie en ce moment (0 à 1).
func pluie() -> float:
	if ambiance == null or ambiance.weather == null:
		return 0.0
	return ambiance.weather.precip * (1.0 - ambiance.weather.snow * 0.0)


# --- Une heure aux champs -----------------------------------------------------------

## Travaux à faire sur un champ ce mois-ci ("" : rien).
func tache_due(ch: Dictionary, mois: int) -> String:
	var cult := String(ch.cult)
	var c := AgriDonnees.culture(cult)
	match String(ch.etat):
		"friche", "chaume":
			if float(ch.paille) > 0.0 and AgriDonnees.outil("pressage", "") != "":
				return "pressage"
			if bool(c.get("permanente", false)) and AgriDonnees.saison_semis(cult, mois, lat(), _climat):
				return "labour" if String(ch.etat) == "friche" and String(ch.prec) != "" else "semis"
			return "labour"
		"laboure":
			if AgriDonnees.saison_semis(cult, mois, lat(), _climat):
				return "semis"
		"pousse":
			var sc := AgriDonnees.culture(String(ch.sc))
			if float(ch.foin) > 0.0:
				return "pressage"
			if not bool(ch.eng) and float(sc.get("engrais", 0)) > 0.0 and float(ch.cr) >= 0.15:
				return "engrais"
			if not bool(ch.tr) and not bool(sc.get("permanente", false)) and float(ch.cr) >= 0.35:
				return "traitement"
		"mur":
			if float(ch.foin) > 0.0:
				return "pressage"
			if String(AgriDonnees.culture(String(ch.sc)).get("recolte_m", "")) != "":
				return "recolte"
	return ""


## Employés de la ferme qui peuvent aller aux champs en ce moment.
func bras(bid: int, h: float) -> int:
	if population == null:
		return 0
	var n := 0
	for pid in population.by_job.get(bid, []):
		if not population.persons.has(pid):
			continue
		var p: Dictionary = population.persons[pid]
		if AgriDonnees.PAS_AUX_CHAMPS.has(String(p.get("met", ""))):
			continue
		if ambiance == null:
			if h >= HEURE_DEBUT and h < HEURE_FIN:
				n += 1
			continue
		var a := population.activity(p)
		if int(a.bid) == bid and String(a.kind) != "trajet":
			n += 1
	return n


func heure(lt: Dictionary) -> void:
	var h := float(lt.h)
	var mois := int(lt.month)
	var mouille := pluie() > PLUIE
	var jour := int(lt.day)
	for bid in fermes.keys():
		if not est_ferme(bid):
			continue
		var f: Dictionary = fermes[bid]
		f.travail = []
		if h < HEURE_DEBUT or h >= HEURE_FIN:
			continue
		var libres := bras(bid, h)
		if libres <= 0:
			continue
		var dues: Array = []
		for id in champs_de(bid):
			var t := tache_due(champs[id], mois)
			if t == "":
				continue
			if mouille and bool(AgriDonnees.TACHES[t].pluie):
				continue
			dues.append([int(AgriDonnees.TACHES[t].ordre), id, t])
		dues.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var prises := {}
		for d in dues:
			if libres <= 0:
				break
			var id := int(d[1])
			var t := String(d[2])
			var ch: Dictionary = champs[id]
			var cult := String(ch.sc) if t in ["engrais", "traitement", "recolte"] or (t == "pressage" and float(ch.foin) > 0.0) \
				else String(ch.cult)
			var engins := _engins(bid, t, cult, prises, jour)
			if engins.is_empty():
				continue
			libres -= 1
			_travaille(bid, id, t, cult, engins, PAS_H)
	_grele()


## Machines pour une tâche : celles de la ferme (libres et en état), sinon
## louées pour la journée. Rend [] s'il en manque.
func _engins(bid: int, t: String, cult: String, prises: Dictionary, jour: int) -> Array:
	var f: Dictionary = fermes[bid]
	var out := []
	for typ in AgriDonnees.machines_pour(t, cult):
		var trouve := -1
		var ms: Array = f.machines
		for i in ms.size():
			var m: Dictionary = ms[i]
			if String(m.t) == typ and not prises.has(i) and int(m.panne) < jour:
				trouve = i
				break
		if trouve >= 0:
			prises[trouve] = true
			out.append(trouve)
			continue
		if not bool(f.get("loc_auto", true)):
			return []
		# Location : une fois par jour et par type de machine (et par engin en même temps).
		var loues: Dictionary = f.loues
		var cle := "%s:%d" % [typ, prises.get("loc:" + typ, 0)]
		prises["loc:" + typ] = int(prises.get("loc:" + typ, 0)) + 1
		if int(loues.get(cle, -1)) != jour:
			loues[cle] = jour
			var prix := float(AgriDonnees.machine(typ).loc) * (1.0 - remise_concession())
			production.pay(bid, "Location de machines", -prix)
		out.append("loc:" + typ)
	return out


## Une heure de travail sur un champ.
func _travaille(bid: int, id: int, t: String, cult: String, engins: Array, h: float) -> void:
	var ch: Dictionary = champs[id]
	var f: Dictionary = fermes[bid]
	if String(ch.tache) != t:
		ch.tache = t
		ch.fait = 0.0
	var ha := surface(ch)
	var v := AgriDonnees.vitesse(t, cult) * h
	var fait := minf(v, ha - float(ch.fait))
	ch.fait = float(ch.fait) + fait
	var part := fait / maxf(v, 0.0001)
	# Gazole et usure.
	var litres := AgriDonnees.litres(t, cult) * h * part
	production.pay(bid, "Gazole", -litres * AgriDonnees.GAZOLE)
	for e in engins:
		if e is int:
			var m: Dictionary = f.machines[int(e)]
			m.h = float(m.h) + h * part
			m.us = minf(float(m.us) + AgriDonnees.USURE_H * h * part, 1.0)
			if float(m.us) > AgriDonnees.PANNE and _rng.randf() < (float(m.us) - AgriDonnees.PANNE) * 0.05:
				var cout := float(AgriDonnees.machine(String(m.t)).prix) * AgriDonnees.REPARATION * float(m.us) \
					* (0.5 if remise_concession() > 0.0 else 1.0)
				production.pay(bid, "Réparations des machines", -cout)
				m.panne = last_day + 1
				m.us = 0.35
				_journal(bid, "Panne : %s, réparée en un jour (%s)" % [AgriDonnees.machine_name(String(m.t)),
					BuildingSystem.format_money(roundi(cout))])
				message.emit("%s : %s en panne." % [nom_ferme(bid), AgriDonnees.machine_name(String(m.t)).to_lower()])
	(f.travail as Array).append({"champ": id, "tache": t, "machines": engins.duplicate(), "cult": cult})
	if float(ch.fait) >= ha - 0.0001:
		_fin_tache(bid, id, t)


func _fin_tache(bid: int, id: int, t: String) -> void:
	var ch: Dictionary = champs[id]
	var ha := surface(ch)
	ch.tache = ""
	ch.fait = 0.0
	match t:
		"labour":
			ch.etat = "laboure"
			ch.paille = 0.0
		"semis":
			var c := AgriDonnees.culture(String(ch.cult))
			production.pay(bid, "Semences", -float(c.semences) * ha)
			ch.sc = ch.cult
			ch.etat = "pousse"
			ch.cr = 0.0
			ch.eng = float(c.get("engrais", 0)) <= 0.0
			ch.tr = bool(c.get("permanente", false))
			ch.pertes = 0.0
			ch.met = _rng.randf_range(0.92, 1.08)
			ch.azote = 0.0
			_journal(bid, "Semis : %s sur %s (%s ha)" % [String(c.name).to_lower(), nom_champ(id), _ha(ha)])
		"engrais":
			_epand(bid, ch)
			ch.eng = true
		"traitement":
			production.pay(bid, "Produits de traitement", -60.0 * ha)
			ch.tr = true
		"recolte":
			_recolte(bid, id)
		"pressage":
			if float(ch.foin) > 0.0:
				production.put(bid, "foin", float(ch.foin))
				_journal(bid, "Foin pressé : %s (%s)" % [Ressources.format_t(float(ch.foin)), nom_champ(id)])
				ch.foin = 0.0
			else:
				production.put(bid, "paille", float(ch.paille))
				_journal(bid, "Paille pressée : %s (%s)" % [Ressources.format_t(float(ch.paille)), nom_champ(id)])
				ch.bottes = last_day
				ch.paille = 0.0
	changed.emit()


## Engrais : le fumier de la ferme d'abord (30 t/ha), sinon de l'engrais
## minéral (produits chimiques de la ville, ou acheté à la coopérative).
func _epand(bid: int, ch: Dictionary) -> void:
	var ha := surface(ch)
	var kg_n := float(AgriDonnees.culture(String(ch.sc)).get("engrais", 0))
	var fumier := production.stock_of(bid, "fumier")
	var besoin_fumier := 30.0 * ha
	if fumier >= besoin_fumier * 0.5:
		var pris := minf(fumier, besoin_fumier)
		production.put(bid, "fumier", -pris)
		ch.azote = float(ch.azote) + kg_n * pris / besoin_fumier
		kg_n *= 1.0 - pris / besoin_fumier
		_journal(bid, "Fumier épandu : %s" % Ressources.format_t(pris))
		ch.fumier_jour = last_day
	if kg_n <= 0.0:
		return
	# Ammonitrate à 33 % d'azote.
	var t := kg_n * ha / 1000.0 / 0.33
	var stock := production.stock_of(bid, "chimie")
	var pris2 := minf(stock, t)
	if pris2 > 0.0:
		production.put(bid, "chimie", -pris2)
	if t - pris2 > 0.0:
		production.pay(bid, "Engrais", -(t - pris2) * Ressources.price("chimie") * Ressources.IMPORT)
	ch.azote = float(ch.azote) + kg_n


## Rendement attendu d'un champ (t), d'après tout ce qui a été fait.
func rendement(ch: Dictionary) -> float:
	var cult := String(ch.sc) if String(ch.sc) != "" else String(ch.cult)
	var c := AgriDonnees.culture(cult)
	if c.is_empty() or float(c.rdt) <= 0.0:
		return 0.0
	var f := fertilite(ch) * float(ch.get("met", 1.0))
	if not AgriDonnees.convient(cult, _climat):
		f *= 0.5
	if not bool(ch.eng):
		f *= AgriDonnees.SANS_ENGRAIS
	if not bool(ch.tr):
		f *= AgriDonnees.SANS_TRAITEMENT
	if not bool(c.get("permanente", false)):
		if String(ch.prec) == cult:
			f *= AgriDonnees.MONOCULTURE
		elif String(ch.prec) in ["colza", "soja", "prairie", "paturage"] and cult in ["ble", "orge", "mais"]:
			f *= AgriDonnees.BONNE_ROTATION
	f *= 1.0 - float(ch.get("pertes", 0.0))
	return float(c.rdt) * surface(ch) * f


## Fertilité du champ (0,4 à 1,25) d'après la carte des terres cultivables.
func fertilite(ch: Dictionary) -> float:
	if not ch.has("fert") or float(ch.fert) < 0.0:
		var m := -1.0
		if production != null and production.carte != null:
			m = production.carte.mean_in("fertilite", ch.r)
		if m < 0.0:
			return 1.0
		ch.fert = clampf(0.4 + m * 1.0, 0.4, 1.25)
	return float(ch.fert)


func _recolte(bid: int, id: int) -> void:
	var ch: Dictionary = champs[id]
	var cult := String(ch.sc)
	var c := AgriDonnees.culture(cult)
	var t := rendement(ch)
	var ha := surface(ch)
	ch.rdt = t
	if bool(c.get("permanente", false)):
		# Fauche : le foin sèche au champ, puis on le presse.
		ch.foin = t
		ch.etat = "pousse"
		ch.cr = 0.0
		ch.eng = false
		ch.azote = 0.0
		_journal(bid, "Fauche : %s (%s ha), %s de foin à presser" % [nom_champ(id), _ha(ha), Ressources.format_t(t)])
	else:
		var g := String(c.good)
		production.put(bid, g, t)
		ch.paille = float(c.get("paille", 0.0)) * ha * (t / maxf(float(c.rdt) * ha, 0.001))
		ch.prec = cult
		ch.sc = ""
		ch.etat = "chaume"
		ch.cr = 0.0
		ch.jr = last_day
		_journal(bid, "Récolte : %s de %s sur %s (%s t/ha)" % [Ressources.format_t(t), String(c.name).to_lower(), nom_champ(id),
			("%.1f" % (t / maxf(ha, 0.001))).replace(".", ",")])
		message.emit("%s : %s de %s récoltées." % [nom_ferme(bid), Ressources.format_t(t), String(c.name).to_lower()])


func _grele() -> void:
	if ambiance == null or ambiance.weather == null or ambiance.weather.storm < 0.6:
		return
	for id in champs:
		var ch: Dictionary = champs[id]
		if String(ch.etat) in ["pousse", "mur"] and float(ch.cr) > 0.5 and _rng.randf() < 0.03:
			var perte := _rng.randf_range(0.1, 0.35)
			ch.met = float(ch.met) * (1.0 - perte)
			message.emit("Grêle sur %s : %d %% de la récolte perdue." % [nom_champ(int(id)), roundi(perte * 100.0)])


# --- Un jour ------------------------------------------------------------------------------

func nouveau_jour(lt: Dictionary) -> void:
	var mois := int(lt.month)
	var herbe := AgriDonnees.saison_herbe(mois, lat(), _climat)
	var sec := ambiance != null and ambiance.weather != null and ambiance.weather.temperature > 30.0 \
		and ambiance.weather.humidity < 0.3
	for id in champs:
		var ch: Dictionary = champs[id]
		if String(ch.etat) == "pousse" or String(ch.etat) == "mur":
			var c := AgriDonnees.culture(String(ch.sc))
			var perm := bool(c.get("permanente", false))
			if not perm or herbe:
				ch.cr = minf(float(ch.cr) + 1.0 / maxf(float(c.get("cycle", 100)), 1.0), 1.0 if not perm else 1.0)
			if sec and not perm and float(ch.cr) < 1.0:
				ch.met = float(ch.met) * 0.997
			if float(ch.cr) >= 1.0 and String(ch.etat) == "pousse" and not bool(c.get("paturage", false)):
				ch.etat = "mur"
				ch.jm = int(lt.day)
			elif String(ch.etat) == "mur" and not perm and int(lt.day) - int(ch.get("jm", lt.day)) > AgriDonnees.GRACE:
				ch.pertes = minf(float(ch.pertes) + AgriDonnees.PERTE_JOUR, 0.9)
		# La paille non pressée finit enfouie au labour.
		if String(ch.etat) == "chaume" and float(ch.paille) > 0.0 and int(lt.day) - int(ch.jr) > 25:
			ch.paille = 0.0
		# Chaume laissé : il se recouvre d'herbe (friche) au bout de quatre mois.
		if String(ch.etat) == "chaume" and int(lt.day) - int(ch.jr) > 120:
			ch.etat = "friche"
	_nourrit_betes()
	# Locations de la veille oubliées.
	for f in fermes.values():
		var loues: Dictionary = f.loues
		for k in loues.keys():
			if int(loues[k]) < int(lt.day) - 1:
				loues.erase(k)
	# Fermes démolies.
	for bid in fermes.keys():
		if not est_ferme(bid):
			fermes.erase(bid)


## Les bêtes mangent ce qu'il y a à la ferme, donnent leurs produits, et
## dépérissent si elles ont faim plusieurs jours.
func _nourrit_betes() -> void:
	for bid in fermes:
		var f: Dictionary = fermes[bid]
		if _betes_total(f) <= 0:
			f.nb = 1.0
			continue
		var besoin := besoins_betes(bid)
		var part := {}
		for g in besoin:
			var need := float(besoin[g])
			var have := production.stock_of(bid, g)
			var take := minf(need, have)
			part[g] = take / need if need > 0.0 else 1.0
			if take > 0.0:
				production.put(bid, g, -take)
		# Soins : assez d'éleveurs pour le troupeau ?
		var a_soigner := 0.0
		for e in f.betes:
			a_soigner += float(int(f.betes[e])) / float(AgriDonnees.espece(e).par_eleveur)
		var eleveurs := 0
		for pid in population.by_job.get(bid, []) if population != null else []:
			if population.persons.has(pid) and not AgriDonnees.PAS_AUX_CHAMPS.has(String(population.persons[pid].get("met", ""))):
				eleveurs += 1
		var soins := clampf(float(eleveurs) / maxf(a_soigner, 0.001), 0.0, 1.0) if a_soigner > 0.0 else 1.0
		var nb_total := 0.0
		var nb_n := 0
		for e in f.betes.keys():
			var sp := AgriDonnees.espece(e)
			var nourri := 1.0
			for g in sp.mange:
				# Le foin manquant est remplacé par l'herbe du pré (déjà retiré du besoin).
				nourri = minf(nourri, float(part.get(g, 1.0)))
			# Paille de litière : sans elle, un peu moins de lait.
			var litiere := float(part.get("paille", 1.0))
			var n := int(f.betes[e])
			var eff := nourri * soins * (0.9 + 0.1 * litiere)
			for g in sp.donne:
				production.put(bid, g, float(sp.donne[g]) * n * eff)
			nb_total += nourri * n
			nb_n += n
			var faim: Dictionary = f.faim
			if nourri < 0.5:
				faim[e] = int(faim.get(e, 0)) + 1
				if int(faim[e]) > 3:
					var morts := maxi(1, roundi(n * 0.05))
					f.betes[e] = n - morts
					message.emit("%s : %d %s %s de faim." % [nom_ferme(bid), morts, String(sp.un) + ("s" if morts > 1 else ""),
						"sont mortes" if morts > 1 else "est morte"])
					_journal(bid, "%d %s morte%s faute de fourrage" % [morts, String(sp.un), "s" if morts > 1 else ""])
					if int(f.betes[e]) <= 0:
						f.betes.erase(e)
			else:
				faim.erase(e)
		f.nb = nb_total / maxf(float(nb_n), 1.0)


func _journal(bid: int, txt: String) -> void:
	var f := ferme(bid)
	var j: Array = f.journal
	var lt := local_time(clock) if clock > 0.0 else {"day": 0}
	var d := Time.get_date_dict_from_unix_time(int(lt.day) * 86400)
	j.push_front("%02d/%02d · %s" % [int(d.day), int(d.month), txt])
	while j.size() > 30:
		j.pop_back()


static func _ha(x: float) -> String:
	if x >= 10.0:
		return "%d" % roundi(x)
	return ("%.1f" % x).replace(".", ",")


# --- Pollution (groupe "pollution_sources", lu par le fil pollution) ------------------

## Engrais des champs : nitrates vers l'eau (azote de l'année) et odeur les
## jours d'épandage de fumier. [{pos, rayon, eau, odeur, nom}].
func pollution_sources() -> Array:
	var out := []
	for id in champs:
		var ch: Dictionary = champs[id]
		var eau := clampf(float(ch.get("azote", 0.0)) / 250.0, 0.0, 1.0)
		var odeur := 0.3 if int(ch.get("fumier_jour", -99)) >= last_day - 1 else 0.0
		if eau <= 0.0 and odeur <= 0.0:
			continue
		var r: Rect2i = ch.r
		var c := Vector2(r.position) + Vector2(r.size) * 0.5
		out.append({"pos": Vector3(c.x, 0.0, c.y), "rayon": Vector2(r.size).length() * 0.5 + 150.0, "eau": eau,
			"odeur": odeur, "nom": "Engrais : %s" % nom_champ(int(id))})
	return out


# --- Ce qui a changé sur le terrain -------------------------------------------------------

func _on_buildings_changed() -> void:
	# Une ferme démolie : ses champs restent (on peut les rattacher à une autre).
	for id in champs:
		var ch: Dictionary = champs[id]
		if not est_ferme(int(ch.f)):
			var other := ferme_proche(Vector2((ch.r as Rect2i).get_center()))
			ch.f = other


func _marque(r: Rect2i) -> void:
	if world == null:
		return
	var cells: Array = []
	for z in range(r.position.y, r.end.y + 1, 32):
		for x in range(r.position.x, r.end.x + 1, 32):
			cells.append(Vector2i(mini(x, r.end.x - 1), mini(z, r.end.y - 1)))
	cells.append(r.end - Vector2i.ONE)
	world.mark_cells_dirty(cells)
	if visuels != null and visuels.has_method("refait"):
		visuels.refait()


func _marque_tout() -> void:
	if visuels != null and visuels.has_method("refait"):
		visuels.refait()


# --- Outil de tracé ---------------------------------------------------------------------

func set_outil(o: String) -> void:
	outil = o
	_glisse = false
	_cadre.visible = false
	_aide()


func _aide() -> void:
	match outil:
		"tracer":
			info_changed.emit("Champ de %s : clic glissé pour tracer le rectangle (près d'une ferme). Échap : arrêter." % \
				AgriDonnees.culture_name(culture_choisie).to_lower())
		"effacer":
			info_changed.emit("Clic sur un champ pour le supprimer. Échap : arrêter.")
		_:
			info_changed.emit("")


func _pick(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null or world == null:
		return null
	return world.pick_point(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


func _unhandled_input(event: InputEvent) -> void:
	if outil == "" or world == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		set_outil("")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var p: Variant = _pick((event as InputEventMouseMotion).position)
		_survol_ok = p != null
		if p != null:
			_survol = _cell_of(p)
			if _glisse:
				_montre_cadre(_rect(_debut, _survol))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var p: Variant = _pick(mb.position)
		if mb.pressed and p != null:
			if outil == "effacer":
				var id := champ_at(_cell_of(p))
				if id >= 0:
					message.emit("%s supprimé." % nom_champ(id).capitalize())
					supprime_champ(id)
			else:
				_glisse = true
				_debut = _cell_of(p)
			get_viewport().set_input_as_handled()
		elif not mb.pressed and _glisse:
			_glisse = false
			_cadre.visible = false
			if p != null:
				var id := champ_at(_cell_of(p))
				var r := _rect(_debut, _cell_of(p))
				if r.size.x * r.size.y < 16 and id >= 0:
					selection = id
					changed.emit()
				else:
					ajoute_champ(r)
			get_viewport().set_input_as_handled()


static func _rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var p := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	return Rect2i(p, Vector2i(absi(a.x - b.x) + 1, absi(a.y - b.y) + 1))


func _montre_cadre(r: Rect2i) -> void:
	var ok := bool(verifie(r).ok)
	var mat := _cadre.material_override as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.35) if ok else Color(0.9, 0.2, 0.2, 0.35)
	var h := world.cell_height(r.get_center()) if world != null else 0.0
	var m := BoxMesh.new()
	m.size = Vector3(r.size.x, 0.6, r.size.y)
	_cadre.mesh = m
	_cadre.position = Vector3(r.position.x + r.size.x * 0.5, h + 0.3, r.position.y + r.size.y * 0.5)
	_cadre.visible = true
	info_changed.emit("%s × %s m = %s ha%s" % [r.size.x, r.size.y, _ha(float(r.size.x * r.size.y) / 10000.0),
		"" if ok else " · " + String(verifie(r).raison)])


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var cs := []
	for id in champs:
		var ch: Dictionary = champs[id].duplicate()
		var r: Rect2i = ch.r
		ch.r = [r.position.x, r.position.y, r.size.x, r.size.y]
		ch.erase("fert")
		for k in ["cr", "fait", "paille", "foin", "rdt", "azote", "met", "pertes"]:
			if ch.has(k):
				ch[k] = snappedf(float(ch[k]), 0.0001)
		cs.append(ch)
	var fs := {}
	for bid in fermes:
		var f: Dictionary = fermes[bid].duplicate(true)
		f.erase("travail")
		fs[str(bid)] = f
	return {"version": 1, "champs": cs, "fermes": fs, "next": next_id, "clock": clock, "jour": last_day,
		"culture": culture_choisie, "repas": repas.to_dict() if repas else {}}


func from_dict(d: Dictionary) -> void:
	champs.clear()
	fermes.clear()
	for x in d.get("champs", []):
		var ch: Dictionary = (x as Dictionary).duplicate()
		var a: Array = ch.get("r", [0, 0, 20, 20])
		ch.r = Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
		ch.id = int(ch.get("id", 0))
		ch.f = int(ch.get("f", -1))
		for k in ["jr", "jm", "bottes"]:
			if ch.has(k):
				ch[k] = int(ch[k])
		champs[int(ch.id)] = ch
	var fs: Dictionary = d.get("fermes", {})
	for k in fs:
		var f: Dictionary = (fs[k] as Dictionary).duplicate(true)
		f.travail = []
		for key in ["machines", "journal"]:
			if not f.has(key):
				f[key] = []
		for key in ["betes", "faim", "loues"]:
			if not f.has(key):
				f[key] = {}
		var betes := {}
		for e in f.betes:
			betes[String(e)] = int(f.betes[e])
		f.betes = betes
		for m in f.machines:
			m.panne = int(m.get("panne", -1))
		fermes[int(k)] = f
	next_id = int(d.get("next", 1))
	clock = float(d.get("clock", -1.0))
	last_day = int(d.get("jour", -1))
	culture_choisie = String(d.get("culture", "ble"))
	if repas:
		repas.from_dict(d.get("repas", {}))
	_marque_tout()
	if world != null:
		for id in champs:
			_marque(champs[id].r)
	changed.emit()
