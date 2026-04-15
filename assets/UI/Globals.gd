extends Node

signal month_ended
signal money_in_detect(in_value)
signal money_out_detect(out_value)
signal skill_points_changed 
signal stats_changed

var money = 0
var ai_money = 10000000
var brokerage_balance: float = 0.0
var Propertys = 0
var credit_score = 600
var credit_history: Array = [600]
var portfolio: Dictionary = {} 
var all_stocks: Array = []
var listed_houses = 0
var first_start = false
var active_loans: Array = []
var save_name: String = "My Save"
var has_car = true
var car_level = 1
var net_worth = 0
var Savings_balance = 0
var last_savings_paid = 0
var market_factor: float = 1.0
var year:int = 1
var month:int = 1
var total_debt: float = 0.0

#Job vars
var current_job_name: String = "Unemployed"
var current_job_category: String = "None"
var job_exp_per_month: float = 10
var jop_exp_gain_per_month = 0
var job_income: float = 0.0

#mission vars
var mission_templates = [
	{"type": "houses",       "min_target": 5,  "max_target": 50,  "min_deadline": 5,  "max_deadline": 30, "desc_base": "Own %d houses"},
	{"type": "tenants",      "min_target": 5, "max_target": 25, "min_deadline": 6,  "max_deadline": 25, "desc_base": "%d houses with tenants"},
	{"type": "net_worth",    "min_target": 50000,  "max_target": 5000000, "min_deadline": 7,  "max_deadline": 20, "desc_base": "Net Worth $%s"},
	{"type": "business_rank","min_target": 3,  "max_target": 20,  "min_deadline": 8,  "max_deadline": 25, "desc_base": "Business Rank %d"},
	{"type": "credit_max",   "min_target": 700, "max_target": 850, "min_deadline": 5,  "max_deadline": 15, "desc_base": "Credit Score %d"},
]

var mission_active: bool = false
var mission_type: String = ""
var mission_target: int = 0  # int for most; net_worth can be float→int
var mission_deadline_year: int = 999
var mission_desc: String = ""  # Formatted desc (e.g. "Own 23 houses")
var mission_completed: bool = false

var total_loan_amount = 0
var total_property_value: int = 0:
	set(value):
		total_property_value = value
		stats_changed.emit() # This tells the UI to update!
var houses_with_tenants: int = 0:
	set(value):
		houses_with_tenants = value
		stats_changed.emit()
var Income = 0
var Expenses = 0
var cashflow = 0
var save_slot = 1
var send_to_account:bool = false
var Editing_Business_Text:bool= false
var negative_month_count = 0
var wallpaper = ""
var yard_edit = false

var skillpoints: int = 1
var EXP: float = 0.0:
	set(value):
		EXP = value
		emit_signal("skill_points_changed") # This refreshes the bar and labels
var exp_to_level: int = 100
var level: int = 1
# Skills to unlock
var has_hireing_app: bool = false
var has_info_app: bool = false
var has_bank_app: bool = false
var has_manager_app: bool = false
var has_stock_app = false
var rent_bost: float = 0.00
var rent_houses: bool = false
var unlock_business: bool = false
var has_market_app:bool = false
var job_manager:bool = false
var job_manager_level:int = 0
var rent_finder_upgrade = false
var Job_bonus = false
var work_bonus = 0.00
var work_amount = 0
var exp_boost = 1.0
var rent_finder_boost = 1.0
var credit_app = false
	#job category Skills
var labor_points = 0
var services_points = 0
var trade_points = 0
var finance_points = 0
var management_points = 0

var difficulty:int = 1

var hasagent = false
var hascleaner = false
var renter_finder = false

func reset():
	money = 0
	Propertys = 0
	credit_score = 600
	year = 1
	car_level = 1
	job_income = 0
	current_job_name = "Unemployed"
	job_exp_per_month = 10
	month = 1
	Savings_balance = 0
	listed_houses = 0
	net_worth = 0
	wallpaper = ""
	total_loan_amount = 0
	houses_with_tenants = 0
	Income = 0
	Expenses = 1000
	cashflow = 0
	first_start = false
	business_name = ""
	Business_worth = 30000
	max_job_time = 0
	job_pay = 0
	job_time = 0
	employees = 0
	hasagent = false
	hascleaner = false
	renter_finder = false

	#Misson mode
	mission_active = false
	mission_type = ""
	mission_target = 0
	mission_deadline_year = 999
	mission_completed = false
	
	#skills
	skillpoints = 1
	EXP = 0
	exp_to_level = 100
	level = 1
	has_hireing_app = false
	has_info_app = false
	has_bank_app = false
	has_stock_app = false
	has_manager_app = false
	rent_bost = 0.00
	
	#job category Skills
	labor_points = 0
	services_points = 0
	trade_points = 0
	finance_points = 0
	management_points = 0
	
	rent_houses = false
	unlock_business = false
	has_market_app = false
	job_manager = false
	job_manager_level = 0
	Job_bonus = false
	business_bonus = false
	work_bonus = 0
	work_amount = 0
	rent_finder_upgrade = false
	credit_app = false
	has_stock_app = false
	exp_boost = 1.0
	rent_finder_boost = 1.0


#Businessinfo
var business_name = ""
var Business_worth = 0
var employees = 0
var max_job_time = 0
var job_time = 0
var job_pay = 0
var business_bonus = false
#player stats
var Player_health = 100
var Player_hunger = 100
var Player_comfort = 100

var interest_rate = 0.005
var normal_loan_added = false

var interest = Savings_balance * interest_rate
var player_has_employees: bool = false


func handle_overflow(current_value: float, add_amount: float, max_value: float) -> Dictionary:
	var total = current_value + add_amount
	var overflow = max(0, total - max_value)
	var new_value = total

	if overflow > 0:
		new_value = add_amount - overflow  # Reset with the overflow amount
		if new_value < 0:
			new_value = 0

	return {
		"new_value": new_value,
		"carryover": overflow,
		"overflowed": overflow > 0
	}

func record_credit_score():
	credit_history.append(credit_score)
	# Keep only the last 20 entries to prevent the graph from getting too crowded
	if credit_history.size() > 15:
		credit_history.pop_front()

func _process(_delta: float) -> void:
	if EXP >= exp_to_level:
		var overflow = EXP - exp_to_level
		EXP = overflow
		skillpoints += 1
		exp_to_level += 10
		level += 1

	EXP = max(0, EXP)

	cashflow = Income - Expenses
	clamp_stats()
	Player_health -= 0.0001
	if year > 50:
		Player_health -= 0.0005
	else:
		Player_health -= 0.0001
	Player_hunger -= 0.0005
	Player_comfort -= 0.0005
	interest = Savings_balance * interest_rate
	credit_score = clamp(credit_score, 300, 850)
	last_savings_paid = interest

# Generate random mission (call on new game)
func generate_random_mission():
	var template = mission_templates[randi() % mission_templates.size()]
	var difficulty_mult = [1.0, 1.2, 1.5, 2.0][difficulty]  # Easy=1x, Nightmare=2x harder

	mission_type = template.type
	mission_target = randi_range(template.min_target, template.max_target) * int(difficulty_mult)

	# Generate base deadline
	var base_deadline = randi_range(template.min_deadline, template.max_deadline)

	# Make it relative to current year + safety minimum
	mission_deadline_year = Globals.year + base_deadline
	mission_deadline_year = max(Globals.year + 5, mission_deadline_year)  # never allow instant or very soon fail

	# Optional: harder difficulty shortens the remaining time (but still safe)
	var remaining_years = mission_deadline_year - Globals.year
	remaining_years = int(remaining_years / difficulty_mult)  # higher diff → shorter time
	mission_deadline_year = Globals.year + max(5, remaining_years)

	# Format desc (net_worth → commas)
	if mission_type == "net_worth":
		mission_desc = template.desc_base % add_comma_to_int(mission_target)  # use your comma func
	elif mission_type == "business_rank":
		mission_desc = "Get " % mission_target + " Business Employees"
	else:
		mission_desc = template.desc_base % mission_target

	mission_active = true
	mission_completed = false

func is_mission_complete() -> bool:
	if not mission_active or mission_completed: return true
	match mission_type:
		"houses": return Propertys >= mission_target
		"business_rank": return employees >= mission_target
		"net_worth": return net_worth >= mission_target
		"credit_max": return credit_score >= mission_target
		"tenants": return houses_with_tenants >= mission_target
	return false

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1

	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func recalculate_expenses() -> void:
	Expenses = 100 + (difficulty * 200)
		
	# Fixed monthly costs
	if employees > 0:
		Expenses += employees * 1000  # or whatever BASE_SALARY is in Business_UI
	if hasagent:
		Expenses += 1000
	if hascleaner:
		Expenses += 500
	if renter_finder:
		Expenses += 500

	if business_name != "":
		match difficulty:
			0: Expenses += 10000.0 / 4.0
			1: Expenses += 10000.0 / 3.0
			2: Expenses += 10000.0 / 2.0
			3: Expenses += 10000.0


	# Loan autopay payments – add once per loan
	var loans_ui = get_tree().get_first_node_in_group("loans_ui")  # adjust path if needed
	if loans_ui:
		for mod in loans_ui.active_loan_mods:
			if is_instance_valid(mod) and mod.autopay_enabled:
				Expenses += mod.payment

func add_starter_loan():
	if difficulty < 0 or difficulty > 3:
		return  # safety

	var payment_amount = 500
	match difficulty:
		0: payment_amount = 100   # Easy
		1: payment_amount = 200   # Medium
		2: payment_amount = 500  # Hard
		3: payment_amount = 800  # Extreme
		
	#add starter money
	money += payment_amount * 5
	
	var loan_amount = payment_amount * 24
	interest_rate = 0.10
	
	var loans_ui = get_tree().get_first_node_in_group("loans_ui")  # or your path: /root/.../Loans
	if loans_ui and loans_ui.has_method("add_loan_mod"):
		loans_ui.add_loan_mod(
			payment_amount,          # monthly payment
			interest_rate,           # annual interest
			loan_amount,             # initial balance
			24,                      # months (2 years example)
			1,                       # LOAN_TYPE_PERSONAL
			null                     # no house ref
		)
var pending_rent_total: float = 0.0
var pending_rent_count: int = 0
var rent_batch_timer: SceneTreeTimer = null

func notify_batched_rent(amount: float):
	pending_rent_total += amount
	pending_rent_count += 1
	
	# If a timer isn't already running, start one for 2 seconds
	if rent_batch_timer == null:
		rent_batch_timer = get_tree().create_timer(2.0)
		rent_batch_timer.timeout.connect(_on_rent_batch_finished)

func _on_rent_batch_finished():
	if pending_rent_count > 0:
		var msg = "Agent collected $%s from %d houses." % [add_comma_to_int(int(pending_rent_total)), pending_rent_count]
		notify(msg, Color.GREEN)
		
	# Reset for the next batch
	pending_rent_total = 0.0
	pending_rent_count = 0
	rent_batch_timer = null

func notify_action(message: String, color: Color = Color.WHITE, action_target: Node = null) -> void:
	# 1. If the player has the Renter Finder, we don't need a "Relist" button 
	# because the agent handles it automatically.
	if Globals.renter_finder and action_target != null:
		# Just send a standard silent notification instead of a button
		notify(message, color)
		return

	var list = get_tree().get_first_node_in_group("notification_list")
	if not list: return

	# 2. CAP THE STACK: If there are already 10+ notifications, 
	# remove the oldest one before adding a new one to prevent UI overflow.
	if list.get_child_count() > 10:
		var oldest = list.get_child(0)
		if is_instance_valid(oldest):
			oldest.queue_free()

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var new_label = Label.new()
	new_label.text = "> " + message
	new_label.add_theme_color_override("font_color", color)
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(new_label)
	
	if action_target != null:
		var btn = Button.new()
		btn.text = "Relist"
		# Optional: Style the button to fit the phone theme
		btn.custom_minimum_size = Vector2(60, 0) 
		hbox.add_child(btn)
		
		btn.pressed.connect(func():
			if is_instance_valid(action_target) and is_instance_valid(hbox):
				action_target._on_relist_house_button_pressed()
				hbox.queue_free()
		)

	list.add_child(hbox)
	_scroll_to_bottom(list)
	
	# 3. Use the bound Tween (Safety first!)
	var wait_time = 20.0 if action_target else 10.0
	var timer_tween = hbox.create_tween()
	timer_tween.tween_interval(wait_time)
	timer_tween.tween_property(hbox, "modulate:a", 0, 0.5)
	timer_tween.tween_callback(hbox.queue_free)

func notify(message: String, color: Color = Color.WHITE) -> void:
	var list = get_tree().get_first_node_in_group("notification_list") 
	if not list:
		list = get_node_or_null("/root/Root/UserInterface/Game/HUD/Universal_Text_Box/MarginContainer/ScrollContainer/VBoxContainer")

	if not is_instance_valid(list): return

	var children = list.get_children()
	var search_depth = min(children.size(), 5) 
	var found_match = false
	
	for i in range(1, search_depth + 1):
		var target = children[children.size() - i]
		if is_instance_valid(target) and target.get_meta("raw_message", "") == message:
			var count = target.get_meta("count", 1) + 1
			target.set_meta("count", count)
			target.text = "> " + message + " (x" + str(count) + ")"
			list.move_child(target, list.get_child_count() - 1)
			
			_setup_notification_timer(target)
			found_match = true
			break
			
	if found_match:
		_scroll_to_bottom(list)
		return

	var new_label = Label.new()
	new_label.text = "> " + message
	new_label.add_theme_color_override("font_color", color)
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_label.set_meta("raw_message", message)
	new_label.set_meta("count", 1)
	
	list.add_child(new_label)
	_scroll_to_bottom(list)
	_setup_notification_timer(new_label)

func _scroll_to_bottom(list):
	var scroll_container = list.get_parent()
	if scroll_container is ScrollContainer:
		await get_tree().process_frame
		if is_instance_valid(list) and is_instance_valid(scroll_container):
			scroll_container.scroll_vertical = int(list.size.y)

func _setup_notification_timer(node: Label) -> void:
	# Kill existing tween if it exists (prevents multiple tweens fighting)
	if node.has_meta("fade_tween"):
		var old_tween = node.get_meta("fade_tween")
		if old_tween and old_tween.is_valid(): 
			old_tween.kill()

	var timer_duration = randi_range(20, 35)
	
	# create_tween() bound to the node automatically stops if the node is freed!
	var tween = node.create_tween()
	node.set_meta("fade_tween", tween)
	
	tween.tween_interval(timer_duration)
	tween.tween_property(node, "modulate:a", 0, 0.5)
	tween.tween_callback(node.queue_free)

var last_economy_update_time: float = 0.0
const ECONOMY_UPDATE_INTERVAL: float = 1.0  # seconds, or 0.5 if you need smoother UI

func update_economy() -> void:
	Propertys = 0
	net_worth = Savings_balance
	total_debt = 0.0
	total_loan_amount = 0
	houses_with_tenants = 0
	Income = 0.0
	listed_houses = 0
	
	var running_property_total: int = 0 

	var all_houses = get_tree().get_nodes_in_group("houses")
	for house in all_houses:
		if not house.owned:
			continue 

		# Use 'current_price' since that's what your script uses for house value
		var house_value = house.current_price
		running_property_total += int(house_value) # Add to our new total
		
		var mortgage_remaining = house.loan_price
		
		net_worth += house_value - mortgage_remaining
		total_debt += mortgage_remaining
		total_loan_amount += mortgage_remaining
		Propertys += 1

		if house.has_tenant:
			houses_with_tenants += 1
			Income += house.rent * (1.0 + rent_bost)

		if house.is_listed:
			listed_houses += 1

	# Update the actual Global variable (this triggers the UI update)
	total_property_value = running_property_total
	
	# Rest of your existing logic...
	if has_car and job_income > 0:
		Income += job_income
	if send_to_account:
		Income += interest
		
	net_worth -= total_debt
	recalculate_expenses()
	cashflow = Income - Expenses

func monthy():
	update_economy()
	
	money += cashflow
	month += 1
	if month > 12:
		year += 1
		month = 1
	
	if Savings_balance > 0:
		last_savings_paid = interest
		if send_to_account:
			money += interest
		else:
			Savings_balance += interest
	record_credit_score()
	apply_monthly_job_exp()
	if money < 0:
		negative_month_count += 1
		credit_score -= 10
	else:
		negative_month_count = 0
	
	if credit_app:
		notify("Credit Score: " + str(credit_score), Color.DEEP_SKY_BLUE)
	credit_score = clamp(credit_score, 300, 850)
	emit_signal("month_ended")

func apply_monthly_job_exp():
	if current_job_name == "Unemployed":
		return
		
	# Add the gain to the current category
	match current_job_category:
		"Labor": labor_points += jop_exp_gain_per_month
		"Services": services_points += jop_exp_gain_per_month
		"Trade": trade_points += jop_exp_gain_per_month
		"Finance": finance_points += jop_exp_gain_per_month
		"Management": management_points += jop_exp_gain_per_month
	
	# Also add to general EXP if that's part of your design
	EXP += job_exp_per_month

	# Tell the UI to refresh
	emit_signal("stats_changed")
	emit_signal("skill_points_changed")

var cursor_normal = load("res://assets/UI/mouse/hand_thin_point.png")
var cursor_click = load("res://assets/UI/mouse/hand_thin_small_point.png")
var cursor_Grab = load("res://assets/UI/mouse/hand_small_closed.png")
var hs = Vector2(24, 12)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Fixed: Added Input.CURSOR_ARROW as the 2nd argument
				Input.set_custom_mouse_cursor(cursor_click, Input.CURSOR_ARROW, hs)
			else:
				Input.set_custom_mouse_cursor(cursor_normal, Input.CURSOR_ARROW, hs)
				
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Use cursor_Grab here if you want a "grabbing" visual for right-click
				Input.set_custom_mouse_cursor(cursor_Grab, Input.CURSOR_ARROW, hs)
			else:
				Input.set_custom_mouse_cursor(cursor_normal, Input.CURSOR_ARROW, hs)

func money_in(amount):
	money += amount
	emit_signal("money_in_detect",amount)

func money_out(amount):
	money -= amount
	emit_signal("money_out_detect",amount)

func clamp_stats():
	if Player_health > 100:
		Player_health = 100
	if Player_hunger > 100:
		Player_hunger = 100
	if Player_comfort > 100:
		Player_comfort = 100
