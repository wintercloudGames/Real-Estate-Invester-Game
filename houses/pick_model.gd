extends TextureButton

@export var model_scene: PackedScene # Drag your .tscn file here in the Inspector
@export var price: int = 100

func _pressed() -> void:
	if not model_scene:
		print("❌ Button Error: No scene assigned in Inspector!")
		return
		
	var editor = get_tree().get_first_node_in_group("YardEditor")
	if editor:
		editor.start_dragging_packed(model_scene, price)
	else:
		print("❌ Error: YardEditor node not found in group 'YardEditor'")

func _ready():
	$Label.text = "$" + str(price)
	# Connect signals for the hover effect
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered():
	# Visual feedback: make the button slightly brighter
	self.modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	# Return to normal
	self.modulate = Color(1, 1, 1)
