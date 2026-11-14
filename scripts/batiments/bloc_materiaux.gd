class_name BlocMateriaux
extends RefCounted
## Matériaux de l'éditeur libre et leurs textures, dessinées par le jeu au
## démarrage (aucun fichier image à fournir) : briques, pierre taillée,
## planches, tuiles, ardoise, crépi, parquet, carrelage, tôle, verre…
##
## Chaque matériau a une couche dans un Texture2DArray (64 px par mètre).
## L'ordre de la liste ne doit jamais changer : les sauvegardes gardent l'indice.
## On peut ajouter des matériaux à la fin.

const PX := 64

## fam : famille affichée dans le panneau.
const LIST := [
	{"name": "Brique", "pat": "brique", "c1": "b8573f", "c2": "d9cfc0", "price": 120, "fam": "murs"},
	{"name": "Pierre", "pat": "pierre_taillee", "c1": "9a9a94", "c2": "7d7d78", "price": 150, "fam": "murs"},
	{"name": "Bois", "pat": "grain", "c1": "8a5a36", "c2": "6b4329", "price": 80, "fam": "bois"},
	{"name": "Planches", "pat": "planches_h", "c1": "c9a27e", "c2": "8a6a4a", "price": 70, "fam": "bois"},
	{"name": "Béton", "pat": "beton", "c1": "b9b6ae", "c2": "9a978f", "price": 100, "fam": "murs"},
	{"name": "Enduit blanc", "pat": "enduit", "c1": "f1ece2", "c2": "dcd5c6", "price": 90, "fam": "murs"},
	{"name": "Enduit jaune", "pat": "enduit", "c1": "f2d491", "c2": "dcbc78", "price": 90, "fam": "murs"},
	{"name": "Tuile", "pat": "tuile", "c1": "b5523b", "c2": "8c3b2a", "price": 110, "fam": "toits"},
	{"name": "Ardoise", "pat": "ardoise", "c1": "4f5560", "c2": "3a3f48", "price": 130, "fam": "toits"},
	{"name": "Métal", "pat": "metal", "c1": "7d8590", "c2": "6a717b", "price": 180, "fam": "metal_verre"},
	{"name": "Verre", "pat": "verre", "c1": "9fd3eb", "c2": "e8f6ff", "price": 200, "fam": "metal_verre", "glass": true},
	{"name": "Herbe", "pat": "herbe", "c1": "6aa84f", "c2": "4f8a3a", "price": 20, "fam": "nature"},
	{"name": "Sable", "pat": "sable", "c1": "e6d59c", "c2": "cdbb82", "price": 20, "fam": "nature"},
	{"name": "Feuillage", "pat": "feuillage", "c1": "3f7d3a", "c2": "2c5e2a", "price": 30, "fam": "nature"},
	# --- Ajouts (deuxième version de l'éditeur) ----------------------------------------
	{"name": "Brique claire", "pat": "brique", "c1": "d9b48f", "c2": "efe6d6", "price": 130, "fam": "murs"},
	{"name": "Brique sombre", "pat": "brique", "c1": "6e3b2e", "c2": "a39d92", "price": 130, "fam": "murs"},
	{"name": "Pierre de taille", "pat": "pierre_taillee", "c1": "e3d9c2", "c2": "c9bea5", "price": 220, "fam": "murs"},
	{"name": "Moellons", "pat": "moellons", "c1": "a59d8c", "c2": "d6cfbf", "price": 140, "fam": "murs"},
	{"name": "Granit", "pat": "granit", "c1": "8f8f8f", "c2": "4f4f4f", "price": 240, "fam": "murs"},
	{"name": "Grès rose", "pat": "pierre_taillee", "c1": "c98a73", "c2": "a8705c", "price": 200, "fam": "murs"},
	{"name": "Marbre", "pat": "marbre", "c1": "f2f0eb", "c2": "a9a9b2", "price": 400, "fam": "murs"},
	{"name": "Pavés", "pat": "paves", "c1": "8e8a82", "c2": "5f5c57", "price": 90, "fam": "sols"},
	{"name": "Parpaing", "pat": "parpaing", "c1": "a9a7a0", "c2": "8e8c86", "price": 60, "fam": "murs"},
	{"name": "Béton brut", "pat": "beton_banche", "c1": "9a978f", "c2": "85827b", "price": 110, "fam": "murs"},
	{"name": "Crépi rose", "pat": "enduit", "c1": "e8b8a8", "c2": "d4a090", "price": 90, "fam": "murs"},
	{"name": "Crépi bleu", "pat": "enduit", "c1": "a9c4d9", "c2": "8eaac0", "price": 90, "fam": "murs"},
	{"name": "Crépi vert", "pat": "enduit", "c1": "b7cfa5", "c2": "9cb68a", "price": 90, "fam": "murs"},
	{"name": "Crépi ocre", "pat": "enduit", "c1": "d9a066", "c2": "c08850", "price": 90, "fam": "murs"},
	{"name": "Colombage", "pat": "colombage", "c1": "f3ead8", "c2": "4a3222", "price": 160, "fam": "murs"},
	{"name": "Torchis", "pat": "torchis", "c1": "cdb48a", "c2": "a88f62", "price": 50, "fam": "murs"},
	{"name": "Terre crue", "pat": "terre", "c1": "b07d4a", "c2": "8f6238", "price": 40, "fam": "murs"},
	{"name": "Rondins", "pat": "rondins", "c1": "8a5a36", "c2": "5a3a22", "price": 100, "fam": "bois"},
	{"name": "Bardage bois", "pat": "planches_v", "c1": "9a744f", "c2": "6b4a33", "price": 90, "fam": "bois"},
	{"name": "Bardage gris", "pat": "planches_h", "c1": "8e9196", "c2": "6a6d72", "price": 90, "fam": "bois"},
	{"name": "Bardage rouge", "pat": "planches_v", "c1": "9b2c2c", "c2": "6e1f1f", "price": 90, "fam": "bois"},
	{"name": "Parquet chêne", "pat": "parquet", "c1": "c79a63", "c2": "a67c4a", "price": 110, "fam": "sols"},
	{"name": "Parquet foncé", "pat": "parquet", "c1": "6b4a33", "c2": "4f3424", "price": 120, "fam": "sols"},
	{"name": "Carrelage blanc", "pat": "carrelage", "c1": "f2f2ee", "c2": "c8c8c2", "price": 100, "fam": "sols"},
	{"name": "Damier", "pat": "damier", "c1": "f2f2ee", "c2": "2a2a2a", "price": 110, "fam": "sols"},
	{"name": "Tomettes", "pat": "tomettes", "c1": "b5523b", "c2": "d9cbb3", "price": 100, "fam": "sols"},
	{"name": "Moquette", "pat": "moquette", "c1": "8e3b46", "c2": "742f39", "price": 60, "fam": "sols"},
	{"name": "Tuile plate", "pat": "tuile_plate", "c1": "9b4a32", "c2": "7a3826", "price": 120, "fam": "toits"},
	{"name": "Tuile vernissée", "pat": "tuile", "c1": "3f7d4f", "c2": "2c5e3a", "price": 160, "fam": "toits"},
	{"name": "Bardeaux", "pat": "tuile_plate", "c1": "7a5a3e", "c2": "5a3f2a", "price": 90, "fam": "toits"},
	{"name": "Chaume", "pat": "chaume", "c1": "b39a5e", "c2": "8a7444", "price": 60, "fam": "toits"},
	{"name": "Tôle ondulée", "pat": "tole", "c1": "9aa3ad", "c2": "7d8590", "price": 70, "fam": "toits"},
	{"name": "Zinc", "pat": "zinc", "c1": "7f8a94", "c2": "5f6a74", "price": 150, "fam": "toits"},
	{"name": "Cuivre", "pat": "cuivre", "c1": "b87333", "c2": "5fae9a", "price": 300, "fam": "metal_verre"},
	{"name": "Or", "pat": "metal", "c1": "d9a520", "c2": "b8891a", "price": 900, "fam": "metal_verre"},
	{"name": "Bambou", "pat": "bambou", "c1": "c8b06a", "c2": "8f7a3e", "price": 50, "fam": "bois"},
	{"name": "Verre fumé", "pat": "verre", "c1": "4a5a66", "c2": "8a9aa6", "price": 220, "fam": "metal_verre", "glass": true},
	{"name": "Vitrail", "pat": "vitrail", "c1": "2a2a2a", "c2": "ffffff", "price": 350, "fam": "metal_verre", "glass": true},
	{"name": "Gravier", "pat": "gravier", "c1": "a8a297", "c2": "77726a", "price": 15, "fam": "nature"},
	{"name": "Terre", "pat": "terre", "c1": "6b4f35", "c2": "57402b", "price": 10, "fam": "nature"},
	{"name": "Neige", "pat": "neige", "c1": "f4f8fb", "c2": "dde7ee", "price": 10, "fam": "nature"},
	{"name": "Plâtre", "pat": "uni", "c1": "f7f5f0", "c2": "ebe7df", "price": 70, "fam": "murs"},
	{"name": "Fer forgé", "pat": "metal", "c1": "2f3236", "c2": "1e2023", "price": 160, "fam": "metal_verre"},
	{"name": "Bois peint blanc", "pat": "planches_h", "c1": "f2f0ea", "c2": "cfccc4", "price": 90, "fam": "bois"},
	# --- Ajouts (troisième version de l'atelier) -----------------------------------------
	{"name": "Brique flamande", "pat": "flamand", "c1": "a9472f", "c2": "d6ccbb", "price": 140, "fam": "murs"},
	{"name": "Brique anglaise", "pat": "anglais", "c1": "9c4632", "c2": "cfc6b6", "price": 140, "fam": "murs"},
	{"name": "Brique joints alignés", "pat": "joints_alignes", "c1": "7a4a3a", "c2": "3a3532", "price": 130, "fam": "murs"},
	{"name": "Brique jaune", "pat": "brique", "c1": "dcc07e", "c2": "efe8d8", "price": 130, "fam": "murs"},
	{"name": "Brique vernissée", "pat": "brique_vernie", "c1": "2f5d8a", "c2": "e8e4da", "price": 220, "fam": "murs"},
	{"name": "Calcaire", "pat": "pierre_taillee", "c1": "ddd3bc", "c2": "c4b99f", "price": 200, "fam": "murs"},
	{"name": "Pierre bleue", "pat": "pierre_taillee", "c1": "5f6872", "c2": "4a525b", "price": 230, "fam": "murs"},
	{"name": "Meulière", "pat": "meuliere", "c1": "c79a5e", "c2": "e9dfc8", "price": 170, "fam": "murs"},
	{"name": "Opus incertum", "pat": "opus", "c1": "b3a68f", "c2": "e0d8c6", "price": 150, "fam": "murs"},
	{"name": "Travertin", "pat": "travertin", "c1": "e6d8bb", "c2": "c8b48e", "price": 260, "fam": "murs"},
	{"name": "Basalte", "pat": "granit", "c1": "3d3f42", "c2": "1f2022", "price": 240, "fam": "murs"},
	{"name": "Pisé", "pat": "pise", "c1": "b98d5e", "c2": "9c7348", "price": 60, "fam": "murs"},
	{"name": "Béton blanc", "pat": "beton", "c1": "e8e6e0", "c2": "cfccc4", "price": 120, "fam": "murs"},
	{"name": "Crépi terracotta", "pat": "enduit", "c1": "c3653f", "c2": "a8522f", "price": 90, "fam": "murs"},
	{"name": "Crépi gris", "pat": "enduit", "c1": "aaa9a3", "c2": "93928c", "price": 90, "fam": "murs"},
	{"name": "Crépi lavande", "pat": "enduit", "c1": "b9a9cf", "c2": "a090b8", "price": 90, "fam": "murs"},
	{"name": "Enduit à la chaux", "pat": "chaux", "c1": "f3ecdc", "c2": "ddd2bb", "price": 100, "fam": "murs"},
	{"name": "Stuc vénitien", "pat": "marbre", "c1": "e9d3b8", "c2": "c9a888", "price": 300, "fam": "murs"},
	{"name": "Zellige", "pat": "zellige", "c1": "2c7a6a", "c2": "e8e4da", "price": 260, "fam": "murs"},
	{"name": "Bois brûlé", "pat": "bois_brule", "c1": "2a2624", "c2": "15120f", "price": 120, "fam": "bois"},
	{"name": "Mélèze", "pat": "planches_v", "c1": "d3a46d", "c2": "a97c4c", "price": 100, "fam": "bois"},
	{"name": "Bardage vert", "pat": "planches_v", "c1": "4c6e51", "c2": "36513b", "price": 90, "fam": "bois"},
	{"name": "Bardage bleu", "pat": "planches_h", "c1": "44627f", "c2": "30485f", "price": 90, "fam": "bois"},
	{"name": "Bois exotique", "pat": "planches_h", "c1": "7c3b24", "c2": "5a2a18", "price": 140, "fam": "bois"},
	{"name": "Contreplaqué", "pat": "contreplaque", "c1": "d4b07a", "c2": "b38e58", "price": 60, "fam": "bois"},
	{"name": "Rotin", "pat": "vannerie", "c1": "c9a66b", "c2": "8f6e3c", "price": 80, "fam": "bois"},
	{"name": "Bardeaux de cèdre", "pat": "bardeaux", "c1": "a8683e", "c2": "7a4a2a", "price": 120, "fam": "toits"},
	{"name": "Lauzes", "pat": "lauze", "c1": "8a8780", "c2": "5e5b55", "price": 180, "fam": "toits"},
	{"name": "Tuile canal", "pat": "tuile_canal", "c1": "c46a45", "c2": "93452c", "price": 120, "fam": "toits"},
	{"name": "Ardoise en écailles", "pat": "ecailles", "c1": "535a66", "c2": "353a42", "price": 160, "fam": "toits"},
	{"name": "Zinc joints debout", "pat": "joints_debout", "c1": "8a949c", "c2": "6c767e", "price": 170, "fam": "toits"},
	{"name": "Tuile noire", "pat": "tuile", "c1": "34363b", "c2": "1f2024", "price": 150, "fam": "toits"},
	{"name": "Tuile bleue", "pat": "tuile", "c1": "3b5c8c", "c2": "2a4268", "price": 160, "fam": "toits"},
	{"name": "Fibrociment", "pat": "fibrociment", "c1": "a5a7a2", "c2": "8b8d88", "price": 60, "fam": "toits"},
	{"name": "Bac acier", "pat": "bac_acier", "c1": "4a4f55", "c2": "363a3f", "price": 90, "fam": "toits"},
	{"name": "Toit végétal", "pat": "vegetal", "c1": "7d9a4a", "c2": "b3574a", "price": 150, "fam": "toits"},
	{"name": "Terrazzo", "pat": "terrazzo", "c1": "e7e2d8", "c2": "8a7f72", "price": 180, "fam": "sols"},
	{"name": "Carreaux de ciment", "pat": "carreaux_ciment", "c1": "e9e3d6", "c2": "2f5d6e", "price": 170, "fam": "sols"},
	{"name": "Mosaïque", "pat": "mosaique", "c1": "3a8fc2", "c2": "e8f2f7", "price": 200, "fam": "sols"},
	{"name": "Parquet en chevrons", "pat": "chevrons", "c1": "b98a55", "c2": "8f6436", "price": 160, "fam": "sols"},
	{"name": "Dalles de pierre", "pat": "dalles", "c1": "b9b2a4", "c2": "8d877b", "price": 140, "fam": "sols"},
	{"name": "Pavés autobloquants", "pat": "autobloquant", "c1": "9a8f86", "c2": "6c645e", "price": 70, "fam": "sols"},
	{"name": "Enrobé", "pat": "enrobe", "c1": "3c3d40", "c2": "55565a", "price": 40, "fam": "sols"},
	{"name": "Tatami", "pat": "tatami", "c1": "c9c28a", "c2": "5a6a3a", "price": 120, "fam": "sols"},
	{"name": "Sol souple", "pat": "uni", "c1": "6b8fa8", "c2": "5f839c", "price": 60, "fam": "sols"},
	{"name": "Moquette grise", "pat": "moquette", "c1": "7b8088", "c2": "6a6f77", "price": 60, "fam": "sols"},
	{"name": "Acier Corten", "pat": "corten", "c1": "8f4a26", "c2": "5e2e16", "price": 260, "fam": "metal_verre"},
	{"name": "Aluminium", "pat": "panneaux", "c1": "c2c7cc", "c2": "9aa0a6", "price": 200, "fam": "metal_verre"},
	{"name": "Laiton", "pat": "metal", "c1": "c9a24a", "c2": "a8862f", "price": 400, "fam": "metal_verre"},
	{"name": "Pavés de verre", "pat": "pave_verre", "c1": "b8dbe8", "c2": "eef8fc", "price": 250, "fam": "metal_verre", "glass": true},
	{"name": "Verre dépoli", "pat": "verre_depoli", "c1": "e6eef2", "c2": "f8fbfc", "price": 230, "fam": "metal_verre", "glass": true},
	{"name": "Eau", "pat": "eau", "c1": "2f7fb0", "c2": "8fd0ea", "price": 30, "fam": "nature", "glass": true},
	{"name": "Glace", "pat": "verre", "c1": "cfe9f5", "c2": "f4fbff", "price": 30, "fam": "nature", "glass": true},
	{"name": "Roche", "pat": "moellons", "c1": "7d746a", "c2": "5a534b", "price": 60, "fam": "nature"},
	{"name": "Toile blanche", "pat": "toile", "c1": "f1eee6", "c2": "d8d3c6", "price": 40, "fam": "decor"},
	{"name": "Toile rayée", "pat": "rayures", "c1": "c8463d", "c2": "f1eee6", "price": 50, "fam": "decor"},
	{"name": "Feutre", "pat": "moquette", "c1": "4a5d3f", "c2": "3e4f35", "price": 50, "fam": "decor"},
	{"name": "Cuir", "pat": "cuir", "c1": "7a4a2c", "c2": "5e3820", "price": 120, "fam": "decor"},
]

const FAMILIES := [
	{"id": "", "name": "Tous les matériaux"},
	{"id": "murs", "name": "Murs"},
	{"id": "toits", "name": "Toits"},
	{"id": "sols", "name": "Sols"},
	{"id": "bois", "name": "Bois"},
	{"id": "metal_verre", "name": "Métal et verre"},
	{"id": "nature", "name": "Nature"},
	{"id": "decor", "name": "Tissus et divers"},
]

## Teintes : 0 = couleur naturelle du matériau.
const TINTS := [
	Color(1, 1, 1), Color("f2f2f2"), Color("b0b0b0"), Color("5a5a5a"),
	Color("d94a3d"), Color("e88a3a"), Color("f2d04a"), Color("7cbf5a"),
	Color("3f8f6a"), Color("4aa3d9"), Color("3a5fbf"), Color("8a5ab8"),
	Color("e88ab0"), Color("8a5a36"), Color("2a2a2a"), Color("f5e6c8"),
]
const TINT_NAMES := ["Naturelle", "Blanc", "Gris", "Anthracite", "Rouge", "Orange", "Jaune", "Vert clair",
	"Vert sapin", "Bleu ciel", "Bleu roi", "Violet", "Rose", "Brun", "Noir", "Crème"]

## Couche 0 du tableau de textures : blanc uni (portes, cadres peints…).
const PLAIN := 0

static var _array: Texture2DArray
static var _images: Array[Image] = []
static var _solid: ShaderMaterial
static var _glass: ShaderMaterial
static var _ghost: ShaderMaterial

const SHADER := """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;
uniform sampler2DArray tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
	vec4 c = texture(tex, vec3(UV, UV2.x));
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 0.88;
}
"""

const SHADER_GLASS := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform sampler2DArray tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float alpha_mul = 1.0;
void fragment() {
	vec4 c = texture(tex, vec3(UV, UV2.x));
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a * alpha_mul;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
}
"""


static func count() -> int:
	return LIST.size()


## Indice d'un matériau d'après son nom (−1 s'il n'existe pas).
static func index_of(name: String) -> int:
	for i in LIST.size():
		if String(LIST[i].name) == name:
			return i
	return -1


static func is_glass(m: int) -> bool:
	return bool(LIST[clampi(m, 0, LIST.size() - 1)].get("glass", false))


## Couche de texture d'un matériau (la couche 0 est le blanc uni).
static func layer(m: int) -> int:
	return clampi(m, 0, LIST.size() - 1) + 1


## Couleur moyenne d'un matériau (aperçus, créations sans texture).
static func color(m: int) -> Color:
	return Color(String(LIST[clampi(m, 0, LIST.size() - 1)].c1))


static func tint_color(t: int) -> Color:
	return TINTS[clampi(t, 0, TINTS.size() - 1)]


static func texture_array() -> Texture2DArray:
	if _array == null:
		_build()
	return _array


## Image d'un matériau (vignette du panneau).
static func image(m: int) -> Image:
	if _array == null:
		_build()
	return _images[layer(m)]


static func solid_material() -> ShaderMaterial:
	if _solid == null:
		var sh := Shader.new()
		sh.code = SHADER
		_solid = ShaderMaterial.new()
		_solid.shader = sh
		_solid.set_shader_parameter("tex", texture_array())
	return _solid


static func glass_material() -> ShaderMaterial:
	if _glass == null:
		var sh := Shader.new()
		sh.code = SHADER_GLASS
		_glass = ShaderMaterial.new()
		_glass.shader = sh
		_glass.set_shader_parameter("tex", texture_array())
	return _glass


## Matériau translucide du fantôme de pose.
static func ghost_material() -> ShaderMaterial:
	if _ghost == null:
		var sh := Shader.new()
		sh.code = SHADER_GLASS
		_ghost = ShaderMaterial.new()
		_ghost.shader = sh
		_ghost.set_shader_parameter("tex", texture_array())
		_ghost.set_shader_parameter("alpha_mul", 0.6)
	return _ghost


static func _build() -> void:
	_images.clear()
	var plain := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	plain.fill(Color.WHITE)
	_images.append(plain)
	for i in LIST.size():
		_images.append(_draw(LIST[i], i))
	for img in _images:
		img.generate_mipmaps()
	_array = Texture2DArray.new()
	_array.create_from_images(_images)


# --- Dessin des motifs -----------------------------------------------------------------

static var _noise: FastNoiseLite


static func _n(x: float, y: float, freq: float, seed_off: int) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = seed_off
	_noise.frequency = freq
	# Bruit répété tous les 64 px : on mélange quatre lectures décalées.
	var u := x / PX
	var v := y / PX
	var a := _noise.get_noise_2d(x, y)
	var b := _noise.get_noise_2d(x - PX, y)
	var c := _noise.get_noise_2d(x, y - PX)
	var d := _noise.get_noise_2d(x - PX, y - PX)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


static func _h(x: int, y: int, s: int) -> float:
	var v := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float(v % 10000) / 10000.0


static func _draw(m: Dictionary, idx: int) -> Image:
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var c1 := Color(String(m.c1))
	var c2 := Color(String(m.c2))
	var pat: String = m.pat
	var s := idx * 17 + 3
	for y in PX:
		for x in PX:
			img.set_pixel(x, y, _pixel(pat, x, y, c1, c2, s))
	return img


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


## Rangées décalées (briques, pierres) : renvoie [ligne, colonne, joint?].
static func _bond(x: int, y: int, bw: int, bh: int, joint: int) -> Array:
	var row := y / bh
	var xx := x + (bw / 2 if row % 2 == 1 else 0)
	var col := xx / bw
	var j := (y % bh) < joint or (xx % bw) < joint
	return [row, col, j]


static func _pixel(pat: String, x: int, y: int, c1: Color, c2: Color, s: int) -> Color:
	var fx := float(x)
	var fy := float(y)
	match pat:
		"uni":
			return _shade(c1, 1.0 + _n(fx, fy, 0.08, s) * 0.03)
		"enduit":
			return _shade(c1, 1.0 + _n(fx, fy, 0.25, s) * 0.06 + (_h(x, y, s) - 0.5) * 0.06)
		"brique", "parpaing", "pierre_taillee":
			var bw := 21 if pat == "brique" else 32
			var bh := 8 if pat == "brique" else (16 if pat == "parpaing" else 16)
			if pat == "brique":
				bw = 16
			var b := _bond(x, y, bw, bh, 2 if pat != "brique" else 1)
			if b[2]:
				return _shade(c2, 1.0 + _n(fx, fy, 0.3, s) * 0.05)
			var v := 0.88 + _h(b[0], b[1], s) * 0.22
			return _shade(c1, v + _n(fx, fy, 0.2, s + 1) * 0.06)
		"moellons", "paves":
			var cell := 16 if pat == "paves" else 21
			var best := 1e9
			var second := 1e9
			var bid := Vector2i.ZERO
			var cx := x / cell
			var cy := y / cell
			var nper := PX / cell + (0 if PX % cell == 0 else 1)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := cx + ox
					var gy := cy + oy
					var wx := posmod(gx, nper)
					var wy := posmod(gy, nper)
					var j := 0.5 if pat == "paves" else 0.85
					var px := (gx + 0.5 + (_h(wx, wy, s) - 0.5) * j) * cell
					var py := (gy + 0.5 + (_h(wx, wy, s + 9) - 0.5) * j) * cell
					var dd := Vector2(px - fx, py - fy).length()
					if dd < best:
						second = best
						best = dd
						bid = Vector2i(wx, wy)
					elif dd < second:
						second = dd
			if second - best < 2.2:
				return _shade(c2, 1.0 + _n(fx, fy, 0.3, s) * 0.05)
			return _shade(c1, 0.82 + _h(bid.x, bid.y, s + 3) * 0.3 + _n(fx, fy, 0.25, s) * 0.05)
		"granit":
			var r := _h(x, y, s)
			var base := _shade(c1, 1.0 + _n(fx, fy, 0.15, s) * 0.08)
			if r > 0.86:
				return c2
			if r < 0.06:
				return _shade(c1, 1.25)
			return base
		"marbre":
			var vein := sin((fx + fy * 0.6) * 0.12 + _n(fx, fy, 0.05, s) * 6.0)
			var t := clampf(pow(absf(vein), 12.0), 0.0, 1.0)
			return c1.lerp(c2, t * 0.8)
		"beton", "beton_banche":
			var c := _shade(c1, 1.0 + _n(fx, fy, 0.2, s) * 0.06 + (_h(x, y, s) - 0.5) * 0.05)
			if pat == "beton_banche":
				if y % 32 == 0 or x % 64 == 0:
					return _shade(c1, 0.85)
				if (x % 32 == 16) and (y % 32 == 16):
					return c2.darkened(0.3)
			elif _h(x, y, s + 5) > 0.985:
				return c2.darkened(0.2)
			return c
		"grain", "planches_h", "planches_v", "parquet", "bois":
			var along := fx if pat != "planches_v" else fy
			var across := fy if pat != "planches_v" else fx
			var bh := 64.0
			if pat == "planches_h" or pat == "planches_v":
				bh = 64.0 / 6.0
			elif pat == "parquet":
				bh = 8.0
			var board := int(across / bh)
			var off := _h(board, 0, s) * PX
			var grain := sin((along + off) * 0.05 + across * 0.9 + _n(along, across * 3.0, 0.05, s + board) * 4.0)
			var c := _shade(c1, 0.92 + grain * 0.06 + _h(board, 1, s) * 0.1)
			var inb := fmod(across, bh)
			if bh < 64.0 and inb < 1.0:
				return _shade(c2, 0.8)
			if pat == "planches_h" and inb > bh - 2.0:
				return _shade(c1, 0.8)
			if pat == "parquet":
				var seg := int((along + off) / 32.0)
				if fmod(along + off, 32.0) < 1.0:
					return _shade(c2, 0.85)
				c = _shade(c, 0.95 + _h(board, seg, s) * 0.1)
			return c
		"rondins":
			var lh := 16.0
			var t := fmod(fy, lh) / lh
			var round := sin(t * PI)
			var c := _shade(c1, 0.55 + round * 0.55 + _n(fx * 0.3, fy * 2.0, 0.1, s) * 0.06)
			if t < 0.06 or t > 0.94:
				return _shade(c2, 0.7)
			return c
		"tuile":
			var rh := 10.7
			var cw := 10.7
			var row := int(fy / rh)
			var t := fmod(fy, rh) / rh
			var xx := fx + (cw / 2.0 if row % 2 == 1 else 0.0)
			var u := fmod(xx, cw) / cw
			var arc := sin(u * PI)
			var c := _shade(c1, 0.72 + arc * 0.38 + _h(row, int(xx / cw), s) * 0.08)
			if t > 0.85:
				return _shade(c2, 0.7)
			return c
		"tuile_plate", "ardoise":
			var rh := 8.0 if pat == "tuile_plate" else 10.7
			var cw := 12.8 if pat == "tuile_plate" else 16.0
			var row := int(fy / rh)
			var xx := fx + (cw / 2.0 if row % 2 == 1 else 0.0)
			var col := int(xx / cw)
			var t := fmod(fy, rh) / rh
			if fmod(xx, cw) < 1.0 or t > 0.88:
				return _shade(c2, 0.75)
			return _shade(c1, 0.85 + _h(row, col % 5, s) * 0.25 + t * 0.06)
		"enduit_lisse":
			return c1
		"metal":
			return _shade(c1, 0.93 + _n(fx * 0.2, fy * 4.0, 0.2, s) * 0.08 + sin(fy * 0.3) * 0.02)
		"tole":
			return _shade(c1, 0.8 + sin(fx / 64.0 * TAU * 8.0) * 0.18)
		"zinc":
			if x % 16 == 0 or x % 16 == 1:
				return _shade(c1, 1.25)
			return _shade(c1, 0.95 + _n(fx, fy, 0.1, s) * 0.05)
		"cuivre":
			var t := clampf(0.5 + _n(fx, fy, 0.08, s) * 1.2, 0.0, 1.0)
			return c1.lerp(c2, t)
		"verre":
			var streak := 0.25 + 0.15 * clampf(sin((fx + fy) * 0.12) * 2.0 - 1.0, 0.0, 1.0)
			var g := c1.lerp(c2, streak)
			g.a = 0.38 + streak * 0.3
			return g
		"vitrail":
			var cell := 16
			var col := Color.from_hsv(_h(x / cell, y / cell, s), 0.7, 0.9)
			if x % cell < 2 or y % cell < 2:
				return Color(0.1, 0.1, 0.1, 0.95)
			col.a = 0.75
			return col
		"herbe":
			var c := _shade(c1, 1.0 + _n(fx, fy, 0.15, s) * 0.12)
			if _h(x, y, s) > 0.82:
				return _shade(c2, 0.95)
			return c
		"sable", "neige", "moquette", "terre":
			var amp := 0.1 if pat != "neige" else 0.04
			return _shade(c1, 1.0 + _n(fx, fy, 0.2, s) * amp + (_h(x, y, s) - 0.5) * amp)
		"gravier":
			var r := _h(x / 3, y / 3, s)
			return _shade(c1.lerp(c2, r), 0.85 + _h(x, y, s + 1) * 0.3)
		"feuillage":
			var v := _n(fx, fy, 0.2, s)
			if v < -0.25:
				return _shade(c2, 0.8)
			return _shade(c1, 1.0 + v * 0.25)
		"chaume":
			return _shade(c1, 0.8 + _n(fx * 4.0, fy * 0.3, 0.2, s) * 0.25 + _h(x, y / 4, s) * 0.12)
		"torchis":
			var c := _shade(c1, 1.0 + _n(fx, fy, 0.18, s) * 0.08)
			if _h(x, y, s) > 0.93:
				return _shade(c2, 1.1)
			return c
		"bambou":
			if x % 10 == 0:
				return _shade(c2, 0.8)
			if (y + (x / 10) * 7) % 21 == 0:
				return c2
			return _shade(c1, 0.85 + sin(float(x % 10) / 10.0 * PI) * 0.25)
		"carrelage", "tomettes":
			var cell := 16 if pat == "carrelage" else 21
			if x % cell == 0 or y % cell == 0:
				return c2
			return _shade(c1, 0.95 + _h(x / cell, y / cell, s) * 0.08)
		"damier":
			var a := ((x / 16) + (y / 16)) % 2 == 0
			return _shade(c1 if a else c2, 1.0 + _n(fx, fy, 0.3, s) * 0.03)
		"flamand", "anglais", "joints_alignes":
			# Appareils : boutisses (8 px) et panneresses (16 px), joints de 1 px.
			var row := y / 8
			var bw := 16
			var off := 0
			if pat == "flamand":
				off = 6 if row % 2 == 1 else 0
				var xx := posmod(x + off, 24)
				var j := (y % 8) < 1 or xx == 0 or xx == 16
				if j:
					return _shade(c2, 1.0 + _n(fx, fy, 0.3, s) * 0.05)
				var hdr := xx >= 16
				return _shade(c1, (0.8 if hdr else 0.95) + _h(row, (x + off) / 24 * 2 + int(hdr), s) * 0.2)
			if pat == "anglais":
				bw = 8 if row % 2 == 1 else 16
				off = 4 if row % 2 == 1 else 0
			var xx2 := x + off
			if (y % 8) < 1 or (xx2 % bw) < 1:
				return _shade(c2, 1.0 + _n(fx, fy, 0.3, s) * 0.05)
			var v2 := 0.86 + _h(row, xx2 / bw, s) * 0.24
			if pat == "anglais" and row % 2 == 1:
				v2 *= 0.88
			return _shade(c1, v2 + _n(fx, fy, 0.2, s + 1) * 0.05)
		"brique_vernie":
			var bv := _bond(x, y, 16, 8, 1)
			if bv[2]:
				return c2
			var g := 0.85 + _h(bv[0], bv[1], s) * 0.3
			var hl := 0.15 if (y % 8) == 2 else 0.0
			return _shade(c1, g + hl)
		"meuliere":
			var mv := _n(fx, fy, 0.12, s)
			if absf(mv) < 0.04:
				return _shade(c2, 0.95)
			var c := _shade(c1, 0.9 + mv * 0.3 + (_h(x, y, s) - 0.5) * 0.12)
			if _h(x / 2, y / 2, s + 4) > 0.9:
				return _shade(c, 0.7)
			return c
		"opus":
			# Pierres irrégulières : cellules de Voronoï plus grandes et joints larges.
			return _pixel("moellons", x, y, c1, c2, s + 7)
		"travertin":
			var band := sin(fy * 0.35 + _n(fx, fy, 0.03, s) * 5.0)
			var c := _shade(c1, 0.95 + band * 0.04 + _n(fx, fy, 0.2, s) * 0.04)
			if _h(x, y / 2, s) > 0.93:
				return _shade(c2, 0.9)
			if y % 32 == 0 or (x + (y / 32) * 21) % 64 == 0:
				return _shade(c1, 0.8)
			return c
		"pise":
			var layer_h := 10.7
			var t := fmod(fy, layer_h) / layer_h
			var c := _shade(c1.lerp(c2, _h(int(fy / layer_h), 0, s) * 0.6), 0.95 + _n(fx, fy, 0.2, s) * 0.08)
			if t < 0.08:
				return _shade(c, 0.85)
			return c
		"chaux":
			var c := _shade(c1, 1.0 + _n(fx * 0.5, fy * 2.0, 0.1, s) * 0.07)
			if _n(fx, fy, 0.05, s + 2) > 0.35:
				return c.lerp(c2, 0.4)
			return c
		"zellige":
			var cell := 8
			if x % cell == 0 or y % cell == 0:
				return c2
			var hv := _h(x / cell, y / cell, s)
			var c := _shade(c1, 0.75 + hv * 0.45)
			if (x % cell) == 2 and (y % cell) == 2:
				return _shade(c, 1.4)
			return c
		"bois_brule":
			var row := int(fy / 10.67)
			var cr := _n(fx * 0.6, fy * 0.6, 0.25, s + row)
			if fmod(fy, 10.67) < 1.0:
				return c2
			if absf(cr) < 0.05:
				return _shade(c1, 1.6)
			return _shade(c1, 0.85 + _h(x / 3, y / 3, s) * 0.3)
		"contreplaque":
			var gr := sin(fx * 0.05 + _n(fx, fy * 0.2, 0.04, s) * 9.0)
			if x % 64 == 0 or y % 64 == 0:
				return _shade(c2, 0.8)
			return _shade(c1, 0.95 + gr * 0.06)
		"vannerie":
			var cx := x / 8
			var cy := y / 8
			var horiz := (cx + cy) % 2 == 0
			var t := float((y if horiz else x) % 8) / 8.0
			var c := _shade(c1, 0.75 + sin(t * PI) * 0.35)
			if (x % 8 == 0 and not horiz) or (y % 8 == 0 and horiz):
				return _shade(c2, 0.8)
			return c
		"bardeaux":
			var rh := 12.8
			var row := int(fy / rh)
			var cw := 9.0 + _h(row, 0, s) * 4.0
			var xx := fx + _h(row, 1, s) * 20.0
			var col := int(xx / cw)
			var t := fmod(fy, rh) / rh
			if fmod(xx, cw) < 1.0 or t > 0.9:
				return _shade(c2, 0.7)
			return _shade(c1, 0.8 + _h(row, col, s) * 0.3 + t * 0.08)
		"lauze":
			var row := int(fy / 12.8)
			var xx := fx + float(row % 3) * 9.0
			var cw := 14.0 + _h(row, int(xx / 18.0), s) * 8.0
			var col := int(xx / cw)
			var t := fmod(fy, 12.8) / 12.8
			if fmod(xx, cw) < 1.5 or t > 0.86:
				return _shade(c2, 0.75)
			return _shade(c1, 0.8 + _h(row, col, s + 2) * 0.3 + _n(fx, fy, 0.3, s) * 0.06)
		"tuile_canal":
			var cw := 12.8
			var row := int(fy / 16.0)
			var u := fmod(fx, cw) / cw
			var arc := sin(u * PI)
			var chan := int(fx / cw) % 2 == 0
			var c := _shade(c1, (0.75 if chan else 0.6) + arc * 0.4 + _h(row, int(fx / cw), s) * 0.12)
			if fmod(fy, 16.0) > 14.0 and chan:
				return _shade(c2, 0.7)
			return c
		"ecailles":
			var rh := 8.0
			var cw := 10.67
			var row := int(fy / rh)
			var xx := fx + (cw / 2.0 if row % 2 == 1 else 0.0)
			var u := fmod(xx, cw) / cw - 0.5
			var t := fmod(fy, rh) / rh
			var edge := 1.0 - sqrt(maxf(0.0, 1.0 - 4.0 * u * u))
			if absf(t - (1.0 - edge * 0.9)) < 0.12:
				return _shade(c2, 0.7)
			return _shade(c1, 0.85 + _h(row, int(xx / cw), s) * 0.25)
		"joints_debout":
			var xm := x % 21
			if xm == 0:
				return _shade(c1, 1.3)
			if xm == 1:
				return _shade(c1, 0.75)
			return _shade(c1, 0.95 + _n(fx, fy, 0.08, s) * 0.04)
		"fibrociment":
			return _shade(c1, 0.82 + sin(fx / 64.0 * TAU * 4.0) * 0.16 + _n(fx, fy, 0.2, s) * 0.04)
		"bac_acier":
			var xm := x % 16
			if xm < 4:
				return _shade(c1, 1.2 if xm < 2 else 0.8)
			return _shade(c1, 0.95)
		"vegetal":
			var v := _n(fx, fy, 0.25, s)
			if _h(x / 2, y / 2, s) > 0.93:
				return c2
			if _h(x / 2, y / 2, s + 1) > 0.95:
				return Color("e9d36a")
			return _shade(c1, 0.85 + v * 0.3)
		"terrazzo":
			var r := _h(x / 2, y / 2, s)
			if r > 0.9:
				return _shade(c2, 0.8 + _h(x, y, s) * 0.4)
			if r > 0.84:
				return Color("c9a27e").lerp(c1, 0.3)
			if r < 0.04:
				return _shade(c2, 0.55)
			return _shade(c1, 1.0 + _n(fx, fy, 0.2, s) * 0.03)
		"carreaux_ciment":
			var cell := 32
			if x % cell == 0 or y % cell == 0:
				return _shade(c1, 0.85)
			var u := float(x % cell) / cell - 0.5
			var v := float(y % cell) / cell - 0.5
			var d := absf(u) + absf(v)
			var ring := sqrt(u * u + v * v)
			if d < 0.18 or (ring > 0.34 and ring < 0.42) or (absf(absf(u) - absf(v)) < 0.03 and d < 0.5):
				return c2
			return c1
		"mosaique":
			var cell := 5
			if x % cell == 0 or y % cell == 0:
				return c2
			var hv := _h(x / cell, y / cell, s)
			return _shade(c1.lerp(c2, hv * 0.3), 0.8 + hv * 0.35)
		"chevrons":
			var bw := 8
			var col := x / bw
			var yy := y + (x % bw) * (1 if col % 2 == 0 else -1) + (col % 2) * 8
			var plank := posmod(yy, 32)
			var id := int(floor(float(yy) / 32.0))
			if plank < 1 or x % bw == 0:
				return _shade(c2, 0.85)
			return _shade(c1, 0.88 + _h(col, id, s) * 0.2 + sin(float(plank) * 0.4) * 0.02)
		"dalles":
			var b := _bond(x, y, 32, 21, 1)
			if b[2]:
				return _shade(c2, 0.9)
			return _shade(c1, 0.88 + _h(b[0], b[1], s) * 0.2 + _n(fx, fy, 0.2, s) * 0.06)
		"autobloquant":
			var b := _bond(x, y, 16, 8, 1)
			var wav := (x % 8) == 4 and (y % 8) < 4
			if b[2] or wav:
				return _shade(c2, 0.9)
			return _shade(c1, 0.88 + _h(b[0], b[1], s) * 0.2)
		"enrobe":
			var r := _h(x, y, s)
			return _shade(c1.lerp(c2, r * r), 0.9 + _n(fx, fy, 0.3, s) * 0.08)
		"tatami":
			if x % 32 < 2 or y % 64 < 1:
				return c2
			return _shade(c1, 0.92 + sin(fy * 1.4) * 0.04 + _n(fx, fy, 0.2, s) * 0.04)
		"corten":
			var t := clampf(0.5 + _n(fx, fy, 0.1, s) * 1.4, 0.0, 1.0)
			var c := c1.lerp(c2, t)
			if _h(x, y, s) > 0.9:
				return _shade(c, 1.2)
			return c
		"panneaux":
			if x % 32 == 0 or y % 21 == 0:
				return _shade(c2, 0.7)
			return _shade(c1, 0.95 + _n(fx * 0.3, fy * 0.3, 0.1, s) * 0.05)
		"pave_verre":
			var cell := 16
			if x % cell < 2 or y % cell < 2:
				return Color(0.85, 0.85, 0.82, 0.95)
			var u := float(x % cell) / cell - 0.5
			var v := float(y % cell) / cell - 0.5
			var g := c1.lerp(c2, clampf(1.0 - (u * u + v * v) * 3.0, 0.0, 1.0))
			g.a = 0.6
			return g
		"verre_depoli":
			var g := c1.lerp(c2, _h(x, y, s) * 0.5)
			g.a = 0.78
			return g
		"eau":
			var w := sin(fx * 0.25 + _n(fx, fy, 0.06, s) * 6.0) * 0.5 + 0.5
			var g := c1.lerp(c2, w * 0.35)
			g.a = 0.62
			return g
		"toile":
			var c := _shade(c1, 0.97 + ((x + y) % 2) * 0.03 + _n(fx, fy, 0.1, s) * 0.03)
			return c
		"rayures":
			return _shade(c1 if (x / 8) % 2 == 0 else c2, 0.97 + (y % 2) * 0.03)
		"cuir":
			var c := _shade(c1, 0.92 + _n(fx, fy, 0.35, s) * 0.12)
			if _h(x, y, s) > 0.97:
				return _shade(c2, 0.9)
			return c
		"colombage":
			var beam := 5
			var on := x < beam or x >= PX - beam or y < beam or y >= PX - beam
			on = on or absi(x - y) < 4
			if on:
				return _shade(c2, 0.9 + _n(fx, fy, 0.3, s) * 0.08)
			return _shade(c1, 1.0 + _n(fx, fy, 0.25, s) * 0.05)
	return c1
