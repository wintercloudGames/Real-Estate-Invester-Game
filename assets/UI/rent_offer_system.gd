extends Control

@onready var game = $"."  
var house = null  
var rent_offers = []  

@onready var ui_layer = $"../HUD"
var timer: Timer

# Base rent offer timing (seconds)
var base_rent_min_time := 30.0
var base_rent_max_time := 90.0
var rent_min_time := base_rent_min_time
var rent_max_time := base_rent_max_time

func _ready() -> void:
	timer = Timer.new()
	timer.name = "RentTimer"
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	timer.one_shot = true
	
	if Globals.has_signal("market_condition_changed"):
		Globals.market_condition_changed.connect(on_market_condition_changed)

func _process(_delta: float) -> void:
	# Ensure the system is active
	if Globals.rent_houses:
		_update_timing_logic()
		check_and_start_timer()

func _update_timing_logic() -> void:
	# Skill-based base timing
	if Globals.renter_finder:
		if Globals.rent_finder_upgrade:
			base_rent_min_time = 1.0
			base_rent_max_time = 5.0 # Tightened for 60-house portfolios
		else:
			base_rent_min_time = 5.0
			base_rent_max_time = 15.0
	else:
		base_rent_min_time = 20.0
		base_rent_max_time = 40.0

func on_market_condition_changed(market_condition: float) -> void:
	var market_modifier = 1.0 / market_condition
	rent_min_time = clamp(base_rent_min_time * market_modifier, 0.1, 30.0)
	rent_max_time = clamp(base_rent_max_time * market_modifier, 0.5, 60.0)

	if timer and not timer.is_stopped():
		reset_timer()

func reset_timer() -> void:
	if timer:
		timer.stop()
		
		var wait = randf_range(base_rent_min_time, base_rent_max_time)
		
		# Division by boost makes the time SMALLER (faster)
		var skill_boost = max(1.0, Globals.rent_bost) 
		var final_wait = (wait / skill_boost) * Globals.rent_finder_boost
		
		# Minimum 0.2s to prevent engine lag but keep it feeling "instant" with 60 houses
		timer.wait_time = max(0.2, final_wait)
		timer.start()

func check_and_start_timer() -> void:
	# Only start if stopped AND we actually have work to do
	if timer and timer.is_stopped():
		if get_available_houses().size() > 0:
			reset_timer()

func get_available_houses() -> Array:
	var available = []
	# Optimization: Only check nodes in group
	var houses = get_tree().get_nodes_in_group("houses")
	for h in houses:
		# Check all three conditions: Owned, No Tenant, and MUST be listed
		if h.owned and not h.has_tenant and h.is_listed:
			available.append(h)
	return available

func _on_timer_timeout() -> void:
	var available = get_available_houses()
	
	if available.size() > 0:
		house = available.pick_random()
		
		# If you have the app, it auto-processes. Otherwise, it shows UI.
		if Globals.renter_finder:
			auto_generate_and_add_tenant()
		else:
			generate_and_display_offers()
	
	# Loop the timer immediately if more houses are still empty
	if get_available_houses().size() > 0:
		reset_timer()

func generate_and_display_offers() -> void:
	if not house: return
	
	var fair_rent: float = float(house.current_price) * 0.007 * float(house.apartment_condition)
	if fair_rent <= 0: fair_rent = 1.0
	
	var rent_ratio: float = float(house.rent) / fair_rent
	
	# If rent is 40% higher than market, 90% chance of no offer
	if rent_ratio > 1.4 and randf() < 0.9:
		Globals.notify_action("Price too high for " + house.id, Color.ORANGE, house) 
		return

	rent_offers = []
	var offer_count = 1 if rent_ratio > 1.1 else randi_range(1, 3)
	
	for i in range(offer_count):
		var raw_offer: float = float(house.rent) * randf_range(0.95, 1.0)
		var snapped_offer = int(snapped(raw_offer, 25))
		rent_offers.append(max(25, snapped_offer))
	
	display_rent_offers()

func auto_generate_and_add_tenant() -> void:
	if not house: return
	
	var fair_rent: float = float(house.current_price) * 0.007 * float(house.apartment_condition)
	if fair_rent <= 0: fair_rent = 1.0
	
	var max_acceptable_rent: float = fair_rent * 1.3
	var final_rent: int = int(house.rent)
	
	# Agent Logic: Snap to grid and auto-adjust
	if final_rent > max_acceptable_rent:
		final_rent = int(snapped(max_acceptable_rent, 25))
	elif final_rent < (fair_rent * 0.8):
		final_rent = int(snapped(fair_rent, 25))

	var stats = generate_renter_stats()
	house.rent = final_rent 
	house.add_tenant(final_rent, stats.lease_length)
	house.is_listed = false
	house.apartment_condition = stats.apartment_condition
	house.payment_punctuality = stats.payment_punctuality
	
	if house.has_method("set_house_UI"):
		house.set_house_UI()
	
	Globals.notify("Agent rented " + house.id + " ($" + add_comma_to_int(final_rent) + ")", Color.GREEN)

func generate_renter_stats() -> Dictionary:
	var punctuality_base = 0.4
	if Globals.credit_score >= 750: punctuality_base = 0.8
	elif Globals.credit_score >= 620: punctuality_base = 0.55
	
	return {
		"payment_punctuality": randf_range(punctuality_base, min(punctuality_base + 0.2, 1.0)),
		"apartment_condition": randf_range(0.7, 1.0),
		"lease_length": [6, 12, 12, 24].pick_random()
	}

func display_rent_offers() -> void:
	var renters_ui = get_node_or_null("../HUD/Phone/Renters/ScrollContainer/renters")
	if not renters_ui: return
	
	for child in renters_ui.get_children():
		child.queue_free()
	
	for offer in rent_offers:
		var renter = preload("res://houses/renter.tscn").instantiate()
		renters_ui.add_child(renter)
		var stats = generate_renter_stats()
		renter.setup(offer, generate_renter_name(), stats)
		renter.pressed.connect(_on_renter_selected.bind(offer, stats))
	
	if has_node("../HUD/event_popup"):
		$"../HUD/event_popup".visible = false

func _on_renter_selected(rent_amount: int, renter_stats: Dictionary) -> void:
	if house:
		house.add_tenant(rent_amount, renter_stats.lease_length)
		house.is_listed = false
		clear_offers_ui()
		Globals.EXP += 5 * Globals.exp_boost
		Globals.notify("Tenant Moved In!", Color.GREEN)

func clear_offers_ui() -> void:
	var renters_ui = get_node_or_null("../HUD/Phone/Renters/ScrollContainer/renters")
	if renters_ui:
		for child in renters_ui.get_children():
			child.queue_free()

func generate_renter_name() -> String:
	var first = ["Alex", "Jamie", "Taylor", "Jordan", "Casey", "Morgan"].pick_random()
	var last = ["Smith", "Johnson", "Williams", "Brown", "Lee", "Davis"].pick_random()
	return "%s %s" % [first, last]

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value


func _on_button_button_down() -> void:
	if house:
		$house_info.visible = true
		$house_info/Value.text = "Value: " + add_comma_to_int(house.current_price)
		$house_info/morgage.text = "Mortgage: " + add_comma_to_int(house.mortgage)

func _on_button_button_up() -> void:
	if house:
		$house_info.visible = false
		$house_info/Value.text = str("0")
		$house_info/morgage.text = str("0")
