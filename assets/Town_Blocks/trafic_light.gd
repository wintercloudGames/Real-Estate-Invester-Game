extends Node3D

@onready var spot_light_3d: SpotLight3D = $SpotLight3D

enum Direction { NORTH, SOUTH, EAST, WEST }
@export var traffic_direction: Direction = Direction.NORTH

# Add this variable so cars can read it instantly
var is_red: bool = true 

func is_north_south() -> bool:
	return traffic_direction == Direction.NORTH or traffic_direction == Direction.SOUTH

func set_light(state: String):
	# 1. Update the logical state for the cars
	if state == "red" or state == "yellow":
		is_red = true
	else:
		is_red = false

	# 2. Safety check and visual light settings
	if not spot_light_3d: return

	match state:
		"red":
			spot_light_3d.light_color = Color.RED
			spot_light_3d.light_energy = 5.0
		"yellow":
			spot_light_3d.light_color = Color.YELLOW
			spot_light_3d.light_energy = 4.0
		"green":
			spot_light_3d.light_color = Color.GREEN
			spot_light_3d.light_energy = 5.0
