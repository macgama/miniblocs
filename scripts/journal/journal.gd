class_name Journal
extends Node
## Le journal de la ville (F4, menu Infos) : chaque matin de jeu, une édition qui
## raconte la veille avec les vrais habitants comme personnages. Une à la une,
## articles, sports, brèves, carnet (naissances, mariages, décès), météo,
## micro-trottoir, petites annonces et chiffre du jour.
##
## Sources : nouvelles des événements (Evenements.actualite : incendies, tempêtes,
## épidémies, fêtes, marchés, politique, saisons…), résultats des clubs
## (ClubSport.resultat), étapes de vie (Population.etape_vie), villages fondés
## (Communes.fonde), et un passage quotidien sur les bâtiments (inaugurations,
## démolitions), les voies (ponts, routes) et les statistiques (paliers
## d'habitants, chômage, caisse, satisfaction, bouchons, poubelles, pollution).
##
## Le nom, la devise, le prix et une partie du vocabulaire suivent l'époque de la
## partie (JournalEpoques). Les textes sont gardés en modèles + arguments et se
## traduisent à l'affichage (Journal.texte).

signal edition_parue(ed: Dictionary)
signal changed

static var instance: Journal

## Éditions gardées (les plus anciennes partent).
const EDITIONS_MAX := 60
## Faits en attente gardés au plus (une journée très chargée).
const FAITS_MAX := 400
const PALIERS := [50, 100, 250, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 250000, 500000, 1000000]
## Catégories de bâtiments dont l'ouverture fait un article.
const NOTABLES := ["services", "sport", "loisirs", "spectacles", "tourisme", "parc", "zoo", "funeraire"]
## Logements assez grands pour faire parler d'eux.
const GRANDS_LOGEMENTS := 40
## Poids des genres de nouvelles (la une va au plus lourd).
const POIDS_GENRE := {"incendie": 8, "tempete": 7, "crue": 7, "epidemie": 7, "manifestation": 6, "politique": 6,
	"canicule": 5, "secheresse": 5, "neige": 4, "gel": 4, "fete": 4, "marche": 3, "ruine": 5, "reparation": 2,
	"saison": 2, "match": 1}
## Rubriques (titre affiché au-dessus de l'article).
const RUBRIQUES := {"ville": "Vie locale", "faits": "Faits divers", "meteo": "Météo et nature", "politique": "Politique",
	"sport": "Sports", "economie": "Économie", "travaux": "Travaux", "societe": "Société"}
const RUBRIQUE_GENRE := {"incendie": "faits", "ruine": "faits", "reparation": "faits", "tempete": "meteo", "crue": "meteo",
	"neige": "meteo", "secheresse": "meteo", "canicule": "meteo", "gel": "meteo", "saison": "meteo", "epidemie": "societe",
	"fete": "ville", "marche": "ville", "politique": "politique", "manifestation": "politique", "match": "sport"}

var population: Population
var evenements: Evenements
var avis: Avis
var statistiques: Statistiques
var buildings: BuildingSystem
var transport: TransportSystem
var communes: Communes
var saisons: Saisons
var ambiance: DayNight

## Éditions parues, de la plus ancienne à la plus récente.
var editions: Array = []
## Faits notés depuis la dernière édition.
var faits: Array = []
var numero := 0
## Édition du jour pas encore ouverte (pastille sur le bouton).
var non_lue := false
## Parution automatique chaque matin (coupée par les tests).
var auto := true
## Année imposée (vitrine, tests) ; 0 = l'année de la partie.
var annee_forcee := 0
## Pendant un chargement, rien n'est noté.
var ecoute := true

## Bâtiments notables déjà connus : bid → [nom, catégorie].
var _bat_vus := {}
## Plus grand id de tronçon déjà vu.
var _troncon_max := 0
## États des chiffres (pour n'écrire qu'au passage d'un seuil).
var _etats := {}
var _dernier_jour := -1
## Premier passage fait : ce qui existait déjà ne fait pas d'article.
var _inventaire := false
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(pop: Population, ev: Evenements, av: Avis, st: Statistiques, bs: BuildingSystem, tr: TransportSystem,
		cm: Communes, sa: Saisons, amb: DayNight) -> void:
	population = pop
	evenements = ev
	avis = av
	statistiques = st
	buildings = bs
	transport = tr
	communes = cm
	saisons = sa
	ambiance = amb
	if ev != null:
		ev.actualite.connect(_on_actualite)
	if pop != null:
		pop.etape_vie.connect(_on_etape)
	if cm != null:
		cm.fonde.connect(_on_fonde)


## Branche un club de sport (chaque sport a le sien).
func ecouter_club(c: ClubSport) -> void:
	if c != null and not c.resultat.is_connected(_on_resultat):
		c.resultat.connect(_on_resultat)


func clear() -> void:
	editions.clear()
	faits.clear()
	numero = 0
	non_lue = false
	_bat_vus.clear()
	_troncon_max = 0
	_etats.clear()
	_dernier_jour = -1
	_inventaire = false


# --- Date et époque ------------------------------------------------------------------

func jour() -> int:
	return int(population.now().day) if population != null else 0


func date() -> Dictionary:
	var d := {"year": 2026, "month": 1, "day": 1, "weekday": 4}
	if ambiance != null:
		d = ambiance.local_datetime()
	if annee_forcee > 0:
		d.year = annee_forcee
	return d


func annee() -> int:
	return int(date().year)


func epoque() -> Dictionary:
	return JournalEpoques.de_annee(annee())


func ville() -> String:
	return Avis.ville()


# --- Ce que le journal entend --------------------------------------------------------

func noter(f: Dictionary) -> void:
	if not ecoute:
		return
	faits.append(f)
	if faits.size() > FAITS_MAX:
		faits.remove_at(0)


static func _pos(v) -> Array:
	if v is Vector3 and (v as Vector3).is_finite():
		var p: Vector3 = v
		return [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]
	return []


static func pos_de(a) -> Vector3:
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.INF


func _on_actualite(n: Dictionary) -> void:
	noter({"k": "depeche", "genre": String(n.get("genre", "")), "texte": String(n.get("texte", "")),
		"ev": int(n.get("ev", -1)), "pos": _pos(n.get("pos", Vector3.INF))})


func _on_resultat(r: Dictionary) -> void:
	var f := r.duplicate()
	f.k = "match"
	noter(f)


func _on_etape(p: Dictionary, code: String, texte: String, ref: int) -> void:
	match code:
		"naissance":
			if not texte.begins_with("Naît à"):
				return
		"mariage", "deces", "sport":
			pass
		_:
			return
	# Un mariage est noté deux fois (un par époux) : on garde le premier.
	if code == "mariage":
		for f in faits:
			if String(f.k) == "carnet" and String(f.code) == "mariage" and int(f.ref) == int(p.id):
				return
	noter({"k": "carnet", "code": code, "pid": int(p.id), "nom": CycleVie.full_name(p), "age": population.age_years(p) if population != null else 0,
		"texte": texte, "ref": ref, "ref_nom": _nom_de(ref) if code == "mariage" else "", "f": String(p.get("s", "H")) == "F"})


func _nom_de(pid: int) -> String:
	if population != null and population.persons.has(pid):
		return CycleVie.full_name(population.persons[pid])
	return ""


func _on_fonde(vid: int) -> void:
	if communes == null or not communes.villages.has(vid):
		return
	noter({"k": "fondation", "nom": String(communes.villages[vid].nom), "vid": vid})


# --- Passage quotidien : bâtiments, voies, chiffres ------------------------------------

## Bâtiment qui mérite un article à son ouverture : [nom, catégorie] ou [].
func _notable(bid: int) -> Array:
	var b: Dictionary = buildings.buildings[bid]
	var ty := BuildingCatalog.get_type(String(b.t))
	if ty.is_empty():
		return []
	var cat := String(ty.get("cat", ""))
	if cat in NOTABLES or (cat == "logement" and int(ty.get("logements", 0)) >= GRANDS_LOGEMENTS):
		var nom := evenements.building_name(bid) if evenements != null else String(ty.get("name", "Bâtiment"))
		return [nom, cat]
	return []


func _ville_de(bid: int) -> String:
	if communes != null:
		var vid := communes.village_du_batiment(bid)
		if vid >= 0 and communes.villages.has(vid):
			return String(communes.villages[vid].nom)
	return ville()


func _scanner_batiments() -> void:
	if buildings == null:
		return
	var vus := {}
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		# Encore en chantier : l'inauguration attendra.
		if b.has("av") and float(b.av) < 1.0:
			if _bat_vus.has(bid):
				vus[bid] = _bat_vus[bid]
			continue
		if _bat_vus.has(bid):
			vus[bid] = _bat_vus[bid]
			continue
		var nt := _notable(int(bid))
		if nt.is_empty():
			continue
		vus[bid] = nt
		# La maison de commune a déjà son article (village fondé).
		if _inventaire and String(b.t) != "maison_commune":
			var ty := BuildingCatalog.get_type(String(b.t))
			noter({"k": "inauguration", "nom": String(nt[0]), "cat": String(nt[1]), "ville": _ville_de(int(bid)),
				"cout": int(ty.get("cost", 0)), "pos": _pos(evenements.building_pos(int(bid)) if evenements != null else Vector3.INF), "bid": int(bid)})
	if _inventaire:
		for bid in _bat_vus:
			if not buildings.buildings.has(bid):
				noter({"k": "demolition", "nom": String(_bat_vus[bid][0]), "cat": String(_bat_vus[bid][1])})
	_bat_vus = vus


func _scanner_voies() -> void:
	if transport == null:
		return
	var net := transport.network
	var nouveaux_m := 0.0
	var plus_grand := _troncon_max
	for eid in net.edges:
		if int(eid) <= _troncon_max:
			continue
		plus_grand = maxi(plus_grand, int(eid))
		if not _inventaire:
			continue
		var e: Dictionary = net.edges[eid]
		if TransportTypes.mode_of(String(e.t)) == TransportTypes.Mode.ROAD:
			nouveaux_m += float(e.len)
		var st: PackedByteArray = e.st
		var pont := false
		for s in st:
			if s == TransportTypes.Struct.BRIDGE:
				pont = true
				break
		if not pont:
			continue
		# Pont dont un bout ne mène nulle part (aucune autre voie au bout).
		var vide := net.degree(int(e.a)) <= 1 or net.degree(int(e.b)) <= 1
		var milieu: Vector3 = (e.pts as PackedVector3Array)[(e.pts as PackedVector3Array).size() / 2]
		noter({"k": "pont", "nulle_part": vide, "long": float(e.len), "pos": _pos(milieu)})
	if nouveaux_m >= 200.0:
		noter({"k": "routes", "m": nouveaux_m})
	_troncon_max = plus_grand


## Passe un état (« chômage élevé »…) à vrai ou faux ; vrai au moment du passage.
func _bascule(cle: String, actif: bool) -> bool:
	var avant := bool(_etats.get(cle, false))
	_etats[cle] = actif
	return actif and not avant and _inventaire


func _scanner_chiffres() -> void:
	var c := chiffres()
	if c.is_empty():
		return
	var hab := int(c.get("habitants", 0))
	var palier := 0
	for p in PALIERS:
		if hab >= p:
			palier = p
	if palier > int(_etats.get("palier", 0)):
		if _inventaire:
			noter({"k": "palier", "n": palier})
		_etats.palier = palier
	if hab < 30:
		return
	if c.has("chomage") and _bascule("chomage", float(c.chomage) > (12.0 if bool(_etats.get("chomage", false)) == false else 9.0)):
		noter({"k": "chomage", "v": float(c.chomage)})
	if c.has("caisse"):
		var rouge := int(c.caisse) < 0
		var etait := bool(_etats.get("caisse", false))
		if _bascule("caisse", rouge):
			noter({"k": "caisse_rouge", "v": int(c.caisse)})
		elif etait and not rouge and _inventaire:
			noter({"k": "caisse_verte", "v": int(c.caisse)})
	if c.has("satisfaction"):
		var s := int(c.satisfaction)
		if _bascule("sat_basse", s < (40 if not bool(_etats.get("sat_basse", false)) else 48)):
			noter({"k": "sat_basse", "v": s})
		if _bascule("sat_haute", s > (78 if not bool(_etats.get("sat_haute", false)) else 70)):
			noter({"k": "sat_haute", "v": s})
	if c.has("congestion") and _bascule("bouchons", float(c.congestion) > (35.0 if not bool(_etats.get("bouchons", false)) else 25.0)):
		noter({"k": "bouchons", "v": float(c.congestion)})
	if c.has("dechets") and _bascule("poubelles", int(c.dechets) > (20 if not bool(_etats.get("poubelles", false)) else 8)):
		noter({"k": "poubelles", "v": int(c.dechets)})
	if c.has("pollution") and _bascule("pollution", float(c.pollution) > (50.0 if not bool(_etats.get("pollution", false)) else 40.0)):
		noter({"k": "pollution", "v": float(c.pollution)})


## Chiffres du dernier relevé des statistiques pour tout le pays.
func chiffres() -> Dictionary:
	if statistiques == null or statistiques.historique.is_empty():
		return {}
	return (statistiques.historique[-1].d as Dictionary).get(Statistiques.PAYS, {})


func scanner() -> void:
	_scanner_batiments()
	_scanner_voies()
	_scanner_chiffres()
	_inventaire = true


func _process(_delta: float) -> void:
	if not auto or population == null:
		return
	var d := jour()
	if _dernier_jour < 0:
		_dernier_jour = d
		scanner()
		return
	if d != _dernier_jour and Etalement.libre():
		_dernier_jour = d
		scanner()
		publier()


# --- L'édition -------------------------------------------------------------------------

static func texte(t) -> String:
	if t is String:
		return Langue.t(t)
	var a: Array = t
	if a.is_empty():
		return ""
	if a[0] is Array:
		return texte(a[0])
	var modele := Langue.t(String(a[0]))
	if a.size() == 1:
		return modele
	var args := []
	for i in range(1, a.size()):
		args.append(Langue.t(String(a[i])))
	if modele.count("%") < args.size():
		return modele
	return modele % args


func _temoin(liste: Array, p_force := -1) -> Dictionary:
	if population == null or population.persons.is_empty() or liste.is_empty():
		return {}
	var p: Dictionary = {}
	if p_force >= 0 and population.persons.has(p_force):
		p = population.persons[p_force]
	else:
		var ids: Array = avis.echantillon(true, 40) if avis != null else population.persons.keys().slice(0, 40)
		if ids.is_empty():
			return {}
		p = population.persons[ids[_rng.randi() % ids.size()]]
	return {"pid": int(p.id), "nom": CycleVie.full_name(p), "age": population.age_years(p), "etape": population.stage_label(p),
		"texte": String(liste[_rng.randi() % liste.size()])}


func _article(rub: String, titre: Array, chapo: Array, corps: Array, imp: int, pos := [], temoin := {}, genre := "") -> Dictionary:
	return {"rub": rub, "genre": genre, "titre": titre, "chapo": chapo, "corps": corps, "imp": imp, "pos": pos, "temoin": temoin}


func _choisir(liste: Array) -> String:
	return JournalRedaction.choisir(_rng, liste, annee())


func _T(liste: Array, args := []) -> Array:
	return JournalRedaction.t_libre(_choisir(liste), args)


## Rédige les articles des faits notés (sans la page : voir publier).
func rediger() -> Dictionary:
	var R := JournalRedaction
	var v := ville()
	var articles := []
	var breves := []
	var sport_breves := []
	var carnet := {"naissance": [], "mariage": [], "deces": [], "sport": []}
	# Nouvelles groupées par événement (ou par genre sans événement).
	var groupes := {}
	var ordre := []
	for f in faits:
		match String(f.k):
			"depeche":
				var g := String(f.genre)
				if g == "match":
					sport_breves.append(String(f.texte))
					continue
				if not POIDS_GENRE.has(g):
					breves.append(String(f.texte))
					continue
				var cle := "ev:%d" % int(f.ev) if int(f.ev) >= 0 else "g:" + g
				if not groupes.has(cle):
					groupes[cle] = {"genre": g, "textes": [], "pos": []}
					ordre.append(cle)
				(groupes[cle].textes as Array).append(String(f.texte))
				if (groupes[cle].pos as Array).is_empty():
					groupes[cle].pos = f.pos
			"carnet":
				(carnet[String(f.code)] as Array).append(f)
	for cle in ordre:
		var gr: Dictionary = groupes[cle]
		var g := String(gr.genre)
		var textes: Array = gr.textes
		var corps := []
		# Le début et la fin de l'histoire (la dernière nouvelle fait le bilan).
		if textes.size() <= 3:
			for tx in textes:
				corps.append([tx])
		else:
			corps.append([textes[0]])
			corps.append([textes[textes.size() - 2]])
			corps.append([textes[-1]])
		var imp := int(POIDS_GENRE.get(g, 2)) + mini(textes.size(), 4)
		articles.append(_article(RUBRIQUE_GENRE.get(g, "ville"), _T(R.TITRES_GENRE.get(g, ["En bref"]), [v]),
			[_choisir(CHAPOS_DE(g))], corps, imp, gr.pos, _temoin(R.TEMOINS.get(g, [])), g))
	for f in faits:
		match String(f.k):
			"match":
				var issue := String(f.issue)
				var corps := [R.t(R.CORPS_MATCH, [String(f.texte)])]
				if bool(f.dom) and int(f.affluence) > 0:
					corps.append(R.t(R.CORPS_MATCH_DOM, [R.nombre(int(f.affluence))]))
				var imp := 4 + (2 if issue == "V" else 0) + (1 if int(f.affluence) > 2000 else 0)
				articles.append(_article("sport", _T(R.TITRES_MATCH.get(issue, R.TITRES_MATCH.N), [String(f.club)]),
					[_sport_nom(String(f.sport))], corps, imp, [], _temoin(R.PAROLE_MATCH.get(issue, [])), "match"))
			"inauguration":
				var cat := String(f.cat)
				var corps := [R.t(R.CORPS_INAUGURATION, [String(f.nom), String(f.ville)])]
				if int(f.cout) > 0:
					corps.append(R.t(R.CORPS_INAUGURATION_COUT, [BuildingSystem.format_money(int(f.cout))]))
				var imp := 5 + (2 if cat in ["services", "parc", "zoo", "spectacles"] else 0)
				articles.append(_article("travaux" if cat != "logement" else "ville", _T(R.TITRES_INAUGURATION.get(cat, R.TITRES_INAUGURATION.autre), [String(f.nom)]),
					[_choisir(R.CHAPO_INAUGURATION)], corps, imp, f.pos, _temoin(["C'était le moment, on l'attendait depuis longtemps.",
						"J'espère que ça ne coûtera pas trop cher en impôts.", "Mes petits-enfants vont adorer."])))
			"demolition":
				articles.append(_article("travaux", _T(R.TITRES_DEMOLITION, [String(f.nom)]), [_choisir(R.CHAPO_DEMOLITION)], [], 4))
			"pont":
				if bool(f.nulle_part):
					articles.append(_article("travaux", _T(R.TITRES_PONT_NULLE_PART, [v]), [_choisir(R.CHAPO_PONT_NULLE_PART)],
						[R.t("Longueur de l'ouvrage : %s.", [R.km(float(f.long))])], 9, f.pos, _temoin(R.PAROLE_PONT_NULLE_PART)))
				else:
					articles.append(_article("travaux", _T(R.TITRES_PONT, [v]), [_choisir(R.CHAPO_PONT)],
						[R.t("Longueur de l'ouvrage : %s.", [R.km(float(f.long))])], 5, f.pos, _temoin(["Fini les détours, je gagne dix minutes chaque matin."])))
			"routes":
				articles.append(_article("travaux", _T(R.TITRES_ROUTES, [R.km(float(f.m)), v]), [_choisir(R.CHAPO_ROUTES)], [], 3))
			"fondation":
				articles.append(_article("ville", _T(R.TITRES_FONDATION, [String(f.nom)]), [_choisir(R.CHAPO_FONDATION)], [], 8))
			"palier":
				articles.append(_article("ville", _T(R.TITRES_PALIER, [R.nombre(int(f.n)), v]), [_choisir(R.CHAPO_PALIER)], [],
					6 + PALIERS.find(int(f.n)) / 3, [], _temoin(["On était bien quand on était moins nombreux. Mais bon, bienvenue !",
						"Plus de monde, plus de clients : je ne vais pas me plaindre."])))
			"chomage":
				articles.append(_article("economie", _T(R.TITRES_CHOMAGE, [_pct(float(f.v))]), [_choisir(R.CHAPO_CHOMAGE)], [], 6, [],
					_temoin(["J'envoie des lettres tous les jours. On ne me répond jamais.", "Il faudrait des usines, ici."])))
			"caisse_rouge":
				articles.append(_article("economie", _T(R.TITRES_CAISSE_ROUGE, [BuildingSystem.format_money(int(f.v))]), [_choisir(R.CHAPO_CAISSE_ROUGE)], [], 7))
			"caisse_verte":
				articles.append(_article("economie", _T(R.TITRES_CAISSE_VERTE), [_choisir(R.CHAPO_CAISSE_VERTE)], [], 4))
			"sat_basse":
				articles.append(_article("politique", _T(R.TITRES_SATISFACTION_BASSE, [v]), [_choisir(R.CHAPO_SATISFACTION_BASSE)],
					[R.t("Satisfaction moyenne : %s sur 100.", [str(int(f.v))])], 6))
			"sat_haute":
				articles.append(_article("ville", _T(R.TITRES_SATISFACTION_HAUTE, [v]), [_choisir(R.CHAPO_SATISFACTION_HAUTE)],
					[R.t("Satisfaction moyenne : %s sur 100.", [str(int(f.v))])], 5))
			"bouchons":
				articles.append(_article("ville", _T(R.TITRES_BOUCHONS, [v]), [_choisir(R.CHAPO_BOUCHONS)], [], 5, [],
					_temoin(["J'ai eu le temps de lire tout le journal dans ma voiture. Deux fois."])))
			"poubelles":
				articles.append(_article("ville", _T(R.TITRES_POUBELLES, [v]), [_choisir(R.CHAPO_POUBELLES)], [], 5, [],
					_temoin(["Ça sent jusque dans la chambre.", "Les chats du quartier n'ont jamais été aussi gros."])))
			"pollution":
				articles.append(_article("societe", _T(R.TITRES_POLLUTION, [v]), [_choisir(R.CHAPO_POLLUTION)], [], 5))
	# Le doyen qui s'en va mérite mieux qu'une ligne dans le carnet.
	for f in carnet.deces:
		if int(f.age) >= 100:
			var elle := bool(f.get("f", false))
			articles.append(_article("societe", R.t("%s s'est éteinte à %s ans" if elle else "%s s'est éteint à %s ans", [String(f.nom), str(int(f.age))]),
				R.t("La ville perd sa doyenne. Un siècle de souvenirs." if elle else "La ville perd son doyen. Un siècle de souvenirs."),
				[[String(f.texte)]], 6, [], {}))
	articles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.imp) > int(b.imp))
	return {"articles": articles, "breves": breves, "sport": sport_breves, "carnet": carnet}


static func CHAPOS_DE(g: String) -> Array:
	return JournalRedaction.CHAPOS_GENRE.get(g, JournalRedaction.CHAPO_DEFAUT)


func _sport_nom(s: String) -> String:
	const NOMS := {"football": "Football", "basket": "Basket", "handball": "Handball", "hockey": "Hockey sur glace",
		"rugby": "Rugby", "tennis": "Tennis"}
	return String(NOMS.get(s, "Sport"))


static func _pct(x: float) -> String:
	return "%s %%" % str(snappedf(x, 0.1)).replace(".", ",")


## Fait paraître l'édition du jour avec les faits notés, puis les oublie.
func publier() -> Dictionary:
	var R := JournalRedaction
	numero += 1
	var d := date()
	_rng.seed = hash(Vector2i(numero, jour())) + hash(ville())
	var ep := epoque()
	var v := ville()
	var r := rediger()
	var articles: Array = r.articles
	var une: Dictionary
	if articles.is_empty():
		une = _article("ville", _T(R.TITRES_CALME, [v]), [_choisir(R.CHAPO_CALME)], [], 0, [],
			_temoin(["Calme ? Moi j'appelle ça reposant.", "Tant mieux, on a le temps de lire les petites annonces."]))
	else:
		une = articles.pop_front()
	var autres := articles.slice(0, 5)
	# Les articles qui n'ont pas trouvé de place passent en brèves.
	var breves: Array = []
	for a in articles.slice(5):
		breves.append(a.titre)
	for b in r.breves:
		if breves.size() < 8:
			breves.append([b])
	var ed := {
		"n": numero, "j": jour(), "an": int(d.year), "mois": int(d.month), "jm": int(d.day), "js": int(d.get("weekday", 0)),
		"ep": String(ep.id), "ville": v, "une": une, "articles": autres, "breves": breves,
		"sport": (r.sport as Array).slice(0, 6), "carnet": _carnet(r.carnet), "meteo": _meteo(),
		"parole": _parole(), "annonces": _annonces(), "chiffre": _chiffre(),
	}
	editions.append(ed)
	while editions.size() > EDITIONS_MAX:
		editions.remove_at(0)
	faits.clear()
	non_lue = true
	edition_parue.emit(ed)
	changed.emit()
	return ed


func _carnet(c: Dictionary) -> Dictionary:
	var out := {}
	for code in c:
		var l := []
		for f in c[code]:
			match String(code):
				"mariage":
					l.append([String(f.nom), String(f.ref_nom)])
				"deces":
					l.append([String(f.nom), int(f.age)])
				"sport":
					l.append([String(f.nom), String(f.texte)])
				_:
					l.append([String(f.nom)])
		out[code] = l.slice(0, 12)
		out[code + "_n"] = l.size()
	return out


func _meteo() -> Dictionary:
	if saisons == null or not is_instance_valid(saisons):
		return {}
	var p: Array = saisons.previsions(1)
	if p.is_empty():
		return {}
	var m: Dictionary = p[0]
	return {"nom": String(m.get("nom", "")), "tmin": roundi(float(m.tmin)), "tmax": roundi(float(m.tmax)),
		"ciel": String(m.get("ciel", "")), "icone": String(m.get("icone", "soleil"))}


func _parole() -> Dictionary:
	if avis == null or population == null or population.persons.size() < 3:
		return {}
	var l := avis.paroles(4)
	if l.is_empty():
		return {}
	var q: Dictionary = l[_rng.randi() % l.size()]
	return {"pid": int(q.pid), "nom": String(q.nom), "age": int(q.age), "etape": String(q.etape), "texte": String(q.phrase)}


func _annonces() -> Array:
	var R := JournalRedaction
	var out := []
	var c := chiffres()
	if int(c.get("logements_libres", 0)) >= 5:
		out.append(R.t(R.ANNONCE_LOGEMENTS, [R.nombre(int(c.logements_libres))]))
	if int(c.get("emplois_libres", 0)) >= 5:
		out.append(R.t(R.ANNONCE_EMPLOIS, [R.nombre(int(c.emplois_libres))]))
	out.append([_choisir(R.ANNONCES_DROLES)])
	return out


func _chiffre() -> Dictionary:
	var c := chiffres()
	if c.is_empty():
		return {}
	var choix := []
	for k in JournalRedaction.CHIFFRES:
		if c.has(k) and float(c[k]) > 0.0:
			choix.append(k)
	if choix.is_empty():
		return {}
	var k: String = choix[_rng.randi() % choix.size()]
	var val := float(c[k])
	var txt := _pct(val) if k in ["chomage", "congestion"] else JournalRedaction.nombre(roundi(val))
	return {"v": txt, "t": JournalRedaction.CHIFFRES[k]}


func derniere() -> Dictionary:
	return editions[-1] if not editions.is_empty() else {}


## Nom du journal pour une édition (selon son époque et sa ville).
static func titre_de(ed: Dictionary) -> String:
	var ep := JournalEpoques.par_id(String(ed.get("ep", "")))
	return Langue.t(String(ep.titre)) % String(ed.get("ville", ""))


# --- Sauvegarde --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var bv := {}
	for bid in _bat_vus:
		bv[str(bid)] = _bat_vus[bid]
	return {"v": 1, "editions": editions, "faits": faits, "numero": numero, "non_lue": non_lue, "bat": bv,
		"troncon": _troncon_max, "etats": _etats, "jour": _dernier_jour, "inv": _inventaire}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	editions = d.get("editions", [])
	faits = d.get("faits", [])
	numero = int(d.get("numero", editions.size()))
	non_lue = bool(d.get("non_lue", false))
	var bv: Dictionary = d.get("bat", {})
	for k in bv:
		_bat_vus[int(k)] = bv[k]
	_troncon_max = int(d.get("troncon", 0))
	_etats = d.get("etats", {})
	_dernier_jour = int(d.get("jour", -1))
	_inventaire = bool(d.get("inv", false))
	changed.emit()
