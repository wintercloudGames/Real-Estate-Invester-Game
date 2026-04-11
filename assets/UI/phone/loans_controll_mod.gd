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

@export var loan_balance: float = 0.0  
@export var months: int = 0            
@export var payment: float = 0.0       
@export var interest: float = 0.0      
@export var loan_id: String = ""       
@export var loan_type_str: String = "" 
var autopay_enabled: bool = true 
var house_ref: Node = null   

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
	
	# FIX: Use string formatting to show decimals (e.g., 5.0% or 12.25%)
	if Intrest: 
		Intrest.text = "Interest: %.1f%%" % (interest * 100.0)
	if month_display: month_display.text = "Months: " + str(months)
	if autopay_toogle:
		autopay_toogle.text = "Enable Autopay: " + str(autopay_enabled)
	
	if loan_type_str == "Mortgage"and house_ref == null:
		queue_free()
	if loan_type_str == "Mortgage" and not is_instance_valid(house_ref):
		print("House no longer exists, removing mortgage module.")
		if loans_ui and loans_ui.active_loan_mods.has(self):
			loans_ui.active_loan_mods.erase(self)
		queue_free()
	
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_make_payment_pressed() -> void:
	if Globals.money < payment:
		show_floating_label("Need $%s!" % add_comma_to_int(int(payment)), Color.RED)
		return
	Globals.credit_score += 2
	var interest_payment = loan_balance * (interest / 12.0)
	var principal_payment = payment - interest_payment
	
	loan_balance -= principal_payment
	Globals.money -= principal_payment
	months -= 1
	if is_instance_valid(house_ref):
		house_ref.loan_price = loan_balance
	else:
		# If the house is gone but this is a mortgage, the loan should probably vanish
		if loan_type_str == "Mortgage":
			queue_free()
			return
	
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
			var tween = create_tween()
			tween.tween_property(self, "modulate:a", 0, 0.5)
			tween.tween_callback(queue_free)
			show_floating_label("LOAN PAID OFF!", Color.GOLD)
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
	if autopay_enabled:
		if Globals.money >= payment:
			_on_make_payment_pressed()
		else:
			show_floating_label("Autopay Failed: Insufficient Funds", Color.RED)
			Globals.credit_score = clamp(Globals.credit_score - 10, 300, 850)
	else:
		show_floating_label("Loan Payment Due!", Color.YELLOW)

func _on_refinance_pressed() -> void:
	# 1. Get the current market rate from the main UI script
	var current_market_rate = 0.05 # Default fallback
	if loans_ui and loans_ui.has_method("get_base_rate_from_credit"):
		var heat = loans_ui.get_market_heat()
		current_market_rate = loans_ui.get_base_rate_from_credit() * heat

	# 2. Only allow if the new rate is actually better
	if current_market_rate >= interest:
		show_floating_label("Market rates are too high to refinance!", Color.ORANGE)
		return

	# 3. Apply a "Refinance Fee" (e.g., 2% of balance)
	var fee = loan_balance * 0.02
	if Globals.money < fee:
		show_floating_label("Need $%s for Refinance Fee!" % add_comma_to_int(int(fee)), Color.RED)
		return

	Globals.money_out(fee)
	interest = current_market_rate
	# Reset term or keep current months? Usually, people reset to 360 (30 years)
	months = 360 
	payment = calculate_mortgage_payment(loan_balance, months, interest)
	
	update_ui()
	show_floating_label("Refinanced to %.1f%%!" % (interest * 100), Color.GREEN)

func _on_payoff_pressed() -> void:
	if Globals.money >= loan_balance:
		Globals.money_out(loan_balance)
		Globals.exp += 5 * Globals.exp_boost # Bonus exp for paying off loan
		Globals.credit_score = clamp(Globals.credit_score - 10, 300, 850)
		
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
