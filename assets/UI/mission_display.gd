extends Panel
#misson display
@onready var mission_label: Label = $mission
@onready var mission_deadline: Label = $mission_deadline
@onready var mission_desc: Label = $mission_des
@onready var mission_progress: Label = $mission_progress

func _ready() -> void:
	# Update whenever a month passes to keep progress fresh
	Globals.month_ended.connect(update_mission_ui)

func _process(_delta: float) -> void:
	# Only update if the player can actually see it
	if visible:
		update_mission_ui()

func update_mission_ui() -> void:
	var m = Globals.active_mission
	if m == null:
		mission_label.text = ""
		mission_desc.text = "No Active Mission"
		mission_progress.text = ""
		mission_deadline.text = ""
		return
	
	# 1. Basic Info 
	mission_label.text = m.title
	mission_desc.text = m.description
	
	var years_left = m.time_limit_year - Globals.year
	if years_left < 0:
		mission_deadline.text = "DEADLINE PASSED"
		mission_deadline.modulate = Color.RED
	else:
		mission_deadline.text = "Deadline: End of Year %d" % m.time_limit_year
		mission_deadline.modulate = Color.WHITE
	var progress_lines = []
	
	if m.target_money > 0:
		progress_lines.append("Cash: %s / %s" % [format_currency(Globals.money), format_currency(m.target_money)])
	if m.target_savings > 0:
		progress_lines.append("Savings: %s / %s" % [format_currency(Globals.Savings_balance), format_currency(m.target_savings)])
	
	if m.target_houses > 0:
		progress_lines.append("Houses: %d / %d" % [Globals.Propertys, m.target_houses])
	if m.target_rented_houses > 0:
		progress_lines.append("Rented: %d / %d" % [Globals.houses_with_tenants, m.target_rented_houses])
	
	if m.target_player_level > 1:
		progress_lines.append("Level: %d / %d" % [Globals.level, m.target_player_level])
	if m.target_car_level > 1:
		progress_lines.append("Car Level: %d / %d" % [Globals.car_level, m.target_car_level])
	if m.target_employees > 0:
		progress_lines.append("Employees: %d / %d" % [Globals.employees, m.target_employees])
	if m.target_credit_score > 0:
		progress_lines.append("Credit: %d / %d" % [Globals.credit_score, m.target_credit_score])

	mission_progress.text = "\n".join(progress_lines)

# Helper to make numbers look like tycoon money ($1,000)
func format_currency(amount: float) -> String:
	return "$" + str(Globals.add_comma_to_int(amount))
