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
	reset_all_tasks()
	for i in range(do_task_buttons.size()):
		do_task_buttons[i].pressed.connect(_on_do_task_button_pressed.bind(i))
	update_rewards()
	update_task_availability()

func update_rewards() -> void:
	# Base pay for tasks
	var base_rewards = [25, 150, 400, 1000, 1500] 
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

func _process(delta: float) -> void:
	# Update if Work Level, Car Status, OR Market Factor changes
	var market_changed = abs(last_market_factor - Globals.market_factor) > 0.01
	
	if last_work_amount != Globals.work_amount or last_has_car != Globals.has_car or market_changed:
		update_rewards() # Re-calculate pay based on new market conditions
		update_task_availability()
		last_work_amount = Globals.work_amount
		last_has_car = Globals.has_car
		last_market_factor = Globals.market_factor
	
	if job_in_progress:
		job_info_label.add_theme_color_override("font_color", Color.YELLOW)
	elif not Globals.has_car and Globals.work_amount >= 1:
		job_info_label.text = "You need a fixed car to do Tasks 2–5."
		job_info_label.add_theme_color_override("font_color", Color.RED)
	else:
		# Show market status in the job info
		var market_text = "Stable"
		if Globals.market_factor > 1.1: market_text = "Booming (High Pay)"
		elif Globals.market_factor < 0.9: market_text = "Recession (Low Pay)"
		
		job_info_label.text = "Market: %s. Choose a job." % market_text
		job_info_label.add_theme_color_override("font_color", Color.CYAN if market_changed else Color.YELLOW)
	
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
	
	# Final check to ensure they get the current market rate at moment of completion
	update_rewards() 
	
	Globals.money += rewards[job_index] 
	show_floating_label("Earned $%s" % add_comma_to_int(rewards[job_index]), Color.SPRING_GREEN)

func get_adjusted_task_speed() -> float:
	var health_factor = max(Globals.Player_health / 100.0, 0.2)
	var hunger_factor = max(Globals.Player_hunger / 100.0, 0.2)
	var comfort_factor = max(Globals.Player_comfort / 100.0, 0.2)
	var average_factor = (health_factor + hunger_factor + comfort_factor) / 3.0
	return base_task_speed * average_factor

func show_floating_label(text: String, color: Color = Color.WHITE) -> void:
	if ui_layer:
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.position = Vector2(700, 500)
		ui_layer.add_child(label)
		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5)
		tween.parallel().tween_property(label, "modulate:a", 0, 1.5)
		tween.tween_callback(label.queue_free)

func _on_do_task_button_pressed(job_index: int) -> void:
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
		show_floating_label("Unlocked Task %d!" % [Globals.work_amount + 1], Color.GREEN)

func upgrade_work_amount() -> void:
	if Globals.work_amount < max_work_level:
		Globals.work_amount += 1
		on_work_amount_upgraded()
	else:
		show_floating_label("Max Level Reached!", Color.YELLOW)

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
