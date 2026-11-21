class_name Tourisme
extends Node3D
## Tourisme : des touristes viennent dormir en ville, visitent les parcs de
## loisirs, les zoos, les musées, les spectacles et le patrimoine, et dépensent
## dans les hôtels, les restaurants, les commerces et les boutiques de souvenirs.
##
## - Attrait de la ville : la somme des « points » de chaque site touristique
##   (ParcLoisirs, ZooSysteme, Musee, Spectacles, monuments et lieux de culte de
##   la bible), selon sa taille et sa note, avec un bonus de variété.
## - Arrivées : chaque jour, selon l'attrait, la saison (l'été !), le jour (le
##   vendredi), la réputation de la ville (0 à 5 étoiles), l'accès (gare,
##   aéroport, port, parking d'autocars), l'office de tourisme et les campagnes
##   de publicité. Ils réservent dans les hébergements (TourismeTypes) selon les
##   étoiles, le prix, la note et la distance aux attractions ; sans lit libre,
##   ils repartent (refusés, comptés).
## - Séjour : de 1 à 7 nuits (plus long au camping, en résidence, en village
##   vacances, l'été et avec un office de tourisme).
## - Visites : chaque client sort environ 1,3 fois par jour vers les sites
##   proches ; ces visiteurs s'ajoutent aux excursionnistes de chaque système
##   (Tourisme.visites(kind, key)).
## - Argent : la nuitée paie l'hébergement (privé : il paie ses salaires et un
##   impôt sur les bénéfices à la ville ; camping municipal et aire de
##   camping-cars : à la ville) ; la taxe de séjour par nuit va à la ville ;
##   repas dans les restaurants et cafés, courses dans les commerces
##   (Production.repas_touristes et achats_touristes), souvenirs.
## - Réputation : ce que les touristes pensent de leur séjour (hébergement,
##   repas, attractions, prix, foule) la fait monter ou descendre.
## - Nature (tourisme v2) : plages, côtes, lacs, rivières, forêts, sommets,
##   glaciers et zones humides du vrai terrain (SitesNaturels) attirent aussi,
##   selon la saison, l'accès par la route, les sentiers (voies « chemin ») et les
##   aménagements (poste de secours, base nautique, belvédère, parking de
##   randonnée, maison de la nature). Les autocars des voyages organisés roulent
##   vraiment sur les routes : entrée de la ville → parking d'autocars → site.

signal changed
signal message(text: String)

static var instance: Tourisme

const STEP := 3600.0
## Arrivées par jour et par point d'attrait (en bonne saison, réputation 3 étoiles).
const ARRIVEES_POINT := 14.0
## Sorties d'un client par jour vers les attractions.
const VISITES_JOUR := 1.3
## Au-delà, un site est trop loin de l'hôtel pour une visite (m).
const PORTEE := 25_000.0
## Repas pris dehors par client et par jour (le petit-déjeuner est à l'hôtel).
const REPAS_JOUR := 1.4
## Courses par client et par jour (t), doublées s'il a une cuisine.
const PANIER := {"boissons": 0.0008, "pain": 0.00012, "epicerie": 0.00008, "hygiene": 0.00003, "vetements": 0.000006, "biens": 0.00002}
const SALAIRE_MOYEN := 1750.0
## Entretien, linge et énergie : part du prix de la nuitée.
const CHARGES_NUIT := 0.22
## Hébergements gérés par la ville (ils encaissent et paient pour elle).
const MUNICIPAUX := ["camping", "aire_camping_cars"]
const SAISON := {1: 0.45, 2: 0.55, 3: 0.7, 4: 0.9, 5: 1.0, 6: 1.15, 7: 1.6, 8: 1.7, 9: 1.0, 10: 0.8, 11: 0.5, 12: 0.75}
## Jour d'arrivée (0 = dimanche).
const JOUR := {0: 0.6, 1: 0.8, 2: 0.8, 3: 0.85, 4: 0.95, 5: 1.5, 6: 1.3}
## Durée moyenne du séjour selon le genre d'hébergement (multiplie la durée de base).
const DUREE_GENRE := {"hotel": 1.0, "auberge": 1.0, "gite": 2.2, "camping": 2.4, "residence": 3.0, "village": 3.4, "refuge": 1.3}
## Genres de visites (bonus de variété, avis des touristes).
const KINDS_VISITE := ["parc", "zoo", "musee", "spectacles", "patrimoine", "nature"]
## Un site naturel sans route à moins de ce rayon (m) est difficile d'accès.
const ACCES_ROUTE := 800.0
## Sentiers comptés autour d'un site naturel (m) et bonus par km (au plus 5 km).
const SENTIERS_RAYON := 700.0
const SENTIER_KM := 0.15
## Relevé du terrain refait tous les N jours (ou quand un village est fondé).
const NATURE_JOURS := 30
## Autocars dessinés sur les routes en même temps, au plus.
const AUTOCARS_VISIBLES := 6
const TAG_AUTOCAR := 4_000_000

## Campagnes de publicité : prix, durée (jours), effet sur les arrivées.
const CAMPAGNES := {
	"salon": {"name": "Stand au salon du tourisme", "prix": 15_000, "jours": 10, "effet": 1.1},
	"regionale": {"name": "Affiches et radio dans la région", "prix": 45_000, "jours": 30, "effet": 1.22},
	"nationale": {"name": "Campagne nationale (télé, internet)", "prix": 220_000, "jours": 30, "effet": 1.45},
	"internationale": {"name": "Campagne internationale", "prix": 900_000, "jours": 45, "effet": 1.9},
}
const CAMPAGNE_ORDER := ["salon", "regionale", "nationale", "internationale"]

const NOMS_HOTEL := ["Hôtel de la Gare", "Hôtel du Lac", "Le Relais", "Hôtel des Voyageurs", "Le Grand Hôtel", "Hôtel Beau Séjour",
	"Hôtel de la Poste", "Les Tilleuls", "Le Belvédère", "Hôtel du Parc", "L'Escale", "Hôtel Bellevue", "Le Cheval Blanc", "Les Glycines"]
const NOMS_CAMPING := ["Camping des Pins", "Camping Le Ruisseau", "Camping de la Plage", "Camping Les Peupliers", "Camping du Moulin"]

## Ce que disent les touristes (réaliste, avec une touche d'humour).
const PENSEES := {
	"super": "Séjour parfait. On revient l'an prochain, avec la belle-famille (on n'est pas sûrs pour la belle-famille).",
	"complet": "Tout était complet en ville. On a dormi dans la voiture, entre le parasol et la glacière.",
	"cher": "%d € la nuit ? Pour ce prix-là, je voulais le petit-déjeuner au lit et un chant d'oiseau.",
	"bon_prix": "Hôtel propre, bon prix, et le réceptionniste connaissait tous les bons restaurants.",
	"faim": "Pas un restaurant ouvert à 20 h. On a dîné de chips au distributeur de la gare.",
	"resto": "Le restaurant du coin vaut le détour : la tarte aux pommes justifie à elle seule le voyage.",
	"rien": "Il n'y a rien à faire ici. On a visité la mairie deux fois.",
	"parc": "Les enfants ont fait le grand-huit six fois. Moi une, et je m'en souviens encore.",
	"zoo": "Les girafes nous ont regardés comme si c'était nous, les touristes. Ce qui est vrai.",
	"musee": "Le musée était superbe. On a même lu les cartels, enfin, la moitié.",
	"spectacle": "Le spectacle du soir était formidable. On a fredonné tout le chemin du retour.",
	"patrimoine": "Les vieilles pierres sont magnifiques. J'ai pris 412 photos, dont 400 de la même tour.",
	"varie": "Un zoo, un musée, un spectacle : trois jours bien remplis, on rentre pour se reposer.",
	"souvenirs": "J'ai acheté un magnet, un tablier et une boule à neige. La boule à neige fuit.",
	"pas_souvenirs": "Pas une carte postale à acheter dans toute la ville. Ma tante sera déçue.",
	"office": "L'office de tourisme nous a tout expliqué, avec un plan et un sourire.",
	"foule": "Trop de monde aux attractions : on a fait la queue pour faire la queue.",
	"camping": "Nuit sous la tente, chant des grillons et matelas qui se dégonfle à 3 h du matin.",
	"luxe": "Peignoir brodé, vue sur la ville et un chocolat sur l'oreiller. Je ne rentre plus chez moi.",
	"pluie": "Il a plu toute la semaine. Heureusement, le musée était ouvert.",
	"loin": "Notre hôtel était à des kilomètres de tout. Le chauffeur de taxi nous connaît par cœur.",
	"autocar": "Voyage organisé : 50 personnes, un guide, un parapluie levé et 20 minutes par monument.",
	"train": "Venus en train, accueillis à la gare : c'est comme ça que devraient commencer les vacances.",
	"courses": "Supermarché bien rempli : on a fait le plein de pâtes et de crème solaire.",
	"rayons_vides": "Rayons vides à la supérette. On a fait des pâtes sans pâtes.",
	"plage": "Sable chaud, mer turquoise et un coup de soleil en forme de maillot. Parfait.",
	"plage_surveillee": "Plage surveillée : les enfants dans l'eau, nous sur la serviette. Enfin des vacances.",
	"cote": "Les falaises au coucher du soleil : 200 photos et le vent qui a gardé ma casquette.",
	"lac": "Pique-nique au bord du lac. Un canard a volé mon sandwich, sans aucun remords.",
	"riviere": "Descente de la rivière en kayak : je suis tombé deux fois, mais avec style.",
	"foret": "Balade en forêt : des cèpes, des écureuils et zéro réseau. Le paradis.",
	"sommet": "Arrivés au sommet en sueur : la vue valait bien les trois heures de montée.",
	"glacier": "Le glacier est impressionnant. Le guide dit qu'il recule : on s'est dépêchés.",
	"marais": "Des hérons, des grenouilles et des moustiques très accueillants.",
	"sentiers": "Sentiers bien balisés : on ne s'est perdus qu'une fois (c'était la faute de la carte).",
	"pas_acces": "Le lac avait l'air superbe sur la carte. Dommage qu'aucune route n'y mène.",
	"eau_sale": "L'eau était trouble et sentait bizarre. On s'est contentés de la regarder.",
	"nature_pluie": "Randonnée sous la pluie : on a surtout vu l'intérieur de nos capuches.",
}

var buildings: BuildingSystem
var population: Population
var ambiance: DayNight
var transport: TransportSystem

## Hébergements : bid → état.
var heb: Dictionary = {}
## Sites touristiques du jour : [{kind, key, nom, pos, pts, note}].
var sites: Array = []
## Visites attendues aujourd'hui depuis les hébergements : "kind:key" → touristes.
var visites_jour: Dictionary = {}
var attrait_total := 0.0
var reputation := 3.0
var campagne := ""
var campagne_fin := -1
var jour: Dictionary = {}
var hier: Dictionary = {}
var total: Dictionary = {}
## Les 60 derniers jours : [jour, arrivées, nuitées, refus, dépenses].
var historique: Array = []
var pensees: Dictionary = {}
var dernieres: Array = []
var clock := -1.0
var last_unix := -1.0
var last_day := -1
## Pour les tests : les hébergements tournent sans personnel.
var ignore_staff := false
var rng := RandomNumberGenerator.new()
var visuels: TourismeVisuels
## Sites naturels trouvés dans le terrain (SitesNaturels.scanner) et leur état du jour.
var nature: Array = []
var nature_jour := -1000
var nature_ok := false
var _nature_sig := ""
## Pour les tests : sites naturels imposés (le terrain n'est pas relevé).
var nature_fixe := false
## Autocars à faire rouler aujourd'hui : [{h, site (pos)}].
var cars_prevus: Array = []
var _car_n := 0
var _dirty := true
var _warned: Dictionary = {}
var _frac := {}


func _init() -> void:
	rng.seed = 7_310_115
	add_to_group("avis_sources")
	jour = _empty_stats()
	hier = _empty_stats()
	total = _empty_stats()


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	visuels = TourismeVisuels.new()
	visuels.name = "Touristes"
	visuels.setup(self)
	add_child(visuels)


func setup(b: BuildingSystem, p: Population, a: DayNight, t: TransportSystem = null) -> void:
	buildings = b
	population = p
	ambiance = a
	transport = t
	if buildings != null:
		buildings.changed.connect(func() -> void: _dirty = true)


func clear() -> void:
	heb.clear()
	sites.clear()
	visites_jour.clear()
	attrait_total = 0.0
	reputation = 3.0
	campagne = ""
	campagne_fin = -1
	jour = _empty_stats()
	hier = _empty_stats()
	total = _empty_stats()
	historique.clear()
	pensees.clear()
	dernieres.clear()
	cars_prevus.clear()
	if not nature_fixe:
		nature.clear()
		nature_ok = false
		nature_jour = -1000
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	_dirty = true
	changed.emit()


static func _empty_stats() -> Dictionary:
	return {"arrivees": 0, "nuitees": 0, "refus": 0, "excursions": 0, "autocars": 0, "visites": 0, "nature": 0.0,
		"hebergement": 0.0, "restaurants": 0.0, "commerces": 0.0, "souvenirs": 0.0, "taxe": 0.0, "impots": 0.0, "ville": 0.0}


## Visites des clients des hébergements attendues aujourd'hui sur un site (par les
## systèmes de loisirs). kind : "parc", "zoo", "musee", "spectacles".
static func visites(kind: String, key: Variant) -> float:
	if instance == null or not is_instance_valid(instance):
		return 0.0
	return float(instance.visites_jour.get("%s:%s" % [kind, str(key)], 0.0))


# --- Hébergements ---------------------------------------------------------------------------

func _new_state(bid: int, sp: Dictionary) -> Dictionary:
	var t := _type_of(bid)
	var noms: Array = NOMS_CAMPING if String(sp.get("genre", "")) == "camping" else NOMS_HOTEL
	var nom := String(BuildingCatalog.get_type(t).get("name", "Hôtel"))
	if String(sp.get("genre", "")) in ["hotel", "camping"]:
		nom = String(noms[absi(hash(bid * 7919)) % noms.size()])
	return {"nom": nom, "prix": float(sp.get("prix", 50.0)), "ouvert": true, "clients": [], "note": 3.0, "satisf": 3.0,
		"jour": {"arrivees": 0, "nuitees": 0, "refus": 0, "ca": 0.0, "charges": 0.0}, "hier": {"arrivees": 0, "nuitees": 0, "refus": 0, "ca": 0.0, "charges": 0.0},
		"compte": 0.0, "mois_ca": 0.0, "mois_charges": 0.0, "rouge": 0}


func _type_of(bid: int) -> String:
	if buildings == null or not buildings.buildings.has(bid):
		return ""
	return String(buildings.buildings[bid].t)


func spec(bid: int) -> Dictionary:
	# Mode gestion (Gestion) : pièces construites et étoiles gagnées.
	return Gestion.spec_de(bid, TourismeTypes.spec_of(_type_of(bid)))


func _sync() -> void:
	_dirty = false
	if buildings == null:
		return
	var seen := {}
	for bid in buildings.buildings:
		if TourismeTypes.est_hebergement(String(buildings.buildings[bid].t)):
			seen[int(bid)] = true
			if not heb.has(int(bid)):
				heb[int(bid)] = _new_state(int(bid), spec(int(bid)))
	for bid in heb.keys():
		if not seen.has(bid):
			heb.erase(bid)


func list_hebergements() -> Array:
	if _dirty:
		_sync()
	var out := heb.keys()
	out.sort()
	return out


## Bâtiments de service touristique d'un rôle : office, souvenirs, autocars.
func services(role: String) -> Array:
	var out: Array = []
	if buildings == null:
		return out
	for bid in buildings.buildings:
		if String(TourismeTypes.spec_of(String(buildings.buildings[bid].t)).get("role", "")) == role and not buildings.en_chantier(int(bid)):
			out.append(int(bid))
	return out


func nom(bid: int) -> String:
	return String(heb[bid].nom) if heb.has(bid) else String(BuildingCatalog.get_type(_type_of(bid)).get("name", ""))


func renommer(bid: int, n: String) -> void:
	if heb.has(bid) and n.strip_edges() != "":
		heb[bid].nom = n.strip_edges()
		changed.emit()


func set_prix(bid: int, prix: float) -> void:
	if heb.has(bid):
		heb[bid].prix = clampf(prix, 2.0, 2000.0)
		changed.emit()


func set_ouvert(bid: int, on: bool) -> void:
	if heb.has(bid):
		heb[bid].ouvert = on
		changed.emit()


func etoiles(bid: int) -> int:
	return int(spec(bid).get("etoiles", 2))


func lits(bid: int) -> int:
	# Hôtel agrandi (Ameliorations) : 1,5 ou 2 fois plus de lits.
	# Mode gestion : chambres ouvertes en plus.
	return roundi(TourismeTypes.lits_de(spec(bid)) * Ameliorations.facteur_bid(buildings, bid) * (1.0 + Gestion.effet_de(bid, "lits")))


func est_municipal(bid: int) -> bool:
	return MUNICIPAUX.has(_type_of(bid))


func pos_of(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)


func porte(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.ZERO
	var b: Dictionary = buildings.buildings[bid]
	return BuildingSystem.door_point(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0))) + Vector3(0, float(b.get("h", 0.0)), 0)


func relie(bid: int) -> bool:
	if buildings == null or not buildings.buildings.has(bid):
		return false
	if transport == null:
		return true
	var door := porte(bid)
	for eid in transport.edges_near(door, 40.0):
		var m := TransportTypes.mode_of(transport.network.edges[eid].t)
		if m == TransportTypes.Mode.ROAD or m == TransportTypes.Mode.PATH:
			return true
	return false


## Part du personnel présent (1 = complet).
func personnel(bid: int) -> float:
	if ignore_staff:
		return 1.0
	var emplois := Ameliorations.cap(buildings.buildings.get(bid, {}), "emplois") if buildings != null else 0
	if emplois <= 0:
		return 1.0
	if population == null:
		return 0.0
	var n := (population.by_job.get(bid, []) as Array).size()
	return clampf(float(n) / float(emplois) * 1.25, 0.0, 1.0)


func en_saison(bid: int, month: int) -> bool:
	var s: Array = spec(bid).get("saison", [])
	if s.size() < 2:
		return true
	return month >= int(s[0]) and month <= int(s[1])


func ouvert(bid: int, month: int) -> bool:
	if not heb.has(bid) or not bool(heb[bid].ouvert) or buildings.en_chantier(bid):
		return false
	return en_saison(bid, month) and personnel(bid) > 0.0


## Lits utilisables aujourd'hui (le personnel limite la capacité).
func capacite(bid: int, month: int) -> int:
	if not ouvert(bid, month):
		return 0
	return int(floorf(float(lits(bid)) * personnel(bid)))


func clients(bid: int) -> int:
	var n := 0
	for c in heb.get(bid, {}).get("clients", []):
		n += int(c[0])
	return n


func clients_total() -> int:
	var n := 0
	for bid in heb:
		n += clients(int(bid))
	return n


func lits_total() -> int:
	var n := 0
	for bid in heb:
		n += lits(int(bid))
	return n


func occupation(bid: int) -> float:
	var l := lits(bid)
	return float(clients(bid)) / float(l) if l > 0 else 0.0


## Note de l'hébergement (0 à 5) : confort (étoiles, piscine, spa), rapport qualité-prix, avis des clients.
func note(bid: int) -> float:
	var sp := spec(bid)
	var e := float(sp.get("etoiles", 2))
	var confort := 1.4 + e * 0.55 + (0.25 if bool(sp.get("piscine", false)) else 0.0) + (0.25 if bool(sp.get("spa", false)) else 0.0) \
		+ (0.2 if bool(sp.get("restaurant", false)) else 0.0) + (0.2 if bool(sp.get("animation", false)) else 0.0)
	var prix := float(heb[bid].prix) if heb.has(bid) else float(sp.get("prix", 50.0))
	var ref := float(sp.get("prix", TourismeTypes.prix_ref(int(e))))
	var qp := clampf((ref / maxf(prix, 1.0) - 1.0) * 0.9, -1.5, 0.6)
	var avis := float(heb[bid].satisf) if heb.has(bid) else 3.0
	return clampf(confort * 0.55 + avis * 0.35 + qp + 0.3 + Gestion.effet_de(bid, "confort"), 0.5, 5.0)


# --- Sites touristiques -------------------------------------------------------------------

func _maj_sites() -> void:
	sites.clear()
	var pl := ParcLoisirs.instance
	if pl != null and is_instance_valid(pl):
		for e in pl.parcs:
			var a := pl.attrait(int(e))
			if a <= 0.0:
				continue
			var n := float(pl.parcs[e].get("note", 3.0))
			sites.append({"kind": "parc", "key": int(e), "nom": String(pl.parcs[e].get("nom", "Parc de loisirs")), "pos": pl.centre(int(e)),
				"pts": 0.3 * a * (0.35 + 0.65 * clampf(n / 5.0, 0.0, 1.0)), "note": n})
	var zs := ZooSysteme.instance
	if zs != null and is_instance_valid(zs):
		for e in zs.zoos:
			var a := zs.attrait(int(e))
			if a <= 0.0:
				continue
			var n := float(zs.zoos[e].get("note", 3.0))
			sites.append({"kind": "zoo", "key": int(e), "nom": String(zs.zoos[e].get("nom", "Zoo")), "pos": pos_of(int(e)),
				"pts": 0.09 * a * (0.35 + 0.65 * clampf(n / 5.0, 0.0, 1.0)), "note": n})
	var mu := Musee.instance
	if mu != null and is_instance_valid(mu):
		for k in mu.list():
			var an := mu.analyse(String(k))
			var n := float(an.get("note", 0.0))
			if n <= 0.0:
				continue
			sites.append({"kind": "musee", "key": String(k), "nom": mu.nom(String(k)), "pos": mu.centre(String(k)),
				"pts": 0.009 * (float(an.prestige) + mu.expo_bonus(String(k))) * (0.4 + n / 5.0), "note": n})
	var sp := Spectacles.instance
	if sp != null and is_instance_valid(sp):
		for bid in sp.list_salles():
			var n := sp.note(int(bid))
			sites.append({"kind": "spectacles", "key": int(bid), "nom": sp.nom(int(bid)), "pos": sp.centre(int(bid)),
				"pts": clampf(float(sp.places(int(bid))) / 1000.0, 0.1, 6.0) * (0.6 + n / 5.0 * 0.6) * 0.8, "note": n})
	# Patrimoine : grands monuments (même en chantier), bâtiments protégés,
	# monuments, châteaux, cathédrales et temples de la bible (Patrimoine).
	var pat := Patrimoine.instance
	if buildings != null and pat != null and is_instance_valid(pat) and pat.buildings == buildings:
		for bid in buildings.buildings:
			var pts := pat.points_site(int(bid))
			if pts > 0.0:
				var nm := pat.nom(int(bid))
				if pat.en_chantier(int(bid)):
					nm = "Chantier de " + nm.substr(0, 1).to_lower() + nm.substr(1)
				sites.append({"kind": "patrimoine", "key": int(bid), "nom": nm, "pos": pos_of(int(bid)), "pts": pts, "note": pat.note_site(int(bid))})
	elif buildings != null:
		for bid in buildings.buildings:
			var t := BuildingCatalog.get_type(String(buildings.buildings[bid].t))
			var role := String(t.get("role", ""))
			var arch := String(t.get("arch", ""))
			if role in ["monument", "culte"] or arch in ["culte", "palais"] or String(buildings.buildings[bid].t) == "phare":
				if buildings.en_chantier(int(bid)):
					continue
				var pts := clampf(float(BuildingCatalog.cost(String(buildings.buildings[bid].t))) / 8_000_000.0, 0.15, 2.5) * (1.0 if role == "monument" else 0.6)
				sites.append({"kind": "patrimoine", "key": int(bid), "nom": String(t.get("name", "Monument")), "pos": pos_of(int(bid)), "pts": pts, "note": 3.5})
	# Cabinets de curiosités et renommée des expéditions.
	var ex := Expeditions.instance
	if ex != null and is_instance_valid(ex) and ex.buildings == buildings:
		sites.append_array(ex.sites_tourisme())
	_sites_nature()
	var kinds := {}
	attrait_total = 0.0
	for s in sites:
		attrait_total += float(s.pts)
		kinds[String(s.kind)] = true
	attrait_total *= 1.0 + 0.12 * maxf(0.0, float(kinds.size()) - 1.0)
	# Explorateurs conférenciers, photographes de renom… (spécialistes des expéditions).
	attrait_total *= 1.0 + Expeditions.facteur("tourisme")


func kinds_count() -> int:
	var kinds := {}
	for s in sites:
		kinds[String(s.kind)] = true
	return kinds.size()


# --- Sites naturels (tourisme v2) -----------------------------------------------------------

func _monde() -> TerrainWorld:
	if buildings != null and buildings.world != null:
		return buildings.world
	if transport != null and transport.world != null:
		return transport.world
	return null


## Centres autour desquels on cherche la nature : les villages, sinon les hébergements.
func centres_nature() -> Array:
	var out: Array = []
	var co := Communes.instance
	if co != null and is_instance_valid(co):
		for vid in co.villages:
			out.append(co.villages[vid].c as Vector2)
	if out.is_empty():
		for bid in heb:
			var p := pos_of(int(bid))
			out.append(Vector2(p.x, p.z))
	if out.is_empty() and buildings != null and not buildings.buildings.is_empty():
		out.append(Vector2.ZERO)
	# Deux centres à moins de 4 km : un seul relevé.
	var gardes: Array = []
	for c in out:
		var proche := false
		for g in gardes:
			if (g as Vector2).distance_to(c) < 4000.0:
				proche = true
				break
		if not proche:
			gardes.append(c)
	return gardes.slice(0, 6)


## Relève le terrain autour des villages (tous les NATURE_JOURS jours, ou quand un
## village apparaît, ou tant que les données ne sont pas toutes arrivées).
func maj_nature(force := false) -> void:
	if nature_fixe:
		return
	var w := _monde()
	if w == null:
		return
	var centres := centres_nature()
	var sig := "%.4f,%.4f|" % [w.origin_lat, w.origin_lon]
	for c in centres:
		sig += "%d,%d;" % [roundi((c as Vector2).x / 500.0), roundi((c as Vector2).y / 500.0)]
	if not force and nature_ok and sig == _nature_sig and last_day - nature_jour < NATURE_JOURS:
		return
	if centres.is_empty():
		nature.clear()
		return
	var r := SitesNaturels.scanner(w, centres)
	if not (r.sites as Array).is_empty() or bool(r.ok):
		nature = r.sites
	nature_ok = bool(r.ok)
	nature_jour = last_day
	_nature_sig = sig
	if nature_ok:
		var neufs: Array = []
		for s in nature:
			neufs.append("%s (%s)" % [String(s.nom), SitesNaturels.nom_genre(String(s.genre)).to_lower()])
		if not neufs.is_empty() and not _warned.has("nature_vue"):
			_warned["nature_vue"] = clock
			message.emit("Tourisme : la nature des environs attire les visiteurs : %s." % ", ".join(neufs.slice(0, 4)))


## Aménagements (bâtiments de rôle « nature ») qui servent un site.
func amenagements_de(site: Dictionary) -> Array:
	var out: Array = []
	for bid in services("nature"):
		var sp := TourismeTypes.spec_of(_type_of(int(bid)))
		if not (sp.get("genres", []) as Array).has(String(site.genre)):
			continue
		if SitesNaturels.distance(site, pos_of(int(bid))) <= float(sp.get("portee", 1500.0)):
			out.append(int(bid))
	return out


## Longueur (km) de sentiers (voies de mode chemin) près d'un site.
func sentiers_km(site: Dictionary) -> float:
	if transport == null or transport.network == null:
		return 0.0
	var m := 0.0
	var vus := {}
	for q in site.get("points", [site.pos]):
		for eid in transport.edges_near(q as Vector3, SENTIERS_RAYON):
			if vus.has(eid) or not transport.network.edges.has(eid):
				continue
			vus[eid] = true
			var e: Dictionary = transport.network.edges[eid]
			if TransportTypes.mode_of(e.t) == TransportTypes.Mode.PATH:
				m += float(e.len)
	return m / 1000.0


## Une route à moins de ACCES_ROUTE m du site (ou un parking de randonnée).
func acces_site(site: Dictionary, amenag: Array) -> bool:
	for bid in amenag:
		if bool(TourismeTypes.spec_of(_type_of(int(bid))).get("acces", false)):
			return true
	if transport == null or transport.network == null:
		return true
	for q in site.get("points", [site.pos]):
		for eid in transport.edges_near(q as Vector3, ACCES_ROUTE):
			if transport.network.edges.has(eid) and TransportTypes.mode_of(transport.network.edges[eid].t) == TransportTypes.Mode.ROAD:
				return true
	return false


## L'état du jour des sites naturels, ajoutés à `sites` (kind « nature »).
func _sites_nature() -> void:
	if nature.is_empty():
		return
	var month := int(_now(clock if clock > 0.0 else (ambiance.unix_time if ambiance != null else 0.0)).month)
	var pluie := _pluie()
	var nu := Nuisances.instance
	for s in nature:
		var genre := String(s.genre)
		var am := amenagements_de(s)
		var bonus := 1.0
		var note := float(s.note)
		var surveille := false
		var recette := 0.0
		var vus := {}
		for bid in am:
			var t := _type_of(int(bid))
			var sp := TourismeTypes.spec_of(t)
			if vus.has(t):
				continue # deux fois le même aménagement : pas plus d'effet
			vus[t] = true
			var sa: Array = sp.get("saison", [])
			if sa.size() >= 2 and (month < int(sa[0]) or month > int(sa[1])):
				continue
			if not _staff_ok(int(bid)):
				continue
			bonus *= float(sp.get("bonus", 1.0))
			note += float(sp.get("note", 0.0))
			recette += float(sp.get("recette", 0.0))
			if t == "poste_secours_plage":
				surveille = true
		var km := sentiers_km(s)
		bonus *= 1.0 + SENTIER_KM * minf(km, 5.0)
		if km >= 1.0:
			note += 0.3
		var acc := acces_site(s, am)
		var pollue := 0.0
		if nu != null and is_instance_valid(nu) and genre in ["plage", "lac", "riviere", "marais"]:
			pollue = clampf(nu.eau(s.pos), 0.0, 1.0)
			note -= 2.0 * pollue
		var meteo := 1.0 - (0.6 if genre in ["plage", "lac", "riviere"] else 0.35) * pluie
		var pts := float(s.base) * SitesNaturels.saison(genre, month) * bonus * meteo * (1.0 if acc else 0.35) * (1.0 - 0.6 * pollue)
		sites.append({"kind": "nature", "key": String(s.key), "genre": genre, "nom": String(s.nom), "pos": s.pos, "points": s.points,
			"pts": pts, "note": clampf(note, 0.5, 5.0), "amenag": am, "sentiers": km, "acces": acc, "surveille": surveille,
			"recette": recette, "pollue": pollue, "taille": s.taille})


## Accès à la ville : routes seules 0,75 ; gare, aéroport, port et autocars en plus.
func acces() -> Dictionary:
	var out := {"f": 0.75, "gare": 0, "aeroport": 0, "port": 0, "autocars": services("autocars").size()}
	if transport != null and transport.stations != null:
		for id in transport.stations.stations:
			var t := String(transport.stations.stations[id].type)
			if t == "gare":
				out.gare = int(out.gare) + 1
			elif t in ["aeroport", "aerodrome"]:
				out.aeroport = int(out.aeroport) + 1
			elif t == "port":
				out.port = int(out.port) + 1
	var f := 0.75
	if int(out.gare) > 0:
		f += 0.2
	if int(out.aeroport) > 0:
		f += 0.35
	if int(out.port) > 0:
		f += 0.1
	f += 0.08 * mini(int(out.autocars), 2)
	out.f = minf(f, 1.6)
	return out


func campagne_effet() -> float:
	if campagne == "" or not CAMPAGNES.has(campagne):
		return 1.0
	return float(CAMPAGNES[campagne].effet)


func office_effet() -> float:
	return 1.0 + 0.1 * mini(services("office").size(), 2)


## Touristes qui veulent venir dormir en ville un jour donné (avant les lits).
func demande(now: Dictionary) -> float:
	if attrait_total <= 0.0:
		return 0.0
	var f := float(SAISON.get(int(now.month), 1.0)) * float(JOUR.get(int(now.wd), 1.0))
	f *= 0.5 + reputation / 6.0
	f *= float(acces().f) * campagne_effet() * office_effet()
	return attrait_total * ARRIVEES_POINT * f


## Durée moyenne du séjour (nuits) dans un hébergement.
func duree_moyenne(bid: int, month: int) -> float:
	var base := 1.3 + 0.3 * maxf(0.0, float(kinds_count()) - 1.0) + 0.04 * minf(attrait_total, 25.0)
	if not services("office").is_empty():
		base += 0.4
	if month in [7, 8]:
		base *= 1.4
	base *= float(DUREE_GENRE.get(String(spec(bid).get("genre", "hotel")), 1.0))
	return clampf(base, 1.0, 9.0)


## Distance moyenne (pondérée) d'un point aux sites touristiques.
func proximite(p: Vector3) -> float:
	var s := 0.0
	var w := 0.0
	for st in sites:
		var d := Vector2(p.x, p.z).distance_to(Vector2((st.pos as Vector3).x, (st.pos as Vector3).z))
		if d > PORTEE:
			continue
		s += float(st.pts) / (1.0 + d / 2500.0)
		w += float(st.pts)
	return s / w if w > 0.0 else 0.0


## Préférence des touristes pour un hébergement (avant les lits libres).
func attrait_heb(bid: int, month: int) -> float:
	var sp := spec(bid)
	var prix := float(heb[bid].prix)
	var ref := float(sp.get("prix", TourismeTypes.prix_ref(int(sp.get("etoiles", 2)))))
	var valeur := clampf(ref / maxf(prix, 1.0), 0.15, 1.6)
	var prox := 0.25 + proximite(pos_of(bid))
	var genre := 1.0
	if String(sp.get("genre", "")) == "camping" or String(sp.get("genre", "")) == "village":
		genre = 1.5 if month in [6, 7, 8] else 0.8
	var route := 1.0 if relie(bid) else 0.2
	return (0.4 + note(bid) / 5.0) * valeur * valeur * prox * genre * route * sqrt(float(maxi(lits(bid), 1))) * (1.0 + Gestion.effet_de(bid, "attrait"))


# --- Temps --------------------------------------------------------------------------------------

func _now(t: float) -> Dictionary:
	var off := ambiance.utc_offset() if ambiance != null else 0.0
	var local := t + off * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	return {"h": fposmod(local, 86400.0) / 3600.0, "wd": int(dt.weekday), "month": int(dt.month), "day": int(floorf(local / 86400.0)), "mday": int(dt.day)}


func _process(_delta: float) -> void:
	if ambiance == null:
		return
	var t := ambiance.unix_time
	if last_unix < 0.0:
		last_unix = t
		return
	var dt := clampf(t - last_unix, 0.0, 86400.0 * 2.0)
	last_unix = t
	if dt > 0.0:
		advance(dt)


func advance(dt: float) -> void:
	var end_t := (ambiance.unix_time if ambiance != null else clock + dt)
	if clock < 0.0 or absf(end_t - dt - clock) > 86400.0 * 3.0:
		clock = end_t - dt
	if last_day < 0:
		last_day = int(_now(clock).day)
	var n := 0
	while clock + STEP <= end_t + 0.001 and n < 96:
		clock += STEP
		n += 1
		step(STEP)
	if clock < end_t - 86400.0:
		clock = end_t


func step(_dt: float) -> void:
	if _dirty:
		_sync()
	var now := _now(clock)
	if int(now.day) > last_day:
		last_day = int(now.day)
		new_day(now)
	_rouler_autocars(float(now.h))


func _pluie() -> float:
	if ambiance == null or ambiance.weather == null:
		return 0.0
	return clampf(float(ambiance.weather.precip), 0.0, 1.0)


# --- Une journée -------------------------------------------------------------------------------

func new_day(now: Dictionary = {}) -> void:
	if _dirty:
		_sync()
	if now.is_empty():
		now = _now(clock if clock > 0.0 else (ambiance.unix_time if ambiance != null else 0.0))
	_cloture()
	maj_nature()
	_maj_sites()
	var month := int(now.month)
	if campagne != "" and last_day >= campagne_fin:
		message.emit("Tourisme : la campagne « %s » est terminée." % String(CAMPAGNES.get(campagne, {}).get("name", campagne)))
		campagne = ""
		campagne_fin = -1
	# Départs (le matin) et avis des partants.
	var sat_sum := 0.0
	var sat_w := 0.0
	for bid in heb:
		var st: Dictionary = heb[bid]
		var rest: Array = []
		for c in st.clients:
			var nuits := int(c[1]) - 1
			if nuits > 0 and ouvert(int(bid), month):
				rest.append([int(c[0]), nuits, float(c[2])])
			else:
				sat_sum += float(c[2]) * int(c[0])
				sat_w += float(c[0])
		st.clients = rest
	if sat_w > 0.0:
		reputation = clampf(lerpf(reputation, sat_sum / sat_w, clampf(sat_w / 400.0, 0.02, 0.15)), 0.5, 5.0)
	# Arrivées (l'après-midi).
	_arrivees(now)
	# La journée des clients : nuitées, repas, courses, souvenirs, visites.
	_journee(now)
	changed.emit()


## Les arrivées du jour, réparties dans les hébergements libres.
func _arrivees(now: Dictionary) -> void:
	var month := int(now.month)
	var d := demande(now)
	var voulu := _arrondi(d)
	if voulu <= 0:
		return
	var libres := {}
	var scores := {}
	var somme := 0.0
	for bid in heb:
		var cap := capacite(int(bid), month) - clients(int(bid))
		if cap <= 0:
			continue
		libres[bid] = cap
		var s := attrait_heb(int(bid), month)
		scores[bid] = s
		somme += s
	var reste := voulu
	if somme > 0.0:
		# Deux passes : le premier choix, puis un repli (un sur trois abandonne).
		for passe in 2:
			if reste <= 0 or libres.is_empty():
				break
			var dispo := reste
			var places := 0
			somme = 0.0
			for bid in libres:
				somme += float(scores[bid])
			for bid in libres.keys():
				var part := float(dispo) * float(scores[bid]) / somme
				var n := mini(int(libres[bid]), _arrondi(part))
				if n <= 0:
					continue
				_loger(int(bid), n, month)
				libres[bid] = int(libres[bid]) - n
				if int(libres[bid]) <= 0:
					libres.erase(bid)
				places += n
			reste -= places
			if passe == 0:
				reste = roundi(float(reste) * 0.67)
	var refus := maxi(0, voulu - _arrives_auj)
	jour.refus = int(jour.refus) + refus
	if refus > 10:
		_penser("complet", [], maxi(1, refus / 10))
		_warn("lits", "Tourisme : %d touristes n'ont pas trouvé de lit en ville. Construis des hébergements (menu Tourisme, Maj+D → Bâtir)." % refus, 86400.0 * 4.0)
	_arrives_auj = 0


var _arrives_auj := 0


func _loger(bid: int, n: int, month: int) -> void:
	var st: Dictionary = heb[bid]
	var moy := duree_moyenne(bid, month)
	# Par petits groupes de durées différentes.
	var groupes := clampi(n / 6, 1, 4)
	var left := n
	for g in groupes:
		var k := left if g == groupes - 1 else n / groupes
		left -= k
		var nuits := maxi(1, roundi(moy * rng.randf_range(0.55, 1.45)))
		(st.clients as Array).append([k, nuits, 3.0])
	st.jour.arrivees = int(st.jour.arrivees) + n
	jour.arrivees = int(jour.arrivees) + n
	_arrives_auj += n


## Nuitées, repas, courses, souvenirs et visites de tous les clients du jour.
func _journee(now: Dictionary) -> void:
	var month := int(now.month)
	visites_jour.clear()
	var prod := Production.instance
	var souvenirs := services("souvenirs")
	var foule := _foule()
	var pluie := _pluie()
	for bid in heb:
		var st: Dictionary = heb[bid]
		var n := clients(int(bid))
		if n <= 0:
			continue
		var sp := spec(int(bid))
		var e := int(sp.get("etoiles", 2))
		var p := pos_of(int(bid))
		# La nuitée et la taxe de séjour.
		var ca := float(n) * float(st.prix)
		var taxe := float(n) * TourismeTypes.taxe(e)
		st.jour.nuitees = int(st.jour.nuitees) + n
		jour.nuitees = int(jour.nuitees) + n
		jour.hebergement = float(jour.hebergement) + ca
		jour.taxe = float(jour.taxe) + taxe
		_flux(int(bid), "Taxe de séjour (hébergements)", taxe)
		jour.ville = float(jour.ville) + taxe
		# Repas : au restaurant de l'hôtel, sinon en ville.
		var repas := float(n) * REPAS_JOUR
		var dehors := repas * (maxf(0.05, 0.4 - Gestion.effet_de(int(bid), "repas")) if bool(sp.get("restaurant", false)) else 1.0)
		if bool(sp.get("cuisine", false)):
			dehors *= 0.5
		ca += (repas - dehors) * Ressources.REPAS * (1.0 + 0.3 * maxf(0.0, float(e) - 2.0))
		var servis := 0.0
		if prod != null and is_instance_valid(prod) and dehors > 0.0:
			var r := prod.repas_touristes(p, dehors)
			jour.restaurants = float(jour.restaurants) + float(r[0])
			servis = float(r[1])
		var faim := 1.0 if dehors <= 0.0 else clampf(servis / dehors, 0.0, 1.0)
		# Courses.
		var trouve := 1.0
		if prod != null and is_instance_valid(prod):
			var panier := {}
			for g in PANIER:
				panier[g] = float(PANIER[g]) * float(n) * (2.5 if bool(sp.get("cuisine", false)) else 1.0)
			var r2 := prod.achats_touristes(p, panier)
			jour.commerces = float(jour.commerces) + float(r2[0])
			trouve = float(r2[1])
		# Souvenirs.
		var boutique := false
		for sb in souvenirs:
			if pos_of(int(sb)).distance_to(p) <= 4000.0 and _staff_ok(int(sb)):
				boutique = true
				break
		if boutique:
			var v := float(n) * float(TourismeTypes.TYPES.boutique_souvenirs_ville.touris.panier) * (0.5 + float(e) * 0.2) / maxf(1.0, float(souvenirs.size()) * 0.5)
			jour.souvenirs = float(jour.souvenirs) + v
			# Boutique privée : la ville touche l'impôt sur ses bénéfices (marge 30 %).
			var imp := v * 0.3 * Production.IMPOT_BENEFICES * BudgetCommunal.facteur("benefices")
			_flux(int(souvenirs[0]), "Tourisme : impôt des boutiques de souvenirs", imp)
			jour.impots = float(jour.impots) + imp
			jour.ville = float(jour.ville) + imp
		# Visites des sites proches.
		var vis := _visites_depuis(p, float(n) * VISITES_JOUR * (1.0 - 0.25 * pluie if not bool(sp.get("animation", false)) else 0.8))
		# Comptes de l'hébergement : salaires, charges, impôt.
		var emplois := Ameliorations.cap(buildings.buildings.get(int(bid), {}), "emplois")
		var charges := float(emplois) * SALAIRE_MOYEN * ReglagesPartie.actuel.salaires / 30.44 + float(n) * float(st.prix) * CHARGES_NUIT \
			+ Gestion.entretien_de(int(bid))
		st.jour.ca = float(st.jour.ca) + ca
		st.jour.charges = float(st.jour.charges) + charges
		if est_municipal(int(bid)):
			_flux(int(bid), "Tourisme : %s" % String(BuildingCatalog.get_type(_type_of(int(bid))).get("name", "hébergement")), ca - charges)
			jour.ville = float(jour.ville) + ca - charges
		else:
			var benef := ca - charges
			st.compte = float(st.compte) + benef
			if benef > 0.0:
				var imp := benef * Production.IMPOT_BENEFICES * BudgetCommunal.facteur("benefices")
				st.compte = float(st.compte) - imp
				_flux(int(bid), "Tourisme : impôt sur les bénéfices des hôtels", imp)
				jour.impots = float(jour.impots) + imp
				jour.ville = float(jour.ville) + imp
		# Satisfaction des clients présents.
		var sat := clampf(_satisfaction(int(bid), faim, trouve, vis, boutique, foule) + Gestion.effet_de(int(bid), "satisf"), 0.5, 5.0)
		for c in st.clients:
			c[2] = lerpf(float(c[2]), sat, 0.5)
		st.satisf = lerpf(float(st.satisf), sat, 0.2)
		_pensees_sejour(int(bid), sp, faim, trouve, vis, boutique, foule, n)
	# Voyages organisés : des autocars d'excursionnistes (sans nuitée).
	_autocars(now)
	_recettes_nature()
	if pluie > 0.5 and jour.nuitees > 0:
		_penser("pluie")
	if not services("office").is_empty() and int(jour.nuitees) > 0:
		_penser("office")
	var acc := acces()
	if int(acc.gare) > 0 and int(jour.arrivees) > 0:
		_penser("train")


func _staff_ok(bid: int) -> bool:
	if ignore_staff:
		return true
	var emplois := int(BuildingCatalog.get_type(_type_of(bid)).get("emplois", 0))
	return emplois <= 0 or (population != null and not (population.by_job.get(bid, []) as Array).is_empty())


## Répartit n sorties depuis un point vers les sites (plus pour les grands et les proches).
## Renvoie {kind: part des sorties} pour la satisfaction.
func _visites_depuis(p: Vector3, n: float) -> Dictionary:
	var poids := {}
	var somme := 0.0
	var out := {"loin": 0.0, "note": 0.0}
	for i in sites.size():
		var st: Dictionary = sites[i]
		var d := Vector2(p.x, p.z).distance_to(Vector2((st.pos as Vector3).x, (st.pos as Vector3).z))
		if d > PORTEE:
			continue
		var w := float(st.pts) / pow(1.0 + d / 3000.0, 2.0)
		poids[i] = w
		somme += w
	if somme <= 0.0 or n <= 0.0:
		return out
	var note_m := 0.0
	var dist_m := 0.0
	for i in poids:
		var st: Dictionary = sites[i]
		var part := float(poids[i]) / somme
		var k := "%s:%s" % [String(st.kind), str(st.key)]
		visites_jour[k] = float(visites_jour.get(k, 0.0)) + n * part
		out[String(st.kind)] = float(out.get(String(st.kind), 0.0)) + part
		if st.has("genre"):
			var gk := "g_" + String(st.genre)
			out[gk] = float(out.get(gk, 0.0)) + part
			if bool(st.get("surveille", false)):
				out["surveille"] = float(out.get("surveille", 0.0)) + part
			if not bool(st.get("acces", true)):
				out["pas_acces"] = float(out.get("pas_acces", 0.0)) + part
			if float(st.get("pollue", 0.0)) > 0.3:
				out["eau_sale"] = float(out.get("eau_sale", 0.0)) + part
			if float(st.get("sentiers", 0.0)) >= 1.0:
				out["sentiers"] = float(out.get("sentiers", 0.0)) + part
		note_m += float(st.note) * part
		dist_m += Vector2(p.x, p.z).distance_to(Vector2((st.pos as Vector3).x, (st.pos as Vector3).z)) * part
	jour.visites = int(jour.visites) + roundi(n)
	out.note = note_m
	out.loin = dist_m
	return out


## Les attractions sont-elles bondées ? (refus aux musées, foule dans les parcs) : 0 à 1.
func _foule() -> float:
	var mu := Musee.instance
	var r := 0.0
	var v := 0.0
	if mu != null and is_instance_valid(mu):
		for k in mu.musees:
			r += float(mu.musees[k].hier.refus)
			v += float(mu.musees[k].hier.visiteurs)
	return clampf(r / maxf(v + r, 1.0) * 2.0, 0.0, 1.0)


func _satisfaction(bid: int, faim: float, trouve: float, vis: Dictionary, boutique: bool, foule: float) -> float:
	var s := 0.0
	s += note(bid) * 0.3
	s += (1.0 + 4.0 * faim) * 0.2
	var att := 0.5
	if sites.is_empty():
		att = 0.5
	else:
		att = clampf(float(vis.get("note", 0.0)), 0.5, 5.0)
		var varie := 0
		for k in KINDS_VISITE:
			if float(vis.get(k, 0.0)) > 0.1:
				varie += 1
		att = clampf(att + 0.25 * maxf(0.0, float(varie) - 1.0), 0.5, 5.0)
	s += att * 0.3
	s += (2.5 + 2.5 * clampf(trouve, 0.0, 1.0)) * 0.1
	s += (4.0 if boutique else 3.0) * 0.1
	s -= foule * 0.8
	if float(vis.get("loin", 0.0)) > 8000.0:
		s -= 0.4
	s -= 0.6 * float(vis.get("pas_acces", 0.0)) + 0.8 * float(vis.get("eau_sale", 0.0))
	return clampf(s, 0.5, 5.0)


func _pensees_sejour(bid: int, sp: Dictionary, faim: float, trouve: float, vis: Dictionary, boutique: bool, foule: float, n: int) -> void:
	var w := maxi(1, n / 20)
	var st: Dictionary = heb[bid]
	var ref := float(sp.get("prix", TourismeTypes.prix_ref(int(sp.get("etoiles", 2)))))
	if float(st.prix) > ref * 1.35:
		_penser("cher", [roundi(float(st.prix))], w)
	elif float(st.prix) <= ref * 0.9:
		_penser("bon_prix", [], w)
	if faim < 0.6:
		_penser("faim", [], w)
	elif faim > 0.95 and rng.randf() < 0.5:
		_penser("resto", [], w)
	if trouve < 0.5:
		_penser("rayons_vides", [], w)
	elif bool(sp.get("cuisine", false)) and trouve > 0.9:
		_penser("courses", [], w)
	if sites.is_empty():
		_penser("rien", [], w)
	for k in ["parc", "zoo", "musee", "spectacles", "patrimoine"]:
		if float(vis.get(k, 0.0)) > 0.25:
			_penser(k, [], w)
	for g in SitesNaturels.ORDER:
		if float(vis.get("g_" + String(g), 0.0)) > 0.2:
			var cle := "plage_surveillee" if g == "plage" and float(vis.get("surveille", 0.0)) > 0.1 else String(g)
			_penser(cle, [], w)
	for k in ["sentiers", "pas_acces", "eau_sale"]:
		if float(vis.get(k, 0.0)) > 0.1:
			_penser(k, [], w)
	if float(vis.get("nature", 0.0)) > 0.3 and _pluie() > 0.5:
		_penser("nature_pluie", [], w)
	var varie := 0
	for k in KINDS_VISITE:
		if float(vis.get(k, 0.0)) > 0.1:
			varie += 1
	if varie >= 3:
		_penser("varie", [], w)
	_penser("souvenirs" if boutique else "pas_souvenirs")
	if foule > 0.3:
		_penser("foule", [], w)
	if float(vis.get("loin", 0.0)) > 8000.0:
		_penser("loin", [], w)
	if String(sp.get("genre", "")) == "camping" and rng.randf() < 0.4:
		_penser("camping")
	if int(sp.get("etoiles", 2)) >= 5 and rng.randf() < 0.5:
		_penser("luxe")
	if note(bid) >= 4.0 and faim > 0.9 and not sites.is_empty():
		_penser("super", [], w)


## Location de kayaks et de pédalos (bases nautiques municipales) : € par visiteur.
func _recettes_nature() -> void:
	for st in sites:
		if String(st.kind) != "nature" or float(st.get("recette", 0.0)) <= 0.0:
			continue
		var v := float(visites_jour.get("nature:%s" % String(st.key), 0.0))
		var r := v * float(st.recette)
		if r <= 0.0:
			continue
		var bid := -1
		for b in st.amenag:
			if float(TourismeTypes.spec_of(_type_of(int(b))).get("recette", 0.0)) > 0.0:
				bid = int(b)
				break
		_flux(bid, "Tourisme : locations des bases nautiques", r)
		jour.ville = float(jour.ville) + r
		jour.nature = float(jour.get("nature", 0.0)) + r


## Voyages organisés : autocars de 50 personnes, garés au parking d'autocars.
func _autocars(now: Dictionary) -> void:
	var parkings := services("autocars")
	if parkings.is_empty() or attrait_total <= 0.0:
		return
	var places := 0
	for pid in parkings:
		places += int(TourismeTypes.spec_of(_type_of(int(pid))).get("places", 12))
	var n := minf(float(places), attrait_total * 0.12 * float(SAISON.get(int(now.month), 1.0)) * (0.5 + reputation / 6.0) * campagne_effet())
	var cars := _arrondi(n)
	if cars <= 0:
		return
	var gens := cars * 50
	jour.autocars = int(jour.autocars) + cars
	jour.excursions = int(jour.excursions) + gens
	var p := pos_of(int(parkings[0]))
	_visites_depuis(p, float(gens) * 1.6)
	_prevoir_autocars(cars, int(parkings[0]))
	var prod := Production.instance
	if prod != null and is_instance_valid(prod):
		var r := prod.repas_touristes(p, float(gens) * 0.8)
		jour.restaurants = float(jour.restaurants) + float(r[0])
	# Droit de stationnement des cars (20 €) pour la ville.
	_flux(int(parkings[0]), "Tourisme : stationnement des autocars", 20.0 * cars)
	jour.ville = float(jour.ville) + 20.0 * cars
	if not services("souvenirs").is_empty():
		jour.souvenirs = float(jour.souvenirs) + float(gens) * 4.0
	_penser("autocar", [], cars)


# --- Autocars sur les routes ----------------------------------------------------------------

func _traffic() -> Traffic:
	if transport == null or transport.traffic == null or not transport.traffic.enabled:
		return null
	return transport.traffic


## Les cars du jour arrivent le matin (8 h à 12 h), un car dessiné pour quelques vrais.
func _prevoir_autocars(cars: int, parking: int) -> void:
	cars_prevus.clear()
	if _traffic() == null:
		return
	var n := mini(cars, AUTOCARS_VISIBLES * 2)
	# Les sites que visitent les groupes : les plus attirants, nature comprise.
	var cibles := sites.duplicate()
	cibles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.pts) > float(b.pts))
	cibles = cibles.slice(0, 4)
	for i in n:
		var site: Dictionary = cibles[i % cibles.size()] if not cibles.is_empty() else {}
		cars_prevus.append({"h": 8.0 + 4.0 * float(i) / maxf(1.0, float(n)) + rng.randf_range(0.0, 0.4), "parking": parking,
			"site": site.get("pos", Vector3.INF), "nom": String(site.get("nom", ""))})


func _rouler_autocars(h: float) -> void:
	if cars_prevus.is_empty():
		return
	for c in cars_prevus.duplicate():
		if float(c.h) <= h:
			cars_prevus.erase(c)
			lancer_autocar(int(c.parking), c.site)


func autocars_visibles() -> int:
	var tr := _traffic()
	if tr == null:
		return 0
	var n := 0
	for v in tr.vehicles:
		var tag := int(v.get("delivery", -1))
		if tag >= TAG_AUTOCAR and tag < TAG_AUTOCAR + 1_000_000:
			n += 1
	return n


## Point de route le plus proche (pour s'arrêter devant un bâtiment ou un site).
func _arret_route(p: Vector3, rayon: float) -> Dictionary:
	if transport == null:
		return {}
	var best := {}
	var best_d := INF
	for eid in transport.edges_near(p, rayon):
		var e: Dictionary = transport.network.edges[eid]
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD or String(e.t) in ["autoroute", "bretelle"]:
			continue
		var hit: Dictionary = transport.network.nearest_on_edge(eid, p)
		if float(hit.dist) < best_d:
			best_d = float(hit.dist)
			best = {"e": int(eid), "s": float(hit.get("s", 0.0)), "a": int(e.a), "b": int(e.b), "len": float(e.len)}
	return best


## L'entrée de la ville : le bout de route (impasse) le plus loin du parking,
## relié à lui. Les cars viennent de là et y repartent.
func entree_ville(depuis: int) -> int:
	if transport == null or not transport.network.nodes.has(depuis):
		return -1
	var net = transport.network
	var p0: Vector3 = net.node_pos(depuis)
	var best := depuis
	var best_d := -1.0
	for nid in net.component(depuis):
		if net.node_mode(nid) != TransportTypes.Mode.ROAD or net.degree(nid) != 1:
			continue
		var d := (net.node_pos(nid) as Vector3).distance_to(p0)
		if d > best_d:
			best_d = d
			best = nid
	return best


## Un car de tourisme part de l'entrée de la ville, dépose son groupe au parking,
## l'emmène voir un site puis repart. Faux s'il n'a pas pu partir.
func lancer_autocar(parking: int, site: Variant = Vector3.INF) -> bool:
	var tr := _traffic()
	if tr == null or autocars_visibles() >= AUTOCARS_VISIBLES:
		return false
	var pk := _arret_route(porte(parking), 60.0)
	if pk.is_empty():
		return false
	var depart := int(pk.a) if float(pk.s) <= float(pk.len) * 0.5 else int(pk.b)
	var entree := entree_ville(depart)
	var halts: Array = [{"e": int(pk.e), "s": float(pk.s)}]
	if site is Vector3 and (site as Vector3).is_finite():
		var arret := _arret_route(site, 1200.0)
		if not arret.is_empty() and int(arret.e) != int(pk.e):
			halts.append({"e": int(arret.e), "s": float(arret.s)})
	if entree != depart:
		halts.append({"n": entree})
	_car_n = (_car_n + 1) % 1_000_000
	return tr.add_delivery_vehicle(TAG_AUTOCAR + _car_n, "autocar", entree if entree >= 0 else depart, halts)


## Fin de journée : statistiques, historique, avis du jour.
func _cloture() -> void:
	jour.excursions = int(jour.excursions) + _excursionnistes()
	for f in jour:
		if jour[f] is int:
			total[f] = int(total.get(f, 0)) + int(jour[f])
		else:
			total[f] = float(total.get(f, 0.0)) + float(jour[f])
	if int(jour.arrivees) + int(jour.nuitees) + int(jour.excursions) > 0 or not historique.is_empty():
		historique.append([last_day, int(jour.arrivees), int(jour.nuitees), int(jour.refus), depenses(jour)])
		if historique.size() > 60:
			historique.pop_front()
	hier = jour
	jour = _empty_stats()
	for bid in heb:
		var st: Dictionary = heb[bid]
		st.mois_ca = float(st.mois_ca) * 0.967 + float(st.jour.ca)
		st.mois_charges = float(st.mois_charges) * 0.967 + float(st.jour.charges)
		st.hier = st.jour
		st.jour = {"arrivees": 0, "nuitees": 0, "refus": 0, "ca": 0.0, "charges": 0.0}
		st.note = note(int(bid))
		if float(st.mois_ca) < float(st.mois_charges) * 0.85 and float(st.mois_charges) > 0.0:
			st.rouge = int(st.rouge) + 1
			if int(st.rouge) == 45:
				message.emit("Tourisme : %s perd de l'argent depuis des semaines (trop peu de clients ou un prix trop bas)." % String(st.nom))
		else:
			st.rouge = 0
	for p in pensees.keys():
		pensees[p] = int(int(pensees[p]) * 0.6)
		if int(pensees[p]) <= 0:
			pensees.erase(p)


## Touristes venus à la journée dans les attractions hier (comptés par chaque système).
func _excursionnistes() -> int:
	var n := 0
	var pl := ParcLoisirs.instance
	if pl != null and is_instance_valid(pl):
		for e in pl.parcs:
			n += int(pl.parcs[e].get("hier", {}).get("touristes", 0))
	var zs := ZooSysteme.instance
	if zs != null and is_instance_valid(zs):
		for e in zs.zoos:
			n += int(zs.zoos[e].get("hier", {}).get("touristes", 0))
	var mu := Musee.instance
	if mu != null and is_instance_valid(mu):
		for k in mu.musees:
			n += int(mu.musees[k].hier.get("touristes", 0))
	return n


static func depenses(st: Dictionary) -> float:
	return float(st.get("hebergement", 0.0)) + float(st.get("restaurants", 0.0)) + float(st.get("commerces", 0.0)) + float(st.get("souvenirs", 0.0))


# --- Campagnes -----------------------------------------------------------------------------------

func lancer_campagne(id: String) -> String:
	if not CAMPAGNES.has(id):
		return "Campagne inconnue."
	if campagne != "":
		return "Une campagne est déjà en cours (%s)." % String(CAMPAGNES[campagne].name)
	var c: Dictionary = CAMPAGNES[id]
	if buildings != null and not buildings.unlimited_money and buildings.money < int(c.prix):
		return "Pas assez d'argent dans la caisse (%s)." % BuildingSystem.format_money(int(c.prix))
	_flux(-1, "Tourisme : publicité", -float(c.prix))
	campagne = id
	campagne_fin = maxi(last_day, 0) + int(c.jours)
	message.emit("Tourisme : « %s » lancée pour %d jours. Les réservations vont affluer." % [String(c.name), int(c.jours)])
	changed.emit()
	return ""


func jours_campagne() -> int:
	return maxi(0, campagne_fin - last_day) if campagne != "" else 0


# --- Argent ------------------------------------------------------------------------------------------

func _flux(bid: int, poste: String, montant: float) -> void:
	if buildings == null or buildings.unlimited_money or absf(montant) < 0.01:
		return
	var prev := Pays.au_batiment(bid) if bid >= 0 else -1
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		if montant > 0.0:
			bc.recette(poste, montant)
		else:
			bc.depense(poste, -montant)
	else:
		var f := float(_frac.get(0, 0.0)) + montant
		var whole := int(f)
		_frac[0] = f - whole
		if whole != 0:
			buildings.money += whole
	Pays.retour(prev)


func _warn(k: String, text: String, every := 86400.0) -> void:
	if clock - float(_warned.get(k, -INF)) < every:
		return
	_warned[k] = clock
	message.emit(text)


func _arrondi(x: float) -> int:
	var b := int(floorf(x))
	return b + (1 if rng.randf() < x - b else 0)


func _penser(cle: String, args: Array = [], poids := 1) -> void:
	pensees[cle] = int(pensees.get(cle, 0)) + poids
	var txt := String(PENSEES.get(cle, cle))
	if not args.is_empty():
		txt = txt % args
	if dernieres.is_empty() or String(dernieres[0]) != txt:
		dernieres.push_front(txt)
		if dernieres.size() > 10:
			dernieres.resize(10)


# --- Conseils, avis des habitants, résumé -----------------------------------------------------

func conseils() -> Array:
	var out: Array = []
	if sites.is_empty():
		out.append("Rien à visiter : un parc de loisirs, un zoo, un musée, une salle de spectacle, un monument ou un beau site naturel (plage, lac, montagne) font venir les touristes.")
	if heb.is_empty():
		out.append("Aucun hébergement : les touristes viennent à la journée et repartent le soir. Un hôtel ou un camping les fait rester (et dépenser).")
	elif int(hier.refus) > 0:
		out.append("%d touristes refusés hier faute de lits : construis un hébergement de plus." % int(hier.refus))
	var faim := int(pensees.get("faim", 0))
	if faim > 3:
		out.append("Les touristes ne trouvent pas où manger : un café, un restaurant ou un hôtel avec restaurant.")
	if services("souvenirs").is_empty() and clients_total() > 30:
		out.append("Une boutique de souvenirs : les touristes ont de l'argent à dépenser et des tantes à qui envoyer des cartes postales.")
	if services("office").is_empty() and clients_total() > 50:
		out.append("Un office de tourisme : +10 % de touristes, des séjours plus longs.")
	var acc := acces()
	if int(acc.gare) == 0 and attrait_total > 8.0:
		out.append("Une gare (touche L) : les touristes viennent aussi en train.")
	if services("autocars").is_empty() and attrait_total > 6.0:
		out.append("Un parking d'autocars : les voyages organisés viendraient à la journée.")
	for bid in heb:
		if not relie(int(bid)):
			out.append("%s n'est relié à aucune route : presque personne ne le trouve." % nom(int(bid)))
		elif not ignore_staff and personnel(int(bid)) < 0.5 and bool(heb[bid].ouvert):
			out.append("%s manque de personnel : la moitié des chambres restent fermées." % nom(int(bid)))
	for st in sites:
		if String(st.kind) != "nature":
			continue
		var g := String(st.genre)
		if not bool(st.acces):
			out.append("%s (%s) : aucune route à moins de %d m. Une route ou un parking de randonnée le rendrait accessible." % [String(st.nom), SitesNaturels.nom_genre(g).to_lower(), int(ACCES_ROUTE)])
		elif (st.amenag as Array).is_empty():
			match g:
				"plage":
					out.append("%s : un poste de secours (plage surveillée) ou une base nautique attirerait les familles." % String(st.nom))
				"lac", "riviere":
					out.append("%s : une base nautique (kayaks, pédalos) attirerait du monde, et rapporterait à la ville." % String(st.nom))
				"sommet", "cote", "glacier":
					out.append("%s : un belvédère et un parking de randonnée feraient venir les marcheurs." % String(st.nom))
				"foret", "marais":
					out.append("%s : une maison de la nature et des sentiers (outil Chemin) attireraient les promeneurs." % String(st.nom))
		if float(st.get("pollue", 0.0)) > 0.3:
			out.append("%s : l'eau est polluée (usines, égouts) et les baigneurs fuient. Voir la carte Pollution de l'eau (N)." % String(st.nom))
	if reputation < 2.5:
		out.append("Réputation en berne : soigne les repas, les prix et la variété des visites.")
	return out


func avis_facteurs() -> Array:
	return [{"id": "tourisme", "theme": "commerces", "f": satisfaction_of}]


func satisfaction_of(_p: Dictionary) -> Array:
	var c := clients_total()
	if c <= 0 or population == null or population.persons.is_empty():
		return [0.0, []]
	var r := float(c) / float(population.persons.size())
	if r > 0.6:
		return [-1.5, ["- Trop de touristes : plus une table libre en terrasse"]]
	if float(hier.restaurants) + float(hier.commerces) > 500.0:
		return [0.8, ["+ Les touristes font marcher les commerces"]]
	return [0.0, []]


func summary() -> String:
	if heb.is_empty() and int(hier.excursions) == 0:
		return ""
	return "Tourisme : %d touristes en ville, %d lits" % [clients_total(), lits_total()]


# --- Sauvegarde -------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var h := {}
	for bid in heb:
		var st: Dictionary = heb[bid]
		h[str(bid)] = {"nom": st.nom, "prix": st.prix, "ouvert": st.ouvert, "clients": st.clients, "satisf": st.satisf, "hier": st.hier,
			"compte": st.compte, "mois_ca": st.mois_ca, "mois_charges": st.mois_charges, "rouge": st.rouge}
	return {"heb": h, "reputation": reputation, "campagne": campagne, "campagne_fin": campagne_fin, "hier": hier, "total": total,
		"historique": historique, "pensees": pensees, "dernieres": dernieres, "last_day": last_day, "visites": visites_jour}


func from_dict(d: Dictionary) -> void:
	clear()
	_sync()
	var h: Dictionary = d.get("heb", {})
	for k in h:
		var bid := int(k)
		if not heb.has(bid):
			continue
		var st: Dictionary = heb[bid]
		var src: Dictionary = h[k]
		for f in src:
			st[f] = src[f]
		var cl: Array = []
		for c in st.clients:
			cl.append([int(c[0]), int(c[1]), float(c[2])])
		st.clients = cl
		st.rouge = int(st.rouge)
		var hh: Dictionary = st.hier
		st.hier = {"arrivees": int(hh.get("arrivees", 0)), "nuitees": int(hh.get("nuitees", 0)), "refus": int(hh.get("refus", 0)),
			"ca": float(hh.get("ca", 0.0)), "charges": float(hh.get("charges", 0.0))}
	reputation = float(d.get("reputation", 3.0))
	campagne = String(d.get("campagne", ""))
	campagne_fin = int(d.get("campagne_fin", -1))
	for part in ["hier", "total"]:
		var s0 := _empty_stats()
		var got: Dictionary = d.get(part, {})
		for f in s0:
			s0[f] = int(got.get(f, 0)) if s0[f] is int else float(got.get(f, 0.0))
		if part == "hier":
			hier = s0
		else:
			total = s0
	historique = []
	for e in d.get("historique", []):
		historique.append([int(e[0]), int(e[1]), int(e[2]), int(e[3]), float(e[4])])
	pensees = {}
	var pd: Dictionary = d.get("pensees", {})
	for k in pd:
		pensees[String(k)] = int(pd[k])
	dernieres = (d.get("dernieres", []) as Array).duplicate()
	last_day = int(d.get("last_day", -1))
	visites_jour = (d.get("visites", {}) as Dictionary).duplicate()
	_maj_sites()
	changed.emit()
