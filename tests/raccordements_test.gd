extends SceneTree
## Test des icônes de raccordement (scripts/reseaux/raccordements.gd) :
## bâtiment loin de toute route = icônes rouges (électricité, eau, égouts) ;
## au bord de la route sans centrale = coupé (orange, seulement dans la vue O) ;
## époques (rien en 1850, eau et égouts en 1910, électricité en 1930) ;
## option pour masquer ; réseaux non obligatoires ; alerte de la Mairie qui
## emmène au bâtiment ; fiche du bâtiment ; atlas et MultiMesh.
## Usage : godot --headless --path . --script res://tests/raccordements_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


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


func _annee(r: ReglagesPartie, a: int) -> void:
	r.annee_depart = a
	r.histoire_saut = 0
	r.histoire_debut = 0.0


func _causes(rac: Raccordements, bid: int) -> Dictionary:
	var d := {}
	for m in rac.manques_de(bid):
		d[m[0]] = m[1]
	return d


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	print("Atlas :")
	var at := Raccordements.atlas()
	_check(at != null and at.get_width() == Raccordements.CASE * 4 and at.get_height() == Raccordements.CASE * 2, "atlas 4 × 2 icônes")
	var img := at.get_image()
	var c_rouge := img.get_pixel(Raccordements.CASE / 2, 10)
	var c_orange := img.get_pixel(Raccordements.CASE / 2, Raccordements.CASE + 10)
	_check(c_rouge.a > 0.9 and c_rouge.r > 0.7 and c_rouge.g < 0.35, "fond rouge pour « pas raccordé »")
	_check(c_orange.a > 0.9 and c_orange.g > 0.4, "fond orange pour « coupé »")
	var centre_vide := true
	for col in 4:
		var px := img.get_pixel(col * Raccordements.CASE + Raccordements.CASE / 2, Raccordements.CASE / 2)
		if px.r > 0.95 and px.g > 0.95 and px.b > 0.95:
			centre_vide = false
	_check(not centre_vide, "les pictogrammes blancs sont dessinés")
	_check(Raccordements.icone("eau", Raccordements.NON_RACCORDE, 18).get_width() == 18, "icône seule pour l'interface")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(45.75, 4.85)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var res: Reseaux = scene.reseaux
	var rac := res.raccordements
	_check(rac != null and rac.reseaux == res and rac.telecom == scene.telecom, "icônes branchées sur les réseaux et le téléphone")
	var r := ReglagesPartie.actuel
	r.reseaux_obligatoires = true
	r.deblocage = "tout"
	_annee(r, 0)
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-21T12:00:00")
	bs.money = 5_000_000_000
	bs.require_access = false
	r.telecom_necessaire = true

	print("Ville d'aujourd'hui :")
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-300, y, 0), Vector3(300, y, 0)).ok, "route est-ouest")
	var pres := bs.place("immeuble", Vector2i(0, 14), bs.best_rotation("immeuble", Vector2i(0, 14)))
	var loin := bs.place("immeuble", Vector2i(0, 260), 0)
	var loin2 := bs.place("maison", Vector2i(80, 300), 0)
	_check(pres > 0 and loin > 0 and loin2 > 0, "un immeuble au bord de la route, deux bâtiments à plus de 250 m")
	if not ok:
		quit(1)
		return
	await process_frame
	await process_frame
	res.simuler(0.0)
	rac.maj()
	var cl := _causes(rac, loin)
	_check(cl.get("elec") == Raccordements.NON_RACCORDE and cl.get("eau") == Raccordements.NON_RACCORDE and cl.get("egout") == Raccordements.NON_RACCORDE,
		"loin de la route : pas raccordé à l'électricité, l'eau, les égouts")
	_check(cl.get("telecom") == Raccordements.NON_RACCORDE, "ni internet")
	var cp := _causes(rac, pres)
	_check(cp.get("elec") == Raccordements.COUPE and cp.get("eau") == Raccordements.COUPE, "au bord de la route sans centrale : raccordé mais coupé")
	_check(not rac.est_non_raccorde(pres) and rac.est_non_raccorde(loin), "seul le bâtiment isolé compte comme non raccordé")
	_check(rac.nb_non_raccordes == 2, "2 bâtiments non raccordés")
	_check(rac.nb_icones == 8 and rac._mm.multimesh.instance_count == 8, "jeu normal : 4 icônes rouges par bâtiment isolé, rien pour les coupés (%d)" % rac.nb_icones)
	var cd: Color = rac.icones[0][1]
	_check(cd.g == 0.0 and absf(cd.b) > 0.1, "icônes rouges côte à côte au-dessus du toit")
	var t0: Vector3 = rac.icones[0][0]
	_check(t0.y > float(bs.buildings[loin].get("h", 0.0)) + 5.0, "posées au-dessus du toit")

	print("Vue des réseaux (O) :")
	res.vue.set_calque("elec", true)
	rac._process(0.1)
	_check(rac._fort and rac._mm.material_override == rac._mat_fort, "icônes plus marquées (grandes, devant les bâtiments)")
	var orange := 0
	for ic in rac.icones:
		if (ic[1] as Color).g == 1.0:
			orange += 1
	_check(orange == 1, "le bâtiment coupé a son icône orange, seulement pour le réseau de l'onglet (%d)" % orange)
	res.vue.set_calque("elec", false)
	rac._process(0.1)
	_check(not rac._fort and rac.nb_icones == 8, "hors de la vue O : retour aux seules icônes rouges")

	print("Option :")
	OptionsJeu.icones_raccordement = false
	rac._process(0.1)
	_check(not rac._mm.visible, "Options → Jeu : icônes masquées")
	OptionsJeu.icones_raccordement = true
	rac._process(0.1)
	_check(rac._mm.visible, "et réaffichées")

	print("Fiche du bâtiment :")
	var lignes := rac.etat_reseaux(loin)
	var txt := ""
	for e in lignes:
		txt += String(e[1]) + "\n"
	_check(txt.contains("Électricité : pas raccordé") and txt.contains("Eau potable : pas raccordé") and txt.contains("Égouts : pas raccordé"), "fiche : chaque réseau dit « pas raccordé »")
	_check(txt.contains("Chauffage") and txt.contains("Internet"), "fiche : chauffage et internet aussi")
	var lp := ""
	for e in rac.etat_reseaux(pres):
		lp += String(e[1]) + "\n"
	_check(lp.contains("raccordé mais coupé (pas assez de production"), "fiche : raccordé mais coupé, avec la raison")
	var box := VBoxContainer.new()
	root.add_child(box)
	_check(rac.remplir_fiche(box, loin) == lignes.size() and box.get_child_count() == lignes.size() + 1, "rubrique Réseaux de la fiche : une ligne par réseau, plus la légende du flux")
	box.queue_free()
	var hp: HabitantsPanel = scene.habitants_panel
	scene.population._sync_buildings()
	hp._panel.visible = true
	hp.show_view("batiment", loin)
	var vu := false
	for n in hp._body.find_children("*", "Label", true, false):
		if (n as Label).text.contains("Électricité : pas raccordé"):
			vu = true
	_check(vu, "la fiche du bâtiment (clic) montre la rubrique Réseaux")

	print("Mairie :")
	var al := rac.alertes()
	_check(al.size() == 1 and String(al[0].panneau) == "non_raccorde" and String(al[0].titre).contains("2 bâtiments non raccordés"), "alerte : %s" % (al[0].titre if not al.is_empty() else "aucune"))
	scene.statistiques.releve()
	var vues: Array = scene.mairie_panel.alertes(4).filter(func(a) -> bool: return String(a.id) == "non_raccordes")
	_check(vues.size() == 1, "l'alerte est dans le tableau de bord de la Mairie (M), parmi les 4 premières")
	var b1: int = scene.aller_au_non_raccorde()
	var p1 := BuildingSystem.rect_center(bs._rect_of(bs.buildings[b1]))
	_check([loin, loin2].has(b1) and absf(scene.rig.position.x - p1.x) < 1.0 and absf(scene.rig.position.z - p1.z) < 1.0, "« Y aller » centre la caméra sur le bâtiment")
	_check(scene.population.selected() == b1, "et ouvre sa fiche")
	var b2: int = scene.aller_au_non_raccorde()
	_check(b2 != b1 and [loin, loin2].has(b2), "clic suivant : le bâtiment non raccordé suivant")

	print("Époques :")
	_annee(r, 1850)
	res.simuler(0.0)
	rac.maj()
	_check(rac.manques.is_empty() and rac.nb_icones == 0, "en 1850 : personne n'attend l'eau courante ni l'électricité")
	_check(rac.etat_reseaux(loin)[0][1].contains("pas encore attendu"), "fiche : « pas encore attendu en 1850 »")
	_annee(r, 1910)
	res.simuler(0.0)
	rac.maj()
	var c19 := _causes(rac, loin)
	_check(c19.has("eau") and c19.has("egout") and not c19.has("elec") and not c19.has("telecom"), "en 1910 : eau et égouts, pas encore l'électricité")
	_annee(r, 1930)
	res.simuler(0.0)
	rac.maj()
	_check(_causes(rac, loin).has("elec") and not _causes(rac, loin).has("telecom"), "en 1930 : l'électricité aussi, pas encore internet")
	_annee(r, 0)

	print("Raccordement :")
	_check(transport.build_segment("route", Vector3(-32, y, 0), Vector3(-32, y, 328)).ok and transport.build_segment("route", Vector3(-32, y, 328), Vector3(120, y, 328)).ok, "une route jusqu'aux bâtiments isolés")
	await process_frame
	res.simuler(0.0)
	scene.telecom.recalculer()
	rac.maj()
	_check(not rac.est_non_raccorde(loin) and not rac.est_non_raccorde(loin2) and rac.nb_icones == 0, "raccordés : plus d'icône rouge")
	_check(rac.alertes().is_empty(), "plus d'alerte")

	print("Réseaux non obligatoires :")
	bs.place("maison", Vector2i(-200, 400), 0)
	await process_frame
	res.simuler(0.0)
	scene.telecom.recalculer()
	rac.maj()
	_check(rac.nb_non_raccordes == 1, "une nouvelle maison isolée")
	r.reseaux_obligatoires = false
	res.simuler(0.0)
	rac.maj()
	_check(rac.manques.is_empty() and rac.nb_icones == 0, "réseaux non obligatoires (F10) : aucune icône")
	r.reseaux_obligatoires = true

	print("Performances :")
	var t := Time.get_ticks_usec()
	for i in 20:
		rac.maj()
	_check(true, "20 mises à jour en %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))

	print("RACCORDEMENTS TEST OK" if ok else "RACCORDEMENTS TEST ÉCHEC")
	quit(0 if ok else 1)
