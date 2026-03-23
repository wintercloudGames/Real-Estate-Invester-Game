extends Node

signal market_updated
signal dividend_paid(amount: float)

# Settings
var update_interval: float = 5.0 
var dividend_interval: float = 60.0 # Total time between payouts

@onready var market_timer = Timer.new()
@onready var dividend_timer = Timer.new()

func _ready():
	# Market Price Timer (5s)
	add_child(market_timer)
	market_timer.wait_time = update_interval
	market_timer.timeout.connect(_on_market_timeout)
	
	# Dividend Payout Timer (60s)
	add_child(dividend_timer)
	dividend_timer.wait_time = dividend_interval
	dividend_timer.one_shot = false
	dividend_timer.timeout.connect(_on_dividend_timeout)
	
	load_stocks_from_folder("res://assets/UI/phone/Stocks/Stocks/")
	
	market_timer.start()
	dividend_timer.start()

# Helper function for the UI to see how much time is left
func get_time_until_dividend() -> int:
	return int(dividend_timer.time_left)

func _on_market_timeout():
	for stock in Globals.all_stocks:
		_update_stock_price(stock)
	market_updated.emit()

func _on_dividend_timeout():
	var total_payout = 0.0
	for stock in Globals.all_stocks:
		var shares = Globals.portfolio.get(stock.ticker, 0)
		if shares > 0:
			# Yield is annual, so we divide by 12 (assuming 60s = 1 month)
			var payout = (stock.current_price * stock.dividend_yield) / 12.0
			total_payout += payout * shares
	
	if total_payout > 0:
		Globals.brokerage_balance += total_payout
		dividend_paid.emit(total_payout)

func _update_stock_price(stock: StockData):
	var change = stock.current_price * randf_range(-0.02, 0.022)
	stock.current_price += change
	stock.current_price = max(0.01, stock.current_price)
	stock.price_history.append(stock.current_price)
	if stock.price_history.size() > 50: stock.price_history.remove_at(0)

func load_stocks_from_folder(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var stock_res = load(path + file_name.replace(".remap", ""))
				if stock_res is StockData:
					Globals.all_stocks.append(stock_res)
			file_name = dir.get_next()
