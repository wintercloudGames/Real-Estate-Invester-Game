@tool
extends Node

# Exported variable to select a house scene
@export var house_name: String = "":
	set(value):
		house_name = value
		_update_house()
		if Engine.is_editor_hint():
			notify_property_list_changed()

# Path to the folder containing house scenes
var scenes_folder: String = "res://3D assets/Textured Houses/" # Verify this path
var scene_files: Array[String] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		_scan_scenes()
		notify_property_list_changed()
		print("Scanned scenes: ", scene_files) # Debug output
	else:
		_update_house() # Instantiate on runtime

func _scan_scenes() -> void:
	scene_files.clear()
	if not DirAccess.dir_exists_absolute(scenes_folder):
		push_error("Directory does not exist: " + scenes_folder)
		return
	
	var dir = DirAccess.open(scenes_folder)
	if dir == null:
		push_error("Failed to open directory: " + scenes_folder)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			scene_files.append(file_name.get_basename())
			print("Found scene: ", file_name) # Debug
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if scene_files.is_empty():
		print("No .tscn files found in: ", scenes_folder)

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
	# Preserve default properties
	properties = get_parent().get_property_list() if has_method("get_parent") else []
	
	if Engine.is_editor_hint():
		_scan_scenes()
	
	var house_prop: Dictionary = {
		"name": "house_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	}
	
	if not scene_files.is_empty():
		house_prop["hint_string"] = ",".join(scene_files)
		print("Dropdown options: ", house_prop["hint_string"]) # Debug
	else:
		house_prop["type"] = TYPE_STRING
		house_prop["hint"] = PROPERTY_HINT_NONE
		house_prop["hint_string"] = ""
		print("No scenes found; house_name is a text field")
	
	properties.append(house_prop)
	return properties

func _set(property: StringName, value: Variant) -> bool:
	if property == "house_name":
		house_name = value
		_update_house()
		return true
	return false

func _get(property: StringName) -> Variant:
	if property == "house_name":
		return house_name
	return null

func _update_house() -> void:
	# Remove existing house instances
	for child in get_children():
		if child.is_in_group("house_instance"):
			child.queue_free()
	
	# Instantiate new house if selection is valid
	if not house_name.is_empty() and house_name in scene_files:
		var scene_path = scenes_folder + house_name + ".tscn"
		var scene = load(scene_path)
		if scene:
			var instance = scene.instantiate()
			instance.add_to_group("house_instance")
			add_child(instance)
			if Engine.is_editor_hint():
				instance.owner = get_tree().edited_scene_root # Ensure visible in editor
			print("Instantiated house: ", house_name) # Debug
		else:
			push_error("Failed to load scene: " + scene_path)
