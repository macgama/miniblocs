extends SceneTree
## Test du mode photo et du time-lapse : vidéo AVI écrite à la main (en-tête,
## index, lisible par ffprobe s'il est là), cadrages et tailles des photos,
## noms de fichiers, entrée et sortie du mode photo (temps figé, interface
## cachée puis rendue, heure de la lumière sans toucher l'horloge), caméra du
## time-lapse posée à la fondation du village, une image par jour vers midi,
## pas la nuit ni loin de la caméra, sauvegarde, ancienne partie, écran de
## lecture, export AVI et bouton du menu Infos.
## Usage : godot --headless --path . --script res://tests/photo_test.gd

var ok := true
## Vendredi 17 juillet 2026, midi (UTC+2).
const MIDI := 1_784_282_400.0


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
	_avi_tests()
	_cadrage_tests()
	await _scene_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _u32(b: PackedByteArray, at: int) -> int:
	return b.decode_u32(at)


func _avi_tests() -> void:
	print("Vidéo AVI :")
	var chemin := "user://test_photo.avi"
	var avi := AviMjpeg.new()
	_check(avi.ouvrir(chemin, 160, 90, 12), "fichier AVI ouvert")
	for i in 20:
		var img := Image.create(160, 90, false, Image.FORMAT_RGB8)
		img.fill(Color.from_hsv(i / 20.0, 0.7, 0.9))
		avi.ajouter_image(img)
	# Une image d'une autre taille est remise à la taille de la vidéo.
	avi.ajouter_image(Image.create(320, 200, false, Image.FORMAT_RGBA8))
	avi.fermer()
	var b := FileAccess.get_file_as_bytes(chemin)
	_check(b.slice(0, 4).get_string_from_ascii() == "RIFF" and b.slice(8, 12).get_string_from_ascii() == "AVI ", "en-tête RIFF AVI")
	_check(_u32(b, 4) == b.size() - 8, "taille RIFF juste")
	_check(_u32(b, 48) == 21, "21 images annoncées dans l'en-tête")
	_check(_u32(b, 64) == 160 and _u32(b, 68) == 90, "taille 160 × 90 dans l'en-tête")
	var idx := b.size() - 21 * 16 - 8
	_check(b.slice(idx, idx + 4).get_string_from_ascii() == "idx1" and _u32(b, idx + 4) == 21 * 16, "index des images à la fin")
	var out := []
	if OS.execute("ffprobe", ["-v", "error", "-count_frames", "-show_entries", "stream=codec_name,nb_read_frames,width", "-of", "csv=p=0", ProjectSettings.globalize_path(chemin)], out) == 0:
		var t := String(out[0]).strip_edges()
		_check(t.begins_with("mjpeg,160,21"), "ffprobe lit la vidéo (%s)" % t)
	else:
		print("  --  ffprobe absent : lecture non vérifiée")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))


func _cadrage_tests() -> void:
	print("Cadrage et fichiers :")
	var ecran := Vector2(1600, 900)
	var v := ModePhoto.rect_cadre(ecran, 9.0 / 16.0)
	_check(is_equal_approx(v.size.y, 900.0) and is_equal_approx(v.size.x, 506.25) and is_equal_approx(v.position.x, 546.875), "cadre vertical 9:16 au centre de l'écran")
	var ci := ModePhoto.rect_cadre(ecran, 2.39)
	_check(is_equal_approx(ci.size.x, 1600.0) and ci.size.y < 700.0 and ci.position.y > 100.0, "cadre cinéma : bandes en haut et en bas")
	_check(ModePhoto.taille_sortie(9.0 / 16.0, 1080) == Vector2i(1080, 1920), "photo verticale HD : 1080 × 1920")
	_check(ModePhoto.taille_sortie(16.0 / 9.0, 2160) == Vector2i(3840, 2160), "photo 4K : 3840 × 2160")
	_check(ModePhoto.taille_sortie(1.0, 1080) == Vector2i(1080, 1080), "photo carrée")
	_check(is_equal_approx(ModePhoto.fov_sortie(70.0, ecran, 9.0 / 16.0), 70.0), "vertical : même champ vertical que l'écran")
	_check(ModePhoto.fov_sortie(70.0, ecran, 2.39) < 70.0, "cinéma : champ vertical réduit comme le cadre")
	var n := ModePhoto.nom_fichier("Saint-Jean: <test>/?", {"year": 2026, "month": 11, "day": 5, "hour": 9, "minute": 3, "second": 7})
	_check(n == "MiniBlocs Saint-Jean   test 2026-11-05 09-03-07.png", "nom de fichier sans caractères interdits (%s)" % n)
	var ids := {}
	for f in ModePhoto.FILTRES:
		ids[int(f[1])] = true
	_check(ids.size() == ModePhoto.FILTRES.size() and ids.has(0) and ids.has(9), "12 filtres, dont maquette (tilt-shift)")
	_check(load("res://scripts/photo/filtre_photo.gdshader") is Shader, "shader des filtres chargé")
	_check(TimeLapse.taille_images("paysage", "standard") == Vector2i(1280, 720), "time-lapse standard : 1280 × 720")
	_check(TimeLapse.taille_images("vertical", "haute") == Vector2i(1080, 1920), "time-lapse vertical haute : 1080 × 1920")
	_check(TimeLapsePanel.date_texte(0.0) == "1er janvier 1970", "date en toutes lettres")
	_check(TimeLapsePanel.date_texte(-3786825600.0 + 86400.0 * 40) == "10 février 1850", "date des années 1800")
	_check(TimeLapsePanel.habitants_texte(12345) == "12 345 habitants", "habitants avec espaces")


func _scene_tests() -> void:
	print("Dans la partie :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 400.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var tl: TimeLapse = scene.timelapse
	var mp: ModePhoto = scene.mode_photo
	var panel: TimeLapsePanel = scene.timelapse_panel
	_check(tl != null and mp != null and panel != null, "mode photo et time-lapse branchés")
	_check(scene.save_sections().has("timelapse"), "section « timelapse » dans la sauvegarde")
	var amb: DayNight = scene.ambiance
	amb.set_speed(0)
	if amb.weather != null:
		amb.weather.set_process(false)
	amb.unix_time = MIDI
	amb._apply()
	tl.set_process(false)
	var couleurs := [0]
	tl.capturer = func(_c: Dictionary) -> Image:
		couleurs[0] += 1
		var img := Image.create(64, 36, false, Image.FORMAT_RGB8)
		img.fill(Color.from_hsv(couleurs[0] * 0.1, 0.6, 0.8))
		return img

	# Fondation : une caméra filme le village.
	var cm: Communes = scene.communes
	var vid := cm.fonder_au_point("Testville", Vector2(10, 10))
	_check(tl.cameras.size() == 1 and int(tl.cameras[0].vid) == vid, "caméra posée à la fondation du village")
	var c: Dictionary = tl.cameras[0]
	var xf := TimeLapse.xform_de(c)
	_check(xf.origin.distance_to(Vector3(10, 40, 10)) > 200.0 and (-xf.basis.z).dot((Vector3(10, 40, 10) - xf.origin).normalized()) > 0.99, "elle regarde la Maison de commune de biais, de loin")
	_check(String(c.nom) == "Village de Testville", "nommée d'après le village")
	cm.fonder_au_point("Testville", Vector2(10, 10))
	_check(tl.cameras.size() == 2, "un deuxième village a sa propre caméra")
	tl.supprimer(int(tl.cameras[1].id))

	# Une image par jour, vers midi.
	scene.rig.global_position = Vector3(0, 40, 0)
	_check(tl.a_filmer(c), "à midi : image à prendre")
	_check(await tl.filmer(c) and (c.images as Array).size() == 1, "première image prise")
	_check(FileAccess.file_exists(tl.chemin_image(c, 0)), "image enregistrée en JPEG (%s)" % tl.chemin_image(c, 0))
	_check(not tl.a_filmer(c), "pas deux images le même jour")
	amb.shift_days(1)
	amb.set_local_hour(3.0)
	_check(not tl.a_filmer(c), "pas d'image la nuit")
	amb.set_local_hour(12.5)
	_check(tl.a_filmer(c), "le lendemain à midi : nouvelle image")
	scene.rig.global_position = Vector3(5000, 40, 0)
	_check(not tl.a_filmer(c), "joueur trop loin : l'image attend")
	scene.rig.global_position = Vector3(0, 40, 0)
	tl.set_process(true)
	for i in 30:
		await process_frame
	tl.set_process(false)
	_check((c.images as Array).size() == 2, "prise toute seule par le time-lapse")
	tl.intervalle = 7
	for d in 5:
		amb.shift_days(1)
		if tl.a_filmer(c):
			await tl.filmer(c)
	_check((c.images as Array).size() == 2, "une image par semaine : rien avant 7 jours")
	tl.intervalle = 1
	for d in 4:
		amb.shift_days(1)
		if tl.a_filmer(c):
			await tl.filmer(c)
	_check((c.images as Array).size() == 6, "6 images en tout")
	tl.set_actif(int(c.id), false)
	amb.shift_days(1)
	_check(not tl.a_filmer(c), "caméra suspendue : plus d'image")
	tl.set_actif(int(c.id), true)

	# Sauvegarde.
	var d := tl.to_dict()
	var copie := TimeLapse.new()
	copie.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(copie.id_partie == tl.id_partie and copie.cameras.size() == 1 and (copie.cameras[0].images as Array).size() == 6
		and int(copie.cameras[0].id) == int(c.id), "time-lapse relu de la sauvegarde (JSON)")
	copie.free()

	# Écran de lecture : temps en pause, images, export.
	panel.set_open(true)
	_check(panel.is_open() and paused, "écran du time-lapse ouvert, partie en pause")
	_check(panel._tex.texture != null and panel._date.text.contains("2026"), "dernière image affichée avec sa date (%s)" % panel._date.text)
	panel.jouer(true)
	_check(panel.image == 0 and panel.lecture, "lecture depuis la fondation")
	for i in 40:
		await process_frame
	_check(panel.image > 0, "les images défilent (image %d)" % panel.image)
	var avi := "user://test_timelapse.avi"
	_check(TimeLapsePanel.avi_brut(tl, c, avi, 12) == "", "export AVI")
	var b := FileAccess.get_file_as_bytes(avi)
	_check(b.size() > 1000 and _u32(b, 48) == 6 + 24, "vidéo : 6 images + 2 s sur la dernière")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(avi))
	panel.set_open(false)
	_check(not panel.is_open() and not paused, "écran fermé, la partie reprend")

	# Mode photo.
	var hud: CanvasLayer = scene.hud
	var t0 := amb.unix_time
	var ev := InputEventKey.new()
	ev.keycode = KEY_F6
	ev.pressed = true
	mp._input(ev)
	_check(mp.actif and paused and mp.camera != null and mp.camera.current, "F6 : mode photo, temps figé, caméra libre")
	_check(not hud.visible and mp._layer.visible, "interface du jeu cachée, panneau photo visible")
	_check(scene.rig.process_mode == Node.PROCESS_MODE_DISABLED, "caméra de gestion arrêtée")
	var h0 := mp.heure_affichee()
	mp.set_heure(19.5)
	_check(absf(mp.heure_affichee() - 19.5) < 0.01 and amb.unix_time == t0, "heure de la lumière changée, horloge du jeu intacte")
	var p0 := mp.camera.global_position
	mp._yaw = 0.0
	mp.camera.global_position = Vector3(p0.x, 30.0, p0.z)
	mp._appliquer_camera()
	var sol := float(mp.ground_height.call(p0.x, p0.z))
	_check(mp.camera.global_position.y >= sol + 0.59 and sol > 35.0, "la caméra libre ne passe pas sous le sol (%.1f m, sol %.1f m)" % [mp.camera.global_position.y, sol])
	mp.filtre = 9
	mp._appliquer_filtre()
	_check(mp._filtre_rect.visible and int(mp._materiau.get_shader_parameter("filtre")) == 9, "filtre maquette appliqué")
	mp.format = "vertical"
	mp.definition = 1080
	_check(await mp.prendre_photo() == "", "sans affichage : pas de photo, pas de plantage")
	var n_avant := tl.cameras.size()
	mp.cadrage_timelapse.emit(mp.camera.global_transform, 50.0, "vertical")
	_check(tl.cameras.size() == n_avant + 1 and String(tl.cameras[-1].format) == "vertical", "« Filmer ce cadrage » ajoute une caméra verticale")
	mp._input(ev)
	_check(not mp.actif and not paused and hud.visible, "F6 à nouveau : retour au jeu, interface revenue")
	_check(absf(mp.heure_affichee() - h0) < 0.01, "lumière de l'heure du jeu revenue")
	_check(scene.rig.process_mode != Node.PROCESS_MODE_DISABLED, "caméra de gestion relancée")
	scene.hud._on_category("photo")
	_check(mp.actif, "bouton Mode photo du menu Infos")
	mp.quitter()
	var dans_infos := false
	for cat in TerreHud.CATEGORIES:
		if String(cat.id) == "photo":
			dans_infos = String(cat.group) == "infos"
	_check(dans_infos, "bouton dans le menu Infos")

	# Ancienne partie : ses villages sont filmés à partir de maintenant.
	var sec: Dictionary = scene.save_sections()
	sec.erase("timelapse")
	for cam in tl.cameras.duplicate():
		tl.effacer_images(int(cam.id))
	tl.clear()
	tl.adopter_villages()
	_check(tl.cameras.size() >= 1 and int(tl.cameras[0].vid) == vid, "ancienne partie : une caméra par village")

	var aide := false
	for s in AidePanel.SECTIONS:
		for l in s[1]:
			if String(l[0]).contains("F6"):
				aide = true
	_check(aide, "F6 dans l'aide (F1)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tl.dossier()))
	scene.queue_free()
	await process_frame
