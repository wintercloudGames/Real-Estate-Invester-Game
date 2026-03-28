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

func _on_remove_tenent_pressed() -> void:
	house.remove_tenant()

func update_tenant_buttons():

	if Globals.rent_houses == false:
			$Remove_Tenent.visible = false
			$Tenent_button.visible = false
			$Label_islistedforrent.visible = false
	else: 
		if house:
			if house.has_tenant:
				$Remove_Tenent.visible = true
				$Tenent_button.visible = false
				$Label_islistedforrent.visible = false
			if house.is_listed and not house.has_tenant:
				$Remove_Tenent.visible = false
				$Tenent_button.visible = false
				$Label_islistedforrent.visible = true
			if not house.is_listed and not house.has_tenant:
				$Remove_Tenent.visible = false
				$Tenent_button.visible = true
				$Label_islistedforrent.visible = false

func _on_tenent_button_pressed() -> void:
	house.is_listed = true
	update_tenant_buttons()

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
	house.edit_yard()
	visible = false
	$"../Phone".put_away()

func _on_sell_button_pressed() -> void:
	$Sell_home.visible = true

func _on_yes_sell_pressed() -> void:
	if house:
		Globals.money += house.current_price
		Globals.Propertys -= 1
		house.remove_tenant()
		$"../../Rent_offer_system".clear_offers_ui()
		if house.has_loan:
			var loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
			if loans_ui and is_instance_valid(loans_ui):
				for mod in loans_ui.active_loan_mods:
					if mod.house_ref == house:
						mod._on_payoff_pressed()  # Pays off balance, removes mod, updates credit/exp
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

func show_floating_label(text: String, color: Color = Color.WHITE) -> void:
	var canvas_layer = get_node_or_null("/root/Root/UserInterface/Game/HUD")
	if canvas_layer:
		var label = Label.new()
		label.text = text
		label.modulate = color
		label.position = Vector2(700, 500)  # Adjust position as needed
		canvas_layer.add_child(label)
		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5)
		tween.parallel().tween_property(label, "modulate:a", 0, 1.5)
		tween.tween_callback(label.queue_free)
	else:
		push_warning("No canvas_layer found for floating label: " + text)

func _on_refinance_button_pressed() -> void:
	if not is_instance_valid(house):
		show_floating_label("Invalid house!", Color.RED)
		return
	
	if not house.owned:
		show_floating_label("House not owned!", Color.RED)
		return
	
	# Check loan eligibility based on credit score
	var can_use_loan: bool = Globals.credit_score >= 500
	if not can_use_loan:
		show_floating_label("Cannot refinance: Credit score below 500!", Color.RED)
		return
	
	# Play popup sound
	var popup_sound = get_node_or_null("../popupsound")
	if popup_sound:
		popup_sound.play()
	
	# Calculate new loan amount (full current price, as in original function)
	var calculated_loan_amount: float = house.current_price
	if calculated_loan_amount <= 0:
		show_floating_label("Invalid loan amount!", Color.RED)
		return
	
	# Determine interest rate based on credit score
	var interest_rate: float = 0.06
	if Globals.credit_score >= 750:
		interest_rate = 0.04
	elif Globals.credit_score >= 680:
		interest_rate = 0.045
	elif Globals.credit_score >= 620:
		interest_rate = 0.055
	
	var term_months: int = 12 * 30
	var monthly_payment: float = calculate_mortgage_payment(calculated_loan_amount, term_months, interest_rate)
	if monthly_payment <= 0:
		show_floating_label("Invalid loan terms!", Color.RED)
		return
	
	# Cash out: Add difference between new loan and existing loan (if any)
	if cash_out > 0:
		Globals.money += cash_out
	
	# Store original values for rollback
	var original_loan_price: float = house.loan_price
	var original_mortgage: float = house.mortgage
	var original_loan_status: bool = house.has_loan
	
	# Update house properties
	house.bought_price = house.current_price
	house.loan_price = calculated_loan_amount
	house.mortgage = int(monthly_payment)
	house.has_loan = true
	house.just_bought = true
	
	# Add loan to Loans UI
	var loan_mod = null
	var loans_ui = get_tree().get_first_node_in_group("loans_ui")
	if not loans_ui:
		loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
	
	if loans_ui and is_instance_valid(loans_ui) and loans_ui.loan_mod_Container:
		var loan_mod_path = "res://assets/UI/phone/Loans_controll_mod.tscn"
		if ResourceLoader.exists(loan_mod_path):
			# Remove existing loan for this house, if any
			for mod in loans_ui.active_loan_mods:
				if mod.house_ref == house:
					mod.queue_free()
					break
			house.loan_price = calculated_loan_amount
			house.mortgage = int(monthly_payment)
			house.has_loan = true
			loan_mod = loans_ui.add_mortgage_as_loan(monthly_payment, interest_rate, term_months, house)
			if loan_mod and is_instance_valid(loan_mod):
				loan_mod.loan_id = "mortgage_" + str(house.id)
				house.house_buy(true, house.current_price, calculated_loan_amount, loan_mod)
			else:
				rollback()
				show_floating_label("Failed to create loan!", Color.RED)
				return
		else:
			rollback()
			show_floating_label("Loan system error!", Color.RED)
			return
	else:
		rollback()
		show_floating_label("Loan system error!", Color.RED)
		return
	
	# Update script-level variables
	price = house.current_price
	loan_price = house.loan_price
	mortgage = house.mortgage
	loan_status = house.has_loan
	cash_out = 0
	
	# Update UI
	loan_display.text = "Loan: " + add_comma_to_int(house.loan_price)
	mortgage_label.text = "Mortgage: " + add_comma_to_int(house.mortgage)
	visible = false
	SaveAndLoad.save_game()
	show_floating_label("Refinanced! Cash out: $" + add_comma_to_int(int(cash_out)), Color.GREEN)

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
