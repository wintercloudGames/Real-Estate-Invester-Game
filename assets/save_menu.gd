extends Panel

@onready var save_and_load: Node = $"../../../Save_and_load"
@onready var ui_layer = $".."  # HUD reference

func _on_save_slot_1_pressed() -> void:
	save_and_load.save_game(1)


func _on_save_slot_2_pressed() -> void:
	save_and_load.save_game(2)


func _on_save_slot_3_pressed() -> void:
	save_and_load.save_game(3)

func show_floating_label(text: String, color: Color = Color.WHITE):
	if ui_layer:
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.set_position(Vector2(0, -50))
		ui_layer.add_child(label)

		var tween = get_tree().create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5)
		tween.tween_property(label, "modulate:a", 0, 1.5)
		tween.tween_callback(label.queue_free)
