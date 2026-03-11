extends Node3D

var selected_house = null
var house = null

@onready var House_ui = $HUD/House_info
@onready var Listing_ui = $HUD/House_listing_ui
@onready var EventPopup = $HUD/event_popup

# Mission & Game Over panels (safer access)
@onready var mission_win_panel: Control = $HUD/MissionWin
@onready var game_over_panel: Control = $HUD/GAME_OVER

# Prevent repeated win/lose triggers
var mission_result_handled: bool = false

func _ready() -> void:
	
	call_deferred("apply_loaded_data_deferred")
	
	get_tree().root.get_viewport().transparent_bg = true
	get_tree().root.get_viewport().transparent = true
	
	if Globals.first_start == false:
		$HUD/Game_start.visible = true
		Globals.reset()
	# Setup systems
	$Market.difficulty = Globals.difficulty
	$Market.apply_difficulty_settings()
	$Market.update_label()
	$HUD/Phone/Car_info.load_info()

	if Globals.business_name != "":
		$"HUD/Business_UI".Set_difficulty()
		$HUD/Business_UI.Load_info()
	
	$HUD/Phone/Car_info.car_level = Globals.car_level 
	$HUD/Phone/Backgrounds.load_wallpaper_texture()
	
	# Ensure panels start hidden
	if mission_win_panel: mission_win_panel.visible = false
	if game_over_panel:   game_over_panel.visible   = false
	mission_result_handled = false

func apply_loaded_data_deferred() -> void:
	SaveAndLoad.apply_loaded_data()
	var path = "HUD/UI/MissionDisplay"
	var panel = get_node_or_null(path)
	panel.visible = Globals.mission_active

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _process(delta: float) -> void:
	if Globals.mission_active and not Globals.mission_completed:
		if Globals.mission_deadline_year <= Globals.year:
			print("SKIP EARLY CHECK - deadline not valid yet or already passed")
			return  # don't fail yet
		
		print("Mission check OK - Year:", Globals.year, "Deadline:", Globals.mission_deadline_year)
		
		if Globals.is_mission_complete():
			# win
			Globals.mission_completed = true
			$HUD/MissionWin.visible = true
			Globals.skillpoints += 100
			Engine.time_scale = 0
		elif Globals.year > Globals.mission_deadline_year:
			print("REAL MISSION FAIL - year > deadline")
			$HUD/GAME_OVER.visible = true
			$HUD/GAME_OVER.message("Mission Failed! " + Globals.mission_desc)
			Engine.time_scale = 0
	# UI scale
	$HUD.scale = Vector2(Settings.UI_scale, Settings.UI_scale)
	
	# Renters notification
	if $HUD/Phone/Renters/ScrollContainer/renters.get_child_count() > 0:
		$HUD/UI/TextureButton/TextureRect.visible = true
		$HUD/UI/TextureButton/Label.text = str($HUD/Phone/Renters/ScrollContainer/renters.get_child_count())
	else:
		$HUD/UI/TextureButton/TextureRect.visible = false
		$HUD/UI/TextureButton/Label.text = ""
	
	# Negative months warning
	$HUD/UI/negative_month_count.visible = Globals.negative_month_count > 0
	
	# Too many negative months → game over
	if Globals.negative_month_count > 12:
		if game_over_panel:
			game_over_panel.visible = true
		Engine.time_scale = 0
	
	# Update qualified houses
	get_qualified_house_amount()
	
	# Reset globals before recalculate
	Globals.Propertys = 0
	Globals.net_worth = 0
	Globals.total_loan_amount = 0
	Globals.houses_with_tenants = 0
	Globals.Income = 0
	Globals.listed_houses = 0
	# Savings income
	if Globals.send_to_account:
		Globals.Income = Globals.last_savings_paid
	
	Globals.net_worth += Globals.Savings_balance
	# House stats loop
	var owned_houses = get_tree().get_nodes_in_group("houses")
	for house in owned_houses:
		if house.owned:
			Globals.net_worth += (house.base_price - house.loan_price)
			Globals.total_loan_amount += house.loan_price
			Globals.Propertys += 1
			
			if house.has_tenant:
				Globals.houses_with_tenants += 1
				Globals.Income += house.rent * (Globals.rent_bost + 1 if Globals.rent_bost > 0 else 1)
			
			if house.is_listed:
				Globals.listed_houses += 1
	
	# Final age / health game over
	if Globals.year >= 100 or Globals.Player_health <= 0:
		if game_over_panel:
			game_over_panel.visible = true
			if game_over_panel.has_method("message"):
				game_over_panel.message("You died")
		Engine.time_scale = 0
	
	# ────────────────────────────────────────────────
	# Mission check (only if active and not yet handled)
	# ────────────────────────────────────────────────
	if Globals.mission_active and not Globals.mission_completed and not mission_result_handled:
		if Globals.is_mission_complete():
			Globals.mission_completed = true
			mission_result_handled = true
			if mission_win_panel:
				mission_win_panel.visible = true
			Globals.skillpoints += 100
			Engine.time_scale = 0
		
		elif Globals.year > Globals.mission_deadline_year:
			mission_result_handled = true
			if game_over_panel:
				game_over_panel.visible = true
				if game_over_panel.has_method("message"):
					game_over_panel.message("Mission Failed!\n" + Globals.mission_desc + "\nRestart?")
				else:
					# Fallback if no message method
					print("Mission Failed - year exceeded")
			Engine.time_scale = 0

# ────────────────────────────────────────────────
# Other functions (unchanged or minor cleanup)
# ────────────────────────────────────────────────

func get_qualified_house_amount():
	var down_payment = Globals.money
	var max_house_price = down_payment / 0.2
	if Globals.money >= 1000:
		$HUD/UI/GridContainer/House_qualify.text = "qualified house amount: " + add_comma_to_int(int(max_house_price))
	else:
		$HUD/UI/GridContainer/House_qualify.text = "qualified house amount: 0"
	
	for house in get_tree().get_nodes_in_group("houses"):
		house.create_label(house.current_price <= max_house_price and not house.owned)

func clear_House_ui_data():
	House_ui.price = 0
	House_ui.loan_price = 0
	House_ui.mortgage = 0
	House_ui.income = 0
	House_ui.house = null
	House_ui.has_tenant = false
	Listing_ui.full_price = 0
	Listing_ui.list_price = 0
	Listing_ui.house = null

func set_listing_UI():
	if not house: return
	Listing_ui.down_payment = house.current_price * 0.2
	Listing_ui.loan_display.text = "Loan\n80% Financed\nDown Payment: \n" + add_comma_to_int(int(Listing_ui.list_price * 0.2))
	Listing_ui.full_price = house.current_price
	Listing_ui.pay_now_amount = house.current_price
	Listing_ui.list_price = house.current_price
	if not house.edit_mode:
		Listing_ui.visible = true
	Listing_ui.house = house

func set_house_UI():
	if not house or not House_ui: return
	House_ui.price = house.current_price
	House_ui.house = house
	if not house.edit_mode:
		House_ui.visible = true
	if house.has_tenant:
		House_ui.income = house.rent

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		$HUD/Quit_menu.visible = true
		$HUD/UI/Skill_tree.visible = false

func _on_yes_pressed() -> void:
	var ui_node = get_tree().get_current_scene().get_node("UserInterface")
	var parent_node = ui_node.get_parent()
	if parent_node and parent_node.has_method("_display_main_menu"):
		parent_node._display_main_menu()

func _on_no_pressed() -> void:
	$HUD/Quit_menu.visible = false

func _on_texture_button_pressed() -> void:
	var has_offers = $HUD/Phone/Renters/ScrollContainer/renters.get_child_count() > 0
	if has_offers:
		$HUD/Phone._on_texture_button_2_pressed()
		$HUD/Phone/Renters.visible = true
		if not $HUD/Phone.isout:
			$HUD/Phone.get_out()
			$HUD/Phone.isout = true
	else:
		if not $HUD/Phone.isout:
			$HUD/Phone.get_out()
			$HUD/Phone.isout = true
		else:
			$HUD/Phone.put_away()
			$HUD/Phone.isout = false

func _on_hospital_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		$HUD/Hostpital_UI.visible = true

func _on_skills_button_pressed() -> void:
	$HUD/UI/Skill_tree.visible = !$HUD/UI/Skill_tree.visible

func _on_business_button_pressed() -> void:
	$HUD/Business_UI.visible = !$HUD/Business_UI.visible

func _on_mission_win_button_pressed() -> void:
	SaveAndLoad.delete_save_file(SaveAndLoad.current_save_slot)
	get_tree().change_scene_to_file("res://Menu/MainMenu.tscn")
