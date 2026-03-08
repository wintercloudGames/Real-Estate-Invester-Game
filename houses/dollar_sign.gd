extends MeshInstance3D

@export var rotation_speed: float = 50
@export var bob_height: float = 0.5
@export var bob_speed: float = 1.0

var original_position: Vector3
var time: float = 0.0

func _ready():
	original_position = position
	setup_input_detection()

func setup_input_detection():
	var area: Area3D
	if has_node("Area3D"):
		area = $Area3D
	else:
		area = Area3D.new()
		area.name = "Area3D"
		add_child(area)
	
	if not area.has_node("CollisionShape3D"):
		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(0.5, 0.5, 0.1)
		collision.shape = box_shape
		area.add_child(collision)
	
	if not area.input_event.is_connected(_on_rent_collect_input_event):
		area.input_event.connect(_on_rent_collect_input_event)

func _process(delta):
	time += delta
	rotate_y(deg_to_rad(rotation_speed * delta))
	position.y = original_position.y + sin(time * bob_speed) * bob_height

func _on_rent_collect_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if visible:
			if has_node("../AudioStreamPlayer"):
				$"../AudioStreamPlayer".play()
			var parent = get_parent()
			if parent and parent.has_method("collect_rent"):
				parent.collect_rent()
			
