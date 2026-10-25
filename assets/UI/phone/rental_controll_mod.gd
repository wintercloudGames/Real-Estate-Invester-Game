extends Control

@onready var house_info_UI = get_tree().get_first_node_in_group("house_info")

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
		# --- 1. APARTMENT UNIT DISPLAY MODE ---
		house_value.visible = false # Hide house value for unit cards
		
		morgage.text = "Rent: " + add_comma_to_int(int(unit_data["rent"]))
		
		var status_text = ""
		if unit_data["has_tenant"]:
			var lease_months = unit_data.get("lease_length", 12)
			if lease_months <= 0:
				rental_status.add_theme_color_override("font_color", Color.ORANGE)
				status_text = "Status: Lease Expired!"
			else:
				rental_status.add_theme_color_override("font_color", Color.GREEN)
				status_text = "Status: Rented (%d mo left)" % lease_months
		elif unit_data["is_listed"]:
			rental_status.add_theme_color_override("font_color", Color.YELLOW)
			status_text = "Status: Seeking Tenant..."
		else:
			rental_status.add_theme_color_override("font_color", Color.CRIMSON)
			status_text = "Status: Unlisted"

		var flow = int(unit_data["rent"]) if unit_data["has_tenant"] else 0
		if flow > 0:
			cash_flow.add_theme_color_override("font_color", Color.LAWN_GREEN)
		else:
			cash_flow.add_theme_color_override("font_color", Color.WHITE)
			
		cash_flow.text = "Cashflow: " + add_comma_to_int(flow)
		rental_status.text = status_text + "\n" + cash_flow.text
		cash_flow.visible = false # Cash flow is embedded into status label text
		
		update_apartment_unit_buttons()

	elif house and house.is_apartment:
		# --- 2. APARTMENT BUILDING PHONE CARD MODE ---
		house_value.visible = true
		house_value.text = "Value: " + add_comma_to_int(int(house.current_price))
		morgage.text = "Mortgage: " + add_comma_to_int(int(house.mortgage))
		
		var total_units: int = house.units.size()
		var rented_count: int = 0
		var listed_count: int = 0
		
		for unit in house.units:
			if unit["has_tenant"]:
				rented_count += 1
			elif unit["is_listed"]:
				listed_count += 1
				
		var status_text = ""
		if rented_count == total_units:
			rental_status.add_theme_color_override("font_color", Color.GREEN)
			status_text = "Status: Fully Rented (%d/%d)" % [rented_count, total_units]
		elif rented_count > 0:
			rental_status.add_theme_color_override("font_color", Color.GREEN)
			status_text = "Status: Rented (%d/%d)" % [rented_count, total_units]
		elif listed_count > 0:
			rental_status.add_theme_color_override("font_color", Color.YELLOW)
			status_text = "Status: Seeking (%d/%d)" % [listed_count, total_units] # Shortened to avoid clipping
		else:
			rental_status.add_theme_color_override("font_color", Color.CRIMSON)
			status_text = "Status: Unlisted (0/%d)" % total_units

		var total_income = house.get_total_apartment_income() if house.has_method("get_total_apartment_income") else 0
		var flow = total_income - int(house.mortgage)
		
		if flow < 0:
			cash_flow.add_theme_color_override("font_color", Color.CRIMSON)
		elif flow > 0:
			cash_flow.add_theme_color_override("font_color", Color.LAWN_GREEN)
		else:
			cash_flow.add_theme_color_override("font_color", Color.WHITE)
			
		cash_flow.text = "Cashflow: " + add_comma_to_int(int(flow))
		rental_status.text = status_text + "\n" + cash_flow.text
		cash_flow.visible = false
		
		update_tenant_buttons()

	elif house:
		# --- 3. REGULAR SINGLE-FAMILY HOUSE DISPLAY MODE ---
		house_value.visible = true
		morgage.text = "Mortgage: " + add_comma_to_int(int(house.mortgage))
		house_value.text = "Value: " + add_comma_to_int(int(house.current_price))
		
		var status_text = ""
		if house.has_tenant:
			rental_status.add_theme_color_override("font_color", Color.GREEN)
			status_text = "Status: Rented"
		elif house.is_listed:
			rental_status.add_theme_color_override("font_color", Color.YELLOW)
			status_text = "Status: Seeking Tenant..."
		else:
			rental_status.add_theme_color_override("font_color", Color.CRIMSON)
			status_text = "Status: Unlisted"

		var current_income = house.rent if house.has_tenant else 0
		var flow = current_income - house.mortgage
		
		if flow < 0:
			cash_flow.add_theme_color_override("font_color", Color.CRIMSON)
		elif flow > 0:
			cash_flow.add_theme_color_override("font_color", Color.LAWN_GREEN)
		else:
			cash_flow.add_theme_color_override("font_color", Color.WHITE)
			
		cash_flow.text = "Cashflow: " + add_comma_to_int(int(flow))
		rental_status.text = status_text + "\n" + cash_flow.text
		cash_flow.visible = false
		
		update_tenant_buttons()

func update_tenant_buttons() -> void:
	if not house:
		rent_button.visible = false
		if rent_ready_label: rent_ready_label.visible = false
		remove_tenent_button.visible = false
		list_for_rent_button.visible = false
		return

	# If this card represents an apartment building
	if house.is_apartment:
		remove_tenent_button.visible = false # Keep remove tenant hidden on phone card
		
		# Check if there's rent ready to collect
		var collect_node = house.get_node_or_null("Collect_Rent")
		var has_cash = collect_node and collect_node.stored_cash > 0
		rent_button.visible = has_cash
		if rent_ready_label: rent_ready_label.visible = has_cash
		
		# Check if there are any unrented units that aren't listed yet
		var has_unlisted_vacancies = false
		for unit in house.units:
			if not unit["has_tenant"] and not unit["is_listed"]:
				has_unlisted_vacancies = true
				break
				
		list_for_rent_button.visible = has_unlisted_vacancies
		return

	# --- Regular House Logic ---
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
		# Individual apartment unit listing
		unit_data["is_listed"] = true
	elif house:
		if house.is_apartment:
			# List all vacant units in the apartment building
			for unit in house.units:
				if not unit["has_tenant"]:
					unit["is_listed"] = true
			Globals.notify("All vacant units listed for rent!", Color.LAWN_GREEN)
		else:
			# Regular single-family house listing
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
	
	if house and house.is_apartment:
		# Open Apartment UI for apartment buildings
		var apartment_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/ApartmentMain")
		if apartment_ui and is_instance_valid(apartment_ui):
			apartment_ui.house = house
			apartment_ui.visible = true
			if apartment_ui.has_method("setup_apartment_ui"):
				apartment_ui.setup_apartment_ui()
	else:
		# Open standard House Info UI for regular houses
		if house_info_UI:
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
