extends Node3D

# --- Camera Movement Settings ---
@export var move_speed: float = 10.0
@export var drag_sensitivity: float = 0.02
@export var zoom_speed: float = 5.0
@export var min_zoom_distance: float = 5.0
@export var max_zoom_distance: float = 50.0
@export var edge_scroll_speed: float = 15.0
@export var edge_margin: int = 20
@export var max_distance: float = 30.0

# --- Inertia / Throw Settings ---
@export var friction: float = 0.93          # 0.9 is snappy, 0.98 is very "slidery"
@export var momentum_multiplier: float = 1.5 # How much "kick" the throw has

# --- Frustum Culling Settings ---
@export var enable_frustum_culling: bool = true
@export var cull_check_interval: float = 0.2
@export var cull_distance_multiplier: float = 1.5

# Internal variables
var _target_zoom_distance: float = 10.0
var _cull_timer: float = 0.0
var _velocity: Vector3 = Vector3.ZERO # Stores the "throw" momentum
var _is_dragging: bool = false
var initial_position: Vector3

@onready var cam = $Camera3D

func _ready():
	_target_zoom_distance = cam.position.distance_to(self.position)
	initial_position = self.position
	
	if enable_frustum_culling:
		perform_frustum_culling()

func _process(delta):
	# 1. Apply Momentum (The Glide)
	if _velocity.length() > 0.01:
		var new_pos = position + _velocity * delta
		
		# Keep within boundaries
		if new_pos.distance_to(initial_position) <= max_distance:
			position = new_pos
		else:
			_velocity = Vector3.ZERO # Instant stop at border
		
		# 2. Apply Friction (Gradual slowdown)
		if not _is_dragging:
			_velocity *= friction
	
	# Only allow keyboard/edge movement if not currently dragging
	if not _is_dragging:
		handle_movement(delta)
		#handle_edge_scroll(delta)
		
	handle_zoom(delta)
	
	# Frustum Culling Timer
	if enable_frustum_culling:
		_cull_timer += delta
		if _cull_timer >= cull_check_interval:
			_cull_timer = 0.0
			perform_frustum_culling()

var _last_mouse_pos: Vector2 = Vector2.ZERO

func _input(event):
	# Handle Drag Initiation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
			if _is_dragging:
				# Store position when we first click so we don't "jump"
				_last_mouse_pos = get_viewport().get_mouse_position()
				_velocity = Vector3.ZERO 

	# Handle Drag Motion
	if event is InputEventMouseMotion and _is_dragging:
		var current_mouse_pos = event.position
		var relative_motion = current_mouse_pos - _last_mouse_pos
		_last_mouse_pos = current_mouse_pos # Update for next frame
		
		handle_drag_pan(relative_motion)

func handle_drag_pan(relative_motion: Vector2):
	if Globals.yard_edit: return
		
	var forward = -transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var right = transform.basis.x
	right.y = 0
	right = right.normalized()

	var zoom_factor = _target_zoom_distance / 10.0
	
	# Calculate move vector (inverted relative_motion to pull the world)
	var move_vec = (right * -relative_motion.x + forward * relative_motion.y) * drag_sensitivity * zoom_factor
	
	# Set velocity for the "throw"
	_velocity = (move_vec / get_process_delta_time()) * momentum_multiplier
	
	var new_position = position + move_vec
	if new_position.distance_to(initial_position) <= max_distance:
		position = new_position

func handle_movement(delta: float):
	if Globals.yard_edit or Globals.Editing_Business_Text:
		return
	
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"): direction.z -= 1
	if Input.is_action_pressed("move_back"): direction.z += 1
	if Input.is_action_pressed("move_left"): direction.x -= 1
	if Input.is_action_pressed("move_right"): direction.x += 1

	if direction.length() > 0:
		direction = direction.normalized()
		var speed_multiplier = 2.0 if Input.is_action_pressed("faster") else 1.0
		var new_position = position + direction * move_speed * speed_multiplier * delta
		
		if new_position.distance_to(initial_position) <= max_distance:
			position = new_position

func handle_zoom(delta: float):
	var zoom_direction = 0
	if Input.is_action_pressed("zoom_in"): zoom_direction -= 1
	if Input.is_action_pressed("zoom_out"): zoom_direction += 1

	_target_zoom_distance += zoom_direction * zoom_speed
	_target_zoom_distance = clamp(_target_zoom_distance, min_zoom_distance, max_zoom_distance)

	var current_distance = cam.position.distance_to(Vector3.ZERO)
	var new_distance = lerp(current_distance, _target_zoom_distance, zoom_speed * delta)
	cam.position = cam.position.normalized() * new_distance

func handle_edge_scroll(delta: float):
	if Globals.yard_edit: return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var edge_direction = Vector3.ZERO
	
	if DisplayServer.window_is_focused():
		if mouse_pos.x < edge_margin: edge_direction.x -= 1
		if mouse_pos.x > viewport_size.x - edge_margin: edge_direction.x += 1
		if mouse_pos.y < edge_margin: edge_direction.z -= 1
		if mouse_pos.y > viewport_size.y - edge_margin: edge_direction.z += 1

	if edge_direction.length() > 0:
		edge_direction = edge_direction.normalized()
		var new_position = position + edge_direction * edge_scroll_speed * delta
		if new_position.distance_to(initial_position) <= max_distance:
			position = new_position

# --- FRUSTUM CULLING LOGIC ---

func perform_frustum_culling():
	if not cam: return
	var frustum = _get_camera_frustum()
	var renderable_objects = get_tree().get_nodes_in_group("renderable")
	
	for obj in renderable_objects:
		if not is_instance_valid(obj): continue
		var should_be_visible = _is_object_in_frustum(obj, frustum)
		
		if obj.visible != should_be_visible:
			obj.visible = should_be_visible
			if obj.has_method("set_process"): obj.set_process(should_be_visible)
			if obj.has_method("set_physics_process"): obj.set_physics_process(should_be_visible)

func _get_camera_frustum() -> Array:
	var frustum = []
	if not cam: return frustum
	
	var camera_transform = cam.global_transform
	var camera_position = camera_transform.origin
	
	# Far and Near planes
	frustum.append({"normal": camera_transform.basis.z, "distance": -camera_transform.basis.z.dot(camera_position + camera_transform.basis.z * cam.near)})
	frustum.append({"normal": -camera_transform.basis.z, "distance": camera_transform.basis.z.dot(camera_position + camera_transform.basis.z * cam.far)})
	return frustum

func _is_object_in_frustum(obj: Node3D, frustum: Array) -> bool:
	var obj_pos = obj.global_position
	# Fast distance check
	if obj_pos.distance_to(cam.global_position) > cam.far * cull_distance_multiplier:
		return false
	
	for plane in frustum:
		if plane["normal"].dot(obj_pos) + plane["distance"] < -2.0:
			return false
	return true
