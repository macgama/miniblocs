extends SceneTree
## Vitrine des devantures vivantes : une rue avec boulangerie, boucherie,
## café, pharmacie, fleuriste, boutique, mairie, maisons, atelier et ferme.
## Captures de jour vue de près, à hauteur d'homme, le soir, en 1890 et en
## 1965, et la boulangerie pleine puis vide.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/devantures_vitrine.gd -- --dossier /chemin/captures

var dir := "."
var scene: Node
var bs: BuildingSystem
var amb: DayNight
var rig: Node3D
var dev: Devantures
var prod: Production
var y := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(nom: String) -> void:
	for i in 4:
		await process_frame
	dev.refresh()
	for i in 8:
		await process_frame
	var path := dir.path_join(nom)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _heure(iso: String) -> void:
	amb.unix_time = Time.get_unix_time_from_datetime_string(iso)
	amb.set_speed(0)
	for i in 3:
		await process_frame


## Caméra : `pos` point regardé, `yaw` en degrés, recul et inclinaison.
func _camera(pos: Vector3, yaw: float, distance: float, pitch: float) -> void:
	scene.population.follow(-1)
	rig.position = pos
	rig.rotation.y = deg_to_rad(yaw)
	rig._distance = distance
	rig._target_distance = distance
	rig.pitch_degrees = pitch
	rig._target_pitch = pitch
	if rig.has_method("_apply_camera"):
		rig.call("_apply_camera")
	for i in 6:
		await process_frame


func _remplir(bid: int, plein: float) -> void:
	if not prod.sites.has(bid):
		return
	for g in DevanturesTypes.profil(String(bs.buildings[bid].t)).get("vend", []):
		prod.sites[bid].st[g] = prod.cap_of(bid, String(g)) * plein


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	ReglagesPartie.actuel.deblocage = "tout"
	BatimentsVie.chantiers = false
	scene = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	bs = scene.get_node("Batiments")
	amb = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	await _heure("2026-06-10T08:30:00")
	bs.unlimited_money = true
	ReglagesPartie.actuel.deblocage = "tout"
	y = world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -160), Vector3(0, y, 160))
	dev = scene.devantures
	prod = scene.production
	rig = scene.rig
	# Côté est : la rue commerçante (façades vers l'ouest, vers la route).
	var est := ["boulangerie", "boucherie_charcuterie", "bistrot_parisien", "pharmacie", "fleuriste", "haussmann__boutique", "librairie"]
	var ids := {}
	var z := -70
	for id in est:
		var t := BuildingCatalog.get_type(id)
		var bid := bs.place(id, Vector2i(int(t.d) / 2 + 7, z + int(t.w) / 2), 3)
		ids[id] = bid
		z += int(t.w) + 2
	# Côté ouest : mairie, maisons, atelier, ferme.
	var ouest := ["mairie", "maison", "maison", "atelier", "ferme"]
	z = -70
	for id in ouest:
		var t := BuildingCatalog.get_type(id)
		var bid := bs.place(id, Vector2i(-int(t.d) / 2 - 7, z + int(t.w) / 2), 1)
		ids["%s_%d" % [id, z]] = bid
		z += int(t.w) + 2
	# Des maisons de plus, pour loger le personnel des commerces.
	var maisons := []
	for j in 10:
		var bm := bs.place("maison", Vector2i(-13, 60 + j * 12), 1)
		if bm > 0:
			maisons.append(bm)
	var pop: Population = scene.population
	pop._sync_buildings()
	for k in ids:
		if String(k).begins_with("maison"):
			maisons.append(int(ids[k]))
	for bm in maisons:
		pop.spawn_household(int(bm))
	# Embauche : deux adultes par commerce, café et mairie.
	var libres := []
	for pid in pop.persons:
		var pp: Dictionary = pop.persons[pid]
		if String(pp.get("role", "")) != "enfant" and int(pp.get("job", -1)) < 0 and pop.age_of(pp) >= 18.0:
			libres.append(pp)
	for k in ids:
		var bid := int(ids[k])
		if String(k).begins_with("maison"):
			continue
		var requis := Effectif.requis_de(String(bs.buildings[bid].t))
		for n in 3:
			if libres.is_empty():
				break
			var met := String(requis[n % requis.size()]) if not requis.is_empty() else ""
			pop._join_job(libres.pop_back(), bid, met)
	pop.effectif.actualiser(true)
	amb.weather.mode = Meteo.Mode.SOLEIL
	prod._sync()
	for k in ids:
		_remplir(int(ids[k]), 1.0)
	print("Bâtiments posés : ", ids)
	var boul := int(ids.boulangerie)
	var pb := bs.node_of(boul).global_position
	var fx := pb.x - float(BuildingCatalog.get_type("boulangerie").d) * 0.5
	# 1. Vue de près, de jour : la rue commerçante.
	await _camera(Vector3(fx, y, pb.z + 22), -90.0, 40.0, 30.0)
	await _shot("1-rue-commercante-jour.png")
	for m in dev.montres:
		print("  ", m.nom, " · ", m.genre, " · ouvert=", m.ouvert, " · niche=", m.niche, " · paliers=", m.paliers, " · store=", m.store,
			" · terrasse=", m.terrasse, " · vendeur=", m.vendeur, " · clients=", m.clients, " · queue=", m.queue)
	# 2. À hauteur d'homme devant la boulangerie.
	await _camera(Vector3(fx, y + 1.4, pb.z), -90.0, 7.0, 6.0)
	await _shot("2-boulangerie-hauteur-homme.png")
	# 3. Le café et sa terrasse.
	var pc := bs.node_of(int(ids.bistrot_parisien)).global_position
	var fc := pc.x - float(BuildingCatalog.get_type("bistrot_parisien").d) * 0.5
	await _camera(Vector3(fc - 1.5, y + 1.0, pc.z), -90.0, 12.0, 14.0)
	await _shot("3-cafe-terrasse.png")
	# 4. Boulangerie vide : plus de farine, plus de pain.
	_remplir(boul, 0.0)
	await _camera(Vector3(fx, y + 1.4, pb.z), -90.0, 7.0, 6.0)
	await _shot("4-boulangerie-vide.png")
	_remplir(boul, 1.0)
	# 4 bis. Fin d'après-midi : les clients font leurs courses.
	await _heure("2026-06-10T15:40:00")
	await _camera(Vector3(fx, y + 1.4, pb.z + 6), -90.0, 12.0, 10.0)
	await _shot("4b-clients-fin-apres-midi.png")
	for m in dev.montres:
		if int(m.clients) > 0 or int(m.queue) > 0:
			print("  clients : ", m.nom, " · dedans=", m.clients, " · queue=", m.queue)
	# 5. Le soir : vitrines éclairées, stores repliés.
	await _heure("2026-06-10T20:40:00")
	await _camera(Vector3(fx, y, pb.z + 18), -90.0, 36.0, 40.0)
	await _shot("5-rue-le-soir.png")
	# 6. L'autre trottoir : mairie, maisons, atelier, ferme.
	await _heure("2026-06-10T08:30:00")
	var pm := bs.node_of(int(ids["mairie_-70"])).global_position
	await _camera(Vector3(-8, y, pm.z + 34), 90.0, 46.0, 32.0)
	await _shot("6-mairie-maisons-atelier.png")
	# 7 et 8. Époques : 1890 puis 1965.
	var r := ReglagesPartie.actuel
	for an in [1890, 1965]:
		r.annee_depart = an
		r.histoire_debut = amb.unix_time
		r.histoire_saut = 0
		await _camera(Vector3(fx, y + 1.0, pb.z + 6), -90.0, 12.0, 10.0)
		await _shot("%d-epoque-%d.png" % [7 if an == 1890 else 8, an])
	quit(0)
