extends TextureButton
class_name SkillNode

@export_category("Skill Properties")
@export var max_level: int = 1
@export var skill_name: String = "Skill Name"
@export_multiline var skill_description: String = "Your skill description"
@export var level_costs: Array[int] = [1]

@export_category("App Skill to Unlock")
enum AppSkills { 
	HIRING_APP,
	INFO_APP,
	BANK_APP,
	MANAGER_APP,
	RENT_HOUSES,
	RENT_BOOST,
	UNLOCK_BUSINESS,
	HAS_MARKET_APP,
	JOB_MANAGER,
	JOB_MANAGER_LEVEL,
	JOB_BONUS,
	BUSINESS_BONUS,
	WORK_BONUS,
	WORK_AMOUNT,
	RENT_FINDER_UPGRADE,
	CREDIT_APP,
	STOCK_APP,
	EXP_BOOST,
	RENT_FINDER_BOOST,
	LABOR_POINTS,
	SERVICES_POINTS,
	TRADE_POINTS,
	FINANCE_POINTS,
	MANAGEMENT_POINTS
}
@export var app_skill_to_unlock: AppSkills = AppSkills.HIRING_APP

var _is_initializing_from_globals: bool = false

@export_category("int and float Settings")
@export var rent_boost_amount: float = 0.05
@export var job_mod_amount: int = 1
@export var work_bonus_amount: float = 0.50
@export var work_amount:int = 1
@export var exp_boost:float = 0.50
@export var rent_finder_boost:float = -0.10
@export var points_per_level: int = 5 

@export_category("Visual Settings")
@export var unlocked_color: Color = Color.WHITE
@export var level_colors: Array[Color] = [Color.GRAY, Color.DARK_GREEN]

@onready var skill_tree: Control = get_node("/root/Root/UserInterface/Game/HUD/UI/Skill_tree")
@onready var skill_level_label: Label = $SkillLevel
@onready var skill_branch: Line2D = $SkillBranch

var level: int = 0:
	set(value):
		var new_level = clampi(value, 0, max_level)
		if new_level != level:
			level = new_level
			_update_display()
			_update_visual_state()
			_unlock_app_skill()

var parent_skill: SkillNode = null
var is_mouse_over: bool = false
var _children_skills: Array[SkillNode] = []

func _ready() -> void:
	# Ensure pivot is centered for the pulse effect
	pivot_offset = size / 2
	
	_update_display()
	_update_visual_state()
	
	if level_costs.size() < max_level:
		level_costs.resize(max_level)
		for i in range(level_costs.size()):
			if level_costs[i] == 0:
				level_costs[i] = 1
	
	_find_child_skills()
	await get_tree().process_frame
	_check_global_unlock_status()
	visibility_changed.connect(_on_visibility_changed)
	
	var parent_node = get_parent()
	if parent_node is SkillNode:
		parent_skill = parent_node
		_connect_to_parent(parent_skill)

func _find_child_skills() -> void:
	_children_skills.clear()
	for child in get_children():
		if child is SkillNode:
			_children_skills.append(child)

func _on_visibility_changed() -> void:
	if visible:
		_update_display()
		_update_visual_state()

func _check_global_unlock_status() -> void:
	_is_initializing_from_globals = true
	var should_update_level = false
	var new_level = level

	match app_skill_to_unlock:
		AppSkills.HIRING_APP: if Globals.has_hireing_app: new_level = max_level; should_update_level = true
		AppSkills.INFO_APP: if Globals.has_info_app: new_level = max_level; should_update_level = true
		AppSkills.BANK_APP: if Globals.has_bank_app: new_level = max_level; should_update_level = true
		AppSkills.MANAGER_APP: if Globals.has_manager_app: new_level = max_level; should_update_level = true
		AppSkills.RENT_HOUSES: if Globals.rent_houses: new_level = max_level; should_update_level = true
		AppSkills.UNLOCK_BUSINESS: if Globals.unlock_business: new_level = max_level; should_update_level = true
		AppSkills.HAS_MARKET_APP: if Globals.has_market_app: new_level = max_level; should_update_level = true
		AppSkills.JOB_MANAGER: if Globals.job_manager: new_level = max_level; should_update_level = true
		AppSkills.JOB_BONUS: if Globals.Job_bonus: new_level = max_level; should_update_level = true
		AppSkills.BUSINESS_BONUS: if Globals.business_bonus: new_level = max_level; should_update_level = true
		AppSkills.CREDIT_APP: if Globals.credit_app: new_level = max_level; should_update_level = true
		AppSkills.STOCK_APP: if Globals.has_stock_app: new_level = max_level; should_update_level = true
		AppSkills.RENT_FINDER_UPGRADE: if Globals.rent_finder_upgrade: new_level = max_level; should_update_level = true
		
		AppSkills.LABOR_POINTS:
			new_level = int(Globals.labor_points / points_per_level)
			should_update_level = true
		AppSkills.SERVICES_POINTS:
			new_level = int(Globals.services_points / points_per_level)
			should_update_level = true
		AppSkills.TRADE_POINTS:
			new_level = int(Globals.trade_points / points_per_level)
			should_update_level = true
		AppSkills.FINANCE_POINTS:
			new_level = int(Globals.finance_points / points_per_level)
			should_update_level = true
		AppSkills.MANAGEMENT_POINTS:
			new_level = int(Globals.management_points / points_per_level)
			should_update_level = true

		AppSkills.WORK_AMOUNT:
			if work_amount > 0:
				new_level = min(int(Globals.work_amount / work_amount), max_level)
				should_update_level = true
		AppSkills.WORK_BONUS:
			if work_bonus_amount > 0:
				new_level = min(int(Globals.work_bonus / work_bonus_amount), max_level)
				should_update_level = true
		AppSkills.EXP_BOOST:
			if Globals.exp_boost > 1.0:
				new_level = min(int((Globals.exp_boost - 1.0) / exp_boost), max_level)
				should_update_level = true
		AppSkills.JOB_MANAGER_LEVEL:
			if job_mod_amount > 0:
				new_level = min(int(Globals.job_manager_level / job_mod_amount), max_level)
				should_update_level = true
	
	if should_update_level:
		level = new_level
	_update_display()
	_update_visual_state()
	_is_initializing_from_globals = false

func _unlock_app_skill() -> void:
	if level == 0 or _is_initializing_from_globals:
		return
	
	match app_skill_to_unlock:
		AppSkills.HIRING_APP: Globals.has_hireing_app = true
		AppSkills.INFO_APP: Globals.has_info_app = true
		AppSkills.BANK_APP: 
			Globals.has_bank_app = true
			Globals.notify("New App: Bank Access unlocked!", Color.CYAN)
		AppSkills.STOCK_APP: 
			Globals.has_stock_app = true
			Globals.notify("New App: Stock Market unlocked!", Color.GOLD)
		AppSkills.MANAGER_APP: 
			Globals.has_manager_app = true
			Globals.notify("New Feature: Property Manager available.", Color.AQUAMARINE)
		AppSkills.CREDIT_APP: Globals.credit_app = true
		AppSkills.RENT_HOUSES: Globals.rent_houses = true
		AppSkills.RENT_FINDER_UPGRADE: Globals.rent_finder_upgrade = true
		AppSkills.UNLOCK_BUSINESS: Globals.unlock_business = true
		AppSkills.HAS_MARKET_APP: Globals.has_market_app = true
		AppSkills.JOB_MANAGER: Globals.job_manager = true
		AppSkills.JOB_BONUS: Globals.Job_bonus = true
		AppSkills.BUSINESS_BONUS: Globals.business_bonus = true
		
		AppSkills.LABOR_POINTS: Globals.labor_points = level * points_per_level
		AppSkills.SERVICES_POINTS: Globals.services_points = level * points_per_level
		AppSkills.TRADE_POINTS: Globals.trade_points = level * points_per_level
		AppSkills.FINANCE_POINTS: Globals.finance_points = level * points_per_level
		AppSkills.MANAGEMENT_POINTS: Globals.management_points = level * points_per_level
		
		AppSkills.EXP_BOOST: Globals.exp_boost = 1.0 + (exp_boost * level)
		AppSkills.RENT_FINDER_BOOST: Globals.rent_finder_boost = 1.0 + (rent_finder_boost * level)
		AppSkills.WORK_BONUS: Globals.work_bonus = work_bonus_amount * level
		AppSkills.WORK_AMOUNT: Globals.work_amount = work_amount * level
		AppSkills.JOB_MANAGER_LEVEL: Globals.job_manager_level = job_mod_amount * level

func _connect_to_parent(parent_node: SkillNode) -> void:
	if not skill_branch: return
	var start_point: Vector2 = skill_branch.to_local(parent_node.global_position + parent_node.size / 2)
	var end_point: Vector2 = skill_branch.to_local(global_position + size / 2)
	skill_branch.clear_points()
	skill_branch.add_point(start_point)
	skill_branch.add_point(end_point)

func _update_display() -> void:
	if skill_level_label:
		skill_level_label.text = str(level) + "/" + str(max_level)

func _update_visual_state() -> void:
	if not is_inside_tree(): return
	
	var parent_requirements_met = _check_parent_requirements()
	var has_enough_points = Globals.skillpoints >= get_next_level_cost()
	
	if level >= max_level:
		disabled = true
		self_modulate = Color.DARK_GREEN
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif !parent_requirements_met:
		disabled = true
		self_modulate = Color.DARK_GRAY
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	elif !has_enough_points:
		disabled = false # Keep it clickable so we can show the "Not enough points" notification
		self_modulate = Color.DARK_RED
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		disabled = false
		self_modulate = Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	_update_children_visuals()

func _update_children_visuals() -> void:
	for child_skill in _children_skills:
		if is_instance_valid(child_skill):
			child_skill._update_visual_state()

func _check_parent_requirements() -> bool:
	if parent_skill == null: return true
	return parent_skill.level >= parent_skill.max_level

func _on_pressed() -> void:
	var cost = get_next_level_cost()
	
	# 1. Check Parent Req
	if not _check_parent_requirements():
		Globals.notify("Locked: Max out " + parent_skill.skill_name + " first!", Color.ORANGE)
		return
		
	# 2. Check Level Cap
	if not can_level_up():
		return

	# 3. Check Points
	if Globals.skillpoints < cost:
		Globals.notify("Not enough points! Need " + str(cost), Color.CRIMSON)
		return

	# 4. Success Logic
	Globals.skillpoints -= cost
	level += 1
	
	Globals.notify("Unlocked: " + skill_name + " (Lvl " + str(level) + ")", Color.SPRING_GREEN)
	
	if skill_tree and skill_tree.has_method("on_skill_unlocked"):
		skill_tree.on_skill_unlocked(skill_name, cost)
	
	_pulse_effect()

func can_level_up() -> bool: return level < max_level

func _pulse_effect() -> void:
	var tween = create_tween()
	# Bind tween to self for safety
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	
func get_next_level_cost() -> int:
	if level < level_costs.size(): return level_costs[level]
	return 1

func _on_mouse_entered() -> void:
	is_mouse_over = true
	await get_tree().create_timer(0.05).timeout
	if is_mouse_over and skill_tree and skill_tree.has_method("show_info"): _show_skill_info()

func _on_mouse_exited() -> void:
	is_mouse_over = false
	await get_tree().create_timer(0.05).timeout
	if not is_mouse_over and skill_tree and skill_tree.has_method("hide_info"): skill_tree.hide_info()

func _show_skill_info() -> void:
	var cost_text = "Cost: " + str(get_next_level_cost()) + " skill points" if level < max_level else "Already Unlocked"
	var requirement_text = ""
	if level < max_level and parent_skill != null and parent_skill.level < parent_skill.max_level:
		requirement_text = "\nRequires: " + parent_skill.skill_name + " (Max Level)"
	
	var description = skill_description
	if requirement_text != "": description += requirement_text
	skill_tree.show_info(skill_name, description, level, max_level, cost_text)

func _on_timer_timeout() -> void:
	_update_display()
	_update_visual_state()
