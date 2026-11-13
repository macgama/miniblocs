class_name Drapeaux
extends RefCounted
## Drapeaux des pays (atlas assets/drapeaux.png, 96 × 72 par drapeau, tiré des
## SVG du paquet « flag-icons », MIT ; tools/build_drapeaux.gd). Codes ISO 3166-1
## en minuscules, plus quelques régions (gb-sct, es-ct…) et l'ONU, l'UE.

const ATLAS := "res://assets/drapeaux.png"
const INDEX := "res://assets/drapeaux.json"

static var _index := {}
static var _w := 96
static var _h := 72
static var _cols := 16
static var _tex: Texture2D
static var _icones := {}
static var _mats := {}
static var _liste: Array = []


static func _charger() -> bool:
	if _tex != null:
		return true
	if not ResourceLoader.exists(ATLAS) or not FileAccess.file_exists(INDEX):
		return false
	_tex = load(ATLAS)
	var d = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if d is Dictionary:
		_index = d.get("index", {})
		_w = int(d.get("w", 96))
		_h = int(d.get("h", 72))
		_cols = int(d.get("cols", 16))
	return _tex != null


static func existe(code: String) -> bool:
	return _charger() and _index.has(code.to_lower())


static func nom(code: String) -> String:
	return Villes.nom_pays(code) if code != "" else "Aucun drapeau"


## [[code, nom]] triés par nom français.
static func liste() -> Array:
	if _liste.is_empty() and _charger():
		for c in _index:
			_liste.append([String(c), Villes.nom_pays(String(c))])
		_liste.sort_custom(func(a: Array, b: Array) -> bool: return Villes.cle(a[1]) < Villes.cle(b[1]))
	return _liste


static func _rect(code: String) -> Rect2:
	var i := int(_index[code])
	return Rect2((i % _cols) * _w, (i / _cols) * _h, _w, _h)


## Petite image du drapeau (interface), ou null.
static func icone(code: String, hauteur := 18) -> Texture2D:
	code = code.to_lower()
	var key := "%s|%d" % [code, hauteur]
	if _icones.has(key):
		return _icones[key]
	if not existe(code):
		return null
	var img := _tex.get_image().get_region(Rect2i(_rect(code)))
	img.resize(roundi(hauteur * float(_w) / _h), hauteur, Image.INTERPOLATE_BILINEAR)
	var t := ImageTexture.create_from_image(img)
	_icones[key] = t
	return t


## Matériau du drapeau pour un mât (les deux faces), ou null.
static func materiau(code: String) -> StandardMaterial3D:
	code = code.to_lower()
	if _mats.has(code):
		return _mats[code]
	if not existe(code):
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var r := _rect(code)
	var size := Vector2(_tex.get_width(), _tex.get_height())
	# Un peu en retrait du bord pour ne pas baver sur le drapeau voisin.
	m.uv1_scale = Vector3((r.size.x - 2.0) / size.x, (r.size.y - 2.0) / size.y, 1.0)
	m.uv1_offset = Vector3((r.position.x + 1.0) / size.x, (r.position.y + 1.0) / size.y, 0.0)
	_mats[code] = m
	return m
