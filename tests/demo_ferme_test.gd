extends SceneTree
## Test de la démo « ferme low-poly » et du kit de modelage LpKit.
## Usage : godot --headless --path . --script res://tests/demo_ferme_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _run() -> void:
	# Kit : une boîte = 12 triangles, normales vers l'extérieur.
	var k := LpKit.new(1)
	k.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.WHITE)
	_check(k.triangle_count() == 12, "une boîte fait 12 triangles")
	var mesh := k.commit({"base": LpKit.vertex_material()})
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var outward := true
	for i in range(0, verts.size(), 3):
		var c := (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		if norms[i].dot(c - Vector3(0, 0.5, 0)) <= 0.0:
			outward = false
		# Sens horaire vu de l'extérieur (convention de Godot pour les faces avant).
		var n := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
		if n.dot(norms[i]) >= 0.0:
			outward = false
	_check(outward, "normales vers l'extérieur et faces dans le bon sens")
	# Triangle mal orienté : retourné grâce à la direction donnée.
	var k2 := LpKit.new(2)
	k2.tri(Vector3.ZERO, Vector3(0, 0, 1), Vector3(1, 0, 0), Color.RED, Vector3.UP)
	var m2 := k2.commit({"base": LpKit.vertex_material()})
	var n2: PackedVector3Array = m2.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	_check(n2[0].y > 0.99, "triangle réorienté vers le haut")
	# Variation de teinte : jamais deux fois la même, mais proche.
	var c0 := Color("b8964f")
	var c1 := k.vary(c0)
	_check(c1 != c0 and absf(c1.v - c0.v) < 0.2, "variation de teinte légère")

	# La scène complète.
	var t0 := Time.get_ticks_msec()
	var scene: Node = load("res://scenes/demo_ferme.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var ms := Time.get_ticks_msec() - t0
	print("  construite en ", ms, " ms : ", scene.stats)
	_check(ms < 20000, "construction en moins de 20 s")
	for nom in ["Maison", "Grange", "Cour", "Enclos", "Potager", "Foret", "Sol proche", "Mare", "Fumee"]:
		_check(scene.get_node_or_null(nom) != null, "objet présent : " + nom)
	_check(scene.stats.triangles > 100000, "plus de 100 000 triangles de décor")
	_check(scene.stats.herbes > 10000, "plus de 10 000 touffes d'herbe")
	_check(scene.stats.epis > 10000, "plus de 10 000 gerbes de blé")
	_check(scene.hauteur(0, 0) > -1.0 and scene.hauteur(0, 0) < 1.0, "ferme sur terrain plat")
	_check(scene.hauteur(-38, 9) < -0.5, "la mare est creusée")
	_check(scene.zone(-38, 9) == scene.Zone.BERGE and scene.zone(0, 40) == scene.Zone.CHAMP, "zones du sol")
	for i in 4:
		scene.appliquer_lumiere(i)
		_check(scene.lumiere == i, "lumière %d : %s" % [i, scene.LUMIERES[i]])
	_check(scene.mats["verre"].emission_energy_multiplier > 0.0, "le soir, les fenêtres s'allument")
	_check(scene.lampes.size() == 2 and scene.lampes[0].light_energy > 0.0, "le soir, les lanternes s'allument")
	scene.appliquer_lumiere(0)
	_check(scene.mats["verre"].emission_energy_multiplier == 0.0, "le jour, fenêtres éteintes")
	for i in 4:
		scene.appliquer_vue(i)
		var cam: Camera3D = scene.camera
		_check(cam.position.y > scene.hauteur(cam.position.x, cam.position.z), "vue %d au-dessus du sol" % i)
	print("DEMO TEST OK" if ok else "DEMO TEST ÉCHEC")
	quit(0 if ok else 1)
