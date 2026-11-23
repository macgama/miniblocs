extends SceneTree
## Test de la publicité, de la recherche et des soirées du parc de loisirs :
## nouvelles attractions (modèles, dates), verrou de recherche dans Construire,
## bureau d'études (points, file, époques, améliorations), campagnes de
## publicité (notoriété, coût, effet sur les visiteurs), feux d'artifice et
## spectacles du soir (heures, visiteurs en plus, humeur, pluie, coût, visuels),
## sauvegarde, panneau.
## Usage : godot --headless --path . --script res://tests/parc_soirees_test.gd

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
	_catalogue()
	_regles()
	await _partie()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _catalogue() -> void:
	print("Nouvelles attractions :")
	for id in ParcInventions.ORDER:
		var t := BuildingCatalog.get_type(id)
		_check(not t.is_empty() and String(t.cat) == "parc", "%s au catalogue du parc" % id)
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "modèle de %s" % id)
		var aabb := m.get_aabb()
		_check(aabb.size.x <= float(t.w) + 0.05 and aabb.size.z <= float(t.d) + 0.05, "%s tient dans son emprise (%.1f × %.1f)" % [id, aabb.size.x, aabb.size.z])
		_check(Epoques.annee_batiment(id) == int(ParcInventions.TYPES[id].annee), "%s daté de %d" % [id, Epoques.annee_batiment(id)])
		_check(ParcTypes.role_of(id) == "attraction", "%s est une attraction" % id)
		for j in Metiers.jobs_for(id):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
		var anim := ParcTypes.build_anim(id)
		_check(anim != null and anim.get_child_count() > 0, "%s a des pièces mobiles" % id)
		ParcTypes.animate(anim, id, 3.0, 0.5, 1.0)
		ParcTypes.animate(anim, id, 9.0, 0.5, 1.0)
		anim.free()
		_check(ParcRecherche.projet_de(id) != "", "%s s'obtient par la recherche" % id)
	# Le looping fait un vrai tour : le haut du tracé dépasse le centre du looping.
	var pts := ParcInventions.looping_points()
	var haut := 0.0
	for i in range(ParcInventions.LOOP_I0, ParcInventions.LOOP_I1 + 1):
		haut = maxf(haut, pts[i].y)
	_check(haut > ParcInventions.LOOP_C.y + ParcInventions.LOOP_R * 0.9, "looping de %.0f m de haut" % haut)
	for id in ParcRecherche.ORDRE:
		_check(ParcRecherche.PROJETS.has(id), "projet %s décrit" % id)
		for q in ParcRecherche.PROJETS[id].get("requis", []):
			_check(ParcRecherche.ORDRE.find(String(q)) < ParcRecherche.ORDRE.find(id), "%s : %s vient avant" % [id, q])
		for b in ParcRecherche.PROJETS[id].get("ids", []):
			_check(not BuildingCatalog.get_type(String(b)).is_empty(), "%s débloque %s (existe)" % [id, b])
	_check(ParcRecherche.PROJETS.size() == ParcRecherche.ORDRE.size(), "tous les projets sont dans l'ordre")


func _regles() -> void:
	print("Règles :")
	# Publicité : notoriété qui monte puis retombe, cibles, coût.
	var p := {"note": 4.0, "noto": ParcPublicite.vide(), "campagnes": []}
	_check(ParcPublicite.lancer(p, "television", "touristes", 2, 100) == "", "campagne télé lancée")
	_check(ParcPublicite.lancer(p, "affiches", "habitants", 1, 100) == "", "campagne d'affiches lancée")
	var cout := 0.0
	for d in range(101, 108):
		cout += ParcPublicite.jour(p, d, true)
	_check(absf(cout - (45_000.0 + 1_200.0)) < 1.0, "une semaine coûte %d € (télé 45 000 + affiches 1 200)" % roundi(cout))
	_check(float(p.noto.region) > 0.4 and float(p.noto.ville) > 0.2, "notoriété : région %.2f, ville %.2f" % [float(p.noto.region), float(p.noto.ville)])
	var eff := ParcPublicite.effet(p.noto)
	_check(float(eff[0]) > 1.4, "+%d %% de touristes" % roundi((float(eff[0]) - 1.0) * 100.0))
	var r0 := float(p.noto.region)
	for d in range(108, 150):
		ParcPublicite.jour(p, d, true)
	_check((p.campagnes as Array).is_empty(), "les campagnes s'arrêtent à la fin")
	_check(float(p.noto.region) < r0 * 0.6, "la notoriété retombe sans pub (%.2f → %.2f)" % [r0, float(p.noto.region)])
	var mal := {"note": 1.0, "noto": ParcPublicite.vide(), "campagnes": []}
	var bien := {"note": 4.5, "noto": ParcPublicite.vide(), "campagnes": []}
	ParcPublicite.lancer(mal, "radio", "tous", 1, 0)
	ParcPublicite.lancer(bien, "radio", "tous", 1, 0)
	ParcPublicite.jour(mal, 1, true)
	ParcPublicite.jour(bien, 1, true)
	_check(float(mal.noto.region) < float(bien.noto.region) * 0.75, "la pub d'un parc mal noté marche moins bien")
	var sens := {"note": 4.0, "noto": ParcPublicite.vide(), "campagnes": []}
	ParcPublicite.lancer(sens, "radio", "sensations", 1, 0)
	ParcPublicite.jour(sens, 1, false)
	_check(float(sens.noto.region) < float(bien.noto.region) * 0.5, "cibler les sensations sans attraction à sensations, c'est de l'argent perdu")
	var fam := {"note": 4.0, "noto": ParcPublicite.vide(), "campagnes": []}
	ParcPublicite.lancer(fam, "journal", "familles", 2, 0)
	for d in 10:
		ParcPublicite.jour(fam, d + 1, true)
	_check(float(fam.noto.familles) > 0.2, "cible familles : public familial (%.2f)" % float(fam.noto.familles))
	_check(ParcPublicite.public_au_hasard(fam.noto, 0.01) == "familles", "des familles arrivent")

	# Époques : en 1850, pas de radio ni de télévision, pas de looping.
	var r := ReglagesPartie.actuel
	r.deblocage = "tout"
	var avant := r.annee_depart
	r.annee_depart = 1850
	r.histoire_debut = 0.0
	r.histoire_saut = 0
	_check(ParcPublicite.disponible("affiches") and ParcPublicite.disponible("journal"), "1850 : affiches et journal")
	_check(not ParcPublicite.disponible("radio") and not ParcPublicite.disponible("television"), "1850 : ni radio ni télévision")
	_check(ParcPublicite.raison("internet").contains("1996"), "Internet arrive en 1996")
	var rech := ParcRecherche.new()
	r.recherche_parc = true
	_check(not rech.possible("looping_express"), "1850 : pas de looping (%s)" % rech.raison("looping_express"))
	_check(rech.possible("palais_glaces"), "1850 : palais des glaces possible")
	_check(not ParcSoirees.disponible("drones") and ParcSoirees.disponible("feu_artifice"), "1850 : feux d'artifice oui, drones non")
	_check(ParcSoirees.palette().size() == 3, "sans recherche, feux dorés seulement")
	r.annee_depart = avant
	r.recherche_parc = false

	# Recherche : file, points, requis.
	rech = ParcRecherche.new()
	ReglagesPartie.actuel.recherche_parc = true
	rech.set_budget(2)
	_check(not rech.possible("looping_express"), "looping : il faut d'abord les montagnes russes (%s)" % rech.raison("looping_express"))
	_check(rech.ajouter("montagnes_russes") and rech.en_cours == "montagnes_russes", "montagnes russes en cours")
	_check(rech.ajouter("looping_express") and rech.file.has("looping_express"), "looping en file")
	var jours := 0
	var finis: Array = []
	while not rech.faits.has("looping_express") and jours < 500:
		jours += 1
		finis += rech.jour(2000.0, jours)
	_check(finis == ["montagnes_russes", "looping_express"], "trouvés dans l'ordre : %s" % str(finis))
	_check(jours > 30 and jours < 150, "en %d jours au budget normal" % jours)
	rech.set_budget(0)
	_check(is_inf(rech.jours_restants(0.0)) or rech.en_cours == "", "sans budget ni visiteurs, rien n'avance")
	var d2 := ParcRecherche.new()
	d2.from_dict(rech.to_dict())
	_check(d2.faits.has("looping_express") and d2.budget == 0, "recherche relue")
	ReglagesPartie.actuel.recherche_parc = false

	# Soirées : quand, combien, heures.
	var prog := ParcSoirees.programme_vide()
	prog.quand = "samedis"
	_check(ParcSoirees.prevu(prog, {"day": 10, "wd": 6, "month": 7, "dom": 18}), "programmé le samedi")
	_check(not ParcSoirees.prevu(prog, {"day": 11, "wd": 0, "month": 7, "dom": 19}), "pas le dimanche")
	prog.quand = "fetes"
	_check(ParcSoirees.prevu(prog, {"day": 1, "wd": 2, "month": 7, "dom": 14}) and ParcSoirees.prevu(prog, {"day": 1, "wd": 6, "month": 8, "dom": 1}),
		"14 juillet et 1er août")
	_check(ParcSoirees.heure(7) > 22.0 and ParcSoirees.heure(12) < 20.0, "à la nuit tombée : 22 h 30 en juillet, 19 h en décembre")
	_check(ParcSoirees.prix({"type": "feu_artifice", "taille": 2}) > ParcSoirees.prix({"type": "feu_artifice", "taille": 0}), "un grand feu coûte plus cher")


func _place(bs: BuildingSystem, id: String, x: int, z: int, r := 0) -> int:
	var bid := bs.place(id, Vector2i(x, z), r)
	if bid < 0:
		push_error("pose impossible : %s en %d, %d" % [id, x, z])
	return bid


func _partie() -> void:
	print("Dans une partie :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	amb.unix_time = SAMEDI
	if amb.weather != null:
		amb.weather.precip = 0.0
	var parc: ParcLoisirs = scene.parc
	var panel: ParcPanel = scene.parc_panel
	var pop: Population = scene.population
	for n in [transport.traffic, parc, pop, scene.dechets, scene.production]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = false
	bs.money = 80_000_000
	ReglagesPartie.actuel.recherche_parc = true
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0)).ok, "route")
	var c0 := Vector2i(0, -14)
	var entree := bs.place("entree_parc", c0, bs.best_rotation("entree_parc", c0))
	_check(entree > 0, "entrée du parc")
	parc.ignore_staff = true
	parc._sync()

	# Verrou de recherche dans Construire.
	var why := ReglagesPartie.actuel.raison_blocage("grande_roue_parc")
	_check(why.contains("bureau d'études"), "grande roue verrouillée : « %s »" % why)
	_check(bs.place("grande_roue_parc", Vector2i(20, -48), 0) < 0, "la grande roue ne se pose pas avant d'être inventée")
	_check(ReglagesPartie.actuel.raison_blocage("carrousel_parc") == "", "le carrousel se pose d'office")
	var car := _place(bs, "carrousel_parc", -30, -50)
	parc.recherche.faits["grande_roue_parc"] = 1
	parc.recherche.faits["montagnes_russes"] = 1
	parc.recherche.faits["looping_express"] = 1
	parc.recherche.faits["tour_panoramique"] = 1
	_check(ReglagesPartie.actuel.raison_blocage("grande_roue_parc") == "", "inventée, la grande roue se pose")
	var roue := _place(bs, "grande_roue_parc", 20, -48)
	var looping := _place(bs, "looping_express", 0, -120)
	var tour := _place(bs, "tour_panoramique", -60, -90)
	var frites := _place(bs, "friterie_parc", -8, -40)
	var buv := _place(bs, "buvette_parc", -8, -30)
	var wc := _place(bs, "toilettes_parc", 40, -75)
	parc._sync()
	_check(car > 0 and roue > 0 and looping > 0 and tour > 0 and frites > 0 and buv > 0 and wc > 0, "parc monté avec looping et tour panoramique")
	_check(parc.attractions_ok(entree).size() == 4, "4 attractions")
	ReglagesPartie.actuel.recherche_parc = false
	_check(ReglagesPartie.actuel.raison_blocage("riviere_rapide") == "", "sans le réglage, tout se pose d'office")
	ReglagesPartie.actuel.recherche_parc = true

	var p: Dictionary = parc.parcs[entree]
	p.note = 4.0
	parc.clock = SAMEDI - 3600.0
	parc.last_day = int(parc._now(parc.clock).day)
	var now := parc._now(SAMEDI)
	var base := parc.attendus(entree, now)

	# Publicité : une campagne augmente les visiteurs attendus et coûte à la ville.
	var caisse := bs.money
	_check(parc.lancer_campagne(entree, "television", "touristes", 4) == "", "campagne télé lancée depuis le parc")
	_check(parc.lancer_campagne(entree, "nimporte", "tous", 1) != "", "support inconnu refusé")
	for i in 10:
		parc.new_day()
	_check(bs.money < caisse - 50_000, "la pub est payée par la caisse (%d €)" % (caisse - bs.money))
	var apres := parc.attendus(entree, now)
	_check(float(apres[0]) > float(base[0]) * 1.4, "touristes attendus : %d → %d" % [roundi(float(base[0])), roundi(float(apres[0]))])
	parc.arreter_campagne(entree, "television")
	_check((p.campagnes as Array).is_empty(), "campagne arrêtée")

	# Recherche dans la partie : le budget est payé, une amélioration aboutit.
	var signal_recu := [""]
	parc.recherche_terminee.connect(func(id: String) -> void: signal_recu[0] = id)
	parc.recherche_budget(entree, 3)
	parc.recherche_ajouter(entree, "revision_preventive")
	caisse = bs.money
	for i in 40:
		parc.new_day()
		if ParcRecherche.est_fait("revision_preventive"):
			break
	_check(ParcRecherche.est_fait("revision_preventive"), "révisions préventives trouvées")
	_check(signal_recu[0] == "revision_preventive", "signal recherche_terminee envoyé")
	_check(ParcRecherche.a_effet("usure"), "effet « usure » actif")
	_check(bs.money < caisse, "le bureau d'études est payé par la caisse")
	parc.recherche_budget(entree, 0)

	# Soirée : feu d'artifice ce samedi soir.
	parc.set_soiree(entree, "feu_artifice", 2, "samedis")
	_check(parc.soiree_ce_jour(entree, now), "feu d'artifice prévu ce samedi")
	var hr := parc.heures(entree, now)
	_check(hr.y > 22.8, "un soir de feu d'artifice, le parc ferme à %.2f h (au lieu de 22 h)" % hr.y)
	var bonus := ParcSoirees.bonus(p.soiree)
	_check(bonus >= 0.5, "grand feu : +%d %% de visiteurs" % roundi(bonus * 100.0))
	var run := func(hours: float) -> void:
		for i in int(hours * 60.0):
			parc.clock += ParcLoisirs.STEP
			parc.step(ParcLoisirs.STEP)
	caisse = bs.money
	run.call(12.0)
	# 20 h : plein de monde qui attend le spectacle.
	var avant_show := parc.presents(entree)
	_check(avant_show > 50, "%d visiteurs attendent le spectacle" % avant_show)
	run.call(2.6)
	_check(bool(p.ouvert), "encore ouvert à %.1f h, au-delà de l'heure habituelle (22 h)" % float(parc._now(parc.clock).h))
	_check(int(p.jour.spectacles) == 1, "le feu d'artifice a eu lieu")
	_check(int(p.jour.spectateurs) > 30, "%d spectateurs" % int(p.jour.spectateurs))
	_check(int(p.show_jour) == int(now.day), "noté pour ce soir")
	var pens: Dictionary = p.pensees
	_check(pens.has("spectacle"), "les visiteurs en parlent")
	# Visuels : des fusées en vol pendant le spectacle.
	parc.clock = float(parc.clock)
	var vis: ParcSoireesVisuels = parc.soirees_visuels
	_check(vis != null, "visuels des soirées branchés")
	EchelleTemps.force = 1.0
	p.show = {"type": "feu_artifice", "taille": 2, "t0": parc.clock - 60.0, "t1": parc.clock + 600.0, "id": 42}
	for i in 30:
		vis._process(0.1)
	_check(vis.effets() > 0, "fusées et bouquets dans le ciel (%d)" % vis.effets())
	p.show = {"type": "drones", "taille": 1, "t0": parc.clock - 60.0, "t1": parc.clock + 600.0, "id": 43}
	vis._process(0.1)
	vis._process(0.1)
	_check(vis.spectacles_affiches().has(entree), "spectacle de drones affiché")
	var src := parc.pollution_sources()
	_check(src.size() >= 1, "bruit du parc")
	p.show = {}
	EchelleTemps.force = -1.0
	# Plus tard : fermé, tout le monde dehors.
	run.call(1.0)
	_check(not bool(p.ouvert), "fermé après le spectacle")

	# Pluie : annulé, on paie une partie.
	parc.set_soiree(entree, "feu_artifice", 1, "chaque_soir")
	var pluie_ok := amb.weather != null
	if pluie_ok:
		amb.weather.precip = 0.9
		run.call(24.0)
		_check(int(p.get("annule_jour", -1)) == int(parc._now(parc.clock).day) or int(p.hier.spectacles) == 0, "sous la pluie, le feu est annulé")
		amb.weather.precip = 0.0

	# Sauvegarde.
	parc.lancer_campagne(entree, "radio", "familles", 2)
	parc.set_soiree(entree, "parade_lumineuse", 0, "fetes")
	var d := parc.to_dict()
	var faits := parc.recherche.faits.duplicate()
	parc.from_dict(JSON.parse_string(JSON.stringify(d)))
	var q: Dictionary = parc.parcs[entree]
	_check((q.campagnes as Array).size() == 1 and String(q.campagnes[0].cible) == "familles", "campagne relue")
	_check(String(q.soiree.type) == "parade_lumineuse" and String(q.soiree.quand) == "fetes", "programme des soirées relu")
	_check(parc.recherche.faits.size() == faits.size(), "recherche relue (%d projets)" % faits.size())

	# Panneau : les trois nouveaux onglets.
	panel.set_open(true)
	for v in ["publicite", "recherche", "soirees"]:
		panel.show_view(v)
		_check(panel._body.get_child_count() > 5, "panneau, onglet %s" % v)
	panel.set_open(false)
	ReglagesPartie.actuel.recherche_parc = false
	scene.queue_free()
	await process_frame
