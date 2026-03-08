# root.gd
extends Node

@onready var ui_layer = get_node("%UserInterface")

func _ready() -> void:
	_display_main_menu()

func _display_main_menu() -> void:
	await _clear_user_interface_with_fade()
	var node = load("res://Menu/MainMenu.tscn").instantiate()
	node.profile_loaded.connect(_on_profile_loaded)
	node.profile_created.connect(_on_profile_created)
	ui_layer.add_child(node)

func _display_game() -> void:
	await _clear_user_interface_with_fade()

	var loading_screen = load("res://Menu/LoadingScreen.tscn").instantiate()
	var progress_bar = loading_screen.get_node("MarginContainer/VBoxContainer/ProgressBar")
	ui_layer.add_child(loading_screen)
	await get_tree().create_timer(0.1).timeout

	var packed_scene = load("res://assets/game.tscn") as PackedScene
	if packed_scene == null:
		push_error("Failed to load game scene.")
		return

	var game_scene = packed_scene.instantiate()
	_fix_particle_trails(game_scene)

	for i in range(20):
		if is_instance_valid(progress_bar):
			progress_bar.value = float(i) / 20.0 * 100.0
			await get_tree().create_timer(0.05).timeout

	if is_instance_valid(loading_screen):
		ui_layer.remove_child(loading_screen)
		loading_screen.queue_free()

	ui_layer.add_child(game_scene)

func _fix_particle_trails(node: Node):
	for child in node.get_children():
		if child is GPUParticles3D or child is GPUParticles2D:
			if child.trail_enabled:
				child.trail_enabled = false
		if child.get_child_count() > 0:
			_fix_particle_trails(child)

func _clear_user_interface_with_fade() -> void:
	for child in ui_layer.get_children():
		child.queue_free()

func _on_profile_loaded(slot: int) -> void:
	SaveAndLoad.current_save_slot = slot
	if await SaveAndLoad.load_game():
		_display_game()
	else:
		push_error("Failed to load profile in slot: ", slot)

func _on_profile_created() -> void:
	_display_game()
