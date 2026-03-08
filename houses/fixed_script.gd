extends MeshInstance3D
class_name HouseMaterialController

enum MATERIAL_TYPES {
	WOOD,
	STONE,
	METAL,
	PLASTER,
	FABRIC,
	GLASS,
	ROOF
}

# Texture libraries
const WOOD_TEXTURES = [
	preload("res://Textures/vol_2_3_Wood_Base_Color.png")
]

const TILE_TEXTURES = [
	preload("res://Textures/Vol_7_1_Tiles_Base_Color.png"),
	preload("res://Textures/Vol_46_2_Tiles_Base_Color.png"),
	preload("res://Textures/Vol_67_3_Tile_Base_Color.png")
]

# Pre-calculated glass tints
const GLASS_TINTS = [
	Color(0.9, 0.95, 1.0),
	Color(0.85, 0.95, 0.9),
	Color(0.95, 0.9, 0.95)
]

enum MATERIAL_QUALITY {
	LOW,    # Simple colors only
	MEDIUM, # Shared materials
	HIGH,   # Per-instance materials
	ULTRA   # Highest quality
}

var material_data = {
	"texture_indices": {},
	"color_variations": {},
	"roughness_values": {},
	"house_id": "",
	"force_black_roofs": true
}

var current_quality: MATERIAL_QUALITY = MATERIAL_QUALITY.MEDIUM

# Shared materials across all instances (static for memory efficiency)
static var shared_materials = {}
var cached_noise_textures = {}

func _ready():
	_load_quality_settings()
	
	# Set visibility based on quality
	visibility_range_begin = 0
	visibility_range_end = _get_visibility_range()
	
	# Skip material generation in Low quality (use simple colors)
	if current_quality == MATERIAL_QUALITY.LOW:
		_apply_low_quality_materials()
		return
	
	if material_data["house_id"] == "":
		material_data["house_id"] = _generate_house_id()
	
	_initialize_or_load_materials()
	_apply_materials()

func _load_quality_settings():
	var quality_preset = _load_graphics_preset()
	match quality_preset:
		"Low": current_quality = MATERIAL_QUALITY.LOW
		"Medium": current_quality = MATERIAL_QUALITY.MEDIUM
		"High": current_quality = MATERIAL_QUALITY.HIGH
		"Ultra": current_quality = MATERIAL_QUALITY.ULTRA
		_: current_quality = MATERIAL_QUALITY.MEDIUM

func _get_visibility_range() -> float:
	match current_quality:
		MATERIAL_QUALITY.LOW: return 200
		MATERIAL_QUALITY.MEDIUM: return 400.0
		MATERIAL_QUALITY.HIGH: return 700.0
		MATERIAL_QUALITY.ULTRA: return 1000.0
		_: return 100.0

func _generate_house_id() -> String:
	var pos = global_transform.origin
	return "house_%d_%d_%d" % [pos.x, pos.y, pos.z]

func _get_material_save_path() -> String:
	var exe_dir = OS.get_executable_path().get_base_dir()
	return exe_dir.path_join("house_materials/%s.json" % material_data["house_id"])

func _get_textures_for_type(type: int) -> Array:
	match type:
		MATERIAL_TYPES.WOOD: return WOOD_TEXTURES
		MATERIAL_TYPES.STONE: return TILE_TEXTURES
		_: return []

func _get_texture_count(type: int) -> int:
	return _get_textures_for_type(type).size()

func _get_roughness_range(type: int) -> Array:
	match type:
		MATERIAL_TYPES.WOOD: return [0.5, 0.8]
		MATERIAL_TYPES.STONE: return [0.7, 1.0]
		MATERIAL_TYPES.ROOF: return [0.8, 1.0]
		_: return [0.5, 1.0]

func _save_material_data():
	var save_path = _get_material_save_path()
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(material_data))
	else:
		push_error("Failed to save house material data to: ", save_path)

func _initialize_or_load_materials():
	# Skip in Low quality
	if current_quality == MATERIAL_QUALITY.LOW:
		return
	
	# Directory setup
	var save_dir = OS.get_executable_path().get_base_dir().path_join("house_materials")
	if !DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	
	# Try loading existing data
	var save_path = _get_material_save_path()
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var loaded_data = JSON.parse_string(file.get_as_text())
			if loaded_data is Dictionary:
				material_data = loaded_data
				return
	
	# Generate new randomized data
	var mesh = self.mesh
	if mesh:
		for surface_idx in mesh.get_surface_count():
			var mat_type = _determine_material_type(surface_idx)
			
			# Special handling for roofs
			if mat_type == MATERIAL_TYPES.ROOF && material_data["force_black_roofs"]:
				material_data["texture_indices"][str(surface_idx)] = -1
			else:
				var texture_count = _get_texture_count(mat_type)
				material_data["texture_indices"][str(surface_idx)] = (
					randi() % texture_count if texture_count > 0 else -1
				)
			
			material_data["color_variations"][str(surface_idx)] = randf_range(-0.1, 0.1)
			material_data["roughness_values"][str(surface_idx)] = randf_range(
				_get_roughness_range(mat_type)[0], 
				_get_roughness_range(mat_type)[1]
			)
	
	_save_material_data()

func _apply_materials():
	# Skip material application in Low quality
	if current_quality == MATERIAL_QUALITY.LOW:
		return
	
	var mesh = self.mesh
	if not mesh: 
		push_warning("No mesh assigned to HouseMaterialController")
		return
	
	for surface_idx in mesh.get_surface_count():
		var mat_type = _determine_material_type(surface_idx)
		var material_key = _get_material_key(mat_type, surface_idx)
		
		# Use shared material if available (MEDIUM quality)
		if current_quality == MATERIAL_QUALITY.MEDIUM and shared_materials.has(material_key):
			mesh.surface_set_material(surface_idx, shared_materials[material_key])
		else:
			# Create new material
			var mat = _create_consistent_material(mat_type, str(surface_idx))
			if mat:
				# Share material for MEDIUM quality
				if current_quality == MATERIAL_QUALITY.MEDIUM:
					shared_materials[material_key] = mat
				mesh.surface_set_material(surface_idx, mat)

func _apply_low_quality_materials():
	var mesh = self.mesh
	if not mesh: return
	
	for surface_idx in mesh.get_surface_count():
		var simple_mat = StandardMaterial3D.new()
		var mat_type = _determine_material_type(surface_idx)
		
		match mat_type:
			MATERIAL_TYPES.ROOF:
				simple_mat.albedo_color = Color.BLACK
				simple_mat.roughness = 1.0
			MATERIAL_TYPES.WOOD:
				simple_mat.albedo_color = Color("#8B4513")  # SaddleBrown
				simple_mat.roughness = 0.7
			MATERIAL_TYPES.STONE:
				simple_mat.albedo_color = Color.GRAY
				simple_mat.roughness = 0.8
			MATERIAL_TYPES.GLASS:
				simple_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.3)
				simple_mat.roughness = 0.1
			_:
				simple_mat.albedo_color = Color.WHITE
				simple_mat.roughness = 0.5
		
		mesh.surface_set_material(surface_idx, simple_mat)

func _get_material_key(mat_type: int, surface_idx: int) -> String:
	return "%s_%s_%d" % [material_data["house_id"], MATERIAL_TYPES.keys()[mat_type], surface_idx]

func _get_noise_texture(seed_value: int, frequency: float) -> NoiseTexture2D:
	var key = "%d_%.1f" % [seed_value, frequency]
	if cached_noise_textures.has(key):
		return cached_noise_textures[key]
	
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = noise
	cached_noise_textures[key] = noise_tex
	return noise_tex

func _create_consistent_material(type: int, surface_key: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	
	match type:
		MATERIAL_TYPES.ROOF:
			if material_data.get("force_black_roofs", true):
				# Configure black roof material
				mat.albedo_color = Color.BLACK
				mat.metallic = 0.0
				mat.roughness = 1.0
				mat.albedo_texture = null
				
				# Add subtle texture variation
				var noise_tex = _get_noise_texture(material_data["house_id"].hash(), 0.5)
				mat.metallic_texture = noise_tex
				mat.metallic = 0.05  # Slight metallic variation
		
		MATERIAL_TYPES.WOOD, MATERIAL_TYPES.STONE:
			# Texture application
			var tex_index = material_data["texture_indices"].get(surface_key, 0)
			var textures = _get_textures_for_type(type)
			if tex_index >= 0 && textures.size() > tex_index:
				mat.albedo_texture = textures[tex_index]
			
			# Color variation
			var hue_shift = material_data["color_variations"].get(surface_key, 0.0)
			mat.albedo_color = Color.from_hsv(
				mat.albedo_color.h + hue_shift,
				mat.albedo_color.s,
				mat.albedo_color.v
			)
			
			# Roughness
			mat.roughness = material_data["roughness_values"].get(surface_key, 0.5)
			
			# Normal map
			var noise_tex = _get_noise_texture(material_data["house_id"].hash(), 5.0)
			mat.normal_texture = noise_tex
		
		MATERIAL_TYPES.GLASS:
			# Glass properties
			var rng = RandomNumberGenerator.new()
			rng.seed = material_data["house_id"].hash()
			
			mat.albedo_color = GLASS_TINTS[rng.randi() % GLASS_TINTS.size()]
			mat.albedo_color.a = rng.randf_range(0.7, 0.9)
			mat.ior = rng.randf_range(1.4, 1.6)
			mat.roughness = rng.randf_range(0.02, 0.1)
	
	return mat

func _determine_material_type(surface_idx: int) -> int:
	var mesh = self.mesh
	if not mesh: return MATERIAL_TYPES.STONE
	
	var surface_name = ""
	if mesh.has_method("surface_get_name"):
		surface_name = mesh.surface_get_name(surface_idx).to_lower()
	
	if "roof" in surface_name: return MATERIAL_TYPES.ROOF
	elif "wood" in surface_name: return MATERIAL_TYPES.WOOD
	elif "glass" in surface_name or "window" in surface_name: return MATERIAL_TYPES.GLASS
	elif "tile" in surface_name or "stone" in surface_name: return MATERIAL_TYPES.STONE
	
	# Fallback logic
	match surface_idx:
		0: return MATERIAL_TYPES.WOOD
		1: return MATERIAL_TYPES.GLASS
		_: return MATERIAL_TYPES.STONE

func _save_graphics_preset(preset: String) -> void:
	var save_data = {
		"graphics_quality": preset
	}

	var file_path = OS.get_executable_path().get_base_dir().path_join("settings.json")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
	else:
		push_error("Failed to save graphics preset")

func _load_graphics_preset() -> String:
	var file_path = OS.get_executable_path().get_base_dir().path_join("settings.json")
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if typeof(data) == TYPE_DICTIONARY and data.has("graphics_quality"):
				return data["graphics_quality"]
	return "Medium"  # default if file not found

# Cleanup function to free resources
func cleanup():
	var mesh = self.mesh
	if mesh:
		for surface_idx in mesh.get_surface_count():
			mesh.surface_set_material(surface_idx, null)
