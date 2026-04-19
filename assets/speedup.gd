extends Control

@onready var game_speed_label: Label = $GameSpeed_text
@onready var h_slider: HSlider = $HSlider

# Game speed control variables
var custom_time_scale: float = 1.0  # Tracks the current speed set by slider
var min_time_scale: float = 1.0    # Minimum speed
var max_time_scale: float = 20.0   # Maximum allowed speed
var time_scale_step: float = 1.0   # Slider increment/decrement step

func _ready() -> void:
	if OS.is_debug_build():
		visible = true
	# Initialize slider properties
	h_slider.min_value = min_time_scale
	h_slider.max_value = max_time_scale
	h_slider.step = time_scale_step
	h_slider.value = custom_time_scale
	
	# Set initial label text and time scale
	_update_label_text()
	Engine.time_scale = custom_time_scale

func _on_h_slider_value_changed(value: float) -> void:
	# Update time scale when slider changes
	custom_time_scale = clamp(value, min_time_scale, max_time_scale)
	Engine.time_scale = custom_time_scale
	_update_label_text()

func _update_label_text() -> void:
	# Update label to reflect current speed
	game_speed_label.text = "Speed: %.1fx" % custom_time_scale
