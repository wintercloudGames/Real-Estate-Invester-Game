extends Control

@onready var description_panel: Panel = $DescriptionPanel
@onready var description_label: Label = $DescriptionPanel/DescriptionLabel
@onready var skill_name_label: Label = $DescriptionPanel/Skill_name

@onready var skill_points_label: Label = $Skill_points_label

func _ready() -> void:
	hide_info()
	
	_update_skill_points_display()

func _process(delta: float) -> void:
	$ProgressBar.value = Globals.exp
	$ProgressBar.max_value = Globals.exp_to_level
	$Level_label.text = "Level: " + str(Globals.level) 
	_update_skill_points_display()

func show_info(skill_name: String, info: String, current_level: int = 0, max_level: int = 0, cost_info: String = "") -> void:
	if not description_panel:
		push_error("DescriptionPanel not found! Check scene structure.")
		return
	
	# Build formatted info text
	var formatted_info = info
	
	if max_level > 0:
		formatted_info += "\n\nLevel: " + str(current_level) + "/" + str(max_level)
	
	if cost_info != "":
		formatted_info += "\n" + cost_info
	
	# Update UI elements
	description_label.text = formatted_info
	skill_name_label.text = skill_name
	
	# Show and position the panel
	description_panel.visible = true
	_position_panel_near_mouse()

func hide_info() -> void:
	if description_panel:
		description_panel.visible = false

func _position_panel_near_mouse() -> void:
	var mouse_pos = get_global_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Position panel near mouse with offset
	var panel_pos = mouse_pos + Vector2(20, 20)
	
	# Ensure panel stays within screen bounds
	if panel_pos.x + description_panel.size.x > viewport_size.x:
		panel_pos.x = max(20, viewport_size.x - description_panel.size.x - 20)
	
	if panel_pos.y + description_panel.size.y > viewport_size.y:
		panel_pos.y = max(20, viewport_size.y - description_panel.size.y - 20)
	
	description_panel.position = panel_pos - global_position

func _on_close_button_pressed() -> void:
	visible = false

func on_skill_unlocked(skill_name: String, cost: int) -> void:
	# This is just for UI updates, points are already deducted by SkillNode
	_update_skill_points_display()  # Refresh the UI display

func add_skill_points(amount: int) -> void:
	Globals.skillpoints += amount
	_update_skill_points_display()  # Update UI if needed

func _update_skill_points_display() -> void:
	if skill_points_label:
		skill_points_label.text = "Skill Points: " + str(Globals.skillpoints)

# Optional: Refresh display when skill tree is shown
func _on_visibility_changed() -> void:
	if visible:
		_update_skill_points_display()

func _on_cheat_button_pressed() -> void:
	Globals.exp += 50
