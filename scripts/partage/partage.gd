class_name Partage
extends RefCounted
## Partage des créations entre joueurs (menu Partage, Maj+W, ou Créer → 8).
##
## Ce qui se partage (genres de PaquetPartage) :
## - modele     : un bâtiment de la banque de l'Atelier (façade personnalisée
##                ou murs fins meublés, dont les musées) ;
## - creation   : une création en blocs (Mes créations) ;
## - attraction : une attraction dessinée dans l'éditeur du parc (grand-huit…) ;
## - site       : un plan de site (PlansSites) : parc, zoo, musée, quartier.
## Un paquet emporte ce dont il a besoin : un plan de site qui contient un
## modèle de l'Atelier, une création ou une attraction dessinée les embarque.
##
## Où ça va : backend() rend le Steam Workshop (PartageSteam) quand le jeu
## tourne sous Steam avec GodotSteam, sinon l'atelier local (PartageLocal). Les
## fichiers .mbloc du dossier d'échange (user://partage) passent toujours par
## l'atelier local : c'est ainsi qu'on s'échange des créations avant Steam.
##
## Registre (user://partage/registre.json) : ce qui est installé (clé → titre,
## genre, date de la version installée) et ce qu'on a publié (clé → date, id
## Steam), pour proposer « Mettre à jour ».

const ECHANGE := "user://partage"
## Dossier d'échange (autre dossier pour les tests).
static var echange := ECHANGE
const SORTES := {"batiment": "Bâtiment", "musee": "Musée", "blocs": "Création en blocs", "attraction": "Attraction",
	"parc": "Parc de loisirs", "zoo": "Zoo", "quartier": "Quartier"}
const SORTE_ICONES := {"batiment": "construire", "musee": "musee", "blocs": "creations", "attraction": "loisirs",
	"parc": "parc", "zoo": "zoo", "quartier": "village"}

## Faux en test : ni registre ni dossier d'échange sur le disque.
static var persist := true
static var _backend: PartageBackend
static var _local: PartageLocal
static var _registre: Dictionary = {}
static var _registre_lu := false


# --- Où ça va ---------------------------------------------------------------------------------

static func local() -> PartageLocal:
	if _local == null:
		_local = PartageLocal.new()
	return _local


static func backend() -> PartageBackend:
	if _backend == null:
		_backend = PartageSteam.new() if PartageSteam.disponible() else local()
	return _backend


## Pour les tests (ou un autre service plus tard).
static func set_backend(b: PartageBackend) -> void:
	_backend = b


# --- Registre ---------------------------------------------------------------------------------

static func _reg() -> Dictionary:
	if not _registre_lu:
		_registre_lu = true
		_registre = {"installes": {}, "publies": {}}
		if persist and FileAccess.file_exists(_registre_path()):
			var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(_registre_path()))
			if v is Dictionary:
				for k in ["installes", "publies"]:
					if (v as Dictionary).get(k) is Dictionary:
						_registre[k] = v[k]
	return _registre


static func _ecrire_reg() -> void:
	if not persist:
		return
	DirAccess.make_dir_recursive_absolute(echange)
	var f := FileAccess.open(_registre_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_reg(), "\t"))


static func _registre_path() -> String:
	return echange.path_join("registre.json")


static func installe(cle: String) -> Dictionary:
	return (_reg().installes as Dictionary).get(cle, {})


static func publication(cle: String) -> Dictionary:
	return (_reg().publies as Dictionary).get(cle, {})


static func noter_publication(cle: String, champs: Dictionary) -> void:
	var p: Dictionary = (_reg().publies as Dictionary).get(cle, {})
	p.merge(champs, true)
	p["quand"] = Time.get_unix_time_from_system()
	_reg().publies[cle] = p
	_ecrire_reg()


## Remet le registre à zéro (tests).
static func oublier() -> void:
	_registre = {"installes": {}, "publies": {}}
	_registre_lu = true
	if _local != null:
		_local.oublier_cache()


# --- Mes créations ----------------------------------------------------------------------------

## Tout ce que le joueur peut partager : [{genre, id, nom, detail, sorte}].
static func mes_creations() -> Array:
	var out := []
	for id in BanqueModeles.ids():
		var d := BanqueModeles.get_model(String(id))
		out.append({"genre": "modele", "id": String(id), "nom": String(d.get("nom", "?")), "detail": BanqueModeles.describe(d), "sorte": sorte_modele(d)})
	for id in Creations.ids():
		var c: Dictionary = Creations.items[id]
		out.append({"genre": "creation", "id": id, "nom": String(c.get("name", "?")),
			"detail": "%d blocs · %d × %d m" % [(c.blocks as Array).size() / 4, int(c.w), int(c.d)], "sorte": "blocs"})
	var bib := AttractionsPerso.biblio()
	for id in bib:
		var a: Dictionary = bib[id]
		out.append({"genre": "attraction", "id": String(id), "nom": String(a.get("nom", "?")),
			"detail": "%s · %d pièces" % [String(VoiePieces.famille(String(a.get("famille", "acier"))).get("nom", "")), (a.get("pieces", []) as Array).size()], "sorte": "attraction"})
	for id in PlansSites.ids():
		var p := PlansSites.get_plan(String(id))
		out.append({"genre": "site", "id": String(id), "nom": String(p.get("nom", "?")), "detail": PlansSites.resume(p), "sorte": String(p.get("sorte", "quartier"))})
	return out


static func sorte_modele(d: Dictionary) -> String:
	if String(d.get("usage", "")) == "musee" or BuildingCatalog.base_of(String(d.get("fonction", ""))).begins_with("musee"):
		return "musee"
	return "batiment"


static func nom_sorte(s: String) -> String:
	return String(SORTES.get(s, "Création"))


## Où trouver une création une fois installée.
static func ou_trouver(genre: String) -> String:
	match genre:
		"modele": return "Créer → Banque (6), et Construire → Mes modèles"
		"creation": return "Créer → Mes créations (5)"
		"attraction": return "Loisirs → Créer un parc (Maj+A), « Mes attractions »"
		"site": return "Partage → Plans de site"
	return "ton jeu"


# --- Empaqueter -------------------------------------------------------------------------------

static func _donnees(genre: String, id: String) -> Dictionary:
	match genre:
		"modele":
			var d := BanqueModeles.get_model(id)
			return d.duplicate(true) if not d.is_empty() else ModelesJeu.model_data(id).duplicate(true)
		"creation":
			Creations.ensure_loaded()
			if Creations.items.has(id):
				var c: Dictionary = (Creations.items[id] as Dictionary).duplicate(true)
				c.erase("hidden")
				return c
		"attraction":
			var a: Dictionary = AttractionsPerso.biblio().get(id, AttractionsPerso.designs.get(id, {}))
			if not a.is_empty():
				var copie := a.duplicate(true)
				copie["id"] = id
				return copie
		"site":
			return PlansSites.get_plan(id).duplicate(true)
	return {}


## Paquet prêt à publier ({} si la création est introuvable).
static func empaqueter(genre: String, id: String, titre := "", description := "", etiquettes: Array = []) -> Dictionary:
	var principal := _donnees(genre, id)
	if principal.is_empty():
		return {}
	var deps := {"modeles": {}, "creations": {}, "attractions": {}}
	var sorte := "batiment"
	var nom := ""
	var img: Image = null
	match genre:
		"modele":
			sorte = sorte_modele(principal)
			nom = String(principal.get("nom", ""))
			img = BanqueModeles.preview_image(id)
		"creation":
			sorte = "blocs"
			nom = String(principal.get("name", ""))
		"attraction":
			sorte = "attraction"
			nom = String(principal.get("nom", ""))
		"site":
			sorte = String(principal.get("sorte", "quartier"))
			nom = String(principal.get("nom", ""))
			var need := PlansSites.dependances(principal)
			for mid in need.modeles:
				var d := _donnees("modele", String(mid))
				if not d.is_empty():
					deps.modeles[String(mid)] = d
			for cid in need.creations:
				var c := _donnees("creation", String(cid))
				if not c.is_empty():
					deps.creations[String(cid)] = c
			for aid in need.attractions:
				var a := _donnees("attraction", String(aid))
				if not a.is_empty():
					deps.attractions[String(aid)] = a
	var p := PaquetPartage.nouveau(genre, id, principal, titre.strip_edges() if titre.strip_edges() != "" else nom, deps, img)
	var tags := [nom_sorte(sorte)]
	for t in etiquettes:
		var s := String(t).strip_edges()
		if s != "" and not s in tags and tags.size() < 10:
			tags.append(s.left(32))
	p.fiche.description = description.strip_edges().left(4000)
	p.fiche.etiquettes = tags
	p.fiche["sorte"] = sorte
	p.fiche["resume"] = _resume(genre, principal)
	# Garder la date de création à chaque nouvelle version.
	var pub := publication(PaquetPartage.cle(p))
	if pub.has("cree"):
		p.fiche.cree = float(pub.cree)
	return p


static func _resume(genre: String, d: Dictionary) -> String:
	match genre:
		"modele": return BanqueModeles.describe(d)
		"creation": return "%d blocs · %d × %d m" % [(d.get("blocks", []) as Array).size() / 4, int(d.get("w", 0)), int(d.get("d", 0))]
		"attraction": return "%s · %d pièces" % [String(VoiePieces.famille(String(d.get("famille", "acier"))).get("nom", "")), (d.get("pieces", []) as Array).size()]
		"site": return PlansSites.resume(d)
	return ""


## Publie sur le Workshop (ou l'atelier local). La réponse arrive par backend().publie.
static func publier(genre: String, id: String, titre := "", description := "", etiquettes: Array = []) -> String:
	var p := empaqueter(genre, id, titre, description, etiquettes)
	if p.is_empty():
		return "Création introuvable."
	var c := PaquetPartage.cle(p)
	noter_publication(c, {"titre": String(p.fiche.titre), "cree": float(p.fiche.cree)})
	backend().publier(p)
	if backend().est_steam():
		# Une copie locale aussi, avec son fichier .mbloc pour les amis hors Steam.
		local().publier(p)
	return ""


# --- Fichiers .mbloc ---------------------------------------------------------------------------

static func fichier_de(p: Dictionary) -> String:
	var t := String(p.fiche.get("titre", "")).to_lower().validate_filename().replace(" ", "_").left(40)
	if t == "":
		t = PaquetPartage.nom_dossier(PaquetPartage.cle(p))
	return echange.path_join("%s.%s" % [t, PaquetPartage.EXTENSION])


## Exporte une création en fichier .mbloc dans le dossier d'échange. Rend le chemin ou "".
static func exporter(genre: String, id: String) -> String:
	var p := empaqueter(genre, id)
	if p.is_empty():
		return ""
	var path := fichier_de(p)
	return path if PaquetPartage.ecrire_fichier(p, path) else ""


## Fait entrer dans l'atelier local les .mbloc du dossier d'échange (et
## importe les anciens .json de la banque). Rend {nouveaux, erreurs: [texte]}.
static func recevoir_echange() -> Dictionary:
	var res := {"nouveaux": 0, "erreurs": []}
	if echange == ECHANGE:
		res.nouveaux += BanqueModeles.import_shared()
	var d := DirAccess.open(echange)
	if d == null:
		return res
	var connus := {}
	for o in local().objets():
		connus[String(o.cle)] = float(o.fiche.get("maj", 0.0))
	for f in d.get_files():
		if f.get_extension().to_lower() != PaquetPartage.EXTENSION:
			continue
		var r := PaquetPartage.lire_fichier(echange.path_join(f))
		if r.has("erreur"):
			(res.erreurs as Array).append("%s : %s" % [f, r.erreur])
			continue
		var p: Dictionary = r.paquet
		var c := PaquetPartage.cle(p)
		if connus.has(c) and float(connus[c]) >= float(p.fiche.get("maj", 0.0)):
			continue
		if local().recevoir(p) != "":
			res.nouveaux += 1
	return res


## Lit un .mbloc n'importe où sur le disque (glisser-déposer, dialogue) et le
## range dans l'atelier local. Rend la clé, ou le texte d'erreur préfixé « ! ».
static func recevoir_fichier(path: String) -> String:
	var r := PaquetPartage.lire_fichier(path)
	if r.has("erreur"):
		return "!" + String(r.erreur)
	var c := local().recevoir(r.paquet)
	return c if c != "" else "!l'atelier local ne s'écrit pas"


static func dossier_echange() -> String:
	DirAccess.make_dir_recursive_absolute(echange)
	return ProjectSettings.globalize_path(echange)


# --- Découvrir et installer --------------------------------------------------------------------

## Créations disponibles (atelier local + abonnements Steam), sans doublon :
## [{cle, fiche, dossier, source, etat}] ; etat : "nouveau", "installe", "maj".
static func disponibles() -> Array:
	var vus := {}
	var out := []
	var sources := [local()]
	if backend() != local():
		sources.push_front(backend())
	for b in sources:
		for o in (b as PartageBackend).objets():
			if vus.has(String(o.cle)):
				continue
			vus[String(o.cle)] = true
			var e: Dictionary = o.duplicate()
			e["etat"] = etat(String(o.cle), float(o.fiche.get("maj", 0.0)))
			e["backend"] = b
			out.append(e)
	return out


static func etat(cle: String, maj: float) -> String:
	var i := installe(cle)
	if i.is_empty():
		return "nouveau"
	return "maj" if maj > float(i.get("maj", 0.0)) + 0.5 else "installe"


## Installe un paquet (dépendances d'abord). Rend {ok, error, ou, ids}.
static func installer(p: Dictionary, remplacer := true) -> Dictionary:
	var why := PaquetPartage.verifier(p)
	if why != "":
		return {"ok": false, "error": why}
	var fiche: Dictionary = p.fiche
	var genre := String(fiche.genre)
	var id := String(fiche.id)
	var principal: Dictionary = p.contenu.principal
	var deps: Dictionary = p.contenu.get("dependances", {})
	var img: Variant = p.get("apercu")
	# Ce dont la création a besoin, sans écraser ce que le joueur a déjà.
	for mid in (deps.get("modeles", {}) as Dictionary):
		BanqueModeles.install_data(deps.modeles[mid], null, false)
	for cid in (deps.get("creations", {}) as Dictionary):
		Creations.installer(String(cid), deps.creations[cid], false)
	for aid in (deps.get("attractions", {}) as Dictionary):
		_installer_attraction(String(aid), deps.attractions[aid], false)
	var ok := false
	match genre:
		"modele":
			ok = BanqueModeles.install_data(principal, img if img is Image else null, remplacer) != ""
		"creation":
			ok = Creations.installer(id, principal, remplacer)
		"attraction":
			ok = _installer_attraction(id, principal, remplacer)
		"site":
			ok = PlansSites.installer(principal, remplacer) != ""
	if not ok:
		return {"ok": false, "error": "contenu illisible par cette version du jeu"}
	_reg().installes[String(fiche.cle)] = {"titre": String(fiche.get("titre", "")), "genre": genre, "id": id,
		"maj": float(fiche.get("maj", 0.0)), "auteur": String(fiche.get("auteur", "")), "quand": Time.get_unix_time_from_system()}
	_ecrire_reg()
	return {"ok": true, "ou": ou_trouver(genre), "id": id, "genre": genre}


static func _installer_attraction(id: String, d: Dictionary, remplacer: bool) -> bool:
	if id == "" or not (d.get("pieces") is Array) or String(d.get("famille", "")) == "":
		return false
	if not VoiePieces.FAMILLES.has(String(d.famille)):
		return false
	if AttractionsPerso.biblio().has(id) and not remplacer:
		if not AttractionsPerso.designs.has(id):
			AttractionsPerso.register(AttractionsPerso.biblio()[id])
		return true
	var copie := d.duplicate(true)
	copie["id"] = id
	AttractionsPerso.register(copie)
	if persist:
		AttractionsPerso.biblio_enregistre(copie)
	else:
		AttractionsPerso.biblio()[id] = copie
	return true


## Installe un objet de disponibles().
static func installer_objet(o: Dictionary) -> Dictionary:
	var b: PartageBackend = o.get("backend", local())
	var p := b.lire(o)
	if p.is_empty():
		return {"ok": false, "error": "fichier illisible"}
	if p.get("apercu") == null:
		p["apercu"] = PaquetPartage.apercu_dossier(String(o.dossier))
	return installer(p, true)


## Steam : installe tout seul les abonnements nouveaux ou mis à jour. Rend le nombre.
static func synchroniser() -> int:
	if not backend().est_steam():
		return 0
	var n := 0
	for o in backend().objets():
		if etat(String(o.cle), float(o.fiche.get("maj", 0.0))) != "installe":
			if bool(installer_objet(o).get("ok", false)):
				n += 1
	return n
