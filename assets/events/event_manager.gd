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
	if roll < 0.10:
		event_tenant_moves_out(owned_houses)
	elif roll < 0.20:
		event_maintenance(owned_houses)
	elif roll < 0.30:
		event_market_shift(owned_houses)
	elif roll < 0.38:
		event_tax_season()
	elif roll < 0.45:
		event_rent_logic(owned_houses)
	elif roll < 0.52:
		event_hoa_incident()
	elif roll < 0.58:
		event_squatter_incident(owned_houses)
	elif roll < 0.65:
		event_disaster(owned_houses)
	elif roll < 0.72:
		event_gentrification(owned_houses) # NEW
	elif roll < 0.80:
		event_public_works(owned_houses)   # NEW
	elif roll < 0.88:
		event_vandalism(owned_houses)      # NEW
	elif roll < 0.94:
		event_energy_upgrade(owned_houses) # NEW
	else:
		event_random_bonus()

# --- 1. VACANCY EVENTS ---

func event_tenant_moves_out(owned_houses: Array):
	var occupied = owned_houses.filter(func(h): return h.has_tenant)
	if occupied.is_empty(): return
	
	var house = occupied.pick_random()
	tenant_moves_out(house)

func tenant_moves_out(house: Node):
	if not is_instance_valid(house): 
		return
	if house.has_method("remove_tenant"):
		house.remove_tenant()
	else:
		# Fallback if the method doesn't exist
		house.has_tenant = false
		house.rent = 0
	
	# 3. Notification and Relisting Logic
	if not Globals.renter_finder:
		# PLAYER MANUAL MODE:
		# We pass 'house' as the action_target so the "More Info" button 
		# in Globals.notify_action can call house.open_house_ui()
		var msg = "VACANCY: A tenant moved out of " + house.id + "!"
		Globals.notify_action(
			msg, 
			Color.ORANGE, 
			house # This ensures buttons target this specific house
		)
		
		house.is_listed = false
	else:
		house.is_listed = true
		var agent_msg = "AGENT: Tenant moved out of " + house.id + ". Relisted automatically."
		Globals.notify(agent_msg, Color.SKY_BLUE)

	Globals.update_economy()
# --- 2. MAINTENANCE & CRIME ---

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
	Globals.notify("REPAIR: %s. Cost: -$%s" % [repair["name"], Globals.add_comma_to_int(cost)], Color.LIGHT_CORAL)

func event_vandalism(owned_houses: Array):
	var house = owned_houses.pick_random()
	var cost = randi_range(200, 900)
	Globals.money -= cost
	Globals.notify("CRIME: Vandalism reported. Cleanup cost: -$%s" % Globals.add_comma_to_int(cost), Color.CHOCOLATE)

# --- 3. MARKET & NEIGHBORHOOD ---

func event_market_shift(owned_houses: Array):
	var house = owned_houses.pick_random()
	var percent = randf_range(0.04, 0.10)
	
	if randf() > 0.4:
		var gain = house.current_price * percent
		house.current_price += gain
		Globals.notify("MARKET: Property values spiked! House gained $%s in value." % Globals.add_comma_to_int(int(gain)), Color.CYAN)
	else:
		var loss = house.current_price * percent
		house.current_price -= loss
		Globals.notify("MARKET: Economic downturn. A house lost value.", Color.ORANGE_RED)

func event_gentrification(owned_houses: Array):
	var house = owned_houses.pick_random()
	var boost = randi_range(15000, 45000)
	house.current_price += boost
	Globals.notify("NEIGHBORHOOD: A trendy cafe opened nearby! Value: +$%s" % Globals.add_comma_to_int(boost), Color.DEEP_PINK)

func event_public_works(owned_houses: Array):
	# Infrastructure helps value but can temporarily hurt rent
	var house = owned_houses.pick_random()
	house.current_price += 10000
	if house.has_tenant:
		house.rent -= 50
	Globals.notify("CITY: New subway line construction. Value up, but rent temporarily down.", Color.MEDIUM_PURPLE)

# --- 4. GOVERNMENT & LEGAL ---

func event_tax_season():
	var total_value = 0
	for h in get_tree().get_nodes_in_group("houses"):
		if h.owned: total_value += h.current_price
	
	var tax = total_value * 0.006
	if tax > 100:
		Globals.money -= tax
		Globals.notify("TAXES: Annual property taxes collected. Total: -$%s" % Globals.add_comma_to_int(int(tax)), Color.CRIMSON)

func event_hoa_incident():
	var cost = [150, 250, 500].pick_random()
	var reasons = ["Uncut Grass", "Illegal Parking", "Trash Cans left out"]
	Globals.money -= cost
	Globals.notify("HOA FINE: %s. Paid: -$%s" % [reasons.pick_random(), Globals.add_comma_to_int(cost)], Color.CORAL)

func event_squatter_incident(owned_houses: Array):
	var vacant = owned_houses.filter(func(h): return !h.has_tenant)
	if vacant.is_empty(): return
	
	var house = vacant.pick_random()
	var legal_fees = randi_range(1000, 2500)
	Globals.money -= legal_fees
	Globals.notify("SQUATTERS: Someone broke into a vacant house! Legal fees: -$%s" % Globals.add_comma_to_int(legal_fees), Color.DARK_ORANGE)

# --- 5. RENT & UPGRADES ---

func event_rent_logic(owned_houses: Array):
	var occupied = owned_houses.filter(func(h): return h.has_tenant)
	if occupied.is_empty(): return
	
	var house = occupied.pick_random()
	if randf() > 0.6: 
		var increase = randi_range(100, 400)
		house.rent += increase
		Globals.notify("RENT: A Tenant signed a lease renewal at +$%s/mo!" % Globals.add_comma_to_int(increase), Color.SPRING_GREEN)
	else:
		Globals.notify("RENT: A Tenant requested an upgrade, but you declined.", Color.KHAKI)

func event_energy_upgrade(owned_houses: Array):
	var house = owned_houses.pick_random()
	var cost = 5000
	if Globals.money > cost:
		Globals.money -= cost
		house.rent += 250
		Globals.notify("UPGRADE: Solar panels installed. Rent increased: +$250/mo", Color.YELLOW)

# --- 6. DISASTER / BONUS ---

func event_disaster(owned_houses: Array):
	var house = owned_houses.pick_random()
	var cost = randi_range(3000, 7000)
	Globals.money -= cost
	Globals.notify("DISASTER: severe weather damage reported! Repairs: -$%s" % Globals.add_comma_to_int(cost), Color.RED)

func event_random_bonus():
	var amt = randi_range(1000, 4000)
	Globals.money += amt
	Globals.notify("BONUS: A local grant was awarded to your business! Received: +$%s" % Globals.add_comma_to_int(amt), Color.GOLD)

# --- ACTION HANDLERS ---

func _on_relist_house_button_pressed() -> void:
	if not houses_needing_relist.is_empty():
		var house = houses_needing_relist.pop_front()
		if is_instance_valid(house):
			house.is_listed = true
			Globals.notify("SUCCESS: House is back on the market.", Color.GREEN)

func rent_offers():
	Globals.notify("ALERT: You have new rent offers waiting!", Color.AQUAMARINE)
