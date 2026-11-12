class_name BlocFormes
extends RefCounted
## Formes de l'éditeur libre : bloc, demi-bloc, escalier, pentes de toit,
## angles, poteaux, colonnes, poutres, cloisons, vitres, garde-corps, fenêtres,
## portes, porte de garage, fenêtre de toit…
##
## Chaque bloc posé est un entier (code) :
##   matériau (8 bits) | forme << 8 (6 bits) | rotation << 14 (2 bits)
##   | teinte << 16 (4 bits) | ouvert << 20 | haut << 21 (moitié haute d'une porte)
## Les anciens blocs (code < 256) sont des blocs pleins : les sauvegardes restent valables.
##
## Repère d'une case : cube unité [0, 1]³ (1 m), rotation 0 = la pente monte
## vers +Z, la façade d'une fenêtre ou d'une porte regarde vers −Z.

enum S { FULL, SLAB, SLAB_TOP, STAIRS, SLOPE, SLOPE_LOW, SLOPE_HIGH, CORNER_OUT, CORNER_IN,
	PILLAR, COLUMN, BEAM, WALL_THIN, PANE, FENCE, WINDOW, WINDOW_SHUTTERS, BAY, DOOR, DOOR_GLASS,
	GARAGE, SKYLIGHT, FLOOR_THIN }

## name, cost (part du prix du matériau), fam (onglet du panneau), cells (hauteur
## en cases), open (s'ouvre), desc.
const INFO := {
	S.FULL: {"name": "Bloc", "cost": 1.0, "fam": "formes", "desc": "Bloc plein de 1 m."},
	S.SLAB: {"name": "Demi-bloc", "cost": 0.5, "fam": "formes", "desc": "Dalle de 50 cm. Visée sur le haut d'une face : demi-bloc du haut."},
	S.SLAB_TOP: {"name": "Demi-bloc haut", "cost": 0.5, "fam": "", "desc": ""},
	S.STAIRS: {"name": "Escalier", "cost": 0.75, "fam": "formes", "desc": "Deux marches de 50 cm, montent vers où tu regardes."},
	S.SLOPE: {"name": "Pente", "cost": 0.5, "fam": "toits", "desc": "Pente à 45°, pour les toits."},
	S.SLOPE_LOW: {"name": "Pente douce (bas)", "cost": 0.3, "fam": "toits", "desc": "Toit en pente douce : moitié basse (0 à 50 cm)."},
	S.SLOPE_HIGH: {"name": "Pente douce (haut)", "cost": 0.7, "fam": "toits", "desc": "Toit en pente douce : moitié haute (50 cm à 1 m)."},
	S.CORNER_OUT: {"name": "Arêtier", "cost": 0.35, "fam": "toits", "desc": "Angle saillant d'un toit à quatre pans."},
	S.CORNER_IN: {"name": "Noue", "cost": 0.7, "fam": "toits", "desc": "Angle rentrant d'un toit en L."},
	S.PILLAR: {"name": "Poteau", "cost": 0.2, "fam": "formes", "desc": "Poteau carré de 30 cm."},
	S.COLUMN: {"name": "Colonne", "cost": 0.45, "fam": "formes", "desc": "Colonne ronde avec base et chapiteau."},
	S.BEAM: {"name": "Poutre", "cost": 0.2, "fam": "formes", "desc": "Poutre horizontale de 30 cm."},
	S.WALL_THIN: {"name": "Cloison", "cost": 0.3, "fam": "formes", "desc": "Mur fin de 30 cm (cloisons intérieures)."},
	S.PANE: {"name": "Vitre / panneau", "cost": 0.15, "fam": "formes", "desc": "Plaque fine de 10 cm : vitre, panneau, palissade."},
	S.FENCE: {"name": "Garde-corps", "cost": 0.3, "fam": "formes", "desc": "Rambarde à barreaux (balcons, escaliers)."},
	S.FLOOR_THIN: {"name": "Revêtement", "cost": 0.1, "fam": "formes", "desc": "Plaque de 10 cm : parquet, carrelage, tapis."},
	S.WINDOW: {"name": "Fenêtre", "cost": 2.0, "fam": "ouvertures", "desc": "Fenêtre à croisillons et appui, dans un mur."},
	S.WINDOW_SHUTTERS: {"name": "Fenêtre à volets", "cost": 3.0, "fam": "ouvertures", "desc": "Fenêtre et ses volets ouverts contre la façade."},
	S.BAY: {"name": "Baie vitrée", "cost": 2.0, "fam": "ouvertures", "desc": "Grand vitrage à cadre fin : à assembler pour une baie."},
	S.DOOR: {"name": "Porte", "cost": 3.0, "fam": "ouvertures", "cells": 2, "open": true, "desc": "Porte de 2 m à panneaux. S'ouvre en vue au sol (E ou clic)."},
	S.DOOR_GLASS: {"name": "Porte-fenêtre", "cost": 3.5, "fam": "ouvertures", "cells": 2, "open": true, "desc": "Porte vitrée de 2 m. S'ouvre en vue au sol (E ou clic)."},
	S.GARAGE: {"name": "Porte de garage", "cost": 2.0, "fam": "ouvertures", "open": true, "desc": "Élément de porte sectionnelle : assemble-en plusieurs (outil Mur)."},
	S.SKYLIGHT: {"name": "Fenêtre de toit", "cost": 2.5, "fam": "ouvertures", "desc": "Pente à 45° avec une fenêtre dans le toit."},
}

## Ordre d'affichage dans le panneau.
const ORDER := [S.FULL, S.SLAB, S.STAIRS, S.FLOOR_THIN, S.WALL_THIN, S.PILLAR, S.COLUMN, S.BEAM, S.PANE, S.FENCE,
	S.SLOPE, S.SLOPE_LOW, S.SLOPE_HIGH, S.CORNER_OUT, S.CORNER_IN,
	S.WINDOW, S.WINDOW_SHUTTERS, S.BAY, S.SKYLIGHT, S.DOOR, S.DOOR_GLASS, S.GARAGE]

const FRAME_TINT := 1 # cadres blancs par défaut quand le matériau est un mur


static func encode(m: int, shape := 0, rot := 0, tint := 0, open := false, top := false) -> int:
	return (m & 255) | ((shape & 63) << 8) | ((rot & 3) << 14) | ((tint & 15) << 16) | (int(open) << 20) | (int(top) << 21)


static func mat_of(code: int) -> int:
	return code & 255


static func shape_of(code: int) -> int:
	return (code >> 8) & 63


static func rot_of(code: int) -> int:
	return (code >> 14) & 3


static func tint_of(code: int) -> int:
	return (code >> 16) & 15


static func is_open(code: int) -> bool:
	return (code >> 20) & 1 == 1


static func is_top(code: int) -> bool:
	return (code >> 21) & 1 == 1


static func with_open(code: int, open: bool) -> int:
	return (code & ~(1 << 20)) | (int(open) << 20)


static func cells(shape: int) -> int:
	return int(INFO.get(shape, {}).get("cells", 1))


static func openable(shape: int) -> bool:
	return bool(INFO.get(shape, {}).get("open", false))


static func shape_name(shape: int) -> String:
	return String(INFO.get(shape, {}).get("name", "Bloc"))


## Prix d'un bloc posé.
static func price(code: int) -> int:
	var m := mat_of(code)
	var base := int(BlocMateriaux.LIST[clampi(m, 0, BlocMateriaux.LIST.size() - 1)].price)
	var f := float(INFO.get(shape_of(code), {}).get("cost", 1.0))
	if is_top(code):
		f = 0.0 # la moitié haute d'une porte est comptée avec le bas
	return maxi(0 if is_top(code) else 1, roundi(base * f))


## Plein (cache les faces voisines) ?
static func is_full(code: int) -> bool:
	return shape_of(code) == S.FULL


## Direction (rotation 0..3) qui monte vers la direction regardée.
static func rot_facing(dir: Vector3) -> int:
	var dirs := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]
	var best := 0
	var bd := -2.0
	for r in 4:
		var d: float = (dirs[r] as Vector3).dot(Vector3(dir.x, 0, dir.z).normalized())
		if d > bd:
			bd = d
			best = r
	return best


# --- Géométrie ----------------------------------------------------------------------

## Ajoute la forme d'un bloc au maillage. base : coin bas (x, y, z) de la case
## en mètres ; neighbor : Callable(Vector3i décalage en cases) -> code ou -1,
## pour cacher les faces collées à un bloc plein.
static func emit(mesher: BlocMesher, code: int, base: Vector3, neighbor: Callable) -> void:
	var m := mat_of(code)
	var shape := shape_of(code)
	var glass := BlocMateriaux.is_glass(m)
	var ctx := {"m": mesher, "rot": rot_of(code), "base": base, "layer": BlocMateriaux.layer(m),
		"col": BlocMateriaux.tint_color(tint_of(code)), "glass": glass}
	match shape:
		S.FULL:
			_full(ctx, code, neighbor)
		S.SLAB:
			_box(ctx, 0, 0, 0, 1, 0.5, 1)
		S.SLAB_TOP:
			_box(ctx, 0, 0.5, 0, 1, 1, 1)
		S.FLOOR_THIN:
			_box(ctx, 0, 0, 0, 1, 0.1, 1)
		S.STAIRS:
			_box(ctx, 0, 0, 0, 1, 0.5, 1)
			_box(ctx, 0, 0.5, 0.5, 1, 1, 1)
		S.SLOPE:
			_wedge(ctx, 0.0, 1.0)
		S.SLOPE_LOW:
			_wedge(ctx, 0.0, 0.5)
		S.SLOPE_HIGH:
			_box(ctx, 0, 0, 0, 1, 0.5, 1, 1)
			_wedge(ctx, 0.5, 1.0)
		S.CORNER_OUT:
			_corner_out(ctx)
		S.CORNER_IN:
			_corner_in(ctx)
		S.PILLAR:
			_box(ctx, 0.35, 0, 0.35, 0.65, 1, 0.65)
		S.COLUMN:
			_column(ctx, code, neighbor)
		S.BEAM:
			_box(ctx, 0, 0.7, 0.35, 1, 1, 0.65)
		S.WALL_THIN:
			_box(ctx, 0, 0, 0.35, 1, 1, 0.65)
		S.PANE:
			_box(ctx, 0, 0, 0.45, 1, 1, 0.55)
		S.FENCE:
			_fence(ctx)
		S.WINDOW, S.WINDOW_SHUTTERS, S.BAY:
			_window(ctx, shape)
		S.DOOR, S.DOOR_GLASS:
			_door(ctx, shape, is_top(code), is_open(code))
		S.GARAGE:
			_garage(ctx, is_open(code))
		S.SKYLIGHT:
			_wedge(ctx, 0.0, 1.0)
			_skylight(ctx)
		_:
			_box(ctx, 0, 0, 0, 1, 1, 1)


## Point local → monde (rotation autour du centre de la case).
static func _tp(ctx: Dictionary, p: Vector3) -> Vector3:
	for i in int(ctx.rot):
		p = Vector3(1.0 - p.z, p.y, p.x)
	return p + (ctx.base as Vector3)


static func _tn(ctx: Dictionary, n: Vector3) -> Vector3:
	for i in int(ctx.rot):
		n = Vector3(-n.z, n.y, n.x)
	return n


static func _face(ctx: Dictionary, pts: Array, n: Vector3, layer := -1, glass := -1, col: Variant = null) -> void:
	var wp: Array = []
	for p in pts:
		wp.append(_tp(ctx, p))
	var g: bool = ctx.glass if glass == -1 else glass == 1
	var c: Color = ctx.col if col == null else col
	(ctx.m as BlocMesher).face(wp, _tn(ctx, n).normalized(), int(ctx.layer) if layer == -1 else layer, c, g)


## Pavé local ; skip : masque de faces à ne pas dessiner (1 bas, 2 haut, 4 −x, 8 +x, 16 −z, 32 +z).
static func _box(ctx: Dictionary, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, skip := 0, layer := -1, glass := -1, col: Variant = null) -> void:
	if skip & 2 == 0:
		_face(ctx, [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.UP, layer, glass, col)
	if skip & 1 == 0:
		_face(ctx, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)], Vector3.DOWN, layer, glass, col)
	if skip & 4 == 0:
		_face(ctx, [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)], Vector3.LEFT, layer, glass, col)
	if skip & 8 == 0:
		_face(ctx, [Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, layer, glass, col)
	if skip & 16 == 0:
		_face(ctx, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], Vector3.FORWARD, layer, glass, col)
	if skip & 32 == 0:
		_face(ctx, [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.BACK, layer, glass, col)


## Bloc plein : les faces collées à un autre bloc plein (même transparence) sont cachées.
static func _full(ctx: Dictionary, code: int, neighbor: Callable) -> void:
	var skip := 0
	var hu := BlockEditor.HU
	var dirs := [[Vector3i(0, -hu, 0), 1], [Vector3i(0, hu, 0), 2], [Vector3i(-1, 0, 0), 4], [Vector3i(1, 0, 0), 8],
		[Vector3i(0, 0, -1), 16], [Vector3i(0, 0, 1), 32]]
	for d in dirs:
		var nc: int = neighbor.call(d[0])
		if nc >= 0 and is_full(nc) and BlocMateriaux.is_glass(mat_of(nc)) == bool(ctx.glass):
			skip |= int(d[1])
	# Les blocs pleins ne tournent pas : on dessine en repère monde.
	var r: int = ctx.rot
	ctx.rot = 0
	_box(ctx, 0, 0, 0, 1, 1, 1, skip)
	ctx.rot = r


## Coin : pente qui monte de h0 (z = 0) à h1 (z = 1).
static func _wedge(ctx: Dictionary, h0: float, h1: float) -> void:
	var n := Vector3(0, 1.0, -(h1 - h0)).normalized()
	_face(ctx, [Vector3(0, h0, 0), Vector3(1, h0, 0), Vector3(1, h1, 1), Vector3(0, h1, 1)], n)
	if h0 > 0.0:
		_face(ctx, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, h0, 0), Vector3(0, h0, 0)], Vector3.FORWARD)
	if h0 == 0.0:
		_face(ctx, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], Vector3.DOWN)
	_face(ctx, [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, h1, 1), Vector3(0, h1, 1)], Vector3.BACK)
	_face(ctx, [Vector3(0, h0, 0), Vector3(0, h1, 1), Vector3(0, h0, 1)], Vector3.LEFT)
	_face(ctx, [Vector3(1, h0, 0), Vector3(1, h1, 1), Vector3(1, h0, 1)], Vector3.RIGHT)
	if h0 > 0.0:
		_face(ctx, [Vector3(0, 0, 0), Vector3(0, h0, 0), Vector3(0, h0, 1), Vector3(0, 0, 1)], Vector3.LEFT)
		_face(ctx, [Vector3(1, 0, 0), Vector3(1, h0, 0), Vector3(1, h0, 1), Vector3(1, 0, 1)], Vector3.RIGHT)


## Arêtier : sommet au coin (1, 1, 1), deux pans vers −Z et −X.
static func _corner_out(ctx: Dictionary) -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(1, 0, 0)
	var c := Vector3(1, 0, 1)
	var d := Vector3(0, 0, 1)
	var t := Vector3(1, 1, 1)
	_face(ctx, [a, b, t], Vector3(0, 1, -1))
	_face(ctx, [a, t, d], Vector3(-1, 1, 0))
	_face(ctx, [d, c, t], Vector3.BACK)
	_face(ctx, [b, c, t], Vector3.RIGHT)
	_face(ctx, [a, b, c, d], Vector3.DOWN)


## Noue : surface h = max(x, z).
static func _corner_in(ctx: Dictionary) -> void:
	var o := Vector3(0, 0, 0)
	_face(ctx, [o, Vector3(1, 1, 0), Vector3(1, 1, 1)], Vector3(-1, 1, 0))
	_face(ctx, [o, Vector3(1, 1, 1), Vector3(0, 1, 1)], Vector3(0, 1, -1))
	_face(ctx, [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)], Vector3.RIGHT)
	_face(ctx, [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)], Vector3.BACK)
	_face(ctx, [o, Vector3(1, 0, 0), Vector3(1, 1, 0)], Vector3.FORWARD)
	_face(ctx, [o, Vector3(0, 1, 1), Vector3(0, 0, 1)], Vector3.LEFT)
	_face(ctx, [o, Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], Vector3.DOWN)


static func _column(ctx: Dictionary, code: int, neighbor: Callable) -> void:
	var hu := BlockEditor.HU
	var below: int = neighbor.call(Vector3i(0, -hu, 0))
	var above: int = neighbor.call(Vector3i(0, hu, 0))
	var y0 := 0.0
	var y1 := 1.0
	if below < 0 or shape_of(below) != S.COLUMN:
		_box(ctx, 0.15, 0, 0.15, 0.85, 0.12, 0.85)
		y0 = 0.12
	if above < 0 or shape_of(above) != S.COLUMN:
		_box(ctx, 0.12, 0.88, 0.12, 0.88, 1.0, 0.88)
		y1 = 0.88
	var sides := 10
	var r := 0.27
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(0.5 + cos(a0) * r, 0, 0.5 + sin(a0) * r)
		var p1 := Vector3(0.5 + cos(a1) * r, 0, 0.5 + sin(a1) * r)
		var n := Vector3(cos((a0 + a1) / 2.0), 0, sin((a0 + a1) / 2.0))
		_face(ctx, [p0 + Vector3(0, y0, 0), p1 + Vector3(0, y0, 0), p1 + Vector3(0, y1, 0), p0 + Vector3(0, y1, 0)], n)


static func _fence(ctx: Dictionary) -> void:
	_box(ctx, 0, 0.9, 0.44, 1, 1.0, 0.56)
	_box(ctx, 0, 0.0, 0.46, 1, 0.08, 0.54)
	for i in 5:
		var x := 0.1 + i * 0.2
		_box(ctx, x - 0.025, 0.08, 0.475, x + 0.025, 0.9, 0.525, 3)


## Cadre d'une fenêtre (dans le plan z = 0.4…0.6) et sa vitre.
static func _window(ctx: Dictionary, shape: int) -> void:
	var f := 0.04 if shape == S.BAY else 0.09
	var z0 := 0.42
	var z1 := 0.58
	_box(ctx, 0, 0, z0, f, 1, z1)
	_box(ctx, 1 - f, 0, z0, 1, 1, z1)
	_box(ctx, f, 1 - f, z0, 1 - f, 1, z1, 12)
	_box(ctx, f, 0, z0, 1 - f, f, z1, 12)
	var gl := BlocMateriaux.layer(10) # Verre
	var white := Color(1, 1, 1)
	_face(ctx, [Vector3(f, f, 0.5), Vector3(1 - f, f, 0.5), Vector3(1 - f, 1 - f, 0.5), Vector3(f, 1 - f, 0.5)], Vector3.FORWARD, gl, 1, white)
	if shape != S.BAY:
		# Croisillons et appui.
		_box(ctx, 0.48, f, 0.47, 0.52, 1 - f, 0.53, 3)
		_box(ctx, f, 0.53, 0.47, 1 - f, 0.57, 0.53, 12)
		_box(ctx, -0.03, 0, -0.08, 1.03, 0.06, z0)
	if shape == S.WINDOW_SHUTTERS:
		for s in [-1, 1]:
			var x0 := -0.5 if s < 0 else 1.0
			var x1 := 0.0 if s < 0 else 1.5
			_box(ctx, x0 + 0.02, 0.04, -0.06, x1 - 0.02, 0.96, -0.01)
			for j in 7:
				var y := 0.12 + j * 0.12
				_box(ctx, x0 + 0.06, y, -0.09, x1 - 0.06, y + 0.04, -0.06, 0)


## Porte (2 cases) : bas et haut. Ouverte, le battant pivote de 90° côté intérieur (+Z).
static func _door(ctx: Dictionary, shape: int, top: bool, open: bool) -> void:
	var z0 := 0.36
	var z1 := 0.64
	# Montants et linteau (dans le matériau choisi).
	_box(ctx, 0, 0, z0, 0.1, 1, z1)
	_box(ctx, 0.9, 0, z0, 1, 1, z1)
	if top:
		_box(ctx, 0.1, 0.9, z0, 0.9, 1, z1, 12)
	else:
		_box(ctx, 0.1, 0, z0 - 0.04, 0.9, 0.03, z1 + 0.04, 12)
	var y0 := 0.03 if not top else 0.0
	var y1 := 1.0 if not top else 0.9
	var gl := BlocMateriaux.layer(10)
	var white := Color(1, 1, 1)
	if open:
		# Battant ouvert contre le montant gauche, vers l'intérieur.
		_box(ctx, 0.1, y0, 0.6, 0.16, y1, 1.38)
		return
	_box(ctx, 0.1, y0, 0.46, 0.9, y1, 0.54, 3)
	if shape == S.DOOR_GLASS and (top or true):
		var gy0 := 0.45 if not top else 0.0
		var gy1 := 1.0 if not top else 0.78
		_face(ctx, [Vector3(0.22, gy0, 0.455), Vector3(0.78, gy0, 0.455), Vector3(0.78, gy1, 0.455), Vector3(0.22, gy1, 0.455)], Vector3.FORWARD, gl, 1, white)
		if top:
			_box(ctx, 0.48, 0.0, 0.44, 0.52, 0.78, 0.46, 0)
	else:
		# Panneaux en relief.
		var py0 := 0.15 if not top else 0.1
		var py1 := 0.9 if not top else 0.75
		_box(ctx, 0.2, py0, 0.43, 0.46, py1, 0.46, 2 | 1)
		_box(ctx, 0.54, py0, 0.43, 0.8, py1, 0.46, 2 | 1)
	if not top:
		var brass := Color(0.95, 0.8, 0.4)
		_box(ctx, 0.78, 0.92, 0.4, 0.84, 0.96, 0.46, 0, BlocMateriaux.PLAIN, 0, brass)


static func _garage(ctx: Dictionary, open: bool) -> void:
	if open:
		_box(ctx, 0, 0.86, 0.4, 1, 1, 0.6)
		return
	_box(ctx, 0, 0, 0.46, 1, 1, 0.54)
	for j in 4:
		var y := 0.24 + j * 0.25
		_box(ctx, 0, y - 0.03, 0.43, 1, y, 0.46, 12)


static func _skylight(ctx: Dictionary) -> void:
	# Cadre et vitre posés sur la pente (normale (0, 1, −1)).
	var off := Vector3(0, 0.03, -0.03)
	var a := Vector3(0.18, 0.2, 0.2) + off
	var b := Vector3(0.82, 0.2, 0.2) + off
	var c := Vector3(0.82, 0.8, 0.8) + off
	var d := Vector3(0.18, 0.8, 0.8) + off
	var n := Vector3(0, 1, -1)
	var dark := Color(0.25, 0.27, 0.3)
	_face(ctx, [a - Vector3(0.05, 0.04, 0.04), b + Vector3(0.05, -0.04, -0.04), c + Vector3(0.05, 0.04, 0.04), d + Vector3(-0.05, 0.04, 0.04)], n, BlocMateriaux.PLAIN, 0, dark)
	off = Vector3(0, 0.05, -0.05)
	_face(ctx, [a + off - Vector3(0, 0.03, 0.03), b + off - Vector3(0, 0.03, 0.03), c + off - Vector3(0, 0.03, 0.03), d + off - Vector3(0, 0.03, 0.03)], n, BlocMateriaux.layer(10), 0, Color(0.55, 0.75, 0.9))
