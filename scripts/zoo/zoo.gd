class_name ZooSysteme
extends Node3D
## Zoo : enclos tracés par le joueur, animaux et leur bien-être, soigneurs,
## vétérinaires, naissances, évasions, visiteurs, billets et note du zoo.
##
## - Une « Entrée du zoo » (ZooTypes) fonde un zoo. Les enclos et les bâtiments
##   du zoo à moins de RAYON mètres en font partie (au plus proche).
## - Un enclos = un polygone (tracé à la main) entouré d'une barrière
##   (ZooEspeces.BARRIERES). Ce qu'il contient se lit sur le terrain : sols peints
##   (biome_paint), eau creusée (water_cells), arbres, abris (bâtiments du zoo
##   posés dedans), objets d'enrichissement (décors « Objets des enclos »).
## - Chaque animal a sa santé, sa faim et son bien-être (0 à 100), calculé
##   d'après les besoins de son espèce : surface, sols, eau, abri (selon la
##   température du jour), taille du groupe, nourriture, propreté, jouets,
##   présence d'un prédateur dans l'enclos.
## - Les soigneurs (poste des soigneurs) nourrissent à 8 h et 15 h et
##   nettoient ; les vétérinaires (clinique) soignent ; les techniciens
##   (atelier) réparent les barrières, qui s'usent.
## - Une barrière trop faible, trop basse, une douve pour un nageur ou une
##   barrière usée : l'animal peut s'évader. Les soigneurs le rattrapent.
## - Couples adultes et heureux : naissances. Vieillesse, maladies : morts.
## - Visiteurs selon l'attrait des animaux, leur bien-être, les espèces
##   menacées, la vue sur les enclos, la note, le prix et la saison. Billets,
##   stands et dons pour la conservation → caisse de la ville de l'entrée.
## - Génétique (ZooGenetique) : gènes hérités (taille, santé, fertilité, longévité),
##   généalogie, consanguinité et diversité génétique de chaque groupe.
## - Échanges : réseau d'élevage des zoos partenaires (offres et demandes), échanges
##   entre zoos de la carte (autres villes, autres joueurs sur une carte entre amis),
##   arrivées à placer (expéditions : accueillir()), remise en liberté suivie.
## - Liens : groupes "avis_sources" (thème loisirs) et "pollution_sources" (odeurs).

signal changed
signal message(text: String)

static var instance: ZooSysteme

const RAYON := 400.0
## Pas de simulation (secondes de jeu) : une heure.
const STEP := 3600.0
const PRIX_ENTREE := 22.0
const TOURISTES_ATTRAIT := 9.0
const HABITANTS_JOUR := 0.004
const SAISON_PART := 0.5
const SAISON_X := 1.3
const ENTRETIEN_MOIS := 0.006
## Usure des barrières par jour (points sur 100).
const USURE_JOUR := 0.35
## Places d'animaux suivies par un soigneur.
const PLACES_SOIGNEUR := 20.0
## Livraison de nourriture sans cuisine : surcoût.
const LIVRAISON_X := 1.4
const MOIS_SAISON := {1: 0.35, 2: 0.4, 3: 0.6, 4: 0.9, 5: 1.0, 6: 1.05, 7: 1.5, 8: 1.5, 9: 0.85, 10: 0.85, 11: 0.4, 12: 0.5}
## Poids du bien-être.
const POIDS := {"espace": 0.17, "sols": 0.15, "eau": 0.08, "abri": 0.1, "groupe": 0.12, "faim": 0.14, "proprete": 0.08,
	"jouets": 0.08, "climat": 0.04, "calme": 0.04}
const BESOINS_NOMS := {"espace": "Espace", "sols": "Sols", "eau": "Eau", "abri": "Abri", "groupe": "Groupe", "faim": "Nourriture",
	"proprete": "Propreté", "jouets": "Enrichissement", "climat": "Température", "calme": "Tranquillité"}
const NOMS_ZOO := ["Zoo de la Tuilière", "Parc animalier des Trois Sources", "Zoo des Grands Espaces", "Réserve des Collines",
	"Zoo du Bois Joli", "Bioparc des Quatre Vents"]
const PRENOMS := ["Simba", "Nala", "Kibo", "Zuri", "Tika", "Baloo", "Mina", "Rafiki", "Kenya", "Pépite", "Caramel", "Moka",
	"Oscar", "Lulu", "Tonnerre", "Bambou", "Neige", "Flocon", "Gaston", "Hector", "Iris", "Jade", "Kali", "Léon", "Malou",
	"Nina", "Olga", "Pacha", "Quinoa", "Rocky", "Sahara", "Tango", "Uma", "Vanille", "Wally", "Xena", "Yoko", "Zéphyr",
	"Biscotte", "Cannelle", "Dakar", "Echo", "Fifi", "Gribouille", "Hugo", "Indigo", "Java", "Kiwi", "Lotus", "Mambo"]

## Ce que disent les visiteurs.
const PENSEES := {
	"super": "Quelle belle journée ! Les enfants veulent revenir demain.",
	"vu": "%s, vu de tout près. Magique.",
	"pas_vu": "%s ? Pas vu : il y a un mur entre nous.",
	"triste": "%s avait l'air malheureux. Ça gâche un peu la visite.",
	"menace": "%s : il en reste si peu dans la nature. Heureusement qu'il y a des zoos.",
	"faim": "Rien à manger dans ce zoo. Je comprends mieux les lions.",
	"soif": "Il fait soif et pas une buvette à l'horizon.",
	"toilettes": "Les toilettes ? Pas trouvées. On est rentrés plus tôt.",
	"cher": "%d € l'entrée ? Pour ce prix-là, je veux voir le panda faire du vélo.",
	"bon_prix": "Pour le prix, c'est une très bonne affaire.",
	"odeur": "Ça sent… l'authentique.",
	"evasion": "%s se promenait dans l'allée, les soigneurs couraient derrière. Inoubliable.",
	"peu": "Trois chèvres et un âne. On a vite fait le tour.",
	"repas": "%s : le repas de 15 h, c'était le meilleur moment.",
	"dons": "On a donné pour la conservation. Le panneau était très bien fait.",
	"pluie": "Le zoo sous la pluie : les animaux dorment, nous aussi presque.",
}

var buildings: BuildingSystem
var population: Population
var transport: TransportSystem
var ambiance: DayNight
var world: TerrainWorld
var decors: DecorSystem

## Entrée (bid) → zoo.
var zoos: Dictionary = {}
## Identifiant → enclos.
var enclos: Dictionary = {}
## Identifiant → animal.
var animaux: Dictionary = {}
var next_enclos := 1
var next_animal := 1
var clock := -1.0
var last_unix := -1.0
var last_day := -1
## Habitants allés au zoo : pid → jour.
var sorties: Dictionary = {}
## Tests : personnel complet, sans tenir compte des habitants.
var ignore_staff := false
var rng := RandomNumberGenerator.new()
## Bâtiments du zoo (bid → rôle), recalculés quand les bâtiments changent.
var items: Dictionary = {}
var _dirty := true
## Enclos dont le contenu (sols, eau, abris, objets) est à relire.
var _sales: Dictionary = {}
var visuels: ZooVisuels
## Généalogie de tous les animaux connus (même partis) : id → {esp, nom, f, pere, mere, F, naiss}.
var genealogie: Dictionary = {}
## Offres d'échange : id → offre (réseau d'élevage, ou d'un zoo de la carte à un autre).
var offres: Dictionary = {}
var next_offre := 1
## Animaux arrivés (expéditions, sauvetages) qui attendent un enclos : id → {zoo, animal, origine, jour}.
var arrivees: Dictionary = {}
var next_arrivee := 1
## Animaux relâchés dans la nature, suivis : [{nom, esp, zoo, jour, fin, chance, statut}].
var relaches: Array = []
## Animaux partis vers le réseau d'élevage (leurs petits peuvent revenir) : [{id, esp, f}].
var reseau: Array = []


func _init() -> void:
	rng.seed = 4_190_311
	add_to_group("avis_sources")
	add_to_group("pollution_sources")


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	visuels = ZooVisuels.new()
	visuels.name = "Visuels"
	visuels.setup(self)
	add_child(visuels)


func setup(b: BuildingSystem, p: Population, t: TransportSystem, a: DayNight, w: TerrainWorld = null, dec: DecorSystem = null) -> void:
	buildings = b
	population = p
	transport = t
	ambiance = a
	world = w if w != null else (b.world if b != null else null)
	decors = dec
	if buildings != null:
		buildings.changed.connect(func() -> void:
			_dirty = true
			_tout_relire())
	if world != null:
		world.terrain_edited.connect(func(_n: int) -> void: _tout_relire())
	if decors != null:
		decors.changed.connect(_tout_relire)


func clear() -> void:
	zoos.clear()
	enclos.clear()
	animaux.clear()
	sorties.clear()
	items.clear()
	genealogie.clear()
	offres.clear()
	arrivees.clear()
	relaches.clear()
	reseau.clear()
	next_offre = 1
	next_arrivee = 1
	next_enclos = 1
	next_animal = 1
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	_dirty = true
	changed.emit()


func _tout_relire() -> void:
	for id in enclos:
		_sales[id] = true


# --- Annuler (HistoriqueVille) -------------------------------------------------------------------

## Les enclos tracés et leurs animaux (ce que Ctrl+Z défait), sans le reste du zoo.
func enclos_dict() -> Dictionary:
	var d := to_dict()
	return {"enclos": d.enclos, "animaux": d.animaux, "next_enclos": next_enclos, "next_animal": next_animal}


## Remet les enclos et animaux d'enclos_dict() ; les zoos, offres et visiteurs restent.
func remettre_enclos(d: Dictionary) -> void:
	enclos.clear()
	animaux.clear()
	_sales.clear()
	_lire_enclos_animaux(d)
	for aid in animaux:
		var a: Dictionary = animaux[aid]
		if not genealogie.has(aid):
			genealogie[aid] = {"esp": a.esp, "nom": a.nom, "f": a.f, "pere": a.pere, "mere": a.mere, "F": a.consang,
				"naiss": float(a.naiss), "genes": a.genes}
	next_enclos = maxi(int(d.get("next_enclos", 1)), next_enclos)
	next_animal = maxi(int(d.get("next_animal", 1)), next_animal)
	_dirty = true
	changed.emit()


## Enclos et animaux d'une section (sauvegarde ou annuler).
func _lire_enclos_animaux(d: Dictionary) -> void:
	for k in (d.get("enclos", {}) as Dictionary):
		var e: Dictionary = d.enclos[k]
		var pts := PackedVector2Array()
		for p in e.get("pts", []):
			pts.append(Vector2(float(p[0]), float(p[1])))
		var id := int(k)
		enclos[id] = {"id": id, "nom": String(e.get("nom", "Enclos %d" % id)), "pts": pts, "barriere": String(e.get("barriere", "grillage")),
			"etat": float(e.get("etat", 100.0)), "propre": float(e.get("propre", 100.0)), "zoo": -1, "cache": {}}
		_sales[id] = true
	for k in (d.get("animaux", {}) as Dictionary):
		var a: Dictionary = (d.animaux[k] as Dictionary).duplicate()
		a.id = int(k)
		a.enclos = int(a.get("enclos", -1))
		a.f = bool(a.get("f", false))
		a.evade = bool(a.get("evade", false))
		a.malade = bool(a.get("malade", false))
		a.besoins = {}
		# Sauvegardes d'avant la génétique : fondateurs sans lien.
		if not a.get("genes") is Dictionary:
			a.genes = ZooGenetique.fondateur(rng)
		a.consang = float(a.get("consang", 0.0))
		a.pere = int(a.get("pere", -1))
		a.mere = int(a.get("mere", -1))
		a.tare = String(a.get("tare", ""))
		a.origine = String(a.get("origine", "elevage"))
		a.contra = bool(a.get("contra", false))
		if a.has("gest_pere"):
			a.gest_pere = int(a.gest_pere)
		animaux[int(k)] = a




# --- Bâtiments et zoos ---------------------------------------------------------------------------

static func _empty_stats() -> Dictionary:
	return {"visiteurs": 0, "touristes": 0, "habitants": 0, "billets": 0.0, "stands": 0.0, "dons": 0.0, "depenses": 0.0,
		"nourriture": 0.0, "naissances": 0, "morts": 0, "evasions": 0, "relaches": 0, "reussites": 0, "echanges": 0}


func _new_zoo(bid: int) -> Dictionary:
	return {"nom": NOMS_ZOO[(bid * 5 + zoos.size()) % NOMS_ZOO.size()], "prix": PRIX_ENTREE, "note": 2.5, "jour": _empty_stats(),
		"hier": _empty_stats(), "total": _empty_stats(), "pensees": {}, "dernieres": [], "presents": 0.0, "argent": 0.0,
		"conservation": 0.0, "prestige": 0.0}


func _sync() -> void:
	_dirty = false
	if buildings == null:
		return
	for bid in zoos.keys():
		if not buildings.buildings.has(bid) or ZooTypes.role_of(_type_of(int(bid))) != "entree":
			zoos.erase(bid)
	items.clear()
	for bid in buildings.buildings:
		var role := ZooTypes.role_of(String(buildings.buildings[bid].t))
		if role == "":
			continue
		items[bid] = role
		if role == "entree" and not zoos.has(bid):
			zoos[bid] = _new_zoo(int(bid))
	for id in enclos:
		enclos[id].zoo = _zoo_proche(_centre_enclos(int(id)))
	changed.emit()


func _zoo_proche(p: Vector2) -> int:
	var best := -1
	var best_d := RAYON
	for e in zoos:
		var c := _center(int(e))
		var d := p.distance_to(Vector2(c.x, c.z))
		if d <= best_d:
			best_d = d
			best = int(e)
	return best


func _type_of(bid: int) -> String:
	return String(buildings.buildings[bid].t) if buildings != null and buildings.buildings.has(bid) else ""


func _center(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)


func en_chantier(bid: int) -> bool:
	return buildings != null and buildings.en_chantier(bid)


## Bâtiments d'un rôle rattachés au zoo e (finis).
func items_of(e: int, role: String) -> Array:
	if _dirty:
		_sync()
	var out: Array = []
	if not zoos.has(e):
		return out
	var ce := _center(e)
	for bid in items:
		if String(items[bid]) != role or en_chantier(int(bid)):
			continue
		var c := _center(int(bid))
		if Vector2(c.x, c.z).distance_to(Vector2(ce.x, ce.z)) <= RAYON and _zoo_proche(Vector2(c.x, c.z)) == e:
			out.append(int(bid))
	return out


## Porte intérieure de l'entrée (côté zoo, à l'opposé de la route).
func portail(e: int) -> Vector3:
	var b: Dictionary = buildings.buildings[e]
	var f := BuildingSystem.front_dir(int(b.r)).rotated(Vector3.UP, float(b.get("a", 0.0)))
	return _center(e) - f * (float(BuildingCatalog.get_type(String(b.t)).get("d", 14)) / 2.0 + 3.0)


func personnel(bid: int) -> Array:
	var emplois := int(BuildingCatalog.get_type(_type_of(bid)).get("emplois", 0))
	if emplois <= 0 or ignore_staff or population == null:
		return [1.0, 0]
	var n := (population.by_job.get(bid, []) as Array).size()
	var f := clampf(float(n) / emplois, 0.0, 1.0)
	var s := 0
	if f < SAISON_PART:
		s = ceili((SAISON_PART - f) * emplois)
	return [clampf(f + float(s) / emplois, 0.0, 1.0), s]


## Effectif d'un métier dans les bâtiments d'un rôle du zoo.
func equipe(e: int, role: String, metier: String) -> float:
	var n := 0.0
	for bid in items_of(e, role):
		var f := float(personnel(int(bid))[0])
		for m in Metiers.jobs_for(_type_of(int(bid))):
			if String(m[0]) == metier:
				n += float(m[1]) * f
	return n


func soigneurs(e: int) -> float:
	return equipe(e, "soigneurs", "soigneur_animalier") + equipe(e, "cuisine", "soigneur_animalier") * 0.5 + equipe(e, "clinique", "soigneur_animalier") * 0.5


# --- Enclos ----------------------------------------------------------------------------------------

## Crée un enclos ; pts : sommets (x, z). Renvoie son identifiant (ou -1).
func ajouter_enclos(pts: PackedVector2Array, barriere := "grillage", payer := true) -> int:
	if pts.size() < 3:
		return -1
	var aire := absf(_aire(pts))
	if aire < 16.0:
		message.emit("Enclos trop petit (16 m² au moins).")
		return -1
	if not Geometry2D.triangulate_polygon(pts).size():
		message.emit("Tracé impossible : les côtés se croisent.")
		return -1
	var cout := perimetre(pts) * float(ZooEspeces.barriere(barriere).prix_m)
	if payer and not _peut_payer(cout):
		message.emit("Pas assez d'argent pour la barrière (%s)." % _euros(cout))
		return -1
	var id := next_enclos
	next_enclos += 1
	var c := _centroide(pts)
	enclos[id] = {"id": id, "nom": "Enclos %d" % id, "pts": pts.duplicate(), "barriere": barriere, "etat": 100.0, "propre": 100.0,
		"zoo": _zoo_proche(c), "cache": {}}
	_sales[id] = true
	if payer:
		_payer_ville(c, "Zoo : barrières", cout)
	changed.emit()
	return id


func retirer_enclos(id: int) -> void:
	if not enclos.has(id):
		return
	for aid in animaux_de(id):
		animaux.erase(aid)
	enclos.erase(id)
	_sales.erase(id)
	changed.emit()


func changer_barriere(id: int, barriere: String) -> bool:
	if not enclos.has(id) or not ZooEspeces.BARRIERES.has(barriere):
		return false
	var en: Dictionary = enclos[id]
	if String(en.barriere) == barriere:
		return false
	var cout := perimetre(en.pts) * float(ZooEspeces.barriere(barriere).prix_m)
	if not _peut_payer(cout):
		message.emit("Pas assez d'argent pour la nouvelle barrière (%s)." % _euros(cout))
		return false
	_payer_ville(_centroide(en.pts), "Zoo : barrières", cout)
	en.barriere = barriere
	en.etat = 100.0
	changed.emit()
	return true


func renommer_enclos(id: int, nom: String) -> void:
	if enclos.has(id) and nom.strip_edges() != "":
		enclos[id].nom = nom.strip_edges().left(40)
		changed.emit()


## Enclos qui contient le point (x, z), ou -1.
func enclos_a(p: Vector2) -> int:
	for id in enclos:
		if Geometry2D.is_point_in_polygon(p, enclos[id].pts):
			return int(id)
	return -1


static func _aire(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0


static func perimetre(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in pts.size():
		l += pts[i].distance_to(pts[(i + 1) % pts.size()])
	return l


static func _centroide(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(1.0, float(pts.size()))


func _centre_enclos(id: int) -> Vector2:
	return _centroide(enclos[id].pts)


func aire(id: int) -> float:
	return absf(_aire(enclos[id].pts)) if enclos.has(id) else 0.0


## Contenu d'un enclos (relu sur le terrain si besoin) : {aire, sols {sol: part},
## eau, abri (places), chaud, froid, jouets, arbres}.
func contenu(id: int) -> Dictionary:
	var en: Dictionary = enclos[id]
	if not _sales.has(id) and not (en.cache as Dictionary).is_empty():
		return en.cache
	_sales.erase(id)
	var pts: PackedVector2Array = en.pts
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	var a := absf(_aire(pts))
	var pas := 1 if a < 4000.0 else (2 if a < 16000.0 else 4)
	var sols := {}
	var n := 0
	var arbres := 0
	for x in range(floori(r.position.x), ceili(r.end.x), pas):
		for z in range(floori(r.position.y), ceili(r.end.y), pas):
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, z + 0.5), pts):
				continue
			var s := sol_de(Vector2i(x, z))
			sols[s] = int(sols.get(s, 0)) + 1
			n += 1
			if world != null and float(world.tree_paint.get(Vector2i(x, z), -1.0)) >= 2.0:
				arbres += 1
	var parts := {}
	for s in sols:
		parts[s] = float(sols[s]) / maxf(1.0, float(n))
	var abri := 0.0
	var chaud := false
	var froid := false
	if buildings != null:
		for bid in items:
			if String(items[bid]) != "abri" or en_chantier(int(bid)):
				continue
			var c := _center(int(bid))
			if Geometry2D.is_point_in_polygon(Vector2(c.x, c.z), pts):
				var sp := ZooTypes.spec_of(_type_of(int(bid)))
				abri += float(sp.get("places", 0))
				chaud = chaud or bool(sp.get("chaud", false))
				froid = froid or bool(sp.get("froid", false))
	var jouets := 0
	if decors != null:
		for o in objets_dans(id):
			if String(o) == "abri_paille":
				abri += 6.0
			elif String(o) != "panneau_espece" and String(o) != "longue_vue":
				jouets += 1
	en.cache = {"aire": a, "sols": parts, "eau": float(parts.get("eau", 0.0)), "abri": abri, "chaud": chaud, "froid": froid,
		"jouets": jouets, "arbres": arbres * pas * pas}
	return en.cache


## Sol d'une case pour le zoo.
func sol_de(c: Vector2i) -> String:
	if world == null:
		return "herbe"
	if world.water_cells.has(c):
		return "eau"
	var k := world.cell_biome(c)
	if world.biome_paint.has(c):
		k = int(world.biome_paint[c])
	return String(ZooEspeces.KIND_SOL.get(k, "herbe"))


## Décors posés dans un enclos (ids des modèles des catégories du zoo).
func objets_dans(id: int) -> Array:
	var out: Array = []
	if decors == null or not enclos.has(id):
		return out
	var pts: PackedVector2Array = enclos[id].pts
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	for k in decors.poses:
		for rr: Array in decors.poses[k]:
			var did := String(rr[0])
			if Decors.info(did).get("cat", "") != "zoo_objets":
				continue
			var p := Vector2(float(rr[1]), float(rr[3]))
			if r.has_point(p) and Geometry2D.is_point_in_polygon(p, pts):
				out.append(did)
	return out


# --- Animaux ----------------------------------------------------------------------------------------

func animaux_de(id: int) -> Array:
	var out: Array = []
	for aid in animaux:
		if int(animaux[aid].enclos) == id:
			out.append(int(aid))
	return out


func especes_de(id: int) -> Dictionary:
	var out := {}
	for aid in animaux_de(id):
		var e := String(animaux[aid].esp)
		out[e] = int(out.get(e, 0)) + 1
	return out


func jour_courant() -> float:
	var t := ambiance.unix_time if ambiance != null else clock
	return t / 86400.0


func age_ans(a: Dictionary) -> float:
	return maxf(0.0, (jour_courant() - float(a.naiss)) / 365.25)


## Achète et place un animal dans un enclos. femelle : -1 = au mieux pour le groupe.
func acheter(esp: String, id: int, femelle := -1, payer := true, age := -1.0) -> int:
	var e := ZooEspeces.espece(esp)
	if e.is_empty() or not enclos.has(id):
		return -1
	var c := _centre_enclos(id)
	var prix := float(e.prix)
	if payer and not _peut_payer(prix):
		message.emit("Pas assez d'argent pour %s (%s)." % [ZooEspeces.minuscule(String(e.nom)), _euros(prix)])
		return -1
	if payer:
		_payer_ville(c, "Zoo : achat d'animaux", prix)
	if femelle < 0:
		var m := 0
		var f := 0
		for aid in animaux_de(id):
			if String(animaux[aid].esp) == esp:
				if bool(animaux[aid].f):
					f += 1
				else:
					m += 1
		femelle = 1 if m > f else 0
	var ans := age if age >= 0.0 else rng.randf_range(float(e.maturite), float(e.maturite) + 4.0)
	return _naitre(esp, id, femelle == 1, jour_courant() - ans * 365.25, _point_dans(id))


## Un animal arrive (naissance, achat, échange) : pere/mere -1 = fondateur (lignée inconnue,
## sans lien avec les autres), genes vide = tirés au hasard.
func _naitre(esp: String, id: int, femelle: bool, naiss: float, pos: Vector2, pere := -1, mere := -1, genes: Dictionary = {},
		origine := "elevage", nom := "") -> int:
	var aid := next_animal
	next_animal += 1
	var consang := 0.0
	if genes.is_empty():
		if pere >= 0 and mere >= 0 and animal_connu(pere) and animal_connu(mere):
			genes = ZooGenetique.heritage(rng, _genes_de(pere), _genes_de(mere))
		else:
			genes = ZooGenetique.fondateur(rng, origine == "sauvage")
	if pere >= 0 and mere >= 0:
		consang = ZooGenetique.parente(genealogie, pere, mere)
	var tare := ""
	if consang >= ZooGenetique.SEUIL_TARE and rng.randf() < consang * 1.5:
		tare = ZooGenetique.TARES[rng.randi() % ZooGenetique.TARES.size()]
	var n := nom if nom != "" else String(PRENOMS[(aid * 7 + esp.length()) % PRENOMS.size()])
	animaux[aid] = {"id": aid, "esp": esp, "nom": n, "f": femelle,
		"naiss": naiss, "sante": 90.0, "bien": 70.0, "faim": 20.0, "enclos": id, "gest": -1.0, "pos": [pos.x, pos.y],
		"evade": false, "evade_h": 0.0, "malade": false, "besoins": {}, "genes": genes, "consang": snappedf(consang, 0.0001),
		"pere": pere, "mere": mere, "tare": tare, "origine": origine, "contra": false}
	genealogie[aid] = {"esp": esp, "nom": n, "f": femelle, "pere": pere, "mere": mere, "F": snappedf(consang, 0.0001), "naiss": naiss,
		"genes": genes}
	changed.emit()
	return aid


## L'animal (vivant ou parti) est-il dans la généalogie ?
func animal_connu(aid: int) -> bool:
	return genealogie.has(aid)


func _genes_de(aid: int) -> Dictionary:
	if animaux.has(aid):
		return animaux[aid].get("genes", {})
	return genealogie.get(aid, {}).get("genes", {})


## Gène effectif (avec la consanguinité et les tares) d'un animal vivant.
func gene(aid: int, g: String) -> float:
	return ZooGenetique.effectif(animaux[aid], g) if animaux.has(aid) else 0.0


## Durée de vie de cet animal (années) : celle de l'espèce, selon son gène de longévité.
func vie_de(a: Dictionary) -> float:
	var e := ZooEspeces.espece(String(a.esp))
	return float(e.get("vie", 20)) * (1.0 + 0.15 * ZooGenetique.effectif(a, "longevite"))


## Animaux d'une espèce dans un zoo (pour la diversité génétique).
func groupe_espece(e: int, esp: String) -> Array:
	var out: Array = []
	for aid in animaux_du_zoo(e):
		if String(animaux[aid].esp) == esp:
			out.append(aid)
	return out


func diversite(e: int, esp: String) -> float:
	return ZooGenetique.diversite(genealogie, groupe_espece(e, esp))


## Couples à risque dans un enclos (parents proches, parenté ≥ 12,5 %) : [[mâle, femelle, parenté]].
func couples_a_risque(id: int) -> Array:
	var out: Array = []
	var ids := animaux_de(id)
	var memo := {}
	for m in ids:
		var am: Dictionary = animaux[m]
		if bool(am.f) or bool(am.get("contra", false)):
			continue
		for f in ids:
			var af: Dictionary = animaux[f]
			if not bool(af.f) or bool(af.get("contra", false)) or String(af.esp) != String(am.esp):
				continue
			var k := ZooGenetique.parente(genealogie, int(m), int(f), memo)
			if k >= ZooGenetique.SEUIL_TARE:
				out.append([int(m), int(f), k])
	return out


## Contraception d'un animal (on évite les petits consanguins sans séparer le groupe).
func set_contraception(aid: int, on: bool) -> void:
	if animaux.has(aid):
		animaux[aid].contra = on
		changed.emit()


## Vend un animal à un autre zoo (moitié du prix, plus s'il est jeune et en forme).
func vendre(aid: int) -> void:
	if not animaux.has(aid):
		return
	var a: Dictionary = animaux[aid]
	var e := ZooEspeces.espece(String(a.esp))
	var prix := float(e.get("prix", 0)) * 0.5 * clampf(float(a.sante) / 100.0, 0.3, 1.0)
	if enclos.has(int(a.enclos)):
		_flux_ville(_centre_enclos(int(a.enclos)), "Zoo : vente d'animaux", prix)
	_retirer_offres_de(aid)
	animaux.erase(aid)
	_vers_reseau(aid, a)
	message.emit("%s (%s) part pour un autre zoo." % [String(a.nom), ZooEspeces.minuscule(String(e.get("nom", "")))])
	changed.emit()


func deplacer(aid: int, id: int) -> void:
	if animaux.has(aid) and enclos.has(id):
		animaux[aid].enclos = id
		var p := _point_dans(id)
		animaux[aid].pos = [p.x, p.y]
		changed.emit()


## Point au hasard dans un enclos.
func _point_dans(id: int) -> Vector2:
	var pts: PackedVector2Array = enclos[id].pts
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	for i in 30:
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if Geometry2D.is_point_in_polygon(p, pts):
			return p
	return _centroide(pts)


# --- Bien-être ---------------------------------------------------------------------------------------

func temperature() -> float:
	if ambiance == null or ambiance.weather == null:
		return 15.0
	return float(ambiance.weather.temperature)


## Besoins d'une espèce dans un enclos : {besoin: 0..1}, plus "problemes" (textes).
func besoins(esp: String, id: int) -> Dictionary:
	var e := ZooEspeces.espece(esp)
	var c := contenu(id)
	var esps := especes_de(id)
	var n := int(esps.get(esp, 0))
	var out := {}
	var pb: Array = []
	# Espace : surface demandée par tous les animaux de l'enclos.
	var besoin_m2 := 0.0
	for s in esps:
		besoin_m2 += float(ZooEspeces.espece(String(s)).get("m2", 50)) * float(esps[s])
	out.espace = clampf(float(c.aire) / maxf(besoin_m2, 1.0), 0.0, 1.0)
	if out.espace < 0.8:
		pb.append("Trop serrés : %d m² pour %d m² souhaités" % [int(c.aire), int(besoin_m2)])
	# Sols : écart entre ce qu'il y a et ce que l'espèce aime.
	var ecart := 0.0
	var sols: Dictionary = c.sols
	var prefs: Dictionary = e.get("sols", {})
	for s in ZooEspeces.SOLS_ORDRE:
		ecart += absf(float(sols.get(s, 0.0)) - float(prefs.get(s, 0.0)))
	out.sols = clampf(1.0 - ecart * 0.5, 0.0, 1.0)
	if out.sols < 0.7:
		var manque := ""
		var best := 0.0
		for s in prefs:
			var d := float(prefs[s]) - float(sols.get(s, 0.0))
			if d > best:
				best = d
				manque = String(s)
		if manque != "":
			pb.append("Sols : il manque %s (%d %% souhaités)" % [String(ZooEspeces.SOLS[manque].nom).to_lower(), roundi(float(prefs[manque]) * 100.0)])
	# Eau.
	var eau_v := float(e.get("eau", 0.0))
	out.eau = 1.0 if eau_v <= 0.0 else clampf(float(c.eau) / eau_v, 0.0, 1.0)
	if out.eau < 0.7:
		pb.append("Pas assez d'eau : %d %% de bassin, il en faut %d %%" % [roundi(float(c.eau) * 100.0), roundi(eau_v * 100.0)])
	# Abri (et température).
	var places := 0.0
	for s in esps:
		var es := ZooEspeces.espece(String(s))
		if bool(es.get("abri", false)):
			places += float(es.get("taille", 1)) * float(esps[s])
	var t := temperature()
	var clim: Array = e.get("climat", [-10, 35])
	var trop_froid := t < float(clim[0])
	var trop_chaud := t > float(clim[1])
	if bool(e.get("abri", false)):
		out.abri = clampf(float(c.abri) / maxf(places, 1.0), 0.0, 1.0)
		if out.abri < 0.8:
			pb.append("Abri trop petit : %d places pour %d" % [int(c.abri), int(places)])
	else:
		out.abri = 1.0
	if trop_froid:
		out.climat = 1.0 if (bool(c.chaud) or float(c.abri) >= places) and float(c.abri) > 0.0 else 0.2
		if out.climat < 1.0:
			pb.append("Il a froid : %d °C (il supporte %d °C) et pas d'abri chauffé" % [roundi(t), int(clim[0])])
	elif trop_chaud:
		out.climat = 1.0 if bool(c.froid) or (float(c.eau) > 0.1 and float(c.arbres) > 0.0) else 0.3
		if out.climat < 1.0:
			pb.append("Il a trop chaud : %d °C (il supporte %d °C)" % [roundi(t), int(clim[1])])
	else:
		out.climat = 1.0
	# Groupe.
	var g: Array = e.get("groupe", [1, 10])
	if n < int(g[0]):
		out.groupe = 0.4 + 0.6 * float(n) / float(g[0])
		pb.append("Se sent seul : %d sur %d au moins" % [n, int(g[0])])
	elif n > int(g[1]):
		out.groupe = clampf(float(g[1]) / float(n), 0.3, 1.0)
		pb.append("Groupe trop nombreux : %d pour %d au plus" % [n, int(g[1])])
	else:
		out.groupe = 1.0
	# Propreté, enrichissement.
	var en: Dictionary = enclos[id]
	out.proprete = clampf(float(en.propre) / 100.0, 0.0, 1.0)
	if out.proprete < 0.6:
		pb.append("Enclos sale : il faut plus de soigneurs")
	var tot := 0
	for s in esps:
		tot += int(esps[s])
	var jouets := float(c.jouets) + float(c.arbres) / 40.0
	out.jouets = clampf(jouets * 4.0 / maxf(float(tot), 1.0), 0.0, 1.0)
	if out.jouets < 0.6:
		pb.append("S'ennuie : ajouter des troncs, balles, plateformes ou arbres")
	# Prédateurs dans le même enclos.
	out.calme = 1.0
	if bool(e.get("proie", false)):
		for s in esps:
			if String(s) != esp and bool(ZooEspeces.espece(String(s)).get("fauve", false)):
				out.calme = 0.1
				pb.append("Vit avec un prédateur (%s) !" % ZooEspeces.nom_bas(String(s)))
				break
	# Barrière.
	var ok := ZooEspeces.barriere_ok(esp, String(en.barriere))
	if not bool(ok[0]):
		pb.append("Risque d'évasion : " + String(ok[1]))
	elif float(en.etat) < 40.0:
		pb.append("Barrière usée (%d %%) : risque d'évasion" % roundi(float(en.etat)))
	out.problemes = pb
	return out


## Bien-être cible (0 à 100) d'après les besoins et la faim.
static func bien_etre(bes: Dictionary, faim: float) -> float:
	var s := 0.0
	for k in POIDS:
		var v := 1.0 - clampf(faim / 100.0, 0.0, 1.0) if k == "faim" else float(bes.get(k, 1.0))
		s += v * float(POIDS[k])
	return clampf(s * 100.0, 0.0, 100.0)


## Bien-être moyen d'un enclos (ou d'un zoo si e >= 0).
func bien_moyen(ids: Array) -> float:
	if ids.is_empty():
		return 0.0
	var s := 0.0
	for aid in ids:
		s += float(animaux[aid].bien)
	return s / float(ids.size())


# --- Temps ----------------------------------------------------------------------------------------------

func _now(t: float) -> Dictionary:
	var off := ambiance.utc_offset() if ambiance != null else 0.0
	var local := t + off * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	return {"h": fposmod(local, 86400.0) / 3600.0, "wd": int(dt.weekday), "month": int(dt.month), "day": int(floorf(local / 86400.0))}


static func horaires(month: int) -> Vector2:
	if month in [4, 5, 6, 7, 8, 9]:
		return Vector2(9.0, 19.0)
	return Vector2(10.0, 17.0)


func _process(_delta: float) -> void:
	if ambiance == null:
		return
	var t := ambiance.unix_time
	if last_unix < 0.0:
		last_unix = t
		return
	var dt := clampf(t - last_unix, 0.0, 86400.0 * 2.0)
	last_unix = t
	if dt > 0.0:
		advance(dt)


func advance(dt: float) -> void:
	if _dirty:
		_sync()
	var end_t := (ambiance.unix_time if ambiance != null else clock + dt)
	if clock < 0.0 or absf(end_t - dt - clock) > 86400.0 * 3.0:
		clock = end_t - dt
	if last_day < 0:
		last_day = int(_now(clock).day)
	var n := 0
	while clock + STEP <= end_t + 0.001 and n < 60:
		clock += STEP
		n += 1
		step()
	if clock < end_t - 86400.0:
		clock = end_t


## Une heure de zoo.
func step() -> void:
	if _dirty:
		_sync()
	var now := _now(clock)
	if int(now.day) > last_day:
		last_day = int(now.day)
		new_day(now)
	if enclos.is_empty() and zoos.is_empty():
		return
	var h := int(floorf(float(now.h)))
	_soins(h)
	_evasions()
	for e in zoos:
		_visiteurs_heure(int(e), now)
	changed.emit()


## Repas (8 h, 15 h), nettoyage, santé et bien-être, heure par heure.
func _soins(h: int) -> void:
	var capa := {}
	for e in zoos:
		capa[e] = soigneurs(int(e)) * PLACES_SOIGNEUR
	var veto := {}
	for e in zoos:
		veto[e] = equipe(int(e), "clinique", "veterinaire_zoo")
	for id in enclos:
		var en: Dictionary = enclos[id]
		var z := int(en.zoo)
		var ids := animaux_de(int(id))
		var places := 0.0
		for aid in ids:
			places += float(ZooEspeces.espece(String(animaux[aid].esp)).get("taille", 1))
		# Les soigneurs suivent les enclos dans l'ordre, tant qu'il leur reste du temps.
		var couvert := 0.0
		if capa.has(z) and places > 0.0:
			couvert = clampf(float(capa[z]) / places, 0.0, 1.0)
			capa[z] = maxf(0.0, float(capa[z]) - places)
		en.propre = clampf(float(en.propre) - places * 0.12 + couvert * 4.0 * (1.0 if h >= 7 and h < 18 else 0.0), 0.0, 100.0)
		var besoins_esp := {}
		for aid in ids:
			var a: Dictionary = animaux[aid]
			if bool(a.evade):
				continue
			var esp := String(a.esp)
			var e := ZooEspeces.espece(esp)
			a.faim = clampf(float(a.faim) + 100.0 / 16.0, 0.0, 100.0)
			if (h == 8 or h == 15) and couvert > 0.0 and rng.randf() < couvert + 0.15:
				_nourrir(z, a)
			if not besoins_esp.has(esp):
				besoins_esp[esp] = besoins(esp, int(id))
			var bes: Dictionary = besoins_esp[esp]
			a.besoins = bes
			var cible := bien_etre(bes, float(a.faim))
			a.bien = lerpf(float(a.bien), cible, 0.15)
			# Santé : suit le bien-être ; les vétérinaires soignent.
			var v := float(veto.get(z, 0.0))
			var ds := (float(a.bien) - 55.0) * 0.02
			# Génétique : une santé fragile (ou une tare) fait tomber malade plus souvent.
			var gs := ZooGenetique.effectif(a, "sante")
			var fragile := clampf(1.0 - gs * 0.6, 0.4, 2.2)
			if gs < 0.0:
				ds -= -gs * 0.03
			if bool(a.malade):
				ds -= 0.6
				if v > 0.0 and rng.randf() < 0.08 * v:
					a.malade = false
				elif v <= 0.0 and rng.randf() < 0.01:
					a.malade = false
			elif (float(a.bien) < 40.0 and rng.randf() < 0.004 * fragile) or (gs < -0.3 and rng.randf() < 0.0004 * -gs):
				a.malade = true
				message.emit("%s (%s) est malade." % [String(a.nom), ZooEspeces.minuscule(String(e.nom))])
			a.sante = clampf(float(a.sante) + ds, 0.0, 100.0)


func _nourrir(z: int, a: Dictionary) -> void:
	var e := ZooEspeces.espece(String(a.esp))
	var kg := float(e.get("kg", 1.0)) * 0.5
	var prix := float(ZooEspeces.REGIMES.get(String(e.get("regime", "herbivore")), {}).get("prix_kg", 1.0)) * kg
	if zoos.has(z) and items_of(z, "cuisine").is_empty():
		prix *= LIVRAISON_X
	a.faim = maxf(0.0, float(a.faim) - 60.0)
	if zoos.has(z):
		zoos[z].jour.nourriture = float(zoos[z].jour.nourriture) + prix
		_payer(z, "Zoo : nourriture des animaux", prix)


## Évasions : barrière inadaptée ou usée. Les soigneurs rattrapent les fuyards.
func _evasions() -> void:
	for aid in animaux.keys():
		var a: Dictionary = animaux[aid]
		var id := int(a.enclos)
		if not enclos.has(id):
			continue
		var en: Dictionary = enclos[id]
		if bool(a.evade):
			a.evade_h = float(a.evade_h) + 1.0
			var sg := soigneurs(int(en.zoo)) if zoos.has(int(en.zoo)) else 0.0
			if a.evade_h >= (3.0 if sg > 0.0 else 10.0):
				a.evade = false
				a.evade_h = 0.0
				var p := _point_dans(id)
				a.pos = [p.x, p.y]
				message.emit("%s (%s) a été rattrapé et ramené dans son enclos." % [String(a.nom), ZooEspeces.nom_bas(String(a.esp))])
			continue
		var ok := ZooEspeces.barriere_ok(String(a.esp), String(en.barriere))
		var chance := 0.0
		if not bool(ok[0]):
			chance = 0.01
		elif float(en.etat) < 40.0:
			chance = (40.0 - float(en.etat)) / 40.0 * 0.004 * float(ZooEspeces.espece(String(a.esp)).get("niveau", 1))
		if float(a.bien) < 35.0:
			chance *= 2.0
		if chance > 0.0 and rng.randf() < chance:
			a.evade = true
			a.evade_h = 0.0
			var z := int(en.zoo)
			if zoos.has(z):
				zoos[z].jour.evasions = int(zoos[z].jour.evasions) + 1
				_penser(z, "evasion", [ZooEspeces.nom(String(a.esp))])
			var danger := " Les habitants s'enferment chez eux." if bool(ZooEspeces.espece(String(a.esp)).get("fauve", false)) else ""
			message.emit("Évasion ! %s (%s) est sorti de « %s ».%s" % [String(a.nom), ZooEspeces.nom_bas(String(a.esp)), String(en.nom), danger])


## Une nouvelle journée : barrières, naissances, vieillesse, prédateurs, comptes, note.
func new_day(now: Dictionary) -> void:
	for id in enclos:
		enclos[id].etat = maxf(0.0, float(enclos[id].etat) - USURE_JOUR)
	for e in zoos:
		var techs := equipe(int(e), "atelier", "technicien_zoo")
		var reste := techs * 6.0
		for id in enclos:
			if int(enclos[id].zoo) != int(e) or reste <= 0.0:
				continue
			var rep := minf(100.0 - float(enclos[id].etat), reste)
			enclos[id].etat = float(enclos[id].etat) + rep
			reste -= rep
	_naissances_et_morts()
	_predateurs()
	_suivre_relaches()
	_offres_du_jour()
	if int(now.day) % 7 == 0:
		_elaguer_genealogie()
	for e in zoos:
		var z: Dictionary = zoos[e]
		_charges(int(e))
		z.note = lerpf(float(z.note), note_cible(int(e)), 0.3)
		for k in z.jour:
			z.total[k] = z.total[k] + z.jour[k]
		z.hier = z.jour
		z.jour = _empty_stats()
		z.prestige = maxf(0.0, float(z.prestige) * 0.995)
	changed.emit()


func _naissances_et_morts() -> void:
	var jour := jour_courant()
	for aid in animaux.keys():
		if not animaux.has(aid):
			continue
		var a: Dictionary = animaux[aid]
		var e := ZooEspeces.espece(String(a.esp))
		var age := age_ans(a)
		# Vieillesse, maladie grave.
		var vie := vie_de(a)
		var mort := float(a.sante) <= 0.0 or (age > vie and rng.randf() < 0.02) or (age > vie * 1.3)
		if mort:
			var z := int(enclos.get(int(a.enclos), {}).get("zoo", -1))
			if zoos.has(z):
				zoos[z].jour.morts = int(zoos[z].jour.morts) + 1
			message.emit("%s (%s) est mort%s. Les soigneurs sont tristes." % [String(a.nom), ZooEspeces.minuscule(String(e.nom)),
				" de vieillesse" if age > vie else ""])
			animaux.erase(aid)
			continue
		# Gestation.
		if float(a.gest) >= 0.0:
			a.gest = float(a.gest) - 1.0
			if float(a.gest) <= 0.0:
				a.gest = -1.0
				var pmax := int(e.get("portee", 1))
				if ZooGenetique.effectif(a, "fertilite") < -0.5:
					pmax = maxi(1, pmax - 1)
				var n := maxi(1, rng.randi_range(1, pmax))
				var p := Vector2(float(a.pos[0]), float(a.pos[1]))
				var pere := int(a.get("gest_pere", -1))
				var tares := 0
				for i in n:
					var nid := _naitre(String(a.esp), int(a.enclos), rng.randf() < 0.5, jour, p + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)),
						pere, int(aid))
					if String(animaux[nid].tare) != "":
						tares += 1
				var z := int(enclos.get(int(a.enclos), {}).get("zoo", -1))
				if zoos.has(z):
					zoos[z].jour.naissances = int(zoos[z].jour.naissances) + n
				message.emit("Naissance au zoo : %d petit%s %s (%s) !" % [n, "s" if n > 1 else "", "de " + String(a.nom), ZooEspeces.minuscule(String(e.nom))])
				if tares > 0:
					message.emit("Le vétérinaire est inquiet : parents trop proches, %s porte une tare héréditaire. Pensez aux échanges ou à la contraception." % (
						"un des petits" if n > 1 else "le petit"))
			continue
		if not bool(a.f) or bool(a.evade) or bool(a.get("contra", false)) or age < float(e.get("maturite", 2)) or float(a.bien) < 70.0:
			continue
		# Un mâle adulte de la même espèce dans l'enclos (sans contraception), et de la place dans le groupe.
		var males: Array = []
		var nb := 0
		for bid in animaux_de(int(a.enclos)):
			var b: Dictionary = animaux[bid]
			if String(b.esp) != String(a.esp):
				continue
			nb += 1
			if not bool(b.f) and not bool(b.get("contra", false)) and not bool(b.evade) and age_ans(b) >= float(e.get("maturite", 2)):
				males.append(int(bid))
		var gmax := int((e.get("groupe", [1, 10]) as Array)[1])
		if males.is_empty() or nb >= gmax:
			continue
		var male := int(males[rng.randi() % males.size()])
		var fert := (ZooGenetique.effectif(a, "fertilite") + ZooGenetique.effectif(animaux[male], "fertilite")) * 0.5
		if rng.randf() < 1.0 / 120.0 * clampf(1.0 + 0.6 * fert, 0.15, 1.8):
			a.gest = float(e.get("gestation", 100))
			a.gest_pere = male


## Un prédateur et ses proies dans le même enclos : de temps en temps, une proie disparaît.
func _predateurs() -> void:
	for id in enclos:
		var esps := especes_de(int(id))
		var fauve := ""
		for s in esps:
			if bool(ZooEspeces.espece(String(s)).get("fauve", false)):
				fauve = String(s)
		if fauve == "":
			continue
		for aid in animaux_de(int(id)):
			var a: Dictionary = animaux[aid]
			if String(a.esp) != fauve and bool(ZooEspeces.espece(String(a.esp)).get("proie", false)) and rng.randf() < 0.15:
				message.emit("Drame dans « %s » : %s (%s) a servi de dîner à un %s. Les visiteurs sont choqués." % [
					String(enclos[id].nom), String(a.nom), ZooEspeces.nom_bas(String(a.esp)), ZooEspeces.nom_bas(fauve)])
				animaux.erase(aid)
				break


# --- Visiteurs ---------------------------------------------------------------------------------------

func est_ouvert(e: int, now: Dictionary) -> bool:
	if en_chantier(e) or animaux_du_zoo(e).is_empty():
		return false
	var hr := horaires(int(now.month))
	return float(now.h) >= hr.x and float(now.h) < hr.y


func animaux_du_zoo(e: int) -> Array:
	var out: Array = []
	for aid in animaux:
		var id := int(animaux[aid].enclos)
		if enclos.has(id) and int(enclos[id].zoo) == e:
			out.append(int(aid))
	return out


func enclos_du_zoo(e: int) -> Array:
	var out: Array = []
	for id in enclos:
		if int(enclos[id].zoo) == e:
			out.append(int(id))
	return out


## Qualité de la vue sur un enclos (barrière, belvédères proches).
func vue(id: int) -> float:
	var en: Dictionary = enclos[id]
	var v := float(ZooEspeces.barriere(String(en.barriere)).vue)
	var c := _centre_enclos(id)
	var z := int(en.zoo)
	if zoos.has(z):
		for bid in items_of(z, "vue"):
			var p := _center(int(bid))
			var portee := float(ZooTypes.spec_of(_type_of(int(bid))).get("portee", 60.0))
			if c.distance_to(Vector2(p.x, p.z)) < portee + sqrt(aire(id)) * 0.5:
				v = maxf(v, 0.85)
	return v


## Attrait du zoo : animaux vus, en forme, espèces menacées (rendements décroissants par espèce).
func attrait(e: int) -> float:
	var par_esp := {}
	for aid in animaux_du_zoo(e):
		var a: Dictionary = animaux[aid]
		if bool(a.evade):
			continue
		var esp := String(a.esp)
		var id := int(a.enclos)
		var k := esp + ":" + str(id)
		var f := (0.4 + 0.6 * float(a.bien) / 100.0) * (1.0 + ZooEspeces.uicn_bonus(esp)) * (0.3 + 0.7 * vue(id))
		if not par_esp.has(k):
			par_esp[k] = [esp, 0.0, 0]
		par_esp[k][1] = float(par_esp[k][1]) + f
		par_esp[k][2] = int(par_esp[k][2]) + 1
	var tot := 0.0
	for k in par_esp:
		var v: Array = par_esp[k]
		var esp := String(v[0])
		var moy := float(v[1]) / float(v[2])
		tot += float(ZooEspeces.espece(esp).get("attrait", 3.0)) * moy * sqrt(float(v[2]))
	return tot + float(zoos[e].prestige) * 0.05 if zoos.has(e) else tot


## L'entrée est-elle reliée à une route ?
func relie(e: int) -> bool:
	if buildings == null or not buildings.buildings.has(e):
		return false
	if transport == null:
		return true
	var b: Dictionary = buildings.buildings[e]
	var door := BuildingSystem.door_point(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0)))
	for eid in transport.edges_near(door, 40.0):
		if TransportTypes.mode_of(transport.network.edges[eid].t) == TransportTypes.Mode.ROAD:
			return true
	return false


func valeur(e: int) -> float:
	return 8.0 + 2.6 * pow(maxf(attrait(e), 0.0), 0.6)


func _pluie() -> float:
	if ambiance == null or ambiance.weather == null:
		return 0.0
	return clampf(float(ambiance.weather.precip), 0.0, 1.0)


## Visiteurs attendus sur la journée : [touristes, habitants].
func attendus(e: int, now: Dictionary) -> Array:
	var z: Dictionary = zoos[e]
	var a := attrait(e)
	if a <= 0.0:
		return [0.0, 0.0]
	var note_f := 0.35 + 0.65 * clampf(float(z.note) / 5.0, 0.0, 1.0)
	var saison := float(MOIS_SAISON.get(int(now.month), 1.0))
	var wd := int(now.wd)
	var jour := 1.7 if wd == 6 else (1.6 if wd == 0 else (1.15 if wd == 3 else 0.7))
	var meteo := 1.0 - 0.6 * _pluie()
	var prix := clampf(valeur(e) / maxf(float(z.prix), 1.0), 0.15, 1.3)
	var route := 1.0
	if not relie(e):
		route = 0.08
	var t := a * TOURISTES_ATTRAIT * note_f * saison * jour * meteo * prix * route
	# Clients des hôtels de la ville (Tourisme).
	t += Tourisme.visites("zoo", e) * meteo * clampf(prix, 0.4, 1.2)
	var hab := 0.0
	if population != null:
		hab = float(population.persons.size()) * HABITANTS_JOUR * saison * jour * meteo * prix * note_f
	return [t, hab]


func _visiteurs_heure(e: int, now: Dictionary) -> void:
	var z: Dictionary = zoos[e]
	if not est_ouvert(e, now):
		z.presents = maxf(0.0, float(z.presents) * 0.4)
		return
	var hr := horaires(int(now.month))
	var duree := maxf(1.0, hr.y - hr.x)
	var att := attendus(e, now)
	var h := float(now.h) - hr.x
	# Arrivées surtout le matin et en début d'après-midi.
	var poids := clampf(1.6 - h / duree * 1.8, 0.05, 1.6) / duree * 1.25
	var tour := float(att[0]) * poids
	var hab := float(att[1]) * poids
	var n := tour + hab
	z.presents = float(z.presents) * 0.72 + n
	var ni := floori(n + rng.randf())
	if ni <= 0:
		return
	var nt := roundi(float(ni) * tour / maxf(n, 0.001))
	z.jour.visiteurs = int(z.jour.visiteurs) + ni
	z.jour.touristes = int(z.jour.touristes) + nt
	z.jour.habitants = int(z.jour.habitants) + (ni - nt)
	_encaisser(e, "billets", float(z.prix) * ni * 0.85)
	if nt > 0:
		_flux(e, "Taxe de séjour", 1.5 * nt)
	# Stands : selon ce qui existe dans le zoo.
	var depense := 0.0
	for bid in items_of(e, "stand"):
		var sp := ZooTypes.spec_of(_type_of(int(bid)))
		var part := 0.45 if String(sp.vend) == "manger" else (0.5 if String(sp.vend) == "boire" else 0.18)
		depense += float(sp.prix) * part * ni * float(personnel(int(bid))[0]) / maxf(1.0, float(items_of(e, "stand").size()) * 0.5)
	if depense > 0.0:
		_encaisser(e, "stands", depense)
	# Dons pour la conservation (kiosques pédagogiques, espèces menacées).
	var ped := items_of(e, "pedago").size()
	if ped > 0:
		var dons := ni * (0.6 + 0.3 * mini(ped, 3)) * clampf(float(z.note) / 5.0, 0.2, 1.0)
		z.conservation = float(z.conservation) + dons
		_encaisser(e, "dons", dons)
		if rng.randf() < 0.2:
			_penser(e, "dons")
	if nt > 0 or (ni - nt) > 0:
		_pensees_heure(e, ni)
	if population != null and ni - nt > 0 and not population.persons.is_empty():
		var keys := population.persons.keys()
		for i in mini(ni - nt, 5):
			sorties[int(keys[rng.randi() % keys.size()])] = last_day


func _pensees_heure(e: int, n: int) -> void:
	var z: Dictionary = zoos[e]
	if rng.randf() > 0.5:
		return
	var ids := animaux_du_zoo(e)
	if ids.is_empty():
		_penser(e, "peu")
		return
	var a: Dictionary = animaux[ids[rng.randi() % ids.size()]]
	var esp := ZooEspeces.nom(String(a.esp))
	var id := int(a.enclos)
	if vue(id) < 0.3:
		_penser(e, "pas_vu", [esp])
	elif float(a.bien) < 40.0:
		_penser(e, "triste", [esp])
	elif ZooEspeces.uicn_bonus(String(a.esp)) >= 0.35 and rng.randf() < 0.4:
		_penser(e, "menace", [esp])
	else:
		_penser(e, "vu", [esp])
	if items_of(e, "stand").is_empty() and rng.randf() < 0.3:
		_penser(e, "faim")
	if items_of(e, "toilettes").is_empty() and rng.randf() < 0.3:
		_penser(e, "toilettes")
	if float(z.prix) > valeur(e) * 1.3 and rng.randf() < 0.4:
		_penser(e, "cher", [roundi(float(z.prix))])
	elif float(z.prix) < valeur(e) * 0.8 and rng.randf() < 0.2:
		_penser(e, "bon_prix")
	if _pluie() > 0.4 and rng.randf() < 0.3:
		_penser(e, "pluie")
	if ids.size() < 6 and rng.randf() < 0.3:
		_penser(e, "peu")
	elif rng.randf() < 0.1:
		_penser(e, "super")


func _penser(e: int, cle: String, args: Array = []) -> void:
	if not zoos.has(e):
		return
	var z: Dictionary = zoos[e]
	z.pensees[cle] = int(z.pensees.get(cle, 0)) + 1
	var txt := String(PENSEES.get(cle, cle))
	if not args.is_empty():
		txt = txt % args
	var d: Array = z.dernieres
	d.push_front(txt)
	if d.size() > 8:
		d.resize(8)


## Détail de la note : chaque critère de 0 à 1, et la note sur 5.
func detail_note(e: int) -> Dictionary:
	var ids := animaux_du_zoo(e)
	var esps := {}
	for aid in ids:
		esps[String(animaux[aid].esp)] = true
	var vues := 0.0
	var encl := enclos_du_zoo(e)
	for id in encl:
		vues += vue(int(id))
	var services := 0.0
	services += 0.4 if not items_of(e, "stand").is_empty() else 0.0
	services += 0.3 if not items_of(e, "toilettes").is_empty() else 0.0
	services += 0.15 if not items_of(e, "repos").is_empty() else 0.0
	services += 0.15 if not items_of(e, "pedago").is_empty() else 0.0
	var z: Dictionary = zoos[e]
	var d := {
		"variete": clampf(float(esps.size()) / 12.0, 0.0, 1.0),
		"bien": bien_moyen(ids) / 100.0,
		"vue": vues / maxf(1.0, float(encl.size())) if not encl.is_empty() else 0.0,
		"services": services,
		"prix": clampf(valeur(e) / maxf(float(z.prix), 1.0), 0.0, 1.0),
		"conservation": clampf(float(z.prestige) / 100.0 + _part_menacees(ids) + float(z.total.get("reussites", 0)) * 0.03, 0.0, 1.0),
	}
	var poids := {"variete": 0.22, "bien": 0.3, "vue": 0.14, "services": 0.14, "prix": 0.1, "conservation": 0.1}
	var note := 0.0
	for k in poids:
		note += float(d[k]) * float(poids[k])
	d["note"] = clampf(note * 5.0, 0.0, 5.0)
	return d


func _part_menacees(ids: Array) -> float:
	if ids.is_empty():
		return 0.0
	var n := 0
	for aid in ids:
		if ZooEspeces.uicn_bonus(String(animaux[aid].esp)) >= 0.2:
			n += 1
	return float(n) / float(ids.size()) * 0.6


func note_cible(e: int) -> float:
	return float(detail_note(e).note)


# --- Argent ---------------------------------------------------------------------------------------------

const POSTES := {"billets": "Zoo : billets", "stands": "Zoo : restauration et boutiques", "dons": "Zoo : dons pour la conservation"}


func _encaisser(e: int, quoi: String, montant: float) -> void:
	var z: Dictionary = zoos[e]
	match quoi:
		"billets": z.jour.billets = float(z.jour.billets) + montant
		"stands": z.jour.stands = float(z.jour.stands) + montant
		"dons": z.jour.dons = float(z.jour.dons) + montant
	_flux(e, String(POSTES.get(quoi, "Zoo")), montant)


func _payer(e: int, poste: String, montant: float) -> void:
	if zoos.has(e):
		zoos[e].jour.depenses = float(zoos[e].jour.depenses) + montant
	_flux(e, poste, -montant)


## Verse (ou prélève) dans la caisse de la ville où est l'entrée du zoo.
func _flux(e: int, poste: String, montant: float) -> void:
	if buildings == null or buildings.unlimited_money or absf(montant) < 0.01:
		return
	var prev := Pays.au_batiment(e)
	_flux_budget(poste, montant, zoos.get(e, {}))
	Pays.retour(prev)


func _flux_budget(poste: String, montant: float, acc: Dictionary) -> void:
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		if montant > 0.0:
			bc.recette(poste, montant)
		else:
			bc.depense(poste, -montant)
	elif buildings != null:
		var reste := float(acc.get("argent", 0.0)) + montant
		var whole := int(reste)
		buildings.money += whole
		if not acc.is_empty():
			acc.argent = reste - whole


## Dépense ou recette liée à un lieu (enclos) : caisse du zoo le plus proche, sinon de la ville chargée.
func _payer_ville(p: Vector2, poste: String, montant: float) -> void:
	_flux_ville(p, poste, -montant)


func _flux_ville(p: Vector2, poste: String, montant: float) -> void:
	var z := _zoo_proche(p)
	if z >= 0:
		if montant < 0.0:
			_payer(z, poste, -montant)
		else:
			_flux(z, poste, montant)
	elif buildings != null and not buildings.unlimited_money:
		_flux_budget(poste, montant, {})


func _peut_payer(montant: float) -> bool:
	return buildings == null or buildings.unlimited_money or float(buildings.money) >= montant


static func _euros(v: float) -> String:
	if absf(v) >= 1_000_000.0:
		return "%.1f M€" % (v / 1_000_000.0)
	if absf(v) >= 10_000.0:
		return "%d k€" % roundi(v / 1000.0)
	return "%d €" % roundi(v)


## Salaires et entretien du jour.
func _charges(e: int) -> void:
	var salaires := 0.0
	var entretien := 0.0
	var ce := _center(e)
	for bid in items:
		if en_chantier(int(bid)):
			continue
		var c := _center(int(bid))
		if _zoo_proche(Vector2(c.x, c.z)) != e:
			continue
		var t := _type_of(int(bid))
		entretien += float(BuildingCatalog.cost(t)) * ENTRETIEN_MOIS / 30.44
		var emplois := int(BuildingCatalog.get_type(t).get("emplois", 0))
		if emplois <= 0:
			continue
		var st := personnel(int(bid))
		var moyen := 0.0
		for m in Metiers.jobs_for(t):
			moyen += float(Metiers.job(String(m[0])).salaire) * float(m[1])
		moyen /= maxf(1.0, float(emplois))
		var tenus := float(st[0]) * emplois - float(st[1])
		salaires += (maxf(tenus, 0.0) * moyen + float(st[1]) * moyen * SAISON_X) / 30.44
	# Vétérinaire de campagne, sans clinique.
	if items_of(e, "clinique").is_empty() and not animaux_du_zoo(e).is_empty():
		entretien += 60.0
	# Enclos : barrières (entretien courant).
	for id in enclos_du_zoo(e):
		entretien += perimetre(enclos[id].pts) * float(ZooEspeces.barriere(String(enclos[id].barriere)).prix_m) * 0.0004
	if ce != Vector3.ZERO:
		_payer(e, "Zoo : salaires", salaires)
		_payer(e, "Zoo : entretien", entretien)


func set_prix(e: int, prix: float) -> void:
	if zoos.has(e):
		zoos[e].prix = clampf(prix, 0.0, 200.0)
		changed.emit()


func set_nom(e: int, nom: String) -> void:
	if zoos.has(e) and nom.strip_edges() != "":
		zoos[e].nom = nom.strip_edges().left(40)
		changed.emit()


# --- Liens avec les autres systèmes ------------------------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "zoo", "theme": "loisirs", "f": satisfaction_of}]


func satisfaction_of(p: Dictionary) -> Array:
	if zoos.is_empty() or population == null:
		return [0.0, []]
	var hp := Vector3.ZERO
	var home := population.home_of(p)
	if home >= 0:
		hp = population.building_pos(home)
	# Un fauve évadé dans le quartier.
	for aid in animaux:
		var a: Dictionary = animaux[aid]
		if bool(a.evade) and bool(ZooEspeces.espece(String(a.esp)).get("fauve", false)) and home >= 0:
			if Vector2(hp.x, hp.z).distance_to(Vector2(float(a.pos[0]), float(a.pos[1]))) < 1500.0:
				return [-6.0, ["− Un %s s'est échappé du zoo, on n'ose plus sortir" % ZooEspeces.nom_bas(String(a.esp))]]
	var pid := int(p.get("id", -1))
	if pid >= 0 and sorties.has(pid) and last_day - int(sorties[pid]) <= 30:
		return [2.5, ["+ Une belle journée au zoo"]]
	if home < 0:
		return [0.0, []]
	for e in zoos:
		var c := _center(int(e))
		if float(zoos[e].note) >= 3.0 and Vector2(hp.x, hp.z).distance_to(Vector2(c.x, c.z)) < 3000.0:
			return [1.2, ["+ Un beau zoo pas loin, les enfants l'adorent"]]
	return [0.0, []]


## Odeurs des enclos (et bruit des singes).
func pollution_sources() -> Array:
	var out: Array = []
	for id in enclos:
		var ids := animaux_de(int(id))
		if ids.is_empty():
			continue
		var places := 0.0
		for aid in ids:
			places += float(ZooEspeces.espece(String(animaux[aid].esp)).get("taille", 1))
		var c := _centre_enclos(int(id))
		var sale := 1.0 - float(enclos[id].propre) / 100.0
		out.append({"pos": Vector3(c.x, 0.0, c.y), "rayon": 80.0 + places * 2.0, "odeur": clampf(0.05 + places * 0.004 + sale * 0.4, 0.05, 0.7),
			"nom": String(enclos[id].nom)})
	return out


func summary() -> String:
	if zoos.is_empty():
		return ""
	var v := 0
	for e in zoos:
		v += int(zoos[e].hier.visiteurs)
	return "Zoo : %d visiteurs hier" % v


# --- Remise en liberté -----------------------------------------------------------------------------------

## Suivi d'un animal relâché (jours) avant de savoir s'il s'est adapté.
const RELACHE_SUIVI := 60
## Transport, colliers émetteurs, équipe sur place (€).
const RELACHE_PRIX := 2500.0


func zoo_de_animal(aid: int) -> int:
	if not animaux.has(aid):
		return -1
	return int(enclos.get(int(animaux[aid].enclos), {}).get("zoo", -1))


## Pourquoi cet animal ne peut pas être relâché ("" : il peut).
func raison_pas_relacher(aid: int) -> String:
	if not animaux.has(aid):
		return "Animal inconnu."
	var a: Dictionary = animaux[aid]
	var esp := String(a.esp)
	if ZooEspeces.uicn_bonus(esp) <= 0.0:
		return "Seules les espèces menacées sont relâchées dans la nature."
	if float(a.bien) < 60.0 or float(a.sante) < 60.0 or age_ans(a) < float(ZooEspeces.espece(esp).maturite) or bool(a.malade):
		return "Il faut un animal adulte et en forme (bien-être et santé 60 au moins)."
	if String(a.get("tare", "")) != "" or float(a.get("consang", 0.0)) >= 0.25:
		return "Le programme de réintroduction refuse les animaux trop consanguins ou porteurs d'une tare."
	return ""


## Chance qu'un animal relâché s'adapte à la vie sauvage (0 à 1).
func chance_relache(aid: int) -> float:
	if not animaux.has(aid):
		return 0.0
	var a: Dictionary = animaux[aid]
	var c := 0.3 + 0.2 * ZooGenetique.effectif(a, "sante") + float(a.bien) / 250.0 + float(a.sante) / 500.0
	if String(a.get("origine", "")) == "sauvage":
		c += 0.15
	c -= float(a.get("consang", 0.0)) * 1.5
	return clampf(c, 0.1, 0.95)


## Relâche un animal dans la nature (espèces menacées) : prestige tout de suite, puis
## suivi pendant RELACHE_SUIVI jours (s'il s'adapte : prestige et dons en plus).
func relacher(aid: int) -> bool:
	var r := raison_pas_relacher(aid)
	if r != "":
		message.emit(r)
		return false
	var a: Dictionary = animaux[aid]
	var esp := String(a.esp)
	var z := zoo_de_animal(aid)
	var chance := chance_relache(aid)
	if zoos.has(z):
		var qualite := clampf(1.0 - float(a.get("consang", 0.0)) * 3.0, 0.4, 1.0)
		zoos[z].prestige = float(zoos[z].prestige) + 10.0 * (1.0 + ZooEspeces.uicn_bonus(esp) * 4.0) * qualite
		zoos[z].jour.relaches = int(zoos[z].jour.get("relaches", 0)) + 1
		_payer(z, "Zoo : réintroductions", RELACHE_PRIX)
	relaches.push_front({"nom": String(a.nom), "esp": esp, "zoo": z, "jour": jour_courant(), "fin": jour_courant() + RELACHE_SUIVI,
		"chance": snappedf(chance, 0.01), "statut": "suivi"})
	if relaches.size() > 30:
		relaches.resize(30)
	_retirer_offres_de(aid)
	animaux.erase(aid)
	message.emit("%s retourne à la vie sauvage, avec un collier émetteur. Le prestige du zoo grimpe." % String(a.nom))
	changed.emit()
	return true


func _suivre_relaches() -> void:
	var jour := jour_courant()
	for r in relaches:
		if String(r.statut) != "suivi" or jour < float(r.fin):
			continue
		var z := int(r.zoo)
		var nom := "%s (%s)" % [String(r.nom), ZooEspeces.nom_bas(String(r.esp))]
		if rng.randf() < float(r.chance):
			r.statut = "reussi"
			if zoos.has(z):
				zoos[z].prestige = float(zoos[z].prestige) + 8.0 * (1.0 + ZooEspeces.uicn_bonus(String(r.esp)) * 4.0)
				zoos[z].jour.reussites = int(zoos[z].jour.get("reussites", 0)) + 1
				_encaisser(z, "dons", 1500.0 + 4000.0 * ZooEspeces.uicn_bonus(String(r.esp)))
			message.emit("Bonne nouvelle du terrain : %s s'est adapté à la vie sauvage. Les dons affluent." % nom)
		else:
			r.statut = "perdu"
			message.emit("Le collier de %s ne donne plus de signal. Les biologistes ont perdu sa trace." % nom)


# --- Réseau d'élevage et échanges ---------------------------------------------------------------------------

## Zoos partenaires (inventés) du réseau d'élevage.
const PARTENAIRES := ["Parc zoologique de Valdorne", "Zoo des Hautes-Rives", "Bioparc de Santa Ilha", "Tierpark Eichenhain",
	"Safari de Montbrisac", "Zoo royal de Kessenbourg", "Réserve de Kaoshan", "Parque de las Lomas Altas",
	"Wildlife Park Ashcombe", "Zoo de la Baie d'Oranne", "Jardin animalier de Corvallo", "Parc des Plateaux de Mbeya"]
const OFFRES_MAX := 6
const OFFRE_JOURS := 20
const RESEAU_MAX := 40


## Offres en cours visibles par un zoo : celles du réseau, et celles d'un zoo de la carte vers lui (ou de lui).
func offres_pour(z: int) -> Array:
	var out: Array = []
	for oid in offres:
		var o: Dictionary = offres[oid]
		if String(o.sorte) != "joueur" or int(o.vers) == z or int(o.de) == z:
			out.append(int(oid))
	return out


## Autres zoos de la carte (autres villes, autres joueurs) : [[entrée, nom]].
func autres_zoos(z: int) -> Array:
	var out: Array = []
	for b in zoos:
		if int(b) != z:
			out.append([int(b), String(zoos[b].nom)])
	return out


## Un animal acheté au réseau ou échangé : sa valeur pour l'élevage (rare chez nous = précieux).
func valeur_genetique(aid: int) -> float:
	if not animaux.has(aid):
		return 1.0
	var esp := String(animaux[aid].esp)
	var tous: Array = []
	for b in animaux:
		if String(animaux[b].esp) == esp:
			tous.append(b)
	var mk := ZooGenetique.parente_moyenne(genealogie, aid, tous)
	return clampf(1.3 - mk * 2.0, 0.6, 1.3)


func _offres_du_jour() -> void:
	var jour := jour_courant()
	for oid in offres.keys():
		var o: Dictionary = offres[oid]
		if float(o.expire) < jour or (String(o.sorte) == "joueur" and not animaux.has(int(o.aid))):
			offres.erase(oid)
	if zoos.is_empty():
		return
	var n := 0
	for oid in offres:
		if String(offres[oid].sorte) != "joueur":
			n += 1
	if n < OFFRES_MAX and rng.randf() < 0.35:
		nouvelle_offre_reseau()


## Le réseau propose un animal (« vente ») ou en demande un (« demande »).
func nouvelle_offre_reseau() -> int:
	var chez_nous := {}
	for aid in animaux:
		chez_nous[String(animaux[aid].esp)] = true
	var esp := ""
	if not chez_nous.is_empty() and rng.randf() < 0.65:
		var k: Array = chez_nous.keys()
		esp = String(k[rng.randi() % k.size()])
	else:
		esp = String(ZooEspeces.ORDRE[rng.randi() % ZooEspeces.ORDRE.size()])
	var e := ZooEspeces.espece(esp)
	var demande := chez_nous.has(esp) and rng.randf() < 0.45
	var oid := next_offre
	next_offre += 1
	var o := {"id": oid, "partenaire": String(PARTENAIRES[rng.randi() % PARTENAIRES.size()]), "esp": esp,
		"expire": jour_courant() + OFFRE_JOURS, "de": -1, "vers": -1, "aid": -1}
	if demande:
		o.sorte = "demande"
		o.f = rng.randi_range(-1, 1)
		o.prix = roundf(float(e.prix) * rng.randf_range(0.55, 0.8) / 10.0) * 10.0
		o.prestige = 2.0 + ZooEspeces.uicn_bonus(esp) * 12.0
	else:
		o.sorte = "vente"
		var f := rng.randf() < 0.5
		var ans := rng.randf_range(float(e.maturite), float(e.maturite) + 3.0)
		var pere := -1
		var mere := -1
		# Parfois, le petit d'un animal que nous avons cédé au réseau : attention à la parenté.
		var cedes: Array = []
		for r in reseau:
			if String(r.esp) == esp and genealogie.has(int(r.id)):
				cedes.append(r)
		if not cedes.is_empty() and rng.randf() < 0.4:
			var r: Dictionary = cedes[rng.randi() % cedes.size()]
			var autre := next_animal
			next_animal += 1
			genealogie[autre] = {"esp": esp, "nom": "", "f": not bool(r.f), "pere": -1, "mere": -1, "F": 0.0,
				"naiss": jour_courant() - (ans + float(e.maturite) + 2.0) * 365.25, "genes": ZooGenetique.fondateur(rng)}
			if bool(r.f):
				mere = int(r.id)
				pere = autre
			else:
				pere = int(r.id)
				mere = autre
		var genes := ZooGenetique.heritage(rng, _genes_de(pere), _genes_de(mere)) if pere >= 0 else ZooGenetique.fondateur(rng)
		o.f = 1 if f else 0
		o.prix = roundf(float(e.prix) * rng.randf_range(0.6, 0.9) / 10.0) * 10.0
		o.prestige = 0.0
		o.animal = {"nom": String(PRENOMS[rng.randi() % PRENOMS.size()]), "naiss": jour_courant() - ans * 365.25, "genes": genes,
			"pere": pere, "mere": mere}
	offres[oid] = o
	changed.emit()
	return oid


## Parenté (0 à 0,5) d'un animal proposé avec le groupe de son espèce dans un zoo.
func parente_offre(oid: int, z: int) -> float:
	if not offres.has(oid):
		return 0.0
	var o: Dictionary = offres[oid]
	var groupe := groupe_espece(z, String(o.esp))
	if String(o.sorte) == "joueur":
		return ZooGenetique.parente_moyenne(genealogie, int(o.aid), groupe)
	if String(o.sorte) != "vente":
		return 0.0
	var an: Dictionary = o.animal
	var memo := {}
	var s := 0.0
	for b in groupe:
		s += 0.5 * (ZooGenetique.parente(genealogie, int(an.pere), int(b), memo) + ZooGenetique.parente(genealogie, int(an.mere), int(b), memo))
	return s / float(groupe.size()) if not groupe.is_empty() else 0.0


## Accepte une offre (animal proposé par le réseau ou par un autre zoo de la carte) : il
## arrive dans l'enclos id, et la ville du zoo paie. "" : fait, sinon la raison.
func acheter_offre(oid: int, id: int) -> String:
	if not offres.has(oid):
		return _refus("Cette offre n'est plus valable.")
	if not enclos.has(id):
		return _refus("Choisissez un enclos.")
	var o: Dictionary = offres[oid]
	var z := int(enclos[id].zoo)
	var prix := float(o.prix)
	match String(o.sorte):
		"vente":
			if not _peut_payer(prix):
				return _refus("Pas assez d'argent (%s)." % _euros(prix))
			_payer_ville(_centre_enclos(id), "Zoo : échanges d'animaux", prix)
			var an: Dictionary = o.animal
			var nid := _naitre(String(o.esp), id, int(o.f) == 1, float(an.naiss), _point_dans(id), int(an.pere), int(an.mere),
				an.genes, "reseau", String(an.nom))
			if zoos.has(z):
				zoos[z].jour.echanges = int(zoos[z].jour.get("echanges", 0)) + 1
			offres.erase(oid)
			message.emit("%s (%s) arrive du %s." % [String(animaux[nid].nom), ZooEspeces.nom_bas(String(o.esp)), String(o.partenaire)])
		"joueur":
			var aid := int(o.aid)
			if not animaux.has(aid):
				offres.erase(oid)
				return _refus("L'animal proposé n'est plus là.")
			if z != int(o.vers):
				return _refus("Cet animal est proposé à %s : choisissez un de ses enclos." % _nom_zoo(int(o.vers)))
			if prix > 0.0 and not _peut_payer(prix):
				return _refus("Pas assez d'argent (%s)." % _euros(prix))
			_transferer(aid, id, int(o.de), z, prix)
			offres.erase(oid)
		_:
			return _refus("Cette offre demande un animal : utilisez « Envoyer ».")
	changed.emit()
	return ""


## Répond à une demande du réseau en envoyant l'animal aid : argent et prestige.
func repondre_demande(oid: int, aid: int) -> String:
	if not offres.has(oid) or String(offres[oid].sorte) != "demande":
		return _refus("Cette demande n'est plus valable.")
	if not animaux.has(aid):
		return _refus("Animal inconnu.")
	var o: Dictionary = offres[oid]
	var a: Dictionary = animaux[aid]
	if String(a.esp) != String(o.esp):
		return _refus("Le réseau demande un %s." % ZooEspeces.nom_bas(String(o.esp)))
	if int(o.f) >= 0 and bool(a.f) != (int(o.f) == 1):
		return _refus("Le réseau demande %s." % ("une femelle" if int(o.f) == 1 else "un mâle"))
	if age_ans(a) < float(ZooEspeces.espece(String(a.esp)).maturite) * 0.5 or bool(a.malade):
		return _refus("Le réseau veut un animal en bonne santé, pas trop jeune.")
	var z := zoo_de_animal(aid)
	var v := valeur_genetique(aid)
	var prix := float(o.prix) * v
	if zoos.has(z):
		zoos[z].prestige = float(zoos[z].prestige) + float(o.prestige) * v
		zoos[z].jour.echanges = int(zoos[z].jour.get("echanges", 0)) + 1
		_flux(z, "Zoo : échanges d'animaux", prix)
	_retirer_offres_de(aid)
	animaux.erase(aid)
	_vers_reseau(aid, a)
	offres.erase(oid)
	message.emit("%s part pour le %s (%s%s)." % [String(a.nom), String(o.partenaire), _euros(prix),
		", précieux pour le programme d'élevage" if v >= 1.15 else ""])
	changed.emit()
	return ""


## Refuse (ou retire) une offre.
func refuser_offre(oid: int) -> String:
	if not offres.has(oid):
		return ""
	var o: Dictionary = offres[oid]
	if String(o.sorte) == "joueur" and animaux.has(int(o.aid)):
		message.emit("L'échange de %s n'a pas lieu." % String(animaux[int(o.aid)].nom))
	offres.erase(oid)
	changed.emit()
	return ""


## Propose un animal à un autre zoo de la carte (entrée vers), pour prix (0 : don ou prêt).
## En solo, tous les zoos sont à vous : l'animal part tout de suite. Sur une carte entre
## amis, le maire de la ville du zoo choisi accepte ou refuse (onglet Échanges).
func proposer_echange(aid: int, vers: int, prix := 0.0) -> String:
	if not animaux.has(aid):
		return _refus("Animal inconnu.")
	var de := zoo_de_animal(aid)
	if not zoos.has(vers) or vers == de:
		return _refus("Choisissez un autre zoo.")
	prix = maxf(0.0, roundf(prix))
	for oid in offres:
		if String(offres[oid].sorte) == "joueur" and int(offres[oid].aid) == aid:
			return _refus("%s est déjà proposé à un zoo." % String(animaux[aid].nom))
	if echanges_directs():
		var id := _meilleur_enclos(vers, String(animaux[aid].esp))
		if id < 0:
			return _refus("%s n'a pas encore d'enclos." % _nom_zoo(vers))
		_transferer(aid, id, de, vers, prix)
		changed.emit()
		return ""
	var oid := next_offre
	next_offre += 1
	offres[oid] = {"id": oid, "sorte": "joueur", "partenaire": _nom_zoo(de), "esp": String(animaux[aid].esp),
		"f": 1 if bool(animaux[aid].f) else 0, "prix": prix, "expire": jour_courant() + OFFRE_JOURS, "de": de, "vers": vers,
		"aid": aid, "prestige": 0.0}
	message.emit("%s est proposé à %s%s." % [String(animaux[aid].nom), _nom_zoo(vers), " pour " + _euros(prix) if prix > 0.0 else " (don)"])
	changed.emit()
	return ""


## Échanges tout de suite (solo, tests) ; sur le serveur d'une carte entre amis, on attend l'autre maire.
var echanges_directs_force := -1


func echanges_directs() -> bool:
	if echanges_directs_force >= 0:
		return echanges_directs_force == 1
	return Multijoueur.role == Multijoueur.Role.SOLO


func _transferer(aid: int, id: int, de: int, vers: int, prix: float) -> void:
	var a: Dictionary = animaux[aid]
	if prix > 0.0:
		_payer(vers, "Zoo : échanges d'animaux", prix)
		_flux(de, "Zoo : échanges d'animaux", prix)
	a.enclos = id
	var p := _point_dans(id)
	a.pos = [p.x, p.y]
	a.evade = false
	for z in [de, vers]:
		if zoos.has(z):
			zoos[z].jour.echanges = int(zoos[z].jour.get("echanges", 0)) + 1
	message.emit("%s (%s) quitte %s pour %s." % [String(a.nom), ZooEspeces.nom_bas(String(a.esp)), _nom_zoo(de), _nom_zoo(vers)])


## Le meilleur enclos d'un zoo pour une espèce : celui où elle vit déjà, sinon le plus adapté.
func _meilleur_enclos(z: int, esp: String) -> int:
	var best := -1
	var score := -1.0
	for id in enclos_du_zoo(z):
		var s := bien_etre(besoins(esp, int(id)), 20.0) + (100.0 if especes_de(int(id)).has(esp) else 0.0)
		if s > score:
			score = s
			best = int(id)
	return best


func _nom_zoo(z: int) -> String:
	return String(zoos[z].nom) if zoos.has(z) else "un autre zoo"


func _refus(t: String) -> String:
	message.emit(t)
	return t


func _retirer_offres_de(aid: int) -> void:
	for oid in offres.keys():
		if String(offres[oid].sorte) == "joueur" and int(offres[oid].aid) == aid:
			offres.erase(oid)


## Un animal parti vers le réseau : on garde sa trace (ses petits peuvent revenir).
func _vers_reseau(aid: int, a: Dictionary) -> void:
	reseau.push_front({"id": aid, "esp": String(a.esp), "f": bool(a.f)})
	if reseau.size() > RESEAU_MAX:
		reseau.resize(RESEAU_MAX)


# --- Arrivées (expéditions, sauvetages) -----------------------------------------------------------------------

## Point d'entrée pour les expéditions (et tout ce qui ramène un animal) : un animal
## arrive au zoo z (-1 : le premier). Il attend un enclos dans l'onglet Échanges, sauf si
## extra.enclos est donné. extra : "nom", "f" (bool), "age" (ans), "genes", "enclos",
## "texte" (message). origine : "expedition", "sauvetage", "sauvage"… (animal sauvage :
## fondateur, gènes variés). Renvoie l'id de l'arrivée (ou -(id animal) s'il est placé), 0 si refusé.
func accueillir(esp: String, z := -1, origine := "expedition", extra: Dictionary = {}) -> int:
	var e := ZooEspeces.espece(esp)
	if e.is_empty():
		return 0
	if not zoos.has(z):
		z = int(zoos.keys()[0]) if not zoos.is_empty() else -1
	var ans := float(extra.get("age", rng.randf_range(float(e.maturite), float(e.maturite) + 5.0)))
	var an := {"nom": String(extra.get("nom", PRENOMS[rng.randi() % PRENOMS.size()])), "f": bool(extra.get("f", rng.randf() < 0.5)),
		"naiss": jour_courant() - ans * 365.25, "genes": extra.get("genes", ZooGenetique.fondateur(rng, true))}
	var texte := String(extra.get("texte", ""))
	var id := int(extra.get("enclos", -1))
	if enclos.has(id):
		var aid := _naitre(esp, id, bool(an.f), float(an.naiss), _point_dans(id), -1, -1, an.genes, origine, String(an.nom))
		message.emit(texte if texte != "" else "%s (%s) arrive au zoo." % [String(an.nom), ZooEspeces.nom_bas(esp)])
		return -aid
	var rid := next_arrivee
	next_arrivee += 1
	arrivees[rid] = {"id": rid, "zoo": z, "esp": esp, "animal": an, "origine": origine, "jour": jour_courant()}
	message.emit(texte if texte != "" else "%s (%s) est arrivé%s : il attend un enclos (zoo, onglet Échanges)." % [
		String(an.nom), ZooEspeces.nom_bas(esp), " de l'expédition" if origine == "expedition" else ""])
	changed.emit()
	return rid


## Arrivées qui attendent un enclos dans un zoo (et celles sans zoo).
func arrivees_de(z: int) -> Array:
	var out: Array = []
	for rid in arrivees:
		if int(arrivees[rid].zoo) == z or not zoos.has(int(arrivees[rid].zoo)):
			out.append(int(rid))
	return out


func placer_arrivee(rid: int, id: int) -> String:
	if not arrivees.has(rid):
		return _refus("Cet animal n'attend plus.")
	if not enclos.has(id):
		return _refus("Choisissez un enclos.")
	var r: Dictionary = arrivees[rid]
	var an: Dictionary = r.animal
	var aid := _naitre(String(r.esp), id, bool(an.f), float(an.naiss), _point_dans(id), -1, -1, an.genes, String(r.origine), String(an.nom))
	arrivees.erase(rid)
	message.emit("%s s'installe dans « %s »." % [String(animaux[aid].nom), String(enclos[id].nom)])
	changed.emit()
	return ""


## Confie une arrivée au réseau d'élevage (moitié du prix de l'espèce).
func ceder_arrivee(rid: int) -> String:
	if not arrivees.has(rid):
		return ""
	var r: Dictionary = arrivees[rid]
	var prix := float(ZooEspeces.espece(String(r.esp)).get("prix", 0)) * 0.5
	if zoos.has(int(r.zoo)):
		_flux(int(r.zoo), "Zoo : échanges d'animaux", prix)
	arrivees.erase(rid)
	message.emit("%s est confié au réseau d'élevage (%s)." % [String(r.animal.nom), _euros(prix)])
	changed.emit()
	return ""


## La généalogie ne garde que les ancêtres utiles (animaux présents, offres, réseau).
func _elaguer_genealogie() -> void:
	var garder := {}
	for aid in animaux:
		ZooGenetique.ancetres(genealogie, int(aid), garder)
		ZooGenetique.ancetres(genealogie, int(animaux[aid].get("gest_pere", -1)), garder)
	for oid in offres:
		var an: Variant = offres[oid].get("animal")
		if an is Dictionary:
			ZooGenetique.ancetres(genealogie, int(an.pere), garder)
			ZooGenetique.ancetres(genealogie, int(an.mere), garder)
	for r in reseau:
		ZooGenetique.ancetres(genealogie, int(r.id), garder)
	for k in genealogie.keys():
		if not garder.has(k):
			genealogie.erase(k)


# --- Sauvegarde --------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var en := {}
	for id in enclos:
		var e: Dictionary = enclos[id]
		var pts: Array = []
		for p in (e.pts as PackedVector2Array):
			pts.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		en[str(id)] = {"nom": e.nom, "pts": pts, "barriere": e.barriere, "etat": e.etat, "propre": e.propre}
	var an := {}
	for aid in animaux:
		var a: Dictionary = animaux[aid].duplicate()
		a.erase("besoins")
		an[str(aid)] = a
	var zs := {}
	for b in zoos:
		var z: Dictionary = zoos[b]
		zs[str(b)] = {"nom": z.nom, "prix": z.prix, "note": z.note, "total": z.total, "hier": z.hier, "conservation": z.conservation,
			"prestige": z.prestige}
	var gen := {}
	for k in genealogie:
		gen[str(k)] = genealogie[k]
	var of := {}
	for k in offres:
		of[str(k)] = offres[k]
	var ar := {}
	for k in arrivees:
		ar[str(k)] = arrivees[k]
	return {"v": 2, "enclos": en, "animaux": an, "zoos": zs, "next_enclos": next_enclos, "next_animal": next_animal,
		"genealogie": gen, "offres": of, "next_offre": next_offre, "arrivees": ar, "next_arrivee": next_arrivee,
		"relaches": relaches.duplicate(true), "reseau": reseau.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	_lire_enclos_animaux(d)
	for k in (d.get("genealogie", {}) as Dictionary):
		var g: Dictionary = (d.genealogie[k] as Dictionary).duplicate()
		g.pere = int(g.get("pere", -1))
		g.mere = int(g.get("mere", -1))
		g.F = float(g.get("F", 0.0))
		g.naiss = float(g.get("naiss", 0.0))
		genealogie[int(k)] = g
	for aid in animaux:
		var a: Dictionary = animaux[aid]
		if not genealogie.has(aid):
			genealogie[aid] = {"esp": a.esp, "nom": a.nom, "f": a.f, "pere": a.pere, "mere": a.mere, "F": a.consang,
				"naiss": float(a.naiss), "genes": a.genes}
	for k in (d.get("offres", {}) as Dictionary):
		var o: Dictionary = (d.offres[k] as Dictionary).duplicate(true)
		for c in ["id", "f", "de", "vers", "aid"]:
			o[c] = int(o.get(c, -1))
		o.id = int(k)
		if o.get("animal") is Dictionary:
			o.animal.pere = int(o.animal.get("pere", -1))
			o.animal.mere = int(o.animal.get("mere", -1))
		offres[int(k)] = o
	for k in (d.get("arrivees", {}) as Dictionary):
		var r: Dictionary = (d.arrivees[k] as Dictionary).duplicate(true)
		r.id = int(k)
		r.zoo = int(r.get("zoo", -1))
		arrivees[int(k)] = r
	for r in d.get("relaches", []):
		if r is Dictionary:
			var x: Dictionary = (r as Dictionary).duplicate()
			x.zoo = int(x.get("zoo", -1))
			relaches.append(x)
	for r in d.get("reseau", []):
		if r is Dictionary:
			reseau.append({"id": int(r.get("id", -1)), "esp": String(r.get("esp", "")), "f": bool(r.get("f", false))})
	next_offre = maxi(int(d.get("next_offre", 1)), next_offre)
	next_arrivee = maxi(int(d.get("next_arrivee", 1)), next_arrivee)
	for k in offres:
		next_offre = maxi(next_offre, int(k) + 1)
	for k in arrivees:
		next_arrivee = maxi(next_arrivee, int(k) + 1)
	var zs: Dictionary = d.get("zoos", {})
	next_enclos = maxi(int(d.get("next_enclos", 1)), next_enclos)
	next_animal = maxi(int(d.get("next_animal", 1)), next_animal)
	for id in enclos:
		next_enclos = maxi(next_enclos, int(id) + 1)
	for aid in animaux:
		next_animal = maxi(next_animal, int(aid) + 1)
	for aid in genealogie:
		next_animal = maxi(next_animal, int(aid) + 1)
	_dirty = true
	_sync()
	for k in zs:
		var b := int(k)
		if zoos.has(b):
			var z: Dictionary = zoos[b]
			var s: Dictionary = zs[k]
			z.nom = String(s.get("nom", z.nom))
			z.prix = float(s.get("prix", PRIX_ENTREE))
			z.note = float(s.get("note", 2.5))
			z.conservation = float(s.get("conservation", 0.0))
			z.prestige = float(s.get("prestige", 0.0))
			for kk in ["total", "hier"]:
				var st: Dictionary = _empty_stats()
				st.merge(s.get(kk, {}), true)
				z[kk] = st
	changed.emit()
