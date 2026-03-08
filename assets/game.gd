# game.gd
extends Node3D

var selected_house = null
var house = null

@onready var House_ui = $HUD/House_info
@onready var Listing_ui = $HUD/House_listing_ui
@onready var EventPopup = $HUD/event_popup


func _ready() -> void:
	#SaveAndLoad.load_game()
	call_deferred("apply_loaded_data_deferred")
	get_tree().root.get_viewport().transparent_bg = true
	get_tree().root.get_viewport().transparent = true
	
	if Globals.first_start == false:
		$HUD/Game_start.visible = true
		Globals.reset()

	# Setup all the game systems with loaded data
	$Market.difficulty = Globals.difficulty
	$Market.apply_difficulty_settings()
	$Market.update_label()
	$HUD/Phone/Car_info.load_info()
	#$HUD/Phone/Loans.refresh_active_loan_mods()
	if Globals.business_name != "":
		$"HUD/Business_UI".Set_difficulty()
		$HUD/Business_UI.Load_info()
	
	$HUD/Phone/Car_info.car_level = Globals.car_level
	$HUD/Phone/Backgrounds.load_wallpaper_texture()

func apply_loaded_data_deferred() -> void:
	SaveAndLoad.apply_loaded_data()

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _process(delta: float) -> void:
	# Update the UI scale based on settings
	$HUD.scale = Vector2(Settings.UI_scale, Settings.UI_scale)
	
	if $HUD/Phone/Renters/ScrollContainer/renters.get_child_count() > 0:
		$HUD/UI/TextureButton/TextureRect.visible = true
		$HUD/UI/TextureButton/Label.text = str($HUD/Phone/Renters/ScrollContainer/renters.get_child_count())
	else:
		$HUD/UI/TextureButton/TextureRect.visible = false
		$HUD/UI/TextureButton/Label.text = ""
	
	if Globals.negative_month_count > 0:
		$HUD/UI/negative_month_count.visible = true
	else:
		$HUD/UI/negative_month_count.visible = false

	if Globals.negative_month_count > 12:
		$HUD/GAME_OVER.visible = true
		Engine.time_scale = 0  # Pause gametime
	# Update the qualified house count
	get_qualified_house_amount()

	# Reset global values before recalculating each cycle
	Globals.Propertys = 0
	Globals.net_worth = 0
	Globals.total_loan_amount = 0
	Globals.houses_with_tenants = 0
	Globals.Income = 0
	Globals.Expenses = 0

	Globals.listed_houses = 0  # Reset listed houses counter

	if Globals.send_to_account:
		Globals.Income = Globals.last_savings_paid
		
	if Globals.employees > 0:
		Globals.Expenses += $"HUD/Business_UI".BASE_SALARY * Globals.employees
	
	if Globals.hasagent:
		Globals.Expenses += 1000
	if Globals.hascleaner:
		Globals.Expenses += 500
	if Globals.renter_finder:
		Globals.Expenses += 500
	
	var total_payment = 0
	for mod in $HUD/Phone/Loans.active_loan_mods:
		if is_instance_valid(mod):
			if mod.autopay_enabled:
				Globals.Expenses += mod.payment

	if Globals.business_name != "":
		if Globals.difficulty == 0: #easy
			Globals.Expenses += 10000/4
		elif Globals.difficulty == 1:#normal
			Globals.Expenses += 10000/3
		elif Globals.difficulty == 2:#hard
			Globals.Expenses += 10000/2
		elif Globals.difficulty == 3:#INSANE
			Globals.Expenses += 10000

	var owned_houses = get_tree().get_nodes_in_group("houses")
	
	for house in owned_houses:
		if house.owned:
			Globals.net_worth += (house.base_price - house.loan_price)
			Globals.total_loan_amount += house.loan_price
			Globals.Propertys += 1
			
			if house.has_tenant:
				Globals.houses_with_tenants += 1
				if Globals.rent_bost > 0.0:
					Globals.Income += house.rent * (Globals.rent_bost + 1)
				else:
					Globals.Income += house.rent

			if house.is_listed:
				Globals.listed_houses += 1

	if Globals.year >= 100 or Globals.Player_health <= 0:
		$HUD/GAME_OVER.visible = true
		Engine.time_scale = 0  # Pause gametime
		$HUD/GAME_OVER.message("You died")

func get_qualified_house_amount():
	var down_payment = Globals.money
	var max_house_price = down_payment / 0.2
	if Globals.money >= 1000:
		$HUD/UI/GridContainer/House_qualify.text = "qualified house amount: " + add_comma_to_int(max_house_price)
	else:
		$HUD/UI/GridContainer/House_qualify.text = "qualified house amount: 0"
	
	for house in get_tree().get_nodes_in_group("houses"):
		if house.current_price <= max_house_price and not house.owned:
			house.create_label(true)
		else:
			house.create_label(false)

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
	Listing_ui.down_payment = house.current_price * 0.2
	Listing_ui.loan_display.text = "Loan\n80% Financed\nDown Payment: \n" + add_comma_to_int(Listing_ui.list_price * 0.2)
	Listing_ui.full_price = house.current_price
	Listing_ui.pay_now_amount = house.current_price
	Listing_ui.list_price = house.current_price
	if house.edit_mode == false:
		Listing_ui.visible = true
	Listing_ui.house = house

func set_house_UI():
	if house == null or House_ui == null:
		#print("Error: House or House UI is not assigned")
		return
	
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
	
	if parent_node:
		if parent_node.has_method("_display_main_menu"):
			parent_node._display_main_menu()


func _on_no_pressed() -> void:
	$HUD/Quit_menu.visible = false

func _on_texture_button_pressed() -> void:
	var has_offers = $HUD/Phone/Renters/ScrollContainer/renters.get_child_count() > 0
	
	if has_offers:
		# If there are offers, always ensure the phone is open and show the Renters tab.
		$HUD/Phone._on_texture_button_2_pressed()
		$HUD/Phone/Renters.visible = true
		if not $HUD/Phone.isout:
			$HUD/Phone.get_out()
			$HUD/Phone.isout = true
	else:
		# Normal toggle when no offers.
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
	if $HUD/UI/Skill_tree.visible == false:
		$HUD/UI/Skill_tree.visible = true
	elif $HUD/UI/Skill_tree.visible == true:
		$HUD/UI/Skill_tree.visible = false

func _on_business_button_pressed() -> void:
	if $HUD/Business_UI.visible == false:
		$HUD/Business_UI.visible = true
	elif $HUD/Business_UI.visible == true:
		$HUD/Business_UI.visible = false
