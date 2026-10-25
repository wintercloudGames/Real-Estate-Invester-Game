@tool
extends Node3D

@export var grid_width: int = 12
@export var grid_height: int = 12
@export var tile_size: float = 20.0

@export var generate_town_now: bool = false:
	set(val):
		generate_town_now = val
		if val and Engine.is_editor_hint():
			call_deferred("_deferred_generate")

@export var clear_town_now: bool = false:
	set(val):
		clear_town_now = val
		if val and Engine.is_editor_hint():
			call_deferred("_deferred_clear")

# Preload your modular road and building assets
const ROAD_STRAIGHT = preload("res://assets/Town_Blocks/straight_way.tscn")
const ROAD_TURN = preload("res://assets/Town_Blocks/turn.tscn")
const ROAD_THREEWAY = preload("res://assets/Town_Blocks/threeway.tscn")
const ROAD_FOURWAY = preload("res://assets/Town_Blocks/fourway.tscn")

const HOUSE_SCENE = preload("res://assets/Town_Blocks/Textured Houses/house_type_01.tscn")
const APARTMENT_SCENE = preload("res://houses/building_large.tscn")
const HOSPITAL_SCENE = preload("res://houses/hostpital.tscn")

func _deferred_generate() -> void:
	generate_town()
	generate_town_now = false

func _deferred_clear() -> void:
	clear_existing_town()
	clear_town_now = false

func generate_town() -> void:
	print("[DEBUG] === GENERATING STRUCTURED TOWN GRID ===")
	clear_existing_town()
	
	var owner_node = self
	var spawned_count = 0
	
	# Define road spacing (e.g., a major road every 4 tiles)
	var road_interval = 4

	for x in range(grid_width):
		for z in range(grid_height):
			var tile_pos = Vector3(x * tile_size, 0, z * tile_size)
			var instance: Node3D = null
			var rot_y = 0.0
			
			var is_road_x = (x % road_interval == 0) or (x == 0) or (x == grid_width - 1)
			var is_road_z = (z % road_interval == 0) or (z == 0) or (z == grid_height - 1)
			
			if is_road_x and is_road_z:
				# Intersection (Four-way, Three-way, or Turn depending on grid edges)
				var is_edge = (x == 0 or x == grid_width - 1) and (z == 0 or z == grid_height - 1)
				if is_edge:
					instance = ROAD_TURN.instantiate()
					if x == 0 and z == grid_height - 1: rot_y = 90
					elif x == grid_width - 1 and z == grid_height - 1: rot_y = 180
					elif x == grid_width - 1 and z == 0: rot_y = 270
				else:
					# Check if it's a T-junction or a 4-way intersection
					var connections = 0
					if x > 0: connections += 1
					if x < grid_width - 1: connections += 1
					if z > 0: connections += 1
					if z < grid_height - 1: connections += 1
					
					if connections >= 4:
						instance = ROAD_FOURWAY.instantiate()
					else:
						instance = ROAD_THREEWAY.instantiate()
						
			elif is_road_x or is_road_z:
				# Straight Road segment
				instance = ROAD_STRAIGHT.instantiate()
				if is_road_z and not is_road_x:
					rot_y = 90.0
					
			else:
				# Inside a city block: Place apartments or houses
				# Place a special building/apartment near block centers, houses elsewhere
				if (x % road_interval == 2) and (z % road_interval == 2):
					if ResourceLoader.exists("res://houses/building_large.tscn"):
						instance = APARTMENT_SCENE.instantiate()
						if "is_apartment" in instance:
							instance.is_apartment = true
					else:
						instance = HOUSE_SCENE.instantiate()
				elif x == 1 and z == 1 and ResourceLoader.exists("res://houses/hostpital.tscn"):
					instance = HOSPITAL_SCENE.instantiate()
				else:
					instance = HOUSE_SCENE.instantiate()
					# Give houses slight random rotation for organic look
					rot_y = [0.0, 90.0, 180.0, 270.0][randi() % 4]
					
			if instance:
				add_child(instance)
				instance.position = tile_pos
				instance.rotation_degrees.y = rot_y
				
				instance.owner = owner_node
				_set_owner_recursive(instance, owner_node)
				spawned_count += 1
				
	print("[DEBUG] === TOWN GENERATION COMPLETE. Total spawned: ", spawned_count, " ===")

func clear_existing_town() -> void:
	for child in get_children():
		child.queue_free()
	print("[DEBUG] Town cleared.")

func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		if child.get_child_count() > 0:
			_set_owner_recursive(child, new_owner)
