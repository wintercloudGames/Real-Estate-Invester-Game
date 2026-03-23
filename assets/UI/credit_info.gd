extends Control

func _ready() -> void:
	Globals.month_ended.connect(update_credit_display)

func _process(delta: float) -> void:
	get_qualified_house_amount()


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
	var credit_label = $VBoxContainer/credit_score
	var repair_btn = $Credit_Repair_Button # Assumes button is a child
	
	if credit_label:
		var credit_status = ""
		var status_color = Color.WHITE
		
		if Globals.credit_score >= 750:
			credit_status = "Excellent"; status_color = Color.GREEN
		elif Globals.credit_score >= 680:
			credit_status = "Good"; status_color = Color.CHARTREUSE
		elif Globals.credit_score >= 620:
			credit_status = "Fair"; status_color = Color.GOLD
		else:
			credit_status = "Poor"; status_color = Color.ORANGE_RED
			
		credit_label.text = "Credit Score: %d (%s)" % [Globals.credit_score, credit_status]
		credit_label.modulate = status_color
		
	# Update Repair Button State
	if repair_btn:
		repair_btn.disabled = (Globals.money < 5000 or Globals.credit_score >= 800)
	
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _on_credit_repair_button_pressed() -> void:
	var repair_cost = 5000 # Scaling cost makes it a mid-game goal
	# Check if player has the cash and isn't already at max credit
	if Globals.money >= repair_cost and Globals.credit_score < 850:
		Globals.money -= repair_cost
		
		# Add a random boost between 10 and 25 points
		var boost = randi_range(10, 25)
		Globals.credit_score = clamp(Globals.credit_score + boost, 300, 850)
		
		show_floating_label("Credit Repaired! +%d Points" % boost, Color.CYAN)
		
		# Optional: Disable the button for the rest of the month
		$Credit_Repair_Button.disabled = true
	elif Globals.credit_score >= 850:
		show_floating_label("Credit is already perfect!", Color.WHITE)
	else:
		show_floating_label("Not enough money! Need $5,000", Color.RED)

func show_floating_label(text: String, color: Color = Color.WHITE):
	# We find the HUD dynamically so any script can call this
	var ui_layer = get_tree().get_root().find_child("HUD", true, false)
	if ui_layer:
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		# Center it on screen or follow mouse
		label.position = ui_layer.get_viewport().get_mouse_position() 
		ui_layer.add_child(label)
		
		var tween = ui_layer.get_tree().create_tween()
		tween.tween_property(label, "position:y", label.position.y - 80, 2.0)
		tween.parallel().tween_property(label, "modulate:a", 0, 2.0)
		tween.tween_callback(label.queue_free)
