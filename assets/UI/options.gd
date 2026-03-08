extends Control

# Volume variables
var master_volume := 0.0
var music_volume := 0.0
var efx_volume := 0.0
var ui_scale := 0.0

func _ready():
	# Load saved volume levels or use defaults
	master_volume = Settings.Master
	music_volume = Settings.Music
	efx_volume = Settings.SFX
	ui_scale = Settings.UI_scale
	# Set slider values
	$ScrollContainer/VBoxContainer/Master_slider.value = master_volume
	$ScrollContainer/VBoxContainer/Music_slider.value = music_volume
	$ScrollContainer/VBoxContainer/Sound_slider.value = efx_volume
	$ScrollContainer/VBoxContainer/UI_Scale.value = ui_scale

func _on_master_slider_value_changed(value: float) -> void:
	Settings.Master = value
	# Apply to audio bus
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	# Mute if volume is very low (optional)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value < 0.01)
	# Save settings
	Settings.save_settings()

func _on_music_slider_value_changed(value: float) -> void:
	Settings.Music = value
	# Apply to audio bus
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
	# Mute if volume is very low (optional)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), value < 0.01)
	# Save settings
	Settings.save_settings()

func _on_sound_slider_value_changed(value: float) -> void:
	Settings.SFX = value
	# Apply to audio bus
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
	# Mute if volume is very low (optional)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), value < 0.01)
	# Save settings
	Settings.save_settings()
func _on_menu_button_pressed() -> void:
	get_tree().quit()

func _on_resolution_item_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_size(Vector2i(1920,1080))
		1:
			DisplayServer.window_set_size(Vector2i(1600,900))
		2:
			DisplayServer.window_set_size(Vector2i(1280,1080))

func _on_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on ==true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_ui_scale_value_changed(value: float) -> void:
	Settings.UI_scale = value
