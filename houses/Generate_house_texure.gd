extends MeshInstance3D
class_name HouseMaterialController

enum MATERIAL_TYPES { WOOD, STONE, METAL, PLASTER, FABRIC, GLASS, ROOF }

# --- TEXTURE LIBRARIES ---
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

# Shared cache for Medium quality to save memory
static var shared_materials: Dictionary = {}

var material_data = {
	"texture_indices": {},
	"color_variations": {},
	"roughness_values": {},
	"house_id": "",
	"force_black_roofs": true
}

func _ready() -> void:
	# Apply Visibility Range - houses far away/off-screen will not render the model
	_apply_visibility_range()
	
	# Generate unique house ID
	if material_data["house_id"] == "":
		material_data["house_id"] = _generate_house_id()
	
	# Only do expensive material work if the house is close enough to be seen
	if _should_apply_materials():
		_initialize_or_load_materials()
		_apply_materials()
	else:
		# Far away house - use very cheap fallback
		_apply_low_quality_fallback()

# ==================== VISIBILITY RANGE (What you requested) ====================
func _apply_visibility_range() -> void:
	visibility_range_begin = 0.0
	
	match Settings.graphics_quality:
		"Low":    visibility_range_end = 120.0
		"Medium": visibility_range_end = 250.0
		"High":   visibility_range_end = 450.0
		"Ultra":  visibility_range_end = 800.0
		_:        visibility_range_end = 300.0
	
	# Smooth fade when appearing/disappearing
	visibility_range_begin_margin = 20.0
	visibility_range_end_margin = 40.0

# Check if house is close enough to warrant full materials
func _should_apply_materials() -> bool:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return true
	var distance = global_position.distance_to(camera.global_position)
	return distance < (visibility_range_end + 60.0)  # small buffer

func _generate_house_id() -> String:
	var pos = global_position
	return "h_%d_%d_%d" % [int(pos.x), int(pos.y), int(pos.z)]

func _initialize_or_load_materials() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("house_materials"):
		dir.make_dir("house_materials")
	
	var path = "user://house_materials/%s.json" % material_data["house_id"]
	
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			material_data = json.get_data()
			return
	
	# Generate new random materials
	if mesh:
		for i in mesh.get_surface_count():
			var type = _determine_material_type(i)
			var textures = _get_textures_for_type(type)
			material_data["texture_indices"][str(i)] = randi() % textures.size() if textures.size() > 0 else -1
			material_data["color_variations"][str(i)] = randf_range(-0.08, 0.08)
			material_data["roughness_values"][str(i)] = randf_range(0.4, 0.9)
	
	_save_material_data()

func _save_material_data() -> void:
	var path = "user://house_materials/%s.json" % material_data["house_id"]
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(material_data))

func _apply_materials() -> void:
	if not mesh: 
		return
	
	var quality = Settings.graphics_quality
	
	for i in mesh.get_surface_count():
		if quality == "Low":
			set_surface_override_material(i, _create_low_poly_material(i))
			continue
		
		var material_key = "%s_%d" % [material_data["house_id"], i]
		
		if quality == "Medium" and shared_materials.has(material_key):
			set_surface_override_material(i, shared_materials[material_key])
		else:
			var mat = _create_standard_material(i)
			if quality == "Medium":
				shared_materials[material_key] = mat
			set_surface_override_material(i, mat)

func _apply_low_quality_fallback() -> void:
	if mesh:
		for i in mesh.get_surface_count():
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.58, 0.58, 0.62)
			mat.roughness = 0.95
			set_surface_override_material(i, mat)

# ==================== MATERIAL CREATION ====================
func _create_standard_material(surface_idx: int) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var type = _determine_material_type(surface_idx)
	
	match type:
		MATERIAL_TYPES.ROOF:
			mat.albedo_color = Color.BLACK if material_data["force_black_roofs"] else Color(0.22, 0.22, 0.25)
			mat.roughness = 1.0
		MATERIAL_TYPES.GLASS:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = GLASS_TINTS[randi() % GLASS_TINTS.size()]
			mat.albedo_color.a = 0.55
			mat.metallic = 0.95
			mat.roughness = 0.05
		_:
			var tex_list = _get_textures_for_type(type)
			var tex_idx = material_data["texture_indices"].get(str(surface_idx), -1)
			if tex_idx != -1 and tex_list.size() > tex_idx:
				mat.albedo_texture = tex_list[tex_idx]
			mat.roughness = material_data["roughness_values"].get(str(surface_idx), 0.7)
			var shift = material_data["color_variations"].get(str(surface_idx), 0.0)
			mat.albedo_color.h += shift
	
	return mat

func _create_low_poly_material(surface_idx: int) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var type = _determine_material_type(surface_idx)
	match type:
		MATERIAL_TYPES.WOOD:  mat.albedo_color = Color("#5d4037")
		MATERIAL_TYPES.ROOF:  mat.albedo_color = Color.BLACK
		MATERIAL_TYPES.GLASS: mat.albedo_color = Color("#81d4fa")
		_: mat.albedo_color = Color(0.55, 0.55, 0.6)
	return mat

func _determine_material_type(surface_idx: int) -> int:
	if mesh and mesh.has_method("surface_get_name"):
		var n = mesh.surface_get_name(surface_idx).to_lower()
		if "roof" in n: return MATERIAL_TYPES.ROOF
		if "wood" in n: return MATERIAL_TYPES.WOOD
		if "glass" in n or "window" in n: return MATERIAL_TYPES.GLASS
		if "stone" in n or "wall" in n: return MATERIAL_TYPES.STONE
	return MATERIAL_TYPES.STONE

func _get_textures_for_type(type: int) -> Array:
	match type:
		MATERIAL_TYPES.WOOD:  return WOOD_TEXTURES
		MATERIAL_TYPES.STONE: return TILE_TEXTURES
		_: return []
