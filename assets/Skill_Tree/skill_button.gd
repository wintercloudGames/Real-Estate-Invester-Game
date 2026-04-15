extends TextureButton
class_name SkillNode

@export_category("Skill Properties")
@export var max_level: int = 1
@export var skill_name: String = "Skill Name"
@export_multiline var skill_description: String = "Your skill description"
@export var level_costs: Array[int] = [1]

@export_category("App Skill to Unlock")
enum AppSkills { 
	HIRING_APP, INFO_APP, BANK_APP, MANAGER_APP, RENT_HOUSES, RENT_BOOST,
	UNLOCK_BUSINESS, HAS_MARKET_APP, JOB_MANAGER, JOB_MANAGER_LEVEL,
	JOB_BONUS, BUSINESS_BONUS, WORK_BONUS, WORK_AMOUNT, RENT_FINDER_UPGRADE,
	CREDIT_APP, STOCK_APP, EXP_BOOST, RENT_FINDER_BOOST, LABOR_POINTS,
	SERVICES_POINTS, TRADE_POINTS, FINANCE_POINTS, MANAGEMENT_POINTS
}
@export var app_skill_to_unlock: AppSkills = AppSkills.HIRING_APP

@export_category("Value Settings")
@export var rent_boost_amount: float = 0.05
@export var job_mod_amount: int = 1
@export var work_bonus_amount: float = 0.50
@export var work_amount:int = 1
@export var exp_boost:float = 0.50
var rent_finder_boost: float = 1.0
@export var points_per_level: int = 5 

@onready var skill_tree: Control = get_node_or_null("/root/Root/UserInterface/Game/HUD/UI/Skill_tree")
@onready var skill_level_label: Label = get_node_or_null("SkillLevel")
@onready var skill_branch: Line2D = get_node_or_null("SkillBranch")

var level: int = 0:
	set(value):
		var new_level = clampi(value, 0, max_level)
		if new_level != level:
			level = new_level
			_update_display()
			_unlock_app_skill()
			_update_visual_state()

var parent_skill: SkillNode = null
var is_mouse_over: bool = false
var _children_skills: Array[SkillNode] = []
var _is_initializing_from_globals: bool = false

# Mouse Cursors
var cursor_normal = load("res://assets/UI/mouse/hand_thin_point.png")
var cursor_hover = load("res://assets/UI/mouse/hand_thin_open.png")
var cursor_disabled = load("res://assets/UI/mouse/disabled.png")

func _ready() -> void:
	pivot_offset = size / 2
	
	# Ensure level costs array is correctly sized
	if level_costs.size() < max_level:
		level_costs.resize(max_level)
		for i in range(level_costs.size()):
			if level_costs[i] == 0: level_costs[i] = 1
	
	_find_child_skills()
	
	# Determine parent-child relationship
	var parent_node = get_parent()
	if parent_node is SkillNode:
		parent_skill = parent_node
		_connect_to_parent(parent_skill)

	# Performance: Listen for signal rather than using _process
	if not Globals.is_connected("skill_points_changed", _update_visual_state):
		Globals.connect("skill_points_changed", _update_visual_state)

	# Sync initial state
	await get_tree().process_frame
	_check_global_unlock_status()
	_update_visual_state()

func _find_child_skills() -> void:
	_children_skills.clear()
	for child in get_children():
		if child is SkillNode:
			_children_skills.append(child)

func _update_visual_state(_dummy_var = null) -> void:
	if not is_inside_tree() or not visible: return
	
	var parent_requirements_met = _check_parent_requirements()
	var has_enough_points = Globals.skillpoints >= get_next_level_cost()
		
	if level >= max_level:
		disabled = true
		self_modulate = Color.DARK_GREEN # Fully upgraded
	elif !parent_requirements_met:
		disabled = true
		self_modulate = Color.DIM_GRAY # Locked
	elif !has_enough_points:
		disabled = false 
		self_modulate = Color.CRIMSON # Can't afford
	else:
		disabled = false
		self_modulate = Color.WHITE # Ready to buy
	
	# Notify children that their parent state might have changed
	for child_skill in _children_skills:
		if is_instance_valid(child_skill):
			child_skill._update_visual_state()
func _check_global_unlock_status() -> void:
	_is_initializing_from_globals = true
	var new_level = level
	var p_per_lvl = max(1, points_per_level)

	match app_skill_to_unlock:
		# Boolean Unlocks (Max level if true)
		AppSkills.HIRING_APP: if Globals.has_hireing_app: new_level = max_level
		AppSkills.INFO_APP: if Globals.has_info_app: new_level = max_level
		AppSkills.BANK_APP: if Globals.has_bank_app: new_level = max_level
		AppSkills.MANAGER_APP: if Globals.has_manager_app: new_level = max_level
		AppSkills.RENT_HOUSES: if Globals.rent_houses: new_level = max_level
		AppSkills.UNLOCK_BUSINESS: if Globals.unlock_business: new_level = max_level
		AppSkills.HAS_MARKET_APP: if Globals.has_market_app: new_level = max_level
		AppSkills.JOB_MANAGER: if Globals.job_manager: new_level = max_level
		AppSkills.JOB_BONUS: if Globals.Job_bonus: new_level = max_level
		AppSkills.BUSINESS_BONUS: if Globals.business_bonus: new_level = max_level
		AppSkills.CREDIT_APP: if Globals.credit_app: new_level = max_level
		AppSkills.STOCK_APP: if Globals.has_stock_app: new_level = max_level
		AppSkills.RENT_FINDER_UPGRADE: if Globals.rent_finder_upgrade: new_level = max_level

		# Integer/Level Based Unlocks
		AppSkills.JOB_MANAGER_LEVEL: new_level = Globals.job_manager_level
		
		# Point/Stats Based (Calculated level)
		AppSkills.MANAGEMENT_POINTS: new_level = int(Globals.management_points / p_per_lvl)
		AppSkills.LABOR_POINTS: new_level = int(Globals.labor_points / p_per_lvl)
		AppSkills.SERVICES_POINTS: new_level = int(Globals.services_points / p_per_lvl)
		AppSkills.TRADE_POINTS: new_level = int(Globals.trade_points / p_per_lvl)
		AppSkills.FINANCE_POINTS: new_level = int(Globals.finance_points / p_per_lvl)
		
		# Multipliers and Boosts
		AppSkills.RENT_BOOST: 
			if rent_boost_amount > 0: new_level = int(Globals.rent_bost / rent_boost_amount)
		AppSkills.WORK_BONUS:
			if work_bonus_amount > 0: new_level = int(Globals.work_bonus / work_bonus_amount)
		AppSkills.WORK_AMOUNT:
			if work_amount > 0: new_level = int(Globals.work_amount / work_amount)
		AppSkills.EXP_BOOST:
			new_level = int((Globals.exp_boost - 1.0) / exp_boost)
		AppSkills.RENT_FINDER_BOOST:
			new_level = int((Globals.rent_finder_boost - 1.0) / rent_finder_boost)

	level = new_level
	_is_initializing_from_globals = false
	_update_display()
	_update_visual_state()

func _unlock_app_skill() -> void:
	match app_skill_to_unlock:
		# Boolean App Unlocks
		AppSkills.HIRING_APP: Globals.has_hireing_app = true
		AppSkills.INFO_APP: Globals.has_info_app = true
		AppSkills.BANK_APP: Globals.has_bank_app = true
		AppSkills.MANAGER_APP: Globals.has_manager_app = true
		AppSkills.STOCK_APP: Globals.has_stock_app = true
		AppSkills.RENT_HOUSES: Globals.rent_houses = true
		AppSkills.UNLOCK_BUSINESS: Globals.unlock_business = true
		AppSkills.HAS_MARKET_APP: Globals.has_market_app = true
		AppSkills.JOB_MANAGER: Globals.job_manager = true
		AppSkills.JOB_BONUS: Globals.Job_bonus = true
		AppSkills.BUSINESS_BONUS: Globals.business_bonus = true
		AppSkills.CREDIT_APP: Globals.credit_app = true
		AppSkills.RENT_FINDER_UPGRADE: Globals.rent_finder_upgrade = true

		# Level-based App Unlocks
		AppSkills.JOB_MANAGER_LEVEL: Globals.job_manager_level = level
		
		# Point Categories
		AppSkills.MANAGEMENT_POINTS: Globals.management_points = level * points_per_level
		AppSkills.LABOR_POINTS: Globals.labor_points = level * points_per_level
		AppSkills.FINANCE_POINTS: Globals.finance_points = level * points_per_level
		AppSkills.TRADE_POINTS: Globals.trade_points = level * points_per_level
		AppSkills.SERVICES_POINTS: Globals.services_points = level * points_per_level
		
		# Math-based Boosts
		AppSkills.RENT_BOOST: Globals.rent_bost = float(level) * rent_boost_amount
		AppSkills.WORK_BONUS: Globals.work_bonus = float(level) * work_bonus_amount
		AppSkills.WORK_AMOUNT: Globals.work_amount = level * work_amount
		AppSkills.EXP_BOOST: Globals.exp_boost = 1.0 + (float(level) * exp_boost)
		AppSkills.RENT_FINDER_BOOST: Globals.rent_finder_boost = 1.0 + (float(level) * rent_finder_boost)

func _on_pressed() -> void:
	if not _check_parent_requirements():
		Globals.notify("Locked: Need %s maxed!" % parent_skill.skill_name, Color.ORANGE)
		return
		
	var cost = get_next_level_cost()
	
	if level < max_level:
		if Globals.skillpoints >= cost:
			# THE CORE DEDUCTION LOGIC
			Globals.skillpoints -= cost
			level += 1
			
			_pulse_effect()
			Globals.notify("Unlocked: %s (Lvl %d)" % [skill_name, level], Color.SPRING_GREEN)
			
			if is_instance_valid(skill_tree) and skill_tree.has_method("on_skill_unlocked"):
				skill_tree.on_skill_unlocked(skill_name, cost)
		else:
			Globals.notify("Not enough points! Need %d" % cost, Color.CRIMSON)

func _connect_to_parent(parent_node: SkillNode) -> void:
	if not is_instance_valid(skill_branch): return
	await get_tree().process_frame
	var start_point = skill_branch.to_local(parent_node.global_position + (parent_node.size / 2))
	var end_point = skill_branch.to_local(global_position + (size / 2))
	skill_branch.points = PackedVector2Array([start_point, end_point])

func _update_display() -> void:
	if is_instance_valid(skill_level_label):
		skill_level_label.text = "%d / %d" % [level, max_level]

func _check_parent_requirements() -> bool:
	return true if parent_skill == null else parent_skill.level >= parent_skill.max_level

func get_next_level_cost() -> int:
	if level < level_costs.size():
		return level_costs[level]
	return 0

func _pulse_effect() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)

func _on_mouse_entered() -> void:
	is_mouse_over = true
	var hs = Vector2(24, 12)
	
	if level >= max_level or !_check_parent_requirements():
		Input.set_custom_mouse_cursor(cursor_disabled, Input.CURSOR_ARROW, hs)
	else:
		Input.set_custom_mouse_cursor(cursor_hover, Input.CURSOR_ARROW, hs)
	
	if is_instance_valid(skill_tree):
		_show_skill_info()

func _on_mouse_exited() -> void:
	var hs = Vector2(24, 12)
	is_mouse_over = false
	Input.set_custom_mouse_cursor(cursor_normal,Input.CURSOR_ARROW, hs)
	if is_instance_valid(skill_tree): 
		skill_tree.hide_info()

func _show_skill_info() -> void:
	var cost_val = get_next_level_cost()
	var cost_text = "Cost: %d pts" % cost_val if level < max_level else "Max Level Reached"
	var desc = skill_description
	
	if parent_skill and parent_skill.level < parent_skill.max_level:
		desc += "\n[Requires: %s]" % parent_skill.skill_name
		
	skill_tree.show_info(skill_name, desc, level, max_level, cost_text)
