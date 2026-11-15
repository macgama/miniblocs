class_name SaisonsTypes
extends RefCounted
## Bâtiments des saisons et des risques naturels (catégorie « Services publics »
## du panneau Construire) :
## - Centre technique municipal : garage des chasse-neige (saleuses) et dôme de
##   sel. Les engins partent dès qu'il y a de la neige sur les routes.
## - Bassin de rétention : stocke l'eau des pluies d'orage et des crues ; la
##   rivière monte moins haut dans les 3 km autour.
## - Station météo : prévisions sur 7 jours au lieu de 3 (panneau Saisons).
##
## Même format que BuildingCatalog, plus un champ "saisons" qui dit le rôle :
## "deneigement" (engins, sel_t), "retention" (rayon, baisse), "meteo".

const CATEGORY := "services"
const ROAD := ["route"]

const TYPES := {
	"centre_technique": {"name": "Centre technique municipal (déneigement)", "w": 34, "d": 26, "access": ROAD,
		"emplois": 10, "cost": 1_400_000,
		"saisons": {"role": "deneigement", "engins": 2, "sel_t": 150.0},
		"metiers": [["chauffeur", 4], ["conducteur_engins", 2], ["mecanicien", 1], ["agent_public", 3]],
		"desc": "Garage de 2 chasse-neige saleuses et dôme de 150 t de sel. Les engins partent dès que la neige tient sur les routes, les grands axes d'abord."},
	"bassin_retention": {"name": "Bassin de rétention des crues", "w": 60, "d": 40, "access": ROAD, "emplois": 1,
		"cost": 2_200_000,
		"saisons": {"role": "retention", "rayon": 3000.0, "baisse": 0.25},
		"metiers": [["agent_public", 1]],
		"desc": "Grand bassin à digues de terre : il retient l'eau des orages et des crues. La rivière monte 25 % moins haut à moins de 3 km (jusqu'à −75 % avec trois bassins)."},
	"station_meteo": {"name": "Station météo", "w": 14, "d": 14, "access": ROAD, "emplois": 2, "cost": 250_000,
		"saisons": {"role": "meteo"},
		"metiers": [["ingenieur", 2]],
		"desc": "Abri à thermomètres, pluviomètre et mât à anémomètre. Les prévisions passent de 3 à 7 jours (panneau Saisons, Maj+R)."},
}
const ORDER := ["centre_technique", "bassin_retention", "station_meteo"]


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		out[id] = t
	return out


static func spec_of(type_id: String) -> Dictionary:
	return BuildingCatalog.get_type(BuildingCatalog.base_of(type_id)).get("saisons", {})


static func role_of(type_id: String) -> String:
	return String(spec_of(type_id).get("role", ""))


# --- Modèles low-poly --------------------------------------------------------------------

const BETON := Color("b9b6ae")
const BETON_C := Color("d6d3cc")
const TOLE := Color("8d99ae")
const ORANGE := Color("f77f00")
const SEL := Color("eef1f4")
const BOIS := Color("9c6b45")
const VITRE := Color("33495e")
const HERBE := Color("6aa84f")
const EAU := Color("4f8fbf")
const TERRE := Color("8a7458")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"centre_technique":
			k.plate(0, 0, w, d, BETON)
			# Hangar des engins : deux grandes portes sur la façade (−Z).
			k.box(-5, 0, 3, 18, 7.0, 16, TOLE)
			k.gable(-5, 7.0, 3, 18.6, 16.6, 1.5, Color("5b5f66"))
			for i in 2:
				k.box(-9.5 + i * 9.0, 0, -5.05, 6.0, 5.0, 0.1, Color("e9ecef"))
			k.box(-5, 6.4, -5.1, 14.0, 0.6, 0.1, ORANGE)
			# Dôme de sel en bois, tas blanc à l'entrée.
			k.cylinder(10, 0, 5, 6.5, 6.5, 2.0, 12, BOIS)
			k.dome(10, 2.0, 5, 6.5, 5.5, BOIS.darkened(0.15), 12)
			k.box(10, 0, -1.3, 3.0, 3.2, 0.3, Color("3d3d3d"))
			k.dome(10, 0, -3.2, 2.6, 1.4, SEL, 8)
			# Bureaux.
			k.box(10, 0, -9, 10, 3.6, 5, BETON_C)
			k.windows_row(10, -11.55, 8.0, 1.6, 3, 1.4, 1.1, VITRE)
			# Un chasse-neige garé dans la cour : lame orange, cabine, trémie.
			k.box(-5, 0.4, -10.5, 2.5, 2.6, 2.2, ORANGE)
			k.box(-5, 0.4, -8.0, 2.5, 2.2, 3.2, Color("6c757d"))
			k.box(-5, 0.1, -12.1, 3.2, 1.0, 0.25, ORANGE.darkened(0.1))
			for x in [-6.0, -4.0]:
				k.box(x, 0, -10.5, 0.5, 0.9, 0.9, Color("212529"))
				k.box(x, 0, -7.2, 0.5, 0.9, 0.9, Color("212529"))
			k.box(-5, 3.0, -10.8, 1.0, 0.2, 0.3, ORANGE.lightened(0.3))
		"bassin_retention":
			k.plate(0, 0, w, d, HERBE)
			# Digues de terre enherbées, eau au fond, déversoir en béton.
			k.box(0, 0, -d / 2 + 2.5, w - 2, 1.8, 3.0, HERBE.darkened(0.12))
			k.box(0, 0, d / 2 - 2.5, w - 2, 1.8, 3.0, HERBE.darkened(0.12))
			k.box(-w / 2 + 2.5, 0, 0, 3.0, 1.8, d - 2, HERBE.darkened(0.12))
			k.box(w / 2 - 2.5, 0, 0, 3.0, 1.8, d - 2, HERBE.darkened(0.12))
			k.plate(0, 0, w - 8, d - 8, TERRE, 0.05, 0.1)
			k.plate(0, 0, w - 10, d - 10, EAU, 0.2, 0.15)
			k.box(w / 2 - 2.5, 0, 6, 3.4, 2.0, 4.0, BETON)
			k.box(w / 2 - 2.5, 2.0, 6, 3.6, 0.15, 4.2, Color("495057"))
			# Échelle limnimétrique et clôture basse.
			k.box(-w / 2 + 5, 0, -d / 2 + 5, 0.15, 3.0, 0.15, Color("ffd166"))
			for i in 10:
				k.box(-w / 2 + 1 + i * (w - 2) / 9.0, 0, -d / 2 + 0.6, 0.12, 1.0, 0.12, BOIS)
		"station_meteo":
			k.plate(0, 0, w, d, HERBE)
			# Abri à thermomètres blanc sur pieds.
			for x in [-3.6, -2.4]:
				for z in [-0.6, 0.6]:
					k.box(x, 0, z, 0.1, 1.2, 0.1, Color("f8f9fa"))
			k.box(-3.0, 1.2, 0, 1.6, 0.9, 1.6, Color("f8f9fa"))
			k.gable(-3.0, 2.1, 0, 1.8, 1.8, 0.3, Color("f8f9fa"))
			# Mât à anémomètre.
			k.cylinder(3, 0, -2, 0.08, 0.06, 10.0, 6, Color("adb5bd"))
			k.box(3, 10.0, -2, 1.4, 0.06, 0.06, Color("adb5bd"))
			k.box(3, 10.0, -2, 0.06, 0.06, 1.4, Color("adb5bd"))
			for s in [Vector2(0.7, 0), Vector2(-0.7, 0), Vector2(0, 0.7), Vector2(0, -0.7)]:
				k.dome(3 + s.x, 9.85, -2 + s.y, 0.18, 0.2, Color("e63946"), 6)
			# Pluviomètre et petit local.
			k.cylinder(0.5, 0, 3.5, 0.2, 0.2, 1.1, 8, Color("adb5bd"))
			k.box(3.5, 0, 4, 4.0, 2.6, 3.0, BETON_C)
			k.gable(3.5, 2.6, 4, 4.4, 3.4, 0.6, Color("c8553d"))
			k.windows_row(3.5, 2.45, 2.5, 1.0, 1, 1.0, 0.9, VITRE)
