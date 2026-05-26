extends Control

@onready var ui_layer = $"../.."
@onready var job_info_label = $VBoxContainer/Job_info

# --- HOLD & LOOP LOGIC ---
var is_holding: bool = false
var current_job_index: int = -1

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
var last_market_factor := 1.0 

func _ready() -> void:
	last_has_car = !Globals.has_car 
	reset_all_tasks()
	
	for i in range(do_task_buttons.size()):
		# Connect both down and up
		do_task_buttons[i].button_down.connect(_on_do_task_button_down.bind(i))
		do_task_buttons[i].button_up.connect(_on_do_task_button_up)
	
	update_rewards()
	update_task_availability()

func get_window_start(index: int) -> float:
	# This starts the window at 85% for task 1, and increases slightly per task
	# We cap it at 0.92 so there is always at least a 4% window before Red (0.96)
	var start = 0.85 + (index * 0.02)
	return min(start, 0.92)

func _process(delta: float) -> void:
	# 1. STATE CHANGE CHECKS
	var market_changed = abs(last_market_factor - Globals.market_factor) > 0.01
	var car_status_changed = (last_has_car != Globals.has_car)
	var work_level_changed = (last_work_amount != Globals.work_amount)

	if work_level_changed or car_status_changed or market_changed:
		update_rewards()
		update_task_availability()
		last_work_amount = Globals.work_amount
		last_has_car = Globals.has_car
		last_market_factor = Globals.market_factor
	
	# 2. PROGRESS BAR ANIMATION & VISUAL FEEDBACK
	for i in range(progress_bars.size()):
		var bar = progress_bars[i]
		
		if task_started[i]:
			# Stop filling if the button is released
			if i == current_job_index and not is_holding:
				task_started[i] = false
				job_in_progress = false
				# Fall through to the reset logic in the 'else' block
			
			var task_speed = get_adjusted_task_speed()
			bar.value += delta * task_speed
			
			var pct = bar.value / bar.max_value
			
			# --- A. TENSION SHAKE ---
			if pct > 0.70:
				var shake_intensity = (pct - 0.70) * 9.0
				bar.position.x = randf_range(-1.0, 1.0) * shake_intensity
			else:
				bar.position.x = 0
			
			# --- B. DYNAMIC COLOR WINDOW ---
			var window_start = get_window_start(i) # Use the helper
			var sb = bar.get_theme_stylebox("fill").duplicate()
			
			if pct >= window_start and pct <= 0.96:
				sb.bg_color = Color.YELLOW
			elif pct > 0.96:
				sb.bg_color = Color.RED
			else:
				sb.bg_color = Color.WHITE

			bar.add_theme_stylebox_override("fill", sb)
			
			# Apply the style override so the color actually shows up
			bar.add_theme_stylebox_override("fill", sb)
				
			# --- C. AUTO-COMPLETION ---
			if bar.value >= bar.max_value:
				bar.position.x = 0
				complete_task(i) # This uses the default 1.0 multiplier
				
		else:
			# --- RESET LOGIC FOR INACTIVE BARS ---
			bar.position.x = 0
			bar.modulate = Color.WHITE
			
			# Remove the override so the bar returns to your default Theme colors
			bar.remove_theme_stylebox_override("fill")
			
			if not job_in_progress:
				bar.value = 0
# --- TASK CONTROL ---
func _on_do_task_button_down(job_index: int) -> void:
	is_holding = true
	current_job_index = job_index
	
	# Start the task immediately on press if not already working
	if not job_in_progress:
		attempt_start_task(job_index)

func _on_do_task_button_up() -> void:
	if current_job_index == -1:
		is_holding = false
		return

	var bar = progress_bars[current_job_index]
	var final_pct = bar.value / bar.max_value
	
	# --- SYNCHRONIZED WINDOW LOGIC ---
	# We use the same math as _process to ensure visual consistency.
	# Index 0 starts at 0.88, Index 4 starts at 0.94.
	# Since Red starts at 0.96, this guarantees at least a 2% window for the last task.
	var window_start = 0.88 + (current_job_index * 0.015)
	window_start = min(window_start, 0.94) 

	if task_started[current_job_index]:
		if final_pct >= window_start and final_pct <= 0.96:
			# SUCCESS: Perfect timing! (Yellow Zone)
			complete_task(current_job_index, 1.5) 
			
		elif final_pct > 0.96:
			# FAIL: Released in the RED
			Globals.notify("Too late! Task Failed.", Color.TOMATO)
			bar.value = 0
			task_started[current_job_index] = false
			job_in_progress = false
			
		else:
			# FAIL: Released too early (White Zone)
			# Bar resets, no reward given
			bar.value = 0
			task_started[current_job_index] = false
			job_in_progress = false

	# Stop the holding state regardless of success or failure
	is_holding = false


func attempt_start_task(job_index: int) -> void:
	# Requirement Checks
	if job_index > Globals.work_amount:
		Globals.notify("Task %d requires Work Level %d" % [job_index + 1, job_index], Color.RED)
		is_holding = false # Cancel hold if they can't do it
		return
		
	if job_index > 0 and not Globals.has_car:
		Globals.notify("Need a fixed car for Task %d" % [job_index + 1], Color.RED)
		is_holding = false
		return
	
	start_task_logic(job_index)

func start_task_logic(job_index: int) -> void:
	if not job_in_progress and not task_started[job_index]:
		if $"../Car_info".breakdown_timer.is_stopped() and Globals.difficulty > 0:
			$"../Car_info".breakdown_timer.start()
		
		task_started[job_index] = true
		job_in_progress = true
		update_rewards()

func complete_task(job_index: int, multiplier: float = 1.0) -> void:
	var bar = progress_bars[job_index]
	bar.value = 0
	
	var earned_exp = (1 + (job_index * 4)) * Globals.exp_boost * multiplier
	Globals.EXP += int(earned_exp)
	
	# Base Money: from your rewards array
	var final_money = int(rewards[job_index] * multiplier)
	Globals.money += final_money
	
	# 2. Visual Feedback / Notifications
	if multiplier > 1.0:
		# Feedback for hitting the "Perfect Release" zone
		Globals.notify("PERFECT! +$%s" % add_comma_to_int(final_money), Color.CYAN)
		Globals.notify("EXP +%d" % int(earned_exp), Color.YELLOW)
	else:
		# Standard feedback for auto-completing or missing the zone
		Globals.notify("Earned $%s" % add_comma_to_int(final_money), Color.SPRING_GREEN)
		Globals.notify("EXP +%d" % int(earned_exp), Color.YELLOW)
	
	# 3. Update UI/Rewards State
	update_rewards() 
	
	# 4. Reset Task State
	task_started[job_index] = false
	job_in_progress = false

	# 5. The Looping Mechanic
	# If the user is still holding the button, restart the task
	if is_holding and current_job_index == job_index:
		attempt_start_task(job_index)

# --- UTILITIES ---

func update_rewards() -> void:
	var base_rewards = [10, 50, 100, 400, 600]
	rewards = []
	for i in range(base_rewards.size()):
		var bonus_multiplier = 1.0 + (Globals.work_bonus * 0.5)
		var final_reward = base_rewards[i] * bonus_multiplier * Globals.market_factor
		rewards.append(int(final_reward))
		do_task_buttons[i].tooltip_text = "Task %d: Earn $%s" % [i + 1, add_comma_to_int(rewards[i])]

func get_adjusted_task_speed() -> float:
	var factors = [Globals.Player_health, Globals.Player_hunger, Globals.Player_comfort]
	var avg = 0.0
	for f in factors: avg += max(f / 100.0, 0.2)
	return base_task_speed * (avg / 3.0)

func update_task_availability() -> void:
	for i in range(do_task_buttons.size()):
		var unlocked = i <= Globals.work_amount
		var has_car = Globals.has_car or i == 0 
		var can_do = unlocked and has_car
		do_task_buttons[i].disabled = not can_do
		do_task_buttons[i].modulate = Color.WHITE if can_do else Color.DIM_GRAY
		do_task_buttons[i].text = "Task %d ($%s)" % [i + 1, add_comma_to_int(rewards[i])]

func reset_all_tasks() -> void:
	for bar in progress_bars: bar.value = 0
	task_started = [false, false, false, false, false]
	job_in_progress = false

func add_comma_to_int(value: int) -> String:
	var s = str(value)
	for i in range(s.length() - 3, 0 if value > -1 else 1, -3):
		s = s.insert(i, ",")
	return s
