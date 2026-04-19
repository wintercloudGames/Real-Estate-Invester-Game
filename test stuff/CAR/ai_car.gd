extends PathFollow3D

@export_group("Movement")
@export var max_speed: float = 5.0
@export var acceleration: float = 4.0
@export var braking_strength: float = 12.0
@export var stop_distance: float = 6.0

@export_group("AI Intelligence")
@export var search_radius: float = 3.5  
@export var switch_threshold: float = 0.96 

@onready var front_ray: RayCast3D = $AICar/FrontRay
# Grouping lights for easy access
@onready var car_lights: Array = [$SpotLight3D,$SpotLight3D2]
@onready var ai_car: CharacterBody3D = $AICar

var _current_speed: float = 0.0
var _is_switching: bool = false
var _wait_timer: float = 0.0
var lights_should_be_on = false

func _ready() -> void:
	loop = false
	cubic_interp = true
	# Randomize speed so cars don't form a perfect, robotic line
	max_speed += randf_range(-1.5, 2.0)
	
	# INITIAL LIGHT CHECK: Ensure lights match the world state immediately
	_update_lights()
	
	# Make sure the path matches your scene tree
	var world_settings = get_node_or_null("/root/Root/UserInterface/Game/World_settings")
	
	if world_settings:
		# Connect to the signal
		world_settings.night_mode_changed.connect(_on_night_mode_changed)
		
		# Set the light state immediately in case it's already night
		_on_night_mode_changed(world_settings._is_currently_night)
	else:
		push_warning("Car couldn't find World_settings! Check the path.")

func _on_night_mode_changed(enabled: bool):
	# Assuming your lights are children of the car
	$SpotLight3D.visible = enabled
	$SpotLight3D2.visible = enabled

func _physics_process(delta: float) -> void:
	# If we are waiting (at a dead end), don't move
	if _wait_timer > 0:
		_wait_timer -= delta
		return

	var target_speed = max_speed
	
	# 1. TRAFFIC SENSING
	# Note: Ensure your RayCast3D Collision Mask is set to ONLY hit other cars
	if front_ray.is_colliding():
		var dist = global_position.distance_to(front_ray.get_collision_point())
		# Smooth braking curve
		target_speed = lerp(0.0, max_speed, (dist - 2.0) / stop_distance)
		target_speed = clamp(target_speed, 0.0, max_speed)

	# 2. MOVEMENT LOGIC
	var accel_rate = acceleration if target_speed > _current_speed else braking_strength
	_current_speed = move_toward(_current_speed, target_speed, accel_rate * delta)
	
	progress += _current_speed * delta

	# 3. MODULAR HANDOFF (Switching to the next road tile)
	if progress_ratio >= switch_threshold and not _is_switching:
		_attempt_group_switch()
	
	# 4. STUCK PREVENTION
	if progress_ratio >= 0.999 and not _is_switching:
		_handle_dead_end()

func _on_external_light_change(_color: Color, _energy: float) -> void:
	_update_lights()

func _update_lights() -> void:
	# Initialize as false so it has a definitive state
	var should_be_on: bool = false
	
	# Check for night
	if Globals.has_method("is_night") and Globals.is_night():
		should_be_on = true
	
	# Check for weather
	var season_sys = get_tree().get_root().find_child("Season_System", true, false)
	if season_sys and season_sys.rain_node.emitting:
		should_be_on = true

	# Apply the state to each light in the array
	for light in car_lights:
		if light:
			light.visible = should_be_on

func _attempt_group_switch() -> void:
	_is_switching = true
	
	# Find all road tiles. 
	# PERFORMANCE TIP: In a huge city, consider using a Proximity search instead of all_tiles
	var all_tiles = get_tree().get_nodes_in_group("level_grid")
	
	var forward_straight: Array[Path3D] = []
	var forward_turns: Array[Path3D] = []
	var uturn_paths: Array[Path3D] = []
	
	var car_forward = -global_transform.basis.z 

	for tile in all_tiles:
		# Only check tiles within a reasonable distance (12 meters)
		if global_position.distance_to(tile.global_position) < 12.0:
			for child in tile.get_children():
				if child is Path3D and child != get_parent():
					var path_curve = child.curve
					var path_start_pos = child.to_global(path_curve.get_point_position(0))
					
					# If the car is near the start of this new path
					if global_position.distance_to(path_start_pos) < search_radius:
						var path_forward = child.to_global(path_curve.get_point_position(1)) - path_start_pos
						var alignment = car_forward.dot(path_forward.normalized())
						
						if alignment > 0.2: # Going generally forward or turning
							if "straight" in child.name.to_lower():
								forward_straight.append(child)
							else:
								forward_turns.append(child)
						else: # Facing the wrong way (U-turn)
							uturn_paths.append(child)

	var chosen_path: Path3D = null

	# Selection Logic: 70% Straight, 30% Turn
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
		# If no path found, we'll try again next frame until we hit 0.999
		_is_switching = false

func _handle_dead_end() -> void:
	# Stop the car and wait for a few seconds if it reaches the absolute end of a path
	_current_speed = 0
	_wait_timer = 2.0 
	# Teleport or despawn logic could go here if you want to remove stuck cars


func _on_visible_on_screen_notifier_3d_screen_entered() -> void:
	if ai_car:
		ai_car.visible = true
	
	if lights_should_be_on:
		for light in car_lights:
			if light:
				light.visible = true

func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	if ai_car:
		ai_car.visible = false
		
	# We turn them off here to save performance while off-screen
	for light in car_lights:
		if light:
			light.visible = false
