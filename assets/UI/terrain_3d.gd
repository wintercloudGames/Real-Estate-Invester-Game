extends Terrain3D

@export var snow_transition_speed: float = 5.0

func set_snow_visibility(show_snow: bool):
	get_material().set("show_texture_normal", show_snow)
	
	# Optional: Add smooth transition
	if snow_transition_speed > 0:
		var tween = create_tween()
		tween.tween_property(
			get_material(), 
			"shader_parameter/texture_scale", 
			Vector2(1, 1) if show_snow else Vector2(0, 0), 
			snow_transition_speed
		)

# Call this when seasons change
func _on_season_changed(is_winter: bool):
	set_snow_visibility(is_winter)
