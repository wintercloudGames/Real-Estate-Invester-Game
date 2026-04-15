extends Node

enum Season { SPRING, SUMMER, FALL, WINTER }

# Signal to tell the world_settings to change the light
signal lighting_update_requested(color: Color, energy: float)

@export_category("Season Settings")
@export var season_length_months: int = 3
@export var lightning_chance: float = 0.0003
@export var weather_check_time: float = 30.0 # How often to check for weather
@export var weather_trigger_chance: float = 0.1 # 10% chance

@onready var rain_node: GPUParticles3D = $Rain
@onready var snow_node: GPUParticles3D = $Snow
@onready var rain_sound: AudioStreamPlayer = $RainSound
@onready var thunder_sound: AudioStreamPlayer = $ThunderSound
@onready var season_label: Label = $"../HUD/Month_mod/Season"

# Internal references
var lightning_overlay: ColorRect
var current_season: Season = Season.SPRING
var last_month: int = -1
var weather_timer: Timer

func _ready() -> void:
	if not Settings.weather:
		process_mode = Node.PROCESS_MODE_DISABLED
		return

	_setup_lightning_overlay()
	_setup_weather_timer()
	
	# Initial check
	_process_season()

func _setup_weather_timer() -> void:
	weather_timer = Timer.new()
	weather_timer.wait_time = weather_check_time
	weather_timer.autostart = true
	weather_timer.timeout.connect(_on_weather_timer_timeout)
	add_child(weather_timer)

func _setup_lightning_overlay() -> void:
	lightning_overlay = ColorRect.new()
	lightning_overlay.color = Color(1, 1, 1, 0.4)
	lightning_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lightning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lightning_overlay.visible = false
	
	var hud = get_node_or_null("../HUD/UI")
	if hud:
		hud.add_child(lightning_overlay)
	else:
		add_child(lightning_overlay)

func _process(_delta: float) -> void:
	# 1. Handle Lightning
	if Settings.lightning and rain_node.emitting:
		if randf() < lightning_chance:
			trigger_lightning()
	
	# 2. Sync weather nodes to camera
	var cam = get_viewport().get_camera_3d()
	if cam:
		var offset = Vector3(0, 10, 0)
		rain_node.global_position = cam.global_position + offset
		snow_node.global_position = cam.global_position + offset

	# 3. Handle Month/Season changes
	var current_month = Globals.month
	if current_month != last_month:
		last_month = current_month
		_process_season()

func _on_weather_timer_timeout() -> void:
	# Determine weather type based on season
	var effect_type = "rain"
	if current_season == Season.WINTER:
		effect_type = "snow"
	
	# Roll the 10% dice
	spawn_weather(effect_type, weather_trigger_chance)

func _process_season() -> void:
	var month = Globals.month
	var season_index = int((month - 1) / season_length_months) % 4
	current_season = Season.values()[season_index]
	
	if season_label:
		season_label.text = Season.keys()[current_season]
	
	Globals.notify("Season: " + Season.keys()[current_season], Color.CYAN)
	
	update_environment_for_season()
	_update_lighting_values()

func _update_lighting_values() -> void:
	var seasonal_color = Color.WHITE
	var energy = 1.0
	
	match current_season:
		Season.SPRING: seasonal_color = Color(0.9, 1.0, 0.9)
		Season.SUMMER: seasonal_color = Color(1.0, 1.0, 0.8)
		Season.FALL:   seasonal_color = Color(1.0, 0.7, 0.4)
		Season.WINTER: seasonal_color = Color(0.8, 0.9, 1.0)
	
	if rain_node.emitting or snow_node.emitting:
		energy = 0.4 
		
	lighting_update_requested.emit(seasonal_color, energy)

func update_environment_for_season() -> void:
	var world_settings = get_node_or_null("../World_settings")
	if not world_settings or not world_settings.world_environment: 
		return
		
	var env = world_settings.world_environment.environment
	if not env: return

	match current_season:
		Season.SPRING, Season.SUMMER:
			env.fog_enabled = false 
		Season.FALL:
			env.fog_enabled = true
			env.fog_density = 0.005
			env.fog_light_color = Color(0.7, 0.6, 0.5)
		Season.WINTER:
			env.fog_enabled = true
			env.fog_density = 0.01
			env.fog_light_color = Color(0.85, 0.85, 0.9)

func trigger_lightning() -> void:
	lightning_overlay.show()
	await get_tree().create_timer(0.06).timeout
	lightning_overlay.hide()
	await get_tree().create_timer(0.04).timeout
	lightning_overlay.show()
	await get_tree().create_timer(0.06).timeout
	lightning_overlay.hide()
	
	await get_tree().create_timer(randf_range(0.5, 1.5)).timeout
	if !thunder_sound.playing:
		thunder_sound.play()

func spawn_weather(effect: String, chance: float) -> void:
	if not Settings.weather:
		_stop_all_weather()
		return 

	var roll = randf()
	var success = roll < chance
	
	if success:
		if effect == "rain" and not rain_node.emitting:
			_stop_all_weather()
			rain_node.emitting = true
			if !rain_sound.playing: rain_sound.play()
			Globals.notify("Weather Update: It has started raining.", Color.AQUA)
		
		elif effect == "snow" and not snow_node.emitting:
			_stop_all_weather()
			snow_node.emitting = true
			Globals.notify("Weather Update: It has started snowing.", Color.SNOW)
	else:
		# If the roll fails, we clear the current weather
		if (effect == "rain" and rain_node.emitting) or (effect == "snow" and snow_node.emitting):
			_stop_all_weather()
			Globals.notify("Weather Update: The skies have cleared.", Color.WHITE)
	
	_update_lighting_values()

func _stop_all_weather() -> void:
	rain_node.emitting = false
	snow_node.emitting = false
	if rain_sound.playing:
		rain_sound.stop()
