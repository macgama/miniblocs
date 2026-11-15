class_name SystemesGeres
extends RefCounted
## Carte entre amis : les systèmes que l'on gère depuis un panneau (clubs de sport,
## parcs de loisirs, zoos, musées). Le serveur les simule et fait foi.
##
## - Les décisions des joueurs (prix, nom, transferts, enclos, animaux, expositions…)
##   partent au serveur par des appels (Multijoueur.APPELS, systèmes marqués « etat ») :
##   seul le maire de la ville où se trouve le bâtiment décide ; hors des villes,
##   tout le monde peut.
## - Le serveur envoie l'état du système (sa section de sauvegarde) juste après un
##   appel, et sinon dès qu'il a changé, au plus toutes les PERIODE secondes.
## - Chez le joueur, l'état reçu remplace le sien, mais ce que son jeu anime à l'écran
##   (visiteurs qui se promènent, horloge de la simulation, besoins des animaux) est
##   gardé : pas de saut à l'écran. Les clubs ne sont pas simulés chez les joueurs
##   (matchs, marché des transferts : tirages au sort du serveur).
## Voir docs/multijoueur.md.

## Délai minimal entre deux envois d'un même système qui change tout seul (s).
const PERIODE := 10.0
## Vérification des changements sur le serveur (s).
const VERIF := 2.0


## nom → {"obj": système, "garder": variables locales gardées, "entites": {variable:
## clé de l'état reçu} (dictionnaires d'objets dont on garde les champs non envoyés),
## "simule": faux si le joueur ne simule pas ce système}.
static func specs(jeu: Node) -> Dictionary:
	var s := {}
	if jeu == null:
		return s
	var clubs: Variant = jeu.get("clubs")
	if clubs is Dictionary:
		for sp in clubs:
			s["club:" + String(sp)] = {"obj": clubs[sp], "simule": false}
	elif jeu.get("club") != null:
		s["club:football"] = {"obj": jeu.club, "simule": false}
	var horloge := ["clock", "last_unix", "last_day"]
	if jeu.get("parc") != null:
		s["parc"] = {"obj": jeu.parc, "garder": horloge + ["agents", "next_agent"], "entites": {"parcs": "parcs", "items": "items"}}
	if jeu.get("zoo") != null:
		s["zoo"] = {"obj": jeu.zoo, "garder": horloge, "entites": {"zoos": "zoos", "enclos": "enclos", "animaux": "animaux"}}
	if jeu.get("musee") != null:
		s["musee"] = {"obj": jeu.musee, "garder": horloge, "entites": {"musees": "musees"}}
	return s


## Le système d'un appel (sys "club" : selon le sport).
static func nom_de_appel(a: Dictionary) -> String:
	var sys := String(a.get("sys", ""))
	if sys == "club":
		return "club:" + String(a.get("sport", "football"))
	return sys


static func lire(spec: Dictionary) -> Dictionary:
	var d: Variant = (spec.obj as Object).call("to_dict")
	return d if d is Dictionary else {}


static func empreinte(d: Dictionary) -> int:
	return hash(var_to_str(d))


## Chez un joueur : l'état reçu du serveur remplace le sien (en gardant l'animation locale).
static func appliquer(spec: Dictionary, d: Dictionary) -> void:
	var o: Object = spec.obj
	var gardes := {}
	for v in spec.get("garder", []):
		var x: Variant = o.get(v)
		gardes[v] = x.duplicate() if x is Dictionary or x is Array else x
	var anciens := {}
	var ents: Dictionary = spec.get("entites", {})
	for v in ents:
		var x: Variant = o.get(v)
		if x is Dictionary:
			anciens[v] = (x as Dictionary).duplicate()
	# Zoo : seuls les enclos qui ont vraiment changé sont redessinés.
	var traces := {}
	if o is ZooSysteme:
		for id in (o as ZooSysteme).enclos:
			var e: Dictionary = (o as ZooSysteme).enclos[id]
			traces[id] = [e.pts, e.barriere]
	var avant := Multijoueur.rejeu
	Multijoueur.rejeu = true
	o.call("from_dict", d)
	Multijoueur.rejeu = avant
	for v in gardes:
		o.set(v, gardes[v])
	for v in anciens:
		var cur: Variant = o.get(v)
		if not cur is Dictionary:
			continue
		var recu: Variant = d.get(String(ents[v]), {})
		var r: Dictionary = recu if recu is Dictionary else {}
		var vieux: Dictionary = anciens[v]
		for id in cur:
			if not vieux.has(id) or not cur[id] is Dictionary or not vieux[id] is Dictionary:
				continue
			var envoye: Variant = r.get(str(id), r.get(id, {}))
			var champs: Dictionary = envoye if envoye is Dictionary else {}
			for k in vieux[id]:
				if not champs.has(k) and k != "id":
					cur[id][k] = vieux[id][k]
	if o is ZooSysteme:
		var z := o as ZooSysteme
		for id in z.enclos:
			if traces.has(id) and traces[id][0] == z.enclos[id].pts and traces[id][1] == z.enclos[id].barriere:
				z._sales.erase(id)


## Ville (clé) dont le maire décide d'un bâtiment ou d'un point de la carte (-1 : aucune).
static func ville_au_point(jeu: Node, p: Vector2) -> int:
	if jeu == null or jeu.get("communes") == null:
		return -1
	return int(jeu.communes.village_au_point(p.x, p.y))


static func point_du_batiment(jeu: Node, bid: int) -> Variant:
	if jeu == null or not jeu.buildings.buildings.has(bid):
		return null
	var c := BuildingSystem.rect_center(jeu.buildings._rect_of(jeu.buildings.buildings[bid]))
	return Vector2(c.x, c.z)


## Ce jeu est un joueur connecté à une carte entre amis (ses décisions partent au serveur) ?
static func client() -> bool:
	var cl := Multijoueur.client_actif()
	return Multijoueur.role == Multijoueur.Role.CLIENT and not Multijoueur.rejeu and cl != null and cl.etat == "en_jeu"


## Joueur connecté : envoie la décision au serveur (vrai) ; faux : à faire ici (en solo).
## p : point de la carte (bâtiment, enclos) qui dit quelle ville décide et paie.
static func relayer(sys: String, f: String, args: Array, p: Variant = null, extra: Dictionary = {}) -> bool:
	if Multijoueur.role != Multijoueur.Role.CLIENT or Multijoueur.rejeu:
		return false
	var cl := Multijoueur.client_actif()
	if cl == null:
		return false
	var x := extra.duplicate()
	if p is Vector2 or p is Vector3:
		var q: Vector2 = Vector2(p.x, p.z) if p is Vector3 else p
		x["p"] = q
		x["ville"] = ville_au_point(cl.jeu, q)
	return Multijoueur.relayer(sys, f, args, x)


## Le stade (bâtiment) du club, ou celui choisi pour le fonder.
static func point_du_club(c: ClubSport, stade := -1) -> Variant:
	if c == null or c.buildings == null:
		return null
	var bid := stade if stade >= 0 else (int(c.club.get("stade", -1)) if c.fonde() else -1)
	if bid < 0 or not c.buildings.buildings.has(bid):
		return null
	var v := BuildingSystem.rect_center(c.buildings._rect_of(c.buildings.buildings[bid]))
	return Vector2(v.x, v.z)
