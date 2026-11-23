extends SceneTree
## Captures du mode gestion « tycoon » (écran isométrique d'un hôtel ou d'un restaurant).
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/gestion_vitrine.gd -- --out DOSSIER [--type hotel_3|haussmann__restaurant|pompiers|police|hopital|entree_parc|scierie|supermarche] [--depart] [--niveau 1|3|5] [--piece spa] [--zoom 30] [--onglet personnel|stats|journal] [--x 20 --z 14]

var out := "user://captures-gestion"
var niveau := 3
var piece := ""
var zoom := 0.0
var onglet := ""
var cible_x := INF
var cible_z := INF
var type_id := "hotel_3"
var depart := false

const VENDREDI := 1_784_282_400.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		match a[i]:
			"--out": out = a[i + 1]
			"--niveau": niveau = int(a[i + 1])
			"--piece": piece = a[i + 1]
			"--zoom": zoom = float(a[i + 1])
			"--onglet": onglet = a[i + 1]
			"--x": cible_x = float(a[i + 1])
			"--z": cible_z = float(a[i + 1])
			"--type": type_id = a[i + 1]
			"--depart": depart = true
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Langue.activer("fr")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 600.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	Langue.activer("fr")
	var tour: Tourisme = scene.tourisme
	var gest: Gestion = scene.gestion
	var vue: GestionVue = scene.gestion_vue
	var pop: Population = scene.population
	for n in [transport.traffic, tour, pop, scene.production, scene.parc]:
		n.set_process(false)
	bs.unlimited_money = false
	bs.money = 50_000_000
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0))
	var g := GestionTypes.genre_de(type_id)
	var sn := bs.road_snap(type_id, Vector2i(0, -14))
	var hotel := bs.place(type_id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	bs.buildings[hotel]["chantier"] = false
	tour.ignore_staff = true
	tour._sync()
	scene.production._sync()
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	scene.urgences._sync_stations()
	var service := GestionTypes.genre(g).has("service")
	if service:
		pass
	elif g == "parc":
		# De vraies attractions derrière l'entrée, et une journée d'été.
		var pc: ParcLoisirs = scene.parc
		ReglagesPartie.actuel.recherche_parc = false
		pc.ignore_staff = true
		pc._sync()
		for a in [["carrousel_parc", -30, -50], ["grande_roue_parc", 20, -48], ["montagnes_russes", 0, -110],
				["bateau_pirate", -50, -85], ["tasses_parc", 50, -40], ["friterie_parc", -8, -40], ["toilettes_parc", 40, -75]]:
			var b := bs.place(String(a[0]), Vector2i(int(a[1]), int(a[2])), 0)
			if b > 0:
				bs.buildings[b]["chantier"] = false
		pc._sync()
		pc.clock = 1_784_358_000.0 - 3600.0
		pc.last_day = int(pc._now(pc.clock).day)
		for i in 360:
			pc.clock += ParcLoisirs.STEP
			pc.step(ParcLoisirs.STEP)
	elif g == "hotel":
		tour.heb[hotel].nom = "Hôtel Bellevue"
		tour.heb[hotel].compte = 180_000.0
		tour.heb[hotel].clients = [[50, 3, 3.5], [40, 2, 3.5]]
	else:
		scene.production.sites[hotel].cash = 60_000.0
	# Personnel : quelques habitants embauchés à leur poste.
	var homes: Array[int] = []
	for i in 6:
		var c := Vector2i(-300 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for b in homes:
		pop.spawn_household(b, "famille")
	var mets := ["receptionniste", "agent_etage", "agent_etage", "cuisinier", "serveur", "serveur", "cadre", "agent_proprete", "maitre_nageur", "maitre_nageur"]
	if g == "restaurant":
		mets = ["serveur", "serveur", "serveur", "cuisinier", "cuisinier", "serveur", "serveur"]
	elif g == "parc":
		mets = ["agent_accueil_parc", "agent_accueil_parc", "operateur_attraction", "operateur_attraction", "operateur_attraction",
				"technicien_attraction", "vendeur_parc", "vendeur_parc", "agent_proprete", "musicien", "danseur", "animateur_vacances", "cadre", "infirmier", "maitre_nageur"]
	elif service:
		mets = []
		for i in 18:
			mets.append({"caserne": "pompier", "commissariat": "policier"}.get(g, ["medecin", "infirmier", "aide_soignant"][i % 3]))
	var k := 0
	pop.by_job[hotel] = []
	for pid in pop.persons:
		if k >= mets.size():
			break
		pop.persons[pid].met = mets[k]
		pop.by_job[hotel].append(int(pid))
		k += 1
	gest.etat(hotel)
	# Niveau 3 : toutes les pièces au niveau 3 et les objets simples ; 5 : tout au maximum.
	bs.unlimited_money = true
	if niveau > 1:
		var cible := 3 if niveau < 5 else 5
		for pid in GestionTypes.ordre(g):
			while gest.niveau(hotel, String(pid)) < cible:
				if not bool(gest.ameliorer(hotel, String(pid)).ok):
					break
			for oid in GestionTypes.objets(g, String(pid)):
				if niveau >= 5 or int(GestionTypes.objet(g, String(pid), String(oid)).get("niv", 1)) <= 2:
					gest.acheter(hotel, String(pid), String(oid))
	bs.unlimited_money = false
	if niveau == 3:
		gest.nouvelle_panne(hotel)
	# Un mois d'historique pour l'onglet Chiffres.
	var rng := RandomNumberGenerator.new()
	for j in 30:
		var ca := 9000.0 + j * 180.0 + rng.randf_range(-1500, 1500)
		var e := 1.0 if g == "hotel" else 0.25
		if service:
			(gest.etat(hotel).hist as Array).append([j + 1, 1000.0, 300.0 + rng.randf_range(-60, 60) + j * 6.0, rng.randi_range(2, 7), clampf(0.8 + rng.randf_range(-0.2, 0.15), 0, 1), 3.9, 3.7])
			continue
		(gest.etat(hotel).hist as Array).append([j + 1, ca * e, (6500.0 + rng.randf_range(-800, 800)) * e, 80, clampf(0.55 + j * 0.012 + rng.randf_range(-0.05, 0.05), 0, 1), 3.6, 3.8])
	if service:
		var stc := gest.etat(hotel)
		stc.hier = {"ca": 1000.0, "charges": 320.0, "clients": 5.0, "retards": 0, "delai": 205.0, "departs": 6}
		stc.delai = 205.0
		stc.interventions = 148
		stc.departs = 171
		stc.note = 4.1
		stc.satisf = 3.8
		stc.caisse = 42_000.0
		stc.volontaires = 2
		stc.elucides = 23
		stc.non_elucides = 9
		stc.fourriere = 64
		stc.patients = 212
		stc.sauves = 7
		stc.parking = 18_400.0
		scene.urgences.maj_flotte(hotel)
	if g == "restaurant":
		gest.etat(hotel).hier = {"ca": 2900.0, "charges": 2100.0, "clients": 150.0, "cap": 190.0}
		gest.etat(hotel).note = 3.8
		gest.etat(hotel).satisf = 3.9
	# Essor : recherche, campagne, défi et avis pour les onglets Essor et Avis.
	if onglet in ["essor", "avis"]:
		var se := gest.etat(hotel)
		var es := GestionEssor.es(se)
		es.faits = ["methodes", "qualite"]
		es.rech = "maintenance"
		es.pts = 11.0
		GestionEssor.lancer_campagne(gest, hotel, "portes" if service else "radio")
		es.defi = {"id": "demandes", "etat": "actif", "cible": 5.0, "jours": 7, "offert": gest.jour, "debut": gest.jour, "fin": gest.jour + 5, "base": float(se.reglees) - 3.0, "prime": 4000}
		es.defis_ok = 2
		for i in 40:
			GestionEssor._nouvel_avis(gest, hotel, se)
	if onglet in ["essor", "avis", "personnel"]:
		var es2 := GestionEssor.es(gest.etat(hotel))
		es2.trophees = ["defi_1", "defi_3", "chercheur", "pub", "premier"]
		es2.ext = 1
		var eq := GestionPlus.equipe(gest, hotel)
		for i in eq.size():
			eq[i].moral = 2.0 + float(i % 4) * 0.8
			eq[i].fatigue = 15.0 + float(i * 7 % 50)
		eq[0].aug = 0.1
		es2.demande = {"i": 1, "jour": gest.jour}
	gest.set_auto(hotel, niveau != 3)
	scene.ouvrir_gestion(hotel)
	if zoom > 0.0:
		vue._zoom = zoom
	if cible_x != INF:
		vue._cible = Vector3(cible_x, 0, cible_z)
	vue._placer_camera()
	EchelleTemps.force = 1.0
	for i in 260:
		vue.simuler(0.1)
	if depart:
		# Un appel : un engin sort de la remise, l'alerte sonne.
		scene.urgences.ignore_crew = true
		scene.urgences.random_call({"caserne": "feu_poubelle", "commissariat": "accident"}.get(g, "malaise"))
		vue._maj_engins(true)
		for i in 6:
			vue.simuler(0.1)
	vue.choisir(piece)
	if onglet != "":
		vue.onglet = onglet
		vue._remplir_carte()
	for i in 30:
		await process_frame
	vue._t_demande = 0.0
	for i in (6 if depart else 40):
		vue.simuler(0.1)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var f := out.path_join("gestion-%s-niveau%d%s%s%s.png" % [g, niveau, ("-" + piece) if piece != "" else "", ("-" + onglet) if onglet != "" else "", "-depart" if depart else ""])
	img.save_png(f)
	print("capture : ", ProjectSettings.globalize_path(f))
	quit(0)
