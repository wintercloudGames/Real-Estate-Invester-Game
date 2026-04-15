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
	if not house: 
		return
	
	# Get current market-adjusted house value
	var house_value = house.current_price
	
	# Calculate realistic rent range (5-10% annual value)
	var annual_min = house_value * 0.05
	var annual_max = house_value * 0.10
	var monthly_min = annual_min / 12
	var monthly_max = annual_max / 12
	
	# Apply market conditions
	if has_node("../Market") and $"../Market".has_method("get_market_condition"):
		var market = $"../Market".get_market_condition()
		monthly_min *= (1 + (market * 0.05))
		monthly_max *= (1 + (market * 0.3))
	
	# Generate 1-5 offers in this range
	rent_offers = []
	for i in range(randi_range(1, 5)):
		var offer = snapped(randf_range(monthly_min, monthly_max), 25)
		rent_offers.append(int(offer))
	

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
	if not house: 
		return
	# Generate rent amount
	var house_value = house.current_price
	var annual_min = house_value * 0.05
	var annual_max = house_value * 0.10
	var monthly_rent = snapped(randf_range(annual_min/12, annual_max/12), 25)
	
	# Generate renter stats
	var renter_stats = generate_renter_stats()
	
	# Directly add tenant without UI
	house.add_tenant(int(monthly_rent), renter_stats.lease_length)
	house.is_listed = false  # Mark as not listed
	house.apartment_condition = renter_stats.apartment_condition
	house.payment_punctuality = renter_stats.payment_punctuality
	
	# Show notification
	Globals.notify("Auto-rented: $" + str(monthly_rent), Color.GREEN)
	

# In rent_offer_system.gd
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
