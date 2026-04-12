extends Control

var car_level = 0
var is_broken = false
var base_upgrade_cost = 500
var breakdown_rate = 1  # Breakdown rate based on the car level (changeable)
var max_car_level = 10
@onready var car_status_label: Label = $Car_status_label
@onready var breakdown_timer: Timer = Timer.new()
@onready var upgrade_cost_label: Label = $Upgrade_Cost_Label
@onready var repair_button: Button = $Repaire_Button
var time_waittime = 120

func _ready():
	add_child(breakdown_timer)
	breakdown_timer.timeout.connect(_on_breakdown_check)
	
	if car_level >= max_car_level:
		$Upgrade_Button.visible = false
		$Upgrade_Cost_Label.visible = false

func _process(delta: float) -> void:
	breakdown_rate = max(0.0, 1.0 - (car_level * 0.1))
	
	if Globals.difficulty == 3:
				breakdown_timer.wait_time = 120
	elif Globals.difficulty == 2:
		breakdown_timer.wait_time = 256
	elif Globals.difficulty == 1:
		breakdown_timer.wait_time = 500
	else:
		breakdown_timer.wait_time = 1000
	
func _on_breakdown_check():
	var chance = randf()
	var breakdown_chance = breakdown_rate  # Breakdown chance based on breakdown_rate
	breakdown_timer.start()
	
	if chance < breakdown_chance:
		Globals.has_car = false
		breakdown_timer.stop()
		is_broken = true
	update_status_label()

func _on_repaire_button_pressed():
	var repair_cost = get_repair_cost()
	if is_broken:
		if Globals.money >= repair_cost:
			Globals.money -= repair_cost
			Globals.has_car = true
			Globals.exp += car_level + 5 * Globals.exp_boost
			is_broken = false
			Globals.notify("Car Repaired for $" + str(repair_cost), Color.GREEN)
		else:
			Globals.notify("Not enough money to repair!", Color.RED)
	else:
		Globals.notify("Car is not broken!", Color.YELLOW)
	update_status_label()

func get_repair_cost() -> int:
	return 250 * car_level  # Adjust the formula to modify repair cost based on car level

func _on_upgrade_button_pressed():
	var cost = get_upgrade_cost()
	
	if Globals.money >= cost and car_level < max_car_level:
		Globals.money -= cost
		Globals.car_level += 1
		breakdown_rate -= 0.1
		Globals.exp += car_level + 5 * Globals.exp_boost
		car_level += 1
		Globals.notify("Upgraded Car to Level %d" % car_level, Color.GREEN)
	else:
		Globals.notify("Not enough money to upgrade!", Color.RED)
	if car_level >= max_car_level:
		$Upgrade_Button.visible = false
		$Upgrade_Cost_Label.visible = false
	update_status_label()

func get_upgrade_cost() -> int:
	return base_upgrade_cost * car_level

func load_info():

	is_broken = !Globals.has_car
	car_level = Globals.car_level
	breakdown_rate = max(0.0, 1.0 - (car_level * 0.1))
	update_status_label()
	if car_level >= max_car_level:
		$Upgrade_Button.visible = false
		$Upgrade_Cost_Label.visible = false

func update_status_label():
	$Repair_Cost_Label.text = "Repair Cost: $" + str(get_repair_cost())
	
	# Logic fix: is_broken should show 'Broken', else 'Working'
	var status = "❌ Broken Down" if is_broken else "✅ Working"
	
	car_status_label.text = "Car Level: %d\nStatus: %s\nBreakdown Rate: %.1f%%" % [car_level, status, breakdown_rate * 100]
	
	var upgrade_cost = get_upgrade_cost()
	upgrade_cost_label.text = "Upgrade Cost: $" + str(upgrade_cost)
	
	# The Repair button should only be clickable if the car IS broken
	repair_button.disabled = !is_broken
