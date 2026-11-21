class_name ReactionsHabitants
extends Control
## Bulles des habitants : quand le joueur fait un choix (poser une école, tracer
## une route, démolir, monter les impôts, annuler…), un habitant du coin réagit
## en une phrase, dans une bulle au-dessus de l'endroit. Ton réaliste, avec une
## touche d'humour. Les phrases suivent l'époque (pas de place de parking en
## 1800) et l'âge de l'habitant (enfant, retraité).
##
## Lisibilité d'abord : une seule bulle à la fois, au moins ECART secondes entre
## deux bulles, et le même genre de choix ne fait pas réagir deux fois de suite
## avant RECHARGE secondes. Clic sur la bulle : fiche de l'habitant. La bulle se
## ferme toute seule (ou ✕ / Ctrl+H, menu Affichage → « Bulles des habitants »).
##
## Purement pour le plaisir : les bulles ne changent ni l'avis (Y) ni l'argent.
## Les textes sont en français : TraductionAuto les traduit à l'affichage.

signal person_requested(pid: int)

## Écart minimum entre deux bulles (secondes réelles).
const ECART := 12.0
## Un même genre de choix ne refait réagir qu'après ce délai.
const RECHARGE := 75.0
## Durée d'affichage : base + par lettre.
const DUREE := 5.0
const DUREE_PAR_LETTRE := 0.045
## Poses du même bâtiment en une minute à partir desquelles on parle de « série ».
const SERIE := 4
## Chance de réagir aux gestes très fréquents (routes, zones, décors).
const CHANCE_FREQUENT := 0.55
const LARGEUR := 300.0

## Phrases par genre de choix : [texte, conditions]. Conditions séparées par des
## espaces : « <1900 » (avant 1900), « >1950 » (à partir de 1950), « enfant »
## (moins de 15 ans), « senior » (65 ans et plus), « adulte ».
const PHRASES := {
	"logement": [
		["Enfin des voisins ! Pourvu qu'ils n'aient pas de coq.", ""],
		["Encore des maisons… bientôt on ne verra plus les champs.", ""],
		["Si le loyer est raisonnable, j'y installe ma belle-mère. Loin de chez moi.", "adulte"],
		["Je parie que le chantier va durer deux ans.", ""],
		["De mon temps, on construisait sa maison soi-même.", "senior"],
		["Il y aura des enfants pour jouer avec moi ?", "enfant"],
	],
	"commerce": [
		["Un nouveau commerce ! Mon porte-monnaie a déjà peur.", ""],
		["Enfin plus besoin de marcher une heure pour acheter du pain.", ""],
		["J'irai voir les prix… et je retournerai chez l'ancien.", "adulte"],
		["Est-ce qu'ils vendront des bonbons ?", "enfant"],
	],
	"industrie": [
		["Du travail, c'est bien. La fumée, un peu moins.", ""],
		["Je sens déjà l'odeur d'ici. Ou alors c'est mon voisin.", ""],
		["Une usine ! Mon fils va enfin quitter la maison.", "senior"],
		["Les machines à vapeur, c'est l'avenir, paraît-il.", "<1900"],
	],
	"production": [
		["Ça sent la campagne… au sens propre.", ""],
		["Des produits d'ici, j'achète. Si ce n'est pas plus cher.", "adulte"],
		["Encore du bruit à l'aube. Le coq avait déjà la place.", ""],
	],
	"ecole": [
		["Une école ! Mes enfants vont adorer. Enfin, peut-être pas.", "adulte"],
		["Une école ? Mais pourquoi ?!", "enfant"],
		["Moi, j'ai appris à lire avec le curé, et je ne m'en porte pas plus mal.", "senior"],
		["Le chemin de l'école sera plus court. Les excuses aussi.", ""],
	],
	"sante": [
		["Un médecin près de chez nous, je vais enfin faire soigner mon genou.", "adulte"],
		["Parfait, j'y réserve déjà ma chaise dans la salle d'attente.", "senior"],
		["Pourvu qu'on n'en ait jamais besoin. Mais merci quand même.", ""],
	],
	"police": [
		["Plus personne ne volera mes poules.", ""],
		["Je me sens plus en sécurité. Et un peu sous surveillance.", ""],
		["Je vais garer mon vélo correctement, promis.", ">1890"],
	],
	"pompiers": [
		["Les pompiers à côté : je peux rater mes gratins tranquille.", "adulte"],
		["J'espère qu'ils feront un bal, comme partout.", ""],
		["Des pompiers ! Je veux monter dans la grande échelle.", "enfant"],
	],
	"services": [
		["Un service public de plus. On verra la file d'attente.", ""],
		["Pratique ! Il ne manque plus que des horaires d'ouverture normaux.", "adulte"],
	],
	"culte": [
		["Un lieu de prière tout près. Adieu les grasses matinées.", ""],
		["Les cloches à sept heures ? Il fallait le dire avant.", "adulte"],
	],
	"gare": [
		["Une gare ! On va pouvoir partir. Et revenir, si possible.", ""],
		["Je viendrai regarder les trains passer. C'est gratuit.", "senior"],
	],
	"mairie": [
		["Un bel édifice. Avec nos impôts, j'imagine.", "adulte"],
		["C'est là qu'on se marie ? Je dis ça, je ne dis rien.", ""],
	],
	"reseaux": [
		["L'eau au robinet, c'est le luxe. Fini les seaux.", ""],
		["De l'électricité ! Je vais pouvoir lire après le coucher du soleil.", ">1885"],
		["Des tuyaux partout… pourvu que ça ne fuie pas chez moi.", ""],
	],
	"dechets": [
		["Une décharge ? Pas derrière chez moi, j'espère !", ""],
		["C'est bien de ramasser les ordures. Mais ailleurs, merci.", ""],
		["Mon jardin va sentir l'aventure.", "adulte"],
	],
	"funeraire": [
		["Un cimetière avec vue. Je réserve.", "senior"],
		["On n'y pense pas, mais il en faut un. Pas trop près de ma fenêtre.", ""],
	],
	"loisirs": [
		["Enfin quelque chose à faire le dimanche !", ""],
		["Je vais pouvoir sortir… si mon patron me laisse partir.", "adulte"],
		["On y va quand ? Là ? Maintenant ?", "enfant"],
	],
	"sport": [
		["Je vais m'y mettre. Lundi. Peut-être.", "adulte"],
		["Je vais crier très fort pendant les matchs, c'est bon pour la santé.", ""],
		["Moi, je gagnerai la coupe du monde !", "enfant"],
	],
	"parc": [
		["Mes enfants vont enfin se fatiguer ailleurs qu'au salon.", "adulte"],
		["Des manèges ! Je vais tout essayer deux fois.", "enfant"],
		["À mon âge, je prendrai le petit train. Lentement.", "senior"],
	],
	"zoo": [
		["Les animaux seront mieux logés que moi.", "adulte"],
		["Il y aura des girafes ? Dis oui !", "enfant"],
		["Un zoo. Le singe va me regarder comme mon beau-frère.", ""],
	],
	"tourisme": [
		["Un hôtel. Ma tante n'aura plus d'excuse pour dormir chez nous.", ""],
		["Des touristes… ils vont encore photographier ma maison.", ">1890"],
		["Des voyageurs ! Ils raconteront le monde à l'auberge.", "<1890"],
	],
	"espaces": [
		["Un banc ! Mon dos vous dit merci.", ""],
		["Une jolie place. Il ne manque plus qu'un marché le samedi.", ""],
	],
	"patrimoine": [
		["Un monument ! On pourra dire qu'on l'a vu se construire.", ""],
		["C'est beau. Combien ça coûte ? Non, ne me dites pas.", "adulte"],
	],
	"demolition": [
		["Hé ! J'avais mes habitudes là-dedans.", ""],
		["Démolir, c'est vite fait. Reconstruire, on en reparle dans dix ans.", ""],
		["Ça tombe… comme mes impôts, j'espère.", "adulte"],
	],
	"demolition_logement": [
		["Et les gens qui habitaient là, ils dorment où ce soir ?", ""],
		["Encore une maison de moins. Mon cousin cherchait justement.", ""],
	],
	"route": [
		["Une vraie route ! Mon cheval va enfin garder ses fers.", "<1910"],
		["Une route neuve. Les nids-de-poule, c'est pour quand ?", ">1910"],
		["Le facteur va mettre moins de temps. En théorie.", ""],
		["Encore une route… et toujours pas de place pour se garer.", ">1955"],
	],
	"rail": [
		["Le train ! Je vais pouvoir aller voir ma sœur. Ou faire semblant d'être en retard.", ""],
		["Un train sous ma fenêtre. J'adore. La nuit, un peu moins.", ""],
		["Le chemin de fer ! La capitale n'est plus qu'à quelques heures.", "<1900"],
	],
	"chemin": [
		["Un chemin pour marcher, très bien. Mes chaussures sont moins d'accord.", ""],
	],
	"eau": [
		["Des bateaux ! J'ai déjà le pied marin.", ""],
	],
	"zones": [
		["On va construire quoi, là ? J'aimais bien ce terrain vague.", ""],
		["Des terrains tout neufs. Mon cousin cherche justement.", "adulte"],
	],
	"decors": [
		["Des arbres ! Ça fait tout de suite plus chic.", ""],
		["Joli. Mais qui va arroser tout ça ?", "adulte"],
	],
	"conduites": [
		["Encore des travaux dans la rue… Bon, si c'est pour l'eau.", ""],
	],
	"impots_hausse": [
		["Encore plus d'impôts ? Je vais cacher mon argent sous le matelas.", "adulte"],
		["La mairie a dû casser sa tirelire.", ""],
		["Je paierai… mais je râlerai, c'est mon droit.", "adulte"],
	],
	"impots_baisse": [
		["Moins d'impôts ! Je vote pour vous l'an prochain.", "adulte"],
		["Moins d'impôts. Je me méfie : où est le piège ?", ""],
	],
	"annuler": [
		["Ah, finalement non ? On a eu peur.", ""],
		["La mairie a changé d'avis. Ça arrive. Souvent.", ""],
		["Pose, enlève, pose, enlève… c'est une danse ?", ""],
	],
	"fondation": [
		["Un nouveau village ! J'ai déjà une liste de réclamations.", "adulte"],
		["Tout reste à faire. On commence par une boulangerie ?", ""],
	],
	"serie": [
		["Encore une pareille ? On va se perdre, tout se ressemble.", ""],
		["C'est une ville ou un jeu de dominos ?", ""],
	],
}

## Bâtiments rangés à part de leur catégorie (début de l'identifiant de base).
const PAR_ID := {"ecole": "ecole", "college": "ecole", "lycee": "ecole", "universite": "ecole", "creche": "ecole",
	"hopital": "sante", "clinique": "sante", "cabinet": "sante", "pharmacie": "sante", "dispensaire": "sante",
	"commissariat": "police", "gendarmerie": "police", "police": "police", "poste_police": "police",
	"caserne": "pompiers", "pompier": "pompiers", "ferme": "production", "culte": "culte", "gare": "gare",
	"mairie": "mairie", "palais": "mairie"}
const PAR_CATEGORIE := {"logement": "logement", "commerce": "commerce", "industrie": "industrie",
	"production": "production", "services": "services", "reseaux": "reseaux", "dechets": "dechets",
	"funeraire": "funeraire", "loisirs": "loisirs", "spectacles": "loisirs", "sport": "sport", "parc": "parc",
	"zoo": "zoo", "tourisme": "tourisme", "espaces": "espaces", "patrimoine": "patrimoine"}
## Genres de choix très fréquents : réaction pas à tous les coups.
const FREQUENTS := ["route", "chemin", "zones", "decors", "conduites", "logement"]

## La scène de jeu (terre_main) : buildings, transport, population, rig, communes.
var jeu: Node
var population: Population
## Callable() -> bool : vrai si l'utilisateur a masqué les bulles (menu Affichage).
var masque: Callable
## Callable() -> bool : faux pendant un chargement de partie.
var pret: Callable
var actif := true
var rng := RandomNumberGenerator.new()
## Pour les tests : l'heure réelle (secondes) au lieu de Time.
var horloge: Callable

## Bulle affichée : {pid, texte, genre, pos (Vector3), fin}.
var bulle: Dictionary = {}
## Dernière bulle par genre (heure réelle).
var _derniers := {}
var _derniere := -1000.0
## Poses récentes [heure, type] pour repérer les séries.
var _poses: Array = []
var _taux := {}
var _t_taux := 0.0
var _survol := false

var _panel: PanelContainer
var _qui: Label
var _texte: Label
var _queue: Control


func _init() -> void:
	name = "ReactionsHabitants"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.randomize()
	_panel = PanelContainer.new()
	_panel.name = "Bulle"
	var sb := UiStyle.flat_box(Color(0.98, 0.97, 0.92, 0.96), 14, 10)
	sb.border_color = Color(0.15, 0.16, 0.14, 0.55)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(LARGEUR, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_panel.tooltip_text = "Clic : fiche de l'habitant"
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_qui = Label.new()
	_qui.add_theme_font_size_override("font_size", 11)
	_qui.add_theme_color_override("font_color", Color(0.35, 0.38, 0.34))
	_qui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_qui)
	_texte = Label.new()
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.custom_minimum_size = Vector2(LARGEUR - 24, 0)
	_texte.add_theme_font_size_override("font_size", 14)
	_texte.add_theme_color_override("font_color", Color(0.10, 0.11, 0.10))
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_texte)
	_queue = Control.new()
	_queue.name = "Queue"
	_queue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_queue.draw.connect(_dessiner_queue)
	add_child(_queue)
	_panel.gui_input.connect(_on_gui_input)
	_panel.mouse_entered.connect(func() -> void: _survol = true)
	_panel.mouse_exited.connect(func() -> void: _survol = false)


## Branche les choix du joueur (annuler/rétablir, fondation de village, impôts).
func setup(j: Node, pop: Population) -> void:
	jeu = j
	population = pop
	_brancher()
	var cm: Communes = j.get("communes") if j != null else null
	if cm != null and not cm.fonde.is_connected(_on_fonde):
		cm.fonde.connect(_on_fonde)
	_lire_taux()


## L'historique (Ctrl+Z) peut naître après les bulles : branché dès qu'il existe.
func _brancher() -> bool:
	var h := HistoriqueVille.instance
	if h == null:
		return false
	if not h.geste_note.is_connected(on_geste):
		h.geste_note.connect(on_geste)
	if not h.annule.is_connected(_on_annule):
		h.annule.connect(_on_annule)
	return true


func carte() -> Control:
	return _panel


func maintenant() -> float:
	if horloge.is_valid():
		return float(horloge.call())
	return Time.get_ticks_msec() / 1000.0


func clear() -> void:
	bulle = {}
	_derniers.clear()
	_poses.clear()
	_derniere = -1000.0
	_panel.visible = false
	_queue.visible = false
	_lire_taux()


# --- Choix du joueur -------------------------------------------------------------

## Un geste du joueur vient d'entrer dans l'historique (HistoriqueVille.geste_note).
func on_geste(ops: Array, noms: Array) -> void:
	var genre := ""
	var pos := Vector3.INF
	var bat := ""
	for op in ops:
		var k := String(op.get("k", ""))
		if k == "bat_pose" or k == "mp_bat_pose":
			var b: Dictionary = op.get("b", op.get("a", {}))
			if b.is_empty():
				continue
			bat = String(b.get("t", ""))
			genre = genre_batiment(bat)
			pos = _pos_batiment(b)
			_poses.append([maintenant(), bat])
			break
		if k == "bat_demoli" or k == "mp_bat_demoli":
			var b2: Dictionary = op.get("b", op.get("a", {}))
			genre = "demolition_logement" if String(BuildingCatalog.get_type(String(b2.get("t", ""))).get("cat", "")) == "logement" else "demolition"
			pos = _pos_batiment(b2)
			break
		if k == "voies" or k == "mp_voies":
			var r := genre_voies(op.get("diff", {}))
			if not r.is_empty():
				genre = r[0]
				pos = r[1]
				break
	if genre == "":
		for n in noms:
			match String(n):
				"Zones": genre = "zones"
				"Décors": genre = "decors"
				"Réseaux", "Télécoms", "Sous-sol": genre = "conduites"
			if genre != "":
				break
	if genre == "":
		return
	if bat != "" and _serie(bat):
		genre = "serie"
	reagir(genre, pos)


func _on_annule() -> void:
	reagir("annuler", Vector3.INF)


func _on_fonde(vid: int) -> void:
	var pos := Vector3.INF
	var cm: Communes = jeu.get("communes") if jeu != null else null
	if cm != null and cm.villages.has(vid):
		var c: Vector2 = cm.villages[vid].get("c", Vector2.ZERO)
		pos = Vector3(c.x, _sol(c.x, c.y), c.y)
	# La fondation se fête : elle passe devant l'écart entre deux bulles.
	reagir("fondation", pos, true)


## Genre de réaction d'un bâtiment posé.
static func genre_batiment(type_id: String) -> String:
	var base := BuildingCatalog.base_of(type_id)
	# Bâtiments de style : « haussmann__ecole » est une école.
	if base.contains("__"):
		base = base.get_slice("__", 1)
	if base == "campement" or base == "maison_commune":
		return ""
	for debut in PAR_ID:
		if base.begins_with(debut):
			return String(PAR_ID[debut])
	var cat := String(BuildingCatalog.get_type(type_id).get("cat", ""))
	return String(PAR_CATEGORIE.get(cat, ""))


## [genre, position] pour des voies tracées, ou [] (rien de neuf, que des démolitions).
static func genre_voies(diff: Dictionary) -> Array:
	var plus: Dictionary = diff.get("e_plus", {})
	var moins: Dictionary = diff.get("e_moins", {})
	for id in plus:
		# Un tronçon simplement coupé en deux par un carrefour n'est pas une nouveauté.
		if moins.has(id):
			continue
		var e: Dictionary = plus[id]
		var pts: PackedVector3Array = e.get("pts", PackedVector3Array())
		var pos := pts[int(pts.size() * 0.5)] if pts.size() > 0 else Vector3.INF
		match TransportTypes.mode_of(String(e.get("t", ""))):
			TransportTypes.Mode.ROAD: return ["route", pos]
			TransportTypes.Mode.RAIL: return ["rail", pos]
			TransportTypes.Mode.PATH: return ["chemin", pos]
			TransportTypes.Mode.WATER: return ["eau", pos]
	return []


func _serie(type_id: String) -> bool:
	var t := maintenant()
	var n := 0
	var garde: Array = []
	for p in _poses:
		if t - float(p[0]) <= 60.0:
			garde.append(p)
			if String(p[1]) == type_id:
				n += 1
	_poses = garde
	return n >= SERIE and n % SERIE == 0


func _lire_taux() -> void:
	var b := BudgetCommunal.instance
	_taux = b.taux.duplicate() if b != null else {}


## Impôts : comparés toutes les 2 s (le curseur bouge par petits pas).
func _suivre_impots(delta: float) -> void:
	_t_taux += delta
	if _t_taux < 2.0:
		return
	_t_taux = 0.0
	var b := BudgetCommunal.instance
	if b == null:
		return
	var d := 0.0
	for k in b.taux:
		d += float(b.taux[k]) - float(_taux.get(k, b.taux[k]))
	_taux = b.taux.duplicate()
	if absf(d) >= 0.049:
		reagir("impots_hausse" if d > 0.0 else "impots_baisse", Vector3.INF)


# --- Bulle -----------------------------------------------------------------------

## Fait réagir un habitant. Renvoie vrai si une bulle s'affiche.
func reagir(genre: String, pos: Vector3, prioritaire := false) -> bool:
	if not actif or not PHRASES.has(genre) or population == null or population.persons.is_empty():
		return false
	if masque.is_valid() and bool(masque.call()):
		return false
	if pret.is_valid() and not bool(pret.call()):
		return false
	var t := maintenant()
	if not prioritaire:
		if t - _derniere < ECART or t - float(_derniers.get(genre, -1000.0)) < RECHARGE:
			return false
		if FREQUENTS.has(genre) and rng.randf() > CHANCE_FREQUENT:
			return false
	var p := choisir_habitant(pos)
	if p.is_empty():
		return false
	var texte := phrase(genre, population.age_years(p), Epoques.annee())
	if texte == "":
		return false
	_derniere = t
	_derniers[genre] = t
	if pos == Vector3.INF:
		pos = _pos_par_defaut()
	bulle = {"pid": int(p.id), "texte": texte, "genre": genre, "pos": pos,
		"fin": t + DUREE + DUREE_PAR_LETTRE * texte.length()}
	_qui.text = "%s · %d ans" % [CycleVie.full_name(p), population.age_years(p)]
	_texte.text = texte
	_panel.visible = true
	_panel.modulate.a = 0.0
	_panel.reset_size()
	_placer()
	return true


## Une phrase du genre, compatible avec l'âge et l'année (« » si aucune).
func phrase(genre: String, age: int, an: int) -> String:
	var ok: Array = []
	for e in PHRASES.get(genre, []):
		if convient(String(e[1]), age, an):
			ok.append(String(e[0]))
			# Les phrases liées à l'âge passent deux fois plus souvent : c'est plus drôle.
			if String(e[1]).contains("enfant") or String(e[1]).contains("senior"):
				ok.append(String(e[0]))
	if ok.is_empty():
		return ""
	return String(ok[rng.randi() % ok.size()])


static func convient(cond: String, age: int, an: int) -> bool:
	for c in cond.split(" ", false):
		if c.begins_with("<"):
			if an >= int(c.substr(1)):
				return false
		elif c.begins_with(">"):
			if an < int(c.substr(1)):
				return false
		elif c == "enfant" and age >= 15:
			return false
		elif c == "senior" and age < 65:
			return false
		elif c == "adulte" and (age < 18 or age >= 65):
			return false
	return true


## Un habitant qui vit près de l'endroit (sinon n'importe qui en âge de parler).
func choisir_habitant(pos: Vector3) -> Dictionary:
	var bs: BuildingSystem = jeu.get("buildings") if jeu != null else null
	var ids := population.persons.keys()
	var meilleur := {}
	var d_min := INF
	for i in mini(ids.size(), 220):
		var p: Dictionary = population.persons[ids[rng.randi() % ids.size()]]
		if population.age_years(p) < 5:
			continue
		if pos == Vector3.INF or bs == null:
			return p
		var h := population.home_of(p)
		if h < 0 or not bs.buildings.has(h):
			if meilleur.is_empty():
				meilleur = p
			continue
		var bp := _pos_batiment(bs.buildings[h])
		var d := Vector2(bp.x - pos.x, bp.z - pos.z).length()
		if d < d_min:
			d_min = d
			meilleur = p
	return meilleur


func _pos_batiment(b: Dictionary) -> Vector3:
	var bs: BuildingSystem = jeu.get("buildings") if jeu != null else null
	if bs != null and b.has("id") and bs.buildings.has(int(b.id)):
		var n := bs.node_of(int(b.id))
		if n != null:
			return n.global_position + Vector3(0, 8, 0)
	if b.has("x") and b.has("z") and b.has("t"):
		var c := BuildingSystem.rect_center(Rect2i(Vector2i(int(b.x), int(b.z)), BuildingCatalog.footprint(String(b.t), int(b.get("r", 0)))))
		return c + Vector3(0, float(b.get("h", 0.0)) + 8.0, 0)
	return Vector3.INF


func _pos_par_defaut() -> Vector3:
	var rig: Node3D = jeu.get("rig") if jeu != null else null
	return rig.global_position + Vector3(0, 4, 0) if rig != null else Vector3.ZERO


func _sol(x: float, z: float) -> float:
	var w: TerrainWorld = jeu.get("world") if jeu != null else null
	if w == null:
		return 0.0
	var g := w.cell_height(Vector2i(floori(x), floori(z)))
	return 0.0 if is_nan(g) else maxf(g, 0.0) + 6.0


func _process(delta: float) -> void:
	if HistoriqueVille.instance != null and not HistoriqueVille.instance.geste_note.is_connected(on_geste):
		_brancher()
	_suivre_impots(delta)
	if bulle.is_empty():
		return
	var t := maintenant()
	if _survol:
		bulle.fin = maxf(float(bulle.fin), t + 1.0)
	var reste := float(bulle.fin) - t
	if reste <= 0.0 or (masque.is_valid() and bool(masque.call())):
		fermer()
		return
	_panel.modulate.a = clampf(minf(_panel.modulate.a + delta * 5.0, reste / 0.6), 0.0, 1.0)
	_queue.modulate.a = _panel.modulate.a
	_placer()


func fermer() -> void:
	bulle = {}
	_panel.visible = false
	_queue.visible = false


## Place la bulle au-dessus du point, dans l'écran (bords et barres évités).
func _placer() -> void:
	var ecran := get_viewport_rect().size
	var cam := get_viewport().get_camera_3d()
	var cible := ecran * Vector2(0.5, 0.45)
	var pos: Vector3 = bulle.get("pos", Vector3.INF)
	var dans_vue := false
	if cam != null and pos != Vector3.INF and not cam.is_position_behind(pos):
		cible = cam.unproject_position(pos)
		dans_vue = Rect2(Vector2.ZERO, ecran).grow(-20.0).has_point(cible)
	var taille := _panel.get_combined_minimum_size()
	var haut := UiStyle.SIDE_TOP + 10.0
	var bas := ecran.y - UiStyle.DOCK_HEIGHT - 10.0
	var x := clampf(cible.x - taille.x * 0.5, 12.0, ecran.x - taille.x - 12.0)
	var y := clampf(cible.y - taille.y - 22.0, haut, bas - taille.y)
	_panel.position = Vector2(x, y)
	_panel.size = taille
	# La pointe ne se montre que si l'endroit est à l'écran, juste sous la bulle.
	var pointe := Vector2(clampf(cible.x, x + 18.0, x + taille.x - 18.0), y + taille.y)
	_queue.visible = _panel.visible and dans_vue and cible.y > pointe.y + 4.0
	_queue.position = pointe
	_queue.set_meta("bout", cible - pointe)
	_queue.queue_redraw()


func _dessiner_queue() -> void:
	var bout: Vector2 = _queue.get_meta("bout", Vector2(0, 16))
	bout = bout.limit_length(22.0)
	var pts := PackedVector2Array([Vector2(-9, -2), Vector2(9, -2), bout])
	_queue.draw_colored_polygon(pts, Color(0.98, 0.97, 0.92, 0.96))
	_queue.draw_polyline(PackedVector2Array([Vector2(-9, 0), bout, Vector2(9, 0)]), Color(0.15, 0.16, 0.14, 0.55), 2.0, true)


func _on_gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or bulle.is_empty():
		return
	accept_event()
	var pid := int(bulle.pid)
	fermer()
	person_requested.emit(pid)
