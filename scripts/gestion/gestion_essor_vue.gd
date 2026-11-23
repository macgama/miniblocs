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
	carte_argent(v)


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
	carte_segments(v)
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


# --- Équipe en personnes (onglet Équipe) ----------------------------------------------------------

static func _ligne_pm(v: GestionVue, texte: String, nom: String, moins: Callable, plus: Callable) -> void:
	var row := HBoxContainer.new()
	row.name = nom
	v._carte_corps.add_child(row)
	var l := Label.new()
	l.text = texte
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(230, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	for d in [["moins", "Baisser", moins], ["plus", "Monter", plus]]:
		var b := UiStyle.icon_button(String(d[0]), String(d[1]), "", 16, 28)
		b.name = String(d[0]).capitalize()
		b.pressed.connect(d[2])
		row.add_child(b)


static func carte_equipe(v: GestionVue) -> void:
	var g := v.gestion
	var bid := v.bid
	var e := GestionEssor.es(g.etat(bid))
	var l := GestionPlus.equipe(g, bid)
	v._carte_corps.add_child(HSeparator.new())
	v._titre("Les personnes", 17)
	v._texte("Moral moyen %.1f / 5 · fatigue %d %% · %d démission(s). Le moral suit le salaire, la formation, la fatigue et les pannes ; trop bas une semaine, la personne s'en va." % [
		GestionPlus.moral_moyen(g, bid), roundi(GestionPlus.fatigue_moyenne(g, bid)), int(e.demissions)], true, 12)
	# Vrais noms des employés quand le bâtiment en a.
	var noms: Array = []
	for x in v._employes():
		if not bool(x.get("extra", false)) and String(x.nom) != "":
			noms.append(String(x.nom))
	var dem: Dictionary = e.demande
	if not dem.is_empty() and int(dem.i) < l.size():
		var qui := String(noms[int(dem.i)]) if int(dem.i) < noms.size() else String(l[int(dem.i)].nom)
		v._texte("%s demande une augmentation de 10 %% (%s par jour)." % [qui, BuildingSystem.format_money(roundi(GestionPlus.prix_augmentation(g, bid)))], false, 13)
		var row := HBoxContainer.new()
		row.name = "Augmentation"
		v._carte_corps.add_child(row)
		for c in [[true, "Accorder", "plus"], [false, "Refuser", "fermer"]]:
			var b := v._bouton(String(c[1]), String(c[2]))
			b.name = "Augmentation_" + ("oui" if bool(c[0]) else "non")
			var oui := bool(c[0])
			b.pressed.connect(func() -> void:
				GestionPlus.repondre_augmentation(g, bid, oui)
				v._remplir_carte())
			row.add_child(b)
	var pz := int(e.pauses)
	_ligne_pm(v, "Pauses : %s (plus longues : moins de fatigue, service un peu plus lent)" % GestionPlus.PAUSES[clampi(pz, 0, 2)], "Pauses",
		func() -> void:
			GestionPlus.set_pauses(g, bid, pz - 1)
			v._remplir_carte(),
		func() -> void:
			GestionPlus.set_pauses(g, bid, pz + 1)
			v._remplir_carte())
	var lib := int(e.mois_fin) <= g.jour
	v._texte(("Employé du mois : prime de %s, +moral pour lui et toute l'équipe." % BuildingSystem.format_money(GestionPlus.prix_prime(g, bid))) if lib
		else "Employé du mois déjà élu (encore %d jours)." % (int(e.mois_fin) - g.jour), true, 12)
	for i in mini(l.size(), 14):
		var p: Dictionary = l[i]
		var t: Dictionary = GestionPlus.TRAITS.get(String(p.trait), {})
		var nm := String(noms[i]) if i < noms.size() else String(p.nom)
		var txt := "%s — %s (%s) · moral %s · fatigue %d %%%s%s" % [nm, String(t.get("nom", "")), String(t.get("desc", "")), "●".repeat(roundi(float(p.moral))) + "○".repeat(5 - roundi(float(p.moral))),
			roundi(float(p.fatigue)), (" · +%d %% de salaire" % roundi(float(p.aug) * 100.0)) if float(p.aug) > 0.0 else "", " · ★ employé du mois" if int(p.mois) >= g.jour else ""]
		var idx := i
		var b := _ligne_bouton(v, txt, "★", "trophee", "Personne_%d" % i, lib, func() -> void:
			var r := GestionPlus.employe_du_mois(g, bid, idx)
			v._dire("Bravo à %s !" % nm if bool(r.ok) else "Impossible : %s." % String(r.get("error", "")))
			v._remplir_carte())
		b.tooltip_text = "Élire employé du mois"
	if l.size() > 14:
		v._texte("… et %d autres." % (l.size() - 14), true, 12)


# --- Argent et bâtiment (onglet Essor) -------------------------------------------------------------

static func carte_argent(v: GestionVue) -> void:
	var g := v.gestion
	var bid := v.bid
	var ville := g.source(bid) == "ville"
	v._carte_corps.add_child(HSeparator.new())
	# Prix de chaque service.
	var sv := GestionPlus.services(g, bid)
	if not sv.is_empty():
		v._titre("Prix des services", 17)
		v._texte("En plus du prix principal : plus cher, chaque client dépense plus mais il est moins content.", true, 12)
		for pid in sv:
			var id := String(pid)
			var f := GestionPlus.tarif(g, bid, id)
			_ligne_pm(v, "%s : %d %% du prix habituel" % [String(GestionTypes.piece(v.genre, id).get("court", id)), roundi(f * 100.0)], "Tarif_" + id,
				func() -> void:
					GestionPlus.changer_tarif(g, bid, id, -1)
					v._remplir_carte(),
				func() -> void:
					GestionPlus.changer_tarif(g, bid, id, 1)
					v._remplir_carte())
		v._carte_corps.add_child(HSeparator.new())
	# Banque.
	if not ville:
		v._titre("Banque", 17)
		var pr := GestionPlus.pret(g, bid)
		if not pr.is_empty():
			v._texte("Prêt de %s à %.1f %% : encore %s à rembourser (%s par jour, dans les charges)." % [BuildingSystem.format_money(int(pr.montant)), float(pr.taux) * 100.0,
				BuildingSystem.format_money(int(pr.reste)), BuildingSystem.format_money(int(pr.jour))], false, 13)
			var b := v._bouton("Tout rembourser maintenant", "banque")
			b.name = "Pret_rembourser"
			b.pressed.connect(func() -> void:
				var r := GestionPlus.rembourser_pret(g, bid)
				v._dire("Prêt remboursé." if bool(r.ok) else "Impossible : %s." % String(r.get("error", "")))
				v._remplir_carte())
			v._carte_corps.add_child(b)
		else:
			v._texte("De l'argent tout de suite sur le compte %s, remboursé chaque jour pendant %d jours avec les intérêts de l'époque." % [v._du(), GestionPlus.PRET_JOURS], true, 12)
			var o := GestionPlus.offres_pret(g, bid)
			for i in o.size():
				var of: Dictionary = o[i]
				var idx := i
				_ligne_bouton(v, "%s à %.1f %% : %s par jour (total %s)" % [BuildingSystem.format_money(int(of.montant)), float(of.taux) * 100.0,
					BuildingSystem.format_money(int(of.jour)), BuildingSystem.format_money(int(of.total))], "Emprunter", "banque", "Pret_%d" % i, true, func() -> void:
						var r := GestionPlus.emprunter(g, bid, idx)
						v._dire("Prêt accordé." if bool(r.ok) else "Impossible : %s." % String(r.get("error", "")))
						v._remplir_haut()
						v._remplir_carte())
		v._carte_corps.add_child(HSeparator.new())
	# Agrandissement.
	v._titre("Agrandissement", 17)
	var n := GestionPlus.extensions(g, bid)
	var px := GestionPlus.prix_extension(g, bid)
	if px <= 0:
		v._texte("Agrandi au maximum (%d extensions) : chaque pièce peut monter jusqu'au niveau %d." % [n, 5 + n], false, 13)
	else:
		var r := g.repartition(bid, px)
		var qui := ("payé par %s" % v._le()) if int(r.ville) <= 0 else ("%s par %s, %s avancés par la ville" % [BuildingSystem.format_money(int(r.batiment)), v._le(), BuildingSystem.format_money(int(r.ville))])
		_ligne_bouton(v, "Extension %d / %d : chaque pièce gagne un niveau possible, et un peu de confort. %s (%s)." % [n + 1, GestionPlus.EXT_MAX, BuildingSystem.format_money(px), qui],
			"Agrandir", "construire", "Agrandir", true, func() -> void:
				var res := GestionPlus.agrandir(g, bid)
				if bool(res.ok):
					v._dire("Agrandissement inauguré !")
					v._reconstruire()
					v._remplir_bas()
				else:
					v._dire("Impossible : %s." % String(res.get("error", "")))
				v._remplir_carte())
	v._carte_corps.add_child(HSeparator.new())
	# Trophées.
	v._titre("Trophées", 17)
	var tr := GestionPlus.trophees(g, bid)
	for t in GestionPlus.TROPHEES:
		var a := String(t.id) in tr
		var l := v._texte("%s %s" % ["★" if a else "○", String(t.nom)], not a, 12)
		if a:
			l.add_theme_color_override("font_color", UiStyle.GOOD)


# --- Types de clients (onglet Avis) ----------------------------------------------------------------

static func carte_segments(v: GestionVue) -> void:
	var g := v.gestion
	var bid := v.bid
	var ville := g.source(bid) == "ville"
	v._carte_corps.add_child(HSeparator.new())
	v._titre("Qui vient" if not ville else "Pour qui", 17)
	var pa := GestionPlus.parts(g, bid, GestionPlus.mois(g, bid))
	for sg in GestionPlus.segments(g, bid):
		var a := GestionPlus.avis_segment(g, bid, sg)
		var f := float(a.fit)
		var aime: Array = []
		for pid in a.aime:
			aime.append(String(GestionTypes.piece(v.genre, String(pid)).get("court", pid)).to_lower())
		var manque: Array = []
		for pid in (a.manque as Array).slice(0, 2):
			manque.append(String(GestionTypes.piece(v.genre, String(pid)).get("court", pid)).to_lower())
		var txt := "%s : %d %% · %s" % [String(sg.nom), roundi(float(pa.get(String(sg.id), 0.0)) * 100.0), "★".repeat(roundi(f * 5.0)) + "☆".repeat(5 - roundi(f * 5.0))]
		if not aime.is_empty():
			txt += " · aiment : " + ", ".join(aime.slice(0, 3))
		if not manque.is_empty():
			txt += " · aimeraient : " + ", ".join(manque)
		if float(sg.prix) >= 1.4 and GestionPlus.facteur_prix(g, bid) > 1.15:
			txt += " · trouvent ça cher"
		v._texte(txt, false, 12)
	v._texte("Les parts changent avec la saison (familles et touristes l'été…). Construire et monter les pièces qu'un type aime le rend plus content.", true, 12)


# --- Trophées exposés devant l'entrée (maquette) ----------------------------------------------------

static func poser_trophees(v: GestionVue) -> void:
	var dio := v.diorama
	var vieux := dio._statique.get_node_or_null("Trophees")
	if vieux != null:
		dio._statique.remove_child(vieux)
		vieux.queue_free()
	var tr := GestionPlus.trophees(v.gestion, v.bid)
	if tr.is_empty():
		return
	var k := LpKit.new(11)
	var porte := dio._porte()
	var x := porte.x + 2.2
	var z := porte.z + 1.4
	var n := 0
	for id in tr:
		var t := GestionPlus.trophee(String(id))
		var col := Color(String(t.get("couleur", "e8c040")))
		var essais := 0
		while not dio.libre(Vector2(x, z), 0.3) and essais < 12:
			x += 0.9
			essais += 1
		var p := Vector3(x, 0, z)
		k.box(p + Vector3(0, 0.25, 0), Vector3(0.55, 0.5, 0.55), Color("3d3f4a"))
		match String(t.cond):
			"defis", "premier":
				k.tube(p + Vector3(0, 0.5, 0), p + Vector3(0, 0.62, 0), 0.06, 0.04, 6, col)
				k.lathe(p + Vector3(0, 0.62, 0), [Vector2(0.04, 0.0), Vector2(0.16, 0.08), Vector2(0.18, 0.28), Vector2(0.14, 0.3)], 8, col)
			"recherches":
				k.box(p + Vector3(0, 0.78, 0), Vector3(0.22, 0.56, 0.22), col)
				k.box(p + Vector3(0, 1.12, 0), Vector3(0.16, 0.16, 0.16), col)
			_:
				k.box(p + Vector3(0, 0.72, 0), Vector3(0.42, 0.44, 0.06), col)
		x += 0.9
		n += 1
	var mi := MeshInstance3D.new()
	mi.name = "Trophees"
	mi.mesh = k.commit(dio._materiaux)
	dio._statique.add_child(mi)
