extends Panel

@onready var save_and_load: SaveAndLoad = get_node("/root/SaveAndLoad")  # Get the autoload
@onready var ui_layer = $".."  # HUD reference
@export var current_slot: int = 0  # Default slot, can be changed


func show_floating_label(text: String, color: Color = Color.WHITE):
	if ui_layer:
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.position = Vector2(-100, 200)
		ui_layer.add_child.call_deferred(label)

		# Timing variables - adjust these to change the behavior
		var rise_duration = 1.5      # Time to move upward (seconds)
		var display_duration = 2.0   # Time to stay visible before fading (seconds)
		var fade_duration = 1.0      # Time to fade out (seconds)
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		
		# Move upward slowly
		tween.tween_property(label, "position:y", label.position.y - 30, rise_duration)
		
		# Stay visible, then fade out slowly
		tween.tween_property(label, "modulate:a", 0, fade_duration).set_delay(rise_duration + display_duration)
		
		# Remove after all animations complete
		tween.tween_callback(label.queue_free).set_delay(rise_duration + display_duration + fade_duration)

func _on_save_delete_pressed() -> void:
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Delete this save permanently?"
	confirm_dialog.confirmed.connect(_delete_confirmed)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _delete_confirmed():
	if save_and_load.delete_profile(current_slot):
		show_floating_label("Profile Deleted", Color.RED)
		# Additional cleanup if needed
	else:
		show_floating_label("Delete Failed!", Color.RED)

func save_game():
	current_slot = save_and_load.current_save_slot
	#save_and_load.current_save_slot = current_slot
	if save_and_load.save_game():
		show_floating_label("Game Saved! in slot: "+ str(save_and_load.current_save_slot), Color.GREEN)
	else:
		show_floating_label("Save Failed!", Color.RED)


func _on_save_game_pressed() -> void:
	save_game()
