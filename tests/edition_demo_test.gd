extends SceneTree
## Test de l'édition démo (Steam Next Fest, EditionDemo) : menu principal
## réduit et bouton Liste de souhaits, panneaux et catalogue verrouillés,
## raccourcis bloqués, pas d'époques ni de succès, limite de la partie et écran
## de fin (FinDemo), sauvegarde de la limite, preset d'export « Windows Demo ».
## Usage : godot --headless --path . --script res://tests/edition_demo_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		quit(1))


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _touche(code: Key, maj := true) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.shift_pressed = maj
	k.pressed = true
	return k


func _run() -> void:
	EditionDemo.ouvrir_vraiment = false
	print("Détection :")
	EditionDemo.forcee = -1
	_check(not EditionDemo.active(), "jeu normal sans la fonctionnalité « demo »")
	EditionDemo.forcee = 1
	_check(EditionDemo.active(), "édition démo forcée")

	print("Preset d'export :")
	var cfg := ConfigFile.new()
	_check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg lisible")
	var trouve := ""
	for s in cfg.get_sections():
		if String(cfg.get_value(s, "name", "")) == "Windows Demo":
			trouve = s
	_check(trouve != "", "preset « Windows Demo »")
	if trouve != "":
		_check(String(cfg.get_value(trouve, "custom_features", "")).split(",").has("demo"), "fonctionnalité « demo »")
		_check(String(cfg.get_value(trouve, "export_path", "")).ends_with("MiniBlocsDemo.exe"), "exécutable à part")
		_check(String(cfg.get_value(trouve, "exclude_filter", "")).contains("tests/*"), "tests exclus")
	var pg := ConfigFile.new()
	pg.load("res://project.godot")
	_check(String(pg.get_value("application", "config/name.demo", "")) == "MiniBlocs Demo", "sauvegardes à part (config/name.demo)")

	print("Menu principal (démo) :")
	var menu: Node = load(MenuPrincipal.SCENE).instantiate()
	root.add_child(menu)
	await _frames(2)
	for id in EditionDemo.MENU_ABSENTS:
		_check(not menu._boutons.has(id), "pas de bouton « %s »" % id)
	for id in ["demo", "nouvelle", "charger", "options", "credits", "souhaits", "quitter"]:
		_check(menu._boutons.has(id), "bouton « %s »" % id)
	var noms: Array = menu._menu.get_children().map(func(b) -> String: return String(b.name))
	_check(noms.back() == "souhaits" and (menu._boutons.quitter as Node).get_parent() == menu._rangee, "Liste de souhaits en bas du menu, juste au-dessus de Quitter (%s)" % ", ".join(noms))
	_check(menu.find_child("BadgeDemo", true, false) != null, "badge « DÉMO »")
	_check(String((menu.find_child("VersionBuild", true, false) as Label).text).begins_with("Démo · "), "version marquée Démo")
	(menu._boutons.souhaits as Button).pressed.emit()
	_check(EditionDemo.derniere_ouverture == EditionDemo.SITE, "sans App ID : le site ManiGames (%s)" % EditionDemo.derniere_ouverture)
	menu.quitter()
	await _frames(2)
	var fq := menu.get_node_or_null("FinDemo") as FinDemo
	_check(fq != null and fq.motif == FinDemo.Motif.QUITTER, "Quitter : écran de remerciement")
	if fq != null:
		_check(fq.find_child("Souhaits", true, false) != null and fq.find_child("Quitter", true, false) != null, "boutons Liste de souhaits et Quitter")
		(fq.find_child("Retour", true, false) as Button).pressed.emit()
		await _frames(2)
		_check(menu.get_node_or_null("FinDemo") == null, "Retour au menu")
	menu.queue_free()
	await _frames(2)
	EditionDemo.forcee = 0
	menu = load(MenuPrincipal.SCENE).instantiate()
	root.add_child(menu)
	await _frames(2)
	_check(menu._boutons.has("scenarios") and menu._boutons.has("atelier") and not menu._boutons.has("souhaits"), "jeu complet : menu entier, pas de bouton souhaits")
	menu.queue_free()
	await _frames(2)
	EditionDemo.forcee = 1

	print("Époques et succès :")
	var r := ReglagesPartie.preset("normal")
	r.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	r.annee_depart = 1850
	_check(not Epoques.actif(r), "démo : pas de partie historique")
	EditionDemo.forcee = 0
	_check(Epoques.actif(r), "jeu complet : partie historique possible")
	EditionDemo.forcee = 1
	Succes.persist = false
	Succes.debloques.erase("premier_coup_de_pelle")
	_check(Succes.existe("premier_coup_de_pelle") and not Succes.debloquer("premier_coup_de_pelle"), "démo : aucun succès débloqué")
	SteamPont.reinitialiser()
	SteamPont.debloquer("MB_TEST")
	_check(SteamPont.journal.size() == 1, "SteamPont n'envoie rien hors Steam")

	print("Partie (démo) :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	Demo.preparer()
	ReglagesPartie.prochaine.fondateurs = 0
	Demo.demandee = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 600.0
	world.set_origin(45.5, 6.4)
	for i in 1500:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var hud: TerreHud = scene.hud
	for id in ["zoo", "parc", "musee", "club", "tourisme", "parc_editeur", "spectacles"]:
		hud._on_category(id)
	await _frames(2)
	_check(not scene.zoo_panel.is_open(), "bouton Zoo : verrouillé")
	_check((hud._cat_buttons.zoo as Button).modulate.a < 0.9 and String((hud._cat_buttons.zoo as Button).tooltip_text).contains("jeu complet"), "bouton Zoo grisé, infobulle « jeu complet »")
	_check((hud._cat_buttons.budget as Button).modulate.a > 0.9, "bouton Budget normal")
	scene._input(_touche(KEY_Z))
	await _frames(2)
	_check(not scene.zoo_panel.is_open(), "Maj+Z : verrouillé")
	_check(EditionDemo.touche_verrouillee(_touche(KEY_M, false)) == "", "M (budget) reste libre")
	_check(EditionDemo.touche_verrouillee(_touche(KEY_F3, false)) != "", "F3 (carte entre amis) verrouillé")
	var bp = scene.build_panel
	for c in EditionDemo.CATALOGUE_VERROUILLE:
		_check(not bp._cat_buttons.has(c), "catalogue : pas d'onglet « %s »" % c)
	_check(bp._cat_buttons.has("loisirs") and bp._cat_buttons.has("espaces") and bp._cat_buttons.has("sport"), "catalogue : loisirs, sport et espaces publics restent")
	bp.set_open(true)
	bp.show_category("zoo")
	_check(bp.category() == "logement", "onglet verrouillé demandé : Logement à la place")
	bp.set_open(false)

	print("Limite de la partie :")
	var lim: LimiteDemo = scene.limite_demo
	var faux := {"jour": 20000, "habitants": 40, "nom": "Valfleuri"}
	lim.lire = func() -> Dictionary: return faux
	lim.jour0 = -1
	lim.fin = false
	scene.ambiance.set_speed(DayNight.DEFAULT_SPEED)
	lim.verifier()
	_check(lim.jour0 == 20000 and not lim.fin, "premier jour noté, pas de fin")
	faux.jour = 20000 + EditionDemo.JOURS_MAX - 1
	lim.verifier()
	_check(not lim.fin and lim.restant().jours == 1, "un jour avant la limite")
	faux.jour = 20000 + EditionDemo.JOURS_MAX
	lim.verifier()
	await _frames(2)
	_check(lim.fin, "limite des jours atteinte")
	_check(scene.ambiance.speed_index == 0, "temps en pause")
	var fin: FinDemo = scene.fin_demo
	_check(fin != null and fin.motif == FinDemo.Motif.LIMITE, "écran de fin de la démo")
	if fin != null:
		_check(fin.find_child("Souhaits", true, false) != null, "bouton Ajouter à ma liste de souhaits")
		_check(fin.sous_titre().contains("Valfleuri") and fin.sous_titre().contains("%d jours" % EditionDemo.JOURS_MAX), "texte : %s" % fin.sous_titre())
		(fin.find_child("Regarder", true, false) as Button).pressed.emit()
		await _frames(2)
		_check(scene.fin_demo == null, "Regarder ma ville : l'écran se ferme")
	scene.ambiance.set_speed(DayNight.DEFAULT_SPEED)
	lim.verifier()
	_check(scene.ambiance.speed_index == 0, "le temps ne repart pas")
	var d := lim.to_dict()
	var lim2 := LimiteDemo.new()
	lim2.from_dict(d)
	_check(lim2.fin and lim2.jour0 == 20000, "limite sauvegardée (%s)" % str(d))
	lim2.free()
	_check(scene.save_sections().has("edition_demo"), "section de sauvegarde « edition_demo »")
	# Limite des habitants.
	lim.fin = false
	lim.jour0 = -1
	faux.jour = 30000
	faux.habitants = EditionDemo.HABITANTS_MAX
	lim.verifier()
	await _frames(2)
	_check(lim.fin and scene.fin_demo != null and scene.fin_demo.sous_titre().contains("%d habitants" % EditionDemo.HABITANTS_MAX), "limite des habitants")

	print("Jeu complet : rien de bloqué :")
	EditionDemo.forcee = 0
	if scene.fin_demo != null:
		scene.fin_demo.fermer()
	lim.fin = false
	lim.jour0 = 0
	faux.jour = 99999
	scene.ambiance.set_speed(DayNight.DEFAULT_SPEED)
	lim.verifier()
	_check(not lim.fin and scene.ambiance.speed_index == DayNight.DEFAULT_SPEED, "pas de limite")
	_check(EditionDemo.touche_verrouillee(_touche(KEY_Z)) == "", "Maj+Z libre")
	hud._on_category("zoo")
	await _frames(2)
	_check(scene.zoo_panel.is_open(), "bouton Zoo ouvre le zoo")

	EditionDemo.forcee = -1
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
