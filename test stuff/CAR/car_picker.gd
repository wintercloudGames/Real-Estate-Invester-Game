extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	show_random_child(self)


func show_random_child(parent_node: Node):
	var children = parent_node.get_children()
	
	if children.size() == 0:
		print("No children found to show!")
		return

	# 2. Hide all children first (Reset)
	for child in children:
		if child is Node3D or child is CanvasItem:
			child.visible = false
	
	# 3. Pick one random child and make it visible
	var random_child = children.pick_random()
	random_child.visible = true
	
	return random_child # Returns the node in case you need to do more with it
