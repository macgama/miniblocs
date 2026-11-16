class_name LimiteDemo
extends Node
## Limite d'une partie de l'édition démo : après EditionDemo.JOURS_MAX jours de
## jeu (depuis le premier jour de la partie) ou EditionDemo.HABITANTS_MAX
## habitants, l'écran de fin (FinDemo) s'ouvre et le temps reste en pause.
## On peut encore regarder sa ville, la photographier et la sauvegarder.
## Section de sauvegarde « edition_demo ». Ne fait rien hors de la démo.

signal fin_atteinte(chiffres: Dictionary)
signal message(texte: String)

## Premier jour de la partie (jour absolu de Population.now().day), -1 = pas encore vu.
var jour0 := -1
## La limite a été atteinte (la partie reste figée, même rechargée).
var fin := false
## Fournit {jour, habitants, nom} (terre_main ; remplaçable dans les tests).
var lire: Callable
## Met le temps en pause / lit la vitesse.
var pause: Callable
var vitesse: Callable
var _acc := 0.0
var _rappel := 0.0


func etat() -> Dictionary:
	return lire.call() if lire.is_valid() else {"jour": 0, "habitants": 0}


func jours_joues(e: Dictionary = {}) -> int:
	if e.is_empty():
		e = etat()
	return maxi(int(e.get("jour", 0)) - jour0, 0) if jour0 >= 0 else 0


## Jours et habitants restants avant la fin (pour l'affichage).
func restant() -> Dictionary:
	var e := etat()
	return {"jours": maxi(EditionDemo.JOURS_MAX - jours_joues(e), 0),
		"habitants": maxi(EditionDemo.HABITANTS_MAX - int(e.get("habitants", 0)), 0)}


func verifier() -> void:
	if not EditionDemo.active():
		return
	var e := etat()
	if jour0 < 0:
		jour0 = int(e.get("jour", 0))
	if not fin:
		if EditionDemo.limite_atteinte(jours_joues(e), int(e.get("habitants", 0))):
			fin = true
			_figer()
			var c := e.duplicate()
			c["jours"] = jours_joues(e)
			fin_atteinte.emit(c)
		return
	# Limite déjà atteinte : le temps reste arrêté.
	if vitesse.is_valid() and int(vitesse.call()) > 0:
		_figer()
		if _rappel <= 0.0:
			_rappel = 6.0
			message.emit("C'est la fin de la démo : le temps reste arrêté. Le jeu complet t'attend (liste de souhaits) !")


func _figer() -> void:
	if pause.is_valid():
		pause.call()


func _process(delta: float) -> void:
	_rappel -= delta
	_acc += delta
	if _acc >= 0.5:
		_acc = 0.0
		verifier()


func to_dict() -> Dictionary:
	return {"jour0": jour0, "fin": fin}


func from_dict(d: Dictionary) -> void:
	jour0 = int(d.get("jour0", -1))
	fin = bool(d.get("fin", false))
