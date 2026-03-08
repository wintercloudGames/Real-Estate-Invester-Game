extends Control

@onready var wallpaper: TextureRect = $"../Wallpaper"

func _ready() -> void:
	var backgrounds = $ScrollContainer/backgrounds.get_children()
	for bg in backgrounds:
		if bg is TextureButton:
			bg.pressed.connect(_on_background_pressed.bind(bg))

func load_wallpaper_texture():
	# Convert wallpaper to string to ensure it's always treated as text
	var wallpaper_path = str(Globals.wallpaper)
	
	if wallpaper_path != "" and wallpaper_path != "0":  # Check for empty string and "0"
		var texture = load(wallpaper_path)
		if texture:
			wallpaper.texture = texture
		else:

			# Fallback to default wallpaper
			wallpaper.texture = load("res://assets/UI/phone/wallpapers/pexels-davidmcelwee-10583422.jpg")
	else:
		# If no wallpaper is set or it's 0, use default
		wallpaper.texture = load("res://assets/UI/phone/wallpapers/pexels-davidmcelwee-10583422.jpg")

func _on_background_pressed(button: TextureButton) -> void:
	wallpaper.texture = button.texture_normal
	var texture_path = str(button.texture_normal.resource_path)  # Get the path as a string
	Globals.wallpaper = texture_path  # Save the file path to Globals.wallpaper
	visible = false
