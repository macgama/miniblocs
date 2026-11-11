class_name EspacesPublics
extends RefCounted
## Places, parcs, monuments et mobilier urbain (catégorie « Espaces publics »).
##
## Même format que BuildingCatalog. Le mobilier (bancs, lampadaires, arbres…)
## n'a pas besoin d'accès à une voie : "access" est vide.

const CATEGORY := "espaces"
const RP := ["route", "chemin"]

const TYPES := {
	# --- Places et parcs -------------------------------------------------------------
	"place_pavee": {"name": "Place pavée", "w": 24, "d": 24, "access": RP, "cost": 600_000, "visiteurs": 400,
		"region": "europe", "era": "classique", "desc": "Pavés, fontaine, bancs, lampadaires et tilleuls."},
	"piazza": {"name": "Piazza à obélisque", "w": 32, "d": 32, "access": RP, "cost": 900_000, "visiteurs": 600,
		"region": "mediterranee", "era": "classique", "desc": "Grande place dallée, obélisque et deux fontaines."},
	"square": {"name": "Square", "w": 20, "d": 20, "access": RP, "cost": 220_000, "visiteurs": 150,
		"region": "europe", "era": "classique", "desc": "Pelouse entourée d'une grille, allées et kiosque."},
	"kiosque_musique": {"name": "Kiosque à musique", "w": 12, "d": 12, "access": RP, "cost": 150_000, "visiteurs": 200,
		"region": "europe", "era": "classique", "desc": "Kiosque octogonal sur un socle, toit en dôme."},
	"jardin_francais": {"name": "Jardin à la française", "w": 44, "d": 32, "access": RP, "cost": 1_200_000, "visiteurs": 500,
		"region": "europe", "era": "traditionnel", "desc": "Parterres taillés, ifs en cône, bassin rond."},
	"parc_lac": {"name": "Parc et son lac", "w": 54, "d": 42, "access": RP, "cost": 1_500_000, "visiteurs": 700,
		"region": "monde", "era": "moderne", "desc": "Lac, île, passerelle, pelouses et bosquets."},
	"pique_nique": {"name": "Aire de pique-nique", "w": 16, "d": 12, "access": RP, "cost": 40_000, "visiteurs": 60,
		"region": "monde", "era": "moderne", "desc": "Tables en bois, barbecue et arbres."},
	"skatepark": {"name": "Skatepark", "w": 22, "d": 16, "access": RP, "cost": 350_000, "visiteurs": 80,
		"region": "monde", "era": "contemporain", "desc": "Rampes, bowl et rails en béton."},
	"jardin_partage": {"name": "Jardin partagé", "w": 18, "d": 14, "access": RP, "cost": 60_000, "visiteurs": 40,
		"region": "monde", "era": "contemporain", "desc": "Potagers en bacs, cabane et compost."},
	"place_moderne": {"name": "Esplanade moderne", "w": 30, "d": 24, "access": RP, "cost": 800_000, "visiteurs": 500,
		"region": "monde", "era": "contemporain", "desc": "Dalles claires, jets d'eau au sol, bancs design."},
	# --- Monuments --------------------------------------------------------------------
	"obelisque": {"name": "Obélisque", "w": 8, "d": 8, "access": RP, "cost": 300_000, "visiteurs": 50,
		"region": "moyen_orient", "era": "antique", "desc": "Obélisque de granit sur un socle."},
	"statue_equestre": {"name": "Statue équestre", "w": 7, "d": 7, "access": RP, "cost": 200_000, "visiteurs": 40,
		"region": "europe", "era": "classique", "desc": "Cavalier en bronze sur un piédestal."},
	"arc_triomphe": {"name": "Arc de triomphe", "w": 24, "d": 12, "access": RP, "cost": 4_000_000, "visiteurs": 500,
		"region": "europe", "era": "classique", "desc": "Arc monumental en pierre."},
	"torii": {"name": "Torii", "w": 10, "d": 4, "access": RP, "cost": 80_000, "visiteurs": 30,
		"region": "asie_est", "era": "traditionnel", "desc": "Portique rouge de sanctuaire."},
	"stupa": {"name": "Stupa", "w": 12, "d": 12, "access": RP, "cost": 400_000, "visiteurs": 120,
		"region": "asie_sud", "era": "traditionnel", "desc": "Dôme blanc et flèche dorée."},
	"totem": {"name": "Mâts totémiques", "w": 6, "d": 4, "access": RP, "cost": 40_000, "visiteurs": 20,
		"region": "ameriques", "era": "traditionnel", "desc": "Mâts sculptés et peints."},
	"monument_moderne": {"name": "Sculpture moderne", "w": 8, "d": 8, "access": RP, "cost": 150_000, "visiteurs": 40,
		"region": "monde", "era": "contemporain", "desc": "Anneau d'acier poli sur une dalle."},
	# --- Mobilier urbain (sans accès) ---------------------------------------------------
	"banc": {"name": "Banc", "w": 2, "d": 1, "access": [], "cost": 600, "region": "monde", "era": "moderne",
		"desc": "Banc en bois sur pieds de fonte."},
	"lampadaire": {"name": "Lampadaire", "w": 1, "d": 1, "access": [], "cost": 1_500, "region": "monde", "era": "moderne",
		"desc": "Mât de 6 m et sa lanterne."},
	"lampadaire_ancien": {"name": "Réverbère ancien", "w": 1, "d": 1, "access": [], "cost": 2_500, "region": "europe", "era": "classique",
		"desc": "Réverbère en fonte à lanterne."},
	"lanterne_pierre": {"name": "Lanterne de pierre", "w": 1, "d": 1, "access": [], "cost": 1_200, "region": "asie_est", "era": "traditionnel",
		"desc": "Tōrō de jardin japonais."},
	"arbre": {"name": "Arbre d'alignement", "w": 2, "d": 2, "access": [], "cost": 800, "region": "monde", "era": "moderne",
		"desc": "Platane avec sa grille de pied."},
	"palmier": {"name": "Palmier", "w": 2, "d": 2, "access": [], "cost": 1_200, "region": "mediterranee", "era": "moderne",
		"desc": "Palmier dattier."},
	"cerisier": {"name": "Cerisier en fleurs", "w": 2, "d": 2, "access": [], "cost": 1_000, "region": "asie_est", "era": "traditionnel",
		"desc": "Sakura rose."},
	"fontaine_wallace": {"name": "Fontaine à boire", "w": 2, "d": 2, "access": [], "cost": 8_000, "region": "europe", "era": "classique",
		"desc": "Petite fontaine en fonte verte, quatre cariatides."},
	"abribus": {"name": "Abribus", "w": 4, "d": 2, "access": [], "cost": 9_000, "region": "monde", "era": "moderne",
		"desc": "Abri vitré avec banc et plan du réseau."},
	"poubelle": {"name": "Corbeille", "w": 1, "d": 1, "access": [], "cost": 200, "region": "monde", "era": "moderne",
		"desc": "Corbeille de rue."},
	"cabine": {"name": "Cabine téléphonique", "w": 1, "d": 1, "access": [], "cost": 3_000, "region": "europe", "era": "classique",
		"desc": "Cabine rouge à petits carreaux."},
	"colonne_morris": {"name": "Colonne d'affichage", "w": 2, "d": 2, "access": [], "cost": 5_000, "region": "europe", "era": "classique",
		"desc": "Colonne verte et ses affiches."},
	"velos": {"name": "Station de vélos", "w": 6, "d": 2, "access": [], "cost": 12_000, "region": "monde", "era": "contemporain",
		"desc": "Bornes et vélos en libre-service."},
	"terrasse": {"name": "Terrasse de café", "w": 5, "d": 5, "access": [], "cost": 4_000, "region": "monde", "era": "moderne",
		"desc": "Tables, chaises et parasols."},
	"jardiniere": {"name": "Jardinière", "w": 3, "d": 1, "access": [], "cost": 700, "region": "monde", "era": "moderne",
		"desc": "Bac à fleurs."},
	"kiosque_journaux": {"name": "Kiosque à journaux", "w": 3, "d": 3, "access": [], "cost": 25_000, "region": "europe", "era": "classique",
		"desc": "Petit kiosque vert à toit en bulbe."},
}

const PAVE := Color("a59f94")
const DALLE := Color("d8d2c4")
const GAZON := Color("6aa84f")
const EAU := Color("4a90b8")
const PIERRE := Color("c9c1ae")
const FONTE := Color("2f3b33")
const BOIS := Color("8a5a36")
const BRONZE := Color("6b5a3a")


static func entries() -> Dictionary:
	var out := {}
	for id in TYPES:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["style"] = ""
		t["espace"] = true
		out[id] = t
	return out


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"place_pavee":
			k.plate(0, 0, w, d, PAVE)
			_fountain(k, 0, 0, 3.2)
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				k.tree(c.x * (w / 2.0 - 2.5), c.y * (d / 2.0 - 2.5), 1.1, Color("5a9a45"))
				_lamp_old(k, c.x * 6.0, c.y * 6.0)
			for s in [-1.0, 1.0]:
				_bench(k, s * 7.5, 0, true)
				_bench(k, 0, s * 7.5, false)
		"piazza":
			k.plate(0, 0, w, d, DALLE)
			k.plate(0, 0, w - 6.0, d - 6.0, Color("cbbfa8"), 0.0, 0.1)
			_obelisk(k, 0, 0, 14.0)
			_fountain(k, -9.0, 0, 2.6)
			_fountain(k, 9.0, 0, 2.6)
			for i in 6:
				_lamp_old(k, -12.5 + i * 5.0, -13.0)
				_lamp_old(k, -12.5 + i * 5.0, 13.0)
		"square":
			k.plate(0, 0, w, d, PAVE)
			k.plate(0, 0, w - 2.0, d - 2.0, GAZON, 0.0, 0.12)
			# Grille basse.
			for s in [-1.0, 1.0]:
				k.box(0, 0, s * (d / 2.0 - 1.0), w - 2.0, 0.9, 0.08, FONTE)
				k.box(s * (w / 2.0 - 1.0), 0, 0, 0.08, 0.9, d - 2.0, FONTE)
			k.plate(0, 0, w - 2.0, 2.0, Color("cdbf9c"), 0.0, 0.14)
			k.plate(0, 0, 2.0, d - 2.0, Color("cdbf9c"), 0.0, 0.14)
			_kiosk(k, 0, 0, 2.8)
			for c in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]:
				k.tree(c.x, c.y, 0.9)
		"kiosque_musique":
			k.plate(0, 0, w, d, PAVE)
			_kiosk(k, 0, 0, 5.0)
			_bench(k, -4.5, 4.8, true)
			_bench(k, 4.5, 4.8, true)
		"jardin_francais":
			k.plate(0, 0, w, d, Color("d9cba3"))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var cx: float = sx * w / 4.0 + sx * 1.0
					var cz: float = sz * d / 4.0 + sz * 1.0
					k.plate(cx, cz, w / 2.0 - 6.0, d / 2.0 - 6.0, GAZON, 0.0, 0.15)
					k.box(cx, 0, cz, w / 2.0 - 6.0, 0.6, 0.6, Color("3f7d3a"))
					k.box(cx, 0, cz, 0.6, 0.6, d / 2.0 - 6.0, Color("3f7d3a"))
					for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
						k.cylinder(cx + c.x * (w / 4.0 - 3.5), 0, cz + c.y * (d / 4.0 - 3.5), 0.9, 0.0, 3.2, 6, Color("2f6b2e"))
			k.cylinder(0, 0, 0, 5.0, 5.0, 0.5, 20, PIERRE)
			k.cylinder(0, 0.5, 0, 4.6, 4.6, 0.02, 20, EAU)
			k.cylinder(0, 0.5, 0, 0.25, 0.15, 2.5, 6, Color("e8eef2"))
		"parc_lac":
			k.plate(0, 0, w, d, GAZON)
			k.cylinder(4.0, 0, 2.0, 14.0, 14.0, 0.06, 14, Color("cdbf9c"))
			k.cylinder(4.0, 0.06, 2.0, 13.0, 13.0, 0.04, 14, EAU)
			k.cylinder(7.0, 0.06, 4.0, 3.2, 2.8, 0.5, 9, GAZON)
			k.tree(7.0, 4.0, 1.0)
			k.box(-3.5, 0.5, 2.0, 8.0, 0.25, 1.6, BOIS)
			for p in [Vector2(-22, -16), Vector2(-18, -12), Vector2(-23, 8), Vector2(-17, 14), Vector2(20, -15), Vector2(23, -10),
					Vector2(-8, -17), Vector2(15, 17), Vector2(21, 15), Vector2(-21, 17), Vector2(24, 0)]:
				k.tree(p.x, p.y, 1.2)
			k.plate(-20.0, 0, 2.0, d - 2.0, Color("cdbf9c"), 0.0, 0.1)
			for i in 3:
				_bench(k, -18.6, -12.0 + i * 12.0, false)
		"pique_nique":
			k.plate(0, 0, w, d, GAZON)
			for p in [Vector2(-4, -2), Vector2(3, -2), Vector2(-1, 3)]:
				k.box(p.x, 0.7, p.y, 2.2, 0.08, 0.9, BOIS)
				k.box(p.x, 0.4, p.y - 0.8, 2.2, 0.06, 0.35, BOIS)
				k.box(p.x, 0.4, p.y + 0.8, 2.2, 0.06, 0.35, BOIS)
				k.box(p.x, 0, p.y, 0.15, 0.7, 0.15, BOIS)
			k.box(6.0, 0, 3.0, 1.0, 0.8, 0.6, Color("70706a"))
			for p in [Vector2(-6, -4), Vector2(6, -4), Vector2(-6, 4)]:
				k.tree(p.x, p.y, 1.0)
		"skatepark":
			k.plate(0, 0, w, d, Color("c4c0b6"))
			k.box(-7.0, 0, 0, 5.0, 1.5, 10.0, Color("b0aca2"))
			k.box(7.0, 0, 0, 5.0, 2.0, 10.0, Color("b0aca2"))
			k.cylinder(0, -0.01, 3.0, 3.5, 3.5, 0.05, 14, Color("8e8a82"))
			k.box(0, 0.4, -4.0, 6.0, 0.08, 0.08, Color("7d8590"))
			k.box(0, 0, -4.0, 0.08, 0.4, 0.08, Color("7d8590"))
			k.box(0, 0, d / 2.0 - 0.6, w, 1.2, 0.15, Color("e76f51"))
		"jardin_partage":
			k.plate(0, 0, w, d, Color("a68a64"))
			for i in 3:
				for j in 2:
					var cx := -5.0 + i * 5.0
					var cz := -3.0 + j * 5.0
					k.box(cx, 0, cz, 3.5, 0.5, 2.0, BOIS)
					k.box(cx, 0.5, cz, 3.2, 0.25, 1.7, Color("5a8a3a"))
			k.box(7.0, 0, 4.0, 2.5, 2.2, 2.5, Color("9b7653"))
			k.gable(7.0, 2.2, 4.0, 3.0, 3.0, 1.0, Color("6b4a33"))
		"place_moderne":
			k.plate(0, 0, w, d, Color("e4e0d6"))
			for i in 5:
				for j in 3:
					k.cylinder(-8.0 + i * 4.0, 0.05, -4.0 + j * 4.0, 0.15, 0.05, 1.2 + float((i + j) % 3) * 0.6, 5, Color(0.75, 0.9, 1.0))
			for i in 4:
				k.box(-10.5 + i * 7.0, 0, 9.0, 3.0, 0.45, 0.8, Color("efefef"))
			for c in [Vector2(-12, -9), Vector2(12, -9), Vector2(-12, 9), Vector2(12, 9)]:
				k.tree(c.x, c.y, 0.9)
		"obelisque":
			k.plate(0, 0, w, d, DALLE)
			_obelisk(k, 0, 0, 16.0)
		"statue_equestre":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0, 2.6, 3.0, 4.0, PIERRE)
			k.box(0, 3.0, 0, 0.9, 1.3, 2.4, BRONZE)
			for c in [Vector2(-0.3, -0.9), Vector2(0.3, -0.9), Vector2(-0.3, 0.9), Vector2(0.3, 0.9)]:
				k.box(c.x, 3.0, c.y, 0.18, 1.0, 0.18, BRONZE)
			k.box(0, 4.1, -1.3, 0.5, 1.0, 0.7, BRONZE)
			k.box(0, 4.3, 0.1, 0.5, 1.2, 0.5, BRONZE)
			k.box(0, 5.5, 0.1, 0.3, 0.35, 0.3, BRONZE)
		"arc_triomphe":
			k.plate(0, 0, w, d, PAVE)
			k.box(-7.5, 0, 0, 7.0, 18.0, 8.0, PIERRE)
			k.box(7.5, 0, 0, 7.0, 18.0, 8.0, PIERRE)
			k.box(0, 12.0, 0, 8.0, 6.0, 8.0, PIERRE)
			k.box(0, 18.0, 0, 22.0, 3.0, 8.4, Color("bdb4a0"))
			k.box(0, 15.0, -4.05, 21.0, 0.6, 0.1, Color("a89f8a"))
		"torii":
			var red := Color("c8342b")
			k.cylinder(-3.2, 0, 0, 0.35, 0.3, 6.0, 8, red)
			k.cylinder(3.2, 0, 0, 0.35, 0.3, 6.0, 8, red)
			k.box(0, 4.6, 0, 7.6, 0.5, 0.5, red)
			k.box(0, 5.9, 0, 9.4, 0.5, 0.8, Color("2a2a2a"))
			k.box(0, 5.4, 0, 8.8, 0.5, 0.6, red)
		"stupa":
			k.plate(0, 0, w, d, DALLE)
			k.box(0, 0, 0, 10.0, 1.2, 10.0, Color("f2efe8"))
			k.box(0, 1.2, 0, 8.0, 0.8, 8.0, Color("f2efe8"))
			k.dome(0, 2.0, 0, 3.8, 3.6, Color("fafafa"), 16)
			k.box(0, 5.6, 0, 1.6, 0.8, 1.6, Color("d9a520"))
			k.lathe(0, 6.4, 0, [Vector2(0.8, 0), Vector2(0.5, 1.5), Vector2(0.25, 3.0), Vector2(0, 4.0)], 8, Color("d9a520"))
		"totem":
			var cols := [Color("b5523b"), Color("2a6f8a"), Color("e9c46a"), Color("2a2a2a")]
			for m in 2:
				var x := -1.5 + m * 3.0
				for i in 4:
					k.box(x, i * 1.6, 0, 1.0 - i * 0.05, 1.6, 1.0, cols[(i + m) % 4])
				k.box(x, 4.4, 0, 3.0, 0.3, 0.6, cols[(m + 2) % 4])
		"monument_moderne":
			k.plate(0, 0, w, d, Color("e4e0d6"))
			for i in 16:
				var a := TAU * i / 16.0
				k.box(cos(a) * 2.6, 3.0 + sin(a) * 2.6, 0, 1.1, 1.1, 0.6, Color("c9d1d9"))
			k.box(0, 0, 0, 1.5, 0.4, 1.5, Color("9aa3ad"))
		"banc":
			_bench(k, 0, 0, true)
		"lampadaire":
			k.cylinder(0, 0, 0, 0.09, 0.07, 6.0, 6, Color("5f666e"))
			k.box(0.35, 5.9, 0, 0.9, 0.12, 0.3, Color("5f666e"))
			k.box(0.6, 5.8, 0, 0.5, 0.1, 0.25, Color("fff3c4"))
		"lampadaire_ancien":
			_lamp_old(k, 0, 0)
		"lanterne_pierre":
			k.cylinder(0, 0, 0, 0.35, 0.3, 0.3, 6, PIERRE)
			k.cylinder(0, 0.3, 0, 0.12, 0.12, 0.7, 6, PIERRE)
			k.box(0, 1.0, 0, 0.5, 0.4, 0.5, Color("e8dfc8"))
			k.pyramid(0, 1.4, 0, 0.9, 0.9, 0.4, PIERRE)
		"arbre":
			k.plate(0, 0, 1.4, 1.4, FONTE, 0.0, 0.04)
			k.tree(0, 0, 1.4, Color("4f8f3f"))
		"palmier":
			k.cylinder(0, 0, 0, 0.22, 0.16, 6.5, 6, Color("8a6a46"))
			for i in 7:
				var a := TAU * i / 7.0
				var tip := Vector3(cos(a) * 2.4, 5.6, sin(a) * 2.4)
				k.tri(Vector3(0, 6.6, 0), tip + Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5), tip - Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5), Vector3.UP, Color("3e8a3a"))
				k.tri(Vector3(0, 6.6, 0), tip - Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5), tip + Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5), Vector3.DOWN, Color("2f6b2e"))
		"cerisier":
			k.cylinder(0, 0, 0, 0.2, 0.15, 1.8, 5, Color("5a3a2a"))
			k.dome(0, 1.6, 0, 1.6, 1.8, Color("f2a7c3"), 8)
		"fontaine_wallace":
			k.cylinder(0, 0, 0, 0.5, 0.45, 0.4, 8, FONTE)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				k.cylinder(cos(a) * 0.25, 0.4, sin(a) * 0.25, 0.08, 0.08, 1.2, 5, FONTE)
			k.dome(0, 1.6, 0, 0.55, 0.5, FONTE, 8)
		"abribus":
			k.plate(0, 0, w, d, Color("b9b6ae"), 0.0, 0.05)
			k.box(0, 0, 0.8, 3.8, 2.4, 0.06, Color(0.6, 0.78, 0.86))
			k.box(-1.9, 0, 0, 0.06, 2.4, 1.6, Color(0.6, 0.78, 0.86))
			k.box(0, 2.4, 0.1, 4.0, 0.12, 1.8, Color("5f666e"))
			k.box(0, 0.45, 0.55, 2.8, 0.06, 0.4, Color("7d8590"))
			k.box(1.75, 0, 0.75, 0.5, 2.2, 0.15, Color("2a6fdb"))
		"poubelle":
			k.cylinder(0, 0, 0, 0.25, 0.28, 0.9, 8, Color("3c6e47"))
		"cabine":
			k.box(0, 0, 0, 0.95, 2.5, 0.95, Color("c8342b"))
			k.box(0, 2.5, 0, 1.0, 0.2, 1.0, Color("a82a22"))
			k.box(0, 0.9, -0.48, 0.6, 1.3, 0.04, Color(0.7, 0.85, 0.9))
		"colonne_morris":
			k.cylinder(0, 0, 0, 0.6, 0.6, 2.8, 10, Color("2f5d3a"))
			k.cylinder(0, 0.4, 0, 0.62, 0.62, 2.0, 10, Color("e8d9b0"))
			k.dome(0, 2.8, 0, 0.7, 0.7, Color("2f5d3a"), 10)
		"velos":
			k.plate(0, 0, w, d, Color("b9b6ae"), 0.0, 0.05)
			for i in 5:
				var x := -2.4 + i * 1.2
				k.box(x, 0, 0.4, 0.2, 1.1, 0.2, Color("7d8590"))
				k.cylinder(x, 0.35, -0.2, 0.33, 0.33, 0.06, 8, Color("2a2a2a"))
				k.box(x, 0.45, -0.3, 0.06, 0.5, 1.0, Color("6bb84a"))
		"terrasse":
			k.plate(0, 0, w, d, Color("a68a64"), 0.0, 0.06)
			for p in [Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(-1.2, 1.2), Vector2(1.2, 1.2)]:
				k.cylinder(p.x, 0, p.y, 0.4, 0.4, 0.75, 8, Color("e9e2d4"))
				k.cylinder(p.x, 0.75, p.y, 0.03, 0.03, 1.5, 4, Color("cccccc"))
				k.cylinder(p.x, 2.0, p.y, 1.1, 0.0, 0.4, 8, Color("c8342b") if p.x < 0 else Color("f2f2f2"))
		"jardiniere":
			k.box(0, 0, 0, 2.8, 0.6, 0.8, Color("8e8a82"))
			k.box(0, 0.6, 0, 2.6, 0.35, 0.6, Color("e76fa1"))
		"kiosque_journaux":
			k.box(0, 0, 0, 2.4, 2.4, 2.4, Color("2f5d3a"))
			k.box(0, 0.9, -1.22, 1.8, 1.0, 0.05, Color("e8d9b0"))
			k.lathe(0, 2.4, 0, [Vector2(1.6, 0), Vector2(1.2, 0.8), Vector2(0.3, 1.5), Vector2(0, 1.8)], 8, Color("2f5d3a"))
		_:
			k.box(0, 0, 0, w * 0.8, 1.0, d * 0.8, PIERRE)


static func _bench(k: BlocMesh, x: float, z: float, along_x: bool) -> void:
	var sx := 1.8 if along_x else 0.5
	var sz := 0.5 if along_x else 1.8
	k.box(x, 0.42, z, sx, 0.08, sz, BOIS)
	if along_x:
		k.box(x, 0.5, z + 0.22, 1.8, 0.4, 0.06, BOIS)
		k.box(x - 0.8, 0, z, 0.08, 0.42, 0.45, FONTE)
		k.box(x + 0.8, 0, z, 0.08, 0.42, 0.45, FONTE)
	else:
		k.box(x + 0.22, 0.5, z, 0.06, 0.4, 1.8, BOIS)
		k.box(x, 0, z - 0.8, 0.45, 0.42, 0.08, FONTE)
		k.box(x, 0, z + 0.8, 0.45, 0.42, 0.08, FONTE)


static func _lamp_old(k: BlocMesh, x: float, z: float) -> void:
	k.cylinder(x, 0, z, 0.18, 0.14, 0.6, 6, FONTE)
	k.cylinder(x, 0.6, z, 0.07, 0.06, 3.4, 6, FONTE)
	k.box(x, 4.0, z, 0.45, 0.6, 0.45, Color("fff0b8"))
	k.pyramid(x, 4.6, z, 0.6, 0.6, 0.35, FONTE)


static func _fountain(k: BlocMesh, x: float, z: float, r: float) -> void:
	k.cylinder(x, 0, z, r, r, 0.6, 16, PIERRE)
	k.cylinder(x, 0.6, z, r - 0.3, r - 0.3, 0.02, 16, EAU)
	k.cylinder(x, 0.6, z, 0.35, 0.3, 1.4, 8, PIERRE)
	k.cylinder(x, 2.0, z, 1.0, 1.0, 0.25, 12, PIERRE)
	k.cylinder(x, 2.25, z, 0.12, 0.05, 1.0, 5, Color(0.8, 0.92, 1.0))


static func _obelisk(k: BlocMesh, x: float, z: float, h: float) -> void:
	k.box(x, 0, z, 3.6, 1.4, 3.6, PIERRE)
	k.box(x, 1.4, z, 2.6, 1.0, 2.6, Color("bdb4a0"))
	k.lathe(x, 2.4, z, [Vector2(1.1, 0), Vector2(0.75, h)], 4, Color("c7a985"))
	k.pyramid(x, 2.4 + h, z, 1.06, 1.06, 1.0, Color("d9a520"))


static func _kiosk(k: BlocMesh, x: float, z: float, r: float) -> void:
	k.cylinder(x, 0, z, r, r, 1.0, 8, PIERRE)
	for i in 8:
		var a := TAU * i / 8.0
		k.cylinder(x + cos(a) * (r - 0.3), 1.0, z + sin(a) * (r - 0.3), 0.08, 0.08, 2.8, 5, FONTE)
	k.cylinder(x, 3.8, z, r + 0.3, r + 0.3, 0.2, 8, Color("2f5d3a"))
	k.lathe(x, 4.0, z, [Vector2(r + 0.3, 0), Vector2(r * 0.5, 1.4), Vector2(0, 2.2)], 8, Color("2f5d3a"))
