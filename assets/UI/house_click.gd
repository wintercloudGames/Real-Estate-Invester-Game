extends Node3D

@export var is_building = false
@export var plot = false
var rarity: float = 1.0
var base_price: float = 0
var current_price: float = 0
var previous_price: float = 0
var mortgage = 0
var rent = 0
var lease_length = 0
var apartment_condition = 1
var payment_punctuality = 1
var mortgage_deducted = false
var tenant_offers = null
var is_listed = false
var edit_mode = false
var stored_cash = 0

@onready var Collect_Rent = $Collect_Rent
@onready var Listing_ui: Node = get_node("/root/Root/UserInterface/Game/HUD/House_listing_ui")
@onready var events: Node = get_node("/root/Root/UserInterface/Game/events")
@onready var House_ui: Node = get_node("/root/Root/UserInterface/Game/HUD/House_info")
@onready var renter = null
@onready var game: Node = get_node("/root/Root/UserInterface/Game")
@onready var spot_light_3d: SpotLight3D = $SpotLight3D
@onready var spot_light_3d_2: SpotLight3D = $SpotLight3D2

var id: String = "" 
var bought_price = 0
var loan_price = 0.0 
var owned = false
var has_loan = false
var has_tenant = false
var tenant = null
var paid_rent = false
var just_bought = false
var upgrade_max: int = 10
var upgrade_amount: int = 0
var for_sale = false
var time_on_market = 0
var owner_type: String = "none"
var loan_module: Control = null
var is_on_screen: bool = true

# Performance Optimization Cache Values
var _frame_count: int = 0
var _last_rendered_price: int = -1
var _last_rendered_cashflow: int = -999999
var _last_rendered_loan: int = -1
var _last_player_money: int = -1
var _last_state_string: String = ""

func _init():
	add_to_group("houses")
	
func _enter_tree() -> void:
	if id == "":
		id = "house_" + str(get_path().hash())

func _ready() -> void:
	Globals.month_ended.connect(_on_month_ended)
	base_price = randi_range(80000, 500000) * rarity
	current_price = base_price
	Collect_Rent = $Collect_Rent
	randomize()
	previous_price = base_price
	loan_price = current_price * 0.8

func _on_visible_on_screen_notifier_3d_screen_entered():
	is_on_screen = true
	_force_ui_refresh()

func _on_visible_on_screen_notifier_3d_screen_exited():
	is_on_screen = false
	# Completely clear labels when off-screen to remove them from the render queue
	$Label3D.text = ""
	$Label3D2.text = ""
	$Label3D3.text = ""
	$Label3D4.text = ""
	$Label3D5.text = ""

func _force_ui_refresh():
	_last_rendered_price = -1
	_last_rendered_cashflow = -999999
	_last_rendered_loan = -1
	_last_player_money = -1
	_last_state_string = ""

func add_to_base_price(amount: int):
	base_price += amount
	_force_ui_refresh()

func set_as_ai_owned():
	owned = true
	owner_type = "ai"
	add_to_group("ai_owned")
	if has_node("Label3D5"):
		$Label3D5.text = "Owned by AI"
		$Label3D5.modulate = Color.ORANGE

var remaining_months: int = 0
func set_remaining_months(new_months: int) -> void:
	remaining_months = new_months

func get_total_yard_value() -> int:
	var total = 0
	var storage = get_node_or_null("YardObjects")
	if storage:
		for object in storage.get_children():
			total += object.get_meta("price", 0)
	return total

func update_market_value(market_change_percent: float) -> void:
	previous_price = current_price
	if abs(market_change_percent) < 0.0005:
		return
	var market_multiplier = 1.0 + market_change_percent
	var noise = randf_range(0.9975, 1.0025)
	current_price = max(round((previous_price * market_multiplier * noise) / 500.0) * 500, 500)
	# Queue an update check because pricing metrics altered
	_last_rendered_price = -1

func _on_month_ended():
	if owned: return
	
func open_house_ui():
	if game:
		game.house = self 
		game.set_house_UI() 

func _on_relist_house_button_pressed():
	is_listed = true
	Globals.notify("Relisted " + id, Color.LAWN_GREEN)
	_force_ui_refresh()

@onready var camera_front: Marker3D = $Camera_Front

func get_camera_location() -> Transform3D:
	if is_instance_valid(camera_front):
		return camera_front.global_transform
	return global_transform 

func _process(_delta: float) -> void:
	_frame_count += 1
	
	# If completely off-screen, skip visual formatting entirely.
	# We process background affordability variables on an interval loop (every 15 frames)
	if not is_on_screen:
		if _frame_count % 15 == 0:
			# Check background states if necessary, otherwise skip completely
			pass
		return

	if Globals.yard_edit == true:
		if _last_state_string != "yard_edit":
			$Label3D.text = ""
			$Label3D2.text = ""
			$Label3D3.text = ""
			$Label3D4.text = ""
			$Label3D5.text = ""
			_last_state_string = "yard_edit"
		return
		
	_last_state_string = "active"

	if owned:
		# --- OWNED PROPERTY LOGIC ---
		if loan_price > 0:
			if _last_rendered_loan != int(loan_price):
				$Label3D.text = "FINANCED PROPERTY"
				$Label3D.modulate = Color.FIREBRICK
				$Label3D2.text = "Loan Balance: " + add_comma_to_int(int(loan_price))
				$Label3D2.visible = true
				_last_rendered_loan = int(loan_price)
			has_loan = true
		else:
			if _last_rendered_loan != 0:
				$Label3D.text = "OWNED PROPERTY"
				$Label3D.modulate = Color.GREEN
				$Label3D2.visible = false
				$Label3D2.text = ""
				_last_rendered_loan = 0
			has_loan = false
			mortgage = 0
			loan_price = 0

		if has_tenant and rent > 0:
			var effective_rent = rent
			if Globals.rent_bost > 0.0:
				effective_rent = rent * (1.0 + Globals.rent_bost)
			
			var cashflow = int(effective_rent - mortgage)
			if _last_rendered_cashflow != cashflow:
				$Label3D3.text = "CashFlow: " + add_comma_to_int(cashflow)
				$Label3D3.modulate = Color.GREEN if cashflow >= 0 else Color.RED
				_last_rendered_cashflow = cashflow
		else:
			if _last_rendered_cashflow != 0:
				$Label3D3.text = ""
				_last_rendered_cashflow = 0
		
		$Label3D4.text = "Listed For Rent" if (is_listed and not has_tenant) else ""
		$Label3D4.modulate = Color.CYAN
		$Label3D5.text = ""

	else:
		# --- UNOWNED PROPERTY LOGIC ---
		var price_int = int(current_price)
		if _last_rendered_price != price_int:
			$Label3D.text = add_comma_to_int(price_int)
			$Label3D.modulate = Color.WHITE if for_sale else Color(0.7, 0.7, 0.7)
			_last_rendered_price = price_int
			
		$Label3D2.text = ""
		$Label3D3.text = ""
		
		# Combine state evaluations to reduce processing paths
		if is_in_group("ai_owned") and for_sale:
			$Label3D5.text = "Competitor Listing"
			$Label3D5.modulate = Color.ORANGE
		elif for_sale:
			$Label3D4.text = "FOR SALE"
			$Label3D4.modulate = Color.ORANGE
			
			# Only update affordability text if player bank records change
			var current_player_money = int(Globals.money)
			if _last_player_money != current_player_money:
				var down_payment_needed = current_price * 0.2
				if current_player_money >= down_payment_needed:
					$Label3D5.text = "Affordable!"
					$Label3D5.modulate = Color.ORANGE
				else:
					$Label3D5.text = ""
				_last_player_money = current_player_money
		else:
			$Label3D4.text = ""
			$Label3D5.text = ""

func create_label(is_affordable: bool):
	if has_node("Label3D5"):
		$Label3D5.visible = is_affordable
		$Label3D5.text = "Affordable!"
		$Label3D5.modulate = Color.GREEN

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_area_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and !Globals.yard_edit:
		game.house = self
		if owned:
			game.set_house_UI()
		else:
			if for_sale:       
				game.set_listing_UI()

func remove_tenant():
	has_tenant = false
	tenant_offers = null
	lease_length = 0
	is_listed = false
	Collect_Rent.collect_rent()
	if Collect_Rent:
		Collect_Rent.reset_rent_state(true)
	_force_ui_refresh()

func add_tenant(income: int, lease_duration: int = 12):
	rent = income
	lease_length = lease_duration
	has_tenant = true
	_force_ui_refresh()
	
func house_buy(use_loan: bool, buy_price: int, loan_amount: int, loan_mod: Node = null) -> void:
	if use_loan and (not loan_mod or not is_instance_valid(loan_mod)):
		push_error("No valid loan_mod for house %s. Reverting to cash purchase." % name)
		use_loan = false
	owned = true
	$Label3D5.text = ""
	bought_price = buy_price
	has_loan = use_loan
	Globals.EXP += buy_price/100000 * Globals.exp_boost
	Globals.net_worth += buy_price
	Listing_ui.visible = false
	time_on_market = 0
	if use_loan:
		loan_price = float(loan_amount)
		mortgage = int(loan_mod.payment if loan_mod and is_instance_valid(loan_mod) else 0)
		Globals.credit_score -= randi_range(15,80)
		Globals.credit_score = clamp(Globals.credit_score, 300, 850)
	else:
		just_bought = true
		loan_price = 0
		mortgage = 0
	_force_ui_refresh()

func sell_house():
	Globals.money += current_price
	Globals.Propertys -= 1
	Globals.notify("house sold",Color.GREEN)
	remove_tenant()
	if has_loan:
		_handle_loan_payoff()
	owned = false
	loan_price = 0
	mortgage = 0
	has_loan = false
	var offer_system = get_tree().root.find_child("Rent_offer_system", true, false)
	if offer_system:
		offer_system.clear_offers_ui()
	_force_ui_refresh()

func _handle_loan_payoff():
	var loans_ui = get_tree().root.find_child("Loans", true, false)
	if loans_ui and "active_loan_mods" in loans_ui:
		for mod in loans_ui.active_loan_mods:
			if is_instance_valid(mod) and mod.get("house_ref") == self:
				mod._on_payoff_pressed()
				break
	else:
		loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
		if loans_ui and "active_loan_mods" in loans_ui:
			for mod in loans_ui.active_loan_mods:
				if is_instance_valid(mod) and mod.get("house_ref") == self:
					mod._on_payoff_pressed()
					break

func collect_rent():
	$Collect_Rent.collect_rent()

func _on_timer_timeout() -> void:
	if Collect_Rent != null:
		Collect_Rent.Month_timer()
	if loan_price > 0 and owned:
		loan_price -= mortgage
		loan_price = max(loan_price, 0)
		var loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
		if loans_ui and is_instance_valid(loans_ui):
			for mod in loans_ui.active_loan_mods:
				if mod.loan_type_str == "Mortgage" and mod.house_ref == self:
					mod.loan_balance = loan_price
					mod.update_ui()
					break
		if loan_price <= 0:
			loan_price = 0
			mortgage = 0
			has_loan = false
	_force_ui_refresh()
