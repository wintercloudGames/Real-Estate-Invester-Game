extends Control

@onready var house_info_UI = get_node("/root/Root/UserInterface/Game/HUD/House_info")

@onready var sell_button: Button = $HBoxContainer/Sell_Button
@onready var refinance_button: Button = $HBoxContainer/Refinance_Button
@onready var list_for_rent_button: Button = $HBoxContainer/List_for_rent_Button
@onready var remove_tenent_button: Button = $HBoxContainer/Remove_Tenent_Button

@onready var rent_button: Button = $HBoxContainer/Collect_rent_Button
@onready var house_value: Label = $HBoxContainer2/House_Value
@onready var morgage: Label = $HBoxContainer2/Morgage
@onready var rental_status: Label = $HBoxContainer2/rental_status
@onready var cash_flow: Label = $HBoxContainer2/Cash_flow
@onready var rent_ready_label = $HBoxContainer2/Rent_ready

var house = null
var apartment_building = null
var unit_data = null

func _process(_delta: float) -> void:
	if unit_data and apartment_building:
		# --- APARTMENT UNIT DISPLAY MODE ---
		house_value.visible = false # Hide value for apartment units!
		
		morgage.text = "Rent: " + add_comma_to_int(int(unit_data["rent"]))
		
		if unit_data["has_tenant"]:
			var lease_months = unit_data.get("lease_length", 12)
			if lease_months <= 0:
				rental_status.add_theme_color_override("font_color", Color.ORANGE)
				rental_status.text = "Status: Lease Expired!"
			else:
				rental_status.add_theme_color_override("font_color", Color.GREEN)
				rental_status.text = "Status: Rented (%d mo left)" % lease_months
		elif unit_data["is_listed"]:
			rental_status.add_theme_color_override("font_color", Color.YELLOW)
			rental_status.text = "Status: Seeking Tenant..."
		else:
			rental_status.add_theme_color_override("font_color", Color.CRIMSON)
			rental_status.text = "Status: Unlisted"

		var flow = int(unit_data["rent"]) if unit_data["has_tenant"] else 0
		if flow > 0:
			cash_flow.add_theme_color_override("font_color", Color.LAWN_GREEN)
		else:
			cash_flow.add_theme_color_override("font_color", Color.WHITE)
			
		cash_flow.text = "Cashflow: " + add_comma_to_int(flow)
		update_apartment_unit_buttons()

	elif house:
		# --- REGULAR HOUSE DISPLAY MODE ---
		house_value.visible = true # Ensure it's visible for normal houses
		morgage.text = "Mortgage: " + add_comma_to_int(int(house.mortgage))
		house_value.text = "Value: " + add_comma_to_int(int(house.current_price))
		
		if house.has_tenant:
			rental_status.add_theme_color_override("font_color", Color.GREEN)
			rental_status.text = "Status: Rented"
		elif house.is_listed:
			rental_status.add_theme_color_override("font_color", Color.YELLOW)
			rental_status.text = "Status: Seeking Tenant..."
		else:
			rental_status.add_theme_color_override("font_color", Color.CRIMSON)
			rental_status.text = "Status: Unlisted"

		var current_income = house.rent if house.has_tenant else 0
		var flow = current_income - house.mortgage
		
		if flow < 0:
			cash_flow.add_theme_color_override("font_color", Color.CRIMSON)
		elif flow > 0:
			cash_flow.add_theme_color_override("font_color", Color.LAWN_GREEN)
		else:
			cash_flow.add_theme_color_override("font_color", Color.WHITE)
			
		cash_flow.text = "Cashflow: " + add_comma_to_int(int(flow))
		update_tenant_buttons()

func update_tenant_buttons() -> void:
	if not house:
		rent_button.visible = false
		if rent_ready_label: rent_ready_label.visible = false
		remove_tenent_button.visible = false
		list_for_rent_button.visible = false
		return

	var rent_ready = house.get_node_or_null("Collect_Rent/Dollar_sign")
	var is_rent_ready = rent_ready and rent_ready.visible
	
	rent_button.visible = is_rent_ready
	if rent_ready_label: rent_ready_label.visible = is_rent_ready

	if house.has_tenant:
		remove_tenent_button.visible = true
		list_for_rent_button.visible = false
	else:
		remove_tenent_button.visible = false
		if house.is_listed:
			list_for_rent_button.visible = false
		else:
			list_for_rent_button.visible = true

func update_apartment_unit_buttons() -> void:
	if not unit_data:
		rent_button.visible = false
		remove_tenent_button.visible = false
		list_for_rent_button.visible = false
		return

	if sell_button: sell_button.visible = false
	if refinance_button: refinance_button.visible = false
	
	var more_btn = $HBoxContainer.get_node_or_null("More_Button")
	if more_btn: more_btn.visible = false

	# Show collect button only if rented and rent has not been paid yet this cycle
	var rent_unpaid = unit_data["has_tenant"] and not unit_data.get("paid_rent", false)
	rent_button.visible = rent_unpaid
	if rent_ready_label: rent_ready_label.visible = rent_unpaid

	if unit_data["has_tenant"]:
		remove_tenent_button.visible = true
		list_for_rent_button.visible = false
	else:
		remove_tenent_button.visible = false
		list_for_rent_button.visible = not unit_data["is_listed"]

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_list_for_rent_button_pressed() -> void:
	if unit_data:
		unit_data["is_listed"] = true
	elif house:
		house.is_listed = true

func _on_remove_tenent_button_pressed():
	if unit_data:
		unit_data["has_tenant"] = false
		unit_data["is_listed"] = false
		unit_data["paid_rent"] = false
		unit_data["lease_length"] = 12
	elif house:
		house.remove_tenant()
	
func _on_refinance_button_pressed() -> void:
	if unit_data: return
	if not is_instance_valid(house) or not house.owned or not house.has_loan: return
	
	var loans_ui = get_tree().get_first_node_in_group("loans_ui")
	if not loans_ui:
		loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
	if not loans_ui: return
	
	var loan_mod = null
	for mod in loans_ui.active_loan_mods:
		if mod.loan_type_str == "Mortgage" and mod.house_ref == house:
			loan_mod = mod
			break
			
	if not loan_mod: return
	
	var new_months: int = 360
	var new_interest_rate: float = 0.05
	if Globals.credit_score >= 750: new_interest_rate = 0.04
	elif Globals.credit_score >= 680: new_interest_rate = 0.045
	elif Globals.credit_score >= 620: new_interest_rate = 0.055

	var current_balance = loan_mod.loan_balance
	var new_payment = calculate_mortgage_payment(current_balance, new_months, new_interest_rate)
	
	loan_mod.payment = new_payment
	loan_mod.interest = new_interest_rate
	loan_mod.months = new_months
	loan_mod.update_ui()
	
	house.loan_price = current_balance
	house.mortgage = int(round(new_payment))
	
	Globals.notify("Refinanced successfully!", Color.GREEN)
	SaveAndLoad.save_game()

func calculate_mortgage_payment(loan_amount: float, months: int, interest_rate: float) -> float:
	if months <= 0 or loan_amount <= 0 or interest_rate < 0: return 0.0
	var monthly_rate := interest_rate / 12.0
	if monthly_rate == 0: return loan_amount / months
	var power_term := pow(1 + monthly_rate, months)
	var payment := loan_amount * (monthly_rate * power_term) / (power_term - 1)
	return round(payment * 100.0) / 100.0

func _on_sell_button_pressed() -> void:
	if unit_data: return
	if house: house.sell_house()

func _on_more_button_pressed() -> void:
	if unit_data: return
	house_info_UI.visible = true
	house_info_UI.house = house

func _on_collect_rent_button_pressed() -> void:
	if unit_data:
		if unit_data["has_tenant"] and not unit_data.get("paid_rent", false):
			var rent_amt = int(unit_data["rent"])
			Globals.money += rent_amt
			unit_data["paid_rent"] = true
			Globals.notify("Collected $" + add_comma_to_int(rent_amt) + " rent from Unit #" + str(unit_data["unit_id"]), Color.GREEN)
	elif house and house.Collect_Rent:
		house.paid_rent = false
		house.Collect_Rent.house = house
		house.Collect_Rent.collect_rent()
