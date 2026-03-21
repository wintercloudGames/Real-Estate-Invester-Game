# stock_graph.gd
extends Control

signal hovered_price(price: float)
signal mouse_exited_graph()

var history: Array[float] = []
var mouse_idx: int = -1 # Tracks which data point the mouse is over

func _gui_input(event):
	if event is InputEventMouseMotion and history.size() > 1:
		# Calculate the width between each data point
		var x_step = size.x / (history.size() - 1)
		
		# Determine the index based on mouse X position
		mouse_idx = int(clamp(event.position.x / x_step, 0, history.size() - 1))
		
		# Tell the main app which price we are looking at
		hovered_price.emit(history[mouse_idx])
		queue_redraw() # Force a redraw to move the vertical line

func _on_mouse_exited():
	mouse_idx = -1 # Reset the index so the line disappears
	mouse_exited_graph.emit()
	queue_redraw()

func _draw():
	if history.size() < 2: return
	
	var max_price = history.max()
	var min_price = history.min()
	var range_p = max_price - min_price if max_price != min_price else 1.0
	
	var points = PackedVector2Array()
	var x_step = size.x / (history.size() - 1)
	
	# 1. Generate the main graph line points
	for i in range(history.size()):
		var x = i * x_step
		var y = size.y - ((history[i] - min_price) / range_p) * size.y
		points.append(Vector2(x, y))
	
	# 2. Draw the main graph line [cite: 2]
	draw_polyline(points, Color.GREEN, 3.0, true)
	
	# 3. Draw the Vertical Scrubbing Line
	if mouse_idx != -1:
		var line_x = mouse_idx * x_step
		var top_point = Vector2(line_x, 0)
		var bottom_point = Vector2(line_x, size.y)
		
		# Draw a semi-transparent white line
		draw_line(top_point, bottom_point, Color(1, 1, 1, 0.3), 1.0)
		
		# Optional: Draw a small circle at the exact price point on the line
		var point_y = size.y - ((history[mouse_idx] - min_price) / range_p) * size.y
		draw_circle(Vector2(line_x, point_y), 4.0, Color.WHITE)
