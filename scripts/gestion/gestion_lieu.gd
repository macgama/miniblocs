class_name GestionLieu
extends RefCounted
## Mode gestion : source « lieu », pour les établissements qui n'ont pas de
## système de clients à eux dans la simulation (zoo, école, gare, musée,
## mairie, stade, ferme… : genres décrits avec GenreAuto).
##
## L'établissement tient sa propre petite comptabilité dans st.caisse :
## - des visiteurs chaque jour : la base du bâtiment (places, visiteurs ou
##   emplois du catalogue) × l'envie de venir (note, attrait, prix, saison),
##   au plus la capacité (effet « couverts » : des places en plus) ;
## - des recettes : visiteurs × panier du genre × prix choisi + dépenses sur
##   place (effet « ventes ») ;
## - pour un service public (genre "public") : un budget versé chaque jour
##   par la ville (comme la caserne), ajustable avec − / + ;
## - des charges : l'entretien des améliorations (Gestion.entretien_jour).
## Comme pour les services d'urgence, seuls les lieux ouverts une fois en
## mode gestion vivent cette journée (les autres ne coûtent rien de plus).
## Les effets sur la ville passent par des liens propres à chaque genre
## (Gestion.effet_de lu par le système concerné).

const PRIX_MIN := 0.0
const PRIX_MAX := 2.5
## Part des vraies recettes (zoo…) mise de côté pour les travaux.
const PART_REEL := 0.25


static func gd(g: Gestion, bid: int) -> Dictionary:
	return GestionTypes.genre(g.genre_of(bid))


static func public(g: Gestion, bid: int) -> bool:
	return bool(gd(g, bid).get("public", false))


## Visiteurs « de base » par jour : places du stade, visiteurs, sinon emplois.
static func base(g: Gestion, bid: int) -> float:
	var t := BuildingCatalog.get_type(g.type_of(bid))
	var d := gd(g, bid)
	var b := 0.0
	if d.has("base_fn"):
		b = GenresAuto.base_speciale(g, bid, String(d.base_fn))
	if b <= 0.0:
		b = float(t.get("visiteurs", 0)) * float(d.get("part_visiteurs", 1.0))
	if b <= 0.0:
		b = float(t.get("emplois", 4)) * float(d.get("par_emploi", 10.0))
	var f := Ameliorations.facteur_bid(g.buildings, bid) if g.buildings != null and g.buildings.buildings.has(bid) else 1.0
	return maxf(5.0, b * f)


static func capacite(g: Gestion, bid: int) -> int:
	return roundi(base(g, bid) * float(gd(g, bid).get("marge", 1.3)) * (1.0 + maxf(0.0, g.effet(bid, "couverts"))))


static func saison(g: Gestion, bid: int, month: int) -> float:
	var s: Dictionary = gd(g, bid).get("saison", {})
	return float(s.get(month, s.get(str(month), 1.0)))


static func envie(g: Gestion, bid: int, month := -1) -> float:
	var st: Dictionary = g.etats.get(bid, {})
	if st.is_empty():
		return 1.0
	var m := month if month > 0 else GestionPlus.mois(g, bid)
	var e := clampf(1.0 + 0.15 * (float(st.note) - 3.0) + g.effet(bid, "attrait"), 0.3, 2.4)
	var px := maxf(0.2, float(st.prix))
	var sens := float(gd(g, bid).get("sensible_prix", 1.3))
	return e * saison(g, bid, m) / pow(px, sens)


static func panier(g: Gestion, bid: int) -> float:
	var p := float(gd(g, bid).get("panier", 0.0))
	# Les prix suivent l'époque (un billet coûte bien moins en 1850).
	var an := EpoquesObjets.annee_partie()
	if an < 1900:
		p *= 0.08
	elif an < 1950:
		p *= 0.25
	elif an < 1990:
		p *= 0.6
	return p


static func dotation_defaut(g: Gestion, bid: int) -> float:
	if not public(g, bid):
		return 0.0
	return roundf(g.cout_batiment(bid) * float(gd(g, bid).get("budget", 0.0004)) / 10.0) * 10.0


static func dotation(g: Gestion, bid: int) -> float:
	var st: Dictionary = g.etats.get(bid, {})
	var d := float(st.get("dotation", -1.0))
	return dotation_defaut(g, bid) if d < 0.0 else d


## La journée d'un lieu ouvert en mode gestion.
static func journee(g: Gestion, bid: int, st: Dictionary, month: int) -> void:
	var gratuit := g.buildings.unlimited_money
	var cap := float(capacite(g, bid))
	var cl := minf(cap, base(g, bid) * envie(g, bid, month)) * GenresAuto.facteur_jour(g, bid, gd(g, bid))
	var ca := cl * (panier(g, bid) * float(st.prix) + maxf(0.0, g.effet(bid, "ventes")))
	# Établissement qui a déjà son système (zoo…) : ses vrais visiteurs, et une
	# part de ses vraies recettes mise de côté pour les travaux (prise à la ville).
	var reel := GenresAuto.reel(g, bid, String(gd(g, bid).get("reel_fn", "")))
	if not reel.is_empty():
		cl = float(reel.clients)
		cap = maxf(cap, float(reel.get("cap", cap)))
		var part := float(reel.recettes) * PART_REEL
		if part > 0.0 and not gratuit:
			g._depense_ville("Gestion : travaux de %s" % g.nom(bid), part)
		ca = part + cl * maxf(0.0, g.effet(bid, "ventes"))
	var dot := dotation(g, bid)
	if dot > 0.0 and not gratuit:
		g._depense_ville("Gestion : budget de %s" % g.nom(bid), dot)
	var ent := g.entretien_jour(bid)
	st.caisse = float(st.caisse) + ca + dot - ent
	if float(st.caisse) < 0.0:
		# Un lieu à court d'argent : la ville avance le reste.
		if not gratuit:
			g._depense_ville("Gestion : avance à %s" % g.nom(bid), -float(st.caisse))
		st.aide_ville = float(st.aide_ville) - float(st.caisse)
		st.caisse = 0.0
	st.hier = {"ca": ca + dot, "charges": ent, "clients": cl, "cap": cap, "recettes": ca, "budget": dot}
	# Satisfaction et note.
	var plein := cl / maxf(1.0, cap)
	var cible := 3.0 + 3.0 * g.effet(bid, "satisf") + 0.4 * g.effet(bid, "confort") - 1.2 * maxf(0.0, float(st.prix) - 1.0) \
		- 0.6 * maxf(0.0, plein - 0.92) - 0.25 * float((st.pannes as Array).size())
	st.satisf = clampf(lerpf(float(st.satisf), clampf(cible, 0.5, 5.0), 0.2), 0.5, 5.0)
	var nc := 2.4 + 0.35 * float(g.etoiles(bid)) + 0.35 * (float(st.satisf) - 3.0) - 0.15 * float((st.pannes as Array).size())
	st.note = clampf(lerpf(float(st.note), clampf(nc, 0.5, 5.0), 0.25), 0.5, 5.0)
	(st.hist as Array).append([g.jour, ca + dot, ent, roundi(cl), snappedf(plein, 0.01), snappedf(float(st.note), 0.01), snappedf(float(st.satisf), 0.01)])
	while (st.hist as Array).size() > Gestion.HISTORIQUE:
		(st.hist as Array).pop_front()
	# Événements propres au genre (fête, inspection, visite…).
	_evenements(g, bid, st, month)


static func _evenements(g: Gestion, bid: int, st: Dictionary, month: int) -> void:
	var evs: Array = gd(g, bid).get("evenements", [])
	if evs.is_empty() or g.rng.randf() > 0.06:
		return
	var choix: Array = []
	for e in evs:
		var mois: Array = e.get("mois", [])
		if mois.is_empty() or month in mois:
			choix.append(e)
	if choix.is_empty():
		return
	var e: Dictionary = choix[g.rng.randi() % choix.size()]
	var gain := float(e.get("gain", 0.0)) * maxf(1.0, base(g, bid)) * maxf(0.05, panier(g, bid) / maxf(0.01, float(gd(g, bid).get("panier", 1.0))))
	if gain > 0.0 and not g.buildings.unlimited_money:
		st.caisse = float(st.caisse) + gain
	if e.has("satisf"):
		g._ajouter_satisf(bid, float(e.satisf))
	st.seminaires = int(st.seminaires) + 1
	g._noter(bid, String(e.texte) + ((" (+%s)" % BuildingSystem.format_money(int(gain))) if gain >= 1.0 else ""), bool(e.get("annoncer", false)))


# --- Chiffres lus par Gestion --------------------------------------------------------------------

static func clients(g: Gestion, bid: int) -> int:
	var h: Dictionary = (g.etats.get(bid, {}) as Dictionary).get("hier", {})
	if h.has("clients"):
		return roundi(float(h.clients))
	return roundi(base(g, bid))


static func prix_unitaire(g: Gestion, bid: int) -> float:
	var st: Dictionary = g.etats.get(bid, {})
	return panier(g, bid) * float(st.get("prix", 1.0))


static func prix_txt(g: Gestion, bid: int) -> String:
	var d := gd(g, bid)
	var st: Dictionary = g.etats.get(bid, {})
	var px := float(st.get("prix", 1.0))
	var t := String(d.get("prix_nom", "Prix d'entrée"))
	if panier(g, bid) <= 0.0:
		return "%s : %d %%" % [t, roundi(px * 100.0)]
	return "%s : %s (%d %% du prix habituel)" % [t, BuildingSystem.format_money(roundi(prix_unitaire(g, bid))), roundi(px * 100.0)]


static func changer_prix(g: Gestion, bid: int, sens: int) -> void:
	var st := g.etat(bid)
	if public(g, bid) and panier(g, bid) <= 0.0:
		# Service public gratuit : − / + règle le budget de la ville.
		var d := dotation(g, bid)
		var pas := maxf(10.0, roundf(dotation_defaut(g, bid) * 0.25 / 10.0) * 10.0)
		st.dotation = clampf(d + pas * float(sens), 0.0, dotation_defaut(g, bid) * 8.0)
		return
	st.prix = snappedf(clampf(float(st.prix) + 0.1 * float(sens), maxf(PRIX_MIN, 0.3 if not public(g, bid) else 0.0), PRIX_MAX), 0.01)


## Gestion automatique : le prix suit le remplissage.
static func ajuster_prix_auto(g: Gestion, bid: int) -> void:
	if public(g, bid) and panier(g, bid) <= 0.0:
		return
	var occ := g.occupation(bid)
	if occ > 0.95:
		changer_prix(g, bid, 1)
	elif occ < 0.55 and float(g.etat(bid).prix) > 0.75:
		changer_prix(g, bid, -1)
