extends Control

# --- CONFIGURATION DATA ---
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
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

# --- UI NODES ---
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
	# Initialize OptionButtons
	option_button.clear()
	for name in preset_names:
		option_button.add_item(name)
	
	resolution_option_button.clear()
	for res in resolution_presets:
		resolution_option_button.add_item("%dx%d" % [res.x, res.y])
	
	# Connect signals (Essential for logic to trigger)
	option_button.item_selected.connect(_on_option_button_item_selected)
	resolution_option_button.item_selected.connect(_on_resolution_item_selected)
	dynamic_res_check.toggled.connect(_on_dynamic_res_check_toggled)
	lightning_check.toggled.connect(_on_lightning_check_toggled)
	show_fps_check.toggled.connect(_on_show_fps_check_toggled)
	weather_check.toggled.connect(_on_weather_check_toggled)
	target_fps_spin.value_changed.connect(_on_target_fps_spin_value_changed)
	master_volume_slider.value_changed.connect(_on_master_volume_slider_value_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_slider_value_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_slider_value_changed)
	ui_scale_slider.value_changed.connect(_on_ui_scale_slider_value_changed)
	close_button.pressed.connect(_on_close_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)

	update_ui_from_settings()

func update_ui_from_settings() -> void:
	# Sync UI state with the Settings Singleton
	dynamic_res_check.button_pressed = Settings.dynamic_resolution
	lightning_check.button_pressed = Settings.lightning
	show_fps_check.button_pressed = Settings.showfps
	weather_check.button_pressed = Settings.weather
	target_fps_spin.value = Settings.target_fps
	master_volume_slider.value = Settings.Master
	music_volume_slider.value = Settings.Music
	sfx_volume_slider.value = Settings.SFX
	ui_scale_slider.value = Settings.UI_scale
	
	var preset_idx = preset_names.find(Settings.graphics_quality)
	if preset_idx != -1: option_button.selected = preset_idx
	
	var res_idx = resolution_presets.find(Settings.resolution)
	if res_idx != -1: resolution_option_button.selected = res_idx
	
	if fps_label:
		fps_label.visible = Settings.showfps

func _process(_delta: float) -> void:
	if Settings.showfps and fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

# --- RESOLUTION LOGIC (FIXED) ---
func _on_resolution_item_selected(index: int) -> void:
	var new_res = resolution_presets[index]
	Settings.resolution = new_res
	
	# Force the engine to update the window
	DisplayServer.window_set_size(new_res)
	
	# Center the window on screen after resize
	var screen_center = DisplayServer.screen_get_position() + (DisplayServer.screen_get_size() / 2)
	DisplayServer.window_set_position(screen_center - (new_res / 2))
	
	Settings.save_settings()

# --- GRAPHICS & PRESETS ---
func apply_graphics_quality(preset: String) -> void:
	var s = graphics_presets[preset]
	Settings.shadows_quality = s.shadows_quality
	Settings.msaa = s.msaa
	Settings.vsync = s.vsync
	Settings.graphics_quality = preset
	
	# Apply to the engine
	DisplayServer.window_set_vsync_mode(s.vsync)
	get_viewport().msaa_3d = s.msaa
	
	Settings.save_settings()

func _on_option_button_item_selected(index: int) -> void:
	apply_graphics_quality(preset_names[index])

# --- VOLUME LOGIC ---
func _on_master_volume_slider_value_changed(value: float) -> void:
	Settings.Master = value
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	Settings.save_settings()

func _on_music_volume_slider_value_changed(value: float) -> void:
	Settings.Music = value
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	Settings.save_settings()

func _on_sfx_volume_slider_value_changed(value: float) -> void:
	Settings.SFX = value
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	Settings.save_settings()

# --- OTHER SETTINGS ---
func _on_show_fps_check_toggled(toggled_on: bool) -> void:
	Settings.showfps = toggled_on
	if fps_label: fps_label.visible = toggled_on
	Settings.save_settings()

func _on_ui_scale_slider_value_changed(value: float) -> void:
	Settings.UI_scale = value
	get_tree().root.content_scale_factor = value
	Settings.save_settings()

func _on_target_fps_spin_value_changed(value: float) -> void:
	Settings.target_fps = int(value)
	Engine.max_fps = Settings.target_fps
	Settings.save_settings()

func _on_lightning_check_toggled(toggled_on: bool) -> void:
	Settings.lightning = toggled_on
	Settings.save_settings()

func _on_weather_check_toggled(toggled_on: bool) -> void:
	Settings.weather = toggled_on
	Settings.save_settings()

func _on_dynamic_res_check_toggled(toggled_on: bool) -> void:
	Settings.dynamic_resolution = toggled_on
	Settings.save_settings()

func _on_close_button_pressed() -> void:
	visible = false
	Settings.save_settings()

func _on_reset_button_pressed() -> void:
	Settings.reset_to_defaults()
	update_ui_from_settings()
