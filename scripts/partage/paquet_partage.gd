class_name PaquetPartage
extends RefCounted
## Paquet de partage : une création (bâtiment de l'Atelier, musée, création en
## blocs, attraction, plan de site) prête à passer d'un joueur à l'autre.
##
## Sur le disque, un paquet est un dossier, la forme d'un objet du Steam
## Workshop (un dossier de contenu et une image d'aperçu) :
##   fiche.json    titre, description, auteur, genre, étiquettes, dates, clé
##   contenu.json  la création elle-même + ce dont elle a besoin (dépendances)
##   apercu.png    l'image de la vignette (facultative)
## Le fichier .mbloc, à envoyer à un ami, est ce même dossier zippé.
##
## En mémoire : {"fiche": {...}, "contenu": {"principal": {...},
## "dependances": {"modeles": {id: données}, "creations": {...}, "attractions": {...}}},
## "apercu": Image ou null}.
##
## Lecture prudente : uniquement du JSON et une image PNG, tailles bornées,
## genre et format vérifiés (un paquet ne peut contenir aucun script).

const FORMAT := "miniblocs-partage"
const VERSION := 1
const EXTENSION := "mbloc"
const FICHE := "fiche.json"
const CONTENU := "contenu.json"
const APERCU := "apercu.png"
## Taille maximale d'un fichier du paquet (octets).
const MAX_OCTETS := 24 * 1024 * 1024
const GENRES := ["modele", "creation", "attraction", "site"]


## Nouveau paquet. cle : "<genre>:<id de la création>".
static func nouveau(genre: String, id: String, principal: Dictionary, titre: String, deps: Dictionary = {}, apercu: Image = null) -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var fiche := {"format": FORMAT, "version": VERSION, "genre": genre, "cle": "%s:%s" % [genre, id], "id": id,
		"titre": titre, "description": "", "auteur": auteur(), "etiquettes": [], "cree": now, "maj": now,
		"jeu": String(VersionBuild.infos().get("version", ProjectSettings.get_setting("application/config/version", "")))}
	return {"fiche": fiche, "contenu": {"principal": principal, "dependances": _deps_propres(deps)}, "apercu": apercu}


static func _deps_propres(deps: Dictionary) -> Dictionary:
	return {"modeles": deps.get("modeles", {}), "creations": deps.get("creations", {}), "attractions": deps.get("attractions", {})}


## Pseudo du joueur (celui des parties entre amis), sinon le nom de session.
static func auteur() -> String:
	var p := Multijoueur.pseudo()
	if p.strip_edges() != "":
		return p.strip_edges()
	var n := OS.get_environment("USERNAME")
	if n == "":
		n = OS.get_environment("USER")
	return n if n != "" else "moi"


## Le paquet est-il lisible par cette version du jeu ? Rend "" ou la raison.
static func verifier(p: Dictionary) -> String:
	var f: Variant = p.get("fiche")
	var c: Variant = p.get("contenu")
	if not (f is Dictionary) or not (c is Dictionary):
		return "fichier incomplet"
	var fiche: Dictionary = f
	if String(fiche.get("format", "")) != FORMAT:
		return "ce n'est pas une création MiniBlocs"
	if int(fiche.get("version", 0)) > VERSION:
		return "créé avec une version plus récente du jeu"
	if not String(fiche.get("genre", "")) in GENRES:
		return "genre de création inconnu"
	if String(fiche.get("id", "")).strip_edges() == "" or String(fiche.get("cle", "")) == "":
		return "création sans identifiant"
	if not ((c as Dictionary).get("principal") is Dictionary):
		return "création vide"
	var deps: Variant = (c as Dictionary).get("dependances", {})
	if not (deps is Dictionary):
		return "dépendances illisibles"
	for k in ["modeles", "creations", "attractions"]:
		if not ((deps as Dictionary).get(k, {}) is Dictionary):
			return "dépendances illisibles"
	return ""


static func cle(p: Dictionary) -> String:
	return String((p.get("fiche", {}) as Dictionary).get("cle", ""))


static func genre(p: Dictionary) -> String:
	return String((p.get("fiche", {}) as Dictionary).get("genre", ""))


## Nom de dossier sûr pour une clé (« modele:maison_123 » → « modele-maison_123 »).
static func nom_dossier(c: String) -> String:
	var s := c.replace(":", "-").validate_filename().replace(" ", "_")
	return s.left(80) if s != "" else "creation"


# --- Dossier (forme Workshop) --------------------------------------------------------------

static func ecrire_dossier(p: Dictionary, dir: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return false
	if not _ecrire_texte(dir.path_join(FICHE), JSON.stringify(p.fiche, "\t", true)):
		return false
	if not _ecrire_texte(dir.path_join(CONTENU), JSON.stringify(p.contenu)):
		return false
	var img: Variant = p.get("apercu")
	if img is Image and not (img as Image).is_empty():
		(img as Image).save_png(dir.path_join(APERCU))
	return true


## Lit un dossier. Rend le paquet ({} si illisible). Avec contenu = false, seule
## la fiche est lue (listes de l'atelier : plus rapide).
static func lire_dossier(dir: String, contenu := true) -> Dictionary:
	var fiche: Variant = _lire_json(dir.path_join(FICHE))
	if not (fiche is Dictionary):
		return {}
	var p := {"fiche": fiche, "contenu": {"principal": {}, "dependances": {}}, "apercu": null, "dossier": dir}
	if contenu:
		var c: Variant = _lire_json(dir.path_join(CONTENU))
		if not (c is Dictionary):
			return {}
		p.contenu = c
		if verifier(p) != "":
			return {}
	elif String((fiche as Dictionary).get("format", "")) != FORMAT:
		return {}
	return p


static func apercu_dossier(dir: String) -> Image:
	var path := dir.path_join(APERCU)
	if not FileAccess.file_exists(path):
		return null
	var b := FileAccess.get_file_as_bytes(path)
	return _image_png(b)


# --- Fichier .mbloc (le dossier zippé) -----------------------------------------------------

static func ecrire_fichier(p: Dictionary, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var z := ZIPPacker.new()
	if z.open(path) != OK:
		return false
	_zip_entree(z, FICHE, JSON.stringify(p.fiche, "\t", true).to_utf8_buffer())
	_zip_entree(z, CONTENU, JSON.stringify(p.contenu).to_utf8_buffer())
	var img: Variant = p.get("apercu")
	if img is Image and not (img as Image).is_empty():
		_zip_entree(z, APERCU, (img as Image).save_png_to_buffer())
	z.close()
	return true


static func _zip_entree(z: ZIPPacker, nom: String, data: PackedByteArray) -> void:
	z.start_file(nom)
	z.write_file(data)
	z.close_file()


## Lit un .mbloc. Rend {"paquet": {...}} ou {"erreur": raison}.
static func lire_fichier(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"erreur": "fichier introuvable"}
	var z := ZIPReader.new()
	if z.open(path) != OK:
		return {"erreur": "fichier abîmé (ce n'est pas un .mbloc)"}
	var files := z.get_files()
	if not FICHE in files or not CONTENU in files:
		z.close()
		return {"erreur": "fichier incomplet"}
	var fiche: Variant = _json_zip(z, FICHE)
	var contenu: Variant = _json_zip(z, CONTENU)
	var img: Image = null
	if APERCU in files:
		var b := z.read_file(APERCU)
		if b.size() <= MAX_OCTETS:
			img = _image_png(b)
	z.close()
	if not (fiche is Dictionary) or not (contenu is Dictionary):
		return {"erreur": "fichier illisible"}
	var p := {"fiche": fiche, "contenu": contenu, "apercu": img}
	var why := verifier(p)
	if why != "":
		return {"erreur": why}
	return {"paquet": p}


static func _json_zip(z: ZIPReader, nom: String) -> Variant:
	var b := z.read_file(nom)
	if b.size() == 0 or b.size() > MAX_OCTETS:
		return null
	return JSON.parse_string(b.get_string_from_utf8())


# --- Petits outils -------------------------------------------------------------------------

static func _ecrire_texte(path: String, s: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(s)
	f.close()
	return true


static func _lire_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > MAX_OCTETS:
		return null
	return JSON.parse_string(f.get_as_text())


static func _image_png(b: PackedByteArray) -> Image:
	if b.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(b) != OK or img.is_empty():
		return null
	if img.get_width() > 1024 or img.get_height() > 1024:
		img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	return img


## Copie récursive d'un dossier (paquet reçu → atelier local).
static func copier_dossier(src: String, dst: String) -> bool:
	var d := DirAccess.open(src)
	if d == null:
		return false
	DirAccess.make_dir_recursive_absolute(dst)
	for f in d.get_files():
		if f in [FICHE, CONTENU, APERCU]:
			if d.copy(src.path_join(f), dst.path_join(f)) != OK:
				return false
	return true


static func supprimer_dossier(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)
