extends Control


func _on_button_pressed() -> void:
	if Globals.money >= 500:
		Globals.money -= 500
		Globals.Player_health += 25


func _on_button_2_pressed() -> void:
	if Globals.money >= 2000:
		Globals.money -= 2000
		Globals.Player_health += 75


func _on_close_button_pressed() -> void:
	visible = false
