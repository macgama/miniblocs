extends SceneTree
## Test des devantures vivantes (scripts/devantures) : profils de tous les
## bâtiments du catalogue, styles d'époque, enseignes, puis une vraie rue :
## vitrine creusée, objets selon le stock (pleine, vide et affichette),
## store déplié le jour et replié le soir, terrasse du café, plaque des
## maisons, stock dehors de l'atelier, façade creusée dans le matériau.
## Usage : godot --headless --path . --script res://tests/devantures_test.gd

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


func _info(dev: Devantures, bid: int) -> Dictionary:
	for m in dev.montres:
		if int(m.bid) == bid:
			return m
	return {}


func _run() -> void:
	print("Profils :")
	var types := BuildingCatalog.all_types()
	var genres := {}
	var sans := []
	for id in types:
		var p := DevanturesTypes.profil(String(id))
		var cat := String(types[id].get("cat", ""))
		if p.is_empty():
			if cat in ["commerce", "services", "logement", "industrie", "production", "loisirs"]:
				sans.append(String(id))
			continue
		genres[String(p.genre)] = int(genres.get(String(p.genre), 0)) + 1
		if String(p.genre) == DevanturesTypes.BOUTIQUE:
			_check_silencieux(not (p.objets as Array).is_empty(), "objets de %s" % id)
	_check(sans.is_empty(), "tous les commerces, services, logements, usines et fermes ont une devanture (%s)" % ", ".join(sans.slice(0, 6)))
	for g in [DevanturesTypes.BOUTIQUE, DevanturesTypes.SALLE, DevanturesTypes.HALL, DevanturesTypes.ENTREPRISE, DevanturesTypes.LOGIS]:
		_check(int(genres.get(g, 0)) > 0, "genre « %s » : %d bâtiments" % [g, int(genres.get(g, 0))])
	_check(String(DevanturesTypes.profil("boulangerie").cle) == "boulangerie", "la boulangerie a son profil")
	_check((DevanturesTypes.profil("boulangerie").vend as Array).has("pain"), "la boulangerie vend du pain (économie)")
	_check(String(DevanturesTypes.profil("bistrot_parisien").genre) == DevanturesTypes.SALLE, "le bistrot a une salle et une terrasse")
	_check(String(DevanturesTypes.profil("mairie").genre) == DevanturesTypes.HALL, "la mairie a un hall d'accueil")
	_check(String(DevanturesTypes.profil("ferme").genre) == DevanturesTypes.ENTREPRISE, "la ferme montre son stock dehors")
	print("Époques :")
	_check(String(DevanturesTypes.style(1850).id) == "ancien" and bool(DevanturesTypes.style(1850).carreaux), "1850 : petits carreaux, bois")
	_check(bool(DevanturesTypes.style(1960).neon), "1960 : néon")
	_check(String(DevanturesTypes.style(2026).id) == "moderne", "2026 : moderne")
	var objs := DevanturesTypes.objets_a(DevanturesTypes.profil("magasin_multimedia"), 1900)
	_check(not objs.has("ecran"), "pas d'écran en vitrine en 1900 (%s)" % ", ".join(objs))
	_check(DevanturesTypes.palier(0.0) == 0 and DevanturesTypes.palier(1.0) == 4 and DevanturesTypes.palier(0.3) == 2, "paliers de remplissage")
	var nom := DevanturesTypes.enseigne(DevanturesTypes.profil("boulangerie"), "boulangerie", 7, "Dubois")
	_check(nom == "Boulangerie Dubois", "enseigne au nom du patron (%s)" % nom)
	_check(DevanturesTypes.enseigne(DevanturesTypes.profil("mairie"), "mairie", 3, "Dubois") == "Mairie", "enseigne de la mairie")

	print("Une rue :")
	Creations.persist = false
	ReglagesPartie.actuel.deblocage = "tout"
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 30:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T10:30:00")
	bs.unlimited_money = true
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -120), Vector3(0, y, 120))
	var boul := bs.place("boulangerie", Vector2i(13, -20), 3)
	var cafe := bs.place("bistrot_parisien", Vector2i(16, 0), 3)
	var maison := bs.place("maison", Vector2i(-13, -20), 1)
	var atelier := bs.place("atelier", Vector2i(-17, 10), 1)
	var mairie := bs.place("mairie", Vector2i(-16, 40), 1)
	_check(boul > 0 and cafe > 0 and maison > 0 and atelier > 0 and mairie > 0, "bâtiments posés")
	var pop: Population = scene.population
	pop._sync_buildings()
	pop.spawn_household(maison)
	var dev: Devantures = scene.devantures
	var prod: Production = scene.production
	_check(dev != null and dev.production == prod, "devantures installées avec l'économie")
	prod._sync()
	var rig: Node3D = scene.rig
	rig.position = Vector3(4, y, -10)
	rig._distance = 30.0
	rig._target_distance = 30.0
	prod.sites[boul].st["pain"] = prod.cap_of(boul, "pain")
	dev.refresh()
	var ib := _info(dev, boul)
	_check(not ib.is_empty() and bool(ib.niche), "la boulangerie a une vitrine creusée")
	_check(String(ib.get("nom", "")).begins_with("Boulangerie"), "enseigne « %s »" % ib.get("nom", ""))
	_check(not (ib.paliers as Array).is_empty() and int((ib.paliers as Array).max()) == 4, "stock plein : vitrine pleine %s" % str(ib.paliers))
	_check(dev.trous.size() >= 1, "façade creusée (%d boîtes)" % dev.trous.size())
	var mat := NightWindows.building_material()
	_check(int(mat.get_shader_parameter("trou_count")) == dev.trous.size(), "matériau des bâtiments : %d trous" % int(mat.get_shader_parameter("trou_count")))
	# La boîte creusée contient bien le pied de la façade, au milieu de la vitrine.
	var bx: Transform3D = dev.trous[0][0]
	var half: Vector3 = dev.trous[0][1]
	var q: Vector3 = bx.affine_inverse() * (bx.origin + bx.basis.y * 0.5)
	_check(absf(q.y) < half.y, "le point de la vitrine est dans la boîte")
	prod.sites[boul].st["pain"] = 0.0
	dev.refresh()
	ib = _info(dev, boul)
	_check(int((ib.paliers as Array).max()) == 0 and bool(ib.rupture), "plus de pain : vitrine vide et affichette")
	prod.sites[boul].st["pain"] = prod.cap_of(boul, "pain") * 0.4
	dev.refresh()
	ib = _info(dev, boul)
	_check(int((ib.paliers as Array).max()) == 2, "stock à 40 %% : vitrine à moitié (%s)" % str(ib.paliers))
	var store_jour := String(ib.store)
	var ic := _info(dev, cafe)
	_check(String(ic.get("genre", "")) == DevanturesTypes.SALLE and bool(ic.niche), "le café a sa salle vue de la rue")
	var im := _info(dev, maison)
	_check(String(im.get("genre", "")) == DevanturesTypes.LOGIS and String(im.nom) != "", "plaque de la maison : « %s »" % im.get("nom", ""))
	var ia := _info(dev, atelier)
	_check(String(ia.get("genre", "")) == DevanturesTypes.ENTREPRISE and String(ia.nom) != "", "enseigne de l'atelier : « %s »" % ia.get("nom", ""))
	rig.position = Vector3(-4, y, 40)
	dev.refresh()
	var imr := _info(dev, mairie)
	_check(String(imr.get("nom", "")) == "Mairie" and bool(imr.niche), "hall de la mairie vu de la rue")
	# Le soir : store replié, vitrines éclairées.
	rig.position = Vector3(4, y, -10)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T22:30:00")
	amb.night = 1.0
	dev.refresh()
	ib = _info(dev, boul)
	_check(String(ib.store) == "replie", "le soir, le store est replié (le jour : %s)" % store_jour)
	_check(_info(dev, maison).get("lumiere", false), "le soir, la lampe d'entrée de la maison s'allume")
	# Époque : la vitrine de 1890 n'a ni néon ni écran.
	ReglagesPartie.actuel.annee_depart = 1890
	ReglagesPartie.actuel.histoire_debut = amb.unix_time
	_check(Epoques.annee() == 1890, "partie en 1890")
	dev.refresh()
	_check(not _info(dev, boul).is_empty(), "devanture de 1890 dessinée")
	ReglagesPartie.actuel.annee_depart = 0
	# Loin (vue de très haut) : plus rien de creusé.
	rig._distance = 400.0
	dev.refresh()
	_check(dev.trous.is_empty() and int(mat.get_shader_parameter("trou_count")) == 0, "vue de haut : aucune façade creusée")
	# Démolition : sa devanture disparaît.
	rig._distance = 30.0
	dev.refresh()
	bs.demolish(boul)
	dev.refresh()
	_check(_info(dev, boul).is_empty(), "boulangerie démolie : plus de devanture")
	print("DEVANTURES TEST %s" % ("OK" if ok else "ÉCHEC"))
	quit(0 if ok else 1)


func _check_silencieux(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
