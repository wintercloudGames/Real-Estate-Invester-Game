extends Control

@onready var market: Node = $"../../Market"


func start():
	market.difficulty = Globals.difficulty
	market.apply_difficulty_settings()
	market.update_label()
	$"../Business_UI".Set_difficulty()
	$"../Phone/Car_info".car_level = 1
	# Show/hide mission display panel if you have one
	Globals.recalculate_expenses()
	# Only reset if we aren't already in a mission
	if Globals.current_game_mode != Globals.GameMode.MISSION:
		Globals.reset(Globals.GameMode.FREEPLAY)
	visible = false
	Globals.first_start = false
	Globals.add_starter_loan()
	SaveAndLoad.save_game()

# ────────────────────────────────────────────────
# Difficulty Buttons
# ────────────────────────────────────────────────

func _on_easy_button_pressed() -> void:
	Globals.difficulty = 0
	Globals.credit_score = 700

	start()

func _on_normal_button_pressed() -> void:
	Globals.difficulty = 1
	Globals.credit_score = 600

	start()

func _on_hard_button_pressed() -> void:
	Globals.difficulty = 2
	Globals.credit_score = 400

	start()

func _on_nightmare_button_pressed() -> void:
	Globals.difficulty = 3
	Globals.credit_score = 300

	start()
