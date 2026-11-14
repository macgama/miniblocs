class_name AttractionsPerso
extends Node3D
## Attractions créées par le joueur dans l'éditeur du parc (menu Parc, Maj+A) :
## grands-huit, bûches, rivière à bouées, bateau splash, toboggans.
##
## Chaque dessin (design) devient un bâtiment du catalogue « atr_<id> » : sa
## gare, posée comme les autres bâtiments (prix, chantier, rotation), avec sa
## voie dessinée autour. Le champ "parc" de l'entrée vient de la simulation
## (VoiePhysique) : places, durée du tour, excitation, intensité, attrait.
## ParcLoisirs le traite donc comme n'importe quelle attraction.
##
## Le brouillon : on pose la gare (fantôme qui suit la souris, R pour tourner),
## puis on ajoute les pièces une à une ; tout se recalcule à chaque pièce
## (vitesse, G, notes, prix, erreurs). « Construire » lance le chantier.
##
## Sauvegarde : section « parc_editeur » (dessins utilisés, adoptés avant les
## bâtiments). Bibliothèque du joueur : user://mes_attractions.json.

signal changed
signal message(text: String)
signal info_changed(text: String)
signal focus_requested(pos: Vector3)

const PREFIX := "atr_"
const BIBLIO := "user://mes_attractions.json"
const ANIM_DIST := 1200.0

## Dessins connus (id -> design), partagés avec le catalogue.
static var designs: Dictionary = {}
## Cache des calculs : id -> {sig, tr, sim}.
static var _calc: Dictionary = {}
static var _biblio: Dictionary = {}
static var _biblio_lue := false

var buildings: BuildingSystem
var world: TerrainWorld
var parc: ParcLoisirs

## Voies posées : bid -> {node, trains: [MeshInstance3D], tau, id}.
var _poses: Dictionary = {}
## Brouillon en cours ({} = aucun) : design, center (Vector2i), r, bid (−1 = nouveau), place (gare posée).
var brouillon: Dictionary = {}
## "" (rien), "gare" (on pose la gare), "trace" (on ajoute des pièces).
var outil := ""
## Le prochain morceau monte avec une chaîne (ou un tapis).
var chaine := false
## Train d'essai sur le brouillon.
var essai := false
var _essai_tau := 0.0
var _fantome: Node3D
var _apercu: MeshInstance3D
var _survol := Vector3.ZERO
var _survol_ok := false
var _rot := 0
var _t := 0.0


func _ready() -> void:
	_fantome = Node3D.new()
	_fantome.name = "Brouillon"
	add_child(_fantome)
	_apercu = MeshInstance3D.new()
	_apercu.name = "ApercuPiece"
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.82, 0.3, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_apercu.material_override = m
	_fantome.add_child(_apercu)


func setup(b: BuildingSystem, w: TerrainWorld, p: ParcLoisirs) -> void:
	buildings = b
	world = w
	parc = p
	b.added.connect(_on_added)
	b.removed.connect(_on_removed)
	b.changed.connect(_sync)
	_sync()


# --- Catalogue (statique) -------------------------------------------------------------------

static func catalog_id(id: String) -> String:
	return PREFIX + id


static func is_atr(type_id: String) -> bool:
	return type_id.begins_with(PREFIX)


static func design_of_type(type_id: String) -> Dictionary:
	return designs.get(type_id.substr(PREFIX.length()), {}) if is_atr(type_id) else {}


static func nouvel_id() -> String:
	return "%d%03d" % [int(Time.get_unix_time_from_system()) % 100000000, randi() % 1000]


## Dessin vide d'une famille.
static func nouveau_design(fam_id: String) -> Dictionary:
	var f := VoiePieces.famille(fam_id)
	var noms := {"acier": "Le Serpentin", "bois": "Le Vieux Bois", "mine": "Train de la Mine d'Or", "familial": "La Chenille",
		"suspendu": "L'Envol", "lance": "La Fusée", "buches": "Les Bûches du Moulin", "riviere": "Rivière Sauvage",
		"splash": "Grand Plouf", "toboggan": "Le Toboggan Bleu"}
	return {"id": nouvel_id(), "nom": String(noms.get(fam_id, "Mon attraction")), "famille": fam_id, "pieces": [],
		"raccord": false, "c_rail": 0, "c_support": 0, "c_train": 0, "voitures": int(f.voitures), "trains": int(f.get("trains", 1))}


## Tracé + simulation, en cache tant que le dessin ne change pas.
static func calcule(design: Dictionary) -> Dictionary:
	var id := String(design.get("id", ""))
	var sig := JSON.stringify([design.get("famille"), design.get("pieces"), design.get("raccord"), design.get("voitures"), design.get("trains")])
	if id != "" and _calc.has(id) and String(_calc[id].sig) == sig:
		return _calc[id]
	var tr := VoiePieces.trace(design)
	var sim := VoiePhysique.simule(design, tr)
	var c := {"sig": sig, "tr": tr, "sim": sim}
	if id != "":
		_calc[id] = c
	return c


## Entrée de catalogue de la gare d'un dessin.
static func entry(design: Dictionary) -> Dictionary:
	var fam_id := String(design.get("famille", "acier"))
	var f := VoiePieces.famille(fam_id)
	var c := calcule(design)
	var sim: Dictionary = c.sim
	var e := VoieMesh.emprise(fam_id)
	var spec := VoiePhysique.spec_parc(design, sim)
	var metiers := VoiePhysique.emplois(design)
	var emplois := 0
	for m in metiers:
		emplois += int(m[1])
	return {"name": String(design.get("nom", "Mon attraction")), "cat": ParcTypes.CATEGORY, "w": e.x, "d": e.y, "access": [],
		"emplois": emplois, "cost": VoiePhysique.prix(design, sim), "parc": spec, "metiers": metiers,
		"desc": "%s · %d m · %d km/h · excitation %.1f" % [String(f.nom), roundi(float(sim.get("longueur", 0.0))), roundi(float(sim.get("v_max", 0.0)) * 3.6), float(sim.get("exc", 0.0))],
		"region": "monde", "era": "moderne", "style": "", "cache": true, "visiteurs": int(spec.cap) * 10,
		"voie_famille": fam_id, "voie_couleur": VoieMesh.couleur(design, "rail"), "voie_id": String(design.id)}


## Le dessin entre (ou se met à jour) dans le catalogue des bâtiments.
static func register(design: Dictionary) -> String:
	var id := String(design.id)
	designs[id] = design
	var cid := catalog_id(id)
	BuildingCatalog.all_types()[cid] = entry(design)
	return cid


# --- Sauvegarde --------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var used := {}
	if buildings:
		for b in buildings.buildings.values():
			var t := String(b.t)
			if is_atr(t):
				var id := t.substr(PREFIX.length())
				if designs.has(id):
					used[id] = designs[id]
	return {"version": 1, "designs": used}


## Avant de recréer les bâtiments d'une partie : ses attractions entrent au catalogue.
static func adopt(data: Dictionary) -> void:
	var src: Dictionary = data.get("designs", {})
	for id in src:
		var d: Dictionary = src[id]
		d["id"] = String(id)
		register(d)


func from_dict(_d: Dictionary) -> void:
	annuler()
	_sync()


func clear() -> void:
	annuler()
	for bid in _poses.keys():
		_detache(int(bid))


# --- Bibliothèque « Mes attractions » ----------------------------------------------------------

static func biblio() -> Dictionary:
	if not _biblio_lue:
		_biblio_lue = true
		var f := FileAccess.open(BIBLIO, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_biblio = (d as Dictionary).get("items", {})
	return _biblio


static func biblio_enregistre(design: Dictionary) -> void:
	var b := biblio()
	var copie := design.duplicate(true)
	b[String(design.id)] = copie
	_biblio_ecrit()


static func biblio_retire(id: String) -> void:
	biblio().erase(id)
	_biblio_ecrit()


static func _biblio_ecrit() -> void:
	var f := FileAccess.open(BIBLIO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "items": _biblio}, "\t"))


## Suite de pièces écrite en abrégé : « montee* » = avec la chaîne.
static func suite(texte: String) -> Array:
	var out := []
	for w in texte.split(" ", false):
		var e := {"p": w.trim_suffix("*")}
		if w.ends_with("*"):
			e["chaine"] = true
		out.append(e)
	return out


## Attractions prêtes à poser (pour démarrer vite, et comme exemples).
static func modeles() -> Array:
	var out := [
		{"nom": "Le Serpentin", "famille": "acier", "raccord": true, "c_rail": 0, "c_support": 0, "c_train": 0, "pieces": suite(
			"droit montee* droit_long* droit_long* fin_montee* droit_court descente raidir_bas adoucir_bas fin_descente droit looping droit " +
			"virage_d_large grande_bosse virage_d_large tire_bouchon_d virage_g droit_long droit_long droit_long droit_long droit_long freins droit")},
		{"nom": "Train de la Mine d'Or", "famille": "mine", "raccord": true, "c_rail": 7, "c_support": 0, "c_train": 5, "pieces": suite(
			"droit montee* droit_long* fin_montee* virage_d droit descente fin_descente tunnel virage_d_large bosse droit_long droit_long " +
			"descente fin_descente droit_long virage_d droit freins")},
		{"nom": "Les Bûches du Moulin", "famille": "buches", "raccord": true, "c_rail": 4, "c_support": 0, "c_train": 0, "pieces": suite(
			"droit virage_g montee* droit_long* fin_montee* virage_g droit_long descente raidir_bas adoucir_bas fin_descente eclabousse virage_g droit")},
		{"nom": "Rivière Sauvage", "famille": "riviere", "raccord": true, "c_rail": 6, "c_support": 0, "c_train": 1, "pieces": suite(
			"droit rapides virage_d_large tourbillon montee* fin_montee* virage_d descente fin_descente rapides virage_d_large")},
		{"nom": "Le Toboggan Bleu", "famille": "toboggan", "raccord": false, "c_rail": 1, "c_support": 0, "c_train": 0, "pieces": suite(
			"droit_court descente virage_d fin_descente virage_g virage_d droit arrivee")},
	]
	for m: Dictionary in out:
		var f := VoiePieces.famille(String(m.famille))
		m["voitures"] = int(f.voitures)
		m["trains"] = int(f.get("trains", 1))
	return out


# --- Voies posées ------------------------------------------------------------------------------

func _on_added(bid: int) -> void:
	if buildings.buildings.has(bid) and is_atr(String(buildings.buildings[bid].t)):
		call_deferred("_attache", bid)


func _on_removed(bid: int) -> void:
	_detache(bid)
	if not brouillon.is_empty() and int(brouillon.get("bid", -1)) == bid:
		annuler()


func _sync() -> void:
	if buildings == null:
		return
	for bid in _poses.keys():
		var host := buildings.node_of(int(bid)) if buildings.buildings.has(bid) else null
		var n: Node3D = _poses[bid].node
		if host == null or not is_instance_valid(n) or n.get_parent() != host:
			_detache(int(bid))
	for bid in buildings.buildings:
		if not _poses.has(bid) and is_atr(String(buildings.buildings[bid].t)):
			_attache(int(bid))


func _detache(bid: int) -> void:
	if not _poses.has(bid):
		return
	var n: Node3D = _poses[bid].node
	if is_instance_valid(n):
		n.queue_free()
	_poses.erase(bid)


func _attache(bid: int) -> void:
	if _poses.has(bid) or not buildings.buildings.has(bid):
		return
	var t := String(buildings.buildings[bid].t)
	var d := design_of_type(t)
	var host := buildings.node_of(bid)
	if d.is_empty() or host == null:
		return
	var n := _construit_voie(d, host.global_transform)
	host.add_child(n)
	_poses[bid] = {"node": n, "tau": 0.0, "id": String(d.id)}


## Nœud de la voie (repère de la gare) : rails + trains. xf : repère monde de la gare.
func _construit_voie(d: Dictionary, xf: Transform3D, fantome := false) -> Node3D:
	var c := calcule(d)
	var root := Node3D.new()
	root.name = "Voie"
	var mi := MeshInstance3D.new()
	mi.name = "Rails"
	mi.mesh = VoieMesh.voie(d, c.tr, c.sim, _sol_local(xf), fantome)
	mi.visibility_range_end = 1600.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)
	var trains := Node3D.new()
	trains.name = "Trains"
	root.add_child(trains)
	var f := VoiePieces.famille(String(d.famille))
	var nt := maxi(1, int(d.get("trains", f.get("trains", 1))))
	var nv := maxi(1, int(d.get("voitures", f.voitures)))
	var m_tete := VoieMesh.voiture(d, true, true)
	var m_occ := VoieMesh.voiture(d, true)
	for t in nt:
		for v in nv:
			var car := MeshInstance3D.new()
			car.mesh = m_tete if v == 0 else m_occ
			car.visibility_range_end = 900.0
			car.set_meta("train", t)
			car.set_meta("rang", v)
			trains.add_child(car)
	_place_trains(root, d, 0.0, false)
	return root


## Hauteur locale du sol sous un point du repère de la gare.
func _sol_local(xf: Transform3D) -> Callable:
	var w := world
	return func(p: Vector3) -> float:
		if w == null:
			return NAN
		var g := xf * p
		var h := w.raw_height(g.x, g.z)
		if is_nan(h):
			return NAN
		return h - xf.origin.y


# --- Animation des trains ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var dt := delta * _vitesse_jeu()
	for bid in _poses:
		var e: Dictionary = _poses[bid]
		var n: Node3D = e.node
		if not is_instance_valid(n):
			continue
		if cam != null and cam.global_position.distance_to(n.global_position) > ANIM_DIST:
			continue
		var d: Dictionary = designs.get(String(e.id), {})
		if d.is_empty():
			continue
		var marche := _en_marche(int(bid))
		e.tau = _avance(d, float(e.tau), dt, marche)
		_place_trains(n, d, float(e.tau), marche)
	if not brouillon.is_empty() and _fantome.get_child_count() > 1:
		var v := _fantome.get_node_or_null("Voie") as Node3D
		if v:
			_essai_tau = _avance(brouillon.design, _essai_tau, delta, essai) if essai else 0.0
			_place_trains(v, brouillon.design, _essai_tau, essai)
	if outil == "gare" and _survol_ok:
		_maj_fantome_gare()


func _vitesse_jeu() -> float:
	# Les manèges tournent en temps réel (comme les manèges du parc v1).
	return 1.0


func _en_marche(bid: int) -> bool:
	if parc == null or not parc.items.has(bid):
		return false
	var it: Dictionary = parc.items[bid]
	var e := int(it.parc)
	if e < 0 or not parc.parcs.has(e) or not bool(parc.parcs[e].ouvert) or bool(it.panne) or buildings.en_chantier(bid):
		return false
	return float(it.fin) > 0.0 or not (it.file as Array).is_empty()


## Durée d'un cycle (tour + arrêt en gare), secondes.
static func _cycle(d: Dictionary) -> float:
	var sim: Dictionary = calcule(d).sim
	var arret := VoiePhysique.ARRET_GARE if String(VoiePieces.famille(String(d.famille)).genre) != "glisse" else 6.0
	return float(sim.get("duree", 60.0)) + arret


func _avance(d: Dictionary, tau: float, dt: float, marche: bool) -> float:
	if marche:
		return tau + dt
	var nt := maxi(1, int(d.get("trains", 1)))
	if nt > 1:
		return tau  # les bateaux s'arrêtent où ils sont
	# Un seul train : il finit son tour, puis attend en gare.
	var cyc := _cycle(d)
	var duree := float(calcule(d).sim.get("duree", 60.0))
	var ph := fposmod(tau, cyc)
	if ph > 0.0 and ph < duree:
		return minf(tau + dt, tau - ph + duree)
	return tau


## Position (abscisse curviligne) d'un temps du tour.
static func _s_au_temps(sim: Dictionary, t: float) -> float:
	var tt: PackedFloat32Array = sim.t
	var ss: PackedFloat32Array = sim.s
	if tt.is_empty():
		return 0.0
	if t <= 0.0:
		return 0.0
	if t >= tt[tt.size() - 1]:
		return ss[ss.size() - 1]
	var lo := 0
	var hi := tt.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if tt[mid] <= t:
			lo = mid
		else:
			hi = mid
	var f := (t - tt[lo]) / maxf(tt[hi] - tt[lo], 0.0001)
	return lerpf(ss[lo], ss[hi], f)


## Repère sur la voie à l'abscisse s (bouclée si le circuit l'est).
static func repere(tr: Dictionary, sim: Dictionary, s: float) -> Transform3D:
	var ss: PackedFloat32Array = sim.s
	var P: PackedVector3Array = tr.P
	var n := P.size()
	if n < 2:
		return Transform3D()
	var total := ss[n - 1]
	if bool(tr.get("ferme", false)) and not bool(tr.get("ouvert", false)):
		s = fposmod(s, total)
	s = clampf(s, 0.0, total)
	var i := clampi(int(s / VoiePieces.PAS), 0, n - 2)
	while i < n - 2 and ss[i + 1] < s:
		i += 1
	while i > 0 and ss[i] > s:
		i -= 1
	var f := clampf((s - ss[i]) / maxf(ss[i + 1] - ss[i], 0.0001), 0.0, 1.0)
	var U: PackedVector3Array = sim.Ub
	var F: PackedVector3Array = tr.F
	var p := P[i].lerp(P[i + 1], f)
	var fw := F[i].lerp(F[i + 1], f).normalized()
	var up := U[i].lerp(U[i + 1], f).normalized()
	var r := fw.cross(up).normalized()
	up = r.cross(fw).normalized()
	return Transform3D(Basis(r, up, -fw), p)


func _place_trains(root: Node3D, d: Dictionary, tau: float, marche: bool) -> void:
	var tn := root.get_node_or_null("Trains")
	if tn == null:
		return
	var c := calcule(d)
	var tr: Dictionary = c.tr
	var sim: Dictionary = c.sim
	if (sim.s as PackedFloat32Array).is_empty():
		return
	var f := VoiePieces.famille(String(d.famille))
	var lv := float(f.lv) * 1.08
	var gare := float(f.gare)
	var nt := maxi(1, int(d.get("trains", f.get("trains", 1))))
	var cyc := _cycle(d)
	var duree := float(sim.get("duree", 60.0))
	var ouvert := bool(tr.get("ouvert", false))
	var s0 := gare * 0.85
	var genre := String(f.genre)
	for car: MeshInstance3D in tn.get_children():
		var t := int(car.get_meta("train"))
		var rang := int(car.get_meta("rang"))
		var ph := fposmod(tau + t * cyc / nt, cyc)
		var s := 0.0
		if ouvert:
			s = _s_au_temps(sim, ph) if ph < duree else -1.0
			car.visible = s >= 0.0 and (marche or ph > 0.0)
			if s < 0.0:
				continue
		else:
			s = s0 + _s_au_temps(sim, ph) - rang * lv
			if ph >= duree:
				s = s0 - rang * lv - (t * lv * 0.0)
		var xf := repere(tr, sim, s)
		if genre == "eau" and String(d.famille) == "riviere":
			xf.basis = xf.basis * Basis(Vector3.UP, ph * 0.6 + t)
		var off := Vector3.ZERO if genre != "rail" else xf.basis.y * 0.05
		if genre == "glisse":
			off = -xf.basis.y * 0.15
		xf.origin += off
		car.transform = xf
		if not ouvert:
			car.visible = true


# --- Brouillon -----------------------------------------------------------------------------------

## Commence une nouvelle attraction (ou un modèle tout prêt) : on pose la gare.
func nouveau(fam_id: String, modele: Dictionary = {}) -> void:
	annuler()
	var d := nouveau_design(fam_id)
	if not modele.is_empty():
		var id := String(d.id)
		d = modele.duplicate(true)
		d["id"] = id
	register(d)
	brouillon = {"design": d, "center": Vector2i.ZERO, "r": _rot, "bid": -1, "place": false}
	outil = "gare"
	essai = false
	chaine = false
	_aide()
	changed.emit()


## Reprend le tracé d'une attraction posée (elle est fermée pendant les travaux).
func modifier(bid: int) -> void:
	if not buildings.buildings.has(bid):
		return
	var t := String(buildings.buildings[bid].t)
	var d := design_of_type(t)
	if d.is_empty():
		return
	annuler()
	var b: Dictionary = buildings.buildings[bid]
	var rect := buildings._rect_of(b)
	brouillon = {"design": d.duplicate(true), "center": buildings._center_of(b), "r": int(b.r), "bid": bid, "place": true,
		"avant": VoiePhysique.prix(d, calcule(d).sim)}
	brouillon.design["id"] = String(d.id) + "e"
	_calc.erase(String(brouillon.design.id))
	if _poses.has(bid):
		(_poses[bid].node as Node3D).visible = false
	outil = "trace"
	_maj_brouillon()
	focus_requested.emit(BuildingSystem.rect_center(rect))
	_aide()
	changed.emit()


func annuler() -> void:
	if not brouillon.is_empty():
		var bid := int(brouillon.get("bid", -1))
		if bid >= 0 and _poses.has(bid) and is_instance_valid(_poses[bid].node):
			(_poses[bid].node as Node3D).visible = true
		var id := String(brouillon.design.get("id", ""))
		# Un dessin jamais construit quitte le catalogue.
		if bid < 0 and not _type_utilise(catalog_id(id)):
			designs.erase(id)
			BuildingCatalog.all_types().erase(catalog_id(id))
		elif bid >= 0:
			designs.erase(id)
			BuildingCatalog.all_types().erase(catalog_id(id))
	brouillon = {}
	outil = ""
	essai = false
	for c in _fantome.get_children():
		if c != _apercu:
			c.queue_free()
	_apercu.mesh = null
	info_changed.emit("")
	changed.emit()


func _type_utilise(cid: String) -> bool:
	if buildings == null:
		return false
	for b in buildings.buildings.values():
		if String(b.t) == cid:
			return true
	return false


func actif() -> bool:
	return outil != ""


func set_inactive() -> void:
	if outil == "gare" and not bool(brouillon.get("place", false)):
		annuler()


func design() -> Dictionary:
	return brouillon.get("design", {})


func resultat() -> Dictionary:
	return calcule(design()) if not brouillon.is_empty() else {}


func pente() -> int:
	return VoiePieces.pente_fin(design().get("pieces", []))


func ajoute(piece_id: String) -> bool:
	if brouillon.is_empty():
		return false
	var d := design()
	var r := VoiePieces.refus(String(d.famille), pente(), piece_id, bool(d.get("raccord", false)))
	if r != "":
		message.emit(r)
		return false
	var e := {"p": piece_id}
	if chaine and String(VoiePieces.famille(String(d.famille)).genre) != "glisse":
		e["chaine"] = true
	(d.pieces as Array).append(e)
	_maj_brouillon()
	Son.jouer("ui_clic", -8.0, 0.0, "Interface")
	return true


func retire_derniere() -> void:
	if brouillon.is_empty():
		return
	var d := design()
	if bool(d.get("raccord", false)):
		d.raccord = false
	elif not (d.pieces as Array).is_empty():
		(d.pieces as Array).pop_back()
	_maj_brouillon()


func vide() -> void:
	if brouillon.is_empty():
		return
	design().pieces = []
	design().raccord = false
	_maj_brouillon()


## Boucle le circuit par un raccord automatique jusqu'à la gare.
func boucler() -> void:
	if brouillon.is_empty():
		return
	var d := design()
	if bool(VoiePieces.famille(String(d.famille)).get("ouvert", false)):
		message.emit("Un toboggan ne se boucle pas : termine-le par un bassin d'arrivée.")
		return
	d.raccord = true
	_calc.erase(String(d.id))
	var c := calcule(d)
	if not bool(c.tr.ferme):
		d.raccord = false
		var info: Dictionary = c.tr.get("raccord_info", {})
		message.emit(String(info.get("raison", "Impossible de boucler d'ici.")))
	_maj_brouillon()


func regle(cle: String, valeur: Variant) -> void:
	if brouillon.is_empty():
		return
	design()[cle] = valeur
	_maj_brouillon()


## Recalcule le brouillon, le dessine et met le catalogue à jour.
func _maj_brouillon() -> void:
	if brouillon.is_empty():
		return
	var d := design()
	register(d)
	for c in _fantome.get_children():
		if c != _apercu:
			_fantome.remove_child(c)
			c.queue_free()
	if bool(brouillon.place):
		var xf := _xf_brouillon()
		_fantome.global_transform = xf
		var v := _construit_voie(d, xf)
		_fantome.add_child(v)
		if int(brouillon.bid) < 0:
			var g := MeshInstance3D.new()
			g.name = "Gare"
			g.mesh = BuildingCatalog.build_mesh(catalog_id(String(d.id)), ParcTypes.material())
			_fantome.add_child(g)
	changed.emit()


func _xf_brouillon() -> Transform3D:
	var cid := catalog_id(String(design().id))
	var r := int(brouillon.r)
	var rect := BuildingSystem.rect_for(cid, brouillon.center, r)
	var h := 0.0
	var bid := int(brouillon.bid)
	if bid >= 0 and buildings.buildings.has(bid):
		h = float(buildings.buildings[bid].h)
	else:
		var res := buildings.check_place(cid, brouillon.center, r)
		h = float(res.get("h", 0.0))
		if (not bool(res.get("ok", false)) or is_nan(h)) and world != null:
			h = world.raw_height(float(brouillon.center.x) + 0.5, float(brouillon.center.y) + 0.5)
		if is_nan(h):
			h = 0.0
	return Transform3D(Basis(Vector3.UP, -r * PI / 2.0), BuildingSystem.rect_center(rect) + Vector3(0, h, 0))


## Aperçu (transparent) de la pièce survolée dans le panneau.
func apercu(piece_id: String) -> void:
	if brouillon.is_empty() or piece_id == "" or not bool(brouillon.place):
		_apercu.mesh = null
		return
	var d := design().duplicate(true)
	d.erase("id")
	if VoiePieces.refus(String(d.famille), pente(), piece_id, bool(d.get("raccord", false))) != "":
		_apercu.mesh = null
		return
	(d.pieces as Array).append({"p": piece_id})
	var tr := VoiePieces.trace(d)
	var P: PackedVector3Array = tr.P
	var debut: int = (tr.debuts as PackedInt32Array)[(d.pieces as Array).size() - 1]
	var k := BlocMesh.new()
	for i in range(maxi(debut - 1, 0), P.size() - 1):
		ParcTypes.beam(k, P[i] + Vector3(0, 0.2, 0), P[i + 1] + Vector3(0, 0.2, 0), 1.6, Color.WHITE)
	_apercu.mesh = k.to_mesh()


## Fin du tracé (repère monde), pour y amener la caméra.
func fin_monde() -> Vector3:
	if brouillon.is_empty():
		return Vector3.ZERO
	var tr: Dictionary = calcule(design()).tr
	var p: Vector3 = (tr.fin as Dictionary).pos
	return _xf_brouillon() * p


## Construit (ou modifie) l'attraction : chantier de la gare, la voie suit.
func construire() -> bool:
	if brouillon.is_empty() or not bool(brouillon.place):
		return false
	var d := design()
	var c := calcule(d)
	if not bool(c.sim.ok):
		message.emit(String((c.sim.erreurs as Array)[0]) if not (c.sim.erreurs as Array).is_empty() else "Le tracé n'est pas terminé.")
		return false
	var conflit := conflits()
	if conflit != "":
		message.emit(conflit)
		return false
	var bid := int(brouillon.bid)
	if bid < 0:
		var cid := register(d)
		var nb := buildings.place(cid, brouillon.center, int(brouillon.r))
		if nb < 0:
			return false
		brouillon = {}
		outil = ""
		for ch in _fantome.get_children():
			if ch != _apercu:
				ch.queue_free()
		_apercu.mesh = null
		message.emit("Chantier de « %s » lancé : %s." % [String(d.nom), BuildingSystem.format_money(VoiePhysique.prix(d, c.sim))])
	else:
		# Modification : le dessin d'origine prend le nouveau tracé.
		var old_id := String(design_of_type(String(buildings.buildings[bid].t)).get("id", ""))
		var nd := d.duplicate(true)
		nd["id"] = old_id
		designs.erase(String(d.id))
		BuildingCatalog.all_types().erase(catalog_id(String(d.id)))
		_calc.erase(old_id)
		register(nd)
		var diff := VoiePhysique.prix(nd, calcule(nd).sim) - int(brouillon.get("avant", 0))
		if diff > 0 and not buildings.unlimited_money:
			buildings.money -= diff
		for b2 in buildings.buildings.keys():
			if String(buildings.buildings[b2].t) == catalog_id(old_id):
				_detache(int(b2))
				_attache(int(b2))
		brouillon = {}
		outil = ""
		for ch in _fantome.get_children():
			if ch != _apercu:
				ch.queue_free()
		message.emit("Tracé de « %s » modifié (%s)." % [String(nd.nom), ("+" + BuildingSystem.format_money(diff)) if diff > 0 else "sans surcoût"])
		buildings.changed.emit()
	info_changed.emit("")
	changed.emit()
	return true


## Le tracé traverse-t-il un bâtiment ? "" si non.
func conflits() -> String:
	if brouillon.is_empty() or buildings == null:
		return ""
	var tr: Dictionary = calcule(design()).tr
	var xf := _xf_brouillon()
	var P: PackedVector3Array = tr.P
	var propre := int(brouillon.bid)
	for i in range(0, P.size(), 4):
		var g := xf * P[i]
		var c := Vector2i(floori(g.x), floori(g.z))
		var b := buildings.building_at(c)
		if b < 0 or b == propre:
			continue
		var top := float(buildings.buildings[b].get("h", 0.0)) + BuildingCatalog.approx_height(String(buildings.buildings[b].t))
		if g.y < top + 2.0:
			return "Le tracé traverse un bâtiment (%s)." % String(BuildingCatalog.get_type(String(buildings.buildings[b].t)).get("name", "?"))
	return ""


# --- Souris : pose de la gare ---------------------------------------------------------------------

func _pick(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null or world == null:
		return null
	return world.pick_point(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


func _maj_fantome_gare() -> void:
	if brouillon.is_empty():
		return
	brouillon.center = Vector2i(floori(_survol.x), floori(_survol.z))
	brouillon.r = _rot
	var cid := catalog_id(String(design().id))
	var res := buildings.check_place(cid, brouillon.center, _rot)
	var g := _fantome.get_node_or_null("Gare") as MeshInstance3D
	if g == null:
		g = MeshInstance3D.new()
		g.name = "Gare"
		g.mesh = BuildingCatalog.build_mesh(cid, ParcTypes.material())
		_fantome.add_child(g)
	var h := float(res.get("h", _survol.y)) if bool(res.get("ok", false)) else _survol.y
	var rect := BuildingSystem.rect_for(cid, brouillon.center, _rot)
	_fantome.global_transform = Transform3D(Basis(Vector3.UP, -_rot * PI / 2.0), BuildingSystem.rect_center(rect) + Vector3(0, h if not is_nan(h) else _survol.y, 0))
	g.transparency = 0.0 if bool(res.get("ok", false)) else 0.55
	info_changed.emit("Gare de « %s » : clic pour la poser, R pour tourner. %s" % [String(design().nom), "" if bool(res.get("ok", false)) else String(res.get("reason", ""))])


func _unhandled_input(event: InputEvent) -> void:
	if outil != "gare":
		if outil == "trace" and event is InputEventKey and event.pressed and not event.echo:
			var k := event as InputEventKey
			if k.physical_keycode == KEY_BACKSPACE:
				retire_derniere()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var p: Variant = _pick((event as InputEventMouseMotion).position)
		_survol_ok = p != null
		if p != null:
			_survol = p
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_R:
			_rot = (_rot + (3 if k.shift_pressed else 1)) % 4
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_ESCAPE:
			annuler()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var p: Variant = _pick(mb.position)
		if p == null:
			return
		_survol = p
		_maj_fantome_gare()
		var cid := catalog_id(String(design().id))
		var res := buildings.check_place(cid, brouillon.center, _rot)
		if not bool(res.get("ok", false)):
			message.emit(String(res.get("reason", "Impossible de poser la gare ici.")))
		else:
			poser_gare(brouillon.center, _rot)
		get_viewport().set_input_as_handled()


## Pose la gare du brouillon (aussi utilisé par les tests).
func poser_gare(center: Vector2i, r: int) -> void:
	if brouillon.is_empty():
		return
	brouillon.center = center
	brouillon.r = r
	brouillon.place = true
	outil = "trace"
	_maj_brouillon()
	_aide()


func _aide() -> void:
	match outil:
		"gare":
			info_changed.emit("Clic : poser la gare de « %s ». R : tourner. Échap : annuler." % String(design().get("nom", "")))
		"trace":
			info_changed.emit("Ajoute les pièces dans le panneau. Retour arrière : retirer la dernière.")
		_:
			info_changed.emit("")
