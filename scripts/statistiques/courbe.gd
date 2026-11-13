class_name Courbe
extends Control
## Graphique en courbes : une ou plusieurs séries (jour, valeur), axe des dates en
## bas, graduations à gauche, et au survol une ligne verticale avec les valeurs.

## [{nom, couleur, points: PackedVector2Array}]
var series: Array = []
var indicateur := ""
## Jours affichés : de x_min à x_max (calculés d'après les séries si NAN).
var x_min := NAN
var x_max := NAN
var _survol := -1.0

const MARGE_G := 62.0
const MARGE_B := 22.0
const MARGE_H := 8.0
const MARGE_D := 10.0
const GRILLE := Color(1, 1, 1, 0.08)
const AXE := Color(1, 1, 1, 0.55)


func _init() -> void:
	custom_minimum_size = Vector2(0, 220)
	mouse_filter = Control.MOUSE_FILTER_STOP


func definir(ind: String, s: Array, de := NAN, a := NAN) -> void:
	indicateur = ind
	series = s
	x_min = de
	x_max = a
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_survol = (event as InputEventMouseMotion).position.x
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_survol = -1.0
		queue_redraw()


## Bornes des valeurs, arrondies à des graduations lisibles.
func _bornes() -> Vector2:
	var lo := INF
	var hi := -INF
	for s in series:
		for p in (s.points as PackedVector2Array):
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	if lo == INF:
		return Vector2(0, 1)
	var d := Statistiques.indicateur(indicateur)
	var fmt := String(d.get("fmt", "int"))
	# Pourcentages et notes sur 100 : l'échelle 0-100 parle d'elle-même.
	if (fmt == "pct" or String(d.get("unite", "")) == "/100") and hi <= 100.0 and lo >= 0.0:
		return Vector2(0, 100)
	if lo > 0.0 and fmt != "money":
		lo = 0.0
	if is_equal_approx(lo, hi):
		hi = lo + maxf(1.0, absf(lo) * 0.1)
	var pas := _pas((hi - lo) / 4.0)
	return Vector2(floorf(lo / pas) * pas, ceilf(hi / pas) * pas)


static func _pas(brut: float) -> float:
	var e := pow(10.0, floorf(log(maxf(brut, 1e-6)) / log(10.0)))
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if brut <= m * e:
			return m * e
	return 10.0 * e


func _draw() -> void:
	var font := get_theme_default_font()
	var fs := 11
	var zone := Rect2(MARGE_G, MARGE_H, size.x - MARGE_G - MARGE_D, size.y - MARGE_H - MARGE_B)
	draw_rect(zone, Color(0, 0, 0, 0.18))
	var xa := x_min
	var xb := x_max
	if is_nan(xa) or is_nan(xb):
		xa = INF
		xb = -INF
		for s in series:
			for p in (s.points as PackedVector2Array):
				xa = minf(xa, p.x)
				xb = maxf(xb, p.x)
	var vide := true
	for s in series:
		if not (s.points as PackedVector2Array).is_empty():
			vide = false
	if vide or xa == INF:
		draw_string(font, zone.position + Vector2(12, zone.size.y * 0.5), "Pas encore de relevé : le premier se fait chaque jour à minuit.",
			HORIZONTAL_ALIGNMENT_LEFT, zone.size.x - 24, 13, UiStyle.TEXT_DIM)
		return
	if xb - xa < 1.0:
		xa -= 0.5
		xb += 0.5
	var b := _bornes()
	var vers := func(p: Vector2) -> Vector2:
		return Vector2(zone.position.x + (p.x - xa) / (xb - xa) * zone.size.x,
			zone.end.y - (p.y - b.x) / (b.y - b.x) * zone.size.y)
	# Graduations horizontales.
	for i in 5:
		var v := lerpf(b.x, b.y, i / 4.0)
		var y := zone.end.y - zone.size.y * i / 4.0
		draw_line(Vector2(zone.position.x, y), Vector2(zone.end.x, y), GRILLE if i > 0 else AXE, 1.0)
		var t := Statistiques.format(indicateur, v, false)
		draw_string(font, Vector2(0, y + 4), t, HORIZONTAL_ALIGNMENT_RIGHT, MARGE_G - 6, fs, UiStyle.TEXT_DIM)
	# Ligne du zéro (caisse, solde) quand l'échelle passe sous zéro.
	if b.x < 0.0 and b.y > 0.0:
		var y0: float = vers.call(Vector2(xa, 0.0)).y
		draw_line(Vector2(zone.position.x, y0), Vector2(zone.end.x, y0), Color(1, 0.55, 0.48, 0.5), 1.0)
	# Dates en bas : début, milieu, fin.
	var court := xb - xa > 90.0
	for i in 3:
		var jx := lerpf(xa, xb, i / 2.0)
		var px := zone.position.x + zone.size.x * i / 2.0
		var al: HorizontalAlignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][i]
		var w := 110.0
		var x0 := px - (0.0 if i == 0 else (w * 0.5 if i == 1 else w))
		draw_string(font, Vector2(x0, size.y - 6), Statistiques.date(jx, court), al, w, fs, UiStyle.TEXT_DIM)
	# Séries.
	for s in series:
		var pts := PackedVector2Array()
		for p in (s.points as PackedVector2Array):
			if p.x >= xa - 0.01 and p.x <= xb + 0.01:
				pts.append(vers.call(p))
		if pts.size() == 1:
			draw_circle(pts[0], 3.0, s.couleur)
		elif pts.size() > 1:
			draw_polyline(pts, s.couleur, 2.0, true)
	# Survol : ligne verticale et valeurs du jour le plus proche.
	if _survol >= zone.position.x and _survol <= zone.end.x:
		var jour := xa + (_survol - zone.position.x) / zone.size.x * (xb - xa)
		draw_line(Vector2(_survol, zone.position.y), Vector2(_survol, zone.end.y), Color(1, 1, 1, 0.35), 1.0)
		var lignes := [Statistiques.date(jour)]
		var couleurs := [UiStyle.TEXT]
		for s in series:
			var best := Vector2(NAN, NAN)
			for p in (s.points as PackedVector2Array):
				if is_nan(best.x) or absf(p.x - jour) < absf(best.x - jour):
					best = p
			if is_nan(best.x):
				continue
			draw_circle(vers.call(best), 3.5, s.couleur)
			lignes.append("%s : %s" % [s.nom, Statistiques.format(indicateur, best.y)])
			couleurs.append(s.couleur)
		var lw := 0.0
		for l in lignes:
			lw = maxf(lw, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var bw := lw + 14.0
		var bh := 15.0 * lignes.size() + 8.0
		var bx := _survol + 8.0 if _survol + 8.0 + bw < size.x else _survol - 8.0 - bw
		draw_rect(Rect2(bx, zone.position.y + 2, bw, bh), Color(0.05, 0.07, 0.06, 0.92))
		for i in lignes.size():
			draw_string(font, Vector2(bx + 7, zone.position.y + 17 + 15 * i), lignes[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, couleurs[i])
