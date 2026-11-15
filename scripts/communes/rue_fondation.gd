class_name RueFondation
extends Node
## Rue offerte à la fondation d'une ville : dès qu'une Maison de commune (ou une
## mairie) fonde un village, une petite rue de village en T est posée devant sa
## façade, gratuite et prête tout de suite (pas de chantier), pour que le joueur
## puisse poser ses premières maisons sans attendre.
##
##   - La barre du T longe la façade (BARRE m), à RECUL m du mur : la porte de la
##     mairie donne dessus. La jambe du T part du milieu, droit devant (JAMBE m).
##   - Une seule rue, et c'est tout : pas de réseaux, pas de raccord à une autre voie.
##   - Si la façade ne laisse pas la place (relief trop raide, rivière, autre voie,
##     bâtiment), on essaie un T plus court, puis les autres côtés de la mairie.
##   - Rien si la mairie a déjà une voie devant sa porte (ancienne partie adoptée,
##     village fondé au bord d'une route).
##   - Réglage Admin (F10, Construction) : ReglagesPartie.rue_fondation, activé par
##     défaut ; décoché, on part de rien.
## Sauvegarde : section « rue_fondation » (mètres offerts par village, pour le tutoriel).

signal changed
signal message(text: String)

static var instance: RueFondation

## Classe de voie posée (rue de desserte, 30 km/h, trottoirs).
const CLASSE := "rue"
## Écart entre la façade et l'axe de la barre du T (m) : chaussée + trottoir + un parvis.
const RECUL := 8.0
## Longueurs [barre, jambe] essayées, de la plus grande à la plus petite (m).
const TAILLES := [[100.0, 60.0], [80.0, 45.0], [60.0, 30.0]]
## Distance à la porte en deçà de laquelle la mairie a déjà sa voie (m).
const DEJA_DESSERVIE := 12.0

var transport: TransportSystem
var buildings: BuildingSystem
var communes: Communes

## Mètres de rue offerts : vid -> m.
var offertes := {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(t: TransportSystem, b: BuildingSystem, c: Communes) -> void:
	transport = t
	buildings = b
	communes = c
	c.fonde.connect(_on_fonde)


func clear() -> void:
	offertes.clear()
	changed.emit()


## Total des mètres de rue offerts (tous villages).
static func metres_offerts() -> float:
	if instance == null:
		return 0.0
	var m := 0.0
	for vid in instance.offertes:
		m += float(instance.offertes[vid])
	return m


static func a_une_rue(vid: int) -> bool:
	return instance != null and instance.offertes.has(vid)


func _on_fonde(vid: int) -> void:
	if not ReglagesPartie.actuel.rue_fondation:
		return
	if communes == null or communes.ignorer or transport == null or buildings == null:
		return
	# Entre amis, le serveur pose la rue et l'envoie à tout le monde.
	if transport.bloque_reseau():
		return
	if not communes.villages.has(vid):
		return
	var bid := int(communes.villages[vid].bid)
	if bid < 0 or not buildings.buildings.has(bid):
		return
	poser(vid, bid)


## Pose le T devant le bâtiment bid. Renvoie les mètres posés (0 : pas de place).
func poser(vid: int, bid: int) -> float:
	var b: Dictionary = buildings.buildings[bid]
	var id := String(b.t)
	var r := int(b.r)
	var a := float(b.get("a", 0.0))
	var rect := buildings._rect_of(b)
	var t := BuildingCatalog.get_type(id)
	var door := BuildingSystem.door_point(id, rect, r, a)
	if _voie_pres(door):
		return 0.0
	var c3 := BuildingSystem.rect_center(rect)
	var c := Vector2(c3.x, c3.z)
	var f3 := BuildingSystem.front_dir(r).rotated(Vector3.UP, a)
	var f := Vector2(f3.x, f3.z).normalized()
	var s := Vector2(-f.y, f.x)
	var d := float(t.get("d", 10))
	var w := float(t.get("w", 10))
	# Façade d'abord, puis les côtés, puis l'arrière.
	var cotes := [[f, d], [s, w], [-s, w], [-f, d]]
	for cote in cotes:
		var dir: Vector2 = cote[0]
		var demi: float = float(cote[1]) * 0.5
		var lat := Vector2(-dir.y, dir.x)
		for taille in TAILLES:
			var barre: float = taille[0]
			var jambe: float = taille[1]
			var p := c + dir * (demi + RECUL)
			var m := _poser_t(p, lat, dir, barre, jambe)
			if m > 0.0:
				offertes[vid] = m
				var nom := String(communes.villages[vid].nom) if communes.villages.has(vid) else "le village"
				message.emit("Une rue en T est offerte devant la Maison de commune de %s (%d m) : pose tes premières maisons ou une zone résidentielle le long." % [nom, roundi(m)])
				changed.emit()
				return m
	message.emit("Pas de place pour la rue offerte devant la Maison de commune (relief, eau ou voie trop proches) : trace ta première rue avec l'outil Route.")
	return 0.0


## Une voie routière passe déjà près de la porte.
func _voie_pres(door: Vector3) -> bool:
	for eid in transport.edges_near(door, DEJA_DESSERVIE + 10.0):
		var e: Dictionary = transport.network.edges[eid]
		if TransportTypes.mode_of(String(e.t)) != TransportTypes.Mode.ROAD:
			continue
		var hit := transport.network.nearest_on_edge(eid, door)
		if float(hit.dist) <= DEJA_DESSERVIE + float(e.get("width", 4.0)) * 0.5:
			return true
	return false


## Barre de p - lat·barre/2 à p + lat·barre/2, puis jambe de p à p + dir·jambe.
## Tout ou rien : si la jambe ne passe pas, la barre est retirée.
func _poser_t(p: Vector2, lat: Vector2, dir: Vector2, barre: float, jambe: float) -> float:
	var spec := TransportTypes.default_spec(CLASSE)
	var pb := PackedVector2Array([p - lat * barre * 0.5, p + lat * barre * 0.5])
	var pj := PackedVector2Array([p, p + dir * jambe])
	# Essai à blanc des deux traits avant de poser quoi que ce soit.
	if not bool(transport.evaluate(CLASSE, spec, pb).ok):
		return 0.0
	if not bool(transport.evaluate(CLASSE, spec, PackedVector2Array([p + dir * 3.0, pj[1]])).ok):
		return 0.0
	var rb := transport.build_path(CLASSE, spec, pb)
	if not bool(rb.get("ok", false)):
		return 0.0
	var rj := transport.build_path(CLASSE, spec, pj)
	if not bool(rj.get("ok", false)):
		for eid in rb.get("edges", []):
			if transport.network.edges.has(eid):
				transport.network.remove_edge(int(eid))
		transport.network.changed.emit()
		return 0.0
	return barre + jambe


func to_dict() -> Dictionary:
	var o := {}
	for vid in offertes:
		o[str(vid)] = float(offertes[vid])
	return {"version": 1, "offertes": o}


func from_dict(d: Dictionary) -> void:
	offertes.clear()
	var o: Dictionary = d.get("offertes", {})
	for k in o:
		offertes[int(k)] = float(o[k])
	changed.emit()
