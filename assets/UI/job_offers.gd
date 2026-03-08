extends TextureButton


var job_offer = 0

var textures = [
	preload("res://3D assets/faces/avatar (1).png"),
	preload("res://3D assets/faces/avatar (2).png"),
	preload("res://3D assets/faces/avatar.png")
]

func _ready():
	set_random_texture()

func set_random_texture():
	texture_normal = textures[randi() % textures.size()]  # For TextureButtontexture = textures[randi() % textures.size()]  # Use this if it's a TextureRect

func _on_pressed() -> void:
	var parent_node = self.get_parent()
	
	# Loop through all siblings of the button and remove them
	for sibling in parent_node.get_children():
		if sibling != self:  # Avoid removing the button itself again
			sibling.queue_free()
	self.queue_free()
	
