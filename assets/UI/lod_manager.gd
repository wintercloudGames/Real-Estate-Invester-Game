extends Node

@export var lod_distances: Array = [15.0, 30.0, 50.0]  # Distance thresholds
@export var lod_update_interval: float = 0.3  # Update 3 times per second

var _lod_timer: float = 0.0
var _camera: Camera3D

func _ready():
	_camera = get_viewport().get_camera_3d()
	set_process(true)
	
	# Auto-add LOD to complex objects
	setup_auto_lod()

func _process(delta):
	_lod_timer += delta
	if _lod_timer >= lod_update_interval:
		_lod_timer = 0.0
		update_all_lods()

func setup_auto_lod():
	# Find complex meshes and add LOD automatically
	for mesh_instance in get_tree().get_nodes_in_group("complex_meshes"):
		if mesh_instance.get_child_count() == 0:  # No LOD set up yet
			_add_auto_lod(mesh_instance)

func _add_auto_lod(mesh_instance: MeshInstance3D):
	# Create simplified versions for LOD
	var original_mesh = mesh_instance.mesh
	if not original_mesh:
		return
	
	# Create LOD levels (you'd need to create these simplified meshes)
	var lod_2 = original_mesh  # Placeholder - should be simplified version
	var lod_3 = original_mesh  # Even more simplified
	
	# Create LOD system
	var lod_group = Node3D.new()
	lod_group.name = "LOD_Group"
	
	# High detail
	var high_detail = mesh_instance.duplicate()
	high_detail.name = "LOD_High"
	
	# Medium detail
	var med_detail = mesh_instance.duplicate()
	med_detail.name = "LOD_Medium"
	med_detail.mesh = lod_2
	med_detail.visible = false
	
	# Low detail  
	var low_detail = mesh_instance.duplicate()
	low_detail.name = "LOD_Low"
	low_detail.mesh = lod_3
	low_detail.visible = false
	
	# Replace original with LOD system
	var parent = mesh_instance.get_parent()
	parent.remove_child(mesh_instance)
	parent.add_child(lod_group)
	lod_group.add_child(high_detail)
	lod_group.add_child(med_detail)
	lod_group.add_child(low_detail)
	lod_group.global_position = mesh_instance.global_position

func update_all_lods():
	if not _camera:
		return
	
	var camera_pos = _camera.global_position
	
	for lod_group in get_tree().get_nodes_in_group("house"):
		var distance = lod_group.global_position.distance_to(camera_pos)
		
		# Show appropriate LOD level
		for i in range(lod_group.get_child_count()):
			var child = lod_group.get_child(i)
			child.visible = (i == _get_lod_level(distance))

func _get_lod_level(distance: float) -> int:
	for i in range(lod_distances.size()):
		if distance < lod_distances[i]:
			return i
	return lod_distances.size()  # Lowest detail
