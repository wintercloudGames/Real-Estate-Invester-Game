extends MeshInstance3D
class_name HouseMaterialController

enum MATERIAL_TYPES { WOOD, STONE, METAL, PLASTER, FABRIC, GLASS, ROOF }

# --- TEXTURE LIBRARIES ---
# Ensure these paths are correct in your project folder
const WOOD_TEXTURES = [
	preload("res://Textures/vol_2_3_Wood_Base_Color.png")
]
const TILE_TEXTURES = [
	preload("res://Textures/Vol_7_1_Tiles_Base_Color.png"),
	preload("res://Textures/Vol_46_2_Tiles_Base_Color.png"),
	preload("res://Textures/Vol_67_3_Tile_Base_Color.png")
]
const GLASS_TINTS = [
	Color(0.9, 0.95, 1.0), 
	Color(0.85, 0.95, 0.9), 
	Color(0.95, 0.9, 0.95)
]

# --- DATA & QUALITY ---
var material_data = {
	"texture_indices": {},
	"color_variations": {},
	"roughness_values": {},
	"house_id": "",
	"force_black_roofs": true
}

# Global cache for Medium quality to save memory
static var shared_materials = {}

func _ready():
	# 1. Sync with your global Settings singleton
	_apply_quality_from_settings()
	
	# 2. Identify this specific house instance
	if material_data["house_id"] == "":
		material_data["house_id"] = _generate_house_id()
	
	# 3. Handle data persistence
	_initialize_or_load_materials()
	
	# 4. Apply the looks
	_apply_materials()

func _apply_quality_from_settings():
	# Set draw distance based on the user's global graphics setting
	var quality = Settings.graphics_quality
	match quality:
		"Low": visibility_range_end = 150.0
		"Medium": visibility_range_end = 400.0
		"High": visibility_range_end = 700.0
		"Ultra": visibility_range_end = 1200.0

func _generate_house_id() -> String:
	# Unique ID based on grid position so it stays consistent
	var pos = global_position
	return "h_%d_%d_%d" % [pos.x, pos.y, pos.z]

func _get_save_path() -> String:
	# 'user://' is safe for exported games; 'res://' or 'exe' paths often fail
	return "user://house_materials/%s.json" % material_data["house_id"]

func _initialize_or_load_materials():
	# Create directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if !dir.dir_exists("house_materials"):
		dir.make_dir("house_materials")
	
	var path = _get_save_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			material_data = json.get_data()
			return

	# Generate new randomized data if no save found
	if mesh:
		for i in mesh.get_surface_count():
			var type = _determine_material_type(i)
			var textures = _get_textures_for_type(type)
			
			material_data["texture_indices"][str(i)] = randi() % textures.size() if textures.size() > 0 else -1
			material_data["color_variations"][str(i)] = randf_range(-0.08, 0.08)
			material_data["roughness_values"][str(i)] = randf_range(0.4, 0.9)
	
	_save_material_data()

func _save_material_data():
	var file = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(material_data))

func _apply_materials():
	if not mesh: return
	
	var quality = Settings.graphics_quality

	for i in mesh.get_surface_count():
		# LOW QUALITY: Use simple vertex colors/solid materials
		if quality == "Low":
			set_surface_override_material(i, _create_low_poly_material(i))
			continue
			
		var type = _determine_material_type(i)
		var material_key = "%s_%d" % [material_data["house_id"], i]
		
		# MEDIUM QUALITY: Use shared materials to reduce draw calls
		if quality == "Medium" and shared_materials.has(material_key):
			set_surface_override_material(i, shared_materials[material_key])
		else:
			# HIGH/ULTRA: Create unique material instances
			var mat = _create_standard_material(type, str(i))
			if quality == "Medium":
				shared_materials[material_key] = mat
			set_surface_override_material(i, mat)

func _create_standard_material(type: int, surface_key: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	
	match type:
		MATERIAL_TYPES.ROOF:
			mat.albedo_color = Color.BLACK if material_data["force_black_roofs"] else Color(0.2, 0.2, 0.2)
			mat.roughness = 1.0
		MATERIAL_TYPES.GLASS:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = GLASS_TINTS[randi() % GLASS_TINTS.size()]
			mat.albedo_color.a = 0.6
			mat.metallic = 1.0
			mat.roughness = 0.05
		_:
			var tex_list = _get_textures_for_type(type)
			var tex_idx = material_data["texture_indices"].get(surface_key, -1)
			if tex_idx != -1 and tex_list.size() > tex_idx:
				mat.albedo_texture = tex_list[tex_idx]
			
			mat.roughness = material_data["roughness_values"].get(surface_key, 0.7)
			# Apply the random hue shift
			var shift = material_data["color_variations"].get(surface_key, 0.0)
			mat.albedo_color.h += shift
			
	return mat

func _create_low_poly_material(surface_idx: int) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var type = _determine_material_type(surface_idx)
	# Fast, untextured colors for performance
	match type:
		MATERIAL_TYPES.WOOD: mat.albedo_color = Color("#5d4037")
		MATERIAL_TYPES.ROOF: mat.albedo_color = Color.BLACK
		MATERIAL_TYPES.GLASS: mat.albedo_color = Color("#81d4fa")
		_: mat.albedo_color = Color.GRAY
	return mat

func _determine_material_type(surface_idx: int) -> int:
	# Attempts to find the material type based on the mesh surface name
	var s_name = mesh.get_surface_count() # Fallback
	if mesh.has_method("surface_get_name"):
		var n = mesh.surface_get_name(surface_idx).to_lower()
		if "roof" in n: return MATERIAL_TYPES.ROOF
		if "wood" in n: return MATERIAL_TYPES.WOOD
		if "glass" in n or "window" in n: return MATERIAL_TYPES.GLASS
		if "stone" in n or "wall" in n: return MATERIAL_TYPES.STONE
	
	# Default fallback if names aren't set in Blender
	return MATERIAL_TYPES.STONE

func _get_textures_for_type(type: int) -> Array:
	match type:
		MATERIAL_TYPES.WOOD: return WOOD_TEXTURES
		MATERIAL_TYPES.STONE: return TILE_TEXTURES
		_: return []
