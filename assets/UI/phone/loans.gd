extends Control

const LOAN_TYPE_MORTGAGE: int = 0
const LOAN_TYPE_PERSONAL: int = 1

@onready var ui_layer = $"../.."  # HUD reference
@onready var loan_amount_input = $TabContainer/Addloan/LoanAmountInput
@onready var take_loan_button = $TabContainer/Addloan/TakeLoanButton
@onready var loan_mod_Container = $TabContainer/Loans/ScrollContainer/loan_mod_Container
@onready var loan_balance_label = $TabContainer/Addloan/LoanBalanceLabel
@onready var Totalpaymentdisplay = $TabContainer/Loans/Totalpaymentdisplay
@onready var max_loan_label = $TabContainer/Addloan/MaxLoanLabel
@onready var interest_rate_label = $TabContainer/Addloan/InterestRateLabel  # New label for interest rate

var loan_term = 12
var active_loan_mods: Array = []
var adloan = true

func _ready() -> void:
	add_to_group("loans_ui")  # Ensure node is in group
	refresh_active_loan_mods()
	update_ui()

func _process(delta: float) -> void:
	if loan_mod_Container.get_child_count() > 0:
		$TabContainer/Loans/Pay_All_Payments.visible = true
	else:
		$TabContainer/Loans/Pay_All_Payments.visible = false
	update_ui()

func update_ui():
	var total_payment = 0
	for mod in active_loan_mods:
		if is_instance_valid(mod):
			total_payment += mod.payment
	if Totalpaymentdisplay:
		Totalpaymentdisplay.text = "Total loan payments \n $" + add_comma_to_int(int(total_payment))
	if max_loan_label:
		var max_loan = 0
		var credit_category = "Poor"
		if Globals.credit_score >= 750:
			max_loan = 100000
			credit_category = "Great"
		elif Globals.credit_score >= 680:
			max_loan = 50000
			credit_category = "Good"
		elif Globals.credit_score >= 620:
			max_loan = 25000
			credit_category = "Fair"
		elif Globals.credit_score >= 500:
			max_loan = 10000
			credit_category = "Poor"
		elif Globals.credit_score >= 300:
			max_loan = 500
			credit_category = "Below Poor"
		max_loan_label.text = "Max Loan: $%s (based on credit %s)" % [add_comma_to_int(max_loan), credit_category]
	if interest_rate_label:
		var interest_rate = 0.12  # Default
		if Globals.credit_score >= 750:
			interest_rate = 0.06
		elif Globals.credit_score >= 680:
			interest_rate = 0.08
		elif Globals.credit_score >= 620:
			interest_rate = 0.10
		elif Globals.credit_score >= 400:
			interest_rate = 0.25
		interest_rate_label.text = "Interest Rate: %s%% (for %s-month term)" % [str(interest_rate * 100), loan_term]

func take_loan(amount: int):
	var interest_rate = 0.12
	if Globals.credit_score >= 750:
		interest_rate = 0.06
	elif Globals.credit_score >= 680:
		interest_rate = 0.08
	elif Globals.credit_score >= 620:
		interest_rate = 0.10
	elif Globals.credit_score >= 400:
		interest_rate = 0.25
	var monthly_payment = (amount * interest_rate / 12) + (amount / loan_term)
	Globals.exp += 10
	Globals.money += amount
	Globals.credit_score -= 5
	Globals.credit_score = clamp(Globals.credit_score, 300, 850)
	add_loan_mod(monthly_payment, interest_rate, amount, loan_term, 1, null)
	update_ui()
	show_floating_label("Loan of $" + add_comma_to_int(amount) + " approved at " + str(interest_rate * 100) + "% interest!", Color.GREEN)

func add_mortgage_as_loan(payment: float, interest_rate: float, term_months: int, house: Node = null) -> Node:
	if not house or not is_instance_valid(house):
		push_error("add_mortgage_as_loan called with invalid house reference: %s" % str(house))
		return null
	if not house.get_script() or not house.get("loan_price") is float or house.loan_price <= 0:
		push_error("Invalid or missing loan_price for house: %s, loan_price=%s" % [house.name, str(house.loan_price)])
		return null
	var mod = add_loan_mod(payment, interest_rate, house.loan_price, term_months, LOAN_TYPE_MORTGAGE, house)
	if not mod or not is_instance_valid(mod):
		push_error("Failed to create loan mod for house: %s, mod=%s" % [house.name, str(mod)])
		return null
	print("add_mortgage_as_loan succeeded for house: %s, mod_id=%s" % [house.name, mod.loan_id])
	return mod

func add_loan_mod(payment: float, interest: float, loan_balance: float, months: int, loan_type: int, house_ref: Node = null) -> Node:
	var mod_scene = load("res://assets/UI/phone/Loans_controll_mod.tscn")
	if not mod_scene:
		push_error("Failed to load Loans_controll_mod.tscn")
		return null
	var mod = mod_scene.instantiate()
	if not mod:
		push_error("Failed to instantiate loan mod scene from %s" % "res://assets/UI/phone/Loans_controll_mod.tscn")
		return null
	if not loan_mod_Container or not is_instance_valid(loan_mod_Container):
		push_error("loan_mod_Container is invalid")
		return null
	loan_mod_Container.add_child(mod)
	if not is_instance_valid(mod):
		return null
	mod.payment = payment
	mod.interest = interest
	mod.loan_balance = loan_balance
	mod.months = months
	mod.loan_type_str = "Mortgage" if loan_type == LOAN_TYPE_MORTGAGE else "Personal"
	mod.house_ref = house_ref
	mod.loan_id = "loan_" + str(randi()) if mod.loan_id.is_empty() else mod.loan_id
	active_loan_mods.append(mod)
	if mod.has_method("update_ui"):
		mod.update_ui()
	return mod

func refresh_active_loan_mods():
	active_loan_mods.clear()
	for child in loan_mod_Container.get_children():
		if child is Control and is_instance_valid(child) and child.has_method("update_ui"):
			active_loan_mods.append(child)

func show_floating_label(text: String, color: Color = Color.WHITE):
	if ui_layer and is_instance_valid(ui_layer):
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.set_position(Vector2(100, 100))
		ui_layer.add_child(label)
		var tween = get_tree().create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5)
		tween.tween_property(label, "modulate:a", 0, 1.5)
		tween.tween_callback(label.queue_free)

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_take_loan_button_pressed() -> void:
	var amount = loan_amount_input.text.to_int()
	var max_loan = 0
	if Globals.credit_score >= 750:
		max_loan = 100000
	elif Globals.credit_score >= 680:
		max_loan = 50000
	elif Globals.credit_score >= 620:
		max_loan = 25000
	elif Globals.credit_score >= 500:
		max_loan = 10000
	elif Globals.credit_score >= 300:
		max_loan = 1000
	if amount > 0 and amount <= max_loan and Globals.credit_score >= 300:
		take_loan(amount)
	else:
		var message = "Credit score too low for loans!"
		if Globals.credit_score >= 300:
			message = "You can borrow up to $" + add_comma_to_int(max_loan) + " based on your credit."
		show_floating_label(message, Color.RED)

func _on_pay_all_payments_pressed() -> void:
	var total_payment = 0
	for mod in active_loan_mods:
		if is_instance_valid(mod):
			total_payment += mod.payment
	if Globals.money >= total_payment:
		for mod in active_loan_mods:
			if is_instance_valid(mod):
				mod._on_make_payment_pressed()
		show_floating_label("Paid all loan payments: $" + add_comma_to_int(int(total_payment)), Color.GREEN)
	else:
		show_floating_label("Not enough money to pay all loans!", Color.RED)

func _on_option_button_item_selected(index: int) -> void:
	var loan_terms = [12, 24, 36, 48, 60]
	if index >= 0 and index < loan_terms.size():
		loan_term = loan_terms[index]
	else:
		loan_term = 12
	update_ui()
