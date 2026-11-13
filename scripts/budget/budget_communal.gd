class_name BudgetCommunal
extends Node
## Budget de la commune : impôts votés par le maire, emprunts, entretien et usure
## des routes, rails, chemins, voies d'eau et des autres réseaux (eau, électricité,
## fibre…), mise sous tutelle si la caisse reste dans le rouge.
##
## En solo, la caisse de la commune est celle du joueur (BuildingSystem.money).
##
## Brancher un autre système, sans dépendance d'ordre de fusion :
## - coûts mensuels : nœud dans le groupe "budget_entretien" avec
##   func budget_entretien() -> Dictionary  ({"Libellé": euros_par_mois})
## - recettes mensuelles : groupe "budget_recettes" avec
##   func budget_recettes() -> Dictionary
##   Les deux sont versés chaque jour (1/30e) et affichés dans le panneau Budget (M).
## - flux ponctuels : recette(poste, montant) / depense(poste, montant).
## - usure d'un réseau à soi : register(reseau, id, longueur_m), etat(), user(), reparer().
## Le nœud est dans le groupe "budget_communal" et dans BudgetCommunal.instance.

signal changed
signal message(text: String)

static var instance: BudgetCommunal

const DAYS_PER_MONTH := 30.44
const DAYS_PER_YEAR := 365.0

## Taux votés par le maire (1,0 = normal), de TAUX_MIN à TAUX_MAX.
const TAUX_MIN := 0.0
const TAUX_MAX := 2.0
const TAUX_NOMS := {"foncier": "Taxe foncière", "entreprises": "Impôt des entreprises (CFE)",
	"benefices": "Impôt sur les bénéfices"}
## Poids de chaque taux dans la pression fiscale ressentie par les habitants.
const TAUX_POIDS := {"foncier": 0.5, "entreprises": 0.25, "benefices": 0.25}

# --- Emprunts ---------------------------------------------------------------------------
const MONTANTS := [100_000, 500_000, 1_000_000, 5_000_000, 10_000_000, 20_000_000]
const DUREES := [5, 10, 20, 30]
const TAUX_BASE := 0.02
const TAUX_RISQUE := 0.05
## Plafond de dette : ce nombre d'années de recettes (au moins PLAFOND_MIN).
const PLAFOND_ANNEES := 8.0
const PLAFOND_MIN := 2_000_000.0
## Pénalité de remboursement anticipé (part du capital restant).
const PENALITE := 0.01

# --- Tutelle ----------------------------------------------------------------------------
const JOURS_ROUGE_TUTELLE := 90
const JOURS_VERT_SORTIE := 30
## Taux minimum imposés par le préfet pendant la tutelle.
const TAUX_TUTELLE := 1.5

# --- Usure et entretien des voies ------------------------------------------------------
## Réseaux de transport gérés ici (clé -> mode de TransportTypes).
const VOIES := {"route": TransportTypes.Mode.ROAD, "rail": TransportTypes.Mode.RAIL,
	"chemin": TransportTypes.Mode.PATH, "eau": TransportTypes.Mode.WATER}
const VOIE_NOMS := {"route": "Routes", "rail": "Voies ferrées", "chemin": "Chemins et pistes", "eau": "Voies d'eau"}
## Durée de vie sans entretien ni trafic (jours de jeu).
const DUREE_VIE := {"route": 1100.0, "rail": 1800.0, "chemin": 1500.0, "eau": 3000.0}
## Budget d'entretien conseillé, € par km et par mois pour une voie de largeur LARGEUR_REF.
const COUT_KM := {"route": 700.0, "rail": 2200.0, "chemin": 120.0, "eau": 250.0}
const LARGEUR_REF := {"route": 7.0, "rail": 4.0, "chemin": 3.0, "eau": 10.0}
## Réfection complète, € par m² de voie.
const PRIX_M2 := {"route": 35.0, "rail": 120.0, "chemin": 15.0, "eau": 20.0}
## Usure par passage : unités de « poids » de véhicule présentes sur 100 m pendant 1 heure.
const USURE_PASSAGE := 1.0 / (365.0 * 24.0 * 8.0)
## Sous ce seuil : nids-de-poule et véhicules ralentis.
const SEUIL_ABIME := 0.5
## Vitesse minimale (part de la vitesse normale) sur une voie très abîmée.
const VITESSE_MIN := 0.6
## Réparations automatiques par réseau et par jour (au plus).
const REPARATIONS_JOUR := 3
## Heures de chantier pour réparer 100 m de voie.
const HEURES_100M := 6.0

## Coûts d'entretien des autres réseaux (eau, électricité…), € par km et par mois.
const COUT_KM_EXT := 900.0
const DUREE_VIE_EXT := 2500.0

var buildings: BuildingSystem
var transport: TransportSystem
var population: Population
var production: Node

## Taux votés : {"foncier", "entreprises", "benefices"}.
var taux := {"foncier": 1.0, "entreprises": 1.0, "benefices": 1.0}
## Emprunts en cours : {id, capital, restant, taux, annees, mensualite, jour, nom}.
var emprunts: Array = []
var _next_loan := 1
## Entretien de chaque réseau : clé -> {"taux": 0..2 (1 = conseillé), "auto": bool, "seuil": 0..1}.
var entretien := {}
## Autres réseaux enregistrés : reseau -> {id -> {"l": m, "u": état 0..1}}.
var reseaux_ext := {}
var tutelle := false
var jours_rouge := 0
var jours_vert := 0
## Comptes du mois en cours et des mois passés : poste -> euros (+ recette, − dépense).
var mois := {}
var historique: Array = []
var jours_mois := 0
var jour_total := 0
var _money_frac := 0.0
var _hour_acc := 0.0
var _last_unix := -1.0
## Dernier bilan quotidien (par mois), pour le panneau.
var dernier := {}
var vue: UsureVue


func _init() -> void:
	_reset_entretien()


func _reset_entretien() -> void:
	for k in VOIES:
		entretien[k] = {"taux": 1.0, "auto": true, "seuil": 0.35}


func _enter_tree() -> void:
	instance = self
	add_to_group("budget_communal")
	add_to_group("avis_sources")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(bs: BuildingSystem, ts: TransportSystem, pop: Population, prod: Node = null) -> void:
	buildings = bs
	transport = ts
	population = pop
	production = prod
	if population != null:
		population.city_pay = pay_day
	_hook_traffic()
	vue = UsureVue.new()
	vue.name = "UsureVue"
	add_child(vue)
	vue.setup(self)


func clear() -> void:
	taux = {"foncier": 1.0, "entreprises": 1.0, "benefices": 1.0}
	emprunts.clear()
	reseaux_ext.clear()
	tutelle = false
	jours_rouge = 0
	jours_vert = 0
	mois = {}
	historique.clear()
	jours_mois = 0
	jour_total = 0
	_money_frac = 0.0
	dernier = {}
	_reset_entretien()
	changed.emit()


## Le trafic multiplie la vitesse par speed_factors (si la version du trafic le permet).
func _hook_traffic() -> void:
	if transport == null or transport.traffic == null:
		return
	var tf = transport.traffic
	if "speed_factors" in tf:
		tf.speed_factors.append(func(eid: int, _v: Dictionary) -> float: return vitesse_facteur(eid))


# --- Taux et pression fiscale ------------------------------------------------------------

## Taux appliqué (tutelle comprise).
func taux_effectif(k: String) -> float:
	var t := float(taux.get(k, 1.0))
	return maxf(t, TAUX_TUTELLE) if tutelle else t


## Multiplicateur d'un impôt pour les autres scripts (1,0 sans budget).
static func facteur(k: String) -> float:
	return instance.taux_effectif(k) if instance != null else 1.0


## Pression fiscale ressentie : 0 = aucun impôt, 1 = normal, 2 = double.
func pression_fiscale() -> float:
	var p := 0.0
	for k in TAUX_POIDS:
		p += taux_effectif(k) * float(TAUX_POIDS[k])
	return p * ReglagesPartie.actuel.impots


func set_taux(k: String, v: float) -> void:
	if not taux.has(k):
		return
	taux[k] = clampf(snappedf(v, 0.05), TAUX_MIN, TAUX_MAX)
	changed.emit()


# --- Recettes et dépenses ---------------------------------------------------------------

func _book(poste: String, v: float) -> void:
	mois[poste] = float(mois.get(poste, 0.0)) + v


## Inscrit une somme déjà versée ailleurs (sans toucher à la caisse).
static func noter(poste: String, v: float) -> void:
	if instance != null:
		instance._book(poste, v)


func _pay(v: float) -> void:
	if buildings == null or buildings.unlimited_money:
		return
	_money_frac += v
	var whole := floori(_money_frac)
	_money_frac -= whole
	buildings.money += whole


## Recette ponctuelle (billets, amendes, ventes…) : créditée et inscrite au mois.
func recette(poste: String, montant: float) -> void:
	_book(poste, montant)
	_pay(montant)


## Dépense ponctuelle : débitée et inscrite au mois.
func depense(poste: String, montant: float) -> void:
	_book(poste, -montant)
	_pay(-montant)


func caisse() -> int:
	return buildings.money if buildings != null else 0


## Comptes du mois, estimés sur l'état actuel : {recettes, depenses, total_recettes, total_depenses, solde}.
func bilan_mensuel() -> Dictionary:
	var rec := {}
	var dep := {}
	if population != null:
		var b := population.city_budget()
		for k in b.recettes:
			var v := float(b.recettes[k])
			if k == "Taxe foncière":
				v *= taux_effectif("foncier")
			elif k == "Impôts des entreprises":
				v *= taux_effectif("entreprises")
			rec[k] = float(rec.get(k, 0.0)) + v
		for k in b.depenses:
			dep[k] = float(dep.get(k, 0.0)) + float(b.depenses[k])
	for n in get_tree().get_nodes_in_group("budget_recettes") if is_inside_tree() else []:
		if n != self and n.has_method("budget_recettes"):
			var d: Dictionary = n.budget_recettes()
			for k in d:
				rec[k] = float(rec.get(k, 0.0)) + float(d[k])
	for n in get_tree().get_nodes_in_group("budget_entretien") if is_inside_tree() else []:
		if n != self and n.has_method("budget_entretien"):
			var d: Dictionary = n.budget_entretien()
			for k in d:
				dep[k] = float(dep.get(k, 0.0)) + float(d[k])
	for k in VOIES:
		var c := cout_entretien(k)
		if c > 0.0:
			dep["Entretien : " + String(VOIE_NOMS[k]).to_lower()] = c
	for r in reseaux_ext:
		var c := cout_entretien_ext(r)
		if c > 0.0:
			dep["Entretien : réseau " + r] = c
	var m := mensualites()
	if m > 0.0:
		dep["Remboursement des emprunts"] = m
	var tr := 0.0
	var td := 0.0
	for k in rec:
		tr += rec[k]
	for k in dep:
		td += dep[k]
	return {"recettes": rec, "depenses": dep, "total_recettes": tr, "total_depenses": td, "solde": tr - td}


## Appelé par Population une fois par jour de jeu (à la place de son propre versement).
func pay_day(_b: Dictionary = {}, day: float = 1.0 / DAYS_PER_MONTH) -> void:
	var b := bilan_mensuel()
	dernier = b
	for k in b.recettes:
		_book(k, float(b.recettes[k]) * day)
	for k in b.depenses:
		if k == "Remboursement des emprunts":
			continue
		_book(k, -float(b.depenses[k]) * day)
	var flux := float(b.total_recettes) - float(b.total_depenses) + mensualites()
	_pay(flux * day)
	_pay_loans(day * DAYS_PER_MONTH)
	_wear_day()
	_auto_repairs()
	_check_tutelle()
	if vue != null:
		vue.rebuild()
	jour_total += 1
	jours_mois += 1
	if jours_mois >= 30:
		historique.append(mois)
		while historique.size() > 24:
			historique.pop_front()
		mois = {}
		jours_mois = 0
	changed.emit()


func _process(delta: float) -> void:
	if population == null or population.ambiance == null:
		return
	var t: float = population.ambiance.unix_time
	if _last_unix < 0.0:
		_last_unix = t
		return
	var dt := clampf(t - _last_unix, 0.0, 86400.0)
	_last_unix = t
	_hour_acc += dt
	if _hour_acc >= 3600.0:
		var h := minf(_hour_acc / 3600.0, 24.0)
		_hour_acc = 0.0
		sample_traffic(h)


# --- Emprunts ---------------------------------------------------------------------------

## Dette totale (capital restant dû).
func dette() -> float:
	var d := 0.0
	for e in emprunts:
		d += float(e.restant)
	return d


func mensualites() -> float:
	var m := 0.0
	for e in emprunts:
		m += float(e.mensualite)
	return m


## Recettes annuelles estimées (base du plafond de dette).
func recettes_annuelles() -> float:
	var b: Dictionary = dernier if not dernier.is_empty() else bilan_mensuel()
	return float(b.total_recettes) * 12.0


func plafond_dette() -> float:
	return maxf(PLAFOND_MIN, recettes_annuelles() * PLAFOND_ANNEES)


## Taux proposé par la banque pour un nouvel emprunt.
func taux_propose(montant: float, annees: int) -> float:
	var ratio := clampf((dette() + montant) / plafond_dette(), 0.0, 1.0)
	var t := TAUX_BASE + TAUX_RISQUE * ratio
	if caisse() < 0:
		t += 0.01
	t += 0.005 * (DUREES.find(annees) if DUREES.has(annees) else 0)
	return snappedf(t, 0.0005)


static func mensualite_de(capital: float, t: float, annees: int) -> float:
	var n := annees * 12
	var r := t / 12.0
	if r <= 0.0:
		return capital / n
	return capital * r / (1.0 - pow(1.0 + r, -n))


## Raison du refus d'un emprunt ("" : accepté).
func refus_emprunt(montant: float, _annees: int) -> String:
	if tutelle:
		return "Ville sous tutelle du préfet : aucun nouvel emprunt."
	if dette() + montant > plafond_dette():
		return "Plafond de dette atteint (%s, soit %d ans de recettes)." % [
			BuildingSystem.format_short(int(plafond_dette())), int(PLAFOND_ANNEES)]
	return ""


func emprunter(montant: float, annees: int) -> Dictionary:
	var why := refus_emprunt(montant, annees)
	if why != "":
		message.emit(why)
		return {}
	var t := taux_propose(montant, annees)
	var e := {"id": _next_loan, "capital": montant, "restant": montant, "taux": t, "annees": annees,
		"mensualite": mensualite_de(montant, t, annees), "jour": jour_total,
		"nom": "Prêt n° %d" % _next_loan}
	_next_loan += 1
	emprunts.append(e)
	_book("Emprunts reçus", montant)
	_pay(montant)
	message.emit("%s : %s sur %d ans à %s %% (%s par mois)." % [e.nom, BuildingSystem.format_money(int(montant)),
		annees, _pct(t), BuildingSystem.format_money(int(e.mensualite))])
	changed.emit()
	return e


## Remboursement anticipé : capital restant + pénalité.
func rembourser(id: int) -> bool:
	for e in emprunts:
		if int(e.id) == id:
			var due := float(e.restant) * (1.0 + PENALITE)
			if buildings != null and not buildings.unlimited_money and buildings.money < due:
				message.emit("Pas assez d'argent pour rembourser (%s)." % BuildingSystem.format_money(int(due)))
				return false
			_book("Remboursement anticipé", -due)
			_pay(-due)
			emprunts.erase(e)
			message.emit("%s remboursé." % String(e.nom))
			changed.emit()
			return true
	return false


## Paie `days` jours de mensualités (intérêts d'abord, puis capital).
func _pay_loans(days: float) -> void:
	var done := []
	for e in emprunts:
		var pay := float(e.mensualite) * days / DAYS_PER_MONTH
		var interest := float(e.restant) * float(e.taux) * days / DAYS_PER_YEAR
		var principal := minf(maxf(0.0, pay - interest), float(e.restant))
		e.restant = float(e.restant) - principal
		_book("Intérêts des emprunts", -interest)
		_book("Capital remboursé", -principal)
		_pay(-(interest + principal))
		if float(e.restant) <= 1.0:
			done.append(e)
	for e in done:
		emprunts.erase(e)
		message.emit("%s entièrement remboursé." % String(e.nom))


# --- Tutelle ------------------------------------------------------------------------------

func _check_tutelle() -> void:
	if buildings == null or buildings.unlimited_money:
		jours_rouge = 0
		if tutelle:
			_set_tutelle(false)
		return
	if buildings.money < 0:
		jours_rouge += 1
		jours_vert = 0
	else:
		jours_vert += 1
		jours_rouge = 0
	if not tutelle and jours_rouge >= JOURS_ROUGE_TUTELLE:
		_set_tutelle(true)
	elif tutelle and jours_vert >= JOURS_VERT_SORTIE:
		_set_tutelle(false)


func _set_tutelle(on: bool) -> void:
	tutelle = on
	if on:
		message.emit("Caisse dans le rouge depuis %d jours : le préfet met la ville sous tutelle. Impôts relevés à %d %%, plus d'emprunts ni de bâtiments publics." % [
			JOURS_ROUGE_TUTELLE, roundi(TAUX_TUTELLE * 100.0)])
	else:
		message.emit("Les comptes sont rétablis : la ville sort de la tutelle du préfet.")
	changed.emit()


## Refus de pose pendant la tutelle (appelé par ReglagesPartie.raison_blocage).
static func raison_blocage(id: String) -> String:
	if instance == null or not instance.tutelle:
		return ""
	if String(BuildingCatalog.get_type(id).get("cat", "")) == "services":
		return "Ville sous tutelle du préfet : pas de nouveau bâtiment public."
	return ""


# --- Usure des voies ----------------------------------------------------------------------

func network() -> TransportNetwork:
	return transport.network if transport != null else null


static func voie_of(type_id: String) -> String:
	var m := TransportTypes.mode_of(type_id)
	for k in VOIES:
		if int(VOIES[k]) == m:
			return k
	return ""


## État d'un tronçon : 1 = neuf, 0 = hors d'usage.
func etat(eid: int) -> float:
	var net := network()
	if net == null or not net.edges.has(eid):
		return 1.0
	return float(net.edges[eid].get("u", 1.0))


func set_etat(eid: int, v: float) -> void:
	var net := network()
	if net == null or not net.edges.has(eid):
		return
	var e: Dictionary = net.edges[eid]
	var before := float(e.get("u", 1.0))
	v = clampf(v, 0.0, 1.0)
	if v >= 1.0:
		e.erase("u")
	else:
		e["u"] = v
	if v <= 0.0 and before > 0.0:
		net.closed_edges[eid] = "usure"
		message.emit("%s hors d'usage : la voie est fermée en attendant les travaux." % _edge_name(eid))
	elif v > 0.0 and String(net.closed_edges.get(eid, "")) == "usure":
		net.closed_edges.erase(eid)


## Multiplicateur de vitesse sur un tronçon abîmé (1 en bon état, VITESSE_MIN à 0 %).
func vitesse_facteur(eid: int) -> float:
	var u := etat(eid)
	if u >= SEUIL_ABIME:
		return 1.0
	return lerpf(VITESSE_MIN, 1.0, u / SEUIL_ABIME)


func _edge_name(eid: int) -> String:
	var net := network()
	var t := String(net.edges[eid].t)
	return String(TransportTypes.get_type(t).get("name", "Voie"))


## Usure due à l'âge, chaque jour, freinée par l'entretien courant.
func _wear_day() -> void:
	var net := network()
	var speed := ReglagesPartie.actuel.usure
	if net == null or speed <= 0.0:
		return
	for eid in net.edges.keys():
		var k := voie_of(String(net.edges[eid].t))
		if k == "":
			continue
		var r := float(entretien[k].taux)
		var aging := speed / float(DUREE_VIE[k]) * (1.0 - 0.8 * minf(r, 1.0))
		var gain := 0.0015 * maxf(0.0, r - 1.0)
		var u := etat(eid)
		if u > 0.0:
			set_etat(eid, u - aging + gain)
	for res in reseaux_ext:
		for id in reseaux_ext[res]:
			var it: Dictionary = reseaux_ext[res][id]
			it.u = clampf(float(it.u) - speed / DUREE_VIE_EXT * 0.2, 0.0, 1.0)


## Usure due au passage des véhicules présents sur les voies pendant `hours` heures.
func sample_traffic(hours: float) -> void:
	var net := network()
	var speed := ReglagesPartie.actuel.usure
	if net == null or speed <= 0.0 or transport.traffic == null:
		return
	var charge := {}
	for v in transport.traffic.vehicles:
		if v.get("parked", false) or v.has("sidewalk"):
			continue
		var route: Array = v.get("route", [])
		var leg := int(v.get("leg", 0))
		if leg < 0 or leg >= route.size():
			continue
		var eid := int(route[leg])
		charge[eid] = float(charge.get(eid, 0.0)) + poids(String(v.get("model", "")), int(v.get("mode", 0)))
	for eid in charge:
		if not net.edges.has(eid):
			continue
		var k := voie_of(String(net.edges[eid].t))
		if k == "":
			continue
		var r := float(entretien[k].taux)
		var per100 := float(charge[eid]) * 100.0 / maxf(20.0, float(net.edges[eid].len))
		var w := per100 * hours * USURE_PASSAGE * speed * (1.0 - 0.8 * minf(r, 1.0))
		var u := etat(eid)
		if u > 0.0:
			set_etat(eid, u - w)


## Poids d'un véhicule pour l'usure (voiture = 1, camion ≈ 10).
static func poids(model: String, mode: int) -> float:
	if mode == TransportTypes.Mode.RAIL:
		return 3.0
	if mode == TransportTypes.Mode.WATER:
		return 0.5
	var cat := String(VehicleCatalog.get_type(model).get("cat", "voiture")) if model != "" else "voiture"
	match cat:
		"utilitaire": return 10.0 if VehicleCatalog.get_type(model).get("livraison", false) else 4.0
		"bus", "tram": return 8.0
		"deux_roues": return 0.3
		"attelage": return 6.0
	return 1.0


## Coût mensuel de l'entretien courant d'un réseau, au taux choisi.
func cout_entretien(k: String) -> float:
	return cout_conseille(k) * float(entretien[k].taux)


func cout_conseille(k: String) -> float:
	var net := network()
	if net == null:
		return 0.0
	var c := 0.0
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		if voie_of(String(e.t)) != k:
			continue
		c += float(e.len) / 1000.0 * float(COUT_KM[k]) * maxf(0.3, float(e.width) / float(LARGEUR_REF[k]))
	return float(ReglagesPartie.prix(roundi(c)))


## Prix de la réfection d'un tronçon (proportionnel à l'usure).
func prix_reparation(eid: int) -> int:
	var net := network()
	if net == null or not net.edges.has(eid):
		return 0
	var e: Dictionary = net.edges[eid]
	var k := voie_of(String(e.t))
	if k == "":
		return 0
	var m2 := float(e.len) * float(e.width)
	return ReglagesPartie.prix(roundi(m2 * float(PRIX_M2[k]) * (1.0 - etat(eid))))


## Répare un tronçon (chantier visible si le système de chantiers est là).
func reparer(eid: int, auto := false) -> bool:
	var net := network()
	if net == null or not net.edges.has(eid) or etat(eid) >= 0.999:
		return false
	var cost := prix_reparation(eid)
	if buildings != null and not buildings.unlimited_money and buildings.money < cost:
		if not auto:
			message.emit("Pas assez d'argent pour réparer (%s)." % BuildingSystem.format_money(cost))
		return false
	var hours := maxf(2.0, float(net.edges[eid].len) / 100.0 * HEURES_100M * (1.0 - etat(eid)))
	var cv = _chantiers_voies()
	if cv != null:
		# Le chantier paie au fil des travaux ; on inscrit la dépense au budget.
		_book("Réparations des voies", -cost)
		cv.chantier_reparation(eid, hours, cost, func() -> void: set_etat(eid, 1.0); vue.rebuild())
	else:
		depense("Réparations des voies", cost)
		set_etat(eid, 1.0)
	if not auto:
		message.emit("%s : réparation lancée (%s)." % [_edge_name(eid), BuildingSystem.format_money(cost)])
	if vue != null:
		vue.rebuild()
	changed.emit()
	return true


## Système de chantiers des voies, s'il existe dans cette version du jeu.
func _chantiers_voies():
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "ChantiersVoies":
			var s = load(String(c.path))
			var inst = s.get("instance") if s != null else null
			if inst != null and is_instance_valid(inst) and inst.has_method("chantier_reparation"):
				return inst
	return null


func _auto_repairs() -> void:
	var net := network()
	if net == null:
		return
	for k in VOIES:
		var cfg: Dictionary = entretien[k]
		if not bool(cfg.auto):
			continue
		var worst := pires(k, float(cfg.seuil), REPARATIONS_JOUR)
		for eid in worst:
			reparer(eid, true)


## Tronçons d'un réseau sous un seuil d'état, du pire au moins pire.
func pires(k: String, seuil := 1.0, n := 10) -> Array:
	var net := network()
	var out := []
	if net == null:
		return out
	for eid in net.edges:
		if (k == "" or voie_of(String(net.edges[eid].t)) == k) and etat(eid) < seuil:
			out.append(eid)
	out.sort_custom(func(a: int, b: int) -> bool: return etat(a) < etat(b))
	return out.slice(0, n)


## État moyen d'un réseau, pondéré par la longueur (1 si vide).
func etat_moyen(k: String) -> float:
	var net := network()
	if net == null:
		return 1.0
	var s := 0.0
	var l := 0.0
	for eid in net.edges:
		if voie_of(String(net.edges[eid].t)) == k:
			var el := float(net.edges[eid].len)
			s += etat(eid) * el
			l += el
	return 1.0 if l <= 0.0 else s / l


func etat_moyen_routes() -> float:
	return etat_moyen("route")


func longueur(k: String) -> float:
	var net := network()
	var l := 0.0
	if net != null:
		for eid in net.edges:
			if voie_of(String(net.edges[eid].t)) == k:
				l += float(net.edges[eid].len)
	return l


func set_entretien(k: String, champ: String, v) -> void:
	if not entretien.has(k):
		return
	match champ:
		"taux": entretien[k].taux = clampf(snappedf(float(v), 0.05), 0.0, 2.0)
		"auto": entretien[k].auto = bool(v)
		"seuil": entretien[k].seuil = clampf(float(v), 0.0, 0.9)
	changed.emit()


# --- Autres réseaux (eau, électricité, fibre…) -------------------------------------------

func register(reseau: String, id: String, longueur_m: float) -> void:
	if not reseaux_ext.has(reseau):
		reseaux_ext[reseau] = {}
	var old: Dictionary = reseaux_ext[reseau].get(id, {})
	reseaux_ext[reseau][id] = {"l": longueur_m, "u": float(old.get("u", 1.0))}


func unregister(reseau: String, id: String) -> void:
	if reseaux_ext.has(reseau):
		reseaux_ext[reseau].erase(id)


func etat_ext(reseau: String, id: String) -> float:
	return float(reseaux_ext.get(reseau, {}).get(id, {}).get("u", 1.0))


func user(reseau: String, id: String, quantite: float) -> void:
	if reseaux_ext.has(reseau) and reseaux_ext[reseau].has(id):
		var it: Dictionary = reseaux_ext[reseau][id]
		it.u = clampf(float(it.u) - quantite * ReglagesPartie.actuel.usure, 0.0, 1.0)


func reparer_ext(reseau: String, id: String) -> void:
	if reseaux_ext.has(reseau) and reseaux_ext[reseau].has(id):
		var it: Dictionary = reseaux_ext[reseau][id]
		var cost := ReglagesPartie.prix(roundi(float(it.l) * 60.0 * (1.0 - float(it.u))))
		depense("Réparations : réseau " + reseau, cost)
		it.u = 1.0


func cout_entretien_ext(reseau: String) -> float:
	var l := 0.0
	for id in reseaux_ext.get(reseau, {}):
		l += float(reseaux_ext[reseau][id].l)
	return float(ReglagesPartie.prix(roundi(l / 1000.0 * COUT_KM_EXT)))


# --- Avis des habitants --------------------------------------------------------------------

## Facteurs lus par le système d'avis (groupe "avis_sources").
func avis_facteurs() -> Array:
	return [
		{"id": "budget_impots", "theme": "impots", "ville": true, "f": _avis_impots},
		{"id": "budget_routes", "theme": "transports", "ville": true, "f": _avis_routes},
	]


func _avis_impots() -> Array:
	var p := pression_fiscale()
	var raisons: Array = []
	var d := 0.0
	if p > 1.05:
		d = -minf(15.0, (p - 1.0) * 12.0)
		raisons.append("− impôts élevés (%d %%)" % roundi(p * 100.0))
	elif p < 0.95:
		d = minf(6.0, (1.0 - p) * 8.0)
		raisons.append("+ impôts bas (%d %%)" % roundi(p * 100.0))
	if tutelle:
		d -= 4.0
		raisons.append("− ville sous tutelle du préfet")
	return [d, raisons]


func _avis_routes() -> Array:
	var u := etat_moyen("route")
	if u >= 0.7:
		return [0.0, []]
	return [-minf(10.0, (0.7 - u) / 0.7 * 12.0), ["− routes abîmées (état %d %%)" % roundi(u * 100.0)]]


# --- Sauvegarde ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "taux": taux.duplicate(), "emprunts": emprunts.duplicate(true), "next_loan": _next_loan,
		"entretien": entretien.duplicate(true), "reseaux": reseaux_ext.duplicate(true), "tutelle": tutelle,
		"jours_rouge": jours_rouge, "jours_vert": jours_vert, "mois": mois.duplicate(), "historique": historique.duplicate(true),
		"jours_mois": jours_mois, "jour_total": jour_total}


func from_dict(d: Dictionary) -> void:
	clear()
	var t: Dictionary = d.get("taux", {})
	for k in taux:
		taux[k] = clampf(float(t.get(k, 1.0)), TAUX_MIN, TAUX_MAX)
	for e in d.get("emprunts", []):
		if e is Dictionary and e.has("restant"):
			emprunts.append({"id": int(e.get("id", 0)), "capital": float(e.get("capital", e.restant)), "restant": float(e.restant),
				"taux": float(e.get("taux", TAUX_BASE)), "annees": int(e.get("annees", 10)), "mensualite": float(e.get("mensualite", 0.0)),
				"jour": int(e.get("jour", 0)), "nom": String(e.get("nom", "Prêt"))})
	_next_loan = int(d.get("next_loan", emprunts.size() + 1))
	var en: Dictionary = d.get("entretien", {})
	for k in entretien:
		if en.get(k) is Dictionary:
			var c: Dictionary = en[k]
			entretien[k] = {"taux": clampf(float(c.get("taux", 1.0)), 0.0, 2.0), "auto": bool(c.get("auto", true)),
				"seuil": clampf(float(c.get("seuil", 0.35)), 0.0, 0.9)}
	var rx: Dictionary = d.get("reseaux", {})
	for r in rx:
		reseaux_ext[String(r)] = {}
		for id in rx[r]:
			var it: Dictionary = rx[r][id]
			reseaux_ext[String(r)][String(id)] = {"l": float(it.get("l", 0.0)), "u": clampf(float(it.get("u", 1.0)), 0.0, 1.0)}
	tutelle = bool(d.get("tutelle", false))
	jours_rouge = int(d.get("jours_rouge", 0))
	jours_vert = int(d.get("jours_vert", 0))
	mois = d.get("mois", {})
	historique = d.get("historique", [])
	jours_mois = int(d.get("jours_mois", 0))
	jour_total = int(d.get("jour_total", 0))
	# Voies hors d'usage : fermées comme avant la sauvegarde.
	var net := network()
	if net != null:
		for eid in net.edges:
			if etat(eid) <= 0.0:
				net.closed_edges[eid] = "usure"
	if vue != null:
		vue.rebuild()
	changed.emit()


static func _pct(t: float) -> String:
	return ("%.2f" % (t * 100.0)).replace(".", ",")
