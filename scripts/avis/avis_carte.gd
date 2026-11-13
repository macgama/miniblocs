class_name AvisCarte
extends MultiMeshInstance3D
## Carte de satisfaction : un disque de couleur au-dessus de chaque logement
## (rouge mécontent, jaune moyen, vert content), d'après le dernier sondage.
## Allumée depuis le panneau Avis (onglet Quartiers) ou le panneau de calques
## commun s'il existe (res://scripts/interface/calques.gd).

const HAUTEUR := 14.0
const RAYON := 5.0

var avis: Avis
var _t := 0.0


func setup(a: Avis) -> void:
	avis = a
	name = "CarteSatisfaction"
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := CylinderMesh.new()
	disc.top_radius = RAYON
	disc.bottom_radius = RAYON
	disc.height = 0.6
	disc.radial_segments = 10
	disc.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	disc.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = disc
	multimesh = mm
	_brancher_calques()


## Panneau de calques commun (fil pollution) : sans dépendance de compilation.
func _brancher_calques() -> void:
	var path := "res://scripts/interface/calques.gd"
	if not ResourceLoader.exists(path):
		return
	var c = load(path)
	if c != null and c.has_method("ajouter"):
		c.call("ajouter", "satisfaction", "Satisfaction", "Habitants", func(on: bool) -> void: set_on(on),
			"rouge : mécontents, jaune : moyen, vert : contents")


func set_on(on: bool) -> void:
	visible = on
	if on:
		refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t >= 3.0:
		_t = 0.0
		refresh()


func refresh() -> void:
	if avis == null or avis.population == null:
		return
	var s := avis.sondage()
	var lg: Dictionary = s.logements
	var mm := multimesh
	mm.instance_count = lg.size()
	var i := 0
	for bid in lg:
		var pos := avis.population.building_pos(int(bid))
		var top := pos.y
		if avis.buildings != null and avis.buildings.buildings.has(int(bid)):
			var b: Dictionary = avis.buildings.buildings[int(bid)]
			top += float(b.get("h", BuildingCatalog.get_type(String(b.t)).get("h", 8.0)))
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(pos.x, top + HAUTEUR * 0.3 + 3.0, pos.z)))
		mm.set_instance_color(i, AvisPanel.couleur(float(lg[bid])))
		i += 1
