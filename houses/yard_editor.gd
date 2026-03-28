extends Node3D

@export var terrain_mask: int = 1 
@export var placement_offset: Vector3 = Vector3(0, 0.05, 0)

@onready var yard_camera: Camera3D = $Yard_camera
@onready var raycast: RayCast3D = $RayCast3D
@onready var ui_canvas: CanvasLayer = $CanvasLayer

var gameplay_camera: Camera3D
var preview_instance: Node3D = null
var current_model_path: String = ""
var current_price: int = 0
var is_dragging: bool = false
var is_edit_mode: bool = false

func _ready():
	add_to_group("YardEditor")
	# Ensure UI is hidden and this camera is off at start
	ui_canvas.visible = false
	yard_camera.current = false

func _input(event):
	# Example: Press 'E' to toggle Edit Mode
	if event.is_action_pressed("edit_mode_toggle"): 
		if is_edit_mode: 
			exit_edit_mode()
		else: 
			enter_edit_mode()

	if not is_edit_mode: return

	# Placement Controls (Only active if dragging an object)
	if is_dragging and preview_instance:
		if event.is_action_pressed("mouse_wheel_up"):
			preview_instance.rotate_y(deg_to_rad(15))
		if event.is_action_pressed("mouse_wheel_down"):
			preview_instance.rotate_y(deg_to_rad(-15))
		if event.is_action_pressed("mouse_left") and preview_instance.visible:
			place_object()
		if event.is_action_pressed("mouse_right"):
			cancel_placement()

func _physics_process(_delta):
	if is_edit_mode and is_dragging and preview_instance:
		update_preview_position()

func enter_edit_mode():
	# 1. Store the old camera so we can go back to it later
	gameplay_camera = get_viewport().get_camera_3d()
	
	# 2. Switch to Yard Camera
	yard_camera.make_current()
	
	# 3. Show UI and free mouse
	is_edit_mode = true
	ui_canvas.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func exit_edit_mode():
	cancel_placement()
	is_edit_mode = false
	ui_canvas.visible = false
	
	# 4. Switch back to Gameplay Camera
	if gameplay_camera:
		gameplay_camera.make_current()
	
	# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Uncomment if your game is FPS style

func update_preview_position():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = yard_camera.project_ray_origin(mouse_pos)
	var ray_dir = yard_camera.project_ray_normal(mouse_pos)
	
	raycast.global_position = ray_origin
	raycast.target_position = ray_dir * 100.0
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		preview_instance.global_position = raycast.get_collision_point() + placement_offset
		preview_instance.visible = true
	else:
		preview_instance.visible = false

func start_dragging(path: String, price: int):
	cancel_placement()
	current_model_path = path
	current_price = price
	
	var scene = load(path)
	if scene:
		preview_instance = scene.instantiate()
		# Add to root to prevent the object from drifting if the editor moves
		get_tree().root.add_child(preview_instance)
		apply_ghost_effect(preview_instance)
		is_dragging = true

func apply_ghost_effect(node):
	var ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.4)
	
	for mesh in node.find_children("*", "MeshInstance3D", true):
		for i in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(i, ghost_mat)

func place_object():
	if Globals.money >= current_price:
		Globals.money -= current_price
		var permanent = load(current_model_path).instantiate()
		
		# Add this to the "house_base" node so it's saved with the house
		get_parent().add_child(permanent) 
		
		permanent.global_position = preview_instance.global_position
		permanent.global_rotation = preview_instance.global_rotation
		cancel_placement()
	else:
		print("Not enough money!")

func cancel_placement():
	if preview_instance:
		preview_instance.queue_free()
	preview_instance = null
	is_dragging = false
