class_name PortraitConseiller
extends RefCounted
## Portrait du conseiller municipal (SVG low-poly dessiné à la volée) : serein,
## soucieux ou alarmé selon l'avis le plus grave. Lunettes, nœud papillon, et une
## mèche rebelle qui se dresse quand les nouvelles sont mauvaises.

static var _cache := {}

const _PEAU := "#e8b48a"
const _OMBRE := "#c98f66"
const _COSTUME := "#34495e"
const _FOND := ["#2f4a3a", "#4a4129", "#4d2c2a"]


static func svg(humeur: int) -> String:
	var h := clampi(humeur, 0, 2)
	var bouche: String = ["<path d=\"M38 62q10 9 20 0\" fill=\"none\" stroke=\"#6b2e22\" stroke-width=\"3\" stroke-linecap=\"round\"/>",
		"<path d=\"M39 64q9 -4 18 0\" fill=\"none\" stroke=\"#6b2e22\" stroke-width=\"3\" stroke-linecap=\"round\"/>",
		"<ellipse cx=\"48\" cy=\"64\" rx=\"5\" ry=\"6\" fill=\"#6b2e22\"/>"][h]
	var sourcils: String = ["<path d=\"M30 37l10 -2M56 35l10 2\"",
		"<path d=\"M30 35l10 2M56 37l10 -2\"",
		"<path d=\"M30 33l10 4M56 37l10 -4\""][h] + " stroke=\"#3b2a20\" stroke-width=\"3\" stroke-linecap=\"round\"/>"
	var meche: String = ["<path d=\"M44 18q4 -4 8 0\" fill=\"#3b2a20\"/>",
		"<path d=\"M46 18q2 -8 8 -6\" fill=\"none\" stroke=\"#3b2a20\" stroke-width=\"3\"/>",
		"<path d=\"M44 19l2 -12M50 19l4 -11M56 20l6 -8\" stroke=\"#3b2a20\" stroke-width=\"3\" stroke-linecap=\"round\"/>"][h]
	var goutte := "<path d=\"M72 30q4 6 0 9q-4 -3 0 -9Z\" fill=\"#8fd3ff\"/>" if h == 2 else ""
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"96\" height=\"96\" viewBox=\"0 0 96 96\">" \
		+ "<rect width=\"96\" height=\"96\" rx=\"14\" fill=\"%s\"/>" % _FOND[h] \
		+ "<path d=\"M14 96q4 -22 34 -24q30 2 34 24Z\" fill=\"%s\"/>" % _COSTUME \
		+ "<path d=\"M40 74l8 8l8 -8Z\" fill=\"#f2f0e6\"/><path d=\"M40 80l8 -3l8 3l-8 3Z\" fill=\"#e76f51\"/>" \
		+ "<rect x=\"42\" y=\"62\" width=\"12\" height=\"12\" fill=\"%s\"/>" % _OMBRE \
		+ "<path d=\"M24 44q0 -26 24 -26q24 0 24 26q0 24 -24 26q-24 -2 -24 -26Z\" fill=\"%s\"/>" % _PEAU \
		+ "<path d=\"M48 70q-24 -2 -24 -26q4 18 24 22Z\" fill=\"%s\" opacity=\".6\"/>" % _OMBRE \
		+ "<path d=\"M24 40q0 -22 24 -22q24 0 24 22q-6 -12 -24 -12q-18 0 -24 12Z\" fill=\"#3b2a20\"/>" \
		+ meche + sourcils \
		+ "<circle cx=\"37\" cy=\"45\" r=\"8\" fill=\"#ffffff\" fill-opacity=\".25\" stroke=\"#222\" stroke-width=\"2.5\"/>" \
		+ "<circle cx=\"59\" cy=\"45\" r=\"8\" fill=\"#ffffff\" fill-opacity=\".25\" stroke=\"#222\" stroke-width=\"2.5\"/>" \
		+ "<path d=\"M45 45h6\" stroke=\"#222\" stroke-width=\"2.5\"/>" \
		+ "<circle cx=\"37\" cy=\"46\" r=\"2.6\" fill=\"#222\"/><circle cx=\"59\" cy=\"46\" r=\"2.6\" fill=\"#222\"/>" \
		+ "<path d=\"M48 48l-3 8h5\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\"/>" % _OMBRE \
		+ bouche + goutte + "</svg>"


## Texture du portrait, `taille` pixels de côté.
static func get_portrait(humeur: int, taille := 72) -> Texture2D:
	var key := "%d|%d" % [humeur, taille]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	if img.load_svg_from_string(svg(humeur), float(taille) / 96.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
