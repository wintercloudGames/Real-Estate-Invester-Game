extends TextureButton

@export var model_path: String
@export var display_name: String
@export var price: int

@onready var editor = get_tree().get_first_node_in_group("YardEditor")

func _ready():
	# Connect signals for the hover effect
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

func _on_mouse_entered():
	# Visual feedback: make the button slightly brighter
	self.modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	# Return to normal
	self.modulate = Color(1, 1, 1)

func _on_pressed():
	if editor:
		editor.start_dragging(model_path, price)
