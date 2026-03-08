extends Panel

@onready var save_and_load: Node = $"../../../Save_and_load"
@onready var ui_layer = $".."  # HUD reference


func _on_load_slot_1_pressed() -> void:
	save_and_load.load_game(1)


func _on_load_slot_2_pressed() -> void:
	save_and_load.load_game(2)


func _on_load_slot_3_pressed() -> void:
	save_and_load.load_game(3)
