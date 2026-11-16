class_name TwitchChat
extends Node
## Lecture du chat d'une chaîne Twitch, sans compte ni clé.
##
## Twitch accepte les connexions anonymes en lecture seule sur son serveur IRC
## par WebSocket : on se présente comme « justinfanNNNNN » avec n'importe quel
## mot de passe, puis on rejoint la chaîne (#nom_de_la_chaine). Le jeu ne peut
## rien écrire dans le chat : il lit seulement les messages des spectateurs.
##
## Reconnexion automatique (2 s, 4 s, 8 s… jusqu'à 60 s) ; réponse aux PING du
## serveur ; commande RECONNECT de Twitch prise en charge.
## Voir docs/streamer.md.

signal message_recu(pseudo: String, nom_affiche: String, texte: String, tags: Dictionary)
signal etat_change(etat: String)

const URL_TWITCH := "wss://irc-ws.chat.twitch.tv:443"
## États : "deconnecte", "connexion", "connecte" (chaîne rejointe), "erreur".
const ETATS := {"deconnecte": "Déconnecté", "connexion": "Connexion…", "connecte": "Connecté", "erreur": "Erreur"}

## Adresse du serveur (les tests la remplacent par un faux serveur local).
var url := URL_TWITCH
var chaine := ""
var etat := "deconnecte"
var derniere_erreur := ""
## Nombre de messages lus depuis la connexion.
var messages_lus := 0

var _ws: WebSocketPeer
var _veut_connexion := false
var _attente := 0.0
var _delai := 2.0
var _pseudo := ""


static func nettoyer_chaine(s: String) -> String:
	## « https://www.twitch.tv/Ma_Chaine » ou « #Ma_Chaine » → « ma_chaine ».
	var t := s.strip_edges().to_lower()
	var i := t.find("twitch.tv/")
	if i >= 0:
		t = t.substr(i + 10)
	t = t.trim_prefix("#").trim_prefix("@")
	var out := ""
	for ch in t:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
		else:
			break
	return out.substr(0, 25)


func connecter(nom_chaine: String) -> bool:
	chaine = nettoyer_chaine(nom_chaine)
	if chaine.length() < 3:
		derniere_erreur = "Nom de chaîne invalide."
		_set_etat("erreur")
		return false
	_veut_connexion = true
	_delai = 2.0
	_ouvrir()
	return true


func deconnecter() -> void:
	_veut_connexion = false
	if _ws != null:
		_ws.close()
	_ws = null
	_set_etat("deconnecte")


func est_connecte() -> bool:
	return etat == "connecte"


func _ouvrir() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	var err := _ws.connect_to_url(url)
	if err != OK:
		derniere_erreur = "Impossible de joindre Twitch (%s)." % error_string(err)
		_ws = null
		_set_etat("erreur")
		_attente = _delai
		return
	_pseudo = "justinfan%d" % (10000 + randi() % 80000)
	_set_etat("connexion")


func _set_etat(e: String) -> void:
	if e == etat:
		return
	etat = e
	etat_change.emit(e)


func _envoyer(ligne: String) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(ligne + "\r\n")


var _bonjour_envoye := false


func _process(delta: float) -> void:
	if _ws == null:
		if _veut_connexion:
			_attente -= delta
			if _attente <= 0.0:
				_ouvrir()
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _bonjour_envoye:
				_bonjour_envoye = true
				_envoyer("CAP REQ :twitch.tv/tags twitch.tv/commands")
				_envoyer("PASS SCHMOOPIIE")
				_envoyer("NICK " + _pseudo)
				_envoyer("JOIN #" + chaine)
			while _ws.get_available_packet_count() > 0:
				var txt := _ws.get_packet().get_string_from_utf8()
				for ligne in txt.split("\n", false):
					_traiter(ligne.strip_edges(false, true))
		WebSocketPeer.STATE_CLOSED:
			_bonjour_envoye = false
			_ws = null
			if _veut_connexion:
				if derniere_erreur == "":
					derniere_erreur = "Connexion coupée, nouvel essai dans %d s." % int(_delai)
				_set_etat("erreur")
				_attente = _delai
				_delai = minf(_delai * 2.0, 60.0)
			else:
				_set_etat("deconnecte")


func _traiter(ligne: String) -> void:
	if ligne.is_empty():
		return
	var m := analyser(ligne)
	match String(m.commande):
		"PING":
			_envoyer("PONG :" + String(m.texte))
		"RECONNECT":
			derniere_erreur = "Twitch demande de se reconnecter."
			if _ws != null:
				_ws.close()
		"NOTICE":
			var t := String(m.texte)
			if t.to_lower().contains("failed") or t.to_lower().contains("invalid"):
				derniere_erreur = t
		"JOIN", "366":
			derniere_erreur = ""
			_delai = 2.0
			_set_etat("connecte")
		"PRIVMSG":
			messages_lus += 1
			var tags: Dictionary = m.tags
			var pseudo := String(m.pseudo)
			var nom := String(tags.get("display-name", ""))
			if nom.is_empty():
				nom = pseudo
			message_recu.emit(pseudo, nom, String(m.texte), tags)


## Découpe une ligne IRC de Twitch :
## « @tags :pseudo!pseudo@pseudo.tmi.twitch.tv PRIVMSG #chaine :texte ».
## Renvoie {tags, pseudo, commande, params, texte}.
static func analyser(ligne: String) -> Dictionary:
	var r := {"tags": {}, "pseudo": "", "commande": "", "params": [], "texte": ""}
	var s := ligne
	if s.begins_with("@"):
		var fin := s.find(" ")
		if fin < 0:
			return r
		for kv in s.substr(1, fin - 1).split(";"):
			var eq := kv.find("=")
			if eq > 0:
				r.tags[kv.substr(0, eq)] = _tag(kv.substr(eq + 1))
		s = s.substr(fin + 1)
	if s.begins_with(":"):
		var fin2 := s.find(" ")
		if fin2 < 0:
			return r
		var prefixe := s.substr(1, fin2 - 1)
		var bang := prefixe.find("!")
		r.pseudo = prefixe.substr(0, bang) if bang >= 0 else prefixe
		s = s.substr(fin2 + 1)
	var deux := s.find(" :")
	var avant := s
	if deux >= 0:
		r.texte = s.substr(deux + 2)
		avant = s.substr(0, deux)
	elif s.begins_with(":"):
		r.texte = s.substr(1)
		avant = ""
	var morceaux := avant.split(" ", false)
	if morceaux.size() > 0:
		r.commande = morceaux[0]
		r.params = Array(morceaux.slice(1))
	return r


static func _tag(v: String) -> String:
	return v.replace("\\s", " ").replace("\\:", ";").replace("\\\\", "\\").replace("\\r", "").replace("\\n", "")


## Le message vient-il du streamer ou d'un modérateur ?
static func est_moderateur(tags: Dictionary) -> bool:
	var badges := String(tags.get("badges", ""))
	return String(tags.get("mod", "0")) == "1" or badges.contains("broadcaster/") or badges.contains("moderator/")
