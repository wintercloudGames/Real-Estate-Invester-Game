extends Node

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var directional_light_3d: DirectionalLight3D = $DirectionalLight3D

@onready var season_system = $"../Season_System"

enum GAME_QUALITY {
	LOW,   
	MEDIUM, 
	HIGH,   
	ULTRA   
}

var current_quality: GAME_QUALITY = GAME_QUALITY.MEDIUM

func _ready() -> void:
	# Ensure the environment is a unique instance so changes don't overwrite the resource file
	if world_environment.environment:
		world_environment.environment = world_environment.environment.duplicate()
	
	load_quality_settings()
	apply_quality_settings()
	
	# Connect to the season system to handle seasonal colors and storm darkness
	if season_system:
		season_system.lighting_update_requested.connect(_on_lighting_update)

# This function handles the smooth transition for seasonal colors and weather dimming
func _on_lighting_update(new_color: Color, energy: float):
	var tween = create_tween()
	tween.set_parallel(true)
	# Smoothly transition color and energy over 2 seconds
	tween.tween_property(directional_light_3d, "light_color", new_color, 2.0)
	tween.tween_property(directional_light_3d, "light_energy", energy, 2.0)

func load_graphics_preset() -> String:
	var file_path = OS.get_executable_path().get_base_dir().path_join("settings.json")
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if typeof(data) == TYPE_DICTIONARY and data.has("graphics_quality"):
				return data["graphics_quality"]
	return "Medium"

func apply_quality_settings():
	var env := world_environment.environment
	var viewport := get_viewport()
	
	match current_quality:
		GAME_QUALITY.LOW:
			env.glow_enabled = false
			env.ssao_enabled = false
			env.fog_enabled = false
			directional_light_3d.shadow_enabled = false
			directional_light_3d.directional_shadow_max_distance = 100
			viewport.msaa_3d = Viewport.MSAA_DISABLED

		GAME_QUALITY.MEDIUM:
			env.glow_enabled = false
			env.ssao_enabled = true
			env.fog_enabled = true
			directional_light_3d.shadow_enabled = true
			directional_light_3d.directional_shadow_max_distance = 300
			viewport.msaa_3d = Viewport.MSAA_2X

		GAME_QUALITY.HIGH:
			env.glow_enabled = true
			env.ssao_enabled = true
			env.fog_enabled = true
			directional_light_3d.shadow_enabled = true
			directional_light_3d.directional_shadow_max_distance = 600 
			viewport.msaa_3d = Viewport.MSAA_4X

		GAME_QUALITY.ULTRA:
			env.glow_enabled = true
			env.ssao_enabled = true
			env.fog_enabled = true
			directional_light_3d.shadow_enabled = true
			directional_light_3d.directional_shadow_max_distance = 1000
			viewport.msaa_3d = Viewport.MSAA_8X

func load_quality_settings():
	var quality_preset = load_graphics_preset()
	match quality_preset:
		"Low": current_quality = GAME_QUALITY.LOW
		"Medium": current_quality = GAME_QUALITY.MEDIUM
		"High": current_quality = GAME_QUALITY.HIGH
		"Ultra": current_quality = GAME_QUALITY.ULTRA
		_: current_quality = GAME_QUALITY.MEDIUM
