extends Node3D

var house = null

@onready var House_ui = $HUD/House_info
@onready var Listing_ui = $HUD/House_listing_ui

@onready var mission_win_panel: Control = $HUD/MissionWin
@onready var game_over_panel: Control = $HUD/GAME_OVER

func _ready() -> void:
	# 1. Immediate Setup (Things that don't depend on saved data)
	$camera/Camera3D.current = true
	Globals.yard_edit = false
	
	if not Globals.month_ended.is_connected(_check_mission_status):
		Globals.month_ended.connect(_check_mission_status)

	# 2. Defer everything else to ensure SaveAndLoad has finished its job
	call_deferred("initialize_game_logic")

func initialize_game_logic() -> void:

	var has_save = SaveAndLoad.save_file_exists(SaveAndLoad.current_save_slot) 
	$HUD/Game_start.visible = false
	
	if has_save:
		SaveAndLoad.load_game() # Ensure data is fetched from disk
		#Globals.check_for_new_unlocks()
		SaveAndLoad.apply_loaded_data() # Apply it to the house objects
		print("Data loaded. first_start is: ", Globals.first_start)
	
	# FINAL UI DECISION
	if Globals.active_mission != null:
		$HUD/Game_start.visible = false
		setup_mission_start()
	elif has_save and Globals.first_start == false:
		# We have a save and the player already clicked 'Start' once before
		$HUD/Game_start.visible = false
	else:
		# Truly a new game
		$HUD/Game_start.visible = true

	# 5. UI VISIBILITY (The final decision)
	if Globals.active_mission != null:
		$HUD/UI/MissionDisplay.visible = true
		setup_mission_start() 
		# Ensure popup is hidden during missions
		$HUD/Game_start.visible = false 
		
	else:
		# Show popup ONLY if first_start is still true
		$HUD/Game_start.visible = Globals.first_start

	# --- 6. SETUP REMAINING SYSTEMS (Difficulty, Phone, Business) ---
	$Market.difficulty = Globals.difficulty
	$Market.apply_difficulty_settings()
	$Market.update_label()
	
	$HUD/Phone/Car_info.load_info()
	$HUD/Phone/Car_info.car_level = Globals.car_level 
	$HUD/Phone/Backgrounds.load_wallpaper_texture()
	
	Globals.recalculate_expenses()
	$HUD/UI/JobDisplay.update_stats()
	
	if Globals.business_name != "":
		$HUD/Business_UI.Set_difficulty()
		$HUD/Business_UI.Load_info()

func setup_mission_start() -> void:
	if Globals.active_mission == null:
		push_error("Mission Mode started but no mission data was found!")
		return
	
	# 1. Store the mission in a local variable 'm' BEFORE resetting
	var m = Globals.active_mission
	
	# 2. Reset the globals (This might clear Globals.active_mission)
	Globals.reset(Globals.GameMode.MISSION)
	
	# 3. Restore the mission back to Globals so the rest of the game can see it
	Globals.active_mission = m
	
	# 4. Setup UI
	$HUD/Game_start.visible = false 
	$HUD/UI/MissionDisplay.visible = true
	$HUD/UI/MissionDisplay.update_mission_ui()
	
	# Now 'm' is guaranteed to exist
	Globals.notify("MISSION START: " + m.title, Color.YELLOW)
	
	SaveAndLoad.save_game()
	

func _check_mission_status():
	if Globals.current_game_mode != Globals.GameMode.MISSION or Globals.active_mission == null:
		return

	var m = Globals.active_mission

	# 1. Check for FAILURE (Time limit)
	if Globals.year > m.time_limit_year:
		$HUD/GAME_OVER.visible = true
		$HUD/GAME_OVER/Info.text = "You failed to reach the goals by Year " + str(m.time_limit_year)
		return

	# 2. Check for SUCCESS
	var has_money = Globals.money >= m.target_money
	var has_houses = Globals.Propertys >= m.target_houses
	var has_savings = Globals.Savings_balance >= m.target_savings

	if has_money and has_houses and has_savings:
		_trigger_mission_win()

func _trigger_mission_win():
	# 1. Get the current ID safely
	var current_id = Globals.active_mission.id
	
	# 2. Add to the list in GLOBALS (not SaveAndLoad)
	if not Globals.completed_missions.has(current_id):
		Globals.completed_missions.append(current_id)
		
		# 3. Tell your Save script to write the current Global state to disk
		SaveAndLoad.save_game() 
	
	mission_win_panel.visible = true
	Engine.time_scale = 0
	

func _process(delta: float) -> void:
	# UI scale
	$HUD.scale = Vector2(Settings.UI_scale, Settings.UI_scale)

	# Renters notification
	if $HUD/Phone/Renters/ScrollContainer/renters.get_child_count() > 0:
		$HUD/UI/Phone_button/RedDot.visible = true
		$HUD/UI/Phone_button/Number.text = str($HUD/Phone/Renters/ScrollContainer/renters.get_child_count())
	else:
		$HUD/UI/Phone_button/RedDot.visible = false
		$HUD/UI/Phone_button/Number.text = ""

	# Negative months warning
	$HUD/UI/negative_month_count.visible = Globals.negative_month_count > 0

	# Too many negative months → instant game over
	if Globals.negative_month_count > 12:
		if game_over_panel:
			game_over_panel.visible = true
		Engine.time_scale = 0

	# Update qualified houses
	get_qualified_house_amount()

	# Reset globals before recalculating
	Globals.last_economy_update_time += delta
	if Globals.last_economy_update_time >= Globals.ECONOMY_UPDATE_INTERVAL:
		Globals.last_economy_update_time = 0.0
		Globals.update_economy()

	# Final age / health game over
	if Globals.year >= 100 or Globals.Player_health <= 0:
		if game_over_panel:
			game_over_panel.visible = true
			if game_over_panel.has_method("message"):
				game_over_panel.message("You died")
		Engine.time_scale = 0
	
func get_qualified_house_amount():
	var down_payment = Globals.money
	var down_payment_percent = 0.2
	var can_use_loan = true
	
	# 1. Determine credit-based constraints
	if Globals.credit_score >= 750:
		down_payment_percent = 0.15 # Excellent
	elif Globals.credit_score >= 680:
		down_payment_percent = 0.20 # Good
	elif Globals.credit_score >= 620:
		down_payment_percent = 0.25 # Fair
	else:
		down_payment_percent = 0.30 # Poor
		if Globals.credit_score < 500:
			can_use_loan = false # Blacklisted
	
	# 2. Calculate Max Price (Rounded to $500 to match Market)
	var max_house_price = 0
	if can_use_loan:
		# Use floor() to ensure we don't round UP into money the player doesn't have
		max_house_price = floor((down_payment / down_payment_percent) / 500.0) * 500
	else:
		max_house_price = floor(down_payment / 500.0) * 500
	
	# 3. Update Labels
	var house_qualify_label = $HUD/Phone/credit_info/VBoxContainer/house_qualify
	var stats_label = $HUD/Phone/credit_info/VBoxContainer/stats
	
	if house_qualify_label and stats_label:
		if Globals.money >= 1000:
			house_qualify_label.text = "Qualified Amount: $" + Globals.add_comma_to_int(int(max_house_price))
			stats_label.text = "Credit eligible for loans." if can_use_loan else "Low credit! Cash only."
		else:
			house_qualify_label.text = "Qualified Amount: $0"
			stats_label.text = "Insufficient funds."

	# 4. Update House World Labels
	# This ensures the 3D "Affordable!" tag only shows if they pass the CREDIT check
	for house in get_tree().get_nodes_in_group("houses"):
		var is_available = house.for_sale and not house.owned
		# Check if the specific house price fits within the Credit-Adjusted Max
		var can_afford = (house.current_price <= max_house_price)
		
		house.create_label(can_afford and is_available)

func clear_House_ui_data():
	House_ui.house = null
	Listing_ui.house = null
	Listing_ui.full_price = 0
	Listing_ui.list_price = 0
	House_ui.rent_slider_info.text = ""

func set_listing_UI():
	if not house: return
	
	var ui_cam = Listing_ui.get_node("SubViewportContainer/SubViewport/ListingCam")
	
	var house_marker = house.get_node("Camera_Front") 
	ui_cam.global_transform = house_marker.global_transform
	
	Listing_ui.visible = true
	Listing_ui.house = house
	
	Listing_ui.down_payment = house.current_price * 0.2
	Listing_ui.list_price = house.current_price
	
	var down_pay_val = int(Listing_ui.list_price * 0.2)
	Listing_ui.loan_display.text = "Loan\n80% Financed\nDown Payment: \n$" + Globals.add_comma_to_int(down_pay_val)
	
	Listing_ui.full_price = house.current_price
	Listing_ui.pay_now_amount = house.current_price
	
	if not house.edit_mode:
		Listing_ui.visible = true
	Listing_ui.house = house

func set_house_UI():
	if not house or not House_ui: return
	House_ui.house = house
	House_ui.setup_slider()
	if not house.edit_mode:
		House_ui.visible = true

func _on_edit_yard_button_pressed(house):
	if not house: return
	if house:
		$Yard_editor.target_house = house
		$Yard_editor.enter_edit_mode()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		$HUD/Quit_menu.visible = true
		$HUD/UI/Skill_tree.visible = false

func _on_yes_pressed() -> void:
	Engine.time_scale = 1
	var ui_node = get_tree().get_current_scene().get_node("UserInterface")
	var parent_node = ui_node.get_parent()
	if parent_node and parent_node.has_method("_display_main_menu"):
		parent_node._display_main_menu()

func _on_no_pressed() -> void:
	$HUD/Quit_menu.visible = false

func _on_hospital_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		$HUD/Hostpital_UI.visible = true

func _on_skills_button_pressed() -> void:
	$HUD/UI/Skill_tree.visible = !$HUD/UI/Skill_tree.visible

func _on_business_button_pressed() -> void:
	$HUD/Business_UI.visible = !$HUD/Business_UI.visible


func _on_mission_win_button_pressed() -> void:
	Engine.time_scale = 1
	
	# 1. Physical Cleanup
	for house in get_tree().get_nodes_in_group("houses"): 
		house.sell_house()

	var loan_container = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans/TabContainer/Loans/ScrollContainer/loan_mod_Container") 
	if loan_container:
		for child in loan_container.get_children():
			child.queue_free()

	# 2. Update Progress
	if Globals.active_mission != null:
		var mid = Globals.active_mission.id
		if not Globals.completed_missions.has(mid):
			Globals.completed_missions.append(mid)

	# 3. PREPARE THE DATA FOR SAVING
	# We clear the active mission object, but KEEP the mode as MISSION
	Globals.active_mission = null 
	Globals.current_game_mode = Globals.GameMode.MISSION 
	
	# 4. SAVE NOW
	# Because current_game_mode is MISSION, the save file will record it correctly
	SaveAndLoad.save_game()
	
	# 5. NOW RESET AND EXIT
	# We call reset LAST so it doesn't mess up the save we just made
	Globals.reset() 
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
