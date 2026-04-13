extends Control

@onready var cashflow_label = $GridContainer/cashflow
@onready var money_label = $GridContainer/money
@onready var properties_label = $properties
@onready var expenses_label = $GridContainer/Expenses
@onready var income_label = $GridContainer/Income
@onready var networth_label = $networth
@onready var month_timer_label = $"../Month_mod/Month_Timer"
@onready var month_label = $"../Month_mod/month"
@onready var year_label = $"../Month_mod/Year"
@onready var fps_counter = $FPS_counter
@onready var market_conditions: Label = $Market_conditions
@onready var negative_month_count: Label = $negative_month_count
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var level_label: Label = $ProgressBar/Level_label


var month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var update_timer: float = 0.0
var update_interval: float = 0.1  # Update UI every 0.1 seconds (10 FPS)

func _ready():
	# Log Settings.showfps and FPS_counter state
	
	if not fps_counter or not is_instance_valid(fps_counter):
		push_error("FPS_counter node is missing or invalid at path $FPS_counter")
	elif not fps_counter is Label:
		push_error("FPS_counter is not a Label, type is: ", fps_counter.get_class())
	else:
		
		fps_counter.visible = Settings.showfps  # Set initial visibility
		fps_counter.modulate = Color.WHITE
		fps_counter.add_theme_color_override("font_color", Color.WHITE)
	
	await get_tree().create_timer(1.0).timeout
	update_ui()

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value

func _process(delta: float) -> void:
	update_timer += delta
	if Globals.skillpoints > 0:
		$Skills_Button/TextureRect.visible = true
		$Skills_Button/Label.text = str(Globals.skillpoints)
	else:
		$Skills_Button/TextureRect.visible = false
		$Skills_Button/Label.text = ""
	
	if Globals.unlock_business:
		$Business_Button.visible = true
	else:
		$Business_Button.visible = false
	
	if update_timer >= update_interval:
		update_timer = 0.0
		update_ui()

func update_ui():
	progress_bar.value = Globals.exp
	progress_bar.max_value = Globals.exp_to_level
	if level_label != null:
		level_label.text = "Level: " + str(Globals.level)
	cashflow_label.add_theme_color_override("font_color", Color.RED if Globals.cashflow < 0 else Color("1dff00"))
	cashflow_label.text = "CashFlow: " + add_comma_to_int(Globals.cashflow)
	
	money_label.text = "Money: " + add_comma_to_int(Globals.money)
	money_label.add_theme_color_override("font_color", Color.RED if Globals.money < 0 else Color.YELLOW)
	
	properties_label.text = "Property's: " + add_comma_to_int(Globals.Propertys)
	expenses_label.text = "Expenses: " + add_comma_to_int(Globals.Expenses)
	income_label.text = "Income: " + add_comma_to_int(Globals.Income)
	networth_label.text = "networth: " + add_comma_to_int(Globals.net_worth)
	
	month_timer_label.text = "Month Timer: " + str(int($Timer.time_left))
	negative_month_count.text = "Months tell Bankrupt: " + str(Globals.negative_month_count) + "/12"
	if Globals.month >= 1 and Globals.month <= 12:
		var month_short = month_names[Globals.month - 1]
		month_label.text = "("+str(Globals.month) + ") Month: " + month_short
	else:
		month_label.text = "Month: ???"
	year_label.text = "Year: " + add_comma_to_int(Globals.year)
	
	var percent = round(Globals.market_factor * 100)
	var label = $Market_conditions/Label
	label.text = str(percent) + "%"
	
	if Globals.has_market_app:
		market_conditions.visible = true
	else:
		market_conditions.visible = false
	
	if Settings.showfps and fps_counter:
		var fps_text = "FPS: %d" % Engine.get_frames_per_second()
		fps_counter.text = fps_text
		fps_counter.visible = true
		fps_counter.modulate = Color.WHITE
		fps_counter.add_theme_color_override("font_color", Color.WHITE)
		
	else:
		if fps_counter:
			fps_counter.text = ""
			fps_counter.visible = false
			
	
func _on_timer_timeout() -> void:
	# Save the game and process monthly income/expenses
	$"../Quit_menu".save_game()
	Globals.monthy()
	
	# Determine the message and color based on cashflow
	var message: String = ""
	var msg_color: Color = Color.WHITE
	
	if Globals.cashflow < 0:
		message = "Monthly Expenses Paid: " + add_comma_to_int(Globals.cashflow) + "$"
		msg_color = Color.LIGHT_CORAL # Reddish for expenses
	else:
		message = "Monthly Cashflow: +" + add_comma_to_int(Globals.cashflow) + "$"
		msg_color = Color.SPRING_GREEN # Green for profit
	
	# Use your new sidebar system instead of the floating label
	Globals.notify(message, msg_color)
	
	# Restart the cycle
	$Timer.start()

func _on_show_log_pressed() -> void:
	$"../Universal_Text_Box".visible = !$"../Universal_Text_Box".visible
