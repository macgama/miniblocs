extends SceneTree
## Test des métiers visibles : gestes, personnel des bâtiments et conséquences,
## vue en coupe, employés dehors, enseignes, pancartes, clic sur un employé.
## Usage : godot --headless --path . --script res://tests/metiers_test.gd

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


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false

	print("Gestes :")
	_check(Gestes.metiers_sans_geste().is_empty(), "chaque métier existant a des gestes valides")
	var n_gestes := 0
	for met in Metiers.METIERS:
		n_gestes += Gestes.du_metier(String(met)).size()
	_check(n_gestes >= Metiers.METIERS.size() * 2 - 10, "%d gestes pour %d métiers" % [n_gestes, Metiers.METIERS.size()])
	_check(Gestes.du_metier("boulanger").has("petrir"), "le boulanger pétrit")
	_check(Gestes.du_metier("enseignant").has("tableau"), "l'enseignant écrit au tableau")
	_check(Gestes.du_metier("medecin").has("ausculter"), "le médecin ausculte")
	_check(Gestes.du_metier("patissier_inconnu").has("faconner"), "métier ajouté plus tard (pâtissier) : geste deviné d'après son nom")
	_check(Gestes.du_metier("zzz_nouveau", "superette") == Gestes.PAR_CATEGORIE.commerce, "métier inconnu : gestes de la catégorie du bâtiment")
	var g1 := Gestes.courant(7, "boulanger", 0.0)
	var g2 := Gestes.courant(7, "boulanger", Gestes.DUREE * 1.0)
	_check(g1 != g2, "le geste change au bout de 10 minutes de jeu (%s puis %s)" % [g1, g2])
	var manquants := []
	for g in Gestes.GESTES:
		var p := String(Gestes.GESTES[g].p)
		var o := String(Gestes.GESTES[g].o)
		if p != "" and Accessoires.poste(p) == null:
			manquants.append(p)
		if o != "" and Accessoires.outil(o) == null:
			manquants.append(o)
	_check(manquants.is_empty(), "chaque geste a son poste et son outil modélisés %s" % str(manquants))
	var fig := Figurine.creer(3, "boulanger")
	root.add_child(fig)
	var anims_ok := true
	for g in Gestes.GESTES:
		fig.regler(String(g))
		for t in [0.0, 0.7, 2.3]:
			fig.animer(t)
		anims_ok = anims_ok and fig.anim == String(Gestes.GESTES[g].a)
	_check(anims_ok, "les %d gestes s'animent" % Gestes.GESTES.size())
	fig.regler("petrir")
	fig.animer(0.0)
	var b0: Vector3 = fig._bras[1].rotation
	fig.animer(0.5)
	_check(fig._bras[1].rotation.distance_to(b0) > 0.05, "les bras bougent en pétrissant")
	fig.queue_free()

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	var pop: Population = scene.population
	var mv: MetiersVivants = scene.metiers_vivants
	_check(mv != null and pop.effectif != null, "vue métiers et personnel branchés dans la scène")
	pop.passants.enabled = false
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0) # mardi
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("departementale", Vector3(0, y, -300), Vector3(0, y, 300)).ok, "route")
	var school := bs.place("ecole", Vector2i(-30, 0), 1)
	var bakery := bs.place("boulangerie", Vector2i(-16, -95), 1)
	var shop := bs.place("superette", Vector2i(-14, -60), 1)
	var hospital := bs.place("hopital", Vector2i(30, 40), 3)
	var farm := bs.place("ferme", Vector2i(-24, 140), 1)
	var homes := []
	for i in 8:
		homes.append(bs.place("immeuble", Vector2i(16, -180 + i * 22), 3))
	for i in 4:
		homes.append(bs.place("maison", Vector2i(-12, -170 + i * 16), 1))
	_check(school > 0 and bakery > 0 and shop > 0 and hospital > 0 and farm > 0 and not homes.has(-1), "école, boulangerie, supérette, hôpital, ferme, logements")
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	pop._now = {}
	var eff := pop.effectif
	eff.actualiser(true)

	print("Personnel :")
	for bid in [school, bakery, shop, hospital]:
		_check(not eff.ferme(bid), "%s ouvert : %s" % [pop.building_name(bid), eff.resume(bid)])
	_check(eff.ouvert_maintenant(school), "mardi 10 h : l'école est ouverte, les enseignants sont là")
	_check(eff.presents(bakery).size() > 0, "mardi 10 h : %d employés à la boulangerie" % eff.presents(bakery).size())
	_check(CycleVie.new(pop).hospital_distance(homes[0]) < INF, "hôpital avec personnel : il soigne")

	print("Vue métiers (coupe) :")
	var rig: Node3D = scene.get_node("CameraRig")
	pop.follow_camera = false
	var bpos: Vector3 = pop.known[bakery].pos
	rig.global_position = Vector3(bpos.x, rig.global_position.y, bpos.z)
	rig.set("_distance", 20.0)
	rig.set("_target_distance", 20.0)
	mv.refresh()
	_check(mv.coupes.has(bakery), "zoom près de la boulangerie : elle s'ouvre en coupe")
	_check(not bs.node_of(bakery).visible, "toit et façade effacés")
	var gestes_vus := {}
	var dans_boulangerie := 0
	for s in mv.shown:
		if int(s.bid) == bakery:
			dans_boulangerie += 1
			gestes_vus[String(s.geste)] = true
	_check(dans_boulangerie > 0, "%d personnes visibles dans la boulangerie (employés et clients)" % dans_boulangerie)
	var boulanger_au_travail := false
	for g in gestes_vus:
		if Gestes.du_metier("boulanger").has(g) or Gestes.du_metier("vendeur").has(g):
			boulanger_au_travail = true
	_check(boulanger_au_travail, "gestes vus : %s" % ", ".join(gestes_vus.keys()))
	for i in 5:
		await process_frame
	var cam: Camera3D = rig.get_node("Camera3D")
	mv.refresh()
	var cible := -1
	var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for s in mv.shown:
		if int(s.bid) == bakery and mv._figs.has(int(s.pid)):
			var pos: Vector3 = (mv._figs[int(s.pid)] as Node3D).global_position + Vector3(0, 1.0, 0)
			if not cam.is_position_behind(pos) and vp.has_point(cam.unproject_position(pos)):
				cible = int(s.pid)
				break
	_check(cible >= 0, "un employé de la boulangerie est à l'écran")
	if cible >= 0:
		var f: Figurine = mv._figs[cible]
		var ecran := cam.unproject_position(f.global_position + Vector3(0, 1.0, 0))
		var vise := mv.pick(ecran, cam)
		var dans := false
		for s2 in mv.shown:
			dans = dans or (int(s2.pid) == vise and int(s2.bid) == bakery)
		_check(dans, "clic sur un employé de la boulangerie : sa fiche s'ouvre (n° %d)" % vise)
		_check(Gestes.de_personne(pop, cible) != "", "sa fiche dit ce qu'il fait : %s" % Gestes.de_personne(pop, cible))
	rig.set("_distance", 70.0)
	rig.set("_target_distance", 70.0)
	mv.refresh()
	_check(not mv.coupes.has(bakery) and bs.node_of(bakery).visible, "en dézoomant, le bâtiment se referme")

	print("Dehors :")
	var fpos: Vector3 = pop.known[farm].pos
	rig.global_position = Vector3(fpos.x, rig.global_position.y, fpos.z)
	mv.refresh()
	var au_champ := 0
	for s in mv.shown:
		if int(s.bid) == farm and String(s.ou) == "dehors":
			au_champ += 1
	var a_la_ferme := eff.presents(farm).size()
	_check(a_la_ferme == 0 or au_champ > 0, "ferme : %d au travail, %d visibles dehors sans vue en coupe" % [a_la_ferme, au_champ])

	print("Enseignes :")
	var spos: Vector3 = pop.known[shop].pos
	rig.global_position = Vector3(spos.x, rig.global_position.y, spos.z)
	mv.refresh()
	var st: Dictionary = mv._bats.get(shop, {})
	_check(st.get("enseigne") != null and (st.enseigne as Label3D).text == "OUVERT", "10 h : enseigne « OUVERT » sur la supérette")
	amb.unix_time = _at("2026-03-11", 3.0)
	pop._now = {}
	mv.refresh()
	st = mv._bats.get(shop, {})
	_check((st.enseigne as Label3D).text == "FERMÉ", "3 h du matin : « FERMÉ »")
	_check(st.get("rideau") != null and (st.rideau as Node3D).visible, "3 h du matin : rideau de fer baissé")
	amb.unix_time = _at("2026-03-10", 10.0)
	pop._now = {}

	print("Conséquences du manque de personnel :")
	var pupils: Array = pop.by_school.get(school, []).duplicate()
	for pid in (pop.by_job.get(school, []) as Array).duplicate():
		if String(pop.persons[pid].met) == "enseignant":
			pop._leave_job(pop.persons[pid])
	pop._apres_embauches()
	pop._now = {}
	_check(eff.ferme(school), "plus d'enseignant : école fermée (%s)" % String(eff.etat(school).raison))
	var a_la_maison := 0
	for pid in pupils:
		var a := pop.activity(pop.persons[pid])
		if String(a.kind) == "maison" and String(a.text).contains("école fermée"):
			a_la_maison += 1
	_check(pupils.size() > 0 and a_la_maison == pupils.size(), "les %d élèves restent à la maison" % a_la_maison)
	_check(not pupils.is_empty() and str(pop.satisfaction(pop.persons[pupils[0]]).why).contains("école fermée"), "leur satisfaction baisse")
	_check(eff.consequences(school).size() > 0, "fiche de l'école : %s" % str(eff.consequences(school)))
	rig.global_position = Vector3(pop.known[school].pos.x, rig.global_position.y, pop.known[school].pos.z)
	mv.refresh()
	st = mv._bats.get(school, {})
	_check(st.get("pancarte") != null and (st.pancarte as Label3D).visible and (st.pancarte as Label3D).text.contains("Fermé"), "pancarte au-dessus de l'école : %s" % ((st.pancarte as Label3D).text if st.get("pancarte") != null else "—"))

	for pid in (pop.by_job.get(hospital, []) as Array).duplicate():
		pop._leave_job(pop.persons[pid])
	pop._apres_embauches()
	_check(eff.ferme(hospital), "hôpital sans personnel : fermé")
	_check(pop.vie.hospital_distance(homes[0]) == INF, "personne n'y est soigné (santé : pas d'hôpital proche)")

	for pid in (pop.by_job.get(shop, []) as Array).duplicate():
		pop._leave_job(pop.persons[pid])
	pop._apres_embauches()
	var client := int(pop.households[pop.by_home[homes[0]][0]].m[0])
	var nearest := pop._nearest_cat(pop.persons[client], "commerce")
	_check(nearest != shop, "supérette fermée : les clients vont ailleurs (%s)" % pop.building_name(nearest))

	# Les embauches reprennent : tout rouvre.
	pop._match_all()
	pop._now = {}
	_check(not eff.ferme(school) and not eff.ferme(hospital) and not eff.ferme(shop), "de nouveaux employés sont embauchés : tout rouvre")

	print("Toutes les vues :")
	mv.set_enabled(false)
	_check(mv._figs.is_empty() and mv._bats.is_empty(), "K : vue métiers coupée, plus rien d'affiché")
	mv.set_enabled(true)

	print("MÉTIERS TEST OK" if ok else "MÉTIERS TEST ÉCHEC")
	quit(0 if ok else 1)
