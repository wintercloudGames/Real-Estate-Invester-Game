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

func _process(_delta: float) -> void:
	if visible != previous_visible:
		previous_visible = visible
		if visible:
			var popup_sound = get_node_or_null("../popupsound")
			if popup_sound: popup_sound.play()
			setup_slider() 
	
	if house and visible:
		update_ui_elements()
func _unhandled_input(event: InputEvent) -> void:
	# 1. Check if the Spacebar was just pressed
	if event.is_action_pressed("ui_accept"):
		# You can also use: if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		
		# 2. Safety Checks: UI must be visible, house must exist, and house must NOT have a tenant or be listed
		if visible and house and not house.has_tenant and not house.is_listed:
			
			# 3. Check if the user is currently typing in the rent box (don't list while editing text)
			if not rent_slider_info.has_focus():
				_on_tenent_button_pressed()
				# Optional: play a sound to confirm the shortcut worked
				var popup_sound = get_node_or_null("../popupsound")
				if popup_sound: popup_sound.play()
# --- CORE UI UPDATER ---
func update_ui_elements() -> void:
	# Basic Stats
	upgrade_label.text = str(house.upgrade_amount) + " / " + str(house.upgrade_max)
	edit_yard_button.visible = !house.is_building
	
	var can_upgrade = house.upgrade_amount < house.upgrade_max
	upgrade_button.visible = can_upgrade
	upgrade_label.visible = can_upgrade
	
	price_display.text = add_comma_to_int(int(house.current_price))
	label_bought_price.text = add_comma_to_int(int(house.bought_price))
	loan_display.text = add_comma_to_int(int(house.loan_price))
	mortgage_label.text = add_comma_to_int(int(house.mortgage))
	
	var current_income: int = int(house.rent) if house.has_tenant else 0
	var current_mortgage: int = int(house.mortgage)
	var current_cashflow: int = current_income - current_mortgage
	if house.has_loan:
		$Refinance_button.text = "Refinance"
		$Refinance_button.tooltip_text = "Get a lower interest rate on your current debt."
	else:
		$Refinance_button.text = "Get Mortgage"
		$Refinance_button.tooltip_text = "Take out a loan against your home's equity for cash."
	income_label.text = "Income: " + add_comma_to_int(current_income)
	cashflow_label.text = "CashFlow: " + add_comma_to_int(current_cashflow)
	
	update_tenant_buttons()
	aparmant_condition.text = "condition: %.0f%%" % (house.apartment_condition * 100)
	sell_amount_label.text = "Equity: " + add_comma_to_int(int(house.current_price - house.loan_price))

	if house.has_tenant:
		# --- LOCKED STATE (LEASE ACTIVE) ---
		income_label.modulate = Color.GREEN
		cashflow_label.modulate = Color.LAWN_GREEN if current_cashflow >= 0 else Color.ORANGE_RED
		rent_slider_info.visible = false
		rent_slider.editable = false
		rent_slider_info.editable = false
		
		# Force slider and text to match the house's fixed lease rent
		rent_slider.value = house.rent
		rent_slider_info.text = "Rent: " + add_comma_to_int(int(house.rent))
		
		rent_slider_info.add_theme_color_override("font_color", Color.GREEN)
		rent_slider_info.add_theme_color_override("font_readonly_color", Color.GREEN)
		
		lease_stat.text = "Lease: " + str(int(house.lease_length)) + " Months"
		punctuality.text = "punctuality: %.0f%%" % (house.payment_punctuality * 100)
	else:
		# --- OPEN STATE (VACANT) ---
		income_label.modulate = Color.WHITE
		cashflow_label.modulate = Color.RED if current_mortgage > 0 else Color.WHITE
		
		rent_slider_info.visible = true
		rent_slider.editable = true
		rent_slider_info.editable = true
		lease_stat.text = "Status: VACANT"
		punctuality.text = ""
		
		# CRITICAL: Only update the text if the player ISN'T typing right now
		if not rent_slider_info.has_focus():
			update_rent_feedback(rent_slider.value)

# --- RENT SLIDER & INPUT LOGIC ---
func setup_slider():
	if not house: return
	
	# 1. Set the technical bounds
	rent_slider.min_value = 25
	rent_slider.step = 25
	var max_rent = snapped(house.current_price * 0.010, 25)
	rent_slider.max_value = max(max_rent, 1000) 
	
	# 2. Handle the value (The Persistence Logic)
	# Check if the house already has a rent value assigned (greater than min_value)
	if house.rent >= rent_slider.min_value:
		rent_slider.value = house.rent
	else:
		# ONLY calculate a default if the house has no rent set yet
		var target = house.mortgage * 1.1 if house.mortgage > 0 else (house.current_price * 0.007)
		var default_val = snapped(clamp(target, rent_slider.min_value, rent_slider.max_value), 25)
		rent_slider.value = default_val
		house.rent = default_val # Save this default so it persists next time
	
	# 3. Update Visuals
	$Min_rent_label.text = add_comma_to_int(int(rent_slider.min_value))
	$max_rent_label.text = add_comma_to_int(int(rent_slider.max_value))
	update_rent_feedback(rent_slider.value)

func _on_slider_value_changed(value: float):
	if house and not house.has_tenant:
		house.rent = value # Save directly to house object
		update_rent_feedback(value)

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
	
	# Only change the text if the user isn't currently editing it
	if not rent_slider_info.has_focus():
		rent_slider_info.text = str(int(val))

func _on_rent_input_submitted(new_text: String):
	update_slider_from_text(new_text)
	rent_slider_info.release_focus()

func _on_rent_input_focus_exited():
	update_slider_from_text(rent_slider_info.text)

func update_slider_from_text(text: String):
	# Clean formatting characters if they exist
	var clean_text = text.replace(",", "").replace("Rent: ", "")
	if clean_text.is_valid_float():
		var new_val = clamp(clean_text.to_float(), rent_slider.min_value, rent_slider.max_value)
		rent_slider.value = new_val 
		if house: house.rent = new_val # Persistence check
	else:
		rent_slider_info.text = str(int(rent_slider.value))

# --- BUTTONS ---
func _on_tenent_button_pressed() -> void:
	if house and Globals.rent_houses:
		house.is_listed = true
		update_tenant_buttons()
	else:
		Globals.notify("Need Renting skill to rent houses", Color.RED)

func _on_remove_tenent_pressed() -> void:
	if house:
		house.remove_tenant()
		Globals.notify("Removed Tenant", Color.CORNFLOWER_BLUE)
		setup_slider() # Refresh slider limits/state

func _on_upgrade_pressed() -> void:
	var upgrade_cost = 10000
	var upgrade_value = 15000
	if Globals.money >= upgrade_cost and house.upgrade_amount < house.upgrade_max:
		Globals.money -= upgrade_cost
		house.upgrade_amount += 1
		house.current_price += upgrade_value
		setup_slider() # Upgrades change house value, so we refresh slider max

func _on_sell_button_pressed() -> void:
	$Sell_home.visible = true

func _on_yes_sell_pressed() -> void:
	if house:
		house.sell_house()
		visible = false
		$Sell_home.visible = false

func _on_no_sell_pressed() -> void:
	$Sell_home.visible = false

func _on_close_button_pressed() -> void:
	visible = false

func _on_edit_yard_button_pressed() -> void:
	if house:
		game._on_edit_yard_button_pressed(house)
		visible = false
		if has_node("../Phone"): get_node("../Phone").put_away()

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
		return

	# --- 1. SETUP & UNIFIED RATE LOGIC ---
	var loans_ui = get_tree().get_first_node_in_group("loans_ui")
	var term_months = 360
	var interest_rate = 0.06 # Default
	
	if Globals.credit_score >= 750: interest_rate = 0.04
	elif Globals.credit_score >= 680: interest_rate = 0.045
	elif Globals.credit_score >= 620: interest_rate = 0.055

	if house.has_loan:
		# --- MODE A: CASH-OUT REFINANCE ---
		var old_balance = house.loan_price
		# Max loan is 80% of what the house is worth NOW
		var new_loan_amount = int(house.current_price * 0.80)
		
		# Check if there is actually cash to take out
		if new_loan_amount <= old_balance:
			Globals.notify("No equity available to cash out!", Color.ORANGE)
			return
			
		var cash_difference = new_loan_amount - old_balance
		var closing_costs = int(new_loan_amount * 0.02)
		
		if Globals.money < closing_costs:
			Globals.notify("Need $" + add_comma_to_int(closing_costs) + " for fees!", Color.RED)
			return

		# Process Transaction
		Globals.money_out(closing_costs)
		Globals.money += cash_difference # This gives you the cash!
		
		# Update UI: Remove the old loan module
		if loans_ui and is_instance_valid(loans_ui):
			loans_ui.remove_loan_by_id("mortgage_" + str(house.id))
		
		var new_payment = calculate_mortgage_payment(new_loan_amount, term_months, interest_rate)
		
		# Update House Data
		house.loan_price = float(new_loan_amount)
		house.mortgage = int(new_payment)

		# Add the new, larger loan back to the UI
		if loans_ui and is_instance_valid(loans_ui):
			var loan_mod = loans_ui.add_mortgage_as_loan(new_payment, interest_rate, term_months, house)
			if loan_mod:
				loan_mod.loan_id = "mortgage_" + str(house.id)
				# Now this assignment will work because 'loan_module' exists in the house script
				house.loan_module = loan_mod
		
		Globals.notify("Refinanced! Pocketed: $" + add_comma_to_int(cash_difference), Color.GREEN)

	else:
		# --- MODE B: NEW MORTGAGE (Initial Equity Pull) ---
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

	# Common Cleanup
	Globals.recalculate_expenses()
	update_ui_elements()
	SaveAndLoad.save_game()
