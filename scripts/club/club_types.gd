class_name ClubTypes
extends RefCounted
## Bâtiments du club de sport (catégorie Sport du panneau Construire) :
## salles où jouent le basket et le handball, patinoire du hockey, centre de
## tennis, centre de formation des jeunes.
##
## Même format que BuildingCatalog, plus un champ "club_sport" :
## {"sports": [sports dont on peut y jouer les matchs], "places": n}.
## Pour les matchs (Matchs, Stades.pelouse_monde) : "bol" (demi-longueur et
## demi-largeur de l'aire de jeu et de ses abords), "tribune" (profondeur,
## hauteur), "pelouse" (centre de l'aire dans le repère du bâtiment).
## Les toits sont des charpentes ouvertes : on voit le match d'en haut.

const CATEGORY := "sport"
const ROAD := ["route"]

const TYPES := {
	"salle_omnisports": {"name": "Salle omnisports (2 500 places)", "w": 66, "d": 48, "access": ROAD, "emplois": 12, "cost": 9_500_000,
		"role": "gymnase", "club_sport": {"sports": ["basket", "handball"], "places": 2500},
		"bol": Vector2(22.0, 12.0), "tribune": Vector2(7.0, 5.0), "pelouse": Vector2(0, 2),
		"metiers": [["coach", 8], ["agent_public", 3], ["cadre", 1]],
		"desc": "Parquet de 44 × 24 m, tribunes sur les quatre côtés, charpente métallique. Basket et handball (Club de sport, Maj+B), sport en salle pour les habitants."},
	"palais_sports": {"name": "Palais des sports (6 000 places)", "w": 100, "d": 78, "access": ROAD, "emplois": 35, "cost": 32_000_000,
		"role": "gymnase", "club_sport": {"sports": ["basket", "handball"], "places": 6000},
		"bol": Vector2(24.0, 14.0), "tribune": Vector2(16.0, 12.0), "pelouse": Vector2(0, 3),
		"metiers": [["coach", 15], ["agent_public", 12], ["serveur", 6], ["cadre", 2]],
		"desc": "Grande salle à gradins pour les clubs de l'élite du basket et du handball. Écran géant au-dessus du parquet."},
	"patinoire_hockey": {"name": "Patinoire de hockey (4 000 places)", "w": 86, "d": 58, "access": ROAD, "emplois": 18, "cost": 24_000_000,
		"role": "patinoire", "club_sport": {"sports": ["hockey"], "places": 4000},
		"bol": Vector2(31.0, 16.0), "tribune": Vector2(8.0, 6.0), "pelouse": Vector2(0, 2),
		"metiers": [["coach", 8], ["agent_public", 8], ["cadre", 2]],
		"desc": "Piste de glace de 60 × 30 m entourée de balustrades, tribunes, machine à surfacer. Matchs de hockey (Club de sport) et patinage libre."},
	"centre_tennis": {"name": "Centre de tennis (court central de 1 800 places)", "w": 76, "d": 56, "access": ROAD, "emplois": 10, "cost": 6_500_000,
		"role": "tennis", "club_sport": {"sports": ["tennis"], "places": 1800},
		"bol": Vector2(14.0, 8.0), "tribune": Vector2(6.0, 4.0), "pelouse": Vector2(0, 4),
		"metiers": [["coach", 7], ["agent_public", 2], ["cadre", 1]],
		"desc": "Un court central en terre battue avec tribunes, quatre courts en dur et un club-house. Championnat par équipes (Club de sport)."},
	"centre_formation": {"name": "Centre de formation des jeunes", "w": 72, "d": 54, "access": ROAD, "emplois": 14, "cost": 4_500_000,
		"role": "centre_formation",
		"metiers": [["coach", 10], ["agent_public", 3], ["cadre", 1]],
		"desc": "Internat, salles de cours, terrain d'entraînement et salle de musculation. Permet aux clubs du joueur d'ouvrir un vrai centre de formation (Club de sport → Formation)."},
}
const ORDER := ["salle_omnisports", "palais_sports", "patinoire_hockey", "centre_tennis", "centre_formation"]


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["region"] = "monde"
		t["era"] = "contemporain"
		t["style"] = ""
		t["visiteurs"] = int(t.get("club_sport", {}).get("places", 120))
		t["club_bat"] = true
		out[id] = t
	return out


# --- Modèles (façade et entrée vers −Z, côté route) ---------------------------------------------

const BETON := Color("bdb9b0")
const BETON_F := Color("8f8b83")
const ENROBE := Color("5a5d62")
const METAL := Color("8d949b")
const METAL_F := Color("5f666d")
const VITRE := Color("3b5a73")
const PARQUET := Color("c89a5e")
const PARQUET_F := Color("b4864c")
const GLACE := Color("eef6fb")
const BLANC := Color("f2f2ee")
const ROUGE := Color("c0392b")
const BLEU := Color("2f6fb0")
const VERT := Color("3f8f4a")
const TERRE := Color("c0653a")
const DUR := Color("3b6ea5")
const SIEGE := Color("4a5560")
const SIEGE_2 := Color("2f6fb0")
const HERBE := Color("6fa05a")
const BRIQUE := Color("a65a3f")
const TUILE := Color("8a4a36")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	k.plate(0, 0, w, d, ENROBE)
	match id:
		"salle_omnisports":
			_salle(k, w, d, t, PARQUET, 11.0, SIEGE_2)
			_terrain_lignes(k, Vector2(0, 2), Vector2(20, 10), BLEU)
		"palais_sports":
			_salle(k, w, d, t, PARQUET_F, 22.0, ROUGE)
			_terrain_lignes(k, Vector2(0, 3), Vector2(20, 10), ROUGE)
			# Écran géant suspendu au-dessus du parquet.
			k.box(0, 15.0, 3.0, 5.0, 3.0, 5.0, Color("1d1d22"))
		"patinoire_hockey":
			_salle(k, w, d, t, GLACE, 13.0, SIEGE)
			# Balustrades blanches et lignes rouge et bleues de la glace.
			var c := Vector2(0, 2)
			k.box(c.x, 0.0, c.y - 15.2, 60.0, 1.1, 0.25, BLANC)
			k.box(c.x, 0.0, c.y + 15.2, 60.0, 1.1, 0.25, BLANC)
			k.box(c.x - 30.1, 0.0, c.y, 0.25, 1.1, 30.6, BLANC)
			k.box(c.x + 30.1, 0.0, c.y, 0.25, 1.1, 30.6, BLANC)
			k.plate(c.x, c.y, 0.4, 30.0, ROUGE, 0.08, 0.02)
			k.plate(c.x - 9.0, c.y, 0.4, 30.0, BLEU, 0.08, 0.02)
			k.plate(c.x + 9.0, c.y, 0.4, 30.0, BLEU, 0.08, 0.02)
			k.plate(c.x - 26.0, c.y, 0.15, 28.0, ROUGE, 0.08, 0.02)
			k.plate(c.x + 26.0, c.y, 0.15, 28.0, ROUGE, 0.08, 0.02)
			# Cages.
			k.box(c.x - 26.6, 0.0, c.y, 1.0, 1.2, 1.8, ROUGE)
			k.box(c.x + 26.6, 0.0, c.y, 1.0, 1.2, 1.8, ROUGE)
			# Machine à surfacer garée dans un coin.
			k.box(c.x + 27.0, 0.0, c.y + 12.5, 2.0, 1.8, 3.6, BLEU)
		"centre_tennis":
			var c := Vector2(0, 4)
			# Court central en terre battue et ses tribunes (deux côtés longs, deux bouts).
			k.plate(c.x, c.y, 34.0, 18.0, TERRE, 0.08, 0.06)
			_terrain_lignes(k, c, Vector2(11.9, 5.5), BLANC)
			k.box(c.x, 0.0, c.y, 0.1, 1.0, 12.0, BLANC)
			_gradins(k, c, Vector2(14.0, 8.0), Vector2(6.0, 4.0), SIEGE_2)
			# Quatre courts en dur sur les côtés, grillagés.
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var cx: float = sx * 30.0
					var cz: float = c.y + sz * 11.0
					k.plate(cx, cz, 14.0, 20.0, Color("4c7f5a"), 0.08, 0.04)
					k.plate(cx, cz, 10.0, 22.0, DUR, 0.12, 0.02)
					k.box(cx, 0.0, cz, 10.6, 0.9, 0.08, BLANC)
			# Club-house devant (côté route).
			k.box(0, 0, -d * 0.5 + 5.0, 22.0, 4.2, 7.0, Color("e6dccb"))
			k.box(0, 4.2, -d * 0.5 + 5.0, 23.0, 0.5, 8.0, TUILE)
			k.windows_row(0, -d * 0.5 + 1.45, 18.0, 1.4, 6, 1.6, 1.6, VITRE)
		"centre_formation":
			# Internat (bâtiment en L, trois étages) et salle de musculation.
			k.box(-w * 0.5 + 12.0, 0.0, -d * 0.5 + 8.0, 20.0, 10.0, 12.0, Color("e8e2d6"))
			k.box(-w * 0.5 + 12.0, 10.0, -d * 0.5 + 8.0, 20.6, 0.5, 12.6, METAL_F)
			k.window_bands(-w * 0.5 + 12.0, -d * 0.5 + 8.0, 20.0, 12.0, 1.2, 3, 3.2, VITRE)
			k.box(-w * 0.5 + 8.0, 0.0, 6.0, 12.0, 7.0, 18.0, Color("d9d1c2"))
			k.window_bands(-w * 0.5 + 8.0, 6.0, 12.0, 18.0, 1.2, 2, 3.2, VITRE)
			k.box(14.0, 0.0, -d * 0.5 + 7.0, 18.0, 6.0, 10.0, Color("c8d0d6"))
			k.box(14.0, 6.0, -d * 0.5 + 7.0, 18.6, 0.4, 10.6, METAL)
			k.windows_row(14.0, -d * 0.5 + 1.95, 16.0, 1.6, 5, 2.4, 2.4, VITRE)
			# Terrain d'entraînement synthétique et piste.
			k.plate(10.0, 9.0, 44.0, 32.0, Color("b5503a"), 0.08, 0.05)
			k.plate(10.0, 9.0, 40.0, 28.0, Color("3f8f4a"), 0.13, 0.03)
			_terrain_lignes(k, Vector2(10.0, 9.0), Vector2(19.0, 13.0), BLANC)
			k.box(10.0 - 19.4, 0.0, 9.0, 0.3, 2.2, 6.0, BLANC)
			k.box(10.0 + 19.4, 0.0, 9.0, 0.3, 2.2, 6.0, BLANC)
			for i in 5:
				k.tree(-32.0 + i * 4.5, d * 0.5 - 1.5, 0.9)
			# Mâts de drapeaux à l'entrée.
			for i in 3:
				k.box(-6.0 + i * 3.0, 0.0, -d * 0.5 + 1.2, 0.15, 7.0, 0.15, METAL)
				k.box(-6.0 + i * 3.0 + 0.7, 5.6, -d * 0.5 + 1.2, 1.4, 0.9, 0.05, [ROUGE, BLANC, BLEU][i])


## Salle à gradins : aire de jeu, tribunes sur les quatre côtés, murs vitrés,
## charpente ouverte (poutres) et hall d'entrée côté route.
static func _salle(k: BlocMesh, w: float, d: float, t: Dictionary, sol: Color, haut: float, siege: Color) -> void:
	var c: Vector2 = t.pelouse
	var bol: Vector2 = t.bol
	var trib: Vector2 = t.tribune
	k.plate(c.x, c.y, bol.x * 2.0, bol.y * 2.0, sol, 0.08, 0.06)
	_gradins(k, c, bol, trib, siege)
	# Murs bas vitrés tout autour.
	var mx := bol.x + trib.x + 1.5
	var mz := bol.y + trib.x + 1.5
	for s in [-1.0, 1.0]:
		k.box(c.x, 0.0, c.y + s * mz, mx * 2.0, haut * 0.55, 0.4, BETON)
		k.box(c.x, haut * 0.55, c.y + s * mz, mx * 2.0, haut * 0.3, 0.25, VITRE)
		k.box(c.x + s * mx, 0.0, c.y, 0.4, haut * 0.55, mz * 2.0, BETON)
		k.box(c.x + s * mx, haut * 0.55, c.y, 0.25, haut * 0.3, mz * 2.0, VITRE)
	# Ceinture de toit et poutres (on voit le terrain entre elles).
	var y := haut * 0.85
	for s in [-1.0, 1.0]:
		k.box(c.x, y, c.y + s * mz, mx * 2.0 + 0.8, 1.2, 1.6, METAL_F)
		k.box(c.x + s * mx, y, c.y, 1.6, 1.2, mz * 2.0, METAL_F)
	var n := int(mx * 2.0 / 9.0)
	for i in n + 1:
		var x := c.x - mx + i * (mx * 2.0 / maxf(n, 1))
		k.box(x, y + 0.2, c.y, 0.5, 0.8, mz * 2.0, METAL)
	# Hall d'entrée.
	k.box(c.x, 0.0, -d * 0.5 + 3.5, minf(w * 0.4, 30.0), 6.0, 5.0, BETON_F)
	k.box(c.x, 0.0, -d * 0.5 + 0.95, minf(w * 0.3, 22.0), 4.0, 0.15, VITRE)
	k.box(c.x, 6.0, -d * 0.5 + 3.5, minf(w * 0.4, 30.0) + 1.0, 0.5, 6.0, METAL_F)


## Gradins en escalier sur les quatre côtés d'une aire.
static func _gradins(k: BlocMesh, c: Vector2, bol: Vector2, trib: Vector2, siege: Color) -> void:
	var rangs := clampi(int(trib.x / 1.4), 3, 12)
	var pas := trib.x / rangs
	var hp := trib.y / rangs
	for r in rangs:
		var off := 1.2 + r * pas
		var h := (r + 1) * hp
		var col := siege if r % 2 == 0 else siege.darkened(0.15)
		k.box(c.x, 0.0, c.y - (bol.y + off + pas * 0.5), (bol.x + off) * 2.0, h, pas, col)
		k.box(c.x, 0.0, c.y + (bol.y + off + pas * 0.5), (bol.x + off) * 2.0, h, pas, col)
		k.box(c.x - (bol.x + off + pas * 0.5), 0.0, c.y, pas, h, (bol.y + off) * 2.0, col)
		k.box(c.x + (bol.x + off + pas * 0.5), 0.0, c.y, pas, h, (bol.y + off) * 2.0, col)


## Lignes de terrain : contour et ligne médiane.
static func _terrain_lignes(k: BlocMesh, c: Vector2, demi: Vector2, col: Color) -> void:
	var e := 0.12
	k.plate(c.x, c.y - demi.y, demi.x * 2.0, e, col, 0.14, 0.01)
	k.plate(c.x, c.y + demi.y, demi.x * 2.0, e, col, 0.14, 0.01)
	k.plate(c.x - demi.x, c.y, e, demi.y * 2.0, col, 0.14, 0.01)
	k.plate(c.x + demi.x, c.y, e, demi.y * 2.0, col, 0.14, 0.01)
	k.plate(c.x, c.y, e, demi.y * 2.0, col, 0.14, 0.01)
