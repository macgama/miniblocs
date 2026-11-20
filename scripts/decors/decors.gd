class_name Decors
extends RefCounted
## Catalogue des décors low-poly : mobilier urbain, clôtures, panneaux, marché,
## jeux, plage, ferme, cultures, animaux, bateaux, rochers…
##
## Les modèles sont faits dans Blender par tools/blender/decors_lowpoly.py, qui
## écrit aussi assets/modeles/decors/decors.json (nom, catégorie, taille).
## Ajouter un décor dans le script Blender suffit : le jeu le lit ici.

const DOSSIER := "res://assets/modeles/decors/"
const CATALOGUE := "res://assets/modeles/decors/decors.json"
const PALETTE := "res://assets/modeles/decors/palette_decors.png"
const PALETTE_LUMIERE := "res://assets/modeles/decors/palette_decors_lumiere.png"

static var _donnees: Dictionary = {}
static var _par_id: Dictionary = {}
static var _meshes: Dictionary = {}
static var _materiau: StandardMaterial3D


static func _charge() -> void:
	if not _donnees.is_empty():
		return
	var f := FileAccess.open(CATALOGUE, FileAccess.READ)
	if f == null:
		_donnees = {"categories": [], "decors": []}
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	_donnees = d if d is Dictionary else {"categories": [], "decors": []}
	for e: Dictionary in _donnees.decors:
		_par_id[String(e.id)] = e
	# Décors à thème du parc, dessinés en code (ParcThemes).
	ParcThemes.ajoute(_donnees, _par_id)


## [{id, nom}] dans l'ordre du panneau.
static func categories() -> Array:
	_charge()
	return _donnees.categories


## Tous les décors : [{id, nom, cat, taille [x, y (profondeur), z (hauteur)], triangles, ligne?, eau?, berge?, anime?}].
static func tous() -> Array:
	_charge()
	return _donnees.decors


static func de_categorie(cat: String) -> Array:
	var out := []
	for e: Dictionary in tous():
		if e.cat == cat:
			out.append(e)
	return out


static func existe(id: String) -> bool:
	_charge()
	return _par_id.has(id)


static func info(id: String) -> Dictionary:
	_charge()
	return _par_id.get(id, {})


## Prix de base par catégorie (€ pour un objet d'environ 1 m², piste CityRT 5) :
## banc ≈ 200 €, lampadaire ≈ 1 500 €, statue ≈ 18 000 €. Le prix grandit avec
## l'emprise au sol et la hauteur ; les clôtures se paient au tronçon.
const PRIX_CATEGORIE := {"urbain": 150, "eclairage": 1200, "monuments": 9000, "clotures": 60, "panneaux": 140,
	"marche": 250, "jeux": 1800, "plage": 120, "ferme": 350, "cultures": 25, "animaux": 900, "eau": 1600,
	"rochers": 80, "zoo": 2500, "zoo_objets": 600}


## Prix d'un décor posé à la main (€, multiplicateur des coûts de la partie compris).
## Les décors automatiques sont offerts.
static func prix(id: String) -> int:
	var e := info(id)
	if e.is_empty():
		return 0
	var base := float(PRIX_CATEGORIE.get(String(e.get("cat", "")), 200))
	var t: Array = e.get("taille", [1, 1, 1])
	var surface := maxf(float(t[0]) * float(t[1]), 0.3)
	var f := sqrt(surface) * (1.0 + 0.12 * clampf(float(t[2]) - 1.0, 0.0, 10.0))
	if ligne(id) > 0.0:
		f = maxf(float(t[0]), 1.0) * 0.6
	var brut := base * clampf(f, 0.5, 12.0)
	var arrondi := snappedf(brut, 10.0) if brut < 2000.0 else snappedf(brut, 100.0)
	return ReglagesPartie.prix(maxi(10, int(arrondi)))


static func nom(id: String) -> String:
	return String(info(id).get("nom", id))


## Hauteur (m) du modèle.
static func hauteur(id: String) -> float:
	var t: Array = info(id).get("taille", [1, 1, 1])
	return float(t[2])


## Plus grande dimension au sol (m).
static func emprise(id: String) -> float:
	var t: Array = info(id).get("taille", [1, 1, 1])
	return maxf(float(t[0]), float(t[1]))


## Longueur d'un tronçon de clôture (0 si ce n'est pas une clôture).
static func ligne(id: String) -> float:
	return float(info(id).get("ligne", 0.0))


static func est_anime(id: String) -> bool:
	return int(info(id).get("anime", 0)) == 1


## Posé sur l'eau (bateau, bouée : origine à la flottaison).
static func sur_eau(id: String) -> bool:
	return int(info(id).get("eau", 0)) == 1


## Distance (m) au-delà de laquelle le décor n'est plus dessiné.
static func distance_vue(id: String) -> float:
	var h := maxf(hauteur(id), emprise(id))
	if h < 1.3:
		return 160.0
	if h < 3.0:
		return 260.0
	if h < 8.0:
		return 420.0
	return 900.0


## Maillage du décor (null si le .glb n'est pas importé).
static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	if ParcThemes.est_theme(id):
		_meshes[id] = ParcThemes.mesh(id)
		return _meshes[id]
	var chemin := DOSSIER + id + ".glb"
	var m: Mesh = null
	if ResourceLoader.exists(chemin):
		var sc := load(chemin) as PackedScene
		if sc:
			var racine := sc.instantiate()
			var mi := _premier_mesh(racine)
			if mi:
				m = mi.mesh
			racine.free()
	_meshes[id] = m
	return m


static func _premier_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _premier_mesh(c)
		if r:
			return r
	return null


## Décor dessiné en code (couleurs par sommet, son propre matériau) ?
static func procedural(id: String) -> bool:
	return int(info(id).get("proc", 0)) == 1


## Le matériau commun à tous les décors : la palette, et les lanternes qui
## s'allument la nuit (set_nuit).
static func materiau() -> StandardMaterial3D:
	if _materiau:
		return _materiau
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	if ResourceLoader.exists(PALETTE):
		m.albedo_texture = load(PALETTE)
	if ResourceLoader.exists(PALETTE_LUMIERE):
		m.emission_enabled = true
		m.emission = Color.BLACK
		m.emission_texture = load(PALETTE_LUMIERE)
		m.emission_energy_multiplier = 0.0
	_materiau = m
	return m


## 0 (jour) à 1 (nuit noire) : allume les lanternes, phares et feux.
static func set_nuit(f: float) -> void:
	var m := materiau()
	if m.emission_enabled:
		m.emission = Color.WHITE if f > 0.0 else Color.BLACK
		m.emission_energy_multiplier = 0.4 + 3.0 * f if f > 0.0 else 0.0
