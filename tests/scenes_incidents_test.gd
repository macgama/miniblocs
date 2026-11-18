extends SceneTree
## Test des lieux des incidents (ScenesIncidents) et de leurs icônes
## (IconesIncidents) : voitures accidentées, blessé, feux de détresse,
## équipages qui descendent (cordon, brancard, lance), fermeture ; icônes et
## carte de détail ; appels rares dans un hameau ; un appel sans service pour
## y répondre se règle seul au bout d'un moment ; alerte « construire ».
## Usage : godot --headless --path . --script res://tests/scenes_incidents_test.gd

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


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


func _count(n: Node, cls: String) -> int:
	var c := 1 if n.is_class(cls) or (n.get_script() != null and (n.get_script() as Script).get_global_name() == cls) else 0
	for k in n.get_children():
		c += _count(k, cls)
	return c


func _run() -> void:
	print("Épave :")
	var src := VehicleCatalog.build_mesh("berline", 0, EvVisuels.material())
	var ep := ScenesIncidents.epave("berline", 0, "avant")
	_check(ep.get_surface_count() == src.get_surface_count(), "même nombre de surfaces que la voiture")
	_check(ep.get_aabb().size.z < src.get_aabb().size.z - 0.2, "l'avant est enfoncé (%.2f m → %.2f m)" % [src.get_aabb().size.z, ep.get_aabb().size.z])
	_check(ScenesIncidents.epave("berline", 0, "avant") == ep, "maillage d'épave gardé en cache")
	_check(IconesIncidents.atlas().get_width() == IconesIncidents.CASE * 8, "atlas des icônes 8 × 3")
	_check(IconesIncidents.picto("accident") != IconesIncidents.picto("incendie"), "un pictogramme par genre d'incident")

	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var urg: Urgences = scene.urgences
	var tf := transport.traffic
	tf.set_process(false)
	urg.set_process(false)
	tf.siren_sound = false
	urg.random_calls = false
	urg.ignore_crew = true
	bs.unlimited_money = true
	ReglagesPartie.actuel.deblocage = "tout"
	_check(urg.scenes != null and urg.icones != null, "lieux et icônes branchés dans les urgences")
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0))
	var hosp := _place(bs, "hopital", 400, false)
	var maison := _place(bs, "maison", 100)
	_check(hosp > 0 and maison > 0, "hôpital et maison posés")
	urg._sync_stations()

	print("Hameau sans police :")
	_check(urg.call_rate() == 0.0, "aucun habitant : aucun appel au hasard")
	_check(urg.call_weight("accident") == 0.0, "pas de voitures : pas d'accident au hasard")
	var id := urg.declare("accident", "Accident de la route", Vector3(150, y, 2), ["ambulance", "police"], 1)
	var inc: Dictionary = urg.incidents[id]
	var sc: Dictionary = urg.scenes.scenes.get(id, {})
	_check(not sc.is_empty(), "lieux de l'accident créés")
	_check((sc.get("blink", []) as Array).size() == 8, "deux voitures, quatre feux de détresse chacune")
	_check(sc.get("blesse") != null and sc.get("voisin") != null, "un blessé allongé et le conducteur au bord de la route")
	var pos_sc: Vector3 = inc.scene_pos
	_check(absf(pos_sc.y - y) < 1.5 and pos_sc.distance_to((inc.road as Dictionary).pos) > 5.0, "voitures un peu après l'arrêt des secours (%.1f m)" % pos_sc.distance_to((inc.road as Dictionary).pos))
	_check(urg.services_manquants(inc) == ["police"], "il manque la police")
	var al := urg.alertes()
	_check(al.size() == 1 and String(al[0].panneau) == "batiment:police", "alerte Mairie : construire un commissariat")
	var det := urg.detail(inc)
	_check(String(det.texte).contains("commissariat"), "la carte dit quoi construire")
	urg.icones.maj()
	_check(urg.icones.icones.size() == 1, "une icône pour l'incident")
	var steps := 0
	var saw_crew := false
	var saw_stretcher := false
	for i in 20000:
		tf.step(0.1)
		urg.step(0.1)
		urg.scenes._process(0.1)
		steps = i
		if urg.scenes.scenes.has(id):
			var s2: Dictionary = urg.scenes.scenes[id]
			saw_crew = saw_crew or not (s2.equipes as Dictionary).is_empty()
			saw_stretcher = saw_stretcher or s2.has("brancard")
		if not urg.incidents.has(id):
			break
	_check(saw_crew, "les ambulanciers descendent sur place")
	_check(saw_stretcher, "brancard à côté du blessé")
	_check(not urg.incidents.has(id), "sans police, l'accident finit par se régler seul (%d s)" % int(steps * 0.1))
	_check(not urg.scenes.scenes.has(id), "les épaves disparaissent")

	print("Avec la police :")
	var cop := _place(bs, "police", -200)
	var fire := _place(bs, "pompiers", -400)
	_check(cop > 0 and fire > 0, "commissariat et caserne posés")
	urg._sync_stations()
	_check(urg.alertes().is_empty(), "plus d'alerte « construire »")
	id = urg.declare("accident", "Accident de la route", Vector3(150, y, 2), ["ambulance", "police"], 1)
	var saw_cordon := false
	var saw_blesse_parti := false
	for i in 20000:
		tf.step(0.1)
		urg.step(0.1)
		urg.scenes._process(0.1)
		if urg.scenes.scenes.has(id):
			var s3: Dictionary = urg.scenes.scenes[id]
			saw_cordon = saw_cordon or s3.cordon != null
			saw_blesse_parti = saw_blesse_parti or (s3.blesse == null and urg.incidents[id].done.get("ambulance", false))
		if not urg.incidents.has(id):
			break
	_check(saw_cordon, "la police pose un cordon")
	_check(saw_blesse_parti, "l'ambulance repart avec le blessé")
	_check(not urg.incidents.has(id) and not urg.scenes.scenes.has(id), "intervention terminée, lieux dégagés")

	print("À domicile et feu de poubelle :")
	var mid := urg.declare("malaise", "Malaise", urg._building_pos(maison), ["ambulance"], 1, {"bid": maison})
	var ms: Dictionary = urg.scenes.scenes[mid]
	var b: Dictionary = bs.buildings[maison]
	_check(ms.blesse != null and absf((ms.anchor as Vector3).y - float(b.h)) < 0.5, "la personne est allongée devant sa porte, au sol")
	var fid := urg.declare("feu_poubelle", "Feu de poubelle", Vector3(-50, y, 2), ["pompiers"], 1)
	var fs: Dictionary = urg.scenes.scenes[fid]
	_check(fs.has("feu"), "la poubelle brûle")
	var saw_lance := false
	for i in 20000:
		tf.step(0.1)
		urg.step(0.1)
		urg.scenes._process(0.1)
		if urg.scenes.scenes.has(fid):
			for uid in urg.scenes.scenes[fid].equipes:
				for x in urg.scenes.scenes[fid].equipes[uid].extras:
					saw_lance = saw_lance or x is GPUParticles3D
		if not urg.incidents.has(fid) and not urg.incidents.has(mid):
			break
	_check(saw_lance, "les pompiers sortent la lance (jet d'eau)")
	_check(urg.incidents.is_empty() and urg.scenes.scenes.is_empty(), "tout est fini et rangé")

	print("Chevauchement des icônes :")
	urg.declare("cambriolage", "Cambriolage", Vector3(300, y, 2), ["police"], 1)
	urg.declare("cambriolage", "Cambriolage", Vector3(300.6, y, 2), ["police"], 1)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(300, y, 0)
	for i in 90:
		await process_frame
	urg.icones.maj()
	var decal := 0.0
	for ic in urg.icones.icones:
		decal = maxf(decal, float(ic.decal))
	_check(urg.icones.icones.size() == 2, "deux icônes")
	_check(decal > 0.0 or urg.icones.get_viewport().get_camera_3d() == null, "la seconde se décale pour ne pas recouvrir la première (%.1f)" % decal)
	urg.clear()
	_check(urg.scenes.scenes.is_empty(), "clear() range les lieux")
	scene.queue_free()
	await process_frame
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
