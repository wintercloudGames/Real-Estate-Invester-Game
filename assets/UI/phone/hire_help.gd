extends Control


func _process(delta: float) -> void:
	if Globals.hascleaner == false:
		$Cleaner_Button.text = "Cleaner $500/mo"
	else:
		$Cleaner_Button.text = "Fire Cleaner"
	
	if Globals.hasagent == false:
		$Rent_collecter_Button.text = "Rent Collector $1000/mo"
	else:
		$Rent_collecter_Button.text = "Fire Rent Collector"
		
	if Globals.renter_finder == false:
		$Find_renter_Button.text = "Renter Finder $500/mo"
	else:
		$Find_renter_Button.text = "Fire Renter Finder"

func _on_cleaner_button_pressed() -> void:
	if Globals.hascleaner == true:
		Globals.hascleaner = false
	else:
		Globals.hascleaner = true

func _on_rent_collecter_button_pressed() -> void:
	if Globals.hasagent == true:
		Globals.hasagent = false
	else:
		Globals.hasagent = true


func _on_find_renter_button_pressed() -> void:
	if Globals.renter_finder == true:
		Globals.renter_finder = false
	else:
		Globals.renter_finder = true
