class_name MuseeGabarits
extends RefCounted
## Musées prêts à poser (outil « Poser un bâtiment meublé » de l'Intérieur,
## ou onglet Bâtir du menu Musée) : vrais murs en pierre, salles à thème,
## parquet Versailles dans les galeries, marbre dans le hall, mobilier du
## musée posé salle par salle (Gabarits.build_spec).
##
## Description : w × d (m), et par étage des salles [x, z, w, d, fonction]
## (rectangles dans l'emprise, façade d'entrée sur z = 0), des portes
## [x0, z0, x1, z1, genre] (un segment d'un mètre sur une cloison ou une
## façade) et des escaliers [x, z, direction]. Les cloisons sont tirées toutes
## seules le long des bords des salles ; les façades reçoivent des fenêtres
## hautes (pas de soleil direct sur les œuvres).

const KINDS := {
	"musee_village": {"name": "Petit musée d'histoire locale", "w": 14, "d": 10, "usage": "musee", "roof": "deux_pans", "budget": 450_000,
		"desc": "Un hall avec sa billetterie, une salle d'histoire, une petite boutique et des toilettes.",
		"salles": [[[0, 0, 6, 4, "hall_musee"], [6, 0, 5, 4, "boutique_musee"], [11, 0, 3, 4, "sdb"], [0, 4, 14, 6, "salle_histoire"]]],
		"portes": [[[2, 0, 3, 0, "porte_double"], [3, 0, 4, 0, "porte_double"], [6, 1, 6, 2, "passage"], [11, 2, 11, 3, "porte"], [2, 4, 3, 4, "passage"], [3, 4, 4, 4, "passage"]]],
		"stairs": [[]]},
	"musee_beaux_arts": {"name": "Musée des beaux-arts", "w": 24, "d": 16, "usage": "musee", "roof": "mansarde", "budget": 2_500_000,
		"desc": "Deux niveaux : hall, boutique, café, galerie de peinture et salle des sculptures en bas ; grande galerie, art moderne et antiquités en haut.",
		"salles": [[[0, 0, 10, 6, "hall_musee"], [10, 0, 7, 6, "boutique_musee"], [17, 0, 4, 6, "cafe_musee"], [21, 0, 3, 6, "sdb"], [0, 6, 12, 10, "galerie_peinture"], [12, 6, 12, 10, "salle_sculpture"]],
			[[0, 0, 12, 16, "galerie_peinture"], [12, 0, 12, 8, "salle_art_moderne"], [12, 8, 12, 8, "salle_antiquites"]]],
		"portes": [[[4, 0, 5, 0, "porte_double"], [5, 0, 6, 0, "porte_double"], [10, 2, 10, 3, "passage"], [17, 2, 17, 3, "passage"], [21, 3, 21, 4, "porte"],
				[5, 6, 6, 6, "arcade"], [6, 6, 7, 6, "arcade"], [12, 10, 12, 11, "arcade"], [12, 11, 12, 12, "arcade"]],
			[[12, 3, 12, 4, "arcade"], [12, 11, 12, 12, "arcade"], [17, 8, 18, 8, "arcade"], [18, 8, 19, 8, "arcade"]]],
		"stairs": [[[1, 1, 3]], []], "floors": {"galerie_peinture": "Parquet Versailles", "salle_art_moderne": "Béton ciré gris", "hall_musee": "Marbre de Carrare"}},
	"museum_nature": {"name": "Muséum d'histoire naturelle", "w": 30, "d": 18, "usage": "musee", "roof": "voute", "budget": 3_000_000,
		"desc": "Une grande galerie des dinosaures sous verrière, une salle d'histoire naturelle, un hall, une boutique, un café.",
		"salles": [[[0, 0, 10, 6, "hall_musee"], [10, 0, 4, 6, "sdb"], [14, 0, 8, 6, "boutique_musee"], [22, 0, 8, 6, "cafe_musee"], [0, 6, 20, 12, "salle_dinosaures"], [20, 6, 10, 12, "salle_nature"]]],
		"portes": [[[4, 0, 5, 0, "porte_double"], [5, 0, 6, 0, "porte_double"], [10, 3, 10, 4, "porte"], [14, 6, 15, 6, "passage"], [24, 6, 25, 6, "passage"],
			[4, 6, 5, 6, "arcade"], [5, 6, 6, 6, "arcade"], [20, 11, 20, 12, "arcade"], [20, 12, 20, 13, "arcade"]]],
		"stairs": [[]], "floors": {"salle_dinosaures": "Granit poli noir", "hall_musee": "Marbre de Carrare"}},
	"musee_sciences": {"name": "Musée des sciences et techniques", "w": 24, "d": 16, "usage": "musee", "roof": "dents_de_scie", "budget": 1_800_000,
		"desc": "Une grande halle des machines, une salle d'histoire des techniques, un hall, une boutique, un café.",
		"salles": [[[0, 0, 8, 6, "hall_musee"], [8, 0, 4, 6, "sdb"], [12, 0, 6, 6, "boutique_musee"], [18, 0, 6, 6, "cafe_musee"], [0, 6, 14, 10, "salle_sciences"], [14, 6, 10, 10, "salle_histoire"]]],
		"portes": [[[3, 0, 4, 0, "porte_double"], [4, 0, 5, 0, "porte_double"], [8, 3, 8, 4, "porte"], [13, 6, 14, 6, "passage"], [20, 6, 21, 6, "passage"],
			[3, 6, 4, 6, "passage"], [4, 6, 5, 6, "passage"], [14, 10, 14, 11, "passage"], [14, 11, 14, 12, "passage"]]],
		"stairs": [[]], "floors": {"salle_sciences": "Béton ciré gris"}},
	"musee_civilisations": {"name": "Musée des civilisations", "w": 26, "d": 16, "usage": "musee", "roof": "plat", "budget": 2_600_000,
		"desc": "Égypte, antiquités grecques et romaines, arts du monde, une salle d'exposition temporaire, un hall et une boutique.",
		"salles": [[[0, 0, 9, 6, "hall_musee"], [9, 0, 6, 6, "boutique_musee"], [15, 0, 3, 6, "sdb"], [18, 0, 8, 6, "salle_expo"],
			[0, 6, 9, 10, "salle_egypte"], [9, 6, 8, 10, "salle_antiquites"], [17, 6, 9, 10, "salle_monde"]]],
		"portes": [[[4, 0, 5, 0, "porte_double"], [5, 0, 6, 0, "porte_double"], [9, 2, 9, 3, "passage"], [15, 3, 15, 4, "porte"], [21, 6, 22, 6, "passage"],
			[4, 6, 5, 6, "arcade"], [9, 10, 9, 11, "arcade"], [17, 10, 17, 11, "arcade"]]],
		"stairs": [[]], "floors": {"salle_egypte": "Grès des Vosges", "salle_antiquites": "Marbre de Carrare", "hall_musee": "Marbre de Carrare"}},
}
const ORDER := ["musee_village", "musee_beaux_arts", "museum_nature", "musee_sciences", "musee_civilisations"]

## Murs extérieurs : pierre de taille ; toit : ardoise.
const MUR := "Pierre de taille"
const TOIT := "Ardoise"


static func _mat(name: String, fallback: int) -> int:
	var i := BlocMateriaux.index_of(name)
	return i if i >= 0 else fallback


## Spécification complète (pour Gabarits.build_spec) : murs, toit et sols résolus.
static func spec(kind: String) -> Dictionary:
	var g: Dictionary = (KINDS[kind] as Dictionary).duplicate()
	g["levels"] = levels_of(kind)
	g["wall_mat"] = _mat(MUR, 5)
	g["roof_mat"] = _mat(TOIT, 8)
	var sols := {}
	var f: Dictionary = g.get("floors", {})
	for fn in f:
		sols[fn] = _mat(String(f[fn]), -1)
	g["floors"] = sols
	return g


## Étages au format de Gabarits (enveloppe, cloisons, ouvertures, escaliers).
static func levels_of(kind: String) -> Array:
	var g: Dictionary = KINDS[kind]
	var w := int(g.w)
	var d := int(g.d)
	var out := []
	var salles: Array = g.salles
	for e in salles.size():
		var rooms: Array = [[0, 0, w, d, ""]]
		var walls: Array = []
		var seen := {}
		for r in salles[e]:
			rooms.append(r)
			var x0 := int(r[0])
			var z0 := int(r[1])
			var x1 := x0 + int(r[2])
			var z1 := z0 + int(r[3])
			for seg in [[x0, z0, x1, z0], [x0, z1, x1, z1], [x0, z0, x0, z1], [x1, z0, x1, z1]]:
				# Les bords de l'emprise sont déjà les murs de l'enveloppe.
				if (seg[0] == seg[2] and (seg[0] == 0 or seg[0] == w)) or (seg[1] == seg[3] and (seg[1] == 0 or seg[1] == d)):
					continue
				var key := str(seg)
				if not seen.has(key):
					seen[key] = true
					walls.append(seg)
		var openings: Array = (g.portes[e] as Array).duplicate()
		var taken := {}
		for o in openings:
			taken[Vector4i(int(o[0]), int(o[1]), int(o[2]), int(o[3]))] = true
		# Fenêtres hautes sur les façades, une tous les 3 m.
		for x in range(1, w - 1, 3):
			for z in [0, d]:
				var k := Vector4i(x, z, x + 1, z)
				if not taken.has(k) and not taken.has(Vector4i(x - 1, z, x, z)) and not taken.has(Vector4i(x + 1, z, x + 2, z)):
					openings.append([x, z, x + 1, z, "fenetre_haute"])
		for z2 in range(2, d - 1, 3):
			for x2 in [0, w]:
				var k2 := Vector4i(x2, z2, x2, z2 + 1)
				if not taken.has(k2):
					openings.append([x2, z2, x2, z2 + 1, "fenetre_haute"])
		out.append({"rooms": rooms, "walls": walls, "openings": openings, "stairs": (g.stairs[e] as Array) if e < (g.stairs as Array).size() else []})
	return out
