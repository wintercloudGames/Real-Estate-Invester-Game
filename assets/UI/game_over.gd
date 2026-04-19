extends Control

func _on_exit_button_pressed() -> void:
	Engine.time_scale = 1
	
	# 1. Clean up the world objects
	for house in get_tree().get_nodes_in_group("houses"): 
		house.sell_house()

	var loan_container = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans/TabContainer/Loans/ScrollContainer/loan_mod_Container") 
	if loan_container:
		for child in loan_container.get_children():
			child.queue_free()

	var loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans") 
	if loans_ui and "active_loan_mods" in loans_ui:
		loans_ui.active_loan_mods.clear()

	Globals.active_mission = null 
	
	Globals.current_game_mode = Globals.GameMode.FREEPLAY
	
	# 4. Save the current state (Money and previous Missions are preserved)
	SaveAndLoad.save_game()
	
	_goto_menu()

func _goto_menu():
	# We use self.get_tree() to be explicit 
	var tree = self.get_tree()
	if tree:
		var ui_node = tree.get_current_scene().get_node_or_null("UserInterface")
		if ui_node:
			var parent_node = ui_node.get_parent()
			if parent_node and parent_node.has_method("_display_main_menu"):
				parent_node._display_main_menu()
				return
		
		# Fallback if the hierarchy is different or UserInterface is missing 
		tree.change_scene_to_file("res://Menu/MainMenu.tscn")
