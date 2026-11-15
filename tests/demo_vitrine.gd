extends SceneTree
## Vitrine de la démo : un village bâti au lieu de la démo guidée (vrai relief,
## téléchargé), puis les captures 1920 × 1080 pour la page Steam, et en option
## les plans d'une courte vidéo.
##
## Usage (avec affichage et réseau) :
##   godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     --script res://tests/demo_vitrine.gd -- --dossier /chemin/captures
## Options :
##   --plat              relief plat, sans réseau (pour essayer le script)
##   --proxy hôte:port   passe les téléchargements par ce proxy HTTPS
##   --ca fichier.crt    autorités de certification du proxy
##   --titre             seulement l'écran titre (00-ecran-titre.png)
##   --grand             captures sans interface en 3840 × 2160 (grand-*.png),
##                       pour les capsules Steam et le site (lancer avec
##                       --resolution 3840x2160)
##   --film              au lieu des captures : plans de caméra pour la vidéo,
##                       une image JPG par image du jeu dans <dossier>/film/
##                       (lancer avec --fixed-fps 30, puis assembler avec ffmpeg).

var dir := "."
var plat := false
var proxy_hote := ""
var proxy_port := 0
var ca: X509Certificate
var film := false
var titre := false
var grand := false

var scene: Node
var world: TerrainWorld
var transport: TransportSystem
var bs: BuildingSystem
var zs: ZoneSystem
var rig: Node3D
var amb: DayNight
var pop: Population
var _proxies := {}
## Centre du village (m) et hauteur du sol.
var centre := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(620.0)
	return a


func _args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var nxt := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--dossier":
				dir = nxt
			"--plat":
				plat = true
			"--film":
				film = true
			"--titre":
				titre = true
			"--grand":
				grand = true
			"--proxy":
				proxy_hote = nxt.get_slice(":", 0)
				proxy_port = int(nxt.get_slice(":", 1))
			"--ca":
				ca = X509Certificate.new()
				if ca.load(nxt) != OK:
					ca = null


## Les téléchargements du jeu (relief, biomes, rivières) passent par le proxy.
func _brancher_proxy(n: Node) -> void:
	if proxy_hote == "":
		return
	for c in n.find_children("*", "HTTPRequest", true, false):
		if _proxies.has(c.get_instance_id()):
			continue
		_proxies[c.get_instance_id()] = true
		var r := c as HTTPRequest
		r.set_https_proxy(proxy_hote, proxy_port)
		r.set_http_proxy(proxy_hote, proxy_port)
		if ca != null:
			r.set_tls_options(TLSOptions.client(ca))


func _attendre_relief(max_ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	var stable := 0
	var last := -1
	while Time.get_ticks_msec() - t0 < max_ms:
		await process_frame
		_brancher_proxy(scene)
		var n := world.horizon.patches.size() if world.horizon != null else 0
		var busy := world.tiles.pending_count() + world.land.pending_count()
		if world.horizon != null:
			busy += world.horizon.tiles.pending_count()
		stable = stable + 1 if n == last and busy == 0 and world.missing_chunk_count() == 0 and world._jobs.is_empty() and world.chunks.size() > 0 else 0
		last = n
		if stable > 60:
			break
	print("Relief prêt : %d blocs, %d plaques lointaines (%d ms)" % [world.chunks.size(),
		world.horizon.patches.size() if world.horizon != null else 0, Time.get_ticks_msec() - t0])


func _h(x: float, z: float) -> float:
	var h := world.cell_height(Vector2i(int(x), int(z)))
	return centre.y if is_nan(h) or is_inf(h) else h


func _p(x: float, z: float) -> Vector3:
	return Vector3(x, _h(x, z), z)


func _route(a: Vector2, b: Vector2, type := "route") -> void:
	var r: Dictionary = transport.build_segment(type, _p(a.x, a.y), _p(b.x, b.y))
	if not r.get("ok", false):
		print("  route refusée ", a, " → ", b, " : ", r.get("reason", "?"))


func _poser(id: String, c: Vector2i, r := -1) -> int:
	var rot := bs.best_rotation(id, c) if r < 0 else r
	var bid := bs.place(id, c, rot)
	if bid < 0:
		# Quelques essais autour.
		for d in [Vector2i(6, 0), Vector2i(-6, 0), Vector2i(0, 6), Vector2i(0, -6), Vector2i(10, 10), Vector2i(-10, -10)]:
			bid = bs.place(id, c + d, bs.best_rotation(id, c + d))
			if bid >= 0:
				break
	if bid < 0:
		print("  %s refusé : %s" % [id, bs.check_place(id, c, rot).get("reason", "?")])
	return bid


## Une rangée de bâtiments des deux côtés d'une rue, de a à b, tous les `pas` m.
func _rangee(ids: Array, a: Vector2, b: Vector2, pas: float, recul: float, rng: RandomNumberGenerator) -> int:
	var dirv := (b - a).normalized()
	var nrm := Vector2(-dirv.y, dirv.x)
	var n := 0
	var l := a.distance_to(b)
	var t := pas * 0.5
	while t < l:
		for side in [-1.0, 1.0]:
			var p: Vector2 = a + dirv * t + nrm * recul * float(side)
			var id := String(ids[rng.randi() % ids.size()])
			var c := Vector2i(roundi(p.x), roundi(p.y))
			if bs.check_place(id, c, bs.best_rotation(id, c)).get("ok", false):
				if bs.place(id, c, bs.best_rotation(id, c)) >= 0:
					n += 1
		t += pas
	return n


## Le village : une grand-rue, des rues de quartier bordées de maisons, la
## Maison de commune et sa place, l'école, des commerces, des loisirs, des
## ateliers, une ligne de bus et des habitants.
func _batir() -> void:
	bs.unlimited_money = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c := Vector2(centre.x, centre.z)
	var ci := Vector2i(int(c.x), int(c.y))
	# Grand-rue (départementale) est-ouest, rues du village.
	_route(c + Vector2(-360, 0), c + Vector2(360, 0))
	_route(c + Vector2(0, -250), c + Vector2(0, 250), "rue")
	for z in [-110.0, 110.0]:
		_route(c + Vector2(-230, z), c + Vector2(230, z), "rue")
	for x in [-230.0, -115.0, 115.0, 230.0]:
		_route(c + Vector2(x, -110), c + Vector2(x, 110), "rue")
	_route(c + Vector2(-115, -110), c + Vector2(-115, -210), "rue")
	_route(c + Vector2(115, 110), c + Vector2(115, 210), "rue")
	scene.communes.nom_en_attente = "Valfleuri"
	# Le centre : mairie et place au nord de la grand-rue, école et jeux au sud.
	_poser("maison_commune", ci + Vector2i(-26, -15))
	_poser("place_pavee", ci + Vector2i(24, -20))
	_poser("boulangerie", ci + Vector2i(48, -14))
	_poser("cafe", ci + Vector2i(-48, -15))
	_poser("superette", ci + Vector2i(70, -16))
	_poser("ecole", ci + Vector2i(-42, 28))
	_poser("aire_jeux", ci + Vector2i(18, 15))
	_poser("square", ci + Vector2i(40, 20))
	_poser("foot", ci + Vector2i(290, 70))
	_poser("eolienne", ci + Vector2i(330, -40))
	_poser("forage_eau", ci + Vector2i(-330, 16))
	# Ateliers à l'est, petits immeubles le long de la grand-rue.
	_rangee(["atelier", "entrepot"], c + Vector2(240, 0), c + Vector2(350, 0), 40.0, 27.0, rng)
	_rangee(["immeuble"], c + Vector2(-230, 0), c + Vector2(-120, 0), 24.0, 13.0, rng)
	_rangee(["immeuble", "superette"], c + Vector2(120, 0), c + Vector2(230, 0), 24.0, 13.0, rng)
	# Maisons et villas dans les rues de quartier.
	var maisons := ["maison", "maison", "maison", "villa"]
	var n := 0
	for z in [-110.0, 110.0]:
		n += _rangee(maisons, c + Vector2(-230, z), c + Vector2(230, z), 15.0, 11.0, rng)
	for x in [-230.0, -115.0, 115.0, 230.0]:
		n += _rangee(maisons, c + Vector2(x, -110), c + Vector2(x, 110), 15.0, 11.0, rng)
	n += _rangee(maisons, c + Vector2(0, -250), c + Vector2(0, -20), 15.0, 11.0, rng)
	n += _rangee(maisons, c + Vector2(0, 30), c + Vector2(0, 250), 15.0, 11.0, rng)
	n += _rangee(maisons, c + Vector2(-115, -110), c + Vector2(-115, -210), 15.0, 11.0, rng)
	n += _rangee(maisons, c + Vector2(115, 110), c + Vector2(115, 210), 15.0, 11.0, rng)
	print("  %d maisons" % n)
	# Une zone qui reste à bâtir, pour montrer le zonage.
	zs.add_zone("R", Rect2i(ci.x - 225, ci.y + 125, 100, 80))
	zs.growth = false
	pop._sync_buildings()
	var homes := []
	for bid in pop.known:
		if int(pop.known[bid].log) > 0:
			homes.append(bid)
	homes.shuffle()
	var guard := 0
	while not homes.is_empty() and pop.persons.size() < 600 and guard < 6000:
		guard += 1
		pop.spawn_household(homes[guard % homes.size()])
	pop._match_all()
	# Ligne de bus sur la grand-rue.
	var a: Dictionary = transport.stations.place("arret_bus", _p(c.x - 160, c.y - 6))
	var b: Dictionary = transport.stations.place("arret_bus", _p(c.x + 160, c.y + 6))
	if a.get("ok", false) and b.get("ok", false):
		transport.stations.create_line([a.id, b.id], "", 2)
	else:
		print("  arrêts : %s / %s" % [a.get("reason", "ok"), b.get("reason", "ok")])
	print("Village : %d bâtiments, %d habitants" % [bs.buildings.size(), pop.persons.size()])


var _caches: Array = []


## Cache l'interface (en retenant ce qui était visible) ou la remet comme avant.
func _ui(visible: bool) -> void:
	pop.follow(-1)
	if not visible:
		for n in scene.find_children("*", "CanvasLayer", true, false):
			if n is DemoBilan or not (n as CanvasLayer).visible:
				continue
			(n as CanvasLayer).visible = false
			_caches.append(n)
	else:
		for n in _caches:
			if is_instance_valid(n):
				(n as CanvasLayer).visible = true
		_caches.clear()


func _vue(pos: Vector3, angle: float, pitch: float, dist: float) -> void:
	rig.position = Vector3(pos.x, _h(pos.x, pos.z), pos.z)
	rig.rotation_degrees.y = angle
	rig._target_distance = dist
	rig._distance = dist
	rig.set_pitch(pitch, true)


func _shot(nom: String, frames := 40) -> void:
	for i in frames:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := dir.path_join(nom + ".png")
	img.save_png(path)
	print("Capture : %s (%d × %d)" % [path, img.get_width(), img.get_height()])


func _run() -> void:
	_args()
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(3840, 2160) if grand else Vector2i(1920, 1080)
	if titre:
		OptionsJeu.charger()
		OptionsJeu.titre_fixe = true
		root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		var m: Node = load(MenuPrincipal.SCENE).instantiate()
		root.add_child(m)
		await process_frame
		# Sans « Continuer » ni carte de la dernière partie : le bouton de la démo en avant.
		m._carte.visible = false
		m._carte.set_process(false)
		if m._boutons.has("continuer"):
			m._boutons.continuer.visible = false
		m._boutons.demo.grab_focus()
		await _shot("00-ecran-titre", 120)
		quit(0)
		return
	Creations.persist = false
	BatimentsVie.chantiers = false
	Demo.preparer()
	ReglagesPartie.prochaine.fondateurs = 0
	scene = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	transport = scene.get_node("Transport")
	bs = scene.get_node("Batiments")
	zs = scene.get_node("Zones")
	rig = scene.get_node("CameraRig")
	amb = scene.get_node("Ambiance")
	root.add_child(scene)
	_brancher_proxy(scene)
	pop = scene.population
	# Pas de personnage principal (il naîtrait, serait suivi et poserait des questions).
	pop.principal.enabled = false
	if plat:
		world.tiles.offline_generator = _flat_tile
		world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
		world.set_origin(float(Demo.LIEU.lat), float(Demo.LIEU.lon))
	scene.urgences.random_calls = false
	scene.evenements.forcer_auto = 0
	scene.evenements.forcer_catastrophes = 0
	pop.arrivals = false
	# Un samedi de fin juin, l'après-midi.
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-27T12:00:00")
	amb.set_local_hour(16.5)
	amb.set_speed(0)
	_vue(Vector3.ZERO, 200.0, 50.0, 420.0)
	await _attendre_relief(120_000)
	centre.y = _h(0.0, 0.0) if not is_nan(world.cell_height(Vector2i.ZERO)) else 0.0
	scene.tutoriel.arreter()
	_batir()
	await _attendre_relief(60_000)
	if film:
		await _film()
	elif grand:
		await _captures_grandes()
	else:
		await _captures()
	quit(0)


func _captures() -> void:
	# 1. Le village vu d'en haut, fin d'après-midi.
	_ui(false)
	amb.set_local_hour(17.5)
	_vue(centre + Vector3(-10, 0, 10), 205.0, 36.0, 280.0)
	await _shot("01-village-vu-du-ciel", 90)
	# 2. Caméra rasante : le village et la campagne jusqu'à l'horizon.
	_vue(centre + Vector3(-120, 0, -80), 150.0, 9.0, 260.0)
	await _attendre_relief(30_000)
	await _shot("02-campagne-a-l-horizon", 60)
	# 3. Le centre et sa place, plus près.
	amb.set_local_hour(18.6)
	_vue(centre + Vector3(10, 0, -10), 230.0, 32.0, 120.0)
	await _shot("03-centre-du-village")
	_ui(false)
	# 4. Un marché sur la place, avec l'interface et la carte de la démo.
	scene.evenements.fetes.organiser("marche", _p(centre.x + 22, centre.z - 18))
	amb.set_local_hour(10.0)
	var t: Tutoriel = scene.tutoriel
	t.parcours = "demo"
	t.actif = true
	t.etape = t.etapes().map(func(e) -> String: return String(e.id)).find("ligne")
	t.temps_demo = 17.0 * 60.0
	t.set_process(false)
	for e in t.etapes().slice(0, t.etape):
		t.faits[String(e.id)] = true
	t._debut_etape()
	t.changed.emit()
	_ui(true)
	scene.tuto_carte.cachee = false
	_vue(centre + Vector3(20, 0, -15), 215.0, 38.0, 95.0)
	await _shot("04-demo-guidee-marche", 90)
	# 5. Vue au sol, dans la grand-rue.
	_ui(false)
	amb.set_local_hour(11.0)
	_vue(centre + Vector3(-40, 0, 4), 90.0, 30.0, 40.0)
	var vs: VueSol = scene.get_node("VueSol")
	vs.set_vue(VueSol.Vue.TROISIEME)
	await _shot("05-vue-au-sol", 90)
	vs.set_vue(VueSol.Vue.DESSUS)
	# 6. Le soir : lumières des maisons et des rues.
	amb.set_local_hour(21.3)
	_vue(centre + Vector3(0, 0, 10), 170.0, 30.0, 200.0)
	await _shot("06-soir-au-village", 90)
	# 7. Le terrain de foot et les quartiers.
	amb.set_local_hour(15.0)
	_vue(centre + Vector3(160, 0, 60), 250.0, 35.0, 140.0)
	await _shot("07-foot-et-quartiers")
	# 8. Le bilan de fin de démo, au-dessus du village.
	t.etape = t.etapes().size() - 1
	for e in t.etapes():
		t.faits[String(e.id)] = true
	t.temps_demo = 31.0 * 60.0
	bs.unlimited_money = false
	bs.money = 21_480_000
	t.changed.emit()
	scene.objectifs.paliers[t.ville()] = 1
	_ui(true)
	_vue(centre, 200.0, 45.0, 300.0)
	t.agir()
	await _shot("08-bilan-de-la-demo", 60)


## Grandes captures sans interface (3840 × 2160) : on y découpe les capsules
## Steam (héros de bibliothèque, capsule verticale, fond de page) et les images
## du site.
func _captures_grandes() -> void:
	_ui(false)
	amb.set_local_hour(17.5)
	_vue(centre + Vector3(-10, 0, 10), 205.0, 36.0, 280.0)
	await _shot("grand-village", 120)
	_vue(centre + Vector3(-120, 0, -80), 150.0, 9.0, 260.0)
	await _attendre_relief(30_000)
	await _shot("grand-horizon", 90)
	amb.set_local_hour(18.6)
	_vue(centre + Vector3(10, 0, -10), 230.0, 22.0, 150.0)
	await _shot("grand-centre", 90)
	amb.set_local_hour(15.0)
	_vue(centre + Vector3(160, 0, 60), 250.0, 35.0, 140.0)
	await _shot("grand-foot", 90)
	amb.set_local_hour(21.3)
	_vue(centre + Vector3(0, 0, 10), 170.0, 30.0, 200.0)
	await _shot("grand-soir", 90)


var _n_image := 0


## Une image de la vidéo.
func _image() -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_jpg(dir.path_join("film/%05d.jpg" % _n_image), 0.92)
	_n_image += 1


## Plans de la vidéo : environ 38 s à 30 images/s.
func _film() -> void:
	DirAccess.make_dir_recursive_absolute(dir.path_join("film"))
	_ui(false)
	amb.set_local_hour(17.2)
	amb.set_speed(2)
	for i in 30:
		await process_frame
	# Plan 1 : survol qui descend vers le village (8 s).
	await _travelling(centre + Vector3(-200, 0, 150), centre, 160.0, 215.0, 30.0, 42.0, 900.0, 360.0, 240)
	# Plan 2 : tour lent du centre (8 s).
	await _travelling(centre, centre + Vector3(10, 0, -10), 215.0, 300.0, 40.0, 32.0, 260.0, 130.0, 240)
	# Plan 3 : rasant sur la campagne (7 s).
	await _travelling(centre + Vector3(-150, 0, -40), centre + Vector3(-60, 0, -120), 140.0, 165.0, 12.0, 8.0, 320.0, 260.0, 210)
	# Plan 4 : vue au sol dans la grand-rue (6 s).
	_vue(centre + Vector3(-60, 0, 4), 90.0, 30.0, 40.0)
	var vs: VueSol = scene.get_node("VueSol")
	vs.set_vue(VueSol.Vue.TROISIEME)
	for i in 20:
		await process_frame
	for i in 180:
		vs._cap += 0.003
		await _image()
	vs.set_vue(VueSol.Vue.DESSUS)
	# Plan 5 : le soir tombe sur le village (8 s).
	amb.set_local_hour(20.6)
	amb.set_speed(4)
	await _travelling(centre + Vector3(0, 0, 40), centre, 160.0, 200.0, 34.0, 28.0, 280.0, 220.0, 240)
	print("Film : %d images dans %s" % [_n_image, dir.path_join("film")])


func _travelling(p0: Vector3, p1: Vector3, a0: float, a1: float, pi0: float, pi1: float, d0: float, d1: float, n: int) -> void:
	# Le plan se prépare hors champ (relief et bâtiments affichés), puis on filme.
	_vue(p0, a0, pi0, d0)
	for i in 40:
		await process_frame
	for i in n:
		var k := smoothstep(0.0, 1.0, float(i) / float(n - 1))
		var p := p0.lerp(p1, k)
		rig.position = Vector3(p.x, _h(p.x, p.z), p.z)
		rig.rotation_degrees.y = lerpf(a0, a1, k)
		var d := lerpf(d0, d1, k)
		rig._target_distance = d
		rig._distance = d
		rig.set_pitch(lerpf(pi0, pi1, k), true)
		await _image()
