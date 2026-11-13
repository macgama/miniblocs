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
	{"id": "reseaux", "titre": "Du courant et de l'eau",
		"texte": "Une maison sans eau ni électricité, c'est du camping (et tes fondateurs en ont assez). Pose une source d'électricité et une source d'eau près d'une route. Pour une petite caisse : une éolienne (3,2 M€) et un forage (1,5 M€). Les routes portent déjà les petits câbles et les tuyaux.",
		"touches": "B : Construire → Réseaux (éolienne, forage) · O : panneau des réseaux",
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
	if etape >= ETAPES.size() or faits.size() >= ETAPES.size():
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


func etape_courante() -> Dictionary:
	return ETAPES[etape] if actif and etape < ETAPES.size() else {}


func id_courant() -> String:
	return String(etape_courante().get("id", ""))


func numero() -> int:
	return etape + 1


func total() -> int:
	return ETAPES.size()


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
	action_requested.emit(id)


func _process(delta: float) -> void:
	if not actif or scene == null:
		return
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
	if id == "" or id == "fin":
		return
	if est_faite(id):
		message.emit("Tutoriel : « %s », c'est fait !" % String(etape_courante().titre))
		_suivante()


func _suivante() -> void:
	faits[id_courant()] = true
	etape += 1
	_avancer_aux_etapes_libres()
	if etape >= ETAPES.size():
		actif = false
		if ReglagesPartie.actuel != null:
			ReglagesPartie.actuel.tutoriel = false
	else:
		_debut_etape()
	changed.emit()


## Saute les étapes déjà faites ou sans objet (partie rechargée, réglages).
func _avancer_aux_etapes_libres() -> void:
	while etape < ETAPES.size():
		var id := String(ETAPES[etape].id)
		if id == "fin":
			return
		if faits.has(id) or sans_objet(id) or (_deja_faisable(id) and est_faite(id)):
			faits[id] = true
			etape += 1
		else:
			return


## Étapes qu'on ne peut pas sauter d'office (elles demandent un geste du joueur).
static func _deja_faisable(id: String) -> bool:
	return not ["camera", "fondateurs", "budget", "objectifs", "temps"].has(id)


func _debut_etape() -> void:
	_vus.clear()
	_cam0.clear()
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
			return bool(s.elec) and bool(s.eau)
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
	return false


## Où en est l'étape (texte court, ou "").
func progres() -> String:
	match id_courant():
		"route":
			return "Route tracée : %d / %d m" % [mini(roundi(metres_de_route()), int(ROUTE_M)), int(ROUTE_M)]
		"reseaux":
			var s := sources()
			return "Électricité : %s · Eau : %s" % ["oui" if s.elec else "pas encore", "oui" if s.eau else "pas encore"]
		"temps":
			return "Habitants logés : %d / %d" % [mini(loges(), LOGES), LOGES]
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


func batiments_de_cat(cats: Array) -> int:
	var n := 0
	var bs := _batiments()
	for bid in bs:
		var t := String(bs[bid].t)
		if Fondateurs.est_base_chantier(t):
			continue
		if cats.has(String(BuildingCatalog.get_type(t).get("cat", ""))):
			n += 1
	return n


## Sources d'électricité et d'eau posées (même en chantier).
func sources() -> Dictionary:
	var out := {"elec": false, "eau": false}
	var bs := _batiments()
	for bid in bs:
		var info := ReseauxTypes.info(String(bs[bid].t))
		var res := String(info.get("res", ""))
		if res == "elec" and (float(info.get("cap", 0.0)) > 0.0 or String(info.get("source", "")) != ""):
			out.elec = true
		elif res == "eau":
			out.eau = true
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


# --- Sauvegarde ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "actif": actif, "etape": etape, "faits": faits.keys(), "replie": replie}


func from_dict(d: Dictionary) -> void:
	actif = bool(d.get("actif", false))
	etape = clampi(int(d.get("etape", 0)), 0, ETAPES.size())
	faits.clear()
	for k in d.get("faits", []):
		faits[String(k)] = true
	replie = bool(d.get("replie", false))
	if etape >= ETAPES.size():
		actif = false
	if actif:
		_debut_etape()
	changed.emit()
