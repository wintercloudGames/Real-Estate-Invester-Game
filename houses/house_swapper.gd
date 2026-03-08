extends Node3D
class_name HouseManager

# Store the file paths to the houses located next to the EXE
var house_model_paths: Array = []
var house_data_path: String = ""
var exe_folder: String = ""

func _ready() -> void:
	remove_child($house_type11)
	exe_folder = OS.get_executable_path().get_base_dir()
	house_data_path = exe_folder.path_join("saved_houses.json")
	
	# First ensure the Houses directory exists
	setup_houses_directory()
	
	# Load saved houses if they exist
	if FileAccess.file_exists(house_data_path):
		load_houses()
	else:
		initialize_house_paths()
		save_houses()
	
	add_model_to_scene(Vector3(0, 0, 0))

func setup_houses_directory():
	var dir = DirAccess.open(exe_folder)
	if not dir.dir_exists("Houses"):
		dir.make_dir("Houses")
	
	# Copy any missing house files from res:// to exe folder
	for i in range(1, 22):
		var target_file = "house_type_%02d.tscn" % i
		var source_path = "res://3D assets/Textured Houses/" + target_file
		var target_path = exe_folder.path_join("Houses").path_join(target_file)
		
		# Only copy if doesn't exist in target
		if not FileAccess.file_exists(target_path):
			# First try original file
			if ResourceLoader.exists(source_path):
				var res = ResourceLoader.load(source_path)
				if res is PackedScene:
					if ResourceSaver.save(res, target_path) == OK:
						print("✅ Copied original: ", target_file)
						continue
			
			# Fallback to .remap file if original fails
			var remap_path = source_path + ".remap"
			if ResourceLoader.exists(remap_path):
				var remap_res = ResourceLoader.load(remap_path)
				if remap_res is PackedScene:
					if ResourceSaver.save(remap_res, target_path) == OK:
						print("⚠️ Used remap file for: ", target_file)
						continue
			
			push_error("❌ Missing both original and remap for: ", target_file)

func initialize_house_paths():
	house_model_paths = []
	for i in range(1, 22):
		var model_path = exe_folder.path_join("Houses/house_type_%02d.tscn" % i)
		house_model_paths.append(model_path)

func save_houses() -> void:
	var save_data = {
		"model_paths": house_model_paths,
		"last_position": Vector3.ZERO
	}
	
	var file = FileAccess.open(house_data_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
	else:
		push_error("Failed to save house data to: ", house_data_path)

func load_houses() -> void:
	var file = FileAccess.open(house_data_path, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			house_model_paths = data.get("model_paths", [])
	else:
		push_error("Failed to load house data from: ", house_data_path)

func add_model_to_scene(position: Vector3 = Vector3.ZERO) -> void:
	if house_model_paths.is_empty():
		push_warning("No house model paths available.")
		return

	var index = randi_range(0, house_model_paths.size() - 1)
	var scene_path = house_model_paths[index]
	
	# Try loading directly first
	if FileAccess.file_exists(scene_path):
		var scene = load(scene_path)
		if scene and scene is PackedScene:
			var house_instance = scene.instantiate()
			if house_instance:
				house_instance.transform.origin = position
				add_child(house_instance)
				save_roof_material(house_instance)
				return
	
	# Fallback to checking for remap version
	var remap_path = scene_path + ".remap"
	if FileAccess.file_exists(remap_path):
		var remap_scene = load(remap_path)
		if remap_scene and remap_scene is PackedScene:
			var house_instance = remap_scene.instantiate()
			if house_instance:
				house_instance.transform.origin = position
				add_child(house_instance)
				save_roof_material(house_instance)
				return
	
	push_error("Failed to load house scene from: " + scene_path)

func save_roof_material(house_instance: Node3D) -> void:
	var material_path = exe_folder.path_join("house_materials/%s.json" % house_instance.name)
	
	var material_data = {
		"force_black_roofs": true,
		"last_modified": Time.get_datetime_string_from_system()
	}
	
	# Ensure directory exists
	var dir = DirAccess.open(exe_folder)
	if not dir.dir_exists("house_materials"):
		dir.make_dir("house_materials")
	
	# Save to file
	var file = FileAccess.open(material_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(material_data))
