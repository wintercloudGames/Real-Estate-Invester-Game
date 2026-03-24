extends Control

@onready var market: Node = $"../../Market"

@onready var mission_toggle: CheckButton = $mission_toggle      # CheckButton for "Play with Mission?"
@onready var mission_label: Label = $MissionLabel             # shows mission description

func _ready() -> void:
	if mission_toggle:
		mission_toggle.button_pressed = false
		mission_toggle.text = "Mission mode: OFF"
	
	if mission_label:
		mission_label.text = ""


func start():
	market.difficulty = Globals.difficulty
	market.apply_difficulty_settings()
	market.update_label()
	$"../Business_UI".Set_difficulty()
	$"../Phone/Car_info".car_level = 1
	# Show/hide mission display panel if you have one
	if has_node("../UI/MissionDisplay"):
		get_node("../UI/MissionDisplay").visible = Globals.mission_active
	Globals.recalculate_expenses()
	visible = false
	Globals.first_start = true 
	SaveAndLoad.save_game()

func generate_and_show_mission():
	if not Globals.mission_active:
		return 
	
	Globals.generate_random_mission()
	
	if mission_label:
		mission_label.text = Globals.mission_desc

	
	if mission_toggle:
		mission_toggle.text = "Mission mode: ON"

# ────────────────────────────────────────────────
# Difficulty Buttons
# ────────────────────────────────────────────────

func _on_easy_button_pressed() -> void:
	Globals.difficulty = 0
	Globals.credit_score = 700
	generate_and_show_mission()
	Globals.add_starter_loan()
	start()

func _on_normal_button_pressed() -> void:
	Globals.difficulty = 1
	Globals.credit_score = 600
	generate_and_show_mission()
	Globals.add_starter_loan()
	start()

func _on_hard_button_pressed() -> void:
	Globals.difficulty = 2
	Globals.credit_score = 400
	generate_and_show_mission()
	Globals.add_starter_loan()
	start()

func _on_nightmare_button_pressed() -> void:
	Globals.difficulty = 3
	Globals.credit_score = 300
	generate_and_show_mission()
	Globals.add_starter_loan()
	start()

func _on_mission_option_toggled(toggled_on: bool) -> void:
	Globals.mission_active = toggled_on
	
	if toggled_on:
		if mission_toggle:
			mission_toggle.text = "Mission mode: ON"
	else:
		# Clear mission so nothing is active
		Globals.mission_type = ""
		Globals.mission_target = 0
		Globals.mission_deadline_year = 0
		Globals.mission_desc = ""
		
		if mission_label:
			mission_label.text = ""
		if mission_toggle:
			mission_toggle.text = "Mission mode: OFF"
