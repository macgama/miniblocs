class_name GenresAuto
extends RefCounted
## Mode gestion : genres « en kit » (zoo, école, gare, musée, mairie, stades,
## fermes… et tous ceux qui suivent), décrits en quelques lignes et montés
## ici en vrai genre de GestionTypes.
##
## Une fiche (SPECS des fichiers genres_*.gd) dit seulement :
## - "accueil" : le hall d'entrée, sur toute la largeur, côté rue ;
## - "pieces" : les salles du fond, de gauche à droite ("w" : largeur) ;
## - "dehors" : ce qui est hors les murs (enclos, terrain, champs), en
##   colonnes à droite du bâtiment ("w", "d") ;
## - "objets" : par pièce, [id, nom, modèle, prix, niveau, effets, poses] ;
## - "demandes" : [pièce, texte, pourboire] ; "pannes" ; "evenements" ;
## - l'argent : "panier" (€ par visiteur à prix normal), "public" (budget
##   versé par la ville), "base_fn" (visiteurs de base calculés à part) ;
## - l'époque et le pays : "annee" d'une pièce ou d'un objet (voir aussi
##   GestionEpoques.MODELES), "noms_pays", "noms_epoque".
## Le plan (rectangles, portes, chemins, postes, poses des objets) se calcule
## tout seul ; le genre monté est gardé en cache (refait si l'année ou le
## pays de la partie changent : les noms suivent).

const PROF := 9.0
const PROF_ACCUEIL := 7.0
const ECART := 2.5

static var _cache := {}
static var _specs := {}


## Toutes les fiches connues : genre → fiche.
static func specs() -> Dictionary:
	if _specs.is_empty():
		for src in [GenresHaute.SPECS, GenresMoyenne.SPECS, GenresBasse.SPECS]:
			_specs.merge(src)
	return _specs


static func connu(g: String) -> bool:
	return specs().has(g)


## Genre monté (vide si inconnu).
static func genre(g: String) -> Dictionary:
	var s: Dictionary = specs().get(g, {})
	if s.is_empty():
		return {}
	var cle := "%s|%d" % [GestionEpoques.pays(), _tranche(s)]
	var c: Dictionary = _cache.get(g, {})
	if not c.is_empty() and String(c.cle) == cle:
		return c.gd
	var gd := construire(g, s)
	_cache[g] = {"cle": cle, "gd": gd}
	return gd


## Tranche d'époque qui change les noms (index dans "noms_epoque").
static func _tranche(s: Dictionary) -> int:
	var an := GestionEpoques.annee()
	var i := 0
	for e in s.get("noms_epoque", []):
		if an <= int(e[0]):
			return i
		i += 1
	return i


static func vider_cache() -> void:
	_cache.clear()


# --- Rattachement des bâtiments -------------------------------------------------------------------

## Genre « en kit » d'un type de bâtiment ("" : aucun).
static var _de := {}


static func genre_de(type_id: String) -> String:
	if _de.has(type_id):
		return _de[type_id]
	var g := _chercher(type_id)
	_de[type_id] = g
	return g


static func _chercher(type_id: String) -> String:
	var base := BuildingCatalog.base_of(type_id)
	for g in specs():
		var s: Dictionary = specs()[g]
		if base in (s.get("types", []) as Array) or type_id in (s.get("types", []) as Array):
			return String(g)
	for g in specs():
		var s: Dictionary = specs()[g]
		for pre in s.get("prefixes", []):
			if base.begins_with(String(pre)) or type_id.begins_with(String(pre)):
				return String(g)
		for suf in s.get("suffixes", []):
			if type_id.ends_with(String(suf)) or base.ends_with(String(suf)):
				return String(g)
	return ""


## Visiteurs de base calculés à part ("base_fn" d'une fiche).
static func base_speciale(g: Gestion, bid: int, fn: String) -> float:
	var t := BuildingCatalog.get_type(g.type_of(bid))
	match fn:
		"places":
			# Stades et salles : les places du bâtiment (ou de l'Atelier).
			var p := float(t.get("visiteurs", 0))
			if p <= 0.0:
				p = float(t.get("emplois", 20)) * 300.0
			return p
	return 0.0


## Chiffres réels de la veille quand l'établissement a déjà son système :
## {clients, cap, recettes} ({} : rien, la gestion compte elle-même).
static func reel(g: Gestion, bid: int, fn: String) -> Dictionary:
	match fn:
		"zoo":
			var z := ZooSysteme.instance
			if z == null or not is_instance_valid(z) or not z.zoos.has(bid):
				return {}
			var h: Dictionary = z.zoos[bid].hier
			return {"clients": float(h.get("visiteurs", 0)), "recettes": float(h.get("billets", 0.0)) + float(h.get("stands", 0.0))}
		"musee":
			var m := Musee.instance
			if m == null or not is_instance_valid(m):
				return {}
			for key in m.musees:
				if m.bid_of(String(key)) == bid:
					var h: Dictionary = m.musees[key].hier
					return {"clients": float(h.get("visiteurs", 0)), "recettes": float(h.get("billets", 0.0)) + float(h.get("boutique", 0.0)) + float(h.get("cafe", 0.0))}
	return {}


## Part des visiteurs de base qui viennent ce jour-là (jours de match…).
static func facteur_jour(g: Gestion, bid: int, gd: Dictionary) -> float:
	var m: Dictionary = gd.get("matchs", {})
	if m.is_empty():
		return 1.0
	var tous := maxi(1, int(m.get("tous", 7)))
	if (g.jour + bid) % tous == 0:
		return 1.0
	return float(m.get("autres", 0.05))


static func jour_fort(g: Gestion, bid: int, gd: Dictionary) -> bool:
	var m: Dictionary = gd.get("matchs", {})
	return not m.is_empty() and (g.jour + bid) % maxi(1, int(m.get("tous", 7))) == 0


# --- Montage du genre -------------------------------------------------------------------------------

static func construire(g: String, s: Dictionary) -> Dictionary:
	var gd := {}
	for k in s:
		if not String(k) in ["accueil", "pieces", "dehors", "objets", "demandes", "pannes", "types", "prefixes", "suffixes"]:
			gd[k] = s[k]
	gd["source"] = "lieu"
	gd["auto"] = true
	var prof := float(s.get("prof", PROF))
	var pa := float(s.get("prof_accueil", PROF_ACCUEIL))
	var dedans: Array = s.get("pieces", [])
	var largeur := 0.0
	for p in dedans:
		largeur += float(p.get("w", 6.0))
	var lmin := float(s.get("largeur_min", 14.0))
	var etire := 1.0 if largeur >= lmin else lmin / maxf(1.0, largeur)
	largeur = maxf(largeur, lmin)
	var plan := Vector2(largeur, prof + pa)
	gd["plan"] = plan
	gd["porte"] = Vector2(snappedf(largeur * 0.5, 0.5), plan.y)
	var comptoir := Vector2(largeur * 0.5 - 2.4, prof + 1.9)
	gd["comptoir"] = comptoir
	gd["file"] = Vector2(comptoir.x, prof + 3.1)
	gd["hall"] = Vector2(largeur * 0.5 + 1.6, prof + 3.4)
	gd["murs"] = String(s.get("murs", "efe7d8"))
	gd["murs_dehors"] = String(s.get("murs_dehors", "b98b6a"))
	var pieces := {}
	var ordre: Array = []
	var activites: Array = []
	# Le hall d'entrée.
	var a: Dictionary = (s.get("accueil", {}) as Dictionary).duplicate(true)
	var aid := String(a.get("id", "accueil"))
	gd["accueil"] = aid
	a.erase("id")
	a["rect"] = [0.0, prof, largeur, pa]
	a["base"] = 1
	_completer(a, 0.004)
	if not a.has("postes"):
		var ps: Array = []
		for i in (a.get("metiers", []) as Array).size():
			ps.append([comptoir.x - 0.8 + i * 1.6, prof + 0.9, 0.0])
		a["postes"] = ps
	pieces[aid] = a
	ordre.append(aid)
	activites.append([aid, float(a.get("part", 0.08))])
	# Les salles du fond, de gauche à droite.
	var x := 0.0
	for p0 in dedans:
		var p: Dictionary = (p0 as Dictionary).duplicate(true)
		var pid := String(p.id)
		p.erase("id")
		var w := float(p.get("w", 6.0)) * etire
		p["rect"] = [x, 0.0, w, prof]
		p["porte"] = [snappedf(x + w * 0.5, 0.1), prof]
		_completer(p, 0.004)
		if not p.has("postes"):
			var ps: Array = []
			var nm := (p.get("metiers", []) as Array).size()
			for i in nm:
				ps.append([x + w * (0.3 + 0.4 * float(i) / maxf(1.0, float(nm - 1)) if nm > 1 else 0.7), prof * 0.38, PI if i % 2 == 0 else 0.0])
			p["postes"] = ps
		pieces[pid] = p
		ordre.append(pid)
		activites.append([pid, float(p.get("part", 0.12))])
		x += w
	gd["pieces"] = pieces
	# Le dehors : colonnes à droite du bâtiment, allée le long de la façade.
	var dehors := {}
	var porte_d := Vector2(largeur, prof + pa * 0.5)
	var hmax := plan.y + 7.0
	var col_x := largeur + ECART
	var col_w := 0.0
	var z := 0.0
	var fonds: Array = []
	var cols: Array = []
	for p0 in s.get("dehors", []):
		var p: Dictionary = (p0 as Dictionary).duplicate(true)
		var pid := String(p.id)
		p.erase("id")
		var w := float(p.get("w", 10.0))
		var d := float(p.get("d", 9.0))
		if z > 0.0 and z + d > hmax:
			col_x += col_w + 2.0
			col_w = 0.0
			z = 0.0
		p["rect"] = [col_x, z, w, d]
		cols.append([pid, col_x, z, w, d])
		fonds.append(z + d)
		col_w = maxf(col_w, w)
		z += d + 1.0
		_completer(p, 0.006)
		dehors[pid] = p
		ordre.append(pid)
		activites.append([pid, float(p.get("part", 0.15))])
	var bas := plan.y + 1.4
	for f in fonds:
		bas = maxf(bas, float(f) + 1.2)
	for c in cols:
		var p: Dictionary = dehors[String(c[0])]
		var cx := float(c[1])
		var cz := float(c[2]) + float(c[4]) * 0.5
		p["porte"] = [porte_d.x, porte_d.y]
		if cx <= largeur + ECART + 0.01:
			p["chemin"] = [[largeur + 1.0, porte_d.y], [largeur + 1.0, cz], [cx + 0.6, cz]]
		else:
			p["chemin"] = [[largeur + 1.0, porte_d.y], [largeur + 1.0, bas], [cx - 1.0, bas], [cx - 1.0, cz], [cx + 0.6, cz]]
		if not p.has("postes"):
			var ps: Array = []
			for i in (p.get("metiers", []) as Array).size():
				ps.append([cx + float(c[3]) * (0.25 + 0.5 * i), float(c[2]) + float(c[4]) * 0.3, PI * 0.5])
			p["postes"] = ps
	gd["dehors"] = dehors
	gd["ordre"] = ordre
	var tout := pieces.duplicate()
	tout.merge(dehors)
	if not gd.has("activites"):
		gd["activites"] = activites
	# Objets : poses calculées le long des murs de chaque pièce.
	var objets := {}
	var src_o: Dictionary = s.get("objets", {})
	for pid in src_o:
		if not tout.has(pid):
			continue
		var r: Array = tout[pid].rect
		var slots := _slots(r, pid == aid, comptoir, dehors.has(pid))
		var i := 0
		var od := {}
		for o in src_o[pid]:
			var n := int(o[6]) if (o as Array).size() > 6 else 1
			var poses: Array = []
			for j in n:
				if i < slots.size():
					poses.append(slots[i])
				i += 1
			var e: Dictionary = (o[5] as Dictionary) if (o as Array).size() > 5 else {}
			od[String(o[0])] = {"nom": String(o[1]), "modele": String(o[2]), "poses": poses, "prix": float(o[3]), "niv": int(o[4]), "effets": e}
			if (o as Array).size() > 7:
				od[String(o[0])].merge(o[7] as Dictionary, true)
		objets[pid] = od
	gd["objets"] = objets
	var dem: Array = []
	var n_d := 0
	for d in s.get("demandes", []):
		n_d += 1
		dem.append({"id": "%s_%d" % [g, n_d], "piece": String(d[0]), "texte": String(d[1]), "pourboire": int(d[2]) if (d as Array).size() > 2 else 2})
	gd["demandes"] = dem
	# Pannes : celles de la fiche, sinon des pannes ordinaires (dedans, dehors).
	var pn: Dictionary = (s.get("pannes", {}) as Dictionary).duplicate(true)
	for pid in ordre:
		if not pn.has(pid):
			pn[pid] = ["Clôture abîmée", "Éclairage en panne"] if dehors.has(pid) else ["Lumière en panne", "Fuite d'eau"]
	gd["pannes"] = pn
	if not gd.has("pensees"):
		gd["pensees"] = {"regle": ["Merci !", "Très bien accueilli.", "On reviendra."], "rate": ["Personne pour m'aider…", "Je repars, tant pis."]}
	if not gd.has("chip_txt"):
		gd["chip_txt"] = "%s / %s " + String(s.get("unite", "visiteurs"))
		gd["chip"] = String(s.get("chip", "habitants"))
		gd["chip_tip"] = "Visiteurs d'hier / ce que %s peut accueillir par jour." % String(s.get("le", "l'établissement"))
	# Le pays et l'époque : noms des pièces et titre.
	var np: Dictionary = (s.get("noms_pays", {}) as Dictionary).get(GestionEpoques.pays(), {})
	var ne := {}
	var an := GestionEpoques.annee()
	for e in s.get("noms_epoque", []):
		if an <= int(e[0]):
			ne = e[1]
			break
	for src in [np, ne]:
		for k in src:
			if String(k) != "pieces":
				gd[k] = src[k]
		for pid in (src.get("pieces", {}) as Dictionary):
			if tout.has(pid):
				tout[pid]["nom"] = String(src.pieces[pid])
				tout[pid]["court"] = String(src.pieces[pid]).split(" (")[0]
	return gd


## Valeurs par défaut d'une pièce.
static func _completer(p: Dictionary, prix: float) -> void:
	if not p.has("court"):
		p["court"] = String(p.get("nom", "")).split(" (")[0]
	if not p.has("max"):
		p["max"] = 5
	if not p.has("base"):
		p["base"] = 0
	if not p.has("prix"):
		p["prix"] = prix
	if not p.has("metiers"):
		p["metiers"] = []
	if not p.has("effets"):
		p["effets"] = {"attrait": 0.02, "confort": 0.03, "entretien": 20.0}
	if not p.has("sol"):
		p["sol"] = "d9cfbd"
	if not p.has("motif"):
		p["motif"] = "parquet"
	if not p.has("desc"):
		p["desc"] = ""


## Emplacements des objets d'une pièce (relatifs à son coin), le long des
## murs : d'abord le fond, puis la gauche, la droite et le devant.
static func _slots(r: Array, accueil: bool, comptoir: Vector2, dehors: bool) -> Array:
	var w := float(r[2])
	var d := float(r[3])
	var out: Array = []
	var m := 0.75
	var pas := 1.7
	if accueil:
		# Le hall : le long des murs de côté et du devant, loin de la porte et du comptoir.
		var cx := comptoir.x - float(r[0])
		var xx := m
		while xx < w - m:
			if absf(xx - w * 0.5) > 2.6 and absf(xx - cx) > 2.2:
				out.append([xx, d - 0.7, PI])
			xx += pas
		var zz := 1.2
		while zz < d - 1.0:
			out.append([0.6, zz, PI * 0.5])
			out.append([w - 0.6, zz, -PI * 0.5])
			zz += pas
		return out
	if dehors:
		var xx := 1.0
		while xx < w - 0.8:
			out.append([xx, 0.8, 0.0])
			xx += pas + 0.5
		var zz := 2.4
		while zz < d - 0.8:
			out.append([w - 0.8, zz, -PI * 0.5])
			zz += pas + 0.5
		return out
	var x := m
	while x < w - m + 0.01:
		out.append([x, 0.6, 0.0])
		x += pas
	var z := 1.9
	while z < d - 2.0:
		out.append([0.55, z, PI * 0.5])
		out.append([w - 0.55, z, -PI * 0.5])
		z += pas
	# Devant : de part et d'autre de la porte.
	for xf in [m, w - m]:
		if absf(xf - w * 0.5) > 1.6:
			out.append([xf, d - 0.6, PI])
	return out
