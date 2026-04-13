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

var _current_speed: float = 0.0
var _is_switching: bool = false

func _ready():
	loop = false
	cubic_interp = true
	# Give cars slightly different speeds for natural traffic
	max_speed += randf_range(-1.5, 2.0)

func _physics_process(delta: float):
	var target_speed = max_speed
	
	# 1. TRAFFIC SENSING
	if front_ray.is_colliding():
		var dist = global_position.distance_to(front_ray.get_collision_point())
		target_speed = lerp(0.0, max_speed, (dist - 2.0) / stop_distance)
		target_speed = clamp(target_speed, 0.0, max_speed)

	# 2. MOVEMENT LOGIC
	var accel_rate = acceleration if target_speed > _current_speed else braking_strength
	_current_speed = move_toward(_current_speed, target_speed, accel_rate * delta)
	
	progress += _current_speed * delta

	# 3. MODULAR HANDOFF
	if progress_ratio >= switch_threshold and not _is_switching:
		_attempt_group_switch()
func _attempt_group_switch():
	_is_switching = true
	
	var all_tiles = get_tree().get_nodes_in_group("level_grid")
	
	var forward_straight: Array[Path3D] = []
	var forward_turns: Array[Path3D] = []
	var uturn_paths: Array[Path3D] = [] # Last resort
	
	var car_forward = -global_transform.basis.z 

	for tile in all_tiles:
		if global_position.distance_to(tile.global_position) < 10.0:
			for child in tile.get_children():
				if child is Path3D and child != get_parent():
					var path_curve = child.curve
					var path_start_pos = child.to_global(path_curve.get_point_position(0))
					
					if global_position.distance_to(path_start_pos) < search_radius:
						# Get the direction the new path is heading
						var path_forward = child.to_global(path_curve.get_point_position(1)) - path_start_pos
						path_forward = path_forward.normalized()
						
						# Check if it's facing forward or backward
						var alignment = car_forward.dot(path_forward)
						
						if alignment > 0.2: # Forward or Side-Turn
							if "straight" in child.name.to_lower():
								forward_straight.append(child)
							else:
								forward_turns.append(child)
						else: # It's facing behind the car (Potential U-Turn)
							uturn_paths.append(child)

	# --- SELECTION LOGIC ---
	var chosen_path: Path3D = null

	# 1. Try to go Straight or Turn (70/30)
	if forward_straight.size() > 0 or forward_turns.size() > 0:
		var roll = randf()
		if forward_straight.size() > 0 and forward_turns.size() > 0:
			chosen_path = forward_straight.pick_random() if roll < 0.70 else forward_turns.pick_random()
		elif forward_straight.size() > 0:
			chosen_path = forward_straight.pick_random()
		else:
			chosen_path = forward_turns.pick_random()
			
	# 2. IF NOTHING FOUND: Check for U-Turns
	elif uturn_paths.size() > 0:
		print("Dead end found! Performing U-turn.")
		chosen_path = uturn_paths.pick_random()

	# --- EXECUTE ---
	if chosen_path:
		reparent(chosen_path)
		progress = 0
		_is_switching = false
	else:
		if progress_ratio >= 0.999:
			_current_speed = 0
		_is_switching = false
