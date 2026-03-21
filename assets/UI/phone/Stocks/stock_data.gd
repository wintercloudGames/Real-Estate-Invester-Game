# stock_data.gd
extends Resource
class_name StockData

@export var stock_name: String = "Global Realty"
@export var ticker: String = "GLRE"
@export var current_price: float = 100.0
@export var volatility: float = 0.05
@export var price_history: Array[float] = []
@export var dividend_yield: float = 0.02 # 2% annual yield, for example
func _init():
	var variation = current_price * 0.05
	var random_start = randf_range(current_price - variation, current_price + variation)
	price_history = [random_start]
