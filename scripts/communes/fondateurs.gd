class_name Fondateurs
extends Node
## Les fondateurs du village : au début d'une partie lancée du globe, il n'y a
## encore aucun habitant. Quand la Maison de commune du premier village est
## posée, les fondateurs arrivent (100 par défaut, réglage Admin F10) et plantent
## leur campement à côté : c'est la réserve de travailleurs des premiers
## chantiers.
##
## - Les chantiers ont besoin d'ouvriers (réglage Admin « main_oeuvre ») : une
##   équipe complète par chantier (Chantiers.equipe_batiment, equipe_travaux).
##   Les ouvriers sont les fondateurs restés au campement (base de chantier) et
##   les employés des entreprises du bâtiment. Ils vont aux chantiers dans
##   l'ordre où ceux-ci ont commencé ; un chantier sans ouvriers attend, un
##   chantier à équipe incomplète avance moins vite. On peut mettre un chantier
##   en pause ou le passer en premier (panneau Maj+H) : il faut doser.
## - Les fondateurs peuvent prendre n'importe quel métier : le joueur les affecte
##   aux postes libres des bâtiments finis (ferme, boulangerie, école…), ou les
##   rappelle au chantier.
## - Ils dorment sous la tente : ni loyer ni courses. Leurs vivres durent un
##   certain nombre de jours (réglage Admin) ; ensuite le ravitaillement du
##   campement est payé par la caisse.
## - Dès qu'une maison est finie, un foyer de fondateurs y emménage avant tout
##   nouvel arrivant : le campement se vide. Logés, ils comptent comme les
##   premiers habitants (paliers, territoire).
##
## - Village neuf (le 2e, le 3e…) : une équipe de pionniers vient lancer ses
##   chantiers (PIONNIERS_PART des fondateurs réglés, 30 par défaut) pendant
##   PIONNIERS_JOURS jours, ou jusqu'à ce que le village ne soit plus neuf
##   (Communes.JEUNE_FOYERS). Ils ne travaillent que pour ce village, aux
##   logements d'abord ; ensuite, le premier chantier de chaque village passe
##   avant les autres (repartir).
##
## Sauvegarde : section « fondateurs » (terre_main.save_sections).

signal changed
signal message(text: String)

const CAMPEMENT := "campement"
const ENTREPRISE := "entreprise_btp"
const METIER := "ouvrier_btp"
## Ravitaillement d'un fondateur pour une journée, une fois les vivres épuisés (€).
const RATION := 12.0
## Variantes du campement : 0 = toutes les tentes, 4 = plus aucune (BuildingCatalog).
const VARIANTES_CAMP := 4
## Distances (m) essayées autour de la Maison de commune pour planter le campement.
const DISTANCES_CAMP := [34.0, 44.0, 56.0, 70.0, 90.0, 115.0, 145.0]
const NOMS_RESEAUX := {"elec": "électricité", "eau": "eau potable", "egout": "égouts", "gaz": "gaz"}

static var instance: Fondateurs

var buildings: BuildingSystem
var population: Population
var communes: Communes
var vie: BatimentsVie
var suivi: SuiviChantiers
var ambiance: DayNight

## Les fondateurs sont arrivés dans cette partie (sinon : ancienne partie,
## bac à sable… et les chantiers n'ont pas besoin d'ouvriers).
var arrives := false
## Campement (id du bâtiment), -1 s'il n'existe plus.
var camp := -1
## Habitants arrivés comme fondateurs (ids, même ceux qui sont morts ou partis).
var membres: Array = []
## Foyers sous la tente à l'arrivée (pour vider le campement peu à peu).
var foyers_depart := 0
## Rations restantes (une par fondateur sous la tente et par jour).
var vivres := 0.0
## Ravitaillement payé par la caisse depuis la fin des vivres (€).
var ravitaillement := 0
## Le ravitaillement n'a pas pu être payé hier : le campement a faim.
var affame := false
## Chantiers de voies et de réseaux en pause, ou passés en premier (clé -> valeur).
var pauses := {}
var ordres := {}

## Répartition calculée : clé du chantier -> ouvriers, et équipe complète voulue.
var repartition := {}
var besoins := {}
## Ouvriers disponibles en tout, et sans chantier.
var total_ouvriers := 0
var libres := 0

var _acc := 0.0
var _jour := -1
var _alerte_vivres := false
var _reloges := 0
var _news := 0.0
## Ouvriers en plus envoyés par l'État avec le kit d'installation (KitInstallation),
## ajoutés aux fondateurs à leur arrivée.
var renfort_en_attente := 0
## Ouvriers arrivés en renfort depuis le début de la partie.
var renfort_total := 0
## Pionniers des villages neufs : vid -> {"n": ouvriers, "fin": heure unix de leur départ}.
var pionniers := {}
## Pionniers sans chantier dans leur village (repartir) : vid -> n.
var pionniers_libres := {}

## Part des fondateurs (réglage Admin) envoyée à chaque village neuf, et pour combien de jours.
const PIONNIERS_PART := 0.3
const PIONNIERS_MIN := 10
const PIONNIERS_JOURS := 60.0


func setup(b: BuildingSystem, p: Population, c: Communes, v: BatimentsVie, s: SuiviChantiers, a: DayNight) -> void:
	buildings = b
	population = p
	communes = c
	vie = v
	suivi = s
	ambiance = a
	instance = self
	if communes != null:
		communes.fonde.connect(_on_fonde)
	if buildings != null:
		buildings.removed.connect(_on_removed)
		var prev: Callable = buildings.demolish_check
		buildings.demolish_check = func(bid: int) -> String:
			var why := raison_demolir(bid)
			if why == "" and prev.is_valid():
				why = String(prev.call(bid))
			return why
	if population != null:
		population.avant_arrivees = reloger


func _exit_tree() -> void:
	if instance == self:
		instance = null


func clear() -> void:
	arrives = false
	renfort_en_attente = 0
	renfort_total = 0
	pionniers.clear()
	pionniers_libres.clear()
	camp = -1
	membres.clear()
	foyers_depart = 0
	vivres = 0.0
	ravitaillement = 0
	affame = false
	pauses.clear()
	ordres.clear()
	repartition.clear()
	besoins.clear()
	total_ouvriers = 0
	libres = 0
	_jour = -1
	_alerte_vivres = false
	changed.emit()


# --- Questions -------------------------------------------------------------------------

## Les chantiers ont-ils besoin d'ouvriers dans cette partie ?
func regle_active() -> bool:
	return arrives and ReglagesPartie.actuel.main_oeuvre and not Chantiers.instantanes()


static func est_campement(bid: int) -> bool:
	return instance != null and bid >= 0 and bid == instance.camp


## Le foyer de ce logement est-il nourri sans faire ses courses (campement) ?
static func nourris(bid: int) -> bool:
	return est_campement(bid) and not instance.affame


## Part de l'équipe présente sur un chantier (0 : arrêté, 1 : équipe complète).
## Clés : "bat:<id du bâtiment>" ou celles de SuiviChantiers ("voie:12"…).
static func facteur_de(cle: String) -> float:
	return instance.facteur(cle) if instance != null else 1.0


static func cle_batiment(bid: int) -> String:
	return "bat:%d" % bid


func facteur(cle: String) -> float:
	if en_pause(cle):
		return 0.0
	if not regle_active():
		return 1.0
	if not repartition.has(cle):
		repartir()
	return float(repartition.get(cle, 0)) / maxf(float(besoins.get(cle, 1)), 1.0)


func en_pause(cle: String) -> bool:
	if cle.begins_with("bat:"):
		var bid := int(cle.substr(4))
		return buildings != null and buildings.buildings.has(bid) and bool(buildings.buildings[bid].get("pause", false))
	return pauses.has(cle)


## Ouvriers sur ce chantier et équipe complète : [ouvriers, équipe].
func equipe_de(cle: String) -> Array:
	if not repartition.has(cle):
		repartir()
	return [int(repartition.get(cle, 0)), int(besoins.get(cle, 0))]


## Les fondateurs encore en vie et dans la ville.
func vivants() -> Array:
	var out := []
	if population == null:
		return out
	for pid in membres:
		if population.persons.has(int(pid)):
			out.append(int(pid))
	return out


## Habitants qui dorment encore au campement.
func au_campement() -> int:
	if population == null or camp < 0:
		return 0
	var n := 0
	for hid in population.by_home.get(camp, []):
		if population.households.has(hid):
			n += (population.households[hid].m as Array).size()
	return n


## Fondateurs qui travaillent à la base de chantier du campement.
func au_chantier() -> Array:
	var out := []
	if population == null or camp < 0:
		return out
	for pid in population.by_job.get(camp, []):
		if population.persons.has(pid):
			out.append(int(pid))
	return out


## Bâtiments dont les employés font avancer les chantiers.
static func est_base_chantier(type_id: String) -> bool:
	return type_id == CAMPEMENT or Metiers.keys_of(type_id).has(ENTREPRISE)


## Ouvriers disponibles : fondateurs au campement et employés des entreprises du bâtiment.
func ouvriers() -> Dictionary:
	var out := {"fondateurs": 0, "entreprises": 0, "pionniers": 0}
	for vid in pionniers:
		out.pionniers += int(pionniers[vid].n)
	if population == null or buildings == null:
		return out
	for bid in population.by_job:
		if not buildings.buildings.has(bid):
			continue
		var t := String(buildings.buildings[bid].t)
		if not est_base_chantier(t):
			continue
		var n := 0
		for pid in population.by_job[bid]:
			if population.persons.has(pid):
				n += 1
		if bid == camp:
			out.fondateurs += n
		else:
			out.entreprises += n
	return out


## Tous les chantiers en cours, dans l'ordre où ils reçoivent les ouvriers :
## [{cle, bid, nom, besoin, ordre, pause, av}].
func liste_chantiers() -> Array:
	var out := []
	if vie != null and buildings != null:
		for bid in vie._chantiers:
			if not buildings.buildings.has(bid):
				continue
			var b: Dictionary = buildings.buildings[bid]
			var t := String(b.t)
			out.append({"cle": cle_batiment(bid), "bid": int(bid), "nom": String(BuildingCatalog.get_type(t).get("name", t)),
				"besoin": Chantiers.equipe_batiment(t), "ordre": float(b.get("ordre", b.get("ne", 0.0))),
				"pause": bool(b.get("pause", false)), "av": float(b.get("av", 0.0)), "attente": bool(b.get("attente", false)),
				"vid": communes.village_de(bid) if communes != null else -1, "log": int(BuildingCatalog.get_type(t).get("logements", 0))})
	if suivi != null:
		for cle in suivi.chantiers:
			var c: Dictionary = suivi.chantiers[cle]
			out.append({"cle": String(cle), "bid": -1, "nom": nom_travaux(String(cle)),
				"besoin": Chantiers.equipe_travaux(float(c.hr)), "ordre": float(ordres.get(cle, c.get("t0", 0.0))),
				"pause": pauses.has(cle), "av": float(c.av), "vid": int(c.get("payeur", -1))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.ordre) != float(b.ordre):
			return float(a.ordre) < float(b.ordre)
		# Même heure de départ : le premier posé d'abord (bâtiments), puis les travaux.
		if (int(a.bid) >= 0) != (int(b.bid) >= 0):
			return int(a.bid) >= 0
		if int(a.bid) >= 0:
			return int(a.bid) < int(b.bid)
		return String(a.cle).naturalnocasecmp_to(String(b.cle)) < 0)
	return out


static func nom_travaux(cle: String) -> String:
	if cle.begins_with("voie:"):
		return "Voie (tronçon %s)" % cle.get_slice(":", 1)
	if cle.begins_with("reparation:"):
		return "Réparation de voie"
	if cle.begins_with("reseau:"):
		var r := cle.get_slice(":", 1)
		return "Réseau (%s)" % NOMS_RESEAUX.get(r, r)
	return "Travaux"


## Distribue les ouvriers aux chantiers, dans l'ordre, chacun jusqu'à son équipe complète.
## À plusieurs villages, le premier chantier de chaque village passe d'abord : un
## village neuf n'attend pas que la grande ville ait fini tous les siens.
func repartir() -> void:
	repartition.clear()
	besoins.clear()
	var o := ouvriers()
	total_ouvriers = int(o.fondateurs) + int(o.entreprises) + int(o.pionniers)
	var dispo := int(o.fondateurs) + int(o.entreprises)
	var liste := liste_chantiers()
	# Les pionniers d'un village neuf ne travaillent que chez eux, aux logements
	# d'abord (la Maison de commune et les rues passent par les autres ouvriers).
	pionniers_libres.clear()
	for vid in pionniers:
		var reste := int(pionniers[vid].n)
		for logements in [true, false]:
			for ch in liste:
				if reste <= 0:
					break
				if int(ch.get("vid", -1)) != int(vid) or (int(ch.get("log", 0)) > 0) != logements \
						or bool(ch.pause) or bool(ch.get("attente", false)) or repartition.has(ch.cle):
					continue
				var n := mini(int(ch.besoin), reste)
				repartition[ch.cle] = n
				reste -= n
		pionniers_libres[vid] = reste
	var premiers := {}
	if communes != null and communes.villages.size() >= 2:
		var vus := {}
		for ch in liste:
			var vid := int(ch.get("vid", -1))
			if vid < 0 or vus.has(vid) or bool(ch.pause) or bool(ch.get("attente", false)):
				continue
			vus[vid] = true
			premiers[ch.cle] = true
	for passe in 2:
		for ch in liste:
			if premiers.has(ch.cle) != (passe == 0):
				continue
			besoins[ch.cle] = int(ch.besoin)
			# En pause, ou arrêté faute d'argent : les ouvriers vont aux chantiers suivants.
			if bool(ch.pause) or bool(ch.get("attente", false)):
				repartition[ch.cle] = 0
				continue
			var deja := int(repartition.get(ch.cle, 0))
			var n := mini(int(ch.besoin) - deja, dispo)
			repartition[ch.cle] = deja + n
			dispo -= n
	libres = dispo


## Les promoteurs des zones peuvent-ils ouvrir un nouveau chantier ? Seulement
## s'il reste des ouvriers : sinon les maisons des zones s'empilent en chantiers
## arrêtés (des centaines au bout d'un mois) et prennent les ouvriers des
## chantiers du joueur qui viennent après elles.
const CHANTIERS_PRIVES_EN_ATTENTE := 2


## vid : village neuf où le promoteur veut construire (ZoneSystem) ; il garde
## toujours deux chantiers en cours, que repartir() sert en premier.
func accepte_chantier_prive(vid := -1) -> bool:
	if not regle_active():
		return true
	repartir()
	var attente := 0
	for cle in repartition:
		if int(repartition[cle]) == 0 and not en_pause(String(cle)):
			attente += 1
	if libres > 0 or attente < CHANTIERS_PRIVES_EN_ATTENTE:
		return true
	if vid < 0 or communes == null or not communes.est_jeune(vid) or vie == null:
		return false
	if int(pionniers_libres.get(vid, 0)) > 0:
		return true
	var n := 0
	for bid in vie._chantiers:
		if communes.village_de(bid) == vid:
			n += 1
	return n < CHANTIERS_PRIVES_EN_ATTENTE


# --- Commandes du joueur -------------------------------------------------------------------

func basculer_pause(cle: String) -> void:
	if cle.begins_with("bat:"):
		var bid := int(cle.substr(4))
		if buildings == null or not buildings.buildings.has(bid):
			return
		var b: Dictionary = buildings.buildings[bid]
		if bool(b.get("pause", false)):
			b.erase("pause")
		else:
			b["pause"] = true
	elif pauses.has(cle):
		pauses.erase(cle)
	else:
		pauses[cle] = true
	repartir()
	changed.emit()


## Passe un chantier en tête : il reçoit ses ouvriers avant les autres.
func prioriser(cle: String) -> void:
	var mini_ordre := INF
	for ch in liste_chantiers():
		mini_ordre = minf(mini_ordre, float(ch.ordre))
	if is_inf(mini_ordre):
		return
	var v := mini_ordre - 1.0
	if cle.begins_with("bat:"):
		var bid := int(cle.substr(4))
		if buildings != null and buildings.buildings.has(bid):
			buildings.buildings[bid]["ordre"] = v
	else:
		ordres[cle] = v
	repartir()
	changed.emit()


## Bâtiments finis qui ont des postes libres (hors base de chantier du campement).
func postes_libres() -> Array:
	var out := []
	if population == null:
		return out
	for bid in population.known:
		if bid == camp:
			continue
		var n := population.free_jobs(bid)
		if n > 0:
			out.append(int(bid))
	return out


## Envoie jusqu'à n fondateurs du chantier vers les postes libres d'un bâtiment.
## metier "" : celui qui manque (Effectif), sinon tiré dans la liste du bâtiment.
## Renvoie le nombre de fondateurs affectés.
func affecter(bid: int, n: int, metier := "") -> int:
	if population == null or not population.known.has(bid) or bid == camp:
		return 0
	var dispo := au_chantier()
	var k := mini(n, mini(dispo.size(), population.free_jobs(bid)))
	if k <= 0:
		return 0
	var t := String(population.known[bid].t)
	for i in k:
		var met := metier
		if met == "" and population.effectif != null and population.effectif.ferme(bid):
			var req := Effectif.requis_de(t)
			if not req.is_empty():
				met = String(req[0])
		population._join_job(population.persons[dispo[i]], bid, met)
		if population.effectif != null:
			population.effectif.oublier(bid)
	_maj_camp()
	population._apres_embauches()
	repartir()
	population.changed.emit()
	changed.emit()
	return k


## Fondateurs qui travaillent dans ce bâtiment (pas au campement).
func fondateurs_dans(bid: int) -> Array:
	var out := []
	if population == null:
		return out
	for pid in population.by_job.get(bid, []):
		if membres.has(pid):
			out.append(int(pid))
	return out


## Fondateurs sans emploi (bâtiment démoli…).
func sans_emploi() -> Array:
	var out := []
	for pid in vivants():
		var p: Dictionary = population.persons[pid]
		if int(p.job) < 0 and population.stage(p) == "chomeur":
			out.append(pid)
	return out


## Rappelle jusqu'à n fondateurs d'un bâtiment (ou sans emploi si bid < 0) au chantier.
func rappeler(bid: int, n: int) -> int:
	if population == null or camp < 0 or not population.known.has(camp):
		return 0
	var liste := fondateurs_dans(bid) if bid >= 0 else sans_emploi()
	var k := mini(n, liste.size())
	if k <= 0:
		return 0
	var b: Dictionary = buildings.buildings[camp]
	b["nemp"] = int(b.get("nemp", 0)) + k
	population.known[camp].emp = int(b.nemp)
	for i in k:
		population._join_job(population.persons[liste[i]], camp, METIER)
	if bid >= 0 and population.effectif != null:
		population.effectif.oublier(bid)
	_maj_camp()
	population._apres_embauches()
	repartir()
	population.changed.emit()
	changed.emit()
	return k


# --- Arrivée ---------------------------------------------------------------------------------

func _on_fonde(vid: int) -> void:
	if arrives and communes != null and not communes.ignorer and communes.villages.size() >= 2 and regle_active():
		envoyer_pionniers(vid)
		return
	if arrives or communes == null or communes.ignorer or not communes.actif:
		return
	if ReglagesPartie.actuel.fondateurs <= 0 or communes.villages.size() != 1:
		return
	# Partie neuve seulement (une ancienne partie adoptée a déjà ses habitants).
	if population == null or not population.persons.is_empty():
		return
	var bid := int(communes.villages[vid].bid)
	if buildings == null or not buildings.buildings.has(bid):
		return
	# Après la pose de la Maison de commune (on est encore dans BuildingSystem.place).
	arriver.call_deferred(ReglagesPartie.actuel.fondateurs, bid)


## Une équipe de pionniers part lancer les chantiers d'un village neuf.
func envoyer_pionniers(vid: int) -> void:
	var n := maxi(PIONNIERS_MIN, roundi(ReglagesPartie.actuel.fondateurs * PIONNIERS_PART))
	var t := ambiance.unix_time if ambiance != null else 0.0
	pionniers[vid] = {"n": n, "fin": t + PIONNIERS_JOURS * 86400.0}
	repartir()
	changed.emit()
	message.emit("%d pionniers arrivent à %s pour lancer ses chantiers : ils y travaillent %d jours, ou jusqu'à ce que le village compte %d foyers." % [
		n, String(communes.villages[vid].nom), roundi(PIONNIERS_JOURS), Communes.JEUNE_FOYERS])


## Les pionniers repartent quand leur temps est fini, ou quand le village a grandi.
func _maj_pionniers() -> void:
	var t := ambiance.unix_time if ambiance != null else 0.0
	for vid in pionniers.keys():
		var parti := communes == null or not communes.villages.has(vid)
		if not parti and (t >= float(pionniers[vid].fin) or not communes.est_jeune(int(vid))):
			message.emit("Les pionniers de %s ont fini leur mission : le village compte sur ses propres ouvriers (entreprise du bâtiment)." % String(communes.villages[vid].nom))
			parti = true
		if parti:
			pionniers.erase(vid)
			changed.emit()


## Les fondateurs arrivent : campement près de la mairie, foyers, emplois au chantier.
func arriver(n: int, mairie: int) -> bool:
	if arrives or n <= 0 or buildings == null or population == null:
		return false
	n += renfort_en_attente
	renfort_total += renfort_en_attente
	renfort_en_attente = 0
	var cb := _planter_camp(mairie)
	if cb < 0:
		message.emit("Pas de place pour le campement des fondateurs près de la Maison de commune : les chantiers avancent sans eux.")
		return false
	camp = cb
	var rng := population.rng
	# Foyers : des couples et des personnes seules, tous en âge de travailler.
	var tailles := []
	var reste := n
	while reste > 0:
		var tl := 2 if reste >= 2 and rng.randf() < 0.45 else 1
		tailles.append(tl)
		reste -= tl
	var b: Dictionary = buildings.buildings[camp]
	b["nlog"] = tailles.size()
	b["nemp"] = n
	population._sync_buildings()
	if not population.known.has(camp):
		population.known[camp] = population._info_of(b)
	population.known[camp].log = tailles.size()
	population.known[camp].emp = n
	membres.clear()
	for tl in tailles:
		_creer_foyer(int(tl))
	foyers_depart = tailles.size()
	vivres = float(n) * float(ReglagesPartie.actuel.vivres_jours)
	ravitaillement = 0
	affame = false
	_alerte_vivres = false
	arrives = true
	_jour = _jour_actuel()
	_maj_camp()
	population._apres_embauches(true)
	repartir()
	var nom := Avis.ville() if Avis.instance != null else "le village"
	message.emit("%d fondateurs arrivent à %s et plantent leur campement : ce sont tes ouvriers pour les premiers chantiers (%d jours de vivres). Répartis-les avec Maj+H." % [
		n, nom, ReglagesPartie.actuel.vivres_jours])
	population.changed.emit()
	changed.emit()
	return true


## Renfort de l'État (kit d'installation d'un nouveau pays) : n ouvriers de plus
## rejoignent le campement, avec leurs vivres. Rend le nombre arrivé.
func renfort(n: int) -> int:
	if n <= 0 or population == null:
		return 0
	if not arrives or camp < 0 or buildings == null or not buildings.buildings.has(camp):
		renfort_en_attente += n
		return 0
	var rng := population.rng
	# Place au campement avant les arrivées (logements et postes au chantier).
	var b: Dictionary = buildings.buildings[camp]
	b["nlog"] = int(b.get("nlog", 0)) + n
	b["nemp"] = int(b.get("nemp", 0)) + n
	if population.known.has(camp):
		population.known[camp].log = int(b.nlog)
		population.known[camp].emp = int(b.nemp)
	var reste := n
	var nf := 0
	while reste > 0:
		var tl := 2 if reste >= 2 and rng.randf() < 0.45 else 1
		_creer_foyer(tl)
		nf += 1
		reste -= tl
	foyers_depart += nf
	renfort_total += n
	vivres += float(n) * float(ReglagesPartie.actuel.vivres_jours)
	affame = false
	_alerte_vivres = false
	_maj_camp()
	population._apres_embauches(true)
	repartir()
	population.changed.emit()
	changed.emit()
	return n


func _creer_foyer(taille: int) -> void:
	var rng := population.rng
	var hid := population.next_hid
	population.next_hid += 1
	var region := population._start_region()
	var h := {"id": hid, "b": camp, "reg": region, "ep": float(rng.randi_range(3, 12) * 1000), "car": 0, "m": []}
	population.households[hid] = h
	if not population.by_home.has(camp):
		population.by_home[camp] = []
	(population.by_home[camp] as Array).append(hid)
	var nom := Prenoms.family_name(rng, region)
	if taille >= 2:
		var a := rng.randf_range(23.0, 45.0)
		population._add_person(hid, "F", a + rng.randf_range(-3.0, 3.0), "adulte", nom)
		population._add_person(hid, "H", a + rng.randf_range(-3.0, 4.0), "adulte", nom)
	else:
		population._add_person(hid, "F" if rng.randf() < 0.45 else "H", rng.randf_range(19.0, 55.0), "adulte", nom)
	population.vie.on_arrival(hid, "couple" if taille >= 2 else "seul")
	for pid in h.m:
		membres.append(int(pid))
		var p: Dictionary = population.persons[pid]
		population.vie.log_event(p, "demenage", "Arrive parmi les fondateurs du village et dort sous la tente", camp)
		population._join_job(p, camp, METIER)


## Plante le campement près de la Maison de commune. Renvoie son id, ou -1.
func _planter_camp(mairie: int) -> int:
	if not buildings.buildings.has(mairie):
		return -1
	var r := buildings._rect_of(buildings.buildings[mairie])
	var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)
	for dist in DISTANCES_CAMP:
		for i in 12:
			var a := float(i) / 12.0 * TAU
			var p := Vector2i(roundi(c.x + cos(a) * dist), roundi(c.y + sin(a) * dist))
			for rot in [0, 1]:
				if buildings.check_place(CAMPEMENT, p, rot).ok:
					var unl := buildings.unlimited_money
					buildings.unlimited_money = true
					var bid := buildings.place(CAMPEMENT, p, rot)
					buildings.unlimited_money = unl
					if bid >= 0:
						return bid
	return -1


# --- Vie du campement --------------------------------------------------------------------------

## Avant les arrivées : les foyers du campement emménagent dans les logements libres.
func reloger() -> void:
	if population == null or camp < 0 or not population.by_home.has(camp):
		return
	var foyers: Array = (population.by_home[camp] as Array).duplicate()
	if foyers.is_empty():
		return
	var origine := population.building_pos(camp)
	var bouge := 0
	for hid in foyers:
		var best := -1
		var best_d := INF
		for bid in population.known:
			if bid == camp or population.free_homes(bid) <= 0:
				continue
			var d := origine.distance_squared_to(population.building_pos(bid))
			if d < best_d:
				best_d = d
				best = bid
		if best < 0:
			break
		population.move_household(int(hid), best)
		bouge += (population.households[hid].m as Array).size()
	if bouge > 0:
		_reloges += bouge
		_maj_camp()
		changed.emit()


## Places du campement : tentes = foyers restants, base de chantier = fondateurs
## qui y travaillent. Le campement se vide à vue d'œil.
func _maj_camp() -> void:
	if camp < 0 or buildings == null or not buildings.buildings.has(camp):
		return
	var b: Dictionary = buildings.buildings[camp]
	var nf := (population.by_home.get(camp, []) as Array).size()
	var ne := (population.by_job.get(camp, []) as Array).size()
	b["nlog"] = nf
	b["nemp"] = ne
	if population.known.has(camp):
		population.known[camp].log = nf
		population.known[camp].emp = ne
	var v := VARIANTES_CAMP
	if foyers_depart > 0:
		v = clampi(roundi(float(VARIANTES_CAMP) * (1.0 - float(nf) / float(foyers_depart))), 0, VARIANTES_CAMP)
		if nf > 0:
			v = mini(v, VARIANTES_CAMP - 1)
	if int(b.get("v", 0)) != v:
		buildings.set_perso(camp, buildings.perso_of(camp), v)


## On ne démonte pas le campement tant que des fondateurs y dorment.
func raison_demolir(bid: int) -> String:
	if bid != camp:
		return ""
	var n := au_campement()
	if n <= 0:
		return ""
	return "Le campement abrite encore %d fondateurs : construis-leur des maisons avant de le démonter." % n


func _on_removed(bid: int) -> void:
	if bid != camp or buildings == null or buildings.buildings.has(bid):
		return
	camp = -1
	message.emit("Le campement des fondateurs est démonté : ses ouvriers cherchent un autre emploi.")
	changed.emit()


func _jour_actuel() -> int:
	if ambiance == null:
		return 0
	return int(floor((ambiance.unix_time + ambiance.utc_offset() * 3600.0) / 86400.0))


func _process(delta: float) -> void:
	if not arrives:
		return
	_acc += delta
	_news -= delta
	if _news <= 0.0 and _reloges > 0:
		var reste := au_campement()
		var txt := "%d fondateur%s emménage%s dans une maison." % [_reloges, "s" if _reloges > 1 else "", "nt" if _reloges > 1 else ""]
		if reste == 0:
			txt += " Le campement est vide : tous les fondateurs sont logés."
		else:
			txt += " Encore %d sous la tente." % reste
		message.emit(txt)
		_reloges = 0
		_news = 4.0
	if _acc < 0.5:
		return
	_acc = 0.0
	if not pionniers.is_empty():
		_maj_pionniers()
	repartir()
	var j := _jour_actuel()
	if _jour < 0 or j < _jour:
		_jour = j
	var n := 0
	while _jour < j and n < 3:
		_jour += 1
		n += 1
		nouveau_jour()
	_jour = maxi(_jour, j)


## Un jour passe : les fondateurs sous la tente mangent leurs vivres, puis le
## ravitaillement payé par la caisse.
func nouveau_jour() -> void:
	depanner()
	var n := au_campement()
	if n <= 0:
		affame = false
		return
	if vivres >= n:
		vivres -= n
		affame = false
		if not _alerte_vivres and vivres < n * 7.0:
			_alerte_vivres = true
			message.emit("Campement : plus que %d jours de vivres pour %d fondateurs sous la tente. Construis des maisons !" % [
				floori(vivres / n), n])
		return
	var manque := float(n) - vivres
	var premiere := vivres > 0.0 or ravitaillement == 0
	vivres = 0.0
	var cout := roundi(manque * RATION)
	# Le ravitaillement est payé par la caisse du premier village.
	var caisse_prev := Pays.a_la_caisse(communes.principal()) if communes != null and not communes.villages.is_empty() else -1
	if buildings != null and not buildings.unlimited_money and buildings.money < cout:
		Pays.retour(caisse_prev)
		if not affame:
			message.emit("Le campement n'a plus de vivres et la caisse ne peut pas payer le ravitaillement : les fondateurs ont faim.")
		affame = true
		return
	if buildings != null and not buildings.unlimited_money:
		buildings.money -= cout
	Pays.retour(caisse_prev)
	ravitaillement += cout
	affame = false
	if premiere:
		message.emit("Vivres épuisés : le ravitaillement du campement coûte %s par jour (%d fondateurs sous la tente)." % [
			BuildingSystem.format_money(roundi(n * RATION)), n])


## Services vitaux (eau, électricité, égouts, déchets) : sans personnel, toute la
## ville en pâtit. Les fondateurs y vont même s'il faut les prendre aux chantiers.
const VITAUX := ["reseaux", "dechets"]


static func est_vital(info: Dictionary) -> bool:
	return VITAUX.has(String(info.get("cat", "")))


## Fondateurs sans chantier (libres) : chaque matin, ils vont tenir les
## bâtiments fermés faute de personnel (forage ou dépôt de collecte sans
## personne, boulangerie sans boulanger, école sans enseignant…), autant qu'il
## en faut pour ouvrir, puis les commerces où l'on fait la queue. Les services
## vitaux (VITAUX) passent d'abord et sont tenus à moitié au moins, quitte à
## prendre des ouvriers aux chantiers : les fondateurs ont un emploi (la base de
## chantier), ils ne sont jamais « sans emploi » pour les embauches ordinaires.
## Renvoie le nombre affecté.
func depanner() -> int:
	if population == null or population.effectif == null or camp < 0 or not regle_active():
		return 0
	repartir()
	var faits := 0
	for vitaux in [true, false]:
		for bid in population.known.keys():
			if bid == camp or not population.known.has(bid) or population.free_jobs(bid) <= 0:
				continue
			var info: Dictionary = population.known[bid]
			var vital := est_vital(info)
			if vital != vitaux or (not vital and libres <= 0):
				continue
			var e := population.effectif.etat(bid)
			if e.is_empty() or population.effectif.en_greve(bid):
				continue
			var t := String(info.t)
			var n := 0
			var met := ""
			var pourquoi := String(e.raison)
			if bool(e.ferme) and not (e.requis as Array).is_empty():
				var deja := 0
				for m in e.requis:
					deja += int((e.par_metier as Dictionary).get(m, 0))
				n = maxi(Effectif.requis_min_de(t) - deja, 1)
				met = String(e.requis[0])
				if vital:
					n = maxi(n, ceili(int(e.prevus) * Effectif.SOUS_EFFECTIF) - int(e.embauches))
			elif vital and bool(e.manque):
				# Forage, poste électrique, station d'épuration, décharge : la moitié des postes.
				n = maxi(ceili(int(e.prevus) * Effectif.SOUS_EFFECTIF) - int(e.embauches), 1)
				if pourquoi == "":
					pourquoi = "manque de personnel"
			elif bool(e.ferme):
				n = 1
			elif not bool(e.ferme) and bool(e.manque) and e.has("besoin"):
				# Commerce ouvert mais débordé : de quoi servir sa clientèle sans queue.
				n = ceili(int(e.besoin) * Effectif.SOUS_EFFECTIF) - int(e.embauches)
				pourquoi = "longues files : %d clients" % int(e.get("clients", 0))
			if n <= 0:
				continue
			var avant := libres
			var k := affecter(bid, n if vital else mini(n, libres), met)
			if k > 0:
				faits += k
				var verbe := ("sans chantier vont" if k > 1 else "sans chantier va")
				if vital and avant < k:
					verbe = "quittent le chantier pour" if k > 1 else "quitte le chantier pour"
				message.emit("%d fondateur%s %s tenir %s (%s)." % [k, "s" if k > 1 else "", verbe,
					population.building_name(bid), pourquoi])
	faits += _livreurs()
	return faits


## Rayons vides et aucun chauffeur-livreur en ville : deux fondateurs sans
## chantier prennent le volant des camions d'un entrepôt (le dépôt de
## marchandises ne sert à rien sans eux).
func _livreurs() -> int:
	var pr := Production.instance
	if libres <= 0 or pr == null or pr.manque_foyers.is_empty() or not pr.drivers().is_empty():
		return 0
	for bid in population.known.keys():
		if bid == camp or population.free_jobs(bid) <= 0:
			continue
		if BuildingCatalog.base_of(String(population.known[bid].t)) != "entrepot":
			continue
		if population.effectif != null and population.effectif.en_greve(bid):
			continue
		var k := affecter(bid, mini(2, libres), "chauffeur")
		if k > 0:
			message.emit("%d fondateur%s sans chantier %s les camions de %s (rayons vides)." % [k, "s" if k > 1 else "", "conduisent" if k > 1 else "conduit",
				population.building_name(bid)])
			return k
	return 0


# --- Sauvegarde ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "arrives": arrives, "camp": camp, "membres": membres.duplicate(), "foyers_depart": foyers_depart,
		"vivres": snappedf(vivres, 0.01), "ravitaillement": ravitaillement, "affame": affame, "alerte": _alerte_vivres,
		"pauses": pauses.keys(), "ordres": ordres.duplicate(), "jour": _jour, "renfort": renfort_en_attente, "renfort_total": renfort_total,
		"pionniers": _pionniers_dict()}


func _pionniers_dict() -> Dictionary:
	var out := {}
	for vid in pionniers:
		out[str(vid)] = {"n": int(pionniers[vid].n), "fin": float(pionniers[vid].fin)}
	return out


func from_dict(d: Dictionary) -> void:
	clear()
	arrives = bool(d.get("arrives", false))
	camp = int(d.get("camp", -1))
	if buildings != null and not buildings.buildings.has(camp):
		camp = -1
	for pid in d.get("membres", []):
		membres.append(int(pid))
	foyers_depart = int(d.get("foyers_depart", 0))
	vivres = float(d.get("vivres", 0.0))
	ravitaillement = int(d.get("ravitaillement", 0))
	affame = bool(d.get("affame", false))
	_alerte_vivres = bool(d.get("alerte", false))
	for k in d.get("pauses", []):
		pauses[String(k)] = true
	var o: Dictionary = d.get("ordres", {})
	for k in o:
		ordres[String(k)] = float(o[k])
	_jour = int(d.get("jour", -1))
	renfort_en_attente = int(d.get("renfort", 0))
	renfort_total = int(d.get("renfort_total", 0))
	var pi: Dictionary = d.get("pionniers", {})
	for k in pi:
		pionniers[int(k)] = {"n": int(pi[k].get("n", 0)), "fin": float(pi[k].get("fin", 0.0))}
	repartir()
	changed.emit()
