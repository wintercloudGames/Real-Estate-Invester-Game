extends Node

var _process_usage = {}
var _physics_process_usage = {}

func _ready():
	set_process(true)
	# Find all nodes with process functions
	_find_processing_nodes(get_tree().root)

func _find_processing_nodes(node):
	if node.has_method("_process") and node.is_processing():
		_process_usage[node.get_path()] = 0.0
	if node.has_method("_physics_process") and node.is_physics_processing():
		_physics_process_usage[node.get_path()] = 0.0
	
	for child in node.get_children():
		_find_processing_nodes(child)

func _process(delta):
	# Track which _process functions are taking time
	for path in _process_usage:
		var node = get_node_or_null(path)
		if node and node.is_processing_internal():
			var start_time = Time.get_ticks_usec()
			# We can't directly measure, but we can estimate by checking every frame
			_process_usage[path] += delta  # Track total time
	

func _physics_process(delta):
	# Same for physics process
	for path in _physics_process_usage:
		var node = get_node_or_null(path)
		if node and node.is_physics_processing_internal():
			_physics_process_usage[path] += delta

func print_usage():
	print("=== PROCESS USAGE ===")
	for path in _process_usage:
		if _process_usage[path] > 0.1:  # Only show significant usage
			print("%s: %.2f ms" % [path, _process_usage[path] * 1000])
	
	print("=== PHYSICS PROCESS USAGE ===")
	for path in _physics_process_usage:
		if _physics_process_usage[path] > 0.1:
			print("%s: %.2f ms" % [path, _physics_process_usage[path] * 1000])
