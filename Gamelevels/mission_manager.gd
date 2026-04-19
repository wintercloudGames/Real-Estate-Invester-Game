extends Node
class_name MissionManager

signal mission_completed
signal mission_failed(reason: String)

func _ready():
	Globals.month_ended.connect(check_status)

func check_status():
	if Globals.current_game_mode != Globals.GameMode.MISSION or !Globals.active_mission:
		return

	var m = Globals.active_mission
	
	# Check Failure
	if Globals.year > m.time_limit_year:
		mission_failed.emit("Time limit reached!")
		return

	# Check Success
	var has_money = Globals.money >= m.target_money
	var has_houses = Globals.Propertys >= m.target_houses
	var has_savings = Globals.Savings_balance >= m.target_savings

	if has_money and has_houses and has_savings:
		mission_completed.emit()
