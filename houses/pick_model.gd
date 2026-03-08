extends TextureButton

@export var model_path: String = ""
@export var display_name: String = "Object"
@export var price: int = 0

@onready var money_label = $Label
@onready var sound_player = $AudioStreamPlayer
@onready var purchase_sound = preload("res://effects/sounds/ui-pop-sound-316482.mp3")
@onready var error_sound = preload("res://effects/sounds/ui-pop-sound-316482.mp3")

var yard_editor: Node = null
var house: Node = null

func _ready() -> void:
	# Find references using groups
	find_yard_editor()
	find_house()
	
	# Set button textures
	if texture_normal:
		texture_normal = texture_normal
	if texture_hover:
		texture_hover = texture_hover
	if texture_pressed:
		texture_pressed = texture_pressed
	if texture_disabled:
		texture_disabled = texture_disabled
	
	# Format price display
	update_price_display()
	

	
	# Add to purchase buttons group
	add_to_group("purchase_buttons")

func find_yard_editor():
	# Try to find yard editor in scene tree using group
	var editors = get_tree().get_nodes_in_group("yard_editor")
	if editors.size() > 0:
		yard_editor = editors[0]

	else:
		# Fallback: try the complex path
		yard_editor = get_node_or_null("../../../../..")


func find_house():
	# Try to find house using group
	var houses = get_tree().get_nodes_in_group("houses")
	if houses.size() > 0:
		house = houses[0]  # Or find the specific house if multiple
	else:
		# Fallback: try the complex path
		house = get_node_or_null("../../../../../..")


func update_price_display():
	if money_label:
		money_label.text = "%s: %s" % [display_name, format_currency(price)]
		if Globals.money < price:
			money_label.add_theme_color_override("font_color", Color.RED)
			disabled = true
		else:
			money_label.add_theme_color_override("font_color", Color.WHITE)
			disabled = false

func format_currency(value: int) -> String:
	var str_value = str(value)
	var length = str_value.length()
	
	# Handle negative numbers
	var is_negative = value < 0
	if is_negative:
		str_value = str_value.substr(1)
		length -= 1
	
	# Add commas every 3 digits
	for i in range(length - 3, 0, -3):
		str_value = str_value.insert(i, ",")
	
	return "$" + ("-" if is_negative else "") + str_value

func _on_button_pressed():

	if Globals.money >= price:
		# Play purchase sound
		if sound_player and purchase_sound:
			sound_player.stream = purchase_sound
			sound_player.play()
		
		# DEDUCT MONEY FIRST - This is the key fix!
		Globals.money -= price
		
		
		# Update house value if house reference exists
		if house and house.has_method("add_to_base_price"):
			house.add_to_base_price(price * 2)
			
		elif house and "base_price" in house:
			house.base_price += price * 2
		
		# Update all buttons' displays
		get_tree().call_group("purchase_buttons", "update_price_display")
		
		# PLACE THE OBJECT DIRECTLY - Don't rely on yard editor methods
		place_object_directly()
		
	else:
		# Play error sound
		if sound_player and error_sound:
			sound_player.stream = error_sound
			sound_player.play()
		
		# Visual feedback for insufficient funds
		shake_label()


func place_object_directly():
	if model_path.is_empty():
		return
	
	if not ResourceLoader.exists(model_path):
		return
	
	if not house:
		return
	
	# Load and place the object
	var object_scene = load(model_path)
	var new_object = object_scene.instantiate()
	
	# Add object as child of the HOUSE (this makes it move with the house)
	house.add_child(new_object)
	
	# Position object near the house (adjust as needed)
	new_object.global_position = house.global_position + Vector3(2, 0, 2)
	
	
	# If yard editor exists, notify it about the placement
	if yard_editor and yard_editor.has_method("on_object_placed"):
		yard_editor.on_object_placed(new_object, display_name, price)

func shake_label():
	if money_label:
		var tween = create_tween()
		tween.tween_property(money_label, "position:x", money_label.position.x + 5, 0.05)
		tween.tween_property(money_label, "position:x", money_label.position.x - 5, 0.05)
		tween.tween_property(money_label, "position:x", money_label.position.x, 0.05)

func _on_mouse_entered():
	# Highlight effect
	scale = Vector2(1.05, 1.05)
	if money_label:
		money_label.add_theme_font_size_override("font_size", 20)

func _on_mouse_exited():
	# Reset highlight
	scale = Vector2(1.0, 1.0)
	if money_label:
		money_label.add_theme_font_size_override("font_size", 16)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# Clean up connections
		if pressed.is_connected(_on_button_pressed):
			pressed.disconnect(_on_button_pressed)
		if mouse_entered.is_connected(_on_mouse_entered):
			mouse_entered.disconnect(_on_mouse_entered)
		if mouse_exited.is_connected(_on_mouse_exited):
			mouse_exited.disconnect(_on_mouse_exited)
		
		# Remove from group
		if is_in_group("purchase_buttons"):
			remove_from_group("purchase_buttons")
