class_name CommercesTypes
extends RefCounted
## Commerces de la vie courante ajoutés pour l'économie locale : ils vendent
## aux habitants ce que les camions leur livrent (voir Ressources.COMMERCES).
## Même format que BuildingCatalog ; modèles low-poly faits en code.

const ROAD := ["route"]
const RP := ["route", "chemin"]

const TYPES := {
	"station_service": {"name": "Station-service", "w": 24, "d": 22, "access": ROAD, "emplois": 4, "visiteurs": 300, "cost": 900_000,
		"desc": "Pompes sous auvent et petite boutique. Carburant, boissons, dépannage."},
	"pharmacie": {"name": "Pharmacie", "w": 10, "d": 12, "access": RP, "emplois": 4, "visiteurs": 150, "cost": 450_000,
		"desc": "Croix verte, médicaments et hygiène."},
	"boutique_mode": {"name": "Boutique de vêtements", "w": 10, "d": 14, "access": RP, "emplois": 4, "visiteurs": 120, "cost": 400_000,
		"desc": "Vêtements et chaussures en vitrine."},
	"magasin_multimedia": {"name": "Magasin d'électronique et d'électroménager", "w": 26, "d": 24, "access": ROAD, "emplois": 15,
		"visiteurs": 300, "cost": 2_000_000, "desc": "Téléphones, ordinateurs, téléviseurs, lave-linge, outils."},
	"magasin_meubles": {"name": "Magasin de meubles", "w": 36, "d": 30, "access": ROAD, "emplois": 12, "visiteurs": 200,
		"cost": 2_500_000, "desc": "Grand hall d'exposition et quai de livraison."},
	"concession_auto": {"name": "Concession automobile", "w": 32, "d": 28, "access": ROAD, "emplois": 10, "visiteurs": 40,
		"cost": 2_200_000, "desc": "Vitrine de voitures neuves et atelier."},
}
const ORDER := ["station_service", "pharmacie", "boutique_mode", "magasin_multimedia", "magasin_meubles", "concession_auto"]


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = "commerce"
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		t["boutique_eco"] = true
		out[id] = t
	return out


const BETON := Color("b9b6ae")
const VITRE := Color("33495e")
const ACIER := Color("5c677d")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"station_service":
			k.plate(0, 0, w, d, Color("6c757d"))
			k.box(0, 5.2, -2, 16, 0.8, 10, Color("f1faee"))
			k.box(0, 6.0, -2, 16.2, 0.4, 10.2, Color("e63946"))
			for x in [-5.0, 5.0]:
				k.box(x, 0, -2, 0.6, 5.2, 0.6, Color("dee2e6"))
				k.box(x, 0, -4.5, 1.0, 1.8, 0.6, Color("2a9d8f"))
				k.box(x, 0, 0.5, 1.0, 1.8, 0.6, Color("2a9d8f"))
			k.box(0, 0, 7.5, 12, 4, 6, Color("f8f9fa"))
			k.box(0, 0.4, 4.45, 8, 2.6, 0.2, VITRE)
			k.box(10, 0, 7, 0.4, 7, 0.4, ACIER)
			k.box(10, 7, 7, 2.4, 2.4, 0.4, Color("e63946"))
		"pharmacie":
			k.box(0, 0, 0, w, 7, d, Color("f1e6d2"))
			k.gable(0, 7, 0, w + 0.6, d + 0.6, 2.4, Color("c8553d"))
			k.box(0, 0.3, -d / 2 - 0.05, w * 0.7, 2.6, 0.2, VITRE)
			k.box(0, 3.4, -d / 2 - 0.5, 1.6, 0.5, 0.3, Color("2dc653"))
			k.box(0, 3.4, -d / 2 - 0.5, 0.5, 1.6, 0.3, Color("2dc653"))
		"boutique_mode":
			k.box(0, 0, 0, w, 8, d, Color("f2d0a9"))
			k.box(0, 8, 0, w + 0.4, 0.5, d + 0.4, Color("5b5f66"))
			k.box(0, 0.3, -d / 2 - 0.05, w * 0.8, 3.0, 0.2, VITRE)
			k.box(0, 3.5, -d / 2 - 0.4, w * 0.9, 0.9, 0.6, Color("9d4edd"))
		"magasin_multimedia":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 2, w * 0.9, 8, d * 0.7, Color("e9ecef"))
			k.box(0, 8, 2, w * 0.9 + 0.4, 0.5, d * 0.7 + 0.4, Color("1d3557"))
			k.box(0, 0.3, 2 - d * 0.35 - 0.05, w * 0.6, 3.0, 0.2, VITRE)
			k.box(0, 5, 2 - d * 0.35 - 0.3, w * 0.5, 1.6, 0.4, Color("f77f00"))
		"magasin_meubles":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 3, w * 0.9, 10, d * 0.75, Color("ffd166"))
			k.box(0, 10, 3, w * 0.9 + 0.4, 0.5, d * 0.75 + 0.4, Color("1d3557"))
			k.box(0, 6, 3 - d * 0.375 - 0.3, w * 0.6, 2.2, 0.4, Color("1d3557"))
			k.box(0, 0.3, 3 - d * 0.375 - 0.05, 6, 3.4, 0.2, VITRE)
		"concession_auto":
			k.plate(0, 0, w, d, Color("6c757d"))
			k.box(-4, 0, 4, 20, 7, 16, Color("f8f9fa"))
			k.box(-4, 0.3, 4 - 8.05, 18, 5.6, 0.2, VITRE)
			k.box(-4, 7, 4, 20.4, 0.5, 16.4, Color("4ea8de"))
			k.box(10, 0, 6, 8, 5, 12, Color("adb5bd"))
			for i in 4:
				k.box(-12 + i * 5, 0, -10, 4.2, 1.5, 1.9, ProductionTypes.CAR_COLS[i % ProductionTypes.CAR_COLS.size()])
		_:
			k.box(0, 0, 0, w * 0.8, 6, d * 0.8, Color("e9ecef"))
