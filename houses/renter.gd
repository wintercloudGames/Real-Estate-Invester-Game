extends TextureButton

var rent_offer_system = null

var rent_offer = 0

@onready var renters: Control = $"../../.."

var textures = []

func _ready():
	load_textures_from_folder("res://3D assets/faces/")
	set_random_texture()
func load_textures_from_folder(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if !dir.current_is_dir():
				# We check for the base file OR the engine's export pointers
				if file_name.ends_with(".png") or file_name.ends_with(".png.import") or file_name.ends_with(".remap"):
					# Clean the name: remove .import or .remap to get the original asset path
					var clean_name = file_name.replace(".import", "").replace(".remap", "")
					var full_path = path + clean_name
					
					var tex = load(full_path)
					# Only add if it's actually a texture and not already in the list
					if tex is Texture2D and !textures.has(tex):
						textures.append(tex)
			
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Error: Could not open path: ", path)

func set_random_texture():
	if textures.size() > 0:
		texture_normal = textures[randi() % textures.size()]
	else:
		print("Warning: No textures found in the faces folder!")
	
func _on_pressed() -> void:
	var parent_node = self.get_parent()
	
	# Loop through all siblings of the button and remove them
	for sibling in parent_node.get_children():
		if sibling != self:  # Avoid removing the button itself again
			sibling.queue_free()
	self.queue_free()
	
	if rent_offer_system:
		rent_offer_system._on_renter_selected(rent_offer)

func setup(offer: int, _name: String, stats: Dictionary):
	# Set basic info
	$HBoxContainer/renter_info/Rent_Label.text = "$%s/mo" % add_comma_to_int(offer)
	$HBoxContainer/renter_info/Name_Label.text = _name
	
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
			60: duration_text = "5-year lease"
			_: duration_text = "%d month lease" % stats.lease_length
		$HBoxContainer/renter_stats/lease_stat.text = duration_text
	

# Helper function for formatting numbers with commas
func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	
	for i in range(str_value.length() - 3, loop_end, -3):
		str_value = str_value.insert(i, ",")
	return str_value
