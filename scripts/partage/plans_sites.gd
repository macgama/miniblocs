class_name PlansSites
extends RefCounted
## Plans de site : une zone entière de la carte (un parc de loisirs, un zoo,
## un quartier, une place) enregistrée pour être reposée ailleurs ou partagée.
##
## On choisit un rectangle sur la carte ; le plan garde ce qui est dedans :
## - les bâtiments entièrement dedans (type, rotation, angle, variante,
##   personnalisation), y compris les modèles de l'Atelier (mdl_), les
##   créations en blocs (crea_) et les attractions dessinées (atr_) ;
## - les allées du parc et les files d'attente (ParcAllees) ;
## - les enclos du zoo, leur barrière et leurs animaux (espèce, sexe) ;
## - les décors posés à la main (DecorSystem.poses) ;
## - les bâtiments en murs fins libres (meublés : musées, maisons…) ;
## - les blocs libres de l'éditeur (hors toits des murs fins).
##
## Reposé : chaque bâtiment passe par BuildingSystem.place (prix, accès,
## terrassement, chantier), les enclos et les animaux se paient, les décors et
## les allées sont offerts. Ce qui ne trouve pas sa place est compté à part.
## R tourne le plan d'un quart de tour, sauf s'il contient des murs fins ou des
## blocs libres (ils ne tournent pas encore).
##
## Bibliothèque commune à toutes les parties : user://plans_sites.json.
## Coordonnées : en mètres depuis le coin −x −z du rectangle.
##
## ctx : {bs, world, allees, zoo, decors, mob, blocks}, chacun facultatif sauf bs.

const PATH := "user://plans_sites.json"
const FORMAT := "miniblocs-site"
const VERSION := 1
const MAX_SIDE := 400
## Bâtiments au plus dans un plan.
const MAX_BATIMENTS := 600

static var persist := true
static var items: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	items.clear()
	if not persist or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for id in (d as Dictionary).get("items", {}):
			var p: Variant = d.items[id]
			if p is Dictionary and valide(p):
				items[String(id)] = p


static func _write() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": VERSION, "items": items}))


static func valide(p: Dictionary) -> bool:
	return String(p.get("format", "")) == FORMAT and String(p.get("id", "")) != "" and int(p.get("version", 0)) <= VERSION \
		and int(p.get("w", 0)) > 0 and int(p.get("d", 0)) > 0 and int(p.w) <= MAX_SIDE and int(p.d) <= MAX_SIDE


static func ids() -> Array:
	ensure_loaded()
	var out := items.keys()
	out.sort_custom(func(a, b) -> bool: return float(items[a].get("cree", 0.0)) > float(items[b].get("cree", 0.0)))
	return out


static func get_plan(id: String) -> Dictionary:
	ensure_loaded()
	return items.get(id, {})


static func remove(id: String) -> void:
	ensure_loaded()
	items.erase(id)
	_write()


static func rename(id: String, nom: String) -> void:
	ensure_loaded()
	if items.has(id) and nom.strip_edges() != "":
		items[id]["nom"] = nom.strip_edges()
		_write()


## Ajoute (ou remplace) un plan reçu. Rend son id, ou "".
static func installer(p: Dictionary, remplacer := false) -> String:
	ensure_loaded()
	if not valide(p):
		return ""
	var id := String(p.id)
	if items.has(id) and not remplacer:
		return id
	items[id] = p.duplicate(true)
	_write()
	return id


# --- Enregistrer une zone -------------------------------------------------------------------

static func _inside(rect: Rect2i, x: float, z: float) -> bool:
	return x >= rect.position.x and z >= rect.position.y and x <= rect.end.x and z <= rect.end.y


## Lit ce que contient le rectangle. Rend le plan (sans l'enregistrer).
static func lire_zone(ctx: Dictionary, rect: Rect2i, nom: String) -> Dictionary:
	var o := rect.position
	var bs: BuildingSystem = ctx.get("bs")
	var bats := []
	var index := {} # bid -> rang dans bats
	if bs != null:
		var bids := bs.buildings.keys()
		bids.sort()
		for bid in bids:
			var b: Dictionary = bs.buildings[bid]
			var br := Rect2i(Vector2i(int(b.x), int(b.z)), BuildingCatalog.footprint(String(b.t), int(b.r)))
			if not rect.encloses(br) or bats.size() >= MAX_BATIMENTS:
				continue
			var e := {"t": String(b.t), "x": br.position.x - o.x, "z": br.position.y - o.y, "r": int(b.r), "a": snappedf(float(b.get("a", 0.0)), 0.0001)}
			if b.has("v"):
				e["v"] = int(b.v)
			if not (b.get("perso", {}) as Dictionary).is_empty():
				e["perso"] = (b.perso as Dictionary).duplicate(true)
			index[int(bid)] = bats.size()
			bats.append(e)
	var allees := []
	var files := []
	var pa: ParcAllees = ctx.get("allees")
	if pa != null:
		for s in pa.allees:
			var a: Vector2 = s.a
			var b2: Vector2 = s.b
			if _inside(rect, a.x, a.y) and _inside(rect, b2.x, b2.y):
				allees.append([snappedf(a.x - o.x, 0.01), snappedf(a.y - o.y, 0.01), snappedf(b2.x - o.x, 0.01), snappedf(b2.y - o.y, 0.01), float(s.l), String(s.g)])
		for fi in pa.files:
			if not index.has(int(fi.bid)):
				continue
			var pts := []
			var ok := true
			for q: Vector2 in fi.pts:
				ok = ok and _inside(rect, q.x, q.y)
				pts.append([snappedf(q.x - o.x, 0.01), snappedf(q.y - o.y, 0.01)])
			if ok:
				files.append({"b": index[int(fi.bid)], "pts": pts})
	var enclos := []
	var zoo: ZooSysteme = ctx.get("zoo")
	if zoo != null:
		var eids := zoo.enclos.keys()
		eids.sort()
		for eid in eids:
			var e: Dictionary = zoo.enclos[eid]
			var pts := []
			var ok := true
			for q in (e.pts as PackedVector2Array):
				ok = ok and _inside(rect, q.x, q.y)
				pts.append([snappedf(q.x - o.x, 0.01), snappedf(q.y - o.y, 0.01)])
			if not ok:
				continue
			var an := []
			for aid in zoo.animaux_de(int(eid)):
				an.append([String(zoo.animaux[aid].esp), 1 if bool(zoo.animaux[aid].f) else 0])
			enclos.append({"nom": String(e.nom), "barriere": String(e.barriere), "pts": pts, "animaux": an})
	var decors := []
	var dec: DecorSystem = ctx.get("decors")
	if dec != null:
		for k in dec.poses:
			for r: Array in dec.poses[k]:
				if _inside(rect, float(r[1]), float(r[3])):
					decors.append([String(r[0]), snappedf(float(r[1]) - o.x, 0.01), snappedf(float(r[3]) - o.y, 0.01), float(r[4]), float(r[5])])
	var murs := []
	var zones_murs: Array[Rect2i] = []
	var mob: Mobilier = ctx.get("mob")
	if mob != null and mob.pe != null:
		for pid in mob.pe.plans:
			var bb: Rect2i = mob.pe._bbox.get(pid, Rect2i())
			if bb.size == Vector2i.ZERO or not rect.intersects(bb):
				continue
			zones_murs.append(bb.grow(2))
			# Les murs fins d'un modèle posé viennent avec son bâtiment (ModelesVisites).
			if mob.linked.has(pid) or not rect.encloses(bb):
				continue
			var data := BanqueModeles.plan_data(mob, String(pid), mob.plan_name(String(pid)))
			if not data.is_empty():
				murs.append({"x": bb.position.x - o.x, "z": bb.position.y - o.y, "plan": data})
	var blocs := []
	var be: BlockEditor = ctx.get("blocks")
	var world: TerrainWorld = ctx.get("world")
	var y_ref := _y_ref(world, rect)
	if be != null:
		for k in be.blocks:
			var kk: Vector3i = k
			var c := Vector2i(kk.x, kk.z)
			if not rect.has_point(c):
				continue
			var pris := false
			for z in zones_murs:
				if z.has_point(c):
					pris = true
					break
			if not pris:
				blocs.append_array([kk.x - o.x, kk.y - y_ref, kk.z - o.y, int(be.blocks[k])])
	var nm := nom.strip_edges()
	var p := {"format": FORMAT, "version": VERSION, "id": _new_id(nm), "nom": nm, "auteur": PaquetPartage.auteur(),
		"cree": Time.get_unix_time_from_system(), "w": rect.size.x, "d": rect.size.y,
		"batiments": bats, "allees": allees, "files": files, "enclos": enclos, "decors": decors, "murs": murs, "blocs": blocs}
	p["sorte"] = sorte_de(p)
	if nm == "":
		p.nom = {"parc": "Mon parc", "zoo": "Mon zoo", "musee": "Mon musée"}.get(p.sorte, "Mon quartier")
	return p


## Enregistre la zone dans la bibliothèque. Rend {ok, id, resume} ou {ok: false, reason}.
static func capture(ctx: Dictionary, rect: Rect2i, nom: String) -> Dictionary:
	ensure_loaded()
	if rect.size.x < 2 or rect.size.y < 2:
		return {"ok": false, "reason": "Zone trop petite."}
	if rect.size.x > MAX_SIDE or rect.size.y > MAX_SIDE:
		return {"ok": false, "reason": "Zone trop grande : %d m de côté au maximum." % MAX_SIDE}
	var p := lire_zone(ctx, rect, nom)
	if est_vide(p):
		return {"ok": false, "reason": "Rien à enregistrer dans cette zone (bâtiments, allées, enclos, décors, murs ou blocs)."}
	items[String(p.id)] = p
	_write()
	return {"ok": true, "id": p.id, "resume": resume(p)}


static func est_vide(p: Dictionary) -> bool:
	for k in ["batiments", "allees", "enclos", "decors", "murs", "blocs"]:
		if not (p.get(k, []) as Array).is_empty():
			return false
	return true


static func _new_id(nom: String) -> String:
	var slug := nom.to_lower().strip_edges().validate_filename().replace(" ", "_").left(24)
	return "site_%s%d_%d" % [slug + "_" if slug != "" else "", int(Time.get_unix_time_from_system()), randi() % 10000]


static func _y_ref(world: TerrainWorld, rect: Rect2i) -> int:
	if world == null:
		return 0
	return floori(world.cell_height(rect.get_center()) / BlockEditor.UNIT_Y)


## parc, zoo, musee ou quartier : d'après ce qu'il contient.
static func sorte_de(p: Dictionary) -> String:
	if not (p.get("enclos", []) as Array).is_empty():
		return "zoo"
	var parc := 0
	var musee := 0
	for b: Dictionary in p.get("batiments", []):
		var t := BuildingCatalog.get_type(String(b.t))
		if t.has("parc") or AttractionsPerso.is_atr(String(b.t)):
			parc += 1
		if BuildingCatalog.base_of(String(b.t)).begins_with("musee"):
			musee += 1
	for m: Dictionary in p.get("murs", []):
		if String((m.plan as Dictionary).get("usage", "")) == "musee":
			musee += 1
	if parc > 0 or not (p.get("allees", []) as Array).is_empty():
		return "parc"
	if musee > 0:
		return "musee"
	return "quartier"


static func nom_sorte(s: String) -> String:
	return {"parc": "Parc de loisirs", "zoo": "Zoo", "musee": "Musée", "quartier": "Quartier"}.get(s, "Plan de site")


static func resume(p: Dictionary) -> String:
	var parts := ["%d × %d m" % [int(p.w), int(p.d)]]
	var n := (p.get("batiments", []) as Array).size()
	if n > 0:
		parts.append(("%d bâtiments" if n > 1 else "%d bâtiment") % n)
	var na := 0
	for e: Dictionary in p.get("enclos", []):
		na += (e.get("animaux", []) as Array).size()
	var ne := (p.get("enclos", []) as Array).size()
	if ne > 0:
		parts.append(("%d enclos, %d animaux" if na > 1 else "%d enclos, %d animal") % [ne, na])
	var nal := (p.get("allees", []) as Array).size()
	if nal > 0:
		parts.append(("%d allées" if nal > 1 else "%d allée") % nal)
	var nm := (p.get("murs", []) as Array).size()
	if nm > 0:
		parts.append("%d en murs fins" % nm)
	var nd := (p.get("decors", []) as Array).size()
	if nd > 0:
		parts.append(("%d décors" if nd > 1 else "%d décor") % nd)
	var nb := (p.get("blocs", []) as Array).size() / 4
	if nb > 0:
		parts.append("%d blocs" % nb)
	return " · ".join(parts)


## Prix estimé (bâtiments, barrières, animaux), réglages de la partie compris.
static func prix(p: Dictionary) -> int:
	var total := 0
	for b: Dictionary in p.get("batiments", []):
		if not BuildingCatalog.get_type(String(b.t)).is_empty():
			total += ReglagesPartie.prix(BuildingCatalog.cost(String(b.t)))
	for e: Dictionary in p.get("enclos", []):
		var pts := _pts(e.get("pts", []), Vector2.ZERO, 0, 0, 0)
		total += int(ZooSysteme.perimetre(pts) * float(ZooEspeces.barriere(String(e.get("barriere", "grillage"))).get("prix_m", 0.0)))
		for a: Array in e.get("animaux", []):
			total += int(ZooEspeces.espece(String(a[0])).get("prix", 0))
	return total


## Types de bâtiment du plan inconnus de cette partie (dépendance manquante).
static func manquants(p: Dictionary) -> Array:
	var out := []
	for b: Dictionary in p.get("batiments", []):
		var t := String(b.t)
		if BuildingCatalog.get_type(t).is_empty() and not t in out:
			out.append(t)
	return out


## Types personnalisés dont le plan a besoin, rangés par genre
## (modeles : id du modèle, creations : id de la création, attractions : id du dessin).
static func dependances(p: Dictionary) -> Dictionary:
	var out := {"modeles": [], "creations": [], "attractions": []}
	for b: Dictionary in p.get("batiments", []):
		var t := String(b.t)
		if ModelesJeu.is_model(t):
			var mid := t.substr(ModelesJeu.PREFIX.length())
			if not mid in out.modeles:
				out.modeles.append(mid)
		elif AttractionsPerso.is_atr(t):
			var aid := t.substr(AttractionsPerso.PREFIX.length())
			if not aid in out.attractions:
				out.attractions.append(aid)
		elif Creations.items.has(t) or t.begins_with("crea_"):
			if not t in out.creations:
				out.creations.append(t)
	return out


static func peut_tourner(p: Dictionary) -> bool:
	return (p.get("murs", []) as Array).is_empty() and (p.get("blocs", []) as Array).is_empty()


# --- Rotation --------------------------------------------------------------------------------

## Taille du plan tourné de q quarts de tour.
static func taille(p: Dictionary, q: int) -> Vector2i:
	return Vector2i(int(p.d), int(p.w)) if q % 2 == 1 else Vector2i(int(p.w), int(p.d))


## Un point du plan (m depuis son coin) tourné de q quarts de tour, comme les
## bâtiments (rotation.y = −r·π/2) : (x, z) → (d − z, x) à chaque quart.
static func tourne(v: Vector2, w: float, d: float, q: int) -> Vector2:
	var p := v
	var cw := w
	var cd := d
	for i in posmod(q, 4):
		p = Vector2(cd - p.y, p.x)
		var t := cw
		cw = cd
		cd = t
	return p


static func _pts(arr: Array, o: Vector2, w: int, d: int, q: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for a: Array in arr:
		out.append(tourne(Vector2(float(a[0]), float(a[1])), w, d, q) + o)
	return out


## Emprise d'un bâtiment du plan, une fois tourné et posé en o.
static func rect_batiment(b: Dictionary, p: Dictionary, o: Vector2i, q: int) -> Rect2i:
	var t := String(b.t)
	var r := int(b.r)
	var fp := BuildingCatalog.footprint(t, r) if not BuildingCatalog.get_type(t).is_empty() else Vector2i(1, 1)
	var c := Vector2(float(b.x) + fp.x / 2.0, float(b.z) + fp.y / 2.0)
	var c2 := tourne(c, float(p.w), float(p.d), q)
	var fp2 := BuildingCatalog.footprint(t, posmod(r + q, 4)) if not BuildingCatalog.get_type(t).is_empty() else fp
	var pos := Vector2i(roundi(c2.x - fp2.x / 2.0), roundi(c2.y - fp2.y / 2.0))
	return Rect2i(pos + o, fp2)


# --- Reposer ---------------------------------------------------------------------------------

## Pose le plan avec son coin −x −z en o, tourné de q quarts de tour.
## Rend {ok, poses, refus, raisons, cout}.
static func poser(p: Dictionary, o: Vector2i, q: int, ctx: Dictionary) -> Dictionary:
	var bs: BuildingSystem = ctx.get("bs")
	if bs == null:
		return {"ok": false, "reason": "Pas de ville ici."}
	if bs.verrou_reseau:
		return {"ok": false, "reason": "Les plans de site ne se posent pas encore dans une carte entre amis."}
	if not peut_tourner(p):
		q = 0
	q = posmod(q, 4)
	var manque := manquants(p)
	var res := {"ok": true, "poses": 0, "refus": 0, "raisons": [], "cout": 0}
	var money0 := bs.money
	var w := int(p.w)
	var d := int(p.d)
	var ov := Vector2(o)
	# Bâtiments (dans l'ordre : les entrées de parc et de zoo d'abord, si elles y sont).
	var nouveaux := {} # rang -> bid
	var bats: Array = p.get("batiments", [])
	for i in bats.size():
		var b: Dictionary = bats[i]
		var t := String(b.t)
		if t in manque:
			_refus(res, "%s : bâtiment inconnu de cette partie" % t)
			continue
		var rr := rect_batiment(b, p, o, q)
		var r2 := posmod(int(b.r) + q, 4)
		var center := rr.position + BuildingCatalog.footprint(t, r2) / 2
		var bid := bs.place(t, center, r2, 0, float(b.get("a", 0.0)))
		if bid < 0:
			_refus(res, "%s : pas de place" % String(BuildingCatalog.get_type(t).get("name", t)))
			continue
		nouveaux[i] = bid
		res.poses += 1
		var perso: Dictionary = b.get("perso", {})
		if perso.size() > 0 or (b.has("v") and int(b.v) != int(bs.buildings[bid].get("v", -1))):
			bs.set_perso(bid, Personnalisation.clean(perso), int(b.get("v", -1)))
	# Allées et files d'attente.
	var pa: ParcAllees = ctx.get("allees")
	if pa != null:
		for s: Array in p.get("allees", []):
			var a := tourne(Vector2(float(s[0]), float(s[1])), w, d, q) + ov
			var b2 := tourne(Vector2(float(s[2]), float(s[3])), w, d, q) + ov
			if pa.ajoute_allee(a, b2, String(s[5]), float(s[4])):
				res.poses += 1
		for fi: Dictionary in p.get("files", []):
			var rang := int(fi.get("b", -1))
			if not nouveaux.has(rang):
				continue
			var pts := _pts(fi.get("pts", []), ov, w, d, q)
			if pts.size() >= 2:
				pa.files.append({"bid": int(nouveaux[rang]), "pts": Array(pts)})
		pa._change()
	elif not (p.get("allees", []) as Array).is_empty():
		_refus(res, "allées du parc : pas d'éditeur de parc ici")
	# Enclos et animaux.
	var zoo: ZooSysteme = ctx.get("zoo")
	for e: Dictionary in p.get("enclos", []):
		if zoo == null:
			_refus(res, "enclos : pas de zoo ici")
			break
		var pts := _pts(e.get("pts", []), ov, w, d, q)
		var eid := zoo.ajouter_enclos(pts, String(e.get("barriere", "grillage")))
		if eid < 0:
			_refus(res, "enclos « %s » : pas posé" % String(e.get("nom", "")))
			continue
		zoo.renommer_enclos(eid, String(e.get("nom", "Enclos")))
		res.poses += 1
		for a: Array in e.get("animaux", []):
			if zoo.acheter(String(a[0]), eid, int(a[1])) < 0:
				_refus(res, "animal (%s) : pas acheté" % String(a[0]))
	# Décors.
	var dec: DecorSystem = ctx.get("decors")
	if dec != null:
		for r: Array in p.get("decors", []):
			var at := tourne(Vector2(float(r[1]), float(r[2])), w, d, q) + ov
			if dec.pose(String(r[0]), at.x, at.y, float(r[3]) - q * PI / 2.0, float(r[4])):
				res.poses += 1
	# Murs fins (sans rotation).
	var mob: Mobilier = ctx.get("mob")
	for m: Dictionary in p.get("murs", []):
		if mob == null:
			_refus(res, "murs fins : pas d'éditeur ici")
			break
		var r := BanqueModeles._place_plan(m.plan, o + Vector2i(int(m.x), int(m.z)), mob)
		if bool(r.get("ok", false)):
			res.poses += 1
		else:
			_refus(res, "%s : %s" % [String((m.plan as Dictionary).get("nom", "murs fins")), String(r.get("error", "pas posé"))])
	# Blocs libres.
	var be: BlockEditor = ctx.get("blocks")
	var ba: Array = p.get("blocs", [])
	if be != null and not ba.is_empty():
		var y_ref := _y_ref(ctx.get("world"), Rect2i(o, Vector2i(w, d)))
		var i := 0
		var n := 0
		while i + 3 < ba.size():
			var k := Vector3i(int(ba[i]) + o.x, int(ba[i + 1]) + y_ref, int(ba[i + 2]) + o.y)
			if not be.blocks.has(k):
				be._put_block(k, int(ba[i + 3]))
				n += 1
			i += 4
		if n > 0:
			be.changed.emit()
			res.poses += 1
	res.cout = maxi(0, money0 - bs.money)
	res.ok = res.poses > 0
	if not res.ok and res.raisons.is_empty():
		res["reason"] = "Rien n'a pu être posé ici."
	elif not res.ok:
		res["reason"] = String(res.raisons[0])
	return res


## Carte entre amis : l'action qui demande au serveur de poser le plan p (origine o,
## quart de tour q), avec les créations des joueurs dont ses bâtiments ont besoin.
static func action_reseau(p: Dictionary, o: Vector2i, q: int) -> Dictionary:
	var defs := []
	var vus := {}
	for b: Dictionary in p.get("batiments", []):
		var t := String(b.get("t", ""))
		if vus.has(t):
			continue
		vus[t] = true
		var d := SectionsPartagees.definition(t)
		if not d.is_empty():
			defs.append(d)
	return {"t": "site", "plan": p, "o": o, "q": q, "defs": defs}


## Le résultat d'une pose en une phrase.
static func bilan(res: Dictionary) -> String:
	if not bool(res.get("ok", false)):
		return "Impossible de poser ici : %s." % String(res.get("reason", "?"))
	var t := "Plan posé : %d éléments pour %s." % [int(res.poses), BuildingSystem.format_money(int(res.cout))]
	if int(res.refus) > 0:
		t += " " + ("Refusés : %d (%s)." % [int(res.refus), ", ".join((res.raisons as Array).slice(0, 2))])
	return t


static func _refus(res: Dictionary, why: String) -> void:
	res.refus += 1
	if (res.raisons as Array).size() < 8:
		(res.raisons as Array).append(why)
