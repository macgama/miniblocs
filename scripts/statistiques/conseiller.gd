class_name Conseiller
extends RefCounted
## Le conseiller municipal : il lit les statistiques du jour (et leur évolution),
## repère ce qui va mal et propose quoi faire, avec le panneau qui sert à le faire.
## Ton : sérieux sur le fond, une pointe d'humour dans la forme.
##
## Un avis : {id, gravite (0 : bonne nouvelle, 1 : à surveiller, 2 : urgent), theme,
## titre, texte, conseil, panneau (id du panneau à ouvrir, "" sinon)}.

const GRAVITES := ["Bonne nouvelle", "À surveiller", "Urgent"]
const COULEURS := [Color("9fe3b0"), Color("ffd166"), Color("ff8a7a")]

## Seuils (réglés pour une ville de quelques centaines à quelques milliers d'habitants).
const CHOMAGE_ATTENTION := 10.0
const CHOMAGE_URGENT := 20.0
const SATISFACTION_ATTENTION := 50
const SATISFACTION_URGENT := 35
const RESEAU_ATTENTION := 97.0
const RESEAU_URGENT := 85.0
const BOUCHONS_ATTENTION := 25.0
const BOUCHONS_URGENT := 60.0
const POLLUTION_ATTENTION := 35.0
const POLLUTION_URGENT := 60.0
## Mois de réserve sous lesquels un solde négatif devient inquiétant.
const MOIS_RESERVE := 6.0


## Tous les avis pour un lieu (Statistiques.PAYS ou l'id d'une ville), les plus urgents d'abord.
static func analyser(st: Statistiques, lieu: String) -> Array:
	var out: Array = []
	if st == null or st.historique.is_empty():
		return out
	var j := st.dernier_jour()
	var hab := st.dernier(lieu, "habitants")
	var ville := lieu != Statistiques.PAYS
	var nom := String(st.noms.get(lieu, "la ville")) if ville else "le pays"
	_argent(st, lieu, nom, out, j)
	if not is_nan(hab) and hab > 0.0:
		_emploi(st, lieu, out, j)
		_logement(st, lieu, out, j)
		_satisfaction(st, lieu, out, j)
		_ecole(st, lieu, out, j)
		_pollution(st, lieu, out, j)
		_tendances(st, lieu, nom, out, j)
	_reseaux(st, out, j)
	_trafic(st, out, j)
	_dechets(st, out, j)
	_elections(st, out, j)
	if out.is_empty() or _max_gravite(out) == 0:
		if is_nan(hab) or hab <= 0.0:
			out.append(_avis("vide", 0, "ville", "Personne n'habite encore ici",
				"Pas d'habitants, pas de problèmes. Pas d'impôts non plus.",
				"Pose des maisons ou dessine une zone résidentielle (B), près d'une route.", "construire", j))
		else:
			out.append(_avis("calme", 0, "ville", _choix(j, "calme", ["Tout va bien", "Rien à signaler", "Calme plat"]),
				_choix(j, "calme_t", ["Aucun problème sérieux. Profites-en : ça ne dure jamais.",
					"Les habitants ont même cessé de se plaindre de la météo. C'est dire.",
					"Le conseil municipal s'ennuie ferme. C'est plutôt bon signe."]),
				"C'est le bon moment pour préparer la suite : nouveaux quartiers, transports, services.", "", j))
	out.sort_custom(func(a, b) -> bool: return int(a.gravite) > int(b.gravite))
	return out


static func _max_gravite(liste: Array) -> int:
	var m := 0
	for a in liste:
		m = maxi(m, int(a.gravite))
	return m


static func _avis(id: String, gravite: int, theme: String, titre: String, texte: String, conseil: String, panneau: String, _j := 0) -> Dictionary:
	return {"id": id, "gravite": gravite, "theme": theme, "titre": titre, "texte": texte, "conseil": conseil, "panneau": panneau}


## Une phrase parmi plusieurs, qui change de temps en temps (toutes les semaines de jeu).
static func _choix(j: int, cle: String, phrases: Array) -> String:
	var h := absi(hash(cle) + j / 7)
	return String(phrases[h % phrases.size()])


static func _pct(v: float) -> String:
	return "%d %%" % roundi(v)


# --- Règles ------------------------------------------------------------------------------------

static func _argent(st: Statistiques, lieu: String, nom: String, out: Array, j: int) -> void:
	var caisse := st.dernier(lieu, "caisse")
	var solde := st.dernier(lieu, "solde")
	if is_nan(caisse) or (st.pays != null and st.pays.illimite()):
		return
	var rouge := 0
	if st.budget != null and lieu != Statistiques.PAYS:
		rouge = int(st.budget.etat_de(int(lieu)).get("jours_rouge", 0))
	elif st.budget != null and not BudgetCommunal.multi():
		rouge = st.budget.jours_rouge
	if caisse < 0.0:
		var reste := BudgetCommunal.JOURS_ROUGE_TUTELLE - rouge
		out.append(_avis("caisse_rouge", 2, "argent", "La caisse est dans le rouge",
			"%s doit %s. %s" % [nom.capitalize(), Statistiques.format("caisse", -caisse),
				("Encore %d jours comme ça et le préfet prend les commandes." % reste) if lieu != Statistiques.PAYS and reste > 0
				else _choix(j, "rouge", ["Le banquier ne répond plus au téléphone.", "Même la tirelire de la mairie est vide."])],
			"Relève un peu les impôts ou emprunte (M), et retarde les grands travaux. Le pays peut aussi verser une subvention (Maj+P).",
			"budget", j))
		return
	if not is_nan(solde) and solde < 0.0:
		var mois := caisse / -solde
		if mois < MOIS_RESERVE:
			out.append(_avis("faillite", 2 if mois < 2.0 else 1, "argent",
				"Plus que %s de réserve" % ("%d mois" % maxi(1, floori(mois)) if mois >= 1.0 else "quelques jours"),
				"Le budget perd %s par mois. %s" % [Statistiques.format("solde", -solde), _choix(j, "faillite",
					["Au rythme actuel, la caisse sera vide avant les prochaines vacances.",
					"Le trésorier commence à compter les trombones."])],
				"Regarde le bilan du mois (M) : les impôts, l'entretien des voies et les emprunts sont les leviers les plus rapides.",
				"budget", j))
		elif mois < 24.0:
			out.append(_avis("deficit", 1, "argent", "Le budget est en déficit",
				"On dépense %s de plus qu'on ne gagne chaque mois. La réserve tient encore %d mois." % [
					Statistiques.format("solde", -solde), floori(mois)],
				"Rien d'urgent, mais un budget se redresse plus facilement avant qu'il ne soit à sec (M).", "budget", j))
	elif not is_nan(solde) and solde > 0.0 and caisse > 0.0:
		var avant := st.il_y_a(lieu, "caisse", 30)
		if not is_nan(avant) and avant < 0.0:
			out.append(_avis("caisse_verte", 0, "argent", "La caisse est sortie du rouge",
				"Le trésorier a retrouvé le sourire, et même un stylo qui marche.", "Garde une réserve de quelques mois avant de relancer les grands travaux.", "budget", j))


static func _emploi(st: Statistiques, lieu: String, out: Array, j: int) -> void:
	var ch := st.dernier(lieu, "chomage")
	if is_nan(ch):
		return
	var emplois := st.dernier(lieu, "emplois_libres")
	if ch >= CHOMAGE_ATTENTION:
		var urgent := ch >= CHOMAGE_URGENT
		var conseil := "Crée des emplois : zone d'activité ou commerces (B), ateliers et usines (P)."
		if not is_nan(emplois) and emplois > 0.0:
			conseil = "Il reste %s emplois libres : vérifie qu'ils sont accessibles (routes, lignes de bus avec L), ou que les métiers correspondent." % Statistiques.format("emplois_libres", emplois)
		out.append(_avis("chomage", 2 if urgent else 1, "emploi", "Chômage à %s" % _pct(ch),
			_choix(j, "chomage", ["Le café du commerce ne désemplit pas, et ce n'est pas bon signe.",
				"Les CV s'empilent à la mairie, certains sont même plastifiés.",
				"Beaucoup d'habitants cherchent du travail, et ils commencent à se demander à quoi sert le maire."]),
			conseil, "construire", j))
	elif ch < 3.0 and not is_nan(emplois) and emplois > 20.0:
		out.append(_avis("plein_emploi", 0, "emploi", "Presque le plein emploi",
			"Les entreprises cherchent même du monde : %s postes libres." % Statistiques.format("emplois_libres", emplois),
			"Des logements en plus attireraient de nouveaux habitants pour ces postes (B, zone résidentielle).", "construire", j))


static func _logement(st: Statistiques, lieu: String, out: Array, j: int) -> void:
	var libres := st.dernier(lieu, "logements_libres")
	var emplois := st.dernier(lieu, "emplois_libres")
	var hab := st.dernier(lieu, "habitants")
	if is_nan(libres):
		return
	if libres <= 0.0 and not is_nan(emplois) and emplois >= 10.0:
		out.append(_avis("logements", 1, "logement", "Plus un logement libre",
			_choix(j, "logement", ["Des gens voudraient venir travailler ici mais n'ont nulle part où dormir. Certains repèrent déjà les bancs du parc.",
				"La liste d'attente pour un appartement est plus longue que celle du médecin."]),
			"Construis des logements ou une zone résidentielle (B) près des %s emplois libres." % Statistiques.format("emplois_libres", emplois),
			"construire", j))
	elif libres > maxf(20.0, hab * 0.3):
		out.append(_avis("vacants", 1, "logement", "Beaucoup de logements vides",
			"%s logements attendent leurs habitants. Les volets fermés, ça fait triste dans la rue." % Statistiques.format("logements_libres", libres),
			"Les gens s'installent là où il y a du travail et des services : emplois (B, P), écoles et commerces avant de nouveaux logements.",
			"construire", j))


static func _satisfaction(st: Statistiques, lieu: String, out: Array, j: int) -> void:
	var s := st.dernier(lieu, "satisfaction")
	if is_nan(s):
		return
	# Thème le plus mal noté et ses raisons (dernier sondage).
	var pire := ""
	var raisons := ""
	if st.avis != null:
		var sd := st.avis.sondage()
		var note_min := 101
		for th in sd.get("themes", {}):
			var n := int(sd.themes[th].note)
			if n < note_min:
				note_min = n
				pire = String(th)
				var r: Array = sd.themes[th].get("raisons", [])
				raisons = String(r[0][0]) if not r.is_empty() else ""
	var quoi := ""
	if pire != "":
		quoi = " Le plus gros sujet de plainte : %s%s." % [Avis.theme_nom(pire).to_lower(), (" (« %s »)" % raisons) if raisons != "" else ""]
	if s < SATISFACTION_URGENT:
		out.append(_avis("colere", 2, "avis", "Les habitants sont en colère (%d/100)" % roundi(s),
			"On parle de manifestation devant la mairie, et ce ne sera pas pour te remercier.%s" % quoi,
			"Ouvre l'avis des habitants (Y) pour voir ce qui coince, et règle d'abord le thème le plus mal noté.", "avis", j))
	elif s < SATISFACTION_ATTENTION:
		out.append(_avis("grogne", 1, "avis", "La grogne monte (%d/100)" % roundi(s),
			"Rien de grave pour l'instant, mais on soupire beaucoup à la boulangerie.%s" % quoi,
			"L'avis des habitants (Y) montre les raisons, quartier par quartier.", "avis", j))
	elif s >= 75.0:
		out.append(_avis("contents", 0, "avis", "Les habitants sont contents (%d/100)" % roundi(s),
			_choix(j, "contents", ["On a même vu quelqu'un sourire à la sortie du conseil municipal.",
				"Ta cote de popularité ferait pâlir un champion du monde."]),
			"C'est le bon moment pour une décision impopulaire mais nécessaire, s'il en faut une.", "avis", j))


static func _ecole(st: Statistiques, lieu: String, out: Array, j: int) -> void:
	var n := st.dernier(lieu, "sans_ecole")
	if is_nan(n) or n < 1.0:
		return
	out.append(_avis("ecole", 2 if n >= 30.0 else 1, "services", "%s sans école" % ("%d enfant" % roundi(n) + ("s" if n >= 2.0 else "")),
		_choix(j, "ecole", ["Ils sont ravis. Leurs parents, beaucoup moins.", "L'école buissonnière, c'est mignon une semaine."]),
		"Construis une école (B → Services) ou agrandis celles qui existent ; Maj+U montre les places et les trajets.", "services", j))


static func _pollution(st: Statistiques, lieu: String, out: Array, j: int) -> void:
	var p := st.dernier(lieu, "pollution")
	if is_nan(p) or p < POLLUTION_ATTENTION:
		return
	out.append(_avis("pollution", 2 if p >= POLLUTION_URGENT else 1, "environnement", "L'air est pollué chez les habitants (%d/100)" % roundi(p),
		_choix(j, "pollution", ["Les habitants toussent, et ce n'est pas la saison des rhumes.", "Le linge sèche gris. Les mamies ont remarqué."]),
		"Éloigne l'industrie et les grands axes des logements, plante des arbres, développe les transports en commun. La carte de l'air est dans N.",
		"cartes", j))


static func _reseaux(st: Statistiques, out: Array, j: int) -> void:
	var P := Statistiques.PAYS
	for spec in [["electricite", "Électricité", "Il manque du courant : les habitants dînent à la bougie. Romantique une fois, pénible tous les soirs.",
			"Construis une centrale ou raccorde les quartiers coupés (O, réseaux)."],
			["eau", "Eau", "Il manque de l'eau : les douches sont devenues très courtes.",
			"Ajoute un captage ou un château d'eau, et vérifie les canalisations (O, réseaux)."]]:
		var v := st.dernier(P, spec[0])
		if is_nan(v) or v >= RESEAU_ATTENTION:
			continue
		out.append(_avis(spec[0], 2 if v < RESEAU_URGENT else 1, "reseaux", "%s : seulement %s des besoins couverts" % [spec[1], _pct(v)],
			spec[2], spec[3], "reseaux", j))
	var c := st.dernier(P, "coupures")
	if not is_nan(c) and c >= 1.0 and out.filter(func(a) -> bool: return a.theme == "reseaux").is_empty():
		out.append(_avis("coupures", 1, "reseaux", "%d bâtiment%s coupé%s du réseau" % [roundi(c), "s" if c >= 2.0 else "", "s" if c >= 2.0 else ""],
			"La production suffit, mais le courant ou l'eau n'arrivent pas jusqu'à eux.",
			"Il manque sans doute un tronçon de ligne ou de canalisation (O, calque des réseaux dans N).", "reseaux", j))


static func _trafic(st: Statistiques, out: Array, j: int) -> void:
	var c := st.dernier(Statistiques.PAYS, "congestion")
	if is_nan(c) or c < BOUCHONS_ATTENTION:
		return
	var t := st.dernier(Statistiques.PAYS, "trajet")
	out.append(_avis("bouchons", 2 if c >= BOUCHONS_URGENT else 1, "transports", "Bouchons : +%s de temps de trajet" % _pct(c),
		"%s%s" % [_choix(j, "bouchons", ["Les automobilistes ont le temps de finir leur journal aux feux rouges.",
			"Le klaxon est devenu l'instrument de musique le plus pratiqué de la ville."]),
			(" Trajet moyen : %s." % Statistiques.format("trajet", t)) if not is_nan(t) else ""],
		"Le panneau Trafic (Maj+L) montre les pires tronçons : élargis-les, ajoute un itinéraire bis, ou une ligne de bus (L).",
		"trafic", j))


static func _dechets(st: Statistiques, out: Array, j: int) -> void:
	var d := st.dernier(Statistiques.PAYS, "dechets")
	if is_nan(d) or d < 1.0:
		return
	out.append(_avis("dechets", 2 if d >= 10.0 else 1, "environnement", "%d poubelle%s déborde%s" % [roundi(d), "s" if d >= 2.0 else "", "nt" if d >= 2.0 else ""],
		_choix(j, "dechets", ["Les chats du quartier n'ont jamais été aussi gros.", "Ça commence à sentir, et pas la lavande."]),
		"Ajoute une benne ou un centre de collecte, ou vérifie qu'ils ont accès aux rues (X, déchets).", "dechets", j))


static func _elections(st: Statistiques, out: Array, j: int) -> void:
	if st.avis == null or st.avis.elections == null or not st.avis.elections.actives():
		return
	var jours := st.avis.elections.jours_avant_vote()
	if jours < 0 or jours > 30:
		return
	var s := st.dernier(Statistiques.PAYS, "satisfaction")
	if is_nan(s) or s >= 55.0:
		return
	out.append(_avis("elections", 2 if s < 45.0 else 1, "politique", "Élections dans %d jour%s, et tu n'es pas favori" % [jours, "s" if jours > 1 else ""],
		"Satisfaction à %d/100 : l'opposition prépare déjà ses affiches." % roundi(s),
		"Tiens tes promesses de campagne et règle les plaintes les plus fréquentes (Y).", "avis", j))


## Tendances inquiétantes (ou encourageantes) sur 30 jours.
static func _tendances(st: Statistiques, lieu: String, nom: String, out: Array, j: int) -> void:
	var h := st.dernier(lieu, "habitants")
	var dh := st.evolution(lieu, "habitants", 30)
	if not is_nan(dh) and h > 50.0:
		var avant := h - dh
		if avant > 0.0 and dh / avant <= -0.05:
			out.append(_avis("exode", 1, "ville", "La population baisse (%s en 30 jours)" % Statistiques.format_ecart("habitants", dh),
				"Des habitants quittent %s. Les déménageurs, eux, sont ravis." % nom,
				"Regarde ce qui fâche dans l'avis des habitants (Y) : logement, emploi et services sont les premières causes de départ.", "avis", j))
		elif avant > 0.0 and dh / avant >= 0.15:
			out.append(_avis("croissance", 0, "ville", "La population grimpe (%s en 30 jours)" % Statistiques.format_ecart("habitants", dh),
				"%s a la cote. Pense à ce dont ces nouveaux habitants auront besoin." % nom.capitalize(),
				"Écoles, commerces, transports et réseaux doivent suivre (Maj+U, O, L).", "", j))
	var ds := st.evolution(lieu, "satisfaction", 7)
	if not is_nan(ds) and ds <= -10.0:
		out.append(_avis("chute_satisfaction", 1, "avis", "La satisfaction chute (%s en une semaine)" % Statistiques.format_ecart("satisfaction", ds),
			"Quelque chose a changé récemment, et ça ne plaît pas.", "Une hausse d'impôts, une coupure ou une fermeture ? L'avis des habitants (Y) donne les raisons.", "avis", j))
