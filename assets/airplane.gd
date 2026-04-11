extends Node3D

@export var fly_distance: float = 500.0
@export var fly_speed: float = 20.0        
@export var rotation_speed: float = 1.0    # Seconds it takes to turn around
@export var min_wait_time: float = 5.0     
@export var max_wait_time: float = 150.0    

var _start_position: Vector3
var _start_rotation: Vector3

func _ready():
	_start_position = global_position

	_wait_and_fly()

func _wait_and_fly():
	var wait_time = randf_range(min_wait_time, max_wait_time)
	await get_tree().create_timer(wait_time).timeout
	_execute_flight_cycle()

func _execute_flight_cycle():
	var duration = fly_distance / fly_speed
	var target_pos = _start_position + (-global_transform.basis.z * fly_distance)
	
	var tween = create_tween()
	
	# 1. FLY FORWARD
	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. ROTATE 180 DEGREES (Turn Around)
	# We add PI (180 degrees in radians) to the current Y rotation
	tween.tween_property(self, "rotation:y", rotation.y + PI, rotation_speed)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# 3. FLY BACK TO START
	tween.tween_property(self, "global_position", _start_position, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# 4. ROTATE BACK TO ORIGINAL FACE
	# Using the stored _start_rotation to ensure it snaps back perfectly
	tween.tween_property(self, "global_rotation:y", _start_rotation.y, rotation_speed)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Loop the logic
	tween.finished.connect(_wait_and_fly)
