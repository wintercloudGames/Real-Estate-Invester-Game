extends CharacterBody3D

enum State {DRIVING, RECOVERING}
var _state = State.DRIVING

@export_group("Movement Settings")
@export var max_speed: float = 12.0
@export var acceleration: float = 4.0
@export var friction: float = 10.0
@export var gravity: float = 20.0

@export_group("AI Intelligence")
@export var look_ahead_dist: float = 10.0
@export var side_buffer: float = 3.5
@export var steer_speed: float = 4.0
@export var stop_distance: float = 5.0

# Ensure these names match your Scene Tree exactly!
@onready var left_whisker = $LeftWhisker
@onready var right_whisker = $RightWhisker
@onready var front_ray = $FrontRay
@onready var ground_ray = $GroundRay

var _current_speed: float = 0.0
var _target_speed: float = 0.0
var _steer_angle: float = 0.0
var _vertical_vel: float = 0.0
var _recovery_timer: float = 0.0

func _ready():
	# SAFETY CHECK: Verify nodes exist
	if not left_whisker or not right_whisker or not front_ray:
		push_error("AI Car Error: RayCast nodes not found. Check your node names!")
		set_physics_process(false) # Stop the script so it doesn't crash
		return

	# Randomize personality
	max_speed += randf_range(-2.0, 3.0)
	
	# Configure Rays via code
	front_ray.target_position = Vector3(0, 0, -look_ahead_dist)
	left_whisker.target_position = Vector3(-side_buffer, 0, -side_buffer)
	right_whisker.target_position = Vector3(side_buffer, 0, -side_buffer)

func _physics_process(delta):
	apply_gravity(delta)
	
	match _state:
		State.DRIVING:
			drive_logic(delta)
		State.RECOVERING:
			recover_logic(delta)

	velocity = -global_transform.basis.z * _current_speed
	velocity.y = _vertical_vel
	
	if move_and_slide() and _current_speed > 2.0 and get_real_velocity().length() < 0.5:
		start_recovery()

func drive_logic(delta):
	_target_speed = max_speed
	var target_steer = 0.0
	
	# 1. FRONT PERCEPTION
	if front_ray.is_colliding():
		var obj = front_ray.get_collider()
		var dist = global_position.distance_to(front_ray.get_collision_point())
		
		if obj is CharacterBody3D: 
			_target_speed = lerp(0.0, max_speed, dist / stop_distance)
		else: 
			_target_speed = max_speed * 0.4 
			target_steer += 1.0 if get_dist(left_whisker) > get_dist(right_whisker) else -1.0

	# 2. LANE KEEPING
	var l_dist = get_dist(left_whisker)
	var r_dist = get_dist(right_whisker)
	target_steer += (side_buffer - l_dist) / side_buffer
	target_steer -= (side_buffer - r_dist) / side_buffer

	# 3. EXECUTION
	_steer_angle = lerp(_steer_angle, target_steer, steer_speed * delta)
	rotation.y += _steer_angle * delta * (2.0 if _current_speed < 5.0 else 1.2)
	
	var accel_rate = acceleration if _target_speed > _current_speed else friction
	_current_speed = move_toward(_current_speed, _target_speed, accel_rate * delta)

func get_dist(ray: RayCast3D) -> float:
	if ray.is_colliding():
		return global_position.distance_to(ray.get_collision_point())
	return side_buffer

func start_recovery():
	_state = State.RECOVERING
	_recovery_timer = 1.5
	_current_speed = 0.0

func recover_logic(delta):
	_recovery_timer -= delta
	_current_speed = -max_speed * 0.3
	rotation.y += 1.5 * delta 
	
	if _recovery_timer <= 0:
		_state = State.DRIVING

func apply_gravity(delta):
	if is_on_floor(): _vertical_vel = 0.0
	else: _vertical_vel -= gravity * delta
