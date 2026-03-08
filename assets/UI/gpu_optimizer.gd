extends Node

func _ready():
	optimize_gpu_settings()


func optimize_gpu_settings():
	# DISABLE expensive rendering features
	var viewport = get_viewport()
	
	# 1. Anti-aliasing (biggest GPU killer)
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	
	# 2. Post-processing effects
	viewport.use_debanding = false
	viewport.use_occlusion_culling = true  # Enable this if you have many objects
	
	# 3. Shadow quality
	#get_viewport().get_camera_3d().environment.background_mode = Environment.BG_CLEAR_COLOR
	if get_viewport().get_camera_3d().environment:
		var env = get_viewport().get_camera_3d().environment
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = false
		env.adjustment_enabled = false
	
	# 4. Texture quality
	ProjectSettings.set_setting("rendering/textures/default_filters/use_nearest_mipmap_filter", true)
	
	# 5. Physics (indirect GPU help)
	Engine.physics_ticks_per_second = 30
	
	# 6. Disable V-Sync (can help or hurt, test both)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _input(event):
	# Quick quality toggle for testing
	if event.is_action_pressed("ui_page_down"):
		reduce_quality_more()
	if event.is_action_pressed("ui_page_up"):
		increase_quality()

func reduce_quality_more():

	# Reduce view distance
	var camera = get_viewport().get_camera_3d()
	if camera:
		camera.far = 30  # Very short draw distance
	
	# Lower texture resolution
	ProjectSettings.set_setting("rendering/textures/default_filters/texture_mipmap_bias", 1.0)

func increase_quality():

	var camera = get_viewport().get_camera_3d()
	if camera:
		camera.far = 100
