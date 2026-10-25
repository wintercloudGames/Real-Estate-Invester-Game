extends Node3D

@onready var house = $".."

var rent_paid: bool = false
@onready var rent_collect_timer: Timer = $"../rent_collect_timer"
@onready var payment_delay_timer: Timer = $"../payment_delay_timer"

# UI Nodes
@onready var dollar_sign = $Dollar_sign
@onready var label_3d = $Label3D

var current_punctuality: float = 0.0
var monthly_variation: float = 15.0
var stored_cash: int = 0
var accumulated_months: int = 0
var max_cash: int = 1000000000

func _ready() -> void:
	if is_instance_valid(house) and not house.owned:
		dollar_sign.visible = false
		label_3d.text = ""

func reset():
	rent_paid = false
	current_punctuality = 0.0
	monthly_variation = 15.0
	stored_cash = 0
	accumulated_months = 0
	if is_instance_valid(house) and not house.owned:
		dollar_sign.visible = false
		label_3d.text = ""

func _on_payment_delay_timeout():
	if not is_instance_valid(house) or not house.owned:
		return

	if house.is_apartment:
		_process_apartment_rent_payment()
	else:
		if house.has_tenant and house.lease_length > 0:
			rent_paid = true
			tenant_pays_rent()

func _on_rent_collect_timeout():
	if Globals.hasagent:
		dollar_sign.visible = false # Hide 3D indicator as agent is collecting automatically
		collect_rent()
		if is_instance_valid(rent_collect_timer):
			rent_collect_timer.start(2.0)

func Month_timer():
	if not is_instance_valid(house): return
	
	if not house.owned:
		label_3d.text = ""
		dollar_sign.visible = false
		return

	# --- APARTMENT HANDLING ---
	if house.is_apartment:
		_process_apartment_month_tick()
		return

	# --- SINGLE-FAMILY HOUSE HANDLING ---
	label_3d.text = get_rent_status()

	if house.has_tenant:
		house.lease_length -= 1
		if house.lease_length <= 0:
			collect_rent()
			house.remove_tenant()
			
			if is_instance_valid(house.events):
				house.events.tenant_moves_out(house)
			
			if Globals.renter_finder:
				house.is_listed = true
			return 
			
	if house.has_tenant and payment_delay_timer.time_left <= 0 and stored_cash < max_cash:
		var base_punctuality_percent = house.payment_punctuality * 100.0
		var monthly_punctuality = clamp(base_punctuality_percent * randf_range(0.85, 1.15), 0.0, 100.0)
		var delay_seconds = 30.0 * (1.0 - (monthly_punctuality / 100.0))
		
		payment_delay_timer.start(max(0.1, delay_seconds))
		label_3d.text = "Rent Delayed: " + str(snapped(delay_seconds, 0.1)) + "s"

# --- APARTMENT LOGIC ---

func _process_apartment_month_tick() -> void:
	var pending_units: int = 0
	
	for unit in house.units:
		if unit["has_tenant"]:
			unit["lease_length"] -= 1
			if unit["lease_length"] <= 0:
				# Lease expired - collect any leftover cash and move tenant out
				if unit.get("stored_cash", 0) > 0:
					stored_cash += unit["stored_cash"]
					unit["stored_cash"] = 0
				unit["has_tenant"] = false
				unit["is_listed"] = false
				unit["lease_length"] = 12
				Globals.notify("Unit #" + str(unit["unit_id"]) + " lease expired!", Color.ORANGE)
			else:
				pending_units += 1

	if pending_units > 0 and payment_delay_timer.time_left <= 0 and stored_cash < max_cash:
		var delay_seconds = randf_range(1.0, 15.0)
		payment_delay_timer.start(max(0.1, delay_seconds))
		label_3d.text = get_rent_status()

func _process_apartment_rent_payment() -> void:
	var total_added = 0
	
	for unit in house.units:
		if unit["has_tenant"]:
			var unit_rent = int(unit["rent"])
			unit["stored_cash"] = unit.get("stored_cash", 0) + unit_rent
			total_added += unit_rent
			unit["paid_rent"] = false # Reset collection flag for new balance
			
	if total_added > 0:
		stored_cash += total_added
		accumulated_months += 1
		
		if Globals.hasagent:
			dollar_sign.visible = false
			if is_instance_valid(rent_collect_timer):
				rent_collect_timer.start(2.0)
		else:
			dollar_sign.visible = true
			
		label_3d.text = get_rent_status()

# --- STANDARD RENT PAY & COLLECT LOGIC ---

func tenant_pays_rent():
	if not is_instance_valid(house) or not house.owned or not house.has_tenant or stored_cash >= max_cash:
		return
	
	if not Globals.hasagent:
		dollar_sign.visible = true
	else:
		dollar_sign.visible = false
		
	stored_cash += house.rent
	accumulated_months += 1
	
	if house.owned:
		label_3d.text = "Rent Ready: $" + str(stored_cash) + " (" + str(accumulated_months) + " mos)"
	
	house.paid_rent = true
	
	if Globals.hasagent and is_instance_valid(rent_collect_timer):
		rent_collect_timer.start(2.0)

func collect_rent():
	# Gather pooled unit cash if apartment
	if house and house.is_apartment:
		for unit in house.units:
			if unit.get("stored_cash", 0) > 0:
				stored_cash += unit["stored_cash"]
				unit["stored_cash"] = 0
				unit["paid_rent"] = true

	if stored_cash <= 0: return
	
	var total_to_receive = float(stored_cash)
	if Globals.rent_bost > 0.0:
		total_to_receive *= (1.0 + Globals.rent_bost)
	
	Globals.money += total_to_receive
	
	if Globals.hasagent:
		Globals.notify_batched_rent(total_to_receive)
	else:
		Globals.notify("Collected Rent: $" + Globals.add_comma_to_int(int(total_to_receive)), Color.GREEN)

	var months_collected = accumulated_months
	stored_cash = 0
	accumulated_months = 0
	
	if is_instance_valid(house):
		if house.has_tenant:
			house.apartment_condition = max(0, house.apartment_condition - (0.01 * months_collected))
		
		if house.owned:
			Globals.EXP += 2.0 * max(1, months_collected) * Globals.exp_boost
			label_3d.text = get_rent_status()
			dollar_sign.visible = false

func reset_rent_state(preserve_cash: bool = false):
	rent_paid = false
	if not preserve_cash:
		stored_cash = 0
		accumulated_months = 0
		if house and house.is_apartment:
			for unit in house.units:
				unit["stored_cash"] = 0
	if is_instance_valid(payment_delay_timer):
		payment_delay_timer.stop()
	if is_instance_valid(rent_collect_timer):
		rent_collect_timer.stop()
	dollar_sign.visible = false
	label_3d.text = ""

func get_rent_status() -> String:
	if not is_instance_valid(house) or not house.owned:
		return ""
	if stored_cash > 0:
		return "Apt Rent Ready: $" + Globals.add_comma_to_int(stored_cash) if house.is_apartment else "Rent Ready: $" + str(stored_cash) + " (" + str(accumulated_months) + " mos)"
	elif payment_delay_timer and payment_delay_timer.time_left > 0:
		return "Rent Late: " + str(snapped(payment_delay_timer.time_left, 0.1)) + "s"
	else:
		return ""
