extends Camera3D
class_name YardCamera

@export_category("Camera Rotation")
@export var rotation_speed: float = 2.0
@export var rotation_radius: float = 8.0
@export var min_angle: float = -45.0
@export var max_angle: float = 45.0
@export var height_offset: float = 4.0

var current_angle: float = 0.0
var target_angle: float = 0.0
var rotation_center: Vector3 = Vector3.ZERO
var is_active: bool = false

func _ready():

	
	# Get the yard center node
	var house_base = get_parent().get_parent()
	if house_base:

		var yard_center = house_base.get_node("Yard_center_for_camera")
		if yard_center:
			rotation_center = yard_center.global_position
		else:
			rotation_center = house_base.global_position
			
	else:
		rotation_center = global_position
		
	
	update_camera_position()
	set_process(false)


func _process(delta):
	# Debug: Check if keys are pressed
	var a_pressed = Input.is_key_pressed(KEY_A)
	var d_pressed = Input.is_key_pressed(KEY_D)
	
	handle_rotation_input(delta)
	update_camera_position()

func handle_rotation_input(delta):
	# Rotate with A and D keys - using direct key checks
	if Input.is_key_pressed(KEY_A):
		target_angle -= rotation_speed * delta
	if Input.is_key_pressed(KEY_D):
		target_angle += rotation_speed * delta
	
	# Clamp angle
	target_angle = clamp(target_angle, deg_to_rad(min_angle), deg_to_rad(max_angle))
	
	# Smooth rotation
	current_angle = lerp(current_angle, target_angle, 5.0 * delta)

func update_camera_position():
	# Calculate new position
	var new_position = rotation_center
	new_position.x += rotation_radius * sin(current_angle)
	new_position.z += rotation_radius * cos(current_angle)
	new_position.y = rotation_center.y + height_offset
	
	global_position = new_position
	look_at(rotation_center, Vector3.UP)
	

func set_as_active(active: bool):
	is_active = active
	current = active
	set_process(active)
	
	if active:
		
		# Update center position
		var house_base = get_parent().get_parent()
		if house_base:
			var yard_center = house_base.get_node("Yard_center_for_camera")
			if yard_center:
				rotation_center = yard_center.global_position
		
		update_camera_position()


# Test function - call this from the console to check if camera works
func test_rotation():
	target_angle += deg_to_rad(30)  # Rotate 30 degrees
