extends Node3D

@onready var house = $".."

var rent_paid: bool = false
@onready var rent_collect_timer: Timer = $"../rent_collect_timer"
@onready var payment_delay_timer: Timer = $"../payment_delay_timer"
var month_timer: Timer
var current_punctuality: float = 0.0
var monthly_variation: float = 15.0
var stored_cash: int = 0
var accumulated_months: int = 0
var max_cash: int = 1000000000

func _ready() -> void:
	if not house.owned:
		$Dollar_sign.visible = false
		$Label3D.text = ""
	payment_delay_timer = Timer.new()
	payment_delay_timer.one_shot = true
	
func reset():
	rent_paid = false
	current_punctuality = 0.0
	monthly_variation = 15.0
	stored_cash = 0
	accumulated_months = 0
	if not house.owned:
		$Dollar_sign.visible = false
		$Label3D.text = ""

func _on_payment_delay_timeout():
	if house.owned and house.has_tenant and house.lease_length > 0:
		rent_paid = true
		tenant_pays_rent()

func _on_rent_collect_timeout():
	collect_rent()
	if Globals.hasagent:
		rent_collect_timer.start(2.0)

func _on_agent_status_changed(new_status: bool):
	if not new_status:
		rent_collect_timer.stop()

func Month_timer():
	if not house.owned:
		$Label3D.text = ""
		$Dollar_sign.visible = false
		return

	if house.owned:
		$Label3D.text = get_rent_status()

	if house.has_tenant:
		house.lease_length -= 1
		if house.lease_length <= 0:
			house.remove_tenant()
			collect_rent()
			if is_instance_valid(house.events):
				house.events.tenant_moves_out(house)
			if Globals.renter_finder:
				house.is_listed = true
			return  # Exit to avoid redundant checks after tenant removal
			
	if house.has_tenant and house.lease_length > 0 and payment_delay_timer.time_left <= 0 and stored_cash < max_cash:
		var base_punctuality_percent = house.payment_punctuality * 100.0
		var monthly_punctuality = base_punctuality_percent * randf_range(0.85, 1.15)
		monthly_punctuality = clamp(monthly_punctuality, 0.0, 100.0)
		var delay_seconds = 30.0 * (1.0 - monthly_punctuality / 100.0)
		payment_delay_timer.start(delay_seconds)
		if house.owned:
			$Label3D.text = "Rent Delayed: " + str(snapped(delay_seconds, 0.1)) + "s"

func tenant_pays_rent():
	if not house.owned or not house.has_tenant or house.lease_length <= 0 or stored_cash >= max_cash:
		return
	$Dollar_sign.visible = true
	stored_cash += house.rent
	accumulated_months += 1
	if house.owned:
		$Label3D.text = "Rent Ready to Collect: $" + str(stored_cash) + " (" + str(accumulated_months) + " months)"
	house.paid_rent = true
	if Globals.hasagent and rent_collect_timer:
		rent_collect_timer.start(2.0)

func show_floating_label(message: String, color: Color) -> void:
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	var label = Label.new()
	label.text = message
	label.position = Vector2(700, 500)
	label.modulate = color
	canvas_layer.add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 4.0)
	tween.tween_property(label, "modulate:a", 0, 4.0)
	tween.tween_callback(label.queue_free)

func collect_rent():
	if not house.owned:
		$Dollar_sign.visible = false
		$Label3D.text = ""
		return

	if Globals.rent_bost > 0.0 and stored_cash > 0:
		var boosted_amount = stored_cash * (1.0 + Globals.rent_bost)
		Globals.money += boosted_amount
		show_floating_label("Collected Rent: $" + str(boosted_amount) + " (" + str(accumulated_months) + " months)", Color.GREEN)
	elif stored_cash > 0:
		Globals.money += stored_cash
		show_floating_label("Collected Rent: $" + str(stored_cash) + " (" + str(accumulated_months) + " months)", Color.GREEN)
	
	var months_collected = accumulated_months
	stored_cash = 0
	accumulated_months = 0
	if house.has_tenant:
		house.apartment_condition -= 0.01 * months_collected
		house.apartment_condition = max(house.apartment_condition, 0)
	
	if house.owned:
		Globals.exp += months_collected
		$Label3D.text = get_rent_status()
		$Dollar_sign.visible = false

func reset_rent_state(preserve_cash: bool = false):
	rent_paid = false
	if not preserve_cash:
		stored_cash = 0
		accumulated_months = 0
	$Dollar_sign.visible = false
	$Label3D.text = ""
	if payment_delay_timer:
		payment_delay_timer.stop()
	if rent_collect_timer:
		rent_collect_timer.stop()

func get_rent_status() -> String:
	if not house.owned:
		return ""
	if stored_cash > 0:
		return "Rent Ready to Collect: $" + str(stored_cash) + " (" + str(accumulated_months) + " months)"
	elif house.has_tenant and payment_delay_timer.time_left > 0:
		return "Rent Late: " + str(snapped(payment_delay_timer.time_left, 0.1)) + "s"
	else:
		return ""
