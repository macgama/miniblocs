class_name FetesMarches
extends RefCounted
## Marchés et fêtes de quartier.
##
## - Automatiques (réglage Admin « Fêtes, marchés et matchs organisés tout
##   seuls ») : marché chaque samedi de 7 h à 13 h sur la plus grande place de
##   la ville (sinon devant la mairie ou un commerce) dès 30 habitants ; fête de
##   quartier le 2e samedi de mai à septembre (15 h – 23 h), fête de la musique
##   le 21 juin au soir.
## - Organisés par le joueur (panneau Infos, I) : il choisit un marché ou une
##   fête et clique où il veut les poser. Ils commencent tout de suite.
## - Des habitants libres y vont (leur journée change, on les voit marcher), le
##   marché rapporte des droits de place à la ville, la fête coûte un peu.

const MARCHE_HEURES := Vector2(7.0, 13.0)
const FETE_HEURES := Vector2(15.0, 23.0)
const MUSIQUE_HEURES := Vector2(18.0, 24.0)
const PLACES := ["place_pavee", "piazza", "place_moderne", "square", "kiosque_musique"]
const COUT_FETE := 8_000
const COUT_MARCHE := 2_000
const DROIT_PLACE := 60

var ev: Evenements


func _init(e: Evenements) -> void:
	ev = e


## Place du marché : la plus grande place publique, sinon la mairie, un commerce.
func lieu_marche() -> int:
	var best := -1
	var score := -1.0
	for bid in ev.buildings.buildings:
		var b: Dictionary = ev.buildings.buildings[bid]
		if b.get("chantier", false):
			continue
		var t := BuildingCatalog.get_type(String(b.t))
		var keys := Metiers.keys_of(String(b.t))
		var s := -1.0
		for k in PLACES:
			if keys.has(k):
				s = 100.0 + float(t.get("visiteurs", 0))
		if s < 0.0 and keys.has("mairie"):
			s = 50.0
		if s < 0.0 and String(t.get("cat", "")) == "commerce" and int(t.get("visiteurs", 0)) > 0:
			s = 10.0 + float(t.get("visiteurs", 0)) * 0.001
		if s > score:
			score = s
			best = bid
	return best


func _habitants() -> int:
	return ev.population.persons.size() if ev.population != null else 0


## Événements automatiques du jour.
func plan_day(n: Dictionary) -> void:
	if _habitants() < 30:
		return
	var day := int(n.day)
	# Déjà prévu aujourd'hui (jour revu après un chargement) : rien de plus.
	for e in ev.events.values():
		if bool(e.get("auto", false)) and String(e.type) in ["marche", "fete"] and absf(float(e.debut) - ev.unix_at(day, 12.0)) < 43200.0:
			return
	var wd := int(n.wd)
	var month := int(n.month)
	var mday := int(n.mday)
	if wd == 6:
		var lieu := lieu_marche()
		if lieu >= 0:
			var pos := ev.building_pos(lieu)
			ev.ajouter("marche", "Marché du samedi", ev.unix_at(day, MARCHE_HEURES.x), ev.unix_at(day, MARCHE_HEURES.y),
				_devant(lieu, pos), lieu, {"etals": _nb_etals()})
		if month >= 5 and month <= 9 and mday >= 8 and mday <= 14:
			var q := _quartier()
			if q >= 0:
				ev.ajouter("fete", "Fête de quartier", ev.unix_at(day, FETE_HEURES.x), ev.unix_at(day, FETE_HEURES.y),
					_devant(q, ev.building_pos(q)), q, {})
	if month == 6 and mday == 21:
		var lieu2 := lieu_marche()
		if lieu2 >= 0:
			ev.ajouter("fete", "Fête de la musique", ev.unix_at(day, MUSIQUE_HEURES.x), ev.unix_at(day, MUSIQUE_HEURES.y),
				_devant(lieu2, ev.building_pos(lieu2)), lieu2, {"musique": true})


func _nb_etals() -> int:
	return clampi(4 + _habitants() / 150, 4, 24)


## Un quartier d'habitation au hasard (bâtiment avec des logements habités).
func _quartier() -> int:
	var list := []
	for bid in ev.population.by_home:
		if not (ev.population.by_home[bid] as Array).is_empty():
			list.append(bid)
	if list.is_empty():
		return -1
	return list[ev.rng.randi() % list.size()]


## Point devant un bâtiment, côté rue (le décor ne cache pas l'entrée), ou sur la place elle-même.
func _devant(bid: int, pos: Vector3) -> Vector3:
	var b: Dictionary = ev.buildings.buildings.get(bid, {})
	if b.is_empty():
		return pos
	var keys := Metiers.keys_of(String(b.t))
	for k in PLACES:
		if keys.has(k):
			return pos
	var rect := ev.buildings._rect_of(b)
	var front := BuildingSystem.front_dir(int(b.r))
	var depth := float(rect.size.y if int(b.r) % 2 == 0 else rect.size.x)
	var p := pos + front * (depth * 0.5 + 9.0)
	p.y = ev.ground(p.x, p.z)
	return p


## Le joueur organise un marché ou une fête à cet endroit (tout de suite).
func organiser(type: String, pos: Vector3) -> int:
	var cout := ReglagesPartie.prix(COUT_FETE if type == "fete" else COUT_MARCHE)
	if not ev._payer(cout, "organiser"):
		return -1
	var t := ev.now()
	var duree := (FETE_HEURES.y - FETE_HEURES.x) if type == "fete" else (MARCHE_HEURES.y - MARCHE_HEURES.x)
	var bid := ev.nearest_known(pos, 350.0)
	var nom := "Fête organisée par la ville" if type == "fete" else "Marché organisé par la ville"
	var id := ev.ajouter(type, nom, t, t + duree * 3600.0, pos, bid, {"etals": _nb_etals(), "joueur": true}, false)
	ev.news("%s : %s (%s)." % [nom, "c'est parti !", BuildingSystem.format_money(cout)], pos, type, id)
	return id


func on_start(e: Dictionary) -> void:
	var pos: Vector3 = e.pos
	var root := Node3D.new()
	root.name = "%s_%d" % [String(e.type), int(e.id)]
	root.position = pos
	var seed := int(e.id) * 7919
	var dec: Node3D
	var visitors := 0
	if String(e.type) == "marche":
		var n := int(e.data.get("etals", 6))
		dec = EvVisuels.marche(n, seed)
		visitors = clampi(n * 3, 8, 70)
		root.add_child(EvVisuels.foule(visitors, Vector2(n * 1.6 + 8.0, n * 1.2 + 8.0), seed))
	else:
		dec = EvVisuels.fete(seed)
		visitors = clampi(12 + _habitants() / 40, 12, 80)
		root.add_child(EvVisuels.foule(visitors, Vector2(16, 14), seed, Vector3(0, 0, -9)))
	root.add_child(dec)
	# Le décor suit le bâtiment voisin (tourné vers la rue).
	var b: Dictionary = ev.buildings.buildings.get(int(e.bid), {})
	if not b.is_empty():
		root.rotation.y = -int(b.r) * PI / 2.0 + float(b.get("a", 0.0))
	ev.visuels.add_child(root)
	e.node = root
	e.data.visiteurs = visitors
	var lieu := ev.building_name(int(e.bid)) if int(e.bid) >= 0 else "en ville"
	if bool(e.get("auto", true)):
		ev.news("%s : ça commence (%s)." % [String(e.nom), lieu], pos, String(e.type), int(e.id))


func on_end(e: Dictionary) -> void:
	var n := habitants_venus(e)
	if String(e.type) == "marche":
		var gain := int(e.data.get("etals", 6)) * DROIT_PLACE
		if not ev.buildings.unlimited_money:
			var caisse_prev := Pays.au_point(e.pos.x, e.pos.z)
			ev.buildings.money += gain
			Pays.retour(caisse_prev)
		ev.news("%s terminé : %d habitants venus, %s de droits de place." % [String(e.nom), n, BuildingSystem.format_money(gain)], e.pos, "marche", int(e.id))
	else:
		ev.news("%s terminée : %d habitants venus." % [String(e.nom), n], e.pos, "fete", int(e.id))


func step(_t: float, _delta: float) -> void:
	pass


## Certains habitants libres y passent : {t, b, kind, dur, txt, d} pour Population._apply_order.
func visit_for(p: Dictionary, e: Dictionary, day: int) -> Dictionary:
	var off := ev.ambiance.utc_offset() * 3600.0 if ev.ambiance != null else 0.0
	var d0 := int(floorf((float(e.debut) + off) / 86400.0))
	if d0 != day or int(e.bid) < 0 or not ev.population.known.has(int(e.bid)):
		return {}
	var age := ev.population.age_of(p)
	if age < 4.0:
		return {}
	var home := ev.population.home_of(p)
	if not ev.population.known.has(home):
		return {}
	var dist := (ev.population.known[home].pos as Vector3).distance_to(e.pos)
	var share := 0.0
	if String(e.type) == "marche":
		share = 0.3 if dist < 1500.0 else (0.12 if dist < 4000.0 else 0.0)
	else:
		share = 0.45 if dist < 500.0 else (0.12 if dist < 2000.0 else 0.0)
	if share <= 0.0:
		return {}
	var h := float(posmod(hash(Vector2i(int(p.id), int(e.id))), 10000)) / 10000.0
	if h > share:
		return {}
	var h0 := (float(e.debut) + off) / 3600.0 - day * 24.0
	var h1 := (float(e.fin) + off) / 3600.0 - day * 24.0
	var start := lerpf(h0, maxf(h0, h1 - 1.5), fposmod(h * 7.31, 1.0))
	var txt := "Au marché" if String(e.type) == "marche" else String(e.nom)
	return {"d": day, "t": start, "b": int(e.bid), "kind": "loisir", "dur": 1.0 if String(e.type) == "marche" else 2.5,
		"txt": "%s (%s)" % [txt, ev.building_name(int(e.bid))]}


## Nombre d'habitants qui ont prévu d'y aller (même tirage que visit_for).
func habitants_venus(e: Dictionary) -> int:
	var off := ev.ambiance.utc_offset() * 3600.0 if ev.ambiance != null else 0.0
	var day := int(floorf((float(e.debut) + off) / 86400.0))
	var n := 0
	for pid in ev.population.persons:
		if not visit_for(ev.population.persons[pid], e, day).is_empty():
			n += 1
	return n
