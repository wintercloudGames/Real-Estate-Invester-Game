extends Node3D

# --- Camera Movement Settings ---
@export_group("Movement")
@export var move_speed: float = 10.0
@export var drag_sensitivity: float = 0.02
@export var zoom_speed: float = 8.0 
@export var pinch_sensitivity: float = 1.2
@export var min_zoom_distance: float = 5.0
@export var max_zoom_distance: float = 20.0
@export var max_distance: float = 50.0

# --- Inertia / Throw Settings ---
@export_group("Inertia")
@export var friction: float = 0.93
@export var momentum_multiplier: float = 2.0

# --- Frustum Culling Settings ---
@export_group("Culling")
@export var enable_frustum_culling: bool = true
@export var cull_check_interval: float = 0.2
@export var cull_distance_multiplier: float = 1.5

# Internal variables
var _target_zoom_distance: float = 10.0
var _cull_timer: float = 0.0
var _velocity: Vector3 = Vector3.ZERO 
var _is_dragging: bool = false
var initial_position: Vector3

# Touch tracking
var _touch_points: Dictionary = {} 
var _last_pinch_distance: float = 0.0

@onready var cam = $Camera3D

func _ready():
	_target_zoom_distance = cam.position.y
	initial_position = self.position
	
	if enable_frustum_culling:
		perform_frustum_culling()

func _process(delta: float):
	if Globals.yard_edit: return
		
	# 1. Momentum Physics
	if _velocity.length() > 0.01:
		var new_pos = position + _velocity * delta
		if new_pos.distance_to(initial_position) <= max_distance:
			position = new_pos
		else:
			_velocity = Vector3.ZERO 
		
		if not _is_dragging:
			_velocity *= friction
	
	# 2. Movement & Zoom
	if not _is_dragging:
		handle_keyboard_movement(delta)
	handle_zoom_logic(delta)
	
	# 3. Frustum Culling
	if enable_frustum_culling:
		_cull_timer += delta
		if _cull_timer >= cull_check_interval:
			_cull_timer = 0.0
			perform_frustum_culling()

func _input(event: InputEvent):
	if Globals.yard_edit: return

	# Block camera movement if mouse is over UI
	var over_ui = get_viewport().gui_get_hovered_control() != null

	# --- TOUCH LOGIC ---
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
		
		_is_dragging = _touch_points.size() > 0
		if _is_dragging: _velocity = Vector3.ZERO
		if _touch_points.size() < 2: _last_pinch_distance = 0.0
		return 

	if event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1:
			handle_drag_pan(event.relative)
		elif _touch_points.size() == 2:
			handle_pinch_zoom()
		return

	# --- MOUSE LOGIC ---
	if _touch_points.size() == 0:
		if event is InputEventMouseButton:
			if event.pressed and over_ui: return

			# Right Click Dragging (Camera Pan)
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_is_dragging = event.pressed
				if _is_dragging: _velocity = Vector3.ZERO 
				
				# Update the Global Cursor state based on drag
				if has_node("/root/GlobalCursor"):
					var cursor_node = get_node("/root/GlobalCursor")
					# Assuming your global script has a set_cursor or similar function
					# Change 'State.GRABBING' to whatever your enum/logic uses
					if _is_dragging:
						cursor_node.update_cursor(true) # True for clicking/grabbing
					else:
						cursor_node.update_cursor(false) # Back to normal

			# Wheel Zoom
			if event.is_action_pressed("zoom_in"):
				_target_zoom_distance = clamp(_target_zoom_distance - 2.0, min_zoom_distance, max_zoom_distance)
			if event.is_action_pressed("zoom_out"):
				_target_zoom_distance = clamp(_target_zoom_distance + 2.0, min_zoom_distance, max_zoom_distance)

		if event is InputEventMouseMotion and _is_dragging:
			handle_drag_pan(event.relative)

func handle_pinch_zoom():
	var keys = _touch_points.keys()
	var dist = _touch_points[keys[0]].distance_to(_touch_points[keys[1]])
	if _last_pinch_distance > 0:
		var screen_height = get_viewport().get_visible_rect().size.y
		var zoom_delta = (dist - _last_pinch_distance) / screen_height * pinch_sensitivity * 50.0
		_target_zoom_distance = clamp(_target_zoom_distance - zoom_delta, min_zoom_distance, max_zoom_distance)
	_last_pinch_distance = dist

func handle_drag_pan(relative: Vector2):
	var forward = -transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right = transform.basis.x
	right.y = 0
	right = right.normalized()

	var zoom_factor = _target_zoom_distance / 10.0
	var move_vec = (right * -relative.x + forward * relative.y) * drag_sensitivity * zoom_factor
	
	var new_position = position + move_vec
	if new_position.distance_to(initial_position) <= max_distance:
		position = new_position
	
	var d_time = get_process_delta_time()
	if d_time > 0:
		_velocity = (move_vec / d_time) * (momentum_multiplier * 0.1)

func handle_keyboard_movement(delta: float):
	if Globals.Editing_Business_Text: return
	var dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"): dir.z -= 1
	if Input.is_action_pressed("move_back"): dir.z += 1
	if Input.is_action_pressed("move_left"): dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1

	if dir.length() > 0:
		dir = dir.normalized()
		var speed = 2.0 if Input.is_action_pressed("faster") else 1.0
		var next_pos = position + dir * move_speed * speed * delta
		if next_pos.distance_to(initial_position) <= max_distance:
			position = next_pos

func handle_zoom_logic(delta: float):
	cam.position.y = lerp(cam.position.y, _target_zoom_distance, zoom_speed * delta)
	cam.position.z = cam.position.y * 0.6 

# --- CULLING LOGIC ---
func perform_frustum_culling():
	if not cam: return
	var frustum = _get_camera_frustum()
	var objects = get_tree().get_nodes_in_group("renderable")
	for obj in objects:
		if not is_instance_valid(obj): continue
		var in_view = _is_object_in_frustum(obj, frustum)
		if obj.visible != in_view:
			obj.visible = in_view
			for method in ["set_process", "set_physics_process"]:
				if obj.has_method(method): obj.call(method, in_view)

func _get_camera_frustum() -> Array:
	var frustum = []
	if not cam: return frustum
	
	var cam_xf = cam.global_transform
	var cam_pos = cam_xf.origin
	
	frustum.append({"normal": cam_xf.basis.z, "distance": -cam_xf.basis.z.dot(cam_pos + cam_xf.basis.z * cam.near)})
	frustum.append({"normal": -cam_xf.basis.z, "distance": cam_xf.basis.z.dot(cam_pos + cam_xf.basis.z * cam.far)})
	return frustum

func _is_object_in_frustum(obj: Node3D, frustum: Array) -> bool:
	var pos = obj.global_position
	if pos.distance_to(cam.global_position) > cam.far * cull_distance_multiplier:
		return false
	for plane in frustum:
		if plane["normal"].dot(pos) + plane["distance"] < -2.0:
			return false
	return true
