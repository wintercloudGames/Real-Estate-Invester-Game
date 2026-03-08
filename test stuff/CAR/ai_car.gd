extends CharacterBody3D

@export var max_speed: float = 15.0
@export var acceleration: float = 3.0
@export var deceleration: float = 5.0
@export var base_rotation_speed: float = 1.5
@export var edge_avoidance_strength: float = 2.0
@export var lane_width: float = 3.5
@export var recovery_speed: float = 0.5
@export var gravity: float = 9.8
@export var ground_clearance: float = 0.2  # Distance to maintain from ground

@onready var left_ray: RayCast3D = $LeftRay
@onready var right_ray: RayCast3D = $RightRay
@onready var front_left_ray: RayCast3D = $FrontLeftRay
@onready var front_right_ray: RayCast3D = $FrontRightRay
@onready var ground_ray: RayCast3D = $GroundRay  # New ray pointing downward

var speed: float = 0.0
var current_lane_center: float = 0.0
var is_on_road: bool = true
var vertical_velocity: float = 0.0

func _ready():
	speed = max_speed / 2
	current_lane_center = global_transform.origin.x
	# Make sure ground ray points downward
	ground_ray.target_position = Vector3(0, -ground_clearance - 0.5, 0)

func _physics_process(delta):
	# Handle vertical movement and ground detection
	handle_grounding(delta)
	
	# Horizontal movement
	speed = min(speed + acceleration * delta, max_speed)
	var steering_input = follow_road(delta)
	rotation.y += steering_input * base_rotation_speed * delta
	
	# Combine horizontal and vertical velocity
	velocity = transform.basis.z * -speed
	velocity.y = vertical_velocity
	
	move_and_slide()

func handle_grounding(delta):
	if ground_ray.is_colliding():
		# Snap to ground when close
		if ground_ray.get_collision_distance() > ground_clearance:
			vertical_velocity = -2.0  # Soft landing
		else:
			vertical_velocity = 0.0
			global_transform.origin.y = ground_ray.get_collision_point().y + ground_clearance
	else:
		# Apply gravity when in air
		vertical_velocity -= gravity * delta

func follow_road(delta) -> float:
	var steering = 0.0
	var hit_left = left_ray.is_colliding() or front_left_ray.is_colliding()
	var hit_right = right_ray.is_colliding() or front_right_ray.is_colliding()
	
	if hit_left and hit_right:
		speed = max(speed - deceleration * delta, max_speed * 0.3)
		return 0.0
	
	if hit_left:
		steering += edge_avoidance_strength * (1.0 - left_ray.get_collision_point().distance_to(global_transform.origin) / lane_width)
	elif hit_right:
		steering -= edge_avoidance_strength * (1.0 - right_ray.get_collision_point().distance_to(global_transform.origin) / lane_width)
	else:
		var lane_offset = global_transform.origin.x - current_lane_center
		steering = -lane_offset * recovery_speed
	
	return steering
