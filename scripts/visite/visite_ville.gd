class_name VisiteVille
extends RefCounted
## Visiter la ville d'un autre joueur, sans y toucher, et lui laisser une carte postale.
##
## Deux façons de visiter (voir docs/visites.md) :
##  - un fichier : le maire « partage sa ville » (F12 → Ma ville). La partie entière
##    part dans un paquet .mbloc de genre « ville » (PaquetPartage) : les fichiers de
##    la sauvegarde, tels quels, en base64 dans contenu.json. On l'envoie à un ami
##    (courriel, Discord, clé USB) ou on le publie sur le Steam Workshop pour les
##    inconnus. Le visiteur l'ouvre (F12 → Visiter, ou menu principal) : la ville est
##    recopiée dans une partie cachée (user://parties/visite) et s'ouvre en visite ;
##  - en ligne : sur une carte entre amis, on entre en « visiteur » (pas de caisse,
##    pas de construction) et les cartes postales passent par le serveur.
##
## En visite : on se promène (caméra, vue au sol V, à bord E), on regarde les
## panneaux d'information, on photographie (F8) ; on ne construit rien, on ne
## règle rien, rien n'est sauvegardé et aucun succès ne se débloque. La copie est
## jetée à la fin : la ville du maire ne peut pas changer.
##
## Carte postale : un texte, un timbre, l'endroit (point et caméra) et une photo.
## Elle part en .mbloc de genre « carte » dans le dossier d'échange, adressée à la
## partie visitée (partie_id) : chez le maire, le courrier (Courrier) la range tout
## seul dans la bonne partie. Les cartes reçues peuvent rester visibles dans la
## ville partagée : c'est le livre d'or que voient les visiteurs suivants.

const DOSSIER := "user://visites"
## Bibliothèque des villes reçues (un dossier de paquet par ville).
static var dossier := DOSSIER
## Partie cachée où la ville visitée est recopiée (absente de la liste des parties).
const SLOT := "visite"
const TERRE := "res://scenes/terre.tscn"
const MAX_TEXTE := 500
const TIMBRES := ["Montagne", "Lac", "Clocher", "Tramway", "Soleil", "Stade"]

## Ville visitée : fiche du paquet (titre, auteur, partie, accueil…). Vide : pas de visite.
static var en_cours: Dictionary = {}
## Visiteur sur une carte entre amis (pas de caisse, pas de construction).
static var en_ligne := false
## Partie du joueur à rouvrir après la visite ("" : retour au menu).
static var retour_slot := ""
static var retour_lat := 0.0
static var retour_lon := 0.0
static var retour_nom := ""
## Faux en test : pas d'écran de chargement (la scène est ouverte à la main).
static var changer_scene := true


static func active() -> bool:
	return not en_cours.is_empty() or en_ligne


static func titre() -> String:
	return String(en_cours.get("ville", en_cours.get("titre", "")))


static func auteur() -> String:
	return String(en_cours.get("auteur", ""))


# --- Partager sa ville ----------------------------------------------------------------------

## Paquet « ville » de la partie sauvegardée slot. accueil : mot du maire aux visiteurs.
## Rend {} si la partie est illisible.
## remplacer : sections réécrites pour le partage (nom -> données), par exemple le
## courrier sans les cartes quand le livre d'or est fermé.
static func empaqueter(slot: String, accueil := "", titre_ := "", apercu: Image = null, remplacer: Dictionary = {}) -> Dictionary:
	var m := SaveGame.read_manifest(slot)
	if m.is_empty():
		return {}
	var dir := SaveGame.DIR.path_join(slot)
	var fichiers := {}
	var octets := 0
	var refaits := {}
	for nom in remplacer:
		var enc := _encoder(String(nom), remplacer[nom])
		if enc.is_empty():
			continue
		(m.sections as Dictionary)[nom] = enc.meta
		refaits[nom] = enc.octets
	for nom in (m.get("sections", {}) as Dictionary):
		var meta: Dictionary = m.sections[nom]
		var f := String(meta.get("fichier", ""))
		if f == "" or f.contains("/") or f.contains("\\") or f.contains(".."):
			continue
		var b: PackedByteArray
		if refaits.has(nom):
			b = refaits[nom]
		else:
			b = FileAccess.get_file_as_bytes(dir.path_join(f))
		if b.is_empty():
			continue
		octets += b.size()
		fichiers[f] = Marshalls.raw_to_base64(b)
	if not fichiers.has(String((m.sections as Dictionary).get("terrain", {}).get("fichier", "terrain.json.zst"))):
		return {}
	var fiche_partie := m.duplicate(true)
	for k in ["id", "auteur", "sauvegardes"]:
		fiche_partie.erase(k)
	var nom_ville := String(m.get("nom", slot))
	var lieu: Dictionary = m.get("lieu", {})
	if String(lieu.get("nom", "")) != "":
		nom_ville = String(lieu.nom).get_slice(",", 0)
	var principal := {"partie": fiche_partie, "fichiers": fichiers, "accueil": accueil.strip_edges().left(MAX_TEXTE)}
	if apercu == null:
		var tex := SaveGame.load_preview(slot)
		if tex != null:
			apercu = tex.get_image()
	var t := titre_.strip_edges()
	if t == "":
		t = nom_ville
	var p := PaquetPartage.nouveau("ville", String(m.get("partie_id", slot)), principal, t, {}, apercu)
	var r: Dictionary = m.get("resume", {})
	p.fiche["sorte"] = "ville"
	p.fiche["ville"] = nom_ville
	p.fiche["partie"] = String(m.get("partie_id", ""))
	p.fiche["resume"] = "%d habitants · %d bâtiments · %s de voies" % [int(r.get("habitants", 0)), int(r.get("batiments", 0)), String(r.get("reseau", "0 km"))]
	p.fiche["octets"] = octets
	p.fiche["etiquettes"] = ["Ville"]
	p.fiche["description"] = accueil.strip_edges().left(4000)
	return p


## Une section comme SaveGame.write l'écrit : {octets (le fichier compressé), meta}.
static func _encoder(nom: String, data: Variant) -> Dictionary:
	var text := JSON.stringify(data, "", true)
	var tmp := "user://visite_section.tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	f.store_string(text)
	f.close()
	var b := FileAccess.get_file_as_bytes(tmp)
	DirAccess.remove_absolute(tmp)
	var file := "%s.json.zst" % nom
	return {"octets": b, "meta": {"fichier": file, "version": int(SaveGame.SECTION_VERSIONS.get(nom, 1)),
		"octets": text.to_utf8_buffer().size(), "sha256": text.sha256_text()}}


## Fichier .mbloc de la ville dans le dossier d'échange. Rend le chemin ou "".
static func exporter(slot: String, accueil := "", titre_ := "", remplacer: Dictionary = {}) -> String:
	var p := empaqueter(slot, accueil, titre_, null, remplacer)
	if p.is_empty():
		return ""
	var t := String(p.fiche.titre).to_lower().validate_filename().replace(" ", "_").left(40)
	var path := Partage.echange.path_join("ville-%s.%s" % [t if t != "" else "ma-ville", PaquetPartage.EXTENSION])
	return path if PaquetPartage.ecrire_fichier(p, path) else ""


## Publie la ville sur le Steam Workshop (ou l'atelier local, avec son .mbloc). Rend "" ou l'erreur.
static func publier(slot: String, accueil := "", titre_ := "", remplacer: Dictionary = {}) -> String:
	var p := empaqueter(slot, accueil, titre_, null, remplacer)
	if p.is_empty():
		return "Partie introuvable : sauvegarde-la d'abord."
	Partage.noter_publication(PaquetPartage.cle(p), {"titre": String(p.fiche.titre), "cree": float(p.fiche.cree)})
	Partage.backend().publier(p)
	if Partage.backend().est_steam():
		Partage.local().publier(p)
	return ""


# --- Bibliothèque des villes reçues ---------------------------------------------------------

## Le contenu d'un paquet « ville » est-il sain ? Rend "" ou la raison.
static func verifier(p: Dictionary) -> String:
	if PaquetPartage.genre(p) != "ville":
		return "ce n'est pas une ville"
	var c: Dictionary = (p.get("contenu", {}) as Dictionary).get("principal", {})
	var partie: Variant = c.get("partie")
	var fichiers: Variant = c.get("fichiers")
	if not (partie is Dictionary) or not (fichiers is Dictionary):
		return "ville incomplète"
	if String((partie as Dictionary).get("format", "")) != SaveGame.FORMAT:
		return "ville illisible"
	if int((partie as Dictionary).get("version", 0)) > SaveGame.VERSION:
		return "ville d'une version plus récente du jeu"
	for f in fichiers:
		var s := String(f)
		if not s.ends_with(".json.zst") or s.contains("/") or s.contains("\\") or s.contains(".."):
			return "fichier de ville refusé (%s)" % s
		if not (fichiers[f] is String):
			return "ville abîmée"
	var secs: Variant = (partie as Dictionary).get("sections", {})
	if not (secs is Dictionary) or not (secs as Dictionary).has("terrain"):
		return "ville sans terrain"
	return ""


## Range une ville reçue dans la bibliothèque des visites. Rend {ok, error}.
static func ranger(p: Dictionary) -> Dictionary:
	var why := verifier(p)
	if why != "":
		return {"ok": false, "error": why}
	var dir := dossier.path_join(PaquetPartage.nom_dossier(PaquetPartage.cle(p)))
	if not PaquetPartage.ecrire_dossier(p, dir):
		return {"ok": false, "error": "la bibliothèque des visites ne s'écrit pas"}
	return {"ok": true, "dossier": dir}


## Villes reçues, la plus récente d'abord : [{fiche, dossier, cle}].
static func villes() -> Array:
	var out := []
	var d := DirAccess.open(dossier)
	if d == null:
		return out
	for n in d.get_directories():
		var p := PaquetPartage.lire_dossier(dossier.path_join(n), false)
		if p.is_empty() or String(p.fiche.get("genre", "")) != "ville":
			continue
		out.append({"fiche": p.fiche, "dossier": dossier.path_join(n), "cle": String(p.fiche.get("cle", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.fiche.get("maj", 0)) > float(b.fiche.get("maj", 0)))
	return out


static func retirer(dir: String) -> void:
	if dir.begins_with(dossier):
		PaquetPartage.supprimer_dossier(dir)


## Fait entrer les villes .mbloc du dossier d'échange. Rend {nouvelles, erreurs}.
static func recevoir_echange() -> Dictionary:
	var res := {"nouvelles": 0, "erreurs": []}
	var d := DirAccess.open(Partage.echange)
	if d == null:
		return res
	var connues := {}
	for v in villes():
		connues[String(v.cle)] = float(v.fiche.get("maj", 0.0))
	for f in d.get_files():
		if f.get_extension().to_lower() != PaquetPartage.EXTENSION:
			continue
		var path := Partage.echange.path_join(f)
		var r := PaquetPartage.lire_fichier(path)
		if r.has("erreur") or PaquetPartage.genre(r.get("paquet", {})) != "ville":
			continue
		var p: Dictionary = r.paquet
		var c := PaquetPartage.cle(p)
		if connues.has(c) and float(connues[c]) >= float(p.fiche.get("maj", 0.0)):
			continue
		var rr := ranger(p)
		if bool(rr.ok):
			res.nouvelles += 1
		else:
			(res.erreurs as Array).append("%s : %s" % [f, rr.error])
	return res


# --- La visite ------------------------------------------------------------------------------

## Recopie la ville du paquet dans la partie cachée « visite ». Rend "" ou l'erreur.
static func preparer(p: Dictionary) -> String:
	var why := verifier(p)
	if why != "":
		return why
	var c: Dictionary = p.contenu.principal
	var dir := SaveGame.DIR.path_join(SLOT)
	if DirAccess.dir_exists_absolute(dir):
		SaveGame.delete(SLOT)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return "dossier de visite impossible à créer"
	var fichiers: Dictionary = c.fichiers
	for f in fichiers:
		var b := Marshalls.base64_to_raw(String(fichiers[f]))
		if b.size() > PaquetPartage.MAX_OCTETS:
			return "ville trop grosse"
		var fa := FileAccess.open(dir.path_join(String(f)), FileAccess.WRITE)
		if fa == null:
			return "écriture impossible"
		fa.store_buffer(b)
		fa.close()
	var m: Dictionary = (c.partie as Dictionary).duplicate(true)
	m["nom"] = "Visite : " + String(p.fiche.get("titre", "ville"))
	var mf := FileAccess.open(dir.path_join(SaveGame.MANIFEST), FileAccess.WRITE)
	if mf == null:
		return "écriture impossible"
	mf.store_string(JSON.stringify(m, "\t", true))
	mf.close()
	var res := SaveGame.read(SLOT)
	if not bool(res.ok):
		return String(res.error)
	return ""


## Ouvre la visite d'une ville de la bibliothèque (dossier) ou d'un paquet.
## jeu : la partie en cours (sauvegardée d'abord, rouverte après la visite), ou null.
static func visiter(p: Dictionary, jeu: Node = null) -> String:
	var why := preparer(p)
	if why != "":
		return why
	retour_slot = ""
	if jeu != null and not active() and not GameStart.atelier:
		if jeu.has_method("save_game") and jeu.save_game():
			retour_slot = GameStart.slot_id
			retour_lat = jeu.world.origin_lat
			retour_lon = jeu.world.origin_lon
			retour_nom = GameStart.place_name
	var f: Dictionary = (p.fiche as Dictionary).duplicate()
	f["accueil"] = String((p.contenu.principal as Dictionary).get("accueil", ""))
	if not f.has("ville") or String(f.ville) == "":
		f["ville"] = String(f.get("titre", "ville"))
	en_cours = f
	en_ligne = false
	var m := SaveGame.read_manifest(SLOT)
	var lieu: Dictionary = m.get("lieu", {})
	GameStart.chosen = true
	GameStart.atelier = false
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.lat = float(lieu.get("lat", GameStart.lat))
	GameStart.lon = float(lieu.get("lon", GameStart.lon))
	GameStart.place_name = String(lieu.get("nom", ""))
	GameStart.load_slot = SLOT
	GameStart.slot_id = SLOT
	if changer_scene:
		EcranChargement.aller(TERRE, "Visite de " + titre())
	return ""


static func visiter_dossier(dir: String, jeu: Node = null) -> String:
	var p := PaquetPartage.lire_dossier(dir, true)
	if p.is_empty():
		return "ville illisible"
	p["apercu"] = PaquetPartage.apercu_dossier(dir)
	return visiter(p, jeu)


## Fin de la visite : retour à sa partie (si on venait d'une partie), sinon au menu.
static func terminer() -> void:
	var slot := retour_slot
	oublier()
	GameStart.load_slot = ""
	GameStart.slot_id = ""
	if not changer_scene:
		return
	if slot != "" and SaveGame.exists(slot):
		GameStart.chosen = true
		GameStart.lat = retour_lat
		GameStart.lon = retour_lon
		GameStart.place_name = retour_nom
		GameStart.load_slot = slot
		GameStart.slot_id = slot
		EcranChargement.aller(TERRE, retour_nom)
	else:
		EcranChargement.aller(MenuPrincipal.SCENE, "Retour au menu principal")


## Oublie la visite (et jette la copie de la ville).
static func oublier() -> void:
	en_cours = {}
	en_ligne = false
	retour_slot = ""
	if SaveGame.exists(SLOT):
		SaveGame.delete(SLOT)


# --- Ce qu'on ne fait pas en visite -------------------------------------------------------

## Panneaux et outils de la barre du bas permis en visite : tout ce qui se regarde.
const PERMIS := ["observer", "habitants", "infos", "cartes", "stats", "journal", "saisons", "photo", "souterrain",
	"avis", "trafic", "niveaux_vie", "tourisme", "parc", "zoo", "musee", "club", "spectacles", "urgences"]
## Raccourcis bloqués (touche logique ou physique) : construire, régler, sauvegarder.
const TOUCHES := [KEY_B, KEY_G, KEY_M, KEY_X, KEY_P, KEY_L, KEY_J, KEY_O, KEY_TAB, KEY_F5, KEY_F6, KEY_F9, KEY_F10]
## Avec Maj : ce qui se regarde reste permis (statistiques, niveaux de vie, trafic,
## saisons, loisirs, tourisme), le reste est bloqué.
const TOUCHES_MAJ_PERMISES := [KEY_I, KEY_N, KEY_L, KEY_R, KEY_G, KEY_Z, KEY_C, KEY_X, KEY_B, KEY_D, KEY_V, KEY_E, KEY_T, KEY_K,
	KEY_F8, KEY_SHIFT, KEY_W, KEY_A, KEY_S, KEY_Q]


static func categorie_verrouillee(id: String) -> bool:
	return active() and not PERMIS.has(id)


static func outil_verrouille(i: int) -> bool:
	return active() and i != 0


## Vrai si cette touche (non tapée dans un champ de texte) est bloquée en visite.
static func touche_verrouillee(k: InputEventKey) -> bool:
	if not active() or k == null or not k.pressed or k.echo or k.ctrl_pressed or k.alt_pressed:
		return false
	var codes := [k.keycode, k.physical_keycode]
	if k.shift_pressed:
		for c in codes:
			if c != KEY_NONE and (c in TOUCHES_MAJ_PERMISES):
				return false
		# Lettres et touches de fonction avec Maj : panneaux de gestion.
		var c0: int = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		return (c0 >= KEY_A and c0 <= KEY_Z) or (c0 >= KEY_F1 and c0 <= KEY_F12 and c0 != KEY_F8)
	for c in codes:
		if c != KEY_NONE and (c in TOUCHES):
			return true
	return false


const TEXTE_VERROU := "En visite, on regarde sans toucher : ici rien ne se construit ni ne se règle. Laisse plutôt une carte postale (F12) !"


# --- Cartes postales --------------------------------------------------------------------------

## Nouvelle carte postale écrite dans la ville visitée.
static func carte(texte: String, pos: Vector2, cam: Dictionary = {}, timbre := 0, photo: Image = null) -> Dictionary:
	var c := {"id": SaveGame.new_uuid(), "de": PaquetPartage.auteur(), "de_id": SaveGame.player_id(),
		"pour": auteur(), "partie": String(en_cours.get("partie", en_cours.get("id", ""))), "ville": titre(),
		"texte": texte.strip_edges().left(MAX_TEXTE), "x": snappedf(pos.x, 0.1), "z": snappedf(pos.y, 0.1),
		"cam": cam, "quand": int(Time.get_unix_time_from_system()), "timbre": clampi(timbre, 0, TIMBRES.size() - 1),
		"photo": ""}
	if photo != null and not photo.is_empty():
		c.photo = Courrier.photo_vers_texte(photo)
	return c


## Paquet .mbloc d'une carte postale.
static func paquet_carte(c: Dictionary) -> Dictionary:
	var img := Courrier.photo_de(c)
	var corps := c.duplicate()
	corps.erase("photo")
	var p := PaquetPartage.nouveau("carte", String(c.id), corps, "Carte postale de %s" % String(c.de), {}, img)
	p.fiche["sorte"] = "carte"
	p.fiche["partie"] = String(c.get("partie", ""))
	p.fiche["ville"] = String(c.get("ville", ""))
	p.fiche["description"] = String(c.get("texte", ""))
	return p


## Envoie une carte : fichier .mbloc dans le dossier d'échange (à faire passer au
## maire), et par le serveur si on visite une carte entre amis. Rend le chemin du fichier.
static func poster(c: Dictionary) -> String:
	var cl := Multijoueur.client_actif()
	if en_ligne and cl != null:
		var envoi := c.duplicate()
		# Par le réseau, une photo plus petite (un seul paquet).
		if String(envoi.get("photo", "")).length() > 60000:
			var img := Courrier.photo_de(c)
			if img != null:
				img.resize(320, 180, Image.INTERPOLATE_BILINEAR)
				envoi.photo = Courrier.photo_vers_texte(img)
		cl.envoyer_carte(envoi)
	_noter_envoyee(c)
	if en_ligne:
		return ""
	var v := String(c.get("ville", "ville")).to_lower().validate_filename().replace(" ", "_").left(30)
	var de := String(c.get("de", "")).to_lower().validate_filename().replace(" ", "_").left(20)
	var path := Partage.echange.path_join("carte-postale-%s-%s-%s.%s" % [v, de, String(c.id).left(6), PaquetPartage.EXTENSION])
	return path if PaquetPartage.ecrire_fichier(paquet_carte(c), path) else ""


static var envoyees_path := DOSSIER.path_join("envoyees.json")


static func _noter_envoyee(c: Dictionary) -> void:
	var l := envoyees()
	var copie := c.duplicate()
	copie.erase("photo")
	l.append(copie)
	DirAccess.make_dir_recursive_absolute(envoyees_path.get_base_dir())
	var f := FileAccess.open(envoyees_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(l.slice(-200), "\t"))


## Cartes postales déjà envoyées (sans les photos).
static func envoyees() -> Array:
	if not FileAccess.file_exists(envoyees_path):
		return []
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(envoyees_path))
	return v if v is Array else []
