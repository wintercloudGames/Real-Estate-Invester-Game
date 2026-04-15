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
	if house:
		update_tenant_buttons()
		if house.is_building == true:
			$Edit_yard_button.visible = false
		else:
			pass
			#$Edit_yard_button.visible = true
		price_display.text = "House Worth: " + add_comma_to_int(house.current_price)
		label_bought_price.text = "Original House price: " + add_comma_to_int(house.bought_price)
		loan_display.text = "Loan: " + add_comma_to_int(house.loan_price)
		mortgage_label.text = "Mortgage: " + add_comma_to_int(house.mortgage)
		
		var cashflow = house.rent - house.mortgage
		cashflow_label.text = "CashFlow: " + add_comma_to_int(cashflow)
		
		income_label.text = "Income: " + add_comma_to_int(house.rent)
			
		aparmant_condition.text = "%.0f%% condition" % (house.apartment_condition * 100)
		if house.has_tenant:
			lease_stat.text = "lease amount: " + add_comma_to_int(house.lease_length)
			punctuality.text = "%.0f%% punctuality" % (house.payment_punctuality * 100)
		else:
			lease_stat.text = ""
			punctuality.text = ""
		sell_amount_label.text = add_comma_to_int(house.current_price) + " - " + add_comma_to_int(house.loan_price) + "\n" + add_comma_to_int(house.current_price - house.loan_price)
		if house.has_tenant == false and house.is_listed == false:
			$Tenent_button.visible = true
			
		if house.upgrade_amount >= house.upgrade_max:
			$Upgrade.visible = false
			$Upgrade_label.visible = false
		else:
			$Upgrade.visible = true
			$Upgrade_label.visible = true
	
	if loan_price <= 0:
		mortgage = 0

func _input(event: InputEvent) -> void:
	if visible == false:
		pass
	if Input.is_action_just_pressed("buyandrent"):
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
	
	if Globals.money >= upgrade_cost:
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
