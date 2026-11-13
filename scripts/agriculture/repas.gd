class_name Repas
extends RefCounted
## Les repas des habitants : chaque foyer mange chaque jour ce qu'il a trouvé
## dans les commerces (pain, viande, poisson, laitages, fruits et légumes,
## épicerie, œufs, huile). Rayons vides plusieurs jours de suite : le foyer a
## faim. La faim fait baisser la satisfaction et la santé, puis le foyer
## déménage ; avec le réglage Admin « Mortelle », on peut en mourir.
##
## Un foyer sans aucun commerce d'alimentation à portée fait ses courses hors
## de la carte : il n'a pas faim, mais il est moins satisfait.

## Part des repas trouvée en dessous de laquelle le foyer a faim ce jour-là.
const SEUIL := 0.6
## Jours de faim avant les départs, puis avant les morts (réglage « Mortelle »).
const JOURS_DEPART := 10.0
const JOURS_MORT := 21.0

var agri: Node
## Jours de faim de chaque foyer : id du foyer -> jours (la faim retombe d'un
## jour par journée bien nourrie).
var faim: Dictionary = {}
## Part des repas trouvée hier par chaque logement : bid -> 0 à 1.
var part_logement: Dictionary = {}
## Logements sans commerce d'alimentation à portée.
var hors_carte: Dictionary = {}
## Chiffres du dernier jour : {foyers, affames, partis, morts, part}.
var bilan := {"foyers": 0, "affames": 0, "partis": 0, "morts": 0, "part": 1.0}


func _init(a: Node) -> void:
	agri = a


func clear() -> void:
	faim.clear()
	part_logement.clear()
	hors_carte.clear()
	bilan = {"foyers": 0, "affames": 0, "partis": 0, "morts": 0, "part": 1.0}


func _mode() -> String:
	return ReglagesPartie.actuel.faim


## Après les courses du jour (Production.day_passed) : qui a mangé à sa faim ?
func apres_courses() -> void:
	var pop: Population = agri.population
	var prod: Production = agri.production
	if pop == null or prod == null:
		return
	part_logement.clear()
	hors_carte.clear()
	var membres := {}
	for h in pop.households.values():
		membres[int(h.b)] = int(membres.get(int(h.b), 0)) + (h.m as Array).size()
	var somme := 0.0
	var n_log := 0
	for home in membres:
		# Campement des fondateurs : nourri par les vivres, puis le ravitaillement (Fondateurs).
		if Fondateurs.nourris(int(home)):
			part_logement[home] = 1.0
			continue
		var veut := 0.0
		var manque := 0.0
		var miss: Dictionary = prod.manque_foyers.get(home, {})
		var a_portee := false
		for g in Ressources.NOURRITURE:
			var w := float(Ressources.CONSO_HABITANT.get(g, 0.0)) * int(membres[home])
			veut += w
			manque += minf(float(miss.get(g, 0.0)), w)
			if not a_portee and not prod._shops_for(home, g).is_empty():
				a_portee = true
		if not a_portee:
			hors_carte[home] = true
			part_logement[home] = 1.0
			continue
		var part := clampf(1.0 - manque / maxf(veut, 0.000001), 0.0, 1.0)
		part_logement[home] = part
		somme += part
		n_log += 1
	var affames := 0
	var departs := []
	var morts := []
	var mode := _mode()
	for hid in pop.households:
		var h: Dictionary = pop.households[hid]
		var part := float(part_logement.get(int(h.b), 1.0))
		var j := float(faim.get(hid, 0.0))
		if part < SEUIL and mode != "aucune":
			j += 1.0 - part
		else:
			j = maxf(j - 1.0, 0.0)
		if j <= 0.0:
			faim.erase(hid)
			continue
		faim[hid] = j
		affames += 1
		if j >= JOURS_DEPART and agri._rng.randf() < 0.15:
			departs.append(hid)
		elif mode == "mortelle" and j >= JOURS_MORT:
			for pid in h.m:
				if agri._rng.randf() < 0.08:
					morts.append(pid)
	for hid in faim.keys():
		if not pop.households.has(hid):
			faim.erase(hid)
	var partis := 0
	for hid in departs:
		if pop.households.has(hid):
			partis += (pop.households[hid].m as Array).size()
			pop._remove_household(hid, "Quitte la ville : les magasins sont vides, on n'y trouve plus à manger")
			faim.erase(hid)
	for pid in morts:
		if pop.persons.has(pid):
			pop.vie.die(pid, "de malnutrition")
	if partis > 0:
		agri.message.emit("%d habitant%s quitte%s la ville : les magasins d'alimentation sont vides." % [partis,
			"s" if partis > 1 else "", "nt" if partis > 1 else ""])
	if not morts.is_empty():
		agri.message.emit("Famine : %d habitant%s mort%s de faim." % [morts.size(), "s" if morts.size() > 1 else "",
			"s" if morts.size() > 1 else ""])
	bilan = {"foyers": pop.households.size(), "affames": affames, "partis": partis, "morts": morts.size(),
		"part": somme / n_log if n_log > 0 else 1.0}


func jours_faim(p: Dictionary) -> float:
	return float(faim.get(int(p.get("f", -1)), 0.0))


## Satisfaction (Population.extra_satisfaction) : [delta, raisons].
func satisfaction(p: Dictionary) -> Array:
	if _mode() == "aucune":
		return [0.0, []]
	var pop: Population = agri.population
	var home := pop.home_of(p)
	if hors_carte.has(home):
		return [-4.0, ["− fait ses courses loin (pas de commerce d'alimentation près de chez lui)"]]
	var j := jours_faim(p)
	if j <= 0.0:
		var part := float(part_logement.get(home, 1.0))
		if part < 0.95:
			return [-3.0, ["− repas incomplets (%d %% trouvés)" % roundi(part * 100.0)]]
		return [0.0, []]
	return [-minf(6.0 + j * 2.0, 30.0), ["− a faim depuis %d jour%s" % [ceili(j), "s" if ceili(j) > 1 else ""]]]


## Santé (Population.extra_health) : [facteur de mortalité, raisons].
func sante(p: Dictionary) -> Array:
	var j := jours_faim(p)
	if j < 3.0 or _mode() == "aucune":
		return [1.0, []]
	if _mode() == "mortelle":
		return [1.0 + 0.5 * j, ["− mal nourri depuis %d jours" % ceili(j)]]
	return [1.0 + minf(0.05 * j, 0.5), ["− mal nourri depuis %d jours" % ceili(j)]]


## Bilan de la nourriture de la ville : pour chaque aliment, besoin des
## habitants, ventes d'hier et production d'hier (t par jour).
func bilan_aliments() -> Array:
	var pop: Population = agri.population
	var prod: Production = agri.production
	var n := pop.persons.size() if pop != null else 0
	var out := []
	for g in Ressources.NOURRITURE:
		var besoin := float(Ressources.CONSO_HABITANT.get(g, 0.0)) * n
		out.append({"g": g, "besoin": besoin, "vendu": float(prod.yesterday.vente.get(g, 0.0)),
			"produit": float(prod.yesterday.prod.get(g, 0.0)), "stock": float(prod.total_stock().get(g, 0.0))})
	return out


func to_dict() -> Dictionary:
	var f := {}
	for hid in faim:
		f[str(hid)] = snappedf(float(faim[hid]), 0.01)
	return {"faim": f, "bilan": bilan}


func from_dict(d: Dictionary) -> void:
	clear()
	var f: Dictionary = d.get("faim", {})
	for k in f:
		faim[int(k)] = float(f[k])
	var b: Dictionary = d.get("bilan", {})
	for k in b:
		bilan[k] = b[k]
