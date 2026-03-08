extends Control

signal profile_loaded(slot: int)
signal profile_created(slot: int)

@export var profile_card_scene: PackedScene
@export var save_name_popup_scene: PackedScene
@export var max_profiles := 10

@onready var profiles_container = %ProfilesContainer
@onready var audio_player = $AudioStreamPlayer
@onready var delete_popup = $Delete_profile_popup
@onready var settings_menu = $Settings_menu

var current_delete_slot: int = -1
var pending_slot: int = -1
var current_rename_slot: int = -1  # ← Track which slot we're renaming

func _ready() -> void:
	if profiles_container == null:
		push_error("ProfilesContainer node is not found!")
		return
	
	refresh_profiles()

	settings_menu.visible = false
	delete_popup.mouse_filter = Control.MOUSE_FILTER_STOP

func refresh_profiles() -> void:
	# Clear existing cards
	for child in profiles_container.get_children():
		child.queue_free()
	
	var profile_count = 0
	var first_empty_slot = -1
	
	# 1. Show ALL existing profiles and find the first empty slot
	for slot in range(max_profiles):
		if SaveAndLoad.save_file_exists(slot):
			var card = profile_card_scene.instantiate()
			card.save_slot = slot
			card.profile_loaded.connect(_on_profile_loaded)
			card.delete_requested.connect(_on_delete_requested)
			card.rename_requested.connect(_on_rename_requested)  # ← Connect rename signal
			profiles_container.add_child(card)
			profile_count += 1
		elif first_empty_slot == -1:  # Found the first empty slot
			first_empty_slot = slot
	
	# 2. If we found empty slots, show new profile button in the first empty slot
	if first_empty_slot != -1:
		var new_card = profile_card_scene.instantiate()
		new_card.save_slot = first_empty_slot
		new_card.profile_created.connect(_on_profile_created)
		profiles_container.add_child(new_card)
	
	# 3. If no empty slots but we're not at max, show new profile button at the end
	elif profile_count < max_profiles:
		var new_card = profile_card_scene.instantiate()
		new_card.save_slot = profile_count
		new_card.profile_created.connect(_on_profile_created)
		profiles_container.add_child(new_card)

func _on_rename_requested(slot: int) -> void:
	current_rename_slot = slot
	show_rename_popup()

func show_rename_popup() -> void:
	if save_name_popup_scene:
		var popup = save_name_popup_scene.instantiate()
		add_child(popup)
		
		# Set current save name as default text
		var current_name = get_save_name(current_rename_slot)
		popup.get_node("VBoxContainer/NameInput").text = current_name
		
		popup.name_confirmed.connect(_on_rename_confirmed)
		popup.cancelled.connect(_on_rename_cancelled)
	else:
		push_error("Rename popup scene not assigned!")
		current_rename_slot = -1

func _on_rename_confirmed(new_name: String) -> void:
	if current_rename_slot != -1:
		# Update the save file with new name
		if rename_save_file(current_rename_slot, new_name):
			print("Profile renamed successfully")
			refresh_profiles()  # Refresh to show the new name
		else:
			push_error("Failed to rename profile")
	current_rename_slot = -1

func _on_rename_cancelled() -> void:
	current_rename_slot = -1
	audio_player.play()

func rename_save_file(slot: int, new_name: String) -> bool:
	var save_path = SaveAndLoad.get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		return false
	
	# Load existing save data
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		return false
	
	var data = json.get_data()
	if not data:
		return false
	
	# Update the save name
	if data.has("Globals"):
		data["Globals"]["save_name"] = new_name
	
	# Save the updated data
	file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func get_save_name(slot: int) -> String:
	var save_path = SaveAndLoad.get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		return "Profile " + str(slot + 1)
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return "Profile " + str(slot + 1)
	
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		return "Profile " + str(slot + 1)
	
	var data = json.get_data()
	if not data or not data.has("Globals"):
		return "Profile " + str(slot + 1)
	
	return data["Globals"].get("save_name", "Profile " + str(slot + 1))

func _on_profile_loaded(slot: int) -> void:
	_load_and_play_profile(slot)

func _on_profile_created() -> void:
	# Find which card emitted this signal
	for card in profiles_container.get_children():
		if card is TextureButton and not SaveAndLoad.save_file_exists(card.save_slot):
			pending_slot = card.save_slot
			show_save_name_popup()
			break

func show_save_name_popup() -> void:
	if save_name_popup_scene:
		var popup = save_name_popup_scene.instantiate()
		add_child(popup)
		popup.name_confirmed.connect(_on_save_name_confirmed)
		popup.cancelled.connect(_on_save_name_cancelled)
	else:
		# Fallback: create profile without naming
		create_profile_directly()

func _on_save_name_confirmed(save_name: String) -> void:
	Globals.save_name = save_name
	create_profile_directly()

func _on_save_name_cancelled() -> void:
	pending_slot = -1
	audio_player.play()

func create_profile_directly() -> void:
	if pending_slot != -1:
		var success = SaveAndLoad.create_new_profile(pending_slot)
		if success:
			_load_and_play_profile(pending_slot)
			Globals.first_start = false
		else:
			push_error("Failed to create new profile in slot: ", pending_slot)
		pending_slot = -1

func _load_and_play_profile(slot: int) -> void:
	
	SaveAndLoad.current_save_slot = slot
	if await SaveAndLoad.load_game():
		profile_loaded.emit(slot)
		audio_player.play()
	else:
		push_error("Failed to load profile in slot: ", slot)
		
func _on_delete_requested(slot: int) -> void:
	current_delete_slot = slot
	var profile_name = "Profile " + str(slot + 1)
	delete_popup.get_node("text").text = "DELETE PROFILE: " + profile_name + "?"
	delete_popup.visible = true
	audio_player.play()

func _on_no_keep_profile_pressed() -> void:
	delete_popup.visible = false
	current_delete_slot = -1
	audio_player.play()

func _on_yes_delete_profile_pressed() -> void:
	if current_delete_slot != -1:
		if SaveAndLoad.delete_save_file(current_delete_slot):
			print("Profile deleted from slot: ", current_delete_slot)
			refresh_profiles()  # This will now show empty slots instead of new profile button
		else:
			push_error("Failed to delete profile from slot: ", current_delete_slot)
	
	delete_popup.visible = false
	current_delete_slot = -1
	audio_player.play()

func _on_quit_button_pressed() -> void:
	audio_player.play()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	settings_menu.visible = true
	audio_player.play()

func _on_settings_menu_closed() -> void:
	settings_menu.visible = false
	audio_player.play()
