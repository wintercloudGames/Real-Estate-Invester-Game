extends Control

@onready var market: Node = $"../../Market"
@onready var loans_ui: Node = $"../Phone/Loans"

func start():
	market.difficulty = Globals.difficulty
	market.apply_difficulty_settings()
	market.update_label()
	$"../Business_UI".Set_difficulty()
	$"../Phone/Car_info".car_level = 1
	visible = false
	Globals.first_start = true
	SaveAndLoad.save_game()

func calculate_loan_amount_for_payment(target_payment: float, months: int, interest_rate: float) -> float:
	if months <= 0 or target_payment <= 0 or interest_rate < 0:
		push_error("Invalid loan parameters: payment=%s, months=%s, interest_rate=%s" % [target_payment, months, interest_rate])
		return 0.0
	var monthly_rate = interest_rate / 12.0
	var loan_amount = target_payment * (pow(1 + monthly_rate, months) - 1) / (monthly_rate * pow(1 + monthly_rate, months))
	return loan_amount

func add_starter_loan() -> void:
	if not loans_ui or not is_instance_valid(loans_ui):
		push_error("Loans UI node not found or invalid")
		return
	
	var target_payment: float
	var loan_term: int = 24  # Changed to 24-month term
	var credit_score: int
	var interest_rate: float
	
	match Globals.difficulty:
		0:  # Easy
			target_payment = 100.0
			credit_score = 700
			interest_rate = 0.08  # From loans.gd for credit_score >= 680
		1:  # Normal
			target_payment = 500.0
			credit_score = 600
			interest_rate = 0.10  # From loans.gd for credit_score >= 620
		2:  # Hard
			target_payment = 1000.0
			credit_score = 400
			interest_rate = 0.12  # From loans.gd for credit_score < 620
		3:  # Nightmare
			target_payment = 1500.0
			credit_score = 300
			interest_rate = 0.12  # From loans.gd for credit_score < 620
		_:
			push_error("Invalid difficulty: %s" % Globals.difficulty)
			return
	
	Globals.credit_score = credit_score
	var loan_amount = calculate_loan_amount_for_payment(target_payment, loan_term, interest_rate)
	
	if loan_amount <= 0:
		push_error("Calculated loan amount invalid: %s" % loan_amount)
		return
	
	# Create the loan using add_loan_mod directly to set exact payment
	var loan_mod = loans_ui.add_loan_mod(target_payment, interest_rate, loan_amount, loan_term, loans_ui.LOAN_TYPE_PERSONAL, null)
	if loan_mod and is_instance_valid(loan_mod):
		Globals.exp += 10
		Globals.money += int(loan_amount)
		Globals.credit_score = clamp(Globals.credit_score - 5, 300, 850)
		loans_ui.show_floating_label("Starter Loan of $" + loans_ui.add_comma_to_int(int(loan_amount)) + " approved at " + str(interest_rate * 100) + "% interest!", Color.GREEN)
		loans_ui.update_ui()
	else:
		push_error("Failed to create starter loan mod")

func _on_easy_button_pressed() -> void:
	Globals.difficulty = 0
	start()
	add_starter_loan()

func _on_normal_button_pressed() -> void:
	Globals.difficulty = 1
	start()
	add_starter_loan()
	Globals.money -= 5000

func _on_hard_button_pressed() -> void:
	Globals.difficulty = 2
	start()
	add_starter_loan()
	Globals.money -= 20000

func _on_nightmare_button_pressed() -> void:
	Globals.difficulty = 3
	start()
	add_starter_loan()
	Globals.money -= 24000
