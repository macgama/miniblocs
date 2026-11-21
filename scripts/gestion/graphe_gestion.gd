class_name GrapheGestion
extends Control
## Petit graphique des comptes du mode gestion : recettes et charges de
## chaque jour en barres, remplissage en ligne (historique de Gestion :
## [jour, recettes, charges, nuitées, remplissage, note, satisfaction]).

var donnees: Array = []


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.05))
	if donnees.is_empty():
		return
	var mx := 1.0
	for e in donnees:
		mx = maxf(mx, maxf(float(e[1]), float(e[2])))
	var n := donnees.size()
	var pas := w / float(n)
	var bw := maxf(1.0, pas * 0.38)
	var bas := h - 14.0
	for i in n:
		var e: Array = donnees[i]
		var x := i * pas + pas * 0.1
		var hr := float(e[1]) / mx * (bas - 6.0)
		var hc := float(e[2]) / mx * (bas - 6.0)
		draw_rect(Rect2(x, bas - hr, bw, hr), Color("9fe3b0"))
		draw_rect(Rect2(x + bw, bas - hc, bw, hc), Color("ff8f80"))
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2(i * pas + pas * 0.5, bas - clampf(float(donnees[i][4]), 0.0, 1.0) * (bas - 6.0)))
	if pts.size() >= 2:
		draw_polyline(pts, Color("ffd166"), 2.0, true)
	draw_line(Vector2(0, bas), Vector2(w, bas), Color(1, 1, 1, 0.3), 1.0)
	var f := get_theme_default_font()
	draw_string(f, Vector2(2, h - 2), "jour %d" % int(donnees[0][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))
	draw_string(f, Vector2(w - 60, h - 2), "jour %d" % int(donnees[-1][0]), HORIZONTAL_ALIGNMENT_RIGHT, 58, 10, Color(1, 1, 1, 0.6))
	draw_string(f, Vector2(4, 12), BuildingSystem.format_money(int(mx)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))
