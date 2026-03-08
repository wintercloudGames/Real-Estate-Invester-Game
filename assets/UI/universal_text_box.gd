extends Panel

@onready var scroll_container = get_node("/root/UniversalTextBox/MarginContainer/ScrollContainer")
@onready var vbox = get_node("/root/UniversalTextBox/MarginContainer/ScrollContainer/VBoxContainer")

# Function to display a list of information as scrollable labels
func show_information(info_list: Array) -> void:
	# Clear any existing labels
	if vbox and vbox.get_child_count() > 0:
		for child in vbox.get_children():
			child.queue_free()  # Free each child (clear all children)

	# Iterate over the list and create a new label for each piece of information
	for info in info_list:
		var label = Label.new()
		label.text = info
		label.autowrap_mode = true  # Enable text wrapping for long text
		label.rect_min_size = Vector2(200, 40)  # Set a minimum size for each label
		vbox.add_child(label)  # Add the label to the VBoxContainer

	# Scroll to the bottom of the list (smooth scroll)
	if scroll_container:
		scroll_container.scroll_vertical = 1.0  # Scroll to the bottom immediately

	# Optionally, add a small delay to allow the UI to update before scrolling, if desired
	await get_tree().create_timer(0.1).timeout  # Wait a bit before scrolling
	if scroll_container:
		scroll_container.scroll_vertical = 1.0  # Scroll to the bottom smoothly
