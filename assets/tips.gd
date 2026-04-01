extends Button


func _on_pressed() -> void:
	var label = $Controlls
	if label.visible == true:
		label.visible = false
	elif label.visible == false:
		label.visible = true
