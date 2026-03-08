extends Control

var house_list = []
var active_mods := {}  # Dictionary to keep track of mods by house reference

@onready var mod_container: VBoxContainer = $ScrollContainer/Rental_mod_Container

func _ready():
	await get_tree().process_frame
	house_list = get_tree().get_nodes_in_group("houses")

func _process(_delta: float) -> void:
	update_owned_house_mods()
	sort_mods_by_cashflow()


func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func sort_mods_by_cashflow():
	var mods = mod_container.get_children()

	# Sort the mods by cashflow (rent - mortgage), lowest first
	mods.sort_custom(func(a, b):
		var a_flow = a.rent - a.mortgage
		var b_flow = b.rent - b.mortgage
		return a_flow < b_flow
	)

	# Reorder using move_child (efficiently reorder in container)
	for i in range(mods.size()):
		mod_container.move_child(mods[i], i)

func sort_mods_by_price():
	var mods = mod_container.get_children()

	# Sort mods by the house's current_price, highest to lowest
	mods.sort_custom(func(a, b):
		return a.house.current_price > b.house.current_price
	)

	# Move children in sorted order
	for i in range(mods.size()):
		mod_container.move_child(mods[i], i)

func update_owned_house_mods():
	for house in house_list:
		if house.owned:
			if not active_mods.has(house):
				add_house_mod(house)
		else:
			if active_mods.has(house):
				remove_house_mod(house)
	sort_mods_by_price()

func add_house_mod(house):
	var mod_scene = preload("res://assets/UI/phone/rental_controll_mod.tscn")
	var mod_instance = mod_scene.instantiate()

	# Set data
	mod_instance.house = house
	mod_instance.rent = house.rent
	mod_instance.mortgage = house.mortgage
	mod_instance.has_tenant = house.has_tenant

	mod_container.add_child(mod_instance)
	active_mods[house] = mod_instance  # Track it

func remove_house_mod(house):
	var mod_instance = active_mods[house]
	if is_instance_valid(mod_instance):
		mod_instance.queue_free()
	active_mods.erase(house)
