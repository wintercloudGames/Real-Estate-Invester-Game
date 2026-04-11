extends DirectionalLight3D

# Adjust this to change how fast the day passes
@export var day_speed: float = 0.02

func _process(_delta: float) -> void:
	# Continuous rotation for the day/night cycle
	rotation_degrees.y += day_speed
