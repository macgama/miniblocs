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
##  - les enclos du zoo (avec leurs animaux) et les champs des fermes, tracés à la
##    main : même différence, sections propres à l'historique (SECTIONS_LOCALES) ;
##  - les projets du mode plan (ModePlan) ;
##  - une séance d'éditeur (éditeur libre, murs et étages, façade, meubles) : tant
##    que l'outil est ouvert il garde son propre Ctrl+Z (vidé à l'ouverture) ; à la
##    fermeture, toute la séance devient UNE entrée, avec ce qu'elle a coûté. L'historique n'est pas sauvegardé : il repart à zéro au
## chargement d'une partie. Voir docs/annuler-mode-plan.md.

signal changed
signal message(text: String)
## Un geste du joueur vient d'entrer dans l'historique : ses opérations (pose,
## démolition, voies…) et les noms des sections changées (« Zones », « Décors »…).
## Écouté par les bulles des habitants (ReactionsHabitants).
signal geste_note(ops: Array, noms: Array)
## Le joueur vient d'annuler un geste (Ctrl+Z).
signal annule

## Nombre de gestes gardés.
const MAX := 60
## Sections suivies par différence (noms de SectionsPartagees.specs).
const SECTIONS := ["zones", "decors", "reseaux", "telecom", "parc_allees", "souterrain"]
## Sections propres à l'historique (pas partagées : ces outils passent par le relais en
## carte entre amis, où elles ne sont pas suivies).
const SECTIONS_LOCALES := ["zoo_enclos", "champs"]
## Éditeurs suivis par séance : section partagée → propriété de la scène.
const SEANCES := {"blocs": "blocks", "plans": "plans", "mobilier": "mobilier"}
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
## Séances d'éditeur ouvertes : nom → {"av": section, "dep": dépense, "cle": caisse}.
var _seances: Dictionary = {}
var _specs_seance: Dictionary = {}


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
	for nom in SEANCES:
		if tout.has(nom):
			_specs_seance[nom] = tout[nom]
	var loc := specs_locales(jeu)
	for nom in loc:
		_specs[nom] = loc[nom]


## Enclos du zoo et champs : lire / écrire seulement ce que le joueur trace.
static func specs_locales(j: Node) -> Dictionary:
	var s := {}
	if j == null:
		return s
	var z: Variant = j.get("zoo")
	if z is ZooSysteme:
		s["zoo_enclos"] = {"obj": z, "outil": j.get("zoo_outils"), "locale": true,
			"lire": Callable(z, "enclos_dict"), "ecrire": Callable(z, "remettre_enclos"),
			"coll": {"enclos": {"genre": "dico", "ids": true}, "animaux": {"genre": "dico", "ids": true}},
			"champs": ["etat", "propre"], "compteurs": ["next_enclos", "next_animal"]}
	var a: Variant = j.get("agriculture")
	if a is Agriculture:
		s["champs"] = {"obj": a, "locale": true, "lire": Callable(a, "champs_dict"), "ecrire": Callable(a, "remettre_champs"),
			"coll": {"champs": {"genre": "liste", "cle": "id", "ids": true}},
			"champs": ["etat", "sc", "cr", "eng", "tr", "pertes", "met", "fait", "tache", "paille", "foin", "prec", "rdt",
				"azote", "jr", "jm", "bottes", "fert"], "compteurs": ["next"]}
	return s


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
	_seances.clear()
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
	_suivre_seances()
	if _fermer_dans < 0:
		return
	_fermer_dans -= 1
	if _fermer_dans < 0:
		fermer_geste()


# --- Séances d'éditeur -----------------------------------------------------------------------------

## Ouvre ou ferme la séance de chaque éditeur selon son outil (léger : un test par image).
func _suivre_seances() -> void:
	if jeu == null or _rejeu or not actif:
		return
	for nom in _specs_seance:
		var ed: Variant = jeu.get(SEANCES[nom])
		var ouvert := ed is Object and _outil_ouvert(ed)
		if ouvert and not _seances.has(nom):
			ouvrir_seance(nom)
		elif not ouvert and _seances.has(nom):
			fermer_seance(nom)


func en_seance() -> bool:
	return not _seances.is_empty()


## Début d'une séance : photo de la section, compteur de dépense ; l'éditeur repart
## d'un Ctrl+Z vide (ses gestes d'avant sont déjà dans l'historique).
func ouvrir_seance(nom: String) -> void:
	var ed: Object = jeu.get(SEANCES[nom])
	var u: Variant = ed.get("_undo")
	if u is Array:
		(u as Array).clear()
	_seances[nom] = {"av": SectionsPartagees.lire(_specs_seance[nom]), "dep": int(ed.get("depense")), "cle": _cle_caisse()}


## Fin d'une séance : tout ce qui a changé devient une entrée, avec son coût.
func fermer_seance(nom: String) -> void:
	if not _seances.has(nom):
		return
	var se: Dictionary = _seances[nom]
	_seances.erase(nom)
	var spec: Dictionary = _specs_seance[nom]
	var ed: Object = jeu.get(SEANCES[nom])
	var av: Dictionary = se.av
	var ap := SectionsPartagees.lire(spec)
	if av == ap:
		return
	var pav := SectionsPartagees.normaliser(av, spec)
	var pap := SectionsPartagees.normaliser(ap, spec)
	var p_ann := SectionsPartagees.difference(pap, pav)
	if SectionsPartagees.vide(p_ann):
		return
	var p_ref := SectionsPartagees.difference(pav, pap)
	var n := (p_ann.mis as Dictionary).size() + (p_ann.otes as Array).size()
	var e := _entree([], ["%s (%d élément%s)" % [_nom_section(nom), n, "s" if n > 1 else ""]])
	e.sections[nom] = {"annuler": p_ann, "refaire": p_ref, "spec": nom, "seance": true,
		"c_av": SectionsPartagees.complets(av, p_ann, spec), "c_ap": SectionsPartagees.complets(ap, p_ref, spec)}
	var dep := int(ed.get("depense")) - int(se.dep)
	if dep != 0:
		e.argent[se.cle] = dep
	e["ferme"] = true
	_pousser(e)


func _cle_caisse() -> int:
	var p: Variant = jeu.get("pays") if jeu != null else null
	return int((p as Pays).actif) if p is Pays else -1


## Commence un geste : photo des sections, de l'argent, journal du relief.
func ouvrir_geste() -> void:
	if not _geste.is_empty():
		fermer_geste()
	var secs := {}
	var client := _client_reseau()
	for nom in _specs:
		var spec: Dictionary = _specs[nom]
		if client and spec.get("locale", false):
			continue
		if _outil_ouvert(spec.get("outil", spec.obj)):
			secs[nom] = SectionsPartagees.lire(spec)
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
		a_bat = a_bat or String(op.k).begins_with("bat") or String(op.k).begins_with("mp_") or String(op.k) == "lot"
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
	geste_note.emit(e.ops, e.noms)


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
		"zoo_enclos": return "Enclos du zoo"
		"champs": return "Champs"
		"blocs": return "Éditeur libre"
		"plans": return "Murs et étages"
		"mobilier": return "Meubles"
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
		geste_note.emit([op], [nom])
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
	if en_seance():
		return _dire("Un éditeur est ouvert : son Ctrl+Z défait ses poses une à une (Échap pour le fermer).")
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
	annule.emit()
	return _dire("Annulé : %s.%s" % [e.nom, _soucis(soucis)])


## Refait le dernier geste annulé.
func refaire() -> String:
	if en_seance():
		return _dire("Rétablir : ferme d'abord l'éditeur (Échap), sa séance devient un seul Ctrl+Z.")
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
	var spec: Dictionary = _specs.get(nom, _specs_seance.get(nom, {}))
	if spec.is_empty():
		return
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
			return _bat_remettre(op.b, int(op.rendu), "La démolition") if defaire else _bat_demolir(int(op.b.id), bool(op.get("discret", false)))
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
		"perso":
			if not bs.buildings.has(int(op.bid)):
				return "Le bâtiment n'est plus là."
			bs.set_perso(int(op.bid), op.av if defaire else op.ap, int(op.v_av if defaire else op.v_ap))
			return ""
		"lot":
			return _lot(op, defaire)
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


## discret : retiré sans remboursement (conversion en intérieur, l'argent est dans le lot).
func _bat_demolir(bid: int, discret := false) -> String:
	var bs: BuildingSystem = jeu.buildings
	if not bs.buildings.has(bid):
		return "Le bâtiment n'est plus là."
	if discret:
		bs.remove_quietly(bid)
	else:
		bs.demolish(bid)
	return "" if not bs.buildings.has(bid) else "Démolition refusée."


## Un lot : opérations, sections d'éditeur et argent d'un seul coup (conversion, façade).
func _lot(op: Dictionary, defaire: bool) -> String:
	var soucis := []
	var ops: Array = op.ops
	if defaire:
		for nom in op.sections:
			_appliquer_section(nom, op.sections[nom].annuler, op.sections[nom].c_av)
		for i in range(ops.size() - 1, -1, -1):
			var r := _op(ops[i], true)
			if r != "":
				soucis.append(r)
	else:
		for o in ops:
			var r := _op(o, false)
			if r != "":
				soucis.append(r)
		for nom in op.sections:
			_appliquer_section(nom, op.sections[nom].refaire, op.sections[nom].c_ap)
	for k in op.argent:
		_crediter(int(k), int(op.argent[k]) * (1 if defaire else -1))
	return "" if soucis.is_empty() else String(soucis[0])


# --- Ce que notent les systèmes -----------------------------------------------------------------

## Photo avant une action faite par un panneau (caisse, sections d'éditeur), pour noter_lot.
func photo() -> Dictionary:
	var secs := {}
	for nom in _specs_seance:
		secs[nom] = SectionsPartagees.lire(_specs_seance[nom])
	return {"soldes": _soldes(), "sections": secs}


## Note une action de panneau comme un seul geste : ses opérations (« perso »,
## « bat_demoli »…), ce qui a changé dans les éditeurs depuis photo() et l'argent dépensé.
func noter_lot(nom: String, avant: Dictionary, ops: Array = []) -> void:
	if _rejeu or not actif or avant.is_empty():
		return
	var lot := {"k": "lot", "ops": ops.duplicate(true), "sections": {}, "argent": {}}
	for n in avant.sections:
		var spec: Dictionary = _specs_seance[n]
		var av: Dictionary = avant.sections[n]
		var ap := SectionsPartagees.lire(spec)
		if av == ap:
			continue
		var pav := SectionsPartagees.normaliser(av, spec)
		var pap := SectionsPartagees.normaliser(ap, spec)
		var p_ann := SectionsPartagees.difference(pap, pav)
		var p_ref := SectionsPartagees.difference(pav, pap)
		lot.sections[n] = {"annuler": p_ann, "refaire": p_ref,
			"c_av": SectionsPartagees.complets(av, p_ann, spec), "c_ap": SectionsPartagees.complets(ap, p_ref, spec)}
	var ap_s := _soldes()
	for k in avant.soldes:
		var d := int(avant.soldes[k]) - int(ap_s.get(k, avant.soldes[k]))
		if d != 0:
			lot.argent[k] = d
	if ops.is_empty() and (lot.sections as Dictionary).is_empty() and (lot.argent as Dictionary).is_empty():
		return
	noter(nom, lot)

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
