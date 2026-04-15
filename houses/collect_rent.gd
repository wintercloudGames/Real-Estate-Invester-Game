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
	if is_instance_valid(house) and house.owned and house.has_tenant and house.lease_length > 0:
		rent_paid = true
		tenant_pays_rent()

func _on_rent_collect_timeout():
	if Globals.hasagent:
		dollar_sign.visible = false # Hide it because the agent is handling it now
		collect_rent()
		if is_instance_valid(rent_collect_timer):
			rent_collect_timer.start(2.0)

func Month_timer():
	# 1. Validation Check
	if not is_instance_valid(house): return
	
	if not house.owned:
		label_3d.text = ""
		dollar_sign.visible = false
		return

	label_3d.text = get_rent_status()

	if house.has_tenant:
		house.lease_length -= 1
		if house.lease_length <= 0:
			# Cache result before tenant is removed
			collect_rent()
			house.remove_tenant()
			
			if is_instance_valid(house.events):
				house.events.tenant_moves_out(house)
			
			if Globals.renter_finder:
				house.is_listed = true
			return 
			
	# 2. Start Payment Delay
	if house.has_tenant and payment_delay_timer.time_left <= 0 and stored_cash < max_cash:
		var base_punctuality_percent = house.payment_punctuality * 100.0
		var monthly_punctuality = clamp(base_punctuality_percent * randf_range(0.85, 1.15), 0.0, 100.0)
		
		# 30 seconds max delay, influenced by tenant punctuality
		var delay_seconds = 30.0 * (1.0 - (monthly_punctuality / 100.0))
		
		# Safety: Ensure delay is at least a frame to avoid timer errors
		payment_delay_timer.start(max(0.1, delay_seconds))
		
		if house.owned:
			label_3d.text = "Rent Delayed: " + str(snapped(delay_seconds, 0.1)) + "s"

func tenant_pays_rent():
	if not is_instance_valid(house) or not house.owned or not house.has_tenant or stored_cash >= max_cash:
		return
	
	# ONLY show the dollar sign if the player DOES NOT have an agent
	if not Globals.hasagent:
		dollar_sign.visible = true
	else:
		dollar_sign.visible = false # Ensure it's hidden if an agent was just hired
		
	stored_cash += house.rent
	accumulated_months += 1
	
	if house.owned:
		label_3d.text = "Rent Ready to Collect: $" + str(stored_cash) + " (" + str(accumulated_months) + " months)"
	
	house.paid_rent = true
	
	# The agent logic already handles the collection timer
	if Globals.hasagent and is_instance_valid(rent_collect_timer):
		rent_collect_timer.start(2.0)

func collect_rent():
	if stored_cash <= 0: return
	
	var total_to_receive = float(stored_cash)
	if Globals.rent_bost > 0.0:
		total_to_receive *= (1.0 + Globals.rent_bost)
	
	Globals.money += total_to_receive
	
	# --- NEW BATCHING LOGIC ---
	if Globals.hasagent:
		Globals.notify_batched_rent(total_to_receive)
	else:
		# If collecting manually, keep the individual notification
		Globals.notify("Collected Rent: $" + Globals.add_comma_to_int(int(total_to_receive)), Color.GREEN)
	# --------------------------

	var months_collected = accumulated_months
	stored_cash = 0
	accumulated_months = 0
	
	if is_instance_valid(house):
		if house.has_tenant:
			house.apartment_condition = max(0, house.apartment_condition - (0.01 * months_collected))
		
		if house.owned:
			Globals.EXP += 2.0 * months_collected * Globals.exp_boost
			label_3d.text = get_rent_status()
			dollar_sign.visible = false

func reset_rent_state(preserve_cash: bool = false):
	rent_paid = false
	if not preserve_cash:
		stored_cash = 0
		accumulated_months = 0
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
		return "Rent Ready to Collect: $" + str(stored_cash) + " (" + str(accumulated_months) + " months)"
	elif house.has_tenant and is_instance_valid(payment_delay_timer) and payment_delay_timer.time_left > 0:
		return "Rent Late: " + str(snapped(payment_delay_timer.time_left, 0.1)) + "s"
	else:
		return ""
