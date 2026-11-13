class_name Communes
extends Node3D
## Villages du joueur et leur territoire (panneau Villages, Maj+M).
##
## Une partie commence par la pose d'un bâtiment fondateur (Maison de commune ou
## Mairie) : il fonde le village et lui donne un territoire en carrés de 100 m
## autour de lui. Le territoire grandit tout seul avec la population (paliers
## Hameau, Village, Bourg, Ville, Grande ville) ; on peut aussi acheter un carré
## voisin (annexer) ou en céder un. Un bâtiment fondateur posé hors de tout
## territoire, à 2 km au moins d'un autre centre, fonde un nouveau village. Deux
## villages qui se touchent peuvent fusionner.
##
## Règles (réglages Admin, F10 → Construction) :
##   fondation : rien ne se construit (bâtiments, zonage, voies) avant le premier village ;
##   territoire : bâtiments et zonage seulement sur le territoire de ses villages.
## Les voies, les réseaux et les lignes restent permis partout, pour relier les villages.
##
## Contrat pour les autres systèmes :
##   Communes.instance               le nœud (ou null)
##   village_au_point(x, z) -> int   village du point, ou -1
##   village_du_batiment(bid) -> int
##   villages[vid] = {id, nom, bid, c: Vector2, rayon, annexes, fonde, couleur, cases}
##   Communes.nom_principal()        nom du premier village ("" sans village)

signal changed
signal message(text: String)
signal fonde(vid: int)

## Côté d'un carré de territoire (m).
const CASE := 100
## Rayon du territoire automatique pour chaque palier de population du village
## (mêmes paliers que ReglagesPartie.PALIERS).
const RAYONS := [500.0, 800.0, 1200.0, 2000.0, 3000.0]
## Distance minimale entre deux centres de village (m).
const DIST_MIN := 2000.0
## Prix d'un carré annexé (1 ha), multiplié par le réglage « coût des constructions ».
const PRIX_CASE := 25_000
const COULEURS := [Color("ffb703"), Color("8ecae6"), Color("f4845f"), Color("90be6d"), Color("c77dff"),
	Color("f15bb5"), Color("00bbf9"), Color("fee440")]
const NOMS_AUTO := ["Les Granges", "Beauvallon", "Saint-Clair", "Montfleury", "La Bastide", "Villeneuve",
	"Les Ormes", "Fontclaire", "Champlong", "Roche-Belle", "Le Moulin", "Valbonne"]

static var instance: Communes

var world: TerrainWorld
var buildings: BuildingSystem
var zones: ZoneSystem
var population: Population
var camera: Camera3D

## Partie « réelle » (lancée depuis le globe) : fondation et territoire appliqués.
## Faux pour les scènes de test et l'atelier : rien n'est bloqué tant qu'il n'y a
## pas de village.
var actif := false
var villages := {}
## Case de territoire (Vector2i, en carrés de CASE m) -> id du village.
var proprio := {}
var next_id := 1
## Nom choisi pour le prochain village (bouton « Fonder un village »).
var nom_en_attente := ""
## Outil en main : "" , "annexer" ou "ceder" (pour outil_village).
var outil := ""
var outil_village := -1
## Frontières montrées par le panneau ou le calque des cartes.
var montre := false
var calque := false
## Chiffres par village (recalculés toutes les 2 s) : vid -> {hab, logements, emplois, batiments, palier}.
var stats := {}
## Chargement d'une partie en cours : les bâtiments rechargés ne fondent rien.
var ignorer := false

var _mat: StandardMaterial3D
var _bordure: MeshInstance3D
var _remplissage: MeshInstance3D
var _survol: MeshInstance3D
var _etiquettes := {}
var _sale := true
var _incomplet := false
var _t_stats := 0.0
var _t_relief := 0.0
var _case_survol := Vector2i(1 << 30, 0)
## Hauteur de la caméra au dernier dessin des frontières (leur largeur en dépend).
var _echelle := 300.0
var _sale_remplissage := true


func _ready() -> void:
	instance = self
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mat.render_priority = 2
	# Frontières lisibles même de très haut (pas de brume dessus).
	_mat.disable_fog = true
	for n in ["Bordure", "Remplissage", "Survol"]:
		var mi := MeshInstance3D.new()
		mi.name = n
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = _mat
		mi.visible = false
		add_child(mi)
	_bordure = $Bordure
	_remplissage = $Remplissage
	_survol = $Survol


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(w: TerrainWorld, b: BuildingSystem, z: ZoneSystem, p: Population) -> void:
	world = w
	buildings = b
	zones = z
	population = p
	camera = b.camera
	buildings.added.connect(_on_added)
	buildings.removed.connect(_on_removed)


func clear() -> void:
	villages.clear()
	proprio.clear()
	stats.clear()
	next_id = 1
	nom_en_attente = ""
	set_outil("")
	_sale = true
	_sale_remplissage = true
	changed.emit()


# --- Questions ----------------------------------------------------------------------

## Le type de bâtiment fonde-t-il un village (maison de commune, mairie) ?
static func est_fondateur(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	if t.is_empty():
		return false
	return bool(t.get("fondateur", false)) or Metiers.keys_of(type_id).has("mairie")


static func case_de(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CASE), floori(z / CASE))


static func centre_case(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * CASE, (c.y + 0.5) * CASE)


func village_au_point(x: float, z: float) -> int:
	return int(proprio.get(case_de(x, z), -1))


func village_du_batiment(bid: int) -> int:
	if buildings == null or not buildings.buildings.has(bid):
		return -1
	var c := _centre_bat(bid)
	return village_au_point(c.x, c.y)


## Nom du premier village (le chef-lieu), ou "".
static func nom_principal() -> String:
	if instance == null or instance.villages.is_empty():
		return ""
	return String(instance.villages[instance.principal()].nom)


func principal() -> int:
	var best := -1
	for vid in villages:
		if best < 0 or int(vid) < best:
			best = int(vid)
	return best


## Il faut encore poser le bâtiment fondateur avant de construire.
func fondation_requise() -> bool:
	return actif and villages.is_empty() and ReglagesPartie.actuel.fondation


## Bâtiments et zonage limités au territoire des villages.
func territoire_strict() -> bool:
	return ReglagesPartie.actuel.territoire and not villages.is_empty()


const MSG_FONDER := "Fonde d'abord ton village : pose une Maison de commune (Construire → Services, ou Maj+M)."


## Raison qui interdit ce bâtiment ici, ou "" (BuildingSystem.extra_check).
func raison_batiment(id: String, rect: Rect2i) -> String:
	var ctr := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
	if est_fondateur(id) and village_au_point(ctr.x, ctr.y) < 0:
		return raison_fondation(ctr, rect)
	if fondation_requise():
		return MSG_FONDER
	if not territoire_strict():
		return ""
	if not rect_dans_territoire(rect):
		return "Hors du territoire de tes villages : agrandis-le (Maj+M → Agrandir) ou fonde un nouveau village."
	return ""


## Peut-on fonder un village ici ? "" si oui.
func raison_fondation(p: Vector2, rect := Rect2i()) -> String:
	if rect.size != Vector2i.ZERO:
		for q in _points_rect(rect):
			var v := village_au_point(q.x, q.y)
			if v >= 0:
				return "Le bâtiment déborde sur le territoire de %s." % villages[v].nom
	for vid in villages:
		var d := p.distance_to(villages[vid].c)
		if d < DIST_MIN:
			return "Trop près de %s (%.1f km) : un nouveau village doit être à %.0f km au moins d'un autre." % [
				villages[vid].nom, d / 1000.0, DIST_MIN / 1000.0]
	return ""


## Raison qui interdit ce zonage, ou "" (ZoneSystem.area_check).
func raison_zone(rect: Rect2i) -> String:
	if fondation_requise():
		return MSG_FONDER
	if territoire_strict() and not rect_dans_territoire(rect):
		return "Zonage hors du territoire de tes villages : agrandis-le d'abord (Maj+M)."
	return ""


## Raison qui interdit de tracer une voie, ou "" (TransportSystem.build_gate).
func raison_voie() -> String:
	return MSG_FONDER if fondation_requise() else ""


func rect_dans_territoire(rect: Rect2i) -> bool:
	for q in _points_rect(rect):
		if village_au_point(q.x, q.y) < 0:
			return false
	return true


## Coins, centre et un point tous les 50 m à l'intérieur du rectangle.
func _points_rect(rect: Rect2i) -> Array:
	var out := []
	var x0 := float(rect.position.x) + 0.01
	var z0 := float(rect.position.y) + 0.01
	var x1 := float(rect.end.x) - 0.01
	var z1 := float(rect.end.y) - 0.01
	var nx := maxi(1, ceili((x1 - x0) / 50.0))
	var nz := maxi(1, ceili((z1 - z0) / 50.0))
	for i in nx + 1:
		for j in nz + 1:
			out.append(Vector2(lerpf(x0, x1, float(i) / nx), lerpf(z0, z1, float(j) / nz)))
	return out


func _centre_bat(bid: int) -> Vector2:
	var b: Dictionary = buildings.buildings[bid]
	var r := buildings._rect_of(b)
	return Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)


# --- Fonder, agrandir, céder, fusionner ------------------------------------------------

## Fonde un village autour du bâtiment bid. Renvoie son id.
func fonder(nom: String, bid: int) -> int:
	var c := _centre_bat(bid) if buildings != null and buildings.buildings.has(bid) else Vector2.ZERO
	return fonder_au_point(nom, c, bid)


func fonder_au_point(nom: String, c: Vector2, bid := -1) -> int:
	nom = nom.strip_edges()
	if nom == "":
		nom = nom_auto()
	var vid := next_id
	next_id += 1
	var fond := 0.0
	if Avis.instance != null and Avis.instance.ambiance != null:
		fond = Avis.instance.ambiance.unix_time
	villages[vid] = {"id": vid, "nom": nom, "bid": bid, "c": c, "rayon": 0.0, "annexes": [],
		"fonde": fond, "couleur": (vid - 1) % COULEURS.size(), "cases": {}}
	# Le carré du centre, même s'il touche une frontière.
	_ajouter_case(vid, case_de(c.x, c.y))
	_etendre(vid, RAYONS[0])
	_sale = true
	_sale_remplissage = true
	message.emit("Village « %s » fondé ! Son territoire : %d ha autour de la mairie. Il grandira avec la population." % [
		nom, (villages[vid].cases as Dictionary).size()])
	fonde.emit(vid)
	changed.emit()
	return vid


## Nom proposé pour un nouveau village.
func nom_auto() -> String:
	if villages.is_empty():
		var n := Avis.ville()
		if n != "" and n != "MiniBlocs":
			return n
	var pris := {}
	for vid in villages:
		pris[String(villages[vid].nom)] = true
	for n in NOMS_AUTO:
		if not pris.has(n):
			return n
	return "Village n° %d" % next_id


## Donne au village tous les carrés libres à moins de rayon m de son centre.
func _etendre(vid: int, rayon: float) -> int:
	var v: Dictionary = villages[vid]
	v.rayon = maxf(float(v.rayon), rayon)
	var c: Vector2 = v.c
	var n := ceili(rayon / CASE) + 1
	var cc := case_de(c.x, c.y)
	var half := GameStart.REGION_SIZE * 0.5
	var added := 0
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var k := cc + Vector2i(i, j)
			if proprio.has(k):
				continue
			var m := centre_case(k)
			if m.distance_to(c) > rayon or absf(m.x) > half or absf(m.y) > half:
				continue
			_ajouter_case(vid, k)
			added += 1
	if added > 0:
		_sale = true
		_sale_remplissage = true
	return added


func _ajouter_case(vid: int, k: Vector2i) -> void:
	proprio[k] = vid
	(villages[vid].cases as Dictionary)[k] = true


func _retirer_case(k: Vector2i) -> void:
	var vid := int(proprio.get(k, -1))
	proprio.erase(k)
	if villages.has(vid):
		(villages[vid].cases as Dictionary).erase(k)


func prix_case() -> int:
	return ReglagesPartie.prix(PRIX_CASE)


func touche(vid: int, k: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if int(proprio.get(k + d, -1)) == vid:
			return true
	return false


## Raison d'un refus d'annexer, ou "".
func raison_annexer(vid: int, k: Vector2i) -> String:
	if not villages.has(vid):
		return "Village inconnu."
	var o := int(proprio.get(k, -1))
	if o == vid:
		return "Ce carré est déjà à %s." % villages[vid].nom
	if o >= 0:
		return "Ce carré appartient à %s. Fusionne les deux villages pour les réunir." % villages[o].nom
	if not touche(vid, k):
		return "Il faut un carré qui touche le territoire de %s." % villages[vid].nom
	var half := GameStart.REGION_SIZE * 0.5
	var m := centre_case(k)
	if absf(m.x) > half or absf(m.y) > half:
		return "Hors de la région de jeu."
	if not buildings.unlimited_money and prix_case() > buildings.money:
		return "Pas assez d'argent : %s nécessaires." % BuildingSystem.format_money(prix_case())
	return ""


## Achète un carré voisin. Renvoie "" si c'est fait, sinon la raison.
func annexer(vid: int, k: Vector2i) -> String:
	var r := raison_annexer(vid, k)
	if r != "":
		return r
	var cost := prix_case()
	if not buildings.unlimited_money:
		buildings.money -= cost
		BudgetCommunal.noter("Terrains annexés", -cost)
	_ajouter_case(vid, k)
	_sale = true
	_sale_remplissage = true
	changed.emit()
	return ""


func raison_ceder(vid: int, k: Vector2i) -> String:
	if not villages.has(vid) or int(proprio.get(k, -1)) != vid:
		return "Ce carré n'est pas à %s." % (villages[vid].nom if villages.has(vid) else "ce village")
	var v: Dictionary = villages[vid]
	if case_de(v.c.x, v.c.y) == k:
		return "On ne cède pas le carré de la mairie."
	if (v.cases as Dictionary).size() <= 1:
		return "Il faut garder au moins un carré."
	var r := Rect2i(k * CASE, Vector2i(CASE, CASE))
	for bid in buildings.buildings:
		if case_de(_centre_bat(bid).x, _centre_bat(bid).y) == k:
			return "Il y a des bâtiments sur ce carré : démolis-les d'abord."
	if zones != null:
		for zid in zones.zones:
			if ZoneSystem.zone_rect(zones.zones[zid]).intersects(r):
				return "Une zone est peinte sur ce carré : retire-la d'abord."
	return ""


func ceder(vid: int, k: Vector2i) -> String:
	var r := raison_ceder(vid, k)
	if r != "":
		return r
	_retirer_case(k)
	_sale = true
	_sale_remplissage = true
	changed.emit()
	return ""


## Les deux villages ont-ils une frontière commune ?
func voisins(a: int, b: int) -> bool:
	if not villages.has(a) or not villages.has(b) or a == b:
		return false
	for k in villages[a].cases:
		if touche(b, k):
			return true
	return false


## Fusionne deux villages voisins : le plus peuplé garde son nom et sa mairie,
## l'autre devient une mairie annexe. Renvoie l'id du village gardé, ou -1.
func fusionner(a: int, b: int) -> int:
	if not voisins(a, b):
		message.emit("Ces deux villages ne se touchent pas : agrandis l'un jusqu'à l'autre.")
		return -1
	var ha := int(stats.get(a, {}).get("hab", 0))
	var hb := int(stats.get(b, {}).get("hab", 0))
	var keep := a if ha > hb or (ha == hb and a < b) else b
	var gone := b if keep == a else a
	var vk: Dictionary = villages[keep]
	var vg: Dictionary = villages[gone]
	for k in (vg.cases as Dictionary).keys():
		_ajouter_case(keep, k)
	if int(vg.bid) >= 0:
		(vk.annexes as Array).append(int(vg.bid))
	(vk.annexes as Array).append_array(vg.annexes)
	vk.rayon = maxf(float(vk.rayon), float(vg.rayon))
	villages.erase(gone)
	stats.erase(gone)
	if outil_village == gone:
		set_outil("")
	_sale = true
	_sale_remplissage = true
	message.emit("%s et %s fusionnent : la commune garde le nom de %s, l'ancienne mairie de %s devient une mairie annexe." % [
		vk.nom, vg.nom, vk.nom, vg.nom])
	changed.emit()
	return keep


func renommer(vid: int, nom: String) -> void:
	nom = nom.strip_edges()
	if not villages.has(vid) or nom == "":
		return
	villages[vid].nom = nom
	_sale = true
	_sale_remplissage = true
	changed.emit()


# --- Bâtiments posés et démolis ------------------------------------------------------------

func _on_added(bid: int) -> void:
	if ignorer:
		return
	var b: Dictionary = buildings.buildings.get(bid, {})
	if b.is_empty() or not est_fondateur(String(b.t)):
		return
	var c := _centre_bat(bid)
	var vid := village_au_point(c.x, c.y)
	if vid < 0:
		if raison_fondation(c) != "" and not villages.is_empty():
			return
		var nom := nom_en_attente
		nom_en_attente = ""
		fonder(nom, bid)
		return
	# Nouvelle mairie dans un village : la plus grande devient le siège.
	var v: Dictionary = villages[vid]
	var siege := int(v.bid)
	if siege == bid or (v.annexes as Array).has(bid):
		return
	if siege < 0 or not buildings.buildings.has(siege):
		v.bid = bid
		message.emit("%s a de nouveau une mairie." % v.nom)
	elif BuildingCatalog.cost(String(b.t)) > BuildingCatalog.cost(String(buildings.buildings[siege].t)):
		(v.annexes as Array).append(siege)
		v.bid = bid
		message.emit("La nouvelle mairie devient le siège de %s ; l'ancienne devient une mairie annexe." % v.nom)
	else:
		(v.annexes as Array).append(bid)
	changed.emit()


func _on_removed(bid: int) -> void:
	if ignorer:
		return
	for vid in villages:
		var v: Dictionary = villages[vid]
		(v.annexes as Array).erase(bid)
		if int(v.bid) != bid:
			continue
		v.bid = -1
		for a in v.annexes:
			if buildings.buildings.has(int(a)):
				v.bid = int(a)
				break
		(v.annexes as Array).erase(v.bid)
		if int(v.bid) < 0:
			message.emit("%s n'a plus de mairie : reconstruis une Maison de commune sur son territoire." % v.nom)
		changed.emit()


# --- Chiffres et croissance ------------------------------------------------------------------

## Palier (index de ReglagesPartie.PALIERS) d'une population.
static func palier_de(hab: int) -> int:
	var best := 0
	for i in ReglagesPartie.PALIERS.size():
		if hab >= int(ReglagesPartie.PALIERS[i].habitants):
			best = i
	return best


func calculer_stats() -> void:
	var out := {}
	for vid in villages:
		out[vid] = {"hab": 0, "foyers": 0, "logements": 0, "emplois": 0, "batiments": 0, "palier": 0,
			"ha": (villages[vid].cases as Dictionary).size()}
	if buildings != null:
		var de := {}
		for bid in buildings.buildings:
			var c := _centre_bat(bid)
			var vid := village_au_point(c.x, c.y)
			de[bid] = vid
			if vid < 0:
				continue
			var s: Dictionary = out[vid]
			s.batiments += 1
			var t := BuildingCatalog.get_type(String(buildings.buildings[bid].t))
			s.logements += int(t.get("logements", 0))
			s.emplois += int(t.get("emplois", 0))
		if population != null:
			for hid in population.households:
				var h: Dictionary = population.households[hid]
				var vid := int(de.get(int(h.b), -1))
				if vid >= 0:
					out[vid].foyers += 1
					out[vid].hab += (h.m as Array).size()
	for vid in out:
		out[vid].palier = palier_de(int(out[vid].hab))
	stats = out


## Le territoire suit la population (jamais de recul).
func croissance() -> void:
	for vid in villages.keys():
		var s: Dictionary = stats.get(vid, {})
		var p := int(s.get("palier", 0))
		var r := float(RAYONS[mini(p, RAYONS.size() - 1)])
		if r > float(villages[vid].rayon) + 0.5:
			var n := _etendre(vid, r)
			if n > 0:
				message.emit("%s devient « %s » : son territoire s'agrandit de %d ha (%s m autour de la mairie)." % [
					villages[vid].nom, String(ReglagesPartie.PALIERS[p].nom).to_lower(), n, str(roundi(r))])
				changed.emit()


func _process(delta: float) -> void:
	_t_stats -= delta
	if _t_stats <= 0.0:
		_t_stats = 2.0
		calculer_stats()
		croissance()
	var show := montre or calque or outil != ""
	if buildings != null and buildings.mode == BuildingSystem.Mode.PLACE:
		show = true
	if zones != null and zones.mode != ZoneSystem.Mode.NONE:
		show = true
	if _incomplet:
		_t_relief -= delta
		if _t_relief <= 0.0:
			_sale = true
	if show and camera != null and not _sale:
		var haut := maxf(camera.global_position.y - _h(camera.global_position.x, camera.global_position.z), 30.0)
		if haut > _echelle * 1.6 or haut < _echelle / 1.6:
			_sale = true
	if show and _sale:
		_reconstruire()
	_bordure.visible = show
	_remplissage.visible = show and (calque or outil != "" or montre)
	_survol.visible = outil != ""
	for vid in _etiquettes:
		(_etiquettes[vid] as Label3D).visible = show


# --- Outils (annexer, céder) -------------------------------------------------------------------

func set_outil(o: String, vid := -1) -> void:
	outil = o
	outil_village = vid if o != "" else -1
	_case_survol = Vector2i(1 << 30, 0)
	if o != "" and villages.has(vid):
		var p := prix_case()
		if o == "annexer":
			message.emit("Agrandir %s : clique sur un carré de 100 × 100 m qui touche le territoire (%s le carré). Clic droit ou Échap pour arrêter." % [
				villages[vid].nom, BuildingSystem.format_money(p)])
		else:
			message.emit("Céder des carrés de %s : clique sur un carré vide de son territoire. Clic droit ou Échap pour arrêter." % villages[vid].nom)


func _unhandled_input(event: InputEvent) -> void:
	if outil == "" or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		_survoler((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			set_outil("")
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_survoler(mb.position)
			if _case_survol.x != 1 << 30:
				var r := annexer(outil_village, _case_survol) if outil == "annexer" else ceder(outil_village, _case_survol)
				if r != "":
					message.emit(r)
				elif outil == "annexer":
					message.emit("Carré annexé à %s pour %s." % [villages[outil_village].nom, BuildingSystem.format_money(prix_case())])
				else:
					message.emit("Carré cédé : il n'appartient plus à aucun village.")
				_case_survol = Vector2i(1 << 30, 0)
				_survoler(mb.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		set_outil("")
		get_viewport().set_input_as_handled()


func _survoler(screen: Vector2) -> void:
	var hit: Variant = world.pick_cell(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null:
		return
	var k := case_de(float(hit.x) + 0.5, float(hit.y) + 0.5)
	if k == _case_survol:
		return
	_case_survol = k
	var ok := (raison_annexer(outil_village, k) if outil == "annexer" else raison_ceder(outil_village, k)) == ""
	var col := Color(0.3, 0.95, 0.4, 0.38) if ok else Color(1.0, 0.3, 0.25, 0.38)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_carre(st, k, col, 1.4)
	_survol.mesh = st.commit()


# --- Dessin des frontières ------------------------------------------------------------------

func _h(x: float, z: float) -> float:
	var h := NAN
	if world != null:
		h = world.cell_height(Vector2i(floori(x), floori(z)))
		if is_nan(h) and world.horizon != null:
			h = world.horizon.height_at(x, z)
	if is_nan(h):
		_incomplet = true
		return 0.0
	return maxf(h, 0.0)


## Carré de territoire drapé sur le relief (maille de 20 m).
func _carre(st: SurfaceTool, k: Vector2i, col: Color, dy: float) -> void:
	const N := 5
	var step := float(CASE) / N
	var x0 := float(k.x * CASE)
	var z0 := float(k.y * CASE)
	var hs := []
	for i in N + 1:
		var row := []
		for j in N + 1:
			var x := x0 + i * step
			var z := z0 + j * step
			row.append(Vector3(x, _h(x, z) + dy, z))
		hs.append(row)
	for i in N:
		for j in N:
			var a: Vector3 = hs[i][j]
			var b: Vector3 = hs[i + 1][j]
			var c: Vector3 = hs[i + 1][j + 1]
			var d: Vector3 = hs[i][j + 1]
			for p in [a, b, c, a, c, d]:
				st.set_color(col)
				st.add_vertex(p)


func _reconstruire() -> void:
	_sale = false
	var incomplet := _incomplet
	_incomplet = false
	if camera != null:
		_echelle = maxf(camera.global_position.y - _h(camera.global_position.x, camera.global_position.z), 30.0)
	var refaire_fill := _sale_remplissage or incomplet
	_sale_remplissage = false
	var bord := SurfaceTool.new()
	bord.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_bord := 0
	var n_fill := 0
	for k in proprio:
		var vid := int(proprio[k])
		if not villages.has(vid):
			continue
		var col: Color = COULEURS[int(villages[vid].couleur) % COULEURS.size()]
		if refaire_fill:
			_carre(fill, k, Color(col, 0.2), 0.9)
			n_fill += 1
		# Côtés de la frontière : voisin d'un autre village ou sans village.
		var x0 := float(k.x * CASE)
		var z0 := float(k.y * CASE)
		for e in [[Vector2i(0, -1), Vector2(x0, z0), Vector2(x0 + CASE, z0), Vector2(0, 1)],
				[Vector2i(0, 1), Vector2(x0, z0 + CASE), Vector2(x0 + CASE, z0 + CASE), Vector2(0, -1)],
				[Vector2i(-1, 0), Vector2(x0, z0), Vector2(x0, z0 + CASE), Vector2(1, 0)],
				[Vector2i(1, 0), Vector2(x0 + CASE, z0), Vector2(x0 + CASE, z0 + CASE), Vector2(-1, 0)]]:
			if int(proprio.get(k + (e[0] as Vector2i), -1)) == vid:
				continue
			_cote(bord, e[1], e[2], e[3], col)
			n_bord += 1
	_bordure.mesh = bord.commit() if n_bord > 0 else null
	if refaire_fill:
		_remplissage.mesh = fill.commit() if n_fill > 0 else null
	if _incomplet:
		_t_relief = 3.0
	_maj_etiquettes()


## Un côté de frontière : un muret translucide et une bande au sol vers l'intérieur.
func _cote(st: SurfaceTool, a: Vector2, b: Vector2, inward: Vector2, col: Color) -> void:
	const PAS := 10.0
	# Muret et bande plus larges quand on regarde de haut (lisibles à toute distance).
	var haut := clampf(_echelle * 0.006, 3.0, 25.0)
	var large := clampf(_echelle * 0.008, 4.0, 40.0)
	var n := ceili(a.distance_to(b) / PAS)
	for i in n:
		var p0 := a.lerp(b, float(i) / n)
		var p1 := a.lerp(b, float(i + 1) / n)
		var h0 := _h(p0.x, p0.y) + 0.6
		var h1 := _h(p1.x, p1.y) + 0.6
		var q0 := p0 + inward * large
		var q1 := p1 + inward * large
		var g0 := _h(q0.x, q0.y) + 0.6
		var g1 := _h(q1.x, q1.y) + 0.6
		var bas := Color(col, 0.9)
		var ciel := Color(col, 0.0)
		var sol := Color(col, 0.85)
		# Muret.
		var w := [[Vector3(p0.x, h0, p0.y), bas], [Vector3(p1.x, h1, p1.y), bas], [Vector3(p1.x, h1 + haut, p1.y), ciel],
			[Vector3(p0.x, h0, p0.y), bas], [Vector3(p1.x, h1 + haut, p1.y), ciel], [Vector3(p0.x, h0 + haut, p0.y), ciel]]
		# Bande au sol.
		w.append_array([[Vector3(p0.x, h0, p0.y), sol], [Vector3(p1.x, h1, p1.y), sol], [Vector3(q1.x, g1, q1.y), Color(col, 0.25)],
			[Vector3(p0.x, h0, p0.y), sol], [Vector3(q1.x, g1, q1.y), Color(col, 0.25)], [Vector3(q0.x, g0, q0.y), Color(col, 0.25)]])
		for e in w:
			st.set_color(e[1])
			st.add_vertex(e[0])


func _maj_etiquettes() -> void:
	for vid in _etiquettes.keys():
		if not villages.has(vid):
			(_etiquettes[vid] as Node).queue_free()
			_etiquettes.erase(vid)
	for vid in villages:
		var v: Dictionary = villages[vid]
		var l: Label3D = _etiquettes.get(vid)
		if l == null:
			l = Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.fixed_size = true
			l.pixel_size = 0.0012
			l.font_size = 40
			l.outline_size = 12
			l.no_depth_test = true
			l.modulate = Color.WHITE
			add_child(l)
			_etiquettes[vid] = l
		l.text = String(v.nom)
		l.outline_modulate = Color(COULEURS[int(v.couleur) % COULEURS.size()].darkened(0.55), 0.9)
		var c: Vector2 = v.c
		l.position = Vector3(c.x, _h(c.x, c.y) + 45.0, c.y)


# --- Sauvegarde ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var vs := []
	for vid in villages:
		var v: Dictionary = villages[vid]
		var cs := []
		for k in v.cases:
			cs.append([k.x, k.y])
		vs.append({"id": vid, "nom": v.nom, "bid": v.bid, "cx": snappedf(v.c.x, 0.01), "cz": snappedf(v.c.y, 0.01),
			"rayon": v.rayon, "annexes": v.annexes, "fonde": v.fonde, "couleur": v.couleur, "cases": cs})
	return {"version": 1, "actif": actif, "next_id": next_id, "villages": vs}


func from_dict(d: Dictionary) -> void:
	clear()
	actif = bool(d.get("actif", actif))
	next_id = maxi(1, int(d.get("next_id", 1)))
	for e in d.get("villages", []):
		var vid := int(e.id)
		var annexes := []
		for a in e.get("annexes", []):
			annexes.append(int(a))
		villages[vid] = {"id": vid, "nom": String(e.get("nom", "Village")), "bid": int(e.get("bid", -1)),
			"c": Vector2(float(e.get("cx", 0.0)), float(e.get("cz", 0.0))), "rayon": float(e.get("rayon", 0.0)),
			"annexes": annexes, "fonde": float(e.get("fonde", 0.0)), "couleur": int(e.get("couleur", vid - 1)), "cases": {}}
		for k in e.get("cases", []):
			_ajouter_case(vid, Vector2i(int(k[0]), int(k[1])))
		next_id = maxi(next_id, vid + 1)
	_sale = true
	_sale_remplissage = true
	calculer_stats()
	changed.emit()


## Ancienne partie sans villages : un village est créé autour de la mairie (ou du
## centre des bâtiments), et son territoire couvre tout ce qui est déjà construit.
func adopter_ancienne_partie() -> int:
	if not villages.is_empty() or buildings == null:
		return -1
	if buildings.buildings.is_empty() and (zones == null or zones.zones.is_empty()):
		return -1
	var siege := -1
	var best := -1
	for bid in buildings.buildings:
		var t := String(buildings.buildings[bid].t)
		if est_fondateur(t) and BuildingCatalog.cost(t) > best:
			best = BuildingCatalog.cost(t)
			siege = bid
	var c := Vector2.ZERO
	if siege >= 0:
		c = _centre_bat(siege)
	elif not buildings.buildings.is_empty():
		for bid in buildings.buildings:
			c += _centre_bat(bid)
		c /= buildings.buildings.size()
	else:
		var z: Dictionary = zones.zones.values()[0]
		c = Vector2(float(z.x) + float(z.w) * 0.5, float(z.z) + float(z.h) * 0.5)
	var vid := fonder_au_point(Avis.ville() if Avis.ville() != "MiniBlocs" else nom_auto(), c, siege)
	# Tout ce qui est déjà construit est dans le territoire.
	for bid in buildings.buildings:
		var r := buildings._rect_of(buildings.buildings[bid])
		for q in _points_rect(r):
			var k := case_de(q.x, q.y)
			if not proprio.has(k):
				_ajouter_case(vid, k)
	if zones != null:
		for zid in zones.zones:
			for q in _points_rect(ZoneSystem.zone_rect(zones.zones[zid])):
				var k := case_de(q.x, q.y)
				if not proprio.has(k):
					_ajouter_case(vid, k)
	calculer_stats()
	_etendre(vid, RAYONS[int(stats.get(vid, {}).get("palier", 0))])
	_sale = true
	_sale_remplissage = true
	message.emit("Ancienne partie : le village « %s » a été créé autour de ta ville (Maj+M pour le voir)." % villages[vid].nom)
	changed.emit()
	return vid
