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
	"carriere": {"name": "Carrière", "w": 44, "d": 30, "access": ROAD, "emplois": 15, "cost": 1_500_000,
		"prod": {"kind": "extraction", "res": {"pierre": 300.0, "calcaire": 300.0, "granite": 90.0}, "radius": 40.0, "min": 0.15},
		"desc": "Concasseur, cribles, tas de granulats et pont-bascule. La fosse en gradins se creuse à côté, dans le périmètre d'extraction. Granulats, calcaire ou granite selon la roche."},
	"sabliere": {"name": "Sablière et gravière", "w": 32, "d": 24, "access": ROAD, "emplois": 8, "cost": 800_000,
		"prod": {"kind": "extraction", "res": {"sable": 200.0}, "radius": 60.0, "min": 0.15},
		"desc": "Crible, laveuse et tas de sable. La fosse peu profonde se creuse à côté : au bord d'une rivière, d'une plage ou dans le désert."},
	"argiliere": {"name": "Carrière d'argile", "w": 28, "d": 22, "access": ROAD, "emplois": 8, "cost": 700_000,
		"prod": {"kind": "extraction", "res": {"argile": 150.0}, "radius": 40.0, "min": 0.15},
		"desc": "Hangar et tas d'argile. La fosse se creuse à côté, dans les plaines basses et les zones humides."},
	"mine_ciel_ouvert": {"name": "Mine à ciel ouvert", "w": 50, "d": 40, "access": ROAD, "emplois": 120, "cost": 25_000_000,
		"prod": {"kind": "extraction", "res": {"fer": 1200.0, "charbon": 1500.0, "cuivre": 800.0, "or": 150.0, "bauxite": 1000.0},
			"radius": 80.0, "min": 0.15},
		"desc": "Grande fosse en gradins de 10 m, pelles géantes, tombereaux et verse à stériles. Plus de minerai qu'une mine souterraine, mais il faut un gisement proche de la surface."},
	"mine": {"name": "Mine souterraine", "w": 40, "d": 36, "access": ROAD, "emplois": 60, "cost": 8_000_000,
		"prod": {"kind": "extraction", "res": {"fer": 400.0, "charbon": 400.0, "cuivre": 250.0, "or": 80.0, "bauxite": 300.0},
			"radius": 60.0, "reserve": 600_000.0, "min": 0.08},
		"desc": "Chevalement, galeries et bâtiments. Extrait le meilleur minerai du sous-sol (fer, charbon, cuivre, or, bauxite) ; les stériles montent en terril à côté."},
	"mine_sel": {"name": "Mine de sel", "w": 36, "d": 30, "access": ROAD, "emplois": 30, "cost": 6_000_000,
		"prod": {"kind": "extraction", "res": {"sel": 500.0}, "radius": 60.0, "reserve": 1_500_000.0, "min": 0.1},
		"desc": "Puits, salles de sel et hangar de stockage. Sel de cuisine pour l'industrie alimentaire et sel de déneigement pour les routes."},
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
	"forage_irrigation": {"annee": 1910, "name": "Forage d'irrigation", "w": 14, "d": 12, "access": RP, "emplois": 2,
		"cost": 900_000, "prod": {"kind": "service", "irrigation": 400.0}, "reseaux": {"elec": 0.15, "eau": 0.0, "egout": 0.0, "gaz": 0.0},
		"desc": "Pompe électrique sur la nappe et canalisations : rend la terre cultivable à 400 m autour, même au désert. Gros consommateur de courant ; chaque ferme arrosée paie son eau (450 € par jour)."},
	"silo_cooperative": {"name": "Silo de coopérative agricole", "w": 30, "d": 24, "access": RP, "emplois": 4,
		"cost": 2_000_000, "prod": {"kind": "entrepot"},
		"desc": "Les fermes y apportent leurs récoltes (grain, colza, foin…) : un entrepôt pour toute la région."},
	# Cultures pérennes, plantations et élevages (champs et bêtes : Agriculture, Maj+F).
	"vignoble": {"annee": 0, "name": "Domaine viticole", "w": 30, "d": 24, "access": RP, "emplois": 6, "cost": 900_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 0.8}, "good": "raisin", "radius": 250.0, "min": 0.15},
		"desc": "Chai, pressoir et rangs de vigne sur les coteaux. Vendanges à la main avant 1975."},
	"verger": {"annee": 0, "name": "Verger (pommes, poires, agrumes)", "w": 28, "d": 22, "access": RP, "emplois": 8, "cost": 700_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 2.5}, "good": "fruits_legumes", "radius": 200.0, "min": 0.2},
		"desc": "Hangar de tri, chambre froide et arbres fruitiers (agrumes sous les climats chauds). Ruches pour la pollinisation."},
	"oliveraie": {"annee": 0, "name": "Oliveraie et moulin à huile", "w": 26, "d": 20, "access": RP, "emplois": 4, "cost": 600_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 0.25}, "good": "oleagineux", "radius": 250.0, "min": 0.1},
		"desc": "Mas, oliviers centenaires et moutons dans les rangs. Climats méditerranéens."},
	"plantation_tropicale": {"annee": 0, "name": "Plantation tropicale (café, cacao, thé, canne)", "w": 36, "d": 28, "access": RP,
		"emplois": 25, "cost": 1_000_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 0.4}, "good": "cafe", "radius": 300.0, "min": 0.2},
		"desc": "Séchoirs, hangars et cueilleurs. Café, cacao, thé ou canne à sucre selon le climat (subtropical, tropical)."},
	"houblonniere": {"annee": 0, "name": "Houblonnière et séchoir à tabac", "w": 30, "d": 24, "access": RP, "emplois": 6, "cost": 700_000,
		"prod": {"kind": "extraction", "res": {"fertilite": 0.2}, "good": "houblon", "radius": 250.0, "min": 0.2},
		"desc": "Hautes perches de houblon (pour les brasseries) et séchoir à tabac en bois."},
	"basse_cour": {"annee": 0, "name": "Basse-cour (canards, dindes, lapins)", "w": 24, "d": 20, "access": RP, "emplois": 3, "cost": 300_000,
		"prod": {"kind": "elevage"}, "desc": "Volières, mare, clapiers et poulailler."},
	"rucher": {"annee": 0, "name": "Rucher et miellerie", "w": 16, "d": 14, "access": RP, "emplois": 2, "cost": 120_000,
		"prod": {"kind": "elevage"}, "desc": "Ruches au milieu des prés et des vergers, miellerie pour l'extraction du miel."},
	"pisciculture": {"name": "Pisciculture (truites)", "w": 30, "d": 24, "access": RP, "emplois": 4, "cost": 800_000,
		"prod": {"kind": "elevage"}, "annee": 1850,
		"desc": "Bassins en eau courante et écloserie. Les poissons mangent du grain (granulés)."},
	"ranch_buffles": {"annee": 0, "name": "Ranch de buffles d'eau", "w": 34, "d": 26, "access": RP, "emplois": 4, "cost": 700_000,
		"prod": {"kind": "elevage"}, "desc": "Étables ouvertes et mares. Lait de bufflonne (mozzarella) et viande."},
	"elevage_andin": {"annee": 0, "name": "Élevage de lamas et d'alpagas", "w": 28, "d": 22, "access": RP, "emplois": 3, "cost": 400_000,
		"prod": {"kind": "elevage"}, "desc": "Enclos de pierre et abri de tonte. Laine fine et viande, en montagne."},
	"elevage_rennes": {"annee": 0, "name": "Élevage de rennes", "w": 28, "d": 22, "access": RP, "emplois": 3, "cost": 350_000,
		"prod": {"kind": "elevage"}, "desc": "Corral et kotas. Les rennes paissent le lichen des régions boréales."},
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
		"prod": {"kind": "transformation", "in": {"calcaire": 200.0, "argile": 50.0}, "out": {"ciment": 160.0}},
		"desc": "Calcaire et argile → clinker → ciment, dans un four rotatif."},
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
		"prod": {"kind": "transformation", "in": {"farine": 2.0, "sucre": 0.5, "fruits_legumes": 1.5, "laitages": 0.5, "sel": 0.1}, "out": {"epicerie": 6.0}},
		"desc": "Farine, sucre, légumes, laitages et sel → pâtes, conserves, biscuits, plats préparés."},
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
	# Industries des produits du terroir et des matériaux d'époque.
	"four_chaux": {"annee": 0, "name": "Four à chaux", "w": 22, "d": 18, "access": RP, "emplois": 8, "cost": 500_000,
		"prod": {"kind": "transformation", "in": {"calcaire": 20.0, "bois": 4.0}, "out": {"chaux": 11.0}},
		"desc": "Calcaire cuit au bois → chaux, le mortier des maçons d'avant le ciment."},
	"tuilerie": {"annee": 0, "name": "Tuilerie", "w": 32, "d": 24, "access": ROAD, "emplois": 15, "cost": 1_500_000,
		"prod": {"kind": "transformation", "in": {"argile": 40.0}, "out": {"tuiles": 34.0}},
		"desc": "Argile moulée et cuite → tuiles canal, plates et mécaniques pour les toits."},
	"cave_vinicole": {"annee": 0, "name": "Cave coopérative vinicole", "w": 30, "d": 22, "access": ROAD, "emplois": 10, "cost": 2_000_000,
		"prod": {"kind": "transformation", "in": {"raisin": 6.0, "verre": 0.6}, "out": {"boissons": 4.5}},
		"desc": "Pressoirs, cuves et chais : raisin → vin en bouteilles."},
	"distillerie": {"annee": 0, "name": "Distillerie", "w": 28, "d": 22, "access": ROAD, "emplois": 10, "cost": 2_500_000,
		"prod": {"kind": "transformation", "in": {"fruits_legumes": 2.0, "verre": 0.3}, "out": {"boissons": 1.5}},
		"desc": "Alambics de cuivre : fruits → eaux-de-vie et liqueurs."},
	"rhumerie": {"annee": 0, "name": "Sucrerie de canne et rhumerie", "w": 34, "d": 26, "access": ROAD, "emplois": 20, "cost": 3_000_000,
		"prod": {"kind": "transformation", "in": {"canne": 20.0}, "out": {"sucre": 2.0, "boissons": 0.6}},
		"desc": "Moulin à cannes, chaudières et colonnes : canne → sucre roux et rhum."},
	"chocolaterie": {"name": "Chocolaterie", "w": 28, "d": 22, "access": ROAD, "emplois": 30, "cost": 4_000_000,
		"prod": {"kind": "transformation", "in": {"cacao": 2.0, "sucre": 1.5, "lait": 0.8}, "out": {"chocolat": 4.0}},
		"annee": 1820, "desc": "Torréfaction, broyage et conchage : cacao + sucre + lait → tablettes et bonbons."},
	"torrefaction": {"annee": 0, "name": "Torréfaction de café", "w": 22, "d": 18, "access": ROAD, "emplois": 8, "cost": 1_200_000,
		"prod": {"kind": "transformation", "in": {"cafe": 1.0}, "out": {"epicerie": 0.85}},
		"desc": "Café vert grillé, moulu et ensaché pour les épiceries."},
	"fromagerie_alpage": {"annee": 0, "name": "Fromagerie d'alpage", "w": 20, "d": 16, "access": RP, "emplois": 4, "cost": 600_000,
		"prod": {"kind": "transformation", "in": {"lait": 1.2}, "out": {"laitages": 1.0}},
		"desc": "Chalet, chaudron de cuivre et cave d'affinage : lait → meules de gruyère et de tomme."},
	"conserverie": {"name": "Conserverie", "w": 34, "d": 26, "access": ROAD, "emplois": 40, "cost": 3_500_000,
		"prod": {"kind": "transformation", "in": {"fruits_legumes": 3.0, "acier": 0.3, "sel": 0.05}, "out": {"epicerie": 3.0}},
		"annee": 1810, "desc": "Boîtes en fer-blanc stérilisées (procédé Appert) : légumes, fruits et plats cuisinés."},
	"tannerie": {"annee": 0, "name": "Tannerie", "w": 28, "d": 22, "access": RP, "emplois": 12, "cost": 1_000_000,
		"prod": {"kind": "transformation", "in": {"betail": 1.0, "sel": 0.1}, "out": {"cuir": 0.3}},
		"desc": "Fosses à tan au bord de l'eau : peaux → cuir pour les chaussures, selles et sacs."},
	"manufacture_tabac": {"annee": 0, "name": "Manufacture de tabac", "w": 34, "d": 26, "access": ROAD, "emplois": 60, "cost": 3_000_000,
		"prod": {"kind": "transformation", "in": {"tabac": 1.0, "papier": 0.1}, "out": {"cigares": 0.9}},
		"desc": "Feuilles séchées, roulées et coupées → cigares et cigarettes (vendus à l'export)."},
	"horlogerie": {"annee": 0, "name": "Manufacture horlogère", "w": 24, "d": 18, "access": ROAD, "emplois": 50, "cost": 6_000_000,
		"prod": {"kind": "transformation", "in": {"acier": 0.05, "cuivre": 0.02, "verre": 0.01}, "out": {"montres": 0.03}},
		"desc": "Établis d'horlogers sous les grandes fenêtres : mouvements, boîtiers et cadrans → montres (export)."},
	"chantier_naval": {"annee": 0, "name": "Chantier naval", "w": 60, "d": 40, "access": ROAD, "emplois": 120, "cost": 15_000_000,
		"prod": {"kind": "transformation", "in": {"bois": 20.0, "acier": 10.0, "planches": 5.0}, "out": {"navires": 25.0}},
		"desc": "Cale de lancement et grue : bois puis acier → bateaux (export). Au bord de l'eau."},
	"usine_engrais": {"name": "Usine d'engrais", "w": 40, "d": 32, "access": ROAD, "emplois": 50, "cost": 12_000_000,
		"prod": {"kind": "transformation", "in": {"gaz": 12.0}, "out": {"engrais": 25.0}}, "annee": 1913,
		"desc": "Procédé Haber-Bosch : gaz naturel + azote de l'air → ammonitrate pour les champs."},
	"recyclerie_metaux": {"name": "Usine de recyclage des matériaux", "w": 40, "d": 30, "access": ROAD, "emplois": 40,
		"cost": 8_000_000, "annee": 1990,
		"prod": {"kind": "transformation", "in": {"balles_tri": 20.0}, "out": {"acier": 6.0, "papier": 6.0, "plastique": 3.0, "aluminium": 1.0}},
		"desc": "Balles du centre de tri → acier, aluminium, papier et plastique de nouveau utilisables."},
	"usine_batteries": {"name": "Usine de batteries", "w": 50, "d": 36, "access": ROAD, "emplois": 150, "cost": 40_000_000,
		"annee": 1991,
		"prod": {"kind": "transformation", "in": {"cuivre": 0.3, "aluminium": 0.6, "chimie": 1.0, "plastique": 0.3}, "out": {"batteries": 1.2}},
		"desc": "Cellules lithium-ion et packs pour les voitures électriques et le stockage de l'électricité."},
	# --- Logistique -------------------------------------------------------------------------
	"transporteur": {"name": "Entreprise de transport routier", "w": 40, "d": 30, "access": ROAD, "emplois": 20, "cost": 1_500_000,
		"prod": {"kind": "logistique"},
		"desc": "Parking de camions et bureaux. Ses chauffeurs-livreurs livrent toute la ville."},
}
## Ordre dans le panneau : de la ressource brute au produit fini.
const ORDER := ["exploitation_forestiere", "ferme_cereales", "ferme_maraichere", "ferme_betteraves", "ferme_fibres",
	"elevage", "ferme_laitiere", "vignoble", "verger", "oliveraie", "plantation_tropicale", "houblonniere",
	"basse_cour", "rucher", "pisciculture", "ranch_buffles", "elevage_andin", "elevage_rennes", "silo_cooperative",
	"concession_agricole", "forage_irrigation", "port_peche", "carriere", "sabliere", "argiliere", "mine_ciel_ouvert", "mine", "mine_sel", "puits",
	"scierie", "moulin", "fournil", "abattoir", "laiterie", "sucrerie", "huilerie", "filature", "usine_agro", "brasserie",
	"briqueterie", "cimenterie", "verrerie", "papeterie", "acierie", "fonderie_cuivre", "aluminerie", "raffinerie",
	"usine_chimique", "menuiserie", "usine_textile", "usine_hygiene", "labo_pharma", "usine_biens",
	"usine_electronique", "usine_auto", "four_chaux", "tuilerie", "cave_vinicole", "distillerie", "rhumerie",
	"chocolaterie", "torrefaction", "fromagerie_alpage", "conserverie", "tannerie", "manufacture_tabac", "horlogerie",
	"chantier_naval", "usine_engrais", "recyclerie_metaux", "usine_batteries", "transporteur"]


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
			# Installations : concasseur, convoyeur, cribles, tas de granulats,
			# pont-bascule et bureaux. La fosse est creusée à côté (Carrieres).
			k.plate(0, 0, w, d, GRAVIER)
			k.box(-14, 0, -6, 7, 5, 7, ACIER)
			k.box(-14, 5, -6, 8, 2.5, 5, Color("f4a261"))
			k.box(-14, 7.5, -6, 3, 1.5, 3, TOLE)
			k.box(-6, 4.5, -6, 10, 0.6, 1.2, Color("495057"))
			k.box(1, 0, -6, 5, 6, 4, ACIER)
			k.box(1, 6, -6, 5.6, 1.2, 4.6, TOLE)
			k.pyramid(-6, 0, 7, 9, 9, 5, Color("d6ccc2"))
			k.pyramid(4, 0, 7, 8, 8, 4.5, Color("bfb3a5"))
			k.pyramid(13, 0, 7, 7, 7, 3.5, Color("e9e4c9"))
			k.plate(14, -9, 4, 12, Color("495057"), 0.0, 0.2)
			k.box(14, 0, -2, 3, 3, 3, Color("e9ecef"))
			k.box(-17, 0, 9, 7, 3, 4, Color("e9ecef"))
			k.box(-17, 3, 9, 7.4, 0.3, 4.4, Color("6c757d"))
		"sabliere":
			k.plate(0, 0, w, d, Color("e6d3a3"))
			k.box(-8, 0, -4, 6, 4, 4, ACIER)
			k.box(-8, 4, -4, 7, 1.6, 5, Color("f4a261"))
			k.box(-2, 3.2, -4, 7, 0.5, 1.0, Color("495057"))
			k.pyramid(5, 0, -4, 8, 8, 4, Color("f4d58d"))
			k.pyramid(5, 0, 6, 7, 7, 3.5, Color("cbbf9f"))
			k.plate(-8, 7, 8, 6, Color("6c9bc0"), 0.0, 0.1)
			k.box(12, 0, 8, 4, 3, 3, Color("e9ecef"))
		"argiliere":
			k.plate(0, 0, w, d, Color("b07d50"))
			k.pyramid(-6, 0, -4, 9, 9, 4, Color("bc6c25"))
			k.pyramid(3, 0, 5, 7, 7, 3, Color("a0522d"))
			k.box(8, 0, -5, 8, 3.5, 7, TOLE)
			k.gable(8, 3.5, -5, 8.6, 7.6, 1.8, Color("6c757d"))
			k.box(-9, 0, 7, 4, 3, 3, Color("e9ecef"))
		"mine_ciel_ouvert":
			k.plate(0, 0, w, d, Color("8d7f6e"))
			# Concasseur primaire, convoyeur, silo de chargement, atelier des engins.
			k.box(-16, 0, -8, 9, 8, 9, ACIER)
			k.box(-16, 8, -8, 10, 3, 7, Color("f4a261"))
			k.box(-6, 6, -8, 14, 0.8, 1.6, Color("495057"))
			k.cylinder(4, 0, -8, 4, 4, 14, 12, Color("adb5bd"))
			k.cylinder(4, 14, -8, 4.2, 0.6, 3, 12, Color("6c757d"))
			k.box(14, 0, -8, 14, 9, 12, TOLE)
			k.gable(14, 9, -8, 14.6, 12.6, 3, Color("5b5f66"))
			k.pyramid(-12, 0, 11, 14, 12, 7, Color("6b4f3a"))
			k.box(10, 0, 12, 10, 3.5, 6, Color("e9ecef"))
			k.box(10, 3.5, 12, 10.4, 0.3, 6.4, Color("6c757d"))
		"mine_sel":
			k.plate(0, 0, w, d, Color("b7b2a8"))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					k.box(-8 + sx * 2.2, 0, -5 + sz * 2.2, 0.5, 18, 0.5, ACIER)
			k.box(-8, 18, -5, 5.4, 0.9, 5.4, ACIER)
			k.cylinder(-8, 19, -7, 1.8, 1.8, 0.4, 10, TOLE_ROUGE)
			k.box(-8, 0, -5, 6, 4, 6, BRIQUE)
			# Grand hangar en dôme où l'on stocke le sel.
			k.box(7, 0, 3, 16, 4, 18, BETON)
			k.gable(7, 4, 3, 16.6, 18.6, 6, Color("d9d9d9"), false)
			k.pyramid(7, 0, -11, 8, 6, 3, Color("f8f9fa"))
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
		"forage_irrigation":
			k.plate(0, 0, w, d, GRAVIER)
			k.box(-3, 0, -2, 5, 3.2, 4, Color("e9ecef"))
			k.gable(-3, 3.2, -2, 5.4, 4.4, 1.2, TOLE)
			k.cylinder(3.5, 0, 1.5, 1.8, 1.8, 4.5, 10, Color("90a4ae"))
			k.cylinder(3.5, 4.5, 1.5, 1.9, 0.2, 0.6, 10, Color("78909c"))
			k.box(-0.5, 0, 3.5, 8, 0.5, 0.5, EAU)
			k.box(-6, 0, -4.5, 0.4, 5.5, 0.4, ACIER)
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
			if not _build_terroir(k, id, w, d):
				k.box(0, 0, 0, w * 0.8, 6, d * 0.8, TOLE)


## Modèles des fermes pérennes, élevages et industries du terroir.
static func _build_terroir(k: BlocMesh, id: String, w: float, d: float) -> bool:
	match id:
		"vignoble":
			k.plate(0, 0, w, d, Color("8a6d4a"))
			k.box(-7, 0, -5, 12, 6, 9, Color("e9dcc0"))
			k.gable(-7, 6, -5, 12.6, 9.6, 2.6, Color("b5523b"))
			for i in 6:
				k.box(-12 + i * 4.5, 0, 7, 0.5, 1.4, 8, Color("4c6b2f"))
			for i in 3:
				k.cylinder(6 + i * 2.2, 0, -6, 0.9, 0.9, 1.6, 10, Color("7f5539"))
		"verger":
			k.plate(0, 0, w, d, HERBE)
			k.box(-7, 0, -5, 10, 5, 8, BOIS_C)
			k.gable(-7, 5, -5, 10.6, 8.6, 2.2, TOLE)
			for i in 4:
				for j in 2:
					k.tree(1 + i * 3.5, 3 + j * 5, 0.8, Color("6a994e"))
		"oliveraie":
			k.plate(0, 0, w, d, Color("c2b280"))
			k.box(-5, 0, -4, 11, 5, 8, Color("f1e3c6"))
			k.gable(-5, 5, -4, 11.6, 8.6, 2.0, Color("c8553d"))
			for p in [Vector2(6, -5), Vector2(9, 2), Vector2(4, 6), Vector2(-6, 6), Vector2(-10, 1)]:
				k.tree(p.x, p.y, 0.7, Color("8a9a5b"))
		"plantation_tropicale":
			k.plate(0, 0, w, d, Color("7a5c3e"))
			k.box(-8, 0, -6, 14, 5, 10, Color("e9c46a"))
			k.gable(-8, 5, -6, 14.6, 10.6, 3, Color("6c584c"))
			k.plate(8, -4, 12, 10, Color("6f1d1b"), 0.0, 0.15)
			for i in 5:
				k.tree(-10 + i * 5, 10, 0.9, Color("2d6a4f"))
		"houblonniere":
			k.plate(0, 0, w, d, Color("8a6d4a"))
			for i in 4:
				for j in 3:
					k.box(-10 + i * 4, 0, 2 + j * 4, 0.25, 7, 0.25, BOIS_C)
			k.box(-10, 7, 6, 13, 0.1, 9, Color("90a955"))
			k.box(9, 0, -5, 8, 8, 8, Color("6f4e37"))
			k.gable(9, 8, -5, 8.6, 8.6, 3, Color("3d3d3d"))
		"basse_cour":
			k.plate(0, 0, w, d, HERBE)
			k.box(-5, 0, -5, 10, 3.5, 6, BOIS_C)
			k.gable(-5, 3.5, -5, 10.6, 6.6, 1.8, TOLE_ROUGE)
			k.plate(5, 4, 8, 6, EAU, 0.0, 0.1)
			for i in 4:
				k.box(-8 + i * 2.4, 0, 5, 2.0, 1.4, 1.4, Color("a0704a"))
		"rucher":
			k.plate(0, 0, w, d, HERBE)
			k.box(-4, 0, -3, 6, 3.2, 5, Color("e9dcc0"))
			k.gable(-4, 3.2, -3, 6.4, 5.4, 1.4, TOLE_ROUGE)
			for i in 6:
				k.box(-5 + i * 2.0, 0, 4, 1.0, 1.1, 0.9, Color("f2c14e") if i % 2 == 0 else Color("e9ecef"))
		"pisciculture":
			k.plate(0, 0, w, d, BETON)
			for i in 4:
				k.plate(-9 + i * 6, 2, 4.5, 14, EAU, 0.0, 0.15)
			k.box(9, 0, -8, 8, 4, 6, Color("dbe9ee"))
			k.box(9, 4, -8, 8.4, 0.4, 6.4, TOLE)
		"ranch_buffles":
			k.plate(0, 0, w, d, HERBE)
			k.box(-6, 0, -5, 16, 5, 9, BOIS_C)
			k.gable(-6, 5, -5, 16.6, 9.6, 2.6, Color("6c584c"))
			k.plate(8, 6, 10, 8, Color("6c7a4f"), 0.0, 0.1)
			for x in [-14.0, 14.0]:
				k.box(x, 0, 6, 0.25, 1.2, 12, BOIS_C)
		"elevage_andin", "elevage_rennes":
			var andin := id == "elevage_andin"
			k.plate(0, 0, w, d, Color("a3b18a") if andin else Color("cad2c5"))
			if andin:
				k.box(-5, 0, -4, 9, 3, 7, Color("b7b7a4"))
				k.gable(-5, 3, -4, 9.6, 7.6, 1.6, Color("bc6c25"))
			else:
				for p in [Vector2(-6, -4), Vector2(-1, -6)]:
					k.cylinder(p.x, 0, p.y, 2.2, 0.2, 4.5, 8, Color("6f4e37"))
			for x in [-12.0, 12.0]:
				k.box(x, 0, 5, 0.4, 1.0, 10, Color("8d99ae") if andin else BOIS_C)
			k.box(0, 0, 10, 24, 1.0, 0.4, Color("8d99ae") if andin else BOIS_C)
		"four_chaux":
			k.plate(0, 0, w, d, GRAVIER)
			k.cylinder(-3, 0, 0, 4.5, 3.2, 9, 10, Color("d6ccc2"))
			k.cylinder(-3, 9, 0, 1.4, 1.2, 3, 8, Color("8d7f6e"))
			k.pyramid(6, 0, 5, 6, 6, 3, Color("e9e4c9"))
			k.box(6, 0, -5, 5, 3, 4, BOIS_C)
		"tuilerie", "fromagerie_alpage", "tannerie", "torrefaction", "distillerie", "cave_vinicole", "horlogerie", \
				"chocolaterie", "conserverie", "manufacture_tabac", "rhumerie":
			var col := {"tuilerie": BRIQUE, "fromagerie_alpage": Color("ddb892"), "tannerie": Color("a98467"),
				"torrefaction": Color("e6ccb2"), "distillerie": Color("e9dcc0"), "cave_vinicole": Color("f1e3c6"),
				"horlogerie": Color("f8f9fa"), "chocolaterie": Color("e6ccb2"), "conserverie": Color("dee2e6"),
				"manufacture_tabac": Color("e9c46a"), "rhumerie": Color("f1e3c6")}[id] as Color
			var roof := {"tuilerie": Color("c8553d"), "fromagerie_alpage": Color("6f4e37"), "tannerie": TOLE,
				"torrefaction": Color("8c4a3a"), "distillerie": Color("8c4a3a"), "cave_vinicole": Color("c8553d"),
				"horlogerie": Color("5c677d"), "chocolaterie": Color("6f1d1b"), "conserverie": TOLE,
				"manufacture_tabac": Color("8c4a3a"), "rhumerie": Color("6c584c")}[id] as Color
			k.plate(0, 0, w, d, GRAVIER if id in ["tuilerie", "tannerie"] else BETON)
			k.box(-2, 0, 0, w * 0.6, 6.5, d * 0.6, col)
			k.gable(-2, 6.5, 0, w * 0.6 + 0.6, d * 0.6 + 0.6, 2.4, roof)
			k.box(-2, 1.0, -d * 0.3 - 0.05, w * 0.4, 2.2, 0.2, VITRE)
			match id:
				"tuilerie", "rhumerie", "distillerie":
					k.cylinder(w * 0.32, 0, -d * 0.25, 1.1, 0.9, 16, 8, BRIQUE)
				"tannerie":
					for i in 3:
						k.plate(w * 0.3, -d * 0.3 + i * 4.0, 3, 3, Color("6f4e37"), 0.0, 0.3)
				"cave_vinicole":
					for i in 3:
						k.cylinder(w * 0.34, 0, -d * 0.25 + i * 3.5, 1.4, 1.4, 6, 12, Color("ced4da"))
				_:
					k.box(w * 0.3, 0, d * 0.2, 4, 3.5, 4, ACIER)
		"chantier_naval":
			k.plate(0, 0, w, d, BETON)
			k.box(-6, 0, -6, 30, 14, 16, Color("adb5bd"))
			k.gable(-6, 14, -6, 30.6, 16.6, 4, ACIER)
			k.box(14, 0, 8, 22, 3, 7, Color("1d3557"))
			k.box(14, 3, 8, 14, 3, 5, Color("e63946"))
			k.box(24, 0, -10, 1.2, 26, 1.2, Color("f4a261"))
			k.box(19, 26, -10, 12, 1, 1, Color("f4a261"))
		"usine_engrais", "usine_batteries", "recyclerie_metaux":
			k.plate(0, 0, w, d, BETON)
			k.box(-4, 0, 0, w * 0.55, 10, d * 0.6, Color("e9ecef") if id != "recyclerie_metaux" else Color("90be6d"))
			k.box(-4, 10, 0, w * 0.55 + 0.4, 0.5, d * 0.6 + 0.4, Color("2a9d8f") if id == "usine_batteries" else TOLE)
			if id == "usine_engrais":
				for i in 2:
					k.cylinder(w * 0.3, 0, -d * 0.25 + i * 8.0, 2.4, 2.0, 22, 12, Color("f8f9fa"))
			elif id == "recyclerie_metaux":
				for i in 4:
					k.box(w * 0.3, 0, -d * 0.3 + i * 3.6, 3, 2, 3, CAR_COLS[i % CAR_COLS.size()])
			else:
				k.box(w * 0.3, 0, 0, 8, 4, 10, Color("adb5bd"))
		_:
			return false
	return true
