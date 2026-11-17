class_name ExpeditionsVisuels
extends RefCounted
## Modèle low-poly de la « Société des explorateurs » : un hôtel particulier en
## pierre blonde, un fronton, une coupole d'observatoire et un grand globe
## terrestre sur le toit, des caisses de voyage devant la porte.

const PIERRE := Color("d9c9a3")
const PIERRE_F := Color("b8a57c")
const TOIT := Color("5b6670")
const CUIVRE := Color("4f9a86")
const VITRE := Color("33495e")
const BOIS := Color("7a5232")
const BOIS_C := Color("a87a4e")
const OCEAN := Color("2f6fa8")
const TERRES := Color("7fae4f")
const OR := Color("d4a62a")


static func build(k: BlocMesh, _id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	k.plate(0, 0, w, d, Color("a09a8a"))
	# Corps du bâtiment : deux niveaux et un attique.
	k.box(0, 0, 1.0, 18.0, 8.0, 11.0, PIERRE)
	k.box(0, 8.0, 1.0, 18.4, 0.5, 11.4, PIERRE_F)
	k.hip(0, 8.5, 1.0, 18.4, 11.4, 3.0, TOIT)
	# Fenêtres hautes et porte à fronton.
	k.windows_row(0, -4.52, 16.0, 1.4, 5, 1.4, 2.4, VITRE)
	k.windows_row(0, -4.52, 16.0, 5.0, 5, 1.4, 2.2, VITRE)
	k.box(0, 0, -4.55, 2.4, 3.2, 0.1, BOIS)
	k.box(0, 3.2, -4.7, 3.6, 0.4, 0.5, PIERRE_F)
	k.gable(0, 3.6, -4.7, 3.8, 0.6, 1.0, PIERRE_F)
	for s in [-1.0, 1.0]:
		k.cylinder(1.6 * s, 0, -5.2, 0.25, 0.25, 3.2, 8, PIERRE)
	# Coupole d'observatoire (cuivre vert-de-gris) à gauche.
	k.cylinder(-5.5, 10.5, 1.5, 2.2, 2.2, 1.0, 12, PIERRE_F)
	k.dome(-5.5, 11.5, 1.5, 2.2, 2.0, CUIVRE)
	# Le grand globe sur son socle, à droite.
	k.box(5.0, 10.5, 1.5, 1.6, 1.0, 1.6, PIERRE_F)
	k.cylinder(5.0, 11.5, 1.5, 0.15, 0.15, 0.6, 6, OR)
	k.lathe(5.0, 12.0, 1.5, [Vector2(0.0, 0.0), Vector2(1.1, 0.35), Vector2(1.6, 1.1), Vector2(1.75, 1.9), Vector2(1.6, 2.7), Vector2(1.1, 3.45), Vector2(0.0, 3.8)], 14, OCEAN)
	k.box(4.6, 13.4, 0.0, 1.4, 1.0, 0.25, TERRES)
	k.box(5.9, 12.8, 0.2, 0.9, 1.2, 0.25, TERRES)
	k.cylinder(5.0, 11.8, 1.5, 2.0, 2.0, 0.12, 16, OR)
	# Caisses de voyage, malles et une longue-vue devant l'entrée.
	k.box(-6.0, 0, -6.2, 1.6, 1.0, 1.0, BOIS_C)
	k.box(-6.3, 1.0, -6.2, 1.0, 0.7, 0.8, BOIS)
	k.box(-4.2, 0, -6.6, 1.2, 0.8, 0.8, BOIS)
	k.box(6.5, 0, -6.4, 1.8, 0.9, 1.0, BOIS_C)
	k.cylinder(4.4, 0, -6.6, 0.06, 0.06, 1.3, 5, BOIS)
	k.cylinder(4.4, 1.3, -6.6, 0.12, 0.16, 0.9, 6, OR)
	# Mât et oriflamme.
	k.cylinder(8.6, 0, -5.8, 0.08, 0.08, 6.0, 6, Color("7d7d7d"))
	k.box(9.2, 5.0, -5.8, 1.2, 0.8, 0.05, Color("b8322a"))
	for s in [-1.0, 1.0]:
		k.tree(9.8 * s, 6.5, 1.1)
