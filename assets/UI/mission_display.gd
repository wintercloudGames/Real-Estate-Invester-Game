extends Panel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$mission.text = str(Globals.mission_desc)
	$mission_deadlne.text = "Complete by year: " + str(Globals.mission_deadline_year)
	$mission_target.text = str(Globals.mission_target)
