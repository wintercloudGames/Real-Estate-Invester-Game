extends Control

# --- CONFIGURATION DATA ---
var graphics_presets = {
	"Low": {
		"shadows_quality": 0, "msaa": Viewport.MSAA_DISABLED, "vsync": DisplayServer.VSYNC_DISABLED,
		"ssao": false, "glow": false, "dof": false, "ssr": false, "debanding": false,
		"texture_filter": CanvasItem.TEXTURE_FILTER_NEAREST, "particles_quality": 0
	},
	"Medium": {
		"shadows_quality": 1, "msaa": Viewport.MSAA_2X, "vsync": DisplayServer.VSYNC_ENABLED,
		"ssao": false, "glow": true, "dof": false, "ssr": true, "debanding": true,
		"texture_filter": CanvasItem.TEXTURE_FILTER_LINEAR, "particles_quality": 1
	},
	"High": {
		"shadows_quality": 2, "msaa": Viewport.MSAA_4X, "vsync": DisplayServer.VSYNC_ENABLED,
		"ssao": true, "glow": true, "dof": true, "ssr": true, "debanding": true,
		"texture_filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "particles_quality": 2
	},
	"Ultra": {
		"shadows_quality": 3, "msaa": Viewport.MSAA_8X, "vsync": DisplayServer.VSYNC_ENABLED,
		"ssao": true, "glow": true, "dof": true, "ssr": true, "debanding": true,
		"texture_filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "particles_quality": 3
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
@onready var day_night_check: CheckButton = $DayNightCheck
@onready var show_fps_check: CheckButton = $ShowFPSCheck
@onready var weather_check: CheckButton = $WeatherCheck
@onready var target_fps_spin: SpinBox = $TargetFPSSpin
@onready var master_volume_slider: HSlider = $MasterVolumeSlider
@onready var music_volume_slider: HSlider = $MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $SFXVolumeSlider
@onready var ui_scale_slider: HSlider = $UIScaleSlider
@onready var close_button: Button = $CloseButton
@onready var reset_button: Button = $ResetButton

@onready var fps_label: Label = get_node_or_null("%FPS_Label") 

var fps_update_timer: float = 0.0

func _ready() -> void:
	option_button.clear()
	for p_name in preset_names: option_button.add_item(p_name)
	
	resolution_option_button.clear()
	for res in resolution_presets: resolution_option_button.add_item("%dx%d" % [res.x, res.y])
	
	# Connect Signals
	_safe_connect(option_button.item_selected, _on_option_button_item_selected)
	_safe_connect(resolution_option_button.item_selected, _on_resolution_item_selected)
	_safe_connect(dynamic_res_check.toggled, _on_dynamic_res_check_toggled)
	_safe_connect(lightning_check.toggled, _on_lightning_check_toggled)
	_safe_connect(day_night_check.toggled, _on_day_night_check_toggled)
	_safe_connect(show_fps_check.toggled, _on_show_fps_check_toggled)
	_safe_connect(weather_check.toggled, _on_weather_check_toggled)
	_safe_connect(target_fps_spin.value_changed, _on_target_fps_spin_value_changed)
	_safe_connect(master_volume_slider.value_changed, _on_master_volume_slider_value_changed)
	_safe_connect(music_volume_slider.value_changed, _on_music_volume_slider_value_changed)
	_safe_connect(sfx_volume_slider.value_changed, _on_sfx_volume_slider_value_changed)
	_safe_connect(ui_scale_slider.value_changed, _on_ui_scale_slider_value_changed)
	_safe_connect(close_button.pressed, _on_close_button_pressed)
	_safe_connect(reset_button.pressed, _on_reset_button_pressed)

	update_ui_from_settings()

func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable): sig.connect(callable)

# Helper to update the button text to "On" or "Off"
func _update_toggle_text(button: CheckButton, is_on: bool) -> void:
	button.text = "On" if is_on else "Off"

func update_ui_from_settings() -> void:
	# Load visual states
	dynamic_res_check.button_pressed = Settings.dynamic_resolution
	_update_toggle_text(dynamic_res_check, Settings.dynamic_resolution)
	
	lightning_check.button_pressed = Settings.lightning
	_update_toggle_text(lightning_check, Settings.lightning)
	
	day_night_check.button_pressed = Settings.day_night_cycle
	_update_toggle_text(day_night_check, Settings.day_night_cycle)
	
	show_fps_check.button_pressed = Settings.showfps
	_update_toggle_text(show_fps_check, Settings.showfps)
	
	weather_check.button_pressed = Settings.weather
	_update_toggle_text(weather_check, Settings.weather)
	
	target_fps_spin.value = Settings.target_fps
	master_volume_slider.value = Settings.Master
	music_volume_slider.value = Settings.Music
	sfx_volume_slider.value = Settings.SFX
	ui_scale_slider.value = Settings.UI_scale
	
	var preset_idx = preset_names.find(Settings.graphics_quality)
	if preset_idx != -1: option_button.selected = preset_idx
	
	var res_idx = resolution_presets.find(Settings.resolution)
	if res_idx != -1: resolution_option_button.selected = res_idx
	
	# Global Sync
	_sync_cycle_to_world(Settings.day_night_cycle)
	_sync_weather_to_world(Settings.weather)
	if is_instance_valid(fps_label): fps_label.visible = Settings.showfps

func _process(delta: float) -> void:
	fps_update_timer += delta
	if fps_update_timer >= 0.5:
		fps_update_timer = 0.0
		if Settings.showfps and is_instance_valid(fps_label):
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

# --- TOGGLE LOGIC ---

func _on_day_night_check_toggled(toggled_on: bool) -> void:
	Settings.day_night_cycle = toggled_on
	_update_toggle_text(day_night_check, toggled_on)
	_sync_cycle_to_world(toggled_on)
	Settings.save_settings()

func _sync_cycle_to_world(enabled: bool) -> void:
	var world_settings = get_node_or_null("/root/Root/UserInterface/Game/World_settings")
	if world_settings:
		world_settings.cycle_enabled = enabled

func _on_weather_check_toggled(toggled_on: bool) -> void:
	Settings.weather = toggled_on
	_update_toggle_text(weather_check, toggled_on)
	_sync_weather_to_world(toggled_on)
	Settings.save_settings()

func _sync_weather_to_world(enabled: bool) -> void:
	var season_system = get_node_or_null("/root/Root/UserInterface/Game/Season_System")
	if season_system:
		season_system.set_process(enabled)
		# Clear existing particles if turned off
		if not enabled:
			if season_system.has_node("Rain"): season_system.get_node("Rain").emitting = false
			if season_system.has_node("Snow"): season_system.get_node("Snow").emitting = false

func _on_lightning_check_toggled(toggled_on: bool) -> void:
	Settings.lightning = toggled_on
	_update_toggle_text(lightning_check, toggled_on)
	Settings.save_settings()

func _on_show_fps_check_toggled(toggled_on: bool) -> void:
	Settings.showfps = toggled_on
	_update_toggle_text(show_fps_check, toggled_on)
	if is_instance_valid(fps_label): fps_label.visible = toggled_on
	Settings.save_settings()

func _on_dynamic_res_check_toggled(toggled_on: bool) -> void:
	Settings.dynamic_resolution = toggled_on
	_update_toggle_text(dynamic_res_check, toggled_on)
	Settings.save_settings()

# --- OTHER LOGIC ---

func _on_master_volume_slider_value_changed(value: float) -> void:
	Settings.Master = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	Settings.save_settings()

func _on_music_volume_slider_value_changed(value: float) -> void:
	Settings.Music = value
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1: AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	Settings.save_settings()

func _on_sfx_volume_slider_value_changed(value: float) -> void:
	Settings.SFX = value
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1: AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	Settings.save_settings()

func _on_ui_scale_slider_value_changed(value: float) -> void:
	Settings.UI_scale = value
	get_tree().root.content_scale_factor = value
	Settings.save_settings()

func _on_target_fps_spin_value_changed(value: float) -> void:
	Settings.target_fps = int(value)
	Engine.max_fps = Settings.target_fps
	Settings.save_settings()

func _on_resolution_item_selected(index: int) -> void:
	var new_res = resolution_presets[index]
	Settings.resolution = new_res
	DisplayServer.window_set_size(new_res)
	var screen_center = DisplayServer.screen_get_position() + (DisplayServer.screen_get_size() / 2)
	DisplayServer.window_set_position(screen_center - (new_res / 2))
	Settings.save_settings()

func _on_option_button_item_selected(index: int) -> void:
	var preset = preset_names[index]
	var s = graphics_presets[preset]
	Settings.shadows_quality = s.shadows_quality
	Settings.msaa = s.msaa
	Settings.vsync = s.vsync
	Settings.graphics_quality = preset
	DisplayServer.window_set_vsync_mode(s.vsync)
	get_viewport().msaa_3d = s.msaa
	Settings.save_settings()

func _on_close_button_pressed() -> void:
	visible = false
	Settings.save_settings()

func _on_reset_button_pressed() -> void:
	Settings.reset_to_defaults()
	update_ui_from_settings()
