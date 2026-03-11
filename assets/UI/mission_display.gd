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
		mission_deadline.text = "Complete by year: " + str(Globals.mission_deadline_year)
	
	if mission_desc:
		mission_desc.text = Globals.mission_desc  # if you want description repeated
	
	if mission_progress:
		var progress_text = "Progress: "
		match Globals.mission_type:
			"houses":
				progress_text += str(Globals.Propertys) + " / " + str(Globals.mission_target)
			"tenants":
				progress_text += str(Globals.houses_with_tenants) + " / " + str(Globals.mission_target)
			"net_worth":
				progress_text += "$" + str(int(Globals.net_worth)) + " / $" + str(Globals.mission_target)
			"credit_max":
				progress_text += str(Globals.credit_score) + " / " + str(Globals.mission_target)
			"business_rank":
				progress_text += str(Globals.employees + 1) + " / " + str(Globals.mission_target)
			_:
				progress_text += "?"
		mission_progress.text = progress_text
	
	print("MissionDisplay updated - visible:", visible, " - ", Globals.mission_desc)

# Optional: live updates every frame (only if you really need it)
func _process(delta: float) -> void:
	if Globals.mission_active:
		update_display()
