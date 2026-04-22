extends Control

@onready var game = $"."  # Reference to game or main controller
var house = null  # Current selected house
var rent_offers = []  # Current rent offers

@onready var ui_layer = $"../HUD"
var timer: Timer

# Base rent offer timing (seconds)
var base_rent_min_time := 30.0
var base_rent_max_time := 90.0
var rent_min_time := base_rent_min_time
var rent_max_time := base_rent_max_time

func _ready() -> void:
	# Initialize the timer
	timer = Timer.new()
	timer.name = "Timer"
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	timer.one_shot = true
	

func _process(delta):
	if Globals.rent_houses:
		check_and_start_timer()
		
		if Globals.renter_finder:
			if Globals.rent_finder_upgrade:
				rent_min_time = 1.0
				rent_max_time = 10.0
			else:
				rent_min_time = 10.0
				rent_max_time = 40.0
			
			# Keep base values in sync for market calculations
			base_rent_min_time = rent_min_time
			base_rent_max_time = rent_max_time
		

func on_market_condition_changed(market_condition: float):
	# Visual feedback
	Globals.notify("Market Change: %s%.1f%%" % [
		"+" if market_condition > 1.0 else "", 
		(market_condition - 1.0) * 100
	], Color.SKY_BLUE)
	
	# Adjust timing based on market (faster offers in hot markets)
	var market_modifier = 1.0 / market_condition
	rent_min_time = clamp(base_rent_min_time * market_modifier, 0.5, 30)  # Lower minimum
	rent_max_time = clamp(base_rent_max_time * market_modifier, 1.0, 60)  # Lower minimum

	# Restart timer if active
	if timer and not timer.is_stopped():
		reset_timer()

func reset_timer():
	if timer:
		timer.stop()
		timer.wait_time = randf_range(rent_min_time, rent_max_time) * Globals.rent_finder_boost
		timer.start()

func check_and_start_timer():

	if timer and timer.is_stopped():
		var available_houses = get_available_houses()
		if available_houses.size() > 0:
			
			reset_timer()

# FIXED: Removed the is_listed check - this was likely preventing houses from being found
func get_available_houses() -> Array:
	var available = []
	for h in get_tree().get_nodes_in_group("houses"):
		if h.owned and not h.has_tenant and h.is_listed:
			available.append(h)
			
	return available

func _on_timer_timeout():
	var available = get_available_houses()
	
	if available.size() > 0:
		house = available.pick_random()
		
		if Globals.renter_finder:
			auto_generate_and_add_tenant()
		else:
			generate_and_display_offers()

	check_and_start_timer()

func generate_and_display_offers():
	if not house: return
	
	# 1. Calculate Fair Market Rent (adjusted by condition)
	# Use float casting to ensure precision during the ratio check
	var fair_rent: float = float(house.current_price) * 0.007 * float(house.apartment_condition)
	if fair_rent <= 0: fair_rent = 1.0 # Prevent division by zero
	
	var rent_ratio: float = float(house.rent) / fair_rent
	
	# 2. Probability check: High rent = fewer or no offers
	var chance_of_no_offer = 0.0
	if rent_ratio > 1.4: chance_of_no_offer = 0.9 
	elif rent_ratio > 1.2: chance_of_no_offer = 0.5
	
	if randf() < chance_of_no_offer:
		var msg = "No interest in " + house.id + ". Rent is too high!"
		Globals.notify_action(msg, Color.ORANGE, house) 
		return

	# 3. Generate 1-3 offers around the player's ASKING price
	rent_offers = []
	var offer_count = 1 if rent_ratio > 1.1 else randi_range(1, 3)
	
	for i in range(offer_count):
		# Potential tenants might try to haggle slightly below the slider value
		var raw_offer: float = float(house.rent) * randf_range(0.95, 1.0)
		
		# CRITICAL: Snap to 25 to match the slider grid
		var snapped_offer = int(snapped(raw_offer, 25))
		
		# Ensure we never offer $0
		rent_offers.append(max(25, snapped_offer))
	
	display_rent_offers()

func display_rent_offers():
	var renters_ui = $"../HUD/Phone/Renters/ScrollContainer/renters"
	if not renters_ui:
		push_error("Renters UI container not found!")
		return
	
	# Clear previous
	for child in renters_ui.get_children():
		child.queue_free()
	
	# Create new offer UI elements
	for offer in rent_offers:
		var renter = preload("res://houses/renter.tscn").instantiate()
		
		# Add to scene tree first
		renters_ui.add_child(renter)
		
		# Now call setup method with stats
		var stats = generate_renter_stats()
		renter.setup(offer, generate_renter_name(), stats)
		renter.pressed.connect(_on_renter_selected.bind(offer, stats))
	
	# Show UI
	if has_node("../HUD/event_popup"):
		$"../HUD/event_popup".visible = false
	
	if has_node("../events") and $"../events".has_method("rent_offers"):
		$"../events".rent_offers()

func _on_renter_selected(rent_amount: int, renter_stats: Dictionary):
	if house:
		house.add_tenant(rent_amount, renter_stats.lease_length)
		house.is_listed = false  # Mark as not listed anymore
		clear_offers_ui()
		house.apartment_condition = renter_stats.apartment_condition
		house.payment_punctuality = renter_stats.payment_punctuality
		Globals.EXP += 5 * Globals.exp_boost
		var duration_text = ""
		match renter_stats.lease_length:
			6: duration_text = "6-month"
			12: duration_text = "1-year"
			24: duration_text = "2-year"
			60: duration_text = "5-year lease"
			_: duration_text = "%d-month" % renter_stats.lease_length
		
		Globals.notify("Tenant Added! (%s lease)" % duration_text, Color.GREEN)
		

func clear_offers_ui():
	var renters_ui = $"../HUD/Phone/Renters/ScrollContainer/renters"
	if renters_ui:
		for child in renters_ui.get_children():
			child.queue_free()

# Helper functions
func generate_renter_name() -> String:
	var first = ["Alex", "Jamie", "Taylor", "Jordan", "Casey"].pick_random()
	var last = ["Smith", "Johnson", "Williams", "Brown", "Lee"].pick_random()
	return "%s %s" % [first, last]

func auto_generate_and_add_tenant():
	if not house: return
	
	# 1. Calculate what the market considers "Fair"
	var fair_rent: float = float(house.current_price) * 0.007 * float(house.apartment_condition)
	if fair_rent <= 0: fair_rent = 1.0
	
	# 2. Define the Agent's Logic [cite: 5]
	# Max Cap: 30% above market (High end)
	# Min Target: Market price (Low end)
	var max_acceptable_rent: float = fair_rent * 1.3
	var final_rent: int = int(house.rent)
	
	# 3. Negotiation Logic:
	if final_rent > max_acceptable_rent:
		# --- PRICE TOO HIGH: Force down to the cap ---
		final_rent = int(round(max_acceptable_rent / 25.0) * 25.0)
		Globals.notify("Agent lowered " + house.id + " to $" + add_comma_to_int(final_rent) + " (Market Cap)", Color.GOLDENROD)
	
	elif final_rent < (fair_rent * 0.8):
		# --- PRICE TOO LOW: Agent raises it to Fair Market value to get better profit ---
		final_rent = int(round(fair_rent / 25.0) * 25.0)
		Globals.notify("Agent raised " + house.id + " to $" + add_comma_to_int(final_rent) + " (Market Rate)", Color.AQUA)
	
	else:
		# --- PRICE IS GOOD: Proceed as is ---
		Globals.notify("Agent rented " + house.id + " for $" + add_comma_to_int(final_rent), Color.GREEN)

	# 4. Finalize the Renter [cite: 5]
	var stats = generate_renter_stats()
	
	# Update the actual house object with the negotiated rent [cite: 5]
	house.rent = final_rent 
	house.add_tenant(final_rent, stats.lease_length)
	house.is_listed = false
	house.apartment_condition = stats.apartment_condition
	house.payment_punctuality = stats.payment_punctuality
	
	# Refresh UI if it's open to show the new rent and tenant status
	if house.has_method("set_house_UI"):
		house.set_house_UI()

func generate_renter_stats() -> Dictionary:
	var lease_options = [
		{"duration": 6, "weight": 0.2},
		{"duration": 12, "weight": 0.6},
		{"duration": 24, "weight": 0.2}
	]
	
	var total_weight = 0.0
	for option in lease_options:
		total_weight += option.weight
	
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	var selected_lease = 12
	
	for option in lease_options:
		cumulative_weight += option.weight
		if random_value <= cumulative_weight:
			selected_lease = option.duration
			break
	
	# Adjust payment punctuality based on credit score
	var punctuality_base = 0.5
	if Globals.credit_score >= 750:
		punctuality_base = 0.8  # Better tenants for excellent credit
	elif Globals.credit_score >= 680:
		punctuality_base = 0.65
	elif Globals.credit_score >= 620:
		punctuality_base = 0.55
	else:
		punctuality_base = 0.4  # Worse tenants for poor credit
	
	return {
		"payment_punctuality": randf_range(punctuality_base, min(punctuality_base + 0.2, 1.0)),
		"apartment_condition": randf_range(0.7, 1.0),
		"lease_length": selected_lease
	}

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

# Show house info
func _on_button_button_down() -> void:
	game.house = house
	var renters_container = $"../HUD/Phone/Renters/ScrollContainer/renters"
	if game.house and renters_container and renters_container.get_child_count() > 0:
		$house_info.visible = true
		$house_info/morgage.text = "payment: " + add_comma_to_int(house.mortgage)
		$house_info/Value.text = "house value: " + add_comma_to_int(house.current_price)

# Hide House Info
func _on_button_button_up() -> void:
	$house_info.visible = false
