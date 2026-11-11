extends SceneTree
## Test de la vue au sol : bascule dessus / 3e / 1re personne, marche sur le relief,
## sur une route et un pont, mur qui arrête, caméra qui ne traverse pas le décor,
## nage, retour à la vue de dessus, état pour le multijoueur.
## Fonctionne sans réseau (relief synthétique, le même que tests/transport_test.gd).
## Usage : godot --headless --path . --script res://tests/personnage_test.gd
## Capture (nécessite un affichage) : ... -- --screenshot dossier/

var ok := true
var world: TerrainWorld
var _tunnel_debut := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


static func terrain_at(x: float, z: float) -> float:
	if x < -300.0:
		return -10.0
	var h := 20.0
	h += 45.0 * exp(-((x - 200.0) * (x - 200.0) + z * z) / 3600.0)
	h -= 16.0 * exp(-((x + 100.0) * (x + 100.0)) / 400.0)
	return h


func _fake_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := float(t.x * 256 + x)
			var gy := float(t.y * 256 + y)
			var lx := (gx - world._px0) / world._px_per_m
			var lz := (gy - Geo.lat_to_pixel_y(world.origin_lat, 15)) / world._px_per_m
			a[y * 256 + x] = terrain_at(lx, lz)
	return a


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Fait marcher le personnage : avance (x droite, y avant) pendant `s` secondes.
func _marcher(p: Personnage, avance: Vector2, cap: float, s: float, course := false) -> void:
	p.commande.avance = avance
	p.commande.cap = cap
	p.commande.course = course
	await _frames(roundi(s * Engine.physics_ticks_per_second))
	p.commande.avance = Vector2.ZERO
	await _frames(10)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	var tr: TransportSystem = scene.get_node("Transport")
	var vue: VueSol = scene.get_node("VueSol")
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	world.set_origin(48.8584, 2.2945)
	for i in 30:
		await process_frame
	var p := vue.personnage
	# Pas de circulation pendant les tests de marche (on la teste à part, plus bas).
	tr.traffic.set_enabled(false)

	print("Bascule de vue :")
	_check(vue.vue == VueSol.Vue.DESSUS and not p.visible, "on commence en vue de dessus, sans personnage")
	rig.position = Vector3(0.5, 20.0, 0.5)
	rig.rotation.y = 0.0
	vue.set_vue(VueSol.Vue.TROISIEME)
	_check(p.visible and vue.camera.current, "touche V : 3e personne, caméra au sol active")
	_check(not rig.is_processing(), "la caméra de gestion est en pause")
	_check(world._focus == p, "le relief se charge autour du personnage")

	print("Marche sur le relief :")
	await _frames(60)
	_check(not p.en_attente, "le personnage est posé une fois le relief chargé")
	_check(p.is_on_floor() and absf(p.global_position.y - 20.0) < 0.6, "debout sur la plaine à 20 m (%.2f m)" % p.global_position.y)
	# Avance vers l'est (cap -90° = vers +X) avec la touche Z/W simulée.
	vue.tourner(Vector2(PI / 2.0, 0.0)) # souris vers la droite : on tourne à droite
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_W
	ev.keycode = KEY_W
	ev.pressed = true
	Input.parse_input_event(ev)
	var x0 := p.global_position.x
	await _frames(120)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(10)
	_check(p.global_position.x - x0 > 5.0, "Z / W fait avancer dans la direction regardée (%.1f m)" % (p.global_position.x - x0))
	# Le contrôleur clavier est coupé : on pilote directement, comme le ferait le réseau.
	vue.set_physics_process(false)
	p.teleporter(Vector3(120.5, world.cell_height(Vector2i(120, 0)) + 0.3, 0.5), -PI / 2.0)
	vue.collisions.mettre_a_jour(p.global_position, 99)
	await _frames(30)
	var y_avant := p.global_position.y
	await _marcher(p, Vector2(0, 1), -PI / 2.0, 6.0, true)
	var c := Vector2i(floori(p.global_position.x), floori(p.global_position.z))
	_check(p.global_position.x > 160.0 and p.global_position.y > y_avant + 8.0, "monte la colline en suivant le relief (%.1f → %.1f m)" % [y_avant, p.global_position.y])
	_check(absf(p.global_position.y - world.cell_height(c)) < 0.6, "les pieds restent sur les cases (écart %.2f m)" % absf(p.global_position.y - world.cell_height(c)))

	print("Routes et ponts :")
	var r := tr.build_segment("route", Vector3(-170, 0, 30), Vector3(-30, 0, 30))
	_check(r.ok and float(r.bridge_len) > 10.0, "route avec un pont au-dessus de la vallée")
	await _frames(5)
	var mid_s := 0.0
	var eid: int = r.edges[0]
	var e: Dictionary = tr.network.edges[eid]
	# Point au milieu du pont.
	for s in range(0, int(e.len), 2):
		if tr.network.struct_at(eid, s) == TransportTypes.Struct.BRIDGE:
			var q := tr.network.point_at(eid, s)
			if absf(q.x + 100.0) < 6.0:
				mid_s = s
	var deck := tr.network.point_at(eid, mid_s)
	var sol := world.cell_height(Vector2i(floori(deck.x), floori(deck.z)))
	p.teleporter(deck + Vector3(-6, 0.5, 0), -PI / 2.0)
	await _frames(30)
	await _marcher(p, Vector2(0, 1), -PI / 2.0, 1.5)
	_check(p.is_on_floor() and absf(p.global_position.y - deck.y) < 0.5 and deck.y - sol > 3.0,
		"marche sur le pont à %.1f m (sol de la vallée à %.1f m)" % [p.global_position.y, sol])
	# Vers le côté : le parapet retient.
	await _marcher(p, Vector2(1, 0), -PI / 2.0, 2.0)
	var demi := float(e.width) * 0.5
	_check(absf(p.global_position.z - deck.z) < demi and p.global_position.y > deck.y - 0.5,
		"le parapet empêche de tomber du pont (%.1f m de l'axe, bord à %.1f m)" % [absf(p.global_position.z - deck.z), demi])

	# Longue marche sans aide sur la route (130 m, pont compris) : les collisions suivent toutes seules.
	var r0 := tr.network.point_at(eid, 3.0)
	p.teleporter(r0 + Vector3(0, 0.4, 0), -PI / 2.0)
	vue.collisions.mettre_a_jour(p.global_position, 99)
	await _frames(10)
	await _marcher(p, Vector2(0, 1), -PI / 2.0, 14.0, true)
	var proche := tr.network.nearest_on_edge(eid, p.global_position)
	var route_y := tr.network.point_at(eid, float(proche.s)).y
	_check(p.global_position.x - r0.x > 100.0 and absf(p.global_position.y - route_y) < 0.6,
		"longue course sur la route (%.0f m) : le sol suit toujours sous les pieds" % (p.global_position.x - r0.x))

	print("Collisions avec un bâtiment :")
	var mur := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2, 6, 12)
	cs.shape = bx
	mur.add_child(cs)
	scene.add_child(mur)
	mur.global_position = Vector3(10.5, 23.0, -20.0)
	p.teleporter(Vector3(4.5, 20.5, -20.0), -PI / 2.0)
	await _frames(20)
	await _marcher(p, Vector2(0, 1), -PI / 2.0, 3.0)
	_check(p.global_position.x < 9.5 - Personnage.RAYON + 0.05, "un mur (bâtiment) arrête le personnage (x = %.2f)" % p.global_position.x)

	print("Caméra 3e personne :")
	vue._distance = 6.0
	vue._cap = PI / 2.0 # regarde vers -X : la caméra recule vers +X, dans le mur
	vue._tangage = 0.0
	await _frames(20)
	await process_frame
	var d_cam := vue.camera.global_position.distance_to(vue._pivot.global_position)
	_check(d_cam < 5.0 and vue.camera.global_position.x < 9.5, "la caméra ne traverse pas le mur (recul %.1f m au lieu de 6)" % d_cam)
	vue._cap = -PI / 2.0
	await _frames(20)
	await process_frame
	d_cam = vue.camera.global_position.distance_to(vue._pivot.global_position)
	_check(d_cam > 5.0, "sans obstacle, la caméra recule de toute sa distance (%.1f m)" % d_cam)
	vue._tangage = deg_to_rad(-60.0)
	vue._cap = 0.0
	vue._tangage = deg_to_rad(70.0) # caméra sous le personnage : bloquée par le sol
	await _frames(20)
	await process_frame
	var cc := vue.camera.global_position
	var hc := world.cell_height(Vector2i(floori(cc.x), floori(cc.z)))
	_check(cc.y > hc - 0.3, "la caméra ne passe pas sous le relief (%.2f m, sol %.2f m)" % [cc.y, hc])
	vue._tangage = -0.25

	# Un vrai bâtiment du catalogue (maison de 10 × 12 m), posé sans règles d'accès ni de coût.
	var bs: BuildingSystem = scene.get_node("Batiments")
	bs.require_access = false
	bs.unlimited_money = true
	var bid := bs.place("maison", Vector2i(40, -60), 0)
	_check(bid > 0, "poser une maison")
	await _frames(5)
	p.teleporter(Vector3(25.5, world.cell_height(Vector2i(25, -60)) + 0.3, -59.5), -PI / 2.0)
	vue.collisions.mettre_a_jour(p.global_position, 99)
	await _frames(20)
	await _marcher(p, Vector2(0, 1), -PI / 2.0, 4.0)
	_check(p.global_position.x < 36.0, "la maison arrête le personnage (x = %.2f)" % p.global_position.x)

	print("Arbres :")
	# Cherche un arbre affiché près du point (60, 60) et fonce dessus.
	var arbre := Vector3.INF
	var cible := Vector2(60, 60)
	for k in world.chunks:
		var bloc_aff := world.chunks[k] as Node3D
		for t: Transform3D in bloc_aff.get_meta("arbres", []):
			var q := bloc_aff.position + t.origin
			if Vector2(q.x, q.z).distance_to(cible) < Vector2(arbre.x, arbre.z).distance_to(cible):
				arbre = q
	_check(arbre != Vector3.INF, "des arbres sont plantés")
	var sol_arbre := world.cell_height(Vector2i(floori(arbre.x), floori(arbre.z)))
	p.teleporter(Vector3(arbre.x - 4.0, world.cell_height(Vector2i(floori(arbre.x - 4.0), floori(arbre.z))) + 0.3, arbre.z), -PI / 2.0)
	vue.collisions.mettre_a_jour(p.global_position, 99)
	await _frames(20)
	await _marcher(p, Vector2(0, 1), -PI / 2.0, 2.0)
	_check(p.global_position.x < arbre.x - 0.3 and absf(p.global_position.y - sol_arbre) < 2.0,
		"le tronc d'un arbre arrête le personnage (%.2f m avant l'arbre)" % (arbre.x - p.global_position.x))

	print("Tunnel :")
	var rt := tr.build_segment("rail", Vector3(60, 0, 0), Vector3(340, 0, 0))
	_check(rt.ok and float(rt.tunnel_len) > 20.0, "voie ferrée en tunnel sous la colline (%d m)" % roundi(rt.get("tunnel_len", 0.0)))
	await _frames(5)
	var debut := Vector3.INF
	var fin := Vector3.INF
	var voute := 0.0
	for id in rt.edges:
		var et: Dictionary = tr.network.edges[id]
		for i in (et.pts as PackedVector3Array).size():
			if et.st[i] == TransportTypes.Struct.TUNNEL:
				if debut == Vector3.INF:
					debut = et.pts[i]
				fin = et.pts[i]
	_tunnel_debut = debut
	_check(vue.collisions.trous.size() > 50, "le relief est percé au-dessus du tunnel (%d cases)" % vue.collisions.trous.size())
	# Entrée côté ouest, quelques mètres avant le portail, puis on marche vers l'est.
	var entree := debut + Vector3(-6.0, 0.4, 0.0)
	p.teleporter(entree, -PI / 2.0)
	vue.collisions.mettre_a_jour(p.global_position, 99)
	await _frames(20)
	var x_dep := p.global_position.x
	await _marcher(p, Vector2(0, 1), -PI / 2.0, 8.0, true)
	var milieu_x := (debut.x + fin.x) * 0.5
	_check(p.global_position.x > debut.x + 30.0 and p.global_position.x < fin.x, "on entre à pied dans le tunnel et on y avance (%.0f m → %.0f m, tunnel de %.0f à %.0f m)" % [x_dep, p.global_position.x, debut.x, fin.x])
	var dessus := world.cell_height(Vector2i(floori(p.global_position.x), floori(p.global_position.z)))
	var voie_y := 0.0
	var meilleur := INF
	for id in rt.edges:
		for q in (tr.network.edges[id].pts as PackedVector3Array):
			var dq := Vector2(q.x - p.global_position.x, q.z - p.global_position.z).length()
			if dq < meilleur:
				meilleur = dq
				voie_y = q.y
	_check(dessus - p.global_position.y > 4.0 and absf(p.global_position.y - voie_y) < 0.6,
		"sous terre, debout sur la voie (%.1f m sous la surface, %s, voie %.1f, tunnel %s → %s)" % [dessus - p.global_position.y, p.global_position, voie_y, debut, fin])
	# Le contrôleur ne doit pas « sauver » le personnage en le remontant sur la colline.
	var avant_ctrl := p.global_position
	vue._physics_process(1.0 / 60.0)
	_check(p.global_position.distance_to(avant_ctrl) < 0.5, "dans le tunnel, le personnage n'est pas renvoyé à la surface")
	# Au-dessus du tunnel, sur la colline : on ne tombe pas dedans.
	var haut := Vector3(milieu_x + 0.5, 0.0, 0.5)
	haut.y = world.cell_height(Vector2i(floori(haut.x), 0)) + 0.3
	p.teleporter(haut, 0.0)
	vue.collisions.mettre_a_jour(p.global_position, 99)
	await _frames(20)
	await _marcher(p, Vector2(1, 0), 0.0, 1.0)
	_check(p.global_position.y > haut.y - 1.5, "sur la colline au-dessus du tunnel, on ne tombe pas dedans (%.1f m)" % p.global_position.y)

	print("Véhicules :")
	tr.traffic.set_enabled(true)
	for i in 3:
		tr.traffic.spawn(TransportTypes.Mode.ROAD)
	for i in 200:
		tr.traffic.step(0.25)
	var auto: MeshInstance3D = null
	for v in tr.traffic.vehicles:
		if int(v.mode) == TransportTypes.Mode.ROAD:
			auto = v.body
			break
	_check(auto != null, "des voitures roulent")
	if auto:
		p.teleporter(auto.global_position + Vector3(0, 3, 0), 0.0)
		vue.collisions.suivre_vehicules(p.global_position)
		_check(vue.collisions.nb_vehicules_actifs() >= 1, "les véhicules proches ont une collision")
		p.global_position = auto.global_position
		vue.collisions.suivre_vehicules(p.global_position)
		vue.collisions.ecarter(p)
		var hors := auto.global_transform.affine_inverse() * (p.global_position + Vector3(0, 0.9, 0))
		var demi_x := auto.mesh.get_aabb().size.x * 0.5
		_check(absf(hors.x) >= demi_x, "une voiture qui arrive sur le personnage l'écarte sur le côté")
	tr.traffic.set_enabled(false)

	print("1re personne :")
	p.teleporter(Vector3(0.5, 20.1, 20.5), 0.0)
	vue.collisions.mettre_a_jour(p.global_position, 99)
	await _frames(40)
	vue.zoomer(-1)
	for i in 20:
		vue.zoomer(-1)
	_check(vue.vue == VueSol.Vue.PREMIERE, "molette : au plus près, on passe à la 1re personne")
	await _frames(5)
	await process_frame
	await process_frame
	var oeil := p.global_position + Vector3(0, Personnage.YEUX, 0)
	var ecart := vue.camera.global_position - oeil
	_check(ecart.length() < 0.15, "caméra à hauteur des yeux (écart %.2f m : %s)" % [ecart.length(), ecart])
	_check(vue.camera.cull_mask & Personnage.COUCHE_CORPS == 0, "son propre corps ne gêne pas la vue")
	vue.zoomer(1)
	_check(vue.vue == VueSol.Vue.TROISIEME, "molette arrière : retour à la 3e personne")

	print("Eau :")
	p.teleporter(Vector3(-400.5, 0.0, 0.5), 0.0)
	await _frames(180)
	_check(p.nage and absf(p.global_position.y - (TerrainWorld.WATER_LEVEL - 1.3)) < 0.4, "nage à la surface de la mer (%.2f m)" % p.global_position.y)

	print("Multijoueur (état) :")
	p.teleporter(Vector3(3.5, 20.1, 7.5), 1.0)
	var etat := p.etat()
	var autre := Personnage.new()
	scene.add_child(autre)
	autre.appliquer_etat(JSON.parse_string(JSON.stringify(etat)))
	_check(autre.global_position.distance_to(p.global_position) < 0.01 and is_equal_approx(float(autre.commande.cap), 1.0),
		"l'état d'un personnage se transmet en JSON")
	autre.queue_free()

	if shot != "":
		await _captures(vue, p, rig, shot, tr)

	print("Sauvegarde :")
	vue.set_vue(VueSol.Vue.PREMIERE)
	p.teleporter(Vector3(12.5, 20.1, 33.5), 0.4)
	vue._cap = 0.4
	var sauve: Dictionary = JSON.parse_string(JSON.stringify(vue.to_dict()))
	vue.set_vue(VueSol.Vue.DESSUS)
	vue.from_dict(sauve)
	_check(vue.vue == VueSol.Vue.PREMIERE and p.global_position.distance_to(Vector3(12.5, 20.1, 33.5)) < 0.01 and is_equal_approx(vue._cap, 0.4),
		"la vue et la place du personnage sont gardées dans la sauvegarde")
	vue.set_vue(VueSol.Vue.TROISIEME)

	print("Retour en vue de dessus :")
	vue.set_physics_process(true)
	p.teleporter(Vector3(30.5, 20.1, 40.5), 0.7)
	vue._cap = 0.7
	await _frames(5)
	vue.set_vue(VueSol.Vue.DESSUS)
	_check(not p.visible and rig.is_processing(), "personnage rangé, caméra de gestion relancée")
	_check(Vector2(rig.position.x, rig.position.z).distance_to(Vector2(30.5, 40.5)) < 0.5, "la vue de dessus se centre sur le personnage")
	_check((rig.get_node("Camera3D") as Camera3D).current and world._focus == rig, "le relief suit de nouveau la caméra de gestion")
	vue.vue_suivante()
	_check(vue.vue == VueSol.Vue.TROISIEME, "V : dessus → 3e personne")
	vue.vue_suivante()
	_check(vue.vue == VueSol.Vue.PREMIERE, "V : 3e → 1re personne")
	vue.vue_suivante()
	_check(vue.vue == VueSol.Vue.DESSUS, "V : 1re personne → dessus")

	print("PERSONNAGE TEST OK" if ok else "PERSONNAGE TEST ÉCHEC")
	quit(0 if ok else 1)


func _captures(vue: VueSol, p: Personnage, rig: Node3D, dossier: String, tr: TransportSystem) -> void:
	vue.set_physics_process(true)
	# Une petite route sur la plaine, en contrebas de la colline.
	tr.build_segment("route", Vector3(20, 0, -40), Vector3(150, 0, -10))
	var vues := [
		["3e-personne", VueSol.Vue.TROISIEME, Vector3(40.5, 21, -30.5), -1.75, -0.12, 5.0],
		["1re-personne", VueSol.Vue.PREMIERE, Vector3(-150.5, 21, 30.5), -PI / 2.0 + 0.25, -0.05, 4.5],
		["tunnel-entree", VueSol.Vue.TROISIEME, _tunnel_debut + Vector3(-14, 0.4, 0), -PI / 2.0, -0.08, 5.0],
		["tunnel-dedans", VueSol.Vue.TROISIEME, _tunnel_debut + Vector3(25, 0.4, 0), -PI / 2.0, -0.05, 4.0],
	]
	for v in vues:
		vue.set_vue(v[1])
		p.teleporter(v[2], v[3])
		vue._cap = v[3]
		vue._tangage = v[4]
		vue._distance = v[5]
		vue.collisions.mettre_a_jour(p.global_position, 99)
		for i in 120:
			await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.save_png(dossier.path_join("apercu-%s.png" % v[0]))
		print("Capture : ", dossier.path_join("apercu-%s.png" % v[0]))
