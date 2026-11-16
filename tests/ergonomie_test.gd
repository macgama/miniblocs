extends SceneTree
## Test de la refonte de l'ergonomie (2026-11-16) : Atelier vide, parcours
## « Enregistrer mon bâtiment », catalogue en thèmes nommés avec favoris,
## récents et recherche globale, recherche dans tout le jeu (Espace), tableau
## de bord de la Mairie (M) et fil d'alertes.
## Usage : godot --headless --path . --script res://tests/ergonomie_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	root.push_input(e)
	await process_frame
	var u := e.duplicate() as InputEventKey
	u.pressed = false
	root.push_input(u)
	await process_frame


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	Creations.persist = false
	BanqueModeles.persist = false
	FavorisConstruire.persist = false
	FavorisConstruire.vider_pour_tests()
	BatimentsVie.chantiers = false

	print("Recherche sans accents :")
	_check(FavorisConstruire.plier("École Été") == "ecole ete", "« École Été » → « ecole ete »")
	var g := ParcoursAtelier.groupe_blocs({Vector3i(0, 0, 0): 1, Vector3i(1, 0, 0): 1, Vector3i(1, 2, 1): 1, Vector3i(40, 0, 40): 1}, Vector3(0, 0, 0))
	_check(g.n == 3 and g.rect == Rect2i(0, 0, 2, 2), "groupe de blocs voisins : 3 blocs, 2 × 2 m (le bloc isolé est laissé)")

	# --- Atelier ----------------------------------------------------------------------
	print("Atelier :")
	GameStart.atelier = true
	var at: Node = load("res://scenes/terre.tscn").instantiate()
	root.add_child(at)
	await _frames(40)
	var aw: TerrainWorld = at.get_node("Terrain")
	_check(aw.sans_vegetation, "terrain sans végétation")
	_check(not at.decors._auto_on(), "pas de décors automatiques")
	var veg := 0
	for mi in aw.get_children():
		for ch in mi.get_children():
			if ch is MultiMeshInstance3D:
				veg += 1
	_check(veg == 0, "aucun arbre, herbe ni fleur posé (%d)" % veg)
	var par: ParcoursAtelier = at.parcours
	_check(par.is_shown(), "les 3 étapes sont affichées")
	_check(par.etape() == 0 and par._save_btn.disabled, "étape 1 : rien à enregistrer, bouton grisé")
	var plans: PlanEditor = at.plans
	var y := aw.cell_height(Vector2i(0, 0))
	var pid := plans.new_plan(y)
	plans.add_room(pid, Rect2i(-5, -4, 10, 8), 0, 2)
	plans.add_roof(pid, "gable")
	par._refresh()
	_check(not par._save_btn.disabled and par.etape() == 1, "construction faite : étape 2, bouton actif")
	par.ouvrir()
	_check(par.dialog_open(), "« Enregistrer mon bâtiment » ouvre la fiche")
	_check(par.cible().genre == "plan", "la fiche vise le bâtiment en murs")
	var res := par.enregistrer("Chalet test", "maison")
	_check(res.ok and not BuildingCatalog.get_type(String(res.catalog_id)).is_empty(), "enregistré : %s dans le catalogue" % res.get("catalog_id", "?"))
	_check(ModelesJeu.ids().has(res.catalog_id), "il est dans Mes modèles")
	_check(par.etape() == 3, "étape 3 faite")
	var poser := par._dialog.find_child("Poser", true, false)
	_check(poser == null or poser is Button, "bouton « Le poser dans ma partie » (si une partie attend)")
	par.fermer()
	# Blocs seuls, loin des murs.
	var blocks: BlockEditor = at.blocks
	var bkeys := []
	for x in 3:
		for z in 2:
			bkeys.append(Vector3i(30 + x, floori(y / BlockEditor.UNIT_Y), 30 + z))
	blocks.place_blocks(bkeys, 1)
	at.rig.global_position = Vector3(31, y, 31)
	plans._active = ""
	plans.plans.erase(pid)
	var c2 := par.cible()
	_check(c2.get("genre", "") == "blocs" and int(c2.n) == 6, "sans murs : le groupe de blocs visé (%s)" % str(c2))
	par.ouvrir()
	var r2 := par.enregistrer("Kiosque test", "")
	_check(r2.ok and Creations.items.has(r2.catalog_id), "blocs enregistrés comme création, sans rectangle à tracer")
	par.fermer()
	var bp: BuildingPanel = at.build_panel
	at._on_create_requested("banque")
	await _frames(2)
	_check(bp._list.find_child("*Kiosque test*", true, false) != null or _has_text(bp._list, "Kiosque test"), "Mes modèles (5) montre aussi les créations en blocs")
	_check(at.hud._cat_buttons.banque.text == "Mes modèles" or at.hud._cat_buttons.banque.tooltip_text.begins_with("Mes modèles"), "tuile « Mes modèles » dans la barre du mode Créer")
	_check(not at.hud._cat_buttons.creations.visible, "plus de tuile « Mes créations » séparée")
	at.queue_free()
	await _frames(5)
	GameStart.atelier = false

	# --- Partie --------------------------------------------------------------------------
	var game: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = game.get_node("Terrain")
	root.add_child(game)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(45.8992, 6.1294)
	await _frames(30)
	_check(not world.sans_vegetation and game.decors._auto_on(), "dans une partie, la végétation et les décors reviennent")
	var hud: TerreHud = game.hud

	print("Construire en thèmes :")
	var panel: BuildingPanel = game.build_panel
	panel.set_open(true)
	panel.show_category("logement")
	await _frames(2)
	var themes := []
	for ch in panel._themes_box.get_children():
		if ch is Button and String(ch.name).begins_with("Theme_"):
			themes.append(String(ch.text))
	_check(themes.has("Logement") and themes.has("Services publics") and themes.has("Loisirs et culture") and themes.has("Sport") and themes.has("Mes modèles"), "thèmes avec leur nom : %s" % ", ".join(themes))
	_check(themes.has("Favoris") and themes.has("Récents"), "Favoris et Récents en tête")
	_check(not panel._cats_grid.visible, "plus de grille de 21 icônes sans nom")
	panel.show_category("zoo")
	await _frames(1)
	var subs := 0
	for ch in panel._themes_box.get_children():
		if ch is Button and String(ch.text) in ["Parc d'attractions", "Zoo", "Spectacles et musées"]:
			subs += 1
	_check(subs == 3, "le thème Loisirs ouvert montre ses sous-thèmes (parc, zoo, spectacles)")
	panel.show_category("logement")
	panel._global_search.text = "piscine"
	panel._global_search.text_changed.emit("piscine")
	await _frames(2)
	var found := _cards(panel)
	var cats := {}
	for id in found:
		cats[String(BuildingCatalog.get_type(id).cat)] = true
	_check(found.size() > 0 and not cats.has("logement") or cats.size() > 1, "« piscine » depuis Logement : trouvé dans tout le catalogue (%d, catégories %s)" % [found.size(), ", ".join(cats.keys())])
	panel._global_search.text = "ecole"
	panel._global_search.text_changed.emit("ecole")
	await _frames(2)
	var ecoles := _cards(panel)
	var has_ecole := false
	for id in ecoles:
		if FavorisConstruire.plier(String(BuildingCatalog.get_type(id).name)).contains("ecole"):
			has_ecole = true
	_check(has_ecole, "« ecole » trouve « École » (sans accent)")
	panel._global_search.text = ""
	panel._global_search.text_changed.emit("")
	panel.show_category("logement")
	await _frames(1)
	var first: String = _cards(panel)[0]
	var card := _card_of(panel, first)
	var star := card.find_child("Etoile", true, false) as Button
	_check(star != null, "étoile sur chaque vignette")
	star.button_pressed = true
	_check(FavorisConstruire.est_favori(first), "étoile : ajouté aux favoris")
	card.pressed.emit()
	_check(FavorisConstruire.liste("recents").has(first), "choisi : ajouté aux récents")
	panel.show_category("favoris")
	await _frames(1)
	_check(_cards(panel).has(first), "Favoris : le bâtiment y est")
	panel.show_category(ModelesJeu.CATEGORY)
	await _frames(1)
	_check(panel._list.find_child("CreerBatiment", true, false) != null, "Mes modèles : « Créer un nouveau bâtiment dans l'Atelier »")
	panel.set_open(false)

	print("Recherche dans tout le jeu :")
	var rech: RechercheUniverselle = game.recherche
	var genres := {}
	for e in rech.chercher("zoo"):
		genres[String(e.genre)] = true
	_check(genres.has("panneau") and genres.has("batiment"), "« zoo » : le panneau du zoo et des bâtiments")
	var budget := rech.chercher("budget")
	_check(not budget.is_empty() and budget[0].genre == "panneau" and budget[0].id == "budget", "« budget » : le panneau Budget en premier")
	var route := rech.chercher("route")
	_check(not route.is_empty() and route[0].genre == "outil", "« route » : l'outil Route en premier")
	await _key(KEY_SPACE)
	_check(rech.est_ouverte(), "Espace ouvre la recherche")
	rech._edit.text = "hopital"
	rech._edit.text_changed.emit("hopital")
	await _frames(1)
	_check(not rech._resultats.is_empty(), "« hopital » trouve quelque chose (%d)" % rech._resultats.size())
	await _key(KEY_ESCAPE)
	_check(not rech.est_ouverte(), "Échap la ferme")
	rech.ouvrir("budget")
	rech.valider()
	await _frames(2)
	_check(game.budget_panel.is_open(), "Entrée sur « Budget » : le panneau s'ouvre")
	game.budget_panel.set_open(false)

	print("Mairie et alertes :")
	await _key(KEY_M)
	var mp: MairiePanel = game.mairie_panel
	_check(mp.is_open(), "M ouvre le tableau de bord")
	_check(hud._cat_buttons.mairie.button_pressed, "la tuile Mairie s'allume")
	var tuiles := 0
	for t in MairiePanel.TUILES:
		if mp._panel.find_child("Tuile_" + String(t.titre), true, false) != null:
			tuiles += 1
	_check(tuiles == 8, "8 tuiles d'état")
	_check(mp._panel.find_child("Menu_habitants", true, false) != null and mp._panel.find_child("Menu_budget", true, false) != null, "tous les menus de la ville sont dans la Mairie")
	(mp._panel.find_child("Menu_habitants", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not mp.is_open() and game.habitants_panel.is_open(), "Mairie › Habitants ouvre le bon panneau")
	game.habitants_panel.set_open(false)
	_check(not hud._group_buttons.ville.is_inside_tree(), "le menu Ville de la barre est remplacé par la Mairie")
	var oublis := []
	for c in TerreHud.CATEGORIES:
		if String(c.get("group", "")) == "ville" and mp._panel.find_child("Menu_" + String(c.id), true, false) == null \
				and not EditionDemo.panneau_verrouille(String(c.id)):
			oublis.append(String(c.id))
	_check(oublis.is_empty(), "chaque menu du groupe Ville a son bouton dans la Mairie (oublis : %s)" % str(oublis))
	# Alertes : un relevé avec du chômage.
	var st: Statistiques = game.statistiques
	st.historique.append({"j": 100, "n": 1, "d": {Statistiques.PAYS: {"habitants": 500.0, "chomage": 25.0, "caisse": 1000000.0, "solde": -5000.0, "satisfaction": 60.0}}})
	st.releve_fait.emit()
	await _frames(1)
	var al := mp.alertes()
	_check(not al.is_empty() and int(al[0].gravite) == 2, "le Conseiller remonte un problème urgent : %s" % (al[0].titre if not al.is_empty() else "?"))
	var fil: FilAlertes = game.fil_alertes
	_check(fil.nombre() > 0 and fil._panel.visible, "fil « À faire » visible (%d)" % fil.nombre())
	hud._request_mode(true)
	await _frames(1)
	_check(not fil._panel.visible, "fil caché en mode Créer")
	_check(game.parcours.is_shown(), "les 3 étapes en mode Créer dans la partie aussi")
	hud._request_mode(false)
	await _frames(1)

	print("Retour de l'Atelier avec le bâtiment en main :")
	game.poser_modele(String(res.catalog_id))
	await _frames(2)
	_check(game.build_panel.is_open() and game.build_panel.category() == ModelesJeu.CATEGORY, "Construire › Mes modèles ouvert")
	_check(game.buildings.mode == BuildingSystem.Mode.PLACE and game.buildings.type_id == String(res.catalog_id), "le bâtiment est en main")

	print("ERGONOMIE TEST " + ("OK" if ok else "ÉCHEC"))
	quit(0 if ok else 1)


func _has_text(n: Node, t: String) -> bool:
	if (n is Button or n is Label) and String(n.text).contains(t):
		return true
	for ch in n.get_children():
		if _has_text(ch, t):
			return true
	return false


## Ids des vignettes affichées dans la liste du panneau.
func _cards(panel: BuildingPanel) -> Array:
	var out := []
	for g in panel._list.get_children():
		if g is GridContainer:
			for b in g.get_children():
				if b is Button and b.has_meta("type_id"):
					out.append(String(b.get_meta("type_id")))
	return out


func _card_of(panel: BuildingPanel, id: String) -> Button:
	for g in panel._list.get_children():
		if g is GridContainer:
			for b in g.get_children():
				if b is Button and String(b.get_meta("type_id", "")) == id:
					return b
	return null
