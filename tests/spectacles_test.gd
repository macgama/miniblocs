extends SceneTree
## Test des spectacles : bâtiments et modèles, tournées, salles reconnues,
## programmation (à la main et automatique), public et argent d'une soirée,
## cinémas et films à l'affiche, plein air et pluie, studios (annexes, film
## de la préparation aux droits télé, festival), avis, sauvegarde, menu
## (barre du bas, Maj+X) et public visible.
## Usage : godot --headless --path . --script res://tests/spectacles_test.gd

var ok := true

## Samedi 18 juillet 2026, 9 h (heure de Suisse romande, UTC+2).
const SAMEDI := 1_784_358_000.0


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


func _run() -> void:
	_catalog_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _catalog_tests() -> void:
	print("Catalogue :")
	var ids := BuildingCatalog.ids_in("spectacles")
	_check(ids.size() == SpectaclesTypes.ORDER.size(), "%d bâtiments dans la catégorie Spectacles" % ids.size())
	for id in SpectaclesTypes.ORDER:
		var t := BuildingCatalog.get_type(id)
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "modèle de %s" % id)
		var aabb := m.get_aabb()
		_check(aabb.size.x <= float(t.w) + 0.05 and aabb.size.z <= float(t.d) + 0.05, "%s tient dans son emprise" % id)
		for j in Metiers.jobs_for(id):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
		var sp: Dictionary = t.spect
		for g in sp.get("genres", []):
			_check(SpectaclesProgrammes.GENRES.has(String(g)), "%s : genre %s connu" % [id, g]) if not SpectaclesProgrammes.GENRES.has(String(g)) else null
	_check(BuildingCatalog.cost("opera_coupole") == 75_000_000, "prix du grand opéra")
	var caches := []
	for id in SpectaclesTypes.ORDER:
		if not BuildingCatalog.get_type(id).has("spect"):
			caches.append(id)
	_check(caches.is_empty(), "aucun id déjà pris par un autre catalogue %s" % str(caches))
	_check(SpectaclesTypes.spec_of("opera").famille == "theatre" and SpectaclesTypes.spec_of("salle_concert").famille == "concert"
		and SpectaclesTypes.spec_of("cinema_multiplexe").famille == "cinema" and SpectaclesTypes.spec_of("amphitheatre_romain").get("plein_air", false),
		"opéra, salle de concert, multiplexe et amphithéâtre de la bible Blender reconnus")
	# Chaque tournée peut jouer quelque part.
	var nt := 0
	for sp in SpectaclesProgrammes.TOURNEES:
		var e: Array = SpectaclesProgrammes.TOURNEES[sp]
		var g := String(e[1])
		var lieu := false
		for id in SpectaclesTypes.ORDER:
			var s: Dictionary = SpectaclesTypes.TYPES[id].spect
			if (s.get("genres", []) as Array).has(g) and int(s.get("places", 0)) >= int(e[4]):
				lieu = true
		if not lieu:
			_check(false, "%s n'a aucune salle où jouer" % sp)
		nt += 1
	_check(nt >= 60, "%d spectacles en tournée, tous jouables quelque part" % nt)
	_check(SpectaclesProgrammes.genres_films().size() == 12, "12 genres de films")
	# Bâtiments d'autres catalogues reconnus.
	_check(SpectaclesTypes.role_of("cinema") == "salle" and SpectaclesTypes.spec_of("cinema").famille == "cinema", "le cinéma du catalogue est une salle")
	_check(SpectaclesTypes.spec_of("kiosque_musique").famille == "concert", "le kiosque à musique accueille des concerts")
	var opera_style := ""
	for id in BuildingCatalog.all_types():
		var t: Dictionary = BuildingCatalog.all_types()[id]
		if String(t.get("arch", "")) == "theatre" and String(t.get("name", "")).contains("Opéra"):
			opera_style = String(id)
			break
	_check(opera_style != "" and SpectaclesTypes.spec_of(opera_style).famille == "theatre", "l'opéra des styles du monde est un théâtre (%s)" % opera_style)
	_check(SpectaclesTypes.spec_of("maison").is_empty(), "une maison n'est pas une salle")
	_check(Icones.has_icon("masques") and Icones.has_icon("clap") and Icones.has_icon("micro"), "icônes des spectacles")
	_check(Nuisances.emission_of("salle_musiques_actuelles").get("nuit", false), "une salle de concert fait du bruit la nuit")
	var trouve := false
	for c in TerreHud.CATEGORIES:
		if String(c.id) == "spectacles" and String(c.get("group", "")) == "loisirs" and String(c.key) == "Maj+X":
			trouve = true
	_check(trouve, "bouton Spectacles (Maj+X) dans le menu Loisirs de la barre du bas")
	var titre := SpectaclesProgrammes.titre_au_hasard("western", RandomNumberGenerator.new())
	_check(titre != "" and not titre.contains("%"), "titre de film inventé : « %s »" % titre)


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var spect: Spectacles = scene.spectacles
	_check(spect != null and scene.spectacles_panel != null, "spectacles et menu branchés dans la scène")
	_check(scene.save_sections().has("spectacles"), "section « spectacles » dans la sauvegarde")
	var pop: Population = scene.population
	for n in [transport.traffic, spect, pop, scene.parc, scene.zoo, scene.musee, scene.dechets, scene.production]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	if scene.ambiance.weather != null:
		scene.ambiance.weather.set_process(false)
		scene.ambiance.weather.precip = 0.0
	bs.unlimited_money = false
	bs.money = 400_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-600, y, 0), Vector3(600, y, 0))
	_check(road.ok, "route de 1,2 km")
	var homes: Array[int] = []
	for i in 30:
		var c := Vector2i(-560 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	_check(pop.persons.size() > 60, "%d habitants" % pop.persons.size())
	spect.ignore_staff = true

	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	bs.message.connect(func(t: String) -> void: print("    (bâtiments) ", t))
	var theatre: int = poser.call("theatre_italienne", Vector2i(-300, -26))
	var smac: int = poser.call("salle_musiques_actuelles", Vector2i(-240, -22))
	var multi: int = poser.call("multiplexe", Vector2i(-160, -28))
	var plein: int = poser.call("cinema_plein_air", Vector2i(-90, -25))
	var studio: int = poser.call("studio_cinema", Vector2i(100, -37))
	var western := bs.place("decor_western", Vector2i(100, -130), 0)
	var post := bs.place("post_production", Vector2i(170, -80), 0)
	var plat := bs.place("plateau_tournage", Vector2i(30, -110), 0)
	_check(theatre > 0 and smac > 0 and multi > 0 and plein > 0 and studio > 0, "salles et studios posés au bord de la route %s" % str([theatre, smac, multi, plein, studio]))
	_check(western > 0 and post > 0 and plat > 0, "décor western, post-production et plateau posés à côté des studios")
	spect._sync()
	_check(spect.list_salles().size() == 4 and spect.list_salles("cinema").size() == 2, "4 salles reconnues, dont 2 cinémas")
	_check(spect.list_studios() == [studio], "les studios sont reconnus")
	_check(spect.places(theatre) == 750 and spect.note(theatre) > 3.0, "théâtre : 750 places, %.1f étoiles" % spect.note(theatre))

	print("Programmation :")
	spect.clock = SAMEDI - 3600.0
	spect.last_day = int(spect._now(SAMEDI).day)
	spect._majs_ages()
	var today := spect._today()
	var sam := spect.date_of(today)
	_check(int(sam.wd) == 6 and int(sam.month) == 7, "nous sommes un samedi de juillet")
	_check(spect.compatible(smac, "stella_nova") != "", "Stella Nova ne joue pas dans une salle de 1 100 places : %s" % spect.compatible(smac, "stella_nova"))
	_check(spect.compatible(theatre, "mc_bitume") != "", "pas de rap au théâtre à l'italienne")
	_check(spect.compatible(theatre, "cyrano") == "", "Cyrano au théâtre : oui")
	_check(spect.creneaux(theatre, spect.date_of(today + 2), "theatre_classique").is_empty(), "relâche le lundi au théâtre")
	_check(spect.creneaux(smac, spect.date_of(today + 3), "rock") == [], "pas de concert le mardi")
	_check(spect.creneaux(theatre, sam, "cirque") == [15, 20] and spect.creneaux(theatre, spect.date_of(today + 1), "comedie") == [16], "cirque à 15 h et 20 h le samedi, matinée à 16 h le dimanche")
	# Une ville moyenne (les vrais habitants du test sont une centaine).
	spect.habitants_force = 15000
	spect._nouveau_jour_programmes()
	var ag_t := spect.agenda(theatre)
	var ag_c := spect.agenda(smac)
	_check(ag_t.size() >= 6, "programmation automatique du théâtre : %d dates en 10 jours" % ag_t.size())
	_check(ag_c.size() >= 4, "programmation automatique de la salle de concert : %d dates" % ag_c.size())
	var bon := true
	for ev in ag_c:
		bon = bon and int(spect.date_of(int(ev.d)).wd) in [3, 4, 5, 6]
	_check(bon, "concerts du mercredi au samedi")
	var deux_fois := false
	for ev in ag_t:
		deux_fois = deux_fois or spect._en_tournee_ailleurs(String(ev.sp), int(ev.d), theatre)
	_check(not deux_fois, "un artiste ne joue pas dans deux salles le même soir")
	spect.set_auto(theatre, false)
	var avant := spect.agenda(theatre).size()
	var n := spect.programmer(theatre, "carmen", 2, today + 30)
	_check(n == 2 and spect.agenda(theatre).size() == avant + 2, "Carmen programmé à la main : 2 dates")
	_check(spect.programmer(smac, "carmen", 1) == -1, "pas d'opéra dans une salle de musiques actuelles")

	print("Une soirée :")
	var soir := spect._now(SAMEDI + 11 * 3600.0)
	spect.set_prix(theatre, 15.0)
	var d_cheap := spect.demande(theatre, "cyrano", soir)
	spect.set_prix(theatre, 90.0)
	var d_cher := spect.demande(theatre, "cyrano", soir)
	_check(d_cheap > d_cher * 1.5, "un billet cher fait fuir le public (%d contre %d candidats)" % [roundi(d_cheap), roundi(d_cher)])
	spect.set_prix(theatre, 30.0)
	var a0 := spect.ages.duplicate()
	spect.ages = [0.05, 0.8, 0.1, 0.05]
	var rap_jeunes := spect.gout("rap")
	var clas_jeunes := spect.gout("classique")
	spect.ages = [0.02, 0.05, 0.23, 0.7]
	_check(rap_jeunes > clas_jeunes and spect.gout("classique") > spect.gout("rap"), "les jeunes préfèrent le rap, les seniors le classique")
	spect.ages = a0
	_check(spect.demande(smac, "stella_nova", soir) > spect.demande(smac, "rateaux_rouilles", soir) * 3.0, "une star attire bien plus de monde (et la région)")
	var argent := bs.money
	var res := spect.jouer(theatre, "cyrano", soir)
	_check(int(res.public) > 0 and float(res.recette) > 0.0, "Cyrano : %d spectateurs, %s de recettes" % [int(res.public), BuildingSystem.format_money(int(res.recette))])
	_check(bs.money != argent, "billets, cachet et technique passent par la caisse (%s)" % BuildingSystem.format_money(bs.money - argent))
	_check(spect.salles[theatre].historique.size() == 1 and int(spect.salles[theatre].jour.representations) == 1, "représentation inscrite à l'historique")
	_check(not (spect.salles[theatre].dernieres as Array).is_empty(), "le public dit ce qu'il en pense : %s" % (spect.salles[theatre].dernieres[0] if not (spect.salles[theatre].dernieres as Array).is_empty() else ""))
	var vu := spect.demande(theatre, "cyrano", soir)
	spect.salles[theatre].vus["cyrano"] = 5000.0
	_check(spect.demande(theatre, "cyrano", soir) < vu, "ceux qui l'ont déjà vu ne reviennent pas")
	spect.salles[theatre].vus.erase("cyrano")

	print("Cinémas :")
	_check(spect.films_affiche_monde().size() >= 6, "%d films à l'affiche" % spect.films_affiche_monde().size())
	_check(spect.affiche(multi).size() == mini(12, spect.films_affiche_monde().size()) and spect.affiche(plein).size() == 1, "un film par écran")
	for h in 24:
		spect.clock = SAMEDI + h * 3600.0
		var now := spect._now(spect.clock)
		spect._seance(multi, now, int(floorf(float(now.h))))
	_check(int(spect.salles[multi].jour.spectateurs) > 0, "multiplexe : %d spectateurs dans la journée" % int(spect.salles[multi].jour.spectateurs))
	_check(int(spect.salles[multi].jour.representations) == 4, "quatre séances")
	_check(spect.saison_ouverte(plein, 7) and not spect.saison_ouverte(plein, 1), "le cinéma en plein air ferme l'hiver")
	scene.ambiance.weather.precip = 1.0
	spect._seance(plein, spect._now(SAMEDI + 13 * 3600.0), 22)
	_check(int(spect.salles[plein].jour.annulations) == 1, "séance en plein air annulée sous la pluie")
	scene.ambiance.weather.precip = 0.0
	var f0 := int(spect.affiche(multi)[spect.affiche(multi).size() - 1])
	spect.forcer_affiche(plein, f0)
	_check(spect.affiche(plein) == [f0], "épingler un film le garde à l'affiche")

	print("Studios :")
	var an := spect.annexes(studio)
	_check((an.decors as Dictionary).has("western") and bool(an.postprod) and int(an.plateau) == 1, "annexes trouvées : %s" % str(an))
	_check(spect.plateaux(studio) == 3, "3 plateaux (2 + 1)")
	var dv := spect.devis(studio, "western", "petit", "paolo_spaghetti", "kevin_du_coin")
	var dv_sf := spect.devis(studio, "sf", "petit", "paolo_spaghetti", "kevin_du_coin")
	_check(float(dv.budget) < float(dv_sf.budget) and int(dv.jours) < int(dv_sf.jours), "le décor western raccourcit et allège un western")
	_check(not (dv_sf.conseils as Array).is_empty(), "conseils du devis : %s" % str(dv_sf.conseils))
	argent = bs.money
	var err := spect.lancer_film(studio, "western", "petit", "paolo_spaghetti", "kevin_du_coin", "Le Shérif de Granit")
	_check(err == "", "film lancé (%s)" % err)
	_check(bs.money < argent, "cachets et préparation payés : %s" % BuildingSystem.format_money(argent - bs.money))
	var fid := int(spect.films_du_studio(studio)[0])
	_check(String(spect.films[fid].phase) == "prep" and spect.plateaux_libres(studio) == 2, "en préparation, un plateau pris")
	spect.lancer_film(studio, "comedie_film", "court", "leo_premier", "inconnus")
	spect.lancer_film(studio, "drame_film", "court", "leo_premier", "inconnus")
	_check(spect.lancer_film(studio, "sf", "court", "leo_premier", "inconnus").contains("plateaux"), "plus de plateau libre : refusé")
	var vu_salle := false
	var day := spect.last_day
	for i in 120:
		day += 1
		spect.last_day = day
		spect.new_day(spect.date_of(day))
		if String(spect.films[fid].phase) == "salle" and spect.affiche(multi, day).has(fid):
			vu_salle = true
		if String(spect.films[fid].phase) == "fini":
			break
	var f: Dictionary = spect.films[fid]
	_check(String(f.phase) == "fini", "le film est passé par le tournage, le montage et les salles")
	_check(int(f.q) > 0 and int(f.presse) > 0 and int(f.public) > 0, "qualité %d, presse %d, public %d" % [int(f.q), int(f.presse), int(f.public)])
	_check(int(f.entrees) > 10_000 and float(f.recettes) > 0.0 and float(f.get("tv", 0.0)) > 0.0, "%s entrées, recettes %s dont droits télé %s" % [Spectacles._nombre(int(f.entrees)),
		BuildingSystem.format_money(int(f.recettes)), BuildingSystem.format_money(int(f.get("tv", 0)))])
	_check(vu_salle, "ton film passe dans le multiplexe de la ville")
	_check(float(spect.studios[studio].reputation) != 20.0, "la réputation des studios a bougé (%d)" % roundi(float(spect.studios[studio].reputation)))
	f.presse = 99
	f.prix = ""
	f.sortie = day - 10
	var gagne := false
	for i in 8:
		spect._festival(day)
		if String(f.prix) != "":
			gagne = true
			break
	_check(gagne and not (spect.studios[studio].prix as Array).is_empty(), "Bobine d'or : %s" % String(f.prix))

	print("Avis, public visible :")
	var pid := int(pop.persons.keys()[0])
	spect.sorties[pid] = spect.last_day
	_check(float(spect.satisfaction_of(pop.persons[pid])[0]) >= 2.0, "une soirée au spectacle rend heureux")
	spect.programmer(theatre, "le_cid", 1, int(spect._now(SAMEDI).day))
	var avant_spect := spect._now(SAMEDI + 10 * 3600.0 + 1800.0)
	spect.set_auto(theatre, false)
	_check(spect.foule(theatre, avant_spect) > 0, "du monde devant le théâtre avant le spectacle (%d)" % spect.foule(theatre, avant_spect))

	print("Sauvegarde :")
	var d := spect.to_dict()
	var back: Dictionary = JSON.parse_string(JSON.stringify(d))
	var n_films := spect.films.size()
	var n_ag := spect.agenda(theatre).size()
	spect.from_dict(back)
	spect._sync()
	_check(spect.salles.size() == 4 and spect.studios.size() == 1 and spect.films.size() == n_films, "salles, studios et films relus")
	_check(spect.agenda(theatre).size() == n_ag and typeof(spect.agenda(theatre)[0].d) == TYPE_INT, "agenda relu (%d dates)" % n_ag)
	_check(String(spect.films[fid].phase) == "fini" and String(spect.films[fid].prix) != "", "film et prix relus")

	print("Menu :")
	var hud: TerreHud = scene.hud
	scene.spectacles_panel.set_open(false)
	hud._on_category("spectacles")
	var panel: SpectaclesPanel = scene.spectacles_panel
	_check(panel.is_open(), "le bouton ouvre le menu Spectacles")
	for v in ["salles", "programmer", "studios", "batir", "amenager", "affiche", "public"]:
		panel.show_view(v)
		_check(panel._body.get_child_count() > 2, "onglet %s" % v)
	panel.choisi = smac
	panel.show_view("programmer")
	var boutons := 0
	for c in panel._body.get_children():
		if c is VBoxContainer:
			for c2 in c.get_children():
				if c2 is HBoxContainer:
					boutons += c2.get_child_count()
	_check(boutons >= 6, "des tournées à réserver dans la salle de concert (%d boutons)" % boutons)
	panel.set_open(false)
	spect.visuels.spect = spect
	scene.ambiance.unix_time = SAMEDI + 10 * 3600.0 + 1800.0
	spect.visuels._placer()
	_check(spect.visuels.compte() > 0, "%d personnages devant les salles" % spect.visuels.compte())
	scene.queue_free()
	await process_frame
