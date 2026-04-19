extends TextureButton

signal profile_loaded(slot: int)
signal profile_created(slot: int) 
signal delete_requested(slot: int)
signal rename_requested(slot: int)

@export var profile_name := "Profile"
@export var save_slot := 0
@export var new_profile_text := "New Profile"

func _ready() -> void:
	update_display()

func update_display() -> void:
	var label = get_node("%Label") as Label #
	var texture = get_node("%TextureRect") as TextureRect
	
	if SaveAndLoad.save_file_exists(save_slot):
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
	if not file: return {}
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK: return {}
	
	var data = json.get_data()
	if not data or not data.has("Globals"): return {}
	
	var g = data["Globals"]
	
	# Returning cleaned data for the stats display
	return {
		"save_name": g.get("save_name", "Profile " + str(slot + 1)),
		"current_game_mode": int(g.get("current_game_mode", 0)), # Force to int
		"year": g.get("year", 1)
	}

func _on_pressed() -> void:
	if SaveAndLoad.save_file_exists(save_slot):
		profile_loaded.emit(save_slot)
	else:
		profile_created.emit(save_slot)

func _on_mouse_entered() -> void:
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.15)
	tween.parallel().tween_property(self, "modulate", Color(1.1, 1.1, 1.1), 0.15)
	
	if SaveAndLoad.save_file_exists(save_slot):
		$Game_stats.visible = true
		update_game_stats()

func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	tween.parallel().tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.2)
	$Game_stats.visible = false

func update_game_stats() -> void:
	var stats = get_save_data(save_slot)
	var game_stats_label = $Game_stats/MarginContainer/Label as Label
	
	if game_stats_label:
		# Use int() to ensure we can match against the numbers
		var mode_int = int(stats.get("current_game_mode", 0)) 
		var year = stats.get("year", 1)
		
		var mode_text = ""
		match mode_int:
			0: mode_text = "Story"
			1: mode_text = "Mission"
			2: mode_text = "Freeplay"
			_: mode_text = "Unknown"
		
		game_stats_label.text = "Mode: %s\nYear: %d" % [mode_text, year]

func _on_delete_button_pressed() -> void:
	delete_requested.emit(save_slot)

func _on_rename_button_pressed() -> void:
	rename_requested.emit(save_slot)
