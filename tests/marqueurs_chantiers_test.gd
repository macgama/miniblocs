extends SceneTree
## Marqueurs des chantiers : plus de texte flottant, une icône + anneau d'avancement,
## pastille d'état, info-bulle au survol, clic → fiche, option et distance.
## Usage : godot --headless --path . --script res://tests/marqueurs_chantiers_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _fake_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	Creations.persist = false
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.deblocage = "tout"
	print("Atlas :")
	var at := MarqueursChantiers.atlas()
	_check(at != null and at.get_width() == MarqueursChantiers.CASE * 4, "atlas 4 × 2 des icônes")
	for q in ["chantier", "niv", "renov", "repos", "argent", "sans_ouvriers", "equipe", "pause"]:
		var ic := MarqueursChantiers.icone(q, 18)
		_check(ic != null and ic.get_image().get_pixel(9, 9).a > 0.5, "icône « %s »" % q)

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 90:
		await process_frame
	var vie: BatimentsVie = scene.get_node("VieBatiments")
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	BatimentsVie.chantiers = true
	bs.require_access = false
	bs.unlimited_money = true
	var mq: MarqueursChantiers = vie.marqueurs
	_check(mq != null and mq.is_inside_tree(), "nœud des marqueurs sous la vie des bâtiments")
	print("Chantier :")
	var bid := bs.place("colombages__maison", Vector2i(-60, 60), 0)
	_check(bid > 0 and bs.en_chantier(bid), "maison posée : chantier ouvert")
	vie._update_chantiers()
	var node := bs.node_of(bid)
	_check(node.find_children("*", "Label3D", true, false).is_empty(), "aucun texte flottant")
	mq.maj()
	var m: Dictionary = {}
	for x in mq.marqueurs:
		if int(x.bid) == bid:
			m = x
	_check(not m.is_empty() and String(m.genre) == "chantier", "un marqueur pour le chantier")
	_check(mq._mm.multimesh.instance_count >= 1, "MultiMesh rempli (%d)" % mq._mm.multimesh.instance_count)
	bs.buildings[bid]["attente"] = true
	mq.maj()
	_check(vie.statut_de(bid) == "argent", "caisse vide : statut « argent »")
	var n_avec := mq._mm.multimesh.instance_count
	bs.buildings[bid].erase("attente")
	vie.au_travail = true
	bs.buildings[bid].erase("sans_ouvriers")
	mq.maj()
	var st_ok := vie.statut_de(bid)
	_check(n_avec > mq._mm.multimesh.instance_count or st_ok != "", "pastille d'état en plus quand ça bloque (%d → %d, statut « %s »)" % [n_avec, mq._mm.multimesh.instance_count, st_ok])
	var d := vie.detail_chantier(bid)
	_check(String(d.nom) != "" and String(d.etape) != "" and d.has("fin"), "détail : %s · %s" % [d.nom, d.etape])
	print("Survol et clic :")
	var cam := scene.get_viewport().get_camera_3d()
	var p: Vector3 = m.pos
	var rig: Node3D = scene.rig
	rig.position.x = p.x
	rig.position.z = p.z
	for i in 5:
		await process_frame
	mq.maj()
	cam = scene.get_viewport().get_camera_3d()
	var dist := cam.global_position.distance_to(p)
	if dist < BatimentsVie.VUE_PANNEAU and not cam.is_position_behind(p):
		var s := MarqueursChantiers.taille_a(dist)
		var ecran := cam.unproject_position(p + Vector3(0, s * 0.6, 0))
		_check(mq.marqueur_sous(ecran) == bid, "marqueur trouvé sous la souris (à %d m)" % roundi(dist))
		_check(mq.marqueur_sous(ecran + Vector2(300, 300)) != bid, "rien à côté")
		mq._survol(ecran)
		_check(mq._bulle.visible and mq._bulle_titre.text.contains("Terrassement") and mq._bulle_aide.text.contains("Clic"), "carte au survol : %s" % mq._bulle_titre.text)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = ecran
		mq._input(press)
		var rel := press.duplicate() as InputEventMouseButton
		rel.pressed = false
		mq._input(rel)
		_check(mq.epingle == bid, "clic : la carte reste ouverte")
		mq._survol(ecran + Vector2(400, 300))
		_check(mq._bulle.visible, "souris partie : la carte épinglée reste")
		var autre := press.duplicate() as InputEventMouseButton
		autre.position = ecran + Vector2(400, 300)
		mq._input(autre)
		var rel2 := autre.duplicate() as InputEventMouseButton
		rel2.pressed = false
		mq._input(rel2)
		_check(mq.epingle == -1, "clic ailleurs : carte fermée")
		mq._input(press)
		mq._input(rel)
		var esc := InputEventKey.new()
		esc.pressed = true
		esc.physical_keycode = KEY_ESCAPE
		mq._input(esc)
		_check(mq.epingle == -1, "Échap : carte fermée")
	else:
		_check(false, "caméra trop loin du chantier pour tester le survol (%d m)" % roundi(dist))
	print("Option et distance :")
	OptionsJeu.marqueurs_chantiers = false
	mq._process(0.3)
	_check(not mq._mm.visible and not mq._bulle.visible, "option décochée : marqueurs masqués")
	OptionsJeu.marqueurs_chantiers = true
	mq._process(0.3)
	_check(mq._mm.visible, "option cochée : marqueurs revenus")
	_check((mq._mm.material_override as ShaderMaterial).get_shader_parameter("distance_max") == BatimentsVie.VUE_PANNEAU, "masqués au-delà de %d m" % roundi(BatimentsVie.VUE_PANNEAU))
	vie.finish_all()
	mq.maj()
	var reste := mq.marqueurs.filter(func(x: Dictionary) -> bool: return int(x.bid) == bid)
	_check(reste.is_empty(), "chantier fini : plus de marqueur")
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
