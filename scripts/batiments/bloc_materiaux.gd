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
]

const FAMILIES := [
	{"id": "", "name": "Tous les matériaux"},
	{"id": "murs", "name": "Murs"},
	{"id": "toits", "name": "Toits"},
	{"id": "sols", "name": "Sols"},
	{"id": "bois", "name": "Bois"},
	{"id": "metal_verre", "name": "Métal et verre"},
	{"id": "nature", "name": "Nature"},
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
		"colombage":
			var beam := 5
			var on := x < beam or x >= PX - beam or y < beam or y >= PX - beam
			on = on or absi(x - y) < 4
			if on:
				return _shade(c2, 0.9 + _n(fx, fy, 0.3, s) * 0.08)
			return _shade(c1, 1.0 + _n(fx, fy, 0.25, s) * 0.05)
	return c1
