extends Control

@onready var house_info_UI = get_node("/root/Root/UserInterface/Game/HUD/House_info")

@onready var sell_button: Button = $HBoxContainer/Sell_Button
@onready var refinance_button: Button = $HBoxContainer/Refinance_Button
@onready var list_for_rent_button: Button = $HBoxContainer/List_for_rent_Button
@onready var remove_tenent_button: Button = $HBoxContainer/Remove_Tenent_Button

@onready var rent_button:Button =  $HBoxContainer/Collect_rent_Button
@onready var house_value: Label = $HBoxContainer2/House_Value
@onready var morgage: Label = $HBoxContainer2/Morgage
@onready var rental_status: Label = $HBoxContainer2/rental_status
@onready var cash_flow: Label = $HBoxContainer2/Cash_flow

var rent = 0
var mortgage = 0
var has_tenant = false
var house = null
var Collect_Rent = null

func _process(_delta: float) -> void:
	if house:
		morgage.text = "mortgage: " + add_comma_to_int(house.mortgage)
		if house.has_tenant:
			rental_status.add_theme_color_override("font_color", Color.GREEN)
			rental_status.text = "Status: Rented"
		elif house.is_listed:
	# It's on the market, but waiting for a tenant
			rental_status.add_theme_color_override("font_color", Color.YELLOW) 
			rental_status.text = "Status: Seeking Tenant..."
		else:
	# The player forgot to click 'List for Rent'
			rental_status.add_theme_color_override("font_color", Color.CRIMSON)
			rental_status.text = "Status: Unlisted"
			
		rent = house.rent
		house_value.text = "Value: " + add_comma_to_int(house.current_price)
		mortgage = house.mortgage
		var flow = house.rent - house.mortgage
		if flow <0:
			cash_flow.add_theme_color_override("font_color",Color.RED)
		else:
			cash_flow.add_theme_color_override("font_color",Color.GREEN)
		cash_flow.text = "cashflow: " + add_comma_to_int(flow)
	update_tenant_buttons()

func update_tenant_buttons() -> void:
	if not house:
		# Hide everything if no house selected
		rent_button.visible = false
		$HBoxContainer2/Rent_ready.visible = false
		remove_tenent_button.visible = false
		list_for_rent_button.visible = false
		return

	# ─── Rent collection button ───
	var rent_ready = house.get_node_or_null("Collect_Rent/Dollar_sign")
	var is_rent_ready = rent_ready and rent_ready.visible
	
	rent_button.visible = is_rent_ready
	$HBoxContainer2/Rent_ready.visible = is_rent_ready   # Assuming this is a label/icon saying "Rent Ready!"

	# ─── Tenant management buttons ───
	if house.has_tenant:
		# Has tenant → show Remove, hide List
		remove_tenent_button.visible = true
		list_for_rent_button.visible = false
	else:
		# No tenant
		remove_tenent_button.visible = false
		
		if house.is_listed:
			# Already listed → hide List button (maybe show "Listed" label instead?)
			list_for_rent_button.visible = false
		else:
			# No tenant and not listed → show List for Rent
			list_for_rent_button.visible = true

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")

	return str_value

func _on_list_for_rent_button_pressed() -> void:
	if house:
		house.is_listed = true

func _on_remove_tenent_button_pressed():
	if house:
		house.has_tenant = false
		house.is_listed = true
		house.rent = 0
	
func _on_refinance_button_pressed() -> void:
	if not is_instance_valid(house):
		Globals.notify("Invalid house!", Color.RED)
		return
	
	if not house.owned:
		Globals.notify("You don't own this house!", Color.RED)
		return
	
	if not house.has_loan:
		Globals.notify("No existing mortgage to refinance!", Color.RED)
		return
	
	# Locate the Loans UI and find the mortgage for this house
	var loans_ui = get_tree().get_first_node_in_group("loans_ui")
	if not loans_ui:
		loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
	
	if not loans_ui or not is_instance_valid(loans_ui):
		Globals.notify("Loan system unavailable!", Color.RED)
		return
	
	var loan_mod = null
	for mod in loans_ui.active_loan_mods:
		if mod.loan_type_str == "Mortgage" and mod.house_ref == house:
			loan_mod = mod
			break
	
	if not loan_mod or not is_instance_valid(loan_mod):
		Globals.notify("No active mortgage found for this house!", Color.RED)
		return
	
	# ────────────────────────────────────────────────
	# Decide new terms (you can later expose these to UI)
	var new_months: int = 360  # 30 years reset — most common refinance choice
	var new_interest_rate: float = loan_mod.interest
	
	# Example: improve rate based on credit (same logic as script #1)
	if Globals.credit_score >= 750:
		new_interest_rate = 0.04
	elif Globals.credit_score >= 680:
		new_interest_rate = 0.045
	elif Globals.credit_score >= 620:
		new_interest_rate = 0.055
	elif Globals.credit_score >= 500:
		new_interest_rate = 0.06
	else:
		Globals.notify("Credit score too low to refinance!", Color.RED)
		return
	
	# Optional: small guaranteed improvement if already good rate
	# new_interest_rate = min(new_interest_rate, loan_mod.interest - 0.005)
	
	if new_interest_rate >= loan_mod.interest and new_months >= loan_mod.months:
		Globals.notify("No better terms available right now.", Color.YELLOW)
		return
	var current_balance: float = loan_mod.loan_balance
	# Calculate new payment
	if loan_mod:
		current_balance = loan_mod.loan_balance
	else:
		current_balance = house.current_price
	
	var new_payment: float = calculate_mortgage_payment(current_balance, new_months, new_interest_rate)
	
	if new_payment <= 0 or is_nan(new_payment) or is_inf(new_payment):
		Globals.notify("Invalid refinance terms!", Color.RED)
		return
	
	# Update loan module
	loan_mod.payment      = new_payment
	loan_mod.interest     = new_interest_rate
	loan_mod.months       = new_months
	# loan_mod.loan_balance stays the same (rate-and-term refinance)
	loan_mod.update_ui()   # hopefully redraws / recalculates amortization if needed
	
	# Update house properties (for consistency / save)
	house.loan_price = current_balance
	house.mortgage   = int(round(new_payment))
	house.has_loan   = true
	# house.bought_price = house.current_price   # ← only if doing cash-out refinance
	
	# Optional: update local script vars if you use them
	# mortgage = house.mortgage
	# loan_price = house.loan_price
	
	# Feedback
	var savings = int(round(loan_mod.payment - new_payment))
	var msg = "Refinanced successfully!\nNew payment: $%s" % add_comma_to_int(int(new_payment))
	if savings > 0:
		msg += "\nMonthly savings: $%s" % add_comma_to_int(savings)
	
	Globals.notify(msg, Color.GREEN)
	
	var popup_sound = get_node_or_null("../popupsound")
	if popup_sound:
		popup_sound.play()
	
	SaveAndLoad.save_game()
	visible = false  


func calculate_mortgage_payment(loan_amount: float, months: int, interest_rate: float) -> float:
	if months <= 0 or loan_amount <= 0 or interest_rate < 0:
		push_error("Invalid mortgage params: amount=%.2f, months=%d, rate=%.4f" % [loan_amount, months, interest_rate])
		return 0.0
	
	var monthly_rate := interest_rate / 12.0
	if monthly_rate == 0:
		return loan_amount / months
	
	var power_term := pow(1 + monthly_rate, months)
	var payment := loan_amount * (monthly_rate * power_term) / (power_term - 1)
	
	return round(payment * 100.0) / 100.0  # round to nearest cent


func _on_sell_button_pressed() -> void:
	if house:
		house.sell_house()

func _on_more_button_pressed() -> void:
	house_info_UI.visible = true
	house_info_UI.house = house
	
func clear_House_ui_data():
	house_info_UI.price = 0
	house_info_UI.loan_price = 0
	house_info_UI.mortgage = 0
	house_info_UI.income = 0
	house_info_UI.house = null
	house_info_UI.has_tenant = false
	
func _on_collect_rent_button_pressed() -> void:
	if house:
		house.paid_rent = false
		house.Collect_Rent.house = house
		house.Collect_Rent.collect_rent()
		
