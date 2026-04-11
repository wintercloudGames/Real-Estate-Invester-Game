extends Panel

@onready var mission: Label = $mission
@onready var mission_deadline: Label = $mission_deadline
@onready var mission_desc: Label = $mission_des
@onready var mission_progress: Label = $mission_progress

func _ready() -> void:
	visible = false

func update_display() -> void:
	if not Globals.mission_active:
		visible = false
		return
	
	visible = true
	
	if mission:
		mission.text = Globals.mission_desc if Globals.mission_desc else "No mission description"
	
	if mission_deadline:
		mission_deadline.text = "Complete by end of year: " + str(Globals.mission_deadline_year)
	
	if mission_desc:
		mission_desc.text = Globals.mission_desc  # if you want description repeated
	
	if mission_progress:
		var progress_text = "Progress: "
		match Globals.mission_type:
			"houses":
				progress_text += add_comma_to_int(Globals.Propertys) + " / " + add_comma_to_int(Globals.mission_target)
			"tenants":
				progress_text += add_comma_to_int(Globals.houses_with_tenants) + " / " + add_comma_to_int(Globals.mission_target)
			"net_worth":
				progress_text += "$" + add_comma_to_int(Globals.net_worth) + " / $" + add_comma_to_int(Globals.mission_target)
			"credit_max":
				progress_text += add_comma_to_int(Globals.credit_score) + " / " + add_comma_to_int(Globals.mission_target)
			"business_rank":
				progress_text += add_comma_to_int(Globals.employees + 1) + " / " + add_comma_to_int(Globals.mission_target)
			_:
				progress_text += "?"
		mission_progress.text = progress_text

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

# Optional: live updates every frame (only if you really need it)
func _process(_delta: float) -> void:
	if Globals.mission_active:
		update_display()
