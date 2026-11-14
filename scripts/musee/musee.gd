class_name Musee
extends Node3D
## Gestion des musées : collections, réputation en étoiles, visiteurs, billets,
## boutique et café, personnel, assurance, expositions temporaires, ce que
## disent les visiteurs.
##
## - Un musée est un bâtiment en murs fins (PlanEditor) dont l'usage est
##   « Musée » (Mobilier.USAGES), ou un bâtiment « Musée » du catalogue (B),
##   ou un modèle de l'Atelier qui a la fonction « Musée ». La billetterie est
##   indispensable pour ouvrir.
## - Réputation : le prestige des œuvres exposées (MuseeObjets), pondéré par
##   la salle (une momie dans la salle égyptienne vaut plus qu'au café),
##   l'éclairage de la salle et la place autour des œuvres ; plus le confort
##   de visite (bancs, cartels, plans, audioguides), les services (vestiaire,
##   toilettes, boutique, café), la variété des collections, l'exposition du
##   moment, et moins les dégâts (objets fragiles sans vitrine ni cordon).
## - Visiteurs : des habitants (selon la population et la note) et des
##   touristes (selon le prestige), plus nombreux le week-end, le mercredi, en
##   été et… quand il pleut. Fermé le lundi. Le prix du billet les retient.
##   La capacité dépend de la surface (une personne pour 4 m², visite d'1 h 30).
## - Argent : billets, boutique, café, audioguides → caisse de la ville
##   (BudgetCommunal, postes « Musée ») ; salaires, assurance des œuvres et
##   expositions → dépenses.

signal changed
signal message(text: String)

static var instance: Musee

const STEP := 3600.0
const PRIX_BILLET := 12.0
## Part des visiteurs qui paient plein tarif (moins de 18 ans gratuits, réductions).
const PART_PAYANTE := 0.7
const TAXE_SEJOUR := 1.5
## Dépenses moyennes par visiteur.
const BOUTIQUE_PANIER := 4.5
const CAFE_PANIER := 5.0
const AUDIOGUIDE_PRIX := 3.0
const SALAIRE_MOYEN := 2050.0
## Assurance des œuvres : part de la valeur par an.
const ASSURANCE_AN := 0.0015
## Habitants qui vont au musée un jour donné (pour une note de 3 étoiles).
const HABITANTS_JOUR := 0.0025
## Touristes par jour et par point de prestige.
const TOURISTES_PRESTIGE := 0.9
## Surface par visiteur présent, durée de visite (h).
const M2_VISITEUR := 4.0
const DUREE_VISITE := 1.5
const MOIS_SAISON := {1: 0.55, 2: 0.65, 3: 0.75, 4: 0.95, 5: 1.0, 6: 1.05, 7: 1.4, 8: 1.45, 9: 0.95, 10: 0.9, 11: 0.65, 12: 0.85}
const ARRIVEES := {10: 0.16, 11: 0.16, 12: 0.1, 13: 0.1, 14: 0.15, 15: 0.14, 16: 0.11, 17: 0.08}
## Bâtiment du catalogue (sans intérieur) : sa collection « de série ».
const CATALOGUE_PRESTIGE := 140.0
const CATALOGUE_VALEUR := 12_000_000
const NOMS := ["Musée des Beaux-Arts", "Musée d'Histoire", "Muséum de la Ville", "Musée des Arts et Métiers", "Musée des Trois Collines",
	"Musée du Patrimoine", "Musée de la Grande Galerie", "Musée Municipal"]

## Expositions temporaires : thème, prix, durée (jours), bonus de prestige.
const EXPOS := {
	"pharaons": {"name": "Trésors des pharaons", "theme": "antiquite", "prix": 400_000, "jours": 60, "bonus": 90.0},
	"impressionnistes": {"name": "Lumières impressionnistes", "theme": "art", "prix": 350_000, "jours": 60, "bonus": 80.0},
	"dinosaures": {"name": "Dinosaures géants", "theme": "nature", "prix": 300_000, "jours": 45, "bonus": 85.0},
	"vikings": {"name": "Vikings, rois des mers", "theme": "histoire", "prix": 220_000, "jours": 45, "bonus": 60.0},
	"samourais": {"name": "Samouraïs, l'art de la guerre", "theme": "monde", "prix": 260_000, "jours": 45, "bonus": 65.0},
	"leonard": {"name": "Les machines du génie de la Renaissance", "theme": "sciences", "prix": 240_000, "jours": 45, "bonus": 65.0},
	"contemporain": {"name": "Art contemporain : est-ce de l'art ?", "theme": "art", "prix": 120_000, "jours": 30, "bonus": 35.0},
	"jouets": {"name": "Jouets d'hier et d'aujourd'hui", "theme": "jouets", "prix": 80_000, "jours": 30, "bonus": 30.0},
	"cinema": {"name": "Légendes du grand écran", "theme": "cinema", "prix": 280_000, "jours": 45, "bonus": 70.0},
	"rock": {"name": "Rock'n'roll : soixante-dix ans de guitares", "theme": "musique", "prix": 200_000, "jours": 45, "bonus": 60.0},
	"couture": {"name": "Haute couture, un siècle d'élégance", "theme": "mode", "prix": 260_000, "jours": 45, "bonus": 65.0},
	"lune": {"name": "Objectif Lune", "theme": "espace", "prix": 320_000, "jours": 60, "bonus": 80.0},
	"olympisme": {"name": "La flamme olympique", "theme": "sport", "prix": 180_000, "jours": 30, "bonus": 55.0},
	"automobiles": {"name": "Voitures de légende", "theme": "automobile", "prix": 240_000, "jours": 45, "bonus": 65.0},
	"paquebots": {"name": "Paquebots de légende", "theme": "marine", "prix": 160_000, "jours": 45, "bonus": 50.0},
	"premiers_artistes": {"name": "Les premiers artistes de l'âge de pierre", "theme": "prehistoire", "prix": 150_000, "jours": 45, "bonus": 50.0},
	"heros_papier": {"name": "Héros de papier", "theme": "bd", "prix": 90_000, "jours": 30, "bonus": 40.0},
	"grands_crus": {"name": "Le goût des grands crus", "theme": "gastronomie", "prix": 70_000, "jours": 30, "bonus": 30.0},
	"trains": {"name": "L'âge d'or du chemin de fer", "theme": "transports", "prix": 140_000, "jours": 45, "bonus": 50.0},
}
const EXPO_ORDER := ["pharaons", "impressionnistes", "dinosaures", "vikings", "samourais", "leonard", "contemporain", "jouets",
	"cinema", "rock", "couture", "lune", "olympisme", "automobiles", "paquebots", "premiers_artistes", "heros_papier", "grands_crus", "trains"]

## Ce que disent les visiteurs (réaliste, avec une pointe d'humour).
const PENSEES := {
	"super": "Une visite magnifique. J'ai même lu les cartels, c'est dire.",
	"star": "J'ai enfin vu %s en vrai. Plus petit qu'à la télé, mais quelle émotion !",
	"dinos": "Le squelette du dinosaure m'a regardé de travers. Les enfants veulent revenir demain.",
	"momie": "La momie avait l'air plus reposée que moi un lundi matin.",
	"sombre": "Il fait si sombre que j'ai admiré un chef-d'œuvre… ou un extincteur.",
	"bancs": "Pas un banc dans tout le musée : j'ai visité l'Antiquité debout.",
	"rien": "Trois vases et une affiche. J'ai les mêmes chez ma grand-mère.",
	"cher": "%d € le billet ? À ce prix-là, je repars avec un tableau.",
	"bon_prix": "Pour le prix d'un sandwich, j'ai vu cinq siècles d'histoire.",
	"gratuit": "Gratuit aujourd'hui ! Toute la ville est là, et moi aussi.",
	"boutique": "J'ai acheté un mug avec un pharaon dessus. Il me juge pendant le petit-déjeuner.",
	"pas_boutique": "Pas de boutique ? Où vais-je acheter ma gomme en forme de dinosaure ?",
	"cafe": "Le café du musée vaut le détour. Les œuvres aussi, paraît-il.",
	"pas_cafe": "Deux heures de visite et pas un café. Je m'effondre devant la Vénus.",
	"toilettes": "Les toilettes ? « Dans l'aile Renaissance, au fond à gauche, après les Flamands. » Il n'y en a pas.",
	"foule": "Il y avait plus de monde devant le tableau que dans le tableau.",
	"melange": "Une momie à côté d'une machine à vapeur : je n'ai pas tout compris au parcours.",
	"moderne": "Un enfant a crié « C'est moche ! » devant l'art moderne. Il n'avait pas tout à fait tort.",
	"expo": "L'exposition « %s » valait à elle seule le déplacement.",
	"degats": "Un visiteur a touché une œuvre. Le gardien a fait un bond de deux mètres.",
	"pluie": "Il pleut : le musée était plein. Les œuvres, elles, sont restées au sec.",
	"lundi": "Fermé le lundi. Comme tous les musées. Comme moi, d'ailleurs.",
	"audioguide": "L'audioguide parle avec la voix d'un acteur célèbre. J'ai tout écouté, deux fois.",
	"vestiaire": "Le vestiaire m'a pris mon manteau, mon parapluie et presque mon chien.",
}

var mob: Mobilier
var buildings: BuildingSystem
var population: Population
var ambiance: DayNight

## Clé (plan « plan_N » ou « bat_<bid> ») → état du musée.
var musees: Dictionary = {}
var clock := -1.0
var last_unix := -1.0
var last_day := -1
var rng := RandomNumberGenerator.new()
var visuels: MuseeVisuels
var _dirty := true
var _cache: Dictionary = {}
var _warned: Dictionary = {}
## Habitants allés au musée : pid → jour.
var sorties: Dictionary = {}


func _init() -> void:
	rng.seed = 4_242_017
	add_to_group("avis_sources")


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	visuels = MuseeVisuels.new()
	visuels.name = "Visiteurs"
	visuels.setup(self)
	add_child(visuels)


func setup(m: Mobilier, b: BuildingSystem, p: Population, a: DayNight) -> void:
	mob = m
	buildings = b
	population = p
	ambiance = a
	if mob != null:
		mob.changed.connect(func() -> void:
			_dirty = true
			_cache.clear())
	if buildings != null:
		buildings.changed.connect(func() -> void: _dirty = true)


func clear() -> void:
	musees.clear()
	sorties.clear()
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	_cache.clear()
	_dirty = true
	changed.emit()


# --- Quels musées ? -------------------------------------------------------------------------------

static func _empty_stats() -> Dictionary:
	return {"visiteurs": 0, "touristes": 0, "habitants": 0, "billets": 0.0, "boutique": 0.0, "cafe": 0.0, "audioguides": 0.0,
		"depenses": 0.0, "refus": 0, "degats": 0}


func _new_state(key: String) -> Dictionary:
	return {"nom": NOMS[absi(hash(key)) % NOMS.size()], "prix": PRIX_BILLET, "gratuit_dimanche": true, "note": 0.0,
		"jour": _empty_stats(), "hier": _empty_stats(), "total": _empty_stats(), "pensees": {}, "dernieres": [],
		"degats": 0.0, "expo": "", "expo_fin": -1, "argent": 0.0, "ouvert": true}


## Bâtiment du catalogue (ou modèle de l'atelier) de fonction « Musée ».
func _is_musee_bid(bid: int) -> bool:
	if buildings == null or not buildings.buildings.has(bid):
		return false
	return BuildingCatalog.base_of(String(buildings.buildings[bid].t)) == "musee"


func _sync() -> void:
	_dirty = false
	var seen := {}
	if mob != null and mob.pe != null:
		# Les modèles de l'atelier posés avec la fonction Musée sont des musées.
		for plan in mob.linked:
			if _is_musee_bid(int(mob.linked[plan])) and mob.usage_of(String(plan)) != "musee":
				mob.usages[plan] = "musee"
				mob._stats_cache.erase(plan)
		for id in mob.pe.plans:
			if mob.usage_of(String(id)) == "musee":
				seen[String(id)] = true
	if buildings != null:
		var linked_bids := {}
		if mob != null:
			for plan in mob.linked:
				linked_bids[int(mob.linked[plan])] = true
		for bid in buildings.buildings:
			if not linked_bids.has(int(bid)) and _is_musee_bid(int(bid)):
				seen["bat_%d" % int(bid)] = true
	for k in seen:
		if not musees.has(k):
			musees[k] = _new_state(String(k))
			_cache.erase(k)
	for k in musees.keys():
		if not seen.has(k):
			musees.erase(k)
			_cache.erase(k)


func list() -> Array:
	if _dirty:
		_sync()
	var out := musees.keys()
	out.sort()
	return out


func is_plan(key: String) -> bool:
	return not key.begins_with("bat_")


func bid_of(key: String) -> int:
	if key.begins_with("bat_"):
		return int(key.substr(4))
	if mob != null and mob.linked.has(key):
		return int(mob.linked[key])
	return mob.bid_of(key) if mob != null else -1


func nom(key: String) -> String:
	return String(musees[key].nom) if musees.has(key) else ""


func renommer(key: String, n: String) -> void:
	if musees.has(key) and n.strip_edges() != "":
		musees[key].nom = n.strip_edges()
		changed.emit()


func set_prix(key: String, prix: float) -> void:
	if musees.has(key):
		musees[key].prix = clampf(prix, 0.0, 60.0)
		_cache.erase(key)
		changed.emit()


func set_gratuit_dimanche(key: String, on: bool) -> void:
	if musees.has(key):
		musees[key].gratuit_dimanche = on
		changed.emit()


## Position du musée (centre au sol).
func centre(key: String) -> Vector3:
	if key.begins_with("bat_"):
		var bid := int(key.substr(4))
		if buildings != null and buildings.buildings.has(bid):
			var b: Dictionary = buildings.buildings[bid]
			return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)
		return Vector3.ZERO
	if mob == null or mob.pe == null or not mob.pe._bbox.has(key):
		return Vector3.ZERO
	return BuildingSystem.rect_center(mob.pe._bbox[key]) + Vector3(0, float(mob.pe.plans[key].y0), 0)


func en_chantier(key: String) -> bool:
	var bid := bid_of(key)
	return buildings != null and buildings.buildings.has(bid) and buildings.en_chantier(bid)


# --- Analyse d'un musée --------------------------------------------------------------------------

## Tout ce qui fait la qualité du musée. Mis en cache jusqu'au prochain changement.
func analyse(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var a := {"oeuvres": 0, "valeur": 0, "prestige": 0.0, "brut": 0.0, "themes": {}, "salles": [], "area": 0, "capacite": 0,
		"lumiere": 1.0, "confort": 0.0, "services": {}, "fragiles": 0, "exposes": 0, "stars": [], "manques": [], "conseils": [],
		"billetterie": false, "note": 0.0, "detail": {}, "mal_placees": 0, "melange": false, "moderne": false, "dinos": false, "momie": false}
	if key.begins_with("bat_"):
		a.oeuvres = 60
		a.valeur = CATALOGUE_VALEUR
		a.prestige = CATALOGUE_PRESTIGE
		a.brut = CATALOGUE_PRESTIGE
		a.themes = {"art": 20, "histoire": 20, "antiquite": 20}
		a.area = 1200
		a.capacite = int(1200 / M2_VISITEUR)
		a.confort = 0.6
		a.services = {"billetterie": 2, "vestiaire": 1, "toilettes": 1, "boutique": 1, "cafe": 1}
		a.billetterie = true
		a.detail = {"collections": 3.0, "confort": 0.36, "services": 0.85, "variete": 0.2, "expo": 0.0, "degats": 0.0}
		a.note = _note(key, a)
		_cache[key] = a
		return a
	if mob == null or mob.pe == null or not mob.pe.plans.has(key):
		return a
	var id := key
	var guesses := mob.guess_functions(id)
	var area := 0
	var conf_pts := 0.0
	var themes := {}
	for e in mob.pe.levels_of(id):
		for r in mob.rooms(id, int(e)):
			var fn := mob.function_of(id, r, guesses)
			var cells := {}
			for c in r.cells:
				cells[c] = true
			var salle := {"fn": fn, "e": int(e), "area": int(r.area), "oeuvres": 0, "prestige": 0.0, "lumiere": 0.0, "protege": 0, "fragiles": 0, "key": r.key}
			area += int(r.area)
			var theme := String(MuseeObjets.SALLES.get(fn, {}).get("theme", "-"))
			var objs := []
			for k in mob.items.get(id, {}):
				var kk: Vector4i = k
				if kk.y != int(e) or not cells.has(Vector2i(kk.x, kk.z)):
					continue
				var ent := Meubles.get_entry(String(mob.items[id][k].m))
				if ent.is_empty():
					continue
				objs.append(ent)
			for ent in objs:
				var t := String(ent.get("theme", ""))
				salle.lumiere = float(salle.lumiere) + float(ent.get("lumiere", 0))
				conf_pts += float(ent.get("confort", 0))
				if bool(ent.get("protege", false)):
					salle.protege = int(salle.protege) + 1
				var sv := String(ent.get("service", ""))
				if sv != "":
					a.services[sv] = int(a.services.get(sv, 0)) + 1
				if (ent.tags as Array).has("wc"):
					a.services["toilettes"] = int(a.services.get("toilettes", 0)) + 1
				if String(ent.type) in ["comptoir_bar", "table_bistrot"] and fn == "cafe_musee":
					a.services["cafe"] = int(a.services.get("cafe", 0)) + 1
				if t == "":
					continue
				salle.oeuvres = int(salle.oeuvres) + 1
				themes[t] = int(themes.get(t, 0)) + 1
				a.valeur = int(a.valeur) + int(ent.get("valeur", 0))
				if bool(ent.get("fragile", false)) and not bool(ent.get("protege", false)):
					salle.fragiles = int(salle.fragiles) + 1
				if (ent.tags as Array).has("star"):
					(a.stars as Array).append(String(ent.name))
				if String(ent.k).begins_with("dino") or String(ent.k) == "mammouth":
					a.dinos = true
				if String(ent.k) in ["momie", "sarcophage"]:
					a.momie = true
				if String(ent.type) in ["toile_abstraite", "sculpture_moderne", "mobile"]:
					a.moderne = true
			# Prestige de la salle : œuvres × cohérence × éclairage × place.
			var n := int(salle.oeuvres)
			if n > 0:
				var besoin := maxf(1.0, float(r.area) / 12.0)
				var lf := clampf(float(salle.lumiere) / besoin, 0.0, 1.5)
				var eclair := 0.55 + 0.45 * minf(lf, 1.0) + 0.08 * maxf(lf - 1.0, 0.0)
				var place := 1.0 if float(r.area) / float(n) >= 3.0 else (0.85 if float(r.area) / float(n) >= 1.8 else 0.7)
				var p := 0.0
				var mal := 0
				for ent2 in objs:
					var t2 := String(ent2.get("theme", ""))
					if t2 == "":
						continue
					var coh := 1.0
					if theme == t2:
						coh = 1.2
					elif fn == "salle_expo" or fn == "hall_musee":
						coh = 1.0
					elif theme != "-" and theme != "":
						coh = 0.85
						mal += 1
					else:
						coh = 0.8
						mal += 1
					p += float(ent2.get("prestige", 0)) * coh
					a.brut = float(a.brut) + float(ent2.get("prestige", 0))
				salle.prestige = p * eclair * place
				salle["eclairage"] = eclair
				a.prestige = float(a.prestige) + float(salle.prestige)
				a.mal_placees = int(a.mal_placees) + mal
				a.oeuvres = int(a.oeuvres) + n
				a.fragiles = int(a.fragiles) + maxi(0, int(salle.fragiles) - int(salle.protege) * 3)
			(a.salles as Array).append(salle)
	a.themes = themes
	a.area = area
	a.capacite = int(float(area) / M2_VISITEUR)
	a.billetterie = int(a.services.get("billetterie", 0)) > 0
	a.confort = clampf(conf_pts / maxf(1.0, float(area) / 25.0), 0.0, 1.0)
	a.melange = int(a.mal_placees) > maxi(2, int(a.oeuvres) / 4)
	var lum_tot := 0.0
	var lum_besoin := 0.0
	for s in a.salles:
		if int(s.oeuvres) > 0:
			lum_tot += float(s.lumiere)
			lum_besoin += maxf(1.0, float(s.area) / 12.0)
	a.lumiere = clampf(lum_tot / lum_besoin, 0.0, 1.5) if lum_besoin > 0.0 else 1.0
	a.note = _note(key, a)
	_conseils(a)
	_cache[key] = a
	return a


## Note en étoiles (0 à 5) et son détail.
func _note(key: String, a: Dictionary) -> float:
	if not bool(a.billetterie) or int(a.oeuvres) == 0:
		a.detail = {"collections": 0.0, "confort": 0.0, "services": 0.0, "variete": 0.0, "expo": 0.0, "degats": 0.0}
		return 0.0
	var st: Dictionary = musees.get(key, {})
	var p := float(a.prestige) + expo_bonus(key)
	var coll := clampf(log(1.0 + p / 18.0) * 1.35, 0.0, 3.4)
	var conf := float(a.confort) * 0.6
	var sv: Dictionary = a.services
	var serv := 0.0
	serv += 0.15 if sv.has("vestiaire") else 0.0
	serv += 0.25 if sv.has("toilettes") else -0.3
	serv += 0.15 if sv.has("boutique") else 0.0
	serv += 0.2 if sv.has("cafe") else 0.0
	serv += 0.15 if sv.has("audioguide") else 0.0
	var variete := 0.2 if (a.themes as Dictionary).size() >= 3 else (0.1 if (a.themes as Dictionary).size() == 2 else 0.0)
	var expo := 0.3 if String(st.get("expo", "")) != "" else 0.0
	var deg := -minf(1.0, float(st.get("degats", 0.0)) * 0.25)
	a.detail = {"collections": coll, "confort": conf, "services": serv, "variete": variete, "expo": expo, "degats": deg}
	return clampf(coll + conf + serv + variete + expo + deg, 0.0, 5.0)


func _conseils(a: Dictionary) -> void:
	var c: Array = a.conseils
	if not bool(a.billetterie):
		c.append("Pose une billetterie (Accueil et services) : sans elle, le musée reste fermé.")
	if int(a.oeuvres) == 0:
		c.append("Expose des œuvres : peinture, sculpture, antiquités, dinosaures…")
	if float(a.lumiere) < 0.7 and int(a.oeuvres) > 0:
		c.append("Les salles sont trop sombres : ajoute des rails de spots, lustres ou projecteurs.")
	if int(a.fragiles) > 0:
		c.append("%d œuvre%s fragile%s sans protection : vitrines ou cordons." % [int(a.fragiles), "s" if int(a.fragiles) > 1 else "", "s" if int(a.fragiles) > 1 else ""])
	if bool(a.melange):
		c.append("Des œuvres sont hors de leur salle : donne une fonction à chaque salle (Salles) et range-les par thème.")
	if float(a.confort) < 0.4 and int(a.oeuvres) > 0:
		c.append("Visite fatigante : bancs, cartels, panneaux et plans rendent la visite plus agréable.")
	var sv: Dictionary = a.services
	if not sv.has("toilettes"):
		c.append("Pas de toilettes : les visiteurs ne restent pas longtemps.")
	if not sv.has("boutique"):
		c.append("Une boutique rapporte : caisse et présentoirs de souvenirs.")
	if not sv.has("cafe"):
		c.append("Un café du musée retient les visiteurs (et leur argent).")
	if (a.themes as Dictionary).size() < 2 and int(a.oeuvres) > 0:
		c.append("Une seule collection : d'autres thèmes attireront d'autres visiteurs.")


# --- Temps ----------------------------------------------------------------------------------------

func _now(t: float) -> Dictionary:
	var off := ambiance.utc_offset() if ambiance != null else 0.0
	var local := t + off * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	return {"h": fposmod(local, 86400.0) / 3600.0, "wd": int(dt.weekday), "month": int(dt.month), "day": int(floorf(local / 86400.0)), "mday": int(dt.day)}


## Heures d'ouverture [ouverture, fermeture] : 10 h – 18 h, 19 h en été.
static func horaires(month: int) -> Vector2:
	return Vector2(10.0, 19.0) if month in [7, 8] else Vector2(10.0, 18.0)


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
	if _dirty:
		_sync()
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
	for k in musees:
		_heure(String(k), now)
	changed.emit()


func est_ouvert(key: String, now: Dictionary) -> bool:
	if not musees.has(key) or not bool(musees[key].ouvert) or en_chantier(key):
		return false
	var a := analyse(key)
	if not bool(a.billetterie) or int(a.oeuvres) == 0:
		return false
	if int(now.wd) == 1:
		return false
	var hz := horaires(int(now.month))
	return float(now.h) >= hz.x and float(now.h) < hz.y


func _gratuit(key: String, now: Dictionary) -> bool:
	var st: Dictionary = musees[key]
	return float(st.prix) <= 0.0 or (bool(st.gratuit_dimanche) and int(now.wd) == 0 and int(now.mday) <= 7)


func _pluie() -> float:
	if ambiance == null or ambiance.weather == null:
		return 0.0
	return clampf(float(ambiance.weather.precip), 0.0, 1.0)


## Visiteurs attendus sur la journée : [habitants, touristes].
func attendus(key: String, now: Dictionary) -> Array:
	var a := analyse(key)
	var st: Dictionary = musees[key]
	var note := float(a.note)
	var hab := 0.0
	if population != null:
		hab = float(population.persons.size()) * HABITANTS_JOUR * pow(maxf(note, 0.0) / 3.0, 1.5)
	var tour := (float(a.prestige) + expo_bonus(key)) * TOURISTES_PRESTIGE * (0.4 + note / 5.0)
	var f := float(MOIS_SAISON.get(int(now.month), 1.0))
	if int(now.wd) in [0, 6]:
		f *= 1.45
	elif int(now.wd) == 3:
		f *= 1.15
	f *= 1.0 + 0.35 * _pluie()
	var prix := float(st.prix)
	var px := 1.6 if _gratuit(key, now) else clampf(1.3 - prix / 40.0, 0.35, 1.3)
	hab *= f * px
	tour *= f * clampf(1.15 - prix / 80.0, 0.5, 1.15)
	return [hab, tour]


func capacite_jour(key: String, month: int) -> float:
	var hz := horaires(month)
	return float(analyse(key).capacite) * (hz.y - hz.x) / DUREE_VISITE


## Visiteurs présents (pour les petits personnages) : ceux arrivés depuis 1 h 30.
func presents(key: String) -> int:
	if not musees.has(key):
		return 0
	return int(musees[key].get("presents", 0))


func _heure(key: String, now: Dictionary) -> void:
	var st: Dictionary = musees[key]
	var h := int(floorf(float(now.h)))
	if not est_ouvert(key, now):
		st.presents = 0
		return
	var att := attendus(key, now)
	var part := float(ARRIVEES.get(h, 0.0))
	if h >= 18:
		part = 0.03
	var hab := float(att[0]) * part
	var tour := float(att[1]) * part
	var cap := capacite_jour(key, int(now.month)) * part * 1.2
	var total := hab + tour
	if total > cap and total > 0.0:
		var refus := total - cap
		st.jour.refus = int(st.jour.refus) + roundi(refus)
		hab *= cap / total
		tour *= cap / total
		if refus > 5.0:
			_penser(key, "foule")
	var nh := _arrondi(hab)
	var nt := _arrondi(tour)
	var n := nh + nt
	st.presents = roundi(float(n) * DUREE_VISITE)
	if n <= 0:
		return
	st.jour.visiteurs = int(st.jour.visiteurs) + n
	st.jour.habitants = int(st.jour.habitants) + nh
	st.jour.touristes = int(st.jour.touristes) + nt
	_sorties(nh)
	var a := analyse(key)
	var gratuit := _gratuit(key, now)
	if not gratuit:
		_encaisser(key, "billets", float(n) * float(st.prix) * PART_PAYANTE)
	if nt > 0:
		_encaisser(key, "taxe", float(nt) * TAXE_SEJOUR)
	var sv: Dictionary = a.services
	if sv.has("boutique"):
		_encaisser(key, "boutique", float(n) * BOUTIQUE_PANIER * (0.5 + float(a.note) / 10.0) * minf(1.0, 0.4 + 0.2 * int(sv.boutique)))
	if sv.has("cafe"):
		_encaisser(key, "cafe", float(n) * CAFE_PANIER * 0.35)
	if sv.has("audioguide"):
		_encaisser(key, "audioguides", float(n) * AUDIOGUIDE_PRIX * 0.2)
	# Dégâts : objets fragiles sans protection, moins de risque avec des gardiens.
	var fr := int(a.fragiles)
	if fr > 0 and rng.randf() < float(n) * float(fr) * 0.00025:
		st.degats = float(st.degats) + 1.0
		st.jour.degats = int(st.jour.degats) + 1
		var cout := 1500.0 + rng.randf() * 6000.0
		_payer(key, "Musée : restaurations", cout)
		_penser(key, "degats")
		_warn(key + "deg", "%s : un visiteur a touché une œuvre fragile. Restauration : %s. Protège-les (vitrines, cordons)." % [nom(key), BuildingSystem.format_money(int(cout))])
	_pensees_visite(key, a, now, gratuit, n)


func _arrondi(x: float) -> int:
	var b := int(floorf(x))
	return b + (1 if rng.randf() < x - b else 0)


func _sorties(n: int) -> void:
	if population == null or n <= 0 or population.persons.is_empty():
		return
	var ids := population.persons.keys()
	for i in mini(n, 12):
		sorties[int(ids[rng.randi() % ids.size()])] = last_day


func _pensees_visite(key: String, a: Dictionary, now: Dictionary, gratuit: bool, n: int) -> void:
	var st: Dictionary = musees[key]
	var w := maxi(1, n / 10)
	if gratuit:
		_penser(key, "gratuit", [], w)
	elif float(st.prix) > 18.0:
		_penser(key, "cher", [roundi(float(st.prix))], w)
	elif float(st.prix) <= 10.0:
		_penser(key, "bon_prix", [], w)
	if float(a.note) >= 4.0:
		_penser(key, "super", [], w)
	if not (a.stars as Array).is_empty():
		_penser(key, "star", [String((a.stars as Array)[0])], w)
	if bool(a.dinos):
		_penser(key, "dinos", [], w)
	if bool(a.momie):
		_penser(key, "momie", [], w)
	if bool(a.moderne) and rng.randf() < 0.3:
		_penser(key, "moderne")
	if float(a.lumiere) < 0.6:
		_penser(key, "sombre", [], w)
	if float(a.confort) < 0.25:
		_penser(key, "bancs", [], w)
	if int(a.oeuvres) < 6:
		_penser(key, "rien", [], w)
	if bool(a.melange):
		_penser(key, "melange", [], w)
	var sv: Dictionary = a.services
	_penser(key, "boutique" if sv.has("boutique") else "pas_boutique")
	_penser(key, "cafe" if sv.has("cafe") else "pas_cafe")
	if not sv.has("toilettes"):
		_penser(key, "toilettes", [], w)
	if sv.has("audioguide") and rng.randf() < 0.3:
		_penser(key, "audioguide")
	if sv.has("vestiaire") and rng.randf() < 0.15:
		_penser(key, "vestiaire")
	if String(st.expo) != "" and EXPOS.has(String(st.expo)):
		_penser(key, "expo", [String(EXPOS[String(st.expo)].name)], w)
	if _pluie() > 0.4:
		_penser(key, "pluie")


func _penser(key: String, cle: String, args: Array = [], poids := 1) -> void:
	var st: Dictionary = musees[key]
	var pens: Dictionary = st.pensees
	pens[cle] = int(pens.get(cle, 0)) + poids
	var txt := String(PENSEES.get(cle, cle))
	if not args.is_empty():
		txt = txt % args
	var d: Array = st.dernieres
	if d.is_empty() or String(d[0]) != txt:
		d.push_front(txt)
		if d.size() > 8:
			d.resize(8)


# --- Expositions temporaires ---------------------------------------------------------------------

func expo_bonus(key: String) -> float:
	if not musees.has(key):
		return 0.0
	var ex := String(musees[key].get("expo", ""))
	if ex == "" or not EXPOS.has(ex):
		return 0.0
	var b := float(EXPOS[ex].bonus)
	# Sans salle d'exposition temporaire, l'exposition s'installe à l'étroit.
	if is_plan(key):
		var has_room := false
		for s in analyse_salles(key):
			if String(s.fn) == "salle_expo":
				has_room = true
				break
		if not has_room:
			b *= 0.5
	return b


func analyse_salles(key: String) -> Array:
	if _cache.has(key):
		return _cache[key].salles
	if mob == null or mob.pe == null or not mob.pe.plans.has(key):
		return []
	var out := []
	var g := mob.guess_functions(key)
	for e in mob.pe.levels_of(key):
		for r in mob.rooms(key, int(e)):
			out.append({"fn": mob.function_of(key, r, g)})
	return out


## Lance une exposition : rend "" ou la raison du refus.
func lancer_expo(key: String, ex: String) -> String:
	if not musees.has(key) or not EXPOS.has(ex):
		return "exposition inconnue"
	var st: Dictionary = musees[key]
	if String(st.expo) != "":
		return "une exposition est déjà en cours"
	var prix := int(EXPOS[ex].prix)
	if buildings != null and not buildings.unlimited_money and buildings.money < prix:
		return "il faut %s en caisse" % BuildingSystem.format_money(prix)
	_payer(key, "Musée : expositions", float(prix))
	st.expo = ex
	var day := last_day if last_day >= 0 else int(_now(ambiance.unix_time if ambiance != null else 0.0).day)
	st.expo_fin = day + int(EXPOS[ex].jours)
	_cache.erase(key)
	message.emit("%s : l'exposition « %s » ouvre ses portes pour %d jours." % [nom(key), String(EXPOS[ex].name), int(EXPOS[ex].jours)])
	changed.emit()
	return ""


func jours_expo(key: String) -> int:
	if not musees.has(key) or String(musees[key].expo) == "":
		return 0
	return maxi(0, int(musees[key].expo_fin) - last_day)


# --- Jour -----------------------------------------------------------------------------------------

func new_day(now: Dictionary = {}) -> void:
	for k in musees:
		var key := String(k)
		var st: Dictionary = musees[key]
		_charges(key)
		for f in st.jour:
			if st.jour[f] is int:
				st.total[f] = int(st.total.get(f, 0)) + int(st.jour[f])
			else:
				st.total[f] = float(st.total.get(f, 0.0)) + float(st.jour[f])
		st.hier = st.jour
		st.jour = _empty_stats()
		st.degats = maxf(0.0, float(st.degats) * 0.93 - 0.02)
		if String(st.expo) != "" and last_day >= int(st.expo_fin):
			message.emit("%s : l'exposition « %s » ferme. Les visiteurs en redemandent." % [nom(key), String(EXPOS.get(String(st.expo), {}).get("name", ""))])
			st.expo = ""
			st.expo_fin = -1
			_cache.erase(key)
		var pens: Dictionary = st.pensees
		for p in pens.keys():
			pens[p] = int(int(pens[p]) * 0.6)
			if int(pens[p]) <= 0:
				pens.erase(p)
		if not now.is_empty() and int(now.wd) == 1:
			_penser(key, "lundi")
		var a := analyse(key)
		st.note = float(a.note)
		if not bool(a.billetterie):
			_warn(key + "bil", "%s : pas de billetterie, le musée reste fermé (menu Musée, Maj+C → Accueil et services)." % nom(key), 86400.0 * 3.0)
	for pid in sorties.keys():
		if last_day - int(sorties[pid]) > 30:
			sorties.erase(pid)


## Salaires, assurance des œuvres, entretien du jour.
func _charges(key: String) -> void:
	var a := analyse(key)
	if en_chantier(key):
		return
	var emplois := 0
	if key.begins_with("bat_"):
		emplois = int(BuildingCatalog.get_type("musee").get("emplois", 12))
	elif mob != null:
		emplois = int(mob.stats(key).emplois)
	if emplois > 0:
		_payer(key, "Musée : salaires", float(emplois) * SALAIRE_MOYEN / 30.44)
	if int(a.valeur) > 0:
		_payer(key, "Musée : assurance des œuvres", float(a.valeur) * ASSURANCE_AN / 365.0)


func _warn(k: String, text: String, every := 3600.0 * 12.0) -> void:
	if clock - float(_warned.get(k, -INF)) < every:
		return
	_warned[k] = clock
	message.emit(text)


const POSTES := {"billets": "Musée : billets", "boutique": "Musée : boutique", "cafe": "Musée : café", "audioguides": "Musée : audioguides", "taxe": "Taxe de séjour"}


func _encaisser(key: String, quoi: String, montant: float) -> void:
	var st: Dictionary = musees[key]
	if st.jour.has(quoi):
		st.jour[quoi] = float(st.jour[quoi]) + montant
	_flux(key, String(POSTES.get(quoi, "Musée")), montant)


func _payer(key: String, poste: String, montant: float) -> void:
	if musees.has(key):
		musees[key].jour.depenses = float(musees[key].jour.depenses) + montant
	_flux(key, poste, -montant)


func _flux(key: String, poste: String, montant: float) -> void:
	if buildings == null or buildings.unlimited_money or absf(montant) < 0.01:
		return
	var prev := Pays.au_batiment(bid_of(key))
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		if montant > 0.0:
			bc.recette(poste, montant)
		else:
			bc.depense(poste, -montant)
	else:
		var st: Dictionary = musees.get(key, {})
		if not st.is_empty():
			st.argent = float(st.argent) + montant
			var whole := int(st.argent)
			if whole != 0:
				buildings.money += whole
				st.argent = float(st.argent) - whole
	Pays.retour(prev)


# --- Avis des habitants, résumé, conseils ----------------------------------------------------------

func avis_facteurs() -> Array:
	return [{"id": "musee", "theme": "loisirs", "f": satisfaction_of}]


func satisfaction_of(p: Dictionary) -> Array:
	if musees.is_empty() or population == null:
		return [0.0, []]
	var pid := int(p.get("id", -1))
	if pid >= 0 and sorties.has(pid) and last_day - int(sorties[pid]) <= 30:
		return [2.0, ["+ Une belle visite au musée"]]
	for k in musees:
		if float(musees[k].note) >= 3.0:
			return [1.0, ["+ Un beau musée en ville"]]
	return [0.0, []]


func summary() -> String:
	if musees.is_empty():
		return ""
	var v := 0
	for k in musees:
		v += int(musees[k].hier.visiteurs)
	return "Musées : %d visiteurs hier" % v


func recettes(st: Dictionary) -> float:
	return float(st.billets) + float(st.boutique) + float(st.cafe) + float(st.audioguides)


# --- Sauvegarde -----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var m := {}
	for k in musees:
		var st: Dictionary = musees[k]
		m[k] = {"nom": st.nom, "prix": st.prix, "gratuit_dimanche": st.gratuit_dimanche, "total": st.total, "hier": st.hier,
			"degats": st.degats, "expo": st.expo, "expo_fin": st.expo_fin, "pensees": st.pensees, "dernieres": st.dernieres, "ouvert": st.ouvert}
	var so := {}
	for pid in sorties:
		so[str(pid)] = sorties[pid]
	return {"musees": m, "last_day": last_day, "sorties": so}


func from_dict(d: Dictionary) -> void:
	clear()
	var m: Dictionary = d.get("musees", {})
	for k in m:
		var st := _new_state(String(k))
		var src: Dictionary = m[k]
		for f in src:
			st[f] = src[f]
		# JSON : les entiers reviennent en flottants.
		for part in ["total", "hier"]:
			var s0 := _empty_stats()
			var got: Dictionary = st[part]
			for f2 in s0:
				s0[f2] = int(got.get(f2, 0)) if s0[f2] is int else float(got.get(f2, 0.0))
			st[part] = s0
		st.expo_fin = int(st.expo_fin)
		musees[String(k)] = st
	last_day = int(d.get("last_day", -1))
	var so: Dictionary = d.get("sorties", {})
	for pid in so:
		sorties[int(pid)] = int(so[pid])
	_dirty = true
	changed.emit()
