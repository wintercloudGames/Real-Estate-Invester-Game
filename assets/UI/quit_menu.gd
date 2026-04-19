extends Panel

@onready var save_and_load: SaveAndLoad = get_node("/root/SaveAndLoad")  # Get the autoload
@onready var ui_layer = $".."  # HUD reference
@export var current_slot: int = 0  # Default slot, can be changed



func save_game():
	current_slot = save_and_load.current_save_slot
	#save_and_load.current_save_slot = current_slot
	if save_and_load.save_game():
		Globals.notify("Game Saved! in slot: "+ str(save_and_load.current_save_slot), Color.GREEN)
	else:
		Globals.notify("Save Failed!", Color.RED)


func _on_save_game_pressed() -> void:
	save_game()
