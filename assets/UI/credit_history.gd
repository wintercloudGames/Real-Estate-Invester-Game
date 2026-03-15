extends Control

@export var line_color: Color = Color.GREEN
@export var thickness: float = 3.0
@export var font_size: int = 18 # Slightly larger for readability
@export var outline_size: int = 4 # Thickness of the white border
@export var padding: float = 25.0
@export var hover_radius: float = 18.0 

func _process(_delta):
	queue_redraw() 

func _draw():
	if Globals.credit_history.size() < 2:
		return

	var size = get_size()
	var points = PackedVector2Array()
	var font = ThemeDB.fallback_font
	var x_step = size.x / (Globals.credit_history.size() - 1)
	var mouse_pos = get_local_mouse_position()
	
	# 1. Calculate all points
	for i in range(Globals.credit_history.size()):
		var score = Globals.credit_history[i]
		var normalized_y = remap(score, 300, 850, size.y - padding, padding)
		points.append(Vector2(i * x_step, normalized_y))
	
	# 2. Draw the line
	draw_polyline(points, line_color, thickness, true)
	
	# 3. Draw the dots and numbers
	for i in range(points.size()):
		var p = points[i]
		var is_hovered = mouse_pos.distance_to(p) < hover_radius
		
		# Draw the dot
		var dot_size = 7.0 if is_hovered else 4.0
		draw_circle(p, dot_size, line_color)
		
		# 4. Draw the Number ONLY if hovered
		if is_hovered:
			var score_int: int = int(Globals.credit_history[i])
			var score_text = str(score_int)
			var text_offset = Vector2(-15, -20)
			
			# Draw the WHITE OUTLINE first
			draw_string_outline(font, p + text_offset, score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, Color.WHITE)
			
			# Draw the BLACK TEXT on top
			draw_string(font, p + text_offset, score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
