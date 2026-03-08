extends Node3D

# -------------------------
# ROOM SCENES
# -------------------------
@export var room_scenes: Dictionary = {
	"fourway": preload("res://assets/Town_Blocks/fourway.tscn"),
	"straight_way": preload("res://assets/Town_Blocks/straight_way.tscn"),
	"threeway": preload("res://assets/Town_Blocks/threeway.tscn"),
	"turn": preload("res://assets/Town_Blocks/turn.tscn"),
	"end": preload("res://assets/Town_Blocks/end.tscn")
}

# -------------------------
# PARAMETERS
# -------------------------
@export var grid_size: Vector2i = Vector2i(10,10)
@export var room_size: float = 7.0
@export var num_clusters: int = 3
@export var max_cluster_size: int = 12

# -------------------------
# INTERNAL VARIABLES
# -------------------------
var grid: Array = []
var rooms: Array = []
var room_positions: Dictionary = {}

# -------------------------
# READY
# -------------------------
func _ready():
	randomize()
	generate_town()

# -------------------------
# MAIN GENERATION
# -------------------------
func generate_town():
	clear_existing_rooms()
	initialize_grid()
	create_clusters_with_paths()
	create_rooms_and_connect()
	assign_room_types()
	print_grid()
	analyze_town()

# -------------------------
# CLEAR EXISTING ROOMS
# -------------------------
func clear_existing_rooms():
	for child in get_children():
		if child.has_meta("is_room"):
			child.queue_free()
	rooms.clear()
	room_positions.clear()
	grid.clear()

# -------------------------
# INITIALIZE GRID
# -------------------------
func initialize_grid():
	grid = []
	for y in range(grid_size.y):
		var row = []
		for x in range(grid_size.x):
			row.append(null)
		grid.append(row)

# -------------------------
# CREATE CLUSTERS AND CONNECT
# -------------------------
func create_clusters_with_paths():
	# Step 1: Place seeds
	var seeds = []
	for i in range(num_clusters):
		var seed = Vector2i(randi() % grid_size.x, randi() % grid_size.y)
		if grid[seed.y][seed.x]==null:
			grid[seed.y][seed.x] = true
			seeds.append(seed)

	# Step 2: Expand clusters
	for seed in seeds:
		var frontier = [seed]
		var count = 1
		while frontier.size() > 0 and count < max_cluster_size:
			var pos = frontier.pop_back()
			for dir in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var next = pos + dir
				if is_valid_position(next.x,next.y) and grid[next.y][next.x]==null:
					grid[next.y][next.x] = true
					frontier.append(next)
					count += 1
					if count >= max_cluster_size:
						break

	# Step 3: Connect clusters
	for i in range(seeds.size()-1):
		connect_points(seeds[i], seeds[i+1])

func connect_points(a:Vector2i, b:Vector2i):
	var x = a.x
	var y = a.y
	while x != b.x:
		x += 1 if x < b.x else -1
		if grid[y][x]==null:
			grid[y][x] = true
	while y != b.y:
		y += 1 if y < b.y else -1
		if grid[y][x]==null:
			grid[y][x] = true

# -------------------------
# CREATE ROOM INSTANCES
# -------------------------
func create_rooms_and_connect():
	# Instantiate rooms
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if grid[y][x]==true:
				var room = create_room_at(x,y,"fourway",0)
				grid[y][x] = room

	# Connect rooms
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var room = grid[y][x]
			if room:
				for dir in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var nx = x + dir.x
					var ny = y + dir.y
					if is_valid_position(nx,ny) and grid[ny][nx]:
						connect_rooms(room,grid[ny][nx],dir)

# -------------------------
# ASSIGN ROOM TYPES BASED ON CONNECTIONS
# -------------------------
func assign_room_types():
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var room = grid[y][x]
			if not room:
				continue

			var neighbors = []
			if room.has_meta("connections"):
				for conn in room.get_meta("connections"):
					neighbors.append(conn["direction"])

			var count = neighbors.size()
			var new_type = ""
			var new_rot = 0

			if count == 4:
				new_type = "fourway"
			elif count == 3:
				new_type = "threeway"
				new_rot = get_threeway_rotation(neighbors)
			elif count == 2:
				if (neighbors.has(Vector2i(1,0)) and neighbors.has(Vector2i(-1,0))) or (neighbors.has(Vector2i(0,1)) and neighbors.has(Vector2i(0,-1))):
					new_type = "straight_way"
					new_rot = 0 if neighbors.has(Vector2i(0,1)) else 90
				else:
					new_type = "turn"
					new_rot = get_turn_rotation_from_dirs(neighbors)
			elif count == 1:
				new_type = "end"
				new_rot = get_end_rotation_from_dir(neighbors[0])
			else:
				new_type = "end"
				new_rot = 90

			# Replace room
			room.queue_free()
			grid[y][x] = create_room_at(x,y,new_type,new_rot)

# -------------------------
# ROTATION HELPERS
# -------------------------
func get_threeway_rotation(neighbors:Array) -> int:
	if not neighbors.has(Vector2i(1,0)):
		return 180
	elif not neighbors.has(Vector2i(-1,0)):
		return 0
	elif not neighbors.has(Vector2i(0,1)):
		return 90
	elif not neighbors.has(Vector2i(0,-1)):
		return 270
	return 0

func get_turn_rotation_from_dirs(neighbors:Array) -> int:
	if neighbors.has(Vector2i(1,0)) and neighbors.has(Vector2i(0,1)):
		return 0
	elif neighbors.has(Vector2i(-1,0)) and neighbors.has(Vector2i(0,1)):
		return 90
	elif neighbors.has(Vector2i(-1,0)) and neighbors.has(Vector2i(0,-1)):
		return 180
	elif neighbors.has(Vector2i(1,0)) and neighbors.has(Vector2i(0,-1)):
		return 270
	return 0

func get_end_rotation_from_dir(dir:Vector2i) -> int:
	if dir == Vector2i(1,0):
		return 0
	elif dir == Vector2i(-1,0):
		return 180
	elif dir == Vector2i(0,1):
		return 90
	elif dir == Vector2i(0,-1):
		return 270
	return 0

# -------------------------
# ROOM CREATION
# -------------------------
func create_room_at(x:int,y:int,room_type:String,rotation_degrees:float=0)->Node3D:
	if room_type not in room_scenes:
		push_error("Room type not found: "+room_type)
		return null
	var room = room_scenes[room_type].instantiate()
	add_child(room)
	room.set_meta("is_room",true)
	room.set_meta("room_type",room_type)
	room.set_meta("grid_position",Vector2i(x,y))
	room.set_meta("rotation",rotation_degrees)
	room.position = Vector3(x*room_size,0,y*room_size)
	room.rotation_degrees.y = rotation_degrees
	rooms.append(room)
	room_positions[Vector2i(x,y)] = room
	return room

# -------------------------
# CONNECT ROOMS
# -------------------------
func connect_rooms(room_a:Node3D,room_b:Node3D,dir:Vector2i):
	if not room_a or not room_b or room_a==room_b:
		return
	var conn_a = room_a.get_meta("connections") if room_a.has_meta("connections") else []
	var conn_b = room_b.get_meta("connections") if room_b.has_meta("connections") else []
	for c in conn_a:
		if c["room"]==room_b:
			return
	conn_a.append({"room":room_b,"direction":dir})
	conn_b.append({"room":room_a,"direction":Vector2i(-dir.x,-dir.y)})
	room_a.set_meta("connections",conn_a)
	room_b.set_meta("connections",conn_b)

# -------------------------
# UTILITIES
# -------------------------
func is_valid_position(x:int,y:int)->bool:
	return x>=0 and y>=0 and x<grid_size.x and y<grid_size.y
func print_grid():
	for y in range(grid_size.y):
		var row = ""
		for x in range(grid_size.x):
			var r = grid[y][x]
			if r:
				var t = r.get_meta("room_type")
				var rot = int(r.get_meta("rotation"))
				if t == "fourway":
					row += "╬ "
				elif t == "threeway":
					row += "╦ "
				elif t == "turn":
					if rot == 0:
						row += "└ "
					elif rot == 90:
						row += "┘ "
					elif rot == 180:
						row += "┐ "
					elif rot == 270:
						row += "┌ "
				elif t == "straight_way":
					if rot == 90:
						row += "─ "
					else:
						row += "│ "
				elif t == "end":
					if rot == 0:
						row += "→ "
					elif rot == 90:
						row += "↓ "
					elif rot == 180:
						row += "← "
					elif rot == 270:
						row += "↑ "
				else:
					row += "? "
			else:
				row += ". "
		print(row)

func analyze_town():
	print("\n=== TOWN STATISTICS ===")
	print("Total rooms: ", rooms.size())
	var types = {"fourway":0,"threeway":0,"straight_way":0,"turn":0,"end":0}
	for r in rooms:
		var t = r.get_meta("room_type")
		if t in types:
			types[t]+=1
	for k in types.keys():
		print(str(k) + ": " + str(types[k]))
