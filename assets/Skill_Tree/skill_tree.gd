extends Control

@onready var description_panel: Panel = $DescriptionPanel
@onready var description_label: Label = $DescriptionPanel/DescriptionLabel
@onready var skill_name_label: Label = $DescriptionPanel/Skill_name

@onready var skill_points_label: Label = $Skill_points_label
@onready var exp_to_level: Label = $Exp_to_level
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var level_label: Label = $Level_label

func _ready() -> void:
	hide_info()
	
	# Connect to Global signals for automatic UI updates
	if not Globals.is_connected("skill_points_changed", _update_skill_points_display):
		Globals.connect("skill_points_changed", _update_skill_points_display)
	
	# Initial UI sync
	_update_skill_points_display()
	_update_progress_bar()

# --- REMOVED _PROCESS ---
# We use signals now. This saves a lot of CPU power.

func show_info(skill_name: String, info: String, current_level: int = 0, max_level: int = 0, cost_info: String = "") -> void:
	if not description_panel: return
	
	var formatted_info = info
	if max_level > 0:
		formatted_info += "\n\nLevel: " + str(current_level) + "/" + str(max_level)
	if cost_info != "":
		formatted_info += "\n" + cost_info
	
	description_label.text = formatted_info
	skill_name_label.text = skill_name
	description_panel.visible = true
	

func hide_info() -> void:
	if is_instance_valid(description_panel):
		description_panel.visible = false


func _update_skill_points_display() -> void:
	if is_instance_valid(skill_points_label):
		skill_points_label.text = "Skill Points: " + str(Globals.skillpoints)
	
	# Always update progress and level when points/exp change
	_update_progress_bar()

func _update_progress_bar() -> void:
	if is_instance_valid(progress_bar):
		progress_bar.max_value = Globals.exp_to_level
		progress_bar.value = Globals.EXP
		
	if is_instance_valid(level_label):
		level_label.text = "Level: " + str(Globals.level)
		
	if is_instance_valid(exp_to_level):
		exp_to_level.text = "%.1f / %d" % [Globals.EXP, Globals.exp_to_level]

func _on_close_button_pressed() -> void:
	visible = false

func on_skill_unlocked(_skill_name: String, _cost: int) -> void:
	_update_skill_points_display()

func _on_visibility_changed() -> void:
	if visible:
		_update_skill_points_display()
		_update_progress_bar()

func _on_cheat_button_pressed() -> void:
	Globals.EXP += 50
