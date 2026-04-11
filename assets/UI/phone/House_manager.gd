extends Control

var house_list = []
var active_mods := {}  # Dictionary to keep track of mods by house reference
var list_needs_resort: bool = false

@onready var mod_container: VBoxContainer = $ScrollContainer/Rental_mod_Container

func _ready():
	await get_tree().process_frame
	house_list = get_tree().get_nodes_in_group("houses")
	# Initial sort
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
		
		# Secondary sort: If status is same, show most expensive houses first
		if a_weight == b_weight:
			return a.house.current_price > b.house.current_price
		
		return a_weight < b_weight
	)

	# Apply the new order to the UI container
	for i in range(mods.size()):
		mod_container.move_child(mods[i], i)

func _get_status_weight(house) -> int:
	# 1. ABSOLUTE TOP: Unlisted (Not on market, no tenant)
	# This MUST come first.
	if not house.is_listed and not house.has_tenant:
		return 0
		
	# 2. SECOND: Rent Ready (Unlisted but has stored cash)
	if house.stored_cash > 0 and not house.is_listed:
		return 1
		
	# 3. THIRD: Looking for Tenant (Is on the market, but empty)
	if house.is_listed and not house.has_tenant:
		return 2
		
	# 4. BOTTOM: Has Tenant (Active income)
	if house.has_tenant:
		return 3
		
	return 4 # Fallback

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
	mod_instance.rent = house.rent
	mod_instance.mortgage = house.mortgage
	mod_instance.has_tenant = house.has_tenant

	mod_container.add_child(mod_instance)
	active_mods[house] = mod_instance
	
	# Connect signals if your House script has them, to trigger a resort when status changes
	if house.has_signal("status_changed"):
		if not house.status_changed.is_connected(_on_house_status_changed):
			house.status_changed.connect(_on_house_status_changed)

func remove_house_mod(house):
	var mod_instance = active_mods[house]
	if is_instance_valid(mod_instance):
		mod_instance.queue_free()
	active_mods.erase(house)
	
	if house.has_signal("status_changed"):
		if house.status_changed.is_connected(_on_house_status_changed):
			house.status_changed.disconnect(_on_house_status_changed)

func _on_house_status_changed():
	list_needs_resort = true

func _on_collect_rent_pressed() -> void:
	for house in active_mods:
		var mod_instance = active_mods[house]
		if is_instance_valid(mod_instance):
			mod_instance._on_collect_rent_button_pressed()
	list_needs_resort = true # Resort after collection in case status changed
