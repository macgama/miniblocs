class_name Courrier
extends Node3D
## Courrier de la ville : les cartes postales laissées par les visiteurs (F12 →
## Ma ville). Section de sauvegarde « courrier ».
##
## Une carte arrive de deux façons :
##  - un fichier .mbloc de genre « carte » déposé dans le dossier d'échange
##    (user://partage) : relever() le range tout seul dans la partie à laquelle
##    il est adressé (même partie_id) et l'enlève du dossier ;
##  - par le serveur d'une carte entre amis (message « carte_postale »).
## Chaque carte est épinglée là où elle a été écrite : une petite carte postale au-dessus
## du sol (masqué avec « Montrer les cartes dans la ville »).
##
## Livre d'or : si le maire le veut (livre_or), les cartes reçues partent avec la
## ville partagée ; les visiteurs suivants les voient épinglées et dans F12.

signal arrivee(carte: Dictionary)
signal change

const MAX_CARTES := 300
## Côté maximal de la photo d'une carte (pixels) et taille maximale en base64.
const PHOTO_MAX := Vector2i(480, 270)
const PHOTO_OCTETS := 200000
const RELEVE := 15.0

var world: TerrainWorld
## Rend l'identifiant de la partie en cours (partie_id de sa fiche), ou "".
var ma_partie: Callable
## Cartes reçues (la plus ancienne d'abord).
var recues: Array = []
## Cartes lues (id -> true).
var lues: Dictionary = {}
## Les cartes reçues partent avec la ville partagée (livre d'or).
var livre_or := true
## Mot d'accueil du maire pour les visiteurs.
var accueil := ""
## Cartes épinglées dans la ville.
var montrer := true
## En visite : cartes que j'ai écrites ici (pas sauvegardées dans la ville).
var posees: Array = []
var _marques: Node3D
var _t := 0.0


func _ready() -> void:
	_marques = Node3D.new()
	_marques.name = "Marques"
	add_child(_marques)


func _process(delta: float) -> void:
	_t += delta
	if _t < RELEVE:
		return
	_t = 0.0
	if not VisiteVille.active() and Multijoueur.role == Multijoueur.Role.SOLO:
		relever()


# --- Cartes ---------------------------------------------------------------------------------

## Carte propre (champs bornés), ou {} si elle est illisible.
static func nettoyer(v: Variant) -> Dictionary:
	if not (v is Dictionary):
		return {}
	var c: Dictionary = v
	var id := String(c.get("id", "")).strip_edges()
	var texte := String(c.get("texte", "")).strip_edges()
	if id.length() < 8 or id.length() > 64 or texte == "":
		return {}
	var out := {"id": id.left(64), "de": String(c.get("de", "?")).strip_edges().replace("\n", " ").left(24),
		"de_id": String(c.get("de_id", "")).left(64), "pour": String(c.get("pour", "")).left(24),
		"partie": String(c.get("partie", "")).left(64), "ville": String(c.get("ville", "")).left(60),
		"texte": texte.left(VisiteVille.MAX_TEXTE), "x": float(c.get("x", 0.0)), "z": float(c.get("z", 0.0)),
		"quand": int(c.get("quand", 0)), "timbre": clampi(int(c.get("timbre", 0)), 0, VisiteVille.TIMBRES.size() - 1),
		"photo": ""}
	if not is_finite(out.x) or not is_finite(out.z) or absf(out.x) > 1e6 or absf(out.z) > 1e6:
		out.x = 0.0
		out.z = 0.0
	var cam: Variant = c.get("cam", {})
	if cam is Dictionary:
		var cc := {}
		for k in ["x", "z", "distance", "angle", "inclinaison"]:
			if (cam as Dictionary).has(k) and is_finite(float(cam[k])):
				cc[k] = float(cam[k])
		out["cam"] = cc
	var ph := String(c.get("photo", ""))
	if ph != "" and ph.length() <= PHOTO_OCTETS:
		out.photo = ph
	return out


static func photo_vers_texte(img: Image) -> String:
	if img == null or img.is_empty():
		return ""
	var i := img.duplicate() as Image
	if i.is_compressed():
		i.decompress()
	i.convert(Image.FORMAT_RGB8)
	var k := minf(float(PHOTO_MAX.x) / i.get_width(), float(PHOTO_MAX.y) / i.get_height())
	if k < 1.0:
		i.resize(maxi(int(i.get_width() * k), 1), maxi(int(i.get_height() * k), 1), Image.INTERPOLATE_BILINEAR)
	var s := Marshalls.raw_to_base64(i.save_jpg_to_buffer(0.8))
	return s if s.length() <= PHOTO_OCTETS else ""


## Photo d'une carte (null s'il n'y en a pas, ou si elle est abîmée).
static func photo_de(c: Dictionary) -> Image:
	var s := String(c.get("photo", ""))
	if s == "":
		return null
	var img := Image.new()
	var b := Marshalls.base64_to_raw(s)
	if b.is_empty() or (img.load_jpg_from_buffer(b) != OK and img.load_png_from_buffer(b) != OK) or img.is_empty():
		return null
	if img.get_width() > 1024 or img.get_height() > 1024:
		img.resize(PHOTO_MAX.x, PHOTO_MAX.y)
	return img


func partie() -> String:
	return String(ma_partie.call()) if ma_partie.is_valid() else ""


## Range une carte reçue. Rend vrai si elle est nouvelle.
func recevoir(v: Variant) -> bool:
	var c := nettoyer(v)
	if c.is_empty():
		return false
	for e in recues:
		if String(e.id) == String(c.id):
			return false
	recues.append(c)
	while recues.size() > MAX_CARTES:
		recues.pop_front()
	_refaire_marques()
	if not VisiteVille.active() and Multijoueur.role != Multijoueur.Role.SERVEUR:
		Succes.ajouter("cartes_recues")
	arrivee.emit(c)
	change.emit()
	return true


## Relève le dossier d'échange : les cartes adressées à cette partie entrent dans
## le courrier et quittent le dossier. Rend le nombre de cartes nouvelles.
func relever() -> int:
	var pid := partie()
	if pid == "":
		return 0
	var d := DirAccess.open(Partage.echange)
	if d == null:
		return 0
	var n := 0
	for f in d.get_files():
		if f.get_extension().to_lower() != PaquetPartage.EXTENSION or not f.begins_with("carte-postale"):
			continue
		var path := Partage.echange.path_join(f)
		var r := PaquetPartage.lire_fichier(path)
		if r.has("erreur"):
			continue
		var p: Dictionary = r.paquet
		if PaquetPartage.genre(p) != "carte" or String(p.fiche.get("partie", "")) != pid:
			continue
		var c: Dictionary = (p.contenu.principal as Dictionary).duplicate()
		var img: Variant = p.get("apercu")
		if img is Image:
			c["photo"] = photo_vers_texte(img)
		if recevoir(c):
			n += 1
		DirAccess.remove_absolute(path)
	return n


## Range un paquet « carte » (installé depuis Partage → Découvrir).
func recevoir_paquet(p: Dictionary) -> bool:
	if PaquetPartage.genre(p) != "carte":
		return false
	var c: Dictionary = (p.contenu.principal as Dictionary).duplicate()
	var img: Variant = p.get("apercu")
	if img is Image:
		c["photo"] = photo_vers_texte(img)
	return recevoir(c)


## En visite : la carte que je viens d'écrire, épinglée chez moi aussi.
func poser(c: Dictionary) -> void:
	var p := nettoyer(c)
	if not p.is_empty():
		posees.append(p)
		_refaire_marques()
		change.emit()


func retirer(id: String) -> void:
	for i in recues.size():
		if String(recues[i].id) == id:
			recues.remove_at(i)
			lues.erase(id)
			_refaire_marques()
			change.emit()
			return


func marquer_lue(id: String) -> void:
	if not lues.has(id):
		lues[id] = true
		change.emit()


func non_lues() -> int:
	var n := 0
	for c in recues:
		if not lues.has(String(c.id)):
			n += 1
	return n


func set_montrer(on: bool) -> void:
	montrer = on
	if _marques:
		_marques.visible = on


# --- Panneaux dans la ville -------------------------------------------------------------------

func _refaire_marques() -> void:
	if _marques == null:
		return
	for ch in _marques.get_children():
		ch.queue_free()
	for c in recues:
		_marque(c, Color(1.0, 0.86, 0.45))
	for c in posees:
		_marque(c, Color(0.55, 0.85, 1.0))
	_marques.visible = montrer


func _marque(c: Dictionary, couleur: Color) -> void:
	var x := float(c.get("x", 0.0))
	var z := float(c.get("z", 0.0))
	var h := 0.0
	if world != null and world.tiles != null:
		h = world.raw_height(x, z)
	# Une petite carte postale qui flotte au-dessus du sol, et le nom de l'expéditeur.
	var m := Node3D.new()
	m.position = Vector3(x, h + 8.0, z)
	m.set_meta("carte", String(c.get("id", "")))
	var s := Sprite3D.new()
	s.texture = Icones.get_icon("carte_postale", 64, couleur)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.fixed_size = true
	s.pixel_size = 0.0006
	s.no_depth_test = true
	s.render_priority = 2
	m.add_child(s)
	var l := Label3D.new()
	l.text = String(c.get("de", ""))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0007
	l.font_size = 28
	l.outline_size = 10
	l.modulate = couleur
	l.no_depth_test = true
	l.render_priority = 2
	l.offset = Vector2(0, -50)
	m.add_child(l)
	_marques.add_child(m)


func rafraichir() -> void:
	_refaire_marques()


# --- Sauvegarde ------------------------------------------------------------------------------

func clear() -> void:
	recues.clear()
	lues.clear()
	posees.clear()
	livre_or = true
	accueil = ""
	_refaire_marques()


func to_dict() -> Dictionary:
	return {"version": 1, "recues": recues.duplicate(true), "lues": lues.keys(), "livre_or": livre_or, "accueil": accueil,
		"montrer": montrer}


func from_dict(d: Dictionary) -> void:
	recues.clear()
	lues.clear()
	posees.clear()
	for v in d.get("recues", []):
		var c := nettoyer(v)
		if not c.is_empty():
			recues.append(c)
	for id in d.get("lues", []):
		lues[String(id)] = true
	livre_or = bool(d.get("livre_or", true))
	accueil = String(d.get("accueil", "")).left(VisiteVille.MAX_TEXTE)
	montrer = bool(d.get("montrer", true))
	# En visite : le livre d'or seulement si le maire l'a voulu.
	if VisiteVille.active() and not VisiteVille.en_ligne and not livre_or:
		recues.clear()
	_refaire_marques()


## Section pour la ville partagée : sans les cartes si le livre d'or est fermé.
func pour_partage() -> Dictionary:
	var d := to_dict()
	if not livre_or:
		d.recues = []
	d.lues = []
	return d
