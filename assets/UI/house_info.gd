extends Control

# --- UI ELEMENTS ---
@onready var price_display = $Label_list_price
@onready var label_bought_price: Label = $Label_bought_price
@onready var loan_display = $Label_loan
@onready var income_label = $Label_Income
@onready var mortgage_label = $Label_morgage
@onready var cashflow_label = $Label_cashflow
@onready var sell_amount_label = $Sell_home/Amount
@onready var lease_stat = $Label_lease_stat
@onready var aparmant_condition = $Label_condition
@onready var punctuality = $Label_punctuality
@onready var rent_slider: HSlider = $Rent_HSlider
@onready var rent_slider_info: LineEdit = $Rent_slider_info
@onready var upgrade_label = $Upgrade_label
@onready var upgrade_button = $Upgrade
@onready var edit_yard_button = $Edit_yard_button
@onready var game = $"../.." 
@onready var SFX = $AudioStreamPlayer

# Persistent interactive interface controls for structural audio hooking
@onready var tenent_button: Button = $Tenent_button
@onready var remove_tenent_button: Button = $Remove_Tenent
@onready var refinance_button: Button = $Refinance_button
@onready var sell_button: Button = $Sell_button
@onready var close_button: Button = $Close_button
@onready var yes_sell_button: Button = $Sell_home/Yes
@onready var no_sell_button: Button = $Sell_home/No
@onready var pay_off_button: Button = $Buy_button # Maps to your pay off node connection

# --- DATA ---
var house = null
var previous_visible := true

# --- INITIALIZATION ---
func _ready() -> void:
	rent_slider_info.modulate = Color.WHITE
	
	# Connect signals via code to ensure they exist
	rent_slider.value_changed.connect(_on_slider_value_changed)
	rent_slider_info.text_submitted.connect(_on_rent_input_submitted)
	rent_slider_info.focus_exited.connect(_on_rent_input_focus_exited)
	
	_connect_layout_hover_sounds()

# Automatically wire standard cursor pointer entries into layout modules
func _connect_layout_hover_sounds() -> void:
	var interactive_nodes = [
		tenent_button, remove_tenent_button, upgrade_button, edit_yard_button, 
		refinance_button, sell_button, close_button, yes_sell_button, no_sell_button, pay_off_button
	]
	for node in interactive_nodes:
		if is_instance_valid(node) and not node.mouse_entered.is_connected(_on_element_hovered):
			node.mouse_entered.connect(_on_element_hovered)

func _on_element_hovered() -> void:
	SFX.play_sound("hover")

func _process(_delta: float) -> void:
	if house:
		if house.for_sale == false:
			visible = false
	if visible != previous_visible:
		previous_visible = visible
		if visible:
			SFX.play_sound("click", 1.05) # Sliding panel view discovery alert
			setup_slider() 
	
	if house and visible:
		update_ui_elements()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if visible and house and not house.has_tenant and not house.is_listed:
			if not rent_slider_info.has_focus():
				_on_tenent_button_pressed()
				SFX.play_sound("click", 1.1)

# --- CORE UI UPDATER ---
func update_ui_elements() -> void:
	upgrade_label.text = str(house.upgrade_amount) + " / " + str(house.upgrade_max)
	edit_yard_button.visible = !house.is_building
	
	var can_upgrade = house.upgrade_amount < house.upgrade_max
	upgrade_button.visible = can_upgrade
	upgrade_label.visible = can_upgrade
	
	price_display.text = add_comma_to_int(int(house.current_price))
	label_bought_price.text = add_comma_to_int(int(house.bought_price))
	loan_display.text = add_comma_to_int(int(house.loan_price))
	mortgage_label.text = add_comma_to_int(int(house.mortgage))
	
	# Update buy/pay-off button context visibility based on active loan state
	if is_instance_valid(pay_off_button):
		pay_off_button.visible = house.has_loan and house.loan_price > 0
		pay_off_button.text = "Pay Off Mortgage"
		pay_off_button.tooltip_text = "Clear remaining loan balance of $" + add_comma_to_int(int(house.loan_price)) + " using cash."
	
	var current_income: int = int(house.rent) if house.has_tenant else 0
	var current_mortgage: int = int(house.mortgage)
	var current_cashflow: int = current_income - current_mortgage
	if house.has_loan:
		refinance_button.text = "Refinance"
		refinance_button.tooltip_text = "Get a lower interest rate on your current debt."
	else:
		refinance_button.text = "Get Mortgage"
		refinance_button.tooltip_text = "Take out a loan against your home's equity for cash."
	income_label.text = "Income: " + add_comma_to_int(current_income)
	cashflow_label.text = "CashFlow: " + add_comma_to_int(current_cashflow)
	
	update_tenant_buttons()
	aparmant_condition.text = "condition: %.0f%%" % (house.apartment_condition * 100)
	sell_amount_label.text = "Equity: " + add_comma_to_int(int(house.current_price - house.loan_price))

	if house.has_tenant:
		income_label.modulate = Color.GREEN
		cashflow_label.modulate = Color.LAWN_GREEN if current_cashflow >= 0 else Color.ORANGE_RED
		rent_slider_info.visible = false
		rent_slider.editable = false
		rent_slider_info.editable = false
		
		rent_slider.value = house.rent
		rent_slider_info.text = "Rent: " + add_comma_to_int(int(house.rent))
		
		rent_slider_info.add_theme_color_override("font_color", Color.GREEN)
		rent_slider_info.add_theme_color_override("font_readonly_color", Color.GREEN)
		
		lease_stat.text = "Lease: " + str(int(house.lease_length)) + " Months"
		punctuality.text = "punctuality: %.0f%%" % (house.payment_punctuality * 100)
	else:
		income_label.modulate = Color.WHITE
		cashflow_label.modulate = Color.RED if current_mortgage > 0 else Color.WHITE
		
		rent_slider_info.visible = true
		rent_slider.editable = true
		rent_slider_info.editable = true
		lease_stat.text = "Status: VACANT"
		punctuality.text = ""
		
		if not rent_slider_info.has_focus():
			update_rent_feedback(rent_slider.value)

# --- RENT SLIDER & INPUT LOGIC ---
func setup_slider():
	if not house: return
	
	rent_slider.min_value = 25
	rent_slider.step = 25
	var max_rent = snapped(house.current_price * 0.010, 25)
	rent_slider.max_value = max(max_rent, 1000) 
	
	if house.rent >= rent_slider.min_value:
		rent_slider.value = house.rent
	else:
		var target = house.mortgage * 1.1 if house.mortgage > 0 else (house.current_price * 0.007)
		var default_val = snapped(clamp(target, rent_slider.min_value, rent_slider.max_value), 25)
		rent_slider.value = default_val
		house.rent = default_val
	
	$Min_rent_label.text = add_comma_to_int(int(rent_slider.min_value))
	$max_rent_label.text = add_comma_to_int(int(rent_slider.max_value))
	update_rent_feedback(rent_slider.value)

func _on_slider_value_changed(value: float):
	if house and not house.has_tenant:
		house.rent = value
		update_rent_feedback(value)
		
		var dynamic_pitch = 1.0 + ((value / rent_slider.max_value) * 0.3)
		SFX.play_sound("hover", dynamic_pitch)

func update_rent_feedback(val: float):
	var fair_rent = house.current_price * 0.007
	var ratio = val / fair_rent
	var text_color = Color.WHITE
	
	if val < house.mortgage:
		text_color = Color.RED
	elif ratio > 1.3:
		text_color = Color.ORANGE
	elif ratio < 0.9:
		text_color = Color.LAWN_GREEN
	
	rent_slider_info.add_theme_color_override("font_color", text_color)
	rent_slider_info.add_theme_color_override("font_placeholder_color", text_color)
	
	if not rent_slider_info.has_focus():
		rent_slider_info.text = str(int(val))

func _on_rent_input_submitted(new_text: String):
	update_slider_from_text(new_text)
	rent_slider_info.release_focus()
	SFX.play_sound("click", 1.0)

func _on_rent_input_focus_exited():
	update_slider_from_text(rent_slider_info.text)

func update_slider_from_text(text: String):
	var clean_text = text.replace(",", "").replace("Rent: ", "")
	if clean_text.is_valid_float():
		var new_val = clamp(clean_text.to_float(), rent_slider.min_value, rent_slider.max_value)
		rent_slider.value = new_val 
		if house: house.rent = new_val
	else:
		rent_slider_info.text = str(int(rent_slider.value))

# --- BUTTONS ---
func _on_tenent_button_pressed() -> void:
	if house and Globals.rent_houses:
		house.is_listed = true
		update_tenant_buttons()
		SFX.play_sound("success", 1.1)
	else:
		Globals.notify("Need Renting skill to rent houses", Color.RED)
		SFX.play_sound("error")

func _on_remove_tenent_pressed() -> void:
	if house:
		house.remove_tenant()
		Globals.notify("Removed Tenant", Color.CORNFLOWER_BLUE)
		setup_slider()
		SFX.play_sound("click", 0.9)

func _on_upgrade_pressed() -> void:
	var upgrade_cost = 10000
	var upgrade_value = 15000
	if Globals.money >= upgrade_cost and house.upgrade_amount < house.upgrade_max:
		Globals.money -= upgrade_cost
		house.upgrade_amount += 1
		house.current_price += upgrade_value
		setup_slider()
		SFX.play_sound("success", 1.2) 
	else:
		SFX.play_sound("error")

func _on_sell_button_pressed() -> void:
	$Sell_home.visible = true
	SFX.play_sound("click", 0.95)

func _on_yes_sell_pressed() -> void:
	if house:
		house.sell_house()
		visible = false
		$Sell_home.visible = false
		SFX.play_sound("success", 1.3) 

func _on_no_sell_pressed() -> void:
	$Sell_home.visible = false
	SFX.play_sound("click", 0.9)

func _on_close_button_pressed() -> void:
	visible = false
	SFX.play_sound("click", 0.85)

func _on_edit_yard_button_pressed() -> void:
	if house:
		game._on_edit_yard_button_pressed(house)
		visible = false
		if has_node("../Phone"): get_node("../Phone").put_away()
		SFX.play_sound("click", 1.02)

# --- UTILITIES ---
func update_tenant_buttons():
	if not house: return
	$Remove_Tenent.visible = house.has_tenant
	$Tenent_button.visible = !house.has_tenant and !house.is_listed
	$Label_islistedforrent.visible = !house.has_tenant and house.is_listed

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(abs(value))
	for i in range(str_value.length() - 3, 0, -3):
		str_value = str_value.insert(i, ",")
	if value < 0: str_value = "-" + str_value
	return str_value

func calculate_mortgage_payment(loan_amount: float, months: int, interest_rate: float) -> float:
	if months <= 0 or loan_amount <= 0 or interest_rate < 0:
		return 0.0
	var monthly_rate = interest_rate / 12.0
	var payment = loan_amount * (monthly_rate * pow(1 + monthly_rate, months)) / (pow(1 + monthly_rate, months) - 1)
	return payment

func _on_refinance_button_pressed() -> void:
	if not is_instance_valid(house):
		SFX.play_sound("error")
		return

	var loans_ui = get_tree().get_first_node_in_group("loans_ui")
	var term_months = 360
	var interest_rate = 0.06
	
	if Globals.credit_score >= 750: interest_rate = 0.04
	elif Globals.credit_score >= 680: interest_rate = 0.045
	elif Globals.credit_score >= 620: interest_rate = 0.055

	if house.has_loan:
		# --- MODE A: CASH-OUT REFINANCE ---
		var old_balance = house.loan_price
		var new_loan_amount = int(house.current_price * 0.80)
		
		if new_loan_amount <= old_balance:
			Globals.notify("No equity available to cash out!", Color.ORANGE)
			SFX.play_sound("error")
			return
			
		var cash_difference = new_loan_amount - old_balance
		var closing_costs = int(new_loan_amount * 0.02)
		
		if Globals.money < closing_costs:
			Globals.notify("Need $" + add_comma_to_int(closing_costs) + " for fees!", Color.RED)
			SFX.play_sound("error")
			return

		Globals.money_out(closing_costs)
		Globals.money += cash_difference
		
		if loans_ui and is_instance_valid(loans_ui):
			loans_ui.remove_loan_by_id("mortgage_" + str(house.id))
		
		var new_payment = calculate_mortgage_payment(new_loan_amount, term_months, interest_rate)
		
		house.loan_price = float(new_loan_amount)
		house.mortgage = int(new_payment)

		if loans_ui and is_instance_valid(loans_ui):
			var loan_mod = loans_ui.add_mortgage_as_loan(new_payment, interest_rate, term_months, house)
			if loan_mod:
				loan_mod.loan_id = "mortgage_" + str(house.id)
				house.loan_module = loan_mod
		
		Globals.notify("Refinanced! Pocketed: $" + add_comma_to_int(cash_difference), Color.GREEN)
		SFX.play_sound("success", 1.1)

	else:
		# --- MODE B: NEW MORTGAGE ---
		var loan_amount = int(house.current_price * 0.80)
		var monthly_payment = calculate_mortgage_payment(loan_amount, term_months, interest_rate)
		
		Globals.money += loan_amount
		
		house.has_loan = true
		house.loan_price = float(loan_amount)
		house.mortgage = int(monthly_payment)
		
		if loans_ui and is_instance_valid(loans_ui):
			var loan_mod = loans_ui.add_mortgage_as_loan(monthly_payment, interest_rate, term_months, house)
			if loan_mod:
				loan_mod.loan_id = "mortgage_" + str(house.id)
				house.loan_module = loan_mod
		
		Globals.notify("Mortgage Taken: +$" + add_comma_to_int(loan_amount), Color.GREEN)
		SFX.play_sound("success", 1.25)

	Globals.recalculate_expenses()
	update_ui_elements()
	SaveAndLoad.save_game()

# --- MORTGAGE PAY-OFF LOGIC ---
func _on_buy_button_pressed() -> void:
	if not is_instance_valid(house):
		SFX.play_sound("error")
		return
		
	if not house.has_loan or house.loan_price <= 0:
		Globals.notify("This asset has no outstanding mortgage liability!", Color.ORANGE)
		SFX.play_sound("error")
		return
		
	var payoff_amount = int(house.loan_price)
	
	# Validate player cash balance against outstanding debt balance
	if Globals.money >= payoff_amount:
		Globals.money -= payoff_amount
		
		# Clear liabilities on target house instance
		house.has_loan = false
		house.loan_price = 0.0
		house.mortgage = 0
		
		# Disconnect mortgage item from active phone tracking system cleanly
		var loans_ui = get_tree().get_first_node_in_group("loans_ui")
		if not loans_ui:
			loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
			
		if loans_ui and is_instance_valid(loans_ui):
			loans_ui.remove_loan_by_id("mortgage_" + str(house.id))
			
		# Explicitly wipe internal node back-references if they exist on the object
		if "loan_module" in house:
			house.loan_module = null
			
		# Refresh the player's overarching expense balances
		Globals.recalculate_expenses()
		update_ui_elements()
		SaveAndLoad.save_game()
		
		Globals.notify("Mortgage Paid Off Fully! -$" + add_comma_to_int(payoff_amount), Color.GREEN)
		SFX.play_sound("success", 1.25) # Play milestone sound
	else:
		var missing_funds = payoff_amount - Globals.money
		Globals.notify("Insufficient Cash! Need $" + add_comma_to_int(missing_funds) + " more.", Color.RED)
		SFX.play_sound("error", 0.95)
