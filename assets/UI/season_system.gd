extends Node

enum Season { SPRING, SUMMER, FALL, WINTER }

# Signal to tell the world_settings to change the light
signal lighting_update_requested(color: Color, energy: float)

var current_season: Season = Season.SPRING
var season_length_months := 3

@onready var rain_notifier = $Rain/RainVisibility
@onready var snow_notifier = $Snow/SnowVisibility
@onready var rain_node: GPUParticles3D = $Rain
@onready var snow_node: GPUParticles3D = $Snow

var last_month = -1

func _ready() -> void:
	if not Settings.weather:
		process_mode = Node.PROCESS_MODE_DISABLED

	rain_notifier.screen_entered.connect(_on_rain_visible)
	rain_notifier.screen_exited.connect(_on_rain_invisible)
	snow_notifier.screen_entered.connect(_on_snow_visible)
	snow_notifier.screen_exited.connect(_on_snow_invisible)

func _on_rain_visible():
	rain_node.emitting = true

func _on_rain_invisible():
	rain_node.emitting = false

func _on_snow_visible():
	snow_node.emitting = true

func _on_snow_invisible():
	snow_node.emitting = false

func _process(_delta):
	if Settings.weather == false:
		return
	if Settings.lightning == true:
		maybe_trigger_lightning()
		
	var current_month = Globals.month
	
	if rain_node.emitting == false:
		$RainSound.stop()
		
	if current_month != last_month:
		last_month = current_month
		_process_season()

func _process_season():
	var month = Globals.month
	current_season = Season.values()[(month - 1) / season_length_months]
	update_environment_for_season()
	_update_lighting_values() # Trigger the light change

func _update_lighting_values():
	var seasonal_color = Color.WHITE
	var energy = 1.0
	
	match current_season:
		Season.SPRING: seasonal_color = Color(0.9, 1.0, 0.9) # Light Green
		Season.SUMMER: seasonal_color = Color(1.0, 1.0, 0.8) # Bright Yellow
		Season.FALL:   seasonal_color = Color(1.0, 0.7, 0.4) # Warm Orange
		Season.WINTER: seasonal_color = Color(0.8, 0.9, 1.0) # Cold Blue
	
	# Darken if it's currently raining or snowing
	if rain_node.emitting or snow_node.emitting:
		energy = 0.3 
		
	lighting_update_requested.emit(seasonal_color, energy)

func spawn_weather(effect: String, chance: float):
	var weather_enabled = ProjectSettings.get_setting("game/weather/enabled", true)
	if weather_enabled == false:
		rain_node.emitting = false
		snow_node.emitting = false
		return 
	
	rain_node.emitting = false
	snow_node.emitting = false

	var weather_chance = randf()
	match effect:
		"rain":
			if weather_chance < chance:
				rain_node.emitting = true
		"snow":
			if weather_chance < chance:
				snow_node.emitting = true
	
	_update_lighting_values() # Update light energy based on new weather

func update_environment_for_season():
	var camera := get_viewport().get_camera_3d()
	if not camera or not camera.environment: return
	var env = camera.environment

	match current_season:
		Season.SPRING, Season.SUMMER:
			env.fog_enabled = false 
		Season.FALL:
			env.fog_enabled = true
			env.fog_density = 0.01
			env.fog_light_color = Color(0.7, 0.6, 0.5)
		Season.WINTER:
			env.fog_enabled = true
			env.fog_density = 0.02
			env.fog_light_color = Color(0.85, 0.85, 0.9)

func maybe_trigger_lightning():
	if current_season != Season.SUMMER and current_season != Season.SPRING:
		return
	if rain_node.emitting and randf() < 0.0003:
		trigger_lightning()

func trigger_lightning():
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.6)
	flash.anchor_left = 0
	flash.anchor_top = 0
	flash.anchor_right = 1
	flash.anchor_bottom = 1
	flash.offset_left = 0
	flash.offset_top = 0
	flash.offset_right = 0
	flash.offset_bottom = 0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	$"../HUD/UI".add_child(flash)
	await get_tree().create_timer(0.05).timeout
	flash.visible = false
	await get_tree().create_timer(0.05).timeout
	flash.visible = true
	await get_tree().create_timer(0.05).timeout
	flash.queue_free()
	await get_tree().create_timer(randf_range(0.3, 1.0)).timeout
	$ThunderSound.play()
