extends Node3D


signal object_placed(object: Node3D)
signal edit_mode_changed(is_editing: bool)

signal model_selected(model_path: String)
signal edit_mode_toggled(is_editing: bool)

@export_category("Editor Settings")
@export var grid_size: float = 0.5
@export var rotation_speed: float = 0.5  # Mouse wheel rotation speed
@export var max_placement_distance: float = 100.0
@export var placement_offset: Vector3 = Vector3(0.0, 0.1, 0.0)
@export var preview_material: StandardMaterial3D
@export var terrain_collision_mask: int = 2
@export var ground_level: float = 0.0

# Node references
@onready var camera_3d: Camera3D = $Yard_camera
@onready var raycast: RayCast3D = $RayCast3D
@onready var ui: Control = $CanvasLayer/UI

# Editor state
var selected_model_scene: PackedScene = null
var preview_instance: Node3D = null
var is_dragging: bool = false
var current_rotation: float = 0.0
var edit_mode: bool = false

func _ready() -> void:
	# Configure raycast
	raycast.collision_mask = terrain_collision_mask
	raycast.enabled = true
	add_to_group("yard_editor")
	# Initial visibility states
	ui.visible = false
	camera_3d.current = false
	
	set_process_input(true)
	set_physics_process(true)

func enter_edit_mode():
	edit_mode_toggled.emit(true)
	camera_3d.current = true
	Globals.yard_edit = true
	ui.visible = true
	edit_mode = true
	edit_mode_changed.emit(true)

func exit_edit_mode():
	edit_mode_toggled.emit(false)
	camera_3d.current = false
	Globals.yard_edit = false
	ui.visible = false
	edit_mode = false
	edit_mode_changed.emit(false)
	cleanup_drag()

func _physics_process(delta: float):
	if is_dragging and preview_instance:
		update_raycast()
		update_preview_position()

func update_raycast():
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera_3d.project_ray_origin(mouse_pos)
	var dir = camera_3d.project_ray_normal(mouse_pos)
	
	# Adjust ray origin if too high
	if from.y > ground_level + 50:
		from.y = ground_level + 50
	
	raycast.global_position = from
	raycast.target_position = dir * max_placement_distance
	raycast.force_raycast_update()

func update_preview_position():
	if not preview_instance:
		return
	
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		
		var target_position = collision_point + (normal * placement_offset.y)
		preview_instance.global_position = calculate_snapped_position(target_position)
		preview_instance.rotation.y = current_rotation
		preview_instance.visible = true
	else:
		preview_instance.visible = false

func calculate_snapped_position(position: Vector3) -> Vector3:
	var result = position
	if grid_size > 0:
		result = result.snapped(Vector3(grid_size, grid_size, grid_size))
	return result

func select_model_via_button(model_path: String):
	if ResourceLoader.exists(model_path):
		select_model(model_path)
		model_selected.emit(model_path)
	else:
		push_error("Model path does not exist: " + model_path)

func select_model(path: String):
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	
	selected_model_scene = load(path)
	setup_preview()
	start_dragging()

func setup_preview():
	if preview_instance:
		preview_instance.queue_free()
	
	if selected_model_scene:
		preview_instance = selected_model_scene.instantiate()
		add_child(preview_instance)
		
		if preview_material:
			for mesh in preview_instance.find_children("*", "MeshInstance3D"):
				mesh.material_overlay = preview_material
		
		# Start position in front of camera
		preview_instance.global_position = camera_3d.global_position + camera_3d.global_transform.basis.z * -5
		preview_instance.visible = false

func start_dragging():
	if selected_model_scene:
		is_dragging = true
		current_rotation = 0.0
		if preview_instance:
			preview_instance.visible = true

func place_object():
	if is_dragging and preview_instance and selected_model_scene and raycast.is_colliding():
		var new_object = selected_model_scene.instantiate()
		add_child(new_object)
		
		new_object.global_position = preview_instance.global_position
		new_object.rotation.y = current_rotation
		object_placed.emit(new_object)

func rotate_object(amount: float):
	current_rotation += amount
	if preview_instance:
		preview_instance.rotation.y = current_rotation

func cleanup_drag():
	is_dragging = false
	if preview_instance:
		preview_instance.visible = false

func _input(event):
	if not edit_mode:
		return
	
	# Mouse wheel rotation
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rotate_object(rotation_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rotate_object(-rotation_speed)
	
	if event is InputEventMouseMotion and is_dragging:
		update_preview_position()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_dragging:
				place_object()
			elif selected_model_scene:
				start_dragging()
		
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cleanup_drag()
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			exit_edit_mode()

func _on_close_button_pressed():
	exit_edit_mode()
