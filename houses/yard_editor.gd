extends Node3D

@export var placement_offset: Vector3 = Vector3(0, 0, 0)
@export var rotation_speed: float = 3.0 

@onready var ray_node: RayCast3D = $RayCast3D 
@onready var yard_camera: Camera3D = $Yard_camera
@onready var ui_canvas: CanvasLayer = $CanvasLayer
@onready var hint_label: Label = $CanvasLayer/UI/tips/Controlls
@onready var context_menu: Control = $CanvasLayer/ContextMenu

var target_pivot_node: Node3D = null
var target_house: Node3D = null 
var gameplay_camera: Camera3D = null
var preview_instance: Node3D = null
var selected_object: Node3D = null
var current_packed_scene_path: String = "" 
var current_price: int = 0
var is_dragging: bool = false
var is_edit_mode: bool = false

func _ready():
	add_to_group("YardEditor")
	ui_canvas.visible = false
	context_menu.visible = false
	ray_node.set_as_top_level(true) 
	ray_node.enabled = true
	
	# Connecting Context Menu Buttons
	$CanvasLayer/ContextMenu/MoveButton.pressed.connect(_on_move_pressed)
	$CanvasLayer/ContextMenu/SellButton.pressed.connect(_on_sell_pressed)
	$CanvasLayer/ContextMenu/CloseButton.pressed.connect(func(): context_menu.visible = false)

func _process(delta):
	if not is_edit_mode: return
	$CanvasLayer/UI/House_value.text = "house value: " + Globals.add_comma_to_int(target_house.current_price) 
	
	# 1. CAMERA ROTATION (Using your 'move_left/right' Input Map)
	var rot_input = Input.get_axis("move_right", "move_left")
	if rot_input != 0:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner: focus_owner.release_focus()
		rotate_y(rot_input * rotation_speed * delta)

	# 2. PLACEMENT & SELECTION
	if is_dragging:
		update_preview_position()
	
	update_controls_hint()

func update_preview_position():
	ray_node.collision_mask = 2 # Ground Layer
	update_ray_to_mouse()

	if ray_node.is_colliding() and is_instance_valid(preview_instance):
		preview_instance.global_position = ray_node.get_collision_point() + placement_offset
		preview_instance.visible = true

func update_ray_to_mouse():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = yard_camera.project_ray_origin(mouse_pos)
	var ray_dir = yard_camera.project_ray_normal(mouse_pos)
	
	# Move the actual RayCast node to the camera's position
	ray_node.global_position = ray_origin
	
	# Point it 100 meters into the screen
	var world_target = ray_origin + (ray_dir * 100.0)
	ray_node.target_position = ray_node.to_local(world_target)
	
	ray_node.force_raycast_update()

func _input(event):
	if not is_edit_mode: return

	# Left Click Handling
	if event.is_action_pressed("mouse_left"):
		# If the context menu is open and we click away, hide it
		if context_menu.visible:
			# Give UI a chance to process the button click first
			await get_tree().process_frame 
			if not Rect2(context_menu.global_position, context_menu.size).has_point(get_viewport().get_mouse_position()):
				context_menu.visible = false
			return

		if is_dragging:
			place_object()
		else:
			handle_selection_click()

	# Right Click / Cancel
	if event.is_action_pressed("mouse_right"):
		if is_dragging:
			delete_current_preview()
		else:
			context_menu.visible = false

	# Mouse Wheel Rotation
	if is_dragging and is_instance_valid(preview_instance):
		if event.is_action_pressed("zoom_in"): # Mouse Wheel Up
			preview_instance.rotate_y(deg_to_rad(15))
		elif event.is_action_pressed("zoom_out"): # Mouse Wheel Down
			preview_instance.rotate_y(deg_to_rad(-15))

func handle_selection_click():
	ray_node.collision_mask = 2 | 8 
	update_ray_to_mouse()
	
	if ray_node.is_colliding():
		var collider = ray_node.get_collider()
		print("HIT SOMETHING: ", collider.name) # DEBUG 1
		
		var current_node = collider
		while current_node != null:
			print("Checking parent: ", current_node.name) # DEBUG 2
			if current_node.get_parent() and current_node.get_parent().name == "YardObjects":
				selected_object = current_node
				show_context_menu()
				return
			current_node = current_node.get_parent()
		
		print("REJECTED: Not a child of YardObjects")
	else:
		print("RAYCAST MISSED: Hit nothing on Layer 4")

func show_context_menu():
	var mouse_pos = get_viewport().get_mouse_position()
	context_menu.global_position = mouse_pos
	context_menu.visible = true
	
	# Optional: Ensure the menu doesn't go off-screen
	var screen_size = get_viewport().get_visible_rect().size
	if context_menu.global_position.x + context_menu.size.x > screen_size.x:
		context_menu.global_position.x -= context_menu.size.x
	if context_menu.global_position.y + context_menu.size.y > screen_size.y:
		context_menu.global_position.y -= context_menu.size.y

func _on_move_pressed():
	context_menu.visible = false
	if is_instance_valid(selected_object):
		pick_up_placed_object(selected_object)
		selected_object = null

func _on_sell_pressed():
	context_menu.visible = false
	
	if is_instance_valid(selected_object):
		var original_price = selected_object.get_meta("price", 0)
		var refund_amount = int(original_price * 0.5)
		Globals.money += refund_amount
		target_house.get_total_yard_value()
		selected_object.queue_free()
		selected_object = null
		SaveAndLoad.save_game()

# --- Core Placement Logic ---

func pick_up_placed_object(obj: Node3D):
	current_packed_scene_path = obj.get_meta("scene_path", "")
	var saved_transform = obj.global_transform
	
	preview_instance = obj
	obj.get_parent().remove_child(obj)
	get_tree().root.add_child(preview_instance)
	
	preview_instance.global_transform = saved_transform
	apply_ghost_effect(preview_instance)
	is_dragging = true

func place_object():
	if not target_house or not is_instance_valid(preview_instance): return
	
	var saved_global_transform = preview_instance.global_transform
	
	if not preview_instance.get_meta("is_placed", false):
		if Globals.money < current_price: return
		Globals.money -= current_price
	
	var permanent = preview_instance
	if permanent.get_parent():
		permanent.get_parent().remove_child(permanent)
	
	var storage = target_house.get_node_or_null("YardObjects")
	if not storage:
		storage = Node3D.new()
		storage.name = "YardObjects"
		target_house.add_child(storage)
		storage.owner = target_house
		
	storage.add_child(permanent)
	permanent.global_transform = saved_global_transform
	permanent.owner = target_house 
	permanent.set_meta("is_placed", true)
	target_house.get_total_yard_value()
	remove_ghost_effect(permanent)
	is_dragging = false
	preview_instance = null
	SaveAndLoad.save_game()

func delete_current_preview():
	if is_instance_valid(preview_instance):
		preview_instance.queue_free()
	is_dragging = false
	preview_instance = null

func start_dragging_packed(scene: PackedScene, price: int):
	if is_dragging: delete_current_preview()
	context_menu.visible = false
	
	current_packed_scene_path = scene.resource_path
	current_price = price
	preview_instance = scene.instantiate()
	get_tree().root.add_child(preview_instance)
	preview_instance.set_meta("price", price)
	preview_instance.set_meta("scene_path", current_packed_scene_path)
	preview_instance.set_meta("is_placed", false) 
	
	apply_ghost_effect(preview_instance)
	is_dragging = true

func remove_ghost_effect(node):
	for mesh in node.find_children("*", "MeshInstance3D", true):
		for i in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(i, null)

func apply_ghost_effect(node):
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0, 1, 0.4) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	mat.no_depth_test = true 
	
	for mesh in node.find_children("*", "MeshInstance3D", true):
		for i in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(i, mat)

func update_controls_hint():
	if not hint_label: return
	if is_dragging:
		hint_label.text = "[LMB] Place | [RMB] Delete\n[Wheel] Rotate | [A/D] Orbit"
	else:
		hint_label.text = "[LMB] Select Object\n[A/D] Rotate View"

func _on_tips_toggled(toggled_on: bool) -> void:
	if hint_label:
		hint_label.visible = toggled_on

func enter_edit_mode():
	if not target_house: return
	target_pivot_node = target_house.get_node_or_null("Yard_center_for_camera")
	if target_pivot_node:
		self.global_position = target_pivot_node.global_position
		self.global_rotation.y = target_pivot_node.global_rotation.y
	else:
		self.global_position = target_house.global_position
	
	gameplay_camera = get_viewport().get_camera_3d()
	if yard_camera: yard_camera.make_current()
	
	is_edit_mode = true
	ui_canvas.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Globals.yard_edit = true

func exit_edit_mode():
	is_edit_mode = false
	ui_canvas.visible = false
	context_menu.visible = false
	if is_instance_valid(gameplay_camera): gameplay_camera.make_current()
	target_house = null
	Globals.yard_edit = false

func _on_ui_mouse_entered() -> void:
	if is_dragging:
		delete_current_preview()
