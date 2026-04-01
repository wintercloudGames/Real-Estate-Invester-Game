extends Node3D

# Camera movement settings
@export var move_speed: float = 10.0
@export var zoom_speed: float = 5.0
@export var min_zoom_distance: float = 5.0
@export var max_zoom_distance: float = 50.0
@export var edge_scroll_speed: float = 10.0
@export var edge_margin: int = 20
@export var max_distance: float = 30.0

# FRUSTUM CULLING SETTINGS
@export var enable_frustum_culling: bool = true
@export var cull_check_interval: float = 0.2  # Check every 0.2 seconds instead of every frame
@export var cull_distance_multiplier: float = 1.5  # Extra margin for culling

# Internal variables
var _target_zoom_distance: float = 10.0
var _cull_timer: float = 0.0
var _visible_objects: Array = []

var _process_interval: float = 0.0
var _process_timer: float = 0.0

@onready var cam = $Camera3D
var initial_position: Vector3

func _ready():
	_target_zoom_distance = cam.position.distance_to(self.position)
	initial_position = self.position
	
	# Initial culling pass
	if enable_frustum_culling:
		perform_frustum_culling()

func _process(delta):
	 # Only process occasionally instead of every frame
	_process_timer += delta
	if _process_timer >= _process_interval:
		_process_timer = 0.0
		_process_interval = max(0.016, Engine.get_frames_per_second() / 1000.0)  # Adaptive
	handle_movement(delta)
	handle_zoom(delta)
	handle_edge_scroll(delta)
	
	# Periodic frustum culling
	if enable_frustum_culling:
		_cull_timer += delta
		if _cull_timer >= cull_check_interval:
			_cull_timer = 0.0
			perform_frustum_culling()

# FRUSTUM CULLING FUNCTIONS
func perform_frustum_culling():
	if not cam:
		return
	
	# Get camera frustum planes
	var frustum = _get_camera_frustum()
	
	# Process all renderable objects
	var renderable_objects = get_tree().get_nodes_in_group("renderable")
	
	for obj in renderable_objects:
		if not is_instance_valid(obj):
			continue
		
		var should_be_visible = _is_object_in_frustum(obj, frustum)
		
		# Only change visibility if it's different
		if obj.visible != should_be_visible:
			obj.visible = should_be_visible
			
			# Also disable processing for hidden objects
			if obj.has_method("set_process"):
				obj.set_process(should_be_visible)
			if obj.has_method("set_physics_process"):
				obj.set_physics_process(should_be_visible)

func _get_camera_frustum() -> Array:
	var frustum = []
	var camera = cam
	
	if not camera:
		return frustum
	
	# Get camera transform
	var camera_transform = camera.global_transform
	var camera_position = camera_transform.origin
	
	# Get camera properties for frustum calculation
	var fov = deg_to_rad(camera.fov)
	var aspect = float(get_viewport().size.x) / float(get_viewport().size.y)
	var near = camera.near
	var far = camera.far
	
	# Calculate frustum planes (simplified version)
	var half_v_fov = fov / 2.0
	var half_h_fov = atan(tan(half_v_fov) * aspect)
	
	# Define frustum planes (normal and distance)
	# This is a simplified frustum calculation - for exact use Camera3D's built-in methods
	frustum.append({
		"normal": camera_transform.basis.z,  # Near plane
		"distance": -camera_transform.basis.z.dot(camera_position + camera_transform.basis.z * near)
	})
	
	frustum.append({
		"normal": -camera_transform.basis.z,  # Far plane
		"distance": camera_transform.basis.z.dot(camera_position + camera_transform.basis.z * far)
	})
	
	return frustum

func _is_object_in_frustum(obj: Node3D, frustum: Array) -> bool:
	if not is_instance_valid(obj) or not obj.visible:
		return false
	
	# Simple distance check first (cheaper)
	var obj_pos = obj.global_position
	var camera_pos = cam.global_position
	var distance = obj_pos.distance_to(camera_pos)
	
	if distance > cam.far * cull_distance_multiplier:
		return false
	
	# If object has a mesh, use its AABB for more accurate culling
	if obj is MeshInstance3D:
		var aabb = obj.get_aabb()
		var global_aabb = aabb.abs().grown(aabb.get_longest_axis_size() * 0.1)
		global_aabb.position += obj_pos
		
		# Check against frustum planes
		for plane in frustum:
			var normal = plane["normal"]
			var distance_to_plane = plane["distance"]
			
			# Get the positive vertex (the vertex that's most in the direction of the plane normal)
			var positive_vertex = Vector3(
				global_aabb.position.x if normal.x >= 0 else global_aabb.end.x,
				global_aabb.position.y if normal.y >= 0 else global_aabb.end.y,
				global_aabb.position.z if normal.z >= 0 else global_aabb.end.z
			)
			
			if normal.dot(positive_vertex) + distance_to_plane < 0:
				return false
		
		return true
	
	# For non-mesh objects, simple sphere test
	var sphere_radius = 2.0  # Default radius assumption
	if "radius" in obj:
		sphere_radius = obj.radius
	
	for plane in frustum:
		var normal = plane["normal"]
		var distance_to_plane = plane["distance"]
		
		if normal.dot(obj_pos) + distance_to_plane < -sphere_radius:
			return false
	
	return true

# OPTIMIZED VERSION: Simple distance-based culling (less accurate but much faster)
func perform_simple_culling():
	if not cam:
		return
	
	var camera_pos = cam.global_position
	var cull_distance = cam.far * cull_distance_multiplier
	
	var renderable_objects = get_tree().get_nodes_in_group("renderable")
	
	for obj in renderable_objects:
		if not is_instance_valid(obj):
			continue
		
		var distance = obj.global_position.distance_to(camera_pos)
		var should_be_visible = distance <= cull_distance
		
		if obj.visible != should_be_visible:
			obj.visible = should_be_visible

# Your existing functions with small optimizations
func handle_movement(delta: float):
	var direction = Vector3.ZERO
	if Globals.yard_edit:
		return
	
	if Globals.Editing_Business_Text == false:
		if Input.is_action_pressed("move_forward"):
			direction.z -= 1
		if Input.is_action_pressed("move_back"):
			direction.z += 1
		if Input.is_action_pressed("move_left"):
			direction.x -= 1
		if Input.is_action_pressed("move_right"):
			direction.x += 1

	if direction.length() > 0:
		direction = direction.normalized()

	var speed_multiplier = 2.0 if Input.is_action_pressed("faster") else 1.0
	var new_position = position + direction * move_speed * speed_multiplier * delta
	
	var distance_from_start = new_position.distance_to(initial_position)
	if distance_from_start <= max_distance:
		position = new_position

func handle_zoom(delta: float):
	var zoom_direction = 0

	if Input.is_action_pressed("zoom_in"):
		zoom_direction -= 1
	if Input.is_action_pressed("zoom_out"):
		zoom_direction += 1

	_target_zoom_distance += zoom_direction * zoom_speed
	_target_zoom_distance = clamp(_target_zoom_distance, min_zoom_distance, max_zoom_distance)

	var current_distance = cam.position.distance_to(self.position)
	var new_distance = lerp(current_distance, _target_zoom_distance, zoom_speed * delta)
	cam.position = cam.position.normalized() * new_distance

func handle_edge_scroll(delta: float):
	if Globals.yard_edit:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var edge_direction = Vector3.ZERO
	
	if DisplayServer.window_is_focused():
		if mouse_pos.x < edge_margin:
			edge_direction.x -= 1
		if mouse_pos.x > viewport_size.x - edge_margin:
			edge_direction.x += 1
		if mouse_pos.y < edge_margin:
			edge_direction.z -= 1
		if mouse_pos.y > viewport_size.y - edge_margin:
			edge_direction.z += 1

	if edge_direction.length() > 0:
		edge_direction = edge_direction.normalized()
		var new_position = position + edge_direction * edge_scroll_speed * delta
		var distance_from_start = new_position.distance_to(initial_position)
		if distance_from_start <= max_distance:
			translate(edge_direction * edge_scroll_speed * delta)

# Debug function to see culling results
func _input(event):
	if event.is_action_pressed("ui_page_up"):
		enable_frustum_culling = !enable_frustum_culling
		if enable_frustum_culling:
			perform_frustum_culling()
