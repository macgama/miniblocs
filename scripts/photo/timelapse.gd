class_name TimeLapse
extends Node
## Time-lapse de la ville : des caméras fixes prennent une image par jour de
## jeu (vers midi, pour une lumière égale), depuis la fondation de chaque
## village. Les images sont des JPEG légers rangés à part
## (user://timelapse/<partie>/c<caméra>/00000.jpg) ; la sauvegarde ne garde que
## la liste des caméras et l'index des images (date, habitants).
##
## Lecture et export (AVI, MP4 si ffmpeg est installé, séquence d'images) :
## TimeLapsePanel (Maj+F4). Voir docs/photo.md.

signal message(text: String)
signal changed

const MAX_CAMERAS := 4
const INTERVALLES := [1, 2, 3, 7, 30]
## Hauteur des images selon la qualité (la largeur suit le format de la caméra).
const QUALITES := {"standard": 720, "haute": 1080}
const FORMATS := {"paysage": 16.0 / 9.0, "vertical": 9.0 / 16.0, "carre": 1.0}
## Les blocs du relief ne sont chargés qu'autour de la caméra du joueur : au-delà,
## l'image attend qu'il revienne.
const DISTANCE_MAX := 2500.0
const QUALITE_JPEG := 0.86

var ambiance: DayNight
var rig: Node3D
var world: TerrainWorld
var communes: Communes
var population: Population
## Pour les tests : Callable(camera: Dictionary) -> Image, à la place du rendu.
var capturer: Callable

## Identifiant de la partie (dossier des images), gardé dans la sauvegarde.
var id_partie := ""
var cameras: Array = []
var next_cam := 1
var enregistrer := true
var intervalle := 1
var qualite := "standard"

var _t_verif := 0.0
var _en_cours := false


func _init() -> void:
	id_partie = nouvel_id()


static func nouvel_id() -> String:
	return "%d-%04d" % [int(Time.get_unix_time_from_system()), randi() % 10000]


func clear() -> void:
	id_partie = nouvel_id()
	cameras.clear()
	next_cam = 1
	enregistrer = true
	intervalle = 1
	qualite = "standard"
	changed.emit()


# --- Caméras ---------------------------------------------------------------------

func camera(cid: int) -> Dictionary:
	for c in cameras:
		if int(c.id) == cid:
			return c
	return {}


## Ajoute une caméra fixe. Renvoie son id (−1 s'il y en a déjà MAX_CAMERAS).
func ajouter_camera(nom: String, xform: Transform3D, fov := 50.0, format := "paysage", vid := -1) -> int:
	if cameras.size() >= MAX_CAMERAS:
		message.emit("Time-lapse : %d caméras au plus. Supprimez-en une d'abord." % MAX_CAMERAS)
		return -1
	var c := {"id": next_cam, "nom": nom, "vid": vid, "format": format if FORMATS.has(format) else "paysage",
		"actif": true, "images": []}
	_poser(c, xform, fov)
	next_cam += 1
	cameras.append(c)
	changed.emit()
	return int(c.id)


func _poser(c: Dictionary, xform: Transform3D, fov: float) -> void:
	var o := xform.origin
	var e := xform.basis.get_euler()
	c["pos"] = [snappedf(o.x, 0.01), snappedf(o.y, 0.01), snappedf(o.z, 0.01)]
	c["rot"] = [snappedf(e.x, 0.0001), snappedf(e.y, 0.0001), snappedf(e.z, 0.0001)]
	c["fov"] = clampf(fov, 8.0, 110.0)


static func xform_de(c: Dictionary) -> Transform3D:
	var p: Array = c.get("pos", [0, 0, 0])
	var r: Array = c.get("rot", [0, 0, 0])
	var b := Basis.from_euler(Vector3(float(r[0]), float(r[1]), float(r[2])))
	return Transform3D(b, Vector3(float(p[0]), float(p[1]), float(p[2])))


## Change le cadrage (les images déjà prises restent).
func recadrer(cid: int, xform: Transform3D, fov: float) -> void:
	var c := camera(cid)
	if c.is_empty():
		return
	_poser(c, xform, fov)
	changed.emit()


func set_actif(cid: int, on: bool) -> void:
	var c := camera(cid)
	if not c.is_empty():
		c.actif = on
		changed.emit()


func renommer(cid: int, nom: String) -> void:
	var c := camera(cid)
	if not c.is_empty() and nom.strip_edges() != "":
		c.nom = nom.strip_edges()
		changed.emit()


## Supprime la caméra et ses images.
func supprimer(cid: int) -> void:
	var c := camera(cid)
	if c.is_empty():
		return
	effacer_images(cid)
	cameras.erase(c)
	changed.emit()


func effacer_images(cid: int) -> void:
	var c := camera(cid)
	if c.is_empty():
		return
	var d := dossier_camera(c)
	var dir := DirAccess.open(d)
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(d)
	(c.images as Array).clear()
	changed.emit()


## Vue d'ensemble d'un village : de biais, à 300 m, la Maison de commune au centre.
func camera_village(vid: int) -> int:
	if communes == null or not communes.villages.has(vid):
		return -1
	for c in cameras:
		if int(c.get("vid", -1)) == vid:
			return int(c.id)
	var v: Dictionary = communes.villages[vid]
	var centre: Vector2 = v.get("c", Vector2.ZERO)
	var h := 0.0
	if world != null:
		var g := world.cell_height(Vector2i(floori(centre.x), floori(centre.y)))
		if not is_nan(g):
			h = maxf(g, 0.0)
	var cible := Vector3(centre.x, h, centre.y)
	var xf := vue_de_biais(cible, 300.0, 38.0, deg_to_rad(35.0))
	if world != null:
		var g2 := world.cell_height(Vector2i(floori(xf.origin.x), floori(xf.origin.z)))
		if not is_nan(g2) and xf.origin.y < g2 + 40.0:
			xf = Transform3D(Basis(), Vector3(xf.origin.x, g2 + 40.0, xf.origin.z)).looking_at(cible, Vector3.UP)
	return ajouter_camera("Village de %s" % String(v.get("nom", "?")), xf, 50.0, "paysage", vid)


static func vue_de_biais(cible: Vector3, distance: float, inclinaison_deg: float, cap: float) -> Transform3D:
	var p := deg_to_rad(inclinaison_deg)
	var dir := Vector3(sin(cap), 0.0, cos(cap))
	var pos := cible + dir * cos(p) * distance + Vector3.UP * sin(p) * distance
	return Transform3D(Basis(), pos).looking_at(cible, Vector3.UP)


## Un village vient d'être fondé : une caméra le filme dès le premier jour.
func on_fonde(vid: int) -> void:
	if cameras.size() >= MAX_CAMERAS:
		return
	var cid := camera_village(vid)
	if cid >= 0:
		message.emit("Time-lapse : « %s » est filmé depuis sa fondation, une image par jour (Maj+F4 pour revoir)." % String(camera(cid).nom))


## Ancienne partie sans time-lapse : une caméra par village, à partir d'aujourd'hui.
func adopter_villages() -> void:
	if communes == null:
		return
	for vid in communes.villages:
		if cameras.size() >= MAX_CAMERAS:
			break
		camera_village(int(vid))


# --- Fichiers --------------------------------------------------------------------

func dossier() -> String:
	return "user://timelapse".path_join(id_partie)


func dossier_camera(c: Dictionary) -> String:
	return dossier().path_join("c%d" % int(c.id))


func chemin_image(c: Dictionary, n: int) -> String:
	return dossier_camera(c).path_join("%05d.jpg" % n)


static func taille_images(format: String, q: String) -> Vector2i:
	var h: int = int(QUALITES.get(q, 720))
	var r: float = float(FORMATS.get(format, 16.0 / 9.0))
	if r >= 1.0:
		return Vector2i(roundi(h * r / 2.0) * 2, h)
	# Vertical : la même largeur que la hauteur d'une image paysage.
	return Vector2i(h, roundi(h / r / 2.0) * 2)


## Place prise sur le disque par les images d'une caméra (octets).
func poids(c: Dictionary) -> int:
	var total := 0
	var dir := DirAccess.open(dossier_camera(c))
	if dir == null:
		return 0
	for f in dir.get_files():
		var fa := FileAccess.open(dossier_camera(c).path_join(f), FileAccess.READ)
		if fa != null:
			total += fa.get_length()
	return total


# --- Enregistrement --------------------------------------------------------------

func jour_de(t: float) -> int:
	var off := ambiance.utc_offset() * 3600.0 if ambiance != null else 0.0
	return int(floorf((t + off) / 86400.0))


## Heure de la lumière affichée (heures locales).
func heure_lumiere() -> float:
	if ambiance == null:
		return 12.0
	return fposmod(ambiance.display_time() + ambiance.utc_offset() * 3600.0, 86400.0) / 3600.0


## Faut-il prendre l'image du jour pour cette caméra ?
func a_filmer(c: Dictionary) -> bool:
	if not enregistrer or not bool(c.get("actif", true)) or ambiance == null:
		return false
	var imgs: Array = c.images
	var now := ambiance.unix_time
	if not imgs.is_empty() and jour_de(now) - jour_de(float(imgs[-1].t)) < intervalle:
		return false
	# Vers midi, en plein jour (ou l'après-midi, faute de mieux : nuit polaire).
	var h := heure_lumiere()
	var lumiere := (h >= 11.0 and ambiance.night < 0.15) or (h >= 14.0 and h < 16.0)
	if not lumiere:
		return false
	if rig != null:
		var p: Array = c.pos
		if Vector2(rig.global_position.x - float(p[0]), rig.global_position.z - float(p[2])).length() > DISTANCE_MAX:
			return false
	return true


func _process(delta: float) -> void:
	_t_verif -= delta
	if _t_verif > 0.0 or _en_cours or cameras.is_empty():
		return
	_t_verif = 0.5
	for c in cameras:
		if a_filmer(c):
			filmer(c)
			return


## Prend l'image du jour d'une caméra (rendu à part, sans l'interface).
func filmer(c: Dictionary) -> bool:
	if _en_cours:
		return false
	_en_cours = true
	var img: Image = null
	if capturer.is_valid():
		img = capturer.call(c)
	else:
		img = await _rendre(c)
	_en_cours = false
	if img == null or img.is_empty() or not cameras.has(c):
		return false
	var imgs: Array = c.images
	var n := imgs.size()
	DirAccess.make_dir_recursive_absolute(dossier_camera(c))
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	if img.save_jpg(chemin_image(c, n), QUALITE_JPEG) != OK:
		return false
	imgs.append({"t": ambiance.unix_time if ambiance != null else 0.0, "hab": _habitants(c)})
	changed.emit()
	return true


func _habitants(c: Dictionary) -> int:
	var vid := int(c.get("vid", -1))
	if communes != null and vid >= 0 and communes.stats.has(vid):
		return int(communes.stats[vid].get("hab", 0))
	if communes != null and not communes.stats.is_empty():
		var s := 0
		for v in communes.stats:
			s += int(communes.stats[v].get("hab", 0))
		return s
	return population.persons.size() if population != null else 0


func _rendre(c: Dictionary) -> Image:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var principale := get_viewport().get_camera_3d()
	var sv := SubViewport.new()
	sv.size = taille_images(String(c.format), qualite)
	sv.world_3d = get_viewport().find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	sv.msaa_3d = get_viewport().msaa_3d
	sv.screen_space_aa = get_viewport().screen_space_aa
	sv.positional_shadow_atlas_size = 2048
	var cam := Camera3D.new()
	cam.fov = float(c.fov)
	cam.near = 0.5
	cam.far = 14000.0
	if principale != null:
		cam.environment = principale.environment
		cam.attributes = principale.attributes
		cam.far = principale.far
	sv.add_child(cam)
	add_child(sv)
	cam.global_transform = xform_de(c)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = sv.get_texture().get_image() if is_instance_valid(sv) else null
	sv.queue_free()
	return img


# --- Sauvegarde ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"id": id_partie, "cameras": cameras.duplicate(true), "next": next_cam,
		"enregistrer": enregistrer, "intervalle": intervalle, "qualite": qualite}


func from_dict(d: Dictionary) -> void:
	id_partie = String(d.get("id", nouvel_id()))
	cameras = (d.get("cameras", []) as Array).duplicate(true)
	for c in cameras:
		c.id = int(c.id)
		c.vid = int(c.get("vid", -1))
		if not c.has("images"):
			c.images = []
	next_cam = int(d.get("next", cameras.size() + 1))
	enregistrer = bool(d.get("enregistrer", true))
	intervalle = int(d.get("intervalle", 1))
	qualite = String(d.get("qualite", "standard"))
	changed.emit()
