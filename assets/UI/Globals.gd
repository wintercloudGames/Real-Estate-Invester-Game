extends Node

var money = 0
var Propertys = 0
var credit_score = 600
var listed_houses = 0
var first_start = false
var active_loans: Array = []
var save_name: String = "My Save"
var has_car = true
var car_level = 1
var net_worth = 0
var Savings_balance = 0
var last_savings_paid = 0
var market_factor: float = 1.0
var year = 1
var month = 1

var total_loan_amount = 0
var houses_with_tenants = 0
var Income = 0
var Expenses = 0
var cashflow = 0
var save_slot = 1
var send_to_account:bool = false
var Editing_Business_Text:bool= false
var negative_month_count = 0
var wallpaper = ""
var yard_edit = false

var skillpoints: int = 1
var exp: float = 0
var exp_to_level: int = 100
var level: int = 0
# Skills to unlock
var has_hireing_app: bool = false
var has_info_app: bool = false
var has_bank_app: bool = false
var has_manager_app: bool = false
var rent_bost: float = 0.00
var rent_houses: bool = false
var unlock_business: bool = false
var has_market_app:bool = false
var job_manager:bool = false
var job_manager_level:int = 0
var rent_finder_upgrade = false
var Job_bonus = false
var work_bonus = 0.00
var work_amount = 0
var credit_app = false


var difficulty:int = 1

var hasagent = false
var hascleaner = false
var renter_finder = false

func reset():
	money = 0
	Propertys = 0
	credit_score = 600
	year = 1
	car_level = 1
	month = 1
	Savings_balance = 0
	listed_houses = 0
	net_worth = 0
	wallpaper = ""
	total_loan_amount = 0
	houses_with_tenants = 0
	Income = 0
	Expenses = 1000
	cashflow = 0
	first_start = false
	business_name = ""
	Business_worth = 30000
	max_job_time = 0
	job_pay = 0
	job_time = 0
	employees = 0
	hasagent = false
	hascleaner = false
	renter_finder = false
	#skills
	skillpoints = 1
	exp = 0
	exp_to_level = 100
	level = 0
	has_hireing_app = false
	has_info_app = false
	has_bank_app = false
	has_manager_app = false
	rent_bost = 0.00
	rent_houses = false
	unlock_business = false
	has_market_app = false
	job_manager = false
	job_manager_level = 0
	Job_bonus = false
	business_bonus = false
	work_bonus = 0
	work_amount = 0
	rent_finder_upgrade = false
	credit_app = false


#Businessinfo
var business_name = ""
var Business_worth = 0
var employees = 0
var max_job_time = 0
var job_time = 0
var job_pay = 0
var business_bonus = false
#player stats
var Player_health = 100
var Player_hunger = 100
var Player_comfort = 100

var interest_rate = 0.005
var normal_loan_added = false

var interest = Savings_balance * interest_rate
var player_has_employees: bool = false

signal money_in_detect(in_value)
signal money_out_detect(out_value)


func handle_overflow(current_value: float, add_amount: float, max_value: float) -> Dictionary:
	var total = current_value + add_amount
	var overflow = max(0, total - max_value)
	var new_value = total
	
	if overflow > 0:
		new_value = add_amount - overflow  # Reset with the overflow amount
		if new_value < 0:
			new_value = 0
	
	return {
		"new_value": new_value,
		"carryover": overflow,
		"overflowed": overflow > 0
	}

func _process(delta: float) -> void:

	if exp >= exp_to_level:
		var overflow = exp - exp_to_level
		exp = overflow
		skillpoints += 1
		exp_to_level += 10
		level += 1
	
	exp = max(0, exp)

	cashflow = Income - Expenses
	clamp_stats()
	Player_health -= 0.0001
	if year > 50:
		Player_health -= 0.0005
	else:
		Player_health -= 0.0001
	Player_hunger -= 0.0005
	Player_comfort -= 0.0005
	interest = Savings_balance * interest_rate
	credit_score = clamp(credit_score, 300, 850)
	last_savings_paid = interest
	

func monthy():
	money -= Expenses
	if money < 0:
		negative_month_count += 1
		credit_score -= 10
	else:
		negative_month_count = 0
	
	if net_worth > 0:
		var debt_ratio = total_loan_amount / float(net_worth)
		if debt_ratio > 0.8:
			credit_score -= 5  # High debt penalty
		elif debt_ratio < 0.3:
			credit_score += 3  # Low debt bonus
	
	month += 1
	if month >= 12:
		year += 1
		month = 1

	if Savings_balance > 0:
		last_savings_paid = interest
		if send_to_account:
			money += interest
		else:
			Savings_balance += interest
		
	credit_score = clamp(credit_score, 300, 850)  # Ensure score stays in range
		
func money_in(amount):
	money += amount
	emit_signal("money_in_detect",amount)

func money_out(amount):
	money -= amount
	emit_signal("money_out_detect",amount)

func clamp_stats():
	if Player_health > 100:
		Player_health = 100
	if Player_hunger > 100:
		Player_hunger = 100
	if Player_comfort > 100:
		Player_comfort = 100
