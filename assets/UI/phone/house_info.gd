extends Control

# Cache the labels so Godot doesn't have to "search" for them every frame
@onready var net_worth_label = $VBoxContainer/Net_worth
@onready var properties_label = $VBoxContainer/properties
@onready var total_loan_label = $VBoxContainer/total_loan_amount
@onready var renter_amount_label = $VBoxContainer/renter_amount
@onready var listed_houses_label = $VBoxContainer/listed_houses

func _ready() -> void:
	# 1. Update once when the menu opens
	update_ui()
	
	# 2. Connect to a global signal so it updates automatically when things change
	# Note: You'll need to add 'signal stats_changed' to your Globals.gd
	if not Globals.is_connected("stats_changed", _on_stats_changed):
		Globals.connect("stats_changed", _on_stats_changed)

# --- REMOVED _PROCESS ENTIRELY ---

func _on_stats_changed():
	# Only update when the game tells us something actually happened
	update_ui()

func update_ui():
	# Using the cached @onready variables is much faster than using $VBoxContainer/...
	net_worth_label.text = "Total Property Value: $" + Globals.add_comma_to_int(Globals.total_property_value)
	properties_label.text = "Properties Owned: " + Globals.add_comma_to_int(Globals.Propertys)
	total_loan_label.text = "Total Loan Amount: $" + Globals.add_comma_to_int(Globals.total_loan_amount)
	
	# Fixed the inconsistency: check if Globals.add_comma_to_int or just add_comma_to_int is the right one
	renter_amount_label.text = "Number Of Renters: " + Globals.add_comma_to_int(Globals.houses_with_tenants)
	listed_houses_label.text = "Houses Listed to Rent: " + Globals.add_comma_to_int(Globals.listed_houses)
