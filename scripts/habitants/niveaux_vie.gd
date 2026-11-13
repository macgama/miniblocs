class_name NiveauxVie
extends Node
## Niveaux de vie des foyers (panneau Maj+N).
##
## Chaque foyer a un niveau, de « Précaire » à « Très aisé ». Il monte quand ses
## besoins du niveau suivant sont couverts assez longtemps (eau, courant,
## commerces, école, santé, internet, loisirs, calme, sécurité, quartier, beau
## logement…) et que ses revenus le permettent. Il redescend quand un besoin de
## son niveau manque trop longtemps (coupure, commerce vide, hôpital saturé,
## chômage…).
##
## Ce que le niveau change :
##   - impôts : la taxe foncière d'un foyer aisé rapporte plus (logement mieux estimé) ;
##   - consommation : courses un peu plus chères, et beaucoup plus de vêtements,
##     d'électronique, de meubles et de biens achetés dans les commerces (Production) ;
##   - dépenses du foyer : sorties et loisirs payés chaque mois ;
##   - revenus : les foyers aisés placent leur épargne (intérêts) ;
##   - logement : un foyer qui veut monter quitte un logement trop modeste pour
##     un logement libre plus cossu (maison, confort, quartier recherché) ;
##   - avis : un foyer qui monte est content, un foyer qui descend ou qui reste
##     bloqué l'est moins (thème Logement, groupe « avis_sources »).
##
## Données : h.nv (niveau 0..4) et h.nvp (progression −1..1) dans chaque foyer
## de Population ; sauvegardés dans la section « niveaux_vie ». Sans ce module,
## un foyer sans h.nv garde les coefficients neutres (1).
##
## Pour les autres systèmes :
##   NiveauxVie.niveau(h) -> 0..4 (−1 si pas encore évalué)
##   NiveauxVie.coef_taxe(h), coef_courses(h), coef_conso(h, marchandise)
##   NiveauxVie.instance.manques(hid) -> besoins qui empêchent de monter

signal changed
signal message(text: String)

static var instance: NiveauxVie

## Les cinq niveaux : nom, couleur, revenu mensuel par unité de consommation
## (INSEE : 1 pour le premier adulte, 0,5 par personne de 14 ans ou plus, 0,3 par
## enfant), jours pour y monter.
const NIVEAUX := [
	{"nom": "Précaire", "court": "précaire", "couleur": Color("e76f51"), "revenu": 0.0, "jours": 0},
	{"nom": "Modeste", "court": "modeste", "couleur": Color("f4a261"), "revenu": 0.0, "jours": 4},
	{"nom": "Classe moyenne", "court": "classe moyenne", "couleur": Color("e9c46a"), "revenu": 1300.0, "jours": 7},
	{"nom": "Aisé", "court": "aisé", "couleur": Color("2a9d8f"), "revenu": 1800.0, "jours": 12},
	{"nom": "Très aisé", "court": "très aisé", "couleur": Color("4361ee"), "revenu": 2300.0, "jours": 20},
]
## Besoins à couvrir pour atteindre chaque niveau (en plus de ceux des niveaux d'en dessous).
const BESOINS_NIVEAU := [
	[],
	["toit", "nourriture", "eau", "electricite", "dettes"],
	["ecole", "sante", "egouts", "internet", "commerces"],
	["transports", "loisirs", "calme", "securite", "logement"],
	["biens", "quartier", "beau_logement"],
]
## Nom et conseil de chaque besoin (le conseil s'affiche dans le panneau).
const BESOINS := {
	"toit": ["Un vrai logement", "Les fondateurs sous la tente attendent des maisons."],
	"nourriture": ["De quoi manger", "Une boulangerie, une supérette ou un marché approvisionné à proximité (P → commerces)."],
	"eau": ["Eau courante", "Raccorde le quartier à l'eau potable (O)."],
	"electricite": ["Électricité", "Pas de coupure de courant (O)."],
	"dettes": ["Pas de dettes", "Des emplois pour les adultes ; des loyers abordables."],
	"ecole": ["École pour les enfants", "Une école avec des places, assez proche (B → Services publics)."],
	"sante": ["Hôpital proche", "Un hôpital à moins de 30 min, avec des lits libres (B → Services publics)."],
	"egouts": ["Tout-à-l'égout", "Égouts raccordés à une station d'épuration (O)."],
	"internet": ["Internet", "ADSL, fibre ou bon réseau mobile (Maj+O)."],
	"commerces": ["Vêtements et hygiène", "Une boutique de vêtements, une pharmacie ou un supermarché approvisionnés."],
	"transports": ["Trajets courts", "Moins de 35 min pour aller au travail ou à l'école : routes, lignes (L)."],
	"loisirs": ["Loisirs", "Au moins deux tiers des loisirs des habitants possibles en ville (sport, culture, parcs)."],
	"calme": ["Quartier calme", "Loin des usines, des grandes routes et des bars de nuit (N → Nuisances)."],
	"securite": ["Sécurité", "Un commissariat qui couvre le quartier (B → Services publics)."],
	"logement": ["Logement agréable", "Une maison, un logement confortable ou un quartier recherché."],
	"biens": ["Électronique et meubles", "Un magasin d'électronique et un magasin de meubles approvisionnés."],
	"quartier": ["Quartier recherché", "Terrain cher : parcs, verdure, bord de l'eau, services (N → Valeur du terrain)."],
	"beau_logement": ["Beau logement", "Une maison ou un logement confortable dans un quartier recherché."],
}
## Effets de chaque niveau.
const TAXE := [0.6, 0.85, 1.0, 1.3, 1.7]
const COURSES := [0.8, 0.92, 1.0, 1.15, 1.35]
## Sorties, loisirs et achats (€ par mois et par adulte).
const SORTIES := [0.0, 30.0, 90.0, 220.0, 450.0]
## Marchandises qui ne sont pas de la nourriture : leur achat suit beaucoup le niveau.
const BIENS_COURANTS := ["vetements", "electronique", "meubles", "biens", "boissons", "hygiene", "voitures"]
const CONSO_BIENS := [0.5, 0.8, 1.0, 1.5, 2.2]
const CONSO_NOURRITURE := [0.9, 0.95, 1.0, 1.05, 1.1]
## Intérêts de l'épargne placée (par an), à partir du niveau Aisé.
const PLACEMENT := 0.025
const NIVEAU_PLACEMENT := 3
## Très aisé : ce revenu par unité suffit avec une belle épargne.
const EPARGNE_TRES_AISE := 60000.0
## Jours pour perdre un niveau quand un besoin manque.
const JOURS_DESCENTE := 10.0
## Les nouveaux arrivants commencent au plus à ce niveau (Classe moyenne).
const NIVEAU_ARRIVEE_MAX := 2
## Trajet maximal pour le besoin « transports » (min).
const TRAJET_MAX := 35
## Chance par jour qu'un foyer bloqué par son logement déménage (s'il trouve mieux).
const CHANCE_DEMENAGER := 0.15
## Foyers évalués par image (le calcul complet est étalé).
const PAR_IMAGE := 400

var population: Population
var production: Production
var buildings: BuildingSystem
var telecom: Telecom
## Besoins manquants pour le niveau suivant (hid -> Array) et pour le niveau actuel.
var _manque_suivant := {}
var _manque_actuel := {}
## Derniers changements : hid -> [jour, +1 / −1].
var recents := {}
## Totaux depuis le début : montées, descentes, déménagements.
var totaux := {"montees": 0, "descentes": 0, "demenagements": 0}
var _queue: Array = []
var _dernier_jour := -1
var _jour := 0
var _news := {}
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func _enter_tree() -> void:
	instance = self
	add_to_group("avis_sources")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(pop: Population, prod: Production, bs: BuildingSystem, tel: Telecom = null) -> void:
	population = pop
	production = prod
	buildings = bs
	telecom = tel


func clear() -> void:
	_manque_suivant.clear()
	_manque_actuel.clear()
	recents.clear()
	totaux = {"montees": 0, "descentes": 0, "demenagements": 0}
	_queue.clear()
	_dernier_jour = -1
	_news.clear()
	changed.emit()


# --- Lecture (statique : utilisable sans le module) ---------------------------------------

## Niveau d'un foyer (−1 : pas encore évalué).
static func niveau(h: Dictionary) -> int:
	return int(h.get("nv", -1))


static func nom(n: int) -> String:
	if n < 0:
		return "—"
	return String(NIVEAUX[clampi(n, 0, NIVEAUX.size() - 1)].nom)


static func couleur(n: int) -> Color:
	if n < 0:
		return Color(0.6, 0.6, 0.6)
	return NIVEAUX[clampi(n, 0, NIVEAUX.size() - 1)].couleur


static func _coef(h: Dictionary, table: Array) -> float:
	var n := niveau(h)
	return 1.0 if n < 0 else float(table[clampi(n, 0, table.size() - 1)])


static func coef_taxe(h: Dictionary) -> float:
	return _coef(h, TAXE)


static func coef_courses(h: Dictionary) -> float:
	return _coef(h, COURSES)


## Achats d'une marchandise par personne, selon le niveau du foyer.
static func coef_conso(h: Dictionary, good: String) -> float:
	return _coef(h, CONSO_BIENS if BIENS_COURANTS.has(good) else CONSO_NOURRITURE)


## Dépenses de sorties et loisirs (€ par mois) d'un foyer.
static func sorties(h: Dictionary, adultes: int) -> float:
	var n := niveau(h)
	return 0.0 if n < 0 else float(SORTIES[clampi(n, 0, SORTIES.size() - 1)]) * adultes


## Intérêts de l'épargne (€ par mois) pour les foyers aisés.
static func placements(h: Dictionary) -> float:
	if niveau(h) < NIVEAU_PLACEMENT:
		return 0.0
	return maxf(float(h.get("ep", 0.0)), 0.0) * PLACEMENT / 12.0


# --- Besoins ---------------------------------------------------------------------------------

## Revenu mensuel par unité de consommation (sans les sorties ni les placements).
func revenu_uc(hid: int) -> float:
	var h: Dictionary = population.households[hid]
	var uc := 0.0
	var first := true
	var inc := 0.0
	for pid in h.m:
		var p: Dictionary = population.persons[pid]
		inc += population.income_of(p)
		if first and String(p.r) == "adulte":
			uc += 1.0
			first = false
		elif population.age_of(p) >= 14.0:
			uc += 0.5
		else:
			uc += 0.3
	if first:
		# Pas d'adulte (rare) : le plus âgé compte pour 1.
		uc += 0.5
	return inc / maxf(uc, 1.0)


## Niveau d'un logement : jusqu'où un foyer peut monter en y vivant (0..4).
func plafond_logement(bid: int) -> int:
	if not population.known.has(bid):
		return 0
	var info: Dictionary = population.known[bid]
	if bool(info.get("camp", false)):
		return 0
	var score := 0
	if bool(info.get("house", false)):
		score += 1
	if int(info.get("conf", 0)) >= 60:
		score += 1
	var c := Nuisances.instance.coef_foncier(bid) if Nuisances.instance != null else 1.0
	if c >= 1.2:
		score += 1
	if c >= 1.6:
		score += 1
	return 2 + mini(score, 2)


func _vend(home: int, goods: Array) -> bool:
	if production == null:
		return true
	var miss: Dictionary = production.manque_foyers.get(home, {})
	for g in goods:
		if miss.has(g) or production._shops_for(home, String(g)).is_empty():
			return false
	return true


func _vend_un(home: int, goods: Array) -> bool:
	if production == null:
		return true
	var miss: Dictionary = production.manque_foyers.get(home, {})
	for g in goods:
		if not miss.has(g) and not production._shops_for(home, String(g)).is_empty():
			return true
	return false


## Un besoin est-il couvert pour ce foyer ?
func besoin(hid: int, id: String) -> bool:
	var h: Dictionary = population.households[hid]
	var home := int(h.b)
	match id:
		"toit":
			return plafond_logement(home) > 0
		"nourriture":
			return _vend_un(home, ["epicerie", "pain"]) and _sans_manque_nourriture(home)
		"eau":
			return Reseaux.instance == null or Reseaux.instance.taux(home, "eau") >= 0.9
		"electricite":
			return Reseaux.instance == null or Reseaux.instance.taux(home, "elec") >= 0.9
		"dettes":
			return float(h.ep) >= 0.0
		"ecole":
			return ServicesPublics.instance == null or not ServicesPublics.instance.households_has_child_without_school(hid)
		"sante":
			return ServicesPublics.instance == null or ServicesPublics.instance.couverture_bid(home, "hopital") >= 0.4
		"egouts":
			return Reseaux.instance == null or Reseaux.instance.raccorde_egout(home)
		"internet":
			var tel := _telecom()
			if tel == null:
				return true
			return String(tel.qualite(home)) in ["", "fibre", "adsl", "mobile"]
		"commerces":
			return _vend_un(home, ["vetements"]) and _vend_un(home, ["hygiene"])
		"transports":
			for pid in h.m:
				var p: Dictionary = population.persons[pid]
				var dest := int(p.job) if int(p.job) >= 0 else int(p.sch)
				if dest >= 0 and int(population.commute(p, home, dest).min) > TRAJET_MAX:
					return false
			return true
		"loisirs":
			var n := 0
			var ok := 0
			for pid in h.m:
				var p: Dictionary = population.persons[pid]
				for hb in p.hob:
					n += 1
					if (Metiers.LOISIRS[hb].lieux as Array).is_empty() or population.venue_for(p, String(hb)) >= 0:
						ok += 1
			return n == 0 or float(ok) / n >= 0.66
		"calme":
			return Nuisances.instance == null or Nuisances.instance.gene(home) < 0.35
		"securite":
			return ServicesPublics.instance == null or ServicesPublics.instance.couverture_bid(home, "police") >= 0.5
		"logement":
			return plafond_logement(home) >= 3
		"biens":
			return _vend_un(home, ["electronique"]) and _vend_un(home, ["meubles"])
		"quartier":
			return Nuisances.instance == null or Nuisances.instance.coef_foncier(home) >= 1.3
		"beau_logement":
			return plafond_logement(home) >= 4
	return true


func _sans_manque_nourriture(home: int) -> bool:
	if production == null:
		return true
	var miss: Dictionary = production.manque_foyers.get(home, {})
	var n := 0
	for g in miss:
		if Ressources.NOURRITURE.has(g):
			n += 1
	return n <= 2


func _telecom() -> Telecom:
	return telecom if is_instance_valid(telecom) else null


## Le revenu permet-il ce niveau ?
func revenu_suffit(hid: int, n: int) -> bool:
	var r := revenu_uc(hid)
	var seuil := float(NIVEAUX[n].revenu) * ReglagesPartie.actuel.salaires
	if r >= seuil:
		return true
	# Très aisé : un revenu d'Aisé et un beau patrimoine suffisent.
	return n == 4 and r >= float(NIVEAUX[3].revenu) * ReglagesPartie.actuel.salaires \
		and float(population.households[hid].ep) >= EPARGNE_TRES_AISE


## Besoins manquants pour atteindre le niveau n (cumulés), revenu compris ("revenu").
func manques_pour(hid: int, n: int) -> Array:
	var out := []
	for l in range(1, mini(n, NIVEAUX.size() - 1) + 1):
		for b in BESOINS_NIVEAU[l]:
			if not besoin(hid, String(b)):
				out.append(b)
	if n >= 1 and not revenu_suffit(hid, n):
		out.append("revenu")
	return out


## Plus haut niveau que le foyer pourrait tenir aujourd'hui.
func niveau_possible(hid: int) -> int:
	var n := 0
	for l in range(1, NIVEAUX.size()):
		var ok := revenu_suffit(hid, l)
		if ok:
			for b in BESOINS_NIVEAU[l]:
				if not besoin(hid, String(b)):
					ok = false
					break
		if not ok:
			break
		n = l
	return n


## Ce qui empêche le foyer de monter (dernier calcul).
func manques(hid: int) -> Array:
	return _manque_suivant.get(hid, [])


static func nom_besoin(id: String) -> String:
	if id == "revenu":
		return "Revenus suffisants"
	return String(BESOINS.get(id, [id])[0])


static func conseil(id: String) -> String:
	if id == "revenu":
		return "Des emplois mieux payés (bureaux, hôpital, industrie) ; les diplômés gagnent plus."
	return String(BESOINS.get(id, ["", ""])[1])


# --- Chaque jour -----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if population == null:
		return
	var d := int(population.now().day)
	if d != _dernier_jour:
		# Nouveau jour : tous les foyers repassent (étalés sur plusieurs images).
		if _dernier_jour >= 0:
			_jour += 1
		_dernier_jour = d
		_queue = population.households.keys()
	if not _queue.is_empty():
		var n := mini(PAR_IMAGE, _queue.size())
		for i in n:
			var hid := int(_queue.pop_back())
			if population.households.has(hid):
				evaluer(hid, true)
		if _queue.is_empty():
			_fin_de_journee()


## Évalue un foyer : besoins, progression ; jour : un jour de jeu passe.
func evaluer(hid: int, jour := false) -> void:
	var h: Dictionary = population.households[hid]
	if (h.m as Array).is_empty() or not population.known.has(int(h.b)):
		return
	if niveau(h) < 0:
		# Nouveau foyer (ou ancienne partie) : il arrive au niveau que la ville
		# permet, au plus Classe moyenne.
		h.nv = mini(niveau_possible(hid), NIVEAU_ARRIVEE_MAX)
		h.nvp = 0.0
	var nv := int(h.nv)
	var actuel := manques_pour(hid, nv) if nv > 0 else []
	_manque_actuel[hid] = actuel
	var suivant := manques_pour(hid, nv + 1) if nv + 1 < NIVEAUX.size() else []
	# Seulement ce qui manque en plus de l'actuel (sinon les deux listes se répètent).
	for b in actuel:
		suivant.erase(b)
	_manque_suivant[hid] = suivant if nv + 1 < NIVEAUX.size() else []
	if not jour:
		return
	var p := float(h.get("nvp", 0.0))
	if not actuel.is_empty():
		p -= 1.0 / JOURS_DESCENTE
		if p <= -0.999:
			_changer(hid, nv - 1, actuel)
			return
	elif nv + 1 < NIVEAUX.size() and suivant.is_empty():
		p = maxf(p, 0.0) + 1.0 / float(NIVEAUX[nv + 1].jours)
		if p >= 0.999:
			_changer(hid, nv + 1, [])
			return
	else:
		p = move_toward(p, 0.0, 0.2)
		# Bloqué seulement par son logement : il cherche plus cossu.
		if nv + 1 < NIVEAUX.size() and _bloque_par_logement(suivant) and rng.randf() < CHANCE_DEMENAGER:
			_demenager(hid, nv + 1)
	h.nvp = p


func _bloque_par_logement(manque: Array) -> bool:
	if manque.is_empty():
		return false
	for b in manque:
		if not String(b) in ["logement", "beau_logement", "quartier", "calme"]:
			return false
	return true


## Un logement libre qui permettrait de monter au niveau n.
func _demenager(hid: int, n: int) -> bool:
	var h: Dictionary = population.households[hid]
	var best := -1
	var best_d := INF
	var here := population.building_pos(int(h.b))
	for bid in population.known:
		if int(bid) == int(h.b) or population.free_homes(int(bid)) <= 0:
			continue
		if plafond_logement(int(bid)) < n:
			continue
		if n >= 3 and Nuisances.instance != null and Nuisances.instance.gene(int(bid)) >= 0.35:
			continue
		if n >= 4 and Nuisances.instance != null and Nuisances.instance.coef_foncier(int(bid)) < 1.3:
			continue
		var d := here.distance_to(population.building_pos(int(bid)))
		if d < best_d:
			best_d = d
			best = int(bid)
	if best < 0:
		return false
	population.move_household(hid, best)
	totaux.demenagements = int(totaux.demenagements) + 1
	_news["demenage"] = int(_news.get("demenage", 0)) + 1
	return true


func _changer(hid: int, n: int, cause: Array) -> void:
	var h: Dictionary = population.households[hid]
	var avant := int(h.nv)
	h.nv = clampi(n, 0, NIVEAUX.size() - 1)
	h.nvp = 0.0
	var monte := int(h.nv) > avant
	recents[hid] = [_jour, 1 if monte else -1]
	var txt := ""
	if monte:
		totaux.montees = int(totaux.montees) + 1
		txt = "Le foyer passe au niveau de vie « %s »" % nom(int(h.nv))
		_news["up%d" % int(h.nv)] = int(_news.get("up%d" % int(h.nv), 0)) + 1
	else:
		totaux.descentes = int(totaux.descentes) + 1
		txt = "Le foyer redescend au niveau de vie « %s »" % nom(int(h.nv))
		if not cause.is_empty():
			txt += " (%s)" % nom_besoin(String(cause[0])).to_lower()
		_news["down"] = int(_news.get("down", 0)) + 1
	for pid in h.m:
		var p: Dictionary = population.persons[pid]
		if String(p.r) == "adulte":
			population.vie.log_event(p, "niveau", txt)
	evaluer(hid, false)


func _fin_de_journee() -> void:
	# Oublie les foyers partis.
	for dict in [_manque_suivant, _manque_actuel, recents]:
		for hid in (dict as Dictionary).keys():
			if not population.households.has(hid):
				(dict as Dictionary).erase(hid)
	for hid in recents.keys():
		if _jour - int(recents[hid][0]) > 15:
			recents.erase(hid)
	var parts: Array[String] = []
	for n in range(NIVEAUX.size() - 1, 0, -1):
		var k := int(_news.get("up%d" % n, 0))
		if k > 0:
			parts.append("%d foyer%s %s « %s »" % [k, "s" if k > 1 else "", "passent en" if k > 1 else "passe en", nom(n)])
	var dn := int(_news.get("down", 0))
	if dn > 0:
		parts.append("%d foyer%s %s" % [dn, "s" if dn > 1 else "", "s'appauvrissent" if dn > 1 else "s'appauvrit"])
	var dm := int(_news.get("demenage", 0))
	if dm > 0:
		parts.append("%d déménage%s pour un logement plus cossu" % [dm, "nt" if dm > 1 else ""])
	if not parts.is_empty():
		message.emit("Niveaux de vie : " + ", ".join(parts) + ".")
	_news.clear()
	changed.emit()


## Évalue tout de suite tous les foyers (tests, chargement), sans faire passer de jour.
func evaluer_tout() -> void:
	for hid in population.households:
		evaluer(int(hid), false)


## Fait passer un jour pour tous les foyers d'un coup (tests).
func jour_complet() -> void:
	_jour += 1
	for hid in population.households.keys():
		if population.households.has(hid):
			evaluer(int(hid), true)
	_fin_de_journee()


# --- Chiffres ---------------------------------------------------------------------------------

## {foyers: [par niveau], habitants: [par niveau], moyenne, bloques: {besoin: foyers},
##  montent, descendent, non_evalues}. filtre : Callable(bid) -> bool.
func bilan(filtre := Callable()) -> Dictionary:
	var foyers := []
	var hab := []
	for i in NIVEAUX.size():
		foyers.append(0)
		hab.append(0)
	var bloques := {}
	var montent := 0
	var descendent := 0
	var somme := 0.0
	var n := 0
	var non := 0
	for hid in population.households:
		var h: Dictionary = population.households[hid]
		if filtre.is_valid() and not filtre.call(int(h.b)):
			continue
		var nv := niveau(h)
		if nv < 0:
			non += 1
			continue
		foyers[nv] += 1
		hab[nv] += (h.m as Array).size()
		somme += nv
		n += 1
		var p := float(h.get("nvp", 0.0))
		if p > 0.0:
			montent += 1
		elif p < 0.0:
			descendent += 1
		for b in _manque_suivant.get(hid, []):
			bloques[b] = int(bloques.get(b, 0)) + 1
	return {"foyers": foyers, "habitants": hab, "moyenne": somme / n if n > 0 else 0.0, "bloques": bloques,
		"montent": montent, "descendent": descendent, "non_evalues": non, "total": n}


## Part des foyers au niveau n ou au-dessus (0..1).
func part_au_moins(n: int, filtre := Callable()) -> float:
	var b := bilan(filtre)
	if int(b.total) <= 0:
		return 0.0
	var k := 0
	for i in range(n, NIVEAUX.size()):
		k += int(b.foyers[i])
	return float(k) / int(b.total)


## Texte court pour la fiche d'un foyer.
func texte_foyer(hid: int) -> String:
	if not population.households.has(hid):
		return ""
	var h: Dictionary = population.households[hid]
	var nv := niveau(h)
	if nv < 0:
		return "Niveau de vie : pas encore évalué."
	var p := float(h.get("nvp", 0.0))
	var t := "Niveau de vie : %s" % nom(nv)
	if p > 0.0 and nv + 1 < NIVEAUX.size():
		t += " · monte vers « %s » (%d %%)" % [nom(nv + 1), roundi(100.0 * p)]
	elif p < 0.0:
		t += " · risque de redescendre (%d %%)" % roundi(-100.0 * p)
	return t


## Lignes « ce qui manque » pour la fiche d'un foyer.
func texte_manques(hid: int) -> String:
	var a: Array = _manque_actuel.get(hid, [])
	var s: Array = _manque_suivant.get(hid, [])
	var out: Array[String] = []
	if not a.is_empty():
		out.append("Manque pour garder son niveau : " + ", ".join(a.map(func(b) -> String: return nom_besoin(String(b)).to_lower())))
	if not s.is_empty():
		out.append("Pour monter : " + ", ".join(s.map(func(b) -> String: return nom_besoin(String(b)).to_lower())))
	return "\n".join(out)


# --- Avis des habitants -----------------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "niveau_vie", "theme": "logement", "f": _f_avis}]


func _f_avis(p: Dictionary) -> Array:
	if population == null or not population.households.has(int(p.f)):
		return [0.0, []]
	var hid := int(p.f)
	var h: Dictionary = population.households[hid]
	if niveau(h) < 0:
		return [0.0, []]
	if recents.has(hid) and int(recents[hid][1]) < 0:
		return [-8.0, ["− le foyer a perdu son niveau de vie"]]
	var prog := float(h.get("nvp", 0.0))
	if prog < 0.0:
		var a: Array = _manque_actuel.get(hid, [])
		return [-4.0, ["− le foyer s'appauvrit%s" % ((" : " + nom_besoin(String(a[0])).to_lower()) if not a.is_empty() else "")]]
	if recents.has(hid) or prog > 0.0:
		return [3.0, ["+ le foyer vit de mieux en mieux"]]
	return [0.0, []]


# --- Sauvegarde --------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var f := {}
	for hid in population.households:
		var h: Dictionary = population.households[hid]
		if niveau(h) >= 0:
			f[str(hid)] = [int(h.nv), snappedf(float(h.get("nvp", 0.0)), 0.001)]
	return {"version": 1, "foyers": f, "totaux": totaux, "jour": _jour}


func from_dict(d: Dictionary) -> void:
	clear()
	var f: Dictionary = d.get("foyers", {})
	for k in f:
		var hid := int(k)
		if not population.households.has(hid):
			continue
		var e: Array = f[k]
		population.households[hid].nv = clampi(int(e[0]), 0, NIVEAUX.size() - 1)
		population.households[hid].nvp = clampf(float(e[1]), -1.0, 1.0) if e.size() > 1 else 0.0
	var t: Dictionary = d.get("totaux", {})
	for k in totaux:
		totaux[k] = int(t.get(k, 0))
	_jour = int(d.get("jour", 0))
	# Ancienne partie : les foyers seront évalués au prochain passage (niveau d'arrivée).
	changed.emit()
