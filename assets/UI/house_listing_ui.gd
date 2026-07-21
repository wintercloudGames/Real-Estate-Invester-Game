extends Control

@onready var light = $SubViewportContainer/SubViewport/ListingCam/SpotLight3D
@onready var time_on_market = $Time_on_market
@onready var price_display = $Label_price
@onready var loan_display = $Label_loan
@onready var game = $"../.."
@onready var SFX = $AudioStreamPlayer
# Interactive structural control elements
@onready var buy_button_1: Button = $Buy_button
@onready var buy_button_2: Button = $Buy_button2
@onready var loan_button: Button = $Loan_button
@onready var close_button: Button = $Close_button

var full_price: int = 0  # Tracks the house's full listing/current price
var list_price: int = 0 
var loan_amount: int = 0  # Amount financed if using a loan
var house = null
var loan_status: bool = false  # Whether the loan toggle is active
var down_payment: int = 0 
var bought_price: int = 0
var has_tenant: bool = false
var can_use_loan: bool = true
var down_payment_percent: float = 0.2
var pay_now_amount: int = 0  # Amount player pays now (down payment or full price)

func _ready() -> void:
	update_prices()
	_connect_layout_hover_sounds()

# Helper to automatically assign baseline pointer entry feedback across controls
func _connect_layout_hover_sounds() -> void:
	var interactive_nodes = [buy_button_1, buy_button_2, loan_button, close_button]
	for node in interactive_nodes:
		if is_instance_valid(node) and not node.mouse_entered.is_connected(_on_element_hovered):
			node.mouse_entered.connect(_on_element_hovered)

func _on_element_hovered() -> void:
	SFX.play_sound("hover")

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		light.visible = false
		return
	else:
		light.visible = true

	if event.is_action_pressed("buy"):
		handle_buy(false)
	
	if event.is_action_pressed("buyandrent"):
		if Globals.rent_houses:
			handle_buy(true)
	
	if event.is_action_pressed("loantoggle"):
		var new_status = !loan_status
		if is_instance_valid(loan_button):
			loan_button.button_pressed = new_status
		_on_loan_button_toggled(new_status)

func update_prices() -> void:
	if not house:
		full_price = 0
		list_price = 0
		down_payment = 0
		loan_amount = 0
		pay_now_amount = 0
		if is_instance_valid(loan_button):
			loan_button.tooltip_text = "No house selected"
		return
	
	list_price = house.current_price
	full_price = house.current_price
	can_use_loan = true
	
	if Globals.credit_score >= 750:
		down_payment_percent = 0.15
	elif Globals.credit_score >= 680:
		down_payment_percent = 0.2
	elif Globals.credit_score >= 620:
		down_payment_percent = 0.25
	else:
		down_payment_percent = 0.3
		if Globals.credit_score < 500:
			can_use_loan = false
	
	if can_use_loan and loan_status:
		down_payment = int(full_price * down_payment_percent)
		loan_amount = int(full_price * (1.0 - down_payment_percent))
		pay_now_amount = down_payment
	else:
		down_payment = full_price
		loan_amount = 0
		pay_now_amount = full_price
	
	if is_instance_valid(loan_button):
		loan_button.tooltip_text = "Credit score too low for a loan (below 500)" if not can_use_loan else "Toggle to finance with a loan"

func update_listing_box(house_node: Node):
	var texture_rect = $HouseBox/TextureRect
	house_node.set_preview_active(true)
	texture_rect.texture = house_node.get_preview_texture()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		light.visible = false
		return
	else:
		light.visible = true
	
	if is_instance_valid($Buy_button2):
		$Buy_button2.visible = Globals.rent_houses
	
	# Handles system interface window entry triggers cleanly via SFX global
	if visible and visible != get_meta("previous_visible", false):
		SFX.play_sound("click", 1.05) # Premium frame sliding pop tone
	set_meta("previous_visible", visible)
	
	if house:
		price_display.text = "Price: $" + add_comma_to_int(pay_now_amount)
		time_on_market.text = "Months on market: " + add_comma_to_int(house.time_on_market)
		$Label_list_price.text = "Listing: $" + add_comma_to_int(house.current_price)
		
		if can_use_loan and loan_status:
			var financed_pct = int((1.0 - down_payment_percent) * 100)
			var down_pay_str = add_comma_to_int(down_payment)
			loan_display.text = "Loan\n%d%% Financed\nDown Payment: $%s" % [financed_pct, down_pay_str]
		else:
			loan_display.text = "No Loan\nFull Payment: $%s" % add_comma_to_int(pay_now_amount)
	else:
		price_display.text = "Price: $0"
		time_on_market.text = "Months on market: 0"
		$Label_list_price.text = "Listing: $0"
		loan_display.text = "No House Selected"

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_loan_button_toggled(toggled_on: bool) -> void:
	if toggled_on and not can_use_loan:
		Globals.notify("Cannot use loan: Credit score below 500!", Color.RED)
		if is_instance_valid(loan_button):
			loan_button.button_pressed = false
		loan_status = false
		SFX.play_sound("error", 0.9) # Rejection buzz on score gate
	else:
		loan_status = toggled_on
		SFX.play_sound("click", 1.1 if toggled_on else 0.92) # Dynamic snap tones for toggle state
	update_prices()

func _on_close_button_pressed() -> void:
	visible = false
	game.clear_House_ui_data()
	if is_instance_valid(loan_button):
		loan_button.button_pressed = false
	SFX.play_sound("click", 0.85)

func handle_buy(list_for_rent: bool = false) -> void:
	if not is_instance_valid(house):
		Globals.notify("Invalid house!", Color.RED)
		SFX.play_sound("error")
		return
	
	if house.owned:
		Globals.notify("House already owned!", Color.RED)
		SFX.play_sound("error")
		return
	
	var loan_mod = null
	if loan_status and can_use_loan:
		# --- LOAN PURCHASE ---
		var calculated_loan_amount = full_price - pay_now_amount
		if Globals.money >= pay_now_amount:
			var interest_rate = 0.06
			if Globals.credit_score >= 750:
				interest_rate = 0.04
			elif Globals.credit_score >= 680:
				interest_rate = 0.045
			elif Globals.credit_score >= 620:
				interest_rate = 0.055
				
			var term_months = 12 * 30
			var monthly_payment = calculate_mortgage_payment(calculated_loan_amount, term_months, interest_rate)
			
			if monthly_payment <= 0:
				Globals.notify("Invalid loan terms!", Color.RED)
				SFX.play_sound("error")
				return
			
			Globals.money_out(pay_now_amount)
			
			house.owned = true
			house.owner_type = "player"
			if house.is_in_group("ai_owned"):
				house.remove_from_group("ai_owned")
			
			house.bought_price = full_price
			house.loan_price = float(calculated_loan_amount)
			house.mortgage = int(monthly_payment)
			house.has_loan = true
			house.just_bought = true
			
			var loans_ui = get_tree().get_first_node_in_group("loans_ui")
			if not loans_ui:
				loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
			
			if loans_ui and is_instance_valid(loans_ui):
				if loans_ui.loan_mod_Container:
					var loan_mod_path = "res://assets/UI/phone/Loans_controll_mod.tscn"
					if ResourceLoader.exists(loan_mod_path):
						loan_mod = loans_ui.add_mortgage_as_loan(monthly_payment, interest_rate, term_months, house)
						if loan_mod and is_instance_valid(loan_mod):
							loan_mod.loan_id = "mortgage_" + str(house.id)
							loan_mod.house_ref = house
							house.house_buy(true, full_price, calculated_loan_amount, loan_mod)
							Globals.recalculate_expenses()
						else:
							rollback_purchase()
							return
					else:
						rollback_purchase()
						return
				else:
					rollback_purchase()
					return
			else:
				rollback_purchase()
				return
			
			Globals.Propertys += 1
			Globals.net_worth += full_price
			Globals.notify("Bought with loan! Down: $" + add_comma_to_int(pay_now_amount), Color.GREEN)
			SFX.play_sound("success", 1.1) # Rewarding investment chime
		else:
			Globals.notify("Need $" + add_comma_to_int(pay_now_amount) + " for down payment!", Color.RED)
			SFX.play_sound("error")
			return
	else:
		# --- CASH PURCHASE ---
		if Globals.money >= pay_now_amount:
			Globals.money -= pay_now_amount
			
			house.owned = true
			house.owner_type = "player"
			if house.is_in_group("ai_owned"):
				house.remove_from_group("ai_owned")
				
			house.bought_price = full_price
			house.loan_price = 0
			house.mortgage = 0
			house.has_loan = false
			house.just_bought = true
			house.house_buy(false, full_price, 0, null)
			
			Globals.Propertys += 1
			Globals.net_worth += full_price
			Globals.notify("Bought with cash! $" + add_comma_to_int(pay_now_amount), Color.GREEN)
			SFX.play_sound("success", 1.25) # Premium high-pitch milestone chime for cash asset acquisition
		else:
			Globals.notify("Need $" + add_comma_to_int(pay_now_amount) + " in cash!", Color.RED)
			SFX.play_sound("error")
			return
	
	if house.has_method("set_house_UI"):
		house.set_house_UI()
	if list_for_rent:
		house.is_listed = true
	if is_instance_valid(loan_button):
		loan_button.button_pressed = false
	visible = false
	game.house = house
	game.set_house_UI()
	SaveAndLoad.save_game()

func rollback_purchase():
	Globals.money += pay_now_amount
	house.owned = false
	house.owner_type = "none"
	house.loan_price = 0
	house.mortgage = 0
	house.has_loan = false
	Globals.notify("Loan system error!", Color.RED)
	SFX.play_sound("error", 0.8)

func calculate_mortgage_payment(loan_amount: float, months: int, interest_rate: float) -> float:
	if months <= 0 or loan_amount <= 0 or interest_rate < 0:
		return 0.0
	var monthly_rate = interest_rate / 12.0
	var payment = loan_amount * (monthly_rate * pow(1 + monthly_rate, months)) / (pow(1 + monthly_rate, months) - 1)
	return payment

func _on_buy_button_pressed() -> void:
	handle_buy(false)

func _on_buy_button_2_pressed() -> void:
	handle_buy(true)
