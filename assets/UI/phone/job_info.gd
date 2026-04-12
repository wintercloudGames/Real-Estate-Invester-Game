extends Control

@onready var ui_layer = $"../.."
@onready var job_info_label = $VBoxContainer/Job_info

@onready var progress_bars := [
	$VBoxContainer/ProgressBar,
	$VBoxContainer/ProgressBar2,
	$VBoxContainer/ProgressBar3,
	$VBoxContainer/ProgressBar4,
	$VBoxContainer/ProgressBar5
]

var task_started := [false, false, false, false, false]
var rewards := []
var job_in_progress := false
var base_task_speed := 10.0

@onready var do_task_buttons := [
	$VBoxContainer/Do_task_Button1,
	$VBoxContainer/Do_task_Button2,
	$VBoxContainer/Do_task_Button3,
	$VBoxContainer/Do_task_Button4,
	$VBoxContainer/Do_task_Button5
]

var max_work_level: int = 4
var last_work_amount := -1
var last_has_car := true
var last_market_factor := 1.0 # Track market changes

func _ready() -> void:
	# Initialize the 'last' variable to the opposite of current so it triggers an update immediately
	last_has_car = !Globals.has_car 
	
	reset_all_tasks()
	for i in range(do_task_buttons.size()):
		do_task_buttons[i].pressed.connect(_on_do_task_button_pressed.bind(i))
	
	# Force an initial update
	update_rewards()
	update_task_availability()

func _process(delta: float) -> void:
	# 1. CHECK FOR STATE CHANGES
	var market_changed = abs(last_market_factor - Globals.market_factor) > 0.01
	var car_status_changed = (last_has_car != Globals.has_car)
	var work_level_changed = (last_work_amount != Globals.work_amount)

	if work_level_changed or car_status_changed or market_changed:
		update_rewards()
		update_task_availability()
		last_work_amount = Globals.work_amount
		last_has_car = Globals.has_car
		last_market_factor = Globals.market_factor
	
	# 2. UPDATE THE INFO LABEL TEXT
	if job_in_progress:
		# Don't change text while working
		pass 
	elif not Globals.has_car:
		# ONLY show the error if the car is actually false
		job_info_label.text = "You need a fixed car for Tasks 2–5."
		job_info_label.add_theme_color_override("font_color", Color.RED)
	else:
		# Car is fixed, show normal market info
		var market_text = "Stable"
		if Globals.market_factor > 1.1: market_text = "Booming (High Pay)"
		elif Globals.market_factor < 0.9: market_text = "Recession (Low Pay)"
		
		job_info_label.text = "Market: %s. Choose a job." % market_text
		job_info_label.add_theme_color_override("font_color", Color.CYAN)
	
	# 3. HANDLE PROGRESS BAR ANIMATION
	for i in range(progress_bars.size()):
		if task_started[i]:
			var bar = progress_bars[i]
			var task_speed = get_adjusted_task_speed()
			bar.value += delta * task_speed
			if bar.value >= bar.max_value:
				complete_task(i)

func update_rewards() -> void:
	# Base pay for tasks
	var base_rewards = [10, 50, 100, 400, 600]
	rewards = []
	
	for i in range(base_rewards.size()):
		# 1. Experience/Skill Bonus
		var bonus_multiplier = 1.0 + (Globals.work_bonus * 0.1) 
		
		# 2. Market Impact 
		# If market_factor is 1.2 (Bull), pay increases by 20%
		# If market_factor is 0.7 (Crash), pay decreases by 30%
		var market_multiplier = Globals.market_factor
		
		var final_reward = base_rewards[i] * bonus_multiplier * market_multiplier
		rewards.append(int(final_reward))
		
		# Update button text/tooltip to show the market-adjusted pay
		do_task_buttons[i].tooltip_text = "Task %d: Earn $%s (Market Adjusted)" % [i + 1, add_comma_to_int(rewards[i])]

func reset_all_tasks() -> void:
	for bar in progress_bars:
		bar.value = 0
	task_started = [false, false, false, false, false]
	job_in_progress = false

func complete_task(job_index: int) -> void:
	var bar = progress_bars[job_index]
	bar.value = 0
	var earned_exp = (2 + (job_index * 2)) * Globals.exp_boost
	Globals.exp += earned_exp
	Globals.notify("EXP + " + str(int(earned_exp)), Color.YELLOW)
	task_started[job_index] = false
	job_in_progress = false
	
	# Final check to ensure they get the current market rate at moment of completion
	update_rewards() 
	
	Globals.money += rewards[job_index] 
	Globals.notify("Earned $%s" % add_comma_to_int(rewards[job_index]), Color.SPRING_GREEN)

func get_adjusted_task_speed() -> float:
	var health_factor = max(Globals.Player_health / 100.0, 0.2)
	var hunger_factor = max(Globals.Player_hunger / 100.0, 0.2)
	var comfort_factor = max(Globals.Player_comfort / 100.0, 0.2)
	var average_factor = (health_factor + hunger_factor + comfort_factor) / 3.0
	return base_task_speed * average_factor


func _on_do_task_button_pressed(job_index: int) -> void:
	if job_index > Globals.work_amount:
		Globals.notify("Task %d requires Work Level %d" % [job_index + 1, job_index], Color.RED)
		return
	if job_index > 0 and not Globals.has_car:
		Globals.notify("Need a fixed car for Task %d" % [job_index + 1], Color.RED)
		return
	if not job_in_progress and not task_started[job_index]:
		if $"../Car_info".breakdown_timer.is_stopped() and Globals.difficulty > 0:
			$"../Car_info".breakdown_timer.start()
		task_started[job_index] = true
		job_in_progress = true
		update_rewards() 

func update_task_availability() -> void:
	for i in range(do_task_buttons.size()):
		var is_unlocked = i <= Globals.work_amount
		var has_car_for_task = Globals.has_car or i == 0 
		do_task_buttons[i].disabled = not (is_unlocked and has_car_for_task)
		do_task_buttons[i].modulate = Color.WHITE if is_unlocked and has_car_for_task else Color.DIM_GRAY
		# Show the dollar amount directly on the button for better UX
		do_task_buttons[i].text = "Task %d ($%s)" % [i + 1, add_comma_to_int(rewards[i])]

func on_work_amount_upgraded() -> void:
	update_rewards()
	update_task_availability()
	if Globals.work_amount > 0 and Globals.work_amount < do_task_buttons.size():
		Globals.notify("Unlocked Task %d!" % [Globals.work_amount + 1], Color.GREEN)

func upgrade_work_amount() -> void:
	if Globals.work_amount < max_work_level:
		Globals.work_amount += 1
		on_work_amount_upgraded()
	else:
		Globals.notify("Max Level Reached!", Color.YELLOW)

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
