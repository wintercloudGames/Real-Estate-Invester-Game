extends Control

@onready var price_display = $Label_list_price
@onready var label_bought_price: Label = $Label_bought_price
@onready var loan_display = $Label_loan
@onready var income_label = $Label_Income
@onready var mortgage_label = $Label_morgage
@onready var cashflow_label = $Label_cashflow
@onready var sell_amount_label = $Sell_home/Amount
@onready var lease_stat = $Label_lease_stat
@onready var aparmant_condition = $Label_condition
@onready var game = $"../.."
@onready var punctuality = $Label_punctuality
@onready var rent_slider: HSlider = $Rent_HSlider
@onready var rent_slider_info: Label = $Rent_slider_info

var price = 0
var mortgage = 0
var list_price = price
var loan_price = 0
var income = 0
var house = null
var loan_status = false
var has_tenant = false

var cash_out: float = 0

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

var previous_visible := true
func _process(delta: float) -> void:
	if visible != previous_visible:
		previous_visible = visible
		if visible:
			$"../popupsound".play()
			setup_slider() 
	if house:
		$Upgrade_label.text = str(house.upgrade_amount) + " / " + str(house.upgrade_max)
		update_tenant_buttons()
		$Edit_yard_button.visible = !house.is_building
		if house.upgrade_amount >= house.upgrade_max:
			$Upgrade.visible = false
			$Upgrade_label.visible = false
		else:
			$Upgrade.visible = true
			$Upgrade_label.visible = true
		# --- CORE HOUSE DATA ---
		price_display.text = "House Worth: " + add_comma_to_int(int(house.current_price))
		label_bought_price.text = "Original Price: " + add_comma_to_int(int(house.bought_price))
		loan_display.text = "Loan: " + add_comma_to_int(int(house.loan_price))
		mortgage_label.text = "Mortgage: " + add_comma_to_int(int(house.mortgage))
		
		# --- RENTER NUMBERS (Actual Ledger) ---
		var current_income: int = int(house.rent) if house.has_tenant else 0
		var current_mortgage: int = int(house.mortgage)
		var current_cashflow: int = current_income - current_mortgage
		
		income_label.text = "Income: " + add_comma_to_int(current_income)
		cashflow_label.text = "CashFlow: " + add_comma_to_int(current_cashflow)
		
		# --- STRATEGIC LOSS VISUALS ---
		if house.has_tenant:
			income_label.modulate = Color.GREEN
			if current_cashflow < 0:
				# Use a "Warning Gold" or "Investment Blue" instead of just Red 
				# to show this might be a choice.
				cashflow_label.modulate = Color.ORANGE_RED 
			else:
				cashflow_label.modulate = Color.LAWN_GREEN
		else:
			income_label.modulate = Color.WHITE
			cashflow_label.modulate = Color.RED if current_mortgage > 0 else Color.WHITE

		# --- LEASE & PLANNING LOGIC ---
		if house.has_tenant:
			rent_slider.editable = false
			rent_slider_info.text = "Lease Active\nRent: " + add_comma_to_int(int(house.rent))
			rent_slider_info.modulate = Color.GREEN
			
			# Lease length is a clean Int
			lease_stat.text = "Lease: " + str(int(house.lease_length)) + " Months"
			punctuality.text = "%.0f%% punctuality" % (house.payment_punctuality * 100)
		else:
			rent_slider.editable = true
			lease_stat.text = "Status: VACANT"
			punctuality.text = ""
			
			# Show sentiment and ASKING amount on a new line
			update_rent_slider_feedback(int(rent_slider.value))

		# --- CONDITION & EQUITY ---
		aparmant_condition.text = "%.0f%% condition" % (house.apartment_condition * 100)
		var equity: int = int(house.current_price - house.loan_price)
		sell_amount_label.text = "Equity: " + add_comma_to_int(equity)

# Helper for the 'Strategic Pricing' feedback
func update_rent_slider_feedback(asking_val: int):
	var fair_rent = house.current_price * 0.007
	var ratio = asking_val / fair_rent
	var sentiment = ""
	
	if asking_val < house.mortgage:
		# Encourage the player!
		sentiment = "Supper competitive"
		rent_slider_info.modulate = Color.CYAN # Cool blue for "Strategic"
	elif ratio > 1.3:
		sentiment = "High Risk: Property Damage Likely"
		rent_slider_info.modulate = Color.ORANGE
	elif ratio < 0.9:
		sentiment = "Premium Tenant Search"
		rent_slider_info.modulate = Color.LAWN_GREEN
	else:
		sentiment = "Market: Fair Price"
		rent_slider_info.modulate = Color.WHITE
		
	rent_slider_info.text = sentiment + "\nAsking: $" + add_comma_to_int(int(asking_val))
	
# Inside House_info script
func _on_rent_h_slider_value_changed(value: float) -> void:
	if house:
		# 1. Update the specific house data
		house.rent = int(value)
		
		# 2. Update the UI labels immediately so it feels responsive
		# This calls the helper function we made earlier
		update_rent_slider_feedback(int(value))
		

func setup_slider():
	if house:
		# 1. Configure the visual limits
		rent_slider.step = 25
		rent_slider.min_value = 25
		# Ensure max_value is at least something so the slider isn't broken
		var max_rent = snapped(house.current_price * 0.02, 25)
		rent_slider.max_value = max(max_rent, 500) 
		
		# 2. PULL DATA CAREFULLY
		if house.rent > 0:
			# This house has a value from the save file or a previous session.
			# KEEP IT. Do not overwrite it.
			rent_slider.value = house.rent
		elif not house.has_tenant and house.owned:
			# ONLY set a default if it's truly empty AND has no saved rent value.
			# We check house.mortgage; if it's 0, we use a fallback fair market price.
			var base_target = house.mortgage if house.mortgage > 0 else (house.current_price * 0.007)
			var safe_start = snapped(base_target * 1.1, 25)
			
			rent_slider.value = safe_start
			house.rent = safe_start

func update_rent_info_label():
	if not house: return
	
	# Calculate Fair Rent (e.g., 0.7% of value)
	var fair_rent = house.current_price * 0.007
	var ratio = house.rent / fair_rent
	var cashflow = house.rent - house.mortgage
	
	# Update the display label
	rent_slider_info.text = "Target Rent: $" + add_comma_to_int(house.rent)
	
	# Color coding and Market Sentiment
	if house.rent < house.mortgage:
		rent_slider_info.text += " (Losing Money!)"
		rent_slider_info.modulate = Color.RED
	elif ratio > 1.3:
		rent_slider_info.text += " (Hard to Rent)"
		rent_slider_info.modulate = Color.ORANGE
	elif ratio < 0.8:
		rent_slider_info.text += " (High Demand)"
		rent_slider_info.modulate = Color.GREEN
	else:
		rent_slider_info.text += " (Fair Price)"
		rent_slider_info.modulate = Color.WHITE

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return 

	if event.is_action_pressed("buyandrent"):
		_on_tenent_button_pressed()

func _on_remove_tenent_pressed() -> void:
	house.remove_tenant()
	Globals.notify("Removed Tenant",Color.CORNFLOWER_BLUE)

func update_tenant_buttons():

	if house:
		if house.has_tenant:
			$Remove_Tenent.visible = true
			$Tenent_button.visible = false
			$Label_islistedforrent.visible = false
		elif house.is_listed:
			$Remove_Tenent.visible = false
			$Tenent_button.visible = false
			$Label_islistedforrent.visible = true
		else:
			# Show the button even if they don't have the skill
			# This allows them to click it and see your error message
			$Remove_Tenent.visible = false
			$Tenent_button.visible = true
			$Label_islistedforrent.visible = false

func _on_tenent_button_pressed() -> void:
	if house and Globals.rent_houses:
		house.is_listed = true
		update_tenant_buttons()
	else:
		Globals.notify("Need Renting skill to rent houses",Color.RED)

func _on_close_button_pressed() -> void:
	visible = false

func _on_buy_button_pressed() -> void:
	$Pay_off.visible = true
	$Pay_off/Amount.text = add_comma_to_int(house.loan_price)

func _on_yes_pressed() -> void:
	if Globals.money >= house.loan_price:
		Globals.money -= house.loan_price
		house.mortgage = 0
		house.loan_price = 0
		loan_price = 0
		$Pay_off.visible = false
		$Buy_button.visible = false
		

func _on_no_pressed() -> void:
	$Pay_off.visible = false

func _on_edit_yard_button_pressed() -> void:
	if house:
		game._on_edit_yard_button_pressed(house)
		visible = false
		$"../Phone".put_away()

func _on_sell_button_pressed() -> void:
	$Sell_home.visible = true

func _on_yes_sell_pressed() -> void:
	if house:
		house.sell_house()
		visible = false
	if has_node("Sell_home"):
		$Sell_home.visible = false
		return
		Globals.money += house.current_price
		Globals.Propertys -= 1
		house.remove_tenant()

		$"../../Rent_offer_system".clear_offers_ui()
		if house.has_loan:
			var loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
			if loans_ui and is_instance_valid(loans_ui):
				for mod in loans_ui.active_loan_mods:
					if mod.house_ref == house:
						mod._on_payoff_pressed()  # Pays off balance, removes mod, updates credit/EXP
						break
			else:
				push_warning("No loans_ui found during house sell for " + house.id)
		
		house.owned = false
		house.loan_price = 0
		house.mortgage = 0
		house.has_loan = false
		
		visible = false
		$Sell_home.visible = false

func _on_no_sell_pressed() -> void:
	$Sell_home.visible = false

func _on_upgrade_pressed() -> void:
	var upgrade_cost = 10000
	var upgrade_value = 15000

	if Globals.money >= upgrade_cost and  house.upgrade_amount < house.upgrade_max:
		Globals.money -= upgrade_cost
		house.upgrade_amount += 1
		house.current_price += upgrade_value
	

func _on_refinance_button_pressed() -> void:
	# 1. Basic Validations
	if not is_instance_valid(house):
		Globals.notify("Invalid house!", Color.RED)
		return
	
	if not house.owned:
		Globals.notify("House not owned!", Color.RED)
		return
	
	if Globals.credit_score < 500:
		Globals.notify("Credit score too low (min 500)!", Color.RED)
		return

	# 2. Calculate New Loan and Cash Out
	# We use the current market price as the new total loan amount
	var new_loan_total: float = house.current_price
	var current_debt: float = house.loan_price
	var calculated_cash_out: float = new_loan_total - current_debt
	
	if calculated_cash_out <= 0:
		Globals.notify("No equity available to cash out!", Color.YELLOW)
		return

	# 3. Determine Interest Rate based on Credit Score
	var interest_rate: float = 0.06
	if Globals.credit_score >= 750:
		interest_rate = 0.04
	elif Globals.credit_score >= 680:
		interest_rate = 0.045
	elif Globals.credit_score >= 620:
		interest_rate = 0.055
	
	var term_months: int = 360 # Standard 30-year reset [cite: 8]
	var monthly_payment: float = calculate_mortgage_payment(new_loan_total, term_months, interest_rate)
	
	if monthly_payment <= 0:
		Globals.notify("Error calculating payment!", Color.RED)
		return

	# 4. Update the Loan UI System
	var loans_ui = get_tree().get_first_node_in_group("loans_ui")
	if not loans_ui:
		loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
	
	if loans_ui and is_instance_valid(loans_ui):
		# Remove the old loan module for this house if it exists 
		for mod in loans_ui.active_loan_mods:
			if mod.house_ref == house:
				mod.queue_free()
				loans_ui.active_loan_mods.erase(mod)
				break
		
		# Create the new loan module
		var loan_mod = loans_ui.add_mortgage_as_loan(monthly_payment, interest_rate, term_months, house)
		
		if loan_mod and is_instance_valid(loan_mod):
			# FIX: Manually set the variables used in loans_controll_mod.gd 
			loan_mod.loan_balance = new_loan_total 
			loan_mod.months = term_months
			loan_mod.interest = interest_rate
			loan_mod.payment = monthly_payment
			loan_mod.loan_type_str = "Mortgage"
			loan_mod.house_ref = house
			loan_mod.loan_id = "mortgage_" + str(house.id)
			
			# Force the UI to refresh with these new values 
			loan_mod.update_ui()
			
			# 5. Finalize House Data and Player Money
			house.loan_price = new_loan_total
			house.mortgage = int(monthly_payment)
			house.has_loan = true
			house.bought_price = house.current_price
			
			Globals.money += calculated_cash_out
			
			# Play sound and update local labels
			var popup_sound = get_node_or_null("../popupsound")
			if popup_sound: popup_sound.play()
			
			if loan_display: loan_display.text = "Loan: " + add_comma_to_int(int(house.loan_price))
			if mortgage_label: mortgage_label.text = "Mortgage: " + add_comma_to_int(int(house.mortgage))
			
			Globals.notify("Refinanced! Cash out: $" + add_comma_to_int(int(calculated_cash_out)), Color.GREEN)
			visible = false
			SaveAndLoad.save_game()
			Globals.recalculate_expenses() # Ensure budget updates 
		else:
			Globals.notify("Failed to generate loan module!", Color.RED)
	else:
		Globals.notify("Loan system not found!", Color.RED)

func calculate_mortgage_payment(loan_amount: float, months: int, interest_rate: float) -> float:
	if months <= 0 or loan_amount <= 0 or interest_rate < 0:
		return 0.0
	var monthly_rate = interest_rate / 12.0
	var payment = loan_amount * (monthly_rate * pow(1 + monthly_rate, months)) / (pow(1 + monthly_rate, months) - 1)
	return payment

	# Rollback function for error cases
func rollback() -> void:
	if cash_out > 0:
		Globals.money -= cash_out
	house.loan_price = loan_price  # Restore original loan_price
	house.mortgage = mortgage      # Restore original mortgage
	house.has_loan = loan_status   # Restore original loan status
	house.just_bought = false
