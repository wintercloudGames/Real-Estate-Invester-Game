extends Control

@onready var health_bar: ProgressBar = $VBoxContainer/Health_bar
@onready var hunger_bar: ProgressBar = $VBoxContainer/Hunger_bar
@onready var comfort_bar: ProgressBar = $VBoxContainer/comfort_bar


func _process(delta: float) -> void:
	health_bar.value = Globals.Player_health
	hunger_bar.value = Globals.Player_hunger
	comfort_bar.value = Globals.Player_comfort

	update_bar_color($VBoxContainer/health_label, health_bar.value)
	update_bar_color($VBoxContainer/Hunger_label, hunger_bar.value)
	update_bar_color($VBoxContainer/comfort_label, comfort_bar.value)
	update_bar_color(health_bar, health_bar.value)
	update_bar_color(hunger_bar, hunger_bar.value)
	update_bar_color(comfort_bar, comfort_bar.value)
	
	
	
	var owned_houses = get_tree().get_nodes_in_group("houses")
	var properties_owned = 0
	
	# Count how many properties are owned
	for house in owned_houses:
		if house.owned and house.has_tenant == false:  # Check if house is owned
			Globals.Player_comfort += 0.05

func update_bar_color(bar, value: float) -> void:
	var color: Color
	if value >= 75:
		color = Color(0, 193, 0)  # Green
	elif value >= 50:
		color = Color(0.78, 0.78, 0.02)  # Yellow
	elif value >= 20:
		color = Color(1.0, 0.6, 0.0)  # Orange
	else:
		color = Color(1.0, 0.0, 0.0)  # Red

	bar.modulate = color
