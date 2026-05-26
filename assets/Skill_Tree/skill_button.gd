extends TextureButton
class_name SkillNode

# --- Export Categories ---
@export_group("Skill Properties")
@export var max_level: int = 1
@export var skill_name: String = "Skill Name"
@export_multiline var skill_description: String = "Your skill description"
@export var level_costs: Array[int] = [1]

@export_group("Selection Visuals")
@export var selected_color: Color = Color(1.8, 1.8, 1.8) # "Glow" effect
@export var locked_color: Color = Color.DIM_GRAY
@export var affordable_color: Color = Color.WHITE
@export var unaffordable_color: Color = Color.CRIMSON
@export var maxed_color: Color = Color.DARK_GREEN

@export_group("Value Settings")
@export var rent_boost_amount: float = 0.05
@export var job_mod_amount: int = 1
@export var work_bonus_amount: float = 0.50
@export var work_amount: int = 1
@export var exp_boost: float = 0.50
@export var rent_finder_boost: float = 1.0
@export var points_per_level: int = 5 

@export_group("Logic")
enum AppSkills { 
	HIRING_APP, INFO_APP, BANK_APP, MANAGER_APP, RENT_HOUSES, RENT_BOOST,
	UNLOCK_BUSINESS, HAS_MARKET_APP, JOB_MANAGER, JOB_MANAGER_LEVEL,
	JOB_BONUS, BUSINESS_BONUS, WORK_BONUS, WORK_AMOUNT, RENT_FINDER_UPGRADE,
	CREDIT_APP, STOCK_APP, EXP_BOOST, RENT_FINDER_BOOST, LABOR_POINTS,
	SERVICES_POINTS, TRADE_POINTS, FINANCE_POINTS, MANAGEMENT_POINTS
}
@export var app_skill_to_unlock: AppSkills = AppSkills.HIRING_APP

# --- Internal References ---
@onready var skill_tree: Control = get_node_or_null("/root/Root/UserInterface/Game/HUD/UI/Skill_tree")
@onready var skill_level_label: Label = get_node_or_null("SkillLevel")
@onready var skill_branch: Line2D = get_node_or_null("SkillBranch")

# --- Cursor Assets ---
var cursor_normal = load("res://assets/UI/mouse/hand_thin_point.png")
var cursor_hover = load("res://assets/UI/mouse/hand_thin_open.png")
var cursor_disabled = load("res://assets/UI/mouse/disabled.png")
var cursor_offset = Vector2(24, 12)

# --- State Variables ---
var level: int = 0:
	set(value):
		level = clampi(value, 0, max_level)
		_update_display()
		_update_visual_state()

var is_selected: bool = false:
	set(value):
		is_selected = value
		_update_visual_state()

var parent_skill: SkillNode = null
var _children_skills: Array[SkillNode] = []

# --- Initialization ---

func _ready() -> void:
	add_to_group("skill_nodes")
	pivot_offset = size / 2
	
	if level_costs.size() < max_level:
		level_costs.resize(max_level)
		for i in range(level_costs.size()):
			if level_costs[i] == 0: level_costs[i] = 1
	
	_find_child_skills()
	
	var parent_node = get_parent()
	if parent_node is SkillNode:
		parent_skill = parent_node
		_connect_to_parent(parent_skill)

	if not Globals.is_connected("skill_points_changed", _update_visual_state):
		Globals.connect("skill_points_changed", _update_visual_state)

	self.visibility_changed.connect(_on_visibility_changed)

	await get_tree().process_frame
	_check_global_unlock_status()

# --- Visual Logic ---

func _update_visual_state(_dummy_var = null) -> void:
	if not is_inside_tree() or not visible: return
	
	var parent_requirements_met = _check_parent_requirements()
	var has_enough_points = Globals.skillpoints >= get_next_level_cost()
	
	# Priority 1: Selection Glow (Using self_modulate to avoid affecting text/children)
	if is_selected:
		self_modulate = selected_color
	# Priority 2: Maxed Out
	elif level >= max_level:
		self_modulate = maxed_color
	# Priority 3: Locked by Parent
	elif !parent_requirements_met:
		self_modulate = locked_color
	# Priority 4: Can't Afford
	elif !has_enough_points:
		self_modulate = unaffordable_color
	# Priority 5: Ready to Buy
	else:
		self_modulate = affordable_color
	
	# Update children without passing the "selected" status
	for child_skill in _children_skills:
		if is_instance_valid(child_skill):
			child_skill._update_visual_state()

func _update_display() -> void:
	if is_instance_valid(skill_level_label):
		skill_level_label.text = "%d / %d" % [level, max_level]

func _pulse_effect() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
# --- Input & Selection ---

func _on_pressed() -> void:
	# Check if the device relies heavily on touch input
	var is_touch_device = DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN)

	if is_touch_device:
		# TOUCH LOGIC: 2-tap process
		if not is_selected:
			# FIRST TAP: Select and show info
			_deselect_all_nodes()
			is_selected = true 
			_show_skill_info()
			_pulse_effect()
			return
		
		# SECOND TAP: Attempt Purchase
		_attempt_unlock()
	else:
		# MOUSE LOGIC: 1-click bypasses selection completely
		_deselect_all_nodes()
		is_selected = true # Keep true so visuals update correctly during unlock
		_attempt_unlock()


func _attempt_unlock() -> void:
	if not _check_parent_requirements():
		Globals.notify("Locked: Need %s maxed!" % parent_skill.skill_name, Color.ORANGE)
		return
		
	if level >= max_level: return

	var cost = get_next_level_cost()
	if Globals.skillpoints >= cost:
		Globals.skillpoints -= cost
		level += 1
		_apply_permanent_unlock()
		_pulse_effect()
		_show_skill_info() # Update panel with new level info
		
		if is_instance_valid(skill_tree) and skill_tree.has_method("on_skill_unlocked"):
			skill_tree.on_skill_unlocked(skill_name, cost)
		Globals.notify("Unlocked: %s (Lvl %d)" % [skill_name, level], Color.SPRING_GREEN)
	else:
		Globals.notify("Not enough points! Need %d" % cost, Color.CRIMSON)

func _deselect_all_nodes() -> void:
	get_tree().call_group("skill_nodes", "set_selected_state", false)

func set_selected_state(value: bool) -> void:
	is_selected = value

func _show_skill_info() -> void:
	var cost_val = get_next_level_cost()
	var cost_text = "Cost: %d pts" % cost_val if level < max_level else "Max Level"
	var desc = skill_description
	
	if parent_skill and parent_skill.level < parent_skill.max_level:
		desc += "\n[Requires: %s]" % parent_skill.skill_name
	
	if is_instance_valid(skill_tree):
		skill_tree.show_info(skill_name, desc, level, max_level, cost_text)

# --- Cursor & Platform Logic ---

func _on_mouse_entered() -> void:
	# Avoid hover calculations executing on touch screens
	if DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN): return

	# Handle cursor changes
	var hs = cursor_offset
	if level >= max_level or !_check_parent_requirements():
		Input.set_custom_mouse_cursor(cursor_disabled, Input.CURSOR_ARROW, hs)
	else:
		Input.set_custom_mouse_cursor(cursor_hover, Input.CURSOR_ARROW, hs)
	
	# MOUSE HOVER FEATURE: Automatically show description details on pointer over
	_show_skill_info()


func _on_mouse_exited() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN): return

	Input.set_custom_mouse_cursor(cursor_normal, Input.CURSOR_ARROW, cursor_offset)
	
	# Hide info on exit since mouse doesn't rely on sticky selection states
	if is_instance_valid(skill_tree):
		skill_tree.hide_info()

func _on_visibility_changed() -> void:
	is_selected = false
	if is_instance_valid(skill_tree) and !visible:
		skill_tree.hide_info()

# --- Backend Logic ---

func _find_child_skills() -> void:
	_children_skills.clear()
	for child in get_children():
		if child is SkillNode:
			_children_skills.append(child)

func _check_parent_requirements() -> bool:
	return true if parent_skill == null else parent_skill.level >= parent_skill.max_level

func get_next_level_cost() -> int:
	return level_costs[level] if level < level_costs.size() else 0

func _connect_to_parent(parent_node: SkillNode) -> void:
	if not is_instance_valid(skill_branch): return
	await get_tree().process_frame
	var start_point = skill_branch.to_local(parent_node.global_position + (parent_node.size / 2))
	var end_point = skill_branch.to_local(global_position + (size / 2))
	skill_branch.points = PackedVector2Array([start_point, end_point])

func _check_global_unlock_status() -> void:
	var new_level = 0
	match app_skill_to_unlock:
		AppSkills.HIRING_APP: if Globals.has_hireing_app: new_level = max_level
		AppSkills.INFO_APP: if Globals.has_info_app: new_level = max_level
		AppSkills.BANK_APP: if Globals.has_bank_app: new_level = max_level
		AppSkills.MANAGER_APP: if Globals.has_manager_app: new_level = max_level
		AppSkills.STOCK_APP: if Globals.has_stock_app: new_level = max_level
		AppSkills.RENT_HOUSES: if Globals.rent_houses: new_level = max_level
		AppSkills.UNLOCK_BUSINESS: if Globals.unlock_business: new_level = max_level
		AppSkills.HAS_MARKET_APP: if Globals.has_market_app: new_level = max_level
		AppSkills.JOB_MANAGER: if Globals.job_manager: new_level = max_level
		AppSkills.CREDIT_APP: if Globals.credit_app: new_level = max_level
		AppSkills.RENT_FINDER_UPGRADE: if Globals.rent_finder_upgrade: new_level = max_level
		AppSkills.RENT_BOOST: if rent_boost_amount > 0: new_level = int(round(Globals.rent_bost / rent_boost_amount))
		AppSkills.WORK_BONUS: if work_bonus_amount > 0: new_level = int(round(Globals.work_bonus / work_bonus_amount))
		AppSkills.WORK_AMOUNT: if work_amount > 0: new_level = int(Globals.work_amount / work_amount)
		AppSkills.EXP_BOOST: new_level = int(round((Globals.exp_boost - 1.0) / exp_boost))
		AppSkills.RENT_FINDER_BOOST: new_level = int(round((Globals.rent_finder_boost - 1.0) / rent_finder_boost))
		AppSkills.LABOR_POINTS: new_level = Globals.labor_skill_points
		AppSkills.SERVICES_POINTS: new_level = Globals.services_skill_points
		AppSkills.TRADE_POINTS: new_level = Globals.trade_skill_points
		AppSkills.FINANCE_POINTS: new_level = Globals.finance_skill_points
		AppSkills.MANAGEMENT_POINTS: new_level = Globals.management_skill_points
	level = new_level

func _apply_permanent_unlock() -> void:
	match app_skill_to_unlock:
		AppSkills.HIRING_APP: Globals.has_hireing_app = true
		AppSkills.INFO_APP: Globals.has_info_app = true
		AppSkills.BANK_APP: Globals.has_bank_app = true
		AppSkills.MANAGER_APP: Globals.has_manager_app = true
		AppSkills.STOCK_APP: Globals.has_stock_app = true
		AppSkills.RENT_HOUSES: Globals.rent_houses = true
		AppSkills.UNLOCK_BUSINESS: Globals.unlock_business = true
		AppSkills.HAS_MARKET_APP: Globals.has_market_app = true
		AppSkills.JOB_MANAGER: Globals.job_manager = true
		AppSkills.CREDIT_APP: Globals.credit_app = true
		AppSkills.RENT_FINDER_UPGRADE: Globals.rent_finder_upgrade = true
		AppSkills.LABOR_POINTS:
			Globals.labor_skill_points = level
			Globals.labor_points += points_per_level
		AppSkills.SERVICES_POINTS:
			Globals.services_skill_points = level
			Globals.services_points += points_per_level
		AppSkills.TRADE_POINTS:
			Globals.trade_skill_points = level
			Globals.trade_points += points_per_level
		AppSkills.FINANCE_POINTS:
			Globals.finance_skill_points = level
			Globals.finance_points += points_per_level
		AppSkills.MANAGEMENT_POINTS:
			Globals.management_skill_points = level
			Globals.management_points += points_per_level
		AppSkills.RENT_BOOST: Globals.rent_bost = float(level) * rent_boost_amount
		AppSkills.WORK_BONUS: Globals.work_bonus = float(level) * work_bonus_amount
		AppSkills.WORK_AMOUNT: Globals.work_amount = level * work_amount
		AppSkills.EXP_BOOST: Globals.exp_boost = 1.0 + (float(level) * exp_boost)
		AppSkills.RENT_FINDER_BOOST: Globals.rent_finder_boost = 1.0 + (float(level) * rent_finder_boost)
