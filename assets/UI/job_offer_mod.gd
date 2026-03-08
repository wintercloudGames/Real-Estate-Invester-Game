extends Control
@onready var Business_UI = get_node("/root/Root/UserInterface/Game/HUD/Business_UI")

var job_pay = 0
var job_time = 0

func _on_deny_job_button_pressed() -> void:
	queue_free()

func _process(delta: float) -> void:
	if Business_UI.max_job_time > 0:
		$HBoxContainer/Take_job_Button.visible = false
	else:
		$HBoxContainer/Take_job_Button.visible = true
		
	if self.is_node_ready() and self.is_inside_tree():
			$HBoxContainer2/Job_expire.text = "Offer Timer: "+str(int($Timer.time_left))

func _on_take_job_button_pressed() -> void:
	if Business_UI.max_job_time > 0:
		$HBoxContainer2/Job_time2.text = "Already have a job in progress"
	else:
		Business_UI._on_take_job_pressed(job_pay,job_time)
	queue_free()

func _ready() -> void:
	$Timer.wait_time = randi_range(30,120)
	$Timer.start()
	$HBoxContainer2/Job_pay.text = "Job Pay: " + add_comma_to_int(job_pay)
	$HBoxContainer2/Job_time.text = "Job time: " + add_comma_to_int(job_time)

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")

	return str_value

func _on_timer_timeout() -> void:
	queue_free()
