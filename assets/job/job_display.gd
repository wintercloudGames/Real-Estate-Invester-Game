extends Control


@onready var job_list_panel: TabContainer = $job_list
@onready var description_label = $Label
@onready var stats: Label = $Stats
var refresh_timer: Timer

const JOBS_FOLDER = "res://assets/job/jobs/"

func _ready():
	load_jobs_from_folder()
	job_list_panel.visible = false
	# Setup the Refresh Timer
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 2.0
	refresh_timer.autostart = false # Only start when panel is visible
	refresh_timer.timeout.connect(update_job_buttons) # Call your update function
	add_child(refresh_timer)
	if Globals.current_job_name != "Unemployed":
		description_label.text = "CURRENT JOB: %s\nINCOME: $%s/mo" % [Globals.current_job_name, Globals.job_income]
	else:
		description_label.text = "You are currently unemployed."

func load_jobs_from_folder():
	# 1. Clear existing buttons from all categories
	for category_node in job_list_panel.get_children():
		var container = category_node.get_node_or_null("VBoxContainer")
		if container:
			for child in container.get_children():
				child.queue_free()

	var categories = ["labor", "services", "trade", "finance", "management"]
	
	for cat in categories:
		var dir = DirAccess.open(JOBS_FOLDER)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				# Check for the actual file or the remapped version Godot creates on export
				if file_name.begins_with(cat) and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
					var clean_path = JOBS_FOLDER + file_name.replace(".remap", "")
					var job_res = load(clean_path)
					if job_res is JobData:
						create_job_button(job_res)
				file_name = dir.get_next()

func create_job_button(job: JobData):
	var container_path = "job_list/" + job.category + "/VBoxContainer"
	var target_container = get_node_or_null(container_path)
	
	if not target_container:
		return

	var btn = Button.new()
	btn.set_meta("job_data", job) 
	var player_points = get_player_points_for_category(job.category)
	
	var level_met = Globals.level >= job.required_player_level
	var skill_met = player_points >= job.required_skill_points
	

	if not level_met or not skill_met:
		btn.text = "LOCKED: %s (Req: Lvl %d, %d Pts)" % [job.job_name, job.required_player_level, job.required_skill_points]
		btn.disabled = true
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0) 
	else:
		btn.text = "%s - $%s/mo" % [job.job_name, str(job.monthly_salary)]
	
	btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_job_selected.bind(job))
	target_container.add_child(btn)
	
func update_job_buttons():
	# Loop through all category folders in your UI
	for category_node in job_list_panel.get_children():
		var container = category_node.get_node_or_null("VBoxContainer")
		if container:
			for btn in container.get_children():
				# We stored the job data in the button metadata when we created it
				var job = btn.get_meta("job_data")
				if job is JobData:
					var player_points = get_player_points_for_category(job.category)
					var level_met = Globals.level >= job.required_player_level
					var skill_met = player_points >= job.required_skill_points
					
					if not level_met or not skill_met:
						btn.text = "LOCKED: %s (Req: Lvl %d, %d Pts)" % [job.job_name, job.required_player_level, job.required_skill_points]
						btn.disabled = true
						btn.modulate = Color(1.0, 1.0, 1.0, 1.0) 
					else:
						btn.text = "%s - $%s/mo" % [job.job_name, str(job.monthly_salary)]
						btn.disabled = false
						btn.modulate = Color.WHITE

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

	description_label.text = "CURRENT JOB: %s\nINCOME: $%s/mo" % [
		job.job_name, 
		str(job.monthly_salary)
	]
	
	job_list_panel.visible = false

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
		refresh_timer.start() # Start checking every 2 seconds
	else:
		refresh_timer.stop() # Stop checking to save resources

func _on_close_button_pressed() -> void:
	visible = false
	job_list_panel.visible = false
	update_stats()

func _on_show_job_display_pressed() -> void:
	self.visible = !self.visible
	job_list_panel.visible = false
	update_stats()
