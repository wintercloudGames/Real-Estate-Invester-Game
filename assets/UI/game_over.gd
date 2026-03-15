extends Control


func _on_button_pressed() -> void:
	Engine.time_scale = 1
	SaveAndLoad.delete_save_file(SaveAndLoad.current_save_slot)
	$"../.."._on_yes_pressed()

func _on_button_2_pressed() -> void:
	$"../event_popup".visible = false
	$"../event_popup/Relist_house_Button".visible = false
	$"../Quit_menu".visible = false
	$".".visible = false
	var save_path = SaveAndLoad.get_save_path(SaveAndLoad.current_save_slot)
	if save_path:
		await get_tree().create_timer(5).timeout
		#SaveAndLoad.load_game()
		if Globals.business_name != "":
			$HUD/Business_UI.Load_info()
	
func message(text):
	$Info.text = str(text)
