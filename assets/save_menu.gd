extends Panel

@onready var save_and_load: Node = $"../../../Save_and_load"
@onready var ui_layer = $".."  # HUD reference

func _on_save_slot_1_pressed() -> void:
	save_and_load.save_game(1)


func _on_save_slot_2_pressed() -> void:
	save_and_load.save_game(2)


func _on_save_slot_3_pressed() -> void:
	save_and_load.save_game(3)
