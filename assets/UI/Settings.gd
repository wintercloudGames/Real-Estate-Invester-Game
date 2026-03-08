extends Node

# Audio settings
var Master: float = 0.8
var Music: float = 0.7
var SFX: float = 0.9

# Graphics settings
var showfps: bool = true
var dynamic_resolution: bool = true
var graphics_quality: String = "Ultra"
var lightning: bool = false
var weather: bool = false
var max_render_scale: float = 1.25
var min_render_scale: float = 0.5
var target_fps: int = 60
var resolution: Vector2i = Vector2i(1920, 1080)
var UI_scale: float = 1.0
var shadows_quality: int = 3
var msaa: int = Viewport.MSAA_8X
var vsync: int = DisplayServer.VSYNC_ENABLED
var ssao: bool = true
var glow: bool = true
var dof: bool = true
var ssr: bool = true
var debanding: bool = true
var texture_filter: int = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
var particles_quality: int = 3

func _ready():
	load_settings()

func save_settings():
	var settings_data = {
		"audio": {
			"Master": Master,
			"Music": Music,
			"SFX": SFX
		},
		"graphics": {
			"show_fps": showfps,
			"dynamic_resolution": dynamic_resolution,
			"graphics_quality": graphics_quality,
			"lightning": lightning,
			"weather": weather,
			"max_render_scale": max_render_scale,
			"min_render_scale": min_render_scale,
			"target_fps": target_fps,
			"resolution": {"width": resolution.x, "height": resolution.y},
			"UI_scale": UI_scale,
			"shadows_quality": shadows_quality,
			"msaa": msaa,
			"vsync": vsync,
			"ssao": ssao,
			"glow": glow,
			"dof": dof,
			"ssr": ssr,
			"debanding": debanding,
			"texture_filter": texture_filter,
			"particles_quality": particles_quality
		}
	}
	
	var save_dir = OS.get_executable_path().get_base_dir().path_join("saves")
	var file_path = save_dir.path_join("settings.json")
	
	# Ensure saves directory exists
	var dir = DirAccess.open(OS.get_executable_path().get_base_dir())
	if dir and not dir.dir_exists("saves"):
		var err = dir.make_dir("saves")
		if err != OK:
			push_error("Failed to create saves directory at %s: %s" % [save_dir, err])
			# Fallback to user://
			file_path = "user://settings.json"
			dir = DirAccess.open("user://")
			if dir and not dir.dir_exists("user://settings"):
				err = dir.make_dir("settings")
				if err != OK:
					push_error("Failed to create user://settings directory: %s" % err)
					return
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data, "\t"))
		file.close()
		print("Settings saved to: ", file_path)
	else:
		push_error("Failed to save settings to: ", file_path)
		# Fallback to user:// if executable path fails
		if file_path != "user://settings.json":
			file_path = "user://settings.json"
			file = FileAccess.open(file_path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(settings_data, "\t"))
				file.close()
				print("Settings saved to fallback: ", file_path)
			else:
				push_error("Failed to save settings to fallback: ", file_path)

func load_settings():
	var file_path = OS.get_executable_path().get_base_dir().path_join("saves/settings.json")
	var fallback_path = "user://settings.json"
	
	# Try loading from executable path
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var data = json.get_data()
				if data is Dictionary:
					# Load audio settings
					if data.has("audio"):
						var audio = data["audio"]
						Master = audio.get("Master", 0.8)
						Music = audio.get("Music", 0.7)
						SFX = audio.get("SFX", 0.9)
					
					# Load graphics settings
					if data.has("graphics"):
						var graphics = data["graphics"]
						showfps = graphics.get("show_fps", true)
						dynamic_resolution = graphics.get("dynamic_resolution", true)
						graphics_quality = graphics.get("graphics_quality", "Ultra")
						lightning = graphics.get("lightning", false)
						weather = graphics.get("weather", false)
						max_render_scale = graphics.get("max_render_scale", 1.25)
						min_render_scale = graphics.get("min_render_scale", 0.5)
						target_fps = graphics.get("target_fps", 60)
						UI_scale = graphics.get("UI_scale", 1.0)
						shadows_quality = graphics.get("shadows_quality", 3)
						msaa = graphics.get("msaa", Viewport.MSAA_8X)
						vsync = graphics.get("vsync", DisplayServer.VSYNC_ENABLED)
						ssao = graphics.get("ssao", true)
						glow = graphics.get("glow", true)
						dof = graphics.get("dof", true)
						ssr = graphics.get("ssr", true)
						debanding = graphics.get("debanding", true)
						texture_filter = graphics.get("texture_filter", CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
						particles_quality = graphics.get("particles_quality", 3)
						if graphics.has("resolution") and typeof(graphics["resolution"]) == TYPE_DICTIONARY:
							var res = graphics["resolution"]
							resolution = Vector2i(res.get("width", 1920), res.get("height", 1080))
					print("Settings loaded from: %s, resolution=%s, Master=%s, showfps=%s" % [file_path, resolution, Master, showfps])
					apply_audio_settings()
					apply_graphics_settings()
					return
				else:
					push_error("Invalid JSON data in: ", file_path)
			else:
				push_error("Failed to parse JSON: ", json.get_error_message())
		else:
			push_error("Failed to open settings file: ", file_path)
	
	# Fallback to user://
	if FileAccess.file_exists(fallback_path):
		var file = FileAccess.open(fallback_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var data = json.get_data()
				if data is Dictionary:
					if data.has("audio"):
						var audio = data["audio"]
						Master = audio.get("Master", 0.8)
						Music = audio.get("Music", 0.7)
						SFX = audio.get("SFX", 0.9)
					if data.has("graphics"):
						var graphics = data["graphics"]
						showfps = graphics.get("show_fps", true)
						dynamic_resolution = graphics.get("dynamic_resolution", true)
						graphics_quality = graphics.get("graphics_quality", "Ultra")
						lightning = graphics.get("lightning", false)
						weather = graphics.get("weather", false)
						max_render_scale = graphics.get("max_render_scale", 1.25)
						min_render_scale = graphics.get("min_render_scale", 0.5)
						target_fps = graphics.get("target_fps", 60)
						UI_scale = graphics.get("UI_scale", 1.0)
						shadows_quality = graphics.get("shadows_quality", 3)
						msaa = graphics.get("msaa", Viewport.MSAA_8X)
						vsync = graphics.get("vsync", DisplayServer.VSYNC_ENABLED)
						ssao = graphics.get("ssao", true)
						glow = graphics.get("glow", true)
						dof = graphics.get("dof", true)
						ssr = graphics.get("ssr", true)
						debanding = graphics.get("debanding", true)
						texture_filter = graphics.get("texture_filter", CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
						particles_quality = graphics.get("particles_quality", 3)
						if graphics.has("resolution") and typeof(graphics["resolution"]) == TYPE_DICTIONARY:
							var res = graphics["resolution"]
							resolution = Vector2i(res.get("width", 1920), res.get("height", 1080))
					print("Settings loaded from fallback: %s, resolution=%s, Master=%s, showfps=%s" % [fallback_path, resolution, Master, showfps])
				else:
					push_error("Invalid JSON data in: ", fallback_path)
			else:
				push_error("Failed to parse JSON: ", json.get_error_message())
		else:
			push_error("Failed to open settings file: ", fallback_path)
	else:
		print("No settings file found at: %s or %s" % [file_path, fallback_path])
	
	# Apply defaults if no file found
	apply_audio_settings()
	apply_graphics_settings()
	save_settings()

func apply_audio_settings():
	if AudioServer.get_bus_index("Master") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(Master))
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), Master < 0.05)
	
	if AudioServer.get_bus_index("Music") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(Music))
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), Music < 0.05)
	
	if AudioServer.get_bus_index("SFX") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(SFX))
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), SFX < 0.05)

func apply_graphics_settings():
	ProjectSettings.set_setting("rendering/shadows/quality", shadows_quality)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", msaa)
	DisplayServer.window_set_vsync_mode(vsync)
	ProjectSettings.set_setting("rendering/global_illumination/ssao/enabled", ssao)
	ProjectSettings.set_setting("rendering/environment/glow_enabled", glow)
	ProjectSettings.set_setting("rendering/camera/depth_of_field/enabled", dof)
	ProjectSettings.set_setting("rendering/reflections/screen_space_reflections/enabled", ssr)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_debanding", debanding)
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", texture_filter)
	ProjectSettings.set_setting("rendering/particles/quality", particles_quality)
	DisplayServer.window_set_size(resolution)

func reset_to_defaults() -> void:
	Master = 0.8
	Music = 0.7
	SFX = 0.9
	showfps = true
	dynamic_resolution = true
	graphics_quality = "Ultra"
	lightning = false
	weather = false
	max_render_scale = 1.25
	min_render_scale = 0.5
	target_fps = 60
	resolution = Vector2i(1920, 1080)
	UI_scale = 1.0
	shadows_quality = 3
	msaa = Viewport.MSAA_8X
	vsync = DisplayServer.VSYNC_ENABLED
	ssao = true
	glow = true
	dof = true
	ssr = true
	debanding = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	particles_quality = 3
	apply_audio_settings()
	apply_graphics_settings()
	save_settings()
