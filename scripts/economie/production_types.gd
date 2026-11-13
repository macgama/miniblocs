class_name ProductionTypes
extends RefCounted
## Bâtiments de production (catégorie « Production » du panneau Construire) :
## extraction des ressources naturelles et transformation des marchandises.
##
## Même format que BuildingCatalog, plus un champ "prod" :
## - extraction : "res" = {ressource naturelle: tonnes par jour à richesse 1},
##   "radius" = rayon (m) autour du bâtiment où l'on mesure la richesse (forêt,
##   champs, eau) ; "reserve" = tonnes en place par point de richesse (les
##   gisements non renouvelables s'épuisent) ; "min" = richesse minimale.
## - transformation : "in" et "out" = {marchandise: tonnes par jour} à plein
##   régime (tous les emplois pourvus, intrants disponibles).
## Les chiffres sont des ordres de grandeur réels (une ferme céréalière et ses
## 25 ha de champs donne environ 1 t de grain par jour en moyenne sur l'année).

const CATEGORY := "production"
const ROAD := ["route"]
const RP := ["route", "chemin"]

const TYPES := {
	# --- Extraction ---------------------------------------------------------------------
	"exploitation_forestiere": {"name": "Exploitation forestière", "w": 30, "d": 24, "access": RP, "emplois": 12, "cost": 600_000,
		"prod": {"kind": "extraction", "res": {"bois": 40.0}, "radius": 250.0, "min": 0.15},
		"desc": "Bûcherons, débardeuses et piles de grumes. À poser dans ou près d'une forêt."},
	"carriere": {"name": "Carrière", "w": 44, "d": 44, "access": ROAD, "emplois": 15, "cost": 1_500_000,
		"prod": {"kind": "extraction", "res": {"pierre": 300.0}, "radius": 40.0, "min": 0.15},
		"desc": "Fosse en gradins, concasseur et tas de granulats. Meilleure sur roche et en montagne."},
	"sabliere": {"name": "Sablière", "w": 32, "d": 32, "access": ROAD, "emplois": 8, "cost": 800_000,
		"prod": {"kind": "extraction", "res": {"sable": 200.0}, "radius": 60.0, "min": 0.15},
		"desc": "Sable et graviers, au bord d'une rivière, d'une plage ou dans le désert."},
	"argiliere": {"name": "Carrière d'argile", "w": 32, "d": 32, "access": ROAD, "emplois": 8, "cost": 700_000,
		"prod": {"kind": "extraction", "res": {"argile": 150.0}, "radius": 40.0, "min": 0.15},
		"desc": "Argile des plaines basses et des zones humides."},
	"mine": {"name": "Mine", "w": 40, "d": 36, "access": ROAD, "emplois": 60, "cost": 8_000_000,
		"prod": {"kind": "extraction", "res": {"fer": 400.0, "charbon": 400.0, "cuivre": 250.0, "or": 80.0, "bauxite": 300.0},
			"radius": 60.0, "reserve": 600_000.0, "min": 0.08},
		"desc": "Chevalement, terril et bâtiments. Extrait le meilleur minerai du sous-sol (fer, charbon, cuivre, or, bauxite)."},
	"puits": {"name": "Puits de pétrole ou de gaz", "w": 16, "d": 20, "access": ROAD, "emplois": 6, "cost": 3_000_000,
		"prod": {"kind": "extraction", "res": {"petrole": 80.0, "gaz": 60.0}, "radius": 40.0, "reserve": 400_000.0, "min": 0.08},
		"desc": "Chevalet de pompage, citernes et torchère. Au-dessus d'un gisement de pétrole ou de gaz."},
	"ferme_cereales": {"name": "Ferme céréalière", "w": 40, "d": 30, "access": RP, "emplois": 2, "cost": 1_200_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 1.2}, "radius": 300.0, "min": 0.2},
		"desc": "Hangars, silos et 25 ha de champs alentour. Rendement selon le sol, la pente et le climat."},
	"elevage": {"name": "Élevage", "w": 36, "d": 28, "access": RP, "emplois": 5, "cost": 900_000,
		"prod": {"kind": "extraction", "res": {"paturage": 0.3}, "radius": 300.0, "min": 0.2},
		"desc": "Étable, fourrage et prés. Bovins sur les prairies et les alpages."},
	"port_peche": {"name": "Port de pêche", "w": 28, "d": 20, "access": ROAD, "emplois": 10, "cost": 1_500_000,
		"prod": {"kind": "extraction", "res": {"poisson": 2.0}, "radius": 200.0, "min": 0.1},
		"desc": "Criée, quai et chalutiers. Au bord de la mer, d'un lac ou d'un grand fleuve."},
	"ferme_maraichere": {"name": "Maraîchage et vergers", "w": 30, "d": 24, "access": RP, "emplois": 10, "cost": 700_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 2.0}, "good": "fruits_legumes", "radius": 200.0, "min": 0.25},
		"desc": "Serres, rangs de légumes et arbres fruitiers. Sur les bonnes terres."},
	"ferme_betteraves": {"name": "Ferme betteravière", "w": 36, "d": 28, "access": RP, "emplois": 2, "cost": 900_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 6.0}, "good": "betteraves", "radius": 300.0, "min": 0.3},
		"desc": "Hangar, arracheuse et tas de betteraves sucrières."},
	"ferme_fibres": {"name": "Culture de lin et de coton", "w": 30, "d": 24, "access": RP, "emplois": 2, "cost": 600_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 0.25}, "good": "fibres", "radius": 300.0, "min": 0.25},
		"desc": "Lin teillé en balles (climats tempérés) ou coton (climats chauds)."},
	"ferme_laitiere": {"name": "Ferme laitière", "w": 36, "d": 28, "access": RP, "emplois": 5, "cost": 1_100_000,
		"prod": {"kind": "extraction", "res": {"paturage": 1.5}, "good": "lait", "radius": 300.0, "min": 0.2},
		"desc": "Stabulation, salle de traite et tank à lait. Vaches dans les prés."},
	"concession_agricole": {"name": "Concession de machines agricoles", "w": 36, "d": 28, "access": ROAD, "emplois": 6,
		"cost": 1_800_000, "prod": {"kind": "service"},
		"desc": "Vend, loue et répare les tracteurs et les machines : achats 10 % moins chers, réparations deux fois moins chères."},
	"silo_cooperative": {"name": "Silo de coopérative agricole", "w": 30, "d": 24, "access": RP, "emplois": 4,
		"cost": 2_000_000, "prod": {"kind": "entrepot"},
		"desc": "Les fermes y apportent leurs récoltes (grain, colza, foin…) : un entrepôt pour toute la région."},
	# --- Transformation -------------------------------------------------------------------
	"huilerie": {"name": "Huilerie", "w": 30, "d": 24, "access": ROAD, "emplois": 10, "cost": 2_500_000,
		"prod": {"kind": "transformation", "in": {"oleagineux": 10.0}, "out": {"huile": 4.0}},
		"desc": "Graines de colza, de tournesol et de soja → huile."},
	"filature": {"name": "Filature de laine", "w": 30, "d": 24, "access": ROAD, "emplois": 15, "cost": 2_000_000,
		"prod": {"kind": "transformation", "in": {"laine": 1.0}, "out": {"fibres": 0.85}},
		"desc": "Laine de mouton lavée, cardée et filée → fibres pour le textile."},
	"scierie": {"name": "Scierie", "w": 36, "d": 30, "access": ROAD, "emplois": 20, "cost": 2_500_000,
		"prod": {"kind": "transformation", "in": {"bois": 30.0}, "out": {"planches": 18.0}},
		"desc": "Grumes → planches."},
	"moulin": {"name": "Moulin à farine", "w": 18, "d": 16, "access": RP, "emplois": 6, "cost": 900_000,
		"prod": {"kind": "transformation", "in": {"cereales": 4.0}, "out": {"farine": 3.0}},
		"desc": "Céréales → farine."},
	"fournil": {"name": "Boulangerie industrielle", "w": 24, "d": 20, "access": ROAD, "emplois": 12, "cost": 1_500_000,
		"prod": {"kind": "transformation", "in": {"farine": 1.5}, "out": {"pain": 2.0}},
		"desc": "Farine → pain, livré par camion aux commerces de la ville."},
	"abattoir": {"name": "Abattoir et boucherie", "w": 32, "d": 24, "access": ROAD, "emplois": 15, "cost": 2_000_000,
		"prod": {"kind": "transformation", "in": {"betail": 1.5}, "out": {"viande": 0.9}},
		"desc": "Bétail → viande."},
	"acierie": {"name": "Aciérie", "w": 64, "d": 44, "access": ROAD, "emplois": 150, "cost": 30_000_000,
		"prod": {"kind": "transformation", "in": {"minerai_fer": 300.0, "charbon": 160.0}, "out": {"acier": 200.0}},
		"desc": "Haut fourneau : minerai de fer + charbon → acier."},
	"raffinerie": {"name": "Raffinerie", "w": 60, "d": 60, "access": ROAD, "emplois": 80, "cost": 40_000_000,
		"prod": {"kind": "transformation", "in": {"petrole": 200.0}, "out": {"carburant": 160.0, "plastique": 25.0}},
		"desc": "Pétrole brut → carburant (essence, gazole) et plastiques."},
	"briqueterie": {"name": "Briqueterie", "w": 40, "d": 30, "access": ROAD, "emplois": 25, "cost": 4_000_000,
		"prod": {"kind": "transformation", "in": {"argile": 100.0}, "out": {"briques": 85.0}},
		"desc": "Argile → briques et tuiles, cuites au four."},
	"cimenterie": {"name": "Cimenterie", "w": 44, "d": 36, "access": ROAD, "emplois": 40, "cost": 15_000_000,
		"prod": {"kind": "transformation", "in": {"pierre": 250.0}, "out": {"ciment": 160.0}},
		"desc": "Calcaire → ciment, dans un four rotatif."},
	"fonderie_cuivre": {"name": "Fonderie de cuivre", "w": 44, "d": 36, "access": ROAD, "emplois": 60, "cost": 20_000_000,
		"prod": {"kind": "transformation", "in": {"minerai_cuivre": 200.0}, "out": {"cuivre": 2.0}},
		"desc": "Minerai à 1 % → cuivre pur."},
	"menuiserie": {"name": "Menuiserie", "w": 24, "d": 20, "access": ROAD, "emplois": 12, "cost": 1_200_000,
		"prod": {"kind": "transformation", "in": {"planches": 2.0}, "out": {"meubles": 1.6}},
		"desc": "Planches → meubles."},
	"usine_biens": {"name": "Usine de biens", "w": 44, "d": 34, "access": ROAD, "emplois": 120, "cost": 9_000_000,
		"prod": {"kind": "transformation", "in": {"acier": 12.0, "planches": 4.0, "cuivre": 0.3}, "out": {"biens": 5.0}},
		"desc": "Acier + planches + cuivre → biens manufacturés (électroménager, outils…)."},
	"laiterie": {"name": "Laiterie et fromagerie", "w": 30, "d": 24, "access": ROAD, "emplois": 25, "cost": 3_000_000,
		"prod": {"kind": "transformation", "in": {"lait": 3.0}, "out": {"laitages": 2.5}},
		"desc": "Lait cru → lait, fromages, beurre et yaourts."},
	"sucrerie": {"name": "Sucrerie", "w": 44, "d": 34, "access": ROAD, "emplois": 10, "cost": 8_000_000,
		"prod": {"kind": "transformation", "in": {"betteraves": 30.0}, "out": {"sucre": 4.5}},
		"desc": "Betteraves → sucre."},
	"usine_agro": {"name": "Usine agroalimentaire", "w": 44, "d": 34, "access": ROAD, "emplois": 60, "cost": 7_000_000,
		"prod": {"kind": "transformation", "in": {"farine": 2.0, "sucre": 0.5, "fruits_legumes": 1.5, "laitages": 0.5}, "out": {"epicerie": 6.0}},
		"desc": "Farine, sucre, légumes et laitages → pâtes, conserves, biscuits, plats préparés."},
	"brasserie": {"name": "Brasserie et eaux minérales", "w": 36, "d": 28, "access": ROAD, "emplois": 25, "cost": 5_000_000,
		"prod": {"kind": "transformation", "in": {"cereales": 1.0, "sucre": 0.3, "verre": 1.0}, "out": {"boissons": 8.0}},
		"desc": "Eau de source, orge et sucre, mis en bouteilles : eaux, sodas, bières."},
	"verrerie": {"name": "Verrerie", "w": 36, "d": 30, "access": ROAD, "emplois": 40, "cost": 9_000_000,
		"prod": {"kind": "transformation", "in": {"sable": 20.0}, "out": {"verre": 16.0}},
		"desc": "Sable fondu → bouteilles, vitres et écrans."},
	"papeterie": {"name": "Papeterie", "w": 44, "d": 34, "access": ROAD, "emplois": 50, "cost": 12_000_000,
		"prod": {"kind": "transformation", "in": {"bois": 25.0}, "out": {"papier": 15.0}},
		"desc": "Bois → pâte à papier, papier, carton et emballages."},
	"usine_chimique": {"name": "Usine chimique", "w": 44, "d": 40, "access": ROAD, "emplois": 60, "cost": 15_000_000,
		"prod": {"kind": "transformation", "in": {"gaz": 30.0}, "out": {"chimie": 25.0}},
		"desc": "Gaz naturel → engrais, solvants, savons et matières de base."},
	"usine_textile": {"name": "Usine textile", "w": 40, "d": 30, "access": ROAD, "emplois": 80, "cost": 6_000_000,
		"prod": {"kind": "transformation", "in": {"fibres": 1.0, "plastique": 0.4}, "out": {"vetements": 1.2}},
		"desc": "Lin, coton et fibres synthétiques → vêtements et chaussures."},
	"usine_hygiene": {"name": "Usine de produits d'hygiène", "w": 36, "d": 30, "access": ROAD, "emplois": 50, "cost": 6_000_000,
		"prod": {"kind": "transformation", "in": {"chimie": 1.5, "papier": 3.0, "plastique": 0.5}, "out": {"hygiene": 4.5}},
		"desc": "Savon, lessive, shampoing, papier toilette et couches."},
	"labo_pharma": {"name": "Laboratoire pharmaceutique", "w": 36, "d": 28, "access": ROAD, "emplois": 120, "cost": 25_000_000,
		"prod": {"kind": "transformation", "in": {"chimie": 0.4, "sucre": 0.1}, "out": {"medicaments": 0.4}},
		"desc": "Principes actifs, comprimés et sirops."},
	"aluminerie": {"name": "Aluminerie", "w": 60, "d": 40, "access": ROAD, "emplois": 100, "cost": 30_000_000,
		"prod": {"kind": "transformation", "in": {"bauxite": 80.0}, "out": {"aluminium": 20.0}},
		"desc": "Bauxite → alumine → aluminium, par électrolyse."},
	"usine_electronique": {"name": "Usine d'électronique", "w": 40, "d": 30, "access": ROAD, "emplois": 150, "cost": 20_000_000,
		"prod": {"kind": "transformation", "in": {"cuivre": 0.3, "plastique": 1.0, "verre": 0.4}, "out": {"electronique": 1.2}},
		"desc": "Cartes, écrans et boîtiers → téléphones, ordinateurs, téléviseurs."},
	"usine_auto": {"name": "Usine automobile", "w": 80, "d": 60, "access": ROAD, "emplois": 400, "cost": 60_000_000,
		"prod": {"kind": "transformation", "in": {"acier": 25.0, "aluminium": 6.0, "plastique": 5.0, "electronique": 1.0, "verre": 1.5},
			"out": {"voitures": 35.0}},
		"desc": "Emboutissage, peinture et montage : environ 25 voitures par jour."},
	# --- Logistique -------------------------------------------------------------------------
	"transporteur": {"name": "Entreprise de transport routier", "w": 40, "d": 30, "access": ROAD, "emplois": 20, "cost": 1_500_000,
		"prod": {"kind": "logistique"},
		"desc": "Parking de camions et bureaux. Ses chauffeurs-livreurs livrent toute la ville."},
}
## Ordre dans le panneau : de la ressource brute au produit fini.
const ORDER := ["exploitation_forestiere", "ferme_cereales", "ferme_maraichere", "ferme_betteraves", "ferme_fibres",
	"elevage", "ferme_laitiere", "silo_cooperative",
	"concession_agricole", "port_peche", "carriere", "sabliere", "argiliere", "mine", "puits",
	"scierie", "moulin", "fournil", "abattoir", "laiterie", "sucrerie", "huilerie", "filature", "usine_agro", "brasserie",
	"briqueterie", "cimenterie", "verrerie", "papeterie", "acierie", "fonderie_cuivre", "aluminerie", "raffinerie",
	"usine_chimique", "menuiserie", "usine_textile", "usine_hygiene", "labo_pharma", "usine_biens",
	"usine_electronique", "usine_auto", "transporteur"]


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


static func prod_of(type_id: String) -> Dictionary:
	return BuildingCatalog.get_type(type_id).get("prod", {})


# --- Modèles low-poly --------------------------------------------------------------------

const BETON := Color("b9b6ae")
const TOLE := Color("8d99ae")
const TOLE_ROUGE := Color("9b2226")
const BRIQUE := Color("a4543a")
const BOIS_C := Color("8c5a3c")
const TERRE := Color("9c7b55")
const GRAVIER := Color("c2b8a3")
const ACIER := Color("5c677d")
const HERBE := Color("6aa84f")
const BLE := Color("e0c068")
const EAU := Color("3f88c5")
const VITRE := Color("33495e")
const CAR_COLS: Array[Color] = [Color("d64933"), Color("2e86ab"), Color("f4f4f4"), Color("343a40"), Color("f2c14e")]


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"exploitation_forestiere":
			k.plate(0, 0, w, d, TERRE)
			k.box(-8, 0, -6, 10, 4.5, 8, BOIS_C)
			k.gable(-8, 4.5, -6, 10.6, 8.6, 2.2, TOLE)
			for i in 4:
				for j in 3:
					k.box(4.0, 0.0 + j * 0.8, -6.0 + i * 2.2, 9.0, 0.8, 0.8, Color("a0704a"))
			k.box(6, 0, 6, 3.0, 2.6, 6.0, Color("e9c46a"))
			k.box(6, 2.6, 4.5, 2.4, 1.2, 2.4, VITRE)
			for x in [-12.0, 12.0]:
				k.tree(x, 9.0, 1.3, Color("2d6a4f"))
				k.tree(x * 0.6, 10.0, 1.1, Color("40916c"))
		"carriere":
			k.plate(0, 0, w, d, GRAVIER)
			# Fosse en gradins (vue comme des terrasses de plus en plus petites).
			for i in 3:
				k.plate(4, 4, 28.0 - i * 7.0, 28.0 - i * 7.0, Color("a39e93").darkened(i * 0.08), 0.0, 0.12 + i * 0.05)
			k.box(-16, 0, -14, 6, 6, 6, ACIER)
			k.box(-16, 6, -14, 3, 3, 3, TOLE)
			k.pyramid(-12, 0, 14, 10, 10, 6, Color("d6ccc2"))
			k.pyramid(-17, 0, 6, 7, 7, 4, Color("bfb3a5"))
			k.box(10, 0, -16, 6, 2.6, 3, Color("f4a261"))
		"sabliere":
			k.plate(0, 0, w, d, Color("e6d3a3"))
			k.plate(4, 6, 16, 14, Color("6c9bc0"), 0.0, 0.1)
			k.pyramid(-8, 0, -6, 10, 10, 5, Color("f4d58d"))
			k.pyramid(6, 0, -8, 8, 8, 4, Color("cbbf9f"))
			k.box(-10, 0, 8, 5, 3, 3, Color("f4a261"))
			k.box(-4, 0, 10, 1.2, 6, 1.2, ACIER)
		"argiliere":
			k.plate(0, 0, w, d, Color("b07d50"))
			k.plate(3, 4, 18, 16, Color("8a5a35"), 0.0, 0.14)
			k.pyramid(-9, 0, -8, 9, 9, 4, Color("bc6c25"))
			k.box(9, 0, -10, 6, 3, 4, Color("f4a261"))
			k.box(-10, 0, 9, 8, 3.5, 6, TOLE)
		"mine":
			k.plate(0, 0, w, d, Color("7f7a73"))
			# Chevalement (tour en treillis) et ses molettes.
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					k.box(-6 + sx * 2.5, 0, -4 + sz * 2.5, 0.6, 22, 0.6, ACIER)
			k.box(-6, 22, -4, 6.4, 1.0, 6.4, ACIER)
			k.cylinder(-6, 23, -6.5, 2.2, 2.2, 0.5, 10, TOLE_ROUGE)
			k.box(-6, 0, -4, 7, 4, 7, BRIQUE)
			k.box(6, 0, -8, 14, 7, 10, BRIQUE)
			k.gable(6, 7, -8, 14.6, 10.6, 3, Color("5b5f66"))
			k.box(13, 0, -2, 1.5, 18, 1.5, BRIQUE)
			k.pyramid(8, 0, 10, 18, 12, 9, Color("3d3d3d"))
		"puits":
			k.plate(0, 0, w, d, Color("c9b79c"))
			# Chevalet de pompage : socle, balancier et tête de cheval.
			k.box(-2, 0, -3, 2, 3.5, 2, ACIER)
			k.box(-2, 4.5, -3, 0.8, 0.8, 9, Color("e63946"))
			k.box(-2, 3.5, -7.6, 1.2, 2.4, 1.6, Color("e63946"))
			k.box(-2, 0, 1.6, 1.4, 1.4, 1.4, ACIER)
			for z in [3.5, 7.5]:
				k.cylinder(4, 0, z, 1.8, 1.8, 4.5, 12, Color("e9ecef"))
			k.box(-5, 0, 6, 0.4, 9, 0.4, ACIER)
		"ferme_cereales":
			k.plate(0, 0, w, d, Color("b5a46a"))
			k.box(-8, 0, -4, 16, 7, 12, TOLE)
			k.gable(-8, 7, -4, 16.6, 12.6, 3, Color("6c757d"))
			for x in [8.0, 13.0]:
				k.cylinder(x, 0, -6, 2.2, 2.2, 11, 12, Color("dee2e6"))
				k.cylinder(x, 11, -6, 2.3, 0.2, 2, 12, Color("adb5bd"))
			k.plate(4, 9, 30, 10, BLE, 0.0, 0.25)
			k.box(10, 0, 4, 3, 2.8, 5, Color("2a9d8f"))
		"elevage":
			k.plate(0, 0, w, d, HERBE)
			k.box(-6, 0, -5, 18, 6, 10, Color("f1e6d2"))
			k.gable(-6, 6, -5, 18.6, 10.6, 3.2, TOLE_ROUGE)
			k.cylinder(9, 0, -7, 2.0, 2.0, 9, 10, Color("8d99ae"))
			for x in [-12.0, 12.0]:
				k.box(x, 0, 8, 0.25, 1.2, 10, BOIS_C)
			k.box(0, 0, 13, 24, 1.2, 0.25, BOIS_C)
			for p in [Vector2(-6, 6), Vector2(-2, 9), Vector2(4, 7), Vector2(7, 10)]:
				k.box(p.x, 0.7, p.y, 2.2, 1.1, 0.9, Color("3d3d3d") if int(p.x) % 2 == 0 else Color("f8f9fa"))
		"port_peche":
			k.plate(0, 0, w, d, BETON)
			k.box(-6, 0, -3, 12, 6, 9, Color("4ea8de"))
			k.gable(-6, 6, -3, 12.6, 9.6, 2.4, Color("e9ecef"))
			k.box(8, 0, 4, 10, 1.0, 10, Color("6c757d"))
			k.box(8, 1.0, 6, 3.5, 1.6, 7, Color("d62828"))
			k.box(8, 2.6, 7, 2.0, 1.8, 2.5, Color("f8f9fa"))
			k.box(8, 2.6, 4, 0.2, 6, 0.2, ACIER)
			for i in 4:
				k.box(-10 + i * 1.6, 0, 6, 1.2, 1.0, 1.2, Color("1d3557"))
		"scierie":
			k.plate(0, 0, w, d, TERRE)
			k.box(-4, 0, -4, 20, 8, 14, Color("ddb892"))
			k.gable(-4, 8, -4, 20.6, 14.6, 3, TOLE)
			k.cylinder(11, 0, -8, 1.0, 1.0, 14, 8, ACIER)
			for i in 3:
				k.box(-6 + i * 5, 0, 10, 4, 1.6, 4, Color("e6ccb2"))
			k.box(12, 0, 8, 6, 2.4, 2.4, BOIS_C)
		"moulin":
			k.plate(0, 0, w, d, Color("cbbf9f"))
			k.cylinder(-2, 0, 0, 5, 4, 12, 10, Color("e9e2d4"))
			k.cylinder(-2, 12, 0, 4.4, 0.2, 4, 10, Color("8c4a3a"))
			k.box(-2, 9, -5.2, 0.6, 12, 0.4, BOIS_C)
			k.box(-2, 14.5, -5.2, 12, 0.6, 0.4, BOIS_C)
			k.box(5, 0, 3, 5, 4, 6, Color("f1e6d2"))
		"fournil":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 1, 20, 7, 14, Color("f4e3c1"))
			k.box(0, 7, 1, 20.4, 0.5, 14.4, Color("d0c8b8"))
			k.box(0, 0.5, -6.05, 14, 2.8, 0.2, VITRE)
			k.box(6, 7.5, 4, 1.2, 4, 1.2, Color("8c4a3a"))
			k.box(0, 3.6, -6.2, 8, 1.2, 0.3, Color("e4572e"))
		"abattoir":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 0, 26, 7, 18, Color("e9ecef"))
			k.box(0, 7, 0, 26.4, 0.5, 18.4, Color("adb5bd"))
			k.box(-8, 0, -9.1, 6, 4, 0.2, Color("6c757d"))
			k.box(8, 7.5, 4, 4, 2.5, 4, ACIER)
		"acierie":
			k.plate(0, 0, w, d, Color("6c6a66"))
			k.box(-14, 0, 0, 26, 18, 28, Color("7d8597"))
			k.gable(-14, 18, 0, 26.6, 28.6, 4, Color("5c677d"))
			k.cylinder(12, 0, -6, 5, 4, 30, 12, Color("495057"))
			k.cylinder(12, 30, -6, 3, 3, 6, 10, TOLE_ROUGE)
			for x in [20.0, 25.0]:
				k.cylinder(x, 0, 10, 1.4, 1.2, 40, 8, BRIQUE)
			k.box(20, 0, -14, 10, 6, 10, ACIER)
		"raffinerie":
			k.plate(0, 0, w, d, Color("9a9a96"))
			for p in [Vector2(-18, -18), Vector2(-6, -18), Vector2(-18, -6), Vector2(-6, -6)]:
				k.cylinder(p.x, 0, p.y, 4.5, 4.5, 9, 14, Color("e9ecef"))
			for p in [Vector2(10, -10), Vector2(16, -4)]:
				k.cylinder(p.x, 0, p.y, 1.6, 1.4, 34, 10, Color("ced4da"))
			k.box(12, 0, 12, 16, 10, 12, ACIER)
			k.box(20, 0, 20, 0.6, 40, 0.6, ACIER)
			k.cylinder(20, 40, 20, 0.6, 0.0, 2.5, 6, Color("f77f00"))
			k.box(-12, 0, 14, 16, 4, 10, TOLE)
		"briqueterie":
			k.plate(0, 0, w, d, Color("b07d50"))
			k.box(-4, 0, -2, 26, 7, 14, BRIQUE)
			k.gable(-4, 7, -2, 26.6, 14.6, 3, Color("5b5f66"))
			k.cylinder(12, 0, -6, 1.6, 1.3, 26, 8, BRIQUE)
			for i in 4:
				k.box(-12 + i * 5, 0, 10, 4, 1.8, 3, Color("c8553d"))
		"cimenterie":
			k.plate(0, 0, w, d, Color("cfcac0"))
			k.box(-10, 0, -8, 14, 26, 10, Color("d6d2c4"))
			k.box(4, 3, 0, 26, 3.6, 3.6, Color("a8a49a"))
			for x in [10.0, 16.0]:
				k.cylinder(x, 0, 10, 3, 3, 20, 12, Color("e9e5dc"))
			k.cylinder(-14, 26, -10, 1.2, 1.0, 14, 8, Color("adb5bd"))
		"fonderie_cuivre":
			k.plate(0, 0, w, d, Color("8d8a82"))
			k.box(-6, 0, -2, 24, 12, 18, Color("b56b45"))
			k.gable(-6, 12, -2, 24.6, 18.6, 3, ACIER)
			k.cylinder(12, 0, -8, 1.8, 1.4, 45, 10, Color("e9ecef"))
			k.box(14, 0, 8, 8, 5, 8, Color("e76f51"))
		"menuiserie":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 1, 20, 6, 14, Color("ddb892"))
			k.gable(0, 6, 1, 20.6, 14.6, 2.6, Color("8c4a3a"))
			k.box(0, 0, -6.05, 6, 4, 0.2, BOIS_C)
			k.box(-7, 0, -8, 4, 1.4, 2, Color("a0704a"))
		"usine_biens":
			k.plate(0, 0, w, d, BETON)
			k.box(-2, 0, 0, 36, 10, 26, Color("e9ecef"))
			for i in 5:
				k.gable(-16 + i * 7, 10, 0, 7, 26.4, 3, Color("4ea8de"), false)
			k.box(18, 0, -10, 6, 5, 6, ACIER)
			k.box(-18, 0, -13.1, 8, 4.5, 0.2, Color("6c757d"))
		"ferme_maraichere":
			k.plate(0, 0, w, d, Color("7a5c3e"))
			for i in 3:
				k.box(-9 + i * 6, 0, -6, 5, 3.2, 10, Color("dbe9ee"))
				k.gable(-9 + i * 6, 3.2, -6, 5.2, 10.2, 1.2, Color("eef6f8"))
			for i in 6:
				k.plate(-12 + i * 4, 7, 2.4, 8, Color("5a9e3a"), 0.0, 0.2)
			for x in [9.0, 13.0]:
				k.tree(x, 8.0, 0.8, Color("6a994e"))
		"ferme_betteraves":
			k.plate(0, 0, w, d, Color("8a6d4a"))
			k.box(-8, 0, -6, 16, 7, 12, TOLE)
			k.gable(-8, 7, -6, 16.6, 12.6, 3, Color("6c757d"))
			k.pyramid(9, 0, 4, 12, 8, 3, Color("d9c7a7"))
			k.box(10, 0, -8, 4, 3, 6, Color("2a9d8f"))
		"ferme_fibres":
			k.plate(0, 0, w, d, Color("b5a46a"))
			k.box(-6, 0, -4, 14, 6, 10, Color("e9e2d4"))
			k.gable(-6, 6, -4, 14.6, 10.6, 2.6, Color("8c4a3a"))
			for i in 5:
				k.cylinder(6 + (i % 3) * 2.4, 0, 4 + (i / 3) * 2.4, 1.0, 1.0, 1.4, 8, Color("f1e3b8"))
			k.plate(0, 9, 26, 6, Color("8fb3d9"), 0.0, 0.2)
		"ferme_laitiere":
			k.plate(0, 0, w, d, HERBE)
			k.box(-6, 0, -5, 20, 5, 12, Color("f1e6d2"))
			k.gable(-6, 5, -5, 20.6, 12.6, 3.0, Color("5b5f66"))
			k.cylinder(10, 0, -8, 1.8, 1.8, 3.2, 12, Color("e9ecef"))
			for p in [Vector2(-8, 7), Vector2(-3, 10), Vector2(3, 8), Vector2(8, 11)]:
				k.box(p.x, 0.7, p.y, 2.2, 1.1, 0.9, Color("f8f9fa"))
				k.box(p.x + 0.3, 1.0, p.y, 0.8, 0.5, 0.92, Color("3d3d3d"))
		"concession_agricole":
			k.plate(0, 0, w, d, BETON)
			k.box(-6, 0, -4, 20, 7, 14, Color("e9ecef"))
			k.box(-6, 7, -4, 20.4, 0.5, 14.4, Color("2a9d8f"))
			k.box(-6, 0.5, -11.05, 14, 4.5, 0.2, VITRE)
			for i in 3:
				k.box(8 + i * 0.1, 0, -6 + i * 6, 3, 2.8, 4.4, [Color("2d6a4f"), Color("d62828"), Color("f4a261")][i])
		"silo_cooperative":
			k.plate(0, 0, w, d, BETON)
			for i in 4:
				k.cylinder(-9 + i * 5.5, 0, -4, 2.5, 2.5, 18, 14, Color("dee2e6"))
				k.cylinder(-9 + i * 5.5, 18, -4, 2.6, 0.3, 2.4, 14, Color("adb5bd"))
			k.box(0, 0, 6, 22, 9, 8, TOLE)
			k.box(12, 0, -4, 1.4, 26, 1.4, ACIER)
		"laiterie", "sucrerie", "usine_agro", "brasserie", "usine_hygiene", "labo_pharma", "usine_electronique", "usine_textile", \
				"huilerie", "filature":
			var col := {"laiterie": Color("f8f9fa"), "sucrerie": Color("e9e2d4"), "usine_agro": Color("f4e3c1"),
				"brasserie": Color("d4a373"), "usine_hygiene": Color("dbe9ee"), "labo_pharma": Color("ffffff"),
				"usine_electronique": Color("e9ecef"), "usine_textile": Color("e6ccb2"), "huilerie": Color("f4e3a1"),
				"filature": Color("e6ccb2")}[id] as Color
			var roof := {"laiterie": Color("4ea8de"), "sucrerie": TOLE, "usine_agro": Color("e4572e"),
				"brasserie": Color("8c4a3a"), "usine_hygiene": Color("2a9d8f"), "labo_pharma": Color("2a9d8f"),
				"usine_electronique": Color("1d3557"), "usine_textile": Color("6c757d"), "huilerie": Color("e9c46a"),
				"filature": Color("8c4a3a")}[id] as Color
			k.plate(0, 0, w, d, BETON)
			k.box(-2, 0, 0, w * 0.62, 8, d * 0.6, col)
			k.box(-2, 8, 0, w * 0.62 + 0.4, 0.5, d * 0.6 + 0.4, roof)
			k.box(-2, 0.5, -d * 0.3 - 0.05, w * 0.4, 2.6, 0.2, VITRE)
			match id:
				"laiterie", "brasserie", "sucrerie", "huilerie":
					for i in 3:
						k.cylinder(w * 0.36, 0, -d * 0.3 + i * 4.0, 1.6, 1.6, 9 + i, 12, Color("ced4da"))
				"labo_pharma", "usine_electronique":
					k.box(w * 0.3, 0, d * 0.25, 6, 4, 6, Color("adb5bd"))
					k.box(w * 0.3, 4, d * 0.25, 1.4, 2.4, 1.4, ACIER)
				_:
					k.box(w * 0.33, 0, d * 0.2, 6, 5, 6, ACIER)
					k.cylinder(w * 0.36, 0, -d * 0.25, 0.9, 0.8, 14, 8, BRIQUE)
		"verrerie":
			k.plate(0, 0, w, d, Color("cfcac0"))
			k.box(-4, 0, 0, 22, 9, 18, Color("adb5bd"))
			k.gable(-4, 9, 0, 22.6, 18.6, 3, ACIER)
			k.cylinder(12, 0, -8, 1.4, 1.2, 28, 8, BRIQUE)
			for i in 3:
				k.box(-10 + i * 6, 0, 12, 4, 1.5, 3, Color("8ecae6"))
		"papeterie":
			k.plate(0, 0, w, d, Color("b9b6ae"))
			k.box(-6, 0, -2, 26, 14, 18, Color("e9e2d4"))
			k.gable(-6, 14, -2, 26.6, 18.6, 3, TOLE)
			k.cylinder(14, 0, -10, 2.2, 1.8, 36, 10, Color("dee2e6"))
			for i in 4:
				k.box(-14 + i * 6, 0, 12, 5, 2.4, 4, Color("a0704a"))
		"usine_chimique":
			k.plate(0, 0, w, d, Color("9a9a96"))
			for p in [Vector2(-14, -12), Vector2(-4, -12), Vector2(6, -12)]:
				k.cylinder(p.x, 0, p.y, 3.5, 3.5, 12, 14, Color("f8f9fa"))
			k.box(0, 0, 8, 26, 9, 14, Color("dee2e6"))
			for x in [14.0, 18.0]:
				k.cylinder(x, 0, 4, 1.2, 1.0, 26, 8, Color("ced4da"))
			k.box(-14, 1.5, 0, 14, 0.8, 0.8, Color("e9c46a"))
		"aluminerie":
			k.plate(0, 0, w, d, Color("8d8a82"))
			for i in 2:
				k.box(-6, 0, -10 + i * 14, 40, 8, 10, Color("ced4da"))
				k.gable(-6, 8, -10 + i * 14, 40.6, 10.6, 2.4, ACIER)
			k.cylinder(22, 0, 0, 3, 3, 18, 12, Color("e9ecef"))
			k.pyramid(22, 0, 14, 10, 8, 5, Color("d62828"))
		"usine_auto":
			k.plate(0, 0, w, d, BETON)
			k.box(-8, 0, -6, 54, 12, 36, Color("e9ecef"))
			for i in 7:
				k.gable(-32 + i * 8, 12, -6, 8, 36.4, 3, Color("4ea8de"), false)
			k.box(30, 0, 8, 14, 6, 14, Color("adb5bd"))
			for i in 8:
				k.box(-30 + i * 6, 0, 22, 4.2, 1.5, 1.9, CAR_COLS[i % CAR_COLS.size()])
		"transporteur":
			k.plate(0, 0, w, d, Color("6c757d"))
			k.box(-12, 0, -8, 12, 7, 10, Color("e9ecef"))
			k.box(-12, 7, -8, 12.4, 0.5, 10.4, Color("e63946"))
			k.box(-12, 1, -13.1, 8, 2, 0.2, VITRE)
			for i in 4:
				k.box(4 + i * 4, 0, 2, 2.5, 3.6, 12, Color("f1faee"))
				k.box(4 + i * 4, 0, -5.5, 2.5, 3.0, 2.6, Color("1d3557"))
		_:
			k.box(0, 0, 0, w * 0.8, 6, d * 0.8, TOLE)
