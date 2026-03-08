extends Node3D

@export var city_size: Vector2i = Vector2i(10, 10) # Grid dimensions
@export var road_spacing: int = 3 # Roads every N tiles
@export var tile_size: float = 6.0 # Distance between tiles

@export var road_straight_scene: PackedScene
@export var road_intersection_scene: PackedScene
@export var road_corner_scene: PackedScene
@export var road_t_scene: PackedScene
@export var house_scene: PackedScene

func _ready():
	generate_city()

func generate_city():
	for x in range(city_size.x):
		for z in range(city_size.y):
			var instance
			var rotation = 0

			var is_horizontal_road = (z % road_spacing == 0)
			var is_vertical_road = (x % road_spacing == 0)

			if is_horizontal_road and is_vertical_road:
				instance = road_intersection_scene.instantiate()
			elif is_horizontal_road:
				instance = road_straight_scene.instantiate()
				rotation = 90
			elif is_vertical_road:
				instance = road_straight_scene.instantiate()
			else:
				instance = house_scene.instantiate()

			# Position and rotation
			instance.transform.origin = Vector3(x * tile_size, 0, z * tile_size)
			instance.rotation_degrees.y = rotation
			add_child(instance)
