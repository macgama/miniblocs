class_name SuccesSuivi
extends Node
## Dans une partie : relève les chiffres de la ville toutes les 2 secondes et écoute
## les événements (incendies, démolitions, décès…) pour avancer les succès du joueur
## (Succes). Rien n'est sauvegardé dans la partie : les succès sont au joueur.
##
## Pas de succès sur le serveur d'une carte entre amis (personne ne joue devant),
## ni dans l'Atelier (pas de ville).

const PERIODE := 2.0

var scene: Node
var _acc := 0.0
var _pause_s := 0.0
## Fondation déjà vue (continent noté) : vid -> true.
var _fondations := {}
var actif := true


func setup(s: Node) -> void:
	scene = s
	actif = Multijoueur.role != Multijoueur.Role.SERVEUR and not GameStart.atelier
	if not actif:
		return
	Succes.charger()
	var ev = _lire("evenements")
	if ev != null:
		ev.incident_declare.connect(_on_incident)
	var pop = _lire("population")
	if pop != null:
		pop.person_died.connect(func(_pid: int, _home: int) -> void: Succes.ajouter("deces"))
	var b = _lire("buildings")
	if b != null:
		b.removed.connect(func(_bid: int) -> void:
			if b.mode == BuildingSystem.Mode.DEMOLISH:
				Succes.ajouter("demolitions"))
	var cm = _lire("communes")
	if cm != null:
		cm.fonde.connect(func(_vid: int) -> void: noter_continent())


func _on_incident(inc: Dictionary) -> void:
	match String(inc.get("type", "")):
		"incendie":
			Succes.ajouter("incendies")
		"tempete", "crue", "inondation":
			Succes.ajouter("catastrophes")


func _lire(prop: String) -> Variant:
	return scene.get(prop) if scene != null else null


func _process(delta: float) -> void:
	if not actif or scene == null:
		return
	# Pause café : le temps de la ville arrêté (vraies secondes, partie ouverte).
	var amb = _lire("ambiance")
	if amb != null and int(amb.speed_index) == 0:
		_pause_s += delta
		Succes.noter("pause_s", _pause_s)
	else:
		_pause_s = 0.0
	_acc += delta
	if _acc < PERIODE:
		return
	_acc = 0.0
	releve()


## Relève tous les chiffres d'un coup (appelé aussi par les tests).
func releve() -> void:
	var tuto = _lire("tutoriel")
	var b = _lire("buildings")
	var illimite: bool = b != null and bool(b.unlimited_money)
	Succes.argent_illimite = illimite
	if illimite:
		Succes.noter("argent_illimite", 1)
	if tuto != null:
		var hab: int = tuto.loges()
		Succes.noter("habitants", hab)
		Succes.noter("route_m", tuto.metres_de_route())
		Succes.noter("lignes", tuto.lignes())
		var n := 0
		var bs: Dictionary = tuto._batiments()
		for bid in bs:
			if not Fondateurs.est_base_chantier(String(bs[bid].t)):
				n += 1
		Succes.noter("batiments", n)
		Succes.noter("fetes", tuto.fetes_organisees())
		if tuto.demo_finie:
			Succes.noter("demo_finie", 1)
		if tuto.parcours == "" and not tuto.actif and tuto.faits.size() > 0 and tuto.etape >= tuto.etapes().size():
			Succes.noter("tutoriel_fini", 1)
		_chiffres_pays(hab)
	if b != null and not illimite:
		Succes.noter("caisse", float(b.money))
		if int(b.money) < 0:
			Succes.noter("dans_le_rouge", 1)
	var bud = _lire("budget")
	if bud != null:
		if bool(bud.tutelle):
			Succes.noter("tutelle", 1)
		Succes.noter("emprunts", (bud.emprunts as Array).size())
	var avis = _lire("avis")
	if avis != null:
		for v in avis.elections_villes:
			var e = avis.elections_villes[v]
			if e != null and e.actives() and not e.joueur_maire():
				Succes.noter("mairie_perdue", 1)
	var pop = _lire("population")
	if pop != null and pop.vie != null:
		# Compté par partie (CycleVie) : le joueur garde le meilleur total d'une partie.
		Succes.noter("naissances", float(pop.vie.totals.get("naissances", 0)))
	var amb = _lire("ambiance")
	if amb != null and int(amb.speed_index) == DayNight.SPEEDS.size() - 1:
		Succes.noter("vitesse_max", 1)
	var vs := scene.get_node_or_null("VueSol")
	if vs != null:
		if int(vs.vue) != 0:
			Succes.noter("vue_sol", 1)
		if vs.has_method("a_bord") and vs.a_bord():
			Succes.noter("a_bord", 1)
	var sout = _lire("souterrain")
	if sout != null and bool(sout.actif):
		Succes.noter("souterrain", 1)
	_loisirs()
	Succes.noter("creations", Creations.items.size())
	var h := int(Time.get_datetime_dict_from_system().hour)
	if h >= 3 and h < 5:
		Succes.noter("nuit_blanche", 1)
	# Succès des Objectifs (Maj+J) gagnés dans cette partie, ou dans une partie rechargée.
	var obj = _lire("objectifs")
	if obj != null:
		for id in obj.succes:
			Succes.debloquer(String(id))
	Succes.sauver_si_besoin()


func _chiffres_pays(hab: int) -> void:
	var st := Statistiques.instance
	if st == null or st.historique.is_empty():
		return
	var lieu := Statistiques.PAYS
	var cho := st.dernier(lieu, "chomage")
	if hab >= 500 and cho >= 0.0 and cho < 2.0:
		Succes.noter("plein_emploi", 1)
	if hab >= 1000 and st.dernier(lieu, "congestion") > 40.0:
		Succes.noter("bouchons", 1)
	if st.dernier(lieu, "recyclage") > 50.0:
		Succes.noter("recyclage", 1)
	Succes.noter("touristes", maxf(st.dernier(lieu, "touristes"), 0.0))
	Succes.noter("jours", float(st.dernier_jour() - st.premier_jour()))


func _loisirs() -> void:
	var zoo = _lire("zoo")
	if zoo != null:
		var esp := {}
		for aid in zoo.animaux:
			esp[String(zoo.animaux[aid].esp)] = true
		Succes.noter("especes_zoo", esp.size())
	var musee = _lire("musee")
	if musee != null:
		var n := 0
		for key in musee.list():
			if not String(key).begins_with("bat_"):
				n += int(musee.analyse(key).get("oeuvres", 0))
		Succes.noter("objets_musee", n)
	var clubs = _lire("clubs")
	if clubs is Dictionary:
		var fondes := 0
		var titres := 0
		for s in clubs:
			var c = clubs[s]
			if c != null and c.fonde():
				fondes += 1
				titres += (c.club.get("palmares", []) as Array).size()
		Succes.noter("clubs", fondes)
		Succes.noter("titres", titres)


## Continent du lieu de la partie, noté à chaque fondation de ville.
func noter_continent() -> void:
	var w = _lire("world")
	if w == null:
		return
	var c := continent(float(w.origin_lat), float(w.origin_lon))
	if c == "":
		return
	Succes.noter("continent_" + c, 1)
	var n := 0
	for k in Succes.stats:
		if String(k).begins_with("continent_") and float(Succes.stats[k]) > 0.0:
			n += 1
	Succes.noter("continents", n)


## Continent approximatif d'un point (boîtes simples, assez justes pour un succès).
static func continent(lat: float, lon: float) -> String:
	if lat < -60.0:
		return "antarctique"
	if lon >= -170.0 and lon < -25.0:
		return "amerique_nord" if lat > 12.0 else "amerique_sud"
	if lat < -10.0 and lon > 110.0 or lon > 165.0 or lon < -170.0:
		return "oceanie"
	if lon >= -25.0 and lon < 60.0:
		if lat > 36.0 or (lat > 30.0 and lon > 26.0 and lon < 45.0):
			return "europe" if lon < 45.0 or lat > 45.0 else "asie"
		if lat > 12.0 and lon > 34.0:
			return "asie"
		return "afrique"
	return "asie"
