extends Control

# UI elements
@onready var loan_amount = $HBoxContainer2/loan_amount  # Label
@onready var loan_type = $HBoxContainer2/loan_type      # Label
@onready var paymentdisplay = $HBoxContainer2/payment   # Label
@onready var Intrest = $HBoxContainer2/Intrest          # Label
@onready var Make_payment = $HBoxContainer/Make_payment  # Button
@onready var autopay_toogle = $HBoxContainer/autopay_toogle  # CheckButton
@onready var month_display = $HBoxContainer2/months     # Label
@onready var timer = $Timer
@onready var refinance_button = $HBoxContainer/RefinanceButton  # Button
@onready var payoff_button = $HBoxContainer/PayoffButton       # Button
@onready var loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")

const LOAN_TYPE_MORTGAGE: int = 0
const LOAN_TYPE_PERSONAL: int = 1

@export var loan_balance: float = 0.0  # Current balance
@export var months: int = 0            # Remaining months
@export var payment: float = 0.0       # Monthly payment
@export var interest: float = 0.0      # Annual interest rate (e.g., 0.06 for 6%)
@export var loan_id: String = ""       # Unique ID (e.g., "personal_123" or "mortgage_houseX")
@export var loan_type_str: String = "" # "Personal" or "Mortgage"
var autopay_enabled: bool = true  # Default to true
var house_ref: Node = null     # For mortgages, reference to house node

func _ready() -> void:
	Globals.recalculate_expenses()
	# Check for null nodes
	if not loan_amount or not loan_type or not paymentdisplay or not Intrest or not month_display or not Make_payment or not autopay_toogle or not timer or not refinance_button or not payoff_button or not loans_ui:
		push_error("One or more nodes are null in Loan_controll_mod.tscn. Check node paths.")
		return
	if loan_type_str == "Mortgage":
		refinance_button.visible = true
	else:
		refinance_button.visible = false
	# Timer for autopay
	timer.wait_time = 60.0  # 60 seconds
	timer.start()
	# Initialize UI
	update_ui()
	
	# Set autopay toggle initial state
	if autopay_toogle:
		autopay_toogle.button_pressed = autopay_enabled
		autopay_toogle.text = "Enable Autopay: " + str(autopay_enabled) 

func update_ui() -> void:
	if loan_amount: loan_amount.text = "Balance: $" + add_comma_to_int(int(loan_balance))
	if loan_type: loan_type.text = "Type: " + loan_type_str
	if paymentdisplay: paymentdisplay.text = "Payment: $" + add_comma_to_int(int(payment))
	if Intrest: Intrest.text = "Interest: " + str(int(interest * 100)) + "%"
	if month_display: month_display.text = "Months: " + add_comma_to_int(int(months))
	if autopay_toogle:
		autopay_toogle.text = "Enable Autopay: " + str(autopay_enabled)
	

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_make_payment_pressed() -> void:
	if not Make_payment or Globals.money < payment:
		show_floating_label("Need $%s for payment!" % add_comma_to_int(int(payment)), Color.RED)
		return
	Globals.exp += 1
	Globals.money_out(payment)
	var interest_payment = loan_balance * (interest / 12.0)
	var principal_payment = payment - interest_payment
	loan_balance -= principal_payment
	months -= 1
	Globals.credit_score = clamp(Globals.credit_score + 2, 300, 850)
	
	
	if loan_type_str == "Mortgage" and house_ref and is_instance_valid(house_ref):
		house_ref.loan_price = loan_balance
		house_ref.mortgage = payment if loan_balance > 0 else 0
		if house_ref.has_method("set_remaining_months"):
			house_ref.set_remaining_months(months)
	
	if loan_balance <= 0 or months <= 0:
		loan_balance = 0
		months = 0
		payment = 0
		if house_ref and is_instance_valid(house_ref):
			house_ref.loan_price = 0
			house_ref.mortgage = 0
			house_ref.has_loan = false
		if loans_ui and is_instance_valid(loans_ui) and loans_ui.active_loan_mods.has(self):
			loans_ui.active_loan_mods.erase(self)
			queue_free()
	update_ui()
	SaveAndLoad.save_game()
	
	var ui_layer = get_node("/root/Root/UserInterface/Game/HUD")
	if ui_layer and is_instance_valid(ui_layer):
		var label = Label.new()
	show_floating_label("Paid $" + add_comma_to_int(int(payment)),Color.GREEN)
	Globals.recalculate_expenses()

func _on_autopay_toggled(toggled: bool) -> void:
	autopay_enabled = toggled
	if loan_type_str == "Mortgage" and house_ref and is_instance_valid(house_ref):
		if house_ref.has_method("set_autopay_enabled"):
			house_ref.set_autopay_enabled(toggled)
	if toggled:
		Globals.recalculate_expenses()
	update_ui()


func _on_timer_timeout() -> void:
	if autopay_enabled and Globals.money >= payment:
		_on_make_payment_pressed()
	elif autopay_enabled and Globals.money < payment:
		show_floating_label("Missed Loan Payment: Insufficient Funds", Color.RED)
		Globals.exp += 1
		Globals.credit_score = clamp(Globals.credit_score - 5, 300, 850)
	elif !autopay_enabled:
		Globals.exp += 1
		show_floating_label("Missed Loan Payment", Color.RED)
		Globals.credit_score = clamp(Globals.credit_score - 5, 300, 850)

func _on_refinance_pressed() -> void:
	if not house_ref or not is_instance_valid(house_ref):
		push_warning("Cannot refinance: no valid house reference for loan %s" % loan_id)
		show_floating_label("No house to refinance!", Color.RED)
		return
	var new_months: int = 360 # Adjust via UI if needed
	var new_interest: float = interest - 0.01 if interest > 0.01 else interest
	var new_payment = calculate_mortgage_payment(loan_balance, new_months, new_interest)

	months = new_months
	interest = new_interest
	payment = new_payment
	if house_ref and is_instance_valid(house_ref):
		house_ref.mortgage = int(new_payment)
		house_ref.loan_price = int(loan_balance)
		house_ref.has_loan = true
		if house_ref.has_method("set_remaining_months"):
			house_ref.set_remaining_months(new_months)
		if house_ref.has_method("set_house_UI"):
			house_ref.set_house_UI()

	update_ui()
	SaveAndLoad.save_game()
	Globals.recalculate_expenses()
	show_floating_label("Refinanced loan to $%s/month" % add_comma_to_int(int(new_payment)), Color.GREEN)

func _on_payoff_pressed() -> void:
	if Globals.money >= loan_balance:
		Globals.money_out(loan_balance)
		Globals.exp += 5 # Bonus exp for paying off loan
		Globals.credit_score = clamp(Globals.credit_score + 10, 300, 850)
		
		if house_ref and is_instance_valid(house_ref):
			house_ref.has_loan = false
			house_ref.loan_price = 0.0
			house_ref.mortgage = 0.0
			if house_ref.has_method("set_remaining_months"):
				house_ref.set_remaining_months(0)
			if house_ref.has_method("set_house_UI"):
				house_ref.set_house_UI()
			
		if loans_ui and is_instance_valid(loans_ui) and loans_ui.active_loan_mods.has(self):
			loans_ui.active_loan_mods.erase(self)
			queue_free()
		update_ui()
		show_floating_label("Loan paid off!", Color.GREEN)
	else:
		push_warning("Insufficient funds to pay off loan: id=%s, balance=%s, money=%s" % [loan_id, loan_balance, Globals.money])
		show_floating_label("Need $%s to pay off!" % add_comma_to_int(int(loan_balance)), Color.RED)
	Globals.recalculate_expenses()

func calculate_mortgage_payment(loan_amount: float, months: int, interest_rate: float) -> float:
	if months <= 0 or loan_amount <= 0 or interest_rate < 0:
		push_error("Invalid mortgage parameters: loan_amount=%s, months=%s, interest_rate=%s" % [loan_amount, months, interest_rate])
		return 0.0
	var monthly_rate = interest_rate / 12.0
	var payment = loan_amount * (monthly_rate * pow(1 + monthly_rate, months)) / (pow(1 + monthly_rate, months) - 1)
	return payment

func show_floating_label(text: String, color: Color = Color.WHITE) -> void:
	var ui_layer = get_node("/root/Root/UserInterface/Game/HUD")
	if ui_layer and is_instance_valid(ui_layer):
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.set_anchors_preset(Control.PRESET_CENTER)  # Anchor to screen center
		# Set initial position to the center of the screen
		var screen_size = get_viewport().size
		label.position = screen_size / 2
		ui_layer.add_child(label)
		var tween = get_tree().create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5)  # Move up 50 pixels
		tween.tween_property(label, "modulate:a", 0, 1.5)  # Fade out
		tween.tween_callback(label.queue_free)
