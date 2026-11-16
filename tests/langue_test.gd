extends SceneTree
## Test des traductions (anglais, allemand, italien, espagnol) : fichiers
## assets/langues/*.json bien formés
## (mêmes champs %d, %s… qu'en français, ou numérotés %1$s), textes exacts,
## modèles (« Population : 1 234 » → « Population: 1,234 »), découpage par
## lignes et séparateurs, nombres à l'anglaise, traduction automatique d'un
## Label et d'un Button par TranslationServer, retour au français.
## Usage : godot --headless --path . --script res://tests/langue_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		quit(1))


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _egal(obtenu: String, attendu: String, what: String) -> void:
	_check(obtenu == attendu, "%s : « %s »%s" % [what, obtenu, "" if obtenu == attendu else " (attendu « %s »)" % attendu])


## Types des champs (%d, %s, %.1f…) d'un texte, dans l'ordre ; %% ignoré.
func _champs(s: String, re: RegEx) -> Array:
	var out := []
	for m in re.search_all(s):
		if m.get_string() == "%%":
			continue
		out.append([m.get_string(1), m.get_string(2)])
	return out


## Vérifie un fichier de langue : JSON {textes}, assez de textes, et mêmes
## champs %d / %s qu'en français (ou numérotés %2$d vers un champ du même type).
## Une traduction peut laisser tomber des %s de pluriel en fin.
func _verifier_fichier(code: String, minimum: int) -> Dictionary:
	var f := FileAccess.open("res://assets/langues/%s.json" % code, FileAccess.READ)
	_check(f != null, "assets/langues/%s.json existe" % code)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	_check(data is Dictionary and data.get("textes") is Dictionary, "%s.json est un JSON {textes: {…}}" % code)
	if not (data is Dictionary and data.get("textes") is Dictionary):
		return {}
	var textes: Dictionary = data.get("textes", {})
	_check(textes.size() > minimum, "%s : plus de %d textes traduits (%d)" % [code, minimum, textes.size()])
	var re := RegEx.create_from_string("%(?:(\\d+)\\$)?[-+0#]*\\d*(?:\\.\\d+)?([sdifxXc])|%%")
	var mauvais := []
	for fr in textes:
		var en := String(textes[fr])
		if en.strip_edges() == "":
			mauvais.append(fr)
			continue
		var cf := _champs(String(fr), re)
		var ce := _champs(en, re)
		var bon := true
		var numerote := false
		for c in ce:
			if c[0] != "":
				numerote = true
		if numerote:
			for c in ce:
				var n := int(c[0]) - 1
				if c[0] == "" or n < 0 or n >= cf.size() or cf[n][1] != c[1]:
					bon = false
		else:
			if ce.size() > cf.size():
				bon = false
			else:
				for i in cf.size():
					if i < ce.size():
						if ce[i][1] != cf[i][1]:
							bon = false
					elif cf[i][1] != "s":
						bon = false
		if not bon:
			mauvais.append(fr)
	_check(mauvais.is_empty(), "%s : champs %%d / %%s cohérents dans toutes les traductions%s" % [code, "" if mauvais.is_empty() else " (%d à revoir, ex. « %s »)" % [mauvais.size(), mauvais[0]]])
	return textes


func _run() -> void:
	# 1. Les fichiers.
	var textes := _verifier_fichier("en", 8000)
	if textes.is_empty():
		_fin()
		return
	for code in ["de", "it", "es"]:
		_verifier_fichier(code, 10000)

	# 2. La traduction elle-même.
	_check(Langue.existe("en") and Langue.existe("fr"), "langues fr et en connues")
	Langue.activer("en")
	var tr_en := Langue.traduction("en") as TraductionAuto
	_check(tr_en != null and tr_en.nb_modeles > 1000, "modèles construits (%d)" % (tr_en.nb_modeles if tr_en else 0))
	_egal(Langue.t("Habitants"), "Residents", "texte exact")
	_egal(Langue.t("HABITANTS"), "RESIDENTS", "texte en capitales")
	_egal(Langue.t("Statistiques"), "Statistics", "titre de panneau")
	_egal(Langue.t("Caisse : 1250 €"), "Funds: 1250 €", "modèle « %s : %s »")
	_egal(Langue.t("%d habitants" % 3), "3 residents", "modèle %d")
	_egal(Langue.t("Trafic\nStatistiques"), "Traffic\nStatistics", "texte sur deux lignes")
	_egal(Langue.t("Courbes · Statistiques"), "Curves · Statistics", "séparateur « · »")
	_egal(Langue.t("Mort à 82 ans"), "Mort à 82 ans", "texte inconnu laissé tel quel")
	_egal(Langue.t("Caisse : 1 234 567 €"), "Funds: 1,234,567 €", "nombres à l'anglaise")
	_egal(Langue.t("ZQSD ou flèches : se déplacer · molette : zoomer · A / E : tourner"),
		"WASD or arrows: move · wheel: zoom · Q / E: rotate", "touches QWERTY")
	_egal(Langue.t("%s · %d content%s, %d mécontent%s" % ["Annecy", 5, "s", 1, ""]),
		"Annecy · 5 happy, 1 unhappy", "champs numérotés (%2$d, %4$d)")
	_egal(tr("Ouvrir le budget"), "Open the budget", "tr() du moteur")
	_egal(Langue.t("10 juin 2026 · 21 °C"), "10 Jun 2026 · 21 °C", "date")
	_egal(Langue.t("Ville ▴"), "Town ▴", "menu avec flèche")
	_egal(Langue.t("-1 330 €"), "-1,330 €", "montant seul")
	_egal(Langue.t("Habitants : 177 · Production : 1 site, 1 en activité · 0 camion en livraison"),
		"Residents: 177 · Production: 1 site, 1 operating · 0 truck delivering", "modèle qui contient lui-même « · »")

	# 3. Les nœuds se traduisent tout seuls.
	var l := Label.new()
	l.text = "Statistiques"
	var b := Button.new()
	b.text = "Sauvegarder la partie"
	b.tooltip_text = "Retour au menu principal"
	root.add_child(l)
	root.add_child(b)
	await process_frame
	_egal(l.atr(l.text), "Statistics", "Label traduit")
	_egal(b.atr(b.text), "Save the game", "Button traduit")
	_egal(b.atr(b.tooltip_text), "Back to the main menu", "info-bulle traduite")

	# 4. Allemand, italien, espagnol : textes, modèles, nombres « 1.234,5 », dates.
	var attendus := {
		"de": ["Einwohner", "Kasse: 1250 €", "3 Einwohner", "Kasse: 1.234.567 €", "Haushalt öffnen", "Statistiken"],
		"it": ["Abitanti", "Cassa: 1250 €", "3 abitanti", "Cassa: 1.234.567 €", "Apri il bilancio", "Statistiche"],
		"es": ["Habitantes", "Caja: 1250 €", "3 habitantes", "Caja: 1.234.567 €", "Abrir el presupuesto", "Estadísticas"],
	}
	for code in attendus:
		var a: Array = attendus[code]
		_check(Langue.existe(code), "langue %s connue" % code)
		Langue.activer(code)
		var trad := Langue.traduction(code) as TraductionAuto
		_check(trad != null and trad.nb_modeles > 1000, "%s : modèles construits (%d)" % [code, trad.nb_modeles if trad else 0])
		_egal(Langue.t("Habitants"), a[0], "%s : texte exact" % code)
		_egal(Langue.t("Caisse : 1250 €"), a[1], "%s : modèle « %%s : %%s »" % code)
		_egal(Langue.t("%d habitants" % 3), a[2], "%s : modèle %%d" % code)
		_egal(Langue.t("Caisse : 1 234 567 €"), a[3], "%s : milliers avec un point" % code)
		_egal(tr("Ouvrir le budget"), a[4], "%s : tr() du moteur" % code)
		_egal(l.atr(l.text), a[5], "%s : Label traduit" % code)
		_egal(Langue.t("Mort à 82 ans"), "Mort à 82 ans", "%s : texte inconnu laissé tel quel" % code)
		print("  ", code, " : ", Langue.t("10 juin 2026 · 21 °C"), " | ", Langue.t("Caisse : 1 234,5 €"), " | ",
			Langue.t("%s · %d content%s, %d mécontent%s" % ["Annecy", 5, "s", 1, ""]))
	Langue.activer("de")
	_egal(Langue.t("10 juin 2026 · 21 °C"), "10. Juni 2026 · 21 °C", "de : date avec point")
	_egal(Langue.t("Caisse : 1 234,5 €"), "Kasse: 1.234,5 €", "de : virgule décimale gardée")
	_egal(Langue.t("%s · %d content%s, %d mécontent%s" % ["Annecy", 5, "s", 1, ""]),
		"Annecy · 5 zufrieden, 1 unzufrieden", "de : champs numérotés")
	Langue.activer("es")
	_egal(Langue.t("ZQSD ou flèches : se déplacer · molette : zoomer · A / E : tourner"),
		"WASD o flechas: moverse · rueda: zoom · Q / E: girar", "es : touches QWERTY")

	# 5. Retour au français : rien n'est traduit.
	Langue.activer("fr")
	_egal(tr("Statistiques"), "Statistiques", "français : texte d'origine")
	_egal(l.atr(l.text), "Statistiques", "français : Label d'origine")
	_check(OptionsJeu.LANGUES.size() >= 5, "choix de la langue dans Options (%d langues)" % OptionsJeu.LANGUES.size())
	_fin()


func _fin() -> void:
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
