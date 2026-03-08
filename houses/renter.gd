extends TextureButton

var rent_offer_system = null

var rent_offer = 0

@onready var renters: Control = $"../../.."

var textures = [
	preload("res://3D assets/faces/avatar (1).png"),
	preload("res://3D assets/faces/avatar (2).png"),
	preload("res://3D assets/faces/avatar.png")
]

func _ready():
	set_random_texture()

func set_random_texture():
	texture_normal = textures[randi() % textures.size()]  # For TextureButtontexture = textures[randi() % textures.size()]  # Use this if it's a TextureRect

func _on_pressed() -> void:
	var parent_node = self.get_parent()
	
	# Loop through all siblings of the button and remove them
	for sibling in parent_node.get_children():
		if sibling != self:  # Avoid removing the button itself again
			sibling.queue_free()
	self.queue_free()
	
	if rent_offer_system:
		rent_offer_system._on_renter_selected(rent_offer)


func setup(offer: int, name: String, stats: Dictionary):
	# Set basic info
	$HBoxContainer/renter_info/Rent_Label.text = "$%s/mo" % add_comma_to_int(offer)
	$HBoxContainer/renter_info/Name_Label.text = name
	
	# Set payment punctuality
	$HBoxContainer/renter_stats/ontime_stat.text = "%.0f%% on time" % (stats.payment_punctuality * 100)
	
	# Set apartment condition if node exists
	if has_node("HBoxContainer/renter_stats/condition_stat"):
		$HBoxContainer/renter_stats/condition_stat.text = "%.0f%% condition" % (stats.apartment_condition * 100)
	
	# Set lease duration if node exists
	if has_node("HBoxContainer/renter_stats/lease_stat"):
		var duration_text = ""
		match stats.lease_length:
			6: duration_text = "6-month lease"
			12: duration_text = "1-year lease"
			24: duration_text = "2-year lease"
			_: duration_text = "%d month lease" % stats.lease_length
		$HBoxContainer/renter_stats/lease_stat.text = duration_text
	

# Helper function for formatting numbers with commas
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
