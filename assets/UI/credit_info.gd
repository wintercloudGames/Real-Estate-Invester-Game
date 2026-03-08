extends Control

func _process(delta: float) -> void:
	get_qualified_house_amount()
	update_credit_display()

func get_qualified_house_amount():
	var down_payment = Globals.money  # Player's current money
	var down_payment_percent = 0.2
	var can_use_loan = true
	
	# Determine down payment percentage and loan eligibility based on credit score
	if Globals.credit_score >= 750:
		down_payment_percent = 0.15  # 15% for excellent credit
	elif Globals.credit_score >= 680:
		down_payment_percent = 0.2   # 20% for good credit
	elif Globals.credit_score >= 620:
		down_payment_percent = 0.25  # 25% for fair credit
	else:
		down_payment_percent = 0.3   # 30% for poor credit
		if Globals.credit_score < 500:
			can_use_loan = false     # No loans for very poor credit
	
	# Calculate max affordable house price
	var max_house_price = 0
	if can_use_loan:
		max_house_price = down_payment / down_payment_percent  # With loan
	else:
		max_house_price = down_payment  # Cash only for low credit
	
	# Update house qualify label
	var house_qualify_label = $VBoxContainer/house_qualify
	var stats_label = $VBoxContainer/stats  # New stats label for feedback
	if house_qualify_label and stats_label:
		if Globals.money >= 1000:
			house_qualify_label.text = "Qualified House Amount: $" + add_comma_to_int(max_house_price)
			if not can_use_loan:
				stats_label.text = "Low credit score! Can only buy with cash."
			else:
				stats_label.text = "Credit eligible for loans."
		else:
			house_qualify_label.text = "Qualified House Amount: $0"
			if Globals.credit_score < 500:
				stats_label.text = "Low credit score and insufficient funds!"
			else:
				stats_label.text = "Insufficient funds for purchase."
	
	# Loop through all houses in the game
	for house in get_tree().get_nodes_in_group("houses"):
		if house.current_price <= max_house_price and not house.owned:
			house.create_label(true)  # Mark as affordable
		else:
			house.create_label(false)  # Not affordable

func update_credit_display():
	var credit_label = $VBoxContainer/credit_score  # Label for credit score
	if credit_label:
		var credit_status = ""
		if Globals.credit_score >= 750:
			credit_status = "Excellent"
		elif Globals.credit_score >= 680:
			credit_status = "Good"
		elif Globals.credit_score >= 620:
			credit_status = "Fair"
		else:
			credit_status = "Poor"
		credit_label.text = "Credit Score: %d (%s)" % [Globals.credit_score, credit_status]

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
