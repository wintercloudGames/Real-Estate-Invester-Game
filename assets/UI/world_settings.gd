extends Node

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var directional_light_3d: DirectionalLight3D = $DirectionalLight3D

enum GAME_QUALITY {
	LOW,   
	MEDIUM, 
	HIGH,   
	ULTRA   
}
var current_quality: GAME_QUALITY = GAME_QUALITY.MEDIUM
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_quality_settings()
	apply_quality_settings()

func load_graphics_preset() -> String:
	var file_path = OS.get_executable_path().get_base_dir().path_join("settings.json")
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if typeof(data) == TYPE_DICTIONARY and data.has("graphics_quality"):
				return data["graphics_quality"]
	return "Medium"  # default if file not found


func apply_quality_settings():
	var env := world_environment.environment
	
	match current_quality:
		GAME_QUALITY.LOW:
			env.glow_enabled = false
			env.ssao_enabled = false
			
			env.fog_enabled = false
			directional_light_3d.shadow_enabled = false
			directional_light_3d.directional_shadow_max_distance = 100
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)

		GAME_QUALITY.MEDIUM:
			env.glow_enabled = false
			env.ssao_enabled = true
			
			env.fog_enabled = true
			directional_light_3d.shadow_enabled = true
			directional_light_3d.directional_shadow_max_distance = 300
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 1)

		GAME_QUALITY.HIGH:
			env.glow_enabled = true
			env.ssao_enabled = true
			
			env.fog_enabled = true
			directional_light_3d.shadow_enabled = true
			directional_light_3d.directional_shadow_max_distance = 600
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 2)

		GAME_QUALITY.ULTRA:
			env.glow_enabled = true
			env.ssao_enabled = true
			
			env.fog_enabled = true
			directional_light_3d.shadow_enabled = true
			directional_light_3d.directional_shadow_max_distance = 1000
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 4)

func load_quality_settings():
	var quality_preset = load_graphics_preset()
	match quality_preset:
		"Low": current_quality = GAME_QUALITY.LOW
		"Medium": current_quality = GAME_QUALITY.MEDIUM
		"High": current_quality = GAME_QUALITY.HIGH
		"Ultra": current_quality = GAME_QUALITY.ULTRA
		_: current_quality = GAME_QUALITY.MEDIUM
