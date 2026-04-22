extends Control

@onready var ui_layer = $".."
@onready var job_offer_timer: Timer = $JobOfferTimer
@onready var job_container: VBoxContainer = $TabContainer/Manager/ScrollContainer/Job_mod_Container

var business_name: String = ""
var salary: int = 0
var employees: int = 0
var job_time: float = 0.0
var max_job_time: float = 0.0
var job_pay_when_done: int = 0
var business_worth: int = 30000
var startup_cost: int = 10000
var expense: int = 1000

var BASE_SALARY := 4000
var MAX_JOB_TIME := 48
var TIER_INCREMENT := 50000
var BASE_PAYMENT := 80000

const TIER_EMPLOYEES := {
	1: 3, 2: 5, 3: 7, 4: 10, 5: 12,
	6: 15, 7: 18, 8: 20, 9: 25, 10: 30
}

signal business_started(business_name)
signal business_sold(business_worth)
signal job_completed(payment, success)
signal employee_changed(count)

func _ready() -> void:
	if Globals.has_signal("month_ended"):
		Globals.month_ended.connect(_on_month_passed)
	
	job_offer_timer.timeout.connect(_update_jobs)
	
	if Globals.business_name:
		load_business(Globals.business_name)
	
	Set_difficulty()

func Load_info() -> void:
	load_business(Globals.business_name)
	business_name = Globals.business_name
	employees = Globals.employees
	salary = BASE_SALARY * employees
	business_worth = Globals.Business_worth
	job_time = Globals.job_time
	max_job_time = Globals.max_job_time
	job_pay_when_done = Globals.job_pay
	Globals.recalculate_expenses()
	
	if Globals.job_manager == true:
		$TabContainer/Job_info/Find_jobs_button.visible = false

func Set_difficulty() -> void:
	match Globals.difficulty:
		0:
			startup_cost = 12500
			expense = 2500
			TIER_INCREMENT = 25000
			BASE_SALARY = 1000
			BASE_PAYMENT = 320000
		1:
			startup_cost = 16667
			expense = 3333
			TIER_INCREMENT = 33333
			BASE_SALARY = 2000
			BASE_PAYMENT = 240000
		2:
			startup_cost = 25000
			expense = 5000
			TIER_INCREMENT = 50000
			BASE_SALARY = 3000
			BASE_PAYMENT = 160000
		3:
			startup_cost = 50000
			expense = 10000
			TIER_INCREMENT = 100000
			BASE_SALARY = 4000
			BASE_PAYMENT = 80000

func _process(delta: float) -> void:
	_update_ui()
	_process_job_progress(delta)
	
	if Globals.job_manager == true and job_offer_timer.is_stopped():
		if job_container.get_child_count() < Globals.job_manager_level + 2:
			job_offer_timer.start(randf_range(5.0, 15.0))

func _update_ui() -> void:
	$TabContainer/employees/Employee_count.text = "Workers: " + str(employees)
	$TabContainer/employees/Employee_cost.text = "Monthly Payroll: $" + add_comma_to_int(salary)
	$TabContainer/info/Business_worth.text = "Business Worth: $" + add_comma_to_int(business_worth)
	$TabContainer/Job_info/job_pay_when_done.text = "Payout: $" + add_comma_to_int(job_pay_when_done)
	
	var efficiency = (sqrt(employees) / employees) * 100 if employees > 0 else 100.0
	if has_node("TabContainer/employees/Efficiency_Bar"):
		$TabContainer/employees/Efficiency_Bar.value = efficiency
	
	var is_working = max_job_time > 0.0
	$TabContainer/Job_info/stop_job_button.visible = is_working
	$TabContainer/Job_info/Find_jobs_button.visible = not is_working and not Globals.job_manager

	var current_tier = clamp(floor(business_worth / TIER_INCREMENT), 1, 10)
	var max_emp = TIER_EMPLOYEES.get(current_tier, 100)
	$TabContainer/info/TierLabel.text = "Tier %d | Max Staff: %d" % [current_tier, max_emp]

func _on_month_passed() -> void:
	if employees > 0:
		pay_salaries()
	
	var depreciation = int(business_worth * 0.01)
	business_worth = max(expense, business_worth - depreciation)
	Globals.Business_worth = business_worth

func pay_salaries() -> void:
	var monthly_cost = salary
	if job_pay_when_done > 0:
		var deduction = min(monthly_cost, job_pay_when_done)
		job_pay_when_done -= deduction
		monthly_cost -= deduction
	
	if monthly_cost > 0:
		Globals.money -= monthly_cost
		Globals.notify("Paid Salaries: -$" + add_comma_to_int(salary), Color.TOMATO)

func _process_job_progress(delta: float) -> void:
	if max_job_time > 0.0 and job_time > 0.0:
		var worker_efficiency = sqrt(employees) if employees > 0 else 0.1
		var progress_rate = (worker_efficiency * delta) / 90.0
		
		job_time = max(0.0, job_time - progress_rate)
		
		var progress = (1.0 - job_time / max_job_time) * 100.0
		$TabContainer/Job_info/ProgressBar.value = progress
		$ProgressBar.value = progress

		if job_time <= 0.0:
			_complete_job()

func _complete_job() -> void:
	Globals.money += job_pay_when_done
	business_worth += job_pay_when_done / (25 if Globals.business_bonus else 50)
	Globals.Business_worth = business_worth
	Globals.notify("Job Complete: +$" + add_comma_to_int(job_pay_when_done), Color.CHARTREUSE)
	job_completed.emit(job_pay_when_done, true)
	_reset_job()

func _reset_job() -> void:
	job_pay_when_done = 0
	max_job_time = 0
	job_time = 0
	$TabContainer/Job_info/ProgressBar.value = 0
	$ProgressBar.value = 0

func start_business(name: String) -> void:
	if name.is_empty():
		Globals.notify("Business Name Can't Be Blank", Color.RED)
		return
	if Globals.money < startup_cost:
		Globals.notify("Not enough money", Color.RED)
		return
	
	Globals.money -= startup_cost
	business_name = name
	Globals.business_name = name
	$TabContainer/info/Business_name.text = name + "'s Info"
	$Start_Business.visible = false
	$TabContainer.visible = true
	$ProgressBar.visible = true
	business_worth = 10000
	Globals.notify("Business Started!", Color.GREEN)

func _on_start_a_business_button_pressed() -> void:
	start_business($Start_Business/Name_of_Business.text)

func _on_name_of_business_text_changed(new_text: String) -> void:
	business_name = new_text

func _on_name_of_business_focus_entered() -> void:
	Globals.Editing_Business_Text = true

func _on_name_of_business_focus_exited() -> void:
	Globals.Editing_Business_Text = false

func _on_find_jobs_button_pressed() -> void:
	$TabContainer/Job_info/Find_jobs_button.disabled = true
	job_offer_timer.start(randf_range(2.0, 5.0))

func _update_jobs() -> void:
	var duration = _get_random_job_duration()
	var tier = clamp(floor(business_worth / TIER_INCREMENT), 1, 10)
	var base_pay = _calculate_tier_payment(tier)
	
	var market = 1.0
	var market_node = get_node_or_null("../../Market")
	if market_node and market_node.has_method("get_market_condition"):
		market = market_node.get_market_condition()
	
	var multiplier = _calculate_random_payment_multiplier(duration, market)
	var final_pay = roundi(base_pay * multiplier)
	
	if Globals.job_manager:
		add_job_mod(final_pay, duration)
	else:
		_show_job_offer(final_pay, duration)
		$TabContainer/Job_info/Find_jobs_button.disabled = false
	
	job_offer_timer.stop()

func _show_job_offer(pay: int, time: int) -> void:
	var worker_eff = sqrt(employees) if employees > 0 else 0.1
	var net = pay - (salary * (time / worker_eff))
	
	var offer_ui = $"../Job_offer_ui"
	offer_ui.visible = true
	offer_ui.get_node("job_pay").text = "Revenue: $" + add_comma_to_int(pay)
	offer_ui.get_node("job_time").text = "Length: %d Months" % time
	
	if offer_ui.has_node("profit_breakdown"):
		var info = offer_ui.get_node("profit_breakdown")
		info.text = "Est. Net: $" + add_comma_to_int(int(net))
		info.modulate = Color.CHARTREUSE if net > 0 else Color.TOMATO
	
	var take_btn = offer_ui.get_node("take_job")
	if take_btn.pressed.is_connected(_on_take_job_pressed):
		take_btn.pressed.disconnect(_on_take_job_pressed)
	take_btn.pressed.connect(_on_take_job_pressed.bind(pay, time))

func _on_take_job_pressed(p: int, t: int) -> void:
	max_job_time = t
	job_time = t
	job_pay_when_done = p
	$"../Job_offer_ui".visible = false

func _on_stop_job_button_pressed() -> void:
	_reset_job()
	Globals.notify("Job Cancelled", Color.ORANGE)

func _on_add_employee_pressed() -> void:
	var tier = clamp(floor(business_worth / TIER_INCREMENT), 1, 10)
	if employees >= TIER_EMPLOYEES.get(tier, 100):
		Globals.notify("Tier Limit Reached!", Color.RED)
		return
	
	employees += 1
	salary += int(BASE_SALARY * (1.0 + (tier * 0.1)))
	Globals.employees = employees

func _on_remove_employee_pressed() -> void:
	if employees <= 0: return
	employees -= 1
	salary = max(0, salary - BASE_SALARY)
	Globals.employees = employees

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end = 1 if value < 0 else 0
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _get_random_job_duration() -> int:
	var r = randf()
	if r < 0.3: return randi_range(1, 3)
	if r < 0.7: return randi_range(4, 8)
	return randi_range(9, MAX_JOB_TIME)

func _calculate_tier_payment(tier: int) -> int:
	return roundi(BASE_PAYMENT * (1.0 + (tier - 1) * 0.8))

func _calculate_random_payment_multiplier(dur: int, mkt: float) -> float:
	return (1.0 - (0.02 * max(0, dur - 5))) * mkt * randf_range(0.9, 1.1)

func load_business(name: String) -> void:
	business_name = name
	$TabContainer/info/Business_name.text = name + "'s Info"
	$Start_Business.visible = false
	$TabContainer.visible = true

func add_job_mod(payment: int, time: int) -> void:
	var mod_scene = preload("res://assets/UI/job_offer_mod.tscn")
	var mod_instance = mod_scene.instantiate()
	mod_instance.job_pay = payment
	mod_instance.job_time = time
	job_container.add_child(mod_instance)

func _on_sell_business_button_pressed() -> void:
	Globals.money += business_worth
	business_name = ""
	employees = 0
	salary = 0
	business_worth = 0
	_reset_job()
	$TabContainer.visible = false
	$Start_Business.visible = true

func _on_close_button_pressed() -> void:
	hide()
