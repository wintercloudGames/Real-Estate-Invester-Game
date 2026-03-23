extends Control

@onready var time_on_market = $Time_on_market
@onready var price_display = $Label_price
@onready var loan_display = $Label_loan
@onready var game = $"../.."

var full_price: int = 0  # Tracks the house's full listing/current price
var list_price: int = 0 
var loan_amount: int = 0  # Amount financed if using a loan
var house = null
var loan_status: bool = false  # Whether the loan toggle is active
var down_payment: int = 0 
var bought_price: int = 0
var has_tenant: bool = false
var can_use_loan: bool = true
var down_payment_percent: float = 0.2
var pay_now_amount: int = 0  # Amount player pays now (down payment or full price)

func _ready() -> void:
	update_prices()

func update_prices() -> void:
	if not house:
		full_price = 0
		list_price = 0
		down_payment = 0
		loan_amount = 0
		pay_now_amount = 0
		$Loan_button.tooltip_text = "No house selected"
		return
	
	list_price = house.current_price
	full_price = house.current_price
	can_use_loan = true
	
	# Adjust down payment based on credit score
	if Globals.credit_score >= 750:
		down_payment_percent = 0.15
	elif Globals.credit_score >= 680:
		down_payment_percent = 0.2
	elif Globals.credit_score >= 620:
		down_payment_percent = 0.25
	else:
		down_payment_percent = 0.3
		if Globals.credit_score < 500:
			can_use_loan = false
	
	if can_use_loan and loan_status:
		down_payment = int(full_price * down_payment_percent)
		loan_amount = int(full_price * (1.0 - down_payment_percent))
		pay_now_amount = down_payment
	else:
		down_payment = full_price
		loan_amount = 0
		pay_now_amount = full_price
	
	# Set tooltip to explain loan availability
	$Loan_button.tooltip_text = "Credit score too low for a loan (below 500)" if not can_use_loan else "Toggle to finance with a loan"

func _process(_delta: float) -> void:
	if Globals.rent_houses:
		$Buy_button2.visible = true
	else:
		$Buy_button2.visible = false
	
	if visible and visible != get_meta("previous_visible", false):
		var popup_sound = get_node_or_null("../popupsound")
		if popup_sound:
			popup_sound.play()
	set_meta("previous_visible", visible)
	
	if house:
		price_display.text = "Price: $" + add_comma_to_int(pay_now_amount)
		time_on_market.text = "Months on market: " + add_comma_to_int(house.time_on_market)
		$Label_list_price.text = "Listing: $" + add_comma_to_int(house.current_price)
		if can_use_loan and loan_status:
			loan_display.text = "Loan\n%d%% Financed\nDown Payment: $%s" % [
				(1.0 - down_payment_percent) * 100, add_comma_to_int(down_payment)
			]
		else:
			loan_display.text = "No Loan\nFull Payment: $%s" % add_comma_to_int(pay_now_amount)
	else:
		price_display.text = "Price: $0"
		$Label_list_price.text = "Listing: $0"
		loan_display.text = "No Loan\nDown Payment: $0"

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_loan_button_toggled(toggled_on: bool) -> void:
	if toggled_on and not can_use_loan:
		show_floating_label("Cannot use loan: Credit score below 500!", Color.RED)
		$Loan_button.button_pressed = false  # Reset toggle state
		loan_status = false  # Ensure loan_status is off
	else:
		loan_status = toggled_on
	update_prices()

func _on_close_button_pressed() -> void:
	visible = false
	game.clear_House_ui_data()
	$Loan_button.button_pressed = false

func show_floating_label(text: String, color: Color = Color.WHITE):
	var canvas_layer = get_node_or_null("/root/Root/UserInterface/Game/HUD")
	if canvas_layer:
		var label = Label.new()
		label.text = text
		label.modulate = color
		label.position = Vector2(700, 500)
		canvas_layer.add_child(label)
		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5)
		tween.parallel().tween_property(label, "modulate:a", 0, 1.5)
		tween.tween_callback(label.queue_free)

func handle_buy(list_for_rent: bool = false) -> void:
	if not is_instance_valid(house):
		show_floating_label("Invalid house!", Color.RED)
		return
	
	if house.owned:
		show_floating_label("House already owned!", Color.RED)
		return
	
	var loan_mod = null
	if loan_status and can_use_loan:
		# --- LOAN PURCHASE ---
		var calculated_loan_amount = full_price - pay_now_amount
		if Globals.money >= pay_now_amount:
			var interest_rate = 0.06
			if Globals.credit_score >= 750:
				interest_rate = 0.04
			elif Globals.credit_score >= 680:
				interest_rate = 0.045
			elif Globals.credit_score >= 620:
				interest_rate = 0.055
				
			var term_months = 12 * 30
			var monthly_payment = calculate_mortgage_payment(calculated_loan_amount, term_months, interest_rate)
			
			if monthly_payment <= 0:
				show_floating_label("Invalid loan terms!", Color.RED)
				return
			
			# Deduct down payment
			Globals.money_out(pay_now_amount)
			
			# Ownership Logic
			house.owned = true
			house.owner_type = "player" # Explicitly mark as Player
			if house.is_in_group("ai_owned"):
				house.remove_from_group("ai_owned")
			
			house.bought_price = full_price
			house.loan_price = float(calculated_loan_amount)
			house.mortgage = int(monthly_payment)
			house.has_loan = true
			house.just_bought = true
			
			# Add loan to Loans UI
			var loans_ui = get_tree().get_first_node_in_group("loans_ui")
			if not loans_ui:
				loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
			
			if loans_ui and is_instance_valid(loans_ui):
				if loans_ui.loan_mod_Container:
					var loan_mod_path = "res://assets/UI/phone/Loans_controll_mod.tscn"
					if ResourceLoader.exists(loan_mod_path):
						loan_mod = loans_ui.add_mortgage_as_loan(monthly_payment, interest_rate, term_months, house)
						if loan_mod and is_instance_valid(loan_mod):
							loan_mod.loan_id = "mortgage_" + str(house.id)
							house.house_buy(true, full_price, calculated_loan_amount, loan_mod)
							Globals.recalculate_expenses()
						else:
							rollback_purchase()
							return
					else:
						rollback_purchase()
						return
				else:
					rollback_purchase()
					return
			else:
				rollback_purchase()
				return
			
			Globals.Propertys += 1
			Globals.net_worth += full_price
			show_floating_label("Bought with loan! Down: $" + add_comma_to_int(pay_now_amount), Color.GREEN)
		else:
			show_floating_label("Need $" + add_comma_to_int(pay_now_amount) + " for down payment!", Color.RED)
			return
	else:
		# --- CASH PURCHASE ---
		if Globals.money >= pay_now_amount:
			Globals.money -= pay_now_amount
			
			# Ownership Logic
			house.owned = true
			house.owner_type = "player" # Explicitly mark as Player
			if house.is_in_group("ai_owned"):
				house.remove_from_group("ai_owned")
				
			house.bought_price = full_price
			house.loan_price = 0
			house.mortgage = 0
			house.has_loan = false
			house.just_bought = true
			house.house_buy(false, full_price, 0, null)
			
			Globals.Propertys += 1
			Globals.net_worth += full_price
			show_floating_label("Bought with cash! $" + add_comma_to_int(pay_now_amount), Color.GREEN)
		else:
			show_floating_label("Need $" + add_comma_to_int(pay_now_amount) + " in cash!", Color.RED)
			return
	
	# Common post-buy logic
	if house.has_method("set_house_UI"):
		house.set_house_UI()
	if list_for_rent:
		house.is_listed = true
	$Loan_button.button_pressed = false
	visible = false
	SaveAndLoad.save_game()

# Helper function to handle rollbacks if loan creation fails
func rollback_purchase():
	Globals.money += pay_now_amount
	house.owned = false
	house.owner_type = "none"
	house.loan_price = 0
	house.mortgage = 0
	house.has_loan = false
	show_floating_label("Loan system error!", Color.RED)

func calculate_mortgage_payment(loan_amount: float, months: int, interest_rate: float) -> float:
	if months <= 0 or loan_amount <= 0 or interest_rate < 0:
		return 0.0
	var monthly_rate = interest_rate / 12.0
	var payment = loan_amount * (monthly_rate * pow(1 + monthly_rate, months)) / (pow(1 + monthly_rate, months) - 1)
	return payment

func _on_buy_button_pressed() -> void:
	handle_buy(false)

func _on_buy_button_2_pressed() -> void:
	handle_buy(true)
