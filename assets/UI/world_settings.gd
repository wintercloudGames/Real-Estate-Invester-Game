extends Node

signal night_mode_changed(is_night: bool)

@onready var world_environment: WorldEnvironment = get_node_or_null("WorldEnvironment")
@onready var directional_light_3d: DirectionalLight3D = get_node_or_null("DirectionalLight3D")
@onready var season_system = $"../Season_System"

enum GAME_QUALITY { LOW, MEDIUM, HIGH, ULTRA }
var current_quality: GAME_QUALITY = GAME_QUALITY.MEDIUM
var is_night: bool = false
# --- SETTINGS ---
@export var cycle_enabled: bool = true

enum SUN_STATE { RISING, STAYING, SETTING, NIGHT }
var current_state = SUN_STATE.RISING
var time_in_state: float = 0.0
var _is_currently_night: bool = false 

@export_group("Cycle Timing")
@export var peak_angle: float = -100.0   
@export var stay_duration: float = 30.0 
@export var night_duration: float = 15.0 

var base_energy: float = 1.0 

func _ready() -> void:
	if world_environment and world_environment.environment:
		# 1. Force a unique environment to avoid changing your save file
		world_environment.environment = world_environment.environment.duplicate()
		
		# 2. Access the Sky Material directly
		var sky_mat = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
		if sky_mat:
			# Kill the orange horizon by matching it to the top color temporarily
			sky_mat.sky_horizon_color = Color(0.3, 0.5, 0.8) # A clear blue
			sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	
	# 3. Position the sun at high noon instantly
	directional_light_3d.rotation_degrees.x = peak_angle # -100
	current_state = SUN_STATE.STAYING
	
	# 4. Trigger your transition logic to lock in the blue sky
	_manage_visual_transitions(false)
	
func _process(delta: float) -> void:
	# Look at the Global Settings script directly
	if not Settings.day_night_cycle:
		return
		
	time_in_state += delta
	_update_sun_state(delta)
	
	var night_check = (current_state == SUN_STATE.NIGHT or current_state == SUN_STATE.SETTING)
	if night_check != _is_currently_night:
		_is_currently_night = night_check
		is_night = night_check
		_manage_visual_transitions(_is_currently_night)

func _update_sun_state(delta: float) -> void:
	match current_state:
		SUN_STATE.RISING:
			directional_light_3d.rotation_degrees.x -= (abs(peak_angle) / 7.5) * delta
			if directional_light_3d.rotation_degrees.x <= peak_angle:
				current_state = SUN_STATE.STAYING
				time_in_state = 0.0
		SUN_STATE.STAYING:
			directional_light_3d.rotation_degrees.x = peak_angle
			if time_in_state >= stay_duration:
				current_state = SUN_STATE.SETTING
				time_in_state = 0.0
		SUN_STATE.SETTING:
			var dist_to_set = abs(-180.0 - peak_angle)
			directional_light_3d.rotation_degrees.x -= (dist_to_set / 7.5) * delta
			if directional_light_3d.rotation_degrees.x <= -180.0:
				current_state = SUN_STATE.NIGHT
				time_in_state = 0.0
		SUN_STATE.NIGHT:
			directional_light_3d.rotation_degrees.x += (180.0 / night_duration) * delta
			if directional_light_3d.rotation_degrees.x >= 0.0:
				directional_light_3d.rotation_degrees.x = 0.0
				current_state = SUN_STATE.RISING
				time_in_state = 0.0

func _manage_visual_transitions(is_night: bool) -> void:
	var env = world_environment.environment
	if not env: return
	var sky_mat: ProceduralSkyMaterial = null
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		sky_mat = env.sky.sky_material

	night_mode_changed.emit(is_night)
	var tween = create_tween().set_parallel(true)

	if is_night:
		tween.tween_property(directional_light_3d, "light_energy", 0.0, 4.0)
		tween.tween_property(env, "ambient_light_energy", 0.02, 4.0)
		if sky_mat:
			tween.tween_property(sky_mat, "sky_top_color", Color(0.28, 0.28, 0.28), 4.0)
			tween.tween_property(sky_mat, "sky_horizon_color", Color(0.37, 0.37, 0.37), 4.0)
			tween.tween_property(sky_mat, "ground_horizon_color", Color(0.49, 0.49, 0.49), 4.0)
		await get_tree().create_timer(2.0).timeout
		directional_light_3d.shadow_enabled = false
	else:
		tween.tween_property(directional_light_3d, "light_energy", base_energy, 4.0)
		tween.tween_property(env, "ambient_light_energy", 1.0, 4.0)
		if sky_mat:
			tween.tween_property(sky_mat, "sky_top_color", Color(0.38, 0.45, 0.55), 4.0)
			tween.tween_property(sky_mat, "sky_horizon_color", Color(0.65, 0.71, 0.75), 4.0)
			tween.tween_property(sky_mat, "ground_horizon_color", Color(0.65, 0.71, 0.75), 4.0)
		if current_quality != GAME_QUALITY.LOW:
			directional_light_3d.shadow_enabled = true

func _on_lighting_update(new_color: Color, energy: float):
	base_energy = energy
	if not _is_currently_night:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(directional_light_3d, "light_color", new_color, 2.0)
		tween.tween_property(directional_light_3d, "light_energy", energy, 2.0)
		if world_environment.environment:
			tween.tween_property(world_environment.environment, "ambient_light_color", new_color, 2.0)

func load_local_settings():
	var path = OS.get_executable_path().get_base_dir().path_join("settings.json")
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			if data.has("gameplay"):
				cycle_enabled = data["gameplay"].get("day_night_cycle", true)
			if data.has("graphics"):
				var q = data["graphics"].get("graphics_quality", "Medium")
				match q:
					"Low": current_quality = GAME_QUALITY.LOW
					"Medium": current_quality = GAME_QUALITY.MEDIUM
					"High": current_quality = GAME_QUALITY.HIGH
					"Ultra": current_quality = GAME_QUALITY.ULTRA

func apply_quality_settings():
	match current_quality:
		GAME_QUALITY.LOW: directional_light_3d.shadow_enabled = false
		GAME_QUALITY.MEDIUM: directional_light_3d.shadow_enabled = true
		GAME_QUALITY.HIGH: directional_light_3d.shadow_enabled = true
		GAME_QUALITY.ULTRA: directional_light_3d.shadow_enabled = true
