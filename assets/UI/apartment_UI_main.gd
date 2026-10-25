extends Control

@onready var cashflow_label = $Label_cashflow
@onready var label_total_rent = $Label_total_rent
@onready var units_scroll_container = $ScrollContainer/GridContainer 
@onready var game = get_node("/root/Root/UserInterface/Game")

# Financial Summary Labels
@onready var label_bought_price: Label = $Label_bought_price
@onready var label_loan: Label = $Label_loan
@onready var label_morgage: Label = $Label_morgage
@onready var refinance_button: Button = $Refinance_button

# Sell Confirmation Panel Nodes
@onready var sell_home_panel: Control = $Sell_home
@onready var sell_amount_label: Label = $Sell_home/Amount
@onready var sell_yes_button: Button = $Sell_home/Yes
@onready var sell_no_button: Button = $Sell_home/No

const RENTAL_MOD_SCENE = preload("res://assets/UI/phone/rental_controll_mod.tscn") 

var house = null

func _ready() -> void:
	if has_node("Close_Button"): $Close_Button.pressed.connect(_on_close_button_pressed)
	if has_node("List_for_rent"): $List_for_rent.pressed.connect(_on_list_all_pressed)
	if has_node("collect_rent"): $collect_rent.pressed.connect(_on_collect_all_rent_pressed)
	if has_node("Sell"): $Sell.pressed.connect(_on_sell_button_pressed)
	if has_node("Refinance_button"): $Refinance_button.pressed.connect(_on_refinance_button_pressed)
	
	# Connect Sell Home panel buttons
	if sell_yes_button and not sell_yes_button.pressed.is_connected(_on_sell_confirmed):
		sell_yes_button.pressed.connect(_on_sell_confirmed)
	if sell_no_button and not sell_no_button.pressed.is_connected(_on_sell_cancelled):
		sell_no_button.pressed.connect(_on_sell_cancelled)
		
	if sell_home_panel:
		sell_home_panel.visible = false
	
	if not Globals.month_ended.is_connected(_on_month_ended):
		Globals.month_ended.connect(_on_month_ended)

func _process(_delta: float) -> void:
	if house and visible:
		update_financial_summary()

func setup_apartment_ui() -> void:
	if not house or not ("is_apartment" in house and house.is_apartment): return
	if sell_home_panel: sell_home_panel.visible = false
	update_financial_summary()
	_populate_unit_list()

func _on_month_ended() -> void:
	if visible and house and house.is_apartment:
		setup_apartment_ui()

func update_financial_summary() -> void:
	if not house: return
	
	var total_income = house.get_total_apartment_income()
	var mortgage_amt = int(house.mortgage)
	var cashflow = total_income - mortgage_amt
	
	if label_total_rent:
		label_total_rent.text = "Total Rent: $" + add_comma_to_int(total_income)
	
	if cashflow_label:
		cashflow_label.text = "Building Cash Flow: $" + add_comma_to_int(cashflow)
		cashflow_label.modulate = Color.GREEN if cashflow >= 0 else Color.RED
		
	if label_bought_price:
		label_bought_price.text = "$" + add_comma_to_int(int(house.bought_price)) if house.bought_price > 0 else "$" + add_comma_to_int(int(house.current_price))
		
	if label_loan:
		label_loan.text = "$" + add_comma_to_int(int(house.loan_price))
		
	if label_morgage:
		label_morgage.text = "$" + add_comma_to_int(int(house.mortgage))
		
	if refinance_button:
		refinance_button.text = "Refinance" if house.has_loan else "Get Mortgage"

func _populate_unit_list() -> void:
	if not units_scroll_container: return
	
	for child in units_scroll_container.get_children():
		child.queue_free()
		
	for unit in house.units:
		var mod_instance = RENTAL_MOD_SCENE.instantiate()
		mod_instance.apartment_building = house
		mod_instance.unit_data = unit
		units_scroll_container.add_child(mod_instance)

func _on_list_all_pressed() -> void:
	if not house: return
	for unit in house.units:
		if not unit["has_tenant"]:
			unit["is_listed"] = true
	setup_apartment_ui()
	Globals.notify("All vacant apartment units listed for rent!", Color.LAWN_GREEN)

func _on_collect_all_rent_pressed() -> void:
	if not house: return
	var collected = 0
	for unit in house.units:
		if unit["has_tenant"] and not unit.get("paid_rent", false):
			collected += int(unit["rent"])
			unit["paid_rent"] = true
			
	if collected > 0:
		Globals.money += collected
		Globals.notify("Collected $" + add_comma_to_int(collected) + " in apartment rent!", Color.GREEN)
		setup_apartment_ui()
	else:
		Globals.notify("No unpaid rent available to collect.", Color.YELLOW)

func _on_sell_button_pressed() -> void:
	if not house: return
	
	# Calculate exact liquidity: Property Value minus remaining loan balance (prevents infinite money glitch)
	var sale_price = int(house.current_price)
	var loan_balance = int(house.loan_price)
	var net_liquidity = max(0, sale_price - loan_balance)
	
	if sell_amount_label:
		sell_amount_label.text = "Sell Payout: $" + add_comma_to_int(net_liquidity) + "\n(After Loan Payoff)"
		
	if sell_home_panel:
		sell_home_panel.visible = true

func _on_sell_confirmed() -> void:
	if house:
		house.sell_house()
		if sell_home_panel: sell_home_panel.visible = false
		visible = false
		Globals.notify("Apartment building sold successfully!", Color.GREEN)

func _on_sell_cancelled() -> void:
	if sell_home_panel:
		sell_home_panel.visible = false

func _on_refinance_button_pressed() -> void:
	if not house: return
	if house.has_loan:
		Globals.notify("Apartment already has an active mortgage of $" + add_comma_to_int(int(house.loan_price)), Color.YELLOW)
		return
		
	var loan_amount = int(house.current_price * 0.8)
	var interest_rate = 0.05
	if Globals.credit_score >= 750: interest_rate = 0.04
	elif Globals.credit_score >= 680: interest_rate = 0.045
	elif Globals.credit_score >= 620: interest_rate = 0.055
	
	var term_months = 360
	var monthly_payment = calculate_mortgage_payment(loan_amount, term_months, interest_rate)
	
	house.has_loan = true
	house.loan_price = float(loan_amount)
	house.mortgage = int(monthly_payment)
	
	Globals.money += loan_amount
	Globals.net_worth -= loan_amount
	
	Globals.notify("Successfully mortgaged apartment for $" + add_comma_to_int(loan_amount) + "!", Color.GREEN)
	update_financial_summary()
	SaveAndLoad.save_game()

func calculate_mortgage_payment(loan_amount: float, months: int, interest_rate: float) -> float:
	if months <= 0 or loan_amount <= 0 or interest_rate < 0: return 0.0
	var monthly_rate := interest_rate / 12.0
	if monthly_rate == 0: return loan_amount / months
	var power_term := pow(1 + monthly_rate, months)
	var payment := loan_amount * (monthly_rate * power_term) / (power_term - 1)
	return round(payment * 100.0) / 100.0

func _on_close_button_pressed() -> void:
	if sell_home_panel and sell_home_panel.visible:
		sell_home_panel.visible = false
		return
	visible = false

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(abs(value))
	for i in range(str_value.length() - 3, 0, -3):
		str_value = str_value.insert(i, ",")
	if value < 0: str_value = "-" + str_value
	return str_value
