extends Node

# --- Market parameters ---
@export var min_growth_rate: float = -0.005
@export var max_growth_rate: float = 0.005
@export var min_crash_months: int = 12
@export var max_crash_months: int = 36
@export var crash_severity_min: float = 0.20
@export var crash_severity_max: float = 0.40
@export var volatility: float = 0.02
@export var crash_threshold: float = 0.30

enum Difficulty { EASY, NORMAL, HARD, NIGHTMARE }
@export var difficulty := Difficulty.NORMAL

var difficulty_settings = {
	Difficulty.EASY: { "min_growth_rate": 0.001, "max_growth_rate": 0.003, "min_crash_months": 24, "max_crash_months": 48, "crash_severity_min": 0.10, "crash_severity_max": 0.20, "volatility": 0.01, "crash_threshold": 0.40 },
	Difficulty.NORMAL: { "min_growth_rate": -0.005, "max_growth_rate": 0.005, "min_crash_months": 12, "max_crash_months": 36, "crash_severity_min": 0.20, "crash_severity_max": 0.40, "volatility": 0.02, "crash_threshold": 0.30 },
	Difficulty.HARD: { "min_growth_rate": -0.01, "max_growth_rate": 0.01, "min_crash_months": 6, "max_crash_months": 24, "crash_severity_min": 0.25, "crash_severity_max": 0.45, "volatility": 0.04, "crash_threshold": 0.25 },
	Difficulty.NIGHTMARE: { "min_growth_rate": -0.015, "max_growth_rate": 0.015, "min_crash_months": 3, "max_crash_months": 12, "crash_severity_min": 0.30, "crash_severity_max": 0.50, "volatility": 0.06, "crash_threshold": 0.20 }
}

# --- Nodes ---
@onready var market_label: Label = $"../HUD/UI/Market_conditions"
@onready var market_graph: TextureRect = $"../HUD/Market/MarketGraphTexture"
@onready var market_timer: Timer = $MarketTimer
@onready var resize_handle := $"../HUD/Market/MarketGraphTexture/Resize_Button"

# --- Market data ---
var base_price: float = 10000.0
var current_price: float = 10000.0
var previous_price: float = 10000.0
var is_crashing: bool = false
var price_history: Array = []
var date_history: Array = [] 
var MAX_HISTORY = 2000 
var GRAPH_WIDTH = 512
var GRAPH_HEIGHT = 250
var graph_image: Image
var graph_texture: ImageTexture

var growth_since_last_crash: float = 0.0
var months_since_last_crash: int = 0
var next_crash_months: int = 6
var last_checked_year := -1
var last_checked_month := -1
var post_crash_price: float = 10000.0

# --- Interaction State ---
var zoom_level: float = 1.0
var scroll_offset: int = 0
var hover_idx: int = -1
var is_resizing := false
var is_panning := false
var resize_origin := Vector2()
var initial_size := Vector2()
var hover_label: Label
var hover_layer: CanvasLayer

# --- Save/Load Support ---

func get_market_data() -> Dictionary:
	return {
		"price_history": price_history.duplicate(),
		"date_history": date_history.duplicate(),
		"current_price": current_price,
		"previous_price": previous_price,
		"is_crashing": is_crashing,
		"growth_since_last_crash": growth_since_last_crash,
		"months_since_last_crash": months_since_last_crash,
		"next_crash_months": next_crash_months,
		"post_crash_price": post_crash_price,
		"last_checked_year": last_checked_year,
		"last_checked_month": last_checked_month,
		"graph_size_x": market_graph.size.x,
		"graph_size_y": market_graph.size.y,
		"graph_pos_x": market_graph.global_position.x,
		"graph_pos_y": market_graph.global_position.y
	}

func set_market_data(data: Dictionary) -> void:
	if data.is_empty(): return
	price_history = data.get("price_history", []).duplicate()
	date_history = data.get("date_history", []).duplicate()
	current_price = data.get("current_price", 10000.0)
	previous_price = data.get("previous_price", 10000.0)
	is_crashing = data.get("is_crashing", false)
	growth_since_last_crash = data.get("growth_since_last_crash", 0.0)
	months_since_last_crash = data.get("months_since_last_crash", 0)
	next_crash_months = data.get("next_crash_months", 6)
	post_crash_price = data.get("post_crash_price", 10000.0)
	last_checked_year = data.get("last_checked_year", -1)
	last_checked_month = data.get("last_checked_month", -1)
	
	if data.has("graph_size_x"):
		market_graph.global_position = Vector2(data.graph_pos_x, data.graph_pos_y)
		resize_graph(int(data.graph_size_x), int(data.graph_size_y))
	
	call_deferred("update_graph")

# --- Core Logic ---

func _ready():
	market_graph.mouse_filter = Control.MOUSE_FILTER_STOP
	market_graph.gui_input.connect(_on_graph_gui_input)
	market_graph.mouse_exited.connect(_on_mouse_exited)
	
	resize_handle.mouse_filter = Control.MOUSE_FILTER_PASS
	resize_handle.button_down.connect(_on_resize_start)
	resize_handle.button_up.connect(_on_resize_end)

	# Force hover label to be on top of everything
	hover_layer = CanvasLayer.new()
	hover_layer.layer = 128 
	add_child(hover_layer)

	hover_label = Label.new()
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hover_label.add_theme_constant_override("outline_size", 8)
	hover_layer.add_child(hover_label)
	hover_label.visible = false

	graph_image = Image.create(GRAPH_WIDTH, GRAPH_HEIGHT, false, Image.FORMAT_RGBA8)
	graph_texture = ImageTexture.create_from_image(graph_image)
	market_graph.texture = graph_texture
	apply_difficulty_settings()
	randomize()
	_add_to_history(current_price) # Fill initial point
	next_crash_months = randi_range(min_crash_months, max_crash_months)
	market_timer.start()

func apply_difficulty_settings():
	var settings = difficulty_settings[difficulty]
	min_growth_rate = settings["min_growth_rate"]; max_growth_rate = settings["max_growth_rate"]
	min_crash_months = settings["min_crash_months"]; max_crash_months = settings["max_crash_months"]
	crash_severity_min = settings["crash_severity_min"]; crash_severity_max = settings["crash_severity_max"]
	volatility = settings["volatility"]; crash_threshold = settings["crash_threshold"]

func _process(_delta):
	if is_resizing:
		var delta = get_viewport().get_mouse_position() - resize_origin
		resize_graph(int(initial_size.x + delta.x), int(initial_size.y + delta.y))

	if Globals.year != last_checked_year or Globals.month != last_checked_month:
		last_checked_year = Globals.year; last_checked_month = Globals.month
		perform_monthly_update()
	update_label()

func perform_monthly_update():
	months_since_last_crash += 1
	previous_price = current_price
	var growth_rate = randf_range(min_growth_rate, max_growth_rate)
	current_price *= (1 + growth_rate + randf_range(-volatility, volatility))
	current_price = max(100.0, current_price)
	growth_since_last_crash = max(0.0, (current_price / post_crash_price) - 1.0)
	if months_since_last_crash >= next_crash_months and growth_since_last_crash >= crash_threshold:
		trigger_crash()
	_add_to_history(current_price)
	update_game_economy()
	update_graph()

func trigger_crash():
	is_crashing = true
	update_label()
	await get_tree().create_timer(1.0).timeout
	current_price *= (1.0 - randf_range(crash_severity_min, crash_severity_max))
	post_crash_price = current_price
	growth_since_last_crash = 0.0; months_since_last_crash = 0
	next_crash_months = randi_range(min_crash_months, max_crash_months)
	is_crashing = false

func update_game_economy():
	var market_change = (current_price - previous_price) / previous_price if previous_price != 0 else 0
	for house in get_tree().get_nodes_in_group("houses"):
		if house.has_method("update_market_value"): house.update_market_value(market_change * 0.5)
	Globals.market_factor = clamp(current_price / base_price, 0.5, 2.0)

# --- Graph Engine ---

func get_visible_points() -> Array:
	var visible_count = int(clamp(price_history.size() / zoom_level, 5, price_history.size()))
	var start_idx = clamp(price_history.size() - visible_count - scroll_offset, 0, price_history.size() - visible_count)
	return price_history.slice(start_idx, start_idx + visible_count)

func update_graph():
	graph_image.fill(Color(0.08, 0.08, 0.12))
	var visible_data = get_visible_points()
	if visible_data.size() < 2: return
	var min_p = visible_data.min(); var max_p = visible_data.max()
	var range_p = max(max_p - min_p, 0.01)

	var prev_pt: Vector2
	for i in visible_data.size():
		var x = int(float(i) / (visible_data.size() - 1) * (GRAPH_WIDTH - 1))
		var y = int((1.0 - (visible_data[i] - min_p) / range_p) * (GRAPH_HEIGHT - 1))
		var curr_pt = Vector2(x, y)
		if i > 0:
			var color = Color.RED if is_crashing or visible_data[i] < visible_data[i-1] else Color.GREEN
			draw_line_bresenham(graph_image, prev_pt, curr_pt, color, 2)
		
		var history_idx = price_history.size() - visible_data.size() - scroll_offset + i
		if history_idx == hover_idx:
			draw_line_bresenham(graph_image, Vector2(x, 0), Vector2(x, GRAPH_HEIGHT), Color(1, 1, 1, 0.3), 1)
			_draw_pixel_dot(graph_image, curr_pt, Color.WHITE)
		prev_pt = curr_pt
	graph_texture.update(graph_image)

func _on_graph_gui_input(event: InputEvent):
	var visible_data = get_visible_points()
	if event is InputEventMouseMotion:
		if is_panning:
			var move_ratio = float(visible_data.size()) / GRAPH_WIDTH
			scroll_offset = clamp(scroll_offset + int(event.relative.x * move_ratio), 0, price_history.size() - visible_data.size())
			hover_label.visible = false
			update_graph()
		else:
			var local_pos = event.position
			var idx_in_view = int(clamp(local_pos.x / GRAPH_WIDTH, 0.0, 1.0) * (visible_data.size() - 1))
			hover_idx = clamp(price_history.size() - visible_data.size() - scroll_offset + idx_in_view, 0, price_history.size()-1)
			
			if hover_idx >= 0 and hover_idx < date_history.size():
				hover_label.visible = true
				
				# Calculate % change for this specific point
				var h_price = price_history[hover_idx]
				var h_prev = price_history[hover_idx-1] if hover_idx > 0 else h_price
				var h_percent = ((h_price - h_prev) / h_prev) * 100 if h_prev != 0 else 0
				
				# Get the "Year / Month" string from history
				var h_date = date_history[hover_idx]
				
				# Plain white text: Year/Month then % Change
				hover_label.text = "%s\n%s%.2f%%" % [h_date, "+" if h_percent >= 0 else "", h_percent]
				hover_label.modulate = Color.WHITE
				
				# Follow the mouse globally (since it's in a CanvasLayer)
				hover_label.global_position = get_viewport().get_mouse_position() + Vector2(20, -40)
			update_graph()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_level = clamp(zoom_level + 0.2, 1.0, 10.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_level = clamp(zoom_level - 0.2, 1.0, 10.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT: is_panning = event.pressed; hover_label.visible = not is_panning
		update_graph()

func _on_mouse_exited():
	hover_idx = -1; hover_label.visible = false; update_graph()

func draw_line_bresenham(img: Image, start: Vector2, end: Vector2, color: Color, thick: int = 1):
	var dx = absi(int(end.x) - int(start.x)); var dy = -absi(int(end.y) - int(start.y))
	var sx = 1 if start.x < end.x else -1; var sy = 1 if start.y < end.y else -1
	var err = dx + dy; var x = int(start.x); var y = int(start.y)
	while true:
		for i in range(-thick / 2, thick / 2 + 1):
			for j in range(-thick / 2, thick / 2 + 1):
				var px = x + i; var py = y + j
				if px >= 0 and px < GRAPH_WIDTH and py >= 0 and py < GRAPH_HEIGHT: img.set_pixel(px, py, color)
		if x == int(end.x) and y == int(end.y): break
		var e2 = 2 * err
		if e2 >= dy: err += dy; x += sx
		if e2 <= dx: err += dx; y += sy

func _draw_pixel_dot(img: Image, pos: Vector2, color: Color):
	for i in range(-1, 2):
		for j in range(-1, 2):
			var px = int(pos.x) + i; var py = int(pos.y) + j
			if px >= 0 and px < GRAPH_WIDTH and py >= 0 and py < GRAPH_HEIGHT: img.set_pixel(px, py, color)

func update_label():
	var change_percent = ((current_price - previous_price) / previous_price) * 100 if previous_price != 0 else 0
	market_label.modulate = Color.RED if is_crashing or current_price < previous_price else Color.GREEN
	market_label.text = "Market: %s\nChange: %s%.2f%%" % [
		"CRASHING!" if is_crashing else "Stable",
		"+" if current_price >= previous_price else "", change_percent
	]
func _add_to_history(val: float):
	price_history.append(val)
	# Format: "Year / Month" (e.g., "2026 / 3")
	var date_str = str(Globals.year) + " / " + str(Globals.month)
	date_history.append(date_str)
	# Keep history synchronized and within MAX_HISTORY limit
	if price_history.size() > MAX_HISTORY: 
		price_history.pop_front()
		date_history.pop_front()

func _on_market_timer_timeout():
	previous_price = current_price
	current_price *= (1 + randf_range(-volatility / 10.0, volatility / 10.0))
	_add_to_history(current_price)
	update_graph()

func resize_graph(new_w, new_h):
	GRAPH_WIDTH = clamp(new_w, 100, 2048); GRAPH_HEIGHT = clamp(new_h, 100, 1024)
	graph_image = Image.create(GRAPH_WIDTH, GRAPH_HEIGHT, false, Image.FORMAT_RGBA8)
	graph_texture = ImageTexture.create_from_image(graph_image)
	market_graph.texture = graph_texture
	market_graph.custom_minimum_size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)
	update_graph()

func _on_resize_start(): is_resizing = true; resize_origin = get_viewport().get_mouse_position(); initial_size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)
func _on_resize_end(): is_resizing = false
