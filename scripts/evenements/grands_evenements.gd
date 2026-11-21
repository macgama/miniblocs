class_name GrandsEvenements
extends RefCounted
## Grands événements à filmer (panneau Infos, I ; vol cinématique au départ) :
##
## - Fête de la ville : chaque année le jour anniversaire de sa fondation
##   (Maison de commune), de 20 h à minuit devant la mairie, avec tables,
##   guirlandes, foule, et le feu d'artifice à 22 h. Le joueur peut aussi en
##   organiser une ce soir (Infos → Organiser).
## - Inauguration d'un grand monument (Patrimoine, quand le chantier finit) :
##   ruban, foule, applaudissements et feu d'artifice tout de suite.
## - Premier train : la première ligne de train de voyageurs d'une ville part
##   de sa gare devant la foule (sifflet, applaudissements) ; la caméra suit la
##   rame pendant le vol.
##
## Chaque départ lance un vol cinématique (VolCinematique, s'il est branché et
## que « Vols automatiques » est coché), avec une bulle d'habitant (ton réaliste,
## un peu d'humour). Les villes déjà fêtées pour leur premier train sont gardées
## dans la sauvegarde (section evenements → grands).

const TYPES := ["fete_ville", "inauguration", "premier_train"]
const FETE_HEURES := Vector2(20.0, 24.0)
const FEUX_HEURE := 22.0
const COUT_FETE_VILLE := 25_000
## Durée de l'inauguration et de la fête du premier train (heures de jeu).
const DUREE_INAUGURATION := 3.0
const DUREE_TRAIN := 2.0
## Feu d'artifice (secondes réelles) : fête de la ville, inauguration, palier.
const FEUX_FETE := 26.0
const FEUX_INAUGURATION := 18.0
const FEUX_PALIER := 10.0

const BULLES_FETE := [
	"« %d ans et toujours pas de piscine couverte. Mais quel feu d'artifice ! »",
	"« Le maire a promis un discours court. Il en est à la page 6. »",
	"« Mon grand-père était là pour la première pierre. Enfin, il le raconte. »",
	"« Les pompiers sont venus en avance, au cas où. Ils ont raison. »",
]
const BULLES_INAUGURATION := [
	"« Douze ans de travaux, mais on ne va pas bouder notre plaisir. »",
	"« C'est beau. On dirait le dépliant, en vrai. »",
	"« J'ai payé une pierre de la souscription. Je cherche laquelle. »",
	"« Les pigeons ont déjà réservé la corniche. »",
]
const BULLES_TRAIN := [
	"« Enfin ! Plus besoin de la diligence de 6 h 12. »",
	"« Il est à l'heure. Profitons-en, ça ne durera pas. »",
	"« Ma tante dit que ça va trop vite pour la santé. Elle a pris un billet quand même. »",
	"« Le chef de gare a ciré ses chaussures deux fois. »",
]

var ev: Evenements
var communes: Communes
var stations: StationSystem
var traffic: Object
## Vol cinématique (Callable(plan: Dictionary) -> bool), branché par terre_main.
var filmer: Callable
## Villes (vid) qui ont déjà fêté leur premier train.
var premiers_trains: Dictionary = {}
var _lignes_vues: Dictionary = {}
## Dernière année fêtée par ville (une fête de la ville par an au plus).
var fetes_faites: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init(e: Evenements, c: Communes, s: StationSystem) -> void:
	ev = e
	communes = c
	stations = s
	traffic = s.traffic if s != null else null
	rng.randomize()
	for t in TYPES:
		ev.modules[t] = self
	ev.planificateurs.append(self)


func clear() -> void:
	premiers_trains.clear()
	fetes_faites.clear()
	_lignes_vues.clear()


func _bulle(liste: Array, args := []) -> String:
	var b: String = liste[rng.randi() % liste.size()]
	return b % args if b.contains("%") and not args.is_empty() else b


func nom_ville(vid: int) -> String:
	return String(communes.villages[vid].nom) if communes != null and communes.villages.has(vid) else "la ville"


## Mairie de la ville (position au sol), sinon le centre du village.
func pos_mairie(vid: int) -> Vector3:
	var v: Dictionary = communes.villages.get(vid, {})
	if v.is_empty():
		return Vector3.INF
	if int(v.bid) >= 0 and ev.buildings != null and ev.buildings.buildings.has(int(v.bid)):
		return ev.building_pos(int(v.bid))
	var c: Vector2 = v.c
	return Vector3(c.x, ev.ground(c.x, c.y), c.y)


## Années depuis la fondation si aujourd'hui est l'anniversaire (sinon 0).
func anniversaire(vid: int, n: Dictionary) -> int:
	var fonde := float(communes.villages[vid].get("fonde", 0.0))
	if fonde <= 0.0:
		return 0
	var off := ev.ambiance.utc_offset() * 3600.0 if ev.ambiance != null else 0.0
	var d := Time.get_datetime_dict_from_unix_time(int(fonde + off))
	if int(d.month) != int(n.month) or int(d.day) != int(n.mday):
		return 0
	var an := Time.get_datetime_dict_from_unix_time(int(ev.now() + off))
	return maxi(int(an.year) - int(d.year), 0)


# --- Planification (Evenements._new_day, réglage automatique) ------------------------

func plan_day(n: Dictionary) -> void:
	if communes == null:
		return
	var an: int = int(Time.get_datetime_dict_from_unix_time(int(ev.now())).year)
	for vid in communes.villages:
		var ans := anniversaire(int(vid), n)
		if ans < 1 or int(fetes_faites.get(vid, -1)) == int(an):
			continue
		if int(communes.stats.get(vid, {}).get("hab", 0)) < 30:
			continue
		var pos := pos_mairie(int(vid))
		if not pos.is_finite():
			continue
		fetes_faites[vid] = int(an)
		ev.ajouter("fete_ville", "Fête de la ville de %s (%d an%s)" % [nom_ville(int(vid)), ans, "s" if ans > 1 else ""],
			ev.unix_at(int(n.day), FETE_HEURES.x), ev.unix_at(int(n.day), FETE_HEURES.y), pos,
			int(communes.villages[vid].bid), {"vid": int(vid), "ans": ans})


## Le joueur organise la fête de la ville où regarde la caméra, ce soir (ou
## tout de suite s'il est déjà plus de 20 h). Renvoie l'id ou −1.
func organiser_fete(pos: Vector3) -> int:
	var vid := communes.village_au_point(pos.x, pos.z) if communes != null else -1
	if vid < 0:
		ev.buildings.message.emit("La fête de la ville se fait dans une ville : place la caméra au-dessus de l'une d'elles.")
		return -1
	for e in ev.events.values():
		if String(e.type) == "fete_ville" and int(e.data.get("vid", -1)) == vid and String(e.etat) != "fini":
			ev.buildings.message.emit("%s a déjà sa fête de prévue." % nom_ville(vid))
			return -1
	var cout := ReglagesPartie.prix(COUT_FETE_VILLE)
	if not ev._payer(cout, "organiser"):
		return -1
	var n := ev.local_now()
	var debut := ev.unix_at(int(n.day), FETE_HEURES.x)
	if ev.now() > debut:
		debut = ev.now()
	var fonde := float(communes.villages[vid].get("fonde", 0.0))
	var ans := 0
	if fonde > 0.0:
		ans = maxi(int(Time.get_datetime_dict_from_unix_time(int(ev.now())).year) - int(Time.get_datetime_dict_from_unix_time(int(fonde)).year), 0)
	var id := ev.ajouter("fete_ville", "Fête de la ville de %s" % nom_ville(vid), debut, ev.unix_at(int(n.day), FETE_HEURES.y),
		pos_mairie(vid), int(communes.villages[vid].bid), {"vid": vid, "ans": ans, "joueur": true}, false)
	ev.organises += 1
	ev.news("Fête de la ville de %s ce soir, feu d'artifice à 22 h (%s)." % [nom_ville(vid), BuildingSystem.format_money(cout)],
		pos_mairie(vid), "fete_ville", id)
	return id


## Inauguration d'un grand monument (signal Patrimoine.inaugure).
func on_inauguration(bid: int, nom: String) -> int:
	var pos := ev.building_pos(bid)
	if not pos.is_finite():
		return -1
	var t := ev.now()
	return ev.ajouter("inauguration", "Inauguration : %s" % nom, t, t + DUREE_INAUGURATION * 3600.0, pos, bid,
		{"monument": nom}, true)


## Lignes changées (StationSystem.lines_changed) : une nouvelle ligne de train
## de voyageurs dans une ville qui n'en avait pas → fête du premier train.
func verifier_trains() -> int:
	if stations == null:
		return -1
	var lance := -1
	for lid in stations.lines:
		if _lignes_vues.has(lid):
			continue
		_lignes_vues[lid] = true
		var l: Dictionary = stations.lines[lid]
		if String(l.kind) != "train" or bool(l.get("fret", false)) or (l.stops as Array).is_empty():
			continue
		var gare: Dictionary = stations.stations.get(int(l.stops[0]), {})
		if gare.is_empty():
			continue
		var pos: Vector3 = stations.network.node_pos(int(gare.node))
		var vid := communes.village_au_point(pos.x, pos.z) if communes != null else -1
		if premiers_trains.has(vid):
			continue
		premiers_trains[vid] = int(lid)
		var ou := nom_ville(vid) if vid >= 0 else String(gare.name)
		var t := ev.now()
		lance = ev.ajouter("premier_train", "Premier train de %s" % ou, t, t + DUREE_TRAIN * 3600.0, pos, -1,
			{"ligne": int(lid), "vid": vid, "gare": String(gare.name)}, true)
	return lance


## Après un chargement : les lignes existantes ne refont pas la fête.
func apres_chargement() -> void:
	_lignes_vues.clear()
	if stations == null:
		return
	for lid in stations.lines:
		_lignes_vues[lid] = true


# --- Déroulement ---------------------------------------------------------------------

func on_start(e: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "%s_%d" % [String(e.type), int(e.id)]
	root.position = e.pos
	var seed := int(e.id) * 7919
	var foule := clampi(20 + ev.population.persons.size() / 30, 20, 90) if ev.population != null else 30
	match String(e.type):
		"fete_ville":
			root.add_child(EvVisuels.fete(seed))
			root.add_child(EvVisuels.foule(foule, Vector2(16, 14), seed, Vector3(0, 0, -9)))
			ev.news("%s : la fête commence devant la mairie. Feu d'artifice à 22 h !" % String(e.nom), e.pos, "fete_ville", int(e.id))
		"inauguration":
			root.add_child(EvVisuels.foule(foule, Vector2(18, 10), seed, Vector3(0, 0, 0)))
			root.add_child(_ruban())
			_feux(e, root, FEUX_INAUGURATION, 18.0)
			Son.jouer_a("applaudissements", e.pos, 0.0, 600.0)
			_vol(e, "Classé monument historique · %d personnes au pied du ruban" % foule, _bulle(BULLES_INAUGURATION),
				110.0, "election_gagnee")
		"premier_train":
			root.add_child(EvVisuels.foule(foule, Vector2(14, 8), seed, Vector3(0, 0, 0)))
			Son.jouer_a("sifflet_vapeur", e.pos, 0.0, 800.0)
			Son.jouer_a("applaudissements", e.pos, -2.0, 600.0)
			var lid := int(e.data.get("ligne", -1))
			_vol(e, "Départ de la gare %s · %s" % [String(e.data.get("gare", "")), String(stations.lines[lid].name) if stations.lines.has(lid) else ""],
				_bulle(BULLES_TRAIN), 90.0, "sifflet_vapeur", func() -> Vector3: return position_rame(lid))
			ev.news("%s : la foule acclame le départ de la gare %s." % [String(e.nom), String(e.data.get("gare", ""))], e.pos, "premier_train", int(e.id))
	ev.visuels.add_child(root)
	e.node = root


func on_end(e: Dictionary) -> void:
	match String(e.type):
		"fete_ville":
			ev.news("%s : fini. Les derniers sont rentrés à pied, en chantant faux." % String(e.nom), e.pos, "fete_ville", int(e.id))
		"inauguration":
			ev.news("%s : la foule repart, le monument reste." % String(e.nom), e.pos, "inauguration", int(e.id))
		"premier_train":
			ev.news("%s : le train est arrivé à l'heure. On en parlera longtemps." % String(e.nom), e.pos, "premier_train", int(e.id))


## Le feu d'artifice de la fête de la ville part à 22 h.
func step(t: float, _dt: float) -> void:
	for e in ev.events.values():
		if String(e.type) != "fete_ville" or String(e.etat) != "en_cours" or bool(e.data.get("feux", false)):
			continue
		var n := ev.local_now()
		var feux := ev.unix_at(int(n.day), FEUX_HEURE)
		if t < feux and t < float(e.fin) - 1800.0:
			continue
		e.data.feux = true
		var node = e.get("node", null)
		if node == null or not is_instance_valid(node):
			continue
		_feux(e, node, FEUX_FETE, 30.0)
		var ans := int(e.data.get("ans", 0))
		_vol(e, "Le feu d'artifice de %s" % (("ses %d ans" % ans) if ans > 1 else ("son 1 an" if ans == 1 else "la fête")),
			_bulle(BULLES_FETE, [ans]) if ans > 1 else _bulle(BULLES_FETE.slice(1)), 130.0, "applaudissements")


func _feux(e: Dictionary, parent: Node3D, duree: float, rayon: float) -> void:
	var f := FeuxArtifice.new()
	f.duree = duree
	f.rayon = rayon
	f.rng.seed = int(e.id) * 104729 + 1
	f.avec_son = DisplayServer.get_name() != "headless"
	parent.add_child(f)
	e.data.feux = true


func _vol(e: Dictionary, sous_titre: String, bulle: String, rayon: float, son: String, suivre := Callable()) -> void:
	if filmer.is_valid():
		filmer.call({"centre": e.pos, "rayon": rayon, "titre": String(e.nom), "sous_titre": sous_titre, "bulle": bulle,
			"son": son, "suivre": suivre, "auto": true, "duree": 16.0 if suivre.is_valid() else 14.0})


## Position de la première rame d'une ligne (INF si elle n'est pas visible).
func position_rame(lid: int) -> Vector3:
	if traffic == null:
		return Vector3.INF
	for v in traffic.vehicles:
		if int(v.get("line", -1)) == lid and v.has("body"):
			var b: Node3D = v.body
			if is_instance_valid(b) and b.is_inside_tree() and b.visible:
				return b.global_position
	return Vector3.INF


## Ruban tricolore tendu entre deux poteaux (inauguration).
static func _ruban() -> Node3D:
	var k := EvVisuels._kit()
	for x in [-4.0, 4.0]:
		k.box(x, 0.0, 6.0, 0.12, 1.2, 0.12, Color("d4af37"))
	for i in 3:
		k.box(-4.0 + i * 8.0 / 3.0 + 4.0 / 3.0, 1.05, 6.0, 8.0 / 3.0, 0.12, 0.03, [Color("0055a4"), Color("f1faee"), Color("ef4135")][i])
	var m := EvVisuels._mesh_instance(k)
	m.name = "Ruban"
	return m


# --- Sauvegarde (dans la section evenements) ----------------------------------------

func to_dict() -> Dictionary:
	var pt := {}
	for k in premiers_trains:
		pt[str(k)] = premiers_trains[k]
	var ff := {}
	for k in fetes_faites:
		ff[str(k)] = fetes_faites[k]
	return {"premiers_trains": pt, "fetes": ff}


func from_dict(d: Dictionary) -> void:
	clear()
	for k in (d.get("premiers_trains", {}) as Dictionary):
		premiers_trains[int(k)] = int(d.premiers_trains[k])
	for k in (d.get("fetes", {}) as Dictionary):
		fetes_faites[int(k)] = int(d.fetes[k])
