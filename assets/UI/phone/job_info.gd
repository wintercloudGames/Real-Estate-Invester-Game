extends Control

@onready var ui_layer = $"../.."  # HUD reference, same as bank_system.gd
@onready var job_info_label = $VBoxContainer/Job_info  # Label for job status

# Store all progress bars in an array.
@onready var progress_bars := [
	$VBoxContainer/ProgressBar,
	$VBoxContainer/ProgressBar2,
	$VBoxContainer/ProgressBar3,
	$VBoxContainer/ProgressBar4,
	$VBoxContainer/ProgressBar5
]

# Task states for each job.
var task_started := [false, false, false, false, false]

# Rewards for each job.
var rewards := []

# Keeps track of whether a job is in progress.
var job_in_progress := false

# Base task speed (higher means faster completion)
var base_task_speed := 10.0  # Jobs complete in ~10 seconds normally

@onready var do_task_buttons := [
	$VBoxContainer/Do_task_Button1,
	$VBoxContainer/Do_task_Button2,
	$VBoxContainer/Do_task_Button3,
	$VBoxContainer/Do_task_Button4,
	$VBoxContainer/Do_task_Button5
]

# Maximum work level
var max_work_level: int = 4

# Track last known work_amount and has_car for optimization
var last_work_amount := -1
var last_has_car := true

func _ready() -> void:
	reset_all_tasks()
	# Connect each button's pressed signal using Callable.bind()
	for i in range(do_task_buttons.size()):
		do_task_buttons[i].pressed.connect(_on_do_task_button_pressed.bind(i))
	update_rewards()
	update_task_availability()


# Function to update rewards based on work_bonus
func update_rewards() -> void:
	var base_rewards = [25, 150, 400, 1000, 1500] 
	rewards = []
	for i in range(base_rewards.size()):
		var bonus_multiplier = 1.0 + (Globals.work_bonus * 0.1)  
		var final_reward = base_rewards[i] * bonus_multiplier
		rewards.append(int(final_reward))
		# Update button tooltip with reward
		do_task_buttons[i].tooltip_text = "Task %d: Earn $%s" % [i + 1, add_comma_to_int(rewards[i])]

func reset_all_tasks() -> void:
	for bar in progress_bars:
		bar.value = 0
	task_started = [false, false, false, false, false]
	job_in_progress = false

func _process(delta: float) -> void:
	# Update task availability only if work_amount or has_car changes
	if last_work_amount != Globals.work_amount or last_has_car != Globals.has_car:
		update_task_availability()
		last_work_amount = Globals.work_amount
		last_has_car = Globals.has_car
	
	# Update job info label
	if job_in_progress:
		job_info_label.add_theme_color_override("font_color", Color.YELLOW)
	elif not Globals.has_car and Globals.work_amount >= 1:
		job_info_label.text = "You need a fixed car to do Tasks 2–5."
		job_info_label.add_theme_color_override("font_color", Color.RED)
	else:
		job_info_label.text = "Choose a job to start."
		job_info_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# Update progress bars
	for i in range(progress_bars.size()):
		if task_started[i]:
			var bar = progress_bars[i]
			var task_speed = get_adjusted_task_speed()
			bar.value += delta * task_speed
			if bar.value >= bar.max_value:
				complete_task(i)

func complete_task(job_index: int) -> void:
	var bar = progress_bars[job_index]
	bar.value = 0
	Globals.exp += 2 + (job_index * 2)
	task_started[job_index] = false
	job_in_progress = false
	Globals.money += rewards[job_index] 
	show_floating_label("Earned $%s" % add_comma_to_int(rewards[job_index]), Color.GREEN)

# Adjusts task speed based on player stats
func get_adjusted_task_speed() -> float:
	var health_factor = max(Globals.Player_health / 100.0, 0.2)
	var hunger_factor = max(Globals.Player_hunger / 100.0, 0.2)
	var comfort_factor = max(Globals.Player_comfort / 100.0, 0.2)
	var average_factor = (health_factor + hunger_factor + comfort_factor) / 3.0
	return base_task_speed * average_factor

# Creates a floating label that moves up and fades out
func show_floating_label(text: String, color: Color = Color.WHITE) -> void:
	if ui_layer:
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.position = Vector2(700, 500)  # Consistent with original
		ui_layer.add_child(label)
		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5)  # Faster animation
		tween.parallel().tween_property(label, "modulate:a", 0, 1.5)
		tween.tween_callback(label.queue_free)

# Called when any "Do Task" button is pressed
func _on_do_task_button_pressed(job_index: int) -> void:
	# Check if task is unlocked and car is available
	if job_index > Globals.work_amount:
		show_floating_label("Task %d requires Work Level %d" % [job_index + 1, job_index], Color.RED)
		return
	if job_index > 0 and not Globals.has_car:
		show_floating_label("Need a fixed car for Task %d" % [job_index + 1], Color.RED)
		return
	if not job_in_progress and not task_started[job_index]:
		if $"../Car_info".breakdown_timer.is_stopped() and Globals.difficulty > 0:
			$"../Car_info".breakdown_timer.start()
		task_started[job_index] = true
		job_in_progress = true
		update_rewards()  # Ensure rewards are up-to-date

# Enable/disable tasks based on work amount and car status
func update_task_availability() -> void:
	for i in range(do_task_buttons.size()):
		var is_unlocked = i <= Globals.work_amount
		var has_car_for_task = Globals.has_car or i == 0  # Task 1 doesn't need a car
		do_task_buttons[i].disabled = not (is_unlocked and has_car_for_task)
		do_task_buttons[i].modulate = Color.WHITE if is_unlocked and has_car_for_task else Color.DIM_GRAY
		do_task_buttons[i].tooltip_text = "Task %d: Earn $%s" % [i + 1, add_comma_to_int(rewards[i])]

# Call this when work amount is upgraded
func on_work_amount_upgraded() -> void:
	update_rewards()
	update_task_availability()
	if Globals.work_amount > 0 and Globals.work_amount < do_task_buttons.size():
		show_floating_label("Unlocked Task %d!" % [Globals.work_amount + 1], Color.GREEN)

# Function to upgrade work amount
func upgrade_work_amount() -> void:
	if Globals.work_amount < max_work_level:
		Globals.work_amount += 1
		on_work_amount_upgraded()
	else:
		show_floating_label("Work amount already at maximum level!", Color.YELLOW)

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
