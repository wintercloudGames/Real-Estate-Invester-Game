extends Node

signal settings_changed

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
var max_render_scale: float = 1.0
var min_render_scale: float = 0.5
var target_fps: int = 60
var resolution: Vector2i = Vector2i(1280, 720)
var UI_scale: float = 1.0

# Gameplay settings
var day_night_cycle: bool = false

# Quality Levels
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

func get_save_path() -> String:
	var exe_dir = OS.get_executable_path().get_base_dir()
	return exe_dir.path_join("settings.json")

func save_settings():
	var settings_data = {
		"audio": { "Master": Master, "Music": Music, "SFX": SFX },
		"gameplay": { "day_night_cycle": day_night_cycle }, # Save cycle state here
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
	
	var file = FileAccess.open(get_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data, "\t"))
		file.close()

func load_settings():
	var path = get_save_path()
	if not FileAccess.file_exists(path):
		apply_audio_settings()
		apply_graphics_settings()
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		
		# Audio Mapping
		var a = data.get("audio", {})
		Master = a.get("Master", Master)
		Music = a.get("Music", Music)
		SFX = a.get("SFX", SFX)
		
		# Gameplay Mapping
		var gp = data.get("gameplay", {})
		day_night_cycle = gp.get("day_night_cycle", day_night_cycle)
		
		# Graphics Mapping
		var g = data.get("graphics", {})
		showfps = g.get("show_fps", showfps)
		dynamic_resolution = g.get("dynamic_resolution", dynamic_resolution)
		graphics_quality = g.get("graphics_quality", graphics_quality)
		lightning = g.get("lightning", lightning)
		weather = g.get("weather", weather)
		max_render_scale = g.get("max_render_scale", max_render_scale)
		min_render_scale = g.get("min_render_scale", min_render_scale)
		target_fps = g.get("target_fps", target_fps)
		UI_scale = g.get("UI_scale", UI_scale)
		shadows_quality = g.get("shadows_quality", shadows_quality)
		msaa = g.get("msaa", msaa)
		vsync = g.get("vsync", vsync)
		ssao = g.get("ssao", ssao)
		glow = g.get("glow", glow)
		dof = g.get("dof", dof)
		ssr = g.get("ssr", ssr)
		debanding = g.get("debanding", debanding)
		texture_filter = g.get("texture_filter", texture_filter)
		particles_quality = g.get("particles_quality", particles_quality)
		
		if g.has("resolution"):
			resolution = Vector2i(g.resolution.width, g.resolution.height)
	
	apply_audio_settings()
	apply_graphics_settings()

func apply_audio_settings():
	var buses = ["Master", "Music", "SFX"]
	var values = [Master, Music, SFX]
	for i in range(buses.size()):
		var idx = AudioServer.get_bus_index(buses[i])
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(values[i]))
			AudioServer.set_bus_mute(idx, values[i] < 0.01)

func apply_graphics_settings():
	var win = get_window()
	DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_vsync_mode(vsync)
	win.content_scale_factor = UI_scale
	
	var vp = get_viewport()
	var current_renderer = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	
	if dynamic_resolution and current_renderer == "forward_plus":
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	
	vp.set("scaling_3d_value", float(max_render_scale))
	vp.set("msaa_3d", msaa)
	vp.set("use_debanding", debanding)
	
	Engine.max_fps = target_fps
	RenderingServer.directional_soft_shadow_filter_set_quality(shadows_quality)
	
	# After updating variables, inform World_settings to update its cycle state
	var world_settings = get_node_or_null("/root/Root/UserInterface/Game/World_settings")
	if world_settings:
		world_settings.cycle_enabled = day_night_cycle
		
	settings_changed.emit()
	
func reset_to_defaults() -> void:
	Master = 0.8
	Music = 0.7
	SFX = 0.9
	day_night_cycle = true
	graphics_quality = "Ultra"
	apply_audio_settings()
	apply_graphics_settings()
	save_settings()
