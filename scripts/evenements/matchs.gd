class_name Matchs
extends RefCounted
## Matchs de football au stade.
##
## - Chaque stade de la ville a son club, au nom inventé d'après le lieu de
##   la partie (« FC Annecy », « Annecy Sport »…). Il joue dans une ligue de dix
##   clubs inventés, saison de mi-juillet à fin mai, trêve de mi-décembre à fin
##   janvier : un match à domicile tous les quinze jours, le samedi à 18 h ou
##   le dimanche à 16 h 30.
## - Terrain de football du catalogue : match amateur le dimanche à 10 h.
## - Pendant le match : 22 joueurs, l'arbitre et le ballon sur la pelouse,
##   tribunes remplies selon l'affluence, tableau d'affichage, buts annoncés
##   dans le fil d'actualité. Des habitants fans de foot y vont à pied, à vélo
##   ou en voiture (on les voit arriver), d'autres supporters viennent d'ailleurs.

const ADVERSAIRES := ["FC Rive-Lac", "Olympique des Crêtes", "Racing Val-Rhône", "AS Montbrun", "FC Haute-Ville",
	"Union Saint-Lorin", "SC Bergval", "FC Les Tilleuls", "Étoile de Combe-Noire", "Sporting Port-Avel",
	"AC Pré-Vert", "FC Moraz", "Lions de Valmont", "Stade Bellerive", "US Clairefontaine"]
const MOTIFS := ["FC %s", "%s Sport", "Olympique %s", "AS %s", "Racing %s", "Stade %s"]
const COULEURS := [["c8102e", "f2f2f2"], ["1d3c8f", "f2f2f2"], ["f2c200", "1b1b1b"], ["2a9d8f", "f2f2f2"],
	["6a0dad", "f2f2f2"], ["1b1b1b", "f2f2f2"], ["e76f51", "264653"], ["ff7f11", "1d3557"], ["2e7d32", "f2f2f2"],
	["7a1f2b", "e9c46a"], ["4ea8de", "1d3557"], ["d62828", "003049"]]
const DUREE := 6900.0 # coup d'envoi → coup de sifflet final, mi-temps comprise (s)
const AVANT := 5400.0 # les supporters arrivent 1 h 30 avant

var ev: Evenements
## Clubs : nom -> {nom, force, couleurs, pts, j, g, n, p, bp, bc, ville (bool)}
var clubs: Dictionary = {}
## bid du stade -> nom du club résident
var residents: Dictionary = {}
var saison := ""
var _anim_acc := 0.0


func _init(e: Evenements) -> void:
	ev = e


func clear() -> void:
	clubs.clear()
	residents.clear()
	saison = ""


func _lieu() -> String:
	var n := GameStart.place_name.strip_edges()
	if n == "":
		return "MiniBlocs"
	# « Annecy, Haute-Savoie » → « Annecy ».
	return n.split(",")[0].strip_edges()


## Nom inventé du club d'un stade (le 1er club prend le nom du lieu).
func club_de(bid: int) -> String:
	if residents.has(bid):
		return residents[bid]
	_ensure_league()
	var i := residents.size()
	var motif: String = MOTIFS[(posmod(hash(_lieu()), MOTIFS.size()) + i) % MOTIFS.size()]
	var nom := motif % _lieu()
	if i >= MOTIFS.size():
		nom = "%s %d" % [nom, i]
	var col: Array = COULEURS[posmod(hash(nom), COULEURS.size())]
	clubs[nom] = {"nom": nom, "force": 0.6, "couleurs": col, "pts": 0, "j": 0, "g": 0, "n": 0, "p": 0, "bp": 0, "bc": 0, "ville": true}
	residents[bid] = nom
	return nom


func _ensure_league() -> void:
	if clubs.size() >= 6:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_lieu())
	var pool := ADVERSAIRES.duplicate()
	for i in 9:
		var k := rng.randi() % pool.size()
		var nom: String = pool[k]
		pool.remove_at(k)
		clubs[nom] = {"nom": nom, "force": rng.randf_range(0.35, 0.85), "couleurs": COULEURS[(i + 3) % COULEURS.size()],
			"pts": 0, "j": 0, "g": 0, "n": 0, "p": 0, "bp": 0, "bc": 0, "ville": false}


## Saison « 2026-2027 » du jour (commence en juillet).
static func saison_de(year: int, month: int) -> String:
	var y := year if month >= 7 else year - 1
	return "%d-%d" % [y, y + 1]


static func en_saison(month: int, mday: int) -> bool:
	if month == 6:
		return false
	if month == 7:
		return mday >= 15
	if month == 12:
		return mday <= 14
	if month == 1:
		return false
	return true


func _new_season(s: String) -> void:
	if saison == s:
		return
	if saison != "" and not clubs.is_empty():
		var t := classement()
		ev.news("Fin de la saison %s : %s champion avec %d points !" % [saison, String(t[0].nom), int(t[0].pts)], Vector3.INF, "match")
	saison = s
	for k in clubs:
		var c: Dictionary = clubs[k]
		for f in ["pts", "j", "g", "n", "p", "bp", "bc"]:
			c[f] = 0


func classement() -> Array:
	var out := clubs.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.pts) != int(b.pts):
			return int(a.pts) > int(b.pts)
		return int(a.bp) - int(a.bc) > int(b.bp) - int(b.bc))
	return out


func stades() -> Array:
	var out := []
	for bid in ev.buildings.buildings:
		var b: Dictionary = ev.buildings.buildings[bid]
		if not b.get("chantier", false) and Stades.est_stade(String(b.t)):
			out.append(bid)
	return out


## Matchs du jour (stades et terrains de foot).
func plan_day(n: Dictionary) -> void:
	var day := int(n.day)
	var dt := ev.ambiance.local_datetime() if ev.ambiance != null else {"year": 2026}
	var month := int(n.month)
	var mday := int(n.mday)
	var wd := int(n.wd)
	for bid in stades():
		var t := String(ev.buildings.buildings[bid].t)
		if t == "foot":
			if wd == 0 and ev.population.persons.size() >= 20:
				var amateur := "%s amateurs" % club_de(bid).replace("FC ", "")
				_schedule(bid, day, 10.0, "Match amateur", amateur, "Équipe réserve du coin", false)
			continue
		if not en_saison(month, mday):
			continue
		_new_season(saison_de(int(dt.get("year", 2026)), month))
		# Un samedi (18 h) ou un dimanche (16 h 30) sur deux, à domicile.
		var week := int(floorf((day + 4) / 7.0))
		if (week + bid) % 2 != 0:
			continue
		var home := club_de(bid)
		if wd == 6 and (week / 2) % 2 == 0:
			_schedule(bid, day, 18.0, "Match de championnat", home, _adversaire(home, week), true)
		elif wd == 0 and (week / 2) % 2 == 1:
			_schedule(bid, day, 16.5, "Match de championnat", home, _adversaire(home, week), true)


func _adversaire(home: String, week: int) -> String:
	var others := []
	for k in clubs:
		if k != home:
			others.append(k)
	others.sort()
	return others[posmod(week, others.size())] if not others.is_empty() else "FC Visiteurs"


## Prévoit un match : buts tirés d'avance (minutes), affluence.
func _schedule(bid: int, day: int, hour: float, nom: String, home: String, away: String, ligue: bool) -> int:
	for e in ev.prevus("match") + ev.en_cours("match"):
		if int(e.bid) == bid:
			return -1
	var kick := ev.unix_at(day, hour)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([bid, day, home, away])
	var fh := float(clubs.get(home, {}).get("force", 0.55))
	var fa := float(clubs.get(away, {}).get("force", 0.5))
	var goals := []
	# Environ 2,8 buts par match, avantage à domicile.
	for side in [0, 1]:
		var lam := 1.4 * (fh / maxf(fa, 0.2) if side == 0 else fa / maxf(fh, 0.2)) * (1.15 if side == 0 else 0.9)
		lam = clampf(lam, 0.3, 3.5)
		var k := 0
		var p := exp(-lam)
		var u := rng.randf()
		var cdf := p
		while u > cdf and k < 8:
			k += 1
			p *= lam / k
			cdf += p
		for i in k:
			goals.append({"min": rng.randi_range(1, 90), "side": side})
	goals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.min) < int(b.min))
	var cap := Stades.places(String(ev.buildings.buildings[bid].t))
	var fans := 0
	for pid in ev.population.persons:
		if _goes(ev.population.persons[pid], bid, day):
			fans += 1
	# Supporters venus d'ailleurs : selon le classement et la taille du stade.
	var ext := 0.0
	if ligue:
		ext = cap * clampf(0.25 + fh * 0.5 + rng.randf_range(-0.1, 0.15), 0.1, 0.95)
	else:
		ext = rng.randf_range(10.0, 60.0)
	var aff := mini(cap, fans + int(ext))
	var data := {"home": home, "away": away, "buts": goals, "affluence": aff, "fans": fans, "ligue": ligue, "score": [0, 0], "annonces": 0}
	var pos := Stades.pelouse_monde(ev.buildings, bid).centre as Vector3
	return ev.ajouter("match", "%s : %s – %s" % [nom, home, away], kick - AVANT, kick + DUREE, pos, bid, data)


## Le supporter va-t-il au match ? (fans de foot surtout, quelques curieux)
func _goes(p: Dictionary, bid: int, day: int) -> bool:
	var age := ev.population.age_of(p)
	if age < 6.0:
		return false
	var fan := (p.get("hob", []) as Array).has("football")
	var share := 0.55 if fan else 0.06
	var h := float(posmod(hash(Vector3i(int(p.id), bid, day)), 10000)) / 10000.0
	return h < share


func visit_for(p: Dictionary, e: Dictionary, day: int) -> Dictionary:
	var bid := int(e.bid)
	var off := ev.ambiance.utc_offset() * 3600.0 if ev.ambiance != null else 0.0
	var kick := float(e.debut) + AVANT
	if int(floorf((kick + off) / 86400.0)) != day or not ev.population.known.has(bid):
		return {}
	if not _goes(p, bid, day):
		return {}
	var h := (kick + off) / 3600.0 - day * 24.0
	return {"d": day, "t": h - 1.0, "b": bid, "kind": "loisir", "dur": 2.9,
		"txt": "Au match %s – %s (%s)" % [String(e.data.home), String(e.data.away), ev.building_name(bid)]}


## Minute du match (0 à 90), −1 avant le coup d'envoi, 91 après. Mi-temps : 45.
static func minute(e: Dictionary, t: float) -> float:
	var k := float(e.debut) + AVANT
	var s := (t - k) / 60.0
	if s < 0.0:
		return -1.0
	if s < 47.0:
		return minf(s, 45.0)
	if s < 62.0:
		return 45.0
	if s < 110.0:
		return minf(45.0 + (s - 62.0), 90.0)
	return 91.0


static func periode(e: Dictionary, t: float) -> String:
	var k := float(e.debut) + AVANT
	var s := (t - k) / 60.0
	if s < 0.0:
		return "avant"
	if s < 47.0:
		return "1re mi-temps"
	if s < 62.0:
		return "mi-temps"
	if s < 110.0:
		return "2e mi-temps"
	return "fin"


func on_start(e: Dictionary) -> void:
	_build_visuals(e)
	if bool(e.data.get("ligue", false)):
		ev.news("Ce soir au stade : %s – %s, %d spectateurs attendus." % [String(e.data.home), String(e.data.away), int(e.data.affluence)], e.pos, "match", int(e.id))


func on_end(e: Dictionary) -> void:
	var d: Dictionary = e.data
	var goals: Array = d.buts
	var sh := 0
	var sa := 0
	for g in goals:
		if int(g.side) == 0:
			sh += 1
		else:
			sa += 1
	d.score = [sh, sa]
	if bool(d.get("ligue", false)):
		_record(String(d.home), sh, sa)
		_record(String(d.away), sa, sh)
		# Recette de la billetterie pour la ville (le club loue le stade).
		var gain := int(d.affluence) * 3
		if not ev.buildings.unlimited_money:
			var caisse_prev := Pays.au_point(e.pos.x, e.pos.z)
			ev.buildings.money += gain
			Pays.retour(caisse_prev)
		ev.news("Score final : %s %d – %d %s (%d spectateurs, %s de recettes)." % [String(d.home), sh, sa, String(d.away),
			int(d.affluence), BuildingSystem.format_money(gain)], e.pos, "match", int(e.id))
	else:
		ev.news("Match amateur terminé : %d – %d." % [sh, sa], e.pos, "match", int(e.id))


func _record(club: String, pour: int, contre: int) -> void:
	if not clubs.has(club):
		return
	var c: Dictionary = clubs[club]
	c.j = int(c.j) + 1
	c.bp = int(c.bp) + pour
	c.bc = int(c.bc) + contre
	if pour > contre:
		c.g = int(c.g) + 1
		c.pts = int(c.pts) + 3
	elif pour == contre:
		c.n = int(c.n) + 1
		c.pts = int(c.pts) + 1
	else:
		c.p = int(c.p) + 1
	# La forme du moment joue un peu sur la force.
	c.force = clampf(float(c.force) + (0.02 if pour > contre else (-0.02 if pour < contre else 0.0)), 0.25, 0.95)


## Score au moment t, et annonce des buts marqués depuis la dernière fois.
func step(t: float, delta: float) -> void:
	_anim_acc += delta
	for e in ev.en_cours("match"):
		var d: Dictionary = e.data
		var m := minute(e, t)
		var sh := 0
		var sa := 0
		var n := 0
		for g in d.buts:
			if float(g.min) <= m and m >= 0.0:
				n += 1
				if int(g.side) == 0:
					sh += 1
				else:
					sa += 1
		d.score = [sh, sa]
		if n > int(d.annonces):
			var g: Dictionary = d.buts[n - 1]
			var who := String(d.home) if int(g.side) == 0 else String(d.away)
			if bool(d.ligue):
				ev.news("But de %s ! %s %d – %d %s (%de)." % [who, String(d.home), sh, sa, String(d.away), int(g.min)], e.pos, "match", int(e.id))
			d.annonces = n
		_animate(e, t, delta)


# --- Ce qu'on voit au stade -------------------------------------------------------------

func _build_visuals(e: Dictionary) -> void:
	var bid := int(e.bid)
	if not ev.buildings.buildings.has(bid):
		return
	var pel := Stades.pelouse_monde(ev.buildings, bid)
	var root := Node3D.new()
	root.name = "Match_%d" % int(e.id)
	root.position = pel.centre
	root.basis = pel.basis
	ev.visuels.add_child(root)
	e.node = root
	var d: Dictionary = e.data
	var hc: Array = clubs.get(String(d.home), {}).get("couleurs", ["c8102e", "f2f2f2"])
	var ac: Array = clubs.get(String(d.away), {}).get("couleurs", ["1d3c8f", "f2f2f2"])
	if hc[0] == ac[0]:
		ac = ["f2f2f2", "1b1b1b"]
	var cap := maxi(Stades.places(String(ev.buildings.buildings[bid].t)), 1)
	var fill := clampf(float(d.affluence) / cap, 0.02, 1.0)
	var bol: Vector2 = pel.bol
	var trib: Vector2 = pel.tribune
	if String(ev.buildings.buildings[bid].t) != "foot":
		root.add_child(EvVisuels.spectateurs(bol, trib, fill, [hc[0], hc[0], ac[0]], int(e.id)))
	else:
		# Terrain de foot : quelques spectateurs le long de la main courante.
		var f := EvVisuels.foule(clampi(int(d.affluence) / 4, 6, 40), Vector2(90, 4), int(e.id))
		f.position = Vector3(0, 0, -40)
		root.add_child(f)
	var players := Node3D.new()
	players.name = "Joueurs"
	root.add_child(players)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e.id)
	# 4-4-2 : positions de base (x le long du terrain, vers le but adverse = +x pour l'équipe 0).
	var shape := [Vector2(-48, 0), Vector2(-32, -22), Vector2(-34, -7), Vector2(-34, 7), Vector2(-32, 22),
		Vector2(-12, -24), Vector2(-14, -8), Vector2(-14, 8), Vector2(-12, 24), Vector2(4, -7), Vector2(4, 7)]
	var list := []
	for side in 2:
		var col: Array = hc if side == 0 else ac
		for i in shape.size():
			var base: Vector2 = shape[i]
			if side == 1:
				base = Vector2(-base.x, -base.y)
			var maillot := Color(String(col[0]))
			if i == 0:
				maillot = Color("2ec4b6") if side == 0 else Color("ffbe0b")
			var mi := MeshInstance3D.new()
			mi.mesh = EvVisuels.joueur_mesh(maillot, Color(String(col[1])), EvVisuels.PEAU[rng.randi() % EvVisuels.PEAU.size()])
			mi.position = Vector3(base.x, 0, base.y)
			mi.visibility_range_end = 700.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			players.add_child(mi)
			list.append({"n": mi, "base": base, "side": side, "gk": i == 0})
	var ref := MeshInstance3D.new()
	ref.mesh = EvVisuels.joueur_mesh(Color("1b1b1b"), Color("1b1b1b"), Color("e8b996"))
	ref.visibility_range_end = 700.0
	players.add_child(ref)
	list.append({"n": ref, "base": Vector2(0, 10), "side": 2, "gk": false})
	var ball := MeshInstance3D.new()
	ball.mesh = EvVisuels.ballon_mesh()
	ball.visibility_range_end = 400.0
	root.add_child(ball)
	# Tableau d'affichage au-dessus d'une tribune.
	var lbl := Label3D.new()
	lbl.name = "Tableau"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 96
	lbl.pixel_size = 0.06
	lbl.outline_size = 18
	lbl.modulate = Color("fff3b0")
	lbl.position = Vector3(0, maxf(trib.y, 6.0) + 10.0, -(bol.y + trib.x * 0.6))
	lbl.no_depth_test = false
	lbl.visibility_range_end = 1500.0
	root.add_child(lbl)
	e.anim = {"list": list, "ball": ball, "bp": Vector2.ZERO, "bt": Vector2.ZERO, "label": lbl, "players": players, "attack": 0}


func _animate(e: Dictionary, t: float, delta: float) -> void:
	var a: Dictionary = e.get("anim", {})
	if a.is_empty():
		_build_visuals(e)
		a = e.get("anim", {})
		if a.is_empty():
			return
	var d: Dictionary = e.data
	var per := periode(e, t)
	var lbl: Label3D = a.label
	var m := minute(e, t)
	var sc: Array = d.score
	var tag := "Coup d'envoi à %s" % ev.heure_courte(float(e.debut) + AVANT) if per == "avant" else ("Mi-temps" if per == "mi-temps" else ("Terminé" if per == "fin" else "%d'" % int(m)))
	lbl.text = "%s  %d – %d  %s\n%s" % [String(d.home), int(sc[0]), int(sc[1]), String(d.away), tag]
	var players: Node3D = a.players
	var playing := per == "1re mi-temps" or per == "2e mi-temps"
	players.visible = per != "avant" and per != "fin"
	(a.ball as Node3D).visible = playing
	if not players.visible:
		return
	# Animation au rythme réel (pas du temps de jeu) : le match reste lisible.
	var dt := clampf(delta, 0.0, 0.1)
	var bp: Vector2 = a.bp
	var bt: Vector2 = a.bt
	if playing:
		if bp.distance_to(bt) < 1.5:
			var side := 1.0 if int(a.attack) == 0 else -1.0
			if ev.rng.randf() < 0.18:
				a.attack = 1 - int(a.attack)
			bt = Vector2(clampf(bp.x + side * ev.rng.randf_range(4.0, 22.0), -50.0, 50.0), ev.rng.randf_range(-30.0, 30.0))
			a.bt = bt
		bp = bp.move_toward(bt, dt * 11.0)
	else:
		bp = Vector2.ZERO
	a.bp = bp
	(a.ball as Node3D).position = Vector3(bp.x, 0.12 + absf(sin(t * 0.0 + Time.get_ticks_msec() * 0.006)) * 0.15, bp.y)
	for pl in a.list:
		var node: MeshInstance3D = pl.n
		var base: Vector2 = pl.base
		var target: Vector2
		if not playing:
			# Mi-temps : tout le monde rentre au vestiaire (on les cache un moment).
			target = Vector2(0, -30.0)
		elif int(pl.side) == 2:
			target = bp + Vector2(-8, 10)
		elif bool(pl.gk):
			target = Vector2(base.x, clampf(bp.y * 0.15, -6.0, 6.0))
		else:
			var pull := 0.35 if (int(pl.side) == 0) == (int(a.attack) == 0) else 0.25
			target = base.lerp(bp, pull) + Vector2(bp.x * 0.3, 0)
		var cur := Vector2(node.position.x, node.position.z)
		var nxt := cur.move_toward(target, dt * 7.0)
		var dir := nxt - cur
		node.position = Vector3(nxt.x, 0.0, nxt.y)
		if dir.length() > 0.001:
			node.rotation.y = atan2(-dir.x, -dir.y)
		elif playing:
			var look := bp - nxt
			node.rotation.y = atan2(-look.x, -look.y)


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var res := {}
	for bid in residents:
		res[str(bid)] = residents[bid]
	return {"clubs": clubs.duplicate(true), "residents": res, "saison": saison}


func from_dict(d: Dictionary) -> void:
	clear()
	clubs = (d.get("clubs", {}) as Dictionary).duplicate(true)
	for k in clubs:
		var c: Dictionary = clubs[k]
		for f in ["pts", "j", "g", "n", "p", "bp", "bc"]:
			c[f] = int(c.get(f, 0))
		c.force = float(c.get("force", 0.5))
	for k in (d.get("residents", {}) as Dictionary):
		residents[int(k)] = String(d.residents[k])
	saison = String(d.get("saison", ""))
