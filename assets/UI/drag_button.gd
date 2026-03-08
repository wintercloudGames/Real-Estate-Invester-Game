extends TextureButton

var dragging := false
var drag_offset := Vector2.ZERO  # offset between mouse and parent position when dragging starts

func _process(delta):
	if dragging and get_parent():
		# Keep the same offset during drag
		get_parent().global_position = get_global_mouse_position() - drag_offset

func _on_button_down():
	if get_parent():
		dragging = true
		# Store the offset between mouse and parent origin at click
		drag_offset = get_global_mouse_position() - get_parent().global_position

func _on_button_up():
	dragging = false
