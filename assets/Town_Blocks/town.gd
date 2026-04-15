extends Node3D

# Update these to your exact paths from the FileSystem
const ROAD_STRAIGHT = preload("res://assets/Town_Blocks/straight_way.tscn")
const ROAD_TURN = preload("res://assets/Town_Blocks/turn.tscn")

@export var tile_count: int = 20
@export var snap_size: float = 6.0

# Keep track of where we've already built
var occupied_tiles = []

func _ready():
	generate_town()

func generate_town():
	# 1. Reset
	for child in get_children():
		child.queue_free()
	occupied_tiles.clear()
	
	var current_pos = Vector3.ZERO
	var current_dir = Vector3.FORWARD
	
	for i in range(tile_count):
		occupied_tiles.append(current_pos)
		
		# Decide: Go Straight (70% chance) or Turn (30% chance)
		var is_turn = randf() < 0.3 and i > 0
		var piece_to_spawn = ROAD_STRAIGHT
		var next_dir = current_dir
		
		if is_turn:
			piece_to_spawn = ROAD_TURN
			# Pick a random 90-degree turn (Left or Right)
			var turn_angle = PI/2 if randf() > 0.5 else -PI/2
			next_dir = current_dir.rotated(Vector3.UP, turn_angle).snapped(Vector3.ONE)
		
		# Spawn and align
		spawn_and_align(piece_to_spawn, current_pos, current_dir, next_dir)
		
		# Move to next snap point
		current_pos += next_dir * snap_size
		current_dir = next_dir

func spawn_and_align(scene: PackedScene, pos: Vector3, incoming_dir: Vector3, outgoing_dir: Vector3):
	var instance = scene.instantiate()
	add_child(instance)
	instance.position = pos
	
	# Logic to rotate the piece to face the direction of travel
	if incoming_dir == outgoing_dir:
		# Straight road: Point it toward the next tile
		instance.look_at(pos + outgoing_dir, Vector3.UP)
	else:
		# Turn: This requires specific alignment based on how your turn mesh is modeled.
		# Most turn assets require looking "between" the two directions.
		var look_dir = (incoming_dir + outgoing_dir).normalized()
		instance.look_at(pos + look_dir, Vector3.UP)
		# You might need to add a 45-degree offset here depending on the turn mesh:
		# instance.rotate_y(deg_to_rad(45))
