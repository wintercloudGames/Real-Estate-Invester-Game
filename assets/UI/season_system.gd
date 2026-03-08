extends Node

enum Season { SPRING, SUMMER, FALL, WINTER }

var current_season: Season = Season.SPRING
var season_length_months := 3

@onready var rain_notifier = $Rain/RainVisibility
@onready var snow_notifier = $Snow/SnowVisibility
@onready var terrain = $"../HTerrain"
@onready var season: Label = $"../HUD/Month_mod/Season"
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

func _process(delta):
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
	season.text = current_season_to_string()

func current_season_to_string():
	match current_season:
		Season.SPRING:
			return "Spring"
		Season.SUMMER:
			return "Summer"
		Season.FALL:
			return "Fall"
		Season.WINTER:
			return "Winter"

func update_environment_for_season():
	match current_season:
		Season.SPRING:
			set_environment("spring")
			spawn_weather("rain",0.3)
			#terrain.set_snow_visibility(false)
			
		Season.SUMMER:
			set_environment("summer")
			spawn_weather("rain",0.1)
			
		Season.FALL:
			set_environment("fall")
			spawn_weather("rain",0.3)
			
		Season.WINTER:
			set_environment("winter")
			spawn_weather("snow",0.5)


func spawn_weather(effect: String, chance: float):
	var weather_enabled = ProjectSettings.get_setting("game/weather/enabled", true)
	if weather_enabled == false:  # Changed this condition
		# Disable all weather effects if weather is disabled
		rain_node.emitting = false
		snow_node.emitting = false
		$RainSound.stop()
		return
	
	# Always stop both effects first
	rain_node.emitting = false
	snow_node.emitting = false
	$RainSound.stop()

	# Disconnect visibility signals
	if rain_notifier.screen_entered.is_connected(_on_rain_visible):
		rain_notifier.screen_entered.disconnect(_on_rain_visible)
	if rain_notifier.screen_exited.is_connected(_on_rain_invisible):
		rain_notifier.screen_exited.disconnect(_on_rain_invisible)
	if snow_notifier.screen_entered.is_connected(_on_snow_visible):
		snow_notifier.screen_entered.disconnect(_on_snow_visible)
	if snow_notifier.screen_exited.is_connected(_on_snow_invisible):
		snow_notifier.screen_exited.disconnect(_on_snow_invisible)
	var weather_chance = randf()
	match effect:
		"rain":
			if weather_chance < chance:
				# Reconnect only rain signals
				rain_notifier.screen_entered.connect(_on_rain_visible)
				rain_notifier.screen_exited.connect(_on_rain_invisible)
				rain_node.emitting = true
		"snow":
			if weather_chance < chance:
				# Reconnect only snow signals
				snow_notifier.screen_entered.connect(_on_snow_visible)
				snow_notifier.screen_exited.connect(_on_snow_invisible)
				snow_node.emitting = true
func set_environment(season: String):
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var env = camera.environment
	if not env:
		return

	match season:
		"spring":
			env.fog_enabled = false
		"summer":
			env.fog_enabled = false
			env.sky.sky_material.set("sky_color", Color(0.7, 0.9, 1.0))
		"fall":
			env.fog_enabled = true
			env.fog_color = Color(0.7, 0.6, 0.5)
		"winter":
			env.fog_enabled = true
			env.fog_color = Color(0.85, 0.85, 0.9)
	
	# Initialize fog
	if env.fog == null:
		env.fog = Environment.new().fog.duplicate()
	
	# Set seasonal effects
	match season:
		"spring":
			env.fog_enabled = false
		
		"summer":
			env.fog_enabled = false
			if env.sky and env.sky.sky_material:
				env.sky.sky_material.sky_color = Color(0.7, 0.9, 1.0)
		
		"fall":
			env.fog_enabled = true
			env.fog.density = 0.01
			env.fog.albedo = Color(0.7, 0.6, 0.5)
		
		"winter":
			env.fog_enabled = true
			env.fog.density = 0.02
			env.fog.albedo = Color(0.85, 0.85, 0.9)

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
	
