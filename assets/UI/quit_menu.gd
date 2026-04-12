extends Panel

@onready var save_and_load: SaveAndLoad = get_node("/root/SaveAndLoad")  # Get the autoload
@onready var ui_layer = $".."  # HUD reference
@export var current_slot: int = 0  # Default slot, can be changed



func _on_save_delete_pressed() -> void:
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Delete this save permanently?"
	confirm_dialog.confirmed.connect(_delete_confirmed)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _delete_confirmed():
	if save_and_load.delete_profile(current_slot):
		Globals.notify("Profile Deleted", Color.RED)
		# Additional cleanup if needed
	else:
		Globals.notify("Delete Failed!", Color.RED)

func save_game():
	current_slot = save_and_load.current_save_slot
	#save_and_load.current_save_slot = current_slot
	if save_and_load.save_game():
		Globals.notify("Game Saved! in slot: "+ str(save_and_load.current_save_slot), Color.GREEN)
	else:
		Globals.notify("Save Failed!", Color.RED)


func _on_save_game_pressed() -> void:
	save_game()
