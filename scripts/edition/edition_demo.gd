class_name EditionDemo
extends RefCounted
## Édition démo de MiniBlocs (Steam Next Fest) : le même jeu, avec des limites.
##
## Elle est active quand l'exécutable a été exporté avec le préréglage
## « Windows Demo » (export_presets.cfg, fonctionnalité « demo »), ou quand on
## lance le jeu avec l'argument `-- --edition-demo` (pour tester depuis Godot).
##
## Ce qui change (docs/demo-next-fest.md) :
## - menu principal : Démo guidée, Nouvelle partie, Charger, Options, Crédits,
##   Liste de souhaits, Quitter (pas de scénarios, carte entre amis, Atelier ni succès) ;
## - en jeu : parc de loisirs, zoo, musée, spectacles, club de sport, tourisme
##   et partage Workshop sont « dans le jeu complet » ; pas d'époques (on démarre
##   aujourd'hui) ; pas de succès Steam (Valve conseille de les couper dans une démo) ;
## - chaque partie s'arrête après JOURS_MAX jours de jeu ou HABITANTS_MAX
##   habitants : écran de fin (FinDemo) avec l'appel à la liste de souhaits ;
## - sauvegardes à part (dossier « MiniBlocs Demo », project.godot).

## App ID du jeu complet sur Steam (0 tant que Steamworks ne l'a pas donné).
## À remplir dès qu'il existe : le bouton « Liste de souhaits » ouvre alors la
## page Steam du jeu (dans l'overlay Steam si GodotSteam est là).
const APP_ID := 0
## Page ouverte tant qu'il n'y a pas d'App ID.
const SITE := "https://www.manigames.online"

## Limites d'une partie de la démo (comptées depuis le premier jour de la partie).
const JOURS_MAX := 120
const HABITANTS_MAX := 1000

## Boutons du menu principal absents de la démo.
const MENU_ABSENTS := ["scenarios", "amis", "atelier", "succes"]
## Boutons de la barre du bas (TerreHud.CATEGORIES) réservés au jeu complet.
const PANNEAUX_VERROUILLES := ["parc_editeur", "parc", "zoo", "musee", "spectacles", "club", "tourisme", "patrimoine", "partage", "succes"]
## Onglets du catalogue Construire (BuildingCatalog.CATEGORIES) cachés dans la démo.
const CATALOGUE_VERROUILLE := ["parc", "zoo", "spectacles", "tourisme", "patrimoine"]
## Raccourcis Maj + touche des panneaux verrouillés.
const TOUCHES_MAJ := {KEY_A: "Créer un parc", KEY_G: "Parc de loisirs", KEY_Z: "Zoo", KEY_C: "Musée",
	KEY_X: "Spectacles", KEY_B: "Club de sport", KEY_D: "Tourisme"}

## Force l'édition démo (tests) : -1 = selon l'exécutable, 0 = non, 1 = oui.
static var forcee := -1


static func active() -> bool:
	if forcee >= 0:
		return forcee == 1
	return OS.has_feature("demo") or OS.get_cmdline_user_args().has("--edition-demo") \
		or OS.get_cmdline_args().has("--edition-demo")


static func menu_visible(id: String) -> bool:
	return not (active() and MENU_ABSENTS.has(id))


static func panneau_verrouille(id: String) -> bool:
	return active() and PANNEAUX_VERROUILLES.has(id)


static func categorie_verrouillee(id: String) -> bool:
	return active() and CATALOGUE_VERROUILLE.has(id)


## Nom du panneau si cette touche ouvre un panneau verrouillé, sinon "".
static func touche_verrouillee(k: InputEventKey) -> String:
	if not active() or k == null or not k.pressed or k.echo or k.ctrl_pressed or k.alt_pressed:
		return ""
	if k.shift_pressed and TOUCHES_MAJ.has(k.keycode):
		return String(TOUCHES_MAJ[k.keycode])
	if not k.shift_pressed and k.keycode == KEY_F6:
		return "Succès"
	if k.keycode == KEY_F3:
		return "Carte entre amis"
	return ""


static func texte_verrou(nom: String) -> String:
	return "%s : dans le jeu complet. Ajoute MiniBlocs à ta liste de souhaits sur Steam pour ne pas le rater !" % nom


## La partie a-t-elle atteint la limite de la démo ?
static func limite_atteinte(jours: int, habitants: int) -> bool:
	return active() and (jours >= JOURS_MAX or habitants >= HABITANTS_MAX)


static func url_magasin() -> String:
	if APP_ID > 0:
		return "https://store.steampowered.com/app/%d/" % APP_ID
	return SITE


## Ouvre la page du jeu : overlay Steam si possible, sinon le navigateur.
## Renvoie l'adresse ouverte (ou « overlay »).
static var derniere_ouverture := ""
static var ouvrir_vraiment := true


static func ouvrir_magasin() -> String:
	if APP_ID > 0 and SteamPont.magasin(APP_ID):
		derniere_ouverture = "overlay"
		return derniere_ouverture
	derniere_ouverture = url_magasin()
	if ouvrir_vraiment:
		OS.shell_open(derniere_ouverture)
	return derniere_ouverture
