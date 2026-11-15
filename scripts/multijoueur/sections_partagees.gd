class_name SectionsPartagees
extends RefCounted
## Carte entre amis : les parties de la sauvegarde que les joueurs changent à la main
## (zones, blocs de l'éditeur libre, murs et étages, meubles, décors, réseaux…).
##
## Principe : chaque section est « mise à plat » (normaliser) : une entrée par objet
## (une zone, un bloc, un tronçon, un décor…), plus les réglages simples. Le jeu d'un
## joueur compare sa section à la dernière version connue du serveur et envoie la
## différence (un « patch » : entrées mises, entrées ôtées). Le serveur l'applique à
## sa partie, puis envoie à tous ce qui a vraiment changé chez lui. Deux joueurs qui
## changent des objets différents en même temps ne s'écrasent donc pas.
##
## Une spec décrit une section :
##  - "coll" : chemin → genre de collection :
##      {"genre": "liste", "cle": "id"} tableau de dictionnaires repérés par un champ,
##      {"genre": "dico"}               dictionnaire repéré par sa clé,
##      {"genre": "plat", "pas": 4}     tableau plat [x, y, z, valeur, …] repéré par les pas−1 premiers,
##      {"genre": "ensemble"}           tableau d'enregistrements (chacun est sa propre clé) ;
##    "ids": true quand les clés sont des numéros donnés par le jeu (deux joueurs peuvent
##    prendre le même en même temps : le serveur refuse le second) ;
##  - "champs" : champs des objets simulés par chaque jeu (chantier, panne…), ni
##    comparés ni écrasés ;
##  - "ignorer" : chemins simulés ou propres à chaque jeu ;
##  - "compteurs" : chemins de compteurs (le serveur garde le plus grand).
## Les chemins imbriqués s'écrivent "elec/troncons". Voir docs/multijoueur.md.

const SEP := "#"


## Les sections partagées de la partie jeu (scène Terre) : nom → spec avec
## "lire" (→ Dictionary) et "ecrire" (Dictionary →).
static func specs(jeu: Node) -> Dictionary:
	var s := {}
	if jeu == null:
		return s
	var champs_reseau := ["av", "hs", "ok"]
	s["zones"] = {"obj": jeu.zones, "coll": {"zones": {"genre": "liste", "cle": "id", "ids": true}},
		"compteurs": ["next_id"], "ignorer": ["version", "growth"]}
	s["blocs"] = {"obj": jeu.blocks, "coll": {"blocks": {"genre": "plat", "pas": 4}}, "ignorer": ["version", "size"]}
	if jeu.get("plans") != null:
		s["plans"] = {"obj": jeu.plans, "coll": {"plans": {"genre": "liste", "cle": "id", "ids": true}}, "ignorer": ["version", "h"]}
	if jeu.get("mobilier") != null:
		s["mobilier"] = {"obj": jeu.mobilier, "coll": {"plans": {"genre": "liste", "cle": "id"}}, "ignorer": ["version"]}
	if jeu.get("decors") != null:
		s["decors"] = {"obj": jeu.decors, "coll": {"poses": {"genre": "ensemble"}, "effaces": {"genre": "ensemble"}}}
	if jeu.get("reseaux") != null:
		var coll := {}
		var cpt := []
		for r in ["elec", "eau", "egout", "gaz"]:
			coll[r + "/troncons"] = {"genre": "dico", "ids": true}
			cpt.append(r + "/next")
		s["reseaux"] = {"obj": jeu.reseaux, "coll": coll, "champs": champs_reseau, "compteurs": cpt,
			"ignorer": ["version", "incidents", "stocks", "manque", "compta", "heures"]}
	if jeu.get("telecom") != null:
		s["telecom"] = {"obj": jeu.telecom, "coll": {"fibre/troncons": {"genre": "dico", "ids": true}, "cuivre/troncons": {"genre": "dico", "ids": true}},
			"champs": champs_reseau, "compteurs": ["fibre/next", "cuivre/next"], "ignorer": ["v"]}
	if jeu.get("parc_allees") != null:
		s["parc_allees"] = {"obj": jeu.parc_allees, "coll": {"allees": {"genre": "ensemble"}, "files": {"genre": "liste", "cle": "bid"}}, "ignorer": ["version"]}
	for nom in s:
		var o: Object = s[nom].obj
		s[nom]["lire"] = Callable(o, "to_dict")
		s[nom]["ecrire"] = Callable(o, "from_dict")
	return s


static func lire(spec: Dictionary) -> Dictionary:
	var d: Variant = (spec.lire as Callable).call()
	return d if d is Dictionary else {}


# --- Mise à plat ----------------------------------------------------------------------------

## Section → {chemin: valeur, "chemin#clé": objet} (sans les chemins ignorés ni les champs simulés).
static func normaliser(d: Dictionary, spec: Dictionary) -> Dictionary:
	var out := {}
	_normaliser(d, "", spec, out)
	return out


static func _normaliser(d: Dictionary, prefixe: String, spec: Dictionary, out: Dictionary) -> void:
	var coll: Dictionary = spec.get("coll", {})
	var ign: Array = spec.get("ignorer", [])
	for k in d:
		var chemin := prefixe + String(k)
		if chemin in ign:
			continue
		var v: Variant = d[k]
		if coll.has(chemin):
			var items := elements(v, coll[chemin])
			var champs: Array = spec.get("champs", [])
			for ck in items:
				out[chemin + SEP + ck] = _sans_champs(items[ck], champs)
		elif v is Dictionary and _a_sous_collection(chemin, coll):
			_normaliser(v, chemin + "/", spec, out)
		else:
			out[chemin] = v


static func _a_sous_collection(chemin: String, coll: Dictionary) -> bool:
	for c in coll:
		if String(c).begins_with(chemin + "/"):
			return true
	return false


static func _sans_champs(item: Variant, champs: Array) -> Variant:
	if champs.is_empty() or not item is Dictionary:
		return item
	var e: Dictionary = (item as Dictionary).duplicate()
	for f in champs:
		e.erase(f)
	return e


## Une collection → {clé: objet}.
static func elements(v: Variant, c: Dictionary) -> Dictionary:
	var out := {}
	match String(c.get("genre", "")):
		"liste":
			var champ := String(c.get("cle", "id"))
			if v is Array:
				for e in v:
					if e is Dictionary and (e as Dictionary).has(champ):
						out[str(e[champ])] = e
		"dico":
			if v is Dictionary:
				for k in v:
					out[str(k)] = v[k]
		"plat":
			var pas := int(c.get("pas", 2))
			if v is Array:
				var a: Array = v
				var i := 0
				while i + pas - 1 < a.size():
					out[var_to_str(a.slice(i, i + pas - 1))] = a.slice(i, i + pas)
					i += pas
		"ensemble":
			if v is Array:
				for e in v:
					out[var_to_str(e)] = e
	return out


## {clé: objet} → la collection telle que la section l'attend.
static func reformer(items: Dictionary, c: Dictionary) -> Variant:
	match String(c.get("genre", "")):
		"liste", "ensemble":
			return items.values()
		"dico":
			return items.duplicate()
		"plat":
			var a := []
			for k in items:
				a.append_array(items[k])
			return a
	return items.values()


# --- Différences --------------------------------------------------------------------------

## Ce qui a changé de a à b : {"mis": {clé: valeur}, "otes": [clés]}.
static func difference(a: Dictionary, b: Dictionary) -> Dictionary:
	var mis := {}
	var otes := []
	for k in b:
		if not a.has(k) or not _egal(a[k], b[k]):
			mis[k] = b[k]
	for k in a:
		if not b.has(k):
			otes.append(k)
	return {"mis": mis, "otes": otes}


static func _egal(x: Variant, y: Variant) -> bool:
	if typeof(x) != typeof(y):
		# 3 et 3.0 : même valeur (une section passée par JSON).
		if (x is int or x is float) and (y is int or y is float):
			return is_equal_approx(float(x), float(y))
		return false
	return x == y


static func vide(p: Dictionary) -> bool:
	return (p.get("mis", {}) as Dictionary).is_empty() and (p.get("otes", []) as Array).is_empty()


## Le patch ne change rien à plat ?
static func deja_applique(plat: Dictionary, p: Dictionary, spec: Dictionary = {}) -> bool:
	var mis: Dictionary = p.get("mis", {})
	var cpt: Array = spec.get("compteurs", [])
	for k in mis:
		if k in cpt and plat.has(k) and int(plat[k]) >= int(mis[k]):
			continue
		if not plat.has(k) or not _egal(plat[k], mis[k]):
			return false
	for k in p.get("otes", []):
		if plat.has(k):
			return false
	return true


## Les entrées mises qui n'existaient pas dans a (nouveaux objets).
static func nouveaux(a: Dictionary, p: Dictionary) -> Array:
	var out := []
	for k in p.get("mis", {}):
		if String(k).contains(SEP) and not a.has(k):
			out.append(k)
	return out


## Entrées d'une collection à numéros prises en même temps par un autre joueur.
static func conflits(plat_serveur: Dictionary, p: Dictionary, spec: Dictionary) -> Array:
	var out := []
	var coll: Dictionary = spec.get("coll", {})
	var mis: Dictionary = p.get("mis", {})
	for k in p.get("nouveaux", []):
		var ks := String(k)
		var chemin := ks.get_slice(SEP, 0)
		if not bool((coll.get(chemin, {}) as Dictionary).get("ids", false)):
			continue
		if plat_serveur.has(ks) and mis.has(ks) and not _egal(plat_serveur[ks], _sans_champs(mis[ks], spec.get("champs", []))):
			out.append(ks)
	return out


## Empreinte d'une section à plat (ne dépend pas de l'ordre).
static func empreinte(plat: Dictionary) -> int:
	var h := plat.size()
	for k in plat:
		h = h ^ hash([k, plat[k]])
	return h


# --- Application ----------------------------------------------------------------------------

## Applique le patch p à la section d (copie modifiée). Les objets mis gardent les champs
## simulés de la version locale ; complets : les objets entiers (pour les champs simulés
## des nouveaux objets).
static func appliquer(d: Dictionary, p: Dictionary, spec: Dictionary, complets: Dictionary = {}) -> Dictionary:
	var out := d.duplicate(true)
	var coll: Dictionary = spec.get("coll", {})
	var champs: Array = spec.get("champs", [])
	var cpt: Array = spec.get("compteurs", [])
	var touches := {}
	var mis: Dictionary = p.get("mis", {})
	for k in mis:
		var ks := String(k)
		if ks.contains(SEP):
			var chemin := ks.get_slice(SEP, 0)
			if not coll.has(chemin):
				continue
			var items := _items(out, chemin, coll[chemin], touches)
			var cle := ks.substr(chemin.length() + 1)
			var e: Variant = complets.get(ks, mis[k])
			if e is Dictionary and items.has(cle) and items[cle] is Dictionary and not champs.is_empty():
				var n: Dictionary = (e as Dictionary).duplicate(true)
				for f in champs:
					if (items[cle] as Dictionary).has(f):
						n[f] = items[cle][f]
				e = n
			items[cle] = e
		else:
			var v: Variant = mis[k]
			if ks in cpt:
				var avant: Variant = _lire_chemin(out, ks)
				if avant != null:
					v = maxi(int(avant), int(v))
			_ecrire_chemin(out, ks, v)
	for k in p.get("otes", []):
		var ks := String(k)
		if ks.contains(SEP):
			var chemin := ks.get_slice(SEP, 0)
			if coll.has(chemin):
				_items(out, chemin, coll[chemin], touches).erase(ks.substr(chemin.length() + 1))
		elif not ks in cpt:
			_effacer_chemin(out, ks)
	for chemin in touches:
		_ecrire_chemin(out, chemin, reformer(touches[chemin], coll[chemin]))
	return out


static func _items(d: Dictionary, chemin: String, c: Dictionary, touches: Dictionary) -> Dictionary:
	if not touches.has(chemin):
		touches[chemin] = elements(_lire_chemin(d, chemin), c)
	return touches[chemin]


static func _lire_chemin(d: Dictionary, chemin: String) -> Variant:
	var cur: Variant = d
	for part in chemin.split("/"):
		if not cur is Dictionary or not (cur as Dictionary).has(part):
			return null
		cur = cur[part]
	return cur


static func _ecrire_chemin(d: Dictionary, chemin: String, v: Variant) -> void:
	var parts := chemin.split("/")
	var cur: Dictionary = d
	for i in parts.size() - 1:
		if not cur.has(parts[i]) or not cur[parts[i]] is Dictionary:
			cur[parts[i]] = {}
		cur = cur[parts[i]]
	cur[parts[parts.size() - 1]] = v


static func _effacer_chemin(d: Dictionary, chemin: String) -> void:
	var parts := chemin.split("/")
	var cur: Variant = d
	for i in parts.size() - 1:
		if not cur is Dictionary or not (cur as Dictionary).has(parts[i]):
			return
		cur = cur[parts[i]]
	if cur is Dictionary:
		(cur as Dictionary).erase(parts[parts.size() - 1])


## Objets entiers (avec leurs champs simulés) des entrées mises d'un patch.
static func complets(d: Dictionary, p: Dictionary, spec: Dictionary) -> Dictionary:
	var out := {}
	if (spec.get("champs", []) as Array).is_empty():
		return out
	var coll: Dictionary = spec.get("coll", {})
	var par_chemin := {}
	for k in p.get("mis", {}):
		var ks := String(k)
		if not ks.contains(SEP):
			continue
		var chemin := ks.get_slice(SEP, 0)
		if not coll.has(chemin):
			continue
		if not par_chemin.has(chemin):
			par_chemin[chemin] = elements(_lire_chemin(d, chemin), coll[chemin])
		var cle := ks.substr(chemin.length() + 1)
		if (par_chemin[chemin] as Dictionary).has(cle):
			out[ks] = par_chemin[chemin][cle]
	return out


# --- Définitions des bâtiments créés par les joueurs ----------------------------------------

## Ce qu'il faut savoir d'un type de bâtiment créé dans l'Atelier, l'éditeur libre ou
## l'éditeur du parc pour le construire sur une autre machine ({} : type du jeu).
static func definition(type_id: String) -> Dictionary:
	Creations.ensure_loaded()
	if Creations.items.has(type_id):
		return {"creations": Creations.to_dict([type_id])}
	if ModelesJeu.is_model(type_id):
		var mid := type_id.substr(ModelesJeu.PREFIX.length())
		var d := BanqueModeles.get_model(mid)
		if d.is_empty():
			d = ModelesJeu._from_saves.get(mid, {})
		if not d.is_empty() and String(d.get("genre", "")) == "plan":
			return {"modeles_jeu": {"version": 1, "items": {mid: d}}}
	if AttractionsPerso.is_atr(type_id):
		var aid := type_id.substr(AttractionsPerso.PREFIX.length())
		if AttractionsPerso.designs.has(aid):
			return {"parc_editeur": {"version": 1, "designs": {aid: AttractionsPerso.designs[aid]}}}
	return {}


## Ajoute au catalogue les créations reçues (sans écraser celles déjà connues).
static func adopter(defs: Dictionary) -> void:
	if defs.is_empty():
		return
	if defs.has("creations"):
		Creations.ensure_loaded()
		Creations.merge_dict(defs.creations)
	if defs.has("modeles_jeu"):
		ModelesJeu.adopt(defs.modeles_jeu)
	if defs.has("parc_editeur"):
		AttractionsPerso.adopt(defs.parc_editeur)
