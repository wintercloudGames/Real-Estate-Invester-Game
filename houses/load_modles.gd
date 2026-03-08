extends Node

const RES_FOLDER_PATH = "res://City houses/"
const USER_FOLDER_PATH = "user://City houses/"


func _ready() -> void:
	copy_models_to_user_folder()

# This function ensures the user://City houses/ folder exists and copies .glb files if needed
func copy_models_to_user_folder():
	if not DirAccess.dir_exists_absolute(USER_FOLDER_PATH):
		DirAccess.make_dir_recursive_absolute(USER_FOLDER_PATH)

	var dir = DirAccess.open(RES_FOLDER_PATH)
	if dir:
		dir.list_dir_begin()
		while true:
			var file = dir.get_next()
			if file == "":
				break
			if file.ends_with(".glb"):
				var scene_path = RES_FOLDER_PATH + file
				var user_path = USER_FOLDER_PATH + file

				# Copy only if the file is not already present in user://
				if not FileAccess.file_exists(user_path):
					var file_access = FileAccess.open(scene_path, FileAccess.READ)
					if file_access:
						var file_copy = FileAccess.open(user_path, FileAccess.WRITE)
						if file_copy:
							file_copy.store_buffer(file_access.get_buffer(file_access.get_length()))
							file_copy.close()
						file_access.close()
					else:
						print("Error: Unable to read from ", scene_path)

		dir.list_dir_end()
	else:
		print("Error: Cannot open directory ", RES_FOLDER_PATH)
