extends Control

func _process(_delta: float) -> void:
	update_ui()


func update_ui():

	$VBoxContainer/Net_worth.text = "Total Property Value: $" + add_comma_to_int(Globals.total_property_value)
	
	$VBoxContainer/properties.text = "Properties Owned: " + add_comma_to_int(Globals.Propertys)
	$VBoxContainer/total_loan_amount.text = "Total Loan Amount: $" + add_comma_to_int(Globals.total_loan_amount)
	
	$VBoxContainer/renter_amount.text = "Number Of Renters: " + add_comma_to_int(Globals.houses_with_tenants)
	$VBoxContainer/listed_houses.text = "Houses Listed to Rent: " + add_comma_to_int(Globals.listed_houses)

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
