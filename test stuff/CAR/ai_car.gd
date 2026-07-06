extends PathFollow3D

@export_group("Movement")
@export var max_speed: float = 3.0
@export var acceleration: float = 2.0
@export var braking_strength: float = 16.0
@export var stop_distance: float = 2.5

@export_group("AI Intelligence")
@export var search_radius: float = 3.5  
@export var switch_threshold: float = 0.96 
@export var stuck_timeout: float = 5.0 
@export var ghost_duration: float = 20.0

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

# Traffic Light Tracking States
var _at_red_light: bool = false 
var _current_stop_area: Area3D = null

func _ready() -> void:
	loop = false
	cubic_interp = true
	max_speed += randf_range(-1.5, 2.0)
	
	# Store the original collision layer to restore it later
	if ai_car:
		_original_collision_layer = ai_car.collision_layer
		
		# 1. Ignore the main car physics body
		front_ray.add_exception(ai_car) 
		
		# 2. Ignore the car's own detection area sensor bubble
		var detection_area = ai_car.get_node_or_null("DetectionArea")
		if detection_area:
			front_ray.add_exception(detection_area)
	
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
	if _ghost_mode_timer > 0:
		_ghost_mode_timer -= delta
		if _ghost_mode_timer <= 0:
			_toggle_ghost_collision(true)

	# 2. WAIT TIMER (for dead ends)
	if _wait_timer > 0:
		_wait_timer -= delta
		return

	var target_speed = max_speed
	
	# 3. TRAFFIC SENSING & QUEUING
	if _ghost_mode_timer <= 0:
		# Force the raycast to stay perfectly level and aim straight ahead along the Y axis (-Y is forward)
		front_ray.target_position.x = 0.0
		front_ray.target_position.z = 0.0
		front_ray.target_position.y = -max(3.5, _current_speed * 1.5)
		
		# Check if the current path we are attached to is a turn lane
		var current_path = get_parent()
		var _is_on_turn_path: bool = current_path and !"straight" in current_path.name.to_lower()
		
		# Check A: Standard Red/Yellow Light Stop
		if _at_red_light and _is_light_ahead_red():
			target_speed = 0.0
			
		# Check B: GRIDLOCK PROTECTION ("Don't Block the Box")
		elif progress_ratio > 0.85 and not _is_switching:
			var next_intended_path = _peek_next_path()
			if next_intended_path and not _has_room_on_destination_path(next_intended_path):
				target_speed = 0.0 
				
		# Check C: Advanced Bumper-to-Bumper Queuing (Bypassed if turning)
		elif not _is_on_turn_path:
			var car_ahead_distance = _get_distance_to_car_ahead()
			if car_ahead_distance < stop_distance:
				# 1.2 is the absolute minimum distance (in meters) between bumpers when fully stopped
				var factor = (car_ahead_distance - 1.2) / (stop_distance - 1.2)
				factor = clamp(factor, 0.0, 1.0)
				
				target_speed = lerp(0.0, max_speed, factor)
				target_speed = clamp(target_speed, 0.0, max_speed)
		
		# If on a turn path, maintain normal target speed since _attempt_group_switch 
		# already verified the turn path was empty before the car entered it.
		else:
			target_speed = max_speed
	

	# 4. STUCK DETECTION
	var waiting_at_light = _at_red_light and _is_light_ahead_red()
	var waiting_for_gridlock = progress_ratio > 0.85 and not _is_switching and _peek_next_path() and not _has_room_on_destination_path(_peek_next_path())
	
	if target_speed > 0.5 and _current_speed < 0.2 and _ghost_mode_timer <= 0 and not waiting_at_light and not waiting_for_gridlock:
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
	_current_speed = max_speed * 0.4

func _toggle_ghost_collision(enable: bool) -> void:
	if not ai_car: return
	if enable:
		ai_car.collision_layer = _original_collision_layer
	else:
		ai_car.collision_layer = 0

# Scans a specific path to see if another car is currently using it
func _is_path_occupied(target_path: Path3D) -> bool:
	for child in target_path.get_children():
		if child is PathFollow3D and child != self:
			if child.progress_ratio < 0.8: 
				return true
	return false

# Checks if the target lane has physical room for another vehicle (Don't Block the Box)
func _has_room_on_destination_path(target_path: Path3D) -> bool:
	var cars_on_path: Array = []
	for child in target_path.get_children():
		if child is PathFollow3D and child != self:
			cars_on_path.append(child)
			
	if cars_on_path.is_empty():
		return true 
		
	var trailing_car: PathFollow3D = cars_on_path[0]
	for car in cars_on_path:
		if car.progress < trailing_car.progress:
			trailing_car = car
			
	if trailing_car.progress < stop_distance:
		return false
		
	return true

# Safely forecasts the upcoming path selection without executing a hard transition
func _peek_next_path() -> Path3D:
	var all_tiles = get_tree().get_nodes_in_group("level_grid")
	var car_forward = -global_transform.basis.z 
	var valid_paths: Array[Path3D] = []

	for tile in all_tiles:
		if global_position.distance_to(tile.global_position) < 12.0:
			for child in tile.get_children():
				if child is Path3D and child != get_parent():
					var path_curve = child.curve
					var path_start_pos = child.to_global(path_curve.get_point_position(0))
					
					if global_position.distance_to(path_start_pos) < search_radius:
						var path_forward = child.to_global(path_curve.get_point_position(1)) - path_start_pos
						if car_forward.dot(path_forward.normalized()) > 0.2:
							valid_paths.append(child)
							
	if not valid_paths.is_empty():
		return valid_paths[0]
	return null

# Calculates the true 3D distance to the vehicle directly in front of our bumper
func _get_distance_to_car_ahead() -> float:
	if front_ray.is_colliding():
		var collider = front_ray.get_collider()
		if collider and (collider.is_in_group("cars") or "AICar" in collider.name or collider is CharacterBody3D):
			return global_position.distance_to(front_ray.get_collision_point())
	return 999.0

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
	var is_chosen_a_turn: bool = false
	
	if not forward_straight.is_empty() or not forward_turns.is_empty():
		if not forward_straight.is_empty() and not forward_turns.is_empty():
			if randf() < 0.70:
				chosen_path = forward_straight.pick_random()
			else:
				chosen_path = forward_turns.pick_random()
				is_chosen_a_turn = true
		elif not forward_straight.is_empty():
			chosen_path = forward_straight.pick_random()
		else:
			chosen_path = forward_turns.pick_random()
			is_chosen_a_turn = true
	elif not uturn_paths.is_empty():
		chosen_path = uturn_paths.pick_random()
		is_chosen_a_turn = true

	if chosen_path:
		if is_chosen_a_turn and _is_path_occupied(chosen_path):
			_current_speed = 0.0
			_is_switching = false
			return 

		reparent(chosen_path)
		progress = 0
		_is_switching = false
		
		_current_stop_area = null
		_at_red_light = false 
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

# --- TRAFFIC LIGHT DETECTION AREA SIGNALS ---

func _on_stop_area_entered(area: Area3D) -> void:
	if area.name == "StopArea":
		_current_stop_area = area
		_at_red_light = true

func _on_stop_area_exited(area: Area3D) -> void:
	if area == _current_stop_area:
		_current_stop_area = null
		_at_red_light = false

func _is_light_ahead_red() -> bool:
	if _current_stop_area and is_instance_valid(_current_stop_area):
		var light_pole = _current_stop_area.get_parent()
		
		if "is_red" in light_pole and "traffic_direction" in light_pole:
			if not light_pole.is_red:
				return false 
				
			var car_forward = -global_transform.basis.z
			var light_forward = Vector3.ZERO
			
			match light_pole.traffic_direction:
				light_pole.Direction.NORTH:
					light_forward = Vector3(0, 0, -1)
				light_pole.Direction.SOUTH:
					light_forward = Vector3(0, 0, 1) 
				light_pole.Direction.EAST:
					light_forward = Vector3(1, 0, 0) 
				light_pole.Direction.WEST:
					light_forward = Vector3(-1, 0, 0)
			
			var alignment = car_forward.dot(light_forward)
			if alignment > 0.5:
				return true
				
	return false
