extends Control

@onready var ui_layer = $"../.."  # HUD reference

# Savings system
@onready var savings_amount_input: LineEdit = $TabContainer/Add_to_Savings/SavingsAmountInput
@onready var remove_funds_button: Button = $TabContainer/Add_to_Savings/RemoveFundsButton
@onready var deposit_funds_button: Button = $TabContainer/Add_to_Savings/DepositFundsButton
@onready var savings_balance_label: Label = $TabContainer/Savings/SavingsBalanceLabel
@onready var intrest_payment_label: Label = $TabContainer/Savings/IntrestPaymentLabel
@onready var savings_balance_label2: Label = $TabContainer/Add_to_Savings/SavingsBalanceDisplay

const INTEREST_RATE = 0.05  # Default 5% per month for savings
const LOAN_TERM = 12  # 12 months to repay loans

func _ready():
	deposit_funds_button.pressed.connect(_on_deposit_funds)
	remove_funds_button.pressed.connect(_on_remove_funds)

func _process(delta: float) -> void:
	update_ui()

func update_ui():
	savings_balance_label.text = "$" + add_comma_to_int(Globals.Savings_balance)
	savings_balance_label2.text = "$" + add_comma_to_int(Globals.Savings_balance)
	intrest_payment_label.text = "0.5% Interest Rate\nMonthly Interest Paid: $" + add_comma_to_int(Globals.last_savings_paid)

func _on_remove_funds():
	var amount = savings_amount_input.text.to_int()
	if amount > 0 and Globals.Savings_balance >= amount:
		remove_savings(amount)
	else:
		Globals.notify("Insufficient savings or invalid amount!", Color.RED)

func _on_deposit_funds():
	var amount = savings_amount_input.text.to_int()
	if amount > 0 and Globals.money >= amount:
		deposit_savings(amount)
	else:
		Globals.notify("Insufficient funds or invalid amount!", Color.RED)

func remove_savings(amount: int):
	Globals.money += amount  # Add to cash
	Globals.Savings_balance -= amount  # Remove from savings
	Globals.notify("Took Out $" + add_comma_to_int(amount) + " From Savings", Color.RED)

func deposit_savings(amount: int):
	Globals.money -= amount  # Remove from cash
	Globals.Savings_balance += amount  # Add to savings

	Globals.notify("Deposited $" + add_comma_to_int(amount) + " to Savings", Color.GREEN)


func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_remove_all_funds_button_pressed() -> void:
	if Globals.Savings_balance > 0:
		remove_savings(Globals.Savings_balance)
	else:
		Globals.notify("No savings to withdraw!", Color.RED)

func _on_send_intrest_to_toggled(toggled_on: bool) -> void:
	Globals.send_to_account = toggled_on
	if toggled_on:
		$TabContainer/Savings/Send_intrest_to.text = "Send Interest To Account"
	else:
		$TabContainer/Savings/Send_intrest_to.text = "Keep Compounded"
