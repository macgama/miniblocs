class_name Personnage
extends CharacterBody3D
## Personnage qui marche au sol : relief, routes, ponts et tout ce qui a une
## collision (bâtiments…). Il nage dans l'eau profonde.
##
## Le personnage ne lit jamais le clavier lui-même : il obéit à `commande`,
## remplie par un contrôleur (ici VueSol, plus tard le réseau pour les autres
## joueurs). `etat()` / `appliquer_etat()` donnent tout ce qu'il faut pour le
## synchroniser en multijoueur.

## Couche de rendu du corps : la caméra 1re personne ne l'affiche pas.
const COUCHE_CORPS := 1 << 19
const TAILLE := 1.75
const YEUX := 1.62
const RAYON := 0.3

@export var vitesse_marche := 4.5
@export var vitesse_course := 10.0
@export var vitesse_nage := 2.5
@export var impulsion_saut := 4.8
@export var gravite := 18.0
## Niveau de la surface de l'eau (m).
@export var niveau_eau := -0.1

## Ordres du contrôleur :
## avance : Vector2 (x = droite, y = avant), entre -1 et 1
## cap : orientation voulue en radians (0 = vers -Z, comme la caméra de gestion)
## saut, course : bool
var commande := {"avance": Vector2.ZERO, "cap": 0.0, "saut": false, "course": false}
## Vrai tant que le sol sous le personnage n'est pas encore chargé : il attend sur place.
var en_attente := false
var nage := false
## Couleur du haut (pour distinguer les joueurs plus tard).
var couleur := Color("d9653b")

var _corps: Node3D
var _jambes: Array[Node3D] = []
var _bras: Array[Node3D] = []
var _phase := 0.0


func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	floor_constant_speed = true
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RAYON
	capsule.height = TAILLE
	forme.shape = capsule
	forme.position.y = TAILLE * 0.5
	add_child(forme)
	_construire_corps()


func _physics_process(delta: float) -> void:
	var cap: float = commande.get("cap", 0.0)
	var avance: Vector2 = commande.get("avance", Vector2.ZERO)
	if avance.length() > 1.0:
		avance = avance.normalized()
	if en_attente:
		velocity = Vector3.ZERO
		return

	# Direction voulue dans le plan du sol, tournée selon le cap.
	var dir := Vector3(avance.x, 0.0, -avance.y).rotated(Vector3.UP, cap)
	var profondeur := niveau_eau - global_position.y
	nage = profondeur > 1.15
	var vitesse := vitesse_nage if nage else (vitesse_course if commande.get("course", false) else vitesse_marche)
	var cible := dir * vitesse
	var reactivite := 10.0 if is_on_floor() or nage else 2.5
	velocity.x = lerpf(velocity.x, cible.x, clampf(delta * reactivite, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, cible.z, clampf(delta * reactivite, 0.0, 1.0))

	if nage:
		# Flotte la tête hors de l'eau ; Espace pour remonter sur une berge.
		var surface := niveau_eau - 1.3
		velocity.y = lerpf(velocity.y, (surface - global_position.y) * 3.0, clampf(delta * 4.0, 0.0, 1.0))
		if commande.get("saut", false):
			velocity.y = 3.0
	else:
		if not is_on_floor():
			velocity.y -= gravite * delta
		elif commande.get("saut", false):
			velocity.y = impulsion_saut
	move_and_slide()

	# Le corps se tourne vers la marche (ou vers le cap à l'arrêt).
	var plat := Vector2(velocity.x, velocity.z)
	if plat.length() > 0.3:
		var vise := atan2(-velocity.x, -velocity.z)
		_corps.rotation.y = lerp_angle(_corps.rotation.y, vise, clampf(delta * 12.0, 0.0, 1.0))
	_animer(delta, plat.length())


## Place le personnage (pieds au point donné) et l'arrête.
func teleporter(p: Vector3, cap := 0.0) -> void:
	global_position = p
	velocity = Vector3.ZERO
	commande.cap = cap
	if _corps:
		_corps.rotation.y = cap


## Tourne le corps tout de suite vers le cap (vue à la 1re personne).
func aligner_corps() -> void:
	_corps.rotation.y = commande.get("cap", 0.0)


## Tout ce qu'un autre joueur doit recevoir pour afficher ce personnage.
func etat() -> Dictionary:
	return {
		"x": global_position.x, "y": global_position.y, "z": global_position.z,
		"vx": velocity.x, "vy": velocity.y, "vz": velocity.z,
		"cap": float(commande.get("cap", 0.0)), "corps": _corps.rotation.y,
		"couleur": couleur.to_html(false),
	}


func appliquer_etat(d: Dictionary) -> void:
	global_position = Vector3(d.get("x", 0.0), d.get("y", 0.0), d.get("z", 0.0))
	velocity = Vector3(d.get("vx", 0.0), d.get("vy", 0.0), d.get("vz", 0.0))
	commande.cap = float(d.get("cap", 0.0))
	_corps.rotation.y = float(d.get("corps", 0.0))
	if d.has("couleur"):
		couleur = Color(String(d.couleur))


# --- Corps low-poly -------------------------------------------------------------

func _construire_corps() -> void:
	_corps = Node3D.new()
	_corps.name = "Corps"
	add_child(_corps)
	var peau := Color("e8b48f")
	var pantalon := Color("2f4a6d")
	# Jambes et bras pivotent à la hanche et à l'épaule.
	for cote in [-1.0, 1.0]:
		var hanche := Node3D.new()
		hanche.position = Vector3(0.1 * cote, 0.88, 0.0)
		_corps.add_child(hanche)
		_bloc(hanche, Vector3(0.0, -0.42, 0.0), Vector3(0.15, 0.84, 0.18), pantalon)
		_bloc(hanche, Vector3(0.0, -0.84, -0.04), Vector3(0.16, 0.08, 0.26), Color("3a3a3a"))
		_jambes.append(hanche)
		var epaule := Node3D.new()
		epaule.position = Vector3(0.28 * cote, 1.42, 0.0)
		_corps.add_child(epaule)
		_bloc(epaule, Vector3(0.0, -0.3, 0.0), Vector3(0.12, 0.6, 0.13), couleur)
		_bloc(epaule, Vector3(0.0, -0.63, 0.0), Vector3(0.11, 0.1, 0.11), peau)
		_bras.append(epaule)
	_bloc(_corps, Vector3(0.0, 1.16, 0.0), Vector3(0.44, 0.58, 0.24), couleur)
	_bloc(_corps, Vector3(0.0, 1.6, 0.0), Vector3(0.26, 0.28, 0.26), peau)
	_bloc(_corps, Vector3(0.0, 1.76, 0.02), Vector3(0.28, 0.07, 0.3), Color("4a3426"))
	# Petit nez : on voit de quel côté il regarde.
	_bloc(_corps, Vector3(0.0, 1.58, -0.14), Vector3(0.05, 0.06, 0.04), peau.darkened(0.1))


func _bloc(parent: Node3D, pos: Vector3, taille: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = taille
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	box.material = mat
	mi.mesh = box
	mi.position = pos
	mi.layers = COUCHE_CORPS
	parent.add_child(mi)


func _animer(delta: float, vitesse: float) -> void:
	var ampleur := clampf(vitesse / vitesse_marche, 0.0, 1.6) * 0.55
	if not is_on_floor() and not nage:
		ampleur = 0.15
	_phase += delta * (4.0 + vitesse * 1.3)
	var a := sin(_phase) * ampleur
	if ampleur < 0.02:
		a = 0.0
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		_jambes[i].rotation.x = lerpf(_jambes[i].rotation.x, a * s, clampf(delta * 14.0, 0.0, 1.0))
		_bras[i].rotation.x = lerpf(_bras[i].rotation.x, -a * s * 0.8, clampf(delta * 14.0, 0.0, 1.0))
