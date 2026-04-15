extends MeshInstance3D

# If your lights are inside a specific child node, change this path
# Most streetlights have an OmniLight3D or SpotLight3D
@onready var light_source =  $SpotLight3D

func _ready():
	# Use the absolute path from your scene tree to find World_settings
	var world_settings = get_node_or_null("/root/Root/UserInterface/Game/World_settings")
	
	if world_settings:
		# Connect to the night mode signal
		world_settings.night_mode_changed.connect(_on_night_mode_changed)
		
		# Set initial state (in case the game starts at night)
		_on_night_mode_changed(world_settings._is_currently_night)
	else:
		push_warning("Streetlight at %s could not find World_settings!" % str(global_position))

func _on_night_mode_changed(is_night: bool):
	if light_source:
		light_source.visible = is_night
	
