class_name Causes
extends RefCounted
## « Pourquoi ? » : la cause d'une alerte en un clic, avec les vrais chiffres du
## moment (pas seulement le constat du Conseiller). Exemple : « Pas assez
## d'ouvriers : 12 disponibles pour 45 demandés ».
##
## Causes.de(avis, lieu) -> {"cause": phrase courte, "lignes": [détails…]}.
## Un avis peut apporter sa propre cause (clés "cause" et "lignes") : elle passe
## avant le calcul d'ici (alertes des chantiers, des raccordements…).
##
## Causes.alertes_chantiers(lieu) : alerte « chantiers à l'arrêt » (sans ouvriers,
## équipe incomplète ou caisse vide) pour le fil « À faire » et la Mairie.


static func de(a: Dictionary, lieu: String = Statistiques.PAYS) -> Dictionary:
	if a.has("cause"):
		return {"cause": String(a.cause), "lignes": (a.get("lignes", []) as Array).duplicate()}
	var st := Statistiques.instance
	var id := String(a.get("id", ""))
	var out := {"cause": "", "lignes": []}
	var d := func(ind: String, l := lieu) -> float:
		return st.dernier(l, ind) if st != null else NAN
	var f := func(ind: String, v: float) -> String: return Statistiques.format(ind, v)
	var P := Statistiques.PAYS
	match id:
		"chomage", "plein_emploi":
			var hab: float = d.call("habitants")
			var libres: float = d.call("emplois_libres")
			var emplois := _stat_ville(lieu, "emplois")
			if not is_nan(libres) and libres > 0.0 and id == "chomage":
				out.cause = "Des emplois restent vides : ils sont mal desservis ou ne correspondent pas aux métiers"
			else:
				out.cause = "Pas assez d'emplois pour les habitants"
			if emplois >= 0 and not is_nan(hab):
				out.lignes.append("%d emplois dans la ville pour %d habitants" % [emplois, roundi(hab)])
			if not is_nan(libres):
				out.lignes.append("%s emplois libres" % f.call("emplois_libres", libres))
			out.lignes.append("Chômage : %s" % f.call("chomage", d.call("chomage")))
		"logements":
			out.cause = "Pas assez de logements : les nouveaux venus n'ont nulle part où dormir"
			out.lignes.append("Logements libres : %s" % f.call("logements_libres", d.call("logements_libres")))
			out.lignes.append("Emplois qui attendent quelqu'un : %s" % f.call("emplois_libres", d.call("emplois_libres")))
		"vacants":
			out.cause = "Les logements sont là, mais pas le travail ni les services pour attirer du monde"
			out.lignes.append("Logements vides : %s" % f.call("logements_libres", d.call("logements_libres")))
			out.lignes.append("Emplois libres : %s" % f.call("emplois_libres", d.call("emplois_libres")))
		"colere", "grogne", "chute_satisfaction", "exode", "elections", "contents":
			_satisfaction(out)
		"caisse_rouge", "faillite", "deficit", "caisse_verte":
			_budget(out, lieu)
		"ecole":
			var n: float = d.call("sans_ecole")
			var ecoles := _compter(lieu, "ecole")
			out.cause = "Aucune école dans la ville" if ecoles == 0 else "Pas assez de places dans les écoles, ou trop loin des familles"
			out.lignes.append("%d enfant%s sans école" % [roundi(n), "s" if n >= 2.0 else ""])
			if ecoles >= 0:
				out.lignes.append("%d école%s dans la ville" % [ecoles, "s" if ecoles > 1 else ""])
		"electricite", "eau":
			var v: float = d.call(id, P)
			out.cause = "La production ne suffit pas : %s des besoins couverts" % f.call(id, v)
			out.lignes.append("Il faut une centrale ou un captage de plus, pas seulement des lignes.")
		"coupures":
			out.cause = "Des bâtiments ne sont pas reliés au réseau (la production, elle, suffit)"
			out.lignes.append("%s bâtiments coupés" % f.call("coupures", d.call("coupures", P)))
		"bouchons":
			out.cause = "Trop de voitures sur les mêmes routes"
			out.lignes.append("Temps perdu : %s" % f.call("congestion", d.call("congestion", P)))
			out.lignes.append("Trajet moyen : %s" % f.call("trajet", d.call("trajet", P)))
		"dechets":
			out.cause = "Pas assez de bennes ou de centres de collecte, ou ils n'atteignent pas ces rues"
			out.lignes.append("%s poubelles qui débordent" % f.call("dechets", d.call("dechets", P)))
		"pollution":
			out.cause = "Usines ou grands axes trop près des logements"
			out.lignes.append("Pollution chez les habitants : %s" % f.call("pollution", d.call("pollution")))
		"loyers":
			out.cause = "Pas assez de logements abordables"
			out.lignes.append("Loyer moyen : %s" % f.call("loyer", d.call("loyer")))
			out.lignes.append("Part du revenu : %s" % f.call("effort", d.call("effort")))
		"vieillissement":
			out.cause = "Peu de jeunes familles s'installent"
			out.lignes.append("65 ans et plus : %s" % f.call("seniors", d.call("seniors")))
		"epidemie":
			out.cause = "La maladie circule : peu de lits et d'hygiène"
			out.lignes.append("Malades : %s · hospitalisés : %s" % [f.call("malades", d.call("malades", P)), f.call("hospitalises", d.call("hospitalises", P))])
			out.lignes.append("Eau potable : %s · égouts : %s" % [f.call("eau_potable", d.call("eau_potable", P)), f.call("egouts", d.call("egouts", P))])
		"hygiene_eau_potable", "hygiene_egouts":
			out.cause = "Le réseau ne dessert pas encore tous les logements"
			out.lignes.append("Eau potable : %s · égouts : %s" % [f.call("eau_potable", d.call("eau_potable", P)), f.call("egouts", d.call("egouts", P))])
		"secours":
			out.cause = "Casernes et hôpitaux trop loin, ou routes encombrées"
			out.lignes.append("Délai moyen : %s" % f.call("intervention", d.call("intervention", P)))
			out.lignes.append("Appels du jour : %s" % f.call("appels", d.call("appels", P)))
		"non_raccordes":
			out.cause = "Trop loin d'une route, d'une ligne ou d'une conduite (plus de 30 m)"
			out.lignes.append(String(a.get("titre", "")))
		"sans_police", "sans_ambulance", "sans_pompiers":
			out.cause = "Aucun bâtiment ne peut envoyer ces secours"
			out.lignes.append(String(a.get("titre", "")))
	if String(out.cause) == "":
		out.cause = String(a.get("texte", ""))
	return out


## Valeur des Communes pour une ville (lieu = id) ; -1 si inconnue.
static func _stat_ville(lieu: String, cle: String) -> int:
	var cm := Communes.instance
	if cm == null or not lieu.is_valid_int():
		return -1
	return int((cm.stats.get(int(lieu), {}) as Dictionary).get(cle, -1))


static func _compter(lieu: String, type_id: String) -> int:
	var o := Objectifs.instance
	if o == null or not lieu.is_valid_int():
		return -1
	return o.compter(int(lieu), type_id)


## Le thème le plus mal noté du dernier sondage et ses raisons, en chiffres.
static func _satisfaction(out: Dictionary) -> void:
	var av := Avis.instance
	if av == null:
		return
	var sd := av.sondage()
	var themes: Array = []
	for th in sd.get("themes", {}):
		themes.append([String(th), int(sd.themes[th].note), sd.themes[th].get("raisons", [])])
	themes.sort_custom(func(x, y) -> bool: return int(x[1]) < int(y[1]))
	if themes.is_empty():
		return
	var pire: Array = themes[0]
	out.cause = "Le plus mal noté : %s (%d/100)" % [Avis.theme_nom(String(pire[0])).to_lower(), int(pire[1])]
	for r in (pire[2] as Array).slice(0, 2):
		out.lignes.append("« %s » : %d habitant%s" % [String(r[0]), int(r[1]), "s" if int(r[1]) > 1 else ""])
	if themes.size() > 1:
		out.lignes.append("Ensuite : %s (%d/100)" % [Avis.theme_nom(String(themes[1][0])).to_lower(), int(themes[1][1])])


## Les postes qui pèsent le plus dans le budget du mois.
static func _budget(out: Dictionary, lieu: String) -> void:
	var b := BudgetCommunal.instance
	if b == null:
		return
	var k := int(lieu) if lieu.is_valid_int() else -2
	var bil := b.bilan_mensuel(k)
	var solde := float(bil.get("solde", 0.0))
	var dep: Array = []
	for key in bil.get("depenses", {}):
		dep.append([String(key), float(bil.depenses[key])])
	dep.sort_custom(func(x, y) -> bool: return float(x[1]) > float(y[1]))
	if solde < 0.0:
		out.cause = "Les dépenses dépassent les recettes de %s par mois" % BuildingSystem.format_money(roundi(-solde))
	else:
		out.cause = "Le mois est positif (%s), mais la réserve est trop maigre" % BuildingSystem.format_money(roundi(solde))
	out.lignes.append("Recettes : %s · dépenses : %s par mois" % [BuildingSystem.format_money(roundi(float(bil.get("total_recettes", 0.0)))),
		BuildingSystem.format_money(roundi(float(bil.get("total_depenses", 0.0))))])
	for p in dep.slice(0, 2):
		out.lignes.append("Plus grosse dépense : %s (%s)" % [String(p[0]), BuildingSystem.format_money(roundi(float(p[1])))])


# --- Alerte des chantiers ----------------------------------------------------------------

## Chantiers à l'arrêt ou au ralenti dans le lieu (id de ville, ou PAYS : tous).
## Rend [] ou [avis] avec sa cause déjà calculée.
static func alertes_chantiers(lieu: String = Statistiques.PAYS) -> Array:
	var fo := Fondateurs.instance
	if fo == null or not fo.regle_active():
		return []
	var v := int(lieu) if lieu.is_valid_int() else -999
	var sans := 0
	var incomplets := 0
	var argent := 0
	var demande := 0
	var presents := 0
	for c in fo.liste_chantiers():
		if v != -999 and int(c.get("vid", -1)) != v:
			continue
		if bool(c.get("pause", false)):
			continue
		var eq := fo.equipe_de(String(c.cle))
		demande += int(eq[1])
		presents += int(eq[0])
		if bool(c.get("attente", false)):
			argent += 1
		elif int(eq[0]) <= 0:
			sans += 1
		elif int(eq[0]) < int(eq[1]):
			incomplets += 1
	if sans + incomplets + argent == 0:
		return []
	var ouv := fo.ouvriers()
	var dispo := int(ouv.fondateurs) + int(ouv.entreprises) + int(ouv.pionniers)
	var lignes: Array = []
	var cause := ""
	if sans + incomplets > 0:
		cause = "Pas assez d'ouvriers : %d au travail pour %d demandés" % [presents, demande]
		lignes.append("Ouvriers : %d fondateurs au campement, %d employés du bâtiment" % [int(ouv.fondateurs), int(ouv.entreprises)]
			+ (", %d pionniers" % int(ouv.pionniers) if int(ouv.pionniers) > 0 else ""))
		if sans > 0:
			lignes.append("%d chantier%s sans aucun ouvrier" % [sans, "s" if sans > 1 else ""])
		if incomplets > 0:
			lignes.append("%d chantier%s avec une équipe incomplète" % [incomplets, "s" if incomplets > 1 else ""])
		lignes.append("Mets en pause les chantiers moins utiles, ou construis une entreprise du bâtiment.")
	if argent > 0:
		if cause == "":
			cause = "Caisse vide : %d chantier%s arrêté%s faute d'argent" % [argent, "s" if argent > 1 else "", "s" if argent > 1 else ""]
		else:
			lignes.append("%d chantier%s arrêté%s faute d'argent" % [argent, "s" if argent > 1 else "", "s" if argent > 1 else ""])
	var n := sans + incomplets + argent
	var s := "s" if n > 1 else ""
	return [{"id": "chantiers_lents", "gravite": 2 if sans >= 3 or argent >= 2 else 1, "prio": 1, "theme": "chantiers",
		"titre": "%d chantier%s à l'arrêt ou au ralenti" % [n, s],
		"texte": ["Les grues attendent, les pelleteuses aussi.", "Le contremaître compte ses ouvriers sur les doigts d'une main.",
			"Les plans sont prêts, il ne manque que les bras."][dispo % 3],
		"conseil": "Répartis les ouvriers dans Fondateurs et chantiers (Maj+H) : pause, priorité, renforts.",
		"panneau": "fondateurs", "cause": cause, "lignes": lignes, "ouvriers": dispo, "demande": demande}]
