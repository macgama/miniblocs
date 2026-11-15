class_name Protocole
extends RefCounted
## Messages échangés entre le jeu et le serveur de la carte entre amis.
##
## Un message est un Dictionary {"m": type, ...} converti en octets (var_to_bytes,
## sans objets) puis compressé (Zstandard). Tout passe par un seul canal fiable et
## ordonné : un message arrive toujours après ceux envoyés avant lui.
##
## Jeu → serveur : bonjour, action, chat, resync, au_revoir.
## Serveur → jeu : bienvenue, refus, instantane (en morceaux), bat (bâtiments posés,
## retirés, changés), rejouer (voies), terrain (cases), section, tic (heure,
## caisses, empreintes), info, chat, joueurs, reponse.

## Version du protocole : un jeu et un serveur de versions différentes refusent de se parler.
const VERSION := 1
const PORT_DEFAUT := 24680
const JOUEURS_MAX := 32
## Taille d'un morceau d'instantané (octets compressés).
const MORCEAU := 192 * 1024
## Octets en dessous desquels on ne compresse pas.
const SEUIL_COMPRESSION := 512


static func encoder(msg: Dictionary) -> PackedByteArray:
	var brut := var_to_bytes(msg)
	if brut.size() < SEUIL_COMPRESSION:
		var out := PackedByteArray([0])
		out.append_array(brut)
		return out
	var comp := brut.compress(FileAccess.COMPRESSION_ZSTD)
	var tete := PackedByteArray([1, 0, 0, 0, 0])
	tete.encode_u32(1, brut.size())
	tete.append_array(comp)
	return tete


## Message décodé, ou {} si les octets sont illisibles.
static func decoder(octets: PackedByteArray) -> Dictionary:
	if octets.size() < 2:
		return {}
	var brut: PackedByteArray
	if octets[0] == 0:
		brut = octets.slice(1)
	elif octets[0] == 1 and octets.size() > 5:
		var n := octets.decode_u32(1)
		if n > 512 * 1024 * 1024:
			return {}
		brut = octets.slice(5).decompress(n, FileAccess.COMPRESSION_ZSTD)
	else:
		return {}
	var v: Variant = bytes_to_var(brut)
	return v if v is Dictionary else {}


## Gros contenu (instantané de la partie) : texte JSON compressé, coupé en morceaux.
static func decouper(donnees: Dictionary) -> Array[PackedByteArray]:
	var brut := JSON.stringify(donnees).to_utf8_buffer()
	var comp := brut.compress(FileAccess.COMPRESSION_ZSTD)
	var tete := PackedByteArray([0, 0, 0, 0])
	tete.encode_u32(0, brut.size())
	tete.append_array(comp)
	var out: Array[PackedByteArray] = []
	var i := 0
	while i < tete.size():
		out.append(tete.slice(i, mini(i + MORCEAU, tete.size())))
		i += MORCEAU
	return out


static func recoller(morceaux: Array) -> Dictionary:
	var tout := PackedByteArray()
	for m in morceaux:
		tout.append_array(m)
	if tout.size() < 5:
		return {}
	var n := tout.decode_u32(0)
	var brut := tout.slice(4).decompress(n, FileAccess.COMPRESSION_ZSTD)
	var v: Variant = JSON.parse_string(brut.get_string_from_utf8())
	return v if v is Dictionary else {}


## « 192.168.1.20:24680 », « monserveur.fr » ou « [::1]:24680 » → [hôte, port].
static func lire_adresse(texte: String) -> Array:
	var t := texte.strip_edges()
	var port := PORT_DEFAUT
	if t.begins_with("["):
		var fin := t.find("]")
		var hote := t.substr(1, fin - 1) if fin > 0 else t.substr(1)
		var reste := t.substr(fin + 1) if fin > 0 else ""
		if reste.begins_with(":") and reste.substr(1).is_valid_int():
			port = int(reste.substr(1))
		return [hote, port]
	if t.count(":") == 1:
		var p := t.get_slice(":", 1)
		if p.is_valid_int():
			port = int(p)
		t = t.get_slice(":", 0)
	if t == "":
		t = "127.0.0.1"
	return [t, clampi(port, 1, 65535)]
