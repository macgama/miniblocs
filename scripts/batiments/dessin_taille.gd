class_name DessinTaille
extends Control
## Petit dessin d'une taille de bâtiment pour la carte « Taille » : vue en plan
## (emprise, à l'échelle de la plus grande proposée) ou façade (niveaux, à
## l'échelle du plus haut permis), avec un bonhomme pour se repérer.

var sorte := "plan"
## Plan : largeur et profondeur en part de la plus grande (0 à 1).
var fx := 1.0
var fz := 1.0
## Façade : niveaux, niveaux au plus, largeur relative de la façade (0 à 1).
var niveaux := 1
var max_niveaux := 1
var largeur := 0.5


static func plan(px: float, pz: float) -> DessinTaille:
	var c := DessinTaille.new()
	c.sorte = "plan"
	c.fx = clampf(px, 0.05, 1.0)
	c.fz = clampf(pz, 0.05, 1.0)
	return c


static func facade(n: int, n_max: int, larg: float) -> DessinTaille:
	var c := DessinTaille.new()
	c.sorte = "facade"
	c.niveaux = maxi(1, n)
	c.max_niveaux = maxi(n_max, n)
	c.largeur = clampf(larg, 0.25, 0.75)
	return c


func _draw() -> void:
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	if sorte == "plan":
		var cote := minf(r.size.x, r.size.y)
		var sz := Vector2(cote * fx, cote * fz)
		var p := r.position + (r.size - sz) / 2.0
		draw_rect(Rect2(p, sz), Color("e9c46a", 0.85))
		draw_rect(Rect2(p, sz), Color("2a2414"), false, 1.5)
		# Façade (côté rue) en bas, trait plus épais.
		draw_line(p + Vector2(0, sz.y), p + sz, Color("ffd166"), 3.0)
		return
	# Façade : sol, niveaux, toit à deux pans.
	var sol := r.position.y + r.size.y
	var roof_h := 8.0
	var hn := minf(10.0, (r.size.y - roof_h) / float(max_niveaux))
	var bw := r.size.x * largeur
	var x0 := r.position.x + (r.size.x - bw) / 2.0 + 6.0
	draw_line(Vector2(r.position.x, sol), Vector2(r.end.x, sol), Color(1, 1, 1, 0.4), 1.0)
	var top := sol - hn * niveaux
	draw_rect(Rect2(x0, top, bw, hn * niveaux), Color("f1e6d2"))
	for i in niveaux:
		var y := sol - hn * (i + 1)
		if i > 0:
			draw_line(Vector2(x0, y + hn), Vector2(x0 + bw, y + hn), Color(0, 0, 0, 0.18), 1.0)
		var nf := maxi(1, floori(bw / 10.0))
		for f in nf:
			var fxp := x0 + (f + 0.5) * bw / nf - 2.0
			draw_rect(Rect2(fxp, y + hn * 0.3, 4.0, hn * 0.42), Color("33495e"))
	draw_colored_polygon(PackedVector2Array([Vector2(x0 - 3, top), Vector2(x0 + bw + 3, top), Vector2(x0 + bw / 2.0, top - roof_h)]), Color("c8553d"))
	# Bonhomme de 1,8 m à l'échelle d'un niveau de 3 m.
	var hb := hn * 0.6
	var xb := x0 - 9.0
	draw_line(Vector2(xb, sol), Vector2(xb, sol - hb * 0.75), Color(1, 1, 1, 0.8), 1.5)
	draw_circle(Vector2(xb, sol - hb * 0.85), maxf(1.2, hb * 0.13), Color(1, 1, 1, 0.8))
