extends Control

var house_list = []
var active_mods := {}  # Dictionary to keep track of mods by house reference
var list_needs_resort: bool = false

@onready var mod_container: VBoxContainer = $ScrollContainer/Rental_mod_Container

func _ready():
	await get_tree().process_frame
	house_list = get_tree().get_nodes_in_group("houses")
	list_needs_resort = true

func _process(_delta: float) -> void:
	update_owned_house_mods()
	sort_mods_by_status()

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

## --- SORTING LOGIC ---

func sort_mods_by_status():
	var mods = mod_container.get_children()
	if mods.size() <= 1: return

	mods.sort_custom(func(a, b):
		var a_weight = _get_status_weight(a.house)
		var b_weight = _get_status_weight(b.house)
		
		if a_weight == b_weight:
			return a.house.current_price > b.house.current_price
		
		return a_weight < b_weight
	)

	for i in range(mods.size()):
		mod_container.move_child(mods[i], i)

func _get_status_weight(house) -> int:
	if not house: return 4
	
	if house.is_apartment:
		var has_stored_cash = false
		var all_rented = true
		var any_listed = false
		
		var collect_node = house.get_node_or_null("Collect_Rent")
		if collect_node and collect_node.stored_cash > 0:
			has_stored_cash = true
			
		for unit in house.units:
			if not unit["has_tenant"]:
				all_rented = false
				if unit["is_listed"]:
					any_listed = true
					
		if has_stored_cash:
			return 1 # Rent Ready
		elif not all_rented and any_listed:
			return 2 # Seeking Tenant
		elif not all_rented and not any_listed:
			return 0 # Unlisted (vacant units not on market)
		else:
			return 3 # Fully Rented
	else:
		if not house.is_listed and not house.has_tenant:
			return 0
		var collect_node = house.get_node_or_null("Collect_Rent")
		if collect_node and collect_node.stored_cash > 0 and not house.is_listed:
			return 1
		if house.is_listed and not house.has_tenant:
			return 2
		if house.has_tenant:
			return 3
		return 4

func update_owned_house_mods():
	for house in house_list:
		if house.owned:
			if not active_mods.has(house):
				add_house_mod(house)
				list_needs_resort = true
		else:
			if active_mods.has(house):
				remove_house_mod(house)
				list_needs_resort = true

func add_house_mod(house):
	var mod_scene = preload("res://assets/UI/phone/rental_controll_mod.tscn")
	var mod_instance = mod_scene.instantiate()
	
	# Set data
	mod_instance.house = house
	if house.is_apartment:
		mod_instance.apartment_building = house # <--- Set this so it knows it's an apartment card!
	
	mod_container.add_child(mod_instance)
	active_mods[house] = mod_instance

func remove_house_mod(house):
	var mod_instance = active_mods[house]
	if is_instance_valid(mod_instance):
		mod_instance.queue_free()
	active_mods.erase(house)

func _on_collect_rent_pressed() -> void:
	for house in active_mods:
		var mod_instance = active_mods[house]
		if is_instance_valid(mod_instance):
			mod_instance._on_collect_rent_button_pressed()
	list_needs_resort = true
