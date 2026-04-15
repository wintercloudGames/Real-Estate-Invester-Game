extends Control

@onready var job_list_panel: TabContainer = $job_list
@onready var description_label = $Label
@onready var stats: Label = $Stats
var refresh_timer: Timer

const JOBS_FOLDER = "res://assets/job/jobs/"

# This tracks jobs the player has already qualified for to prevent notification spam
var unlocked_jobs: Array[String] = []

func _ready():
	# 1. First, check what jobs are already unlocked without notifying
	initialize_known_jobs()
	
	# 2. Setup UI
	load_jobs_from_folder()
	job_list_panel.visible = false
	Globals.stats_changed.connect(update_stats)
	# 3. Setup the Refresh Timer
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 2.0
	refresh_timer.autostart = false 
	refresh_timer.timeout.connect(update_job_buttons) 
	add_child(refresh_timer)
	
	if Globals.current_job_name != "Unemployed":
		description_label.text = "CURRENT JOB: %s\nINCOME: $%s/mo" % [Globals.current_job_name, str(Globals.job_income)]
	else:
		description_label.text = "You are currently unemployed."

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
	# Clear existing buttons
	for category_node in job_list_panel.get_children():
		var container = category_node.get_node_or_null("VBoxContainer")
		if container:
			for child in container.get_children():
				child.queue_free()

	var categories = ["labor", "services", "trade", "finance", "management"]
	
	var dir = DirAccess.open(JOBS_FOLDER)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Check for the actual file or the remapped version Godot creates on export
			if (file_name.ends_with(".tres") or file_name.ends_with(".remap")) and not file_name.ends_with(".import"):
				var clean_path = JOBS_FOLDER + file_name.trim_suffix(".remap")
				var job_res = load(clean_path)
				if job_res is JobData:
					create_job_button(job_res)
			file_name = dir.get_next()

func create_job_button(job: JobData):
	# Match internal category (Capitalized) to UI structure
	var container_path = "job_list/" + job.category + "/VBoxContainer"
	var target_container = get_node_or_null(container_path)
	
	if not target_container:
		return

	var btn = Button.new()
	btn.set_meta("job_data", job) 
	
	# Initial setup of button appearance
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
				if job is JobData:
					update_button_visuals(btn, job)

func update_button_visuals(btn: Button, job: JobData):
	var player_points = get_player_points_for_category(job.category)
	var level_met = Globals.level >= job.required_player_level
	var skill_met = player_points >= job.required_skill_points
	
	if level_met and skill_met:
		# Notify if this is a newly unlocked job
		if not unlocked_jobs.has(job.job_name):
			unlocked_jobs.append(job.job_name)
			Globals.notify("New Job Available: " + job.job_name, Color.CHARTREUSE)
		
		btn.text = "%s - $%s/mo" % [job.job_name, str(job.monthly_salary)]
		btn.disabled = false
		btn.modulate = Color.WHITE
	else:
		btn.text = "LOCKED: %s (Req: Lvl %d, %d Pts)" % [job.job_name, job.required_player_level, job.required_skill_points]
		btn.disabled = true
		btn.modulate = Color(1.0, 1.0, 1.0, 0.5) 

func get_player_points_for_category(cat: String) -> int:
	match cat:
		"Labor": return Globals.labor_points
		"Services": return Globals.services_points
		"Trade": return Globals.trade_points
		"Finance": return Globals.finance_points
		"Management": return Globals.management_points
	return 0

func _on_job_selected(job: JobData):
	Globals.job_income = job.monthly_salary
	Globals.current_job_name = job.job_name
	Globals.job_exp_per_month = job.Exp_gain_per_month
	Globals.jop_exp_gain_per_month = job.jop_exp_gain_per_month
	Globals.current_job_category = job.category
	description_label.text = "CURRENT JOB: %s\nINCOME: $%s/mo" % [
		job.job_name, 
		str(job.monthly_salary)
	]
	
	# Close panel after picking a job
	job_list_panel.visible = false
	refresh_timer.stop()

func update_stats():
	stats.text = "--- SKILLS ---\n"
	stats.text += "LABOR: %d pts\n" % Globals.labor_points
	stats.text += "SERVICES: %d pts\n" % Globals.services_points
	stats.text += "TRADE: %d pts\n" % Globals.trade_points
	stats.text += "FINANCE: %d pts\n" % Globals.finance_points
	stats.text += "MANAGEMENT: %d pts" % Globals.management_points

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
