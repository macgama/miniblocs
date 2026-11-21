extends SceneTree
## Test de la jouabilité « séance » : objectif de séance (Seance, 20 min, paliers
## bronze/argent/or, récompenses, bannière, carte, sauvegarde), alertes limitées à
## 3 avec « Régler », et la cause d'un problème en un clic (« Pourquoi ? »,
## Causes ; chantiers sans ouvriers).
## Usage : godot --headless --path . --script res://tests/seance_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(400.0).timeout.connect(func() -> void:
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


func _trouver(n: Node, nom: String) -> Node:
	return n.find_child(nom, true, false)


func _run() -> void:
	Langue.activer("fr")
	Creations.persist = false
	BatimentsVie.chantiers = true
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.tutoriel = false

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var cm: Communes = scene.communes
	var fd: Fondateurs = scene.fondateurs
	var pop: Population = scene.population
	var se: Seance = scene.seance
	scene.ambiance.set_speed(0)
	pop.arrivals = false
	bs.require_access = false
	if scene.tutoriel.actif:
		scene.tutoriel.arreter()

	print("Objectif de séance :")
	_check(se != null and Seance.instance == se and scene.seance_banniere != null, "séance et bannière branchées")
	_check(scene.tuto_carte.seance_carte != null and scene.tuto_carte.seance_carte.get_parent() == scene.tuto_carte._col, "carte de séance dans la colonne du tutoriel")
	se.suivre()
	_check(se.courante.is_empty(), "pas de séance sans ville")
	scene.kit.pays_de = func(_v: int) -> String: return "zz"
	scene.kit.pays_servis["zz"] = 0
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	_check(mc > 0, "Maison de commune posée")
	await process_frame
	await process_frame
	var vid := cm.principal()
	se.suivre()
	_check(not se.courante.is_empty() and int(se.courante.vid) == vid, "une séance commence avec la première ville")
	var c := se.courante
	_check(String(c.titre) != "" and String(c.pourquoi) != "", "but et raison : « %s » (%s)" % [c.titre, c.pourquoi])
	_check((c.cibles as Array).size() == 3 and float(c.cibles[0]) < float(c.cibles[1]) and float(c.cibles[1]) < float(c.cibles[2]),
		"trois paliers croissants : %s" % str(c.cibles))
	_check(se.restant() > 19.0 * 60.0 and se.texte_restant() == "20 min", "20 minutes au compteur")
	_check(se.prime_du_palier(1) + se.prime_du_palier(2) + se.prime_du_palier(3) == int(c.prime) and int(c.prime) > 0,
		"récompense répartie en 25/25/50 %% (%s)" % BuildingSystem.format_money(int(c.prime)))
	var carte: SeanceCarte = scene.tuto_carte.seance_carte
	carte.rafraichir()
	_check((_trouver(carte, "TitreSeance") as Label).text == String(c.titre), "la carte montre le but")
	_check((_trouver(carte, "Palier1") as Label).text.contains("Bronze") and (_trouver(carte, "Palier3") as Label).text.contains("Or"), "trois médailles sur la carte")
	_check((_trouver(carte, "Recompense") as Label).text.begins_with("+"), "la prochaine récompense est affichée")
	_check(Seance.nom_palier(1) == "Argent", "médaille « Argent » en français")
	Langue.activer("en")
	_check(Seance.nom_palier(1) == "Silver", "« Silver » en anglais (pas « Money »)")
	Langue.activer("fr")

	print("Paliers et récompenses :")
	# Séance « habitants » fixée pour le test : 10 / 20 / 30 habitants de plus.
	cm.calculer_stats()
	var h0 := int(cm.stats[vid].hab)
	se.courante = {"type": "habitants", "titre": "Faire grandir la ville", "pourquoi": "test", "vid": vid, "debut": se.ecoule,
		"atteints": 0, "depart": float(h0), "cibles": [h0 + 10.0, h0 + 20.0, h0 + 30.0], "prime": 100000}
	var argent0: int = scene.pays.solde(vid)
	var paliers := []
	se.palier_atteint.connect(func(n: int, _s: Dictionary) -> void: paliers.append(n))
	var points0 := ArbreProgression.points_gagnes(ReglagesPartie.actuel)
	cm.stats[vid].hab = h0 + 12
	_check(se.paliers_mesures() == 1, "12 habitants : le bronze est atteint")
	se.suivre()
	_check(paliers == [1] and int(se.courante.atteints) == 1, "bronze gagné")
	_check(is_equal_approx(se.progres(), 0.2), "barre : 20 %% vers l'argent")
	_check(scene.pays.solde(vid) - argent0 == 25000, "prime du bronze dans la caisse de la ville (+25 000 €)")
	_check(scene.seance_banniere.visible_maintenant(), "bannière au centre de l'écran")
	_check(se.texte_progres() == "12 / 20 habitants", "progrès en mots : %s" % se.texte_progres())
	cm.stats[vid].hab = h0 + 31
	se.suivre()
	_check(paliers == [1, 2, 3] and int(se.courante.atteints) == 3 and se.reussies == 1, "argent et or d'un coup : séance réussie")
	_check(scene.pays.solde(vid) - argent0 == 100000, "toute la récompense versée (100 000 €)")
	_check(ArbreProgression.points_gagnes(ReglagesPartie.actuel) == points0 + 1, "l'or rapporte un point de progrès")
	_check(se.medailles == [1, 1, 1], "médailles comptées")
	carte.rafraichir()
	_check((_trouver(carte, "SeanceSuivante") as Button).visible, "« Encore un objectif » une fois l'or gagné")
	se.derniers = ["habitants"]
	se.suivante()
	_check(int(se.courante.atteints) == 0 and String(se.courante.type) != "habitants", "nouvelle séance, avec un autre but (%s)" % se.courante.type)

	print("Fin du temps :")
	var fin := []
	se.terminee.connect(func(s: Dictionary) -> void: fin.append(s))
	var t0 := String(se.courante.type)
	se.ecoule += Seance.DUREE + 1.0
	se.suivre()
	_check(fin.size() == 1 and String(fin[0].type) == t0, "au bout de 20 min, la séance se termine (bilan)")
	_check(not se.courante.is_empty() and se.restant() > 19.0 * 60.0, "et la suivante commence")
	se.bloque = func() -> bool: return true
	var e0 := se.ecoule
	se._process(5.0)
	_check(is_equal_approx(se.ecoule, e0) and se.suspendue(), "pendant le tutoriel, le temps ne compte pas")
	se.bloque = Callable()

	print("Sauvegarde :")
	var d := se.to_dict()
	var se2 := Seance.new()
	se2.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(int(se2.courante.vid) == vid and se2.reussies == 1 and se2.medailles == [1, 1, 1] and is_equal_approx(se2.ecoule, se.ecoule),
		"séance, médailles et temps relus")
	se2.free()
	var types := {}
	for cible in ["habitants", "emplois", "logements", "satisfaction", "caisse", "batiment"]:
		types[cible] = se.cibles(cible, 10.0, vid)
	_check(float(types.caisse[2]) > 10.0 and float(types.batiment[2]) == 2.0, "cibles de tous les types")
	_check(se.cibles("caisse", -300000.0, vid) == [-200000.0, -100000.0, 0.0], "caisse dans le rouge : remonter par tiers jusqu'à zéro")

	print("Cause en un clic : chantiers sans ouvriers :")
	bs.unlimited_money = true
	var maisons := 0
	var x := -1000 + 60
	while maisons < 14 and x < -500:
		for z in [-60, 60]:
			var cc := Vector2i(x, z)
			if bs.check_place("colombages__maison", cc, 0).ok and bs.place("colombages__maison", cc, 0) > 0:
				maisons += 1
		x += 22
	fd.repartir()
	var al := Causes.alertes_chantiers(str(vid))
	_check(al.size() == 1 and String(al[0].id) == "chantiers_lents" and String(al[0].panneau) == "fondateurs", "alerte « chantiers à l'arrêt » qui ouvre Maj+H")
	var cause := Causes.de(al[0], str(vid))
	_check(String(cause.cause).begins_with("Pas assez d'ouvriers") and int(al[0].demande) > int(al[0].ouvriers) - 1,
		"cause : %s" % cause.cause)
	_check((cause.lignes as Array).size() >= 2, "avec les chiffres : %s" % " | ".join(cause.lignes))
	_check(Causes.alertes_chantiers("12345").is_empty(), "rien pour une autre ville")

	print("3 alertes au plus, avec « Régler » :")
	var mp: MairiePanel = scene.mairie_panel
	var garde := mp.autres_alertes
	mp.autres_alertes = func(l: String) -> Array:
		var out: Array = garde.call(l)
		for i in 4:
			out.append({"id": "faux_%d" % i, "gravite": 1, "theme": "ville", "titre": "Alerte %d" % i, "texte": "Texte %d" % i,
				"conseil": "", "panneau": "budget"})
		return out
	_check(mp.alertes().size() == 3 and mp.nombre_alertes() >= 5, "Mairie : 3 alertes montrées sur %d" % mp.nombre_alertes())
	var vues: Array = mp.alertes().map(func(a) -> String: return String(a.id))
	_check(vues.has("chantiers_lents"), "les chantiers passent devant (« prio »)")
	var fil: FilAlertes = scene.fil_alertes
	fil.refresh()
	var cartes := fil._list.get_children().filter(func(n) -> bool: return n.name.begins_with("Alerte_"))
	_check(cartes.size() == 3 and fil.nombre() == 3 and fil.total_alertes >= 5, "fil « À faire » : 3 cartes")
	_check(_trouver(fil._list, "AutresAlertes") != null and fil._head.text.contains("sur"), "« + n moins graves : Mairie (M) »")
	var ch: Control = null
	for n in cartes:
		if String(n.name) == "Alerte_chantiers_lents":
			ch = n
	_check(ch != null, "carte des chantiers dans le fil")
	var regler := _trouver(ch, "Regler") as Button
	_check(regler != null and regler.text == "Régler", "bouton « Régler »")
	var ouverts := []
	fil.panneau_requested.connect(func(id: String) -> void: ouverts.append(id))
	regler.pressed.emit()
	_check(ouverts == ["fondateurs"], "« Régler » ouvre Fondateurs et chantiers")
	var pq := _trouver(ch, "Pourquoi") as Button
	var boite := _trouver(ch, "Cause") as Control
	_check(pq != null and boite != null and not boite.visible, "« ? » et cause repliée")
	pq.button_pressed = true
	_check(boite.visible and (_trouver(boite, "TexteCause") as Label).text.contains("ouvriers"), "un clic : la cause s'affiche")
	fil.refresh()
	var ch2 := _trouver(fil._list, "Alerte_chantiers_lents")
	_check(ch2 != null and (_trouver(ch2, "Cause") as Control).visible, "elle reste dépliée au rafraîchissement")
	MairiePanel.causes_ouvertes.clear()
	mp.set_open(true)
	_check(_trouver(mp, "Alerte_chantiers_lents") != null and (_trouver(_trouver(mp, "Alerte_chantiers_lents"), "Pourquoi") as Button).text == "Pourquoi ?",
		"dans la Mairie aussi : « Pourquoi ? »")
	mp.set_open(false)
	mp.autres_alertes = garde

	print("Causes des avis du Conseiller :")
	for id in ["chomage", "logements", "ecole", "caisse_rouge", "colere", "coupures", "bouchons", "secours", "non_raccordes"]:
		var cz := Causes.de({"id": id, "gravite": 1, "titre": "t", "texte": "texte"}, str(vid))
		_check(String(cz.cause) != "", "%s : %s" % [id, cz.cause])

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
