extends Control

@onready var job_list_panel: TabContainer = $job_list
@onready var description_label = $Label
@onready var stats: Label = $VBoxContainer/Stats
@onready var SFX = $AudioStreamPlayer
# Persistent layout button references for explicit hover hooking
@onready var close_button:Button = $Close_Button
@onready var job_list_button: Button = $job_list_button

# Only one single progress bar to handle the active job category tracking
@export var active_job_bar: ProgressBar

var refresh_timer: Timer
var work_timer: Timer 
const JOBS_FOLDER = "res://assets/job/jobs/"
var unlocked_jobs: Array[String] = []

func _ready():
	initialize_known_jobs()
	load_jobs_from_folder()
	job_list_panel.visible = false
	
	if not Globals.is_connected("stats_changed", update_stats):
		Globals.connect("stats_changed", update_stats)
	
	# Connect base hover triggers dynamically to structural layout items on load
	_connect_base_hover_sounds()
	
	# Dynamic structural trigger when switching tabs (Labor, Services, etc.)
	if not job_list_panel.tab_changed.is_connected(_on_job_tab_changed):
		job_list_panel.tab_changed.connect(_on_job_tab_changed)
	
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 2.0
	refresh_timer.timeout.connect(update_job_buttons) 
	add_child(refresh_timer)

	work_timer = Timer.new()
	work_timer.wait_time = 5.0 
	work_timer.timeout.connect(process_work_tick)
	add_child(work_timer)
	work_timer.start() 
	
	update_stats()

# Helper to bind clean pointer behavior directly into structural nodes
func _connect_base_hover_sounds() -> void:
	var base_items = [close_button, job_list_button]
	for item in base_items:
		if is_instance_valid(item) and not item.mouse_entered.is_connected(_on_ui_element_hovered):
			item.mouse_entered.connect(_on_ui_element_hovered)

func _on_ui_element_hovered() -> void:
	SFX.play_sound("hover")

func _on_job_tab_changed(_tab_index: int) -> void:
	# Swoosh style interface sound when clicking through active tracks
	SFX.play_sound("click", 0.9)

func process_work_tick():
	if Globals.current_job_name == "Unemployed" or not Globals.has_car:
		return
		
	var total_multiplier = 1.0 + Globals.exp_boost
	var gain = Globals.job_exp_gain_per_month * total_multiplier

	match Globals.current_job_category:
		"Labor": Globals.labor_points += gain
		"Services": Globals.services_points += gain
		"Trade": Globals.trade_points += gain
		"Finance": Globals.finance_points += gain
		"Management": Globals.management_points += gain
	
	var current_points = get_player_points_for_category(Globals.current_job_category)
	if int(current_points) > int(current_points - gain):
		Globals.check_for_new_unlocks() 

	update_stats()
	Globals.emit_signal("stats_changed")

func update_stats():
	if Globals.current_job_name != "Unemployed":
		description_label.text = "CURRENT JOB: %s\nINCOME: $%s/mo" % [Globals.current_job_name, str(Globals.job_income)]
		
		var category = Globals.current_job_category
		var total_points = get_player_points_for_category(category)
		
		var whole_levels = int(total_points)
		var progress = total_points - float(whole_levels)
		var exp_percent = int(snapped(progress, 0.01) * 100)
		
		stats.text = "Category: %s\nPTS: %d | EXP: %d%%" % [category.to_upper(), whole_levels, exp_percent]
	
		if is_instance_valid(active_job_bar):
			active_job_bar.visible = true
			active_job_bar.max_value = 1.0
			active_job_bar.value = progress
	else:
		description_label.text = "You are currently unemployed."
		stats.text = "TRACK: NONE\nLVL: 0 | EXP: 0%"
		
		if is_instance_valid(active_job_bar):
			active_job_bar.value = 0.0
			active_job_bar.visible = false

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
	
	# Binds the button instance directly into our filtered validation checker
	btn.mouse_entered.connect(_on_job_button_hovered.bind(btn))
	
	target_container.add_child(btn)

func _on_job_button_hovered(btn: Button) -> void:
	if is_instance_valid(btn):
		var job = btn.get_meta("job_data")
		if job is JobData:
			var player_points = int(get_player_points_for_category(job.category))
			var level_met = Globals.level >= job.required_player_level
			var skill_met = player_points >= job.required_skill_points
			
			# Filter: ONLY play hover tick if career is unlocked
			if level_met and skill_met:
				SFX.play_sound("hover")

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
		if not Globals.unlocked_jobs.has(job.job_name):
			Globals.unlocked_jobs.append(job.job_name)
			if Globals.first_start == false: 
				Globals.notify("New Job Available: " + job.job_name, Color.CHARTREUSE)
				SFX.play_sound("success", 1.15) 
		
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
	var player_points = int(get_player_points_for_category(job.category))
	var level_met = Globals.level >= job.required_player_level
	var skill_met = player_points >= job.required_skill_points
	
	# Block selection actions and play an error sound if requirements aren't met
	if not (level_met and skill_met):
		SFX.play_sound("error", 0.95) # Low-pitched error tone for rejection
		return

	# If they qualify, accept the job normally
	Globals.job_income = job.monthly_salary
	Globals.current_job_name = job.job_name
	Globals.job_exp_per_month = job.Exp_gain_per_month
	Globals.job_exp_gain_per_month = job.job_exp_gain_per_month
	Globals.current_job_category = job.category
	
	job_list_panel.visible = false
	refresh_timer.stop()
	update_stats()
	
	SFX.play_sound("success", 1.0) # Reward sound for successful employment change

func _on_apply_for_job_pressed() -> void:
	job_list_panel.visible = !job_list_panel.visible
	SFX.play_sound("click", 1.0)
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
	SFX.play_sound("click", 0.85) 

func _on_show_job_display_pressed() -> void:
	self.visible = !self.visible
	SFX.play_sound("click", 1.02)
	if not self.visible:
		job_list_panel.visible = false
		refresh_timer.stop()
	update_stats()
