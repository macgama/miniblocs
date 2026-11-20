class_name ConstructionSouterraine
extends Node
## Construire depuis la vue sous terre (VueSouterraine), au niveau affiché :
## - poser des conduites (eau, égout, gaz, fibre) à la profondeur du niveau ;
##   au −1 elles gardent leur profondeur habituelle, plus bas elles sont posées
##   en tranchée blindée puis au microtunnelier (plus cher, plus long) ;
## - déplacer une conduite enterrée (dévoiement : la nouvelle est construite,
##   l'ancienne reste en service jusqu'à la fin des travaux) ;
## - creuser des tunnels : métro, rue, voie express, train, à la profondeur du
##   niveau (−3 au moins). Raccordés à une voie de surface, ils ont leur rampe ;
## - creuser des pièces : cave, parking, entrepôt, local technique, bunker, sur
##   1 à 3 niveaux. Une fois creusées, ce sont de vrais sous-sols de l'Atelier
##   (plan "st") qu'on aménage avec les outils Murs, Porte, Escalier ;
## - supprimer ce qui est sous terre (conduite, tunnel, pièce).
## Tout se construit en chantier (SuiviChantiers), payé au fil des travaux.

signal message(text: String)
signal info_changed(text: String)
signal changed

enum Outil { AUCUN, CONDUITE, TUNNEL, PIECE, ATELIER, DEPLACER, GOMME }

const H := VueSouterraine.H
## Au-delà, on ne creuse plus de tranchée : microtunnelier ou fonçage.
const PROF_TRANCHEE_MAX := 6.0
## Les tunnels commencent au −3 (voies à 8 m) : au-dessus, ce serait une tranchée.
const NIVEAU_MIN_TUNNEL := 3
const PIECE_MAX_M2 := 3600
const PIECE_MIN := 2
const NIVEAUX_PIECE_MAX := 3

## Conduites qu'on pose depuis la vue (type de tronçon -> réseau).
## « picto » : vignette du bouton (Pictos). Les autres conduites enterrées des
## panneaux O et Maj+O (aqueduc, séparatif, chaleur, téléphone…) se posent aussi
## sous terre quand on les choisit là-bas (SousTerreAuto).
const CONDUITES := {
	"conduite_eau": {"name": "Eau", "tip": "Conduite d'eau potable", "res": "eau", "picto": "sous_eau"},
	"collecteur": {"name": "Égout", "tip": "Collecteur d'égout", "res": "egout", "picto": "sous_egout"},
	"conduite_gaz": {"name": "Gaz", "tip": "Conduite de gaz ou de chaleur", "res": "gaz", "picto": "sous_gaz"},
	"cable_souterrain": {"name": "Électricité", "tip": "Câble électrique enterré (ni poteaux, ni pannes de tempête)", "res": "elec", "picto": "sous_elec"},
	"fibre": {"name": "Fibre", "tip": "Fibre optique enterrée", "res": "telecom", "picto": "sous_fibre"},
}
## Voies qu'on creuse : prix du tunnel au mètre (base, avant le coût de la partie).
## Repères réels : métro double voie au tunnelier 50 à 80 k€/m (hors stations),
## tunnel routier urbain 60 à 150 k€/m.
const VOIES := {
	"metro": {"name": "Métro", "tip": "Tunnel de métro (double voie, tunnelier)", "prix_m": 60000, "picto": "sous_metro"},
	"rue": {"name": "Rue", "tip": "Tunnel routier urbain, une voie par sens", "prix_m": 45000, "picto": "sous_rue"},
	"voie_express": {"name": "2 × 2 voies", "tip": "Tunnel routier à deux tubes, 2 × 2 voies", "prix_m": 110000, "picto": "sous_2x2"},
	"train": {"name": "Train", "tip": "Tunnel ferroviaire", "prix_m": 70000, "picto": "sous_train"},
}
## Pièces : prix au m² et par niveau (creusement, soutènement, dalles et voiles),
## heures de travail par m², surface par place (parking, abri).
const USAGES := {
	"cave": {"name": "Cave", "prix_m2": 1100, "h_m2": 1.2, "col": Color(0.78, 0.66, 0.5, 0.5)},
	"parking": {"name": "Parking", "prix_m2": 1300, "h_m2": 1.0, "par_place": 25.0, "col": Color(0.55, 0.58, 0.62, 0.5)},
	"entrepot": {"name": "Entrepôt", "prix_m2": 1000, "h_m2": 1.0, "col": Color(0.7, 0.62, 0.42, 0.5)},
	"technique": {"name": "Local technique", "prix_m2": 1500, "h_m2": 1.4, "col": Color(0.5, 0.62, 0.7, 0.5)},
	"bunker": {"name": "Bunker (abri)", "prix_m2": 2800, "h_m2": 2.5, "par_place": 1.0, "col": Color(0.46, 0.5, 0.42, 0.55)},
}
const USAGE_ORDRE := ["cave", "parking", "entrepot", "technique", "bunker"]
## Outils de l'Atelier proposés sous terre.
## [nom, outil, infobulle, icône]
const ATELIER := [
	["Murs", PlanEditor.Tool.WALL, "Murs fins (glisser)", "mur"],
	["Porte", PlanEditor.Tool.OPENING, "Porte dans un mur", "ouverture"],
	["Escalier", PlanEditor.Tool.STAIRS, "Escalier vers le niveau du dessus", "escalier"],
	["Gomme", PlanEditor.Tool.ERASE, "Effacer murs, portes, escaliers", "gomme"],
]
const MATERIAU_PIECE := "Béton brut"

var vue: VueSouterraine
var reseaux: Reseaux
var telecom: Telecom
var transport: TransportSystem
var plans: PlanEditor
var buildings: BuildingSystem
var world: TerrainWorld
## Range les outils de la surface (terre_main._select_building_tool).
var ranger: Callable

var outil: Outil = Outil.AUCUN
var type_conduite := "conduite_eau"
var type_voie := "metro"
var usage := "cave"
var hauteur := 1
var outil_atelier: int = PlanEditor.Tool.WALL

## id -> {"r": Rect2i, "n": niveau du haut, "h": nombre de niveaux, "u": usage,
##        "av": avancement (1 = fini), "cout": int, "plan": String, "e": étage du bas
##        dans le plan, "sb": sous un bâtiment}
var pieces: Dictionary = {}
var next_id := 1
## Dévoiements en cours : [{"res", "ancien", "nouveau"}].
var deplacements: Array = []

var _sel := {}
var _grab := Vector3.INF
var _a := Vector2i.ZERO
var _drag := false
var _survol := Vector3.INF
var _fantome: MeshInstance3D
var _mat: StandardMaterial3D
var _barre: VBoxContainer
var _boutons := {}
var _info: Label
var _bilan: Label
var _haut_btn: ChoixVisuel
var _rangement := false


# --- Règles (prix, profondeurs) -------------------------------------------------------

## Coût d'une conduite selon sa profondeur (m) : tranchée jusqu'à 2 m, tranchée
## blindée jusqu'à 6 m, puis microtunnelier.
static func facteur_profondeur(d: float) -> float:
	if d <= 2.0:
		return 1.0
	if d <= PROF_TRANCHEE_MAX:
		return 1.0 + 0.25 * (d - 2.0)
	return 2.5 + 0.08 * (d - PROF_TRANCHEE_MAX)


static func facteur_heures(d: float) -> float:
	return pow(facteur_profondeur(d), 0.8)


static func methode_conduite(d: float) -> String:
	if d <= 2.0:
		return "tranchée"
	if d <= PROF_TRANCHEE_MAX:
		return "tranchée blindée"
	return "microtunnelier"


## Nom d'une conduite : celles de la barre, puis les tronçons du panneau O et les câbles des télécoms.
static func nom_conduite(type_id: String) -> String:
	if CONDUITES.has(type_id):
		return String(CONDUITES[type_id].tip)
	if est_telecom(type_id):
		return String(Telecom.CABLES[type_id].name)
	return String(ReseauxTypes.troncon(type_id).get("name", type_id))


## Câble des télécoms (fibre, téléphone, coaxial) plutôt que tronçon du panneau O.
static func est_telecom(type_id: String) -> bool:
	return Telecom.CABLES.has(type_id)


static func outil_telecom(type_id: String) -> Telecom.Outil:
	for o in Telecom.OUTIL_CABLE:
		if String(Telecom.OUTIL_CABLE[o]) == type_id:
			return o
	return Telecom.Outil.FIBRE


## Profondeur de l'axe d'une conduite posée au niveau n : sa profondeur habituelle
## au −1, le milieu du niveau plus bas.
static func profondeur_conduite(type_id: String, n: int) -> float:
	if n <= 1:
		return float(VueSouterraine.TRONCONS.get(type_id, {"d": 1.2}).d)
	return (n - 0.5) * H


## Profondeur des voies (rails ou chaussée) d'un tunnel creusé au niveau n.
static func profondeur_voie(n: int) -> float:
	return n * H - 1.0


## Prix d'un mètre de tunnel : moins cher en tranchée couverte (peu profond),
## plus cher très profond (puits, ventilation).
static func prix_tunnel_m(type_id: String, prof: float) -> float:
	var p := float(VOIES.get(type_id, {"prix_m": 50000}).prix_m)
	if not VOIES.has(type_id):
		var w := TransportTypes.width_of(type_id, TransportTypes.default_spec(type_id))
		p = 5000.0 * w
	if prof < 10.0:
		p *= 0.6
	elif prof > 20.0:
		p *= 1.0 + 0.01 * (prof - 20.0)
	return p


## Prix des parties en tunnel d'un tracé (rampes et parties au sol : comme en surface).
static func prix_tunnel(type_id: String, pts: PackedVector3Array, st: PackedByteArray, prof: float) -> int:
	return ReglagesPartie.prix(roundi(longueur_tunnel(pts, st) * prix_tunnel_m(type_id, prof)))


static func longueur_tunnel(pts: PackedVector3Array, st: PackedByteArray) -> float:
	var l := 0.0
	for i in range(pts.size() - 1):
		if i + 1 < st.size() and st[i] == TransportTypes.Struct.TUNNEL and st[i + 1] == TransportTypes.Struct.TUNNEL:
			l += pts[i].distance_to(pts[i + 1])
	return l


## Prix d'une pièce : aire × niveaux × prix au m², +6 % par niveau de profondeur,
## +50 % sous un bâtiment (reprise en sous-œuvre).
static func prix_piece(u: String, aire: int, h: int, n_bas: int, sous_bati := false) -> int:
	var p := float(aire * h) * float(USAGES[u].prix_m2) * (1.0 + 0.06 * (n_bas - 1))
	if sous_bati:
		p *= 1.5
	return ReglagesPartie.prix(roundi(p))


static func heures_piece(u: String, aire: int, h: int, n_bas: int) -> float:
	return maxf(float(aire * h) * float(USAGES[u].h_m2) * (1.0 + 0.04 * (n_bas - 1)), 8.0)


## Places d'une pièce (parking : 25 m², abri : 1 m² par personne) ; 0 sinon.
static func niveaux_txt(h: int) -> String:
	return "1 niveau" if h <= 1 else "%d niveaux" % h


static func places_de(u: String, aire: int, h: int) -> int:
	var pp := float(USAGES.get(u, {}).get("par_place", 0.0))
	return 0 if pp <= 0.0 else floori(float(aire * h) / pp)


# --- Mise en place -----------------------------------------------------------------------

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = true
	_mat.render_priority = 2
	_fantome = MeshInstance3D.new()
	_fantome.name = "FantomeSouterrain"
	_fantome.layers = VueSouterraine.COUCHE
	_fantome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fantome.material_override = _mat
	add_child(_fantome)


## Les fantômes des outils de surface se voient aussi dans la vue sous terre.
func setup() -> void:
	var couche := VueSouterraine.COUCHE
	if plans != null:
		for n in [plans._ghost, plans._grid]:
			if n != null:
				(n as VisualInstance3D).layers |= couche
	if reseaux != null and reseaux.vue != null and reseaux.vue._fantome != null:
		reseaux.vue._fantome.layers |= couche
	if telecom != null and telecom._trace_mesh != null:
		telecom._trace_mesh.layers |= couche
	if transport != null:
		for n in [transport._preview, transport._marker, transport._ctrl_marker]:
			if n != null:
				(n as VisualInstance3D).layers |= couche
		transport.edges_built.connect(_on_edges_built)
	if SuiviChantiers.instance != null:
		SuiviChantiers.instance.termine.connect(func(_k: String) -> void: _verifier_deplacements())


func niveau() -> int:
	return maxi(vue.niveau, 1) if vue != null else 1


# --- Outils ------------------------------------------------------------------------------

func activer(o: Outil, param := "") -> void:
	if vue == null or not vue.actif:
		return
	_ranger_tout()
	outil = o
	_sel = {}
	_drag = false
	match o:
		Outil.CONDUITE:
			if param != "":
				type_conduite = param
		Outil.TUNNEL:
			if param != "":
				type_voie = param
			if transport.relais.is_valid() or transport.bloque_reseau():
				message.emit("En ligne, les tunnels ne se creusent pas encore depuis la vue sous terre.")
				outil = Outil.AUCUN
		Outil.PIECE:
			if USAGES.has(param):
				usage = param
		Outil.ATELIER:
			if param != "":
				outil_atelier = int(param)
	_appliquer_niveau()
	_maj_boutons()
	_aide()


## Échap (reçu par la vue) : arrête le tracé en cours, sinon range l'outil.
func echap() -> void:
	match outil:
		Outil.CONDUITE:
			if est_telecom(type_conduite) and not telecom._trace.is_empty():
				telecom._trace.clear()
				telecom._dessiner_trace()
				return
			if not est_telecom(type_conduite) and reseaux._trace.size() > 0:
				reseaux._trace = PackedVector3Array()
				if reseaux.vue:
					reseaux.vue.fantome(PackedVector3Array(), Color.WHITE)
				reseaux._aide()
				return
		Outil.TUNNEL:
			if not transport._start.is_empty():
				transport.cancel()
				return
		Outil.ATELIER:
			if plans._drag:
				plans._drag = false
				plans._update_ghost()
				return
		Outil.PIECE, Outil.DEPLACER:
			if _drag or not _sel.is_empty():
				_drag = false
				_sel = {}
				_dessiner_fantome()
				_aide()
				return
	desactiver()


func desactiver() -> void:
	var avant := outil
	outil = Outil.AUCUN
	_sel = {}
	_drag = false
	if avant != Outil.AUCUN:
		_ranger_tout()
	_remettre_profondeurs()
	if _fantome != null:
		_fantome.mesh = null
	_maj_boutons()
	info_changed.emit("")
	if _info != null:
		_info.text = ""


func _remettre_profondeurs() -> void:
	RoutePlanner.profondeur_forcee = NAN
	if reseaux != null:
		reseaux.profondeur_pose = NAN
	if telecom != null:
		telecom.profondeur_pose = NAN
	if plans != null:
		plans.sous_terre = false


func _ranger_tout() -> void:
	_rangement = true
	if ranger.is_valid():
		ranger.call()
	if reseaux != null:
		reseaux.set_inactive()
	if telecom != null:
		telecom.set_inactive()
	if transport != null:
		transport.set_inactive()
	if plans != null:
		plans.set_inactive()
	_remettre_profondeurs()
	_rangement = false


## Le niveau affiché a changé (Page bas / Page haut) : l'outil suit.
func _appliquer_niveau() -> void:
	var n := niveau()
	_remettre_profondeurs()
	match outil:
		Outil.CONDUITE:
			var prof := profondeur_conduite(type_conduite, n)
			if est_telecom(type_conduite):
				telecom.profondeur_pose = prof
				if telecom.outil != outil_telecom(type_conduite):
					telecom.set_outil(outil_telecom(type_conduite))
			else:
				reseaux.profondeur_pose = prof
				if reseaux.outil != Reseaux.Outil.TRACER or reseaux.type_troncon != type_conduite:
					reseaux.set_outil(Reseaux.Outil.TRACER, type_conduite)
				else:
					reseaux._aide()
		Outil.TUNNEL:
			if n < NIVEAU_MIN_TUNNEL:
				message.emit("Tunnels : descendez au moins au Sous-sol −%d (Page bas) ; plus haut, ce serait une tranchée." % NIVEAU_MIN_TUNNEL)
				transport.set_inactive()
			else:
				RoutePlanner.profondeur_forcee = profondeur_voie(n)
				if transport.tool != TransportSystem.Tool.BUILD or transport.type_id != type_voie:
					transport.set_build(type_voie)
				else:
					transport._update_preview()
		Outil.ATELIER:
			plans.sous_terre = true
			plans.set_level(-n)
			if plans.tool != outil_atelier:
				plans.set_tool(outil_atelier)
	_aide()


func niveau_change() -> void:
	if outil != Outil.AUCUN:
		_appliquer_niveau()


## L'outil délégué a été rangé ailleurs (Échap, autre outil) : on s'arrête aussi.
func _process(_delta: float) -> void:
	if outil == Outil.AUCUN or _rangement:
		return
	var parti := false
	match outil:
		Outil.CONDUITE:
			if est_telecom(type_conduite):
				parti = telecom.outil != outil_telecom(type_conduite)
			else:
				parti = reseaux.outil != Reseaux.Outil.TRACER or reseaux.type_troncon != type_conduite
		Outil.TUNNEL:
			if niveau() >= NIVEAU_MIN_TUNNEL:
				parti = transport.tool != TransportSystem.Tool.BUILD or transport.type_id != type_voie
				if not parti:
					_fantome_tunnel()
		Outil.ATELIER:
			parti = plans.tool == PlanEditor.Tool.NONE
			if not parti and plans.level != -niveau() and plans.level < 0:
				vue.set_niveau(-plans.level)
	if parti:
		desactiver()


func _aide() -> void:
	var t := ""
	var n := niveau()
	match outil:
		Outil.CONDUITE:
			var d := profondeur_conduite(type_conduite, n)
			t = "%s à %s m (%s, prix ×%s). Clic pour chaque point, clic droit pour finir." % [
				nom_conduite(type_conduite), TransportTypes._num(snappedf(d, 0.1)), methode_conduite(d),
				TransportTypes._num(snappedf(facteur_profondeur(d), 0.01))]
		Outil.TUNNEL:
			if n < NIVEAU_MIN_TUNNEL:
				t = "Tunnels : à partir du Sous-sol −%d." % NIVEAU_MIN_TUNNEL
			else:
				var pd := profondeur_voie(n)
				t = "%s à %d m : %s le mètre de tunnel, payé au fil des travaux. Raccordé à une voie de surface, il a sa rampe." % [
					VOIES[type_voie].tip, roundi(pd), BuildingSystem.format_money(ReglagesPartie.prix(roundi(prix_tunnel_m(type_voie, pd))))]
				if not transport._plan.is_empty() and transport._plan.get("ok", false):
					var c := prix_tunnel(type_voie, transport._plan.pts, transport._plan.st, pd)
					t += "  Tracé : %d m de tunnel, %s." % [roundi(longueur_tunnel(transport._plan.pts, transport._plan.st)), BuildingSystem.format_money(c)]
		Outil.PIECE:
			var u: Dictionary = USAGES[usage]
			t = "%s sur %s (−%d à −%d) : glisser un rectangle. %s le m² par niveau." % [String(u.name), niveaux_txt(hauteur),
				n, n + hauteur - 1, BuildingSystem.format_money(ReglagesPartie.prix(int(u.prix_m2)))]
			if _drag and _survol.is_finite():
				var r := _rect(_a, _cellule(_survol))
				var sb := _sous_bati(r)
				t += "  %d × %d m : %s%s." % [r.size.x, r.size.y,
					BuildingSystem.format_money(prix_piece(usage, r.size.x * r.size.y, hauteur, n + hauteur - 1, sb)),
					" (sous un bâtiment : reprise en sous-œuvre)" if sb else ""]
		Outil.ATELIER:
			t = "Atelier au Sous-sol −%d : murs, portes et escaliers dans les pièces creusées." % n
		Outil.DEPLACER:
			if _sel.is_empty():
				t = "Déplacer : clic sur une conduite enterrée."
			else:
				t = "Déplacer : clic à la nouvelle place (posée au Sous-sol −%d). La conduite reste en service jusqu'à la fin des travaux. Clic droit : annuler." % n
		Outil.GOMME:
			t = "Supprimer : clic sur une pièce, une conduite ou un tunnel du niveau."
	if _info != null:
		_info.text = t
	info_changed.emit(t)


# --- Souris --------------------------------------------------------------------------------

func _pick(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null or world == null:
		return null
	return world.pick_point(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


static func _cellule(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


static func _rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _unhandled_input(event: InputEvent) -> void:
	if outil != Outil.PIECE and outil != Outil.DEPLACER and outil != Outil.GOMME:
		return
	if vue == null or not vue.actif:
		return
	var mm := event as InputEventMouseMotion
	if mm:
		var hit: Variant = _pick(mm.position)
		if hit != null:
			_survol = hit
			_dessiner_fantome()
			if outil == Outil.PIECE and _drag:
				_aide()
		return
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _drag or not _sel.is_empty():
				_drag = false
				_sel = {}
				_dessiner_fantome()
				_aide()
			else:
				desactiver()
			get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit: Variant = _pick(mb.position)
		if hit == null:
			return
		get_viewport().set_input_as_handled()
		var p: Vector3 = hit
		match outil:
			Outil.PIECE:
				if mb.pressed:
					_drag = true
					_a = _cellule(p)
				elif _drag:
					_drag = false
					creuser(_rect(_a, _cellule(p)), niveau(), hauteur, usage)
				_dessiner_fantome()
			Outil.DEPLACER:
				if not mb.pressed:
					return
				if _sel.is_empty():
					_sel = conduite_pres(p, 8.0)
					_grab = p
					if _sel.is_empty():
						message.emit("Pas de conduite enterrée ici.")
				else:
					deplacer(_sel, Vector2(p.x - _grab.x, p.z - _grab.z), niveau())
					_sel = {}
				_dessiner_fantome()
				_aide()
			Outil.GOMME:
				if mb.pressed:
					supprimer_a(p, niveau())
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		if _drag or not _sel.is_empty():
			_drag = false
			_sel = {}
			_dessiner_fantome()
		else:
			desactiver()
		get_viewport().set_input_as_handled()


# --- Pièces --------------------------------------------------------------------------------

## Vrai si un bâtiment (catalogue ou Atelier) est au-dessus d'une case du rectangle.
func _sous_bati(r: Rect2i) -> bool:
	for x in range(r.position.x, r.end.x):
		for z in range(r.position.y, r.end.y):
			var c := Vector2i(x, z)
			if (buildings != null and buildings.occupancy.has(c)) or (plans != null and plans.cells.has(c)):
				return true
	return false


## Raison pour laquelle on ne peut pas creuser ici ("" si possible).
func raison_piece(r: Rect2i, n: int, h: int) -> String:
	if r.size.x < PIECE_MIN or r.size.y < PIECE_MIN:
		return "Pièce trop petite : %d × %d m au moins." % [PIECE_MIN, PIECE_MIN]
	if r.size.x * r.size.y * h > PIECE_MAX_M2:
		return "Pièce trop grande : %d m² au plus (tous niveaux comptés)." % PIECE_MAX_M2
	if n + h - 1 > VueSouterraine.NIVEAU_MAX:
		return "On ne creuse pas sous −%d." % VueSouterraine.NIVEAU_MAX
	for x in range(r.position.x, r.end.x):
		for z in range(r.position.y, r.end.y):
			if world != null and is_nan(world.cell_height(Vector2i(x, z))):
				return "Relief encore en chargement."
	var rf := Rect2(Vector2(r.position), Vector2(r.size))
	for k in range(n, n + h):
		# Les réseaux de la rue (jusqu'à 3 m) occupent le −1 sous les voies.
		if k == 1 and transport != null:
			for x in range(r.position.x, r.end.x):
				for z in range(r.position.y, r.end.y):
					if transport.is_cell_occupied(Vector2i(x, z)):
						return "Les réseaux de la rue passent ici : creusez à partir du Sous-sol −2."
		for id in pieces:
			var pc: Dictionary = pieces[id]
			if k >= int(pc.n) and k < int(pc.n) + int(pc.h) and (pc.r as Rect2i).intersects(r):
				return "Une autre pièce souterraine occupe déjà ce niveau."
		if buildings != null:
			for bid in buildings.buildings:
				var b: Dictionary = buildings.buildings[bid]
				var br: Rect2i = buildings._rect_of(b)
				if br.intersects(r) and k <= VueSouterraine.sous_sols_de(String(b.t), b):
					return "Le sous-sol de ce bâtiment occupe déjà le −%d." % k
		if plans != null:
			for pid in plans.plans:
				if not (plans._bbox.get(pid, Rect2i()) as Rect2i).intersects(r):
					continue
				var e := _etage_de(pid, k, r.get_center())
				for fk in plans.plans[pid].floors:
					var kf: Vector3i = fk
					if kf.y == e and r.has_point(Vector2i(kf.x, kf.z)):
						return "Un sous-sol de l'Atelier occupe déjà ce niveau."
		var d0 := (k - 1) * H
		var d1 := k * H
		# Tunnels et métro qui traversent ce niveau.
		if transport != null:
			for eid in transport.edges_near(Vector3(rf.get_center().x, 0, rf.get_center().y), rf.size.length() / 2.0 + 20.0):
				var ed: Dictionary = transport.network.edges[eid]
				var pts: PackedVector3Array = ed.pts
				var st: PackedByteArray = ed.st
				var hw := TransportTypes.width_of(String(ed.t), ed.get("w", {})) / 2.0 + 1.0
				for i in pts.size():
					if st[i] != TransportTypes.Struct.TUNNEL:
						continue
					var q := pts[i]
					if not rf.grow(hw).has_point(Vector2(q.x, q.z)):
						continue
					var g := _sol(q.x, q.z, q.y)
					var bas := g - q.y + 0.6
					var haut := bas - 7.0
					if bas > d0 and haut < d1:
						return "Un tunnel passe à ce niveau."
		# Conduites enterrées (axe ± demi-section).
		for tr in _tous_troncons():
			var spec: Dictionary = VueSouterraine.TRONCONS.get(String(tr.t), {})
			if spec.is_empty():
				continue
			var d := float(tr.get("prof", spec.d))
			var s := float(spec.s) / 2.0
			if d + s <= d0 or d - s >= d1:
				continue
			for q in (tr.pts as PackedVector3Array):
				if rf.grow(s + 0.3).has_point(Vector2(q.x, q.z)):
					return "Une conduite passe à ce niveau : déplacez-la d'abord."
	return ""


func _tous_troncons() -> Array:
	var out := []
	if reseaux != null:
		for r in reseaux.tous():
			for id in (r as ReseauBase).troncons:
				out.append((r as ReseauBase).troncons[id])
	if telecom != null:
		for r in [telecom.fibre, telecom.cuivre]:
			for id in (r as ReseauBase).troncons:
				out.append((r as ReseauBase).troncons[id])
	return out


func _sol(x: float, z: float, defaut := 0.0) -> float:
	if world == null:
		return defaut
	var h := world.cell_height(Vector2i(floori(x), floori(z)))
	return defaut if is_nan(h) else h


## Étage d'un plan de l'Atelier qui correspond au niveau n de la vue (même fond).
func _etage_de(pid: String, n: int, c: Vector2i) -> int:
	var y0 := float(plans.plans[pid].y0)
	var bas := _sol(c.x + 0.5, c.y + 0.5, y0) - n * H
	return clampi(roundi((bas - y0) / H), PlanEditor.MIN_LEVEL, PlanEditor.MAX_LEVEL)


## Creuse une pièce (rectangle de cases) du niveau n sur h niveaux. Renvoie son id, ou -1.
func creuser(r: Rect2i, n: int, h: int, u: String) -> int:
	if not USAGES.has(u):
		return -1
	h = clampi(h, 1, NIVEAUX_PIECE_MAX)
	var why := raison_piece(r, n, h)
	if why != "":
		message.emit(why)
		return -1
	var aire := r.size.x * r.size.y
	var sb := _sous_bati(r)
	var cout := prix_piece(u, aire, h, n + h - 1, sb)
	var id := next_id
	next_id += 1
	pieces[id] = {"r": r, "n": n, "h": h, "u": u, "av": 0.0, "cout": cout, "plan": "", "e": 0, "sb": sb}
	var places := places_de(u, aire, h)
	var txt := "%s de %d m² sur %s : %s, payé au fil des travaux." % [String(USAGES[u].name), aire, niveaux_txt(h),
		BuildingSystem.format_money(cout)]
	if places > 0:
		txt += " " + "%d places." % places
	message.emit(txt)
	_lancer(id)
	changed.emit()
	if vue != null:
		vue.marquer_sale()
	return id


static func cle(id: int) -> String:
	return "piece_st:%d" % id


func _lancer(id: int) -> void:
	var pc: Dictionary = pieces[id]
	var sc := SuiviChantiers.instance
	if sc == null or not is_instance_valid(sc) or not sc.is_inside_tree() or Chantiers.instantanes():
		var du := roundi(float(pc.cout) * (1.0 - float(pc.av)))
		if buildings != null and not buildings.unlimited_money:
			buildings.money -= du
		_realiser(id)
		return
	var r: Rect2i = pc.r
	sc.commencer(cle(id), heures_piece(String(pc.u), r.size.x * r.size.y, int(pc.h), int(pc.n) + int(pc.h) - 1),
		func(a: float, _et = null) -> void:
			if pieces.has(id) and float(pieces[id].av) < 1.0:
				pieces[id].av = a
				if vue != null:
					vue.marquer_sale(),
		func() -> void: _realiser(id),
		float(pc.av), int(pc.cout), Chantiers.ETAPES_PIECE)


## Fin du chantier : la pièce devient un vrai sous-sol de l'Atelier (dalles et
## murs en béton), qu'on aménage ensuite (portes, escaliers, mobilier).
func _realiser(id: int) -> void:
	if not pieces.has(id):
		return
	var pc: Dictionary = pieces[id]
	pc.av = 1.0
	var r: Rect2i = pc.r
	var n := int(pc.n)
	var h := int(pc.h)
	if plans != null and String(pc.plan) == "":
		# Collée à une autre pièce souterraine : même plan (on passe de l'une à l'autre).
		var pid := ""
		for x in range(r.position.x - 1, r.end.x + 1):
			for z in range(r.position.y - 1, r.end.y + 1):
				var c := Vector2i(x, z)
				if pid == "" and plans.cells_st.has(c):
					pid = String(plans.cells_st[c])
		if pid == "":
			pid = plans.new_plan(plans.ground_level(r.get_center()), true)
		var e_bas := _etage_de(pid, n + h - 1, r.get_center())
		var mat_avant := plans.material
		var m := BlocMateriaux.index_of(MATERIAU_PIECE)
		if m >= 0:
			plans.material = m
		var fait := plans.add_room(pid, r, e_bas, h, false)
		plans.material = mat_avant
		if fait:
			pc.plan = pid
			pc.e = e_bas
		else:
			plans._drop_if_empty(pid)
	message.emit("Travaux terminés : %s de %d m² au Sous-sol −%d." % [String(USAGES[pc.u].name).to_lower(), r.size.x * r.size.y, n])
	changed.emit()
	if vue != null:
		vue.marquer_sale()


func piece_a(c: Vector2i, n: int) -> int:
	for id in pieces:
		var pc: Dictionary = pieces[id]
		if n >= int(pc.n) and n < int(pc.n) + int(pc.h) and (pc.r as Rect2i).has_point(c):
			return id
	return -1


## Comble une pièce : le chantier en cours s'arrête (ce qui est payé est perdu).
func combler(id: int) -> void:
	if not pieces.has(id):
		return
	var pc: Dictionary = pieces[id]
	if SuiviChantiers.instance != null:
		SuiviChantiers.instance.annuler(cle(id))
	var pid := String(pc.plan)
	if plans != null and plans.plans.has(pid):
		# Sans remboursement : les murs de la pièce n'ont pas été payés à l'Atelier.
		var argent := buildings.money if buildings != null else 0
		for e in range(int(pc.e), int(pc.e) + int(pc.h)):
			if plans.plans.has(pid):
				plans.erase_rect(pid, pc.r, e)
				# Les murs du bord (sur la ligne de fin du rectangle).
				if plans.plans.has(pid):
					for k in PlanEditor.room_walls(pc.r, e):
						plans.plans[pid].walls.erase(k)
		if buildings != null:
			buildings.money = argent
		if plans.plans.has(pid):
			plans._after_change(pid)
	pieces.erase(id)
	message.emit("%s comblée." % USAGES[pc.u].name)
	changed.emit()
	if vue != null:
		vue.marquer_sale()


## Bilan : places de parking, places à l'abri, volume de stockage (m³).
func bilan() -> Dictionary:
	var out := {"parking": 0, "abri": 0, "stockage": 0, "chantiers": 0, "pieces": 0}
	for id in pieces:
		var pc: Dictionary = pieces[id]
		if float(pc.av) < 1.0:
			out.chantiers += 1
			continue
		out.pieces += 1
		var r: Rect2i = pc.r
		var aire := r.size.x * r.size.y
		match String(pc.u):
			"parking":
				out.parking += places_de("parking", aire, int(pc.h))
			"bunker":
				out.abri += places_de("bunker", aire, int(pc.h))
			"cave", "entrepot":
				out.stockage += roundi(aire * int(pc.h) * (H - 0.4))
	return out


# --- Conduites ----------------------------------------------------------------------------

## Conduite enterrée la plus proche : {"net": "reseaux"/"telecom", "res", "id"} ou {}.
func conduite_pres(p: Vector3, r: float) -> Dictionary:
	var best := {}
	var bd := r
	var sources := []
	if reseaux != null:
		for res in ["eau", "egout", "gaz"]:
			sources.append(["reseaux", res, reseaux.reseau(res)])
	if telecom != null:
		sources.append(["telecom", "fibre", telecom.fibre])
	for s in sources:
		var rb: ReseauBase = s[2]
		for id in rb.troncons:
			var t: Dictionary = rb.troncons[id]
			if not VueSouterraine.TRONCONS.has(String(t.t)):
				continue
			var pts: PackedVector3Array = t.pts
			for i in range(pts.size() - 1):
				var d := ReseauBase.dist_seg(p, pts[i], pts[i + 1])
				if d < bd:
					bd = d
					best = {"net": s[0], "res": s[1], "id": id}
	return best


func _reseau_de(sel: Dictionary) -> ReseauBase:
	if sel.is_empty():
		return null
	if String(sel.net) == "telecom":
		return telecom.fibre
	return reseaux.reseau(String(sel.res))


## Déplace une conduite enterrée de delta (m, en plan), au niveau n : une nouvelle
## est posée (payée, en chantier) ; l'ancienne reste en service jusqu'à la fin.
func deplacer(sel: Dictionary, delta: Vector2, n: int) -> int:
	var rb := _reseau_de(sel)
	if rb == null or not rb.troncons.has(int(sel.id)):
		return -1
	var t: Dictionary = rb.troncons[int(sel.id)]
	var type_id := String(t.t)
	var prof := profondeur_conduite(type_id, n)
	if n <= 1 and t.has("prof"):
		prof = float(t.prof)
	var pts := PackedVector3Array()
	for q in (t.pts as PackedVector3Array):
		var x := q.x + delta.x
		var z := q.z + delta.y
		pts.append(Vector3(x, _sol(x, z, q.y), z))
	var nouveau := -1
	if String(sel.net) == "telecom":
		telecom.profondeur_pose = prof
		nouveau = telecom.poser_cable(type_id, pts)
		telecom.profondeur_pose = NAN
	else:
		var avant := reseaux.profondeur_pose
		reseaux.profondeur_pose = prof
		nouveau = reseaux.poser(type_id, pts)
		reseaux.profondeur_pose = avant
	if nouveau < 0:
		return -1
	deplacements.append({"net": String(sel.net), "res": String(sel.res), "ancien": int(sel.id), "nouveau": nouveau})
	message.emit("Dévoiement lancé : la conduite reste en service jusqu'à la fin des travaux.")
	_verifier_deplacements()
	changed.emit()
	return nouveau


## Les dévoiements finis : l'ancienne conduite est abandonnée (retirée).
func _verifier_deplacements() -> void:
	var reste := []
	for d in deplacements:
		var rb := _reseau_de(d)
		if rb == null or not rb.troncons.has(int(d.nouveau)):
			continue
		if not bool(rb.troncons[int(d.nouveau)].ok):
			reste.append(d)
			continue
		rb.retirer_troncon(int(d.ancien))
		if String(d.net) == "telecom":
			telecom.marquer()
		else:
			reseaux._topo_sale = true
			if reseaux.vue:
				reseaux.vue.refaire_troncon(String(d.res), int(d.ancien))
			reseaux.changed.emit()
	deplacements = reste
	if vue != null:
		vue.marquer_sale()


# --- Tunnels ------------------------------------------------------------------------------

func _on_edges_built(edges: Array) -> void:
	if outil != Outil.TUNNEL or is_nan(RoutePlanner.profondeur_forcee):
		return
	# Voie rejouée pour la carte entre amis : sa profondeur vient du serveur.
	if transport != null and transport._par_reseau:
		return
	appliquer_tunnel(edges, RoutePlanner.profondeur_forcee)


## Les tronçons edges sont un tunnel creusé à prof mètres : profondeur notée, prix
## du tunnel. Aussi appelé par la carte entre amis (serveur, et chez chaque joueur
## qui rejoue la voie : avertir faux, le serveur fait payer).
func appliquer_tunnel(edges: Array, prof: float, avertir := true) -> void:
	var total := 0
	var lt := 0.0
	for eid in edges:
		if not transport.network.edges.has(eid):
			continue
		var e: Dictionary = transport.network.edges[eid]
		e["prof"] = snappedf(prof, 0.1)
		var c := prix_tunnel(String(e.t), e.pts, e.st, prof)
		lt += longueur_tunnel(e.pts, e.st)
		total += c
		if ChantiersVoies.instance != null:
			ChantiersVoies.instance.fixer_cout(eid, c)
		elif buildings != null and not buildings.unlimited_money and avertir:
			buildings.money -= c
	if total > 0 and avertir:
		message.emit("%s : %d m de tunnel à %d m de fond, %s payés au fil des travaux." % [VOIES.get(type_voie, {"name": "Tunnel"}).name,
			roundi(lt), roundi(prof), BuildingSystem.format_money(total)])
	if vue != null:
		vue.marquer_sale()


## Tunnel (ou métro) le plus proche au niveau n : id du tronçon, ou -1.
func tunnel_pres(p: Vector3, n: int, r := 10.0) -> int:
	if transport == null:
		return -1
	var best := -1
	var bd := r
	for eid in transport.edges_near(p, r + 20.0):
		var e: Dictionary = transport.network.edges[eid]
		var metro := float(TransportTypes.get_type(String(e.t)).get("underground", 0.0)) > 0.0
		if not metro and not e.has("prof"):
			continue
		var hit := transport.network.nearest_on_edge(eid, p)
		if float(hit.dist) < bd:
			var q: Vector3 = hit.get("pos", p)
			var fond := _sol(q.x, q.z, q.y) - q.y + 0.6
			if VueSouterraine.visible_au(n, fond):
				bd = float(hit.dist)
				best = eid
	return best


# --- Supprimer ----------------------------------------------------------------------------

func supprimer_a(p: Vector3, n: int) -> bool:
	var pid := piece_a(_cellule(p), n)
	if pid >= 0:
		combler(pid)
		return true
	var c := conduite_pres(p, 6.0)
	if not c.is_empty():
		var rb := _reseau_de(c)
		var t: Dictionary = rb.troncons[int(c.id)]
		var spec: Dictionary = VueSouterraine.TRONCONS.get(String(t.t), {"d": 1.0, "s": 0.5})
		if VueSouterraine.visible_au(n, float(t.get("prof", spec.d)) + float(spec.s) / 2.0):
			if String(c.net) == "telecom":
				telecom.retirer_pres(p)
			else:
				reseaux.retirer(String(c.res), int(c.id))
			if vue != null:
				vue.marquer_sale()
			return true
	var eid := tunnel_pres(p, n)
	if eid >= 0:
		transport.demolish(eid)
		return true
	message.emit("Rien à supprimer ici à ce niveau.")
	return false


# --- Dessin (appelé par la vue) ------------------------------------------------------------

## Pièces en chantier : la fouille (terre) avec la part creusée, en béton une fois
## finie (le plan de l'Atelier prend le relais).
func dessiner(plein: SurfaceTool, verre: SurfaceTool, n: int) -> int:
	var nb := 0
	for id in pieces:
		var pc: Dictionary = pieces[id]
		var r: Rect2i = pc.r
		var bas_n := int(pc.n) + int(pc.h) - 1
		if bas_n < n:
			continue
		var c := r.get_center()
		var y0 := _sol(c.x + 0.5, c.y + 0.5, 0.0)
		var rr := Rect2(Vector2(r.position), Vector2(r.size))
		var col: Color = USAGES[String(pc.u)].col
		var av := float(pc.av)
		nb += 1
		if av >= 1.0 and String(pc.plan) != "":
			# Teinte légère de l'usage, sous les murs de l'Atelier.
			for k in range(maxi(int(pc.n), n), bas_n + 1):
				var b := y0 - k * H
				VueSouterraine._boite_rect(plein, rr.grow(-0.15), b + 0.21, b + 0.26, Color(col, 1.0))
			continue
		# Fouille : de haut en bas, la part creusée suit l'avancement.
		var haut := y0 - (int(pc.n) - 1) * H
		var bas := y0 - bas_n * H
		var creuse := lerpf(haut, bas, clampf(av / 0.45, 0.0, 1.0))
		VueSouterraine._boite_rect(verre, rr, bas, haut, Color(0.55, 0.42, 0.28, 0.32))
		if creuse < haut - 0.05:
			VueSouterraine._boite_rect(plein, rr.grow(-0.1), creuse, creuse + 0.15, Color(0.42, 0.32, 0.22))
		if av > 0.45:
			# Soutènement puis dalles : le béton monte.
			var beton := lerpf(bas, haut, clampf((av - 0.45) / 0.5, 0.0, 1.0))
			VueSouterraine._boite_rect(plein, rr, bas, bas + 0.25, Color(0.66, 0.64, 0.6))
			for side in [Rect2(rr.position, Vector2(rr.size.x, 0.3)), Rect2(Vector2(rr.position.x, rr.end.y - 0.3), Vector2(rr.size.x, 0.3)),
					Rect2(rr.position, Vector2(0.3, rr.size.y)), Rect2(Vector2(rr.end.x - 0.3, rr.position.y), Vector2(0.3, rr.size.y))]:
				VueSouterraine._boite_rect(plein, side, bas, beton, Color(0.7, 0.68, 0.63))
		# Engin de chantier (mini-pelle) au fond de la fouille.
		var e := Vector3(rr.position.x + 1.5, maxf(creuse, bas) + 0.2, rr.position.y + 1.5)
		VueSouterraine._boite_rect(plein, Rect2(e.x - 0.8, e.z - 0.6, 1.6, 1.2), e.y, e.y + 1.0, Color(0.95, 0.72, 0.1))
	return nb


func _dessiner_fantome() -> void:
	if _fantome == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rien := true
	var n := niveau()
	if outil == Outil.PIECE and _survol.is_finite():
		var r := _rect(_a, _cellule(_survol)) if _drag else Rect2i(_cellule(_survol), Vector2i.ONE)
		var ok := not _drag or raison_piece(r, n, hauteur) == ""
		var c := r.get_center()
		var y0 := _sol(c.x + 0.5, c.y + 0.5, _survol.y)
		var col := Color(0.4, 0.95, 0.5, 0.35) if ok else Color(1.0, 0.3, 0.25, 0.4)
		VueSouterraine._boite_rect(st, Rect2(Vector2(r.position), Vector2(r.size)), y0 - (n + hauteur - 1) * H, y0 - (n - 1) * H, col)
		rien = false
	elif outil == Outil.DEPLACER and not _sel.is_empty() and _survol.is_finite():
		var rb := _reseau_de(_sel)
		if rb != null and rb.troncons.has(int(_sel.id)):
			var t: Dictionary = rb.troncons[int(_sel.id)]
			var spec: Dictionary = VueSouterraine.TRONCONS.get(String(t.t), {"s": 0.5})
			var prof := profondeur_conduite(String(t.t), n)
			var dx := _survol.x - _grab.x
			var dz := _survol.z - _grab.z
			var pts: PackedVector3Array = t.pts
			for i in range(pts.size() - 1):
				var a := pts[i] + Vector3(dx, 0, dz)
				var b := pts[i + 1] + Vector3(dx, 0, dz)
				a.y = _sol(a.x, a.z, a.y) - prof
				b.y = _sol(b.x, b.z, b.y) - prof
				VueSouterraine._boite_seg(st, a, b, float(spec.s) * VueSouterraine.LOUPE + 0.3, float(spec.s) * VueSouterraine.LOUPE + 0.3, Color(1, 1, 1, 0.55))
			rien = false
	_fantome.mesh = null if rien else st.commit()


## Fantôme du tunnel en cours de tracé (la voie de surface ne se dessine pas en tunnel).
func _fantome_tunnel() -> void:
	if _fantome == null:
		return
	var pl: Dictionary = transport._plan
	if pl.is_empty() or not pl.has("pts"):
		_fantome.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: PackedVector3Array = pl.pts
	var w := TransportTypes.width_of(type_voie, transport.spec) + 1.5
	var col := Color(0.4, 0.95, 0.5, 0.4) if pl.get("ok", false) else Color(1.0, 0.3, 0.25, 0.45)
	var pas := maxi(1, pts.size() / 120)
	var i := 0
	while i < pts.size() - 1:
		var j := mini(i + pas, pts.size() - 1)
		VueSouterraine._boite_seg(st, pts[i] + Vector3(0, 2.8, 0), pts[j] + Vector3(0, 2.8, 0), w, 6.0, col)
		i = j
	_fantome.mesh = st.commit()
	_aide()


# --- Barre d'outils (dans le panneau de la vue) --------------------------------------------

func construire_barre(parent: Container) -> void:
	_barre = VBoxContainer.new()
	_barre.add_theme_constant_override("separation", 3)
	parent.add_child(_barre)
	# Menus en images : chaque outil est une vignette (coupe du sous-sol) ou une icône.
	var r1 := _ligne("Poser")
	for t in CONDUITES:
		_bouton(r1, "c:" + t, CONDUITES[t].name, CONDUITES[t].tip + " au niveau affiché",
			func() -> void: activer(Outil.CONDUITE, t), String(CONDUITES[t].picto))
	r1.add_child(VSeparator.new())
	for t in VOIES:
		_bouton(r1, "v:" + t, VOIES[t].name, VOIES[t].tip + " (à partir du −3)",
			func() -> void: activer(Outil.TUNNEL, t), String(VOIES[t].picto))
	var r2 := _ligne("Creuser")
	for u in USAGE_ORDRE:
		_bouton(r2, "p:" + u, String(USAGES[u].name).get_slice(" (", 0), "Creuser : %s (glisser un rectangle, sous ce niveau)" % USAGES[u].name,
			func() -> void: activer(Outil.PIECE, u), "sous_" + String(u))
	_haut_btn = ChoixVisuel.new()
	_haut_btn.icone = "souterrain"
	_haut_btn.gradue = 1
	_haut_btn.titre = "Hauteur de la pièce"
	_haut_btn.focus_mode = Control.FOCUS_NONE
	_haut_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for h in NIVEAUX_PIECE_MAX:
		_haut_btn.add_item(niveaux_txt(h + 1))
	_haut_btn.face_image = Vector2(40, 28)
	_haut_btn.select(hauteur - 1)
	_haut_btn.item_selected.connect(func(i: int) -> void:
		hauteur = i + 1
		if outil == Outil.PIECE:
			_aide())
	r2.add_child(_haut_btn)
	r2.add_child(VSeparator.new())
	for a in ATELIER:
		var t: int = a[1]
		_bouton(r2, "a:%d" % t, String(a[0]), "Atelier : " + String(a[2]), func() -> void: activer(Outil.ATELIER, str(t)), "", String(a[3]))
	r2.add_child(VSeparator.new())
	_bouton(r2, "deplacer", "Déplacer", "Déplacer une conduite enterrée (dévoiement)", func() -> void: activer(Outil.DEPLACER), "", "glisser")
	_bouton(r2, "gomme", "Supprimer", "Supprimer une pièce, une conduite ou un tunnel", func() -> void: activer(Outil.GOMME), "", "demolir")
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 13)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(900, 0)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_barre.add_child(_info)
	_bilan = Label.new()
	_bilan.add_theme_font_size_override("font_size", 12)
	_bilan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bilan.modulate = Color(1, 1, 1, 0.75)
	_barre.add_child(_bilan)
	changed.connect(_maj_bilan)
	_maj_bilan()


func _ligne(titre: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = titre
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	l.custom_minimum_size = Vector2(62, 0)
	h.add_child(l)
	_barre.add_child(h)
	return h


## Vignette d'outil : une image (picto, coupe du sous-sol) ou une icône, le nom dessous.
const TUILE := Vector2(70, 60)


func _bouton(parent: Container, cle_: String, texte: String, tip: String, f: Callable, picto := "", icone := "") -> void:
	var b := Button.new()
	b.name = "Outil_" + cle_.replace(":", "_")
	b.text = texte
	b.tooltip_text = tip
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = TUILE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 11)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	if picto != "":
		b.icon = Pictos.get_picto(picto, 60)
		b.add_theme_constant_override("icon_max_width", 60)
	else:
		b.icon = Icones.get_icon(icone if icone != "" else "souterrain", 26)
		b.add_theme_constant_override("icon_max_width", 26)
	UiStyle.style_icon_button(b)
	if picto != "":
		# Une image garde ses couleurs, même enfoncée.
		for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			b.add_theme_color_override(k, Color.WHITE)
	b.pressed.connect(func() -> void:
		if b.button_pressed:
			f.call()
		else:
			desactiver())
	parent.add_child(b)
	_boutons[cle_] = b


func _cle_active() -> String:
	match outil:
		Outil.CONDUITE: return "c:" + type_conduite
		Outil.TUNNEL: return "v:" + type_voie
		Outil.PIECE: return "p:" + usage
		Outil.ATELIER: return "a:%d" % outil_atelier
		Outil.DEPLACER: return "deplacer"
		Outil.GOMME: return "gomme"
	return ""


func _maj_boutons() -> void:
	var k := _cle_active()
	for c in _boutons:
		(_boutons[c] as Button).set_pressed_no_signal(c == k)


func _maj_bilan() -> void:
	if _bilan == null:
		return
	var b := bilan()
	var parts := []
	if int(b.parking) > 0:
		parts.append("%d places de parking" % int(b.parking))
	if int(b.abri) > 0:
		parts.append("%d places à l'abri" % int(b.abri))
	if int(b.stockage) > 0:
		parts.append("%d m³ de stockage" % int(b.stockage))
	if int(b.chantiers) == 1:
		parts.append("1 chantier souterrain")
	elif int(b.chantiers) > 1:
		parts.append("%d chantiers souterrains" % int(b.chantiers))
	_bilan.text = "Sous terre : %s" % "  ·  ".join(parts) if not parts.is_empty() else ""


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var p := {}
	for id in pieces:
		var pc: Dictionary = pieces[id]
		var r: Rect2i = pc.r
		p[str(id)] = {"r": [r.position.x, r.position.y, r.size.x, r.size.y], "n": pc.n, "h": pc.h, "u": pc.u,
			"av": snappedf(float(pc.av), 0.0001), "cout": pc.cout, "plan": pc.plan, "e": pc.e, "sb": pc.sb}
	return {"v": 1, "next": next_id, "pieces": p, "deplacements": deplacements.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	clear()
	next_id = int(d.get("next", 1))
	var p: Dictionary = d.get("pieces", {})
	for k in p:
		var e: Dictionary = p[k]
		var ra: Array = e.get("r", [0, 0, 1, 1])
		var id := int(k)
		pieces[id] = {"r": Rect2i(int(ra[0]), int(ra[1]), int(ra[2]), int(ra[3])), "n": int(e.get("n", 1)), "h": int(e.get("h", 1)),
			"u": String(e.get("u", "cave")) if USAGES.has(String(e.get("u", ""))) else "cave", "av": float(e.get("av", 1.0)),
			"cout": int(e.get("cout", 0)), "plan": String(e.get("plan", "")), "e": int(e.get("e", 0)), "sb": bool(e.get("sb", false))}
		next_id = maxi(next_id, id + 1)
	for x in d.get("deplacements", []):
		var dd: Dictionary = x
		deplacements.append({"net": String(dd.get("net", "reseaux")), "res": String(dd.get("res", "eau")),
			"ancien": int(dd.get("ancien", -1)), "nouveau": int(dd.get("nouveau", -1))})
	# Chantiers en cours : ils reprennent où ils en étaient.
	for id in pieces:
		if float(pieces[id].av) < 1.0:
			_lancer(id)
	if vue != null:
		vue.marquer_sale()
	changed.emit()


func clear() -> void:
	if SuiviChantiers.instance != null:
		for id in pieces:
			SuiviChantiers.instance.annuler(cle(id))
	pieces.clear()
	deplacements.clear()
	next_id = 1
