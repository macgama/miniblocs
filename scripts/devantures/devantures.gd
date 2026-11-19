class_name Devantures
extends Node3D
## Devantures vivantes : ce que chaque bâtiment montre côté rue, près de la caméra.
##
## - Vitrine : la façade est creusée au rez-de-chaussée (boîtes « trous » du
##   matériau des bâtiments, voir batiment.gdshader) et une vraie petite
##   boutique y prend place : présentoir, étagères, comptoir, caisse. Les objets
##   exposés sont ceux que le commerce vend (Ressources.COMMERCES), en quantité
##   réelle : le palier de chaque objet suit le stock du commerce (Production).
##   Rupture = vitrine vide et affichette.
## - Intérieur : le vendeur (un employé présent) est derrière son comptoir, les
##   clients présents (Population.present_in) devant ; s'ils sont trop nombreux,
##   ils font la queue dehors. Visible à travers la vitre en vue au sol (V) et
##   de près en vue de dessus.
## - Devanture : enseigne au nom du commerce (nom du patron, sinon nom tiré au
##   sort), store banne qui se déplie quand c'est ouvert et qu'il fait jour,
##   ardoise du jour, étal sur le trottoir, terrasse des cafés par beau temps,
##   lumière le soir (plafonniers, néons, halo sur le trottoir).
## - Tous les bâtiments : hall éclairé et enseigne des services, bureaux,
##   hôtels et loisirs ; enseigne et marchandise empilée devant les entreprises
##   (stock produit) ; plaque au nom de la famille, lampe et jardinières des
##   logements.
## - Époque (Epoques.annee) : bois et petits carreaux, lampe à pétrole, store
##   rayé, néon, aluminium, grands vitrages (DevanturesTypes.style).
##
## Rien n'est sauvegardé : tout se déduit de l'état de la ville.

## Vitrines creusées et contenu jusqu'à cette distance du point regardé (m).
const VUE := 80.0
## Enseignes et plaques jusqu'à cette distance.
const VUE_ENSEIGNE := 170.0
## Au-delà de ce recul de la caméra (vue de dessus), seules les enseignes restent.
const ZOOM_DETAILS := 120.0
const ZOOM_ENSEIGNES := 260.0
## Au plus 16 façades creusées à la fois (uniformes du matériau).
const MAX_NICHES := 16
const MAX_LUMIERES := 6
const MAX_FIGURINES := 48
const MAX_DEDANS := 3
const MAX_QUEUE := 6
const REFRESH := 0.5

static var instance: Devantures

var pop: Population
var buildings: BuildingSystem
var production: Production
var ambiance: DayNight
var rig: Node3D
## Vue métiers : ses figurines ne sont pas montrées deux fois.
var metiers: MetiersVivants
var enabled := true

## bid -> état (nœuds créés, clés des maillages)
var _etat: Dictionary = {}
## pid -> Figurine
var _figs: Dictionary = {}
var _timer := 0.0
var _t := 0.0
## Ce qui est montré au dernier rafraîchissement (tests, captures) :
## [{bid, genre, nom, niche, paliers, objets, store, terrasse, clients, queue, vendeur, lumiere}]
var montres: Array = []
## Boîtes creusées au dernier rafraîchissement : [[Transform3D, demi-tailles]].
var trous: Array = []


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	NightWindows.set_trous([])


func setup(p: Population, b: BuildingSystem, prod: Production, amb: DayNight, camera_rig: Node3D) -> void:
	pop = p
	buildings = b
	production = prod
	ambiance = amb
	rig = camera_rig
	buildings.removed.connect(func(bid: int) -> void: _oublier(bid))


## Ce bâtiment a-t-il en ce moment une vitrine creusée (MetiersVivants laisse
## alors la pancarte et le rideau aux devantures) ?
func a_niche(bid: int) -> bool:
	return _etat.has(bid) and bool(_etat[bid].get("a_niche", false)) and (_etat[bid].root as Node3D).visible


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_tout_cacher()
	else:
		_timer = 0.0


func _process(delta: float) -> void:
	if pop == null or buildings == null:
		return
	_t += EchelleTemps.dt(delta)
	if not enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		refresh()
	for pid in _figs:
		var f: Figurine = _figs[pid]
		if f.visible:
			f.animer(_t)


# --- Où regarde-t-on ? ---------------------------------------------------------------------

func _au_sol() -> bool:
	return pop != null and pop.vue_sol != null and pop.vue_sol.vue != VueSol.Vue.DESSUS


func _focus() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if _au_sol() and cam != null:
		return cam.global_position
	if rig != null:
		return rig.global_position
	return cam.global_position if cam != null else Vector3.ZERO


func _recul() -> float:
	if _au_sol():
		return 0.0
	if rig != null and "_distance" in rig:
		return float(rig.get("_distance"))
	return 0.0


# --- Rafraîchissement ------------------------------------------------------------------------

func refresh() -> void:
	montres.clear()
	var recul := _recul()
	if recul > ZOOM_ENSEIGNES:
		_tout_cacher()
		return
	var details := recul <= ZOOM_DETAILS
	var focus := _focus()
	var f2 := Vector2(focus.x, focus.z)
	var proches := []
	for bid in buildings.buildings:
		var node := buildings.node_of(bid)
		if node == null:
			continue
		var p := node.global_position
		var d := Vector2(p.x, p.z).distance_to(f2)
		if d <= VUE_ENSEIGNE:
			proches.append([d, bid])
	proches.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
	var annee := Epoques.annee()
	var st := DevanturesTypes.style(annee)
	var ctx := {
		"annee": annee, "st": st, "soir": _soir(), "heure": ambiance.local_hour() if ambiance != null else 12.0,
		"pluie": _pluie(), "chaud": _temperature() >= 10.0, "jour": int((ambiance.unix_time if ambiance != null else 0.0) / 86400.0),
		"niches": 0, "lumieres": 0,
	}
	var vus := {}
	var figs_vues := {}
	trous.clear()
	for e in proches:
		var bid := int(e[1])
		var d := float(e[0])
		vus[bid] = true
		_batiment(bid, d, details and d <= VUE, ctx, figs_vues)
	for bid in _etat.keys():
		if not vus.has(bid):
			_oublier(bid)
	for pid in _figs.keys():
		if not figs_vues.has(pid):
			(_figs[pid] as Node).queue_free()
			_figs.erase(pid)
	NightWindows.set_trous(trous)


func _soir() -> bool:
	return ambiance != null and ambiance.night > 0.35


func _pluie() -> float:
	if ambiance == null or ambiance.weather == null:
		return 0.0
	return float(ambiance.weather.precip)


func _temperature() -> float:
	if ambiance == null or ambiance.weather == null:
		return 18.0
	return float(ambiance.weather.temperature)


## Un bâtiment : enseigne, et de près sa vitrine, son store, sa terrasse…
func _batiment(bid: int, d: float, proche: bool, ctx: Dictionary, figs_vues: Dictionary) -> void:
	var b: Dictionary = buildings.buildings[bid]
	var type_id := String(b.t)
	var p := DevanturesTypes.profil(type_id)
	var node := buildings.node_of(bid)
	if p.is_empty() or node == null or node.mesh == null or not node.visible or buildings.en_chantier(bid):
		_cacher(bid)
		return
	var st: Dictionary = ctx.st
	var s: Dictionary = _etat.get(bid, {})
	if s.is_empty():
		s = {"root": Node3D.new()}
		(s.root as Node3D).name = "Devanture_%d" % bid
		add_child(s.root)
		_etat[bid] = s
	var root: Node3D = s.root
	root.visible = true
	var g := _geometrie(node, p)
	root.global_transform = node.global_transform * Transform3D(Basis.IDENTITY, g.origine)
	var genre := String(p.genre)
	var ouvert := _ouvert(bid, genre, float(ctx.heure))
	var info := {"bid": bid, "genre": genre, "type": type_id, "niche": false, "ouvert": ouvert, "nom": "",
		"objets": [], "paliers": [], "store": "", "terrasse": 0, "clients": 0, "queue": 0, "vendeur": -1, "lumiere": false,
		"etal": false, "ardoise": "", "rupture": false}
	# Enseigne (toujours, tant qu'on est assez près).
	var nom := _nom(bid, type_id, p)
	info.nom = nom
	_enseigne(s, g, p, nom, st, ouvert and bool(ctx.soir))
	var niche := proche and bool(g.niche) and int(ctx.niches) < MAX_NICHES
	s["a_niche"] = niche
	if not proche:
		_masquer(s, ["niche", "vitres", "contenu", "store", "nom_store", "terrasse", "etal", "ardoise", "texte_ardoise", "affichette", "logis", "stock", "lum", "potence", "rideau", "pancarte"])
		montres.append(info)
		return
	# Logements : plaque, lampe d'entrée, jardinières.
	if genre == DevanturesTypes.LOGIS:
		_logis(s, g, ctx)
		_masquer(s, ["niche", "vitres", "contenu", "store", "nom_store", "terrasse", "etal", "ardoise", "texte_ardoise", "affichette", "stock", "lum", "potence", "rideau", "pancarte"])
		info.lumiere = bool(ctx.soir)
		montres.append(info)
		return
	_masquer(s, ["logis"])
	# Entreprises : marchandise empilée devant, selon le stock produit.
	if genre == DevanturesTypes.ENTREPRISE:
		var pal := DevanturesTypes.palier(_remplissage_sortie(bid))
		var objs := DevanturesTypes.objets_a(p, int(ctx.annee))
		info.objets = objs
		info.paliers = [pal]
		if float(g.cour) >= 1.6 and pal > 0:
			var mi := _mi(s, "stock")
			mi.mesh = DevanturesModeles.stock_dehors(objs, pal, float(g.l) * 0.5)
			mi.position = Vector3(-float(g.l) * 0.25, 0, -float(g.cour) * 0.5 + 1.2)
			mi.visible = true
		else:
			_masquer(s, ["stock"])
		_masquer(s, ["niche", "vitres", "contenu", "store", "nom_store", "terrasse", "etal", "ardoise", "texte_ardoise", "affichette", "lum", "potence", "rideau", "pancarte"])
		montres.append(info)
		return
	_masquer(s, ["stock"])
	# Vitrine creusée dans la façade.
	var w := float(g.w)
	var h := float(g.h)
	var dp := float(g.d)
	var allume := bool(ctx.soir) and (ouvert or float(ctx.heure) < 22.5)
	if niche:
		ctx.niches = int(ctx.niches) + 1
		info.niche = true
		var centre := Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5 + 0.06, dp * 0.5 - 0.06))
		trous.append([root.global_transform * centre, Vector3(w * 0.5 - 0.02, h * 0.5, dp * 0.5 + 0.08)])
		var fond := Color(String(p.fond))
		var mn := _mi(s, "niche")
		mn.mesh = DevanturesModeles.coquille(w, h, dp, fond, st, genre)
		mn.visible = true
		_allumer(mn, allume)
		var mv := _mi(s, "vitres")
		mv.mesh = DevanturesModeles.vitres(w, h, genre)
		mv.visible = true
		var mc := _mi(s, "contenu")
		match genre:
			DevanturesTypes.BOUTIQUE:
				var objs := DevanturesTypes.objets_a(p, int(ctx.annee))
				var pals := []
				for o in objs:
					pals.append(DevanturesTypes.palier(_remplissage(bid, p, String(o), ouvert)))
				info.objets = objs
				info.paliers = pals
				mc.mesh = DevanturesModeles.boutique(w, h, dp, objs, pals, int(ctx.annee))
				var vide: bool = not (p.vend as Array).is_empty() and int(pals.max()) == 0
				info.rupture = vide
				_affichette(s, w, h, vide, p)
			DevanturesTypes.SALLE:
				mc.mesh = DevanturesModeles.salle(w, h, dp, int(ctx.annee), 1.0)
				_affichette(s, w, h, false, p)
			_:
				mc.mesh = DevanturesModeles.hall(w, h, dp, String(p.get("accueil", "accueil")), int(ctx.annee), Color(String(p.fond)))
				_affichette(s, w, h, false, p)
		mc.visible = true
		_allumer(mc, allume)
		# Halo sur le trottoir le soir (les plus proches seulement).
		if allume and int(ctx.lumieres) < MAX_LUMIERES:
			ctx.lumieres = int(ctx.lumieres) + 1
			var l: OmniLight3D = s.get("lum")
			if l == null:
				l = OmniLight3D.new()
				l.omni_range = 7.0
				l.light_energy = 1.4
				l.shadow_enabled = false
				root.add_child(l)
				s["lum"] = l
			l.light_color = st.lumiere
			l.position = Vector3(0, h * 0.6, 0.6)
			l.visible = true
			info.lumiere = true
		else:
			_masquer(s, ["lum"])
		_gens(bid, s, root, w, dp, genre, info, figs_vues)
		_rideau_et_pancarte(s, w, h, genre, ouvert, allume, int(ctx.annee), info)
	else:
		_masquer(s, ["niche", "vitres", "contenu", "affichette", "lum", "rideau", "pancarte"])
		info.lumiere = allume
	# Store banne.
	if bool(st.store) and p.has("store") and genre != DevanturesTypes.ENTREPRISE:
		var deplie := ouvert and not bool(ctx.soir) and float(ctx.pluie) < 0.7 and float(ctx.heure) >= 7.0 and float(ctx.heure) < 20.5
		var ms := _mi(s, "store")
		ms.mesh = DevanturesModeles.store(w, h, Color(String(p.store)), deplie, String(st.id) != "moderne")
		ms.visible = true
		info.store = "deplie" if deplie else "replie"
		# Le nom peint sur le lambrequin : lisible même quand le store cache le bandeau.
		if deplie and nom != "":
			var ln := _label(s, "nom_store", 48, 0.004)
			ln.text = nom.to_upper() if String(st.id) != "ancien" else nom
			ln.pixel_size = clampf((w * 0.8) / maxf(float(nom.length()) * 27.0, 1.0), 0.0018, 0.004)
			ln.modulate = Color("f4f1e8") if Color(String(p.store)).get_luminance() < 0.6 else Color("2b2b2b")
			ln.outline_size = 0
			ln.position = DevanturesModeles.lambrequin(w, h)
			ln.rotation = Vector3(0, PI, 0)
			ln.visible = true
		else:
			_masquer(s, ["nom_store"])
	else:
		_masquer(s, ["store", "nom_store"])
	# Enseigne en potence (époques anciennes).
	if bool(st.enseigne_potence) and genre == DevanturesTypes.BOUTIQUE:
		var mp := _mi(s, "potence")
		mp.mesh = DevanturesModeles.potence(Color(String(p.get("store", "7f5539"))), st.cadre)
		mp.position = Vector3(w * 0.5 + 0.2, h + 0.5, 0)
		mp.visible = true
	else:
		_masquer(s, ["potence"])
	# Terrasse des cafés : ouverts, sans pluie, assez doux.
	var terrasse := genre == DevanturesTypes.SALLE and bool(p.get("terrasse", false)) and ouvert \
		and float(ctx.pluie) < 0.25 and bool(ctx.chaud) and float(g.cour) + 1.5 >= 1.8
	if terrasse:
		var n := clampi(int(w / 1.6), 1, 4)
		var mt := _mi(s, "terrasse")
		mt.mesh = DevanturesModeles.terrasse(w, n, int(ctx.annee), not bool(ctx.soir))
		mt.visible = true
		info.terrasse = n
		_clients_terrasse(bid, s, root, w, n, info, figs_vues)
	else:
		_masquer(s, ["terrasse"])
	# Étal sur le trottoir.
	if bool(p.get("dehors", false)) and ouvert and float(ctx.pluie) < 0.6:
		var objs2 := DevanturesTypes.objets_a(p, int(ctx.annee))
		var pal2 := 4
		if not (info.paliers as Array).is_empty():
			pal2 = int((info.paliers as Array).max())
		var me := _mi(s, "etal")
		me.mesh = DevanturesModeles.etal(objs2, pal2, w)
		me.visible = pal2 > 0
		info.etal = pal2 > 0
	else:
		_masquer(s, ["etal"])
	# Ardoise du jour.
	var phrase := DevanturesTypes.ardoise(p, int(ctx.jour), bid)
	if phrase != "" and ouvert and not bool(ctx.soir):
		var ma := _mi(s, "ardoise")
		ma.mesh = DevanturesModeles.ardoise()
		ma.position = Vector3(DevanturesModeles.porte_x(w) - 1.3, 0, -0.9)
		ma.rotation = Vector3(0, PI + 0.25, 0)
		ma.visible = true
		var lt := _label(s, "texte_ardoise", 40, 0.0038)
		lt.text = phrase
		lt.modulate = Color("f4f1e8")
		lt.outline_size = 0
		lt.width = 215.0
		lt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Collée sur la face avant du tableau (même inclinaison que lui).
		lt.transform = ma.transform * Transform3D(Basis(Vector3.RIGHT, 0.19), Vector3(0, 0.66, -0.11)) * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.02))
		lt.visible = true
		info.ardoise = phrase
	else:
		_masquer(s, ["ardoise", "texte_ardoise"])
	montres.append(info)


## Où et comment creuser la vitrine dans un modèle (repère du bâtiment).
func _geometrie(node: MeshInstance3D, p: Dictionary) -> Dictionary:
	var bb := BatimentsVie.body_bounds(node.mesh)
	var genre := String(p.genre)
	var l := bb.size.x
	var cx := bb.get_center().x
	var z0 := bb.position.z
	var w := clampf(l * 0.62, 2.6, 7.5)
	w = minf(w, l - 0.8)
	var h := clampf(bb.size.y * 0.42, 2.8, 3.4)
	var d := clampf(bb.size.z * 0.4, 1.8, 3.4)
	var niche := genre in [DevanturesTypes.BOUTIQUE, DevanturesTypes.SALLE, DevanturesTypes.HALL] \
		and bb.size.y >= 3.8 and l >= 3.4 and bb.size.z >= 3.2 and w >= 2.6
	# Cour devant la façade : entre le modèle et le bord de la parcelle.
	var t := BuildingCatalog.get_type(String(p.get("type", "")))
	var cour := maxf(z0 + float(t.get("d", 0.0)) * 0.5, 0.0) if not t.is_empty() else 0.0
	return {"origine": Vector3(cx, 0.0, z0), "w": w, "h": h, "d": d, "l": l, "haut": bb.size.y, "niche": niche, "cour": cour}


# --- Économie : ouverture et stock -------------------------------------------------------------

func _ouvert(bid: int, genre: String, heure: float) -> bool:
	if genre == DevanturesTypes.LOGIS:
		return true
	var eff := pop.effectif
	if eff != null and eff.concerne(bid):
		return eff.ouvert_maintenant(bid)
	# Sans personnel suivi : heures d'ouverture habituelles.
	return heure >= 8.0 and heure < 19.5


## Remplissage (0 à 1) de l'objet `o` dans la vitrine d'un commerce.
func _remplissage(bid: int, p: Dictionary, o: String, ouvert: bool) -> float:
	var vend: Array = p.get("vend", [])
	if vend.is_empty() or production == null or not production.sites.has(bid):
		# Commerce que l'économie ne suit pas (fleuriste, librairie…) : vitrine garnie.
		return 1.0 if ouvert else 0.8
	var bien := String(DevanturesTypes.BIEN_D_OBJET.get(o, ""))
	var biens := [bien] if vend.has(bien) else vend
	var tot := 0.0
	for g in biens:
		var cap := production.cap_of(bid, String(g))
		tot += clampf(production.stock_of(bid, String(g)) / maxf(cap, 0.0001), 0.0, 1.0) if cap > 0.0 else 0.0
	return tot / float(biens.size())


## Stock produit d'une entreprise (0 à 1), 0.5 si l'économie ne la suit pas.
func _remplissage_sortie(bid: int) -> float:
	if production == null or not production.sites.has(bid):
		return 0.5
	var out := production.outputs_of(bid)
	if out.is_empty():
		return 0.5
	var tot := 0.0
	for g in out:
		var cap := production.cap_of(bid, String(g))
		tot += clampf(production.stock_of(bid, String(g)) / maxf(cap, 0.0001), 0.0, 1.0) if cap > 0.0 else 0.0
	return tot / float(out.size())


## Nom de l'enseigne : patron (premier employé), sinon une famille du bâtiment, sinon tiré au sort.
func _nom(bid: int, type_id: String, p: Dictionary) -> String:
	var famille := ""
	var emp: Array = pop.by_job.get(bid, [])
	if not emp.is_empty():
		var ids := emp.duplicate()
		ids.sort()
		famille = String(pop.persons.get(ids[0], {}).get("n", ""))
	elif String(p.genre) == DevanturesTypes.LOGIS:
		for hid in pop.by_home.get(bid, []):
			var m: Array = pop.households.get(hid, {}).get("m", [])
			if not m.is_empty():
				famille = String(pop.persons.get(m[0], {}).get("n", ""))
				break
	if famille == "" and String(p.genre) != DevanturesTypes.LOGIS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("patron%d" % bid)
		var reg := "fr"
		if ambiance != null:
			reg = Prenoms.region_for_place(ambiance.lat, ambiance.lon)
		famille = Prenoms.family_name(rng, reg)
	return DevanturesTypes.enseigne(p, type_id, bid, famille)


# --- Habitants : vendeur, clients, queue, terrasse ----------------------------------------------

func _deja_montre(pid: int) -> bool:
	return metiers != null and metiers._figs.has(pid)


func _figurine(pid: int, met: String) -> Figurine:
	if _figs.has(pid):
		return _figs[pid]
	var f := Figurine.creer(pid, met, pop.age_of(pop.persons[pid]) < 12.0, pop)
	add_child(f)
	_figs[pid] = f
	return f


func _gens(bid: int, s: Dictionary, root: Node3D, w: float, dp: float, genre: String, info: Dictionary, figs_vues: Dictionary) -> void:
	if _figs.size() >= MAX_FIGURINES:
		return
	var base := root.global_transform
	var cz := clampf(dp * 0.55, 1.0, dp - 0.9)
	# Vendeur derrière le comptoir, face à la rue.
	var eff := pop.effectif
	if eff != null and eff.concerne(bid) and genre != DevanturesTypes.SALLE:
		var pres := eff.presents(bid)
		pres.sort()
		for pid in pres:
			if _deja_montre(int(pid)):
				continue
			var met := String(pop.persons[pid].met)
			var f := _figurine(int(pid), met)
			var g := Gestes.courant(int(pid), met, ambiance.unix_time if ambiance != null else 0.0, String(info.type))
			if Gestes.dehors(g) or String(Gestes.info(g).p) in ["four", "petrin", "machine"]:
				g = "vendre"
			if f.geste != g:
				f.regler(g)
			var cw := minf(2.2, w * 0.4)
			var cx := -w * 0.5 + 0.3 + cw * 0.5 if w > 3.5 else 0.0
			f.global_transform = base * Transform3D(Basis(Vector3.UP, PI), Vector3(cx, 0.12, cz + 0.55))
			f.visible = true
			figs_vues[int(pid)] = true
			info.vendeur = int(pid)
			break
	# Clients présents : dedans devant le comptoir, puis la queue dehors.
	var clients := []
	for pid in pop.present_in(bid):
		var k := String(pop.activity(pop.persons[pid]).kind)
		if (k == "courses" or k == "loisir") and not _deja_montre(int(pid)):
			clients.append(int(pid))
	clients.sort()
	var px := DevanturesModeles.porte_x(w)
	var n := 0
	for pid in clients:
		if _figs.size() >= MAX_FIGURINES or n >= MAX_DEDANS + MAX_QUEUE:
			break
		var f2 := _figurine(pid, "")
		if f2.geste != "client":
			f2.regler("conseiller")
			f2.geste = "client"
			f2.anim = "client"
			f2._outil.mesh = null
		var xf: Transform3D
		if n < MAX_DEDANS and genre != DevanturesTypes.SALLE:
			var x := -w * 0.5 + 0.7 + (w - 1.4) * (float(n) + 0.5) / MAX_DEDANS
			xf = Transform3D(Basis(Vector3.UP, 0.2 * float(n - 1)), Vector3(x, 0.12, minf(cz - 0.5, 1.1)))
			info.clients = int(info.clients) + 1
		elif genre == DevanturesTypes.SALLE:
			break
		else:
			var q := n - MAX_DEDANS
			xf = Transform3D(Basis.IDENTITY, Vector3(px + 0.15 * float(q % 2), 0.0, -0.7 - 0.65 * float(q)))
			info.queue = int(info.queue) + 1
		f2.hauteur_assise = 0.0
		f2.global_transform = base * xf
		f2.visible = true
		figs_vues[pid] = true
		n += 1


## Clients assis en terrasse (ceux qui sont au café en ce moment).
func _clients_terrasse(bid: int, s: Dictionary, root: Node3D, w: float, n: int, info: Dictionary, figs_vues: Dictionary) -> void:
	var base := root.global_transform
	var places := []
	for i in n:
		var x := -w * 0.5 + 0.7 + (w - 1.4) * (float(i) + 0.5) / n
		var z := -1.2 - float(i % 2) * 0.9
		places.append(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x - 0.55, 0.0, z)))
		places.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x + 0.55, 0.0, z)))
	var clients := []
	for pid in pop.present_in(bid):
		var k := String(pop.activity(pop.persons[pid]).kind)
		if (k == "loisir" or k == "courses") and not _deja_montre(int(pid)):
			clients.append(int(pid))
	clients.sort()
	var i2 := 0
	for pid in clients:
		if i2 >= places.size() or _figs.size() >= MAX_FIGURINES:
			break
		var f := _figurine(pid, "")
		if f.geste != "terrasse":
			f.regler("conseiller", true)
			f.geste = "terrasse"
			f._outil.mesh = Accessoires.outil("tasse")
		f.hauteur_assise = Accessoires.ASSISE
		f.global_transform = base * (places[i2] as Transform3D)
		f.visible = true
		figs_vues[pid] = true
		i2 += 1
	info.clients = i2


# --- Nœuds ----------------------------------------------------------------------------------

func _mi(s: Dictionary, cle: String) -> MeshInstance3D:
	var mi: MeshInstance3D = s.get(cle)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = cle
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if cle in ["vitres", "lum"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		(s.root as Node3D).add_child(mi)
		s[cle] = mi
	return mi


func _label(s: Dictionary, cle: String, taille: int, pixel: float) -> Label3D:
	var l: Label3D = s.get(cle)
	if l == null:
		l = Label3D.new()
		l.name = cle
		l.font_size = taille
		l.pixel_size = pixel
		l.outline_size = 6
		l.double_sided = false
		l.shaded = true
		(s.root as Node3D).add_child(l)
		s[cle] = l
	return l


## Plafonniers et intérieur qui s'allument le soir (surfaces "lumiere" et "base").
func _allumer(mi: MeshInstance3D, on: bool) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m == DevanturesModeles.mat_lumiere(false):
			mi.set_surface_override_material(i, DevanturesModeles.mat_lumiere(true) if on else null)
		elif m == DevanturesModeles.mat_base():
			mi.set_surface_override_material(i, DevanturesModeles.mat_interieur(true) if on else null)


func _enseigne(s: Dictionary, g: Dictionary, p: Dictionary, nom: String, st: Dictionary, neon: bool) -> void:
	if nom == "":
		_masquer(s, ["enseigne"])
		return
	var genre := String(p.genre)
	var l := _label(s, "enseigne", 64, 0.008)
	var w := float(g.w)
	if genre == DevanturesTypes.LOGIS:
		l.font_size = 32
		l.pixel_size = 0.0028
		l.text = nom
		l.modulate = Color("2b2b2b")
		l.outline_size = 0
		l.position = Vector3(0.75, 1.45, -0.06)
	elif genre == DevanturesTypes.ENTREPRISE or not bool(g.niche):
		var y := clampf(float(g.haut) - 1.2, 2.6, 5.5)
		l.text = nom.to_upper()
		l.font_size = 64
		l.pixel_size = clampf(float(g.l) * 0.8 / maxf(float(nom.length()) * 38.0, 1.0), 0.004, 0.012)
		l.modulate = st.lettres
		l.outline_size = 8
		l.outline_modulate = Color(0, 0, 0, 0.6)
		l.position = Vector3(0, y, -0.08)
	else:
		l.text = nom.to_upper() if String(st.id) != "ancien" else nom
		l.font_size = 64
		# Les lettres tiennent dans le bandeau (environ 0,55 × largeur du caractère).
		l.pixel_size = clampf((w * 0.86) / maxf(float(nom.length()) * 36.0, 1.0), 0.0035, 0.0085)
		l.modulate = st.lettres
		l.outline_size = 4
		l.outline_modulate = Color(0, 0, 0, 0.5)
		l.position = Vector3(0, float(g.h) - 0.32, -0.215)
	l.rotation = Vector3(0, PI, 0)
	# Néon ou lettres éclairées le soir.
	l.shaded = not neon
	if neon and bool(st.neon):
		l.modulate = Color("ff5c8a") if String(st.id) == "trente_glorieuses" else l.modulate
	l.visible = true


## Affichette « Plus de pain » quand la vitrine est vide.
func _affichette(s: Dictionary, w: float, h: float, vide: bool, p: Dictionary) -> void:
	if not vide:
		_masquer(s, ["affichette"])
		return
	var l := _label(s, "affichette", 36, 0.004)
	var vend: Array = p.get("vend", [])
	var bien := String(vend[0]) if not vend.is_empty() else ""
	l.text = "Plus de %s" % Ressources.good_name(bien).to_lower() if bien != "" else "Rupture"
	l.modulate = Color("b03a2e")
	l.outline_size = 0
	l.position = Vector3(-w * 0.2, 1.25, 0.05)
	l.rotation = Vector3(0, PI, 0)
	l.visible = true


## Pancarte « Ouvert » / « Fermé » sur la porte, et rideau baissé quand c'est
## fermé : volets de bois avant 1880, rideau de fer plein, grille à mailles
## (vitrine encore éclairée le soir) depuis 1960. Les halls n'en ont pas.
func _rideau_et_pancarte(s: Dictionary, w: float, h: float, genre: String, ouvert: bool, allume: bool, annee: int, info: Dictionary) -> void:
	var px := DevanturesModeles.porte_x(w)
	var l := _label(s, "pancarte", 28, 0.0035)
	l.text = "OUVERT" if ouvert else "FERMÉ"
	l.modulate = Color("2e8b57") if ouvert else Color("b03a2e")
	l.outline_size = 0
	l.position = Vector3(px, 1.55, -0.04)
	l.rotation = Vector3(0, PI, 0)
	l.visible = genre != DevanturesTypes.HALL
	var baisse := not ouvert and genre != DevanturesTypes.HALL
	if not baisse:
		_masquer(s, ["rideau"])
		info["rideau"] = ""
		return
	var sorte := "volets" if annee < 1880 else ("grille" if annee >= 1960 else "plein")
	var mi := _mi(s, "rideau")
	mi.mesh = DevanturesModeles.rideau(w, h, sorte)
	mi.visible = true
	info["rideau"] = sorte


func _logis(s: Dictionary, g: Dictionary, ctx: Dictionary) -> void:
	var mi := _mi(s, "logis")
	var mois := 6
	if ambiance != null:
		mois = int(Time.get_date_dict_from_unix_time(int(ambiance.unix_time)).month)
	var fleurs := mois >= 4 and mois <= 10 and float(g.haut) >= 3.0
	mi.mesh = DevanturesModeles.logis(float(g.l), int(ctx.annee), fleurs)
	mi.visible = true
	_allumer(mi, bool(ctx.soir))


func _masquer(s: Dictionary, cles: Array) -> void:
	for c in cles:
		var n: Node3D = s.get(c)
		if n != null:
			n.visible = false


func _cacher(bid: int) -> void:
	if _etat.has(bid):
		(_etat[bid].root as Node3D).visible = false


func _oublier(bid: int) -> void:
	if not _etat.has(bid):
		return
	(_etat[bid].root as Node).queue_free()
	_etat.erase(bid)


func _tout_cacher() -> void:
	for bid in _etat.keys():
		_oublier(bid)
	for pid in _figs:
		(_figs[pid] as Node).queue_free()
	_figs.clear()
	trous.clear()
	montres.clear()
	NightWindows.set_trous([])
