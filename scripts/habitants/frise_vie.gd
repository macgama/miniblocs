class_name FriseVie
extends Control
## Frise chronologique d'une vie : une bande colorée par étape (enfance,
## école, études, travail, sans emploi, retraite) et un point par grand
## moment (couple, mariage, enfant, diplôme, médaille, maladie, décès…).

const BAR_Y := 16.0
const BAR_H := 14.0

## [[âge début, âge fin, phase], …] (CycleVie.phases_of).
var phases: Array = []
## [[âge, code], …]
var points: Array = []
var span := 80.0
var alive := true


func setup(vie: CycleVie, p: Dictionary) -> void:
	phases = vie.phases_of(p)
	points.clear()
	var end_age := vie.age_of(p)
	for e in p.get("cv", []):
		var code := String(e[1])
		if code in ["couple", "mariage", "pacs", "separation", "enfant", "diplome", "sport", "maladie", "guerison",
				"deces", "depart", "veuvage", "heritage", "arrivee", "permis"]:
			points.append([clampf((float(e[0]) - float(p.nj)) / 365.25, 0.0, end_age), code])
	alive = not p.has("mort")
	span = maxf(ceilf(maxf(end_age, 1.0) / 10.0) * 10.0, 10.0)
	custom_minimum_size = Vector2(0, 46)
	tooltip_text = _legend()
	queue_redraw()


func _legend() -> String:
	var out := []
	var seen := {}
	for ph in phases:
		var k := String(ph[2])
		if not seen.has(k):
			seen[k] = true
			out.append("%s : %d → %d ans" % [CycleVie.PHASE_NAMES.get(k, k), floori(float(ph[0])), floori(float(ph[1]))])
	return "\n".join(out)


func _draw() -> void:
	var w := size.x - 8.0
	var x0 := 4.0
	draw_rect(Rect2(x0, BAR_Y, w, BAR_H), Color(1, 1, 1, 0.08))
	for ph in phases:
		var a := float(ph[0]) / span * w
		var b := float(ph[1]) / span * w
		draw_rect(Rect2(x0 + a, BAR_Y, maxf(b - a, 1.0), BAR_H), CycleVie.PHASES.get(String(ph[2]), Color.GRAY))
	var font := get_theme_default_font()
	var step := 10.0 if span <= 60.0 else 20.0
	var t := 0.0
	while t <= span + 0.01:
		var x := x0 + t / span * w
		draw_line(Vector2(x, BAR_Y + BAR_H), Vector2(x, BAR_Y + BAR_H + 4.0), Color(1, 1, 1, 0.5))
		draw_string(font, Vector2(x - 8.0, BAR_Y + BAR_H + 15.0), "%d" % int(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(1, 1, 1, 0.6))
		t += step
	for e in points:
		var x := x0 + float(e[0]) / span * w
		var c: Color = CycleVie.CODES.get(String(e[1]), Color.WHITE)
		if String(e[1]) == "deces":
			draw_line(Vector2(x, BAR_Y - 6.0), Vector2(x, BAR_Y + BAR_H + 2.0), Color.WHITE, 2.0)
			continue
		draw_circle(Vector2(x, BAR_Y - 6.0), 4.0, Color(0, 0, 0, 0.6))
		draw_circle(Vector2(x, BAR_Y - 6.0), 3.0, c)
	if alive:
		# Aujourd'hui : petit triangle au bout de la bande.
		var x := x0 + (float(phases[-1][1]) if not phases.is_empty() else 0.0) / span * w
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, BAR_Y + BAR_H + 2), Vector2(x + 4, BAR_Y + BAR_H + 2),
			Vector2(x, BAR_Y + BAR_H - 4)]), Color.WHITE)
