extends Node3D

var selected_house = null
var house = null

@onready var House_ui = $HUD/House_info
@onready var Listing_ui = $HUD/House_listing_ui
@onready var EventPopup = $HUD/event_popup

@onready var mission_win_panel: Control = $HUD/MissionWin
@onready var game_over_panel: Control = $HUD/GAME_OVER

func _ready() -> void:
	call_deferred("apply_loaded_data_deferred")
	
	Globals.month_ended.connect(simulate_market_buyers)
	
	if Globals.first_start == false:
		$HUD/Game_start.visible = true
		for house in get_tree().get_nodes_in_group("houses"):
			if not house.owned:
				house.for_sale = randf() < 0.20 
				house.current_price *= randf_range(0.85, 1.15)
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

func apply_loaded_data_deferred() -> void:
	SaveAndLoad.apply_loaded_data()
	
	await get_tree().process_frame
	
	
	if Globals.mission_active and Globals.year > Globals.mission_deadline_year:

		if game_over_panel:
			game_over_panel.visible = true
			var info = game_over_panel.get_node_or_null("Info")
			if info:
				info.text = "Mission Failed!\n" + Globals.mission_desc + "\nTime ran out!"
		Engine.time_scale = 0

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _process(delta: float) -> void:
	if Globals.mission_active and not Globals.mission_completed:
		# ─── WIN CHECK ────────────────────────────────────────
		if Globals.is_mission_complete():
			Globals.mission_completed = true
			if mission_win_panel:
				mission_win_panel.visible = true
			Engine.time_scale = 0
			print("MISSION WIN - ", Globals.mission_desc)
			return   # early out so we don't accidentally check fail

		# ─── LOSE CHECK ───────────────────────────────────────
		# Fail if we've passed the end of the deadline year
		var past_deadline = false
		
		if Globals.year > Globals.mission_deadline_year:
			past_deadline = true
		elif Globals.year == Globals.mission_deadline_year and Globals.month > 12:
			past_deadline = true 
			
		if past_deadline:
			Globals.mission_completed = true 
			if game_over_panel:
				game_over_panel.visible = true
				var info = game_over_panel.get_node_or_null("Info")
				if info:
					info.text = "Mission Failed!\n" + Globals.mission_desc + "\nTime's up!"
				else:
					print("Warning: No 'Info' label in GAME_OVER panel")
			Engine.time_scale = 0
			print("MISSION FAILED - year:", Globals.year, "deadline was:", Globals.mission_deadline_year)
		
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
	Globals.Propertys = 0
	Globals.net_worth = 0.0
	Globals.total_debt = 0.0           # Reset debt every frame
	Globals.total_loan_amount = 0
	Globals.houses_with_tenants = 0
	Globals.Income = 0
	Globals.listed_houses = 0

	# Savings as asset
	Globals.net_worth += Globals.Savings_balance
	if Globals.send_to_account == true:
		Globals.Income += Globals.interest
	# House stats loop
	var owned_houses = get_tree().get_nodes_in_group("houses")
	for house in owned_houses:
		if house.owned:
			var house_value = house.current_price
			var mortgage_remaining = house.loan_price
			
			var house_equity = house_value - mortgage_remaining
			Globals.net_worth += house_equity
			Globals.total_debt += mortgage_remaining
			Globals.total_loan_amount += mortgage_remaining
			
			Globals.Propertys += 1
			
			if house.has_tenant:
				Globals.houses_with_tenants += 1
				Globals.Income += house.rent * (Globals.rent_bost + 1 if Globals.rent_bost > 0 else 1)
			
			if house.is_listed:
				Globals.listed_houses += 1

	var loans_ui = $HUD/Phone/Loans
	if loans_ui:
		for mod in loans_ui.active_loan_mods:
			if is_instance_valid(mod):
				var balance = mod.loan_balance
				if typeof(balance) == TYPE_FLOAT or typeof(balance) == TYPE_INT:
					Globals.total_debt += float(balance)  # force float

	if typeof(Globals.total_debt) == TYPE_FLOAT or typeof(Globals.total_debt) == TYPE_INT:
		Globals.net_worth -= float(Globals.total_debt)

	Globals.total_debt = 0.0  # emergency reset
	# Final net worth = assets - all debt
	Globals.net_worth -= Globals.total_debt

	# Final age / health game over
	if Globals.year >= 100 or Globals.Player_health <= 0:
		if game_over_panel:
			game_over_panel.visible = true
			if game_over_panel.has_method("message"):
				game_over_panel.message("You died")
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
		var should_show = (house.current_price <= max_house_price 
			and not house.owned 
			and house.for_sale)
		house.create_label(should_show)

func simulate_market_buyers() -> void:
	# 1. Get current market 'heat' from your Market node
	# If price is high relative to base, market is 'Hot'
	var market_node = $Market
	var heat = clamp(market_node.current_price / market_node.base_price, 0.5, 2.0)
	
	var all_houses = get_tree().get_nodes_in_group("houses")
	
	for house in all_houses:
		if house.owned: continue # Skip houses the player owns
		
		if house.for_sale:
			# TICK THE CLOCK
			house.time_on_market += 1
			
			# --- NPC BUYING LOGIC (Demand) ---
			# Hotter market = Higher chance NPCs buy it immediately
			var buy_chance = 0.1 + (heat * 0.2) 
			
			# If the house is a 'Steal' (Price < Base), NPCs are more likely to grab it
			if house.current_price < house.base_price:
				buy_chance += 0.15

			if randf() < buy_chance:
				house.for_sale = false
				house.time_on_market = 0
				print("NPC bought: ", house.name)
			
			# --- PRICE DROP LOGIC (Desperate Sellers) ---
			# If house sits for 4+ months, drop price by 5%
			elif house.time_on_market >= 4:
				house.current_price *= 0.95
				# Round to nearest 5000 for realism
				house.current_price = round(house.current_price / 5000.0) * 5000
				print(house.name, " price dropped! It's getting stale.")
				
		else:
			# --- NEW LISTING LOGIC (Supply) ---
			# If a house is NOT for sale, there's a small chance the owner lists it
			# In a 'Cold' market (low heat), more people are forced to sell
			var list_chance = 0.05 + (1.0 - heat) * 0.1 
			if randf() < clamp(list_chance, 0.02, 0.15):
				house.for_sale = true
				house.time_on_market = 0
				# Reset price to a 'fresh' market value based on current economy
				house.current_price = house.base_price * heat * randf_range(0.9, 1.1)
				print("New Listing: ", house.name)
	
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
	Engine.time_scale = 1
	var ui_node = get_tree().get_current_scene().get_node("UserInterface")
	var parent_node = ui_node.get_parent()
	if parent_node and parent_node.has_method("_display_main_menu"):
		parent_node._display_main_menu()

func _on_no_pressed() -> void:
	$HUD/Quit_menu.visible = false

func _on_Phone_button_pressed() -> void:
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
	Engine.time_scale = 1.0                    # Unpause the game
	SaveAndLoad.delete_save_file(SaveAndLoad.current_save_slot)  # Delete current save (fresh start)
	Globals.reset()
	get_tree().reload_current_scene()
	
	
