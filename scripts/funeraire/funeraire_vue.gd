class_name FuneraireVue
extends RefCounted
## Onglet « Funéraire » du panneau Habitants (touche H) : décès, obsèques en
## cours et à venir, défunts qui attendent une place, places libres de chaque
## cimetière et columbarium, pompes funèbres et inhumations récentes.


static func remplir(panel: HabitantsPanel) -> void:
	var f := Funeraire.instance
	panel._title.text = "Habitants · funéraire"
	if f == null:
		panel._text("Pas de services funéraires dans cette partie.", true)
		return
	if not Funeraire.actif():
		panel._text("Les obsèques sont désactivées dans les réglages de la partie (Admin, F10).", true)
		return
	var b := f.bilan()
	var vie := panel.pop.vie
	panel._text("Hier : %d décès · %d inhumations · %d crémations" % [int(b.deces), int(b.inhumations), int(b.cremations)], false, 14)
	panel._text("Depuis le début : %d décès, %d enterrés dans une commune voisine faute de place." % [
		int(f.totaux.deces) + int(f.today.deces), int(b.exportes)], true, 12)
	if int(b.attente) > 0:
		var l := panel._text("⚠ %d défunt%s attend%s une place au cimetière." % [int(b.attente), "s" if int(b.attente) > 1 else "",
			"ent" if int(b.attente) > 1 else ""], false, 13)
		l.add_theme_color_override("font_color", Color("ff8f6b"))

	panel._section("Cimetières et columbariums")
	var any := false
	for role in ["cimetiere", "columbarium"]:
		for bid in f.sites_of(role):
			any = true
			var pos := f._pos_of(bid)
			panel._link("%s  ↗" % f.building_name(bid), func() -> void: panel.focus_requested.emit(pos), "Centrer la caméra")
			panel._gauge(panel._body, "Occupées", f.used(bid), f.capacity(bid))
	if not any:
		panel._text("Aucun cimetière : construis-en un (Construire → Funéraire). Sans place, les défunts sont enterrés dans une commune voisine.", true, 12)
	var cr := f.sites_of("crematorium")
	var pf := f.sites_of("pompes_funebres")
	panel._text("Crématorium : %s · Pompes funèbres : %s" % [
		"%d" % cr.size() if not cr.is_empty() else "aucun (crémations dans une commune voisine)",
		"%d" % pf.size() if not pf.is_empty() else "aucune (convois venus d'ailleurs, plus chers)"], true, 12)
	for bid in pf:
		var busy := 0
		for u in f.sites[bid].units:
			if int(u.pid) >= 0:
				busy += 1
		var pos := f._pos_of(bid)
		panel._link("%s : %d corbillard%s en convoi sur %d  ↗" % [f.building_name(bid), busy, "s" if busy > 1 else "", (f.sites[bid].units as Array).size()],
			func() -> void: panel.focus_requested.emit(pos))

	panel._section("Obsèques")
	var list: Array = f.obseques.values()
	list.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a.t_mort) < float(c.t_mort))
	if list.is_empty():
		panel._text("Aucunes obsèques en préparation.", true)
	for o in list.slice(0, 15):
		var pid := int(o.pid)
		if vie.archive.has(pid):
			panel._person_link(pid, f.etat_text(o))
		else:
			panel._text("† %s · %s" % [o.nom, f.etat_text(o)], true)
	if list.size() > 15:
		panel._text("… et %d autres." % (list.size() - 15), true, 12)

	panel._section("Inhumations et crémations récentes")
	if f.recents.is_empty():
		panel._text("Personne pour l'instant.", true)
	for pid in f.recents.slice(0, 12):
		if vie.archive.has(int(pid)):
			panel._person_link(int(pid), f.sepulture_text(int(pid)))
	panel._text("Clic sur une tombe : la fiche du défunt. Concessions de 30 ans, renouvelées par la famille si elle vit encore en ville.", true, 12)
