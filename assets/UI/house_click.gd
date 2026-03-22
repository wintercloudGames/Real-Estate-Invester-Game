# house.gd
extends Node3D

@export var is_building = false
@export var plot = false
@export var rarity = 1.0
var base_price: float = randi_range(80000, 500000) * rarity
var current_price: float = base_price
var previous_price: float = 0
var mortgage = 0
var rent = 0
var lease_length = 0
var apartment_condition = 1
var payment_punctuality = 1
var mortgage_deducted = false
var tenant_offers = null
var is_listed = false
var edit_mode = false
var stored_cash = 0


@onready var Collect_Rent = $Collect_Rent
@onready var Listing_ui: Node = get_node("/root/Root/UserInterface/Game/HUD/House_listing_ui")
@onready var events: Node = get_node("/root/Root/UserInterface/Game/events")
@onready var House_ui: Node = get_node("/root/Root/UserInterface/Game/HUD/House_info")
@onready var renter = null
@onready var game: Node = get_node("/root/Root/UserInterface/Game")

var id: String = "" 
var bought_price = 0
var loan_price = 0.0 
var owned = false
var has_loan = false
var has_tenant = false
var tenant = null
var paid_rent = false
var just_bought = false
var upgrade_max = 10
var upgrade_amount = 0
var for_sale = false
var time_on_market = 0

func _init():
	add_to_group("houses")

func _ready() -> void:
	Globals.month_ended.connect($Collect_Rent.Month_timer)
	if not is_building:
		setup_yard_editor()
	if id == "":
		id = "house_" + str(get_path().hash())
	Collect_Rent = $Collect_Rent
	randomize()
	previous_price = base_price
	loan_price = current_price * 0.8

func setup_yard_editor():
	if has_node("YardEditor"):
		var yard_editor = $YardEditor
		if yard_editor:
			yard_editor.add_to_group("yard_editor")
			yard_editor.edit_mode_toggled.connect(_on_yard_edit_mode_changed)

func add_to_base_price(amount: int):
	base_price += amount

var remaining_months: int = 0
func set_remaining_months(new_months: int) -> void:
	remaining_months = new_months

func _on_yard_edit_mode_changed(is_editing: bool):
	pass

func update_market_value(market_change_percent: float) -> void:
	previous_price = current_price
	if abs(market_change_percent) < 0.0005:
		return
	var market_multiplier = 1.0 + market_change_percent
	var noise = randf_range(0.9975, 1.0025)
	current_price = previous_price * market_multiplier * noise
	current_price = max(round(current_price / 5000.0) * 5000, 5000)

func _process(delta: float) -> void:

	$Label3D5.text = ""           
	$Label3D3.text = ""        

	if owned:

		if loan_price > 0:
			$Label3D.text = "FINANCED PROPERTY"
			$Label3D.modulate = Color.YELLOW
			$Label3D2.text = "Loan Balance: " + add_comma_to_int(int(loan_price))
			$Label3D2.visible = true
			has_loan = true
		else:
			$Label3D.text = "OWNED PROPERTY"
			$Label3D.modulate = Color.GREEN
			$Label3D2.visible = false
			$Label3D2.text = ""
			has_loan = false
			mortgage = 0
			loan_price = 0
		if has_tenant and rent > 0:
			var effective_rent = rent
			if Globals.rent_bost > 0.0:
				effective_rent = rent * (1.0 + Globals.rent_bost)
			$Label3D3.text = "CashFlow: " + add_comma_to_int(int(effective_rent - mortgage))
			$Label3D3.modulate = Color.GREEN if effective_rent >= mortgage else Color.RED
		else:
			$Label3D3.text = ""
		$Label3D4.text = ""

	else:
		$Label3D.text = add_comma_to_int(int(current_price))
		$Label3D2.text = ""
		$Label3D3.text = ""

		if for_sale:

			$Label3D.modulate = Color.WHITE
			$Label3D4.text = "FOR SALE"
			$Label3D4.modulate = Color(1, 0.8, 0.2)

			var down_payment_needed = current_price * 0.2
			if Globals.money >= down_payment_needed:
				$Label3D5.text = "Affordable!"
				$Label3D5.modulate = Color.GREEN
			else:
				$Label3D5.text = ""

		else:
			$Label3D.modulate = Color(0.7, 0.7, 0.7)
			$Label3D4.text = ""           
			$Label3D4.modulate = Color(0.6, 0.6, 0.6)
			$Label3D5.text = ""                       

		if is_listed and not has_tenant:
			$Label3D4.text = "Listed For Rent"
			$Label3D4.modulate = Color.CYAN


func create_label(stat):
	if stat == true:
		$Label3D5.text = "Affordable!"
	else:
		$Label3D5.text = ""

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_area_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and !Globals.yard_edit:
		game.house = self
		if owned:
			game.set_house_UI()
		else:
			if for_sale:       
				game.set_listing_UI()


func edit_yard():
	$Yard_editor.enter_edit_mode()

func remove_tenant():
	has_tenant = false
	rent = 0
	tenant_offers = null
	lease_length = 0
	is_listed = false
	if Collect_Rent:
		Collect_Rent.reset_rent_state(true)

func add_tenant(income: int, lease_duration: int = 12):
	rent = income
	lease_length = lease_duration
	House_ui.income = income
	has_tenant = true

func sell_house(sell_price: int) -> void:
	owned = false
	has_tenant = false
	rent = 0
	lease_length = 0
	paid_rent = false
	stored_cash = 0
	has_loan = false
	loan_price = 0
	mortgage = 0
	is_listed = false
	tenant_offers = null
	Globals.net_worth -= bought_price
	Globals.money += sell_price
	Collect_Rent.reset()
	time_on_market = 0
	if $Collect_Rent/Dollar_sign.visible == true:
		collect_rent()
	if Collect_Rent:
		Collect_Rent.reset_rent_state(true)
	$Label3D.text = add_comma_to_int(current_price)
	$Label3D2.text = ""
	$Label3D3.text = ""
	$Label3D4.text = ""
	$Label3D.modulate = Color.WHITE
	
	$Collect_Rent/Dollar_sign.visible = false

func house_buy(use_loan: bool, buy_price: int, loan_amount: int, loan_mod: Node = null) -> void:
	if use_loan and (not loan_mod or not is_instance_valid(loan_mod)):
		push_error("No valid loan_mod for house %s. Reverting to cash purchase." % name)
		use_loan = false
	owned = true
	$Label3D5.text = ""
	bought_price = buy_price
	has_loan = use_loan
	Globals.exp += buy_price/100000
	Globals.net_worth += buy_price
	Listing_ui.visible = false
	time_on_market = 0
	if use_loan:
		loan_price = float(loan_amount)  # Ensure float
		mortgage = int(loan_mod.payment if loan_mod and is_instance_valid(loan_mod) else 0)
		Globals.credit_score -= randi_range(15,80)
		Globals.credit_score = clamp(Globals.credit_score, 300, 850)
	else:
		just_bought = true
		loan_price = 0
		mortgage = 0

func collect_rent():
	$Collect_Rent.collect_rent()

func _on_timer_timeout() -> void:
	#$Timer.start()
	if Collect_Rent != null:
		Collect_Rent.Month_timer()
	if loan_price > 0 and owned:
		loan_price -= mortgage
		var loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
		if loans_ui and is_instance_valid(loans_ui):
			for mod in loans_ui.active_loan_mods:
				if mod.loan_type_str == "Mortgage" and mod.house_ref == self:
					mod.loan_balance = loan_price
					mod.update_ui()
					
					break
		if loan_price <= 0:
			loan_price = 0
			mortgage = 0
			has_loan = false
