extends Control


@onready var game = $"."
var house = null

func clear_children() -> void:
	# Get the renters container node
	var renters_container = $ScrollContainer/renters
	
	# Loop through all child nodes and queue them for deletion
	for child in renters_container.get_children():
		child.queue_free()

func list_house_for_rent():
	if house and house.owned and not house.has_tenant:
		house.is_listed = true
		house.tenant_offers = generate_rental_offers(house.base_price)


func generate_rental_offers(house_price: int) -> Array:
	var offers = []
	var min_rent = house_price * 0.005  # 0.5% of house value
	var max_rent = house_price * 0.01   # 1% of house value
	
	for i in range(randi_range(1, 5)):  # 1 to 5 offers
		var rent_offer = randi_range(int(min_rent), int(max_rent))
		offers.append(rent_offer)
	
	return offers

func _on_renter_selected( rent_offer):
	house.has_tenant = true
	house.rent = rent_offer
	house.is_listed = false  # House is no longer listed

	game.set_house_UI()

func add_renter_offer(house, renter_name: String, rent_offer: int):
	var renters_ui = $ScrollContainer/renters
	
	var renter_scene = preload("res://houses/renter.tscn")  # Load your renter UI scene
	var new_renter = renter_scene.instantiate()
	
	new_renter.get_node("renter_info/Name_Label").text = renter_name  # Set renter name
	new_renter.get_node("renter_info/Rent_Label").text = "$" + str(rent_offer)  # Set rent offer
	
	# Connect the button to accept the offer
	new_renter.get_node("Texture_Button").connect("pressed", Callable(self, "_on_renter_selected").bind(house, rent_offer))
	
	renters_ui.add_child(new_renter)  # Add to UI

func accept_rental_offer(selected_rent: int):
	if house and house.is_listed:
		house.rent = selected_rent
		house.has_tenant = true
		house.is_listed = false
		
