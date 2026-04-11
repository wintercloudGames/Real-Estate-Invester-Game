extends TextureButton

@export var phone_node: Control 
@export var renters_container: Control # This MUST be the node that holds the children!
func _ready() -> void:
	# Ensure the button reacts instantly
	action_mode = ACTION_MODE_BUTTON_PRESS
	
	# If not assigned in Inspector, try to find them
	if not phone_node:
		phone_node = get_node_or_null("../../Phone")
	
	# Connect signal
	if not pressed.is_connected(_on_self_pressed):
		pressed.connect(_on_self_pressed)

func _on_self_pressed() -> void:
	if not phone_node: return

	# We defined it as 'renters_ui' here (with an 's')
	var renters_ui = phone_node.get_node_or_null("Renters")
	var has_offers = renters_container.get_child_count() > 0 if renters_container else false
	
	# CASE 1: Phone is closed -> Open it
	if not phone_node.isout:
		_open_phone()
	
	# CASE 2: Phone is ALREADY open
	else:
		# If there are offers AND the renters menu isn't showing yet -> Switch to Renters
		if has_offers and renters_ui and not renters_ui.visible:
			if phone_node.has_method("_on_texture_button_2_pressed"):
				phone_node._on_texture_button_2_pressed()
			
			# FIXED: Changed 'renter_ui' to 'renters_ui' to match line 5
			renters_ui.visible = true
		
		# If the phone is open and we are ALREADY looking at renters (or no offers) -> Close it
		else:
			_close_phone()

func _open_phone() -> void:
	phone_node.get_out()
	phone_node.isout = true
	
	# Check for offers
	# Use a safer check: count children of the list inside the scroll container
	var offer_count = 0
	if renters_container:
		offer_count = renters_container.get_child_count()
	
	
	if offer_count > 0:
		# Force the Phone to switch to the Renters tab
		if phone_node.has_method("_on_texture_button_2_pressed"):
			phone_node._on_texture_button_2_pressed()
			
		# Make sure the Renters UI element is actually visible
		var renters_ui = phone_node.get_node_or_null("Renters")
		if renters_ui:
			renters_ui.visible = true

func _close_phone() -> void:
	phone_node.put_away()
	phone_node.isout = false
