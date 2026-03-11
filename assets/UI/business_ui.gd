extends Control

@onready var ui_layer = $".."  # HUD reference
@onready var salary_timer: Timer = $Timers/SalaryTimer
@onready var job_offer_timer: Timer = $Timers/JobOfferTimer
@onready var job_container: VBoxContainer = $TabContainer/Manager/ScrollContainer/Job_mod_Container

# Business Data
var business_name: String = ""
var category: String = ""
var salary: int = 0  # Monthly salary cost
var employees: int = 0  # Number of employees
var job_time: float = 0.0  # Remaining job time in months
var max_job_time: float = 0.0  # Total job time
var job_payment: int = 0  # Payment for the job
var job_pay_when_done: int = 0
var business_worth: int = 30000
var startup_cost: int = 10000
var expense: int = 1000

# Configurable job offer delay
var months_between_offers: float = randf_range(1, 3)  # Job offers appear every 1-3 in-game months

# Constants
var BASE_SALARY := 4000
var MIN_JOB_TIME := 1
var MAX_JOB_TIME := 48
var TIER_INCREMENT := 50000
var BASE_PAYMENT := 80000

# Tier to max employees mapping
const TIER_EMPLOYEES := {
	1: 3, 2: 5, 3: 7, 4: 10, 5: 12,
	6: 15, 7: 18, 8: 20, 9: 25, 10: 30
}

# Signals
signal business_started(business_name)
signal business_sold(business_worth)
signal job_accepted(payment, time)
signal job_completed(payment, success)
signal employee_changed(count)

func _ready() -> void:
	# Set up salary deduction timer (acts as in-game months)
	salary_timer.wait_time = 60.0  # Each in-game month is 60 real-world seconds
	salary_timer.autostart = true
	salary_timer.timeout.connect(_on_month_passed)
	
	job_offer_timer.wait_time = months_between_offers
	job_offer_timer.timeout.connect(_update_jobs)
	
	# Load business if it exists
	if Globals.business_name:
		load_business(Globals.business_name)

func Load_info() -> void:
	load_business(Globals.business_name)
	business_name = Globals.business_name
	employees = Globals.employees
	salary += BASE_SALARY * employees
	business_worth = Globals.Business_worth
	job_time = Globals.job_time
	max_job_time = Globals.max_job_time
	job_pay_when_done = Globals.job_pay
	Globals.recalculate_expenses()
	if Globals.job_manager == true:
		$TabContainer/Job_info/Find_jobs_button.visible = false

func Set_difficulty() -> void:
	match Globals.difficulty:
		0: # Easy
			startup_cost = 12500
			expense = 2500
			business_worth = 7500
			TIER_INCREMENT = 25000
			BASE_SALARY = 1000
			BASE_PAYMENT = 320000
		1: # Normal
			startup_cost = 16667
			expense = 3333
			business_worth = 10000
			TIER_INCREMENT = 33333
			BASE_SALARY = 2000
			BASE_PAYMENT = 240000
		2: # Hard
			startup_cost = 25000
			expense = 5000
			business_worth = 15000
			TIER_INCREMENT = 50000
			BASE_SALARY = 3000
			BASE_PAYMENT = 160000
		3: # INSANE
			startup_cost = 50000
			expense = 10000
			business_worth = 30000
			BASE_SALARY = 4000
			BASE_PAYMENT = 80000
			TIER_INCREMENT = 100000

func _process(delta: float) -> void:
	_update_ui()
	_process_job_progress(delta)
	_update_tier_display()
	
	if Globals.job_manager == true and job_offer_timer.is_stopped():
		
		if job_container.get_child_count() < Globals.job_manager_level + 2:
			job_offer_timer.start()
	
	Globals.player_has_employees = employees > 0 and max_job_time > 0
		
func _update_ui() -> void:
	$Start_Business/Cost_Label.text = "Start Up Cost: " + add_comma_to_int(startup_cost)
	$Start_Business/Expence_Label.text = "Monthly cost: " + add_comma_to_int(expense)
	$TabContainer/employees/Employee_count.text = "Workers: " + str(employees)
	$TabContainer/employees/Employee_cost.text = "Employee cost every month: " + add_comma_to_int(salary)
	$TabContainer/Job_info/job_pay_when_done.text = "Job Pay When Done: " + add_comma_to_int(job_pay_when_done)
	$TabContainer/info/Business_worth.text = "Business worth: " + add_comma_to_int(business_worth)

func _on_month_passed() -> void:
	# Only deduct salary if there are employees
	if employees > 0:
		pay_salaries()

func _process_job_progress(delta: float) -> void:
	# Ensure variables are floats before comparison
	if typeof(max_job_time) == TYPE_FLOAT and typeof(job_time) == TYPE_FLOAT:
		if max_job_time > 0.0 and job_time > 0.0:
			Globals.max_job_time = max_job_time
			Globals.job_time = job_time
			Globals.job_pay = job_payment
			# Linear scaling with workers (1 worker = 1x speed, 2 workers = 2x speed)
			var progress_rate = 0.01 / 90.0 + employees * delta / 90.0
			job_time = max(0.0, job_time - progress_rate)
			$TabContainer/Job_info/stop_job_button.visible = true

			# Update progress bar
			var progress = (1.0 - job_time / max_job_time) * 100.0
			$TabContainer/Job_info/ProgressBar.value = progress
			$ProgressBar.value = progress

			if job_time <= 0.0:
				_complete_job()
	else:
		_reset_job()

func _complete_job() -> void:
	$TabContainer/Job_info/ProgressBar.value = 100
	$ProgressBar.value = 100
	$TabContainer/Job_info/stop_job_button.visible = false
	if Globals.job_manager == false:
		$TabContainer/Job_info/Find_jobs_button.visible = true
	Globals.exp += 25
	if job_pay_when_done >= 0:
		Globals.money += job_pay_when_done
		if Globals.business_bonus:
			business_worth += job_pay_when_done / 25
		else:
			business_worth += job_pay_when_done / 50
		Globals.Business_worth = business_worth
		show_floating_label("Job Completed! Earned: $" + add_comma_to_int(job_pay_when_done), Color.GREEN)
		job_completed.emit(job_pay_when_done, true)
	else:
		Globals.money += job_pay_when_done
		business_worth += job_pay_when_done / 50
		Globals.business_worth = business_worth
		show_floating_label("Job Completed! Lost: $" + add_comma_to_int(-job_pay_when_done), Color.RED)
		job_completed.emit(job_pay_when_done, false)
	
	_reset_job()

func _reset_job() -> void:
	job_pay_when_done = 0
	max_job_time = 0
	job_payment = 0
	$TabContainer/Job_info/ProgressBar.value = 0
	$ProgressBar.value = 0

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func start_business(name: String) -> void:
	if name.is_empty():
		show_floating_label("Business Name Can't Be Blank", Color.RED)
		return
		
	if Globals.money < startup_cost:
		show_floating_label("Not enough money to start business", Color.RED)
		return
	
	Globals.money -= startup_cost
	business_name = name
	Globals.business_name = business_name
	$TabContainer/info/Business_name.text = business_name + "'s Info"
	$Start_Business.visible = false
	$TabContainer.visible = true
	$job_progress.visible = true
	$ProgressBar.visible = true
	business_worth = expense
	show_floating_label("Business Created: " + business_name, Color.GREEN)
	business_started.emit(business_name)
	Globals.recalculate_expenses()

func pay_salaries() -> void:
	if employees <= 0:
		return
		
	var monthly_cost = salary
	
	# Deduct from job payment first, then player money
	if job_pay_when_done > 0:
		var deduction = min(monthly_cost, job_pay_when_done)
		job_pay_when_done -= deduction
		monthly_cost -= deduction
	
	if monthly_cost > 0:
		Globals.money -= monthly_cost
		var color = Color.GREEN if Globals.money >= 0 else Color.RED
		show_floating_label("Paid salaries: $" + add_comma_to_int(salary), color)

func _update_jobs() -> void:
	# Add randomness to job duration with weighted probabilities
	var job_duration = _get_random_job_duration()
	
	var business_tier = clamp(floor(business_worth / TIER_INCREMENT), 1, 10)
	var base_payment = _calculate_tier_payment(business_tier)
	
	# Get market condition with some randomness
	var market_condition = 0.0
	if has_node("../../Market") and $"../../Market".has_method("get_market_condition"):
		market_condition = $"../../Market".get_market_condition()
		# Add small random fluctuation to market condition (±10%)
		market_condition *= randf_range(0.9, 1.1)
	
	# More varied payment calculation with multiple random factors
	var payment_multiplier = _calculate_random_payment_multiplier(job_duration, market_condition)
	
	var job_pay = roundi(base_payment * payment_multiplier)
	
	# Apply job bonus with small random variation
	if Globals.Job_bonus:  # Simplified boolean check
		job_pay = roundi(job_pay * randf_range(1.45, 1.55))  # 45-55% bonus

	# Occasionally add random modifiers to jobs
	if randf() < 0.3:  # 30% chance for special job
		job_pay = _apply_random_job_modifiers(job_pay, job_duration)
	
	if Globals.job_manager == true:
		if job_container.get_child_count() < Globals.job_manager_level + 2:
			add_job_mod(job_pay, job_duration)
			# Randomize timer wait time for next job offer
			job_offer_timer.wait_time = randf_range(months_between_offers * 0.7, months_between_offers * 1.3)
			job_offer_timer.start()
	else:
		# Show single job offer UI
		_show_job_offer(job_pay, job_duration)

# Helper function for weighted random job duration
func _get_random_job_duration() -> int:
	var durations = []
	var weights = []
	
	# Define preferred durations with weights (shorter jobs more common)
	durations.append(randi_range(1, 3))        # Very short jobs
	weights.append(0.3)                        # 30% weight
	
	durations.append(randi_range(4, 8))        # Short-medium jobs  
	weights.append(0.4)                        # 40% weight
	
	durations.append(randi_range(9, 15))       # Medium-long jobs
	weights.append(0.2)                        # 20% weight
	
	durations.append(randi_range(16, MAX_JOB_TIME)) # Long jobs
	weights.append(0.1)                        # 10% weight
	
	# Return a weighted random duration
	return _weighted_random(durations, weights)

# Helper function for more varied payment calculation
func _calculate_random_payment_multiplier(duration: int, market_condition: float) -> float:
	# Base multiplier based on duration
	var base_multiplier = 1.0 - (0.02 * max(0, duration - 5))
	base_multiplier = max(base_multiplier, 0.7)
	
	# Market influence with random factor
	var market_effect = 1.0 + (market_condition * randf_range(0.004, 0.006))
	
	# Random quality factor (some jobs pay better/worse than average)
	var quality_factor = randf_range(0.9, 1.1)
	
	# Urgency factor (shorter jobs sometimes pay more)
	var urgency_bonus = 1.0
	if duration <= 3 and randf() < 0.4:  # 40% chance for urgency bonus on very short jobs
		urgency_bonus = randf_range(1.1, 1.3)
	
	return base_multiplier * market_effect * quality_factor * urgency_bonus

# Helper function for weighted random selection
func _weighted_random(options: Array, weights: Array):
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	
	for i in range(options.size()):
		cumulative_weight += weights[i]
		if random_value <= cumulative_weight:
			return options[i]
	
	return options[-1]  # Fallback to last option

# Function to apply random job modifiers
func _apply_random_job_modifiers(base_pay: int, duration: int) -> int:
	var modified_pay = base_pay
	var modifier_type = randi() % 4
	
	match modifier_type:
		0: # Rush job - shorter time, higher pay
			if duration > 3:  # Only apply to longer jobs
				modified_pay = roundi(base_pay * randf_range(1.2, 1.5))
		1: # Complex job - longer time, higher pay
			modified_pay = roundi(base_pay * randf_range(1.1, 1.4))
		2: # Standard bonus
			modified_pay = roundi(base_pay * randf_range(1.05, 1.15))
		3: # High-risk, high-reward
			if randf() < 0.5:  # 50% chance for high reward
				modified_pay = roundi(base_pay * randf_range(1.3, 1.8))
	
	return modified_pay

func _calculate_tier_payment(tier: int) -> int:
	# 1.5x growth per tier with soft cap at tier 8
	if tier <= 8:
		return roundi(BASE_PAYMENT * pow(1.5, tier - 1))
	else:
		# Slower growth for tiers 9-10
		return roundi(BASE_PAYMENT * pow(1.5, 7) * pow(1.2, tier - 8))

func _update_tier_display() -> void:
	var current_tier = clamp(floor(business_worth / TIER_INCREMENT), 1, 10)
	var next_tier_goal = (current_tier * TIER_INCREMENT) + TIER_INCREMENT
	var max_employees = TIER_EMPLOYEES.get(current_tier, 100)
	
	$TabContainer/info/TierLabel.text = "Business Tier: %d/10\nNext Tier at $%s\nMax Employees: %d" % [
		current_tier,
		add_comma_to_int(next_tier_goal),
		max_employees
	]

func load_business(name: String) -> void:
	business_name = name
	Globals.business_name = business_name
	$TabContainer/info/Business_name.text = business_name + "'s Info"
	$Start_Business.visible = false
	$TabContainer.visible = true
	$job_progress.visible = true
	$ProgressBar.visible = true
	show_floating_label("Business LOADED: " + business_name, Color.GREEN)

func add_job_mod(payment: int, time: int) -> void:
	var mod_scene = preload("res://assets/UI/job_offer_mod.tscn")
	var mod_instance = mod_scene.instantiate()

	# Set data
	mod_instance.job_pay = payment
	mod_instance.job_time = time

	job_container.add_child(mod_instance)
	job_offer_timer.start()

func _show_job_offer(payment: int, time: int) -> void:
	# Calculate cost with worker efficiency
	var effective_months = time / max(1, employees)
	var total_cost = BASE_SALARY * employees * effective_months if employees > 0 else 5000 * effective_months
	
	# Enhanced profitability check
	var profit_margin = float(payment - total_cost) / total_cost if total_cost > 0 else 1.0
	
	# Update UI
	$"../Job_offer_ui".visible = true
	$"../Job_offer_ui/job_time".text = "Job Duration: " + str(time) + " months"
	$"../Job_offer_ui/job_pay".text = "Job Pay: " + add_comma_to_int(payment)
	$"../Job_offer_ui/info".text = "Job offer for " + business_name
	
	# Disconnect previous signals
	if $"../Job_offer_ui/take_job".pressed.is_connected(_on_take_job_pressed):
		$"../Job_offer_ui/take_job".pressed.disconnect(_on_take_job_pressed)
	if $"../Job_offer_ui/Deny_job".pressed.is_connected(_on_deny_job_pressed):
		$"../Job_offer_ui/Deny_job".pressed.disconnect(_on_deny_job_pressed)
	
	# Connect new signals
	$"../Job_offer_ui/take_job".pressed.connect(_on_take_job_pressed.bind(payment, time))
	$"../Job_offer_ui/Deny_job".pressed.connect(_on_deny_job_pressed)
	
	# Stop the timer while showing the offer
	job_offer_timer.stop()

func _on_take_job_pressed(payment: int, time: int) -> void:
	max_job_time = time
	job_time = time
	job_payment = payment
	job_pay_when_done = job_payment
	show_floating_label("Accepted Job", Color.GREEN)
	$"../Job_offer_ui".visible = false
	job_accepted.emit(payment, time)
	
	# Restart timer for next offer
	job_offer_timer.stop()

func _on_deny_job_pressed() -> void:
	show_floating_label("Rejected Job", Color.RED)
	$"../Job_offer_ui".visible = false
	job_offer_timer.start()

func show_floating_label(text: String, color: Color = Color.WHITE) -> void:
	if not ui_layer:
		return
		
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position.y = -50
	ui_layer.add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)

func _on_start_a_business_button_pressed() -> void:
	var business_name_input = $Start_Business/Name_of_Business.text
	start_business(business_name_input)

func _on_stop_job_button_pressed() -> void:
	_reset_job()
	$TabContainer/Job_info/stop_job_button.visible = false
	if Globals.job_manager == false:
		$TabContainer/Job_info/Find_jobs_button.visible = true
	show_floating_label("Job Cancelled", Color.YELLOW)

func _on_find_jobs_button_pressed() -> void:
	$TabContainer/Job_info/Find_jobs_button.visible = false
	job_offer_timer.start()

func get_max_employees() -> int:
	var tier = max(floor(business_worth / TIER_INCREMENT), 1)
	return TIER_EMPLOYEES.get(clamp(tier, 1, 10), 100)

func _on_add_employee_pressed() -> void:
	var max_employees = get_max_employees()
	
	if employees >= max_employees:
		show_floating_label("Max employees reached for this business tier", Color.RED)
		return
	employees += 1
	Globals.employees = employees
	salary += BASE_SALARY
	show_floating_label("Hired 1 Employee", Color.GREEN)
	employee_changed.emit(employees)

func _on_remove_employee_pressed() -> void:
	if employees <= 0:
		return
		
	employees -= 1
	Globals.employees = employees
	salary -= BASE_SALARY
	show_floating_label("Fired 1 Employee", Color.RED)
	employee_changed.emit(employees)

func _on_close_button_pressed() -> void:
	hide()

func _on_sell_business_button_pressed() -> void:
	Globals.money += business_worth
	show_floating_label("Sold Business for: " + add_comma_to_int(business_worth), Color.GREEN)
	business_sold.emit(business_worth)
	
	# Reset business state
	Globals.business_name = ""
	Globals.employees = 0
	Globals.Business_worth = 0
	employees = 0
	salary = 0
	_reset_job()
	
	# Update UI
	$TabContainer.visible = false
	$Start_Business.visible = true
	$ProgressBar.visible = false
	$job_progress.visible = false
	$Start_Business/Name_of_Business.text = ""
	Globals.recalculate_expenses()
func _on_name_of_business_focus_entered() -> void:
	Globals.Editing_Business_Text = true

func _on_name_of_business_focus_exited() -> void:
	Globals.Editing_Business_Text = false
