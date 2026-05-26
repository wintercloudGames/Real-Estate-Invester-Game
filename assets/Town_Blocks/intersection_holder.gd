# intersection_holder.gd
extends Node3D

@export var green_duration: float = 8.0
@export var yellow_duration: float = 2.5

var ns_lights: Array = []
var ew_lights: Array = []
var is_ns_turn: bool = true

@onready var timer: Timer = $Timer

func _ready() -> void:
	# 1. Gather and sort children explicitly
	for child in get_children():
		if child.has_method("is_north_south"):
			if child.is_north_south():
				ns_lights.append(child)
			else:
				ew_lights.append(child)
				
	# 2. Setup and start the loop
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
		
	_start_green_phase()

func _start_green_phase() -> void:
	# Active direction gets green, opposite gets red
	_broadcast_light_state("green", "red")
	timer.start(green_duration)

func _start_yellow_phase() -> void:
	# Active direction warns with yellow, opposite stays red
	_broadcast_light_state("yellow", "red")
	timer.start(yellow_duration)

func _on_timer_timeout() -> void:
	# If we just finished a green phase, move to yellow
	# If we just finished a yellow phase, flip directions and go green
	if timer.wait_time == green_duration:
		_start_yellow_phase()
	else:
		is_ns_turn = !is_ns_turn
		_start_green_phase()

func _broadcast_light_state(active_color: String, idle_color: String) -> void:
	var ns_target = active_color if is_ns_turn else idle_color
	var ew_target = idle_color if is_ns_turn else active_color
	
	for light in ns_lights:
		light.set_light(ns_target)
	for light in ew_lights:
		light.set_light(ew_target)
