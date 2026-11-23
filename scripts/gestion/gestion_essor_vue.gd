class_name GestionEssorVue
extends RefCounted
## Onglets « Essor » (recherche, campagnes, défi, paliers) et « Avis » (avis
## des clients, ce qui plaît ou fâche, classement des concurrents) de l'écran
## de gestion. Voir GestionEssor.


static func _ligne_bouton(v: GestionVue, texte: String, bouton: String, icone: String, nom: String, actif: bool, quand: Callable) -> Button:
	var row := HBoxContainer.new()
	row.name = nom
	v._carte_corps.add_child(row)
	var l := Label.new()
	l.text = texte
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(210, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	var b := Button.new()
	b.name = "Bouton"
	b.text = bouton
	b.icon = Icones.get_icon(icone, 16, UiStyle.ACCENT)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.disabled = not actif
	b.pressed.connect(quand)
	row.add_child(b)
	return b


static func _barre(v: GestionVue, fait: float, cible: float, nom: String) -> void:
	var pb := ProgressBar.new()
	pb.name = nom
	pb.min_value = 0.0
	pb.max_value = maxf(0.001, cible)
	pb.value = clampf(fait, 0.0, cible)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(GestionVue.CARTE_W - 30, 10)
	v._carte_corps.add_child(pb)


# --- Essor ----------------------------------------------------------------------------------------

static func carte_essor(v: GestionVue) -> void:
	var g := v.gestion
	var bid := v.bid
	var st := g.etat(bid)
	var e := GestionEssor.es(st)
	var ville := g.source(bid) == "ville"
	# Recherche.
	v._titre("Recherche", 17)
	v._texte("%.1f points par jour (équipe, formation, pièces). Un projet à la fois ; en gestion automatique, %s choisit tout seul." % [GestionEssor.points_jour(g, bid), v._le()], true, 12)
	var cur := String(e.rech)
	if cur != "":
		var r := GestionEssor.recherche(cur)
		v._texte("En cours : %s (%d / %d points)" % [String(r.nom), int(e.pts), int(r.cout)], false, 13)
		_barre(v, float(e.pts), float(r.cout), "Recherche_barre")
	for r in GestionEssor.RECHERCHES:
		var id := String(r.id)
		var fait := GestionEssor.faite(st, id)
		var why := GestionEssor.refus_recherche(st, id)
		var eff := _effets_txt(GestionEssor.effets_recherche(g, bid, r))
		var txt := "%s %s — %s%s" % ["✔" if fait else ("▶" if id == cur else "○"), String(r.nom), GestionEssor.desc_recherche(g, bid, r),
			("" if eff == "" else " (" + eff + ")")]
		if fait:
			var l := v._texte(txt, false, 12)
			l.add_theme_color_override("font_color", UiStyle.GOOD)
			continue
		var bid2 := bid
		_ligne_bouton(v, txt + ("" if why == "" else " · " + why), "%d pts" % int(r.cout), "chercher", "Recherche_" + id, why == "" and id != cur, func() -> void:
			var res := GestionEssor.lancer_recherche(g, bid2, id)
			v._dire("Recherche lancée : %s." % String(r.nom) if bool(res.ok) else "Impossible : %s." % String(res.get("error", "")))
			v._remplir_carte())
	v._carte_corps.add_child(HSeparator.new())
	# Campagnes.
	v._titre("Campagnes" if ville else "Publicité", 17)
	var c := GestionEssor.campagne_en_cours(g, bid)
	if not c.is_empty():
		var cc := GestionEssor.campagne(g, bid, String(c.id))
		v._texte("En cours : %s, encore %d jours (%s par jour)%s." % [String(cc.nom), int(c.fin) - g.jour, BuildingSystem.format_money(int(c.cout)),
			" · moitié d'effet, le public s'en lasse" if float(c.force) < 1.0 else ""], false, 13)
		var b := v._bouton("Arrêter la campagne", "fermer")
		b.name = "Campagne_arreter"
		b.pressed.connect(func() -> void:
			GestionEssor.arreter_campagne(g, bid)
			v._remplir_carte())
		v._carte_corps.add_child(b)
	else:
		v._texte("Payée chaque jour tant qu'elle dure, sur le compte %s. Refaire la même avant 30 jours : moitié d'effet." % v._du(), true, 12)
	for cp in GestionEssor.campagnes_possibles(g, bid):
		var id := String(cp.id)
		var cout := GestionEssor.cout_campagne(g, bid, cp)
		var txt := "%s — %d jours, %s par jour (%s)%s" % [String(cp.nom), int(cp.jours), BuildingSystem.format_money(cout), _effets_txt(cp.effets),
			" · lassé" if GestionEssor.lassitude(g, bid, id) else ""]
		_ligne_bouton(v, txt, "Lancer", "megaphone", "Campagne_" + id, c.is_empty(), func() -> void:
			var res := GestionEssor.lancer_campagne(g, bid, id)
			v._dire(("Campagne lancée : %s." % String(cp.nom)) if bool(res.ok) else "Impossible : %s." % String(res.get("error", "")))
			v._remplir_carte())
	v._carte_corps.add_child(HSeparator.new())
	# Défi.
	v._titre("Défi", 17)
	var df: Dictionary = e.defi
	if df.is_empty():
		v._texte("Pas de défi pour l'instant. Le prochain arrive dans %d jours." % maxi(0, int(e.defi_prochain) - g.jour), true, 12)
	elif String(df.etat) == "offert":
		v._texte("Proposé : %s. Prime : %s, et des clients ravis pendant %d jours." % [GestionEssor.texte_defi(g, bid, df), BuildingSystem.format_money(int(df.prime)), GestionEssor.BONUS_DEFI_JOURS], false, 13)
		var row := HBoxContainer.new()
		row.name = "Defi"
		v._carte_corps.add_child(row)
		var oui := v._bouton("Accepter", "plus")
		oui.name = "Defi_accepter"
		oui.pressed.connect(func() -> void:
			GestionEssor.accepter_defi(g, bid)
			v._remplir_carte())
		row.add_child(oui)
		var non := v._bouton("Refuser", "fermer")
		non.name = "Defi_refuser"
		non.pressed.connect(func() -> void:
			GestionEssor.refuser_defi(g, bid)
			v._remplir_carte())
		row.add_child(non)
	else:
		var a := GestionEssor.avance_defi(g, bid)
		var note := String(GestionEssor.defi(String(df.id)).mesure) == "note"
		v._texte("En cours : %s — %s, encore %d jours. Prime : %s." % [GestionEssor.texte_defi(g, bid, df),
			("%.1f / %.1f" % [float(a[0]), float(a[1])]) if note else ("%d / %d" % [int(a[0]), int(a[1])]), maxi(0, int(df.fin) - g.jour),
			BuildingSystem.format_money(int(df.prime))], false, 13)
		_barre(v, float(a[0]), float(a[1]), "Defi_barre")
	v._texte("Défis réussis : %d · manqués : %d" % [int(e.defis_ok), int(e.defis_rates)], true, 12)
	if int(e.bonus_fin) >= g.jour:
		var l := v._texte("★ Défi réussi : clients ravis encore %d jours." % (int(e.bonus_fin) - g.jour), false, 12)
		l.add_theme_color_override("font_color", UiStyle.GOOD)
	v._carte_corps.add_child(HSeparator.new())
	# Paliers.
	v._titre("Paliers", 17)
	var pal := GestionEssor.paliers(g, bid)
	if pal.is_empty():
		v._texte("Aucun palier encore.", true, 12)
	for p in pal:
		var l := v._texte("✔ %s (%s)" % [String(p.nom), _effets_txt(p.effets)], false, 12)
		l.add_theme_color_override("font_color", UiStyle.GOOD)
	for t in GestionEssor.prochains_paliers(g, bid):
		v._texte("○ " + String(t), true, 12)


static func _effets_txt(eff: Dictionary) -> String:
	var out: Array = []
	for k in eff:
		var x := float(eff[k])
		match String(k):
			"pannes":
				out.append("−%d %% de pannes" % roundi(x * 100.0))
			"economie":
				out.append("−%d %% de charges" % roundi(x * 100.0))
			"points":
				out.append("+%d %% de recherche" % roundi(x * 100.0))
			"equipage":
				out.append("+%d de garde" % roundi(x))
			"ventes":
				out.append("+%s par client" % BuildingSystem.format_money(roundi(x)))
			"confort":
				out.append("+%.2f de confort" % x)
			_:
				out.append("+%d %% %s" % [roundi(x * 100.0), String(GestionTypes.EFFETS.get(k, k))])
	return ", ".join(out)


# --- Avis -----------------------------------------------------------------------------------------

static func carte_avis(v: GestionVue) -> void:
	var g := v.gestion
	var bid := v.bid
	var st := g.etat(bid)
	var e := GestionEssor.es(st)
	var ville := g.source(bid) == "ville"
	v._titre("Ce qu'en disent les habitants" if ville else "Avis des clients", 17)
	var moy := GestionEssor.moyenne_avis(st)
	if moy > 0.0:
		v._texte("Moyenne des %d derniers avis : %s %.1f / 5" % [(e.avis as Array).size(), "★".repeat(roundi(moy)), moy], false, 13)
	var r := GestionEssor.ressenti(g, bid)
	if not (r.plus as Array).is_empty():
		var l := v._texte("Ce qui plaît : " + ", ".join(r.plus).to_lower() + ".", false, 12)
		l.add_theme_color_override("font_color", UiStyle.GOOD)
	if not (r.moins as Array).is_empty():
		var l2 := v._texte("Ce qui fâche : " + ", ".join(r.moins).to_lower() + ".", false, 12)
		l2.add_theme_color_override("font_color", Color("ffb4a2"))
	if (e.avis as Array).is_empty():
		v._texte("Pas encore d'avis : ils arrivent au fil des jours.", true, 12)
	for a in (e.avis as Array).slice(0, 8):
		v._texte("%s  %s, jour %d : « %s »" % ["★".repeat(int(a[1])) + "☆".repeat(5 - int(a[1])), String(a[2]), int(a[0]), String(a[3])], false, 12)
	v._carte_corps.add_child(HSeparator.new())
	var cl := GestionEssor.concurrents(g, bid)
	var rg := GestionEssor.rang(g, bid)
	v._titre("Classement (%d sur %d)" % [rg.x, rg.y] if rg.y > 1 else "Classement", 17)
	if cl.size() <= 1:
		v._texte("Pas d'autre établissement de ce genre dans la partie : tu es seul sur le marché." if not ville else "Seul service de ce genre dans la partie.", true, 12)
		return
	var tot := 0
	for c in cl:
		tot += int(c.clients)
	var i := 0
	for c in cl:
		i += 1
		if i > 8 and not bool(c.moi):
			continue
		var part := ("" if ville or tot <= 0 else " · %d %% des clients" % roundi(100.0 * float(c.clients) / float(tot)))
		var l := v._texte("%d. %s — %.1f / 5, %s%s" % [i, String(c.nom), float(c.note), "★".repeat(int(c.etoiles)), part], false, 12)
		if bool(c.moi):
			l.add_theme_color_override("font_color", UiStyle.ACCENT)
