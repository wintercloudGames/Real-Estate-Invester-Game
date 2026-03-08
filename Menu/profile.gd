extends TextureButton

signal profile_loaded(slot: int)
signal profile_created()
signal delete_requested(slot: int)
signal rename_requested(slot: int)

@export var profile_name := "Profile"
@export var save_slot := 0
@export var new_profile_text := "New Profile"

func _ready() -> void:
	update_display()

func update_display() -> void:
	var label = get_node("%Label") as Label
	var texture = get_node("%TextureRect") as TextureRect
	
	if SaveAndLoad.save_file_exists(save_slot):
		# Get the custom save name
		var save_name = get_save_name(save_slot)
		label.text = save_name
		texture.texture = load("res://assets/UI/icons/village.png")
		$Delete_button.visible = true
		$Rename_button.visible = true
	else:
		$Delete_button.visible = false
		$Rename_button.visible = false
		label.text = new_profile_text
		texture.texture = load("res://assets/UI/icons/health-normal.png")

func get_save_name(slot: int) -> String:
	var save_data = get_save_data(slot)
	return save_data.get("save_name", "Profile " + str(slot + 1))

func get_save_data(slot: int) -> Dictionary:
	var save_path = SaveAndLoad.get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		return {}
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		return {}
	
	var data = json.get_data()
	if not data or not data.has("Globals"):
		return {}
	
	# Return specific stats for display
	return {
		"save_name": data["Globals"].get("save_name", "Profile " + str(slot + 1)),
		"money": data["Globals"].get("money", 0),
		"year": data["Globals"].get("year", 1),
		"difficulty": data["Globals"].get("difficulty", 1)
	}

func _on_pressed() -> void:
	if SaveAndLoad.save_file_exists(save_slot):
		profile_loaded.emit(save_slot)
	else:
		profile_created.emit()

func _on_mouse_entered() -> void:
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.15)
	tween.parallel().tween_property(self, "modulate", Color(1.1, 1.1, 1.1), 0.15)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	if SaveAndLoad.save_file_exists(save_slot):
		$Game_stats.visible = true
		update_game_stats()

func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	$Game_stats.visible = false

func update_game_stats() -> void:
	var stats = get_save_data(save_slot)
	var game_stats_label = $Game_stats/MarginContainer/Label as Label
	if game_stats_label:
		var money = stats.get("money", 0)
		var year = stats.get("year", 1)
		var difficulty = stats.get("difficulty", 1)
		# Map difficulty integer to descriptive string
		var difficulty_text = ["Easy", "Normal", "Hard", "Nightmare"][difficulty]
		game_stats_label.text = "Money: $%s\nYear: %d\nDifficulty: %s" % [
			add_comma_to_int(money), year, difficulty_text
		]


func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_delete_button_pressed() -> void:
	delete_requested.emit(save_slot)

func _on_rename_button_pressed() -> void:
	rename_requested.emit(save_slot)
