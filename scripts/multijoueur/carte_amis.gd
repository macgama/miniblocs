class_name CarteAmis
extends RefCounted
## Carte entre amis, côté serveur : code d'invitation, membres, rôles, maires des
## villes et caisses personnelles. Section « multijoueur » de la sauvegarde du serveur.
##
## Règles (voir docs/multijoueur.md) :
##  - on entre la première fois avec le code d'invitation ; ensuite on est membre
##    et le code n'est plus demandé (sauf s'il a été changé avec « nouveau code ») ;
##  - le créateur de la carte est l'admin (réglages, vitesse du temps, code, exclure) ;
##  - chaque joueur a sa caisse : celle de sa ville s'il en est le maire, sinon sa
##    caisse personnelle (l'argent de départ des réglages), qui devient la caisse de
##    sa première ville quand il en fonde une ;
##  - on construit partout ; hors de ses villes, c'est sa propre caisse qui paie.

const VERSION := 1
## Lettres sans ambiguïté (pas de 0/O ni de 1/I/L) pour un code facile à dicter.
const LETTRES := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

var nom := ""
var code := ""
var createur := ""
## pid -> {"pseudo", "role": "admin"|"joueur", "n": numéro, "rejoint": unix, "vu": unix}
var membres := {}
## pid exclus par l'admin
var exclus := {}
## vid -> pid du maire
var maires := {}
## Visiteurs sans code d'invitation (inconnus) permis : ils se promènent sans construire.
var visites_ouvertes := false
var _prochain := 1


static func nouveau_code() -> String:
	var b := Crypto.new().generate_random_bytes(8)
	var s := ""
	for i in 8:
		s += LETTRES[b[i] % LETTRES.length()]
		if i == 3:
			s += "-"
	return s


## Code tapé par un joueur, ramené à la forme du serveur (« ab cd-ef gh » → « ABCD-EFGH »).
static func normaliser_code(t: String) -> String:
	var s := ""
	for ch in t.to_upper():
		if LETTRES.contains(ch):
			s += ch
	if s.length() == 8:
		s = s.substr(0, 4) + "-" + s.substr(4)
	return s


func creer(nom_carte: String, createur_id: String) -> void:
	nom = nom_carte
	createur = createur_id
	code = nouveau_code()


## Visiteur (pas membre, pas de caisse, ne construit pas). Renvoie {"ok", "raison", "pseudo"}.
func accepter_visiteur(pid: String, pseudo_: String, code_tape: String) -> Dictionary:
	if pid.length() < 8:
		return {"ok": false, "raison": "Identifiant de joueur invalide."}
	if exclus.has(pid):
		return {"ok": false, "raison": "L'admin de la carte t'en a exclu."}
	if not visites_ouvertes and not membres.has(pid) and normaliser_code(code_tape) != code:
		return {"ok": false, "raison": "Cette carte ne s'ouvre aux visiteurs qu'avec le code d'invitation."}
	var p := nettoyer_pseudo(pseudo_, 0)
	if p == "Joueur 0":
		p = "Visiteur"
	return {"ok": true, "raison": "", "pseudo": p}


## Demande d'entrée. Renvoie {"ok", "raison", "nouveau": premier passage}.
func accepter(pid: String, pseudo: String, code_tape: String, maintenant: int) -> Dictionary:
	if pid.length() < 8:
		return {"ok": false, "raison": "Identifiant de joueur invalide."}
	if exclus.has(pid):
		return {"ok": false, "raison": "L'admin de la carte t'en a exclu."}
	var connu := membres.has(pid)
	if not connu and normaliser_code(code_tape) != code and (createur == "" or pid != createur):
		return {"ok": false, "raison": "Code d'invitation incorrect. Demande-le au créateur de la carte."}
	# Nouvelle carte sans créateur désigné : le premier qui entre (avec le code) en devient l'admin.
	if createur == "":
		createur = pid
	if not connu:
		if membres.size() >= Protocole.JOUEURS_MAX:
			return {"ok": false, "raison": "La carte est pleine (%d joueurs)." % Protocole.JOUEURS_MAX}
		membres[pid] = {"pseudo": "", "role": "admin" if pid == createur else "joueur", "n": _prochain, "rejoint": maintenant, "vu": maintenant}
		_prochain += 1
	var m: Dictionary = membres[pid]
	m.pseudo = nettoyer_pseudo(pseudo, int(m.n))
	m.vu = maintenant
	return {"ok": true, "raison": "", "nouveau": not connu}


static func nettoyer_pseudo(p: String, n: int) -> String:
	var s := p.strip_edges().replace("\n", " ")
	if s.length() > 24:
		s = s.substr(0, 24)
	return s if s != "" else "Joueur %d" % n


func est_admin(pid: String) -> bool:
	return pid != "" and (pid == createur or String((membres.get(pid, {}) as Dictionary).get("role", "")) == "admin")


func pseudo(pid: String) -> String:
	return String((membres.get(pid, {}) as Dictionary).get("pseudo", "?"))


## Caisse personnelle (sans ville) d'un membre.
func cle_personnelle(pid: String) -> int:
	return Pays.JOUEUR_BASE - int((membres.get(pid, {}) as Dictionary).get("n", 0))


## Villes dont le joueur est maire (les plus anciennes d'abord).
func villes_de(pid: String) -> Array:
	var out := []
	for vid in maires:
		if String(maires[vid]) == pid:
			out.append(int(vid))
	out.sort()
	return out


## Caisse qui paie ce que fait le joueur hors de ses villes : sa première ville, sinon sa caisse personnelle.
func caisse_principale(pid: String) -> int:
	var v := villes_de(pid)
	return int(v[0]) if not v.is_empty() else cle_personnelle(pid)


func maire_de(vid: int) -> String:
	return String(maires.get(vid, ""))


func exclure(pid: String) -> void:
	if pid == createur:
		return
	membres.erase(pid)
	exclus[pid] = true


func to_dict(caisses: Dictionary = {}) -> Dictionary:
	var m := {}
	for pid in membres:
		m[pid] = (membres[pid] as Dictionary).duplicate()
	var ma := {}
	for vid in maires:
		ma[str(vid)] = maires[vid]
	var cs := {}
	for k in caisses:
		cs[str(k)] = int(caisses[k])
	return {"version": VERSION, "nom": nom, "code": code, "createur": createur, "membres": m,
		"exclus": exclus.keys(), "maires": ma, "prochain": _prochain, "caisses": cs, "visites_ouvertes": visites_ouvertes}


## Renvoie les caisses personnelles enregistrées (clé -> solde).
func from_dict(d: Dictionary) -> Dictionary:
	nom = String(d.get("nom", ""))
	code = String(d.get("code", ""))
	createur = String(d.get("createur", ""))
	membres.clear()
	var dm: Dictionary = d.get("membres", {})
	for pid in dm:
		var e: Dictionary = dm[pid]
		membres[String(pid)] = {"pseudo": String(e.get("pseudo", "")), "role": String(e.get("role", "joueur")),
			"n": int(e.get("n", 0)), "rejoint": int(e.get("rejoint", 0)), "vu": int(e.get("vu", 0))}
	exclus.clear()
	for pid in d.get("exclus", []):
		exclus[String(pid)] = true
	maires.clear()
	var dma: Dictionary = d.get("maires", {})
	for vid in dma:
		maires[int(vid)] = String(dma[vid])
	_prochain = maxi(int(d.get("prochain", 1)), 1)
	visites_ouvertes = bool(d.get("visites_ouvertes", false))
	for pid in membres:
		_prochain = maxi(_prochain, int(membres[pid].n) + 1)
	if code == "":
		code = nouveau_code()
	var cs := {}
	var dc: Dictionary = d.get("caisses", {})
	for k in dc:
		cs[int(k)] = int(dc[k])
	return cs
