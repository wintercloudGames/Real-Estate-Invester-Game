extends Control

var car_level = 0
var is_broken = false
var base_upgrade_cost = 500
var breakdown_rate = 1.0 
var max_car_level = 10

@onready var car_status_label: Label = $Car_status_label
@onready var breakdown_timer: Timer = Timer.new()
@onready var upgrade_cost_label: Label = $Upgrade_Cost_Label
@onready var repair_button: Button = $Repaire_Button

func _ready():
	add_child(breakdown_timer)
	breakdown_timer.timeout.connect(_on_breakdown_check)
	
	# Initial setup
	_update_timer_difficulty()
	load_info()

# Optimization: Don't set wait_time 60 times a second. 
# Only update it when difficulty actually changes or on start.
func _update_timer_difficulty():
	match Globals.difficulty:
		3: breakdown_timer.wait_time = 120
		2: breakdown_timer.wait_time = 256
		1: breakdown_timer.wait_time = 500
		_: breakdown_timer.wait_time = 1000

func _on_breakdown_check():
	var chance = randf()
	# Current breakdown_rate is 1.0 (100%) minus 10% per level
	if chance < breakdown_rate:
		is_broken = true
		Globals.has_car = false
		# Using the "car_event" key keeps this warning on ONE line in the notification list
		Globals.notify("⚠️ ALERT: Car has broken down!", Color.RED)
		breakdown_timer.stop()
	else:
		# Restart the timer for the next check if we didn't break
		breakdown_timer.start()
		
	update_status_label()

func _on_repaire_button_pressed():
	var repair_cost = get_repair_cost()
	
	if not is_broken:
		Globals.notify("Car is already functional.", Color.YELLOW)
		return

	if Globals.money >= repair_cost:
		Globals.money -= repair_cost
		Globals.has_car = true
		is_broken = false
		
		# Math Fix: Proper EXP boost
		var gained_exp = int((car_level + 5) * Globals.exp_boost)
		Globals.exp += gained_exp
		
		Globals.notify("Car Repaired! ($%d)" % repair_cost, Color.SPRING_GREEN)
		Globals.notify("EXP + %d" % gained_exp, Color.YELLOW)
		
		# Restart the breakdown cycle
		breakdown_timer.start()
	else:
		Globals.notify("Not enough money to repair!", Color.CRIMSON)
		
	update_status_label()

func _on_upgrade_button_pressed():
	var cost = get_upgrade_cost()
	
	if car_level >= max_car_level:
		Globals.notify("Car is already at max level!", Color.GOLD)
		return

	if Globals.money >= cost:
		Globals.money -= cost
		Globals.car_level += 1
		car_level = Globals.car_level # Keep local synced with global
		
		# Update breakdown rate logic
		breakdown_rate = max(0.0, 1.0 - (car_level * 0.1))
		
		var gained_exp = int((car_level + 5) * Globals.exp_boost)
		Globals.exp += gained_exp
		
		Globals.notify("Car Upgraded to Level %d" % car_level, Color.GREEN)
		Globals.notify("EXP + %d" % gained_exp, Color.YELLOW)
	else:
		Globals.notify("Not enough money for upgrade!", Color.CRIMSON)
		
	update_status_label()

func get_repair_cost() -> int:
	# Base repair cost + level scaling
	return 250 * (car_level + 1)

func get_upgrade_cost() -> int:
	# Cost increases with level
	return base_upgrade_cost * (car_level + 1)

func load_info():
	car_level = Globals.car_level
	is_broken = !Globals.has_car
	breakdown_rate = max(0.0, 1.0 - (car_level * 0.1))
	
	if is_broken:
		breakdown_timer.stop()
	else:
		breakdown_timer.start()
		
	update_status_label()

func update_status_label():
	# Hide upgrade UI if maxed
	var is_maxed = car_level >= max_car_level
	$Upgrade_Button.visible = !is_maxed
	$Upgrade_Cost_Label.visible = !is_maxed
	
	var repair_cost = get_repair_cost()
	$Repair_Cost_Label.text = "Repair Cost: $%d" % repair_cost
	
	var status_text = "❌ Broken Down" if is_broken else "✅ Working"
	# Logic: format percentage for the UI
	var display_rate = breakdown_rate * 100
	
	car_status_label.text = "Car Level: %d\nStatus: %s\nBreakdown Risk: %d%%" % [car_level, status_text, display_rate]
	
	upgrade_cost_label.text = "Upgrade Cost: $%d" % get_upgrade_cost()
	repair_button.disabled = !is_broken
