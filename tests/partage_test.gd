extends SceneTree
## Test du partage des créations : paquets .mbloc (écriture, lecture, fichiers
## abîmés ou d'une version future refusés), installation chez un autre joueur
## (modèle de l'Atelier, création en blocs, attraction dessinée), plans de site
## (zone lue avec bâtiments, allées, enclos, animaux, décors ; dépendances
## embarquées ; reposé tourné d'un quart de tour), atelier local (publier,
## recevoir du dossier d'échange, mises à jour), Steam Workshop avec une
## doublure de GodotSteam, menu Partage (onglets, Maj+W, Créer → 8).
## Usage : godot --headless --path . --script res://tests/partage_test.gd

var ok := true
const DOSSIER := "user://test_partage"


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Doublure du module GodotSteam : enregistre les appels, répond par les mêmes signaux.
class FauxSteam:
	extends Object
	signal item_created(result: int, file_id: int, accept_tos: bool)
	signal item_updated(result: int, accept_tos: bool)
	signal item_downloaded(result: int, file_id: int, app_id: int)
	var appels: Array = []
	var titre := ""
	var contenu := ""
	var abonnements: Dictionary = {}
	func createItem(_app: int, _type: int) -> void:
		appels.append("createItem")
		item_created.emit.call_deferred(1, 4242, false)
	func startItemUpdate(_app: int, fid: int) -> int:
		appels.append("startItemUpdate:%d" % fid)
		return 7
	func setItemTitle(_h: int, t: String) -> void:
		titre = t
	func setItemDescription(_h: int, _t: String) -> void:
		pass
	func setItemTags(_h: int, _t: Array, _a: bool) -> void:
		pass
	func setItemMetadata(_h: int, _m: String) -> void:
		pass
	func setItemContent(_h: int, d: String) -> void:
		contenu = d
	func setItemPreview(_h: int, _p: String) -> void:
		pass
	func submitItemUpdate(_h: int, _n: String) -> void:
		appels.append("submitItemUpdate")
		item_updated.emit.call_deferred(1, false)
	func getSubscribedItems() -> Array:
		return abonnements.keys()
	func getItemInstallInfo(fid: int) -> Dictionary:
		return {"ret": abonnements.has(fid), "folder": String(abonnements.get(fid, "")), "size": 0, "timestamp": 0}
	func unsubscribeItem(fid: int) -> void:
		abonnements.erase(fid)
	func run_callbacks() -> void:
		pass


func _run() -> void:
	Creations.persist = false
	BanqueModeles.persist = false
	PlansSites.persist = false
	Partage.persist = false
	BatimentsVie.chantiers = false
	_vider(DOSSIER)
	Partage.echange = DOSSIER
	Partage.local().root = DOSSIER.path_join("atelier_local")
	Partage.oublier()
	_check(not PartageSteam.disponible() and Partage.backend() is PartageLocal, "sans Steam : l'atelier local")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	await _frames(60)
	bs.unlimited_money = true
	bs.require_access = false
	var mob: Mobilier = scene.mobilier
	_check(scene.partage_panel != null and scene.outil_site != null, "menu Partage et outil des plans de site dans la scène")

	print("Paquet d'un modèle de l'Atelier :")
	var house := bs.place("hollandais__maison", Vector2i(-30, -10), 0)
	var conv := Conversion.open_interior(mob, house)
	var mid := String(BanqueModeles.save_plan(mob, String(conv.id), "Maison du test").get("id", ""))
	_check(mid != "" and BanqueModeles.has_model(mid), "modèle dans la banque")
	var mes := Partage.mes_creations()
	_check(mes.any(func(m: Dictionary) -> bool: return String(m.genre) == "modele" and String(m.id) == mid), "il apparaît dans « Partager »")
	var p := Partage.empaqueter("modele", mid, "Ma jolie maison", "Une maison hollandaise.", ["Pays-Bas", " brique "])
	_check(PaquetPartage.verifier(p) == "", "paquet valide")
	_check(PaquetPartage.cle(p) == "modele:" + mid and String(p.fiche.titre) == "Ma jolie maison", "clé et titre")
	_check((p.fiche.etiquettes as Array).has("Bâtiment") and (p.fiche.etiquettes as Array).has("brique"), "étiquettes : la sorte d'abord, espaces retirés")
	var path := DOSSIER.path_join("maison.mbloc")
	_check(PaquetPartage.ecrire_fichier(p, path), "fichier .mbloc écrit")
	var lu := PaquetPartage.lire_fichier(path)
	_check(lu.has("paquet") and JSON.stringify(lu.paquet.contenu.principal) == JSON.stringify(JSON.parse_string(JSON.stringify(p.contenu.principal))), "relu à l'identique")

	print("Fichiers refusés :")
	var f := FileAccess.open(DOSSIER.path_join("abime.mbloc"), FileAccess.WRITE)
	f.store_string("pas un zip")
	f.close()
	_check(PaquetPartage.lire_fichier(DOSSIER.path_join("abime.mbloc")).has("erreur"), "fichier abîmé")
	var futur := p.duplicate(true)
	futur.fiche.version = PaquetPartage.VERSION + 1
	PaquetPartage.ecrire_fichier(futur, DOSSIER.path_join("futur.mbloc"))
	_check(String(PaquetPartage.lire_fichier(DOSSIER.path_join("futur.mbloc")).get("erreur", "")).contains("récente"), "version plus récente du jeu")
	var bizarre := p.duplicate(true)
	bizarre.fiche.genre = "script"
	_check(PaquetPartage.verifier(bizarre) != "", "genre inconnu refusé")
	DirAccess.remove_absolute(DOSSIER.path_join("futur.mbloc"))

	print("Installé chez un autre joueur :")
	BanqueModeles.remove(mid)
	_check(not BanqueModeles.has_model(mid), "le modèle n'est plus là")
	var r := Partage.installer(lu.paquet)
	_check(r.ok and BanqueModeles.has_model(mid), "installé dans la banque")
	_check(not BuildingCatalog.get_type(ModelesJeu.catalog_id(mid)).is_empty(), "et dans le catalogue (Mes modèles)")
	_check(Partage.etat("modele:" + mid, float(lu.paquet.fiche.maj)) == "installe", "noté installé")
	_check(Partage.etat("modele:" + mid, float(lu.paquet.fiche.maj) + 100.0) == "maj", "une version plus récente propose « Mettre à jour »")

	print("Création en blocs et attraction :")
	var cid := "crea_test_partage"
	Creations.items[cid] = {"name": "Kiosque", "w": 3, "d": 3, "blocks": [0, 0, 0, 1, 1, 0, 1, 1, 2, 0, 2, 1, 1, 1, 1, 2], "cost": 5000}
	Creations._register(cid)
	var pc := Partage.empaqueter("creation", cid)
	_check(PaquetPartage.verifier(pc) == "" and String(pc.fiche.sorte) == "blocs", "paquet d'une création en blocs")
	Creations.items.erase(cid)
	_check(Partage.installer(pc).ok and Creations.items.has(cid) and Creations.ids().has(cid), "réinstallée dans Mes créations")
	var design: Dictionary = AttractionsPerso.modeles()[0].duplicate(true)
	design["id"] = "atr_test_99"
	AttractionsPerso.biblio()["atr_test_99"] = design
	var pa := Partage.empaqueter("attraction", "atr_test_99")
	_check(PaquetPartage.verifier(pa) == "" and String(pa.fiche.sorte) == "attraction", "paquet d'une attraction dessinée")
	AttractionsPerso.biblio().erase("atr_test_99")
	AttractionsPerso.designs.erase("atr_test_99")
	_check(Partage.installer(pa).ok and AttractionsPerso.biblio().has("atr_test_99"), "réinstallée dans Mes attractions")
	_check(not BuildingCatalog.get_type(AttractionsPerso.catalog_id("atr_test_99")).is_empty(), "sa gare est au catalogue")

	print("Plan de site :")
	var zoo: ZooSysteme = scene.zoo
	var al: ParcAllees = scene.parc_allees
	var dec: DecorSystem = scene.decors
	var o := Vector2i(100, 100)
	var b1 := bs.place(ModelesJeu.catalog_id(mid), o + Vector2i(10, 10), 1)
	var b2 := bs.place(cid, o + Vector2i(30, 8), 0)
	var b3 := bs.place("maison", o + Vector2i(40, 30), 2)
	_check(b1 > 0 and b2 > 0 and b3 > 0, "trois bâtiments posés (modèle, création, maison)")
	_check(al.ajoute_allee(Vector2(o.x + 5, o.y + 40), Vector2(o.x + 25, o.y + 40)), "une allée")
	var eid := zoo.ajouter_enclos(PackedVector2Array([Vector2(o.x + 5, o.y + 50), Vector2(o.x + 20, o.y + 50), Vector2(o.x + 20, o.y + 62), Vector2(o.x + 5, o.y + 62)]), "grillage")
	_check(eid >= 0 and zoo.acheter("zebre", eid) >= 0 and zoo.acheter("zebre", eid) >= 0, "un enclos et deux zèbres")
	_check(dec.pose("banc_bois", o.x + 30.5, o.y + 45.5, 0.3), "un banc")
	var ctx: Dictionary = scene.contexte_partage()
	var cap := PlansSites.capture(ctx, Rect2i(o, Vector2i(60, 70)), "Parc d'essai")
	_check(cap.ok, "zone enregistrée : %s" % String(cap.get("resume", cap.get("reason", ""))))
	var sid := String(cap.get("id", ""))
	var plan := PlansSites.get_plan(sid)
	_check((plan.batiments as Array).size() == 3 and (plan.allees as Array).size() >= 1, "bâtiments et allées lus")
	_check((plan.enclos as Array).size() == 1 and (plan.enclos[0].animaux as Array).size() == 2, "enclos et animaux lus")
	_check((plan.decors as Array).size() >= 1, "décors lus")
	_check(String(plan.sorte) == "zoo", "sorte : zoo (il y a un enclos)")
	_check(PlansSites.capture(ctx, Rect2i(Vector2i(-2000, -2000), Vector2i(10, 10)), "").ok == false, "zone vide refusée")
	_check(PlansSites.capture(ctx, Rect2i(o, Vector2i(500, 20)), "").ok == false, "zone trop grande refusée")
	var ps := Partage.empaqueter("site", sid)
	var deps: Dictionary = ps.contenu.dependances
	_check(deps.modeles.has(mid) and deps.creations.has(cid), "le paquet embarque le modèle et la création")

	print("Rotation :")
	_check(PlansSites.tourne(Vector2(3, 5), 60, 70, 4) == Vector2(3, 5), "quatre quarts de tour : retour au départ")
	_check(PlansSites.tourne(Vector2(0, 0), 60, 70, 1) == Vector2(70, 0), "un quart : (x, z) → (d − z, x)")
	for b: Dictionary in plan.batiments:
		var rr := PlansSites.rect_batiment(b, plan, Vector2i.ZERO, 1)
		_check(Rect2i(Vector2i.ZERO, PlansSites.taille(plan, 1)).encloses(rr), "%s tourné reste dans le plan" % String(b.t))

	print("Reposé ailleurs, chez un autre joueur :")
	PlansSites.remove(sid)
	BanqueModeles.remove(mid)
	_check(Partage.installer(ps).ok and not PlansSites.get_plan(sid).is_empty(), "plan installé")
	_check(BanqueModeles.has_model(mid) and PlansSites.manquants(PlansSites.get_plan(sid)).is_empty(), "ses dépendances aussi")
	var nb := bs.buildings.size()
	var ne := zoo.enclos.size()
	var na := zoo.animaux.size()
	var nal := al.allees.size()
	var nd := dec.nombre_poses()
	var res := PlansSites.poser(PlansSites.get_plan(sid), Vector2i(-300, 200), 1, ctx)
	_check(res.ok and int(res.refus) == 0, "posé tourné d'un quart (%d éléments, %d refus %s)" % [int(res.poses), int(res.refus), str(res.raisons)])
	_check(bs.buildings.size() == nb + 3, "trois bâtiments de plus")
	_check(zoo.enclos.size() == ne + 1 and zoo.animaux.size() == na + 2, "un enclos et deux zèbres de plus")
	_check(al.allees.size() > nal and dec.nombre_poses() > nd, "allée et banc reposés")
	var tourne_ok := false
	for bid in bs.buildings:
		var b: Dictionary = bs.buildings[bid]
		if String(b.t) == "maison" and int(b.x) < -200:
			tourne_ok = int(b.r) == 3
	_check(tourne_ok, "la maison a tourné avec le plan")
	var refus := PlansSites.poser(PlansSites.get_plan(sid), Vector2i(-300, 200), 1, ctx)
	_check(int(refus.refus) >= 3, "au même endroit : les bâtiments n'ont plus de place")

	print("Atelier local :")
	var publie := []
	var sur_publie := func(okp: bool, c: String, _i: String) -> void: publie.append([okp, c])
	Partage.local().publie.connect(sur_publie)
	_check(Partage.publier("site", sid, "Mon zoo", "Zèbres et banc.", ["savane"]) == "", "publier")
	_check(publie.size() == 1 and bool(publie[0][0]), "publié")
	Partage.local().publie.disconnect(sur_publie)
	var dispo := Partage.disponibles()
	_check(dispo.size() == 1 and String(dispo[0].fiche.titre) == "Mon zoo", "il apparaît dans « Découvrir »")
	_check(FileAccess.file_exists(DOSSIER.path_join("mon_zoo.mbloc")), "et en fichier .mbloc dans le dossier d'échange")
	_check(PartagePanel.filtrer(dispo, "zoo", "savane").size() == 1 and PartagePanel.filtrer(dispo, "parc", "").is_empty(), "filtres par sorte et recherche")
	Partage.local().retirer(dispo[0])
	_check(Partage.disponibles().is_empty(), "retiré de l'atelier local")
	var rec := Partage.recevoir_echange()
	_check(int(rec.nouveaux) == 2 and Partage.disponibles().size() == 2, "« Recevoir » lit les .mbloc du dossier d'échange (%d)" % int(rec.nouveaux))
	_check((rec.erreurs as Array).size() == 1, "et signale le fichier abîmé")
	_check(int(Partage.recevoir_echange().nouveaux) == 0, "pas deux fois le même")
	var zoo_dispo: Dictionary = Partage.disponibles().filter(func(e: Dictionary) -> bool: return String(e.fiche.genre) == "site")[0]
	PlansSites.remove(sid)
	Partage.oublier()
	_check(Partage.installer_objet(zoo_dispo).ok and not PlansSites.get_plan(sid).is_empty(), "installé depuis « Découvrir »")

	print("Steam Workshop (doublure de GodotSteam) :")
	var faux := FauxSteam.new()
	var st := PartageSteam.new()
	st.envoi = DOSSIER.path_join("steam_envoi")
	st.app_id = 480
	st.brancher(faux)
	Partage.set_backend(st)
	var fin := []
	st.publie.connect(func(okp: bool, _c: String, info: String) -> void: fin.append([okp, info]))
	Partage.publier("creation", cid, "Kiosque à musique")
	await _frames(4)
	_check(faux.appels.has("createItem") and faux.appels.has("startItemUpdate:4242") and faux.appels.has("submitItemUpdate"), "createItem, startItemUpdate, submitItemUpdate")
	_check(fin.size() == 1 and bool(fin[0][0]), "publié sur le Workshop : %s" % (String(fin[0][1]) if fin.size() > 0 else "?"))
	_check(faux.titre == "Kiosque à musique" and FileAccess.file_exists(ProjectSettings.localize_path(faux.contenu).path_join("fiche.json")), "titre et dossier de contenu envoyés")
	_check(int(Partage.publication("creation:" + cid).get("steam_id", 0)) == 4242, "id Workshop gardé pour les mises à jour")
	faux.appels.clear()
	Partage.publier("creation", cid, "Kiosque v2")
	await _frames(4)
	_check(not faux.appels.has("createItem") and faux.appels.has("startItemUpdate:4242"), "deuxième fois : mise à jour du même objet")
	# Un abonnement : Steam a téléchargé le dossier d'un autre joueur.
	var autre := PaquetPartage.nouveau("attraction", "atr_steam_1", design.merged({"id": "atr_steam_1", "nom": "Grand Huit Steam"}, true), "Grand Huit Steam")
	autre.fiche["sorte"] = "attraction"
	var dl := DOSSIER.path_join("steam_dl/1001")
	PaquetPartage.ecrire_dossier(autre, dl)
	faux.abonnements[1001] = ProjectSettings.globalize_path(dl)
	_check(Partage.synchroniser() == 1 and AttractionsPerso.biblio().has("atr_steam_1"), "abonnement installé tout seul")
	_check(Partage.synchroniser() == 0, "pas deux fois")
	_check(Partage.disponibles().any(func(e: Dictionary) -> bool: return String(e.source) == "steam"), "abonnements dans « Découvrir »")
	Partage.set_backend(Partage.local())
	st.steam = null
	faux.free()

	print("Menu Partage :")
	var hud: TerreHud = scene.hud
	var panel: PartagePanel = scene.partage_panel
	_check(Icones.has_icon("partage") and Icones.has_icon("telecharger") and Icones.has_icon("envoyer"), "icônes")
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.shift_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	_check(panel.is_open(), "Maj+W ouvre le menu")
	for v in ["partager", "sites", "decouvrir"]:
		panel.show_view(v)
		await _frames(2)
		_check(panel._body.get_child_count() > 2, "onglet %s rempli" % v)
	panel._form = "site:" + sid
	panel.show_view("partager")
	await _frames(2)
	_check(_cherche_type(panel._body, "TextEdit"), "formulaire de publication (titre, description, étiquettes)")
	panel.set_open(false)
	scene.set_create_mode(true)
	await _frames(2)
	_check(TerreHud.CREATE_KEYS.get(KEY_8, "") == "partage", "mode Créer : touche 8")
	hud._on_category("partage")
	await _frames(2)
	_check(panel.is_open() and not scene.build_panel.is_open(), "Créer → Partage ouvre le menu")
	scene.outil_site.choisir_zone()
	_check(scene.outil_site.actif() and scene._tool_busy(), "outil zone actif (Échap l'arrête d'abord)")
	scene._select_building_tool()
	_check(not scene.outil_site.actif(), "un autre outil le range")
	scene.set_create_mode(false)

	_vider(DOSSIER)
	Partage.set_backend(null)
	print("PARTAGE TEST OK" if ok else "PARTAGE TEST ÉCHEC")
	quit(0 if ok else 1)


func _cherche_type(n: Node, cls: String) -> bool:
	if n.get_class() == cls:
		return true
	for c in n.get_children():
		if _cherche_type(c, cls):
			return true
	return false


func _vider(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_vider(dir.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)
