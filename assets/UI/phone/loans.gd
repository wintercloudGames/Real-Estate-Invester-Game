extends Control

const LOAN_TYPE_MORTGAGE: int = 0
const LOAN_TYPE_PERSONAL: int = 1

@onready var ui_layer = $"../.."  # HUD reference
@onready var loan_amount_input = $TabContainer/Addloan/LoanAmountInput
@onready var take_loan_button = $TabContainer/Addloan/TakeLoanButton
@onready var loan_mod_Container = $TabContainer/Loans/ScrollContainer/loan_mod_Container
@onready var Totalpaymentdisplay = $TabContainer/Loans/Totalpaymentdisplay
@onready var max_loan_label = $TabContainer/Addloan/MaxLoanLabel
@onready var interest_rate_label = $TabContainer/Addloan/InterestRateLabel 
@onready var monthly_preview_label = $TabContainer/Addloan/MonthlyPreviewLabel

var loan_term: int = 12
var active_loan_mods: Array = []

func get_market_heat() -> float:
	var market = get_tree().get_root().find_child("Market", true, false)
	if market:
		var raw_heat = clamp(market.current_price / market.base_price, 0.5, 2.5)
		# Round heat to the nearest 0.05 to prevent tiny jitters
		return snapped(raw_heat, 0.05) 
	return 1.0

func calculate_max_loan() -> int:
	var heat = get_market_heat()
	var base_max = 1000
	
	if Globals.credit_score >= 750: base_max = 100000
	elif Globals.credit_score >= 680: base_max = 50000
	elif Globals.credit_score >= 620: base_max = 25000
	elif Globals.credit_score >= 500: base_max = 10000
	
	var market_multiplier = heat if heat > 0.8 else heat * 0.4
	var raw_max = max(base_max * market_multiplier, 500)
	
	# Round to closest 50 for clean UI and consistent button checks
	return int(round(raw_max / 50.0) * 50)

func calculate_current_rate() -> float:
	var base_rate = 0.12
	if Globals.credit_score >= 750: base_rate = 0.05
	elif Globals.credit_score >= 680: base_rate = 0.08
	elif Globals.credit_score >= 620: base_rate = 0.10
	elif Globals.credit_score < 500: base_rate = 0.25
	return base_rate * get_market_heat()

func get_credit_category() -> String:
	if Globals.credit_score >= 750: return "Great"
	elif Globals.credit_score >= 680: return "Good"
	elif Globals.credit_score >= 620: return "Fair"
	elif Globals.credit_score >= 500: return "Poor"
	return "Below Poor"

# --- 2. LIFECYCLE & UI ---

func _ready() -> void:
	add_to_group("loans_ui")
	refresh_active_loan_mods()
	update_ui()
	# Create a timer so the UI updates even if you aren't typing
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1.0 # Update every second
	timer.timeout.connect(update_ui)
	timer.start()

func _process(_delta: float) -> void:
	# Keep this simple for performance
	$TabContainer/Loans/Pay_All_Payments.visible = loan_mod_Container.get_child_count() > 0

func update_ui():
	var heat = get_market_heat()
	var amount = loan_amount_input.text.to_int()
	var current_rate = calculate_current_rate()
	var final_max = calculate_max_loan()

	# Update Labels
	interest_rate_label.text = "Interest Rate: %.2f%%\nTerm: %d Months" % [current_rate * 100, loan_term]
	
	if max_loan_label:
		max_loan_label.text = "Max Loan: $%s\n(Credit: %s | Market: x%.2f)" % [
			add_comma_to_int(final_max), get_credit_category(), heat
		]

	# Update Active Loan List & Total Bill
	var total_monthly_bill: float = 0.0
	active_loan_mods = active_loan_mods.filter(func(mod): return is_instance_valid(mod))
	for mod in active_loan_mods:
		total_monthly_bill += mod.payment
	
	Totalpaymentdisplay.text = "Total Monthly Payments: \n$" + add_comma_to_int(int(total_monthly_bill))
	
	# Preview for Current Input
	if amount > 0:
		var preview_payment = (amount * current_rate / 12) + (amount / loan_term)
		monthly_preview_label.text = "Estimated Monthly Payment: $" + add_comma_to_int(int(preview_payment))
		monthly_preview_label.modulate = Color.RED if preview_payment > Globals.Income else Color.WHITE
	else:
		monthly_preview_label.text = "Enter an amount to see payment"
		monthly_preview_label.modulate = Color.GRAY

# --- 3. LOAN ACTIONS ---

func take_loan(amount: int):
	var final_rate = calculate_current_rate()
	var monthly_payment = (amount * final_rate / 12) + (amount / loan_term) 
	
	# Apply effects to Globals 
	Globals.EXP += 10 * Globals.exp_boost
	Globals.notify("EXP + " + str(10 * Globals.exp_boost), Color.YELLOW)
	Globals.money += amount
	Globals.credit_score = clamp(Globals.credit_score - randi_range(30, 60), 300, 850) 
	
	add_loan_mod(monthly_payment, final_rate, amount, loan_term, LOAN_TYPE_PERSONAL, null)
	
	# Visual/UI feedback
	if has_node("TabContainer"):
		$TabContainer.current_tab = 1 

	var msg = "APPROVED: +$%s\n(Rate: %.1f%%)" % [add_comma_to_int(amount), final_rate * 100]
	Globals.notify(msg, Color.GREEN)
	
	if Globals.has_signal("money_changed"):
		Globals.emit_signal("money_changed")
		
	update_ui()

func add_loan_mod(payment: float, interest: float, loan_balance: float, months: int, loan_type: int, house_ref: Node = null) -> Node:
	var mod_scene = load("res://assets/UI/phone/Loans_controll_mod.tscn")
	var mod = mod_scene.instantiate()
	loan_mod_Container.add_child(mod)
	
	mod.payment = payment
	mod.interest = interest
	mod.loan_balance = loan_balance
	mod.months = months
	mod.loan_type_str = "Mortgage" if loan_type == LOAN_TYPE_MORTGAGE else "Personal"
	mod.house_ref = house_ref
	mod.loan_id = "loan_" + str(randi())
	
	active_loan_mods.append(mod)
	if mod.has_method("update_ui"): mod.update_ui()
	return mod

func _on_take_loan_button_pressed() -> void:
	var amount = loan_amount_input.text.to_int()
	var current_max = calculate_max_loan() 
	
	if amount > 0 and amount <= current_max:
		take_loan(amount)
	else:
		var message = "Max allowed right now: $" + add_comma_to_int(current_max)
		if amount <= 0: message = "Enter a valid amount!"
		Globals.notify(message, Color.RED)

func _on_loan_amount_input_text_changed(_new_text: String) -> void:
	update_ui()

func _on_pay_all_payments_pressed() -> void:
	var total_needed = 0
	for mod in active_loan_mods:
		if is_instance_valid(mod): 
			total_needed += mod.payment
		
	if Globals.money >= total_needed:
		# 1. Disable the button to prevent double-clicks
		var pay_button = $TabContainer/Loans/Pay_All_Payments # Ensure you have a unique name or reference
		if is_instance_valid(pay_button):
			pay_button.disabled = true
		
		var list_to_pay = active_loan_mods.duplicate()
		var paid_count = 0
		
		# 2. Loop through with a delay
		for mod in list_to_pay:
			if is_instance_valid(mod) and mod.has_method("_on_make_payment_pressed"):
				mod._on_make_payment_pressed(false)
				paid_count += 1
				

				await get_tree().create_timer(0.1).timeout
		

		if is_instance_valid(pay_button):
			pay_button.disabled = false
			
		Globals.notify("Paid " + str(paid_count) + " loans: -$" + add_comma_to_int(int(total_needed)), Color.GREEN)
	else:
		Globals.notify("Not enough money!", Color.RED)

func _on_option_button_item_selected(index: int) -> void:
	var loan_terms = [12, 24, 36, 48, 60]
	loan_term = loan_terms[index] if index < loan_terms.size() else 12
	update_ui()

func refresh_active_loan_mods():
	active_loan_mods.clear()
	for child in loan_mod_Container.get_children():
		if child.has_method("update_ui"):
			active_loan_mods.append(child)

func remove_loan_by_id(target_id: String) -> void:
	# Assuming your loan modules are children of 'loan_mod_Container'
	# as seen in your handle_buy logic.
	if not loan_mod_Container:
		return
		
	for child in loan_mod_Container.get_children():
		# Check if the child is a loan module and has the matching ID
		if "loan_id" in child and child.loan_id == target_id:
			# Use the module's own cleanup function if it exists, 
			# otherwise queue_free it manually.
			if child.has_method("_self_destruct"):
				child._self_destruct() 
			else:
				child.queue_free()
			break # Exit after finding and removing the match

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func add_mortgage_as_loan(payment: float, interest_rate: float, term_months: int, house: Node = null) -> Node:
	if not house or not is_instance_valid(house): return null
	return add_loan_mod(payment, interest_rate, house.loan_price, term_months, LOAN_TYPE_MORTGAGE, house)
