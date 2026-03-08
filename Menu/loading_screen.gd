extends Node



func _ready():
	copy_assets()


func copy_assets() -> bool:
	# Configuration - adjust these paths as needed
	var source_dir = "res://3D assets/Textured Houses/"
	var target_dir = OS.get_executable_path().get_base_dir().path_join("Houses")
	
	# 1. Verify source directory exists in Godot's virtual filesystem
	if not DirAccess.dir_exists_absolute(source_dir):
		return false
	
	# 2. Create target directory in OS filesystem
	var dir = DirAccess.open(target_dir.get_base_dir())
	if not dir:
		return false
		
	if dir.make_dir_recursive(target_dir.get_file()) != OK:
		return false
	
	# 3. Get list of files using Godot's virtual filesystem
	var files = []
	var source_dir_access = DirAccess.open(source_dir)
	if source_dir_access:
		source_dir_access.list_dir_begin()
		var file_name = source_dir_access.get_next()
		
		while file_name != "":
			if not source_dir_access.current_is_dir() and not file_name.ends_with(".import"):
				files.append(file_name)
			file_name = source_dir_access.get_next()
	
	if files.is_empty():
		return false
	
	# 4. Copy each file using Godot's FileAccess
	var files_copied = 0
	for file in files:
		var source_path = source_dir.path_join(file)
		var target_path = target_dir.path_join(file)
		
		# Read file content from Godot's virtual filesystem
		var file_content = FileAccess.get_file_as_bytes(source_path)
		if file_content == null:
			continue
			
		# Write to OS filesystem
		var target_file = FileAccess.open(target_path, FileAccess.WRITE)
		if target_file:
			target_file.store_buffer(file_content)
			target_file.close()

			files_copied += 1

	return files_copied > 0
