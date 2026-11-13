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
##
## Plusieurs villes (Pays) : chaque ville a son état (taux, emprunts, entretien,
## tutelle, comptes du mois). L'état chargé est celui de `cle` (la ville choisie) ;
## les autres attendent dans `etats`. Chaque jour, pay_day passe par toutes les
## villes puis par le pays (clé 0), chacun avec sa caisse.

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
const PLAFOND_MIN := 10_000_000.0
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
## Commune dont l'état est chargé (0 : le pays, ou partie sans villages).
var cle := 0
## États rangés des autres communes : clé -> état (voir _pack()).
var etats := {}
## Caisse propriétaire de chaque voie (recalculé chaque jour) : eid -> clé.
var _proprio_voies := {}


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
	cle = 0
	etats.clear()
	_proprio_voies.clear()
	changed.emit()


# --- Plusieurs villes (Pays) ---------------------------------------------------------------

## Plusieurs caisses (le pays a au moins une ville) ?
static func multi() -> bool:
	return Pays.instance != null and Pays.instance.a_des_villes()


func _pack() -> Dictionary:
	return {"taux": taux, "emprunts": emprunts, "entretien": entretien, "tutelle": tutelle, "jours_rouge": jours_rouge,
		"jours_vert": jours_vert, "mois": mois, "historique": historique, "jours_mois": jours_mois, "dernier": dernier,
		"frac": _money_frac}


func _unpack(d: Dictionary) -> void:
	taux = d.get("taux", {"foncier": 1.0, "entreprises": 1.0, "benefices": 1.0})
	emprunts = d.get("emprunts", [])
	if d.has("entretien"):
		entretien = d.entretien
	else:
		entretien = {}
		_reset_entretien()
	tutelle = bool(d.get("tutelle", false))
	jours_rouge = int(d.get("jours_rouge", 0))
	jours_vert = int(d.get("jours_vert", 0))
	mois = d.get("mois", {})
	historique = d.get("historique", [])
	jours_mois = int(d.get("jours_mois", 0))
	dernier = d.get("dernier", {})
	_money_frac = float(d.get("frac", 0.0))


## Charge l'état de la commune k (et range celui d'avant).
func selectionner(k: int, signaler := false) -> void:
	if k == cle:
		return
	etats[cle] = _pack()
	cle = k
	_unpack(etats.get(k, {}))
	etats.erase(k)
	if signaler:
		changed.emit()


## Donne l'état chargé de la commune de à la commune a (ancienne partie).
func transferer_etat(de: int, a: int) -> void:
	if cle != de or de == a:
		return
	etats[a] = _pack()
	_unpack({})


## Retour à une seule commune (nouvelle région).
func oublier_communes() -> void:
	etats.clear()
	cle = 0


## Village partie absorbé par garde : ses emprunts passent à garde.
func fusionner_etats(garde: int, partie: int) -> void:
	var sel := cle
	selectionner(partie)
	var reprise: Array = emprunts.duplicate(true)
	selectionner(garde)
	emprunts.append_array(reprise)
	etats.erase(partie)
	if sel != partie:
		selectionner(sel)
	changed.emit()


## Inscrit un mouvement au mois de la commune k, sans toucher aux caisses.
func noter_pour(k: int, poste: String, v: float) -> void:
	if k == cle or not multi():
		_book(poste, v)
		return
	var e: Dictionary = etats.get(k, {})
	if e.is_empty():
		e = {"mois": {}}
		etats[k] = e
	if not e.has("mois"):
		e["mois"] = {}
	e.mois[poste] = float(e.mois.get(poste, 0.0)) + v


## État rangé (ou chargé) d'une commune, en lecture : tutelle, emprunts…
func etat_de(k: int) -> Dictionary:
	return _pack() if k == cle else etats.get(k, {})


## Le joueur décide-t-il des réglages de cette commune (il en est le maire) ?
func joueur_decide(k := -1) -> bool:
	if k < 0:
		k = cle
	return Pays.instance == null or Pays.instance.joueur_maire(k)


func _filtre_ville(k: int) -> Callable:
	var cm := Communes.instance
	return func(bid: int) -> bool: return cm != null and int(cm.bat_village.get(bid, -1)) == k


## Caisse propriétaire d'une voie (-1 sans pays).
func proprio_voie(eid: int) -> int:
	if not multi():
		return -1
	if _proprio_voies.has(eid):
		return int(_proprio_voies[eid])
	var k := Pays.instance.payeur_de_voie(eid)
	_proprio_voies[eid] = k
	return k


func _maj_proprio_voies() -> void:
	_proprio_voies.clear()
	var net := network()
	if net == null or not multi():
		return
	for eid in net.edges:
		_proprio_voies[eid] = Pays.instance.payeur_de_voie(eid)


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
## k : commune (-2 : celle qui est chargée ; -1 : tout, sans pays ; 0 : le pays).
func bilan_mensuel(k := -2) -> Dictionary:
	if k == -2:
		k = cle if multi() else -1
	if k == Pays.PAYS and multi():
		return bilan_pays()
	var rec := {}
	var dep := {}
	var part := 1.0
	if k > 0 and multi():
		part = float(Pays.instance.parts_population().get(k, 0.0))
	if population != null:
		var b := population.city_budget(_filtre_ville(k) if k > 0 else Callable())
		for key in b.recettes:
			var v := float(b.recettes[key])
			var poste := String(key)
			if key == "Taxe foncière":
				v *= taux_effectif("foncier")
			elif key == "Impôts des entreprises":
				v *= taux_effectif("entreprises")
			elif key == "Dotation de l'État" and k > 0:
				poste = "Dotation du pays"
				v *= Pays.instance.facteur_dotation()
			rec[poste] = float(rec.get(poste, 0.0)) + v
		for key in b.depenses:
			dep[key] = float(dep.get(key, 0.0)) + float(b.depenses[key])
		if k > 0:
			var impots := float(rec.get("Taxe foncière", 0.0)) + float(rec.get("Impôts des entreprises", 0.0))
			var c := impots * Pays.instance.taux_national
			if c > 0.0:
				dep["Contribution au pays"] = c
	for n in get_tree().get_nodes_in_group("budget_recettes") if is_inside_tree() else []:
		if n != self and n.has_method("budget_recettes"):
			var d: Dictionary = n.budget_recettes()
			for key in d:
				rec[key] = float(rec.get(key, 0.0)) + float(d[key]) * part
	for n in get_tree().get_nodes_in_group("budget_entretien") if is_inside_tree() else []:
		if n != self and n.has_method("budget_entretien"):
			var d: Dictionary = n.budget_entretien()
			for key in d:
				dep[key] = float(dep.get(key, 0.0)) + float(d[key]) * part
	_ajouter_entretien(dep, k)
	return _totaux(rec, dep)


## Entretien des voies et des autres réseaux, et mensualités des emprunts chargés.
func _ajouter_entretien(dep: Dictionary, k: int) -> void:
	for v in VOIES:
		var c := cout_entretien(v, k if multi() else -1)
		if c > 0.0:
			dep["Entretien : " + String(VOIE_NOMS[v]).to_lower()] = c
	# Autres réseaux (eau, électricité…) : partagés selon la population.
	var part := 1.0
	if multi():
		part = 0.0 if k == Pays.PAYS else float(Pays.instance.parts_population().get(k, 0.0))
	for r in reseaux_ext:
		var c := cout_entretien_ext(r) * part
		if c > 0.0:
			dep["Entretien : réseau " + r] = c
	var m := mensualites()
	if m > 0.0:
		dep["Remboursement des emprunts"] = m


func _totaux(rec: Dictionary, dep: Dictionary) -> Dictionary:
	var tr := 0.0
	var td := 0.0
	for key in rec:
		tr += rec[key]
	for key in dep:
		td += dep[key]
	return {"recettes": rec, "depenses": dep, "total_recettes": tr, "total_depenses": td, "solde": tr - td}


## Contribution d'une ville au pays et dotation qu'elle reçoit, par mois.
func flux_ville(vid: int) -> Dictionary:
	if population == null or not multi():
		return {"contribution": 0.0, "dotation": 0.0}
	var e := etat_de(vid)
	var t: Dictionary = e.get("taux", {"foncier": 1.0, "entreprises": 1.0})
	var tut := bool(e.get("tutelle", false))
	var tf := float(t.get("foncier", 1.0))
	var te := float(t.get("entreprises", 1.0))
	if tut:
		tf = maxf(tf, TAUX_TUTELLE)
		te = maxf(te, TAUX_TUTELLE)
	var b := population.city_budget(_filtre_ville(vid))
	var impots := float(b.recettes.get("Taxe foncière", 0.0)) * tf + float(b.recettes.get("Impôts des entreprises", 0.0)) * te
	return {"contribution": impots * Pays.instance.taux_national,
		"dotation": float(b.recettes.get("Dotation de l'État", 0.0)) * Pays.instance.facteur_dotation()}


## Bilan mensuel du pays : impôt national, dotations, voies hors des villes, emprunts du pays.
func bilan_pays() -> Dictionary:
	var rec := {}
	var dep := {}
	var c := 0.0
	var d := 0.0
	for vid in Communes.instance.villages:
		var f := flux_ville(int(vid))
		c += float(f.contribution)
		d += float(f.dotation)
	if c > 0.0:
		rec["Impôt national"] = c
	if d > 0.0:
		dep["Dotations aux villes"] = d
	var sel := cle
	if sel != Pays.PAYS:
		# Emprunts du pays : on charge son état le temps du calcul.
		selectionner(Pays.PAYS)
		_ajouter_entretien(dep, Pays.PAYS)
		selectionner(sel)
	else:
		_ajouter_entretien(dep, Pays.PAYS)
	return _totaux(rec, dep)


## Appelé par Population une fois par jour de jeu (à la place de son propre versement).
func pay_day(_b: Dictionary = {}, day: float = 1.0 / DAYS_PER_MONTH) -> void:
	if multi():
		_maj_proprio_voies()
		var p := Pays.instance
		var sel := cle
		# Les villes d'abord, puis le pays (clé 0, en dernier dans cles()).
		for k in p.cles():
			selectionner(int(k))
			var prev := p.entrer(int(k))
			_jour(int(k), day)
			p.sortir(prev)
		selectionner(sel)
	else:
		_jour(-1, day)
	_wear_day()
	if vue != null:
		vue.rebuild()
	jour_total += 1
	changed.emit()


## Une journée de la commune chargée (k : sa clé, -1 sans pays).
func _jour(k: int, day: float) -> void:
	var b := bilan_mensuel(k)
	dernier = b
	for key in b.recettes:
		_book(key, float(b.recettes[key]) * day)
	for key in b.depenses:
		if key == "Remboursement des emprunts":
			continue
		_book(key, -float(b.depenses[key]) * day)
	var flux := float(b.total_recettes) - float(b.total_depenses) + mensualites()
	_pay(flux * day)
	_pay_loans(day * DAYS_PER_MONTH)
	_auto_repairs(k)
	# Le pays n'est pas mis sous tutelle : à sec, il ne verse plus de dotation.
	if k != Pays.PAYS or not multi():
		_check_tutelle()
	jours_mois += 1
	if jours_mois >= 30:
		historique.append(mois)
		while historique.size() > 24:
			historique.pop_front()
		mois = {}
		jours_mois = 0


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
	var qui := ("%s : " % Pays.instance.nom_de(cle)) if multi() else ""
	if on:
		message.emit(qui + "Caisse dans le rouge depuis %d jours : le préfet met la ville sous tutelle. Impôts relevés à %d %%, plus d'emprunts ni de bâtiments publics." % [
			JOURS_ROUGE_TUTELLE, roundi(TAUX_TUTELLE * 100.0)])
	else:
		message.emit(qui + "Les comptes sont rétablis : la ville sort de la tutelle du préfet.")
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
## proprio : seulement les voies de cette caisse (-1 : toutes).
func cout_entretien(k: String, proprio := -1) -> float:
	return cout_conseille(k, proprio) * float(entretien[k].taux)


func cout_conseille(k: String, proprio := -1) -> float:
	var net := network()
	if net == null:
		return 0.0
	if proprio == -2:
		proprio = cle if multi() else -1
	var c := 0.0
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		if voie_of(String(e.t)) != k:
			continue
		if proprio >= 0 and proprio_voie(eid) != proprio:
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
	# Réparation demandée à la main : c'est la caisse propriétaire de la voie qui paie.
	if not auto and multi():
		var o := proprio_voie(eid)
		if o != cle:
			if o != Pays.PAYS and not joueur_decide(o):
				message.emit("Cette voie est à %s, dont tu n'es plus le maire : son conseil décide des travaux." % Pays.instance.nom_de(o))
				return false
			var sel := cle
			selectionner(o)
			var prev := Pays.instance.entrer(o)
			var ok := reparer(eid, false)
			Pays.instance.sortir(prev)
			selectionner(sel)
			return ok
	var cost := prix_reparation(eid)
	if buildings != null and not buildings.unlimited_money and buildings.money < cost:
		if not auto:
			message.emit("Pas assez d'argent pour réparer (%s)." % BuildingSystem.format_money(cost))
		return false
	var hours := maxf(2.0, float(net.edges[eid].len) / 100.0 * HEURES_100M * (1.0 - etat(eid)))
	var cv := ChantiersVoies.instance
	if cv != null and is_instance_valid(cv) and cv.network == net:
		if cv.en_reparation(eid):
			return false
		# Chantier visible (voie fermée, engins) : il paie au fil des travaux.
		if not cv.chantier_reparation(eid, hours, cost, func() -> void:
				set_etat(eid, 1.0)
				if vue != null:
					vue.rebuild()):
			return false
		_book("Réparations des voies", -cost)
	else:
		depense("Réparations des voies", cost)
		set_etat(eid, 1.0)
	if not auto:
		message.emit("%s : réparation lancée (%s)." % [_edge_name(eid), BuildingSystem.format_money(cost)])
	if vue != null:
		vue.rebuild()
	changed.emit()
	return true


## Tronçon déjà en travaux de réfection ?
func en_travaux(eid: int) -> bool:
	var cv := ChantiersVoies.instance
	return cv != null and is_instance_valid(cv) and cv.en_reparation(eid)


func _auto_repairs(proprio := -1) -> void:
	var net := network()
	if net == null:
		return
	for k in VOIES:
		var cfg: Dictionary = entretien[k]
		if not bool(cfg.auto):
			continue
		var worst := pires(k, float(cfg.seuil), REPARATIONS_JOUR, proprio)
		for eid in worst:
			reparer(eid, true)


## Tronçons d'un réseau sous un seuil d'état, du pire au moins pire.
func pires(k: String, seuil := 1.0, n := 10, proprio := -1) -> Array:
	var net := network()
	var out := []
	if net == null:
		return out
	for eid in net.edges:
		if proprio >= 0 and proprio_voie(eid) != proprio:
			continue
		if (k == "" or voie_of(String(net.edges[eid].t)) == k) and etat(eid) < seuil and not en_travaux(eid):
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
	var d := _etat_dict()
	d["version"] = 2
	d["jour_total"] = jour_total
	d["next_loan"] = _next_loan
	d["reseaux"] = reseaux_ext.duplicate(true)
	d["cle"] = cle
	var es := {}
	for k in etats.keys():
		var keep := _pack()
		_unpack(etats[k])
		es[str(k)] = _etat_dict()
		_unpack(keep)
	d["communes"] = es
	return d


## État de la commune chargée, pour la sauvegarde.
func _etat_dict() -> Dictionary:
	return {"taux": taux.duplicate(), "emprunts": emprunts.duplicate(true), "next_loan": _next_loan,
		"entretien": entretien.duplicate(true), "reseaux": reseaux_ext.duplicate(true), "tutelle": tutelle,
		"jours_rouge": jours_rouge, "jours_vert": jours_vert, "mois": mois.duplicate(), "historique": historique.duplicate(true),
		"jours_mois": jours_mois}


func from_dict(d: Dictionary) -> void:
	clear()
	_charger_etat(d)
	_next_loan = int(d.get("next_loan", emprunts.size() + 1))
	var rx: Dictionary = d.get("reseaux", {})
	for r in rx:
		reseaux_ext[String(r)] = {}
		for id in rx[r]:
			var it: Dictionary = rx[r][id]
			reseaux_ext[String(r)][String(id)] = {"l": float(it.get("l", 0.0)), "u": clampf(float(it.get("u", 1.0)), 0.0, 1.0)}
	jour_total = int(d.get("jour_total", 0))
	# Autres communes (Pays) : chacune son état ; la commune chargée est `cle`.
	cle = int(d.get("cle", 0))
	var es: Dictionary = d.get("communes", {})
	for ks in es:
		var k := int(ks)
		if k == cle:
			continue
		var keep := _pack()
		_unpack({})
		_charger_etat(es[ks])
		etats[k] = _pack()
		_unpack(keep)
	# Voies hors d'usage : fermées comme avant la sauvegarde.
	var net := network()
	if net != null:
		for eid in net.edges:
			if etat(eid) <= 0.0:
				net.closed_edges[eid] = "usure"
	if vue != null:
		vue.rebuild()
	changed.emit()


## Charge l'état d'une commune (taux, emprunts, entretien, tutelle, comptes).
func _charger_etat(d: Dictionary) -> void:
	taux = {"foncier": 1.0, "entreprises": 1.0, "benefices": 1.0}
	emprunts = []
	entretien = {}
	_reset_entretien()
	var t: Dictionary = d.get("taux", {})
	for k in taux:
		taux[k] = clampf(float(t.get(k, 1.0)), TAUX_MIN, TAUX_MAX)
	for e in d.get("emprunts", []):
		if e is Dictionary and e.has("restant"):
			emprunts.append({"id": int(e.get("id", 0)), "capital": float(e.get("capital", e.restant)), "restant": float(e.restant),
				"taux": float(e.get("taux", TAUX_BASE)), "annees": int(e.get("annees", 10)), "mensualite": float(e.get("mensualite", 0.0)),
				"jour": int(e.get("jour", 0)), "nom": String(e.get("nom", "Prêt"))})
	var en: Dictionary = d.get("entretien", {})
	for k in entretien:
		if en.get(k) is Dictionary:
			var c: Dictionary = en[k]
			entretien[k] = {"taux": clampf(float(c.get("taux", 1.0)), 0.0, 2.0), "auto": bool(c.get("auto", true)),
				"seuil": clampf(float(c.get("seuil", 0.35)), 0.0, 0.9)}
	tutelle = bool(d.get("tutelle", false))
	jours_rouge = int(d.get("jours_rouge", 0))
	jours_vert = int(d.get("jours_vert", 0))
	mois = d.get("mois", {})
	historique = d.get("historique", [])
	jours_mois = int(d.get("jours_mois", 0))


static func _pct(t: float) -> String:
	return ("%.2f" % (t * 100.0)).replace(".", ",")
