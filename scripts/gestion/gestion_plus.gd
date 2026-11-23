class_name GestionPlus
extends RefCounted
## Mode gestion « tycoon », deuxième lot de ce qu'offrent les jeux du marché,
## pour tous les genres (voir aussi GestionEssor) :
## - l'équipe en personnes : chacun son trait (rapide, aimable, soigneux…),
##   son moral et sa fatigue ; pauses réglables, demandes d'augmentation,
##   employé du mois, démissions quand le moral reste trop bas ;
## - le prix de chaque service (spa, bar, boutique…) en plus du prix principal ;
## - les types de clients (familles, affaires, touristes…) : leur part change
##   avec la saison, chacun a ses pièces préférées et sa sensibilité au prix ;
## - le prêt de la banque (entreprises) : argent tout de suite, remboursé
##   chaque jour avec intérêts selon l'époque ;
## - les trophées : gagnés par les défis, la recherche, la publicité, les avis,
##   la première place… exposés devant l'établissement ;
## - l'agrandissement : deux extensions qui donnent un niveau de plus à
##   chaque pièce.
## Tout tient dans st.essor (GestionEssor.vide), lu par GestionEssor.bonus,
## ajuster_charges, facteur_pannes, points_jour et journee.

const EQUIPE_MAX := 30
const PAUSES := ["Courtes", "Normales", "Longues"]
const EXT_MAX := 2
const PRET_JOURS := 120
const TARIF_MIN := 0.6
const TARIF_MAX := 1.6

const TRAITS := {
	"rapide": {"nom": "Rapide", "effets": {"vitesse": 0.06}, "desc": "fait tout plus vite"},
	"aimable": {"nom": "Aimable", "effets": {"satisf": 0.03}, "desc": "les clients l'adorent"},
	"soigneux": {"nom": "Soigneux", "effets": {"pannes": 0.06}, "desc": "casse moins de choses"},
	"endurant": {"nom": "Endurant", "effets": {}, "desc": "se fatigue deux fois moins"},
	"creatif": {"nom": "Créatif", "effets": {"points": 0.12}, "desc": "fait avancer la recherche"},
	"ambitieux": {"nom": "Ambitieux", "effets": {"vitesse": 0.03}, "desc": "travaille dur, demande des augmentations"},
	"maladroit": {"nom": "Maladroit", "effets": {"pannes": -0.06}, "desc": "casse plus souvent"},
	"raleur": {"nom": "Râleur", "effets": {"satisf": -0.01}, "desc": "son moral baisse plus vite"},
}
const TRAITS_POIDS := {"rapide": 3, "aimable": 3, "soigneux": 2, "endurant": 2, "creatif": 2, "ambitieux": 2, "maladroit": 1, "raleur": 1}

## Types de clients : "mots" (pièces aimées : morceaux d'identifiant),
## "prix" (sensibilité au prix : 0 s'en moque, 2 très sensible),
## "saison" (part par mois, 1 à 12 : facteur), "part" de base.
const SEGMENTS := [
	{"id": "familles", "nom": "Familles", "part": 0.25, "prix": 1.4, "mots": ["jardin", "piscine", "enfant", "terrasse", "glace", "aire", "pique", "potager", "aquatique", "petits"],
		"ete": 1.6, "hiver": 0.7},
	{"id": "affaires", "nom": "Gens d'affaires", "part": 0.2, "prix": 0.4, "mots": ["conference", "bureau", "salon", "parking", "bar", "direction", "accueil", "reception"],
		"ete": 0.6, "hiver": 1.2},
	{"id": "touristes", "nom": "Touristes", "part": 0.25, "prix": 1.0, "mots": ["boutique", "spa", "restaurant", "cave", "the", "patisserie", "souvenir", "salle"],
		"ete": 1.4, "hiver": 0.8},
	{"id": "jeunes", "nom": "Jeunes", "part": 0.15, "prix": 1.8, "mots": ["bar", "sport", "terrasse", "frissons", "attraction"],
		"ete": 1.2, "hiver": 1.0},
	{"id": "seniors", "nom": "Seniors", "part": 0.15, "prix": 0.9, "mots": ["chambres", "jardin", "spa", "salle", "toilettes", "accueil"],
		"ete": 0.9, "hiver": 1.1},
]
const SEGMENTS_VILLE := [
	{"id": "ecoles", "nom": "Écoles et enfants", "part": 0.3, "prix": 0.0, "mots": ["formation", "cour", "parvis", "jardin", "chenil", "consultation"], "ete": 0.5, "hiver": 1.2},
	{"id": "actifs", "nom": "Actifs et entreprises", "part": 0.4, "prix": 0.0, "mots": ["garage", "remise", "alerte", "commandement", "regulation", "plaintes", "urgence"], "ete": 1.0, "hiver": 1.0},
	{"id": "aines", "nom": "Personnes âgées", "part": 0.3, "prix": 0.0, "mots": ["accueil", "chambres", "consultation", "pharmacie", "garde"], "ete": 1.0, "hiver": 1.4},
]

## Trophées : "cond" (lue par _merite), "effets", "couleur" (exposition).
const TROPHEES := [
	{"id": "defi_1", "nom": "Coupe du premier défi", "cond": "defis", "n": 1, "effets": {"satisf": 0.01}, "couleur": "b0703a"},
	{"id": "defi_3", "nom": "Coupe d'argent (3 défis)", "cond": "defis", "n": 3, "effets": {"satisf": 0.01, "attrait": 0.01}, "couleur": "c9ced6"},
	{"id": "defi_10", "nom": "Coupe d'or (10 défis)", "cond": "defis", "n": 10, "effets": {"satisf": 0.02, "attrait": 0.02}, "couleur": "e8c040"},
	{"id": "chercheur", "nom": "Diplôme de l'innovation (4 recherches)", "cond": "recherches", "n": 4, "effets": {"confort": 0.03}, "couleur": "f2ead8"},
	{"id": "savant", "nom": "Statue du savoir (toute la recherche)", "cond": "recherches", "n": 8, "effets": {"confort": 0.05}, "couleur": "9aa6b4"},
	{"id": "pub", "nom": "Affiche d'or (5 campagnes)", "cond": "campagnes", "n": 5, "effets": {"attrait": 0.02}, "couleur": "e07040"},
	{"id": "avis", "nom": "Plaque « Adoré des clients » (avis 4,5 / 5)", "cond": "avis", "n": 8, "effets": {"attrait": 0.02, "satisf": 0.01}, "couleur": "5fb36b"},
	{"id": "premier", "nom": "Trophée du meilleur de la ville", "cond": "premier", "n": 2, "effets": {"attrait": 0.03}, "couleur": "e8c040"},
	{"id": "equipe", "nom": "Plaque de l'équipe soudée (moral 4 pendant 15 jours)", "cond": "moral", "n": 15, "effets": {"vitesse": 0.05}, "couleur": "4f8fd8"},
	{"id": "agrandi", "nom": "Ruban de l'inauguration (agrandissement)", "cond": "ext", "n": 1, "effets": {"attrait": 0.01}, "couleur": "d84848"},
]


static func _ville(g: Gestion, bid: int) -> bool:
	return g.source(bid) == "ville"


static func _e(g: Gestion, bid: int) -> Dictionary:
	if not g.etats.has(bid):
		return {}
	return GestionEssor.es(g.etats[bid])


# --- L'équipe --------------------------------------------------------------------------------------

## Effectif suivi : les emplois du bâtiment (au moins 2, au plus 30).
static func effectif(g: Gestion, bid: int) -> int:
	return clampi(g.emplois_de(bid), 2, EQUIPE_MAX)


static func _tirer_trait(g: Gestion) -> String:
	var tot := 0
	for k in TRAITS_POIDS:
		tot += int(TRAITS_POIDS[k])
	var x := g.rng.randi() % tot
	for k in TRAITS_POIDS:
		x -= int(TRAITS_POIDS[k])
		if x < 0:
			return String(k)
	return "rapide"


static func _recrue(g: Gestion) -> Dictionary:
	var p := String(GestionEssor.PRENOMS[g.rng.randi() % GestionEssor.PRENOMS.size()])
	return {"nom": "%s %s." % [p, "ABCDEFGHJKLMNPRSTV"[g.rng.randi() % 18]], "trait": _tirer_trait(g), "moral": 3.2, "fatigue": 10.0, "bas": 0, "aug": 0.0, "mois": -1}


## L'équipe, mise à la taille du bâtiment.
static func equipe(g: Gestion, bid: int) -> Array:
	var e := _e(g, bid)
	if e.is_empty():
		return []
	var l: Array = e.equipe
	var n := effectif(g, bid)
	while l.size() < n:
		l.append(_recrue(g))
	while l.size() > n:
		l.pop_back()
	return l


static func moral_moyen(g: Gestion, bid: int) -> float:
	var l := equipe(g, bid)
	if l.is_empty():
		return 3.0
	var s := 0.0
	for p in l:
		s += float(p.moral)
	return s / float(l.size())


static func fatigue_moyenne(g: Gestion, bid: int) -> float:
	var l := equipe(g, bid)
	if l.is_empty():
		return 0.0
	var s := 0.0
	for p in l:
		s += float(p.fatigue)
	return s / float(l.size())


## Pièce où l'équipe se repose (salle de repos, vestiaires, chambres de garde…).
static func niveau_repos(g: Gestion, bid: int) -> int:
	var best := 0
	for pid in GestionTypes.ordre(g.genre_of(bid)):
		var s := String(pid)
		for m in ["repos", "pause", "vestiaire", "garde", "lingerie"]:
			if s.contains(m):
				best = maxi(best, g.niveau(bid, s))
	return best


## Ce que l'équipe ajoute à une clé : traits (pondérés par le moral), moral
## et fatigue moyens, pauses.
static func bonus_equipe(g: Gestion, bid: int, cle: String) -> float:
	var l := equipe(g, bid)
	if l.is_empty():
		return 0.0
	var s := 0.0
	for p in l:
		var t: Dictionary = TRAITS.get(String(p.trait), {})
		s += float((t.get("effets", {}) as Dictionary).get(cle, 0.0)) * clampf(float(p.moral) / 3.0, 0.3, 1.3)
	s = s / float(l.size()) * 3.0
	var m := moral_moyen(g, bid) - 3.0
	var f := fatigue_moyenne(g, bid) / 100.0
	match cle:
		"satisf":
			s += m * 0.03 - f * 0.06
		"vitesse":
			s += m * 0.04 - f * 0.15 - [0.0, 0.03, 0.07][clampi(int(_e(g, bid).pauses), 0, 2)]
	return s


static func _journee_equipe(g: Gestion, bid: int, st: Dictionary) -> void:
	var e := GestionEssor.es(st)
	var l := equipe(g, bid)
	var occ := g.occupation(bid) if g.source(bid) != "ville" else 0.7
	var repos := 4.0 + 2.5 * float(niveau_repos(g, bid)) + 3.0 * float(int(e.pauses))
	var partis: Array = []
	for i in l.size():
		var p: Dictionary = l[i]
		var t := String(p.trait)
		var dur := (3.0 + 9.0 * occ) * (0.5 if t == "endurant" else 1.0)
		p.fatigue = clampf(float(p.fatigue) + dur - repos, 0.0, 100.0)
		var cible := 3.0 + (float(st.salaire) - 1.0) * 4.0 + float(p.aug) * 6.0 + 0.15 * float(st.formation) - float(p.fatigue) / 45.0 \
			- (0.6 if t == "raleur" else 0.0) - 0.15 * float((st.pannes as Array).size()) + (1.0 if int(p.mois) >= g.jour else 0.0)
		p.moral = clampf(float(p.moral) + (cible - float(p.moral)) * 0.2, 0.0, 5.0)
		p.bas = int(p.bas) + 1 if float(p.moral) < 1.3 else 0
		if int(p.bas) >= 7:
			partis.append(i)
	for k in range(partis.size() - 1, -1, -1):
		var p: Dictionary = l[int(partis[k])]
		g._noter(bid, "%s (%s) démissionne : moral trop bas. Une nouvelle recrue arrive." % [String(p.nom), String(TRAITS[String(p.trait)].nom).to_lower()], true)
		e.demissions = int(e.demissions) + 1
		l[int(partis[k])] = _recrue(g)
	# Demande d'augmentation.
	if (e.demande as Dictionary).is_empty() and g.rng.randf() < 0.04:
		var cands: Array = []
		for i in l.size():
			if String(l[i].trait) == "ambitieux" or float(l[i].moral) < 2.6:
				cands.append(i)
		if not cands.is_empty():
			var i: int = cands[g.rng.randi() % cands.size()]
			e.demande = {"i": i, "jour": g.jour}
			g._noter(bid, "%s demande une augmentation de 10 %%." % String(l[i].nom))
	elif not (e.demande as Dictionary).is_empty():
		if bool(st.auto):
			repondre_augmentation(g, bid, g.compte(bid) > prix_augmentation(g, bid) * 60.0)
		elif g.jour - int(e.demande.jour) > 7:
			repondre_augmentation(g, bid, false)
	# Plaque de l'équipe soudée.
	e.moral_bon = int(e.moral_bon) + 1 if moral_moyen(g, bid) >= 4.0 else 0


## Coût par jour d'une augmentation de 10 % pour une personne.
static func prix_augmentation(g: Gestion, _bid: int) -> float:
	return Tourisme.SALAIRE_MOYEN * ReglagesPartie.actuel.salaires / 30.44 * 0.1


static func repondre_augmentation(g: Gestion, bid: int, oui: bool) -> void:
	var e := _e(g, bid)
	if e.is_empty() or (e.demande as Dictionary).is_empty():
		return
	var l := equipe(g, bid)
	var i := int(e.demande.i)
	e.demande = {}
	if i < 0 or i >= l.size():
		return
	var p: Dictionary = l[i]
	if oui:
		p.aug = float(p.aug) + 0.1
		p.moral = minf(5.0, float(p.moral) + 1.2)
		g._noter(bid, "Augmentation accordée à %s." % String(p.nom))
	else:
		p.moral = maxf(0.0, float(p.moral) - 1.0)
		g._noter(bid, "Augmentation refusée à %s, qui le prend mal." % String(p.nom))


## Prime de l'employé du mois.
static func prix_prime(g: Gestion, _bid: int) -> int:
	return roundi(Tourisme.SALAIRE_MOYEN * ReglagesPartie.actuel.salaires * 0.5 / 10.0) * 10


static func employe_du_mois(g: Gestion, bid: int, i: int) -> Dictionary:
	var e := _e(g, bid)
	if e.is_empty():
		return {"ok": false, "error": "pas d'établissement"}
	if int(e.mois_fin) > g.jour:
		return {"ok": false, "error": "déjà élu ce mois-ci (encore %d jours)" % (int(e.mois_fin) - g.jour)}
	var l := equipe(g, bid)
	if i < 0 or i >= l.size():
		return {"ok": false, "error": "personne"}
	var r := g._payer(bid, prix_prime(g, bid))
	if not bool(r.ok):
		return r
	var p: Dictionary = l[i]
	p.mois = g.jour + 30
	p.moral = minf(5.0, float(p.moral) + 1.5)
	for q in l:
		q.moral = minf(5.0, float(q.moral) + 0.3)
	e.mois_fin = g.jour + 30
	g._noter(bid, "%s est l'employé du mois : prime de %s, toute l'équipe applaudit." % [String(p.nom), BuildingSystem.format_money(prix_prime(g, bid))])
	return {"ok": true}


static func set_pauses(g: Gestion, bid: int, n: int) -> void:
	var e := _e(g, bid)
	if not e.is_empty():
		e.pauses = clampi(n, 0, 2)


# --- Prix de chaque service ------------------------------------------------------------------------

## Services à prix : les pièces construites qui font dépenser les clients.
static func services(g: Gestion, bid: int) -> Array:
	var out: Array = []
	if _ville(g, bid):
		return out
	var gn := g.genre_of(bid)
	for pid in GestionTypes.ordre(gn):
		var p := GestionTypes.piece(gn, String(pid))
		if g.niveau(bid, String(pid)) > 0 and float((p.get("effets", {}) as Dictionary).get("ventes", 0.0)) > 0.0:
			out.append(String(pid))
	return out


static func tarif(g: Gestion, bid: int, pid: String) -> float:
	var e := _e(g, bid)
	return float((e.get("tarifs", {}) as Dictionary).get(pid, 1.0)) if not e.is_empty() else 1.0


static func changer_tarif(g: Gestion, bid: int, pid: String, sens: int) -> void:
	var e := GestionEssor.es(g.etat(bid))
	e.tarifs[pid] = snappedf(clampf(tarif(g, bid, pid) + 0.1 * float(sens), TARIF_MIN, TARIF_MAX), 0.01)
	g._sur_changement(bid)


## Dépenses des clients que rapporte un service (niveaux et objets de la pièce).
static func ventes_piece(g: Gestion, bid: int, pid: String) -> float:
	var gn := g.genre_of(bid)
	var s := float((GestionTypes.piece(gn, pid).get("effets", {}) as Dictionary).get("ventes", 0.0)) * maxi(1, g.gagnes(bid, pid))
	for oid in g.objets_de(bid, pid):
		s += float((GestionTypes.objet(gn, pid, String(oid)).get("effets", {}) as Dictionary).get("ventes", 0.0))
	return s


static func bonus_tarifs(g: Gestion, bid: int, cle: String) -> float:
	if not (cle in ["ventes", "satisf", "attrait"]):
		return 0.0
	var s := 0.0
	for pid in services(g, bid):
		var f := tarif(g, bid, String(pid))
		match cle:
			"ventes":
				# Plus cher : chaque client dépense plus, mais un peu moins de clients en profitent.
				s += ventes_piece(g, bid, String(pid)) * ((f - 1.0) - 0.35 * maxf(0.0, f - 1.0) * (f - 1.0) * 2.0)
			"satisf":
				s += -maxf(0.0, f - 1.0) * 0.06 + maxf(0.0, 1.0 - f) * 0.04
			"attrait":
				s += (1.0 - f) * 0.015
	return s


# --- Types de clients ------------------------------------------------------------------------------

static func segments(g: Gestion, bid: int) -> Array:
	return SEGMENTS_VILLE if _ville(g, bid) else SEGMENTS


## Prix principal par rapport à l'habitude (1 : normal).
static func facteur_prix(g: Gestion, bid: int) -> float:
	if _ville(g, bid) or not g.etats.has(bid):
		return 1.0
	var st: Dictionary = g.etats[bid]
	if g.source(bid) == "tourisme" and g.tourisme != null and g.tourisme.heb.has(bid):
		return float(g.tourisme.heb[bid].prix) / maxf(1.0, float(g.spec_base(bid).get("prix", g.tourisme.heb[bid].prix)))
	return float(st.get("prix", 1.0))


static func _saison(month: int) -> String:
	if month in [6, 7, 8]:
		return "ete"
	if month in [12, 1, 2]:
		return "hiver"
	return ""


## Part de chaque type de clients ce mois-ci : {id: part}.
static func parts(g: Gestion, bid: int, month: int) -> Dictionary:
	var out := {}
	var tot := 0.0
	var sa := _saison(month)
	for sg in segments(g, bid):
		var v := float(sg.part) * (float(sg.get(sa, 1.0)) if sa != "" else 1.0)
		out[String(sg.id)] = v
		tot += v
	for k in out:
		out[k] = float(out[k]) / maxf(0.001, tot)
	return out


## Ce qu'un type de clients pense de l'établissement (0 : rien pour lui, 1 : parfait)
## et les pièces qu'il aime : {fit, aime: [pid], manque: [pid]}.
static func avis_segment(g: Gestion, bid: int, sg: Dictionary) -> Dictionary:
	var gn := g.genre_of(bid)
	var aime: Array = []
	var manque: Array = []
	var s := 0.0
	var n := 0
	for pid in GestionTypes.ordre(gn):
		var id := String(pid)
		var ok := false
		for m in sg.mots:
			ok = ok or id.contains(String(m))
		if not ok:
			continue
		n += 1
		var niv := g.niveau(bid, id)
		s += float(niv) / float(maxi(1, g.niveau_max(bid, id)))
		if niv >= 3:
			aime.append(id)
		elif niv == 0:
			manque.append(id)
	var fit := (s / float(n)) if n > 0 else 0.4
	if float(sg.prix) > 0.0:
		fit -= (facteur_prix(g, bid) - 1.0) * 0.35 * float(sg.prix)
	return {"fit": clampf(fit, 0.0, 1.0), "aime": aime, "manque": manque}


## Mois courant connu de la gestion (posé chaque jour par journee).
static func mois(g: Gestion, bid: int) -> int:
	var e := _e(g, bid)
	return int(e.get("mois", 6)) if not e.is_empty() else 6


static func bonus_segments(g: Gestion, bid: int, cle: String) -> float:
	if not (cle in ["satisf", "attrait"]):
		return 0.0
	if cle == "attrait" and _ville(g, bid):
		return 0.0
	var pa := parts(g, bid, mois(g, bid))
	var s := 0.0
	for sg in segments(g, bid):
		var f := float(avis_segment(g, bid, sg).fit)
		s += float(pa.get(String(sg.id), 0.0)) * (f - 0.4) * (0.10 if cle == "satisf" else 0.08)
	return s


# --- Prêt de la banque -----------------------------------------------------------------------------

## Taux d'intérêt annuel selon l'année de la partie.
static func taux(annee: int) -> float:
	if annee < 1900:
		return 0.05
	if annee < 1970:
		return 0.045
	if annee < 1995:
		return 0.09
	if annee < 2015:
		return 0.045
	return 0.035


static func offres_pret(g: Gestion, bid: int) -> Array:
	var out: Array = []
	if _ville(g, bid):
		return out
	for f in [0.02, 0.05, 0.10]:
		var m := maxi(5000, int(roundf(g.cout_batiment(bid) * float(f) / 1000.0)) * 1000)
		var t := taux(EpoquesObjets.annee_partie())
		var tot := float(m) * (1.0 + t * float(PRET_JOURS) / 365.0)
		out.append({"montant": m, "taux": t, "jour": tot / float(PRET_JOURS), "total": tot})
	return out


static func pret(g: Gestion, bid: int) -> Dictionary:
	var e := _e(g, bid)
	return e.get("pret", {}) if not e.is_empty() else {}


static func emprunter(g: Gestion, bid: int, i: int) -> Dictionary:
	if _ville(g, bid):
		return {"ok": false, "error": "un service public est payé par la ville"}
	if not pret(g, bid).is_empty():
		return {"ok": false, "error": "un prêt est déjà en cours"}
	var o := offres_pret(g, bid)
	if i < 0 or i >= o.size():
		return {"ok": false, "error": "offre inconnue"}
	var e := GestionEssor.es(g.etat(bid))
	var of: Dictionary = o[i]
	e.pret = {"montant": int(of.montant), "reste": float(of.total), "jour": float(of.jour), "taux": float(of.taux), "debut": g.jour}
	g._crediter(bid, float(of.montant))
	g._noter(bid, "Prêt de la banque : %s à %.1f %%, remboursé %s par jour pendant %d jours." % [BuildingSystem.format_money(int(of.montant)), float(of.taux) * 100.0,
		BuildingSystem.format_money(int(of.jour)), PRET_JOURS], true)
	return {"ok": true}


static func rembourser_pret(g: Gestion, bid: int) -> Dictionary:
	var p := pret(g, bid)
	if p.is_empty():
		return {"ok": false, "error": "pas de prêt"}
	# Remboursement anticipé : sans les intérêts qui restaient à courir.
	var du := int(ceilf(float(p.reste) / (1.0 + float(p.taux) * float(PRET_JOURS) / 365.0)))
	if g.compte(bid) < float(du) and not g.buildings.unlimited_money:
		return {"ok": false, "error": "il faut %s sur le compte" % BuildingSystem.format_money(du)}
	if not g.buildings.unlimited_money:
		g._crediter(bid, -float(du))
	_e(g, bid).pret = {}
	g._noter(bid, "Prêt remboursé d'un coup (%s)." % BuildingSystem.format_money(du))
	return {"ok": true, "du": du}


static func _journee_pret(g: Gestion, bid: int, e: Dictionary) -> void:
	var p: Dictionary = e.get("pret", {})
	if p.is_empty():
		return
	p.reste = float(p.reste) - float(p.jour)
	if float(p.reste) <= 0.5:
		e.pret = {}
		g._noter(bid, "Dernière échéance payée : le prêt est remboursé.")


# --- Trophées --------------------------------------------------------------------------------------

static func _merite(g: Gestion, bid: int, e: Dictionary, t: Dictionary) -> bool:
	var n := int(t.n)
	match String(t.cond):
		"defis":
			return int(e.defis_ok) >= n
		"recherches":
			return (e.faits as Array).size() >= mini(n, GestionEssor.RECHERCHES.size())
		"campagnes":
			return int(e.camps) >= n
		"avis":
			return (e.avis as Array).size() >= n and GestionEssor.moyenne_avis(g.etats[bid]) >= 4.5
		"premier":
			var r := GestionEssor.rang(g, bid)
			return r.y >= n and r.x == 1
		"moral":
			return int(e.moral_bon) >= n
		"ext":
			return int(e.ext) >= n
	return false


static func trophee(id: String) -> Dictionary:
	for t in TROPHEES:
		if String(t.id) == id:
			return t
	return {}


static func trophees(g: Gestion, bid: int) -> Array:
	var e := _e(g, bid)
	return e.trophees if not e.is_empty() else []


static func _journee_trophees(g: Gestion, bid: int, e: Dictionary) -> void:
	for t in TROPHEES:
		if String(t.id) in (e.trophees as Array):
			continue
		if _merite(g, bid, e, t):
			(e.trophees as Array).append(String(t.id))
			g._noter(bid, "Nouveau trophée : %s ! Il est exposé devant l'entrée." % String(t.nom), true)


static func bonus_trophees(g: Gestion, bid: int, cle: String) -> float:
	var s := 0.0
	for id in trophees(g, bid):
		var t := trophee(String(id))
		var v := float((t.get("effets", {}) as Dictionary).get(cle, 0.0))
		if cle == "attrait" and _ville(g, bid):
			v = 0.0
		s += v
	return s


# --- Agrandissement --------------------------------------------------------------------------------

static func extensions(g: Gestion, bid: int) -> int:
	var e := _e(g, bid)
	return int(e.get("ext", 0)) if not e.is_empty() else 0


static func prix_extension(g: Gestion, bid: int) -> int:
	if extensions(g, bid) >= EXT_MAX:
		return 0
	return maxi(20_000, int(roundf(g.cout_batiment(bid) * 0.12 * float(extensions(g, bid) + 1) / 1000.0)) * 1000)


static func agrandir(g: Gestion, bid: int, sans_ville := false) -> Dictionary:
	var px := prix_extension(g, bid)
	if px <= 0:
		return {"ok": false, "error": "déjà agrandi au maximum"}
	var r := g._payer(bid, px, sans_ville)
	if not bool(r.ok):
		return r
	var e := GestionEssor.es(g.etat(bid))
	e.ext = int(e.ext) + 1
	g._noter(bid, "Agrandissement n° %d inauguré : chaque pièce peut monter d'un niveau de plus." % int(e.ext), true)
	g._sur_changement(bid)
	return r


# --- Pour GestionEssor ------------------------------------------------------------------------------

static func bonus(g: Gestion, bid: int, cle: String) -> float:
	var s := bonus_equipe(g, bid, cle) + bonus_tarifs(g, bid, cle) + bonus_segments(g, bid, cle) + bonus_trophees(g, bid, cle)
	if cle == "confort":
		s += 0.05 * float(extensions(g, bid))
	return s


## Charges en plus par jour : augmentations, prêt.
static func charges(g: Gestion, bid: int) -> float:
	var s := 0.0
	var un := prix_augmentation(g, bid) * 10.0
	for p in equipe(g, bid):
		s += float(p.aug) * un
	var pr := pret(g, bid)
	if not pr.is_empty():
		s += float(pr.jour)
	return s


## Facteur des pannes venu de l'équipe (soigneux, maladroits).
static func facteur_pannes(g: Gestion, bid: int) -> float:
	var l := equipe(g, bid)
	if l.is_empty():
		return 1.0
	var s := 0.0
	for p in l:
		s += float((TRAITS.get(String(p.trait), {}).get("effets", {}) as Dictionary).get("pannes", 0.0))
	return clampf(1.0 - s / float(l.size()) * 3.0, 0.6, 1.4)


static func points(g: Gestion, bid: int) -> float:
	return bonus_equipe(g, bid, "points")


static func journee(g: Gestion, bid: int, st: Dictionary, month: int) -> void:
	var e := GestionEssor.es(st)
	e.mois = month
	_journee_equipe(g, bid, st)
	_journee_pret(g, bid, e)
	_journee_trophees(g, bid, e)
