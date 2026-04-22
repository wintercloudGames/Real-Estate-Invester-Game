extends Control

@onready var job_list_panel: TabContainer = $job_list
@onready var description_label = $Label
@onready var stats: Label = $Stats

@export var labor_bar: ProgressBar
@export var services_bar: ProgressBar
@export var trade_bar: ProgressBar
@export var finance_bar: ProgressBar
@export var management_bar: ProgressBar

var refresh_timer: Timer
var work_timer: Timer # New timer for EXP gain
const JOBS_FOLDER = "res://assets/job/jobs/"
var unlocked_jobs: Array[String] = []

func _ready():
	initialize_known_jobs()
	load_jobs_from_folder()
	job_list_panel.visible = false
	
	# Connect signals
	if not Globals.is_connected("stats_changed", update_stats):
		Globals.connect("stats_changed", update_stats)
	
	# UI Refresh Timer
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 2.0
	refresh_timer.timeout.connect(update_job_buttons) 
	add_child(refresh_timer)
	
	# --- WORK TICK TIMER ---
	work_timer = Timer.new()
	work_timer.wait_time = 5.0 # Trigger every 5 seconds
	work_timer.timeout.connect(process_work_tick)
	add_child(work_timer)
	work_timer.start() 
	
	if Globals.current_job_name != "Unemployed":
		description_label.text = "CURRENT JOB: %s\nINCOME: $%s/mo" % [Globals.current_job_name, str(Globals.job_income)]
	else:
		description_label.text = "You are currently unemployed."
	
	update_stats()

func process_work_tick():
	if Globals.current_job_name == "Unemployed" or not Globals.has_car:
		return
		
	var total_multiplier = 1.0 + Globals.exp_boost
	var gain = Globals.job_exp_gain_per_month * total_multiplier

	# 1. Update the points
	match Globals.current_job_category:
		"Labor": Globals.labor_points += gain
		"Services": Globals.services_points += gain
		"Trade": Globals.trade_points += gain
		"Finance": Globals.finance_points += gain
		"Management": Globals.management_points += gain
	
	# 2. REMOVE check_for_new_unlocks() from here!
	# Only call it when the whole number (Level) changes to save performance
	var current_points = get_player_points_for_category(Globals.current_job_category)
	if int(current_points) > int(current_points - gain):
		Globals.check_for_new_unlocks() # Only scans files when you actually level up!

	update_stats()
	Globals.emit_signal("stats_changed")

func update_stats():
	stats.text = "--- JOB SKILLS ---\n"
	
	var stat_list = [
		{"name": "LABOR", "val": Globals.labor_points, "bar": labor_bar},
		{"name": "SERVICES", "val": Globals.services_points, "bar": services_bar},
		{"name": "TRADE", "val": Globals.trade_points, "bar": trade_bar},
		{"name": "FINANCE", "val": Globals.finance_points, "bar": finance_bar},
		{"name": "MANAGEMENT", "val": Globals.management_points, "bar": management_bar}
	]
	
	for s in stat_list:
		var total_points = float(s["val"])
		var whole_points = int(total_points)
		var progress = total_points - float(whole_points)
		
		stats.text += "[%s]\n" % s["name"]
		stats.text += "  Level: %d pts\n" % whole_points
		# FIX: Use 'snapped' to show only 1 decimal point (e.g. 45.2%)
		stats.text += "  EXP: %d%%\n\n" % int(snapped(progress, 0.01) * 100)
		
		if is_instance_valid(s["bar"]):
			s["bar"].max_value = 1.0
			s["bar"].value = progress
# --- UI LOGIC ---

func initialize_known_jobs():
	var dir = DirAccess.open(JOBS_FOLDER)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != ".." and not file_name.ends_with(".import"):
				var clean_path = JOBS_FOLDER + file_name.trim_suffix(".remap")
				var job_res = load(clean_path)
				if job_res is JobData:
					var player_points = get_player_points_for_category(job_res.category)
					var level_met = Globals.level >= job_res.required_player_level
					var skill_met = player_points >= job_res.required_skill_points
					
					if level_met and skill_met:
						unlocked_jobs.append(job_res.job_name)
			file_name = dir.get_next()

func load_jobs_from_folder():
	for category_node in job_list_panel.get_children():
		var container = category_node.get_node_or_null("VBoxContainer")
		if container:
			for child in container.get_children(): child.queue_free()

	var dir = DirAccess.open(JOBS_FOLDER)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if (file_name.ends_with(".tres") or file_name.ends_with(".remap")) and not file_name.ends_with(".import"):
				var clean_path = JOBS_FOLDER + file_name.trim_suffix(".remap")
				var job_res = load(clean_path)
				if job_res is JobData:
					create_job_button(job_res)
			file_name = dir.get_next()

func create_job_button(job: JobData):
	var container_path = "job_list/" + job.category + "/VBoxContainer"
	var target_container = get_node_or_null(container_path)
	if not target_container: return

	var btn = Button.new()
	btn.set_meta("job_data", job) 
	update_button_visuals(btn, job)
	btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_job_selected.bind(job))
	target_container.add_child(btn)

func update_job_buttons():
	for category_node in job_list_panel.get_children():
		var container = category_node.get_node_or_null("VBoxContainer")
		if container:
			for btn in container.get_children():
				var job = btn.get_meta("job_data")
				if job is JobData: update_button_visuals(btn, job)

func update_button_visuals(btn: Button, job: JobData):
	var player_points = int(get_player_points_for_category(job.category))
	var level_met = Globals.level >= job.required_player_level
	var skill_met = player_points >= job.required_skill_points
	
	if level_met and skill_met:
		# Check Globals instead of the local array
		if not Globals.unlocked_jobs.has(job.job_name):
			Globals.unlocked_jobs.append(job.job_name)
			# Only notify if the game is actually running (not just starting up)
			if Globals.first_start == false: 
				Globals.notify("New Job Available: " + job.job_name, Color.CHARTREUSE)
		
		btn.text = "%s - $%s/mo" % [job.job_name, str(job.monthly_salary)]
		btn.disabled = false
		btn.modulate = Color.WHITE
	else:
		btn.text = "LOCKED: %s (Req: Lvl %d, %d Pts)" % [job.job_name, job.required_player_level, job.required_skill_points]
		btn.disabled = true
		btn.modulate = Color(1.0, 1.0, 1.0, 0.5)

func get_player_points_for_category(cat: String) -> float:
	match cat:
		"Labor": return float(Globals.labor_points)
		"Services": return float(Globals.services_points)
		"Trade": return float(Globals.trade_points)
		"Finance": return float(Globals.finance_points)
		"Management": return float(Globals.management_points)
	return 0.0

func _on_job_selected(job: JobData):
	Globals.job_income = job.monthly_salary
	Globals.current_job_name = job.job_name
	Globals.job_exp_per_month = job.Exp_gain_per_month
	Globals.job_exp_gain_per_month = job.job_exp_gain_per_month
	Globals.current_job_category = job.category
	description_label.text = "CURRENT JOB: %s\nINCOME: $%s/mo" % [job.job_name, str(job.monthly_salary)]
	job_list_panel.visible = false
	refresh_timer.stop()

func _on_apply_for_job_pressed() -> void:
	job_list_panel.visible = !job_list_panel.visible
	if job_list_panel.visible:
		update_job_buttons()
		update_stats()
		refresh_timer.start()
	else:
		refresh_timer.stop()

func _on_close_button_pressed() -> void:
	self.visible = false
	job_list_panel.visible = false
	refresh_timer.stop()
	update_stats()

func _on_show_job_display_pressed() -> void:
	self.visible = !self.visible
	if not self.visible:
		job_list_panel.visible = false
		refresh_timer.stop()
	update_stats()
