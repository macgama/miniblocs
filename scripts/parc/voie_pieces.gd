class_name VoiePieces
extends RefCounted
## Attractions sur voie du parc de loisirs : grands-huit, attractions
## aquatiques et toboggans, construits pièce par pièce depuis la gare.
##
## Une attraction = une famille (FAMILLES) et une suite de pièces (PIECES).
## Le tracé se calcule comme un petit véhicule qu'on fait avancer : position,
## cap (yaw), pente (pitch) et roulis (bank). Chaque pièce dit comment ces
## angles changent sur sa longueur (courbes en S douces : la courbure part de
## zéro et y revient, comme les clothoïdes des vrais tracés).
##
## Repère local de l'attraction = repère du bâtiment de la gare : sol en y = 0,
## façade (entrée des visiteurs) vers −Z ; la voie traverse la gare dans le
## sens +X, à l'arrière du quai.
##
## Le relevé des virages est automatique (calculé d'après la vitesse, voir
## VoiePhysique) ; les figures (vrilles, tire-bouchons) ajoutent leur roulis.

## genre : "rail" (grands-huit), "eau" (bateaux dans un canal), "glisse" (toboggan, parcours ouvert).
## pente_max : pente la plus forte permise (degrés) ; inversions : loopings et vrilles permis.
## places : par voiture ; voitures : par train (réglable) ; lv : longueur d'une voiture (m).
## mu, air : frottements (roulement, air) ; courant : vitesse minimale sur le plat (eau) ;
## chaine : vitesse de la chaîne (m/s) ; releve_max : relevé maximal des virages (degrés).
## gare : longueur de la gare (m) ; h_gare : hauteur de la voie en gare (m).
## m_prix : prix de la voie par mètre (€) ; gare_prix : prix de la gare.
const FAMILLES := {
	"acier": {"nom": "Grand-huit en acier", "genre": "rail", "pente_max": 90, "inversions": true, "places": 4, "voitures": 6,
		"lv": 2.6, "mu": 0.010, "air": 0.0007, "chaine": 3.6, "releve_max": 85.0, "gare": 24.0, "h_gare": 1.1,
		"m_prix": 9000, "gare_prix": 900_000, "icone": "acier",
		"desc": "Rails tubulaires, loopings, vrilles et tire-bouchons. Tout est permis, sauf la timidité."},
	"bois": {"nom": "Grand-huit en bois", "genre": "rail", "pente_max": 45, "inversions": false, "places": 4, "voitures": 6,
		"lv": 2.6, "mu": 0.016, "air": 0.0008, "chaine": 3.2, "releve_max": 50.0, "gare": 24.0, "h_gare": 1.1,
		"m_prix": 7000, "gare_prix": 800_000, "icone": "bois",
		"desc": "Charpente en treillis, bosses et virages serrés. Ça craque, ça secoue, c'est normal."},
	"mine": {"nom": "Train de la mine", "genre": "rail", "pente_max": 25, "inversions": false, "places": 4, "voitures": 7,
		"lv": 2.4, "mu": 0.014, "air": 0.0008, "chaine": 3.0, "releve_max": 35.0, "gare": 22.0, "h_gare": 1.0,
		"m_prix": 5000, "gare_prix": 600_000, "icone": "mine",
		"desc": "Wagonnets, tunnels et virages au ras des rochers. Le grand-huit des familles."},
	"familial": {"nom": "Grand-huit junior", "genre": "rail", "pente_max": 25, "inversions": false, "places": 2, "voitures": 8,
		"lv": 1.8, "mu": 0.014, "air": 0.0008, "chaine": 2.6, "releve_max": 30.0, "gare": 18.0, "h_gare": 0.9,
		"m_prix": 3500, "gare_prix": 350_000, "icone": "familial",
		"desc": "Petites voitures en forme de chenille, à hauteur d'enfant. Les parents crient quand même."},
	"suspendu": {"nom": "Grand-huit suspendu", "genre": "rail", "pente_max": 90, "inversions": true, "places": 4, "voitures": 7,
		"lv": 2.6, "mu": 0.011, "air": 0.0008, "chaine": 3.4, "releve_max": 90.0, "gare": 24.0, "h_gare": 4.8, "suspendu": true,
		"m_prix": 11000, "gare_prix": 1_100_000, "icone": "suspendu",
		"desc": "Les sièges pendent sous le rail, les pieds dans le vide. Inversions permises."},
	"lance": {"nom": "Grand-huit lancé", "genre": "rail", "pente_max": 90, "inversions": true, "places": 4, "voitures": 5,
		"lv": 2.6, "mu": 0.010, "air": 0.0007, "chaine": 3.6, "releve_max": 85.0, "gare": 24.0, "h_gare": 1.1,
		"m_prix": 10000, "gare_prix": 1_000_000, "icone": "lance",
		"desc": "Pas de chaîne : un lanceur propulse le train à 100 km/h en trois secondes."},
	"buches": {"nom": "Bûches", "genre": "eau", "pente_max": 45, "inversions": false, "places": 4, "voitures": 1,
		"lv": 4.2, "mu": 0.020, "air": 0.0012, "chaine": 2.8, "courant": 2.2, "releve_max": 0.0, "gare": 20.0, "h_gare": 0.0,
		"m_prix": 6000, "gare_prix": 700_000, "trains": 6, "icone": "buches",
		"desc": "Troncs flottants dans un canal, un tapis qui monte et une chute qui mouille le premier rang."},
	"riviere": {"nom": "Rivière à bouées", "genre": "eau", "pente_max": 25, "inversions": false, "places": 8, "voitures": 1,
		"lv": 4.0, "mu": 0.024, "air": 0.0015, "chaine": 2.4, "courant": 2.6, "releve_max": 0.0, "gare": 20.0, "h_gare": 0.0,
		"m_prix": 7500, "gare_prix": 800_000, "trains": 8, "large": true, "icone": "riviere",
		"desc": "Bouées rondes de huit places qui tournent dans les rapides. Personne ne ressort sec."},
	"splash": {"nom": "Bateau splash", "genre": "eau", "pente_max": 45, "inversions": false, "places": 20, "voitures": 1,
		"lv": 8.0, "mu": 0.018, "air": 0.0010, "chaine": 3.0, "courant": 2.0, "releve_max": 0.0, "gare": 24.0, "h_gare": 0.0,
		"m_prix": 6500, "gare_prix": 900_000, "trains": 2, "icone": "splash",
		"desc": "Un grand bateau, une longue montée et une seule descente. La vague arrose aussi le pont des spectateurs."},
	"toboggan": {"nom": "Toboggan aquatique", "genre": "glisse", "pente_max": 45, "inversions": false, "places": 1, "voitures": 1,
		"lv": 1.6, "mu": 0.10, "air": 0.0045, "chaine": 0.0, "courant": 1.4, "releve_max": 60.0, "gare": 6.0, "h_gare": 12.0, "ouvert": true,
		"m_prix": 2500, "gare_prix": 350_000, "trains": 6, "icone": "toboggan",
		"desc": "Une tour, un tube qui serpente et un bassin d'arrivée. Parcours ouvert : on remonte à pied."},
	# --- Attractions d'avant-guerre (lot du 2026-11-17). « base » : famille dont elles
	# reprennent le dessin (voie, piliers, voitures, gare).
	"panoramique": {"nom": "Montagnes russes panoramiques", "genre": "rail", "pente_max": 30, "inversions": false, "places": 4, "voitures": 4,
		"lv": 2.4, "mu": 0.014, "air": 0.0008, "chaine": 3.0, "releve_max": 25.0, "gare": 22.0, "h_gare": 1.1,
		"m_prix": 4000, "gare_prix": 450_000, "icone": "bois", "base": "bois",
		"desc": "Le grand-huit de la Belle Époque : voie en bois, décors peints et un serre-freins debout dans chaque train."},
	"bobsleigh": {"nom": "Bobsleigh", "genre": "rail", "pente_max": 40, "inversions": false, "places": 2, "voitures": 4,
		"lv": 2.2, "mu": 0.015, "air": 0.0008, "chaine": 3.0, "releve_max": 85.0, "gare": 20.0, "h_gare": 1.1,
		"m_prix": 6000, "gare_prix": 600_000, "icone": "bois", "base": "bois",
		"desc": "Une gouttière en bois où les luges filent librement et montent sur les parois des virages (1929)."},
	"train_fantome": {"nom": "Train fantôme", "genre": "rail", "pente_max": 10, "inversions": false, "places": 2, "voitures": 2,
		"lv": 1.8, "mu": 0.014, "air": 0.0008, "chaine": 2.6, "releve_max": 10.0, "gare": 16.0, "h_gare": 0.9,
		"m_prix": 2500, "gare_prix": 300_000, "icone": "mine", "base": "familial",
		"desc": "Petites voitures qui cognent les portes d'un tunnel sombre : squelettes, toiles d'araignée et cris garantis."},
	"moulin": {"nom": "Tunnel de l'amour", "genre": "eau", "pente_max": 10, "inversions": false, "places": 4, "voitures": 1,
		"lv": 3.6, "mu": 0.026, "air": 0.0012, "chaine": 1.8, "courant": 1.4, "releve_max": 0.0, "gare": 18.0, "h_gare": 0.0,
		"m_prix": 3500, "gare_prix": 400_000, "trains": 6, "icone": "buches", "base": "buches",
		"desc": "Barques lentes dans un canal couvert, une petite chute au moulin. Romantique, et humide au premier rang."},
	"tour_glissade": {"nom": "Tour de glissade", "genre": "glisse", "pente_max": 35, "inversions": false, "places": 1, "voitures": 1,
		"lv": 1.4, "mu": 0.14, "air": 0.0045, "chaine": 0.0, "courant": 1.2, "releve_max": 45.0, "gare": 5.0, "h_gare": 10.0, "ouvert": true,
		"m_prix": 1500, "gare_prix": 200_000, "trains": 6, "icone": "toboggan", "base": "toboggan",
		"desc": "Une tour en bois et sa glissade en spirale, sur un paillasson. Le grand frisson de la fête foraine de 1905."},
	# --- Lot 4 : la première attraction du genre (1817) et celles d'aujourd'hui.
	"promenades": {"nom": "Promenades aériennes", "genre": "rail", "pente_max": 25, "inversions": false, "places": 2, "voitures": 2,
		"lv": 2.4, "mu": 0.014, "air": 0.0008, "chaine": 3.0, "releve_max": 20.0, "gare": 20.0, "h_gare": 1.1,
		"m_prix": 3000, "gare_prix": 300_000, "icone": "bois", "base": "bois",
		"desc": "Des chariots à roulettes calés sur une rampe en bois descendent en tournant autour d'un pavillon (Paris, 1817)."},
	"tournant": {"nom": "Grand-huit à voitures tournantes", "genre": "rail", "pente_max": 30, "inversions": false, "places": 4, "voitures": 4,
		"lv": 2.4, "mu": 0.014, "air": 0.0008, "chaine": 3.0, "releve_max": 30.0, "gare": 20.0, "h_gare": 1.0,
		"m_prix": 6000, "gare_prix": 700_000, "icone": "familial", "base": "familial",
		"desc": "Chaque voiture pivote librement sur elle-même dans les virages : jamais deux tours pareils (1997)."},
	"luge_ete": {"nom": "Luge d'été sur rail", "genre": "rail", "pente_max": 30, "inversions": false, "places": 2, "voitures": 4,
		"lv": 2.4, "mu": 0.014, "air": 0.0008, "chaine": 3.0, "releve_max": 35.0, "gare": 16.0, "h_gare": 0.9,
		"m_prix": 2500, "gare_prix": 250_000, "icone": "familial", "base": "familial",
		"desc": "Une luge à deux places sur un rail en inox qui dévale la montagne ; chacun freine quand il veut (1996)."},
	"aile": {"nom": "Grand-huit à ailes", "genre": "rail", "pente_max": 90, "inversions": true, "places": 4, "voitures": 6,
		"lv": 2.6, "mu": 0.010, "air": 0.0007, "chaine": 3.6, "releve_max": 85.0, "gare": 24.0, "h_gare": 1.1,
		"m_prix": 12000, "gare_prix": 1_300_000, "icone": "acier", "base": "acier",
		"desc": "Les sièges sont de part et d'autre du rail, rien au-dessus ni en dessous : on vole (2007)."},
	"realite_virtuelle": {"nom": "Grand-huit en réalité virtuelle", "genre": "rail", "pente_max": 90, "inversions": true, "places": 4, "voitures": 6,
		"lv": 2.6, "mu": 0.010, "air": 0.0007, "chaine": 3.6, "releve_max": 85.0, "gare": 24.0, "h_gare": 1.1,
		"m_prix": 10000, "gare_prix": 1_200_000, "icone": "acier", "base": "acier",
		"desc": "Un casque sur les yeux : le grand-huit devient vol de dragon ou descente dans l'espace (2016)."},
}
const ORDRE_RAIL := ["acier", "bois", "mine", "familial", "suspendu", "lance", "panoramique", "bobsleigh", "train_fantome",
	"promenades", "tournant", "luge_ete", "aile", "realite_virtuelle"]
const ORDRE_EAU := ["buches", "riviere", "splash", "toboggan", "moulin", "tour_glissade"]

## Pièces. L : longueur (m). p0 : pente d'entrée imposée (absent = toute pente
## permise, la pièce la garde). p1 : pente de sortie. yaw : changement de cap
## (degrés, + = à gauche). bosse : amplitude d'une bosse de pente (degrés,
## sin 2πt : monte puis redescend ; négatif = creux). roll : tour de roulis (degrés).
## decal : décalage latéral (m, loopings). releve : virage relevé automatiquement.
## fin_yaw : cap ajouté en sortie (figures qui retournent le train, p. ex. Immelmann).
## pente_tour : pente d'un virage en montée ou en descente (garde la pente courante).
## inv : nombre d'inversions. special : "freins", "lanceur", "tunnel", "eclabousse",
## "rapides", "tourbillon", "arrivee". genres : familles de voie permises.
const PIECES := {
	"droit_court": {"nom": "Droit court", "groupe": "droits", "L": 4.0},
	"droit": {"nom": "Droit", "groupe": "droits", "L": 8.0},
	"droit_long": {"nom": "Droit long", "groupe": "droits", "L": 16.0},
	"virage_g": {"nom": "Virage à gauche", "groupe": "virages", "L": 16.0, "yaw": 90.0, "releve": true, "pente_tour": true},
	"virage_d": {"nom": "Virage à droite", "groupe": "virages", "L": 16.0, "yaw": -90.0, "releve": true, "pente_tour": true},
	"virage_g_large": {"nom": "Grand virage à gauche", "groupe": "virages", "L": 32.0, "yaw": 90.0, "releve": true, "pente_tour": true},
	"virage_d_large": {"nom": "Grand virage à droite", "groupe": "virages", "L": 32.0, "yaw": -90.0, "releve": true, "pente_tour": true},
	"virage_g_45": {"nom": "Courbe à gauche (45°)", "groupe": "virages", "L": 12.0, "yaw": 45.0, "releve": true, "pente_tour": true},
	"virage_d_45": {"nom": "Courbe à droite (45°)", "groupe": "virages", "L": 12.0, "yaw": -45.0, "releve": true, "pente_tour": true},
	"demi_tour_g": {"nom": "Demi-tour à gauche", "groupe": "virages", "L": 36.0, "yaw": 180.0, "releve": true, "pente_tour": true},
	"demi_tour_d": {"nom": "Demi-tour à droite", "groupe": "virages", "L": 36.0, "yaw": -180.0, "releve": true, "pente_tour": true},
	"helice_g": {"nom": "Hélice à gauche (descend)", "groupe": "virages", "L": 80.0, "yaw": 360.0, "bosse_desc": -9.0, "releve": true, "p0": 0, "p1": 0},
	"helice_d": {"nom": "Hélice à droite (descend)", "groupe": "virages", "L": 80.0, "yaw": -360.0, "bosse_desc": -9.0, "releve": true, "p0": 0, "p1": 0},
	"montee": {"nom": "Début de montée", "groupe": "pentes", "L": 10.0, "p0": 0, "p1": 25},
	"fin_montee": {"nom": "Fin de montée", "groupe": "pentes", "L": 10.0, "p0": 25, "p1": 0},
	"descente": {"nom": "Début de descente", "groupe": "pentes", "L": 10.0, "p0": 0, "p1": -25},
	"fin_descente": {"nom": "Fin de descente", "groupe": "pentes", "L": 12.0, "p0": -25, "p1": 0},
	"raidir_haut": {"nom": "Montée raide", "groupe": "pentes", "L": 8.0, "p0": 25, "p1": 45},
	"adoucir_haut": {"nom": "Montée adoucie", "groupe": "pentes", "L": 8.0, "p0": 45, "p1": 25},
	"raidir_bas": {"nom": "Descente raide", "groupe": "pentes", "L": 8.0, "p0": -25, "p1": -45},
	"adoucir_bas": {"nom": "Descente adoucie", "groupe": "pentes", "L": 10.0, "p0": -45, "p1": -25},
	"vertical_haut": {"nom": "Montée verticale", "groupe": "pentes", "L": 8.0, "p0": 45, "p1": 90},
	"quitter_vertical_haut": {"nom": "Sortie de verticale (montée)", "groupe": "pentes", "L": 8.0, "p0": 90, "p1": 45},
	"vertical_bas": {"nom": "Chute verticale", "groupe": "pentes", "L": 8.0, "p0": -45, "p1": -90},
	"quitter_vertical_bas": {"nom": "Sortie de chute verticale", "groupe": "pentes", "L": 10.0, "p0": -90, "p1": -45},
	"sommet": {"nom": "Sommet en chapeau", "groupe": "pentes", "L": 30.0, "p0": 90, "p1": -90},
	"bosse": {"nom": "Bosse (airtime)", "groupe": "figures", "L": 24.0, "p0": 0, "p1": 0, "bosse": 24.0},
	"grande_bosse": {"nom": "Grande bosse", "groupe": "figures", "L": 44.0, "p0": 0, "p1": 0, "bosse": 32.0},
	"creux": {"nom": "Creux", "groupe": "figures", "L": 24.0, "p0": 0, "p1": 0, "bosse": -22.0},
	"looping": {"nom": "Looping", "groupe": "figures", "L": 52.0, "p0": 0, "p1": 360, "decal": 5.0, "inv": 1},
	"petit_looping": {"nom": "Petit looping", "groupe": "figures", "L": 36.0, "p0": 0, "p1": 360, "decal": 4.0, "inv": 1},
	"vrille_g": {"nom": "Vrille à gauche", "groupe": "figures", "L": 22.0, "p0": 0, "p1": 0, "roll": -360.0, "inv": 1},
	"vrille_d": {"nom": "Vrille à droite", "groupe": "figures", "L": 22.0, "p0": 0, "p1": 0, "roll": 360.0, "inv": 1},
	"tire_bouchon_g": {"nom": "Tire-bouchon à gauche", "groupe": "figures", "L": 34.0, "p0": 0, "p1": 0, "yaw": 90.0, "bosse": 18.0, "roll": -360.0, "inv": 1},
	"tire_bouchon_d": {"nom": "Tire-bouchon à droite", "groupe": "figures", "L": 34.0, "p0": 0, "p1": 0, "yaw": -90.0, "bosse": 18.0, "roll": 360.0, "inv": 1},
	"immelmann_g": {"nom": "Immelmann (sort à gauche)", "groupe": "figures", "L": 44.0, "p0": 0, "p1": 180, "roll_fin": -180.0, "fin_yaw": 180.0, "decal": 6.0, "inv": 1},
	"immelmann_d": {"nom": "Immelmann (sort à droite)", "groupe": "figures", "L": 44.0, "p0": 0, "p1": 180, "roll_fin": 180.0, "fin_yaw": 180.0, "decal": -6.0, "inv": 1},
	"plongeon_g": {"nom": "Plongeon (dive loop) à gauche", "groupe": "figures", "L": 44.0, "p0": 0, "p1": -180, "roll_debut": -180.0, "fin_yaw": 180.0, "decal": 6.0, "inv": 1},
	"plongeon_d": {"nom": "Plongeon (dive loop) à droite", "groupe": "figures", "L": 44.0, "p0": 0, "p1": -180, "roll_debut": 180.0, "fin_yaw": 180.0, "decal": -6.0, "inv": 1},
	"freins": {"nom": "Freins", "groupe": "special", "L": 8.0, "p0": 0, "p1": 0, "special": "freins", "genres": ["rail", "glisse"]},
	"lanceur": {"nom": "Lanceur (100 km/h)", "groupe": "special", "L": 30.0, "p0": 0, "p1": 0, "special": "lanceur", "genres": ["rail"]},
	"tunnel": {"nom": "Tunnel décoré", "groupe": "special", "L": 16.0, "special": "tunnel"},
	"eclabousse": {"nom": "Éclaboussure", "groupe": "special", "L": 14.0, "p0": 0, "p1": 0, "special": "eclabousse", "genres": ["eau"]},
	"rapides": {"nom": "Rapides", "groupe": "special", "L": 16.0, "p0": 0, "p1": 0, "special": "rapides", "genres": ["eau"]},
	"tourbillon": {"nom": "Tourbillon", "groupe": "special", "L": 16.0, "p0": 0, "p1": 0, "special": "tourbillon", "genres": ["eau"]},
	"arrivee": {"nom": "Bassin d'arrivée", "groupe": "special", "L": 10.0, "p0": 0, "p1": 0, "special": "arrivee", "genres": ["glisse"]},
}
const GROUPES := [["droits", "Droits"], ["virages", "Virages"], ["pentes", "Pentes"], ["figures", "Figures"], ["special", "Spécial"]]
## Pentes permises (degrés).
const PENTES := [-90, -45, -25, 0, 25, 45, 90]
## Pas d'échantillonnage du tracé (m).
const PAS := 0.5


static func famille(id: String) -> Dictionary:
	return FAMILLES.get(id, FAMILLES.acier)


## Famille dont l'attraction reprend le dessin (voie, piliers, voitures) : elle-même
## ou sa « base » pour les attractions d'époque.
static func style(id: String) -> String:
	return String(FAMILLES.get(id, {}).get("base", id))


static func piece(id: String) -> Dictionary:
	return PIECES.get(id, {})


## Pente à laquelle on est après les pièces données (degrés, la gare est à plat).
static func pente_fin(pieces: Array) -> int:
	var p := 0
	for e in pieces:
		var d := piece(String(e.p))
		if d.has("p1"):
			p = int(d.p1)
	return _norme(p)


static func _norme(p: int) -> int:
	if p == 360 or p == -360 or p == 180 or p == -180:
		return 0
	return p


## La pièce peut-elle se poser à la suite (pente courante, famille) ? "" si oui, sinon la raison.
static func refus(fam_id: String, pente: int, piece_id: String, ferme := false) -> String:
	var f := famille(fam_id)
	var d := piece(piece_id)
	if d.is_empty():
		return "Pièce inconnue."
	if ferme:
		return "Le circuit est bouclé : retire le raccord pour continuer."
	var ep := EpoquesObjets.raison(EpoquesObjets.annee_piece_voie(piece_id))
	if ep != "":
		return ep
	var genre := String(f.genre)
	if d.has("genres") and not genre in (d.genres as Array):
		return "Pas sur ce type d'attraction."
	if int(d.get("inv", 0)) > 0 and not bool(f.inversions):
		return "Pas d'inversion sur ce type d'attraction."
	if d.has("p0") and int(d.p0) != pente:
		return "Il faut arriver à %s." % nom_pente(int(d.p0))
	if d.has("p1") and absi(_norme(int(d.p1))) > int(f.pente_max):
		return "Trop raide pour ce type d'attraction (%d° au plus)." % int(f.pente_max)
	if d.has("p1") and absi(int(d.p1)) > 90 and not bool(f.inversions):
		return "Pas d'inversion sur ce type d'attraction."
	if absf(float(d.get("yaw", 0.0))) > 0.0 and not d.has("p0") and absi(pente) > 25:
		return "Virage impossible dans une pente de plus de 25°."
	if String(d.get("special", "")) == "arrivee" and pente != 0:
		return "Le bassin d'arrivée se pose à plat."
	return ""


static func nom_pente(p: int) -> String:
	match p:
		0: return "plat"
		25: return "la montée douce (25°)"
		45: return "la montée raide (45°)"
		90: return "la verticale (montée)"
		-25: return "la descente douce (25°)"
		-45: return "la descente raide (45°)"
		-90: return "la chute verticale"
	return "%d°" % p


# --- Géométrie -------------------------------------------------------------------------------

## État du « curseur » qui pose la voie : position, cap, pente (radians).
static func depart(fam_id: String) -> Dictionary:
	var f := famille(fam_id)
	var lg := float(f.gare)
	return {"pos": Vector3(-lg / 2.0, float(f.h_gare), 2.5), "yaw": -PI / 2.0, "pitch": 0.0}


static func base(yaw: float, pitch: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)


## Tracé échantillonné : positions P, avant F, haut U0 (sans roulis), droite R0,
## roulis manuel (radians), drapeaux par échantillon (index de pièce, relevé, chaîne, spécial).
## Ajoute à `out` (dictionnaire de tableaux) les échantillons d'une pièce et renvoie l'état de sortie.
static func _integre(out: Dictionary, st: Dictionary, d: Dictionary, idx: int, chaine: bool) -> Dictionary:
	var L := float(d.get("L", 8.0))
	var n := maxi(2, ceili(L / PAS))
	var ds := L / n
	var yaw0 := float(st.yaw)
	var p0 := float(st.pitch)
	var p1 := deg_to_rad(float(d.p1)) if d.has("p1") else p0
	if d.has("p0"):
		p0 = deg_to_rad(float(d.p0))
	var dyaw := deg_to_rad(float(d.get("yaw", 0.0)))
	var bosse := deg_to_rad(float(d.get("bosse", 0.0)))
	var bosse_desc := deg_to_rad(float(d.get("bosse_desc", 0.0)))
	var roll := deg_to_rad(float(d.get("roll", 0.0)))
	var roll_fin := deg_to_rad(float(d.get("roll_fin", 0.0)))
	var roll_debut := deg_to_rad(float(d.get("roll_debut", 0.0)))
	var decal := float(d.get("decal", 0.0))
	var pos: Vector3 = st.pos
	var r_init := base(yaw0, 0.0) * Vector3.RIGHT
	var special := String(d.get("special", ""))
	var releve := bool(d.get("releve", false))
	var prev_dec := 0.0
	for i in n:
		var ta := float(i) / n
		var tb := float(i + 1) / n
		var tm := (ta + tb) / 2.0
		var yaw := yaw0 + dyaw * _lisse(tm)
		var pitch := p0 + (p1 - p0) * _lisse(tm) + bosse * sin(TAU * tm) + bosse_desc * sin(PI * tm)
		var b := base(yaw, pitch)
		var f := b * Vector3.FORWARD
		var dec := decal * _lisse(tb)
		pos += f * ds + r_init * (dec - prev_dec)
		prev_dec = dec
		# Échantillon au bout du pas.
		var yb := yaw0 + dyaw * _lisse(tb)
		var pb := p0 + (p1 - p0) * _lisse(tb) + bosse * sin(TAU * tb) + bosse_desc * sin(PI * tb)
		var bb := base(yb, pb)
		var rl := roll * _lisse(tb)
		if roll_fin != 0.0:
			rl = roll_fin * smoothstep(0.55, 1.0, tb)
		if roll_debut != 0.0:
			rl = roll_debut * smoothstep(0.0, 0.45, tb)
		(out.P as Array).append(pos)
		(out.F as Array).append(bb * Vector3.FORWARD)
		(out.U as Array).append(bb * Vector3.UP)
		(out.R as Array).append(bb * Vector3.RIGHT)
		(out.roll as Array).append(rl)
		(out.piece as Array).append(idx)
		(out.releve as Array).append(1 if releve else 0)
		(out.chaine as Array).append(1 if chaine else 0)
		(out.special as Array).append(special)
	var yaw_out := yaw0 + dyaw + deg_to_rad(float(d.get("fin_yaw", 0.0)))
	var p_out := deg_to_rad(float(_norme(int(d.p1)))) if d.has("p1") else p1
	return {"pos": pos, "yaw": wrapf(yaw_out, -PI, PI), "pitch": p_out}


## Courbe douce de 0 à 1 (dérivée nulle aux deux bouts).
static func _lisse(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _vide() -> Dictionary:
	return {"P": [], "F": [], "U": [], "R": [], "roll": [], "piece": [], "releve": [], "chaine": [], "special": []}


## Les tableaux de travail deviennent des tableaux compacts.
static func _compacte(out: Dictionary) -> void:
	out.P = PackedVector3Array(out.P)
	out.F = PackedVector3Array(out.F)
	out.U = PackedVector3Array(out.U)
	out.R = PackedVector3Array(out.R)
	out.roll = PackedFloat32Array(out.roll)
	out.piece = PackedInt32Array(out.piece)
	out.releve = PackedByteArray(out.releve)
	out.chaine = PackedByteArray(out.chaine)


## Tracé complet d'un dessin : gare (pièce −1), pièces, puis raccord vers la gare
## si `raccord` (pièce = nombre de pièces). Renvoie les tableaux d'échantillons
## et "fin" (état du curseur après la dernière pièce), "ferme" (circuit bouclé).
static func trace(design: Dictionary) -> Dictionary:
	var fam := String(design.get("famille", "acier"))
	var f := famille(fam)
	var out := _vide()
	var st := depart(fam)
	# Gare : un droit à plat (le premier point est l'entrée de la gare).
	(out.P as Array).append(st.pos)
	(out.F as Array).append(Vector3.RIGHT)
	(out.U as Array).append(Vector3.UP)
	(out.R as Array).append(Vector3.BACK)
	(out.roll as Array).append(0.0)
	(out.piece as Array).append(-1)
	(out.releve as Array).append(0)
	(out.chaine as Array).append(0)
	(out.special as Array).append("gare")
	st = _integre(out, st, {"L": float(f.gare), "p0": 0, "p1": 0, "special": "gare"}, -1, false)
	var pieces: Array = design.get("pieces", [])
	var debuts := PackedInt32Array()
	for i in pieces.size():
		debuts.append((out.P as Array).size())
		var e: Dictionary = pieces[i]
		st = _integre(out, st, piece(String(e.p)), i, bool(e.get("chaine", false)))
	out["fin"] = st
	out["debuts"] = debuts
	out["n_pieces"] = pieces.size()
	var ouvert := bool(f.get("ouvert", false))
	var ferme := false
	if ouvert:
		ferme = not pieces.is_empty() and String(piece(String(pieces[pieces.size() - 1].p)).get("special", "")) == "arrivee"
	elif bool(design.get("raccord", false)):
		var r := raccord(st, depart(fam), f)
		if r.ok:
			_ajoute_raccord(out, r, pieces.size())
			ferme = true
		out["raccord_info"] = r
	else:
		# Bouclé à la main : la fin retombe sur l'entrée de la gare, dans le bon sens.
		var d0: Dictionary = depart(fam)
		var fwd := base(float(st.yaw), float(st.pitch)) * Vector3.FORWARD
		ferme = (st.pos as Vector3).distance_to(d0.pos) < 1.5 and fwd.dot(Vector3.RIGHT) > 0.97
	out["ferme"] = ferme
	out["ouvert"] = ouvert
	_compacte(out)
	return out


## Raccord automatique (courbe de Hermite) de la fin du tracé à l'entrée de la
## gare. Plusieurs tensions sont essayées ; on garde la plus courte qui passe.
static func raccord(fin: Dictionary, arrivee: Dictionary, f: Dictionary) -> Dictionary:
	var a: Vector3 = fin.pos
	var b: Vector3 = arrivee.pos
	var dist := a.distance_to(b)
	if dist < 2.0:
		return {"ok": false, "raison": "La fin est déjà sur la gare."}
	var meilleur := {}
	var raison := ""
	for kf in [0.5, 0.8, 1.1, 1.5, 2.0, 2.7]:
		var r := _essai_raccord(fin, a, b, f, maxf(dist * kf, 12.0))
		if r.ok:
			if meilleur.is_empty() or float(r.longueur) < float(meilleur.longueur):
				meilleur = r
		elif raison == "":
			raison = String(r.raison)
	if not meilleur.is_empty():
		return meilleur
	return {"ok": false, "raison": raison}


static func _essai_raccord(fin: Dictionary, a: Vector3, b: Vector3, f: Dictionary, k: float) -> Dictionary:
	var ta := base(float(fin.yaw), float(fin.pitch)) * Vector3.FORWARD
	var tb := Vector3.RIGHT
	var pts := PackedVector3Array()
	var n := maxi(16, ceili((a.distance_to(b) + k) * 1.6 / PAS))
	for i in n + 1:
		var t := float(i) / n
		var h00 := 2 * t * t * t - 3 * t * t + 1
		var h10 := t * t * t - 2 * t * t + t
		var h01 := -2 * t * t * t + 3 * t * t
		var h11 := t * t * t - t * t
		pts.append(a * h00 + ta * k * h10 + b * h01 + tb * k * h11)
	# Pente maximale et rayon minimal (au plan) du raccord.
	var pente := 0.0
	var long := 0.0
	var rmin := INF
	for i in range(1, pts.size()):
		var d := pts[i] - pts[i - 1]
		long += d.length()
		var hz := Vector2(d.x, d.z).length()
		pente = maxf(pente, rad_to_deg(atan2(absf(d.y), maxf(hz, 0.0001))))
		if i >= 2:
			var d0 := pts[i - 1] - pts[i - 2]
			var ang := absf(Vector2(d0.x, d0.z).angle_to(Vector2(d.x, d.z)))
			if ang > 0.0001:
				rmin = minf(rmin, hz / ang)
	if pente > float(f.pente_max) + 2.0:
		return {"ok": false, "raison": "Raccord trop raide (%d°) : rapproche la fin de la hauteur de la gare." % roundi(pente)}
	if rmin < 5.0:
		return {"ok": false, "raison": "Raccord trop serré : termine le tracé en direction de la gare, un peu à l'écart."}
	return {"ok": true, "pts": pts, "longueur": long, "pente": pente}


static func _ajoute_raccord(out: Dictionary, r: Dictionary, idx: int) -> void:
	var pts: PackedVector3Array = r.pts
	# Rééchantillonnage au pas régulier.
	var res := _reechantillonne(pts, PAS)
	for i in range(1, res.size()):
		var p := res[i]
		var fw := (res[mini(i + 1, res.size() - 1)] - res[i - 1]).normalized()
		if i == res.size() - 1:
			fw = Vector3.RIGHT
		var rt := fw.cross(Vector3.UP)
		if rt.length() < 0.01:
			rt = Vector3.BACK
		rt = rt.normalized()
		var up := rt.cross(fw).normalized()
		(out.P as Array).append(p)
		(out.F as Array).append(fw)
		(out.U as Array).append(up)
		(out.R as Array).append(rt)
		(out.roll as Array).append(0.0)
		(out.piece as Array).append(idx)
		(out.releve as Array).append(1)
		(out.chaine as Array).append(0)
		(out.special as Array).append("raccord")


static func _reechantillonne(pts: PackedVector3Array, pas: float) -> PackedVector3Array:
	var out := PackedVector3Array([pts[0]])
	var reste := pas
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var l := a.distance_to(b)
		var t := 0.0
		while l - t >= reste:
			t += reste
			out.append(a.lerp(b, t / l))
			reste = pas
		reste -= (l - t)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.05:
		out.append(pts[pts.size() - 1])
	return out


## Pièces qu'on peut poser maintenant (dans l'ordre du panneau).
static func pieces_possibles(fam_id: String, pente: int) -> Array:
	var out := []
	for id in PIECES:
		if refus(fam_id, pente, id) == "":
			out.append(id)
	return out


## Petit dessin de la pièce (vue de dessus pour les virages, de profil pour le reste).
static func vignette(piece_id: String, px := 44, col := Color.WHITE) -> Texture2D:
	var d := piece(piece_id)
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if d.is_empty():
		return ImageTexture.create_from_image(img)
	var out := _vide()
	var st := {"pos": Vector3.ZERO, "yaw": -PI / 2.0, "pitch": 0.0}
	if d.has("p0"):
		st.pitch = deg_to_rad(float(d.p0))
	_integre(out, st, d, 0, false)
	var pts := PackedVector3Array(out.P)
	pts.insert(0, Vector3.ZERO)
	var dessus := absf(float(d.get("yaw", 0.0))) > 0.0
	var pts2 := PackedVector2Array()
	for p in pts:
		pts2.append(Vector2(p.x, -p.z) if dessus else Vector2(p.x, p.y))
	var mn := pts2[0]
	var mx := pts2[0]
	for p in pts2:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	var taille := maxf(maxf(mx.x - mn.x, mx.y - mn.y), 0.01)
	var marge := 5.0
	var ech := (px - 2.0 * marge) / taille
	var centre := (mn + mx) / 2.0
	var prev := Vector2.ZERO
	for i in pts2.size():
		var q := (pts2[i] - centre) * ech
		var s := Vector2(px / 2.0 + q.x, px / 2.0 - q.y)
		if i > 0:
			_ligne(img, prev, s, col, 2)
		prev = s
	# Point de départ.
	var s0 := (pts2[0] - centre) * ech
	_disque(img, Vector2(px / 2.0 + s0.x, px / 2.0 - s0.y), 3, UiStyle.ACCENT)
	return ImageTexture.create_from_image(img)


static func _ligne(img: Image, a: Vector2, b: Vector2, col: Color, ep: int) -> void:
	var n := maxi(1, ceili(a.distance_to(b) * 2.0))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_disque(img, p, ep, col)


static func _disque(img: Image, c: Vector2, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var px := roundi(c.x) + x
				var py := roundi(c.y) + y
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, col)
