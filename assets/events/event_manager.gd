extends Node

# Configuration
var event_interval: float = 90.0
var event_timer = Timer.new()

# To handle multiple houses needing relisting at once
var houses_needing_relist: Array = []

func _ready():
	# Initialize the timer
	event_timer.wait_time = event_interval
	event_timer.autostart = true
	event_timer.one_shot = false
	event_timer.timeout.connect(_trigger_random_event)
	add_child(event_timer)

func _trigger_random_event():
	var houses = get_tree().get_nodes_in_group("houses")
	var owned_houses = houses.filter(func(h): return h.owned)
	
	if owned_houses.is_empty():
		return

	# Randomize next event time slightly (75-105s)
	event_timer.wait_time = event_interval + randf_range(-15, 15)
	
	var roll = randf()
	if roll < 0.12:
		event_tenant_moves_out(owned_houses)
	elif roll < 0.25:
		event_maintenance(owned_houses)
	elif roll < 0.35:
		event_market_shift(owned_houses)
	elif roll < 0.45:
		event_tax_season()
	elif roll < 0.55:
		event_rent_logic(owned_houses)
	elif roll < 0.65:
		event_hoa_incident()
	elif roll < 0.75:
		event_squatter_incident(owned_houses)
	elif roll < 0.85:
		event_disaster(owned_houses)
	else:
		event_random_bonus()

# --- 1. VACANCY EVENTS ---

func event_tenant_moves_out(owned_houses: Array):
	var occupied = owned_houses.filter(func(h): return h.has_tenant)
	if occupied.is_empty(): return
	
	var house = occupied.pick_random()
	tenant_moves_out(house)

func tenant_moves_out(house: Node):
	if not is_instance_valid(house): return
	
	# Use your house's built-in function to handle the logic
	if house.has_method("remove_tenant"):
		house.remove_tenant()
	else:
		# Fallback if the function name changes
		house.has_tenant = false
	
	# Track for the relist button
	houses_needing_relist.append(house)
	
	# UI Notification
	Globals.notify_action(
		"VACANCY: A Tenant moved out! The house is now empty.", 
		Color.ORANGE, 
		self 
	)

# --- 2. MAINTENANCE EVENTS ---

func event_maintenance(owned_houses: Array):
	var house = owned_houses.pick_random()
	var repairs = [
		{"name": "Leaking Roof", "min": 800, "max": 2500},
		{"name": "Broken HVAC", "min": 1200, "max": 3500},
		{"name": "Termite Infestation", "min": 500, "max": 1500},
		{"name": "Electrical Issue", "min": 2000, "max": 5000},
		{"name": "Water Pipe Burst", "min": 400, "max": 1200}
	]
	var repair = repairs.pick_random()
	var cost = randi_range(repair["min"], repair["max"])
	
	Globals.money -= cost
	Globals.notify("REPAIR: %s at a House. Cost: -$%d" % [repair["name"], cost], Color.LIGHT_CORAL)

# --- 3. MARKET EVENTS ---

func event_market_shift(owned_houses: Array):
	var house = owned_houses.pick_random()
	var percent = randf_range(0.04, 0.10)
	
	if randf() > 0.4:
		var gain = house.current_price * percent
		house.current_price += gain
		Globals.notify("MARKET: Local property values spiked! A House gained $%d in value." % int(gain), Color.CYAN)
	else:
		var loss = house.current_price * percent
		house.current_price -= loss
		Globals.notify("MARKET: Economic downturn. A House lost value.", Color.ORANGE_RED)

# --- 4. GOVERNMENT / TAX ---

func event_tax_season():
	var total_value = 0
	for h in get_tree().get_nodes_in_group("houses"):
		if h.owned: total_value += h.current_price
	
	var tax = total_value * 0.006
	if tax > 100:
		Globals.money -= tax
		Globals.notify("TAXES: Annual property taxes collected. Total: -$%d" % int(tax), Color.CRIMSON)

func event_hoa_incident():
	var cost = [150, 250, 500].pick_random()
	var reasons = ["Uncut Grass", "Illegal Parking", "Trash Cans left out"]
	Globals.money -= cost
	Globals.notify("HOA FINE: %s. Paid: -$%d" % [reasons.pick_random(), cost], Color.CORAL)

# --- 5. RENT LOGIC ---

func event_rent_logic(owned_houses: Array):
	var occupied = owned_houses.filter(func(h): return h.has_tenant)
	if occupied.is_empty(): return
	
	var house = occupied.pick_random()
	if randf() > 0.6: 
		var increase = randi_range(100, 400)
		house.rent += increase
		Globals.notify("RENT: A Tenant signed a lease renewal at +$%d/mo!" % increase, Color.SPRING_GREEN)
	else:
		Globals.notify("RENT: A Tenant requested an upgrade, but you declined.", Color.KHAKI)

func event_squatter_incident(owned_houses: Array):
	var vacant = owned_houses.filter(func(h): return !h.has_tenant)
	if vacant.is_empty(): return
	
	var house = vacant.pick_random()
	var legal_fees = randi_range(1000, 2500)
	Globals.money -= legal_fees
	Globals.notify("SQUATTERS: Someone broke into a vacant house! Legal fees: -$%d" % legal_fees, Color.DARK_ORANGE)

# --- 6. DISASTER / BONUS ---

func event_disaster(owned_houses: Array):
	var house = owned_houses.pick_random()
	var cost = randi_range(3000, 7000)
	Globals.money -= cost
	Globals.notify("DISASTER: Severe damage hit a House! Repairs: -$%d" % cost, Color.RED)

func event_random_bonus():
	var amt = randi_range(1000, 4000)
	Globals.money += amt
	Globals.notify("BONUS: A lucky investment paid off! Received: +$%d" % amt, Color.GOLD)

# --- ACTION HANDLERS ---

func _on_relist_house_button_pressed() -> void:
	if not houses_needing_relist.is_empty():
		var house = houses_needing_relist.pop_front()
		if is_instance_valid(house):
			house.is_listed = true
			Globals.notify("SUCCESS: House is back on the market.", Color.GREEN)

func rent_offers():
	Globals.notify("ALERT: You have new rent offers waiting!", Color.AQUAMARINE)
