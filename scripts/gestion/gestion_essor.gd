class_name GestionEssor
extends RefCounted
## Mode gestion « tycoon » : ce qui fait grandir un établissement, pour tous
## les genres (hôtel, restaurant, caserne, commissariat, hôpital… et ceux qui
## viendront). Inspiré de ce qu'offrent les jeux de gestion du marché (sans
## les copier) :
## - la recherche : un projet à la fois, des points gagnés chaque jour par
##   l'équipe (formation, pièces) ; chaque projet fini donne un bonus durable ;
## - les campagnes : publicité (affiches, journal, radio, télé, internet…
##   selon l'année de la partie) pour les entreprises, journée portes
##   ouvertes, recrutement ou prévention pour les services publics. Payées
##   chaque jour tant qu'elles durent ; refaire la même trop tôt lasse le
##   public (moitié d'effet) ;
## - les défis : un défi proposé de temps en temps (« Régler 5 demandes en
##   7 jours »), à accepter, avec une prime et un bonus de 30 jours ;
## - les paliers : des caps (pièce au maximum, 10/25/50 objets, défis
##   réussis, toute la recherche) qui donnent un petit bonus permanent ;
## - les avis : ce que les clients (ou les habitants) écrivent, avec leurs
##   étoiles, et ce qui leur plaît ou les fâche ;
## - les concurrents : le classement des établissements du même genre.
##
## Tout tient dans st.essor (sauvegardé avec la section « gestion »). Les
## bonus passent par Gestion.effet() (GestionEssor.bonus), les dépenses par
## Gestion.entretien_jour() (GestionEssor.ajuster_charges), les pannes par
## GestionEssor.facteur_pannes et la journée par GestionEssor.journee.

const AVIS_MAX := 12
const DEFI_TOUS_LES := 12
const DEFI_ATTENTE := 5
const BONUS_DEFI_JOURS := 30
const LASSITUDE_JOURS := 30

## Projets de recherche : "cout" en points, "effets" (clés de GestionTypes.EFFETS
## plus "pannes" : pannes en moins, "economie" : charges en moins, "points" :
## recherche plus rapide), "ville" : effets à la place pour un service public.
const RECHERCHES := [
	{"id": "methodes", "nom": "Méthodes de travail", "cout": 10.0, "effets": {"vitesse": 0.15},
		"desc": "Qui fait quoi, dans quel ordre : l'équipe perd moins de temps."},
	{"id": "qualite", "nom": "Démarche qualité", "cout": 14.0, "effets": {"satisf": 0.04},
		"desc": "Fiches de contrôle et petits gestes : les clients le sentent.",
		"desc_ville": "Fiches de contrôle et petits gestes : les habitants et l'équipe le sentent."},
	{"id": "maintenance", "nom": "Maintenance préventive", "cout": 18.0, "effets": {"pannes": 0.3}, "apres": "methodes",
		"desc": "On change les pièces avant qu'elles cassent : 30 % de pannes en moins."},
	{"id": "achats", "nom": "Achats groupés", "cout": 22.0, "effets": {"economie": 0.1}, "apres": "methodes",
		"desc": "Fournisseurs mis en concurrence : 10 % de charges en moins."},
	{"id": "ambiance", "nom": "Design et ambiance", "cout": 26.0, "effets": {"confort": 0.15}, "apres": "qualite",
		"desc": "Lumières, musique, couleurs : tout paraît plus beau."},
	{"id": "fidelite", "nom": "Fidélisation", "cout": 30.0, "effets": {"attrait": 0.05}, "ville": {"equipage": 1.0}, "apres": "qualite",
		"desc": "Carte de fidélité et bouche-à-oreille : les clients reviennent.",
		"desc_ville": "Réseau d'anciens et de volontaires : une personne de garde en plus."},
	{"id": "innovation", "nom": "Atelier d'idées", "cout": 34.0, "effets": {"points": 0.5, "ventes": 1.0}, "ville": {"points": 0.5, "vitesse": 0.1}, "apres": "achats",
		"desc": "L'équipe propose ses idées : nouvelles offres, recherche plus rapide.",
		"desc_ville": "L'équipe propose ses idées : protocoles plus rapides, recherche plus rapide."},
	{"id": "excellence", "nom": "Excellence", "cout": 50.0, "effets": {"confort": 0.25, "satisf": 0.04}, "apres": "tout",
		"desc": "Le sommet du métier : tout le monde en parle."},
]

## Campagnes : "annee" (première année possible), "cout" (part du prix du
## bâtiment par jour), "jours", "effets".
const CAMPAGNES := [
	{"id": "affiches", "nom": "Affiches en ville", "annee": 0, "cout": 0.00012, "jours": 14, "effets": {"attrait": 0.04}},
	{"id": "journal", "nom": "Annonce dans le journal", "annee": 1830, "cout": 0.00018, "jours": 14, "effets": {"attrait": 0.06}},
	{"id": "radio", "nom": "Spot à la radio", "annee": 1925, "cout": 0.00030, "jours": 14, "effets": {"attrait": 0.08}},
	{"id": "tele", "nom": "Publicité à la télé", "annee": 1955, "cout": 0.00060, "jours": 10, "effets": {"attrait": 0.13}},
	{"id": "internet", "nom": "Site et avis en ligne", "annee": 1998, "cout": 0.00025, "jours": 21, "effets": {"attrait": 0.08, "satisf": 0.01}},
	{"id": "reseaux", "nom": "Influenceurs et réseaux sociaux", "annee": 2010, "cout": 0.00045, "jours": 10, "effets": {"attrait": 0.14}},
	{"id": "fete", "nom": "Journée découverte (prix cassés)", "annee": 0, "cout": 0.00040, "jours": 3, "effets": {"attrait": 0.12, "satisf": 0.06}},
]

const CAMPAGNES_VILLE := [
	{"id": "portes", "nom": "Journée portes ouvertes", "annee": 0, "cout": 0.00020, "jours": 7, "effets": {"satisf": 0.06, "equipage": 1.0}},
	{"id": "recrutement", "nom": "Campagne de recrutement", "annee": 0, "cout": 0.00035, "jours": 21, "effets": {"equipage": 2.0}},
	{"id": "prevention", "nom": "Prévention dans les écoles", "annee": 0, "cout": 0.00015, "jours": 14, "effets": {"satisf": 0.08}},
	{"id": "affiches", "nom": "Affiches et dépliants", "annee": 0, "cout": 0.00010, "jours": 14, "effets": {"satisf": 0.04}},
	{"id": "medias", "nom": "Reportage à la radio et à la télé", "annee": 1930, "cout": 0.00030, "jours": 10, "effets": {"satisf": 0.06, "equipage": 1.0}},
]

## Défis : "mesure" (ce qui est compté), "n", "jours".
const DEFIS := [
	{"id": "demandes", "mesure": "reglees", "n": 5, "jours": 7, "texte": "Régler %d demandes en %d jours", "texte_ville": "Répondre à %d visiteurs en %d jours"},
	{"id": "objets", "mesure": "objets", "n": 3, "jours": 10, "texte": "Installer %d objets en %d jours"},
	{"id": "ameliorations", "mesure": "niveaux", "n": 2, "jours": 12, "texte": "Faire %d améliorations en %d jours"},
	{"id": "pannes", "mesure": "sans_panne", "n": 10, "jours": 10, "texte": "Aucune panne pendant %d jours (sur %d)"},
	{"id": "note", "mesure": "note", "n": 0, "jours": 15, "texte": "Monter la note à %.1f en %d jours"},
	{"id": "recettes", "mesure": "recettes", "n": 0, "jours": 7, "texte": "Encaisser %s en %d jours", "prive": true},
	{"id": "interventions", "mesure": "interventions", "n": 8, "jours": 10, "texte": "Faire %d interventions en %d jours", "public": true},
]

const PRENOMS := ["Léa", "Hugo", "Chloé", "Lucas", "Emma", "Nathan", "Inès", "Louis", "Manon", "Jules", "Sarah", "Gabriel", "Camille", "Noah",
	"Zoé", "Adam", "Julie", "Paul", "Alice", "Tom", "Yasmine", "Marco", "Aïcha", "Kenji", "Olga", "Pedro", "Nadia", "Sven"]


# --- État -----------------------------------------------------------------------------------------

static func vide() -> Dictionary:
	return {"pts": 0.0, "rech": "", "faits": [], "camp": {}, "dernieres": {}, "camps": 0, "defi": {}, "defi_prochain": 3,
		"defis_ok": 0, "defis_rates": 0, "bonus_fin": -1, "paliers": [], "avis": [], "cumul": 0.0,
		# GestionPlus : équipe, pauses, augmentation demandée, prix des services, prêt, trophées, agrandissements.
		"equipe": [], "pauses": 1, "demande": {}, "demissions": 0, "mois_fin": -1, "moral_bon": 0, "mois": 6,
		"tarifs": {}, "pret": {}, "trophees": [], "ext": 0}


## Remet les types après un chargement (le JSON rend des nombres à virgule).
static func charger(src: Variant) -> Dictionary:
	var e := vide()
	if not (src is Dictionary):
		return e
	for k in e:
		if (src as Dictionary).has(k):
			e[k] = src[k]
	e.pts = float(e.pts)
	e.cumul = float(e.cumul)
	e.rech = String(e.rech)
	for k in ["camps", "defi_prochain", "defis_ok", "defis_rates", "bonus_fin", "pauses", "demissions", "mois_fin", "moral_bon", "mois", "ext"]:
		e[k] = int(e[k])
	var faits: Array = []
	for f in e.faits:
		faits.append(String(f))
	e.faits = faits
	var eq: Array = []
	for p in e.equipe:
		if p is Dictionary:
			eq.append({"nom": String(p.get("nom", "")), "trait": String(p.get("trait", "rapide")), "moral": float(p.get("moral", 3.0)),
				"fatigue": float(p.get("fatigue", 0.0)), "bas": int(p.get("bas", 0)), "aug": float(p.get("aug", 0.0)), "mois": int(p.get("mois", -1))})
	e.equipe = eq
	var dm: Dictionary = e.demande if e.demande is Dictionary else {}
	e.demande = {"i": int(dm.i), "jour": int(dm.get("jour", 0))} if dm.has("i") else {}
	var tf := {}
	if e.tarifs is Dictionary:
		for k in e.tarifs:
			tf[String(k)] = float(e.tarifs[k])
	e.tarifs = tf
	var pr: Dictionary = e.pret if e.pret is Dictionary else {}
	e.pret = {} if pr.is_empty() else {"montant": int(pr.get("montant", 0)), "reste": float(pr.get("reste", 0.0)), "jour": float(pr.get("jour", 0.0)), "taux": float(pr.get("taux", 0.0)), "debut": int(pr.get("debut", 0))}
	var tr: Array = []
	for f in e.trophees:
		tr.append(String(f))
	e.trophees = tr
	var pal: Array = []
	for f in e.paliers:
		pal.append(String(f))
	e.paliers = pal
	var der := {}
	for k in (e.dernieres as Dictionary):
		der[String(k)] = int(e.dernieres[k])
	e.dernieres = der
	var avis: Array = []
	for a in e.avis:
		if a is Array and (a as Array).size() >= 4:
			avis.append([int(a[0]), int(a[1]), String(a[2]), String(a[3])])
	e.avis = avis
	var c: Dictionary = (e.camp as Dictionary).duplicate() if e.camp is Dictionary else {}
	if not c.is_empty():
		c = {"id": String(c.get("id", "")), "debut": int(c.get("debut", 0)), "fin": int(c.get("fin", -1)), "force": float(c.get("force", 1.0)), "cout": float(c.get("cout", 0.0))}
	e.camp = c
	var d: Dictionary = (e.defi as Dictionary).duplicate() if e.defi is Dictionary else {}
	for k in ["jours", "offert", "debut", "fin", "prime", "sans"]:
		if d.has(k):
			d[k] = int(d[k])
	for k in ["cible", "base"]:
		if d.has(k):
			d[k] = float(d[k])
	for k in ["id", "etat"]:
		if d.has(k):
			d[k] = String(d[k])
	e.defi = d
	return e


## L'état d'essor d'un établissement (créé au besoin, réparé après un chargement).
static func es(st: Dictionary) -> Dictionary:
	if not (st.get("essor", null) is Dictionary):
		st["essor"] = vide()
	var e: Dictionary = st.essor
	var v := vide()
	for k in v:
		if not e.has(k):
			e[k] = v[k]
	return e


static func _ville(g: Gestion, bid: int) -> bool:
	return g.source(bid) == "ville" or (g.source(bid) == "lieu" and GestionLieu.public(g, bid))


static func _annee() -> int:
	return EpoquesObjets.annee_partie()


# --- Recherche ------------------------------------------------------------------------------------

static func recherche(id: String) -> Dictionary:
	for r in RECHERCHES:
		if String(r.id) == id:
			return r
	return {}


static func effets_recherche(g: Gestion, bid: int, r: Dictionary) -> Dictionary:
	if _ville(g, bid) and r.has("ville"):
		var e: Dictionary = (r.effets as Dictionary).duplicate()
		e.erase("attrait")
		e.erase("ventes")
		for k in r.ville:
			e[k] = r.ville[k]
		return e
	var e2: Dictionary = (r.effets as Dictionary).duplicate()
	if _ville(g, bid):
		e2.erase("attrait")
		e2.erase("ventes")
	return e2


static func desc_recherche(g: Gestion, bid: int, r: Dictionary) -> String:
	return String(r.get("desc_ville", r.desc)) if _ville(g, bid) else String(r.desc)


static func faite(st: Dictionary, id: String) -> bool:
	return id in (es(st).faits as Array)


## Pourquoi un projet ne peut pas être lancé ("" : possible).
static func refus_recherche(st: Dictionary, id: String) -> String:
	var r := recherche(id)
	if r.is_empty():
		return "inconnu"
	if faite(st, id):
		return "déjà fait"
	var av := String(r.get("apres", ""))
	if av == "tout":
		for x in RECHERCHES:
			if String(x.id) != id and not faite(st, String(x.id)):
				return "demande tous les autres projets"
	elif av != "" and not faite(st, av):
		return "demande « %s »" % String(recherche(av).nom)
	return ""


## Points de recherche gagnés par jour : l'équipe, sa formation, les pièces.
static func points_jour(g: Gestion, bid: int) -> float:
	var st := g.etat(bid)
	if st.is_empty():
		return 0.0
	var p := 1.0 + 0.4 * float(st.formation) + 0.12 * float(g._nb_pieces(bid))
	return p * maxf(0.2, 1.0 + _somme_recherches(g, bid, st, "points") + GestionPlus.points(g, bid))


static func lancer_recherche(g: Gestion, bid: int, id: String) -> Dictionary:
	var st := g.etat(bid)
	if st.is_empty():
		return {"ok": false, "error": "pas d'établissement"}
	var why := refus_recherche(st, id)
	if why != "":
		return {"ok": false, "error": why}
	var e := es(st)
	if String(e.rech) != id:
		e.rech = id
		e.pts = 0.0
	return {"ok": true}


static func _prochaine_recherche(st: Dictionary) -> String:
	for r in RECHERCHES:
		if refus_recherche(st, String(r.id)) == "":
			return String(r.id)
	return ""


static func _avancer_recherche(g: Gestion, bid: int, st: Dictionary) -> void:
	var e := es(st)
	if String(e.rech) == "":
		if not bool(st.auto):
			return
		e.rech = _prochaine_recherche(st)
		if String(e.rech) == "":
			return
	var r := recherche(String(e.rech))
	if r.is_empty():
		e.rech = ""
		return
	e.pts = float(e.pts) + points_jour(g, bid)
	if float(e.pts) >= float(r.cout):
		(e.faits as Array).append(String(r.id))
		e.rech = ""
		e.pts = 0.0
		g._noter(bid, "Recherche terminée : %s." % String(r.nom), true)


static func _somme_recherches(g: Gestion, bid: int, st: Dictionary, cle: String) -> float:
	var s := 0.0
	for id in es(st).faits:
		s += float(effets_recherche(g, bid, recherche(String(id))).get(cle, 0.0))
	return s


# --- Campagnes ------------------------------------------------------------------------------------

static func campagnes(g: Gestion, bid: int) -> Array:
	return CAMPAGNES_VILLE if _ville(g, bid) else CAMPAGNES


static func campagne(g: Gestion, bid: int, id: String) -> Dictionary:
	for c in campagnes(g, bid):
		if String(c.id) == id:
			return c
	return {}


## Campagnes possibles à l'année de la partie.
static func campagnes_possibles(g: Gestion, bid: int) -> Array:
	var out: Array = []
	var an := _annee()
	for c in campagnes(g, bid):
		if int(c.annee) <= an:
			out.append(c)
	return out


static func cout_campagne(g: Gestion, bid: int, c: Dictionary) -> int:
	return maxi(50, int(roundf(g.cout_batiment(bid) * float(c.cout) / 10.0)) * 10)


static func campagne_en_cours(g: Gestion, bid: int) -> Dictionary:
	if not g.etats.has(bid):
		return {}
	var e := es(g.etats[bid])
	var c: Dictionary = e.camp
	if c.is_empty() or int(c.get("fin", -1)) < g.jour:
		return {}
	return c


## La même campagne refaite moins de 30 jours après : moitié d'effet.
static func lassitude(g: Gestion, bid: int, id: String) -> bool:
	if not g.etats.has(bid):
		return false
	var d: Dictionary = es(g.etats[bid]).dernieres
	return d.has(id) and g.jour - int(d[id]) < LASSITUDE_JOURS


static func lancer_campagne(g: Gestion, bid: int, id: String) -> Dictionary:
	var st := g.etat(bid)
	if st.is_empty():
		return {"ok": false, "error": "pas d'établissement"}
	var c := campagne(g, bid, id)
	if c.is_empty() or int(c.annee) > _annee():
		return {"ok": false, "error": "pas encore inventé à cette époque"}
	if not campagne_en_cours(g, bid).is_empty():
		return {"ok": false, "error": "une campagne est déjà en cours"}
	var e := es(st)
	var demi := lassitude(g, bid, id)
	e.camp = {"id": id, "debut": g.jour, "fin": g.jour + int(c.jours), "force": 0.5 if demi else 1.0, "cout": cout_campagne(g, bid, c)}
	e.dernieres[id] = g.jour
	e.camps = int(e.camps) + 1
	g._noter(bid, "Campagne lancée : %s (%d jours, %s par jour)%s." % [String(c.nom), int(c.jours),
		BuildingSystem.format_money(cout_campagne(g, bid, c)), " — le public s'en lasse, moitié d'effet" if demi else ""])
	g._sur_changement(bid)
	return {"ok": true, "lasse": demi}


static func arreter_campagne(g: Gestion, bid: int) -> void:
	if g.etats.has(bid):
		es(g.etats[bid]).camp = {}
		g._sur_changement(bid)


# --- Défis ----------------------------------------------------------------------------------------

static func defi(id: String) -> Dictionary:
	for d in DEFIS:
		if String(d.id) == id:
			return d
	return {}


static func _mesure(g: Gestion, bid: int, st: Dictionary, m: String) -> float:
	match m:
		"reglees":
			return float(st.reglees)
		"objets":
			return float(g.nb_objets(bid))
		"niveaux":
			var t := 0
			for pid in GestionTypes.ordre(String(st.genre)):
				t += g.gagnes(bid, String(pid))
			return float(t)
		"note":
			return g.note(bid)
		"recettes":
			return float(es(st).cumul)
		"interventions":
			return float(st.get("interventions", 0))
	return 0.0


static func _proposer_defi(g: Gestion, bid: int, st: Dictionary) -> void:
	var e := es(st)
	var choix: Array = []
	for d in DEFIS:
		if bool(d.get("prive", false)) and _ville(g, bid):
			continue
		if bool(d.get("public", false)) and not _ville(g, bid):
			continue
		if String(d.id) == "note" and g.note(bid) >= 4.6:
			continue
		if String(d.id) == "recettes" and float(g.hier(bid).get("ca", 0.0)) <= 1.0:
			continue
		choix.append(d)
	if choix.is_empty():
		return
	var d: Dictionary = choix[g.rng.randi() % choix.size()]
	var m := String(d.mesure)
	var cible := float(d.n)
	if m == "note":
		cible = snappedf(minf(5.0, g.note(bid) + 0.4), 0.1)
	elif m == "recettes":
		cible = roundf(float(g.hier(bid).get("ca", 0.0)) * float(d.jours) * 1.15 / 100.0) * 100.0
	var prime := maxi(500, int(roundf(g.cout_batiment(bid) * 0.004 / 100.0)) * 100)
	e.defi = {"id": String(d.id), "etat": "offert", "cible": cible, "jours": int(d.jours), "offert": g.jour, "prime": prime}
	g._noter(bid, "Nouveau défi proposé : %s." % texte_defi(g, bid, e.defi))


static func texte_defi(g: Gestion, bid: int, df: Dictionary) -> String:
	var d := defi(String(df.get("id", "")))
	if d.is_empty():
		return ""
	var t := String(d.get("texte_ville", d.texte)) if _ville(g, bid) else String(d.texte)
	match String(d.mesure):
		"note":
			return t % [float(df.cible), int(df.jours)]
		"recettes":
			return t % [BuildingSystem.format_money(int(df.cible)), int(df.jours)]
	return t % [int(df.cible), int(df.jours)]


## Avancement d'un défi en cours : [fait, cible].
static func avance_defi(g: Gestion, bid: int) -> Array:
	if not g.etats.has(bid):
		return [0.0, 1.0]
	var st: Dictionary = g.etats[bid]
	var df: Dictionary = es(st).defi
	if df.is_empty():
		return [0.0, 1.0]
	var m := String(defi(String(df.id)).get("mesure", ""))
	if m == "note":
		return [g.note(bid), float(df.cible)]
	if m == "sans_panne":
		return [float(df.get("sans", 0)), float(df.cible)]
	var base := float(df.get("base", 0.0))
	return [_mesure(g, bid, st, m) - base, float(df.cible)]


static func accepter_defi(g: Gestion, bid: int) -> Dictionary:
	var st := g.etat(bid)
	if st.is_empty():
		return {"ok": false, "error": "pas d'établissement"}
	var e := es(st)
	var df: Dictionary = e.defi
	if df.is_empty() or String(df.etat) != "offert":
		return {"ok": false, "error": "pas de défi proposé"}
	var m := String(defi(String(df.id)).get("mesure", ""))
	if m == "recettes":
		e.cumul = 0.0
	df.etat = "actif"
	df.debut = g.jour
	df.fin = g.jour + int(df.jours)
	df.base = _mesure(g, bid, st, m)
	df.sans = 0
	g._noter(bid, "Défi accepté : %s." % texte_defi(g, bid, df))
	return {"ok": true}


static func refuser_defi(g: Gestion, bid: int) -> void:
	if g.etats.has(bid):
		var e := es(g.etats[bid])
		e.defi = {}
		e.defi_prochain = g.jour + DEFI_TOUS_LES


static func _suivre_defi(g: Gestion, bid: int, st: Dictionary) -> void:
	var e := es(st)
	var df: Dictionary = e.defi
	if df.is_empty():
		if g.jour >= int(e.defi_prochain):
			_proposer_defi(g, bid, st)
		return
	if String(df.etat) == "offert":
		if bool(st.auto):
			accepter_defi(g, bid)
		elif g.jour - int(df.offert) > DEFI_ATTENTE:
			refuser_defi(g, bid)
		return
	var m := String(defi(String(df.id)).get("mesure", ""))
	if m == "sans_panne":
		df.sans = int(df.get("sans", 0)) + 1 if (st.pannes as Array).is_empty() else 0
	var a := avance_defi(g, bid)
	if float(a[0]) >= float(a[1]) - 0.0001:
		var prime := int(df.prime)
		if not g.buildings.unlimited_money:
			g._crediter(bid, float(prime))
		e.defis_ok = int(e.defis_ok) + 1
		e.bonus_fin = g.jour + BONUS_DEFI_JOURS
		e.defi = {}
		e.defi_prochain = g.jour + DEFI_TOUS_LES
		g._noter(bid, "Défi réussi : %s ! Prime de %s et clients ravis pendant %d jours." % [texte_defi(g, bid, df), BuildingSystem.format_money(prime), BONUS_DEFI_JOURS], true)
		g._sur_changement(bid)
	elif g.jour >= int(df.fin):
		e.defis_rates = int(e.defis_rates) + 1
		e.defi = {}
		e.defi_prochain = g.jour + DEFI_TOUS_LES
		g._noter(bid, "Défi manqué : %s." % texte_defi(g, bid, df))


# --- Paliers --------------------------------------------------------------------------------------

## Caps atteints : [{id, nom, effets}].
static func paliers(g: Gestion, bid: int) -> Array:
	var out: Array = []
	if not g.etats.has(bid):
		return out
	var st: Dictionary = g.etats[bid]
	var gn := String(st.genre)
	for pid in GestionTypes.ordre(gn):
		var n := g.niveau(bid, String(pid))
		if n > 0 and n >= g.niveau_max(bid, String(pid)):
			out.append({"id": "max_" + String(pid), "nom": "%s au maximum" % String(GestionTypes.piece(gn, String(pid)).get("court", pid)), "effets": {"confort": 0.03}})
	var nobj := g.nb_objets(bid)
	for cap in [10, 25, 50]:
		if nobj >= cap:
			out.append({"id": "obj_%d" % cap, "nom": "%d objets installés" % cap, "effets": {"satisf": 0.02}})
	var e := es(st)
	for cap in [3, 10]:
		if int(e.defis_ok) >= cap:
			out.append({"id": "defis_%d" % cap, "nom": "%d défis réussis" % cap, "effets": {"satisf": 0.02} if _ville(g, bid) else {"attrait": 0.03}})
	if (e.faits as Array).size() >= RECHERCHES.size():
		out.append({"id": "recherche", "nom": "Toute la recherche", "effets": {"vitesse": 0.1}})
	return out


## Prochains caps à viser (pour l'écran) : [texte].
static func prochains_paliers(g: Gestion, bid: int) -> Array:
	var out: Array = []
	var nobj := g.nb_objets(bid)
	for cap in [10, 25, 50]:
		if nobj < cap:
			out.append("%d objets installés (%d / %d) : satisfaction en plus" % [cap, nobj, cap])
			break
	if g.etats.has(bid):
		var e := es(g.etats[bid])
		for cap in [3, 10]:
			if int(e.defis_ok) < cap:
				out.append("%d défis réussis (%d / %d)" % [cap, int(e.defis_ok), cap])
				break
	out.append("Chaque pièce au niveau maximum : confort en plus")
	return out


static func _annoncer_paliers(g: Gestion, bid: int, st: Dictionary) -> void:
	var e := es(st)
	var connus: Array = e.paliers
	for p in paliers(g, bid):
		if not (String(p.id) in connus):
			connus.append(String(p.id))
			g._noter(bid, "Palier atteint : %s." % String(p.nom), true)


# --- Bonus et charges (lus par Gestion) -----------------------------------------------------------

## Ce que la recherche, la campagne, les paliers et un défi réussi ajoutent à une clé.
static func bonus(g: Gestion, bid: int, cle: String) -> float:
	if not g.etats.has(bid):
		return 0.0
	var st: Dictionary = g.etats[bid]
	if not (st.get("essor", null) is Dictionary) or cle in ["economie", "pannes", "points", "rayons", "panier", "antivol"]:
		return 0.0
	var s := _somme_recherches(g, bid, st, cle)
	var c := campagne_en_cours(g, bid)
	if not c.is_empty():
		s += float(campagne(g, bid, String(c.id)).get("effets", {}).get(cle, 0.0)) * float(c.get("force", 1.0))
	for p in paliers(g, bid):
		s += float((p.effets as Dictionary).get(cle, 0.0))
	s += GestionPlus.bonus(g, bid, cle)
	if int(es(st).bonus_fin) >= g.jour:
		if cle == "satisf":
			s += 0.04
		elif cle == "attrait" and not _ville(g, bid):
			s += 0.03
	return s


## Charges du jour : campagne en cours, moins les économies de la recherche.
static func ajuster_charges(g: Gestion, bid: int, s: float) -> float:
	if not g.etats.has(bid) or not (g.etats[bid].get("essor", null) is Dictionary):
		return s
	var c := campagne_en_cours(g, bid)
	var plus := float(c.get("cout", 0.0)) if not c.is_empty() else 0.0
	return s * (1.0 - _somme_recherches(g, bid, g.etats[bid], "economie")) + plus + GestionPlus.charges(g, bid)


## Facteur des pannes (maintenance préventive).
static func facteur_pannes(g: Gestion, bid: int) -> float:
	if not g.etats.has(bid) or not (g.etats[bid].get("essor", null) is Dictionary):
		return 1.0
	return maxf(0.2, (1.0 - _somme_recherches(g, bid, g.etats[bid], "pannes")) * GestionPlus.facteur_pannes(g, bid))


# --- La journée -----------------------------------------------------------------------------------

static func journee(g: Gestion, bid: int, st: Dictionary, month := 6) -> void:
	var e := es(st)
	GestionPlus.journee(g, bid, st, month)
	e.cumul = float(e.cumul) + float(g.hier(bid).get("ca", 0.0)) if not _ville(g, bid) else 0.0
	_avancer_recherche(g, bid, st)
	_suivre_defi(g, bid, st)
	_annoncer_paliers(g, bid, st)
	_nouvel_avis(g, bid, st)
	if bool(st.auto):
		_campagne_auto(g, bid, st)


## En gestion automatique : une campagne quand il manque des clients et que
## le compte le permet (jamais la caisse de la ville).
static func _campagne_auto(g: Gestion, bid: int, st: Dictionary) -> void:
	if not campagne_en_cours(g, bid).is_empty() or g.jour % 5 != 0:
		return
	if _ville(g, bid):
		return
	if g.occupation(bid) >= 0.7:
		return
	var best := {}
	for c in campagnes_possibles(g, bid):
		if lassitude(g, bid, String(c.id)):
			continue
		var tot := float(cout_campagne(g, bid, c) * int(c.jours))
		if tot > g.compte(bid) * 0.25:
			continue
		if best.is_empty() or float(c.effets.get("attrait", 0.0)) > float(best.effets.get("attrait", 0.0)):
			best = c
	if not best.is_empty():
		lancer_campagne(g, bid, String(best.id))


# --- Avis des clients -----------------------------------------------------------------------------

## Ce qui plaît et ce qui fâche en ce moment : {plus: [texte], moins: [texte]}.
static func ressenti(g: Gestion, bid: int) -> Dictionary:
	var plus: Array = []
	var moins: Array = []
	var st := g.etat(bid)
	if st.is_empty():
		return {"plus": plus, "moins": moins}
	var gn := String(st.genre)
	var ville := _ville(g, bid)
	for p in st.pannes:
		moins.append("%s en panne : %s" % [String(GestionTypes.piece(gn, String(p.piece)).get("court", p.piece)), String(p.texte).to_lower()])
	if not ville:
		var px := float(st.get("prix", 1.0))
		if g.source(bid) == "tourisme" and g.tourisme != null and g.tourisme.heb.has(bid):
			px = float(g.tourisme.heb[bid].prix) / maxf(1.0, float(g.spec_base(bid).get("prix", g.tourisme.heb[bid].prix)))
		if px > 1.3:
			moins.append("Trop cher pour ce que c'est")
		elif px < 0.85:
			plus.append("Des prix vraiment doux")
	else:
		var dl := float(st.get("delai", -1.0))
		if dl >= 0.0 and dl < 240.0:
			plus.append("Arrivés très vite quand on a appelé")
		elif dl >= 420.0:
			moins.append("Les secours mettent trop de temps à arriver")
	if float(st.salaire) >= 1.15:
		plus.append("Une équipe souriante")
	elif float(st.salaire) <= 0.9:
		moins.append("Une équipe qui fait la tête")
	if int(st.formation) >= 3:
		plus.append("Un personnel très pro")
	var best := ""
	var bestn := 0
	var pire := ""
	for pid in GestionTypes.ordre(gn):
		var n := g.niveau(bid, String(pid))
		var court := String(GestionTypes.piece(gn, String(pid)).get("court", pid))
		if n > bestn:
			bestn = n
			best = court
		if n == 1 and int(GestionTypes.piece(gn, String(pid)).get("base", 0)) >= 1 and pire == "":
			pire = court
	if bestn >= 3:
		plus.append("%s magnifique" % best)
	if pire != "" and g.etoiles(bid) >= 3:
		moins.append("%s un peu vieillot" % pire)
	if g.nb_objets(bid) >= 15:
		plus.append("Plein de petites attentions")
	if int(st.ratees) > int(st.reglees) and int(st.ratees) >= 3:
		moins.append("On demande, personne ne répond")
	var c := campagne_en_cours(g, bid)
	if not c.is_empty():
		plus.append("On en parle partout (%s)" % String(campagne(g, bid, String(c.id)).nom).to_lower())
	if not ville and g.occupation(bid) >= 0.95:
		moins.append("Toujours complet, difficile d'avoir une place")
	return {"plus": plus.slice(0, 4), "moins": moins.slice(0, 4)}


static func _nouvel_avis(g: Gestion, bid: int, st: Dictionary) -> void:
	if g.rng.randf() > 0.45:
		return
	if not _ville(g, bid) and g.clients(bid) <= 0:
		return
	var r := ressenti(g, bid)
	var etoiles := clampi(roundi(g.satisf(bid) + g.rng.randf_range(-1.0, 1.0)), 1, 5)
	var texte := ""
	var lp: Array = r.plus
	var lm: Array = r.moins
	if etoiles >= 4 and not lp.is_empty():
		texte = String(lp[g.rng.randi() % lp.size()])
	elif etoiles <= 2 and not lm.is_empty():
		texte = String(lm[g.rng.randi() % lm.size()])
	elif not lp.is_empty() and (lm.is_empty() or g.rng.randf() < 0.5):
		texte = String(lp[g.rng.randi() % lp.size()])
	elif not lm.is_empty():
		texte = String(lm[g.rng.randi() % lm.size()])
	else:
		texte = ["Rien à redire.", "Correct, sans plus.", "On reviendra peut-être.", "Comme d'habitude."][g.rng.randi() % 4]
	# Pas deux fois de suite le même avis.
	var der: Array = es(st).avis
	if not der.is_empty() and String(der[0][3]) == texte:
		var tout: Array = lp + lm
		tout.erase(texte)
		if tout.is_empty():
			return
		texte = String(tout[g.rng.randi() % tout.size()])
	var auteur := String(PRENOMS[g.rng.randi() % PRENOMS.size()])
	var e := es(st)
	(e.avis as Array).push_front([g.jour, etoiles, auteur, texte])
	while (e.avis as Array).size() > AVIS_MAX:
		(e.avis as Array).pop_back()


## Moyenne des étoiles des avis (0 : pas d'avis).
static func moyenne_avis(st: Dictionary) -> float:
	var l: Array = es(st).avis
	if l.is_empty():
		return 0.0
	var s := 0.0
	for a in l:
		s += float(a[1])
	return s / float(l.size())


# --- Concurrents ----------------------------------------------------------------------------------

## Les établissements du même genre de la partie, du mieux noté au moins bien :
## [{bid, nom, note, etoiles, clients, moi}].
static func concurrents(g: Gestion, bid: int) -> Array:
	var out: Array = []
	if g.buildings == null:
		return out
	var gn := g.genre_of(bid)
	for b in g.buildings.buildings:
		var id := int(b)
		if g.genre_of(id) != gn or not g.valide(id):
			continue
		out.append({"bid": id, "nom": g.nom(id), "note": g.note(id), "etoiles": g.etoiles(id), "clients": g.clients(id), "moi": id == bid})
	out.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool:
		if absf(float(a.note) - float(b2.note)) > 0.001:
			return float(a.note) > float(b2.note)
		return int(a.clients) > int(b2.clients))
	return out


## Rang du bâtiment parmi ses concurrents (1 = premier), et leur nombre.
static func rang(g: Gestion, bid: int) -> Vector2i:
	var l := concurrents(g, bid)
	for i in l.size():
		if bool(l[i].moi):
			return Vector2i(i + 1, l.size())
	return Vector2i(0, l.size())
