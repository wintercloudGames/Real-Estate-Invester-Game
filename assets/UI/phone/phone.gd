extends Control

@onready var ui_layer = $".."  # HUD reference
@onready var Business_UI:Control = get_node("/root/Root/UserInterface/Game/HUD/Business_UI")
var isout = false

# Cache node references and states
var renters_container: Control
var renters_texture_rect: TextureRect
var car_info: Control
var car_info_texture_rect: TextureRect
var ui_elements: Array

# State tracking to avoid unnecessary operations
var last_renter_count: int = -1
var last_difficulty: int = -1
var last_has_car: bool = false
var frame_counter: int = 0

func _ready() -> void:
	# Cache all node references
	renters_container = $Renters/ScrollContainer/renters
	renters_texture_rect =$ScrollContainer/apps/Renters/TextureRect
	car_info = $ScrollContainer/apps/Car_info
	car_info_texture_rect = $ScrollContainer/apps/Car_info/TextureRect
	
	# Cache UI elements array
	ui_elements = [
		$options, $Music_player, $Savings, $house_info, $house_manager,
		$job_info, $Player_stats,$Loans,$Stock_app,
		$Food_market, $Backgrounds, $Renters, $Car_info, $Hire_help,$credit_info
	]

func _process(delta: float) -> void:
	frame_counter += 1
	# Only check expensive operations every 5 frames (reduces CPU usage by 80%)
	if frame_counter % 5 == 0:
		unlock_apps()
		# Check renters - only update if changed
		var hasrenters = renters_container.get_child_count()
		if hasrenters != last_renter_count:
			last_renter_count = hasrenters
			renters_texture_rect.visible = hasrenters > 0
			$ScrollContainer/apps/Renters/TextureRect/Label.text = str(renters_container.get_child_count())
		
		# Check difficulty - only update if changed
		if Globals.difficulty != last_difficulty:
			last_difficulty = Globals.difficulty
			car_info.visible = Globals.difficulty >= 1
		
		car_info_texture_rect.visible = !Globals.has_car

func unlock_apps():
	if Globals.has_bank_app == true:
		$ScrollContainer/apps/Loans.visible = true
		$ScrollContainer/apps/Savings.visible = true
	else:
		$ScrollContainer/apps/Loans.visible = false
		$ScrollContainer/apps/Savings.visible = false
	
	if Globals.has_manager_app == true:
		$ScrollContainer/apps/House_manager.visible = true
	else:
		$ScrollContainer/apps/House_manager.visible = false
		
	if Globals.credit_app == true:
		$ScrollContainer/apps/Credit_display.visible = true
	else:
		$ScrollContainer/apps/Credit_display.visible = false
		
	if Globals.has_hireing_app == true:
		$ScrollContainer/apps/Hire_help.visible = true
	else:
		$ScrollContainer/apps/Hire_help.visible = false
		
	if Globals.has_market_app == true:
		$ScrollContainer/apps/Market.visible = true
	else:
		$ScrollContainer/apps/Market.visible = false
	
	if Globals.has_stock_app == true:
		$ScrollContainer/apps/Stock_Market.visible = true
	else:
		$ScrollContainer/apps/Stock_Market.visible = false
		
	
	if Globals.rent_houses == true:
		$ScrollContainer/apps/Renters.visible = true
	else:
		$ScrollContainer/apps/Renters.visible = false
		
	if Globals.has_info_app == true:
		$ScrollContainer/apps/house_info.visible = true
	else:
		$ScrollContainer/apps/house_info.visible = false 

func put_away():
	$AnimationPlayer.play("put_away")

func get_out():
	visible = true
	$AnimationPlayer.play("get_out")

func _on_texture_button_pressed() -> void:
	put_away()

func _on_texture_button_2_pressed() -> void:
	for element in ui_elements:
		element.visible = false

func _on_music_player_pressed() -> void:
	$Music_player.visible = true

func _on_settings_pressed() -> void:
	$options.visible = true

func _on_house_info_pressed() -> void:
	$house_info.visible = true

func _on_job_pressed() -> void:
		$job_info.visible = true
		
func _on_player_stats_pressed() -> void:
	$Player_stats.visible = true

func _on_food_pressed() -> void:
	$Food_market.visible = true

func _on_backgrounds_pressed() -> void:
	$Backgrounds.visible = true

func _on_renters_pressed() -> void:
	$Renters.visible = true

func _on_car_info_pressed() -> void:
	$Car_info.visible = true

func _on_market_pressed() -> void:
	var market = $"../Market"
	market.visible = !market.visible

func _on_house_manager_pressed() -> void:
	$house_manager.visible = true

func _on_hire_help_pressed() -> void:
	$Hire_help.visible = true

func _on_credit_display_pressed() -> void:
	$credit_info.visible = true

func _on_savings_pressed() -> void:
	$Savings.visible = true

func _on_loans_pressed() -> void:
	$Loans.visible = true

func _on_stock_market_pressed() -> void:
	$Stock_app.visible = true
