class_name AviMjpeg
extends RefCounted
## Petite vidéo AVI « Motion JPEG » écrite à la main : chaque image est un JPEG,
## rangé dans un conteneur RIFF/AVI avec son index. Lisible par VLC, le lecteur
## Windows (Films et TV, Lecteur multimédia), DaVinci Resolve, Premiere…
## Pas besoin de logiciel en plus pour exporter un time-lapse.
##
##   var avi := AviMjpeg.new()
##   avi.ouvrir("user://ville.avi", 1280, 720, 24)
##   avi.ajouter_jpeg(image.save_jpg_to_buffer(0.9))
##   avi.fermer()

const AVIF_HASINDEX := 0x10
const AVIIF_KEYFRAME := 0x10

var _f: FileAccess
var _largeur := 0
var _hauteur := 0
var _ips := 24
## Position du mot « movi » dans le fichier (les décalages de l'index partent de là).
var _pos_movi := 0
var _pos_taille_movi := 0
var _pos_nb_avih := 0
var _pos_nb_strh := 0
var _pos_tampon_avih := 0
var _pos_tampon_strh := 0
var _index := PackedInt32Array() # décalage, taille, décalage, taille…
var _plus_grande := 0
var images := 0
var erreur := ""


## Ouvre le fichier et écrit l'en-tête (les tailles sont complétées à la fin).
func ouvrir(chemin: String, largeur: int, hauteur: int, ips: int) -> bool:
	_f = FileAccess.open(chemin, FileAccess.WRITE)
	if _f == null:
		erreur = "impossible d'écrire %s (%s)" % [chemin, error_string(FileAccess.get_open_error())]
		return false
	_largeur = largeur
	_hauteur = hauteur
	_ips = maxi(ips, 1)
	_f.big_endian = false
	_fourcc("RIFF")
	_f.store_32(0) # taille du fichier − 8, complétée à la fin
	_fourcc("AVI ")
	# LIST hdrl = 4 + (8 + 56) + (8 + 4 + (8 + 56) + (8 + 40))
	_fourcc("LIST")
	_f.store_32(4 + 64 + 12 + 64 + 48)
	_fourcc("hdrl")
	_fourcc("avih")
	_f.store_32(56)
	_f.store_32(int(1000000.0 / _ips)) # µs par image
	_f.store_32(0) # débit maximal
	_f.store_32(0) # granularité
	_f.store_32(AVIF_HASINDEX)
	_pos_nb_avih = _f.get_position()
	_f.store_32(0) # nombre d'images
	_f.store_32(0) # images initiales
	_f.store_32(1) # un seul flux
	_pos_tampon_avih = _f.get_position()
	_f.store_32(0) # taille de tampon conseillée
	_f.store_32(largeur)
	_f.store_32(hauteur)
	for i in 4:
		_f.store_32(0)
	_fourcc("LIST")
	_f.store_32(4 + 64 + 48)
	_fourcc("strl")
	_fourcc("strh")
	_f.store_32(56)
	_fourcc("vids")
	_fourcc("MJPG")
	_f.store_32(0) # options
	_f.store_16(0) # priorité
	_f.store_16(0) # langue
	_f.store_32(0) # images initiales
	_f.store_32(1) # échelle
	_f.store_32(_ips) # cadence = cadence / échelle
	_f.store_32(0) # début
	_pos_nb_strh = _f.get_position()
	_f.store_32(0) # longueur (images)
	_pos_tampon_strh = _f.get_position()
	_f.store_32(0) # tampon conseillé
	_f.store_32(0xFFFFFFFF) # qualité par défaut
	_f.store_32(0) # taille d'échantillon (variable)
	_f.store_16(0)
	_f.store_16(0)
	_f.store_16(largeur)
	_f.store_16(hauteur)
	_fourcc("strf")
	_f.store_32(40)
	_f.store_32(40) # BITMAPINFOHEADER
	_f.store_32(largeur)
	_f.store_32(hauteur)
	_f.store_16(1) # plans
	_f.store_16(24) # bits par pixel
	_fourcc("MJPG")
	_f.store_32(largeur * hauteur * 3)
	for i in 4:
		_f.store_32(0)
	_fourcc("LIST")
	_pos_taille_movi = _f.get_position()
	_f.store_32(0)
	_pos_movi = _f.get_position()
	_fourcc("movi")
	return true


## Ajoute une image déjà encodée en JPEG.
func ajouter_jpeg(jpeg: PackedByteArray) -> void:
	if _f == null or jpeg.is_empty():
		return
	_index.append(_f.get_position() - _pos_movi)
	_index.append(jpeg.size())
	_fourcc("00dc")
	_f.store_32(jpeg.size())
	_f.store_buffer(jpeg)
	if jpeg.size() % 2 == 1:
		_f.store_8(0) # les morceaux RIFF ont une taille paire
	_plus_grande = maxi(_plus_grande, jpeg.size())
	images += 1


## Ajoute une image (redimensionnée à la taille de la vidéo si besoin).
func ajouter_image(img: Image, qualite := 0.9) -> void:
	if img == null or img.is_empty():
		return
	if img.get_width() != _largeur or img.get_height() != _hauteur:
		img = img.duplicate()
		img.resize(_largeur, _hauteur, Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGB8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGB8)
	ajouter_jpeg(img.save_jpg_to_buffer(qualite))


## Écrit l'index et complète les tailles de l'en-tête.
func fermer() -> void:
	if _f == null:
		return
	var fin_movi := _f.get_position()
	_fourcc("idx1")
	_f.store_32(images * 16)
	for i in images:
		_fourcc("00dc")
		_f.store_32(AVIIF_KEYFRAME)
		_f.store_32(_index[i * 2])
		_f.store_32(_index[i * 2 + 1])
	var fin := _f.get_position()
	_f.seek(4)
	_f.store_32(fin - 8)
	_f.seek(_pos_taille_movi)
	_f.store_32(fin_movi - _pos_movi)
	for p in [_pos_nb_avih, _pos_nb_strh]:
		_f.seek(p)
		_f.store_32(images)
	for p in [_pos_tampon_avih, _pos_tampon_strh]:
		_f.seek(p)
		_f.store_32(_plus_grande + 8)
	_f.close()
	_f = null


func _fourcc(s: String) -> void:
	_f.store_buffer(s.to_ascii_buffer())
