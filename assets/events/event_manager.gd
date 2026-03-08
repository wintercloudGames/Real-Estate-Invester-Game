extends Node

@onready var ui_layer: CanvasLayer = $"../HUD"
var event_interval: float = 90  # Time (seconds) between events
@onready var event_popup = $"../HUD/event_popup"  # Reference to the popup UI
var event_timer = Timer.new()
# Define possible events (some have no static cost—they calculate it during execution)
var events = [
	{ "type": "maintenance", "description": "A house needs repairs!", "cost": 200 },
	{ "type": "maintenance", "description": "A house needs repairs!", "cost": 500 },
	{ "type": "maintenance", "description": "A house needs repairs!", "cost": 2000 },
	{ "type": "rent_increase", "description": "A tenant agrees to pay more every month!" },
	{ "type": "house_upgrade", "description": "A property renovation boosts its value!", "cost": 2000 },
	{ "type": "property_damage", "description": "A storm caused damage, repairs needed!", "cost": 2500 },
	{ "type": "random_bonus", "description": "A costumer is very happy with your work! and gave you bonus money!", "cost": -1000 },
	{ "type": "random_bonus", "description": "A lucky investment pays off!", "cost": -5000 }
]

func _ready():
	event_timer.wait_time = event_interval
	event_timer.autostart = true
	event_timer.one_shot = false
	event_timer.timeout.connect(_trigger_random_event)
	add_child(event_timer)

func _trigger_random_event():
	var owned_houses = get_tree().get_nodes_in_group("houses").filter(func(house): return house.owned)

	if owned_houses.is_empty():
		return
	event_timer.wait_time = event_interval
	var selected_event = events[randi() % events.size()]

	if selected_event.has("cost") and Globals.money < selected_event["cost"]:
		show_floating_label("Not enough money! Going into debt.", Color.RED)

	handle_event(selected_event)

func show_floating_label(text: String, color: Color = Color.WHITE):
	if ui_layer:
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.set_position(Vector2(100, 100))
		ui_layer.add_child(label)

		var tween = get_tree().create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5)
		tween.tween_property(label, "modulate:a", 0, 1.5)
		tween.tween_callback(label.queue_free)

func handle_event(event_data: Dictionary):
	match event_data["type"]:
		"rent_increase":
			increase_rent(event_data)
		"house_upgrade":
			upgrade_house(event_data)
		"property_damage":
			property_damage(event_data)
		_:
			Globals.money -= event_data["cost"]
			show_popup(event_data["description"], event_data["cost"])

var moved_out_house = null

func _on_relist_house_button_pressed() -> void:
	moved_out_house.is_listed = true
	moved_out_house = null
	$"../HUD/event_popup".visible = false
	$"../HUD/event_popup/Relist_house_Button".visible = false

func tenant_moves_out(house):
	var occupied_houses = house

	moved_out_house = occupied_houses
	$"../HUD/event_popup/Relist_house_Button".visible = true
	show_popup("A tenant moved out, the house is now vacant.",0)

func increase_rent(event_data: Dictionary):
	var occupied_houses = get_tree().get_nodes_in_group("houses").filter(func(house): return house.has_tenant)

	if occupied_houses.size() > 0:
		var selected_house = occupied_houses[randi() % occupied_houses.size()]
		var rent_increase = randi_range(100, 300)
		selected_house.rent += rent_increase
		show_popup(event_data["description"], -rent_increase)

func upgrade_house(event_data: Dictionary):
	var owned_houses = get_tree().get_nodes_in_group("houses")

	if owned_houses.size() > 0:
		var selected_house = owned_houses[randi() % owned_houses.size()]
		selected_house.current_price += 5000
	show_popup(event_data["description"], event_data["cost"])

func property_damage(event_data: Dictionary):
	var owned_houses = get_tree().get_nodes_in_group("houses")

	if owned_houses.size() > 0:
		var selected_house = owned_houses[randi() % owned_houses.size()]
		Globals.money -= event_data["cost"]

	show_popup(event_data["description"], event_data["cost"])

func rent_offers():
	show_popup("You have rent offers!", 0)

func show_popup(message: String, cost: int):
	$"../HUD/event_popup/Label".text = message

	if cost > 0:
		$"../HUD/event_popup/cost".text = "-$" + str(cost)
	elif cost < 0:
		$"../HUD/event_popup/cost".text = "+$" + str(abs(cost))
	else:
		$"../HUD/event_popup/cost".text = ""

	event_popup.visible = true

	if $"../HUD/event_popup/Relist_house_Button".visible == false:
		await get_tree().create_timer(3.0).timeout
		event_popup.visible = false
	else:
		await get_tree().create_timer(10.0).timeout
		event_popup.visible = false
		$"../HUD/event_popup/Relist_house_Button".visible = false
