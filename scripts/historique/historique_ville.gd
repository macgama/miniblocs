class_name HistoriqueVille
extends Node
## Annuler et rétablir en ville (Ctrl+Z, Ctrl+Y ou Ctrl+Maj+Z).
##
## Un « geste » est tout ce que fait un clic du joueur (du bouton enfoncé jusqu'à un
## instant après le relâcher) : poser une maison, tracer un tronçon, peindre une
## zone en glissant, semer des décors, tirer une conduite, valider tout un plan…
## Chaque geste devient une entrée de l'historique, que Ctrl+Z défait d'un bloc.
##
## Ce qui est suivi :
##  - les bâtiments posés ou démolis (opérations « bat_pose », « bat_demoli ») :
##    annuler une pose rend tout ce qui a été payé (y compris l'avancement du
##    chantier) ; annuler une démolition reprend la part remboursée ;
##  - les voies (« voies ») : différence exacte du réseau (tronçons coupés aux
##    carrefours compris, giratoires, échangeurs), avec les mêmes numéros ;
##  - le relief touché pendant le geste (terrassement, outils de terrain, canaux) ;
##  - les sections que le joueur change à la main (zones, décors, réseaux d'eau et
##    d'électricité, télécoms, allées du parc, pièces souterraines) : différence
##    avant / après, comme la carte entre amis (SectionsPartagees), et l'argent que
##    le geste a coûté ;
##  - les projets du mode plan (ModePlan).
## L'éditeur libre, les murs et les meubles gardent leur propre Ctrl+Z quand leur
## outil est ouvert. L'historique n'est pas sauvegardé : il repart à zéro au
## chargement d'une partie. Voir docs/annuler-mode-plan.md.

signal changed
signal message(text: String)

## Nombre de gestes gardés.
const MAX := 60
## Sections suivies par différence (noms de SectionsPartagees.specs).
const SECTIONS := ["zones", "decors", "reseaux", "telecom", "parc_allees", "souterrain"]
## Images après le relâcher avant de fermer le geste (les panneaux réagissent au relâcher).
const IMAGES_APRES := 2

static var instance: HistoriqueVille

## La scène de jeu (terre_main) : buildings, transport, world, pays, mode_plan…
var jeu: Node
var actif := true

var _annuler: Array = []
var _refaire: Array = []
## Vrai pendant un annuler / rétablir : rien n'est noté.
var _rejeu := false
## Geste en cours ({} : aucun).
var _geste: Dictionary = {}
var _fermer_dans := -1
var _specs: Dictionary = {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if jeu != null and jeu.get("world") != null:
		jeu.world.journal = null


func setup(j: Node) -> void:
	jeu = j
	var tout := SectionsPartagees.specs(jeu)
	for nom in SECTIONS:
		if tout.has(nom):
			_specs[nom] = tout[nom]


# --- État ------------------------------------------------------------------------------------

func peut_annuler() -> bool:
	return not _annuler.is_empty()


func peut_refaire() -> bool:
	return not _refaire.is_empty()


func nom_annuler() -> String:
	return String(_annuler.back().nom) if peut_annuler() else ""


func nom_refaire() -> String:
	return String(_refaire.back().nom) if peut_refaire() else ""


func taille() -> int:
	return _annuler.size()


## Oublie tout (chargement, nouvelle partie, fondation d'un village).
func vider() -> void:
	_annuler.clear()
	_refaire.clear()
	_annuler_geste()
	changed.emit()


func en_rejeu() -> bool:
	return _rejeu


# --- Gestes ------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not actif or _rejeu:
		return
	if mb.pressed:
		if _geste.is_empty():
			ouvrir_geste()
		_fermer_dans = -1
	elif not _geste.is_empty():
		_fermer_dans = IMAGES_APRES


func _process(_delta: float) -> void:
	if _fermer_dans < 0:
		return
	_fermer_dans -= 1
	if _fermer_dans < 0:
		fermer_geste()


## Commence un geste : photo des sections, de l'argent, journal du relief.
func ouvrir_geste() -> void:
	if not _geste.is_empty():
		fermer_geste()
	var secs := {}
	for nom in _specs:
		if _outil_ouvert(_specs[nom].obj):
			secs[nom] = SectionsPartagees.lire(_specs[nom])
	_geste = {"ops": [], "noms": [], "sections": secs, "soldes": _soldes()}
	if _journal_permis():
		jeu.world.journal = {}


## Termine le geste : ce qui a changé devient une entrée de l'historique.
func fermer_geste() -> void:
	_fermer_dans = -1
	if _geste.is_empty():
		return
	var g := _geste
	_geste = {}
	var e := _entree(g.ops, g.noms)
	# Sections changées à la main.
	var a_bat := false
	for op in g.ops:
		a_bat = a_bat or String(op.k).begins_with("bat") or String(op.k).begins_with("mp_")
	for nom in g.sections:
		var spec: Dictionary = _specs[nom]
		var av: Dictionary = g.sections[nom]
		var ap := SectionsPartagees.lire(spec)
		if av == ap:
			continue
		var pav := SectionsPartagees.normaliser(av, spec)
		var pap := SectionsPartagees.normaliser(ap, spec)
		var p_ann := SectionsPartagees.difference(pap, pav)
		if SectionsPartagees.vide(p_ann):
			continue
		var p_ref := SectionsPartagees.difference(pav, pap)
		e.sections[nom] = {"annuler": p_ann, "refaire": p_ref,
			"c_av": SectionsPartagees.complets(av, p_ann, spec), "c_ap": SectionsPartagees.complets(ap, p_ref, spec)}
		(e.noms as Array).append(_nom_section(nom))
	# Argent du geste (zones, décors, conduites) : les bâtiments comptent le leur.
	if not (e.sections as Dictionary).is_empty() and not a_bat:
		var ap_s := _soldes()
		for k in g.soldes:
			var d := int(g.soldes[k]) - int(ap_s.get(k, g.soldes[k]))
			if d != 0:
				e.argent[k] = d
	# Relief.
	if jeu != null and jeu.get("world") != null and jeu.world.journal is Dictionary:
		var av_t: Dictionary = jeu.world.journal
		jeu.world.journal = null
		var ap_t: Dictionary = jeu.world.etat_cases(av_t.keys())
		for c in av_t.keys():
			if av_t[c] == ap_t[c]:
				av_t.erase(c)
				ap_t.erase(c)
		if not av_t.is_empty():
			e.terrain = {"av": av_t, "ap": ap_t}
			if (e.noms as Array).is_empty():
				(e.noms as Array).append("Terrain (%d case%s)" % [av_t.size(), "s" if av_t.size() > 1 else ""])
	_pousser(e)


func _annuler_geste() -> void:
	_geste = {}
	_fermer_dans = -1
	if jeu != null and jeu.get("world") != null:
		jeu.world.journal = null


## Seules les sections dont l'outil est ouvert sont photographiées (un clic reste
## léger même avec des milliers de décors) ; un système sans outil l'est toujours.
static func _outil_ouvert(o: Object) -> bool:
	if o == null:
		return false
	for champ in ["outil", "mode", "tool"]:
		var v: Variant = o.get(champ)
		if v is int:
			return int(v) != 0
		if v is String:
			return String(v) != ""
	return true


func _journal_permis() -> bool:
	# Carte entre amis : le relief du client vient du serveur.
	return jeu != null and jeu.get("world") != null and not _client_reseau()


func _client_reseau() -> bool:
	return jeu != null and jeu.get("buildings") != null and (jeu.buildings as BuildingSystem).relais.is_valid()


func _entree(ops: Array, noms: Array) -> Dictionary:
	return {"ops": ops.duplicate(), "noms": noms.duplicate(), "sections": {}, "argent": {}, "terrain": {}, "image": Engine.get_process_frames()}


static func _vide(e: Dictionary) -> bool:
	return (e.ops as Array).is_empty() and (e.sections as Dictionary).is_empty() and (e.terrain as Dictionary).is_empty()


func _pousser(e: Dictionary) -> void:
	if _vide(e):
		return
	e["nom"] = _resume(e.noms)
	_annuler.append(e)
	while _annuler.size() > MAX:
		_annuler.pop_front()
	_refaire.clear()
	changed.emit()


static func _resume(noms: Array) -> String:
	if noms.is_empty():
		return "changement"
	if noms.size() == 1:
		return String(noms[0])
	var compte := {}
	for n in noms:
		compte[n] = int(compte.get(n, 0)) + 1
	if compte.size() == 1:
		return "%s ×%d" % [noms[0], noms.size()]
	return "%d changements (%s…)" % [noms.size(), noms[0]]


static func _nom_section(nom: String) -> String:
	match nom:
		"zones": return "Zones"
		"decors": return "Décors"
		"reseaux": return "Réseaux"
		"telecom": return "Télécoms"
		"parc_allees": return "Allées du parc"
		"souterrain": return "Sous-sol"
	return nom


## Note une opération (pose, démolition, voies, projet). Dans un geste ouvert, elle
## s'y ajoute ; sinon elle forme une entrée (ou rejoint celle de la même image).
func noter(nom: String, op: Dictionary) -> void:
	if _rejeu or not actif:
		return
	if not _geste.is_empty():
		(_geste.ops as Array).append(op)
		(_geste.noms as Array).append(nom)
		return
	if not _annuler.is_empty() and int(_annuler.back().image) == Engine.get_process_frames() and not _annuler.back().has("ferme"):
		var e: Dictionary = _annuler.back()
		(e.ops as Array).append(op)
		(e.noms as Array).append(nom)
		e.nom = _resume(e.noms)
		changed.emit()
		return
	_pousser(_entree([op], [nom]))


func _soldes() -> Dictionary:
	var out := {}
	var p: Variant = jeu.get("pays") if jeu != null else null
	if p is Pays:
		var pays: Pays = p
		for k in pays.cles():
			out[int(k)] = pays.solde(k)
		out[pays.actif] = pays.solde(pays.actif)
	elif jeu != null and jeu.get("buildings") != null:
		out[-1] = jeu.buildings.money
	return out


func _crediter(k: int, v: int) -> void:
	var p: Variant = jeu.get("pays")
	if p is Pays:
		(p as Pays)._poser(k, (p as Pays).solde(k) + v)
	elif k == -1:
		jeu.buildings.money += v


# --- Annuler / rétablir --------------------------------------------------------------------------

## Défait le dernier geste. Renvoie le message affiché.
func annuler() -> String:
	fermer_geste()
	if _annuler.is_empty():
		return _dire("Rien à annuler.")
	var e: Dictionary = _annuler.pop_back()
	e["ferme"] = true
	_rejeu = true
	var soucis := _defaire(e)
	_rejeu = false
	_refaire.append(e)
	changed.emit()
	return _dire("Annulé : %s.%s" % [e.nom, _soucis(soucis)])


## Refait le dernier geste annulé.
func refaire() -> String:
	fermer_geste()
	if _refaire.is_empty():
		return _dire("Rien à rétablir.")
	var e: Dictionary = _refaire.pop_back()
	_rejeu = true
	var soucis := _refaire_entree(e)
	_rejeu = false
	_annuler.append(e)
	changed.emit()
	return _dire("Rétabli : %s.%s" % [e.nom, _soucis(soucis)])


func _dire(t: String) -> String:
	message.emit(t)
	return t


static func _soucis(s: Array) -> String:
	if s.is_empty():
		return ""
	return " " + String(s[0]) + ("" if s.size() == 1 else " (et %d autre%s)" % [s.size() - 1, "s" if s.size() > 2 else ""])


func _defaire(e: Dictionary) -> Array:
	var soucis := []
	var ops: Array = e.ops
	for i in range(ops.size() - 1, -1, -1):
		var r := _op(ops[i], true)
		if r != "":
			soucis.append(r)
	for nom in e.sections:
		_appliquer_section(nom, e.sections[nom].annuler, e.sections[nom].c_av)
	if not (e.terrain as Dictionary).is_empty():
		jeu.world.remettre_cases(e.terrain.av)
	for k in e.argent:
		_crediter(int(k), int(e.argent[k]))
	_apres()
	return soucis


func _refaire_entree(e: Dictionary) -> Array:
	var soucis := []
	for op in e.ops:
		var r := _op(op, false)
		if r != "":
			soucis.append(r)
	for nom in e.sections:
		_appliquer_section(nom, e.sections[nom].refaire, e.sections[nom].c_ap)
	if not (e.terrain as Dictionary).is_empty():
		jeu.world.remettre_cases(e.terrain.ap)
	for k in e.argent:
		_crediter(int(k), -int(e.argent[k]))
	_apres()
	return soucis


func _appliquer_section(nom: String, p: Dictionary, complets: Dictionary) -> void:
	if not _specs.has(nom):
		return
	var spec: Dictionary = _specs[nom]
	var brut := SectionsPartagees.lire(spec)
	var d := SectionsPartagees.appliquer(brut, p, spec, complets)
	(spec.ecrire as Callable).call(d)


func _apres() -> void:
	if jeu != null and jeu.get("buildings") != null:
		(jeu.buildings as BuildingSystem)._refresh()


## Une opération, dans un sens. Renvoie "" ou ce qui n'a pas pu se faire.
func _op(op: Dictionary, defaire: bool) -> String:
	var bs: BuildingSystem = jeu.buildings if jeu != null else null
	match String(op.k):
		"bat_pose":
			return _bat_retirer(op) if defaire else _bat_remettre(op.b, int(op.paye), "")
		"bat_demoli":
			return _bat_remettre(op.b, int(op.rendu), "La démolition") if defaire else _bat_demolir(int(op.b.id))
		"voies":
			var tr: TransportSystem = jeu.transport
			var n := tr.appliquer_diff(op.diff, defaire)
			return "" if n == 0 else "%d tronçon%s avai%s déjà changé." % [n, "s" if n > 1 else "", "ent" if n > 1 else "t"]
		"projet":
			var mp: ModePlan = jeu.get("mode_plan")
			if mp == null:
				return ""
			# ajout : défaire = retirer ; retrait : défaire = remettre.
			if bool(op.ajout) == defaire:
				mp.retirer(int(op.p.pid), false)
			else:
				mp.remettre(op.p)
			return ""
		"mp_bat_pose":
			if bs == null or not bs.relais.is_valid():
				return "Plus en ligne."
			if defaire:
				bs.relais.call({"t": "demolir", "c": op.a.c, "annule": true})
			else:
				bs.relais.call((op.a as Dictionary).duplicate(true))
			return ""
		"mp_bat_demoli":
			if bs == null or not bs.relais.is_valid():
				return "Plus en ligne."
			if defaire:
				bs.relais.call((op.a as Dictionary).duplicate(true))
			else:
				bs.relais.call({"t": "demolir", "c": op.a.c})
			return ""
		"mp_voies":
			var tr: TransportSystem = jeu.transport
			if not tr.relais.is_valid():
				return "Plus en ligne."
			tr.relais.call({"t": "voie_histo", "annuler": defaire, "d": op.diff})
			return ""
	return ""


func _bat_retirer(op: Dictionary) -> String:
	var bs: BuildingSystem = jeu.buildings
	var bid := int(op.b.id)
	if not bs.buildings.has(bid):
		return "Le bâtiment n'est plus là."
	var b: Dictionary = bs.buildings[bid]
	# Tout ce qui a été payé revient : prix immédiat, ou chantier déjà avancé.
	var rendu := 0
	if not bool(op.get("illimite", false)):
		rendu = int(op.paye) + int(op.get("du0", 0)) - int(b.get("du", 0))
	bs.remove_quietly(bid)
	if rendu != 0 and not bs.unlimited_money:
		var p := Pays.du_batiment(b, bs._rect_of(b))
		bs.money += rendu
		Pays.retour(p)
	return ""


## Remet un bâtiment (copie b) et fait payer « prix » (0 : rien).
func _bat_remettre(b: Dictionary, prix: int, quoi: String) -> String:
	var bs: BuildingSystem = jeu.buildings
	var bid := int(b.id)
	if bs.buildings.has(bid):
		return ""
	for c in BuildingSystem.cells_for(String(b.t), bs._center_of(b), int(b.r), float(b.get("a", 0.0))):
		if bs.occupancy.has(c) or (bs.transport != null and bs.transport.is_cell_occupied(c)):
			return "%s ne peut pas revenir : la place est prise." % (quoi if quoi != "" else "Le bâtiment")
	var copie := b.duplicate(true)
	bs.restore(copie)
	if prix != 0 and not bs.unlimited_money:
		var p := Pays.du_batiment(copie, bs._rect_of(copie))
		bs.money -= prix
		Pays.retour(p)
	return ""


func _bat_demolir(bid: int) -> String:
	var bs: BuildingSystem = jeu.buildings
	if not bs.buildings.has(bid):
		return "Le bâtiment n'est plus là."
	bs.demolish(bid)
	return "" if not bs.buildings.has(bid) else "Démolition refusée."


# --- Ce que notent les systèmes -----------------------------------------------------------------

## Un bâtiment vient d'être posé par le joueur (BuildingSystem, ModePlan).
func noter_pose(bid: int) -> void:
	var bs: BuildingSystem = jeu.buildings if jeu != null else null
	if bs == null or not bs.buildings.has(bid) or _rejeu:
		return
	var b: Dictionary = bs.buildings[bid]
	# Fonder un village (commune, kit de l'État, rue offerte) ne s'annule pas : l'historique repart d'ici.
	if Communes.est_fondateur(String(b.t)):
		vider()
		return
	var copie := b.duplicate(true)
	# Rétablir : le chantier repart de zéro, comme une pose neuve.
	for k in ["ne", "fin", "av", "hr", "chantier"]:
		copie.erase(k)
	var du0 := int(b.get("du", 0))
	var paye := 0 if bs.unlimited_money else int(b.get("cost", 0)) - du0
	noter(_nom_type(String(b.t)), {"k": "bat_pose", "b": copie, "paye": paye, "du0": du0, "illimite": bs.unlimited_money})


## Un bâtiment va être démoli par le joueur : copie prise avant, remboursement après.
func noter_demolition(avant: Dictionary, rendu: int) -> void:
	if _rejeu:
		return
	noter("Démolition : " + _nom_type(String(avant.t)).to_lower(), {"k": "bat_demoli", "b": avant.duplicate(true), "rendu": rendu})


## Voies tracées, démolies, carrefour aménagé (diff de TransportSystem.diff_reseau).
func noter_voies(nom: String, diff: Dictionary) -> void:
	if _rejeu or TransportSystem.diff_vide(diff):
		return
	noter(nom, {"k": "voies", "diff": diff})


static func _nom_type(id: String) -> String:
	var t := BuildingCatalog.get_type(id)
	return String(t.get("name", id)) if not t.is_empty() else id
