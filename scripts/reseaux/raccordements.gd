class_name Raccordements
extends Node3D
## Icônes flottantes au-dessus des bâtiments qui n'ont pas un réseau dont ils
## ont besoin : électricité (éclair), eau potable (goutte), égouts (tuyau) et
## internet (antenne). Une icône par réseau manquant, côte à côte.
##
## - Fond rouge : pas raccordé (aucune route desservie, ligne ni conduite à
##   moins de 30 m, plus la demi-taille du bâtiment). Toujours montré, en jeu normal.
## - Fond orange : raccordé, mais coupé (le réseau ne produit pas assez, panne).
##   Seulement dans la vue Réseaux (touche O), pour le réseau de l'onglet ouvert ;
##   dans cette vue, toutes les icônes sont plus grandes, pulsent et passent
##   devant les bâtiments.
## - Époques : un réseau pas encore répandu (Epoques.ATTENDU : électricité en
##   1925, eau et égouts en 1900, internet en 1975) n'est pas demandé. Réseaux
##   non obligatoires (Admin, F10) : aucune icône.
## - Rendu : un seul MultiMesh (un quad par icône) et un shader qui tourne les
##   icônes vers la caméra et garde leur taille à l'écran ; la liste n'est
##   refaite que toutes les secondes, et le MultiMesh seulement si elle change.
## - Option du joueur : Options → Jeu → « Icônes des bâtiments non raccordés »
##   (OptionsJeu.icones_raccordement), aussi dans le panneau O.

## Réseaux suivis, dans l'ordre des colonnes de l'atlas.
## Le nombre de bâtiments non raccordés a changé (fil d'alertes, Mairie).
signal nombre_change(n: int)

const RES := ["elec", "eau", "egout", "telecom"]
const NOMS := {"elec": "Électricité", "eau": "Eau potable", "egout": "Égouts", "telecom": "Internet"}
const NON_RACCORDE := "non_raccorde"
const COUPE := "coupe"
const COULEUR_NON := Color("d62839")
const COULEUR_COUPE := Color("f08c2e")
const CASE := 128

## Pictogrammes blancs (SVG 24 × 24), posés sur un disque de couleur.
const PICTOS := {
	"elec": "<path d=\"M13.5 2 5 13.5h5.5L9 22l9-12.5h-5.6Z\" fill=\"#fff\" stroke=\"#fff\" stroke-width=\".8\" stroke-linejoin=\"round\"/>",
	"eau": "<path d=\"M12 2.5C9 7 6 10.4 6 14.2a6 6 0 0 0 12 0C18 10.4 15 7 12 2.5Z\" fill=\"#fff\"/><path d=\"M9.2 14.5a3 3 0 0 0 2.6 3\" fill=\"none\" stroke-width=\"1.5\" stroke-linecap=\"round\" stroke=\"#000\" stroke-opacity=\".25\"/>",
	"egout": "<path d=\"M3 6h7v4h4v8h-4v-4H3Z\" fill=\"#fff\"/><path d=\"M16 17.5c1.6 1.5 3.4 1.5 5 0\" fill=\"none\" stroke=\"#fff\" stroke-width=\"1.8\" stroke-linecap=\"round\"/><path d=\"M17.5 13.5c-.9 1.3-1.4 2.1-1.4 2.8a1.4 1.4 0 0 0 2.8 0c0-.7-.5-1.5-1.4-2.8Z\" fill=\"#fff\"/>",
	"telecom": "<path d=\"M12 11v11M8.5 22h7\" stroke=\"#fff\" stroke-width=\"2\" stroke-linecap=\"round\"/><circle cx=\"12\" cy=\"10\" r=\"2.2\" fill=\"#fff\"/><path d=\"M7.8 5.8a6 6 0 0 0 0 8.4M16.2 5.8a6 6 0 0 1 0 8.4M4.9 3a10 10 0 0 0 0 14M19.1 3a10 10 0 0 1 0 14\" fill=\"none\" stroke=\"#fff\" stroke-width=\"1.7\" stroke-linecap=\"round\"/>",
}

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, skip_vertex_transform, shadows_disabled%s;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float fort = 0.0;
varying vec2 cellule;
varying float pulse;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(CAMERA_POSITION_WORLD - centre);
	// Taille à peu près constante à l'écran, bornée en mètres.
	float s = clamp(d * 0.032, 2.5, 90.0) * (1.0 + 0.5 * fort);
	float bob = sin(TIME * 2.6 + centre.x * 0.07 + centre.z * 0.05) * 0.08 * s;
	vec3 droite = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 haut = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 p = centre + vec3(0.0, s * 0.6 + bob, 0.0) + droite * (INSTANCE_CUSTOM.z * s * 1.08)
		+ (droite * VERTEX.x + haut * VERTEX.y) * s;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	cellule = INSTANCE_CUSTOM.xy;
	pulse = fort * (0.5 + 0.5 * sin(TIME * 5.0 + centre.x));
}

void fragment() {
	vec4 c = texture(atlas, (cellule + UV) / vec2(4.0, 2.0));
	ALBEDO = c.rgb * (1.0 + 0.35 * pulse);
	ALPHA = c.a;
}
"""

var reseaux: Reseaux
## Réseau téléphone et internet (facultatif, branché par terre_main).
var telecom: Telecom
## Masquées par le joueur ou par le code (tests, mode photo…).
var montrer := true

## bid -> [[res, cause], …] : réseaux qui manquent à chaque bâtiment.
var manques: Dictionary = {}
## Nombre de bâtiments sans au moins un raccordement.
var nb_non_raccordes := 0
## Nombre d'icônes affichées en ce moment.
var nb_icones := 0
## Copie des icônes envoyées au MultiMesh : [position, Color(colonne, ligne, décalage, 0)].
var icones: Array = []

var _mm: MultiMeshInstance3D
var _mat: ShaderMaterial
var _mat_fort: ShaderMaterial
var _fort := false
## Réseau du calque allumé dans la vue O : ses bâtiments coupés ont l'icône orange.
var _calque := ""
var _cle := 0
var _acc := 10.0
var _suivant := -1

static var _atlas: ImageTexture


func _ready() -> void:
	name = "Raccordements"
	_mm = MultiMeshInstance3D.new()
	_mm.name = "Icones"
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	_mm.multimesh = mm
	# Le shader déplace les sommets : pas de découpe par la boîte d'origine.
	_mm.custom_aabb = AABB(Vector3(-1e6, -1e4, -1e6), Vector3(2e6, 2e4, 2e6))
	add_child(_mm)
	_mat = _materiau(false)
	_mat_fort = _materiau(true)
	_mm.material_override = _mat


static func _materiau(fort: bool) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SHADER % (", depth_test_disabled" if fort else "")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("atlas", atlas())
	m.set_shader_parameter("fort", 1.0 if fort else 0.0)
	m.render_priority = 3 if fort else 1
	return m


## Atlas 4 × 2 : une colonne par réseau, rouge (pas raccordé) puis orange (coupé).
static func atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var img := Image.create(CASE * 4, CASE * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		var fond: Color = COULEUR_NON if row == 0 else COULEUR_COUPE
		for col in RES.size():
			var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\" viewBox=\"0 0 32 32\">" \
				+ "<circle cx=\"16\" cy=\"16\" r=\"14.6\" fill=\"#%s\" stroke=\"#fff\" stroke-width=\"2.2\"/>" % fond.to_html(false) \
				+ "<g transform=\"translate(5.2 5.2) scale(.9)\">%s</g>" % PICTOS[RES[col]] + "</svg>"
			var ic := Image.new()
			if ic.load_svg_from_string(svg, float(CASE) / 32.0) != OK:
				continue
			ic.convert(Image.FORMAT_RGBA8)
			img.blit_rect(ic, Rect2i(0, 0, mini(ic.get_width(), CASE), mini(ic.get_height(), CASE)), Vector2i(col * CASE, row * CASE))
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


## Icône seule d'un réseau, pour l'interface (fiche, alertes).
static func icone(res: String, cause := NON_RACCORDE, taille := 18) -> Texture2D:
	var a := atlas().get_image()
	var col := RES.find(res)
	if col < 0:
		return null
	var sub := a.get_region(Rect2i(col * CASE, (0 if cause == NON_RACCORDE else 1) * CASE, CASE, CASE))
	sub.resize(taille, taille, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(sub)


func _process(delta: float) -> void:
	_acc += delta
	var visible_ok := montrer and OptionsJeu.icones_raccordement and not _camera_photo()
	_mm.visible = visible_ok
	var calque := reseaux.vue.calque_actif() if reseaux != null and reseaux.vue != null else ""
	if calque != _calque:
		_calque = calque
		_fort = calque != ""
		_acc = 10.0
	if _acc < 1.0:
		return
	_acc = 0.0
	maj()


## Le mode photo (F8) a sa propre caméra : pas d'icônes sur les photos.
func _camera_photo() -> bool:
	if not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.name == "CameraPhoto"


## Refait la liste des manques et les icônes (appelé toutes les secondes).
func maj() -> void:
	calculer()
	_dessiner()


## Réseaux qui manquent à chaque bâtiment, selon l'époque et les réglages.
func calculer() -> void:
	var avant := nb_non_raccordes
	_calculer()
	if nb_non_raccordes != avant:
		nombre_change.emit(nb_non_raccordes)


func _calculer() -> void:
	manques.clear()
	nb_non_raccordes = 0
	if reseaux == null or reseaux.buildings == null or not ReglagesPartie.actuel.reseaux_obligatoires:
		return
	var b := reseaux.buildings
	for res in ["elec", "eau", "egout"]:
		if not Epoques.attendu(res):
			continue
		var r := reseaux.reseau(res)
		var k: String = Reseaux.CLE[res]
		for bid in r.consos:
			var cause := ""
			if not r.est_raccorde(bid):
				cause = NON_RACCORDE
			elif float(reseaux.etat.get(bid, {}).get(k, 1.0)) < 0.5:
				cause = COUPE
			else:
				continue
			if not b.buildings.has(bid) or b.en_chantier(bid):
				continue
			_ajouter(bid, res, cause)
	if telecom != null and Telecom.necessaire():
		for bid in telecom.service:
			if telecom.qualite(bid) == "rien" and b.buildings.has(bid) and not b.en_chantier(bid):
				# Au bord d'une rue, le cuivre arrive : il manque le central (coupé).
				var relie := telecom.cuivre.est_raccorde(bid) or telecom.fibre.est_raccorde(bid)
				_ajouter(bid, "telecom", COUPE if relie else NON_RACCORDE)
	for bid in manques:
		for m in manques[bid]:
			if m[1] == NON_RACCORDE:
				nb_non_raccordes += 1
				break


func _ajouter(bid: int, res: String, cause: String) -> void:
	if not manques.has(bid):
		manques[bid] = []
	(manques[bid] as Array).append([res, cause])


## Ce qui manque à un bâtiment : [[res, cause], …] (vide : tout va bien).
func manques_de(bid: int) -> Array:
	return manques.get(bid, [])


func est_non_raccorde(bid: int) -> bool:
	for m in manques_de(bid):
		if m[1] == NON_RACCORDE:
			return true
	return false


## Bâtiments sans au moins un raccordement (filtre : Callable(bid) -> bool).
func non_raccordes(filtre := Callable()) -> Array:
	var out := []
	for bid in manques:
		if est_non_raccorde(bid) and (not filtre.is_valid() or bool(filtre.call(bid))):
			out.append(bid)
	out.sort()
	return out


## Le prochain bâtiment non raccordé (chaque appel passe au suivant), -1 s'il n'y en a pas.
func suivant(filtre := Callable()) -> int:
	var l := non_raccordes(filtre)
	if l.is_empty():
		return -1
	_suivant = (_suivant + 1) % l.size()
	return int(l[_suivant])


## Avis pour la Mairie (M) et le fil « À faire » : [] si tout est raccordé.
func alertes(filtre := Callable()) -> Array:
	var l := non_raccordes(filtre)
	if l.is_empty():
		return []
	var par_res := {}
	for bid in l:
		for m in manques_de(bid):
			if m[1] == NON_RACCORDE:
				par_res[m[0]] = int(par_res.get(m[0], 0)) + 1
	var parts := []
	for res in RES:
		if par_res.has(res):
			parts.append("%s : %d" % [String(NOMS[res]).to_lower(), par_res[res]])
	var n := l.size()
	var s := "s" if n > 1 else ""
	var blague: String = ["Les habitants s'éclairent à la bougie et se lavent au seau.",
		"Ils ont emménagé quand même. Optimistes, ces gens-là.",
		"Le plombier passe souvent, mais il ne trouve aucun tuyau."][absi(n) % 3]
	return [{"id": "non_raccordes", "gravite": 2 if n >= 5 else 1, "prio": 1, "theme": "reseaux",
		"titre": "%d bâtiment%s non raccordé%s (%s)" % [n, s, s, ", ".join(parts)],
		"texte": blague,
		"conseil": "Il faut une route, une ligne ou une conduite à moins de 30 m. « Y aller » montre le premier, puis le suivant à chaque clic (icônes rouges au-dessus).",
		"panneau": "non_raccorde"}]


func _dessiner() -> void:
	var mm := _mm.multimesh
	_mm.material_override = _mat_fort if _fort else _mat
	var b := reseaux.buildings if reseaux != null else null
	if b == null or manques.is_empty():
		if mm.instance_count != 0:
			mm.instance_count = 0
		nb_icones = 0
		icones.clear()
		_cle = 0
		return
	# Liste des icônes : en jeu normal, seulement les « pas raccordé ».
	var items := []
	var h := 17
	for bid in manques:
		var l := []
		for m in manques[bid]:
			if m[1] == NON_RACCORDE or (_fort and m[0] == _calque):
				l.append(m)
		if l.is_empty():
			continue
		items.append([bid, l])
		h = hash([h, bid, l])
	h = hash([h, _calque])
	nb_icones = 0
	for it in items:
		nb_icones += (it[1] as Array).size()
	if h == _cle and mm.instance_count == nb_icones:
		return
	_cle = h
	mm.instance_count = nb_icones
	icones.clear()
	var i := 0
	for it in items:
		var bid := int(it[0])
		var l: Array = it[1]
		var bd: Dictionary = b.buildings[bid]
		var p := BuildingSystem.rect_center(b._rect_of(bd))
		p.y = float(bd.get("h", 0.0)) + BuildingCatalog.approx_height(String(bd.t)) + 2.5
		for j in l.size():
			var res := String(l[j][0])
			var cd := Color(float(RES.find(res)), 0.0 if l[j][1] == NON_RACCORDE else 1.0, float(j) - (l.size() - 1) * 0.5, 0.0)
			mm.set_instance_transform(i, Transform3D(Basis(), p))
			mm.set_instance_custom_data(i, cd)
			icones.append([p, cd])
			i += 1


# --- Fiche du bâtiment (groupe « fiche_batiment ») -------------------------------------

## État de chaque réseau d'un bâtiment : [[res, texte, couleur], …].
func etat_reseaux(bid: int) -> Array:
	var out := []
	if reseaux == null:
		return out
	var libre := not ReglagesPartie.actuel.reseaux_obligatoires
	var dem := {}
	if reseaux.buildings != null and reseaux.buildings.buildings.has(bid):
		dem = Reseaux.demande_type(String(reseaux.buildings.buildings[bid].t))
	for res in ["elec", "eau", "egout", "gaz"]:
		var r := reseaux.reseau(res)
		if not r.consos.has(bid) and float(dem.get(res, 0.0)) <= 0.0:
			continue
		var nom: String = NOMS.get(res, "Chauffage (gaz, chaleur)")
		var t := reseaux.taux(bid, res)
		var txt := ""
		var col := UiStyle.GOOD
		if libre:
			txt = "desservi d'office (réseaux non obligatoires, F10)"
		elif not r.est_raccorde(bid):
			if res == "gaz":
				txt = "pas de conduite : chauffage à l'électricité"
				col = UiStyle.TEXT_DIM
			elif not Epoques.attendu(res):
				txt = "pas raccordé (pas encore attendu en %d : %s)" % [Epoques.annee(), {"elec": "bougies et lampes", "eau": "puits et fontaines", "egout": "fosse"}[res]]
				col = UiStyle.TEXT_DIM
			else:
				txt = "pas raccordé, aucune route desservie, ligne ou conduite à moins de 30 m"
				col = COULEUR_NON
		elif t >= 0.95:
			txt = "raccordé, servi à %d %%" % roundi(t * 100.0)
			if res == "egout" and not reseaux.raccorde_egout(bid):
				txt = "raccordé, mais rejeté sans traitement (pollue la rivière)"
				col = COULEUR_COUPE
		elif t >= 0.5:
			txt = "raccordé, rationné : %d %%" % roundi(t * 100.0)
			col = COULEUR_COUPE
		else:
			var pourquoi := "panne en cours" if res == "elec" and reseaux.incidents.coupe(bid) else "pas assez de production sur ce réseau"
			txt = "raccordé mais coupé (%s)" % pourquoi
			col = COULEUR_COUPE if not Epoques.attendu(res) else Color("e63946")
		out.append([res, "%s : %s" % [nom, txt], col])
	if telecom != null and telecom.service.has(bid):
		var q := telecom.qualite(bid)
		var col := UiStyle.GOOD if q == "fibre" or q == "adsl" or q == "mobile" else (COULEUR_COUPE if q == "lent" else COULEUR_NON)
		if q == "rien" and not Epoques.attendu("telecom"):
			col = UiStyle.TEXT_DIM
		out.append(["telecom", "Internet : %s" % telecom.info_of(bid), col])
	return out


## Rubrique « Réseaux » de la fiche du bâtiment : une ligne par réseau, avec son icône.
func remplir_fiche(parent: Control, bid: int, largeur := 300.0) -> int:
	var n := 0
	for e in etat_reseaux(bid):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var ic := TextureRect.new()
		var col: Color = e[2]
		var mauvais := col == COULEUR_NON or col == COULEUR_COUPE or col == Color("e63946")
		ic.texture = icone(String(e[0]), NON_RACCORDE if col == COULEUR_NON or col == Color("e63946") else COUPE, 18) if mauvais \
			else Icones.get_icon({"elec": "reseaux", "eau": "eau", "egout": "reseaux", "gaz": "feu", "telecom": "reseaux"}.get(String(e[0]), "reseaux"), 18, col)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(20, 20)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		var l := Label.new()
		l.text = String(e[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(largeur - 30, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", col)
		row.add_child(l)
		parent.add_child(row)
		n += 1
	if n > 0 and reseaux != null and reseaux.flux != null:
		var lg := Label.new()
		lg.text = "Sur les routes : les flèches montrent le courant, l'eau, les égouts et le gaz qui circulent. Bord vert = tout va bien, orange et lent = saturé, rouge qui clignote = coupé."
		lg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lg.custom_minimum_size = Vector2(largeur, 0)
		lg.add_theme_font_size_override("font_size", 11)
		lg.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		parent.add_child(lg)
	return n
