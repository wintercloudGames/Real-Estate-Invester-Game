extends Control

var graphics_presets = {
	"Low": {
		"shadows_quality": 0,
		"msaa": Viewport.MSAA_DISABLED,
		"vsync": DisplayServer.VSYNC_DISABLED,
		"ssao": false,
		"glow": false,
		"dof": false,
		"ssr": false,
		"debanding": false,
		"texture_filter": CanvasItem.TEXTURE_FILTER_NEAREST,
		"particles_quality": 0
	},
	"Medium": {
		"shadows_quality": 1,
		"msaa": Viewport.MSAA_2X,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"ssao": false,
		"glow": true,
		"dof": false,
		"ssr": true,
		"debanding": true,
		"texture_filter": CanvasItem.TEXTURE_FILTER_LINEAR,
		"particles_quality": 1
	},
	"High": {
		"shadows_quality": 2,
		"msaa": Viewport.MSAA_4X,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"ssao": true,
		"glow": true,
		"dof": true,
		"ssr": true,
		"debanding": true,
		"texture_filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"particles_quality": 2
	},
	"Ultra": {
		"shadows_quality": 3,
		"msaa": Viewport.MSAA_8X,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"ssao": true,
		"glow": true,
		"dof": true,
		"ssr": true,
		"debanding": true,
		"texture_filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,
		"particles_quality": 3
	}
}

const preset_names = ["Low", "Medium", "High", "Ultra"]
const resolution_presets = [
	Vector2i(1280, 720),   # 720p/HD
	Vector2i(1920, 1080),  # 1080p/Full HD
	Vector2i(2560, 1440),  # 1440p/Quad HD
	Vector2i(3840, 2160)   # 4K/Ultra HD
]

@onready var option_button: OptionButton = $OptionButton
@onready var resolution_option_button: OptionButton = $ResolutionOptionButton
@onready var dynamic_res_check: CheckButton = $DynamicResCheck
@onready var lightning_check: CheckButton = $LightningCheck
@onready var show_fps_check: CheckButton = $ShowFPSCheck
@onready var weather_check: CheckButton = $WeatherCheck
@onready var target_fps_spin: SpinBox = $TargetFPSSpin
@onready var min_render_scale_spin: SpinBox = $MinRenderScaleSpin
@onready var max_render_scale_spin: SpinBox = $MaxRenderScaleSpin
@onready var master_volume_slider: HSlider = $MasterVolumeSlider
@onready var music_volume_slider: HSlider = $MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $SFXVolumeSlider
@onready var ui_scale_slider: HSlider = $UIScaleSlider
@onready var close_button: Button = $CloseButton
@onready var reset_button: Button = $ResetButton
@onready var fps_label: Label = %FPS_Label

func _ready() -> void:
	# Validate UI nodes
	if not (option_button and resolution_option_button and dynamic_res_check and lightning_check and 
			show_fps_check and weather_check and target_fps_spin and min_render_scale_spin and 
			max_render_scale_spin and master_volume_slider and music_volume_slider and 
			sfx_volume_slider and ui_scale_slider and close_button and reset_button and fps_label):
		push_error("One or more UI nodes are missing. Check scene setup.")
		return
	
	# Initialize OptionButton with presets
	option_button.clear()
	for i in range(preset_names.size()):
		option_button.add_item(preset_names[i], i)
	
	# Initialize ResolutionOptionButton with presets
	resolution_option_button.clear()
	for i in range(resolution_presets.size()):
		var res = resolution_presets[i]
		resolution_option_button.add_item("%dx%d" % [res.x, res.y], i)
	print("ResolutionOptionButton initialized with %d items: %s" % [resolution_presets.size(), resolution_presets])
	
	
	# Initialize sliders
	master_volume_slider.min_value = 0.0
	master_volume_slider.max_value = 1.0
	master_volume_slider.step = 0.01
	music_volume_slider.min_value = 0.0
	music_volume_slider.max_value = 1.0
	music_volume_slider.step = 0.01
	sfx_volume_slider.min_value = 0.0
	sfx_volume_slider.max_value = 1.0
	sfx_volume_slider.step = 0.01
	ui_scale_slider.min_value = 0.5
	ui_scale_slider.max_value = 2.0
	ui_scale_slider.step = 0.1
	
	# Update UI
	update_ui_from_settings()
	
	# Log initial state
	print("Settings menu initialized: showfps=%s, graphics_quality=%s, resolution=%s, Master=%s, UI_scale=%s" % 
		[Settings.showfps, Settings.graphics_quality, Settings.resolution, Settings.Master, Settings.UI_scale])

func update_ui_from_settings() -> void:
	if dynamic_res_check:
		dynamic_res_check.button_pressed = Settings.dynamic_resolution
	if lightning_check:
		lightning_check.button_pressed = Settings.lightning
		lightning_check.text = "On" if Settings.lightning else "Off"
	if show_fps_check:
		show_fps_check.button_pressed = Settings.showfps
		show_fps_check.text = "On" if Settings.showfps else "Off"
	if weather_check:
		weather_check.button_pressed = Settings.weather
		weather_check.text = "On" if Settings.weather else "Off"
	if target_fps_spin:
		target_fps_spin.value = Settings.target_fps
	if min_render_scale_spin:
		min_render_scale_spin.value = Settings.min_render_scale
	if max_render_scale_spin:
		max_render_scale_spin.value = Settings.max_render_scale
	if master_volume_slider:
		master_volume_slider.value = Settings.Master
	if music_volume_slider:
		music_volume_slider.value = Settings.Music
	if sfx_volume_slider:
		sfx_volume_slider.value = Settings.SFX
	if ui_scale_slider:
		ui_scale_slider.value = Settings.UI_scale
	if option_button:
		var preset_index = preset_names.find(Settings.graphics_quality)
		if preset_index != -1:
			option_button.selected = preset_index
	if resolution_option_button:
		var res_index = resolution_presets.find(Settings.resolution)
		if res_index != -1:
			resolution_option_button.selected = res_index
		else:
			# Fallback to closest resolution or default
			resolution_option_button.selected = 1  # Default to 1080p
			Settings.resolution = resolution_presets[1]
			Settings.save_settings()
			print("Resolution %s not found in presets, defaulting to 1080p" % Settings.resolution)
	
	# Update FPS label
	if fps_label:
		fps_label.visible = Settings.showfps
		fps_label.modulate = Color.WHITE
		fps_label.add_theme_color_override("font_color", Color.WHITE)
		if Settings.showfps:
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	print("Updated UI: showfps=%s, graphics_quality=%s, resolution=%s, Master=%s, UI_scale=%s" % 
		[Settings.showfps, Settings.graphics_quality, Settings.resolution, Settings.Master, Settings.UI_scale])

func _process(delta: float) -> void:
	if Settings.showfps and fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func apply_graphics_quality(preset: String) -> void:
	if not preset in graphics_presets:
		push_warning("Invalid graphics preset: %s. Falling back to Ultra." % preset)
		preset = "Ultra"
	
	var settings = graphics_presets[preset]
	Settings.shadows_quality = settings.shadows_quality
	Settings.msaa = settings.msaa
	Settings.vsync = settings.vsync
	Settings.ssao = settings.ssao
	Settings.glow = settings.glow
	Settings.dof = settings.dof
	Settings.ssr = settings.ssr
	Settings.debanding = settings.debanding
	Settings.texture_filter = settings.texture_filter
	Settings.particles_quality = settings.particles_quality
	Settings.graphics_quality = preset
	
	Settings.apply_graphics_settings()
	Settings.save_settings()

func _on_option_button_item_selected(index: int) -> void:
	var preset = option_button.get_item_text(index)
	apply_graphics_quality(preset)

func _on_resolution_item_selected(index: int) -> void:
	if index < 0 or index >= resolution_presets.size():
		push_error("Invalid resolution index: %d" % index)
		return
	Settings.resolution = resolution_presets[index]
	Settings.apply_graphics_settings()
	Settings.save_settings()
	print("Resolution changed to: %s" % Settings.resolution)

func _on_dynamic_res_check_toggled(toggled_on: bool) -> void:
	Settings.dynamic_resolution = toggled_on
	Settings.apply_graphics_settings()
	Settings.save_settings()

func _on_lightning_check_toggled(toggled_on: bool) -> void:
	Settings.lightning = toggled_on
	lightning_check.text = "On" if toggled_on else "Off"
	Settings.save_settings()
	print("Lightning toggled: %s" % toggled_on)

func _on_show_fps_check_toggled(toggled_on: bool) -> void:
	Settings.showfps = toggled_on
	show_fps_check.text = "On" if toggled_on else "Off"
	if fps_label:
		fps_label.visible = toggled_on
	Settings.save_settings()
	print("Show FPS toggled: %s" % toggled_on)

func _on_weather_check_toggled(toggled_on: bool) -> void:
	Settings.weather = toggled_on
	weather_check.text = "On" if toggled_on else "Off"
	Settings.save_settings()
	print("Weather toggled: %s" % toggled_on)

func _on_target_fps_spin_value_changed(value: float) -> void:
	Settings.target_fps = int(value)
	Settings.apply_graphics_settings()
	Settings.save_settings()

func _on_min_render_scale_spin_value_changed(value: float) -> void:
	Settings.min_render_scale = value
	Settings.apply_graphics_settings()
	Settings.save_settings()

func _on_max_render_scale_spin_value_changed(value: float) -> void:
	Settings.max_render_scale = value
	Settings.apply_graphics_settings()
	Settings.save_settings()

func _on_master_volume_slider_value_changed(value: float) -> void:
	Settings.Master = value
	Settings.apply_audio_settings()
	Settings.save_settings()

func _on_music_volume_slider_value_changed(value: float) -> void:
	Settings.Music = value
	Settings.apply_audio_settings()
	Settings.save_settings()

func _on_sfx_volume_slider_value_changed(value: float) -> void:
	Settings.SFX = value
	Settings.apply_audio_settings()
	Settings.save_settings()

func _on_ui_scale_slider_value_changed(value: float) -> void:
	Settings.UI_scale = value
	get_tree().root.content_scale_factor = Settings.UI_scale
	Settings.save_settings()
	print("UI scale changed to: %s" % Settings.UI_scale)

func _on_close_button_pressed() -> void:
	if has_node("../AudioStreamPlayer"):
		$"../AudioStreamPlayer".play()
	visible = false
	Settings.save_settings()
	print("Settings menu closed, saving settings: resolution=%s, Master=%s, showfps=%s, UI_scale=%s" % 
		[Settings.resolution, Settings.Master, Settings.showfps, Settings.UI_scale])

func _on_reset_button_pressed() -> void:
	Settings.reset_to_defaults()
	update_ui_from_settings()
