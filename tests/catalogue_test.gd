extends SceneTree
## Test du catalogue daté (CatalogueJeu, EpoquesObjets, panneau F7) : chaque
## objet qui se construit a une année et aucune n'est plus devinée ; décors,
## meubles, ouvertures, toits, aménagements et grands-huit suivent l'époque ;
## l'export docs/catalogue s'écrit ; le panneau s'ouvre et filtre.
## Usage : godot --headless --path . --script res://tests/catalogue_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _run() -> void:
	print("Catalogue :")
	var tout := CatalogueJeu.entrees(true)
	_check(tout.size() > 1500, "plus de 1 500 objets au catalogue (%d)" % tout.size())
	for f in CatalogueJeu.FAMILLES:
		_check(not CatalogueJeu.de_famille(String(f[0])).is_empty(), "famille « %s » remplie" % f[1])
	var devinees := []
	var sans := []
	for e: Dictionary in tout:
		if String(e.source) == "devinee":
			devinees.append(String(e.id))
		if not e.has("annee") or int(e.annee) < 0:
			sans.append(String(e.id))
	_check(devinees.is_empty(), "aucune année devinée (%s)" % ", ".join(devinees.slice(0, 8)))
	_check(sans.is_empty(), "tous les objets ont une année")
	var types := BuildingCatalog.all_types()
	var vus := {}
	for e: Dictionary in CatalogueJeu.de_famille("batiments"):
		vus[String(e.id)] = true
	var manquants := []
	for id in types:
		var t: Dictionary = types[id]
		if not (t.has("blocks") or t.has("modele") or bool(t.get("cache", false))) and not vus.has(id):
			manquants.append(String(id))
	_check(manquants.is_empty(), "tous les bâtiments du catalogue B y sont (%s)" % ", ".join(manquants.slice(0, 8)))
	_check(Epoques.annee_batiment("grande_roue") == 1893, "la grande roue arrive en 1893 (et plus en 1830)")
	_check(Epoques.annee_batiment("immeuble_annees30") == 1925, "l'immeuble Art déco arrive en 1925")
	_check(Epoques.annee_batiment("stade_bale") == 2001, "le stade de Bâle ouvre en 2001")
	var pompiers := {}
	for e: Dictionary in CatalogueJeu.de_famille("batiments"):
		if String(e.id) == "remise_pompes":
			pompiers = e
	_check(String(pompiers.get("evol", "")).contains("Même rôle selon l'époque"), "la remise des pompes montre sa lignée")
	var maison := {}
	for e: Dictionary in CatalogueJeu.de_famille("batiments"):
		if String(e.id) == "maison":
			maison = e
	_check(String(maison.get("evol", "")).contains("niveau 3"), "la maison montre ses agrandissements")
	_check(Epoques.vehicule_pour_annee("tacot", 1850) != "tacot", "avant 1900, une voiture sans chevaux est remplacée par un attelage")

	print("Objets datés selon l'année de la partie :")
	var r := ReglagesPartie.new()
	r.annee_depart = 1850
	var avant := ReglagesPartie.actuel
	ReglagesPartie.actuel = r
	_check(Epoques.actif() and Epoques.annee() == 1850, "partie en 1850")
	_check(EpoquesObjets.decor_epoque("lampadaire") == "reverbere", "lampadaire posé tout seul → réverbère en 1850")
	_check(EpoquesObjets.decor_epoque("bateau_moteur") == "barque", "hors-bord → barque en 1850")
	_check(EpoquesObjets.decor_epoque("botte_ronde") == "meule", "botte ronde → meule en 1850")
	_check(EpoquesObjets.decor_epoque("panneau_stop") == "", "pas de stop en 1850")
	_check(EpoquesObjets.decor_epoque("tracteur") == "cheval", "tracteur → cheval en 1850")
	_check(not EpoquesObjets.decor_disponible("abribus"), "abribus verrouillé en 1850")
	_check(EpoquesObjets.decor_disponible("banc_bois"), "banc en bois libre en 1850")
	_check(Meubles.pick("refrigerateur", "contemporain") == "", "pas de réfrigérateur en 1850")
	var froid := Meubles.pick_any(["refrigerateur", "garde_manger"], "contemporain")
	_check(froid != "" and String(Meubles.get_entry(froid).type) == "garde_manger", "garde-manger à la place du frigo (%s)" % froid)
	_check(not EpoquesObjets.meuble_disponible("spectacle/projecteur_numerique"), "pas de projecteur numérique en 1850")
	_check(EpoquesObjets.annee_ouverture("mur_rideau") > Epoques.annee(), "mur-rideau verrouillé en 1850")
	_check(EpoquesObjets.annee_toit("terrasse") > Epoques.annee(), "toit-terrasse verrouillé en 1850")
	_check(EpoquesObjets.annee_amenagement("voie_lgv") > Epoques.annee(), "voie LGV verrouillée dans l'Atelier en 1850")
	_check(VoiePieces.refus("acier", 0, "looping") != "", "pas de looping en 1850")
	_check(VoiePieces.refus("bois", 0, "droit") == "", "un droit se pose en 1850")
	var mat_plastique := -1
	for i in BlocMateriaux.LIST.size():
		if String(BlocMateriaux.LIST[i].name).to_lower().contains("bâche"):
			mat_plastique = i
			break
	_check(mat_plastique < 0 or not Epoques.materiau_disponible(mat_plastique), "bâche plastique verrouillée en 1850")
	r.annee_depart = 2026
	EpoquesObjets._remplace_annee = -1
	_check(EpoquesObjets.decor_epoque("lampadaire") == "lampadaire", "lampadaire en 2026")
	_check(Meubles.pick("refrigerateur", "contemporain") != "", "réfrigérateur en 2026")
	ReglagesPartie.actuel = avant

	print("Export :")
	var dir := "user://test_catalogue"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var Export: GDScript = load("res://tools/catalogue/export_catalogue.gd")
	var md: String = Export.markdown(tout)
	var page: String = Export.html(tout)
	_check(md.contains("## Bâtiments") and md.contains("Grande roue"), "le Markdown liste les bâtiments")
	_check(page.contains("<title>Catalogue MiniBlocs</title>") and page.contains("\"objets\""), "la page HTML embarque les données")
	_check(String(Export.dates_ajoutees(tout)).contains("Grande roue (1893)"), "les années ajoutées sont listées")

	print("Panneau F7 :")
	var p := CataloguePanel.new()
	root.add_child(p)
	await process_frame
	_check(p._titre.text.begins_with("Catalogue"), "le panneau s'ouvre")
	p.texte = "looping"
	p.famille = "attractions"
	p.annee = 1900
	p.refresh()
	await process_frame
	_check(p._resume.text.begins_with("2 affichés, dont 0"), "recherche « looping » en 1900 : 2 objets, aucun inventé (%s)" % p._resume.text)
	p.close_panel()
	await process_frame

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
