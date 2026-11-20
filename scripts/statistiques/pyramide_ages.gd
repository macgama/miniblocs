class_name PyramideAges
extends Control
## Pyramide des âges : hommes à gauche, femmes à droite, une barre par tranche de
## 10 ans (la plus jeune en bas). Au survol : les effectifs de la tranche.

const HOMMES := Color("7cc7ff")
const FEMMES := Color("f5a3d0")
const MARGE_CENTRE := 34.0
const MARGE_B := 20.0

## [{h, f}] de 0-9 ans à 90 ans et plus (Statistiques.pyramide).
var tranches: Array = []
var _survol := -1


func _init() -> void:
	custom_minimum_size = Vector2(0, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP


func definir(t: Array) -> void:
	tranches = t
	queue_redraw()


static func libelle(i: int) -> String:
	return "90+" if i >= 9 else "%d-%d" % [i * 10, i * 10 + 9]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var n := maxi(1, tranches.size())
		var hb := (size.y - MARGE_B) / n
		var i := n - 1 - int((event as InputEventMouseMotion).position.y / hb)
		_survol = i if i >= 0 and i < n else -1
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_survol = -1
		queue_redraw()


func _draw() -> void:
	var n := tranches.size()
	if n == 0:
		return
	var font := get_theme_default_font()
	var maxv := 1
	for t in tranches:
		maxv = maxi(maxv, maxi(int(t.h), int(t.f)))
	var cx := size.x * 0.5
	var demi := cx - MARGE_CENTRE - 4.0
	var hb := (size.y - MARGE_B) / n
	for i in n:
		var t: Dictionary = tranches[i]
		var y := (n - 1 - i) * hb
		var lh := demi * int(t.h) / maxv
		var lf := demi * int(t.f) / maxv
		var survol := i == _survol
		draw_rect(Rect2(cx - MARGE_CENTRE - lh, y + 2, lh, hb - 4), Color(HOMMES, 1.0 if survol else 0.8))
		draw_rect(Rect2(cx + MARGE_CENTRE, y + 2, lf, hb - 4), Color(FEMMES, 1.0 if survol else 0.8))
		var lab := libelle(i)
		var w := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(cx - w * 0.5, y + hb * 0.5 + 4), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.TEXT_DIM)
		if survol:
			draw_string(font, Vector2(cx - MARGE_CENTRE - lh - 4 - font.get_string_size(str(t.h), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, y + hb * 0.5 + 4),
				str(t.h), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.TEXT)
			draw_string(font, Vector2(cx + MARGE_CENTRE + lf + 4, y + hb * 0.5 + 4), str(t.f), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.TEXT)
	var yb := size.y - 5
	draw_string(font, Vector2(8, yb), "● " + Langue.t("Hommes"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HOMMES)
	var femmes := Langue.t("Femmes") + " ●"
	var wf := font.get_string_size(femmes, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(size.x - wf - 8, yb), femmes, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, FEMMES)
