extends Node

# Market parameters
@export var min_growth_rate: float = -0.005
@export var max_growth_rate: float = 0.005
@export var min_crash_months: int = 12
@export var max_crash_months: int = 36
@export var crash_severity_min: float = 0.20
@export var crash_severity_max: float = 0.40
@export var volatility: float = 0.02
@export var crash_threshold: float = 0.30  # Growth needed for crash eligibility

enum Difficulty { EASY, NORMAL, HARD, NIGHTMARE }
@export var difficulty := Difficulty.NORMAL

# Difficulty Settings for a Balanced Economy
var difficulty_settings = {
	Difficulty.EASY: {
		"min_growth_rate": 0.001,
		"max_growth_rate": 0.003,
		"min_crash_months": 24,
		"max_crash_months": 48,
		"crash_severity_min": 0.10,
		"crash_severity_max": 0.20,
		"volatility": 0.01,
		"crash_threshold": 0.40
	},
	Difficulty.NORMAL: {
		"min_growth_rate": -0.005,
		"max_growth_rate": 0.005,
		"min_crash_months": 12,
		"max_crash_months": 36,
		"crash_severity_min": 0.20,
		"crash_severity_max": 0.40,
		"volatility": 0.02,
		"crash_threshold": 0.30
	},
	Difficulty.HARD: {
		"min_growth_rate": -0.01,
		"max_growth_rate": 0.01,
		"min_crash_months": 6,
		"max_crash_months": 24,
		"crash_severity_min": 0.25,
		"crash_severity_max": 0.45,
		"volatility": 0.04,
		"crash_threshold": 0.25
	},
	Difficulty.NIGHTMARE: {
		"min_growth_rate": -0.015,
		"max_growth_rate": 0.015,
		"min_crash_months": 3,
		"max_crash_months": 12,
		"crash_severity_min": 0.30,
		"crash_severity_max": 0.50,
		"volatility": 0.06,
		"crash_threshold": 0.20
	}
}

# Nodes
@onready var market_label: Label = $"../HUD/UI/Market_conditions"
@onready var market_graph: TextureRect = $"../HUD/Market/MarketGraphTexture"
@onready var market_timer: Timer = $MarketTimer  # Timer for real-time updates (15s)
var camera: Camera3D

var is_resizing := false
var resize_origin := Vector2()
var initial_size := Vector2()

@onready var resize_handle := $"../HUD/Market/MarketGraphTexture/Resize_Button"

# Market data
var base_price: float = 10000.0
var current_price: float = 10000.0
var previous_price: float = 10000.0
var is_crashing: bool = false
var price_history: Array = []
var MAX_HISTORY = 200
var GRAPH_WIDTH = 512
var GRAPH_HEIGHT = 250
var graph_image: Image
var graph_texture: ImageTexture

var growth_since_last_crash: float = 0.0
var months_since_last_crash: int = 0
var next_crash_months: int = 6  # Will be set in _ready
var last_checked_year := -1
var last_checked_month := -1
var post_crash_price: float = 10000.0  # Track price after last crash for relative growth

func get_market_data() -> Dictionary:
	return {
		"price_history": price_history.duplicate(),
		"current_price": current_price,
		"previous_price": previous_price,
		"is_crashing": is_crashing,
		"growth_since_last_crash": growth_since_last_crash,
		"months_since_last_crash": months_since_last_crash,
		"next_crash_months": next_crash_months,
		"post_crash_price": post_crash_price
	}

func set_market_data(data: Dictionary) -> void:
	price_history = data.get("price_history", []).duplicate()
	current_price = data.get("current_price", 10000.0)
	previous_price = data.get("previous_price", 10000.0)
	is_crashing = data.get("is_crashing", false)
	growth_since_last_crash = data.get("growth_since_last_crash", 0.0)
	months_since_last_crash = data.get("months_since_last_crash", 0)
	next_crash_months = data.get("next_crash_months", 6)
	post_crash_price = data.get("post_crash_price", 10000.0)

func _ready():
	resize_handle.mouse_filter = Control.MOUSE_FILTER_PASS
	resize_handle.connect("button_down", Callable(self, "_on_resize_start"))
	resize_handle.connect("button_up", Callable(self, "_on_resize_end"))

	# Initialize graph
	graph_image = Image.create(GRAPH_WIDTH, GRAPH_HEIGHT, false, Image.FORMAT_RGBA8)
	graph_texture = ImageTexture.create_from_image(graph_image)
	market_graph.texture = graph_texture

	apply_difficulty_settings()
	randomize()
	next_crash_months = randi_range(min_crash_months, max_crash_months)

	# Start the timer for real-time volatility updates (small changes)
	market_timer.wait_time = 15.0
	market_timer.autostart = true
	market_timer.start()

func apply_difficulty_settings():
	var settings = difficulty_settings[difficulty]
	min_growth_rate = settings["min_growth_rate"]
	max_growth_rate = settings["max_growth_rate"]
	min_crash_months = settings["min_crash_months"]
	max_crash_months = settings["max_crash_months"]
	crash_severity_min = settings["crash_severity_min"]
	crash_severity_max = settings["crash_severity_max"]
	volatility = settings["volatility"]
	crash_threshold = settings["crash_threshold"]

func _on_resize_start():
	is_resizing = true
	resize_origin = get_viewport().get_mouse_position()
	initial_size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)

func _on_resize_end():
	is_resizing = false

func _process(_delta):
	if is_resizing:
		var mouse_pos = get_viewport().get_mouse_position()
		var delta = mouse_pos - resize_origin

		var new_width = int(initial_size.x + delta.x)
		var new_height = int(initial_size.y + delta.y)

		new_width = clamp(new_width, 100, 2048)
		new_height = clamp(new_height, 100, 1024)

		resize_graph(new_width, new_height)

	# Check for monthly updates
	if Globals.year != last_checked_year or Globals.month != last_checked_month:
		last_checked_year = Globals.year
		last_checked_month = Globals.month
		perform_monthly_update()

	update_label()

func perform_monthly_update():
	months_since_last_crash += 1

	# Major monthly growth
	previous_price = current_price
	var growth_rate = randf_range(min_growth_rate, max_growth_rate)
	
	# Mean-reversion bias to prevent extremes
	var reversion_bias: float = 0.0
	if current_price > base_price * 1.5:
		reversion_bias = -0.005  # Pull down
	elif current_price < base_price * 0.8:
		reversion_bias = 0.005   # Pull up
	growth_rate += reversion_bias
	
	var volatility_adjust = randf_range(-volatility, volatility)
	current_price *= (1 + growth_rate + volatility_adjust)
	current_price = max(1000.0, current_price)  # Prevent too low

	# Update growth (relative to post-crash price)
	growth_since_last_crash = (current_price / post_crash_price) - 1.0
	growth_since_last_crash = max(0.0, growth_since_last_crash)  # Prevent negative blocking crashes

	# Check for crash
	if months_since_last_crash >= next_crash_months and growth_since_last_crash >= crash_threshold:
		trigger_crash()

	# Append to history
	price_history.append(current_price)
	if price_history.size() > MAX_HISTORY:
		price_history.pop_front()

	update_game_economy()
	update_graph()

func update_market_value():
	# Minor real-time volatility (small adjustments between months)
	previous_price = current_price
	var small_volatility = randf_range(-volatility / 10.0, volatility / 10.0)  # 1/10th for smoothness
	current_price *= (1 + small_volatility)
	current_price = max(1000.0, current_price)

	# Update history for graph
	price_history.append(current_price)
	if price_history.size() > MAX_HISTORY:
		price_history.pop_front()

	update_graph()

func update_label():
	var price_change = current_price - previous_price
	var change_percent = (price_change / previous_price) * 100 if previous_price != 0 else 0
	var text_color: Color
	if is_crashing:
		text_color = Color.RED
	elif price_change > 0:
		text_color = Color.GREEN
	elif price_change < 0:
		text_color = Color.RED
	else:
		text_color = Color.ROYAL_BLUE

	market_label.modulate = text_color
	market_label.text = "Market: %s\nPrice: $%d\nChange: %s%.2f%%" % [
		"CRASHING!" if is_crashing else "Stable",
		round(current_price),
		"+" if price_change > 0 else "",
		change_percent
	]

func trigger_crash():
	is_crashing = true
	update_label()

	# Apply crash
	await get_tree().create_timer(1.0).timeout
	var crash_severity = randf_range(crash_severity_min, crash_severity_max)
	current_price = max(1000.0, current_price * (1.0 - crash_severity))
	post_crash_price = current_price
	growth_since_last_crash = 0.0
	months_since_last_crash = 0
	next_crash_months = randi_range(min_crash_months, max_crash_months)
	is_crashing = false


func update_game_economy():
	var market_change = (current_price - previous_price) / previous_price if previous_price != 0 else 0
	for house in get_tree().get_nodes_in_group("houses"):
		if house.has_method("update_market_value"):
			house.update_market_value(market_change * 0.5)  # Half strength for house prices

	# Update Globals.market_factor
	Globals.market_factor = clamp(current_price / base_price, 0.5, 2.0)  # Clamp to avoid extremes

	# Update job pay
	Globals.job_pay *= (1 + market_change)

	# Call refresh on food_market if exists
	var food_market = get_node_or_null("../FoodMarket")  # Adjust path to your food_market node
	if food_market and food_market.has_method("refresh_food_buttons"):
		food_market.refresh_food_buttons()

func update_graph():
	graph_image.fill(Color(0.1, 0.1, 0.15))  # Dark background

	if price_history.size() < 2:
		return

	var min_price = price_history.min()
	var max_price = price_history.max()
	var range_price = max(max_price - min_price, 0.01)

	draw_grid(min_price, max_price)

	var prev_point: Vector2
	for i in price_history.size():
		var x = int(float(i) / (price_history.size() - 1) * (GRAPH_WIDTH - 1))  # Scale to full width
		var y = int((1.0 - (price_history[i] - min_price) / range_price) * (GRAPH_HEIGHT - 1))
		var current_point = Vector2(x, y)

		if i > 0:
			var line_color = Color.GREEN
			if is_crashing:
				line_color = Color.RED
			elif price_history[i] < price_history[i - 1]:
				line_color = Color(1, 0.5, 0)  # Orange
			draw_line_bresenham(graph_image, prev_point, current_point, line_color, 2)

		prev_point = current_point

	graph_texture.update(graph_image)

func draw_grid(min_val: float, max_val: float):
	for i in range(5):
		var y = int(float(i) / 4 * GRAPH_HEIGHT)
		draw_line_bresenham(graph_image, Vector2(0, y), Vector2(GRAPH_WIDTH, y), Color(1, 1, 1, 0.1), 1)

	for i in range(4):
		var x = int(float(i) / 3 * GRAPH_WIDTH)
		draw_line_bresenham(graph_image, Vector2(x, 0), Vector2(x, GRAPH_HEIGHT), Color(1, 1, 1, 0.1), 1)

func draw_line_bresenham(img: Image, start: Vector2, end: Vector2, color: Color, thickness: int = 1):
	var dx = absi(int(end.x) - int(start.x))
	var dy = -absi(int(end.y) - int(start.y))
	var sx = 1 if start.x < end.x else -1
	var sy = 1 if start.y < end.y else -1
	var err = dx + dy
	var x = int(start.x)
	var y = int(start.y)

	while true:
		for i in range(-thickness / 2, thickness / 2 + 1):
			for j in range(-thickness / 2, thickness / 2 + 1):
				var px = x + i
				var py = y + j
				if px >= 0 and px < GRAPH_WIDTH and py >= 0 and py < GRAPH_HEIGHT:
					img.set_pixel(px, py, color)

		if x == int(end.x) and y == int(end.y):
			break

		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

func get_difficulty_name() -> String:
	return Difficulty.keys()[difficulty]

# Timer callback for real-time minor updates
func _on_market_timer_timeout():
	update_market_value()
	market_timer.start()

func resize_graph(new_width: int, new_height: int):
	GRAPH_WIDTH = new_width
	GRAPH_HEIGHT = new_height

	graph_image = Image.create(GRAPH_WIDTH, GRAPH_HEIGHT, false, Image.FORMAT_RGBA8)
	graph_texture = ImageTexture.create_from_image(graph_image)
	market_graph.texture = graph_texture
	market_graph.custom_minimum_size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)
	update_graph()
