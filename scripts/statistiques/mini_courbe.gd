class_name MiniCourbe
extends Control
## Petite courbe sans axes (vignette du tableau de bord) : la tendance d'un chiffre,
## remplie sous la ligne, avec un point sur la dernière valeur.

var points := PackedVector2Array()
var couleur := Color("ffd166")


func _init() -> void:
	custom_minimum_size = Vector2(0, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func definir(p: PackedVector2Array, c: Color) -> void:
	points = p
	couleur = c
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(2, 3), size - Vector2(4, 6))
	draw_line(Vector2(r.position.x, r.end.y), r.end, Color(1, 1, 1, 0.12), 1.0)
	if points.size() < 2:
		return
	var x0 := points[0].x
	var x1 := points[-1].x
	var lo := INF
	var hi := -INF
	for p in points:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	if hi - lo < 1e-6:
		lo -= 1.0
		hi += 1.0
	var ligne := PackedVector2Array()
	for p in points:
		var x := r.position.x + (p.x - x0) / maxf(1e-6, x1 - x0) * r.size.x
		var y := r.end.y - (p.y - lo) / (hi - lo) * r.size.y
		ligne.append(Vector2(x, y))
	var aire := ligne.duplicate()
	aire.append(Vector2(ligne[-1].x, r.end.y))
	aire.append(Vector2(ligne[0].x, r.end.y))
	draw_colored_polygon(aire, Color(couleur, 0.16))
	draw_polyline(ligne, couleur, 1.6, true)
	draw_circle(ligne[-1], 2.6, couleur)
