class_name Tutoriel
extends Node
## Tutoriel guidé d'une première partie : une carte en haut à gauche de l'écran
## donne une étape à la fois (caméra, fondation du village, fondateurs, route,
## zonage, courant et eau, temps, emplois, école, budget, objectifs).
##
## - Chaque étape se valide toute seule quand le joueur l'a faite (une route
##   tracée, une zone posée, un panneau ouvert…). Une étape déjà faite est
##   sautée. « Passer » saute une étape, la croix arrête le tutoriel.
## - Optionnel : case « Tutoriel guidé » sur le globe et dans l'Admin (F10 →
##   Aide). Le relancer depuis l'Admin reprend à la première étape pas faite.
## - Les objectifs du pays (scripts/pays/objectifs.gd) restent la seule source
##   des missions et des rangs : la carte des objectifs (TutorielCarte) ne fait
##   que les résumer à l'écran.
## - Sauvegarde : section « tutoriel ».

signal changed
## Le joueur a cliqué sur le bouton d'action de l'étape (ouvrir un panneau,
## prendre un outil…) : la scène fait l'action.
signal action_requested(id: String)
signal message(text: String)

static var instance: Tutoriel

## Mètres de route à tracer pour valider l'étape « route ».
const ROUTE_M := 50.0
## Habitants logés (hors campement) pour valider l'étape « temps ».
const LOGES := 5
## Habitants à atteindre pour finir la démo (comme le rang de Village).
const CENT := 100

## Étapes, dans l'ordre. action : bouton de la carte (texte, id envoyé à la scène).
const ETAPES := [
	{"id": "camera", "titre": "Bienvenue, futur maire",
		"texte": "Te voilà sur une terre vierge : pas une route, pas une maison, pas même un panneau « Bienvenue ». Fais d'abord un petit tour du propriétaire.",
		"touches": "ZQSD ou flèches : se déplacer · molette : zoomer · A / E : tourner"},
	{"id": "fonder", "titre": "Fonder ton village",
		"texte": "Tout commence par une Maison de commune. Choisis un nom et un drapeau, puis pose-la sur un terrain plutôt plat. Pas besoin de route : c'est la première pierre (et la seule qui ne se plaindra pas du bruit).",
		"touches": "R : tourner · clic gauche : poser · clic droit : annuler",
		"action": ["Fonder mon village", "fonder"]},
	{"id": "fondateurs", "titre": "Tes fondateurs",
		"texte": "Une centaine de courageux plantent leurs tentes près de la mairie. Ce sont les ouvriers de tes premiers chantiers, puis tes premiers habitants dès qu'ils auront un toit. Les vivres ne dureront pas éternellement : jette un œil à leur campement.",
		"touches": "Maj + H : fondateurs et chantiers",
		"action": ["Voir les fondateurs", "fondateurs"]},
	{"id": "route", "titre": "Tracer une route",
		"texte": "Les maisons veulent une route devant la porte : personne n'aime rentrer à travers champs en pantoufles. Trace une route qui part de la Maison de commune.",
		"touches": "5 : outil Route · un clic par point · C : courbe · clic droit : finir",
		"action": ["Prendre l'outil Route", "route"]},
	{"id": "zone_r", "titre": "Zoner des logements",
		"texte": "Dans Construire, onglet Zonage, choisis « Résidentielle » et glisse le long de ta route. Les maisons pousseront toutes seules… enfin, avec tes ouvriers et ton argent.",
		"touches": "B : Construire → Zonage → Résidentielle · clic glissé",
		"action": ["Ouvrir le zonage", "zones"]},
	{"id": "reseaux", "titre": "Courant, eau et égouts",
		"texte": "Une maison sans eau ni électricité, c'est du camping (et tes fondateurs en ont assez). Pose une source d'électricité (raccordement au réseau national, éolienne, solaire…), une source d'eau (forage, ou captage près d'une rivière) et de quoi traiter les égouts (lagunage, station d'épuration), près d'une route. Bonne nouvelle : la première ville du pays reçoit le kit d'installation de l'État, et ses bons paient ces bâtiments, et même un dépôt de collecte pour les poubelles (détails : Maj+P). Les routes portent déjà les petits câbles et les tuyaux.",
		"touches": "B : Construire → Réseaux (et Déchets) · O : panneau des réseaux · Maj+P : bons du kit",
		"action": ["Ouvrir les réseaux", "reseaux"]},
	{"id": "temps", "titre": "Laisser le temps faire",
		"texte": "Les chantiers avancent au rythme de la vie, en semaine et en journée, comme les vrais. Accélère le temps et attends que les premières maisons soient habitées : tes fondateurs quittent la tente dès qu'un toit est prêt.",
		"touches": "Maj + T : vitesse suivante · T : pause",
		"action": ["Accélérer le temps", "temps"]},
	{"id": "emplois", "titre": "Du travail pour tous",
		"texte": "Des habitants sans travail finissent par partir, ou pire : par se plaindre à la mairie. Zone des commerces ou de l'industrie près des logements.",
		"touches": "B : Construire → Zonage → Commerciale ou Industrielle",
		"action": ["Ouvrir le zonage", "zones"]},
	{"id": "ecole", "titre": "Une école",
		"texte": "Les enfants grandissent vite, et pas toujours sagement. Construis une école reliée à la route : sans elle, ta ville ne deviendra jamais un Bourg.",
		"touches": "B : Construire → Services → École",
		"action": ["Ouvrir les services", "ecole"]},
	{"id": "budget", "titre": "Surveiller la caisse",
		"texte": "Impôts, dépenses, emprunts : tout est dans le budget. Si la caisse est à sec, un emprunt dépanne, mais il faudra le rembourser. Conseil d'ami : une caisse vide n'a jamais construit de pont.",
		"touches": "M : budget de la ville",
		"action": ["Ouvrir le budget", "budget"]},
	{"id": "objectifs", "titre": "Tes objectifs",
		"texte": "Le pays te confie des missions, avec une prime à la clé, et ta ville gagne des rangs : Hameau, Village, Bourg… Ils sont résumés sous cette carte. Ouvre le panneau pour le détail et les succès.",
		"touches": "Maj + J : objectifs, rangs et succès",
		"action": ["Ouvrir les objectifs", "objectifs"]},
	{"id": "fin", "titre": "Tu es maire !",
		"texte": "Le tutoriel s'arrête là, la ville continue. Fais-la grandir, garde les habitants contents et gagne les élections. Ils râleront quand même un peu : c'est comme ça qu'on sait qu'ils tiennent à leur ville.",
		"touches": "F1 : toutes les commandes · F10 : réglages (relancer le tutoriel)",
		"action": ["Terminer", "terminer"]},
]

## Démo guidée (menu principal → « Démo guidée ») : les étapes du tutoriel
## jusqu'aux objectifs, puis ces chapitres, puis le bilan. Environ 30 minutes.
const ETAPES_DEMO := [
	{"id": "vue_sol", "titre": "Descendre dans la rue", "demo": true,
		"texte": "Assez vu ta ville d'en haut, comme un pigeon. Descends à hauteur d'habitant : tu peux marcher, entrer dans les bâtiments ouverts et regarder les chantiers de près. V repasse d'une vue à l'autre, et te ramène dans ton fauteuil de maire.",
		"touches": "V : vue au sol (3e puis 1re personne) · ZQSD : marcher · souris : regarder",
		"action": ["Descendre dans la rue", "vue_sol"]},
	{"id": "loisirs", "titre": "Un coin pour souffler", "demo": true,
		"texte": "Travailler, dormir, recommencer : tes habitants méritent mieux. Pose un square, une place, une aire de jeux ou un terrain de sport près des maisons. Les gens contents votent mieux (c'est ce qu'on dit).",
		"touches": "B : Construire → Espaces publics, Loisirs ou Sport",
		"action": ["Ouvrir les espaces publics", "loisirs"]},
	{"id": "fete", "titre": "Une fête au village", "demo": true,
		"texte": "Rien ne soude un village comme un marché ou une fête avec des lampions. Organise-en un : clique sur l'endroit où poser les étals ou la scène, les habitants libres viendront à pied.",
		"touches": "I : Infos → Organiser · clic : poser · clic droit : annuler",
		"action": ["Organiser un marché ou une fête", "fete"]},
	{"id": "ligne", "titre": "Prendre le bus", "demo": true,
		"texte": "Pour qu'on se passe un peu de la voiture, pose deux arrêts de bus le long de tes routes, puis trace une ligne qui les relie. Les bus partent tout seuls ; leur bilan te dira si la ligne vaut le ticket.",
		"touches": "L : lignes et arrêts · outil Ligne : un clic par arrêt, clic droit pour finir",
		"action": ["Ouvrir les lignes", "ligne"]},
	{"id": "village", "titre": "Cent habitants", "demo": true,
		"texte": "Dernier défi de la démo : loger 100 habitants. Avec une majorité contente en plus, ton hameau deviendra un Village, avec une prime du pays. Logements, emplois, services : tout compte. Accélère le temps si tu es sûr de toi.",
		"touches": "Maj + J : ce qui manque · Maj + T : accélérer · Y : avis des habitants",
		"action": ["Voir ce qui manque", "objectifs"]},
	{"id": "fin_demo", "titre": "Fin de la démo", "demo": true,
		"texte": "Bravo, Monsieur le Maire (ou Madame) : la démo s'arrête ici, mais pas ta ville. Regarde ton bilan, puis continue à jouer aussi longtemps que tu veux.",
		"touches": "",
		"action": ["Voir mon bilan", "bilan"]},
]

## Parcours en cours : "" (tutoriel) ou "demo" (démo guidée).
var parcours := ""
## Démo : secondes réelles jouées (hors pause) et chiffres de départ.
var temps_demo := 0.0
var demo_finie := false
## Démo : jour de jeu du départ (Objectifs.jour()), -1 pas encore lu.
var jour0 := -1
## Marchés et fêtes organisés au début de l'étape « fete ».
var _fetes0 := 0
signal bilan_demande

## Scène Terre (pour lire l'état du jeu : communes, transport, zones…).
var scene: Node
var actif := false
## Indice de l'étape en cours dans ETAPES.
var etape := 0
## Étapes faites ou passées : id -> true.
var faits := {}
## Carte des objectifs repliée.
var replie := false
## Panneaux vus ouverts depuis le début de l'étape.
var _vus := {}
## Caméra au début de l'étape « camera ».
var _cam0 := {}
var _acc := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(s: Node) -> void:
	scene = s


func clear() -> void:
	parcours = ""
	jour0 = -1
	temps_demo = 0.0
	demo_finie = false
	actif = false
	etape = 0
	faits.clear()
	replie = false
	_vus.clear()
	_cam0.clear()
	changed.emit()


## Lance (ou relance) le tutoriel : reprend à la première étape pas faite.
func demarrer() -> void:
	if actif:
		return
	actif = true
	if etape >= etapes().size() or faits.size() >= etapes().size():
		faits.clear()
	etape = 0
	_avancer_aux_etapes_libres()
	_debut_etape()
	changed.emit()


func arreter() -> void:
	if not actif:
		return
	actif = false
	changed.emit()


func set_actif(on: bool) -> void:
	if on:
		demarrer()
	else:
		arreter()


## Étapes du parcours en cours.
func etapes() -> Array:
	if parcours != "demo":
		return ETAPES
	return _etapes_demo()


static var _cache_demo: Array = []


static func _etapes_demo() -> Array:
	if _cache_demo.is_empty():
		for e in ETAPES:
			if String(e.id) != "fin":
				_cache_demo.append(e)
		_cache_demo.append_array(ETAPES_DEMO)
	return _cache_demo


func est_demo() -> bool:
	return parcours == "demo"


## Lance la démo guidée (nouvelle partie depuis le menu principal).
func demarrer_demo() -> void:
	parcours = "demo"
	temps_demo = 0.0
	demo_finie = false
	jour0 = -1
	if _lire("objectifs") != null:
		jour0 = int(_lire("objectifs").jour())
	actif = false
	faits.clear()
	demarrer()


## Minutes jouées dans la démo.
func minutes_demo() -> int:
	return int(temps_demo / 60.0)


func etape_courante() -> Dictionary:
	return etapes()[etape] if actif and etape < etapes().size() else {}


func id_courant() -> String:
	return String(etape_courante().get("id", ""))


func numero() -> int:
	return etape + 1


func total() -> int:
	return etapes().size()


## Passe l'étape en cours (bouton « Passer »).
func passer() -> void:
	if not actif:
		return
	_suivante()


## Bouton d'action de l'étape.
func agir() -> void:
	var e := etape_courante()
	if e.is_empty() or not e.has("action"):
		return
	var id := String(e.action[1])
	if id == "terminer":
		_suivante()
		return
	if id == "bilan":
		# Le chapitre de fin compte comme fait dans le bilan (17 / 17).
		demo_finie = true
		faits[id_courant()] = true
		bilan_demande.emit()
		_suivante()
		return
	action_requested.emit(id)


func _process(delta: float) -> void:
	if not actif or scene == null:
		return
	if parcours == "demo":
		temps_demo += delta
		if jour0 < 0 and _lire("objectifs") != null:
			jour0 = int(_lire("objectifs").jour())
	_noter_panneaux()
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	verifier()


## Valide l'étape en cours si elle est faite (appelée deux fois par seconde).
func verifier() -> void:
	if not actif:
		return
	var id := id_courant()
	if id == "" or id == "fin" or id == "fin_demo":
		return
	if est_faite(id):
		message.emit("Tutoriel : « %s », c'est fait !" % String(etape_courante().titre))
		_suivante()


func _suivante() -> void:
	faits[id_courant()] = true
	etape += 1
	_avancer_aux_etapes_libres()
	if etape >= etapes().size():
		actif = false
		if ReglagesPartie.actuel != null:
			ReglagesPartie.actuel.tutoriel = false
	else:
		_debut_etape()
	changed.emit()


## Saute les étapes déjà faites ou sans objet (partie rechargée, réglages).
func _avancer_aux_etapes_libres() -> void:
	while etape < etapes().size():
		var id := String(etapes()[etape].id)
		if id == "fin" or id == "fin_demo":
			return
		if faits.has(id) or sans_objet(id) or (_deja_faisable(id) and est_faite(id)):
			faits[id] = true
			etape += 1
		else:
			return


## Étapes qu'on ne peut pas sauter d'office (elles demandent un geste du joueur).
static func _deja_faisable(id: String) -> bool:
	return not ["camera", "fondateurs", "budget", "objectifs", "temps", "vue_sol", "fete", "loisirs"].has(id)


func _debut_etape() -> void:
	_vus.clear()
	_cam0.clear()
	_fetes0 = fetes_organisees()
	var rig = _lire("rig")
	if rig != null:
		_cam0 = {"p": rig.position, "d": float(rig.get("_target_distance")), "r": float(rig.rotation_degrees.y)}


func _lire(prop: String) -> Variant:
	if scene == null:
		return null
	return scene.get(prop)


## Panneaux ouverts pendant l'étape (budget, objectifs, fondateurs).
func _noter_panneaux() -> void:
	for p in ["budget_panel", "objectifs_panel", "fondateurs_panel"]:
		var n = _lire(p)
		if n != null and n.has_method("is_open") and n.is_open():
			_vus[p] = true


## L'étape n'a pas lieu d'être avec ces réglages.
func sans_objet(id: String) -> bool:
	var r := ReglagesPartie.actuel
	match id:
		"fondateurs":
			var f = _lire("fondateurs")
			return r.fondateurs <= 0 or (f != null and _villages() > 0 and not bool(f.arrives))
		"reseaux":
			return not r.reseaux_obligatoires
	return false


func _villages() -> int:
	var c = _lire("communes")
	return 0 if c == null else (c.villages as Dictionary).size()


## L'étape est-elle faite ?
func est_faite(id: String) -> bool:
	match id:
		"camera":
			var rig = _lire("rig")
			if rig == null or _cam0.is_empty():
				return false
			var p: Vector3 = rig.position
			var p0: Vector3 = _cam0.p
			var d := float(rig.get("_target_distance"))
			var d0 := float(_cam0.d)
			return Vector2(p.x - p0.x, p.z - p0.z).length() > 25.0 or absf(d - d0) > maxf(8.0, d0 * 0.3) \
				or absf(angle_difference(deg_to_rad(float(rig.rotation_degrees.y)), deg_to_rad(float(_cam0.r)))) > deg_to_rad(20.0)
		"fonder":
			return _villages() > 0
		"fondateurs":
			return _vus.has("fondateurs_panel")
		"route":
			return metres_de_route() >= ROUTE_M
		"zone_r":
			return zones_de(["R"]) > 0
		"reseaux":
			var s := sources()
			return bool(s.elec) and bool(s.eau) and bool(s.egout)
		"temps":
			return loges() >= LOGES
		"emplois":
			return zones_de(["C", "I"]) > 0 or batiments_de_cat(["commerce", "industrie", "production"]) > 0
		"ecole":
			return batiments_de_type("ecole") > 0
		"budget":
			return _vus.has("budget_panel")
		"objectifs":
			return _vus.has("objectifs_panel")
		"vue_sol":
			var vs = scene.get_node_or_null("VueSol") if scene != null else null
			return vs != null and int(vs.vue) != 0
		"loisirs":
			# Posés par le joueur : les cafés et restaurants qui poussent dans les
			# zones commerciales (catégorie « loisirs ») ne comptent pas.
			return batiments_de_cat(["loisirs", "espaces", "sport", "parc"], true) > 0
		"fete":
			return fetes_organisees() > _fetes0
		"ligne":
			return lignes() > 0
		"village":
			return rang() >= 1 or habitants_ville() >= CENT
	return false


## Où en est l'étape (texte court, ou "").
func progres() -> String:
	match id_courant():
		"route":
			return "Route tracée : %d / %d m" % [mini(roundi(metres_de_route()), int(ROUTE_M)), int(ROUTE_M)]
		"reseaux":
			var s := sources()
			return "Électricité : %s · Eau : %s · Égouts : %s" % ["oui" if s.elec else "pas encore", "oui" if s.eau else "pas encore",
				"oui" if s.egout else "pas encore"]
		"temps":
			return "Habitants logés : %d / %d" % [mini(loges(), LOGES), LOGES]
		"ligne":
			return "Arrêts posés : %d · lignes : %d" % [arrets(), lignes()]
		"village":
			var hab := habitants_ville()
			var sat := satisfaction_ville()
			return "Habitants : %d / %d · satisfaction : %s" % [mini(hab, CENT), CENT, ("%d %%" % sat) if sat >= 0 else "pas encore de sondage"]
	return ""


# --- Lecture de l'état du jeu --------------------------------------------------------

func metres_de_route() -> float:
	var t = _lire("transport")
	if t == null:
		return 0.0
	var total := 0.0
	var net: TransportNetwork = t.network
	for id in net.edges:
		var e: Dictionary = net.edges[id]
		if TransportTypes.mode_of(String(e.t)) == TransportTypes.Mode.ROAD:
			total += float(e.len)
	return total


func zones_de(kinds: Array) -> int:
	var z = _lire("zones")
	if z == null:
		return 0
	var n := 0
	for id in z.zones:
		if kinds.has(String(z.zones[id].k)):
			n += 1
	return n


func _batiments() -> Dictionary:
	var b = _lire("buildings")
	return {} if b == null else b.buildings


func batiments_de_type(type_id: String) -> int:
	var n := 0
	var bs := _batiments()
	for bid in bs:
		if String(bs[bid].t) == type_id:
			n += 1
	return n


## hors_zones : sans les bâtiments qui ont poussé tout seuls dans une zone.
func batiments_de_cat(cats: Array, hors_zones := false) -> int:
	var n := 0
	var bs := _batiments()
	for bid in bs:
		var t := String(bs[bid].t)
		if Fondateurs.est_base_chantier(t):
			continue
		if hors_zones and int(bs[bid].get("zone", 0)) > 0:
			continue
		if cats.has(String(BuildingCatalog.get_type(t).get("cat", ""))):
			n += 1
	return n


## Sources d'électricité, d'eau et traitement des égouts posés (même en chantier).
func sources() -> Dictionary:
	var out := {"elec": false, "eau": false, "egout": false}
	var bs := _batiments()
	for bid in bs:
		var info := ReseauxTypes.info(String(bs[bid].t))
		var res := String(info.get("res", ""))
		if res == "elec" and (float(info.get("cap", 0.0)) > 0.0 or String(info.get("source", "")) != ""):
			out.elec = true
		elif res == "eau":
			out.eau = true
		elif res == "egout":
			out.egout = true
	# Sources branchées par d'autres systèmes (incinérateur…).
	var r = _lire("reseaux")
	if r != null and not (r.elec.sources as Dictionary).is_empty():
		out.elec = true
	return out


## Habitants qui ont un vrai toit (les fondateurs sous la tente ne comptent pas).
func loges() -> int:
	var p = _lire("population")
	if p == null:
		return 0
	var n: int = (p.persons as Dictionary).size()
	var f = _lire("fondateurs")
	if f != null:
		n -= int(f.au_campement())
	return maxi(n, 0)


## Marchés et fêtes organisés par le joueur depuis le début de la partie.
func fetes_organisees() -> int:
	var ev = _lire("evenements")
	return 0 if ev == null else int(ev.organises)


func lignes() -> int:
	var t = _lire("transport")
	if t == null or t.stations == null:
		return 0
	return (t.stations.lines as Dictionary).size()


func arrets() -> int:
	var t = _lire("transport")
	if t == null or t.stations == null:
		return 0
	return (t.stations.stations as Dictionary).size()


## Ville principale (celle que la caméra regarde, sinon la première).
func ville() -> int:
	var c = _lire("communes")
	if c == null or (c.villages as Dictionary).is_empty():
		return -1
	var p = _lire("pays")
	var vid := int(p.actif) if p != null else -1
	return vid if c.villages.has(vid) else int(c.principal())


func rang() -> int:
	var o = _lire("objectifs")
	var vid := ville()
	if o == null or vid < 0:
		return 0
	return int(o.palier_de(vid))


func habitants_ville() -> int:
	var o = _lire("objectifs")
	var vid := ville()
	if o == null or vid < 0:
		return 0
	return int(o._hab(vid))


func satisfaction_ville() -> int:
	var o = _lire("objectifs")
	var vid := ville()
	if o == null or vid < 0:
		return -1
	return int(o.satisfaction(vid))


## Chiffres du bilan de la démo.
func bilan() -> Dictionary:
	var out := {"minutes": minutes_demo(), "habitants": 0, "batiments": 0, "routes_km": metres_de_route() / 1000.0,
		"caisse": 0, "rang": "Hameau", "nom": "Ta ville", "etoiles": 0, "lignes": lignes(), "etapes": faits.size(),
		"total": etapes().size(), "jours": 0}
	var vid := ville()
	var o = _lire("objectifs")
	if vid >= 0 and o != null:
		out.habitants = int(o._hab(vid))
		out.rang = String(Objectifs.PALIERS[int(o.palier_de(vid))].nom)
		out.etoiles = int(o.etoiles())
		out.jours = maxi(int(o.jour()) - jour0, 0) if jour0 >= 0 else 0
		if o.pays != null:
			out.nom = String(o.pays.nom_de(vid))
	var n := 0
	var bs := _batiments()
	for bid in bs:
		if not Fondateurs.est_base_chantier(String(bs[bid].t)):
			n += 1
	out.batiments = n
	var bsys = _lire("buildings")
	if bsys != null:
		out.caisse = int(bsys.money)
	return out


# --- Sauvegarde ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "actif": actif, "etape": etape, "faits": faits.keys(), "replie": replie,
		"parcours": parcours, "temps_demo": temps_demo, "demo_finie": demo_finie, "jour0": jour0}


func from_dict(d: Dictionary) -> void:
	parcours = String(d.get("parcours", ""))
	temps_demo = float(d.get("temps_demo", 0.0))
	demo_finie = bool(d.get("demo_finie", false))
	jour0 = int(d.get("jour0", -1))
	actif = bool(d.get("actif", false))
	etape = clampi(int(d.get("etape", 0)), 0, etapes().size())
	faits.clear()
	for k in d.get("faits", []):
		faits[String(k)] = true
	replie = bool(d.get("replie", false))
	if etape >= etapes().size():
		actif = false
	if actif:
		_debut_etape()
	changed.emit()
