extends Control

@onready var SFX = $AudioStreamPlayer
# UI elements
@onready var loan_amount = $HBoxContainer2/loan_amount  # Label
@onready var loan_type = $HBoxContainer2/loan_type      # Label
@onready var paymentdisplay = $HBoxContainer2/payment   # Label
@onready var Intrest = $HBoxContainer2/Intrest          # Label
@onready var Make_payment = $HBoxContainer/Make_payment  # Button
@onready var autopay_toogle = $HBoxContainer/autopay_toogle  # CheckButton
@onready var month_display = $HBoxContainer2/months     # Label
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
	# Connect to the Global signal so we update whenever the month rolls over
	if not Globals.month_ended.is_connected(_on_month_ended):
		Globals.month_ended.connect(_on_month_ended)
		
	# Setup UI visibility
	refinance_button.visible = (loan_type_str == "Mortgage")
	
	if autopay_toogle:
		autopay_toogle.button_pressed = autopay_enabled
		
	# Connect base hover sounds dynamically to the buttons on load
	_connect_hover_sounds()
	
	update_ui()
	Globals.recalculate_expenses()
	
	# Validation safety check
	await get_tree().create_timer(2).timeout
	_validate_loan_integrity()

# Helper to automatically apply hover sounds to all buttons in this module
func _connect_hover_sounds() -> void:
	var buttons = [Make_payment, refinance_button, payoff_button, autopay_toogle]
	for btn in buttons:
		if is_instance_valid(btn) and not btn.mouse_entered.is_connected(_on_button_hovered):
			btn.mouse_entered.connect(_on_button_hovered)

func _on_button_hovered() -> void:
	SFX.play_sound("hover")

func _validate_loan_integrity() -> void:
	if loan_type_str == "Mortgage":
		if house_ref == null or not is_instance_valid(house_ref):
			print("ERROR: No Loan House ID. Orphaned mortgage loan self-destructing.")
			_self_destruct()

func update_ui() -> void:
	if loan_amount: loan_amount.text = "Balance: $" + add_comma_to_int(int(loan_balance))
	if loan_type: loan_type.text = "Type: " + loan_type_str
	if paymentdisplay: paymentdisplay.text = "Payment: $" + add_comma_to_int(int(payment))
	if Intrest: Intrest.text = "Interest: %.1f%%" % (interest * 100.0)
	if month_display: month_display.text = "Months: " + str(months)
	
	if loan_type_str == "Mortgage" and (house_ref == null or not is_instance_valid(house_ref)):
		_self_destruct()

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end = 1 if value < 0 else 0
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

# --- MONTHLY PROCESSING ---

func _on_month_ended():
	if autopay_enabled:
		process_loan_reduction()
	else:
		Globals.notify("MISSED PAYMENT: %s" % loan_type_str, Color.ORANGE)
		Globals.credit_score -= 10
		
		# Unpaid interest penalty sound
		SFX.play_sound("error", 0.8)
		
		var monthly_interest_rate = interest / 12.0
		var interest_charge = loan_balance * monthly_interest_rate
		loan_balance += interest_charge
		
		update_ui()

func _on_make_payment_pressed(is_manual: bool = true) -> void:
	if Globals.money < payment:
		if is_manual:
			Globals.notify("Need $%s!" % add_comma_to_int(int(payment)), Color.RED)
			SFX.play_sound("error") # Financial rejection sound
		return
	SFX.play_sound("success",0.8)
	Globals.money -= payment
	process_loan_reduction()
	
	if is_manual:
		Globals.notify("Extra Payment: -$" + add_comma_to_int(int(payment)), Color.CYAN)
		SFX.play_sound("click", 1.1) # Extra payment high-pitch confirmation
		Globals.credit_score += 1

func process_loan_reduction():
	var monthly_interest_rate = interest / 12.0
	var interest_charge = loan_balance * monthly_interest_rate
	var principal_reduction = payment - interest_charge
	
	loan_balance -= principal_reduction
	months -= 1
	Globals.credit_score += 2
	
	if is_instance_valid(house_ref):
		house_ref.loan_price = loan_balance
	
	if loan_balance <= 0 or months <= 0:
		_complete_loan()
	else:
		update_ui()
		Globals.recalculate_expenses()

func _complete_loan():
	loan_balance = 0
	months = 0
	if is_instance_valid(house_ref):
		house_ref.has_loan = false
		house_ref.loan_price = 0
	
	Globals.notify("LOAN PAID OFF!", Color.GOLD)
	SFX.play_sound("success", 1.3) # Mega-rewarding loan payoff chime!
	_self_destruct()

# --- BUTTON ACTIONS ---

func _on_autopay_toggled(toggled: bool) -> void:
	autopay_enabled = toggled
	Globals.recalculate_expenses()
	update_ui()
	SFX.play_sound("click", 0.95 if toggled else 0.85) # Alternates toggle pitch

func _on_payoff_pressed() -> void:
	if Globals.money >= loan_balance:
		Globals.money -= loan_balance
		Globals.notify("Loan fully settled!", Color.GREEN)
		_complete_loan()
	else:
		Globals.notify("Need $%s to payoff!" % add_comma_to_int(int(loan_balance)), Color.RED)
		SFX.play_sound("error")

func _on_refinance_pressed() -> void:
	var current_market_rate = 0.05 
	if loans_ui and loans_ui.has_method("get_base_rate_from_credit"):
		current_market_rate = loans_ui.get_base_rate_from_credit()
	
	if current_market_rate >= interest:
		Globals.notify("Market rates aren't better!", Color.ORANGE)
		SFX.play_sound("error", 0.9)
		return

	var fee = loan_balance * 0.02
	if Globals.money < fee:
		Globals.notify("Refinance Fee: $%s" % add_comma_to_int(int(fee)), Color.RED)
		SFX.play_sound("error")
		return

	Globals.money -= fee
	interest = current_market_rate
	months = 360 # Reset to 30 years
	payment = calculate_mortgage_payment(loan_balance, months, interest)
	
	Globals.notify("Refinanced to %.1f%%" % (interest * 100), Color.GREEN)
	SFX.play_sound("success", 1.1) # Upgraded premium interest chime
	update_ui()
	Globals.recalculate_expenses()

func calculate_mortgage_payment(p_amount: float, p_months: int, p_rate: float) -> float:
	if p_months <= 0: return 0.0
	if p_rate == 0: return p_amount / p_months
	var m_rate = p_rate / 12.0
	return p_amount * (m_rate * pow(1 + m_rate, p_months)) / (pow(1 + m_rate, p_months) - 1)

func _self_destruct():
	if loans_ui and loans_ui.get("active_loan_mods") and loans_ui.active_loan_mods.has(self):
		loans_ui.active_loan_mods.erase(self)
	
	if Globals.month_ended.is_connected(_on_month_ended):
		Globals.month_ended.disconnect(_on_month_ended)
		
	queue_free()
	Globals.recalculate_expenses()
