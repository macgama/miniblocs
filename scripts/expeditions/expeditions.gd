class_name Expeditions
extends Node
## Expéditions (menu Loisirs → Expéditions, Maj+F4) : depuis une « Société des
## explorateurs », la ville envoie une équipe au loin. Elle en rapporte des objets
## rares pour ses musées, des animaux pour ses zoos et des spécialistes qui
## s'installent dans une ville et l'améliorent.
##
## - Préparer : une destination (17, datées), un chef (il gagne de l'expérience
##   d'une expédition à l'autre), des membres (guide, médecin, naturaliste,
##   archéologue, interprète, porteurs…) et des provisions. Chacun apporte des
##   qualités (ExpeditionsDonnees.QUALITES). Le prix se paie au départ, par la
##   ville de la Société.
## - Le voyage dépend de l'époque : en voilier en 1800, en avion aujourd'hui.
## - En exploration, l'équipe s'use (santé, moral ; le climat sans le bon
##   matériel use plus vite), fait des trouvailles chaque jour selon ses
##   qualités, et rencontre des événements à choix : chaque choix met une
##   qualité à l'épreuve (chance de réussite affichée). Sans réponse du joueur
##   en 2 jours, le chef décide (ou tout de suite si « le chef décide » est coché).
## - Santé trop basse : un membre rentre au pays ; à zéro, rapatriement d'urgence.
##   Moral à zéro : l'équipe abandonne et rentre.
## - Au retour : la renommée de la ville monte (gazette, tourisme), le butin
##   arrive dans la réserve. Objets : donnés à un musée (prestige), exposés au
##   cabinet de curiosités de la Société (tourisme), vendus aux enchères, ou
##   rendus au pays d'origine (renommée). Animaux : placés dans un enclos du zoo,
##   ou confiés à un autre zoo. Spécialistes : affectés à une ville (3 au plus
##   par ville) ; leurs effets sont lus par les autres systèmes (facteur()).
##
## Section de sauvegarde « expeditions ».

signal message(text: String)
signal actualite(text: String, pos: Vector3)
signal changed

static var instance: Expeditions

## Délai (jours) laissé au joueur pour répondre à un événement.
const DELAI_CHOIX := 2
## Chance d'un événement par jour d'exploration.
const CHANCE_EVENEMENT := 0.3
## Butin maximal d'une expédition.
const MAX_OBJETS := 4
const MAX_ESPECES := 3
const MAX_SPECIALISTES := 2
## Niveau maximal d'un chef (+1 à toutes les qualités par niveau).
const NIVEAU_MAX := 5
const POSTE := "Expéditions"

var buildings: BuildingSystem
var ambiance: DayNight

## id → expédition (voir _nouvelle).
var expeditions: Dictionary = {}
var next_id := 1
## Chefs d'expédition : [{nom, xp, faites, reussies, libre}].
var chefs: Array = []
## Objets trouvés : id → {"lieu": "reserve"|"musee"|"cabinet"|"vendu"|"rendu", "musee": clé, "soc": bid, "jour": j}.
var objets: Dictionary = {}
## Animaux qui attendent un enclos : [{"esp", "f" (bool), "dest"}].
var animaux: Array = []
## Spécialistes : id → {"ville": -1 (réserve), 0 (partout) ou clé de ville, "jour": j}.
var specialistes: Dictionary = {}
## Renommée totale de la ville (somme des expéditions).
var renommee := 0.0
## Récits des expéditions terminées, le plus récent d'abord : [{jour, texte, issue, dest}].
var recits: Array = []
var last_day := -1
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func _enter_tree() -> void:
	instance = self
	add_to_group("sante_sources")
	add_to_group("avis_sources")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(b: BuildingSystem, a: DayNight) -> void:
	buildings = b
	ambiance = a


func clear() -> void:
	expeditions.clear()
	next_id = 1
	chefs.clear()
	objets.clear()
	animaux.clear()
	specialistes.clear()
	renommee = 0.0
	recits.clear()
	last_day = -1


# --- Temps -------------------------------------------------------------------------------------

func jour() -> int:
	if ambiance == null:
		return maxi(last_day, 0)
	return int(floor(ambiance.unix_time / 86400.0))


func annee() -> int:
	return Epoques.annee()


func _process(_delta: float) -> void:
	if ambiance == null:
		return
	var j := jour()
	if last_day < 0:
		last_day = j
		return
	if j > last_day:
		# Au plus 60 jours d'un coup (avance rapide, chargement) : pas de gel.
		var n := mini(j - last_day, 60)
		for i in n:
			new_day(last_day + 1)
		last_day = j


## Avance de n jours (tests, avance rapide).
func avancer(n: int) -> void:
	for i in n:
		new_day((last_day if last_day >= 0 else jour()) + 1)


func new_day(j: int) -> void:
	last_day = j
	for id in expeditions.keys():
		var x: Dictionary = expeditions[id]
		if String(x.etat) != "finie":
			_jour(x, j)


# --- Sociétés des explorateurs -------------------------------------------------------------------

func societes() -> Array:
	var out := []
	if buildings == null:
		return out
	for bid in buildings.buildings:
		if ExpeditionsDonnees.est_societe(String(buildings.buildings[bid].t)) and not buildings.en_chantier(int(bid)):
			out.append(int(bid))
	out.sort()
	return out


## Expédition en cours d'une Société (-1 : aucune).
func expedition_de(soc: int) -> int:
	for id in expeditions:
		if int(expeditions[id].soc) == soc and String(expeditions[id].etat) != "finie":
			return int(id)
	return -1


func societe_libre() -> int:
	for bid in societes():
		if expedition_de(int(bid)) < 0:
			return int(bid)
	return -1


func pos_of(bid: int) -> Vector3:
	if buildings == null or not buildings.buildings.has(bid):
		return Vector3.INF
	return BuildingSystem.rect_center(buildings._rect_of(buildings.buildings[bid]))


func en_cours() -> Array:
	var out := []
	for id in expeditions:
		if String(expeditions[id].etat) != "finie":
			out.append(int(id))
	out.sort()
	return out


# --- Chefs ---------------------------------------------------------------------------------------

func _assurer_chefs() -> void:
	while chefs.size() < 3:
		var n := String(ExpeditionsDonnees.CHEFS[chefs.size() % ExpeditionsDonnees.CHEFS.size()])
		chefs.append({"nom": n, "xp": 0, "faites": 0, "reussies": 0, "libre": true})


func chefs_libres() -> Array:
	_assurer_chefs()
	var out := []
	for i in chefs.size():
		if bool(chefs[i].libre):
			out.append(i)
	return out


func niveau_chef(i: int) -> int:
	if i < 0 or i >= chefs.size():
		return 1
	return clampi(1 + int(chefs[i].reussies) / 2, 1, NIVEAU_MAX)


func nom_chef(i: int) -> String:
	return String(chefs[i].nom) if i >= 0 and i < chefs.size() else "?"


## Embauche un nouveau chef (quand les autres sont partis).
func recruter_chef() -> int:
	_assurer_chefs()
	var n := String(ExpeditionsDonnees.CHEFS[chefs.size() % ExpeditionsDonnees.CHEFS.size()])
	chefs.append({"nom": n, "xp": 0, "faites": 0, "reussies": 0, "libre": true})
	changed.emit()
	return chefs.size() - 1


# --- Préparation : qualités, prix, durée -----------------------------------------------------------

func destinations_ouvertes() -> Array:
	var out := []
	var a := annee()
	for id in ExpeditionsDonnees.DESTINATIONS_ORDRE:
		if int(ExpeditionsDonnees.DESTINATIONS[id].annee) <= a:
			out.append(id)
	return out


func membre_disponible(m: String) -> bool:
	return int(ExpeditionsDonnees.membre(m).get("annee", 0)) <= annee()


## Qualités d'une équipe : {qualité: points}. plan = {dest, chef, membres: {id: n}, provisions: [ids]}.
func qualites(plan: Dictionary) -> Dictionary:
	var q := {}
	for k in ExpeditionsDonnees.QUALITES:
		q[k] = 0
	var membres: Dictionary = plan.get("membres", {})
	for m in membres:
		var d := ExpeditionsDonnees.membre(String(m))
		for k in (d.get("q", {}) as Dictionary):
			q[k] = int(q[k]) + int(d.q[k]) * int(membres[m])
	for p in plan.get("provisions", []):
		var d2: Dictionary = ExpeditionsDonnees.PROVISIONS.get(String(p), {})
		for k in (d2.get("q", {}) as Dictionary):
			q[k] = int(q[k]) + int(d2.q[k])
	var bonus := niveau_chef(int(plan.get("chef", -1))) + roundi(facteur("expeditions"))
	for k in q:
		q[k] = int(q[k]) + bonus
	return q


func taille_equipe(plan: Dictionary) -> int:
	var n := 1
	var membres: Dictionary = plan.get("membres", {})
	for m in membres:
		n += int(membres[m])
	return n


func a_membre(plan: Dictionary, m: String) -> bool:
	return int((plan.get("membres", {}) as Dictionary).get(m, 0)) > 0


## {aller, explo, retour, total} en jours.
func durees(plan: Dictionary) -> Dictionary:
	var d := ExpeditionsDonnees.destination(String(plan.get("dest", "")))
	if d.is_empty():
		return {"aller": 0, "explo": 0, "retour": 0, "total": 0}
	var tr := ExpeditionsDonnees.transport(annee())
	var f := float(tr[1])
	if a_membre(plan, "pilote") and annee() >= 1920:
		f *= float(ExpeditionsDonnees.MEMBRES.pilote.trajet)
	var aller := maxi(2, roundi(float(d.trajet) * f))
	return {"aller": aller, "explo": int(d.jours), "retour": aller, "total": aller * 2 + int(d.jours)}


## Prix de l'expédition : {total, base, salaires, voyage, provisions}.
func prix(plan: Dictionary) -> Dictionary:
	var d := ExpeditionsDonnees.destination(String(plan.get("dest", "")))
	if d.is_empty():
		return {"total": 0, "base": 0, "salaires": 0, "voyage": 0, "provisions": 0}
	var j := float(durees(plan).total)
	var sal := 0.0
	var membres: Dictionary = plan.get("membres", {})
	for m in membres:
		sal += float(ExpeditionsDonnees.membre(String(m)).get("salaire", 0.0)) * int(membres[m]) * j
	sal += 400.0 * j # le chef
	var voy := float(ExpeditionsDonnees.transport(annee())[2]) * float(taille_equipe(plan)) * j
	var prov := 0
	for p in plan.get("provisions", []):
		prov += int((ExpeditionsDonnees.PROVISIONS.get(String(p), {}) as Dictionary).get("prix", 0))
	var base := int(d.cout)
	var tot := base + roundi(sal) + roundi(voy) + prov
	return {"total": tot, "base": base, "salaires": roundi(sal), "voyage": roundi(voy), "provisions": prov}


## Ce qui manque ou ce qui inquiète (conseils avant le départ).
func avertissements(plan: Dictionary) -> Array:
	var out := []
	var d := ExpeditionsDonnees.destination(String(plan.get("dest", "")))
	if d.is_empty():
		return ["Choisis une destination."]
	var themes: Array = d.themes
	var prov: Array = plan.get("provisions", [])
	var mat := String(ExpeditionsDonnees.CLIMAT_MATERIEL.get(String(d.climat), ""))
	if mat != "" and not prov.has(mat):
		out.append("Sans %s, le %s use l'équipe deux fois plus vite." % [
			String(ExpeditionsDonnees.PROVISIONS[mat].nom).to_lower(), String(ExpeditionsDonnees.CLIMAT_NOMS.get(String(d.climat), ""))])
	if themes.has("objet") and not a_membre(plan, "archeologue"):
		out.append("Sans archéologue, aucune pièce de musée.")
	if themes.has("animal") and (not a_membre(plan, "naturaliste") or not prov.has("cages")):
		out.append("Pour ramener des animaux : un naturaliste et des caisses de transport.")
	if not a_membre(plan, "medecin") and int(d.diff) >= 3:
		out.append("Une destination difficile sans médecin : risqué.")
	if taille_equipe(plan) > ExpeditionsDonnees.EQUIPE_MAX:
		out.append("L'équipe dépasse %d personnes." % ExpeditionsDonnees.EQUIPE_MAX)
	return out


## Lance une expédition : rend "" ou la raison du refus.
func partir(soc: int, plan: Dictionary) -> String:
	var dest := String(plan.get("dest", ""))
	var d := ExpeditionsDonnees.destination(dest)
	if d.is_empty():
		return "destination inconnue"
	if not destinations_ouvertes().has(dest):
		return "destination pas encore accessible (%d)" % int(d.annee)
	if buildings == null or not buildings.buildings.has(soc) or not ExpeditionsDonnees.est_societe(String(buildings.buildings[soc].t)):
		return "il faut une Société des explorateurs"
	if buildings.en_chantier(soc):
		return "la Société des explorateurs est encore en chantier"
	if expedition_de(soc) >= 0:
		return "cette Société a déjà une expédition en cours"
	var chef := int(plan.get("chef", -1))
	_assurer_chefs()
	if chef < 0 or chef >= chefs.size() or not bool(chefs[chef].libre):
		return "choisis un chef libre"
	if taille_equipe(plan) > ExpeditionsDonnees.EQUIPE_MAX:
		return "équipe trop nombreuse (%d au plus)" % ExpeditionsDonnees.EQUIPE_MAX
	var membres: Dictionary = {}
	var src: Dictionary = plan.get("membres", {})
	for m in src:
		var md := ExpeditionsDonnees.membre(String(m))
		if md.is_empty() or int(src[m]) <= 0:
			continue
		if not membre_disponible(String(m)):
			return "%s : pas encore de ce métier en %d" % [String(md.nom), annee()]
		membres[String(m)] = mini(int(src[m]), int(md.max))
	var p := prix({"dest": dest, "chef": chef, "membres": membres, "provisions": plan.get("provisions", [])})
	if not buildings.unlimited_money:
		var prev := Pays.au_batiment(soc)
		var ok := buildings.money >= int(p.total)
		Pays.retour(prev)
		if not ok:
			return "il faut %s en caisse" % BuildingSystem.format_money(int(p.total))
	_flux(soc, POSTE, -float(p.total))
	var du := durees({"dest": dest, "chef": chef, "membres": membres})
	var j := jour() if last_day < 0 else maxi(jour(), last_day)
	if last_day < 0:
		last_day = j
	var x := {"id": next_id, "dest": dest, "soc": soc, "chef": chef, "membres": membres,
		"provisions": (plan.get("provisions", []) as Array).duplicate(), "etat": "aller", "depart": j,
		"fin_etape": j + int(du.aller), "aller": int(du.aller), "explo": int(du.explo), "sante": 100.0, "moral": 100.0,
		"butin": {"objets": [], "animaux": [], "specialistes": []}, "evenement": {}, "vus": [], "auto": bool(plan.get("auto", false)),
		"r": 0.0, "log": [], "cout": int(p.total), "issue": "", "perdus": 0, "annee": annee()}
	expeditions[next_id] = x
	next_id += 1
	chefs[chef].libre = false
	var tr := ExpeditionsDonnees.transport(annee())
	_noter(x, "Départ %s pour %s : %d jours de voyage." % [String(tr[0]), String(d.nom), int(du.aller)])
	message.emit("%s part %s pour %s (%s)." % [nom_chef(chef), String(tr[0]), String(d.nom), BuildingSystem.format_money(int(p.total))])
	actualite.emit("La Société des explorateurs lance une expédition vers %s, menée par %s." % [String(d.nom), nom_chef(chef)], pos_of(soc))
	changed.emit()
	return ""


func set_auto(id: int, on: bool) -> void:
	if expeditions.has(id):
		expeditions[id].auto = on
		changed.emit()


## Fait rentrer l'expédition tout de suite (avec ce qu'elle a trouvé).
func rappeler(id: int) -> void:
	if not expeditions.has(id):
		return
	var x: Dictionary = expeditions[id]
	if String(x.etat) != "exploration" and String(x.etat) != "aller":
		return
	_rentrer(x, "rappel", "Rappelée par la Société : l'équipe rentre.")
	changed.emit()


# --- Une journée d'expédition -----------------------------------------------------------------

func _jour(x: Dictionary, j: int) -> void:
	var d := ExpeditionsDonnees.destination(String(x.dest))
	match String(x.etat):
		"aller":
			if j >= int(x.fin_etape):
				x.etat = "exploration"
				x.fin_etape = j + int(x.explo)
				_noter(x, "Arrivée : %s. L'exploration commence (%d jours)." % [String(d.nom), int(x.explo)])
				message.emit("L'expédition de %s est arrivée : %s." % [nom_chef(int(x.chef)), String(d.nom)])
				changed.emit()
		"exploration":
			_usure(x, d)
			if String(x.etat) != "exploration":
				return
			var ev: Dictionary = x.evenement
			if not ev.is_empty():
				if bool(x.auto) or j >= int(ev.limite):
					choisir(int(x.id), meilleur_choix(int(x.id)), true)
			else:
				_trouvailles(x, d)
				if rng.randf() < CHANCE_EVENEMENT:
					_tirer_evenement(x, d, j)
			if String(x.etat) == "exploration" and j >= int(x.fin_etape) and (x.evenement as Dictionary).is_empty():
				_rentrer(x, "", "Exploration terminée : l'équipe prend le chemin du retour.")
		"retour":
			if j >= int(x.fin_etape):
				_arrivee(x)


func _usure(x: Dictionary, d: Dictionary) -> void:
	var q := qualites(x)
	var mat := String(ExpeditionsDonnees.CLIMAT_MATERIEL.get(String(d.climat), ""))
	var sans_mat := mat != "" and not (x.provisions as Array).has(mat)
	var s := 0.6 * float(d.diff) + (2.5 if sans_mat else 0.0) - 0.18 * float(q.medecine)
	x.sante = clampf(float(x.sante) - maxf(0.2, s), 0.0, 100.0)
	var mf := 1.0
	if a_membre(x, "cuisinier"):
		mf *= float(ExpeditionsDonnees.MEMBRES.cuisinier.moral)
	if (x.provisions as Array).has("vivres"):
		mf *= float(ExpeditionsDonnees.PROVISIONS.vivres.moral)
	var m := (0.9 + 0.35 * float(d.diff) + (1.0 if sans_mat else 0.0)) / mf
	x.moral = clampf(float(x.moral) - m, 0.0, 100.0)
	if float(x.sante) <= 0.0:
		_rentrer(x, "rapatriee", "L'équipe est à bout de forces : rapatriement d'urgence.")
		return
	if float(x.moral) <= 0.0:
		_rentrer(x, "abandon", "Plus personne n'y croit : l'équipe abandonne et rentre.")
		return
	if float(x.sante) < 25.0 and _membres_restants(x) > 0:
		var who := _perdre_membre(x)
		x.sante = float(x.sante) + 15.0
		_noter(x, "%s, épuisé, est renvoyé au pays." % who)


func _membres_restants(x: Dictionary) -> int:
	var n := 0
	for m in x.membres:
		n += int(x.membres[m])
	return n


## Retire un membre au hasard (jamais le chef) ; rend son métier.
func _perdre_membre(x: Dictionary) -> String:
	var pool := []
	for m in x.membres:
		for i in int(x.membres[m]):
			pool.append(String(m))
	if pool.is_empty():
		return "Personne"
	var m: String = pool[rng.randi() % pool.size()]
	x.membres[m] = int(x.membres[m]) - 1
	if int(x.membres[m]) <= 0:
		(x.membres as Dictionary).erase(m)
	x.perdus = int(x.perdus) + 1
	var n := String(ExpeditionsDonnees.membre(m).nom).to_lower()
	if m in ["archeologue", "interprete", "alpiniste"]:
		return "L'" + n
	return "Le " + n


func _trouvailles(x: Dictionary, d: Dictionary) -> void:
	var q := qualites(x)
	var themes: Array = d.themes
	var sav := float(q.savoir)
	if themes.has("objet") and a_membre(x, "archeologue"):
		var p := 0.05 + 0.008 * sav + (0.05 if (x.provisions as Array).has("fouilles") else 0.0)
		if rng.randf() < p:
			_gagner(x, "objet")
	if themes.has("animal") and a_membre(x, "naturaliste") and (x.provisions as Array).has("cages"):
		if rng.randf() < 0.05 + 0.008 * sav:
			_gagner(x, "animal")
	if themes.has("savoir"):
		if rng.randf() < 0.02 + 0.004 * sav:
			_gagner(x, "specialiste")


## Tente d'ajouter une trouvaille au butin ; rend vrai si c'est fait.
func _gagner(x: Dictionary, quoi: String) -> bool:
	var d := ExpeditionsDonnees.destination(String(x.dest))
	var b: Dictionary = x.butin
	if quoi == "*":
		var opts := []
		for t in d.themes:
			var tt := "specialiste" if String(t) == "savoir" else String(t)
			if _peut_gagner(x, tt):
				opts.append(tt)
		if opts.is_empty():
			x.r = float(x.r) + 8.0
			return false
		quoi = String(opts[rng.randi() % opts.size()])
	if not _peut_gagner(x, quoi):
		if quoi == "animal" and (d.faune as Array).size() > 0:
			_noter(x, "Faute de naturaliste ou de caisses, l'animal reste dans son pays. On en fait le portrait.")
		x.r = float(x.r) + 4.0
		return false
	match quoi:
		"objet":
			var id := _tirer_objet(x)
			if id == "":
				x.r = float(x.r) + 6.0
				return false
			(b.objets as Array).append(id)
			var o := ExpeditionsDonnees.objet(id)
			_noter(x, "Trouvaille : %s %s." % [String(o.nom), ExpeditionsDonnees.etoiles(int(o.rare))])
		"animal":
			var faune: Array = d.faune
			var deja := []
			for a in b.animaux:
				deja.append(String(a))
			var libres := []
			for e in faune:
				if not deja.has(String(e)) and not ZooEspeces.espece(String(e)).is_empty():
					libres.append(String(e))
			if libres.is_empty():
				x.r = float(x.r) + 4.0
				return false
			var esp: String = libres[rng.randi() % libres.size()]
			(b.animaux as Array).append(esp)
			var verbe := "recueille" if int(x.annee) >= 1970 else "capture"
			_noter(x, "Le naturaliste %s un couple : %s." % [verbe, ZooEspeces.minuscule(ZooEspeces.nom(esp))])
		"specialiste":
			var sid := _tirer_specialiste(x)
			if sid == "":
				x.r = float(x.r) + 8.0
				return false
			(b.specialistes as Array).append(sid)
			_noter(x, "Rencontre : %s accepte de revenir avec l'équipe." % String(ExpeditionsDonnees.specialiste(sid).nom).to_lower())
	return true


func _peut_gagner(x: Dictionary, quoi: String) -> bool:
	var b: Dictionary = x.butin
	match quoi:
		"objet":
			return a_membre(x, "archeologue") and (b.objets as Array).size() < MAX_OBJETS
		"animal":
			return a_membre(x, "naturaliste") and (x.provisions as Array).has("cages") and (b.animaux as Array).size() < MAX_ESPECES \
				and not (ExpeditionsDonnees.destination(String(x.dest)).faune as Array).is_empty()
		"specialiste":
			return (b.specialistes as Array).size() < MAX_SPECIALISTES
	return false


func _tirer_objet(x: Dictionary) -> String:
	var pris: Array = x.butin.objets
	var tas := []
	var tot := 0.0
	for id in ExpeditionsDonnees.objets_de(String(x.dest)):
		if objets.has(id) or pris.has(id):
			continue
		var w := [0.0, 6.0, 3.0, 1.0][clampi(int(ExpeditionsDonnees.OBJETS[id].rare), 1, 3)] as float
		tas.append([id, w])
		tot += w
	if tas.is_empty():
		return ""
	var r := rng.randf() * tot
	for e in tas:
		r -= float(e[1])
		if r <= 0.0:
			return String(e[0])
	return String(tas[-1][0])


func _tirer_specialiste(x: Dictionary) -> String:
	var pris: Array = x.butin.specialistes
	var ici := []
	var ailleurs := []
	for id in ExpeditionsDonnees.SPECIALISTES:
		if specialistes.has(id) or pris.has(id):
			continue
		var sd := String(ExpeditionsDonnees.SPECIALISTES[id].dest)
		if sd == String(x.dest):
			ici.append(id)
		elif sd == "":
			ailleurs.append(id)
		else:
			ailleurs.append(id)
	if not ici.is_empty() and rng.randf() < 0.7:
		return String(ici[rng.randi() % ici.size()])
	if ailleurs.is_empty():
		return String(ici[0]) if not ici.is_empty() else ""
	return String(ailleurs[rng.randi() % ailleurs.size()])


# --- Événements ----------------------------------------------------------------------------------

func _tirer_evenement(x: Dictionary, d: Dictionary, j: int) -> void:
	var tas := []
	for id in ExpeditionsDonnees.EVENEMENTS:
		var e: Dictionary = ExpeditionsDonnees.EVENEMENTS[id]
		if (x.vus as Array).has(id):
			continue
		var cl: Array = e.climats
		if not cl.is_empty() and not cl.has(String(d.climat)):
			continue
		if int(e.get("annee", 0)) > int(x.annee):
			continue
		var th := String(e.get("theme", ""))
		if th != "" and not (d.themes as Array).has(th):
			continue
		tas.append(id)
	if tas.is_empty():
		return
	var id: String = tas[rng.randi() % tas.size()]
	(x.vus as Array).append(id)
	x.evenement = {"id": id, "jour": j, "limite": j + DELAI_CHOIX}
	var e2: Dictionary = ExpeditionsDonnees.EVENEMENTS[id]
	_noter(x, "%s : %s" % [String(e2.titre), String(e2.texte)])
	if not bool(x.auto):
		message.emit("Expédition %s : « %s ». Une décision t'attend (menu Expéditions)." % [String(d.nom), String(e2.titre)])
	changed.emit()


## Chance de réussite (0 à 1) d'un choix de l'événement en cours.
func chance(id: int, i: int) -> float:
	if not expeditions.has(id):
		return 0.0
	var x: Dictionary = expeditions[id]
	var ev: Dictionary = x.evenement
	if ev.is_empty():
		return 0.0
	var ch: Array = ExpeditionsDonnees.EVENEMENTS[String(ev.id)].choix
	if i < 0 or i >= ch.size():
		return 0.0
	return _chance_choix(x, ch[i])


func _chance_choix(x: Dictionary, c: Dictionary) -> float:
	var qn := String(c.get("q", ""))
	if qn == "":
		return 1.0
	var q := qualites(x)
	var seuil := int(c.get("seuil", 4)) + int(ExpeditionsDonnees.destination(String(x.dest)).diff)
	return clampf(0.55 + 0.1 * float(int(q.get(qn, 0)) - seuil), 0.1, 0.95)


## Le choix que ferait le chef (meilleure espérance).
func meilleur_choix(id: int) -> int:
	if not expeditions.has(id):
		return 0
	var x: Dictionary = expeditions[id]
	var ev: Dictionary = x.evenement
	if ev.is_empty():
		return 0
	var ch: Array = ExpeditionsDonnees.EVENEMENTS[String(ev.id)].choix
	var best := 0
	var best_v := -INF
	for i in ch.size():
		var c: Dictionary = ch[i]
		var p := _chance_choix(x, c)
		var v := p * _valeur(x, c.get("ok", {})) + (1.0 - p) * _valeur(x, c.get("ko", {}))
		if v > best_v:
			best_v = v
			best = i
	return best


func _valeur(x: Dictionary, eff: Dictionary) -> float:
	var v := float(eff.get("m", 0)) * 0.5 + float(eff.get("s", 0)) * 0.9 - float(eff.get("j", 0)) * 1.5
	v += float(eff.get("e", 0)) / 5000.0 + float(eff.get("r", 0)) * 0.4
	if eff.has("b"):
		v += 14.0
	if bool(eff.get("perte", false)):
		v -= 22.0
	# Équipe à bout : la santé compte double.
	if float(x.sante) < 40.0:
		v += float(eff.get("s", 0)) * 0.9
	return v


## Répond à l'événement en cours : rend le texte de l'issue ("" si rien à faire).
func choisir(id: int, i: int, par_le_chef := false) -> String:
	if not expeditions.has(id):
		return ""
	var x: Dictionary = expeditions[id]
	var ev: Dictionary = x.evenement
	if ev.is_empty():
		return ""
	var e: Dictionary = ExpeditionsDonnees.EVENEMENTS[String(ev.id)]
	var ch: Array = e.choix
	i = clampi(i, 0, ch.size() - 1)
	var c: Dictionary = ch[i]
	var reussi := rng.randf() < _chance_choix(x, c)
	var eff: Dictionary = c.get("ok", {}) if reussi else c.get("ko", {})
	var qn := String(c.get("q", ""))
	var txt := "%s%s → %s" % ["Le chef décide : " if par_le_chef else "", String(c.t),
		"c'est réussi." if reussi and qn != "" else ("raté." if qn != "" else "fait.")]
	_appliquer(x, eff)
	x.evenement = {}
	_noter(x, txt)
	changed.emit()
	return txt


func _appliquer(x: Dictionary, eff: Dictionary) -> void:
	x.moral = clampf(float(x.moral) + float(eff.get("m", 0)), 0.0, 100.0)
	x.sante = clampf(float(x.sante) + float(eff.get("s", 0)), 0.0, 100.0)
	var dj := int(eff.get("j", 0))
	if dj != 0:
		x.fin_etape = int(x.fin_etape) + dj
	var eu := int(eff.get("e", 0))
	if eu != 0:
		_flux(int(x.soc), POSTE, float(eu))
		x.cout = int(x.cout) - eu
	x.r = float(x.r) + float(eff.get("r", 0))
	if eff.has("b"):
		_gagner(x, String(eff.b))
	if bool(eff.get("perte", false)) and _membres_restants(x) > 0:
		_noter(x, "%s doit rentrer au pays." % _perdre_membre(x))


# --- Retour -----------------------------------------------------------------------------------------

func _rentrer(x: Dictionary, issue: String, texte: String) -> void:
	var j := last_day if last_day >= 0 else jour()
	x.evenement = {}
	x.etat = "retour"
	var voyage := int(x.aller)
	# Rapatriement : le voyage du retour est plus court (on prend le plus rapide).
	if issue == "rapatriee":
		voyage = maxi(1, voyage / 2)
		var b: Dictionary = x.butin
		(b.objets as Array).resize(int(ceil((b.objets as Array).size() / 2.0)))
		(b.animaux as Array).clear()
	x.issue = issue
	x.fin_etape = j + voyage
	_noter(x, texte)
	if issue != "":
		message.emit("Expédition %s : %s" % [String(ExpeditionsDonnees.destination(String(x.dest)).nom), texte])


func _arrivee(x: Dictionary) -> void:
	var d := ExpeditionsDonnees.destination(String(x.dest))
	var b: Dictionary = x.butin
	var j := last_day if last_day >= 0 else jour()
	for o in b.objets:
		objets[String(o)] = {"lieu": "reserve", "musee": "", "soc": int(x.soc), "jour": j}
	for esp in b.animaux:
		animaux.append({"esp": String(esp), "f": false, "dest": String(x.dest)})
		animaux.append({"esp": String(esp), "f": true, "dest": String(x.dest)})
	for s in b.specialistes:
		specialistes[String(s)] = {"ville": -1, "jour": j}
	var gain := float(x.r) + 10.0 * (b.objets as Array).size() + 6.0 * (b.animaux as Array).size() + 15.0 * (b.specialistes as Array).size()
	for o in b.objets:
		gain += 0.1 * float(ExpeditionsDonnees.objet(String(o)).prestige)
	gain += 4.0 * float(d.diff)
	if a_membre(x, "photographe"):
		gain *= float(ExpeditionsDonnees.MEMBRES.photographe.recit)
	var issue := String(x.issue)
	if issue == "rapatriee" or issue == "abandon":
		gain *= 0.4
	var trouve := (b.objets as Array).size() + (b.animaux as Array).size() + (b.specialistes as Array).size()
	if issue == "":
		issue = "reussie" if trouve > 0 or float(x.r) >= 12.0 else "bredouille"
	x.issue = issue
	x.renommee = roundf(gain)
	renommee += roundf(gain)
	x.etat = "finie"
	x.retour = j
	var c := int(x.chef)
	if c >= 0 and c < chefs.size():
		chefs[c].libre = true
		chefs[c].faites = int(chefs[c].faites) + 1
		chefs[c].xp = int(chefs[c].xp) + trouve
		if issue == "reussie":
			chefs[c].reussies = int(chefs[c].reussies) + 1
	var parts := []
	if not (b.objets as Array).is_empty():
		parts.append("%d objet%s rare%s" % [(b.objets as Array).size(), "s" if (b.objets as Array).size() > 1 else "", "s" if (b.objets as Array).size() > 1 else ""])
	if not (b.animaux as Array).is_empty():
		parts.append("%d couple%s d'animaux" % [(b.animaux as Array).size(), "s" if (b.animaux as Array).size() > 1 else ""])
	if not (b.specialistes as Array).is_empty():
		parts.append("%d spécialiste%s" % [(b.specialistes as Array).size(), "s" if (b.specialistes as Array).size() > 1 else ""])
	var quoi := ", ".join(parts) if not parts.is_empty() else "de beaux souvenirs et des pieds fatigués"
	var titre := ""
	match issue:
		"reussie":
			titre = "Retour triomphal de l'expédition %s : %s." % [String(d.nom), quoi]
		"bredouille":
			titre = "L'expédition %s rentre bredouille, mais avec des histoires plein les poches." % String(d.nom)
		"rapatriee":
			titre = "L'expédition %s a été rapatriée d'urgence. Elle rapporte tout de même %s." % [String(d.nom), quoi]
		"abandon":
			titre = "L'expédition %s a abandonné en route. Elle rapporte %s." % [String(d.nom), quoi]
		_:
			titre = "L'expédition %s est rappelée et rentre avec %s." % [String(d.nom), quoi]
	_noter(x, titre)
	recits.push_front({"jour": j, "texte": titre, "issue": issue, "dest": String(x.dest), "id": int(x.id)})
	if recits.size() > 40:
		recits.resize(40)
	message.emit(titre)
	actualite.emit(titre, pos_of(int(x.soc)))
	changed.emit()


func _noter(x: Dictionary, t: String) -> void:
	var j := last_day if last_day >= 0 else jour()
	(x.log as Array).push_front({"jour": j, "t": t})
	if (x.log as Array).size() > 60:
		(x.log as Array).resize(60)


# --- La réserve : objets, animaux, spécialistes ---------------------------------------------------

func objets_en(lieu: String) -> Array:
	var out := []
	for id in objets:
		if String(objets[id].lieu) == lieu:
			out.append(String(id))
	out.sort()
	return out


## Donne un objet de la réserve (ou du cabinet) à un musée (clé de Musee).
func donner_musee(oid: String, key: String) -> String:
	if not objets.has(oid) or not (String(objets[oid].lieu) in ["reserve", "cabinet"]):
		return "objet introuvable"
	var mu := Musee.instance
	if mu == null or not is_instance_valid(mu) or not mu.musees.has(key):
		return "musée introuvable"
	objets[oid].lieu = "musee"
	objets[oid].musee = key
	mu._cache.erase(key)
	message.emit("%s rejoint les collections de %s." % [String(ExpeditionsDonnees.objet(oid).nom), mu.nom(key)])
	changed.emit()
	return ""


## Expose un objet au cabinet de curiosités d'une Société (attrait touristique).
func exposer(oid: String, soc := -1) -> String:
	if not objets.has(oid) or not (String(objets[oid].lieu) in ["reserve", "musee"]):
		return "objet introuvable"
	if soc < 0:
		soc = int(objets[oid].soc)
	if not societes().has(soc):
		var s := societes()
		if s.is_empty():
			return "il faut une Société des explorateurs"
		soc = int(s[0])
	_retirer_du_musee(oid)
	objets[oid].lieu = "cabinet"
	objets[oid].soc = soc
	changed.emit()
	return ""


func _retirer_du_musee(oid: String) -> void:
	var key := String(objets[oid].get("musee", ""))
	if key != "" and Musee.instance != null and is_instance_valid(Musee.instance):
		Musee.instance._cache.erase(key)
	objets[oid].musee = ""


## Vend un objet aux enchères (sa valeur, dans la caisse de la ville de la Société).
func vendre(oid: String) -> String:
	if not objets.has(oid) or String(objets[oid].lieu) in ["vendu", "rendu"]:
		return "objet introuvable"
	var o := ExpeditionsDonnees.objet(oid)
	_retirer_du_musee(oid)
	objets[oid].lieu = "vendu"
	_flux(int(objets[oid].soc), "Expéditions : ventes aux enchères", float(o.valeur))
	message.emit("%s est adjugé %s." % [String(o.nom), BuildingSystem.format_money(int(o.valeur))])
	changed.emit()
	return ""


## Rend un objet à son pays d'origine : pas d'argent, mais de la renommée.
func rendre(oid: String) -> String:
	if not objets.has(oid) or String(objets[oid].lieu) in ["vendu", "rendu"]:
		return "objet introuvable"
	var o := ExpeditionsDonnees.objet(oid)
	_retirer_du_musee(oid)
	objets[oid].lieu = "rendu"
	var g := roundf(float(o.prestige) * 0.5)
	renommee += g
	var d := ExpeditionsDonnees.destination(String(o.dest))
	var t := "La ville rend %s à son pays d'origine (%s). Un geste très remarqué." % [String(o.nom).substr(0, 1).to_lower() + String(o.nom).substr(1), String(d.get("pays", ""))]
	message.emit(t)
	actualite.emit(t, pos_of(int(objets[oid].soc)))
	changed.emit()
	return ""


## Prestige que les objets rares ajoutent à un musée.
func prestige_musee(key: String) -> float:
	var p := 0.0
	for id in objets:
		if String(objets[id].lieu) == "musee" and String(objets[id].musee) == key:
			p += float(ExpeditionsDonnees.objet(String(id)).prestige)
	return p


func objets_du_musee(key: String) -> Array:
	var out := []
	for id in objets:
		if String(objets[id].lieu) == "musee" and String(objets[id].musee) == key:
			out.append(String(id))
	return out


## Place un animal de la réserve au zoo (gratuit) : rend "" ou la raison. Avec un enclos,
## il s'y installe ; avec -1, il attend un enclos dans l'onglet Échanges du zoo. Né
## sauvage, il apporte des gènes neufs (ZooSysteme.accueillir).
func placer_animal(i: int, enclos_id: int = -1) -> String:
	if i < 0 or i >= animaux.size():
		return "animal introuvable"
	var zs := ZooSysteme.instance
	if zs == null or not is_instance_valid(zs) or zs.zoos.is_empty():
		return "il faut d'abord un zoo"
	if enclos_id >= 0 and not zs.enclos.has(enclos_id):
		return "enclos introuvable"
	var a: Dictionary = animaux[i]
	var esp := String(a.esp)
	var d := ExpeditionsDonnees.destination(String(a.get("dest", "")))
	var extra := {"f": bool(a.f)}
	if enclos_id >= 0:
		extra["enclos"] = enclos_id
	if not d.is_empty():
		extra["texte"] = ("%s, rapporté de %s, s'installe au zoo." if enclos_id >= 0 else "%s, rapporté de %s, attend un enclos (zoo, onglet Échanges).") % [ZooEspeces.nom(esp), String(d.nom)]
	var r := zs.accueillir(esp, -1, "sauvage", extra)
	if r == 0:
		return "impossible de l'accueillir"
	animaux.remove_at(i)
	changed.emit()
	return ""


## Confie un animal à un autre zoo (il rapporte 80 % de son prix).
func confier_animal(i: int) -> String:
	if i < 0 or i >= animaux.size():
		return "animal introuvable"
	var a: Dictionary = animaux[i]
	var e := ZooEspeces.espece(String(a.esp))
	var soc := societes()
	_flux(int(soc[0]) if not soc.is_empty() else -1, "Expéditions : animaux confiés", float(e.get("prix", 0)) * 0.8)
	animaux.remove_at(i)
	changed.emit()
	return ""


## Villes où l'on peut installer un spécialiste : [[clé, nom]] ; [[0, "Toute la ville"]] sans pays.
func villes() -> Array:
	var p := Pays.instance
	if p == null or not is_instance_valid(p) or not p.a_des_villes():
		return [[0, "Toute la ville"]]
	var out := []
	for nk in p.cles_nations():
		for v in p.villes_de(int(nk)):
			out.append([int(v), p.nom_de(int(v)) if p.has_method("nom_de") else "Ville %d" % int(v)])
	if out.is_empty():
		return [[0, "Toute la ville"]]
	return out


func specialistes_de(ville: int) -> Array:
	var out := []
	for id in specialistes:
		if int(specialistes[id].ville) == ville:
			out.append(String(id))
	out.sort()
	return out


## Installe un spécialiste dans une ville (-1 : le remet en réserve).
func affecter(sid: String, ville: int) -> String:
	if not specialistes.has(sid):
		return "spécialiste introuvable"
	if ville >= 0 and int(specialistes[sid].ville) != ville and specialistes_de(ville).size() >= ExpeditionsDonnees.SPECIALISTES_PAR_VILLE:
		return "%d spécialistes au plus par ville" % ExpeditionsDonnees.SPECIALISTES_PAR_VILLE
	specialistes[sid].ville = ville
	# Les musées relisent leur prestige (conservatrice…).
	if Musee.instance != null and is_instance_valid(Musee.instance):
		Musee.instance._cache.clear()
	if ville >= 0:
		message.emit("%s s'installe en ville." % String(ExpeditionsDonnees.specialiste(sid).nom))
	changed.emit()
	return ""


# --- Effets pour les autres systèmes -----------------------------------------------------------------

## Somme d'un effet des spécialistes installés : ville -2 = tous ; sinon ceux de la
## ville (et ceux installés « partout » quand il n'y a pas de pays).
static func facteur(effet: String, ville := -2) -> float:
	var ex := instance
	if ex == null or not is_instance_valid(ex):
		return 0.0
	var v := 0.0
	for id in ex.specialistes:
		var vk := int(ex.specialistes[id].ville)
		if vk < 0:
			continue
		if ville != -2 and vk != 0 and vk != ville:
			continue
		v += float((ExpeditionsDonnees.specialiste(String(id)).get("effets", {}) as Dictionary).get(effet, 0.0))
	return v


## Ville d'un bâtiment pour les effets (-2 : pas de pays, tous les spécialistes comptent).
static func ville_du_batiment(bid: int) -> int:
	var p := Pays.instance
	if p == null or not is_instance_valid(p) or not p.a_des_villes():
		return -2
	return p.payeur_du_batiment(bid)


## Rythme des chantiers d'un bâtiment (1 = normal).
static func rythme_chantier(bid: int) -> float:
	if instance == null:
		return 1.0
	return 1.0 + facteur("chantiers", ville_du_batiment(bid))


## Multiplicateur du prestige d'un musée (clé de Musee).
static func facteur_musee(key: String) -> float:
	if instance == null:
		return 1.0
	var mu := Musee.instance
	var bid := mu.bid_of(key) if mu != null and is_instance_valid(mu) else -1
	return 1.0 + facteur("musee", ville_du_batiment(bid) if bid >= 0 else -2)


## Santé (groupe "sante_sources") : les médecins rapportés réduisent les risques.
func risque_sante(bid: int) -> float:
	return -facteur("sante", ville_du_batiment(bid))


## Avis des habitants (groupe "avis_sources").
func avis_facteurs() -> Array:
	return [{"id": "expeditions", "theme": "loisirs", "f": _avis, "ville": true}]


func _avis() -> Array:
	var vv := -2
	if Avis.instance != null and is_instance_valid(Avis.instance) and int(Avis.instance.get("ville_vid")) >= 0:
		vv = int(Avis.instance.get("ville_vid"))
	var v := facteur("avis", vv)
	var raisons := []
	if v > 0.0:
		raisons.append("+ Des personnalités venues du bout du monde")
	if renommee >= 150.0:
		v += 1.0
		raisons.append("+ Les explorateurs de la ville font la une")
	return [minf(v, 4.0), raisons]


## Sites touristiques des Sociétés (cabinet de curiosités et renommée), pour Tourisme.
func sites_tourisme() -> Array:
	var out := []
	var socs := societes()
	for bid in socs:
		var pts := minf(renommee * 0.004, 4.0) / maxf(1.0, float(socs.size()))
		var n := 0
		for id in objets:
			if String(objets[id].lieu) == "cabinet" and int(objets[id].soc) == int(bid):
				pts += float(ExpeditionsDonnees.objet(String(id)).prestige) * 0.012
				n += 1
		if pts <= 0.01:
			continue
		out.append({"kind": "expeditions", "key": int(bid), "nom": "Cabinet de curiosités (%d objet%s)" % [n, "s" if n > 1 else ""],
			"pos": pos_of(int(bid)), "pts": pts, "note": clampf(2.5 + float(n) * 0.4, 0.0, 5.0)})
	return out


# --- Argent --------------------------------------------------------------------------------------

func _flux(soc: int, poste: String, montant: float) -> void:
	if buildings == null or buildings.unlimited_money or absf(montant) < 0.01:
		return
	var prev := Pays.au_batiment(soc) if soc >= 0 else -1
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		if montant > 0.0:
			bc.recette(poste, montant)
		else:
			bc.depense(poste, -montant)
	else:
		buildings.money += roundi(montant)
	Pays.retour(prev)


# --- Résumé et sauvegarde ------------------------------------------------------------------------

func summary() -> String:
	var n := en_cours().size()
	if n == 0 and objets.is_empty():
		return ""
	return "Expéditions : %d en cours, renommée %d" % [n, roundi(renommee)]


func to_dict() -> Dictionary:
	var ex := {}
	for id in expeditions:
		ex[str(id)] = expeditions[id]
	return {"expeditions": ex, "next_id": next_id, "chefs": chefs, "objets": objets, "animaux": animaux,
		"specialistes": specialistes, "renommee": renommee, "recits": recits, "last_day": last_day}


func from_dict(d: Dictionary) -> void:
	clear()
	var ex: Dictionary = d.get("expeditions", {})
	for k in ex:
		var x: Dictionary = (ex[k] as Dictionary).duplicate(true)
		# JSON : les entiers reviennent en flottants.
		for f in ["id", "soc", "chef", "depart", "fin_etape", "aller", "explo", "cout", "perdus", "annee", "retour", "renommee"]:
			if x.has(f):
				x[f] = int(x[f])
		var mb := {}
		for m in (x.get("membres", {}) as Dictionary):
			mb[String(m)] = int(x.membres[m])
		x.membres = mb
		var ev: Dictionary = x.get("evenement", {})
		if not ev.is_empty():
			ev.jour = int(ev.get("jour", 0))
			ev.limite = int(ev.get("limite", 0))
		expeditions[int(k)] = x
	next_id = int(d.get("next_id", 1))
	for c in d.get("chefs", []):
		var cc: Dictionary = (c as Dictionary).duplicate()
		for f in ["xp", "faites", "reussies"]:
			cc[f] = int(cc.get(f, 0))
		chefs.append(cc)
	var ob: Dictionary = d.get("objets", {})
	for k in ob:
		var o: Dictionary = (ob[k] as Dictionary).duplicate()
		o.soc = int(o.get("soc", -1))
		o.jour = int(o.get("jour", 0))
		objets[String(k)] = o
	for a in d.get("animaux", []):
		animaux.append((a as Dictionary).duplicate())
	var sp: Dictionary = d.get("specialistes", {})
	for k in sp:
		specialistes[String(k)] = {"ville": int(sp[k].get("ville", -1)), "jour": int(sp[k].get("jour", 0))}
	renommee = float(d.get("renommee", 0.0))
	for r in d.get("recits", []):
		var rr: Dictionary = (r as Dictionary).duplicate()
		rr.jour = int(rr.get("jour", 0))
		recits.append(rr)
	last_day = int(d.get("last_day", -1))
	changed.emit()
