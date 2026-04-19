extends Control

signal profile_loaded(slot: int)
signal profile_created(slot: int)

@export var profile_card_scene: PackedScene
@export var save_name_popup_scene: PackedScene
@export var max_profiles := 10

# UI Node References
@onready var profiles_container = %ProfilesContainer
@onready var main_profiles_panel = $ProfilesContainer
@onready var mode_selection = $ModeSelectionPanel
@onready var missions_menu = $Missons
@onready var mission_list_container = $Missons/ScrollContainer/MissionListContainer
@onready var audio_player = $AudioStreamPlayer
@onready var delete_popup = $Delete_profile_popup

var current_delete_slot: int = -1
var pending_slot: int = -1
var current_rename_slot: int = -1 
var temporary_save_name: String = "" # Holds the name until a mode is picked

func _ready() -> void:
	Globals.reset(Globals.GameMode.FREEPLAY)
	Globals.active_mission_id = null
	Globals.completed_missions = []
	missions_menu.visible = false
	mode_selection.visible = false
	delete_popup.visible = false
	main_profiles_panel.visible = true
	refresh_profiles()

func _on_profile_loaded(slot: int) -> void:
	SaveAndLoad.current_save_slot = slot
	
	main_profiles_panel.visible = false
	mode_selection.visible = false
	
	# Wait for the file to load into Globals and convert active_mission_id to a Resource
	var success = await SaveAndLoad.load_game()
	
	if success:
		if audio_player: audio_player.play()
		
		match Globals.current_game_mode:
			Globals.GameMode.MISSION:
				# If the save file has an active mission resource, resume it immediately
				if Globals.active_mission != null:
					print("Resuming Mission: ", Globals.active_mission.id)
					profile_loaded.emit(slot)
				else:
					# No mission in progress, show the selection menu to pick one
					missions_menu.visible = true
					populate_mission_menu()
			
			Globals.GameMode.FREEPLAY, Globals.GameMode.STORY:
				profile_loaded.emit(slot)
	else:
		main_profiles_panel.visible = true
		push_error("Load failed for slot: ", slot)

func _on_save_name_confirmed(save_name: String) -> void:
	if current_rename_slot != -1:
		SaveAndLoad.rename_save_slot(current_rename_slot, save_name)
		current_rename_slot = -1
		refresh_profiles()
	else:
		# For new profiles
		temporary_save_name = save_name
		SaveAndLoad.current_save_slot = pending_slot
		main_profiles_panel.visible = false 
		mode_selection.visible = true
	
	pending_slot = -1

# --- MODE SELECTION & PROFILE CREATION ---

func _finalize_profile_creation(mode: Globals.GameMode):
	Globals.save_name = temporary_save_name
	Globals.current_game_mode = mode
	
	# Create the actual file on disk
	if SaveAndLoad.create_new_profile(SaveAndLoad.current_save_slot):
		profile_created.emit(SaveAndLoad.current_save_slot)
	
	temporary_save_name = "" 

func _on_story_pressed():
	_finalize_profile_creation(Globals.GameMode.STORY)

func _on_freeplay_pressed():
	_finalize_profile_creation(Globals.GameMode.FREEPLAY)

func _on_misson_pressed():
	mode_selection.visible = false
	missions_menu.visible = true
	populate_mission_menu()

# --- MISSION SYSTEM ---

func _on_mission_clicked(mission: MissionData) -> void:
	# 1. Update Global State
	Globals.active_mission = mission
	Globals.current_game_mode = Globals.GameMode.MISSION
	
	# 2. Check if this is a BRAND NEW profile or an EXISTING profile picking a new mission
	if temporary_save_name != "":
		# New profile flow
		_finalize_profile_creation(Globals.GameMode.MISSION)
	else:
		# Existing profile flow (Resuming a profile but picking a new mission)
		SaveAndLoad.save_game() # Save the fact that this mission is now active
		profile_loaded.emit(SaveAndLoad.current_save_slot) # Start the game

func populate_mission_menu() -> void:
	for child in mission_list_container.get_children():
		child.queue_free()
		
	var missions = load_all_missions()
	var completed = Globals.completed_missions
	
	for mission in missions:
		var btn = Button.new()
		
		# We use .strip_edges() to ensure no hidden spaces break the check
		var mission_id = mission.id.strip_edges()
		var is_actually_done = false
		
		for completed_id in completed:
			if completed_id.strip_edges() == mission_id:
				is_actually_done = true
				break
		
		if is_actually_done:
			btn.modulate = Color.GREEN
			btn.text = mission.title + " (Done)"
			btn.disabled = true
		else:
			# Check unlock requirement
			var req = mission.unlock_id_needed.strip_edges()
			var is_unlocked = req == "" or completed.has(req)
			
			if is_unlocked:
				btn.text = mission.title
				btn.pressed.connect(_on_mission_clicked.bind(mission))
			else:
				btn.text = mission.title + ": Locked"
				btn.disabled = true
				
		mission_list_container.add_child(btn)

func load_all_missions() -> Array[MissionData]:
	var missions: Array[MissionData] = []
	var path = "res://Gamelevels/missons/" 
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if !dir.current_is_dir():
				if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
					var full_path = path + file_name.replace(".remap", "")
					var resource = load(full_path)
					if resource is MissionData:
						missions.append(resource)
			file_name = dir.get_next()
	return missions

# --- NAVIGATION & UTILITY ---

func refresh_profiles() -> void:
	for child in profiles_container.get_children():
		child.queue_free()
	
	var found_empty = false
	for slot in range(max_profiles):
		var exists = SaveAndLoad.save_file_exists(slot)
		if exists or not found_empty:
			var card = profile_card_scene.instantiate()
			card.save_slot = slot
			card.profile_loaded.connect(_on_profile_loaded)
			card.profile_created.connect(func(s): 
				pending_slot = s
				show_save_name_popup()
			) 
			card.delete_requested.connect(_on_delete_requested)
			card.rename_requested.connect(_on_rename_requested)
			profiles_container.add_child(card)
			if not exists: found_empty = true

func show_save_name_popup() -> void:
	if save_name_popup_scene:
		var popup = save_name_popup_scene.instantiate()
		add_child(popup)
		popup.name_confirmed.connect(_on_save_name_confirmed)
		popup.cancelled.connect(_on_save_name_cancelled)

func _on_save_name_cancelled():
	pending_slot = -1
	current_rename_slot = -1
	temporary_save_name = ""

func _on_rename_requested(slot: int) -> void:
	current_rename_slot = slot
	show_save_name_popup()

func _on_delete_requested(slot: int) -> void:
	current_delete_slot = slot
	delete_popup.visible = true

func _on_yes_delete_profile_pressed() -> void:
	if current_delete_slot != -1:
		SaveAndLoad.delete_save_file(current_delete_slot)
		refresh_profiles()
	delete_popup.visible = false

func _on_no_keep_profile_pressed():
	delete_popup.visible = false

func _on_quit_button_pressed():
	get_tree().quit()

func _on_misson_menu_close_button_pressed() -> void:
	missions_menu.visible = false
	main_profiles_panel.visible = true

func _on_close_mode_button_pressed() -> void:
	main_profiles_panel.visible = true
	mode_selection.visible = false
