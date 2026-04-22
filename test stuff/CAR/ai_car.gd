extends PathFollow3D

@export_group("Movement")
@export var max_speed: float = 5.0
@export var acceleration: float = 4.0
@export var braking_strength: float = 12.0
@export var stop_distance: float = 6.0

@export_group("AI Intelligence")
@export var search_radius: float = 3.5  
@export var switch_threshold: float = 0.96 
@export var stuck_timeout: float = 5.0 # Seconds before ghost mode triggers
@export var ghost_duration: float = 20.0 # Seconds collision stays disabled

@onready var front_ray: RayCast3D = $AICar/FrontRay
@onready var car_lights: Array = [$SpotLight3D, $SpotLight3D2]
@onready var ai_car: CharacterBody3D = $AICar

# Internal State
var _current_speed: float = 0.0
var _is_switching: bool = false
var _wait_timer: float = 0.0
var _stuck_timer: float = 0.0
var _ghost_mode_timer: float = 0.0
var _original_collision_layer: int = 0
var lights_should_be_on: bool = false

func _ready() -> void:
	loop = false
	cubic_interp = true
	max_speed += randf_range(-1.5, 2.0)
	
	# Store the original collision layer to restore it later
	if ai_car:
		_original_collision_layer = ai_car.collision_layer
	
	_update_lights()
	
	# Connect to World Settings for night/day cycle
	var world_settings = get_node_or_null("/root/Root/UserInterface/Game/World_settings")
	if world_settings:
		world_settings.night_mode_changed.connect(_on_night_mode_changed)
		_on_night_mode_changed(world_settings._is_currently_night)
	else:
		push_warning("Car couldn't find World_settings! Check the path.")

func _on_night_mode_changed(enabled: bool) -> void:
	lights_should_be_on = enabled
	for light in car_lights:
		if light:
			light.visible = enabled

func _physics_process(delta: float) -> void:
	# 1. GHOST MODE TIMER
	# Restores collision once the 20-second timer expires
	if _ghost_mode_timer > 0:
		_ghost_mode_timer -= delta
		if _ghost_mode_timer <= 0:
			_toggle_ghost_collision(true)

	# 2. WAIT TIMER (for dead ends)
	if _wait_timer > 0:
		_wait_timer -= delta
		return

	var target_speed = max_speed
	
	# 3. TRAFFIC SENSING
	# Only sense traffic if NOT in ghost mode (so we can drive through jams)
	if _ghost_mode_timer <= 0 and front_ray.is_colliding():
		var dist = global_position.distance_to(front_ray.get_collision_point())
		target_speed = lerp(0.0, max_speed, (dist - 2.0) / stop_distance)
		target_speed = clamp(target_speed, 0.0, max_speed)

	# 4. STUCK DETECTION
	# If we want to move but speed is near zero, increment the stuck timer
	if target_speed > 0.5 and _current_speed < 0.2 and _ghost_mode_timer <= 0:
		_stuck_timer += delta
		if _stuck_timer >= stuck_timeout:
			_trigger_ghost_mode()
	else:
		_stuck_timer = 0.0

	# 5. MOVEMENT EXECUTION
	var accel_rate = acceleration if target_speed > _current_speed else braking_strength
	_current_speed = move_toward(_current_speed, target_speed, accel_rate * delta)
	
	progress += _current_speed * delta

	# 6. MODULAR HANDOFF (Switching tiles)
	if progress_ratio >= switch_threshold and not _is_switching:
		_attempt_group_switch()
	
	# 7. DEAD END PREVENTION
	if progress_ratio >= 0.999 and not _is_switching:
		_handle_dead_end()

func _trigger_ghost_mode() -> void:
	_stuck_timer = 0.0
	_ghost_mode_timer = ghost_duration
	_toggle_ghost_collision(false)
	# Force some speed so it immediately starts clearing the jam
	_current_speed = max_speed * 0.4

func _toggle_ghost_collision(enable: bool) -> void:
	if not ai_car: return
	
	if enable:
		ai_car.collision_layer = _original_collision_layer
		ai_car.modulate.a = 1.0 # Back to opaque
	else:
		ai_car.collision_layer = 0 # Disables collision entirely
		ai_car.modulate.a = 0.5 # Optional: Make transparent to show it's "ghosting"

func _attempt_group_switch() -> void:
	_is_switching = true
	var all_tiles = get_tree().get_nodes_in_group("level_grid")
	
	var forward_straight: Array[Path3D] = []
	var forward_turns: Array[Path3D] = []
	var uturn_paths: Array[Path3D] = []
	
	var car_forward = -global_transform.basis.z 

	for tile in all_tiles:
		if global_position.distance_to(tile.global_position) < 12.0:
			for child in tile.get_children():
				if child is Path3D and child != get_parent():
					var path_curve = child.curve
					var path_start_pos = child.to_global(path_curve.get_point_position(0))
					
					if global_position.distance_to(path_start_pos) < search_radius:
						var path_forward = child.to_global(path_curve.get_point_position(1)) - path_start_pos
						var alignment = car_forward.dot(path_forward.normalized())
						
						if alignment > 0.2:
							if "straight" in child.name.to_lower():
								forward_straight.append(child)
							else:
								forward_turns.append(child)
						else:
							uturn_paths.append(child)

	var chosen_path: Path3D = null
	if not forward_straight.is_empty() or not forward_turns.is_empty():
		if not forward_straight.is_empty() and not forward_turns.is_empty():
			chosen_path = forward_straight.pick_random() if randf() < 0.70 else forward_turns.pick_random()
		elif not forward_straight.is_empty():
			chosen_path = forward_straight.pick_random()
		else:
			chosen_path = forward_turns.pick_random()
	elif not uturn_paths.is_empty():
		chosen_path = uturn_paths.pick_random()

	if chosen_path:
		reparent(chosen_path)
		progress = 0
		_is_switching = false
	else:
		_is_switching = false

func _handle_dead_end() -> void:
	_current_speed = 0
	_wait_timer = 2.0 

func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	if ai_car: ai_car.visible = true
	if lights_should_be_on:
		for light in car_lights:
			if light: light.visible = true

func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	if ai_car: ai_car.visible = false
	for light in car_lights:
		if light: light.visible = false

func _on_external_light_change(_color: Color, _energy: float) -> void:
	_update_lights()

func _update_lights() -> void:
	var should_be_on: bool = false
	if Globals.has_method("is_night") and Globals.is_night():
		should_be_on = true
	
	var season_sys = get_tree().get_root().find_child("Season_System", true, false)
	if season_sys and season_sys.rain_node.emitting:
		should_be_on = true

	for light in car_lights:
		if light: light.visible = should_be_on
