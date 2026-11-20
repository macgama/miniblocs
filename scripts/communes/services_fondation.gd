class_name ServicesFondation
extends Node
## Services de base prêts au premier village : le tout premier village de la
## carte (en solo, ou celui du premier joueur d'une carte partagée) reçoit, dès
## sa fondation, ce qu'il faut pour vivre à son époque, sans chantier :
##
##   - électricité, eau potable, égouts, déchets : un bâtiment de chaque réseau
##     (deux pour les déchets : dépôt des bennes et décharge), le plus moderne de
##     l'époque (CHOIX) ;
##   - posés un peu à l'écart du centre : une rue de service prolonge la rue en T
##     offerte (RueFondation) loin de la mairie, et les bâtiments la bordent ; ils
##     sont donc sur le même réseau de rues, raccordés comme les autres (Reseaux) ;
##   - ce sont les bons du kit de l'État (KitInstallation) qui servent : le kit
##     n'est pas donné deux fois, et le reste du prix est offert ;
##   - un réseau dont les habitants n'ont pas encore besoin (Epoques.ATTENDU :
##     courant en 1925, eau et égouts en 1900, déchets en 1884) ou qui n'est pas
##     encore inventé attend : il est posé tout seul l'année venue, sauf si la
##     ville en a déjà un (construit par le joueur).
##   - Réglage Admin (F10, Construction) : ReglagesPartie.services_fondation,
##     activé par défaut.
## Sauvegarde : section « services_fondation ».

signal changed
signal message(text: String)

static var instance: ServicesFondation

## Par réseau, les possibilités du plus moderne au plus ancien : la première
## dont tous les bâtiments existent à l'année de la partie est posée.
const CHOIX := {
	"elec": [["poste_national"]],
	"eau": [["forage_eau"], ["captage_eau"]],
	"egout": [["station_epuration_locale"], ["lagunage"], ["exutoire_egout"]],
	"dechets": [["depot_collecte", "decharge"], ["decharge"]],
}
const ORDRE := ["elec", "eau", "egout", "dechets"]
const NOMS := {"elec": "courant", "eau": "eau potable", "egout": "égouts", "dechets": "déchets"}
## Rue de service : classe, longueurs essayées (m).
const CLASSE := "rue"
const LONGUEURS := [200.0, 150.0, 100.0]
## Un réseau que la ville a déjà, à moins de RAYON m de sa mairie, n'est pas posé.
const RAYON := 3000.0
## Vérification de l'année (s réelles) pour les réseaux qui attendent.
const PERIODE := 2.0

var buildings: BuildingSystem
var transport: TransportSystem
var communes: Communes
var fondateurs: Fondateurs

## Village servi (-1 : aucun encore).
var vid := -1
## Réseaux traités : res -> [bid…] (vide : la ville l'avait déjà).
var poses := {}
## Tronçons de la rue de service.
var rue := []
var _t := 0.0
var _annonce := false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(bs: BuildingSystem, ts: TransportSystem, cm: Communes, f: Fondateurs) -> void:
	buildings = bs
	transport = ts
	communes = cm
	fondateurs = f
	# Après le kit et la rue en T (branchés avant) : les bons et la rue existent.
	cm.fonde.connect(_on_fonde)


func clear() -> void:
	vid = -1
	_annonce = false
	poses.clear()
	rue.clear()
	changed.emit()


## Mètres de la rue de service offerte (le tutoriel ne les compte pas comme tracés).
static func metres_offerts() -> float:
	if instance == null or instance.transport == null:
		return 0.0
	var m := 0.0
	for eid in instance.rue:
		if instance.transport.network.edges.has(eid):
			m += float(instance.transport.network.edges[eid].len)
	return m


func en_attente() -> Array:
	var out := []
	for res in ORDRE:
		if not poses.has(res):
			out.append(res)
	return out


func _on_fonde(v: int) -> void:
	if not ReglagesPartie.actuel.services_fondation or vid >= 0:
		return
	if communes == null or communes.ignorer or not communes.actif or buildings == null or transport == null:
		return
	# Entre amis, c'est le serveur qui pose et envoie à tout le monde.
	if transport.bloque_reseau() or buildings.bloque_reseau():
		return
	# Seulement le tout premier village de la carte.
	if communes.villages.size() != 1 or not communes.villages.has(v):
		return
	# Ancienne partie adoptée (habitants déjà là) : elle a ses réseaux.
	if fondateurs != null and fondateurs.population != null and not fondateurs.population.persons.is_empty() \
			and not fondateurs.arrives:
		return
	vid = v
	changed.emit()
	installer.call_deferred()


func _process(delta: float) -> void:
	if vid < 0 or poses.size() >= ORDRE.size():
		return
	_t += delta
	if _t < PERIODE:
		return
	_t = 0.0
	if not ReglagesPartie.actuel.services_fondation:
		return
	installer()


## Pose ce qui peut l'être à l'année de la partie. Renvoie les réseaux posés.
func installer() -> Array:
	var faits := []
	if vid < 0 or communes == null or not communes.villages.has(vid):
		return faits
	if transport.bloque_reseau() or buildings.bloque_reseau():
		return faits
	var noms: Array[String] = []
	for res in ORDRE:
		if poses.has(res) or not Epoques.attendu(res):
			continue
		if _deja_servi(res):
			poses[res] = []
			continue
		var ids := choix(res)
		if ids.is_empty():
			continue
		var bids := []
		for id in ids:
			var bid := _poser(String(id))
			if bid >= 0:
				bids.append(bid)
				noms.append(String(BuildingCatalog.get_type(String(id)).get("name", id)))
		if not bids.is_empty():
			poses[res] = bids
			faits.append(res)
	if faits.is_empty() and not _annonce and poses.is_empty():
		message.emit("%s commence en %d : bougies, puits et fosses suffisent encore. Courant, eau, égouts et déchets seront posés tout seuls quand leur époque viendra." % [
			String(communes.villages[vid].nom), Epoques.annee()])
	_annonce = true
	if not faits.is_empty():
		var nom := String(communes.villages[vid].nom)
		var att := en_attente()
		var suite := ""
		if not att.is_empty():
			suite = " À venir avec l'époque : %s." % ", ".join(att.map(func(r: String) -> String: return String(NOMS[r])))
		message.emit("Services de base prêts à %s, un peu à l'écart du centre : %s (offerts par l'État, déjà raccordés).%s" % [
			nom, ", ".join(noms), suite])
		changed.emit()
	return faits


## Bâtiments à poser pour ce réseau à l'année de la partie ([] : rien n'existe encore).
static func choix(res: String) -> Array:
	for option in CHOIX.get(res, []):
		var ok := true
		for id in option:
			if BuildingCatalog.get_type(String(id)).is_empty() or not Epoques.batiment_disponible(String(id)):
				ok = false
				break
		if ok:
			return option
	return []


## La ville a-t-elle déjà un bâtiment de ce réseau (posé par le joueur) ?
func _deja_servi(res: String) -> bool:
	var c: Vector2 = communes.villages[vid].c
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if KitInstallation.bon_du_type(String(b.t)) != res:
			continue
		var r := buildings._rect_of(b)
		if Vector2(r.get_center()).distance_to(c) <= RAYON:
			return true
	return false


# --- Où poser ------------------------------------------------------------------------------

func _net() -> TransportNetwork:
	return transport.network


## Rues du village (milieu sur son territoire, ou rue de service).
func _voies() -> Array:
	var out := []
	var net := _net()
	for eid in net.edges:
		if TransportTypes.mode_of(String(net.edges[eid].t)) != TransportTypes.Mode.ROAD:
			continue
		var m := net.point_at(eid, float(net.edges[eid].len) * 0.5)
		if communes.village_au_point(m.x, m.z) == vid or rue.has(eid):
			out.append(eid)
	out.sort()
	return out


## Trace la rue de service : depuis le bout de rue le plus loin de la mairie,
## tout droit vers l'extérieur.
func _tracer_rue() -> void:
	if not rue.is_empty():
		for eid in rue:
			if _net().edges.has(eid):
				return
		rue.clear()
	var net := _net()
	var c: Vector2 = communes.villages[vid].c
	var bouts := []  # [distance, noeud, direction]
	for eid in _voies():
		var e: Dictionary = net.edges[eid]
		for n in [int(e.a), int(e.b)]:
			if net.degree(n) != 1:
				continue
			var dir := -net.leave_dir(eid, n)
			dir.y = 0.0
			if dir.length() < 0.01:
				continue
			var p := net.node_pos(n)
			bouts.append([Vector2(p.x, p.z).distance_to(c), n, dir.normalized()])
	bouts.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	for bout in bouts:
		var a := net.node_pos(int(bout[1]))
		var dir: Vector3 = bout[2]
		for l in LONGUEURS:
			var b: Vector3 = a + dir * float(l)
			if communes.village_au_point(b.x, b.z) != vid:
				continue
			var r: Variant = _gratuit(func() -> Variant: return transport.build_segment(CLASSE, a, b))
			if bool((r as Dictionary).get("ok", false)):
				rue = ((r as Dictionary).get("edges", []) as Array).duplicate()
				return


## Points de pose, de part et d'autre des rues, la rue de service d'abord (de
## son bout vers le village), puis les autres rues, des plus loin aux plus près
## de la mairie : [Vector3, distance].
func _sites(recul: float) -> Array:
	var net := _net()
	var c: Vector2 = communes.villages[vid].c
	var service := []
	var autres := []
	for eid in _voies():
		var l := float(net.edges[eid].len)
		var s := 8.0
		while s < l - 6.0:
			var p := net.point_at(eid, s)
			var tg := net.tangent_at(eid, s)
			tg.y = 0.0
			tg = tg.normalized()
			var nrm := Vector3(-tg.z, 0.0, tg.x)
			for side in [1.0, -1.0]:
				var q: Vector3 = p + nrm * (net.half_width(eid) + recul) * float(side)
				var d := Vector2(q.x, q.z).distance_to(c)
				if rue.has(eid):
					service.append([q, d])
				elif d > 40.0:
					autres.append([q, d])
			s += 10.0
	var loin := func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1])
	service.sort_custom(loin)
	autres.sort_custom(loin)
	return service + autres


func _poser(id: String) -> int:
	_tracer_rue()
	var t := BuildingCatalog.get_type(id)
	var prof := maxf(float(t.get("w", 20)), float(t.get("d", 20)))
	for site in _sites(prof * 0.5 + 3.0):
		var q: Vector3 = site[0]
		var ctr := Vector2i(roundi(q.x), roundi(q.z))
		var r := buildings.best_rotation(id, ctr)
		# Essai à blanc (argent compris à part : tout est offert).
		var res: Dictionary = _gratuit(func() -> Variant: return buildings.check_place(id, ctr, r))
		if not bool(res.get("ok", false)):
			continue
		var bid := int(_gratuit(func() -> Variant: return buildings.place(id, ctr, r)))
		if bid >= 0:
			# Le bon du kit de l'État sert (il n'est pas donné deux fois).
			if KitInstallation.instance != null:
				KitInstallation.instance.utiliser(bid, id, res.rect, true)
			return bid
	return -1


## Appelle f sans chantier et sans rien faire payer (cadeau de l'État).
func _gratuit(f: Callable) -> Variant:
	var illimite := buildings.unlimited_money
	var chantiers := BatimentsVie.chantiers
	var caisse_prev := Pays.a_la_caisse(vid)
	var argent := buildings.money
	buildings.unlimited_money = true
	BatimentsVie.chantiers = false
	var out: Variant = f.call()
	buildings.money = argent
	BatimentsVie.chantiers = chantiers
	buildings.unlimited_money = illimite
	Pays.retour(caisse_prev)
	return out


# --- Sauvegarde ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "vid": vid, "poses": poses.duplicate(true), "rue": rue.duplicate()}


func from_dict(d: Dictionary) -> void:
	vid = int(d.get("vid", -1))
	poses.clear()
	var p: Dictionary = d.get("poses", {})
	for res in p:
		var l := []
		for b in p[res]:
			l.append(int(b))
		poses[String(res)] = l
	_annonce = true
	rue.clear()
	for e in d.get("rue", []):
		rue.append(int(e))
	# Ancienne partie (sans section) : rien à poser après coup.
	if not d.has("vid"):
		vid = -1
	changed.emit()
