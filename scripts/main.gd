extends Node3D
## Scène principale : relie l'interface à la grille de la ville.

@onready var city: Node3D = $City
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	city.stats_changed.connect(hud.update_stats)
	hud.tool_selected.connect(func(t: int) -> void: city.set_tool(t))
	hud.save_requested.connect(_on_save)
	hud.load_requested.connect(_on_load)
	hud.clear_requested.connect(_on_clear)
	city._emit_stats()


func _on_save() -> void:
	hud.show_message("Ville sauvegardée." if city.save_city() else "Échec de la sauvegarde.")


func _on_load() -> void:
	hud.show_message("Ville chargée." if city.load_city() else "Aucune sauvegarde trouvée.")


func _on_clear() -> void:
	city.clear_city()
	hud.show_message("Carte effacée.")
