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
var loan_term = 12
var active_loan_mods: Array = []

# --- Market Integration Helper ---
func get_market_heat() -> float:
	# Adjust this path to match your scene tree (e.g., /root/Main/Market)
	var market = get_tree().get_root().find_child("Market", true, false)
	if market:
		# Returns a factor (e.g., 1.0 is stable, 1.5 is booming, 0.7 is crashing)
		return clamp(market.current_price / market.base_price, 0.5, 2.5)
	return 1.0

func _ready() -> void:
	add_to_group("loans_ui")
	refresh_active_loan_mods()
	update_ui()

func _process(_delta: float) -> void:
	$TabContainer/Loans/Pay_All_Payments.visible = loan_mod_Container.get_child_count() > 0
	update_ui()

func update_ui():
	var heat = get_market_heat()
	var amount = loan_amount_input.text.to_int()
	
	# --- 1. Calculate the Interest Rate (Matches take_loan logic) ---
	var base_rate = 0.12
	if Globals.credit_score >= 750: base_rate = 0.05
	elif Globals.credit_score >= 680: base_rate = 0.08
	elif Globals.credit_score >= 620: base_rate = 0.10
	elif Globals.credit_score < 500: base_rate = 0.25
	
	var current_rate = base_rate * heat
	
	# Update the Rate Display (Clean version as requested)
	interest_rate_label.text = "Interest Rate: %.2f%%\nTerm: %d Months" % [current_rate * 100, loan_term]

	# --- 2. Calculate the Preview Payment ---
	if amount > 0:
		# Formula: (Principal * Annual Rate / 12) + (Principal / Term)
		var preview_payment = (amount * current_rate / 12) + (amount / loan_term)
		monthly_preview_label.text = "Estimated Monthly Payment: $" + add_comma_to_int(int(preview_payment))
		
		# Visual Warning: Red if it exceeds their current total income
		if preview_payment > Globals.Income:
			monthly_preview_label.modulate = Color.RED
		else:
			monthly_preview_label.modulate = Color.WHITE
	else:
		monthly_preview_label.text = "Enter an amount to see payment"
		monthly_preview_label.modulate = Color.GRAY
	# 2. Calculate Dynamic Max Loan
	if max_loan_label:
		var base_max = 500
		var credit_cat = "Below Poor"
		
		if Globals.credit_score >= 750: base_max = 100000; credit_cat = "Great"
		elif Globals.credit_score >= 680: base_max = 50000; credit_cat = "Good"
		elif Globals.credit_score >= 620: base_max = 25000; credit_cat = "Fair"
		elif Globals.credit_score >= 500: base_max = 10000; credit_cat = "Poor"
		
		# Banks lend more in a boom, but tighten up significantly in a crash
		var market_multiplier = heat if heat > 0.8 else heat * 0.4
		var final_max = int(base_max * market_multiplier)
		
		max_loan_label.text = "Max Loan: $%s\n(Credit: %s | Market: x%.2f)" % [
			add_comma_to_int(final_max), credit_cat, market_multiplier
		]
	
func take_loan(amount: int):
	var heat = get_market_heat()
	
	# Determine Rate based on Market + Credit
	var base_rate = 0.12
	if Globals.credit_score >= 750: base_rate = 0.05
	elif Globals.credit_score >= 680: base_rate = 0.08
	elif Globals.credit_score >= 620: base_rate = 0.10
	
	var final_rate = base_rate * heat
	var monthly_payment = (amount * final_rate / 12) + (amount / loan_term)
	
	# Apply effects to Globals
	Globals.exp += 10
	Globals.money += amount
	Globals.credit_score -= randi_range(30, 60) # Taking debt lowers score
	Globals.credit_score = clamp(Globals.credit_score, 300, 850)
	
	add_loan_mod(monthly_payment, final_rate, amount, loan_term, LOAN_TYPE_PERSONAL, null)
	update_ui()
	
	var msg = "Loan of $%s approved at %.1f%% interest!" % [add_comma_to_int(amount), final_rate * 100]
	show_floating_label(msg, Color.GREEN)

func add_mortgage_as_loan(payment: float, interest_rate: float, term_months: int, house: Node = null) -> Node:
	if not house or not is_instance_valid(house): return null
	return add_loan_mod(payment, interest_rate, house.loan_price, term_months, LOAN_TYPE_MORTGAGE, house)

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

func refresh_active_loan_mods():
	active_loan_mods.clear()
	for child in loan_mod_Container.get_children():
		if child.has_method("update_ui"):
			active_loan_mods.append(child)

func show_floating_label(text: String, color: Color = Color.WHITE):
	if ui_layer and is_instance_valid(ui_layer):
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.position = get_global_mouse_position() # Better visibility
		ui_layer.add_child(label)
		var tween = get_tree().create_tween()
		tween.tween_property(label, "position:y", label.position.y - 80, 2.0)
		tween.parallel().tween_property(label, "modulate:a", 0, 2.0)
		tween.tween_callback(label.queue_free)

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_take_loan_button_pressed() -> void:
	var amount = loan_amount_input.text.to_int()
	var heat = get_market_heat()
	
	# Calculate Max Loan logic matches update_ui for consistency
	var base_max = 500
	if Globals.credit_score >= 750: base_max = 100000
	elif Globals.credit_score >= 680: base_max = 50000
	elif Globals.credit_score >= 620: base_max = 25000
	elif Globals.credit_score >= 500: base_max = 10000
	
	var market_multiplier = heat if heat > 0.8 else heat * 0.4
	var final_max = int(base_max * market_multiplier)
	
	if amount > 0 and amount <= final_max and Globals.credit_score >= 300:
		take_loan(amount)
	else:
		var message = "Credit score too low!"
		if Globals.credit_score >= 300:
			message = "Max allowed right now: $" + add_comma_to_int(final_max)
		show_floating_label(message, Color.RED)

func _on_pay_all_payments_pressed() -> void:
	var total_needed = 0
	for mod in active_loan_mods:
		if is_instance_valid(mod): total_needed += mod.payment
		
	if Globals.money >= total_needed:
		# Use a copy of the array because paying off a loan might remove it from the original list
		var list_to_pay = active_loan_mods.duplicate()
		for mod in list_to_pay:
			if is_instance_valid(mod) and mod.has_method("_on_make_payment_pressed"):
				mod._on_make_payment_pressed()
		show_floating_label("Paid all: $" + add_comma_to_int(int(total_needed)), Color.GREEN)
	else:
		show_floating_label("Not enough money!", Color.RED)

func _on_option_button_item_selected(index: int) -> void:
	var loan_terms = [12, 24, 36, 48, 60]
	loan_term = loan_terms[index] if index < loan_terms.size() else 12
	update_ui()
