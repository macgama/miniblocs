class_name Statistiques
extends Node
## Statistiques dans le temps (Maj+I) : chaque jour de jeu, un relevé des chiffres
## de chaque ville et du pays (habitants, satisfaction, chômage, caisse, solde du
## mois, logements et emplois libres, pollution, électricité, eau, embouteillages,
## déchets…). Les 400 derniers jours sont gardés jour par jour, les plus anciens
## en moyennes de 30 jours : on peut tracer toute la partie sans alourdir la
## sauvegarde. Le Conseiller lit ces relevés pour signaler les problèmes.

signal releve_fait
## Un problème grave vient d'apparaître (le conseiller lève la main).
signal alerte(texte: String, lieu: String)

static var instance: Statistiques

## Lieu « pays » (tout le territoire) ; les villes ont l'id de leur village en texte.
const PAYS := "pays"
## Jours gardés un par un ; au-delà, regroupés par paquets de REGROUPEMENT jours.
const JOURS_DETAIL := 400
const REGROUPEMENT := 30
## Nombre maximum de points regroupés (≈ 50 ans de partie) ; au-delà, regroupés par deux.
const POINTS_MAX := 600
## Habitants pris pour la pollution aux logements (le calcul complet est coûteux).
const ECHANTILLON_LOGEMENTS := 300

## Indicateurs : id, nom, unité, format (int, pct, money, dec), sens (+1 : plus c'est
## haut, mieux c'est ; −1 : l'inverse ; 0 : ni l'un ni l'autre), portée (ville :
## relevé par ville et pour le pays ; pays : seulement pour tout le pays).
const INDICATEURS := [
	{"id": "habitants", "nom": "Habitants", "unite": "", "fmt": "int", "sens": 1, "portee": "ville", "icone": "habitants"},
	{"id": "satisfaction", "nom": "Satisfaction", "unite": "/100", "fmt": "int", "sens": 1, "portee": "ville", "icone": "sourire"},
	{"id": "chomage", "nom": "Chômage", "unite": "%", "fmt": "pct", "sens": -1, "portee": "ville", "icone": "emploi"},
	{"id": "caisse", "nom": "Caisse", "unite": "€", "fmt": "money", "sens": 1, "portee": "ville", "icone": "budget"},
	{"id": "solde", "nom": "Solde du mois", "unite": "€/mois", "fmt": "money", "sens": 1, "portee": "ville", "icone": "budget"},
	{"id": "logements_libres", "nom": "Logements libres", "unite": "", "fmt": "int", "sens": 0, "portee": "ville", "icone": "logement"},
	{"id": "emplois_libres", "nom": "Emplois libres", "unite": "", "fmt": "int", "sens": 0, "portee": "ville", "icone": "industrie"},
	{"id": "sans_ecole", "nom": "Enfants sans école", "unite": "", "fmt": "int", "sens": -1, "portee": "ville", "icone": "ecole"},
	{"id": "pollution", "nom": "Pollution de l'air chez les habitants", "unite": "/100", "fmt": "int", "sens": -1, "portee": "ville", "icone": "paysage"},
	{"id": "electricite", "nom": "Électricité fournie", "unite": "%", "fmt": "pct", "sens": 1, "portee": "pays", "icone": "reseaux"},
	{"id": "eau", "nom": "Eau fournie", "unite": "%", "fmt": "pct", "sens": 1, "portee": "pays", "icone": "eau"},
	{"id": "coupures", "nom": "Bâtiments privés de courant ou d'eau", "unite": "", "fmt": "int", "sens": -1, "portee": "pays", "icone": "reseaux"},
	{"id": "congestion", "nom": "Temps perdu dans les bouchons", "unite": "%", "fmt": "pct", "sens": -1, "portee": "pays", "icone": "circulation"},
	{"id": "trajet", "nom": "Trajet moyen", "unite": "min", "fmt": "dec", "sens": -1, "portee": "pays", "icone": "circulation"},
	{"id": "dechets", "nom": "Poubelles qui débordent", "unite": "", "fmt": "int", "sens": -1, "portee": "pays", "icone": "dechets"},
	{"id": "recyclage", "nom": "Déchets recyclés", "unite": "%", "fmt": "pct", "sens": 1, "portee": "pays", "icone": "dechets"},
]

var population: Population
var communes: Communes
var pays: Pays
var budget: BudgetCommunal
var reseaux: Reseaux
var trafic: Trafic
var dechets: Dechets
var nuisances: Nuisances
var avis: Avis

## Relevés, du plus ancien au plus récent : {"j": jour, "n": jours regroupés, "d": {lieu: {indicateur: valeur}}}.
var historique: Array = []
## Noms des villes relevées (une ville fusionnée ou disparue garde ses courbes).
var noms := {}
## Problèmes graves déjà signalés (lieu:id), pour ne pas répéter l'alerte chaque jour.
var _alertes := {}
var _dernier_jour := -1
## Relevé automatique chaque jour (coupé par les tests qui relèvent à la main).
var auto := true


func setup(pop: Population, cm: Communes, p: Pays, bud: BudgetCommunal, res: Reseaux, tr: Trafic, dch: Dechets,
		nui: Nuisances, av: Avis) -> void:
	population = pop
	communes = cm
	pays = p
	budget = bud
	reseaux = res
	trafic = tr
	dechets = dch
	nuisances = nui
	avis = av


func clear() -> void:
	historique.clear()
	noms.clear()
	_alertes.clear()
	_dernier_jour = -1


static func indicateur(id: String) -> Dictionary:
	for d in INDICATEURS:
		if d.id == id:
			return d
	return {}


# --- Relevé quotidien ------------------------------------------------------------------

func jour() -> int:
	return int(population.now().day) if population != null else 0


func _process(_delta: float) -> void:
	if not auto or population == null:
		return
	var d := jour()
	if _dernier_jour < 0:
		_dernier_jour = d
		if historique.is_empty():
			releve()
		return
	if d != _dernier_jour:
		_dernier_jour = d
		releve()


## Relève les chiffres du jour pour le pays et chaque ville.
func releve() -> void:
	var j := jour()
	if communes != null:
		communes.calculer_stats()
	var d := {}
	d[PAYS] = _chiffres_pays()
	for vid in _villes():
		d[str(vid)] = _chiffres_ville(int(vid))
		noms[str(vid)] = pays.nom_de(int(vid)) if pays != null else String(communes.villages[vid].nom)
	_nationaux(d[PAYS])
	if not historique.is_empty() and int(historique[-1].j) == j and int(historique[-1].n) == 1:
		historique[-1] = {"j": j, "n": 1, "d": d}
	else:
		historique.append({"j": j, "n": 1, "d": d})
	_compacter()
	releve_fait.emit()
	_verifier_alertes()


func _villes() -> Array:
	if communes == null:
		return []
	var ids: Array = communes.villages.keys()
	ids.sort()
	return ids


## Chiffres par habitant : chômage, enfants sans école, pollution, par lieu ("" = pays).
func _par_habitant() -> Dictionary:
	var out := {}
	if population == null:
		return out
	var bv: Dictionary = communes.bat_village if communes != null else {}
	var pas := maxi(1, population.persons.size() / ECHANTILLON_LOGEMENTS)
	var i := 0
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		var home := population.home_of(p)
		if home >= 0 and Fondateurs.est_campement(home):
			i += 1
			continue
		var lieux := [PAYS]
		var vid := int(bv.get(home, -1))
		if vid >= 0:
			lieux.append(str(vid))
		var st := population.stage(p)
		var pol := -1.0
		if nuisances != null and home >= 0 and i % pas == 0:
			pol = nuisances.air(population.building_pos(home))
		i += 1
		for l in lieux:
			if not out.has(l):
				out[l] = {"actifs": 0, "chomeurs": 0, "sans_ecole": 0, "pol": 0.0, "pol_n": 0}
			var o: Dictionary = out[l]
			if st == "actif":
				o.actifs += 1
			elif st == "chomeur":
				o.chomeurs += 1
			elif st == "eleve" and int(p.sch) < 0:
				o.sans_ecole += 1
			if pol >= 0.0:
				o.pol += pol
				o.pol_n += 1
	return out


var _hab_cache := {}


func _chiffres_pays() -> Dictionary:
	_hab_cache = _par_habitant()
	var c := {}
	var s := population.stats() if population != null else {}
	c.habitants = int(s.get("habitants", 0))
	_communs(c, PAYS)
	if avis != null and population != null and not population.persons.is_empty():
		var sd := avis.sondage(true)
		if int(sd.n) > 0:
			c.satisfaction = int(sd.valeur)
	elif s.has("satisfaction") and c.habitants > 0:
		c.satisfaction = int(s.satisfaction)
	if pays != null:
		c.caisse = pays.solde(Pays.PAYS) if pays.a_des_villes() else (pays.buildings.money if pays.buildings != null else 0)
	if budget != null:
		var b := budget.bilan_mensuel(Pays.PAYS if BudgetCommunal.multi() else -1)
		c.solde = roundi(float(b.get("solde", 0.0)))
	c.logements_libres = maxi(0, int(s.get("logements", 0)) - int(s.get("foyers", 0)))
	c.emplois_libres = maxi(0, int(s.get("emplois", 0)) - int(s.get("actif", 0)))
	return c


func _chiffres_ville(vid: int) -> Dictionary:
	var c := {}
	var st: Dictionary = communes.stats.get(vid, {})
	c.habitants = int(st.get("hab", 0))
	_communs(c, str(vid))
	if avis != null and c.habitants > 0:
		# Satisfaction de la ville : moyenne des logements du dernier sondage.
		var sd := avis.sondage()
		var tot := 0.0
		var n := 0
		for bid in sd.get("logements", {}):
			if int(communes.bat_village.get(bid, -1)) == vid:
				tot += float(sd.logements[bid])
				n += 1
		if n > 0:
			c.satisfaction = roundi(tot / n)
	if pays != null:
		c.caisse = pays.solde(vid)
	if budget != null:
		c.solde = roundi(float(budget.bilan_mensuel(vid).get("solde", 0.0)))
	c.logements_libres = maxi(0, int(st.get("logements", 0)) - int(st.get("foyers", 0)))
	c.emplois_libres = maxi(0, int(st.get("emplois", 0)) - int(c.get("_actifs", 0)))
	c.erase("_actifs")
	return c


## Chômage, enfants sans école et pollution d'un lieu (d'après _par_habitant).
func _communs(c: Dictionary, lieu: String) -> void:
	var h: Dictionary = _hab_cache.get(lieu, {})
	var adultes := int(h.get("actifs", 0)) + int(h.get("chomeurs", 0))
	if adultes > 0:
		c.chomage = 100.0 * int(h.chomeurs) / adultes
	c._actifs = int(h.get("actifs", 0))
	c.sans_ecole = int(h.get("sans_ecole", 0))
	if int(h.get("pol_n", 0)) > 0:
		c.pollution = 100.0 * float(h.pol) / int(h.pol_n)
	if lieu == PAYS:
		c.erase("_actifs")


## Réseaux, trafic et déchets : un seul chiffre pour tout le pays.
func _nationaux(c: Dictionary) -> void:
	if reseaux != null:
		var coupes := 0
		for res in ["elec", "eau"]:
			var b := reseaux.bilan(res)
			coupes += int(b.get("coupes", 0))
			if float(b.demande) > 0.0:
				c["electricite" if res == "elec" else "eau"] = 100.0 * clampf(float(b.servi) / float(b.demande), 0.0, 1.0)
		c.coupures = coupes
	if trafic != null and trafic.stats.has("jam_factor"):
		c.congestion = maxf(0.0, (float(trafic.stats.jam_factor) - 1.0) * 100.0)
		c.trajet = float(trafic.stats.get("avg_min", 0.0))
	if dechets != null and not dechets.yesterday.is_empty():
		var b := dechets.bilan()
		c.dechets = int(b.debordent)
		if float(b.produit) > 0.0:
			c.recyclage = 100.0 * float(b.taux_recyclage)


## Garde le détail des derniers jours et regroupe les plus anciens.
func _compacter() -> void:
	var detail := 0
	for e in historique:
		if int(e.n) == 1:
			detail += 1
	while detail > JOURS_DETAIL:
		# Premier relevé jour par jour : on regroupe les REGROUPEMENT suivants.
		var i0 := 0
		while i0 < historique.size() and int(historique[i0].n) != 1:
			i0 += 1
		var k := mini(REGROUPEMENT, historique.size() - i0)
		historique[i0] = _moyenne(historique.slice(i0, i0 + k))
		for _i in k - 1:
			historique.remove_at(i0 + 1)
		detail -= k
	while _regroupes() > POINTS_MAX:
		for i in historique.size() - 1:
			if int(historique[i].n) > 1 and int(historique[i + 1].n) > 1:
				historique[i] = _moyenne([historique[i], historique[i + 1]])
				historique.remove_at(i + 1)
				break


func _regroupes() -> int:
	var n := 0
	for e in historique:
		if int(e.n) > 1:
			n += 1
	return n


## Moyenne de plusieurs relevés (pondérée par les jours de chacun).
static func _moyenne(liste: Array) -> Dictionary:
	var somme := {}
	var poids := {}
	var n := 0
	for e in liste:
		var w := int(e.n)
		n += w
		for lieu in e.d:
			if not somme.has(lieu):
				somme[lieu] = {}
				poids[lieu] = {}
			for ind in e.d[lieu]:
				somme[lieu][ind] = float(somme[lieu].get(ind, 0.0)) + float(e.d[lieu][ind]) * w
				poids[lieu][ind] = int(poids[lieu].get(ind, 0)) + w
	var d := {}
	for lieu in somme:
		d[lieu] = {}
		for ind in somme[lieu]:
			d[lieu][ind] = float(somme[lieu][ind]) / int(poids[lieu][ind])
	return {"j": int(liste[0].j), "n": n, "d": d}


# --- Lecture -------------------------------------------------------------------------------

## Lieux relevés : le pays puis les villes (même disparues), avec leur nom.
func lieux() -> Array:
	var out := [[PAYS, pays.nom_pays() if pays != null else "Pays"]]
	var ids := noms.keys()
	ids.sort_custom(func(a, b) -> bool: return int(a) < int(b))
	for k in ids:
		var nom := String(noms[k])
		if pays != null and communes != null and communes.villages.has(int(k)):
			nom = pays.nom_de(int(k))
		elif communes != null and not communes.villages.has(int(k)):
			nom += " (disparue)"
		out.append([String(k), nom])
	return out


## Points (jour, valeur) d'un indicateur depuis le jour `depuis` (−1 : toute la partie).
func serie(lieu: String, ind: String, depuis := -1) -> PackedVector2Array:
	var out := PackedVector2Array()
	for e in historique:
		if depuis >= 0 and int(e.j) + int(e.n) - 1 < depuis:
			continue
		var v: Dictionary = e.d.get(lieu, {})
		if v.has(ind):
			# Un relevé regroupé est placé au milieu de sa période.
			out.append(Vector2(float(e.j) + (float(e.n) - 1.0) * 0.5, float(v[ind])))
	return out


## Dernière valeur relevée (NAN si jamais relevée).
func dernier(lieu: String, ind: String) -> float:
	for i in range(historique.size() - 1, -1, -1):
		var v: Dictionary = historique[i].d.get(lieu, {})
		if v.has(ind):
			return float(v[ind])
	return NAN


## Valeur d'il y a `jours` jours (la plus proche), NAN si on n'a rien d'aussi vieux.
func il_y_a(lieu: String, ind: String, jours: int) -> float:
	if historique.is_empty():
		return NAN
	var cible := int(historique[-1].j) - jours
	var best := NAN
	for e in historique:
		if int(e.j) > cible:
			break
		var v: Dictionary = e.d.get(lieu, {})
		if v.has(ind):
			best = float(v[ind])
	return best


## Évolution sur `jours` jours (NAN si on n'a pas assez de recul).
func evolution(lieu: String, ind: String, jours: int) -> float:
	var a := il_y_a(lieu, ind, jours)
	var b := dernier(lieu, ind)
	return NAN if is_nan(a) or is_nan(b) else b - a


func premier_jour() -> int:
	return int(historique[0].j) if not historique.is_empty() else jour()


func dernier_jour() -> int:
	return int(historique[-1].j) if not historique.is_empty() else jour()


## Valeur mise en forme : « 1 234 », « 12 % », « 3,4 M€ », « 18,5 min ».
static func format(ind: String, v: float, avec_unite := true) -> String:
	if is_nan(v):
		return "—"
	var d := indicateur(ind)
	match String(d.get("fmt", "int")):
		"money":
			return _money(v)
		"pct":
			return ("%d %%" if avec_unite else "%d") % roundi(v)
		"dec":
			var s := String.num(snappedf(v, 0.1), 1).replace(".", ",")
			return s + (" " + String(d.unite) if avec_unite and String(d.unite) != "" else "")
		_:
			var t := _milliers(roundi(v))
			return t + (" " + String(d.unite) if avec_unite and String(d.unite) != "" and String(d.unite) != "/100" else "")


## Écart mis en forme avec son signe : « +12 », « −3 % », « +1,2 M€ ».
static func format_ecart(ind: String, v: float) -> String:
	if is_nan(v):
		return ""
	var signe := "+" if v > 0.0 else ("−" if v < 0.0 else "±")
	var d := indicateur(ind)
	var a := absf(v)
	match String(d.get("fmt", "int")):
		"money":
			return signe + _money(a)
		"pct":
			return "%s%d pt" % [signe, roundi(a)]
		"dec":
			return signe + String.num(snappedf(a, 0.1), 1).replace(".", ",")
		_:
			return signe + _milliers(roundi(a))


static func _milliers(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


static func _money(v: float) -> String:
	var a := absf(v)
	var signe := "-" if v < 0.0 else ""
	if a >= 1_000_000.0:
		return signe + String.num(snappedf(a / 1_000_000.0, 0.1), 1).replace(".", ",") + " M€"
	if a >= 10_000.0:
		return signe + "%d k€" % roundi(a / 1000.0)
	return signe + _milliers(roundi(a)) + " €"


## Date d'un jour de jeu : « 12 avr. 2026 ».
static func date(j: float, court := false) -> String:
	const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
	var dt := Time.get_datetime_dict_from_unix_time(int(floorf(j)) * 86400)
	if court:
		return "%s %d" % [MOIS[int(dt.month) - 1], int(dt.year)]
	return "%d %s %d" % [int(dt.day), MOIS[int(dt.month) - 1], int(dt.year)]


# --- Alertes du conseiller ----------------------------------------------------------------------

func _verifier_alertes() -> void:
	var vus := {}
	var lieux_suivis := [PAYS]
	for vid in _villes():
		lieux_suivis.append(str(vid))
	for lieu in lieux_suivis:
		for a in Conseiller.analyser(self, lieu):
			if int(a.gravite) < 2:
				continue
			var cle := "%s:%s" % [lieu, a.id]
			vus[cle] = true
			if not _alertes.has(cle):
				var ou := "" if lieu == PAYS or _villes().size() <= 1 else " (%s)" % String(noms.get(lieu, lieu))
				alerte.emit("Conseiller%s : %s" % [ou, String(a.titre)], lieu)
	_alertes = vus


# --- Sauvegarde --------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var h := []
	for e in historique:
		var d := {}
		for lieu in e.d:
			d[lieu] = {}
			for ind in e.d[lieu]:
				d[lieu][ind] = snappedf(float(e.d[lieu][ind]), 0.01)
		h.append({"j": int(e.j), "n": int(e.n), "d": d})
	return {"version": 1, "historique": h, "noms": noms.duplicate(), "alertes": _alertes.keys()}


func from_dict(d: Dictionary) -> void:
	clear()
	for e in d.get("historique", []):
		if e is Dictionary and e.has("j") and e.has("d"):
			historique.append({"j": int(e.j), "n": maxi(1, int(e.get("n", 1))), "d": e.d})
	for k in d.get("noms", {}):
		noms[String(k)] = String(d.noms[k])
	for k in d.get("alertes", []):
		_alertes[String(k)] = true
	_dernier_jour = int(historique[-1].j) if not historique.is_empty() else -1
