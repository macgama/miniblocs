class_name SousTerreAuto
extends Node
## Passe la vue sous terre toute seule quand on prend un outil qui construit sous
## le sol, d'où qu'il vienne :
## - conduite ou câble enterré du panneau Réseaux (O) : eau, égout, gaz, câble
##   électrique souterrain, aqueduc, séparatif, chaleur, hydrogène ;
## - câble enterré des télécoms (Maj+O) : fibre, téléphone, coaxial ;
## - métro des Voies (Rail → Métro) ;
## - thème « Sous terre » de Construire (B) et bouton « Sous terre » de la barre.
## La vue se met au bon niveau (−1 pour une conduite, −3 au moins pour un tunnel)
## et l'outil passe dans le panneau Sous-sol, au niveau affiché.
## Quand on range l'outil (Échap, clic droit, autre outil), la vue revient en
## surface si c'est l'outil qui l'avait ouverte. « Retour en surface » avec
## l'outil en main le garde en main, en surface (métro aérien, conduite posée
## à l'ancienne) : il n'est plus repris tant qu'on ne le change pas.

## false : plus de bascule automatique (tests, ou pour la couper un jour en réglage).
static var active := true

var vue: VueSouterraine
var construction: ConstructionSouterraine
var reseaux: Reseaux
var telecom: Telecom
var transport: TransportSystem
## Appelé juste avant d'ouvrir la vue (terre_main : range la vue par étage).
var preparer: Callable

## Vrai si la vue a été ouverte par un outil : on la referme avec lui.
var auto_ouverte := false
## Outil laissé en surface exprès (« Retour en surface ») : pas repris tant qu'il reste en main.
var laisse := ""
var _sortie_par_nous := false


func brancher() -> void:
	vue.avant_sortie.connect(_on_avant_sortie)


## Outil de surface qui construit sous le sol : {"o": Outil, "p": type, "n":
## niveau minimal, "cle": clé} ; vide sinon.
func demande() -> Dictionary:
	if reseaux != null and reseaux.outil == Reseaux.Outil.TRACER and est_conduite(reseaux.type_troncon):
		return {"o": ConstructionSouterraine.Outil.CONDUITE, "p": reseaux.type_troncon, "n": 1, "cle": "c:" + reseaux.type_troncon}
	if telecom != null and Telecom.OUTIL_CABLE.has(telecom.outil):
		var c := String(Telecom.OUTIL_CABLE[telecom.outil])
		if not bool(Telecom.CABLES[c].aerien):
			return {"o": ConstructionSouterraine.Outil.CONDUITE, "p": c, "n": 1, "cle": "c:" + c}
	if transport != null and transport.tool == TransportSystem.Tool.BUILD and transport.type_id == "metro" \
			and not transport.relais.is_valid() and not transport.bloque_reseau():
		return {"o": ConstructionSouterraine.Outil.TUNNEL, "p": "metro", "n": ConstructionSouterraine.NIVEAU_MIN_TUNNEL, "cle": "v:metro"}
	return {}


## Tronçon du panneau O posé sous terre (pas les lignes sur poteaux ou pylônes).
static func est_conduite(type_id: String) -> bool:
	if type_id.begins_with("ligne_") or not VueSouterraine.TRONCONS.has(type_id):
		return false
	var tr := ReseauxTypes.troncon(type_id)
	return not tr.is_empty() and (String(tr.res) != "elec" or bool(tr.get("enterre", false)))


## La vue de dessus est la caméra en cours (pas la vue au sol).
func _vue_de_dessus() -> bool:
	return vue.camera != null and vue.camera.get_viewport() != null and vue.camera.get_viewport().get_camera_3d() == vue.camera


## Ouvre la vue (si besoin) au niveau n au moins et prend l'outil o. Faux si la
## vue sous terre ne peut pas s'ouvrir (vue au sol).
func lancer_outil(o: ConstructionSouterraine.Outil, param: String, n := 1) -> bool:
	if not vue.actif:
		if not _vue_de_dessus():
			return false
		if preparer.is_valid():
			preparer.call()
		vue.entrer()
		if not vue.actif:
			return false
		auto_ouverte = true
	if vue.niveau < n:
		vue.set_niveau(n)
	construction.activer(o, param)
	return construction.outil == o


## Thème « Sous terre » de Construire : "conduite", "tunnel" ou "piece" et son type.
func lancer(outil: String, param: String) -> bool:
	laisse = ""
	match outil:
		"conduite":
			return lancer_outil(ConstructionSouterraine.Outil.CONDUITE, param, 1)
		"tunnel":
			return lancer_outil(ConstructionSouterraine.Outil.TUNNEL, param, ConstructionSouterraine.NIVEAU_MIN_TUNNEL)
		"piece":
			# Une cave sous une rue gênerait ses réseaux : on part du −1, le joueur descend.
			return lancer_outil(ConstructionSouterraine.Outil.PIECE, param, 1)
	return false


func _process(_delta: float) -> void:
	if vue == null or construction == null:
		return
	if not vue.actif:
		auto_ouverte = false
	var d := demande() if active else {}
	var cle := String(d.get("cle", ""))
	if laisse != "" and cle != laisse:
		laisse = ""
	if not d.is_empty() and cle != laisse and construction.outil == ConstructionSouterraine.Outil.AUCUN:
		lancer_outil(d.o, String(d.p), int(d.n))
		return
	# L'outil qui avait ouvert la vue est rangé : retour en surface.
	if auto_ouverte and vue.actif and construction.outil == ConstructionSouterraine.Outil.AUCUN:
		_sortie_par_nous = true
		vue.sortir()
		_sortie_par_nous = false
		auto_ouverte = false


## « Retour en surface » (ou vue au sol) avec une conduite ou un tunnel venu d'un
## menu de surface en main : l'outil reste en main, en surface.
func _on_avant_sortie() -> void:
	if _sortie_par_nous or not auto_ouverte:
		return
	auto_ouverte = false
	var o := construction.outil
	var p := construction.type_conduite if o == ConstructionSouterraine.Outil.CONDUITE else construction.type_voie
	if o != ConstructionSouterraine.Outil.CONDUITE and not (o == ConstructionSouterraine.Outil.TUNNEL and p == "metro"):
		return
	_rearmer.call_deferred(o, p)


func _rearmer(o: ConstructionSouterraine.Outil, p: String) -> void:
	if vue.actif:
		return
	if o == ConstructionSouterraine.Outil.TUNNEL:
		transport.set_build(p)
	elif ConstructionSouterraine.est_telecom(p):
		telecom.set_outil(ConstructionSouterraine.outil_telecom(p))
	else:
		reseaux.set_outil(Reseaux.Outil.TRACER, p)
	laisse = ("v:" if o == ConstructionSouterraine.Outil.TUNNEL else "c:") + p
